#!/usr/bin/env python3
"""Build the animation-viewer catalog from the extracted GameMaker 8.1 project."""

from __future__ import annotations

import re
import shutil
import struct
import json
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "original-game-reference/source/extracted/spelunky"
SPRITE_ROOT = SOURCE / "Sprites"
OBJECT_ROOT = SOURCE / "Objects"
DESTINATION = ROOT / "assets/original/animations"
OUTPUT = ROOT / "src/animation/original_catalog.lua"
COMBINATION_MAP = ROOT / "src/animation/entity_combinations.json"
ROOM_SPEED = 30
NON_ANIMATED_SHEETS = {"sFont", "sFontSmall", "sFontOld"}

SPRITE_TOKEN = re.compile(r"\bs[A-Za-z0-9_]+\b")
SPEED_ASSIGNMENT = re.compile(r"\bimage_speed\s*=\s*([^;\n]+)")
DIRECT_SELF_SPRITE = re.compile(r"(?<![.A-Za-z0-9_])sprite_index\s*=\s*(s[A-Za-z0-9_]+)")


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    return struct.unpack(">II", header[16:24])


def natural_frame_key(path: Path) -> int:
    match = re.search(r"(\d+)$", path.stem)
    return int(match.group(1)) if match else 0


def pretty_identifier(value: str) -> str:
    value = re.sub(r"^[os](?=[A-Z_])", "", value)
    value = value.replace("_", " ")
    value = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", value)
    value = re.sub(r"\bU F O\b", "UFO", value)
    value = re.sub(r"\bP D\b", "Player ", value)
    return re.sub(r"\s+", " ", value).strip()


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")


def lua_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') \
        .replace("\n", "\\n") + '"'


def unique(values):
    return list(dict.fromkeys(values))


def numeric_speed(expression: str) -> float | None:
    try:
        return float(expression)
    except ValueError:
        return None


def facing_name(sprite_name: str) -> tuple[str, str]:
    replacements = (
        (r"Left$", "", "left"), (r"Right$", "", "right"),
        (r"Left([0-9]+)$", r"\1", "left"), (r"Right([0-9]+)$", r"\1", "right"),
        (r"L$", "", "left"), (r"R$", "", "right"),
        (r"L([0-9]+)$", r"\1", "left"), (r"R([0-9]+)$", r"\1", "right"),
    )
    for pattern, replacement, facing in replacements:
        if re.search(pattern, sprite_name):
            return re.sub(pattern, replacement, sprite_name), facing
    return sprite_name, "neutral"


def read_objects(animated_sprites: set[str]):
    objects = {}
    sprite_references = defaultdict(list)
    for path in OBJECT_ROOT.rglob("*.xml"):
        if ".events" in path.parts:
            continue
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            continue
        object_name = path.stem
        default_sprite = root.findtext("sprite") or ""
        parent = root.findtext("parent") or ""
        event_directory = path.with_suffix(".events")
        events = []
        if event_directory.is_dir():
            for event_path in sorted(event_directory.glob("*.xml")):
                try:
                    event_root = ET.parse(event_path).getroot()
                    code = "\n".join(
                        node.text or "" for node in event_root.findall(".//argument[@kind='STRING']")
                    )
                except ET.ParseError:
                    code = event_path.read_text(errors="ignore")
                events.append({"name": event_path.stem, "code": code})

        referenced = []
        if default_sprite in animated_sprites:
            referenced.append(default_sprite)
        for event in events:
            referenced.extend(token for token in SPRITE_TOKEN.findall(event["code"])
                              if token in animated_sprites)
        referenced = unique(referenced)
        objects[object_name] = {
            "name": object_name,
            "default": default_sprite,
            "parent": parent,
            "events": events,
            "referenced": referenced,
        }
        for sprite in referenced:
            sprite_references[sprite].append(object_name)
    return objects, sprite_references


