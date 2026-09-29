#!/usr/bin/env python3
"""Copy static preview frames and origins for generated Spelunky entities."""

from __future__ import annotations

import shutil
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "original-game-reference/source/extracted/spelunky"
DESTINATION = ROOT / "assets/original/entities"
LUA_OUTPUT = ROOT / "src/world/original_entity_sprites.lua"

OBJECTS = {
    "player": "oPlayer1", "shopkeeper": "oShopkeeper", "chest": "oChest",
    "tunnel_man": "oTunnelMan",
    "crate": "oCrate", "damsel": "oDamsel", "bat": "oBat",
    "spider": "oSpiderHang", "giant_spider": "oGiantSpiderHang", "snake": "oSnake",
    "caveman": "oCaveman", "mantrap": "oManTrap", "frog": "oFrog",
    "fire_frog": "oFireFrog", "zombie": "oZombie", "vampire": "oVampire",
    "monkey": "oMonkey", "piranha": "oPiranha", "dead_fish": "oDeadFish",
    "ufo": "oUFO", "yeti": "oYeti", "scarab": "oScarab", "hawkman": "oHawkman",
    "tomb_lord": "oTombLord", "alien_boss": "oAlienBoss", "jaws": "oJaws",
    "alien": "oAlien", "ghost": "oGhost", "magma_man": "oMagmaMan",
    "yeti_king": "oYetiKing",
    "arrow_trap_left": "oArrowTrapLeft", "arrow_trap_right": "oArrowTrapRight",
    "spear_trap_top": "oSpearTrapTop", "spear_trap_bottom": "oSpearTrapBottom",
    "spring_trap": "oSpringTrap", "smash_trap": "oSmashTrap",
    "trap_block": "oTrapBlock", "ceiling_trap": "oCeilingTrap", "door": "oDoor",
    "rock": "oRock", "jar": "oJar", "web": "oWeb", "bones": "oBones",
    "skeleton": "oBones", "skull": "oSkull", "gold_bar": "oGoldBar",
    "gold_bars": "oGoldBars", "emerald_big": "oEmeraldBig",
    "sapphire_big": "oSapphireBig", "ruby_big": "oRubyBig", "grave": "oGrave",
    "gold_door": "oGoldDoor", "mattock": "oMattock", "shotgun": "oShotgun",
    "jetpack": "oJetpack", "bomb_box": "oBombBox", "bomb_bag": "oBombBag",
    "rope_pile": "oRopePile", "parachute": "oParaPickup", "compass": "oCompass",
    "pistol": "oPistol", "machete": "oMachete", "bow": "oBow",
    "gloves": "oGloves", "spectacles": "oSpectacles", "paste": "oPaste",
    "spring_shoes": "oSpringShoes", "spike_shoes": "oSpikeShoes", "cape": "oCapePickup",
    "teleporter": "oTeleporter", "web_cannon": "oWebCannon", "mitt": "oMitt",
    "shop_sign": "oSign", "die": "oDice", "crystal_skull": "oCrystalSkull",
    "tree": "oTree", "moai": "oMoai", "barrier_emitter": "oBarrierEmitter",
    "entrance": "oEntrance", "exit": "oExit", "spikes": "oSpikes",
    "gold_idol": "oGoldIdol", "altar_left": "oAltarLeft", "altar_right": "oAltarRight",
    "sac_altar_left": "oSacAltarLeft", "sac_altar_right": "oSacAltarRight",
    "giant_tiki_head": "oGiantTikiHead",
    "olmec": "oOlmec",
    "lamp": "oLamp", "lamp_red": "oLampRed", "fake_bones": "oFakeBones",
    "thwomp_trap": "oThwompTrap",
    "locked_chest": "oLockedChest", "key": "oKey", "crown": "oCrown",
    "ankh": "oAnkh", "kapala": "oKapala", "udjat_eye": "oUdjatEye",
    "moai2": "oMoai2", "moai3": "oMoai3", "moai_inside": "oMoaiInside",
}

DIRECT_SPRITES = {
    "shop_sign_general": "sSignGeneral", "shop_sign_bomb": "sSignBomb",
    "shop_sign_weapon": "sSignWeapon", "shop_sign_rare": "sSignRare",
    "shop_sign_clothing": "sSignClothing", "shop_sign_craps": "sSignCraps",
    "shop_sign_kissing": "sSignKissing", "alien_structure": "sAlienFloor",
}

DIRECT_BACKGROUNDS = {
    "lady_xoc": "bgLadyXoc",
}


def one_match(pattern: str) -> Path:
    matches = list(SOURCE.glob(pattern))
    if len(matches) != 1:
        raise RuntimeError(f"Expected one match for {pattern}, found {len(matches)}")
    return matches[0]


def sprite_for_object(object_name: str) -> str:
    object_path = one_match(f"Objects/**/{object_name}.xml")
    sprite = ET.parse(object_path).getroot().findtext("sprite")
    if not sprite or sprite == "-1":
        raise RuntimeError(f"{object_name} has no default sprite")
    return sprite


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    return struct.unpack(">II", header[16:24])


def lua_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main() -> None:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    sprite_names = {key: sprite_for_object(name) for key, name in OBJECTS.items()}
    sprite_names.update(DIRECT_SPRITES)
    records = {}

    for key, sprite_name in sorted(sprite_names.items()):
        image_path = one_match(f"Sprites/**/{sprite_name}.images/image 0.png")
        sprite_path = one_match(f"Sprites/**/{sprite_name}.xml")
        sprite_root = ET.parse(sprite_path).getroot()
        origin = sprite_root.find("origin")
        origin_x = int(origin.attrib["x"])
        origin_y = int(origin.attrib["y"])
        width, height = png_size(image_path)
        destination = DESTINATION / f"{key}.png"
        shutil.copyfile(image_path, destination)
        records[key] = (origin_x, origin_y, width, height, sprite_name)

    for key, background_name in DIRECT_BACKGROUNDS.items():
        image_path = one_match(f"Backgrounds/{background_name}.png")
        width, height = png_size(image_path)
        shutil.copyfile(image_path, DESTINATION / f"{key}.png")
        records[key] = (0, 0, width, height, background_name)

    lines = [
        "-- Generated by tools/extract_original_entity_sprites.py; do not edit by hand.",
        "return {",
    ]
    for key, (origin_x, origin_y, width, height, sprite_name) in sorted(records.items()):
        lines.append(
            f"    [{lua_quote(key)}] = {{ image = {lua_quote(key)}, originX = {origin_x}, "
            f"originY = {origin_y}, width = {width}, height = {height}, "
            f"sourceSprite = {lua_quote(sprite_name)} }},"
        )
    lines.append("}")
    LUA_OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
