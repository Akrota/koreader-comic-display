-- Comic Display: zwei Hilfen für Comics auf Farb-E-Ink in einem Plugin (früher die beiden
-- Plugins Comic-Refresh und Dunkle Raender).
-- 1. Refresh gegen Ghosting: Ein Voll-Refresh beim Umblaettern reicht auf Farb-E-Ink (Kaleido) oft
--    nicht, Reste der vorherigen Seite bleiben stehen. Kurz nachdem die neue Seite angezeigt wurde,
--    folgt ein zweiter Voll-Refresh. Automatik: nur bei farbigen Seiten.
-- 2. Dunkle Raender: Die Flaeche, die KOReader neben einer Comic-Seite frei laesst, wird schwarz statt
--    hell gezeichnet. Automatik: pro Seite nach Seitenrand und Helligkeit. Im Nachtmodus greift das
--    nicht ein (Schwarz wuerde durch die Invertierung sonst weiss).
-- Beide nutzen dieselbe Messung pro Seite (einmal statt zweimal pro Seite).
-- Nur bei Comics, EPUBs bleiben unberuehrt.
local Blitbuffer = require("ffi/blitbuffer")
local InfoMessage = require("ui/widget/infomessage")
local logger = require("logger")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local strings = {
    de = {
        menu_title = "Comic Display",
        on = "an",
        off = "aus",
        enabled = "Aktiv",
        pdf = "Auch bei PDF und DjVu",
        about = "Wie funktioniert das?",
        -- Refresh
        refresh_title = "Refresh gegen Ghosting: %s",
        refresh_auto = "Automatisch: nur farbige Seiten (experimentell)",
        delay = "Verzögerung: %s",
        delay_now = "sofort",
        every = "Bei jeder %s. Seite",
        every_one = "Bei jeder Seite",
        test = "Jetzt einmal ausführen",
        turbo = "Turbo (experimentell)",
        mode_clean = "Sauber: zwei Refreshes",
        mode_fast = "Schnell: Dithering automatisch",
        state_clean = "sauber",
        state_fast = "schnell",
        mode_clean_help = "Nach dem Umblättern folgt ein zweiter, voller Refresh. Am saubersten, blitzt aber zweimal.",
        mode_fast_help = "Kein zweiter Refresh. Stattdessen schaltet Comic Display beim Umblättern automatisch den Farbmodus des Bildschirms ein (wie der Schalter „Dithering“), passend zu den Automatik-Einstellungen darunter: nur farbige Seiten, auf Wunsch auch dunkle Schwarzweiß-Seiten. Am schnellsten, ganz leichtes Ghosting kann bleiben.",
        delay_note = "Hinweis: kurze Pause nach dem Blättern bleibt",
        delay_note_help = "Der Extra-Refresh kommt immer einen Moment nach dem Umblättern: KOReader zeichnet zuerst die neue Seite, erst danach kann Comic Display sie ein zweites Mal auffrischen. Beides lässt sich nicht zu einem Schritt zusammenlegen. „Sofort“ macht die Pause so kurz wie möglich, ganz weg geht sie aber nie.",
        turbo_help = "Turbo zeichnet die neue Seite zuerst im schnellsten Modus und frischt sie gleich danach voll auf. Das geht nur mit der Verzögerung „sofort“.",
        refresh_auto_help = "Auf Farb-E-Ink hinterlassen vor allem farbige Seiten sichtbares Ghosting, egal ob hell oder dunkel. Ist das an, bekommen nur farbige Seiten den Extra-Refresh, Schwarzweiß-Seiten nicht (kein unnötiges Flackern).\n\nDie nächste Seite wird schon im Hintergrund geprüft, sobald KOReader sie vorgeladen hat. Experimentell: Die Automatik schätzt nach Helligkeit und Farbe und liegt nicht immer richtig.",
        -- Raender
        borders_title = "Dunkle Ränder: %s",
        borders_auto = "Automatisch: nur dunkle Seiten (experimentell)",
        borders_auto_help = "Der Rand wird schwarz, wenn die Seite selbst einen dunklen Rand hat oder das Bild bis an den Rand reicht (Nachtszenen, schwarze Zwischenräume). Hat sie einen weißen Rand, nur dann, wenn die ganze Seite sehr dunkel ist. Farbe allein zählt nicht. Experimentell: Die Automatik schätzt nach Helligkeit und Farbe und liegt nicht immer richtig.",
        -- Hilfe
        refresh_dark = "Auch dunkle Schwarzweiß-Seiten (experimentell)",
        refresh_dark_help = "Für düstere Schwarzweiß-Comics: Sehr dunkle Seiten bekommen dann ebenfalls den Extra-Refresh, helle Schwarzweiß-Seiten weiterhin nicht. Experimentell: Die Automatik schätzt nach Helligkeit und Farbe und liegt nicht immer richtig.",
        refresh_help = "Zwei Modi:\n• Sauber: Nach dem Umblättern folgt ein zweiter, voller Refresh, der Reste der vorherigen Seite entfernt (Ghosting). Am saubersten, blitzt zweimal. Blätterst du schnell weiter, wird nur die Seite aufgefrischt, auf der du stehen bleibst.\n• Schnell: kein zweiter Refresh. Stattdessen schaltet Comic Display beim Umblättern automatisch Dithering ein (den Farbmodus des Bildschirms, wie der Schalter „Dithering“). Am schnellsten, ganz leichtes Ghosting kann bleiben.\nKOReaders Dithering-Schalter brauchst du in keinem Modus.\n\nAutomatik (beide Modi): Den zweiten Refresh bzw. das Dithering bekommen nur farbige Seiten, auf Wunsch auch dunkle Schwarzweiß-Seiten. Helle Schwarzweiß-Seiten blättert KOReader ganz normal um. Die Automatik ist experimentell und schätzt nach Farbe und Helligkeit.\n\nVerzögerung, Turbo und „Bei jeder Seite“ gehören zum zweiten Refresh und gelten nur bei „Sauber“. Bleibt Ghosting stehen: Verzögerung erhöhen.\n\nGilt für CBZ, CBR, CB7, CBT (und auf Wunsch PDF/DjVu), nicht für EPUBs.",
        borders_help = "Passt eine Seite nicht genau auf den Bildschirm, bleibt daneben ein freier Rand. Comic Display färbt ihn schwarz statt hell.\n\nAutomatik: nur, wenn die Seite selbst einen dunklen Rand hat, das Bild bis an den Rand reicht oder die ganze Seite sehr dunkel ist. Helle Seiten behalten ihren hellen Rand. Die Automatik ist experimentell: Liegt sie daneben, schalte sie aus, dann sind die Ränder immer schwarz.\n\nIm Nachtmodus greift Comic Display nicht ein.",
        old_plugins = "Comic Display ersetzt die Plugins „Comic-Refresh“ und „Dunkle Ränder“. Beide sind noch installiert und würden doppelt wirken. Bitte die Ordner comicrefresh.koplugin und comicdarkborders.koplugin aus dem plugins-Ordner löschen.",
        clock_title = "Uhrzeit in der Ecke",
        clock_on = "Uhrzeit anzeigen",
        clock_battery = "Mit Akkustand",
        clock_corner = "Ecke: %s",
        corner_tr = "oben rechts",
        corner_tl = "oben links",
        corner_br = "unten rechts",
        corner_bl = "unten links",
        clock_style = "Darstellung: %s",
        style_box = "helles Feld",
        style_outline_black = "schwarz mit weißem Umriss",
        style_outline_white = "weiß mit schwarzem Umriss",
        clock_size = "Größe: %s",
        size_s = "klein",
        size_m = "mittel",
        size_l = "groß",
        clock_help = "Zeigt bei Comics klein die Uhrzeit (und auf Wunsch den Akkustand) in einer Ecke über dem Bild. Das Bild wird nicht kleiner. Die Anzeige erneuert sich beim Umblättern, nicht jede Minute (sonst blitzt die Ecke auf E-Ink ständig und kostet Akku).",
        no_standby = "Kein Standby bei Comics",
        no_standby_help = "Solange ein Comic offen ist, geht das Gerät zwischen den Seiten nicht in den kurzen Standby. Beim schnellen Blättern konnte der Standby sonst eine Seite verschlucken: intern umgeblättert, aber nicht angezeigt. Bei Büchern gilt weiter KOReaders Standby-Einstellung. Der normale Ruhezustand bleibt auch bei Comics.",
    },
    en = {
        menu_title = "Comic Display",
        on = "on",
        off = "off",
        enabled = "Enabled",
        pdf = "Also for PDF and DjVu",
        about = "How does it work?",
        refresh_title = "Refresh against ghosting: %s",
        refresh_auto = "Automatic: only colourful pages (experimental)",
        delay = "Delay: %s",
        delay_now = "immediately",
        every = "Every %s pages",
        every_one = "Every page",
        test = "Run once now",
        turbo = "Turbo (experimental)",
        mode_clean = "Clean: two refreshes",
        mode_fast = "Fast: automatic dithering",
        state_clean = "clean",
        state_fast = "fast",
        mode_clean_help = "After the page turn a second, full refresh follows. Cleanest, but flashes twice.",
        mode_fast_help = "No second refresh. Instead, Comic Display switches on the screen's colour mode when turning (like the \"Dithering\" switch), following the automatic settings below: only colourful pages, optionally also dark black-and-white pages. Fastest, very slight ghosting may remain.",
        delay_note = "Note: a short pause after turning stays",
        delay_note_help = "The extra refresh always comes a moment after the page turn: KOReader first draws the new page, only then can Comic Display refresh it a second time. The two cannot be merged into one step. \"Immediately\" makes the pause as short as possible, but it never goes away completely.",
        turbo_help = "Turbo first draws the new page in the fastest mode and fully refreshes it right after. It only works with the delay set to \"immediately\".",
        refresh_auto_help = "On colour e-ink, mainly colourful pages leave visible ghosting, whether light or dark. With this on, only colourful pages get the extra refresh, black-and-white pages do not (no needless flashing).\n\nThe next page is already checked in the background once KOReader has preloaded it. Experimental: the automatic mode guesses from brightness and colour and is not always right.",
        borders_title = "Dark borders: %s",
        borders_auto = "Automatic: only dark pages (experimental)",
        borders_auto_help = "The border turns black when the page itself has a dark edge or the picture reaches the edge (night scenes, black gutters). With a white edge only when the whole page is very dark. Colour alone does not count. Experimental: the automatic mode guesses from brightness and colour and is not always right.",
        refresh_dark = "Also dark black-and-white pages (experimental)",
        refresh_dark_help = "For gloomy black-and-white comics: very dark pages get the extra refresh as well, light black-and-white pages still do not. Experimental: the automatic mode guesses from brightness and colour and is not always right.",
        refresh_help = "Two modes:\n• Clean: after the page turn a second, full refresh clears what is left of the previous page (ghosting). Cleanest, flashes twice. If you keep turning pages quickly, only the page you stop on gets refreshed.\n• Fast: no second refresh. Instead, Comic Display switches on dithering automatically when turning (the screen's colour mode, like the \"Dithering\" switch). Fastest, very slight ghosting may remain.\nYou do not need KOReader's dithering switch in either mode.\n\nAutomatic (both modes): only colourful pages get the second refresh or the dithering, optionally also dark black-and-white pages. Light black-and-white pages are turned by KOReader as usual. The automatic mode is experimental and guesses from colour and brightness.\n\nDelay, Turbo and \"Every page\" belong to the second refresh and only apply in \"Clean\" mode. Still ghosting: increase the delay.\n\nApplies to CBZ, CBR, CB7, CBT (and optionally PDF/DjVu), not to EPUBs.",
        borders_help = "If a page does not fit the screen exactly, a free border remains beside it. Comic Display paints it black instead of light.\n\nAutomatic: only when the page itself has a dark edge, the picture reaches the edge, or the whole page is very dark. Light pages keep their light border. The automatic mode is experimental: if it guesses wrong, turn it off and the borders are always black.\n\nIn night mode Comic Display stays out of the way.",
        old_plugins = "Comic Display replaces the plugins \"Comic refresh\" and \"Dark borders\". Both are still installed and would act twice. Please delete the folders comicrefresh.koplugin and comicdarkborders.koplugin from the plugins folder.",
        clock_title = "Clock in the corner",
        clock_on = "Show time",
        clock_battery = "With battery level",
        clock_corner = "Corner: %s",
        corner_tr = "top right",
        corner_tl = "top left",
        corner_br = "bottom right",
        corner_bl = "bottom left",
        clock_style = "Style: %s",
        style_box = "light box",
        style_outline_black = "black, white outline",
        style_outline_white = "white, black outline",
        clock_size = "Size: %s",
        size_s = "small",
        size_m = "medium",
        size_l = "large",
        clock_help = "For comics, shows the time (and optionally the battery level) small in a corner on top of the page. The page is not shrunk. It updates when you turn the page, not every minute (on e-ink the corner would flash constantly and cost battery).",
        no_standby = "No standby for comics",
        no_standby_help = "While a comic is open, the device does not drop into the short standby between pages. When turning pages quickly, standby could otherwise swallow a page: turned internally, but not shown. Books keep KOReader's standby setting. Normal sleep still works for comics.",
    },
}

