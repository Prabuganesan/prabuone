# 🌟 Prabu One — Personal Life Operating System

> **One unified, private, on-device iOS app for everything that matters:** vehicle maintenance, credit cards, recurring subscriptions, digital document vault, family milestones, and in-car display screen mirroring.

![Prabu One Logo](PrabuOne/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)

---

## 📖 Overview

**Prabu One** transforms your iPhone into your central personal operating command hub. Instead of fragmenting your life across single-purpose apps, Prabu One brings financial obligations, vehicle telemetry & health, document expirations, and life events under a single **attention-driven architecture**.

### 🔒 100% Private, Real & On-Device
- **Complete Editability Across Every Feature**: Every single metric, due target, date, balance, and record can be edited, updated, or deleted with instant feedback and disk persistence.
- **Zero Dummy Data**: Clean initial state without mock data or clutter, immediately ready for your real accounts, documents, and vehicle details.
- **Zero Third-Party Trackers**: No analytics SDKs, telemetry servers, or cloud dependencies.
- **Local Persistence**: All records are securely saved into your iPhone's protected application sandbox (`JSON` with atomic file writes).
- **Offline First**: Works without internet connectivity; alerts are scheduled natively with `UserNotifications`.
- **Zero Developer Fees**: Configured to build, sign, and install using a **Free Personal Apple ID** without requiring an Apple Developer Program membership.

---

## 🏛️ Core Life Pillars & Features

### 1. 🚗 Vehicle Hub (Kia Sonet & Daily Driver)
- **100% Editable Telemetry & Parameters**:
  - **Next Service Due Target (km)**: Tap the stat card or quick-edit to enter your exact target service interval (e.g. 50,000 km). Remaining km is automatically computed in real-time against your odometer.
  - **PUC Pollution Expiry Date**: Tap the PUC card to open the date picker and update certificate validity with automatic alert re-scheduling.
  - **Insurance Expiry Date**: Tap the Insurance card to update policy expiry dates.
  - **Live Odometer**: Tap "Update km" anytime to record new odometer readings.
  - **FASTag Balance**: Tap to adjust your active balance with low-balance thresholds.
  - **Full Profile Editor**: Tap the top pencil icon to edit Make & Model, Registration Number, Fuel Type, Odometer, Target Service, FASTag, Insurance, and PUC in one screen.
- **Service Records Management**: Add, view, edit (title, date, odometer, cost, service center, replaced parts), or delete maintenance entries.
- **Fuel Logs & Economy**: Add, view, edit (date, odometer, liters, cost), or delete refuel logs with dynamic fuel economy calculation (`km/L`).

### 2. 💳 Cards & Banking Vault (Credit, Debit & Bank Accounts)
- **Separate Dedicated Tabs**:
  - **Credit Cards Tab**: Dedicated view for credit cards with total credit limit tracking and payment due day reminders.
  - **Debit Cards Tab**: Dedicated view for daily bank debit cards with spend/ATM limit tracking.
  - **Bank Accounts Tab**: Dedicated view for savings, current, and salary bank accounts with IFSC codes and UPI VPAs.
- **Full Card Credentials Storage**:
  - Full 16-digit card number with 4-digit formatted grouping.
  - CVV security code (3 or 4 digits).
  - Valid Thru / Expiry date (`MM/YY`).
  - Cardholder name & auto-detected card network (Visa, Mastercard, RuPay, Amex).
- **Security PINs (ATM PIN & TPIN)**:
  - **ATM PIN (4 digits)**: Securely stored on-device for physical cash withdrawals and merchant PIN verification.
  - **TPIN / NetBanking PIN (4-6 digits)**: Transaction PIN for mobile banking, demat/CDSL verification, and online transactions.
  - **1-Tap Quick Copy Actions**: Tap "Copy ATM PIN" or "Copy TPIN" to instantly copy credentials with haptic feedback.
- **Privacy Masking & Instant Access**:
  - **Show / Hide Privacy Toggle**: Tap the eye icon 👁 to toggle masking for card numbers, CVVs, ATM PINs, and TPINs.
  - **1-Tap Quick Copy Bar**: Horizontal scrollable action bar with quick copy for **Card Number**, **CVV**, **Expiry Date**, **ATM PIN**, and **TPIN**.
