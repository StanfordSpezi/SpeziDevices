//
// This source file is part of the ENGAGE-HF project based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit


public enum ProcessedHealthMeasurement { // TODO: HealthKitSample with Hint? => StructuredHKSample?
    case weight(HKQuantitySample)
    case bloodPressure(HKCorrelation, heartRate: HKQuantitySample? = nil)
}


extension ProcessedHealthMeasurement: Identifiable {
    public var id: UUID {
        switch self {
        case let .weight(sample):
            sample.uuid
        case let .bloodPressure(sample, _):
            sample.uuid
        }
    }
}
