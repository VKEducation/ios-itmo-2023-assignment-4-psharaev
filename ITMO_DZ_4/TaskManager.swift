import Foundation

class Task: Hashable {
    let id: UUID
    /**
     Чем больше число, тем быстрее задача попадёт на выполнение, но это не гарантируется из-за графа зависимостей.
     */

    let name: String?

    let priority: Int

    private var dependencies = Set<Task>()

    private let lock = NSLock()

    convenience init(priority: Int) {
        self.init(name: nil, priority: priority)
    }

    init(name: String?, priority: Int) {
        self.name = name
        self.id = UUID();
        self.priority = priority
    }

    func getDependencies() -> Set<Task> {
        lock.withLock {
            dependencies
        }
    }

    /**
    добавить задачу, которая должна быть сделана до self.
    Вернёт true, если успешно
    */
    @discardableResult
    func addDependency(_ task: Task) -> Bool {
        lock.withLock {
                    dependencies.insert(task)
                }
                .inserted
    }

    func execute() {
        if let name = name {
            print("id: \(id) name: \(name) priority: \(priority)")
        } else {

            print("id: \(id) priority: \(priority)")
        }
    }

    public var hashValue: Int {
        id.hashValue
    }

    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }

    public static func ==(lhs: Task, rhs: Task) -> Bool {
        lhs.id == rhs.id
    }
}

extension Dictionary {
    mutating func computeIfAbsent(_ key: Key, defaultValue: () -> Value) -> Value {
        guard let existingValue = self[key] else {
            let computedValue = defaultValue()
            self[key] = computedValue
            return computedValue
        }
        return existingValue
    }
}

enum TaskManagerError: Error {
    case taskNotAdded
    case taskCycle
}

class Reference<T> {
    var value: T

    init(_ value: T) {
        self.value = value
    }
}

class TaskManager {
    private var tasks = Set<Task>()
    private let lock = NSLock()
    private let queue: DispatchQueue

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    /**
     добавить задачу в граф. Все зависимые задачи так же треубется добавить,
     иначе будет кинуто TaskManagerError.taskNotAdded в методе buildTasksSnapshot
     */
    func add(_ task: Task) -> Void {
        lock.withLock {
            tasks.insert(task)
        }
    }

    private func buildGraph() -> Dictionary<Task, [Task]> {
        var graphUniq = Dictionary<Task, Reference<Set<Task>>>()
        let copyTasks: Set<Task>

        lock.lock()
        do {
            defer {
                lock.unlock()
            }
            copyTasks = tasks
        }

        for task in copyTasks {
            var fromArray = graphUniq.computeIfAbsent(task) {
                Reference(Set<Task>())
            }

            task.getDependencies().forEach { (dep) in
                fromArray.value.insert(dep)
            }
        }

        var graphSorted = Dictionary<Task, [Task]>()
        for (from, to) in graphUniq {
            var toArray = Array(to.value)
            toArray.sort {
                $0.priority < $1.priority
            }
            graphSorted[from] = toArray
        }

        return graphSorted
    }

    private func topologicalSortUtil(_ graph: inout Dictionary<Task, [Task]>,
                                     _ from: Task,
                                     _ visited: inout Set<Task>,
                                     _ stack: inout [Task]) {
        guard visited.insert(from).inserted else {
            return
        }

        guard let toArray = graph[from] else {
            return
        }

        for to in toArray {
            topologicalSortUtil(&graph, to, &visited, &stack);
        }

        stack.append(from)
    }


    private func topologicalSort(_ graph: inout Dictionary<Task, [Task]>) throws -> [Task] {
        var stack = [Task]()
        var visited = Set<Task>()

        for from in graph.keys {
            topologicalSortUtil(&graph, from, &visited, &stack)
        }

        stack.reverse()

        try throwOnCycle(&graph, &stack)

        return stack
    }

    private func throwOnCycle(_ graph: inout Dictionary<Task, [Task]>,
                              _ stack: inout [Task]) throws {
        var pos = Dictionary<Task, Int>()

        for (index, task) in stack.enumerated() {
            pos[task] = index
        }

        for (leftIndex, leftTask) in stack.enumerated() {
            guard let rightTasks = graph[leftTask] else {
                continue
            }

            for rightTask in rightTasks {
                guard let rightIndex = pos[rightTask] else {
                    throw TaskManagerError.taskNotAdded
                }
                guard leftIndex < rightIndex else {
                    throw TaskManagerError.taskCycle
                }
            }
        }
    }

    /**
     Делает топологическую сортировку на графе зависимостей.
     Если был найден цикл, будет кинуто исключение.
     */
    func buildTasksSnapshot() throws -> Snapshot {
        var graph = buildGraph()
        let stack = try topologicalSort(&graph)
        return Snapshot(queue, stack)
    }

    class Snapshot {
        private let stack: [Task]
        private let queue: DispatchQueue

        fileprivate init(_ queue: DispatchQueue, _ stack: [Task]) {
            self.queue = queue
            self.stack = stack
        }

        func execute() {
            for task in stack {
                queue.async {
                    task.execute()
                }
            }
        }
    }
}
