# Comic Display for KOReader

*Deutsch: [README.de.md](README.de.md)*

A KOReader plugin that makes comics look better on colour e-ink. It does two things, each with its own settings:

- **Refresh against ghosting:** right after a page turn, a second full refresh clears what is left of the previous page.
- **Dark borders:** when a page doesn't fill the screen, the free border beside it is painted black instead of light, so dark pages don't sit in a bright frame.

Both share one quick look at each page (brightness, colour, edge), so the page is only measured once.

- It doesn't change any KOReader files, so it survives updates.
- It is only active for comics (CBZ, CBR, CB7, CBT). PDF and DjVu can be switched on, and EPUBs are not affected.

## Refresh against ghosting

On colour e-ink (for example the Kobo Libra Colour), remnants of the previous page often stay visible in comics, even when KOReader does a full refresh on every page. Comic Display triggers a **second** full refresh as soon as the new page is drawn.

- When you turn pages quickly, a pending refresh is dropped. Only the page you stop on gets refreshed.
- **Automatic: only colourful pages (experimental)** (default: on). Experimental, like all automatic options here: it guesses from colour and brightness. Ghosting is mainly visible on colourful pages. Black-and-white pages are refreshed by KOReader as usual, without the extra flash. The next page is checked in the background as soon as KOReader has preloaded it.
- **Also dark black-and-white pages (experimental)** (default: off). For gloomy black-and-white comics: very dark pages get the extra refresh as well.
- **Delay:** 0.3 s by default. Try "immediately": if the page is clean with it, that's the fastest option. If ghosting remains, increase the delay.
- Right below it, a note explains why a short pause after the page turn always stays: KOReader draws the new page first, only then can the second refresh follow.
- **Two modes:** **Clean** (default): a second, full refresh after the page turn, cleanest. **Fast: automatic dithering**: no second refresh; instead Comic Display switches on the screen's colour mode when turning (like KOReader's "Dithering" switch), following the automatic settings. Fastest, very slight ghosting may remain. You don't need KOReader's dithering switch in either mode.
- **Turbo** (only with "immediately", experimental): the new page is first drawn in KOReader's fastest mode, the clean full refresh follows right after.
- **How often:** every page (default), or only every 2nd, 3rd or 5th page.

Tip: you can set KOReader's own "full refresh on every page" back to a normal value, for example every 6 pages. Comic Display takes care of a clean picture anyway, so the screen flashes once per page instead of twice.

## Dark borders

- **Automatic: only dark pages (experimental)** (default: on). The border turns black when the page itself has a dark edge or the picture reaches the edge (night scenes, black gutters). With a white edge only when the whole page is very dark. Light pages keep their light border. A small buffer stops it from switching back and forth between similar pages.
- Turn the automatic mode off to have black borders on every page.
- In night mode Comic Display stays out of the way.

## Installation

1. Download the ZIP from [Releases](../../releases) and unpack it, or download this repository.
2. Copy the folder **`comicdisplay.koplugin`** to KOReader's `plugins` folder. On a Kobo, that is `.adds/koreader/plugins/`.
3. Restart KOReader.

## Settings

Open a comic, then go to: top menu → tools icon (wrench) → **Comic Display** (near the top).

- **Refresh against ghosting: clean ▸** with the mode (clean or fast) and all refresh settings
- **Dark borders: on ▸** with its own settings
- **Clock in the corner:** time, optionally with battery, in a corner of the page (corner, size, and style: box, black outline or white outline). Off by default. Works with ZenOS 4.3 too.
- **Also for PDF and DjVu** (for both)

Each part ends with **"How does it work?"**, a short explanation. Long-press an entry for its help text.

## Works well with

- [Comic Panel Zoom](https://github.com/Akrota/koreader-comic-panel-zoom): has its own refresh on panel change.
- [Comic Dual Page](https://github.com/Akrota/koreader-comic-dual-page): two pages side by side in landscape.

## Tested on

Kobo Libra Colour with KOReader 2026.07.1 (also with ZenOS).

## Who made this

The code was written entirely by **Claude**, an AI by Anthropic (in Claude Code). The owner of this repository came up with the idea, tested the plugin on a Kobo and gave feedback, but did not write the code.

There is no warranty and no guaranteed support. Bug reports are welcome as [issues](../../issues). Please attach `crash.log` from the KOReader folder.

## License

[MIT](LICENSE)
