# HANDOFF — PROMOT Integration

Quick-start document for resuming this work after a context break.
For full audit trail see `CHANGES.md` in this directory. For end-to-end setup and
execution instructions see `README.md` in this directory.

---

## Current state (as of 2026-07-12)

**Branch:** `promot_integration` (up to date with `origin/promot_integration`, `main`
already merged in). **All work on this pipeline happens on this branch — check
`git branch` before starting a session, do not assume.**

### What is done

- `parse_promot.rb` — extracts PROMOT OWL restrictions and routes them into NMDO annotation property templates (ROBOT CSV format)
- `llm_match_promot.rb` — takes classes NMDO couldn't match directly, calls the NMDO semantic search API, and produces matched/unmatched/conflicts outputs
- Session 3 duplicate-ID fix and Session 4 Label/Definition fix are both applied — see CHANGES.md. `promot-annotations-llm-matched.csv` has unique IDs and correct target labels.
- **First full, unscoped run of all of PROMOT is complete** (Session 4, 2026-07-12) — this supersedes the earlier Batch 1 scoped subset (SNOMED "Examination by method" subtree only). Results:
  - 338 PROMOT classes found → 4 direct matches, 334 sent to LLM matching, 334/334 matched
  - 201 unique NMDO target classes after dedup, 67 conflict groups (sizes 2–11)
  - Full numbers and methodology: CHANGES.md, Session 4

### Next: curator review of the full matched/conflicts set

Nothing left to regenerate for this batch. What's outstanding is a human decision on:

- `promot-annotations-llm-matched.csv` (201 rows) — spot-check scores, especially the low end
- `promot-annotations-llm-conflicts.csv` (67 rows) — decide per-group whether NMDO needs splitting into finer-grained classes, or whether the many-to-one mapping is correct as-is
- Known low-confidence outliers already flagged: `Participation` → `disseminated` (0.2472), `Activity` → `Falls` (0.3577) — see CHANGES.md Session 4
- Earlier Batch-1-specific flags (still valid, now folded into the full conflicts/matched files): pinch strength → Paresthesia, Berg Balance → EQ-5D-5L, Hand Jamar → Nine-Hole Peg Test — see CHANGES.md Session 2

**Match quality is not a gate here** — every row is reviewed by domain experts before
anything is applied to NMDO, so low scores and large conflict groups are expected,
useful signal rather than pipeline errors.

---

## File map

### Scripts (`src/scripts/`)

| File | Purpose |
| --- | --- |
| `parse_promot.rb` | Step 1: OWL → ROBOT template CSVs. Re-run only if PROMOT or NMDO OWL changes. |
| `llm_match_promot.rb` | Step 2: LLM matching of unmatched classes. Re-run freely. |
| `README.md` | Full documentation and execution instructions |
| `CHANGES.md` | Full audit trail of all sessions |
| `HANDOFF.md` | This file |

### Templates (`src/templates/`)

| File | Contents | ROBOT-ready? |
| --- | --- | --- |
| `annotations-robot-template.csv` | 14 new annotation property declarations | Yes — Step 1 |
| `promot-annotations-existing.csv` | PROMOT classes already in NMDO (IRI/SKOS/label match) | Yes — Step 2 |
| `promot-annotations-missing.csv` | PROMOT classes with no NMDO match — input to llm_match_promot.rb | No |
| `promot-annotations-llm-matched.csv` | LLM-matched classes (review before using) | After review |
| `promot-annotations-llm-unmatched.csv` | Below LLM threshold (0.20) — curator decision needed | No |
| `promot-annotations-llm-conflicts.csv` | NMDO IRIs claimed by >1 PROMOT class — NMDO may need splitting | No |

---

## How to run

See `README.md` for full prerequisites and explanation. Quick reference (from `src/scripts/`):

```bash
# Full run — all of PROMOT, no scoping (this is what Session 4 used):
ruby parse_promot.rb <path-to-promot_V0.71.owl> ../../nmdo-full.owl
ruby llm_match_promot.rb

# Scoped run — one subtree only (useful for isolated re-review):
ruby parse_promot.rb <path-to-promot_V0.71.owl> ../../nmdo-full.owl <root-iri>
ruby llm_match_promot.rb
```

`promot_V0.71.owl` is gitignored and not part of the repo — supply your own local copy.

Review `promot-annotations-llm-matched.csv` and `promot-annotations-llm-conflicts.csv`
before applying to NMDO with ROBOT. See `../templates/README.md` for ROBOT commands.
