import SwiftUI
import AppKit

let appVersion = "1.2.0"

// MARK: - helpers
let dataDir: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let u = base.appendingPathComponent("bluFPS")
    try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}()

@discardableResult
func sh(_ cmd: String) -> (out: String, code: Int32) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/bash")
    p.arguments = ["-c", cmd]
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return ("", -1) }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (String(data: data, encoding: .utf8) ?? "", p.terminationStatus)
}
func q(_ s: String) -> String { return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
func osa(_ script: String) -> (out: String, code: Int32) { return sh("osascript -e " + q(script) + " 2>&1") }
func bg(_ work: @escaping () -> Void) { DispatchQueue.global(qos: .userInitiated).async(execute: work) }
func ui(_ work: @escaping () -> Void) { DispatchQueue.main.async(execute: work) }
func trimmed(_ s: String) -> String { return s.trimmingCharacters(in: .whitespacesAndNewlines) }
func home(_ rel: String) -> String { return NSHomeDirectory() + "/" + rel }
func fmtSize(_ b: Double) -> String {
    if b >= 1_073_741_824 { return String(format: "%.1f GB", b / 1_073_741_824) }
    if b >= 1_048_576 { return String(format: "%.0f MB", b / 1_048_576) }
    if b >= 1024 { return String(format: "%.0f KB", b / 1024) }
    return String(format: "%.0f B", b)
}
func versionParts(_ s: String) -> [Int] {
    return s.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0) ?? 0 }
}
func isNewer(_ a: String, than b: String) -> Bool {
    let x = versionParts(a)
    let y = versionParts(b)
    for i in 0..<max(x.count, y.count) {
        let p = i < x.count ? x[i] : 0
        let r = i < y.count ? y[i] : 0
        if p != r { return p > r }
    }
    return false
}
@discardableResult
func ask(_ title: String, _ text: String, _ buttons: [String] = ["OK"]) -> Int {
    let a = NSAlert()
    a.messageText = title
    a.informativeText = text
    for b in buttons { a.addButton(withTitle: b) }
    let r = a.runModal()
    return r.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
}
func acfValue(_ text: String, _ key: String) -> String {
    for line in text.components(separatedBy: "\n") where line.contains("\"" + key + "\"") {
        let p = line.components(separatedBy: "\"")
        if p.count >= 4 { return p[3] }
    }
    return ""
}

// MARK: - theme and small views
enum Theme {
    static let bg1 = Color(red: 0.027, green: 0.043, blue: 0.094)
    static let bg2 = Color(red: 0.047, green: 0.090, blue: 0.220)
    static let card = Color(red: 0.067, green: 0.102, blue: 0.200)
    static let line = Color(red: 0.120, green: 0.170, blue: 0.330)
    static let btn = Color(red: 0.094, green: 0.141, blue: 0.322)
    static let accent = Color(red: 0.180, green: 0.480, blue: 1.000)
    static let muted = Color(red: 0.490, green: 0.560, blue: 0.740)
    static let ok = Color(red: 0.240, green: 0.860, blue: 0.590)
    static let warn = Color(red: 0.960, green: 0.770, blue: 0.260)
    static let bad = Color(red: 1.000, green: 0.420, blue: 0.420)
}
struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
    }
}
struct PillStyle: ButtonStyle {
    var go: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(go ? Theme.accent : Theme.btn))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
struct Page<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content
    init(_ title: String, _ subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                Text(subtitle).font(.system(size: 13)).foregroundColor(Theme.muted)
                content
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
struct Bar: View {
    let value: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(Theme.accent).frame(width: g.size.width * CGFloat(min(max(value, 0), 1)))
            }
        }
        .frame(height: 6)
    }
}
struct StatCard: View {
    let title: String
    let value: String
    let bar: Double?
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.muted)
                Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(.white).lineLimit(2)
                if let b = bar { Bar(value: b) }
            }
        }
    }
}
func label(_ s: String) -> some View {
    return Text(s.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.muted)
}
func muted(_ s: String) -> some View {
    return Text(s).font(.system(size: 12)).foregroundColor(Theme.muted).fixedSize(horizontal: false, vertical: true)
}

// MARK: - settings
let knownApps: [(String, Bool)] = [
    ("Microsoft Teams", true), ("Slack", true), ("zoom.us", true), ("Dropbox", true), ("OneDrive", true),
    ("Google Drive", true), ("Creative Cloud", true), ("Skype", true), ("Spotify", false), ("Discord", false),
    ("Google Chrome", false), ("Safari", false), ("Firefox", false), ("Microsoft Edge", false)
]
final class Prefs: ObservableObject {
    @Published var autoCheck: Bool { didSet { save() } }
    @Published var quitApps: Bool { didSet { save() } }
    @Published var preventSleep: Bool { didSet { save() } }
    @Published var purge: Bool { didSet { save() } }
    @Published var restoreApps: Bool { didSet { save() } }
    @Published var eco: Bool { didSet { save() } }
    @Published var probal: Bool { didSet { save() } }
    @Published var pause: Bool { didSet { save() } }
    @Published var maxBoost: Bool { didSet { save() } }
    @Published var hud: Bool { didSet { save() } }
    @Published var killList: [String] { didSet { save() } }
    @Published var customKill: [String] { didSet { save() } }
    @Published var source: String { didSet { save() } }
    @Published var skipVersion: String { didSet { save() } }
    init() {
        let d = UserDefaults.standard
        autoCheck = d.object(forKey: "autoCheck") as? Bool ?? true
        quitApps = d.object(forKey: "quitApps") as? Bool ?? false
        preventSleep = d.object(forKey: "preventSleep") as? Bool ?? true
        purge = d.object(forKey: "purge") as? Bool ?? false
        restoreApps = d.object(forKey: "restoreApps") as? Bool ?? true
        eco = d.object(forKey: "eco") as? Bool ?? true
        probal = d.object(forKey: "probal") as? Bool ?? true
        pause = d.object(forKey: "pause") as? Bool ?? true
        maxBoost = d.object(forKey: "maxBoost") as? Bool ?? false
        hud = d.object(forKey: "hud") as? Bool ?? false
        killList = d.stringArray(forKey: "killList") ?? knownApps.filter { $0.1 }.map { $0.0 }
        customKill = d.stringArray(forKey: "customKill") ?? []
        source = d.string(forKey: "source") ?? Prefs.bundledSource()
        skipVersion = d.string(forKey: "skipVersion") ?? ""
    }
    static func bundledSource() -> String {
        guard let p = Bundle.main.resourcePath, let t = try? String(contentsOfFile: p + "/update-source.txt", encoding: .utf8) else { return "" }
        for line in t.components(separatedBy: "\n") {
            let l = trimmed(line)
            if !l.isEmpty && !l.hasPrefix("#") { return l }
        }
        return ""
    }
    func save() {
        let d = UserDefaults.standard
        d.set(autoCheck, forKey: "autoCheck")
        d.set(quitApps, forKey: "quitApps")
        d.set(preventSleep, forKey: "preventSleep")
        d.set(purge, forKey: "purge")
        d.set(restoreApps, forKey: "restoreApps")
        d.set(eco, forKey: "eco")
        d.set(probal, forKey: "probal")
        d.set(pause, forKey: "pause")
        d.set(maxBoost, forKey: "maxBoost")
        d.set(hud, forKey: "hud")
        d.set(killList, forKey: "killList")
        d.set(customKill, forKey: "customKill")
        d.set(source, forKey: "source")
        d.set(skipVersion, forKey: "skipVersion")
    }
    func setLevel(_ n: Int) {
        quitApps = false
        preventSleep = true
        restoreApps = true
        purge = n == 2
        eco = n >= 1
        probal = n >= 1
        pause = n >= 1
        maxBoost = n == 2
        hud = n == 2
    }
    func planText() -> String {
        var l: [String] = []
        if quitApps { l.append("- Quit the background apps ticked in Settings") }
        if purge { l.append("- Free up memory (asks for your password)") }
        if preventSleep { l.append("- Keep the screen and Mac awake while you play") }
        if eco { l.append("- Efficiency mode: other apps move to the efficient cores") }
        if probal { l.append("- Stop CPU hogs while you play (ProBalance)") }
        if pause { l.append("- Pause Photos / media background analysis") }
        if maxBoost { l.append("- Raise the game priority (one password prompt)") }
        if hud { l.append("- Show the Metal FPS overlay") }
        l.append("- Launch the game")
        if restoreApps { l.append("- Reopen your apps when you quit the game") }
        return l.joined(separator: "\n")
    }
}

