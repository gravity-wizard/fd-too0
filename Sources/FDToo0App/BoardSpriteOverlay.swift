//
//  BoardSpriteOverlay.swift
//  FD_too0
//
//  SpriteKit celebratory Chroma Surge & Cascade sparkle layer overlaid cleanly above the Pastel Dice Tray.
//

import SwiftUI
import SpriteKit

public final class CascadeSparkleScene: SKScene {
    public override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
    }

    public func emitBurst(
        normalizedX: CGFloat = 0.5,
        normalizedY: CGFloat = 0.5,
        count: Int = 18,
        durationScale: Double = 1.0
    ) {
        let origin = CGPoint(x: size.width * normalizedX, y: size.height * normalizedY)
        let palette: [SKColor] = [
            SKColor(red: 0.96, green: 0.72, blue: 0.68, alpha: 1.0),
            SKColor(red: 0.96, green: 0.88, blue: 0.62, alpha: 1.0),
            SKColor(red: 0.70, green: 0.90, blue: 0.80, alpha: 1.0),
            SKColor(red: 0.69, green: 0.85, blue: 0.95, alpha: 1.0)
        ]

        let dur = 0.52 * max(0.5, durationScale)
        for idx in 0..<count {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 3.5...6.5))
            spark.fillColor = palette[idx % palette.count]
            spark.strokeColor = .clear
            spark.position = origin
            addChild(spark)

            let angle = (CGFloat(idx) / CGFloat(count)) * (.pi * 2.0) + CGFloat.random(in: -0.2...0.2)
            let distance = CGFloat.random(in: 36...128)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            let move = SKAction.moveBy(x: dx, y: dy, duration: dur)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: dur)
            let scale = SKAction.scale(to: 0.2, duration: dur)
            spark.run(.sequence([.group([move, fade, scale]), .removeFromParent()]))
        }
    }
}