local function T(key, ...)
    local ok, lang = pcall(function() return G_reader_settings:readSetting("language") end)
    if not ok or type(lang) ~= "string" then
        ok, lang = pcall(function() return require("gettext").current_lang end)
    end
    local l = (ok and type(lang) == "string" and lang:sub(1, 2):lower() == "de") and "de" or "en"
    local s = strings[l][key] or strings.en[key] or key
    if select("#", ...) > 0 then return string.format(s, ...) end
    return s
end

local COMIC_EXT = { cbz = true, cbr = true, cb7 = true, cbt = true, zip = true, rar = true }
local PDF_EXT = { pdf = true, djvu = true, xps = true }
local DELAYS = { 0, 0.15, 0.3, 0.5, 0.8 }
local EVERY = { 1, 2, 3, 5 }

-- ── Einstellungen ────────────────────────────────────────────────────────────────────────────────
local function setting(key, default)
    local v = G_reader_settings:readSetting("comicdisplay_" .. key)
    if v == nil then return default end
    return v
end

local function save(key, value)
    G_reader_settings:saveSetting("comicdisplay_" .. key, value)
end

-- Einmalig die Einstellungen der beiden alten Plugins uebernehmen
local function migrate()
    if G_reader_settings:readSetting("comicdisplay_migrated") then return end
    local map = {
        refresh_enabled = "comicrefresh_enabled", refresh_auto = "comicrefresh_auto",
        delay = "comicrefresh_delay", turbo = "comicrefresh_turbo", every = "comicrefresh_every",
        borders_enabled = "comicdarkborders_enabled", borders_auto = "comicdarkborders_auto",
    }
    for new, old in pairs(map) do
        local v = G_reader_settings:readSetting(old)
        if v ~= nil then save(new, v) end
    end
    -- PDF/DjVu galt bisher pro Plugin: an, wenn es in einem der beiden an war
    local pdf_r, pdf_b = G_reader_settings:readSetting("comicrefresh_pdf"), G_reader_settings:readSetting("comicdarkborders_pdf")
    if pdf_r ~= nil or pdf_b ~= nil then save("pdf", pdf_r == true or pdf_b == true) end
    save("migrated", true)
