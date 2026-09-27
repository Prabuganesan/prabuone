# 🌟 Prabu One — Personal Life Operating System

> **One unified, private, on-device iOS app for everything that matters:** vehicle maintenance, credit cards, recurring subscriptions, digital document vault, family milestones, and in-car display screen mirroring.

![Prabu One Logo](PrabuOne/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)

---

## 📖 Overview

**Prabu One** transforms your iPhone into your central command hub. Instead of fragmenting your personal life across single-purpose apps, Prabu One brings financial obligations, vehicle health, document expirations, and life events under a single **attention-driven architecture**.

### 🔒 100% Private & On-Device
- **Zero Third-Party Trackers**: No analytics SDKs or remote telemetries.
- **Local Persistence**: All data is securely stored directly in your iPhone's protected application sandbox.
- **Offline First**: Works without internet connectivity; alerts are scheduled directly via native `UserNotifications`.
- **Zero Paid Developer Fees**: Configured to build, sign, and install using a **Free Personal Apple ID** without requiring an Apple Developer Program membership.

---

## 🏛️ Core Life Pillars & Features

### 1. 🔴 Attention-Driven Dashboard
- **"Needs Attention" Radar**: Dynamically surfaces bills, service dues, policy renewals, or birthdays due today or within 7 days.
- **Monthly Outflow Predictor**: Computes total committed expenditure (₹) for the current calendar month.
- **Universal Instant Search**: Rapidly filter across credit cards, subscriptions, utility bills, vehicle records, documents, and birthdays.
- **Multi-Stage Local Reminders**: Proactive push notifications scheduled automatically at **30 days, 7 days, 3 days, 1 day, and 0 days** prior to due dates.

### 2. 🚗 Vehicle Hub (Kia Sonet)
- **Live Odometer Tracking**: Quick tap-to-update odometer logging.
- **Service Interval Countdown**: Remaining kilometers and estimated schedule until next periodic maintenance.
- **Refuel & Mileage Logs**: Track liters, fuel rates, total costs, and calculate dynamic fuel economy (`km/L`).
- **Service History**: Log maintenance center visits, replaced parts, and invoices.
- **FASTag Balance Monitor**: One-tap FASTag balance update with low-balance alerts.

### 3. 💳 Money & Cards Hub
- **Credit Card Visualizer**: Live statement generation date, due date countdown, credit limit, available limit, and credit utilization bar.
- **One-Tap "Mark as Paid"**: Instantly resets outstanding dues and synchronizes with home dashboard items.
- **Subscriptions Analytics**: Monthly recurring burn rate and annualized run-rate calculations.
- **Utility & Mobile Recharges**: Manage active prepaid plans and validity countdowns.

### 4. 🗄️ Digital Document Vault
- **Official Records Vault**: Store registration certificates (RC), Driving License, Passport, Comprehensive Insurance, and PUC Pollution certificates.
- **Live Validity Badges**:
  - 🟢 **VALID**
  - 🟠 **EXPIRING SOON** (< 30 days)
  - 🔴 **EXPIRED**
- **One-Tap Copy to Clipboard**: Tap any document number to copy it instantly with a tactile haptic HUD.

### 5. 🎂 Birthdays & Life Milestones
- **Countdown to Moments**: Track days remaining until family birthdays and wedding anniversaries.
- **Gift & Planning Notes**: Keep gift ideas, dinner reservations, and celebration plans alongside each date.

### 6. 🪞 Car Mirror Utility
- **Low-Latency Vehicle Mirroring**: Custom `AVSampleBufferDisplayLayer` hardware preview for streaming your iPhone screen to vehicle CarPlay screens.
- **Keep-Awake Protection**: Prevents display dimming or auto-lock (`isIdleTimerDisabled = true`) while mirroring is active.
- **Immersion Mode**: Tap on the live viewport to toggle distraction-free edge-to-edge mirroring.
- **Cross-Platform Compatibility**: Supports both physical hardware via `ScreenCaptureKit` and iOS Simulators via compile-time guards.

---

## 🛠️ Tech Stack & Architecture

- **Platform**: iOS 27.0+
- **Framework**: SwiftUI, Combine
- **Hardware Acceleration**: `ScreenCaptureKit`, `AVFoundation`
- **Feedback Engine**: Native `UIImpactFeedbackGenerator` & `UINotificationFeedbackGenerator`
- **Architecture**: MVVM + Observable State Store (`LifeStore.shared`)

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
   - Select your iPhone in the top target selector.
   - Go to `PrabuOne` target > **Signing & Capabilities**.
   - Ensure your **Personal Apple ID Team** is selected.

4. Press **`Cmd + R`** to compile, install, and run directly on your phone!

---

## 📄 License

Personal project developed by [Prabu Ganesan](https://github.com/Prabuganesan).
