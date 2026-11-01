# Architecture

## Principles

- **Definitions vs. state.** `ProductDef` and `FixtureDef` are immutable
  Resources in `data/`. Runtime state (`Fixture`, `Inventory`, `Economy`) holds
  ids and numbers, never references to definitions in saves.
- **Simulation is separate from rendering.** `src/sim` and `src/agents` logic
  never touch nodes for decisions. Views (`FixtureView`, `PersonView`) observe
  and interpolate.
- **One autoload.** `Game` owns the simulation systems and the fixed-step loop.
  Everything else is a plain object or a node in the main scene.

## The loop

`Game._process` accumulates real time × speed and runs whole 1/30 s steps
(up to 24 per frame). Speeding up runs *more* identical steps, never larger
ones, so shoppers, queues and money behave the same at every speed. Views
interpolate between the last two steps using `Game.alpha`.

Each step: `SimClock.step` → `Inventory.step` (deliveries) → `Game.tick`
signal → customers, checkout lanes, staff.

## Space

`StoreGrid` uses 0.5 m cells (the same as the floor tiles). Zones mark shop,
stockroom, pavement and road. **Walls live on cell edges**, so wall shelving sits
flush. Navigation is an `AStar2D` graph; occupancy changes relink only the
neighbourhood. Paths are string-pulled with a clearance-aware line-of-sight
test. A watchdog flags agents that stop making progress, and their owners
recover gracefully (shoppers give up, staff return what they carry).

## Rules live in one place

`Store.check_placement` is the only placement validator. The build tool, save
loading and tests all call it. It checks bounds, zones, overlap, doorways,
wall straddling, aisle access and a flood fill proving that every fixture's
aisle and the stockroom route are still reachable from the entrance.

## Money and stock

- Money is integer cents. Every change goes through `Economy._post`, which
  writes a ledger entry, so `cash == sum(ledger)` always holds.
- Units move through explicit methods: supplier → stockroom → (staff carrying)
  → shelf → basket → sold. `Inventory.audit()` checks that units in the world
  equal units received minus units sold, and that nothing is negative or over
  capacity. The tests run it after hundreds of random operations and a full
  day.

## Saves

Versioned JSON (`user://saves/slot1.json`) is written to a temp file then
renamed. Only plain data is stored. Shoppers mid-visit aren't saved; their
baskets and staff loads are folded back into the stockroom figures. On load,
cents and product ids are normalised back from JSON's floats and strings, and
every fixture is re-validated.

## Scaling notes

- Products on shelves are `MultiMesh` instances (one per tier). People are
  single skinned meshes (one draw call each).
- Fixture and person meshes are cached by definition/look.
- Shopper decisions run per step but are cheap. Pathfinding is native
  `AStar2D`. The design targets hundreds of agents; it has **not** been
  profiled at that scale yet.
