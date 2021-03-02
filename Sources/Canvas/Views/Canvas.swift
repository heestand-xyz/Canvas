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
    @State var canvasDragInteractions: [UUID: CanvasInteraction] = [:]
    
    public var body: some View {
        
        ZStack(alignment: .topLeading) {
            
            // Background
            backgroundContent(canvasCoordinate)
            
            // Back
            ZStack(alignment: .topLeading) {
                ForEach(frameContentList) { frameContent in
                    frameContent.backContent(canvasCoordinate)
                        .canvasFrame(content: frameContent, scale: canvasScale)
                }
            }
            .canvasCoordinateRotationOffset(canvasCoordinate)
            
            // Touches
            #if DEBUG
            ForEach(canvasInteractions) { interaction in
                Circle()
                    .foregroundColor((interaction == canvasPanInteraction) ? .blue :
                                        (interaction == canvasPinchInteraction?.0 ||
                                            interaction == canvasPinchInteraction?.1) ? .purple :
                                        canvasDragInteractions.contains(where: { $0.value == interaction }) ? .orange : .primary)
                    .opacity(interaction.active ? 1.0 : 0.25)
                    .frame(width: 50, height: 50)
                    .offset(x: interaction.location.x - 25,
                            y: interaction.location.y - 25)
            }
            #endif
            
            // Interact
            CanvasInteractViewRepresentable(snapAngle: snapAngle,
                                            frameContentList: $frameContentList,
                                            canvasOffset: $canvasOffset,
                                            canvasScale: $canvasScale,
                                            canvasAngle: $canvasAngle,
                                            canvasInteractions: $canvasInteractions,
                                            canvasPanInteraction: $canvasPanInteraction,
                                            canvasPinchInteraction: $canvasPinchInteraction,
                                            canvasDragInteractions: $canvasDragInteractions)
            
            // Front
            ZStack(alignment: .topLeading) {
                ForEach(frameContentList) { frameContent in
                    frameContent.frontContent(canvasCoordinate)
                        .canvasFrame(content: frameContent, scale: canvasScale)
                }
            }
            .canvasCoordinateRotationOffset(canvasCoordinate)
            
        }
        
    }
    
}
