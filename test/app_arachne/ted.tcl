#-----------------------------------------------------------------------
# TITLE:
#    ted.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_arachne(n) Text Execution Deputy package
#
#    This package initializes app_arachne for testing, and provides
#    a variety of test utilities.
#-----------------------------------------------------------------------

package require snit

#-----------------------------------------------------------------------
# ted

snit::type ted {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    typevariable appLoaded 0  ;# if 1, [ted init] has loaded the app.

    #-------------------------------------------------------------------
    # Initialization

    # init argv
    #
    # argv  - The command line arguments
    #
    # Loads the app_arachne code in preparation for tests, initializes
    # Ted's data structures, and configures tcltest.
    # The arguments are returned for use by tcltest.

    typemethod init {argv} {
        # FIRST, if the application is already loaded this is a no-op.
        if {$appLoaded} {
            return $argv
        }
        set appLoaded 1

        # NEXT, load and initialize app_arachne.
        package require app_arachne
        namespace import ::kiteutils::* ::marsutil::* ::projectlib::*

        puts "ted: app_arachne(n) at $::app_arachne::library"
        puts ""

        # Make working directories
        set scratchDir  [file join [pwd] scratch]
        set scenarioDir [file join [pwd] scenario]

        file mkdir $scenarioDir
        lappend appOptions            \
            -test                     \
            -scratchdir  $scratchDir  \
            -scenariodir $scenarioDir

        app init $appOptions

        puts "app_arachne(n) initialized."

        # NEXT, initialize tcltest(n).
        package require tcltest 2.2 
        ::tcltest::configure \
            -singleproc yes  \
            -testdir    [file dirname [file normalize [info script]]] \
            -notfile    {all.test all_tests.test} \
            {*}$argv

        # NEXT, define custom match algorithms.
        ::tcltest::customMatch dict     [mytypemethod MatchDict]
        ::tcltest::customMatch indict   [mytypemethod MatchInDict]
        ::tcltest::customMatch dictglob [mytypemethod MatchDictGlob]
        ::tcltest::customMatch trim     [mytypemethod MatchTrim]
        ::tcltest::customMatch norm     [mytypemethod MatchNorm]


        puts "Test Execution Deputy: Initialized"
    }
    
    # cleanup
    #
    # Cleans up after a test:
    #
    # * Forgets notifier binds
    # * Deletes all records from the $cleanupTables
    # * Clears the SQLITE_SEQUENCE table
    # * Resyncs the $cleanupModules with the RDB
    # * Resets the parms
    
    typemethod cleanup {} {
        # FIRST, reset scenarios to empty.
        case clear
    }

    #-------------------------------------------------------------------
    # Scenario Management

    typevariable scenarioScripts -array {
        test1 {
            send ACTOR:CREATE -a JOE
        }
    }

    # mkadb scenario
    #
    # scenario  - An index into scenarioScripts
    #
    # Creates a scenario file using the named script.

    typemethod mkadb {scenario} {
        set sdb [athena new]
        $sdb executive eval $scenarioScripts($scenario)
        $sdb save [file join [case scenariodir] $scenario.adb]
        $sdb destroy
    }

    # with script
    # 
    # script   - a script to evaluate
    #
    # This method executes the given script in the base case scenario.

    typemethod with {script} {
        case with case00 executive eval $script
    }

    # advance ticks
    # 
    # ticks   - number of ticks to advance
    #
    # This method attempts to lock and advance the base case scenario. 
    # Any errors that occur will bubble up.

    typemethod advance {ticks} {
        case with case00 lock
        case with case00 advance -ticks $ticks
    }

    # redirectf request
    # 
    # suffix   - The url in the /scenario domain, e.g., /index.json
    # args     - The query string, which is simply the dictionary
    #
    # This method traps an HTTP redirect that is expected to go to a file
    # in the temp domain and returns the contents of that file

    typemethod redirectf {suffix args} {
        if {[llength $args] == 1} {
            set query [lindex $args 0]
        } else {
            set query $args
        }

        try {
            set result [$::app::domains(/scenario) request GET $suffix $query]
        } trap HTTPD_REDIRECT {result eopts} {
            set filename [file tail [lindex [dict get $eopts -errorcode] 1]]
            tcltest::viewFile $filename [app tempdir]
        }
    }

    # mkscript scenario
    #
    # scenario - An index into scenarioScripts
    #
    # Saves the script to disk.

    typemethod mkscript {scenario} {
        writefile [file join [case scenariodir] $scenario.tcl] \
            [outdent $scenarioScripts($scenario)]    
    }
    

    #-------------------------------------------------------------------
    # Domain Requests
    
    # get suffix ?args...?
    #
    # suffix   - The url in the /scenario domain, e.g., /index.json
    # args     - The query string, which is simply the dictionary
    #
    # Calls the scenario_domain handler directly as a GET request.

    typemethod get {suffix args} {
        if {[llength $args] == 1} {
            set query [lindex $args 0]
        } else {
            set query $args
        }

        try {
            set result [$::app::domains(/scenario) request GET $suffix $query]
        } trap HTTPD_REDIRECT {result eopts} {
            # The error code includes the URL
            return [dict get $eopts -errorcode]
        } trap NOTFOUND {result} {
            return [list NOTFOUND $result]
        }

        return [string trim $result]
    }

    # getjson suffix ?query...?
    #
    # suffix   - The url in the /scenario domain, e.g., /index.json
    # query    - The query string, which is simply the dictionary
    #
    # Calls the scenario_domain handler directly as a GET request,
    # and parses a JSON return value.

    typemethod getjson {suffix args} {
        if {[llength $args] == 1} {
            set query [lindex $args 0]
        } else {
            set query $args
        }

        try {
            set result [$::app::domains(/scenario) request GET $suffix $query]
        } trap HTTPD_REDIRECT {result eopts} {
            # The error code includes the URL
            return [dict get $eopts -errorcode]
        } trap NOTFOUND {result} {
            return [list NOTFOUND $result]
        }

        return [json::json2dict $result]
    }


    # post suffix ?query?
    #
    # suffix   - The url in the /scenario domain, e.g., /index.json
    # query    - The query string, which is text/plain
    #
    # Calls the scenario_domain handler directly as a POST request.

    typemethod post {suffix {query ""}} {
        try {
            set result [$::app::domains(/scenario) request POST $suffix $query]
        } trap HTTPD_REDIRECT {result eopts} {
            # The error code includes the URL
            return [dict get $eopts -errorcode]
        } trap NOTFOUND {result} {
            return [list NOTFOUND $result]
        }

        return [string trim $result]
    }


    #-------------------------------------------------------------------
    # SQL Queries
    
    # query case sql
    #
    # case    - A case ID
    # sql     - An SQL query
    #
    # Does an RDB query using the SQL text, and pretty-prints the 
    # whitespace.

    typemethod query {case sql} {
        return "\n[case with $case query $sql -maxcolwidth 80]    "
    }

    # querylist case sql
    #
    # case    - A case ID
    # sql     - An SQL query
    #
    # Does an RDB query using the SQL text, and pretty-prints the 
    # whitespace, returning -list output

    typemethod querylist {case sql args} {
        return "\n[case with $case query $sql -mode list]    "
    }
    


    # pdict dict
    #
    # dict - A dictionary
    # 
    # Pretty-prints a dictionary for use in -result

    typemethod pdict {dict} {
        set results "\n"

        set wid [lmaxlen [dict keys $dict]]

        foreach {key value} $dict {
            append results \
                "        [format {%-*s %s} $wid $key [list $value]]\n" 
        }
        append results "    "
                    
        return $results
    }

    # pdicts dict skipping
    #
    # dict     - A dictionary
    # skipping - keys to skip 
    # 
    # Pretty-prints a dictionary for use in -result, with sorted keys.

    typemethod pdicts {dict {skipping ""}} {
        if {[llength $skipping] > 0} {
            set dict [dict remove $dict {*}$skipping]
        }

        set results "\n"

        set wid [lmaxlen [dict keys $dict]]

        foreach key [lsort [dict keys $dict]] {
            set value [dict get $dict $key]
            append results \
                "        [format {%-*s %s} $wid $key [list $value]]\n" 
        }
        append results "    "
                    
        return $results
    }

    # sortdict dict
    #
    # dict     - A dictionary
    # 
    # Returns a dictionary with the keys in sorted order.

    typemethod sortdict {dict} {
        set result [dict create]

        foreach key [lsort [dict keys $dict]] {
            dict set result $key [dict get $dict $key]
        }
                    
        return $result
    }

    # MatchTrim e a
    #
    # e    - Expected result
    # a    - Actual result
    #
    # TclTest custom match algorithm for "trim":
    # trims both results and compares.

    typemethod MatchTrim {e a} {
        expr {[string trim $e] eq [string trim $a]}
    }

    # MatchNorm e a
    #
    # e    - Expected result
    # a    - Actual result
    #
    # TclTest custom match algorithm for "norm": normalizes whitespace
    # in both, and glob matches.

    typemethod MatchNorm {e a} {
        string match [normalize $e] [normalize $a]
    }


    # MatchDict edict adict
    #
    # edict    - Expected result dictionary
    # adict    - Actual result dictionary
    #
    # TclTest custom match algorithm for "dict":
    # the adict must have the same keys as edict, and every value in
    # adict must eq the pattern in edict.

    typemethod MatchDict {edict adict} {
        # FIRST, the dictionaries must have the same keys.
        if {[lsort [dict keys $edict]] ne [lsort [dict keys $adict]]} {
            return 0
        }

        # NEXT, each actual value must match the expected pattern.
        dict for {key value} $adict {
            set pattern [dict get $edict $key]

            if {$value ne $pattern} {
                return 0
            }
        }

        return 1
    }

    # MatchInDict edict adict
    #
    # edict    - Expected result dictionary
    # adict    - Actual result dictionary
    #
    # TclTest custom match algorithm for "indict":
    # every key in the edict must be in the adict, and every value in
    # adict must eq the pattern in edict.  Keys in adict that are not
    # in edict are ignored.

    typemethod MatchInDict {edict adict} {
        dict for {key pattern} $edict {
            if {![dict exists $adict $key]} {
                return 0
            }

            set value [dict get $adict $key]

            if {$value ne $pattern} {
                return 0
            }
        }

        return 1
    }


    # MatchDictGlob edict adict
    #
    # edict    - Expected result dictionary
    # adict    - Actual result dictionary
    #
    # TclTest custom match algorithm for "dictglob":
    # the adict must have the same keys as edict, and every value in
    # adict must [string match] the pattern in edict.

    typemethod MatchDictGlob {edict adict} {
        # FIRST, the dictionaries must have the same keys.
        if {[lsort [dict keys $edict]] ne [lsort [dict keys $adict]]} {
            return 0
        }

        # NEXT, each actual value must match the expected pattern.
        dict for {key value} $adict {
            set pattern [dict get $edict $key]

            if {![string match $pattern $value]} {
                return 0
            }
        }

        return 1
    }

}

