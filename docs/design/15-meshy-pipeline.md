# 15 — Meshy AI Pipeline (research digest + design, not yet built)

Date: 2026-07-15. Engine: Godot 4.6.2. Research pulled live from `docs.meshy.ai`
(fetched today — see citations per section; do not trust training-data memory
of this API, it has changed materially since Meshy-5).

**Scope note:** this doc is a reference + design proposal. No pipeline code
is written here (per brief). Section 5 is a script spec an implementer can
build from directly.

---

## 0. What already exists in this repo (read this first)

The project has run **three manual Meshy batches already** — there is no
automation yet, but there is an established convention this new pipeline
must slot into, not replace:

- `assets/models/meshy/` — flat dir of generated `.glb` + extracted `_0.jpg`
  texture siblings (Godot's import setting `gltf/embedded_image_handling=1`
  = *Extract Textures*, so every GLB's embedded image gets pulled out to a
  sibling file on import — this is already the default in this project, not
  something a new pipeline needs to configure).
- `scripts/meshy_prop.gd` (`MeshyProp` class) — the **scale-normalization
  helper every Meshy asset goes through at integration time**. Critical
  context: *"Meshy normalizes every model to a ~1.9-unit max dimension with
  an arbitrary internal origin"* — raw instancing is never usable as-is.
  `MeshyProp.instance(path, target_height, yaw_deg, base_at_zero, center_xz)`
  measures the merged AABB, scales to a target height, and re-seats the
  origin to (base-at-zero, centered-xz). Any new batch's props get consumed
  through this same helper, not a new one.
- `tools/asset_probe.tscn` / `tools/asset_probe.gd` — auto-discovers every
  `.glb` in `assets/models/meshy/` (or a cosmetics subfolder pattern), racks
  them on pedestals next to a 1.8 m reference capsule under house lighting,
  prints each AABB to stdout, and takes windowed screenshots at scripted
  camera passes (`--shots=60,110,170,230,290`). **This is the report-sheet
  mechanism the brief asks for in section 5 — reuse it, don't rebuild it.**
- `docs/verify/meshy-assets-VERIFY.md`, `cosmetics-VERIFY.md`,
  `visual-polish-VERIFY.md` — the provenance/verdict-table convention: every
  batch gets a markdown table of asset name, prompt, preview task ID, refine
  task ID, AABB, and a KEEP/REGENERATE-LATER/REJECT verdict from eyeballing
  probe screenshots. A new gothic-props batch should produce
  `docs/verify/gothic-props-VERIFY.md` in the same shape.
- `assets/models/meshy/LICENSE-NOTE.md` — records that all these assets were
  generated on Alex's **paid** Meshy account (commercial-use ownership); a
  new batch needs one more line appended, not a new file.
- Prior generations used `model: meshy-5`, `model_type: lowpoly`,
  `topology: triangle`, `target_polycount: 8000`, common suffix: *"low poly,
  chunky toy-like proportions, flat colors, no textures needed, game asset,
  clean silhouette, single object, Kenney/KayKit style."* Regen rate so far:
  1/18 assets needed a redo (halo ring, wrong topology on first pass) — a
  ~5-6% retry rate is a reasonable budget assumption.
- Godot headless import is already wired in `build/package.ps1`: exactly
  `& $Godot --headless --path . --import --quit` (line 90) — this is the
  correct invocation for the new pipeline too; no flags need inventing.
