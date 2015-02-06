# TODO.md - Athena TODO List

- Modify strategybrowser to use paster for pasting blocks
- Move editable entities to athena(n)
- Move model modules to athena(n)
- Move relevant projtypes to athena(n)
- Document all athena(n) notifier events in athena(n).
- When app_athena no longer needs to be loaded to test athena(n):
  - app_athena tests to test/athena.
  - Include ted.tcl.
  - Will any app_athena tests remain?
- Write cellide manpage.

# Global Resources in use in athena(n)

- app/messagebox
  - absit, actor, bsys, cap, civgroup, curse, frcgroup, nbhood, orggroup
- athena register
  - bsys
- driver::absit
  - absit
- ::gofer::ACTORS
  - curse
- ::gofer::CIVGROUPS
  - curse
- ::gofer::FRCGROUPS
  - curse
- ::gofer::GROUPS
  - curse
- inject
  - curse
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
  - actor, agent, cash
- tactic
  - agent


