import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) throws {
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Turns launch-at-login on the first time Beam runs (spec: on by default), and re-points an enabled
    /// login item at this copy when Beam was moved (e.g. installed into /Applications).
    static func applyDefaultOnce() {
        let defaults = UserDefaults.standard
        let firstRunKey = "didSetDefaultLoginItem", pathKey = "loginItemBundlePath"
        let path = Bundle.main.bundlePath
        do {
            if !defaults.bool(forKey: firstRunKey) {
                defaults.set(true, forKey: firstRunKey)
                try set(true)
            } else if isEnabled, defaults.string(forKey: pathKey) != path {
                try SMAppService.mainApp.unregister()
                try SMAppService.mainApp.register()
            }
            if isEnabled { defaults.set(path, forKey: pathKey) }
        } catch {
            log.error("Login item: \(error.localizedDescription, privacy: .public)")
        }
    }
}
