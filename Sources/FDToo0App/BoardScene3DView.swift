//
//  BoardScene3DView.swift
//  FD_too0 (Joe SmoLLey 3D Spatial Deck)
//
//  True Hardware-Accelerated SceneKit 3D Tray for Classic FD & FD_too0 (1,023 Levels).
//  - Upright Parlour Camera reveals Top + South + East faces while keeping Rows (← →)
//    and Columns (↑ ↓) cleanly aligned with screen gestures.
//  - Native 3D Raycast Hit-Testing (`SCNView.hitTest`) on macOS & iOS guarantees every
//    tap and directional swipe hits the exact 3D die under your finger/cursor.
//  - Persistent SCNNode lifecycle preserves smooth 90° quaternion tumbles and 2-stage
//    aerial 180° Twist somersaults (`top ↔ 7 - top`).
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
public final class BoardScene3DCoordinator: ObservableObject {
    private struct DieNodeRecord {
        let node: SCNNode
        var frostLayers: Int
        var isChained: Bool
        var pastelHue: PastelHueFamily
        var lastCoord: GridCoord
        var lastOrientation: DieOrientation
    }

    public let scene = SCNScene()
    public let cameraNode = SCNNode()

    private let trayRoot = SCNNode()
    private let padsRoot = SCNNode()
    private let diceRoot = SCNNode()
    private let selectionPlateNode = SCNNode()

    private var dieRecordsByID: [Int: DieNodeRecord] = [:]
    private var lastSkin: DieVisualSkin? = nil
    private var lastAppearance: BoardAppearanceMode? = nil
    private var lastLevelKey: String = ""
    private var lastSelectedCoord: GridCoord? = nil
    private var hasCompletedInitialSync: Bool = false

