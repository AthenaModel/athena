#-----------------------------------------------------------------------
# TITLE:
#    gofer_number.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Number gofer
#    
#    gofer::NUMBER: A number, floating-or-integer, produced according to
#    one of various rules

#-----------------------------------------------------------------------
# gofer::NUMBER

gofer define NUMBER "" {
    rc "" -width 3in -span 3
    label {
        Enter a rule for retrieving a particular number.
    }
    rc

    rc
    selector _rule {
        case BY_VALUE "specific number" {
            rc
            rc "Enter the desired number:"
            rc
            text raw_value 
        }
        
        case EXPR "TCL expression" {
            rc
            rc "A Tcl Boolean expression."
            rc
            text expr_value
        }

        case AFFINITY "affinity(x,y)" {
            rc
            rc "Affinity of group or actor"
            rc
            enumlong x -showkeys yes -dictcmd {::ptype goa namedict}

            rc "with group or actor"
            rc
            enumlong y -showkeys yes -dictcmd {::ptype goa namedict}
        }

        case AGENT_PLANTS "aplants(a)" {
            rc
            rc "The total number of plants owned by agent"
            rc
            enum a -listcmd {::agent names}
        }

        case ASSIGNED "assigned(g,activity,n)" {
            rc
            rc "Number of personnel of force or org group "
            rc
            enumlong g -showkeys yes -dictcmd {::ptype fog namedict}


            rc "assigned to do activity"
            rc
            enum activity -listcmd {::activity asched names $g}

            rc "in neighborhood"
            rc
            enumlong n -showkeys yes -dictcmd {::nbhood namedict}
        }

        case GROUP_CONSUMERS "consumers(g,...)" {
            rc
            rc "Consumers belonging to civilian group(s)"
            rc
            enumlonglist glist -showkeys yes -dictcmd {::civgroup namedict} \
                -width 30 -height 10
        }

        case COOP "coop(f,g)" {
            rc
            rc "Cooperation of civilian group"
            rc
            enumlong f -showkeys yes -dictcmd {::civgroup namedict}

            rc "with force group"
            rc
            enumlong g -showkeys yes -dictcmd {::frcgroup namedict}
        }

        case COVERAGE "coverage(g,activity,n)" {
            rc
            rc "Coverage fraction for force or org group"
            rc
            enumlong g -showkeys yes -dictcmd {::ptype fog namedict}

            rc "assigned to activity"
            rc
            enum activity -listcmd {::activity withcov names [group gtype $g]}

            rc "in neighborhood"
            rc
            enumlong n -showkeys yes -dictcmd {::nbhood namedict}
        }

        case DEPLOYED "deployed(g,n,...)" {
            rc
            rc "Personnel of force or org group"
            rc
            enumlong g -showkeys yes -dictcmd {::ptype fog namedict}

            rc
            rc "deployed in neighborhood(s)"
            rc
            enumlonglist nlist -showkeys yes -dictcmd {::nbhood namedict} \
                -width 30 -height 10
        }

        case GDP "gdp()" {
            rc
            rc "The value of the Gross Domestic Product of the regional economy \
                in base-year dollars."
            rc
       }

        case GOODS_CAP "goodscap(a)" {
            rc
            rc "The total output capacity of all goods production plants given an agent"
            rc
            enum a -listcmd {::agent names}
        }

        case GOODS_IDLE "goodsidle()" {
            rc
            rc "The idle capacity for the playbox."
            rc
        }

        case HREL "hrel(f,g)" {
            rc
            rc "The horizontal relationship of group"
            rc
            enumlong f -showkeys yes -dictcmd {::group namedict}

            rc "with group"
            rc
            enumlong g -showkeys yes -dictcmd {::group namedict}
        }

        case INCOME "income(a,...)" {
            rc
            rc "The total income for actor(s)"
            rc
            enumlonglist alist -showkeys yes -dictcmd {::actor namedict} \
                -width 30 -height 10
        }

        case INCOME_BLACK "income_black(a,...)" {
            rc
            rc "The income from the black market sector for actor(s)"
            rc
            enumlonglist alist -showkeys yes -dictcmd {::actor namedict} \
                -width 30 -height 10
        }

        case INCOME_GOODS "income_goods(a,...)" {
            rc
            rc "The total income for actor(s)"
            rc
            enumlonglist alist -showkeys yes -dictcmd {::actor namedict} \
                -width 30 -height 10
        }

        case INCOME_POP "income_pop(a,...)" {
            rc
            rc "The total income for actor(s)"
            rc
            enumlonglist alist -showkeys yes -dictcmd {::actor namedict} \
                -width 30 -height 10
        }

        case INCOME_REGION "income_region(a,...)" {
            rc
            rc "The total income for actor(s)"
            rc
            enumlonglist alist -showkeys yes -dictcmd {::actor namedict} \
                -width 30 -height 10
        }

        case INCOME_WORLD "income_world(a,...)" {
            rc
            rc "The total income for actor(s)"
            rc
            enumlonglist alist -showkeys yes -dictcmd {::actor namedict} \
                -width 30 -height 10
        }

        case INFLUENCE "influence(a,n)" {
            rc
            rc "Influence of actor"
            rc
            enumlong a -showkeys yes -dictcmd {::actor namedict}

            rc "in neighborhood"
            rc
            enumlong n -showkeys yes -dictcmd {::nbhood namedict}
        }

        case LOCAL_CONSUMERS "local_consumers()" {
            rc
            rc "Consumers resident in local neighborhoods"
            rc
        }

        case LOCAL_POPULATION "local_pop()" {
            rc
            rc "Population of civilian groups in local neighborhoods"
            rc
        }

        case LOCAL_UNEMPLOYMENT_RATE "local_unemp()" {
            rc
            rc "Unemployment rate in local neighborhoods"
            rc
        }

        case LOCAL_WORKERS "local_workers()" {
            rc
            rc "Workers resident in local neighborhoods"
            rc
        }

        case MOBILIZED "mobilized(g,...)" {
            rc
            rc "Personnel mobilized in the playbox belonging to force or org group"
            rc
            enumlonglist glist -showkeys yes -dictcmd {::ptype fog namedict}
        }

        case MOOD "mood(g)" {
            rc
            rc "Mood of civilian group"
            rc
            enumlong g -showkeys yes -dictcmd {::civgroup namedict}
        }

        case NBCONSUMERS "nbconsumers(n,...)" {
            rc
            rc "Consumers resident in neighborhood(s)"
            rc
            enumlonglist nlist -showkeys yes -dictcmd {::nbhood namedict} \
                -width 30 -height 10
        }

        case NBCOOP "nbcoop(n,g)" {
            rc
            rc "Cooperation of neighborhood"
            rc
            enumlong n -showkeys yes -dictcmd {::nbhood namedict}

            rc "with force group"
            rc
            enumlong g -showkeys yes -dictcmd {::frcgroup namedict}
        }

        case NB_GOODS_CAP "nbgoodscap(n)" {
            rc
            rc "The total output capacity of all goods production plants in neighborhood"
            rc
            enumlong n -showkeys yes -dictcmd {::nbhood namedict}
        }

        case NBMOOD "nbmood(n)" {
            rc
            rc "Mood of neighborhood"
            rc
            enumlong n -showkeys yes -dictcmd {::nbhood namedict}
        }

        case NB_PLANTS "nbplants(n)" {
            rc
            rc "The total number of plants in neighborhood"
            rc
            enumlong n -showkeys yes -dictcmd {::nbhood namedict}
        }

        case NBPOPULATION "nbpop(n,...)" {
            rc
            rc "Civilian population in neighborhood(s)"
            rc
            enumlonglist nlist -showkeys yes -dictcmd {::nbhood namedict} \
                -width 30 -height 10
        }

        case NBSUPPORT "nbsupport(a,n)" {
            rc
            rc "Support of actor"
            rc
            enumlong a -showkeys yes -dictcmd {::actor namedict}
            
            rc "in neighborhood"
            rc
            enumlong n -showkeys yes -dictcmd {::nbhood namedict}    
        }

        case NB_UNEMPLOYMENT_RATE "nbunemp(n,...)" {
            rc
            rc "Unemployment rate for neighborhood(s)"
            rc
            enumlonglist nlist -showkeys yes -dictcmd {::nbhood namedict} \
                -width 30 -height 10
        }

        case NBWORKERS "nbworkers(n,...)" {
            rc
            rc "Workers resident in neighborhood(s)"
            rc
            enumlonglist nlist -showkeys yes -dictcmd {::nbhood namedict} \
                -width 30 -height 10
        }

        case CASH_ON_HAND "onhand(a)" {
            rc
            rc "The cash on hand of actor a"
            rc
            enumlong a -showkeys yes -dictcmd {::actor namedict}
        }

        case PLAYBOX_CONSUMERS "pbconsumers()" {
            rc
            rc "Consumers resident in the playbox."
            rc
        }

        case PLAYBOX_GOODS_CAP "pbgoodscap()" {
            rc
            rc "The total output capacity of all goods production plants in the playbox."
            rc
        }

        case PLAYBOX_PLANTS "pbplants()" {
            rc
            rc "The total number of plants in the playbox"
            rc
        }

        case PLAYBOX_POPULATION "pbpop()" {
            rc
            rc "Population of civilian groups in the playbox."
            rc
        }

        case PLAYBOX_UNEMPLOYMENT_RATE "pbunemp()" {
            rc
            rc "Unemployment rate in the playbox."
            rc
        }

        case PLAYBOX_WORKERS "pbworkers()" {
            rc
            rc "Workers resident in the playbox."
            rc
        }

        case PCTCONTROL "pctcontrol(a,...)" {
            rc 
            rc "Percentage of neighborhood controlled by these actors"
            rc
            enumlonglist alist -showkeys yes -dictcmd {::actor namedict} \
                -width 30 -height 10
        }

        case PLANTS "plants(a,n)" {
            rc
            rc "The total number of plants owned by agent"
            rc
            enum a -listcmd {::agent names}

            rc "in neighborhood"
            rc
            enumlong n -showkeys yes -dictcmd {::nbhood namedict}
        }

        case GROUP_POPULATION "pop(g,...)" {
            rc
            rc "Population of civilian group(s) in playbox"
            rc
            enumlonglist glist -showkeys yes -dictcmd {::civgroup namedict} \
                -width 30 -height 10
        }

        case REPAIR "repair(a,n)" {
            rc
            rc "The current level of repair for plants owned by actor"
            rc
            enumlong a -showkeys yes -dictcmd {::actor namedict}

            rc "in neighborhood"
            rc
            enumlong n -showkeys yes -dictcmd {::nbhood namedict}
        }

        case CASH_RESERVE "reserve(a)" {
            rc
            rc "The cash reserve of actor a"
            rc
            enumlong a -showkeys yes -dictcmd {::actor namedict}
        }

        case SAT "sat(g,c)" {
            rc
            rc "Satisfaction of civilian group"
            rc
            enumlong g -showkeys yes -dictcmd {::civgroup namedict}

            rc "with concern"
            rc
            enumlong c -showkeys yes -dictcmd {::econcern deflist}
        }

        case SECURITY_CIV "security(g)" {
            rc
            rc "Security of civilian group"
            rc
            enumlong g -showkeys yes -dictcmd {::civgroup namedict}         
        }

        case SECURITY "security(g,n)" {
            rc
            rc "Security of group"
            rc
            enumlong g -showkeys yes -dictcmd {::group namedict}

            rc "in neighborhood"
            rc
            enumlong n -showkeys yes -dictcmd {::nbhood namedict}            
        }

        case SUPPORT_CIV "support(a,g)" {
            rc
            rc "Support for actor"
            rc
            enumlong a -showkeys yes -dictcmd {::actor namedict}
            
            rc "by group"
            rc
            enumlong g -showkeys yes -dictcmd {::civgroup namedict}
        }

        case SUPPORT "support(a,g,n)" {
            rc
            rc "Support for actor"
            rc
            enumlong a -showkeys yes -dictcmd {::actor namedict}
            
            rc "by group"
            rc
            enumlong g -showkeys yes -dictcmd {::group namedict}
            
            rc "in neighborhood"
            rc
            enumlong n -showkeys yes -dictcmd {::nbhood namedict}    
        }

        case GROUP_UNEMPLOYMENT_RATE "unemp(g,...)" {
            rc
            rc "Unemployment rate for civilian group(s)"
            rc
            enumlonglist glist -showkeys yes -dictcmd {::civgroup namedict} \
                -width 30 -height 10
        }

        case VREL "vrel(g,a)" {
            rc
            rc "The vertical relationship of group"
            rc
            enumlong g -showkeys yes -dictcmd {::group namedict}

            rc "with actor"
            rc
            enumlong a -showkeys yes -dictcmd {::actor namedict}
        }

        case GROUP_WORKERS "workers(g,...)" {
            rc
            rc "Workers belonging to civilian group(s)"
            rc
            enumlonglist glist -showkeys yes -dictcmd {::civgroup namedict} \
                -width 30 -height 10
        }
    }
}

