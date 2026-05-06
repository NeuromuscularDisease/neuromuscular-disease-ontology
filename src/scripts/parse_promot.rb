require 'rdf'
require 'rdf/rdfxml'
require 'sparql'
require 'csv'

OWL_FILE = ARGV[0]
OUTPUT_FILE = File.expand_path('..', __FILE__) + '/../templates/nmdo-robot-template.csv'

HEADERS_ROW1 = %w[ID Label Definition Deprecated Entity\ Type Superclass Superproperty Domain Range]
HEADERS_ROW2 = ['ID', 'LABEL', 'A rdfs:comment', 'A owl:deprecated', 'TYPE', 'SC %', 'SP %', 'DOMAIN', 'RANGE']

$stderr.puts "Loading ontology: #{OWL_FILE}"
graph = RDF::Graph.load(OWL_FILE, format: :rdfxml)
$stderr.puts "Loaded #{graph.count} triples."



# OBJECT_PROPERTIES_QUERY = SPARQL.parse(<<~SPARQL)
#   PREFIX owl:  <http://www.w3.org/2002/07/owl#>
#   PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
#   PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
#   PREFIX obo:  <http://purl.obolibrary.org/obo/>

#   SELECT DISTINCT ?prop ?label ?definition
#   WHERE {
#     ?prop rdf:type owl:ObjectProperty .

#     OPTIONAL {
#       ?prop rdfs:label ?label .
#       FILTER(lang(?label) = "en" || lang(?label) = "")
#     }

#     OPTIONAL {
#       ?prop obo:IAO_0000115 ?definition .
#       FILTER(lang(?definition) = "en" || lang(?definition) = "")
#     }
#   }
#   ORDER BY ?prop
# SPARQL

# results = graph.query(OBJECT_PROPERTIES_QUERY)

# CSV.open(OUTPUT_FILE, 'w') do |csv|
#   csv << HEADERS_ROW1
#   csv << HEADERS_ROW2

#   results.each do |sol|
#     id         = sol[:prop].to_s
#     label      = sol[:label]&.to_s
#     definition = sol[:definition]&.to_s

#     csv << [id, label, definition, nil, 'owl:ObjectProperty', nil, nil, nil, nil]
#   end
# end

# $stderr.puts "Wrote #{results.count} object properties to #{OUTPUT_FILE}"


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

results = graph.query(ASSESSES_PROPERTIES_QUERY)
results.each do |r|
  puts "#{r[:class]}  (#{r[:classLabel]})  assesses  #{r[:filler]}  (#{r[:fillerLabel]})"
end
$stderr.puts "#{results.count} restriction(s) found."