# Contributing to DhikrFlow

First off, thank you for considering contributing to DhikrFlow (ذِكْر فْلُو)! 

DhikrFlow is an open-source, 100% offline, privacy-first companion for hands-free remembrance of Allah. To preserve the integrity and mission of the application, all contributions must respect our core tenets.

---

## 🔒 Non-Negotiable Tenets

Before submitting a feature or pull request, please review these essential constraints:

1. **Strictly 100% Offline**: Core functionality must work with zero network connection. No cloud speech APIs, no server dependencies.
2. **Zero Telemetry or Analytics**: Do not add tracking, crashlytics, or analytics SDKs.
3. **Audio Privacy**: Microphone audio must never be persisted to storage or transmitted over the wire. Transient in-memory audio buffers only.
4. **No User Accounts / Cloud Sync**: Data stays on the user's device (SQLite / local prefs).

---

## 🛠️ Getting Started

1. **Fork and clone the repository:**
   ```bash
   git clone https://github.com/your-username/dhikrflow.git
   cd dhikrflow
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify tests and analysis:**
   ```bash
   flutter analyze
   flutter test
   ```

---

## 📐 Guidelines for Code & Adhkar

* **Sound Null-Safety**: All Dart code must be null-safe and pass `flutter analyze` with zero warnings or errors.
* **Classical Arabic Orthography**: Any additions to the Adhkar catalog must strictly adhere to liturgical waqf codas (sukūn on final vowels to prevent case-ending confusion) and proper Unicode Quranic glyphs (e.g., `ٱللّٰه`).
* **Test Coverage**: Any new domain logic, DSP filters, or repetition detectors should include comprehensive unit tests in the `test/` directory.

---

## 🤝 Submitting Changes

1. Create a feature branch (`git checkout -b feature/my-enhancement`).
2. Commit your changes with clear semantic commit messages (e.g. `feat: ...`, `fix: ...`).
3. Ensure all tests pass (`flutter test`).
4. Push to your fork and submit a Pull Request.

Thank you for helping make DhikrFlow beneficial for everyone!
