import Foundation
import CoreGraphics
import SwiftUI

public struct FrameContent<Content: View>: Identifiable {
    
    public let id: UUID
    let canvasFrame: CGRect
    let content: () -> (Content)
    
    public init(id: UUID, canvasFrame: CGRect, content: @escaping () -> (Content)) {
        self.id = id
        self.canvasFrame = canvasFrame
        self.content = content
    }
    
}
