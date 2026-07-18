import SwiftUI

// MARK: - Design tokens

enum DeckTheme {
    /// Soft studio backdrop behind the device.
    static let studio = Color(red: 0.956, green: 0.960, blue: 0.968)

    /// Printed-legend ink used for silkscreen text on the plate.
    static let silkscreen = Color(red: 0.38, green: 0.40, blue: 0.44)

    /// Thin-line icon ink on matte keycaps.
    static let ink = Color(red: 0.13, green: 0.14, blue: 0.17)

    /// Matte keycap surface.
    static let capTop = Color(white: 0.995)
    static let capBottom = Color(red: 0.905, green: 0.915, blue: 0.935)

    /// Dark switch housing that peeks out under every cap.
    static let housing = Color(red: 0.12, green: 0.12, blue: 0.14)

    /// RGB underglow ring, sampled from the acrylic edge in the reference shots.
    static let glow: [Color] = [
        Color(red: 0.40, green: 0.93, blue: 0.72),
        Color(red: 0.45, green: 0.86, blue: 0.98),
        Color(red: 0.55, green: 0.66, blue: 1.00),
        Color(red: 0.80, green: 0.72, blue: 1.00),
        Color(red: 0.42, green: 0.92, blue: 0.80)
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

// MARK: - Silkscreen

struct Silkscreen: View {
    let text: String
    var size: CGFloat = 7.5
    var opacity: Double = 0.85

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .medium))
            .kerning(0.7)
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
                        colors: [Color(white: 0.30), Color(white: 0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "hexagon.fill")
                .font(.system(size: 4.5))
                .foregroundStyle(.black.opacity(0.9))

            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 4, height: 1)
                .rotationEffect(.degrees(-40))
        }
        .frame(width: 10, height: 10)
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
        HStack(spacing: 7) {
            VStack(alignment: .leading, spacing: 2.5) {
                SMDLed(tint: .white)
                SMDLed(tint: Color(red: 1.0, green: 0.84, blue: 0.35))
                SMDLed(tint: Color(red: 1.0, green: 0.84, blue: 0.35))
            }

            Circle()
                .fill(Color.black)
                .frame(width: 21, height: 21)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.55), lineWidth: 1)
                        .padding(-3)
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
                .frame(width: 5, height: 3.5)
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
    var height: CGFloat = 62
    let action: () -> Void
    @ViewBuilder let icon: Icon

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(DeckTheme.housing)
                        .padding(.horizontal, 7)
                        .frame(height: height)
                        .offset(y: 6)

                    capFace
                }

                if let caption {
                    Silkscreen(text: caption, size: 6.5)
                }
            }
        }
        .buttonStyle(TactileButtonStyle())
        .disabled(!enabled)
    }

    private var capFace: some View {
        icon
            .foregroundStyle(DeckTheme.ink.opacity(enabled ? 1 : 0.30))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DeckTheme.capTop, DeckTheme.capBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        // Circular finger dish pressed into the cap.
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white.opacity(0.9), .white.opacity(0)],
                                    center: .center,
                                    startRadius: 1,
                                    endRadius: height * 0.42
                                )
                            )
                            .padding(6)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(.white.opacity(0.95), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.14), radius: 4, y: 4)
            }
    }
}

// MARK: - Translucent agent switch key

/// A clear, RGB-backlit switch key — the exposed MX-style switch look from the
/// top rows of the reference device. The LED color is the agent status.
struct AgentSwitchKey: View {
    let agent: Agent
    let isSelected: Bool
    let action: () -> Void

    private var lit: Bool { agent.status != .idle }
    private var glow: Color { agent.status.color }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(DeckTheme.housing)
                        .padding(.horizontal, 6)
                        .frame(height: 64)
                        .offset(y: 6)

                    // LED shining through the frosted cap.
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(glow)
                        .frame(height: 64)
                        .blur(radius: 12)
                        .opacity(lit ? (isSelected ? 0.85 : 0.55) : 0.14)

