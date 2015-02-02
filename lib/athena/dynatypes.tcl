#-----------------------------------------------------------------------
# TITLE:
#    dynatypes.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): dynaform(n) field type aliases
#
#    This module defines dynaform(n) field types and aliases for use in order
#    dialogs and other data entry forms.  It should be loaded before any order
#    dialogs are defined.
#
# TBD:
#    * Global dependencies: nbhood
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Aliases

# actor: pick an actor by name.
dynaform fieldtype alias actor enum -listcmd {$adb_ actor names}

# civgroup: Pick a CIV group by name; long names shown.
dynaform fieldtype alias civgroup enumlong \
    -showkeys yes \
    -dictcmd  {$adb_ civgroup namedict}

# frcgroup: Pick a force group by name.
dynaform fieldtype alias frcgroup enum -listcmd {$adb_ frcgroup names}

# longname: text field of standard width for longnames.
dynaform fieldtype alias longname text -width 30

# nbhood: Pick a neighborhood by name
dynaform fieldtype alias nbhood enumlong \
    -showkeys yes \
    -dictcmd  {::nbhood namedict}

# yesno: Boolean entry field, compatible with [boolean]
dynaform fieldtype alias yesno enumlong -dict {
    1 Yes
    0 No 
}

