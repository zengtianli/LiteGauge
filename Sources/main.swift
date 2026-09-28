import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
let version = "0.1.1"

func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    FileHandle.standardOutput.write(data)
    print("")
}

if arguments == ["--version"] {
    print("LiteGauge \(version)")
} else if arguments.first == "status", arguments == ["status"] || arguments == ["status", "--json"] {
    let sampler = MetricsSampler()
    _ = sampler.sample()
    Thread.sleep(forTimeInterval: 1)
    let snapshot = sampler.sample()
    if arguments.contains("--json") { try printJSON(snapshot) }
    else {
        print(MetricFormat.status(snapshot))
        if let m = snapshot.memory { print("内存 \(MetricFormat.gib(m.usedBytes)) / \(MetricFormat.gib(m.totalBytes)) · 压力\(m.pressure)") }
        if let d = snapshot.disk { print("磁盘剩余 \(MetricFormat.gb(d.availableBytes)) / \(MetricFormat.gb(d.totalBytes))") }
    }
    if !snapshot.errors.isEmpty { exit(1) }
} else if arguments == ["--help"] {
    print("轻仪 LiteGauge \(version) — 极简 CPU / 内存 / 磁盘监控\n用法：LiteGauge [status [--json] | --ui-self-test [目录] | --version | --help]\n无参数启动菜单栏。退出码：0 成功，1 采集失败，2 参数错误。")
} else if arguments.first == "--snapshot", arguments.count == 2 {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    try renderSnapshot(to: arguments[1])
} else if arguments.first == "--ui-self-test", arguments.count <= 2 {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let out = URL(fileURLWithPath: arguments.count == 2 ? arguments[1] : NSTemporaryDirectory(), isDirectory: true)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    exit(AppDelegate(benchmark: nil).runUISelfTest(outDir: out) ? 0 : 1)
} else if arguments.isEmpty || arguments == ["--background"] || (arguments.first == "--benchmark" && arguments.count == 2) {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate(benchmark: arguments.first == "--benchmark" ? arguments[1] : nil)
    app.delegate = delegate
    app.run()
    withExtendedLifetime(delegate) {}
} else {
    FileHandle.standardError.write(Data("未知参数；用 --help 查看用法。\n".utf8))
    exit(2)
}
