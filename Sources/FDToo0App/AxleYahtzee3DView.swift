//
//  AxleYahtzee3DView.swift
//  FD_too0 (Joe SmoLLey 3D Spatial Deck)
//
//  3D SceneKit Parlour Table for ReguLar 1–6 & Full-3D AxLe Yahtzee:
//  - Modes: 🎲 ReguLar 1–6 (Classic 13-Category Yahtzee) | ⚡ AxLe 3D | ◇ 4-Num Pair
//  - Beyond Axles: 90° Edge Tumbles (↑↓←→), 120° Corner-Vertex Spin (◇ East→Top→South),
//    180° Sum-7 Twist (⟳ Top↔Bottom), Free 90° Felt Yaw (↻), plus Optional Skewers!
//  - Live Smart Coach Prompts, 5-Step Interactive Tutorial, Guide Sheet & Bot Opponents (🐢 & 🤖)!
//

import SwiftUI
import Combine
import SceneKit
import QuartzCore
import simd
#if canImport(FDToo0Core)
import FDToo0Core
#endif
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
public final class Yahtzee3DSceneCoordinator: ObservableObject {
    private struct SlotRecord {
        let node: SCNNode
        var axleLock: AxleLockAxis
        var archetype: ConjugateCubeArchetype?
        var pastelHue: PastelHueFamily
        var lastOrientation: DieOrientation
    }

    public let scene = SCNScene()
    public let cameraNode = SCNNode()
    private let trayNode = SCNNode()
    private let feltNode = SCNNode()
    private var slotRecords: [Int: SlotRecord] = [:]
    private var lastSkin: DieVisualSkin? = nil
    private var lastAppearance: BoardAppearanceMode? = nil
    private var lastRollTick: Int = 0
    private var hasInitialSync: Bool = false

    public init() {
        scene.background.contents = SceneKitDieBuilder.makeColor(0.07, 0.10, 0.16)

        let key = SCNNode()
        let kl = SCNLight()
        kl.type = .directional
        kl.intensity = 1120
        kl.castsShadow = true
        key.light = kl
        key.simdEulerAngles = SIMD3<Float>(-.pi / 2.85, .pi / 6.2, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        let fl = SCNLight()
        fl.type = .omni
        fl.intensity = 420
        fill.light = fl
        fill.simdPosition = SIMD3<Float>(-5, 7, 6)
        scene.rootNode.addChildNode(fill)

        let amb = SCNNode()
        let al = SCNLight()
        al.type = .ambient
        al.intensity = 410
        amb.light = al
        scene.rootNode.addChildNode(amb)

        // Parlour Felt Base
        let feltBox = SCNBox(width: 11.4, height: 0.18, length: 3.4, chamferRadius: 0.08)
        let feltMat = SCNMaterial()
        feltMat.lightingModel = .physicallyBased
        feltMat.diffuse.contents = SceneKitDieBuilder.makeColor(0.10, 0.24, 0.20)
        feltMat.roughness.contents = 0.78
        feltBox.materials = [feltMat]
        feltNode.geometry = feltBox
        feltNode.name = "parlour_felt"
        feltNode.simdPosition = SIMD3<Float>(0, -0.84, 0)
        scene.rootNode.addChildNode(feltNode)

        let cam = SCNCamera()
        cam.usesOrthographicProjection = true
        cam.orthographicScale = 2.65
        cam.zNear = 0.5
        cam.zFar = 80.0
        cameraNode.camera = cam
        // Upright parlour angle: keeps all 5 dice aligned straight across their 5 cards below
        // while revealing Top (+Y), South (+Z), and East (+X) faces!
        cameraNode.simdPosition = SIMD3<Float>(0.55, 7.5, 5.4)
        cameraNode.simdLook(at: SIMD3<Float>(0, 0.05, 0))
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(trayNode)
    }

    public static func hitTestDieIndex(in scnView: SCNView, at point: CGPoint) -> Int? {
        let options: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .ignoreHiddenNodes: true
        ]
        let hits = scnView.hitTest(point, options: options)
        for hit in hits {
            var cur: SCNNode? = hit.node
            while let n = cur {
                if let name = n.name, name.hasPrefix("yahtzee_die_"),
                   let idx = Int(name.dropFirst("yahtzee_die_".count)) {
                    return idx
                }
                cur = n.parent
            }
        }
        return nil
    }

