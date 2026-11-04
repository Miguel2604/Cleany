import SwiftUI

/// The raccoon's face for each state of the Mac. Depends only on SwiftUI, so the widget and the icon
/// renderer script can draw it too.
enum RaccoonMood: String, CaseIterable, Sendable {
    /// Nothing to wash: eyes closed, smiling.
    case calm
    /// Busy, but nothing idle: eyes open.
    case busy
    /// Draining fast: eyes wide, brows up. Concerned, never angry.
    case worried
    /// Still watching after launch or wake: eyes glance to the side.
    case watching
    /// Just cleaned up: happy eyes, paws rubbing together.
    case washing
}

/// A raccoon head drawn in a 100 × 100 space and scaled to `size`.
/// `pawPhase` (0…1) moves the paws while washing; the caller animates it.
struct Raccoon: View {
    var mood: RaccoonMood
    var size: CGFloat
    var pawPhase: Double = 0
    /// One flat color with the mask and eyes cut out: the menu bar's template glyph.
    var template = false

    static let fur = Color(red: 0.66, green: 0.69, blue: 0.71)
    static let furDark = Color(red: 0.42, green: 0.45, blue: 0.48)
    static let mask = Color(red: 0.13, green: 0.15, blue: 0.17)
    static let cream = Color(red: 0.96, green: 0.97, blue: 0.95)

