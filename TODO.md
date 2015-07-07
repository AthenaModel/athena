# TODO.md - Athena TODO List

- Causality Chaining
  - Add existing vardiffs as inputs where appropriate
  - Add inputs and work down
- Angular Web App
  - Merge ScenOpsController into ScenarioListController.
  - In Arachne service, consider returning a promise from requests, 
    refreshes instead of using a callback.  See "Tyler McGinnis: Factory
    vs. Service vs. Provider" for example.
  - Move entity object caching from CaseController to a service, either
    Arachne or a new service.
  - Case page: Add a tab for sending orders to a case.
  - Script page: Add a tab for sending scripts to a case.
  - Handling help would require a .json interface to the help.
- Arachne
  - Fix scenario name in Arachne's export .tcl file.  It depends on last 
    export, and it shouldn't.
  - Write arachne(1) man page, referencing I/F doc.
  - Write athena(1) man page
  - Write athena_log(1) man page.
- Projectlib(n)
  - Tests for parmdict(n), smartdomain(n)
- Athena(n)
  - Optimize athena(n) creation, reset, load.  It's way slow.