- **Expanded Blue Shade Color Themes & Luxury Finishes**:
  - **7 Tailored Blue Shades**:
    - 🌌 **Midnight**: Midnight Cobalt
    - ⚓ **Deep Navy**: Executive Corporate Navy
    - 💎 **Sapphire**: Electric Royal Sapphire
    - 🌊 **Pacific Blue**: Deep Ocean Cyan-Blue
    - 🧊 **Arctic Cyan**: Crisp Glacier Ice-Blue
    - 🏙️ **Steel Slate**: Sleek Industrial Slate-Blue
    - 🌤️ **Sky Azure**: Modern Vibrant Azure
  - **Classic & Luxury Shades**: Obsidian Black, Emerald Green, Titanium Silver, Royal Purple, Rose Gold, and Warm Bronze.
- **🏦 Bank Accounts Vault**:
  - **Complete Bank Details Storage**:
    - Bank Name (with 1-tap quick bank chips for HDFC, ICICI, SBI, Axis, Kotak, Canara, BoB, PNB).
    - Account Type badge: `SAVINGS`, `CURRENT`, or `SALARY`.
    - Full Account Number with formatting and privacy masking (`•••••••• 9876`).
    - IFSC Code with auto-capitalization and monospaced typography.
    - UPI ID (e.g. `prabu@okhdfcbank`) for instant VPA sharing.
    - TPIN / UPI PIN and ATM PIN storage with 1-tap copy.
    - Branch Name & Account Holder Name.
  - **1-Tap Quick Copy Actions**:
    - Dedicated quick copy buttons for **Account Number**, **IFSC Code**, **UPI ID**, **TPIN**, and **ATM PIN** with tactile haptic feedback and onscreen toast confirmation.
  - **Passbook Design & Themes**:
    - Passbook-style bank cards styled with your choice of the 7 blue shades or luxury finishes.
  - **Encrypted Local Persistence**: All credentials remain 100% encrypted in your local device sandbox with zero cloud transmission.

### 3. 🔁 Subscriptions Hub (Recurring Subscriptions Only)
- **Dedicated Subscriptions Hub**: Focused exclusively on recurring services (OTT, Cloud, AI tools, memberships).
- **Run-Rate Analytics**: Computes monthly recurring burn rate and annualized run-rate calculations.
- **Full Editability**: Tap any subscription or use context menu to edit title, subtitle, category, due date, amount, renewal frequency (monthly/yearly), and notes.
- **Quick Add**: Direct "+" action to add subscriptions without selecting categories.

### 4. 📱 Mobile & Bills Hub (SIM & Utility Plans Only)
- **Dedicated Utility Hub**: Dedicated exclusively to SIM recharges, broadband plans, electricity, and utility commitments.
- **Commitment Overview**: Track total monthly utility outflow and upcoming due dates.
- **Full Editability**: Tap any bill or use context menu to edit provider title, plan subtitle, amount, renewal date, and notes.

### 5. 🗄️ Digital Document Vault & File Uploads
- **Official Records Vault**: Store vehicle RC Book, Driving License, Passport, Aadhaar, PAN, Insurance Policies, and PUC Certificates.
- **Document Upload (Photos & PDFs)**:
  - Attach scans and files via **Photo Library** (`PhotosPicker`) or **File/PDF Importer** (`fileImporter`).
  - Encrypted, on-device sandboxed persistence in `vault_attachments/` with automatic garbage collection when documents are deleted or replaced.
- **In-App Document Viewer & PDFKit**:
  - Tap any attached document card to view it directly in the app.
  - Multi-page PDF viewer powered by `PDFKit` and high-resolution pinch-to-zoom photo previewer.
  - Native iOS share sheet (`ShareLink`) to export, AirDrop, or send documents anywhere.
- **Full Edit Support**: Tap pencil button or context menu "Edit Document" to modify document name, type, registration number, expiration date, or upload new attachments.
- **Live Validity Badges**:
  - 🟢 **VALID**
  - 🟠 **EXPIRING SOON** (< 30 days)
  - 🔴 **EXPIRED**
- **One-Tap Copy to Clipboard**: Tap any document number to copy it instantly with a tactile haptic HUD.

### 6. 🎂 Birthdays & Life Milestones
- **Countdown to Moments**: Track days remaining until family birthdays and wedding anniversaries.
- **Milestone Editor**: Tap pencil button or context menu to update name, celebration description, event date, and gift / dinner planning notes.
- **Smart Reminders**: Automated multi-stage alerts at 30 days, 7 days, 1 day, and on the day.

