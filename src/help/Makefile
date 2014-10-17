#---------------------------------------------------------------------
# TITLE:
#    Makefile -- Athena Help Makefile
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    	all          Builds athena.helpdb.
#       clean        Deletes athena.helpdb. 
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Settings

# Set the root of the directory tree.
TOP_DIR = ../..

.PHONY: all clean

HELPTOOL = $(TOP_DIR)/bin/helptool.tcl
HELPDB   = $(TOP_DIR)/docs/athena.helpdb

all:
	$(HELPTOOL) athena.help $(HELPDB)

clean:
	-rm $(HELPDB)
