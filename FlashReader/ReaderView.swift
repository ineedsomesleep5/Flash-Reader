import SwiftUI
import UIKit

struct ReaderView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let documentID: ReadingDocument.ID
    @StateObject private var reader = RSVPReader()
    @State private var sessionStartedAt: Date?
    @State private var sessionStartIndex = 0

    private var document: ReadingDocument? {
        model.document(with: documentID)
    }

    var body: some View {
        ZStack {
            FRTheme.readerBackground.ignoresSafeArea()
            if let document {
                VStack(spacing: 0) {
                    topBar(document)
                    Spacer(minLength: 20)
                    wordStage(document)
                    Spacer(minLength: 20)
                    if model.settings.showsContext {
                        contextBar(document)
                    }
                    controls(document)
                }
                .padding(20)
                .onAppear {
                    reader.configurePreview(tokens: document.tokens, index: document.progressIndex, chunkSize: model.settings.chunkSize)
                }
                .onDisappear {
                    stopReading(document)
                }
            } else {
                ContentUnavailableView("Document missing", systemImage: "exclamationmark.triangle")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func topBar(_ document: ReadingDocument) -> some View {
        VStack(spacing: 12) {
            HStack {
                IconCircleButton(systemImage: "xmark", accessibilityLabel: "Close Reader") {
                    dismiss()
                }
                Spacer()
                Text("\(min(document.progressIndex + 1, document.wordCount)) / \(document.wordCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FRTheme.secondaryText)
                Spacer()
                IconCircleButton(systemImage: "textformat.size", accessibilityLabel: "Reader Settings") {
                    model.updateSettings { $0.showsContext.toggle() }
                }
            }
            Slider(
                value: Binding(
                    get: { Double(document.progressIndex) },
                    set: { model.updateProgress(documentID: document.id, index: Int($0)); reader.seek(to: Int($0)) }
                ),
                in: 0...Double(max(document.wordCount - 1, 0)),
                step: 1
            )
            .tint(FRTheme.accent)
        }
    }

    private func wordStage(_ document: ReadingDocument) -> some View {
        ZStack {
            VStack(spacing: 110) {
                guideTick
                guideTick
            }
            flashedWord
                .font(.system(size: 48 * model.settings.fontScale, weight: .bold, design: .serif))
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard model.settings.tapToPlayEnabled else { return }
                    reader.isPlaying ? stopReading(document) : startReading(document)
                }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .accessibilityLabel("Current reading word")
    }

    private var guideTick: some View {
        Rectangle()
            .fill(FRTheme.accent.opacity(0.8))
            .frame(width: 2, height: 34)
    }

    private var flashedWord: some View {
        Group {
            if reader.currentChunk.count == 1, let token = reader.currentChunk.first {
                HStack(spacing: 0) {
                    Text(String(token.stripped.prefix(token.orpIndex)))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(orpCharacter(token))
                        .foregroundStyle(FRTheme.accent)
                    Text(String(token.stripped.dropFirst(token.orpIndex + 1)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(FRTheme.primaryText)
            } else {
                Text(reader.currentChunk.map(\.stripped).joined(separator: "  "))
                    .foregroundStyle(FRTheme.primaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func contextBar(_ document: ReadingDocument) -> some View {
        Text(model.sentenceContext(for: document, index: document.progressIndex))
            .font(.footnote)
            .lineLimit(3)
            .multilineTextAlignment(.center)
            .foregroundStyle(FRTheme.secondaryText)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(FRTheme.surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.bottom, 16)
    }

    private func controls(_ document: ReadingDocument) -> some View {
        VStack(spacing: 16) {
            Button {
                reader.isPlaying ? stopReading(document) : startReading(document)
            } label: {
                Label(reader.isPlaying ? "Pause" : "Tap or Hold to Read", systemImage: reader.isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(reader.isPlaying ? FRTheme.elevated : FRTheme.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            Text("Hold for sprint reading")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(reader.isPlaying ? FRTheme.accent : FRTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(FRTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
                .contentShape(Capsule())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !reader.isPlaying {
                                startReading(document)
                            }
                        }
                        .onEnded { _ in
                            if reader.isPlaying {
                                stopReading(document)
                            }
                        }
                )

            VStack(spacing: 8) {
                HStack {
                    Text("\(model.settings.wpm) WPM")
                        .font(.headline)
                        .foregroundStyle(FRTheme.primaryText)
                    Spacer()
                    Text("\(model.settings.chunkSize) word\(model.settings.chunkSize == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FRTheme.secondaryText)
                }
                Slider(
                    value: Binding(
                        get: { Double(model.settings.wpm) },
                        set: { value in
                            model.updateSettings { $0.wpm = Int(value) }
                            reader.setWPM(Int(value))
                        }
                    ),
                    in: 100...1000,
                    step: 10
                )
                .tint(FRTheme.accent)
            }
        }
    }

    private func startReading(_ document: ReadingDocument) {
        sessionStartedAt = Date()
        sessionStartIndex = document.progressIndex
        haptic(.medium)
        reader.play(
            tokens: document.tokens,
            startIndex: document.progressIndex,
            wpm: model.settings.wpm,
            smartPauses: model.settings.smartPauses,
            chunkSize: model.settings.chunkSize,
            onAdvance: { index, _ in
                model.updateProgress(documentID: document.id, index: index)
            },
            onEnd: {
                finishSession(document, endedAt: document.wordCount)
            }
        )
    }

    private func stopReading(_ document: ReadingDocument) {
        guard reader.isPlaying || sessionStartedAt != nil else { return }
        reader.pause()
        finishSession(document, endedAt: model.document(with: document.id)?.progressIndex ?? document.progressIndex)
    }

    private func finishSession(_ document: ReadingDocument, endedAt: Int) {
        let seconds = sessionStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        model.accumulateSession(documentID: document.id, from: sessionStartIndex, to: endedAt, seconds: seconds)
        sessionStartedAt = nil
        haptic(.light)
    }

    private func orpCharacter(_ token: ReadingToken) -> String {
        guard token.orpIndex < token.stripped.count else { return "" }
        let index = token.stripped.index(token.stripped.startIndex, offsetBy: token.orpIndex)
        return String(token.stripped[index])
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard model.settings.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
