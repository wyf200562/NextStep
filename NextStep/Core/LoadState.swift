import Foundation

/// The uniform state of an asynchronously loaded value.
///
/// ViewModels own a `LoadState` and map underlying errors to Chinese copy before showing them.
nonisolated enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(any Error)

    var value: Value? {
        guard case .loaded(let value) = self else { return nil }
        return value
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var error: (any Error)? {
        guard case .failed(let error) = self else { return nil }
        return error
    }
}
