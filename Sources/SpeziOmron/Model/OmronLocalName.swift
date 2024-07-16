//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import RegexBuilder


public struct OmronLocalName { // TODO: extensions for docs
    public enum PairingMode: String {
        case transferMode = "BLESmart_"
        case pairingMode = "BLEsmart_" // yeah, that's funny
    }

    public struct ModelIdentifier {
        public var rawValue: String

        public init?(rawValue: String) {
            guard rawValue.count == 8 else {
                return nil
            }
            self.rawValue = rawValue
        }
    }

    public struct MacAddress {
        public var rawValue: String // TODO: `Data` rawValue?

        public init?(rawValue: String) {
            guard rawValue.count == 12 else {
                return nil
            }
            self.rawValue = rawValue
        }
    }

    public let pairingMode: PairingMode
    public let model: ModelIdentifier
    public let macAddress: MacAddress

    public var rawValue: String {
        pairingMode.rawValue + model.rawValue + macAddress.rawValue
    }


    public init?(rawValue: String) {
        let pattern = Regex {
            TryCapture {
                ChoiceOf {
                    "BLESmart_"
                    "BLEsmart_"
                }
            } transform: { output in
                PairingMode(rawValue: String(output))
            }
            TryCapture {
                Repeat(.hexDigit, count: 2 * 4)
            } transform: { output in
                ModelIdentifier(rawValue: String(output))
            }
            TryCapture {
                Repeat(.hexDigit, count: 2 * 6)
            } transform: { output in
                MacAddress(rawValue: String(output))
            }
        }
        guard let match = rawValue.wholeMatch(of: pattern) else {
            return nil
        }

        let (_, pairingMode, model, macAddress) = match.output
        self.pairingMode = pairingMode
        self.model = model
        self.macAddress = macAddress
    }
}


extension OmronLocalName.ModelIdentifier: RawRepresentable, Sendable, Hashable {}


extension OmronLocalName.MacAddress: RawRepresentable, Sendable, Hashable {}


extension OmronLocalName: RawRepresentable, Sendable, Hashable {}
