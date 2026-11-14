//
//  TactileAudioHaptics.swift
//  FD_too0
//
//  Zero-asset procedural marimba/wood dice synthesizer (AVAudioEngine) + CoreHaptics / UIImpactFeedback.
//  Compiles cleanly on both iOS/iPadOS and macOS!
//

import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class TactileAudioHaptics {
    public static let shared = TactileAudioHaptics()
    public var soundEnabled: Bool = true
    public var hapticsEnabled: Bool = true

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isSetup = false

    private init() {}

    private func ensureAudioReady() {
        guard !isSetup else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        do {
            try audioEngine.start()
            playerNode.play()
            isSetup = true
        } catch {
            isSetup = false
        }
    }

    public func playTumble(pip: Int) {
        triggerHaptic(intensity: 0.55)
        guard soundEnabled else { return }
        // Warm wooden marimba clack scaled gently by pip (1..6)
        let pentatonic: [Double] = [293.66, 329.63, 392.00, 440.00, 523.25, 587.33]
        let freq = pentatonic[max(0, min(5, pip - 1))]
        synthesizeTone(frequency: freq, duration: 0.085, harmonicRatio: 2.75, amplitude: 0.24)
    }

    public func playCascadeMatch(chain: Int, isChromaSurge: Bool) {
        triggerHaptic(intensity: isChromaSurge ? 1.0 : 0.8)
        guard soundEnabled else { return }
        let baseFreq = 440.0 * pow(1.12246, Double(min(chain, 8)))
        synthesizeTone(frequency: baseFreq, duration: 0.18, harmonicRatio: 2.0, amplitude: 0.30)
        if isChromaSurge {
            synthesizeTone(frequency: baseFreq * 1.5, duration: 0.24, harmonicRatio: 3.0, amplitude: 0.22)
        }
    }

    public func playStageWin() {
        triggerHaptic(intensity: 1.0)
        guard soundEnabled else { return }
        synthesizeTone(frequency: 523.25, duration: 0.28, harmonicRatio: 2.0, amplitude: 0.30)
    }

    private func triggerHaptic(intensity: Double) {
        guard hapticsEnabled else { return }
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: intensity > 0.75 ? .rigid : .medium)
        generator.impactOccurred(intensity: CGFloat(intensity))
        #endif
    }

    private func synthesizeTone(frequency: Double, duration: Double, harmonicRatio: Double, amplitude: Float) {
        ensureAudioReady()
        guard isSetup else { return }
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return }

        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let env = exp(-t * 26.0)
            let fundamental = sin(2.0 * .pi * frequency * t)
            let overtone = 0.35 * sin(2.0 * .pi * (frequency * harmonicRatio) * t) * exp(-t * 48.0)
            channel[i] = Float((fundamental + overtone) * env) * amplitude
        }
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
    }
}
