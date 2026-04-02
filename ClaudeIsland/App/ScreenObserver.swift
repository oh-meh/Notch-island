//
//  ScreenObserver.swift
//  ClaudeIsland
//
//  Monitors screen configuration changes
//

import AppKit

class ScreenObserver {
    private var observer: Any?
    private let onScreenChange: () -> Void
    private var debounceWork: DispatchWorkItem?

    init(onScreenChange: @escaping () -> Void) {
        self.onScreenChange = onScreenChange
        startObserving()
    }

    deinit {
        stopObserving()
    }

    private func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.debounceScreenChange()
        }
    }

    /// Debounce rapid-fire screen parameter notifications (e.g., display wake,
    /// resolution changes, or window creation that re-triggers the notification).
    private func debounceScreenChange() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onScreenChange()
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func stopObserving() {
        debounceWork?.cancel()
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
