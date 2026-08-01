# bard.realm.watch

**A 260,000-parameter transformer writing stories on a $3 microcontroller.**

The Bard is a real TinyStories-class language model — int8, executed in place from
flash — that runs on an ESP32-C3 with 400 KB of RAM and narrates without end. A
sliding-window KV cache means it never finishes: the tale keeps moving past a
72×40 OLED five lines at a time, typewriter-style, forever.

It was built inside [smol](https://github.com/jphein/smol), the mesh-firmware project,
and shipped there ([smol#300](https://github.com/jphein/smol/issues/300)). This repo is
where it moves out.

## Why it left smol

A storyteller and a mesh gateway have different memory appetites.

Measured on the same commit, same toolchain, the Bard costs the shared fleet image:

| resource | cost of `--features bard` |
|---|---:|
| `.rodata` (the model blob, XIP from flash) | **+287,392 B** (~281 KB) |
| `.bss` + `.data` (DRAM) | **+39,072 B** |
| runtime stack region (what's left of DRAM) | **−39,072 B** |

That last row is the whole argument. On the ESP32-C3 the linker gives `.stack`
whatever DRAM is left after `.bss`, and it shrinks it *silently* — so a successful
link says nothing about whether the firmware can run. On the current fleet image the
Bard fits. On the Embassy re-platform ([smol#233](https://github.com/jphein/smol/issues/233)),
where the radio stack is materially larger, it does not: the canonical tier links with
a **67,488 B** stack region against a **74,208 B** floor, and the same commit built
without the Bard links with **106,560 B** — a 32 KB margin instead of a 6.7 KB deficit.

One binary was forcing a storyteller and a radio to starve each other. So the Bard gets
its own chip, and rejoins the mesh as a peer rather than a passenger.

## What lives here

Right now: the project, the docs, and the Pages site. **Not the firmware.**

| phase | what | state |
|---|---|---|
| 1 | repo, site, versioning | **this** |
| 2 | `smol-core` — SMOLv1 wire format, election, OTA relay, names/sigil, DIAG | upstream, [smol#347](https://github.com/jphein/smol/issues/347) |
| 3 | the Bard firmware — its own binary, consuming `smol-core` | blocked on 2 |

The firmware is deliberately **not** copied yet. Copying it before `smol-core` exists
would create a third hand-maintained fork of `names.rs`/`sigil.rs` (the esp32c6-watch
already has the second), and that divergence is the exact thing Phase 2 is for.

## The site

`index.html` is a static GitHub Pages site — no build step, no external requests, no
CDN. Dark and light themes come from `prefers-color-scheme` over CSS custom properties,
with a manual override for people whose system theme lies about their preferences.

It is built to display **stories the Bard actually generated on-device**. Anything else
would be a mockup of the interesting part.

### How stories will get here

The fleet already reports over MQTT, so that is the path — no new transport:

```
node (Bard firmware)                broker                  this site
  narrate loop  ──publish──▶  smol/<node>/bard/story  ──▶  collector
                                                             │
                                            stories/stories.json (committed)
                                                             │
                                                     Pages serves it
```

Constraints that shape it, both learned the hard way upstream:

- **~490 B per MQTT publish.** The gateway's packet buffer caps a publish at roughly
  490 bytes, so a story arrives as numbered fragments and is reassembled by the
  collector, not sent whole.
- **Retained topics lie.** A retained payload persists after the node that wrote it is
  gone, so the collector must treat a *flip to a new value* as the liveness signal —
  never mere presence.

The collector itself is not built yet. `stories/stories.json` holds the schema and a
seed entry so the page has something honest to render, and every entry carries the
node, the firmware version, and the tokens-per-second it was produced at — a story
without its provenance is just text.

## Versioning

Per the house convention this project uses
[realm-sigil](https://github.com/jphein/realm-sigil): every build gets a deterministic
magical name from its commit hash, and exposes it at a standard endpoint.

```bash
./tools/stamp.sh          # writes version.json, api/version, and the <meta> tag
```

- `GET /version.json` — the realm-sigil payload the `<Sigil />` convention expects
- `GET /api/version` — the same document at the standard path, for
  `status.realm.watch`

Registered in `status.realm.watch/checks.json` under both `http` and `version`.

## Numbers

Measured on hardware, not estimated
([smol#300](https://github.com/jphein/smol/issues/300),
[#302](https://github.com/jphein/smol/issues/302)):

| | |
|---|---|
| parameters | ~260,000 |
| weights | int8, executed in place from flash |
| model blob | ~281 KB `.rodata` |
| working DRAM | ~39 KB (`.bss` + `.data`), 96 KB heap |
| context window | 80 tokens (`SEQ_CAP`), sliding |
| throughput | 202 ms/token bounded; 224–274 ms/token endless |
| display | 72×40 OLED — 5 lines × 14 characters |
| correctness | bit-for-bit against an independent Python reference |
| stack high-water | byte-identical at 55,440 B across 5 consecutive reports |

That last line is the one worth staring at: the sliding window does not creep. The
story can run forever because the memory cost of the next sentence is the same as the
memory cost of the first.

## License

GPL-3.0. Same as smol, from which this was extracted.
