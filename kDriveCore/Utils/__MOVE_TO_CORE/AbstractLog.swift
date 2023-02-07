/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import CocoaLumberjackSwift
import Foundation
import os.log
import InfomaniakDI

/// A representation of sandard log levels
public enum AbstractLogLevel {
    case emergency
    case alert
    case critical
    case error
    case warning
    case notice
    case info
    case debug
    /// Use this level only to capture system-level or multiprocess information when reporting system errors.
    case fault
    
    /// bridge to OSLogType
    var logType: OSLogType {
        switch self {
        case .warning, .notice, .emergency, .alert, .critical:
            return .default
        case .error:
            return .error
        case .info:
            return .info
        case .debug:
            return .debug
        case .fault:
            return .fault
        }
    }
}

fileprivate let categoryKey = "category"

/// Abstract log mechanism, wrapping cocoalumberjack and OSLog
///
/// OSLog messages are only enabled on iOS 14.0 and up, also enabled if the `DEBUG` flag is set.
///
/// - Parameters:
///   - message: the message we want to log
///   - level: the log level
///   - context: the context
///   - file: the file name this event originates from
///   - function: the function name this event originates from
///   - line: the line this event originates from
///   - tag: any extra info
///   - async: Should this be async?
public func ABLog(_ message: @autoclosure () -> Any,
                  category: String = "",
                  subsystem: String = Bundle.main.bundleIdentifier!,
                  level: AbstractLogLevel = .info,
                  context: Int = 0,
                  file: StaticString = #file,
                  function: StaticString = #function,
                  line: UInt = #line,
                  tag: Any? = nil,
                  asynchronous async: Bool = asyncLoggingEnabled) {
    let messageString = message() as! String
    
    // Forward to OS.log
#if DEBUG
    if #available(iOS 14.0, *), category.isEmpty == false {
        let factoryParameters = [categoryKey : category]
        @InjectService(customTypeIdentifier: category, factoryParameters: factoryParameters) var logger: Logger
        
        switch level {
        case .warning, .alert:
            logger.warning("\(messageString)")
        case .emergency, .critical:
            logger.critical("\(messageString)")
        case .error:
            logger.error("\(messageString)")
        case .notice:
            logger.notice("\(messageString)")
        case .info:
            logger.info("\(messageString)")
        case .debug:
            logger.debug("\(messageString)")
        case .fault:
            logger.fault("\(messageString)")
        }
    } else {
        // os_log() only support `StaticSting`
    }
#endif
    
    // Forward to cocoaLumberjack
//    let buffer = "[\(category)] " + messageString
//    switch level {
//    case .error:
//        DDLogError(buffer,
//                   context: context,
//                   file: file,
//                   function: function,
//                   line: line,
//                   tag: tag,
//                   asynchronous: async,
//                   ddlog: .sharedInstance)
//    case.info: fallthrough
//    default:
//        DDLogInfo(buffer,
//                  context: context,
//                  file: file,
//                  function: function,
//                  line: line,
//                  tag: tag,
//                  asynchronous: async,
//                  ddlog: .sharedInstance)
//    }
}
