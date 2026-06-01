#!/usr/bin/env ruby
# frozen_string_literal: true

# Reads promot-annotations-missing.csv (output of parse_promot.rb) and
# calls the NMDO semantic search API to find best-guess NMDO matches for
# each unmatched PROMOT class.
#
# Outputs two ROBOT template files:
#   promot-annotations-llm-matched.csv   — top match >= MIN_SCORE
#   promot-annotations-llm-unmatched.csv — no confident match found
#
# Usage:
#   ruby llm_match_promot.rb [min_score]
#   ruby llm_match_promot.rb 0.20        # default

require 'csv'
require 'net/http'
require 'json'
require 'uri'

SEARCH_BASE   = 'https://simpathic.services/llm_search/search'.freeze
TEMPLATES_DIR = File.expand_path('../templates', __dir__)
MISSING_CSV   = File.join(TEMPLATES_DIR, 'promot-annotations-missing.csv')
MIN_SCORE     = (ARGV[0] || '0.20').to_f
TOP_K         = 3   # fetch top 3 so reviewers can see alternatives

warn "LLM match threshold: #{MIN_SCORE}"
warn "Reading #{MISSING_CSV}..."

rows = CSV.read(MISSING_CSV)
header1 = rows[0]
header2 = rows[1]
data    = rows[2..]

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
    # Replace ID with matched NMDO IRI; keep all annotation columns intact
    matched_row = [nmdo_iri] + row[1..] + [score.to_s, alternatives]
    matched << matched_row
  else
    warn "    ✗ best: #{nmdo_lbl.empty? ? '(none)' : nmdo_lbl} (#{score})"
    unmatched << row + [score.to_s, alternatives]
  end

  sleep 0.05  # be polite to the API
end

warn "Matched: #{matched.size} | Unmatched: #{unmatched.size}"

# ── Extra column headers ───────────────────────────────────────────────────────
# These go after the existing annotation columns.
# The ROBOT row 2 value is empty — ROBOT ignores columns with no instruction,
# so these are purely for human review.
REVIEW_H1 = ['LLM Score', 'LLM Top Candidates'].freeze
REVIEW_H2 = ['', ''].freeze

# ── Write promot-annotations-llm-matched.csv ──────────────────────────────────
# Same structure as promot-annotations-existing.csv, but ID is the LLM-matched
# NMDO IRI.  Includes review columns so the team can accept/reject easily.
matched_path = File.join(TEMPLATES_DIR, 'promot-annotations-llm-matched.csv')
warn "Writing #{matched_path}..."
CSV.open(matched_path, 'w') do |csv|
  csv << header1 + REVIEW_H1
  csv << header2 + REVIEW_H2
  matched.each { |row| csv << row }
end

# ── Write promot-annotations-llm-unmatched.csv ────────────────────────────────
# Same structure as promot-annotations-missing.csv; review columns show what
# the best candidate was even though it didn't pass the threshold.
unmatched_path = File.join(TEMPLATES_DIR, 'promot-annotations-llm-unmatched.csv')
warn "Writing #{unmatched_path}..."
CSV.open(unmatched_path, 'w') do |csv|
  csv << header1 + REVIEW_H1
  csv << header2 + REVIEW_H2
  unmatched.each { |row| csv << row }
end

warn 'Done.'
