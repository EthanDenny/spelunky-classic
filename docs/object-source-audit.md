# Individual object source audit — 2026-10-02

Reviewed against the bundled **Spelunky Classic 1.1** extraction, imported upstream commit `9a9e3e865d489510bbc34e7bb1dc5006c5c3823c`; see [source provenance](../original-game-reference/SOURCE_OF_TRUTH.md). This is a source comparison of the implementation after `2fa3fe4`, including the corrections recorded below. It is **not a declaration of full Classic parity** or verification against the original executable.

The original walkthrough covers **96 individual modules**: 18 items, 26 pickups, 9 enemies, `fake_bones`, 8 tiles, 9 structures, 5 traps, 4 tools, 4 projectiles, 1 environmental object and 11 effects. The existing player controller is reviewed separately below. `types.lua` files and `arrow_trap_behavior.lua` are registry/shared infrastructure, not additional Classic objects. A file per kind does not imply a complete port: much of the behavior is inherited or coordinated elsewhere.

**Historical baseline:** the numbered tables and shared findings below record the initial audit. The [Kali altar follow-up](#kali-altar-follow-up-2026-10-02) and [Mines completion follow-up](#mines-completion-follow-up-2026-10-02) supersede resolved gaps; read those sections for the current implementation. Five further object modules were added in the Mines pass, following the two Kali modules.

## Method and shared findings

1. Identify each source object, sprite, origin, mask and parent. Follow its `*.events/` directory, including inherited events.
2. Trace the module through its live owner: Item, Treasure, Enemy, Creature, World, the tool/projectile systems and the playtest screen. Compare source player events, `scrUseItem`, `scrFireBow`, stock generation and `gameStepEvent` where behavior lives outside the object.
3. Compare creation constants, movement/contact rules, timers, destruction/rewards and draw ordering. Check both generated play and scenario implementations when they differ.
4. Correct the bounded, independently verified bugs below. Add behavioral regressions at existing owners, demonstrate failure on pre-fix code, then run the full smoke suite.
5. Record remaining differences for every module. “Verified” in the tables refers only to the stated details; the neighboring remaining column limits that claim.

Common references used by the tables:

- **D — dynamic draw depth:** current definitions often reproduce the object's XML depth, while source Step events change it. [oItem Step](../original-game-reference/source/extracted/spelunky/Objects/Basis/oItem.events/Step.xml) normally sets loose depth 101, or 51 with spectacles. [oTreasure Step](../original-game-reference/source/extracted/spelunky/Objects/Basis/oTreasure.events/Step.xml) sets 101, or 0 with spectacles/eye. Container XML depth 900 and gold XML depth 100 are therefore not their normal live depths. Jar/skull override their parent Step; not every object receives every parent rule. Held depth 0, or 51 for cape/jetpack climbing, is correct from [player End Step](../original-game-reference/source/extracted/spelunky/Objects/oPlayer1.events/End%20Step.xml).
- **I — inherited item behavior:** supported item physics/throws have existing source regressions, but exact sprite-mask/event ordering, offscreen activation, water/lava and all clean-death effects are incomplete. Damsel sacrifices are now implemented; ordinary loose items have no source sacrifice rule. Equipment pickup flags alone do not prove their player/world effects.
- **C — free supplies:** source [player Step](../original-game-reference/source/extracted/spelunky/Objects/oPlayer1.events/Step.xml) automatically collects unheld, zero-cost, unembedded bomb bags/boxes and rope piles on contact. The clone requires ACTION pickup. Paid stock is separately governed by the shop.
- **T — treasure lifecycle:** Mines values/bounds match the listed source definitions, but the clone delays all released treasure twenty ticks and none of the preplaced treasure. Source collectible alarms are per object. Area value scaling, delayed cash counting, original overlap selection, lava and ghost-to-diamond conversion are incomplete.
- **E — inherited enemy behavior:** [oEnemy](../original-game-reference/source/extracted/spelunky/Objects/Basis/oEnemy.xml) and source object events gate activity by view and have water/lava/spike/sacrifice/held-body rules. Water/lava/spike/view rules remain partial. Mines caveman/shopkeeper sacrifices and held/corpse bodies are now implemented. Enemy uses fractional accumulation; ordinary Creature movement rounds each velocity (held/stunned/corpse bodies use source tick pulses), while source `moveTo` uses global tick pulses. Several clone paths move after gravity where source moves before it. Small Enemy stomps always deal one; Creature stomps omit source fall-distance scaling. Source side contact has no generic stun; specialized source actors override it.
- **S — solid destruction:** [oSolid Destroy](../original-game-reference/source/extracted/spelunky/Objects/Basis/oSolid.events/Destroy.xml) cleans up supported hazards and drops hanging lamps. Clone covers spikes/shop walls/cave lips in selected paths, not all descendants or material-specific debris. Source child events only inherit cleanup where they call `event_inherited`.
- **P — bullet contacts:** [oBullet](../original-game-reference/source/extracted/spelunky/Objects/Effects/oBullet.xml) moves directly and uses GameMaker collision events. Clone uses substeps, point terrain checks and circular actor overlap. Safe-fire/player damage contracts have tests, but original event ordering and masks are not proven.
- **F — visual effects:** source [oDetritus](../original-game-reference/source/extracted/spelunky/Objects/Basis/oDetritus.xml), [oRubblePiece](../original-game-reference/source/extracted/spelunky/Objects/Basis/oRubblePiece.xml) and each effect event are behavioral, not merely sprite references. Clone has explicit lifetime/animation approximations, omits view/lava/water rules in several paths, and submits particles at a shared effect depth.

Source links below point to object metadata; the executable GML is in the adjacent same-name `*.events/` directory. Sprite masks and coordinate conversions were checked where explicitly listed; a matching rectangular bound does not establish exact opaque-pixel collision parity.

## 1. Items

| Module | Classic source | Verified details / repairs | Remaining alignment gaps |
|---|---|---|---|
| [arrow.lua](../src/platform/items/arrow.lua) | [oArrow](../original-game-reference/source/extracted/spelunky/Objects/Items/oArrow.xml) | 4px half-mask, 0.2 initial gravity, wall-stick threshold 6. | Trap arrows hurt players for one heart and enemies for two; source fast-item hits use different rules. Three flight paths (loose, bow, trap) differ in gravity order; D/I. |
| [bow.lua](../src/platform/items/bow.lua) | [oBow](../original-game-reference/source/extracted/spelunky/Objects/Items/oBow.xml) | $1000; first pickup grants six arrows; charge +0.2 to 12; release cooldown 10. | Arrow movement/contact inherits the gaps above; D/I. |
| [chest.lua](../src/platform/items/chest.lua) | [oChest](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oChest.xml) | Heavy; bounds (6,0,8); 1/12 trapped bomb; 3–4 small gems and 1/4 big gem. | D/I; source chest release/animation lifecycle and collision ordering are approximated. |
| [crate.lua](../src/platform/items/crate.lua) | [oCrate](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oCrate.xml) | Heavy; bounds (6,0,8); source player-opening sequential loot odds and fallback. | D/I; tutorial-only bomb-bag contents and source open-object lifecycle are absent. |
| [die.lua](../src/platform/items/die.lua) | [oDice](../original-game-reference/source/extracted/spelunky/Objects/Items/oDice.xml) | Heavy; bounds (6,0,8); held offsets -2/0; settled betting lifecycle. | D/I; fast dice use per-tick random faces in the executable source too. The earlier sprite-cycle mismatch claim was incorrect. |
| [gold_idol.lua](../src/platform/items/gold_idol.lua) | [oGoldIdol](../original-game-reference/source/extracted/spelunky/Objects/Items/oGoldIdol.xml) | Heavy; held offsets 0/2; Mines value $5000; delayed boulder activation. | D/I; conversion happens during next-level generation rather than source exit contact, and the final Mines exit does not convert it; exact altar-floor destruction is incomplete. |
| [jar.lua](../src/platform/items/jar.lua) | [oJar](../original-game-reference/source/extracted/spelunky/Objects/Items/oJar.xml) | Bounds (4,-6,6); wall/ceiling/floor threshold 3; sequential loot odds; source spider/snake spawn origins converted to bottom-center. | I; blocked enemy spawns receive nearby clearance correction; velocity and sprite-mask collisions remain adapted. See the pot follow-up below. |
| [key.lua](../src/platform/items/key.lua) | [oKey](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oKey.xml) | Light carryable; default 4px mask; no base cost; unlocks locked chest. | D/I; unlock detection is a distance check rather than source key/chest collision. |
| [locked_chest.lua](../src/platform/items/locked_chest.lua) | [oLockedChest](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oLockedChest.xml) | Heavy; bounds (6,-2,8); consumes key and releases scattered Udjat Eye. | D/I; collision-trigger geometry and lifecycle are approximated. |
| [machete.lua](../src/platform/items/machete.lua) | [oMachete](../original-game-reference/source/extracted/spelunky/Objects/Items/oMachete.xml) | $7000; two damage; player swing speed 1; cuts webs; damages keepers. | D/I; precise original collision-event order is not reproduced. |
| [mattock.lua](../src/platform/items/mattock.lua) | [oMattock](../original-game-reference/source/extracted/spelunky/Objects/Items/oMattock.xml) | $8000; bounds (4,-6,6); swing speed 0.2; strike speed 0.5; 1/20 break on digging. | D/I; exact terrain probe/destruction geometry differs. |
| [mattock_head.lua](../src/platform/items/mattock_head.lua) | [oMattockHead](../original-game-reference/source/extracted/spelunky/Objects/Items/oMattockHead.xml) | Bounds (6,-4,4); source sprite and origin. | D/I; shares generic item physics and lacks complete source environment events. |
| [pistol.lua](../src/platform/items/pistol.lua) | [oPistol](../original-game-reference/source/extracted/spelunky/Objects/Items/oPistol.xml) | $5000; one four-damage bullet; speed 6–8; recoil 1; cooldown 20. | D/I/P. |
| [rock.lua](../src/platform/items/rock.lua) | [oRock](../original-game-reference/source/extracted/spelunky/Objects/Items/oRock.xml) | Light; 4px mask; ordinary item physics, carry offsets and throws. | D/I; offscreen/environment and collision-order gaps remain. |
| [shotgun.lua](../src/platform/items/shotgun.lua) | [oShotgun](../original-game-reference/source/extracted/spelunky/Objects/Items/oShotgun.xml) | $15000; six four-damage bullets; speed 6–8; random vertical spread; recoil 3; cooldown 40. | D/I/P. |
| [skull.lua](../src/platform/items/skull.lua) | [oSkull](../original-game-reference/source/extracted/spelunky/Objects/Items/oSkull.xml) | 4px mask; held offsets 0/4; wall threshold 2, any upward ceiling hit, floor threshold 3. | I; the separate effects/skull implementation is only a visual approximation of this same source object. |
| [teleporter.lua](../src/platform/items/teleporter.lua) | [oTeleporter](../original-game-reference/source/extracted/spelunky/Objects/Items/oTeleporter.xml) | $10000; 4–8 tiles; horizontal room clamps; at most three upward unsticking steps. Fixed ceiling wrapping to preserve pixel offset. | D/I; telefrag tests use rectangles and actor damage rather than source instance destruction. Duck/firing edge cases need separate source-event parity. |
| [web_cannon.lua](../src/platform/items/web_cannon.lua) | [oWebCannon](../original-game-reference/source/extracted/spelunky/Objects/Items/oWebCannon.xml) | $2000; speed 6–8; recoil 1; cooldown 20; 12px muzzle offset; web-ball gravity 0.2. | D/I; inherits web-ball/web collision and decay gaps. |

## 2. Pickups and treasure

| Module | Classic source | Verified details / repairs | Remaining alignment gaps |
|---|---|---|---|
| [bomb_bag.lua](../src/platform/pickups/bomb_bag.lua) | [oBombBag](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oBombBag.xml) | $2500; +3 bombs; light; bounds (6,-2,6). | D/I/C. |
| [bomb_box.lua](../src/platform/pickups/bomb_box.lua) | [oBombBox](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oBombBox.xml) | $10000; +12 bombs; bounds (6,-2,8). Fixed heavy carry and throw behavior. | D/I/C. |
| [rope_pile.lua](../src/platform/pickups/rope_pile.lua) | [oRopePile](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oRopePile.xml) | $2500; +3 ropes; light; bounds (6,-5,5). | D/I/C. |
| [spectacles.lua](../src/platform/pickups/spectacles.lua) | [oSpectacles](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oSpectacles.xml) | $8000; 6px mask; acquired flag and larger dark-level visibility radius. | D/I; source primarily exposes embedded items through depth; that behavior is absent. |
| [compass.lua](../src/platform/pickups/compass.lua) | [oCompass](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oCompass.xml) | $3000; 6px mask; flag enables source directional compass sprites in HUD. | D/I; HUD placement is the clone viewport adaptation, without original-runtime comparison. |
| [parachute.lua](../src/platform/pickups/parachute.lua) | [oParaPickup](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oParaPickup.xml) | oParaPickup, not deployed oParachute; $2000; 6px mask; triggers after fallTimer >14 and consumes equipment. | D/I; deployed parachute is a player flag rather than the separate source object and collision lifecycle. |
| [paste.lua](../src/platform/pickups/paste.lua) | [oPaste](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oPaste.xml) | $3000; bounds (6,-2,6); acquired flag makes bombs sticky. | D/I; see bomb attachment/chain-explosion gaps. |
| [gloves.lua](../src/platform/pickups/gloves.lua) | [oGloves](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oGloves.xml) | $8000; bounds (6,-6,8); flag enables wall climbing. | D/I; player wall probes and masks still have runtime parity limits. |
| [mitt.lua](../src/platform/pickups/mitt.lua) | [oMitt](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oMitt.xml) | $4000; bounds (6,-6,8); stronger throws and 0.1 thrown-item gravity. | D/I; generic item types reset gravity differently from overriding source objects, handled for the supported paths. |
| [cape.lua](../src/platform/pickups/cape.lua) | [oCapePickup](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oCapePickup.xml) | oCapePickup, not worn oCape; $12000; 6px mask; replaces jetpack; player glide support. | D/I; worn cape is represented by player state rather than a source actor. |
| [jetpack.lua](../src/platform/pickups/jetpack.lua) | [oJetpack](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oJetpack.xml) | $20000; bounds (5,-5,8); replaces cape; fifty fuel ticks. Fixed heavy carry and throws. | D/I; source deletes loose jetpack when player becomes invisible; no matching lifecycle. |
| [spike_shoes.lua](../src/platform/pickups/spike_shoes.lua) | [oSpikeShoes](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oSpikeShoes.xml) | $4000; 6px mask; acquired flag. | D/I/E; small Enemy stomps ignore the flag; Creature stomps use three damage but omit fall-distance scaling. |
| [spring_shoes.lua](../src/platform/pickups/spring_shoes.lua) | [oSpringShoes](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oSpringShoes.xml) | $5000; 6px mask; acquired flag raises player jump strength. | D/I; source-runtime movement parity remains outside this module's constants. |
| [kapala.lua](../src/platform/pickups/kapala.lua) | [oKapala](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oKapala.xml) | Bounds (6,-6,8). Fixed source base cost to $999999. | D/I; health currently comes from eight enemy deaths, whereas source collects blood particles and heals when bloodLevel >8 (nine droplets). |
| [udjat_eye.lua](../src/platform/pickups/udjat_eye.lua) | [oUdjatEye](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oUdjatEye.xml) | Zero base cost; 6px mask; locked-chest reward and acquired flag. | D/I; embedded-treasure exposure and Black Market detection are absent. |
| [gold_chunk.lua](../src/platform/pickups/gold_chunk.lua) | [oGoldChunk](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oGoldChunk.xml) | Mines value $100; bounds (2,-2,2); source four-pixel sprite. | D/T. |
| [gold_nugget.lua](../src/platform/pickups/gold_nugget.lua) | [oGoldNugget](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oGoldNugget.xml) | Mines value $500; bounds (4,-4,4); source eight-pixel sprite. | D/T. |
| [gold_bar.lua](../src/platform/pickups/gold_bar.lua) | [oGoldBar](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oGoldBar.xml) | Mines value $500; bounds (4,-4,4). | D/T. |
| [gold_bars.lua](../src/platform/pickups/gold_bars.lua) | [oGoldBars](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oGoldBars.xml) | Mines value $1000; bounds (7,-8,8). | D/T. |
| [emerald.lua](../src/platform/pickups/emerald.lua) | [oEmerald](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oEmerald.xml) | Mines value $200; bounds (2,-2,2); source four-pixel sprite. | D/T; source starts collectible only after its twenty-tick alarm. |
| [sapphire.lua](../src/platform/pickups/sapphire.lua) | [oSapphire](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oSapphire.xml) | Mines value $400; bounds (2,-2,2); source four-pixel sprite. | D/T; source twenty-tick collectible alarm. |
| [ruby.lua](../src/platform/pickups/ruby.lua) | [oRuby](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oRuby.xml) | Mines value $400; bounds (2,-2,2); source four-pixel sprite. | D/T; source twenty-tick collectible alarm. |
| [emerald_big.lua](../src/platform/pickups/emerald_big.lua) | [oEmeraldBig](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oEmeraldBig.xml) | Mines value $800; default 4px mask. | D/T; source twenty-tick collectible alarm and ghost conversion to diamond are absent. |
| [sapphire_big.lua](../src/platform/pickups/sapphire_big.lua) | [oSapphireBig](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oSapphireBig.xml) | Mines value $1200; default 4px mask. | D/T; source twenty-tick collectible alarm and ghost conversion to diamond are absent. |
| [ruby_big.lua](../src/platform/pickups/ruby_big.lua) | [oRubyBig](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oRubyBig.xml) | Mines value $1600; default 4px mask. | D/T; source twenty-tick collectible alarm and ghost conversion to diamond are absent. |
| [scarab.lua](../src/platform/pickups/scarab.lua) | [oScarab](../original-game-reference/source/extracted/spelunky/Objects/Enemies/oScarab.xml) | Mines value $4000 and source object depth 40. | Substantial mismatch: oScarab is a flying enemy that flees within 64px, launches at speed 4 and slows by 0.5; current implementation is ordinary falling treasure. |

## 3. Enemies and characters

| Module | Classic source | Verified details / repairs | Remaining alignment gaps |
|---|---|---|---|
| [snake.lua](../src/platform/enemies/snake.lua) | [oSnake](../original-game-reference/source/extracted/spelunky/Objects/Enemies/oSnake.xml) | One HP; one-pixel patrol; 20–50 idle rolls; 1/100 stop roll; left/right support probes. | E; initial timer 15 and zero initial velocity differ from source counter 0 and xVel 2.5; update order differs. |
| [bat.lua](../src/platform/enemies/bat.lua) | [oBat](../original-game-reference/source/extracted/spelunky/Objects/Enemies/oBat.xml) | Hanging/attack states; one HP; 90px activation and 160px pursuit; one-pixel normalized pursuit; mask (6,-14,-2). | E; obstacle steering, ceiling probes and view activation differ. |
| [spider.lua](../src/platform/enemies/spider.lua) | [oSpiderHang](../original-game-reference/source/extracted/spelunky/Objects/Enemies/oSpiderHang.xml), [oSpider](../original-game-reference/source/extracted/spelunky/Objects/Enemies/oSpider.xml) | Hanging and active source objects; gravity 0.2; 5–20 recovery rolls; speed 2.5 jumps. | E; ceiling probe, drop geometry, alarm timing and physics order differ. |
| [caveman.lua](../src/platform/enemies/caveman.lua) | [oCaveman](../original-game-reference/source/extracted/spelunky/Objects/Enemies/oCaveman.xml) | Three HP; Enemy scenario path includes idle/walk/charge/stun; 200-tick ordinary stun and 20-tick bullet stun in both paths; generated held/corpse bodies and 2/1 favor sacrifices. | E; generated play uses a separate simplified Creature path at speed 1.1, missing source 1.5 walk/3 charge and sight projectile. |
| [skeleton.lua](../src/platform/enemies/skeleton.lua) | [oSkeleton](../original-game-reference/source/extracted/spelunky/Objects/Enemies/oSkeleton.xml) | One HP; twenty-tick idle; one-pixel walking; permits walking over ledges; source skeleton sprites. | E; generated facing does not initialize toward the player; raise/update/contact behavior differs across Enemy and Creature paths. |
| [ghost.lua](../src/platform/enemies/ghost.lua) | [oGhost](../original-game-reference/source/extracted/spelunky/Objects/Enemies/oGhost.xml) | Mask (4,0,12,16) converted to clone coordinates; damage immunity. Fixed one-pixel normalized pursuit through walls at any distance, player invincibility, and contact from above. | Source turn/disappear animations, invisible-player death, dropped weapon, bone/skull death effects and HUD suppression remain absent. |
| [giant_spider.lua](../src/platform/enemies/giant_spider.lua) | [oGiantSpiderHang](../original-game-reference/source/extracted/spelunky/Objects/Enemies/oGiantSpiderHang.xml), [oGiantSpider](../original-game-reference/source/extracted/spelunky/Objects/Enemies/oGiantSpider.xml) | Hanging ten HP; masks change on drop; 32px sprites; gravity 0.3; jump speed 2.5; 100–1000 web timer; two-heart active contact. | E; missing ten-tick whip/item immunity and randomized 1–3 big-gem drops; hanging embed death, animation/state ordering and stomp scaling differ. |
| [damsel.lua](../src/platform/enemies/damsel.lua) | [oDamsel](../original-game-reference/source/extracted/spelunky/Objects/Characters/oDamsel.xml) | Four HP; heavy carry; source held offsets; 120-tick thrown/damaged recovery; sale/kiss transactions; carryable corpses; source eight-favor sacrifices. | I; idle/yell/run/exit states are simplified, free damsels drift at 0.35; damage reactions and exact source animation/event ordering remain partial. |
| [shopkeeper.lua](../src/platform/enemies/shopkeeper.lua) | [oShopkeeper](../original-game-reference/source/extracted/spelunky/Objects/Characters/oShopkeeper.xml) | Twenty HP; six four-damage bullets; thirty-tick fire cooldown; source follow/patrol/attack/throw/stun rules and whip immunity implemented; held/corpse bodies and 12/6 favor sacrifices. | E; crush lifecycle and environmental inherited events remain partial; greeting/kiss animations and broader Classic shops are incomplete. |

## 3a. Fake bones

| Module | Classic source | Verified details / repairs | Remaining alignment gaps |
|---|---|---|---|
| [fake_bones.lua](../src/platform/fake_bones.lua) | [oFakeBones](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oFakeBones.xml) | oFakeBones 64px horizontal/8px vertical trigger, gravity 0.2, six-frame rise followed by skeleton creation. | Source view activation is absent; spawned skeleton then inherits the skeleton gaps. Source uses animation-end events rather than an explicit frame counter. |

## 3b. Existing player controller

| Module | Classic source | Verified details | Remaining alignment gaps |
|---|---|---|---|
| [player.lua](../src/platform/player.lua) | [oPlayer1](../original-game-reference/source/extracted/spelunky/Objects/oPlayer1.xml), platform engine scripts | Fixed 30Hz controller; source movement/state/jump/climb/stun contracts are covered by the [existing player audit](../src/platform/README.md#player-physics-source-audit-2026-10-02); parachute trigger, jetpack fuel, cape/jetpack held depth and source spikes rectangle were cross-checked in this walkthrough. | Precise masks/general slopes, swimming/water/lava, specialized source animation/event ordering and the equipment/world interaction gaps listed above remain partial. Passing controller tests does not certify those features. |

## 4. Tiles

| Module | Classic source | Verified details / repairs | Remaining alignment gaps |
|---|---|---|---|
| [empty.lua](../src/platform/tiles/empty.lua) | No instance (synthetic) | Represents absence of a source instance; no collision or image. | Synthetic representation, so there is no Classic object to certify. |
| [brick.lua](../src/platform/tiles/brick.lua) | [oBrick](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oBrick.xml) | oBrick style dispatch, depth 100 and solidity; generator uses matching alternate/gold/hidden-gem odds. | S; gold-brick destruction does not release three chunks (plus nugget for large gold); buried-item choice is restricted to four kinds instead of nineteen source choices. |
| [solid.lua](../src/platform/tiles/solid.lua) | [oSolid](../original-game-reference/source/extracted/spelunky/Objects/Basis/oSolid.xml) | Shared oSolid collision layer, depth 100, style dispatch. | Synthetic wrapper over several materials; S, particularly support cleanup for hanging lamps. |
| [block.lua](../src/platform/tiles/block.lua) | [oBlock](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oBlock.xml) | oBlock sprite, depth 110 and solidity. | S; destruction uses generic rubble, missing lush material and City of Gold gold contents (later area unsupported). |
| [smooth_brick.lua](../src/platform/tiles/smooth_brick.lua) | [oBrickSmooth](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oBrickSmooth.xml) | oBrickSmooth sprite, depth 110 and solidity. | S; missing tan rubble selection and complete inherited cleanup. |
| [ladder.lua](../src/platform/tiles/ladder.lua) | [oLadderOrange](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oLadderOrange.xml), [oLadder](../original-game-reference/source/extracted/spelunky/Objects/Basis/oLadder.xml) | oLadderOrange sprite/depth 1000 and oLadder climbable basis; source room L cells. | Player climbing is adapted to grid queries rather than precise source instance masks; no original-runtime parity claim. |
| [ladder_top.lua](../src/platform/tiles/ladder_top.lua) | [oLadderTop](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oLadderTop.xml) | oLadderTop depth 1000; source platform basis; player one-way landing/climbing layer. | Exact platform mask and engine collision-order parity are not established. |
| [push_block.lua](../src/platform/tiles/push_block.lua) | [oPushBlock](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oPushBlock.xml) | 16px bounds, solidity, one-pixel player pushing. Fixed inherited 0.6 gravity, upward-rounded travel and eight-pixel cap from gameStepEvent. | S; lava sinking/recursive stack drop, offscreen activation and material rubble remain absent. |

## 5. Structures

| Module | Classic source | Verified details / repairs | Remaining alignment gaps |
|---|---|---|---|
| [entrance.lua](../src/platform/structures/entrance.lua) | [oEntrance](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oEntrance.xml) | Source sprite and depth 9000. | Visual behavior aligns in Mines; level-editor leadsTo labels/custom-level routing are outside implemented scope. |
| [exit.lua](../src/platform/structures/exit.lua) | [oExit](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oExit.xml) | Source sprite and depth 9000; exit used for progression. | Source collision_point detection replaced by a near rectangle; exit animations/delayed transitions and automatic held-object handling differ. |
| [kali_head.lua](../src/platform/structures/kali_head.lua) | [oKaliHead](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oKaliHead.xml) | Source three variants and depth 997; one-tick alarm opens the hole and launches six spiders with source velocities and thump. | Spawned spiders retain the inherited movement/event-order gaps listed above. |
| [bones.lua](../src/platform/structures/bones.lua) | [oBones](../original-game-reference/source/extracted/spelunky/Objects/Collectibles/oBones.xml) | Source sprite and depth 900; inert bones do not awaken. | Source gravity 0.2 and one-pixel support correction are absent; current entity is static. |
| [lamp.lua](../src/platform/structures/lamp.lua) | [oLamp](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oLamp.xml) | Source sprite and depth 201; contributes to dark-level lighting. | Source image_speed 0.5 flicker and falling oLampItem on support destruction are absent. |
| [sacrifice_altar.lua](../src/platform/structures/sacrifice_altar.lua) | [oSacAltarLeft](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oSacAltarLeft.xml), [oSacAltarRight](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oSacAltarRight.xml) | Two solid cells at depth 110; either-half support collapse; twenty-tick sacrifice countdown; favor/gifts; one defilement penalty of -16 and global altar removal; escalating spiders, ball/chain, darkness/ghost; tan debris. | Collapse uses grid support/viewport tests rather than original sprite masks; general particle lifetime/ordering remains approximate. See the Kali follow-up below. |
| [altar_left.lua](../src/platform/structures/altar_left.lua) | [oAltarLeft](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oAltarLeft.xml) | Source sprite, solid cell, depth 110. | S; tan rubble destruction event missing. |
| [altar_right.lua](../src/platform/structures/altar_right.lua) | [oAltarRight](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oAltarRight.xml) | Source sprite, solid cell, depth 110. | S; tan rubble destruction event missing. |
| [shop_sign.lua](../src/platform/structures/shop_sign.lua) | [oSign](../original-game-reference/source/extracted/spelunky/Objects/Blocks/oSign.xml) | oSign depth 110, solid cell and per-shop sign sprites. | S; tan rubble destruction event missing; broader shop styles are not implemented. |

## 6. Traps

| Module | Classic source | Verified details / repairs | Remaining alignment gaps |
|---|---|---|---|
| [arrow_trap_left.lua](../src/platform/traps/arrow_trap_left.lua) | [oArrowTrapLeft](../original-game-reference/source/extracted/spelunky/Objects/Traps/oArrowTrapLeft.xml) | Depth 110; fires at (x-2,y+4) with xVel -8; fires once. | Beam is checked live with a 0.05 movement threshold and 96px rectangle, versus source rounded oArrowTrapTest geometry and any nonzero velocity; crouch-to-hang trigger and unfired destruction arrow are missing. |
| [arrow_trap_right.lua](../src/platform/traps/arrow_trap_right.lua) | [oArrowTrapRight](../original-game-reference/source/extracted/spelunky/Objects/Traps/oArrowTrapRight.xml) | Depth 110; fires at (x+18,y+4) with xVel 8; fires once. | Same detection gaps as left; source right beam has its own obstacle-distance/minimum-width rounding; destruction arrow missing. |
| [giant_tiki_head.lua](../src/platform/traps/giant_tiki_head.lua) | [oGiantTikiHead](../original-game-reference/source/extracted/spelunky/Objects/Traps/oGiantTikiHead.xml) | Depth 997; idol activation arms 100-tick delay, replaces head with hole and spawns boulder at source anchor. | Nearest-head activation and altar-floor clearing need full source trigger parity; source activation is coordinated by player/item events. |
| [boulder.lua](../src/platform/traps/boulder.lua) | [oBoulder](../original-game-reference/source/extracted/spelunky/Objects/Traps/oBoulder.xml) | Bounds (-14,-16,14,16); depth 200; double movement; gravity 0.6; bounce 0.3; friction 0.99; first roll 4.5; boundary/ledge rules. | S; approximate enemy overlap, terrain debris and explosion-destroys-boulder behavior remain incomplete. |
| [spikes.lua](../src/platform/traps/spikes.lua) | [oSpikes](../original-game-reference/source/extracted/spelunky/Objects/Traps/oSpikes.xml) | Depth 120; player rectangle (x±4,y-4…y+8), downward velocity, fallTimer >4 or stunned, lethal bloody contact. | Source enemy impalement (yVel >2), corpse lodging and complete source effects/collision ordering are absent. |

## 7. Tools

| Module | Classic source | Verified details / repairs | Remaining alignment gaps |
|---|---|---|---|
| [bomb.lua](../src/platform/tools/bomb.lua) | [oBomb](../original-game-reference/source/extracted/spelunky/Objects/Items/oBomb.xml) | 4px mask; eighty slow fuse ticks then forty fast ticks; source armed/sticky depths 49/1; shared bounce and paste support. | I; source chain blast fuse 4–8 ticks, complete enemy-link cleanup and explosion collisions are missing. |
| [rope_throw.lua](../src/platform/tools/rope_throw.lua) | [oRopeThrow](../original-game-reference/source/extracted/spelunky/Objects/Items/oRopeThrow.xml) | Source moving rope end depth 100; flight/deployment delegated to tools/rope.lua. | Split is a thin definition; source end is destroyed after deployment, whereas clone retains rope controller; inherits rope gaps. |
| [rope.lua](../src/platform/tools/rope.lua) | [oRope](../original-game-reference/source/extracted/spelunky/Objects/Items/oRope.xml), [oRopeTop](../original-game-reference/source/extracted/spelunky/Objects/Items/oRopeTop.xml) | oRope/oRopeTop depth 200; 8px growth up to sixteen segments; horizontal snapping and apex deployment; flying-end impacts. | Source lava burning/detachment is missing; blocked down placement returns nil instead of source fallback moving throw; exact segment collision differs. |
| [explosion.lua](../src/platform/tools/explosion.lua) | [oExplosion](../original-game-reference/source/extracted/spelunky/Objects/Effects/oExplosion.xml) | Depth 1; source ten-frame animation at 0.8; 30 enemy damage and terrain blast. | Substantial mismatch: age-zero proximity damage replaces ongoing sprite collisions; source damsel damage 100, item breakage, directional additive impulses, chain bombs, web removal and boulder rubble/destruction are absent. |

## 8. Projectiles

| Module | Classic source | Verified details / repairs | Remaining alignment gaps |
|---|---|---|---|
| [bullet.lua](../src/platform/projectiles/bullet.lua) | [oBullet](../original-game-reference/source/extracted/spelunky/Objects/Effects/oBullet.xml) | Source sprite/depth 0; gun paths pass four damage; safe flag protects enemies, not player/damsel; persistent until terrain/outside world. | P; source damsel -6 vertical/120-tick thrown impulse differs; the executable oEnemy collision does not check enemy invincibility; actor-specific handling needs comparison; source sprite collisions are replaced by swept circles/points. |
| [pellet.lua](../src/platform/projectiles/pellet.lua) | [oBullet](../original-game-reference/source/extracted/spelunky/Objects/Effects/oBullet.xml) | Reuses oBullet image/depth. | Synthetic projectile alias with finite sixty-tick life and generic impacts; source shotgun creates six oBullet instances. Live shotgun correctly uses bullet, not this alias. |
| [muzzle_flash.lua](../src/platform/projectiles/muzzle_flash.lua) | [oShotgunBlastLeft](../original-game-reference/source/extracted/spelunky/Objects/Effects/oShotgunBlastLeft.xml), [oShotgunBlastRight](../original-game-reference/source/extracted/spelunky/Objects/Effects/oShotgunBlastRight.xml) | oShotgunBlastLeft/Right ten frames, depth 0; shot system advances at source 0.8 speed. | Verified narrow visual animation/offset contract; original engine animation-end cleanup is represented by age removal. |
| [web_ball.lua](../src/platform/projectiles/web_ball.lua) | [oWebBall](../original-game-reference/source/extracted/spelunky/Objects/Effects/oWebBall.xml) | oWebBall depth 1; direct motion before 0.2 gravity; 20–100 lifetime; collision creation animation; giant-spider exemption. | Created webs are left dying=false, unlike source animation end dying=true; exact sprite masks, view/room lifecycle and some actor collisions remain approximated. |

## 9. Environmental objects

| Module | Classic source | Verified details / repairs | Remaining alignment gaps |
|---|---|---|---|
| [web.lua](../src/platform/environment/web.lua) | [oWeb](../original-game-reference/source/extracted/spelunky/Objects/Effects/oWeb.xml) | Source depth 200; initial life 12; dying decrement 0.02; drawn alpha life/12; x/y placement from web-ball center minus eight. | Web-ball-created webs never start dying; item/treasure/spider handling partly shared, but water destruction, rubble stopping and keeper anger are incomplete. |

## 10. Effects

| Module | Classic source | Verified details / repairs | Remaining alignment gaps |
|---|---|---|---|
| [blood.lua](../src/platform/effects/blood.lua) | [oBlood](../original-game-reference/source/extracted/spelunky/Objects/Effects/oBlood.xml) | oBlood/oDetritus bounds ±4, life 60, random gravity 0.1–0.6, bounce, four-tick trails, floor life 20 and speed >6 death. | F; no five-tick collectible blood state or player Kapala collision; animation and exact population/view limits differ. |
| [blood_trail.lua](../src/platform/effects/blood_trail.lua) | [oBloodTrail](../original-game-reference/source/extracted/spelunky/Objects/Effects/oBloodTrail.xml) | Source seven frames and 0.8 trail-frame progression when emitted by blood. | F; direct Effects:add path has different lifetime/gravity from trail-list path; full source animation-end behavior is not established. |
| [bone.lua](../src/platform/effects/bone.lua) | [oBone](../original-game-reference/source/extracted/spelunky/Objects/Effects/oBone.xml) | oBone/oDetritus life 60, random gravity 0.1–0.6, bounce, smoke on floor. | F; random source creation velocities are supplied by callers only; dying smoke actor and original population limits are approximated. |
| [skull.lua](../src/platform/effects/skull.lua) | [oSkull](../original-game-reference/source/extracted/spelunky/Objects/Items/oSkull.xml) | Uses oSkull sprite and fragile-impact/floor-friction approximation for skeleton death effects. | Duplicate visual-only implementation of items/skull.lua: artificial 120-tick lifetime, detritus six-speed cap, no carry or break fragments; not source-equivalent. |
| [flame.lua](../src/platform/effects/flame.lua) | [oFlame](../original-game-reference/source/extracted/spelunky/Objects/Effects/oFlame.xml) | Source random gravity, bounce and two-tick flame trails; smoke on death. | F; source starts with inherited life 60 and floor cap 20; clone starts at 30 and caps floor remaining life at 12; water behavior missing. |
| [flame_trail.lua](../src/platform/effects/flame_trail.lua) | [oFlameTrail](../original-game-reference/source/extracted/spelunky/Objects/Effects/oFlameTrail.xml) | Source five-frame sprite; 0.7 progression and no gravity. | F; approximate fixed eight-tick lifecycle; original animation-end behavior/runtime not compared. |
| [smoke.lua](../src/platform/effects/smoke.lua) | [oSmokePuff](../original-game-reference/source/extracted/spelunky/Objects/Effects/oSmokePuff.xml) | Source eight-frame sSmokePuff at 0.4 speed (twenty ticks). | Confirmed mismatch: source rises steadily 0.1px per tick; clone starts -0.1 then adds +0.1 gravity and falls after its first ticks. |
| [poof.lua](../src/platform/effects/poof.lua) | [oPoof](../original-game-reference/source/extracted/spelunky/Objects/Effects/oPoof.xml) | Source six-frame sprite at 0.4; fifteen-tick visual life and supplied horizontal motion. | F; resetVertical forces supplied vertical motion to zero, unlike source x+=xVel/y+=yVel; current crate/unlock callers use zero vertical speed. |
| [teleport_spark.lua](../src/platform/effects/teleport_spark.lua) | [oFlareSpark](../original-game-reference/source/extracted/spelunky/Objects/Effects/oFlareSpark.xml) | oFlareSpark five-frame sprite at 0.4; initial yVel -0.1. | Confirmed mismatch: source steady -0.1 movement and terrain-contact death; clone adds gravity 0.1 and omits terrain destruction; effect depth 1 differs from source 150. |
| [rubble.lua](../src/platform/effects/rubble.lua) | [oRubbleSmall](../original-game-reference/source/extracted/spelunky/Objects/Effects/oRubbleSmall.xml) | oRubbleSmall/oRubblePiece sprite; direct movement; gravity 0.6; destroyed at terrain point. | F; artificial forty-five-tick life; material colors, water slowing and source view-based lifetime absent. |
| [rubble_large.lua](../src/platform/effects/rubble_large.lua) | [oRubble](../original-game-reference/source/extracted/spelunky/Objects/Effects/oRubble.xml) | oRubble/oRubblePiece sprite; direct movement; gravity 0.6; destroyed at terrain point. | F; same artificial lifetime/material/environment gaps as small rubble. |

## Repairs and validation

Changed six individual modules:

- `pickups/bomb_box.lua` and `pickups/jetpack.lua`: restore source heavy carry positions and heavy throw velocities, without changing other supply/equipment kinds.
- `pickups/kapala.lua`: restore its $999999 source base price.
- `items/teleporter.lua`: replace a pixel clamp with source whole-tile ceiling wrapping.
- `enemies/ghost.lua`: target the source mask center, move one normalized pixel through terrain at any distance, preserve player invincibility, bypass generic stomp handling, and restore source HP 1 while retaining damage immunity. Death animation/lifecycle remains partial.
- `tiles/push_block.lua`: inherit gravity 0.6 and cap 8 from `oMoveableSolid`/`gameStepEvent`, with source upward rounding of positive travel. The apparent gravity 1 assignment in `gameStepEvent` is commented out and is not executable behavior.

Extended the existing primary behavior owners with five regression groups, rather than inventories or source-string assertions:

| Regression owner | Independent source contract | Pre-fix result |
|---|---|---|
| `platform_item_test.lua` | Bomb boxes/jetpacks sit at heavy offsets and launch with heavy velocities | Fails: bomb box sits at light standing offset |
| `platform_item_test.lua` | Near-ceiling upward teleport preserves pixel offset | Fails: player y22 clamps to y16 |
| `platform_item_test.lua` | Near/distant ghost pursuit crosses solids at normalized speed 1 | Fails: ghost remains at its starting position |
| `platform_item_test.lua` | Protected falling contact neither kills nor bounces; unprotected contact from above kills | Fails: contact enters generic stomp path |
| `dynamic_world_test.lua` | Unsupported block advances 1,2,2px, then reaches an 8px terminal speed | Fails: block advances 1,2,3px |

The existing full smoke suite passed before the changes. The four item/ghost regression groups failed together against an isolated pre-fix snapshot; the push-block regression failed in an isolated pre-fix dynamic-terrain runner. After repairs, **`love . --smoke-test` passes**, including the new regressions and existing item, enemy, shop, terrain, rendering, generation and screen checks. **`git diff --check` passes.** No new production test hooks or source-reference files were introduced or modified. Kapala's price is a directly checked source constant; no redundant definition-inventory test was added.

## Batches identified by the initial audit

1. Restore destruction consequences: gold-brick contents, material rubble, lamp support, unfired trap arrows and explosion object interactions.
2. Correct supply collection and treasure alarms/dynamic depths; implement actual Kapala blood collection and scarab flight.
3. Consolidate generated Enemy/Creature behavior so cavemen and skeletons behave consistently, then restore source movement/contact/event order and actor-specific immunity.
4. Extend actor/environment source parity beyond the implemented Mines Kali interaction (see follow-up below).
5. Correct web decay and particle motion/lifetimes; finish ghost death/turn animations and source exit transitions.

These were the next implementation batches at the initial audit. The Mines completion follow-up below records their subsequent repairs and remaining parity limits.


## Kali altar follow-up (2026-10-02)

Implemented [kali.lua](../src/platform/kali.lua) against `oEnemy` and `oDamsel` sacrifice steps, `scrGetFavorMsg`, `oSacAltarLeft/Right`, `oKaliHead`, `oBall`, `oChain`, `characterStepEvent`, `scrUseItem`, and `oLevel` creation. The owning object modules retain actor favor values, altar support/destruction, head alarms, and ball/chain movement and sprites.

- A stationary, unheld stunned body/corpse is consumed on its twenty-first eligible tick. Moving or holding resets the twenty-tick countdown. Either half of the altar accepts a body. Normal items and healthy enemies are excluded.
- Cavemen contribute 2 living / 1 dead; shopkeepers 12 / 6. Damsels contribute 8 in both cases: the source's live bonus checks status 98, but its thrown status is 2. Severe anger (favor <= -8) consumes without credit; lesser anger permits recovery.
- Gifts follow the source's ordered branches: unowned equipment at 8, Kapala at 16, 99 bombs at 32 when bombs <80, otherwise 4–8 vitality. Repeated vitality begins at 48, then advances by 16 favor. Jumping thresholds skips lower gifts. Equipment gifts are free world pickups and use the cyclic ownership scan with jetpack/bomb-box fallbacks.
- Breaking either altar cell or its support removes every altar in the level and applies one -16 penalty. The first punishment arms every head for six spiders; the second attaches a carryable iron ball with four chain links; later punishments darken the level and summon a ghost immediately, or trigger spiders when darkness and a ghost already exist.
- The ball restrains horizontal travel/jump/fall movement and follows source dragging rules. Teleporting moves it with the player. Exits retain favor/gifts/punishment and reattach the ball without duplicating a carried ball. Heavy items and corpses are dropped on exit; living damsels enter their rescue animation. The previous carried-corpse persistence claim was incorrect. New runs reset the state.

| New object module | Classic source | Implemented behavior |
|---|---|---|
| [ball.lua](../src/platform/items/ball.lua) | [oBall](../original-game-reference/source/extracted/spelunky/Objects/Items/oBall.xml) | Heavy carryable item, bounds ±5, initial gravity 1 followed by inherited 0.6, drag/vertical tether rules, depth 99 and source sprite origin (8,10). Player restraint follows `characterStepEvent`. |
| [chain.lua](../src/platform/environment/chain.lua) | [oChain](../original-game-reference/source/extracted/spelunky/Objects/Items/oChain.xml) | Four links interpolate by linkVal/4 between player and ball; depth 1; source sprite; disappears if the ball is absent. |

The [Kali integration tests](../src/tests/kali_altar_test.lua) exercise live simulation ticks, ACTION carrying/dropping, actual bomb destruction, support collapse, ownership/reward branches, anger recovery, punishment escalation, real level transitions, teleportation, and source sprite rendering. All ten scenario groups failed for the expected missing behaviors against an isolated pre-change snapshot and pass with the implementation. The full `love . --smoke-test` suite and `git diff --check` pass.

This completes the Mines altar interaction. The subsequent Mines pass replaces the Kapala death-count approximation with mature blood-droplet collection and updates inherited actor/environment behavior as recorded below.


## Mines completion follow-up (2026-10-02)

Implemented the outstanding functional Mines batches against executable object events and `characterStepEvent`, `oPlayer1` Step/End Step, `oTransition`, `oLevel`, `scrGenerateItem`, and `scrUseItem`. Per-object properties and reactions remain in their individual modules; shared movement, destruction, lighting, and run bookkeeping live with their owners.

| Batch | Current behavior | Source anchors |
|---|---|---|
| Supplies and cash | Free bomb bags/boxes and ropes collect on player contact; paid stock remains a shop transaction. Gold collects immediately; small/big gems and diamonds wait twenty ticks. Cash counts after the delay and flushes on exit. Hidden terrain contents use the source nineteen-choice selection. | `oPlayer1`, collectible Create/Alarm events, `scrGenerateItem`, `oTransition` |
| Blood and rewards | Kapala heals after nine droplets mature for five ticks and overlap the player, with a heart effect and kiss sound. Hits emit blood; actor-specific death rewards include carryable skeleton skulls and giant-spider paste plus one to three big gems. Health can exceed its starting maximum. | `oBlood`, `oEnemy`, `oDamsel`, `oSkeleton`, `oGiantSpider` |
| Treasure movement and visibility | Scarabs flee in horizontal/angled bursts without treasure gravity. Spectacles expose buried items and treasure through depth; Udjat Eye exposes treasure. Live inherited item/treasure depths replace static XML depths where appropriate. | `oScarab`, `oItem`, `oTreasure` |
| Destruction | Gold bricks release chunks and nuggets; supported lamps become carryable lamps where the source child inherits that cleanup. Terrain and dynamic blocks emit material-specific rubble once. Unfired traps release arrows even when destroyed without a blast. | `oSolid` and child Destroy events, `oBrick`, `oLamp`, arrow traps |
| Blasts, arrows and ropes | Explosions collide throughout their animation, damage players/enemies/damsels, break fragile items, remove webs, shorten nearby bomb fuses, and destroy boulders into rubble and possible rocks. Ordinary items receive additive directional impulses. Bomb attachment follows corpses until pickup. Arrow movement precedes gravity; trap beams accept any nonzero motion and use the source asymmetric rounding. Blocked downward ropes fall back to an upward throw. | `oExplosion`, `oBomb`, `oArrow`, `oArrowTrapTest`, rope creation |
| Actors and hazards | Generated cavemen/skeletons share their kind's AI; cavemen walk and charge at source speeds. Shared movement uses global tick pulses before gravity. Fall distance and spike shoes affect stomps. Falling enemies impale and lodge without kill credit; embedded actors die. Damsels wait/yell, run after thrown recovery, and rescue at the door independently of the player. | `moveTo`, `oEnemy`, `oCaveman`, `oSkeleton`, `oDamsel`, `oSpikes` |
| Ghost | Timed haunting starts after 150 seconds beyond the first depth, at the viewport edge. Pursuit turns use source sprites. Contact hides the player, drops equipment and creates skull/bones; the ghost disappears through its animation. Big gems convert into delayed $5000 diamonds; small gems do not. | `oLevel`, `oGhost`, big-gem collisions |
| Darkness and effects | Darkness follows distance to lamps, carried/fallen lamps, flares and explosions. Smoke/sparks rise steadily; poofs preserve supplied vertical motion. Burning wisps, hearts, flame lifetime, rubble material/view/terrain cleanup and individual effect depths are implemented. Web-ball-created webs begin their source decay. | `oPlayer1` darkness calculation, effect events, `oWeb`, `oWebBall` |
| Exits | Door point contact cashes held idols and rescues living damsels. Grounded, unstunned players enter a 32-tick exit animation while the world continues. Heavy items, corpses and armed bombs stay behind; lightweight items and Kali state persist. Rescue healing happens during transition. The final Mines exit finishes the animation before completion; R starts a new run. | `oExit`, `oPlayer1`, `oDamsel`, `oTransition`, `oLevel` |

New individual object modules:

| Module | Classic source | Role |
|---|---|---|
| [diamond.lua](../src/platform/pickups/diamond.lua) | `oDiamond` | $5000 ghost-converted treasure, twenty-tick collection alarm |
| [lamp_item.lua](../src/platform/items/lamp_item.lua) | `oLampItem` | Heavy carryable light released from supported lamps |
| [flare.lua](../src/platform/items/flare.lua) | `oFlare` | Carryable light with periodic source sparks |
| [heart.lua](../src/platform/effects/heart.lua) | `oHeart` (sprite `sSmoochHeart`) | Thirty-tick rising healing effect |
| [burn.lua](../src/platform/effects/burn.lua) | `oBurn` | Animated rising burning wisps with terrain cleanup |

The original source comments out both the F flare action and initial dark-level flare creation. The flare object is supported when spawned; no active player flare action was invented. Spectacles affect buried-object depth, not a larger circular darkness radius. Scarabs are not light sources. Bullets ignore ordinary enemy invincibility in the source, but rescuing damsels let bullets pass through. The source dice really do choose random faces on fast ticks.

The [Mines completion tests](../src/tests/mines_completion_test.lua) cover 21 behavior scenarios through real owners and simulation ticks. All 21 fail against an isolated pre-change checkout for the missing behaviors or systems and pass after implementation. Existing supply, rope, explosion, web, loot, and Kali transition tests were updated where the source disproved their old expectations. The live [render-order regression](../src/tests/render_depth_test.lua) exercises actual flare/lamp/diamond/ghost/effect submissions, spectacles occlusion and player exit rendering. The full `love . --smoke-test` suite and `git diff --check` pass.

This implements the identified functional Mines gaps. It does not certify exact GameMaker opaque-pixel masks, collision/event ordering, equal-depth ties, or every animation against the original executable. Small-enemy obstacle steering and fine movement/state timing remain adaptations. The standalone Enemy AI screen retains a visual-only skeleton-skull fallback; generated Mines use the carryable item. Water/lava, tutorial rules and later-area scaling/gameplay remain outside the Mines scope.


## Accuracy recheck after Mines completion (2026-10-02)

Rechecked the per-object split, initial repairs, Kali implementation and Mines completion (`2fa3fe4` through `d9b976a`) against the bundled extracted source. The tables above record earlier snapshots; this section supersedes their overlapping claims. The reference authority remains [SOURCE_OF_TRUTH.md](../original-game-reference/SOURCE_OF_TRUTH.md). This is a source-event review with executable clone regressions, not an original-executable parity certification.

The review follows object inheritance as well as child events: XML metadata alone does not describe live depth, Destroy inheritance, alarms, or collision behavior. Native GameMaker action events were also checked where the extracted GML is empty. Coordinate assertions below translate source sprite origins to the clone's body anchors.

### Confirmed discrepancies repaired

| Owner / behavior | Correction | Independent source anchor |
|---|---|---|
| Enemy activity and Kali | Use the source top-left anchor and asymmetric viewport margins; giant spiders use their own margins. Enemy sacrifice countdowns pause outside their Step region. Damsel sacrifice processing remains outside its movement gate. Exit animation continues before the movement gate. | `oEnemy`, `oGiantSpider`, `oDamsel` Step |
| Treasure/item alarms | Gem collection delays and flare alarms continue just outside the movement region. Item-specific cleanup runs before movement gating. This does not implement GameMaker's entire instance activation system. | `oTreasure` Alarm 0/Step, `oFlare` Alarm 0, `oJetpack` Step, `oLevel` activation region |
| Trap sensing | Ghosts are excluded because `oGhost` is not an `oEnemy` child. Late crouch-to-hang sensing reads the player's actual animation frame. | `oArrowTrapTest` Step |
| Explosions and held actors | Retain held damsels/enemies through explosion collisions. Only the source `oItem` collision releases the held item. The previous held-NPC release implementation and test expectation were incorrect. | `oExplosion` collisions with `oDamsel`, `oEnemy`, `oItem` |
| Giant spider hits | Active conversion starts a ten-tick hit cooldown. Thrown items and front whips respect it; back whips retain inherited damage. Front hits apply one damage. | `oGiantSpider` Create/Step, Collision with `oWhip`, inherited `oWhipPre` |
| Caveman immunity | A machete does not bypass stunned immunity. Bullet/explosion exceptions remain. | `oCaveman` whip collisions, `oBullet`, `oExplosion` |
| Stomps | Reset fall accumulation. Cavemen/shopkeepers use a -6 bounce; ordinary enemies and giant spiders use -6 minus 0.2 times incoming vertical speed. | `oEnemy`, `oCaveman`, `oGiantSpider` character collisions |
| Skeletons | Face the player on generated and dynamic creation unless an explicit facing is provided. Drop the carryable skull at the source center, without the Ghost-only vertical offset. | `oSkeleton` Create/Step; `oGhost` character collision |
| Giant spider drops | Paste, gems and death blood use the same source position, with the hanging-to-active sprite-height conversion. | `oGiantSpider` Step death branch |
| Ghost drop direction | Turning changes the sprite without rewriting the source's RIGHT facing field; contact therefore retains the rightward equipment impulse. | `oGhost` Create/Step/character collision |
| Lighting | Use static lamps' source origins; select the nearest explosion before applying its animation-dependent distance adjustment. | `oPlayer1` Step darkness calculation |
| Particle cleanup and distribution | Detritus uses a four-pixel viewport margin; rubble uses thirty-two. Flare sparks and burning wisps do not inherit that viewport deletion. Rubble positions use two random draws' difference. | `oDetritus`, `oRubblePiece`, `oFlareSpark`, `oBurn`, solid Destroy events |
| Kapala effects | Each consumed droplet produces a BloodSpark in addition to the nine-droplet healing heart. Added the individual [blood_spark.lua](../src/platform/effects/blood_spark.lua) object with source sprite, depth 1, speed 0.5 and steady random upward velocity. | `oPlayer1` blood collision, `oBloodSpark`, `oDrawnSprite` |
| Flare/lamp metadata | Static previews use flare depth 30 and lamp-item depth 100; live inherited item depths still apply. Flare sparks use the source offset distribution and two-tick alarm. | `oFlare` XML/Create/Alarm 0, `oLampItem` XML, `oItem` Step |
| Scarab inheritance | Scarabs remain money pickups in their individual module and now participate in whips, weapons, thrown-item/projectile/trap and explosion targets. Collection emits three sparks; death adds three downward sparks. Bloodless hits emit no blood. | `oScarab` Create/Step/Destroy/character collision, inherited `oEnemy` collisions, `scrCreateBlood` |

### Checked without changing the source-backed contract

Kali sacrifice values, the twenty-first eligible tick, gift branch order and thresholds, ownership scan, anger recovery, punishment escalation, ball/chain rules, teleport attachment and exit persistence align with the inspected events/scripts. The Damsel living/dead credit quirk remains intentional. Held actor depths 0/51 are correct because player End Step overrides enemy Step. Supplies, cash delays, hidden-item selection, rope fallback, bomb attachment, timed Ghost spawning, gem conversion and exit transition branches retain their checked contracts. Player flare actions and initial dark-level flare creation remain commented out in the source. The correct healing object name is `oHeart`; `sSmoochHeart` is its sprite.

### Remaining source differences and limits

| Area | Remaining difference / verification limit |
|---|---|
| Enemy AI | Fine Step ordering and state timing remain adapted. For example, snakes start with a different timer/velocity; caveman sight uses an immediate ray rather than an `oEnemySight` actor. Small-enemy steering, stunned movement and giant-spider state/animation timing are not exact source implementations. |
| Dark Mines generation | `MinesVariants.apply` performs post-generation placement with its own random stream. Source `scrEntityGen` chooses giant spider/lamp/scarab/bat/spider during placement, with different branch order and start-room/bottom restrictions. Exact spawn distributions and seed parity are not established. |
| Solid Destroy inheritance | `World:remove` still applies shop-wall, spike and cave-lip cleanup broadly. Source children such as blocks, push blocks, altar halves, signs and arrow traps override Destroy without inheriting all `oSolid` consequences; explosions separately remove unsupported spikes/lips. Lamp drops already respect child inheritance. Direct non-explosion destruction therefore still needs an inheritance-aware cleanup pass. |
| Lamp animation | Static lamp rendering still omits the source's flicker at image speed 0.5. |
| Engine lifecycle | Pixel masks, collision/Step/End Step ordering, equal-depth ties, population caps, global instance activation and every native animation alarm remain unverified against the original executable. Offscreen alarm repairs cover the inspected active-region case, not universal deactivation parity. Scarab Destroy's use of `other` also leaves exact runtime spark positions unverified. |
| Scope | The initial table's unresolved details not explicitly superseded here remain open, including visual-only skull fallback behavior and non-Mines environments. Functional coverage does not establish complete source equivalence. |

### Validation

The full `love . --smoke-test` suite passes, including **31 Mines completion scenarios**, **11 Kali scenarios**, and the live render-order check for BloodSpark over terrain. Against an isolated `d9b976a` snapshot, the updated Mines test owner fails **15 scenario groups** for the intended discrepancies, and the new Kali offscreen-sacrifice case fails independently. The remaining cases preserve already implemented behavior. The snapshot uses the original implementation and assets without adding test-only production seams. `git diff --check` passes.

Separate Udjat progression and held-item placement work in this shared checkout is preserved and excluded from this audit's commit.

## Pot enemy placement regression (2026-10-03)

The [oJar Destroy event](../original-game-reference/source/extracted/spelunky/Objects/Items/oJar.events/Destroy.xml) creates active spiders at `x-8, y-8`, and snakes at that origin with an eight-pixel shift away from side impacts. The clone now converts both to bottom-center coordinates. Spiders previously missed the vertical conversion and the clearance handling already applied to snakes.

When the enemy's larger collision body overlaps terrain, both kinds now search nearby free space, preferring the impact's outward direction. This bounded clearance correction is a clone adaptation rather than an exact GameMaker collision-event reproduction. Unobstructed spawn coordinates retain the source conversion.

The pot cases in [playtest_feedback_test.lua](../src/tests/playtest_feedback_test.lua) now exercise the actual impact and reward from the same pot. Earlier cases incorrectly reused its coordinates after destruction had moved it offscreen. The corrected regression failed on a spider overlapping the right wall before the fix. Both enemy kinds now pass left/right wall, ceiling, floor, corner and dynamic push-block impacts, with 45 movement ticks checking survival and clearance. A real whip hit verifies the unobstructed source position; the ceiling-gem case also uses the actual impact. The full Love smoke suite passes.


### Gameplay message follow-up (2026-10-03)

Compared the live gameplay notices against `scrStealItem`, saleable Create events,
`oShopkeeper.Step`, `scrShopkeeperAnger`, `oPlayer1` alarms, `scrInitLevel`,
`oGame.Step`, and the normal/dark message draw events. Pickup and sale text now
belongs to each individual object module. All 22 pickup-message definitions and
22 sale templates were checked against the extracted source.

- Removed prototype cash, container, locked-chest, mattock-break, purchase,
  exit, death, and Mines-completion notices, and the bottom-right Full game level label.
- Restored exact item, shop, dice, kissing, anger, and Kali wording and line breaks.
  Shop instructions use the configured Pay key. Keeper greetings use the original
  32-name pool and happen once on entering the room.
- Restored the ten-tick Mines feeling alarm and dark-level follow-up 210 ticks later.
  The ghost warning reads “A CHILL RUNS UP YOUR SPINE...” / “LET'S GET OUT OF HERE!”
  after two minutes on 1-2 or later; the ghost's later arrival adds no notice.
- A new notice replaces the previous notice instead of queuing it. Source durations
  run on the clone's 30 Hz simulation clock, including exit/death animation ticks,
  so rendering at 60 Hz does not halve their lifetime. Level changes clear notices.
- Full game, Full Level Playtest, and Kali replay cards share the original
  `sFontSmall` sprites: eight-pixel character spacing, centered white/yellow lines,
  y=216/224 in the 320×240 camera, no panel or wrapping. Larger lab viewports adapt
  the center and bottom offsets. Lab controls and scenario event labels remain lab UI.
- The current Mines-only Full game returns to the menu after its fourth exit;
  no invented victory message substitutes for the unimplemented Jungle transition.

Validation: the new supply-message regression failed against the pre-fix code;
source-text, replacement/expiry, ghost/feeling timing, locked/pot silence, shop
transactions/greetings, and damsel-devouring checks pass. The rendering check
compares the entire 320×240 camera against independently positioned original
font sprites, detecting wrong placement, colour, font, or added backgrounds.


### Jump input and ledge support follow-up (2026-10-03)

The source reads held/pressed/released inputs first, probes collisions, changes
unsupported ground states to `FALLING`, then evaluates ground jumping, and finally
moves the player. The clone follows this order. Source references:
`characterStepEvent` lines 38–40, 243–265 and 339–374, `platformCharacterIs`,
`isCollisionBottom`, `calculateCollisionBounds`, and the three `checkJump` scripts.

The ledge checks agree with the source's rounded inclusive collision line:
10-pixel walking and 16-pixel running masks, including the last supporting pixel
and the first unsupported position on both sides of a ledge. Running fixtures
reach the wider mask through ordinary player movement. Existing tests retain
Classic's variable jump height, initial -4 velocity and five-step 18-pixel rise.

The input adapter previously sampled only held keys on each 30 Hz tick. It lost a
complete tap, or a release/repress of an already held key, between ticks. App key
callbacks now preserve jump press/release flags separately from held state and
consume them exactly once on the next simulation tick. Tool-direction snapshots
do not consume those flags. Menu changes, simulation rebuilds, and focus loss
clear pending flags. Gameplay eligibility remains governed by the existing player
rules; an ineligible press is consumed rather than saved for landing.

Regression evidence: the real App-callback short-tap test fails before the input
fix and passes afterward. Coverage exercises catch-up ticks, airborne cape presses,
repeat suppression, remapping, menu/reset/focus cleanup and the Full game loop in
exclusive fullscreen. The Full game fixture first lets the generated entrance
spawn settle naturally; its initial spawn is not necessarily supported.

This verifies the clone's callback delivery and the source's collision/state
contracts. Sub-tick keyboard handling by the original GameMaker 8 executable has
not been measured; these checks do not claim timing parity with that runner.

## Arrow trap sensor and flight audit (2026-10-04)

The active detection path is `oArrowTrapLeft/Right` Alarm 1 plus
`oArrowTrapTest` collision events. The line sensors in the traps' Step events
are commented out. The sensor uses `sRed`, a precise 16×16 sprite whose opaque
rows are 1 through 14. Its horizontal scale and anchor retain the original
asymmetric obstacle rounding, maximum reach and cached geometry.

Detection now uses the bundled sprite XML and image alpha masks rather than
movement bounds. Masks retain frame changes, character mirroring, rectangular
versus precise shapes, and arrow rotation. Characters, items (including flying
rope ends and damsels), treasure, enemies (including moving corpses), push blocks
and boulders can trigger. Bullets, pellets, web balls and ghosts lack the relevant
source inheritance and cannot trigger. Any nonzero x/y velocity qualifies; the
late crouch-to-hang exception remains. Extending rope ends explicitly have zero
velocities in `oRopeThrow` Step; their positional extension and fixed `oRope`
segments do not qualify as moving sensor targets.

The level checks sensors after body updates, with the same target set during exit.
Collision-created arrows wait until the next movement tick. Trap arrows share
`oItem` movement quantization, initial 0.2 gravity followed by 0.6, activity bounds,
wall rebounds and web stops. A terrain handoff retains velocity, gravity, angle
and the unsafe state. Fast unsafe arrows use the source player's inclusive x/y
±8 rectangle, deal two hearts, transfer x velocity, stun for 20 ticks, and emit
three blood particles. That source check has no enemy-contact immunity gate;
loose arrows use the same player-hit owner.

Regressions exercise both trap directions, empty sensor edge rows, crouching,
precise rock corners, animation frames and mirroring, rotated arrow pixels,
source inheritance, cached obstacle widths, single firing, real upward rope
crossings during play and exit, stationary rope extension, quantized arrow
flight, offscreen pause, arrow damage and rebound handoff. The old implementation
fails the sensor-edge, projectile-class, rope-timing, flight and hit regressions.
Verification uses extracted source and sprite assets plus the native LÖVE smoke
suite. GameMaker 8 runner timing and arbitrary-angle mask rasterization have not
been measured against the original executable. Bow projectile flight and its
handoff remain a separate implementation outside this trap audit.

### Opened chests and pot contact follow-up

- The player pickup filter now admits opened `oChest` equivalents. Opening
  changes the source chest sprite; it does not remove its pickup capability.
  Up + ACTION throws an already opened held chest and cannot roll more loot.
- `oJar` overrides the parent item Step. Its own enemy contact rectangle is
  x/y ±3, with either velocity component strictly above two. The pot is
  destroyed even against an invulnerable, stunned, or dead target. Cavemen and
  shopkeepers receive a stun rather than health damage; an existing stun keeps
  its counter and vertical motion. Damsels lose one HP, are released from the
  player's hands, and enter their 120-tick thrown state.
- Pot throw velocities, low-ceiling correction, mitt modifiers, and terrain
  smash thresholds were checked against `scrUseItem`, `oJar.Step`, `moveTo`,
  and the collision scripts. Terrain contact uses post-gravity velocity and a
  strict threshold of three, so gentle drops and slow collisions can bounce.
- Regression scenarios exercise actual ACTION input for chest pickup/throw,
  pot wall throws and gentle drops, plus pot contact against live/stunned/dead
  cavemen, a ghost, a spider, and a stunned damsel. Creature contact geometry
  still uses the clone's movement rectangles rather than GameMaker sprite
  bounds/nearest-instance selection; this follow-up does not claim exact
  GameMaker event ordering or collision rasterization.

## Full game level intermissions (2026-10-04)

Full game now enters the Mines transition room after the 32-tick exit animation,
before generating the next level. The lab retains its immediate advance.
The room uses `rTransition1` placements and bundled sprites, the original small
font and completion text, `oTransition`'s TIME/LOOT/KILLS/MONEY layout, counter
order, 30-tick time reveals, three-tick icon tally, and 100-per-tick money count.
ACTION or ESC (the source keyboard START input) hastens an unfinished tally; a
fresh press after completion continues. Key repeats do not continue. Music and
the live world/run clock remain stopped throughout the intermission.

Successful money pickups, idol delivery and counted deaths feed per-level
summary counters. Loot money is gross collection, independent of shopping costs.
The dummy walks two pixels per tick, pauses for a rescued damsel's kiss, then
enters the far door. `oDamselKiss.Room End` awards one heart on continuation,
including a skip before the kiss. Run resources, equipment and carried items
persist; summary counters reset for the next level.

Coverage extends the existing Full game lifecycle test through the actual App
keyboard callbacks and live gameplay collection/death/exit paths. The missing
intermission assertion failed before implementation. Native smoke tests and a
rendered 320x240 intermission passed afterward.

Scope is the four playable Mines levels: the final summary returns to the menu.
Jungle generation and boundary Tunnel Man donations remain unimplemented.
The room's source brick surfaces are retained; randomized cave fringe decoration
and dummy cape/jetpack/ball-chain accessory rendering are not reproduced here.
