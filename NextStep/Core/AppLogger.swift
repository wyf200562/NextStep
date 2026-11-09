import Foundation
import os

/// Layered loggers. Categories mirror the architecture: app, data, matching, ui.
///
/// Use these instead of `print` so logs remain filterable and privacy-aware.
nonisolated enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "NextStep"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let matching = Logger(subsystem: subsystem, category: "matching")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
