#!/usr/bin/env ruby
# frozen_string_literal: true

require 'set'
require 'rdf'
require 'rdf/rdfxml'
require 'sparql'
require 'csv'

PROMOT_OWL = ARGV[0] or abort "Usage: #{$0} <promot.owl> <nmdo-full.owl>"
NMDO_OWL   = ARGV[1] or abort "Usage: #{$0} <promot.owl> <nmdo-full.owl>"
TEMPLATES_DIR = File.expand_path('../templates', __dir__)

# ── Load ontologies ────────────────────────────────────────────────────────────
warn "Loading #{PROMOT_OWL}..."
promot = RDF::Graph.load(PROMOT_OWL, format: :rdfxml)
warn "  #{promot.count} triples"

warn "Loading #{NMDO_OWL}..."
nmdo = RDF::Graph.load(NMDO_OWL, format: :rdfxml)
warn "  #{nmdo.count} triples"

BASE_NS = 'urn:local:nmdo_annotations:'.freeze

# ── Routing: source ObjectProperty → target annotation key ───────────────────
# :assesses is a special case: filler namespace determines the sub-key.
SOURCE_PROPS = {
  'http://purl.obolibrary.org/obo/RO_0004029'     => :associated_phenotype,
  'http://purl.obolibrary.org/obo/PROMOT_2000006' => :associated_phenotype,
  'http://purl.obolibrary.org/obo/RO_0000091'     => :associated_phenotype,
  'http://purl.obolibrary.org/obo/PROMOT_2000002' => :assesses,
  'http://purl.obolibrary.org/obo/RO_0002328'     => :associated_function,
  'http://purl.obolibrary.org/obo/RO_0002331'     => :involved_in,
  'http://purl.obolibrary.org/obo/RO_0001025'     => :located_in,
}.freeze

def route(prop_uri, filler_uri)
  base = SOURCE_PROPS[prop_uri]
  return nil unless base
  return base unless base == :assesses
  case filler_uri
  when %r{/obo/HP_}     then :assesses_phenotype
  when /id\.who\.int/   then :assesses_function
  when %r{/obo/PROMOT_} then :captures_data_about
  end
end

# ── Annotation property declarations (14 = 7 URI + 7 parallel label siblings) ─
ANNOTATION_PROP_DEFS = [
  ['associated_phenotype',
   'associated phenotype',
   'Associates a class with HPO phenotypic signs that characterise it. ' \
   'Collapsed from PROMOT disease_has_feature (RO:0004029), is_related_to (PROMOT:2000006), ' \
   'and has_disposition (RO:0000091) subClass restrictions.'],
  ['associated_phenotype_label',
   'associated phenotype label',
   'Human-readable label for each URI in associated_phenotype. ' \
   'Values are pipe-separated and positionally parallel to associated_phenotype.'],

  ['assesses_phenotype',
   'assesses phenotype',
   'Relates a clinical assessment instrument to the HPO phenotypic sign or symptom ' \
   'it is designed to detect or measure.'],
  ['assesses_phenotype_label',
   'assesses phenotype label',
   'Human-readable label for each URI in assesses_phenotype. ' \
   'Values are pipe-separated and positionally parallel to assesses_phenotype.'],

  ['assesses_function',
   'assesses function',
   'Relates a clinical assessment instrument to the WHO-ICF body function or structure ' \
   'it is designed to measure.'],
  ['assesses_function_label',
   'assesses function label',
   'Human-readable label for each URI in assesses_function. ' \
   'Values are pipe-separated and positionally parallel to assesses_function.'],

  ['captures_data_about',
   'captures data about',
   'Relates a clinical assessment instrument to the PROMOT-defined clinical or data-model ' \
   'concept whose data it captures. Intended to guide CRF users to the correct form ' \
   'section or data domain.'],
  ['captures_data_about_label',
   'captures data about label',
   'Human-readable label for each URI in captures_data_about. ' \
   'Values are pipe-separated and positionally parallel to captures_data_about.'],

  ['associated_function',
   'associated function',
   'Associates a class with WHO-ICF functional capacities (b-codes) it is related to. ' \
   'Derived from PROMOT functionally_related_to (RO:0002328) subClass restrictions.'],
  ['associated_function_label',
   'associated function label',
   'Human-readable label for each URI in associated_function. ' \
   'Values are pipe-separated and positionally parallel to associated_function.'],

  ['involved_in',
   'involved in',
   'Associates a class with WHO-ICF activities and participation (d-codes) it is involved in. ' \
   'Derived from PROMOT involved_in (RO:0002331) subClass restrictions.'],
  ['involved_in_label',
   'involved in label',
   'Human-readable label for each URI in involved_in. ' \
   'Values are pipe-separated and positionally parallel to involved_in.'],

  ['located_in',
   'located in',
   'Associates a class with WHO-ICF body structures (s-codes) it is anatomically located in. ' \
   'Derived from PROMOT located_in (RO:0001025) subClass restrictions.'],
  ['located_in_label',
   'located in label',
   'Human-readable label for each URI in located_in. ' \
   'Values are pipe-separated and positionally parallel to located_in.'],
].freeze

