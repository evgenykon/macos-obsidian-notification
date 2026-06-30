import AppKit
import Foundation
import Observation
@preconcurrency import UserNotifications

@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func checkAuthorization() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestPermissionIfNeeded() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            authorizationStatus = granted ? .authorized : .denied
        } catch {
            print("Notif: requestAuth error = \(error.localizedDescription)")
        }
    }

    func show(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                print("Notif: add error = \(error.localizedDescription)")
            }
        }
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
