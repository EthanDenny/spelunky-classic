# Original area artwork

These PNGs are direct copies of frame 0 from the extracted Spelunky Classic 1.1
GameMaker project under `original-game-reference/source/extracted/spelunky`.
They have only been renamed for the LÖVE renderer; their pixel data is unchanged.

- `bg_cave.png`, `bg_temple.png`: `Backgrounds/bgCave.png`, `Backgrounds/bgTemple.png`
- `jungle*.png`: `Sprites/Blocks/Lush/sLush*.images/image 0.png`
- `dark*.png`, `ice*.png`, `thin_ice.png`: corresponding sprites under `Sprites/Blocks/Dark`
- `temple*.png`: `Sprites/Blocks/Temple/sTemple*.images/image 0.png`
- `water*.png`, `lava*.png`: corresponding sprites under `Sprites/Blocks/Water`
- `vine*.png`: corresponding sprites under `Sprites/Blocks/Ladders`
- `olmec.png`: `Sprites/Enemies/Olmec/sOlmecStart1.images/image 0.png`

The exact procedural templates and obstacle tables are generated into
`src/world/original_area_data.lua` by `tools/extract_original_area_data.py`.
