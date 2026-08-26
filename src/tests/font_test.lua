local Test = {}

function Test.run(app)
    local symbols = "◀▶▲▼•"
    for name, font in pairs(app.fonts) do
        assert(font:hasGlyphs(symbols), name .. " UI font is missing viewer navigation glyphs")
    end
    assert(app.fonts.body:getWidth("◀  FACING LEFT") <= 144,
        "Facing label no longer fits its animation-viewer button")
end

return Test
