/*
 Modified for Cosee: fluid frame rates and continuous animation phase across load changes.
 RunnerLayer.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/08.
 Copyright 2026 Kyome22 (Takuto Nakamura)

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import AppKit

final class RunnerLayer: CALayer {
    private var gap: CGFloat
    private var width = CGFloat.zero
    private let maskLayer = CALayer()
    private var keyFrameAnimation = CAKeyframeAnimation(keyPath: "contents")
    private(set) var frameRevision = 0
    private(set) var lastSpeedPhaseError: Double = 0
    private(set) var lastFramePhaseError: Double = 0

    init(gap: CGFloat) {
        self.gap = gap
        super.init()
        contentsGravity = CALayerContentsGravity.left
        masksToBounds = true
        contentsScale = 2.0
        maskLayer.frame = bounds
        keyFrameAnimation.calculationMode = .discrete
        keyFrameAnimation.repeatCount = .infinity
        keyFrameAnimation.isRemovedOnCompletion = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setFrames(_ frames: [NSImage], _ isTemplate: Bool, frameRate: Double = 2) {
        let now = CACurrentMediaTime()
        let previousLayer = mask ?? self
        let previousSpeed = previousLayer.speed
        let previousPhase = phase(at: now)
        let size = frames.first?.alignmentRect.size ?? .zero
        keyFrameAnimation.values = frames
        keyFrameAnimation.duration = Double(frames.count) / max(1, frameRate)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        removeAllAnimations()
        maskLayer.removeAllAnimations()
        frame = CGRect(origin: CGPoint(x: gap, y: 2.0), size: size)
        maskLayer.frame = CGRect(origin: .zero, size: size)
        if isTemplate {
            maskLayer.speed = previousSpeed
            maskLayer.timeOffset = .zero
            maskLayer.beginTime = .zero
            timeOffset = .zero
            beginTime = .zero
            speed = 1.0
            mask = maskLayer
        } else {
            speed = previousSpeed
            timeOffset = .zero
            beginTime = .zero
            mask = nil
        }
        let animatedLayer = mask ?? self
        keyFrameAnimation.beginTime =
            animatedLayer.convertTime(now, from: nil)
            - previousPhase * keyFrameAnimation.duration
        animatedLayer.add(keyFrameAnimation, forKey: "running")
        lastFramePhaseError = abs(phase(at: now) - previousPhase)
        frameRevision += 1
        CATransaction.commit()
    }

    func setColor(_ tintColor: CGColor, _ isTemplate: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundColor = isTemplate ? tintColor : nil
        CATransaction.commit()
    }

    func setSpeed(_ speed: Float) {
        let now = CACurrentMediaTime()
        let animatedLayer = mask ?? self
        let previousTime = animatedLayer.convertTime(now, from: nil)
        let parentTime =
            if mask != nil {
                convertTime(now, from: nil)
            } else {
                superlayer?.convertTime(now, from: nil) ?? now
            }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        animatedLayer.timeOffset = previousTime
        animatedLayer.beginTime = parentTime
        animatedLayer.speed = speed
        lastSpeedPhaseError = abs(animatedLayer.convertTime(now, from: nil) - previousTime)
        CATransaction.commit()
    }

    private func phase(at time: CFTimeInterval) -> Double {
        guard keyFrameAnimation.duration > 0, (mask ?? self).animation(forKey: "running") != nil else { return 0 }
        let elapsed = (mask ?? self).convertTime(time, from: nil) - keyFrameAnimation.beginTime
        return max(0, elapsed.truncatingRemainder(dividingBy: keyFrameAnimation.duration) / keyFrameAnimation.duration)
    }
}
