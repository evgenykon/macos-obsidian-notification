import AppKit
import Foundation
import Observation
@preconcurrency import UserNotifications

@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    override init() {
        super.init()
        center?.delegate = self
    }

    func checkAuthorization() async {
        guard let center else {
            print("Notif: no bundle, skipping auth check")
            return
        }
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        print("Notif: auth status = \(settings.authorizationStatus.rawValue)")
    }

    func requestPermission() async {
        guard let center else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            authorizationStatus = settings.authorizationStatus
            return
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            authorizationStatus = granted ? .authorized : .denied
        } catch {
            print("Notification permission error: \(error.localizedDescription)")
            authorizationStatus = .denied
        }
    }

    func show(title: String, body: String) {
        guard let center else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    static func openSystemSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.notifications"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
