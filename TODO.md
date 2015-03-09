# TODO.md - Athena TODO List

- Document athena(n)
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



