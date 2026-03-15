import SwiftUI

struct DictionaryView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchQuery = ""
    @State private var showSearch = false
    @State private var editingEntry: DictionaryEntry? = nil
    @State private var isCreatingEntry = false
    @State private var isNewWordHovered = false
    @State private var isSearchHovered = false
    @State private var isExportHovered = false

    private var filteredEntries: [DictionaryEntry] {
        var entries = appState.dictionaryEntries
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            entries = entries.filter {
                $0.term.lowercased().contains(q)
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
                if !appState.dictionaryEntries.isEmpty {
                    Button {
                        exportDictionary()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11))
                            Text(appState.l10n.exportDictionary)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(isExportHovered ? DS.textNormal : DS.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isExportHovered ? DS.bgModifierHover : DS.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSmall))
                    }
                    .buttonStyle(.plain)
                    .onHover { isExportHovered = $0 }
                    .animation(.easeOut(duration: 0.12), value: isExportHovered)
                }
                Button {
                    isCreatingEntry = true
                    editingEntry = DictionaryEntry(term: "")
                } label: {
                    Text(appState.l10n.addTerm)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.textOnAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isNewWordHovered ? DS.blurple.opacity(0.8) : DS.blurple)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMedium))
                }
                .buttonStyle(.plain)
                .onHover { isNewWordHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isNewWordHovered)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 16)

            // Search
            HStack(spacing: 0) {
                Spacer()

                if showSearch {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.textFaint)
                        TextField(appState.l10n.search, text: $searchQuery)
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
                            .foregroundStyle(isSearchHovered ? DS.textNormal : DS.textMuted)
                            .padding(8)
                            .background(isSearchHovered ? DS.bgModifierHover : DS.bgTertiary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isSearchHovered = $0 }
                    .animation(.easeOut(duration: 0.12), value: isSearchHovered)
                    .help(appState.l10n.search)
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

    private func exportDictionary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "verba-dictionary.txt"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let text = appState.dictionaryEntries.map { $0.term }.joined(separator: "\n")
        try? text.write(to: url, atomically: true, encoding: .utf8)
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

}

// MARK: - Dictionary Card

struct DictionaryCard: View {
    let entry: DictionaryEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 10))
                .foregroundStyle(DS.textFaint)
                .frame(width: 14)

            Text(entry.term)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.textNormal)
                .lineLimit(1)

            Spacer(minLength: 4)

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
                .help(L10n.current.edit)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.red)
                        .padding(4)
                        .background(DS.bgModifierHover)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help(L10n.current.delete)
            }
            .opacity(isHovered ? 1 : 0)
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
