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
    @State var canvasPanInteraction: CanvasInteraction? = nil
    @State var canvasPinchInteraction: (CanvasInteraction, CanvasInteraction)? = nil
    
    public var body: some View {
        
        ZStack(alignment: .topLeading) {
            
            backgroundContent(canvasScale)
                .rotationEffect(canvasAngle)
                .offset(x: canvasOffset.x,
                        y: canvasOffset.y)
            
            ForEach(canvasInteractions) { canvasInteraction in
                Circle()
                    .foregroundColor((canvasInteraction == canvasPanInteraction) ? .blue :
                                        (canvasInteraction == canvasPinchInteraction?.0 ||
                                            canvasInteraction == canvasPinchInteraction?.1) ? .purple : .primary)
                    .opacity(canvasInteraction.active ? 1.0 : 0.25)
                    .frame(width: 50, height: 50)
                    .offset(x: canvasInteraction.location.x - 25,
                            y: canvasInteraction.location.y - 25)
            }
            
            CanvasInteractViewRepresentable(canvasOffset: $canvasOffset,
                                            canvasScale: $canvasScale,
                                            canvasAngle: $canvasAngle,
                                            canvasInteractions: $canvasInteractions,
                                            canvasPanInteraction: $canvasPanInteraction,
                                            canvasPinchInteraction: $canvasPinchInteraction)
            
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
