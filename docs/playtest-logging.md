# Automatic playtest logs

Normal launches record a JSONL session automatically. There is no CLI, launch flag,
or special debug mode. The smoke and oracle-analysis commands intentionally do not
replace the last human playtest.

Love writes sessions to its save directory under `playtest-logs/`. On macOS for this
project, that is:

`~/Library/Application Support/LOVE/spelunky-classic-clone/playtest-logs/`

`latest.txt` contains the relative path of the most recent normal-launch session.
Each session has its own timestamped `.jsonl` file. Logs are flushed after every
record, so the lead-up to a crash remains on disk. App callback errors also write
an `error` record with a traceback. Old sessions are not deleted;
the directory will grow with continued playtesting.

Press F9 at any time to add a `bookmark` record. It does not change gameplay.
When reporting a bug, “the last playtest” is enough; mentioning the area, rough
moment, or that you pressed F9 helps narrow the search.

Every session records the Love version, source directory, and a SHA-256 fingerprint
of the running Lua source. Records include screen changes, frames, keyboard and
mouse actions, generated levels, full initial collision maps for simulation
screens, world-cell edits, dynamic-block creation/removal, and pre/post tick
observations. Tick observations include normalized input, player movement/status,
nearby cells, dynamic blocks, enemies, items, tools, traps, projectiles, and run
state where applicable. A `tick_start` record survives if the tick itself errors.

These are diagnostic observations of live play, not deterministic replays.
The schema is versioned but may grow as new bugs reveal missing context. Logs can
be large and can reveal how and when you played; keep them private unless you
choose to share them.
