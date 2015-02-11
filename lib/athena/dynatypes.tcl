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
#    * Global dependencies: none
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Aliases

# actor: pick an actor by name.
dynaform fieldtype alias actor enum -listcmd {$adb_ actor names}

# agent: pick an agent by name.
dynaform fieldtype alias agent enum -listcmd {$adb_ agent names}

# cap: Pick a cap by name.
dynaform fieldtype alias cap enumlong \
    -showkeys yes \
    -dictcmd  {$adb_ cap namedict}

# civgroup: Pick a CIV group by name; long names shown.
dynaform fieldtype alias civgroup enumlong \
    -showkeys yes \
    -dictcmd  {$adb_ civgroup namedict}

# civlist: Pick a list of CIV groups; long names shown.
dynaform fieldtype alias civlist enumlonglist \
    -showkeys yes \
    -width    30  \
    -dictcmd  {$adb_ civgroup namedict}

# curse: pick a curse by name.
dynaform fieldtype alias curse enum -listcmd {::curse names}

# comparator: An ecomparator value
dynaform fieldtype alias comparator enumlong \
    -dictcmd {ecomparator deflist}

# coop: Pick a cooperation level
dynaform fieldtype alias coop range \
    -datatype    ::qcooperation     \
    -showsymbols yes                \
    -resetvalue  50

# expr: A text field for editing expressions.
dynaform fieldtype alias expr text -width 60

# frac: Fraction, 0.0 to 1.0
dynaform fieldtype alias frac range -datatype ::rfraction

# frcgroup: Pick a force group by name.
dynaform fieldtype alias frcgroup enum -listcmd {$adb_ frcgroup names}

# group: Pick a group by name.
dynaform fieldtype alias group enum -listcmd {$adb_ group names}

# localn: Pick a local neighborhood by name
dynaform fieldtype alias localn enumlong \
    -showkeys yes \
    -dictcmd {$adb_ nbhood local namedict}


# longname: text field of standard width for longnames.
dynaform fieldtype alias longname text -width 30

# nbhood: Pick a neighborhood by name
dynaform fieldtype alias nbhood enumlong \
    -showkeys yes \
    -dictcmd  {$adb_ nbhood namedict}

# nlist: Pick a neighborhood from a list; long names shown.
dynaform fieldtype alias nlist enumlonglist \
    -showkeys yes \
    -width    30  \
    -dictcmd  {$adb_ nbhood namedict}

# orggroup: Pick an ORG group by name.
dynaform fieldtype alias orggroup enum -listcmd {$adb_ orggroup names}

# percent: Pick a percentage.
dynaform fieldtype alias percent range -datatype ::ipercent

# rel: Relationship value
dynaform fieldtype alias rel range \
    -datatype   ::qaffinity \
    -resolution 0.1

# roles: Pick one or more roles to group(s) mapping
dynaform fieldtype alias roles rolemap \
    -listheight 6 \
    -liststripe 1 \
    -listwidth  20

# sat: Pick a satisfaction level
dynaform fieldtype alias sat range \
    -datatype    ::qsat \
    -showsymbols yes    \
    -resetvalue  0.0

# sal: Pick a saliency
dynaform fieldtype alias sal range \
    -datatype    ::qsaliency \
    -showsymbols yes         \
    -resetvalue  1.0 

# yesno: Boolean entry field, compatible with [boolean]
dynaform fieldtype alias yesno enumlong -dict {
    1 Yes
    0 No 
}

