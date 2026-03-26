import SwiftUI

struct SettingsCharacterRecognitionCalibrationCard: View {
    @Binding var isDiagnosticsEnabled: Bool
    @Binding var hintDelay: Double
    @Binding var trackpadMinimumTravel: Double
    @Binding var trackpadValidationSegments: Int
    @Binding var magicMouseMinimumTravel: Double
    @Binding var magicMouseActivationSegments: Int
    let diagnostics: CharacterRecognitionDiagnosticsStore
    let onClearDiagnostics: () -> Void

    var body: some View {
        JitouchSurfaceCard(
            title: "Calibration & Diagnostics",
            subtitle: "Tune thresholds and inspect recognizer output without needing the old debug-only tooling.",
            symbol: "waveform.path.ecg",
            tint: .pink
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Enable Live Character Diagnostics", isOn: $isDiagnosticsEnabled)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Hint Delay")
                        Spacer()
                        Text(hintDelay, format: .number.precision(.fractionLength(2)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $hintDelay, in: 0.10 ... 0.60)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Trackpad Min Travel")
                        Spacer()
                        Text(trackpadMinimumTravel, format: .number.precision(.fractionLength(5)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $trackpadMinimumTravel, in: 0.00005 ... 0.0010)
                }

                Stepper(
                    "Trackpad Validation Segments: \(trackpadValidationSegments)",
                    value: $trackpadValidationSegments,
                    in: 2 ... 10
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Magic Mouse Min Travel")
                        Spacer()
                        Text(magicMouseMinimumTravel, format: .number.precision(.fractionLength(2)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $magicMouseMinimumTravel, in: 1.0 ... 15.0)
                }

                Stepper(
                    "Magic Mouse Activation Segments: \(magicMouseActivationSegments)",
                    value: $magicMouseActivationSegments,
                    in: 2 ... 8
                )

                HStack(spacing: 12) {
                    Button("Clear Diagnostics", action: onClearDiagnostics)

                    Text("These controls are stored in the same preference domain, so calibration survives restarts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if let snapshot = diagnostics.liveSnapshot {
                    SettingsLiveRecognitionSnapshotView(snapshot: snapshot)
                } else {
                    SettingsSecondaryPlaceholderText(text: "No live character-recognition snapshot yet.")
                }

                if !diagnostics.recentSnapshots.isEmpty {
                    Divider()
                    SettingsRecentRecognitionSessionsView(snapshots: diagnostics.recentSnapshots)
                }
            }
        }
    }
}

private struct SettingsLiveRecognitionSnapshotView: View {
    let snapshot: CharacterRecognitionDiagnosticSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Snapshot")
                .font(.headline)

            SettingsKeyValueGrid(items: summaryItems)

            if !snapshot.candidates.isEmpty {
                SettingsMonospacedReadoutSection(
                    title: "Top Candidates",
                    text: snapshot.candidateLines
                )
            }
        }
    }

    private var summaryItems: [SettingsKeyValueItem] {
        [
            SettingsKeyValueItem(label: "Source", value: snapshot.source.title),
            SettingsKeyValueItem(label: "Phase", value: snapshot.phase.title),
            SettingsKeyValueItem(label: "Segments", value: "\(snapshot.segmentCount)"),
            SettingsKeyValueItem(label: "Hint", value: snapshot.hint ?? "None"),
            SettingsKeyValueItem(label: "Recognized", value: snapshot.recognizedCharacter?.value ?? "Pending"),
            SettingsKeyValueItem(label: "Reason", value: snapshot.reason ?? "None"),
            SettingsKeyValueItem(label: "Span", value: snapshot.spanDescription),
            SettingsKeyValueItem(
                label: "Updated",
                value: snapshot.timestamp.formatted(date: .omitted, time: .standard)
            ),
        ]
    }
}

private struct SettingsRecentRecognitionSessionsView: View {
    let snapshots: [CharacterRecognitionDiagnosticSnapshot]

    var body: some View {
        SettingsMonospacedReadoutSection(
            title: "Recent Sessions",
            text: recentSnapshotLines
        )
    }

    private var recentSnapshotLines: String {
        snapshots
            .prefix(5)
            .map { snapshot in
                let outcome = snapshot.recognizedCharacter?.value ?? snapshot.hint ?? "No Match"
                return "\(snapshot.timestamp.formatted(date: .omitted, time: .standard))  \(snapshot.source.title)  \(snapshot.phase.title)  \(outcome)"
            }
            .joined(separator: "\n")
    }
}

private extension CharacterRecognitionDiagnosticSnapshot {
    var spanDescription: String {
        guard let verticalSpan, let horizontalSpan else {
            return "Not sampled"
        }

        return "\(verticalSpan.formatted(.number.precision(.fractionLength(3)))) x \(horizontalSpan.formatted(.number.precision(.fractionLength(3))))"
    }

    var candidateLines: String {
        candidates.map { candidate in
            let score = candidate.score.formatted(.number.precision(.fractionLength(2)))
            let progress = "\(candidate.matchedSegments)/\(candidate.totalSegments)"
            let completion = candidate.isComplete ? "complete" : "tracking"
            let geometry = candidate.isAcceptedByGeometry ? "accepted" : "geometry-filtered"
            return "\(candidate.value.padding(toLength: 8, withPad: " ", startingAt: 0)) score \(score)  segments \(progress)  \(completion)  \(geometry)"
        }
        .joined(separator: "\n")
    }
}