    public func sync(
        dice: [YahtzeeDieSlot],
        mode: AxleYahtzeeProbabilityMode,
        skin: DieVisualSkin,
        appearance: BoardAppearanceMode,
        projection: CameraProjectionStyle,
        selectedDieIndex: Int,
        rollTick: Int
    ) {
        switch appearance {
        case .dark:
            scene.background.contents = SceneKitDieBuilder.makeColor(0.07, 0.10, 0.16)
        case .light:
            scene.background.contents = SceneKitDieBuilder.makeColor(0.93, 0.91, 0.87)
        case .spruce:
            scene.background.contents = SceneKitDieBuilder.makeColor(0.18, 0.13, 0.09)
        }

        if let cam = cameraNode.camera {
            cam.usesOrthographicProjection = (projection != .perspective3D)
            cam.orthographicScale = 2.65
            cam.fieldOfView = 35.0
        }

        var forceImmediate = !hasInitialSync
        if lastSkin != skin || lastAppearance != appearance {
            for (_, rec) in slotRecords { rec.node.removeFromParentNode() }
            slotRecords.removeAll()
            lastSkin = skin
            lastAppearance = appearance
            forceImmediate = true
        }

        let isCupRoll = (rollTick != lastRollTick) && hasInitialSync
        lastRollTick = rollTick

        let spacing: Float = 2.08
        let startX = -Float(max(0, dice.count - 1)) * 0.5 * spacing

        for (idx, slot) in dice.enumerated() {
            let arch: ConjugateCubeArchetype? = (mode == .conjugateDuplicate4Faces) ? slot.archetype : nil
            let effectiveAxle: AxleLockAxis = (mode == .mysteriousAxis) ? slot.axleLock : .free24
            let isSel = (idx == selectedDieIndex)
            let basePos = SIMD3<Float>(
                startX + Float(idx) * spacing,
                slot.isHeld ? 0.34 : (isSel ? 0.14 : 0.0),
                0
            )
            let targetQuat = SceneKitDieBuilder.simdQuat(from: slot.orientation.unitQuaternion)

            let needsRebuild: Bool = {
                guard let rec = slotRecords[idx] else { return true }
                return rec.axleLock != effectiveAxle || rec.archetype != arch || rec.pastelHue != slot.pastelHue
            }()

            if needsRebuild {
                let prevQuat = slotRecords[idx]?.node.simdOrientation ?? targetQuat
                let prevPos = slotRecords[idx]?.node.simdPosition ?? basePos
                slotRecords[idx]?.node.removeFromParentNode()

                let fresh = SceneKitDieBuilder.makeDieNode(
                    pastelHue: slot.pastelHue,
                    appearance: appearance,
                    skin: skin,
                    axleLock: effectiveAxle,
                    conjugateArchetype: arch,
                    isSelected: isSel,
                    isMatchGlowing: slot.isHeld
                )
                fresh.name = "yahtzee_die_\(idx)"
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0
                fresh.simdPosition = forceImmediate ? basePos : prevPos
                fresh.simdOrientation = forceImmediate ? targetQuat : prevQuat
                trayNode.addChildNode(fresh)
                SCNTransaction.commit()

                if !forceImmediate {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.26
                    SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    fresh.simdPosition = basePos
                    fresh.simdOrientation = targetQuat
                    SCNTransaction.commit()
                }

                slotRecords[idx] = SlotRecord(
                    node: fresh,
                    axleLock: effectiveAxle,
                    archetype: arch,
                    pastelHue: slot.pastelHue,
                    lastOrientation: slot.orientation
                )
            } else if var rec = slotRecords[idx] {
                rec.node.name = "yahtzee_die_\(idx)"
                SceneKitDieBuilder.updateDieHighlight(
                    node: rec.node,
                    isSelected: isSel,
                    isMatchGlowing: slot.isHeld
                )
                let prevOri = rec.lastOrientation
                rec.lastOrientation = slot.orientation
                slotRecords[idx] = rec

                if isCupRoll && !slot.isHeld {
                    // Lively 2-stage 3D Cup Shake & Tumble!
                    let spinMid = slot.orientation.spunCorner120().tipped(.north)
                    let midQuat = SceneKitDieBuilder.simdQuat(from: spinMid.unitQuaternion)
                    let hopY: Float = 1.05 + Float(idx % 2) * 0.18
                    let capturedIdx = idx
                    let capturedBase = basePos

                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.17
                    SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
                    rec.node.simdPosition = SIMD3<Float>(basePos.x, hopY, -0.25)
                    rec.node.simdOrientation = midQuat
                    SCNTransaction.commit()

                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 170_000_000)
                        guard let self, let latest = self.slotRecords[capturedIdx] else { return }
                        let finalQ = SceneKitDieBuilder.simdQuat(from: latest.lastOrientation.unitQuaternion)
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = 0.23
                        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        latest.node.simdPosition = capturedBase
                        latest.node.simdOrientation = finalQ
                        SCNTransaction.commit()
                    }
                } else if prevOri != slot.orientation && slot.orientation == prevOri.twisted180() && !forceImmediate {
                    // 2-stage 180° Sum-7 Twist somersault!
                    let midQuat = SceneKitDieBuilder.simdQuat(from: prevOri.tipped(.east).unitQuaternion)
                    let capturedIdx = idx
                    let capturedBase = basePos

                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.16
                    SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
                    rec.node.simdPosition = SIMD3<Float>(basePos.x, 0.96, 0)
                    rec.node.simdOrientation = midQuat
                    SCNTransaction.commit()

                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 160_000_000)
                        guard let self, let latest = self.slotRecords[capturedIdx] else { return }
                        let finalQ = SceneKitDieBuilder.simdQuat(from: latest.lastOrientation.unitQuaternion)
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = 0.18
                        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        latest.node.simdPosition = capturedBase
                        latest.node.simdOrientation = finalQ
                        SCNTransaction.commit()
                    }
                } else {
                    // Smooth 90° Edge Tumble, ◇120° Corner Spin, ↻90° Yaw, or Hold Lift!
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = forceImmediate ? 0.0 : 0.28
                    SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    rec.node.simdPosition = basePos
                    rec.node.simdOrientation = targetQuat
                    SCNTransaction.commit()
                }
            }
        }

        hasInitialSync = true
    }
}

