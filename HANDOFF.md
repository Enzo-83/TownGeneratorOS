# Handoff

Working notes for picking this fork up cold. The [README](README.md) says what the fork
*is*; this says what it was like to build, what to do next, and what will bite you.

---

## Where it stands

`master` carries everything, CI green:

- **Double walls** — an inner ring that is not a fortification, plus the outer curtain wall
- **Placed districts** — `core` / `between` / `city` / `plaza`
- **District and settlement names**, fitted labels, landmarks, population, scale bar
- **Custom district names** — `districts=` takes `ward:zone:Name`
- **Label collision rejection**, halos, and one `LabelPlan` behind both renderers
- **SVG and PNG export** on the `S` and `P` keys, and in the menu
- **A right-click menu** — sizes, reroll, walls/ring/citadel/plaza/river toggles, exports
- **A river**, opt-in, that provably does not change the city it runs through
- **Fields on farms**, which upstream left as a bare farmhouse in an empty patch

---

## What was done next, in order

⚠️ **All four are now done.** They are kept here with what each one turned out to cost,
because the traps are the part worth reading, and because the order they were done in is
still the argument for how to pick the next thing: **not** by working down the version gap
to the released 0.11.4, but by what a GM with no vector editor cannot work around.

### 1. ✅ Custom district names — done

`districts=` takes `ward:zone:Name`. `WardPlacement` has a `name` field, `parsePlacements`
no longer lowercases the whole entry (only the ward and zone tokens), and `placeWards` sets
`ward.name`, which `nameWards` then leaves alone.

⚠️ **`nameWards` still rolls the generated name for a district the caller named, and throws
it away.** `buildGeometry` runs after `nameWards` and draws from the same sequence, so
skipping the roll would move every building in the city — naming a district would silently
relayout the map. Same pattern as the plaza/citadel/wall rolls. Verified: `#buildings`
hashes identically with and without the names on `?size=24&seed=149&…`.

Landmarks are kept off hand-named districts (`Patch.nameFromCaller`), since a landmark
supersedes the district label it lands on.

**Landmarks take a placement too**, added later: `landmarks=cathedral:Temple of the Dawn`,
or a zone, or nothing at all. ⛔ **`assignLandmarks` makes exactly one `Random` draw per
landmark placed, whatever the spec says** — `buildGeometry` runs afterwards off the same
sequence, so an extra or skipped draw moves every building in the city. Filtering on
"anything" returns the same patches in the same order and the same single draw then picks
the same one, which is what keeps an unspecified list landing where it always did.
Verified by stash-and-rebuild: identical marker coordinates, labels, and buildings, fields
and walls hashes.

> ✅ **A long custom name used to be dropped rather than shrunk.** `LabelView.fit` returns
> null below `MIN_FIT`, so "The Velvet Road" vanished from `?size=24&seed=149&…` while
> "Velvet" printed. `fitInsistent` now prints it at `MIN_FIT` anyway, overflowing its
> patch, and picks the least-overlapping angle when nothing is clear — see 2.

### 2. ✅ Label collision rejection — done, plus the readability work it exposed

`LabelPlan` decides every label on a map and in what order; `CityMap` and `MapExporter`
both consume it, so the screen and the SVG cannot disagree about which labels a map has.
`LabelView.fit` takes the boxes already spoken for and falls back through twelve angles and
four sizes until it clears them.

**The order is the priority**, since whatever is placed first cannot be pushed aside: title,
population line, scale caption, landmarks, hand-named districts, generated names. Only the
last group is ever dropped, into `LabelPlan.dropped`.

Three things this turned up that are worth not rediscovering:

- ⛔ **`GLYPH_RATIO` is the wrong number for a collision box, and using it made the
  rejection silently not reject.** 0.46 is an *average* advance, tuned so a label looks
  right inside its patch. Measured against Georgia the mean is 0.50 and "Hound Works" is
  0.57, so boxes built from 0.46 sat a tenth of a label's width inside each other and the
  test passed them. `BOX_RATIO`/`BOX_HEIGHT` are separate and deliberately worst-case. A
  fitting ratio wants the average; a box wants the widest name on the map.
- **The legibility floor is a share of `cityRadius`, not a constant in city units**, and it
  applies to *every* label in `LabelPlan.reserve` rather than only the district names. Both
  the view and the export scale to fit the city, so a size in map units is not a size on the
  page — the old absolute 3.6 was a seventh of a size-6 town's radius and a thirtieth of a
  metropolis's. ⚠️ It was tried as an absolute first, and a size-6 town came back with a
  population line nearly as large as its own title.
