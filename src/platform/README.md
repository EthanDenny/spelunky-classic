# Platform engine

The controller is derived from the extracted GameMaker 8.0 project scripts in
`Scripts/Platform Engine`, principally `characterCreateEvent.gml`,
`characterStepEvent.gml`, `characterSprite.gml`, `moveTo.gml`, and
`platformCharacterIs.gml`.

It runs fixed 30 Hz simulation steps and retains the original movement scale:

- walk cap: 3 pixels per step
- sprint cap: 6 pixels per step; Shift activates it immediately, while held
  ACTION activates it after 10 non-whipping steps
- gravity: 1 pixel per step squared, capped at 10 pixels per step
- initial ground jump velocity: -4 pixels per step, or -6 with spring shoes
- variable jump window: 10 steps
- ladder acceleration/friction: 0.6
- ladder departure: horizontal velocity set to ±4, then air friction and the
  retained horizontal cap apply; vertical acceleration -4 plus prior gravity
- walk, sprint, air, climbing, and crouching friction models

Implemented states include standing, running, sprinting, looking, crouching,
crawling, variable jumping, falling, ladder/rope climbing, ladder jumping, automatic
ledge grabs, hanging jumps and drops, crouch-to-hang, pushing, and dropping through
one-way platforms. Collision movement is resolved one pixel at a time. Fractional
velocities use the source's global-tick pulses (`time mod round(1 / fraction)`),
rather than accumulating fractional displacement.

The rendered poses and frame sequences are copied unchanged from the original player
sprite resources by `tools/extract_platform_sprites.py`.

## Player physics source audit (2026-10-02)

The behavioral references are `Scripts/Platform Engine/characterStepEvent.gml`,
`moveTo.gml`, the directional scripts in `Scripts/Collision`, and
`Objects/oPlayer1.events/Step.xml` and `Animation End.xml` in the bundled source.
The player regression suite covers these corrections:

- Stunned and dead bodies share gravity, wall/ceiling response, floor/platform
  bounces, and ground friction. Stun counts down from the previous stationary
  stun pose, and held inputs do not manufacture a new press on recovery.
- Stun cancels active whips and weapon slashes. ACTION, held-item use, bomb
  throws, and rope throws are blocked until recovery; an ACTION press consumed
  during stun cannot start a delayed attack. An already armed bow fires once
  when stun forces it out of the player's hands, as in `scrFireBow.gml`.
- Webs apply 0.2 friction after acceleration at the player's origin and clear
  the fall timer. Jumping in a web damages it and applies its escape impulse.
  The playtest no longer applies additional drag after movement.
- Spring shoes increase ground-jump acceleration, with ordinary ladder jumps.
  Whipping blocks entering crouch and jumping from a ladder.
- Cape flight toggles on a rearmed airborne jump press and uses 0.5 vertical
  friction. Jetpacks require a released jump or walking off a ledge to rearm,
  spend one fuel tick per thrust, and refill to 50 on the ground.
- Parachutes deploy after more than 14 descending ticks when there is no solid
  32 pixels below; deployment consumes the pickup and applies vertical friction
  before movement.
- Gloves enter Hanging against a descending wall and use the ordinary hanging
  jump, with a ten-tick drop cooldown. Head-only ladder grabs snap vertically;
  crouch-to-hang can attach directly to an adjacent ladder or rope.
- Movement uses directional collision lines. Horizontal movement excludes the
  top five collider pixels, as `getIdCollisionLeft/Right` does. Push blocks move
  one pixel with each successful player movement pixel and stop with pressure,
  instead of moving an entire tile after a push timer.

The source-based cases were demonstrated to fail on the pre-audit controller.
The full LÖVE smoke suite passes. Existing tests retain the previously measured
original-executable walk, sprint, and held-jump traces. Fresh executable comparison
was unavailable during this audit because the Parallels service could not connect.

This does not establish complete Classic physics parity. Water/ice and vines/trees
remain outside the Mines controller scope. Stuck-arrow
hanging, ball-and-chain movement and the general ground slope adjustment are
implemented with source-based scenarios as of 2026-10-06; their complete
GameMaker runtime equivalence has not been certified.
The world also represents terrain with rectangles rather than every original
precise sprite collision mask. These gaps must stay explicit when adding those
features or claiming executable-level parity.

## Object modules

