# Original game reference

This directory is the source-of-truth reference for the original Spelunky
Classic 1.1 game while developing the LÖVE reimplementation.

## Upstream provenance

- Repository: <https://github.com/gondur/spelunky-classic-1.1>
- Branch: `master`
- Imported commit: `9a9e3e865d489510bbc34e7bb1dc5006c5c3823c`
- Imported: 2026-08-26

The upstream Git metadata was intentionally omitted so this directory and the
extracted resources can be tracked as ordinary files by the parent repository.

## Project sources

The untouched GameMaker project binaries are:

- `source/spelunky.gmk` — SHA-256
  `d28e322e4aa03b0137485d2c1c3be11899502f2b582b3d22b8939be81f97186c`
- `source/config.gmk` — SHA-256
  `589321ee9a7fd117c64d55b8e659b1fd58bc59ba595fc9fd6fb9ac1be9ef10c7`

Their decomposed, searchable resource trees are:

- `source/extracted/spelunky/`
- `source/extracted/config/`

The `.gmk` headers identify both projects as GameMaker 8.0 format (version
800). The upstream `source/readme2.txt` likewise says the projects were made
with Game Maker 7.0 and 8.0. This matters when reproducing legacy engine
behavior: do not silently assume a GameMaker 8.1 project-file format.

## Extraction

The trees were produced with Gmk Splitter v0.19:

- Project: <https://github.com/Medo42/Gmk-Splitter>
- Release archive SHA-256:
  `f9eadbb85e2a58492b004e1dd9cec98e0691f1c59a1b51c24619598c83f52b03`
- ID mode: `--preserve-ids all`
- Duplicate ID mode: `--allow-duplicate-ids tiles,instances`

The full ID options are deliberate. GameMaker resource IDs and room instance
ordering can be observable game behavior, so they must not be reassigned while
using this reference.

The splitter requires headless AWT mode on macOS in this environment. The
equivalent extraction command is:

```sh
java -Djava.awt.headless=true -jar gmksplit.jar \
  --preserve-ids all \
  --allow-duplicate-ids tiles,instances \
  source/spelunky.gmk source/extracted/spelunky
```

The same command was used for `config.gmk`.

## Verification and limitations

Each extracted tree was rebuilt into a fresh GM8 `.gmk` and extracted again
with the same ID settings. Recursive comparison found no differences for
either project.

Gmk Splitter documents limitations around triggers, custom action libraries,
and per-resource timestamps. For any detail not represented in an extracted
tree, the untouched `.gmk` file is authoritative. The shipped executables,
external `sound/` assets, configuration files, documentation, and GameMaker
8.x runtime behavior should be used as corroborating references when exact
behavior is important.
