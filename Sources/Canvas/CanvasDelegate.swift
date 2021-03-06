import Foundation
import CoreGraphics

public protocol CanvasDelegate: AnyObject {

    func canvasHitTest(at position: CGPoint) -> UUID?
    
    func canvasContentPosition(id: UUID) -> CGPoint
    func canvasPositionContent(id: UUID, to position: CGPoint)

    func canvasDidStartDrag(id: UUID)
    func canvasWillEndDrag(id: UUID)
    func canvasDidEndDrag(id: UUID)
    
}
