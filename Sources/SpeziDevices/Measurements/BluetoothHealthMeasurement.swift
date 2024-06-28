//
// This source file is part of the Stanford SpeziDevices open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetoothServices


/// A measurement retrieved from a Bluetooth device.
///
/// Bluetooth Measurements are represented using standardized measurement characteristics.
public enum BluetoothHealthMeasurement {
    /// A weight measurement and its context.
    case weight(WeightMeasurement, WeightScaleFeature)
    /// A blood pressure measurement and its context.
    case bloodPressure(BloodPressureMeasurement, BloodPressureFeature)

    private var type: SwiftDataBluetoothHealthMeasurementWorkaroundContainer.MeasurementType {
        switch self {
        case .weight:
            .weight
        case .bloodPressure:
            .bloodPressure
        }
    }
}

import SpeziNumerics
import SpeziBluetoothServices
private struct BloodPressureMeasurementCopy: Codable {
    /// The systolic value of the blood pressure measurement.
    ///
    /// The unit of this value is defined by the ``unit-swift.property`` property.
    public let systolicValue: MedFloat16
    /// The diastolic value of the blood pressure measurement.
    ///
    /// The unit of this value is defined by the ``unit-swift.property`` property.
    public let diastolicValue: MedFloat16
    /// The Mean Arterial Pressure (MAP)
    ///
    /// The unit of this value is defined by the ``unit-swift.property`` property.
    public let meanArterialPressure: MedFloat16
    /// The unit of the blood pressure measurement values.
    ///
    /// This property defines the unit of the ``systolicValue``, ``diastolicValue`` and ``meanArterialPressure`` properties.
    public let unit: String

    /// The timestamp of the measurement.
    public let timeStamp: DateTime?

    /// The pulse rate in beats per minute.
    public let pulseRate: UInt16?

    /// The associated user of the blood pressure measurement.
    ///
    /// This value can be used to differentiate users if the device supports multiple users.
    /// - Note: The special value of `0xFF` (`UInt8.max`) is used to represent an unknown user.
    ///
    /// The values are left to the implementation but should be unique per device.
    public let userId: UInt8?

    /// Additional metadata information of a blood pressure measurement.
    public let measurementStatus: UInt16?


    var measurement: BloodPressureMeasurement {
        .init(
            systolic: systolicValue,
            diastolic: diastolicValue,
            meanArterialPressure: meanArterialPressure,
            unit: .init(rawValue: unit) ?? .mmHg,
            timeStamp: timeStamp,
            pulseRate: pulseRate.map { MedFloat16(bitPattern: $0) },
            userId: userId,
            measurementStatus: measurementStatus.map { .init(rawValue: $0) }
        )
    }

    init(from measurement: BloodPressureMeasurement) {
        self.systolicValue = measurement.systolicValue
        self.diastolicValue = measurement.diastolicValue
        self.meanArterialPressure = measurement.meanArterialPressure
        self.unit = measurement.unit.rawValue
        self.timeStamp = measurement.timeStamp
        self.pulseRate = measurement.pulseRate?.bitPattern
        self.userId = measurement.userId
        self.measurementStatus = measurement.measurementStatus?.rawValue
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.systolicValue, forKey: .systolicValue)
        try container.encode(self.diastolicValue, forKey: .diastolicValue)
        try container.encode(self.meanArterialPressure, forKey: .meanArterialPressure)
        try container.encode(self.unit, forKey: .unit)
        try container.encodeIfPresent(self.timeStamp, forKey: .timeStamp)
        try container.encodeIfPresent(self.pulseRate, forKey: .pulseRate)
        try container.encodeIfPresent(self.userId, forKey: .userId)
        try container.encodeIfPresent(self.measurementStatus, forKey: .measurementStatus)
    }

    enum CodingKeys: CodingKey {
        case systolicValue
        case diastolicValue
        case meanArterialPressure
        case unit
        case timeStamp
        case pulseRate
        case userId
        case measurementStatus
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.systolicValue = try container.decode(MedFloat16.self, forKey: .systolicValue)
        self.diastolicValue = try container.decode(MedFloat16.self, forKey: .diastolicValue)
        self.meanArterialPressure = try container.decode(MedFloat16.self, forKey: .meanArterialPressure)
        self.unit = try container.decode(String.self, forKey: .unit)
        self.timeStamp = try container.decodeIfPresent(DateTime.self, forKey: .timeStamp)
        self.pulseRate = try container.decodeIfPresent(UInt16.self, forKey: .pulseRate)
        self.userId = try container.decodeIfPresent(UInt8.self, forKey: .userId)
        self.measurementStatus = try container.decodeIfPresent(UInt16.self, forKey: .measurementStatus)
    }
}

