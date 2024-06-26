//
// This source file is part of the Stanford SpeziDevices open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit


/// A collection of HealthKit samples that form a measurement.
public enum HealthKitMeasurement {
    /// A weight measurement with optional BMI and height samples.
    case weight(HKQuantitySample, bmi: HKQuantitySample? = nil, height: HKQuantitySample? = nil)
    /// A blood pressure correlation with an optional heart rate sample.
    case bloodPressure(HKCorrelation, heartRate: HKQuantitySample? = nil)
}


extension HealthKitMeasurement: Hashable {}


extension HealthKitMeasurement {
    /// The collection of HealthKit samples contained in the measurement.
    public var samples: [HKSample] {
        var samples: [HKSample] = []
        switch self {
        case let .weight(sample, bmi, height):
            samples.append(sample)
            if let bmi {
                samples.append(bmi)
            }
            if let height {
                samples.append(height)
            }
        case let .bloodPressure(sample, heartRate):
            samples.append(sample)
            if let heartRate {
                samples.append(heartRate)
            }
        }

        return samples
    }
}


extension HealthKitMeasurement: Identifiable {
    public var id: UUID {
        switch self {
        case let .weight(sample, _, _):
            sample.uuid
        case let .bloodPressure(sample, _):
            sample.uuid
        }
    }
}
