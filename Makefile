# Makefile for phd. 
#
# Created    Thu Feb 04 11:21:04 2010 by Yves Frederix,
# Refactored Mon Jul 26 10:27:00 2010 by Wannes Meert,
#
# Usage:
#    Create full thesis:
#    $ make
# 
#    To run for a specific set of chapters, run with CHAPTERS variable:
#    $ make CHAPTERS=introduction
#    $ make CHAPTERS="introduction conclusion"
# 
#    Cleaning:
#    $ make clean
#    $ make realclean
#
#    Checks:
#    $ make sanitycheck
#    $ make spelling
#    $ make grammar
# 
#    Create final thesis
#    $ make thesisfinal
#
# Chapter specific tricks:
#
#    Create new chapters 'MYCHAPTER' as follows:
#    $ make newchapter
#
#    From inside a chapter directory, run 'make' to build that chapter only
#    (This generates a document with TOC, chapter and references).
#    e.g.:
#    $ cd chapter/introduction
#    $ make      # --> generates introduction.pdf in the current directory
#
# Options:
#    The default settings in this makefile can be overridden by a
#    Makefile.settings file.
#

# Define default target before importing other Makefile settings
all: default

# Use bash as default shell
SHELL = bash

# Auxiliary variables
empty:=
space:= $(empty) $(empty)
comma:= ,

##############################################################################
### DEFAULT SETTINGS (can be overridden by Makefile.settings) ################

# Filenames
MAINDIR = $(empty)$(empty)
MAINTEX = thesis.tex
MAINBIBTEXFILE = thesis.bib
DEFS_THESIS = defs_thesis.tex # Thesiswide preamble settings

CHAPTERSDIR = chapters
IMAGEDIR = image # This corresponds to $(CHAPTERSDIR)/<chapter>/$(IMAGEDIR)

DEFS = defs.tex # Autogenerated by this Makefile from $(DEFS_THESIS) 
				# and $(CHAPTERSDIR)/*/$(DEFS).

CLEANEXTENSIONS = toc aux log bbl blg log lof lot ilg out glo gls nlo nls brf ist glg synctex.gz tgz idx ind
REALCLEANEXTENSIONS = dvi pdf ps

FORCE_REBUILD = .force_rebuild

USEPDFTEX ?= 0 # can be externally set

# Binaries
TEX = latex
PDFTEX = pdflatex
DVIPS = dvips
PS2PDF = ps2pdf -dMaxSubsetPct=100 -dSubsetFonts=true -dEmbedAllFonts=true \
		  -dPDFSETTINGS=/printer -dCompatibilityLevel=1.3
BIBTEX = bibtex
MAKEINDEX = makeindex
DETEX = detex
GNUDICTION = diction
GNUSTYLE = style
ASPELL = aspell --lang=en_GB --add-tex-command="eqref p" \
			--add-tex-command="psfrag pP" --add-tex-command="special p" \
			--encoding=iso-8859-1 -t

##############################################################################
### INCLUDE GENERAL SETTINGS (Everything above can be overridden) ############
include Makefile.settings
 
##############################################################################
### DERIVED SETTINGS #########################################################
 
# Other tex files that might be included in $(MAINTEX)
INCLUDEDCHAPTERNAMES = $(shell grep -e "^[^%]*\include" $(MAINTEX) | \
					   sed -n -e 's|.*{\(.*\)}.*|\1|p')

# Check if we passed the environment variable CHAPTERS. If so, redefine
# $(CHAPTERNAMES).
ifneq ($(origin CHAPTERS), undefined) 
	CHAPTERNAMES = $(CHAPTERS) 
#	CHAPTERINCLUDEONLYSTRING = $(subst $(space),$(comma),$(foreach chaptername,$(CHAPTERNAMES),$(CHAPTERSDIR)/$(chaptername)/$(chaptername)))
else
	CHAPTERNAMES = $(subst ./,,$(shell (cd $(CHAPTERSDIR); find -mindepth 1 -maxdepth 1 -type d)))
#	CHAPTERINCLUDEONLYSTRING = 
endif

