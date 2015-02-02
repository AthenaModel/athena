#-----------------------------------------------------------------------
# TITLE:
#    ted.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n) Text Execution Deputy package
#
#    At present, all ted routines are defined directly in this
#    file.  Ultimately we might define additional modules, in which case
#    this will become a loader script.
#
#    See athena_test(1) for documentation of these utilities.
#
#-----------------------------------------------------------------------

package require snit

#-------------------------------------------------------------------
# ted

puts ""

snit::type ted {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Lookup tables

    # cleanupTables -- list of RDB tables that should be cleared after
    # a test.

    typevariable cleanupTables {
        activity_nga
        actors
        beans
        caps
        cap_access
        cap_kn
        cap_kg
        civgroups
        coop_fg
        curses
        curse_injects
        demog_g
        demog_local
        demog_n
        deploy_ng
        deploy_tng
        drivers
        absits
        expenditures
        frcgroups
        groups
        hooks
        hook_topics
        hrel_fg
        income_a
        ioms
        mads
        nbhoods
        nbrel_mn
        orggroups
        payloads
        personnel_g
        plants_na
        plants_shares
        plants_build
        rule_firings
        rule_inputs
        sigevents
        sigevent_tags
        stance_fg
        stance_nfg
        units
        vrel_ga
        working_build
        working_cash
        working_personnel
        working_deployment
    }

    # cleanupModules -- list of modules that need to be resync'd
    # after a test.

    typevariable cleanupModules {
        nbhood
    }

    #-------------------------------------------------------------------
    # Type Variables

    # appLoaded flag
    #
    # If 1, [ted app] has loaded the app.

    typevariable appLoaded 0

    # Entities ted knows how to create.  The key is the entry ID; the
    # value is a pair, module name and creation dict.

    typevariable entities -array { }

    # List of entities created for this test; cleared by "ted cleanup"
    typevariable createdEntities {}

    # List of notifier events received since last "ted notifier forget".
    # Each event is "object event args..."

    typevariable notifierResults {}

    #-------------------------------------------------------------------
    # Initialization

    # init argv
    #
    # argv  - The command line arguments
    #
    # Loads the app_athena code in preparation for tests, initializes
    # Ted's data structures, and configures tcltest.  If 
    # the argument list includes "-notk", sets ::loadtk to false,
    # extracts -notk from the argument list.  The remaining arguments
    # are returned for use by tcltest.

    typemethod init {argv} {
        # FIRST, if the application is already loaded this is a no-op.
        if {$appLoaded} {
            return $argv
        }
        set appLoaded 1

        # NEXT, check for -notk.
        set ::tkLoaded 1

        if {"-notk" in $argv} {
            set ndx [lsearch -exact $argv -notk]
            set argv [lreplace $argv $ndx $ndx]
            set ::tkLoaded 0
        }

        if {$::tkLoaded} {
            package require Tk
        }

        # NEXT, load and initialize app_athena.
        package require app_athena
        namespace import ::kiteutils::* ::marsutil::* ::projectlib::*

        puts "ted: app_athena(n) at $::app_athena::library"
        puts ""

        app init [list -ignoreuser]

        puts "app_athena(n) initialized."

        # NEXT, initialize tcltest(n).
        package require tcltest 2.2 
        ::tcltest::configure \
            -singleproc yes  \
            -testdir    [file dirname [file normalize [info script]]] \
            -notfile    {all.test all_tests.test} \
            {*}$argv

        # NEXT, define test entities
        DefineEntities

        # NEXT, Define Constraints
        ::tcltest::testConstraint tk    $::tkLoaded
        ::tcltest::testConstraint notk  [expr !$::tkLoaded]

        # NEXT, define custom match algorithms.
        ::tcltest::customMatch dict     [mytypemethod MatchDict]
        ::tcltest::customMatch indict   [mytypemethod MatchInDict]
        ::tcltest::customMatch dictglob [mytypemethod MatchDictGlob]

        # NEXT, get rid of the window, if it exists.
        if {$::tkLoaded} {
            wm protocol .main WM_DELETE_WINDOW { 
                # NOP 
            }

            destroy .main
            update idletasks
        }

        puts "Test Execution Deputy: Initialized"
    }

    # DefineEntities
    #
    # Defines the entities that can be created by TED

    proc DefineEntities {} {

        # Neighborhoods
        defentity NB1 ::nbhood {
            n            NB1
            longname     "Here"
            local        1
            urbanization URBAN
            controller   NONE
            vtygain      1.0
            pcf          1.0
            refpoint     {100 100}
            polygon      {80 80 120 80 100 120}
        }

        defentity OV1 ::nbhood {
            n            OV1
            longname     "Over Here"
            local        1
            urbanization SUBURBAN
            controller   NONE
            vtygain      1.0
            pcf          1.0
            refpoint     {101 101}
            polygon      {81 81 121 81 101 121}
        }

        defentity NB2 ::nbhood {
            n            NB2
            longname     "There"
            local        1
            urbanization RURAL
            controller   NONE
            vtygain      1.0
            pcf          1.0
            refpoint     {300 300}
            polygon      {280 280 320 280 300 320}
        }


        defentity NB3 ::nbhood {
            n            NB3
            longname     "County"
            local        1
            urbanization RURAL
            controller   NONE
            vtygain      1.0
            pcf          1.0
            refpoint     {500 500}
            polygon      {400 400 400 800 800 800 800 400}
        }

        defentity NB4 ::nbhood {
            n            NB4
            longname     "Town"
            local        1
            urbanization URBAN
            controller   NONE
            vtygain      1.0
            pcf          1.0
            refpoint     {700 700}
            polygon      {600 600 600 800 800 800 800 600}
        }

        defentity NL1 ::nbhood {
            n            NL1
            longname     "Not Local"
            local        0
            urbanization URBAN
            controller   NONE
            vtygain      1.0
            pcf          1.0
            refpoint     {800 800}
            polygon      {600 600 600 800 800 800 800 600}
        }

        # Actors
        
        defentity JOE ::actor {
            a                JOE
            longname         "Joe the Actor"
            bsid             1
            supports         SELF
            atype            INCOME
            auto_maintain    0
            cash_reserve     200000
            cash_on_hand     0
            income_goods     10000
            shares_black_nr  0
            income_black_tax 0
            income_pop       0
            income_graft     0
            income_world     0
            budget           0
        }

        defentity BOB ::actor {
            a                BOB
            longname         "Bob the Actor"
            bsid             1
            supports         SELF
            atype            INCOME
            auto_maintain    0
            cash_reserve     150000
            cash_on_hand     0
            income_goods     5000
            shares_black_nr  0
            income_black_tax 0
            income_pop       0
            income_graft     0
            income_world     0
            budget           0
        }

        defentity DAVE ::actor {
            a                DAVE
            longname         "Dave the Actor"
            bsid             1
            supports         SELF
            atype            INCOME
            auto_maintain    0
            cash_reserve     150000
            cash_on_hand     0
            income_goods     5000
            shares_black_nr  0
            income_black_tax 0
            income_pop       0
            income_graft     0
            income_world     0
            budget           0
        }

        defentity BRIAN ::actor {
            a                BRIAN
            longname         "Brian the Actor"
            bsid             1
            supports         BOB
            atype            INCOME
            auto_maintain    0
            cash_reserve     150000
            cash_on_hand     0
            income_goods     5000
            shares_black_nr  0
            income_black_tax 0
            income_pop       0
            income_graft     0
            income_world     0
            budget           0
        }

        defentity WILL ::actor {
            a                WILL
            longname         "Will the Actor"
            bsid             1
            supports         SELF
            atype            BUDGET
            auto_maintain    0
            cash_reserve     0
            cash_on_hand     0
            income_goods     0
            shares_black_nr  0
            income_black_tax 0
            income_pop       0
            income_graft     0
            income_world     0
            budget           10000
        }

        # Civ Groups
        
        defentity SHIA ::civgroup {
            g         SHIA
            longname  "Shia"
            bsid      1
            color     "#c00001"
            n         NB1
            basepop   1000
            pop_cr    0.0
            sa_flag   0
            demeanor  AVERAGE
            lfp       60
            housing   AT_HOME
            hist_flag 0
            upc       0.0
        } NB1

        defentity SUNN ::civgroup {
            g         SUNN
            longname  "Sunni"
            bsid      1
            color     "#c00002"
            n         NB1
            basepop   1000
            pop_cr    0.0
            sa_flag   0
            demeanor  AGGRESSIVE
            lfp       60
            housing   AT_HOME
            hist_flag 0
            upc       0.0
        } NB1

        defentity KURD ::civgroup {
            g         KURD
            longname  "Kurd"
            bsid      1
            color     "#c00003"
            n         NB2
            basepop   1000
            pop_cr    0.0
            sa_flag   1
            demeanor  AGGRESSIVE
            lfp       0
            housing   AT_HOME
            hist_flag 0
            upc       0.0
        } NB2

        defentity NO_ONE ::civgroup {
            g         NO_ONE
            longname  "Nobody"
            bsid      1
            color     "#c00004"
            n         NB2
            basepop   0
            pop_cr    0.0
            sa_flag   1
            demeanor  AGGRESSIVE
            lfp       0
            housing   DISPLACED
            hist_flag 0
            upc       0.0
        } NB2

        defentity NOT_LOCALS ::civgroup {
            g         NOT_LOCALS
            longname  "Not Locals"
            bsid      1
            color     "#c00003"
            n         NL1
            basepop   1000
            pop_cr    0.0
            sa_flag   1
            demeanor  AGGRESSIVE
            lfp       0
            housing   AT_HOME
            hist_flag 0
            upc       0.0
        } NL1

        # Force Groups

        defentity BLUE ::frcgroup {
            g              BLUE
            longname       "US Army"
            a              JOE
            color          "#f00001"
            forcetype      REGULAR
            training       PROFICIENT
            base_personnel 5000
            demeanor       AVERAGE
            cost           0.0
            local          0
        } JOE

        defentity BRIT ::frcgroup {
            g              BRIT
            longname       "British Forces"
            a              JOE
            color          "#f00002"
            forcetype      REGULAR
            training       PROFICIENT
            base_personnel 5000
            demeanor       AVERAGE
            cost           0.0
            local          0
        } JOE
        
        defentity ALQ ::frcgroup {
            g              ALQ
            longname       "Al Qaeda"
            a              BOB
            color          "#f00003"
            forcetype      IRREGULAR
            training       PARTIAL
            base_personnel 1000
            demeanor       AGGRESSIVE
            cost           0.0
            local          0
        } BOB
        
        defentity TAL ::frcgroup {
            g              TAL
            longname       "Taliban"
            a              BOB
            color          "#f00004"
            forcetype      IRREGULAR
            training       PARTIAL
            base_personnel 1000
            demeanor       AGGRESSIVE
            cost           0.0
            local          1
        } BOB
        
        # Organization Groups

        defentity USAID ::orggroup {
            g              USAID
            longname       "US Aid"
            a              JOE
            color          "#000001"
            orgtype        NGO
            base_personnel 1000
            demeanor       AVERAGE
            cost           0.0
        } JOE

        defentity HAL ::orggroup {
            g              HAL
            longname       "Haliburton"
            a              JOE
            color          "#000002"
            orgtype        CTR
            base_personnel 2000
            demeanor       AVERAGE
            cost           0.0
        } JOE

        # Comm. Asset Packages
        defentity CBS ::cap {
            k        CBS
            longname "Columbia Broadcasting System"
            owner    JOE
            capacity 0.8
            cost     1000.0
            nlist    NB1
            glist    SHIA
        } JOE NB1 SHIA

        defentity NBC ::cap {
            k        NBC
            longname "National Broadcasting Corp."
            owner    JOE
            capacity 0.8
            cost     1000.0
            nlist    NB1
            glist    SHIA
        } JOE NB1 SHIA

        defentity ABC ::cap {
            k        ABC
            longname "American Broadcasting Corp."
            owner    JOE
            capacity 0.8
            cost     1000.0
            nlist    NB1
            glist    SHIA
        } JOE NB1 SHIA

        defentity CNN ::cap {
            k        CNN
            longname "Cable News Network"
            owner    BOB
            capacity 0.9
            cost     500.0
            nlist    {NB1 NB2}
            glist    {SUNN KURD}
        } BOB NB1 NB2 SUNN KURD
    
        defentity FOX ::cap {
            k        FOX
            longname "Fox News"
            owner    BOB
            capacity 0.9
            cost     500.0
            nlist    {NB1 NB2}
            glist    {SUNN KURD}
        } BOB NB1 NB2 SUNN KURD

        defentity PBS ::cap {
            k        PBS
            longname "Public Broadcasting System"
            owner    BOB
            capacity 0.8
            cost     1000.0
            nlist    NB1
            glist    SHIA
        } JOE NB1 SHIA

        # Hooks
        defentity HOOK1 ::hook {
            hook_id  HOOK1
            longname "Hook One"
        }

        defentity HOOK2 ::hook {
            hook_id  HOOK2
            longname "Hook Two"
        }

        # IOMs 
        defentity IOM1 ::iom {
            iom_id   IOM1
            longname "IOM One"
            hook_id  HOOK1
        } HOOK1

        defentity IOM2 ::iom {
            iom_id   IOM2
            longname "IOM Two"
            hook_id  HOOK2
        } HOOK2
    }

    # defentity name module parmdict ?entity...?
    #
    # name      The entity name
    # module    The module that creates it
    # parmdict  The creation dictionary
    # entity    An entity on which the group depends.
    #
    # Adds the entity to the entities array

    proc defentity {name module parmdict args} {
        set entities($name) [list $module $parmdict $args]
    }

    #-------------------------------------------------------------------
    # Other Client Commands

    # entity name ?dict?
    # entity name ?key value ...?
    #
    # name    The name of a defined entity
    #
    # By default returns the entity's creation dictionary
    # If additional creation parameters are given, as a single dictionary
    # or as separate keys and values, they are merged with the creation
    # dictionary and the result is returned.

    typemethod entity {name args} {
        # FIRST, entity's dict
        set dict [lindex $entities($name) 1]

        # NEXT, get the additional parameters, if any
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        if {[llength $args] > 0} {
            set dict [dict merge $dict $args]
        }

        return $dict
    }

    # create name ?name....?
    #
    # name     The name of an entity
    #
    # Calls "$module mutate create" or "$module create" for each named entity.

    typemethod create {args} {
        foreach name $args {
            if {$name ni $createdEntities} {
                lassign $entities($name) module parmdict parents

                # FIRST, Create any entities on which this entity depends
                $type create {*}$parents

                # NEXT, create the requested entity
                if {$module in {
                    ::actor ::absit ::civgroup ::frcgroup ::orggroup
                }} {
                    {*}$module create $parmdict
                } else {
                    {*}$module mutate create $parmdict
                }

                lappend createdEntities $name
            }
        }
    }

    # lock ?-fullecon?
    #
    # if the -fullecon option is supplied, the econ model
    # is unomdified, otherwise some parameters are set to
    # reduce it's effect
    # 
    # Reconciles the scenario, so that all implied entities are
    # created, and sends SIM:LOCK.

    typemethod lock {args} {
        if {[lindex $args 0] ne "-fullecon"} {
            parm set econ.gdpExp 0
            parm set econ.empExp 0
        }
        absit reconcile
        ted order SIM:LOCK
    }

    # step
    #
    # Steps time forward by one week, locking the scenario if need be.
    
    typemethod step {} {
        if {[sim state] eq "PREP"} {
            ted lock
        }
        
        ted order SIM:RUN weeks 1 block 1
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
        set createdEntities {}

        ted notifier forget

        if {[sim state] eq "RUNNING"} {
            sim mutate pause
        }

        if {[sim state] eq "PAUSED"} {
            sim restart
        }

        foreach table $cleanupTables {
            rdb eval "DELETE FROM $table;" 
        }

        # So that automatically generated IDs start over at 1.
        # Note that SQLite adds this table as needed.
        catch {
            rdb eval {DELETE FROM main.sqlite_sequence}
        }

        foreach module $cleanupModules {
            {*}$module dbsync
        }

        flunky          reset
        parm            reset
        bsys            clear
        econ            reset
        simclock        reset
        aram            clear
        pot             reset
        aam             reset
        strategy        init
        driver::abevent reset
    }

    # sendex ?-error? command...
    #
    # command...    A Tcl command, represented as either a single argument
    #               containing the entire command, or as multiple arguments.
    #
    # Executes the command in the Executive's client interpreter,
    # and returns the result.  If -error is specified, expects an error
    # returns the error message.
    #
    # Examples: The following calls are equivalent
    #
    #    ted sendex magic absit BADFOOD {1.0 1.0}
    #    ted sendex {magic absit BADFOOD {1.0 1.0}} 

    typemethod sendex {args} {
        # FIRST, is -error specified?
        if {[lindex $args 0] eq "-error"} {
            lshift args
            set errorFlag 1
        } else {
            set errorFlag 0
        }

        # NEXT, get the command
        if {[llength $args] == 1} {
            set command [lindex $args 0]
        } else {
            set command $args
        }

        # NEXT, execute the command
        if {$errorFlag} {
            set code [catch {
                executive eval $command
            } result]

            if {$code} {
                return $result
            } else {
                return -code error "Expected error, got ok"
            }
        } else {
            # Normal case; let nature take its course
            # executive eval test $command
            executive eval $command
        }
    }

    # order ?-reject? name parmdict
    #
    # name       A simulation order
    # parmdict   The order's parameter dictionary, as a single
    #            argument or as multiple arguments.
    #
    # Sends the order in normal mode with transactions off, and returns 
    # the result. If "-reject" is used, expects the order to be rejected.

    typemethod order {args} {
        # FIRST, is -reject specified?
        if {[lindex $args 0] eq "-reject"} {
            lshift args
            set rejectFlag 1
        } else {
            set rejectFlag 0
        }

        # NEXT, get the order name
        set order [lshift args]

        require {$order ne ""} "No order specified!"

        # NEXT, get the parm dict
        if {[llength $args] == 1} {
            set parmdict [lindex $args 0]
        } else {
            set parmdict $args
        }

        # NEXT, send the order
        try {
            flunky transactions off
            if {$rejectFlag} {
                set code [catch {
                    flunky senddict normal $order $parmdict
                } result opts]

                if {$code} {
                    if {[dict get $opts -errorcode] eq "REJECT"} {

                        set    results "\n"
                        foreach {parm error} $result {
                            append results "        $parm [list $error]\n" 
                        }
                        append results "    "
                        
                        return $results
                    } else {
                        return {*}$opts $result
                    }
                } else {
                    return -code error "Expected rejection, got ok"
                }

            } else {
                flunky senddict normal $order $parmdict
            }
        } finally {
            flunky transactions on
        }
    }

    # query sql
    #
    # sql     - An SQL query
    #
    # Does an RDB query using the SQL text, and pretty-prints the 
    # whitespace.

    typemethod query {sql} {
        return "\n[rdb query $sql -maxcolwidth 80]    "
    }

    # querylist sql
    #
    # sql     - An SQL query
    #
    # Does an RDB query using the SQL text, and pretty-prints the 
    # whitespace, returning -list output

    typemethod querylist {sql args} {
        return "\n[rdb query $sql -mode list]    "
    }

    #-------------------------------------------------------------------
    # Strategy Helpers

    # addblock agent ?parm value...?
    #
    # agent  - An agent name
    #
    # Adds a block to an agent and returns its name.  If args
    # are given, they are passed to BLOCK:UPDATE.

    typemethod addblock {agent args} {
        set bid [ted order STRATEGY:BLOCK:ADD agent $agent]

        if {[llength $args] > 0} {
            ted order BLOCK:UPDATE block_id $bid {*}$args
        }

        return [pot get $bid]
    }

    # addcondition block typename ?parm value...?
    #
    # block    - A block object name
    # typename - A condition typename
    #
    # Adds a condition to an agent and returns its name.  If args
    # are given, they are passed to CONDITION:$typename:UPDATE.

    typemethod addcondition {block typename args} {
        set cid [ted order BLOCK:CONDITION:ADD \
                    block_id [$block id] typename $typename]

        if {[llength $args] > 0} {
            ted order CONDITION:${typename} condition_id $cid {*}$args
        }

        return [pot get $cid]
    }

    # addtactic block typename ?parm value...?
    #
    # block    - A block object name
    # typename - A tactic typename
    #
    # Adds a tactic to an agent and returns its name.  If args
    # are given, they are passed to TACTIC:$typename:UPDATE.

    typemethod addtactic {block typename args} {
        set tid [ted order BLOCK:TACTIC:ADD \
                    block_id [$block id] typename $typename]

        if {[llength $args] > 0} {
            ted order TACTIC:${typename} tactic_id $tid {*}$args
        }

        return [pot get $tid]
    }

    # deploy n g personnel
    #
    # n          - The neighborhood
    # g          - The group
    # personnel  - The number of personnel to deploy, or "all"
    #
    # Creates a new onlock YES block for g's owner, and a new
    # DEPLOY tactic in that block.

    typemethod deploy {n g personnel} {
        set a [group owner $g]
        set block [ted addblock $a onlock YES]

        if {$personnel eq "all"} {
            ted addtactic $block DEPLOY                          \
                g         $g                                     \
                pmode     ALL                                    \
                nlist     [gofer construct NBHOODS BY_VALUE $n]  \
                nmode     EQUAL
        } else {
            ted addtactic $block DEPLOY                          \
                g         $g                                     \
                pmode     SOME                                   \
                personnel $personnel                             \
                nlist     [gofer construct NBHOODS BY_VALUE $n]  \
                nmode     EQUAL
        }
    }

    # assign n g a personnel
    #
    # n          - The neighborhood
    # g          - The group
    # a          - The activity
    # personnel  - The number of personnel to deploy
    #
    # Creates a new onlock YES block for g's owner, and a new
    # ASSIGN tactic in that block.

    typemethod assign {n g a personnel} {
        set owner [group owner $g]
        set block [ted addblock $owner onlock YES]

        ted addtactic $block ASSIGN \
            g $g n $n activity $a pmode SOME personnel $personnel
    }

    # tactic identity tactic
    #
    # tactic - a tactic object
    #
    # Given the tactic, passes the tactic's default view parameters
    # back to the tactic's order.  This should work without error.

    typemethod {tactic identity} {tactic} {
        set tname [$tactic typename]
        set order TACTIC:$tname
        set tdict [$tactic view]
        dict set tdict tactic_id [$tactic id]

        set pdict [dict create]

        foreach parm [::athena::orders parms $order] {
            dict set pdict $parm [dict get $tdict $parm]
        }

        ted order $order {*}$pdict

        return "OK"
    }

    # condition identity condition
    #
    # condition - a condition object
    #
    # Given the condition, passes the condition's default view parameters
    # back to the condition's order.  This should work without error.

    typemethod {condition identity} {condition} {
        set cname [$condition typename]
        set order CONDITION:$cname
        set cdict [$condition view]
        dict set cdict condition_id [$condition id]

        set pdict [dict create]

        foreach parm [::athena::orders parms $order] {
            dict set pdict $parm [dict get $cdict $parm]
        }

        ted order $order {*}$pdict

        return "OK"
    }

    #-------------------------------------------------------------------
    # Notifier events

    # notifier forget
    #
    # Clears all of ted's notifier bindings and data

    typemethod {notifier forget} {} {
        notifier forget ::ted

        set notifierResults [list]
    }

    # notifier bind subject event
    #
    # subject     The subject 
    # event       The event ID
    #
    # Binds to the named event; if received, it will go in the results.
    
    typemethod {notifier bind} {subject event} {
        notifier bind $subject $event ::ted \
            [mytypemethod NotifierEvent $subject $event]
    }

    # notifier received
    #
    # Returns a pretty-printed list of lists of the received events 
    # with their arguments.

    typemethod {notifier received} {} {
        if {[llength $notifierResults] > 0} {
            set    results "\n        {"
            append results [join $notifierResults "}\n        {"]
            append results "}\n    "

            return $results
        } else {
            return ""
        }
    }

    # NotifierEvent args...
    #
    # Lappends the args to the notifier results

    typemethod NotifierEvent {args} {
        lappend notifierResults $args
    }

    # notifier diff ndx event matchdict...
    #
    # ndx          The index of the event in the received event queue.
    # event        The event name
    # dict         A dictionary to diff with the event dictionary,
    #              expressed as one argument or many.
    #
    # Does a "ted dictdiff" of the selected event's dict with the
    # specified one, and confirms the event name.  The output is
    # as for dictdiff.

    typemethod {notifier diff} {ndx event args} {
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        set evt    [lindex [ted notifier received] $ndx 1]
        set eparms [lindex [ted notifier received] $ndx 2]

        assert {$evt eq $event}

        ted dictdiff $eparms $args
    } 

    # notifier match ndx event matchdict...
    #
    # ndx          The index of the event in the received event queue.
    # event        The event name
    # dict         A dictionary of keys and patterns match with the 
    #              event dictionary expressed as one argument or many.
    #
    # Does a "ted dictmatch" of the selected event's dict with the
    # specified one, and confirms the event name.  The output is
    # as for dictmatch.

    typemethod {notifier match} {ndx event args} {
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        set evt    [lindex [ted notifier received] $ndx 1]
        set eparms [lindex [ted notifier received] $ndx 2]

        assert {$evt eq $event}

        ted dictmatch $eparms $args
    } 


    #-------------------------------------------------------------------
    # dictdiff

    # dictdiff a b...
    #
    # a    A dict
    # b    A dict, possible specified as individual arguments
    #
    # Compares the two dicts, and returns a description of the values that
    # differ.  Each value is a list {A|B <name> <value>}.  If an item
    # appears in only A or B, an A or B entry will appear in the output.
    # If it appears in both with different values, the A entry will appear
    # followed by the B entry.
    #
    # If there are no differences, the result is an empty string.
    # Otherwise, the output is a valid list of lists, with one difference
    # entry per line, so as to appear nicely formatted in a test -result.

    typemethod dictdiff {a args} {
        # FIRST, get b.
        if {[llength $args] == 1} {
            set b [lindex $args 0]
        } else {
            set b $args
        }

        # NEXT, compare each entry in a with b
        set results [list]

        foreach key [lsort [dict keys $a]] {
            if {![dict exists $b $key]} {
                lappend results [list A $key [dict get $a $key]]
            } elseif {[dict get $b $key] ne [dict get $a $key]} {
                lappend results [list A $key [dict get $a $key]]
                lappend results [list B $key [dict get $b $key]]
            }

            # Remove the key from b, so that we can easily find
            # what's left.
            set b [dict remove $b $key]
        }

        # NEXT, add entries for anything left in b
        foreach key [lsort [dict keys $b]] {
            lappend results [list B $key [dict get $b $key]]
        }

        # NEXT, format.
        if {[llength $results] == 0} {
            return $results
        }
        
        set    out "\n        {"
        append out [join $results "}\n        {"]
        append out "}\n    "
        
        return $out
    }

    # dictmatch a b...
    #
    # a    A dict
    # b    A dict of glob patterns, possibly specified as individual 
    #      arguments
    #
    # Does a string match of each glob pattern in b with the
    # corresponding key and value in a, and returns a dict of the values
    # that differ.  keys in a that do not appear in b are ignored.
    #
    # If all of b's patterns match, the result is "OK".
    # Otherwise, the output is a dict with one key/value pair per line,
    # so as to appear nicely formatted in a test -result.

    typemethod dictmatch {a args} {
        # FIRST, get b.
        if {[llength $args] == 1} {
            set b [lindex $args 0]
        } else {
            set b $args
        }

        # NEXT, compare each entry in b with a
        set results [list]

        foreach key [lsort [dict keys $b]] {
            if {![dict exists $a $key]} {
                lappend results $key *null*
            } elseif {![string match [dict get $b $key] [dict get $a $key]]} {
                lappend results $key [dict get $a $key]
            }
        }

        # NEXT, format.
        if {[llength $results] == 0} {
            return "OK"
        }

        set out "\n"
        foreach {key val} $results {
            append out "        "
            append out [list $key $val]
            append out "\n"
        } 
        append out "    "
        
        return $out
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



