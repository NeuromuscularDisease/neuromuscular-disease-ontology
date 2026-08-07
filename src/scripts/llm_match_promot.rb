#!/usr/bin/env ruby
# frozen_string_literal: true

# Reads promot-annotations-missing.csv (output of parse_promot.rb) and
# calls the NMDO semantic search API to find best-guess NMDO matches for
# each unmatched PROMOT class.
#
# Outputs three files:
#   promot-annotations-llm-matched.csv   — one row per NMDO IRI (merged when
#                                          multiple PROMOT classes hit the same IRI)
#   promot-annotations-llm-unmatched.csv — no confident match found
#   promot-annotations-llm-conflicts.csv — NMDO IRIs claimed by >1 PROMOT class
#                                          (curator flag: NMDO may need splitting)
#
# Usage:
#   ruby llm_match_promot.rb [min_score]
#   ruby llm_match_promot.rb 0.20        # default

require 'csv'
require 'net/http'
require 'json'
require 'uri'

BASE_NS     = 'http://purl.obolibrary.org/obo/nmdo#'.freeze
SEARCH_BASE = 'https://simpathic.services/llm_search/search'.freeze
TEMPLATES_DIR = File.expand_path('../templates', __dir__)
MISSING_CSV   = File.join(TEMPLATES_DIR, 'promot-annotations-missing.csv')
MIN_SCORE     = (ARGV[0] || '0.20').to_f
TOP_K         = 3   # fetch top 3 so reviewers can see alternatives

warn "LLM match threshold: #{MIN_SCORE}"
warn "Reading #{MISSING_CSV}..."

rows = CSV.read(MISSING_CSV)
# Missing file columns: ID(0) Label(1) Definition(2) Type(3) Parent(4) XRef(5) annotations(6+)
# Matched file drops Type and Parent — annotating existing classes, not creating new ones.
EXISTING_COLS = ([0, 1, 2, 5] + (6..999).to_a).freeze
missing_h1 = rows[0]
missing_h2 = rows[1]
data        = rows[2..]

# Headers for the matched file — same as promot-annotations-existing.csv format
matched_h1 = missing_h1.values_at(*EXISTING_COLS.select { |i| i < missing_h1.size })
matched_h2 = missing_h2.values_at(*EXISTING_COLS.select { |i| i < missing_h2.size })

warn "  #{data.size} classes to process"

# ── Call search API ────────────────────────────────────────────────────────────
def search(query, top_k: TOP_K)
  uri = URI(SEARCH_BASE)
  uri.query = URI.encode_www_form(q: query, top_k: top_k)
  response = Net::HTTP.get_response(uri)
  return [] unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)['results'] || []
rescue StandardError => e
  warn "  API error for #{query.inspect}: #{e.message}"
  []
end

# ── Process each missing class ─────────────────────────────────────────────────
matched   = []
unmatched = []

data.each_with_index do |row, i|
  promot_iri = row[0]
  label      = row[1]

  if label.nil? || label.strip.empty?
    warn "  [#{i + 1}/#{data.size}] #{promot_iri} — no label, skipping"
    unmatched << row + ['', '', '']
    next
  end

  warn "  [#{i + 1}/#{data.size}] #{label}"
  results = search(label)

  top       = results.first
  score     = top ? top['score'].round(4) : 0.0
  nmdo_iri  = top ? top['iri']   : ''
  nmdo_lbl  = top ? top['label'] : ''

  # Build a readable alternatives string for the reviewer (top 3, pipe-separated)
  alternatives = results.map { |r| "#{r['label']} [#{r['score'].round(3)}]" }.join(' | ')

  if score >= MIN_SCORE
    warn "    ✓ #{nmdo_lbl} (#{score})"
    # Build row in existing-file format: drop Type(3) and Parent(4) columns,
    # replace ID with the matched NMDO IRI, keep PROMOT IRI as cross-reference.
    review_note = "PROMOT mapping: '#{label}' (LLM score: #{score}) | Candidates: #{alternatives}"
    src_values = row.values_at(*EXISTING_COLS.select { |i| i < row.size })[1..]
    # src_values = [promot_label, promot_definition, promot_xref, annotations...].
    # Label/Definition must describe the matched NMDO class, not the PROMOT source —
    # the header's LABEL column is a ROBOT directive that asserts rdfs:label, so
    # writing the PROMOT label there would overwrite the existing class's real label.
    # Definition is left blank for the same reason (the API doesn't return the
    # target's definition, and the PROMOT one isn't the target's).
    matched_row = [nmdo_iri, nmdo_lbl, ''] + src_values[2..] +
                  [score.to_s, alternatives, review_note]
    matched << [matched_row, label]
  else
    warn "    ✗ best: #{nmdo_lbl.empty? ? '(none)' : nmdo_lbl} (#{score})"
    unmatched << row + [score.to_s, alternatives]
  end

  sleep 0.05  # be polite to the API
end

warn "Matched: #{matched.size} | Unmatched: #{unmatched.size}"

