#-----------------------------------------------------------------------
# TITLE:
#   tool_build.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Athena "build" tool.  This tool builds scenario files given inputs
#   and options.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# tool::BUILD

tool define BUILD {
    usage       {2 - "?<infile>? ?<script>...? ?options...? <outfile>"}
    description "Athena Scenario Builder"
} {
    The 'athena build' tool builds an output scenario file from a variety
    of inputs.  In particular, the tool:

    * Loads <infile>, an input scenario file (if given)
    * Runs zero or more executive <script>s on the scenario.
    * Applies the options (see below).
    * Saves the result to <outfile>, the output file name.

    The options are as follows:

    -run <t>   - Locks the scenario and advances time to <t>.  If <t>
                 is zero, simply locks the scenario.
} {
    #-------------------------------------------------------------------
    # Execution 

    # execute argv
    #
    # Executes the tool given the command line arguments.

    typemethod execute {argv} {
        # FIRST, get the output file name.
        set outfile [lpop argv]

        if {![string match "*.adb" $outfile]} {
            throw FATAL \
                "Missing output file: expected *.adb, got \"$outfile\""
        }

        # NEXT, create a blank scenario.
        athena create sdb

        # NEXT, load the input file if any.
        set infile [lindex $argv 0]

        if {[string match "*.adb" $infile]} {
            lshift argv

            puts "Loading scenario: $infile"
            try {
                sdb load $infile
            } trap {SCENARIO OPEN} {result} {
                throw FATAL "Could not load $infile:\n$result"
            }
        }

        # NEXT apply the scripts and options.  If there are none, there's
        # nothing to.
        if {![got $argv]} {
            throw FATAL "No actions request; no data saved."
        }

        while {[string match "*.tcl" [lindex $argv 0]]} {
            set script [lshift argv]

            puts "Applying script: $script"

            try {
                sdb executive call $script
            } on error {result} {
                vputs $::errorInfo
                throw FATAL "Error in $script:\n$result"
            }
        }

        # NEXT, apply the options
        foroption opt argv -all {
            -run {
                set t [lshift argv]

                if {![string is integer -strict $t] || $t < 0} {
                    throw FATAL "-run: expected time <t> >= 0, got \"$t\"."
                }

                puts "Advancing time to: $t"
                try {
                    sdb lock
                    if {$t > 0} {
                        sdb advance -ticks $t -tickcmd [mytypemethod TickCmd]
                    }
                } on error {result} {
                    vputs $::errorInfo
                    throw FATAL "Error advancing time:\n$result"
                }
            }
        }

        # NEXT, save the results:
        puts "Saving Results: $outfile"

        try {
            sdb save $outfile
        } trap {SCENARIO SAVE} {result} {
            throw FATAL "Could not save $outfile:\n$result"
        }
    }

    #-------------------------------------------------------------------
    # Helper Routines

    typemethod TickCmd {state i n} {
        puts "$state tick $i of $n"
    }
    
}






