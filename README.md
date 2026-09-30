# Spelunky Classic clone

This is a coverage inventory for the original **Spelunky Classic (1.1)**, not a claim that the game is finished. The original source in [`original-game-reference`](original-game-reference/SOURCE_OF_TRUTH.md) is the behavioral authority; the [Classic wiki's places](https://spelunky.fandom.com/wiki/Places_%28Classic%29), [level feelings](https://spelunky.fandom.com/wiki/Level_Feeling_%28Classic%29), [enemies](https://spelunky.fandom.com/wiki/Enemies_%28Classic%29), [items](https://spelunky.fandom.com/wiki/Items_%28Classic%29), [traps](https://spelunky.fandom.com/wiki/Traps_%28Classic%29), and [unlockable rooms](https://spelunky.fandom.com/wiki/Unlockable_rooms) are cross-checks for omissions. HD and Spelunky 2 content is out of scope.

The playable implementation currently focuses on **Mines 1–4 only**. World Generation and Full Level Playtest generate Mines levels; the playtest stops at the 1–4 exit. Jungle, Ice Caves, Temple, Olmec, and special-level generation/gameplay were removed for this focused pass. Their entries below remain as future coverage goals, not active implementations. The animation viewer, original-source archive, and image/sound assets still cover the wider Classic game. Run the project with Love 11.5 (`love .`); run its smoke suite with `love . --smoke-test`.

Normal playtest sessions log automatically to `playtest-logs/` in Love's save directory. `latest.txt` points to the most recent JSONL session; press F9 during a test to add a bookmark for later diagnosis. The smoke suite does not create a playtest session.

Legend: **`[ ]`** not started; **`[ ] … [WIP]`** started, but incomplete or not yet validated; **`[x]`** explicitly confirmed by the player in a playtest. Code, assets, and automated tests alone never promote an entry to `[x]`. A confirmed narrow behavior does not confirm its whole category. Update these markers as playtests and source comparisons establish more.

## Coverage inventory

- **Areas and level types**
  - [ ] Cave / Mines (levels 1–4) [WIP]
  - [ ] Lush / Jungle (levels 5–8)
  - [ ] Ice Caves (levels 9–12)
  - [ ] Temple (levels 13–15)
  - [ ] Olmec's Lair (level 16)
  - [ ] Black Market
  - [ ] City of Gold
  - [ ] Moai interior
  - [ ] Entrance lobby and tutorial as complete playable spaces

- **Level feelings and variants**
  - [ ] Darkness and light sources [WIP]
  - [ ] Snake Pit [WIP]
  - [ ] Restless Dead / cemetery, including skeletal piranhas
  - [ ] Flooded Cavern / lake
  - [ ] Yeti Kingdom feeling
  - [ ] UFO crash-site feeling
  - [ ] Sacrificial Pit
  - [ ] Stacked feelings and their announcement messages

- **Generation and progression**
  - [ ] Room templates, guaranteed route, entrances, and exits [WIP]
  - [ ] Mines terrain, enemies, traps, treasure, and item placement [WIP]
  - [ ] Mines shops, altars, and idols [WIP]
  - [ ] Hidden entrances to special levels
  - [ ] Mines 1–4 transitions and in-memory run state [WIP]
  - [ ] Tunnel Man and shortcuts
  - [ ] Udjat Eye → Black Market → Ankh → Moai → Hedjet/crown → sceptre → City of Gold route
  - [ ] Olmec encounter and final-level exit

- **Game shell, story, and screens**
  - [ ] Intro cinematic (`rIntro`)
  - [ ] Original main/title screen and playable entrance lobby (`rTitle`), distinct from the prototype menu
  - [ ] Playable tutorial and return to the main screen (`rTutorial`)
  - [ ] Between-area transition scenes and Tunnel Man encounters (`rTransition*`)
  - [ ] Shortcut House and entrances to unlocked rooms
  - [ ] Title-hub score-room entrance and high-score screen (`rHighscores`)
  - [ ] Death, game-over, and retry flow outside the playtest screen
  - [ ] Olmec victory sequence, ending cinematics, and credits (`rEnd*`, `rCredits*`)
  - [ ] All screen transitions, skip behavior, and return paths

- **Settings, saves, and persistent progress**
  - [ ] Original settings integration: fullscreen, graphics quality, down-to-run, gamepad, scale, and music/sound volume (`settings.cfg`)
  - [ ] Keyboard and gamepad binding configuration, including the original config screens (`keys.cfg`, `gamepad.cfg`)
  - [ ] Read and write existing player statistics (`stats.txt`)
  - [ ] Preserve and update existing high scores, records, trophies, and unlocks
  - [ ] Persist Tunnel Man payments and unlocked shortcuts across runs and restarts
  - [ ] Reconcile the original save data with Love's save location without silently discarding or resetting it
  - [ ] In-memory run state for health, money, inventory, and current-level progression [WIP]

- **Terrain and traversal**
  - [ ] Solid and destructible blocks, including material-specific behavior [WIP]
  - [ ] One-way platforms and ladder tops [WIP]
  - [ ] Ladders and deployed ropes [WIP]
  - [ ] Vines
  - [ ] Ledges and hanging surfaces [WIP]
  - [ ] Push blocks, crush interactions, and terrain destruction [WIP]
  - [ ] Falling platforms and blocks outside the Mines
  - [ ] Thin ice and slippery ice surfaces
  - [ ] Foreground tile decorations and correct draw occlusion [WIP]

- **Environment**
  - [ ] Water and submerged movement
  - [ ] Lava and burning
  - [ ] Webs and entanglement [WIP]
  - [ ] Darkness and carried/placed light [WIP]
  - [ ] Pits and the Ice Caves abyss
  - [ ] Flares and boxes of flares as usable light sources

- **Player movement and animation states**
  - [ ] Standing, walking, sprinting, and turning [WIP]
  - [ ] Crouching, crawling, and looking up [WIP]
  - [ ] Jumping, variable-height jump, and falling [WIP]
  - [ ] Ladder and rope climbing; jumping off them [WIP]
  - [ ] Vine climbing
  - [ ] Automatic ledge grab, hanging, and drop [WIP]
  - [x] Jumping from a ledge hang onto the ledge (player-confirmed)
  - [ ] Crouch-to-hang and drop-through platforms [WIP]
  - [ ] Landing, wall pushing, knockback, and bouncing [WIP]
  - [ ] Carrying, dropping, and throwing [WIP]
  - [ ] Whip timing and attack pose [WIP]

- **Player survival and conditions**
  - [ ] Health, healing, and fall damage [WIP]
  - [ ] Stun, recovery, and temporary invulnerability [WIP]
  - [ ] Webbed state [WIP]
  - [ ] Burning state
  - [ ] Death and death animation [WIP]
  - [ ] Spike impalement, crushing, and other instant deaths [WIP]
  - [ ] Ankh resurrection

- **Enemies and bosses**
  - [ ] Snake, bat, spider, giant spider, caveman, skeleton [WIP]
  - [ ] Frog, fire frog, monkey, mantrap, piranha, Megamouth
  - [ ] Zombie / Jiang Shi, vampire, skeletal piranha
  - [ ] Ghost [WIP]
  - [ ] Yeti, alien, UFO
  - [ ] Hawkman, magma man, Tomb Lord / mummy, worshipper
  - [ ] Yeti King, Alien Lord / alien boss, Olmec
  - [ ] Per-enemy AI: idle, patrol, detection, pursuit, attack, and contact [WIP]
  - [ ] Per-enemy damage, stun, carry/throw, death, drops, and animation [WIP]
  - [ ] Ghost spawn timer and pursuit [WIP]

- **NPCs, shops, and services**
  - [ ] Damsel: rescue, damage, carrying, and exit reward [WIP]
  - [ ] Shopkeeper: inventory, buying, anger, theft, and pursuit [WIP]
  - [ ] Tunnel Man as an in-level NPC: dialogue, payments, and shortcuts
  - [ ] General, bomb, weapon, clothing, and specialty shops [WIP]
  - [ ] Dice house / gambling and kissing parlor [WIP]
  - [ ] Black Market artifact stall
  - [ ] Complete shop ownership, pricing, and run-long wanted behavior

- **Carryable objects and containers**
  - [ ] Rock, skull, arrow, and die [WIP]
  - [ ] Pot / jar and its breakable contents [WIP]
  - [ ] Crate and chest [WIP]
  - [ ] Locked chest and key [WIP]
  - [ ] Golden Idol [WIP]
  - [ ] Crystal Skull
  - [ ] Giant Idol
  - [ ] Corpse, piranha skeleton, and detached mattock head as distinct carryables
  - [ ] Lantern as a carryable object
  - [ ] Pickup, carry, release, throw, collisions, and breakage [WIP]
  - [ ] Physics for spawned treasure and container contents [WIP]

- **Weapons, tools, and projectiles**
  - [ ] Whip, bombs, and ropes [WIP]
  - [ ] Bow and arrows [WIP]
  - [ ] Machete and mattock [WIP]
  - [ ] Pistol and shotgun [WIP]
  - [ ] Teleporter and web gun [WIP]
  - [ ] Sceptre and its projectile
  - [ ] Bullets, pellets, webs, explosions, and blast damage [WIP]
  - [ ] Weapon timing, trajectories, recoil, enemy damage, and terrain effects [WIP]

- **Equipment, artifacts, and power-ups**
  - [ ] Spectacles, compass, and parachute [WIP]
  - [ ] Bomb paste, climbing gloves, and pitcher's mitt [WIP]
  - [ ] Cape, jetpack, spike shoes, and spring shoes [WIP]
  - [ ] Udjat Eye [WIP]
  - [ ] Kapala effects [WIP]
  - [ ] Ankh and Hedjet/crown
  - [ ] Acquisition, passive effects, consumption, visual feedback, and interactions [WIP]

- **Treasure and resources**
  - [ ] Gold bars/piles, emeralds, sapphires, and rubies [WIP]
  - [ ] Scarabs and idols as valuables [WIP]
  - [ ] Crystal skulls as valuables
  - [ ] Money and Mines treasure values [WIP]
  - [ ] Area-dependent treasure values beyond the Mines
  - [ ] Health, bomb, and rope supplies [WIP]
  - [ ] Kapala blood collection and health reward [WIP]
  - [ ] Spawn physics, collection, and run persistence [WIP]

- **Traps and hazards**
  - [ ] Spikes and bloody impalement [WIP]
  - [ ] Arrow traps [WIP]
  - [ ] Spear/tiki, spring, smash/crush, and ceiling traps
  - [ ] Boulders and idol-triggered destruction [WIP]
  - [ ] Push blocks and webs [WIP]
  - [ ] Falling platforms, thin ice, lava, and later-area pits
  - [ ] Barrier emitters / forcefields
  - [ ] Rigged chest
  - [ ] Unused Thwomp trap: document source behavior before deciding whether playable coverage is needed
  - [ ] Trigger conditions, warning/animation, collision, damage, and reset behavior [WIP]

- **Structures and interactions**
  - [ ] Ordinary doors and exits [WIP]
  - [ ] Hidden Black Market entrance and Golden Door
  - [ ] Altar placement [WIP]
  - [ ] Sacrifices, Kali favor, rewards, and punishments
  - [ ] Moai and Ankh-triggered resurrection
  - [ ] Idol structures and their traps [WIP]
  - [ ] Lamps, torches, shop signs, and contextual messages [WIP]

- **Cross-system interactions**
  - [ ] Thrown objects versus enemies, traps, terrain, and other objects [WIP]
  - [ ] Enemies and NPCs versus Mines spikes, explosions, and push blocks [WIP]
  - [ ] Enemies and NPCs versus lava and later-area moving terrain
  - [ ] Bombs versus terrain, traps, items, and chain reactions [WIP]
  - [ ] Fire frogs versus terrain, traps, items, and chain reactions
  - [ ] Carried enemies/NPCs versus shops, exits, altars, and hazards [WIP]
  - [ ] Equipment changing movement, combat, or environmental rules [WIP]

- **Presentation and feedback**
  - [ ] Player, enemy, item, and terrain sprites and animation timing [WIP]
  - [ ] Terrain/player/item draw order and occlusion [WIP]
  - [ ] Blood, debris, breakage, and other particles [WIP]
  - [ ] Hit, death, pickup, purchase, discovery, and exit sounds [WIP]
  - [ ] Area music and music changes for special levels or the ghost
  - [ ] HUD, camera, darkness, and level messages [WIP]
  - [ ] Breakage, damage, stun, and impalement feedback [WIP]

- **Controls and interface**
  - [ ] Movement, jump, sprint, duck, look, and climb [WIP]
  - [ ] Attack, pickup, throw, use, bomb, and rope [WIP]
  - [ ] Context-sensitive inputs, including doors, shops, and hanging [WIP]
  - [ ] Menu and playtest-screen controls [WIP]
  - [ ] Complete original-game menus (the prototype menu is not a replacement)

- **Modes, unlocks, and records**
  - [ ] Sun Room survival challenge
  - [ ] Moon Room archery challenge
  - [ ] Stars Room shopkeeper challenge
  - [ ] Changing Room / playable Damsel
  - [ ] Playable Tunnel Man unlock
  - [ ] Level editor and custom-level import/export
  - [ ] High scores, records, and challenge trophies
