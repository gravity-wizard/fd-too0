//
//  SceneKitDieBuilder.swift
//  FD_too0 (Joe SmoLLey 3D Spatial Deck)
//
//  Hardware-Accelerated SceneKit + Metal PBR 3D Die Factory & Texture Synthesizer.
//  Renders real beveled 6-face RH000 dice across all 3 Visual Skins:
//    1) Modeled 3D Recessed Pips (`1..6`)
//    2) Twisted 45° (`4v`) Numerals pointing into chirality vertices V_123 and V_654
//    3) Royal 6-Face FaceCards (`A♠, K♥, Q♦, 10♣, J♠ One-Eyed, J♦ Two-Eyed`)
//  Plus glowing metallic Axle-Lock Skewers (`[1-6]`, `[2-5]`, `[3-4]`)!
//

import Foundation
import SceneKit
import CoreGraphics
import CoreText
import simd
#if canImport(FDToo0Core)
import FDToo0Core
#endif

#if os(macOS)
import AppKit
public typealias PlatformColor = NSColor
#elseif canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
#endif

public enum SceneKitDieBuilder {
    private static var textureCache: [String: CGImage] = [:]
    private static let cacheLock = NSLock()

    public static func makeColor(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1.0) -> PlatformColor {
        PlatformColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }

    public static func simdQuat(from q: Quat) -> simd_quatf {
        simd_quatf(ix: Float(q.x), iy: Float(q.y), iz: Float(q.z), r: Float(q.w))
    }

    /// Canonical local outward face normals (+X=3, -X=4, +Y=1, -Y=6, +Z=2, -Z=5).
    public static let localFaces: [(pip: Int, normal: Vec3)] = [
        (1, Vec3( 0,  1,  0)),
        (6, Vec3( 0, -1,  0)),
        (2, Vec3( 0,  0,  1)),
        (5, Vec3( 0,  0, -1)),
        (3, Vec3( 1,  0,  0)),
        (4, Vec3(-1,  0,  0))
    ]

    /// Builds a complete 3D die node (`side = 1.40` default) whose `.simdOrientation` can be driven
    /// directly by `DieOrientation.unitQuaternion`.
    public static func makeDieNode(
        pastelHue: PastelHueFamily,
        appearance: BoardAppearanceMode,
        skin: DieVisualSkin,
        axleLock: AxleLockAxis = .free24,
        conjugateArchetype: ConjugateCubeArchetype? = nil,
        isSelected: Bool = false,
        isMatchGlowing: Bool = false,
        frostLayers: Int = 0,
        isChained: Bool = false
    ) -> SCNNode {
        let root = SCNNode()
        let tokens = pastelHue.rgbTokens(for: appearance)

        // 1. Beveled Porcelain Body Cube
        let box = SCNBox(width: 1.42, height: 1.42, length: 1.42, chamferRadius: 0.21)
        let bodyMat = SCNMaterial()
        bodyMat.lightingModel = .physicallyBased
        bodyMat.diffuse.contents = makeColor(tokens.body.0, tokens.body.1, tokens.body.2)
        bodyMat.roughness.contents = 0.28
        bodyMat.metalness.contents = 0.04
        box.materials = [bodyMat]
        let bodyNode = SCNNode(geometry: box)
        bodyNode.name = "die_body"
        root.addChildNode(bodyNode)
        updateDieHighlight(node: root, isSelected: isSelected, isMatchGlowing: isMatchGlowing)

        // 2. Populate all 6 faces according to active skin (or 4-number conjugate cube override)
        if skin == .modeledPips && conjugateArchetype == nil {
            attachModeled3DPips(to: root, pipRGB: tokens.pip)
        } else {
            attachOrientedFaceDecals(
                to: root,
                skin: skin,
                conjugateArchetype: conjugateArchetype,
                pipRGB: tokens.pip,
                bevelRGB: tokens.bevel
            )
        }

        // 3. Optional Glowing Metallic Axle-Lock Skewer (`[1-6]`, `[2-5]`, `[3-4]`)
        if axleLock != .free24 {
            let skewer = makeAxleSkewerNode(for: axleLock)
            root.addChildNode(skewer)
        }

        // 4. Optional Frosted Ice Shell (`FD_too0` World 3+)
        if frostLayers > 0 {
            let iceBox = SCNBox(width: 1.52, height: 1.52, length: 1.52, chamferRadius: 0.23)
            let iceMat = SCNMaterial()
            iceMat.lightingModel = .physicallyBased
            iceMat.diffuse.contents = makeColor(0.55, 0.90, 1.0, 0.34)
            iceMat.transparency = 0.42
            iceMat.roughness.contents = 0.08
            iceBox.materials = [iceMat]
            root.addChildNode(SCNNode(geometry: iceBox))
        }

        // 5. Optional Chain Band (`FD_too0` World 5+)
        if isChained {
            let torus = SCNTorus(ringRadius: 0.84, pipeRadius: 0.065)
            let brass = SCNMaterial()
            brass.lightingModel = .physicallyBased
            brass.diffuse.contents = makeColor(0.82, 0.62, 0.24)
            brass.metalness.contents = 0.88
            brass.roughness.contents = 0.22
            torus.materials = [brass]
            root.addChildNode(SCNNode(geometry: torus))
        }

        return root
    }

