# TODO.md - Athena TODO List

- Move "executive script *" to script.tcl.
- Document all component entries in athenadb(n).
  - Or, come up with a plan for which ones are documented and which aren't.
- Document athena(n)
- Move editable entities to athena(n)
- Move model modules to athena(n)
- Move relevant projtypes to athena(n)
- Move parmdb/parm to athena(n)
  - Make it use `::athena::ruleset names` intead of edamruleset, and
    remove edamruleset.
- Document all athena(n) notifier events in athena(n).
- When app_athena no longer needs to be loaded to test athena(n):
  - app_athena tests to test/athena.
  - Include ted.tcl.
  - Will any app_athena tests remain?
  - Add '$adb ruleset' test, vs. 010-dam, 010-driver.
- Consider moving all rule set metadata from projtypes into athena(n).
  - Could use "define" command to build up metadata for introspection.
- Write cellide manpage.

# Global Resources in use in athena(n)

- aam
  - tactic_attrit
- app/messagebox
  - absit, actor, bsys, cap, civgroup, curse, frcgroup, nbhood, orggroup
- aram
  - ruleset
- athena register
  - bsys, econ
- autogen
  - executive
- curse
  - dynatypes, tactic_curse
- iom
  - tactic_broadcast
- inject
  - curse, tactic_curse
- map
  - exporter
- notifier bind
  - nbhood
- plant
  - gofer_number, strategy, tactic_build, tactic_damage, tactic_maintain
- ptype - Should go in athena_order.tcl? (But no hierarchical methods!)
  - absit, actor, gofer_actors.tcl, gofer_number.tcl, nbhood, tactic_*.tcl
- refpoint
  - absit, nbhood
- service
  - strategy, tactic_service
- service_eni
  - strategy, tactic_fundeni
- sigevent
  - condition_expr, personnel, tactic_*.tcl
- sim
  - absit, parm, ruleset_iom.tcl
- simclock
  - absit, athenadb, block, exporter