- **A landmark's name is measured out from its dot**, not offset by a share of the radius.
  Once the size had a floor under it, a fixed share put the name straight through its own
  marker on a small town.

**Labels are haloed** in the paper colour — eight offset copies on screen, a stroke under
the fill via `paint-order` in SVG. The map is drawn almost entirely in one ink, and a bare
glyph over a block of houses has to be picked out of the hatching before it can be read.
⚠️ The halo is why the AABB test is worth keeping conservative: a label that *nearly*
collides now prints a ring through its neighbour.

> **Testing this without clicking:** export the SVG by the recipe further down, inject only
> its `#labels` group into a 2048×2048 host div, and compare `getBoundingClientRect()`
> pairwise. That is the browser's own glyph metrics rather than our estimate of them, so it
> catches exactly the `GLYPH_RATIO` class of bug. `?size=24&seed=149&…` went from ten
> overlapping pairs to none. **Test the landmark dots against the labels in the same pass**
> — a marker is not a label and nothing else notices when a name is printed through one.
>
> ⛔ **It found a second bug worth keeping the harness for.** SVG anchors text at its
> baseline while the plan gives a centre, and the shift between them was applied to the `y`
> of the `translate` — *outside* the rotation. That offset is along the glyphs' own down
> axis, not the page's, so a label rotated 90° came out a third of its height off along
> page x: it disagreed with the screen renderer, and sat outside the box the collision test
> had reserved for it. The shift now goes on the `<text>` inside the transform.

### 3. ✅ A menu — done, then rebuilt as a context menu

It began as `ui/Menu.hx`, a column of buttons down the right-hand edge, extending the four
size buttons upstream already had. **That is gone.** The released generator dropped the
on-screen column for a right-click context menu, and this now matches it: `ui/ContextMenu.hx`
holds the sizes, **New City**, toggles for walls / ring / citadel / plaza / river, and both
exports. `Button`, `CitySizeButton`, `ActionButton`, `ToggleButton` and `Menu` were all
deleted with it. `S` and `P` still work.

Things worth knowing if you touch it:

- ⛔ **`stage.showDefaultContextMenu = false` is what suppresses the browser's own menu,
  and there is no other hook.** Lime calls `preventDefault` on the `contextmenu` event only
  when OpenFL has cancelled the mouse event underneath it, and OpenFL only cancels it when
  that flag is false. Verified rather than assumed: a `contextmenu` listener on `window`
  reports `defaultPrevented: true` on the canvas.
- **The menu clamps itself into the window.** The map fills the window now, so the corners
  are ordinary places to right-click, and a menu that opens at the cursor would hang off
  the bottom right — which is where a 12-row menu is taller than the space under the
  cursor almost anywhere.
- ⚠️ **The tooltip needed two fixes to coexist with it.** `Tooltip.blocked` stops a patch
  under the open menu from raising its label — clearing the tooltip once on open is not
  enough, because the cursor is still over the patch. And `Tooltip.place` is now called
  from `set` as well as from mouse-move: regenerating builds a new scene under a cursor
  that has not moved, so the new patch's label used to appear in the top-left corner and
  stay there until the mouse was nudged.
- **A hint reads `right-click for options`** until the menu is first opened
  (`ContextMenu.everOpened`, static so it survives the scene rebuild). Without it this
  change would undo the discoverability the menu was built for in the first place. It uses
  `Main.hintFont`, because `Main.uiFont` is the paper colour — invisible on the map.

A toggle reads its state from the finished `Model` (`model.wall != null`), not from
`StateManager`, so it shows what the map actually has. Those differ whenever a parameter
was left to be rolled, which is the default for walls, citadel and plaza.

Two things this turned up:

- ⛔ **The size buttons wrote a seed to the URL and then built with a different one.**
  `CitySizeButton` pushed `Random.getSeed()` into the address bar and called
  `new Model( size )`, whose seed argument defaults to -1 and falls back to `opts.seed` —
  the seed inside the `Model.options` built at startup, which nothing ever refreshed. So
  the URL described a city that was never drawn, and clicking the same size twice gave the
  same map twice. Everything that regenerates now goes through `StateManager.regenerate`,
  which does both halves. Verified: click **New City**, then reload the URL it wrote, and
  the exported SVG hashes identically.
