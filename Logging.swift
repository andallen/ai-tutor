import Foundation

@objc public class AppLogger: NSObject {
  @objc public static func log(_ message: String) {
    Swift.print(message)
    NSLog("APP_LOG: \(message)")
  }

  @objc public static func addLog(_ message: String) {
    log(message)
  }
}

public func appLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
  let output = items.map { "\($0)" }.joined(separator: separator)
  AppLogger.log(output)
}

public func addLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
  let output = items.map { "\($0)" }.joined(separator: separator)
  AppLogger.addLog(output)
}
