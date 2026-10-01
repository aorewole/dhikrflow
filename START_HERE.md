# Dhikr Counter — Antigravity Starter Pack

## What this folder is

This folder is the project brief and persistent instructions for building **Dhikr Counter**, a free, privacy-first, offline hands-free dhikr counter.

The intended first implementation is a Flutter application targeting Android and iOS from one shared codebase. The core experience is:

> **Select a dhikr → Start → Recite naturally → the app counts each repetition locally.**

The microphone stream is processed on-device. Raw audio is not stored. The core feature must work without Internet access.

This repository is deliberately designed so Google Antigravity can treat the files as project context, not as a one-off chat prompt.

---

## 1. Do this first

### A. Create/open a local project folder

Use Google Antigravity 2.0 and create a Project for this folder. Antigravity Projects define the folders/repositories agents can access. The official setup flow is: create a Project, add the local folder, then start an agent in that Project.

This starter pack already contains an `AGENTS.md` file. Antigravity automatically discovers `AGENTS.md` files in the project and uses them as persistent instructions.

### B. Put this folder at the project root

The workspace should look like:

```text
DhikrCounter/
├── AGENTS.md
├── START_HERE.md
└── docs/
    ├── MASTER_SPEC.md
    ├── RECOGNITION_SPEC.md
    ├── BUILD_ROADMAP.md
    ├── PRIVACY_AND_RELEASE.md
    └── MODEL_EVALUATION.md
```

You can rename the root folder to `DhikrCounter`.

### C. Do not manually design or write the Flutter app first

Let Antigravity inspect the development environment and create the Flutter project. The agent should verify the installed Flutter/Dart toolchain and target-platform tooling before choosing versions or dependencies.

---

## 2. Your first Antigravity prompt

Open an Agent conversation inside the project and paste this:

```text
Read the project instructions and specification files before changing code.

Source of truth:
- AGENTS.md
- docs/MASTER_SPEC.md
- docs/RECOGNITION_SPEC.md
- docs/BUILD_ROADMAP.md
- docs/PRIVACY_AND_RELEASE.md
- docs/MODEL_EVALUATION.md

Do not ask broad clarification questions. The product decisions are already approved in these files.

Start the project now.

First:
1. Inspect the local development environment and verify Flutter, Dart, Android tooling, Xcode/iOS tooling where available, Git, and relevant build tools.
2. Create a concise environment report in docs/ENVIRONMENT_REPORT.md.
3. Identify the best current Flutter architecture and local/offline recognition approach available in the environment. Treat sherpa-onnx as a candidate, not as an automatic commitment.
4. Research/verify current package and model compatibility, licensing, model size, performance implications, and platform constraints. Do not use cloud speech recognition.
5. Produce/update the implementation plan as a concrete sequence of tasks.
6. Create the Flutter project scaffold and implement Phase 1 from docs/BUILD_ROADMAP.md.
7. Use fake/mock recognition events for the UI until the local recognition engine is ready.
8. Add unit tests for the recognition-domain abstractions and session/counting logic where possible.
9. Run formatting, static analysis, and tests.
10. Review the result for privacy violations, unnecessary permissions, and architecture mistakes.

Do not build the entire application in one pass.
Do not add analytics, telemetry, Firebase, authentication, cloud APIs, advertising SDKs, or raw audio persistence.
Do not download or bundle a speech model until its license, redistribution terms, size, and suitability have been documented.

At the end, report:
- what was created
- what was verified
- what is still blocked
- exact next task to continue the build
```

### Important

When Antigravity presents an implementation plan, review it before allowing a large batch of changes. The plan should follow the documents in this folder and should not quietly change the privacy model or recognition strategy.

---

## 3. After Phase 1

Do not immediately tell Antigravity to “finish the whole app.” Continue phase-by-phase.

Use the prompts in `docs/BUILD_ROADMAP.md`.

The most important milestone is **Recognition Proof of Concept**:

```text
Target: Astaghfirullah

User says:
Astaghfirullah
→ 1

Astaghfirullah Astaghfirullah
→ 3 total

Four rapid repetitions
→ +4

Unrelated speech
→ +0
```

Then run the same test with the device disconnected from the Internet.

---

## 4. Product rule that must not be lost

Do not build a general-purpose voice assistant.

The app's job is not “transcribe everything the user says.”

The app's job is:

> **Detect repeated utterances of a selected short dhikr and convert accepted detections into count events.**

That distinction should drive the recognition architecture, battery strategy, privacy design, and UI.

---

## 5. Release philosophy

The app should feel like a calm digital tasbih, not an AI demo.

Core principles:

1. **Private** — no cloud processing, no account, no tracking, no raw-audio storage.
2. **Local** — recognition runs on-device.
3. **Light** — use the smallest model that performs adequately on practical devices.
4. **Natural** — users may recite at normal or fast speed.
5. **Simple** — select, start, recite.

---

## Official references checked for this starter pack

- Google Antigravity getting started: https://www.antigravity.google/docs
- Antigravity Rules: https://www.antigravity.google/docs/rules/
- Flutter multi-platform: https://docs.flutter.dev/platform-integration
- Flutter create-new-app guidance: https://docs.flutter.dev/reference/create-new-app
- Flutter install/setup: https://docs.flutter.dev/install
- sherpa-onnx documentation: https://k2-fsa.github.io/sherpa/onnx/

Model pages and package versions are intentionally not hard-coded as permanent truth. The agent should verify them at build time because model availability, licenses, and package compatibility can change.
