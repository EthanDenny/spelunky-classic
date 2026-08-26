# Original executable oracle

This directory contains pixel-level captures from the untouched Spelunky 1.1
Windows executable. The executable is copied to `C:\SpelunkyOracle` inside the
`Windows 11` Parallels VM; it is not modified in place.

Run these commands from the repository root:

```sh
tools/original_oracle.sh setup
tools/original_oracle.sh launch
tools/original_oracle.sh hold-frames right 10
tools/original_oracle.sh chord-frames run right 10
tools/original_oracle.sh capture-held jump-held-05 jump 5
tools/original_oracle.sh capture-after jump-short-05 jump 1 4
tools/original_oracle.sh tap jump
tools/original_oracle.sh capture jump-01
```

`hold-frames` converts the requested number of 30 Hz game steps to a key-hold
duration. Because the retail executable exposes no frame-step API, the beginning
of a key hold can land on either side of a runner tick. Repeat boundary-sensitive
measurements and compare the neighboring traces rather than treating one capture
as sub-frame instrumentation.

`capture-held` presses a control, waits for the requested interval, triggers F9
while that control is still down, and then releases it. It is intended for
in-flight jump and climb captures that would finish before a normal capture can
be copied back to the host. Capture commands switch focus back to
`Spelunky.exe` after the guest copy completes so the next injected input is not
lost to PowerShell. The held control is released immediately after F9, before
the slower guest-to-host copy begins.

`capture-after` holds and releases a control, waits a second requested interval,
and then triggers F9. It is useful for comparing a released short jump with a
same-age held jump.

The `capture` command uses Spelunky's own F9 screenshot feature. This is
intentional: Parallels' VM screenshot command returns a black rectangle for the
legacy DirectDraw surface.

The low-level Parallels key mapping follows the official `prlctl send-key-event`
codes. Spelunky's configured controls are read from the original `keys.cfg`:

| Oracle key | Original input |
| --- | --- |
| `left`, `right`, `up`, `down` | Arrow keys |
| `jump` | Z |
| `action` | X |
| `cycle` | C |
| `run` | Left Shift |
| `f4` | Toggle fullscreen |
| `f9` | Save an original-renderer screenshot |

Do not use modern GameMaker, ENIGMA, or OpenGMK output as the final behavioral
baseline. The shipping executable remains the oracle.

Locate the original player's logical 320x240 position in a saved capture with:

```sh
/Applications/love.app/Contents/MacOS/love . --analyze-oracle \
  test/original-oracle/captures/tutorial-baseline.png
```

The matcher tests the extracted movement sprite frames in both facings and
reports the sprite, frame, logical origin position, and mean RGB error.