- Collision convention: Meshy props in this project are **visual overlays
  only**. Gameplay collision stays as hand-authored primitive
  `CollisionShape3D`s already sized to a trap/prop's footprint; the GLB is
  scaled via `MeshyProp` to sit inside that existing footprint (see
  `07-visual-polish-audit.md`: *"Meshy iron press-head/anvil block scaled
  into the exact 0.85×0.55×0.85 hammer footprint (collision untouched)"*).
  **Do not turn on Godot's automatic trimesh/convex collision generation on
  import for this batch** — it's not the house pattern and most gothic
  estate props (gravestones, medals, trophies, candelabras, board pieces)
  are static set dressing that either has no collision or reuses an
  existing primitive.

---

## 1. API surface

Base URL and auth are uniform across every endpoint:

```
https://api.meshy.ai/openapi/v{1,2}/...
Authorization: Bearer ${MESHY_API_KEY}
Content-Type: application/json
```

(Text-to-3D is on `v2`; Image-to-3D, Retexture, Remesh, Rigging, Animation
are on `v1`. Mixed versioning is real, not a typo — verified independently
on both the quick-start and text-to-3d reference pages.)
[Quickstart](https://docs.meshy.ai/en/api/quick-start) ·
[Text to 3D](https://docs.meshy.ai/en/api/text-to-3d)

### Text to 3D — `POST/GET/DELETE /openapi/v2/text-to-3d[/:id]`, `GET .../:id/stream` (SSE)

Two-call workflow sharing one endpoint, distinguished by `mode`:

**`mode: "preview"`** (untextured geometry only):

| Param | Type | Default | Notes |
|---|---|---|---|
| `prompt` | string | — | required, max 600 chars |
| `model_type` | string | `standard` | `standard` \| `lowpoly` |
| `ai_model` | string | `latest` | `meshy-5` \| `meshy-6` \| `latest` (→ meshy-6) |
| `topology` | string | `triangle` | `quad` \| `triangle` |
| `target_polycount` | int | 30000 | 100–300000 |
| `decimation_mode` | int | — | adaptive levels 1–4, overrides polycount |
| `pose_mode` | string | `""` | `a-pose` \| `t-pose` \| `""` |
| `should_remesh` | bool | false (v6) / true (older) | |
| `target_formats` | string[] | all but 3mf | `glb,obj,fbx,stl,usdz,3mf` |
| `origin_at` | string | `bottom` | `bottom` \| `center` |
| `auto_size` | bool | false | AI-estimated real-world scale |
| `moderation` | bool | false | |
| `art_style` | string | `realistic` | **deprecated, ignored on meshy-6** |

**`mode: "refine"`** (texture the preview mesh; `preview_task_id` must be
`SUCCEEDED`):

| Param | Notes |
|---|---|
| `preview_task_id` | required |
| `texture_prompt` | max 600 chars, optional |
| `texture_image_url` | optional, mutually exclusive-ish with texture_prompt |
| `enable_pbr` | bool, default false — metallic/roughness/normal(+emission on v6) |
| `hd_texture` | bool, default false — 4K base color, meshy-6+ only; PBR maps stay 2K |
| `remove_lighting` | bool, default **true** — strips baked highlights/shadows (v6+) |
| `ai_model`, `target_formats`, `moderation`, `origin_at` | same as preview |

Task object: `id`, `status` (`PENDING/IN_PROGRESS/SUCCEEDED/FAILED/CANCELED`),
`progress` (0-100), `model_urls` (per-format URLs), `thumbnail_url`,
`texture_urls[]` (PBR channel URLs when `enable_pbr`), `created_at`,
`consumed_credits`, `preceding_tasks` (queue position while PENDING),
`task_error`.
[Text to 3D API](https://docs.meshy.ai/en/api/text-to-3d)

### Image to 3D — `POST/GET/DELETE /openapi/v1/image-to-3d[/:id]`

Single-call (mesh + texture together), one of `image_url` or
`input_task_id` required. Same shared params as above (`ai_model`,
`topology`, `target_polycount`, `enable_pbr`, `hd_texture`, `target_formats`,
`origin_at`, `auto_size`) plus:

- `model_type`: `standard` \| `smart-topology` \| `lowpoly` (deprecated).
  **Smart Topology** is new (`meshy-t2` default model, `meshy-t1` legacy) —
  "cleaner topology, natively separated parts, triangle output," polycount
  range 100–15,000 instead of 300,000, cheaper (5/15 credits vs 20/30).
- `should_texture` (bool, default true), `image_enhancement` (bool, default
  true, v6+ only), `multi_view_thumbnails` (bool, +3s latency, 4 cardinal
  thumbnails).
- Deprecated: `symmetry_mode`, `is_a_t_pose`.

Not relevant to this batch (all props start from text prompts, not
reference photos) but documented for completeness since the brief asked.
[Image to 3D API](https://docs.meshy.ai/en/api/image-to-3d)

### Text to Texture — `POST/GET/DELETE /openapi/v1/retexture[/:id]`

Now called **Retexture** in current docs (the brief's "text-to-texture" is
this endpoint). Applies a new texture to an existing mesh: one of
`input_task_id` or `model_url` (accepts `.glb/.gltf/.obj/.fbx/.stl`), plus
one of `text_style_prompt` or `image_style_url` for the styling. Same
`enable_pbr`/`hd_texture`/`remove_lighting`/`target_formats` knobs as
refine. `enable_original_uv` (bool) preserves the source UV layout instead
of re-unwrapping — useful if you already like a mesh's topology and just
want a different skin.
[Retexture API](https://docs.meshy.ai/en/api/retexture)

### Remesh — `POST/GET/DELETE /openapi/v1/remesh[/:id]`

Post-process an existing mesh's topology/polycount without regenerating
geometry: `target_polycount`, `topology`, `decimation_mode`,
`target_formats` (adds `blend` to the format list vs. the others),
`origin_at`. Useful if a preview comes back at too high a polycount for a
small board-piece prop and you don't want to spend a full new preview.
[Remesh API](https://docs.meshy.ai/en/api/remesh)

### Auto-Rigging & Animation — `POST/GET/DELETE /openapi/v1/rigging[/:id]`, `POST /openapi/v1/animations`

Exists, but **out of scope for this props batch** (gravestones/medals/
trophies/candelabras/board pieces don't need skeletons). Documented since
the brief asked "if available": rigging takes `input_task_id` or
`model_url` + `height_meters` (default 1.7), requires a **textured humanoid
model under 300,000 faces**, outputs rigged FBX/GLB plus optional walk/run
animations. A 594+ entry animation library exists, addressed by
`action_id` against `POST /openapi/v1/animations`. This is the tool to
reach for later if the anthology ever wants Meshy-generated NPCs instead of
KayKit stock characters — not now.
[Rigging API](https://docs.meshy.ai/en/api/rigging-and-animation) ·
[Animation Library](https://docs.meshy.ai/en/api/animation-library)

### Auth, polling, rate limits

- Header: `Authorization: Bearer ${MESHY_API_KEY}` (matches the brief's env
  var name exactly — no translation needed).
- **Polling pattern** (this is the only supported pattern for a batch
  script; SSE/webhooks exist but add complexity a one-shot batch tool
  doesn't need): POST to create → get `id` back immediately → `GET
  .../:id` on an interval until `status == "SUCCEEDED"` (or `FAILED` /
  `CANCELED`) → read `model_urls`.
- **Rate limits** are two independent buckets, enforced per-account across
  all API keys: requests/second, and concurrent queued generation tasks
  (Text-to-3D, Image-to-3D, Retexture, Remesh count against this; Rigging/
  Animation do not). Pro tier (this project's plan, per
  `LICENSE-NOTE.md`): **20 req/s, 10 concurrent queued tasks**. Exceeding
  either returns `429`, distinguished by error subtype
  `RateLimitExceeded` vs `NoMoreConcurrentTasks`.
  [Rate Limits](https://docs.meshy.ai/en/api/rate-limits)
- Error codes: `400` bad params, `401` auth, `402` insufficient credits,
  `429` rate limit. Failed tasks refund credits (`consumed_credits: 0` on
  `FAILED`).
- Asset URLs are **not permanent** — `expires_at` on the task object;
  non-Enterprise retention is a matter of days. **Download GLBs into the
  repo immediately after SUCCEEDED; never store a `model_urls.glb` link as
  the source of truth.**

---

## 2. Output formats

Every generation/refine/retexture/remesh endpoint accepts a
`target_formats` array (defaults to every format except `3mf`):

| Format | Availability | Notes |
|---|---|---|
| `glb` | all endpoints | **the one this project uses** — self-contained, embeds textures |
| `fbx` | all endpoints | no material embedding parity with glb; not used here |
| `obj` + `mtl` | all endpoints | no PBR, no rig; not used here |
| `usdz` | all endpoints | AR-oriented (iOS Quick Look); not relevant to a Godot game |
| `stl` | all endpoints | geometry-only, no material; 3D-print oriented |
| `3mf` | opt-in only, multi-color print oriented | not relevant |
| `blend` | Remesh endpoint only | not others |

**Request only `glb`** (`target_formats: ["glb"]`) — every other format is
wasted generation/storage for this project; the existing convention
(`assets/models/meshy/*.glb`) never touches FBX/OBJ/USDZ.

**PBR maps**: `enable_pbr: true` returns `texture_urls[]` with
`base_color`, `metallic`, `roughness`, `normal`, and (meshy-6+) `emission`
channels, baked into the GLB's material *and* exposed as separate URLs.
`hd_texture: true` bumps `base_color` to 4K (meshy-6+ only; the PBR
side-channels stay 2K regardless). **Recommendation for this batch: leave
`enable_pbr` off.** The existing 18-asset batch shipped without it and the
verify docs note the flat-ish baked textures already read a shade richer
than Kenney/KayKit's flat-color look — full PBR (specular highlights,
normal-mapped micro-detail) would push further away from the stylized
target, not closer. This matches the "flat colors, no textures needed"
suffix already in use.

**Polycount control**: `target_polycount` (100–300,000, applies at preview
or remesh time) is the lever, not `art_style` (deprecated/ignored on
meshy-6). `decimation_mode` (1-4) is an alternate adaptive-LOD-style knob
that overrides `target_polycount` when set — leave unset and use explicit
polycount numbers per prop tier (see §5 manifest design).

**Topology**: `triangle` (default) vs `quad`. **Use `triangle`.** Quad
topology only matters if the mesh will be hand-retouched in Blender before
import; Godot triangulates on import regardless, so requesting quad buys
nothing for this pipeline and Meshy's quad remesh pass adds latency/cost
risk for no visible benefit.

**Texture resolution**: controlled indirectly via `hd_texture` (2K vs 4K
base color only — there's no explicit numeric resolution parameter
documented). 2K (`hd_texture: false`, the default) is correct for hand-held
props viewed from a diorama camera distance; 4K is wasted VRAM for this use
case.

Sources: [Text to 3D](https://docs.meshy.ai/en/api/text-to-3d) ·
[Image to 3D](https://docs.meshy.ai/en/api/image-to-3d) ·
[Retexture](https://docs.meshy.ai/en/api/retexture) ·
[Remesh](https://docs.meshy.ai/en/api/remesh)

---

## 3. Prompt craft for a consistent gothic-estate batch

### What's confirmed vs. not

**Negative prompts are not a real feature.** Meshy's own help center states
Meshy-4/5 don't support negative prompting, and the current `text-to-3d`
API reference has no `negative_prompt` field — some third-party
guides/wrappers show one, but it isn't in the official schema fetched
today. **Do not budget on excluding unwanted elements via a negative
prompt field; write positive prompts precise enough that there's nothing
to exclude**, and treat a bad first pass as a prompt-rewrite + regenerate,
not a negative-prompt tweak. [Help center: negative
prompt](https://help.meshy.ai/en/articles/9992028-how-to-use-negative-prompt-for-text-to-3d-i-can-t-find-any-text-input-to-enter-one)

**`art_style` is deprecated and ignored on meshy-6** — style consistency
has to come entirely from prompt wording, not a style enum.

### Technique: shared suffix (already proven in this repo)

The existing 3 batches already validated the exact mechanism the brief
asks about — a **common style suffix appended to every per-asset prompt**,
changed only when the target character (prop vs. hat) shifts:

> Props batch: *"low poly, chunky toy-like proportions, flat colors, no
> textures needed, game asset, clean silhouette, single object,
> Kenney/KayKit style."*
> Cosmetics batch: *"low poly, chunky toy-like, flat colors, single object,
> hat/accessory only, no head, game asset, Kenney style."*

18/18 assets across two batches landed KEEP or KEEP-with-note; only 1
needed a regenerate (wrong topology, not a style miss). This is strong
in-house evidence the suffix technique works for this pipeline and should
be reused verbatim in structure for the gothic batch, just re-worded for
the darker material:

**Proposed suffix for this batch:**

> *"low poly, chunky toy-like proportions, flat matte colors, subtly worn/
> weathered surface, gothic dark-comedy haunted-estate prop, no fine
> engraved text, game asset, clean readable silhouette, single object,
> Kenney/KayKit style, no realistic photoreal detail."*

Notes on the additions vs. the original suffix:
- *"no fine engraved text"* — gravestones and trophy plaques are exactly
  the kind of prop where a text-to-3D model will try to sculpt illegible
  epitaph/inscription geometry into the mesh; suppress it explicitly since
  there's no negative-prompt escape hatch.
- *"subtly worn/weathered"* — carries the gothic-estate material read
  (stone, tarnished metal, dusty velvet) without asking for "dark" as a
  color instruction, which risks Meshy interpreting it as literal black/
  navy geometry rather than a mood — same trap the viking helm hit when
  Meshy added an unrequested red war-mask despite a clean prompt (see
  `cosmetics-VERIFY.md`); keep material/mood words separate from shape
  words in the per-asset prompt.
- *"no realistic photoreal detail"* — meshy-6 defaults toward `realistic`
  art_style even though the param itself is ignored; the wording has to
  do the work the deprecated enum used to.

### Per-asset prompt structure

Keep the pattern from both prior batches: **shape + material + pose, in
that order, before the suffix.** e.g. for a candelabra:

> "A tall gothic candelabra with three curved wrought-iron arms holding
> stubby candles, ornate scrollwork base" + suffix

Avoid stacking more than ~2 material words (prior batches show single
dominant-material prompts — "warm polished wood," "weathered grey stone" —
outperform multi-material ones for silhouette clarity at low polycount).

### Style-consistency risks specific to this batch

- **Board-game pieces (small props)** are the highest silhouette-collapse
  risk at low polycount — a "meeple" or "chess pawn" prompt without a
  strong distinguishing shape word can converge toward a generic blob at
  1,500-3,000 tris. Front-load a strong shape noun ("a chunky wedge-top
  pawn," not "a game piece").
- **Trophies/medals** risk photoreal gold-shader temptation from meshy-6's
  realistic default — the "flat matte colors" + "no realistic photoreal
  detail" suffix clauses are load-bearing here specifically.
- Batch all prompts through the **same `ai_model` pin** (`meshy-6`, not
  `latest`) so a mid-batch Meshy model upgrade can't shift style halfway
  through — `latest` is a moving target (already `meshy-6` today, was
  `meshy-5` a week ago per changelog cadence). Pin explicitly.

---

## 4. Godot import pipeline

### Headless import

Exactly the invocation already in `build/package.ps1:90`:

```
& $Godot --headless --path . --import --quit
```

Run this once after all new GLBs land in `assets/models/meshy/` (or a
`gothic_props/` subfolder — see §5) and before opening the probe scene.
Godot auto-generates a `.import` sidecar per new `.glb` on first import
using project-wide defaults (see below); no per-asset import config is
needed unless a specific prop needs an override.

### Material handling

Meshy GLBs embed materials as glTF PBR (`baseColorTexture`,
`metallicRoughnessTexture` packed ORM-style, optional `normalTexture`,
optional `emissiveTexture`). Godot's glTF importer converts these
automatically into `BaseMaterial3D`/`StandardMaterial3D` resources — no
manual material authoring needed, same as the existing 18 assets. The
project's current import default is `gltf/embedded_image_handling=1`
(**Extract Textures** — confirmed against `throne.glb.import` and the
sibling `_0.jpg` files already in `assets/models/meshy/`), which is why
every existing Meshy GLB has a same-named `_0.jpg` sitting next to it
post-import. This is fine and matches the existing 18-asset convention;
no change needed for the new batch.

### Mesh instancing, LOD, collision

- **LOD**: `meshes/generate_lods=true` is already the project-wide default
  (confirmed in every existing `.glb.import`) — Godot auto-generates LOD
  levels via its built-in mesh simplifier at import time. Nothing to add
  per-asset.
- **Instancing**: use `MeshyProp.instance(path, target_height, ...)`
  (`scripts/meshy_prop.gd`) exactly as the existing 18 assets do — do not
  write a second scale-normalization helper. Static gothic props that
  repeat many times in one scene (e.g., a graveyard of headstones) should
  go through `MultiMeshInstance3D` if instance count gets into the dozens;
  none of the existing Meshy props do this yet, so this would be new
  ground — flag it as a decision for whoever integrates the assets, not
  something this research doc should force.
- **Collision**: per §0, this project's convention is hand-authored
  primitive `CollisionShape3D`s sized to fit the visual GLB, not
  auto-generated trimesh collision from the import. Keep that pattern for
  the new batch; most gothic set-dressing (gravestones, candelabras,
  trophies) needs no collision at all since it's non-interactive
  background/foreground dressing, matching how `stone_lantern.glb` and
  `manor_gate.glb` are used today.

### Known gotchas (confirmed against this project's own data + Godot/Meshy docs)

1. **Scale**: Meshy normalizes every export to a ~1.9-unit max dimension
   with an arbitrary internal origin (this project's own finding, recorded
   in `meshy-assets-VERIFY.md` and encoded directly into `MeshyProp`'s
   docstring). Never trust raw GLB scale — always go through `MeshyProp`
   and eyeball the printed AABB from the probe scene.
2. **Orientation**: glTF's forward convention is `+Z`/`Y-up`; Godot is also
   `Y-up`, so GLB→Godot import doesn't need a manual axis-remap the way
   Blender (`Z-up`) or some Y-up/Z-up crossover tools do. This project has
   not hit an orientation bug across 18 assets, consistent with GLB/Godot
   sharing the Y-up convention.
3. **Texture extraction side-files**: because `embedded_image_handling=1`
   is the project default, every new prop will spawn a sibling `_0.jpg` (or
   `_1.jpg`, `_2.jpg`... if PBR channels are enabled) next to its `.glb` —
   expected, not a bug; the manifest/report tooling in §5 should account
   for these appearing after import, not treat them as stray files.
4. **`should_remesh` / `target_polycount` interaction**: on meshy-6,
   `should_remesh` defaults to **false**, meaning a preview task honors
   `target_polycount` directly rather than only during a separate remesh
   pass (this differs from meshy-5's default-true behavior) — don't carry
   over meshy-5-era assumptions about needing `should_remesh: true` to get
   polycount control on meshy-6.

---

## 5. Pipeline design (spec only — no code written)

### Manifest format

`tools/meshy_batch/manifest.json` (or `.jsonl`, either is fine — JSON array
is simpler for a ~40-60 item batch):

```json
[
  {
    "name": "gravestone_cross",
    "prompt": "A weathered stone cross gravestone, rounded top, cracked base, moss patches",
    "tier": "medium",
    "target_polycount": 5000,
    "model_type": "lowpoly",
    "output": "assets/models/meshy/gothic_props/gravestone_cross.glb"
  }
]
```

Fields: `name` (also the output stem), `prompt` (per-asset, pre-suffix —
the shared suffix from §3 is appended by the script, not repeated 50
times in the manifest), `tier` (drives default `target_polycount` per
size class so authors don't hand-pick a number for every one of 50
props — e.g. `small` = 2000, `medium` = 5000, `large` = 8000, matching the
project's existing 8000-tri convention for the largest hero props), and an
optional per-asset `target_polycount` override for anything unusual.

### Script flow

```
load manifest → for each asset:
  1. SUBMIT preview  (POST v2/text-to-3d, mode=preview, suffix-appended prompt)
  2. POLL preview    (GET .../:id every ~5s, timeout ~180s, watch status)
  3. On SUCCEEDED:   SUBMIT refine (mode=refine, preview_task_id=<id>)
     On FAILED:      log + skip to next asset, record in report
  4. POLL refine     (same pattern, timeout ~240s — texture stage is slower)
  5. On SUCCEEDED:   download model_urls.glb → assets/models/meshy/gothic_props/<name>.glb
     On FAILED:      log + skip
  6. accumulate consumed_credits (preview + refine) into a running total
     against a configured budget ceiling; abort remaining queue if exceeded
→ after all assets processed:
  7. godot --headless --path . --import --quit   (batch-imports every new GLB)
  8. launch tools/asset_probe.tscn windowed with --shots=... --outdir=verify_out/gothic_probe
     (existing probe already auto-discovers new GLBs in its target dir —
      point MESHY_DIR at the gothic_props subfolder, or drop the new assets
      straight into assets/models/meshy/ root to match the existing probe's
      hardcoded path with zero code changes)
  9. write docs/verify/gothic-props-VERIFY.md skeleton (name / prompt / task
     IDs / AABB-from-probe-stdout / blank verdict column) for a human to fill
     in after reading the probe screenshots — do not auto-verdict; the
     existing convention is always a human eyeball pass
```

### Concurrency

Given the Pro-tier limit of **10 concurrent queued tasks** (§1), the
submit loop should maintain a worker pool of ≤8 in-flight preview/refine
tasks (leave headroom under the hard cap of 10 for API polling requests
themselves, which also count against the 20 req/s bucket) rather than
submitting all 40-60 previews at once and hitting `429`
`NoMoreConcurrentTasks`.

### Error handling

- `429 RateLimitExceeded` → exponential backoff on the poll/submit call,
  not a hard failure.
- `429 NoMoreConcurrentTasks` → hold the next submission until a queue slot
  frees (poll loop naturally does this if the worker-pool pattern above is
  used).
- `402 Insufficient credits` → hard stop, surface remaining manifest items
  as "not attempted" in the report, do not silently skip.
- Task `status: FAILED` → log `task_error`, continue batch (don't let one
  bad prompt kill 59 others), flag in the report for a manual prompt
  rewrite + single-item re-run (the script should support re-running a
  manifest subset by `name` for exactly this case).
- Download failure (expired URL, network blip) → retry download 2-3x
  before falling back to "SUCCEEDED but not downloaded" state in the
  report, since `expires_at` means a late download can silently 404.

### Credit-budget tracking

Script accepts a `--budget-credits N` ceiling. Running total = sum of
`consumed_credits` from every completed task response (not an estimate —
the API returns the actual charged amount per task). Print running total
after every asset; abort remaining queue (not in-flight tasks) if the next
item would risk exceeding budget. This makes the batch resumable: a report
of "38/52 completed, budget exhausted, 14 remaining" is a normal stopping
point, not a crash.

### Report sheet

Reuses `tools/asset_probe.tscn` for the visual side (already produces
labeled screenshots with printed AABBs — no new thumbnail code needed) and
a generated `docs/verify/gothic-props-VERIFY.md` for the data side, in the
exact table shape already proven in `meshy-assets-VERIFY.md` and
`cosmetics-VERIFY.md`.

---

## 6. Cost math — budgeting a 40-60 prop batch

### Per-asset cost (confirmed from `docs.meshy.ai/en/api/pricing`, fetched today)

| Stage | Cost (meshy-6 / lowpoly) |
|---|---|
| Preview (mesh) | 20 credits |
| Refine (texture, no PBR) | 10 credits |
| **Full asset (preview+refine)** | **30 credits** |

This cross-checks against the Image-to-3D pricing table's combined figure
("20 credits without texture, 30 with texture" for the same model tier) —
internally consistent across two independently-fetched doc pages, so
treated as reliable. (One help-center article summarized the combined cost
as "20 credits total," which conflicts with the two consistent pricing-page
figures above — flagging the discrepancy rather than silently picking a
number. **Recommend running the first 3-5 assets of the real batch and
checking actual `consumed_credits` before trusting either figure for
budgeting the remaining 35-55.**)

Not included in the base estimate, add only if used:
- `texture_prompt` or `texture_image_url` guidance on Image-to-3D: +10
  credits (not applicable — this batch is pure text-to-3D)
- `enable_pbr` / `hd_texture`: no surcharge documented anywhere fetched
  today — appears bundled into the flat 10-credit refine cost, but this is
  an absence-of-evidence, not confirmed-absence; **recommended default for
  this batch is `enable_pbr: false` anyway** (§2), which sidesteps the
  uncertainty entirely.
- Regenerations: based on this project's own 1/18 (~5.5%) historical
  retry rate, budget a **15% credit buffer** to be safe (retries cost a
  full second preview+refine, not a discount).

### Batch totals

| Batch size | Base credits (30/asset) | +15% retry buffer | Pro-tier $ ($0.02/credit) |
|---|---|---|---|
| 40 props | 1,200 | ~1,380 | ~$27.60 |
| 50 props | 1,500 | ~1,725 | ~$34.50 |
| 60 props | 1,800 | ~2,070 | ~$41.40 |

### Plan fit

- **Pro** ($20/mo, 1,000 credits/mo): covers ~33 props at the buffered
  rate in a single monthly allowance — a 40-60 prop batch needs **roughly
  1.4-2.1 months of Pro credits**, or a top-up purchase (Pro supports
  buying additional credits; exact $/credit for top-ups wasn't published
  on the pages fetched today — check `meshy.ai/settings/subscription`
  before committing to a one-shot 60-prop run on Pro).
- **Ultra** ($80/mo, 10,000 credits/mo, $0.008/credit): a 60-prop buffered
  batch (~2,070 credits) costs **~$16.56** of a single Ultra month and
  leaves ~8,000 credits of headroom for future batches (character
  variants, additional cosmetics, minigame-specific prop sets) — cheaper
  per-credit and removes the multi-month stretch Pro would need. **If more
  than one large batch is planned this cycle, Ultra for a single month is
  the better buy than 2 months of Pro.**
- **Premium** (3,000 credits/mo) sits between the two; exact $/mo wasn't
  confirmed on the pages fetched today (Pro $20 and Ultra $80 were
  directly confirmed; Premium's price should be checked at
  [meshy.ai/pricing](https://www.meshy.ai/pricing) before assuming a
  linear interpolation).
- Existing account is already **paid** (per `LICENSE-NOTE.md`) — whatever
  tier it's currently on, the credit math above is what determines whether
  a top-up or a one-cycle tier bump is needed for a 40-60 prop push.

**Bottom line: budget $30-45 in credits for a 40-60 prop batch at current
Pro-tier per-credit pricing, or under $17 if run in a single Ultra month.**
Confirm actual per-task cost against the first few real generations before
trusting the estimate for the full remaining batch.

Sources: [Pricing (API docs)](https://docs.meshy.ai/en/api/pricing) ·
[Pricing (product page)](https://www.meshy.ai/pricing) ·
[Credit cost help article](https://help.meshy.ai/en/articles/10000507-how-many-credits-does-each-generation-task-cost)

---

## Open questions for whoever builds this

1. Confirm Premium tier's exact monthly price before budgeting against it.
2. Confirm whether `enable_pbr`/`hd_texture` carry a hidden surcharge by
   watching `consumed_credits` on a real PBR-enabled test task (not needed
   if this batch ships with `enable_pbr: false` as recommended).
3. Decide `assets/models/meshy/gothic_props/` subfolder vs. flat
   `assets/models/meshy/` — the existing probe scene has `MESHY_DIR`
   hardcoded to the flat root, so a subfolder means either editing the
   probe or duplicating/parameterizing it (small change either way, but a
   decision for the implementer, not this research doc).
4. Language model pin: recommend `meshy-6` explicit, not `latest`, to
   avoid a mid-batch model version drift — confirm this is still the
   newest stable tag at implementation time (checked
   [changelog](https://docs.meshy.ai/en/api/changelog) today: meshy-6
   stable since Sep 2025, meshy-4 retired Mar 2026, `latest` currently
   resolves to meshy-6).
