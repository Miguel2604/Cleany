import Foundation

/// Tinted glass, or no fill at all with a soft shadow behind the content.
public enum Backdrop: String, CaseIterable, Sendable {
    case tinted, clear

    public static let key = "background"

    /// The global choice from Settings, kept in the App Group so the widget can read it too.
    public static func saved(in defaults: UserDefaults?) -> Backdrop {
        defaults?.string(forKey: key).flatMap(Backdrop.init) ?? .tinted
    }
}
