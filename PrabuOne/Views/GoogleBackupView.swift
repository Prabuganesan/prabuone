import SwiftUI
import UniformTypeIdentifiers

/// Dedicated Google Drive Backup and Cloud Restore View for Prabu One.
public struct GoogleBackupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LifeStore
    
    @State private var showingShareSheet = false
    @State private var backupFileURL: URL? = nil
    @State private var showingFileImporter = false
    @State private var restoreAlertMessage = ""
    @State private var showingRestoreConfirmation = false
    @State private var pendingRestoreURL: URL? = nil
    @State private var pendingArchiveSummary = ""
    @State private var successToast: String? = nil
    @State private var errorMessage: String? = nil
    
    public init(store: LifeStore) {
        self.store = store
    }
    
    private var lastBackupDateString: String {
        let timestamp = UserDefaults.standard.double(forKey: "last_google_backup_timestamp")
        guard timestamp > 0 else { return "No backup created yet" }
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Cloud Backup Hero Card
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color.blue, Color.cyan, Color.teal],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 76, height: 76)
                                
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 4) {
                                Text("Google Drive Backup & Sync")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                
                                Text("Secure complete snapshot of all cards, bank accounts, loans, LIC policies, vehicle telemetry, and documents.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.blue)
                                Text("Last Backup: \(lastBackupDateString)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(20)
                        
                        // Current Data Snapshot Card
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Data Snapshot to Backup")
                                .font(.system(size: 15, weight: .bold))
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                snapshotTile(icon: "creditcard.fill", color: .blue, title: "Cards", count: "\(store.creditCards.count)")
                                snapshotTile(icon: "building.columns.fill", color: .indigo, title: "Bank A/Cs", count: "\(store.bankAccounts.count)")
                                snapshotTile(icon: "indianrupeesign.square.fill", color: .red, title: "Loans & EMIs", count: "\(store.loans.count)")
                                snapshotTile(icon: "shield.lefthalf.filled", color: .emeraldAccent, title: "LIC Policies", count: "\(store.licPolicies.count)")
                                snapshotTile(icon: "doc.text.fill", color: .teal, title: "Documents", count: "\(store.documents.count)")
                                snapshotTile(icon: "square.and.pencil", color: .amberAccent, title: "Quick Notes", count: "\(store.quickNotes.count)")
                                snapshotTile(icon: "bell.badge.fill", color: .purple, title: "Commitments", count: "\(store.items.count)")
                                snapshotTile(icon: "car.side.fill", color: .orange, title: "Vehicle", count: store.vehicleProfile.registrationNumber.isEmpty ? "Configured" : store.vehicleProfile.registrationNumber)
                            }
                        }
                        .padding(16)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(18)
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            // 1. Export / Backup to Google Drive
                            Button(action: {
                                performBackup()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.up.doc.fill")
                                        .font(.system(size: 18))
                                    Text("Backup to Google Drive / Files")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(LinearGradient(colors: [Color.blue, Color(red: 0.1, green: 0.45, blue: 0.9)], startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                            }
                            
                            // 2. Restore from Google Drive
                            Button(action: {
                                HapticManager.light()
                                showingFileImporter = true
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.system(size: 18))
                                    Text("Restore from Google Drive / Files")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        
                        // How it works guide
                        VStack(alignment: .leading, spacing: 10) {
                            Text("How Google Drive Backup Works")
                                .font(.system(size: 14, weight: .bold))
                            
                            guideStep(number: "1", text: "Tap 'Backup to Google Drive' to generate a timestamped snapshot of your personal OS.")
                            guideStep(number: "2", text: "In the iOS Share Sheet, select 'Google Drive' to upload directly into your Google Drive account, or save to Files.")
                            guideStep(number: "3", text: "To restore anytime or on a new iPhone, tap 'Restore from Google Drive' and select your JSON backup file.")
                        }
                        .padding(16)
                        .background(Color.blue.opacity(0.06))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
                
                // Toast overlay
                if let toast = successToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(toast)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .shadow(radius: 6)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Google Drive Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = backupFileURL {
                    ShareSheetView(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let selectedURL = urls.first else { return }
                    prepareRestore(from: selectedURL)
                case .failure(let error):
                    errorMessage = "File picker error: \(error.localizedDescription)"
                }
            }
            .alert("Confirm Restore from Backup", isPresented: $showingRestoreConfirmation) {
                Button("Restore Data", role: .destructive) {
                    if let url = pendingRestoreURL {
                        finalizeRestore(from: url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will replace your current data with the contents of this Google Drive backup:\n\n\(pendingArchiveSummary)\n\nAre you sure you want to proceed?")
            }
            .alert("Backup Error", isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Actions
    
    private func performBackup() {
        HapticManager.light()
        do {
            let fileURL = try store.exportBackupArchive()
            self.backupFileURL = fileURL
            self.showingShareSheet = true
            showToast("Backup file ready. Select Google Drive to save!")
        } catch {
            errorMessage = "Failed to export backup: \(error.localizedDescription)"
        }
    }
    
    private func prepareRestore(from url: URL) {
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let archive: PrabuOneBackupArchive
            if let decoded = try? decoder.decode(PrabuOneBackupArchive.self, from: data) {
                archive = decoded
            } else {
                archive = try JSONDecoder().decode(PrabuOneBackupArchive.self, from: data)
            }
            
            self.pendingArchiveSummary = "• \(archive.creditCards.count) Cards\n• \(archive.bankAccounts.count) Bank Accounts\n• \(archive.loans.count) Loans\n• \(archive.licPolicies.count) LIC Policies\n• \(archive.documents.count) Documents\n• \(archive.quickNotes.count) Quick Notes\n• \(archive.items.count) Commitments"
            self.pendingRestoreURL = url
            self.showingRestoreConfirmation = true
        } catch {
            errorMessage = "Invalid Prabu One backup file: \(error.localizedDescription)"
        }
    }
    
    private func finalizeRestore(from url: URL) {
        do {
            let counts = try store.restoreFromBackup(url: url)
            showToast("Restored \(counts.cards) cards, \(counts.loans) loans, \(counts.policies) policies, \(counts.docs) docs!")
            HapticManager.success()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }
    
    private func showToast(_ text: String) {
        withAnimation {
            successToast = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                successToast = nil
            }
        }
    }
    
    // MARK: - UI Helpers
    
    private func snapshotTile(icon: String, color: Color, title: String, count: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(count)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
    }
    
    private func guideStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Native UIKit Share Sheet wrapper for exporting to Google Drive and other apps.
struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
