# CHANGES — PROMOT Integration Scripts

Audit trail for the extraction and flattening of PROMOT ontology content into NMDO annotation properties.
Maintained for clinical research audit purposes.

---

## 2026-08-07 — Session 5: Switch annotation property base to OBO PURL

**Lead:** Mark Wilkinson

### Problem identified

Ontology curator review on PR #37 flagged that the `ID` field in
`annotations-robot-template.csv` used the `https://w3id.org/nmdo/` URI base instead
of the registered OBO PURL base (`http://purl.obolibrary.org/obo/nmdo`), which is
what the rest of NMDO (classes, imports, `ONTBASE` in the Makefile) actually uses.

### Changes made

- **`parse_promot.rb`** and **`llm_match_promot.rb`**: `BASE_NS` changed from
  `https://w3id.org/nmdo/` to `http://purl.obolibrary.org/obo/nmdo#`.
- **`annotations-robot-template.csv`**: regenerated so all 14 property `ID`s use the
  new base.
- **`src/templates/README.md`**: `--prefix "nmdo: ..."` flags and namespace notes
  updated to match.

---

## 2026-07-12 — Session 4: Label/Definition fix + first full-PROMOT run

**Lead:** Mark Wilkinson

### Problem identified

`promot-annotations-llm-matched.csv` populated its `LABEL` and `Definition` columns
from the **source** PROMOT class's own label/definition, not the **matched NMDO
class's**. `LABEL` is a reserved ROBOT template directive that asserts `rdfs:label`
on the row's `ID` — since `ID` is the matched (existing) NMDO/NCIT/HP IRI, applying
this template via ROBOT would have silently overwritten that class's real label with
the PROMOT source class's label. E.g. the merged row for `NCIT_C202084` carried
`Label: "Assessment using Sydney Swallow Questionnaire (SSQ)"` (a PROMOT class name)
instead of the class's actual label. This affected every matched row, not just
conflict rows.

### Changes made

