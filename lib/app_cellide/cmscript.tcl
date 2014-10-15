#-----------------------------------------------------------------------
# TITLE:
#    cmscript.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_cellide(n) cmscript Ensemble
#
#    This module manages the cellmodel(5) script for the application.
#    It knows whether the current script has been saved or not, and owns
#    the cellmodel(n) object.  It is responsible for the 
#    open/save/save as/new functionality.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# cmscript ensemble

snit::type cmscript {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Components

    typecomponent cm     ;# The cellmodel(n) object
    typecomponent editor ;# The cmscripteditor object

    #-------------------------------------------------------------------
    # Type Variables

    # Info Array: most scalars are stored here
    #
    # cmfile     - Name of the current cellmodel(5) file
    # unsaved    - 1 if file needs to be saved, and 0 otherwise.
    # checkstate - An echeckstate value; status of last check.  Set
    #              to unchecked when file is edited.
    # checkinfo  - A dictionary of syntax error information, when
    #              checkstate is "syntax":
    #
    #              line - The line number at which the syntax error 
    #                     is located.
    #              msg  - The error message
    # solvestate - An esolvestate value; status of last solution.
    #              Set to "unsolved" when file is edited.
    # solveinfo  - A dictionary of solution information.  The content
    #              depends on the solve state.
    #
    #              diverge:
    #                  page   - The name of the page that diverged.
    #
    #              errors:
    #                  page   - The name of the page on which the math
    #                           errors occurred.
    #
    #              ok:
    #                  TBD
    #

    typevariable info -array {
        cmfile     ""
        unsaved    0
        checkstate unchecked
        checkinfo  {}
        solvestate unsolved
    }

    #-------------------------------------------------------------------
    # Initializer

    # init
    #
    # Initializes the module.

    typemethod init {} {
        # FIRST, create a clean cellmodel(n) object
        cellmodel ::cm
    }

    # register ed
    #
    # ed   - A cmscripteditor widget
    #
    # Registers the script editor with this module.
    
    typemethod register {ed} {
        set editor $ed
    }

    #-------------------------------------------------------------------
    # State Routines
    
    # unsaved
    #
    # Returns 1 if there are unsaved changes, and 0 otherwise.

    typemethod unsaved {} {
        $type DetermineStates

        return $info(unsaved) 
    }

    # DetermineStates
    #
    # This routine is a mini-expert system that fills out the state
    # vector.

    typemethod DetermineStates {} {
        # FIRST, Are there unsaved changes or not? 
        set modified [$editor edit modified]

        # NEXT, if there are unsaved changes, the model is unsaved,
        # unchecked, and unsolved.
        if {$modified} {
            set info(unsaved) 1 
            set info(checkstate) unchecked
            set info(checkinfo)  {}
            set info(solvestate) unsolved
        }

        # NEXT, clear the editor's modified flag, so that we can
        # detect further changes.
        $editor edit modified no
    }
    
    # checkstate
    #
    # Returns the check state

    typemethod checkstate {} {
        $type DetermineStates

        return $info(checkstate)
    }

    # checkinfo
    #
    # Returns the syntax checkinfo dictionary when checkstate is
    # "syntax".  Otherwise, returns the empty string.

    typemethod checkinfo {} {
        return $info(checkinfo)
    }

    # solvestate
    #
    # Returns the solution state

    typemethod solvestate {} {
        $type DetermineStates

        return $info(solvestate)
    }

    typemethod solveinfo {} {
        return $info(solveinfo)
    }

    #-------------------------------------------------------------------
    # Script Management Methods

    # new
    #
    # Creates a new, blank cellmodel(5) script

    typemethod new {} {
        # NEXT, Create a blank cmscript
        $type MakeNew

        # NEXT, notify the application
        notifier send ::cmscript <New>
        app puts "New cell model created"
    }

    # MakeNew
    #
    # Creates a new, blank, script.  This is used on 
    # "cmscript new", and when "cmscript open" tries and fails.

    typemethod MakeNew {} {
        # FIRST, clear the editor.
        $editor new

        # NEXT, set the states and save the file name
        set info(cmfile)     ""
        set info(unsaved)    0
        set info(checkstate) unchecked
        set info(checkinfo)  {}
        set info(solvestate) unsolved

    }

    # open filename
    #
    # filename - A .cm file
    #
    # Opens the specified file name, replacing the existing file.

    typemethod open {filename} {
        # FIRST, load the file.
        if {[catch {
            $editor new [readfile $filename]
        } result]} {
            $type MakeNew

            app error {
                |<--
                Could not open cellmodel(5) file
                
                    $filename

                $result
            }

            return
        }

        # NEXT, set the states and save the file name
        set info(cmfile)     $filename
        set info(unsaved)    0
        set info(checkstate) unchecked
        set info(checkinfo)  {}
        set info(solvestate) unsolved

        # NEXT, notify the application.
        notifier send ::cmscript <Open>

        app puts "Opened file [file tail $filename]"

        return
    }

    # save ?filename?
    #
    # filename - Name for the new save file
    #
    # Saves the file, notify the application on success.  If no
    # file name is specified, the cmfile is used.  Returns 1 if
    # the save is successful and 0 otherwise.

    typemethod save {{filename ""}} {
        # FIRST, if filename is not specified, get the cmfile
        if {$filename eq ""} {
            if {$info(cmfile) eq ""} {
                error "Cannot save: no file name"
            }

            set cmfile $info(cmfile)
        } else {
            set cmfile $filename
        }

        # NEXT, make sure it has a .cm extension.
        if {[file extension $cmfile] ne ".cm"} {
            append cmfile ".cm"
        }

        # NEXT, notify the application that we're saving, so other 
        # modules can prepare.
        notifier send ::cmscript <Saving>

        # NEXT, Save, and check for errors.
        if {[catch {
            if {[file exists $cmfile]} {
                file rename -force $cmfile [file rootname $cmfile].bak
            }

            set f [open $cmfile w]
            puts $f [$editor getall]
            close $f
        } result opts]} {
            app error {
                |<--
                Could not save as
                
                    $cmfile

                $result
            }
            return 0
        }

        # NEXT, mark it saved, and save the file name
        set info(cmfile)  $cmfile
        set info(unsaved) 0


        # NEXT, set the current working directory to the cmscript
        # file location.
        catch {cd [file dirname [file normalize $filename]]}

        # NEXT, notify the application
        app puts "Saved file [file tail $info(cmfile)]"
        notifier send ::cmscript <Saved>

        return 1
    }


    # cmfile
    #
    # Returns the name of the current cmscript file

    typemethod cmfile {} {
        return $info(cmfile)
    }

    # cmtext
    #
    # Returns the text of the current cmscript file

    typemethod cmtext {} {
        return [$editor getall]
    }

    #-------------------------------------------------------------------
    # Model Checking

    # check
    #
    # Checks the content of the current model.  Returns an 
    # echeckstate value; if the result is "syntax", then 
    # [syntaxerr] returns the line number and error message

    typemethod check {} {
        # FIRST, clear the state data.
        $type DetermineStates
        set info(checkinfo) [dict create]

        # FIRST, check the syntax.
        if {[catch {cm load [$editor getall]} result eopts]} {
            set ecode [dict get $eopts -errorcode]

            if {[lindex $ecode 0] eq "SYNTAX"} {
                dict set info(checkinfo) line [lindex $ecode 1]
                dict set info(checkinfo) msg  $result
                set info(checkstate) syntax

                notifier send ::cmscript <Check>
                return $info(checkstate)
            }

            # It's an unexpected error; rethrow
            return {*}$eopts $result
        }

        # NEXT, if there were other problems, let them know about
        # that.
        if {$result == 1} {
            set info(checkstate) checked
        } else {
            set info(checkstate) insane
        }

        # NEXT, notify the application
        notifier send ::cmscript <Check>

        # FINALLY, all is good.
        return $info(checkstate)
    }

    #-------------------------------------------------------------------
    # Model Solving

    # solve ?options?
    #
    # -snapshot   - Snapshot to use as starting point for solution.
    # -epsilon    - Epsilon for iteration termination.
    # -maxiters   - Max number of iterations.
    #
    # Attempts to solve the model given the parameters, saving solution
    # details for later display.
    #
    # Note: the option values are presumed to be right.  If not, they'll
    # be caught by cellmodel(n).

    typemethod solve {args} {
        # FIRST, clear the state info
        $type DetermineStates
        set info(solveinfo) [dict create]

        # NEXT, get the option values.
        set opts(-snapshot) model
        set opts(-epsilon)  0.0001
        set opts(-maxiters) 100

        while {[llength $args] > 0} {
            set opt [lshift args]

            if {[info exists opts($opt)]} {
                set opts($opt) [lshift args]
            } else {
                error "Unknown option: \"$opt\""
            }
        }

        # NEXT, configure for solution
        cm configure \
            -epsilon  $opts(-epsilon)  \
            -maxiters $opts(-maxiters)

        # NEXT, put in the initial set of values
        cm set [snapshot get $opts(-snapshot)]

        # NEXT, solve the model and save the solution information
        set result [cm solve]

        set info(solvestate) [lindex $result 0]

        dict set info(solveinfo) initial $opts(-snapshot)
        dict set info(solveinfo) solution [snapshot save solution [cm get]]

        if {$info(solvestate) in {diverge errors}} {
            dict set info(solveinfo) page [lindex $result 1]
        }

        # NEXT, notify the application that we've tried to solve the model.
        notifier send ::cmscript <Solve>

        # FINALLY, return the solution state
        return $info(solvestate)
    }
}

