//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation

public struct Reaction: Codable, Hashable {
    public var createdAt: Date
    public var messageId: String
    public var score: Int
    public var type: String
    public var updatedAt: Date
    public var custom: [String: RawJSON]
    public var userId: String? = nil
    public var user: UserObject? = nil

    public init(createdAt: Date, messageId: String, score: Int, type: String, updatedAt: Date, custom: [String: RawJSON], userId: String? = nil, user: UserObject? = nil) {
        self.createdAt = createdAt
        self.messageId = messageId
        self.score = score
        self.type = type
        self.updatedAt = updatedAt
        self.custom = custom
        self.userId = userId
        self.user = user
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case createdAt = "created_at"
        case messageId = "message_id"
        case score
        case type
        case updatedAt = "updated_at"
        case custom
        case userId = "user_id"
        case user
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(messageId, forKey: .messageId)
        try container.encode(score, forKey: .score)
        try container.encode(type, forKey: .type)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(custom, forKey: .custom)
        try container.encode(userId, forKey: .userId)
        try container.encode(user, forKey: .user)
    }
}
