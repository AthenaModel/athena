# CHECKLIST

Checklist to follow when moving the singletons for editable entities
from app_athena(n) to athena(n).  See lib/athena/actor.tcl for an example.

- [x] Copy mymodule.tcl from lib/app_athena/shared to lib/athena, updating
      the pkgModule files.
- [x] Update header comment to reference athena(n); review and edit
      description as needed.
- [x] Scan the module, and list global references (e.g., ::$adb, ::actor) 
      in a "TBD" header comment for later cleanup, and in TODO.md.
- [x] Define the module as "snit type ::athena::mymodule".
- [x] Remove the singleton pragma
- [x] Add a component, "adb"
- [x] Add a constructor taking "adb_" as the argument, and saving it to
      "adb": `set adb $adb_`
- [x] Replace "typecomponent" with "component"
  - [x] Update creation of any typecomponent
- [x] Replace "typevariable" with "variable"
- [x] Replace "typemethod" with "method"
- [x] Replace references to "rdb" with "$adb".
- [x] Replace references to "mymodule" or "$type" with:
  - [] "$self" in snit::type method bodies
  - [] "$adb mymodule" in order method bodies.
  - [] "$adb_ mymodule" in dynaform field callbacks.
- [] Update any global references for modules that already exist in athena(n).
- [] Update any global references in modules that already exist in athena(n).
- [] Remove "mutate" keyword.
  - [] From module
  - [] From *.test
  - [] From ted.tcl/create
  - [] From project
- [] Replace "meta defaults" with "meta parmlist" in orders.
- [] In athenadb.tcl, parallel to the entries for "actor":
  - [] Add "component mymodule -public mymodule"
  - [] Add "mymodule" to the MakeComponents call in the constructor
- [] Try to invoke athena.tcl.  You might get dynaform errors.
  - [] Move field types from shared/field_types.tcl to athena/dynatypes.tcl
        as needed.
  - [] If moved types reference global resources, list them in the 
        dynatypes.tcl header comment.
  - [] If any of the types in dynatypes reference mymodule, update the
        reference to `$adb_ mymodule`.
- [] Try "athena.tcl -script scenarios/Nangahar_geo.adb".  Fix problems.
- [] Try editing the entity type interactively; verify that you can
      create and update.
- [] Verify that the full app_athena test suite runs.
- [] Update any notifier sends to athena(n) standard, and update the 
     UI accordingly.