See the [individual object source audit](../../docs/object-source-audit.md) for the category-by-category comparison of all 96 modules, including inherited behavior, verified constants, corrections and remaining alignment gaps.

Each implemented kind has its own Lua module. Shared systems consume the
capabilities and hooks declared by those modules:

- `items/`: carryables and weapons, such as `shotgun.lua`, `bow.lua`, and `jar.lua`.
- `pickups/`: equipment, supplies, and treasure, such as `compass.lua`,
  `bomb_bag.lua`, and `ruby.lua`.
- `enemies/`: enemy and NPC behavior, including `skeleton.lua` and `damsel.lua`.
- `tiles/`: tile solidity, collision layer, image selection, depth, and moving
  tile behavior. Brick sprite variants belong to `brick.lua`.
- `traps/`: arrow traps, spikes, the idol's tiki head, and boulders.
- `tools/`: bombs, thrown/deployed ropes, and explosions.
- `projectiles/`: bullets, pellets, web balls, and muzzle flashes. The arrow's
  item and projectile behavior share `items/arrow.lua`.
- `structures/` and `environment/`: entrances, exits, altars, signs, lamps,
  bones, and webs. The existing `player.lua` and `fake_bones.lua` are already
  single-object modules.
- `effects/`: per-particle assets, lifetime, animation, and motion traits.

Each category's `types.lua` lists its modules. `item_definitions.lua` combines
items and pickups for the common Item/Treasure APIs. `objects.lua` combines
object registries for terrain entities and render depth lookup; tile lookup
uses `tiles/types.lua` directly. Registration is explicit and works in packaged
LÖVE builds without scanning directories at runtime.

Keep per-kind prices, rewards, loot tables, masks, depths, sprite overrides,
and exceptional behavior in the owning module. Shared movement, carrying,
gun/melee actions, collision handling, and draw submission remain in their
common systems. To add an object, create its module and register it in the
appropriate `types.lua`; add a new shared handler only for behavior that other
objects can also use. The generated original sprite catalog remains extracted
asset metadata, including sprites for unimplemented areas.

## Carryable behavior layers

Mines carryables use small, composable systems rather than an ECS. Each module in
`items/` or `pickups/` declares collision bounds, held offsets, impact and wall
stick rules, first-pickup and collectible rewards, container contents, shop
prices, unlocks, and ACTION behavior. `physical_body.lua` owns pixel-stepped
collision movement and the shared loose-object/web interaction. `holdable.lua`
owns pickup, held position, throwing, and dropping. `item_contents.lua` rolls
Classic crate, jar, and chest contents. `item_actions.lua` dispatches ACTION:
ordinary items throw, containers open with Up, melee weapons wind up and
strike, guns fire, the bow draws then fires on release, and teleporters move
the player. Pistol, shotgun, and web cannon share the gun implementation in
`projectile_system.lua`; shot count, velocity range, recoil, and cooldown live
in their definitions. The shot system draws the source bullet sprite and
ten-frame muzzle flash; bows show their four draw frames and recover slow,
unstuck arrows. Open chests retain their sprite, dice roll before showing a
face, and crate/locked-chest poofs use the source animation. The shared
throw path handles adjacent walls, low ceilings, and pitcher’s-mitt velocity.
`melee_mask.lua` tests hits against each Classic wind-up
and strike sprite's opaque pixels, matching the rendered frame. A first pickup
of a new bow grants six arrows.

The playtest screen coordinates these systems and handles world effects such
as spawning container contents and terrain debris. Treasure and bombs retain
their distinct source-specific bounce and fuse rules but use the shared web
interaction. When adding a carryable, define its traits first and add a new
ACTION handler only if none of the existing behaviors fit.

`item_body.lua` owns the complete loose-body step: terrain motion, per-kind
flight updates, breaking, enemy impacts, and web contact. `Traits.carry()`
includes this behavior automatically; `Traits.body()` supplies it to NPC
bodies and tools without classifying them as ordinary inventory items.
Damage depends on that behavior, not membership in the screen's `items`
collection. Damsels, loose cavemen, corpses, armed bombs, and flying rope ends
share the same impact handler. It excludes the source body, uses its physics
origin, and preserves speed thresholds, arrow consumption, fragile breaking,
paste attachment, and rope hit history through definition properties/hooks.
The shopkeeper retains its custom stunned movement and uses the shared impact
handler directly. Loose treasure keeps its separate `oTreasure` behavior.