end

-- ── Messung einer Seite ──────────────────────────────────────────────────────────────────────────
-- Stichprobe von 24 x 32 Bildpunkten: mittlere Helligkeit (0-255) und mittlere Farbigkeit (Abstand
-- zwischen staerkstem und schwaechstem Farbkanal), dazu 160 Punkte im schmalen Streifen am
-- Seitenrand (aeussere 2 %). Dauert Bruchteile einer Millisekunde.
local COLOUR_ABOVE = 30      -- Refresh: mittlere Farbigkeit darueber = farbige Seite
local EDGE_DARK_BELOW = 110  -- Raender: Seitenrand dunkler als das = dunkler Rand
local PAGE_DARK_ENTER = 100  -- Raender: von hell nach schwarz erst, wenn die Seite dunkler als das ist
local PAGE_DARK_LEAVE = 125  -- Raender: von schwarz zurueck nach hell erst, wenn die Seite heller ist
local DARK_BW_BELOW = 100    -- Refresh (Option): Schwarzweiss-Seite dunkler als das bekommt ihn auch

local function rgb(bb, x, y)
    local px = bb:getPixel(x, y)
    if not px then return nil end
    return px:getColorRGB32()
end

-- @return { page = Helligkeit, colour = Farbigkeit, edge = Randhelligkeit (nur ohne x0) } oder nil
local function measure(bb, x0, y0, w, h)
    if not bb then return nil end
    local full = x0 == nil
    x0, y0 = x0 or 0, y0 or 0
    w, h = w or bb:getWidth(), h or bb:getHeight()
    if w < 20 or h < 20 then return nil end
    local sum_l, sum_c, n = 0, 0, 0
    for j = 0, 31 do
        local y = y0 + math.floor((j + 0.5) * h / 32)
        for i = 0, 23 do
            local c = rgb(bb, x0 + math.floor((i + 0.5) * w / 24), y)
            if c then
                sum_l = sum_l + 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
                sum_c = sum_c + math.max(c.r, c.g, c.b) - math.min(c.r, c.g, c.b)
                n = n + 1
            end
        end
    end
    if n == 0 then return nil end
    local m = { page = sum_l / n, colour = sum_c / n }
    if not full then return m end -- Bildschirmausschnitt: kein Seitenrand
    local bx, by = math.max(1, math.floor(w * 0.02)), math.max(1, math.floor(h * 0.02))
    local sum_edge, n_edge = 0, 0
    for i = 0, 39 do
        local x = math.floor((i + 0.5) * w / 40)
        local y = math.floor((i + 0.5) * h / 40)
        for _, p in ipairs({ { x, by }, { x, h - 1 - by }, { bx, y }, { w - 1 - bx, y } }) do
            local c = rgb(bb, p[1], p[2])
            if c then
                sum_edge = sum_edge + 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
                n_edge = n_edge + 1
            end
        end
    end
    if n_edge > 0 then m.edge = sum_edge / n_edge end
    return m
