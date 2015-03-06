# TODO.md - Athena TODO List

- Problems in test/athena:
  - MAP:* orders use `app puts`; wrote issue #130 for Dave. 
- Remove all "app" calls from athena(n).
- Move "application" executive commands from executive.tcl to app.
- Add tests for the athena(n) object (in so far as that's useful)
  as 050-athena.test.
- Document athena(n)
- Document athenadb(n)
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
- Consider moving all rule set metadata from projtypes into athena(n).
  - Could use "define" command to build up metadata for introspection.
- arachne tool can have subcommands:
  - Make a scenario file given a script.
  - Modify a scenario file given a script.
- Write cellide manpage.



