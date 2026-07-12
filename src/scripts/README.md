# PROMOT → NMDO Integration Scripts

## IMPORTING INTO NMDO:  

GO directly down to "Output Files" section!

## Overview

This directory contains the pipeline that extracts clinical-assessment content from
the PROMOT ontology and flattens it into ROBOT template CSVs that add annotation
properties to existing NMDO classes (or flag PROMOT classes NMDO doesn't have yet).

For the full session-by-session audit trail (design decisions, bug fixes, batch
results), see `CHANGES.md`. For a fast "what's the state right now" summary, see
`HANDOFF.md`. This file is the how-to.

---

## Branch

**All of this work happens on the `promot_integration` branch**, targeting `main`.
Check `git branch` before starting — don't assume you're already on it.

---

## Prerequisites

- Ruby with the `rdf`, `rdf-rdfxml`, `sparql`, and `csv` gems available (used by
  `parse_promot.rb`)
- Network access to the NMDO semantic search service at
  `https://simpathic.services/llm_search/` (used by `llm_match_promot.rb`). Sanity
  check before a run:
  ```bash
  curl -s https://simpathic.services/llm_search/health
  ```
  Confirm `built_at` is more recent than the last real change to `nmdo-full.owl`
  (`git log -1 -- ../../nmdo-full.owl`). The index does **not** rebuild automatically
  when the ontology changes — if it looks stale, someone needs to trigger
  `POST /llm_search/reindex` on the service before results can be trusted.
- A local copy of the PROMOT OWL file. **`promot_V0.71.owl` is gitignored** — it is
  not checked into this repo. Supply your own path; it does not need to live inside
  the repo (e.g. `/home/osboxes/Desktop/promot_V0.71.owl` was used for the Session 4
  full run).
- `nmdo-full.owl` at the repo root (checked into git, part of each release).
- ROBOT (only needed for the final application step) — see `../templates/README.md`.

---

## Pipeline overview

Two scripts, run in sequence:

1. **`parse_promot.rb`** — loads PROMOT and NMDO OWL, extracts `someValuesFrom`
   restrictions on 7 PROMOT/RO object properties, and routes them into 7 new NMDO
   annotation properties (14 columns total, with `_label` siblings). For each PROMOT
   class found, attempts a direct match against NMDO by IRI, SKOS cross-reference, or
   exact English label. Classes that match go to `promot-annotations-existing.csv`;
   everything else goes to `promot-annotations-missing.csv` for the next step.

2. **`llm_match_promot.rb`** — takes `promot-annotations-missing.csv` and, for each
   class, calls the NMDO semantic search API with the class's label to find the
   best-guess NMDO target. Matches scoring ≥ threshold (default 0.20) go to
   `promot-annotations-llm-matched.csv`; the rest go to
   `promot-annotations-llm-unmatched.csv`. When multiple PROMOT classes match the same
   NMDO class, they're merged into one row (annotations unioned) and also reported in
   `promot-annotations-llm-conflicts.csv` for curator review.

Every matched/conflict row carries an `rdfs:comment` with the LLM score and
alternative candidates, so reviewers can see match provenance directly in Protégé or
OLS without cross-referencing this repo.

**Match quality is not a gate.** Every row — matched, unmatched, and conflicted — is
manually reviewed by domain experts before anything is applied to NMDO with ROBOT. Low
scores and large many-to-one conflict groups are expected and useful signal (they
often indicate NMDO needs a more fine-grained class), not pipeline errors to prevent
upstream.

---

## How to run

From `src/scripts/`:

```bash
# Full run — process all of PROMOT, no scoping:
ruby parse_promot.rb <path-to-promot_V0.71.owl> ../../nmdo-full.owl
ruby llm_match_promot.rb                    # default score threshold 0.20
ruby llm_match_promot.rb 0.30               # stricter threshold, optional

# Scoped run — one PROMOT/SNOMED subtree only (useful for isolated review of one area):
ruby parse_promot.rb <path-to-promot_V0.71.owl> ../../nmdo-full.owl <root-iri>
ruby llm_match_promot.rb
```

`parse_promot.rb` only needs re-running if the PROMOT or NMDO OWL files change.
`llm_match_promot.rb` can be re-run freely — it always regenerates its three output
files from the current `promot-annotations-missing.csv`.

Both scripts write directly into `../templates/`, overwriting the previous run's
output. That's expected — all of it is committed to git, so any prior run's results
are recoverable from history if needed. A full (unscoped) run's results are a superset
of any prior scoped run over the same subtree, so there is nothing to lose by
overwriting.

Runtime: `parse_promot.rb` does its work in pure-Ruby SPARQL over in-memory RDF
graphs with no indexing, so it is slow relative to file size — expect on the order of
10+ minutes for a ~30MB combined PROMOT+NMDO load, not seconds. `llm_match_promot.rb`
is bounded by one HTTP round-trip per unmatched class (roughly 0.3–0.5s including a
polite 0.05s sleep) — a few hundred classes takes a few minutes.

---

## Output files

All written to `../templates/`:

| File | Contents | Curator action |
| --- | --- | --- |
| `annotations-robot-template.csv` | Declares the 14 new annotation properties | Apply first via ROBOT |
| `promot-annotations-existing.csv` | PROMOT classes matched to NMDO directly (IRI/SKOS/label) | Apply via ROBOT |
| `promot-annotations-missing.csv` | PROMOT classes with no direct NMDO match — input to `llm_match_promot.rb` | Reference only |
| `promot-annotations-llm-matched.csv` | LLM best-guess matches, one row per NMDO IRI | **Review before applying** — check `LLM Score` / `LLM Match Note` columns |
| `promot-annotations-llm-unmatched.csv` | Classes below the score threshold | Decide: new NMDO class, or discard |
| `promot-annotations-llm-conflicts.csv` | NMDO IRIs claimed by >1 PROMOT class | Decide: does NMDO need splitting into finer classes? |

See `../templates/README.md` for the ROBOT commands that apply these templates to
`nmdo-full.owl`, and for the reviewer scoring rule of thumb (≥0.50 usually reliable,
0.30–0.50 check carefully, <0.30 likely wrong).

---

## A note on the `Label`/`Definition` columns

`promot-annotations-llm-matched.csv`'s `Label` column is a ROBOT `LABEL` directive —
it asserts `rdfs:label` on the row's `ID` (an **existing** NMDO/NCIT/HP/etc. class).
`llm_match_promot.rb` populates it from the matched NMDO class's own label (returned
by the search API), never from the PROMOT source class's label — asserting the wrong
one would silently overwrite an existing class's real label when applied via ROBOT.
`Definition` is left blank for the same reason: the search API doesn't return the
target's definition, and the PROMOT source definition describes the wrong class. See
CHANGES.md, Session 4, for the incident this fixed.

---

## Known limitations

- The full (unscoped) run sweeps in PROMOT content that earlier scoped batches
  deliberately excluded — gene-variant classes (germline mutation content) and
  administrative/data-model classes (age categories, consent status, etc.), plus
  top-level WHO-ICF category classes like "Activity" and "Participation" that tend to
  produce weak, generic matches. This is intentional for a full run, not a bug.
- `parse_promot.rb`'s direct-match step only tries exact IRI, SKOS cross-reference, or
  exact-case-insensitive English label — no fuzzy matching. Everything else falls
  through to the LLM step.
