import Foundation
import CoreGraphics
import CoreGraphicsExtensions
import SwiftUI

public struct CanvasFrameContent<FontContent: View, BackContent: View>: Identifiable {
    
    public let id: UUID
    
    public var frame: CGRect
    public var center: CGPoint {
        get { frame.origin + frame.size / 2.0 }
        set { frame.origin = newValue - frame.size / 2.0 }
    }
    
    let frontContent: (CanvasCoordinate) -> (FontContent)
    let backContent: (CanvasCoordinate) -> (BackContent)
    
    public enum Shape {
        case rectangle
        case circle
    }
    let shape: Shape

    public init(id: UUID,
                shape: Shape = .rectangle,
                frame: CGRect,
                front: @escaping (CanvasCoordinate) -> (FontContent),
                back: @escaping (CanvasCoordinate) -> (BackContent)) {
        self.id = id
        self.shape = shape
        self.frame = frame
        frontContent = front
        backContent = back
    }
    
}

extension View {
    
    func canvasFrame<FC: View, BC: View>(content frameContent: CanvasFrameContent<FC, BC>, scale: CGFloat) -> some View {
        self.frame(width: frameContent.frame.width * scale,
                   height: frameContent.frame.height * scale)
            .offset(x: frameContent.frame.origin.x * scale,
                    y: frameContent.frame.origin.y * scale)
    }
    
}