The source of truth is `original-game-reference/source/extracted/spelunky/`:
`Objects/Basis/oItem.events/Step.xml` for held offsets and impacts,
`Scripts/Character/scrUseItem.gml` for weapon use, `Objects/oPlayer1.events/Step.xml`
for swing frames and bow release, and each item's Create/Destroy events for
prices, bounds, and contents. The 30 Hz scenario viewer exercises pickup,
put-down, ACTION, melee timing, and break particles for every Mines carryable.

## Enemy behavior layers

`enemies/types.lua` registers one capability module per Mines actor. The
`snake.lua`, `bat.lua`, `spider.lua`, `caveman.lua`, and `skeleton.lua` modules
own their patrol/attack rules, initial state, collision masks where needed,
damage/contact exceptions, and animation choices. `enemy.lua` supplies their
shared 30 Hz body movement, collision, health, player contact, and drawing.

Generated-level actors use the same registry: `ghost.lua`, `shopkeeper.lua`,
`damsel.lua`, and `giant_spider.lua` own their AI and special interactions;
`creature.lua` supplies shared body, stun, held-NPC, and contact plumbing. The
giant-spider module also owns its detailed animation and hopping sequence. Damsel is included as an NPC,
not an enemy that damages the player. Add new per-kind behavior to its module,
and change a shared class only when the rule truly applies across kinds.

## Thrown-object source audit (2026-10-02)

The audit compared Mines carryables, loose treasure and equipment, armed bombs,
flying ropes, and held/thrown damsels against the bundled `oItem`, `oJar`,
`oSkull`, `oDice`, `oTreasure`, `oBomb`, `oRopeThrow`, and `oDamsel` events,
`moveTo.gml`, the directional collision scripts, and `scrUseItem.gml`.

- Loose motion uses the global tick's fractional pixel pulses and GM8 rounding,
  horizontal-then-vertical movement, and directional collision lines. These
  objects pass through player-only platforms and ladder tops.
- Ordinary items respond to contacts after movement, cap falling speed at eight,
  halve wall velocity, separate one pixel, bounce by 0.5 on floors, apply 0.3
  floor friction, and rebound from ceilings by 0.8. Destroyed support releases
  stuck arrows and pasted bombs.
- Jar/skull overrides add gravity before testing break speeds and cancel vertical
  motion at walls. Dice retain their six-pixel gravity condition and stricter
  enemy-hit threshold. Mitt gravity persists for these overrides; ordinary
  parent items reset it to 0.6 after the first flight tick. Down wins simultaneous
  Up/Down throw input. Held positions refresh after the player's movement and
  crouch transition, before ACTION, in both the playtest and item scenarios.
  Gentle crouched placement preserves jars/skulls; a subsequent fall can break them.
- Loose money retains its distinct pre-movement floor/side contacts and stops
  without bouncing. Released equipment and supplies use their `oItem` bounds
  and bounce rules even when not for sale. Web collisions stop motion after Step.
- Enemy contact uses either component's speed and a small origin rectangle.
  Surviving enemies receive part of the object's velocity; the object keeps its
  trajectory. Effective loose-arrow hits consume the arrow, and ordinary bombs
  inherit direct item impacts.
- Damsels use heavy-object held offsets, launch speeds, the four-pixel release
  offset, item bounces/friction, and a 120-tick recovery counter that advances on
  ground/web contact. Flying ropes share item motion and create their first
  segment in the anchoring Step.
- The source Mines rooms run at 30 Hz. Bombs retain 80 fuse ticks plus 40 flashing
  ticks (four seconds), replacing the previous 72-tick fuse. Explosion animation
  lasts 13 ticks at its source 0.8-frame speed. Bomb replays now run long enough
  to show the corrected fuse and blast.

Twenty source cases pass in `platform_item_test.lua`; eighteen fail against the
pre-audit implementation, while two protect existing source-correct behavior.
The full LÖVE smoke suite also passes. This is source-based verification;
fresh original-executable comparison remains unavailable because the Parallels
service could not connect during the player audit.

