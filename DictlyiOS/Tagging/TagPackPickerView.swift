import SwiftUI
import SwiftData
import OSLog
import DictlyModels
import DictlyStorage
import DictlyTheme

private let logger = Logger(subsystem: "com.dictly.ios", category: "TagPacks")

struct TagPackPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CategorySyncService.self) private var syncService

    let isOnboarding: Bool
    var onComplete: (() -> Void)?

    @State private var selectedPackIDs: Set<String> = []
    @State private var installedPackIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DictlySpacing.lg) {
                    if isOnboarding {
                        headerSection
                    }
                    packGrid
                }
                .padding(DictlySpacing.md)
            }
            .background(DictlyColors.background)
            .navigationTitle(isOnboarding ? "Choose Tag Packs" : "Tag Packs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isOnboarding {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Skip") {
                            onComplete?()
                            dismiss()
                        }
                        .foregroundStyle(DictlyColors.textSecondary)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Install") {
                            installSelected()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedPackIDs.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .onAppear { loadInstalledPacks() }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.sm) {
            Text("What will you be recording?")
                .font(DictlyTypography.h2)
            Text("Pick one or more tag packs to get started. You can always change this later in Settings.")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)
        }
    }

    private var packGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DictlySpacing.md) {
            ForEach(TagPackRegistry.all) { pack in
                PackCard(
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
        } catch {
            logger.error("Failed to install packs: \(error)")
        }
        onComplete?()
        dismiss()
    }
}

// MARK: - Pack Card

private struct PackCard: View {
    let pack: TagPack
    let isSelected: Bool
    let isInstalled: Bool
    let isOnboarding: Bool
    let action: () -> Void

    private var isActive: Bool { isOnboarding ? isSelected : isInstalled }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DictlySpacing.sm) {
                HStack {
                    Image(systemName: pack.iconName)
                        .font(.title2)
                        .foregroundStyle(isActive ? .white : DictlyColors.textPrimary)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                }
                Text(pack.name)
                    .font(DictlyTypography.h3)
                    .foregroundStyle(isActive ? .white : DictlyColors.textPrimary)
                Text(pack.description)
                    .font(DictlyTypography.caption)
                    .foregroundStyle(isActive ? .white.opacity(0.8) : DictlyColors.textSecondary)
                    .lineLimit(2)
                Text("\(pack.categories.count) categories, \(pack.tags.values.reduce(0) { $0 + $1.count }) tags")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(isActive ? .white.opacity(0.7) : DictlyColors.textSecondary)
            }
            .padding(DictlySpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isActive ? Color.accentColor : DictlyColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.clear : DictlyColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pack.name) tag pack")
        .accessibilityHint(isActive ? "Selected" : "Tap to select")
    }
}
