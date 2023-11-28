import Foundation

class ThreadSafeArray<T> {
    private var array: [T] = []
    private let lock: UnfairLock

    init() {
        self.lock = UnfairLock.createLock()
    }

    deinit {
        UnfairLock.deinitLock(lock)
    }
}

extension ThreadSafeArray: RandomAccessCollection {
    typealias Index = Int
    typealias Element = T

    var startIndex: Index {
        lock.withLock {
            return array.startIndex
        }
    }
    var endIndex: Index {
        lock.withLock {
            return array.endIndex
        }
    }

    subscript(index: Index) -> Element {
        get {
            lock.withLock {
                return array[index]
            }
        }
    }

    func index(after i: Index) -> Index {
        lock.withLock {
            return array.index(after: i)
        }
    }
}

typealias UnfairLock = UnsafeMutablePointer<os_unfair_lock>

extension UnfairLock {
    static func createLock() -> UnfairLock {
        let l = UnfairLock.allocate(capacity: 1)
        l.initialize(to: .init())
        return l
    }

    static func deinitLock(_ lock: UnfairLock) {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    func lock() {
        os_unfair_lock_lock(self)
    }

    func unlock() {
        os_unfair_lock_unlock(self)
    }

    func withLock<T>(_ action: () -> T) -> T {
        lock()
        defer {
            unlock()
        }
        return action()
    }
}