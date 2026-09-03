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
- **SVG and PNG export** on the `S` and `P` keys

---

## What to do next, in order

The order matters more than the list, and it is **not** the order you would get from
working down the version gap to the released 0.11.4.

### 1. ✅ Custom district names — done

`districts=` takes `ward:zone:Name`. `WardPlacement` has a `name` field, `parsePlacements`
no longer lowercases the whole entry (only the ward and zone tokens), and `placeWards` sets
`ward.name`, which `nameWards` then leaves alone.

⚠️ **`nameWards` still rolls the generated name for a district the caller named, and throws
it away.** `buildGeometry` runs after `nameWards` and draws from the same sequence, so
skipping the roll would move every building in the city — naming a district would silently
relayout the map. Same pattern as the plaza/citadel/wall rolls. Verified: `#buildings`
hashes identically with and without the names on `?size=24&seed=149&…`.

Landmarks are kept off hand-named districts (`Model.namedPatches`), since a landmark
supersedes the district label it lands on.

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
- **`MIN_FIT` is now a floor under *every* label**, applied in `LabelPlan.reserve`, not
  just the district names that are sized against a patch. Landmark names, the population
  line and the scale caption are all a share of `cityRadius`, and at size 15 that share was
  about half the size at which anything is readable — the names the caller cared about most
  were the least legible text on the map.
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
> overlapping pairs to none.

### 3. A menu — moderate

Export and labels are behind undiscoverable keypresses. `ui/` has `Button.hx` and
`CitySizeButton.hx` to build on. This is a bigger job than the exporters were.

### 4. Rivers — large, and the only large thing worth doing

Everything else in the version gap is cosmetic. Rivers are not: they are the reason
riverside settlements can be mapped at all.

> ⛔ **Rivers are the only remaining feature that changes generation, and they must not
> break existing seeds.**
>
> Names and collision rejection touch labels, not layout; a menu touches neither. A river
> carves through the patch layout, so **if river code draws from `Random` when `river=0`,
> it shifts the sequence and every previously chosen seed produces a different city** —
> including landlocked ones that will never have a river.
>
> Follow the pattern already in `Model.new`: the plaza, citadel and wall rolls are **always
> drawn, in the original order**, and only then overridden, so setting one parameter cannot
> silently relayout the map. Do the same for the river roll, and do any river-specific
> geometry **after** the patch layout is fixed.

### Deliberately not doing

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
`window`. To verify the exporters end to end, intercept the download instead:

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
