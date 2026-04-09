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
    private static let packIDsKey = "installedPackIDs"

    /// ISO 8601 formatter with fractional seconds for sub-second precision in last-write-wins.
    nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Cached modifiedAt timestamps per category UUID from the last push or pull.
    /// Used by merge to implement last-write-wins: only apply cloud fields if cloud modifiedAt
    /// is newer than the locally cached timestamp.
    private var cachedModifiedAt: [String: Date] = [:]

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
    /// Registers for KVS change notifications, triggers initial sync, and pushes local state.
    public func startObserving(context: ModelContext) {
        guard modelContext == nil else {
            logger.info("CategorySyncService: startObserving called again — ignoring duplicate")
            return
        }
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
        pullPackIDsFromCloud()
        pushCategoriesToCloud()
        pushPackIDsToCloud()
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
                let uuidStr = cat.uuid.uuidString
                // Preserve cached modifiedAt if available; stamp current time only for new/changed categories
                let lastKnown = cachedModifiedAt[uuidStr]
                let modifiedAt = lastKnown ?? now
                return SyncableCategory(
                    uuid: uuidStr,
                    name: cat.name,
                    colorHex: cat.colorHex,
                    iconName: cat.iconName,
                    sortOrder: cat.sortOrder,
                    isDefault: cat.isDefault,
                    modifiedAt: modifiedAt
                )
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(Self.iso8601Formatter.string(from: date))
            }
            let data = try encoder.encode(payload)
            store.set(data, forKey: Self.kvsKey)

            // Update cache with pushed timestamps
            for cat in payload {
                cachedModifiedAt[cat.uuid] = cat.modifiedAt
            }

            logger.info("CategorySyncService: pushed \(payload.count) categories to iCloud KVS")
        } catch {
            logger.error("CategorySyncService: push failed — \(error)")
        }
    }

    /// Mark a category as locally modified so the next push stamps it with the current time.
    /// Call this before pushCategoriesToCloud when a category has been mutated.
    public func markModified(_ category: TagCategory) {
        cachedModifiedAt[category.uuid.uuidString] = Date()
    }

    // MARK: - Pack ID Sync

    /// Serialize locally installed pack IDs to iCloud KVS.
    /// Call after any pack install/uninstall to propagate changes to other devices.
    public func pushPackIDsToCloud() {
        guard let modelContext else {
            logger.error("CategorySyncService: pushPackIDsToCloud called before startObserving")
            return
        }

        do {
            let localPackIDs = try DefaultTagSeeder.installedPackIDs(context: modelContext)
            let sorted = Array(localPackIDs).sorted()
            let data = try JSONEncoder().encode(sorted)
            store.set(data, forKey: Self.packIDsKey)
            logger.info("CategorySyncService: pushed \(sorted.count) pack IDs to iCloud KVS: \(sorted)")
        } catch {
            logger.error("CategorySyncService: pushPackIDs failed — \(error)")
        }
    }

    /// Read installed pack IDs from iCloud KVS and install/uninstall packs to match.
    func pullPackIDsFromCloud() {
        guard let modelContext else { return }

        guard let data = store.data(forKey: Self.packIDsKey) else {
            logger.info("CategorySyncService: no pack IDs in iCloud KVS yet — nothing to pull")
            return
        }

        processPackIDsPayload(data, into: modelContext)
    }

    /// Process a raw pack IDs payload — exposed as internal for unit testing.
    func processPackIDsPayload(_ data: Data, into context: ModelContext) {
        do {
            let remotePackIDs = Set(try JSONDecoder().decode([String].self, from: data))
            let localPackIDs = try DefaultTagSeeder.installedPackIDs(context: context)

            let toInstall = remotePackIDs.subtracting(localPackIDs)
            let toUninstall = localPackIDs.subtracting(remotePackIDs)

            var sortOrder = try DefaultTagSeeder.nextSortOrder(context: context)
            for packID in toInstall {
                guard let pack = TagPackRegistry.all.first(where: { $0.id == packID }) else {
                    logger.warning("CategorySyncService: unknown pack ID from cloud: \(packID) — skipping")
                    continue
                }
                try DefaultTagSeeder.installPack(pack, startingSortOrder: sortOrder, context: context)
                sortOrder += pack.categories.count
                logger.info("CategorySyncService: auto-installed pack '\(packID)' from cloud sync")
            }

            for packID in toUninstall {
                guard let pack = TagPackRegistry.all.first(where: { $0.id == packID }) else {
                    continue
                }
                try DefaultTagSeeder.uninstallPack(pack, context: context)
                logger.info("CategorySyncService: auto-uninstalled pack '\(packID)' from cloud sync")
            }
        } catch {
            logger.error("CategorySyncService: processPackIDsPayload failed — \(error)")
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
            if changedKeys.contains(Self.packIDsKey) || reason == .initialSyncChange {
                pullPackIDsFromCloud()
            }
        case .accountChange:
            pullCategoriesFromCloud()
            pullPackIDsFromCloud()
        case .quotaViolationChange:
            logger.error("CategorySyncService: iCloud KVS quota violated — sync paused")
        case .unknown:
            logger.warning("CategorySyncService: unknown KVS change reason (\(reasonRaw)) — ignoring")
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
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let date = Self.iso8601Formatter.date(from: dateString) {
                    return date
                }
                // Fallback: try standard ISO 8601 without fractional seconds
                let fallback = ISO8601DateFormatter()
                if let date = fallback.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO 8601 date: \(dateString)")
            }
            let cloudCategories = try decoder.decode([SyncableCategory].self, from: data)
            try mergeCloudCategories(cloudCategories, into: context)
            logger.info("CategorySyncService: merged \(cloudCategories.count) categories from payload")
        } catch {
            logger.error("CategorySyncService: process payload failed — \(error)")
        }
    }

    /// Merge strategy:
    /// - UUID match, cloud newer → update local fields
    /// - UUID match, local newer or equal → keep local (last-write-wins)
    /// - UUID not in local → insert
    /// - UUID not in cloud → keep local (no deletion on pull)
    /// - Simultaneous edit → most recent `modifiedAt` wins
    private func mergeCloudCategories(_ cloudCategories: [SyncableCategory], into context: ModelContext) throws {
        let localCategories = try context.fetch(FetchDescriptor<TagCategory>())
        let localByUUID = Dictionary(localCategories.map { ($0.uuid.uuidString, $0) }, uniquingKeysWith: { first, _ in first })

        // Deduplicate cloud payload by UUID (keep last occurrence — most recent push wins)
        var seenUUIDs = Set<String>()
        var uniqueCloud: [SyncableCategory] = []
        for cat in cloudCategories.reversed() {
            if seenUUIDs.insert(cat.uuid).inserted {
                uniqueCloud.append(cat)
            }
        }

        for remote in uniqueCloud {
            if let local = localByUUID[remote.uuid] {
                // UUID match — compare modifiedAt for last-write-wins
                let localModifiedAt = cachedModifiedAt[remote.uuid] ?? .distantPast
                guard remote.modifiedAt > localModifiedAt else {
                    // Local is newer or equal — keep local fields
                    continue
                }

                let oldName = local.name
                let nameChanged = oldName != remote.name

                local.name = remote.name
                local.colorHex = remote.colorHex
                local.iconName = remote.iconName
                local.sortOrder = remote.sortOrder
                local.isDefault = remote.isDefault

                // Update cached timestamp to reflect applied cloud version
                cachedModifiedAt[remote.uuid] = remote.modifiedAt

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

                // Cache the cloud timestamp for newly inserted category
                cachedModifiedAt[remote.uuid] = remote.modifiedAt
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
