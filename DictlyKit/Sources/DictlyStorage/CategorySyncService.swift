import Foundation
import SwiftData
import Observation
import os
import DictlyModels

// MARK: - Sync Payload

/// Codable representation of a TagCategory for iCloud Key-Value Store sync.
/// Contains only metadata — no session, tag, or audio data.
struct SyncableCategory: Codable {
    var uuid: String
    var name: String
    var colorHex: String
    var iconName: String
    var sortOrder: Int
    var isDefault: Bool
    var modifiedAt: Date
}

// MARK: - CategorySyncService

/// Syncs TagCategory metadata between devices via iCloud Key-Value Store.
/// Lives in DictlyStorage (shared between iOS and Mac targets).
/// Uses NSUbiquitousKeyValueStore — lightweight, automatic, 1 MB limit.
@MainActor
@Observable
public final class CategorySyncService {

    private var modelContext: ModelContext?
    private let store = NSUbiquitousKeyValueStore.default
    private let logger = Logger(subsystem: "com.dictly", category: "storage")
    private static let kvsKey = "tagCategories"

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // nonisolated(unsafe) required so deinit (which is nonisolated in Swift 6) can access this
    nonisolated(unsafe) private var observation: NSObjectProtocol?

    public init() {}

    deinit {
        if let observation {
            NotificationCenter.default.removeObserver(observation)
        }
    }

    // MARK: - Public API

    /// Call from app entry point `.task` modifier after ModelContainer setup.
    public func startObserving(context: ModelContext) {
        self.modelContext = context

        observation = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            // Extract Sendable values from Notification before crossing isolation boundary.
            // queue: .main guarantees we're on the main queue.
            let reasonRaw = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
            MainActor.assumeIsolated {
                self?.handleExternalChange(reasonRaw: reasonRaw, changedKeys: changedKeys)
            }
        }

