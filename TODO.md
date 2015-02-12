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

- aam
  - tactic_attrit
- app/messagebox
  - absit, actor, bsys, cap, civgroup, curse, frcgroup, nbhood, orggroup
- athena register
  - bsys, econ
- curse
  - dynatypes, tactic_curse
- driver::absit
  - absit
- driver::abevent
  - strategy, tactic_accident, tactic_demo, tactic_explosion, tactic_riot, 
    tactic_violence
- driver::CURSE
  - tactic_curse
- driver::IOM
  - tactic_broadcast
- executive
  - condition_expr, tactic_executive
- ::gofer*
  - curse
  - condition_compare, condition_control, tactic_*
- iom
  - tactic_broadcast
- inject
  - curse, tactic_curse
- nbhood
  - absit
- notifier bind
  - nbhood
- parm, parmdb
  - absit, personnel, tactic_fundeni, tactic_maintain
- plant
  - strategy, tactic_build, tactic_damage, tactic_maintain
- ptype - Should go in athena_order.tcl? (But no hierarchical methods!)
  - absit, actor, nbhood, tactic_*.tcl
- refpoint
  - absit, nbhood
- service
  - strategy, tactic_service
- service_eni
  - strategy, tactic_fundeni
- sigevent
  - condition_expr, personnel, tactic_*.tcl
- sim
  - absit
- simclock
  - absit, athenadb, block


