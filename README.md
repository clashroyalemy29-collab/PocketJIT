# PocketJIT

An on-device JIT enabler for sideloaded iOS apps (emulators and similar
`get-task-allow` apps), built around the public, already-open-source
[`idevice`](https://github.com/jkcoxson/idevice) stack and the
[`StikJIT`](https://github.com/StikDebug/StikJIT) helper framework.

> **What this is not:** this project does not contain, and does not claim to
> contain, any new or undisclosed exploit. It only reproduces the
> already-documented, Apple-sanctioned flow — a developer-mode device
> pairing + the `debugserver` "attach with `get-task-allow`" entitlement —
> the same flow StikDebug/StikJIT already ship publicly. It only works on
> **apps you sideloaded yourself** with a development signature; it cannot
> attach to someone else's app or data.

## How JIT-without-a-computer actually works (background)

1. Apple ships a `debugserver` on every iOS device (inside the Developer
   Disk Image / "DDI"). Any process that was *signed with the
   `get-task-allow` entitlement* (true for anything sideloaded with a free
   or paid Apple developer certificate) can legally have a debugger attach
   to it. iOS only allows the JIT (`mprotect` with `PROT_EXEC` on
   writable pages) while such a debugger is attached — that's the whole
   mechanism, there's no memory-corruption bug involved.
2. Normally "attaching a debugger" means Xcode, over USB, from a Mac.
3. Since iOS 17, a device can instead be *paired* the same way Xcode pairs
   with it, and that pairing can be driven from **another process on the
   same phone** instead of a computer, using the `idevice` reimplementation
   of Apple's pairing/lockdown/RSD protocols. On iOS 27, Apple additionally
   exposes this directly in **Settings → Privacy & Security → Developer
   Mode → Pair with…**, so the one-time pairing handshake needs no computer
   either.
4. Once paired, a small helper process (here: `PocketJITHelper`, an App
   Extension) opens the `debugserver` service over the on-device pairing
   tunnel, attaches it to the target app's PID, and detaches — the target
   app is now allowed to JIT until it's relaunched.

PocketJIT is the UI + plumbing around step 4; steps 1–3 are provided by the
`idevice` C library and the `StikJIT.xcframework` built from it, which this
project depends on rather than reimplementing (per your choice — faster and
far less likely to silently break on new iOS betas than rewriting the
pairing/tunnel/debugserver protocol stack from scratch).

## Architecture

```
PocketJIT.app                     PocketJITHelper.appex
┌───────────────────────┐         ┌───────────────────────────┐
│ ContentView            │   XPC   │ HelperExtension            │
│  PairingView            │◄──────►│  calls StikJIT.enableJIT   │
│  InstalledAppsProvider  │ (PID,  │  (targetPID:pairingFile:)  │
│  PairingStore (Keychain)│  pair  └───────────────────────────┘
└───────────────────────┘  file)        depends on
                                         StikJIT.xcframework
                                         (bundles idevice FFI)
```

- **PocketJIT** (app target) — SwiftUI UI: run the one-time pairing flow,
  list sideloaded apps, pick one, tap "Enable JIT".
- **PocketJITHelper** (extension target) — the actual `StikJIT.enableJIT`
  call has to happen in its own process (see StikJIT's integration guide),
  so the app hands it a PID + the stored pairing file over XPC and gets
  progress/result back the same way.
- **Shared** — the XPC protocol both targets speak.

## Building

This repo uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) instead of
committing a binary `.xcodeproj`, so diffs stay readable.

```sh
brew install xcodegen
git clone https://github.com/clashroyalemy29-collab/PocketJIT.git
cd PocketJIT

# 1. Build (or download a release of) StikJIT.xcframework and drop it in
#    ./Vendor/StikJIT.xcframework — see
#    https://github.com/StikDebug/StikJIT#build for the two xcodebuild
#    commands that produce it.
mkdir -p Vendor
# cp -R /path/to/StikJIT.xcframework Vendor/

# 2. Generate the Xcode project from project.yml
xcodegen generate

# 3. Open and run
open PocketJIT.xcodeproj
```

Then in Xcode: select the `PocketJIT` target → Signing & Capabilities → sign
in with your own (free is fine) Apple ID and set a unique bundle id for
both the app and the `PocketJITHelper` extension, then Cmd+R onto your
device.

### First run on-device

1. Settings → Privacy & Security → Developer Mode → **Pair with…**
2. Open PocketJIT, tap **Pair**, enter the PIN Settings showed you.
3. Pick a sideloaded app from the list, tap **Enable JIT**, then launch it.

On iOS 26 and earlier (no in-Settings pairing UI), import a `.mobiledevicepairing`
/ `.plist` pairing file instead — PocketJIT's pairing screen falls back to a
file importer automatically when it can't find the iOS 27 pairing API.

## Status of this scaffold

This is a working **scaffold**, not a finished app — the pieces that are
genuinely novel engineering (`idevice`'s pairing/tunnel implementation,
`StikJIT`'s debugserver attach logic) are intentionally *not*
reimplemented here; they're pulled in as the existing, already-reviewed
open-source dependency. What's implemented in this repo:

- [x] App/extension target layout and XPC bridge
- [x] Pairing-file storage (Keychain) and iOS 27 in-Settings pairing hook
- [x] `StikJIT.enableJIT` call wired up from the extension
- [ ] Installed-app enumeration — currently a manual bundle-id / PID entry
      field; wiring this to `installation_proxy` over the same tunnel is a
      TODO (`InstalledAppsProvider.swift`)
- [ ] Auto re-launch-and-attach flow (watch for the process to (re)spawn)

## License

Original PocketJIT code in this repo: MIT (see `LICENSE`). It depends on
`StikJIT.xcframework` (MPL-2.0) and, transitively, `idevice` (MIT); neither
is vendored into this repo — see the Building section.

## Scope note

This only ever operates on apps *you* sideloaded with *your own* signing
identity on *your own* device. It is the same category of tool as
StikDebug/StikJIT/Playport/Madeira, all of which are public on GitHub; it
doesn't add a capability that doesn't already exist in the open-source
iOS-emulation community, it's just this project's own implementation of
the app/extension/XPC plumbing around it.
