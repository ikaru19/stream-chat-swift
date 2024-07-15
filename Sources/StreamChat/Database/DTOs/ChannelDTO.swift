//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import CoreData
import Foundation

@objc(ChannelDTO)
class ChannelDTO: NSManagedObject {
    @NSManaged var cid: String
    @NSManaged var name: String?
    @NSManaged var imageURL: URL?
    @NSManaged var typeRawValue: String
    @NSManaged var extraData: Data
    @NSManaged var config: ChannelConfigDTO
    @NSManaged var ownCapabilities: [String]

    @NSManaged var createdAt: DBDate
    @NSManaged var deletedAt: DBDate?
    @NSManaged var defaultSortingAt: DBDate
    @NSManaged var updatedAt: DBDate
    @NSManaged var lastMessageAt: DBDate?

    // The oldest message of the channel we have locally coming from a regular channel query.
    // This property only lives locally, and it is useful to filter out older pinned/quoted messages
    // that do not belong to the regular channel query.
    @NSManaged var oldestMessageAt: DBDate?

    // Used for paginating newer messages while jumping to a mid-page.
    // We want to avoid new messages being inserted in the UI if we are in a mid-page.
    @NSManaged var newestMessageAt: DBDate?

    // This field is also used to implement the `clearHistory` option when hiding the channel.
    @NSManaged var truncatedAt: DBDate?

    @NSManaged var isHidden: Bool

    @NSManaged var watcherCount: Int64
    @NSManaged var memberCount: Int64

    @NSManaged var isFrozen: Bool
    @NSManaged var cooldownDuration: Int
    @NSManaged var team: String?
    
    @NSManaged var isBlocked: Bool

    // MARK: - Queries

    // The channel list queries the channel is a part of
    @NSManaged var queries: Set<ChannelListQueryDTO>

    // MARK: - Relationships

    @NSManaged var createdBy: UserDTO?
    @NSManaged var members: Set<MemberDTO>
    @NSManaged var threads: Set<ThreadDTO>

    /// If the current user is a member of the channel, this is their MemberDTO
    @NSManaged var membership: MemberDTO?
    @NSManaged var currentlyTypingUsers: Set<UserDTO>
    @NSManaged var messages: Set<MessageDTO>
    @NSManaged var pinnedMessages: Set<MessageDTO>
    @NSManaged var reads: Set<ChannelReadDTO>
    @NSManaged var watchers: Set<UserDTO>
    @NSManaged var memberListQueries: Set<ChannelMemberListQueryDTO>
    @NSManaged var previewMessage: MessageDTO?

    /// If the current channel is muted by the current user, `mute` contains details.
    @NSManaged var mute: ChannelMuteDTO?

    override func willSave() {
        super.willSave()

        guard !isDeleted else {
            return
        }

        // Change to the `truncatedAt` value have effect on messages, we need to mark them dirty manually
        // to triggers related FRC updates
        if changedValues().keys.contains("truncatedAt") {
            messages
                .filter { !$0.hasChanges }
                .forEach {
                    // Simulate an update
                    $0.willChangeValue(for: \.id)
                    $0.didChangeValue(for: \.id)
                }

            // When truncating the channel, we need to reset the newestMessageAt so that
            // the channel can render newer messages in the UI.
            if newestMessageAt != nil {
                newestMessageAt = nil
            }
        }

        // Update the date for sorting every time new message in this channel arrive.
        // This will ensure that the channel list is updated/sorted when new message arrives.
        // Note: If a channel is truncated, the server will update the lastMessageAt to a minimum value, and not remove it.
        // So, if lastMessageAt is nil or is equal to distantPast, we need to fallback to createdAt.
        var lastDate = lastMessageAt ?? createdAt
        if lastDate.bridgeDate <= .distantPast {
            lastDate = createdAt
        }
        if lastDate != defaultSortingAt {
            defaultSortingAt = lastDate
        }
    }