#-----------------------------------------------------------------------
# Helper Commands

# TBD

#-----------------------------------------------------------------------
# Gofer Rules

# Rule: BY_VALUE
#
# Some number chosen by the user.

gofer rule NUMBER BY_VALUE {raw_value} {
    typemethod construct {raw_value} {
        return [$type validate [dict create raw_value $raw_value]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create raw_value [snit::double validate $raw_value]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "$raw_value"
    }

    typemethod eval {gdict} {
        dict with gdict {}

        return $raw_value
    }
}

# Rule: EXPR
#
# An TCL expression chosen by the user.

gofer rule NUMBER EXPR {expr_value} {
    typemethod construct {expr_value} {
        return [$type validate [dict create expr_value $expr_value]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create expr_value [executive expr validate $expr_value]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "$expr_value"
    }

    typemethod eval {gdict} {
        dict with gdict {}

        return [executive eval [list expr $expr_value]]
    }
}

# Rule: AFFINITY
#
# affinity(x,y)

gofer rule NUMBER AFFINITY {x y} {
    typemethod construct {x y} {
        return [$type validate [dict create x $x y $y]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            x [ptype goa validate [string toupper $x]] \
            y [ptype goa validate [string toupper $y]]

    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {affinity("%s","%s")} $x $y]
    }

    typemethod eval {gdict} {
        dict with gdict {}
        
        return [format %.2f [bsys affinity [getbsid $x] [getbsid $y]]]
    }

    proc getbsid {e} {
        rdb eval {
            SELECT bsid FROM actors WHERE a=$e
        } {
            return $bsid
        }

        rdb eval {
            SELECT bsid FROM groups_bsid_view WHERE g=$e
        } {
            return $bsid
        }

        return 1
    }
}

# Rule: AGENT_PLANTS
#
# aplants(a)

gofer rule NUMBER AGENT_PLANTS {a} {
    typemethod construct {a} {
        return [$type validate [dict create a $a]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            a [agent validate [string toupper $a]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {aplants("%s")} $a]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        set plants [plant number a $a]

        if {$plants == ""} {
            set plants 0.0
        }

        return $plants
    }
}

# Rule: ASSIGNED
#
# assigned(g,activity,n)

gofer rule NUMBER ASSIGNED {g activity n} {
    typemethod construct {g activity n} {
        return [$type validate [dict create g $g activity $activity n $n]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        set valid [dict create]

        dict set valid g [ptype fog validate [string toupper $g]]

        dict set valid activity [string toupper $activity]

        if {$activity eq ""} {
            return -code error -errorcode INVALID \
                "Invalid activity \"\"."
        } else {
            activity check [string toupper $g] [string toupper $activity]
        }

        dict set valid n [nbhood validate [string toupper $n]]

        return $valid
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {assigned("%s","%s","%s")} $g $activity $n]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT total(personnel) AS assigned FROM units WHERE n=$n AND g=$g AND a=$activity
        } {
            return [format %.0f $assigned]
        }

        return 0
    }
}

# Rule: GROUP_CONSUMERS
#
# consumers(g,...)

gofer rule NUMBER GROUP_CONSUMERS {glist} {
    typemethod construct {glist} {
        return [$type validate [dict create glist $glist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create glist \
            [listval civgroups {civgroup validate} [string toupper $glist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {consumers("%s")} [join $glist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $glist ',']')"

        # NEXT, query the total of consumers belonging to
        # groups in the list.
        set count [rdb onecolumn "
            SELECT sum(consumers) 
            FROM demog_g
            WHERE g IN $inClause
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: COOP
#
# coop(f,g)

gofer rule NUMBER COOP {f g} {
    typemethod construct {f g} {
        return [$type validate [dict create f $f g $g]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            f [civgroup validate [string toupper $f]] \
            g [frcgroup validate [string toupper $g]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {coop("%s","%s")} $f $g]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT coop FROM uram_coop WHERE f=$f AND g=$g
        } {
            return [format %.1f $coop]
        }

        return 50.0
    }
}

# Rule: COVERAGE
#
# coverage(g,activity,n)

gofer rule NUMBER COVERAGE {g activity n} {
    typemethod construct {g activity n} {
        return [$type validate [dict create g $g activity $activity n $n]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        set valid [dict create]

        dict set valid g [::ptype fog validate [string toupper $g]]
        dict set valid activity [string toupper $activity]

        set gtype [group gtype [string toupper $g]]

        if {$gtype eq "FRC"} {
            activity withcov frc validate [string toupper $activity]
        } elseif {$gtype eq "ORG"} {
            activity withcov org validate [string toupper $activity]
        }

        dict set valid n [nbhood validate [string toupper $n]]

        return $valid
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {coverage("%s","%s","%s")} $g $activity $n]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT coverage FROM activity_nga WHERE n=$n AND g=$g AND a=$activity
        } {
            return [format %.1f $coverage]
        }

        return 0.0
    }
}

# Rule: DEPLOYED
#
# deployed(g,n,...)

gofer rule NUMBER DEPLOYED {g nlist} {
    typemethod construct {g nlist} {
        return [$type validate [dict create g $g nlist $nlist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create \
            g [ptype fog validate [string toupper $g]] \
            nlist [listval nbhoods {nbhood validate} [string toupper $nlist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {deployed("%s","%s")} $g [join $nlist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $nlist ',']')"

        # NEXT, query the total of deployed belonging to
        # the group in the nbhoods in the nbhood list.
        set count [rdb onecolumn "
            SELECT sum(personnel) 
            FROM deploy_ng
            WHERE g='$g'
            AND n IN $inClause
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: GDP
#
# gdp()

gofer rule NUMBER GDP {} {
    typemethod construct {} {
        return [$type validate [dict create]]
    }

    typemethod validate {gdict} {
        dict create
    }

    typemethod narrative {gdict {opt ""}} {
        return "gdp()"
    }

    typemethod eval {gdict} {
        if {[econ state] eq "DISABLED"} {
            return 0.00
        } else {
            return [format %.2f [econ value Out::DGDP]]
        }
    }
}

# Rule: GOODS_CAP
#
# goodscap(a)

gofer rule NUMBER GOODS_CAP {a} {
    typemethod construct {a} {
        return [$type validate [dict create a $a]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            a [agent validate [string toupper $a]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {goodscap("%s")} $a]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        set goodscap [plant capacity a $a]

        if {$goodscap == ""} {
            set goodscap 0.0
        }

        return $goodscap
    }
}

# Rule: GOODS_IDLE
#
# goodsidle()

gofer rule NUMBER GOODS_IDLE {} {
    typemethod construct {} {
        return [$type validate [dict create]]
    }

    typemethod validate {gdict} {
        dict create
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "goodsidle()"
    }

    typemethod eval {gdict} {
        if {[econ state] eq "DISABLED"} {
            return 0.00
        } else {
            return [format %.2f [econ value Out::IDLECAP.goods]]
        }
    }
}

# Rule: HREL
#
# hrel(f,g)

gofer rule NUMBER HREL {f g} {
    typemethod construct {f g} {
        return [$type validate [dict create f $f g $g]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            f [group validate [string toupper $f]] \
            g [group validate [string toupper $g]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {hrel("%s","%s")} $f $g]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT hrel FROM uram_hrel WHERE f=$f AND g=$g AND tracked
        } {
            return [format %.1f $hrel]
        }

        return 0.0
    }
}

# Rule: INCOME
#
# income(a,...)

gofer rule NUMBER INCOME {alist} {
    typemethod construct {alist} {
        return [$type validate [dict create alist $alist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create alist \
            [listval actors {actor validate} [string toupper $alist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {income("%s")} [join $alist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $alist ',']')"

        # NEXT, query the total income belonging to
        # actor(s) in the list.
        set count [rdb onecolumn "
            SELECT sum(income) 
            FROM income_a
            WHERE a IN $inClause
        "]

        if {$count == ""} {
            return 0.00
        } else {
            return [format %.2f $count]
        }
    }
}

# Rule: INCOME_BLACK
#
# income_black(a,...)

gofer rule NUMBER INCOME_BLACK {alist} {
    typemethod construct {alist} {
        return [$type validate [dict create alist $alist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create alist \
            [listval actors {actor validate} [string toupper $alist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {income_black("%s")} [join $alist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $alist ',']')"

        # NEXT, query the total inc_black_t belonging to
        # actor(s) in the list.
        set countt [rdb onecolumn "
            SELECT sum(inc_black_t) 
            FROM income_a
            WHERE a IN $inClause
        "]

        if {$countt == ""} {
            set countt 0.00
        } 

        # NEXT, query the total inc_black_nr belonging to
        # actor(s) in the list.
        set countnr [rdb onecolumn "
            SELECT sum(inc_black_nr)
            FROM income_a
            WHERE a IN $inClause
        "]

        if {$countnr == ""} {
            set countnr 0.00
        }

        return [format %.2f [expr $countt+$countnr]]
    }
}

# Rule: INCOME_GOODS
#
# income_goods(a,...)

gofer rule NUMBER INCOME_GOODS {alist} {
    typemethod construct {alist} {
        return [$type validate [dict create alist $alist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create alist \
            [listval actors {actor validate} [string toupper $alist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {income_goods("%s")} [join $alist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $alist ',']')"

        # NEXT, query the total inc_goods belonging to
        # actor(s) in the list.
        set count [rdb onecolumn "
            SELECT sum(inc_goods) 
            FROM income_a
            WHERE a IN $inClause
        "]

        if {$count == ""} {
            return 0.00
        } else {
            return [format %.2f $count]
        }
    }
}

# Rule: INCOME_POP
#
# income_pop(a,...)

gofer rule NUMBER INCOME_POP {alist} {
    typemethod construct {alist} {
        return [$type validate [dict create alist $alist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create alist \
            [listval actors {actor validate} [string toupper $alist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {income_pop("%s")} [join $alist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $alist ',']')"

        # NEXT, query the total inc_pop belonging to
        # actor(s) in the list.
        set count [rdb onecolumn "
            SELECT sum(inc_pop) 
            FROM income_a
            WHERE a IN $inClause
        "]

        if {$count == ""} {
            return 0.00
        } else {
            return [format %.2f $count]
        }
    }
}

# Rule: INCOME_REGION
#
# income_region(a,...)

gofer rule NUMBER INCOME_REGION {alist} {
    typemethod construct {alist} {
        return [$type validate [dict create alist $alist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create alist \
            [listval actors {actor validate} [string toupper $alist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {income_region("%s")} [join $alist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $alist ',']')"

        # NEXT, query the total inc_region belonging to
        # actor(s) in the list.
        set count [rdb onecolumn "
            SELECT sum(inc_region) 
            FROM income_a
            WHERE a IN $inClause
        "]

        if {$count == ""} {
            return 0.00
        } else {
            return [format %.2f $count]
        }
    }
}

# Rule: INCOME_WORLD
#
# income_world(a,...)

gofer rule NUMBER INCOME_WORLD {alist} {
    typemethod construct {alist} {
        return [$type validate [dict create alist $alist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create alist \
            [listval actors {actor validate} [string toupper $alist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {income_world("%s")} [join $alist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $alist ',']')"

        # NEXT, query the total inc_world belonging to
        # actor(s) in the list.
        set count [rdb onecolumn "
            SELECT sum(inc_world) 
            FROM income_a
            WHERE a IN $inClause
        "]

        if {$count == ""} {
            return 0.00
        } else {
            return [format %.2f $count]
        }
    }
}

# Rule: INFLUENCE
#
# influence(a,n)

gofer rule NUMBER INFLUENCE {a n} {
    typemethod construct {a n} {
        return [$type validate [dict create a $a n $n]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            a [actor validate [string toupper $a]] \
            n [nbhood validate [string toupper $n]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {influence("%s","%s")} $a $n]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT influence FROM influence_na WHERE n=$n AND a=$a
        } {
            return [format %.2f $influence]
        }

        return 0.0
    }
}

# Rule: LOCAL_CONSUMERS
#
# local_consumers()

gofer rule NUMBER LOCAL_CONSUMERS {} {
    typemethod construct {} {
        return [$type validate [dict create]]
    }

    typemethod validate {gdict} {
        dict create
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "local_consumers()"
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # NEXT, query the total of consumers
        set count [rdb onecolumn "
            SELECT consumers
            FROM demog_local
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: LOCAL_POPULATION
#
# local_pop()

gofer rule NUMBER LOCAL_POPULATION {} {
    typemethod construct {} {
        return [$type validate [dict create]]
    }

    typemethod validate {gdict} {
        dict create
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "local_pop()"
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # NEXT, query the total of population
        set count [rdb onecolumn "
            SELECT population
            FROM demog_local
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: LOCAL_UNEMPLOYMENT_RATE
#
# local_unemp()

gofer rule NUMBER LOCAL_UNEMPLOYMENT_RATE {} {
    typemethod construct {} {
        return [$type validate [dict create]]
    }

    typemethod validate {gdict} {
        dict create
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "local_unemp()"
    }

    typemethod eval {gdict} {
        dict with gdict {}
        
        # NEXT, query the total of unemployed ppl belonging
        # to ALL nbhoods JOINED with nbhoods that are local
        set unemp [rdb onecolumn "
            SELECT sum(demog_n.unemployed)
            FROM demog_n INNER JOIN nbhoods
            ON demog_n.n = nbhoods.n
            WHERE nbhoods.local
        "]
        
        # NEXT, if in setup unemp will be "", need to set to 0.00
        # Otherwise we cast it to a double to be sure the division
        # done later will keep it's precision.
        if {$unemp == ""} {
            set unemp 0.00
        } else {
            set unemp [expr { double($unemp) }]
        }

        # NEXT, query the total number of the labor force belonging
        # to ALL nbhoods JOINED with nbhoods that are local
        set labfrc [rdb onecolumn "
            SELECT sum(demog_n.labor_force)
            FROM demog_n INNER JOIN nbhoods
            ON demog_n.n = nbhoods.n
            WHERE nbhoods.local
        "]

        # NEXT, if in setup labfrc is "" or 0, we cannot divide by 0
        # so we just return 0.00
        if {$labfrc == "" || $labfrc == 0} {
            return 0.00
        }

        # NEXT, divide the unemployment total by the 
        # labor force total to get the weighted average.
        set urate [expr { 100*($unemp/$labfrc) }]
            
        return [format %.2f $urate]
    }
}

# Rule: LOCAL_WORKERS
#
# local_workers()

gofer rule NUMBER LOCAL_WORKERS {} {
    typemethod construct {} {
        return [$type validate [dict create]]
    }

    typemethod validate {gdict} {
        dict create
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "local_workers()"
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # NEXT, query the total of workers
        set count [rdb onecolumn "
            SELECT labor_force
            FROM demog_local
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: MOBILIZED
#
# mobilized(g,...)

gofer rule NUMBER MOBILIZED {glist} {
    typemethod construct {glist} {
        return [$type validate [dict create glist $glist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create \
            glist [listval fogs {::ptype fog validate} [string toupper $glist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {mobilized("%s")} [join $glist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $glist ',']')"

        # NEXT, query the total of mobilized belonging to
        # the group in the nbhoods in the nbhood list.
        set count [rdb onecolumn "
            SELECT sum(personnel) 
            FROM personnel_g
            WHERE g IN $inClause
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: MOOD
#
# mood(g)

gofer rule NUMBER MOOD {g} {
    typemethod construct {g} {
        return [$type validate [dict create g $g]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create g [civgroup validate [string toupper $g]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {mood("%s")} $g]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT mood FROM uram_mood WHERE g=$g
        } {
            return [format %.1f $mood]
        }

        return 0.0
    }
}

# Rule: NBCONSUMERS
#
# nbconsumers(n,...)

gofer rule NUMBER NBCONSUMERS {nlist} {
    typemethod construct {nlist} {
        return [$type validate [dict create nlist $nlist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create nlist \
            [listval nbhoods {nbhood validate} [string toupper $nlist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {nbconsumers("%s")} [join $nlist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $nlist ',']')"

        # NEXT, query the total of consumers residing in
        # nbhoods in the list.
        set count [rdb onecolumn "
            SELECT sum(consumers) 
            FROM demog_n
            WHERE n IN $inClause
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: NBCOOP
#
# nbcoop(n,g)

gofer rule NUMBER NBCOOP {n g} {
    typemethod construct {n g} {
        return [$type validate [dict create n $n g $g]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            n [nbhood validate [string toupper $n]] \
            g [frcgroup validate [string toupper $g]]

    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {nbcoop("%s","%s")} $n $g]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT nbcoop FROM uram_nbcoop WHERE n=$n AND g=$g
        } {
            return [format %.1f $nbcoop]
        }

        return 50.0
    }
}

# Rule: NB_GOODS_CAP
#
# nbgoodscap(n)

gofer rule NUMBER NB_GOODS_CAP {n} {
    typemethod construct {n} {
        return [$type validate [dict create n $n]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            n [nbhood validate [string toupper $n]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {nbgoodscap("%s")} $n]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        set goodscap [plant capacity n $n]

        if {$goodscap == ""} {
            set goodscap 0.0
        }

        return $goodscap
    }
}

# Rule: NBMOOD
#
# nbmood(n)

gofer rule NUMBER NBMOOD {n} {
    typemethod construct {n} {
        return [$type validate [dict create n $n]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create n [nbhood validate [string toupper $n]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {nbmood("%s")} $n]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT nbmood FROM uram_n WHERE n=$n
        } {
            return [format %.1f $nbmood]
        }

        return 0.0
    }
}

# Rule: NB_PLANTS
#
# nbplants(n)

gofer rule NUMBER NB_PLANTS {n} {
    typemethod construct {n} {
        return [$type validate [dict create n $n]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            n [nbhood validate [string toupper $n]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {nbplants("%s")} $n]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        set nbplants [plant number n $n]

        if {$nbplants == ""} {
            set nbplants 0.0
        }

        return $nbplants
    }
}

# Rule: NBPOPULATION
#
# nbpop(n,...)

gofer rule NUMBER NBPOPULATION {nlist} {
    typemethod construct {nlist} {
        return [$type validate [dict create nlist $nlist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create nlist \
            [listval nbhoods {nbhood validate} [string toupper $nlist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {nbpop("%s")} [join $nlist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $nlist ',']')"

        # NEXT, query the total of population residing in
        # nbhoods in the list.
        set count [rdb onecolumn "
            SELECT sum(population) 
            FROM demog_n
            WHERE n IN $inClause
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: NBSUPPORT
#
# nbsupport(a,n)

gofer rule NUMBER NBSUPPORT {a n} {
    typemethod construct {a n} {
        return [$type validate [dict create a $a n $n]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            a [actor validate [string toupper $a]] \
            n [nbhood validate [string toupper $n]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {nbsupport("%s","%s")} $a $n]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT support FROM influence_na WHERE n=$n AND a=$a
        } {
            return [format %.2f $support]
        }

        return 0.00
    }
}

# Rule: NB_UNEMPLOYMENT_RATE
#
# nbunemp(n,...)

gofer rule NUMBER NB_UNEMPLOYMENT_RATE {nlist} {
    typemethod construct {nlist} {
        return [$type validate [dict create nlist $nlist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create nlist \
            [listval nbhoods {nbhood validate} [string toupper $nlist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {nbunemp("%s")} [join $nlist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}
        
        # FIRST, create the inClause.
        set inClause "('[join $nlist ',']')"
        
        # NEXT, query the total of unemployed ppl belonging
        # to nbhoods in the list JOINED with nbhoods that are local
        set unemp [rdb onecolumn "
            SELECT sum(demog_n.unemployed) 
            FROM demog_n INNER JOIN nbhoods
            ON demog_n.n = nbhoods.n
            WHERE demog_n.n IN $inClause
            AND nbhoods.local
        "]
        
        # NEXT, if in setup unemp will be "", need to set to 0.00
        # Otherwise we cast it to a double to be sure the division
        # done later will keep it's precision.
        if {$unemp == ""} {
            set unemp 0.00
        } else {
            set unemp [expr { double($unemp) }]
        }

        # NEXT, query the total number of the labor force belonging
        # to nbhoods in the list JOINED with nbhoods that are local
        set labfrc [rdb onecolumn "
            SELECT sum(demog_n.labor_force)
            FROM demog_n INNER JOIN nbhoods
            ON demog_n.n = nbhoods.n
            WHERE demog_n.n IN $inClause
            AND nbhoods.local
        "]
        
        # NEXT, if in setup labfrc is "" or 0, we cannot divide by 0
        # so we just return 0.00
        if {$labfrc == "" || $labfrc == 0} {
            return 0.00
        }

        # NEXT, divide the unemployment total by the 
        # labor force total to get the weighted average.
        set urate [expr { 100*($unemp/$labfrc) }]
            
        return [format %.2f $urate]
    }
}

# Rule: NBWORKERS
#
# nbworkers(n,...)

gofer rule NUMBER NBWORKERS {nlist} {
    typemethod construct {nlist} {
        return [$type validate [dict create nlist $nlist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create nlist \
            [listval nbhoods {nbhood validate} [string toupper $nlist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {nbworkers("%s")} [join $nlist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $nlist ',']')"

        # NEXT, query the total of workers residing in
        # nbhoods in the list.
        set count [rdb onecolumn "
            SELECT sum(labor_force) 
            FROM demog_n
            WHERE n IN $inClause
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: CASH_ON_HAND
#
# onhand(a)

gofer rule NUMBER CASH_ON_HAND {a} {
    typemethod construct {a} {
        return [$type validate [dict create a $a]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            a [actor validate [string toupper $a]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {onhand("%s")} $a]
    }

    typemethod eval {gdict} {
        if {[econ state] eq "DISABLED"} {
            # IF econ disabled return 0.00
            return 0.00
        } elseif {![sim locked]} {
            # If the scenario is NOT locked, return 0.00
            return 0.00
        } else {
            dict with gdict {}
            
            set onhand [cash onhand $a]
            
            if {$onhand == ""} {
                set onhand 0.00
            }
            
            return [format %.2f $onhand]
        }
    }
}

# Rule: PLAYBOX_CONSUMERS
#
# pbconsumers()

gofer rule NUMBER PLAYBOX_CONSUMERS {} {
    typemethod construct {} {
        return [$type validate [dict create]]
    }

    typemethod validate {gdict} {
        dict create
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "pbconsumers()"
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # NEXT, query the total of consumers
        set count [rdb onecolumn "
            SELECT sum(consumers)
            FROM demog_local
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: PLAYBOX_GOODS_CAP
#
# pbgoodscap()

gofer rule NUMBER PLAYBOX_GOODS_CAP {} {
    typemethod construct {} {
        return [$type validate [dict create]]
    }

    typemethod validate {gdict} {
        dict create
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "pbgoodscap()"
    }

    typemethod eval {gdict} {
        dict with gdict {}

        set goodscap [plant capacity total]

        if {$goodscap == ""} {
            set goodscap 0.0
        }

        return $goodscap
    }
}

# Rule: PLAYBOX_PLANTS
#
# pbplants()

gofer rule NUMBER PLAYBOX_PLANTS {} {
    typemethod construct {} {
        return [$type validate [dict create]]
    }

    typemethod validate {gdict} {
        dict create
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "pbplants()"
    }

    typemethod eval {gdict} {
        dict with gdict {}

        set plants [plant number total]

        if {$plants == ""} {
            set plants 0.0
        }

        return $plants
    }
}

# Rule: PLAYBOX_POPULATION
#
# pbpop()

gofer rule NUMBER PLAYBOX_POPULATION {} {
    typemethod construct {} {
        return [$type validate [dict create]]
    }

    typemethod validate {gdict} {
        dict create
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "pbpop()"
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # NEXT, query the total of population
        set count [rdb onecolumn "
            SELECT sum(population)
            FROM demog_n
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: PLAYBOX_UNEMPLOYMENT_RATE
#
# pbunemp()

gofer rule NUMBER PLAYBOX_UNEMPLOYMENT_RATE {} {
    typemethod construct {} {
        return [$type validate [dict create]]
    }

    typemethod validate {gdict} {
        dict create
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "pbunemp()"
    }

    typemethod eval {gdict} {
        dict with gdict {}
        
        # NEXT, query the total of unemployed ppl belonging
        # to ALL nbhoods JOINED with nbhoods that are local
        set unemp [rdb onecolumn "
            SELECT sum(demog_n.unemployed)
            FROM demog_n INNER JOIN nbhoods
            ON demog_n.n = nbhoods.n
            WHERE nbhoods.local
        "]
        
        # NEXT, if in setup unemp will be "", need to set to 0.00
        # Otherwise we cast it to a double to be sure the division
        # done later will keep it's precision.
        if {$unemp == ""} {
            set unemp 0.00
        } else {
            set unemp [expr { double($unemp) }]
        }

        # NEXT, query the total number of the labor force belonging
        # to ALL nbhoods JOINED with nbhoods that are local
        set labfrc [rdb onecolumn "
            SELECT sum(demog_n.labor_force)
            FROM demog_n INNER JOIN nbhoods
            ON demog_n.n = nbhoods.n
            WHERE nbhoods.local
        "]

        # NEXT, if in setup labfrc is "" or 0, we cannot divide by 0
        # so we just return 0.00
        if {$labfrc == "" || $labfrc == 0} {
            return 0.00
        }

        # NEXT, divide the unemployment total by the 
        # labor force total to get the weighted average.
        set urate [expr { 100*($unemp/$labfrc) }]
            
        return [format %.2f $urate]
    }
}

# Rule: PLAYBOX_WORKERS
#
# pbworkers()

gofer rule NUMBER PLAYBOX_WORKERS {} {
    typemethod construct {} {
        return [$type validate [dict create]]
    }

    typemethod validate {gdict} {
        dict create
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return "pbworkers()"
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # NEXT, query the total of workers
        set count [rdb onecolumn "
            SELECT sum(labor_force)
            FROM demog_local
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: PCTCONTROL
#
# pctcontrol(a,...)

gofer rule NUMBER PCTCONTROL {alist} {
    typemethod construct {alist} {
        return [$type validate [dict create alist $alist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create alist \
            [listval actors {actor validate} [string toupper $alist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {pctcontrol("%s")} [join $alist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $alist ',']')"

        # NEXT, query the number of neighborhoods controlled by
        # actors in the list.
        set count [rdb onecolumn "
            SELECT count(n) 
            FROM control_n
            WHERE controller IN $inClause
        "]

        set total [llength [nbhood names]]

        if {$total == 0.0} {
            return 0.0
        }

        return [expr {100.0*$count/$total}]
    }
}

# Rule: PLANTS
#
# plants(a,n)

gofer rule NUMBER PLANTS {a n} {
    typemethod construct {a n} {
        return [$type validate [dict create a $a n $n]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            a [agent validate [string toupper $a]] \
            n [nbhood validate [string toupper $n]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {plants("%s","%s")} $a $n]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        set plants [plant get "$n $a" num]

        if {$plants == ""} {
            set plants 0.0
        }

        return $plants
    }
}

# Rule: GROUP_POPULATION
#
# pop(g,...)

gofer rule NUMBER GROUP_POPULATION {glist} {
    typemethod construct {glist} {
        return [$type validate [dict create glist $glist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create glist \
            [listval civgroups {civgroup validate} [string toupper $glist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {pop("%s")} [join $glist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $glist ',']')"

        # NEXT, query the total of population belonging to
        # groups in the list.
        set count [rdb onecolumn "
            SELECT SUM(population) 
            FROM demog_g
            WHERE g IN $inClause
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}

# Rule: REPAIR
#
# repair(a,n)

gofer rule NUMBER REPAIR {a n} {
    typemethod construct {a n} {
        return [$type validate [dict create a $a n $n]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            a [actor validate [string toupper $a]] \
            n [nbhood validate [string toupper $n]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {repair("%s","%s")} $a $n]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        set repair [plant get "$n $a" rho]

        if {$repair == ""} {
            set repair 0.0
        }

        return $repair
    }
}

# Rule: CASH_RESERVE
#
# reserve(a)

gofer rule NUMBER CASH_RESERVE {a} {
    typemethod construct {a} {
        return [$type validate [dict create a $a]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            a [actor validate [string toupper $a]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {reserve("%s")} $a]
    }

    typemethod eval {gdict} {
        if {[econ state] eq "DISABLED"} {
            # IF econ disabled return 0.00
            return 0.00
        } elseif {![sim locked]} {
            # If the scenario is NOT locked, return 0.00
            return 0.00
        } else {
            dict with gdict {}
            
            set reserve [cash reserve $a]
            
            if {$reserve == ""} {
                set reserve 0.00
            }
            
            return [format %.2f $reserve]
        }
    }
}

#
# Rule: SAT
#
# sat(g,c)

gofer rule NUMBER SAT {g c} {
    typemethod construct {g c} {
        return [$type validate [dict create g $g c $c]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            g [civgroup validate [string toupper $g]] \
            c [econcern validate [string toupper $c]]

    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {sat("%s","%s")} $g $c]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT sat FROM uram_sat WHERE g=$g AND c=$c
        } {
            return [format %.1f $sat]
        }

        return 0.0
    }
}

#
# Rule: SECURITY_CIV
#
# security(g)

gofer rule NUMBER SECURITY_CIV {g} {
    typemethod construct {g} {
        return [$type validate [dict create g $g]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            g [civgroup validate [string toupper $g]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {security("%s")} $g]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        set n [rdb eval {
            SELECT n FROM civgroups WHERE g=$g
        }]
        rdb eval {
            SELECT security FROM force_ng WHERE n=$n AND g=$g
        } {
            return $security
        }

        return 0
    }
}
#
# Rule: SECURITY
#
# security(g,n)

gofer rule NUMBER SECURITY {g n} {
    typemethod construct {g n} {
        return [$type validate [dict create g $g n $n]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            g [group validate [string toupper $g]] \
            n [nbhood validate [string toupper $n]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {security("%s","%s")} $g $n]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT security FROM force_ng WHERE n=$n AND g=$g
        } {
            return $security
        }

        return 0
    }
}

# Rule: SUPPORT_CIV
#
# support(a,g)

gofer rule NUMBER SUPPORT_CIV {a g} {
    typemethod construct {a g} {
        return [$type validate [dict create a $a g $g]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            a [actor validate [string toupper $a]] \
            g [civgroup validate [string toupper $g]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {support("%s","%s")} $a $g]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT support FROM support_nga WHERE g=$g AND a=$a
        } {
            return [format %.2f $support]
        }

        return 0.00
    }
}

# Rule: SUPPORT
#
# support(a,g,n)

gofer rule NUMBER SUPPORT {a g n} {
    typemethod construct {a g n} {
        return [$type validate [dict create a $a g $g n $n]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            a [actor validate [string toupper $a]] \
            g [group validate [string toupper $g]] \
            n [nbhood validate [string toupper $n]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {support("%s","%s","%s")} $a $g $n]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT support FROM support_nga WHERE n=$n AND g=$g AND a=$a
        } {
            return [format %.2f $support]
        }

        return 0.00
    }
}

# Rule: GROUP_UNEMPLOYMENT_RATE
#
# unemp(g,...)

gofer rule NUMBER GROUP_UNEMPLOYMENT_RATE {glist} {
    typemethod construct {glist} {
        return [$type validate [dict create glist $glist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create glist \
            [listval civgroups {civgroup validate} [string toupper $glist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {unemp("%s")} [join $glist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}
        
        # FIRST, create the inClause.
        set inClause "('[join $glist ',']')"
        
        # NEXT, query the total number of unemployed ppl belonging
        # to groups in the list JOINED with local_civgroups
        set unemp [rdb onecolumn "
            SELECT sum(demog_g.unemployed)
            FROM demog_g INNER JOIN local_civgroups
            ON demog_g.g = local_civgroups.g
            WHERE demog_g.g IN $inClause
        "]

        # NEXT, if in setup unemp will be "", need to set to 0.00
        # Otherwise we cast it to a double to be sure the division
        # done later will keep it's precision.
        if {$unemp == "" || $unemp == 0} {
            set unemp 0.00
        } else {
            set unemp [expr { double($unemp) }]
        }
        
        # NEXT, query the total number of the labor force belonging
        # to groups in the list JOINED with local_civgroups
        set labfrc [rdb onecolumn "
            SELECT sum(demog_g.labor_force)
            FROM demog_g INNER JOIN local_civgroups
            ON demog_g.g = local_civgroups.g
            WHERE demog_g.g IN $inClause
        "]

        # NEXT, if in setup labfrc is "" or 0, we cannot divide by 0
        # so we just return 0.00
        if {$labfrc == "" || $labfrc == 0} {
            return 0.00
        }

        # NEXT, divide the unemployment total by the 
        # labor force total to get the weighted average.
        set urate [expr { 100*($unemp/$labfrc) }]
            
        return [format %.2f $urate]
    }
}

# Rule: VREL
#
# vrel(g,a)

gofer rule NUMBER VREL {g a} {
    typemethod construct {g a} {
        return [$type validate [dict create g $g a $a]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create \
            g [group validate [string toupper $g]] \
            a [actor validate [string toupper $a]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {vrel("%s","%s")} $g $a]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        rdb eval {
            SELECT vrel FROM uram_vrel WHERE g=$g AND a=$a AND tracked
        } {
            return [format %.1f $vrel]
        }

        return 0.0
    }
}

# Rule: GROUP_WORKERS
#
# workers(g,...)

gofer rule NUMBER GROUP_WORKERS {glist} {
    typemethod construct {glist} {
        return [$type validate [dict create glist $glist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}
        dict create glist \
            [listval civgroups {civgroup validate} [string toupper $glist]]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [format {workers("%s")} [join $glist \",\"]]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        # FIRST, create the inClause.
        set inClause "('[join $glist ',']')"

        # NEXT, query the total of workers belonging to
        # groups in the list.
        set count [rdb onecolumn "
            SELECT sum(labor_force) 
            FROM demog_g
            WHERE g IN $inClause
        "]

        if {$count == ""} {
            return 0
        } else {
            return $count
        }
    }
}
