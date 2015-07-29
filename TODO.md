# TODO.md - Athena TODO List

- Causality Chaining
  - Vardiffs need better context strings, or perhaps links to help.
  - Need to add "trivial" checks to some of the vardiff types, based
    on limits in compdb(n); but the limits that are there now are OBE.
    - Could do this just by pruning based on type-specific "score" or "delta".
  - Need to move comparison(n)'s "A" values to compdb(n)?
  - Continue to flesh out chains.
  - Vardiffs need tests.
- Angular Web App
  - See if we can pass "page" to ar-mainpage, which includes both
    templates.
  - Various pages need to do something better when the route params are
    empty.
  - Clean up Arachne URLs, e.g., "/scenario/{case}/nbhoods/index.json"
    by "/scenario/{case}/nbhood/{n}/index.json".  Both should be "nbhoods"
    or "nbhood".
  - Should the scenario_*.json modules be merged, now that HTML is being
    removed?
  - The case data management should be abstracted from CaseController
    into a case.js service following the same pattern as comparison.js
    -   Which itself needs some help.
  - Case page: 
    - Sanity Check!
    - Add a tab for sending orders to a case.
    - Add a tab for sending scripts to a case.
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



