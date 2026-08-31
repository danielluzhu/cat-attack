# CatAttack — working notes

## Commit convention

One logical change per commit, pushed as it lands. Never batch several
unrelated changes into a single commit, and don't leave finished work sitting
uncommitted at the end of a task.

## Build & run

```bash
swift build                 # compile
./scripts/make-app.sh       # build build/CatAttack.app
open build/CatAttack.app
```

`swift test` does **not** run on a machine with only Command Line Tools
installed — XCTest is missing. The tests in `Tests/` are still correct and run
under full Xcode. To verify detection logic without Xcode, compile the core
sources together with a throwaway `main.swift` harness and run it directly.

## Layout

- `Sources/CatAttackCore/` — detection heuristics and unlock-phrase matching.
  Pure logic, no AppKit, so it stays unit-testable. Put anything worth testing
  here rather than in the app target.
- `Sources/CatAttack/` — event tap, lock state, overlay, menu bar.

## Accessibility permission gotcha

The app needs Accessibility (it blocks events, not just observes them).
`make-app.sh` ad-hoc signs by default, which gives the app a new code identity
on every build, so macOS silently stops honouring the existing grant — System
Settings still shows CatAttack enabled while the app is denied. Symptom: ⚠️ in
the menu bar and nothing ever locks.

After a rebuild, re-grant by toggling CatAttack off and on in System Settings →
Privacy & Security → Accessibility. The app supervises tap acquisition and
picks the grant up within ~3 s, so it does not need relaunching. Set
`CATATTACK_SIGN_IDENTITY` to a stable self-signed certificate to avoid the
dance entirely.

Diagnosing: the app logs its state, so start here rather than guessing.

```bash
log show --last 10m --predicate 'process == "CatAttack"' --style compact | grep "CatAttack:"
```
