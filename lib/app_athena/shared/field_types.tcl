#-----------------------------------------------------------------------
# TITLE:
#    field_types.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): dynaform(n) field type aliases
#
#    This module defines dynaform(n) field types and aliases for use in order
#    dialogs and other data entry forms.  It should be loaded before any order
#    dialogs are defined.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Aliases

# actorlist: pick a list of actors by name
dynaform fieldtype alias actorlist enumlonglist \
    -showkeys yes \
    -width    30  \
    -dictcmd {::actor namedict}

# agent: pick an agent by name.
dynaform fieldtype alias agent enum -listcmd {::agent names}

# cap: Pick a cap by name.
dynaform fieldtype alias cap enumlong \
    -showkeys yes \
    -dictcmd  {::cap namedict}

# civgroup: Pick a CIV group by name; long names shown.
dynaform fieldtype alias civgroup enumlong \
    -showkeys yes \
    -dictcmd  {::civgroup namedict}

# civlist: Pick a list of CIV groups; long names shown.
dynaform fieldtype alias civlist enumlonglist \
    -showkeys yes \
    -width    30  \
    -dictcmd  {::civgroup namedict}

# comparator: An ecomparator value
dynaform fieldtype alias comparator enumlong \
    -dictcmd {ecomparator deflist}

# concern: An econcern value
dynaform fieldtype alias concern enum \
    -listcmd {econcern names}

dynaform fieldtype alias concernlist enumlonglist \
    -showkeys yes \
    -width 30     \
    -dictcmd {econcern deflist}

# coop: Pick a cooperation level
dynaform fieldtype alias coop range \
    -datatype    ::qcooperation     \
    -showsymbols yes                \
    -resetvalue  50

# curse: pick a curse by name.
dynaform fieldtype alias curse enum -listcmd {::curse names}

# expr: A text field for editing expressions.
dynaform fieldtype alias expr text -width 60

# frac: Fraction, 0.0 to 1.0
dynaform fieldtype alias frac range -datatype ::rfraction

# frcgroup: Pick a force group by name.
dynaform fieldtype alias frcgroup enum -listcmd {::frcgroup names}

# frclist: Pick from a list of force groups; longname shown
dynaform fieldtype alias frclist enumlonglist \
    -showkeys yes \
    -width    30  \
    -dictcmd {::frcgroup namedict}

# group: Pick a group by name.
dynaform fieldtype alias group enum -listcmd {::group names}

# grouplist: Pick a list of groups; longname shown
dynaform fieldtype alias grouplist enumlonglist \
    -showkeys yes \
    -width    30  \
    -dictcmd  {::group namedict}

# hook: Pick a hook ID
dynaform fieldtype alias hook key \
    -db    ::rdb \
    -table hooks \
    -keys  hook_id

# inject: Pick an inject by its ID.
dynaform fieldtype alias inject key \
    -db    ::rdb        \
    -table gui_injects  \
    -keys  {curse_id inject_num}

# plant: Pick a plant by its ID.
dynaform fieldtype alias plant key \
    -db    ::rdb        \
    -table gui_plants_na  \
    -keys  {n a}

# key: key fields should get -db automatically.
dynaform fieldtype alias key key -db ::rdb

# mad: Magic Attitude Driver ID
dynaform fieldtype alias mad key \
    -db       ::rdb     \
    -table    gui_mads  \
    -keys     mad_id    \
    -dispcols longid    \
    -widths   40

# mag: qmag(n) values
dynaform fieldtype alias mag range \
    -datatype    ::qmag \
    -showsymbols yes    \
    -resetvalue  0.0    \
    -resolution  0.5    \
    -min         -40.0  \
    -max         40.0

# multi: multi fields should get -db automatically.
dynaform fieldtype alias multi multi -db ::rdb

# nbhood: Pick a neighborhood by name
dynaform fieldtype alias nbhood enumlong \
    -showkeys yes \
    -dictcmd  {::nbhood namedict}

# localn: Pick a local neighborhood by name
dynaform fieldtype alias localn enumlong \
    -showkeys yes \
    -dictcmd {::nbhood local namedict}

# nlist: Pick a neighborhood from a list; long names shown.
dynaform fieldtype alias nlist enumlonglist \
    -showkeys yes \
    -width    30  \
    -dictcmd  {::nbhood namedict}

# orggroup: Pick an ORG group by name.
dynaform fieldtype alias orggroup enum -listcmd {::orggroup names}

# payload: Pick a payload by its ID.
dynaform fieldtype alias payload key \
    -db    ::rdb        \
    -table gui_payloads \
    -keys  {iom_id payload_num}

# percent: Pick a percentage.
dynaform fieldtype alias percent range -datatype ::ipercent

# posfrac: Fraction, 0.01 to 1.0
dynaform fieldtype alias posfrac range \
    -datatype   ::rposfrac             \
    -resolution 0.01

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


