#-----------------------------------------------------------------------
# FILE: app_types.tcl
#
#   Application Data Types
#
# PACKAGE:
#   app_cellide(n) -- cellide(1) implementation package
#
# PROJECT:
#   Athena S&RO Simulation
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Enumerations

# esortcellby: Options for sorting tables of cells

enum esortcellby {
    name "Cell Name"
    line "Line Number"
}

# echeckstate: Has the model been checked or not, and to what effect?

enum echeckstate {
    unchecked "Unchecked"
    syntax    "Syntax Error"
    insane    "Sanity Error"
    checked   "Checked"
}

# esolvestate: Has the model been solved, and to what effect?

enum esolvestate {
    unsolved "Unsolved"
    diverge  "Diverged"
    errors   "Math Errors"
    ok       "Solved"
}

# esnapshottype: Kinds of snapshot saved by the snapshot model.

enum esnapshottype {
    import   "Import"
    model    "Model"
    solution "Solution"
}

#-----------------------------------------------------------------------
# Integer Types

# A number of interations
snit::integer iiterations -min 1

#-----------------------------------------------------------------------
# Real Types

# An epsilon value
snit::double repsilon -min 0.000001
