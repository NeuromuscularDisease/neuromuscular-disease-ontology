---
layout: ontology_detail
id: nmdo
title: Neuromuscular Disease Ontology
jobs:
  - id: https://travis-ci.org/NeuromuscularDisease/neuromuscular-disease-ontology
    type: travis-ci
build:
  checkout: git clone https://github.com/NeuromuscularDisease/neuromuscular-disease-ontology.git
  system: git
  path: "."
contact:
  email: peter-bram.thoen@radboudumc.nl
  label: Peter-Bram 't Hoen
  github: pacthoen
description: Neuromuscular Disease Ontology is a project ontology built to support the mapping and integration of neuromuscular disease datasets.
domain: health
homepage: https://github.com/NeuromuscularDisease/neuromuscular-disease-ontology
products:
  - id: nmdo.owl
    name: "Neuromuscular Disease Ontology main release in OWL format"
  - id: nmdo.obo
    name: "Neuromuscular Disease Ontology additional release in OBO format"
  - id: nmdo.json
    name: "Neuromuscular Disease Ontology additional release in OBOJSon format"
  - id: nmdo/nmdo-full.owl
    name: "Neuromuscular Disease Ontology main release in OWL format"
  - id: nmdo/nmdo-full.obo
    name: "Neuromuscular Disease Ontology additional release in OBO format"
  - id: nmdo/nmdo-full.json
    name: "Neuromuscular Disease Ontology additional release in OBOJSon format"
dependencies:
- id: hgnc
- id: hp
- id: mondo
- id: ncit
- id: pato
- id: uberon
tracker: https://github.com/NeuromuscularDisease/neuromuscular-disease-ontology/issues
license:
  url: https://creativecommons.org/publicdomain/zero/1.0/
  label: CC0
activity_status: active
---

Enter a detailed description of your ontology here. You can use arbitrary markdown and HTML.
You can also embed images too.

