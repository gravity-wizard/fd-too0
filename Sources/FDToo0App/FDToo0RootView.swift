//
//  FDToo0RootView.swift
//  FD_too0
//
//  Main Universal SwiftUI + SpriteKit Game Screen with Live Flipper (Classic FD <-> FD_too0),
//  Dark / Light / Spruce Wood Pastel Themes, 6-Face Cube Peek HUD, and Touch Swipe Controls.
//

import SwiftUI
import SpriteKit
import FDToo0Core

public struct FDToo0RootView: View {
    @State private var engine = GameEngine23(initialMode: .fdToo0, startLevel: 1)
    @State private var sparkleScene = CascadeSparkleScene(size: CGSize(width: 420, height: 420))
    @State private var showAtlas = false
    @State private var showRules = false
    @State private var lastTipDir: TumbleDirection? = nil

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    public init() {}

    private var trayBackground: Color {
        switch engine.appearanceMode {
        case .dark:   return Color(red: 0.10, green: 0.09, blue: 0.09)
        case .light:  return Color(red: 0.96, green: 0.94, blue: 0.90)
        case .spruce: return Color(red: 0.24, green: 0.17, blue: 0.12)
        }
    }

    private var windowBackground: Color {
        switch engine.appearanceMode {
        case .dark:   return Color(red: 0.06, green: 0.06, blue: 0.06)
        case .light:  return Color(red: 0.99, green: 0.98, blue: 0.95)
        case .spruce: return Color(red: 0.16, green: 0.11, blue: 0.08)
        }
    }

    private var primaryInk: Color {
        engine.appearanceMode == .light ? Color(red: 0.13, green: 0.11, blue: 0.10) : Color(red: 0.96, green: 0.94, blue: 0.90)
    }

    public var body: some View {
        ZStack {
            windowBackground.ignoresSafeArea()

            VStack(spacing: 12) {
                headerFlipperBar
                scoreSlatStrip
                boardTrayView
                selectedDieCompassHUD
                bottomControlDeck
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: 620)
        }
        .preferredColorScheme(engine.appearanceMode == .light ? .light : .dark)
        .onReceive(timer) { _ in
            engine.tickSecond()
        }
        .sheet(isPresented: $showAtlas) {
            WorldAtlasSheet(engine: engine)
        }
        .sheet(isPresented: $showRules) {
            RulesInspectorSheet()
        }
        .overlay {
            if engine.isWon {
                victoryOverlayCard
            }
        }
    }

    // MARK: - Top Flipper & Theme Bar

