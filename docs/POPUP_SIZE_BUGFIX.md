# Popup grows taller on its own

## Symptom

Opening ChatAI from its panel icon, the popup got a little taller every time,
without the user resizing it, until it reached the 95% screen limit Plasma
enforces. On a horizontal panel only the height grew; on a vertical panel the
width grew instead. Both Wayland and X11 were affected.

## Reproducing (before the fix)

The growth happens in a Plasma session that started without a saved popup size
for the widget: a newly added widget, the first session after installing, or
after `popupWidth`/`popupHeight` were removed from its configuration.

1. Add ChatAI to a horizontal panel (or remove `popupWidth`/`popupHeight` from
   `[Containments][N][Applets][M][Configuration]` in
   `~/.config/plasma-org.kde.plasma.desktop-appletsrc` and restart plasmashell).
2. Open the popup and leave it open: it grows 1 px every 500 ms.
3. Close and reopen it: the extra height is kept and keeps growing.

`tests/popup-size-regression.sh --fresh` automates this (see
[TESTING.md](TESTING.md)).

## Root cause

A feedback loop in `contents/ui/main.qml` between the size ChatAI asked for and
the size it measured:

```text
Layout.preferredHeight  <- plasmoid.configuration.dialogHeight
        |
        v  Plasma sizes the popup from it: preferredHeight + 1 + frame padding
mainLayout.height = preferredHeight + 1
        |
        v  onHeightChanged -> saveSizeTimer (500 ms)
plasmoid.configuration.dialogHeight = mainLayout.height  -> back to the top, +1 px
```

The extra pixel comes from Plasma's popup wrapper for panel applets
(`/usr/share/plasma/shells/org.kde.plasma.desktop/contents/applet/CompactApplet.qml`).
It draws a 1 px separator line against the panel and adds it to the popup's size
hint (`appletParent.extraHeight: 1` for top/bottom panels, `extraWidth: 1` for
left/right panels). It only subtracts that pixel from the applet
(`fullRepresentation.anchors.bottomMargin`) if the separator is already visible
when the representation is attached, which was not the case here. So the applet
gets one pixel more than it asked for.

Logged in Plasma 6.7.4 (frame padding 15 px vertically):

```text
pref=1000x700  win=1016x716  content=1000x701
SAVED content=702  pref=701  win=717
SAVED content=703  pref=702  win=718   ... every 500 ms while open
```

Any difference between the requested and the received size would have caused
the same drift; the loop turned a constant 1 px offset into unbounded growth.
Whether that pixel shows up depends on how the separator is rounded at the
current scale: at 150% (`QT_SCALE_FACTOR=1.5`) the old code did not grow, at
100% and on a vertical panel it did.

### Why it did not happen in every session

Plasma 6's `AppletPopup` saves the popup size itself when the popup hides
(`popupWidth`/`popupHeight`, without the frame padding) and restores it when
plasmashell starts. A restored size makes Plasma ignore `Layout.preferredHeight`
for the rest of that session, so the loop could not resize the popup. In a
session without a saved size the loop ran freely, and Plasma then saved the
inflated size, which is why it stayed large afterwards.

## Fix

`main.qml` no longer persists the size. `Layout.preferredWidth` and
`Layout.preferredHeight` are constants (`defaultWidth`, `defaultHeight`): the
size of a popup the user never resized. The `saveSizeTimer` and the
`onWidthChanged`/`onHeightChanged` handlers are gone.

Remembering a manual resize is left to Plasma, which already does it correctly:
it saves the size on hide, restores it on startup, keeps it within 95% of the
screen and is unaffected by theme margins. The popup is resized by Plasma's own
resize handles, so a user resize is the only thing that changes that saved size.

`dialogWidth`/`dialogHeight` stay in `contents/config/main.xml` because
`Migration.js` uses `dialogWidth` to recognise older installations; they are
no longer written or read for sizing.

## Before and after

Same machine and session state (no saved popup size), 30 openings of 1.2 s each:

| Opening | 1 | 10 | 20 | 30 |
|---|---|---|---|---|
| Before | 701 | 725 | 755 | 788 (+88 px) |
| After | 703 | 703 | 703 | 703 |

A single 28 s opening grew the popup from 700 to 754 px before the fix. After
it, 100 consecutive openings all saved 816×703. On X11 with a left panel the
old code grew the width from 1175 to 1195 px in 5 openings; the fix kept
817×702.

## Known limitations

- A popup that already grew keeps its saved size: the fix stops further growth
  but cannot tell an inflated size from one the user chose. Resizing it once
  fixes it for good.
- The applet still receives `preferredHeight + 1` on a horizontal panel (the
  separator compensation described above, in Plasma's own `CompactApplet.qml`).
  It is now a constant pixel, not a cumulative one.
- In a session without a saved popup size, a change of the default size (for
  example a different font size, which changes `Kirigami.Units.gridUnit`) makes
  Plasma resize the popup to the new default. This is Plasma's behaviour for
  every applet; once a size is saved it no longer applies.
- Validated on Wayland and X11, with bottom and left panels and at 100–200%
  scale, on a single monitor; see [TESTING.md](TESTING.md).
