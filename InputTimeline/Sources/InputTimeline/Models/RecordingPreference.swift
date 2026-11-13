import Foundation

enum RecordingPreference {
    private static let enabledKey = "isRecordingEnabled"
    private static let silenceGapKey = "silenceGapSeconds"
    private static let excludedAppsKey = "excludedAppNames"

    static let suggestedSensitiveApps: [String] = [
        "1Password",
        "钥匙串访问",
        "Keychain Access",
        "Bitwarden",
        "KeePassXC",
        "系统设置",
        "System Settings"
    ]

    /// 用户偏好；未设置时默认开启记录。
    static var enabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
        }
    }

    static var silenceGapSeconds: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: silenceGapKey)
            return (1 ... 10).contains(stored) ? stored : 2
        }
        set {
            let clamped = min(10, max(1, newValue))
            UserDefaults.standard.set(clamped, forKey: silenceGapKey)
        }
    }

    static var excludedApps: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: excludedAppsKey) ?? []
        }
        set {
            let normalized = Array(
                NSOrderedSet(array: newValue.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
            ) as? [String] ?? []
            UserDefaults.standard.set(normalized, forKey: excludedAppsKey)
        }
    }
}
