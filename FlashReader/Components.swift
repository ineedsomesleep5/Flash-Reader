import SwiftUI

struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = FRTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(FRTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(FRTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(FRTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: FRTheme.accent.opacity(0.25), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }
}

struct IconCircleButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(FRTheme.primaryText)
                .frame(width: 44, height: 44)
                .background(FRTheme.surface, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
        }
        .accessibilityLabel(accessibilityLabel)
        .buttonStyle(.plain)
    }
}

struct RingProgressView: View {
    let progress: Double
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 9)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(FRTheme.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(FRTheme.primaryText)
        }
        .frame(width: 68, height: 68)
    }
}

struct DocumentRow: View {
    let document: ReadingDocument
    let eta: String

    var body: some View {
        HStack(spacing: 14) {
            RingProgressView(
                progress: document.percentComplete,
                label: "\(Int(document.percentComplete * 100))%"
            )
            VStack(alignment: .leading, spacing: 7) {
                Text(document.title)
                    .font(.headline)
                    .foregroundStyle(FRTheme.primaryText)
                    .lineLimit(2)
                Text("\(document.wordCount.formatted()) words - \(eta)")
                    .font(.subheadline)
                    .foregroundStyle(FRTheme.secondaryText)
                    .lineLimit(1)
                ProgressView(value: document.percentComplete)
                    .tint(FRTheme.accent)
                    .background(.white.opacity(0.06), in: Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(FRTheme.secondaryText)
        }
        .frCard()
    }
}
