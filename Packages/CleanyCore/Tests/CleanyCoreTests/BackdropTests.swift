import Foundation
import Testing
@testable import CleanyCore

@Test func backdropDefaultsToTintedAndReadsTheSavedChoice() {
    let suite = "app.cleany.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    #expect(Backdrop.saved(in: nil) == .tinted)
    #expect(Backdrop.saved(in: defaults) == .tinted)
    defaults.set("clear", forKey: Backdrop.key)
    #expect(Backdrop.saved(in: defaults) == .clear)
    defaults.set("nonsense", forKey: Backdrop.key)
    #expect(Backdrop.saved(in: defaults) == .tinted)
}
