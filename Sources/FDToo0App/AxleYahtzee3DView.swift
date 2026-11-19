//
//  AxleYahtzee3DView.swift
//  FD_too0 (Joe SmoLLey 3D Spatial Deck)
//
//  3D SceneKit Parlour Table for AxLe-Locked & FaceCard Yahtzee:
//  - Mysterious-Axis Mode ([1-6], [2-5], [3-4] skewers rolling 4-face rings at exact 1/4 odds)
//  - Physical Duplicate-Face 4-Number Mode (Conjugate α/β 6-face cubes with exact 1/4 pool odds)
//  - One-Eyed Jack (J♠) Axle-Breaker & Two-Eyed Jack (J♦) Wild powers + Learned 90° Nudge!
//

import SwiftUI
import Combine
import SceneKit
import simd
import FDToo0Core

@MainActor
public final class Yahtzee3DSceneCoordinator: ObservableObject {
    public let scene = SCNScene()
    public let cameraNode = SCNNode()
    private let trayNode = SCNNode()
    private var dieNodes: [SCNNode] = []

    public init() {
        scene.background.contents = SceneKitDieBuilder.makeColor(0.07, 0.10, 0.16)
        let key = SCNNode()
        let kl = SCNLight()
        kl.type = .directional
        kl.intensity = 1120
        key.light = kl
        key.simdEulerAngles = SIMD3<Float>(-.pi / 3.0, .pi / 5.0, 0)
        scene.rootNode.addChildNode(key)

        let amb = SCNNode()
        let al = SCNLight()
        al.type = .ambient
        al.intensity = 420
        amb.light = al
        scene.rootNode.addChildNode(amb)

        let cam = SCNCamera()
        cam.usesOrthographicProjection = true
        cam.orthographicScale = 3.2
        cameraNode.camera = cam
        cameraNode.simdPosition = SIMD3<Float>(2.4, 7.6, 5.2)
        cameraNode.simdLook(at: SIMD3<Float>(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(trayNode)
    }

    public func sync(
        dice: [YahtzeeDieSlot],
        mode: AxleYahtzeeProbabilityMode,
        skin: DieVisualSkin,
        appearance: BoardAppearanceMode,
        projection: CameraProjectionStyle,
        selectedDieIndex: Int
    ) {
        if let cam = cameraNode.camera {
            cam.usesOrthographicProjection = (projection != .perspective3D)
            cam.orthographicScale = 3.25
            cam.fieldOfView = 38.0
        }

        trayNode.childNodes.forEach { $0.removeFromParentNode() }
        dieNodes.removeAll()

        let spacing: Float = 2.05
        let startX = -Float(dice.count - 1) * 0.5 * spacing

        for (idx, slot) in dice.enumerated() {
            let arch: ConjugateCubeArchetype? = (mode == .conjugateDuplicate4Faces) ? slot.archetype : nil
            let node = SceneKitDieBuilder.makeDieNode(
                pastelHue: slot.pastelHue,
                appearance: appearance,
                skin: skin,
                axleLock: slot.axleLock,
                conjugateArchetype: arch,
                isSelected: idx == selectedDieIndex,
                isMatchGlowing: slot.isHeld
            )
            node.simdPosition = SIMD3<Float>(startX + Float(idx) * spacing, slot.isHeld ? 0.36 : 0.0, 0)
            node.simdOrientation = SceneKitDieBuilder.simdQuat(from: slot.orientation.unitQuaternion)
            trayNode.addChildNode(node)
            dieNodes.append(node)
        }
    }
}

public struct AxleYahtzee3DView: View {
    @Bindable public var yahtzee: AxleYahtzeeEngine
    public var globalEngine: GameEngine23

    @StateObject private var sceneCoord = Yahtzee3DSceneCoordinator()
    @State private var selectedDieIndex: Int = 0
    @State private var rollSpinTick: Int = 0

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
            ? Color(red: 0.95, green: 0.93, blue: 0.89)
            : Color(red: 0.11, green: 0.13, blue: 0.18)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                modeAndMathBar
                scene3DTrayCard
                dieHoldAndAxleStrip
                learnedTacticalControls
                scorecardGrid
            }
            .padding(.bottom, 12)
        }
        .onAppear { refreshScene() }
        .onChange(of: yahtzee.dice) { _, _ in refreshScene() }
        .onChange(of: globalEngine.visualSkin) { _, _ in refreshScene() }
        .onChange(of: globalEngine.cameraProjection) { _, _ in refreshScene() }
        .onChange(of: selectedDieIndex) { _, _ in refreshScene() }
    }

    private func refreshScene() {
        sceneCoord.sync(
            dice: yahtzee.dice,
            mode: yahtzee.probabilityMode,
            skin: globalEngine.visualSkin,
            appearance: globalEngine.appearanceMode,
            projection: globalEngine.cameraProjection,
            selectedDieIndex: selectedDieIndex
        )
    }

    private var modeAndMathBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Picker("Probability Engine", selection: $yahtzee.probabilityMode) {
                    ForEach(AxleYahtzeeProbabilityMode.allCases) { m in
                        Text(m == .mysteriousAxis ? "Mysterious AxLe" : "4-Number Conjugate").tag(m)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Jacks✦", isOn: $yahtzee.jackPowersEnabled)
                    .font(.caption2.weight(.bold))
                    .toggleStyle(.button)
            }

            Text(yahtzee.statusBanner)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(primaryInk.opacity(0.86))
                .multilineTextAlignment(.center)
        }
    }

    private var scene3DTrayCard: some View {
        ZStack(alignment: .topTrailing) {
            SceneView(
                scene: sceneCoord.scene,
                pointOfView: sceneCoord.cameraNode,
                options: [.allowsCameraControl, .temporalAntialiasingEnabled]
            )
            .frame(height: 178)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("Total \(yahtzee.totalScore) pts")
                .font(.caption.weight(.heavy).monospacedDigit())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(8)
        }
    }

    private var dieHoldAndAxleStrip: some View {
        HStack(spacing: 6) {
            ForEach(Array(yahtzee.dice.enumerated()), id: \.element.id) { idx, slot in
                let val = slot.effectiveValue(in: yahtzee.probabilityMode)
                let sig = LearnedGeometryOracle.signature(for: slot.orientation)
                let badge = globalEngine.visualSkin == .royalFaceCards && yahtzee.probabilityMode == .mysteriousAxis
                    ? sig.faceCardBadge
                    : "\(val)\(sig.cornerQuadrant.arrowGlyph)"

                VStack(spacing: 3) {
                    Button {
                        selectedDieIndex = idx
                        yahtzee.toggleHold(dieIndex: idx)
                    } label: {
                        VStack(spacing: 2) {
                            Text(badge)
                                .font(.caption.weight(.black).monospacedDigit())
                            Text(yahtzee.probabilityMode == .mysteriousAxis ? slot.axleLock.shortTag : (slot.archetype == .alpha12Doubled ? "Cube α" : "Cube β"))
                                .font(.system(size: 9, weight: .bold))
                                .opacity(0.75)
                            Text(slot.isHeld ? "HELD ★" : (selectedDieIndex == idx ? "FOCUS" : "TAP HOLD"))
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(slot.isHeld ? Color.yellow : primaryInk.opacity(0.65))
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
    }

    private var learnedTacticalControls: some View {
        HStack(spacing: 8) {
            Button {
                rollSpinTick += 1
                if yahtzee.rollUnheldDice() {
                    TactileAudioHaptics.shared.playTumble(pip: 6)
                }
            } label: {
                Label("Roll Cup (\(yahtzee.rollsRemaining))", systemImage: "dice.fill")
                    .font(.caption.weight(.heavy))
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(yahtzee.rollsRemaining == 0 || yahtzee.isGameComplete)

            if yahtzee.probabilityMode == .mysteriousAxis {
                Button {
                    if yahtzee.cycleDieAxle(dieIndex: selectedDieIndex) {
                        TactileAudioHaptics.shared.playTumble(pip: 3)
                    }
                } label: {
                    Text("♠J Break AxLe (\(yahtzee.axleBreakerTokens))")
                        .font(.caption2.weight(.bold))
                }
                .buttonStyle(.bordered)
                .disabled(yahtzee.axleBreakerTokens == 0)
            }

            HStack(spacing: 4) {
                ForEach(TumbleDirection.allCases, id: \.self) { dir in
                    Button(dir.arrowGlyph) {
                        if yahtzee.nudgeDie(dieIndex: selectedDieIndex, direction: dir) {
                            TactileAudioHaptics.shared.playTumble(pip: 5)
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption.bold())
                    .disabled(yahtzee.tacticalNudgesRemaining == 0 || yahtzee.rollsRemaining == 3)
                }
            }

            Button("New") {
                yahtzee.startNewGame()
            }
            .buttonStyle(.bordered)
            .font(.caption2.bold())
        }
    }

    private var scorecardGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        let rec = yahtzee.recommendedOpenCategory?.category

        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(AxleYahtzeeCategory.allCases) { cat in
                let locked = yahtzee.lockedScores[cat]
                let preview = yahtzee.potentialScore(for: cat)
                let isRecommended = (locked == nil && rec == cat && yahtzee.rollsRemaining < 3 && preview > 0)

                Button {
                    if yahtzee.commitScore(in: cat) {
                        TactileAudioHaptics.shared.playCascadeMatch(chain: 2, isChromaSurge: preview >= 25)
                    }
                } label: {
                    HStack {
                        Text(cat.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 4)
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(isRecommended ? Color.yellow.opacity(0.85) : primaryInk.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(primaryInk)
                }
                .buttonStyle(.plain)
                .disabled(locked != nil || yahtzee.rollsRemaining == 3)
            }
        }
    }
}
