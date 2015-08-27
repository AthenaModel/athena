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

.PHONY: all clean

HELPTOOL           = $(TOP_DIR)/bin/helptool.tcl
WORKBENCH_HELPDB   = $(TOP_DIR)/docs/workbench.helpdb
ARACHNE_HELPDB     = $(TOP_DIR)/docs/arachne.helpdb

all:
	$(HELPTOOL) workbench.help $(WORKBENCH_HELPDB)
	$(HELPTOOL) arachne.help $(ARACHNE_HELPDB)

clean:
	-rm $(HELPDB)
