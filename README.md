# Cascade

One click cascades every window on the screen you are pointing at. Built to pair
with [AutoRaise](https://github.com/dimentium/AutoRaise).

Click **CA** in the menu bar. The screen under the pointer is split down the
middle, its windows are dealt out between the two halves, and each half is
cascaded down and to the right so that **every window keeps a strip of its title
bar exposed**.

That strip is the whole idea. With AutoRaise running, moving the pointer onto any
exposed sliver brings that window forward. Two displays become four working
zones you can reach without a single click.

Only the screen the pointer is on is touched. The other display is left exactly
as it was.

## Install

```
brew install --cask markoboskoauroville/pasty/cascade
```

Cascade.app lands in Applications. The cask installs a prebuilt app, so no Swift
toolchain is needed.

## Permission

**Cascade needs Accessibility permission, and there is no way around it.**
Moving another application's windows is precisely what macOS puts behind that
gate.

System Settings, Privacy & Security, Accessibility, switch Cascade on.

If it is already on and nothing happens, switch it off and on again. After an
update macOS keeps the old entry but stops trusting it, and a stale entry looks
identical to a working one.

## Behaviour

- One window on the screen: it fills the screen. There is nothing to cascade
  against, and halving it would waste the display.
- Two windows: a clean left and right split, no offset.
- Three or more: dealt between the halves, cascaded by 30pt steps.
- Windows are ordered left to right by where they already are, so they broadly
  stay on the side you had them on.
- Skipped: minimised windows, full screen windows, palettes and panels, and any
  window whose app refuses to be moved or resized.

## Build from source

```
swift build -c release
VERSION=1.0.0 BUILD=1 ./scripts/build_app.sh
```

Requires macOS 13 or later.

## Licence

MIT. Rectangle was the reference for how a macOS window mover should behave;
no code was taken from it.
