import Foundation
import Carbon

final class HotkeyManager {
    typealias Handler = () -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var onDown: Handler?
    private var onUp: Handler?

    // 'MPie' four-char code: 0x4D506965
    private let hotKeyID = EventHotKeyID(signature: OSType(0x4D506965), id: 1)

    func register(keyCode: UInt32 = 49, modifiers: UInt32 = UInt32(optionKey), onDown: @escaping Handler, onUp: @escaping Handler) {
        unregister()
        self.onDown = onDown
        self.onUp = onUp

        let specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let callback: EventHandlerUPP = { (_, event, userData) in
            guard let userData = userData, let event = event else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            let kind = GetEventKind(event)
            if kind == UInt32(kEventHotKeyPressed) {
                manager.onDown?()
            } else if kind == UInt32(kEventHotKeyReleased) {
                manager.onUp?()
            }
            return noErr
        }

        let userData = Unmanaged.passUnretained(self).toOpaque()
        specs.withUnsafeBufferPointer { ptr in
            InstallEventHandler(GetEventDispatcherTarget(), callback, Int(ptr.count), ptr.baseAddress, userData, &eventHandlerRef)
        }

        var hotKey = hotKeyRef
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKey)
        hotKeyRef = hotKey
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil

        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
        eventHandlerRef = nil

        onDown = nil
        onUp = nil
    }

    deinit { unregister() }
} 