end

-- Refresh: true = braucht den Extra-Refresh, false = nicht (KOReader frischt normal auf).
-- Auf Farb-E-Ink hinterlaesst vor allem Farbe sichtbares Ghosting, egal ob hell oder dunkel.
-- Auf Wunsch auch sehr dunkle Schwarzweiss-Seiten (duestere Schwarzweiss-Comics).
local function needsRefresh(m)
    if m.colour > COLOUR_ABOVE then return true end
    return setting("refresh_dark", false) and m.page < DARK_BW_BELOW
end

-- Raender:
-- 1. Hat die Seite selbst einen dunklen Rand oder reicht das Bild bis an den Rand: schwarz.
-- 2. Hat sie einen hellen Rand: nur schwarz, wenn die ganze Seite wirklich sehr dunkel ist.
--    Farbe allein zaehlt nicht (helle farbige Seiten bleiben hell).
-- 3. Pufferzone: Die Grenze fuer die ganze Seite haengt von der vorigen Entscheidung ab, damit
--    aehnliche Seiten hintereinander nicht zwischen hell und dunkel springen.
local function bordersDark(m, previous_dark)
    if m.edge and m.edge < EDGE_DARK_BELOW then return true end
    if previous_dark then return m.page < PAGE_DARK_LEAVE end
    return m.page < PAGE_DARK_ENTER
end

-- ── Plugin ───────────────────────────────────────────────────────────────────────────────────────
local ComicDisplay = WidgetContainer:extend{
    name = "comicdisplay",
    is_doc_only = true,
}

function ComicDisplay:init()
    migrate()
    self.page_count = 0
    self.measures = {}  -- Seite -> Messwerte (gemeinsam fuer beide Hilfen)
    self.refresh = {}   -- Seite -> Refresh-Entscheidung
    self.dark = {}      -- Seite -> Rand-Entscheidung
    -- Eine feste Funktion, damit ein noch ausstehender Refresh per unschedule verworfen werden kann
    self.do_refresh = function()
        -- Turbo: Flag zuruecksetzen, sonst wuerde auch dieser Voll-Refresh zu "fast" herabgestuft
        if self.turbo_pending then
            UIManager.currently_scrolling = false
            self.turbo_pending = false
        end
        UIManager:setDirty(nil, "full", nil, true)
        -- Erst freigeben, wenn der Refresh auf dem Bildschirm ist (das passiert am Ende dieses
        -- Durchlaufs). Sonst wuerde das Vorausladen im selben Durchlauf vorher noch rechnen.
        local seq = self.page_seq
        UIManager:scheduleIn(0.05, function()
            if seq ~= self.page_seq then return end -- inzwischen weitergeblaettert
            self.refresh_pending = false
            self:runDeferredHint()
        end)
    end
    -- Oben im Werkzeuge-Menue, in fester Reihenfolge mit den anderen viel genutzten Plugins
    local util = require("util")
    local TOP = { "story_recall", "guitar_tab_reader", "comicdisplay" }
    local tools = require("ui/elements/reader_menu_order").tools
    for i = #tools, 1, -1 do if tools[i] == "comicdisplay" then table.remove(tools, i) end end
    local my_rank, pos = util.arrayContains(TOP, "comicdisplay"), 1
    for i, key in ipairs(tools) do
        local rank = util.arrayContains(TOP, key)
        if rank and rank < my_rank then pos = i + 1 end
    end
    table.insert(tools, pos, "comicdisplay")
    self.ui.menu:registerToMainMenu(self)
    self:wrapBorders()
    self:wrapPaint()
end

function ComicDisplay:isComic()
    local file = self.ui.document and self.ui.document.file
    if not file then return false end
    local ext = (file:match("%.([^./]+)$") or ""):lower()
    if COMIC_EXT[ext] then return true end
    return PDF_EXT[ext] and setting("pdf", false) or false
end

function ComicDisplay:onReaderReady()
    self.comic = self:isComic()
    self:updateStandby()
    self:wrapHinting()
    self.page_count = 0
    self.measures, self.refresh, self.dark = {}, {}, {}
    self.last_dark = nil
    -- Die alten Einzel-Plugins wuerden doppelt wirken
    if self.comic and (self.ui.comicrefresh or self.ui.comicdarkborders) and not ComicDisplay.warned then
        ComicDisplay.warned = true
        UIManager:show(InfoMessage:new{ text = T("old_plugins") })
    end
end

-- Kein Standby bei Comics: KOReaders kurzer Standby zwischen den Seiten (Kobo) konnte beim schnellen
-- Blaettern eine Seite verschlucken (intern umgeblaettert, aber nicht angezeigt). Solange ein Comic
-- offen ist, wird er ueber KOReaders eigene Sperre (preventStandby/allowStandby) verhindert, genau
-- einmal gesperrt und einmal freigegeben. Der normale Ruhezustand ist davon nicht betroffen.
function ComicDisplay:updateStandby()
    local want = self.comic and setting("no_standby", true) and true or false
    if want and not self.standby_blocked then
        UIManager:preventStandby()
        self.standby_blocked = true
        logger.info("ComicDisplay: Standby gesperrt (Comic offen)")
    elseif not want and self.standby_blocked then
        UIManager:allowStandby()
        self.standby_blocked = false
        logger.info("ComicDisplay: Standby wieder erlaubt")
    end
end

