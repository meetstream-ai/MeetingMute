import AppKit
import CoreAudio
import MeetingMuteCore

/// Which processes are recording audio, read from Core Audio. Needs no permission and
/// records nothing: it only reads each process's "input is running" flag.
enum AudioInput {
    private static var system: AudioObjectID { AudioObjectID(kAudioObjectSystemObject) }

    private static var processListAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    /// Apple documents no first macOS version for the per-process API, so probe for it.
    static let hasProcessList: Bool = {
        var address = processListAddress
        return AudioObjectHasProperty(system, &address)
    }()

    /// Bundle IDs of processes with audio input running. Uses the default input device when the
    /// per-process API is missing (early macOS 14): then it reports running meeting apps while
    /// the microphone is busy.
    static func recordingBundleIDs() -> [String] {
        if hasProcessList { return processBundleIDs() }
        guard defaultInputIsRunning() else { return [] }
        return NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
            .filter { id in MeetingApp.matching(id).map { !$0.isBrowser } ?? false }
    }

    private static func processBundleIDs() -> [String] {
        var address = processListAddress
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.stride)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr else { return [] }
        processes = Array(processes.prefix(Int(size) / MemoryLayout<AudioObjectID>.stride))

        return processes.compactMap { process in
            var running: UInt32 = 0
            var length = UInt32(MemoryLayout<UInt32>.size)
            address.mSelector = kAudioProcessPropertyIsRunningInput
            guard AudioObjectGetPropertyData(process, &address, 0, nil, &length, &running) == noErr,
                  running != 0 else { return nil }
            var bundleID: Unmanaged<CFString>?
            length = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            address.mSelector = kAudioProcessPropertyBundleID
            guard AudioObjectGetPropertyData(process, &address, 0, nil, &length, &bundleID) == noErr else { return nil }
            return bundleID?.takeRetainedValue() as String?
        }
    }

    private static func defaultInputIsRunning() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &device) == noErr, device != 0 else {
            return false
        }
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }
}
