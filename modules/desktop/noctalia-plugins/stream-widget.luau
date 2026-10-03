--!nonstrict
-- Bar widget that renders a stream of ashell-style JSON lines:
--   {"text": "...", "alt": "urgent" | "error" | anything}
-- Shared by the calendar and weather plugins. modules/desktop/noctalia.nix
-- substitutes the @...@ tokens with store paths at build time, so the widget
-- needs no per-instance settings (those would trip the strict config check).
--
-- runStream gives Luau no exit callback (v5.1.0 luau_host.cpp), so restarting
-- a dead script lives in the Nix-built stream wrapper, which prints an
-- "alt": "error" line before each restart. That keeps the bar from showing
-- stale text with no marker.

local STREAM = [==[@stream@]==]
local CLICK = [==[@click@]==]
local GLYPH = "@glyph@"

local text = "@name@ loading"
local alert = false
-- "alt": "empty" means nothing worth showing (ashell-calendar.sh prints it
-- when no meeting is within the hour), so the widget hides instead of taking
-- bar space with "No meetings soon".
local empty = false

local function render()
  barWidget.setVisible(not empty)
  -- Empty @glyph@ means the stream's own text carries its icons (the weather
  -- script prints Nerd Font weather glyphs), so don't add a second one.
  if GLYPH ~= "" then
    barWidget.setGlyph(GLYPH)
  end
  barWidget.setText(text)
  if alert then
    barWidget.setColor("error")
    barWidget.setGlyphColor("error")
  else
    barWidget.setColor("on_surface")
    barWidget.setGlyphColor("primary")
  end
end

noctalia.runStream(STREAM, function(line)
  -- ashell-calendar.sh and openweathermap-forecast.sh build their JSON by
  -- string interpolation (not a JSON encoder), so a meeting title or
  -- forecast string containing a `"` produces invalid JSON. json.decode can
  -- throw rather than return nil for that, so wrap it in pcall. Any failure
  -- here (decode error, nil, a non-table, or a non-string .text) must mark
  -- the bar as stale/wrong rather than silently keep showing the previous
  -- line's text with no indication something broke.
  local ok, data = pcall(noctalia.json.decode, line)
  if not ok or type(data) ~= "table" or type(data.text) ~= "string" then
    noctalia.log("@name@: ignoring unparseable line: " .. line)
    text = "@name@ unavailable"
    alert = true
    empty = false
    render()
    return
  end
  text = data.text
  alert = data.alt == "urgent" or data.alt == "error"
  empty = data.alt == "empty"
  render()
end)

function update()
  noctalia.setUpdateInterval(60000)
  render()
end

function onClick()
  noctalia.runAsync(CLICK)
end
