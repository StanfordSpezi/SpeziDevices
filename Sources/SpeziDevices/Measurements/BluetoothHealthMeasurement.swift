//
// This source file is part of the ENGAGE-HF project based on the Stanford Spezi Template Application project
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
}
