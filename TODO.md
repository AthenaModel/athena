# TODO.md - Athena TODO List

- Arachne
  - Display of JSON results in HTML page
    - I have a sample of AJAX-style request, in branch json-result-display
      - However, reloading the result page sends the request a second time.
    - What's wanted: A button that:
      - Retrieves a form's parameters
      - Assembles the relevant JSON request
      - Requests it
      - Puts the result in a JSON Result box.
    - This solves the above problem; however:
      - Other data on the page won't get updated properly.  Ooooh, it gets
        complicated!
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



