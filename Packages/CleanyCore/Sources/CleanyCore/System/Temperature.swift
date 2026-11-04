import Foundation

/// The CPU temperature, read from the Apple Silicon die sensors through IOHIDEventSystem. That API is
/// private (there is no public one for degrees), so its symbols are looked up at run time and a
/// missing one, or an Intel Mac without these sensors, reads as `nil`.
public enum Temperature {
    /// The hottest CPU die, in °C, or `nil` when the sensors can't be read.
    public static func cpuCelsius() -> Double? {
        guard let api = HID.shared else { return nil }
        let services = (api.copyServices(api.client)?.takeRetainedValue() as? [AnyObject]) ?? []
        let readings = services.compactMap { service -> (String, Double)? in
            guard let name = api.copyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String,
                  let event = api.copyEvent(service, temperatureEvent, 0, 0)?.takeRetainedValue() else { return nil }
            return (name, api.floatValue(event, Int32(temperatureEvent << 16)))
        }
        return hottestDie(readings)
    }

    /// The hottest "tdie" sensor ("PMU tdie3", "PMU2 tdie1"); out-of-range values are sensor noise.
    static func hottestDie(_ readings: [(name: String, celsius: Double)]) -> Double? {
        readings.filter { $0.name.contains("tdie") && (1...150).contains($0.celsius) }.map(\.celsius).max()
    }

    private static let temperatureEvent: Int64 = 15 // kIOHIDEventTypeTemperature

    /// The client and the functions, resolved once.
    private struct HID: @unchecked Sendable {
        typealias Create = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
        typealias SetMatching = @convention(c) (AnyObject, CFDictionary) -> Int32
        typealias CopyServices = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
        typealias CopyProperty = @convention(c) (AnyObject, CFString) -> Unmanaged<AnyObject>?
        typealias CopyEvent = @convention(c) (AnyObject, Int64, Int32, Int64) -> Unmanaged<AnyObject>?
        typealias FloatValue = @convention(c) (AnyObject, Int32) -> Double

        let client: AnyObject
        let copyServices: CopyServices
        let copyProperty: CopyProperty
        let copyEvent: CopyEvent
        let floatValue: FloatValue

        static let shared: HID? = {
            guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else { return nil }
            func symbol<T>(_ name: String, as: T.Type) -> T? {
                dlsym(handle, name).map { unsafeBitCast($0, to: T.self) }
            }
            guard let create = symbol("IOHIDEventSystemClientCreate", as: Create.self),
                  let setMatching = symbol("IOHIDEventSystemClientSetMatching", as: SetMatching.self),
                  let copyServices = symbol("IOHIDEventSystemClientCopyServices", as: CopyServices.self),
                  let copyProperty = symbol("IOHIDServiceClientCopyProperty", as: CopyProperty.self),
                  let copyEvent = symbol("IOHIDServiceClientCopyEvent", as: CopyEvent.self),
                  let floatValue = symbol("IOHIDEventGetFloatValue", as: FloatValue.self),
                  let client = create(kCFAllocatorDefault)?.takeRetainedValue() else { return nil }
            // Apple vendor page, temperature sensor usage.
            _ = setMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
            return HID(client: client, copyServices: copyServices, copyProperty: copyProperty,
                       copyEvent: copyEvent, floatValue: floatValue)
        }()
    }
}