    public init() {
        setupLights()
        setupCamera()
        setupSelectionPlate()
        trayRoot.addChildNode(padsRoot)
        trayRoot.addChildNode(selectionPlateNode)
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
        key.simdEulerAngles = SIMD3<Float>(-.pi / 2.75, .pi / 6.5, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 480
        fill.light = fillLight
        fill.simdPosition = SIMD3<Float>(-6, 8.5, 7.5)
        scene.rootNode.addChildNode(fill)

        let amb = SCNNode()
        let ambLight = SCNLight()
        ambLight.type = .ambient
        ambLight.intensity = 390
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

    private func setupSelectionPlate() {
        let bezel = SCNBox(width: 1.66, height: 0.08, length: 1.66, chamferRadius: 0.16)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = SceneKitDieBuilder.makeColor(0.98, 0.78, 0.20)
        mat.emission.contents = SceneKitDieBuilder.makeColor(0.85, 0.62, 0.12)
        mat.roughness.contents = 0.25
        bezel.materials = [mat]
        selectionPlateNode.geometry = bezel
        selectionPlateNode.isHidden = true
    }

    // MARK: - Exact 3D Raycast Hit-Testing

    public static func parseCellName(_ name: String?) -> GridCoord? {
        guard let name, name.hasPrefix("cell_") else { return nil }
        let parts = name.dropFirst(5).split(separator: "_")
        guard parts.count == 2,
              let r = Int(parts[0]),
              let c = Int(parts[1]) else { return nil }
        return GridCoord(r, c)
    }

    public static func hitTestCell(in scnView: SCNView, at point: CGPoint) -> GridCoord? {
        let options: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .ignoreHiddenNodes: true
        ]
        let hits = scnView.hitTest(point, options: options)
        for hit in hits {
            var cur: SCNNode? = hit.node
            while let n = cur {
                if let coord = parseCellName(n.name) {
                    return coord
                }
                cur = n.parent
            }
        }
        return nil
    }

    // MARK: - Scene State Synchronization & 3D Tumble / 180° Twist Choreography

    public func sync(
        engine: GameEngine23,
        selectedCoord: GridCoord?,
        glowingCoords: Set<GridCoord>,
        twistArmed: Bool
    ) {
        let rows = engine.blueprint.rows
        let cols = engine.blueprint.cols
        let spacing: Float = 1.78
        let maxSpan = Float(max(rows, cols))
        self.lastSelectedCoord = selectedCoord

        // Background & tray palette
        switch engine.appearanceMode {
        case .dark:
            scene.background.contents = SceneKitDieBuilder.makeColor(0.08, 0.08, 0.09)
        case .light:
            scene.background.contents = SceneKitDieBuilder.makeColor(0.95, 0.93, 0.89)
        case .spruce:
            scene.background.contents = SceneKitDieBuilder.makeColor(0.20, 0.14, 0.10)
        }

        // Upright Parlour Camera: keeps Rows horizontal (← →) and Columns vertical (↑ ↓)
        // while revealing Top (+Y), South (+Z), and East (+X) 3D faces!
        if let cam = cameraNode.camera {
            let isOrtho = (engine.cameraProjection == .orthographic3DIn2D)
            cam.usesOrthographicProjection = isOrtho
            cam.orthographicScale = Double(maxSpan) * 0.98
            cam.fieldOfView = 35.0
        }
        let dist = maxSpan * 2.52 + 3.4
        cameraNode.simdPosition = SIMD3<Float>(dist * 0.06, dist * 0.88, dist * 0.48)
        cameraNode.simdLook(at: SIMD3<Float>(0, -0.05, 0.08))

        let levelKey = "\(engine.mode.rawValue)-\(engine.currentLevel)-\(rows)x\(cols)-\(engine.appearanceMode.rawValue)"
        var resetBoardImmediately = !hasCompletedInitialSync
        if levelKey != lastLevelKey {
            rebuildPads(blueprint: engine.blueprint, spacing: spacing, appearance: engine.appearanceMode)
            for (_, rec) in dieRecordsByID { rec.node.removeFromParentNode() }
            dieRecordsByID.removeAll()
            lastLevelKey = levelKey
            resetBoardImmediately = true
        }

        if lastSkin != engine.visualSkin || lastAppearance != engine.appearanceMode {
            for (_, rec) in dieRecordsByID { rec.node.removeFromParentNode() }
            dieRecordsByID.removeAll()
            lastSkin = engine.visualSkin
            lastAppearance = engine.appearanceMode
            resetBoardImmediately = true
        }

        let xOrigin = -Float(cols - 1) * 0.5 * spacing
        let zOrigin = -Float(rows - 1) * 0.5 * spacing

        // Update golden/orange selection plate under selected die
        if let sel = selectedCoord,
           sel.row >= 0, sel.row < rows, sel.col >= 0, sel.col < cols,
           engine.grid[sel.row][sel.col] != nil {
            selectionPlateNode.isHidden = false
            if let mat = selectionPlateNode.geometry?.firstMaterial {
                if twistArmed {
                    mat.diffuse.contents = SceneKitDieBuilder.makeColor(1.0, 0.52, 0.12)
                    mat.emission.contents = SceneKitDieBuilder.makeColor(0.95, 0.42, 0.08)
                } else {
                    mat.diffuse.contents = SceneKitDieBuilder.makeColor(0.98, 0.78, 0.20)
                    mat.emission.contents = SceneKitDieBuilder.makeColor(0.85, 0.62, 0.12)
                }
            }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.14
            selectionPlateNode.simdPosition = SIMD3<Float>(
                xOrigin + Float(sel.col) * spacing,
                -0.71,
                zOrigin + Float(sel.row) * spacing
            )
            SCNTransaction.commit()
        } else {
            selectionPlateNode.isHidden = true
        }

        var activeIDs = Set<Int>()
        let tumbleDur = engine.paceSpeed.tumbleDuration * 0.88
        let dropDur = engine.paceSpeed.dropDuration * 0.85

        for r in 0..<rows {
            for c in 0..<cols {
                guard let die = engine.grid[r][c] else { continue }
                activeIDs.insert(die.id)
                let coord = GridCoord(r, c)
                let isSel = (selectedCoord == coord)
                let isGlow = glowingCoords.contains(coord)
                let worldPos = SIMD3<Float>(
                    xOrigin + Float(c) * spacing,
                    isSel ? 0.28 : 0.0,
                    zOrigin + Float(r) * spacing
                )
                let targetQuat = SceneKitDieBuilder.simdQuat(from: die.orientation.unitQuaternion)

                if var rec = dieRecordsByID[die.id],
                   rec.frostLayers == die.frostLayers,
                   rec.isChained == die.isChained,
                   rec.pastelHue == die.pastelHue {
                    // Reuse existing SCNNode so animations stay silky smooth!
                    rec.node.name = "cell_\(r)_\(c)"
                    SceneKitDieBuilder.updateDieHighlight(
                        node: rec.node,
                        isSelected: isSel,
                        isMatchGlowing: isGlow
                    )

                    let prevCoord = rec.lastCoord
                    let prevOri = rec.lastOrientation
                    rec.lastCoord = coord
                    rec.lastOrientation = die.orientation
                    dieRecordsByID[die.id] = rec

                    if prevCoord == coord && prevOri != die.orientation && !resetBoardImmediately {
                        // In-place 180° Twist (or Undo of Twist): 2-stage aerial somersault!
                        let midOri = (die.orientation == prevOri.twisted180()) ? prevOri.tipped(.east) : die.orientation
                        let midQuat = SceneKitDieBuilder.simdQuat(from: midOri.unitQuaternion)
                        let halfDur = max(0.14, engine.paceSpeed.tumbleDuration * 0.48)
                        let liftPos = SIMD3<Float>(worldPos.x, 1.02, worldPos.z)

                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = halfDur
                        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
                        rec.node.simdPosition = liftPos
                        rec.node.simdOrientation = midQuat
                        SCNTransaction.commit()

                        let capturedID = die.id
                        Task { @MainActor [weak self] in
                            try? await Task.sleep(nanoseconds: UInt64(halfDur * 1_000_000_000))
                            guard let self,
                                  let latestRec = self.dieRecordsByID[capturedID] else { return }
                            let settleY: Float = (self.lastSelectedCoord == latestRec.lastCoord) ? 0.28 : 0.0
                            let settlePos = SIMD3<Float>(
                                xOrigin + Float(latestRec.lastCoord.col) * spacing,
                                settleY,
                                zOrigin + Float(latestRec.lastCoord.row) * spacing
                            )
                            let finalQuat = SceneKitDieBuilder.simdQuat(from: latestRec.lastOrientation.unitQuaternion)
                            SCNTransaction.begin()
                            SCNTransaction.animationDuration = halfDur
                            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                            latestRec.node.simdPosition = settlePos
                            latestRec.node.simdOrientation = finalQuat
                            SCNTransaction.commit()
                        }
                    } else {
                        // 90° Swipe Tumble / Gravity Shift / Selection Lift
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = resetBoardImmediately ? 0.0 : tumbleDur
                        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        rec.node.simdPosition = worldPos
                        rec.node.simdOrientation = targetQuat
                        SCNTransaction.commit()
                    }
                } else {
                    // Build fresh SCNNode (either initial load, cascade refill, or frost/chain state change)
                    let hadPrevious = dieRecordsByID[die.id] != nil
                    let prevPos = dieRecordsByID[die.id]?.node.simdPosition
                    dieRecordsByID[die.id]?.node.removeFromParentNode()

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
                    fresh.name = "cell_\(r)_\(c)"

                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.0
                    if resetBoardImmediately {
                        fresh.simdPosition = worldPos
                    } else if let prevPos, hadPrevious {
                        fresh.simdPosition = prevPos
                    } else {
                        fresh.simdPosition = SIMD3<Float>(worldPos.x, worldPos.y + 1.65, worldPos.z)
                    }
                    fresh.simdOrientation = targetQuat
                    diceRoot.addChildNode(fresh)
                    SCNTransaction.commit()

                    if !resetBoardImmediately {
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = hadPrevious ? tumbleDur : dropDur
                        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
                        fresh.simdPosition = worldPos
                        SCNTransaction.commit()
                    }

                    dieRecordsByID[die.id] = DieNodeRecord(
                        node: fresh,
                        frostLayers: die.frostLayers,
                        isChained: die.isChained,
                        pastelHue: die.pastelHue,
                        lastCoord: coord,
                        lastOrientation: die.orientation
                    )
                }
            }
        }

        // Remove cleared dice
        for (id, rec) in dieRecordsByID where !activeIDs.contains(id) {
            rec.node.removeFromParentNode()
            dieRecordsByID.removeValue(forKey: id)
        }

        hasCompletedInitialSync = true
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
                let tile = SCNBox(width: 1.68, height: 0.14, length: 1.68, chamferRadius: 0.06)
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
                n.name = "cell_\(r)_\(c)"
                n.simdPosition = SIMD3<Float>(xOrigin + Float(c) * spacing, -0.78, zOrigin + Float(r) * spacing)
                padsRoot.addChildNode(n)
            }
        }
    }
}

