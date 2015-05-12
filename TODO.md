# TODO.md - Athena TODO List

- Projectlib(n)
  - Tests for parmdict(n), smartdomain(n)
- Athena(n)
  - Sanity Checking
    - On pressing Check:
      - Strategy Browser
        - Does strategy sanity check
        - strategy.tcl sends <Check>
        - browser reloads, displaying results of check
          - Browser automatically displays results no matter how check was
            requested.
        - Detail browser page is NOT loaded
      - Curse Browser
        - Does curse sanity check
        - curse.tcl does NOT send <Check>
        - Browser does not automatically reload, displaying results
        - Detail browser page is loaded
      - IOM Browser
        - Does iom sanity check
        - iom.tcl does NOT send <Check>
        - Browser does not automatically reload, displaying results
        - Detail browser page is loaded
      - Hook Browser
        - Has no check button
        - hook.tcl provides no check
        - sanity/hook is a useless page.      
    - Conclusions
      - Most checkers should return the severity, as now.
      - The htools buffer is replaced with the dictlist.
      - The prose gets moved to appserver, etc.
      - Where multiple errors can be defined per entity, make them 
        individual failure records.
    - Checkers are used where?
      - "adb sanity onlock check"
        - Used by app_athenawb/app.tcl
      - "adb econ check"
        - Used by sanity.tcl
      - "adb strategy check{er}"
        - Used by strategybrowser.tcl
        - Used by appserver_agent.tcl
        - Used by appserver_sanity.tcl
        - Used by sanity.tcl
      - "adb curse checker" => OK or WARNING
        - Used by cursebrowser.tcl
        - Used by appserver_sanity.tcl
        - Used by sanity.tcl
      - "adb inject checker" => OK or WARNING
        - Not used by appserver_sanity.tcl, included in curse results
        - curse.tcl
      - "adb iom checker" OK or WARNING
        - Used by iombrowser.tcl
        - Used by appserver_sanity.tcl
        - Used by sanity.tcl
      - "adb payload checker"  => OK or WARNING
        - Not used by appserver_sanity.tcl, included in iom results
        - Used by iom.tcl
      - "adb hook checker"
        - Used by appserver_sanity.tcl
        - But there isn't any such command.  WTF!
    - Before Merge:
      - Move prose from checking modules to appserver_sanity.tcl
      - Remove old routines from checking modules.
  - Optimize athena(n) creation, reset, load.  It's way slow.
  - Group athenadb(n) predicates under "is", e.g., "is busy".
  - Finish athena(n) man page!!!!!!!
- Arachne
  - Consider smartdomain look ups using a dict tree: split the url into
    components and just follow them down the tree, accumulating place
    holders as you go.  See if that's faster.
  - Fix scenario name in Arachne's export .tcl file.  It depends on last 
    export, and it shouldn't.
  - Missing Operations:
    - Lock/Unlock/Time Advance
    - HTML I/F to control toplevel operations
    - Many, many .json queries
  - What should the htdocs directory look like?
  - Write arachne(1) man page, referencing I/F doc.
  - Write athena_log(1) man page.


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



