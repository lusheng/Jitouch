import SwiftUI

struct SettingsSidebarView<Header: View, Footer: View>: View {
    let header: Header
    let footer: Footer
    @Binding var selectedPane: JitouchSettingsPane?

    init(
        selectedPane: Binding<JitouchSettingsPane?>,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        self._selectedPane = selectedPane
        self.header = header()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Text("SETTINGS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(JitouchSettingsPane.allCases) { pane in
                    sidebarButton(for: pane)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.54))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
            )

            Spacer(minLength: 0)

            footer
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.973, green: 0.977, blue: 0.984),
                    Color(red: 0.962, green: 0.967, blue: 0.976),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func sidebarButton(for pane: JitouchSettingsPane) -> some View {
        let isSelected = selectedPane == pane

        return Button {
            selectedPane = pane
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.white.opacity(0.58))

                    Image(systemName: pane.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 0) {
                    Text(pane.title)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.92) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.black.opacity(0.05) : Color.clear, lineWidth: 1)
            )
            .shadow(
                color: isSelected ? Color.black.opacity(0.025) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