// MARK: - dashboard stats
final class StatsModel: ObservableObject {
    @Published var cpu: Double = 0
    @Published var ram: Double = 0
    @Published var disk: String = "--"
    @Published var diskUsed: Double = 0
    @Published var battery: String = "n/a"
    @Published var ping: String = "--"
    @Published var chip: String = ""
    private var timer: Timer?
    func start() {
        chip = trimmed(sh("sysctl -n machdep.cpu.brand_string").out) + "  |  " + fmtSize(Double(ProcessInfo.processInfo.physicalMemory)) + " RAM"
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func refresh() {
        bg {
            let cores = Double(ProcessInfo.processInfo.activeProcessorCount)
            let cpuRaw = Double(trimmed(sh("ps -A -o %cpu | awk 'NR>1 {s+=$1} END {print s}'").out)) ?? 0
            let vm = sh("vm_stat").out
            let pageSize = Double(trimmed(sh("sysctl -n hw.pagesize").out)) ?? 4096
            func pages(_ key: String) -> Double {
                for line in vm.components(separatedBy: "\n") where line.hasPrefix(key) {
                    let digits = line.filter { "0123456789".contains($0) }
                    return Double(digits) ?? 0
                }
                return 0
            }
            let used = (pages("Pages active") + pages("Pages wired down") + pages("Pages occupied by compressor")) * pageSize
            let total = Double(ProcessInfo.processInfo.physicalMemory)
            var diskText = "--"
            var diskFrac = 0.0
            if let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]) {
                let avail = Double(v.volumeAvailableCapacityForImportantUsage ?? 0)
                let tot = Double(v.volumeTotalCapacity ?? 1)
                diskText = fmtSize(avail) + " free of " + fmtSize(tot)
                diskFrac = 1 - avail / max(tot, 1)
            }
            let bat = trimmed(sh("pmset -g batt | grep -Eo '[0-9]+%' | head -1").out)
            let pr = trimmed(sh("ping -c 1 -t 2 1.1.1.1 | awk -F'time=' '/time=/{print $2}'").out)
            ui {
                self.cpu = min(cpuRaw / max(cores, 1), 100) / 100
                self.ram = min(used / max(total, 1), 1)
                self.disk = diskText
                self.diskUsed = diskFrac
                self.battery = bat.isEmpty ? "Plugged in (no battery)" : bat
                self.ping = pr.isEmpty ? "no reply" : pr
            }
        }
    }
}

