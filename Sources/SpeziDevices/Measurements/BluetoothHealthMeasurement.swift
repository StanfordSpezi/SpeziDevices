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
    // TODO: public let systolicValue: MedFloat16
    /// The diastolic value of the blood pressure measurement.
    ///
    /// The unit of this value is defined by the ``unit-swift.property`` property.
    // TODO: public let diastolicValue: MedFloat16
    /// The Mean Arterial Pressure (MAP)
    ///
    /// The unit of this value is defined by the ``unit-swift.property`` property.
    // TODO: public let meanArterialPressure: MedFloat16
    /// The unit of the blood pressure measurement values.
    ///
    /// This property defines the unit of the ``systolicValue``, ``diastolicValue`` and ``meanArterialPressure`` properties.
    public let unit: String

    /// The timestamp of the measurement.
    // TODO: public let timeStamp: DateTime?

    /// The pulse rate in beats per minute.
    // TODO: public let pulseRate: MedFloat16?

    /// The associated user of the blood pressure measurement.
    ///
    /// This value can be used to differentiate users if the device supports multiple users.
    /// - Note: The special value of `0xFF` (`UInt8.max`) is used to represent an unknown user.
    ///
    /// The values are left to the implementation but should be unique per device.
    // TODO: public let userId: UInt8?

    /// Additional metadata information of a blood pressure measurement.
    // TOOD: public let measurementStatus: UInt16?


    init(from measurement: BloodPressureMeasurement) {
        // TODO: self.systolicValue = measurement.systolicValue
        // TODO: self.diastolicValue = measurement.diastolicValue
        // TODO: self.meanArterialPressure = measurement.meanArterialPressure
        self.unit = measurement.unit.rawValue
        // TODO: self.timeStamp = measurement.timeStamp
        // TODO: self.pulseRate = measurement.pulseRate
        // TODO: self.userId = measurement.userId
        // TODO: self.measurementStatus = measurement.measurementStatus?.rawValue
    }
}

struct SwiftDataBluetoothHealthMeasurementWorkaroundContainer: Codable {
    enum MeasurementType: String, Codable {
        case weight
        case bloodPressure
    }

    private let type: MeasurementType

    private var bloodPressureMeasurement2: BloodPressureMeasurementCopy?
    private var bloodPressureFeatures: BloodPressureFeature.RawValue? // TODO: non-transient!

    // TODO: private var weightMeasurement: WeightMeasurement?
    private var weightScaleFeatures: WeightScaleFeature.RawValue?

    init(from measurement: BluetoothHealthMeasurement) {
        switch measurement {
        case let .bloodPressure(measurement, feature):
            type = .bloodPressure
            bloodPressureMeasurement2 = BloodPressureMeasurementCopy(from: measurement)
            // TODO: bloodPressureMeasurement = .init(from: measurement)
            bloodPressureFeatures = feature.rawValue
        case let .weight(measurement, features):
            type = .weight
            // bloodPressureMeasurement2 = BloodPressureMeasurementCopy(from: .mock())
            // TODO:  weightMeasurement = measurement
            weightScaleFeatures = features.rawValue
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encodeIfPresent(self.bloodPressureMeasurement2, forKey: .bloodPressureMeasurement2)
        try container.encodeIfPresent(self.bloodPressureFeatures, forKey: .bloodPressureFeatures)
        // TOOD: try container.encodeIfPresent(self.weightScaleFeatures, forKey: .weightScaleFeatures)
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