    /// The fetch request that returns all existed channels from the database
    static var allChannelsFetchRequest: NSFetchRequest<ChannelDTO> {
        let request = NSFetchRequest<ChannelDTO>(entityName: ChannelDTO.entityName)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChannelDTO.updatedAt, ascending: false)]
        return request
    }

    static func fetchRequest(for cid: ChannelId) -> NSFetchRequest<ChannelDTO> {
        let request = NSFetchRequest<ChannelDTO>(entityName: ChannelDTO.entityName)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChannelDTO.updatedAt, ascending: false)]
        request.predicate = NSPredicate(format: "cid == %@", cid.rawValue)
        return request
    }

    static func load(cid: ChannelId, context: NSManagedObjectContext) -> ChannelDTO? {
        let request = fetchRequest(for: cid)
        return load(by: request, context: context).first
    }

    static func load(cids: [ChannelId], context: NSManagedObjectContext) -> [ChannelDTO] {
        guard !cids.isEmpty else { return [] }
        let request = NSFetchRequest<ChannelDTO>(entityName: ChannelDTO.entityName)
        request.predicate = NSPredicate(format: "cid IN %@", cids)
        return load(by: request, context: context)
    }

    static func loadOrCreate(cid: ChannelId, context: NSManagedObjectContext, cache: PreWarmedCache?) -> ChannelDTO {
        if let cachedObject = cache?.model(for: cid.rawValue, context: context, type: ChannelDTO.self) {
            return cachedObject
        }

        let request = fetchRequest(for: cid)
        if let existing = load(by: request, context: context).first {
            return existing
        }

        let new = NSEntityDescription.insertNewObject(into: context, for: request)
        new.cid = cid.rawValue
        return new
    }
}

// MARK: - EphemeralValuesContainer

extension ChannelDTO: EphemeralValuesContainer {
    func resetEphemeralValues() {
        currentlyTypingUsers.removeAll()
        watchers.removeAll()
        watcherCount = 0
    }
}

// MARK: Saving and loading the data

extension NSManagedObjectContext {
    func saveChannelList(
        payload: ChannelListPayload,
        query: ChannelListQuery?
    ) -> [ChannelDTO] {
        let cache = payload.getPayloadToModelIdMappings(context: self)

        // The query will be saved during `saveChannel` call
        // but in case this query does not have any channels,
        // the query won't be saved, which will cause any future
        // channels to not become linked to this query
        if let query = query {
            _ = saveQuery(query: query)
        }

        return payload.channels.compactMapLoggingError { channelPayload in
            try saveChannel(payload: channelPayload, query: query, cache: cache)
        }
    }

    func saveChannel(
        payload: ChannelDetailPayload,
        query: ChannelListQuery?,
        cache: PreWarmedCache?
    ) throws -> ChannelDTO {
        let dto = ChannelDTO.loadOrCreate(cid: payload.cid, context: self, cache: cache)

        dto.name = payload.name
        dto.imageURL = payload.imageURL
        do {
            dto.extraData = try JSONEncoder.default.encode(payload.extraData)
        } catch {
            log.error(
                "Failed to decode extra payload for Channel with cid: <\(dto.cid)>, using default value instead. "
                    + "Error: \(error)"
            )
            dto.extraData = Data()
        }
        dto.typeRawValue = payload.typeRawValue
        dto.config = payload.config.asDTO(context: self, cid: dto.cid)
        if let ownCapabilities = payload.ownCapabilities {
            dto.ownCapabilities = ownCapabilities
        }
        dto.createdAt = payload.createdAt.bridgeDate
        dto.deletedAt = payload.deletedAt?.bridgeDate
        dto.updatedAt = payload.updatedAt.bridgeDate
        dto.defaultSortingAt = (payload.lastMessageAt ?? payload.createdAt).bridgeDate
        dto.lastMessageAt = payload.lastMessageAt?.bridgeDate
        dto.memberCount = Int64(clamping: payload.memberCount)

        // Because `truncatedAt` is used, client side, for both truncation and channel hiding cases, we need to avoid using the
        // value returned by the Backend in some cases.
        //
        // Whenever our Backend is not returning a value for `truncatedAt`, we simply do nothing. It is possible that our
        // DTO already has a value for it if it has been hidden in the past, but we are not touching it.
        //
        // Whenever we do receive a value from our Backend, we have 2 options:
        //  1. If we don't have a value for `truncatedAt` in the DTO -> We set the date from the payload
        //  2. If we have a value for `truncatedAt` in the DTO -> We pick the latest date.
        if let newTruncatedAt = payload.truncatedAt {
            let canUpdateTruncatedAt = dto.truncatedAt.map { $0.bridgeDate < newTruncatedAt } ?? true
            if canUpdateTruncatedAt {
                dto.truncatedAt = newTruncatedAt.bridgeDate
            }
        }

        dto.isFrozen = payload.isFrozen
        
        // Backend only returns a boolean
        // for blocked 1:1 channels on channel list query
        if let isBlocked = payload.isBlocked {
            dto.isBlocked = isBlocked
        } else {
            dto.isBlocked = false
        }

        // Backend only returns a boolean for hidden state
        // on channel query and channel list query
        if let isHidden = payload.isHidden {
            dto.isHidden = isHidden
        }

        dto.cooldownDuration = payload.cooldownDuration
        dto.team = payload.team

        if let createdByPayload = payload.createdBy {
            let creatorDTO = try saveUser(payload: createdByPayload)
            dto.createdBy = creatorDTO
        }

        try payload.members?.forEach { memberPayload in
            let member = try saveMember(payload: memberPayload, channelId: payload.cid, query: nil, cache: cache)
            dto.members.insert(member)
        }

        if let query = query {
            let queryDTO = saveQuery(query: query)
            queryDTO.channels.insert(dto)
        }

        return dto
    }