def fixed_entity(relative_path: Path) -> tuple[str, str, str] | None:
    parts = relative_path.parts
    if len(parts) >= 3 and parts[0] == "Character":
        names = {"Main Dude": "Player", "Damsel": "Damsel", "Tunnel Man": "Tunnel Man"}
        name = names.get(parts[1], parts[1])
        return slug(name), name, "Characters"
    if len(parts) >= 3 and parts[0] == "Enemies":
        name = parts[1]
        return slug(name), name, "Enemies"
    if parts and parts[0] == "supersound":
        return "super_sound_system", "Super Sound System", "Internal"
    return None


def read_entity_combinations(animated_sprites: set[str]):
    data = json.loads(COMBINATION_MAP.read_text(encoding="utf-8"))
    combinations = {}
    for group in data["groups"]:
        entity = group["entity"]
        category = group["category"]
        sprites = group["sprites"]
        if len(sprites) < 2:
            raise ValueError(f"Combination {entity!r} must contain at least two sprites")
        for sprite in sprites:
            if sprite not in animated_sprites:
                raise ValueError(f"Combination {entity!r} references unknown animated sprite {sprite!r}")
            if sprite in combinations:
                previous = combinations[sprite][1]
                raise ValueError(f"Sprite {sprite!r} is mapped to both {previous!r} and {entity!r}")
            combinations[sprite] = (slug(entity), entity, category)
    excluded = set()
    if data.get("exclude_right_when_left_exists"):
        for sprite in animated_sprites:
            if "Right" not in sprite:
                continue
            left_sprite = sprite.replace("Right", "Left", 1)
            if left_sprite in animated_sprites:
                excluded.add(sprite)
    return combinations, excluded


