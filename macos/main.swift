// Kilo für Kilo – schlanke macOS-Hülle: ein Fenster, das die mitgelieferte index.html anzeigt.
// Eingaben liegen im WebKit-Speicher der App; Rezepte lädt die Seite selbst von GitHub nach.
// Die Hülle kann sich außerdem selbst aktualisieren (Profil → App und Updates).
import Cocoa
import WebKit

enum UpdateError: Error {
    case message(String)
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: WKWebView!

    static let releaseBase = "https://github.com/Melo-Labs/Kilo-fuer-Kilo/releases/download/latest/"
    static let versionURL = URL(string: releaseBase + "version.json")!
    static let dmgURL = URL(string: releaseBase + "Kilo-fuer-Kilo.dmg")!

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
    var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
    }
    private var updateBusy = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()

        let config = WKWebViewConfiguration()
        let controller = config.userContentController
        // Versionsinfo für die Seite, bevor ihr Skript läuft.
        controller.addUserScript(WKUserScript(
            source: "window.kiloNative={version:\"\(currentVersion)\",build:\(currentBuild)};",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        // Sagt der Seite, dass sie in der Mac-App läuft (Platz für die Fensterknöpfe).
        controller.addUserScript(WKUserScript(
            source: "document.documentElement.setAttribute('data-shell','mac');",
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        controller.add(self, name: "kilo")
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        // Dunkles Design: Fenster und Randbereiche schwarz, kein weißes Aufblitzen beim Start.
        webView.isHidden = true
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .black
        }

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kilo für Kilo"
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 380, height: 560)
        window.contentView = webView
        window.center()
        window.setFrameAutosaveName("KiloMainWindow2")
        window.makeKeyAndOrderFront(nil)

        if let page = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
        NSApp.activate(ignoringOtherApps: true)
        // Falls das Lade-Signal ausbleibt, die Seite trotzdem zeigen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.webView.isHidden = false
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.isHidden = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webView.isHidden = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // Links auf Webseiten öffnen im Standardbrowser, nicht im App-Fenster.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           url.scheme == "http" || url.scheme == "https" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // MARK: - Nachrichten von der Seite

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        switch action {
        case "check": checkForUpdate(silent: false)
        case "check-silent": checkForUpdate(silent: true)
        case "install": installUpdate()
        default: break
        }
    }

    private func sendUpdate(_ info: [String: Any]) {
        DispatchQueue.main.async {
            guard let data = try? JSONSerialization.data(withJSONObject: info),
                  let json = String(data: data, encoding: .utf8) else { return }
            self.webView.evaluateJavaScript("window.kiloUpdate && window.kiloUpdate(\(json));", completionHandler: nil)
        }
    }

    // MARK: - Update suchen

    private func checkForUpdate(silent: Bool) {
        if updateBusy { return }
        if !silent { sendUpdate(["status": "checking"]) }
        var request = URLRequest(url: AppDelegate.versionURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 20
        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data = data,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let build = (obj["build"] as? NSNumber)?.intValue else {
                self.sendUpdate(silent
                    ? ["status": "idle"]
                    : ["status": "error", "message": "Es konnte nicht nach Updates gesucht werden. Besteht eine Internetverbindung?"])
                return
            }
            var info: [String: Any] = [
                "status": build > self.currentBuild ? "available" : "current",
                "build": build,
                "auto": silent
            ]
            if let version = obj["version"] as? String { info["version"] = version }
            if let date = obj["date"] as? String { info["date"] = date }
            self.sendUpdate(info)
        }.resume()
    }

    // MARK: - Update installieren

    @discardableResult
    private func run(_ path: String, _ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw UpdateError.message("Schritt fehlgeschlagen (\(URL(fileURLWithPath: path).lastPathComponent)): \(output)")
        }
        return output
    }

    private func installUpdate() {
        if updateBusy { return }
        let appURL = Bundle.main.bundleURL
        let parent = appURL.deletingLastPathComponent()
        if appURL.path.contains("/AppTranslocation/") || appURL.path.hasPrefix("/Volumes/") {
            sendUpdate(["status": "error",
                        "message": "Bitte zieh die App zuerst in den Programme-Ordner und starte sie von dort."])
            return
        }
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            sendUpdate(["status": "error",
                        "message": "Keine Schreibrechte für \(parent.path). Bitte installiere das Update einmal von Hand über die .dmg-Datei."])
            return
        }
        updateBusy = true
        sendUpdate(["status": "downloading"])

        var request = URLRequest(url: AppDelegate.dmgURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 120
        URLSession.shared.downloadTask(with: request) { tmp, response, _ in
            do {
                guard let tmp = tmp, (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw UpdateError.message("Der Download ist fehlgeschlagen. Besteht eine Internetverbindung?")
                }
                let fm = FileManager.default
                let work = fm.temporaryDirectory.appendingPathComponent("kilo-update-" + UUID().uuidString)
                try fm.createDirectory(at: work, withIntermediateDirectories: true)
                let dmg = work.appendingPathComponent("update.dmg")
                try fm.moveItem(at: tmp, to: dmg)

                self.sendUpdate(["status": "installing"])
                let mount = work.appendingPathComponent("mnt")
                try fm.createDirectory(at: mount, withIntermediateDirectories: true)
                try self.run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path])
                let staged = work.appendingPathComponent("Kilo für Kilo.app")
                do {
                    try self.run("/usr/bin/ditto", [mount.appendingPathComponent("Kilo für Kilo.app").path, staged.path])
                } catch {
                    _ = try? self.run("/usr/bin/hdiutil", ["detach", mount.path, "-force"])
                    throw error
                }
                _ = try? self.run("/usr/bin/hdiutil", ["detach", mount.path, "-force"])
                _ = try? self.run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staged.path])

                guard Bundle(url: staged)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
                    throw UpdateError.message("Die heruntergeladene Datei enthält nicht die erwartete App.")
                }
                DispatchQueue.main.async {
                    self.replaceAndRelaunch(app: appURL, staged: staged, work: work)
                }
            } catch {
                let text: String
                if case UpdateError.message(let m) = error { text = m } else { text = error.localizedDescription }
                self.updateBusy = false
                self.sendUpdate(["status": "error", "message": text])
            }
        }.resume()
    }

    // Ein kleines Skript wartet, bis die App beendet ist, tauscht sie aus und startet sie neu.
    // Schlägt das Kopieren fehl, wird die alte Version wiederhergestellt.
    private func replaceAndRelaunch(app: URL, staged: URL, work: URL) {
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        if mv "$2" "$2.alt"; then
          if /usr/bin/ditto "$3" "$2"; then rm -rf "$2.alt"; else rm -rf "$2"; mv "$2.alt" "$2"; fi
        fi
        rm -rf "$4"
        /usr/bin/open "$2"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "kilo-update",
                             String(ProcessInfo.processInfo.processIdentifier),
                             app.path, staged.path, work.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            updateBusy = false
            sendUpdate(["status": "error", "message": "Das Update konnte nicht gestartet werden: \(error.localizedDescription)"])
            return
        }
        NSApp.terminate(nil)
    }

    // MARK: - Menü

    @objc func reloadPage(_ sender: Any?) {
        webView.reload()
    }

    @objc func checkForUpdatesFromMenu(_ sender: Any?) {
        webView.evaluateJavaScript("location.hash='#profil';", completionHandler: nil)
        checkForUpdate(silent: false)
    }

    private func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let updates = NSMenuItem(title: "Nach Updates suchen …", action: #selector(checkForUpdatesFromMenu(_:)), keyEquivalent: "")
        updates.target = self
        appMenu.addItem(updates)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Kilo für Kilo ausblenden", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Kilo für Kilo beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Bearbeiten")
        editMenu.addItem(withTitle: "Widerrufen", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Wiederholen", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Ausschneiden", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Kopieren", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Einsetzen", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "Darstellung")
        let reload = NSMenuItem(title: "Neu laden", action: #selector(reloadPage(_:)), keyEquivalent: "r")
        reload.target = self
        viewMenu.addItem(reload)
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Fenster")
        windowMenu.addItem(withTitle: "Im Dock ablegen", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Schließen", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
