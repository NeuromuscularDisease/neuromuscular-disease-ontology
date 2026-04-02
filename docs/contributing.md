# Contributing to Neuromuscular Disease Ontology

:+1: First of all: Thank you for taking the time to contribute!

The following is a set of guidelines for contributing to NMDO. 
These guidelines are not strict rules. Use your best judgment, and feel free to propose 
changes to this document in a pull request.

## Table Of Contents

- [Guidelines for Contributions and Requests](#contributions)
    * [Getting started with GitHub](#github-quickstart-guide)
    * [Reporting problems with the ontology](#reporting-bugs)
    * [Requesting new terms](#requesting-terms)
    * [How to contribute via pull requests?](#adding-terms-and-identifying-issues)
    * [How to create a great pull/merge request?](#great-pulls)
- [About NMDO](#about-nmdo)


<a id="contributions"></a>

## Guidelines for Contributions and Requests

<a id="github-quickstart-guide"></a>

### Getting started with GitHub

If you're new to GitHub or would like a short refresher, please check out the [GitHub quickstart guide](https://docs.github.com/en/get-started/start-your-journey/hello-world). It is a short hands-on tutorial that teaches you GitHub essentials like repositories, branches, commits, and pull requests. 

<a id="reporting-bugs"></a>

### Reporting problems with the ontology

Please use our [Issue Tracker](https://github.com/NeuromuscularDisease/neuromuscular-disease-ontology/issues/) for reporting problems with the ontology. 
To learn how to write a good issue [see here](https://oboacademy.github.io/obook/explanation/writing-good-issues/).

<a id="requesting-terms"></a>

### Considerations for requesting terms to be imported from external ontologies

- **Does the term already exist?**  You can search for your term using [OLS](https://www.ebi.ac.uk/ols4/) or [Ontobee](https://ontobee.org/). 

- **Is the ontology in scope for the term?** Please be sure to align with the following hierarchy of ontologies to be incorporated:

   - Disease – primary ontologies MONDO; secondary ORDO, SNOMED, ICD10/11
   - Phenotype – primary ontology HPO; secondary PhenX
   - Clinical assessment – primary ontologies NCIT; secondary SNOMED
   - Anatomy – primary ontology Uberon, secondary Uberon
   - Function and capacity: ICF
   - Assistive devices: ICF
   - Therapies / (life style) intervention – Medical Action Ontology (MAxO)
   - Genes - HGNC

#### What if my term does not exist in any of the ontologies listed?

Anyone can request new terms. However, there is no guarantee that your term will be added automatically. Some ontologies will have web forms to fill out and others will have GitHub repos where you can request new terms via github issues. Here's a list of links to where you can request terms:

- [Mondo](https://github.com/monarch-initiative/mondo/issues)
- [HPO](https://github.com/obophenotype/human-phenotype-ontology/issues)
- [PhenX](https://www.phenxtoolkit.org/about/contact-form)
- [NCIt](https://evsexplore.semantics.cancer.gov/evsexplore/termform)
- [Uberon](https://github.com/obophenotype/uberon/issues)
- [ICF](https://www.who.int/standards/classifications/international-classification-of-functioning-disability-and-health)
- [MAxO](https://github.com/monarch-initiative/MAxO/issues)
- [HGNC](https://www.genenames.org/useful/instructions-to-authors/)

#### How to write a new term request

Please refer to the [OBO Academy term request guide](https://oboacademy.github.io/obook/howto/term-request/).

<a id="adding-terms-and-identifying-issues"></a>

### How to contribute via pull requests

If you feel comfortable making edits to the repo we ask that you follow this tutorial on [using Github to make pull requests](https://oboacademy.github.io/obook/lesson/contributing-to-obo-ontologies/#use-github-make-pull-requests). For more information on best practices related to pull requests please visit the links below.

## Best Practices

<a id="great-pulls"></a>

### How to create a great pull/merge request?

Please refer to the [OBO Academy best practices](https://oboacademy.github.io/obook/howto/github-create-pull-request/).

## About NMDO

<a id="about-nmdo"></a>

### Where can I find more information about NMDO?

Please refer to the [NMDO Ontology Documentation](https://nmdo-sprints-documentation.readthedocs.io/en/latest/index.html) site.

