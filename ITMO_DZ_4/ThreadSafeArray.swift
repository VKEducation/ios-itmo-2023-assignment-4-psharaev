import Foundation

class ThreadSafeArray<T> {
    private var array: [T] = []
    private let mutex = NSLock()
}

extension ThreadSafeArray: RandomAccessCollection {
    typealias Index = Int
    typealias Element = T

    var startIndex: Index {
        mutex.withLock {
            return array.startIndex
        }
    }
    var endIndex: Index {
        mutex.withLock {
            return array.endIndex
        }
    }

    subscript(index: Index) -> Element {
        get {
            mutex.withLock {
                return array[index]
            }
        }
    }

    func index(after i: Index) -> Index {
        mutex.withLock {
            return array.index(after: i)
        }
    }
}
