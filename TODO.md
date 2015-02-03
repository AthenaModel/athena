# TODO.md - Athena TODO List

- Write cellide manpage.
- Move editable entities to athena(n)
- Move model modules to athena(n)
- Move relevant projtypes to athena(n)
- When app_athena no longer needs to be loaded to test athena(n):
  - app_athena tests to test/athena.
  - Include ted.tcl.
  - Will any app_athena tests remain?

# Global Resources in use in athena(n)

- app/messagebox
  - absit, actor, civgroup, frcgroup, orggroup
- bsys
  - actor, civgroup
- driver::absit
  - absit
- nbhood
  - absit, dynatypes
- parmdb
  - absit
- ptype
  - absit, actor
- refpoint
  - absit
- sim
  - absit
- simclock
  - absit, athenadb
- strategy
  - actor


