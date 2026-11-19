//
//  FDToo0RootView.swift
//  FD_too0 — Joe SmoLLey 3D Spatial Deck
//
//  Unified Universal SwiftUI + SceneKit + SpriteKit Workspace:
//  1) FLipPing Dice & FD_too0 (1,023 Levels in True 3D SceneKit + Classic 2D Toggle)
//  2) AxLe-Locked & FaceCard Yahtzee Parlour (Mysterious-Axis + Conjugate 4-Number Cubes)
//  3) HoLy SmoLLey Vacuum Gravity-Trains & Abyssal OTEC Odyssey
//  4) z404 M00N Buggy (4WD Crawl <-> 2-Pip RWD Drift Lab)
//

import SwiftUI
import Combine
import SpriteKit
#if canImport(FDToo0Core)
import FDToo0Core
#endif

public struct FDToo0RootView: View {
    @State private var activeDeck: SpatialDeckTab = .flippingDice3D
    @State private var engine = GameEngine23(initialMode: .fdToo0, startLevel: 1)
    @State private var yahtzeeEngine = AxleYahtzeeEngine()
    @State private var smolleyEngine = HolySmolleyMissionEngine()
    @State private var buggyEngine = MoonBuggyArenaEngine()

    @State private var sparkleScene = CascadeSparkleScene(size: CGSize(width: 420, height: 420))
    @State private var showAtlas = false
    @State private var showRules = false
    @State private var showScoreStory = false
    @State private var rollDirByCoord: [GridCoord: TumbleDirection] = [:]
    @State private var twistCoords: Set<GridCoord> = []
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
        case .dark:   return Color(red: 0.06, green: 0.06, blue: 0.07)
        case .light:  return Color(red: 0.99, green: 0.98, blue: 0.95)
        case .spruce: return Color(red: 0.16, green: 0.11, blue: 0.08)
        }
    }

    private var primaryInk: Color {
        engine.appearanceMode == .light
            ? Color(red: 0.13, green: 0.11, blue: 0.10)
            : Color(red: 0.96, green: 0.94, blue: 0.90)
    }

    public var body: some View {
        ZStack {
            windowBackground.ignoresSafeArea()

            VStack(spacing: 8) {
                spatialDeckSwitcherBar
                globalSkinAndProjectionBar

                switch activeDeck {
                case .flippingDice3D:
                    flippingDiceDeckBody
                case .axleYahtzee:
                    AxleYahtzee3DView(yahtzee: yahtzeeEngine, globalEngine: engine)
                case .holySmolley:
                    HolySmolley3DView(smolley: smolleyEngine, globalEngine: engine)
                case .moonBuggyZ404:
                    MoonBuggy3DView(buggy: buggyEngine, globalEngine: engine)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: 660)
        }
        .preferredColorScheme(engine.appearanceMode == .light ? .light : .dark)
        .onReceive(timer) { _ in
            if activeDeck == .flippingDice3D {
                engine.tickSecond()
            }
        }
        .sheet(isPresented: $showAtlas) {
            WorldAtlasSheet(engine: engine)
        }
        .sheet(isPresented: $showRules) {
            RulesInspectorSheet()
        }
        .overlay {
            if activeDeck == .flippingDice3D && engine.isWon {
                victoryOverlayCard
            }
        }
    }

    // MARK: - Joe SmoLLey 4-Deck Switcher Bar

    private var spatialDeckSwitcherBar: some View {
        HStack(spacing: 5) {
            ForEach(SpatialDeckTab.allCases) { tab in
                let selected = (activeDeck == tab)
                Button {
                    cancelChoreography()
                    activeDeck = tab
                    TactileAudioHaptics.shared.playTumble(pip: 5)
                } label: {
                    HStack(spacing: 3) {
                        Text(tab.iconGlyph)
                            .font(.caption2)
                        Text(tab.shortTitle)
                            .font(.system(size: 11, weight: selected ? .black : .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(selected ? Color(red: 0.89, green: 0.62, blue: 0.22) : trayBackground)
                    )
                    .foregroundStyle(selected ? Color.black : primaryInk.opacity(0.86))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Global 3D Skin (`RH000 Pips` | `45° Twisted` | `FaceCards`) & Camera Projection Bar

    private var globalSkinAndProjectionBar: some View {
        HStack(spacing: 6) {
            Button {
                let skins = DieVisualSkin.allCases
                let idx = skins.firstIndex(of: engine.visualSkin) ?? 0
                engine.visualSkin = skins[(idx + 1) % skins.count]
                TactileAudioHaptics.shared.playTumble(pip: 4)
            } label: {
                Text("\(engine.visualSkin.badgeGlyph) \(engine.visualSkin.shortLabel)")
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(trayBackground))
                    .overlay(Capsule().strokeBorder(primaryInk.opacity(0.22), lineWidth: 1))
                    .foregroundStyle(primaryInk)
            }
            .buttonStyle(.plain)

            Button {
                let styles = CameraProjectionStyle.allCases
                let idx = styles.firstIndex(of: engine.cameraProjection) ?? 0
                engine.cameraProjection = styles[(idx + 1) % styles.count]
                TactileAudioHaptics.shared.playTumble(pip: 3)
            } label: {
                let isTrainer = (engine.cameraProjection == .flat2D)
                Text("\(isTrainer ? "🎓" : "🎥") \(engine.cameraProjection.shortLabel)")
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(
                            isTrainer
                                ? Color(red: 0.24, green: 0.56, blue: 0.45).opacity(0.32)
                                : trayBackground
                        )
                    )
                    .overlay(Capsule().strokeBorder(primaryInk.opacity(0.24), lineWidth: 1))
                    .foregroundStyle(primaryInk)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 2)

            Button {
                let modes = BoardAppearanceMode.allCases
                let idx = modes.firstIndex(of: engine.appearanceMode) ?? 0
                engine.appearanceMode = modes[(idx + 1) % modes.count]
            } label: {
                Text(engine.appearanceMode.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().strokeBorder(primaryInk.opacity(0.24), lineWidth: 1))
                    .foregroundStyle(primaryInk)
            }
            .buttonStyle(.plain)

            Button {
                showRules = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(primaryInk)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Deck 1: FLipPing Dice & FD_too0 (1,023 Levels in True 3D SceneKit + Classic 2D)

    private var flippingDiceDeckBody: some View {
        VStack(spacing: 8) {
            headerFlipperBar
            paceSpeedBar
            scoreSlatStrip
            boardTrayView
            selectedDieCompassHUD
            bottomControlDeck
        }
    }

    private var headerFlipperBar: some View {
        HStack(spacing: 8) {
            Button {
                cancelChoreography()
                engine.toggleFlipper()
                TactileAudioHaptics.shared.playTumble(pip: 6, audioStretch: engine.paceSpeed.audioStretch)
            } label: {
                HStack(spacing: 5) {
                    Text("⇄")
                        .font(.subheadline.bold())
                    Text(engine.mode.shortBadge)
                        .font(.caption.weight(.heavy))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
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
                HStack(spacing: 6) {
                    Text("Lv \(engine.currentLevel)/1023\(engine.blueprint.isBossLevel ? " • BOSS" : "") ▾")
                        .font(.footnote.weight(.bold).monospacedDigit())
                    Text("• \(engine.blueprint.world.name)")
                        .font(.caption2)
                        .opacity(0.75)
                        .lineLimit(1)
                }
                .foregroundStyle(primaryInk)
            }
            .buttonStyle(.plain)

            Spacer()
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
                        .padding(.vertical, 5)
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
        .padding(3)
        .background(
            Capsule()
                .fill(trayBackground)
                .overlay(Capsule().strokeBorder(primaryInk.opacity(0.12), lineWidth: 1))
        )
    }

    // MARK: - ScoreSlat Telemetry Strip

    private var scoreSlatStrip: some View {
        VStack(spacing: 5) {
            HStack(spacing: 10) {
                statPill(
                    label: engine.mode == .fdToo0 ? "CLEARED" : "TARGET PIP",
                    value: engine.mode == .fdToo0
                        ? "\(engine.diceCleared)/\(engine.blueprint.targetDiceCleared)"
                        : LearnedGeometryOracle.label(forPip: engine.blueprint.targetHarmonyPip ?? 6, skin: engine.visualSkin)
                )
                statPill(label: "MOVES / PAR", value: "\(engine.moves)/\(engine.blueprint.parMoves)")
                statPill(
                    label: "TIME / \(engine.paceSpeed.emoji) PAR",
                    value: "\(engine.elapsedSeconds)s/\(engine.effectiveParSeconds)s"
                )
                Button {
                    showScoreStory.toggle()
                } label: {
                    statPill(
                        label: engine.score % 2 == 1 ? "SCORE • ODD✦" : "SCORE ▾",
                        value: "\(engine.score)"
                    )
                }
                .buttonStyle(.plain)
            }

            if showScoreStory && engine.mode == .fdToo0 {
                Text(GameEngine23.decodeScoreStory(engine.score, tally: engine.matchTally).summaryLine)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(primaryInk.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Text(engine.lastBanner)
                .font(.caption2.weight(.medium))
                .foregroundStyle(primaryInk.opacity(0.84))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .opacity(0.65)
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(trayBackground)
        )
        .foregroundStyle(primaryInk)
    }

    // MARK: - True 3D SceneKit Board OR Classic 2D Board + SpriteKit Sparkles

    private var boardTrayView: some View {
        let rows = engine.blueprint.rows
        let cols = engine.blueprint.cols

        return ZStack {
            if engine.cameraProjection != .flat2D {
                BoardScene3DView(
                    engine: engine,
                    isInteractionLocked: isChoreographing,
                    onSwipeCell: { coord, dir in
                        performSwipe(from: coord, direction: dir)
                    },
                    onTapCell: { coord in
                        handleTap(on: coord)
                    }
                )
            } else {
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
            }

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
                    let isTwisting = twistCoords.contains(coord)
                    DieTile3DView(
                        die: die,
                        appearance: engine.appearanceMode,
                        skin: engine.visualSkin,
                        isSelected: engine.selectedCoord == coord,
                        isMatchGlowing: engine.glowingMatchCoords.contains(coord),
                        springResponse: engine.paceSpeed.springResponse,
                        hintDirection: hintDir,
                        lastTipDirection: rollDir,
                        isInPlaceTwist: isTwisting,
                        rollTriggerID: (rollDir != nil || isTwisting) ? rollTriggerSeq : 0
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
            .zIndex((rollDirByCoord[coord] != nil || twistCoords.contains(coord)) ? 12 : 1)
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

    // MARK: - 6-Face Learned-Player Cube Peek & Interactive Dice Trainer Compass

    private var selectedDieCompassHUD: some View {
        Group {
            if let sel = engine.selectedCoord, let die = engine.grid[sel.row][sel.col] {
                let o = die.orientation
                let sig = LearnedGeometryOracle.signature(for: o)
                let topToken = engine.visualSkin == .royalFaceCards ? sig.faceCardBadge : sig.displayBadge
                HStack(spacing: 6) {
                    Text("(\(sel.row + 1),\(sel.col + 1)) Top \(topToken) • Bot \(o.bottom) • TF \(o.tfCode)")
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 4)

                    ForEach([TumbleDirection.north, .south, .west, .east], id: \.self) { dir in
                        Button {
                            guard !isChoreographing else { return }
                            performSwipe(from: sel, direction: dir)
                        } label: {
                            Text("\(dir.arrowGlyph)\(o.nextTopPip(whenTipped: dir))")
                                .font(.system(size: 11, weight: .heavy, design: .rounded).monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(primaryInk.opacity(0.10)))
                        }
                        .buttonStyle(.plain)
                        .disabled(isChoreographing)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 10).fill(trayBackground))
                .foregroundStyle(primaryInk)
            } else {
                Text("\(engine.visualSkin.shortLabel) • \(engine.cameraProjection.shortLabel) • \(engine.paceSpeed.summary)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(primaryInk.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    // MARK: - Bottom Control Deck

    private var bottomControlDeck: some View {
        HStack(spacing: 8) {
            Button {
                cancelChoreography()
                engine.undoLastMove()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.bordered)
            .disabled(!engine.canUndo || isChoreographing)

            Button {
                handleTwistButtonPressed()
            } label: {
                let hasSel = (engine.selectedCoord != nil)
                let title: String = {
                    if engine.twistArmed {
                        return "⚡ Tap Die (\(engine.twistCharges))"
                    } else if hasSel {
                        return "Twist 180° Now (\(engine.twistCharges))"
                    } else {
                        return "Twist 180° (\(engine.twistCharges))"
                    }
                }()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.heavy))
                    Text(title)
                        .font(.caption.weight(.heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        engine.twistCharges == 0
                            ? Color.gray.opacity(0.32)
                            : (engine.twistArmed
                                ? Color.orange
                                : (hasSel ? Color(red: 0.90, green: 0.56, blue: 0.16) : Color.teal))
                    )
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(engine.twistCharges == 0 || isChoreographing)

            Button {
                _ = engine.requestHint()
            } label: {
                Label("Hint", systemImage: "lightbulb")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.bordered)
            .disabled(isChoreographing)

            Button {
                cancelChoreography()
                engine.load(level: engine.currentLevel)
            } label: {
                Label("Replay", systemImage: "arrow.clockwise")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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

                Text("Moves: \(engine.moves) (Par \(engine.blueprint.parMoves)) • Time: \(engine.elapsedSeconds)s (\(engine.paceSpeed.emoji) Par \(engine.effectiveParSeconds)s) • Score: \(engine.score)")
                    .font(.subheadline)
                    .opacity(0.85)
                    .multilineTextAlignment(.center)

                if engine.mode == .fdToo0 {
                    Text(GameEngine23.decodeScoreStory(engine.score, tally: engine.matchTally).summaryLine)
                        .font(.caption.weight(.semibold))
                        .opacity(0.92)
                        .multilineTextAlignment(.center)
                }

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
        twistCoords.removeAll()
        engine.glowingMatchCoords.removeAll()
    }

    private func handleTwistButtonPressed() {
        guard !isChoreographing, engine.twistCharges > 0 else { return }

        // If a die is already selected on the board, immediately flip it 180° (Top <-> Bottom, Sum-7)!
        if let sel = engine.selectedCoord,
           sel.row >= 0, sel.row < engine.blueprint.rows,
           sel.col >= 0, sel.col < engine.blueprint.cols,
           engine.grid[sel.row][sel.col] != nil {
            executeTwist180(at: sel, keepSelected: true)
            return
        }

        // Otherwise arm/disarm 180° Twist with unmistakable visual + audio + banner feedback
        engine.twistArmed.toggle()
        if engine.twistArmed {
            engine.setBanner("⚡ 180° Twist Armed! Tap any die on the board to flip Top ↔ Bottom (Sum-7).")
        } else {
            engine.setBanner("Twist disarmed • Tap or swipe any die ↑ ↓ ← → (Opposite faces = 7).")
        }
        TactileAudioHaptics.shared.playTumble(
            pip: engine.twistArmed ? 6 : 3,
            audioStretch: engine.paceSpeed.audioStretch
        )
    }

    private func executeTwist180(at coord: GridCoord, keepSelected: Bool) {
        let speed = engine.paceSpeed
        guard engine.beginTwist180Only(at: coord) else { return }

        rollDirByCoord.removeAll()
        twistCoords = [coord]
        rollTriggerSeq += 1
        if keepSelected && engine.grid[coord.row][coord.col] != nil {
            engine.selectedCoord = coord
        }

        let topPip = engine.grid[coord.row][coord.col]?.orientation.top ?? 6
        TactileAudioHaptics.shared.playTumble(pip: topPip, audioStretch: speed.audioStretch)

        if engine.isWon {
            TactileAudioHaptics.shared.playStageWin(audioStretch: speed.audioStretch)
            sparkleScene.emitBurst(count: 28, durationScale: speed.sparkleScale)
            return
        }

        runWaveChoreography()
    }

    private func handleTap(on coord: GridCoord) {
        guard coord.row >= 0, coord.row < engine.blueprint.rows,
              coord.col >= 0, coord.col < engine.blueprint.cols else { return }

        if engine.twistArmed {
            if engine.grid[coord.row][coord.col] != nil {
                executeTwist180(at: coord, keepSelected: true)
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

        twistCoords.removeAll()
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

            let initialTumbleNs = UInt64(engine.paceSpeed.tumbleDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: initialTumbleNs)
            if Task.isCancelled { return }
            rollDirByCoord.removeAll()
            twistCoords.removeAll()
            guard isCascadeMode else { return }

            var wave = 1
            while !engine.isWon && wave <= 20 {
                let preview = engine.previewNextMatchWave()
                if preview.isEmpty { break }

                engine.glowingMatchCoords = preview
                let glowNs = UInt64(engine.paceSpeed.glowDuration * 1_000_000_000)
                try? await Task.sleep(nanoseconds: glowNs)
                if Task.isCancelled { return }

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
