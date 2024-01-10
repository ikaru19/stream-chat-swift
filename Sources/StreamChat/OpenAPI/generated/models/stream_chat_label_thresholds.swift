//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation

public struct StreamChatLabelThresholds: Codable, Hashable {
    public var block: Double?
    
    public var flag: Double?
    
    public init(block: Double?, flag: Double?) {
        self.block = block
        
        self.flag = flag
    }
    
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case block
        
        case flag
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(block, forKey: .block)
        
        try container.encode(flag, forKey: .flag)
    }
}
