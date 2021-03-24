# WorkSequencer

A simple Combine-based work queue. Supports appending or intelligently replacing all work items.

## Functional Style

You can create units of work with a function. Here's what that looks like, with both
blocking/immediate completions and delayed/signaled completions.

In this style each function is given a unique UUID.

```swift
/// Create a functional sequencer. This one has three concurrent workers
/// and executes work on the main queue.
let sequencer = FnWorkSequencer(workers: 3, scheduler: DispatchQueue.main.eraseToAnyScheduler())

/// Start processing work.
sequencer.start()

// Perform some work
sequencer.append {
    print("Immediate done!")
    return WorkCompleted()
}

// Perform work that takes time by sending a signal when it's done.
sequencer.append {
    let signal = Just("Delayed done!")
        .delay(for: .milliseconds(10), scheduler: DispatchQueue.main)
        .handleEvents(receiveOutput: { message in
            print(message)
        })
    return WorkInProgress(signal)
}
```

## Structural Style

Adopt the `Workable` protocol to define a unit of work.

```swift
/// A work item is an identifiable unit of work
public protocol Workable: Identifiable {
    func work() -> WorkSignal
}
```
An example of using `Workable`. In this style you define the ID of each unit of work.

```swift
/// Anything can be workable
struct Printer: Workable {
    var id: String
    func work() -> WorkSignal {
        print(id)
        return WorkCompleted()
    }
}

/// Create a sequencer matching our work's identifier.
let sequencer = WorkSequencer<String>(scheduler: DispatchQueue.main.eraseToAnyScheduler())

/// Start processing work.
sequencer.start()

/// Do some work.
sequencer.append(Printer(id: "Hello"))
sequencer.append(Printer(id: "World"))
```

## Replacing all work

The driver for this package was the ability to process a set of jobs, where the order of jobs is important. 
That set of jobs can change over time; adding, removing, or modifying each job. I wanted to intelligently
replace the set of jobs, handling in-flight, upcoming and removed jobs correctly.

```swift
let hello = Printer(id: "Hello")
let goodbye = Printer(id: "Goodbye")
let cruel = Printer(id: "Cruel")
let world = Printer(id: "World")

/// Start processing work.
sequencer.start()

// The initial set of work
sequencer.replace(items: [goodbye, cruel, world])

// The updated set of work
sequencer.replace(items: [hello, world])

// Prints: "Goodbye, Hello, World" because Goodbye starts before it's replaced.
```

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
