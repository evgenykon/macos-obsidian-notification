import SwiftUI

struct NotificationHistoryView: View {
    let notifications: [AINotification]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bell.and.waveform")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Последние уведомления")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ForEach(notifications.prefix(3)) { notification in
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
                    Text(notification.aiMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 8)
    }
}
