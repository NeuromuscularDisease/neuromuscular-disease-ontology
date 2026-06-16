## Customize Makefile settings for nmdo
## 
## If you need to customize your Makefile, make
## changes here rather than in the main Makefile

###### BEGIN CUSTOM IMPORTS ###################

ifeq ($(IMP),true)

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
		 remove --term IAO:0000102 --select "self descendants" --signature true \
		 remove --term MONDO:0021178 --select "self descendants" --signature true \
		 extract $(foreach f, $(ALL_TERMS), --term-file $(f)) $(T_IMPORTSEED) \
		         --force true --copy-ontology-annotations false \
		         --individuals exclude \
		         --method STAR \
		 remove $(foreach p, $(ANNOTATION_PROPERTIES), --term $(p)) \
		        $(foreach f, $(ALL_TERMS), --term-file $(f)) $(T_IMPORTSEED) \
		        --select complement --select annotation-properties \
		 odk:normalize --base-iri https://w3id.org \
		               --subset-decls true --synonym-decls true \
		 collapse $(foreach f, $(ALL_TERMS), --precious-terms $(f)) \
		 repair --merge-axiom-annotations true \
		 $(ANNOTATE_CONVERT_FILE)

endif # IMP=true



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
mirror-ncit: $(IMPORTDIR)/ncit_terms.txt $(IMPORTDIR)/ncit_terms_exclude.txt | $(TMPDIR)
	curl -L $(OBOBASE)/ncit.owl --create-dirs -o $(TMPDIR)/ncit-download.owl --retry 4 --max-time 500 && \
	$(ROBOT) remove -i $(TMPDIR)/ncit-download.owl --base-iri NCIT --axioms external --preserve-structure false --trim false \
			extract --term-file $< \
		         --force true --copy-ontology-annotations true \
		         --individuals exclude \
		         --method STAR \
			remove --term-file $(IMPORTDIR)/ncit_terms_exclude.txt --select "self" \
			-o $(TMPDIR)/$@.owl
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