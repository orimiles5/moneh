# Kickoff: Taxi meter app (Israel-first)

You are the lead engineer on a new product: a taxi meter that runs on the driver's phone and shows the fare on the car's screen. Build it to production standard from the first commit. Read this whole brief before doing anything, then follow "How to start" at the bottom.

## Product

A driver mounts or connects their phone, taps start, and the meter runs: starting fee, distance charge, time charge at low speed, tariff by time of day, extras. The passenger must be able to see the running fare at all times, ideally on the car's built-in screen, so the driver's phone stays free for navigation and dispatch apps.

Working name: `Moneh` (Hebrew for "meter"). Keep the name in one place so it's trivial to change.

Israel is the first market. Hebrew is the default language and the UI is RTL-first. Everything must be generic enough that adding a country (new tariffs, currency, language, regulations) is configuration and translation work, not a rewrite.

### What "the car's screen" means in practice

These platform limits are real and shape the architecture. Verify them against current Apple and Google documentation before building, since they change yearly.

- **iOS / CarPlay.** Full CarPlay apps require a category entitlement from Apple. The closest fit is the Driving Task category, and approval isn't guaranteed. But since iOS 26, Live Activities appear on the CarPlay Dashboard with no extra entitlement. So:
  - Primary path: a Live Activity showing the running fare, tariff and trip time. It also covers the Lock Screen and Dynamic Island for free.
  - Secondary path: a CarPlay Driving Task scene (`CPTemplateApplicationSceneDelegate`, information/grid templates), built and tested in the CarPlay Simulator, behind a build flag until Apple grants the entitlement. Prepare the entitlement request text in `docs/`.
- **Android / Android Auto.** The Android for Cars App Library only allows specific categories (navigation, POI, IoT, weather, messaging, media and a few more). None fits a meter. Do not try to sneak around the review. Instead:
  - Full-screen "meter mode" on the driver's phone, with an ongoing notification.
  - Keep the car-screen layer behind an interface so Android Auto can be added if a category opens up.
- **Passenger display (both platforms, later milestone).** A second cheap device (old phone or tablet) mounted for the passenger, paired to the driver's phone over a local link (Multipeer Connectivity / Nearby Connections, or BLE), showing a read-only fare. This works in any car, with or without CarPlay/Android Auto.

## Architecture

- **Monorepo.** `core/` (shared), `ios/`, `android/`, `docs/`.
- **Shared core in Kotlin Multiplatform**, consumed by iOS as an XCFramework/SPM package and by Android directly. The core owns everything that must behave identically on both platforms:
  - Fare engine: a pure, deterministic function of (tariff, trip events) → fare breakdown. No clocks, no I/O inside.
  - Tariff model: tariffs are versioned data (JSON), not code. Starting fee, distance and time increments, crossover speed, time-of-day/day-of-week/holiday rules, extras, rounding. Each trip records the tariff version it used.
  - Trip state machine: idle → hired → paused/waiting → stopped → settled. Illegal transitions are impossible by construction.
  - Distance pipeline: GPS samples filtered (accuracy gating, outlier rejection, smoothing), with an interface for an optional OBD-II speed source and dead reckoning across short GPS gaps (tunnels).
  - Trip log: append-only and tamper-evident (hash chain over events). We want the app to be certifiable by a regulator later, so auditability is a design requirement now, not an add-on.