// MARK: - Platform-Native Interactive Raycasting SCNView

#if os(macOS)
private final class BoardHitSCNView: SCNView {
    var isInteractionLocked: Bool = false
    var onTapCell: ((GridCoord) -> Void)?
    var onSwipeCell: ((GridCoord, TumbleDirection) -> Void)?

    private var downPoint: NSPoint?
    private var downCoord: GridCoord?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard !isInteractionLocked else {
            downPoint = nil
            downCoord = nil
            return
        }
        let pt = convert(event.locationInWindow, from: nil)
        downPoint = pt
        downCoord = BoardScene3DCoordinator.hitTestCell(in: self, at: pt)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            downPoint = nil
            downCoord = nil
        }
        guard !isInteractionLocked, let startPt = downPoint else { return }
        let endPt = convert(event.locationInWindow, from: nil)
        let dx = endPt.x - startPt.x
        let dyScreenUp = isFlipped ? -(endPt.y - startPt.y) : (endPt.y - startPt.y)
        let dist = hypot(dx, dyScreenUp)

        if dist >= 14.0 {
            guard let startCoord = downCoord else { return }
            let dir: TumbleDirection
            if abs(dx) >= abs(dyScreenUp) {
                dir = dx > 0 ? .east : .west
            } else {
                dir = dyScreenUp > 0 ? .north : .south
            }
            onSwipeCell?(startCoord, dir)
        } else {
            if let hitCoord = downCoord ?? BoardScene3DCoordinator.hitTestCell(in: self, at: endPt) {
                onTapCell?(hitCoord)
            }
        }
    }
}