// MARK: - games
struct Game: Identifiable, Hashable {
    let id: String
    let name: String
    let launcher: String
    let launch: String
    let dir: String
    let steamId: String
}
final class GamesModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var selected: Game? = nil
    @Published var status: String = "No boost active."
    @Published var scanMsg: String = ""
    @Published var active: Game? = nil
    var closedApps: [String] = []
    var throttled: [Int32] = []
    var paused = false
    var prefsRef: Prefs? = nil
    var adminDone = false
    var tickN = 0
    static let keepNames = ["Discord", "OBS", "zoom.us", "Teams", "Slack", "Steam", "Epic Games", "TeamSpeak"]
    static let protectedNames = ["windowserver", "kernel_task", "coreaudiod", "audiomxd", "loginwindow", "finder", "dock", "systemuiserver", "blufps", "discord", "obs", "zoom.us", "steam", "epicgames", "teamspeak", "launchd", "controlcenter", "notificationcenter", "caffeinate"]
    var caff: Process? = nil
    var timer: Timer? = nil
    var started = Date()
    var seen = false
    var misses = 0
    var restore = true

    func scan() {
        ui { self.scanMsg = "Scanning your Mac..." }
        bg {
            var list: [Game] = []
            let fm = FileManager.default
            let steam = home("Library/Application Support/Steam")
            var libs: [String] = [steam]
            if let vdf = try? String(contentsOfFile: steam + "/steamapps/libraryfolders.vdf", encoding: .utf8) {
                for line in vdf.components(separatedBy: "\n") where line.contains("\"path\"") {
                    let parts = line.components(separatedBy: "\"")
                    if parts.count >= 4 { libs.append(parts[3]) }
                }
            }
            var seenLibs = Set<String>()
            for lib in libs {
                if seenLibs.contains(lib) { continue }
                seenLibs.insert(lib)
                let apps = lib + "/steamapps"
                guard let files = try? fm.contentsOfDirectory(atPath: apps) else { continue }
                for f in files where f.hasPrefix("appmanifest_") && f.hasSuffix(".acf") {
                    guard let t = try? String(contentsOfFile: apps + "/" + f, encoding: .utf8) else { continue }
                    let id = acfValue(t, "appid")
                    let name = acfValue(t, "name")
                    let dir = acfValue(t, "installdir")
                    if id.isEmpty || name.isEmpty || dir.isEmpty { continue }
                    if name.hasPrefix("Steamworks Common") || name.hasPrefix("Steam Linux Runtime") || name.hasPrefix("Proton") { continue }
                    if !fm.fileExists(atPath: apps + "/common/" + dir) { continue }
                    list.append(Game(id: "steam-" + id, name: name, launcher: "Steam", launch: "steam://rungameid/" + id, dir: apps + "/common/" + dir, steamId: id))
                }
            }
            // Epic Games Launcher
            let epicDir = home("Library/Application Support/Epic/EpicGamesLauncher/Data/Manifests")
            if let items = try? fm.contentsOfDirectory(atPath: epicDir) {
                for f in items where f.hasSuffix(".item") {
                    guard let data = fm.contents(atPath: epicDir + "/" + f),
                          let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }
                    let name = (obj["DisplayName"] as? String) ?? ""
                    let loc = (obj["InstallLocation"] as? String) ?? ""
                    let an = (obj["AppName"] as? String) ?? ""
                    let ns = (obj["CatalogNamespace"] as? String) ?? ""
                    let ci = (obj["CatalogItemId"] as? String) ?? ""
                    let mainName = (obj["MainGameAppName"] as? String) ?? ""
                    if name.isEmpty || loc.isEmpty || an.isEmpty || !fm.fileExists(atPath: loc) { continue }
                    if !mainName.isEmpty && mainName != an { continue }
                    list.append(Game(id: "epic-" + an, name: name, launcher: "Epic", launch: "com.epicgames.launcher://apps/" + ns + "%3A" + ci + "%3A" + an + "?action=launch&silent=true", dir: loc, steamId: ""))
                }
            }
            var appPaths: [String] = UserDefaults.standard.stringArray(forKey: "manualGames") ?? []
            for base in ["/Applications", home("Applications")] {
                guard let items = try? fm.contentsOfDirectory(atPath: base) else { continue }
                for it in items where it.hasSuffix(".app") {
                    let path = base + "/" + it
                    if let b = Bundle(path: path), let cat = b.infoDictionary?["LSApplicationCategoryType"] as? String, cat.lowercased().contains("games") {
                        appPaths.append(path)
                    }
                }
            }
            // folders the user chose (any drive): apps up to three levels deep
            var unreadable = 0
            for folder in UserDefaults.standard.stringArray(forKey: "scanFolders") ?? [] {
                guard fm.fileExists(atPath: folder),
                      let en = fm.enumerator(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil, options: [.skipsPackageDescendants, .skipsHiddenFiles]) else { unreadable += 1; continue }
                for case let url as URL in en {
                    if en.level > 3 { en.skipDescendants(); continue }
                    if url.pathExtension == "app" { appPaths.append(url.path) }
                }
            }
            var seenApps = Set<String>()
            for path in appPaths {
                if seenApps.contains(path) { continue }
                seenApps.insert(path)
                if list.contains(where: { path.hasPrefix($0.dir + "/") }) { continue }
                let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
                list.append(Game(id: "app-" + path, name: name, launcher: "Mac app", launch: path, dir: path, steamId: ""))
            }
            // one game, one entry (launchers first, then plain apps); respect games the user removed
            let hidden = Set(UserDefaults.standard.stringArray(forKey: "hiddenGames") ?? [])
            var seenNames = Set<String>()
            var uniq: [Game] = []
            for g in list {
                if hidden.contains(g.id) { continue }
                let key = g.name.lowercased().filter { $0.isLetter || $0.isNumber }
                if key.count >= 4 && seenNames.contains(key) { continue }
                seenNames.insert(key)
                uniq.append(g)
            }
            uniq.sort { $0.name.lowercased() < $1.name.lowercased() }
            var msg = uniq.isEmpty ? "No games found. Use Scan a folder or Add game to point bluFPS at them." : "Scan finished: " + String(uniq.count) + " games found."
            if unreadable > 0 { msg += " " + String(unreadable) + " folder(s) could not be read." }
            ui { self.games = uniq; self.scanMsg = msg }
        }
    }
    func addGame() {
        let p = NSOpenPanel()
        p.allowedFileTypes = ["app"]
        p.directoryURL = URL(fileURLWithPath: "/Applications")
        p.message = "Choose the game (.app) to add"
        if p.runModal() == .OK, let url = p.url {
            var arr = UserDefaults.standard.stringArray(forKey: "manualGames") ?? []
            if !arr.contains(url.path) { arr.append(url.path) }
            UserDefaults.standard.set(arr, forKey: "manualGames")
            var hid = UserDefaults.standard.stringArray(forKey: "hiddenGames") ?? []
            hid.removeAll { $0 == "app-" + url.path }
            UserDefaults.standard.set(hid, forKey: "hiddenGames")
            scan()
        }
    }
    func addFolder() {
        let p = NSOpenPanel()
        p.canChooseFiles = false
        p.canChooseDirectories = true
        p.allowsMultipleSelection = false
        p.message = "Choose a folder that contains your games"
        if p.runModal() == .OK, let url = p.url {
            var arr = UserDefaults.standard.stringArray(forKey: "scanFolders") ?? []
            if !arr.contains(url.path) { arr.append(url.path) }
            UserDefaults.standard.set(arr, forKey: "scanFolders")
            scan()
        }
    }
    func removeGame(_ g: Game) {
        var man = UserDefaults.standard.stringArray(forKey: "manualGames") ?? []
        man.removeAll { $0 == g.dir }
        UserDefaults.standard.set(man, forKey: "manualGames")
        var hid = UserDefaults.standard.stringArray(forKey: "hiddenGames") ?? []
        if !hid.contains(g.id) { hid.append(g.id) }
        UserDefaults.standard.set(hid, forKey: "hiddenGames")
        if selected == g { selected = nil }
        scan()
    }
    func resetRemoved() {
        UserDefaults.standard.removeObject(forKey: "hiddenGames")
        scan()
    }
    func play(_ g: Game, prefs: Prefs) {
        if active != nil { status = "A boost is already active. Press Restore first."; return }
        active = g
        prefsRef = prefs
        restore = prefs.restoreApps
        adminDone = false
        tickN = 0
        status = "Boosting " + g.name + "..."
        var closed: [String] = []
        if prefs.quitApps {
            let names = prefs.killList + prefs.customKill
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                let n = app.localizedName ?? ""
                if n.isEmpty || n == "Finder" || app.bundleIdentifier == Bundle.main.bundleIdentifier { continue }
                if names.contains(where: { n.localizedCaseInsensitiveContains($0) }) {
                    if let p = app.bundleURL?.path { closed.append(p) }
                    app.terminate()
                }
            }
        }
        closedApps = closed
        let delay: Double = closed.isEmpty ? 0.2 : 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.boostSystem(g, prefs: prefs, closedCount: closed.count)
        }
    }
    func boostSystem(_ g: Game, prefs: Prefs, closedCount: Int) {
        var pids: [Int32] = []
        if prefs.eco {
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                let n = app.localizedName ?? ""
                if n.isEmpty || app.bundleIdentifier == Bundle.main.bundleIdentifier { continue }
                if GamesModel.keepNames.contains(where: { n.localizedCaseInsensitiveContains($0) }) { continue }
                pids.append(app.processIdentifier)
            }
        }
        throttled = pids
        if prefs.pause { paused = true }
        if prefs.preventSleep {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            p.arguments = ["-d", "-i", "-m"]
            try? p.run()
            caff = p
        }
        var cmds: [String] = []
        for pid in pids { cmds.append("taskpolicy -b -p " + String(pid) + " 2>/dev/null; renice -n 10 -p " + String(pid) + " 2>/dev/null") }
        if prefs.pause { cmds.append("killall -STOP photoanalysisd mediaanalysisd 2>/dev/null") }
        if prefs.hud { cmds.append("launchctl setenv MTL_HUD_ENABLED 1") }
        let setup = cmds.joined(separator: "; ")
        bg {
            if !setup.isEmpty { sh(setup) }
            ui {
                if g.launch.contains("://"), let url = URL(string: g.launch) { NSWorkspace.shared.open(url) }
                else { NSWorkspace.shared.open(URL(fileURLWithPath: g.launch)) }
                self.started = Date()
                self.seen = false
                self.misses = 0
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
                self.status = g.name + ": launching... (quit " + String(closedCount) + " app(s), eased " + String(pids.count) + ")"
                if prefs.purge && !prefs.maxBoost { bg { _ = osa("do shell script \"purge\" with administrator privileges") } }
            }
        }
    }
    func tick() {
        guard let g = active else { return }
        tickN += 1
        let n = tickN
        let prefs = prefsRef
        bg {
            let out = sh("ps -Axo uid=,pid=,pcpu=,command=").out
            let needle = g.dir + "/"
            let myUid = String(getuid())
            var running = false
            var gamePid: Int32 = 0
            var hogs: [Int32] = []
            for line in out.components(separatedBy: "\n") {
                let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
                if parts.count < 4 { continue }
                let cmd = String(parts[3])
                if cmd.contains(needle) {
                    running = true
                    if gamePid == 0 { gamePid = Int32(parts[1]) ?? 0 }
                    continue
                }
                if prefs?.probal == true && n % 2 == 0 && String(parts[0]) == myUid {
                    let cpu = Double(parts[2]) ?? 0
                    if cpu > 60 {
                        let pid = Int32(parts[1]) ?? 0
                        let lower = cmd.lowercased()
                        var skip = false
                        for k in GamesModel.protectedNames where lower.contains(k) { skip = true }
                        if !skip && pid != getpid() && pid > 0 { hogs.append(pid) }
                    }
                }
            }
            ui {
                if running {
                    self.seen = true
                    self.misses = 0
                    self.status = g.name + ": boost active. It ends when you quit the game."
                    if gamePid != 0, !self.adminDone, let pf = prefs, pf.maxBoost {
                        self.adminDone = true
                        let cmd = (pf.purge ? "purge; " : "") + "renice -n -10 -p " + String(gamePid)
                        bg { _ = osa("do shell script \"" + cmd + "\" with administrator privileges") }
                    }
                } else if self.seen {
                    self.misses += 1
                    if self.misses >= 2 { self.end(keepStatus: false) }
                } else if Date().timeIntervalSince(self.started) > 240 {
                    self.status = "Could not find " + g.name + " running, so the boost ended."
                    self.end(keepStatus: true)
                } else {
                    self.status = g.name + ": waiting for the game to start..."
                }
                if !hogs.isEmpty {
                    let fresh = hogs.filter { !self.throttled.contains($0) }
                    self.throttled += fresh
                    bg { for p in fresh { sh("taskpolicy -b -p " + String(p) + " 2>/dev/null; renice -n 10 -p " + String(p) + " 2>/dev/null") } }
                }
            }
        }
    }
    func end(keepStatus: Bool) {
        timer?.invalidate()
        timer = nil
        caff?.terminate()
        caff = nil
        let name = active?.name ?? ""
        active = nil
        let pids = throttled
        let wasPaused = paused
        throttled = []
        paused = false
        bg {
            for p in pids { sh("taskpolicy -B -p " + String(p) + " 2>/dev/null") }
            if wasPaused { sh("killall -CONT photoanalysisd mediaanalysisd 2>/dev/null") }
            sh("launchctl unsetenv MTL_HUD_ENABLED 2>/dev/null")
        }
        if restore {
            for path in closedApps {
                let cfg = NSWorkspace.OpenConfiguration()
                cfg.activates = false
                NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: cfg, completionHandler: nil)
            }
        }
        closedApps = []
        if !keepStatus { status = "Restored your Mac after " + name + "." }
    }
}

