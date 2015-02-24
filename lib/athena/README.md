README.md
=========

This directory contains the source code for the athena(n) library.  Most
code is in the top-level directory; the subdirectories are defined as
follows:

* `conditions/`: All concrete condition types.
* `gofers/`: All concrete gofer types.
* `rulesets/`: All DAM rule sets.
* `sql/`: All SQL schema files.
* `tactics`: All concrete tactic types.
* `tk`: Tk-specific code, loaded only if Tk is already loaded.

Note that abstract base classes (e.g., `tactic.tcl`) reside in the
top-level directory.