Remaining parity gaps include offscreen activation, precise sprite masks,
water/lava interactions, corpse and walking-damsel behavior, and full enemy
invulnerability/contact ordering. Bow-fired and trap-fired arrows still have
separate projectile flight/handoff paths and are not covered by this thrown-item
parity claim. The previously requested falling-carryable player hazard remains
an intentional addition to Classic's named arrow/rock contact rules.

## Shopkeeper and purchasing source audit (2026-10-02)

The references are the bundled `oShopkeeper`, `oShopkeeper2`, `oPlayer1`,
`oDamsel`, `oDice`, `oItem`, `oBullet`, and `oSolid` events, plus
`scrShopkeeperAnger.gml`, `scrStealItem.gml`, `isInShop.gml`,
`getKissValue.gml`, `scrShopItemsGen.gml`, and `scrGenerateItem.gml`.
`shop.lua` owns transactions and shop-room ownership, `shop_stock.lua` owns
the source stock rolls, and `enemies/shopkeeper.lua` owns the keeper's states.

- DOWN + ACTION holds unpaid stock; the configured PAY key (P by default)
  purchases it. Weapons remain held; equipment and supplies are consumed once.
  Free equipment and supplies also require pickup, while money collects on touch.
  Failed payment releases the unpaid object without charging or causing theft.
- Standard stock keeps its Create-event price plus ten percent per level after
  level two. Dice display prizes retain their base price. Buying a cape or
  jetpack releases the player's previous back item as free loose equipment.
- Crossing a shop-room boundary with unpaid stock causes theft. Loose stolen
  stock, vandalized shop walls, armed bombs in shops, and mistreatment of shop
  damsels provoke keepers. First theft adds two wanted levels, later incidents
  add three, and exits remove one. Murder stays wanted after theft forgiveness.
- Peaceful keepers follow unpaid stock and ignore ordinary contact. Wanted
  keepers patrol before detecting the player. Attack restores the source
  movement, jump, turn, firing range, thirty-tick cooldown, and recoil rules.
  Their shotgun fires six four-heart bullets; the safe flag protects enemies,
  while damsels and the player remain vulnerable.
- Ordinary whips provoke without health damage. Ordinary thrown items provoke
  without disarming. Stomps and stun-producing hits drop the shotgun; recovery
  counts down on ground contact, and attacking keepers can retrieve a shotgun.
  Contact with headroom throws the player; the first wall/floor impact takes one
  heart. A blocked throw deals an ordinary contact heart instead.
- Kisses cost `10000 + 5000 * (level - 2)`, add a heart, and leave the damsel
  for sale. Buying the held damsel costs three kisses and does not heal.
- PAY places one bet of `1000 + level * 500`. Two genuinely rolled and settled
  dice decide it: below seven loses, above seven pays twice the bet, and seven
  releases the displayed prize and generates one weighted replacement. Rerolling
  an already settled die before the other finishes provokes the keeper.
- Shop stock uses the source's sequential probability rolls and duplicate
  retries rather than uniform item lists. The dice high-end set is shared with
  replacement-prize generation.

All 29 source regression cases in `shop_behaviour_test.lua` were demonstrated
to fail on the saved pre-audit implementation and pass after correction.
The follow-up ownership fixes extend that suite to 33 cases. Four new regressions
failed before repair: whipping a stunned keeper left thrown-item immunity,
thrown merchandise skipped enemy impacts, PAY callbacks and simulation input
disagreed at shop boundaries, and brief PAY events executed outside the tick.
Supplies and equipment now use `Item` definitions and collision handling;
`Treasure` contains only money and gems. Keeper damage reactions own health,
state, stun, and hit impulses. PAY events queue a press consumed once after
movement and theft detection, alongside held-input edges. All 33 cases and the
full LÖVE smoke suite pass after these fixes.
The player-stun follow-up adds two player cases and four shop/gameplay cases,
bringing the shop suite to 37. All six new cases failed before repair and pass
after restoring blocked ACTION/tool input, uninterrupted stun recovery, immediate
whip/slash cancellation on hard landings, and the armed-bow discharge on stun.
The full LÖVE smoke suite passes using a snapshot with an isolated save identity
to avoid concurrent writes to the latest-playtest pointer.
The audit uses source contracts; it does not establish original-executable
or complete Classic parity. Remaining gaps include offscreen activation,
precise sprite masks and event ordering, keeper corpse/crush/held-body behavior,
Black Market/Ankh shops, greeting and kiss animations, and the original delayed
cash-counting presentation. Mines shop transactions and keeper combat have
coverage; these broader gaps must remain explicit.

