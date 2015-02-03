# TODO.md - Athena TODO List

- Write cellide manpage.
- Problems
  - Open elitia scenario, File/New get bgerror in strategybrowser.
  - flunky <Sync> is no longer being received, because the subject is wrong.
  - Orders are not being logged.
  - Right-Click/Control-Click isn't working on OSX.
- Move editable entities to athena(n)
- Move model modules to athena(n)
- Move relevant projtypes to athena(n)
- When app_athena no longer needs to be loaded to test athena(n):
  - app_athena tests to test/athena.
  - Include ted.tcl.
  - Will any app_athena tests remain?

# Global Resources in use in athena(n)

- app/messagebox
  - absit, actor, civgroup, frcgroup, nbhood, orggroup
- bsys
  - actor, civgroup
- driver::absit
  - absit
- nbhood
  - absit
- notifier send
  - nbhood
- parmdb
  - absit
- ptype - Should go in athena_order.tcl? (But no hierarchical methods!)
  - absit, actor, nbhood
- refpoint
  - absit, nbhood
- sim
  - absit
- simclock
  - absit, athenadb
- strategy
  - actor


