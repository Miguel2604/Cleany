import SwiftUI

/// Cleany's mark, from `App/AppIcon.icon`: a C on a 5×5 dot grid, with its last stretch set apart as
/// the part that can come back: hollow here and in the icon (idle, like a meter's hollow dots).
struct CleanyMark: View {
    /// (column, row) from the top left.
    static let letter = [(1, 0), (2, 0), (3, 0), (4, 0), (0, 1), (0, 2), (0, 3), (1, 4), (2, 4), (3, 4)]
    static let stretch = [(4, 3), (4, 4)]

    var size: CGFloat
    /// Shows the stretch.
    var segment = true

    var body: some View {
        Canvas { context, canvas in
            let pitch = canvas.width / 5
            let dot = pitch * 0.8
            let oval = { (cell: (Int, Int), inset: CGFloat) in
                Path(ellipseIn: CGRect(x: CGFloat(cell.0) * pitch + inset + pitch * 0.1, y: CGFloat(cell.1) * pitch + inset + pitch * 0.1,
                                       width: dot - 2 * inset, height: dot - 2 * inset))
            }
            for cell in Self.letter { context.fill(oval(cell, 0), with: .foreground) }
            if segment {
                for cell in Self.stretch { context.stroke(oval(cell, dot * 0.1), with: .foreground, lineWidth: dot * 0.2) }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
