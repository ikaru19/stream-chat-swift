//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation

public struct StreamChatImageDataRequest: Codable, Hashable {
    public var size: String?
    
    public var url: String?
    
    public var width: String?
    
    public var frames: String?
    
    public var height: String?
    
    public init(size: String?, url: String?, width: String?, frames: String?, height: String?) {
        self.size = size
        
        self.url = url
        
        self.width = width
        
        self.frames = frames
        
        self.height = height
    }
    
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case size
        
        case url
        
        case width
        
        case frames
        
        case height
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(size, forKey: .size)
        
        try container.encode(url, forKey: .url)
        
        try container.encode(width, forKey: .width)
        
        try container.encode(frames, forKey: .frames)
        
        try container.encode(height, forKey: .height)
    }
}
