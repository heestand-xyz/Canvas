import Foundation
import CoreGraphics
#if os(iOS)
import UIKit
#endif

public struct CanvasAnimation {
    
    public enum AnimationEase {
        case linear
        case easeIn
        case easeInOut
        case easeOut
    }
    
    public static func animate(for duration: CGFloat, ease: AnimationEase = .linear, loop: @escaping (CGFloat) -> (), done: (() -> ())? = nil) {
        animate(for: duration, ease: ease) { fraction, _ in
            loop(fraction)
        } done: {
            done?()
        }
    }
    
    public static func animate(for duration: CGFloat, ease: AnimationEase = .linear, loop: @escaping (CGFloat, CGFloat) -> (), done: (() -> ())? = nil) {
        let startTime = Date()
        #if os(macOS)
        let fps: Int = 60
        #else
        let fps: Int = UIScreen.main.maximumFramesPerSecond
        #endif
        loop(0.0, 0.0)
        var lastFraction: CGFloat = 0.0
        RunLoop.current.add(Timer(timeInterval: 1.0 / Double(fps), repeats: true, block: { t in
            let elapsedTime = CGFloat(-startTime.timeIntervalSinceNow)
            let fraction = min(elapsedTime / duration, 1.0)
            var easeFraction = fraction
            switch ease {
            case .linear: break
            case .easeIn: easeFraction = cos(fraction * .pi / 2 - .pi) + 1
            case .easeInOut: easeFraction = cos(fraction * .pi - .pi) / 2 + 0.5
            case .easeOut: easeFraction = cos(fraction * .pi / 2 - .pi / 2)
            }
            if fraction < 1.0 {
                let relativeFraction: CGFloat = easeFraction - lastFraction
                loop(easeFraction, relativeFraction)
                lastFraction = easeFraction
            } else {
                let relativeFraction: CGFloat = 1.0 - lastFraction
                loop(1.0, relativeFraction)
                done?()
                t.invalidate()
            }
        }), forMode: .common)
    }
    
}
