//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OSLog


struct SavableDictionary<Key: Hashable & Codable, Value: Codable> {
    private var storage: [Key: Value]

    var keys: Dictionary<Key, Value>.Keys {
        storage.keys
    }

    var values: Dictionary<Key, Value>.Values {
        storage.values
    }

    init() {
        self.storage = [:]
    }

    subscript(key: Key) -> Value? {
        get {
            storage[key]
        }
        _modify {
            yield &storage[key]
        }
        set {
            storage[key] = newValue
        }
    }
}


extension SavableDictionary: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (Key, Value)...) {
        self.storage = .init(elements) { _, rhs in
            rhs
        }
    }
}


extension SavableDictionary: Collection {
    public typealias Index = Dictionary<Key, Value>.Index
    public typealias Element = Dictionary<Key, Value>.Iterator.Element

    public var startIndex: Index {
        storage.startIndex
    }
    public var endIndex: Index {
        storage.endIndex
    }

    public func index(after index: Index) -> Index {
        storage.index(after: index)
    }

    public subscript(position: Index) -> Element {
        storage[position]
    }
}


extension SavableDictionary: RawRepresentable {
    private static var logger: Logger {
        Logger(subsystem: "edu.stanford.spezi.SpeziDevices", category: "\(Self.self)")
    }

    var rawValue: String {
        let data: Data
        do {
            data = try JSONEncoder().encode(storage)
        } catch {
            Self.logger.error("Failed to encode \(Self.self): \(error)")
            return "{}"
        }
        guard let rawValue = String(data: data, encoding: .utf8) else {
            Self.logger.error("Failed to convert data of \(Self.self) to string: \(data)")
            return "{}"
        }

        return rawValue
    }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8) else {
            Self.logger.error("Failed to convert string of \(Self.self) to data: \(rawValue)")
            return nil
        }

        do {
            self.storage = try JSONDecoder().decode([Key: Value].self, from: data)
        } catch {
            Self.logger.error("Failed to decode \(Self.self): \(error)")
            return nil
        }
    }
}
