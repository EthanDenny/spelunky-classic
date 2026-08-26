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
side-contact damage, knockback, and 30-tick player invincibility. The Enemy AI screen
adds the original 11-frame player attack animation and front/back whip hit windows,
plus optional sensor and collision visualization.
