# Cascade, handoff

Public repo. macOS menu bar app. One click cascades the windows on the screen
under the pointer, in two columns, leaving every title bar reachable. Companion
to AutoRaise.

## Permission, non negotiable

Needs **Accessibility**. Moving another app's windows is what that gate exists
for. Unlike FKeys there is no IOKit back door.

**The grant dies on every update.** The app is ad-hoc signed, not Developer ID
signed, so its cdhash changes with each build and macOS silently stops trusting
the existing entry. The switch still looks on. Off and on again fixes it. The
only real fix is a Developer ID certificate.

## Coordinate spaces, the trap that eats window managers

Cocoa: origin at the bottom left of the primary screen, y grows **up**.
Accessibility: origin at the top left, y grows **down**.

`AXBridge.axRect(fromCocoa:)` and `cocoaRect(fromAX:)` convert, using the height
of the screen whose origin is `.zero`, not `NSScreen.main`, which is the screen
with focus and moves around. Get this wrong and windows land on the wrong
display or off screen entirely.

Everything in `CascadeLayout` and `Arranger` is in AX space.

## Layout

`CascadeLayout.frames(count:in:)` splits the area in half, `ceil(n/2)` left.
Each column cascades by `preferredStep` 30pt, tightening the step only if the
last window would fall below `minimumSize` 420x300. Total travel is capped at
half the column either way.

Special cases that are deliberate, not oversights: one window fills the screen,
two split cleanly with no offset.

Verified before shipping: for 1, 2, 3, 5, 8, 12 and 20 windows on both a
1728x1085 and a 2560x1440 area, every frame stays inside the area and the
smallest window is 594x778 at twenty windows.

## Ordering and z-order

Windows are sorted by current `minX` so they stay on the side of the screen they
were already on.

**Setting a frame does not change z-order.** Without the second pass that calls
`AXRaiseAction` in order, the cascade positions are right but the stacking is
whatever it was, so windows hide each other's title bars and the whole point is
lost.

## Which screen

`NSEvent.mouseLocation` at click time. The pointer is on the menu bar that was
just clicked, so this satisfies both "the screen the mouse is on" and "the
screen whose button I pressed" with one rule. A window belongs to the screen its
**centre** is on; using a corner would claim windows that merely overlap an edge.

## Inherited traps, already applied

- `Package.swift` is **swift-tools-version 5.9. Do not raise it.**
- `build_app.sh` probes for `xcbuild`; universal builds need full Xcode.
- No bash arrays in scripts, macOS bash 3.2 aborts on empty array expansion
  under `set -u`.
- Artwork in tracked `assets/`; `packaging/` is gitignored generated output.
- Rolling `latest` release tag with fixed asset name `Cascade.zip`, because the
  cask URL hardcodes both. Do not rename either.

## Open

- Menu bar label is `CA`, two letters on purpose: a single `C` collided with the
  `C` FKeys shows when F1-F12 are in media mode. One constant,
  `AppDelegate.letter`.
- No hotkey. Click only, as specified.
- No undo. Previous frames are not recorded.