# CHAPTERINCLUDEONLYSTRING is empty if CHAPTERS environment variable is not
# provided:
CHAPTERINCLUDEONLYSTRING = $(if $(CHAPTERS),$(subst $(space),$(comma),$(foreach chaptername,$(CHAPTERS),$(CHAPTERSDIR)/$(chaptername)/$(chaptername))),)

CHAPTERTEXS = $(foreach chaptername,$(CHAPTERNAMES),$(shell test -f $(CHAPTERSDIR)/$(chaptername)/.ignore || echo $(CHAPTERSDIR)/$(chaptername)/$(chaptername).tex) )
CHAPTERAUX = $(CHAPTERTEXS:.tex=.aux)
CHAPTERMAKEFILES = $(foreach chaptername,$(CHAPTERNAMES),$(CHAPTERSDIR)/$(chaptername)/Makefile)
# TODO: onderstaande wildcard dinges kunnen nog verbeterd worden!
CHAPTERDEFS = $(wildcard $(CHAPTERSDIR)/*/$(DEFS))

DVIFILE     = $(MAINTEX:.tex=.dvi)
PSFILE      = $(MAINTEX:.tex=.ps)
PDFFILE     = $(MAINTEX:.tex=.pdf)
BBLFILE     = $(MAINTEX:.tex=.bbl)
NOMENCLFILE = $(MAINTEX:.tex=.nls)
GLOSSFILE   = $(MAINTEX:.tex=.gls)

IGNOREINCHAPTERMODE = \(makefrontcover\|makebackcover\|maketitle\|includepreface\|includeabstract\|listoffigures\|listoftables\|printnomenclature\|printglossary\|includecv\|includepublications\|includeonly\|instructionschapters\)

IGNOREINCHAPTERMODEBARE = $(subst makefrontcover,makefrontcover\|tableofcontents,$(IGNOREINCHAPTERMODE))

# Dependencies for the main pdf file (Make sure $(MAINTEX) is the first in
# this list!)
DEPENDENCIES = $(MAINTEX) $(DEFS) $(EXTRADEP) $(CHAPTERTEXS) $(CHAPTERMAKEFILES) $(BBLFILE) $(NOMENCLFILE) $(GLOSSFILE) $(FORCE_REBUILD)

# Search for pdfnup and use it (instead of psnup) if found
PDFNUP = $(shell which pdfnup)

test:
	@echo $(CHAPTERNAMES)
	#@echo $(IGNOREINCHAPTERMODEBARE)
	#@echo $(PDFNUP)
	#@echo $(CHAPTERAUX)
	#echo 'lkasdjf'
	#echo $(CHAPTERNAMES)
	#echo $(wildcard $(CHAPTERSDIR)/*)/Makefile
	#echo $(wildcard $(CHAPTERSDIR)/*/$(DEFS))
	#echo $(CHAPTERDEFS)

# Default build target
default: $(PDFFILE)

##############################################################################
### BUILD PDF/PS (with relaxed dependencies on bibtex, nomenclature, glossary)

ifeq ($(USEPDFTEX), 1)

$(TEX) = $(PDFTEX)

##################################################
# BUILD THESIS
$(PDFFILE): $(DEPENDENCIES)
	$(TEX) -jobname $(@:.pdf=) $<

##################################################
# BUILD CHAPTERS
# The following rules provide compilation of individual chapters.
$(CHAPTERSDIR)/%_ch.pdf: $(DEPENDENCIES)
	$(TEX) -jobname $(@:.pdf=) $<
	$(TEX) -jobname $(@:.pdf=) $<
	$(RM) $(@:_ch.pdf=).{$(subst $(empty) $(empty),$(comma),$(CLEANEXTENSIONS))}

$(CHAPTERSDIR)/%.pdf: $(DEPENDENCIES)
	$(MAKE) $(CHAPTERSDIR)/$*_ch.pdf
	mv $(CHAPTERSDIR)/$*_ch.pdf $@

##################################################

else

##################################################
# BUILD THESIS
    ifneq ($(CHAPTERINCLUDEONLYSTRING),"")

