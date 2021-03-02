import Foundation
import CoreGraphics
import SwiftUI

public struct CanvasFrameContent<FontContent: View, BackContent: View>: Identifiable {
    
    public let id: UUID
    
    var frame: CGRect
    
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
