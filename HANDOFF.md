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

> ⛔ **A long custom name is dropped, not shrunk.** `LabelView.fit` returns null below
> `MIN_FIT`, so "The Velvet Road" vanished from `?size=24&seed=149&…` while "Velvet"
> printed. A name the user typed by hand is the one label that must never silently
> disappear — fixed as part of 2 below.

### 2. Label collision rejection — cheap, and now worth it

`LabelView.fit` sizes each label to its own patch and knows nothing about its neighbours,
so labels in small adjacent patches can collide. The released generator solved this
properly in 0.11.1 with straight-skeleton placement; **that is not what to build.** Keep a
list of placed label bounding boxes, test each new one against it, and drop or shrink on
overlap. Most of the benefit, a fraction of the work.

Reserve in priority order — title, population line, scale caption, landmarks, **hand-named
districts**, then generated names — and only let the last group be dropped. A hand-named
district should also be clamped to `MIN_FIT` rather than dropped, per the note above.

⚠️ **Whatever you build has to run identically in `CityMap.addLabels` and
`MapExporter.addLabels`**, which are two parallel loops over `model.patches` today.
Collision rejection depends on placement order, so parallel code will drift into
disagreement between the screen and the SVG. Compute the placements once and have both
renderers consume them.

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
