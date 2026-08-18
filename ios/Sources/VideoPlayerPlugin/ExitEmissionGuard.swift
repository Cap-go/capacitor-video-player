import Foundation

struct ExitEmissionGuard {
    private(set) var didEmit = false

    mutating func emitIfNeeded(_ action: () -> Void) {
        guard !didEmit else { return }
        didEmit = true
        action()
    }
}
