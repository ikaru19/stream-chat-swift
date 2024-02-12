//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation

public struct ShowChannelRequest: Codable, Hashable {
    public var userId: String? = nil
    public var user: UserObjectRequest? = nil

    public init(userId: String? = nil, user: UserObjectRequest? = nil) {
        self.userId = userId
        self.user = user
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case userId = "user_id"
        case user
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(user, forKey: .user)
    }
}
