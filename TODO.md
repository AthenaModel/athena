# TODO.md - Athena TODO List

- Write cellide manpage.
- Problems
  - bsys uses mam(n), which is a singleton.  Arggh!
- Move editable entities to athena(n)
- Move model modules to athena(n)
- Move relevant projtypes to athena(n)
- Document all athena(n) notifier events in athena(n).
- When app_athena no longer needs to be loaded to test athena(n):
  - app_athena tests to test/athena.
  - Include ted.tcl.
  - Will any app_athena tests remain?

# Global Resources in use in athena(n)

- app/messagebox
  - absit, actor, cap, civgroup, frcgroup, nbhood, orggroup
- bsys
  - actor, civgroup
- driver::absit
  - absit
- group
  - activity
- nbhood
  - absit
- notifier bind
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
  - actor, agent
- tactic
  - agent