# ── Column order for class templates ──────────────────────────────────────────
ANNO_KEYS = %i[
  associated_phenotype
  assesses_phenotype
  assesses_function
  captures_data_about
  associated_function
  involved_in
  located_in
].freeze

ANNO_HUMAN = {
  associated_phenotype: 'Associated Phenotype',
  assesses_phenotype:   'Assesses Phenotype',
  assesses_function:    'Assesses Function',
  captures_data_about:  'Captures Data About',
  associated_function:  'Associated Function',
  involved_in:          'Involved In',
  located_in:           'Located In',
}.freeze

# Header row 1 fragments (human-readable)
ANNO_H1 = ANNO_KEYS.flat_map { |k| ["#{ANNO_HUMAN[k]} (URI)", "#{ANNO_HUMAN[k]} (label)"] }.freeze

# Header row 2 fragments (ROBOT template instructions)
ANNO_H2 = ANNO_KEYS.flat_map do |k|
  ["A <#{BASE_NS}#{k}>^^xsd:anyURI SPLIT=|", "A <#{BASE_NS}#{k}_label> SPLIT=|"]
end.freeze

# ── SPARQL queries ─────────────────────────────────────────────────────────────

# All classes in PROMOT that carry restrictions on our 7 source properties,
# plus their label, definition, and named parents.
# Includes both PROMOT_0xxxxx (assessment tools) and WHO-ICF entities.
CLASSES_Q = SPARQL.parse(<<~SPARQL)
  PREFIX owl:  <http://www.w3.org/2002/07/owl#>
  PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  PREFIX obo:  <http://purl.obolibrary.org/obo/>
  SELECT DISTINCT ?class ?label ?definition ?parent
  WHERE {
    ?class rdf:type owl:Class .
    FILTER(
      STRSTARTS(STR(?class), "http://purl.obolibrary.org/obo/PROMOT_0") ||
      STRSTARTS(STR(?class), "http://id.who.int/icd/entity/")
    )
    OPTIONAL {
      ?class rdfs:label ?label .
      FILTER(lang(?label) = "en" || lang(?label) = "")
    }
    OPTIONAL {
      ?class obo:IAO_0000115 ?definition .
      FILTER(lang(?definition) = "en" || lang(?definition) = "")
    }
    OPTIONAL {
      ?class rdfs:subClassOf ?parent .
      FILTER(!isBlank(?parent))
    }
  }
  ORDER BY ?class
SPARQL