struct GamesView: View {
    @EnvironmentObject var gm: GamesModel
    @EnvironmentObject var prefs: Prefs
    var body: some View {
        Page("Games", "Pick a game and press Boost and Play. bluFPS frees up your Mac, launches the game, and puts everything back when you quit.") {
            HStack(spacing: 10) {
                Button("Rescan") { gm.scan() }.buttonStyle(PillStyle())
                Button("Scan a folder...") { gm.addFolder() }.buttonStyle(PillStyle())
                Button("Add game...") { gm.addGame() }.buttonStyle(PillStyle())
                Button("Show removed games") { gm.resetRemoved() }.buttonStyle(PillStyle())
                Text(gm.scanMsg.isEmpty ? (gm.games.isEmpty ? "No games found yet. Steam, Epic and Mac apps filed under Games appear here." : String(gm.games.count) + " games") : gm.scanMsg)
                    .font(.system(size: 12)).foregroundColor(Theme.muted)
            }
            HStack(alignment: .top, spacing: 14) {
                Card { listView }
                Card { detailView }.frame(width: 330)
            }
        }
    }
    var listView: some View {
        LazyVStack(spacing: 6) {
            ForEach(gm.games) { g in
                Button(action: { gm.selected = g }) { row(g) }.buttonStyle(PlainButtonStyle())
            }
        }
    }
    func row(_ g: Game) -> some View {
        HStack(spacing: 12) {
            thumb(g, 92, 43)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.name).font(.system(size: 14, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Text(g.launcher + (FileManager.default.fileExists(atPath: g.dir) ? "  -  Ready for Game Boost" : "  -  Not found (moved or uninstalled)")).font(.system(size: 11)).foregroundColor(Theme.muted)
            }
            Spacer()
        }
        .padding(8)
        .background(gm.selected == g ? Theme.accent.opacity(0.35) : Color.white.opacity(0.03))
        .cornerRadius(10)
    }
    @ViewBuilder func thumb(_ g: Game, _ w: CGFloat, _ h: CGFloat) -> some View {
        if !g.steamId.isEmpty {
            AsyncImage(url: URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/" + g.steamId + "/header.jpg")) { phase in
                if let img = phase.image { img.resizable().scaledToFill() } else { Theme.btn }
            }
            .frame(width: w, height: h).clipped().cornerRadius(8)
        } else {
            Image(nsImage: NSWorkspace.shared.icon(forFile: g.dir)).resizable().scaledToFit().frame(width: w, height: h)
        }
    }
    var detailView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let g = gm.selected {
                thumb(g, 296, 138)
                Text(g.name).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text(g.launcher + "  -  " + g.dir).font(.system(size: 11)).foregroundColor(Theme.muted).lineLimit(2)
                label("When you boost")
                Text(prefs.planText()).font(.system(size: 12)).foregroundColor(Color(white: 0.85)).fixedSize(horizontal: false, vertical: true)
                Button("BOOST AND PLAY") { gm.play(g, prefs: prefs) }.buttonStyle(PillStyle(go: true)).disabled(gm.active != nil)
                Button("Show in Finder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: g.dir) }.buttonStyle(PillStyle())
                Button("Remove from list") { gm.removeGame(g) }.buttonStyle(PillStyle())
            } else {
                Text("Pick a game").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            }
            if gm.active != nil { Button("Restore my Mac now") { gm.end(keepStatus: false) }.buttonStyle(PillStyle()) }
            Text(gm.status).font(.system(size: 12)).foregroundColor(gm.active != nil ? Theme.ok : Theme.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - boost (apps)
struct RunApp: Identifiable {
    let id: String
    let name: String
    let path: String
}
struct BoostView: View {
    @EnvironmentObject var prefs: Prefs
    @State var apps: [RunApp] = []
    @State var picked: Set<String> = []
    @State var reopen: [String] = []
    @State var msg: String = ""
    var body: some View {
        Page("Boost", "Quit apps you are not using, or free memory. Game boosts use the same tools automatically.") {
            HStack(spacing: 10) {
                Button("Refresh") { load() }.buttonStyle(PillStyle())
                Button("Quit selected apps") { quitPicked() }.buttonStyle(PillStyle(go: true))
                Button("Reopen what I quit") { reopenApps() }.buttonStyle(PillStyle())
                Button("Free up memory") { freeMemory() }.buttonStyle(PillStyle())
            }
            if !msg.isEmpty { Text(msg).font(.system(size: 12)).foregroundColor(Theme.ok) }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    label("Open apps")
                    ForEach(apps) { a in
                        Toggle(isOn: Binding(get: { picked.contains(a.id) }, set: { on in if on { picked.insert(a.id) } else { picked.remove(a.id) } })) {
                            Text(a.name).foregroundColor(.white)
                        }
                        .toggleStyle(SwitchToggleStyle())
                    }
                }
            }
        }
        .onAppear { load() }
    }
    func load() {
        var list: [RunApp] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let n = app.localizedName ?? ""
            if n.isEmpty || n == "Finder" || app.bundleIdentifier == Bundle.main.bundleIdentifier { continue }
            list.append(RunApp(id: app.bundleIdentifier ?? n, name: n, path: app.bundleURL?.path ?? ""))
        }
        list.sort { $0.name.lowercased() < $1.name.lowercased() }
        apps = list
    }
    func quitPicked() {
        var count = 0
        for a in apps where picked.contains(a.id) {
            for r in NSRunningApplication.runningApplications(withBundleIdentifier: a.id) { r.terminate(); count += 1 }
            if !a.path.isEmpty { reopen.append(a.path) }
        }
        picked = []
        msg = "Asked " + String(count) + " app(s) to quit."
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { load() }
    }
    func reopenApps() {
        for p in reopen {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = false
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: p), configuration: cfg, completionHandler: nil)
        }
        msg = "Reopened " + String(reopen.count) + " app(s)."
        reopen = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { load() }
    }
    func freeMemory() {
        msg = "Freeing memory (macOS asks for your password)..."
        bg {
            let r = osa("do shell script \"purge\" with administrator privileges")
            ui { msg = r.code == 0 ? "Memory freed." : "Cancelled, or not allowed." }
        }
    }
}

