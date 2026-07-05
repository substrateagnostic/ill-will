# Cosmetics system — verification

Generated 2026-07-05 via Meshy.ai text-to-3D (paid account), model `meshy-5`,
triangle topology, target polycount 8000, preview → refine → GLB into
`assets/models/meshy/cosmetics/`. 8 cosmetics; 7 succeeded first try, the halo
needed one regeneration (first attempt produced a vertical double-ring).

System: `core/cosmetics.gd` (autoload-ready, **not** registered — the director
wires the store/autoload). Registry with per-cosmetic size (height- or
width-normalized via the MeshyProp AABB math), seat offset on the KayKit `head`
BoneAttachment3D, optional horizontal `xz_scale` stretch, optional per-character
overrides, optional material override, and per-player persistence in
`user://cosmetics.json`. Head cosmetics hide the character's stock headwear
(Barbarian bear hood / Knight helmet / Mage wizard hat) while worn and restore
it on unequip — this is how the Mage's big hat is "replaced convincingly".
The Rogue GLB ships **without** a `head` BoneAttachment3D; equip() creates one
on the `head` bone at runtime.

Logic test: `godot --headless --script res://scripts/dev/test_cosmetics.gd`
→ `COSMETICS_TEST PASS` (16 checks: Rogue attachment creation, slot replace,
unequip restore, headwear hide/restore, save/load/remove persistence,
apply_to_character round-trip).

## Probe

`tools/wardrobe_probe.tscn` — all four KayKit characters in a row, house
lighting, idle animation (hats ride the head bone), stock weapons hidden.
Auto-cycles every cosmetic; `--cosmetic=id` pins one; `--combo=a,b,c,d`
dresses each character differently.

```
godot --path . tools/wardrobe_probe.tscn -- --shots=25,70,115,160,205,250,295,340,385 --outdir=verify_out/wardrobe
```

Fit was iterated over 4 windowed probe rounds (raw captures gitignored in
`verify_out/wardrobe*/`); final screenshots checked into `docs/verify/shots/`.

## Verdicts (per hat, per character — judged from screenshots)

| Cosmetic | Barbarian | Knight | Mage | Rogue | Verdict | Screenshot |
|---|---|---|---|---|---|---|
| party_cone | Sits on bald crown, jaunty | On hair, clean | In black hair, clean | On hair, clean | **KEEP** | `shots/cosmetics_party_cone.png` |
| flower_crown | Wreath hugs crown, sprigs frame temples | Ring nestles in blond hair | Sits in hair, dainty | Good; side sprigs stick out a touch far | **KEEP** (sprig quirk noted) | `shots/cosmetics_flower_crown.png` |
| viking_helm | Best-in-batch — horns + his beard | Proper helm, cheek guards frame face | Covers skull over hair | Great with long hair | **KEEP** | `shots/cosmetics_viking_helm.png` |
| chef_hat | Proper toque proportions (xz_scale 1.5) | Clean | Clean | Clean | **KEEP** | `shots/cosmetics_chef_hat.png` |
| halo | Floats over bear hood | Floats over helmet spikes | Rings the wizard hat tip — delightful | Floats over hair | **KEEP** (gold emissive material override; keeps stock hats visible) | `shots/cosmetics_halo.png` |
| jester_cap | Band sits snug on brow | Charming | Charming | Charming | **KEEP** | `shots/cosmetics_jester_cap.png` |
| tophat_monocle | Dapper, brim over brow | Fixed hair clip via per-char +0.08y | On hair, clean | On hair, clean | **KEEP** | `shots/cosmetics_tophat_monocle.png` |
| propeller_beanie | Hugs skull, brim over brows | Covers fringe | Clean | Clean | **KEEP** (nudged back −0.05z to bury an internal stub) | `shots/cosmetics_propeller_beanie.png` |

Bare-head baseline (stock hats hidden): `shots/cosmetics_bare.png`.
Favorite combo (viking / tophat / halo / flower_crown):
`shots/cosmetics_combo.png`.

