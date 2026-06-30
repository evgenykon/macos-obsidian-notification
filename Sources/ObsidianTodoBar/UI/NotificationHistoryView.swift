import SwiftUI

struct NotificationHistoryView: View {
    let notifications: [AINotification]
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "bell.and.waveform")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Последнее уведомление")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if let notification = notifications.first {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(notification.taskTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Text(notification.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if notification.aiMessage.count > 200 {
                        ScrollView {
                            Text(notification.aiMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 100)
                    } else {
                        Text(notification.aiMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .overlay(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onTap() }
                )
            }
        }
        .padding(.bottom, 6)
    }
}
