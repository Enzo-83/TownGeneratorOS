# Medieval Fantasy City Generator — Kwanqobile fork

A fork of [watabou/TownGeneratorOS](https://github.com/watabou/TownGeneratorOS), adding
**two concentric walls** and **deliberately placed districts**. GPL-3.0, like the original.

> ### Upstream's README, kept as written
> This is the source code of the [Medieval Fantasy City Generator](https://watabou.itch.io/medieval-fantasy-city-generator/) (also available [here](http://fantasycities.watabou.ru/?size=15&seed=682063530)). It
> lacks some of the latest features, namely waterbodies, options UI and some smaller ones. Maybe I'll update it later.
>
> You'll need [OpenFL](https://github.com/openfl/openfl) and [msignal](https://github.com/massiveinteractive/msignal)
> to run this code, both available through `haxelib`.

⚠️ **That caveat matters.** This source predates the current released generator, so the
landmark loader, the settlement panel and SVG/JSON export are **not here** and are not
added by this fork. What you get is the generator as of January 2021, plus the two
features below.

---

## What this fork adds

### A second, inner wall

The generator models exactly one wall: a single `CurtainWall`, with a *boolean*
`withinWalls` on each patch. A city is walled or it isn't.

This fork adds an **inner ring**, built for cities that grew a boundary long before they
grew a defence. It is deliberately not a fortification:

- built with `real = false`, so it follows patch boundaries exactly and **splits no patch**
  to make room for a road;
- **no towers**;
- **drawn open at its gates** — the line simply stops, because the ring never had to hold
  anyone;
- its gates are kept **out of `Model.gates`** on purpose. Streets already cross it on their
  way from the outer gates to the plaza, and anchoring more streets to it is the quickest
  way to make street building fail.

The enclosed core grows outward from the centre, always taking the nearest patch that
already touches the core. Slicing the distance-sorted list instead is simpler and
occasionally hands `findCircumference` a disconnected set, which does not terminate.

### Placed districts

Upstream assigns wards by shuffling `Model.WARDS` and giving each one the best-rated free
patch. You can influence it, but you cannot say *put the market next to the plaza*.

This fork adds a placement pass that runs **before** the shuffled list gets a look in.
Each placement names a ward type and a zone:

| Zone | Means |
|---|---|
| `core` | Inside the inner ring |
| `between` | Within the city, outside the inner ring |
| `city` | Anywhere inside the city |
| `plaza` | Sharing an edge with the central plaza |

Within its zone a placed ward still uses that ward class's own `rateLocation`, so it lands
somewhere the generator considers sensible rather than somewhere arbitrary.

**A zone that cannot be satisfied falls back to anywhere in the city rather than throwing.**
An impossible spec would otherwise rebuild the city forever. Every compromise is recorded
in `Model.placementWarnings` — which also carries a river that could not be routed — so a
caller can tell *the district is where I asked* from *the district is somewhere*.

A placement may also carry **the district's name**, as a third field:

```
districts=market:between:The Velvet Road,craftsmen:core:The Awoken Steel
```

Without it a district gets a generated name, so a map of a real place labels its market
quarter "Brambletown" instead of what it is actually called — and the only fix was editing
the exported SVG in a vector editor, which is exactly what a user without one cannot do.
Generated names remain the fallback for everything left unnamed.

Only the ward and zone are case-folded; the name is kept exactly as written. It may contain
spaces and colons, but not a comma, which separates one placement from the next.

**Naming a district does not move anything.** The generated name is still rolled and thrown
away, because ward geometry is built afterwards from the same random sequence — skipping
the roll would shift every building in the city.

### A river

Opt-in, with `river=1` or the menu toggle. Riverside settlements are the reason to have
one at all, and until now they could not be mapped.

> ⛔ **A river does not change the city it runs through.**
>
> Everything the generator makes — the patches, the walls, the streets, the wards, every
> building — comes out of one static `Random` in order. A single draw from it for the river
> would shift all of them, and every seed already chosen would produce a different city,
> including the landlocked ones that will never have a river. So the river draws from a
> generator of its own, seeded from the city's seed, and it runs **after** the geometry is
> finished. Toggling it leaves exactly the same city underneath.
>
> Verified rather than asserted: on the same seed with and without it, the `roads` and
> `walls` groups of the exported SVG are byte-identical, and every building in the wet map
> is also in the dry one. The river only ever takes buildings away.

The cost of that is that the wards do not know about the water — nobody sites a district
with reference to a river that does not exist yet. What happens instead is that the
buildings the water covers are cleared afterwards, and the population falls with them,
since it is counted from the buildings left standing.

The course follows patch boundaries, for the same reason the inner ring does: an edge is a
line the generator has already agreed nothing is built on. It pays a toll to run along a
street or across the plaza, so it prefers to cross a road rather than flow down it, and
each crossing gets a **bridge**. ⚠️ If nothing crosses, one is placed where the water runs
nearest the middle of the town: the street network was built before the river existed, so
on a small town with two streets whether anything crosses is luck — and a settlement
straddling a river has a crossing.

**There is deliberately no river roll.** A roll would have to come out of the city's own
sequence to be reproducible from the seed, and drawing from that sequence is the one thing
the river must not do.

### Names and labels

**The upstream source draws no text at all** — no district names, no settlement name, no
scale bar. Labelled districts arrived in 0.7.1, which postdates this code, so a fork of it
produces maps with nothing written on them.

This fork adds:

- **District names**, generated compositionally rather than by Markov chain. The names
  being imitated ("Silver Rock", "North Slums", "Rose Gate") are modifier + head noun, and
  a head chosen from the ward's own type is what makes a market read as a market. A
  character-level chain on a small corpus produces mush and cannot be steered that way.
- **Label fitting** — each name is tried at twelve angles and placed at the largest legible
  size that fits its patch, or dropped if none does. Text is rasterised large and scaled
  *down*, since the map is drawn in units where a whole town is a few hundred across.
- **Collision rejection** — a label is also tested against every label already placed, and
  falls back through angles and sizes until it clears them or gives up. The released
  generator solved this properly in 0.11.1 with straight-skeleton placement; this is most
  of the benefit for a fraction of the work. **The order is the priority**: the settlement
  title, the scale caption, landmarks and hand-named districts are placed first, and only
  a generated district name is ever dropped.
- **A halo** behind every label, in the paper colour. The map is drawn almost entirely in
  one ink, so a bare glyph over a block of houses has to be picked out of the hatching
  before it can be read. On screen the halo is eight offset copies of the text; in SVG it
  is a stroke under the fill, so it stays one element per label.
- **A legibility floor** under every label, as a share of the city's radius rather than a
  constant. The view and the export both scale to fit the city, so a size in map units is
  not a size on the page: an absolute floor left a size-6 town's population line nearly as
  large as its own title, and a metropolis's district names too small to read.
- **The settlement's name** above the map, and a **population / building count** beneath it.
- **A scale bar**, in map units, so it stays truthful at any zoom.

Population is `buildings × 6`, measured against the released generator's own readout across
four sizes, where it lands between 6.0 and 6.2 throughout. `Model.METRES_PER_UNIT` is 4,
calibrated from `MAIN_STREET` being 2 units and a main street being about eight metres —
which puts a 2,100-person town at roughly 18 hectares, about right for the period.

### Landmarks

A comma-separated list of points of interest, scattered one to a district and drawn as a
marker with its name beneath. A landmark supersedes its district's own name, since printing
both in one patch yields two unreadable labels.

**Placement is random**, which reproduces the released generator's behaviour — a landmark
list is scattered, not positioned. Reroll the seed until it lands somewhere you can live with.

Landmarks do avoid **hand-named** districts, since a name you wrote yourself is not something
to overwrite by a scatter. Generated names are fair game.

### Export

| Key | Writes |
|---|---|
| `S` | SVG |
| `P` | PNG, 2048×2048 |

**SVG is written from the model, not captured from the screen**, so the output is real
vector geometry in named groups (`roads`, `buildings`, `walls`, `labels`) that you can pull
apart in an editor. That is the point of exporting rather than screenshotting.

Both the screen and the SVG take their labels from the same `LabelPlan`, so the two cannot
disagree about which labels a map has — which they otherwise would, since collision
rejection depends on the order labels are placed in.

Both are also in the menu, which is where anyone who has not read this will find them.

### The menu

Down the right-hand edge: the four city sizes, **New City** for another one the same size,
toggles for **walls**, the inner **ring**, the **citadel**, the **plaza** and the **river**,
and the two exports. Each has a tooltip.

A toggle reads its state from the finished model rather than from the parameters, so it
shows what the map on screen actually has. Those differ whenever a parameter was left to
be rolled, which is the default for the walls, the citadel and the plaza.

Everything the menu does goes through `StateManager.regenerate`, which rebuilds the city
*and* rewrites the address bar. ⚠️ The size buttons previously did half of that: they
pushed a fresh seed into the URL and then rebuilt from the seed inside the stale
`Model.options`, so the address bar described a city that was never drawn and reloading it
gave you a different map.

---

## URL parameters

Upstream's build reads only `size` and `seed`. This fork adds the rest:

| Parameter | Values | Default |
|---|---|---|
| `size` | 6–40 | 15 |
| `seed` | positive integer | random |
| `plaza` | `0` / `1` | rolled |
| `citadel` | `0` / `1` | rolled |
| `walls` | `0` / `1` | rolled |
| `innerwall` | `0` / `1` | `0` |
| `core` | 2–30 — patches inside the inner ring | 5 |
| `river` | `0` / `1` | `0` |
| `districts` | `ward:zone:Name,…` — zone and name both optional | none |
| `name` | the settlement's name | generated |
| `landmarks` | comma-separated names | none |

Ward names for `districts`: `craftsmen`, `merchant`, `cathedral`, `administration`,
`slum`, `patriciate`, `market`, `military`, `park`, `gate`, `farm`.
An unknown ward or zone name is skipped, so one typo costs you a district rather than the
whole map. A missing zone defaults to `city`; a missing name is generated.

`CommonWard` and `Castle` are deliberately not placeable. `CommonWard` is the base class
the residential wards extend, and its constructor takes density parameters as well —
building one with just `(model, patch)` leaves `minSq` null, and `Ward.createAlleys` then
subdivides until the stack gives out. `Castle` belongs to the citadel and raises its own wall.

```
?size=24&seed=149&walls=1&innerwall=1&core=6&districts=craftsmen:core:The Awoken Steel,market:plaza,park:between
```

**Seeds still reproduce upstream's cities.** The three rolls for plaza, citadel and walls
are always drawn, in the original order, even when you override them — otherwise setting
one parameter would silently change the whole layout. Nothing this fork adds draws from
that sequence at all; `river=1` is the closest thing to an exception, and it has a
generator of its own precisely so that it is not one.

Programmatically, set `Model.options` to a `CityOptions` before constructing a `Model`.
Left null, the generator behaves exactly as it did upstream.

---

## Running it

CI publishes the html5 build to GitHub Pages on every push to `master`:

**<https://enzo-83.github.io/TownGeneratorOS/>**

Every parameter below works there, so a map is a link rather than a file:

```
https://enzo-83.github.io/TownGeneratorOS/?size=24&seed=149&walls=1&river=1&districts=market:plaza:The Velvet Road
```

⚠️ **Pages has to be set to "GitHub Actions" as its source**, not to a branch. `Export/` is
gitignored, so there is no branch holding a built bundle for Pages to serve — the deploy job
hands it the one CI has just built. The bundle's paths are all relative, so it runs from the
repository subpath without a base-href of any kind.

## Building

```
haxelib install msignal 1.2.5
haxelib install lime 8.3.2
haxelib install openfl 9.5.2
haxelib run lime build html5
```

⚠️ **`project.xml` has been repinned.** Upstream pinned lime 7.3.0 and openfl 8.9.0, which
predate Haxe 4 — openfl 8.9.0 still uses `@:fakeEnum`, removed in Haxe 4, so those versions
cannot compile on a current toolchain at all. Two upstream source fixes were needed for the
same reason, both unrelated to the features above:

- `Polygon.get_square` called the static extension `last()` bare inside an abstract, which
  Haxe 4 will not resolve; it is now `this.last()`.
- `Ward.filterOutskirts` built an array comprehension whose first branch was `Int` and whose
  middle branch was fractional; the literals are now floats.

CI builds html5 on every push and uploads the bundle as an artifact.
