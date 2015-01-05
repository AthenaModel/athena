#-----------------------------------------------------------------------
# TITLE:
#    orderx_dialog.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectgui(n): orderx dialog widget
#
#-------------------------------------------------------------------

namespace eval ::projectgui:: {
    namespace export orderx_dialog
}

#-----------------------------------------------------------------------
# Widget: orderx_dialog
#
# The orderx_dialog(n) widget creates order dialogs for orders defined
# using orderx(n).
#
# TBD: This module sends the <OrderEntry> event to indicate what kind of
# parameter is currently being entered.  Because orderx_dialog(n) is a
# GUI submodule of orderx(n), it will use the same notifier(n) subject
# as orderx(n).
#
#-----------------------------------------------------------------------

snit::widget ::projectgui::orderx_dialog {
    #===================================================================
    # Dialog Widget
    hulltype toplevel

    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    # -appname name
    #
    # The application name, for use in dialog title bar.

    option -appname \
        -readonly yes \
        -default  "Application"

    # -flunky flunky
    #
    # The order_flunky(n) instance which will be responsible for
    # handling the order when it is sent.

    option -flunky \
        -readonly yes

    # -helpcmd cmd
    #
    # If given, a command for retrieving on-line help for the -order.

    option -helpcmd

    # -order order
    #
    # The name of the order.  The widget will create an instance of
    # the order.

    option -order     \
        -readonly yes

    # -parent pwin
    #
    # The parent window

    option -parent \
        -readonly yes

    # -refreshon eventdict
    #
    # Indicates additional notifier events that should cause the dialog
    # to refresh.

    option -refreshon \
        -readonly yes

    #-------------------------------------------------------------------
    # Components

    component flunky     ;# The order_flunky(n) instance.
    component order      ;# The orderx(n) instance
    component form       ;# The dynaview(n) widget
    component raiser     ;# A timeout(n) object.

    #-------------------------------------------------------------------
    # Instance Variables

    # my array -- scalars and field data
    #
    # parms             Names of all parms.
    # context           Names of all context parms

    variable my -array {
        parms      {}
        context    {}
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, withdraw the hull; we will deiconify at the end of the
        # constructor.
        wm withdraw $win
        
        # NEXT, get the options and save components.
        $self configurelist $args

        set flunky $options(-flunky)

        # NEXT, create the order.
        set order [$flunky make $options(-order)]

        # NEXT, set up the window manager details

        # Title
        wm title $win "$options(-appname): Send Order"
        
        # User can't resize it
        wm resizable $win 0 0

        # Control closing the window
        wm protocol $win WM_DELETE_WINDOW [mymethod Close]

        # NEXT, create the title bar
        ttk::frame $win.tbar \
            -borderwidth 0   \
            -relief      flat

        # NEXT, create the title widget
        ttk::label $win.tbar.title        \
            -font          OrderTitleFont \
            -text          [$order title] \
            -padding       4

        # NEXT, create the help button
        ttk::button $win.tbar.help               \
            -style   Toolbutton                  \
            -image   ::marsgui::icon::question22 \
            -state   normal                      \
            -command [mymethod Help]

        DynamicHelp::add $win.tbar.help -text "Get help!"

        pack $win.tbar.title -side left

        if {$options(-helpcmd) ne ""} {
            pack $win.tbar.help  -side right
        }

        # NEXT, create the dynaview.
        install form using dynaview $win.form      \
            -formtype    [$order dynaform]         \
            -entity      $order                    \
            -borderwidth 1                         \
            -relief      raised                    \
            -padding     2                         \
            -currentcmd  [mymethod OnEnterField]   \
            -changecmd   [mymethod OnFormChange] 

        # NEXT, set up the metadata.
        set my(parms)      [$order parms]
        set my(context)    [dynaform context [$order dynaform]]

        # NEXT, create the message display
        rotext $win.message                                \
            -takefocus          0                          \
            -font               TkDefaultFont              \
            -width              40                         \
            -height             3                          \
            -wrap               word                       \
            -relief             flat                       \
            -background         [$win cget -background]    \
            -highlightthickness 0

        # NEXT, create the frame to hold the buttons
        ttk::frame $win.buttons \
            -borderwidth 0      \
            -relief      flat

        ttk::button $win.buttons.clear        \
            -text    "Clear"                  \
            -width   6                        \
            -command [mymethod Clear]

        ttk::button $win.buttons.send         \
            -text    "Send"                   \
            -width   6                        \
            -command [mymethod Send]

        ttk::button $win.buttons.sendclose    \
            -text    "Send & Close"           \
            -width   12                       \
            -command [mymethod SendClose]

        pack $win.buttons.clear     -side left  -padx {2 15}
        pack $win.buttons.sendclose -side right -padx 2
        pack $win.buttons.send      -side right -padx 2

        # NEXT, pack components
        pack $win.tbar    -side top -fill x
        pack $win.form    -side top -fill x -padx 4 -pady 4
        pack $win.message -side top -fill x -padx 4
        pack $win.buttons -side top -fill x -pady 4

        # NEXT, make the window visible, and transient over the
        # current top window.
        osgui mktoolwindow  $win $options(-parent)
        wm deiconify  $win
        raise $win
        
        # NEXT, if there's saved position, give the dialog the
        # position.
        if 0 {
            # TBD: Define dialog position manager.  The dialog ID
            # should be "$flunky/[$order class]".
            if {$info(position-$options(-order)) ne ""} {
                wm geometry \
                    $info(win-$options(-order)) \
                    $info(position-$options(-order))
            }
        }

        # NEXT, refresh the dialog on events from the flunky.
        notifier bind $flunky <Sync> $win [mymethod RefreshDialog]

        # NEXT, prepare to refresh the dialog on particular events from
        # the application.
        foreach {subject event} $options(-refreshon) {
            notifier bind $subject $event $win [mymethod RefreshDialog]
        }

        # NEXT, raise the widget if it's obscured by its parent.
        install raiser using timeout ${selfns}::raiser \
            -interval   500 \
            -repetition yes \
            -command    [mymethod KeepVisible]
        $raiser schedule

        # NEXT, wait for visibility.
        update idletasks
    }

    destructor {
        notifier forget $win
        catch {$order destroy}
    }

    #-------------------------------------------------------------------
    # Event Handlers: Form Callbacks

    # OnFormChange fields
    #
    # fields   A list of one or more field names
    #
    # The data in the form has changed.  Validate the order, and set
    # the button state.

    method OnFormChange {fields} {
        # FIRST, validate the order.
        $self CheckValidity

        # NEXT, set the button state
        $self SetButtonState
    }

    # OnEnterField parm
    #
    # parm    The parameter name
    #
    # Updates the display when the user is on a particular field.

    method OnEnterField {parm} {
        # FIRST, if there's an error message, display it.
        if {[dict exists [$order errdict] $parm]} {
            $self ShowParmError $parm [dict get [$order errdict] $parm]
        } else {
            $self Message ""
        }

        # NEXT, tell the app what kind of parameter this is.
        set tags [$order tags $parm]

        if {[llength $tags] == 0} {
            set tags null
        }

        if 0 {
            # TBD: Notification is TBD
            $type Notify <OrderEntry> $tags
        }
    }

    #-------------------------------------------------------------------
    # Event Handlers: Buttons

    # Clear
    #
    # Clears all parameter values

    method Clear {} {
        # FIRST, clear the dialog
        $form clear

        # NEXT, refresh all of the fields.
        $self RefreshDialog

        # NEXT, notify the app that the dialog has been cleared; this
        # will allow it to clear up any entry artifacts.
        if 0 {
            # TBD: Notification comes later.
            $type Notify <OrderEntry> {}
        }
    }

    # Close
    #
    # Closes the dialog

    method Close {} {
        if 0 {
            # TBD: position will be handled by dialog positioner.
            # TBD: notifications are TBD.

            # FIRST, save the dialog's position
            set geo [wm geometry $win]
            set ndx [string first "+" $geo]
            set info(position-$options(-order)) [string range $geo $ndx end]

            # NEXT, notify the app that no order entry is being done.
            $type Notify <OrderEntry> {}
        }

        # NEXT, destroy the dialog
        destroy $win
    }

    # Help
    #
    # Brings up the on-line help for the application
    
    method Help {} {
        callwith $info(helpcmd) $options(-order)
    }

    # Send
    #
    # Sends the order if valid.

    method Send {} {
        # FIRST, the send button shouldn't be active unless the order
        # is known to be valid.
        assert {[$order valid]}
        set result [$flunky execute gui $order]

        # NEXT, either output the result, or just say that the order
        # was accepted.
        if {$result ne ""} {
            $self Message "Result: $result"
        } else {
            $self Message "The order was accepted."
        }

        # NEXT, notify the app that no order entry is being done; this
        # will allow it to clear up any entry artifacts.
        if 0 {
            # TBD: Notifications are TBD.
            $type Notify <OrderEntry> {}
        }

        # NEXT, the order was accepted; we're done here.
        return 1
    }

    # SendClose
    #
    # Sends the order and closes the dialog on success.

    method SendClose {} {
        $self Send
        $self Close
    }

    #-------------------------------------------------------------------
    # Event Handlers: Visibility

    # KeepVisible 
    #
    # If the dialog is fully obscured, this raises it above its parent.

    method KeepVisible {} {
        set p $options(-parent)

        if {[winfo exists $p] && [winfo ismapped $p]} {
            if {[wm stackorder $win isbelow $p]} {
                raise $win
            }
        }
    }

    #-------------------------------------------------------------------
    # Event Handlers: Dialog Refresh

    # RefreshDialog ?args...?
    #
    # args - Ignored optional arguments.
    #
    # At times, it's necessary to refresh the entire dialog:
    # at initialization, on clear, etc.
    #
    # Any arguments are ignored; this allows a refresh to be
    # triggered by any notifier(n) event.

    method RefreshDialog {args} {
        $form refresh
        $self CheckValidity
        $self SetButtonState
    }



    #-------------------------------------------------------------------
    # Event Handlers: Object Selection

    # ObjectSelect tagdict
    #
    # tagdict   A dictionary of tags and values
    #
    # A dictionary of tags and values that indicates the object or 
    # objects that were selected.  The first one that matches the current
    # field, if any, will be inserted into it.

    method ObjectSelect {tagdict} {
        # FIRST, Get the current field.  If there is none,
        # we're done.
        set current [$self GetCurrentField]

        if {$current eq ""} {
            return
        }

        # NEXT, get the tags for the current field.  If there are none,
        # we're done.

        set tags [$order tags $parm]

        if {[llength $tags] == 0} {
            return
        }

        # NEXT, get the new value, if any.  If none, we're done.
        set newValue ""

        foreach {tag value} $tagdict {
            if {$tag in $tags} {
                set newValue $value
                break
            }
        }

        if {$newValue eq ""} {
            return
        }

        # NEXT, save the value
        $form set $current $newValue
    }

    #-------------------------------------------------------------------
    # Utility Methods


    # SetButtonState
    #
    # Enables/disables the send button based on 
    # whether there are unsaved changes, and whether the data is valid,
    # and so forth.

    method SetButtonState {} {
        # FIRST, the order can be sent if the field values are
        # valid, and if either we aren't checking order states or
        # the order is valid in this state.
        if {[$flunky available $options(-order)] && [$order valid]} {
            $win.buttons.send      configure -state normal
            $win.buttons.sendclose configure -state normal
        } else {
            $win.buttons.send      configure -state disabled
            $win.buttons.sendclose configure -state disabled
        }
    }

    # CheckValidity
    #
    # Checks the current parameters; on error, reveals the error.

    method CheckValidity {} {
        # FIRST, clear error indicators
        $form invalid {}

        # NEXT, give the parameters to the order, and validate them.
        $order setdict [$form get]

        if {[$order valid]} {
            $self Message ""

            return
        }

        # NEXT, the order isn't valid. Mark the bad parms.
        set errdict [$order errdict]
        dict unset errdict *

        $form invalid [dict keys $errdict]

        # NEXT, show the current error message
        set current [$self GetCurrentField]

        if {$current ne "" && [dict exists $errdict $current]} {
            $self ShowParmError $current [dict get $errdict $current]
        } elseif {[dict exists [$order errdict] *]} {
            $self Message "Error in order: [dict get [$order errdict] *]"
        } else {
            $self Message \
             "Error in order; click in marked fields for error messages."
        }
    }


    # GetCurrentField
    #
    # Gets the name of the currently active field, or the first
    # editable field otherwise.

    method GetCurrentField {} {
        return [$form current]
    }

    # Message text
    #
    # Opens the message widget, and displays the text.

    method Message {text} {
        # FIRST, normalize the whitespace
        set text [string trim $text]
        set text [regsub {\s+} $text " "]

        # NEXT, display the text.
        $win.message del 1.0 end
        $win.message ins 1.0 $text
        $win.message see 1.0
    }

    # ShowParmError parm message
    #
    # parm    - The parameter name
    # message - The error message string
    #
    # Shows the error message on the message line.
    #
    # TBD: The method used to get the dynaform field's label 
    # is kind of fragile.  Perhaps some other way of linking
    # the field with the message could be used?  I.e., an
    # asterisk on the current field, if the current field is in
    # error?

    method ShowParmError {parm message} {
        set label [$form getlabel $parm]

        if {$label ne ""} {
            $self Message "$label: $message"
        } else {
            $self Message $message
        }
    }



    #-------------------------------------------------------------------
    # Public Methods

    delegate method get to form

    # enter parmdict
    #
    # parmdict   - A dictionary of order parameters and values.
    #
    # Loads the parameter values into the dialog.

    method enter {parmdict} {
        # FIRST, make the window visible
        raise $win

        # NEXT, verify that all context parameters are included.
        set missing [list]
        foreach cparm $my(context) {
            if {![dict exists $parmdict $cparm]} {
                lappend missing $cparm
            }
        }

        if {[llength $missing] > 0} {
            set msg \
"Cannot enter $options(-order) dialog, context parm(s) missing: [join $missing {, }]"
            $self Close
            throw $msg
        }

        # NEXT, fill in the data
        $self Clear

        if {[dict size $parmdict] > 0} {
            $form set $parmdict
        }
    }
    



}

