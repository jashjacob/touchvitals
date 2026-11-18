<p align="center"><b>TouchVitals</b></p>
<p align="center">A persistent Touch Bar system monitor — network speed and disk usage, always on the Control Strip, no matter what app is frontmost</p>

<p align="center">
  <a href="https://github.com/jashjacob/touchvitals/actions/workflows/build.yml"><img src="https://github.com/jashjacob/touchvitals/actions/workflows/build.yml/badge.svg" alt="Build status"></a>
</p>

<p align="center">
  🚧 <b>Work in progress.</b> There is no release build yet — only a Phase 0 hardware spike and a Phase 1 console harness. See <a href="#status">Status</a> below for what actually works today. 🚧
</p>

---

## What this is

A MacBook Pro's physical Touch Bar loses its usefulness the moment you're not in an app that draws something onto it — switch to any app without a custom Touch Bar layout and you just get media keys. TouchVitals pins a small Control Strip icon there permanently, and expands into a compact network/disk readout on tap, using the same undocumented `DFRFoundation` + `NSTouchBarItem` system-tray mechanism that tools like [TokenBar](https://github.com/jashjacob/TokenBar) and Pock-style widget managers rely on.

It reuses the reader/sampler/scheduler design from [Vitals](https://github.com/jashjacob/vitals) (a menu-bar system monitor) rather than reinventing metrics collection, and ports the private Touch Bar presentation layer from TokenBar rather than reinventing *that*.

## Status

Built in small, independently-verifiable phases rather than as one big drop:

- [x] **Phase 0 — spike.** Confirmed `DFRElementSetControlStripPresenceForIdentifier` / `addSystemTrayItem:` still resolve on this macOS version and register a real, persistent Control Strip icon. [`Spikes/TouchBarSpike`](Spikes/TouchBarSpike)
- [x] **Phase 1 — sampling.** `NetworkSampler` + `DiskSampler` wired to one shared `Scheduler` tick, printing to console. Cross-checked against `route get default` and `df -h`. [`Apps/TouchVitals/main.swift`](Apps/TouchVitals/main.swift)
- [x] **Phase 2 — expanded bar UI.** Network arrows+rate, disk capacity bar+percent, each redraw-gated. [`ExpandedBarView`](Sources/TouchBarKit/ExpandedBarView.swift), tests under [`Tests/TouchBarKitTests`](Tests/TouchBarKitTests).
- [x] **Phase 3 — persistence.** The expanded bar re-asserts itself across app switches and Dock menus via [`TouchBarController`](Sources/AppMain/TouchBarController.swift) + [`ReassertController`](Sources/TouchBarKit/ReassertController.swift). Verified on hardware.
- [x] **Phase 4 — polish.** Tap-to-expand from the Control Strip icon, plus a mini download-rate history sparkline ([`SparklineView`](Sources/TouchBarKit/SparklineView.swift), [`RingBuffer`](Sources/MetricsCore/RingBuffer.swift)). Verified on hardware.

All five phases are built and verified on real Touch Bar hardware. Still **WIP**: no app icon, no persistent-login/launch-agent setup, no signing or notarization — see [Constraints](#constraints).

## Requirements

- A MacBook Pro with a **physical Touch Bar** — any of them: the Intel-era 13"/15"/16" models (2016–2020) or the Apple Silicon 13" M1 (2020) and M2 (2022). Touch Bar Macs were discontinued in October 2023; none of the private-API code here is architecture-specific, so Intel and Apple Silicon behave the same. There is no simulator for this hardware; everything Touch Bar-related has to be verified on real hardware by hand.
- macOS 14+
- Swift 6 toolchain (Xcode or Command Line Tools)

## Building from source

```bash
git clone https://github.com/jashjacob/touchvitals.git
cd touchvitals
swift build
swift test          # TouchBarKit's redraw-gate and formatter rules
.build/debug/TouchVitals   # Phase 1 console harness (network + disk, Ctrl+C to stop)
```

The Phase 0 hardware spike is a separate package:

```bash
cd Spikes/TouchBarSpike
swift build
.build/debug/TouchBarSpike   # installs a static "TV" Control Strip icon
```

## Project structure

```
Sources/
  SystemKit/      stateless readers (network interfaces, disk volumes) — ported from Vitals
  Diagnostics/    OSSignposter wrappers — ported from Vitals
  MetricsCore/    Scheduler, Sampler protocol, formatters — ported from Vitals
  Modules/        NetworkSampler, DiskSampler — ported from Vitals
  TouchBarKit/    NEW — pure redraw/formatting logic for the Touch Bar row (Phase 2+)
Apps/TouchVitals/ console harness (Phase 1), will become the real app entry point
Spikes/           throwaway, hardware-only proofs — not part of the shipped app
Tests/            unit tests for anything new; ported code is trusted as-is
```

## Credits

- [Vitals](https://github.com/jashjacob/vitals) — the metrics reader/sampler/scheduler design this project reuses verbatim.
- [TokenBar](https://github.com/jashjacob/TokenBar) — the private Control Strip / system-modal Touch Bar presentation mechanism this project's Phase 0–3 work is built on.

## Constraints

- Ad-hoc signed, personal use only. Not notarized, not distributed.
- No telemetry, no accounts.
- Depends on undocumented AppKit/`DFRFoundation` private APIs, guarded with `responds(to:)`/`dlsym` checks that log and no-op rather than crash if a future macOS removes them. A macOS update can break this at any time — see [`PrivateTouchBar.swift`](Spikes/TouchBarSpike/Sources/TouchBarSpike/PrivateTouchBar.swift)'s comments for exactly which symbols it depends on.
