import Foundation

let a = Task(name: "a", priority: 10)
let b = Task(name: "b", priority: 8)
let c = Task(name: "c", priority: 11)
let d = Task(name: "d", priority: 11)

a.addDependency(b)
//b.addDependency(a)
a.addDependency(c)
d.addDependency(a)

let myQueue = DispatchQueue(label: "my")
let disp = TaskManager(queue: myQueue)

disp.add(a)
disp.add(b)
disp.add(c)
disp.add(d)

do {
    try disp.buildTasksSnapshot().execute()
} catch {
    print(error)
}

sleep(1)