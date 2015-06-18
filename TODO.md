# TODO.md - Athena TODO List

- Angular Web App
  - Got code search working, but errors in .json handlers seem to return
    "success" with something other than real data.  Track this down!
  - Figure out how to add Case pages.
  - Move ScenarioListController stuff to a service.
  - Handling help would require a .json interface to the help.
- Arachne
  - Fix scenario name in Arachne's export .tcl file.  It depends on last 
    export, and it shouldn't.
  - Write arachne(1) man page, referencing I/F doc.
  - Write athena(1) man page
  - Write athena_log(1) man page.
- Projectlib(n)
  - Tests for parmdict(n), smartdomain(n)
- Athena(n)
  - Optimize athena(n) creation, reset, load.  It's way slow.