$(DVIFILE): MYMAINTEX = $(MAINTEX:.tex=_sel.tex)
$(DVIFILE): $(DEPENDENCIES)
	sed -e 's|\\begin{document}|\\includeonly{$(CHAPTERINCLUDEONLYSTRING)}\\begin{document}|' $(MAINTEX) > $(MYMAINTEX)
	[ -f $(BBLFILE) ] && cp $(BBLFILE) $(BBLFILE:.bbl=_sel.bbl)
	[ -f $(NOMENCLFILE) ] && cp $(NOMENCLFILE) $(NOMENCLFILE:.nls=_sel.nls)
	[ -f $(GLOSSFILE) ] && cp $(GLOSSFILE) $(GLOSSFILE:.gls=_sel.gls)
	$(TEX) -jobname $(@:.dvi=) $(MYMAINTEX)
	$(TEX) -jobname $(@:.dvi=) $(MYMAINTEX)
	$(RM) $(MYMAINTEX:.tex=).{$(subst $(empty) $(empty),$(comma),$(CLEANEXTENSIONS))}
	$(RM) $(MYMAINTEX)

    else

$(DVIFILE): $(DEPENDENCIES)
	$(TEX) -jobname $(@:.dvi=) $(MAINTEX)
	$(TEX) -jobname $(@:.dvi=) $(MAINTEX)

    endif

# Do NOT remove the following line:
$(DVIFILE:.dvi=_bare.dvi): CHAPTERINCLUDEONLYSTRING = $(subst $(space),$(comma),$(foreach chaptername,$(CHAPTERNAMES),$(CHAPTERSDIR)/$(chaptername)/$(chaptername)))
$(DVIFILE:.dvi=_bare.dvi): MYMAINTEX = $(MAINTEX:.tex=_bare.tex)
$(DVIFILE:.dvi=_bare.dvi): $(DEPENDENCIES)
	@echo $(CHAPTERNAMES)
	@echo $(CHAPTERTEXS)
	@echo "Creating '$@' only containing chapters:"
	@for i in $(CHAPTERNAMES); do echo "  + $$i"; done
	grep -v '$(IGNOREINCHAPTERMODEBARE)' $(MAINTEX) \
		| sed -e 's|\\begin{document}|\\includeonly{$(CHAPTERINCLUDEONLYSTRING)}\\begin{document}|' > $(MYMAINTEX)
	[ -f $(BBLFILE) ] && cp $(BBLFILE) $(BBLFILE:.bbl=_bare.bbl)
	[ -f $(NOMENCLFILE) ] && cp $(NOMENCLFILE) $(NOMENCLFILE:.nls=_bare.nls)
	[ -f $(GLOSSFILE) ] && cp $(GLOSSFILE) $(GLOSSFILE:.gls=_bare.gls)
	$(TEX) -jobname $(@:.dvi=) $(MYMAINTEX)
	sed -i.bak -e 's/\\includebibliography/%\\includebibliography/' $(MYMAINTEX)
	$(TEX) -jobname $(@:.dvi=) $(MYMAINTEX)
	$(RM) $(@:.dvi=).{$(subst $(empty) $(empty),$(comma),$(CLEANEXTENSIONS))}
	$(RM) $(MYMAINTEX){,.bak}

# Clear the default rule dvi <-- tex (otherwise it gets preference over the
# rule that generates $(CHAPTERSDIR)/%_ch.dvi below!!)
%.dvi: %.tex

#$(DVIFILE): %.dvi : $(FORCE_REBUILD)
#	@echo DVIFILE:%%.dvi rule
#	$(TEX) -jobname $(@:.dvi=) $(MAINTEX)
#	$(TEX) -jobname $(@:.dvi=) $(MAINTEX)

%.ps: %.dvi
	$(DVIPS) -P pdf -o $@ $<

%.pdf: %.ps
	$(PS2PDF) $< $@

