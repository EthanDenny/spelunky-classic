# Platform engine

The prototype controller is derived from the extracted GameMaker 8.1 scripts in
`Scripts/Platform Engine`, principally `characterCreateEvent.gml`,
`characterStepEvent.gml`, `characterSprite.gml`, `moveTo.gml`, and
`platformCharacterIs.gml`.

It runs fixed 30 Hz simulation steps and retains the original movement scale:

- walk cap: 3 pixels per step
- sprint cap: 6 pixels per step after 10 held steps
- gravity: 1 pixel per step squared, capped at 10 pixels per step
- initial jump velocity: -4 pixels per step
- variable jump window: 10 steps
- ladder acceleration/friction: 0.6
- ladder jump velocity: 4 horizontally and -4 vertically
- walk, sprint, air, climbing, and crouching friction models

Implemented states include standing, running, sprinting, looking, crouching,
crawling, variable jumping, falling, ladder/rope climbing, ladder jumping, automatic
ledge grabs, hanging jumps and drops, crouch-to-hang, pushing, and dropping through
one-way platforms. Collision movement is resolved one pixel at a time.

The rendered poses and frame sequences are copied unchanged from the original player
sprite resources by `tools/extract_platform_sprites.py`.

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
Scenario sound starts muted and can be enabled with the header button or M key.
Snake deaths emit three blood particles from the sprite center; a whip hit emits
one additional particle, following the original collision and step events.
The live giant spider starts as `oGiantSpiderHang`, then switches to its
32×32 flip, idle, jump, crawl, and web-squirt sprites when triggered; its
visual state is recorded in playtest logs for frame-by-frame diagnosis.
