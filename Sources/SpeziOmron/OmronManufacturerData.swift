//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore
import SpeziBluetooth


/// Omron Manufacturer Data format.
public struct OmronManufacturerData {
    /// The device's pairing mode.
    public enum PairingMode {
        /// The device is advertising to transfer data.
        case transferMode
        /// The device is advertising to get paired.
        case pairingMode
    }

    /// The streaming mode.
    public enum StreamingMode {
        /// Data Communication.
        case dataCommunication
        /// Streaming.
        case streaming
    }

    /// The services mode.
    public enum ServiceMode {
        /// Uses Bluetooth standard services and characteristics.
        case bluetoothStandard
        /// Uses services and characteristics of the Omron Extension.
        case omronExtension
    }

    /// Metadata of a user slot.
    public struct UserSlot {
        /// The user slot number.
        public let id: UInt8
        /// The current record sequence number.
        public let sequenceNumber: UInt16
        /// The amount of records currently stored on the device.
        public let recordsNumber: UInt8


        /// Create a new user slot.
        /// - Parameters:
        ///   - id: The user slot number.
        ///   - sequenceNumber: The current record sequence number.
        ///   - recordsNumber: The amount of records currently stored on the device.
        public init(id: UInt8, sequenceNumber: UInt16, recordsNumber: UInt8) {
            self.id = id
            self.sequenceNumber = sequenceNumber
            self.recordsNumber = recordsNumber
        }
    }

    fileprivate struct Flags: OptionSet {
        static let timeNotSet = Flags(rawValue: 1 << 2)
        static let pairingMode = Flags(rawValue: 1 << 3)
        static let streamingMode = Flags(rawValue: 1 << 4)
        static let wlpStp = Flags(rawValue: 1 << 5)

        let rawValue: UInt8

        var numberOfUsers: UInt8 {
            rawValue & 0x3 + 1
        }

        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        init(numberOfUsers: UInt8) {
            precondition(numberOfUsers > 0 && numberOfUsers <= 4, "Only 4 users are supported and at least one.")
            self.rawValue = numberOfUsers - 1
        }
    }

    /// Indicate if the time was set on the device.
    public let timeSet: Bool
    /// Determine the pairing mode the device is currently in.
    public let pairingMode: PairingMode
    /// The type of data transmission mode.
    public let streamingMode: StreamingMode
    /// The type of services the peripheral is exposing.
    public let servicesMode: ServiceMode

    /// The advertised user slots.
    ///
    /// - Important: Exposes at least one, and a maximum of four slots.
    public let users: [UserSlot]


    /// Create new Omron Manufacture Data
    /// - Parameters:
    ///   - timeSet: Indicate if the time was set.
    ///   - pairingMode: The pairing mode.
    ///   - streamingMode: The streaming mode.
    ///   - servicesMode: The services mode.
    ///   - users: The list of users. At least one, maximum four.
    public init( // swiftlint:disable:this function_default_parameter_at_end
        timeSet: Bool = true,
        pairingMode: PairingMode,
        streamingMode: StreamingMode = .dataCommunication,
        servicesMode: Mode = .bluetoothStandard,
        users: [UserSlot]
    ) {
        // swiftlint:disable:next empty_count
        precondition(users.count > 0 && users.count <= 4, "Only 4 users are supported and at least one.")
        self.timeSet = timeSet
        self.pairingMode = pairingMode
        self.streamingMode = streamingMode
        self.mode = servicesMode
        self.users = users
    }
}


extension OmronManufacturerData.UserSlot: Identifiable {}


extension OmronManufacturerData.Flags: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let rawValue = UInt8(from: &byteBuffer) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
}


extension OmronManufacturerData: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let companyIdentifier = ManufacturerIdentifier(from: &byteBuffer) else {
            return nil
        }

        guard companyIdentifier == .omronHealthcareCoLtd else {
            return nil
        }

        guard let dataType = UInt8(from: &byteBuffer),
              dataType == 0x01 else { // 0x01 signifies start of "Each User Data"
            return nil
        }

        guard let flags = Flags(from: &byteBuffer) else {
            return nil
        }

        self.timeSet = !flags.contains(.timeNotSet)
        self.pairingMode = flags.contains(.pairingMode) ? .pairingMode : .transferMode
        self.streamingMode = flags.contains(.streamingMode) ? .streaming : .dataCommunication
        self.servicesMode = flags.contains(.wlpStp) ? .bluetoothStandard : .omronExtension

        var userSlots: [UserSlot] = []
        for userNumber in 1...flags.numberOfUsers {
            guard let sequenceNumber = UInt16(from: &byteBuffer),
                  let numberOfData = UInt8(from: &byteBuffer) else {
                return nil
            }

            let userData = UserSlot(id: userNumber, sequenceNumber: sequenceNumber, recordsNumber: numberOfData)
            userSlots.append(userData)
        }
        self.users = userSlots
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        ManufacturerIdentifier.omronHealthcareCoLtd.encode(to: &byteBuffer)
        UInt8(0x01).encode(to: &byteBuffer)

        var flags = Flags(numberOfUsers: UInt8(users.count))

        if !timeSet {
            flags.insert(.timeNotSet)
        }

        if case .pairingMode = pairingMode {
            flags.insert(.pairingMode)
        }

        if case .streaming = streamingMode {
            flags.insert(.streamingMode)
        }

        if case .bluetoothStandard = servicesMode {
            flags.insert(.wlpStp)
        }

        flags.encode(to: &byteBuffer)

        for user in users {
            user.sequenceNumber.encode(to: &byteBuffer)
            user.recordsNumber.encode(to: &byteBuffer)
        }
    }
}