**8 / 8 KEEP. No REGENERATE-LATER outstanding** (halo regenerated once during
this pass; its harlequin texture is masked by a gold emissive override in the
registry — geometry is a clean flat torus).

Style note: like the first Meshy batch, refined models carry baked flat-ish
textures a touch richer than pure Kenney/KayKit, but they sit comfortably in
the warm house lighting. The viking helm's hidden red war-mask (Meshy added
one despite the prompt) is buried inside the head volume at the shipped scale;
at `size >= 1.9` it emerges over the face — do not scale it up.

## Generation prompts + Meshy task IDs

Common suffix on every prompt: *"low poly, chunky toy-like, flat colors,
single object, hat/accessory only, no head, game asset, Kenney style"*.

| Asset | Prompt (before suffix) | Preview task | Refine task |
|---|---|---|---|
| party_cone | A festive birthday party cone hat, tall cone with diagonal candy stripes and a fluffy pom pom ball on the tip | `019f3094-a42b-72e7-b4ab-7324cd864655` | `019f3098-b697-7321-9f57-235575e62011` |
| flower_crown | A flower crown circlet, an open ring headband woven of daisies, pink flowers and green leaves | `019f3094-af57-72e9-bf4e-af1cef8c6137` | `019f3098-bb87-7322-9703-6cda91408ad5` |
| viking_helm | A horned viking helmet, rounded iron dome with rivets and two big curved horns on the sides | `019f3094-b957-728d-8acf-415b62b53b9a` | `019f3098-c0f8-7281-a976-3eee08d405b2` |
| chef_hat | A tall white chef toque hat, puffy pleated cylindrical top above a simple band | `019f3094-c33d-728e-bd85-d621eb57c97b` | `019f3098-c617-7282-ab0e-0131902ef7c1` |
| halo (regen) | A single golden angel halo ring lying flat and horizontal like a donut on the ground, one smooth chunky gold torus, nothing else | `019f30a1-f6f8-7526-a73f-b09bf3acbab0` | `019f30a2-cd03-7591-ba27-c15c4e91b75e` |
| jester_cap | A jester cap hat with three drooping fabric points each ending in a round gold bell, purple and gold panels | `019f3094-d527-728f-adcd-427e6ca88191` | `019f3098-cff9-73ba-8330-3066275551ff` |
| tophat_monocle | A black gentleman top hat with a red ribbon band, a round gold rimmed monocle lens attached to the front brim by a short chain | `019f3094-def2-72f3-bb92-9943a685b03a` | `019f3098-d4ca-7283-8a1d-ce2cf8c3945e` |
| propeller_beanie | A propeller beanie cap, a small rounded skullcap of alternating red yellow and blue segments with a two blade propeller on a stem on top | `019f3094-e9c1-7295-bed7-8d61fd6403ce` | `019f3098-d99d-7296-a12f-745d9d671b12` |

(The abandoned first halo: preview `019f3094-cbc4-72f2-81ce-505ab313e08c` —
vertical double-ring, rejected on sight.)

## Suggested store prices (director tunes)

| Cosmetic | Royalties | Grudge | Rationale |
|---|---|---|---|
| propeller_beanie | 100 | 0 | Starter charm |
| party_cone | 120 | 0 | Cheap, iconic |
| chef_hat | 140 | 0 | Mid |
| flower_crown | 150 | 0 | Mid, pretty |
| jester_cap | 180 | 15 | You will be mocked |
| viking_helm | 200 | 25 | Intimidation tax |
| tophat_monocle | 250 | 40 | Old money |
| halo | 300 | 0 | Earned innocence — the flex item |

## Integration status

**Not integrated.** `core/cosmetics.gd` is autoload-ready; the director
registers the autoload and builds the store UI (estate/ untouched per brief).
License/provenance: `assets/models/meshy/LICENSE-NOTE.md`.
