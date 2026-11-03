import Boundaries
import Foundation
import Synchronization

/// 테스트가 정한 시각을 돌려주는 가짜 시계. `advance(by:)`로 시간을 흐르게 한다.
public final class FixedTimeSource: TimeSource {
    private let current: Mutex<Date>

    public init(now: Date) {
        current = Mutex(now)
    }

    public var now: Date {
        current.withLock { $0 }
    }

    public func advance(by interval: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(interval) }
    }
}
