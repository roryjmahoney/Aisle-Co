# Development log

## How this was verified

The development environment had no GPU and no audio device. To avoid working
blind:

- Godot 4.3 ran under Xvfb with Mesa's software Vulkan (lavapipe), so the real
  Forward+ renderer produced every screenshot in `docs/screenshots/`. Visual
  decisions below were made by looking at those renders and fixing what looked
  wrong.
- `tools/capture.gd` drives scripted camera angles, times of day, simulated
  play and UI states for review.
- `tests/run_tests.gd` runs headless (11 tests, all passing).

**Not verified:** how the camera *feels* in the hand (mouse orbit, drag, zoom),
since nothing was played interactively. Sounds were checked for level and
clipping by the tests but **not listened to**. Frame rate on real hardware
hasn't been measured.

## Milestone 1: foundation (Phase 1)

Done:
- Procedural mesh kit (bevelled boxes, lathes, rods, skinning) and a shared
  material library; procedural shaders for tile, brick, plaster with wainscot,
  oak and terrain.
- The diorama lot: plinth, street with crossing, pavements with a dropped kerb,
  brick shop with striped awning, fascia sign, sliding doors, stockroom with
  strip curtain and roll-up shutter, planters, lamps, bench, hydrant, empty lot
  next door.
- Per-side wall cutaway that folds walls down when they block the view and
  keeps them up at wide zoom so the façade shows.
- Damped management camera; time-of-day lighting with dusk and night.

Review fixes made after looking at renders:
- Interior was stark white and clinical → butter-yellow walls and a stronger mint
  checker.
- Golden hour washed everything sepia → rose/lavender dusk keys.
- Road missing (grass plane drawn over asphalt), plinth z-fighting on the empty
  lot, sliding doors staying up when the wall was cut, street lamps blocking the
  close-up view, manhole cover rendering as a bright disc.

## Milestone 2: construction (Phase 2)

Done: grid placement with a fresnel ghost and marigold footprint, rotation,
human-readable reasons for invalid spots, costs, 75% resale, move, undo,
connectivity validation (nothing can wall off an aisle, a till or the
stockroom). The build menu shows thumbnails rendered from the real models.

Review fixes: the ghost was invisible (mint on a mint floor), so it now uses a
pale sky body and a marigold footprint.

## Milestone 3 and 4: trading loop and management (Phases 3–4)

Done:
- Six products, wholesale ordering, delivery van, stockroom racks showing the
  cases you own.
- Shoppers with budget, price sensitivity, patience, substitution and speed.
  They take physical units, react to stock-outs, prices and queues, and leave
  satisfied or not. That feeds reputation, which drives footfall.
- The owner works the till when needed and restocks otherwise; cashiers and
  stockers can be hired and let go; restock tasks can be prioritised per tier.
- Day cycle: setup hour, trading, closing (serving the last shoppers), report;
  rent, utilities, upkeep, wages.
- Prices window with margin and how shoppers will perceive each price.
- Saves with autosave each morning.

Bugs found and fixed:
- Street-furniture cells were blocked after the navigation graph was built →
  shoppers looped on replanning forever and the day never closed. Fixed at the
  source, and a stuck-agent watchdog was added.
- Floating baskets (bone attachment offset), oversized windows from autowrapped
  labels, stale audio players after a scene reload, the placement sound clipping
  (now limited).

A simulated first day: ~90–100 shoppers, ~95% served, about $580–620 sales,
about $250 operating profit, with inventory audit and ledger checks passing.

## Not built yet (honest list)

- Buying adjacent land / expanding the building; walls and floors aren't
  buildable yet (the lot is structured for it).
- Spoilage (`shelf_life_days` exists but isn't simulated).
- Music (the bus and settings exist; no tracks ship). Ambient soundscape.
- Cleaner, manager and delivery roles; the owner walkaround mode.
- Customer avoidance between people (they can overlap briefly).
- Performance profiling at hundreds of agents.
- Key rebinding UI, multiple save slots, a title screen.

## Next steps

1. Play-test camera and construction feel on real hardware; tune damping.
2. Land purchase and building extension (the grid and walls support it).
3. More product lines and a produce display; spoilage.
4. Ambient sound and music.
