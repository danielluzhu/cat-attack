# CatAttack 🐾

A macOS menu bar app that detects when a cat walks onto your keyboard and locks the keyboard until a human takes over.

## How it works

CatAttack installs a system-wide keyboard event tap (CGEvent tap) and scores every key-down against three paw-shaped heuristics:

1. **Mass press** — 5 or more keys held down at the same time.
2. **Paw-sized press** — 4 or more keys held at once that are *physically adjacent* on the keyboard (it knows the ANSI key layout, so `u`+`i`+`j`+`k` is a paw, but spread-out keys held for a shortcut are not).
3. **Paw skitter** — 6 or more distinct keys within 250 ms that are all clustered in one region of the keyboard. Real fast typing spreads across the whole board; a walking cat mashes one area at a time.
4. **Mashing** — 7 or more distinct keys within 250 ms anywhere on the keyboard. That is 28 keys/second, about triple what a fast typist sustains, so only a paw (or a human deliberately testing it) gets there. Repeatedly hitting the same few keys does not count, since the rule counts *distinct* keys.

These are the **Normal** sensitivity thresholds; the menu bar's *Sensitivity* submenu switches between Low (lock only on obvious cats), Normal, and High (lock eagerly — fast rollover typing may false-positive).

When any rule fires, the keyboard **locks**: every key-down is swallowed before reaching apps (key-ups and modifier changes pass through so nothing gets stuck), a beep sounds, and a floating overlay appears.

### Unlocking

- **Type the unlock phrase** (default `human`) — key presses are still observed while locked, just not delivered, so a human can type it. A cat statistically cannot.
- **Click "Unlock with mouse"** on the overlay, or use the 🙀 menu bar item.
- **Walk away** — it auto-unlocks after 10 s with no key presses (the cat left).

However it disengages, a brief "✅ Keyboard unlocked" popup confirms the keyboard is live again.

## Build & run

```bash
./scripts/make-app.sh
open build/CatAttack.app
```

On first launch macOS will prompt for **Accessibility** permission (System Settings → Privacy & Security → Accessibility). Enable CatAttack there; the app starts watching automatically once granted (menu bar icon changes from ⚠️ to 🐾).

You can also run it unbundled with `swift run CatAttack`, but then the Accessibility grant applies to your terminal app instead — the bundled `.app` is the intended way.

### Tests

The detection heuristics live in a separate `CatAttackCore` library with unit tests:

```bash
swift test
```

## Menu bar

| Icon | Meaning |
|------|---------|
| 🐾 | Watching for cats |
| 🙀 | Keyboard locked |
| 💤 | Detection paused |
| ⚠️ | Waiting for Accessibility permission |

The menu offers manual lock, pause/resume detection (for gaming or key-mashing work), a sensitivity preset (Low / Normal / High), and quit.

## Tuning

Settings are read at launch from the app's defaults domain:

```bash
# Unlock phrase (lowercase letters only; default "human")
defaults write com.catattack.CatAttack unlockPhrase -string "letmein"

# Seconds of silence before auto-unlock (default 10)
defaults write com.catattack.CatAttack autoUnlockSeconds -int 15

# Detection thresholds (applied on top of the sensitivity preset)
defaults write com.catattack.CatAttack sensitivity -string low # low | normal | high
defaults write com.catattack.CatAttack maxHeldKeys -int 6      # simultaneous keys = instant lock (default 5)
defaults write com.catattack.CatAttack burstCount -int 7       # distinct keys per burst (default 6)
defaults write com.catattack.CatAttack burstWindowMs -int 200  # burst window in ms (default 250)
```

Restart the app after changing settings (the Sensitivity menu applies immediately).

## Project layout

- `Sources/CatAttackCore/` — pure detection logic: [CatDetector.swift](Sources/CatAttackCore/CatDetector.swift) (heuristics) and [KeyLayout.swift](Sources/CatAttackCore/KeyLayout.swift) (physical key positions for adjacency math). No AppKit, fully unit-testable.
- `Sources/CatAttack/` — the app: event tap ([KeyboardMonitor.swift](Sources/CatAttack/KeyboardMonitor.swift)), lock state + unlock phrase ([LockController.swift](Sources/CatAttack/LockController.swift)), overlay panel, menu bar item.
- `Tests/CatAttackTests/` — cat vs. human scenarios.

## Troubleshooting

**The menu bar shows ⚠️ and nothing locks, even though CatAttack is listed in Accessibility.**

This is the usual symptom after a rebuild. The build script ad-hoc signs the app, which gives it a *new code identity* every time, so macOS stops honouring the existing grant — System Settings still shows CatAttack switched on, but the app is denied and sits idle.

Fix it by re-granting: System Settings → Privacy & Security → Accessibility, then **turn CatAttack off and on again** (or remove it with "−" and re-add `build/CatAttack.app`). The app re-checks every 3 seconds and activates itself as soon as the grant lands, so there's no need to relaunch it.

To stop this recurring, build with a stable signing identity. Create a self-signed code-signing certificate once in Keychain Access (Certificate Assistant → Create a Certificate, type "Code Signing"), then:

```bash
CATATTACK_SIGN_IDENTITY="CatAttack Self Signed" ./scripts/make-app.sh
```

Grants then survive rebuilds, because the recorded identity is the certificate rather than the exact binary.

**Checking what the app thinks is happening:**

```bash
log show --last 10m --predicate 'process == "CatAttack"' --style compact | grep "CatAttack:"
```

It logs `event tap active — watching for cats` on success, and the specific reason on failure.

## Notes & limitations

- Key layout math assumes a US ANSI layout; other layouts still work, but adjacency detection is approximate.
- The tap needs Accessibility (not just Input Monitoring) because it actively blocks events, not merely observes them.
- Locking swallows keyboard input only — mouse/trackpad keep working, which is also your escape hatch.
