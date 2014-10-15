#---------------------------------------------------------------------
# TITLE:
#    Makefile -- Athena Makefile
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    This Makefile defines the following targets:
#
#    	all          Builds Athena code and documentation.
#    	docs         Builds Athena documentation
#    	test         Runs Athena unit tests.
#    	clean        Deletes all build products
#       build        Builds code and documentation from scratch,
#                    and runs tests.
#       tag          Tags the current branch or trunk. 
#       cmbuild      Official build; requires ATHENA_VERSION=x.y.z
#                    on make command line.  Builds code and 
#                    documentation from scratch.
#    	install      Installs documentation and tarballs to the Athena AFS Page
#    	installdist  Installs tarballs to the Athena AFS Page
#    	installdocs  Installs documentation to the Athena AFS Page
#
#    For normal development, this Makefile is usually executed as
#    follows:
#
#        make
#
#    Optionally, this is followed by
#
#        make test
#
#    For official builds (whether development or release), this
#    sequence is used:
#
#        make build                          
#
#    Resolve any problems until "make build" runs cleanly. Then,
#
#        make ATHENA_VERSION=x.y.z cmbuild
#
#    NOTE: Before doing the official build, docs/build.html should be
#    updated with the build notes for the current version.
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Settings

# Set the root of the directory tree.
TOP_DIR = .

.PHONY: all docs test src build cmbuild tag tar srctar clean

#---------------------------------------------------------------------
# Shared Definitions

include MakeDefs


#---------------------------------------------------------------------
# Target: all
#
# Build code and documentation.

all: src bin docs

#---------------------------------------------------------------------
# Target: src
#
# Build compiled modules.

src: check_env
	@ echo ""
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo "+          Building Binaries From Source            +"
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo ""
	cd $(TOP_DIR)/mars ; make src

#---------------------------------------------------------------------
# Target: bin
#
# Build Athena executable; C/C++ source must be built first.  Note that
# the executable is always built; it really has too many dependencies
# to try to build it only when some dependency has changed, and on top
# of that it's not usually needed or built during day-to-day 
# development.

ifeq "$(MARS_PLATFORM)" "linux32"
    BASE_KIT   = $(TOP_DIR)/tools/basekits/base-tk-thread-linux-ix86
    ATHENA_EXE = $(TOP_DIR)/bin/athena
else ifeq "$(MARS_PLATFORM)" "linux64"
    BASE_KIT   = $(TOP_DIR)/tools/basekits/base-tk-thread-linux-x86_64
    ATHENA_EXE = $(TOP_DIR)/bin/athena
else ifeq "$(MARS_PLATFORM)" "win32"
    BASE_KIT   = $(TOP_DIR)/tools/basekits/base-tk-thread-win32-ix86.exe
    ATHENA_EXE = $(TOP_DIR)/bin/athena.exe
else
    BASE_KIT   =
    ATHENA_EXE =
endif

ARCHIVE = $(ATHENA_TCL_HOME)/lib/teapot

# tclapp has a nasty habit of not halting the build on error, and
# the error messages get lost for some reason.  So explicitly delete
# the binary before calling tclapp, so that on error we don't have
# a binary.

bin: check_env src
	@ echo ""
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo "+              Building Athena Executable           +"
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo ""
	-rm $(ATHENA_EXE)
	tclapp $(TOP_DIR)/bin/athena.tcl                    \
		$(TOP_DIR)/lib/*/*                          \
		$(TOP_DIR)/lib/*/*/*                        \
		$(TOP_DIR)/mars/lib/*/*                     \
		-log $(TOP_DIR)/tclapp.log                  \
		-icon $(TOP_DIR)/installer/athena.ico       \
		-out $(ATHENA_EXE)                          \
		-prefix $(BASE_KIT)                         \
		-archive $(ARCHIVE)                         \
		-follow                                     \
		-force                                      \
		-pkgref "comm"                              \
		-pkgref "Img       -require 1.4"            \
	    -pkgref "snit      -require 2.3"            \
	    -pkgref "BWidget   -require 1.9"            \
        -pkgref "Tktable"                           \
		-pkgref "treectrl"                          \
		-pkgref "sqlite3   -require 3.8.3"          \
		-pkgref "tablelist -require 5.11"           \
		-pkgref "textutil::expander"                \
		-pkgref "textutil::adjust"                  \
		-pkgref "Tkhtml    -require 3.0"            \
		-pkgref "uri"                               \
		-pkgref "fileutil"                          \
		-pkgref "ctext     -require 3.3"            \
		-pkgref "TclOO"                             \
		-pkgref "tls"                               \
		-pkgref "tdom"                              \
		-pkgref "struct::set"
	@ cat tclapp.log

