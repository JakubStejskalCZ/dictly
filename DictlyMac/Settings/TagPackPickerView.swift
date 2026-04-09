import SwiftUI
import SwiftData
import OSLog
import DictlyModels
import DictlyStorage
import DictlyTheme

private let logger = Logger(subsystem: "com.dictly.mac", category: "TagPacks")

struct TagPackPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CategorySyncService.self) private var syncService

    let isOnboarding: Bool
    var onComplete: (() -> Void)?

    @State private var selectedPackIDs: Set<String> = []
    @State private var installedPackIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            if isOnboarding {
                headerSection
                Divider()
            }
            packList
                .padding(DictlySpacing.md)
            Divider()
            footerButtons
        }
        .frame(width: 480, height: isOnboarding ? 420 : 360)
        .onAppear { loadInstalledPacks() }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: DictlySpacing.sm) {
            Text("Choose Tag Packs")
                .font(DictlyTypography.h1)
            Text("Pick one or more tag packs to get started.\nYou can always change this later in Preferences.")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DictlySpacing.lg)
    }

    private var packList: some View {
        VStack(spacing: DictlySpacing.sm) {
            ForEach(TagPackRegistry.all) { pack in
                PackRow(
                    pack: pack,
                    isSelected: selectedPackIDs.contains(pack.id),
                    isInstalled: installedPackIDs.contains(pack.id),
                    isOnboarding: isOnboarding
                ) {
                    if isOnboarding {
                        toggleSelection(pack)
                    } else {
                        toggleInstallation(pack)
                    }
                }
            }
        }
    }

    private var footerButtons: some View {
        HStack {
            if isOnboarding {
                Button("Skip") {
                    onComplete?()
                    dismiss()
                }
                Spacer()
                Button("Install") {
                    installSelected()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPackIDs.isEmpty)
            } else {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DictlySpacing.md)
    }

    // MARK: - Actions

    private func loadInstalledPacks() {
        installedPackIDs = (try? DefaultTagSeeder.installedPackIDs(context: modelContext)) ?? []
    }

    private func toggleSelection(_ pack: TagPack) {
        if selectedPackIDs.contains(pack.id) {
            selectedPackIDs.remove(pack.id)
        } else {
            selectedPackIDs.insert(pack.id)
        }
    }

    private func toggleInstallation(_ pack: TagPack) {
        do {
            if installedPackIDs.contains(pack.id) {
                try DefaultTagSeeder.uninstallPack(pack, context: modelContext)
                installedPackIDs.remove(pack.id)
            } else {
                let sortOrder = try DefaultTagSeeder.nextSortOrder(context: modelContext)
                try DefaultTagSeeder.installPack(pack, startingSortOrder: sortOrder, context: modelContext)
                installedPackIDs.insert(pack.id)
            }
            syncService.pushCategoriesToCloud()
            syncService.pushPackIDsToCloud()
            syncService.pushTagsToCloud()
        } catch {
            logger.error("Failed to toggle pack \(pack.id): \(error)")
        }
    }

    private func installSelected() {
        do {
            var sortOrder = try DefaultTagSeeder.nextSortOrder(context: modelContext)
            for pack in TagPackRegistry.all where selectedPackIDs.contains(pack.id) {
                try DefaultTagSeeder.installPack(pack, startingSortOrder: sortOrder, context: modelContext)
                sortOrder += pack.categories.count
            }
            syncService.pushCategoriesToCloud()
            syncService.pushPackIDsToCloud()
            syncService.pushTagsToCloud()
        } catch {
            logger.error("Failed to install packs: \(error)")
        }
        onComplete?()
        dismiss()
    }
}

// MARK: - Pack Row

private struct PackRow: View {
    let pack: TagPack
    let isSelected: Bool
    let isInstalled: Bool
    let isOnboarding: Bool
    let action: () -> Void

    private var isActive: Bool { isOnboarding ? isSelected : isInstalled }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DictlySpacing.md) {
                Image(systemName: pack.iconName)
                    .font(.title3)
                    .frame(width: 32)
                    .foregroundStyle(isActive ? Color.accentColor : DictlyColors.textPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.name)
                        .font(DictlyTypography.h3)
                        .foregroundStyle(DictlyColors.textPrimary)
                    Text(pack.description)
                        .font(DictlyTypography.caption)
                        .foregroundStyle(DictlyColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(pack.categories.count) categories")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isActive ? Color.accentColor : DictlyColors.border)
                    .font(.title3)
            }
            .padding(DictlySpacing.sm)
            .background(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
