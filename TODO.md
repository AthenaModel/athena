# TODO.md - Athena TODO List

- Problems in test/athena:
  - MAP:* orders use `app puts`; wrote issue #130 for Dave. 
- Document athena(n)
- Document athenadb(n)
- Document executive(n)
- New tests:
  - 010-abevent.test
  - 010-athenadb.test
  - 010-athena.test
- See about giving athena(n) a read-only db.
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
- arachne tool can have subcommands:
  - Make a scenario file given a script.
  - Modify a scenario file given a script.
- Write cellide manpage.



