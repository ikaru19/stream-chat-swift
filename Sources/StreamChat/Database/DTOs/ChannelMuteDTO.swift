//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import CoreData
import Foundation

@objc(ChannelMuteDTO)
final class ChannelMuteDTO: NSManagedObject {
    @NSManaged var createdAt: DBDate
    @NSManaged var updatedAt: DBDate
    @NSManaged var channel: ChannelDTO
    @NSManaged var currentUser: CurrentUserDTO

    static func fetchRequest(for cid: ChannelId) -> NSFetchRequest<ChannelMuteDTO> {
        let request = NSFetchRequest<ChannelMuteDTO>(entityName: ChannelMuteDTO.entityName)
        request.predicate = NSPredicate(format: "channel.cid == %@", cid.rawValue)
        return request
    }

    static func load(cid: ChannelId, context: NSManagedObjectContext) -> ChannelMuteDTO? {
        load(by: fetchRequest(for: cid), context: context).first
    }

    static func loadOrCreate(cid: ChannelId, context: NSManagedObjectContext) -> ChannelMuteDTO {
        let request = fetchRequest(for: cid)
        if let existing = load(by: request, context: context).first {
            return existing
        }

        let new = NSEntityDescription.insertNewObject(
            into: context,
            for: request
        )
        return new
    }
}

extension NSManagedObjectContext {
    @discardableResult
    func saveChannelMute(payload: ChannelMute?) throws -> ChannelMuteDTO {
        guard let currentUser = currentUser, let payload, let mutedChannel = payload.channel else {
            throw ClientError.CurrentUserDoesNotExist()
        }
        
        let cid = try ChannelId(cid: mutedChannel.cid)
        let channel = try saveChannel(payload: mutedChannel, query: nil, cache: nil)
        let dto = ChannelMuteDTO.loadOrCreate(cid: cid, context: self)
        dto.channel = channel
        dto.currentUser = currentUser
        dto.createdAt = payload.createdAt.bridgeDate
        dto.updatedAt = payload.updatedAt.bridgeDate

        return dto
    }
}