-- Vorausladen erst nach dem Refresh: KOReader rechnet direkt nach dem Zeichnen die naechste Seite
-- vor. Steht noch ein Extra-Refresh aus, muesste er auf diese Rechenarbeit warten (beim Vorblaettern
-- spuerbar langsamer als beim Zurueckblaettern, wo nichts zu rechnen ist). Deshalb wird das
-- Vorausladen so lange zurueckgehalten und direkt nach dem Refresh nachgeholt.
function ComicDisplay:wrapHinting()
    local hinting = self.ui.hinting
    if not hinting or hinting._comicdisplay_wrapped then return end
    hinting._comicdisplay_wrapped = true
    local original = hinting.onHintPage -- auch die Fassung von Comic Dual Page (Doppelseiten)
    local plugin = self
    hinting.onHintPage = function(h, ...)
        if plugin.refresh_pending then
            local args = { ... }
            plugin.deferred_hint = function() original(h, unpack(args)) end
            return true
        end
        return original(h, ...)
    end
end

function ComicDisplay:runDeferredHint()
    local hint = self.deferred_hint
    if not hint then return end
    self.deferred_hint = nil
    hint()
end

-- Messwerte aus KOReaders Zwischenspeicher (vorgeladene oder schon gezeigte Seite).
-- Rendert nichts selbst: Liegt die Seite nicht im Speicher, kommt nil zurueck.
function ComicDisplay:pageMeasure(page)
    if not page or page < 1 then return nil end
    if self.measures[page] then return self.measures[page] end
    local doc, view = self.ui.document, self.ui.view
    if not doc or not view then return nil end
    local ok, tile = pcall(function()
        local zoom = self.ui.zooming and self.ui.zooming:getZoom(page) or view.state.zoom
        local hash = doc:getFullPageHash(page, zoom, view.state.rotation, view.state.gamma, view.state.saturation)
        return require("document/doccache"):check(hash, require("document/tilecacheitem"))
    end)
    if not ok or not tile or not tile.bb then return nil end
    local ok2, m = pcall(measure, tile.bb)
    if not ok2 or not m then return nil end
    self.measures[page] = m
    return m
end

-- ── 1. Refresh gegen Ghosting ────────────────────────────────────────────────────────────────────
function ComicDisplay:refreshDecision(page)
    if self.refresh[page] ~= nil then return self.refresh[page] end
    local m = self:pageMeasure(page)
    if not m then return nil end
    self.refresh[page] = needsRefresh(m)
    return self.refresh[page]
end

-- Bewertung des gerade gezeigten Bildschirms (ohne Statusleiste unten)
function ComicDisplay:screenDecision()
    local bb = Screen and Screen.bb
    if not bb then return nil end
    local w, h = bb:getWidth(), bb:getHeight()
    local ok, m = pcall(measure, bb, 0, math.floor(h * 0.03), w, math.floor(h * 0.90))
    if not ok or not m then return nil end
    return needsRefresh(m)
end

-- Im Hintergrund die Nachbarseiten messen, sobald KOReader sie vorgeladen hat
function ComicDisplay:schedulePredict(page)
    if self.predict_fn then UIManager:unschedule(self.predict_fn) end
    self.predict_fn = function()
        self.predict_fn = nil
        for _, p in ipairs({ page + 1, page - 1 }) do self:refreshDecision(p) end
    end
    UIManager:scheduleIn(0.6, self.predict_fn)
end

function ComicDisplay:onPageUpdate(page)
    if self.comic == nil then self.comic = self:isComic() end
    -- Eine neue Seite: ein noch zurueckgehaltenes Vorausladen gilt der alten Seite und entfaellt
    self.refresh_pending, self.deferred_hint = false, nil
    self.page_seq = (self.page_seq or 0) + 1
    if not self.comic or not setting("refresh_enabled", true) then return end
    -- Im Modus "schnell" kein zweiter Refresh (der Farbmodus kommt beim Zeichnen, siehe wrapPaint)
    if not self:cleanMode() then return end
    self.page_count = self.page_count + 1
    if self.page_count % setting("every", 1) ~= 0 then return end
    UIManager:unschedule(self.do_refresh)
    if self.tick_wrapper then UIManager:unschedule(self.tick_wrapper) end
    local delay = setting("delay", 0.3)

    if setting("refresh_auto", true) and page then
        local d = self:refreshDecision(page)
        logger.info("ComicDisplay refresh: page", page, "decision", d == nil and "unknown" or (d and "refresh" or "skip"), "(preloaded)")
        if d == false then
            -- Schwarzweiss-Seite: kein Extra-Refresh, auch kein Turbo
            self:schedulePredict(page)
            return
        elseif d == nil then
            -- Unbekannt: normal zeichnen lassen, danach den Bildschirm pruefen
            self.refresh_pending = true
            self.tick_wrapper = UIManager:tickAfterNext(function()
                local s = self:screenDecision()
                logger.info("ComicDisplay refresh: page", page, "decision", s == nil and "unknown" or (s and "refresh" or "skip"), "(screen)")
                if s ~= nil then self.refresh[page] = s end
                if s ~= false then
                    if delay <= 0 then self.do_refresh() else UIManager:scheduleIn(delay, self.do_refresh) end
                else
                    self.refresh_pending = false
                    self:runDeferredHint()
                end
                self:schedulePredict(page)
            end)
            return
        end
        -- Farbig: wie gehabt (inklusive Turbo)
        self:schedulePredict(page)
    end
    self.refresh_pending = true
    if delay <= 0 then
        if setting("turbo", false) and not UIManager.currently_scrolling then
            -- Turbo: Die neue Seite zuerst mit dem schnellsten Modus ("fast") zeichnen lassen,
            -- wie KOReader es beim Scrollen macht. Der Voll-Refresh direkt danach ersetzt das Bild.
            UIManager.currently_scrolling = true
            self.turbo_pending = true
        end
        -- Geplante Aufgaben laufen in KOReader VOR dem Zeichnen, nextTick wuerde also mit dem
        -- Umblaettern verschmelzen. tickAfterNext laeuft direkt nach dem Zeichnen, ohne Wartezeit.
        self.tick_wrapper = UIManager:tickAfterNext(self.do_refresh)
    else
        UIManager:scheduleIn(delay, self.do_refresh)
    end
