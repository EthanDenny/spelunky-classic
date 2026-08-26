# Original animation frames

`tools/extract_original_animations.py` generates this directory from the extracted
GameMaker 8.1 project in `original-game-reference/source/extracted/spelunky`.

It copies every sprite containing more than one subimage, excluding the three font
glyph sheets. The generated `src/animation/original_catalog.lua` pairs left/right
sprites, preserves their original frame order, dimensions, and origins, associates
them with source objects, and records source-derived `image_speed` and Animation End
behavior.

Entity pages are derived from `src/animation/entity_combinations.json`. That map is
the human-reviewed list of original sprite resources that belong on the same entity
page. It changes catalog organization only: the source resource names, extracted PNG
files, and frame sequences remain untouched.

The map also enables the catalog's left-facing deduplication policy. A sprite whose
resource name contains `Right` is omitted from the viewer when replacing the first
`Right` with `Left` names another original sprite. The viewer mirrors that left-facing
sequence when facing right; both original resource directories remain extracted.

Gameplay rooms run at 30 steps per second, so a fixed animation's playback rate is
`image_speed * 30` frames per second.
