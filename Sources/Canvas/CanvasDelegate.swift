import Foundation
import CoreGraphics

public protocol CanvasDelegate: AnyObject {

    func canvasDragHitTest(at position: CGPoint) -> CanvasDrag?
    
    func canvasDragGetPosition(_ drag: CanvasDrag) -> CGPoint
    func canvasDragSetPosition(_ drag: CanvasDrag, to position: CGPoint)

    func canvasDragStarted(_ drag: CanvasDrag, at position: CGPoint)
    func canvasDragReleased(_ drag: CanvasDrag, at position: CGPoint)
    func canvasDragWillEnd(_ drag: CanvasDrag, at position: CGPoint)
    func canvasDragDidEnd(_ drag: CanvasDrag, at position: CGPoint)
    
}