# ── Extra column headers ───────────────────────────────────────────────────────
# LLM Score and LLM Top Candidates are CSV-only review aids (ROBOT ignores them).
# LLM Match Note is written to the OWL as rdfs:comment so clinicians can see
# provenance and score directly in Protege / OLS — low scores flag review needed.
REVIEW_H1 = ['LLM Score', 'LLM Top Candidates', 'LLM Match Note'].freeze
REVIEW_H2 = ['', '', 'A rdfs:comment'].freeze

# ── Deduplicate: merge rows that share the same NMDO IRI ──────────────────────
# Column layout within each matched_row (0-indexed):
#   0                   = NMDO IRI (ID)
#   1                   = Label
#   2                   = Definition
#   3                   = PROMOT XRef (oboInOwl:hasDbXref)
#   4..matched_h1.size-1 = annotation columns (14 URI/label pairs)
#   matched_h1.size     = LLM Score
#   matched_h1.size+1   = LLM Top Candidates
#   matched_h1.size+2   = LLM Match Note
SCORE_COL = matched_h1.size
ALT_COL   = matched_h1.size + 1
NOTE_COL  = matched_h1.size + 2
XREF_COL  = 3
ANNO_RANGE = (4...matched_h1.size).freeze

# matched entries are [row, promot_label] tuples — promot_label is kept out of the
# CSV row itself (it must not land in the LABEL column) but is still needed below
# to report each contributing PROMOT class's own name in the conflicts file.
matched_by_nmdo = matched.group_by { |(row, _label)| row[0] }

# Groups where >1 PROMOT class claimed the same NMDO IRI.
conflicts = matched_by_nmdo.select { |_, entries| entries.size > 1 }
warn "Conflicts (>1 PROMOT class → same NMDO IRI): #{conflicts.size}"

# Produce one merged row per NMDO IRI.
merged_matched = matched_by_nmdo.map do |nmdo_iri, entries|
  next entries.first[0] if entries.size == 1

  rows = entries.map { |(row, _label)| row }

  # Highest-scoring row provides Label and Definition for the merged row.
  best = rows.max_by { |r| r[SCORE_COL].to_f }

  # Union of all PROMOT cross-references (pipe-separated).
  merged_xref = rows.map { |r| r[XREF_COL] }.join('|')

  # Union of all annotation values per column, deduplicated.
  merged_annos = ANNO_RANGE.map do |col|
    vals = rows.flat_map { |r| (r[col] || '').split('|') }.uniq.reject(&:empty?)
    vals.join('|')
  end

  # Review columns: keep best score; concatenate alternatives and notes.
  merged_alts  = rows.map { |r| r[ALT_COL] }.join(' || ')
  merged_notes = rows.map { |r| r[NOTE_COL] }.join(' | ')

  [nmdo_iri] + best[1..2] + [merged_xref] + merged_annos + [best[SCORE_COL], merged_alts, merged_notes]
end

# ── Write promot-annotations-llm-matched.csv ──────────────────────────────────
# One row per NMDO IRI; annotations merged when multiple PROMOT classes matched.
matched_path = File.join(TEMPLATES_DIR, 'promot-annotations-llm-matched.csv')
warn "Writing #{matched_path} (#{merged_matched.size} rows after deduplication)..."
CSV.open(matched_path, 'w') do |csv|
  csv << matched_h1 + REVIEW_H1
  csv << matched_h2 + REVIEW_H2
  merged_matched.each { |row| csv << row }
end

# ── Write promot-annotations-llm-conflicts.csv ────────────────────────────────
# One row per NMDO IRI that was claimed by more than one PROMOT class.
# Curator action: decide whether NMDO needs to be split into finer-grained classes.
conflicts_path = File.join(TEMPLATES_DIR, 'promot-annotations-llm-conflicts.csv')
warn "Writing #{conflicts_path}..."
CSV.open(conflicts_path, 'w') do |csv|
  csv << ['NMDO IRI', 'PROMOT Count', 'PROMOT IRIs', 'PROMOT Labels', 'LLM Scores', 'Review Note']
  conflicts.each do |nmdo_iri, entries|
    entries_by_score = entries.sort_by { |(row, _label)| -row[SCORE_COL].to_f }
    csv << [
      nmdo_iri,
      entries.size,
      entries_by_score.map { |(row, _label)| row[XREF_COL] }.join(' | '),
      entries_by_score.map { |(_row, label)| label }.join(' | '),
      entries_by_score.map { |(row, _label)| row[SCORE_COL] }.join(' | '),
      "#{entries.size} PROMOT classes mapped to same NMDO IRI — verify whether NMDO needs splitting"
    ]
  end
end

# ── Write promot-annotations-llm-unmatched.csv ────────────────────────────────
# Keeps the missing-file format (with TYPE and SC %) — these may become new
# NMDO classes. Review columns show the best LLM candidate even below threshold.
unmatched_path = File.join(TEMPLATES_DIR, 'promot-annotations-llm-unmatched.csv')
warn "Writing #{unmatched_path}..."
CSV.open(unmatched_path, 'w') do |csv|
  csv << missing_h1 + REVIEW_H1
  csv << missing_h2 + REVIEW_H2
  unmatched.each { |row| csv << row }
end

warn 'Done.'