// MARK: - Platform-Native Tap-Raycasting SCNView for Yahtzee Parlour

#if os(macOS)
private final class YahtzeeHitSCNView: SCNView {
    var onTapDieOrFelt: ((Int?) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func mouseUp(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let idx = Yahtzee3DSceneCoordinator.hitTestDieIndex(in: self, at: pt)
        onTapDieOrFelt?(idx)
    }
}

private struct YahtzeeInteractiveSCNView: NSViewRepresentable {
    let coordinator: Yahtzee3DSceneCoordinator
    let onTapDieOrFelt: (Int?) -> Void

    func makeNSView(context: Context) -> YahtzeeHitSCNView {
        let v = YahtzeeHitSCNView()
        v.scene = coordinator.scene
        v.pointOfView = coordinator.cameraNode
        v.rendersContinuously = true
        v.antialiasingMode = .multisampling4X
        v.allowsCameraControl = false
        v.onTapDieOrFelt = onTapDieOrFelt
        return v
    }

    func updateNSView(_ nsView: YahtzeeHitSCNView, context: Context) {
        nsView.onTapDieOrFelt = onTapDieOrFelt
    }
}
#elseif canImport(UIKit)
@MainActor
private final class YahtzeeTapBridge: NSObject {
    var onTapDieOrFelt: ((Int?) -> Void)?
    weak var scnView: SCNView?

    @objc func handleTap(_ gr: UITapGestureRecognizer) {
        guard gr.state == .ended, let view = scnView else { return }
        let pt = gr.location(in: view)
        let idx = Yahtzee3DSceneCoordinator.hitTestDieIndex(in: view, at: pt)
        onTapDieOrFelt?(idx)
    }
}

private struct YahtzeeInteractiveSCNView: UIViewRepresentable {
    let coordinator: Yahtzee3DSceneCoordinator
    let onTapDieOrFelt: (Int?) -> Void

    func makeCoordinator() -> YahtzeeTapBridge { YahtzeeTapBridge() }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = coordinator.scene
        v.pointOfView = coordinator.cameraNode
        v.rendersContinuously = true
        v.antialiasingMode = .multisampling4X
        v.allowsCameraControl = false
        context.coordinator.scnView = v
        context.coordinator.onTapDieOrFelt = onTapDieOrFelt
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(YahtzeeTapBridge.handleTap(_:)))
        v.addGestureRecognizer(tap)
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.scnView = uiView
        context.coordinator.onTapDieOrFelt = onTapDieOrFelt
    }
}
#endif

// MARK: - Main Parlour View

public struct AxleYahtzee3DView: View {
    @Bindable public var yahtzee: AxleYahtzeeEngine
    public var globalEngine: GameEngine23

    @StateObject private var sceneCoord = Yahtzee3DSceneCoordinator()
    @State private var selectedDieIndex: Int = 0
    @State private var rollSpinTick: Int = 0
    @State private var showGuideSheet: Bool = false

    public init(yahtzee: AxleYahtzeeEngine, globalEngine: GameEngine23) {
        self.yahtzee = yahtzee
        self.globalEngine = globalEngine
    }

