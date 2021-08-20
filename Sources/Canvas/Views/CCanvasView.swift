import SwiftUI

public struct CCanvasView: View {
    
    @ObservedObject var canvas: CCanvas
    
    public init(canvas: CCanvas) {
        self.canvas = canvas
    }
    
    public var body: some View {
        
        ZStack(alignment: .topLeading) {
            
            /// Touches
//            #if DEBUG
//            ForEach(Array(canvas.interactions)) { interaction in
//                Circle()
//                    .foregroundColor({
//                        if interaction == canvas.panInteraction {
//                            return .blue
//                        } else if interaction == canvas.pinchInteraction?.0 ||
//                                    interaction == canvas.pinchInteraction?.1 {
//                            return .purple
//                        } else if canvas.dragInteractions.contains(where: { $0.interaction == interaction }) {
//                            return .orange
//                        }
//                        return .primary
//                    }())
//                    .opacity(interaction.active ? 1.0 : 0.25)
//                    .frame(width: 50, height: 50)
//                    .offset(x: interaction.location.x - 25,
//                            y: interaction.location.y - 25)
//            }
//            #endif
            
            // Interact
            CCanvasInteractViewRepresentable(canvas: canvas)
            
        }
        
    }
    
}
