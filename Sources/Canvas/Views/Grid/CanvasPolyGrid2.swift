//
//  CanvasPolyGrid2.swift
//  CanvasDemo
//
//  Created by Anton Heestand on 2021-03-01.
//

import SwiftUI
import CoreGraphicsExtensions

@available(macOS 12.0, iOS 15, *)
public struct CanvasPolyGrid2: View {
    
    let canvasCoordinate: CCanvasCoordinate
    
    let size: CGFloat
    
    let count: Int
    
    public init(size: CGFloat, count: Int = 3, canvasCoordinate: CCanvasCoordinate) {
        self.size = size
        self.count = count
        self.canvasCoordinate = canvasCoordinate
    }
    
    var spacing: CGFloat {
        size * canvasCoordinate.scale
    }
    
    let fractions: [CGFloat] = [0.25, 1.0, 4.0, 16.0]
    
    public var body: some View {
        Canvas { context, size in
            let extraScale: CGFloat = max(2.0, 0.5 + size.height / size.width)
            for fraction in fractions {
                guard canvasCoordinate.scale > (0.25 / fraction) else { continue }
                let opacity = (canvasCoordinate.scale - (0.25 / fraction)) * fraction
                drawGrid(in: context,
                         size: size,
                         at: fraction,
                         extraScale: extraScale,
                         opacity: opacity,
                         angleCount: count)
            }
        }
    }
    
    func drawGrid(in context: GraphicsContext,
                  size: CGSize,
                  at superScale: CGFloat = 1.0,
                  lineWidth: CGFloat = .onePixel,
                  extraScale: CGFloat = 2.0,
                  opacity: Double,
                  angleCount: Int) {
        
        let count = count(size: size, at: superScale, extraScale: extraScale)
        
        for i in 0..<angleCount {
            for y in (-count)...count {
                
                let width: CGFloat = size.width * extraScale * 2.0
                
                let xOffset: CGFloat = rotatedOffsetY(at: i) * -1.0
                var yOffset: CGFloat = (spacing * superScale) * CGFloat(y)
                yOffset += CGFloat(Int(rotatedOffsetX(at: i) / (spacing * superScale))) * (spacing * superScale) * -1.0
                
                var leadingPoint = CGPoint(x: -width / 2 + xOffset, y: yOffset)
                var trailingPoint = CGPoint(x: width / 2 + xOffset, y: yOffset)
                
                let angle: Angle = angle(at: i) + canvasCoordinate.angle
                leadingPoint = rotate(leadingPoint, byAngle: angle)
                trailingPoint = rotate(trailingPoint, byAngle: angle)
                
                leadingPoint += canvasCoordinate.offset
                trailingPoint += canvasCoordinate.offset
                
                let line = Path { path in
                    path.move(to: leadingPoint)
                    path.addLine(to: trailingPoint)
                }
                
                context.stroke(line, with: .color(Color.primary.opacity(opacity)), lineWidth: lineWidth)
            }
        }
    }
    
    func rotate(_ point: CGPoint, byAngle: Angle) -> CGPoint {
        let angle: Angle = Angle(radians: atan2(point.y, point.x)) + byAngle
        let radius: CGFloat = hypot(point.x, point.y)
        return CGPoint(x: cos(CGFloat(angle.radians)) * radius,
                       y: sin(CGFloat(angle.radians)) * radius)
    }
    
    func rotatedOffsetX(at index: Int) -> CGFloat {
        canvasCoordinate.rotatedOffset.x * cos(radians(at: index) + .pi * 0.5)
            + canvasCoordinate.rotatedOffset.y * sin(radians(at: index) + .pi * 0.5)
    }
    
    func rotatedOffsetY(at index: Int) -> CGFloat {
        canvasCoordinate.rotatedOffset.x * cos(radians(at: index))
            + canvasCoordinate.rotatedOffset.y * sin(radians(at: index))
    }
    
    func radians(at index: Int) -> CGFloat {
        CGFloat(angle(at: index).radians)
    }
    
    func angle(at index: Int) -> Angle {
        Angle(radians: Double(fraction(at: index) * .pi * 2))
    }
    
    func fraction(at index: Int) -> CGFloat {
        CGFloat(index) / CGFloat(count)
    }
    
    func count(size: CGSize, at superScale: CGFloat, extraScale: CGFloat) -> Int {
        let scaledSize: CGSize = (size / (spacing * superScale)) * extraScale
        return max(Int(scaledSize.width), Int(scaledSize.height))
    }
    
}

@available(macOS 12.0, iOS 15, *)
struct CanvasPolyGrid2_Previews: SwiftUI.PreviewProvider {
    static var previews: some View {
        CanvasPolyGrid2(size: 100, canvasCoordinate: .zero)
    }
}
