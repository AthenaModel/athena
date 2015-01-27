# TODO.md - Athena TODO List

- Write cellide manpage.
- Look for:
  - DONE order send
  - DONE order enter
  - DONE order state
  - DONE order define
  - DONE cif transaction
  - DONE cif undo
  - DONE cif redo
  - DONE orderdialog
  - DONE order title
  - DONE order parms
- Replace old cond::*
- After all orders are converted:
-   Make sure that orders are CIF'd.
    -   Move code from cif.tcl, get rid of cif.tcl
-   Add "monitor" flag to athena_flunky; if off, no RDB monitoring.
-   Update "call" executive command to disable monitoring temporarily
    and send <DbSync> after.
-   Document executive commands
    -   send (new style)
    -   enter

