#-----------------------------------------------------------------------
# TITLE:
#   tool.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Tool framework.  A tool is a subcommand of the executable.
#   Tools are created by calling 'tool define'.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# tool ensemble

snit::type tool {
    pragma -hasinstances no -hastypedestroy no

    #-------------------------------------------------------------------
    # Tool Meta Data

    # meta array
    #
    # tools              - List of tool subcommand names
    # usage-$tool        - List {min max argspec}
    # description-$tool  - One line description of tool

    typevariable meta -array {
        tools {}
    }

    #-------------------------------------------------------------------
    # Tool Definition

    # define tool mdict helptext body
    #
    # tool      - The tool's subcommand, e.g., "info"
    # mdict     - The metadata dictionary
    # helptext  - The tool's help text
    # body      - The tool's body
    #
    # Defines a tool.  The metadata dictionary defines the tool's 
    # usage and description.  The help text is passed to the
    # help subsystem.
    #
    # The body is a snit::type body containing typemethods.  It must 
    # contain at least an "execute" typemethod.  It may also define other
    # public methods for use by other parts of the application, especially
    # "clean".
    #
    # The tool's ensemble will be "tool::$tool" with $tool in uppercase.

    typemethod define {tool mdict helptext body} {
        # FIRST, check the inputs
        set tool [string tolower $tool]

        # NEXT, save the metadata.
        ladd meta(tools)             $tool
        set  meta(usage-$tool)       [dict get $mdict usage]
        set  meta(description-$tool) [dict get $mdict description]
        set  meta(ensemble-$tool)    ::tool::[string toupper $tool]

        # NEXT, save the help text
        # TODO: We'll do better when we update the help subsystem.
        set ::thelp($tool) $helptext

        # NEXT, build up the snit type.
        snit::type $meta(ensemble-$tool) [format [outdent {
            pragma -hasinstances no -hastypedestroy no

            %s
        }] $body]
    }
    
    #-------------------------------------------------------------------
    # Public Methods

    # names
    #
    # Returns a list of the names of the registered tools.

    typemethod names {} {
        return $meta(tools)
    }

    # exists tool
    #
    # tool  - Possibly, the name of a registered tool.
    #
    # Returns 1 if the tool exists, and 0 otherwise.

    typemethod exists {tool} {
        expr {$tool in $meta(tools)}
    }

    # usage tool
    #
    # tool  - The name of a registered tool.
    #
    # Returns a usage string for the tool.

    typemethod usage {tool} {
        lassign $meta(usage-$tool) min max argspec
        return "[file tail $::argv0] $tool $argspec"
    }

    # description tool
    #
    # tool  - The name of a registered tool.
    #
    # Returns the tools description.

    typemethod description {tool} {
        return $meta(description-$tool)
    }

    # use tool ?argv?
    #
    # tool   - The name of a registered tool
    # argv   - The argument list to pass to the tool.
    #
    # Executes the tool given the argument list, first checking the usage.

    typemethod use {tool {argv ""}} {
        # FIRST, check the usage.
        lassign $meta(usage-$tool) min max argspec
        set argc [llength $argv]

        if {($argc < $min) ||
            ($max ne "-" && $argc > $max)
        } {
            throw FATAL "Usage: [tool usage $tool]"
        }

        # NEXT, execute the tool.
        $meta(ensemble-$tool) execute $argv

        puts ""
    }    
}
