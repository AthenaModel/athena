# TODO.md - Athena TODO List

- Finish gofer work:
  - Convert remaining gofers and test
  - Test gofer.tcl, gofer_type.tcl, gofer_rule.tcl
  - Get the goferx field type working.
  - Update man pages (insofar as that's necessary)
  - Update and test gofer executive command, per writeup in help.
  - Update remaining code to use "adb gofer TYPE" instead of "::gofer::TYPE".
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
- curse
  - dynatypes, tactic_curse
- driver::absit
  - absit
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
  - absit, personnel, ruleset, tactic_fundeni, tactic_maintain
- plant
  - strategy, tactic_build, tactic_damage, tactic_maintain
- ptype - Should go in athena_order.tcl? (But no hierarchical methods!)
  - absit, actor, gofer_actors.tcl, nbhood, tactic_*.tcl
- refpoint
  - absit, nbhood
- service
  - strategy, tactic_service
- service_eni
  - strategy, tactic_fundeni
- sigevent
  - condition_expr, personnel, tactic_*.tcl
- sim
  - absit, ruleset_iom.tcl
- simclock
  - absit, athenadb, block


