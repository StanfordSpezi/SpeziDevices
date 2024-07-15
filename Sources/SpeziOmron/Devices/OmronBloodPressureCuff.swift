//
// This source file is part of the Stanford SpeziDevices open source project
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
import SpeziNumerics


/// Implementation of Omron BP5250 Blood Pressure Cuff.
public final class OmronBloodPressureCuff: BluetoothDevice, Identifiable, OmronHealthDevice, BatteryPoweredDevice, @unchecked Sendable {
    public static var icon: ImageReference? {
        .asset("Omron-BP5250", bundle: .module)
    }

    private let logger = Logger(subsystem: "ENGAGEHF", category: "BloodPressureCuffDevice")

    @DeviceState(\.id) public var id: UUID
    @DeviceState(\.name) public var name: String?
    @DeviceState(\.state) public var state: PeripheralState
    @DeviceState(\.advertisementData) public var advertisementData: AdvertisementData
    @DeviceState(\.nearby) public var nearby

    @Service public var deviceInformation = DeviceInformationService()

    @Service public var time = CurrentTimeService()
    @Service public var battery = BatteryService()
    @Service public var bloodPressure = BloodPressureService()

    @DeviceAction(\.connect) public var connect
    @DeviceAction(\.disconnect) public var disconnect

    @Dependency private var measurements: HealthMeasurements?
    @Dependency private var pairedDevices: PairedDevices?

    /// Initialize the device.
    public required init() {}

    public func configure() {
        $state.onChange { [weak self] value in
            await self?.handleStateChange(value)
        }

        battery.$batteryLevel.onChange { [weak self] value in
            await self?.handleBatteryChange(value)
        }
        time.$currentTime.onChange { [weak self] value in
            await self?.handleCurrentTimeChange(value)
        }

        if let pairedDevices {
            pairedDevices.configure(device: self, accessing: $state, $advertisementData, $nearby)
        }
        if let measurements {
            measurements.configureReceivingMeasurements(for: self, on: bloodPressure)
        }
    }

    private func handleStateChange(_ state: PeripheralState) async {
        if case .connected = state,
           case .transferMode = manufacturerData?.pairingMode {
            time.synchronizeDeviceTime()
        }
    }

    @MainActor
    private func handleBatteryChange(_ level: UInt8) {
        pairedDevices?.signalDevicePaired(self)
    }

    @MainActor
    private func handleCurrentTimeChange(_ time: CurrentTime) {
        logger.debug("Received updated device time for \(self.label) is \(String(describing: time))")
        let paired = pairedDevices?.signalDevicePaired(self)

        if paired == true {
            self.time.synchronizeDeviceTime()
        }
    }
}


@_spi(TestingSupport)
extension OmronBloodPressureCuff {
    /// Create a mock instance.
    /// - Parameters:
    ///   - systolic: The mock systolic value.
    ///   - diastolic: The mock diastolic value.
    ///   - pulseRate: The mock pulse rate value.
    ///   - state: The initial state.
    ///   - nearby: The nearby state.
    ///   - manufacturerData: The initial manufacturer data.
    /// - Returns: Returns the mock device instance.
    public static func createMockDevice( // swiftlint:disable:this function_body_length
        systolic: MedFloat16 = 103,
        diastolic: MedFloat16 = 64,
        pulseRate: MedFloat16 = 62,
        state: PeripheralState = .disconnected,
        nearby: Bool = true,
        manufacturerData: OmronManufacturerData = OmronManufacturerData(pairingMode: .pairingMode, users: [
            .init(id: 1, sequenceNumber: 2, recordsNumber: 1)
        ])
    ) -> OmronBloodPressureCuff {
        let device = OmronBloodPressureCuff()

        device.$id.inject(UUID())
        device.$name.inject("BP5250")
        device.$state.inject(state)
        device.$nearby.inject(nearby)

        device.deviceInformation.$manufacturerName.inject("Mock Blood Pressure Cuff")
        device.deviceInformation.$modelNumber.inject(OmronModel.bp5250.rawValue)
        device.deviceInformation.$hardwareRevision.inject("2")
        device.deviceInformation.$firmwareRevision.inject("1.0")

        device.battery.$batteryLevel.inject(85)

        let features: BloodPressureFeature = [
            .bodyMovementDetectionSupported,
            .irregularPulseDetectionSupported
        ]

        let measurement = BloodPressureMeasurement(
            systolic: systolic,
            diastolic: diastolic,
            meanArterialPressure: 77,
            unit: .mmHg,
            timeStamp: DateTime(year: 2024, month: .june, day: 5, hours: 12, minutes: 33, seconds: 11),
            pulseRate: pulseRate,
            userId: 1,
            measurementStatus: []
        )

        device.bloodPressure.$features.inject(features)
        device.bloodPressure.$bloodPressureMeasurement.inject(measurement)

        let advertisementData = AdvertisementData([
            CBAdvertisementDataManufacturerDataKey: manufacturerData.encode()
        ])
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
                    device.battery.$batteryLevel.inject(100)
                }
            }
        }

        device.$disconnect.inject { @MainActor [weak device] in
            device?.$state.inject(.disconnected)
        }

        device.$state.enableSubscriptions()
        device.$advertisementData.enableSubscriptions()
        device.$nearby.enableSubscriptions()

        device.battery.$batteryLevel.enableSubscriptions()
        device.battery.$batteryLevel.enablePeripheralSimulation()

        device.time.$currentTime.enableSubscriptions()
        device.time.$currentTime.enablePeripheralSimulation()

        device.bloodPressure.$bloodPressureMeasurement.enableSubscriptions()
        device.bloodPressure.$bloodPressureMeasurement.enablePeripheralSimulation()

        return device
    }
}
