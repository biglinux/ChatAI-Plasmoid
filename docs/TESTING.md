# Testing the popup size

How the fix in [POPUP_SIZE_BUGFIX.md](POPUP_SIZE_BUGFIX.md) was validated, and
how to check it again.

## Automated regression test

`tests/popup-size-regression.sh` opens and closes the ChatAI popup in the running
Plasma session and fails if the size Plasma saves on close ever changes.

```bash
tests/popup-size-regression.sh             # 20 openings, current session
tests/popup-size-regression.sh 100         # 100 openings
tests/popup-size-regression.sh 20 --fresh  # first restart plasmashell without a saved size
```

- Needs a Plasma 6 session (Wayland or X11) with ChatAI on a panel. The popup
  opens on screen while it runs.
- It toggles the popup through a temporary global shortcut (set with the
  plasmashell scripting API, triggered over D-Bus through kglobalaccel) and
  reads `popupWidth`/`popupHeight` after each close.
- `--fresh` reproduces the state where the bug happened. It restarts
  plasmashell twice (the panel disappears for a few seconds) and restores the
  saved size, ChatAI's legacy `dialogWidth`/`dialogHeight` and the shortcut at
  the end.
- With the code before the fix it reports `FAIL`; with the fix, `PASS`. The
  widget's configuration was byte-identical before and after each run.

The test needs a real compositor and plasmashell, so it is not part of CI.

## Static checks

| Check | Result |
|---|---|
| `qmllint` (Qt 6.11) on every QML file | No new warnings: `main.qml` has the same 35 warnings as before (unqualified `plasmoid`/`i18n` access found throughout the project) |
| `xmllint --noout contents/config/main.xml` | OK |
| Package built from `metadata.json contents LICENSE` | Zip integrity OK, same file list as before, no dev files |
| `kpackagetool6 -i` of that package into a temporary root | Installed |

## Live tests

Common setup: Plasma 6.7.4, KDE Frameworks 6.29, Qt 6.11.2, one 1920×1080
screen, a 40 px panel, ChatAI as a panel widget. The code under test was
installed as a temporary copy in `~/.local/share/plasma/plasmoids` (removed
afterwards); "before" means the same tests against the code before the fix.

### Wayland, bottom panel, 100% scale

Window and content sizes were logged from QML through an instrumented copy of
the widget.

| Test | Result |
|---|---|
| 100 openings, no saved size | 100 × 816×703 |
| 30 openings, same timing, before | 701 → 788 px (+88) |
| 15 s opening | No size change while open (before: one 28 s opening grew 700 → 754 px) |
| 3 plasmashell restarts × 5 openings, saved 1000×700 | 1000×700 throughout |
| Resize the open popup by +60×+90 through the compositor (KWin script) | Saved as 1060×790, kept for 5 reopenings and after a restart; same in a session without a saved size (876×793) |
| Header auto-hide on/off, header hidden on/off, popup open | Window 892×808 in all 864 logged samples; the header animation (31 → 0 px) stayed inside the layout |
| Providers ChatGPT, Claude, Gemini, DeepSeek; pin on/off; popup open | Same 892×808 |
| CPU of plasmashell + WebEngine, 20 s open and idle | Inconclusive: 15.8–28.5% across runs, dominated by the page's own activity |

### X11

Real mouse and keyboard input was generated with XTest (python-xlib), and the
popup window was measured from the X server (`_KDE_NET_WM_WINDOW_TYPE_APPLET_POPUP`
window of plasmashell).

| Test | Before | After |
|---|---|---|
| Regression test, bottom panel, 100% | 457 → 481 px in 6 openings (`FAIL`) | 20 × 816×703 (`PASS`) |
| Regression test, left (vertical) panel | Width 1175 → 1195 px in 5 openings (`FAIL`) | 10 × 817×702 (`PASS`) |
| Regression test at `QT_SCALE_FACTOR` 1.25 / 1.5 / 2 | 1.5: stable 1073×454 | 816×703 / 816×669 / 816×498, all `PASS` |

At 150% and 200% the height is Plasma's 95% screen limit in logical pixels
(1080 / 1.5 × 0.95 and 1080 / 2 × 0.95, minus the frame), so oversized popups
are clamped as expected. Before the fix the growth depended on how the
separator pixel was rounded: at 150% it did not happen.

With the fix, on the bottom panel at 100%:

| Test | Result |
|---|---|
| Window vs saved size | Window 1090×469, saved 1074×454: the saved size excludes the frame padding (16×15 px) |
| Drag the top edge 150 px up, then the left edge 100 px out, with the mouse | Window 1090×469 → 1090×619 → 1190×619, saved as 1174×604, kept for 3 reopenings and after a plasmashell restart |
| Auto-hide header: pointer on the page 4.5 s, on the top strip, away again | Header hidden → shown → hidden (screenshots); window 1190×619 throughout |
| Ctrl+F, then Escape | Find bar opens and closes; window unchanged |
| F11, then Escape | Full screen window covers the screen and closes; popup unchanged |
| Menu → About ChatAI, then Escape | In-widget settings open (About) and close; window unchanged |
| Close button, then reopen | Popup closes, a WebEngine process ends (5 → 4), reopening recreates it (5) and loads the page; size unchanged |

## Not verified

- Multiple monitors: only one screen was available. Creating virtual monitors
  with `xrandr --setmonitor` would have made Plasma add desktops and panels to
  the tester's session, so it was not done.
- Scale factors set in System Settings (they need a new login); the scale tests
  used `QT_SCALE_FACTOR` on plasmashell, which scales it the same way.
- A widget inside the System Tray: ChatAI does not declare
  `X-Plasma-NotificationArea`, so it cannot be placed there.

## Observations (unchanged behaviour)

- Escape does not close the popup while the web page has focus: Qt WebEngine
  hands it to the page, which sites use for their own dialogs. The shortcut
  list in About documents Escape only for the find bar, settings and full
  screen.
- Tab moves focus inside the web page, not through the toolbar.