end

-- ── 2. Dunkle Raender ────────────────────────────────────────────────────────────────────────────
function ComicDisplay:bordersActive()
    if not (setting("borders_enabled", true) and not Screen.night_mode and self:isComic()) then return false end
    if not setting("borders_auto", true) then return true end
    return self:pageEdgeDark(self.ui.view and self.ui.view.state and self.ui.view.state.page)
end

function ComicDisplay:pageEdgeDark(page)
    if not page then return self.last_dark or false end
    -- Einmal getroffene Entscheidung pro Seite beibehalten (sonst wuerde die Pufferzone beim
    -- Neuzeichnen derselben Seite je nach vorheriger Seite anders ausfallen)
    if self.dark[page] ~= nil then
        self.last_dark = self.dark[page]
        return self.dark[page]
    end
    local m = self:pageMeasure(page)
    if m then
        local d = bordersDark(m, self.last_dark)
        logger.info(string.format("ComicDisplay borders: Seite %d Rand %.0f Seite %.0f -> %s", page, m.edge or -1, m.page, d and "schwarz" or "hell"))
        self.dark[page] = d
        self.last_dark = d
        return d
    end
    -- Seite noch nicht gerendert (erstes Zeichnen): wie die vorige Seite, nach dem Zeichnen
    -- messen und bei Abweichung den Rand neu zeichnen
    local guess = self.last_dark or false
    self:scheduleRecheck(page, guess)
    return guess
end

function ComicDisplay:scheduleRecheck(page, guessed)
    if self.recheck_fn then UIManager:unschedule(self.recheck_fn) end
    self.recheck_fn = function()
        self.recheck_fn = nil
        local m = self:pageMeasure(page)
        if not m then return end
        local d = bordersDark(m, guessed)
        logger.info(string.format("ComicDisplay borders: Seite %d Rand %.0f Seite %.0f -> %s (nachgeprueft)", page, m.edge or -1, m.page, d and "schwarz" or "hell"))
        self.dark[page] = d
        if d ~= guessed and self.ui.view and self.ui.view.state.page == page then
            self.last_dark = d
            UIManager:setDirty(self.ui.view.dialog, "ui")
        end
    end
    UIManager:scheduleIn(0.2, self.recheck_fn)
end

-- Die drei Stellen, an denen ReaderView Flaeche ausserhalb der Seite fuellt. Jeweils fuer die Dauer
-- des Zeichnens die Farbe auf Schwarz setzen und danach den Originalwert zurueckgeben.
function ComicDisplay:wrapBorders()
    local view = self.ui.view
    if not view then return end
    local plugin = self
    local function wrap(method, field, subfield)
        local original = view[method]
        if not original then return end
        view[method] = function(v, ...)
            if not plugin:bordersActive() then return original(v, ...) end
            local holder = subfield and v[field] or v
            local key = subfield or field
            if type(holder) ~= "table" then return original(v, ...) end
            local saved = holder[key]
            holder[key] = Blitbuffer.COLOR_BLACK
            local ok, err = pcall(original, v, ...)
            holder[key] = saved
            if not ok then error(err, 0) end
        end
    end
    wrap("drawPageSurround", "outer_page_color") -- Raender in der Seitenansicht
    wrap("drawPageBackground", "page_bgcolor") -- Hintergrund in der fortlaufenden Ansicht
    wrap("drawPageGap", "page_gap", "color") -- Luecke zwischen Seiten in der fortlaufenden Ansicht
end

-- Farbmodus beim Umblaettern: KOReader frischt eine neue Seite nur dann im Farbmodus des Bildschirms
-- (Kaleido) auf, wenn die Ansicht als "gedithert" markiert ist. Das macht sonst nur der Schalter
-- "Dithering" im unteren Menue. Ohne ihn bleiben beim normalen Umblaettern Farbreste stehen.
-- Bei Comics setzt Comic Display die Markierung selbst, solange der Refresh gegen Ghosting an ist.
-- Refresh-Modus: "off" = Refresh gegen Ghosting aus, "clean" = zwei Refreshes, "fast" = kein
-- zweiter Refresh, aber Dithering (Farbmodus) automatisch, nach denselben Automatik-Regeln.
function ComicDisplay:refreshMode()
    if not setting("refresh_enabled", true) then return "off" end
    return setting("mode", "clean") == "fast" and "fast" or "clean"
end

-- Nur im Modus "sauber" gibt es den zweiten Refresh (und damit Verzoegerung, Turbo, Wie oft)
function ComicDisplay:cleanMode()
    return self:refreshMode() == "clean"
end

-- Bekommt diese Seite den Farbmodus? Wie der Extra-Refresh: mit Automatik nur farbige Seiten
-- (auf Wunsch auch dunkle Schwarzweiss-Seiten). Gemessen wird die gerade gezeichnete Seite.
function ComicDisplay:wantsColour(page, bb)
    if not setting("refresh_auto", true) then return true end
    local d = page and self:refreshDecision(page)
    if d == nil and bb then
        local w, h = bb:getWidth(), bb:getHeight()
        local ok, m = pcall(measure, bb, 0, math.floor(h * 0.03), w, math.floor(h * 0.90))
        if ok and m then
            d = needsRefresh(m)
            if page then self.refresh[page] = d end
        end
    end
    return d == true
end

function ComicDisplay:modeItem(mode, key)
    return {
        text = T(key),
        radio = true,
        enabled_func = function() return setting("refresh_enabled", true) end,
        checked_func = function() return setting("mode", "clean") == mode end,
        callback = function()
            save("mode", mode)
            self.refresh = {}
        end,
        help_text = T(key .. "_help"),
    }
end

