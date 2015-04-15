# TODO.md - Athena TODO List

- athena-slave:
  - Finish athena(n), athenadb(n) man pages!!!!!!!
    - athenadb(n)
      - Make sure all top-level commands are documented.
      - Add a list of the components that aren't documented.
  - athenadb(n)
    - Test the new state/busy methods
      - In test/athena
    - Add "savetemp", "loadtemp" to save and load transient files.
      - Not exposed by athena(n).
      - Don't affect the changed flag.
      - Don't set adbfile name.
    - Make "master" be "background" and "slave" be "bgslave".
    - Handle slave logging.
      - Multiple log directories, $subject and $subject.bg.
    - Figure out how to use master/slave for doing runs in practice.
      - Perhaps a limit: more than x ticks, use background, fewer than x
        use fg, where the limit can be set and can automatically decrease
        if fg processing takes too long?
      - Or, add a checkbox, and automatically do background for anything over
        five ticks?
      - For arachne, we'll always want to do background runs.
    - Cleanup references to state names wherever possible, using the
      predicates instead.
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
  - Generation of URLs:
    - htools is configured with a dictionary of symbolic names and base URLs.
    - The `$ht link` command will translate "%name/" at the beginning of a
      URL to "$baseurl/".
    - If the "name" is unknown, no link is created; just the link text is
      put in the buffer.
    - athena(n) gets the same dictionary, and delegates it to athenadb(n).
    - athenadb(n) provides a factory method for creating configured htools
      buffers.
    - Code using htools buffers get them from athenadb(n).
- See about giving athena(n) a read-only db.
- Write cellide manpage.