# All someValuesFrom restrictions on the 7 source properties.
# Covers both PROMOT_0xxxxx assessment tools and WHO-ICF classes.
RESTRICTIONS_Q = SPARQL.parse(<<~SPARQL)
  PREFIX owl:  <http://www.w3.org/2002/07/owl#>
  PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  SELECT DISTINCT ?class ?prop ?filler ?fillerLabel
  WHERE {
    ?class rdfs:subClassOf ?restriction .
    ?restriction owl:onProperty ?prop .
    ?restriction owl:someValuesFrom ?filler .
    FILTER(!isBlank(?class))
    FILTER(!isBlank(?filler))
    FILTER(
      STRSTARTS(STR(?class), "http://purl.obolibrary.org/obo/PROMOT_0") ||
      STRSTARTS(STR(?class), "http://id.who.int/icd/entity/")
    )
    VALUES ?prop {
      <http://purl.obolibrary.org/obo/RO_0004029>
      <http://purl.obolibrary.org/obo/PROMOT_2000006>
      <http://purl.obolibrary.org/obo/RO_0000091>
      <http://purl.obolibrary.org/obo/PROMOT_2000002>
      <http://purl.obolibrary.org/obo/RO_0002328>
      <http://purl.obolibrary.org/obo/RO_0002331>
      <http://purl.obolibrary.org/obo/RO_0001025>
    }
    OPTIONAL {
      ?filler rdfs:label ?fillerLabel .
      FILTER(lang(?fillerLabel) = "en" || lang(?fillerLabel) = "")
    }
  }
  ORDER BY ?class ?prop ?filler
SPARQL

# All named classes in NMDO with English labels, for label-based matching.
NMDO_Q = SPARQL.parse(<<~SPARQL)
  PREFIX owl:  <http://www.w3.org/2002/07/owl#>
  PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  SELECT DISTINCT ?class ?label
  WHERE {
    ?class rdf:type owl:Class .
    FILTER(!isBlank(?class))
    ?class rdfs:label ?label .
    FILTER(lang(?label) = "en" || lang(?label) = "")
  }
SPARQL

# SKOS mappings from NMDO classes to external IRIs (ICF, etc.).
# Lets us find the NMDO class that corresponds to a given ICF entity IRI.
NMDO_SKOS_Q = SPARQL.parse(<<~SPARQL)
  PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
  SELECT DISTINCT ?nmdo_class ?external_iri
  WHERE {
    ?nmdo_class skos:exactMatch|skos:closeMatch|skos:narrowMatch ?external_iri .
    FILTER(!isBlank(?nmdo_class))
    FILTER(!isBlank(?external_iri))
  }
SPARQL

# ── Build PROMOT class index ───────────────────────────────────────────────────
warn 'Querying PROMOT classes...'
classes = {}

promot.query(CLASSES_Q).each do |sol|
  iri = sol[:class].to_s
  rec = classes[iri] ||= {
    label:      nil,
    definition: nil,
    parents:    [],
    annos:      Hash.new { |h, k| h[k] = [] }
  }
  rec[:label]      ||= sol[:label]&.to_s
  rec[:definition] ||= sol[:definition]&.to_s
  next unless (p = sol[:parent]) && !p.anonymous?
  piri = p.to_s
  rec[:parents] << piri unless rec[:parents].include?(piri)
end
warn "  #{classes.size} classes found"

# ── Route restrictions into annotation buckets ────────────────────────────────
warn 'Routing restrictions...'
routed = 0
promot.query(RESTRICTIONS_Q).each do |sol|
  key = route(sol[:prop].to_s, sol[:filler].to_s)
  next unless key
  rec = classes[sol[:class].to_s]
  next unless rec
  pair = [sol[:filler].to_s, sol[:fillerLabel]&.to_s || sol[:filler].to_s]
  unless rec[:annos][key].include?(pair)
    rec[:annos][key] << pair
    routed += 1
  end
end
warn "  #{routed} annotations routed"

# ── Build NMDO IRI set, SKOS map, and label index ─────────────────────────────
warn 'Indexing NMDO...'
nmdo_iris         = Set.new  # direct IRI match
nmdo_by_skos      = {}       # external IRI → NMDO class IRI (via skos:exactMatch etc.)
nmdo_by_label     = {}       # English label → NMDO class IRI (fallback)

nmdo.query(NMDO_Q).each do |sol|
  iri = sol[:class].to_s
  nmdo_iris << iri
  nmdo_by_label[sol[:label].to_s.strip.downcase] = iri
end

nmdo.query(NMDO_SKOS_Q).each do |sol|
  nmdo_by_skos[sol[:external_iri].to_s] = sol[:nmdo_class].to_s
