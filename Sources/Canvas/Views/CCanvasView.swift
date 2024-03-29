import SwiftUI

public struct CCanvasView<Content: View>: View {
    
    @ObservedObject var canvas: CCanvas
    
    let content: () -> Content
    
    public init(canvas: CCanvas, @ViewBuilder content: @escaping () -> Content = { EmptyView() }) {
        self.canvas = canvas
        self.content = content
    }
    
    public var body: some View {
        
        ZStack(alignment: .topLeading) {
            
            /// Debug of Touches
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
            
            /// Debug of Coodinates
//            #if DEBUG
//            ZStack(alignment: .bottomLeading) {
//                Color.clear
//                HStack {
//                    Group {
//                        Text("x: \(canvas.offset.x)")
//                        Text("y: \(canvas.offset.y)")
//                        Text("s: \(canvas.scale)")
//                        Text("a: \(canvas.angle.degrees)")
//                    }
//                    .font(.system(.footnote, design: .monospaced))
//                    .frame(width: 85)
//                }
//                .padding(5)
//            }
//            #endif
            
            // Interact
            CCanvasInteractViewRepresentable(canvas: canvas) {
                ZStack(alignment: .topLeading) {
                    Color.clear
                    content()
                }
            }
        }
    }
}
