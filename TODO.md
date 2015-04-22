# TODO.md - Athena TODO List

- Arachne
  - Problem with athenawb mods
  - Fix scenario name in Arache export .tcl file.  It depends on last 
    export, and it shouldn't.
  - Missing Operations:
    - Export a scenario (e.g., save as)
    - Clone a scenario
    - Compare two scenarios, return vardiffs
    - HTML I/F to control these things.
  - What should the htdocs directory look like?
  - How to include the arachne.html file in the htdocs directory?
    - Population script in ./bin?
  - Write arachne(1) man page, referencing I/F doc.
  - Write athena_log(1) man page.
- CLI history is not getting saved.
  - saveprefs is getting called.
  - Perhaps LoadPrefs isn't properly closing the file, so Windows is 
    helpfully writing to another file?
    - But LoadPrefs is using "readfile"
    - No "Virtual" directory with alternate file in it.
- Finish athena(n) man page!!!!!!!
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



