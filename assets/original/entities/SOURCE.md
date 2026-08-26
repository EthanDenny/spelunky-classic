# Original entity artwork

The PNG files in this directory are direct frame-0 copies from the extracted
Spelunky Classic 1.1 GameMaker project. `tools/extract_original_entity_sprites.py`
resolves each generated entity through its original object XML, copies the
object's default sprite, and writes its GameMaker origin and dimensions to
`src/world/original_entity_sprites.lua`.

The shop sign variants and Lady Xoc background are copied from their named
sprite/background resources because the original scripts select them dynamically.