                    capFace
                }

                Silkscreen(text: agent.name.uppercased(), size: 6.5)
            }
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("\(agent.name), \(agent.status.label), \(agent.task)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var capFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.white.opacity(0.34))
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(glow.opacity(lit ? 0.30 : 0.05))
                }

            // Inner clear-cap wall.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.70), lineWidth: 1)
                .padding(9)

            SwitchStem(tint: stemTint)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(
                    isSelected ? glow.opacity(0.9) : .white.opacity(0.85),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .frame(height: 64)
        .shadow(color: glow.opacity(lit ? (isSelected ? 0.55 : 0.30) : 0.06), radius: 9, y: 3)
    }

    private var stemTint: Color {
        lit ? Color(red: 0.30, green: 0.33, blue: 0.48) : Color(white: 0.55)
    }
}

/// The cross-shaped MX switch stem visible through the clear cap.
struct SwitchStem: View {
    var tint: Color = Color(red: 0.30, green: 0.33, blue: 0.48)

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.30))
                .frame(width: 20, height: 20)

            Capsule()
                .fill(tint)
                .frame(width: 13, height: 3.5)

            Capsule()
                .fill(tint)
                .frame(width: 3.5, height: 13)
        }
        .accessibilityHidden(true)
    }
}

/// An unlit clear key for an empty agent slot.
struct EmptySwitchKey: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(DeckTheme.housing.opacity(0.55))
                        .padding(.horizontal, 6)
                        .frame(height: 64)
                        .offset(y: 6)

                    ZStack {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(.white.opacity(0.22))

                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.white.opacity(0.5), lineWidth: 1)
                            .padding(9)

                        SwitchStem(tint: Color(white: 0.68))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(.white.opacity(0.6), lineWidth: 1)
                    }
                    .frame(height: 64)
                }

                Silkscreen(text: "— — —", size: 6.5, opacity: 0.45)
            }
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("Add or connect an agent")
    }
}

// MARK: - Knob

/// The white rotary knob with the machined flat cut, top-left on the device.
struct DeckKnob: View {
    let caption: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.18))
                        .frame(width: 60, height: 60)
                        .offset(y: 4)
                        .blur(radius: 2)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(white: 0.84)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay { Circle().stroke(.white, lineWidth: 1) }

                    // Machined diagonal cut across the knob face.
                    Capsule()
                        .fill(Color(white: 0.78))
                        .frame(width: 52, height: 1.5)
                        .rotationEffect(.degrees(-45))
                        .mask(Circle().frame(width: 58, height: 58))

                    Capsule()
                        .fill(Color(white: 0.60))
                        .frame(width: 2.5, height: 14)
                        .offset(y: -17)
                        .rotationEffect(.degrees(38))
                }
                .frame(height: 70)

                Silkscreen(text: caption.uppercased(), size: 6.5)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TactileButtonStyle())
    }
}

// MARK: - Joystick

/// The black four-way hat switch, top-right on the device.
struct DeckJoystick: View {
    let caption: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                ZStack {
                    // Dashed silkscreen outline around the mount.
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            DeckTheme.silkscreen.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 2.5])
                        )
                        .frame(width: 62, height: 62)

                    Circle()
                        .fill(.black.opacity(0.30))
                        .frame(width: 50, height: 50)
                        .offset(y: 3)
                        .blur(radius: 2)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(white: 0.28), .black],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 34
                            )
                        )
                        .frame(width: 50, height: 50)

                    // Four-way cross indents on the stick cap.
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(.black.opacity(0.85))
                            .frame(width: 3, height: 9)
                            .offset(y: -12)
                            .rotationEffect(.degrees(Double(index) * 90 + 45))
                    }
                }
                .frame(height: 70)

                Silkscreen(text: caption.uppercased(), size: 6.5)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TactileButtonStyle())
    }
}
