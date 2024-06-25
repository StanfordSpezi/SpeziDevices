//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OSLog


struct SavableCollection<Element: Codable> {
    private var storage: [Element]

    var values: [Element] {
        storage
    }

    init(_ elements: [Element] = []) {
        self.storage = elements
    }
}


extension SavableCollection: RandomAccessCollection {
    public var startIndex: Int {
        storage.startIndex
    }

    public var endIndex: Int {
        storage.endIndex
    }

    public func index(after index: Int) -> Int {
        storage.index(after: index)
    }

    public subscript(position: Int) -> Element {
        storage[position]
    }
}


extension SavableCollection: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}


extension SavableCollection: RangeReplaceableCollection {
    public init() {
        self.init([])
    }

    public mutating func replaceSubrange<C: Collection<Element>>(_ subrange: Range<Int>, with newElements: C) {
        storage.replaceSubrange(subrange, with: newElements)
    }

    public mutating func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
        try storage.removeAll(where: shouldBeRemoved)
    }
}


extension SavableCollection: RawRepresentable {
    private static var logger: Logger {
        Logger(subsystem: "edu.stanford.spezi.SpeziDevices", category: "\(Self.self)")
    }

    var rawValue: String {
        let data: Data
        do {
            data = try JSONEncoder().encode(storage)
        } catch {
            Self.logger.error("Failed to encode \(Self.self): \(error)")
            return "[]"
        }
        guard let rawValue = String(data: data, encoding: .utf8) else {
            Self.logger.error("Failed to convert data of \(Self.self) to string: \(data)")
            return "[]"
        }

        return rawValue
    }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8) else {
            Self.logger.error("Failed to convert string of \(Self.self) to data: \(rawValue)")
            return nil
        }

        do {
            self.storage = try JSONDecoder().decode([Element].self, from: data)
        } catch {
            Self.logger.error("Failed to decode \(Self.self): \(error)")
            return nil
        }
    }
}
