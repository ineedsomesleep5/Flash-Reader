# Flash Reader iOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native SwiftUI iOS app named Flash Reader from the existing RSVP web prototype behavior.

**Architecture:** Create a new Xcode project beside the current web prototype and keep native code in focused Swift files. Core RSVP behavior lives in pure Swift types (`Tokenizer`, `RSVPReader`, models) while SwiftUI views consume an `AppModel` store for documents, settings, stats, import, and persistence.

**Tech Stack:** SwiftUI, Foundation, UniformTypeIdentifiers, UIKit haptics, XCTest, JSON file persistence with `Codable`.

---

## File Structure

- Create `FlashReader.xcodeproj/project.pbxproj`: Xcode project with iOS app and unit test targets.
- Create `FlashReader/FlashReaderApp.swift`: app entry point.
- Create `FlashReader/Models.swift`: `ReadingToken`, `ReadingDocument`, `ReaderSettings`, `ReadingStats`, `DailyReadingSession`, and helpers.
- Create `FlashReader/Tokenizer.swift`: pure tokenization, ORP, and smart-pause logic.
- Create `FlashReader/RSVPReader.swift`: timer-driven reader engine.
- Create `FlashReader/AppStore.swift`: JSON persistence.
- Create `FlashReader/AppModel.swift`: root state and app actions.
- Create `FlashReader/Theme.swift`: colors, gradients, reusable styling.
- Create `FlashReader/Components.swift`: shared SwiftUI controls.
- Create `FlashReader/LibraryView.swift`: dashboard, search, document list.
- Create `FlashReader/DocumentDetailView.swift`: progress, preview, actions.
- Create `FlashReader/ReaderView.swift`: immersive RSVP reader.
- Create `FlashReader/ImportView.swift`: paste and file import.
- Create `FlashReader/SettingsView.swift`: reading preferences.
- Create `FlashReader/Assets.xcassets/...`: minimal asset catalog.
- Create `FlashReaderTests/TokenizerTests.swift`: tokenizer and ORP tests.
- Create `FlashReaderTests/RSVPReaderTests.swift`: reader timing/progress tests.
- Create `FlashReaderTests/AppStoreTests.swift`: persistence defaults and round trip tests.
- Create `.gitignore`: ignore Xcode, SwiftPM, node, and build artifacts.

### Task 1: Project Shell

**Files:**
- Create: `.gitignore`
- Create: `FlashReader.xcodeproj/project.pbxproj`
- Create: `FlashReader/Assets.xcassets/Contents.json`
- Create: `FlashReader/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `FlashReader/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `FlashReader/FlashReaderApp.swift`

- [ ] **Step 1: Add Xcode project and app entry**

Create a SwiftUI iOS app target named `FlashReader` and a unit test target named `FlashReaderTests`. The app entry initializes `AppModel` and presents `LibraryView`.

- [ ] **Step 2: Verify project files exist**

Run: `Test-Path 'FlashReader.xcodeproj\project.pbxproj'; Test-Path 'FlashReader\FlashReaderApp.swift'`

Expected: both commands print `True`.

### Task 2: Core Models And Tokenizer

**Files:**
- Create: `FlashReader/Models.swift`
- Create: `FlashReader/Tokenizer.swift`
- Create: `FlashReaderTests/TokenizerTests.swift`

- [ ] **Step 1: Write tokenizer tests**

Cover token splitting, punctuation stripping, ORP calculation, and timing multipliers.

- [ ] **Step 2: Implement models and tokenizer**

Define `Codable`, `Identifiable`, and `Equatable` value models. Port the web prototype ORP and multiplier rules exactly.

- [ ] **Step 3: Verify source is searchable**

Run: `Select-String -LiteralPath 'FlashReader\Tokenizer.swift' -Pattern 'sentenceEndMultiplier|optimalRecognitionPoint|tokenize'`

Expected: all three symbols are found.

### Task 3: Reader Engine

