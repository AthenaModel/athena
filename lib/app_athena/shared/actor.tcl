#-----------------------------------------------------------------------
# TITLE:
#    actor.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Actor Manager
#
#    This module is responsible for managing political actors and operations
#    upon them.  As such, it is a type ensemble.
#
#-----------------------------------------------------------------------

snit::type actor {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # names
    #
    # Returns the list of actor names

    typemethod names {} {
        set names [rdb eval {
            SELECT a FROM actors
        }]
    }


    # namedict
    #
    # Returns the dict of actor names/longnames

    typemethod namedict {} {
        return [rdb eval {
            SELECT a, longname FROM actors
        }]
    }

    # validate a
    #
    # a - Possibly, an actor short name.
    #
    # Validates an actor short name

    typemethod validate {a} {
        set names [$type names]

        if {$a ni $names} {
            set nameString [join $names ", "]

            if {$nameString ne ""} {
                set msg "should be one of: $nameString"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid actor, $msg"
        }

        return $a
    }

    # get a ?parm?
    #
    # a    - An actor
    # parm - A actors column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # actors.

    typemethod get {a {parm ""}} {
        # FIRST, get the data
        rdb eval {SELECT * FROM actors WHERE a=$a} row {
            if {$parm ne ""} {
                return $row($parm)
            } else {
                unset row(*)
                return [array get row]
            }
        }

        return ""
    }

    # frcgroups a 
    #
    # a - An actor
    #
    # Returns a list of the force groups owned by the actor.
    
    typemethod frcgroups {a} {
        rdb eval {SELECT g FROM frcgroups_view WHERE a=$a}
    }

    # income a
    #
    # a - An actor
    #
    # Returns the actor's most recent income.  For INCOME actors,
    # the income is from income_a, if available, or from the income_*
    # inputs.  For BUDGET actors, the income is as budgeted.

    typemethod income {a} {
        return [rdb onecolumn {
            SELECT income FROM actors_view WHERE a=$a
        }]
    }

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.

    # mutate create parmdict
    #
    # parmdict     A dictionary of actor parms
    #
    #    a                 The actor's ID
    #    longname          The actor's long name
    #    bsid              Belief System ID
    #    supports          Actor name, SELF, or NONE.
    #    atype             Actor type, INCOME or BUDGET
    #    cash_reserve      Cash reserve (starting balance)
    #    cash_on_hand      Cash-on-hand (starting balance)
    #    income_goods      Income from "goods" sector, $/week
    #    shares_black_nr   Income, shares of net revenues from "black" sector
    #    income_black_tax  Income, "taxes" on "black" sector, $/week
    #    income_pop        Income from "pop" sector, $/week
    #    income_graft      Income, graft on foreign aid to "region", $/week
    #    income_world      Income from "world" sector, $/week
    #    budget            Actor's budget, $/week
    #
    # Creates an actor given the parms, which are presumed to be
    # valid.

    typemethod {mutate create} {parmdict} {
        # FIRST, prepare to undo.
        set undo [list]

        # NEXT, clear irrelevant fields.
        set parmdict [ClearIrrelevantFields $parmdict]
        
        # NEXT, create the actor.
        dict with parmdict {
            # FIRST, get the "supports" actor
            if {$supports eq "SELF"} {
                set supports $a
            }

            # FIRST, Put the actor in the database
            rdb eval {
                INSERT INTO 
                actors(a,  
                       longname,
                       bsid,  
                       supports, 
                       atype,
                       auto_maintain,
                       cash_reserve, 
                       cash_on_hand,
                       income_goods, 
                       shares_black_nr, 
                       income_black_tax, 
                       income_pop, 
                       income_graft,
                       income_world,
                       budget)
                VALUES($a, 
                       $longname,
                       $bsid, 
                       nullif($supports, 'NONE'),
                       $atype,
                       $auto_maintain,
                       $cash_reserve,
                       $cash_on_hand,
                       $income_goods, 
                       $shares_black_nr,
                       $income_black_tax,
                       $income_pop,
                       $income_graft,
                       $income_world,
                       $budget);
            }

            # NEXT, create the related entities
            lappend undo [strategy create_ $a]

            # NEXT, Return undo command.
            lappend undo [list rdb delete actors "a='$a'"]

            return [join $undo \n]
        }
    }

    # mutate delete a
    #
    # a     An actor short name
    #
    # Deletes the actor.

    typemethod {mutate delete} {a} {
        set undo [list]

        # FIRST, get the undo information
        set gdata [rdb grab \
                       groups    {a=$a}                   \
                       caps      {owner=$a}               \
                       actors    {a != $a AND supports=$a}]
        
        set adata [rdb delete -grab actors {a=$a}]

        
        # NEXT, delete the related entities
        lappend undo [strategy delete_ $a]
        lappend undo [list rdb ungrab [concat $adata $gdata]]

        return [join $undo \n]
    }


    # mutate update parmdict
    #
    # parmdict     A dictionary of actor parms
    #
    #    a                  An actor short name
    #    longname           A new long name, or ""
    #    bsid               A new belief system ID, or ""
    #    supports           A new supports (SELF, NONE, actor), or ""
    #    atype              A new actor type, or ""
    #    cash_reserve       A new reserve amount, or ""
    #    cash_on_hand       A new cash-on-hand amount, or ""
    #    income_goods       A new income, or ""
    #    shares_black_nr    A new share of revenue, or ""
    #    income_black_tax   A new income, or ""
    #    income_pop         A new income, or ""
    #    income_graft       A new income, or ""
    #    income_world       A new income, or ""
    #    budget             A new budget, or ""
    #
    # Updates a actor given the parms, which are presumed to be
    # valid.

    typemethod {mutate update} {parmdict} {
        # FIRST, clear irrelevant fields.
        set parmdict [ClearIrrelevantFields $parmdict]
        
        # NEXT, save the changes.
        dict with parmdict {
            # FIRST, get the undo information
            set data [rdb grab actors {a=$a}]

            # NEXT, handle SELF
            if {$supports eq "SELF"} {
                set supports $a
            }

            # NEXT, Update the actor
            rdb eval {
                UPDATE actors
                SET longname      = nonempty($longname,      longname),
                    bsid          = nonempty($bsid,          bsid),
                    supports      = nullif(nonempty($supports,supports),'NONE'),
                    atype         = nonempty($atype,         atype),
                    auto_maintain = nonempty($auto_maintain, auto_maintain),
                    cash_reserve  = nonempty($cash_reserve,  cash_reserve),
                    cash_on_hand  = nonempty($cash_on_hand,  cash_on_hand),
                    income_goods  = nonempty($income_goods,  income_goods),
                    shares_black_nr  = 
                        nonempty($shares_black_nr,  shares_black_nr),
                    income_black_tax = 
                        nonempty($income_black_tax, income_black_tax),
                    income_pop    = nonempty($income_pop,    income_pop),
                    income_graft  = nonempty($income_graft,  income_graft),
                    income_world  = nonempty($income_world,  income_world),
                    budget        = nonempty($budget,        budget)
                WHERE a=$a;
            } {}

            # NEXT, Return the undo command
            return [list rdb ungrab $data]
        }
    }

    # ClearIrrelevantFields parmdict
    #
    # parmdict - A [mutate create] or [mutate update] dictionary.
    #
    # Clears fields to zero if they are irrelevant for the funding
    # type.
    proc ClearIrrelevantFields {parmdict} {
        if {![dict exists $parmdict atype]} {
            dict set parmdict atype ""
        }

        if {![dict exists $parmdict supports]} {
            dict set parmdict supports ""
        }

        dict with parmdict {       
            # FIRST, if atype is empty retrieve it.
            if {$atype eq ""} {
                set atype [actor get $a atype]
            }
            
            # NEXT, fix up the fields based on funding type.
            if {$atype eq "INCOME"} {
                let budget           0.0
            } else {
                let cash_reserve     0.0
                let cash_on_hand     0.0
                let income_goods     0.0
                let shares_black_nr  0.0
                let income_black_tax 0.0
                let income_pop       0.0
                let income_graft     0.0
                let income_world     0.0
            }
        }
    
        return $parmdict
    }
}

#-----------------------------------------------------------------------
# Orders: ACTOR:*

# ACTOR:CREATE
#
# Creates new actors.

myorders define ACTOR:CREATE {
    meta title "Create Actor"

    meta sendstates PREP

    meta defaults {
        a                ""
        longname         ""
        bsid             1
        supports         SELF
        auto_maintain    0
        atype            INCOME
        cash_reserve     0
        cash_on_hand     0
        income_goods     0
        shares_black_nr  0
        income_black_tax 0
        income_pop       0
        income_graft     0
        income_world     0
        budget           0
    }

    meta form {
        rcc "Actor:" -for a
        text a
        
        rcc "Long Name:" -for longname
        longname longname

        rcc "Belief System:" -for bsid
        enumlong bsid -dictcmd {::bsys system namedict} -showkeys yes \
            -defvalue 1

        rcc "Supports:" -for supports
        enum supports -defvalue SELF -listcmd {ptype a+self+none names}

        rcc "Auto-maintain Infrastructure?" -for auto_maintain
        yesno auto_maintain -defvalue 0

        rcc "Funding Type:" -for atype
        selector atype -defvalue INCOME {
            case INCOME "Actor gets weekly income from local economy" {
                rcc "Cash Reserve:" -for cash_reserve
                text cash_reserve -defvalue 0
                label "$"
        
                rcc "Cash On Hand:" -for cash_on_hand
                text cash_on_hand -defvalue 0
                label "$"
        
                rcc "Income, GOODS Sector:" -for income_goods
                text income_goods -defvalue 0
                label "$/week"
        
                rcc "Income, BLACK Profits:" -for shares_black_nr
                text shares_black_nr -defvalue 0
                label "shares"
        
                rcc "Income, BLACK Taxes:" -for income_black_tax
                text income_black_tax -defvalue 0
                label "$/week"
        
                rcc "Income, POP Sector:" -for income_pop
                text income_pop -defvalue 0
                label "$/week"
        
                rcc "Income, Graft on FA:" -for income_graft
                text income_graft -defvalue 0
                label "$/week"
        
                rcc "Income, WORLD Sector:" -for income_world
                text income_world -defvalue 0
                label "$/week"
            }
            case BUDGET "Actor gets weekly budget from foreign source" {
                rcc "Weekly Budget:       " -for budget
                text budget -defvalue 0
                label "$/week"
            }
        }
    }


    method _validate {} {

        # FIRST, prepare and validate the parameters
        my prepare a                -toupper -required -type ident
        my unused a
        my prepare longname         -normalize
        my prepare bsid             -num               -type {bsys system}
        my prepare supports         -toupper           -type {ptype a+self+none}
        my prepare auto_maintain    -toupper           -type boolean 
        my prepare atype            -toupper           -selector
        my prepare cash_reserve     -toupper           -type money
        my prepare cash_on_hand     -toupper           -type money
        my prepare income_goods     -toupper           -type money
        my prepare shares_black_nr  -num               -type iquantity
        my prepare income_black_tax -toupper           -type money
        my prepare income_pop       -toupper           -type money
        my prepare income_graft     -toupper           -type money
        my prepare income_world     -toupper           -type money
        my prepare budget           -toupper           -type money
    }

    method _execute {{flunky ""}} {
        # NEXT, If longname is "", defaults to ID.
        if {$parms(longname) eq ""} {
            set parms(longname) $parms(a)
        }
    
        # NEXT, if bsys is "", defaults to 1 (neutral)
        if {$parms(bsid) eq ""} {
            set parms(bsid) 1
        }
    
        # NEXT, if supports is "", defaults to SELF
        if {$parms(supports) eq ""} {
            set parms(supports) "SELF"
        }
        
        # NEXT, create the actor
        my setundo [actor mutate create [array get parms]]
    }
}

# ACTOR:DELETE

myorders define ACTOR:DELETE {
    meta title "Delete Actor"
    meta sendstates PREP

    meta defaults {
        a ""
    }

    meta form {
        rcc "Actor:" -for a
        actor a
    }

    method _validate {} {
        # FIRST, prepare the parameters
        my prepare a -toupper -required -type actor
    }

    method _execute {{flunky ""}} {
        if {[my mode] eq "gui"} {
            set answer [messagebox popup \
                            -title         "Are you sure?"                  \
                            -icon          warning                          \
                            -buttons       {ok "Delete it" cancel "Cancel"} \
                            -default       cancel                           \
                            -onclose       cancel                           \
                            -ignoretag     ACTOR:DELETE                     \
                            -ignoredefault ok                               \
                            -parent        [app topwin]                     \
                            -message       [normalize {
                                Are you sure you
                                really want to delete this actor and all of the
                                entities that depend upon it?
                            }]]
    
            if {$answer eq "cancel"} {
                my cancel
            }
        }

        # NEXT, Delete the actor and dependent entities
        lappend undo 
    
        my setundo [actor mutate delete $parms(a)]
    }
}

# ACTOR:UPDATE
#
# Updates existing actors.

myorders define ACTOR:UPDATE {
    meta title "Update Actor"
    meta sendstates PREP

    meta defaults {
        a                ""
        longname         ""
        bsid             ""
        supports         ""
        auto_maintain    ""
        atype            ""
        cash_reserve     ""
        cash_on_hand     ""
        income_goods     ""
        shares_black_nr  ""
        income_black_tax ""
        income_pop       ""
        income_graft     ""
        income_world     ""
        budget           ""
    }

    meta form {
        # Use explicit width so that long labels don't wrap.  Ugh!
        rc "Select Actor:" -for a -width 2in
        c
        dbkey a -table gui_actors -keys a \
            -loadcmd {$order_ keyload a *} 
        
        rcc "Long Name:" -for longname
        longname longname

        rcc "Belief System:" -for bsid
        enumlong bsid -dictcmd {::bsys system namedict} -showkeys yes \

        rcc "Supports:" -for supports
        enum supports -listcmd {ptype a+self+none names}

        rcc "Auto-maintain Infrastructure?" -for auto_maintain
        yesno auto_maintain 

        rcc "Funding Type:" -for atype
        selector atype {
            case INCOME "Actor gets weekly income from local economy" {
                rcc "Cash Reserve:" -for cash_reserve 
                text cash_reserve
                label "$"
        
                rcc "Cash On Hand:" -for cash_on_hand
                text cash_on_hand
                label "$"
        
                rcc "Income, GOODS Sector:" -for income_goods
                text income_goods
                label "$/week"
        
                rcc "Income, BLACK Profits:" -for shares_black_nr
                text shares_black_nr
                label "shares"
        
                rcc "Income, BLACK Taxes:" -for income_black_tax
                text income_black_tax
                label "$/week"
        
                rcc "Income, POP Sector:" -for income_pop
                text income_pop
                label "$/week"
        
                rcc "Income, Graft on FA:" -for income_graft
                text income_graft
                label "$/week"
        
                rcc "Income, WORLD Sector:" -for income_world
                text income_world
                label "$/week"
            }
            case BUDGET "Actor gets weekly budget from foreign source" {
                rcc "Weekly Budget:       " -for budget
                text budget
                label "$/week"
            }
        }
    }


    method _validate {} {
        my prepare a                -toupper   -required -type actor
        my prepare longname         -normalize
        my prepare bsid             -num               -type {bsys system}
        my prepare supports         -toupper           -type {ptype a+self+none}
        my prepare auto_maintain    -toupper           -type boolean 
        my prepare atype            -toupper           -selector
        my prepare cash_reserve     -toupper           -type money
        my prepare cash_on_hand     -toupper           -type money
        my prepare income_goods     -toupper           -type money
        my prepare shares_black_nr  -num               -type iquantity
        my prepare income_black_tax -toupper           -type money
        my prepare income_pop       -toupper           -type money
        my prepare income_graft     -toupper           -type money
        my prepare income_world     -toupper           -type money
        my prepare budget           -toupper           -type money
    }

    method _execute {{flunky ""}} {
        my setundo [actor mutate update [array get parms]]
    }
}

# ACTOR:INCOME
#
# Updates existing actor's income or budget.  Does not
# allow changing the actor's type.

myorders define ACTOR:INCOME {
    meta title "Update Actor Income"
    meta sendstates {PREP PAUSED TACTIC}

    meta defaults {
        a                ""
        atype            ""
        income_goods     ""
        shares_black_nr  ""
        income_black_tax ""
        income_pop       ""
        income_graft     ""
        income_world     ""
        budget           ""
    }

    meta form {
        rcc "Select Actor:" -for a
        dbkey a -table gui_actors -keys a \
            -loadcmd {$order_ keyload a *} 

        selector atype -invisible yes {
            case INCOME "Actor gets weekly income from local economy" {
                rcc "Income, GOODS Sector:" -for income_goods
                text income_goods
                label "$/week"
        
                rcc "Income, BLACK Profits:" -for shares_black_nr
                text shares_black_nr
                label "shares"
        
                rcc "Income, BLACK Taxes:" -for income_black_tax
                text income_black_tax
                label "$/week"
        
                rcc "Income, POP Sector:" -for income_pop
                text income_pop
                label "$/week"
        
                rcc "Income, Graft on FA:" -for income_graft
                text income_graft
                label "$/week"
        
                rcc "Income, WORLD Sector:" -for income_world
                text income_world
                label "$/week"
            }
            case BUDGET "Actor gets weekly budget from foreign source" {
                rcc "Weekly Budget:       " -for budget
                text budget
                label "$/week"
            }
        }
    }


    method _validate {} {
        set parms(atype) ""
        
        my prepare a                -toupper   -required -type actor
        my prepare income_goods     -toupper             -type money
        my prepare shares_black_nr  -num                 -type iquantity
        my prepare income_black_tax -toupper             -type money
        my prepare income_pop       -toupper             -type money
        my prepare income_graft     -toupper             -type money
        my prepare income_world     -toupper             -type money
        my prepare budget           -toupper             -type money
    }

    method _execute {{flunky ""}} {
        # FIRST, fill in the empty parameters
        array set parms {
            auto_maintain {}
            longname      {}
            supports      {}
            cash_reserve  {}
            cash_on_hand  {}
        }
    
        # NEXT, modify the actor
        my setundo [actor mutate update [array get parms]]
    }
}

# ACTOR:SUPPORTS
#
# Updates existing actor's "supports" attribute.

myorders define ACTOR:SUPPORTS {
    meta title "Update Actor Supports"
    meta sendstates {PREP PAUSED TACTICS}

    meta defaults {
        a        ""
        supports ""
    }

    meta form {
        rcc "Select Actor:" -for a
        dbkey a -table gui_actors -keys a \
            -loadcmd {$order_ keyload a *} 
        
        rcc "Supports:" -for supports
        enum supports -listcmd {ptype a+self+none names}
    }

    method _validate {} {
        my prepare a            -toupper   -required -type actor
        my prepare supports     -toupper   -required -type {ptype a+self+none}
    }

    method _execute {{flunky ""}} {
        # FIRST, fill in the empty parameters
        array set parms {
            longname         {}
            atype            {}
            auto_maintain    {}
            cash_reserve     {}
            cash_on_hand     {}
            income_goods     {}
            shares_black_nr  {}
            income_black_tax {}
            income_pop       {}
            income_graft     {}
            income_world     {}
            budget           {}
        }
    
        # NEXT, modify the actor
        my setundo [actor mutate update [array get parms]]
    }
}


