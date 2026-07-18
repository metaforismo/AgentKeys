import SwiftUI

// MARK: - Design tokens

enum DeckTheme {
    /// Soft studio backdrop behind the device.
    static let studio = Color(red: 0.956, green: 0.960, blue: 0.968)

    /// Printed-legend ink used for silkscreen text on the plate.
    static let silkscreen = Color(red: 0.36, green: 0.38, blue: 0.42)

    /// Thin-line icon ink on matte keycaps.
    static let ink = Color(red: 0.13, green: 0.14, blue: 0.17)

    /// Matte keycap surface.
    static let capTop = Color(white: 0.998)
    static let capBottom = Color(red: 0.885, green: 0.895, blue: 0.915)

    /// Dark switch housing that peeks out under every cap.
    static let housing = Color(red: 0.10, green: 0.10, blue: 0.12)

    /// Warm-white LED used by idle channels, so every populated key reads lit.
    static let idleGlow = Color(red: 0.93, green: 0.95, blue: 1.0)

    /// RGB underglow ring, sampled from the acrylic edge in the reference shots.
    static let glow: [Color] = [
        Color(red: 0.33, green: 0.94, blue: 0.70),
        Color(red: 0.40, green: 0.85, blue: 0.99),
        Color(red: 0.50, green: 0.62, blue: 1.00),
        Color(red: 0.83, green: 0.70, blue: 1.00),
        Color(red: 0.36, green: 0.93, blue: 0.78)
    ]
}

// MARK: - Press behaviour

/// Keys travel straight down like a real switch instead of scaling.
struct TactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .spring(response: 0.20, dampingFraction: 0.9),
                value: configuration.isPressed
            )
    }
}

/// Reports the press state outward so a key can sink its cap into a static
/// housing — the housing must not travel with the cap.
struct PressTrackingButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
}

// MARK: - Silkscreen

struct Silkscreen: View {
    let text: String
    var size: CGFloat = 9
    var opacity: Double = 0.9
    @ScaledMetric(relativeTo: .caption2) private var scale = 1.0

    var body: some View {
        Text(text)
            .font(.system(size: size * scale, weight: .medium))
            .kerning(0.9)
            .foregroundStyle(DeckTheme.silkscreen.opacity(opacity))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Fasteners, LEDs, ports

struct DeckScrew: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.32), Color(white: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "hexagon.fill")
                .font(.system(size: 5))
                .foregroundStyle(.black.opacity(0.9))

            Capsule()
                .fill(.white.opacity(0.28))
                .frame(width: 4.5, height: 1)
                .rotationEffect(.degrees(-40))
        }
        .frame(width: 11, height: 11)
        .shadow(color: .white.opacity(0.9), radius: 1, x: -0.5, y: -0.5)
        .accessibilityHidden(true)
    }
}

struct DeckLED: View {
    let color: Color
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(0.85))
                    .frame(width: size * 0.32, height: size * 0.32)
                    .padding(size * 0.15)
            }
            .shadow(color: color.opacity(0.8), radius: size * 0.7)
    }
}

/// The tiny SMD LED cluster and reset port from the bottom-left of the board.
struct BoardDetailCluster: View {
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                SMDLed(tint: .white)
                SMDLed(tint: Color(red: 1.0, green: 0.84, blue: 0.35))
                SMDLed(tint: Color(red: 1.0, green: 0.84, blue: 0.35))
            }

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.16), .black],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: 16
                        )
                    )
                    .frame(width: 22, height: 22)

                Circle()
                    .stroke(.white.opacity(0.6), lineWidth: 1)
                    .frame(width: 28, height: 28)
            }
        }
        .accessibilityHidden(true)
    }

    private struct SMDLed: View {
        let tint: Color

        var body: some View {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 6, height: 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .stroke(.black.opacity(0.25), lineWidth: 0.5)
                }
                .shadow(color: tint.opacity(0.7), radius: 1.5)
        }
    }
}

// MARK: - Matte keycap

/// A matte white keycap with a thin-line icon, sitting on a dark switch housing.
struct MatteKeycap<Icon: View>: View {
    var caption: String? = nil
    var enabled: Bool = true
    var height: CGFloat = 64
    var accessibilityID: String = ""
    let action: () -> Void
    @ViewBuilder let icon: Icon

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var heightScale = 1.0

    private var capHeight: CGFloat { height * min(heightScale, 1.4) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    // The housing stays put; only the cap travels.
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(DeckTheme.housing)
                        .padding(.horizontal, 8)
                        .frame(height: capHeight)
                        .offset(y: 6)

                    capFace
                        .offset(y: isPressed ? 4.5 : 0)
                }

