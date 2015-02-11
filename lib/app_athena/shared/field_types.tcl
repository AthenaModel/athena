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

# concern: An econcern value
dynaform fieldtype alias concern enum \
    -listcmd {econcern names}

dynaform fieldtype alias concernlist enumlonglist \
    -showkeys yes \
    -width 30     \
    -dictcmd {econcern deflist}

# frclist: Pick from a list of force groups; longname shown
dynaform fieldtype alias frclist enumlonglist \
    -showkeys yes \
    -width    30  \
    -dictcmd {::frcgroup namedict}

# grouplist: Pick a list of groups; longname shown
dynaform fieldtype alias grouplist enumlonglist \
    -showkeys yes \
    -width    30  \
    -dictcmd  {::group namedict}

# inject: Pick an inject by its ID.
dynaform fieldtype alias inject dbkey \
    -table gui_injects  \
    -keys  {curse_id inject_num}

# mad: Magic Attitude Driver ID
dynaform fieldtype alias mad dbkey \
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


# payload: Pick a payload by its ID.
dynaform fieldtype alias payload dbkey \
    -table gui_payloads \
    -keys  {iom_id payload_num}

# plant: Pick a plant by its ID.
dynaform fieldtype alias plant dbkey \
    -table gui_plants_na  \
    -keys  {n a}

# posfrac: Fraction, 0.01 to 1.0
dynaform fieldtype alias posfrac range \
    -datatype   ::rposfrac             \
    -resolution 0.01




