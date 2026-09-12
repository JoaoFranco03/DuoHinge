//
//  LidAngleSensor.swift
//  Adapted from Sam Henri Gold's LidAngleSensor (Apache-2.0).
//  https://github.com/samhenrigold/LidAngleSensor
//  Modified for callback-based readings, app lifecycle, and reporting-interval restoration.
//  See THIRD_PARTY_NOTICES.md and Licenses/LidAngleSensor-Apache-2.0.txt.
//

import AppKit
import Foundation
import IOKit.hid
import Observation

/// Reads the MacBook's built-in lid-angle HID sensor. The hardware is not present on every Mac.
@Observable @MainActor
final class LidAngleSensor {
    @ObservationIgnored private(set) var angle = 120.0
    @ObservationIgnored private(set) var sampleTime = 0.0
    private(set) var isAvailable = false
    private(set) var statusMessage = "Looking for the MacBook lid angle sensor…"

    @ObservationIgnored private var manager: IOHIDManager?
    @ObservationIgnored private var isOpen = false
    @ObservationIgnored private var driver: io_service_t = 0
    @ObservationIgnored private var originalInterval: CFTypeRef?
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?

    init() {
        let options = IOOptionBits(kIOHIDOptionsTypeNone)
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, options)
        guard IOHIDManagerOpen(manager, options) == kIOReturnSuccess else {
            statusMessage = "Could not access the HID manager."
            return
        }
        defer { IOHIDManagerClose(manager, options) }

        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: 0x8104,
            "PrimaryUsagePage": 0x0020,
            "PrimaryUsage": 0x008A,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
            !devices.isEmpty
        else {
            statusMessage = "This Mac does not expose a supported lid angle sensor."
            return
        }

        // Device discovery can precede the first report. Availability is based on
        // HID enumeration; readings begin after the run-loop session opens.
        isAvailable = true
        if let initialAngle = Self.readCurrentAngle(from: devices) {
            angle = initialAngle
            statusMessage = "Physical MacBook hinge connected."
        } else {
            statusMessage = "Physical MacBook hinge found; waiting for its first reading."
        }
    }

    func start() {
        guard isAvailable, !isOpen else { return }
        let options = IOOptionBits(kIOHIDOptionsTypeNone)
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, options)
        let deviceMatch: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: 0x8104,
            "PrimaryUsagePage": 0x0020,
            "PrimaryUsage": 0x008A,
        ]
        IOHIDManagerSetDeviceMatching(manager, deviceMatch as CFDictionary)
        // Do not set an input-value match here. On macOS 27, a match can be applied before the
        // LAS elements are enumerated and suppress the first event stream; filter in the callback.
        IOHIDManagerRegisterInputValueCallback(
            manager,
            { context, result, _, value in
                guard result == kIOReturnSuccess, let context else { return }
                let element = IOHIDValueGetElement(value)
                guard IOHIDElementGetUsagePage(element) == 0x0020,
                    IOHIDElementGetUsage(element) == 0x047F
                else { return }
                let sensor = Unmanaged<LidAngleSensor>.fromOpaque(context).takeUnretainedValue()
                let angle = Double(IOHIDValueGetIntegerValue(value))
                // This manager is scheduled on the main run loop. Avoid another queued hop.
                MainActor.assumeIsolated { sensor.receiveAngle(angle) }
            },
            Unmanaged.passUnretained(self).toOpaque()
        )
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        guard IOHIDManagerOpen(manager, options) == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            isAvailable = false
            statusMessage =
                "The lid angle sensor could not be opened. Quit other lid-sensor utilities and reopen this app."
            return
        }
        self.manager = manager
        isOpen = true
        requestFastReporting()
        if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
            let initialAngle = Self.readCurrentAngle(from: devices)
        {
            receiveAngle(initialAngle)
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
        if statusMessage.contains("waiting") {
            statusMessage = "Physical MacBook hinge connected; waiting for its first reading."
        }
    }

    func stop() {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
            self.terminationObserver = nil
        }
        if driver != 0 {
            if let originalInterval {
                let result = IORegistryEntrySetCFProperty(driver, "ReportInterval" as CFString, originalInterval)
                if result != kIOReturnSuccess { NSLog("LAS interval restore failed: %d", result) }
            }
            IOObjectRelease(driver)
            driver = 0
            originalInterval = nil
        }
        if isOpen, let manager {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            self.manager = nil
            isOpen = false
        }
    }

    @discardableResult
    func fetchCurrentAngle() -> Double? {
        guard isAvailable else { return nil }
        if let manager, isOpen,
            let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
            let currentAngle = Self.readCurrentAngle(from: devices)
        {
            receiveAngle(currentAngle)
            return currentAngle
        }
        return nil
    }

    private static func readCurrentAngle(from devices: Set<IOHIDDevice>) -> Double? {
        let elementMatching: [String: Any] = [
            kIOHIDElementUsagePageKey as String: 0x0020,
            kIOHIDElementUsageKey as String: 0x047F,
        ]
        for device in devices {
            guard
                let elements = IOHIDDeviceCopyMatchingElements(
                    device, elementMatching as CFDictionary, IOOptionBits(kIOHIDOptionsTypeNone)
                ) as? [IOHIDElement]
            else { continue }

            for element in elements {
                var valueRef: Unmanaged<IOHIDValue>?
                let result = withUnsafeMutablePointer(to: &valueRef) { ptr in
                    ptr.withMemoryRebound(to: Unmanaged<IOHIDValue>.self, capacity: 1) { reboundPtr in
                        IOHIDDeviceGetValue(device, element, reboundPtr)
                    }
                }
                if result == kIOReturnSuccess, let value = valueRef?.takeUnretainedValue() {
                    let angle = Double(IOHIDValueGetIntegerValue(value))
                    if angle.isFinite, (0...360).contains(angle) {
                        return angle
                    }
                }
            }
        }
        return nil
    }

    private func requestFastReporting() {
        var iterator: io_iterator_t = 0
        guard
            IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSPUHIDDriver"), &iterator)
                == kIOReturnSuccess
        else { return }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            let product =
                IORegistryEntryCreateCFProperty(service, "Product" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String
            guard product == "las", driver == 0,
                let previous = IORegistryEntryCreateCFProperty(
                    service, "ReportInterval" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            else {
                IOObjectRelease(service)
                continue
            }
            // An 8 ms request produced ~100 ms angle updates on the tested M2 Pro.
            // Requesting a rate does not imply that the hardware delivers that rate.
            let result = IORegistryEntrySetCFProperty(service, "ReportInterval" as CFString, NSNumber(value: 8000))
            if result == kIOReturnSuccess {
                driver = service
                originalInterval = previous
            } else {
                NSLog("LAS fast reporting request failed: %d", result)
                IOObjectRelease(service)
            }
        }
    }

    fileprivate func receiveAngle(_ value: Double) {
        guard isOpen, value.isFinite, (0...360).contains(value) else { return }
        angle = value
        sampleTime = ProcessInfo.processInfo.systemUptime
        statusMessage = "Physical MacBook hinge connected."
    }
}
