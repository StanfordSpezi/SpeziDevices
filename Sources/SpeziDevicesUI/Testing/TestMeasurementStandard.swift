//
// This source file is part of the ENGAGE-HF project based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import Spezi
import SpeziDevices


#if DEBUG || TEST
actor TestMeasurementStandard: Standard, HealthMeasurementsConstraint {
    func addMeasurement(sample: HKSample) async throws {
        print("Adding sample \(sample)")
    }
}
#endif
