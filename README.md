# Spelunky Classic clone

This is a coverage inventory for the original **Spelunky Classic (1.1)**, not a claim that the game is finished. The original source in [`original-game-reference`](original-game-reference/SOURCE_OF_TRUTH.md) is the behavioral authority; the [Classic wiki's places](https://spelunky.fandom.com/wiki/Places_%28Classic%29), [level feelings](https://spelunky.fandom.com/wiki/Level_Feeling_%28Classic%29), [enemies](https://spelunky.fandom.com/wiki/Enemies_%28Classic%29), [items](https://spelunky.fandom.com/wiki/Items_%28Classic%29), [traps](https://spelunky.fandom.com/wiki/Traps_%28Classic%29), and [unlockable rooms](https://spelunky.fandom.com/wiki/Unlockable_rooms) are cross-checks for omissions. HD and Spelunky 2 content is out of scope.

Implemented objects live in individual Lua modules under `src/platform/` (`items/shotgun.lua`, `pickups/compass.lua`, `enemies/skeleton.lua`, `tiles/brick.lua`, etc.). See [object module conventions](src/platform/README.md#object-modules) for the registries and shared systems.

Normal playtest sessions log automatically to `playtest-logs/` in Love's save directory. `latest.txt` points to the most recent JSONL session; press F9 during a test to add a bookmark for later diagnosis. The smoke suite does not create a playtest session.

Gameplay controls load the original 12-line `keys.cfg` and seven-line `settings.cfg` format. A file in Love's save directory takes priority; otherwise the real files in `original-game-reference/` are used. The shipped keyboard bindings are arrows to move/climb, Z jump, X action/pickup/throw, Shift run, A bomb, and S rope—WASD does not move the player. Hold Up+A for a high bomb throw or Down+A for a short grounded drop; Down+S drops a rope beside a ledge. A blocked downward rope falls back to an upward throw; an upward placement without headroom does not spend a rope. In Full Level Playtest, R resets the selected Mines level with full health, four bombs, and no gold. The loaded `downToRun` setting affects movement; `musicVol` and `soundVol` use Classic’s attenuation scale. `graphicsHigh` controls cave fringes, bomb flames and blood trails. `gamepad.cfg` loads the original nine button/trigger mappings when `gamepadOn` is enabled, with joystick axes and the directional hat for movement. Gamepad Start follows Escape navigation. The lab keeps its own window dimensions; Full game forces fullscreen and scales the 320×240 view to fit, overriding the display settings. P purchases eligible shop stock. C cycles a light held item through an unarmed bomb and rope, reserving and refunding resources; ACTION arms or throws the selected tool. The source comments out F flare activation.

The lab menu contains **Animation Viewer**, **Scenario Tests**, **Full Level Playtest**, and **Full game**. Full Level Playtest includes the former generation preview: **Tab** switches between gameplay and a paused whole-level map; **F2** toggles the room-path overlay in either view. Gameplay actions are disabled while viewing the map. Use **N** for the next seed, **R** to restart, **-/=** for depth, and **T** to cycle level types in either view.

Choices are Random, Standard, Idol, Kali Altar, Snake Pit, Shop, and Dark. Selecting Shop, Kali Altar, or Dark from 1–1 moves to 1–2, where those types can generate. The selector searches forward for a seed that naturally produces the type. Manual type changes and filtered rerolls start a fresh test run; ordinary exit progression returns to Random. The selected type and actual seed are recorded in playtest logs.

Legend: **`[ ]`** not started; **`[ ] … [WIP]`** started, but incomplete or not yet validated; **`[x]`** explicitly confirmed by the player in a playtest. Code, assets, and automated tests alone never promote an entry to `[x]`. A confirmed narrow behavior does not confirm its whole category. Update these markers as playtests and source comparisons establish more.

## Coverage inventory

- [x] Mines (levels 1–4)
  - [x] Snake Pit
- [ ] Jungle (levels 5–8)
  - [ ] Black Market
  - [ ] Restless Dead
  - [ ] Flooded Cavern
- [ ] Ice Caves (levels 9–12)
  - [ ] Yeti Kingdom
  - [ ] UFO crash-site
- [ ] Temple (levels 13–15)
  - [ ] City of Gold
  - [ ] Sacrificial Pit
- [ ] Olmec's Lair (level 16)
- [x] Dark levels
- [x] Kali altars
- [ ] City of Gold item sequence [WIP]
- [ ] Intro cinematic
- [ ] Original main/title screen
- [ ] Playable tutorial
- [ ] Between-area transition scenes [WIP]
- [ ] Tunnel Man encounters in transition scenes [WIP]
- [ ] Shortcuts
- [ ] High-score screen
- [ ] Olmec victory sequence
- [ ] Ending cinematics
- [ ] Credits
- [ ] Return paths between screens
- [ ] Sun Room survival challenge
- [ ] Moon Room archery challenge
- [ ] Stars Room shopkeeper challenge