    /// Updates selection and cascade-match emission in place without destroying or recreating the SCNNode,
    /// preserving continuous 3D quaternion tumble & 180° Twist somersault animations.
    public static func updateDieHighlight(
        node: SCNNode,
        isSelected: Bool,
        isMatchGlowing: Bool
    ) {
        guard let bodyNode = node.childNode(withName: "die_body", recursively: false),
              let mat = bodyNode.geometry?.firstMaterial else { return }
        if isMatchGlowing {
            mat.emission.contents = makeColor(0.95, 0.78, 0.25, 1.0)
        } else if isSelected {
            mat.emission.contents = makeColor(0.42, 0.34, 0.08, 1.0)
        } else {
            mat.emission.contents = makeColor(0.0, 0.0, 0.0, 1.0)
        }
    }

    // MARK: - Skin 1: Sculpted 3D Recessed Casino Pips (RH000 Chirality)

    private static func attachModeled3DPips(to dieNode: SCNNode, pipRGB: (Double, Double, Double)) {
        let pipGeo = SCNSphere(radius: 0.115)
        pipGeo.segmentCount = 16

        let inkMat = SCNMaterial()
        inkMat.lightingModel = .physicallyBased
        inkMat.diffuse.contents = makeColor(pipRGB.0, pipRGB.1, pipRGB.2)
        inkMat.roughness.contents = 0.35

        let crimsonMat = SCNMaterial()
        crimsonMat.lightingModel = .physicallyBased
        crimsonMat.diffuse.contents = makeColor(0.78, 0.14, 0.16)
        crimsonMat.roughness.contents = 0.28

        let d: Float = 0.34
        let s: Float = 0.695

        func addPip(_ x: Float, _ y: Float, _ z: Float, crimson: Bool = false) {
            let g = pipGeo.copy() as! SCNSphere
            g.materials = [crimson ? crimsonMat : inkMat]
            let n = SCNNode(geometry: g)
            n.simdPosition = SIMD3<Float>(x, y, z)
            dieNode.addChildNode(n)
        }

        // 1 on +Y (Crimson Ace)
        addPip(0, s, 0, crimson: true)
        // 6 on -Y: two 3-pip rails along X = +-d with Z in {-d, 0, +d} so rails point toward 2(+Z)/5(-Z)?
        // Wait: in DieOrientation.swift, 6's two 3-pip rails point toward 3(+X) & 4(-X) — meaning middle pips sit on 2(+Z) & 5(-Z) edges!
        for sz: Float in [-d, d] {
            for sx: Float in [-d, 0, d] {
                addPip(sx, -s, sz)
            }
        }
        // 2 on +Z (South): corners toward (1,4)=(-X,+Y) and (6,3)=(+X,-Y)
        addPip(-d, d, s)
        addPip(d, -d, s)
        // 5 on -Z (North)
        for sx: Float in [-d, d] {
            for sy: Float in [-d, d] {
                addPip(sx, sy, -s)
            }
        }
        addPip(0, 0, -s)
        // 3 on +X (East): diagonal from (6,2)=(-Y,+Z) through (0,0) to (1,5)=(+Y,-Z)
        addPip(s, -d, d)
        addPip(s, 0, 0)
        addPip(s, d, -d)
        // 4 on -X (West, Crimson Four)
        for sy: Float in [-d, d] {
            for sz: Float in [-d, d] {
                addPip(-s, sy, sz, crimson: true)
            }
        }
    }

