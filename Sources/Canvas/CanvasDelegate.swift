import Foundation
import CoreGraphics

public protocol CanvasDelegate: AnyObject {

    func canvasDragHitTest(at position: CGPoint, coordinate: CanvasCoordinate) -> CanvasDrag?
    
    func canvasDragGetPosition(_ drag: CanvasDrag, coordinate: CanvasCoordinate) -> CGPoint
    func canvasDragSetPosition(_ drag: CanvasDrag, to position: CGPoint, coordinate: CanvasCoordinate)

    func canvasDragStarted(_ drag: CanvasDrag, at position: CGPoint, coordinate: CanvasCoordinate)
    func canvasDragReleased(_ drag: CanvasDrag, at position: CGPoint, coordinate: CanvasCoordinate)
    func canvasDragWillEnd(_ drag: CanvasDrag, at position: CGPoint, coordinate: CanvasCoordinate)
    func canvasDragDidEnd(_ drag: CanvasDrag, at position: CGPoint, coordinate: CanvasCoordinate)
    
    func canvasMoveStarted(at position: CGPoint, viaScroll: Bool, coordinate: CanvasCoordinate)
    func canvasMoveEnded(at position: CGPoint, viaScroll: Bool, coordinate: CanvasCoordinate)
    
}
