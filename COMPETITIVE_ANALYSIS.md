# EchoText Competitive Analysis & Feature Roadmap

_Last Updated: January 2026_

## Market Overview

### Main Competitor: MacWhisper (€64 Pro)

The current market leader for Whisper-based transcription on macOS.

### Other Competitors

| App                      | Price            | Notes                           |
| ------------------------ | ---------------- | ------------------------------- |
| Whisper Notes            | $4.99            | Minimalist, "do one thing well" |
| Voibe                    | $99 lifetime     | Zero-setup, hold Fn to speak    |
| VoiceInk                 | Free/Open Source | Community-driven                |
| Built-in macOS Dictation | Free             | Apple Intelligence powered      |

---

## Feature Comparison Matrix

| Feature                        | MacWhisper | EchoText (Current) | Priority |
| ------------------------------ | ---------- | ------------------ | -------- |
| On-device transcription        | ✅         | ✅                 | -        |
| Multiple Whisper models        | ✅         | ✅                 | -        |
| System-wide dictation          | ✅         | ✅                 | -        |
| Global hotkey                  | ✅         | ✅                 | -        |
| Auto-insert text               | ✅         | ✅                 | -        |
| Menu bar integration           | ✅         | ✅                 | -        |
| File transcription             | ✅         | ✅                 | -        |
| 100+ languages                 | ✅         | ✅                 | -        |
| Export (TXT, SRT, VTT, MD)     | ✅         | ✅                 | -        |
| Focus Mode                     | ❌         | ✅                 | -        |
| **Speaker Diarization**        | ✅         | ❌                 | HIGH     |
| **Transcript History/Library** | ✅         | ❌                 | HIGH     |
| **Full-text Search**           | ✅         | ❌                 | HIGH     |
| **System Audio Recording**     | ✅         | ✅                 | -        |
| **Playback Sync**              | ✅         | ❌                 | HIGH     |
| **Batch Transcription**        | ✅         | ❌                 | MEDIUM   |
| **YouTube URL Transcription**  | ✅         | ❌                 | MEDIUM   |
| **Watch Folder Automation**    | ✅         | ❌                 | MEDIUM   |
| **PDF/DOCX Export**            | ✅         | ❌                 | MEDIUM   |
| **AI Post-Processing**         | ✅         | ❌                 | MEDIUM   |
| **Real-time Captions**         | ✅         | ❌                 | LOW      |
| **Translation (DeepL)**        | ✅         | ❌                 | LOW      |
| **Webhooks/Zapier**            | ✅         | ❌                 | LOW      |
| **iPhone/iPad Companion**      | ✅         | ❌                 | LOW      |
| **Parakeet v2 Support**        | ✅         | ❌                 | LOW      |

---

## Feature Roadmap

### Phase 1: Core Differentiators (Must-Have)

#### 1. Transcript History & Library

- [*] Create `TranscriptionHistory` Core Data model
- [*] Add "History" tab in main window
- [*] Store all transcriptions with metadata (date, duration, model, source file)
- [*] Display transcriptions in chronological list with preview
- [*] Delete/archive individual transcriptions
- [*] Import/export history

#### 2. Full-text Search

- [*] Implement search across all saved transcripts
- [*] Search by content, date range, source file name
- [*] Highlight search matches in results
- [*] Quick filter/sort options

#### 3. Speaker Diarization

- [*] Integrate speaker detection (pyannote.audio or similar)
- [*] Auto-label speakers (Speaker 1, Speaker 2, etc.)
- [*] Allow manual speaker name assignment
- [*] Color-code speakers in transcript view
- [*] Export with speaker labels

#### 4. System Audio Recording (Meeting Transcription)

- [x] Create virtual audio device or use ScreenCaptureKit
- [x] Record system audio from Zoom, Teams, Meet, Discord
- [x] Audio source selector in UI
- [x] Indicator showing active audio capture
- [x] Auto-detect meeting apps

#### 5. Playback Sync

- [ ] Embed audio player in file transcription view
- [ ] Click segment to seek to timestamp
- [ ] Highlight current segment during playback
- [ ] Playback speed control (0.5x - 2x)
- [ ] Keyboard shortcuts (J/K/L for playback control)

---

### Phase 2: Value Multipliers

#### 6. Batch File Processing

- [ ] Multi-file drag & drop support
- [ ] Transcription queue with progress for each file
- [ ] Parallel processing option (if memory allows)
- [ ] Queue management (pause, cancel, reorder)
- [ ] Batch export all results

