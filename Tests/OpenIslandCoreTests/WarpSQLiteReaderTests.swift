import Foundation
import Testing
import SQLite3
@testable import OpenIslandCore

struct WarpSQLiteReaderTests {
    @Test
    func defaultDatabasePathPointsToWarpGroupContainer() {
        let path = WarpSQLiteReader.defaultDatabasePath()
        #expect(path.hasSuffix("/Library/Group Containers/2BBY89MBSN.dev.warp/Library/Application Support/dev.warp.Warp-Stable/warp.sqlite"))
        // Path should be absolute and start with the user's home dir.
        #expect(path.hasPrefix(NSHomeDirectory()))
    }

    @Test
    func readerAcceptsExplicitPathOverride() {
        let custom = "/tmp/warp-fixture.sqlite"
        let reader = WarpSQLiteReader(databasePath: custom)
        #expect(reader.databasePath == custom)
    }

    @Test
    func lookupPaneUUIDReturnsUppercaseHexForClaudeInKnownCwd() throws {
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .threeTabsTwoClaudes)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        let uuid = reader.lookupPaneUUID(forCwd: "/Users/u/open-vibe-island")
        #expect(uuid == "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB")
    }

    @Test
    func lookupPaneUUIDReturnsNilForCwdWithoutClaudeCommand() throws {
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .threeTabsTwoClaudes)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        #expect(reader.lookupPaneUUID(forCwd: "/nonexistent") == nil)
    }

    @Test
    func lookupPaneUUIDReturnsNilForMissingDatabaseFile() {
        let reader = WarpSQLiteReader(databasePath: "/nonexistent/path/warp.sqlite")
        #expect(reader.lookupPaneUUID(forCwd: "/any") == nil)
    }

    @Test
    func lookupPaneUUIDFallsBackToCommandHistoryWhenTerminalPanesCwdIsStale() throws {
        // Regression for the compound-command flow: user opens a new Warp
        // tab and pastes `mkdir -p /tmp/compound-test && cd /tmp/compound-test
        // && claude` as one line. Warp's shell integration wrote a
        // precmd-<session>-1 block at the very first prompt render (before
        // the compound command ran), linking the shell session to the pane
        // uuid — but terminal_panes.cwd was never updated past the initial
        // /Users/u because the second prompt never rendered. The primary
        // cwd lookup returns nil; the fallback must inspect the commands
        // history, match the `cd /tmp/compound-test` pattern, follow
        // commands.session_id → blocks.precmd-<session_id>-* →
        // pane_leaf_uuid.
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .compoundCommandFlow)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        let uuid = reader.lookupPaneUUID(forCwd: "/tmp/compound-test")
        #expect(uuid == "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD")
    }

    @Test
    func lookupPaneUUIDFallbackAcceptsFirmlinkFlippedInput() throws {
        // Hook payloads arrive with /private/tmp/compound-test because
        // Claude Code captures cwd via getcwd() which resolves the
        // firmlink. The original command was typed as `cd
        // /tmp/compound-test`. The fallback must try both forms so the
        // cross-match succeeds.
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .compoundCommandFlow)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        let uuid = reader.lookupPaneUUID(forCwd: "/private/tmp/compound-test")
        #expect(uuid == "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD")
    }

    @Test
    func lookupPaneUUIDByShellPIDReturnsUUIDAtTheSameIndexAsShellInSortedSiblings() throws {
        // Core correlation: Warp spawns one shell child per pane in
        // tab creation order, and writes terminal_panes rows in the
        // same order. The Nth child of Warp's terminal-server (by pid
        // ASC) owns the Nth pane (by tab_id ASC). This is the signal
        // that disambiguates sibling tabs sharing the same cwd — a
        // case neither the primary cwd lookup nor the commands-history
        // fallback can resolve.
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .threeTabsTwoClaudes)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        let siblings: [pid_t] = [2001, 2002, 2003]

        // Shell 2001 (index 0 after sort) → first pane in tab order =
        // AAAA (giftcard).
        #expect(reader.lookupPaneUUIDByShellPID(2001, siblings: siblings)
            == "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
        // Shell 2002 (index 1) → second pane = BBBB (open-vibe-island).
        #expect(reader.lookupPaneUUIDByShellPID(2002, siblings: siblings)
            == "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB")
        // Shell 2003 (index 2) → third pane = CCCC (/tmp).
        #expect(reader.lookupPaneUUIDByShellPID(2003, siblings: siblings)
            == "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    }

    @Test
    func lookupPaneUUIDByShellPIDReturnsNilWhenShellIsNotInSiblings() throws {
        // Guards against a stale shellPID (e.g. the shell exited and a
        // new one took its pid, or the caller passed a pid that is
        // not a direct child of terminal-server). The correct
        // fallback is nil — never guess.
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .threeTabsTwoClaudes)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        #expect(reader.lookupPaneUUIDByShellPID(9999, siblings: [2001, 2002, 2003]) == nil)
    }

    @Test
    func lookupPaneUUIDByShellPIDSortsSiblingsBeforeIndexing() throws {
        // Caller may pass siblings in arbitrary order (e.g. the order
        // pgrep prints them in, which is not guaranteed to be sorted).
        // The pid→index correlation depends on ASCENDING sort, so the
        // method must impose the ordering itself.
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .threeTabsTwoClaudes)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        // pgrep output order flipped — still must resolve to the
        // right pane.
        #expect(reader.lookupPaneUUIDByShellPID(2001, siblings: [2003, 2001, 2002])
            == "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    }

    @Test
    func lookupPaneUUIDByShellPIDReturnsNilWhenIndexIsOutOfRange() throws {
        // Simulates a transient state where siblings list contains
        // more entries than terminal_panes. Could happen if Warp is
        // mid-spawn on a new tab, or if a helper process is counted
        // as a sibling by accident. Better to return nil than guess.
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .threeTabsTwoClaudes)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        // Six siblings, but only 3 panes — shell 2006 (index 5) is
        // out of range.
        #expect(reader.lookupPaneUUIDByShellPID(
            2006,
            siblings: [2001, 2002, 2003, 2004, 2005, 2006]
        ) == nil)
    }

    @Test
    func lookupPaneUUIDFallbackFindsPaneEvenWithoutAnyPrecmdBlocks() throws {
        // Discovered against a real Warp SQLite during local E2E
        // testing: Warp does NOT always write `precmd-<session>-1`
        // for a shell session. Specifically, when the user opens a
        // new tab and immediately pastes a compound command like
        // `mkdir -p /tmp/foo && cd /tmp/foo && claude`, claude grabs
        // the TTY before Warp's shell integration has a chance to
        // record even the first prompt. The commands row exists but
        // the blocks table has ZERO precmd entries for that
        // session_id.
        //
        // This breaks any fallback that depends on a precmd block
        // linking session → pane uuid. We instead correlate via
        // `commands.pwd = terminal_panes.cwd` (both reflect the
        // pane's inherited initial cwd), with the NOT EXISTS filter
        // excluding panes already "owned" by a different session via
        // their own precmd blocks. In this fixture there's a sibling
        // pane with blocks tying it to a different session — the
        // orphan pane (no blocks) is the only valid match.
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .compoundCommandInSiblingTabFlow)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        // Scenario: two sibling tabs both with inherited cwd
        // /tmp/sibling. Tab X (uuid AAAA) has precmd blocks tied to
        // its own shell session 10001. Tab Y (uuid CCCC) has NO
        // precmd blocks at all — the compound-command-hijacks-TTY
        // flow. The `cd /tmp/target && claude` command for tab Y's
        // session 10002 lives in commands but is not linked to any
        // pane via blocks. The fallback must correlate
        // commands.pwd with terminal_panes.cwd AND exclude tab X
        // (owned by another session) to land on tab Y.
        let uuid = reader.lookupPaneUUID(forCwd: "/tmp/target")
        #expect(uuid == "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
    }

    @Test
    func lookupPaneUUIDFallbackSkipsOrphanBlocksFromClosedTabs() throws {
        // When the user closes a Warp tab, Warp prunes the
        // `terminal_panes` row for that tab but leaves the historical
        // `commands` and `blocks` entries in place — this is visible on
        // the real database, which routinely has ~1000+ blocks against
        // a handful of live terminal_panes rows. The fallback must
        // reject matches whose resolved pane_leaf_uuid is no longer
        // present in terminal_panes, otherwise a stale hit would pass
        // a ghost uuid to the precision jump cycle loop, which would
        // spin its entire cap never seeing that uuid in the focused
        // pane read. Graceful degradation is "activate Warp, no
        // precise target" — not "cycle for a second then give up".
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .compoundCommandFlow)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        // The fixture has an orphan command+block pair pointing at pane
        // uuid FFFF... — no matching terminal_panes row.
        let uuid = reader.lookupPaneUUID(forCwd: "/tmp/closed-tab-cwd")
        #expect(uuid == nil)
    }

    @Test
    func lookupPaneUUIDFallbackDoesNotFalsePositiveOnSubstringCwd() throws {
        // The fallback uses LIKE '%cd <target>%' which is vulnerable to
        // substring collision: a query for `/tmp/foo` must not match a
        // command like `cd /tmp/foo-extended`. Pin the boundary behavior.
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .compoundCommandFlow)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        // The fixture has a `cd /tmp/compound-test-extended && claude`
        // command pointed at a different pane uuid. A lookup for the
        // shorter path must NOT match it.
        let uuid = reader.lookupPaneUUID(forCwd: "/tmp/compound")
        #expect(uuid == nil)
    }

    @Test
    func lookupPaneUUIDPrimaryStillWinsWhenTerminalPanesCwdIsPopulated() throws {
        // When terminal_panes.cwd IS populated (normal case where the
        // user ran a non-TUI command between `cd` and `claude`), the
        // primary cwd query should still win and we should not fall
        // through to the slower commands-table fallback. This is pinned
        // by reusing the threeTabsTwoClaudes scenario which has populated
        // terminal_panes.cwd for /Users/u/open-vibe-island.
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .threeTabsTwoClaudes)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        let uuid = reader.lookupPaneUUID(forCwd: "/Users/u/open-vibe-island")
        #expect(uuid == "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB")
    }

    @Test
    func currentFocusedPaneUUIDReturnsActiveTabsUUID() throws {
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .threeTabsTwoClaudes)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        // Scenario has active_tab_index = 1 which is tab id 2 (open-vibe-island).
        let reader = WarpSQLiteReader(databasePath: tmp)
        #expect(reader.currentFocusedPaneUUID() == "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB")
    }

    @Test
    func currentFocusedPaneUUIDReturnsNilForMissingDatabase() {
        let reader = WarpSQLiteReader(databasePath: "/nonexistent.sqlite")
        #expect(reader.currentFocusedPaneUUID() == nil)
    }

    @Test
    func tabCountInActiveWindowReturnsCount() throws {
        let tmp = NSTemporaryDirectory() + "warp-fixture-\(UUID().uuidString).sqlite"
        try WarpSQLiteFixture.write(to: tmp, scenario: .threeTabsTwoClaudes)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let reader = WarpSQLiteReader(databasePath: tmp)
        #expect(reader.tabCountInActiveWindow() == 3)
    }

    @Test
    func tabCountInActiveWindowReturnsZeroForMissingDatabase() {
        let reader = WarpSQLiteReader(databasePath: "/nonexistent.sqlite")
        #expect(reader.tabCountInActiveWindow() == 0)
    }
}