#---------------------------------------------------------------------
# Target: docs
#
# Build development documentation.

docs: check_env
	@ echo ""
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo "+              Building Documentation               +"
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo ""

	cd $(TOP_DIR)/mars ; make docs
	cd $(TOP_DIR)/docs ; make

#---------------------------------------------------------------------
# Target: test
#
# Run all unit tests.

test: check_env
	@ echo ""
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo "+               Running Unit Tests                  +"
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo ""

	cd $(TOP_DIR)/mars ; make test
	cd $(TOP_DIR)/test ; make

#---------------------------------------------------------------------
# Target: install
#
# Copy tarballs and documentation to the Athena AFS page.


install: installdist installdocs

installdist: installdirs
	$(SCP) $(TOP_DIR)/../*.tgz $(ATHENA_SERVER):$(ATHENA_ARCHIVE)
	if test -e "$(ATHENA_INSTALLER)" ; then \
	    $(SCP) $(ATHENA_INSTALLER) $(ATHENA_SERVER):$(ATHENA_ARCHIVE); fi

installdocs: installdirs
	-$(SCP) docs/index.html            $(ATHENA_SERVER):$(ATHENA_DOCS)/docs
	-$(SCP) docs/developer.html        $(ATHENA_SERVER):$(ATHENA_DOCS)/docs
	-$(SCP) docs/build_notes.html      $(ATHENA_SERVER):$(ATHENA_DOCS)/docs
	-$(SCP) docs/dev/*.html            $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/dev
	-$(SCP) docs/dev/*.doc             $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/dev
	-$(SCP) docs/dev/*.docx            $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/dev
	-$(SCP) docs/dev/*.pptx            $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/dev
	-$(SCP) docs/dev/*.odt             $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/dev
	-$(SCP) docs/dev/*.ods             $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/dev
	-$(SCP) docs/dev/*.pdf             $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/dev
	-$(SCP) docs/dev/*.txt             $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/dev
	-$(SCP) docs/man1/*.html           $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/man1
	-$(SCP) docs/man5/*.html           $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/man5
	-$(SCP) docs/mani/*.html           $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/mani
	-$(SCP) docs/mann/*.html           $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/mann
	-$(SCP) docs/mansim/*.html         $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/mansim
	-$(SCP) docs/man1/*.gif            $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/man1
	-$(SCP) docs/man5/*.gif            $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/man5
	-$(SCP) docs/mani/*.gif            $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/mani
	-$(SCP) docs/mann/*.gif            $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/mann
	-$(SCP) docs/mansim/*.gif          $(ATHENA_SERVER):$(ATHENA_DOCS)/docs/mansim
	-$(SCP) mars/docs/index.html       $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs
	-$(SCP) mars/docs/build_notes.html $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs
	-$(SCP) mars/docs/dev/*.html       $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/dev
	-$(SCP) mars/docs/dev/*.doc        $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/dev
	-$(SCP) mars/docs/dev/*.docx       $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/dev
	-$(SCP) mars/docs/dev/*.pptx       $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/dev
	-$(SCP) mars/docs/dev/*.pdf        $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/dev
	-$(SCP) mars/docs/dev/*.txt        $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/dev
	-$(SCP) mars/docs/man1/*.html      $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/man1
	-$(SCP) mars/docs/man5/*.html      $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/man5
	-$(SCP) mars/docs/mani/*.html      $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/mani
	-$(SCP) mars/docs/mann/*.html      $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/mann
	-$(SCP) mars/docs/man1/*.gif       $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/man1
	-$(SCP) mars/docs/man5/*.gif       $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/man5
	-$(SCP) mars/docs/mani/*.gif       $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/mani
	-$(SCP) mars/docs/mann/*.gif       $(ATHENA_SERVER):$(ATHENA_DOCS)/mars/docs/mann

installdirs:
	$(SSH) mkdir -p $(ATHENA_ARCHIVE)
	$(SSH) mkdir -p $(ATHENA_DOCS)
	$(SSH) mkdir -p $(ATHENA_DOCS)/docs/man1
	$(SSH) mkdir -p $(ATHENA_DOCS)/docs/man5
	$(SSH) mkdir -p $(ATHENA_DOCS)/docs/mani
	$(SSH) mkdir -p $(ATHENA_DOCS)/docs/mann
	$(SSH) mkdir -p $(ATHENA_DOCS)/docs/dev
	$(SSH) mkdir -p $(ATHENA_DOCS)/mars
	$(SSH) mkdir -p $(ATHENA_DOCS)/mars/docs
	$(SSH) mkdir -p $(ATHENA_DOCS)/mars/docs/man1
	$(SSH) mkdir -p $(ATHENA_DOCS)/mars/docs/man5
	$(SSH) mkdir -p $(ATHENA_DOCS)/mars/docs/mani
	$(SSH) mkdir -p $(ATHENA_DOCS)/mars/docs/mann
	$(SSH) mkdir -p $(ATHENA_DOCS)/mars/docs/dev


#---------------------------------------------------------------------
# Target: build
#
# Build code and documentation from scratch, and run tests.

build: clean src bin docs test

#---------------------------------------------------------------------
# Target: cmbuild
#
# Official CM build.  Requires a valid (numeric) ATHENA_VERSION.

cmbuild: check_cmbuild clean srctar src bin docs tar
	@ echo ""
	@ echo "*****************************************************"
	@ echo "         CM Build: Athena $(ATHENA_VERSION) Complete"
	@ echo "*****************************************************"
	@ echo ""

check_cmbuild:
	@ echo ""
	@ echo "*****************************************************"
	@ echo "                CM Build: Athena $(ATHENA_VERSION)"
	@ echo "                CM Build: Mars $(MARS_VERSION)"
	@ echo "*****************************************************"
	@ echo ""

#---------------------------------------------------------------------
# Target: tar

tar:
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo "+               Making ../athena_$(ATHENA_VERSION).tar"
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo ""

	$(TOP_DIR)/tools/bin/make_tar install $(ATHENA_VERSION) $(MARS_PLATFORM)

	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo "+               Making ../athena_$(ATHENA_VERSION)_docs.tar"
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo ""

	$(TOP_DIR)/tools/bin/make_tar docs    $(ATHENA_VERSION) $(MARS_PLATFORM)

#---------------------------------------------------------------------
# Target: srctar

srctar:
	@ echo ""
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo "+               Making ../athena_$(ATHENA_VERSION)_src.tar"
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo ""

	$(TOP_DIR)/tools/bin/make_tar source $(ATHENA_VERSION) $(MARS_PLATFORM)


#---------------------------------------------------------------------
# Target: clean
#
# Delete all build products.

clean: check_env
	@ echo ""
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo "+                     Cleaning                      +"
	@ echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	@ echo ""
	-rm $(TOP_DIR)/bin/athena
	cd $(TOP_DIR)/mars ; make clean
	cd $(TOP_DIR)/test ; make clean
	cd $(TOP_DIR)/docs ; make clean

#---------------------------------------------------------------------
# Target: tag
#
# Tags the version in the current work area.

BUILD_TAG    = athena_$(ATHENA_VERSION)
TAG_DIR      = https://oak.jpl.nasa.gov/svn/athena/tags/$(BUILD_TAG)

tag: check_env check_ver
	@ echo ""
	@ echo "*****************************************************"
	@ echo "         Tagging: Athena $(ATHENA_VERSION)"
	@ echo "*****************************************************"
	@ echo ""
	svn copy -m"Tagging Athena $(ATHENA_VERSION)" . $(TAG_DIR)
	svn switch $(TAG_DIR) .
	@ echo ""
	@ echo "*****************************************************"
	@ echo "         Now in $(TAG_DIR)"
	@ echo "*****************************************************"
	@ echo ""

check_ver:
	@ if test ! -n "$(ATHENA_VERSION)" ; then \
	    echo "Makefile variable ATHENA_VERSION is not set." ; exit 1 ; fi
	@ if test "$(ATHENA_VERSION)" = "$(ATHENA_VERSION_DEFAULT)" ; then \
	    echo "Makefile variable ATHENA_VERSION is not set." ; exit 1 ; fi


#---------------------------------------------------------------------
# Shared Rules

include MakeRules









