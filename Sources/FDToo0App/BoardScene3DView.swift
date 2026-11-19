//
//  BoardScene3DView.swift
//  FD_too0 (Joe SmoLLey 3D Spatial Deck)
//
//  True Hardware-Accelerated SceneKit 3D Tray for Classic FD & FD_too0 (1,023 Levels).
//  Displays Top + South + East faces simultaneously in Twisted23's signature
//  Orthographic 3D-in-2D projection (or full 3D Perspective) with smooth quaternion tumbles!
//

import SwiftUI
import Combine
import SceneKit
import simd
import FDToo0Core

@MainActor
public final class BoardScene3DCoordinator: ObservableObject {
    public let scene = SCNScene()
    public let cameraNode = SCNNode()
    private let trayRoot = SCNNode()
    private let padsRoot = SCNNode()
    private let diceRoot = SCNNode()
    private var dieNodesByID: [Int: SCNNode] = [:]
    private var lastSkin: DieVisualSkin? = nil
    private var lastAppearance: BoardAppearanceMode? = nil
    private var lastLevelKey: String = ""

    public init() {
        setupLights()
        setupCamera()
        trayRoot.addChildNode(padsRoot)
        trayRoot.addChildNode(diceRoot)
        scene.rootNode.addChildNode(trayRoot)
    }