- **`llm_match_promot.rb`**:
  - `Label` column now comes from the search API's `top['label']` (the matched NMDO
    class's real label) instead of the PROMOT source row.
  - `Definition` is left blank for matched rows — the search API doesn't return the
    target's definition, and the PROMOT source definition describes the wrong class.
  - Internal bookkeeping change to support this: `matched` entries are now
    `[row, promot_label]` tuples so the PROMOT source label is still available for the
    conflicts report (`promot-annotations-llm-conflicts.csv`'s "PROMOT Labels" column)
    without leaking into the CSV's `LABEL` column.
  - Verified: matched output for `NCIT_C202084` now correctly shows
    `Label: "Eating Assessment Tool-10"`.

### First full-PROMOT run (unscoped — no root-iri)

Ran the full pipeline end-to-end for the first time, without the SNOMED-subtree
scoping used for Batch 1. Curator sign-off: match quality is not a gate — every
matched/conflict row is manually reviewed by domain experts downstream, so low
scores and many-to-one conflicts are expected, useful signal rather than errors to
prevent.

```bash
ruby parse_promot.rb /home/osboxes/Desktop/promot_V0.71.owl ../../nmdo-full.owl
ruby llm_match_promot.rb
```

| Metric | Value |
| --- | --- |
| PROMOT classes found (`PROMOT_0xxxxx` + WHO-ICD entity) | 338 |
| Restriction-based annotations routed | 411 |
| Direct IRI/SKOS matches (`promot-annotations-existing.csv`) | 4 (Pain, Vestibular labyrinth, Heart, Congenital) |
| Sent to LLM matching | 334 |
| LLM matched (score ≥ 0.20) | 334 / 334 |
| Unique NMDO target classes after dedup | 201 |
| Conflict groups (NMDO IRI claimed by >1 PROMOT class) | 67 (sizes 2–11; 200 of the 334 PROMOT classes fall into one) |

Confirmed search index freshness before running: `simpathic.services/llm_search/health`
reported `built_at: 2026-07-11T11:03:52Z`, after the `2026-07-10` NMDO release commit
that last changed `nmdo-full.owl` — no reindex needed.

Notable low-confidence outliers worth flagging to curators (not blocking, expected noise
from now including top-level WHO-ICF category classes like "Activity"/"Participation"
that were previously out of scope):

- `Participation` → `disseminated` (0.2472) — barely above threshold, generic ICF
  category vs. an oncology staging term
- `Activity` → `Falls` (0.3577) — generic ICF category, weak match

### Output files (regenerated, superseding Batch 1's scoped subset)

- `promot-annotations-existing.csv` — 4 rows
- `promot-annotations-llm-matched.csv` — 201 rows
- `promot-annotations-llm-conflicts.csv` — 67 rows
- `promot-annotations-llm-unmatched.csv` — 0 rows (nothing fell below threshold)

Batch 1's prior scoped output is recoverable from git history (`c67a121`) if needed —
not manually archived since it's a strict subset of this run's results.

---

## 2026-06-12 — Session 3: Duplicate ID fix in llm_match_promot.rb

**Lead:** Mark Wilkinson

### Problem identified

`promot-annotations-llm-matched.csv` contained duplicate values in the `ID` column — multiple PROMOT classes had been independently matched to the same NMDO IRI by the LLM, producing multiple rows with conflicting Label, Definition, and annotation data. ROBOT template format requires unique IDs, so earlier rows would be silently overwritten.

### Changes made

- **`llm_match_promot.rb`** — added post-match deduplication:
  - After all LLM calls complete, groups matched rows by their NMDO IRI
  - Rows that share a NMDO IRI are merged into one: annotations (all pipe-separated columns) are unioned and deduplicated; PROMOT cross-references are pipe-joined; Label/Definition come from the highest-scoring match
  - Writes a new **`promot-annotations-llm-conflicts.csv`** listing every NMDO IRI claimed by >1 PROMOT class — one row per conflict, with all PROMOT IRIs, labels, and scores — so curators can decide whether NMDO needs to be split into finer-grained classes

### Output files

| File | Status |
| --- | --- |
| `promot-annotations-llm-matched.csv` | Now guaranteed unique IDs; annotations merged across all PROMOT sources |
| `promot-annotations-llm-conflicts.csv` | **New** — curator flag for NMDO splitting decisions |
| `promot-annotations-llm-unmatched.csv` | Unchanged |

### Action required

Re-run `ruby llm_match_promot.rb` (from `src/scripts/`) to regenerate the matched and conflicts files.
`parse_promot.rb` does not need re-running unless PROMOT or NMDO OWL files have changed.

---

## 2026-06-03 / 2026-06-04 — Session 2: ROBOT pipeline, LLM matching, scoped batch approach

**Lead:** Mark Wilkinson  
**Commits:** `95f1ac6`, `5268644`

### Changes made

- **`parse_promot.rb`** — major revision:
  - Added optional third argument `[root-iri]` to scope extraction to a specific PROMOT subtree
  - Changed annotation header format from full IRI in angle brackets to CURIE form (`nmdo:property_name`) — required by ROBOT template parser
  - Changed `AT` back to `A` for annotation column instructions — `AT` is not valid ROBOT template syntax
  - Changed base namespace from `urn:local:nmdo_annotations:` to `https://w3id.org/nmdo/` — ROBOT rejects `urn:` scheme IRIs
  - Removed `SC %` and `TYPE` columns from llm-matched template output — those columns caused hierarchy corruption in NMDO when applied to existing classes
  - Added `rdfs:comment` column to llm-matched template carrying LLM match score and candidates — for clinician review

- **`llm_match_promot.rb`** — new script:
  - Calls NMDO semantic search API (`https://simpathic.services/llm_search/search`) for each unmatched PROMOT class
  - Generates `promot-annotations-llm-matched.csv` (proposed NMDO IRI as subject, human review required) and `promot-annotations-llm-unmatched.csv`
  - Default score threshold: 0.20 (configurable via first argument)
  - Uses `all-MiniLM-L6-v2` embedding model via FastEmbed sidecar

### Batch 1 — "Examination by method" subtree
- **Root class:** `http://snomed.info/id/315306007` (SNOMED "Examination by method")
- **Classes processed:** 13 PROMOT assessment tool classes (`PROMOT_0100005`–`PROMOT_0100017`)
- **Annotations routed:** 30 (all `assesses_*` type — no other property types present in this subtree)
- **IRI/SKOS matches:** 0 (NMDO has no PROMOT IRIs; assessment tools are PROMOT-specific)
- **LLM matches:** 13/13 (all above 0.20 threshold)
- **Known questionable LLM matches** (require clinician review):
  - `Assessment of pinch strength using B&L gauge` → `Paresthesia` (score: 0.296) — wrong concept
  - `Assessment using Berg Balance Scale` → `EQ-5D-5L Questionnaire` (score: 0.444) — wrong tool
  - `Assessment using Hand Jamar dynamometer` → `Nine-Hole Peg Functional Test` (score: 0.430) — wrong tool
- **PR:** submitted to `promot_integration` branch targeting `main`
- **Status:** awaiting curator review

### ROBOT pipeline (confirmed working)
See `project_robot_pipeline.md` in memory for full commands. Key requirement:
`--prefix "nmdo: https://w3id.org/nmdo/"` must be passed to every `robot template` invocation.

---

## 2026-06-01 — Session 1: Initial extraction framework

**Lead:** Mark Wilkinson  
**Commits:** `4369e0b`, `6118d5a`, `843d3d4`

### Changes made

- **`parse_promot.rb`** — initial version:
  - Loads PROMOT v0.71 and NMDO-full OWL files
  - Extracts `someValuesFrom` restrictions from 7 source object properties
  - Routes fillers to 7 new annotation properties based on namespace (HPO → phenotype, ICF → function/activity/structure, PROMOT-internal → `captures_data_about`)
  - Three-tier NMDO matching: direct IRI → SKOS reverse map → English label fallback
  - Generates three ROBOT template CSVs: annotation property declarations, existing matches, missing classes

### Design decisions made (Session 1)

- Collapsed `disease_has_feature` + `is_related_to` + `has_disposition` → single `associated_phenotype` (all pointed at HPO)
- Named `captures_data_about` (not `assesses_construct`) — matches clinician/CRF vocabulary
- Named `associated_function` (not `functionally_related_to`) — clearer semantic direction
- Kept PROMOT-internal fillers for `assesses` → `captures_data_about` — useful for CRF users navigating form sections
- Added parallel `_label` sibling properties for every URI annotation property — human-readable display without IRI resolution
- Added `A oboInOwl:hasDbXref` column to every class row to record PROMOT IRI provenance

---

## 2026-05-07 — Initial parsing experiments

**Lead:** Mark Wilkinson  
**Commits:** `970205e`, `7c0b27f`

- Early exploration of PROMOT structure
- Initial SPARQL queries for object properties and restriction patterns
- Identified `assesses` (PROMOT_2000002) as the most semantically interesting property

---

## Annotation properties introduced

All declared in `annotations-robot-template.csv`. Namespace: `http://purl.obolibrary.org/obo/nmdo#`

| Property | Source PROMOT property | Semantic role |
|---|---|---|
| `associated_phenotype` | RO:0004029, PROMOT:2000006, RO:0000091 | HPO phenotypes characterising a class |
| `associated_phenotype_label` | *(label sibling)* | Human-readable labels for above |
| `assesses_phenotype` | PROMOT:2000002 → HP fillers | HPO phenotype a clinical tool detects |
| `assesses_phenotype_label` | *(label sibling)* | Human-readable labels for above |
| `assesses_function` | PROMOT:2000002 → ICF fillers | WHO-ICF function/structure a tool measures |
| `assesses_function_label` | *(label sibling)* | Human-readable labels for above |
| `captures_data_about` | PROMOT:2000002 → PROMOT-internal fillers | CRF data-model concept captured by tool |
| `captures_data_about_label` | *(label sibling)* | Human-readable labels for above |
| `associated_function` | RO:0002328 | WHO-ICF functional capacities (b-codes) |
| `associated_function_label` | *(label sibling)* | Human-readable labels for above |
| `involved_in` | RO:0002331 | WHO-ICF activities/participation (d-codes) |
| `involved_in_label` | *(label sibling)* | Human-readable labels for above |
| `located_in` | RO:0001025 | WHO-ICF body structures (s-codes) |
| `located_in_label` | *(label sibling)* | Human-readable labels for above |

---

## Planned next batches (pending Batch 1 curator approval)

PROMOT contains further subtrees not yet processed. Candidates for future batches:
- Disease/phenotype classes (PROMOT_002XXXX body structure/anatomical entity classes)
- Administrative/data model classes (age categories, consent status, etc.) — likely to be mostly discarded
- Gene variant classes (PROMOT_0000001–PROMOT_0000XXX) — germline mutation content, excluded from Batch 1

Each batch requires: `ruby parse_promot.rb promot_V0.71.owl ../../nmdo-full.owl <root-iri>`