##################################################
# BUILD CHAPTERS
# The following rules provide compilation of individual chapters.
$(CHAPTERSDIR)/%_ch.dvi: CHAPTERINCLUDEONLYSTRING = $(subst $(space),$(comma),$(foreach chaptername,$(CHAPTERNAMES),$(CHAPTERSDIR)/$(chaptername)/$(chaptername)))
$(CHAPTERSDIR)/%_ch.dvi: $(DEPENDENCIES)
	grep -v '$(IGNOREINCHAPTERMODE)' $(MAINTEX) \
		| sed -e 's|\\begin{document}|\\includeonly{$(CHAPTERINCLUDEONLYSTRING)}\\begin{document}|' > ch_$(MAINTEX)
	[ -f $(BBLFILE) ] && cp $(BBLFILE) $(CHAPTERSDIR)/$(BBLFILE:.bbl=_ch.bbl)
	[ -f $(NOMENCLFILE) ] && cp $(NOMENCLFILE) $(CHAPTERSDIR)/$(NOMENCLFILE:.nls=_ch.nls)
	[ -f $(GLOSSFILE) ] && cp $(GLOSSFILE) $(CHAPTERSDIR)/$(GLOSSFILE:.gls=_ch.gls)
	$(TEX) -jobname $(@:.dvi=) ch_$(MAINTEX)
	$(TEX) -jobname $(@:.dvi=) ch_$(MAINTEX)
	$(RM) $(@:.dvi=).{$(subst $(empty) $(empty),$(comma),$(CLEANEXTENSIONS))}
	$(RM) ch_$(MAINTEX)

# The following rule creates e.g. chapters/introduction/introduction.pdf
# containing only the chapter 'introduction'. The difficulty in doing this, is
# that there also exists a file chapters/introduction/introduction.tex, which
# means the 'standard' rules already match but 
#  (1) do not do what we want; and
#  (2) do not have the correct dependencies. 
# To get around this, I want to generate first
# chapters/introduction/introduction_ch.pdf as follows
#    _ch.pdf <-- ps <-- dvi: all dependencies
# The dvi file is generated with the correct dependencies by the previous
# rule. 
#
# Pitfall: to force the pdf/ps/dvi chain to be followed, it must have the
# preference over recursively matching this one. 
# --> include %_ch.ps (which is the same prereq. as the rule that generates
#  the chain (the one after this one).
# _more_ specific than the following so that it will be chosen over that one.
$(CHAPTERSDIR)/%.pdf: $(DEPENDENCIES) $(CHAPTERSDIR)/%_ch.ps
	$(MAKE) $(CHAPTERSDIR)/$*_ch.pdf
	mv $(CHAPTERSDIR)/$*_ch.pdf $@

# The following rules ensures that the pdf/ps/dvi chain has preference over
# recursively using the previous one!
$(CHAPTERSDIR)/%_ch.pdf: $(CHAPTERSDIR)/%_ch.ps

endif

##############################################################################
### PUT 2 LOGICAL PAGES ON SINGLE PHYSICAL PAGE  #############################

.PHONY: psnup
psnup: $(PDFFILE)
	if [ "$(PDFNUP)" != "" ]; then \
		pdfnup --frame true $<;\
	else \
		pdftops -q $< - | psnup -q -2 -d1 -b0 -m20 -s0.65 > $(PDFFILE:.pdf=-2x1.ps);\
		echo "Finished: output is $$PWD/$(PDFFILE:.pdf=-2x1.ps)";\
	fi;

##############################################################################
### DEFS #####################################################################
$(DEFS): $(DEFS_THESIS) $(CHAPTERDEFS)
	cat $(DEFS_THESIS) > $@
	for i in $(CHAPTERDEFS);\
	do \
	  [ -f $$i ] && ! [ -L $$i ] && (cat $$i >> $@);\
	done

##############################################################################
### BUILD THESIS #############################################################
.PHONY: thesisfinal
thesisfinal: $(MAINTEX) $(DEFS) $(FORCE_REBUILD)
	@make nomenclature
	@echo "Running bibtex..."
	$(BIBTEX) $(basename $<)
	@echo "Running latex a second time..."
	$(TEX) $<
	@echo "Running latex a third time..."
	$(TEX) $<
	@echo "Converting dvi -> ps -> pdf..."
	make $(PDFFILE)
	@echo "Done."

