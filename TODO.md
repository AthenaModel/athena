# TODO.md - Athena TODO List

- Athenawb(1):
  - Tk images are not displaying properly in appserver pages.
    - E.g., pencil icon in parmdb page.
- Projectlib(n)
  - Tests for parmdict(n), smartdomain(n)
- Athena(n)
  - Optimize athena(n) creation, reset, load.  It's way slow.
  - Group athenadb(n) predicates under "is", e.g., "is busy".
  - Finish athena(n) man page!!!!!!!
- Arachne
  - Consider smartdomain look ups using a dict tree: split the url into
    components and just follow them down the tree, accumulating place
    holders as you go.  See if that's faster.
  - Fix scenario name in Arachne's export .tcl file.  It depends on last 
    export, and it shouldn't.
  - Missing Operations:
    - Lock/Unlock/Time Advance
    - HTML I/F to control toplevel operations
    - Many, many .json queries
  - What should the htdocs directory look like?
  - Write arachne(1) man page, referencing I/F doc.
  - Write athena_log(1) man page.
- Significant Outputs:
  - All history variable base names should be unique, e.g., nbsecurity.n rather
    than security.n.
  - If possible, the column names in the hist_* table should match the 
    variable base name.  (But don't break old post-processors.)
  - `::athena::athena compare` is the command to compare two scenarios. 
    - Returns an ::athena::comparison object.
    - Knowledge of how to do output and input comparisons resides in 
      athena/compare.tcl.
  - Comparison objects:
    - Provide comparison data in a variety of forms.
    - Can ask individual vardiff objects for causal chain info.
    - Each vardiff object knows how to determine its potentially significant
      inputs, and how to score them, and is responsible for drilling down.
      - Scores must be saved at the vardiff level. 
  - Comparisons should be provided to front end in JSON form
    - Raw data, not cooked narrative (unless they ask for it).
  - vardiff records provide simple Tcl dictionaries.
- Causal Chains


- Document athena(n)
- Make mods work with all athena(n) applications.
- New tests:
  - 010-abevent.test
  - 010-athenadb.test
  - 010-athena.test
- athena(n) HTML generation
  - What to do about icon names?
    - Replace with .png files, with valid URLs?
      - That's probably easiest.
- Write cellide manpage.



