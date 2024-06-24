//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import Spezi


/// A Standard constraint when using the `HealthMeasurements` Module.
///
/// A Standard must adopt this constraint when the ``HealthMeasurements`` module is loaded.
///
/// ```swift
/// actor ExampleStandard: Standard, HealthMeasurementsConstraint {
///     func addMeasurement(samples: [HKSample]) async throws {
///         // ... be notified when new measurements arrive
///     }
/// }
/// ```
public protocol HealthMeasurementsConstraint: Standard {
    func addMeasurement(samples: [HKSample]) async throws
    // TODO: document that it might throw errors, but only for visualization purposes in the UI
}