## Enemy AI and combat

`enemy.lua` ports the first Mines enemy behaviors from the extracted GameMaker
objects and runs them on the same fixed 30 Hz simulation:

- snakes alternate between idle and patrol, reversing at walls and unsupported ledges
- bats hang until a living player passes below within 90 pixels, pursue within 160
  pixels, steer around solid collisions, and return to a ceiling when disengaged
- spiders wait on ceilings, detect a player in the narrow column beneath them, drop,
  recover, and make randomized player-directed hops

The shared contact rules support one-hit enemies, downward stomps and bounce velocity,
side-contact damage, a brief horizontal push without a stun pose, and 30-tick player
invincibility. The Scenario Tests viewer
has a Mines enemy and rope sidebar with automatically repeating scenarios. Its snake page shows
patrol and gap avoidance, player contact, and an idle snake being whipped. Bat scenarios
cover ambush, ceiling return, and a timed whip. Caveman scenarios cover ledge patrol,
an animated charge, and a whip stun with animated recovery. Spider scenarios show
ceiling drops, the full flip animation, hopping, and a whip kill. Giant spider
scenarios show its ceiling flip, jumps, whip-triggered drop, and web shot. Skeleton
scenarios show fake bones awakening, walking over a ledge, and shattering into
bones and a skull. The rope page shows a blocked one-block throw, both corner
offsets, throws with and without a ceiling, the moving rope end striking
snakes and cavemen, a crouched drop beside a ledge, and the 16-segment limit
in a deep shaft. The bomb page shows a wall rebound, paste sticking to and
breaking a wall, a snake caught in the blast, Up and Down throws, and a whip
blocking the throw. Flames rebound from solid surfaces; destroyed bricks and
movable blocks shed rubble, while blasted enemies leave blood or skeleton pieces.
The **Kali Altar** page adds sixteen replays: living/dead damsels, cavemen and
shopkeepers; holding and releasing a body; equipment, Kapala, bomb and vitality
rewards; devouring and forgiveness; spiders, ball/chain and darkness/Ghost
punishments. Each runs the live Mines simulation and rendering, shows favor,
health and Kali's response, and restarts after seven seconds. Space pauses;
R restarts. The sidebar scrolls with the wheel while the pointer is over it and
keeps the selected page visible. Existing item-page numbers are retained.

Scenario sound starts muted and can be enabled with the header button or M key.
Snake deaths emit three blood particles from the sprite center; a whip hit emits
one additional particle, following the original collision and step events.
The live giant spider starts as `oGiantSpiderHang`, then switches to its
32×32 flip, idle, jump, crawl, and web-squirt sprites when triggered; its
visual state is recorded in playtest logs for frame-by-frame diagnosis.

## Shared mechanics without gameplay changes

- `source_math.lua` owns fractional pixel pulses and rounding. Player/item
  movement keeps ties-to-even rounding and its existing tick source; particles
  and boulders keep their existing half-up rounding.
- `actor_body.lua` shares actor bounds, overlap queries, pixel movement, and
  the common stomp response. Enemy/Creature eligibility, remainder resets,
  platforms, jump rearming, damage, and ground responses remain distinct.
- `sprite_mask.lua` caches opaque pixels and intersects masks with rectangles.
  Whip, melee, and object collision keep their own pose/metadata selection;
  rotated object-mask rasterization remains in `sprite_collision.lua`.
- `entity_body.lua` constructs and registers placed and released bodies. It
  retains their different anchors, initial facing, hanging state, seeds, and
  constructor priority; item-only spawning does not require an enemy seed.
- `object_simulation.lua` shares item/treasure update phases, ACTION preparation,
  and whip contact admission. Screens keep their own phase order and response
  callbacks, including the item viewer's existing opened-item filter.
- `body_contact.lua` shares speed gates and contact traversal. Pots, arrows,
  and ordinary item bodies retain their eligibility and damage/destruction
  rules. Bow/trap arrows share loose-arrow construction while keeping their
  different handoff fields and flight paths.

Validation compared deterministic native LÖVE viewer/game traces before and
following these extractions, plus old/new fractional movement and sprite-mask
queries. This refactor deliberately preserves existing differences between
viewers and normal gameplay; source-parity corrections remain separate work.