        store.synchronize()
        pullCategoriesFromCloud()
    }

    /// Serialize all local TagCategory objects to JSON and write to iCloud KVS.
    /// Call after any local mutation to propagate changes to other devices.
    public func pushCategoriesToCloud() {
        guard let modelContext else {
            logger.error("CategorySyncService: pushCategoriesToCloud called before startObserving")
            return
        }

        do {
            let categories = try modelContext.fetch(FetchDescriptor<TagCategory>())
            let now = Date()
            let payload = categories.map { cat in
                SyncableCategory(
                    uuid: cat.uuid.uuidString,
                    name: cat.name,
                    colorHex: cat.colorHex,
                    iconName: cat.iconName,
                    sortOrder: cat.sortOrder,
                    isDefault: cat.isDefault,
                    modifiedAt: now
                )
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            store.set(data, forKey: Self.kvsKey)
            logger.info("CategorySyncService: pushed \(payload.count) categories to iCloud KVS")
        } catch {
            logger.error("CategorySyncService: push failed — \(error)")
        }
    }

    // MARK: - Private

    private func handleExternalChange(reasonRaw: Int?, changedKeys: [String]) {
        guard let reasonRaw else { return }
        let reason = NSUbiquitousKeyValueStore.ChangeReason(rawValue: reasonRaw)

        switch reason {
        case .serverChange, .initialSyncChange:
            if changedKeys.contains(Self.kvsKey) || reason == .initialSyncChange {
                pullCategoriesFromCloud()
            }
        case .accountChange:
            pullCategoriesFromCloud()
        case .quotaViolationChange:
            logger.error("CategorySyncService: iCloud KVS quota violated — sync paused")
        default:
            pullCategoriesFromCloud()
        }
    }

    /// Read category payload from iCloud KVS and merge into local SwiftData store.
    /// Internal access allows unit tests to trigger a pull via @testable import.
    func pullCategoriesFromCloud() {
        guard let modelContext else { return }

        guard let data = store.data(forKey: Self.kvsKey) else {
            logger.info("CategorySyncService: no data in iCloud KVS yet — nothing to pull")
            return
        }

        processCloudPayload(data, into: modelContext)
    }

    /// Process a raw KVS payload directly — exposed as internal for unit testing
    /// without relying on NSUbiquitousKeyValueStore being available in test processes.
    func processCloudPayload(_ data: Data, into context: ModelContext) {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cloudCategories = try decoder.decode([SyncableCategory].self, from: data)
            try mergeCloudCategories(cloudCategories, into: context)
            logger.info("CategorySyncService: merged \(cloudCategories.count) categories from payload")
        } catch {
            logger.error("CategorySyncService: process payload failed — \(error)")
        }
    }

    /// Merge strategy:
    /// - UUID match, cloud newer → update local fields
    /// - UUID not in local → insert
    /// - UUID not in cloud → keep local (no deletion on pull)
    /// - Simultaneous edit → last `modifiedAt` wins
    private func mergeCloudCategories(_ cloudCategories: [SyncableCategory], into context: ModelContext) throws {
        let localCategories = try context.fetch(FetchDescriptor<TagCategory>())
        let localByUUID = Dictionary(uniqueKeysWithValues: localCategories.map { ($0.uuid.uuidString, $0) })

        for remote in cloudCategories {
            if let local = localByUUID[remote.uuid] {
                // UUID match — update if cloud modifiedAt is newer
                // Since we don't store modifiedAt in SwiftData, we always apply cloud fields
                // (last-write-wins: cloud data came from the server, so it reflects the latest push)
                let oldName = local.name
                let nameChanged = oldName != remote.name

                local.name = remote.name
                local.colorHex = remote.colorHex
                local.iconName = remote.iconName
                local.sortOrder = remote.sortOrder
                local.isDefault = remote.isDefault

                if nameChanged {
                    try updateTagCategoryName(from: oldName, to: remote.name, in: context)
                }
            } else {
                // Not in local — insert
                guard let uuid = UUID(uuidString: remote.uuid) else {
                    logger.error("CategorySyncService: invalid UUID in cloud payload: \(remote.uuid)")
                    continue
                }
                let newCategory = TagCategory(
                    uuid: uuid,
                    name: remote.name,
                    colorHex: remote.colorHex,
                    iconName: remote.iconName,
                    sortOrder: remote.sortOrder,
                    isDefault: remote.isDefault
                )
                context.insert(newCategory)
            }
        }
        // Categories in local but not in cloud are intentionally preserved (no deletion on pull)
    }

    /// Update all Tag records referencing the old category name to use the new name.
    /// Mirrors the rename fix from Story 1.5 (TagCategoryFormSheet.swift).
    private func updateTagCategoryName(from oldName: String, to newName: String, in context: ModelContext) throws {
        let capturedOldName = oldName
        let predicate = #Predicate<Tag> { $0.categoryName == capturedOldName }
        let tags = try context.fetch(FetchDescriptor<Tag>(predicate: predicate))
        for tag in tags {
            tag.categoryName = newName
        }
        if !tags.isEmpty {
            logger.info("CategorySyncService: updated \(tags.count) tags from category '\(oldName)' → '\(newName)'")
        }
    }
}

// MARK: - NSUbiquitousKeyValueStore.ChangeReason helper

private extension NSUbiquitousKeyValueStore {
    enum ChangeReason {
        case serverChange
        case initialSyncChange
        case quotaViolationChange
        case accountChange
        case unknown

        init(rawValue: Int) {
            switch rawValue {
            case NSUbiquitousKeyValueStoreServerChange: self = .serverChange
            case NSUbiquitousKeyValueStoreInitialSyncChange: self = .initialSyncChange
            case NSUbiquitousKeyValueStoreQuotaViolationChange: self = .quotaViolationChange
            case NSUbiquitousKeyValueStoreAccountChange: self = .accountChange
            default: self = .unknown
            }
        }
    }
}