end

warn "  #{nmdo_iris.size} NMDO classes, #{nmdo_by_skos.size} SKOS mappings, #{nmdo_by_label.size} labels indexed"

# ── Split PROMOT classes: matched vs missing ───────────────────────────────────
# Matching priority:
#   1. Direct IRI — the subject IRI exists as-is in NMDO
#   2. SKOS reverse — an NMDO class has skos:exactMatch/closeMatch/narrowMatch
#                     pointing at this IRI (catches ICF entities)
#   3. Label fallback — English rdfs:label matches case-insensitively
matched = {}  # promot_iri => rec + :nmdo_iri
missing = {}  # promot_iri => rec

classes.each do |promot_iri, rec|
  nmdo_iri = if nmdo_iris.include?(promot_iri)
               promot_iri
             elsif (skos_match = nmdo_by_skos[promot_iri])
               skos_match
             elsif rec[:label]
               nmdo_by_label[rec[:label].strip.downcase]
             end
  if nmdo_iri
    matched[promot_iri] = rec.merge(nmdo_iri: nmdo_iri)
  else
    missing[promot_iri] = rec
  end
end
warn "Matched to NMDO: #{matched.size} | Missing from NMDO: #{missing.size}"

# ── Helper: serialise annotation pairs to parallel URI / label cells ───────────
def anno_cells(rec)
  ANNO_KEYS.flat_map do |k|
    pairs = rec[:annos][k].uniq
    [pairs.map(&:first).join('|'), pairs.map(&:last).join('|')]
  end
end

# ── 1. annotations-robot-template.csv ─────────────────────────────────────────
# Declares the 14 new annotation properties (7 URI + 7 label siblings).
anno_path = File.join(TEMPLATES_DIR, 'annotations-robot-template.csv')
warn "Writing #{anno_path}..."
CSV.open(anno_path, 'w') do |csv|
  csv << ['ID', 'Label', 'Definition', 'Entity Type']
  csv << ['ID', 'LABEL', 'A IAO:0000115', 'TYPE']
  ANNOTATION_PROP_DEFS.each do |slug, label, defn|
    csv << ["<#{BASE_NS}#{slug}>", label, defn, 'owl:AnnotationProperty']
  end
end

# ── 2. promot-annotations-existing.csv ────────────────────────────────────────
# One row per PROMOT class that already has a label-matched equivalent in NMDO.
# ID is the NMDO class IRI; PROMOT IRI recorded as oboInOwl:hasDbXref.
existing_path = File.join(TEMPLATES_DIR, 'promot-annotations-existing.csv')
warn "Writing #{existing_path}..."
CSV.open(existing_path, 'w') do |csv|
  csv << ['ID', 'Label', 'Definition', 'PROMOT Cross-reference'] + ANNO_H1
  csv << ['ID', 'LABEL', 'A IAO:0000115', 'A oboInOwl:hasDbXref']  + ANNO_H2
  matched.each do |promot_iri, rec|
    csv << [rec[:nmdo_iri], rec[:label], rec[:definition], promot_iri] + anno_cells(rec)
  end
end

# ── 3. promot-annotations-missing.csv ─────────────────────────────────────────
# One row per PROMOT class with no NMDO equivalent.
# ID is the PROMOT IRI itself; includes Type and Parent Class for project lead review.
missing_path = File.join(TEMPLATES_DIR, 'promot-annotations-missing.csv')
warn "Writing #{missing_path}..."
CSV.open(missing_path, 'w') do |csv|
  csv << ['ID', 'Label', 'Definition', 'Type', 'Parent Class', 'PROMOT Cross-reference'] + ANNO_H1
  csv << ['ID', 'LABEL', 'A IAO:0000115', 'TYPE', 'SC %', 'A oboInOwl:hasDbXref']        + ANNO_H2
  missing.each do |promot_iri, rec|
    csv << [
      promot_iri,
      rec[:label],
      rec[:definition],
      'owl:Class',
      rec[:parents].first,
      promot_iri,
    ] + anno_cells(rec)
  end
end

warn 'Done.'