**Files:**
- Create: `FlashReader/RSVPReader.swift`
- Create: `FlashReaderTests/RSVPReaderTests.swift`

- [ ] **Step 1: Write reader tests**

Cover chunk creation, delay calculation, seek clamping, and progress advancement.

- [ ] **Step 2: Implement `RSVPReader`**

Use a `@MainActor ObservableObject` with `play`, `pause`, `seek`, `setWPM`, and `setChunkSize`.

- [ ] **Step 3: Verify engine symbols**

Run: `Select-String -LiteralPath 'FlashReader\RSVPReader.swift' -Pattern 'func play|func pause|func seek|delayForChunk'`

Expected: all core methods are found.

### Task 4: Persistence And App Model

**Files:**
- Create: `FlashReader/AppStore.swift`
- Create: `FlashReader/AppModel.swift`
- Create: `FlashReaderTests/AppStoreTests.swift`

- [ ] **Step 1: Write persistence tests**

Cover default state and JSON round trip in a temporary folder.

- [ ] **Step 2: Implement store**

Persist documents, settings, and stats as `Codable` JSON. Use dependency injection for the storage directory.

- [ ] **Step 3: Implement app model**

Seed onboarding content, add pasted/file documents, update progress, accumulate sessions, reset, delete, and update settings.

- [ ] **Step 4: Verify model actions**

Run: `Select-String -LiteralPath 'FlashReader\AppModel.swift' -Pattern 'addDocument|updateProgress|accumulateSession|seedIfNeeded'`

Expected: all actions are found.

### Task 5: SwiftUI Interface

**Files:**
- Create: `FlashReader/Theme.swift`
- Create: `FlashReader/Components.swift`
- Create: `FlashReader/LibraryView.swift`
- Create: `FlashReader/DocumentDetailView.swift`
- Create: `FlashReader/ReaderView.swift`
- Create: `FlashReader/ImportView.swift`
- Create: `FlashReader/SettingsView.swift`

- [ ] **Step 1: Implement visual system**

Add warm dark colors, accent red, cards, icon controls, progress rings, and compact reusable components.

- [ ] **Step 2: Implement Library**

Show continue-reading hero, stats, daily goal, search, import/settings toolbar buttons, and document rows.

- [ ] **Step 3: Implement Detail**

Show title, progress, ETA, preview with active word, reset/delete, and start-reading action.

- [ ] **Step 4: Implement Reader**

Show ORP word display, guide rails, WPM controls, scrubber, hold-to-read, tap play/pause, context, and haptics.

- [ ] **Step 5: Implement Import and Settings**

Support paste, `.txt`, `.md`, settings controls, and validation messages.

- [ ] **Step 6: Verify view symbols**

Run: `Select-String -LiteralPath 'FlashReader\*.swift' -Pattern 'LibraryView|ReaderView|ImportView|SettingsView|DocumentDetailView'`

Expected: all view names are found.

### Task 6: Git And Verification

**Files:**
- Modify: repository metadata only.

- [ ] **Step 1: Initialize git if missing**

Run: `if (!(Test-Path '.git')) { git init }`

Expected: git initializes or reports the existing repository.

- [ ] **Step 2: Inspect status**

Run: `git status --short`

Expected: created iOS project files, docs, and existing web prototype files are visible.

- [ ] **Step 3: Run available local verification**

Run: `npm run build`

Expected: existing web prototype still builds. Native iOS compilation requires Xcode and cannot be run on this Windows machine.

- [ ] **Step 4: Commit local work**

Run: `git add .; git commit -m "feat: add native Flash Reader iOS app"`

Expected: commit succeeds after local verification.

- [ ] **Step 5: Push private GitHub repo if tooling exists**

If `gh` is authenticated, run `gh repo create flash-reader --private --source . --remote origin --push`. If `gh` is unavailable, report that local commit is ready and pushing requires GitHub auth/tooling.
