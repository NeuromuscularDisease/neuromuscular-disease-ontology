## Customize Makefile settings for nmdo
## 
## If you need to customize your Makefile, make
## changes here rather than in the main Makefile

###### BEGIN CUSTOM IMPORTS ###################

ifeq ($(IMP),true)

# Add "mondo_terms_nmd_branch.txt" to the ALL_TERMS list to use in the merged_import.owl command
ALL_TERMS = $(foreach imp, $(IMPORTS), $(IMPORTDIR)/$(imp)_terms.txt) $(IMPORTDIR)/mondo_terms_nmd_branch.txt

## Overwrite merged_import
# Changes from original command in Makefile:
#    - Added "remove --term IAO:0000102 ..." line to remove the 'data about an ontology part' class and all descendents
#	 - Added "remove --term MONDO:0021178 ..." line to remove the Mondo 'injury' branch
#    - Added "collapse ..." line to remove unnecessary intermediate classes
$(IMPORTDIR)/merged_import.owl: $(MIRRORDIR)/merged.owl $(ALL_TERMS) \
				$(IMPORTSEED) | all_robot_plugins
	$(ROBOT) merge --input $< \
		 remove --select "<http://purl.obolibrary.org/obo/BFO_*>" \
		 remove --select "<http://purl.obolibrary.org/obo/CHEBI_*>" \
		 remove --select "<http://purl.obolibrary.org/obo/CHR_*>" \
		 remove --select "<http://purl.obolibrary.org/obo/CL_*>" \
		 remove --select "<http://purl.obolibrary.org/obo/CLM_*>" \
		 remove --select "<http://purl.obolibrary.org/obo/ECTO_*>" \
		 remove --select "<http://purl.obolibrary.org/obo/GO_*>" \
		 remove --select "<http://purl.obolibrary.org/obo/HsapDv_*>" \
		 remove --select "<http://purl.obolibrary.org/obo/MAXO_*>" \
		 remove --select "<http://purl.obolibrary.org/obo/MF_*>" \
		 remove --select "<http://purl.obolibrary.org/obo/NBO_*>" \
		 remove --select "<http://purl.obolibrary.org/obo/NCBITaxon_*>" \
		 remove --select "<http://purl.obolibrary.org/obo/PR_*>" \
		 remove --select "<https://bioregistry.io/*>" \
		 remove --select "<http://purl.uniprot.org/uniprot/*>" \
		 remove --select "<http://www.informatics.jax.org/accession/MGI*>" \
		 remove --select "<http://rgd.mcw.edu/rgdweb/report/gene/*>" \
		 remove --select "<http://identifiers.org/ncbigene/*>" \
		 remove --term IAO:0000102 --select "self descendants" --signature true \
		 remove --term MONDO:0021178 --select "self descendants" --signature true \
		 extract $(foreach f, $(ALL_TERMS), --term-file $(f)) $(T_IMPORTSEED) \
		         --force true --copy-ontology-annotations false \
		         --individuals exclude \
		         --method STAR \
		 remove $(foreach p, $(ANNOTATION_PROPERTIES), --term $(p)) \
		        $(foreach f, $(ALL_TERMS), --term-file $(f)) $(T_IMPORTSEED) \
		        --select complement --select annotation-properties \
		 odk:normalize --base-iri http://purl.obolibrary.org/obo \
		               --subset-decls true --synonym-decls true \
		 collapse $(foreach f, $(ALL_TERMS), --precious-terms $(f)) \
		 repair --merge-axiom-annotations true \
		 $(ANNOTATE_CONVERT_FILE)

endif # IMP=true


# Get all descendants of "neuromuscular disease" (MONDO:0019056) and write to an import term file
$(IMPORTDIR)/mondo_terms_nmd_branch.txt: $(MIRRORDIR)/mondo.owl
	runoak -i sqlite:obo:mondo descendants MONDO:0019056 -p i -o $@ && \
	sed -i 's/!/\#/g' $@


ifeq ($(MIR),true)

## Overwrite HGNC mirror download
## ONTOLOGY: hgnc
mirror-hgnc: | $(TMPDIR)
	curl -L https://w3id.org/biopragmatics/resources/hgnc/hgnc.ofn --create-dirs -o $(TMPDIR)/hgnc-download.ofn.tmp --retry 4 --max-time 500 && \
	perl -npe 's@https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/@http://identifiers.org/hgnc/@g' $(TMPDIR)/hgnc-download.ofn.tmp > $(TMPDIR)/hgnc-download.ofn
	$(ROBOT) convert -i $(TMPDIR)/hgnc-download.ofn -o $(TMPDIR)/$@.owl


## Overwrite NCIT mirror to reduce size
## ONTOLOGY: ncit
.PHONY: mirror-ncit
.PRECIOUS: $(MIRRORDIR)/ncit.owl
ifeq ($(IMP_LARGE),true)
# Using the source EVS version of NCIT instead of the OBO edition one in order to use newly created terms (EVS has a monthly release cycle).
# The `postprocess-ncit-*.ru` scripts replace some of the NCIT annotation properties with OBO properties (similar to what is done in the OBO edition version).
mirror-ncit: $(IMPORTDIR)/ncit_terms.txt $(IMPORTDIR)/ncit_terms_exclude.txt $(SPARQLDIR)/postprocess-ncit-import.ru $(SPARQLDIR)/postprocess-ncit-import-cleanup.ru | $(TMPDIR)
	$(ROBOT) --prefix "NCIT: http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#" \
			remove -I https://evs.nci.nih.gov/ftp1/rdf/Thesaurus.owl --base-iri http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl# \
				--axioms external --preserve-structure false --trim false \
			extract --term-file $< \
		         --force true --copy-ontology-annotations true \
		         --individuals exclude \
		         --method STAR \
			remove --term-file $(IMPORTDIR)/ncit_terms_exclude.txt --select "self" \
			query --update $(SPARQLDIR)/postprocess-ncit-import.ru \
			query --update $(SPARQLDIR)/postprocess-ncit-import-cleanup.ru \
			-o $(TMPDIR)/$@.tmp.owl && \
	perl -npe 's@http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#@http://purl.obolibrary.org/obo/NCIT_@g' $(TMPDIR)/$@.tmp.owl > $(TMPDIR)/$@.owl
endif

endif # MIR=true


###### END CUSTOM IMPORTS ###################




###### BEGIN TEMPLATE MANAGEMENT ###################

TEMPLATE_NAMES := nmdo
TEMPLATE_FILES := $(foreach x,$(TEMPLATE_NAMES),$(TEMPLATEDIR)/$(x).tsv)

# Sort template tables, standardize quoting and line endings
.PHONY: sort-templates
sort-templates: $(SCRIPTSDIR)/sort-templates.py $(TEMPLATE_FILES)
	$(foreach x,$(TEMPLATE_FILES),python $(SCRIPTSDIR)/sort-templates.py $(x);)


###### END TEMPLATE MANAGEMENT ###################





# Get the Mondo-to-ORPHA dbXref mappings
$(TMPDIR)/mondo-orphanet-mappings.tsv:
	runoak -i sqlite:obo:mondo mappings -M Orphanet -O sssom --autolabel -o $@ 