# TODO.md - Athena TODO List

- Causality Chaining
  - Implement new-style input scoring.
  - Compute and return chains
  - Chain vardiffs don't get added to comparison.
  - Continue to flesh out input tree.
- Angular Web App
  - Page Names:
    - DONE! #/cases, cases-controller
    - #/case/:caseid, case-controller
    - #/comparisons, comparisons-controller
    - #/comparison/:case1[:/case2], comparison-controller
  - Comparisons
    - Comparison records should always include the list of significant
      outputs.
    - New concept: no public comparison IDs
      - Comparisons are cacheable but not persistent.
      - Comparisons are requested given one or two case IDs.
      - Comparisons are cached by the server, and deleted automatically
        when an underlying case changes, as now.
        - No public remove operation
      - A comparison can be requested via /comparison/new.json; the result
        is the comparison record is returned, which is computed if necessary.
      - The cached comparisons are returned in their entirety by 
        /comparison/index.json.
    - Web app URLs: 
      - #/comparison/:case1
        - Requests a comparison of case1 with itself, and displays whatever
          is available.
      - #/comparison/:case1/:case2
        - Requests a comparison of case A with case B, and displays whatever
          is available.
    - Responsibilities of the Comparison service:
      - Refreshes cached comparison data on demand.
      - Provides Comparison.request(case1, [case2]).then().
      - comparisons-controller provides list of comparisons, plus a "Go"
        form for going to a specific /comparison/:case1/:case2.
        - Gets list of data from Comparison service.
      - comparison-controller asks comparison.js for the comparison, and displays
        whatever is available.
      - On demand, comparison-controller asks comparison.js for chain, and
        displays whatever is available.
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



