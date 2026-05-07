require 'rdf'
require 'rdf/rdfxml'
require 'sparql'
require 'csv'

# Header	Meaning	Generated axiom
# SC %	SubClass	rdfs:subClassOf <value>
# SP %	SubProperty	rdfs:subPropertyOf <value>
# There are several others in the same family:

# Header	Meaning
# EC %	owl:equivalentClass
# EP %	owl:equivalentProperty
# DC %	owl:disjointWith (class)
# DP %	owl:propertyDisjointWith
# C %	Anonymous class expression (for use in restrictions like SC 'part of' some %)
# The % substitution can write Manchester Syntax expressions directly in the cell, e.g.:

# SC %
# 'part of' some UBERON:0000948
# Which would generate: rdfs:subClassOf ('part of' some UBERON:0000948)

# Headers with novel properties are declared as:
# A <property IRI>^^xsd:datatype  with the value in that column being the annnotation that is addeed

OWL_FILE = ARGV[0]
warn "Loading ontology: #{OWL_FILE}"
graph = RDF::Graph.load(OWL_FILE, format: :rdfxml)
warn "Loaded #{graph.count} triples."

OUTPUT_FILE = File.expand_path(__dir__) + '/../templates/annotations-robot-template.csv'
ANNOTATION_HEADERS_ROW1 = ['ID', 'Label', 'Definition', 'Entity Type']
ANNOTATION_HEADERS_ROW2 = ['ID', 'LABEL', 'A rdfs:comment', 'TYPE']

OBJECT_PROPERTIES_QUERY = SPARQL.parse(<<~SPARQL)
  PREFIX owl:  <http://www.w3.org/2002/07/owl#>
  PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  PREFIX obo:  <http://purl.obolibrary.org/obo/>

  SELECT DISTINCT ?prop ?label ?definition
  WHERE {
    ?prop rdf:type owl:ObjectProperty .

    OPTIONAL {
      ?prop rdfs:label ?label .
      FILTER(lang(?label) = "en" || lang(?label) = "")
    }

    OPTIONAL {
      ?prop obo:IAO_0000115 ?definition .
      FILTER(lang(?definition) = "en" || lang(?definition) = "")
    }
  }
  ORDER BY ?prop
SPARQL

results = graph.query(OBJECT_PROPERTIES_QUERY)

CSV.open(OUTPUT_FILE, 'w') do |csv|
  csv << ANNOTATION_HEADERS_ROW1
  csv << ANNOTATION_HEADERS_ROW2

  seen = {}
  results.each do |sol|
    # id         = sol[:prop]&.to_s.strip
    label      = sol[:label]&.to_s
    definition = sol[:definition]&.to_s

    id = "<urn:local:nmdo_annotations:#{label.gsub(/\s/, '-')}>"
    next if seen[id]

    seen[id] = true

    csv << [id, label, definition, 'owl:AnnotationProperty']
  end
end

warn 'Now doing assesses properties'

OUTPUT_FILE = File.expand_path(__dir__) + '/../templates/assesses-robot-template.csv'
ASSESSES_HEADERS_ROW1 = ['ID', 'Label', 'Assesses HPO']
ASSESSES_HEADERS_ROW2 = ['ID', 'LABEL', 'A <urn:local:nmdo_annotations:assesses>^^anyURI']

ASSESSES_PROPERTIES_QUERY = SPARQL.parse(<<~SPARQL)
  PREFIX owl:  <http://www.w3.org/2002/07/owl#>
  PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  PREFIX obo:  <http://purl.obolibrary.org/obo/>

  SELECT DISTINCT ?class ?classLabel ?filler ?fillerLabel
  WHERE {
    # ?restriction is the blank node; ?class is the named class that uses it
    ?restriction owl:onProperty obo:PROMOT_2000002 .
    ?restriction owl:someValuesFrom ?filler .
    ?class rdfs:subClassOf ?restriction .

    OPTIONAL {
      ?class rdfs:label ?classLabel .
      FILTER(lang(?classLabel) = "en" || lang(?classLabel) = "")
    }
    OPTIONAL {
      ?filler rdfs:label ?fillerLabel .
      FILTER(lang(?fillerLabel) = "en" || lang(?fillerLabel) = "")
    }
  }
  ORDER BY ?class ?filler
SPARQL

puts ['ID', 'Label', 'Assesses HPO']

results = graph.query(ASSESSES_PROPERTIES_QUERY)
results.each do |r|
  puts [r[:class], r[:classLabel], r[:filler], r[:fillerLabel]].join("\t")
end
warn "#{results.count} restriction(s) found."