private struct InteractiveBoardSCNView: NSViewRepresentable {
    let coordinator: BoardScene3DCoordinator
    let isInteractionLocked: Bool
    let onSwipeCell: (GridCoord, TumbleDirection) -> Void
    let onTapCell: (GridCoord) -> Void

    func makeNSView(context: Context) -> BoardHitSCNView {
        let view = BoardHitSCNView()
        view.scene = coordinator.scene
        view.pointOfView = coordinator.cameraNode
        view.rendersContinuously = true
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.isInteractionLocked = isInteractionLocked
        view.onSwipeCell = onSwipeCell
        view.onTapCell = onTapCell
        return view
    }

    func updateNSView(_ nsView: BoardHitSCNView, context: Context) {
        if nsView.scene !== coordinator.scene {
            nsView.scene = coordinator.scene
        }
        if nsView.pointOfView !== coordinator.cameraNode {
            nsView.pointOfView = coordinator.cameraNode
        }
        nsView.isInteractionLocked = isInteractionLocked
        nsView.onSwipeCell = onSwipeCell
        nsView.onTapCell = onTapCell
    }
}
#elseif canImport(UIKit)
@MainActor
private final class BoardTouchRecognizerBridge: NSObject {
    var isInteractionLocked: Bool = false
    var onTapCell: ((GridCoord) -> Void)?
    var onSwipeCell: ((GridCoord, TumbleDirection) -> Void)?
    weak var scnView: SCNView?
    private var panStartCoord: GridCoord?

