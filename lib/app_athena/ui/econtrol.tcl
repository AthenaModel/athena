#-----------------------------------------------------------------------
# FILE: econtrol.tcl
#
# PACKAGE:
#   app_sim(n) -- athena_sim(1) implementation package
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#
#   econtrol(sim) package: Economic model control
#
#     This widget displays a large on/off switch that allows a user
#   to easily enable or disable the economic model.  It also displays
#   some text based on the state of the switch.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget: econtrol
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widget econtrol {

    #-------------------------------------------------------------------
    # Options
    #
    # Unknown options delegated to the hull

    delegate option * to hull
 
    #------------------------------------------------------------------
    # Components

    component modelswitch ;# the econ model switch
    component browser     ;# an instance of a mybrowser(n)

    #------------------------------------------------------------------
    # Instance variables

    # econstate
    #
    # The state of the econ model one of ENABLED or DISABLED

    variable econstate ;# eeconstate(n) enumeration
    #------------------------------------------------------------------
    # Constructor
    #
    # Create the widget and map the CGE.

    constructor {args} {
        # FIRST, get the options.
        $self configurelist $args

        ttk::label $win.lbl \
            -text "Economic Model Is:" 

        ttk::label $win.dummy -text ""

        install modelswitch using checkbutton $win.cb  \
            -variable    [myvar econstate]             \
            -indicatoron 0                             \
            -command     [mymethod ToggleSwitch]       \
            -image       ::projectgui::icon::switchoff \
            -selectimage ::projectgui::icon::switchon  \
            -relief      solid                         \
            -offrelief   solid                         \
            -onvalue     ENABLED                       \
            -offvalue    DISABLED

        set econstate DISABLED

        install browser using mybrowser $win.browser \
            -toolbar   no \
            -sidebar   no \
            -home      "" \
            -hyperlinkcmd {::app show} \
            -messagecmd   {::app puts} \
            -reloadon {
                ::sim <State>
            }

        grid $win.lbl     -row 0 -column 0 -padx 5 -sticky w
        grid $modelswitch -row 0 -column 1         -sticky w
        grid $win.dummy   -row 0 -column 2         -sticky w
        grid $browser     -row 1 -column 0 -columnspan 3 -sticky nsew

        grid rowconfigure    $win 1 -weight 1
        grid columnconfigure $win 2 -weight 1

        notifier bind ::sim  <DbSyncB> $self [mymethod EconState]
        notifier bind ::sim  <State>   $self [mymethod SimState]
        notifier bind ::econ <State>   $self [mymethod EconState]

        # NEXT, populate the HTML frame based on view
        $browser show "my://app/econ/disabled/"
    }

    # Constructor: Destructor
    #
    # Forget the notifier bindings.
    
    destructor {
        notifier forget $self
    }

    # ToggleSwitch
    #
    # This method toggles the information displayed depending on the
    # state of the switch.  It also sets the econ model accordingly.
    # Lastly a notifier is sent with the new state.

    method ToggleSwitch {} {
        if {$econstate eq "DISABLED"} {
            $browser show "my://app/econ/disabled/"
            econ disable
        } else {
            $browser show "my://app/econ/enabled/"
            econ enable
        }

        notifier send ::econtrol <State> $econstate 
    }

    # SimState
    #
    # This method responds to changes in the simulation state.

    method SimState {} {
        if {[sim state] eq "PREP"} {
            $modelswitch configure -state normal
        } else {
            $modelswitch configure -state disabled
        }
    }

    # EconState
    #
    # This method responds to changes made to the economic model state
    # from within the economic model itself, or after an new database
    # has been loaded.  If something goes terribly wrong in the economic
    # model during a run, it disables itself, so this widget needs to know
    # if that happens.

    method EconState {} {
        if {[econ state] eq "ENABLED"} {
            $modelswitch select
            $browser show "my://app/econ/enabled/"
        } else {
            $modelswitch deselect
            $browser show "my://app/econ/disabled/"
        }
    }
}
