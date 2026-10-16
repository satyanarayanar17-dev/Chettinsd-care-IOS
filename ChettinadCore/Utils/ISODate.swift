import Foundation

/// Shared, tolerant ISO-8601 handling for backend timestamps.
/// Accepts values with or without fractional seconds (e.g. `2026-09-25T10:00:00Z`
/// and `2026-09-25T10:00:00.000+05:30`).
public enum ISODate {
    public static func parse(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: trimmed) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: trimmed)
    }

    /// Formats a backend timestamp in the user's locale and the hospital's Asia/Kolkata time zone.
    /// Falls back to the raw string if it cannot be parsed.
    public static func display(_ string: String, dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short) -> String {
        guard let date = parse(string) else { return string }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier:"Asia/Kolkata")
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }
}
