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

    private let descriptor: DeviceDescriptor
    fileprivate let asset: ImageReference


    func matches(for pairedDevice: PairedDeviceInfo) -> Bool {
        switch descriptor {
        case let .name(substring, isSubstring):
            return isSubstring
                ? pairedDevice.peripheralName?.hasPrefix(substring) == true
                : pairedDevice.peripheralName == substring
        }
    }

    func matches(for device: some GenericDevice) -> Bool {
        switch descriptor {
        case let .name(substring, isSubstring):
            return isSubstring
                ? device.name?.hasPrefix(substring) == true
                : device.name == substring
        }
    }
}


extension DeviceAsset {
    /// Define an asset for devices with a given name.
    ///
    /// - Parameters:
    ///   - name: The name of the peripheral. The provided `asset` will be used if the name matches the peripherals name.
    ///   - asset: The image to use.
    public static func name(_ name: String, _ asset: ImageReference) -> DeviceAsset {
        DeviceAsset(descriptor: .name(name, isSubstring: false), asset: asset)
    }
}


extension Array where Element == DeviceAsset {
    /// Retrieve the first matching asset for the given paired device info.
    /// - Parameter pairedDevice: The paired device info.
    /// - Returns: The first matching asset or `nil` if none were found.
    public func firstAsset(for pairedDevice: PairedDeviceInfo) -> ImageReference? {
        first { asset in
            asset.matches(for: pairedDevice)
        }?.asset
    }


    /// Retrieve the first matching asset for the given device.
    /// - Parameter device: The device.
    /// - Returns: The first matching asset or `nil` if none were found.
    public func firstAsset(for device: some GenericDevice) -> ImageReference? {
        first { asset in
            asset.matches(for: device)
        }?.asset
    }
}
