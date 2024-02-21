//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

@testable import StreamChat
import XCTest

/// Mock implementation of `ChannelMemberUpdater`
final class ChannelMemberUpdater_Mock: ChannelMemberUpdater {
    @Atomic var banMember_userId: UserId?
    @Atomic var banMember_cid: ChannelId?
    @Atomic var banMember_shadow: Bool?
    @Atomic var banMember_timeoutInMinutes: Int??
    @Atomic var banMember_reason: String??
    @Atomic var banMember_completion: ((Error?) -> Void)?

    @Atomic var unbanMember_userId: UserId?
    @Atomic var unbanMember_cid: ChannelId?
    @Atomic var unbanMember_completion: ((Error?) -> Void)?

    func cleanUp() {
        banMember_userId = nil
        banMember_cid = nil
        banMember_timeoutInMinutes = nil
        banMember_reason = nil
        banMember_completion = nil

        unbanMember_userId = nil
        unbanMember_cid = nil
        unbanMember_completion = nil
    }

    override func banMember(
        _ userId: UserId,
        in cid: ChannelId,
        shadow: Bool,
        for timeoutInMinutes: Int? = nil,
        reason: String? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        banMember_userId = userId
        banMember_cid = cid
        banMember_shadow = shadow
        banMember_timeoutInMinutes = timeoutInMinutes
        banMember_reason = reason
        banMember_completion = completion
    }

    override func unbanMember(
        _ userId: UserId,
        in cid: ChannelId,
        currentUserId: UserId? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        unbanMember_userId = userId
        unbanMember_cid = cid
        unbanMember_completion = completion
    }
}
