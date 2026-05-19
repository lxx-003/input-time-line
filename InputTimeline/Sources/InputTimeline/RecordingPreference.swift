import Foundation

enum RecordingPreference {
    private static let preferenceKey = "isRecordingEnabled"

    /// 用户偏好；未设置时默认开启记录。
    static var enabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: preferenceKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: preferenceKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: preferenceKey)
        }
    }
}
