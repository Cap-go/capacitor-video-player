import Foundation

@objc public class VideoPlayer: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