- **`Tooltip` clamps itself to the window.** It was `mouseX + 4`, and the menu is against
  the right-hand edge — so every hint the menu raised started off the side of the screen.

### 4. ✅ Rivers — done, and they do not change the city

> ⛔ **The constraint was that a river must not break existing seeds, and it is met by
> not drawing from `Random` at all** — not by drawing carefully.
>
> The pattern this handoff suggested was the plaza/citadel/wall one: always draw the roll,
> then override it. That keeps `river=0` and `river=1` agreeing with each other, but a
> fourth roll still shifts the sequence against every map made before it existed, and it
> would have cost the README's "seeds still reproduce upstream's cities". So `River` takes
> an `Rng` of its own — the same generator with its own state, seeded from the city's seed
> so it stays reproducible — and runs **after** `buildGeometry`, on a layout that is
> already finished.
>
> The consequence is that there is **no river roll**, and there cannot be one: a roll has
> to come out of the city's own sequence to be reproducible from the seed. `river=1` is
> opt-in, which is what a GM mapping a named settlement wants anyway.

Measured, not asserted. On `?size=24&seed=149&walls=1` with and without it, the `roads` and
`walls` groups of the exported SVG hash identically, and **every building in the wet map is
also in the dry one** — 785 of the dry map's 857, so the river only ever takes buildings
away. Compare polygon `points` strings as a set; it is a stronger check than a hash,
because it tells you a difference is a *subset* rather than merely a difference.

What it costs: the wards do not know about the water, because nobody can site a district
against a river that does not exist yet. The buildings under it are cleared afterwards
instead, and the population falls with them — `Model.recountBuildings` exists for that.

Things worth knowing if you touch it:

- **The course follows patch boundaries**, like the inner ring, because an edge is a line
  the generator has already agreed nothing is built on. It pays a toll to run along a
  street or across the plaza, so it crosses roads rather than flowing down them.
- ⚠️ **Short segments are dropped before smoothing.** A patch boundary can turn most of a
  right angle between two vertices a few units apart, and offsetting a corner that sharp
  folds the far bank back over itself — which draws as a notch bitten out of the river.
- ⚠️ **A bridge is forced where none was found.** The street network is built before the
  river exists, so whether a street crosses the water is luck, and on a small town with two
  streets it is usually bad luck. Without the fallback, `?size=6&seed=2024&river=1` was a
  walled town cut in half with no way across.
- **Buildings are cleared by any corner in the water**, not by their centre. Centre-only
  left blocks sliced by the bank standing in the current.
- **`LabelPlan` reserves the water** before it places anything, so no name is printed
  mid-current. Hand-named districts still override that, because `fitInsistent` does.

### Farmland, added after the fact

A farm was its farmhouse and nothing else — four units square in a patch a hundred units
across — so it was indistinguishable from open country on the map, and only the hover label
gave it away. `Farm.fields` parcels the patch; `CityMap.drawFarmland` and the SVG's
`fields` group draw the boundaries.

- ⛔ **`Farm.createGeometry`'s three `Random` draws are untouched and must stay that way.**
  They site the farmhouse out of the shared sequence, so adding to them or reordering them
  moves every building in every city that contains a farm. The parcelling uses an `Rng`
  seeded from the patch's own centroid, which needs nothing from the sequence — and `Cutter`
  is pure geometry with no `Random` in it, which is what makes that possible.
- **Fields are not in `Ward.geometry`.** Geometry is buildings and buildings are what the
  population is counted from, so a farm placed inside the city with `districts=farm:…` would
  otherwise report its fields as houses.
- ⚠️ **`MAX_DEPTH` caps the recursion at five bisections**, however large the patch. This is
  the same recursion shape that already overflows the stack in `createAlleys`; a hard cap
  costs a few oversized parcels on a metropolis and cannot run away.
- **Farmland is drawn before the roads**, in its own pass rather than inside the patch loop,
  so a road crosses a field instead of being buried under one — and so the screen agrees
  with the order the SVG writes its groups in.

### Warnings on the map

`Model.placementWarnings` was write-only in practice: a caller could read it from code, but
the URL is the whole interface, so a district that quietly landed somewhere else looked
exactly like one that landed where it was asked. `TownScene.showWarnings` prints them in the
corner, wrapped to the window with `BitmapText.split` and on a paper backing so they stay
legible over countryside.