    private var headerFlipperBar: some View {
        HStack(spacing: 10) {
            Button {
                engine.toggleFlipper()
                TactileAudioHaptics.shared.playTumble(pip: 6)
            } label: {
                HStack(spacing: 6) {
                    Text("⇄")
                        .font(.headline.bold())
                    Text(engine.mode.shortBadge)
                        .font(.subheadline.weight(.heavy))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(engine.mode == .fdToo0 ? Color(red: 0.84, green: 0.56, blue: 0.34) : Color(red: 0.35, green: 0.62, blue: 0.52))
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button {
                showAtlas = true
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Lv \(engine.currentLevel) / 1023\(engine.blueprint.isBossLevel ? " • BOSS" : "")")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                    Text(engine.blueprint.world.name)
                        .font(.caption2)
                        .opacity(0.75)
                }
                .foregroundStyle(primaryInk)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                let modes = BoardAppearanceMode.allCases
                let idx = modes.firstIndex(of: engine.appearanceMode) ?? 0
                engine.appearanceMode = modes[(idx + 1) % modes.count]
            } label: {
                Text(engine.appearanceMode.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().strokeBorder(primaryInk.opacity(0.28), lineWidth: 1))
                    .foregroundStyle(primaryInk)
            }
            .buttonStyle(.plain)

            Button {
                showRules = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .foregroundStyle(primaryInk)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - ScoreSlat Telemetry Strip (Game_23.swift Heritage)

    private var scoreSlatStrip: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                statPill(
                    label: engine.mode == .fdToo0 ? "CLEARED" : "TARGET PIP",
                    value: engine.mode == .fdToo0
                        ? "\(engine.diceCleared)/\(engine.blueprint.targetDiceCleared)"
                        : "Pip \(engine.blueprint.targetHarmonyPip ?? 6)"
                )
                statPill(label: "MOVES / PAR", value: "\(engine.moves)/\(engine.blueprint.parMoves)")
                statPill(label: "TIME / PAR", value: "\(engine.elapsedSeconds)s/\(engine.blueprint.parSeconds)s")
                statPill(label: "SCORE", value: "\(engine.score)")
            }

            Text(engine.lastBanner)
                .font(.caption.weight(.medium))
                .foregroundStyle(primaryInk.opacity(0.84))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .opacity(0.65)
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(trayBackground)
        )
        .foregroundStyle(primaryInk)
    }

    // MARK: - Interactive Pastel Dice Tray + SpriteKit Sparkles

    private var boardTrayView: some View {
        let rows = engine.blueprint.rows
        let cols = engine.blueprint.cols

        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(trayBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(primaryInk.opacity(0.12), lineWidth: 1.5)
                )

            VStack(spacing: 8) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 8) {
                        ForEach(0..<cols, id: \.self) { c in
                            cellSlotView(row: r, col: c)
                        }
                    }
                }
            }
            .padding(14)

            SpriteView(scene: sparkleScene, options: [.allowsTransparency])
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .aspectRatio(CGFloat(cols) / CGFloat(rows), contentMode: .fit)
    }

    @ViewBuilder
    private func cellSlotView(row: Int, col: Int) -> some View {
        let coord = GridCoord(row, col)
        let pad = engine.blueprint.pads[row][col]

        if pad == .hole {
            Color.clear.aspectRatio(1, contentMode: .fit)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(primaryInk.opacity(0.06))
                    .overlay {
                        padBadgeOverlay(for: pad)
                    }

                if let die = engine.grid[row][col] {
                    let hintDir = (engine.activeHint?.from == coord) ? engine.activeHint?.direction : nil
                    DieTile3DView(
                        die: die,
                        appearance: engine.appearanceMode,
                        isSelected: engine.selectedCoord == coord,
                        hintDirection: hintDir,
                        lastTipDirection: lastTipDir
                    )
                    .gesture(
                        DragGesture(minimumDistance: 14)
                            .onEnded { value in
                                let dx = value.translation.width
                                let dy = value.translation.height
                                let dir: TumbleDirection = abs(dx) > abs(dy)
                                    ? (dx > 0 ? .east : .west)
                                    : (dy > 0 ? .south : .north)
                                performSwipe(from: coord, direction: dir)
                            }
                    )
                    .onTapGesture {
                        handleTap(on: coord)
                    }
                } else {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleTap(on: coord)
                        }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }

    @ViewBuilder
    private func padBadgeOverlay(for pad: CellPadKind) -> some View {
        switch pad {
        case .chromaMultiplier(let m):
            Text("×\(m)")
                .font(.caption2.weight(.black))
                .foregroundStyle(Color.yellow.opacity(0.75))
        case .twist180:
            Text("⟳7")
                .font(.caption2.weight(.black))
                .foregroundStyle(Color.orange.opacity(0.8))
        case .portal:
            Text("◎")
                .font(.caption.weight(.black))
                .foregroundStyle(Color.mint.opacity(0.85))
        case .hole, .normal:
            EmptyView()
        }
    }

    // MARK: - 6-Face Cube Peek Compass

    private var selectedDieCompassHUD: some View {
        Group {
            if let sel = engine.selectedCoord, let die = engine.grid[sel.row][sel.col] {
                let o = die.orientation
                HStack(spacing: 12) {
                    Text("Selected (\(sel.row + 1),\(sel.col + 1)) • Top \(o.top) / Bottom \(o.bottom)")
                        .font(.caption.weight(.bold))
                    Spacer()
                    Text("↑\(o.nextTopPip(whenTipped: .north))  →\(o.nextTopPip(whenTipped: .east))  ↓\(o.nextTopPip(whenTipped: .south))  ←\(o.nextTopPip(whenTipped: .west))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10).fill(trayBackground))
                .foregroundStyle(primaryInk)
            } else {
                Text("Tip: Swipe any die ↑ ↓ ← →, or tap a die to inspect all 6 Sum-7 faces!")
                    .font(.caption2)
                    .foregroundStyle(primaryInk.opacity(0.62))
                    .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Bottom Control Deck

    private var bottomControlDeck: some View {
        HStack(spacing: 10) {
            Button {
                engine.undoLastMove()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.bordered)
            .disabled(!engine.canUndo)

            Button {
                engine.twistArmed.toggle()
            } label: {
                Label("Twist 180° (\(engine.twistCharges))", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .tint(engine.twistArmed ? .orange : .teal)
            .disabled(engine.twistCharges == 0)

            Button {
                _ = engine.requestHint()
            } label: {
                Label("Hint", systemImage: "lightbulb")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.bordered)

            Button {
                engine.load(level: engine.currentLevel)
            } label: {
                Label("Replay", systemImage: "arrow.clockwise")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Victory Celebration Modal

    private var victoryOverlayCard: some View {
        ZStack {
            Color.black.opacity(0.58).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(String(repeating: "★ ", count: engine.earnedStars))
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.yellow)

                Text("Level #\(engine.currentLevel) Complete!")
                    .font(.title2.weight(.heavy))

                Text("Moves: \(engine.moves) (Par \(engine.blueprint.parMoves)) • Score: \(engine.score)")
                    .font(.subheadline)
                    .opacity(0.85)

                HStack(spacing: 12) {
                    Button("Replay") {
                        engine.load(level: engine.currentLevel)
                    }
                    .buttonStyle(.bordered)

                    Button("Next Level #\(min(1023, engine.currentLevel + 1)) →") {
                        engine.load(level: min(1023, engine.currentLevel + 1))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 24).fill(trayBackground))
            .foregroundStyle(primaryInk)
            .padding(24)
        }
    }

    // MARK: - Interaction Handlers

    private func handleTap(on coord: GridCoord) {
        if engine.twistArmed {
            if engine.applyTwist180(at: coord) {
                TactileAudioHaptics.shared.playCascadeMatch(chain: 1, isChromaSurge: true)
                sparkleScene.emitBurst()
            }
            return
        }

        if let prev = engine.selectedCoord {
            if prev == coord {
                engine.selectedCoord = nil
                return
            }
            let dr = coord.row - prev.row
            let dc = coord.col - prev.col
            if abs(dr) + abs(dc) == 1 {
                let dir: TumbleDirection = (dr == -1) ? .north : (dr == 1 ? .south : (dc == 1 ? .east : .west))
                performSwipe(from: prev, direction: dir)
                return
            }
        }
        if engine.grid[coord.row][coord.col] != nil {
            engine.selectedCoord = coord
        }
    }

    private func performSwipe(from coord: GridCoord, direction: TumbleDirection) {
        let prevCleared = engine.diceCleared
        lastTipDir = direction
        if engine.swipeDie(at: coord, direction: direction) {
            let delta = engine.diceCleared - prevCleared
            if engine.isWon {
                TactileAudioHaptics.shared.playStageWin()
                sparkleScene.emitBurst(count: 28)
            } else if delta > 0 {
                TactileAudioHaptics.shared.playCascadeMatch(chain: max(1, engine.currentChain), isChromaSurge: engine.lastBanner.contains("CHROMA"))
                sparkleScene.emitBurst(count: 18)
            } else {
                let topPip = engine.grid[coord.row + direction.rowDelta][coord.col + direction.colDelta]?.orientation.top ?? 4
                TactileAudioHaptics.shared.playTumble(pip: topPip)
            }
        }
    }
}