    var body: some View {
        Canvas { context, canvasSize in
            context.scaleBy(x: canvasSize.width / 100, y: canvasSize.height / 100)
            if template { drawTemplate(&context) } else { drawFull(&context) }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: Shapes (100 × 100)

    private var ears: [Path] {
        [Path { p in
            p.move(to: CGPoint(x: 14, y: 40)); p.addQuadCurve(to: CGPoint(x: 24, y: 10), control: CGPoint(x: 10, y: 18))
            p.addQuadCurve(to: CGPoint(x: 42, y: 26), control: CGPoint(x: 36, y: 12)); p.closeSubpath()
        }, Path { p in
            p.move(to: CGPoint(x: 86, y: 40)); p.addQuadCurve(to: CGPoint(x: 76, y: 10), control: CGPoint(x: 90, y: 18))
            p.addQuadCurve(to: CGPoint(x: 58, y: 26), control: CGPoint(x: 64, y: 12)); p.closeSubpath()
        }]
    }

    private var innerEars: [Path] {
        [Path(ellipseIn: CGRect(x: 21, y: 17, width: 11, height: 16)).applying(rotation(-28, around: CGPoint(x: 26, y: 25))),
         Path(ellipseIn: CGRect(x: 68, y: 17, width: 11, height: 16)).applying(rotation(28, around: CGPoint(x: 74, y: 25)))]
    }

    /// A wide head that narrows to the chin.
    private var head: Path {
        Path { p in
            p.move(to: CGPoint(x: 50, y: 20))
            p.addCurve(to: CGPoint(x: 94, y: 56), control1: CGPoint(x: 78, y: 20), control2: CGPoint(x: 96, y: 36))
            p.addCurve(to: CGPoint(x: 50, y: 88), control1: CGPoint(x: 92, y: 72), control2: CGPoint(x: 70, y: 88))
            p.addCurve(to: CGPoint(x: 6, y: 56), control1: CGPoint(x: 30, y: 88), control2: CGPoint(x: 8, y: 72))
            p.addCurve(to: CGPoint(x: 50, y: 20), control1: CGPoint(x: 4, y: 36), control2: CGPoint(x: 22, y: 20))
        }
    }

    /// The bandit mask: two swept lobes over the eyes, joined above the nose.
    private var mask: Path {
        Path { p in
            p.move(to: CGPoint(x: 50, y: 46))
            p.addCurve(to: CGPoint(x: 12, y: 50), control1: CGPoint(x: 38, y: 38), control2: CGPoint(x: 18, y: 38))
            p.addCurve(to: CGPoint(x: 30, y: 64), control1: CGPoint(x: 10, y: 60), control2: CGPoint(x: 20, y: 66))
            p.addCurve(to: CGPoint(x: 50, y: 56), control1: CGPoint(x: 40, y: 62), control2: CGPoint(x: 46, y: 58))
            p.addCurve(to: CGPoint(x: 70, y: 64), control1: CGPoint(x: 54, y: 58), control2: CGPoint(x: 60, y: 62))
            p.addCurve(to: CGPoint(x: 88, y: 50), control1: CGPoint(x: 80, y: 66), control2: CGPoint(x: 90, y: 60))
            p.addCurve(to: CGPoint(x: 50, y: 46), control1: CGPoint(x: 82, y: 38), control2: CGPoint(x: 62, y: 38))
        }
    }

    private var brows: [Path] {
        let lift: CGFloat = mood == .worried ? -4 : 0
        return [Path { p in
            p.move(to: CGPoint(x: 18, y: 42)); p.addQuadCurve(to: CGPoint(x: 44, y: 40 + lift), control: CGPoint(x: 30, y: 30 + lift))
            p.addQuadCurve(to: CGPoint(x: 18, y: 42), control: CGPoint(x: 30, y: 36 + lift))
        }, Path { p in
            p.move(to: CGPoint(x: 82, y: 42)); p.addQuadCurve(to: CGPoint(x: 56, y: 40 + lift), control: CGPoint(x: 70, y: 30 + lift))
            p.addQuadCurve(to: CGPoint(x: 82, y: 42), control: CGPoint(x: 70, y: 36 + lift))
        }]
    }

    private var muzzle: Path {
        Path { p in
            p.move(to: CGPoint(x: 50, y: 56))
            p.addCurve(to: CGPoint(x: 68, y: 74), control1: CGPoint(x: 62, y: 58), control2: CGPoint(x: 70, y: 66))
            p.addCurve(to: CGPoint(x: 50, y: 86), control1: CGPoint(x: 66, y: 82), control2: CGPoint(x: 58, y: 86))
            p.addCurve(to: CGPoint(x: 32, y: 74), control1: CGPoint(x: 42, y: 86), control2: CGPoint(x: 34, y: 82))
            p.addCurve(to: CGPoint(x: 50, y: 56), control1: CGPoint(x: 30, y: 66), control2: CGPoint(x: 38, y: 58))
        }
    }

    private var nose: Path {
        Path(roundedRect: CGRect(x: 44, y: 62, width: 12, height: 8), cornerRadius: 4)
    }

    private var mouth: Path {
        Path { p in
            switch mood {
            case .worried:
                p.addEllipse(in: CGRect(x: 47, y: 74, width: 6, height: 5))
            case .busy, .watching:
                p.move(to: CGPoint(x: 50, y: 70)); p.addLine(to: CGPoint(x: 50, y: 74))
                p.move(to: CGPoint(x: 45, y: 76)); p.addQuadCurve(to: CGPoint(x: 55, y: 76), control: CGPoint(x: 50, y: 78))
            case .calm, .washing:
                p.move(to: CGPoint(x: 50, y: 70)); p.addLine(to: CGPoint(x: 50, y: 74))
                p.move(to: CGPoint(x: 42, y: 74)); p.addQuadCurve(to: CGPoint(x: 50, y: 74), control: CGPoint(x: 46, y: 80))
                p.addQuadCurve(to: CGPoint(x: 58, y: 74), control: CGPoint(x: 54, y: 80))
            }
        }
    }

    /// Eye centers, inside the mask lobes.
    private let eyeCenters = [CGPoint(x: 31, y: 52), CGPoint(x: 69, y: 52)]

    private var eyeRadius: CGFloat { mood == .worried ? 6.5 : 5.5 }

    private var closedEyes: Bool { mood == .calm || mood == .washing }

    private func closedEye(at c: CGPoint) -> Path {
        Path { p in
            p.move(to: CGPoint(x: c.x - 6, y: c.y + 1.5))
            p.addQuadCurve(to: CGPoint(x: c.x + 6, y: c.y + 1.5), control: CGPoint(x: c.x, y: c.y - 6))
        }
    }

    private var pupilOffset: CGFloat { mood == .watching ? 2.2 : 0 }

    private var paws: [Path] {
        let shift = CGFloat(sin(pawPhase * .pi * 2)) * 3
        return [Path(ellipseIn: CGRect(x: 30 + shift, y: 84, width: 18, height: 13)),
                Path(ellipseIn: CGRect(x: 52 - shift, y: 84, width: 18, height: 13))]
    }

    // MARK: Drawing

    private func drawFull(_ c: inout GraphicsContext) {
        for ear in ears { c.fill(ear, with: .color(Self.furDark)) }
        for ear in innerEars { c.fill(ear, with: .color(Self.mask.opacity(0.75))) }
        c.fill(head, with: .color(Self.fur))
        for brow in brows { c.fill(brow, with: .color(Self.cream)) }
        c.fill(muzzle, with: .color(Self.cream))
        c.fill(mask, with: .color(Self.mask))
        drawEyes(&c, ink: Self.cream)
        c.fill(nose, with: .color(Self.mask))
        c.stroke(mouth, with: .color(Self.mask), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        if mood == .washing {
            for paw in paws {
                c.fill(paw, with: .color(Self.furDark))
                c.stroke(paw, with: .color(Self.mask.opacity(0.35)), lineWidth: 1)
            }
        }
    }

    private func drawEyes(_ c: inout GraphicsContext, ink: Color) {
        for center in eyeCenters {
            if closedEyes {
                c.stroke(closedEye(at: center), with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            } else {
                let r = eyeRadius
                c.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(ink))
                let pr = r * 0.6
                let pc = CGPoint(x: center.x + pupilOffset, y: center.y + 0.5)
                c.fill(Path(ellipseIn: CGRect(x: pc.x - pr, y: pc.y - pr, width: pr * 2, height: pr * 2)), with: .color(Self.mask))
                c.fill(Path(ellipseIn: CGRect(x: pc.x - pr * 0.2, y: pc.y - pr * 0.75, width: pr * 0.6, height: pr * 0.6)), with: .color(.white))
            }
        }
    }

    /// Silhouette with the mask knocked out and the eyes drawn back in, so it reads at 16 pt.
    private func drawTemplate(_ c: inout GraphicsContext) {
        c.drawLayer { layer in
            for ear in ears { layer.fill(ear, with: .color(.black)) }
            layer.fill(head, with: .color(.black))
            layer.blendMode = .destinationOut
            layer.fill(mask, with: .color(.black))
            layer.fill(nose.applying(CGAffineTransform(translationX: 0, y: 4)), with: .color(.black))
            layer.blendMode = .normal
            for center in eyeCenters {
                if closedEyes {
                    layer.stroke(closedEye(at: center), with: .color(.black), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                } else {
                    let r = eyeRadius + 0.5
                    layer.fill(Path(ellipseIn: CGRect(x: center.x - r + pupilOffset, y: center.y - r, width: r * 2, height: r * 2)), with: .color(.black))
                }
            }
        }
    }

    private func rotation(_ degrees: CGFloat, around p: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: p.x, y: p.y).rotated(by: degrees * .pi / 180).translatedBy(x: -p.x, y: -p.y)
    }
}
