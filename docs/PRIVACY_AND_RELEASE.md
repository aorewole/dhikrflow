# Dhikr Counter — Privacy & Release Specification

## 1. Privacy promise

Suggested product wording:

> **Your recitation stays on your device.**
> The app processes speech locally for counting and does not upload or store your recitation audio.

This copy must only be used if implementation and dependency review confirm it is true.

## 2. Permission policy

Request microphone permission only when the user initiates voice counting or explicitly enables an audio-dependent feature.

Do not request unrelated permissions.

Background microphone behavior must be explicit and visible.

## 3. Network policy

The core feature should work with the device fully offline.

Test conditions:

- Airplane Mode enabled.
- Wi-Fi disabled.
- Mobile data disabled.

The app should still:

- open
- show dhikr library
- start a selected-dhikr session
- process voice locally
- count repetitions
- save the session
- show history

## 4. Audio policy

Raw user audio should exist only as short-lived in-memory data required for the recognition pipeline.

Do not:

- save WAV files
- save MP3/AAC clips
- cache recordings
- silently upload clips
- include sample recordings from users in diagnostics

Development/test recordings must come from permissioned test datasets and must not become ordinary user data.

## 5. Data inventory

The app may store locally:

- dhikr definitions
- favorites
- settings
- target preferences
- session counts/timestamps/durations
- non-audio recognition diagnostics if useful
- optional future recognition profiles

The app should not store:

- raw recitation audio
- remote user profiles
- advertising identifiers
- unnecessary device identifiers

## 6. Third-party review

Every package must be reviewed for:

- license
- network behavior
- tracking
- data collection
- platform permissions
- maintenance status

The local ASR engine/model requires separate review of software license and model/weight license.

## 7. Release gates

Do not release until:

- privacy documentation matches real behavior
- dependency audit is complete
- model license is compatible with distribution
- Android/iOS permissions are minimal and correctly explained
- no unexpected network requests are identified during core offline tests
- raw audio persistence audit passes
- recognition/counting tests are documented
