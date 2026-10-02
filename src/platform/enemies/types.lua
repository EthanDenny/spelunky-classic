-- The screen chooses Enemy or Creature for placement; these modules own the
-- kind-specific capabilities once an actor has entered the simulation.
return {
    snake = require("src.platform.enemies.snake"),
    bat = require("src.platform.enemies.bat"),
    spider = require("src.platform.enemies.spider"),
    caveman = require("src.platform.enemies.caveman"),
    skeleton = require("src.platform.enemies.skeleton"),
    ghost = require("src.platform.enemies.ghost"),
    giant_spider = require("src.platform.enemies.giant_spider"),
    damsel = require("src.platform.enemies.damsel"),
    shopkeeper = require("src.platform.enemies.shopkeeper"),
}