                if let caption {
                    Silkscreen(text: caption, size: 8)
                }
            }
        }
        .buttonStyle(PressTrackingButtonStyle(isPressed: $isPressed))
        .animation(
            reduceMotion ? .easeOut(duration: 0.08) : .spring(response: 0.18, dampingFraction: 0.85),
            value: isPressed
        )
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed) { _, pressed in pressed }
        .disabled(!enabled)
        .accessibilityIdentifier(accessibilityID)
    }

    private var capFace: some View {
        icon
            .foregroundStyle(DeckTheme.ink.opacity(enabled ? 1 : 0.28))
            .frame(maxWidth: .infinity)
            .frame(height: capHeight)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DeckTheme.capTop, DeckTheme.capBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        // Soft finger dish pressed into the cap — highlight
                        // only, no printed ring.
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white, .white.opacity(0)],
                                    center: .init(x: 0.5, y: 0.42),
                                    startRadius: 1,
                                    endRadius: capHeight * 0.46
                                )
                            )
                            .padding(5)
                    }
                    .overlay {
                        // Crisp top light, soft shaded bottom lip.
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.35), .black.opacity(0.10)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
                    // The drop shadow collapses as the cap bottoms out.
                    .shadow(color: .black.opacity(0.10), radius: isPressed ? 1 : 2, y: isPressed ? 0.5 : 1)
                    .shadow(color: .black.opacity(0.10), radius: isPressed ? 2 : 6, y: isPressed ? 1.5 : 5)
            }
    }
}

// MARK: - Translucent agent switch key

/// A clear, RGB-backlit switch key — the exposed MX-style switch look from the
/// top rows of the reference device. The LED color is the agent status; idle
/// channels glow warm white so every populated key reads as powered.
struct AgentSwitchKey: View {
    let agent: Agent
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var heightScale = 1.0

    private var keyHeight: CGFloat { 66 * min(heightScale, 1.4) }
    private var isThinking: Bool { agent.status == .thinking }

    private var glow: Color {
        agent.status == .idle ? DeckTheme.idleGlow : agent.status.color
    }

    private var bloom: Double {
        if isSelected { return 1.0 }
        return agent.status == .idle ? 0.55 : 0.8
    }

    /// Base bloom modulated by the thinking breath and by finger pressure —
    /// pressing a key drives its LED brighter, like bottoming out a switch.
    private var effectiveBloom: Double {
        var value = bloom
        if isThinking { value *= breathing ? 1.3 : 0.75 }
        if isPressed { value = min(1.5, value * 1.35) }
        return value
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    // Color-stained housing under the clear cap; stays put.
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [glow.opacity(0.55), Color.black.opacity(0.92)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(.horizontal, 7)
                        .frame(height: keyHeight)
                        .offset(y: 6)

                    // LED bloom escaping around the cap.
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(glow)
                        .frame(height: keyHeight)
                        .blur(radius: 13)
                        .opacity(0.45 * effectiveBloom)

                    capFace
                        .offset(y: isPressed ? 4.5 : 0)
                }

                Silkscreen(text: agent.name.uppercased(), size: 8)
            }
        }
        .buttonStyle(PressTrackingButtonStyle(isPressed: $isPressed))
        .animation(
            reduceMotion ? .easeOut(duration: 0.08) : .spring(response: 0.18, dampingFraction: 0.85),
            value: isPressed
        )
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed) { _, pressed in pressed }
        .onAppear { updateBreathing() }
        .onChange(of: isThinking) { updateBreathing() }
        .onChange(of: reduceMotion) { updateBreathing() }
        .accessibilityIdentifier("deck-agent-key-\(agent.name)")
        .accessibilityLabel("\(agent.name), \(agent.status.label), \(agent.task)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func updateBreathing() {
        if isThinking && !reduceMotion {
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                breathing = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.4)) {
                breathing = false
            }
        }
    }

    private var capFace: some View {
        ZStack {
            // Frosted cap body.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.42))

            // The LED sits under the stem: a tight radial bloom, not a fill.
            RadialGradient(
                colors: [
                    glow.opacity(min(1, 0.95 * effectiveBloom)),
                    glow.opacity(0.35 * effectiveBloom),
                    glow.opacity(0.06)
                ],
                center: .center,
                startRadius: 2,
                endRadius: 46
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Inner clear-cap wall.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.78), lineWidth: 1)
                .padding(10)

            SwitchStem(tint: Color(red: 0.27, green: 0.30, blue: 0.46))

            // Diagonal specular sheen across the acrylic.
            LinearGradient(
                colors: [.white.opacity(0.55), .white.opacity(0.0), .white.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ? glow.opacity(0.95) : .white.opacity(0.9),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .frame(height: keyHeight)
        .shadow(color: glow.opacity(min(1, 0.35 * effectiveBloom)), radius: 10, y: 3)
    }
}

/// The cross-shaped MX switch stem visible through the clear cap.
struct SwitchStem: View {
    var tint: Color = Color(red: 0.27, green: 0.30, blue: 0.46)

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.26))
                .frame(width: 24, height: 24)

            Circle()
                .stroke(tint.opacity(0.4), lineWidth: 1)
                .frame(width: 24, height: 24)

            Capsule()
                .fill(tint)
                .frame(width: 15, height: 4)

            Capsule()
                .fill(tint)
                .frame(width: 4, height: 15)
        }
        .accessibilityHidden(true)
    }
}