#### 7. YouTube/URL Transcription

- [ ] URL input field in File Transcription tab
- [ ] Integrate yt-dlp for YouTube downloads
- [ ] Support for other video platforms (Vimeo, etc.)
- [ ] Download progress indicator
- [ ] Auto-cleanup of temp files

#### 8. Additional Export Formats

- [ ] PDF export with formatting
- [ ] DOCX export (using Swift DocX library)
- [ ] CSV export (timestamp, speaker, text columns)
- [ ] HTML export with styling
- [ ] JSON export for programmatic use
- [ ] Copy options: with timestamps vs. clean text

#### 9. Watch Folder Automation

- [ ] Configure watched folder in settings
- [ ] Monitor for new audio/video files
- [ ] Auto-transcribe and save to output folder
- [ ] Notification on completion
- [ ] File naming patterns

---

### Phase 3: Pro Features (Upsell)

#### 10. AI Post-Processing

- [ ] Summarize transcription
- [ ] Extract action items and key points
- [ ] Reformat as meeting notes
- [ ] Generate title/description
- [ ] Local Ollama integration (privacy-first)
- [ ] Optional: OpenAI/Claude API support

#### 11. Translation

- [ ] Transcribe in source language
- [ ] Translate to target language
- [ ] Side-by-side view (original + translated)
- [ ] DeepL API integration (or local model)
- [ ] Multi-language subtitle export

#### 12. Real-time Captions/Subtitles

- [ ] Floating caption overlay window
- [ ] Customizable appearance (font, size, position)
- [ ] OBS integration for streaming
- [ ] Always-on-top option

#### 13. Custom Vocabulary/Hotwords

- [ ] Add domain-specific terms
- [ ] Company/product names
- [ ] Technical jargon and acronyms
- [ ] Per-project vocabulary lists

---

## Pricing Strategy

### Recommended Pricing (Beat MacWhisper on Value)

| Tier       | Price              | Features                                                                                                |
| ---------- | ------------------ | ------------------------------------------------------------------------------------------------------- |
| **Free**   | $0                 | Basic dictation, tiny/base models, single file transcription, basic export                              |
| **Pro**    | **$29** (one-time) | All models, transcript history & search, all export formats, batch processing, speaker diarization      |
| **Studio** | **$49** (one-time) | Pro + system audio recording, YouTube transcription, AI summarization, watch folders, custom vocabulary |

### Competitive Advantage

- MacWhisper Pro: €64 (~$70)
- **EchoText Studio: $49** (30% cheaper with comparable features)
- **EchoText Pro: $29** (57% cheaper than MacWhisper Pro)

### Additional Revenue Options

- Student/Education discount: 25% off
- Volume licensing for teams
- Optional cloud sync subscription ($2/month)

---

## Implementation Priority

### Quick Wins (Start Here)

1. **Transcript History** - Biggest missing feature, high impact
2. **Search** - Pairs with history, essential for power users
3. **PDF/DOCX Export** - Low effort, high perceived value
4. **Batch Processing** - Common request, moderate effort

### Medium Term

5. **Speaker Diarization** - Key differentiator for meetings
6. **System Audio Recording** - Unlocks meeting transcription market
7. **Playback Sync** - Expected by file transcription users
8. **YouTube Transcription** - Viral potential, content creators love this

### Longer Term

9. **AI Post-Processing** - Emerging expectation, adds "magic"
10. **Watch Folders** - Power user feature, podcast workflows
11. **Real-time Captions** - Niche but valuable
12. **Translation** - International market expansion

---

## Technical Notes

### Dependencies to Consider

- **Speaker Diarization**: pyannote.audio (Python) or speechbrain
- **YouTube Download**: yt-dlp (bundled or system)
- **PDF Export**: PDFKit or TPPDF
- **DOCX Export**: DocX Swift library
- **System Audio**: ScreenCaptureKit (macOS 13+) or BlackHole virtual device
- **AI Integration**: Ollama (local), OpenAI API, Anthropic API

### Database for History

- Core Data with SQLite backend
- Or: GRDB.swift for pure SQLite
- Schema: transcriptions, segments, speakers, settings

---

## References

- [MacWhisper Official](https://goodsnooze.gumroad.com/l/macwhisper)
- [Best Transcription Software for Mac 2026](https://www.meetjamie.ai/blog/transcription-software-for-mac)
- [Superwhisper Alternatives](https://www.getvoibe.com/blog/superwhisper-alternatives/)
- [Whisper Notes](https://whispernotes.app/mac-whisper)
