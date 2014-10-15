#-----------------------------------------------------------------------
# TITLE:
#    dynaforms.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_cellide(n) dynaform definitions
#
#    This module contains dynaforms defined for use by the application.
#
#-----------------------------------------------------------------------

dynaform fieldtype alias snapshot enumlong -dictcmd {::snapshot namedict}

dynaform define SnapshotExport {
    rc "Please select the snapshot to export."
    rc
    snapshot snapshot
}

dynaform define ModelSolve {
    rc ""
    c "Select the solution parameters." -width 3in
    br

    rcc "Start From:" -for snapshot 
    snapshot snapshot -defvalue model
    
    rcc "Epsilon:" -for epsilon
    text epsilon -width 8 -defvalue 0.0001

    rcc "Max Iterations:" -for maxiters
    text maxiters -width 8 -defvalue 100
}
