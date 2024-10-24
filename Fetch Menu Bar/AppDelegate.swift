import Cocoa
import ServiceManagement

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?
    var timer: Timer?

    let loginItemAppId = "io.goellner.Fetch-Menu-Bar" // Replace with your actual app's bundle identifier

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set the app's activation policy to hide it from the Dock
        NSApp.setActivationPolicy(.accessory)

        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "Loading..."
        }

        // Setup right-click menu
        setupMenu()

        // Try loading content if URL is already set
        let savedURL = UserDefaults.standard.string(forKey: "fetchURL")
        if savedURL == nil || savedURL!.isEmpty {
            statusItem?.button?.title = "Set URL in Settings"
        } else {
            loadContent() // Load initial URL on start
            let refreshInterval = UserDefaults.standard.double(forKey: "refreshInterval")
            startTimer(with: refreshInterval > 0 ? refreshInterval : 60.0) // Set up a timer to refresh content
        }
    }

    func startTimer(with interval: Double) {
        timer?.invalidate() // Invalidate any existing timer
        timer = Timer.scheduledTimer(timeInterval: interval,
                                     target: self,
                                     selector: #selector(loadContent),
                                     userInfo: nil,
                                     repeats: true)
        RunLoop.main.add(timer!, forMode: .common) // Ensure timer runs on the common run loop modes
    }

    @objc func loadContent() {
        let savedURL = UserDefaults.standard.string(forKey: "fetchURL")

        guard let urlString = savedURL, !urlString.isEmpty, let url = URL(string: urlString) else {
            print("No URL set, skipping fetch")
            DispatchQueue.main.async {
                self.statusItem?.button?.title = "No URL set"
            }
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    self.statusItem?.button?.title = "Error fetching data"
                }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
               let fetchedData = json["data"] {
                DispatchQueue.main.async {
                    self.statusItem?.button?.title = fetchedData
                }
            } else {
                DispatchQueue.main.async {
                    self.statusItem?.button?.title = "Invalid data"
                }
            }
        }
        task.resume()
    }

    func setupMenu() {
        let menu = NSMenu()

        // Add "Change URL" option
        menu.addItem(NSMenuItem(title: "Change URL", action: #selector(promptForURL), keyEquivalent: ""))

        // Add "Change Refresh Interval" option
        menu.addItem(NSMenuItem(title: "Change Refresh Interval", action: #selector(promptForInterval), keyEquivalent: ""))

        // Add checkbox to start on login
        let startOnLoginItem = NSMenuItem(title: "Start on Login", action: #selector(toggleStartOnLogin), keyEquivalent: "")
        startOnLoginItem.state = isAppSetToLaunchAtLogin() ? .on : .off
        menu.addItem(startOnLoginItem)

        menu.addItem(NSMenuItem.separator()) // Separator
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }

    // Prompt for URL input
    @objc func promptForURL() {
        let alert = NSAlert()
        alert.messageText = "Enter Fetch URL"
        alert.informativeText = "Enter the URL to fetch the data from:"
        alert.alertStyle = .informational

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.stringValue = UserDefaults.standard.string(forKey: "fetchURL") ?? ""
        alert.accessoryView = inputField
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newURL = inputField.stringValue
            UserDefaults.standard.setValue(newURL, forKey: "fetchURL")
            loadContent() // Immediately load the new content
        }
    }

    // Prompt for refresh interval input
    @objc func promptForInterval() {
        let alert = NSAlert()
        alert.messageText = "Set Refresh Interval"
        alert.informativeText = "Enter the refresh interval in seconds:"
        alert.alertStyle = .informational

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        let currentInterval = UserDefaults.standard.integer(forKey: "refreshInterval")
        inputField.stringValue = currentInterval > 0 ? String(currentInterval) : "60"
        alert.accessoryView = inputField
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let newInterval = Int(inputField.stringValue) {
                UserDefaults.standard.setValue(newInterval, forKey: "refreshInterval")
                startTimer(with: Double(newInterval)) // Update the timer with the new interval
            } else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Invalid Interval"
                errorAlert.informativeText = "Please enter a valid integer for the refresh interval."
                errorAlert.alertStyle = .warning
                errorAlert.runModal()
            }
        }
    }

    // Toggle "Start on Login" option
    @objc func toggleStartOnLogin(sender: NSMenuItem) {
        let shouldStart = sender.state == .off
        setAppToLaunchAtLogin(shouldStart)
        sender.state = shouldStart ? .on : .off
    }

    // Helper function to check if the app is set to launch at login using SMAppService
    func isAppSetToLaunchAtLogin() -> Bool {
        return UserDefaults.standard.bool(forKey: "launchAtLogin")
    }

    // Helper function to enable/disable the app as a login item
    func setAppToLaunchAtLogin(_ shouldStart: Bool) {
        let loginItem = SMAppService.loginItem(identifier: loginItemAppId)
        
        if shouldStart {
            do {
                try loginItem.register()
                UserDefaults.standard.set(true, forKey: "launchAtLogin")
            } catch {
                print("Failed to register login item: \(error)")
            }
        } else {
            do {
                try loginItem.unregister()
                UserDefaults.standard.set(false, forKey: "launchAtLogin")
            } catch {
                print("Failed to unregister login item: \(error)")
            }
        }
    }
}