// MARK: - network
struct RegionResult: Identifiable {
    let id: String
    let name: String
    let ms: Double
}
final class NetModel: ObservableObject {
    @Published var results: [RegionResult] = []
    @Published var testing = false
    @Published var note = ""
    let regions: [(String, String)] = [
        ("US East (N. Virginia)", "ec2.us-east-1.amazonaws.com"), ("US West (Oregon)", "ec2.us-west-2.amazonaws.com"),
        ("Europe (Frankfurt)", "ec2.eu-central-1.amazonaws.com"), ("Europe (London)", "ec2.eu-west-2.amazonaws.com"),
        ("Asia (Tokyo)", "ec2.ap-northeast-1.amazonaws.com"), ("Asia (Singapore)", "ec2.ap-southeast-1.amazonaws.com"),
        ("Asia (Mumbai)", "ec2.ap-south-1.amazonaws.com"), ("Oceania (Sydney)", "ec2.ap-southeast-2.amazonaws.com"),
        ("South America (Sao Paulo)", "ec2.sa-east-1.amazonaws.com")
    ]
    func test() {
        testing = true
        results = []
        let group = DispatchGroup()
        let lock = NSLock()
        var out: [RegionResult] = []
        for r in regions {
            group.enter()
            bg {
                var best = Double.infinity
                for _ in 0..<3 {
                    let t = trimmed(sh("curl -o /dev/null -s -m 4 -w '%{time_connect}' https://" + r.1 + "/").out)
                    if let v = Double(t), v > 0 { best = min(best, v * 1000) }
                }
                lock.lock()
                if best.isFinite { out.append(RegionResult(id: r.1, name: r.0, ms: best)) }
                lock.unlock()
                group.leave()
            }
        }
        group.notify(queue: .main) {
            self.results = out.sorted { $0.ms < $1.ms }
            self.testing = false
        }
    }
    func flushDNS() {
        note = "Flushing DNS (macOS asks for your password)..."
        bg {
            let r = osa("do shell script \"dscacheutil -flushcache; killall -HUP mDNSResponder\" with administrator privileges")
            ui { self.note = r.code == 0 ? "DNS cache flushed." : "Cancelled, or not allowed." }
        }
    }
}
struct NetworkView: View {
    @EnvironmentObject var net: NetModel
    var body: some View {
        Page("Network", "Latency to the cloud regions most online games use. Pick the closest one in your game's settings.") {
            HStack(spacing: 10) {
                Button(net.testing ? "Testing..." : "Test game regions") { net.test() }.buttonStyle(PillStyle(go: true)).disabled(net.testing)
                Button("Flush DNS") { net.flushDNS() }.buttonStyle(PillStyle())
                Text(net.note).font(.system(size: 12)).foregroundColor(Theme.ok)
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    if net.results.isEmpty { muted("Press Test game regions. Results are web round trips, a little higher than in-game ping.") }
                    ForEach(net.results) { r in
                        HStack {
                            Text(r.name + (r.id == net.results.first?.id ? "   closest" : "")).foregroundColor(.white).frame(width: 260, alignment: .leading)
                            Bar(value: max(0.04, 1 - r.ms / 300)).frame(maxWidth: .infinity)
                            Text(String(format: "%.0f ms", r.ms)).foregroundColor(r.ms < 60 ? Theme.ok : (r.ms < 120 ? Theme.warn : Theme.bad)).frame(width: 70, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - tools model
struct CleanCat: Identifiable {
    let id: String
    let name: String
    let desc: String
    var items: [String]
    var bytes: Double
    var on: Bool
    var isTrash: Bool
}
struct LoginItem: Identifiable {
    let id: String
    let name: String
    let path: String
}
struct AgentItem: Identifiable {
    let id: String
    let path: String
}
struct AppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let bundleId: String
}
struct Leftover: Identifiable {
    let id: String
    let path: String
    var on: Bool
}
struct ProcRow: Identifiable {
    let id: String
    let cpu: Double
    let mem: Double
}
struct BackupInfo: Identifiable {
    let id: String
    let path: String
}
final class ToolsModel: ObservableObject {
    @Published var cats: [CleanCat] = []
    @Published var cleanMsg = ""
    @Published var logins: [LoginItem] = []
    @Published var agents: [AgentItem] = []
    @Published var disabledAgents: [AgentItem] = []
    @Published var startMsg = ""
    @Published var apps: [AppInfo] = []
    @Published var selectedApp: AppInfo? = nil
    @Published var leftovers: [Leftover] = []
    @Published var unMsg = ""
    @Published var procs: [ProcRow] = []
    @Published var sortByMem = false
    @Published var backups: [BackupInfo] = []
    @Published var bkMsg = ""
    var backedUp = false
    var monTimer: Timer? = nil
    let fm = FileManager.default

    // ----- cleaner -----
    func buildCats() {
        func kids(_ dir: String, _ skipApple: Bool) -> [String] {
            let names = (try? fm.contentsOfDirectory(atPath: dir)) ?? []
            var out: [String] = []
            for n in names where !(skipApple && n.hasPrefix("com.apple.")) { out.append(dir + "/" + n) }
            return out
        }
        var c: [CleanCat] = []
        c.append(CleanCat(id: "caches", name: "App caches", desc: "Temporary data apps rebuild by themselves. System caches are left alone.", items: kids(home("Library/Caches"), true), bytes: 0, on: true, isTrash: false))
        c.append(CleanCat(id: "logs", name: "App logs", desc: "Log files left by apps.", items: kids(home("Library/Logs"), false), bytes: 0, on: true, isTrash: false))
        let browsers: [(String, String, String)] = [
            ("safari", "Safari cache", home("Library/Caches/com.apple.Safari")),
            ("chrome", "Google Chrome cache", home("Library/Caches/Google/Chrome")),
            ("firefox", "Firefox cache", home("Library/Caches/Firefox")),
            ("edge", "Microsoft Edge cache", home("Library/Caches/Microsoft Edge"))
        ]
        for b in browsers where fm.fileExists(atPath: b.2) {
            c.append(CleanCat(id: b.0, name: b.1, desc: "Saved pages and images. Passwords, cookies and history are NOT touched.", items: [b.2], bytes: 0, on: true, isTrash: false))
        }
        c.append(CleanCat(id: "trash", name: "Trash", desc: "Files you deleted. Look inside before emptying it!", items: [], bytes: 0, on: false, isTrash: true))
        cats = c
    }
    func scanClean() {
        cleanMsg = "Scanning..."
        let snapshot = cats
        bg {
            var result = snapshot
            for i in 0..<result.count {
                if result[i].isTrash {
                    let kb = Double(trimmed(sh("du -sk " + q(home(".Trash")) + " 2>/dev/null | awk '{print $1}'").out)) ?? 0
                    result[i].bytes = kb * 1024
                    continue
                }
                if result[i].items.isEmpty { continue }
                let args = result[i].items.map { q($0) }.joined(separator: " ")
                let lines = sh("du -sk " + args + " 2>/dev/null").out.components(separatedBy: "\n")
                var sum = 0.0
                for l in lines { if let first = l.split(separator: "\t").first, let v = Double(first) { sum += v } }
                result[i].bytes = sum * 1024
            }
            ui { self.cats = result; self.cleanMsg = "Scan finished." }
        }
    }
    func runClean() {
        let chosen = cats.filter { $0.on }
        if chosen.isEmpty { cleanMsg = "Switch on what you want to clean first."; return }
        let total = chosen.reduce(0.0) { $0 + $1.bytes }
        let r = ask("Clean up?", "Remove about " + fmtSize(total) + " from the selected categories?\n\nbluFPS never touches your documents, passwords, cookies or browsing history. Files in use are skipped.", ["Clean", "Cancel"])
        if r != 0 { return }
        cleanMsg = "Cleaning..."
        bg {
            for c in chosen {
                if c.isTrash { _ = osa("tell application \"Finder\" to empty trash"); continue }
                for p in c.items { try? self.fm.removeItem(atPath: p) }
            }
            ui {
                self.buildCats()
                self.cleanMsg = "Cleaned up about " + fmtSize(total) + "."
            }
        }
    }

    // ----- startup manager -----
    func loadStartup() {
        bg {
            let names = trimmed(osa("tell application \"System Events\" to get the name of every login item").out)
            let paths = trimmed(osa("tell application \"System Events\" to get the path of every login item").out)
            let n = names.isEmpty || names.contains("error") ? [] : names.components(separatedBy: ", ")
            let p = paths.isEmpty || paths.contains("error") ? [] : paths.components(separatedBy: ", ")
            var items: [LoginItem] = []
            for i in 0..<n.count { items.append(LoginItem(id: n[i], name: n[i], path: i < p.count ? p[i] : "")) }
            let agentDir = home("Library/LaunchAgents")
            let files = ((try? self.fm.contentsOfDirectory(atPath: agentDir)) ?? []).filter { $0.hasSuffix(".plist") }
            let off = ((try? self.fm.contentsOfDirectory(atPath: dataDir.path + "/disabled-agents")) ?? []).filter { $0.hasSuffix(".plist") }
            ui {
                self.logins = items
                self.agents = files.map { AgentItem(id: $0, path: agentDir + "/" + $0) }
                self.disabledAgents = off.map { AgentItem(id: $0, path: dataDir.path + "/disabled-agents/" + $0) }
            }
        }
    }
    func ensureBackup() {
        if backedUp { return }
        backedUp = true
        createBackup(label: "before startup changes")
    }
    func removeLogin(_ it: LoginItem) {
        ensureBackup()
        bg {
            let r = osa("tell application \"System Events\" to delete login item \"" + it.name + "\"")
            ui { self.startMsg = r.code == 0 ? it.name + " will no longer open at login." : "Could not change it: " + trimmed(r.out); self.loadStartup() }
        }
    }
    func addLogin() {
        let p = NSOpenPanel()
        p.allowedFileTypes = ["app"]
        p.directoryURL = URL(fileURLWithPath: "/Applications")
        if p.runModal() == .OK, let url = p.url {
            ensureBackup()
            bg {
                _ = osa("tell application \"System Events\" to make login item at end with properties {path:\"" + url.path + "\", hidden:false}")
                ui { self.loadStartup() }
            }
        }
    }
    func disableAgent(_ a: AgentItem) {
        ensureBackup()
        let dest = dataDir.path + "/disabled-agents"
        try? fm.createDirectory(atPath: dest, withIntermediateDirectories: true)
        bg {
            _ = sh("launchctl bootout gui/$(id -u) " + q(a.path) + " 2>/dev/null")
            _ = sh("mv " + q(a.path) + " " + q(dest + "/" + a.id))
            ui { self.startMsg = a.id + " is disabled. Restore it below any time."; self.loadStartup() }
        }
    }
    func enableAgent(_ a: AgentItem) {
        bg {
            let target = home("Library/LaunchAgents/" + a.id)
            _ = sh("mv " + q(a.path) + " " + q(target))
            _ = sh("launchctl bootstrap gui/$(id -u) " + q(target) + " 2>/dev/null")
            ui { self.startMsg = a.id + " is enabled again."; self.loadStartup() }
        }
    }

    // ----- uninstaller -----
    func loadApps() {
        bg {
            var list: [AppInfo] = []
            for base in ["/Applications", home("Applications")] {
                for it in (try? self.fm.contentsOfDirectory(atPath: base)) ?? [] where it.hasSuffix(".app") {
                    let path = base + "/" + it
                    let bid = Bundle(path: path)?.bundleIdentifier ?? ""
                    if bid.hasPrefix("com.apple.") || bid == Bundle.main.bundleIdentifier { continue }
                    list.append(AppInfo(id: path, name: String(it.dropLast(4)), path: path, bundleId: bid))
                }
            }
            list.sort { $0.name.lowercased() < $1.name.lowercased() }
            ui { self.apps = list }
        }
    }
    func findLeftovers(_ a: AppInfo) {
        let lib = home("Library")
        var cands: [String] = []
        for key in [a.bundleId, a.name] where !key.isEmpty {
            cands += [lib + "/Application Support/" + key, lib + "/Caches/" + key, lib + "/Preferences/" + key + ".plist", lib + "/Containers/" + key,
                      lib + "/Logs/" + key, lib + "/Saved Application State/" + key + ".savedState", lib + "/HTTPStorages/" + key, lib + "/WebKit/" + key,
                      lib + "/Application Scripts/" + key, lib + "/LaunchAgents/" + key + ".plist"]
        }
        var seenP = Set<String>()
        var out: [Leftover] = []
        for c in cands where fm.fileExists(atPath: c) && !seenP.contains(c) {
            seenP.insert(c)
            out.append(Leftover(id: c, path: c, on: true))
        }
        leftovers = out
        unMsg = out.isEmpty ? "No leftovers found for " + a.name + "." : "Found " + String(out.count) + " leftover item(s). Untick anything you want to keep."
    }
    func uninstall(_ a: AppInfo) {
        let chosen = leftovers.filter { $0.on }.map { $0.path }
        let r = ask("Uninstall " + a.name + "?", "The app and " + String(chosen.count) + " leftover item(s) go to the Trash, so you can still get them back until you empty it.", ["Move to Trash", "Cancel"])
        if r != 0 { return }
        for run in NSRunningApplication.runningApplications(withBundleIdentifier: a.bundleId) { run.terminate() }
        ensureBackup()
        let all = [a.path] + chosen
        let list = all.map { "POSIX file \"" + $0 + "\"" }.joined(separator: ", ")
        unMsg = "Moving to Trash..."
        bg {
            let res = osa("tell application \"Finder\" to delete {" + list + "}")
            ui {
                self.unMsg = res.code == 0 ? a.name + " and its leftovers are in the Trash." : "Could not finish: " + trimmed(res.out)
                self.selectedApp = nil
                self.leftovers = []
                self.loadApps()
            }
        }
    }

    // ----- monitor -----
    func startMonitor() {
        sample()
        monTimer?.invalidate()
        monTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.sample() }
    }
    func stopMonitor() { monTimer?.invalidate(); monTimer = nil }
    func sample() {
        let byMem = sortByMem
        bg {
            let out = sh("ps -Aceo pcpu=,rss=,comm=").out
            var cpu: [String: Double] = [:]
            var mem: [String: Double] = [:]
            for line in out.components(separatedBy: "\n") {
                let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                if parts.count < 3 { continue }
                let name = trimmed(String(parts[2]))
                cpu[name, default: 0] += Double(parts[0]) ?? 0
                mem[name, default: 0] += (Double(parts[1]) ?? 0) * 1024
            }
            var rows: [ProcRow] = []
            for (k, v) in cpu { rows.append(ProcRow(id: k, cpu: v, mem: mem[k] ?? 0)) }
            rows.sort { byMem ? $0.mem > $1.mem : $0.cpu > $1.cpu }
            let top = Array(rows.prefix(14))
            ui { self.procs = top }
        }
    }

    // ----- backup and restore -----
    func loadBackups() {
        let dir = dataDir.path + "/backups"
        let names = ((try? fm.contentsOfDirectory(atPath: dir)) ?? []).sorted(by: >)
        backups = names.map { BackupInfo(id: $0, path: dir + "/" + $0) }
    }
    func createBackup(label: String) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dir = dataDir.path + "/backups/" + df.string(from: Date()) + "_" + label.replacingOccurrences(of: " ", with: "-")
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        bg {
            let names = trimmed(osa("tell application \"System Events\" to get the path of every login item").out)
            try? names.write(toFile: dir + "/login-items.txt", atomically: true, encoding: .utf8)
            _ = sh("mkdir -p " + q(dir + "/LaunchAgents") + " && cp " + q(home("Library/LaunchAgents")) + "/*.plist " + q(dir + "/LaunchAgents") + "/ 2>/dev/null")
            ui { self.bkMsg = "Backup saved."; self.loadBackups() }
        }
    }
    func restoreBackup(_ b: BackupInfo) {
        let r = ask("Restore this backup?", "Login items and launch agents saved in this backup are put back. Anything added later is left alone.\n\n" + b.id, ["Restore", "Cancel"])
        if r != 0 { return }
        bg {
            let t = (try? String(contentsOfFile: b.path + "/login-items.txt", encoding: .utf8)) ?? ""
            let current = trimmed(osa("tell application \"System Events\" to get the path of every login item").out)
            for p in t.components(separatedBy: ", ") where !trimmed(p).isEmpty && !current.contains(trimmed(p)) {
                _ = osa("tell application \"System Events\" to make login item at end with properties {path:\"" + trimmed(p) + "\", hidden:false}")
            }
            _ = sh("mkdir -p " + q(home("Library/LaunchAgents")) + " && cp -n " + q(b.path + "/LaunchAgents") + "/*.plist " + q(home("Library/LaunchAgents")) + "/ 2>/dev/null")
            ui { self.bkMsg = "Backup restored. Log out and in for everything to apply." }
        }
    }
    func deleteBackup(_ b: BackupInfo) { try? fm.removeItem(atPath: b.path); loadBackups() }
    func snapshot() {
        bkMsg = "Creating a Time Machine local snapshot..."
        bg {
            let r = sh("tmutil localsnapshot 2>&1")
            ui { self.bkMsg = r.code == 0 ? "Snapshot created. Restore it from Time Machine." : "Could not create a snapshot: " + trimmed(r.out) }
        }
    }
}

// MARK: - tools views
struct ToolsView: View {
    @EnvironmentObject var t: ToolsModel
    @State var tab: Int = 0
    var body: some View {
        Page("Tools", "Clean up junk, speed up startup, remove apps for good, see what slows your Mac, and back up before you change anything.") {
            Picker("", selection: $tab) {
                Text("Cleaner").tag(0)
                Text("Startup").tag(1)
                Text("Uninstaller").tag(2)
                Text("Monitor").tag(3)
                Text("Backup").tag(4)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: 520)
            switch tab {
            case 0: CleanerView()
            case 1: StartupView()
            case 2: UninstallerView()
            case 3: MonitorView()
            default: BackupView()
            }
        }
    }
}
struct CleanerView: View {
    @EnvironmentObject var t: ToolsModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button("Scan") { t.scanClean() }.buttonStyle(PillStyle())
                Button("Clean selected") { t.runClean() }.buttonStyle(PillStyle(go: true))
                Button("Storage settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.settings.Storage")!) }.buttonStyle(PillStyle())
                Text(t.cleanMsg).font(.system(size: 12)).foregroundColor(Theme.ok)
            }
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(t.cats.indices, id: \.self) { i in
                        HStack(alignment: .top) {
                            Toggle(isOn: Binding(get: { t.cats[i].on }, set: { t.cats[i].on = $0 })) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.cats[i].name).foregroundColor(.white)
                                    Text(t.cats[i].desc).font(.system(size: 11)).foregroundColor(Theme.muted)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle())
                            Spacer()
                            Text(t.cats[i].bytes > 0 ? fmtSize(t.cats[i].bytes) : "").foregroundColor(Theme.accent)
                        }
                    }
                }
            }
        }
        .onAppear { if t.cats.isEmpty { t.buildCats() } }
    }
}
struct StartupView: View {
    @EnvironmentObject var t: ToolsModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button("Refresh") { t.loadStartup() }.buttonStyle(PillStyle())
                Button("Add an app...") { t.addLogin() }.buttonStyle(PillStyle())
                Text(t.startMsg).font(.system(size: 12)).foregroundColor(Theme.ok)
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    label("Opens when you log in")
                    if t.logins.isEmpty { muted("No login items found (macOS may ask for permission the first time).") }
                    ForEach(t.logins) { it in
                        HStack {
                            VStack(alignment: .leading) { Text(it.name).foregroundColor(.white); Text(it.path).font(.system(size: 11)).foregroundColor(Theme.muted) }
                            Spacer()
                            Button("Remove") { t.removeLogin(it) }.buttonStyle(PillStyle())
                        }
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    label("Background launch agents (yours)")
                    ForEach(t.agents) { a in
                        HStack { Text(a.id).foregroundColor(.white).lineLimit(1); Spacer(); Button("Disable") { t.disableAgent(a) }.buttonStyle(PillStyle()) }
                    }
                    if !t.disabledAgents.isEmpty { label("Disabled by bluFPS") }
                    ForEach(t.disabledAgents) { a in
                        HStack { Text(a.id).foregroundColor(Theme.muted).lineLimit(1); Spacer(); Button("Restore") { t.enableAgent(a) }.buttonStyle(PillStyle()) }
                    }
                }
            }
        }
        .onAppear { t.loadStartup() }
    }
}
struct UninstallerView: View {
    @EnvironmentObject var t: ToolsModel
    @State var search: String = ""
    var shown: [AppInfo] { return search.isEmpty ? t.apps : t.apps.filter { $0.name.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search your apps", text: $search).textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 360)
            HStack(alignment: .top, spacing: 14) {
                Card {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(shown) { a in
                            Button(action: { t.selectedApp = a; t.findLeftovers(a) }) {
                                HStack { Image(nsImage: NSWorkspace.shared.icon(forFile: a.path)).resizable().frame(width: 24, height: 24); Text(a.name).foregroundColor(.white); Spacer() }
                                    .padding(6)
                                    .background(t.selectedApp == a ? Theme.accent.opacity(0.35) : Color.clear)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        if let a = t.selectedApp {
                            Text(a.name).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                            Text(a.bundleId).font(.system(size: 11)).foregroundColor(Theme.muted)
                            Button("Uninstall (to Trash)") { t.uninstall(a) }.buttonStyle(PillStyle(go: true))
                            label("Leftovers found")
                            ForEach(t.leftovers.indices, id: \.self) { i in
                                Toggle(isOn: Binding(get: { t.leftovers[i].on }, set: { t.leftovers[i].on = $0 })) {
                                    Text(t.leftovers[i].path).font(.system(size: 11)).foregroundColor(Color(white: 0.85)).lineLimit(2)
                                }
                            }
                        } else { Text("Pick an app").foregroundColor(.white) }
                        Text(t.unMsg).font(.system(size: 12)).foregroundColor(Theme.ok).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(width: 340)
            }
        }
        .onAppear { if t.apps.isEmpty { t.loadApps() } }
    }
}
struct MonitorView: View {
    @EnvironmentObject var t: ToolsModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button("Sort by CPU") { t.sortByMem = false; t.sample() }.buttonStyle(PillStyle(go: !t.sortByMem))
                Button("Sort by memory") { t.sortByMem = true; t.sample() }.buttonStyle(PillStyle(go: t.sortByMem))
            }
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { label("App").frame(maxWidth: .infinity, alignment: .leading); label("CPU").frame(width: 80, alignment: .trailing); label("Memory").frame(width: 100, alignment: .trailing) }
                    ForEach(t.procs) { p in
                        HStack {
                            Text(p.id).foregroundColor(.white).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            Text(String(format: "%.1f%%", p.cpu)).foregroundColor(p.cpu > 50 ? Theme.bad : (p.cpu > 15 ? Theme.warn : Color(white: 0.85))).frame(width: 80, alignment: .trailing)
                            Text(fmtSize(p.mem)).foregroundColor(p.mem > 2_000_000_000 ? Theme.bad : (p.mem > 800_000_000 ? Theme.warn : Color(white: 0.85))).frame(width: 100, alignment: .trailing)
                        }
                    }
                    muted("CPU is shown per core, like Activity Monitor (200% means two cores fully busy).")
                }
            }
        }
        .onAppear { t.startMonitor() }
        .onDisappear { t.stopMonitor() }
    }
}
struct BackupView: View {
    @EnvironmentObject var t: ToolsModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button("Back up now") { t.createBackup(label: "manual") }.buttonStyle(PillStyle(go: true))
                Button("Time Machine snapshot") { t.snapshot() }.buttonStyle(PillStyle())
                Button("Open Time Machine") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Time Machine.app")) }.buttonStyle(PillStyle())
            }
            Text(t.bkMsg).font(.system(size: 12)).foregroundColor(Theme.ok)
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    label("Backups (made automatically before bluFPS changes startup items or removes apps)")
                    if t.backups.isEmpty { muted("No backups yet.") }
                    ForEach(t.backups) { b in
                        HStack {
                            Text(b.id).foregroundColor(.white).lineLimit(1)
                            Spacer()
                            Button("Restore") { t.restoreBackup(b) }.buttonStyle(PillStyle())
                            Button("Delete") { t.deleteBackup(b) }.buttonStyle(PillStyle())
                        }
                    }
                }
            }
        }
        .onAppear { t.loadBackups() }
    }
}

