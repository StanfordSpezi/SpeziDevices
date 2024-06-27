//
// This source file is part of the ENGAGE-HF project based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation
import OSLog
@_spi(TestingSupport) import SpeziBluetooth
import SpeziBluetoothServices
import SpeziDevices


/// Implementation of Omron SC150 Weight Scale.
public class OmronWeightScale: BluetoothDevice, Identifiable, OmronHealthDevice {
    private static let logger = Logger(subsystem: "ENGAGEHF", category: "WeightScale")

    @DeviceState(\.id) public var id: UUID
    @DeviceState(\.name) public var name: String?
    @DeviceState(\.state) public var state: PeripheralState
    @DeviceState(\.advertisementData) public var advertisementData: AdvertisementData
    @DeviceState(\.nearby) public var nearby

    @Service public var deviceInformation = DeviceInformationService()

    @Service public var time = CurrentTimeService()
    @Service public var weightScale = WeightScaleService()

    @DeviceAction(\.connect) public var connect
    @DeviceAction(\.disconnect) public var disconnect

    @Dependency private var measurements: HealthMeasurements?
    @Dependency private var pairedDevices: PairedDevices?

    private var dateOfConnection: Date?

    public var icon: ImageReference? {
        .asset("Omron-SC-150", bundle: .module)
    }

    /// Initialize the device.
    public required init() {}

    public func configure() {
        $state.onChange { [weak self] value in
            await self?.handleStateChange(value)
        }

        time.$currentTime.onChange { [weak self] value in
            await self?.handleCurrentTimeChange(value)
        }

        if let pairedDevices {
            pairedDevices.configure(device: self, accessing: $state, $advertisementData, $nearby)
        }
        if let measurements {
            measurements.configureReceivingMeasurements(for: self, on: weightScale)
        }
    }

    private func handleStateChange(_ state: PeripheralState) async {
        switch state {
        case .connected:
            switch manufacturerData?.pairingMode {
            case .pairingMode:
                print("Device connection is NOW!")
                dateOfConnection = .now
            case .transferMode:
                time.synchronizeDeviceTime()
            case nil:
                break
            }
        default:
            break
        }
    }

    @MainActor
    private func handleCurrentTimeChange(_ time: CurrentTime) {
        if case .pairingMode = manufacturerData?.pairingMode,
           let dateOfConnection,
           abs(Date.now.timeIntervalSince1970 - dateOfConnection.timeIntervalSince1970) < 1 {
            // if its pairing mode, and we just connected, we ignore the first current time notification as its triggered
            // because of the notification registration.
            return
        }

        Self.logger.debug("Received updated device time for \(self.label): \(String(describing: time))")
        let paired = pairedDevices?.signalDevicePaired(self) == true
        if paired {
            dateOfConnection = nil
            self.time.synchronizeDeviceTime()
        }
    }
}


extension OmronWeightScale {
    /// Create a mock instance.
    /// - Parameters:
    ///   - weight: The weight value.
    ///   - resolution: The weight resolution.
    ///   - state: The initial state.
    ///   - nearby: The nearby state.
    ///   - manufacturerData: The initial manufacturer data.
    /// - Returns: Returns the mock device instance.
    public static func createMockDevice(
        weight: UInt16 = 8400,
        resolution: WeightScaleFeature.WeightResolution = .resolution5g,
        state: PeripheralState = .disconnected,
        nearby: Bool = true,
        manufacturerData: OmronManufacturerData = OmronManufacturerData(pairingMode: .pairingMode, users: [
            .init(id: 1, sequenceNumber: 2, recordsNumber: 1)
        ])
    ) -> OmronWeightScale {
        let device = OmronWeightScale()

        device.$id.inject(UUID())
        device.$name.inject("Mock Health Scale")
        device.$state.inject(state)
        device.$nearby.inject(nearby)

        device.deviceInformation.$manufacturerName.inject("Mock Weight Scale")
        device.deviceInformation.$modelNumber.inject(OmronModel.sc150.rawValue)
        device.deviceInformation.$hardwareRevision.inject("2")
        device.deviceInformation.$firmwareRevision.inject("1.0")

        // mocks the values as reported by the real device
        let features = WeightScaleFeature(
            weightResolution: resolution,
            heightResolution: .unspecified,
            options: .timeStampSupported
        )

        let measurement = WeightMeasurement(
            weight: weight,
            unit: .si
        )

        device.weightScale.$features.inject(features)
        device.weightScale.$weightMeasurement.inject(measurement)

        let advertisementData = AdvertisementData([
            CBAdvertisementDataManufacturerDataKey: manufacturerData.encode()
        ])
        device.$advertisementData.inject(advertisementData)

        device.$connect.inject { @MainActor [weak device] in
            guard let device else {
                return
            }

            device.$state.inject(.connecting)

            try? await Task.sleep(for: .seconds(1))

            if case .connecting = device.state {
                device.$state.inject(.connected)
            }
        }

        device.$disconnect.inject { @MainActor [weak device] in
            device?.$state.inject(.disconnected)
        }

        device.$state.enableSubscriptions()
        device.$advertisementData.enableSubscriptions()
        device.$nearby.enableSubscriptions()

        device.weightScale.$weightMeasurement.enableSubscriptions()
        device.weightScale.$weightMeasurement.enablePeripheralSimulation()

        return device
    }
}
