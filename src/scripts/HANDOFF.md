# HANDOFF — PROMOT Integration

Quick-start document for resuming this work after a context break.
For full audit trail see `CHANGES.md` in this directory. For end-to-end setup and
execution instructions see `README.md` in this directory.

---

## Current state (as of 2026-09-08)

**Branch:** `promot_integration` (up to date with `origin/promot_integration`, `main`
already merged in). **All work on this pipeline happens on this branch — check
`git branch` before starting a session, do not assume.**

### What is done

- `parse_promot.rb` — extracts PROMOT OWL restrictions and routes them into NMDO annotation property templates (ROBOT CSV format)
- `llm_match_promot.rb` — takes classes NMDO couldn't match directly, calls the NMDO semantic search API, and produces matched/unmatched/conflicts outputs. Now includes a top-3 exact-match rerank (added 2026-09-02, confirmed firing in a full run for the first time this session).
- Session 3 duplicate-ID fix and Session 4 Label/Definition fix are both applied — see CHANGES.md. `promot-annotations-llm-matched.csv` has unique IDs and correct target labels.
- The NMDO search service's embedding model switched from `all-MiniLM-L6-v2` to the biomedical `cambridgeltl/SapBERT-UMLS-2020AB-all-lang-from-XLMR` — deployed and confirmed live 2026-09-08. **That change lives on SIMPATHIC2's `spreadsheet-2-care` branch, not `main` — still needs merging.**
- **First full run against the final PROMOT release is complete** (Session 6, 2026-09-08, `promot-full.owl` release `2026-08-17`), using the new SapBERT model — supersedes Session 4's run against the `promot_V0.71.owl` snapshot. Results:
  - 389 PROMOT classes found → 4 direct matches, 385 sent to LLM matching, 385/385 matched (0 unmatched)
  - 201 unique NMDO target classes after dedup, 86 conflict groups
  - Full numbers, model-mismatch incident, and methodology: CHANGES.md, Session 6; README.md Run History table

### Next: curator review of the full matched/conflicts set

Nothing left to regenerate for this batch. What's outstanding is a human decision on:

- `promot-annotations-llm-matched.csv` (201 rows) — spot-check scores, especially matches that look like word-overlap artifacts rather than true concept matches (e.g. `Power of tibialis anterior` → `anterior neural tube`) — see CHANGES.md Session 6
- `promot-annotations-llm-conflicts.csv` (86 rows) — decide per-group whether NMDO needs splitting into finer-grained classes, or whether the many-to-one mapping is correct as-is
- Earlier Batch-1-specific flags (still valid, now folded into the full conflicts/matched files): pinch strength → Paresthesia, Berg Balance → EQ-5D-5L, Hand Jamar → Nine-Hole Peg Test — see CHANGES.md Session 2
- Also outstanding: merge SIMPATHIC2's `spreadsheet-2-care` branch (holds the nmdo-search SapBERT change) to `main`

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
# Full run — all of PROMOT, no scoping (this is what Session 6 used):
ruby parse_promot.rb <path-to-promot-full.owl> ../../nmdo-full.owl
ruby llm_match_promot.rb

# Scoped run — one subtree only (useful for isolated re-review):
ruby parse_promot.rb <path-to-promot-full.owl> ../../nmdo-full.owl <root-iri>
ruby llm_match_promot.rb
```

The PROMOT OWL file is gitignored and not part of the repo — supply your own local
copy (Session 6 used `promot-full.owl`, the final `2026-08-17` release).

Review `promot-annotations-llm-matched.csv` and `promot-annotations-llm-conflicts.csv`
before applying to NMDO with ROBOT. See `../templates/README.md` for ROBOT commands.