// MARK: - updates
final class UpdateModel: ObservableObject {
    @Published var status: String = "Not checked yet."
    @Published var latest: String = ""
    @Published var notes: String = ""
    @Published var assetURL: String = ""
    @Published var available: Bool = false
    @Published var working: Bool = false
    @Published var last: String = "never"
    var prompted = ""

    func repo(_ source: String) -> String? {
        for part in source.components(separatedBy: ";") {
            var t = trimmed(part)
            if t.hasPrefix("https://github.com/") { t = String(t.dropFirst("https://github.com/".count)) }
            if t.range(of: "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", options: .regularExpression) != nil { return t }
        }
        return nil
    }
    func check(prefs: Prefs, manual: Bool) {
        guard let r = repo(prefs.source), let url = URL(string: "https://api.github.com/repos/" + r + "/releases/latest") else {
            if manual { status = "No update source set. Enter your GitHub repo (owner/name) in Settings." }
            return
        }
        if manual { status = "Checking..." }
        var req = URLRequest(url: url)
        req.setValue("bluFPS-updater", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 12
        URLSession.shared.dataTask(with: req) { data, resp, err in
            var tag = ""
            var body = ""
            var asset = ""
            if let d = data, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                tag = (j["tag_name"] as? String) ?? ""
                body = (j["body"] as? String) ?? ""
                for a in (j["assets"] as? [[String: Any]]) ?? [] {
                    let n = (a["name"] as? String) ?? ""
                    if n.hasSuffix("-Mac.zip") { asset = (a["browser_download_url"] as? String) ?? "" }
                }
            }
            ui {
                let df = DateFormatter()
                df.timeStyle = .short
                self.last = df.string(from: Date())
                if tag.isEmpty {
                    self.status = manual ? "Could not check (offline, no published release, or the repo is private)." : self.status
                    return
                }
                let ver = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                if isNewer(ver, than: appVersion) && !asset.isEmpty {
                    self.latest = ver
                    self.notes = body
                    self.assetURL = asset
                    self.available = true
                    self.status = "Version " + ver + " is available."
                    if (manual || prefs.skipVersion != ver) && self.prompted != ver {
                        self.prompted = ver
                        self.promptUpdate(prefs: prefs)
                    }
                } else {
                    self.available = false
                    self.status = isNewer(ver, than: appVersion) ? "A new version exists but has no Mac download yet." : "You are up to date."
                }
            }
        }.resume()
    }
    func promptUpdate(prefs: Prefs) {
        let r = ask("Update available", "bluFPS " + latest + " is available (you have " + appVersion + ").\n\nDo you want to update bluFPS now? It downloads, rebuilds and reopens by itself.\n\n" + notes, ["Yes, update", "Not now", "Skip this version"])
        if r == 0 { install() }
        else if r == 2 { prefs.skipVersion = latest; status = "Version " + latest + " skipped. You can still update from this page." }
    }
    func install() {
        if working { return }
        guard let url = URL(string: assetURL) else { return }
        working = true
        status = "Downloading version " + latest + "..."
        URLSession.shared.downloadTask(with: url) { tmp, resp, err in
            guard let tmp = tmp else { ui { self.working = false; self.status = "Download failed." }; return }
            let work = dataDir.path + "/update"
            _ = sh("rm -rf " + q(work) + " && mkdir -p " + q(work + "/src"))
            try? FileManager.default.moveItem(at: tmp, to: URL(fileURLWithPath: work + "/mac.zip"))
            ui { self.status = "Unpacking and building (about a minute)..." }
            _ = sh("ditto -x -k " + q(work + "/mac.zip") + " " + q(work + "/src"))
            let found = trimmed(sh("find " + q(work + "/src") + " -maxdepth 3 -name build.sh | head -1").out)
            if found.isEmpty { ui { self.working = false; self.status = "The update package is missing build.sh." }; return }
            if sh("xcrun --find swiftc").code != 0 { ui { self.working = false; self.status = "Building needs Apple's free command line tools. Run: xcode-select --install" }; return }
            let dir = (found as NSString).deletingLastPathComponent
            let newApp = work + "/bluFPS.app"
            let r = sh("cd " + q(dir) + " && bash build.sh " + q(newApp) + " --quiet 2>&1")
            if r.code != 0 || !FileManager.default.fileExists(atPath: newApp) {
                ui { self.working = false; self.status = "The build failed. Your current bluFPS is unchanged." }
                return
            }
            let current = Bundle.main.bundlePath
            let swap = work + "/swap.sh"
            let script = "sleep 2\nrm -rf " + q(current) + "\nmv " + q(newApp) + " " + q(current) + "\nopen " + q(current) + "\n"
            try? script.write(toFile: swap, atomically: true, encoding: .utf8)
            ui {
                self.status = "Restarting..."
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/bash")
                p.arguments = ["-c", "nohup bash " + q(swap) + " >/dev/null 2>&1 &"]
                try? p.run()
                NSApp.terminate(nil)
            }
        }.resume()
    }
}
struct UpdatesView: View {
    @EnvironmentObject var u: UpdateModel
    @EnvironmentObject var prefs: Prefs
    var body: some View {
        Page("Updates", "bluFPS for Windows, Mac and Chromebook share one version number and are released together.") {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    label("Installed version")
                    Text("v" + appVersion).font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                    Text(u.status).font(.system(size: 13)).foregroundColor(u.available ? Theme.ok : Theme.muted)
                    if !u.notes.isEmpty { Text(u.notes).font(.system(size: 12)).foregroundColor(Color(white: 0.85)).fixedSize(horizontal: false, vertical: true) }
                    HStack(spacing: 10) {
                        Button("Check for updates") { u.check(prefs: prefs, manual: true) }.buttonStyle(PillStyle(go: true))
                        if u.available { Button("Install update...") { u.promptUpdate(prefs: prefs) }.buttonStyle(PillStyle(go: true)) }
                        Text("Last checked: " + u.last).font(.system(size: 12)).foregroundColor(Theme.muted)
                    }
                }
            }
            Card { muted("When a new version is published bluFPS asks first (Yes, update / Not now / Skip this version). Updating downloads the new source, builds it on your Mac with Apple's command line tools, then reopens. Nothing to download by hand.") }
        }
    }
}

