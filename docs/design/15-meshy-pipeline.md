# Meshy Forge — API pipeline research

This doc was expected to already exist (per the MESHY FORGE brief) but was not
found anywhere in git history across any branch/worktree, so it was written
fresh here, from a live fetch of `docs.meshy.ai` on 2026-07-15, before writing
`tools/meshy_forge.ps1`. It documents exactly what the tool implements.

## Auth

`Authorization: Bearer <MESHY_API_KEY>` header. Key lives in
`C:\Users\agall\projects\Dead_Attestation\.env` as `MESHY_API_KEY=msy_...`
(gitignored, never committed, never printed — the forge script reads it into
a process variable at runtime only).

## Endpoints (API v2)

Base: `https://api.meshy.ai/openapi/v2/text-to-3d`

| Verb | Path | Purpose |
|---|---|---|
| POST | `/openapi/v2/text-to-3d` | create task (`mode: "preview"` or `"refine"`) |
| GET | `/openapi/v2/text-to-3d/:id` | poll task status |

## Current model

**`meshy-6`** is the current default (`ai_model: "latest"` resolves to it).
`meshy-5` still works but is the legacy model the first three shipped batches
(18 assets, `docs/verify/meshy-assets-VERIFY.md`, `docs/verify/cosmetics-VERIFY.md`,
`docs/verify/visual-polish-VERIFY.md`) used. This batch uses `meshy-6`
explicitly (`ai_model: "meshy-6"`) per the brief.

## Preview request (`mode: "preview"`)

Required: `mode`, `prompt` (≤600 chars).

Used for this batch:
```json
{
  "mode": "preview",
  "prompt": "<specific prompt> + house style suffix",
  "ai_model": "meshy-6",
  "model_type": "lowpoly",
  "topology": "triangle",
  "target_polycount": 8000,
  "should_remesh": true,
  "moderation": false,
  "target_formats": ["glb"],
  "origin_at": "bottom"
}
```
`model_type: "lowpoly"` + `target_polycount: 8000` + `topology: "triangle"`
reproduces the exact settings recorded in the prior VERIFY docs
("low-poly mode, triangle topology, target polycount 8000") — the settings
that produced all 18 KEEP-verdict assets already in `assets/models/meshy/`.
`target_formats: ["glb"]` is the one new v6 knob (per the API changelog) that
trims task time by skipping the other export formats we never use.

## Refine request (`mode: "refine"`)

Required: `mode`, `preview_task_id`.

Used for this batch:
```json
{
  "mode": "refine",
  "preview_task_id": "<id>",
  "ai_model": "meshy-6",
  "enable_pbr": false,
  "moderation": false,
  "target_formats": ["glb"],
  "origin_at": "bottom"
}
```
`enable_pbr: false` — **PBR off**, per the brief: house style is flat-color,
matching every prior batch (no metallic/roughness/normal maps requested).
`remove_lighting` (meshy-6 only) defaults to `true`, which is what we want —
it keeps the baked texture flat/unlit rather than sun-baked, closer to the
Kenney/KayKit flat-color look.

## House style suffix (proven — reused verbatim)

Every prompt in `tools/meshy_manifest.json` is submitted as
`"<specific description>, " + HOUSE_STYLE_SUFFIX` where:

> low poly, chunky toy-like proportions, flat colors, no textures needed,
> game asset, clean silhouette, single object, Kenney/KayKit style

This is the exact suffix from `docs/verify/meshy-assets-VERIFY.md` and
`docs/verify/visual-polish-VERIFY.md` (18/18 KEEP across three batches with
this suffix, one halo regeneration in the cosmetics batch for an unrelated
geometry issue). Reusing it verbatim is the whole point: new props must sit
next to `throne.glb`, `manor_gate.glb`, etc. without a style seam.

## Response shape

```json
{
  "id": "...",
  "type": "text-to-3d-preview" | "text-to-3d-refine",
  "status": "PENDING" | "IN_PROGRESS" | "SUCCEEDED" | "FAILED" | "CANCELED",
  "progress": 0-100,
  "model_urls": {"glb": "https://assets.meshy.ai/.../model.glb?Expires=..."},
  "task_error": {"message": ""},
  "consumed_credits": 20
}
```
`model_urls.glb` is a presigned URL — no auth header needed to download it,
and it expires, so the forge tool downloads immediately after SUCCEEDED
rather than caching the URL.

## Credit costs (confirmed against `docs.meshy.ai/en/api/pricing`)

