# Flash Reader

Flash Reader is a native SwiftUI iOS app for RSVP speed reading. It shows text one chunk at a time, highlights the Optimal Recognition Point in single-word mode, applies smart pauses for punctuation and long words, and tracks reading progress locally.

This repository also keeps the original Vite web prototype as behavioral reference material.

## Native iOS App

Open `FlashReader.xcodeproj` in Xcode and run the `FlashReader` scheme on an iPhone simulator or device.

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

The iOS project was generated on a Windows host without Xcode, so native compilation must be verified on macOS with Xcode installed. The existing web prototype build has been verified with `npm run build`.