// MARK: - settings
struct SettingsView: View {
    @EnvironmentObject var prefs: Prefs
    @State var newApp: String = ""
    func tog(_ title: String, _ desc: String, _ b: Binding<Bool>) -> some View {
        Toggle(isOn: b) {
            VStack(alignment: .leading, spacing: 2) { Text(title).foregroundColor(.white); Text(desc).font(.system(size: 11)).foregroundColor(Theme.muted) }
        }
        .toggleStyle(SwitchToggleStyle())
    }
    var body: some View {
        Page("Settings", "Choose what a game boost does. Changes save automatically.") {
            HStack(spacing: 10) {
                label("Boost level")
                Button("Light") { prefs.setLevel(0) }.buttonStyle(PillStyle())
                Button("Balanced") { prefs.setLevel(1) }.buttonStyle(PillStyle())
                Button("Maximum") { prefs.setLevel(2) }.buttonStyle(PillStyle(go: true))
            }
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    label("What a boost does")
                    tog("Quit background apps", "Quits the apps ticked below before the game starts.", $prefs.quitApps)
                    tog("Keep the Mac awake while playing", "Stops the screen and Mac sleeping during the game.", $prefs.preventSleep)
                    tog("Free up memory", "Runs purge (macOS asks for your password).", $prefs.purge)
                    tog("Efficiency mode for other apps", "Other apps move to the efficient cores and low priority, leaving the fast cores to the game.", $prefs.eco)
                    tog("Stop CPU hogs while you play", "If another app suddenly hogs the processor during a game, it is slowed down on the spot (ProBalance).", $prefs.probal)
                    tog("Pause Photos and media analysis", "Pauses the background daemons that scan your photo library while you play.", $prefs.pause)
                    tog("Maximum boost for the game", "Raises the game priority; with Free up memory on, one password prompt covers both.", $prefs.maxBoost)
                    tog("Show the FPS overlay (Metal HUD)", "For games started after the boost, not ones launched from an already-open Steam.", $prefs.hud)
                    tog("Reopen my apps afterwards", "Apps that bluFPS quit are opened again when the game ends.", $prefs.restoreApps)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    label("Apps to quit during a boost")
                    ForEach(knownApps.map { $0.0 } + prefs.customKill, id: \.self) { name in
                        Toggle(isOn: Binding(get: { prefs.killList.contains(name) }, set: { on in
                            if on { if !prefs.killList.contains(name) { prefs.killList.append(name) } } else { prefs.killList.removeAll { $0 == name } }
                        })) { Text(name).foregroundColor(.white) }
                        .toggleStyle(SwitchToggleStyle())
                    }
                    HStack {
                        TextField("Another app's name", text: $newApp).textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 260)
                        Button("Add") {
                            let n = trimmed(newApp)
                            if !n.isEmpty && !prefs.customKill.contains(n) { prefs.customKill.append(n); prefs.killList.append(n) }
                            newApp = ""
                        }.buttonStyle(PillStyle())
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    label("Updates")
                    tog("Check for updates automatically", "On start and every hour. bluFPS always asks before installing.", $prefs.autoCheck)
                    Text("Update source (your GitHub repo, like owner/name)").font(.system(size: 12)).foregroundColor(Theme.muted)
                    TextField("owner/name", text: $prefs.source).textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 360)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    label("Data")
                    HStack(spacing: 10) {
                        Button("Open data folder") { NSWorkspace.shared.open(dataDir) }.buttonStyle(PillStyle())
                        Button("Reset settings") {
                            prefs.killList = knownApps.filter { $0.1 }.map { $0.0 }
                            prefs.customKill = []
                            prefs.quitApps = true; prefs.preventSleep = true; prefs.purge = false; prefs.restoreApps = true; prefs.autoCheck = true; prefs.skipVersion = ""; prefs.setLevel(1)
                        }.buttonStyle(PillStyle())
                    }
                }
            }
        }
    }
}

