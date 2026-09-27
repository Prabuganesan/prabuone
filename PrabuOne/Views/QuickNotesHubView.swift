import SwiftUI

/// Dedicated Scratchpad & Quick Notes Hub for instant thoughts, memos, and checklists.
public struct QuickNotesHubView: View {
    @ObservedObject var store: LifeStore
    @State private var showingAddNote = false
    @State private var selectedNoteToEdit: QuickNote? = nil
    @State private var noteSearchText = ""
    @State private var copiedToast: String? = nil
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var filteredNotes: [QuickNote] {
        let query = noteSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        let allNotes = store.quickNotes
        if query.isEmpty {
            return allNotes.sorted { (a, b) -> Bool in
                if a.isPinned == b.isPinned {
                    return a.updatedAt > b.updatedAt
                }
                return a.isPinned && !b.isPinned
            }
        }
        return allNotes.filter {
            $0.title.lowercased().contains(query) ||
            $0.content.lowercased().contains(query)
        }.sorted { (a, b) -> Bool in
            if a.isPinned == b.isPinned {
                return a.updatedAt > b.updatedAt
            }
            return a.isPinned && !b.isPinned
        }
    }
    
    private var pinnedNotes: [QuickNote] {
        filteredNotes.filter { $0.isPinned }
    }
    
    private var otherNotes: [QuickNote] {
        filteredNotes.filter { !$0.isPinned }
    }
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Quick Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search your notes & sudden ideas...", text: $noteSearchText)
                            .font(.system(size: 15))
                        if !noteSearchText.isEmpty {
                            Button(action: { noteSearchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    if store.quickNotes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "note.text.badge.plus")
                                .font(.system(size: 46))
                                .foregroundColor(.amberAccent)
                                .padding(.top, 40)
                            
                            Text("No Notes Yet")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("Capture sudden thoughts, parking slots, ideas, codes, or lists anytime.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            Button(action: {
                                HapticManager.light()
                                showingAddNote = true
                            }) {
                                Label("Write First Note", systemImage: "square.and.pencil")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.amberAccent)
                                    .cornerRadius(12)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 20)
                    } else {
                        // Pinned Section
                        if !pinnedNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.amberAccent)
                                    Text("PINNED")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    ForEach(pinnedNotes) { note in
                                        QuickNoteCard(note: note, onSelect: {
                                            selectedNoteToEdit = note
                                        }, onTogglePin: {
                                            store.togglePinQuickNote(note)
                                        }, onCopy: {
                                            copyNote(note)
                                        }, onDelete: {
                                            store.deleteQuickNote(note)
                                        })
                                    }
                                }
                            }
                        }
                        
                        // All / Other Notes Section
                        if !otherNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                if !pinnedNotes.isEmpty {
                                    Text("OTHER NOTES")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    ForEach(otherNotes) { note in
                                        QuickNoteCard(note: note, onSelect: {
                                            selectedNoteToEdit = note
                                        }, onTogglePin: {
                                            store.togglePinQuickNote(note)
                                        }, onCopy: {
                                            copyNote(note)
                                        }, onDelete: {
                                            store.deleteQuickNote(note)
                                        })
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            
            // Toast HUD
            if let toast = copiedToast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(radius: 6)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Quick Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    HapticManager.light()
                    showingAddNote = true
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.amberAccent)
                }
            }
        }
        .sheet(isPresented: $showingAddNote) {
            NoteEditorSheet(store: store, noteToEdit: nil)
        }
        .sheet(item: $selectedNoteToEdit) { note in
            NoteEditorSheet(store: store, noteToEdit: note)
        }
    }
    
    private func copyNote(_ note: QuickNote) {
        let textToCopy = note.title.isEmpty ? note.content : "\(note.title)\n\n\(note.content)"
        UIPasteboard.general.string = textToCopy
        HapticManager.success()
        withAnimation {
            copiedToast = "Note Copied to Clipboard"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedToast = nil
            }
        }
    }
}

