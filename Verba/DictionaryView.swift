import SwiftUI

enum DictionaryFilter: String, CaseIterable {
    case all
    case autoAdded
    case manual
}

struct DictionaryView: View {
    @EnvironmentObject var appState: AppState
    @State private var filter: DictionaryFilter = .all
    @State private var searchQuery = ""
    @State private var showSearch = false
    @State private var editingEntry: DictionaryEntry? = nil
    @State private var isCreatingEntry = false

    private var filteredEntries: [DictionaryEntry] {
        var entries = appState.dictionaryEntries
        switch filter {
        case .all: break
        case .autoAdded: entries = entries.filter { $0.isAutoAdded }
        case .manual: entries = entries.filter { !$0.isAutoAdded }
        }
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            entries = entries.filter {
                $0.term.lowercased().contains(q) ||
                $0.readings.contains(where: { $0.lowercased().contains(q) })
            }
        }
        return entries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(appState.l10n.dictionaryNav)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DS.textNormal)
                Spacer()
                Button {
                    isCreatingEntry = true
                    editingEntry = DictionaryEntry(term: "")
                } label: {
                    Text(appState.l10n.newWord)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(DS.blurple)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 16)

            // Filter tabs + search
            HStack(spacing: 0) {
                HStack(spacing: 2) {
                    ForEach(DictionaryFilter.allCases, id: \.self) { f in
                        FilterTab(
                            label: filterLabel(f),
                            icon: filterIcon(f),
                            isSelected: filter == f
                        ) {
                            withAnimation(.easeOut(duration: 0.15)) { filter = f }
                        }
                    }
                }
                .padding(3)
                .background(DS.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))

                Spacer()

                if showSearch {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.textFaint)
                        TextField("Search...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.textNormal)
                            .frame(width: 160)
                        Button {
                            searchQuery = ""
                            withAnimation { showSearch = false }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.textFaint)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DS.inputBg)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    Button {
                        withAnimation { showSearch = true }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.textMuted)
                            .padding(8)
                            .background(DS.bgTertiary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)

            // Content
            if filteredEntries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ], spacing: 10) {
                        ForEach(filteredEntries) { entry in
                            DictionaryCard(
                                entry: entry,
                                onEdit: {
                                    isCreatingEntry = false
                                    editingEntry = entry
                                },
                                onDelete: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        appState.deleteDictionaryEntry(entry)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(DS.bgSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editingEntry) { entry in
            DictionaryEditorSheet(
                entry: entry,
                isNew: isCreatingEntry,
                l10n: appState.l10n,
                onSave: { saved in
                    if isCreatingEntry {
                        appState.addDictionaryEntry(saved)
                    } else {
                        appState.updateDictionaryEntry(saved)
                    }
                    editingEntry = nil
                    isCreatingEntry = false
                },
                onCancel: {
                    editingEntry = nil
                    isCreatingEntry = false
                }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "character.book.closed")
                .font(.system(size: 36))
                .foregroundStyle(DS.textFaint)
            Text(appState.l10n.noDictionaryEntries)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DS.textMuted)
            Text(appState.l10n.dictionaryDesc)
                .font(.system(size: 13))
                .foregroundStyle(DS.textFaint)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func filterLabel(_ f: DictionaryFilter) -> String {
        switch f {
        case .all: return appState.l10n.filterAll
        case .autoAdded: return appState.l10n.filterAutoAdded
        case .manual: return appState.l10n.filterManual
        }
    }

    private func filterIcon(_ f: DictionaryFilter) -> String? {
        switch f {
        case .all: return nil
        case .autoAdded: return "sparkles"
        case .manual: return "pencil"
        }
    }
}

// MARK: - Filter Tab

struct FilterTab: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? DS.blurple : DS.textFaint)
                }
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DS.textNormal : DS.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? DS.cardBg : isHovered ? DS.bgModifierHover : .clear)
            )
            .shadow(color: isSelected ? .black.opacity(0.04) : .clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Dictionary Card

struct DictionaryCard: View {
    let entry: DictionaryEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isAutoAdded ? "sparkles" : "pencil")
                .font(.system(size: 10))
                .foregroundStyle(entry.isAutoAdded ? DS.blurple : DS.textFaint)
                .frame(width: 14)

            Text(entry.term)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.textNormal)
                .lineLimit(1)

            Spacer(minLength: 4)

            if isHovered {
                HStack(spacing: 2) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.textMuted)
                            .padding(4)
                            .background(DS.bgModifierHover)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.red)
                            .padding(4)
                            .background(DS.bgModifierHover)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DS.radiusMedium)
                .fill(isHovered ? DS.bgModifierHover : DS.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusMedium)
                .stroke(isHovered ? DS.blurple.opacity(0.3) : DS.cardBorder, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
