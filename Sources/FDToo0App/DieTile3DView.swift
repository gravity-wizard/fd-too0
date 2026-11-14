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
    public let hintDirection: TumbleDirection?
    public let lastTipDirection: TumbleDirection?

    public init(
        die: BoardDie,
        appearance: BoardAppearanceMode,
        isSelected: Bool,
        hintDirection: TumbleDirection?,
        lastTipDirection: TumbleDirection?
    ) {
        self.die = die
        self.appearance = appearance
        self.isSelected = isSelected
        self.hintDirection = hintDirection
        self.lastTipDirection = lastTipDirection
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

            ZStack {
                // 3D Porcelain Cushion Base
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(shadowColor)
                    .offset(y: side * 0.055)

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
                                isSelected ? Color.yellow.opacity(0.95) : bevelColor.opacity(0.85),
                                lineWidth: isSelected ? 2.8 : 1.4
                            )
                    )

                // Standard 3x3 Die Pip Matrix (1...6)
                PipMatrixView(pipCount: die.orientation.top, pipDiameter: pipSize, pipColor: pipColor)
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
                .degrees(lastTipDirection == nil ? 0 : 12),
                axis: rotationAxis(for: lastTipDirection),
                perspective: 0.55
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .animation(.spring(response: 0.26, dampingFraction: 0.72), value: die.orientation)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isSelected)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func rotationAxis(for direction: TumbleDirection?) -> (x: CGFloat, y: CGFloat, z: CGFloat) {
        switch direction {
        case .north: return (1, 0, 0)
        case .south: return (-1, 0, 0)
        case .east:  return (0, 1, 0)
        case .west:  return (0, -1, 0)
        case .none:  return (0, 0, 1)
        }
    }
}

private struct PipMatrixView: View {
    let pipCount: Int
    let pipDiameter: CGFloat
    let pipColor: Color

    // Active indices in a 3x3 grid (0..8) for standard dice faces 1..6
    private var activeSlots: Set<Int> {
        switch pipCount {
        case 1: return [4]
        case 2: return [2, 6]
        case 3: return [2, 4, 6]
        case 4: return [0, 2, 6, 8]
        case 5: return [0, 2, 4, 6, 8]
        default: return [0, 2, 3, 5, 6, 8]
        }
    }

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
