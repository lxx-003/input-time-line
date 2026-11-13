import SwiftUI

// MARK: - Plush Sonner Toast Banner

struct PlushToastMessage: Identifiable, Equatable {
    enum Tone: Equatable {
        case success
        case info
        case warning
        case error

        var color: Color {
            switch self {
            case .success: return PlushTheme.success
            case .info: return PlushTheme.accent
            case .warning: return PlushTheme.warning
            case .error: return PlushTheme.danger
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark"
            case .info: return "info"
            case .warning: return "exclamationmark"
            case .error: return "xmark"
            }
        }
    }

    let id: UUID
    let title: String
    let subtitle: String?
    let tone: Tone

    init(id: UUID = UUID(), title: String, subtitle: String? = nil, tone: Tone = .success) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
    }
}

struct PlushToastBanner: View {
    let toast: PlushToastMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(toast.tone.color)
                    .frame(width: 24, height: 24)

                Image(systemName: toast.tone.icon)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(toast.tone == .info ? PlushTheme.onAccent : Color.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(toast.title)
                    .font(PlushTheme.rounded(13, weight: .semibold))
                    .foregroundStyle(PlushTheme.ink)
                    .lineLimit(1)

                if let subtitle = toast.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(PlushTheme.rounded(11.5, weight: .medium))
                        .foregroundStyle(PlushTheme.ink2)
                        .lineLimit(1)
                }
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(PlushTheme.ink2)
            }
            .buttonStyle(PlushCircleIconButtonStyle(diameter: 20, variant: .secondary))
            .padding(.leading, 4)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(PlushTheme.surfaceElevated)
                .plushSoftShadow(elevated: true)
        )
    }
}
