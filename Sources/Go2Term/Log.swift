import Foundation
import os

enum Log {
    static let app = Logger(subsystem: "com.bingghost.Go2Term", category: "app")
}

/// Milliseconds elapsed since `start`.
func elapsedMS(since start: ContinuousClock.Instant) -> Int {
    let d = ContinuousClock.now - start
    return Int(d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000)
}