    private var primaryInk: Color {
        globalEngine.appearanceMode == .light
            ? Color(red: 0.13, green: 0.11, blue: 0.10)
            : Color(red: 0.96, green: 0.94, blue: 0.90)
    }

    private var cardSurface: Color {
        globalEngine.appearanceMode == .light
            ? Color(red: 0.94, green: 0.92, blue: 0.88)
            : Color(red: 0.11, green: 0.13, blue: 0.18)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                modeAndTutorialBar
                opponentAndScoreboardBar
                if yahtzee.isTutorialActive {
                    interactiveTutorialCard
                }
                coachPromptBanner
                scene3DTrayCard
                dieHoldAndAxleStrip
                rollAnd3DStudioControls
                if !yahtzee.botTurnFeed.isEmpty {
                    botPlayByPlayStrip
                }
                scorecardTable
            }
            .padding(.bottom, 14)
        }
        .sheet(isPresented: $showGuideSheet) {
            YahtzeeGuideSheet(yahtzee: yahtzee)
        }
        .onAppear { refreshScene() }
        .onChange(of: yahtzee.dice) { _, _ in refreshScene() }
        .onChange(of: yahtzee.probabilityMode) { _, _ in refreshScene() }
        .onChange(of: globalEngine.visualSkin) { _, _ in refreshScene() }
        .onChange(of: globalEngine.cameraProjection) { _, _ in refreshScene() }
        .onChange(of: globalEngine.appearanceMode) { _, _ in refreshScene() }
        .onChange(of: selectedDieIndex) { _, _ in refreshScene() }
        .onChange(of: rollSpinTick) { _, _ in refreshScene() }
    }

    private func refreshScene() {
        sceneCoord.sync(
            dice: yahtzee.dice,
            mode: yahtzee.probabilityMode,
            skin: globalEngine.visualSkin,
            appearance: globalEngine.appearanceMode,
            projection: globalEngine.cameraProjection,
            selectedDieIndex: selectedDieIndex,
            rollTick: rollSpinTick
        )
    }

    // MARK: - 1. Ruleset Mode (`ReguLar 1–6` | `AxLe 3D` | `4-Num`) + Tutorial & Guide Bar

    private var modeAndTutorialBar: some View {
        HStack(spacing: 5) {
            ForEach(AxleYahtzeeProbabilityMode.allCases) { m in
                let active = (yahtzee.probabilityMode == m)
                Button {
                    yahtzee.probabilityMode = m
                    TactileAudioHaptics.shared.playTumble(pip: 5)
                } label: {
                    Text(m.shortTabTitle)
                        .font(.system(size: 11, weight: active ? .black : .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                active
                                    ? Color(red: 0.25, green: 0.58, blue: 0.48)
                                    : cardSurface
                            )
                        )
                        .foregroundStyle(active ? Color.white : primaryInk.opacity(0.86))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 2)

            Button {
                if yahtzee.isTutorialActive {
                    yahtzee.isTutorialActive = false
                } else {
                    yahtzee.startTutorial()
                }
                TactileAudioHaptics.shared.playTumble(pip: 6)
            } label: {
                Text(yahtzee.isTutorialActive ? "🎓 Hide" : "🎓 Tutorial")
                    .font(.system(size: 11, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            yahtzee.isTutorialActive
                                ? Color.orange
                                : Color(red: 0.88, green: 0.56, blue: 0.18).opacity(0.24)
                        )
                    )
                    .foregroundStyle(yahtzee.isTutorialActive ? Color.black : primaryInk)
            }
            .buttonStyle(.plain)

            Button {
                showGuideSheet = true
            } label: {
                Text("📖 Guide")
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Capsule().strokeBorder(primaryInk.opacity(0.24), lineWidth: 1))
                    .foregroundStyle(primaryInk)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 2. Opponent Roster (`Solo` | `vs 🐢 TurtLe` | `vs 🤖 SmoLLey` | `🏆 Trio`)

    private var opponentAndScoreboardBar: some View {
        HStack(spacing: 5) {
            ForEach(YahtzeeOpponentMode.allCases) { opp in
                let active = (yahtzee.opponentMode == opp)
                Button {
                    yahtzee.opponentMode = opp
                    TactileAudioHaptics.shared.playTumble(pip: 4)
                } label: {
                    Text(opp.pillLabel)
                        .font(.system(size: 10, weight: active ? .heavy : .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(
                                active
                                    ? Color(red: 0.30, green: 0.44, blue: 0.78)
                                    : cardSurface
                            )
                        )
                        .foregroundStyle(active ? Color.white : primaryInk.opacity(0.84))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 2)

            if yahtzee.probabilityMode == .mysteriousAxis {
                Button {
                    yahtzee.jackPowersEnabled.toggle()
                } label: {
                    Text(yahtzee.jackPowersEnabled ? "🃏 Jacks ON" : "🃏 Jacks OFF")
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(
                                yahtzee.jackPowersEnabled
                                    ? Color.purple.opacity(0.45)
                                    : cardSurface
                            )
                        )
                        .overlay(Capsule().strokeBorder(primaryInk.opacity(0.20), lineWidth: 1))
                        .foregroundStyle(primaryInk)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 3. Interactive 5-Step Walkthrough Card

    private var interactiveTutorialCard: some View {
        let step = yahtzee.tutorialStep
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(step.stepBadge.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange))
                    .foregroundStyle(.black)

                Text(step.headline)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(primaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Button {
                    yahtzee.isTutorialActive = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(primaryInk.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            Text(step.bodyText)
                .font(.caption2)
                .foregroundStyle(primaryInk.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("← Prev") {
                    yahtzee.previousTutorialStep()
                }
                .font(.caption2.bold())
                .buttonStyle(.bordered)
                .disabled(step == .welcomeModes)

                if step == .rollAndHold && yahtzee.rollsRemaining == 3 {
                    Button("🎲 Roll Cup Now") {
                        triggerCupRoll()
                    }
                    .font(.caption2.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else if step == .beyondAxles3D {
                    Button("◇ Try 120° Corner Spin") {
                        if yahtzee.probabilityMode != .mysteriousAxis {
                            yahtzee.probabilityMode = .mysteriousAxis
                        }
                        if yahtzee.rollsRemaining == 3 {
                            triggerCupRoll()
                        }
                        if yahtzee.spinDieCorner120(dieIndex: selectedDieIndex) {
                            TactileAudioHaptics.shared.playTumble(pip: 6)
                        }
                    }
                    .font(.caption2.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                }

                Spacer()

                Button(step == .scoreAndBots ? "Finish ✓" : "Next Lesson →") {
                    yahtzee.nextTutorialStep()
                }
                .font(.caption2.bold())
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.85), lineWidth: 1.8)
                )
        )
    }

    // MARK: - 4. Live Smart Coach Prompt Strip

    private var coachPromptBanner: some View {
        VStack(spacing: 3) {
            Text(yahtzee.coachPrompt)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(primaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(yahtzee.statusBanner)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(primaryInk.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.20, green: 0.45, blue: 0.42).opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.teal.opacity(0.45), lineWidth: 1)
                )
        )
    }

    // MARK: - 5. 3D SceneKit Parlour Tray (Tap any 3D cube to Focus / HOLD ★!)

    private var scene3DTrayCard: some View {
        ZStack(alignment: .top) {
            YahtzeeInteractiveSCNView(coordinator: sceneCoord) { hitIdx in
                if let idx = hitIdx {
                    selectedDieIndex = idx
                    if yahtzee.rollsRemaining == 3 {
                        triggerCupRoll()
                    } else {
                        yahtzee.toggleHold(dieIndex: idx)
                        TactileAudioHaptics.shared.playTumble(pip: 4)
                    }
                } else if yahtzee.rollsRemaining == 3 {
                    triggerCupRoll()
                }
            }
            .frame(height: 162)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack {
                Text("Upper: \(yahtzee.upperSubtotal)/\(yahtzee.upperBonusThreshold)\(yahtzee.upperBonus > 0 ? " (+35✓)" : "")")
                    .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())

                Spacer()

                HStack(spacing: 8) {
                    Text("You: \(yahtzee.totalScore)")
                        .font(.system(size: 11, weight: .black, design: .rounded).monospacedDigit())
                    ForEach(yahtzee.bots) { bot in
                        Text("\(bot.emoji) \(bot.totalScore(for: yahtzee.probabilityMode))")
                            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(8)
        }
    }

    // MARK: - 6. 5-Die Hold & Axle Status Cards

    private var dieHoldAndAxleStrip: some View {
        HStack(spacing: 6) {
            ForEach(Array(yahtzee.dice.enumerated()), id: \.element.id) { idx, slot in
                let val = slot.effectiveValue(in: yahtzee.probabilityMode)
                let sig = LearnedGeometryOracle.signature(for: slot.orientation)
                let badge: String = {
                    if globalEngine.visualSkin == .royalFaceCards && yahtzee.probabilityMode != .conjugateDuplicate4Faces {
                        return sig.faceCardBadge
                    } else if globalEngine.visualSkin == .twisted45Numerals {
                        return "\(val)\(sig.cornerQuadrant.arrowGlyph)"
                    } else {
                        return "Pip \(val)"
                    }
                }()
                let subtitle: String = {
                    switch yahtzee.probabilityMode {
                    case .regularStandard:
                        return "Bot \(7 - slot.orientation.top)"
                    case .mysteriousAxis:
                        return slot.axleLock.shortTag
                    case .conjugateDuplicate4Faces:
                        return slot.archetype == .alpha12Doubled ? "Cube α" : "Cube β"
                    }
                }()

                Button {
                    selectedDieIndex = idx
                    if yahtzee.rollsRemaining < 3 {
                        yahtzee.toggleHold(dieIndex: idx)
                        TactileAudioHaptics.shared.playTumble(pip: val)
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(badge)
                            .font(.system(size: 12, weight: .black, design: .rounded).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(subtitle)
                            .font(.system(size: 9, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .opacity(0.76)
                        Text(slot.isHeld ? "HELD ★" : (selectedDieIndex == idx ? "● FOCUS" : (yahtzee.rollsRemaining == 3 ? "READY" : "TAP HOLD")))
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(slot.isHeld ? Color.yellow : (selectedDieIndex == idx ? Color.cyan : primaryInk.opacity(0.62)))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        slot.isHeld ? Color.yellow : (selectedDieIndex == idx ? Color.cyan : primaryInk.opacity(0.15)),
                                        lineWidth: slot.isHeld || selectedDieIndex == idx ? 2 : 1
                                    )
                            )
                    )
                    .foregroundStyle(primaryInk)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 7. Roll Cup + Full-3D Rotation Studio (90° Edge + ◇120° Corner + ⟳180° Twist + ↻Yaw + Pin AxLe)

    private var rollAnd3DStudioControls: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    triggerCupRoll()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "dice.fill")
                        Text(yahtzee.isGameComplete ? "Match Done" : "Roll Cup (\(yahtzee.rollsRemaining))")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(
                            (yahtzee.rollsRemaining == 0 || yahtzee.isGameComplete)
                                ? Color.gray.opacity(0.35)
                                : Color.orange
                        )
                    )
                    .foregroundStyle((yahtzee.rollsRemaining == 0 || yahtzee.isGameComplete) ? primaryInk.opacity(0.5) : Color.black)
                }
                .buttonStyle(.plain)
                .disabled(yahtzee.rollsRemaining == 0 || yahtzee.isGameComplete)

                if yahtzee.dice.indices.contains(selectedDieIndex) {
                    let o = yahtzee.dice[selectedDieIndex].orientation
                    Text("Die #\(selectedDieIndex + 1): Top \(o.top) • S \(o.south) • E \(o.east) • Bot \(o.bottom)")
                        .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(primaryInk.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 2)

                Button("New Match") {
                    yahtzee.startNewGame()
                    TactileAudioHaptics.shared.playTumble(pip: 5)
                }
                .font(.caption2.weight(.bold))
                .buttonStyle(.bordered)
            }

            // In ⚡ AxLe 3D Mode: Show all 4 3D rotation families (Edge 90°, Corner 120°, Twist 180°, Yaw 90°) + Optional Skewer Pin!
            if yahtzee.probabilityMode == .mysteriousAxis && yahtzee.dice.indices.contains(selectedDieIndex) {
                let slot = yahtzee.dice[selectedDieIndex]
                let o = slot.orientation
                let canSpendMove = (yahtzee.tacticalNudgesRemaining > 0 && yahtzee.rollsRemaining < 3 && !yahtzee.isGameComplete)

                VStack(spacing: 5) {
                    HStack(spacing: 4) {
                        Text("3D Moves (\(yahtzee.tacticalNudgesRemaining)):")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(primaryInk.opacity(0.82))
                            .lineLimit(1)

                        ForEach([TumbleDirection.north, .south, .west, .east], id: \.self) { dir in
                            Button {
                                if yahtzee.nudgeDie(dieIndex: selectedDieIndex, direction: dir) {
                                    TactileAudioHaptics.shared.playTumble(pip: 5)
                                }
                            } label: {
                                Text("\(dir.arrowGlyph)\(o.nextTopPip(whenTipped: dir))")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded).monospacedDigit())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(canSpendMove ? Color.teal.opacity(0.32) : primaryInk.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                            .disabled(!canSpendMove)
                        }

                        Button {
                            if yahtzee.spinDieCorner120(dieIndex: selectedDieIndex) {
                                TactileAudioHaptics.shared.playTumble(pip: 6)
                            }
                        } label: {
                            Text("◇120°→\(o.east)")
                                .font(.system(size: 10, weight: .heavy, design: .rounded).monospacedDigit())
                                .lineLimit(1)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(canSpendMove ? Color.purple.opacity(0.38) : primaryInk.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSpendMove)

                        Button {
                            if yahtzee.twistDie180(dieIndex: selectedDieIndex) {
                                TactileAudioHaptics.shared.playTumble(pip: 6)
                            }
                        } label: {
                            Text("⟳180°→\(o.bottom)")
                                .font(.system(size: 10, weight: .heavy, design: .rounded).monospacedDigit())
                                .lineLimit(1)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(canSpendMove ? Color.orange.opacity(0.42) : primaryInk.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSpendMove)

                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 6) {
                        Button {
                            if yahtzee.yawDie90(dieIndex: selectedDieIndex) {
                                TactileAudioHaptics.shared.playTumble(pip: 3)
                            }
                        } label: {
                            Text("↻ Free Yaw 90°")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().strokeBorder(primaryInk.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button {
                            if yahtzee.cycleDieAxle(dieIndex: selectedDieIndex) {
                                TactileAudioHaptics.shared.playTumble(pip: 4)
                            }
                        } label: {
                            Text("📌 Pin AxLe: \(slot.axleLock.shortTag) (\(yahtzee.axleBreakerTokens))")
                                .font(.system(size: 10, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color(red: 0.85, green: 0.64, blue: 0.18).opacity(0.26)))
                        }
                        .buttonStyle(.plain)
                        .disabled(yahtzee.axleBreakerTokens == 0)

                        Spacer()
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(cardSurface))
                .foregroundStyle(primaryInk)
            }
        }
    }

    private func triggerCupRoll() {
        if yahtzee.rollUnheldDice() {
            rollSpinTick += 1
            TactileAudioHaptics.shared.playTumble(pip: 6)
        }
    }

    // MARK: - 8. Live Bot Play-by-Play Ticker

    private var botPlayByPlayStrip: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(yahtzee.botTurnFeed, id: \.self) { line in
                Text(line)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryInk.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardSurface.opacity(0.85))
        )
    }

    // MARK: - 9. Multi-Column Parlour Scorecard (`You` vs `🐢 TurtLe` vs `🤖 SmoLLey`)

    private var scorecardTable: some View {
        let rec = yahtzee.recommendedOpenCategory?.category
        let cats = yahtzee.activeCategories

        return VStack(spacing: 5) {
            // Header row when playing against Bots
            HStack {
                Text("SCORECARD CATEGORY")
                    .font(.system(size: 9, weight: .black))
                    .opacity(0.65)
                Spacer()
                Text("YOU")
                    .font(.system(size: 9, weight: .black))
                    .frame(width: 46, alignment: .trailing)
                ForEach(yahtzee.bots) { bot in
                    Text("\(bot.emoji)")
                        .font(.system(size: 10, weight: .black))
                        .frame(width: 38, alignment: .trailing)
                }
            }
            .padding(.horizontal, 10)
            .foregroundStyle(primaryInk)

            ForEach(cats) { cat in
                let locked = yahtzee.lockedScores[cat]
                let preview = yahtzee.potentialScore(for: cat)
                let isRecommended = (locked == nil && rec == cat && yahtzee.rollsRemaining < 3 && preview > 0)

                Button {
                    if yahtzee.commitScore(in: cat) {
                        TactileAudioHaptics.shared.playCascadeMatch(chain: 2, isChromaSurge: preview >= 25)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(cat.rawValue)
                            .font(.system(size: 11, weight: isRecommended ? .heavy : .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        if isRecommended {
                            Text("★ BEST")
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.yellow))
                                .foregroundStyle(.black)
                        }
                        Spacer(minLength: 4)

                        // Player Column
                        Group {
                            if let locked {
                                Text("\(locked)✓")
                                    .font(.caption.weight(.black).monospacedDigit())
                                    .foregroundStyle(.green)
                            } else {
                                Text(yahtzee.rollsRemaining < 3 ? "+\(preview)" : "—")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(isRecommended ? Color.yellow : primaryInk.opacity(0.65))
                            }
                        }
                        .frame(width: 46, alignment: .trailing)

                        // Bot Columns
                        ForEach(yahtzee.bots) { bot in
                            let botPts = bot.lockedScores[cat]
                            Text(botPts != nil ? "\(botPts!)" : "·")
                                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(botPts != nil ? primaryInk.opacity(0.88) : primaryInk.opacity(0.35))
                                .frame(width: 38, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        isRecommended ? Color.yellow.opacity(0.88) : primaryInk.opacity(0.10),
                                        lineWidth: isRecommended ? 1.6 : 1.0
                                    )
                            )
                    )
                    .foregroundStyle(primaryInk)
                }
                .buttonStyle(.plain)
                .disabled(locked != nil || yahtzee.rollsRemaining == 3)
            }

            // Upper Bonus & Totals Summary Footer
            HStack(spacing: 6) {
                Text("TOTAL (incl. +35 Upper Bonus at \(yahtzee.upperBonusThreshold)+)")
                    .font(.system(size: 10, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Text("\(yahtzee.totalScore)")
                    .font(.subheadline.weight(.black).monospacedDigit())
                    .frame(width: 46, alignment: .trailing)
                ForEach(yahtzee.bots) { bot in
                    Text("\(bot.totalScore(for: yahtzee.probabilityMode))")
                        .font(.caption.weight(.black).monospacedDigit())
                        .frame(width: 38, alignment: .trailing)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.teal.opacity(0.22)))
            .foregroundStyle(primaryInk)
        }
    }
}

// MARK: - Illustrated Rules & 3D Cube Rotation Guide Sheet

private struct YahtzeeGuideSheet: View {
    let yahtzee: AxleYahtzeeEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    guideSection(
                        title: "1. Three Ways to Play (Switch Anytime)",
                        body: """
                        • 🎲 ReguLar 1–6: Pure classic 5-dice Yahtzee! Standard 1–6 dice, up to 3 rolls per turn, tap dice to HOLD ★, 13 categories, and +35 Upper Bonus when 1s–6s reach 63+.
                        • ⚡ AxLe 3D: Full 24-state SO(3) spatial Yahtzee! Dice roll freely across all 6 faces AND let you spend 1 Tactical 3D Move per turn plus optional 4-ring skewers.
                        • ◇ 4-Num Pair: Mathematical duplicate-face cubes α {1,1,2,2,3,4} & β {3,3,4,4,1,2} giving exact 3/12 = 25% odds per number.
                        """
                    )

                    guideSection(
                        title: "2. Why 3D Dice Don’t Only Turn About Axles!",
                        body: """
                        A physical right-handed cube has 24 rotational states in SO(3), generated by 4 distinct spatial moves in ⚡ AxLe 3D:
                        • ↑ ↓ ← → 90° Edge Tumble: Tips the cube 90° in any cardinal direction (never artificially blocked!).
                        • ◇ 120° Corner-Vertex Spin: Spins 120° around the front-upper-right corner [East → Top → South → East], bringing the East face straight onto Top!
                        • ⟳ 180° Sum-7 Twist: Somersaults 180° to swap Top ↔ Bottom (1↔6, 2↔5, 3↔4).
                        • ↻ Free 90° Felt Yaw: Spins clockwise flat on the table (0 move cost) to line up East/South for your next move!
                        """
                    )

                    guideSection(
                        title: "3. Optional AxLe Skewers ([1-6], [2-5], [3-4])",
                        body: """
                        • Unpinned dice (Free-24) roll all 6 faces at 1/6 each.
                        • Tapping [📌 Pin AxLe] threads a golden skewer through a Sum-7 opposite pair so that die's next Cup Roll lands strictly on the remaining 4-face ring at 25% each:
                          – AxLe [1-6] rolls {2, 3, 5, 4}
                          – AxLe [2-5] rolls {1, 3, 6, 4}
                          – AxLe [3-4] rolls {1, 2, 6, 5}
                        """
                    )

                    guideSection(
                        title: "4. Bot Opponents (🐢 TurtLe & 🤖 Joe SmoLLey)",
                        body: """
                        • 👤 Solo: Relaxed high-score practice with live Coach Prompts.
                        • 🐢 TurtLe Bot: Friendly club regular who collects clean pairs, trios, and Full Houses.
                        • 🤖 Joe SmoLLey: 3D parlour shark who chases 63+ Upper Bonuses, Large Straights, and uses ◇120° Corner Spins & ⟳180° Twists in ⚡ AxLe 3D!
                        • 🏆 Trio (🐢+🤖): Three-seat parlour showdown against both Bots at once!
                        """
                    )
                }
                .padding(18)
            }
            .navigationTitle("Yahtzee & AxLe 3D Guide")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }

    private func guideSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.footnote)
                .opacity(0.88)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.06)))
    }
}