    private func setupLights() {
        let key = SCNNode()
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 1080
        keyLight.castsShadow = true
        key.light = keyLight
        key.simdEulerAngles = SIMD3<Float>(-.pi / 2.8, .pi / 5.5, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 460
        fill.light = fillLight
        fill.simdPosition = SIMD3<Float>(-6, 8, 7)
        scene.rootNode.addChildNode(fill)

        let amb = SCNNode()
        let ambLight = SCNLight()
        ambLight.type = .ambient
        ambLight.intensity = 380
        amb.light = ambLight
        scene.rootNode.addChildNode(amb)
    }

    private func setupCamera() {
        let cam = SCNCamera()
        cam.zNear = 0.5
        cam.zFar = 120.0
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
    }

    public func sync(
        engine: GameEngine23,
        selectedCoord: GridCoord?,
        glowingCoords: Set<GridCoord>
    ) {
        let rows = engine.blueprint.rows
        let cols = engine.blueprint.cols
        let spacing: Float = 1.78
        let maxSpan = Float(max(rows, cols))

        // Background & tray palette
        switch engine.appearanceMode {
        case .dark:
            scene.background.contents = SceneKitDieBuilder.makeColor(0.08, 0.08, 0.09)
        case .light:
            scene.background.contents = SceneKitDieBuilder.makeColor(0.95, 0.93, 0.89)
        case .spruce:
            scene.background.contents = SceneKitDieBuilder.makeColor(0.20, 0.14, 0.10)
        }

        // Camera framing: Slight SE-above isometric tilt reveals Top + South (+Z) + East (+X) simultaneously!
        if let cam = cameraNode.camera {
            let isOrtho = (engine.cameraProjection == .orthographic3DIn2D)
            cam.usesOrthographicProjection = isOrtho
            cam.orthographicScale = Double(maxSpan) * 1.04
            cam.fieldOfView = 36.0
        }
        let dist = maxSpan * 2.55 + 3.5
        cameraNode.simdPosition = SIMD3<Float>(dist * 0.30, dist * 0.92, dist * 0.44)
        cameraNode.simdLook(at: SIMD3<Float>(0, 0, 0.15))

        let levelKey = "\(engine.mode.rawValue)-\(engine.currentLevel)-\(rows)x\(cols)-\(engine.appearanceMode.rawValue)"
        if levelKey != lastLevelKey {
            rebuildPads(blueprint: engine.blueprint, spacing: spacing, appearance: engine.appearanceMode)
            for (_, node) in dieNodesByID { node.removeFromParentNode() }
            dieNodesByID.removeAll()
            lastLevelKey = levelKey
        }

        if lastSkin != engine.visualSkin || lastAppearance != engine.appearanceMode {
            for (_, node) in dieNodesByID { node.removeFromParentNode() }
            dieNodesByID.removeAll()
            lastSkin = engine.visualSkin
            lastAppearance = engine.appearanceMode
        }

        // Sync active dice positions & 3D orientations
        var activeIDs = Set<Int>()
        let xOrigin = -Float(cols - 1) * 0.5 * spacing
        let zOrigin = -Float(rows - 1) * 0.5 * spacing

        SCNTransaction.begin()
        SCNTransaction.animationDuration = engine.paceSpeed.tumbleDuration * 0.85

        for r in 0..<rows {
            for c in 0..<cols {
                guard let die = engine.grid[r][c] else { continue }
                activeIDs.insert(die.id)
                let coord = GridCoord(r, c)
                let isSel = (selectedCoord == coord)
                let isGlow = glowingCoords.contains(coord)
                let worldPos = SIMD3<Float>(
                    xOrigin + Float(c) * spacing,
                    isSel ? 0.24 : 0.0,
                    zOrigin + Float(r) * spacing
                )

                // Rebuild node if frost/chain/glow/selection state changed, otherwise animate smoothly!
                let stateTag = (die.frostLayers * 100) + (die.isChained ? 10 : 0) + (isGlow ? 2 : (isSel ? 1 : 0))
                let existing = dieNodesByID[die.id]
                let targetNode: SCNNode

                if let existing, existing.name == "\(stateTag)" {
                    targetNode = existing
                } else {
                    existing?.removeFromParentNode()
                    let fresh = SceneKitDieBuilder.makeDieNode(
                        pastelHue: die.pastelHue,
                        appearance: engine.appearanceMode,
                        skin: engine.visualSkin,
                        axleLock: .free24,
                        isSelected: isSel,
                        isMatchGlowing: isGlow,
                        frostLayers: die.frostLayers,
                        isChained: die.isChained
                    )
                    fresh.name = "\(stateTag)"
                    fresh.simdPosition = worldPos
                    diceRoot.addChildNode(fresh)
                    dieNodesByID[die.id] = fresh
                    targetNode = fresh
                }

                targetNode.simdPosition = worldPos
                targetNode.simdOrientation = SceneKitDieBuilder.simdQuat(from: die.orientation.unitQuaternion)
            }
        }

        // Remove cleared dice
        for (id, node) in dieNodesByID where !activeIDs.contains(id) {
            node.removeFromParentNode()
            dieNodesByID.removeValue(forKey: id)
        }

        SCNTransaction.commit()
    }

    private func rebuildPads(
        blueprint: LevelBlueprint,
        spacing: Float,
        appearance: BoardAppearanceMode
    ) {
        padsRoot.childNodes.forEach { $0.removeFromParentNode() }
        let rows = blueprint.rows
        let cols = blueprint.cols
        let xOrigin = -Float(cols - 1) * 0.5 * spacing
        let zOrigin = -Float(rows - 1) * 0.5 * spacing

        for r in 0..<rows {
            for c in 0..<cols {
                let pad = blueprint.pads[r][c]
                if pad == .hole { continue }
                let tile = SCNBox(width: 1.58, height: 0.14, length: 1.58, chamferRadius: 0.05)
                let mat = SCNMaterial()
                mat.lightingModel = .physicallyBased
                mat.roughness.contents = 0.65

                switch pad {
                case .normal:
                    mat.diffuse.contents = appearance == .light
                        ? SceneKitDieBuilder.makeColor(0.86, 0.83, 0.78)
                        : SceneKitDieBuilder.makeColor(0.16, 0.15, 0.17)
                case .chromaMultiplier(let m):
                    mat.diffuse.contents = m >= 3
                        ? SceneKitDieBuilder.makeColor(0.68, 0.45, 0.14)
                        : SceneKitDieBuilder.makeColor(0.24, 0.52, 0.42)
                case .twist180:
                    mat.diffuse.contents = SceneKitDieBuilder.makeColor(0.66, 0.34, 0.16)
                case .portal:
                    mat.diffuse.contents = SceneKitDieBuilder.makeColor(0.16, 0.54, 0.62)
                case .hole:
                    break
                }
                tile.materials = [mat]
                let n = SCNNode(geometry: tile)
                n.simdPosition = SIMD3<Float>(xOrigin + Float(c) * spacing, -0.80, zOrigin + Float(r) * spacing)
                padsRoot.addChildNode(n)
            }
        }
    }
}

public struct BoardScene3DView: View {
    public var engine: GameEngine23
    public var isInteractionLocked: Bool
    public var onSwipeCell: (GridCoord, TumbleDirection) -> Void
    public var onTapCell: (GridCoord) -> Void