// MARK: - app shell
enum PageId: String, CaseIterable {
    case dashboard = "Dashboard", games = "Games", boost = "Boost", network = "Network", tools = "Tools", updates = "Updates", settings = "Settings"
    var icon: String {
        switch self {
        case .dashboard: return "speedometer"
        case .games: return "gamecontroller"
        case .boost: return "bolt.fill"
        case .network: return "network"
        case .tools: return "wrench.and.screwdriver"
        case .updates: return "arrow.triangle.2.circlepath"
        case .settings: return "gearshape"
        }
    }
}
let prefs = Prefs()
let stats = StatsModel()
let gamesModel = GamesModel()
let netModel = NetModel()
let toolsModel = ToolsModel()
let updater = UpdateModel()

struct RootView: View {
    @State var page: PageId = .dashboard
    @EnvironmentObject var u: UpdateModel
    @EnvironmentObject var pr: Prefs
    var logo: NSImage? {
        guard let p = Bundle.main.resourcePath else { return nil }
        return NSImage(contentsOfFile: p + "/bluFPS.png")
    }
    var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                if let l = logo { Image(nsImage: l).resizable().frame(width: 46, height: 46) }
                VStack(alignment: .leading, spacing: 0) {
                    Text("bluFPS").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                    Text("v" + appVersion + "  Mac").font(.system(size: 10)).foregroundColor(Theme.muted)
                }
            }
            .padding(.bottom, 18)
            ForEach(PageId.allCases, id: \.self) { p in
                Button(action: { page = p }) {
                    HStack(spacing: 10) {
                        Image(systemName: p.icon).frame(width: 20)
                        Text(p.rawValue)
                        Spacer()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(page == p ? .white : Theme.muted)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(page == p ? Theme.accent.opacity(0.3) : Color.clear)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
        }
        .padding(18)
        .frame(width: 210)
        .background(Color.black.opacity(0.25))
    }
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                if u.available {
                    HStack {
                        Text("bluFPS " + u.latest + " is available.").foregroundColor(.white)
                        Spacer()
                        Button("Update...") { u.promptUpdate(prefs: prefs) }.buttonStyle(PillStyle(go: true))
                    }
                    .padding(10)
                    .background(Color(red: 0.09, green: 0.19, blue: 0.42))
                } else if u.repo(pr.source) == nil {
                    HStack {
                        Text("Online updates are not set up. Add your GitHub repo and bluFPS tells you about new versions by itself, with nothing to download.")
                            .font(.system(size: 12)).foregroundColor(.white)
                        Spacer()
                        Button("Set up") { page = .settings }.buttonStyle(PillStyle(go: true))
                    }
                    .padding(10)
                    .background(Color(red: 0.09, green: 0.19, blue: 0.42))
                }
                content
            }
        }
        .background(LinearGradient(colors: [Theme.bg1, Theme.bg2], startPoint: .topLeading, endPoint: .bottomTrailing))
        .frame(minWidth: 980, minHeight: 640)
    }
    @ViewBuilder var content: some View {
        switch page {
        case .dashboard: DashboardView()
        case .games: GamesView()
        case .boost: BoostView()
        case .network: NetworkView()
        case .tools: ToolsView()
        case .updates: UpdatesView()
        case .settings: SettingsView()
        }
    }
}
struct DashboardView: View {
    @EnvironmentObject var s: StatsModel
    var body: some View {
        Page("Dashboard", "What your Mac reports, live.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                StatCard(title: "CPU", value: String(format: "%.0f%%", s.cpu * 100), bar: s.cpu)
                StatCard(title: "Memory", value: String(format: "%.0f%%", s.ram * 100), bar: s.ram)
                StatCard(title: "Storage", value: s.disk, bar: s.diskUsed)
                StatCard(title: "Ping (1.1.1.1)", value: s.ping, bar: nil)
                StatCard(title: "Battery", value: s.battery, bar: nil)
                StatCard(title: "Chip", value: s.chip, bar: nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit bluFPS", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        NSApp.mainMenu = main
        let root = RootView()
            .environmentObject(prefs).environmentObject(stats).environmentObject(gamesModel)
            .environmentObject(netModel).environmentObject(toolsModel).environmentObject(updater)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 720),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "bluFPS"
        window.contentView = NSHostingView(rootView: root)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        _ = sh("killall -CONT photoanalysisd mediaanalysisd 2>/dev/null")
        stats.start()
        gamesModel.scan()
        if prefs.autoCheck {
            updater.check(prefs: prefs, manual: false)
            Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in updater.check(prefs: prefs, manual: false) }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { return true }
    func applicationWillTerminate(_ notification: Notification) {
        if gamesModel.active != nil { gamesModel.end(keepStatus: true) }
        _ = sh("killall -CONT photoanalysisd mediaanalysisd 2>/dev/null; launchctl unsetenv MTL_HUD_ENABLED 2>/dev/null")
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
