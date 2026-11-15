//
//  DieTile3DView.swift
//  FD_too0
//
//  Sculpted Matte-Porcelain Pastel Die View with Recessed Pips (1...6),
//  3D Perspective Tumble Spring, Frost Glaze, Chain Lock & Pad Overlays.
//

import SwiftUI
import FDToo0Core

public struct DieTile3DView: View {
    public let die: BoardDie
    public let appearance: BoardAppearanceMode
    public let isSelected: Bool
    public let isMatchGlowing: Bool
    public let springResponse: Double
    public let hintDirection: TumbleDirection?
    public let activeRollDirection: TumbleDirection?
    public let rollTriggerID: Int

    @State private var rollAngle: Double = 0
    @State private var rollOffsetFraction: CGFloat = 0

    public init(
        die: BoardDie,
        appearance: BoardAppearanceMode,
        isSelected: Bool,
        isMatchGlowing: Bool = false,
        springResponse: Double = 0.46,
        hintDirection: TumbleDirection?,
        lastTipDirection: TumbleDirection?,
        rollTriggerID: Int = 0
    ) {
        self.die = die
        self.appearance = appearance
        self.isSelected = isSelected
        self.isMatchGlowing = isMatchGlowing
        self.springResponse = springResponse
        self.hintDirection = hintDirection
        self.activeRollDirection = lastTipDirection
        self.rollTriggerID = rollTriggerID
    }

    public var body: some View {
        let tokens = die.pastelHue.rgbTokens(for: appearance)
        let bodyColor = Color(red: tokens.body.0, green: tokens.body.1, blue: tokens.body.2)
        let bevelColor = Color(red: tokens.bevel.0, green: tokens.bevel.1, blue: tokens.bevel.2)
        let shadowColor = Color(red: tokens.shadow.0, green: tokens.shadow.1, blue: tokens.shadow.2)
        let pipColor = Color(red: tokens.pip.0, green: tokens.pip.1, blue: tokens.pip.2)

        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let corner = side * 0.22
            let pipSize = side * 0.165
            let stepDist = side + 8.0

            ZStack {
                // 3D Porcelain Cushion Extrusion
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(shadowColor)
                    .offset(
                        x: extrusionOffset(for: activeRollDirection, fraction: rollOffsetFraction, side: side).width,
                        y: side * 0.06 + extrusionOffset(for: activeRollDirection, fraction: rollOffsetFraction, side: side).height
                    )

                // Top Sculpted Pastel Face
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [bevelColor, bodyColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(
                                isMatchGlowing
                                    ? Color(red: 0.99, green: 0.89, blue: 0.52)
                                    : (isSelected ? Color.yellow.opacity(0.95) : bevelColor.opacity(0.85)),
                                lineWidth: isMatchGlowing ? 3.2 : (isSelected ? 2.8 : 1.4)
                            )
                    )

                // True 3D Casino Die Pip Matrix (1...6, respecting yaw for 2, 3, and 6 rails!)
                PipMatrixView(
                    activeSlots: die.orientation.topFacePipSlots,
                    pipDiameter: pipSize,
                    pipColor: pipColor
                )
                    .padding(side * 0.18)

                // Frosted Ice Overlay
                if die.frostLayers > 0 {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(Color.cyan.opacity(0.22))
                        .overlay(
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.75), lineWidth: 2)
                        )
                        .overlay(alignment: .topTrailing) {
                            Text("❄︎")
                                .font(.system(size: side * 0.22, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(4)
                        }
                }

                // Chained Lock Overlay
                if die.isChained {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2.2, dash: [5, 3]))
                        .foregroundStyle(Color.orange.opacity(0.9))
                        .overlay(alignment: .bottomTrailing) {
                            Text("⛓")
                                .font(.system(size: side * 0.20))
                                .padding(3)
                        }
                }

                // Solver Hint Arrow Badge
                if let hintDir = hintDirection {
                    Text(hintDir.arrowGlyph)
                        .font(.system(size: side * 0.34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Circle().fill(Color.black.opacity(0.72)))
                }
            }
            .rotation3DEffect(
                .degrees(rollAngle),
                axis: rotationAxis(for: activeRollDirection),
                perspective: 0.62
            )
            .offset(
                x: travelOffset(for: activeRollDirection, step: stepDist * rollOffsetFraction).width,
                y: travelOffset(for: activeRollDirection, step: stepDist * rollOffsetFraction).height
            )
            .scaleEffect(isMatchGlowing ? 1.07 : (isSelected ? 1.04 : 1.0))
            .animation(.easeInOut(duration: 0.18), value: isMatchGlowing)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isSelected)
            .onAppear {
                triggerRollAnimation()
            }
            .onChange(of: rollTriggerID) { _, _ in
                triggerRollAnimation()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .zIndex(rollOffsetFraction > 0.01 ? 10 : 1)
    }

    private func triggerRollAnimation() {
        guard activeRollDirection != nil, rollTriggerID > 0 else { return }
        rollAngle = -82
        rollOffsetFraction = 1.0
        withAnimation(.spring(response: springResponse, dampingFraction: 0.76)) {
            rollAngle = 0
            rollOffsetFraction = 0
        }
    }

    private func rotationAxis(for direction: TumbleDirection?) -> (x: CGFloat, y: CGFloat, z: CGFloat) {
        switch direction {
        case .north: return (1, 0, 0)
        case .south: return (-1, 0, 0)
        case .east:  return (0, 1, 0)
        case .west:  return (0, -1, 0)
        case .none:  return (0, 1, 0)
        }
    }

    private func travelOffset(for direction: TumbleDirection?, step: CGFloat) -> CGSize {
        switch direction {
        case .north: return CGSize(width: 0, height: step)
        case .south: return CGSize(width: 0, height: -step)
        case .east:  return CGSize(width: -step, height: 0)
        case .west:  return CGSize(width: step, height: 0)
        case .none:  return .zero
        }
    }

    private func extrusionOffset(for direction: TumbleDirection?, fraction: CGFloat, side: CGFloat) -> CGSize {
        let depth = side * 0.12 * fraction
        switch direction {
        case .north: return CGSize(width: 0, height: -depth)
        case .south: return CGSize(width: 0, height: depth)
        case .east:  return CGSize(width: depth, height: 0)
        case .west:  return CGSize(width: -depth, height: 0)
        case .none:  return .zero
        }
    }
}

private struct PipMatrixView: View {
    let activeSlots: Set<Int>
    let pipDiameter: CGFloat
    let pipColor: Color

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { col in
                        let idx = row * 3 + col
                        ZStack {
                            if activeSlots.contains(idx) {
                                Circle()
                                    .fill(pipColor)
                                    .frame(width: pipDiameter, height: pipDiameter)
                                    .shadow(color: .white.opacity(0.28), radius: 0.6, x: 0, y: 0.8)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }
}
