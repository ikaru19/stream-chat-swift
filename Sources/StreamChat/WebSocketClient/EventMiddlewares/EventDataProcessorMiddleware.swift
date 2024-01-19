//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation

/// A middleware which saves the incoming data from the Event to the database.
struct EventDataProcessorMiddleware: EventMiddleware {
    func handle(event: Event, session: DatabaseSession) -> Event? {
        guard let payload = (event as? EventDTO)?.payload else {
            // TODO: handle this better
            do {
                try session.saveEvent(event: event)
                log.debug("Event data saved to db")
                return event
            } catch {
                log.error("Failed saving incoming `Event` data to DB. Error: \(error)")
                return nil
            }
        }

        do {
            try session.saveEvent(payload: payload)
            log.debug("Event data saved to db: \(payload)")
            return event
        } catch {
            log.error("Failed saving incoming `Event` data to DB. Error: \(error)")
            return nil
        }
    }
}