##############################################################################
### MISC CHAPTER STUFF #######################################################
.PHONY: newchapter
newchapter:
	@echo -n "Input name for the new chapter: " && \
	read NEWCHAPNAME && \
	NEWCHAPNAME=$${NEWCHAPNAME// /-} && \
	echo -e "\n *** Creating $$NEWCHAPNAME *** \n" && \
	cd $(CHAPTERSDIR) && ./makeemptychapter.sh $$NEWCHAPNAME && \
	echo -e "\n==> Succesfully created new chapter '$$NEWCHAPNAME'"

%_bare: BARECHAPNAME = $(@:_bare=)
%_bare: $(CHAPTERAUX) $(CHAPTERSDIR)/%  
	@echo "Creating chapter 'my$(BARECHAPNAME)'..."
	#IGNOREINCHAPTERMODEBARE=$$(echo '$(IGNOREINCHAPTERMODEBARE)' | sed -e 's/\\|includeabstract//')
	#@echo "$$IGNOREINCHAPTERMODEBARE"
	grep -v '$(IGNOREINCHAPTERMODEBARE)' $(MAINTEX) \
		| sed -e 's|\\begin{document}|\\includeonly{$(CHAPTERSDIR)/$(BARECHAPNAME)/$(BARECHAPNAME)}\\begin{document}|' > my$@.tex
	$(TEX) my$@.tex
	make my$@.bbl
	$(TEX) my$@.tex
	$(TEX) my$@.tex
	sed -i.bak -e 's/^.*bibliography.*$$//' my$@.tex 
	$(TEX) my$@.tex
	make my$@.ps my$@.pdf
	make cleanpar TARGET=my$@
	$(RM) my$@.tex my$@.tex.bak

$(CHAPTERAUX): $(DEFS) $(CHAPTERTEXS)
	@echo "Creating $@ ..."
	$(TEX) $(MAINTEX)

.PHONY: chaptermakefiles
chaptermakefiles: $(CHAPTERMAKEFILES)

$(CHAPTERSDIR)/%/Makefile: $(CHAPTERSDIR)/Makefile.chapters
	@echo "Generating chapter makefile [$@]..."
	@echo "# Autogenerated Makefile, $(shell date)." > $@
	@echo "" >> $@
	@echo "MAINDIR = $(PWD)" >> $@
	@echo "" >> $@
	@echo "s:" >> $@
	@echo -e "\t@@echo $(EDITOR) $(@:$(CHAPTERSDIR)/%/Makefile=%).tex $(MAINBIBTEXFILE) $(DEFS) > \$$@" >> $@
	@echo -e "\t@@chmod +x \$$@" >> $@
	@echo -e "\t@@echo You can now start using ./s" >> $@
	@echo "" >> $@
	@echo ".PHONY: $*.pdf" >> $@
	@echo "$*.pdf: " >> $@
	@echo -e "\t( cd \$$(MAINDIR) && make $(CHAPTERSDIR)/$*/\$$@ )" >> $@

##############################################################################
### BIBTEX/REFERENCES ########################################################

.PHONY: ref
ref: 
	@make $(BBLFILE)

%.bbl: %.tex $(MAINBIBTEXFILE)
	@echo "Running latex..."
	$(TEX) $<
	@echo "Running bibtex..."
	$(BIBTEX) $(<:.tex=)
	@[ -f $(<:.tex=.dvi) ] && $(RM) $(<:.tex=.dvi)

reflist:
	fgrep "\cite" $(MAINTEX) | grep -v "^%.*" | \
		sed -n -e 's/^.*cite{\([^}]*\)}.*/\1/p' | sed -e 's/,/\n/g' | uniq $(PIPE)

reflist.bib: PIPE := | python extract_from_bibtex.py --bibfile=$(MAINBIBTEXFILE)--stdin > reflist.bib
reflist.bib: reflist

##############################################################################
### NOMENCLATURE  ############################################################

.PHONY: nomenclature
nomenclature: 
	@make $(NOMENCLFILE)
	
$(MAINTEX:.tex=).nls: $(MAINTEX) $(DEFS)
%.nls: %.tex
	@echo "Running latex..."
	$(TEX) $<
	@echo "Creating nomenclature..."
	$(MAKEINDEX) $(<:.tex=.nlo) -s nomencl.ist -o $(<:.tex=.nls)
	$(RM) $(DVIFILE)

##############################################################################
### GLOSSARY: LIST OF ABBREVIATIONS  #########################################

.PHONY: glossary
glossary: 
	@make $(GLOSSFILE)
	
%.gls: %.tex
	@echo "Running latex..."
	$(TEX) $<
	@echo "Creating nomenclature..."
	$(MAKEINDEX) $(<:.tex=.glo) -s $(<:.tex=.ist) -t $(<:.tex=.glg) -o $(<:.tex=.gls)
	$(RM) $(DVIFILE)

##############################################################################
### FORCE REBUILD ############################################################

#force: touch all
force_rebuild: force_rebuild_ all
force_rebuild_:
	touch $(FORCE_REBUILD)

$(FORCE_REBUILD):
	[ -e $(FORCE_REBUILD) ] || touch $(FORCE_REBUILD)

##############################################################################
### FIGURES ##################################################################

image: figures

figures:
	cd image && make

figurelist:
	@fgrep includegraphic $(MAINTEX) | sed 's/^[ \t]*//' | grep -v "^%" | \
		sed -n -e 's/.*includegraphics[^{]*{\([^}]*\)}.*/\1/p' $(FIGPIPE)

figurelist.txt: FIGPIPE := > figurelist.txt
figurelist.txt: figurelist

##############################################################################
### Sanity check #############################################################

sanitycheck:
	# Check some basic things in the tex source
	##############################
	# 1. look for todo or toremove or tofix
	@for f in $(MAINTEX) $(CHAPTERTEXS); \
	do \
		echo "\nProcessing $$f...\n";\
		GREP_COLOR="41;50" grep -n -i --color '\(todo\|toremove\|tofix\)' $$f;\
		echo "";\
	done;

##############################################################################
### SPELLING AND GRAMMAR #####################################################

spelling:
	$(foreach f,$(CHAPTERTEXS),$(ASPELL) check $(f);)

grammar:
	# DICTION: misused words {{{}{
	@$(foreach f,$(CHAPTERTEXS), $(DETEX) -lc $(f) | $(GNUDICTION) -sb | sed "s#(stdin)#$(f)#";)
	# }{}}}
	# STYLE: nominalizations {{{}{
	@$(foreach f,$(CHAPTERTEXS), $(DETEX) -lc $(f) | $(GNUSTYLE) -N | sed "s#(stdin):\([0-9][0-9]*\):#$(f):\1:Warning, nominalization:#";)
	# }{}}}
	# STYLE: passive {{{}{
	@$(foreach f,$(CHAPTERTEXS), $(DETEX) -lc $(f) | $(GNUSTYLE) -p | sed "s#(stdin):\([0-9][0-9]*\):#$(f):\1:Warning, passive::#";)
	# }{}}}
	# DIFFICULT SENTENCES: high ari-index {{{}{
	@$(foreach f,$(CHAPTERTEXS), $(DETEX) -lc $(f) | $(GNUSTYLE) -r 20 | sed "s#(stdin):\([0-9][0-9]*\):#$(f):\1:Warning, long sentence:#";)
	# }{}}}

##############################################################################
### CLEAN etc ################################################################

.PHONY: clean
clean:
	make cleanpar TARGET=$(basename $(MAINTEX))

.PHONY: realclean
realclean: clean
	make realcleanpar TARGET=$(basename $(MAINTEX))
	# Remove autogenerated $(DEFS)
	$(RM) $(DEFS)
	# Remove all compiled chapters
	@echo "Removing temporary files for all chapters..."
	for i in $(CHAPTERSDIR)/*;\
	do \
		i=$(basename "$$i");\
		if [ -f my"$$i".pdf ]; then $(RM) my"$$i".pdf; fi;\
		if [ -f my"$$i".dvi ]; then $(RM) my"$$i".dvi; fi;\
		if [ -f my"$$i".ps ]; then $(RM) my"$$i".ps; fi;\
	done
	# Remove .aux files in chapters
	$(RM) $(CHAPTERSDIR)/*/*.aux

##############################################################################

s:
	echo $(EDITOR) $(MAINTEX) $(MAINBIBTEXFILE) > $@
	chmod +x $@

##############################################################################
# vim: tw=78