    @objc func handleTap(_ gr: UITapGestureRecognizer) {
        guard !isInteractionLocked, gr.state == .ended, let view = scnView else { return }
        let pt = gr.location(in: view)
        if let coord = BoardScene3DCoordinator.hitTestCell(in: view, at: pt) {
            onTapCell?(coord)
        }
    }

    @objc func handlePan(_ gr: UIPanGestureRecognizer) {
        guard !isInteractionLocked, let view = scnView else { return }
        switch gr.state {
        case .began:
            let pt = gr.location(in: view)
            panStartCoord = BoardScene3DCoordinator.hitTestCell(in: view, at: pt)
        case .ended:
            defer { panStartCoord = nil }
            guard let startCoord = panStartCoord else { return }
            let t = gr.translation(in: view)
            let dist = hypot(t.x, t.y)
            guard dist >= 14.0 else {
                onTapCell?(startCoord)
                return
            }
            let dir: TumbleDirection
            if abs(t.x) >= abs(t.y) {
                dir = t.x > 0 ? .east : .west
            } else {
                dir = t.y < 0 ? .north : .south
            }
            onSwipeCell?(startCoord, dir)
        case .cancelled, .failed:
            panStartCoord = nil
        default:
            break
        }
    }
}

private struct InteractiveBoardSCNView: UIViewRepresentable {
    let coordinator: BoardScene3DCoordinator
    let isInteractionLocked: Bool
    let onSwipeCell: (GridCoord, TumbleDirection) -> Void
    let onTapCell: (GridCoord) -> Void

    func makeCoordinator() -> BoardTouchRecognizerBridge {
        BoardTouchRecognizerBridge()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = coordinator.scene
        view.pointOfView = coordinator.cameraNode
        view.rendersContinuously = true
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false

        context.coordinator.scnView = view
        context.coordinator.isInteractionLocked = isInteractionLocked
        context.coordinator.onSwipeCell = onSwipeCell
        context.coordinator.onTapCell = onTapCell

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(BoardTouchRecognizerBridge.handleTap(_:)))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(BoardTouchRecognizerBridge.handlePan(_:)))
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if uiView.scene !== coordinator.scene {
            uiView.scene = coordinator.scene
        }
        if uiView.pointOfView !== coordinator.cameraNode {
            uiView.pointOfView = coordinator.cameraNode
        }
        context.coordinator.scnView = uiView
        context.coordinator.isInteractionLocked = isInteractionLocked
        context.coordinator.onSwipeCell = onSwipeCell
        context.coordinator.onTapCell = onTapCell
    }
}
#endif

// MARK: - SwiftUI 3D Board View

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

    private func syncCoordinator() {
        coordinator.sync(
            engine: engine,
            selectedCoord: engine.selectedCoord,
            glowingCoords: engine.glowingMatchCoords,
            twistArmed: engine.twistArmed
        )
    }

    public var body: some View {
        let rows = engine.blueprint.rows
        let cols = engine.blueprint.cols

        InteractiveBoardSCNView(
            coordinator: coordinator,
            isInteractionLocked: isInteractionLocked,
            onSwipeCell: onSwipeCell,
            onTapCell: onTapCell
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    engine.twistArmed ? Color.orange.opacity(0.85) : Color.white.opacity(0.08),
                    lineWidth: engine.twistArmed ? 2.5 : 1.0
                )
                .allowsHitTesting(false)
        )
        .aspectRatio(CGFloat(cols) / CGFloat(rows), contentMode: .fit)
        .onAppear {
            syncCoordinator()
        }
        .onChange(of: engine.grid) { _, _ in
            syncCoordinator()
        }
        .onChange(of: engine.selectedCoord) { _, _ in
            syncCoordinator()
        }
        .onChange(of: engine.glowingMatchCoords) { _, _ in
            syncCoordinator()
        }
        .onChange(of: engine.twistArmed) { _, _ in
            syncCoordinator()
        }
        .onChange(of: engine.visualSkin) { _, _ in
            syncCoordinator()
        }
        .onChange(of: engine.cameraProjection) { _, _ in
            syncCoordinator()
        }
        .onChange(of: engine.appearanceMode) { _, _ in
            syncCoordinator()
        }
    }
}