| Task | Cost |
|---|---|
| Preview (meshy-6 or lowpoly model) | 20 credits |
| Refine (texture generation) | 10 credits |
| **Total per finished prop** | **30 credits** |

This matches the brief's "~30 credits/prop" estimate exactly, which is a
good sign the brief's author had already priced this out — the forge tool's
pilot run (first 2-3 props) exists to confirm `consumed_credits` sums to 30
per prop before the full 32-prop batch (~960 credits) is unleashed.

## Rate limits

`docs.meshy.ai` (pricing/limits page): paid tiers get **20 requests/second**
and a cap on **queued (PENDING+IN_PROGRESS) tasks** — 10 for Pro, 20 for
Max/Max Unlimited. `tools/meshy_forge.ps1` never needs anywhere near 20 RPS
(it submits one task every ~0.4s at most), but the queued-task cap matters:
the tool batches submissions at **5 in flight at a time** (`$BatchSize`,
comfortably under even the Pro cap) and polls each batch to a terminal state
before opening the next batch. Preview and refine are two separate batched
phases run sequentially across the whole manifest (all previews first, then
all refines), so at no point are more than 5 tasks of one kind queued.

On `429 Too Many Requests` or `5xx`, the tool backs off (5s, 10s, 20s) and
retries up to 3 times before treating the submission as a hard failure for
that id (still eligible for the one-retry-with-adjusted-prompt rule on a
`FAILED` terminal status).

## Polling

`GET /openapi/v2/text-to-3d/:id` every 5s per task, per-task timeout 15
minutes (preview/refine tasks on meshy-6 typically finish in ~1-3 minutes per
the changelog; 15 min is a generous ceiling before the tool gives up and
marks that id `timeout` in the report).

## Failure handling

- API-level submission failure (after retries) → mark `failed`, log
  `task_error.message` if any, move to next id.
- Preview reaches `FAILED` → automatic **one retry** with the prompt suffixed
  by `", simple clean geometry, single distinct object"` (a generic
  disambiguator) before giving up per-id.
- A prop that *succeeds* generation but looks wrong on the contact sheet is a
  visual judgment call the script cannot make — those are re-run by hand
  after the screenshot review (`-Only <id>` with a hand-edited manifest
  prompt), per the brief's "retry once with an adjusted prompt" instruction.

## Output layout

```
assets/models/meshy/generated/<id>.glb     -- new props (this batch only)
tools/meshy_forge_report.json              -- {id, preview_task_id, refine_task_id,
                                                consumed_credits, status, ...}
```
Existing `assets/models/meshy/*.glb` (18 shipped assets, flat, no subfolder)
are untouched — the new batch lives in its own `generated/` subfolder so it
never collides with or reshuffles the shipped set. `tools/asset_probe.gd` was
given a small additive `--dir=`/`--groups=` cmdline option (default behavior
unchanged) so the existing contact-sheet mechanism can point at
`generated/` instead of scanning only the flat top-level directory.

---

## NIGHT 5 ADDENDUM (2026-07-16) — the rest of the API, from docs.meshy.ai/llms.txt

Account upgraded pro → **premium** this night (3× monthly credits; Alex: no
nightly cap needed anymore). Balance at upgrade: 2697.

Capabilities we are NOT yet using (all under https://api.meshy.ai/openapi/):
- **Rigging** (`/rigging`) — humanoid skeleton auto-added to a generated model.
- **Animation** (`/animation` + `/animation-library`) — preset motions applied
  to rigged characters. Rig+preset-idle could replace puppet transform-tweens
  for NPCs/host in a future pass — trial before committing a lane to it.
- **Retexture** (`/retexture`) — replace textures on an EXISTING model via
  text/image prompt. Cheaper fix than re-forging when geometry is fine but
  style missed.
- **Remesh** (`/remesh`) — topology/polycount control; useful for background
  NPC perf budgets.
- **UV Unwrap** (5 cr), **Convert** (1 cr, GLB/FBX/OBJ/STL/USDZ/BLEND),
  **Resize** (1 cr), **Image-to-3D** (`/v1/image-to-3d`), text-to-image.
- Async model: poll, **SSE stream, or webhook** (we poll; SSE is available).
- **Asset retention is 3 days** on non-Enterprise — always download GLBs
  immediately (we already do).
- Rate limits: Pro/premium tier ~20 req/s, 10-20 task queue.
- A Meshy **MCP server for Claude Code** exists (docs: /api/ai) if a future
  instance prefers tool-native calls over the forge script.
