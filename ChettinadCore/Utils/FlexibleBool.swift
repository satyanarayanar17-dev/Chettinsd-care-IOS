import Foundation

@propertyWrapper
public struct FlexibleBool: Codable {
    public var wrappedValue: Bool

    public init(wrappedValue: Bool) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            wrappedValue = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            wrappedValue = (intValue != 0)
        } else if let stringValue = try? container.decode(String.self) {
            wrappedValue = (stringValue.lowercased() == "true" || stringValue == "1")
        } else {
            wrappedValue = false
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}