- **Money is integers in minor units** (agorot). Never floating point for money. Rounding rules come from the tariff.
- **Native UI:** SwiftUI on iOS, Jetpack Compose on Android. Platform services (location, background execution, Live Activities, foreground service, notifications, persistence) live in the platform layers behind small interfaces the core defines.
- **Background operation is critical.** iOS: background location with the modern `CLLocationUpdate`/`CLBackgroundActivitySession` APIs; Live Activity updated locally. Android: a foreground service of type `location`. The meter must survive the screen locking, app switching and the driver opening Waze.
- **Local-first.** No backend in v1. Trips, tariffs and settings persist on device. Receipts can be shared (PDF/image). Design data models so a sync backend can be added later without migrations hell.
- **Minimum OS:** pick and justify sensible minimums (CarPlay Live Activities need iOS 26 on the phone; don't lock out older phones from the core meter).

## Israel specifics

- Research the current official taxi tariffs from the Israeli Ministry of Transport (gov.il) and encode them as a tariff file with a source URL and effective date. If anything is ambiguous (tariff boundaries, holidays, extras like luggage or airport), list it in `docs/open-questions.md` and ask me. **Never invent tariff values.**
- Holidays: Jewish holidays affect tariffs. Use a proper Hebrew-calendar source or library; don't hardcode dates.
- This app is not a certified meter. Until it is, the UI must not claim to be an official meter. Put a short, honest notice in onboarding and settings, worded carefully in Hebrew. Note in `docs/regulatory.md` what certification would require.

## Design

The bar is [memoriez.app](https://memoriez.app). I reviewed it; here's what makes it good and what to carry over:

- **Warm, calm canvas.** Off-white/cream background (around `#f6f2ec`), near-black warm ink, not pure black on pure white. One accent at a time.
- **Bold, confident Hebrew typography.** A heavy display face for the one thing that matters on the screen, a clean sans for everything else. Pick a Hebrew-capable family with an open license (evaluate options like Rubik, Heebo or similar, check the license) and bundle it. The fare uses tabular, monospaced digits so it never jitters.
- **One question or one number per screen.** Memoriez opens with a single question and a single input. Our main screen is one huge fare, with tariff and trip time secondary. Onboarding asks one thing at a time.
- **The UI reacts to input instantly and with delight.** On memoriez, typing a destination recolors and re-illustrates the book cover live. For us: digits roll smoothly when the fare increments, the tariff chip transitions when the tariff changes, starting a trip has a satisfying physical moment (spring animation + haptic).
- **Tactile, skeuomorphic touches used sparingly.** Memoriez's book opens with a 3D page turn and casts a soft shadow. One or two moments like that (e.g., the receipt sliding out at the end of a trip), no more.
- **Perfect RTL.** Switching to English on memoriez mirrors the entire layout, including the direction of the page turn and arrows. Ours must do the same: use leading/trailing everywhere, mirror directional icons, and handle bidi correctly for mixed Hebrew text and numbers (fare amounts, plate numbers, times).
- **Pill buttons, generous spacing, soft shadows, rounded cards.** Nothing busy.

Car-specific requirements on top of that:
- Night mode matters more than day mode: drivers work at night. Dark theme follows system and can be forced on. Avoid bright glare at night.
- Huge touch targets, glanceable at arm's length, readable by a passenger in the back seat.
- Respect Dynamic Type/font scale, VoiceOver/TalkBack, Reduce Motion, and sufficient contrast.

Set up a small design system first (color tokens with light/dark values, type scale, spacing, radii, motion curves) on both platforms, and build every screen from it.

## Engineering standards

- Clean, idiomatic Swift and Kotlin. Small focused types, clear names, no speculative abstractions, no frameworks we don't need. If a simple solution works, use it.
- Comments only where the *why* isn't obvious. No narrating comments, no commented-out code, no boilerplate doc blocks.
- Strict concurrency on iOS (Swift 6 language mode), structured concurrency/coroutines on Android, no force unwraps or `!!` outside tests.
- Linting/formatting: SwiftLint + SwiftFormat, ktlint/detekt. Enforced in CI.
- Localization: String Catalogs on iOS, string resources on Android. No user-facing string literals in code. Locale-aware number, currency and date formatting. Hebrew + English from day one so the i18n path is proven.
- Tests:
  - Fare engine: table-driven tests against hand-computed fares from the official tariffs, plus property tests (fare never decreases during a trip, time and distance never both charged for the same interval, etc.).
  - Distance pipeline: replay tests from recorded GPS traces (add realistic fixtures: urban canyon, tunnel, standing at lights, highway).
  - UI: snapshot tests for key screens in Hebrew and English, light and dark.
- Privacy: location is the most sensitive data we hold. Collect the minimum, keep it on device, write clear permission prompts. No analytics SDKs without asking me.
- Secrets and signing material never enter the repo.

## Git and GitHub workflow

Use the `gh` CLI for everything GitHub.

- Check `gh auth status` first. Create a **private** repository (ask me for the owner/org and name if not obvious) and push the initial skeleton to `main`.
- Protect `main`: no direct pushes, PRs required, CI must pass.
- Work in short-lived branches named `feat/…`, `fix/…`, `chore/…`, `docs/…`. Conventional Commits.
- One coherent change per PR, kept reviewable. PR description: what and why, how it was tested, screenshots for UI changes (Hebrew and English, light and dark).
- GitHub Actions CI: build and test `core`, iOS (macOS runner) and Android on every PR. Cache dependencies. Add Dependabot for Gradle, SPM and Actions.
- Track milestones and tasks as GitHub issues and link PRs to them.
- Merging: squash-merge your own PRs once CI is green and you've reviewed the diff yourself, **except** PRs that change fare calculation, tariffs, the trip log or permissions. Leave those open and ask me to review.

Create a `CLAUDE.md` at the repo root capturing these conventions, the architecture and commands, so future sessions stay consistent. Keep it short and current.

## Milestones

1. **Foundation.** Repo, CI, lint, design tokens, empty app shells on both platforms that build, `CLAUDE.md`, `docs/`.
2. **Core.** Tariff model, Israeli tariff file, fare engine, trip state machine, trip log, with full tests.
3. **iOS meter.** Location pipeline, background operation, main meter screen, trip summary and receipt, onboarding with permissions, Hebrew + English.
4. **iOS car screen.** Live Activity (verify it on the CarPlay Dashboard in the CarPlay Simulator), then the Driving Task CarPlay scene behind a flag, plus the entitlement request text.
5. **Android meter.** Parity with milestone 3, foreground service, ongoing notification.
6. **Passenger display.** Pairing and read-only fare on a second device.
7. **OBD-II.** Optional BLE OBD-II speed source fused with GPS.

## How to start

1. Don't write code yet. Read this brief, verify the platform constraints above against current docs, and research the current Israeli tariffs.
2. Come back with: a short architecture overview, the repo layout, your proposed minimum OS versions and font choice, the milestone 1 and 2 plan broken into PR-sized tasks, and a list of questions for me (repo owner/name, bundle ID, Apple team, anything ambiguous).
3. After I answer, create the repo and issues, and start milestone 1.
