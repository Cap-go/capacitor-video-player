import Foundation

struct VideoChapter {
    let title: String
    let startTime: TimeInterval
    let endTime: TimeInterval?

    init?(dictionary: [String: Any]) {
        guard let title = dictionary["title"] as? String,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let startTime: TimeInterval
        if let number = dictionary["startTime"] as? NSNumber {
            startTime = number.doubleValue
        } else if let value = dictionary["startTime"] as? Double {
            startTime = value
        } else {
            return nil
        }

        if startTime < 0 {
            return nil
        }

        var endTime: TimeInterval?
        if let number = dictionary["endTime"] as? NSNumber {
            endTime = number.doubleValue
        } else if let value = dictionary["endTime"] as? Double {
            endTime = value
        }

        if let endTime, endTime <= startTime {
            return nil
        }

        self.title = title
        self.startTime = startTime
        self.endTime = endTime
    }
}
