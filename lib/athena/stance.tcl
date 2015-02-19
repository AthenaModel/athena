#-----------------------------------------------------------------------
# TITLE:
#    stance.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Tactic API: group stance
#
#    This module is the API used by the STANCE tactic to set the stance
#    of one group (usually a force group) to other groups.  The stance is
#    the horizontal relationship that force group f has been ordered to
#    exhibit toward group g.  Whether and to what extent f is successful
#    at obeying that order depends on f's training level.
#
#    Stance is set by adding an f,g,relationship triple to either the
#    stance_fg or stance_nfg table (in the latter case, the stance is set
#    in that neighborhood only).  An entry in stance_nfg overrides any
#    matching entry in stance_fg.
#
# NOTE:
#    As a tactic API, this one doesn't actually do much.  However, the 
#    "reset" method needs to go somewhere accessible, and in the athena(n)
#    architecture it can no longer be a class method of the tactic::STANCE
#    class.
#
# WARNING:
#    The stance_nfg table isn't currently in use, as it is not required
#    by the existing STANCE tactic.  It would be useful, however, if we
#    wished to have force group f have different stances toward force 
#    group g in different neighborhoods.  Thus, since it is tested and
#    works we are leaving it in the code. 
#    
#-----------------------------------------------------------------------

snit::type ::athena::stance {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Methods

    # reset
    #
    # Clears the stance_* tables prior to the beginning of strategy
    # execution.  Note that stance_nfg is never set at present;
    # see the WARNING in the file header for details.

    method reset {} {
        rdb eval {
            DELETE FROM stance_fg;
            DELETE FROM stance_nfg;
        }
    }

    # setfg f g rel
    #
    # f     - Force group f
    # g     - Another group g
    # drel  - The designated relationship of f towards g.
    #
    # Saves the stance in the stance_fg table.

    method setfg {f g drel} {
        $adb eval {
            INSERT OR IGNORE INTO stance_fg(f,g,stance)
            VALUES($f,$g,$drel)
        }
    }
}