    @StateObject private var coordinator = BoardScene3DCoordinator()

    public init(
        engine: GameEngine23,
        isInteractionLocked: Bool,
        onSwipeCell: @escaping (GridCoord, TumbleDirection) -> Void,
        onTapCell: @escaping (GridCoord) -> Void
    ) {
        self.engine = engine
        self.isInteractionLocked = isInteractionLocked
        self.onSwipeCell = onSwipeCell
        self.onTapCell = onTapCell
    }

    public var body: some View {
        let rows = engine.blueprint.rows
        let cols = engine.blueprint.cols

        ZStack {
            SceneView(
                scene: coordinator.scene,
                pointOfView: coordinator.cameraNode,
                options: [.rendersContinuously, .temporalAntialiasingEnabled]
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // Transparent cell-aligned touch/mouse gesture matrix over the 3D board
            VStack(spacing: 4) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 4) {
                        ForEach(0..<cols, id: \.self) { c in
                            let coord = GridCoord(r, c)
                            Color.white.opacity(0.001)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 12)
                                        .onEnded { val in
                                            guard !isInteractionLocked else { return }
                                            let dx = val.translation.width
                                            let dy = val.translation.height
                                            let dir: TumbleDirection = abs(dx) > abs(dy)
                                                ? (dx > 0 ? .east : .west)
                                                : (dy > 0 ? .south : .north)
                                            onSwipeCell(coord, dir)
                                        }
                                )
                                .onTapGesture {
                                    guard !isInteractionLocked else { return }
                                    onTapCell(coord)
                                }
                        }
                    }
                }
            }
            .padding(18)
        }
        .aspectRatio(CGFloat(cols) / CGFloat(rows), contentMode: .fit)
        .onAppear {
            coordinator.sync(
                engine: engine,
                selectedCoord: engine.selectedCoord,
                glowingCoords: engine.glowingMatchCoords
            )
        }
        .onChange(of: engine.grid) { _, _ in
            coordinator.sync(engine: engine, selectedCoord: engine.selectedCoord, glowingCoords: engine.glowingMatchCoords)
        }
        .onChange(of: engine.selectedCoord) { _, newSel in
            coordinator.sync(engine: engine, selectedCoord: newSel, glowingCoords: engine.glowingMatchCoords)
        }
        .onChange(of: engine.glowingMatchCoords) { _, newGlow in
            coordinator.sync(engine: engine, selectedCoord: engine.selectedCoord, glowingCoords: newGlow)
        }
        .onChange(of: engine.visualSkin) { _, _ in
            coordinator.sync(engine: engine, selectedCoord: engine.selectedCoord, glowingCoords: engine.glowingMatchCoords)
        }
        .onChange(of: engine.cameraProjection) { _, _ in
            coordinator.sync(engine: engine, selectedCoord: engine.selectedCoord, glowingCoords: engine.glowingMatchCoords)
        }
        .onChange(of: engine.appearanceMode) { _, _ in
            coordinator.sync(engine: engine, selectedCoord: engine.selectedCoord, glowingCoords: engine.glowingMatchCoords)
        }
    }
}