    // MARK: - Skins 2 & 3: 45° Vertex-Pointing Twisted Numerals & Royal FaceCards

    private static func attachOrientedFaceDecals(
        to dieNode: SCNNode,
        skin: DieVisualSkin,
        conjugateArchetype: ConjugateCubeArchetype?,
        pipRGB: (Double, Double, Double),
        bevelRGB: (Double, Double, Double)
    ) {
        let surfaceOffset = 0.716
        for entry in localFaces {
            let pip = entry.pip
            let n = entry.normal
            // Target cube chirality vertex: V_123 (+1,+1,+1) for {1,2,3}, V_654 (-1,-1,-1) for {4,5,6}
            let vTarget = LearnedGeometryOracle.localChiralityVertex(forPip: pip)
            // In-plane diagonal unit vector pointing straight toward the target chirality corner
            let proj = vTarget - (n * vTarget.dot(n))
            let uDiag = proj.normalized
            // Construct right-handed plane basis (xPlane, yPlane, zPlane=n) where (xPlane + yPlane)/sqrt(2) == uDiag!
            let xPlane = ((uDiag + uDiag.cross(n)) * (0.5.squareRoot())).normalized
            let yPlane = n.cross(xPlane).normalized

            let qPlane = quaternionFromBasis(xAxis: xPlane, yAxis: yPlane, zAxis: n)

            let plane = SCNPlane(width: 1.04, height: 1.04)
            plane.cornerRadius = 0.14
            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased
            mat.roughness.contents = 0.30
            mat.diffuse.contents = cachedDecalImage(
                pip: pip,
                skin: skin,
                conjugateArchetype: conjugateArchetype,
                inkRGB: pipRGB,
                bgRGB: bevelRGB
            )
            plane.materials = [mat]

            let decalNode = SCNNode(geometry: plane)
            let pos = n * surfaceOffset
            decalNode.simdPosition = SIMD3<Float>(Float(pos.x), Float(pos.y), Float(pos.z))
            decalNode.simdOrientation = simdQuat(from: qPlane)
            dieNode.addChildNode(decalNode)
        }
    }

    private static func quaternionFromBasis(xAxis c0: Vec3, yAxis c1: Vec3, zAxis c2: Vec3) -> Quat {
        let r00 = c0.x, r10 = c0.y, r20 = c0.z
        let r01 = c1.x, r11 = c1.y, r21 = c1.z
        let r02 = c2.x, r12 = c2.y, r22 = c2.z
        let tr = r00 + r11 + r22
        let qx, qy, qz, qw: Double
        if tr > 0.0 {
            let s = (tr + 1.0).squareRoot() * 2.0
            qw = 0.25 * s; qx = (r21 - r12) / s; qy = (r02 - r20) / s; qz = (r10 - r01) / s
        } else if r00 > r11 && r00 > r22 {
            let s = (1.0 + r00 - r11 - r22).squareRoot() * 2.0
            qw = (r21 - r12) / s; qx = 0.25 * s; qy = (r01 + r10) / s; qz = (r02 + r20) / s
        } else if r11 > r22 {
            let s = (1.0 + r11 - r00 - r22).squareRoot() * 2.0
            qw = (r02 - r20) / s; qx = (r01 + r10) / s; qy = 0.25 * s; qz = (r12 + r21) / s
        } else {
            let s = (1.0 + r22 - r00 - r11).squareRoot() * 2.0
            qw = (r10 - r01) / s; qx = (r02 + r20) / s; qy = (r12 + r21) / s; qz = 0.25 * s
        }
        return Quat(x: qx, y: qy, z: qz, w: qw).normalized
    }

