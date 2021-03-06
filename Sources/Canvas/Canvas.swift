import Foundation
import SwiftUI

public class Canvas<FrontContent: View, BackContent: View>: ObservableObject {
    
    let snapGridToAngle: Angle?
    let snapContentToGrid: CanvasSnapGrid?
    
    @Published public var frameContentList: [CanvasFrameContent<FrontContent, BackContent>]
    
    @Published public var offset: CGPoint = .zero
    @Published public var scale: CGFloat = 1.0
    @Published public var angle: Angle = .zero
    public var coordinate: CanvasCoordinate {
        CanvasCoordinate(offset: offset, scale: scale, angle: angle)
    }
    
    @Published var interactions: [CanvasInteraction] = []
    @Published var panInteraction: CanvasInteraction? = nil
    @Published var pinchInteraction: (CanvasInteraction, CanvasInteraction)? = nil
    @Published var dragInteractions: [UUID: CanvasInteraction] = [:]
    
    @Published var keyboardFlags: Set<CanvasKeyboardFlag> = []
    @Published var mouseLocation: CGPoint? = nil

    public init(snapGridToAngle: Angle? = nil,
                snapContentToGrid: CanvasSnapGrid? = nil,
                frameContentList: [CanvasFrameContent<FrontContent, BackContent>] = []) {
        self.snapGridToAngle = snapGridToAngle
        self.snapContentToGrid = snapContentToGrid
        self.frameContentList = frameContentList
    }
    
}
