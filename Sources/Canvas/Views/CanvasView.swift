import SwiftUI

public struct CanvasView<BackgroundContent: View, MiddleContent: View, FrontContent: View, BackContent: View>: View {
    
    let backgroundContent: (CanvasCoordinate) -> (BackgroundContent)
    let middleContent: (CanvasCoordinate) -> (MiddleContent)
    
    @ObservedObject var canvas: Canvas<FrontContent, BackContent>
    
    public init(canvas: Canvas<FrontContent, BackContent>,
                middle: @escaping (CanvasCoordinate) -> (MiddleContent),
                background: @escaping (CanvasCoordinate) -> (BackgroundContent)) {
        self.canvas = canvas
        backgroundContent = background
        middleContent = middle
    }
    
    public var body: some View {
        
        ZStack(alignment: .topLeading) {
            
            // Background
            backgroundContent(canvas.coordinate)
            
            // Back
            ZStack(alignment: .topLeading) {
                ForEach(canvas.frameContentList) { frameContent in
                    frameContent.backContent(canvas.coordinate)
                        .canvasFrame(content: frameContent, scale: canvas.scale)
                }
            }
            .frame(width: 1, height: 1, alignment: .topLeading) /// No Scale Hack
            .canvasCoordinateRotationOffset(canvas.coordinate)
            
            middleContent(canvas.coordinate)
            
            // Touches
//            #if DEBUG
//            ForEach(canvasInteractions) { interaction in
//                Circle()
//                    .foregroundColor((interaction == canvasPanInteraction) ? .blue :
//                                        (interaction == canvasPinchInteraction?.0 ||
//                                            interaction == canvasPinchInteraction?.1) ? .purple :
//                                        canvasDragInteractions.contains(where: { $0.value == interaction }) ? .orange : .primary)
//                    .opacity(interaction.active ? 1.0 : 0.25)
//                    .frame(width: 50, height: 50)
//                    .offset(x: interaction.location.x - 25,
//                            y: interaction.location.y - 25)
//            }
//            #endif
            
            // Interact
            CanvasInteractViewRepresentable(canvas: canvas)
            
            // Front
            ZStack(alignment: .topLeading) {
                ForEach(canvas.frameContentList) { frameContent in
                    frameContent.frontContent(canvas.coordinate)
                        .canvasFrame(content: frameContent, scale: canvas.scale)
                }
            }
            .frame(width: 1, height: 1, alignment: .topLeading) /// No Scale Hack
            .canvasCoordinateRotationOffset(canvas.coordinate)
            
        }
        
    }
    
}