    private static func cachedDecalImage(
        pip: Int,
        skin: DieVisualSkin,
        conjugateArchetype: ConjugateCubeArchetype?,
        inkRGB: (Double, Double, Double),
        bgRGB: (Double, Double, Double)
    ) -> CGImage? {
        let archKey = conjugateArchetype?.rawValue ?? "std"
        let key = "\(pip)-\(skin.rawValue)-\(archKey)-\(Int(inkRGB.0 * 100))"
        cacheLock.lock()
        if let hit = textureCache[key] {
            cacheLock.unlock()
            return hit
        }
        cacheLock.unlock()

        let size = 256
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let w = CGFloat(size)
        // Soft ivory/pastel card inset background
        ctx.setFillColor(red: CGFloat(bgRGB.0), green: CGFloat(bgRGB.1), blue: CGFloat(bgRGB.2), alpha: 0.96)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: w))

        // Subtle inner parlour frame
        ctx.setStrokeColor(red: CGFloat(inkRGB.0), green: CGFloat(inkRGB.1), blue: CGFloat(inkRGB.2), alpha: 0.28)
        ctx.setLineWidth(6)
        ctx.stroke(CGRect(x: 14, y: 14, width: w - 28, height: w - 28))

        // Chirality Corner Chevron in Top-Right (+X, +Y in CGContext coordinates!)
        // Points straight into V_123 (for pips 1..3) or V_654 (for pips 4..6)!
        let isPrimaryTriad = pip <= 3
        ctx.setFillColor(
            red: isPrimaryTriad ? 0.86 : 0.16,
            green: isPrimaryTriad ? 0.52 : 0.56,
            blue: isPrimaryTriad ? 0.14 : 0.78,
            alpha: 0.92
        )
        ctx.beginPath()
        ctx.move(to: CGPoint(x: w - 18, y: w - 18))
        ctx.addLine(to: CGPoint(x: w - 58, y: w - 22))
        ctx.addLine(to: CGPoint(x: w - 22, y: w - 58))
        ctx.closePath()
        ctx.fillPath()

        // Main Glyph Text (rotated -45° so its crown points toward Top-Right (+X, +Y)!)
        let displayNum = conjugateArchetype?.mappedFourNumber(forRawPip: pip) ?? pip
        let mainText: String
        let subText: String
        let textColor: CGColor

        if skin == .royalFaceCards && conjugateArchetype == nil {
            let fc = FaceCardFace(pip: pip)
            mainText = "\(fc.rankLabel)\(fc.suitSymbol)"
            subText = fc.isOneEyedJack ? "1-EYE" : (fc.isTwoEyedJack ? "2-EYE★" : "")
            textColor = fc.isRedSuit
                ? makeColor(0.78, 0.13, 0.18, 1.0).cgColor
                : makeColor(0.10, 0.12, 0.18, 1.0).cgColor
        } else {
            mainText = "\(displayNum)"
            subText = (displayNum == 6 || displayNum == 9) ? "•" : ""
            textColor = makeColor(inkRGB.0, inkRGB.1, inkRGB.2, 1.0).cgColor
        }

        ctx.saveGState()
        ctx.translateBy(x: w * 0.5, y: w * 0.5)
        // In CGContext (+Y up, +X right), rotating by -45° (-pi/4) tilts +Y (head of numeral) into (+X, +Y) Top-Right!
        ctx.rotate(by: -.pi * 0.25)
        drawCenteredCoreText(mainText, fontSize: skin == .royalFaceCards ? 84 : 118, color: textColor, at: CGPoint(x: 0, y: subText.isEmpty ? 0 : 14), in: ctx)
        if !subText.isEmpty {
            drawCenteredCoreText(subText, fontSize: 30, color: textColor, at: CGPoint(x: 0, y: -56), in: ctx)
        }
        ctx.restoreGState()

        guard let img = ctx.makeImage() else { return nil }
        cacheLock.lock()
        textureCache[key] = img
        cacheLock.unlock()
        return img
    }

    private static func drawCenteredCoreText(
        _ string: String,
        fontSize: CGFloat,
        color: CGColor,
        at center: CGPoint,
        in ctx: CGContext
    ) {
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
        ]
        let attrStr = NSAttributedString(string: string, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        ctx.textPosition = CGPoint(
            x: center.x - bounds.midX,
            y: center.y - bounds.midY
        )
        CTLineDraw(line, ctx)
    }

    // MARK: - 3D Gravity Wizard Pin-Axles (`[1-6]`, `[2-5]`, `[3-4]`)

    public static func makeAxleSkewerNode(for axle: AxleLockAxis) -> SCNNode {
        let holder = SCNNode()

        // Starlight Royal Indigo Wizard Robe & Hat material
        let wizardRobeMat = SCNMaterial()
        wizardRobeMat.lightingModel = .physicallyBased
        wizardRobeMat.diffuse.contents = makeColor(0.24, 0.18, 0.62)
        wizardRobeMat.metalness.contents = 0.35
        wizardRobeMat.roughness.contents = 0.28
        wizardRobeMat.emission.contents = makeColor(0.07, 0.04, 0.20)

        // Enchanted Gold Hatband, Star-Tip & Internal Axle Shaft
        let goldMat = SCNMaterial()
        goldMat.lightingModel = .physicallyBased
        goldMat.diffuse.contents = makeColor(0.95, 0.74, 0.22)
        goldMat.metalness.contents = 0.90
        goldMat.roughness.contents = 0.16
        goldMat.emission.contents = makeColor(0.26, 0.17, 0.02)

        // Flowing Silver-White Wizard Beard
        let beardMat = SCNMaterial()
        beardMat.lightingModel = .physicallyBased
        beardMat.diffuse.contents = makeColor(0.95, 0.96, 0.99)
        beardMat.roughness.contents = 0.42

        // Warm Wizard Face & Cute Round Nose
        let skinMat = SCNMaterial()
        skinMat.lightingModel = .physicallyBased
        skinMat.diffuse.contents = makeColor(0.96, 0.80, 0.67)
        skinMat.roughness.contents = 0.45

        // Internal gold axle rod connecting the two opposite Gravity Wizards
        let rod = SCNCylinder(radius: 0.09, height: 1.48)
        rod.materials = [goldMat]
        holder.addChildNode(SCNNode(geometry: rod))

        func makeSingleGravityWizard() -> SCNNode {
            let wiz = SCNNode()

            // 1. Robe Collar & Shoulders emerging from cube face (y = 0.70 .. 0.84)
            let robeGeo = SCNCone(topRadius: 0.145, bottomRadius: 0.265, height: 0.16)
            robeGeo.materials = [wizardRobeMat]
            let robeNode = SCNNode(geometry: robeGeo)
            robeNode.simdPosition = SIMD3<Float>(0, 0.77, 0)
            wiz.addChildNode(robeNode)

            // 2. Wizard Head (y = 0.88)
            let headGeo = SCNSphere(radius: 0.138)
            headGeo.materials = [skinMat]
            let headNode = SCNNode(geometry: headGeo)
            headNode.simdPosition = SIMD3<Float>(0, 0.88, 0.01)
            wiz.addChildNode(headNode)

            // 3. Lush Flowing Pointed Wizard Beard cascading down front (+Z) + Cute Nose
            let beardGeo = SCNCone(topRadius: 0.025, bottomRadius: 0.105, height: 0.20)
            beardGeo.materials = [beardMat]
            let beardNode = SCNNode(geometry: beardGeo)
            beardNode.simdPosition = SIMD3<Float>(0, 0.80, 0.125)
            beardNode.simdEulerAngles = SIMD3<Float>(.pi * 0.82, 0, 0)
            wiz.addChildNode(beardNode)

            let noseGeo = SCNSphere(radius: 0.044)
            noseGeo.materials = [skinMat]
            let noseNode = SCNNode(geometry: noseGeo)
            noseNode.simdPosition = SIMD3<Float>(0, 0.895, 0.145)
            wiz.addChildNode(noseNode)

            // 4. Wide Flared Wizard's Hat Brim (y = 0.945) + Golden Hatband Torus
            let brimLower = SCNCone(topRadius: 0.245, bottomRadius: 0.145, height: 0.045)
            brimLower.materials = [wizardRobeMat]
            let brimLowerNode = SCNNode(geometry: brimLower)
            brimLowerNode.simdPosition = SIMD3<Float>(0, 0.935, 0.01)
            wiz.addChildNode(brimLowerNode)

            let brimUpper = SCNCone(topRadius: 0.175, bottomRadius: 0.245, height: 0.035)
            brimUpper.materials = [wizardRobeMat]
            let brimUpperNode = SCNNode(geometry: brimUpper)
            brimUpperNode.simdPosition = SIMD3<Float>(0, 0.972, 0.01)
            wiz.addChildNode(brimUpperNode)

            let bandGeo = SCNTorus(ringRadius: 0.162, pipeRadius: 0.026)
            bandGeo.materials = [goldMat]
            let bandNode = SCNNode(geometry: bandGeo)
            bandNode.simdPosition = SIMD3<Float>(0, 0.992, 0.01)
            wiz.addChildNode(bandNode)

            // 5. Tall Pointed Wizard's Hat Crown + Whimsical Bent Tip + Golden Star Orb!
            let crownGeo = SCNCone(topRadius: 0.078, bottomRadius: 0.168, height: 0.22)
            crownGeo.materials = [wizardRobeMat]
            let crownNode = SCNNode(geometry: crownGeo)
            crownNode.simdPosition = SIMD3<Float>(0, 1.095, 0.015)
            wiz.addChildNode(crownNode)

            let tipConeGeo = SCNCone(topRadius: 0.036, bottomRadius: 0.078, height: 0.13)
            tipConeGeo.materials = [wizardRobeMat]
            let tipConeNode = SCNNode(geometry: tipConeGeo)
            tipConeNode.simdPosition = SIMD3<Float>(0, 1.255, 0.045)
            tipConeNode.simdEulerAngles = SIMD3<Float>(-0.34, 0, 0)
            wiz.addChildNode(tipConeNode)

            let starOrbGeo = SCNSphere(radius: 0.042)
            starOrbGeo.materials = [goldMat]
            let starOrbNode = SCNNode(geometry: starOrbGeo)
            starOrbNode.simdPosition = SIMD3<Float>(0, 1.318, 0.068)
            wiz.addChildNode(starOrbNode)

            return wiz
        }

        let topWizard = makeSingleGravityWizard()
        holder.addChildNode(topWizard)

        let bottomWizard = makeSingleGravityWizard()
        bottomWizard.simdEulerAngles = SIMD3<Float>(.pi, 0, 0)
        holder.addChildNode(bottomWizard)

        switch axle {
        case .free24:
            break
        case .pin16:
            holder.simdEulerAngles = SIMD3<Float>(0, 0, 0)
        case .pin25:
            holder.simdEulerAngles = SIMD3<Float>(.pi * 0.5, 0, 0)
        case .pin34:
            holder.simdEulerAngles = SIMD3<Float>(0, 0, .pi * 0.5)
        }
        return holder
    }
}
