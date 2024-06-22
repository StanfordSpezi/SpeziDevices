//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//



import HealthKit
import SpeziBluetoothServices


extension BloodPressureMeasurement.Unit {
    /// The unit represented as a `HKUnit`.
    public var hkUnit: HKUnit {
        switch self {
        case .mmHg:
            return .millimeterOfMercury()
        case .kPa:
            return .pascalUnit(with: .kilo)
        }
    }
}