/// A vacant socket: no switch installed, just the dashed mount outline and
/// bare contacts, so it cannot be mistaken for an idle (powered) channel.
struct EmptySwitchKey: View {
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var heightScale = 1.0

    private var keyHeight: CGFloat { 66 * min(heightScale, 1.4) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.black.opacity(0.03))

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            DeckTheme.silkscreen.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )

                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(DeckTheme.silkscreen.opacity(0.55))
                }
                .frame(height: keyHeight)

                Silkscreen(text: "ADD", size: 8, opacity: 0.5)
            }
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityIdentifier("deck-add-agent")
        .accessibilityLabel("Add or connect an agent")
    }
}

// MARK: - Knob

/// Pie-slice wedge scooped out of the knob face.
private struct KnobWedge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(
            center: center,
            radius: rect.width / 2,
            startAngle: .degrees(-114),
            endAngle: .degrees(-36),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

/// The white rotary knob with the machined scoop cut, top-left on the device.
struct DeckKnob: View {
    let caption: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.22))
                        .frame(width: 64, height: 64)
                        .offset(y: 4)
                        .blur(radius: 3)

                    // Cylinder side wall.
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(white: 0.74)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    // Top face, inset from the wall so the rim reads as depth.
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, Color(white: 0.88)],
                                center: .init(x: 0.35, y: 0.3),
                                startRadius: 2,
                                endRadius: 40
                            )
                        )
                        .frame(width: 56, height: 56)

                    // Machined scoop cut into the top face: shaded floor,
                    // dark inner edge, bright outer lip.
                    ZStack {
                        KnobWedge()
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.66), Color(white: 0.84)],
                                    startPoint: .init(x: 0.5, y: 0.5),
                                    endPoint: .init(x: 0.5, y: 0.0)
                                )
                            )

                        KnobWedge()
                            .stroke(Color(white: 0.55).opacity(0.85), lineWidth: 1)

                        KnobWedge()
                            .stroke(.white.opacity(0.9), lineWidth: 1)
                            .offset(y: 1)
                            .blendMode(.screen)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .rotationEffect(.degrees(26))
                }
                .frame(height: 72)

                Silkscreen(text: caption.uppercased(), size: 8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityIdentifier("deck-mode-knob")
        .accessibilityLabel(caption)
    }
}

// MARK: - Joystick

private struct Octagon: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let inset = width * 0.29
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + inset))
        path.closeSubpath()
        return path
    }
}

/// The black four-way hat switch on its metal mount, top-right on the device.
struct DeckJoystick: View {
    let caption: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    // Dashed silkscreen outline around the module.
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(
                            DeckTheme.silkscreen.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1, dash: [3.5, 3])
                        )
                        .frame(width: 68, height: 68)

                    // Brushed metal mount plate.
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.94), Color(white: 0.76)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(.white.opacity(0.9), lineWidth: 0.75)
                        }
                        .overlay { mountScrews }

                    // Rubber hat: octagonal cap with a fine X-shaped groove.
                    Octagon()
                        .fill(.black.opacity(0.35))
                        .frame(width: 42, height: 42)
                        .offset(y: 2.5)
                        .blur(radius: 2)

                    Octagon()
                        .fill(
                            RadialGradient(
                                colors: [Color(white: 0.34), Color(white: 0.06)],
                                center: .init(x: 0.35, y: 0.3),
                                startRadius: 2,
                                endRadius: 29
                            )
                        )
                        .frame(width: 42, height: 42)
                        .overlay {
                            Octagon()
                                .stroke(.white.opacity(0.22), lineWidth: 0.75)
                        }

                    // Fine engraved X-groove.
                    ForEach(0..<4, id: \.self) { index in
                        ZStack {
                            Capsule()
                                .fill(.white.opacity(0.14))
                                .frame(width: 3, height: 10)
                                .offset(x: 0.8, y: -9.2)

                            Capsule()
                                .fill(.black.opacity(0.9))
                                .frame(width: 2.5, height: 10)
                                .offset(y: -9.5)
                        }
                        .rotationEffect(.degrees(Double(index) * 90 + 45))
                    }

                    Circle()
                        .fill(.black.opacity(0.85))
                        .frame(width: 5, height: 5)
                }
                .frame(height: 72)

                Silkscreen(text: caption.uppercased(), size: 8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityIdentifier("deck-control-stick")
        .accessibilityLabel("Agent controls")
    }

    private var mountScrews: some View {
        VStack {
            HStack {
                MountScrew()
                Spacer()
                MountScrew()
            }
            Spacer()
            HStack {
                MountScrew()
                Spacer()
                MountScrew()
            }
        }
        .padding(3.5)
    }

    private struct MountScrew: View {
        var body: some View {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.55), Color(white: 0.25)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 3
                    )
                )
                .frame(width: 4, height: 4)
        }
    }
}