    func saveChannel(
        payload: ChannelPayload,
        query: ChannelListQuery?,
        cache: PreWarmedCache?
    ) throws -> ChannelDTO {
        let dto = try saveChannel(payload: payload.channel, query: query, cache: cache)

        let reads = Set(
            try payload.channelReads.map {
                try saveChannelRead(payload: $0, for: payload.channel.cid, cache: cache)
            }
        )
        dto.reads.subtracting(reads).forEach { delete($0) }
        dto.reads = reads

        try payload.messages.forEach { _ = try saveMessage(payload: $0, channelDTO: dto, syncOwnReactions: true, cache: cache) }

        if dto.needsPreviewUpdate(payload) {
            dto.previewMessage = preview(for: payload.channel.cid)
        }

        dto.updateOldestMessageAt(payload: payload)

        try payload.pinnedMessages.forEach {
            _ = try saveMessage(payload: $0, channelDTO: dto, syncOwnReactions: true, cache: cache)
        }

        // Note: membership payload should be saved before all the members
        if let membership = payload.membership {
            let membership = try saveMember(payload: membership, channelId: payload.channel.cid, query: nil, cache: cache)
            dto.membership = membership
        } else {
            dto.membership = nil
        }
        
        // Sometimes, `members` are not part of `ChannelDetailPayload` so they need to be saved here too.
        try payload.members.forEach {
            let member = try saveMember(payload: $0, channelId: payload.channel.cid, query: nil, cache: cache)
            dto.members.insert(member)
        }

        dto.watcherCount = Int64(clamping: payload.watcherCount ?? 0)

        if let watchers = payload.watchers {
            // We don't call `removeAll` on watchers since user could've requested
            // a different page
            try watchers.forEach {
                let user = try saveUser(payload: $0)
                dto.watchers.insert(user)
            }
        }
        // We don't reset `watchers` array if it's missing
        // since that can mean that user didn't request watchers
        // This is done in `ChannelUpdater.channelWatchers` func

        return dto
    }

    func channel(cid: ChannelId) -> ChannelDTO? {
        ChannelDTO.load(cid: cid, context: self)
    }

    func delete(query: ChannelListQuery) {
        guard let dto = channelListQuery(filterHash: query.filter.filterHash) else { return }

        delete(dto)
    }

    func cleanChannels(cids: Set<ChannelId>) {
        let channels = ChannelDTO.load(cids: Array(cids), context: self)
        for channelDTO in channels {
            channelDTO.resetEphemeralValues()
            channelDTO.messages.removeAll()
            channelDTO.members.removeAll()
            channelDTO.pinnedMessages.removeAll()
            channelDTO.reads.removeAll()
            channelDTO.oldestMessageAt = nil
        }
    }

    func removeChannels(cids: Set<ChannelId>) {
        let channels = ChannelDTO.load(cids: Array(cids), context: self)
        channels.forEach(delete)
    }
}

// To get the data from the DB

