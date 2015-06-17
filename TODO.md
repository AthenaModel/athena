# TODO.md - Athena TODO List

- Angular Web App
  - Use bootstrap CSS?
  - How to structure the other features?
    - Double toolbar works for scenarios, because the list of scenarios
      is front and center.
    - What if a major area has several things to display?  How do we 
      display that?
  - I'm thinking that the scenario links should take you to a distinct 
    app on a different page.
  - Handling help would require a .json interface to the help.
- Arachne
  - Consider smartdomain look ups using a dict tree: split the url into
    components and just follow them down the tree, accumulating place
    holders as you go.  See if that's faster.
  - Fix scenario name in Arachne's export .tcl file.  It depends on last 
    export, and it shouldn't.
  - What should the htdocs directory look like?
  - Write arachne(1) man page, referencing I/F doc.
  - Write athena_log(1) man page.
- Projectlib(n)
  - Tests for parmdict(n), smartdomain(n)
- Athena(n)
  - Optimize athena(n) creation, reset, load.  It's way slow.
  - Group athenadb(n) predicates under "is", e.g., "is busy".
  - Finish athena(n) man page!!!!!!!


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



