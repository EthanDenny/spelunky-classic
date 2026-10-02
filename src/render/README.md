# Mines rendering order

Classic GameMaker draws larger `depth` values first (behind smaller values).
Each object or tile module declares its Classic depth and any state changes.
`classic_depth.lua` resolves those definitions; `depth_queue.lua` sorts draw
submissions back-to-front and keeps
submission order for equal depths. The source does not establish an equal-depth
tie rule we can rely on, so equal-depth overlap is explicitly our choice. Loose
rocks are submitted before brick tiles at depth 100 so foreground brick pixels
occlude them.

The mapping comes from each object's `<depth>` in
`original-game-reference/source/extracted/spelunky/Objects`, plus tile depths in
`Scripts/Level Generation/scrInitLevel.gml`, `scrRoomGen.gml`, and
`scrSetupWalls.gml`. Do **not** assign the parent `oItem` depth to every item:
for example, `oRock` is 100, `oMattock` is 101, and `oChest` is 900. The shop
`k` marker instantiates `oSign` at 110; the separate dice-sign *tile* is 9004.

`WorldGeneration:submitLevel` submits static backdrops, entities, terrain and
cave lips for both the preview and live playtest. Full Level Playtest submits
items, creatures, dynamic terrain, traps, tools, projectiles, player, whip and
effects to the **same** queue. Platforming Engine and Enemy AI also use the
same queue and depth mapping. Sprite draw functions only draw their own image;
they must not establish global bands by drawing neighboring objects. The room
background is drawn before the queue. Darkness masks the completed world;
HUD, UI and diagnostic overlays are separate passes after it.

Some depths change at runtime: bombs 99 → armed 49 or sticky 1; held objects 0,
or 51 while climbing with cape/jetpack; player 50, or 999 in original exit/lava
animations; damsel exit/lava depth is likewise state-specific. The current
Mines playtest changes bomb and held-item depths, but does not yet implement the
original exit/lava animation phases. Do not fake them with a permanent depth.
Thrown ropes are at 100; deployed rope tops and segments are at 200.

When adding a visible kind or state, find the original object and its Step/End
Step depth changes, declare the depth in its object module (unknown kinds fail
loudly), submit the
object from its owner into the queue, and add a rendered-order regression in
`src/tests/render_depth_test.lua` for at least one relevant occlusion boundary.
Keep the queue inside the world camera transform; never put HUD or darkness
into it. `love . --smoke-test` exercises preview and live playtest ordering.