extension ChannelDTO {
    static func channelListFetchRequest(
        query: ChannelListQuery,
        chatClientConfig: ChatClientConfig
    ) -> NSFetchRequest<ChannelDTO> {
        let request = NSFetchRequest<ChannelDTO>(entityName: ChannelDTO.entityName)

        // Fetch results controller requires at least one sorting descriptor.
        let sortDescriptors = query.sort.compactMap { $0.key.sortDescriptor(isAscending: $0.isAscending) }
        request.sortDescriptors = sortDescriptors.isEmpty ? [ChannelListSortingKey.defaultSortDescriptor] : sortDescriptors

        let matchingQuery = NSPredicate(format: "ANY queries.filterHash == %@", query.filter.filterHash)
        let notDeleted = NSPredicate(format: "deletedAt == nil")

        var subpredicates: [NSPredicate] = [
            matchingQuery, notDeleted
        ]

        // If a hidden filter is not provided, we add a default hidden filter == 0.
        // The backend appends a `hidden: false` filter when it's not specified, so we need to do the same.
        if query.filter.hiddenFilterValue == nil {
            subpredicates.append(NSPredicate(format: "\(#keyPath(ChannelDTO.isHidden)) == 0"))
        }

        if chatClientConfig.isChannelAutomaticFilteringEnabled, let filterPredicate = query.filter.predicate {
            subpredicates.append(filterPredicate)
        }

        request.predicate = NSCompoundPredicate(type: .and, subpredicates: subpredicates)
        request.fetchLimit = query.pagination.pageSize
        request.fetchBatchSize = query.pagination.pageSize
        return request
    }
    
    static func directMessageChannel(participantId: UserId, context: NSManagedObjectContext) -> ChannelDTO? {
        let request = NSFetchRequest<ChannelDTO>(entityName: ChannelDTO.entityName)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChannelDTO.updatedAt, ascending: false)]
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "cid CONTAINS ':!members'"),
            NSPredicate(format: "members.@count == 2"),
            NSPredicate(format: "ANY members.user.id == %@", participantId)
        ])
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}

extension ChannelDTO {
    /// Snapshots the current state of `ChannelDTO` and returns an immutable model object from it.
    func asModel() throws -> ChatChannel { try .create(fromDTO: self) }
}

extension ChatChannel {
    /// Create a ChannelModel struct from its DTO
    fileprivate static func create(fromDTO dto: ChannelDTO) throws -> ChatChannel {
        guard let cid = try? ChannelId(cid: dto.cid), let context = dto.managedObjectContext else {
            throw InvalidModel(dto)
        }

        let extraData: [String: RawJSON]
        do {
            extraData = try JSONDecoder.default.decode([String: RawJSON].self, from: dto.extraData)
        } catch {
            log.error(
                "Failed to decode extra data for Channel with cid: <\(dto.cid)>, using default value instead. "
                    + "Error: \(error)"
            )
            extraData = [:]
        }

        let reads: [ChatChannelRead] = try dto.reads.map { try $0.asModel() }

        let unreadCount: ChannelUnreadCount = {
            guard let currentUser = context.currentUser else {
                return .noUnread
            }

            let currentUserRead = reads.first(where: { $0.user.id == currentUser.user.id })

            let allUnreadMessages = currentUserRead?.unreadMessagesCount ?? 0

            // Fetch count of all mentioned messages after last read
            // (this is not 100% accurate but it's the best we have)
            let unreadMentionsRequest = NSFetchRequest<MessageDTO>(entityName: MessageDTO.entityName)
            unreadMentionsRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                MessageDTO.channelMessagesPredicate(
                    for: dto.cid,
                    deletedMessagesVisibility: context.deletedMessagesVisibility ?? .visibleForCurrentUser,
                    shouldShowShadowedMessages: context.shouldShowShadowedMessages ?? false
                ),
                NSPredicate(format: "createdAt > %@", currentUserRead?.lastReadAt.bridgeDate ?? DBDate(timeIntervalSince1970: 0)),
                NSPredicate(format: "%@ IN mentionedUsers", currentUser.user)
            ])