// MARK: - Fixture

/// Builds a minimal synthetic warp.sqlite with the exact schema columns the
/// reader queries. Only the queried subset is present; other tables and
/// constraints are omitted intentionally to keep the fixture short.
enum WarpSQLiteFixture {
    static func write(to path: String, scenario: Scenario) throws {
        // Open (create) the file
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            throw NSError(domain: "WarpSQLiteFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "open failed"])
        }
        defer { sqlite3_close(db) }

        let schema = """
        CREATE TABLE app (id INTEGER PRIMARY KEY, active_window_id INTEGER);
        CREATE TABLE windows (id INTEGER PRIMARY KEY, active_tab_index INTEGER NOT NULL);
        CREATE TABLE tabs (id INTEGER PRIMARY KEY, window_id INTEGER NOT NULL);
        CREATE TABLE pane_nodes (id INTEGER PRIMARY KEY, tab_id INTEGER NOT NULL, is_leaf BOOLEAN NOT NULL);
        CREATE TABLE terminal_panes (id INTEGER PRIMARY KEY, uuid BLOB NOT NULL, cwd TEXT);
        CREATE TABLE commands (id INTEGER PRIMARY KEY, session_id INTEGER, command TEXT, pwd TEXT);
        CREATE TABLE blocks (id INTEGER PRIMARY KEY, pane_leaf_uuid BLOB, block_id TEXT);
        """
        guard sqlite3_exec(db, schema, nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "WarpSQLiteFixture", code: 2, userInfo: [NSLocalizedDescriptionKey: "schema failed: \(String(cString: sqlite3_errmsg(db)))"])
        }

