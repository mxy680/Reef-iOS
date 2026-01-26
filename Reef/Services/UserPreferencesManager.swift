//
//  UserPreferencesManager.swift
//  Reef
//
//  Manages user preferences for pinned items.
//

import SwiftUI

@MainActor
class UserPreferencesManager: ObservableObject {
    static let shared = UserPreferencesManager()

    @AppStorage("pinnedItemIds") private var pinnedItemIdsData: Data = Data()

    private init() {}

    // MARK: - Pinned Items

    var pinnedItemIds: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: pinnedItemIdsData)) ?? []
        }
        set {
            pinnedItemIdsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            objectWillChange.send()
        }
    }

    func addPin(id: UUID) {
        var ids = pinnedItemIds
        ids.insert(id.uuidString)
        pinnedItemIds = ids
    }

    func removePin(id: UUID) {
        var ids = pinnedItemIds
        ids.remove(id.uuidString)
        pinnedItemIds = ids
    }

    func isPinned(id: UUID) -> Bool {
        pinnedItemIds.contains(id.uuidString)
    }

    func togglePin(id: UUID) {
        if isPinned(id: id) {
            removePin(id: id)
        } else {
            addPin(id: id)
        }
    }
}
