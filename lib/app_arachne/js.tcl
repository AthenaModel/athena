#-----------------------------------------------------------------------
# TITLE:
#   js.tcl
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
#   js: JSON generation utilities.
#
#   We use the huddle(n) Tcllib package for generating JSON; this module
#   contains convenience commands for common patterns.
#
#-----------------------------------------------------------------------

snit::type js {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Operation Results
    
    # ok result...
    #
    # result   - A string or HUDDLE object
    #
    # Formats a JSON "OK" result message.

    typemethod ok {args} {
        set hud [huddle list]
        huddle append hud OK

        foreach result $args {
            if {[huddle isHuddle $result]} {
                huddle append hud $result
            } else {
                huddle append hud [huddle compile string $result]
            }
        }

        return [huddle jsondump $hud]
    }

    # reject result...
    #
    # result   - A dictionary, as one argument or multiple
    #
    # Formats a JSON "REJECT" result message.

    typemethod reject {args} {
        if {[llength $args] eq 1} {
            set args [lindex $args 0]
        }

        set hud [huddle list]
        huddle append hud REJECT [huddle compile dict $args]

        return [huddle jsondump $hud]
    }

    # error message
    #
    # message     - The error message
    #
    # Formats a JSON "ERROR" result message.

    typemethod error {message} {
        set hud [huddle list]
        huddle append hud ERROR [huddle compile string $message]

        return [huddle jsondump $hud]
    }

    # exception message stackTrace
    #
    # message     - The error message
    # stackTrace  - A Tcl stack trace
    #
    # Formats a JSON "EXCEPTION" result message.

    typemethod exception {message stackTrace} {
        set hud [huddle list]
        huddle append hud EXCEPTION \
            [huddle compile string $message] \
            [huddle compile string $stackTrace]

        return [huddle jsondump $hud]
    }

    #-------------------------------------------------------------------
    # Data Results

    # dictab table
    #
    # table   - A "dictab", or list of simple dictionaries.
    #
    # Formats the dictab as a list of JSON objects.

    typemethod dictab {table} {
        set hud [huddle list]
        
        foreach record $table {
            huddle append hud [huddle compile dict $record]
        }   

        return [huddle jsondump $hud]
    }

    # list list
    #
    # list   - A list of simple strings.
    #
    # Formats the list as a JSON array of strings.

    typemethod list {list} {
        set hud [huddle compile list $list]        
        return  [huddle jsondump $hud]
    }
    

}