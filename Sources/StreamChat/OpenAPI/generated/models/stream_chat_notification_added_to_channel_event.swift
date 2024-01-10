//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation

public struct StreamChatNotificationAddedToChannelEvent: Codable, Hashable {
    public var createdAt: String
    
    public var member: StreamChatChannelMember?
    
    public var type: String
    
    public var channel: StreamChatChannelResponse?
    
    public var channelId: String
    
    public var channelType: String
    
    public var cid: String
    
    public init(createdAt: String, member: StreamChatChannelMember?, type: String, channel: StreamChatChannelResponse?, channelId: String, channelType: String, cid: String) {
        self.createdAt = createdAt
        
        self.member = member
        
        self.type = type
        
        self.channel = channel
        
        self.channelId = channelId
        
        self.channelType = channelType
        
        self.cid = cid
    }
    
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case createdAt = "created_at"
        
        case member
        
        case type
        
        case channel
        
        case channelId = "channel_id"
        
        case channelType = "channel_type"
        
        case cid
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(createdAt, forKey: .createdAt)
        
        try container.encode(member, forKey: .member)
        
        try container.encode(type, forKey: .type)
        
        try container.encode(channel, forKey: .channel)
        
        try container.encode(channelId, forKey: .channelId)
        
        try container.encode(channelType, forKey: .channelType)
        
        try container.encode(cid, forKey: .cid)
    }
}
