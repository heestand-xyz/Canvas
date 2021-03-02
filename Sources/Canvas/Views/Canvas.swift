import SwiftUI

public struct Canvas<BackgroundContent: View, FrontContent: View, BackContent: View>: View {
    
    let snapAngle: Angle?
    
    let backgroundContent: (CanvasCoordinate) -> (BackgroundContent)
    
    @Binding var frameContentList: [CanvasFrameContent<FrontContent, BackContent>]
    
    public init(snapAngle: Angle? = Angle(degrees: 90.0),
                frameContentList: Binding<[CanvasFrameContent<FrontContent, BackContent>]>,
                background: @escaping (CanvasCoordinate) -> (BackgroundContent)) {
        self.snapAngle = snapAngle
        _frameContentList = frameContentList
        backgroundContent = background
    }
    
    @State var canvasOffset: CGPoint = .zero
    @State var canvasScale: CGFloat = 1.0
    @State var canvasAngle: Angle = .zero
    var canvasCoordinate: CanvasCoordinate {
        CanvasCoordinate(offset: canvasOffset,
                         scale: canvasScale,
                         angle: canvasAngle)
    }
    
    @State var canvasInteractions: [CanvasInteraction] = []
    @State var canvasPanInteraction: CanvasInteraction? = nil
    @State var canvasPinchInteraction: (CanvasInteraction, CanvasInteraction)? = nil
    
    public var body: some View {
        
        ZStack(alignment: .topLeading) {
            
            // Background
            backgroundContent(canvasCoordinate)
            
            // Touches
            #if DEBUG
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
            #endif
            
            // Back
            ZStack(alignment: .topLeading) {
                ForEach(frameContentList) { frameContent in
                    frameContent.backContent(canvasCoordinate)
                        .frame(width: frameContent.canvasFrame.width * canvasScale,
                               height: frameContent.canvasFrame.height * canvasScale)
                        .offset(x: frameContent.canvasFrame.origin.x * canvasScale,
                                y: frameContent.canvasFrame.origin.y * canvasScale)
                }
            }
            .canvasCoordinateRotationOffset(canvasCoordinate)
            
            // Interact
            CanvasInteractViewRepresentable(snapAngle: snapAngle,
                                            frameContentList: $frameContentList,
                                            canvasOffset: $canvasOffset,
                                            canvasScale: $canvasScale,
                                            canvasAngle: $canvasAngle,
                                            canvasInteractions: $canvasInteractions,
                                            canvasPanInteraction: $canvasPanInteraction,
                                            canvasPinchInteraction: $canvasPinchInteraction)
            
            // Front
            ZStack(alignment: .topLeading) {
                ForEach(frameContentList) { frameContent in
                    frameContent.frontContent(canvasCoordinate)
                        .frame(width: frameContent.canvasFrame.width * canvasScale,
                               height: frameContent.canvasFrame.height * canvasScale)
                        .offset(x: frameContent.canvasFrame.origin.x * canvasScale,
                                y: frameContent.canvasFrame.origin.y * canvasScale)
                }
            }
            .canvasCoordinateRotationOffset(canvasCoordinate)
            
        }
        
    }
    
}