function ComicDisplay:wrapPaint()
    -- An der Klasse ReaderView, nicht an der Ansicht selbst: ZenOS (ab 4.3, return_button.lua) ersetzt
    -- nach dem Oeffnen jedes Buchs ui.view.paintTo und ruft dann ReaderView.paintTo auf. Eine Huelle an
    -- der Ansicht ginge dabei verloren (12.11.2026: Uhr und Farbmodus kamen auf dem Kobo nie an).
    local ReaderView = require("apps/reader/modules/readerview")
    ReaderView._comicdisplay_plugin = self
    if ReaderView._comicdisplay_paint then return end
    ReaderView._comicdisplay_paint = true
    local original = ReaderView.paintTo
    ReaderView.paintTo = function(v, bb, x, y, ...)
        local r = original(v, bb, x, y, ...)
        local plugin = ReaderView._comicdisplay_plugin
        if not plugin or not plugin.ui or plugin.ui.view ~= v then return r end
        if plugin.comic and plugin:refreshMode() ~= "off" and v.dialog
                and plugin:wantsColour(v.state and v.state.page, bb) then
            v.dialog.dithered = true
        end
        if plugin.comic and setting("clock", false) then
            local ok, err = pcall(plugin.paintClock, plugin, bb, x or 0, y or 0)
            if not ok and plugin.clock_err ~= tostring(err) then
                plugin.clock_err = tostring(err)
                logger.warn("ComicDisplay clock:", err)
            end
        end
        return r
    end
end

-- ── Uhrzeit in der Ecke ──────────────────────────────────────────────────────────────────────────
-- Wird nach der Seite gezeichnet, also darueber; das Bild bleibt unveraendert gross.
-- Erneuert sich mit jedem Neuzeichnen (Umblaettern), nicht im Minutentakt.
local CLOCK_SIZES = { s = 15, m = 19, l = 25 }

function ComicDisplay.clockText(now, battery)
    local text = os.date("%H:%M", now)
    if battery then text = text .. " · " .. battery .. " %" end
    return text
end

local function battery_level()
    local ok, cap = pcall(function() return require("device"):getPowerDevice():getCapacity() end)
    if ok and type(cap) == "number" then return math.floor(cap + 0.5) end
end

function ComicDisplay:paintClock(bb, x, y)
    local Font = require("ui/font")
    local TextWidget = require("ui/widget/textwidget")
    local text = ComicDisplay.clockText(os.time(), setting("clock_battery", true) and battery_level() or nil)
    local size = CLOCK_SIZES[setting("clock_size", "m")] or CLOCK_SIZES.m
    local style = setting("clock_style", "box")
    local face = Font:getFace("cfont", size)
    local fg = style == "outline_white" and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK
    local ring = style == "outline_white" and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE
    local widget
    local pad_x, pad_y = 0, 0
    if style == "box" then
        widget = require("ui/widget/container/framecontainer"):new{
            background = Blitbuffer.COLOR_WHITE,
            bordersize = 0,
            radius = Screen:scaleBySize(4),
            padding = Screen:scaleBySize(2),
            padding_left = Screen:scaleBySize(5),
            padding_right = Screen:scaleBySize(5),
            TextWidget:new{ text = text, face = face, fgcolor = fg },
        }
    else
        widget = TextWidget:new{ text = text, face = face, fgcolor = fg }
        pad_x = Screen:scaleBySize(2) -- Platz fuer den Umriss
        pad_y = pad_x
    end
    local ws = widget:getSize()
    local margin = Screen:scaleBySize(6)
    local w, h = Screen:getWidth(), Screen:getHeight()
    local corner = setting("clock_corner", "tr")
    local px = (corner == "tl" or corner == "bl") and (margin + pad_x) or (w - ws.w - margin - pad_x)
    local py = (corner == "tl" or corner == "tr") and (margin + pad_y) or (h - ws.h - margin - pad_y)
    px, py = x + px, y + py
    if style ~= "box" then
        -- Umriss: die Schrift in der Gegenfarbe rundherum versetzt, dann die Schrift selbst darueber
        local outline = TextWidget:new{ text = text, face = face, fgcolor = ring }
        local r = pad_x
        for dx = -r, r do
            for dy = -r, r do
                if (dx ~= 0 or dy ~= 0) and dx * dx + dy * dy <= r * r + 1 then
                    outline:paintTo(bb, px + dx, py + dy)
                end
            end
        end
        outline:free()
    end
    widget:paintTo(bb, px, py)
    widget:free()
    self.clock_painted = text
end

function ComicDisplay:onCloseDocument()
    UIManager:unschedule(self.do_refresh)
    if self.predict_fn then UIManager:unschedule(self.predict_fn) end
    if self.recheck_fn then UIManager:unschedule(self.recheck_fn) end
    if self.tick_wrapper then UIManager:unschedule(self.tick_wrapper) end
    if self.turbo_pending then
        UIManager.currently_scrolling = false
        self.turbo_pending = false
    end
    self.refresh_pending, self.deferred_hint = false, nil
    self.measures, self.refresh, self.dark = {}, {}, {}
    self.last_dark = nil
    self.comic = false
    self:updateStandby()
end

-- ── Menue ────────────────────────────────────────────────────────────────────────────────────────
local function delay_text(d)
    if d <= 0 then return T("delay_now") end
    return string.format("%g s", d)
end

local function redraw()
    UIManager:setDirty("all", "full")
end

