# TODO.md - Athena TODO List

- Make simclock an athenadb component.
- Scan for TBD and TODOs in library.
- Move "application" executive commands from executive.tcl to app.
- parm component should be told about state changes directly.
- Remove all "app" calls from athena(n).
- See about giving athena(n) a read-only db.
- Why is there no 010-abevent.test?
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



