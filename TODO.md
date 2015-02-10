# TODO.md - Athena TODO List

- Add all component entries to athenadb(n).
  - Or, come up with a plan for which ones are documented and which aren't.
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
- condition
  - block
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
  - absit, athenadb, block
- strategy
  - actor, agent, block, cash
- tactic
  - agent, block


