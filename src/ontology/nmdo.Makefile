## Customize Makefile settings for nmdo
## 
## If you need to customize your Makefile, make
## changes here rather than in the main Makefile

###### BEGIN CUSTOM IMPORTS ###################

ifeq ($(IMP),true)

# BFO:0000050 = part of
# BFO:0000051 = has part
# RO:0000052 = characteristic of
# RO:0000053 = has characteristic
# RO:0002314 = characteristic of part of
# RO:0002323 = mereotopologically related to (grouping term for parthood/connectivity relationships)
# RO:0002573 = has modifier
# RO:0004003 = has material basis in germline mutation in
# RO:0004026 = disease has location
# RO:0040035 = disease relationship (grouping term - using to include the descendant relations)

OBJECT_PROPERTIES=BFO:0000050 BFO:0000051 RO:0000052 RO:0000053 RO:0002314 RO:0002323 RO:0002573 RO:0004003 RO:0004026 RO:0040035

## merged_import

# Include only specified terms and relations between them
$(IMPORTDIR)/merged_import.owl: $(MIRRORDIR)/merged.owl $(ALL_TERMS) \
				$(IMPORTSEED) | all_robot_plugins
	$(ROBOT) merge --input $< \
		 extract $(foreach f, $(ALL_TERMS), --term-file $(f)) $(T_IMPORTSEED) \
		         --force true --copy-ontology-annotations false \
		         --individuals definitions \
		         --method STAR \
		 remove $(foreach p, $(OBJECT_PROPERTIES), --term $(p)) \
		 		$(foreach p, $(ANNOTATION_PROPERTIES), --term $(p)) \
		        $(foreach f, $(ALL_TERMS), --term-file $(f)) $(T_IMPORTSEED) \
		        --select "self equivalents" --select complement \
		 odk:normalize --base-iri https://w3id.org \
		               --subset-decls true --synonym-decls true \
		 repair --merge-axiom-annotations true --invalid-references true --annotation-property oboInOwl:hasDbXref \
		 $(ANNOTATE_CONVERT_FILE)


# Include only parents and children of specified terms and relations between them
#$(IMPORTDIR)/merged_import.owl: $(MIRRORDIR)/merged.owl $(ALL_TERMS) \
#				$(IMPORTSEED) | all_robot_plugins
#	$(ROBOT) merge --input $< \
#		 extract $(foreach f, $(ALL_TERMS), --term-file $(f)) $(T_IMPORTSEED) \
#		         --force true --copy-ontology-annotations false \
#		         --individuals definitions \
#		         --method STAR \
#		 remove $(foreach p, $(OBJECT_PROPERTIES), --term $(p)) \
#		 		$(foreach p, $(ANNOTATION_PROPERTIES), --term $(p)) \
#		        $(foreach f, $(ALL_TERMS), --term-file $(f)) $(T_IMPORTSEED) \
#		        --select "self parents children" --select "self equivalents" --select complement \
#		 odk:normalize --base-iri https://w3id.org \
#		               --subset-decls true --synonym-decls true \
#		 repair --merge-axiom-annotations true --invalid-references true --annotation-property oboInOwl:hasDbXref \
#		 $(ANNOTATE_CONVERT_FILE)


# Include all related terms
#$(IMPORTDIR)/merged_import.owl: $(MIRRORDIR)/merged.owl $(ALL_TERMS) \
#				$(IMPORTSEED) | all_robot_plugins
#	$(ROBOT) merge --input $< \
#		 extract $(foreach f, $(ALL_TERMS), --term-file $(f)) $(T_IMPORTSEED) \
#		         --force true --copy-ontology-annotations false \
#		         --individuals definitions \
#		         --method STAR \
#		 remove $(foreach p, $(ANNOTATION_PROPERTIES), --term $(p)) \
#		        $(foreach f, $(ALL_TERMS), --term-file $(f)) $(T_IMPORTSEED) \
#		        --select complement --select annotation-properties \
#		 odk:normalize --base-iri https://w3id.org \
#		               --subset-decls true --synonym-decls true \
#		 collapse --threshold 2 \
#		 repair \
#		 $(ANNOTATE_CONVERT_FILE)


endif # IMP=true



ifeq ($(MIR),true)

## Overwrite HGNC mirror download
## ONTOLOGY: hgnc
mirror/hgnc_gene.nt: | $(MIRRORDIR)
	if [ $(MIR) = true ] && [ $(IMP) = true ]; then curl -L https://data.monarchinitiative.org/monarch-kg/latest/rdf/hgnc_gene.nt.gz | gzip -d > $@.tmp &&\
		perl -npe 's@https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/HGNC:@http://identifiers.org/hgnc/@g' $@.tmp > $@; fi
.PRECIOUS: mirror/hgnc_gene.nt

mirror-hgnc: mirror/hgnc_gene.nt | $(TMPDIR)
	if [ $(MIR) = true ] && [ $(IMP) = true ]; then $(ROBOT) merge -i $< \
		query --format ttl --query ../sparql/construct/construct-hgnc.sparql $(TMPDIR)/$@.owl; fi

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