struct SwiftDataBluetoothHealthMeasurementWorkaroundContainer: Codable {
    enum MeasurementType: String, Codable {
        case weight
        case bloodPressure
    }

    private let type: MeasurementType

    private var bloodPressureMeasurement: BloodPressureMeasurementCopy?
    private var bloodPressureFeatures: BloodPressureFeature.RawValue?

    private var weightMeasurement: WeightMeasurement?
    private var weightScaleFeatures: WeightScaleFeature.RawValue?

    var measurement: BluetoothHealthMeasurement {
        switch type {
        case .bloodPressure:
            guard let bloodPressureMeasurement, let bloodPressureFeatures else {
                preconditionFailure("Inconsistent type")
            }
            return .bloodPressure(bloodPressureMeasurement.measurement, .init(rawValue: bloodPressureFeatures))
        case .weight:
            guard let weightMeasurement, let weightScaleFeatures else {
                preconditionFailure("Inconsistent type")
            }
            return .weight(weightMeasurement, .init(rawValue: weightScaleFeatures))
        }
    }

    init(from measurement: BluetoothHealthMeasurement) {
        switch measurement {
        case let .bloodPressure(measurement, feature):
            type = .bloodPressure
            bloodPressureMeasurement = .init(from: measurement)
            bloodPressureFeatures = feature.rawValue
            weightMeasurement = nil
            weightScaleFeatures = nil
        case let .weight(measurement, features):
            type = .weight
            bloodPressureMeasurement = nil
            bloodPressureFeatures = nil
            // bloodPressureMeasurement2 = BloodPressureMeasurementCopy(from: .mock())
            weightMeasurement = measurement
            weightScaleFeatures = features.rawValue
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encodeIfPresent(self.bloodPressureMeasurement, forKey: .bloodPressureMeasurement)
        try container.encodeIfPresent(self.bloodPressureFeatures, forKey: .bloodPressureFeatures)
        try container.encodeIfPresent(self.weightMeasurement, forKey: .weightMeasurement)
        try container.encodeIfPresent(self.weightScaleFeatures, forKey: .weightScaleFeatures)
    }

    enum CodingKeys: CodingKey {
        case type
        case bloodPressureMeasurement
        case bloodPressureFeatures
        case weightMeasurement
        case weightScaleFeatures
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(SwiftDataBluetoothHealthMeasurementWorkaroundContainer.MeasurementType.self, forKey: .type)
        switch type {
        case .bloodPressure:
            self.bloodPressureMeasurement = try container.decodeIfPresent(BloodPressureMeasurementCopy.self, forKey: .bloodPressureMeasurement)
            self.bloodPressureFeatures = try container.decodeIfPresent(BloodPressureFeature.RawValue.self, forKey: .bloodPressureFeatures)
        case .weight:
            self.weightMeasurement = try container.decodeIfPresent(WeightMeasurement.self, forKey: .weightMeasurement)
            self.weightScaleFeatures = try container.decodeIfPresent(WeightScaleFeature.RawValue.self, forKey: .weightScaleFeatures)
        }
    }
}


extension BluetoothHealthMeasurement: Hashable, Sendable {}


extension BluetoothHealthMeasurement: Codable {
    enum MeasurementType: String, Codable {
        case weight
        case bloodPressure
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case bloodPressure
        case bloodPressureFeatures

        case weight
        case weightScaleFeatures
    }

    public init(from decoder: any Decoder) throws {
        do {
            print("Decoding \(Self.self)")
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let type = try container.decode(MeasurementType.self, forKey: .type)
            switch type {
            case .weight:
                let measurement = try container.decode(WeightMeasurement.self, forKey: .bloodPressure)
                let features = try container.decode(WeightScaleFeature.self, forKey: .bloodPressureFeatures)
                self = .weight(measurement, features)
            case .bloodPressure:
                let measurement = try container.decode(BloodPressureMeasurement.self, forKey: .weight)
                let features = try container.decode(BloodPressureFeature.self, forKey: .weightScaleFeatures)
                self = .bloodPressure(measurement, features)
            }
        } catch {
            print("FAILED TO DECODE: \(error)")
            throw error
        }
    }

    public func encode(to encoder: any Encoder) throws {
        print("encoding \(Self.self)")
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .weight(measurement, feature):
            try container.encode(MeasurementType.weight, forKey: .type)
            try container.encode(measurement, forKey: .bloodPressure)
            try container.encode(feature, forKey: .bloodPressureFeatures)
        case let .bloodPressure(measurement, feature):
            try container.encode(MeasurementType.bloodPressure, forKey: .type)
            try container.encode(measurement, forKey: .weight)
            try container.encode(feature, forKey: .weightScaleFeatures)
        }
    }
}
