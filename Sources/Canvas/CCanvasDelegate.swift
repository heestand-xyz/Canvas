import Foundation
import CoreGraphics

public protocol CCanvasDelegate: AnyObject {

    func canvasDragHitTest(at position: CGPoint, coordinate: CCanvasCoordinate) -> CCanvasDrag?
    
    func canvasDragGetPosition(_ drag: CCanvasDrag, coordinate: CCanvasCoordinate) -> CGPoint
    func canvasDragSetPosition(_ drag: CCanvasDrag, to position: CGPoint, coordinate: CCanvasCoordinate)

    func canvasDragStarted(_ drag: CCanvasDrag, at position: CGPoint, info: CCanvasInteractionInfo, keyboardFlags: Set<CCanvasKeyboardFlag>, coordinate: CCanvasCoordinate)
    func canvasDragReleased(_ drag: CCanvasDrag, at position: CGPoint, ignoreTap: Bool, info: CCanvasInteractionInfo, keyboardFlags: Set<CCanvasKeyboardFlag>, coordinate: CCanvasCoordinate)
    func canvasDragWillEnd(_ drag: CCanvasDrag, at position: CGPoint, coordinate: CCanvasCoordinate)
    func canvasDragDidEnd(_ drag: CCanvasDrag, at position: CGPoint, coordinate: CCanvasCoordinate)
    
    func canvasMoveStarted(at position: CGPoint, viaScroll: Bool, info: CCanvasInteractionInfo?, keyboardFlags: Set<CCanvasKeyboardFlag>, coordinate: CCanvasCoordinate)
    func canvasMoveUpdated(at position: CGPoint, viaScroll: Bool, info: CCanvasInteractionInfo?, keyboardFlags: Set<CCanvasKeyboardFlag>, coordinate: CCanvasCoordinate)
    func canvasMoveEnded(at position: CGPoint, viaScroll: Bool, info: CCanvasInteractionInfo?, keyboardFlags: Set<CCanvasKeyboardFlag>, coordinate: CCanvasCoordinate)
    
    #if os(macOS)
    func canvasSelectionStarted(at position: CGPoint, info: CCanvasInteractionInfo, keyboardFlags: Set<CCanvasKeyboardFlag>, coordinate: CCanvasCoordinate)
    func canvasSelectionChanged(to position: CGPoint, coordinate: CCanvasCoordinate)
    func canvasSelectionEnded(at position: CGPoint, info: CCanvasInteractionInfo, keyboardFlags: Set<CCanvasKeyboardFlag>, coordinate: CCanvasCoordinate)
    #endif
    
}
