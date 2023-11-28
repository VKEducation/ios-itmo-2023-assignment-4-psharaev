import Foundation

class ThreadSafeArray<T> {
    private var array: [T] = []
    private let lock = RWLock()
}

extension ThreadSafeArray: RandomAccessCollection {
    typealias Index = Int
    typealias Element = T

    var startIndex: Index {
        lock.withReadLock {
            return array.startIndex
        }
    }
    var endIndex: Index {
        lock.withReadLock {
            return array.endIndex
        }
    }

    subscript(index: Index) -> Element {
        get {
            lock.withReadLock {
                return array[index]
            }
        }
        set {
            lock.withWriteLock {
                array[index] = newValue
            }
        }
    }

    func index(after i: Index) -> Index {
        lock.withReadLock {
            return array.index(after: i)
        }
    }
}

class RWLock {
    private var lock = pthread_rwlock_t()

    public init() {
        guard pthread_rwlock_init(&lock, nil) == 0 else {
            fatalError("RWLock fail init")
        }
    }

    deinit {
        guard pthread_rwlock_destroy(&lock) == 0 else {
            fatalError("RWLock fail deinit")
        }
    }

    func writeLock() {
        guard pthread_rwlock_wrlock(&lock) == 0 else {
            fatalError("RWLock fail get write lock")
        }
    }

    func readLock() {
        guard pthread_rwlock_rdlock(&lock) == 0 else {
            fatalError("RWLock fail get read lock")
        }
    }

    func unlock() {
        guard pthread_rwlock_unlock(&lock) == 0 else {
            fatalError("RWLock fail unlock")
        }
    }

    func withReadLock<T>(_ action: () -> T) -> T {
        readLock()
        defer {
            unlock()
        }
        return action()
    }

    func withWriteLock<T>(_ action: () -> T) -> T {
        writeLock()
        defer {
            unlock()
        }
        return action()
    }
}
