import SwiftUI

/// Cleany's mark, from `App/AppIcon.icon`: the creek band bent into a C, open on the right, with its
/// last stretch split off as the part that can come back. Same proportions as the icon (a 262 radius
/// and a 120 stroke in its 1024 canvas), scaled so `size` is the outer diameter.
struct CleanyMark: View {
    var size: CGFloat
    /// Shows the split-off stretch: in the menu bar, only while something idle can be cleaned up.
    var segment = true
    var ink: Color = .primary
    var accent: Color = Creek.idleMark

    var body: some View {
        let line = size * 120 / 644
        let diameter = size * 524 / 644
        // Degrees clockwise from three o'clock: the C runs 70°…320°, the stretch 40°…62°.
        ZStack {
            Circle().trim(from: 70 / 360, to: 320 / 360)
                .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .butt))
            if segment {
                Circle().trim(from: 40 / 360, to: 62 / 360)
                    .stroke(accent, style: StrokeStyle(lineWidth: line, lineCap: .butt))
            }
        }
        .frame(width: diameter, height: diameter)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
