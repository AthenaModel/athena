------------------------------------------------------------------------
-- TITLE:
--    experiment.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema for experimentdb(n): Experiment Tables.
--    Support for running experiments consisting of many distinct cases.
--
-- SECTIONS:
--    Case Definition
--    
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- CASE DEFINITION

CREATE TABLE cases (
    -- Experiment Case Table: saves the definition and result status 
    -- for each case.  Cases are assigned IDs automatically.

    -- A unique ID for this case, assigned automatically.
    case_id   INTEGER PRIMARY KEY,

    -- A Tcl dictionary of case parameters and values, defining this
    -- particular case.  The dictionary can be sparse, i.e., only the
    -- case parms that differ from the baseline need be included.
    case_dict TEXT,

    -- The outcome of running the case.
    -- TBD: It's not clear what the full set of outcomes should be,
    -- but it should certainly include the following:
    --
    -- OK      - The case ran to completion normally, and the results
    --           are presumed to be of interest.
    -- FAILURE - The case halted due to some sanity-check failure.
    --           The case has some undesirable property such that
    --           it was abandoned.
    -- ERROR   - Athena produced an error while the case was running;
    --           this is a bug, and should be looked into.
    --
    -- If NULL, the case has not been run.
    outcome   TEXT,

    -- For abnormal outcomes, any information as to why the outcome was
    -- abnormal, in human readable form (i.e., a bgerror)
    context   TEXT
);

CREATE TABLE case_parms (
    -- Case Parameter Definition Table: definitions of the case parameters
    -- for this experiment.  The case parameter settings are translated
    -- into scenario inputs by the case parm scripts.

    -- The name of the case parameter
    name        TEXT PRIMARY KEY,

    -- A brief description of the parameter's meaning
    docstring   TEXT DEFAULT '',

    -- An executive script that will make the scenario changes for this
    -- parameter.  The script can assume that there is a Tcl variable
    -- with the parameter's name and value.
    script      TEXT
);

------------------------------------------------------------------------
-- End of File
------------------------------------------------------------------------


