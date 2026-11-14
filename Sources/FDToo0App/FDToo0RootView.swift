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
    @State private var rollDirByCoord: [GridCoord: TumbleDirection] = [:]
    @State private var rollTriggerSeq: Int = 0
    @State private var choreographyTask: Task<Void, Never>? = nil
    @State private var isChoreographing: Bool = false

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

            VStack(spacing: 10) {
                headerFlipperBar
                paceSpeedBar
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
                cancelChoreography()
                engine.toggleFlipper()
                TactileAudioHaptics.shared.playTumble(pip: 6, audioStretch: engine.paceSpeed.audioStretch)
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
                cancelChoreography()
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

    // MARK: - Rabbit 🐇 • TurtLe 🐢 • SnaiL 🐌 Pace Speed Bar

    private var paceSpeedBar: some View {
        HStack(spacing: 6) {
            ForEach(PaceSpeed.allCases) { speed in
                let active = engine.paceSpeed == speed
                Button {
                    engine.paceSpeed = speed
                    TactileAudioHaptics.shared.playTumble(
                        pip: speed == .rabbit ? 6 : (speed == .turtle ? 4 : 2),
                        audioStretch: speed.audioStretch
                    )
                } label: {
                    Text(speed.stylizedLabel)
                        .font(.caption.weight(active ? .heavy : .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    active
                                        ? Color(red: 0.35, green: 0.62, blue: 0.52)
                                        : primaryInk.opacity(0.06)
                                )
                        )
                        .foregroundStyle(active ? Color.white : primaryInk.opacity(0.82))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(trayBackground)
                .overlay(Capsule().strokeBorder(primaryInk.opacity(0.12), lineWidth: 1))
        )
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
                statPill(
                    label: "TIME / \(engine.paceSpeed.emoji) PAR",
                    value: "\(engine.elapsedSeconds)s/\(engine.effectiveParSeconds)s"
                )
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
                    let rollDir = rollDirByCoord[coord]
                    DieTile3DView(
                        die: die,
                        appearance: engine.appearanceMode,
                        isSelected: engine.selectedCoord == coord,
                        isMatchGlowing: engine.glowingMatchCoords.contains(coord),
                        springResponse: engine.paceSpeed.springResponse,
                        hintDirection: hintDir,
                        lastTipDirection: rollDir,
                        rollTriggerID: rollDir != nil ? rollTriggerSeq : 0
                    )
                    .gesture(
                        DragGesture(minimumDistance: 14)
                            .onEnded { value in
                                guard !isChoreographing else { return }
                                let dx = value.translation.width
                                let dy = value.translation.height
                                let dir: TumbleDirection = abs(dx) > abs(dy)
                                    ? (dx > 0 ? .east : .west)
                                    : (dy > 0 ? .south : .north)
                                performSwipe(from: coord, direction: dir)
                            }
                    )
                    .onTapGesture {
                        guard !isChoreographing else { return }
                        handleTap(on: coord)
                    }
                } else {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isChoreographing else { return }
                            handleTap(on: coord)
                        }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .zIndex(rollDirByCoord[coord] != nil ? 12 : 1)
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
                Text(engine.paceSpeed.summary)
                    .font(.caption2)
                    .foregroundStyle(primaryInk.opacity(0.66))
                    .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Bottom Control Deck

    private var bottomControlDeck: some View {
        HStack(spacing: 10) {
            Button {
                cancelChoreography()
                engine.undoLastMove()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.bordered)
            .disabled(!engine.canUndo || isChoreographing)

            Button {
                engine.twistArmed.toggle()
            } label: {
                Label("Twist 180° (\(engine.twistCharges))", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .tint(engine.twistArmed ? .orange : .teal)
            .disabled(engine.twistCharges == 0 || isChoreographing)

            Button {
                _ = engine.requestHint()
            } label: {
                Label("Hint", systemImage: "lightbulb")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.bordered)
            .disabled(isChoreographing)

            Button {
                cancelChoreography()
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

                Text("Moves: \(engine.moves) (Par \(engine.blueprint.parMoves)) • Time: \(engine.elapsedSeconds)s (\(engine.paceSpeed.emoji) Par \(engine.effectiveParSeconds)s)")
                    .font(.subheadline)
                    .opacity(0.85)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("Replay") {
                        cancelChoreography()
                        engine.load(level: engine.currentLevel)
                    }
                    .buttonStyle(.bordered)

                    Button("Next Level #\(min(1023, engine.currentLevel + 1)) →") {
                        cancelChoreography()
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

    // MARK: - Interaction & Multi-Phase Speed Choreography

    private func cancelChoreography() {
        choreographyTask?.cancel()
        choreographyTask = nil
        isChoreographing = false
        rollDirByCoord.removeAll()
        engine.glowingMatchCoords.removeAll()
    }

    private func handleTap(on coord: GridCoord) {
        if engine.twistArmed {
            let speed = engine.paceSpeed
            let didTwist = engine.beginTwist180Only(at: coord)
            if didTwist {
                rollDirByCoord = [coord: .east]
                rollTriggerSeq += 1
                let topPip = engine.grid[coord.row][coord.col]?.orientation.top ?? 6
                TactileAudioHaptics.shared.playTumble(pip: topPip, audioStretch: speed.audioStretch)
                runWaveChoreography()
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
        let speed = engine.paceSpeed
        let moved = engine.beginSwipeTumbleOnly(at: coord, direction: direction)
        guard moved else { return }

        let dest = GridCoord(coord.row + direction.rowDelta, coord.col + direction.colDelta)
        var nextRolls: [GridCoord: TumbleDirection] = [dest: direction]
        if engine.grid[coord.row][coord.col] != nil {
            nextRolls[coord] = direction.opposite
        }
        rollDirByCoord = nextRolls
        rollTriggerSeq += 1

        let landedPip = (dest.row >= 0 && dest.row < engine.blueprint.rows && dest.col >= 0 && dest.col < engine.blueprint.cols)
            ? (engine.grid[dest.row][dest.col]?.orientation.top ?? 4)
            : 4
        TactileAudioHaptics.shared.playTumble(pip: landedPip, audioStretch: speed.audioStretch)

        if engine.isWon {
            TactileAudioHaptics.shared.playStageWin(audioStretch: speed.audioStretch)
            sparkleScene.emitBurst(count: 28, durationScale: speed.sparkleScale)
            return
        }

        runWaveChoreography()
    }

    private func runWaveChoreography() {
        choreographyTask?.cancel()
        let isCascadeMode = (engine.mode == .fdToo0)
        if isCascadeMode {
            isChoreographing = true
        }

        choreographyTask = Task { @MainActor in
            defer {
                isChoreographing = false
            }

            // Phase 1: Let the 90° 3D tumble land visually at the chosen Rabbit / TurtLe / SnaiL pace
            let initialTumbleNs = UInt64(engine.paceSpeed.tumbleDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: initialTumbleNs)
            if Task.isCancelled { return }
            rollDirByCoord.removeAll()
            guard isCascadeMode else { return }

            var wave = 1
            while !engine.isWon && wave <= 20 {
                let preview = engine.previewNextMatchWave()
                if preview.isEmpty { break }

                // Phase 2: Highlight the 3+ matching top-pip run before popping
                engine.glowingMatchCoords = preview
                let glowNs = UInt64(engine.paceSpeed.glowDuration * 1_000_000_000)
                try? await Task.sleep(nanoseconds: glowNs)
                if Task.isCancelled { return }

                // Phase 3: Pop matched dice & drop fresh Pastel HSB gravity cascade
                let speed = engine.paceSpeed
                let outcome = withAnimation(.spring(response: speed.dropDuration, dampingFraction: 0.78)) {
                    engine.commitSingleCascadeWave(waveIndex: wave)
                }
                if let outcome {
                    if engine.isWon {
                        TactileAudioHaptics.shared.playStageWin(audioStretch: speed.audioStretch)
                        sparkleScene.emitBurst(count: 28, durationScale: speed.sparkleScale)
                        break
                    } else {
                        TactileAudioHaptics.shared.playCascadeMatch(
                            chain: outcome.chainIndex,
                            isChromaSurge: outcome.isChromaSurge,
                            audioStretch: speed.audioStretch
                        )
                        sparkleScene.emitBurst(
                            count: outcome.isChromaSurge ? 24 : 16,
                            durationScale: speed.sparkleScale
                        )
                    }
                }

                let dropNs = UInt64(engine.paceSpeed.dropDuration * 1_000_000_000)
                try? await Task.sleep(nanoseconds: dropNs)
                if Task.isCancelled { return }
                wave += 1
            }

            engine.finalizeTurnAfterWaves()
        }
    }
}
