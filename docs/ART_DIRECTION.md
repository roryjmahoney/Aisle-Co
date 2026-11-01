# Art direction

## The idea

**A neighbourhood grocer as a hand-made miniature.** The world sits on a dark
presentation plinth, like an architectural model someone built with care.
Everything is a little chunky and softened, lit like a sunny morning, and
detailed enough that zooming in is rewarding.

Reference feelings, not references to copy: model railways, old corner-shop
signage, painted wainscoting, striped canvas awnings, checkerboard floors.

## Palette

Defined once in `src/art/palette.gd`. Nothing invents its own colour.

| Role | Swatch | Hex |
| --- | --- | --- |
| Signature green (storefront, frames, awning) | Grocer | `#2f7a57` |
| Near-ink green (trim, kick plates, UI surfaces) | Pine | `#1d3b33` |
| Primary accent (price tags, selection, primary buttons) | Marigold | `#f2b33d` |
| Warm accent (owner's shirt, hydrant, warnings) | Tomato | `#e2553a` |
| Cool accent (chilled goods, info) | Sky | `#8cc8dc` |
| Floor tile | Mint `#8fccb0` / Snow `#f4f7f2` | |
| Upper walls | Butter yellow | `#f3e39e` |
| Exterior | Terracotta brick | `#b85b3f` |
| Natural material | Oak | `#c98b55` |

**No beige.** Whites are cool (`#f4f7f2`), and the warmth comes from butter
yellow, oak and terracotta instead of cream. Dusk goes rose and lavender, not
sepia.

## Typography

- **Bricolage Grotesque** (heavy, condensed): titles, money, 3D signs. It has
  the slightly irregular warmth of painted shop lettering.
- **Figtree**: everything you read at length. Tabular figures are used for
  numbers that tick, so they don't jitter.

## Modelling rules

- Every edge gets a bevel (1 to 2 cm at real scale). Bevels catch the key light and
  are the difference between "miniature" and "grey-box".
- Objects are built in real units (shelf tiers are 0.4 m apart, a can is
  7.4 cm wide). Shelf capacity is derived from product size, so **what you see
  on the shelf is the stock**.
- Materials come from a small set of channels (matte paint, satin, gloss,
  metal, glass, emissive, wood) with procedural detail in shaders: tile grout
  aligned to the build grid, brick courses, wood grain, plaster with wainscot.
- Repeated objects get small variations (product jitter, leaf rotation) so
  nothing looks stamped out.

## Lighting

Filmic tonemapping, SSAO for contact shading (essential for the diorama
look), gentle glow only on genuinely emissive things. The sun moves across the
day; when it sets, street lamps and the shop's warm interior take over.

## UI

- Floating panels around the edges; the store stays visible.
- Pine-ink surfaces, one accent colour (marigold) for "act here / selected",
  tomato only for problems.
- Original line icons on a 24-unit grid with a 1.75 stroke, matching the type weight.
- Short (≈0.2 s) eased entrances; money counts rather than jumps.
- Hover, pressed, selected and disabled states on every interactive element.
