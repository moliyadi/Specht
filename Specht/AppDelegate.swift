import Cocoa
import NetworkExtension
import NEKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var barItem: NSStatusItem!
    var managerMap: [String: NETunnelProviderManager]!
    var pendingAction = 0

    var configFolder: String {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".Specht")
        var isDir: ObjCBool = false
        let exist = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        if exist && !isDir {
            try! FileManager.default.removeItem(atPath: path)
            try! FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
        if !exist {
            try! FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
        return path
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        reloadAllConfigurationFiles() {
            self.registerObserver()
            self.initMenuBar()
        }
    }


    func initManagerMap(_ completionHandler: @escaping () -> ()) {
        managerMap = [:]

        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            guard managers != nil else {
                self.alertError("Failed to load VPN settings from preferences. \(error)")
                return
            }

            for manager in managers! {
                self.managerMap[manager.localizedDescription!] = manager
            }

            completionHandler()
        }
    }

    func initMenuBar() {
        barItem = NSStatusBar.system().statusItem(withLength: -1)
        barItem.title = "Sp"
        barItem.menu = NSMenu()
        barItem.menu!.delegate = self
    }

    func registerObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.statusDidChange(_:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.configurationDidChange(_:)), name: NSNotification.Name.NEVPNConfigurationChange, object: nil)
    }

    func statusDidChange(_ notification: Notification) {
    }

    func configurationDidChange(_ notification: Notification) {
    }

    func startConfiguration(_ sender: NSMenuItem) {
        let manager = managerMap[sender.title]!
        do {
            switch manager.connection.status {
            case .disconnected:
//                disconnect()
                try (manager.connection as! NETunnelProviderSession).startTunnel(options: [:])
            case .connected, .connecting, .reasserting:
                (manager.connection as! NETunnelProviderSession).stopTunnel()
            default:
                break
            }
        } catch let error {
            alertError("Failed to start VPN \(sender.title) due to: \(error)")
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let disableNonConnected = findConnectedManager() != nil
        for manager in managerMap.values {
            let item = buildMenuItemForManager(manager, disableNonConnected: disableNonConnected)
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Disconnect", action: #selector(AppDelegate.disconnect(_:)), keyEquivalent: "d")
        menu.addItem(withTitle: "Open config folder", action: #selector(AppDelegate.openConfigFolder(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Reload config", action: #selector(AppDelegate.reloadClicked(_:)), keyEquivalent: "r")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Exit", action: #selector(AppDelegate.terminate(_:)), keyEquivalent: "q")
    }

    func openConfigFolder(_ sender: AnyObject) {
        NSWorkspace.shared().openFile(configFolder)
    }

    func reloadClicked(_ sender: AnyObject) {
        reloadAllConfigurationFiles()
    }

    func reloadAllConfigurationFiles(_ completionHandler: (() -> ())? = nil) {
        VPNManager.removeAllManagers {
            VPNManager.loadAllConfigFiles(self.configFolder) {
                self.initManagerMap() {
                    completionHandler?()
                }
            }
        }
    }

    func disconnect(_ sender: AnyObject? = nil) {
        for manager in managerMap.values {
            switch manager.connection.status {
            case .connected, .connecting:
                (manager.connection as! NETunnelProviderSession).stopTunnel()
            default:
                break
            }
        }
    }

    func findConnectedManager() -> NETunnelProviderManager? {
        for manager in managerMap.values {
            switch manager.connection.status {
            case .connected, .connecting, .reasserting, .disconnecting:
                return manager
            default:
                break
            }
        }
        return nil
    }

    func buildMenuItemForManager(_ manager: NETunnelProviderManager, disableNonConnected: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: manager.localizedDescription!, action: #selector(AppDelegate.startConfiguration(_:)), keyEquivalent: "")

        switch manager.connection.status {
        case .connected:
            item.state = NSOnState
        case .connecting:
            item.title = item.title + "(Connecting)"
        case .disconnecting:
            item.title = item.title + "(Disconnecting)"
        case .reasserting:
            item.title = item.title + "(Reconnecting)"
        case .disconnected:
            break
        case .invalid:
            item.title = item.title + "(----)"
        }

        if disableNonConnected {
            switch manager.connection.status {
            case .disconnected, .invalid:
                item.action = nil
            default:
                break
            }
        }
        return item
    }

    func alertError(_ errorDescription: String) {
        let alert = NSAlert()
        alert.messageText = errorDescription
        alert.runModal()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }

    func terminate(_ sender: AnyObject) {
        NSApp.terminate(self)
    }

}
