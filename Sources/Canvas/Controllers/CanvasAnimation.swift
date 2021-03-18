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
        let startTime = Date()
        #if os(iOS)
        let fps: Int = UIScreen.main.maximumFramesPerSecond
        #else
        let fps: Int = 60
        #endif
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
            loop(easeFraction)
            if fraction == 1.0 {
                done?()
                t.invalidate()
            }
        }), forMode: .common)
    }
    
}
