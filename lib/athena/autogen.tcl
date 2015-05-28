#-----------------------------------------------------------------------
# TITLE:
#    autogen.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Scenario Auto-Generator 
#
#    This module manages automatic scenario generation.  It is
#    responsible for all aspects of scenario generation generally used
#    for testing Athena. Automtically generated scenarios can be used
#    for load testing, unit testing or for use by the automated
#    test suite.
#
#-----------------------------------------------------------------------

snit::type ::athena::autogen {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Type Variables

    # info array
    #
    # aidx    activity index for ASSIGN tactics

    variable info -array {
        aidx 0
    }

    # scenario args
    #
    # Arguments:
    #
    # -actors     number of actors to create
    # -nbhoods    number of nbhoods to create
    # -frcgroups  number of FRC groups to create
    # -civgroups  number of CIV groups to create
    # -orggroups  number of ORG groups to create
    # -topics     number of belief system topics to create
    # -nostrategy flag indicating that strategies should not be created
    #
    # This method creates a scenario using the optional arguments 
    # supplied. Default numbers are used for any argument that is
    # omitted.

    method scenario {args} {
        require {[$adb is idle] && [$adb is unlocked]} "Not in scenario prep"

        # FIRST, default options
        array set opts {
            -actors     3
            -nbhoods    10
            -frcgroups  3
            -civgroups  6
            -orggroups  2
            -topics     3 
            -strategy   1
        }

        # NEXT, parse input options and error check
        while {[llength $args] > 0} {
            set opt [lshift args]
            switch -exact -- $opt {
                -actors {
                    set opts(-actors) [lshift args]
                    if {![string is integer -strict $opts(-actors)]} {
                        error "-actors: must be integer"
                    }

                    if {$opts(-actors) < 1} {
                        error "-actors: must be positive integer"
                    }
                }

                -nb {
                    set opts(-nbhoods) [lshift args]
                    if {![string is integer -strict $opts(-nbhoods)]} {
                        error "-nb: must be integer"
                    }

                    if {$opts(-nbhoods) < 2} {
                        error "-nb: must be integer >= 2"
                    }

                    if {$opts(-nbhoods) > 999} {
                        error "-nb: max nbhoods is 999"
                    }
                }

                -frcg {
                    set opts(-frcgroups) [lshift args]
                    if {![string is integer -strict $opts(-frcgroups)]} {
                        error "-frcg: must be integer"
                    }

                    if {$opts(-frcgroups) < 1} {
                        error "-frcg: must be positive integer"
                    }
                }

                -civg {
                    set opts(-civgroups) [lshift args]
                    if {![string is integer -strict $opts(-civgroups)]} {
                        error "-civg: must be integer"
                    }

                    if {$opts(-civgroups) < 1} {
                        error "-civg: must be positive integer"
                    }
                }

                -orgg {
                    set opts(-orggroups) [lshift args]
                    if {![string is integer -strict $opts(-orggroups)]} {
                        error "-orgg: must be integer"
                    }

                    if {$opts(-orggroups) < 0} {
                        error "-orgg: must be >= 0"
                    }
                }

                -topics {
                    set opts(-topics) [lshift args]
                    if {![string is integer -strict $opts(-topics)]} {
                        error "-topics: must be integer"
                    }

                    if {$opts(-topics) < 1} {
                        error "-topics: must be >= 1"
                    }
                }

                -nostrategy {
                    set opts(-strategy) 0
                }

                default {
                    error "Unknown option: $opt"
                }
            }
        }

        # NEXT, all inputs check out, blank out the scenario
        $adb reset
        $adb dbsync

        # NEXT, create scenario entities, order matters
        $self Actors    $opts(-actors)
        $self Nbhoods   $opts(-nbhoods)   
        $self CivGroups $opts(-civgroups)
        $self OrgGroups $opts(-orggroups)
        $self FrcGroups $opts(-frcgroups)
        $self BSystem   $opts(-topics)

        # NEXT, if actor strategies are desired, create them
        if {$opts(-strategy)} {
            $self strategy
        }
    }

    # actors ?num?
    #
    # num   number of actors to create
    #
    # This method will create the requested number of actors provided
    # all error checking passes.

    method actors {{num 3}} {
        require {[$adb is idle] && [$adb is unlocked]} "Not in scenario prep"

        # FIRST, no actors can exist currently
        if {[llength [$adb actor names]] > 0} {
            error "Actors already exist, must delete them first"
        }

        if {![string is integer -strict $num]} {
            error "argument must be integer"
        }

        if {$num < 1} {
            error "argument must be >= 1"
        }

        # NEXT, error checking passed, create the actors
        $self Actors $num
    }

    # nbhoods ?num?
    #
    # num   number of nbhoods to create
    #
    # This method will create the requested number of nbhoods provided
    # all error checking passes.

    method nbhoods {{num 10}} {
        require {[$adb is idle] && [$adb is unlocked]} \
            "Not in scenario prep"

        # FIRST, no nbhoods can exists and we must already have actors
        if {[llength [$adb nbhood names]] > 0} {
            error "Nbhoods already exist, must delete them first"
        }

        if {[llength [$adb actor names]] == 0} {
            error "Must create actors first"
        }

        if {![string is integer -strict $num]} {
            error "argument must be integer"
        }

        if {$num < 2} {
            error "argument must be >= 2"
        }

        if {$num > 999} {
            error "argument must be <= 999"
        }

        # NEXT, error checking passed, create the nbhoods
        $self Nbhoods $num
    }


    # civgroups ?num?
    #
    # num  number of CIV groups to create per neighborhood
    #
    # This method will create the requested number of CIV groups in
    # each neighborhood provided all error checking passes.

    method civgroups {{num 6}} {
        require {[$adb is idle] && [$adb is unlocked]} "Not in scenario prep"

        # FIRST, there must already be neighborhoods and no CIV groups
        if {[llength [$adb nbhood names]] == 0} {
            error "Must create nbhoods first"
        }

        if {[llength [$adb civgroup names]] > 0} {
            error "CIV groups already exist, must delete them first"
        }

        if {![string is integer -strict $num]} {
            error "argument must be integer"
        }

        if {$num < 1} {
            error "argument must be >= 1"
        }

        # NEXT, error checking passed, create the CIV groups
        $self CivGroups $num
    }

    # orggroups ?num?
    #
    # num  number of ORG groups to create
    #
    # This method will create the requested number of ORG groups
    # provided all error checking passes.

    method orggroups {{num 2}} {
        require {[$adb is idle] && [$adb is unlocked]} "Not in scenario prep"

        # FIRST, there can be no ORG groups and we must have actor(s)
        if {[llength [$adb orggroup names]] > 0} {
            error "ORG groups already exist, must delete them first"
        }

        if {[llength [$adb actor names]] == 0} {
            error "Must create actors first"
        }

        if {![string is integer -strict $num]} {
            error "argument must be integer"
        }

        if {$num < 1} {
            error "argument must be >= 1"
        }

        # NEXT, error checking passed, create the ORG groups
        $self OrgGroups $num
    }

    # frcgroups ?num?
    #
    # num  number of FRC groups to create
    #
    # This method will create the requested number of CIV groups
    # provided all error checking passes.

    method frcgroups {{num 3}} {
        require {[$adb is idle] && [$adb is unlocked]} "Not in scenario prep"

        # FIRST, there must be no FRC groups and at least one actor
        if {[llength [$adb frcgroup names]] > 0} {
            error "FRC groups already exist, must delete them first"
        }

        if {[llength [$adb actor names]] == 0} {
            error "Must create actors first"
        }

        if {![string is integer -strict $num]} {
            error "argument must be integer"
        }

        if {$num < 1} {
            error "argument must be >= 1"
        }

        # NEXT, error checking passed, create the FRC groups
        $self FrcGroups $num
    }

    # bsystem ?num?
    #
    # num  number of topics to create in the belief system
    #
    # This method will create a belief system with the requested number
    # of topics provided all error checking passes.

    method bsystem {{num 3}} {
        require {[$adb is idle] && [$adb is unlocked]} "Not in scenario prep"

        # FIRST, there must be no topics and we must have CIV groups and
        # actors defined
        if {[llength [$adb bsys topic ids]] > 0} {
            error "Belief system topics already exist, must delete them first"
        }

        if {[llength [$adb civgroup names]] == 0} {
            error "Must create CIV groups first"
        }

        if {[llength [$adb actor names]] == 0} {
            error "Must create actors first"
        }

        if {![string is integer -strict $num]} {
            error "argument must be integer"
        }

        if {$num < 1} {
            error "argument must be >= 1"
        }

        # NEXT, error checking passes, create the belief system
        $self BSystem $num
    }

    # strategy
    #
    # This method will create a  set of tactics for each supplied actor.
    # If no arguments are supplied, then DEPLOY and FUNDENI tactics are
    # created for all actors, force groups, org groups and neighborhoods.
    #
    # Arguments:
    #    -actors   List of actors to create tactics for or "ALL"
    #    -civg     CIV groups to consider when creating tactics or "ALL"
    #    -frcg     FRC groups to consider when creating tactics or "ALL"
    #    -frcact   FRC activities to consider when creating tactics or "ALL"
    #    -orgg     ORG groups to consider when creating tactics or "ALL"
    #    -orgact   ORG activities to consider when creating tactics or "ALL"
    #    -nbhoods  Neighborhoods to consider when creating tactics or "ALL"

    method strategy {args} {
        require {[$adb is idle] && [$adb is unlocked]} "Not in scenario prep"

        # FIRST, default options
        array set opts {
            -tactics    {DEPLOY FUNDENI}
            -actors     ALL
            -civgroups  ALL
            -frcgroups  ALL
            -frcact     ALL
            -orggroups  ALL
            -orgact     ALL
            -nbhoods    ALL
        }

        # NEXT, must have actors, nbhoods and and least one FRC 
        # or ORG group
        if {[llength [$adb actor names]] == 0} {
            error "Must create actors first"
        }

        if {[llength [$adb nbhood names]] == 0} {
            error "Must create nbhoods first"
        }

        if {[llength [$adb frcgroup names]] == 0 &&
            [llength [$adb orggroup names]] == 0} {
            error "Must have at least one FRC group or one ORG group"
        }

        # NEXT, parse any arguments
        while {[llength $args] != 0} {
            set opt [lshift args]
            switch -exact -- $opt {
                -actors {
                    set opts(-actors) [lshift args]

                    # NEXT, get the list of actors 
                    set alist [$adb actor names]

                    if {$opts(-actors) ne "ALL"} {
                        foreach act $opts(-actors) {
                            if {$act ni $alist} {
                                error "Unrecognized actor: $act"
                            }
                        }
                    }
                }

                -civg {
                    set opts(-civgroups) [lshift args]

                    set civg [$adb civgroup names]

                    if {$opts(-civgroups) ne "ALL"} {
                        foreach grp $opts(-civgroups) {
                            if {$grp ni $civg} {
                                error "Unrecognized CIV group: $grp"
                            }
                        }
                    }
                }

                -frcg {
                    set opts(-frcgroups) [lshift args]

                    set frcg [$adb frcgroup names]

                    if {$opts(-frcgroups) ne "ALL"} {
                        foreach grp $opts(-frcgroups) {
                            if {$grp ni $frcg} {
                                error "Unrecognized FRC group: $grp"
                            }
                        }
                    }
                }

                -orgg {
                    set opts(-orggroups) [lshift args]
                    
                    set orgg [$adb orggroup names]

                    if {$opts(-orggroups) ne "ALL"} {
                        foreach grp $opts(-orggroups) {
                            if {$grp ni $orgg} {
                                error "Unrecognized ORG group: $grp"
                            }
                        }
                    }
                }

                -nbhoods {
                    set opts(-nbhoods) [lshift args]

                    set nbhoods [$adb nbhood names]

                    if {$opts(-nbhoods) ne "ALL"} {
                        foreach nb $opts(-nbhoods) {
                            if {$nb ni $nbhoods} {
                                error "Unrecognized nbhood: $nb"
                            }
                        }
                    }
                }

                -frcact {
                    set opts(-frcact) [lshift args]

                    set frcacts [$adb activity frc names]

                    if {$opts(-frcact) ne "ALL"} {
                        foreach act $opts(-frcact) {
                            if {$act ni $frcacts} {
                                error "Unrecognized force activity: $act"
                            }
                        }
                    }
                }

                -orgact {
                    set opts(-orgact) [lshift args]

                    set orgacts [$adb activity org names]

                    if {$opts(-orgact) ne "ALL"} {
                        foreach act $opts(-orgact) {
                            if {$act ni $orgacts} {
                                error "Unrecognized org activity: $act"
                            }
                        }
                    }
                }

                default {
                    error "Unknown option: $opt"
                }
            }
        }

        # NEXT, error checking passes, create strategies
        $self Strategy [array get opts]
    }

    # assign owner args
    #
    # owner   - an actor
    # 
    # Arguments:
    #    -frcg     Force groups to be assigned activities
    #    -orgg     Org groups to be assigned activities
    #    -nbhoods  The nbhoods in which to do activities
    #    -frcact   The type of force activities to do
    #    -orgact   The type of org activities to do
    #
    # This method assigns activities to groups owned by owner in
    # specified nbhoods. If no arguments are supplied then all groups
    # owned by the owner are assigned appropriate activities in turn
    # in each neighborhood.

    method assign {owner args} {
        # FIRST, default opts and parse args
        array set opts {
            -frcg    {}
            -orgg    {}
            -nbhoods {}
            -frcact  {}
            -orgact  {}
        }

        # NEXT, must have actors, nbhoods and and least one FRC 
        # or ORG group
        if {[llength [$adb actor names]] == 0} {
            error "Must create actors first"
        }

        if {[llength [$adb nbhood names]] == 0} {
            error "Must create nbhoods first"
        }

        if {[llength [$adb frcgroup names]] == 0 &&
            [llength [$adb orggroup names]] == 0} {
            error "Must have at least one FRC group or one ORG group"
        }

        # NEXT, parse the args
        while {[llength $args] != 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -frcg {
                    set opts(-frcg) [lshift args]
                }

                -orgg {
                    set opts(-orgg) [lshift args]
                }

                -frcact {
                    set opts(-frcact) [lshift args]
                }

                -orgact {
                    set opts(-orgact) [lshift args]
                }

                -nbhoods {
                    set opts(-nbhoods) [lshift args]
                }

                default {
                    error "Unknown option: $opt"
                }
            }
        }

        # NEXT, error checking
        if {$owner ni [$adb actor names]} {
                error "Unrecognized actor: $owner"
        }

        if {$opts(-frcg) eq ""} {
            set opts(-frcg) [$adb frcgroup ownedby $owner] 

        } else {
            foreach g $opts(-frcg) {
                if {$g ni [$adb frcgroup names]} {
                    error "Unrecognized force group: $g"
                }
            }
        }

        if {$opts(-orgg) eq ""} {
            set opts(-orgg) \
                [$adb eval {SELECT g FROM orggroups_view WHERE a=$owner}]
        } else {
            foreach g $opts(-orgg) {
                if {$g ni [$adb orggroup names]} {
                    error "Unrecognized org group: $g"
                }
            }
        }

        if {$opts(-frcg) eq "" && $opts(-orgg) eq ""} {
            error "Actor $owner does not own any groups"
        }

        # NEXT, get appropriate nbhoods 
        if {$opts(-nbhoods) eq ""} {
            set opts(-nbhoods) [$adb nbhood names]
        } else {
            foreach n $opts(-nbhoods) {
                if {$n ni [$adb nbhood names]} {
                    error "Unrecognized nbhood: $opts(-nbhood)"
                }
            }
        }

        if {$opts(-frcact) eq ""} {
            set opts(-frcact) [$adb activity frc names]
        } else {
            foreach act $opts(-frcact) {
                if {$act ni [$adb activity frc names]} {
                    error "$act is not a valid force activity"
                }
            }
        }

        if {$opts(-orgact) eq ""} {
            set opts(-orgact) [$adb activity org names]
        } else {
            foreach act $opts(-orgact) {
                if {$act ni [$adb activity org names]} {
                    error "$act is not a valid org activity"
                }
            }
        }

        set block [$self AddBlock $owner]

        set aidx 0
        # NEXT, create ASSIGN for force groups
        foreach g $opts(-frcg) {
            foreach n $opts(-nbhoods) {

                set act [lindex $opts(-frcact) $aidx]
                # NEXT, create the tactic
                $self AddTactic ASSIGN $block \
                    g          $g   \
                    n          $n   \
                    activity   $act \
                    personnel  100

               incr aidx
               if {[expr {$aidx % [llength $opts(-frcact)]}] == 0} {
                   set aidx 0
               }
           }
       }

       set aidx 0
       # NEXT, create assign for org groups
       foreach g $opts(-orgg) {
           foreach n $opts(-nbhoods) {
               set act [lindex $opts(-orgact) $aidx]
               # NEXT, create the tactic
                $self AddTactic ASSIGN $block \
                    g          $g   \
                    n          $n   \
                    activity   $act \
                    personnel  100

               incr aidx
               if {[expr {$aidx % [llength $opts(-orgact)]}] == 0} {
                   set aidx 0
               }
           }
       }

    }

    # Actors num
    #
    # num   - number of actors to create
    #
    # This method creates the desired number of actors called "Ann"
    # where nn is an integer from 0 to num - 1. Each actor supports
    # himself.

    method Actors {num} {
        for {set i 0} {$i < $num} {incr i} {
            set parms(a) "A[format "%02d" $i]"
            set parms(supports) "SELF"
            set parms(cash_on_hand) "500B"

            $adb order senddict normal ACTOR:CREATE [array get parms]
        }
    }

    # Nbhoods num
    #
    # num  - number of nbhoods to create
    #
    # This method creates numn nbhoods called "Ni" where i is and
    # integer from 0 to numn-1. Each nbhood is 10x10 pixels in size
    # laid out in columns of 8. Actors are assigned as contollers
    # of each nbhood in turn. Nbhood proximity is HERE for nbhoods
    # that have i +/- 1 from the current nbhood, and FAR for all
    # others. Proximity is symmetric.

    method Nbhoods {num} {
        # FIRST get all actors
        set actors [$adb eval {SELECT a FROM actors}]
        set numa [llength $actors]

        # NEXT, default map projection, may have options
        # overridden
        set proj [maprect %AUTO%]

        # NEXT, get the map projection data from the $adb
        # if it exists.
        $adb eval {
            SELECT * FROM maps WHERE id=1
        } row {
            $proj configure -width $row(width)   \
                            -height $row(height) \
                            -minlat $row(llat)   \
                            -minlon $row(ulon)   \
                            -maxlat $row(ulat)   \
                            -maxlon $row(llon)  
        }
        
        set j -1
        set k 0

        # NEXT, cycle through requested nbhoods
        for {set i 0} {$i < $num} {incr i} {

            # NEXT, start a new row if necessary
            if {[expr {$i % 99}] == 0} {
                incr j
            }

            # NEXT, determine polygon coords in canvas space
            let x1 {($i % 99) * 10.0}
            let x2 {$x1 + 10.0}
            let y1 {$j  * 10.0}
            let y2 {$y1 + 10.0}

            # NEXT, reference point is in the center of the 10x10
            # square
            let refptx {($x1 + $x2) / 2.0}
            let refpty {$y1 + 5.0}
            
            # NEXT, convert to mapref strings
            set refpt [$proj c2ref 100.0 $refptx $refpty]
            set pts [list \
                        [$proj c2ref 100.0 $x1 $y1]   \
                        [$proj c2ref 100.0 $x2 $y1]   \
                        [$proj c2ref 100.0 $x2 $y2] \
                        [$proj c2ref 100.0 $x1 $y2]]

            set parms(n)        "N[format "%02d" $i]"
            set parms(refpoint) $refpt
            set parms(polygon)  $pts

            # NEXT, set the controlling actor
            set parms(controller) [lindex $actors $k]

            $adb order senddict normal NBHOOD:CREATE [array get parms]
            
            # NEXT, increase the actor counter, unless we
            # need to go back to the first actor
            incr k

            if {[expr {$k % $numa}] == 0} {
                set k 0
            }
        }
        
        # NEXT, prepare for nbhood proximity
        array unset parms

        # NEXT, FAR nbhoods. We will override appropriate
        # nbhoods with a proximity of NEAR in the next step
        for {set i 0} {$i < $num} {incr i} {
            for {set j 0} {$j < $num} {incr j} {
                if {$i == $j} {
                    continue
                }

                # Symmetric
                lappend parms(ids) [list "N[format "%02d" $i]" \
                                         "N[format "%02d" $j]"]
                lappend parms(ids) [list "N[format "%02d" $j]" \
                                         "N[format "%02d" $i]"]
            }
        }

        set parms(proximity) "FAR"
        $adb order senddict normal NBREL:UPDATE:MULTI [array get parms]

        # NEXT, if the user only requested two neighborhoods we
        # are done
        if {$num == 2} {
            return
        }

        # NEXT, prepare for NEAR nbhoods
        array unset parms

        # NEXT, NEAR nbhoods are nbhoods that have i = +/- 1
        # from current nbhood.
        for {set i 0} {$i < $num} {incr i} {
            if {$i > 0 && $i < $num-1} {
                set j1 [format "%02d" [expr {$i - 1}]]
                set j2 [format "%02d" [expr {$i + 1}]]

                lappend parms(ids) [list "N[format "%02d" $i]" N$j1]
                lappend parms(ids) [list "N[format "%02d" $i]" N$j2]

                # Symmetric
                lappend parms(ids) [list N$j1 "N[format "%02d" $i]"]
                lappend parms(ids) [list N$j2 "N[format "%02d" $i]"]
            }
        }

        set parms(proximity) "NEAR"

        $adb order senddict normal NBREL:UPDATE:MULTI [array get parms]
    }

    # Civgroups num 
    #
    # num   - number of CIV groups per nbhood
    #
    # This method creates numc civilian groups per neighborhood. The
    # ID of each civgroup is determined by the neighborhood and group.
    # Thus, group "C01" is civilian group 0 in nbhood 1. Each group
    # is given a base population of some multiple of 10000. The first
    # group is given no population. Every other group is a subsistence
    # agriculture group.

    method CivGroups {num} {
        set nbhoods [$adb eval {SELECT n FROM nbhoods}]

        set numn [llength $nbhoods]
        set housing [ehousing names]
        set nhousing [llength $housing]
        set civ_id 0

        # FIRST, step through number of civgroups per nbhood.
        for {set i 0} {$i < $num} {incr i} {

            # NEXT, set base pop, which is zero for the first group
            let parms(basepop) {$i*10000}

            # NEXT, by default, not subsistence farmers. This is 
            # overridden for the last group in each neighborhood
            set parms(sa_flag) 0
            set parms(lfp) 60

            set ctr 0

            # NEXT, step through neighborhoods creating groups as we go
            for {set j 0} {$j < $numn} {incr j} {
                set parms(g) "C[format "%04d" $civ_id]"
                set parms(n) [lindex $nbhoods $j]

                # NEXT set housing
                set parms(housing) [lindex $housing $ctr]

                # NEXT cycle to next housing index, returning to the
                # first if necessary
                incr ctr
                incr civ_id

                if {[expr {$ctr % $nhousing}] == 0} {
                    set ctr 0
                }

                # NEXT, last group in each neighborhood is subsistence 
                # farmers
                if {$j == $numn-1} {
                    set parms(sa_flag) 1
                    set parms(lfp) 0

                    # SA can only be at home
                    set parms(housing) AT_HOME
                }

                $adb order senddict normal CIVGROUP:CREATE [array get parms]
            }
        }
    }

    # OrgGroups num 
    #
    # num   - number of org groups to create
    #
    # This method creates the specified number of ORG groups and has
    # the last actor in the list of actors own all of them. The type
    # of ORG group is assigned in turn. Thus, if there are at least as
    # many ORG groups as there are types, all types will be represented.
    # Each group is given a base personnel of 10000.

    method OrgGroups {num} {
        # FIRST, identify owning actor, its the last one in the list of
        # actors
        set parms(a) [lindex [$adb eval {SELECT a FROM actors}] end]

        # NEXT, have that actors support no one
        set parms(supports) NONE
        $adb order senddict normal ACTOR:UPDATE [array get parms]

        # NEXT, no longer need the "supports" parm
        unset parms(supports)

        # NEXT, number of orgtypes
        set norgtypes [llength [eorgtype names]]

        set orgtype 0

        # NEXT step through number of orgs creating each one
        for {set i 0} {$i < $num} {incr i} {
            set parms(g) "O[format "%02d" $i]"
            set parms(orgtype) [eorgtype name $orgtype]
            set parms(base_personnel) 100000
            set parms(cost) "1K"

            $adb order senddict normal ORGGROUP:CREATE [array get parms]

            incr orgtype
            
            # NEXT, go to first orgtype if we are past the last
            if {[expr $orgtype % $norgtypes] == 0} {
                set orgtype 0
            }
        }
    }


    # FrcGroups num
    #
    # num   - number of frc groups to create
    #
    # This method creates the specified number of force groups.
    # Actors are assigned as owners of a force group in turn.
    # If there are ORG groups, the last actor is skipped; he owns
    # the ORG groups. Each force group is given a base personnel
    # of 10000 and force group types are stepped through in turn.
    # If there are at least as many force groups as there are force
    # group types, then at least one of each type is created.

    method FrcGroups {num} {
        # FIRST, get the list of actors
        set actors [$adb eval {SELECT a FROM actors}]

        set numa [llength $actors]

        # NEXT, the number of force group types
        set nfrctypes [llength [eforcetype names]]

        # NEXT, initialize indices for owning actor and for
        # force group type
        set j 0
        set frctype 0

        # NEXT, create each force group
        for {set i 0} {$i < $num} {incr i} {
            set parms(g)              "F[format "%02d" $i]"
            set parms(a)              [lindex $actors $j]
            set parms(forcetype)      [eforcetype name $frctype]
            set parms(base_personnel) 100000
            set parms(cost)           "1K"

            $adb order senddict normal FRCGROUP:CREATE [array get parms]

            incr frctype
            incr j

            # NEXT, if we are at the last force group type 
            # go back to the first one
            if {[expr $frctype % $nfrctypes] == 0} {
                set frctype 0
            }

            # NEXT, if we are at the last actor go back to the
            # first one.
            if {[expr $j % $numa] == 0} {
                set j 0
            }
        }
    }

    # BSystem num
    #
    # num   number of topics to create
    #
    # This method creates the number of requested topics and then
    # goes through actors and civilian groups creating belief systems
    # and assigning beliefs
    # to each. There are four possible position/emphasis pairs for
    # each entity. These pairs are cycled through the topics. If
    # there are as many topics as there are pairs (four) then
    # affinities between all entities are homogenous. If tension 
    # is desired, it's best to have three or five topics.

    method BSystem {num} {
        # FIRST, create the requested topics
        for {set i 1} {$i <= $num} {incr i} {
            $adb order senddict normal BSYS:TOPIC:ADD [list tid $i]
        }

        # FIRST, create a belief system for each actor and group.
        set sids [list]

        foreach a [$adb actor names] {
            set sid [$adb order senddict normal BSYS:SYSTEM:ADD]
            $adb order senddict normal BSYS:SYSTEM:UPDATE \
                [list sid $sid name "Actor $a's Beliefs"]

            lappend sids $sid
        }

        foreach g [$adb civgroup names] {
            set sid [$adb order senddict normal BSYS:SYSTEM:ADD]
            $adb order senddict normal BSYS:SYSTEM:UPDATE \
                [list sid $sid name "Group $g's Beliefs"]

            lappend sids $sid
        }

        # NEXT, set up the list of positions and emphases, this
        # list could be expanded
        set pelist [list \
                       [list P+ ASTRONG ] \
                       [list P+ DEXTREME] \
                       [list P- ASTRONG ] \
                       [list P- DEXTREME]]

        # NEXT, give actors their beliefs
        set idx 0
        foreach sid $sids  {
            for {set tid 1} {$tid <= $num} {incr tid} {
                set parms(bid) [list $sid $tid]

                # NEXT, set position/emphasis pair 
                lassign [lindex $pelist $idx] parms(position) parms(emphasis)

                $adb order senddict normal BSYS:BELIEF:UPDATE [array get parms]

                # NEXT, go to next position/emphasis pair
                incr idx

                # NEXT, if we are out of pairs, go back to the first one
                if {($idx % [llength $pelist]) == 0} {
                    set idx 0
                }
            }
        }
    }

    # Strategy
    #
    # This method sets up a default set of tactics for each actor if 
    # the -strategy flag is set to 1
    
    method Strategy {args} {
        array set opts [lindex $args 0]

        if {$opts(-actors) eq "ALL"} {
            set opts(-actors) [$adb eval {SELECT a FROM actors}]
        }

        if {$opts(-frcact) eq "ALL"} {
            set opts(-frcact) [$adb activity frc names]
        }

        if {$opts(-orgact) eq "ALL"} {
            set opts(-orgact) [$adb activity org names]
        }

        if {$opts(-nbhoods) eq "ALL"} {
            set opts(-nbhoods) [$adb eval {SELECT n FROM nbhoods}]
        }

        # NEXT, reset activity index
        set info(aidx) 0

        # NEXT, step through each actor setting up group strategy for
        # the groups each actor owns
        if {"DEPLOY" in $opts(-tactics)} {
            foreach a $opts(-actors) {
                set block [$self AddBlock $a onlock YES]

                set frcgroups [$adb eval {
                    SELECT g FROM groups 
                    WHERE gtype='FRC' AND a=$a
                }]

                set orggroups [$adb eval {
                    SELECT g FROM groups 
                    WHERE gtype='ORG' AND a=$a
                }]
                
                if {$opts(-frcgroups) ne "ALL"} {
                    set frcgroups $opts(-frcgroups)
                }

                $self GroupStrategy \
                    $block $frcgroups FRC $opts(-frcact) $opts(-nbhoods)

                if {$opts(-orggroups) ne "ALL"} {
                    set orggroups $opts(-orggroups)
                }

                $self GroupStrategy \
                    $block $orggroups ORG $opts(-orgact) $opts(-nbhoods)
            }
        }

        if {"FUNDENI" in $opts(-tactics)} {
            set civgroups [$adb eval {SELECT g FROM civgroups}]

            if {$opts(-civgroups) ne "ALL"} {
                set civgroups $opts(-civgroups)
            }

            # NEXT, if there are civgroups do FUNDENI
            if {[llength $civgroups] > 0} {
                foreach a $opts(-actors) {
                    set block [$self AddBlock $a onlock YES]
                    $self AddTactic FUNDENI $block \
                        glist  [$adb gofer make CIVGROUPS BY_VALUE $civgroups] \
                        mode   EXACT \
                        amount "1K"
                }
            }
        }
    }

    # GroupStrategy  b groups gtype activites
    #
    # b            The block for adding tactics
    # groups       List of groups to be deployed/assigned activities
    # gtype        The type of groups; FRC or ORG
    # activities   List of activities to be assigned
    # nbhoods      List of nbhoods to which groups should be deployed/assigned
    #
    # This method deploys and assigns appropriate activities
    # to groups owned by the actor that owns the strategy block. 
    # Activities are assigned in turn to each neighborood. The type 
    # of activities depend on whether gtype is FRC or ORG.

    method GroupStrategy {b groups gtype activities nbhoods} {

        # FIRST, set the table name to look up the number of personnel
        set gtable "[string tolower $gtype]groups"

        # NEXT, get the agent that owns the block
        set a [$b agent]

        # NEXT, see if this actor owns any groups of this group type
        set ownedgroups [$adb eval {
            SELECT g FROM groups WHERE gtype=$gtype AND a=$a
        }]

        # NEXT, no groups, get out
        if {[llength $groups] == 0} {
            return
        }

        set usegroups [list]

        # NEXT, gather only owned groups
        foreach group $groups {
            if {$group in $ownedgroups} {
                lappend usegroups $group
            }
        }

        # NEXT, if no groups owned, get out
        if {[llength $usegroups] == 0} {
            error "$a does not own any of the specified groups"
        }

        # NEXT, determine activities based on group type
        set actlen [llength $activities]
        
        # NEXT, in case we've gone from a FRC group to an ORG group
        # and the activity counter is out of range, reset it
        if {$info(aidx) > $actlen} {
            set info(aidx) 0
        }

        # NEXT, go through each group mobilizing, deploying and assigning
        # appropriate activities
        foreach g $usegroups {
            set pers \
                [$adb eval "
                    SELECT base_personnel FROM $gtable
                    WHERE g = \$g
                "]

            $self AddTactic DEPLOY $b \
                pmode  "ALL" \
                g      $g \
                nlist  [$adb gofer make NBHOODS BY_VALUE \
                           [$adb eval {SELECT n FROM nbhoods}]]

            # NEXT determine the number of personnel per neighborhood to
            # assign to an activity
            set persPerN [expr {int(floor($pers / [llength $nbhoods]))}]

            # NEXT, go through neighborhoods assigning activities
            foreach n $nbhoods {
                set act [lindex $activities $info(aidx)]

                $self AddTactic ASSIGN $b \
                    g          $g   \
                    n          $n   \
                    activity   $act \
                    personnel  $persPerN

                # NEXT, increment activity counter making sure
                # not to run off the end
                incr info(aidx)
                if {[expr $info(aidx) % $actlen] == 0} {
                    set info(aidx) 0
                }
            }
        }
    }

    # AddBlock agent args
    #
    # agent   - the agent that owns the created block
    # args    - optional arguments for the block object
    #
    # This method creates and adds a block to the supplied
    # agents strategy. The ID of the block is returned

    method AddBlock {agent args} {
        set bid [$adb order send normal STRATEGY:BLOCK:ADD -agent $agent]

        if {[llength $args] > 0} {
            $adb order senddict normal BLOCK:UPDATE \
                [list block_id $bid {*}$args]
        }

        return [$adb bean get $bid]
    }

    # AddTactic ttype block args
    #
    # ttype   - Tactic type
    # block   - Block object to which the tactic should be added
    # args    - arguments specific to the type of tactic being added
    #
    # This method adds a tactic of the type provided along with the
    # specified arguments.  The caller is responsible for supplying the
    # proper arguments.

    method AddTactic {ttype block args} {
        set tid [$adb order send normal BLOCK:TACTIC:ADD \
                    -block_id [$block id] \
                    -typename $ttype]

        $adb order senddict normal TACTIC:${ttype} \
            [list tactic_id $tid {*}$args]
    }
}
