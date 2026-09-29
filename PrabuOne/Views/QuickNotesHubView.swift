import SwiftUI

/// Dedicated Scratchpad & Quick Notes Hub for instant thoughts, memos, and checklists with timed reminders.
public struct QuickNotesHubView: View {
    @ObservedObject var store: LifeStore
    @State private var showingAddNote = false
    @State private var selectedNoteToEdit: QuickNote? = nil
    @State private var noteSearchText = ""
    @State private var selectedFilter: NoteFilter = .all
    @State private var copiedToast: String? = nil
    
    public enum NoteFilter: String, CaseIterable {
        case all = "All Notes"
        case reminders = "Reminders"
    }
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var baseNotes: [QuickNote] {
        switch selectedFilter {
        case .all:
            return store.quickNotes
        case .reminders:
            return store.quickNotes.filter { $0.hasReminder }
        }
    }
    
    private var filteredNotes: [QuickNote] {
        let query = noteSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        let notes = baseNotes
        if query.isEmpty {
            return notes.sorted { (a, b) -> Bool in
                if a.isPinned == b.isPinned {
                    return a.updatedAt > b.updatedAt
                }
                return a.isPinned && !b.isPinned
            }
        }
        return notes.filter {
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
    
    private var totalRemindersCount: Int {
        store.quickNotes.filter { $0.hasReminder }.count
    }
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Segment Filter & Search Bar
                    VStack(spacing: 12) {
                        Picker("Filter", selection: $selectedFilter) {
                            Text("All Notes (\(store.quickNotes.count))").tag(NoteFilter.all)
                            Text("Reminders 🔔 (\(totalRemindersCount))").tag(NoteFilter.reminders)
                        }
                        .pickerStyle(.segmented)
                        
                        // Search Bar
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search notes, memos, or reminders...", text: $noteSearchText)
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
                    }
                    
                    if store.quickNotes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "note.text.badge.plus")
                                .font(.system(size: 46))
                                .foregroundColor(.amberAccent)
                                .padding(.top, 40)
                            
                            Text("No Notes Yet")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("Capture sudden thoughts, parking slots, ideas, codes, or schedule quick reminders.")
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
                    } else if selectedFilter == .reminders && filteredNotes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 42))
                                .foregroundColor(.secondary)
                                .padding(.top, 30)
                            
                            Text("No Reminders Set")
                                .font(.headline)
                            
                            Text("Add a note and set a timed reminder to get alerted on your phone.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.vertical, 30)
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
                                        }, onToggleReminder: {
                                            store.toggleNoteReminderCompleted(note)
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
                                    Text(selectedFilter == .reminders ? "OTHER REMINDERS" : "OTHER NOTES")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    ForEach(otherNotes) { note in
                                        QuickNoteCard(note: note, onSelect: {
                                            selectedNoteToEdit = note
                                        }, onTogglePin: {
                                            store.togglePinQuickNote(note)
                                        }, onToggleReminder: {
                                            store.toggleNoteReminderCompleted(note)
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

/// Visual card for a quick note in the grid with dedicated reminder badge.
struct QuickNoteCard: View {
    let note: QuickNote
    let onSelect: () -> Void
    let onTogglePin: () -> Void
    var onToggleReminder: (() -> Void)? = nil
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
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                
                // Dedicated Reminder Pill
                if let reminderText = note.formattedReminder {
                    Button(action: {
                        onToggleReminder?()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: note.isReminderCompleted ? "checkmark.circle.fill" : (note.isReminderOverdue ? "bell.badge.fill" : "bell.fill"))
                                .font(.system(size: 10))
                            
                            Text(note.isReminderCompleted ? "Done" : reminderText)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(reminderBadgeBackground)
                        .foregroundColor(reminderBadgeForeground)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
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
            if note.hasReminder {
                Button(action: { onToggleReminder?() }) {
                    Label(note.isReminderCompleted ? "Mark Reminder Pending" : "Mark Reminder Done",
                          systemImage: note.isReminderCompleted ? "bell" : "checkmark.circle")
                }
            }
            
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
    
    private var reminderBadgeBackground: Color {
        if note.isReminderCompleted {
            return Color.gray.opacity(0.18)
        } else if note.isReminderOverdue {
            return Color.red.opacity(0.18)
        } else {
            return Color.amberAccent.opacity(0.2)
        }
    }
    
    private var reminderBadgeForeground: Color {
        if note.isReminderCompleted {
            return Color.secondary
        } else if note.isReminderOverdue {
            return Color.red
        } else {
            return Color.amberAccent
        }
    }
}

/// Instant note creation & editing sheet with dedicated reminder options and quick presets.
public struct NoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    let noteToEdit: QuickNote?
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isPinned: Bool = false
    @State private var colorTag: String = "yellow"
    
    // Dedicated Reminder State
    @State private var hasReminder: Bool = false
    @State private var reminderDate: Date = Date().addingTimeInterval(3600)
    
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
                
                // Note Content & Reminder Options
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Note Title (Optional)", text: $title)
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                        
                        Divider().padding(.horizontal, 16)
                        
                        TextEditor(text: $content)
                            .focused($isContentFocused)
                            .font(.system(size: 16))
                            .frame(minHeight: 180)
                            .padding(.horizontal, 12)
                            .scrollContentBackground(.hidden)
                            .overlay(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text("Suddenly note something here... (parking slot, code, ideas, lists)")
                                        .foregroundColor(Color(UIColor.placeholderText))
                                        .font(.system(size: 16))
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                        
                        Divider().padding(.horizontal, 16)
                        
                        // Dedicated Reminder Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundColor(.amberAccent)
                                        .font(.system(size: 16))
                                    Text("Reminder Alert")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $hasReminder)
                                    .labelsHidden()
                                    .tint(.amberAccent)
                            }
                            
                            if hasReminder {
                                VStack(spacing: 12) {
                                    // Quick Presets
                                    HStack(spacing: 8) {
                                        presetButton(title: "In 1 Hour", icon: "clock.arrow.circlepath") {
                                            reminderDate = Date().addingTimeInterval(3600)
                                        }
                                        
                                        presetButton(title: "Tonight 8 PM", icon: "moon.fill") {
                                            var comp = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                                            comp.hour = 20
                                            comp.minute = 0
                                            var target = Calendar.current.date(from: comp) ?? Date()
                                            if target <= Date() {
                                                target = Calendar.current.date(byAdding: .day, value: 1, to: target) ?? Date()
                                            }
                                            reminderDate = target
                                        }
                                        
                                        presetButton(title: "Tomorrow 9 AM", icon: "sun.max.fill") {
                                            var comp = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
                                            comp.hour = 9
                                            comp.minute = 0
                                            reminderDate = Calendar.current.date(from: comp) ?? Date()
                                        }
                                    }
                                    
                                    // Custom Date & Time Picker
                                    DatePicker("Alert At", selection: $reminderDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                        .font(.system(size: 14, weight: .medium))
                                        .tint(.amberAccent)
                                        .padding(10)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(10)
                                }
                                .padding(.top, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
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
                    hasReminder = note.hasReminder
                    if let d = note.reminderDate {
                        reminderDate = d
                    }
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
    
    private func presetButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private func saveNote() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalReminderDate: Date? = hasReminder ? reminderDate : nil
        
        if let existing = noteToEdit {
            var updated = existing
            updated.title = cleanTitle
            updated.content = cleanContent
            updated.isPinned = isPinned
            updated.colorTag = colorTag
            updated.reminderDate = finalReminderDate
            // If the reminder date was changed or extended into the future, mark not completed
            if let newDate = finalReminderDate, newDate > Date() {
                updated.isReminderCompleted = false
            }
            store.updateQuickNote(updated)
        } else {
            store.addQuickNote(
                title: cleanTitle,
                content: cleanContent,
                colorTag: colorTag,
                isPinned: isPinned,
                reminderDate: finalReminderDate
            )
        }
        dismiss()
    }
}

// Color helper
extension Color {
    static let amberAccent = Color(red: 0.95, green: 0.65, blue: 0.1)
}
