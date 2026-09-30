# Spelunky Classic clone

This is a coverage inventory for the original **Spelunky Classic (1.1)**, not a claim that the game is finished. The original source in [`original-game-reference`](original-game-reference/SOURCE_OF_TRUTH.md) is the behavioral authority; the [Classic wiki's places](https://spelunky.fandom.com/wiki/Places_%28Classic%29), [level feelings](https://spelunky.fandom.com/wiki/Level_Feeling_%28Classic%29), [enemies](https://spelunky.fandom.com/wiki/Enemies_%28Classic%29), [items](https://spelunky.fandom.com/wiki/Items_%28Classic%29), [traps](https://spelunky.fandom.com/wiki/Traps_%28Classic%29), and [unlockable rooms](https://spelunky.fandom.com/wiki/Unlockable_rooms) are cross-checks for omissions. HD and Spelunky 2 content is out of scope.

Legend: **☐** not started; **◩** started, but incomplete or not yet validated; **☑** explicitly confirmed by the player in a playtest. Code, assets, and automated tests alone never promote an entry to ☑. A confirmed narrow behavior does not confirm its whole category. Update these markers as playtests and source comparisons establish more.

## Coverage inventory

- **Areas and level types**
  - ◩ Cave / Mines (levels 1–4)
  - ◩ Lush / Jungle (levels 5–8)
  - ◩ Ice Caves (levels 9–12)
  - ◩ Temple (levels 13–15)
  - ◩ Olmec's Lair (level 16)
  - ◩ Black Market
  - ◩ City of Gold
  - ◩ Moai interior
  - ☐ Entrance lobby and tutorial as complete playable spaces

- **Level feelings and variants**
  - ◩ Darkness and light sources
  - ◩ Snake Pit
  - ◩ Restless Dead / cemetery, including skeletal piranhas
  - ◩ Flooded Cavern / lake
  - ◩ Yeti Kingdom feeling
  - ◩ UFO crash-site feeling
  - ◩ Sacrificial Pit
  - ☐ Stacked feelings and their announcement messages

- **Generation and progression**
  - ◩ Room templates, guaranteed route, entrances, and exits
  - ◩ Area-specific terrain, enemies, traps, treasure, and item placement
  - ◩ Shops, altars, idols, and hidden entrances
  - ◩ Level transitions and persistent run state
  - ◩ Tunnel Man and shortcuts
  - ◩ Udjat Eye → Black Market → Ankh → Moai → Hedjet/crown → sceptre → City of Gold route
  - ◩ Olmec encounter and final-level exit

- **Game shell, story, and screens**
  - ☐ Intro cinematic (`rIntro`)
  - ☐ Original main/title screen and playable entrance lobby (`rTitle`), distinct from the prototype menu
  - ☐ Playable tutorial and return to the main screen (`rTutorial`)
  - ☐ Between-area transition scenes and Tunnel Man encounters (`rTransition*`)
  - ☐ Shortcut House and entrances to unlocked rooms
  - ☐ Title-hub score-room entrance and high-score screen (`rHighscores`)
  - ☐ Death, game-over, and retry flow outside the playtest screen
  - ☐ Olmec victory sequence, ending cinematics, and credits (`rEnd*`, `rCredits*`)
  - ☐ All screen transitions, skip behavior, and return paths

- **Settings, saves, and persistent progress**
  - ☐ Original settings integration: fullscreen, graphics quality, down-to-run, gamepad, scale, and music/sound volume (`settings.cfg`)
  - ☐ Keyboard and gamepad binding configuration, including the original config screens (`keys.cfg`, `gamepad.cfg`)
  - ☐ Read and write existing player statistics (`stats.txt`)
  - ☐ Preserve and update existing high scores, records, trophies, and unlocks
  - ☐ Persist Tunnel Man payments and unlocked shortcuts across runs and restarts
  - ☐ Reconcile the original save data with Love's save location without silently discarding or resetting it
  - ◩ In-memory run state for health, money, inventory, and current-level progression

- **Terrain and traversal**
  - ◩ Solid and destructible blocks, including material-specific behavior
  - ◩ One-way platforms and ladder tops
  - ◩ Ladders, vines, and deployed ropes
  - ◩ Ledges and hanging surfaces
  - ◩ Push blocks and falling platforms/blocks
  - ◩ Thin ice and slippery ice surfaces
  - ◩ Moving terrain, crush interactions, and terrain destruction
  - ◩ Foreground tile decorations and correct draw occlusion

- **Environment**
  - ◩ Water and submerged movement
  - ◩ Lava and burning
  - ◩ Webs and entanglement
  - ◩ Darkness and carried/placed light
  - ◩ Pits and the Ice Caves abyss
  - ☐ Flares and boxes of flares as usable light sources

- **Player movement and animation states**
  - ◩ Standing, walking, sprinting, and turning
  - ◩ Crouching, crawling, and looking up
  - ◩ Jumping, variable-height jump, and falling
  - ◩ Ladder, vine, and rope climbing; jumping off them
  - ◩ Automatic ledge grab, hanging, and drop
  - ☑ Jumping from a ledge hang onto the ledge (player-confirmed)
  - ◩ Crouch-to-hang and drop-through platforms
  - ◩ Landing, wall pushing, knockback, and bouncing
  - ◩ Carrying, dropping, and throwing
  - ◩ Whip timing and attack pose

- **Player survival and conditions**
  - ◩ Health, healing, and fall damage
  - ◩ Stun, recovery, and temporary invulnerability
  - ◩ Webbed and burning states
  - ◩ Death and death animation
  - ◩ Spike impalement, crushing, and other instant deaths
  - ◩ Ankh resurrection

- **Enemies and bosses**
  - ◩ Snake, bat, spider, giant spider, caveman, skeleton
  - ◩ Frog, fire frog, monkey, mantrap, piranha, Megamouth
  - ◩ Zombie / Jiang Shi, vampire, skeletal piranha
  - ◩ Yeti, alien, UFO, ghost
  - ◩ Hawkman, magma man, Tomb Lord / mummy, worshipper
  - ◩ Yeti King, Alien Lord / alien boss, Olmec
  - ◩ Per-enemy AI: idle, patrol, detection, pursuit, attack, and contact
  - ◩ Per-enemy damage, stun, carry/throw, death, drops, and animation
  - ◩ Ghost spawn timer and pursuit

- **NPCs, shops, and services**
  - ◩ Damsel: rescue, damage, carrying, and exit reward
  - ◩ Shopkeeper: inventory, buying, anger, theft, and pursuit
  - ◩ Tunnel Man as an in-level NPC: dialogue, payments, and shortcuts
  - ◩ General, bomb, weapon, clothing, and specialty shops
  - ◩ Dice house / gambling and kissing parlor
  - ◩ Black Market artifact stall
  - ☐ Complete shop ownership, pricing, and run-long wanted behavior

- **Carryable objects and containers**
  - ◩ Rock, skull, arrow, and die
  - ◩ Pot / jar and its breakable contents
  - ◩ Crate and chest
  - ◩ Locked chest and key
  - ◩ Golden Idol and Crystal Skull
  - ☐ Giant Idol
  - ☐ Corpse, piranha skeleton, and detached mattock head as distinct carryables
  - ☐ Lantern as a carryable object
  - ◩ Pickup, carry, release, throw, collisions, and breakage
  - ◩ Physics for spawned treasure and container contents

- **Weapons, tools, and projectiles**
  - ◩ Whip, bombs, and ropes
  - ◩ Bow and arrows
  - ◩ Machete and mattock
  - ◩ Pistol and shotgun
  - ◩ Teleporter and web gun
  - ☐ Sceptre and its projectile
  - ◩ Bullets, pellets, webs, explosions, and blast damage
  - ◩ Weapon timing, trajectories, recoil, enemy damage, and terrain effects

- **Equipment, artifacts, and power-ups**
  - ◩ Spectacles, compass, and parachute
  - ◩ Bomb paste, climbing gloves, and pitcher's mitt
  - ◩ Cape, jetpack, spike shoes, and spring shoes
  - ◩ Udjat Eye, Ankh, Hedjet/crown, and Kapala
  - ◩ Acquisition, passive effects, consumption, visual feedback, and interactions

- **Treasure and resources**
  - ◩ Gold bars/piles, emeralds, sapphires, and rubies
  - ◩ Scarabs, idols, and crystal skulls as valuables
  - ◩ Money and area-dependent treasure values
  - ◩ Health, bomb, and rope supplies
  - ◩ Kapala blood collection and health reward
  - ◩ Spawn physics, collection, and run persistence

- **Traps and hazards**
  - ◩ Spikes and bloody impalement
  - ◩ Arrow, spear/tiki, spring, smash/crush, and ceiling traps
  - ◩ Boulders and idol-triggered destruction
  - ◩ Falling platforms, push blocks, thin ice, webs, lava, and pits
  - ◩ Barrier emitters / forcefields
  - ☐ Rigged chest
  - ☐ Unused Thwomp trap: document source behavior before deciding whether playable coverage is needed
  - ◩ Trigger conditions, warning/animation, collision, damage, and reset behavior

- **Structures and interactions**
  - ◩ Ordinary doors and exits
  - ◩ Hidden Black Market entrance and Golden Door
  - ◩ Altar placement
  - ☐ Sacrifices, Kali favor, rewards, and punishments
  - ◩ Moai and Ankh-triggered resurrection
  - ◩ Idol structures and their traps
  - ◩ Lamps, torches, shop signs, and contextual messages

- **Cross-system interactions**
  - ◩ Thrown objects versus enemies, traps, terrain, and other objects
  - ◩ Enemies and NPCs versus spikes, lava, explosions, and moving terrain
  - ◩ Bombs and fire frogs versus terrain, traps, items, and chain reactions
  - ◩ Carried enemies/NPCs versus shops, exits, altars, and hazards
  - ◩ Equipment changing movement, combat, or environmental rules

- **Presentation and feedback**
  - ◩ Player, enemy, item, and terrain sprites and animation timing
  - ◩ Terrain/player/item draw order and occlusion
  - ◩ Blood, debris, breakage, and other particles
  - ◩ Hit, death, pickup, purchase, discovery, and exit sounds
  - ☐ Area music and music changes for special levels or the ghost
  - ◩ HUD, camera, darkness, and level messages
  - ◩ Breakage, damage, stun, and impalement feedback

- **Controls and interface**
  - ◩ Movement, jump, sprint, duck, look, and climb
  - ◩ Attack, pickup, throw, use, bomb, and rope
  - ◩ Context-sensitive inputs, including doors, shops, and hanging
  - ◩ Menu and playtest-screen controls
  - ☐ Complete original-game menus (the prototype menu is not a replacement)

- **Modes, unlocks, and records**
  - ☐ Sun Room survival challenge
  - ☐ Moon Room archery challenge
  - ☐ Stars Room shopkeeper challenge
  - ☐ Changing Room / playable Damsel
  - ☐ Playable Tunnel Man unlock
  - ☐ Level editor and custom-level import/export
  - ☐ High scores, records, and challenge trophies

- **Coverage and diagnosis**
  - ◩ Representative scenarios for movement, combat, items, traps, and generation
  - ◩ Original-source behavior comparisons and regression tests
  - ◩ Visual-screen checks
  - ◩ Automatic playtest logs for investigating player-reported problems
  - ☐ Player-confirmed end-to-end coverage for every category above

The wiki cross-check added several easily missed Classic-specific topics to this list: level feelings and their combinations, flares, the sceptre, rigged chests, the Black Market's shop variants, challenge rooms, and the level editor. Before implementing any of them, verify exact behavior against the original source; the wiki is an inventory aid, not the final specification.
