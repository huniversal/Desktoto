import Synchronization

// 테스트에서 가짜 구현이 받은 값을 스레드 안전하게 모은다. Mutex는 복사할 수 없어서 클래스로 감싼다.
final class CallLog<Element: Sendable>: Sendable {
    private let storage = Mutex<[Element]>([])

    func append(_ element: Element) {
        storage.withLock { $0.append(element) }
    }

    var elements: [Element] {
        storage.withLock { $0 }
    }

    var count: Int {
        storage.withLock { $0.count }
    }
}
