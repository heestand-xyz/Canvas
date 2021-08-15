//
//  CanvasFadeMask.swift
//  CanvasDemo
//
//  Created by Anton Heestand on 2021-03-02.
//

import SwiftUI

public struct CanvasFadeMask: View {
    let distance: CGFloat
    public init(distance: CGFloat) {
        self.distance = distance
    }
    public var body: some View {
        GeometryReader(content: { geo in
            LinearGradient(gradient: Gradient(stops: [
                Gradient.Stop(color: .clear, location: 0.0),
                Gradient.Stop(color: .white, location: distance / geo.size.width),
                Gradient.Stop(color: .white, location: 1.0 - (distance / geo.size.width)),
                Gradient.Stop(color: .clear, location: 1.0),
            ]), startPoint: .leading, endPoint: .trailing)
            .mask(
                LinearGradient(gradient: Gradient(stops: [
                    Gradient.Stop(color: .clear, location: 0.0),
                    Gradient.Stop(color: .white, location: distance / geo.size.height),
                    Gradient.Stop(color: .white, location: 1.0 - (distance / geo.size.height)),
                    Gradient.Stop(color: .clear, location: 1.0),
                ]), startPoint: .top, endPoint: .bottom)
            )
        })
    }
}

struct CanvasFadeMask_Previews: SwiftUI.PreviewProvider {
    static var previews: some View {
        CanvasFadeMask(distance: 100)
    }
}
