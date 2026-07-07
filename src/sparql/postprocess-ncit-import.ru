# This script replaces the following NCIT properties with OBO properties:
#    A8	(Concept_In_Subset)	--> oboInOwl:inSubset
#    P90 (FULL_SYN)		    --> oboInOwl:hasExactSynonym
#    P97 (DEFINITION) 		--> IAO:0000115 (definition)
PREFIX owl:  <http://www.w3.org/2002/07/owl#>
PREFIX ncit: <http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#>
PREFIX obo:  <http://purl.obolibrary.org/obo/>
PREFIX oboInOwl: <http://www.geneontology.org/formats/oboInOwl#>


DELETE {
    ?subject ?oldProperty ?value .
    ?axiom owl:annotatedProperty ?oldProperty .
}
INSERT {
    ?subject ?newProperty ?value .
    ?axiom owl:annotatedProperty ?newProperty .
}
WHERE {
    VALUES (?oldProperty ?newProperty) {
        (ncit:P97 obo:IAO_0000115)
        (ncit:P90 oboInOwl:hasExactSynonym)
        (ncit:A8 oboInOwl:inSubset)
    }

    ?subject ?oldProperty ?value .

    OPTIONAL {
        ?axiom a owl:Axiom ;
            owl:annotatedSource ?subject ;
            owl:annotatedProperty ?oldProperty ;
            owl:annotatedTarget ?value .
    }
}
