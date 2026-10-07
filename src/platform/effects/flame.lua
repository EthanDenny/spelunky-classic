return { path = "original-game-reference/source/extracted/spelunky/Sprites/Effects/sFlame.images/image 0.png", origin = 4,
    life = 60,
    motion = "flame",
    initialVx = function(random) return random:random()*4-random:random()*4 end,
    initialVy = function(random) return -1-random:random()*2 end,
    randomGravity = true,
    smokeOnDeath = true,
}
