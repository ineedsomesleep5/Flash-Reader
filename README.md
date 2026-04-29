# Flash Reader

Flash Reader is a native SwiftUI iOS app for RSVP speed reading. It shows text one chunk at a time, highlights the Optimal Recognition Point in single-word mode, applies smart pauses for punctuation and long words, and tracks reading progress locally.

This repository also keeps the original Vite web prototype as behavioral reference material.

## Native iOS App

Clone the repo on a Mac with Xcode installed:

```bash
git clone https://github.com/ineedsomesleep5/Flash-Reader.git
cd Flash-Reader
open FlashReader.xcodeproj
```

Then select the shared `FlashReader` scheme, choose an iPhone simulator, and press Run.

Project settings:

- Product name: `Flash Reader`
- Scheme: `FlashReader`
- Bundle ID: `com.flashreader.app`
- Minimum iOS target: iOS 17.0
- Dependencies: none for the native app

If Xcode asks for signing when running on a real iPhone, choose your Apple Developer team in the `FlashReader` target's Signing & Capabilities tab. Simulator runs should not require a team.

Included native features:

- SwiftUI Library dashboard with reading stats, daily goal, streak, search, and continue-reading card.
- Immersive RSVP Reader with ORP highlighting, guide rails, WPM control, scrubber, tap play/pause, hold-to-read, sentence context, and haptics.
- Paste import and `.txt` / `.md` file import.
- Local JSON persistence for documents, settings, and stats.
- Unit tests for tokenization, timing, reader chunk behavior, and persistence.

## Web Prototype

The original prototype still runs with Vite:

```bash
npm install
npm run dev
npm run build
```

## Verification Note

The iOS project was generated on a Windows host without Xcode, so native compilation must be verified on macOS with Xcode installed. The repo includes a shared Xcode scheme and workspace metadata so Xcode should pick it up directly after clone. The existing web prototype build has been verified with `npm run build`.
