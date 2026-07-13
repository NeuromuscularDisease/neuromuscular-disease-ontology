# This script removes the A8, P90, and P97 annotation property declarations
PREFIX ncit: <http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#>

DELETE {
    ?property ?p ?o .
    ?s ?p2 ?property .
}
WHERE {
    VALUES ?property {
        ncit:P97
        ncit:P90
        ncit:A8
    }

    {
        ?property ?p ?o .
    }
    UNION
    {
        ?s ?p2 ?property .
    }
}
