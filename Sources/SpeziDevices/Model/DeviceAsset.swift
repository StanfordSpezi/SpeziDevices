//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//


/// Description of a asset for a device.
public struct DeviceAsset {
    enum DeviceDescriptor { // TODO: share that with DiscoveryDescriptor!
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

    func matches(name: String) -> Bool { // TODO: not the final solution!
        // TODO:
        switch descriptor {
        case .name(let name0, _):
            name0 == name // TODO: substring!
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


import AccessorySetupKit
import SpeziBluetooth
@available(iOS 18, *)
extension DeviceAsset {
    func pickerDisplayItem(for discovery: DiscoveryCriteria) -> ASPickerDisplayItem {
        let name = switch descriptor {
        case let .name(name, _):
            // TODO: this is used to match the name of the device and doesn't provide a name!
            name // TODO: substring doesn't make sense!
        }

        guard let image = asset.uiImage ?? UIImage(systemName: "sensor") else {
            preconditionFailure("Failed to retrieve 'sensor' system image.")
        }

        let descriptor = discovery.discoveryDescriptor

        return ASPickerDisplayItem(name: name, productImage: image, descriptor: descriptor)
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

    // TODO: not the final solution!
    func firstAsset(name: String) -> ImageReference? {
        first { asset in
            asset.matches(name: name)
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
