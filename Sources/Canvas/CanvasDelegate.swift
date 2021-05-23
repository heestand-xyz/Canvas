import Foundation
import CoreGraphics

public protocol CanvasDelegate: AnyObject {

    func canvasDragHitTest(at position: CGPoint, coordinate: CanvasCoordinate) -> CanvasDrag?
    
    func canvasDragGetPosition(_ drag: CanvasDrag, coordinate: CanvasCoordinate) -> CGPoint
    func canvasDragSetPosition(_ drag: CanvasDrag, to position: CGPoint, coordinate: CanvasCoordinate)

    func canvasDragStarted(_ drag: CanvasDrag, at position: CGPoint, keyboardFlags: Set<CanvasKeyboardFlag>, coordinate: CanvasCoordinate)
    func canvasDragReleased(_ drag: CanvasDrag, at position: CGPoint, keyboardFlags: Set<CanvasKeyboardFlag>, coordinate: CanvasCoordinate)
    func canvasDragWillEnd(_ drag: CanvasDrag, at position: CGPoint, coordinate: CanvasCoordinate)
    func canvasDragDidEnd(_ drag: CanvasDrag, at position: CGPoint, coordinate: CanvasCoordinate)
    
    func canvasMoveStarted(at position: CGPoint, viaScroll: Bool, keyboardFlags: Set<CanvasKeyboardFlag>, coordinate: CanvasCoordinate)
    func canvasMoveEnded(at position: CGPoint, viaScroll: Bool, coordinate: CanvasCoordinate)
    
    #if os(macOS)
    func canvasSelectionStarted(at position: CGPoint, info: CanvasInteractionInfo, keyboardFlags: Set<CanvasKeyboardFlag>, coordinate: CanvasCoordinate)
    func canvasSelectionChanged(to position: CGPoint, coordinate: CanvasCoordinate)
    func canvasSelectionEnded(at position: CGPoint, info: CanvasInteractionInfo, keyboardFlags: Set<CanvasKeyboardFlag>, coordinate: CanvasCoordinate)
    #endif
    
}
