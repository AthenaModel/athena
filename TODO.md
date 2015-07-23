# TODO.md - Athena TODO List

- Causality Chaining
  - The vardiff "inputs" field should probably be an array in JSON
    - We can send it sorted, and it will stick.
  - Need to display detail for chain roots.
    - Possibly, just make them the top of the outline.
  - Need to indicate which variables have inputs and which don't.
  - Need better narratives for drivers; the driver isn't identified clearly.
  - Need to move comparison(n)'s "A" values to compdb(n)?
  - Might want to add "trivial" checks to some of the vardiff types, based
    on limits in compdb(n); but the limits that are there now are OBE.
  - Compute and return chains
  - Chain vardiffs don't get added to comparison.
  - Continue to flesh out input tree.
- Angular Web App
  - Comparisons
  - Clean up Arachne URLs, e.g., "/scenario/{case}/nbhoods/index.json"
    by "/scenario/{case}/nbhood/{n}/index.json".  Both should be "nbhoods"
    or "nbhood".
  - Should the scenario_*.json modules be merged, now that HTML is being
    removed?
  - The case data management should be abstracted from CaseController
    into a case.js service following the same pattern as comp.js.
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