function ComicDisplay:clockMenu()
    local items = {
        {
            text = T("clock_on"),
            checked_func = function() return setting("clock", false) end,
            callback = function() save("clock", not setting("clock", false)); redraw() end,
            help_text = T("clock_help"),
        },
        {
            text = T("clock_battery"),
            enabled_func = function() return setting("clock", false) end,
            checked_func = function() return setting("clock_battery", true) end,
            callback = function() save("clock_battery", not setting("clock_battery", true)); redraw() end,
            separator = true,
        },
    }
    for _, c in ipairs({ "tr", "tl", "br", "bl" }) do
        items[#items + 1] = {
            text = T("clock_corner", T("corner_" .. c)),
            radio = true,
            enabled_func = function() return setting("clock", false) end,
            checked_func = function() return setting("clock_corner", "tr") == c end,
            callback = function() save("clock_corner", c); redraw() end,
            separator = c == "bl",
        }
    end
    for _, st in ipairs({ "box", "outline_black", "outline_white" }) do
        items[#items + 1] = {
            text = T("clock_style", T("style_" .. st)),
            radio = true,
            enabled_func = function() return setting("clock", false) end,
            checked_func = function() return setting("clock_style", "box") == st end,
            callback = function() save("clock_style", st); redraw() end,
            separator = st == "outline_white",
        }
    end
    for _, z in ipairs({ "s", "m", "l" }) do
        items[#items + 1] = {
            text = T("clock_size", T("size_" .. z)),
            radio = true,
            enabled_func = function() return setting("clock", false) end,
            checked_func = function() return setting("clock_size", "m") == z end,
            callback = function() save("clock_size", z); redraw() end,
        }
    end
    return items
end

function ComicDisplay:addToMainMenu(menu_items)
    local delay_items = {}
    for _, d in ipairs(DELAYS) do
        delay_items[#delay_items + 1] = {
            text = delay_text(d),
            radio = true,
            checked_func = function() return setting("delay", 0.3) == d end,
            callback = function() save("delay", d) end,
        }
    end
    local every_items = {}
    for _, n in ipairs(EVERY) do
        every_items[#every_items + 1] = {
            text = n == 1 and T("every_one") or T("every", n),
            radio = true,
            checked_func = function() return setting("every", 1) == n end,
            callback = function() save("every", n) end,
        }
    end
    menu_items.comicdisplay = {
        text = T("menu_title"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text_func = function()
                    local m = self:refreshMode()
                    return T("refresh_title", m == "clean" and T("state_clean") or m == "fast" and T("state_fast") or T("off"))
                end,
                sub_item_table = {
                    {
                        text = T("enabled"),
                        checked_func = function() return setting("refresh_enabled", true) end,
                        callback = function() save("refresh_enabled", not setting("refresh_enabled", true)) end,
                    },
                    self:modeItem("clean", "mode_clean"),
                    (function() local it = self:modeItem("fast", "mode_fast"); it.separator = true; return it end)(),
                    {
                        text = T("refresh_auto"),
                        enabled_func = function() return setting("refresh_enabled", true) end,
                        checked_func = function() return setting("refresh_auto", true) end,
                        callback = function()
                            save("refresh_auto", not setting("refresh_auto", true))
                            self.refresh = {}
                        end,
                        help_text = T("refresh_auto_help"),
                    },
                    {
                        text = T("refresh_dark"),
                        enabled_func = function() return setting("refresh_enabled", true) and setting("refresh_auto", true) end,
                        checked_func = function() return setting("refresh_dark", false) end,
                        callback = function()
                            save("refresh_dark", not setting("refresh_dark", false))
                            self.refresh = {}
                        end,
                        help_text = T("refresh_dark_help"),
                    },
                    {
                        text_func = function() return T("delay", delay_text(setting("delay", 0.3))) end,
                        enabled_func = function() return self:cleanMode() end,
                        sub_item_table = delay_items,
                    },
                    {
                        -- right below the delay: why there is always a short pause
                        text = T("delay_note"),
                        enabled_func = function() return self:cleanMode() end,
                        keep_menu_open = true,
                        callback = function() UIManager:show(InfoMessage:new{ text = T("delay_note_help") }) end,
                    },
                    {
                        text = T("turbo"),
                        -- Turbo wirkt nur ohne Verzoegerung
                        enabled_func = function() return self:cleanMode() and setting("delay", 0.3) <= 0 end,
                        checked_func = function() return setting("turbo", false) end,
                        callback = function() save("turbo", not setting("turbo", false)) end,
                        help_text = T("turbo_help"),
                    },
                    {
                        text_func = function()
                            local n = setting("every", 1)
                            return n == 1 and T("every_one") or T("every", n)
                        end,
                        enabled_func = function() return self:cleanMode() end,
                        sub_item_table = every_items,
                        separator = true,
                    },
                    {
                        text = T("about"),
                        keep_menu_open = true,
                        callback = function() UIManager:show(InfoMessage:new{ text = T("refresh_help") }) end,
                    },
                },
            },
            {
                text_func = function()
                    return T("borders_title", setting("borders_enabled", true) and T("on") or T("off"))
                end,
                sub_item_table = {
                    {
                        text = T("enabled"),
                        checked_func = function() return setting("borders_enabled", true) end,
                        callback = function()
                            save("borders_enabled", not setting("borders_enabled", true))
                            redraw()
                        end,
                        separator = true,
                    },
                    {
                        text = T("borders_auto"),
                        enabled_func = function() return setting("borders_enabled", true) end,
                        checked_func = function() return setting("borders_auto", true) end,
                        callback = function()
                            save("borders_auto", not setting("borders_auto", true))
                            self.dark = {}
                            redraw()
                        end,
                        help_text = T("borders_auto_help"),
                    },
                    {
                        text = T("about"),
                        keep_menu_open = true,
                        callback = function() UIManager:show(InfoMessage:new{ text = T("borders_help") }) end,
                    },
                },
            },
            {
                text = T("pdf"),
                checked_func = function() return setting("pdf", false) end,
                callback = function()
                    save("pdf", not setting("pdf", false))
                    self.comic = self:isComic()
                    self:updateStandby()
                    redraw()
                end,
            },
            {
                text = T("clock_title"),
                checked_func = function() return setting("clock", false) end,
                help_text = T("clock_help"),
                sub_item_table = self:clockMenu(),
            },
            {
                text = T("no_standby"),
                checked_func = function() return setting("no_standby", true) end,
                callback = function()
                    save("no_standby", not setting("no_standby", true))
                    self:updateStandby()
                end,
                help_text = T("no_standby_help"),
            },
        },
    }
end

return ComicDisplay
