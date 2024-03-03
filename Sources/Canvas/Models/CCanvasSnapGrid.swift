import CoreGraphics

public enum CCanvasSnapGrid: Hashable {
    case square(size: CGFloat, offset: CGFloat)
    case triangle(size: CGFloat)
}
