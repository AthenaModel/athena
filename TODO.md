# TODO.md - Athena TODO List

- Why is there no 010-abevent.test?
- Remove global singleton names:
  - Revise remaining app code to not use them.
  - Remove all such aliases, and see what breaks.
- Move "application" executive commands from executive.tcl to app.
- Remove all "app" calls from athena(n).
- See about giving athena(n) a read-only db.
- Check whether "adb reset" can replace all of the resets in "ted cleanup"
  - And if not, why not?
- Figure out what to do about icon names in athena(n) HTML.
- Generation of URLs:
  - htools is configured with a dictionary of symbolic names and base URLs.
  - The `$ht link` command will translate "%name/" at the beginning of a
    URL to "$baseurl/".
  - If the "name" is unknown, no link is created; just the link text is
    put in the buffer.
  - athena(n) gets the same dictionary, and delegates it to athenadb(n).
  - athenadb(n) provides a factory method for creating configured htools
    buffers.
  - Code creating htools buffers get them from athenadb(n).
- athena(n) needs to know whether it is running in an event loop or not.
  Or, more specifically, whether non-blocking runs are allowed.
  - Make this an option.
  - Update SIM:RUN accordingly
  - Add "adb run" and "adb pause" commands.
- Document all component entries in athenadb(n).
  - Or, come up with a plan for which ones are documented and which aren't.
- Document athena(n)
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
  - absit, actor, autogen, bsys, cap, civgroup, curse, frcgroup, nbhood, 
    orggroup, sim
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
  - autogen, exporter
- notifier bind
  - nbhood
- ptype - Should go in athena_order.tcl? (But no hierarchical methods!)
  - absit, actor, gofer_actors.tcl, gofer_number.tcl, nbhood, tactic_*.tcl
- rebase
  - sim
- service
  - strategy, tactic_service
- service_eni
  - strategy, tactic_fundeni
- sigevent
  - condition_expr, personnel, tactic_*.tcl
- simclock
  - absit, athenadb, block, exporter, sim


