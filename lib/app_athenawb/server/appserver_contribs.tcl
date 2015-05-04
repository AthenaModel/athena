#-----------------------------------------------------------------------
# TITLE:
#    appserver_contribs.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Contributions to Attitude Curves
#
#    /app/contribs/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module CONTRIBS {
    #-------------------------------------------------------------------
    # Look up tables

    # Limit values

    typevariable limit -array {
        ALL    0
        TOP5   5
        TOP10  10
        TOP20  20
        TOP50  50
        TOP100 100
    }

    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /contribs {contribs/?}    \
            tcl/linkdict [myproc /contribs:linkdict] \
            text/html [myproc /contribs:html]        \
            "Contributions to attitude curves."

        appserver register /contribs/coop {contribs/coop/?} \
            text/html [myproc /contribs/coop:html]          \
            "Contributions to cooperation curves."

        appserver register /contribs/hrel {contribs/hrel/?} \
            text/html [myproc /contribs/hrel:html]          \
            "Contributions to horizontal relationships."

        appserver register /contribs/mood {contribs/mood/?} \
            text/html [myproc /contribs/mood:html]         \
            "Contributions to civilian group mood."

        appserver register /contribs/nbcoop {contribs/nbcoop/?} \
            text/html [myproc /contribs/nbcoop:html]         \
            "Contributions to neighborhood cooperation."

        appserver register /contribs/nbmood {contribs/nbmood/?} \
            text/html [myproc /contribs/nbmood:html]         \
            "Contributions to neighborhood mood."

        appserver register /contribs/sat {contribs/sat/?} \
            text/html [myproc /contribs/sat:html]         \
            "Contributions to satisfaction curves."

        appserver register /contribs/vrel {contribs/vrel/?} \
            text/html [myproc /contribs/vrel:html]          \
            "Contributions to vertical relationships."
    }

    #-------------------------------------------------------------------
    # /contribs: All defined attitude types.
    #
    # No match parameters

    # /contribs:linkdict udict matchArray
    #
    # Returns a tcl/linkdict of contributions pages

    proc /contribs:linkdict {udict matchArray} {
        return {
            /app/contribs/coop { 
                label "Cooperation" 
                listIcon ::projectgui::icon::heart12
            }
            /app/contribs/hrel { 
                label "Horizontal Relationships" 
                listIcon ::projectgui::icon::heart12
            }
            /app/contribs/mood { 
                label "Group Mood" 
                listIcon ::projectgui::icon::heart12
            }
            /app/contribs/nbcoop { 
                label "Neighborhood Cooperation" 
                listIcon ::projectgui::icon::heart12
            }
            /app/contribs/nbmood { 
                label "Neighborhood Mood" 
                listIcon ::projectgui::icon::heart12
            }
            /app/contribs/sat { 
                label "Satisfaction" 
                listIcon ::projectgui::icon::heart12
            }
            /app/contribs/vrel { 
                label "Vertical Relationships" 
                listIcon ::projectgui::icon::heart12
            }
        }
    }

    # /contribs:html udict matchArray
    #
    # Returns a page that allows the user to drill down to the contributions
    # for a specific kind of attitude curve.

    proc /contribs:html {udict matchArray} {
        ht page "Contributions to Attitude Curves" {
            ht title "Contributions to Attitude Curves"

            ht ul {
                ht li {
                    ht link /app/contribs/coop "Cooperation"
                }

                ht li {
                    ht link /app/contribs/hrel "Horizontal Relationships"
                }

                ht li {
                    ht link /app/contribs/mood "Civilian Group Mood"
                }
                
                ht li {
                    ht link /app/contribs/nbcoop "Neighborhood Cooperation"
                }
                
                ht li {
                    ht link /app/contribs/nbmood "Neighborhood Mood"
                }
                
                ht li {
                    ht link /app/contribs/sat "Satisfaction"
                }
                
                ht li {
                    ht link /app/contribs/vrel "Vertical Relationships"
                }
            }
        }

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /contribs/coop:  All cooperation curves.
    #
    # No match parameters

    # /contribs/coop:html udict matchArray
    #
    # Returns a page that allows the user to see the contributions
    # for a specific cooperation curve for a specific pair of groups during
    # a particular time interval.
    #
    # The udict query is a "parm=value[+parm=value]" string with the
    # following parameters:
    #
    #    f      The civilian group
    #    g      The force group
    #    top    Max number of top contributors to include.
    #    start  Start time in ticks
    #    end    End time in ticks
    #
    # Unknown query parameters and invalid query values are ignored.

    proc /contribs/coop:html {udict matchArray} {
        # FIRST, get the query parameters 
        set qdict [GetQueryParms $udict {f g}]

        # NEXT, bring the query parms into scope
        dict with qdict {}

        # NEXT, get the two groups
        set f [string toupper $f]
        set g [string toupper $g]

        if {![adb civgroup exists $f]} {
            set f "?"
        }

        if {![adb frcgroup exists $g]} {
            set g "?"
        }
        
        # NEXT, begin to format the report
        ht page "Contributions to Cooperation"
        ht title "Contributions to Cooperation"

        # NEXT, if we're not locked we're done.
        if {![locked -disclaimer]} {
            ht /page
            return [ht get]
        }

        # NEXT, insert subtitle, indicating the two groups
        ht subtitle "Of $f with $g"

        # NEXT, insert the control form.
        ht hr
        ht form
        ht label f "Civ. Group:"
        ht input f enum $f -src /app/groups/civ
        ht label g "Frc. Group:"
        ht input g enum $g -src /app/groups/frc
        ht label top "Show:"
        ht input top enum $top -src /app/enum/topitems -content tcl/enumdict
        ht para
        ht label start 
        ht put "Time Interval &mdash; "
        ht link /help/term/timespec.html "From:"
        ht /label
        ht input start text $start -size 12
        ht label end
        ht link /help/term/timespec.html "To:"
        ht /label
        ht input end text $end -size 12
        ht submit
        ht /form
        ht hr
        ht para

        # NEXT, if we don't have the groups, ask for them.
        if {$f eq "?" || $g eq "?"} {
            ht putln "Please select the groups."
            ht /page
            return [ht get]
        }

        # NEXT, format the report header.

        ht ul {
            ht li {
                ht put "Civ. Group: "
                ht put [GroupLongLink $f]
            }
            ht li {
                ht put "Frc. Group: "
                ht put [GroupLongLink $g]
            }
            ht li {
                ht put [TimeWindow $start_ $end_]
            }
        }

        ht para

        # NEXT, insert the plot.
        set vars [list basecoop.$f.$g coop.$f.$g]

        # If the URAM gamma for this attitude is non-zero, include the
        # natural level.
        if {[lindex [adb parm get uram.factors.COOP] 1] > 0.0} {
            lappend vars natcoop.$f.$g
        }

        PutPlot hist.coop $start_ $end_ $vars

        # NEXT, Get the drivers for this time period.
        adb contribs coop $f $g \
            -start $start_       \
            -end   $end_

        # NEXT, output the contribs table.
        PutContribsTable $start_ $end_ $top_

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /contribs/hrel:  All horizontal relationship curves.
    #
    # No match parameters

    # /contribs/hrel:html udict matchArray
    #
    # Returns a page that allows the user to see the contributions
    # for a specific horizontal relationships curve of one group
    # with a second group during a particular time interval.
    #
    # The udict query is a "parm=value[+parm=value]" string with the
    # following parameters:
    #
    #    f      The first group
    #    g      The second group
    #    top    Max number of top contributors to include.
    #    start  Start time in ticks
    #    end    End time in ticks
    #
    # Unknown query parameters and invalid query values are ignored.

    proc /contribs/hrel:html {udict matchArray} {
        # FIRST, get the query parameters 
        set qdict [GetQueryParms $udict {f g}]

        # NEXT, bring the query parms into scope
        dict with qdict {}

        # NEXT, get the groups
        set f [string toupper $f]
        set g [string toupper $g]

        if {![adb group exists $f]} {
            set f "?"
        }

        if {![adb group exists $g]} {
            set g "?"
        }
        
        # NEXT, begin to format the report
        ht page "Contributions to Horizontal Relationship"
        ht title "Contributions to Horizontal Relationship"

        # NEXT, if we're not locked we're done.
        if {![locked -disclaimer]} {
            ht /page
            return [ht get]
        }

        # NEXT, insert subtitle, indicating the two groups
        ht subtitle "Of $f with $g"

        # NEXT, insert the control form.
        ht hr
        ht form
        ht label f "Of Group:"
        ht input f enum $f -src /app/groups
        ht label g "With Group:"
        ht input g enum $g -src /app/groups
        ht label top "Show:"
        ht input top enum $top -src /app/enum/topitems -content tcl/enumdict
        ht para
        ht label start 
        ht put "Time Interval &mdash; "
        ht link /help/term/timespec.html "From:"
        ht /label
        ht input start text $start -size 12
        ht label end
        ht link /help/term/timespec.html "To:"
        ht /label
        ht input end text $end -size 12
        ht submit
        ht /form
        ht hr
        ht para

        # NEXT, if we don't have the groups, ask for them.
        if {$f eq "?" || $g eq "?"} {
            ht putln "Please select the groups."
            ht /page
            return [ht get]
        }

        # NEXT, format the report header.

        ht ul {
            ht li {
                ht put "Of Group: "
                ht put [GroupLongLink $f]
            }
            ht li {
                ht put "With Group: "
                ht put [GroupLongLink $g]
            }
            ht li {
                ht put [TimeWindow $start_ $end_]
            }
        }

        ht para

        # NEXT, insert the plot.
        set vars [list basehrel.$f.$g hrel.$f.$g]

        # If the URAM gamma for this attitude is non-zero, include the
        # natural level.
        if {[lindex [adb parm get uram.factors.HREL] 1] > 0.0} {
            lappend vars nathrel.$f.$g
        }

        PutPlot hist.hrel $start_ $end_ $vars

        # NEXT, Get the drivers for this time period.
        adb contribs hrel $f $g \
            -start $start_       \
            -end   $end_

        # NEXT, output the contribs table.
        PutContribsTable $start_ $end_ $top_

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /contribs/mood:  Contributions to civilian group mood.
    #
    # No match parameters

    # /contribs/mood:html udict matchArray
    #
    # Returns a page that allows the user to see the contributions
    # for a specific group mood curve for a specific group during
    # a particular time interval.
    #
    # The udict query is a "parm=value[+parm=value]" string with the
    # following parameters:
    #
    #    g      The civilian group
    #    top    Max number of top contributors to include.
    #    start  Start time in ticks
    #    end    End time in ticks
    #
    # Unknown query parameters and invalid query values are ignored.

    proc /contribs/mood:html {udict matchArray} {
        # FIRST, get the query parameters 
        set qdict [GetQueryParms $udict {g}]

        # NEXT, bring the query parms into scope
        dict with qdict {}

        # NEXT, get the group
        set g [string toupper $g]

        if {![adb civgroup exists $g]} {
            set g "?"
        }

        # NEXT, begin to format the report
        ht page "Contributions to Group Mood"
        ht title "Contributions to Group Mood"

        # NEXT, if we're not locked we're done.
        if {![locked -disclaimer]} {
            ht /page
            return [ht get]
        }

        # NEXT, insert subtitle, indicating the group
        ht subtitle "Of $g"

        # NEXT, insert the control form.
        ht hr
        ht form
        ht label g "Group:"
        ht input g enum $g -src /app/groups/civ
        ht label top "Show:"
        ht input top enum $top -src /app/enum/topitems -content tcl/enumdict
        ht para
        ht label start 
        ht put "Time Interval &mdash; "
        ht link /help/term/timespec.html "From:"
        ht /label
        ht input start text $start -size 12
        ht label end
        ht link /help/term/timespec.html "To:"
        ht /label
        ht input end text $end -size 12
        ht submit
        ht /form
        ht hr
        ht para

        # NEXT, if we don't have the group, ask for it.
        if {$g eq "?"} {
            ht putln "Please select a group."
            ht /page
            return [ht get]
        }

        # NEXT, format the report header.

        ht ul {
            ht li {
                ht put "Group: "
                ht put [GroupLongLink $g]
            }
            ht li {
                ht put [TimeWindow $start_ $end_]
            }
        }

        ht para

        # NEXT, insert the plot: all four concerns, plus mood.
        set vars [list]
        foreach c [econcern names] {
            lappend vars sat.$g.$c
        }
        lappend vars mood.$g

        PutPlot hist.sat $start_ $end_ $vars

        # NEXT, Get the drivers for this time period.
        adb contribs mood $g \
            -start $start_    \
            -end   $end_

        # NEXT, output the contribs table.
        PutContribsTable $start_ $end_ $top_

        ht /page

        return [ht get]
    }


    #-------------------------------------------------------------------
    # /contribs/nbcoop: Contributions to nbhood cooperation
    #
    # No match parameters

    # /contribs/nbcoop:html udict matchArray
    #
    # Returns a page that allows the user to see the contributions
    # to the cooperation of the residents of a neighborhood with a
    # particular force group during a particular time interval.
    #
    # The udict query is a "parm=value[+parm=value]" string with the
    # following parameters:
    #
    #    n      The neighborhood
    #    g      The force group
    #    top    Max number of top contributors to include.
    #    start  Start time in ticks
    #    end    End time in ticks
    #
    # Unknown query parameters and invalid query values are ignored.

    proc /contribs/nbcoop:html {udict matchArray} {
        # FIRST, get the query parameters 
        set qdict [GetQueryParms $udict {n g}]

        # NEXT, bring the query parms into scope
        dict with qdict {}

        # NEXT, get the indices
        set n [string toupper $n]
        set g [string toupper $g]

        if {![adb nbhood exists $n]} {
            set n "?"
        }

        if {![adb frcgroup exists $g]} {
            set g "?"
        }
        
        # NEXT, begin to format the report
        ht page "Contributions to Neighborhood Cooperation"
        ht title "Contributions to Neighborhood Cooperation"

        # NEXT, if we're not locked we're done.
        if {![locked -disclaimer]} {
            ht /page
            return [ht get]
        }

        # NEXT, insert subtitle, indicating the two indices
        ht subtitle "Of $n with $g"

        # NEXT, insert the control form.
        ht hr
        ht form
        ht label n "Neighborhood:"
        ht input n enum $n -src /app/nbhoods
        ht label g "Frc. Group:"
        ht input g enum $g -src /app/groups/frc
        ht label top "Show:"
        ht input top enum $top -src /app/enum/topitems -content tcl/enumdict
        ht para
        ht label start 
        ht put "Time Interval &mdash; "
        ht link /help/term/timespec.html "From:"
        ht /label
        ht input start text $start -size 12
        ht label end
        ht link /help/term/timespec.html "To:"
        ht /label
        ht input end text $end -size 12
        ht submit
        ht /form
        ht hr
        ht para

        # NEXT, if we don't have the indices, ask for them.
        if {$n eq "?" || $g eq "?"} {
            ht putln "Please select the neighborhood and group."
            ht /page
            return [ht get]
        }

        # NEXT, format the report header.

        ht ul {
            ht li {
                ht put "Neighborhood: "
                ht put [NbhoodLongLink $n]
            }
            ht li {
                ht put "Frc. Group: "
                ht put [GroupLongLink $g]
            }
            ht li {
                ht put [TimeWindow $start_ $end_]
            }
        }

        ht para

        # NEXT, insert the plot.
        set vars [list]
        adb eval {SELECT g AS f FROM civgroups WHERE n=$n} {
            lappend vars coop.$f.$g
        }

        lappend vars nbcoop.$n.$g

        # NOTE: there's a limit of 10 plots.  If the groups would overflow
        # that, don't include them.
        if {[llength $vars] > 10} {
            set vars [lindex $vars end]
            ht putln "
                <b>NOTE:</b> There are too many civilian groups in this
                neighborhood to display the cooperation of each with
                group $g.  Hence, the plot shows only the average cooperation 
                of the neighborhood with $g. 
            "
        }


        PutPlot hist.nbcoop $start_ $end_ $vars

        # NEXT, Get the drivers for this time period.
        adb contribs nbcoop $n $g \
            -start $start_       \
            -end   $end_

        # NEXT, output the contribs table.
        PutContribsTable $start_ $end_ $top_

        ht /page

        return [ht get]
    }


    #-------------------------------------------------------------------
    # /contribs/nbmood:  Contributions to neighborhood mood.
    #
    # No match parameters

    # /contribs/nbmood:html udict matchArray
    #
    # Returns a page that allows the user to see the contributions
    # for a specific neighborhood mood curve during
    # a particular time interval.
    #
    # The udict query is a "parm=value[+parm=value]" string with the
    # following parameters:
    #
    #    n      The neighborhood
    #    top    Max number of top contributors to include.
    #    start  Start time in ticks
    #    end    End time in ticks
    #
    # Unknown query parameters and invalid query values are ignored.

    proc /contribs/nbmood:html {udict matchArray} {
        # FIRST, get the query parameters 
        set qdict [GetQueryParms $udict {n}]

        # NEXT, bring the query parms into scope
        dict with qdict {}

        # NEXT, get the neighborhood
        set n [string toupper $n]

        if {![adb nbhood exists $n]} {
            set n "?"
        }

        # NEXT, begin to format the report
        ht page "Contributions to Neighborhood Mood"
        ht title "Contributions to Neighborhood Mood"

        # NEXT, if we're not locked we're done.
        if {![locked -disclaimer]} {
            ht /page
            return [ht get]
        }

        # NEXT, insert subtitle, indicating the neighborhood
        ht subtitle "Of $n"

        # NEXT, insert the control form.
        ht hr
        ht form
        ht label n "Neighborhood:"
        ht input n enum $n -src /app/nbhoods
        ht label top "Show:"
        ht input top enum $top -src /app/enum/topitems -content tcl/enumdict
        ht para
        ht label start 
        ht put "Time Interval &mdash; "
        ht link /help/term/timespec.html "From:"
        ht /label
        ht input start text $start -size 12
        ht label end
        ht link /help/term/timespec.html "To:"
        ht /label
        ht input end text $end -size 12
        ht submit
        ht /form
        ht hr
        ht para

        # NEXT, if we don't have the neighborhood, ask for it.
        if {$n eq "?"} {
            ht putln "Please select a neighborhood."
            ht /page
            return [ht get]
        }

        # NEXT, format the report header.

        ht ul {
            ht li {
                ht put "Neighborhood: "
                ht put [NbhoodLongLink $n]
            }
            ht li {
                ht put [TimeWindow $start_ $end_]
            }
        }

        ht para

        # NEXT, insert the plot.
        set vars [list] 
        adb eval {SELECT g FROM civgroups WHERE n=$n} {
            lappend vars mood.$g
        }
        lappend vars nbmood.$n

        # NOTE: there's a limit of 10 plots.  If the groups would overflow
        # that, don't include them.
        if {[llength $vars] > 10} {
            set vars [lindex $vars end]
            ht putln "
                <b>NOTE:</b> There are too many civilian groups in this
                neighborhood to display the mood of each.  Hence, the plot 
                shows only the neighborhood's mood. 
            "
        }


        PutPlot hist.nbmood $start_ $end_ $vars

        # NEXT, Get the drivers for this time period.
        adb contribs nbmood $n \
            -start $start_    \
            -end   $end_

        # NEXT, output the contribs table.
        PutContribsTable $start_ $end_ $top_

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /contribs/sat?query
    #
    # No match parameters


    # /contribs/sat:html udict matchArray
    #
    # Returns a page that allows the user to see the contributions
    # for a specific satisfaction curve for a specific group during
    # a particular time interval.
    #
    # The udict query is a "parm=value[+parm=value]" string with the
    # following parameters:
    #
    #    g      The civilian group
    #    c      The concern
    #    top    Max number of top contributors to include.
    #    start  Start time in ticks
    #    end    End time in ticks
    #
    # Unknown query parameters and invalid query values are ignored.

    proc /contribs/sat:html {udict matchArray} {
        # FIRST, get the query parameters 
        set qdict [GetQueryParms $udict {g c}]

        # NEXT, bring the query parms into scope
        dict with qdict {}

        # NEXT, get the group and concern
        set g [string toupper $g]
        set c [string toupper $c]

        if {![adb civgroup exists $g]} {
            set g "?"
        }

        if {$c ni [econcern names]} {
            set c "?"
        }

        # NEXT, begin to format the report
        ht page "Contributions to Satisfaction"
        ht title "Contributions to Satisfaction"

        # NEXT, if we're not locked we're done.
        if {![locked -disclaimer]} {
            ht /page
            return [ht get]
        }

        # NEXT, insert subtitle, indicating the group and concern
        ht subtitle "Of $g with $c"

        # NEXT, insert the control form.
        ht hr
        ht form
        ht label g "Group:"
        ht input g enum $g -src /app/groups/civ
        ht label c "Concern:"
        ht input c enum $c -src /app/enum/concerns
        ht label top "Show:"
        ht input top enum $top -src /app/enum/topitems -content tcl/enumdict
        ht para
        ht label start 
        ht put "Time Interval &mdash; "
        ht link /help/term/timespec.html "From:"
        ht /label
        ht input start text $start -size 12
        ht label end
        ht link /help/term/timespec.html "To:"
        ht /label
        ht input end text $end -size 12
        ht submit
        ht /form
        ht hr
        ht para

        # NEXT, if we don't have the group and concern, ask for them.
        if {$g eq "?" || $c eq "?"} {
            ht putln "Please select a group and concern."
            ht /page
            return [ht get]
        }

        # NEXT, format the report header.

        ht ul {
            ht li {
                ht put "Group: "
                ht put [GroupLongLink $g]
            }
            ht li {
                ht put "Concern: $c"
            }
            ht li {
                ht put [TimeWindow $start_ $end_]
            }
        }

        ht para

        # NEXT, insert the plot.
        set vars [list basesat.$g.$c sat.$g.$c]

        # If the URAM gamma for this concern is non-zero, include the
        # natural level.
        if {[lindex [adb parm get uram.factors.$c] 1] > 0.0} {
            lappend vars natsat.$g.$c
        }

        PutPlot hist.sat $start_ $end_ $vars

        # NEXT, Get the drivers for this time period.
        adb contribs sat $g $c \
            -start $start_      \
            -end   $end_

        # NEXT, output the contribs table.
        PutContribsTable $start_ $end_ $top_

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /contribs/vrel:  All vertical relationship curves.
    #
    # No match parameters

    # /contribs/vrel:html udict matchArray
    #
    # Returns a page that allows the user to see the contributions
    # for a specific vertical relationships curve of a group
    # with an actor during a particular time interval.
    #
    # The udict query is a "parm=value[+parm=value]" string with the
    # following parameters:
    #
    #    g      The group
    #    a      The actor
    #    top    Max number of top contributors to include.
    #    start  Start time in ticks
    #    end    End time in ticks
    #
    # Unknown query parameters and invalid query values are ignored.

    proc /contribs/vrel:html {udict matchArray} {
        # FIRST, get the query parameters 
        set qdict [GetQueryParms $udict {g a}]

        # NEXT, bring the query parms into scope
        dict with qdict {}

        # NEXT, get the group and actor
        set g [string toupper $g]
        set a [string toupper $a]

        if {![adb group exists $g]} {
            set g "?"
        }

        if {![adb actor exists $a]} {
            set a "?"
        }
        
        # NEXT, begin to format the report
        ht page "Contributions to Vertical Relationship"
        ht title "Contributions to Vertical Relationship"

        # NEXT, if we're not locked we're done.
        if {![locked -disclaimer]} {
            ht /page
            return [ht get]
        }

        # NEXT, insert subtitle, indicating the group/actor pair
        ht subtitle "Of $g with $a"

        # NEXT, insert the control form.
        ht hr
        ht form
        ht label g "Of Group:"
        ht input g enum $g -src /app/groups
        ht label a "With Actor:"
        ht input a enum $a -src actors
        ht label top "Show:"
        ht input top enum $top -src /app/enum/topitems -content tcl/enumdict
        ht para
        ht label start 
        ht put "Time Interval &mdash; "
        ht link /help/term/timespec.html "From:"
        ht /label
        ht input start text $start -size 12
        ht label end
        ht link /help/term/timespec.html "To:"
        ht /label
        ht input end text $end -size 12
        ht submit
        ht /form
        ht hr
        ht para

        # NEXT, if we don't have the group or actor, ask for them.
        if {$g eq "?" || $a eq "?"} {
            ht putln "Please select the group and actor."
            ht /page
            return [ht get]
        }

        # NEXT, format the report header.

        ht ul {
            ht li {
                ht put "Of Group: "
                ht put [GroupLongLink $g]
            }
            ht li {
                ht put "With Actor: "
                ht put [ActorLongLink $a]
            }
            ht li {
                ht put [TimeWindow $start_ $end_]
            }
        }

        ht para

        # NEXT, insert the plot.
        set vars [list basevrel.$g.$a vrel.$g.$a]

        # If the URAM gamma for this attitude is non-zero, include the
        # natural level.
        if {[lindex [adb parm get uram.factors.VREL] 1] > 0.0} {
            lappend vars natvrel.$g.$a
        }

        PutPlot hist.vrel $start_ $end_ $vars

        # NEXT, Get the drivers for this time period.
        adb contribs vrel $g $a \
            -start $start_       \
            -end   $end_

        # NEXT, output the contribs table.
        PutContribsTable $start_ $end_ $top_

        ht /page

        return [ht get]
    }


    #-------------------------------------------------------------------
    # Utilities

    # GetQueryParms udict parms
    #
    # udict    - The URL dictionary, as passed to the handler
    # parms    - The list of expected parameter names, except for
    #            top, start, and end.
    #
    # Retrieves the parameter names using [querydict]; then
    # does the required validation and processing on the
    # shared top, start, and end parms.  Returns the parameter
    # dictionary, with "start_", "end_", and "top_" containing the
    # "cooked" versions of "start", "end", and "top".
    
    proc GetQueryParms {udict parms} {
        # FIRST, get the query parameter dictionary.
        set qdict [querydict $udict [concat $parms {top start end}]]

        # NEXT, do the standard parameend_r processing.
        dict set qdict start_ ""
        dict set qdict end_   ""
        dict set qdict top_   ""

        dict with qdict {
            # FIRST, get the top number of items
            restrict top etopitems TOP20

            set top_ $limit($top)

            # NEXT, get the user's time specs in ticks, or "".
            set start_ $start
            set end_   $end

            restrict start_ {adb clock timespec} [adb clock cget -tick0]
            restrict end_   {adb clock timespec} [adb clock now]

            # If they picked the defaults, clear their entries.
            if {$start_ == 0             } { set start "" }
            if {$end_   == [adb clock now]} { set end   "" }

            # NEXT, end_ can't be later than mystart.
            let end_ {max($start_,$end_)}
        }

        return $qdict
    }
    
    # ActorLongLink a
    #
    # a      A actor name
    #
    # Returns the actor's long link.

    proc ActorLongLink {a} {
        adb onecolumn {
            SELECT longlink FROM gui_actors WHERE a=$a
        }
    }
    
    # GroupLongLink g
    #
    # g      A group name
    #,
    # Returns the group's long link.

    proc GroupLongLink {g} {
        adb onecolumn {
            SELECT longlink FROM gui_groups WHERE g=$g
        }
    }

    # NbhoodLongLink n
    #
    # n      A nbhood name
    #
    # Returns the nbhood's long link.

    proc NbhoodLongLink {n} {
        adb onecolumn {
            SELECT longlink FROM gui_nbhoods WHERE n=$n
        }
    }

    # TimeWindow start end
    #
    # start    - The start time, in ticks
    # end      - The end time in ticks
    #
    # Converts the start and end time into a time window string.

    proc TimeWindow {start end} {
        set text "Window: [adb clock toString $start] to "

        if {$end == [adb clock now]} {
            append text "now"
        } else {
            append text "[adb clock toString $end]"
        }

        return $text
    }

    # PutPlot histparm start end vars
    #
    # histparm - hist.* parm governing whether data is available
    # start    - Start time in ticks
    # end      - End time in ticks
    # vars     - List of time series display variables
    #
    # Adds a plot of the listed variables to the ht buffer.

    proc PutPlot {histparm start end vars} {
        if {![adb parm get $histparm]} {
            ht putln {
                <b>Note:</b> Athena is not currently saving some or
                all of the historical data required for the following 
                plot.  To plot the data, unlock the scenario,
                set the model parameter
            }

            ht link "/app/parmdb?$histparm" <b>$histparm</b>

            ht putln "to on, and re-run the scenario."
            ht para
        }

        ht object plot/time?start=$start+end=$end+vars=[join $vars ,] \
            -width  100% \
            -height 3in
        ht para
    }

    # PutContribsTable start end top
    #
    # start - Time tick of first week in interval
    # end   - Time tick of last week in interval
    # top   - Max number of entries in table, or 0 for all.
    #
    # Converts the data in uram_contribs into a ranked contributions
    # table, and puts it into the htools buffer.

    proc PutContribsTable {start end top} {
        # FIRST, compute the number of weeks.
        let weeks {$end - $start + 1}

        # NEXT, pull the contribs into a temporary table, in sorted order,
        # so that we can use the "rowid" as the rank.
        # Note: This query is passed as a string, because the LIMIT
        # is an integer, not an expression, so we can't use an SQL
        # variable.
        set query "
            DROP TABLE IF EXISTS temp_contribs;
    
            CREATE TEMP TABLE temp_contribs AS
            SELECT driver            AS driver,
                   contrib           AS contrib,
                   contrib/\$weeks   AS avgcontrib
            FROM uram_contribs
            ORDER BY abs(contrib) DESC
        "

        if {$top != 0} {
            append query "LIMIT $top"
        }

        adb eval $query

        # NEXT, get the total contribution to this curve in this
        # time window.

        set totContrib [adb onecolumn {
            SELECT total(abs(contrib))
            FROM uram_contribs
        }]

        # NEXT, get the total contribution represented by the report.

        set totReported [adb onecolumn {
            SELECT total(abs(contrib)) 
            FROM temp_contribs
        }]

        # NEXT, format the body of the report.
        ht query {
            SELECT format('%4d', temp_contribs.rowid) AS "Rank",
                   format('%8.3f', avgcontrib)        AS "Actual",
                   link                               AS "Driver",
                   dtype                              AS "Type",
                   sigline                            AS "Signature"
            FROM temp_contribs
            JOIN gui_drivers ON (driver = driver_id);

            DROP TABLE temp_contribs;
        }  -default "None known." -align "RRRLL"

        ht para

        if {$totContrib > 0.0} {
            set pct [percent [expr {$totReported / $totContrib}]]

            ht putln "The listed drivers represent"
            ht putln "$pct of the contributions made to this curve"
            ht putln "during the specified time window."
            ht para

            ht putln {
                The <b>Actual</b> contribution displayed for each
                driver is the average contribution per week during
                the requested time interval.  Remember that driver
                contributions are not accumulated from week to week.
            }

            ht para
        }
    }
}




