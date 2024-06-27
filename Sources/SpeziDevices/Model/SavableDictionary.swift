//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OrderedCollections
import OSLog


struct SavableDictionary<Key: Hashable & Codable, Value: Codable> {
    private var storage: OrderedDictionary<Key, Value>

    var keys: OrderedSet<Key> {
        storage.keys
    }

    var values: OrderedDictionary<Key, Value>.Values {
        storage.values
    }

    init() {
        self.storage = [:]
    }

    mutating func removeAll() {
        storage.removeAll()
    }

    @discardableResult
    mutating func removeValue(forKey key: Key) -> Value? {
        storage.removeValue(forKey: key)
    }

    subscript(key: Key) -> Value? {
        get {
            storage[key]
        }
        mutating _modify {
            yield &storage[key]
        }
        mutating set {
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
    public typealias Index = OrderedDictionary<Key, Value>.Index
    public typealias Element = OrderedDictionary<Key, Value>.Iterator.Element

    public var startIndex: Index {
        storage.elements.startIndex
    }
    public var endIndex: Index {
        storage.elements.endIndex
    }

    public func index(after index: Index) -> Index {
        storage.elements.index(after: index)
    }

    public subscript(position: Index) -> Element {
        storage.elements[position]
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
            self.storage = try JSONDecoder().decode(OrderedDictionary<Key, Value>.self, from: data)
        } catch {
            Self.logger.error("Failed to decode \(Self.self): \(error)")
            return nil
        }
    }
}
