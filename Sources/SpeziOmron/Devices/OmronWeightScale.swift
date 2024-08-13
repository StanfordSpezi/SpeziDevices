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
public final class OmronWeightScale: BluetoothDevice, Identifiable, OmronHealthDevice, @unchecked Sendable {
    public static var assets: [DeviceAsset] {
        [
            .name("SC-150", .asset("Omron-SC-150", bundle: .module))
        ]
    }

    private let logger = Logger(subsystem: "ENGAGEHF", category: "WeightScale")

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

    @Dependency(HealthMeasurements.self) private var measurements: HealthMeasurements?
    @Dependency(PairedDevices.self) private var pairedDevices: PairedDevices?

    private var didReceiveFirstTimeNotification = false

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
            measurements.configureReceivingMeasurements(for: self, on: \.weightScale)
        }
    }

    private func handleStateChange(_ state: PeripheralState) async {
        logger.debug("\(Self.self) changed state to \(state).")
        switch state {
        case .connecting, .connected:
            break
        case .disconnected, .disconnecting:
            didReceiveFirstTimeNotification = false
        }
    }

    @MainActor
    private func handleCurrentTimeChange(_ time: CurrentTime) {
        // TODO: only update the first time, do we have that web page still open???
        logger.debug("Received updated device time for \(self.label): \(String(describing: time))")

        // TODO: filter for notifications happening while being in disconnected state?

        // for Omron we take that as a signal that device is paired // TODO: does this work now for all weight scales?
        let didPair = pairedDevices?.signalDevicePaired(self) == true // TODO: do we need to result still?

        if !didReceiveFirstTimeNotification {
            didReceiveFirstTimeNotification = true
            self.time.synchronizeDeviceTime()
        }
        // TODO: apply this changes for the blood pressure cuff as well!
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
        device.$name.inject("SC-150")
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

        let advertisementData = AdvertisementData(manufacturerData: manufacturerData.encode())
        device.$advertisementData.inject(advertisementData)

        device.$connect.inject { @MainActor [weak device] in
            guard let device else {
                return
            }

            device.$state.inject(.connecting)

            try? await Task.sleep(for: .seconds(2))

            if case .connecting = device.state {
                device.$state.inject(.connected)

                if case .pairingMode = device.manufacturerData?.pairingMode {
                    try? await Task.sleep(for: .seconds(1))
                    device.time.$currentTime.inject(CurrentTime(time: .init(from: .now)))
                }
            }
        }

        device.$disconnect.inject { @MainActor [weak device] in
            device?.$state.inject(.disconnected)
        }

        device.$state.enableSubscriptions()
        device.$advertisementData.enableSubscriptions()
        device.$nearby.enableSubscriptions()

        device.time.$currentTime.enableSubscriptions()
        device.time.$currentTime.enablePeripheralSimulation()

        device.weightScale.$weightMeasurement.enableSubscriptions()
        device.weightScale.$weightMeasurement.enablePeripheralSimulation()

        return device
    }
}
