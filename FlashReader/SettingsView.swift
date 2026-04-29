import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading") {
                    VStack(alignment: .leading) {
                        Text("Default speed: \(model.settings.wpm) WPM")
                        Slider(value: doubleBinding(\.wpm), in: 100...1000, step: 10)
                    }
                    VStack(alignment: .leading) {
                        Text("Font scale: \(model.settings.fontScale, specifier: "%.2f")x")
                        Slider(value: doubleBinding(\.fontScale), in: 0.8...1.45, step: 0.05)
                    }
                    Picker("Chunk size", selection: intBinding(\.chunkSize)) {
                        Text("1 word").tag(1)
                        Text("2 words").tag(2)
                        Text("3 words").tag(3)
                    }
                }
                Section("Focus") {
                    Toggle("Smart pauses", isOn: boolBinding(\.smartPauses))
                    Toggle("Sentence context", isOn: boolBinding(\.showsContext))
                    Toggle("Tap reader to play", isOn: boolBinding(\.tapToPlayEnabled))
                    Toggle("Haptics", isOn: boolBinding(\.hapticsEnabled))
                }
                Section("Daily Goal") {
                    Stepper("\(model.settings.dailyWordGoal.formatted()) words", value: intBinding(\.dailyWordGoal), in: 250...20000, step: 250)
                }
            }
            .scrollContentBackground(.hidden)
            .background(FRTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func boolBinding(_ keyPath: WritableKeyPath<ReaderSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in model.updateSettings { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func intBinding(_ keyPath: WritableKeyPath<ReaderSettings, Int>) -> Binding<Int> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in model.updateSettings { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func doubleBinding(_ keyPath: WritableKeyPath<ReaderSettings, Int>) -> Binding<Double> {
        Binding(
            get: { Double(model.settings[keyPath: keyPath]) },
            set: { newValue in model.updateSettings { $0[keyPath: keyPath] = Int(newValue) } }
        )
    }

    private func doubleBinding(_ keyPath: WritableKeyPath<ReaderSettings, Double>) -> Binding<Double> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in model.updateSettings { $0[keyPath: keyPath] = newValue } }
        )
    }
}
