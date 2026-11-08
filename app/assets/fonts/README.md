# Fonts

The two typefaces of the ACAPS website, bundled so the app never downloads fonts at run time.

| File | Family | Use | License |
| --- | --- | --- | --- |
| `BebasNeue-Regular.ttf` | Bebas Neue | Headings (all caps) | SIL Open Font License 1.1 |
| `RobotoCondensed-Regular.ttf` | Roboto Condensed 400 | Body text | SIL Open Font License 1.1 |
| `RobotoCondensed-Bold.ttf` | Roboto Condensed 700 | Titles, labels, buttons | SIL Open Font License 1.1 |
| `Arrows-400.ttf`, `Arrows-700.ttf` | Noto Sans Symbols (only ← ↑ → ↓) | Fallback for arrows in text | SIL Open Font License 1.1 |

The Bebas Neue and Roboto Condensed files are Latin subsets from [Fontsource](https://fontsource.org). The arrow
files come from the Google Fonts `text=` API. All six files add up to about 125 KB. The theme lists `Arrows` as a
fallback family, so no glyph used in the app has to be fetched over the network.