### 7. 📝 Quick Notes with Dedicated Reminders (Instant Scratchpad)
- **Sudden Thought Capture**: 1-tap action directly from the top header or the Quick Notes hub to note ideas, parking slot numbers, gate passes, locker codes, or temporary checklists instantly.
- **Dedicated Timed Reminders**:
  - Toggle "Reminder Alert" on any note to receive local push notification alerts at the exact scheduled time.
  - **Quick Presets**: 1-tap buttons for "In 1 Hour", "Tonight 8 PM", and "Tomorrow 9 AM", or custom Date & Time picker.
  - **Interactive Reminder Badges**: Note cards display live status (🔔 Upcoming, ⚠️ Overdue, or ✅ Done) with 1-tap toggle to mark as done.
  - **Dedicated Reminders Filter**: Toggle between "All Notes" and "Reminders 🔔" to view all time-sensitive tasks in one place.
- **Immediate Keyboard Auto-Focus**: No mandatory fields or forms required — tap, type, and save with zero friction.
- **Pin Important Notes**: Keep vital codes or reminders pinned at the top.
- **Color Accent Tagging**: Visual organization with 5 curated color accents (Amber Yellow, Sky Blue, Emerald Green, Indigo Purple, Coral Rose).
- **Universal Search Integration**: All notes and memos are searchable directly from the home screen universal search bar.
- **One-Tap Copy & Share**: Copy note content to clipboard with tactile haptic feedback.

### 8. 🔴 Attention-Driven Dashboard
- **"Needs Attention" Radar**: Dynamically surfaces bills, service dues, policy renewals, or birthdays due today or within 7 days.
- **Tap-to-Edit Attention Items**: Tap any item in the attention card or search results to open the editor directly.
- **Monthly Outflow Predictor**: Computes total committed expenditure (₹) for the current calendar month.
- **Universal Instant Search**: Search across cards, subscriptions, utility bills, vehicle records, documents, birthdays, and quick notes.
- **Multi-Stage Local Reminders**: Proactive push notifications scheduled automatically at **30 days, 7 days, 3 days, 1 day, and 0 days** prior to due dates.

### 9. 🪞 Car Mirror & In-Car Cockpit Display
- **In-Car Cockpit HUD (Full-Screen Landscape / AMOLED Dark Mode)**:
  - Specially designed high-contrast cockpit dashboard for car displays (16:9 / 21:9 aspect ratios) with anti-glare styling.
  - **Live Vehicle Health**: Real-time odometer, distance to next service interval with warning colors (< 1000 km in amber).
  - **Toll & Compliance**: FASTag balance with low-balance warning, live PUC pollution expiry days remaining, and insurance status.
  - **Driver Quick Notes**: Directly surfaces your active driver notes (parking bay number, gate pass codes, temporary checklists).
  - **Emergency Roadside Assistance**: 1-tap direct dial buttons for Highway RSA (1033), Police (112), and Ambulance (108).
- **AirPlay Screen Mirroring & External Display Support**:
  - Live auto-detection of external car screens and AirPlay receivers (`UIScreen.didConnectNotification`).
  - Seamless 1-2-3 guide on mirroring via iOS Control Center -> Screen Mirroring to wireless CarPlay dongles, Android headunits, or AirPlay receivers.
- **CarPlay Scene Architecture (`CPTemplateApplicationSceneDelegate`)**:
  - Registered `CPTemplateApplicationSceneSessionRoleApplication` in `Info.plist` with `CarPlaySceneDelegate`.
  - Native integration with Xcode CarPlay Simulator (`I/O > External Displays > CarPlay`) presenting Vehicle Health, FASTag, and Notes templates.
- **Keep-Awake Driver Protection**: Prevents display dimming or auto-lock (`isIdleTimerDisabled = true`) while in the Cockpit HUD.

---

## 🛠️ Tech Stack & Architecture

- **Platform**: iOS 27.0+
- **Language**: Swift 6 / SwiftUI
- **Hardware Acceleration**: `ScreenCaptureKit`, `AVFoundation`
- **Feedback Engine**: Native `UIImpactFeedbackGenerator` & `UINotificationFeedbackGenerator`
- **Architecture**: MVVM + Observable State Store (`LifeStore.shared`) with automatic notification synchronizations (`ReminderEngine.shared`)

---

## 🚀 Building & Installing on Physical iPhone

1. Clone this repository:
   ```bash
   git clone https://github.com/Prabuganesan/prabuone.git
   cd prabuone
   ```

2. Open the project in **Xcode**:
   ```bash
   open PrabuOne.xcodeproj
   ```

3. Connect your iPhone via USB / Wi-Fi:
   - Select your iPhone in the top destination selector.
   - Go to `PrabuOne` target > **Signing & Capabilities**.
   - Ensure your **Personal Apple ID Team** is selected.

4. Press **`Cmd + R`** to compile, install, and run directly on your phone!

---

## 📄 License

Personal project developed by [Prabu Ganesan](https://github.com/Prabuganesan).
