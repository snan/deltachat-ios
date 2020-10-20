import Foundation
import DcCore
import UIKit
import AVFoundation

extension DcMsg {
    public func getPrettyFileSize() -> String {
        if self.filesize <= 0 { return "0 B" }
        let units: [String] = ["B", "kB", "MB"]
        let digitGroups = Int(log10(Double(self.filesize)) / log10(1024))
        let size = String(format: "%.1f", Double(filesize) / pow(1024, Double(digitGroups)))
        return "\(size) \(units[digitGroups])"
    }
}
