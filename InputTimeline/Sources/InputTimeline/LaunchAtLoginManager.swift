import Foundation
import ServiceManagement

/// 通过系统「登录项」在开机 / 登录后自动启动应用（macOS 13+）。
enum LaunchAtLoginManager {
    private static let preferenceKey = "launchAtLogin"

    /// 用户偏好；未设置时默认开启。
    static var preferenceEnabled: Bool {
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

    static var isRegistered: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 将注册状态与用户偏好对齐（应用启动时调用）。
    static func syncWithPreference() {
        apply(preferenceEnabled)
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String? {
        preferenceEnabled = enabled
        return apply(enabled)
    }

    @discardableResult
    private static func apply(_ enabled: Bool) -> String? {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    return nil
                }
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
