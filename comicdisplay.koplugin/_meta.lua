-- Beschreibung auf Deutsch oder Englisch, je nach KOReader-Sprache
local ok, lang = pcall(function() return G_reader_settings:readSetting("language") end)
local de = ok and type(lang) == "string" and lang:sub(1, 2):lower() == "de"
return {
    fullname = "Comic Display",
    description = de
        and "Für Comics auf Farb-E-Ink (CBZ/CBR/CB7/CBT, optional PDF): Refresh gegen Ghosting (schnell per Dithering oder sauber mit zweitem Refresh; automatisch nur bei farbigen Seiten) und schwarze statt helle Ränder neben der Seite (automatisch pro Seite). Ersetzt die Plugins Comic-Refresh und Dunkle Ränder."
        or "For comics on colour e-ink (CBZ/CBR/CB7/CBT, optionally PDF): refresh against ghosting (fast with dithering, or clean with a second refresh; automatically only on colourful pages) and black instead of light borders beside the page (decided per page). Replaces the plugins Comic refresh and Dark borders.",
    version = "0.2.0",
}
