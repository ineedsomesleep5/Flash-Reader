# Flash Reader iOS Design

## Goal

Flash Reader is a native iOS app for faster reading with RSVP, Rapid Serial Visual Presentation. It should feel polished, focused, and modern while preserving the strongest behavior from the existing web prototype: one-word-at-a-time reading, Optimal Recognition Point highlighting, smart timing pauses, progress tracking, imports, and local persistence.

The rewrite should be a real SwiftUI app, not a web wrapper. The current Vite app remains source material for product behavior and edge cases.

## Product Shape

The app has four primary areas:

1. Library
2. Reader
3. Import
4. Settings

The Library is the home screen. It shows a continue-reading hero, reading stats, daily goal progress, and a searchable list of documents. The Reader is an immersive focus mode with the flashed word at a stable focal point. Import handles paste and files. Settings controls reading behavior and app preferences.

## Visual Direction

Flash Reader should use a warm, cinematic dark interface with high contrast, restrained accent color, and native iOS motion. The app should avoid looking like a generic productivity template. The focal reading screen can be almost black, with the ORP character in a strong red accent and subtle guide rails. Library and settings can use layered dark surfaces, clear typography, progress rings, and compact controls.

The app name is `Flash Reader`.

## Core Features

### Library

- Show a prominent continue-reading card when at least one document has progress.
- Show total words read, reading time, document count, and daily goal progress.
- List saved documents with title, word count, percent complete, estimated time left, and last-read order.
- Support search/filter by title.
- Allow delete and reset progress from document detail.

### Reader

- Show one token at a time with ORP highlighting for single-word mode.
- Support chunk sizes of 1, 2, and 3 words. Multi-word chunks are centered without ORP highlighting.
- Support smart pauses for sentence endings, clause endings, and long words.
- Provide WPM controls from the reader screen.
- Provide hold-to-read and tap play/pause modes.
- Include a progress scrubber and word count position.
- Include optional sentence context.
- Add optional haptics for start, pause, and session completion.

### Import

- Paste text with an optional title.
- Import `.txt` and `.md` through the iOS file picker in the first pass.
- Import `.pdf` and `.epub` if local dependencies are practical during implementation; otherwise structure the importer so these can be added cleanly.
- Seed the app with a short onboarding document explaining RSVP and ORP.

### Settings

- Default WPM.
- Font scale.
- Smart pauses toggle.
- Chunk size.
- Sentence context toggle.
- Haptics toggle.
- Daily word goal.

## Data Model

Use native Swift models:

- `ReadingDocument`: id, title, original text, tokens, progress index, added date, last-read date.
- `ReadingToken`: raw text, stripped text, ORP index, timing multiplier.
- `ReaderSettings`: WPM, font scale, smart pauses, chunk size, context visibility, haptics, daily goal.
- `ReadingStats`: total words read, total reading minutes, daily sessions.

Persistence can use SwiftData if the created project target supports it cleanly. If not, use local JSON files with `Codable` models. The design should keep persistence behind a small store type so the app can switch storage later without rewriting views.

## Architecture

Use SwiftUI with small focused views and simple state ownership:

- `FlashReaderApp`: app entry and store ownership.
- `AppModel` or store: root-owned app state, documents, settings, stats.
- `Tokenizer`: pure Swift tokenization and ORP logic.
- `RSVPReader`: timing engine with play, pause, seek, WPM update, and chunk-size update.
- `LibraryView`: dashboard and document list.
- `DocumentDetailView`: progress summary, preview, and document actions.
- `ReaderView`: immersive RSVP experience.
- `ImportView`: paste and file import.
- `SettingsView`: user preferences.

The tokenizer and reader engine should be independent from SwiftUI so they can be unit tested.

## Behavior Ported From Prototype

ORP calculation:

- Length 1: index 0
- Length 2 to 5: index 1
- Length 6 to 9: index 2
- Length 10 and up: index 3

Smart pause multipliers:

- Sentence end: 2.5x
- Clause end: 1.5x
- Long word over 12 characters: 1.4x
- Medium word over 8 characters: 1.2x

Delay formula:

`delay = (60 / WPM) * multiplier`

For chunk mode, use the highest multiplier in the current chunk.

## Error Handling

- Empty paste attempts should show a friendly validation message.
- Unsupported file types should show a clear error.
- Failed file reads should preserve the current library and explain that the import failed.
- Reader progress should persist when leaving the reader, pausing, or scrubbing.

## Testing

Add focused tests for:

- Token splitting.
- Punctuation stripping.
- ORP calculation.
- Smart pause multipliers.
- Reader play/pause/seek progress.
- Chunk timing multiplier selection.
- Settings persistence defaults.

## Implementation Notes

The first implementation should prioritize a complete, polished native loop:

1. Create the SwiftUI project.
2. Port tokenization and RSVP engine.
3. Build local persistence.
4. Build Library, Detail, Reader, Import, and Settings.
5. Add native polish: haptics, clean empty states, responsive layout, and accessibility labels.
6. Add unit tests for core logic.

Wikipedia, Gutenberg, PDF, and EPUB support can follow after the native MVP is stable if they risk slowing the first iOS build.