        for row in scenario.rows {
            guard sqlite3_exec(db, row, nil, nil, nil) == SQLITE_OK else {
                throw NSError(domain: "WarpSQLiteFixture", code: 3, userInfo: [NSLocalizedDescriptionKey: "insert failed: \(String(cString: sqlite3_errmsg(db)))"])
            }
        }
    }

    struct Scenario {
        var rows: [String]

        /// Models the "compound command" flow where Warp's shell
        /// integration never updates `terminal_panes.cwd` past the
        /// initial shell cwd because the user ran `cd <target> && claude`
        /// as a single pasted line and claude's TUI took over before a
        /// second prompt could render.
        ///
        /// Pane D had one prompt render at shell startup (cwd /Users/u),
        /// wrote precmd-9001-1, then executed the compound command — so
        /// terminal_panes.cwd stays /Users/u but the commands table
        /// records the full text with `cd /tmp/compound-test`.
        ///
        /// Pane E is a separate shell that ran a NEAR-miss command
        /// (`cd /tmp/compound-test-extended`) so we can pin that the
        /// fallback doesn't false-positive on substring collisions.
        static let compoundCommandFlow = Scenario(rows: [
            "INSERT INTO app (id, active_window_id) VALUES (1, 1);",
            "INSERT INTO windows (id, active_tab_index) VALUES (1, 0);",
            "INSERT INTO tabs (id, window_id) VALUES (1, 1), (2, 1);",
            "INSERT INTO pane_nodes (id, tab_id, is_leaf) VALUES (1, 1, 1), (2, 2, 1);",
            "INSERT INTO terminal_panes (id, uuid, cwd) VALUES " +
                "(1, x'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD', '/Users/u')," +
                "(2, x'EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE', '/Users/u');",
            "INSERT INTO commands (id, session_id, command, pwd) VALUES " +
                "(300, 9001, 'mkdir -p /tmp/compound-test && cd /tmp/compound-test && claude', '/Users/u')," +
                "(301, 9002, 'mkdir -p /tmp/compound-test-extended && cd /tmp/compound-test-extended && claude', '/Users/u')," +
                // Orphan row: represents a shell session whose tab was
                // closed. commands + blocks linger but terminal_panes is
                // pruned. The fallback must not return FFFF... because
                // no such pane exists anymore.
                "(302, 9003, 'cd /tmp/closed-tab-cwd && claude', '/Users/u');",
            "INSERT INTO blocks (id, pane_leaf_uuid, block_id) VALUES " +
                "(1, x'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD', 'precmd-9001-1')," +
                "(2, x'EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE', 'precmd-9002-1')," +
                "(3, x'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF', 'precmd-9003-1');",
        ])

        /// Models the "compound command in a sibling tab" flow where
        /// Warp did not write ANY precmd block for the new shell. The
        /// user has two tabs, both with inherited initial cwd
        /// /tmp/sibling:
        ///
        /// - Tab A (pane uuid AAAA): an older shell session 10001
        ///   that ran a `pwd` (or similar non-TUI command) before
        ///   starting claude, so Warp did write precmd-10001-1 and
        ///   precmd-10001-2 blocks tying the pane to session 10001.
        ///   This is the "test-b" equivalent — the already-running
        ///   tab the user is NOT targeting.
        ///
        /// - Tab C (pane uuid CCCC): a newer shell session 10002
        ///   that was opened as a new tab (inheriting cwd from Tab
        ///   A's focus) and IMMEDIATELY pasted a compound command.
        ///   claude took the TTY before Warp's shell integration
        ///   could render a first prompt, so there are ZERO precmd
        ///   blocks for session 10002. This is the "test-c"
        ///   equivalent — the target the user IS trying to jump to.
        ///
        /// The fallback must correlate:
        ///   commands.pwd (/tmp/sibling) → terminal_panes.cwd (/tmp/sibling)
        /// and exclude Tab A via the NOT EXISTS foreign-block check,
        /// leaving Tab C as the only valid match even though Tab C
        /// has zero blocks of its own.
        static let compoundCommandInSiblingTabFlow = Scenario(rows: [
            "INSERT INTO app (id, active_window_id) VALUES (1, 1);",
            "INSERT INTO windows (id, active_tab_index) VALUES (1, 0);",
            "INSERT INTO tabs (id, window_id) VALUES (1, 1), (2, 1);",
            "INSERT INTO pane_nodes (id, tab_id, is_leaf) VALUES (1, 1, 1), (2, 2, 1);",
            // Both panes inherited the same initial cwd because the
            // new tab opened as a sibling to the first.
            "INSERT INTO terminal_panes (id, uuid, cwd) VALUES " +
                "(1, x'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', '/tmp/sibling')," +
                "(2, x'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC', '/tmp/sibling');",
            // Both shell sessions ran commands with pwd=/tmp/sibling.
            // Session 10001 has non-compound command history (a plain
            // `pwd` before claude). Session 10002 has ONLY the
            // compound cd+claude.
            "INSERT INTO commands (id, session_id, command, pwd) VALUES " +
                "(400, 10001, 'pwd', '/tmp/sibling')," +
                "(401, 10001, 'claude', '/tmp/sibling')," +
                "(402, 10002, 'mkdir -p /tmp/target && cd /tmp/target && claude', '/tmp/sibling');",
            // Session 10001 has two precmd blocks (one at first
            // prompt, one after `pwd` completed). Session 10002 has
            // no blocks at all — the compound command ran before the
            // first prompt.
            "INSERT INTO blocks (id, pane_leaf_uuid, block_id) VALUES " +
                "(1, x'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', 'precmd-10001-1')," +
                "(2, x'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', 'precmd-10001-2');",
        ])

        /// Three tabs in one window. Tab 1 cwd=giftcard (pane uuid AAAA...),
        /// tab 2 cwd=open-vibe-island (pane uuid BBBB...), tab 3 cwd=/tmp (pane uuid CCCC...).
        /// Claude was launched in giftcard from Warp shell session 1001 and in open-vibe-island from 1002.
        static let threeTabsTwoClaudes = Scenario(rows: [
            "INSERT INTO app (id, active_window_id) VALUES (1, 1);",
            "INSERT INTO windows (id, active_tab_index) VALUES (1, 1);", // tab index 1 = second tab (0-based)
            "INSERT INTO tabs (id, window_id) VALUES (1, 1), (2, 1), (3, 1);",
            "INSERT INTO pane_nodes (id, tab_id, is_leaf) VALUES (1, 1, 1), (2, 2, 1), (3, 3, 1);",
            "INSERT INTO terminal_panes (id, uuid, cwd) VALUES " +
                "(1, x'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', '/Users/u/giftcard')," +
                "(2, x'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB', '/Users/u/open-vibe-island')," +
                "(3, x'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC', '/tmp');",
            "INSERT INTO commands (id, session_id, command, pwd) VALUES " +
                "(100, 1001, 'cd giftcard', '/Users/u')," +
                "(101, 1001, 'claude --dangerously-skip-permissions', '/Users/u/giftcard')," +
                "(200, 1002, 'claude --dangerously-skip-permissions', '/Users/u/open-vibe-island');",
            "INSERT INTO blocks (id, pane_leaf_uuid, block_id) VALUES " +
                "(1, x'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', 'precmd-1001-1')," +
                "(2, x'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', 'precmd-1001-2')," +
                "(3, x'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB', 'precmd-1002-1');",
        ])
    }
}
