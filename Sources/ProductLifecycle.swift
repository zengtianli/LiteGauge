import AppKit

// LiteGauge's side of the shared「配置与更新」layer (AppLifecycle*.swift, byte copies of swift-shared). This file is the
// one place that names the product, its release channel and its portable settings. The settings window and the
// `litegauge config …` / `litegauge update check` commands are both built from it, so they read and write one thing.
enum ProductLifecycle {
    static let name = "LiteGauge 轻仪"
    /// The one release channel: the window's「检查更新」and `litegauge update check` both read it.
    static let updateSource: AppUpdateSource = .github(repository: "zengtianli/LiteGauge")
    /// CareStore's policy file. Only the protection list travels with「导出配置」and the optional iCloud copy.
    /// The automatic-handling switches, the memory budget and the idle threshold stay per Mac: the budget is sized to
    /// this Mac's memory, and turning a switch on is the consent for this Mac to close or restart apps on its own.
    static let policyFile = "care-policy.json"
    static let portableKeys = ["protectedApps", "unprotectedBuiltins"]

    // MARK: One factory for the window and the command line

    /// An isolated run (the lifecycle self-test, or a caller that sets APP_LIFECYCLE_SUPPORT_DIR as the shared layer
    /// expects) keeps the policy in that folder and the switch in a throwaway preference domain, so the owner's
    /// policy, preferences and iCloud Drive are never read or written by it.
    static var isolatedRoot: URL? {
        ProcessInfo.processInfo.environment["APP_LIFECYCLE_SUPPORT_DIR"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
    }
    static let isolatedSuitePrefix = "test.tianli.litegauge."

    static func store() -> CareStore {
        isolatedRoot.map { CareStore(directory: $0.appendingPathComponent("LiteGauge", isDirectory: true)) } ?? CareStore()
    }

    /// The preference domain that holds the「使用 iCloud 记住配置」switch; nil means UserDefaults.standard.
    /// The App's main bundle is LiteGauge.app, so its standard domain is already the product's. The command line is
    /// usually started through the ~/.local/bin symlink, where the main bundle has no identifier and the standard
    /// domain would be a different one: it names the product's domain explicitly.
    /// An isolated run uses a named throwaway domain (LITEGAUGE_PREFERENCES_SUITE, test prefix only). It has to be a
    /// named domain: a file-path suite inside the temporary folder is not kept in step between running processes
    /// (tried 2026-10-07: the App never saw the command's later switches, and the commands read each other's stale file).
    static func preferencesDomain(mainBundleID: String?, isolated: Bool, requestedSuite: String?) -> String? {
        if isolated {
            if let requestedSuite, requestedSuite.hasPrefix(isolatedSuitePrefix) { return requestedSuite }
            return isolatedSuitePrefix + "isolated"
        }
        return mainBundleID == AppIdentity.bundleID ? nil : AppIdentity.bundleID
    }

    static func defaults() -> UserDefaults {
        let domain = preferencesDomain(mainBundleID: Bundle.main.bundleIdentifier, isolated: isolatedRoot != nil,
                                       requestedSuite: ProcessInfo.processInfo.environment["LITEGAUGE_PREFERENCES_SUITE"])
        return domain.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    static func makeConfiguration(store: CareStore) -> AppConfiguration {
        AppConfiguration(productID: AppIdentity.bundleID,
                         files: [AppConfigurationFile(url: store.directory.appendingPathComponent(policyFile), keys: portableKeys, validateValue: validate)],
                         defaults: defaults())
    }

    /// Both portable fields are lists of bundle-id patterns. Anything else would make the whole policy unreadable, so it
    /// is refused before a single byte is written. Locked built-in protection cannot be lifted by a stored list either way.
    static func validate(_ value: Any) throws {
        guard let list = value as? [String], list.count <= 500, list.allSatisfy(AppProtection.validPattern) else {
            throw AppUpdateError("保护名单须是 bundle id 的列表（形如 com.example.App，或 com.example.* 表示该前缀下全部）。")
        }
    }

    /// AppConfiguration writes the policy file itself, not through CareStore: put the owner-only mode back and tell
    /// the menu, both windows and the resident controller the way every other policy change does.
    static func policyApplied(_ store: CareStore) {
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: store.directory.appendingPathComponent(policyFile).path)
        // An isolated run must not make the owner's running instance reload its policy.
        guard isolatedRoot == nil else { return }
        DistributedNotificationCenter.default().postNotificationName(CareStore.policyChanged, object: nil, userInfo: nil, deliverImmediately: true)
    }

    // MARK: App side

    struct AppSide {
        let configuration: AppConfiguration
        let settings: CareSettings
    }
    private static var observers: [NSObjectProtocol] = []

    /// Called once from applicationDidFinishLaunching, and by the lifecycle self-test to run this same code offscreen:
    /// the settings window with LiteGauge's own groups, the portable configuration, and following the command line.
    static func installApp() -> AppSide {
        let store = store()
        let settings = CareSettings(store: store)
        let configuration = makeConfiguration(store: store)
        AppLifecycleUI.install(name: name, configuration: configuration, updateSource: updateSource)
        AppLifecycleUI.shared.productGroups = { settings.groups() }
        AppLifecycleUI.shared.willShow = { settings.refresh() }
        // A running window follows `litegauge config sync on|off` and `config import`. The command is the only writer of
        // the switch: the shared follower adopts the stored state without storing anything, and nothing here does either.
        AppLifecycleCLI.follow(configuration)
        // onChange also fires for a switch that left the policy alone, and reloading the resident controller cancels a
        // reclaim in progress: reload only when the portable part of the policy really differs from what was last seen.
        var seen = try? configuration.exportData()
        configuration.onChange = { [weak configuration, weak settings] in
            guard let configuration else { return }
            let now = try? configuration.exportData()
            guard now != seen else { return }
            seen = now
            policyApplied(store)
            settings?.refresh()
        }
        observers.append(DistributedNotificationCenter.default().addObserver(forName: CareStore.policyChanged, object: nil, queue: .main) { [weak configuration] _ in
            seen = try? configuration?.exportData()
        })
        return AppSide(configuration: configuration, settings: settings)
    }

    // MARK: Command side

    /// The .app this executable lives in. Through the ~/.local/bin symlink Bundle.main is the link's folder, without an
    /// Info.plist or identifier; version, build and bundle id come from the resolved executable's bundle.
    static let hostBundle: Bundle = {
        guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else { return .main }
        let app = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return (app.pathExtension == "app" ? Bundle(url: app) : nil) ?? .main
    }()

    /// The shared layer's own help lines for the top-level --help, so a subcommand it gains shows up there too.
    static var help: CLI.LifecycleHelp {
        CLI.LifecycleHelp(read: AppLifecycleCLI.helpRead(CLI.shortName), write: AppLifecycleCLI.helpWrite(CLI.shortName),
                          noCommand: AppLifecycleCLI.helpNoCommand)
    }

    /// `litegauge config …` and `litegauge update check`. `arguments` starts at the verb; call on the main thread.
    static func run(_ arguments: [String]) -> Int32 {
        let store = store()
        let configuration = makeConfiguration(store: store)
        let before = try? configuration.exportData()
        var printed = ""
        var product = AppLifecycleCLI.Product(command: CLI.shortName, name: name, configuration: configuration, updateSource: updateSource)
        product.bundle = hostBundle
        product.out = { printed += $0; CLIOutput.write($0 + "\n") }
        product.runningApp = { RunningInstances.menuBar().map(\.processIdentifier) }
        product.changed = { if (try? configuration.exportData()) != before { policyApplied(store) } }
        let code = AppLifecycleCLI.run(arguments, product: product)
        // Like every other LiteGauge command: a usage error names its reason on stderr even when --json was asked for.
        if code == 2, CLI.wantsJSON(arguments),
           let object = (try? JSONSerialization.jsonObject(with: Data(printed.utf8))) as? [String: Any],
           let message = (object["error"] as? [String: Any])?["message"] as? String {
            CLIOutput.write(message + "；用 --help 查看用法。\n", to: .standardError)
        }
        return code
    }
}

// MARK: - Lifecycle self-test

// `--lifecycle-self-test [dir]`: this process is the running App. It runs the same `installApp()` the menu-bar App
// runs, offscreen (activation policy .prohibited: no status item, no visible window, no Dock icon), and the real
// `litegauge config …` commands are run against it as child processes of this same executable, through a symlink
// named litegauge the way the installed command is called. Policy, preferences, "cloud" folder and the follow
// channel are throwaway: the owner's policy, preferences, iCloud Drive and running menu-bar instance are not touched.
extension ProductLifecycle {
    static func runSelfTest(outDir: URL) -> Bool {
        let files = FileManager.default
        var checks: [String: Bool] = [:], order: [String] = [], facts: [String: Any] = [:]
        func check(_ name: String, _ passed: Bool) { if checks[name] == nil { order.append(name) }; checks[name] = passed }
        // Deadlines count time the Mac was awake: a wait that spans a sleep must not fail (or pass) because of it.
        func awake() -> TimeInterval { ProcessInfo.processInfo.systemUptime }
        func wait(_ seconds: Double, until done: () -> Bool) -> Bool {
            let end = awake() + seconds
            while !done() && awake() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
            return done()
        }
        func stamp(_ url: URL) -> String {
            guard let attributes = try? files.attributesOfItem(atPath: url.path) else { return "absent" }
            return "\((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)/\(attributes[.size] ?? 0)"
        }

        // The owner's real state, looked at (never opened for writing) before and after.
        let home = files.homeDirectoryForCurrentUser
        let owned = [CareStore().directory.appendingPathComponent(policyFile),
                     home.appendingPathComponent("Library/Preferences/\(AppIdentity.bundleID).plist"),
                     home.appendingPathComponent("Library/Application Support/TianliApps/Configuration/\(AppIdentity.bundleID)")]
        let ownedBefore = owned.map(stamp)

        let id = UUID().uuidString.lowercased()
        let root = outDir.appendingPathComponent("lifecycle-" + id.prefix(8), isDirectory: true)
        let support = root.appendingPathComponent("support", isDirectory: true), cloud = root.appendingPathComponent("cloud", isDirectory: true)
        let suite = isolatedSuitePrefix + id
        setenv("APP_LIFECYCLE_SUPPORT_DIR", support.path, 1)
        setenv("APP_LIFECYCLE_CLOUD_DIR", cloud.path, 1)
        setenv("APP_LIFECYCLE_FOLLOW_CHANNEL", "test." + id, 1)
        setenv("LITEGAUGE_PREFERENCES_SUITE", suite, 1)
        /// A removed throwaway domain leaves an empty 42-byte plist in ~/Library/Preferences, and the preferences daemon
        /// writes it seconds after this process has exited: nothing here can catch its own. Each run clears the empty
        /// shells earlier runs left (this test's prefix only), and the result names this run's domain so the caller can
        /// delete it (`defaults delete <domain>`; scripts/accept/lifecycle.sh does).
        func sweepTestPreferences() {
            let folder = home.appendingPathComponent("Library/Preferences", isDirectory: true)
            for file in (try? files.contentsOfDirectory(atPath: folder.path)) ?? [] where file.hasPrefix(isolatedSuitePrefix) && file.hasSuffix(".plist") {
                let url = folder.appendingPathComponent(file)
                let size = ((try? files.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.intValue
                if let size, size <= 42 { try? files.removeItem(at: url) }
            }
        }
        sweepTestPreferences()
        facts["preference_domain"] = suite
        defer {
            UserDefaults.standard.removePersistentDomain(forName: suite)
            CFPreferencesAppSynchronize(suite as CFString)
            try? files.removeItem(at: root)
        }
        let isolatedStore = store()
        let policyURL = isolatedStore.directory.appendingPathComponent(policyFile)
        check("isolation_in_force", isolatedRoot?.path == support.path && isolatedStore.directory.path.hasPrefix(root.path)
              && preferencesDomain(mainBundleID: Bundle.main.bundleIdentifier, isolated: true, requestedSuite: suite) == suite)
        // Outside an isolated run the switch lives in one domain whether the App or the symlinked command asks
        // (decided here without opening that domain); inside one, neither can reach it, whatever suite is asked for.
        check("app_and_command_share_one_preference_domain",
              preferencesDomain(mainBundleID: AppIdentity.bundleID, isolated: false, requestedSuite: nil) == nil
              && preferencesDomain(mainBundleID: nil, isolated: false, requestedSuite: nil) == AppIdentity.bundleID
              && preferencesDomain(mainBundleID: nil, isolated: false, requestedSuite: suite) == AppIdentity.bundleID
              && preferencesDomain(mainBundleID: AppIdentity.bundleID, isolated: true, requestedSuite: suite) == suite
              && preferencesDomain(mainBundleID: nil, isolated: true, requestedSuite: AppIdentity.bundleID) == isolatedSuitePrefix + "isolated")
        guard checks.values.allSatisfy({ $0 }) else { return report(checks, order, facts, outDir: outDir) }

        // A policy with portable and non-portable fields, written directly (CareStore would notify the owner's instance).
        do {
            try files.createDirectory(at: isolatedStore.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(CarePolicy(enabled: true, pausedBudgetBytes: 5 * 1_073_741_824, budgetIdleMinutes: 30, protectedApps: ["com.example.Seed"]))
                .write(to: policyURL, options: .atomic)
        } catch { check("seed_policy", false); return report(checks, order, facts, outDir: outDir) }

        // The running App: the production wiring, then the real settings window built offscreen.
        let app = installApp()
        let shot = (try? AppLifecycleUI.shared.offscreenSnapshot(to: outDir.appendingPathComponent("lifecycle-settings.png"))) ?? [:]
        let window = Mirror(reflecting: AppLifecycleUI.shared)
        let toggle = window.descendant("cloudToggle") as? NSSwitch, statusLine = window.descendant("syncStatus") as? NSTextField
        let off = "iCloud 配置同步已关闭"
        check("settings_window_offscreen_with_configuration_group", shot["upgrade_window_offscreen"] == true && shot["upgrade_image_rendered"] == true
              && toggle?.window?.title == "\(name) 设置" && toggle?.window?.isVisible == false && statusLine?.window === toggle?.window)
        check("app_starts_with_sync_off", !app.configuration.enabled && toggle?.state == .off && statusLine?.stringValue == off)

        // The command, as an agent runs it: a child of this executable through a symlink named litegauge.
        let link = root.appendingPathComponent("litegauge")
        guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath(),
              (try? files.createSymbolicLink(at: link, withDestinationURL: executable)) != nil else {
            check("command_link", false); return report(checks, order, facts, outDir: outDir)
        }
        var commands = 0
        func run(_ arguments: String...) -> (code: Int32, body: [String: Any], stderr: String) {
            let process = Process(), out = Pipe(), err = Pipe()
            process.executableURL = link; process.arguments = arguments + ["--json"]
            process.standardOutput = out; process.standardError = err; process.standardInput = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return (-1, [:], "not started") }
            commands += 1
            // The App keeps running while the command does: notifications and the follow handler are delivered here.
            while process.isRunning { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
            let body = (try? JSONSerialization.jsonObject(with: out.fileHandleForReading.readDataToEndOfFile())) as? [String: Any]
            return (process.terminationStatus, body ?? [:], String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
        }
        /// The stored switch as a fresh process reads it; nil when the readback itself failed.
        func stored() -> Bool? {
            let status = run("config", "status")
            return status.code == 0 ? status.body["sync_enabled"] as? Bool : nil
        }
        /// For `seconds`, the App, its window and every fresh read of the stored value all stay at `target`.
        func holds(_ target: Bool, _ seconds: Double) -> Bool {
            let end = awake() + seconds
            repeat {
                guard app.configuration.enabled == target, toggle?.state == (target ? .on : .off), stored() == target else { return false }
                RunLoop.main.run(until: Date().addingTimeInterval(0.03))
            } while awake() < end
            return true
        }
        func sync(_ target: Bool) -> (code: Int32, body: [String: Any], stderr: String) { run("config", "sync", target ? "on" : "off", "--yes") }
        var unfollowed: [[String: Any]] = []
        func follows(_ target: Bool) -> Bool {
            let began = awake(), clock = Date()
            let followed = wait(5) { app.configuration.enabled == target && toggle?.state == (target ? .on : .off)
                && (statusLine?.stringValue == off) == !target }
            // What the App showed when it did not follow, and whether wall time ran ahead of awake time (a sleep).
            if !followed {
                unfollowed.append(["target": target, "enabled": app.configuration.enabled, "toggle_on": toggle?.state == .on,
                                   "status": statusLine?.stringValue ?? "", "awake_s": awake() - began, "wall_s": Date().timeIntervalSince(clock)])
            }
            return followed
        }

        let first = run("config", "status")
        check("status_reads_the_same_settings", first.code == 0 && first.body["has_settings"] as? Bool == true && first.body["sync_enabled"] as? Bool == false
              && first.body["keys"] as? [String] == ["file.0.protectedApps"] && first.body["problem"] is NSNull)
        check("status_writes_nothing", !files.fileExists(atPath: support.appendingPathComponent(AppIdentity.bundleID).path) && !files.fileExists(atPath: cloud.path))

        // Switch on and off, several rounds: the App follows each one and the stored value is never written back.
        let cloudFile = cloud.appendingPathComponent(AppIdentity.bundleID + ".json")
        for round in 1...3 {
            let on = sync(true)
            check("round\(round)_command_switches_on", on.code == 0 && on.body["changed"] as? Bool == true && on.body["sync_enabled"] as? Bool == true)
            check("round\(round)_app_follows_on", follows(true))
            check("round\(round)_on_is_not_written_back", holds(true, 1.2))
            if round == 1 {
                let uploaded = ((try? JSONSerialization.jsonObject(with: Data(contentsOf: cloudFile))) as? [String: Any])?["values"] as? [String: Any]
                check("sync_on_uploads_through_the_shared_reconcile", uploaded?["file.0.protectedApps"] as? [String] == ["com.example.Seed"])
            }
            let offResult = sync(false)
            check("round\(round)_command_switches_off", offResult.code == 0 && offResult.body["changed"] as? Bool == true && offResult.body["sync_enabled"] as? Bool == false)
            check("round\(round)_app_follows_off", follows(false))
            check("round\(round)_off_is_not_written_back", holds(false, 1.2))
        }

        // Back to back: the second command lands while the App is still about to act on the first. From the moment
        // the second command returns, no fresh read may see the first command's value again.
        var regressions: [String] = []
        func settled(_ target: Bool, _ label: String) {
            let end = awake() + 1.5
            while awake() < end {
                if stored() != target { regressions.append(label); return }
            }
            if !follows(target) { regressions.append(label + ":app") }
        }
        for round in 1...4 {
            _ = sync(true); _ = sync(false)
            settled(false, "on>off#\(round)")
            _ = sync(true); _ = follows(true); _ = wait(0.5) { false }
            _ = sync(false); _ = sync(true)
            settled(true, "off>on#\(round)")
            _ = sync(false); _ = follows(false); _ = wait(0.5) { false }
        }
        facts["back_to_back_regressions"] = regressions
        check("back_to_back_switches_never_regress", regressions.isEmpty)

        // The window's own switch and the command are one setting, both ways.
        if let toggle, let action = toggle.action {
            toggle.state = .on
            NSApp.sendAction(action, to: toggle.target, from: toggle)
            check("window_switch_is_read_by_the_command", wait(5) { app.configuration.status != off } && stored() == true)
            let back = sync(false)
            check("command_switch_is_shown_by_the_window", back.code == 0 && follows(false) && holds(false, 0.6))
        } else { check("window_switch_is_read_by_the_command", false) }

        // Import: the App re-reads the settings, the switch is left alone, non-portable fields survive.
        func envelope(_ values: [String: Any], product: String = AppIdentity.bundleID) -> Data {
            (try? JSONSerialization.data(withJSONObject: ["version": 1, "product": product, "values": values], options: [.sortedKeys])) ?? Data()
        }
        let incoming = root.appendingPathComponent("in.json")
        try? envelope(["file.0.protectedApps": ["com.example.Imported", "com.example.suite.*"]]).write(to: incoming)
        check("import_needs_yes", run("config", "import", incoming.path).code == 2 && (try? isolatedStore.policy())?.protectedApps == ["com.example.Seed"])
        let imported = run("config", "import", incoming.path, "--yes")
        check("import_command", imported.code == 0 && imported.body["imported"] as? Bool == true && imported.body["sync"] == nil)
        check("app_rereads_imported_settings", wait(5) { app.settings.protectedText.contains("com.example.Imported") })
        check("import_leaves_the_switch_alone", holds(false, 0.8))
        let after = try? isolatedStore.policy()
        check("import_keeps_non_portable_fields", after?.protectedApps == ["com.example.Imported", "com.example.suite.*"] && after?.enabled == true
              && after?.budgetIdleMinutes == 30 && after?.pausedBudgetBytes == 5 * 1_073_741_824 && after?.memoryBudgetBytes == nil)
        let backups = (try? files.contentsOfDirectory(atPath: support.appendingPathComponent(AppIdentity.bundleID + "/Backups").path)) ?? []
        check("import_backs_up_and_keeps_owner_only_mode", backups.count == 1
              && ((try? files.attributesOfItem(atPath: policyURL.path))?[.posixPermissions] as? NSNumber)?.intValue == 0o600)

        // Refused imports leave the policy readable and unchanged.
        let wrongType = root.appendingPathComponent("wrong-type.json"), foreign = root.appendingPathComponent("foreign.json")
        let notAllowed = root.appendingPathComponent("not-allowed.json")
        try? envelope(["file.0.protectedApps": 5]).write(to: wrongType)
        try? envelope(["file.0.protectedApps": ["com.example.Other"]], product: "someone.else").write(to: foreign)
        try? envelope(["file.0.memoryBudgetBytes": 1_073_741_824]).write(to: notAllowed)
        let refused = [wrongType, foreign, notAllowed].map { run("config", "import", $0.path, "--yes") }
        check("bad_imports_are_refused_and_change_nothing", refused.allSatisfy { $0.code == 1 && ($0.body["error"] as? [String: Any])?["code"] as? String == "import_rejected" }
              && (try? isolatedStore.policy())?.protectedApps == after?.protectedApps && (try? isolatedStore.policy())?.memoryBudgetBytes == nil)

        // With sync on, an import reaches the cloud copy and the App; then back off.
        check("app_follows_on_before_synced_import", sync(true).code == 0 && follows(true))
        try? envelope(["file.0.protectedApps": ["com.example.Synced"]]).write(to: incoming)
        let carried = run("config", "import", incoming.path, "--yes")
        let mirrored = ((try? JSONSerialization.jsonObject(with: Data(contentsOf: cloudFile))) as? [String: Any])?["values"] as? [String: Any]
        check("import_while_syncing_reaches_the_cloud_copy", carried.code == 0 && (carried.body["sync"] as? [String: Any])?["completed"] as? Bool == true
              && mirrored?["file.0.protectedApps"] as? [String] == ["com.example.Synced"])
        check("app_shows_the_synced_import_and_stays_on", wait(5) { app.settings.protectedText.contains("com.example.Synced") } && follows(true) && holds(true, 0.8))
        _ = sync(false)
        check("app_follows_final_off", follows(false) && holds(false, 0.6))

        // Export is the window's envelope; usage errors keep LiteGauge's convention; help lists every subcommand.
        let exported = root.appendingPathComponent("out.json")
        let export = run("config", "export", "-o", exported.path)
        let written = (try? JSONSerialization.jsonObject(with: Data(contentsOf: exported))) as? [String: Any]
        check("export_writes_the_portable_settings_only", export.code == 0 && written?["product"] as? String == AppIdentity.bundleID
              && (written?["values"] as? [String: Any])?.keys.sorted() == ["file.0.protectedApps"] && run("config", "export", "-o", exported.path).code == 2)
        let usage = run("config", "sync", "maybe")
        check("usage_error_exit_2_json_and_stderr", usage.code == 2 && (usage.body["error"] as? [String: Any])?["code"] as? String == "usage"
              && usage.body["ok"] as? Bool == false && usage.stderr.contains("用 --help 查看用法"))
        let text = CLI.help(help)
        check("help_lists_every_lifecycle_subcommand", ["\n  config status", "\n  config export", "\n  update check", "\n  config import", "\n  config sync on|off"].allSatisfy(text.contains)
              && text.components(separatedBy: "暂无命令").last?.contains("升级到新版") == true && CLI.windowOnly.allSatisfy { text.contains($0.name) })

        check("owner_policy_preferences_and_sync_state_untouched", owned.map(stamp) == ownedBefore)
        facts["not_followed"] = unfollowed
        facts["commands_run"] = commands
        return report(checks, order, facts, outDir: outDir)
    }

    private static func report(_ checks: [String: Bool], _ order: [String], _ facts: [String: Any], outDir: URL) -> Bool {
        let passed = !checks.isEmpty && checks.values.allSatisfy { $0 }
        var result: [String: Any] = ["ok": passed, "checks": checks, "failed": order.filter { checks[$0] == false }, "count": checks.count,
                                     "screenshots": ["lifecycle-settings.png"],
                                     "not_covered": ["the owner's real iCloud Drive and preference domain", "update check (reads the network)",
                                                     "a physical click on the window's switch", "AppKit menu tracking"]]
        facts.forEach { result[$0.key] = $0.value }
        if let data = try? JSONSerialization.data(withJSONObject: result, options: .sortedKeys) { print(String(decoding: data, as: UTF8.self)) }
        return passed
    }
}
