#---------------------------------------------------------------------
# TITLE:
#    Makefile -- Athena Help Makefile
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    	all          Builds workbench.helpdb, arachne.helpdb.
#       clean        Deletes target helpdb files. 
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Settings

# Set the root of the directory tree.
TOP_DIR = ../..

.PHONY: all workbench arachne clean

HELPTOOL           = $(TOP_DIR)/bin/helptool.tcl
WORKBENCH_HELPDB   = $(TOP_DIR)/docs/workbench.helpdb
ARACHNE_HELPDB     = $(TOP_DIR)/docs/arachne.helpdb

all: workbench arachne

workbench:
	$(HELPTOOL) workbench.help $(WORKBENCH_HELPDB)

arachne:
	$(HELPTOOL) arachne.help $(ARACHNE_HELPDB)

clean:
	-rm $(HELPDB)