/// Visual card for a quick note in the grid.
struct QuickNoteCard: View {
    let note: QuickNote
    let onSelect: () -> Void
    let onTogglePin: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    private var cardColor: Color {
        switch note.colorTag {
        case "blue": return Color.blue
        case "green": return Color.green
        case "purple": return Color.purple
        case "rose": return Color.pink
        default: return Color.amberAccent
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(note.updatedAt) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "d MMM"
        }
        return formatter.string(from: note.updatedAt)
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Circle()
                        .fill(cardColor)
                        .frame(width: 8, height: 8)
                    
                    Spacer()
                    
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11))
                            .foregroundColor(cardColor)
                    }
                }
                
                Text(note.displayTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                let snippet = note.previewSnippet
                if !snippet.isEmpty {
                    Text(snippet)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer(minLength: 4)
                
                HStack {
                    Text(formattedDate)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(note.isPinned ? cardColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onTogglePin) {
                Label(note.isPinned ? "Unpin Note" : "Pin Note", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            
            Button(action: onCopy) {
                Label("Copy Note", systemImage: "doc.on.doc")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Note", systemImage: "trash")
            }
        }
    }
}

/// Instant note creation & editing sheet with focus on speed.
public struct NoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let noteToEdit: QuickNote?
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isPinned: Bool = false
    @State private var colorTag: String = "yellow"
    @FocusState private var isContentFocused: Bool
    
    let colors: [(name: String, color: Color)] = [
        ("yellow", Color.amberAccent),
        ("blue", Color.blue),
        ("green", Color.green),
        ("purple", Color.purple),
        ("rose", Color.pink)
    ]
    
    public init(store: LifeStore, noteToEdit: QuickNote? = nil) {
        self.store = store
        self.noteToEdit = noteToEdit
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Color & Pin Strip
                HStack(spacing: 14) {
                    ForEach(colors, id: \.name) { item in
                        Button(action: {
                            HapticManager.selection()
                            colorTag = item.name
                        }) {
                            ZStack {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 24, height: 24)
                                
                                if colorTag == item.name {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                        .frame(width: 30, height: 30)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        HapticManager.selection()
                        isPinned.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isPinned ? "pin.fill" : "pin")
                            Text(isPinned ? "Pinned" : "Pin")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isPinned ? Color.amberAccent.opacity(0.18) : Color(UIColor.secondarySystemBackground))
                        .foregroundColor(isPinned ? .amberAccent : .secondary)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                Divider()
                
                // Note Content Editor
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Note Title (Optional)", text: $title)
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                        
                        Divider().padding(.horizontal, 16)
                        
                        TextEditor(text: $content)
                            .focused($isContentFocused)
                            .font(.system(size: 16))
                            .frame(minHeight: 280)
                            .padding(.horizontal, 12)
                            .scrollContentBackground(.hidden)
                            .overlay(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text("Suddenly note something here... (parking bay, locker code, ideas, lists)")
                                        .foregroundColor(Color(UIColor.placeholderText))
                                        .font(.system(size: 16))
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                }
            }
            .navigationTitle(noteToEdit == nil ? "Quick Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let note = noteToEdit {
                    title = note.title
                    content = note.content
                    isPinned = note.isPinned
                    colorTag = note.colorTag
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isContentFocused = true
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                    }
                    .fontWeight(.bold)
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveNote() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let existing = noteToEdit {
            var updated = existing
            updated.title = cleanTitle
            updated.content = cleanContent
            updated.isPinned = isPinned
            updated.colorTag = colorTag
            store.updateQuickNote(updated)
        } else {
            store.addQuickNote(
                title: cleanTitle,
                content: cleanContent,
                colorTag: colorTag,
                isPinned: isPinned
            )
        }
        dismiss()
    }
}

// Color helper
extension Color {
    static let amberAccent = Color(red: 0.95, green: 0.65, blue: 0.1)
}
