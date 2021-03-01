import SwiftUI

public struct Canvas<GridContent: View, Content: View>: View {
    
    let backgroundContent: (CGFloat) -> (GridContent)
    @Binding var frameContentList: [FrameContent<Content>]
    
    public init(frameContentList: Binding<[FrameContent<Content>]>,
                background: @escaping (CGFloat) -> (GridContent)) {
        _frameContentList = frameContentList
        backgroundContent = background
    }
    
    @State var canvasOffset: CGPoint = .zero
    @State var canvasScale: CGFloat = 1.0
    @State var canvasAngle: Angle = .zero
    @State var canvasInteractions: [CanvasInteraction] = []
    
    public var body: some View {
        
        ZStack(alignment: .topLeading) {
            
            backgroundContent(canvasScale)
                .rotationEffect(canvasAngle)
                .offset(x: canvasOffset.x,
                        y: canvasOffset.y)
            
            CanvasInteractViewRepresentable(canvasOffset: $canvasOffset,
                                            canvasScale: $canvasScale,
                                            canvasAngle: $canvasAngle,
                                            canvasInteractions: $canvasInteractions)
            
            ZStack(alignment: .topLeading) {
                
                ForEach(frameContentList) { frameContent in
                    frameContent.content()
                        .frame(width: frameContent.canvasFrame.width * canvasScale,
                               height: frameContent.canvasFrame.height * canvasScale)
                        .border(Color.red)
                        .offset(x: frameContent.canvasFrame.origin.x * canvasScale,
                                y: frameContent.canvasFrame.origin.y * canvasScale)
                }
    
            }
            .rotationEffect(canvasAngle)
            .offset(x: canvasOffset.x,
                    y: canvasOffset.y)
            
        }
        
    }
    
}
