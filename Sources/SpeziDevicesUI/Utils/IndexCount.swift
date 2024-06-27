//
// This source file is part of the Stanford SpeziDevices open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//


struct IndexCount {
    let index: Int
    let count: Int

    init(_ index: Int, _ count: Int) {
        self.index = index
        self.count = count
    }
}


extension IndexCount: Hashable {}
