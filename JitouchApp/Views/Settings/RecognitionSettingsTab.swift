import SwiftUI

struct RecognitionSettingsTab<
    ProfileSelectionContent: View,
    GestureSearchContent: View,
    GestureEditorContent: View
>: View {
    @Binding var trackpadCharacterRecognitionEnabled: Bool
    @Binding var oneFingerDrawingEnabled: Bool
    @Binding var twoFingerDrawingEnabled: Bool
    @Binding var magicMouseCharacterRecognitionEnabled: Bool
    @Binding var characterRecognitionDistance: Double
    @Binding var characterRecognitionMouseButton: Int
    let hasLiveDiagnosticsSnapshot: Bool
    @Binding var characterRecognitionDiagnosticsEnabled: Bool
    let profileSelection: ProfileSelectionContent
    let gestureSearch: GestureSearchContent
    let gestureEditor: GestureEditorContent

    init(
        trackpadCharacterRecognitionEnabled: Binding<Bool>,
        oneFingerDrawingEnabled: Binding<Bool>,
        twoFingerDrawingEnabled: Binding<Bool>,
        magicMouseCharacterRecognitionEnabled: Binding<Bool>,
        characterRecognitionDistance: Binding<Double>,
        characterRecognitionMouseButton: Binding<Int>,
        hasLiveDiagnosticsSnapshot: Bool,
        characterRecognitionDiagnosticsEnabled: Binding<Bool>,
        @ViewBuilder profileSelection: () -> ProfileSelectionContent,
        @ViewBuilder gestureSearch: () -> GestureSearchContent,
        @ViewBuilder gestureEditor: () -> GestureEditorContent
    ) {
        self._trackpadCharacterRecognitionEnabled = trackpadCharacterRecognitionEnabled
        self._oneFingerDrawingEnabled = oneFingerDrawingEnabled
        self._twoFingerDrawingEnabled = twoFingerDrawingEnabled
        self._magicMouseCharacterRecognitionEnabled = magicMouseCharacterRecognitionEnabled
        self._characterRecognitionDistance = characterRecognitionDistance
        self._characterRecognitionMouseButton = characterRecognitionMouseButton
        self.hasLiveDiagnosticsSnapshot = hasLiveDiagnosticsSnapshot
        self._characterRecognitionDiagnosticsEnabled = characterRecognitionDiagnosticsEnabled
        self.profileSelection = profileSelection()
        self.gestureSearch = gestureSearch()
        self.gestureEditor = gestureEditor()
    }

    var body: some View {
        SettingsPageScaffold(
            title: JitouchSettingsPane.recognition.title,
            subtitle: JitouchSettingsPane.recognition.subtitle
        ) {
            recognitionSummaryCard
            characterRecognitionSettingsCard
            profileSelection
            gestureSearch
            gestureEditor
        }
    }

    private var recognitionSummaryCard: some View {
        JitouchSurfaceCard(
            title: "Recognition Modes",
            subtitle: "Trackpad and Magic Mouse drawing now share the same Swift recognition core, with adjustable thresholds and profile-based command outputs.",
            symbol: "signature",
            tint: .purple
        ) {
            SettingsMetricsGrid {
                JitouchMetricTile(
                    title: "Trackpad Recognition",
                    value: trackpadCharacterRecognitionEnabled ? "Enabled" : "Disabled",
                    detail: oneFingerDrawingEnabled || twoFingerDrawingEnabled
                        ? "Drawing input is available on trackpad."
                        : "No trackpad drawing modes are active.",
                    symbol: "rectangle.and.pencil.and.ellipsis",
                    tint: trackpadCharacterRecognitionEnabled ? .green : .secondary
                )
                JitouchMetricTile(
                    title: "Magic Mouse Recognition",
                    value: magicMouseCharacterRecognitionEnabled ? "Enabled" : "Disabled",
                    detail: characterRecognitionMouseButton == 0 ? "Triggered from middle click." : "Triggered from right click.",
                    symbol: "mouse",
                    tint: magicMouseCharacterRecognitionEnabled ? .blue : .secondary
                )
                JitouchMetricTile(
                    title: "Diagnostics",
                    value: characterRecognitionDiagnosticsEnabled ? "Live" : "Off",
                    detail: hasLiveDiagnosticsSnapshot ? "Receiving recognizer snapshots." : "No live snapshot yet.",
                    symbol: "waveform.path.ecg",
                    tint: characterRecognitionDiagnosticsEnabled ? .pink : .secondary
                )
            }
        }
    }

    private var characterRecognitionSettingsCard: some View {
        JitouchSurfaceCard(
            title: "Character Recognition",
            subtitle: "Configure drawing-based input on trackpad and Magic Mouse, plus the shared thresholds that shape recognition stability.",
            symbol: "character.cursor.ibeam",
            tint: .purple
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Enable Trackpad Character Recognition", isOn: $trackpadCharacterRecognitionEnabled)
                Toggle("Enable One-Finger Drawing", isOn: $oneFingerDrawingEnabled)
                    .disabled(!trackpadCharacterRecognitionEnabled)
                Toggle("Enable Two-Finger Drawing", isOn: $twoFingerDrawingEnabled)
                    .disabled(!trackpadCharacterRecognitionEnabled)
                Toggle("Enable Magic Mouse Character Recognition", isOn: $magicMouseCharacterRecognitionEnabled)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Index / Ring Distance")
                        Spacer()
                        Text(characterRecognitionDistance, format: .number.precision(.fractionLength(2)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $characterRecognitionDistance, in: 0.18 ... 0.50)
                }

                Picker("Mouse Recognition Button", selection: $characterRecognitionMouseButton) {
                    Text("Middle Click").tag(0)
                    Text("Right Click").tag(1)
                }
                .pickerStyle(.segmented)
                .disabled(!magicMouseCharacterRecognitionEnabled)

                Text("Trackpad one-finger and two-finger drawing, plus Magic Mouse drag-to-character, are now wired up in Swift. Character overlay timing is much closer to the legacy build, but threshold calibration still needs real-device tuning.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
