import AppKit
import SwiftUI

/// Dark glass design tokens shared by the lookup panel and the app's windows.
/// The app is dark only; `InstaLingoApp` forces the dark appearance.
enum Theme {
    static let panelFill = Color(red: 30 / 255, green: 30 / 255, blue: 34 / 255).opacity(0.86)
    static let surface = Color.white.opacity(0.06)
    static let surfaceStroke = Color.white.opacity(0.08)
    static let field = Color.white.opacity(0.08)
    static let fieldStroke = Color.white.opacity(0.10)
    static let control = Color.white.opacity(0.08)
    static let controlHover = Color.white.opacity(0.14)
    static let controlStroke = Color.white.opacity(0.12)
    static let hairline = Color.white.opacity(0.07)

    static let textPrimary = Color(hex: 0xF5F5F7)
    static let textBody = Color(hex: 0xD8D8DC)
    static let textSecondary = Color(hex: 0xA1A1A6)
    static let textTertiary = Color(hex: 0x98989D)
    static let iconDefault = Color(hex: 0xC7C7CC)

    static let accent = Color(hex: 0x0A6FE0)
    static let accentBright = Color(hex: 0x0A84FF)
    static let accentSoft = Color(hex: 0x7AB8FF)
    static let accentTint = Color(hex: 0x0A84FF).opacity(0.2)
    static let star = Color(hex: 0xE0A100)
    static let success = Color(hex: 0x30D158)
    static let warning = Color(hex: 0xFFB340)
    static let warningTint = Color(hex: 0xFF9F0A).opacity(0.2)
    static let danger = Color(hex: 0xFF6961)
    static let dangerTint = Color(hex: 0xFF453A).opacity(0.2)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Surfaces

extension View {
    /// The rounded translucent card that holds panel content.
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Theme.surfaceStroke)
            }
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.4)
            .textCase(.uppercase)
            .foregroundStyle(Theme.textSecondary)
    }
}

/// A 28 pt rounded square with a tinted symbol, used by message states.
struct TintedIcon: View {
    let systemName: String
    let color: Color
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(tint, in: RoundedRectangle(cornerRadius: 7))
            .accessibilityHidden(true)
    }
}

/// A keyboard shortcut rendered as a small key cap.
struct KeyCap: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(.system(size: 10))
            .foregroundStyle(Theme.iconDefault)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
    }
}

/// Loading placeholder bar with a shimmer that stops when Reduce Motion is on.
struct SkeletonBar: View {
    let widthFraction: CGFloat
    let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            let base = Color.white.opacity(0.07)
            RoundedRectangle(cornerRadius: 6)
                .fill(base)
                .overlay {
                    if !reduceMotion {
                        LinearGradient(
                            colors: [base, Color.white.opacity(0.16), base],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width)
                        .offset(x: phase * geometry.size.width)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: geometry.size.width * widthFraction)
        }
        .frame(height: height)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// MARK: - Button styles

/// Borderless 26 pt icon button with a hover highlight.
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 26

    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration, size: size)
    }

    private struct HoverBody: View {
        let configuration: Configuration
        let size: CGFloat
        @State private var isHovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isHovered ? Theme.textPrimary : Theme.iconDefault)
                .frame(width: size, height: size)
                .background(
                    isHovered || configuration.isPressed ? Color.white.opacity(0.06) : .clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .opacity(isEnabled ? 1 : 0.4)
                .onHover { isHovered = $0 }
        }
    }
}

/// The blue call-to-action button.
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        PrimaryBody(configuration: configuration, height: height)
    }

    private struct PrimaryBody: View {
        let configuration: Configuration
        let height: CGFloat
        @State private var isHovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: height > 28 ? 13 : 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, height > 28 ? 14 : 11)
                .frame(height: height)
                .background(
                    configuration.isPressed ? Theme.accentBright : (isHovered ? Theme.accentBright : Theme.accent),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .center)
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .opacity(isEnabled ? 1 : 0.45)
                .onHover { isHovered = $0 }
        }
    }
}

/// Quiet bordered button for secondary actions such as Save and Copy.
struct ActionButtonStyle: ButtonStyle {
    var height: CGFloat = 24

    func makeBody(configuration: Configuration) -> some View {
        ActionBody(configuration: configuration, height: height)
    }

    private struct ActionBody: View {
        let configuration: Configuration
        let height: CGFloat
        @State private var isHovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: height > 26 ? 13 : 11.5))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, height > 26 ? 12 : 8)
                .frame(height: height)
                .background(
                    isHovered || configuration.isPressed ? Theme.controlHover : Theme.control,
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.controlStroke)
                }
                .contentShape(RoundedRectangle(cornerRadius: 7))
                .opacity(isEnabled ? 1 : 0.45)
                .onHover { isHovered = $0 }
        }
    }
}

/// Capsule chip used for professional contexts and captured words.
struct ChipButtonStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        ChipBody(configuration: configuration, isOn: isOn)
    }

    private struct ChipBody: View {
        let configuration: Configuration
        let isOn: Bool
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(isOn ? .white : Theme.textPrimary)
                .padding(.horizontal, 10)
                .frame(minWidth: 24, minHeight: 24)
                .background(isOn ? Theme.accent : Theme.control, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(
                        isOn ? Theme.accent : Color.white.opacity(isHovered ? 0.25 : 0.12)
                    )
                }
                .contentShape(Capsule())
                .opacity(configuration.isPressed ? 0.8 : 1)
                .onHover { isHovered = $0 }
        }
    }
}

/// Full-width list row with a subtle hover highlight.
struct HoverRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowBody(configuration: configuration)
    }

    private struct RowBody: View {
        let configuration: Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.white.opacity(configuration.isPressed ? 0.08 : (isHovered ? 0.045 : 0)),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onHover { isHovered = $0 }
        }
    }
}

/// Compact segmented control drawn to match the glass panel.
struct GlassMenuPicker<Value: Hashable>: View {
    let label: String
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    @State private var isHovered = false

    private var selectedTitle: String {
        options.first { $0.value == selection }?.title ?? ""
    }

    var body: some View {
        Menu {
            Picker(label, selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.title).tag(option.value)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "globe")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text(selectedTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Theme.control, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(isHovered ? 0.25 : 0.12))
            }
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { isHovered = $0 }
        .help(label)
        .accessibilityLabel(label)
        .accessibilityValue(selectedTitle)
    }
}

/// Lays out children left to right and wraps onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if proposedWidth > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

enum SystemSettingsLink {
    static let accessibility = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    static let screenRecording = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
}
