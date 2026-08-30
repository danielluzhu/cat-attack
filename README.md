# CatAttack 🐾

A macOS menu bar app that detects when a cat walks onto your keyboard and locks the keyboard until a human takes over.

## How it works

CatAttack installs a system-wide keyboard event tap (CGEvent tap) and scores every key-down against three paw-shaped heuristics:

1. **Mass press** — 4 or more keys held down at the same time.
2. **Paw-sized press** — 3 or more keys held at once that are *physically adjacent* on the keyboard (it knows the ANSI key layout, so `j`+`k`+`l` is a paw, but `q`+`p`+`z` held for a shortcut is not enough on its own).
3. **Paw skitter** — 5 or more distinct keys within 300 ms that are all clustered in one region of the keyboard. Real fast typing spreads across the whole board; a walking cat mashes one area at a time.

When any rule fires, the keyboard **locks**: every key-down is swallowed before reaching apps (key-ups and modifier changes pass through so nothing gets stuck), a beep sounds, and a floating overlay appears.

### Unlocking

- **Type the unlock phrase** (default `human`) — key presses are still observed while locked, just not delivered, so a human can type it. A cat statistically cannot.
- **Click "Unlock with mouse"** on the overlay, or use the 🙀 menu bar item.
- **Walk away** — it auto-unlocks after 10 s with no key presses (the cat left).

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

The menu offers manual lock, pause/resume detection (for gaming or key-mashing work), and quit.

## Tuning

Settings are read at launch from the app's defaults domain:

```bash
# Unlock phrase (lowercase letters only; default "human")
defaults write com.catattack.CatAttack unlockPhrase -string "letmein"

# Seconds of silence before auto-unlock (default 10)
defaults write com.catattack.CatAttack autoUnlockSeconds -int 15

# Detection thresholds
defaults write com.catattack.CatAttack maxHeldKeys -int 5      # simultaneous keys = instant lock (default 4)
defaults write com.catattack.CatAttack burstCount -int 6       # distinct keys per burst (default 5)
defaults write com.catattack.CatAttack burstWindowMs -int 250  # burst window in ms (default 300)
```

Restart the app after changing settings.

## Project layout

- `Sources/CatAttackCore/` — pure detection logic: [CatDetector.swift](Sources/CatAttackCore/CatDetector.swift) (heuristics) and [KeyLayout.swift](Sources/CatAttackCore/KeyLayout.swift) (physical key positions for adjacency math). No AppKit, fully unit-testable.
- `Sources/CatAttack/` — the app: event tap ([KeyboardMonitor.swift](Sources/CatAttack/KeyboardMonitor.swift)), lock state + unlock phrase ([LockController.swift](Sources/CatAttack/LockController.swift)), overlay panel, menu bar item.
- `Tests/CatAttackTests/` — cat vs. human scenarios.

## Notes & limitations

- Key layout math assumes a US ANSI layout; other layouts still work, but adjacency detection is approximate.
- The tap needs Accessibility (not just Input Monitoring) because it actively blocks events, not merely observes them.
- Locking swallows keyboard input only — mouse/trackpad keep working, which is also your escape hatch.
