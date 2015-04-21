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
    # names               - The IDs of the different cases.
    # counter             - The case ID counter
    # sdb-$id             - The scenario object for $id 
    # longname-$id        - A one-line description of $id
    # source-$id          - Description of the original source of the $id

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
        $type clear
    }

    # clear
    #
    # Removes all scenarios except the basecase, and resets that one.

    typemethod clear {} {
        foreach id $cases(names) {
            $type delete $id
        }

        array unset cases
        set cases(counter) -1
        set cases(names)   {}

        $type new "" "Base Case"
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
        return $cases(sdb-$id)
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

    # send id pdict
    #
    # id     - A case ID
    # pdict  - An order parmdict(n) object, including "order_"
    #
    # Attempts to send the order to the scenario.  Can throw REJECT.

    typemethod send {id pdict} {
        set sdb [case get $id]

        $pdict prepare order_ -required -toupper \
            -with [list $sdb order validate]

        if {![$pdict ok]} {
            throw REJECT [$pdict errors]
        }

        set order [$pdict remove order_]
        set validparms [::athena::orders parms $order]

        foreach p [dict keys [$pdict parms]] {
            if {$p ni $validparms} {
                $pdict remove $p
            }
        }

        return [$sdb order senddict normal $order [$pdict parms]]
    } 

    # metadata id ?parm?
    #
    # id   - A case ID
    # parm - A metadata parameter
    #
    # Returns a dictionary of metadata about the case.  If parm
    # is given, returns just that parm.

    typemethod metadata {id {parm ""}} {
        dict set result id       $id
        dict set result longname $cases(longname-$id)
        dict set result state    [$type with $id state]
        dict set result tick     [$type with $id clock now]
        dict set result week     [$type with $id clock asString]
        dict set result source   $cases(source-$id)

        if {$parm ne ""} {
            return [dict get $result $parm]
        } else {
            return $result
        }
    }

    # new ?id? ?longname?
    #
    # id         - Optionally, an existing case ID
    # longname   - Optionally, a new longname.
    #
    # Creates a new, empty scenario, optionally giving it the longname,
    # or replaces an existing scenario with a new empty one.

    typemethod new {{id ""} {longname ""}} {
        if {$id eq ""} {
            set id [NextID]
        }

        if {$id in $cases(names)} {
            case with $id reset
            app log normal $id "Reset case $id"
        } else {
            set sdb [athena new \
                        -subject $id \
                        -logdir [scratchdir join log $id]]

            lappend cases(names)    $id
            set cases(longname-$id) [DefaultLongname $id]
            set cases(sdb-$id)      $sdb
            
            app log normal $id "Created new case $id"
        }

        set cases(source-$id) "n/a"

        if {$longname ne ""} {
            set cases(longname-$id) $longname
        }

        return $id
    }

    # import filename id longname
    #
    # filename  - An .adb or .tcl file name in -scenariodir
    # id        - An existing case ID, or ""
    # longname  - A longname, or ""
    #
    # Attempts to import the scenario into the application.  Throws
    # SCENARIO IMPORT on failure.

    typemethod import {filename id {longname ""}} {
        # FIRST, validate the inputs
        if {[file tail $filename] ne $filename} {
            throw {SCENARIO IMPORT} "Not a bare file name"
        }

        set ext [file extension $filename]
        if {$ext ni {.adb .tcl}} {
            throw {SCENARIO IMPORT} "Cannot import files of type \"$ext\""
        }

        set filename [case scenariodir $filename]
        if {![file isfile $filename]} {
            throw {SCENARIO IMPORT} "No such scenario is available."
        }

        # NEXT, get the ID
        if {$id ne ""} {
            set theID $id
        } else {
            set theID [NextID]
        }

        # NEXT, make sure we can load the filename.
        set sdb [athena new -subject $theID]

        if {$ext eq ".adb"} {
            try {
                $sdb load $filename
            } trap {SCENARIO OPEN} {result} {
                $sdb destroy
                throw {SCENARIO IMPORT} $result
            }
        } else {
            try {
                $sdb executive call $filename
            } on error {result} {
                $sdb destroy
                throw {SCENARIO IMPORT} "Script error: $result"
            }
        }

        # NEXT, the import was successful.  Save the new data.
        if {$id ne ""} {
            $cases(sdb-$id) destroy
            set cases(sdb-$id) $sdb
            $cases(sdb-$id) log normal app "Re-imported from $filename"
        } else {
            set id $theID
            lappend cases(names) $id
            set cases(sdb-$id) $sdb
            if {$longname eq ""} {
                set longname [DefaultLongname $id]
            }
        }

        if {$longname ne ""} {
            set cases(longname-$id) $longname
        }

        set cases(source-$id) [file tail $filename]

        return $theID
    }

    # delete id
    #
    # id   - A case ID
    #
    # Destroys the case object and its log, and removes any related data
    # from disk.

    typemethod delete {id} {
        case with $id destroy

        array unset cases(*-$id)
        ldelete cases(names) $id
    }


    
    #-------------------------------------------------------------------
    # Utility Commands

    # scenariodir ?filename?
    #
    # Returns the name of the scenario directory, optionally joining
    # a file to it.

    typemethod scenariodir {{filename ""}} {
        if {$filename ne ""} {
            return [file join $info(scenarioDir) $filename]
        } else {
            return $info(scenarioDir)
        }
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

