# CHECKLIST

Checklist to follow when moving the singletons for editable entities
from app_athena(n) to athena(n).  See lib/athena/actor.tcl for an example.

- [x] Copy mymodule.tcl from lib/app_athena/shared to lib/athena
- [x] Update header comment to reference athena(n); review and edit
      description as needed.
- [x] Scan the module, and list global references (e.g., ::rdb, ::actor) 
      in a "TBD" header comment for later cleanup.
- [x] Define the module as "snit type ::athena::mymodule".
- [x] Remove the singleton pragma
- [x] Add an instance variable, "adb"
- [x] Add a constructor taking "adb_" as the argument, and saving it to
      "adb": `set adb $adb_`
- [x] Replace "typevariable" with "variable"
- [x] Replace "typemethod" with "method"
- [x] Replace references to "rdb" with "$adb".
- [x] Replace references to "mymodule" or "$type" with:
  - [x] "$self" in snit::type method bodies
  - [x] "$adb mymodule" in order method bodies.
  - [x] "$adb_ mymodule" in dynaform field callbacks.
- [x] Replace "meta defaults" with "meta parmlist" in orders.
- [x] In athenadb.tcl, parallel to the entries for "actor":
  - [x] Add "component mymodule -public mymodule"
  - [x] Add "install mymodule" line to constructor
  - [x] Add "interp alias ::mymodule" line to constructor
- [x] Try to invoke athena.tcl.  You might get dynaform errors.
  - [x] Move field types from shared/field_types.tcl to athena/dynatypes.tcl
        as needed.
  - [x] If moved types reference global resources, list them in the 
        dynatypes.tcl header comment.
  - [x] If any of the types in dynatypes reference mymodule, update the
        reference to `$adb_ mymodule`.
- [x] Add `variable adb` at the top of each order definition's body.
- [x] Try "athena.tcl -script scenarios/Nangahar_geo.adb".  Fix problems.
- [x] Try editing the entity type interactively; verify that you can
      create and update.
- [ ] Verify that the full app_athena test suite runs.