def choose_object(sprite, candidates, objects):
    if not candidates:
        return None
    defaults = [name for name in candidates if objects[name]["default"] == sprite]
    if defaults:
        candidates = defaults
    sprite_words = set(re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?![a-z])", sprite[1:]))
    return max(candidates, key=lambda name: (
        len(sprite_words & set(re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?![a-z])", name[1:]))),
        -len(name), name,
    ))


def speed_metadata(sprite_name, object_name, objects):
    candidates = []
    pattern = "loop"
    evidence = []
    current = object_name
    visited = set()
    while current and current in objects and current not in visited:
        visited.add(current)
        data = objects[current]
        relevant_events = [event for event in data["events"] if sprite_name in event["code"]]
        for event in relevant_events:
            lines = event["code"].splitlines()
            occurrences = [index for index, line in enumerate(lines) if sprite_name in line]
            for occurrence in occurrences:
                nearby = []
                for index in range(max(0, occurrence - 12), min(len(lines), occurrence + 5)):
                    for value in SPEED_ASSIGNMENT.findall(lines[index]):
                        nearby.append((abs(index - occurrence), value.strip()))
                if nearby:
                    nearest_distance = min(distance for distance, _ in nearby)
                    candidates.extend(value for distance, value in nearby if distance == nearest_distance)
            if event["name"] == "Animation end":
                pattern = "one-shot / state transition"
            if any("image_index" in lines[index]
                   for occurrence in occurrences
                   for index in range(max(0, occurrence - 5), min(len(lines), occurrence + 6))):
                pattern = "manual / conditional frames"
            evidence.append(current + ": " + event["name"])
        if candidates:
            break
        current = data["parent"]

    if not candidates and object_name and object_name in objects:
        for event in objects[object_name]["events"]:
            if event["name"] == "Create":
                candidates.extend(value.strip() for value in SPEED_ASSIGNMENT.findall(event["code"]))
    candidates = unique(candidates) or ["1"]
    numeric = [abs(value) for expression in candidates
               if (value := numeric_speed(expression)) is not None and value != 0]
    preview_speed = (numeric[0] if numeric else 0.4) * ROOM_SPEED
    if candidates == ["0"]:
        pattern = "held frame / manual"
        preview_speed = 0
    return candidates, preview_speed, pattern, unique(evidence)


def side_record(sprite):
    return {
        "sprite": sprite["name"], "originX": sprite["originX"], "originY": sprite["originY"],
        "width": sprite["width"], "height": sprite["height"], "frames": sprite["framePaths"],
    }


def write_lua(pages):
    lines = [
        "-- Generated by tools/extract_original_animations.py; do not edit by hand.",
        "return {", f"    roomSpeed = {ROOM_SPEED},", "    pages = {",
    ]
    for page in pages:
        lines.extend([
            "        {", f"            id = {lua_quote(page['id'])},",
            f"            name = {lua_quote(page['name'])},",
            f"            category = {lua_quote(page['category'])},", "            animations = {",
        ])
        for animation in page["animations"]:
            lines.extend([
                "                {", f"                    name = {lua_quote(animation['name'])},",
                f"                    pattern = {lua_quote(animation['pattern'])},",
                f"                    previewFps = {animation['previewFps']:.6g},",
                "                    speedRules = { " + ", ".join(lua_quote(v) for v in animation["speedRules"]) + " },",
                "                    evidence = { " + ", ".join(lua_quote(v) for v in animation["evidence"]) + " },",
            ])
            for facing in ("left", "right", "neutral"):
                side = animation.get(facing)
                if not side:
                    continue
                lines.extend([
                    f"                    {facing} = {{", f"                        sprite = {lua_quote(side['sprite'])},",
                    f"                        originX = {side['originX']}, originY = {side['originY']},",
                    f"                        width = {side['width']}, height = {side['height']},",
                    "                        frames = { " + ", ".join(lua_quote(v) for v in side["frames"]) + " },",
                    "                    },",
                ])
            lines.append("                },")
        lines.extend(["            },", "        },"])
    lines.extend(["    },", "}"])
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    sprites = {}
    for image_directory in SPRITE_ROOT.rglob("*.images"):
        frames = sorted(image_directory.glob("image *.png"), key=natural_frame_key)
        name = image_directory.name[:-7]
        if len(frames) <= 1 or name in NON_ANIMATED_SHEETS:
            continue
        relative = image_directory.relative_to(SPRITE_ROOT)
        xml_path = image_directory.with_suffix(".xml")
        root = ET.parse(xml_path).getroot()
        origin = root.find("origin")
        width, height = png_size(frames[0])
        output_directory = DESTINATION / name
        output_directory.mkdir(parents=True, exist_ok=True)
        frame_paths = []
        for index, frame in enumerate(frames):
            output_path = output_directory / f"{index:03d}.png"
            shutil.copyfile(frame, output_path)
            frame_paths.append(output_path.relative_to(ROOT).as_posix())
        sprites[name] = {
            "name": name, "relative": relative, "originX": int(origin.attrib["x"]),
            "originY": int(origin.attrib["y"]), "width": width, "height": height,
            "framePaths": frame_paths,
        }

    animated = set(sprites)
    combinations, excluded = read_entity_combinations(animated)
    catalog_sprites = {name: sprite for name, sprite in sprites.items() if name not in excluded}
    objects, references = read_objects(set(catalog_sprites))
    pages = {}
    assignments = {}
    for sprite_name, sprite in catalog_sprites.items():
        fixed = fixed_entity(sprite["relative"])
        object_name = choose_object(sprite_name, references[sprite_name], objects)
        if sprite_name in combinations:
            page_id, page_name, category = combinations[sprite_name]
        elif fixed:
            page_id, page_name, category = fixed
        elif object_name:
            page_name = pretty_identifier(object_name)
            page_id = slug(page_name)
            category = sprite["relative"].parts[0] if len(sprite["relative"].parts) > 1 else "Other"
        else:
            parent = sprite["relative"].parent
            if len(sprite["relative"].parts) == 2:
                page_name = pretty_identifier(sprite_name)
            else:
                page_name = pretty_identifier(parent.name if parent.name else "Miscellaneous")
            page_id = slug(page_name)
            category = sprite["relative"].parts[0] if len(sprite["relative"].parts) > 1 else "Other"
        assignments[sprite_name] = (page_id, page_name, category, object_name)
        pages.setdefault(page_id, {"id": page_id, "name": page_name, "category": category, "sprites": []})
        pages[page_id]["sprites"].append(sprite_name)

    for page in pages.values():
        grouped = {}
        for sprite_name in page.pop("sprites"):
            base, facing = facing_name(sprite_name)
            key = base
            entry = grouped.setdefault(key, {"name": pretty_identifier(base), "sides": {}})
            if facing in entry["sides"]:
                key = sprite_name
                entry = grouped.setdefault(key, {"name": pretty_identifier(sprite_name), "sides": {}})
            entry["sides"][facing] = sprite_name

        animations = []
        for entry in grouped.values():
            preferred = entry["sides"].get("left") or entry["sides"].get("neutral") \
                or entry["sides"].get("right")
            object_name = assignments[preferred][3]
            rules, fps, pattern, evidence = speed_metadata(preferred, object_name, objects)
            animation = {
                "name": entry["name"], "speedRules": rules, "previewFps": fps,
                "pattern": pattern, "evidence": evidence,
            }
            if page["id"] in {"player", "damsel", "tunnel_man"}:
                lower_name = animation["name"].lower()
                if "run" in lower_name or "crawl" in lower_name:
                    animation["speedRules"] = ["abs(xVel) * 0.1 + 0.1 (capped at 1)"]
                    if page["id"] == "damsel":
                        animation["speedRules"].append("0.8 while autonomous")
                    animation["previewFps"] = 12
                    animation["evidence"] = ["characterStepEvent: velocity-driven run animation"]
                elif "climb" in lower_name:
                    animation["speedRules"] = ["sqrt(xVel^2 + yVel^2) * 0.4 (capped at 1)"]
                    animation["previewFps"] = 24
                    animation["evidence"] = ["characterStepEvent: velocity-driven climb animation"]
                elif "attack" in lower_name:
                    animation["speedRules"] = ["0.6"]
                    animation["previewFps"] = 18
                    animation["pattern"] = "one-shot / state transition"
                elif "whoa" in lower_name:
                    animation["speedRules"] = ["0.6"]
                    animation["previewFps"] = 18
                elif "dt h" in lower_name or "duck to hang" in lower_name:
                    animation["speedRules"] = ["0.8"]
                    animation["previewFps"] = 24
                    animation["pattern"] = "one-shot / state transition"
            for facing, sprite_name in entry["sides"].items():
                animation[facing] = side_record(sprites[sprite_name])
            if page["id"] == "super_sound_system" and animation["name"] == "0":
                animation["name"] = "Logo"
            animations.append(animation)
        page["animations"] = sorted(animations, key=lambda item: item["name"])

    category_order = {"Characters": 0, "Enemies": 1, "Items": 2, "Traps": 3,
                      "Blocks": 4, "Effects": 5, "HUD": 6, "Other": 7,
                      "Internal": 8}
    result = sorted(pages.values(), key=lambda page: (
        0 if page["id"] == "player" else 1,
        category_order.get(page["category"], 99), page["category"], page["name"]
    ))
    write_lua(result)
    total_animations = sum(len(page["animations"]) for page in result)
    total_frames = sum(len(sprite["framePaths"]) for sprite in sprites.values())
    catalog_frames = sum(len(sprite["framePaths"]) for sprite in catalog_sprites.values())
    print(f"Extracted {len(sprites)} animated sprites / {total_frames} frames")
    print(f"Excluded {len(excluded)} redundant Right sprites with matching Left sprites")
    print(f"Cataloged {len(catalog_sprites)} sprites / {catalog_frames} frames as "
          f"{total_animations} unique animations on {len(result)} entity pages")


if __name__ == "__main__":
    main()
