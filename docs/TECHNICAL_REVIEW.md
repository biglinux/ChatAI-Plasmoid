# Technical review: popup size fix

## Changes

| File | Change |
|---|---|
| `contents/ui/main.qml` | Constant `Layout.preferredWidth`/`Layout.preferredHeight`; removed `saveSizeTimer` and the size change handlers |
| `contents/config/main.xml` | Comment marking `dialogWidth`/`dialogHeight` as legacy |
| `ChatAI-Plasmoid.plasmoid` | Rebuilt: the committed package still contained the old `main.qml` |
| `tests/popup-size-regression.sh` | New live regression test |
| `docs/` | This review, [POPUP_SIZE_BUGFIX.md](POPUP_SIZE_BUGFIX.md) and [TESTING.md](TESTING.md) |
| `README.md` | `docs/` and `tests/` in the Development section |

## Decisions

**Let Plasma own the popup size.** Plasma 6's `AppletPopup` already persists the
popup size, saving it on hide and restoring it at startup, without frame margins
and limited to 95% of the screen. ChatAI kept a second copy of the same
information, and keeping both in sync is what created the loop. Removing ChatAI's
copy fixes the cause instead of compensating for it, removes code, and makes
ChatAI behave like the standard Plasma applets.

Alternatives considered and rejected:

- *Subtract the separator pixel before saving.* It depends on an internal detail
  of Plasma's `CompactApplet.qml` (1 px, only on panel edges, only when not
  compensated) and would break silently when that changes.
- *Save only when the popup hides.* The measured size still includes the extra
  pixel, so the growth would only slow down to 1 px per opening.
- *Ignore size changes right after opening.* It needs a timing guess, and the
  measured size is wrong for as long as the popup is open, not only at opening.
- *Read the saved size once, without a live binding.* It stops the loop within a
  session but still saves a size 1 px off, which then becomes the next
  session's starting size.

**Keep the legacy keys.** `dialogWidth`/`dialogHeight` stay in the KConfig schema
because `Migration.js` treats `dialogWidth > 0` as a sign of an older
installation. Existing values are harmless: nothing reads them for sizing any
more. Users keep the size Plasma saved for them.

**Defaults unchanged.** `defaultWidth` (at least 780 CSS px of viewport, so the
AI sites keep their desktop layout) and `defaultHeight` (39 grid units) are the
same values as before.

## Performance

- One `Timer` and two signal handlers fewer in `main.qml`.
- In the affected state, the old loop resized the popup window, and with it the
  Qt WebEngine view, every 500 ms for as long as the popup was open, writing the
  configuration file each time. That no longer happens.
- A CPU comparison over 20 s with the popup idle was dominated by the web page's
  own activity and was inconclusive, so no figure is claimed.

## Related audit findings

- **Header animation.** `Behavior on Layout.preferredHeight` of the header only
  redistributes space inside the layout. With an explicit preferred size on the
  representation it cannot change the window, as the header tests in
  [TESTING.md](TESTING.md) confirmed. It was kept.
- **Content cannot resize the window.** Plasma reads the representation's
  `Layout.preferredHeight`, which is explicit, so the WebView, the settings panel
  and the auto-hide reveal strip do not affect the popup size.
- **Committed package was stale.** `ChatAI-Plasmoid.plasmoid` had not been
  rebuilt since the size persistence was last changed, so installing from it
  would have kept the bug. It was rebuilt with the command from the README.
- **Not ChatAI's code.** A malformed `[Containments2Appletsts]` group with
  `dialogWidth`/`dialogHeight` was found in the test machine's
  `plasma-org.kde.plasma.desktop-appletsrc`. Nothing in this repository or in
  biglinux-welcome writes it; it comes from another tool writing to a wrong
  group path and is harmless to ChatAI.

No visual or interaction changes were made beyond the fix.
