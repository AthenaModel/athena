# TODO.md - Athena TODO List

- Causality Chaining
  - Add existing vardiffs as inputs where appropriate
  - Add inputs and work down
- Angular Web App
  - Comparisons
    - See #/comparisons/index.html for UI issues
    - All comparison requests should be moved to comp.js
      - And there should be a "new()" method, which can save the 
        comparison's metadata and outputs immediately, so that they
        don't need to be retrieved separately.
  - The case data management should be abstracted from CaseController
    into a case.js service following the same pattern as comp.js.
  - Case page: Add a tab for sending orders to a case.
  - Script page: Add a tab for sending scripts to a case.
  - Handling help would require a .json interface to the help.
  - Debugging page
    - Define debugging service.
    - Sidebar content should be defined as directives using the 
      service; then the sidebar doesn't need to see the page controller,
      and we can go back to using ar-mainpage.
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



