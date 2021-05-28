import CoreGraphics

public enum CanvasSnapGrid: Hashable {
    case square(size: CGFloat)
    case triangle(size: CGFloat)
    var size: CGFloat {
        switch self {
        case .square(size: let size):
            return size
        case .triangle(size: let size):
            return size
        }
    }
}
