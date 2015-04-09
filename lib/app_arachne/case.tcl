#-----------------------------------------------------------------------
# TITLE:
#   case.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Arachne case manager.  Each case is a distinct scenario.
#
#-----------------------------------------------------------------------

snit::type case {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # info: Info Array
    #
    # scenarioDir  - Import/export directory for scenario files.

    typevariable info -array {
        scenarioDir ""
    }

    # cases array: tracks scenarios
    #
    # names                 - The IDs of the different cases.
    # counter               - The case ID counter
    # sdb-$case             - The scenario object for $case 
    # longname-$case        - A one-line description of $case
    # log-$case             - logger(n) object for the $case

    typevariable cases -array {
        counter -1
        names {}
    }

    #-------------------------------------------------------------------
    # Initialization

    # init scenarioDir
    #
    # scenarioDir   - The external directory for scenario import/export.
    #
    # Initializes the module, creating an empty base case.

    typemethod init {scenarioDir} {
        # FIRST, get the initialization options.
        set info(scenarioDir) $scenarioDir

        # NEXT, add an empty base case
        $type new "Base Case"
    }

    #-------------------------------------------------------------------
    # Case Management

    # names
    #
    # Returns the list of case names.

    typemethod names {} {
        return $cases(names)
    }

    # validate name
    #
    # Validates the case name.

    typemethod validate {name} {
        if {$name ni $cases(names)} {
            throw INVALID "Unknown scenario: \"$name\""
        }

        return $name
    }


    # get id
    #
    # id - A case name
    #
    # Returns the athena(n) object for the case.  
    #
    # TBD: If we were to implement caching, this is where it would
    # be done.

    typemethod get {id} {
        return cases(sdb-$id)
    }

    # with id subcommand ...
    #
    # id - A case name
    #
    # Asks the case to execute the subcommand.
    #
    # TBD: If we implement caching, this would need to call "get"

    typemethod with {id args} {
        tailcall $cases(sdb-$id) {*}$args
    }

    # new ?longname?
    #
    # Creates a new, empty scenario, giving it the longname.

    typemethod new {{longname ""}} {
        set id [NextID]

        if {$longname eq ""} {
            set longname [DefaultDescription $id]
        }

        lappend cases(names) $id
        set cases(log-$id)      [app newlog $id]
        set cases(longname-$id) $longname
        set cases(sdb-$id)      [athena new \
                                    -logcmd $cases(log-$id) \
                                    -subject $id]

        app log normal $id "Created new case $id, $longname"

        return $id
    }

    # getdict id
    #
    # id   - A case ID
    #
    # Returns a dictionary of information about the case.

    typemethod getdict {id} {
        dict set result id       $id
        dict set result longname $cases(longname-$id)
        dict set result state    [$type with $id state]
        dict set result tick     [$type with $id clock now]
        dict set result week     [$type with $id clock asString]

        return $result
    }

    # import id adbfile
    #
    # adbfile - An external scenario file
    #
    # Loads the file into the named case.  If the import fails, the
    # content of the scenario will be empty; the caller will handle
    # any error.
    #
    # TBD: Should we save the scenario to disk, and restore its 
    # content if the import fails?  Should we immediately save the 
    # new content into the scratch space?
    #
    # TBD: Q: Should we presume that all changes made to cases are
    # immediately persistent?  "Saving" to the user means exporting 
    # a scenario or scenarios to the -scenariodir?

    typemethod import {id adbfile} {
        set sdb $cases(sdb-$id)

        # Load the file.  Assume it's in the scenario directory; 
        # if it's an absolute path already, the file join will have no
        # effect. 
        $sdb load [file join $info(scenarioDir) $adbfile]
    }
    
    #-------------------------------------------------------------------
    # Utility Commands

    # scenariodir
    #
    # Returns the name of the scenario directory.

    typemethod scenariodir {} {
        return $info(scenarioDir)
    }   

    #-------------------------------------------------------------------
    # Private Helpers

    # NextID
    #
    # Assigns the next case ID.
    proc NextID {} {
        format "case%02d" [incr cases(counter)]
    }

    # DefaultLongname id
    #
    # id  - A case ID
    #
    # Returns a default long name for the case.

    proc DefaultLongname {id} {
        set num [string range $id 4 end]
        return "Scenario #$num"
    }
    
}

