//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//


/// Description of a asset for a device.
public struct DeviceAsset {
    enum DeviceDescriptor {
        case name(_ substring: String, isSubstring: Bool)
    }

    let descriptor: DeviceDescriptor
    let asset: ImageReference


    func matches(pairedDevice: PairedDeviceInfo) -> Bool {
        switch descriptor {
        case let .name(substring, isSubstring):
            return isSubstring
                ? pairedDevice.peripheralName?.hasPrefix(substring) == true
                : pairedDevice.peripheralName == substring
        }
    }

    func matches(device: some GenericDevice) -> Bool {
        switch descriptor {
        case let .name(substring, isSubstring):
            return isSubstring
                ? device.name?.hasPrefix(substring) == true
                : device.name == substring
        }
    }
}


extension DeviceAsset {
    public static func name(_ name: String, _ asset: ImageReference) -> DeviceAsset {
        DeviceAsset(descriptor: .name(name, isSubstring: false), asset: asset)
    }
}
