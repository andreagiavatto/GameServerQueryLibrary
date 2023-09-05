// Copyright © 2021 Rhapsody International. All rights reserved.

import Foundation
import os

public final class NLog {
	private static let subsystem = "com.napster.logging"
	private static let defaultLogger = Logger(subsystem: subsystem, category: "default")
	private static var loggers = [String: Logger]()

	private init() {}

	public enum LogMessagePrivacy {
		case `public`, `private`
	}

	public static func log(_ message: Any, function: String = #function, file: String = #file, line: UInt = #line, privacy: LogMessagePrivacy = .public, verbose: Bool = false) {
		let colorizedMessage = ">> ⚪️ \(message)"
		printLog(message: colorizedMessage, function: function, file: file, line: line, privacy: privacy, verbose: verbose)
	}

	public static func error(_ message: Any, function: String = #function, file: String = #file, line: UInt = #line, privacy: LogMessagePrivacy = .public, verbose: Bool = true) {
		let colorizedMessage = ">> 🔴 \(message)"
		printLog(message: colorizedMessage, function: function, file: file, line: line, privacy: privacy, verbose: verbose)
	}

	private static func printLog(message: String, function: String = #function, file: String = #file, line: UInt = #line, privacy: LogMessagePrivacy, verbose: Bool) {
		guard !ProcessInfo.processInfo.arguments.contains("SILENCE_TRACE_LOGS") else {
			return
		}

        guard BuildDestination.allTestingModes.contains(BuildDestination.current) else {
			return
		}

		let fileName = (file as NSString).lastPathComponent
		let logger = defaultLogger
		let prefix = verbose ? "[\(fileName):L.\(line) - \(function)] " : ""
		if case .private = privacy {
			logger.info("\(prefix)\(message, privacy: .private)")
		} else {
			logger.info("\(prefix)\(message, privacy: .public)")
		}
	}
}

public struct BuildDestination: OptionSet {
    public let rawValue: Int

    static let dev = BuildDestination(rawValue: 1 << 0)
    static let release = BuildDestination(rawValue: 1 << 2)

    static let allTestingModes: BuildDestination = [.dev]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static var current: BuildDestination {
        #if DEBUG
            return .dev
        #else
            return .release // assume release to print nothing if unknown
        #endif
    }
}