            do {
                return ChannelUnreadCount(
                    messages: allUnreadMessages,
                    mentions: try context.count(for: unreadMentionsRequest)
                )
            } catch {
                log.error("Failed to fetch unread counts for channel `\(cid)`. Error: \(error)")
                return .noUnread
            }
        }()

        let messages: [ChatMessage] = {
            MessageDTO
                .load(
                    for: dto.cid,
                    limit: dto.managedObjectContext?.localCachingSettings?.chatChannel.latestMessagesLimit ?? 25,
                    deletedMessagesVisibility: dto.managedObjectContext?.deletedMessagesVisibility ?? .visibleForCurrentUser,
                    shouldShowShadowedMessages: dto.managedObjectContext?.shouldShowShadowedMessages ?? false,
                    context: context
                )
                .compactMap { try? $0.asModel() }
        }()

        let latestMessageFromUser: ChatMessage? = {
            guard let currentUser = context.currentUser else { return nil }

            return try? MessageDTO
                .loadLastMessage(
                    from: currentUser.user.id,
                    in: dto.cid,
                    context: context
                )?
                .asModel()
        }()

        let watchers = UserDTO.loadLastActiveWatchers(cid: cid, context: context)
            .compactMap { try? $0.asModel() }
        
        let members = MemberDTO.loadLastActiveMembers(cid: cid, context: context)
            .compactMap { try? $0.asModel() }

        let muteDetails: MuteDetails? = {
            guard let mute = dto.mute else { return nil }
            return .init(
                createdAt: mute.createdAt.bridgeDate,
                updatedAt: mute.updatedAt.bridgeDate,
                expiresAt: mute.expiresAt?.bridgeDate
            )
        }()
        let membership = try dto.membership.map { try $0.asModel() }
        let pinnedMessages = dto.pinnedMessages.compactMap { try? $0.asModel() }
        let previewMessage = try? dto.previewMessage?.asModel()
        let typingUsers = Set(dto.currentlyTypingUsers.compactMap { try? $0.asModel() })
        
        return try ChatChannel(
            cid: cid,
            name: dto.name,
            imageURL: dto.imageURL,
            lastMessageAt: dto.lastMessageAt?.bridgeDate,
            createdAt: dto.createdAt.bridgeDate,
            updatedAt: dto.updatedAt.bridgeDate,
            deletedAt: dto.deletedAt?.bridgeDate,
            truncatedAt: dto.truncatedAt?.bridgeDate,
            isHidden: dto.isHidden,
            createdBy: dto.createdBy?.asModel(),
            config: dto.config.asModel(),
            ownCapabilities: Set(dto.ownCapabilities.compactMap(ChannelCapability.init(rawValue:))),
            isFrozen: dto.isFrozen,
            isBlocked: dto.isBlocked,
            lastActiveMembers: members,
            membership: membership,
            currentlyTypingUsers: typingUsers,
            lastActiveWatchers: watchers,
            team: dto.team,
            unreadCount: unreadCount,
            watcherCount: Int(dto.watcherCount),
            memberCount: Int(dto.memberCount),
            reads: reads,
            cooldownDuration: Int(dto.cooldownDuration),
            extraData: extraData,
            latestMessages: messages,
            lastMessageFromCurrentUser: latestMessageFromUser,
            pinnedMessages: pinnedMessages,
            muteDetails: muteDetails,
            previewMessage: previewMessage
        )
    }
}

// MARK: - Helpers

extension ChannelDTO {
    func cleanAllMessagesExcludingLocalOnly() {
        messages = messages.filter { $0.isLocalOnly }
    }

    /// Updates the `oldestMessageAt` of the channel. It should only update if the current `oldestMessageAt` is not older already.
    /// This property is useful to filter out older pinned/quoted messages that do not belong to the regular channel query,
    /// but are already in the database.
    func updateOldestMessageAt(payload: ChannelPayload) {
        guard let payloadOldestMessageAt = payload.messages.map(\.createdAt).min() else { return }
        let isOlderThanCurrentOldestMessage = payloadOldestMessageAt < (oldestMessageAt?.bridgeDate ?? Date.distantFuture)
        if isOlderThanCurrentOldestMessage {
            oldestMessageAt = payloadOldestMessageAt.bridgeDate
        }
    }

    /// Returns `true` if the payload holds messages sent after the current channel preview.
    func needsPreviewUpdate(_ payload: ChannelPayload) -> Bool {
        guard let preview = previewMessage else {
            return true
        }

        guard let newestMessage = payload.newestMessage else {
            return false
        }

        return newestMessage.createdAt > preview.createdAt.bridgeDate
    }
}