- ⚠️ **On screen only, and that is deliberate.** A warning is for tuning the URL; baking it
  into the export would put scaffolding in the finished artifact. It works because both
  exporters draw from the model or from `CityMap`, and this belongs to the scene — the same
  reason the right-click hint stays out of them. Checked, not assumed: the exported SVG
  matches neither "nothing free" nor "right-click".
- **Rebuilt in `layout`**, not the constructor, because the wrap width is the window's.

### Deliberately not doing

All four items above are done, so this is what remains of the version gap to the released
0.11.4 — and it is still the part not worth building.

- **The 0.8.0 building algorithm.** Buildings are texture at map scale; nobody reads an
  individual house. ⚠️ If this is ever revisited, note that **building count feeds the
  population figure at ×6** — a change to the algorithm shifts the calibration with it.
- **Straight-skeleton label placement** (0.11.1) — see 2 above.
- **Armoria** (0.8.2) — decorative, a third-party dependency, and it presumes a settlement
  has a single coat of arms.
- **Coast, warp, forests, alleys/roof/district views** — cosmetic.

---

## Traps

**openfl 8.9.0 cannot compile on Haxe 4.** It still uses `@:fakeEnum`, removed in Haxe 4.
`project.xml` is repinned to lime 8.3.2 / openfl 9.5.2. Do not "restore" the original pins.

**Two upstream source fixes were needed for the same reason**, and are unrelated to any
feature here: `Polygon.get_square` called the static extension `last()` bare inside an
abstract, and `Ward.filterOutskirts` mixed `Int` and `Float` branches in one array
comprehension.

**`CommonWard` is not a placeable ward.** It is the base class, and its constructor takes
`minSq` / `gridChaos` / `sizeChaos` as well as `(model, patch)`. Building one with two
arguments leaves `minSq` null, `Ward.createAlleys` never meets its termination condition,
and you get a stack overflow and a black map. Every *concrete* ward takes two arguments —
but note they declare it as `public inline function new`, so a grep for
`public function new` will not find them and will make the safe ones look unsafe.

**There is a pre-existing crash that is not ours.** The console shows a `RangeError` from
`createAlleys` recursion. It reproduces with every fork feature off — `?size=24&seed=149`
alone — so it is upstream's own recursion depth. Non-fatal; the model's retry loop
recovers. Worth fixing if it ever starts eating seeds.

**Placement failures do not throw.** A zone that cannot be satisfied falls back to anywhere
in the city, because an impossible spec would otherwise rebuild the city forever. Check
`Model.placementWarnings` to tell *the district is where I asked* from *the district is
somewhere*.

---

## Testing what you cannot click

Haxe's html5 output is **module-scoped**. Classes are not on `window`, so you cannot poke
`Model.instance` from the console even though class names appear in stack traces.

Synthetic key events from an automation harness may not reach OpenFL, which listens on
`window`. **Mouse events do**, which is what makes the context menu testable: a harness
right-click opens it, hovering highlights a row, and clicking one runs it. A harness
`Escape` does *not* arrive — dispatch it on `window` yourself, as below, before concluding
the handler is broken.

To verify the exporters end to end, intercept the download instead:

```js
window.__captured = null;
const orig = URL.createObjectURL.bind(URL);
URL.createObjectURL = b => { window.__captured = b; return orig(b); };
HTMLAnchorElement.prototype.click = function(){ window.__clicked = this.download; };

const e = new KeyboardEvent('keydown', { key:'s', bubbles:true });
Object.defineProperty(e, 'keyCode', { get: () => 83 });   // S = 83, P = 80
window.dispatchEvent(e);

// then: await window.__captured.text()  → parse with DOMParser
//       await createImageBitmap(window.__captured)  → check PNG dimensions
```

That is how the SVG was confirmed well-formed with all landmarks present, and the PNG
confirmed a real 2048×2048.

---

## Calibration

Two constants, derived independently, that agree — so changing one means rechecking the other.

| Constant | Value | Where it came from |
|---|---|---|
| `Model.METRES_PER_UNIT` | 4 | `MAIN_STREET` is 2 units; a main street is about 8 m |
| population | `buildings × 6` | The released generator's own readout across four sizes, 6.0–6.2 throughout |

Together they put a 2,100-person town at roughly 18 hectares, which is right for the
period. **They are a cross-check, not two independent guesses** — if buildings get smaller
or denser, both need revisiting.
