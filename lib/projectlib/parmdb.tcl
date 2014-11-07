#-----------------------------------------------------------------------
# TITLE:
#    parmdb.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena model parameter database
#
#    The module delegates most of its function to parmset(n).
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export parmdb
}

#-------------------------------------------------------------------
# First, define the parameter value types used in this database

# Real Quantity
::marsutil::range ::projectlib::parmdb_rquantity \
    -min 0.0 -format "%.2f"

# Loss Exchange Ratio
::marsutil::range ::projectlib::parmdb_ler \
    -min 0.01 -format "%.2f"

# Nominal coverage
::marsutil::range ::projectlib::parmdb_nomcoverage \
    -min 0.1 -max 1.0 -format "%+5.2f"

# Nominal cooperation
::marsutil::range ::projectlib::parmdb_nomcoop \
    -min 10.0 -max 100.0 -format "%5.1f"

# Positive Days
::marsutil::range ::projectlib::parmdb_posdays \
    -min 0.1 -format "%.2f"

# Idle Fraction
::marsutil::range ::projectlib::parmdb_idlefrac \
    -min 0.0 -max 0.9 -format "%.2f"

# Positive Cobb-Douglas parameter
::marsutil::range ::projectlib::parmdb_posCD \
    -min 0.05 -max 1.0 -format "%.2f"

# Non-negative security
snit::integer ::projectlib::parmdb_nnsec \
    -min 1 -max 100


#-------------------------------------------------------------------
# parm

snit::type ::projectlib::parmdb {
    # Make it a singleton
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Typecomponents

    typecomponent ps ;# The parmset(n) object

    #-------------------------------------------------------------------
    # Public typemethods

    delegate typemethod * to ps

    # init
    #
    # Initializes the module

    typemethod init {} {
        # Don't initialize twice.
        if {$ps ne ""} {
            return
        }

        # FIRST, create the parmset.
        set ps [parmset %AUTO%]

        # NEXT, create an "in-memory" scenariodb, for concerns
        # and activities.
        set tempdb ${type}::tempdb
        catch {$tempdb destroy}
        scenariodb $tempdb
        $tempdb open :memory:

        # NEXT, Simulation Control parameters
        $ps subset sim {
            Parameters that affect the simulation at a basic level.
        }

        $ps define sim.tickTransaction ::snit::boolean yes {
            If yes, the time advance (or tick) activities are wrapped
            in an SQL transaction, which makes them considerably
            faster, but means that RDB changes made during the tick
            are lost if tick code throws an unexpected error.  If no,
            no enclosing transaction is used; the tick activities will
            be much slower, but the data required for debugging will
            remain.
        }

        # absit.* parameters
        $ps subset absit {
            Environmental situation parameters, by absit type.
        }

        foreach name [eabsit names] {
            $ps subset absit.$name "
                Parameters for abstract situation type
                [eabsit longname $name].
            "

            $ps define absit.$name.duration ::projectlib::iticks 0 {
                How long until the absit auto-resolves, in integer
                ticks.  If 0, the absit never auto-resolves.
            }
        }

        # Tweak the specifics
        $ps setdefault absit.BADFOOD.duration        2
        $ps setdefault absit.BADWATER.duration       1
        $ps setdefault absit.COMMOUT.duration        1
        $ps setdefault absit.CULSITE.duration        6
        $ps setdefault absit.DISASTER.duration       6
        $ps setdefault absit.DISEASE.duration        4
        $ps setdefault absit.DROUGHT.duration        52
        $ps setdefault absit.EPIDEMIC.duration       52
        $ps setdefault absit.FOODSHRT.duration       26
        $ps setdefault absit.FUELSHRT.duration       4
        $ps setdefault absit.GARBAGE.duration        6
        $ps setdefault absit.INDSPILL.duration       12
        $ps setdefault absit.MINEFIELD.duration      156
        $ps setdefault absit.NOWATER.duration        2
        $ps setdefault absit.ORDNANCE.duration       78
        $ps setdefault absit.PIPELINE.duration       1
        $ps setdefault absit.POWEROUT.duration       8
        $ps setdefault absit.REFINERY.duration       1
        $ps setdefault absit.RELSITE.duration        6
        $ps setdefault absit.SEWAGE.duration         9
        $ps setdefault absit.TRAFFIC.duration        1

        # NEXT, Activity Parameters

        $ps subset activity {
            Parameters which affect the computation of group activity
            coverage.
        }

        $ps subset activity.FRC {
            Parameters which affect the computation of force group
            activity coverage.
        }

        $ps subset activity.ORG {
            Parameters which affect the computation of organization group
            activity coverage.
        }

        # FRC activities
        foreach a {
            CHKPOINT
            COERCION
            CONSTRUCT
            CRIME
            CURFEW
            EDU
            EMPLOY
            GUARD
            INDUSTRY
            INFRA
            LAWENF
            MEDICAL
            PATROL
            PRESENCE
            PSYOP
            RELIEF
        } {
            $ps subset activity.FRC.$a {
                Parameters relating to this force activity.
            }

            if {$a ne "PRESENCE"} {
                $ps define activity.FRC.$a.cost ::projectlib::money 0 {
                    The cost, in dollars, to assign one person to do this
                    activity for one strategy tock, i.e., for one week.
                    The dollar amount may be defined with a "K", "M", or
                    "B" suffix to connote thousands, millions, or billions.
                }
            }
            
            $ps define activity.FRC.$a.minSecurity ::projectlib::qsecurity L {
                Minimum security level required to conduct this
                activity.
            }

            $ps define activity.FRC.$a.coverage ::simlib::coverage {
                25.0 1000
            } {
                The parameters (c, d) that determine the
                coverage fraction function for this force activity.  Coverage
                depends on the asset density, which is the number
                of personnel conducting the activity per d people in the 
                population.  If the density is 0, the coverage is 0.  The 
                coverage fraction increases to 2/3 when density is c.
            }
        }

        # ORG activities
        foreach a {
            CONSTRUCT
            EDU
            EMPLOY
            INDUSTRY
            INFRA
            MEDICAL
            RELIEF
        } {
            $ps subset activity.ORG.$a {
                Parameters relating to this organization activity.
            }

            $ps define activity.ORG.$a.cost ::projectlib::money 0 {
                The cost, in dollars, to assign one person to do this
                activity for one strategy tock, i.e., for one week.
                The dollar amount may be defined with a "K", "M", or
                "B" suffix to connote thousands, millions, or billions.
            }

            $ps subset activity.ORG.$a.minSecurity {
                Minimum security levels required to conduct this
                activity, by organization type.
            }

            foreach orgtype [eorgtype names] {
                 $ps define activity.ORG.$a.minSecurity.$orgtype \
                     ::projectlib::qsecurity H {
                         Minimum security level required to conduct this
                         activity.
                     }
            }

            $ps define activity.ORG.$a.coverage ::simlib::coverage {
                20.0 1000
            } {
                The parameters (c, d) that determine the
                coverage fraction function for this activity.  Coverage
                depends on the asset density, which is the number
                of personnel conducting the activity per d people in the 
                population.  If the density is 0, the coverage is 0.  
                The coverage fraction increases to 2/3 when density is c.
            }
         }

        # FRC Activities

        # Activity: PRESENCE
        $ps setdefault activity.FRC.PRESENCE.minSecurity  N
        $ps setdefault activity.FRC.PRESENCE.coverage     {25 1000}

        # Activity: CHKPOINT
        $ps setdefault activity.FRC.CHKPOINT.minSecurity  L
        $ps setdefault activity.FRC.CHKPOINT.coverage     {25 1000}

        # Activity: COERCION
        $ps setdefault activity.FRC.COERCION.minSecurity  M
        $ps setdefault activity.FRC.COERCION.coverage     {12 1000}

        # Activity: CONSTRUCT
        $ps setdefault activity.FRC.CONSTRUCT.minSecurity H
        $ps setdefault activity.FRC.CONSTRUCT.coverage    {20 1000}

        # Activity: CRIME
        $ps setdefault activity.FRC.CRIME.minSecurity     M
        $ps setdefault activity.FRC.CRIME.coverage        {10 1000}

        # Activity: CURFEW
        $ps setdefault activity.FRC.CURFEW.minSecurity    M
        $ps setdefault activity.FRC.CURFEW.coverage       {25 1000}

        # Activity: EDU
        $ps setdefault activity.FRC.EDU.minSecurity       H
        $ps setdefault activity.FRC.EDU.coverage          {20 1000}

        # Activity: EMPLOY
        $ps setdefault activity.FRC.EMPLOY.minSecurity    H
        $ps setdefault activity.FRC.EMPLOY.coverage       {20 1000}

        # Activity: GUARD
        $ps setdefault activity.FRC.GUARD.minSecurity     L
        $ps setdefault activity.FRC.GUARD.coverage        {25 1000}

        # Activity: INDUSTRY
        $ps setdefault activity.FRC.INDUSTRY.minSecurity  H
        $ps setdefault activity.FRC.INDUSTRY.coverage     {20 1000}

        # Activity: INFRA
        $ps setdefault activity.FRC.INFRA.minSecurity     H
        $ps setdefault activity.FRC.INFRA.coverage        {20 1000}

        # Activity: LAWENF
        $ps setdefault activity.FRC.LAWENF.minSecurity    M
        $ps setdefault activity.FRC.LAWENF.coverage       {25 1000}

        # Activity: MEDICAL
        $ps setdefault activity.FRC.MEDICAL.minSecurity   H
        $ps setdefault activity.FRC.MEDICAL.coverage      {20 1000}

        # Activity: PATROL
        $ps setdefault activity.FRC.PATROL.minSecurity    L
        $ps setdefault activity.FRC.PATROL.coverage       {25 1000}

        # Activity: PSYOP
        $ps setdefault activity.FRC.PSYOP.minSecurity     L
        $ps setdefault activity.FRC.PSYOP.coverage        {1 50000}

        # Activity: RELIEF
        $ps setdefault activity.FRC.RELIEF.minSecurity    H
        $ps setdefault activity.FRC.RELIEF.coverage       {20 1000}

        # ORG Activities
        # All parameters use defaults.

        # app.* parameters
        $ps subset app {
            Parameters related to how the Athena application should behave
            under certain circumstances. For now, this is limited to
            only developer user.
        }

        $ps define app.dev ::projectlib::boolean no {
            This flag indicates areas of Athena that should not be
            accessed because they are under development
            and should not be used in the course of running. This flag
            also provides a way of marking the code clearly for these types
            of areas.
        }

        # attitude.* parameters
        $ps subset attitude {
            Parameters related to Athena's attitudes model.  Note that
            parameters implemented by URAM are in the uram.* hierarchy.
        }

        foreach att {COOP HREL SAT VREL} {
            $ps subset attitude.$att {
                Parameters relating to $att curves.
            }

            $ps define attitude.$att.gain ::projectlib::rgain 1.0 {
                The input gain for attitude inputs of this type.
                Increase the gain to make Athena run "hotter",
                decrease it to make Athena run "colder".
            }
        }

        $ps subset attitude.SFT {
            Parameters related to SFT satisfaction curves.
        }

        $ps define attitude.SFT.Znatural ::marsutil::zcurve \
            {-100.0 -100.0 100.0 100.0} {
                A Z-curve for computing the natural level of
                SFT satisfaction curves from the civilian group's
                security.  The default curve simply equates the two.
                The output may not exceed the range (-100.0, +100.0).
            }

        # control.* parameters
        $ps subset control {
            Parameters related to the determination of group/actor
            relationships, actor influence and support, and neighborhood
            control.
        }

        $ps subset control.support {
            Parameters related to the computation of the support of a
            neighborhood for a particular actor.
        }

        $ps define control.support.min ::simlib::rfraction 0.1 {
            The minimum support than actor a can have in neighborhood
            n and still be able to take control of neighborhood n.
        }

        $ps define control.support.vrelMin ::simlib::rfraction 0.2 {
            The minimum V.ga that group g can have for actor a and
            still be deemed to be a supporter of a.
        }

        $ps define control.support.Zsecurity ::marsutil::zcurve \
            {0.0 -25 25 1.0} {
                A Z-curve for computing a group's security factor
                in a neighborhood, that is, the degree to which the
                group can support an actor given their current
                security level.  The input is the group's security
                level, -100 to +100; the output is a factor from 0.0
                to 1.0.
        }

        $ps define control.threshold ::simlib::rfraction 0.5 {
            The minimum influence.na an actor must have to become
            "in control" of a neighborhood.
        }

        # dam.* parameters
        $ps subset dam {
            Driver Assessment Model rule/rule set parameters.
        }

        # Global parameters
        #
        # TBD

        # Abevent global parameters
        $ps subset dam.abevent {
            Parameters for the abstract event rule sets in general.
        }

        $ps define dam.abevent.nominalCoverage \
            ::projectlib::parmdb_nomcoverage 0.5 \
            {
                The nominal coverage fraction for abstract
                event rule sets.
                Input magnitudes are specified for this nominal coverage,
                i.e., if a change is specified as "cov * M+" the input
                will be "M+" when "cov" equals the nominal coverage.  The
                valid range is 0.1 to 1.0.
            }

        # Absit global parameters
        $ps subset dam.absit {
            Parameters for the abstract situation rule sets in general.
        }

        $ps define dam.absit.nominalCoverage \
            ::projectlib::parmdb_nomcoverage 1.0 \
            {
                The nominal coverage fraction for abstract
                situation rule sets.
                Input magnitudes are specified for this nominal coverage,
                i.e., if a change is specified as "cov * M+" the input
                will be "M+" when "cov" equals the nominal coverage.  The
                valid range is 0.1 to 1.0.
        }

        # Actsit global parameters
        $ps subset dam.actsit {
            Parameters for the activity situation rule sets in general.
        }

        $ps define dam.actsit.nominalCoverage \
            ::projectlib::parmdb_nomcoverage 0.66 \
            {
                The nominal coverage fraction for activity rule sets.
                Input magnitudes are specified for this nominal coverage,
                i.e., if a change is specified as "cov * M+" the input
                will be "M+" when "cov" equals the nominal coverage.  The
                valid range is 0.1 to 1.0.
            }


        # First, give each an "active" flag.
        foreach name [edamruleset names] {
            $ps subset dam.$name "
                Parameters for DAM rule set $name.
            "

            $ps define dam.$name.active ::projectlib::boolean yes {
                Indicates whether the rule set is active or not.
            }

            # NEXT, set the default cause to the first one, it will
            # be overridden below.
            $ps define dam.$name.cause ::projectlib::ecause MAGIC "
                The \"cause\" for all URAM inputs produced by this
                rule set.  The value must be a valid cause, one of:
                [join [ecause names] {, }].
            "

            $ps define dam.$name.nearFactor ::simlib::rfraction 0.0 {
                Strength of indirect satisfaction effects in neighborhoods
                which consider themselves "near" to the neighborhood in
                which the rule set fires.
            }

            $ps define dam.$name.farFactor ::simlib::rfraction 0.0 {
                Strength of indirect satisfaction effects in neighborhoods
                which consider themselves "far" from the neighborhood in
                which the rule set fires.
            }

            # Add mitigates parm for activities that support mitigation
            # of absits. 
            if {$name in {
                CONSTRUCT
                EDU
                EMPLOY
                INDUSTRY
                INFRA
                MEDICAL
                RELIEF
            }} {
                $ps define dam.$name.mitigates ::projectlib::leabsit {} {
                    List of abstract situation types mitigated by this
                    activity.  Note not all rule sets support this.
                }
            }

            # Add CONSUMP defaults for when econ is disabled
            if {$name eq "CONSUMP"} {
                $ps subset dam.CONSUMP.expectf {
                    Expectations factor parameters for the CONSUMP ruleset.
                    Note that these parameters only apply if the econ model
                    is disabled.
                }

                $ps subset dam.CONSUMP.povfrac {
                    Poverty fraction parameters for the CONSUMP ruleset.
                    Note that these parameters only apply if the econ model
                    is disabled.
                }

                foreach urb [eurbanization names] {
                    $ps define dam.CONSUMP.expectf.$urb \
                        ::projectlib::expectf 0.0 "
                            The default expectations factor by urbanization
                            that the CONSUMP ruleset uses only if the econ 
                            model is disabled.  When set to 0.0, all civilians
                            in neighborhoods with urbanization $urb are getting 
                            their expected level of consumption. The valid
                            range of values is -3.0 (civilians are consuming
                            much less than they expect) to 3.0 (civilians are 
                            consuming much much more than they expect).
                            "
                    $ps define dam.CONSUMP.povfrac.$urb \
                        ::simlib::rfraction 0.1 " 
                            The default poverty fraction by urbanization that
                            the CONSUMP ruleset uses only if the econ model is
                            disabled.  This represent the fraction of 
                            civilians in neighborhoods with urbanization $urb
                            that are below the poverty line. The valid range
                            of values is 0.0 to 1.0
                            "
                }
            }
        }

        # Rule Set: ACCIDENT
        $ps setdefault dam.ACCIDENT.cause         DISASTER
        $ps setdefault dam.ACCIDENT.nearFactor    0.0
        $ps setdefault dam.ACCIDENT.farFactor     0.0

        # Rule Set: BADFOOD
        $ps setdefault dam.BADFOOD.cause          HUNGER
        $ps setdefault dam.BADFOOD.nearFactor     0.0
        $ps setdefault dam.BADFOOD.farFactor      0.0

        # Rule Set: BADWATER
        $ps setdefault dam.BADWATER.cause         THIRST
        $ps setdefault dam.BADWATER.nearFactor    0.0
        $ps setdefault dam.BADWATER.farFactor     0.0

        # Rule Set: CHKPOINT
        $ps setdefault dam.CHKPOINT.cause         CHKPOINT
        $ps setdefault dam.CHKPOINT.nearFactor    0.25
        $ps setdefault dam.CHKPOINT.farFactor     0.0

        # Rule Set: CIVCAS
        $ps setdefault dam.CIVCAS.cause           CIVCAS
        $ps setdefault dam.CIVCAS.nearFactor      0.25
        $ps setdefault dam.CIVCAS.farFactor       0.1

        # Add additional parameters for CIVCAS rule sets
        $ps define dam.CIVCAS.Zsat ::marsutil::zcurve {0.3 1.0 100.0 2.0} {
            Z-curve used to compute the casualty multiplier used in
            the CIVCAS satisfaction rules from the number of civilian
            casualties.
        }

        $ps define dam.CIVCAS.Zcoop ::marsutil::zcurve {0.3 1.0 100.0 2.0} {
            Z-curve used to compute the casualty multiplier used in
            the CIVCAS cooperation rule from the number of civilian
            casualties.
        }

        # Rule Set: CONSTRUCT
        $ps setdefault dam.CONSTRUCT.cause        CONSTRUCT
        $ps setdefault dam.CONSTRUCT.nearFactor   0.75
        $ps setdefault dam.CONSTRUCT.farFactor    0.25
        $ps setdefault dam.CONSTRUCT.mitigates    {
            BADFOOD  BADWATER COMMOUT  CULSITE  DISASTER DISEASE
            EPIDEMIC FOODSHRT FUELSHRT GARBAGE  INDSPILL MINEFIELD
            NOWATER  ORDNANCE PIPELINE POWEROUT REFINERY RELSITE   SEWAGE
        }

        # Rule Set: COERCION
        $ps setdefault dam.COERCION.cause         COERCION
        $ps setdefault dam.COERCION.nearFactor    0.5
        $ps setdefault dam.COERCION.farFactor     0.2

        # Rule Set: COMMOUT
        $ps setdefault dam.COMMOUT.cause          COMMOUT
        $ps setdefault dam.COMMOUT.nearFactor     0.1
        $ps setdefault dam.COMMOUT.farFactor      0.1

        # Rule Set: CONTROL
        $ps setdefault dam.CONTROL.cause          CONTROL
        $ps setdefault dam.CONTROL.nearFactor     0.2
        $ps setdefault dam.CONTROL.farFactor      0.0

        # Rule Set: CRIME
        $ps setdefault dam.CRIME.cause            CRIME
        $ps setdefault dam.CRIME.nearFactor       0.5
        $ps setdefault dam.CRIME.farFactor        0.2

        # Rule Set: CURFEW
        $ps setdefault dam.CURFEW.cause           CURFEW
        $ps setdefault dam.CURFEW.nearFactor      0.5
        $ps setdefault dam.CURFEW.farFactor       0.0

        # Rule Set: CULSITE
        $ps setdefault dam.CULSITE.cause          CULSITE
        $ps setdefault dam.CULSITE.nearFactor     0.1
        $ps setdefault dam.CULSITE.farFactor      0.1

        # Rule Set: DEMO
        $ps setdefault dam.DEMO.cause             DEMO
        $ps setdefault dam.DEMO.nearFactor        0.0
        $ps setdefault dam.DEMO.farFactor         0.0

        # Rule Set: DISASTER
        $ps setdefault dam.DISASTER.cause         DISASTER
        $ps setdefault dam.DISASTER.nearFactor    0.0
        $ps setdefault dam.DISASTER.farFactor     0.0

        # Rule Set: DISPLACED
        $ps setdefault dam.DISPLACED.active       0
        $ps setdefault dam.DISPLACED.cause        DISPLACED
        $ps setdefault dam.DISPLACED.nearFactor   0.25
        $ps setdefault dam.DISPLACED.farFactor    0.0

        # Rule Set: DROUGHT
        $ps setdefault dam.DROUGHT.cause          DISASTER
        $ps setdefault dam.DROUGHT.nearFactor     0.0
        $ps setdefault dam.DROUGHT.farFactor      0.0

        # Rule Set: EDU
        $ps setdefault dam.EDU.cause              EDU
        $ps setdefault dam.EDU.nearFactor         0.75
        $ps setdefault dam.EDU.farFactor          0.5
        $ps setdefault dam.EDU.mitigates          {}

        # Rule Set: EMPLOY
        $ps setdefault dam.EMPLOY.cause           EMPLOY
        $ps setdefault dam.EMPLOY.nearFactor      0.75
        $ps setdefault dam.EMPLOY.farFactor       0.5
        $ps setdefault dam.EMPLOY.mitigates       {}

        # Rule Set: ENERGY
        $ps setdefault dam.ENERGY.cause          ENERGY
        $ps setdefault dam.ENERGY.nearFactor     0.25
        $ps setdefault dam.ENERGY.farFactor      0.0

        # Rule Set: ENI
        $ps setdefault dam.ENI.cause              ENI
        $ps setdefault dam.ENI.nearFactor         0.25
        $ps setdefault dam.ENI.farFactor          0.0

        # Rule Set: EPIDEMIC
        $ps setdefault dam.EPIDEMIC.cause         SICKNESS
        $ps setdefault dam.EPIDEMIC.nearFactor    0.5
        $ps setdefault dam.EPIDEMIC.farFactor     0.2

        # Rule Set: EXPLOSION
        $ps setdefault dam.EXPLOSION.cause        CIVCAS
        $ps setdefault dam.EXPLOSION.nearFactor   0.0
        $ps setdefault dam.EXPLOSION.farFactor    0.0

        # Rule Set: FOODSHRT
        $ps setdefault dam.FOODSHRT.cause         HUNGER
        $ps setdefault dam.FOODSHRT.nearFactor    0.1
        $ps setdefault dam.FOODSHRT.farFactor     0.0

        # Rule Set: FUELSHRT
        $ps setdefault dam.FUELSHRT.cause         FUELSHRT
        $ps setdefault dam.FUELSHRT.nearFactor    0.1
        $ps setdefault dam.FUELSHRT.farFactor     0.0

        # Rule Set: GARBAGE
        $ps setdefault dam.GARBAGE.cause          GARBAGE
        $ps setdefault dam.GARBAGE.nearFactor     0.0
        $ps setdefault dam.GARBAGE.farFactor      0.0

        # Rule Set: GUARD
        $ps setdefault dam.GUARD.cause            GUARD
        $ps setdefault dam.GUARD.nearFactor       0.5
        $ps setdefault dam.GUARD.farFactor        0.0

        # Rule Set: INDSPILL
        $ps setdefault dam.INDSPILL.cause         INDSPILL
        $ps setdefault dam.INDSPILL.nearFactor    0.0
        $ps setdefault dam.INDSPILL.farFactor     0.0

        # Rule Set: INDUSTRY
        $ps setdefault dam.INDUSTRY.cause         INDUSTRY
        $ps setdefault dam.INDUSTRY.nearFactor    0.75
        $ps setdefault dam.INDUSTRY.farFactor     0.25
        $ps setdefault dam.INDUSTRY.mitigates     {
            COMMOUT  FOODSHRT FUELSHRT INDSPILL NOWATER PIPELINE
            POWEROUT REFINERY
        }

        # Rule Set: INFRA
        $ps setdefault dam.INFRA.cause            INFRA
        $ps setdefault dam.INFRA.nearFactor       0.75
        $ps setdefault dam.INFRA.farFactor        0.25
        $ps setdefault dam.INFRA.mitigates        {
            BADWATER COMMOUT NOWATER POWEROUT SEWAGE
        }

        # Rule Set: IOM
        $ps setdefault dam.IOM.cause         IOM
        $ps setdefault dam.IOM.nearFactor    0.0
        $ps setdefault dam.IOM.farFactor     0.0

        # Additional parameters for IOM rule set.
        $ps define dam.IOM.nominalCAPcov \
            ::projectlib::parmdb_nomcoverage 0.66 {
            The nominal CAP Coverage fraction for this rule set.  The effect
            magnitudes entered by the user as part of the IOM are
            specified for this nominal coverage, i.e., if the effect is
            "M+" in the IOM, the value will be "M+" when the CAP Coverage
            is the nominal coverage and will be scaled up and down from
            there.  The valid range is 0.1 to 1.0.
        }

        $ps define dam.IOM.Zresonance ::marsutil::zcurve {0.0 0.0 0.6 1.0} {
            A Z-curve for computing the "resonance" of an IOM's semantic
            hook with a civilian group from the civilian group's affinity
            for the hook.  The Z-curve has been chosen so that groups with a
            negative affinity receive no effect.  Some backfiring might be
            reasonable, so the <i>lo</i> value could easily be decreased to,
            say, -0.1.
        }

        # Rule Set: LAWENF
        $ps setdefault dam.LAWENF.cause           LAWENF
        $ps setdefault dam.LAWENF.nearFactor      0.5
        $ps setdefault dam.LAWENF.farFactor       0.25

        # Rule Set: MEDICAL
        $ps setdefault dam.MEDICAL.cause          MEDICAL
        $ps setdefault dam.MEDICAL.nearFactor     0.75
        $ps setdefault dam.MEDICAL.farFactor      0.25
        $ps setdefault dam.MEDICAL.mitigates      {
            DISASTER DISEASE EPIDEMIC
        }

        # Rule Set: MINEFIELD
        $ps setdefault dam.MINEFIELD.cause        ORDNANCE
        $ps setdefault dam.MINEFIELD.nearFactor   0.2
        $ps setdefault dam.MINEFIELD.farFactor    0.0

        # Rule Set: MOOD
        $ps setdefault dam.MOOD.cause             MOOD
        $ps setdefault dam.MOOD.nearFactor        0.0
        $ps setdefault dam.MOOD.farFactor         0.0

        # Add additional parameters for MOOD rule set
        $ps define dam.MOOD.threshold ::projectlib::parmdb_rquantity 5.0 {
            Delta-mood threshold; changes in civilian mood will only
            affect vertical relationships if the absolute change
            in mood meets or exceeds this threshold.
        }

        # Rule Set: NOWATER
        $ps setdefault dam.NOWATER.cause          THIRST
        $ps setdefault dam.NOWATER.nearFactor     0.1
        $ps setdefault dam.NOWATER.farFactor      0.0

        # Rule Set: ORDNANCE
        $ps setdefault dam.ORDNANCE.cause         ORDNANCE
        $ps setdefault dam.ORDNANCE.nearFactor    0.0
        $ps setdefault dam.ORDNANCE.farFactor     0.0

        # Rule Set: UNEMP
        $ps setdefault dam.UNEMP.cause            UNEMP
        $ps setdefault dam.UNEMP.nearFactor       0.2
        $ps setdefault dam.UNEMP.farFactor        0.0

        # Rule Set: PATROL
        $ps setdefault dam.PATROL.cause           PATROL
        $ps setdefault dam.PATROL.nearFactor      0.5
        $ps setdefault dam.PATROL.farFactor       0.0

        # Rule Set: PIPELINE
        $ps setdefault dam.PIPELINE.cause         PIPELINE
        $ps setdefault dam.PIPELINE.nearFactor    0.0
        $ps setdefault dam.PIPELINE.farFactor     0.0

        # Rule Set: POWEROUT
        $ps setdefault dam.POWEROUT.cause         POWEROUT
        $ps setdefault dam.POWEROUT.nearFactor    0.1
        $ps setdefault dam.POWEROUT.farFactor     0.0

        # Rule Set: PRESENCE
        $ps setdefault dam.PRESENCE.active        0
        $ps setdefault dam.PRESENCE.cause         PRESENCE
        $ps setdefault dam.PRESENCE.nearFactor    0.25
        $ps setdefault dam.PRESENCE.farFactor     0.0

        # Rule Set: PSYOP
        $ps setdefault dam.PSYOP.cause            PSYOP
        $ps setdefault dam.PSYOP.nearFactor       0.1
        $ps setdefault dam.PSYOP.farFactor        0.0

        # Rule Set: REFINERY
        $ps setdefault dam.REFINERY.cause         REFINERY
        $ps setdefault dam.REFINERY.nearFactor    0.0
        $ps setdefault dam.REFINERY.farFactor     0.0

        # Rule Set: RELIEF
        $ps setdefault dam.RELIEF.cause           RELIEF
        $ps setdefault dam.RELIEF.nearFactor      0.25
        $ps setdefault dam.RELIEF.farFactor       0.1
        $ps setdefault dam.RELIEF.mitigates       {
            BADFOOD  BADWATER COMMOUT  CULSITE  DISASTER DISEASE
            EPIDEMIC FOODSHRT FUELSHRT GARBAGE  INDSPILL MINEFIELD
            NOWATER  ORDNANCE PIPELINE POWEROUT REFINERY RELSITE
            SEWAGE
        }

        # Rule Set: RELSITE
        $ps setdefault dam.RELSITE.cause          RELSITE
        $ps setdefault dam.RELSITE.nearFactor     0.1
        $ps setdefault dam.RELSITE.farFactor      0.1

        # Rule Set: RIOT
        $ps setdefault dam.RIOT.cause             CIVCAS
        $ps setdefault dam.RIOT.nearFactor        0.0
        $ps setdefault dam.RIOT.farFactor         0.0

        # Rule Set: SEWAGE
        $ps setdefault dam.SEWAGE.cause           SEWAGE
        $ps setdefault dam.SEWAGE.nearFactor      0.2
        $ps setdefault dam.SEWAGE.farFactor       0.0

        # Rule Set: TRAFFIC
        $ps setdefault dam.TRAFFIC.cause          TRAFFIC
        $ps setdefault dam.TRAFFIC.nearFactor     0.0
        $ps setdefault dam.TRAFFIC.farFactor      0.0

        # Rule Set: TRANSPORT
        $ps setdefault dam.TRANSPORT.cause        TRANSPORT
        $ps setdefault dam.TRANSPORT.nearFactor   0.25
        $ps setdefault dam.TRANSPORT.farFactor    0.1

        # Rule Set: VIOLENCE
        $ps setdefault dam.VIOLENCE.cause         CIVCAS
        $ps setdefault dam.VIOLENCE.nearFactor    0.0
        $ps setdefault dam.VIOLENCE.farFactor     0.0

        # Rule Set: WATER
        $ps setdefault dam.WATER.cause            WATER
        $ps setdefault dam.WATER.nearFactor       0.4
        $ps setdefault dam.WATER.farFactor        0.0

        # demog.* parameters
        $ps subset demog {
            Demographics Model parameters.
        }

        $ps define demog.turFrac ::simlib::rfraction 0.04 {
            The turbulence fraction of those in the labor force. This
            fraction represents those individuals that are "between jobs"
            and, thus, make up a portion of the unemployed.
        }
        
        $ps define demog.playboxUR ::projectlib::rpercent 0.0 {
            Playbox wide unemployment rate to use if the economic 
            model is disabled.  This value will be treated as if it had come
            from the economic model CGE.  Valid values are from 0.0 to 100.0.
        }

        $ps subset demog.consump {
            Parameters related to the Demographics model's consumption
            model.
        }
        
        $ps define demog.consump.alphaA ::simlib::rfraction 0.50 {
            Smoothing constant for revising the expected level of
            consumption <b>when the actual level of consumption has been
            higher than expected</b>.  If 1.0, the expected
            level of consumption will just be the current level of
            consumption; (expectations change instantly); if 0.0, the
            expected level of consumption will never change at all.<p>

            The value can be thought of as 1 over the average age of
            the data in weeks.  Thus, the default value of 0.5 implies
            that the data used for smoothing has an average age of 2
            weeks.
        }

        $ps define demog.consump.alphaE ::simlib::rfraction 0.25 {
            Smoothing constant for revising the expected level of
            consumption <b>when the actual level of consumption has
            been lower than expected.</b>.  If 1.0, the expected
            level of consumption will just be the current level
            (expectations change instantly); if 0.0, the expected
            level of consumption will never change at all.  <p>

            The value can be thought of as 1 over the average age of
            the data in weeks.  Thus, the default value of 0.25 implies
            that the data used for smoothing has an average age of 4
            weeks.
        }


        $ps define demog.consump.expectfGain ::projectlib::rnonneg 3 {
            The gain on the expectations factor.  The base factor
            runs from -1.0 to +1.0; this gain stretches it to a wider
            range so that the magnitude expressed in the rule is for a
            nominal value rather than for an extreme value.
        }
        
        $ps subset demog.consump.RGPC {
            This set of parameters defines the required number of goods
            baskets per capita (RGPC) to live without hardship, by
            urbanization level.
        }
        
        foreach urb [eurbanization names] {
            $ps define demog.consump.RGPC.$urb ::projectlib::iquantity 0 {
                The number of goods baskets per capita per year consumed
                by those living at the poverty line, by urbanization
                level.
            }
        }
        
        $ps setdefault demog.consump.RGPC.ISOLATED 0
        $ps setdefault demog.consump.RGPC.RURAL    350
        $ps setdefault demog.consump.RGPC.SUBURBAN 400
        $ps setdefault demog.consump.RGPC.URBAN    450

        $ps define demog.consump.Zpovf ::marsutil::zcurve {0.0 0.05 1.0 1.0} {
            Z-curve for the poverty factor.  The input is the fraction
            of a group that is living below the regional poverty line,
            as defined by the demog.RGPC.* parameters.  The output
            should range from 0.0 (no unusual poverty) to 1.0
            (maximum poverty).
        }
        
        $ps define demog.gini ::simlib::rfraction .3 {
            The regional Gini coefficient.  The Gini coefficient
            gives an estimate of the inequality of per capita income
            in the region, and used to describe the Lorenz curve for
            the region.  It is a number between 0.0 and 1.0
        }

        $ps define demog.maxcommute ::simlib::eproximity FAR {
            The maximum neighborhood proximity that workers are willing
            to travel for a job when allocating the work force to jobs.
            If set to FAR, then workers are not willing to travel to
            FAR or REMOTE neighborhoods.
        }
        
        $ps define demog.Zuaf ::marsutil::zcurve {0.0 5.0 15.0 2.0} {
            Z-curve for the unemployment attitude factor (UAF).
            The input is the unemployed per capita (UPC), which is
            expressed as a percentage of the total population.
            The output is a coefficient used in the
            UNEMP rule set; it should range from 0.0 to 2.0.
        }
        
        # Economic Model parameters

        $ps subset econ {
            Parameters which affect the Athena Economic Model.
        }

        $ps define econ.gdpExp ::projectlib::rnonneg 0.075 {
            Used to change an exponent on the calibration page in the
            six-by-six economic model.  It is used to tune the 
            convergence of GDP to the base case GDP.
        }

        $ps define econ.empExp ::projectlib::rnonneg 0.2 {
            Used to change an exponent on the calibration page in the
            six-by-six economic model.  It is used to tune the
            convergense of unemployment rate to the base case unemployment
            rate.
        }

        $ps define econ.REMisTaxed ::projectlib::boolean yes {
            If yes, then remittances are treated as before tax income
            otherwise they are added to after tax income.
        }

        $ps define econ.ticksPerTock ::projectlib::ipositive 1 {
            Defines the size of the economic model "tock", in ticks.
            At each tock, Athena updates the economic model with the
            latest demographic data, etc., and computes the new
            state of the economy.
        }

        $ps define econ.initCapPct ::projectlib::rpercent 100.0 {
            The initial capacity of the economy being modeled expressed as
            a percentage of the maximum capacity.  If the production
            infrastructure at scenario lock is degraded, then this parameter
            should be something less than 100 percent to represent that. 
        }

        $ps subset econ.check {
            Parameters that control Athena's on-going sanity checks for
            economic model.
        }

        $ps define econ.check.MinConsumerFrac ::simlib::rfraction 0.4 {
            The on-tick sanity check will fail if the total number of
            consumers in the local economy drops to below this
            fraction of its starting value.  Set it to 0.0 to disable
            the check.

        }

        $ps define econ.check.MinLaborFrac ::simlib::rfraction 0.4 {
            The on-tick sanity check will fail if the total number of
            workers in the local labor force drops to below this
            fraction of its starting value.  Set it to 0.0 to disable
            the check.
        }

        $ps define econ.check.MaxUR ::projectlib::iquantity 50 {
            The on-tick sanity check will fail if unemployment
            rate exceeds this value.  Set it to 100 to disable the
            check.
        }

        $ps define econ.check.MinDgdpFrac ::simlib::rfraction 0.5 {
            The on-tick sanity check will fail if the DGDP
            (Deflated Gross Domestic Product) falls drops to below
            this fraction of its starting value.  Set it to 0.0 to
            disable the check.
        }

        $ps define econ.check.MinCPI ::projectlib::parmdb_rquantity 0.7 {
            The on-tick sanity check will fail if the CPI drops
            to below this value.  Set it to 0.0 to disable the check.
        }

        $ps define econ.check.MaxCPI ::projectlib::parmdb_rquantity 1.5 {
            The on-tick sanity check will fail if the CPI rises to
            above this value.  Set it to some large number (e.g., 100.0)
            to effectively disable the check.
        }

        $ps subset econ.secFactor {
            Parameters relating to the effect of security on the economy.
        }

        $ps subset econ.secFactor.consumption {
            A set of factors that decrease a neighborhood group's
            consumption due to the the group's current security level.
        }

        $ps subset econ.secFactor.labor {
            A set of factors that decrease a neighborhood group's
            contribution to the labor force to the the group's current
            security level.
        }

        foreach level [qsecurity names] {
            $ps define econ.secFactor.consumption.$level \
                ::simlib::rfraction 1.0 "
                    Fraction of consumption when a group's security
                    level is $level.
                "

            $ps define econ.secFactor.labor.$level \
                ::simlib::rfraction 1.0 "
                    Fraction of labor force when a group's security
                    level is $level.
                "
        }

        $ps setdefault econ.secFactor.consumption.M 0.98
        $ps setdefault econ.secFactor.consumption.L 0.92
        $ps setdefault econ.secFactor.consumption.N 0.88

        $ps setdefault econ.secFactor.labor.M 0.98
        $ps setdefault econ.secFactor.labor.L 0.95
        $ps setdefault econ.secFactor.labor.N 0.90


        $ps subset econ.shares {
            Allocations of expenditures to CGE sectors, by
            expenditure class and sector.  The allocations are
            specified as shares per sector.  The fraction of money
            allocated to a sector is determined by dividing its
            designated number of shares by the total number of shares
            for this expenditure class.
        }

        foreach class {ASSIGN BROADCAST BUILD DEPLOY FUNDENI MAINTAIN} {
            $ps subset econ.shares.$class "
                Allocations of expenditures to CGE sectors for the
                $class expenditure class.  The allocations are
                specified as shares per sector.  The fraction of money
                allocated to a sector is determined by dividing its
                designated number of shares by the total number of shares
                for the $class expenditure class.
            "

            foreach sector {goods pop black region world} {
                $ps define econ.shares.$class.$sector \
                    ::projectlib::iquantity 0 "
                        Allocation of $class expenditures to the
                        $sector CGE sector, a number of shares greater
                        than or equal to 0.
                    "
            }
        }

        $ps setdefault econ.shares.ASSIGN.goods      4
        $ps setdefault econ.shares.ASSIGN.pop        6
        $ps setdefault econ.shares.ASSIGN.black      0
        $ps setdefault econ.shares.ASSIGN.region     0
        $ps setdefault econ.shares.ASSIGN.world      0
        $ps setdefault econ.shares.BROADCAST.goods   4
        $ps setdefault econ.shares.BROADCAST.pop     6
        $ps setdefault econ.shares.BROADCAST.black   0
        $ps setdefault econ.shares.BROADCAST.region  0
        $ps setdefault econ.shares.BROADCAST.world   0
        $ps setdefault econ.shares.BUILD.goods       1 
        $ps setdefault econ.shares.BUILD.pop         3
        $ps setdefault econ.shares.BUILD.black       0
        $ps setdefault econ.shares.BUILD.region      0
        $ps setdefault econ.shares.BUILD.world       0
        $ps setdefault econ.shares.DEPLOY.goods      4
        $ps setdefault econ.shares.DEPLOY.pop        6
        $ps setdefault econ.shares.DEPLOY.black      0
        $ps setdefault econ.shares.DEPLOY.region     0
        $ps setdefault econ.shares.DEPLOY.world      0
        $ps setdefault econ.shares.FUNDENI.goods     4
        $ps setdefault econ.shares.FUNDENI.pop       6
        $ps setdefault econ.shares.FUNDENI.black     0
        $ps setdefault econ.shares.FUNDENI.region    0
        $ps setdefault econ.shares.FUNDENI.world     0
        $ps setdefault econ.shares.MAINTAIN.goods    1 
        $ps setdefault econ.shares.MAINTAIN.pop      3
        $ps setdefault econ.shares.MAINTAIN.black    0
        $ps setdefault econ.shares.MAINTAIN.region   0
        $ps setdefault econ.shares.MAINTAIN.world    0


        # NEXT, Force/Volatility/Security Parameters
        $ps subset force {
            Parameters which affect the neighborhood force analysis models.
        }

        $ps define force.mood ::simlib::rfraction 0.2 {
            Dial that controls the extent to which a civilian group's mood
            in a neighborhood affects its force in that neighborhood.
            At 0.0, mood has no effect.  At 1.0, the group's force will
            be doubled if the mood is -100.0 (perfectly dissatisfied) and
            zeroed  if the mood is +100 (perfectly satisfied).  At the
            default value of 0.2, the effect changes from 1.2
            when perfectly dissatisfied to 0.8 when perfectly satisfied.
            (This value is denoted "b" in the Athena Analyst Guide.)
        }

        $ps define force.population ::simlib::rfraction 0.01 {
            Dial that controls the fraction of a civilian group's
            population in a neighborhood
            that counts toward that group's force in the
            neighborhood.  Must be no less than 0. (This value is denoted
            "a" in the Athena Analyst Guide.)
        }

        $ps define force.proximity ::projectlib::rgain 0.1 {
            Dial that controls the extent to which nearby
            neighborhoods contribute to a group's force in a neighborhood.
            This dial should be larger if neighborhoods are small, and
            smaller if neighborhoods are large.  Set it to 0.0 if
            nearby neighborhoods have no effect.  Must be no less than
            0.  (This value is denoted "h" in the Athena Analyst Guide.)
        }

        $ps define force.volatility ::projectlib::rgain 1.0 {
            Dial that controls the affect of neighborhood volatility
            on the security of each group in the neighborhood.  Set to 0
            to ignore volatility altogether.  Must be no less than 0.
            (This value is denoted "v" in the Athena Analyst Guide.)
        }

        $ps subset force.alpha {
            Alpha is the force multiplier applied to force group personnel
            performing a particular activity when computing the group's
            "own force" in a neighborhood.
        }

        foreach a {
            NONE
            CHKPOINT
            COERCION
            CONSTRUCT
            CRIME
            CURFEW
            EDU
            EMPLOY
            GUARD
            INDUSTRY
            INFRA
            LAWENF
            MEDICAL
            PATROL
            PSYOP
            RELIEF
        } {
            $ps define force.alpha.$a ::projectlib::rgain 1.0 {
                Force multiplier for force group personnel assigned the
                specified activity.  Must be no less than 0.0; the average
                value is 1.0.
            }
        }

        $ps setdefault force.alpha.CHKPOINT   1.5
        $ps setdefault force.alpha.COERCION   1.2
        $ps setdefault force.alpha.CONSTRUCT  0.8
        $ps setdefault force.alpha.CRIME      0.8
        $ps setdefault force.alpha.CURFEW     1.2
        $ps setdefault force.alpha.EDU        0.8
        $ps setdefault force.alpha.EMPLOY     0.8
        $ps setdefault force.alpha.GUARD      1.7
        $ps setdefault force.alpha.INDUSTRY   0.8
        $ps setdefault force.alpha.INFRA      0.8
        $ps setdefault force.alpha.LAWENF     1.5
        $ps setdefault force.alpha.MEDICAL    0.8
        $ps setdefault force.alpha.NONE       1.0
        $ps setdefault force.alpha.PATROL     2.0
        $ps setdefault force.alpha.PSYOP      1.0
        $ps setdefault force.alpha.RELIEF     0.8

        $ps subset force.demeanor {
            Dial that determines the effect of demeanor on a group's
            force.  Must be no less than 0; set to 1.0 if demeanor should
            have no effect.
        }

        foreach {name value} {
            APATHETIC  0.3
            AVERAGE    1.0
            AGGRESSIVE 1.5
        } {
            $ps define force.demeanor.$name ::projectlib::rgain $value "
                Dial that determines the effect of $name demeanor
                on a group's force.  Must be no less than 0; set to 1.0
                if demeanor should have no effect.
            "
        }

        $ps subset force.discipline {
            Dial that determines a force group's level of discipline as
            a function of its training level.  Set all values to  1.0 if
            training should have no effect on discipline.
        }

        foreach {name value} {
            PROFICIENT 1.0
            FULL       0.9
            PARTIAL    0.7
            NONE       0.4
        } {
            $ps define force.discipline.$name ::simlib::rfraction $value "
                Dial that determines a force group's level of discipline
                given a training level of $name; a number between 0.0 and
                1.0.
            "
        }

        $ps subset force.forcetype {
            For units belonging to force groups, this set of dials
            determines the contribution to force of each person in the unit,
            based on the group's force type.  Must be no less
            than 0.
        }

        foreach {name value} {
            REGULAR       25
            PARAMILITARY  15
            POLICE        10
            IRREGULAR     20
            CRIMINAL       8
        } {
            $ps define force.forcetype.$name ::projectlib::rgain $value "
                This dial determines the contribution to force of each
                person in a unit, where that unit belongs to an
                force group of force type $name.
                Must be no less than 0.
            "
        }

        $ps subset force.law {
            These parameters relate to the effect of law enforcement
            activities by force groups on the background level of
            criminal activity, and hence on volatility.
        }

        $ps define force.law.suppfrac ::simlib::rfraction 0.6 {
            Suppressible fraction: the fraction of a civilian group's
            criminal activity that can be suppressed by law enforcement.
        }

        $ps subset force.law.beta {
            These parameters indicate how effective force group activities
            are at reducing volatility in the neighborhood.
        }

        foreach a {
            NONE
            CHKPOINT
            COERCION
            CONSTRUCT
            CRIME
            CURFEW
            EDU
            EMPLOY
            GUARD
            INDUSTRY
            INFRA
            LAWENF
            MEDICAL
            PATROL
            PSYOP
            RELIEF
        } {
            $ps define force.law.beta.$a ::projectlib::rgain 1.0 {
                How effective this activity is at reducing volatility
                and criminal activities in the neighborhood.
            }
        }

        $ps setdefault force.law.beta.NONE       0.0
        $ps setdefault force.law.beta.CHKPOINT   0.5
        $ps setdefault force.law.beta.COERCION   0.3
        $ps setdefault force.law.beta.CONSTRUCT  0.0
        $ps setdefault force.law.beta.CRIME      0.0
        $ps setdefault force.law.beta.CURFEW     1.2
        $ps setdefault force.law.beta.EDU        0.0
        $ps setdefault force.law.beta.EMPLOY     0.0
        $ps setdefault force.law.beta.GUARD      1.0
        $ps setdefault force.law.beta.INDUSTRY   0.0
        $ps setdefault force.law.beta.INFRA      0.0
        $ps setdefault force.law.beta.LAWENF     1.0
        $ps setdefault force.law.beta.MEDICAL    0.0
        $ps setdefault force.law.beta.PATROL     1.0
        $ps setdefault force.law.beta.PSYOP      0.3
        $ps setdefault force.law.beta.RELIEF     0.3

        $ps subset force.law.coverage {
            These parameters are coverage functions for law enforcement
            activities, in terms of the neighborhood's urbanization
            level.  If coverage is 1.0, then background criminal activities
            are completely suppressed.  The input is a complex measure of
            personnel involved in activities that relate in some way to
            law enforcement or suppression of crime.
        }

        foreach {urb func} {
            ISOLATED {1.0 1000}
            RURAL    {1.0 1000}
            SUBURBAN {2.0 1000}
            URBAN    {3.0 1000}
        } {
            $ps define force.law.coverage.$urb ::simlib::coverage $func "
                Law enforcement coverage function for $urb neighborhoods.
            "
        }

        $ps subset force.law.efficiency {
            This is set of multipliers indicating the efficiency of a
            force group at law enforcement given its training level.
        }

        foreach {name val} {
            PROFICIENT 1.2
            FULL       0.9
            PARTIAL    0.7
            NONE       0.4
        } {
            $ps define force.law.efficiency.$name ::projectlib::rgain $val "
                Given a training level of $name, a non-negative
                multiplier indicating how efficient the force group
                will be at law enforcement.
            "
        }

        $ps subset force.law.suitability {
            A family of non-negative multipliers, by force type, indicating
            how suitable a force of the given type is for performing
            law enforcement activities.
        }

        foreach {name val} {
            REGULAR       0.8
            PARAMILITARY  0.6
            POLICE        1.0
            IRREGULAR     0.3
            CRIMINAL      0.6
        } {
            $ps define force.law.suitability.$name ::projectlib::rgain $val {
                A non-negative multiplier indicating how suitable a force
                group of a given type is to performing law enforcement
                activities.
            }
        }

        $ps subset force.law.crimfrac {
            A family of Z-curves indicating the fraction of a civilian
            group that will engage in criminal activities as a function
            of the group's unemployment per capita.
        }

        foreach {name zcurve} {
            AGGRESSIVE  {0.05 4.0 20.0 0.20}
            AVERAGE     {0.04 4.0 20.0 0.15}
            APATHETIC   {0.03 4.0 20.0 0.10}
        } {
            $ps define force.law.crimfrac.$name ::marsutil::zcurve $zcurve "
                A Z-curve, indicating the fraction of a civilian group
                with demeanor $name that will engage in criminal
                activities, as a function of group's unemployment per
                capita percentage.
            "
        }

        $ps define force.law.crimrel ::simlib::qaffinity -0.5 {
            The presumed relationship between criminals and 
            all other groups when computing security.
        }

        $ps subset force.orgtype {
            For units belonging to organization groups, this set of dials
            determines the contribution to force of each person in the unit,
            based on the group's organization type.  Must be no less
            than 0.
        }

        foreach {name value} {
            NGO 0.0
            IGO 0.0
            CTR 2.0
        } {
            $ps define force.orgtype.$name ::projectlib::rgain $value "
                This dial determines the contribution to force of each
                person in a unit, where that unit belongs to an
                organization group of organization type $name.
                Must be no less than 0.
            "
        }

        # NEXT, History parameters.
        $ps subset hist {
            Parameters which control the history data saved by Athena
            at each timestep.
        }

        $ps define hist.control ::snit::boolean on {
            If on, Athena will save, each week, the actor in control of each
            neighborhood to the hist_control table.
        }

        $ps define hist.coop ::snit::boolean on {
            If on, Athena will save, each week, the cooperation of
            each civilian group with each force group
            to the hist_coop table.
        }

        $ps define hist.hrel ::snit::boolean off {
            If on, Athena will save, each week, the horizontal
            relationship between each pair of groups to this
            hist_hrel table.  Horizontal relationships are only
            affected by magic inputs, and the amount of data can
            be quite large; hence, this flag is off by default.
        }

        $ps define hist.nbcoop ::snit::boolean on {
            If on, Athena will save, each week, the cooperation of
            each neighborhood with each force group
            to the hist_nbcoop table.
        }

        $ps define hist.nbmood ::snit::boolean on {
            If on, Athena will save, each week, the mood of
            each neighborhood to the hist_nbmood table.
        }

        $ps define hist.pop ::snit::boolean on {
            If on, Athena will save, each week, the population
            of each civilian group, the civilian population of each 
            neighborhood and all flows of population from one group 
            to another.
        }

        $ps define hist.sat ::snit::boolean on {
            If on, Athena will save, each week, the satisfaction of
            each civilian group with each concern to the hist_sat table.
        }

        $ps define hist.security ::snit::boolean on {
            If on, Athena will save, each week, the security of each
            group in each neighborhood to the hist_security table.
        }

        $ps define hist.service ::snit::boolean on {
            If on, Athena will save, each week, the service and funding
            levels of ENI service for each group in each neighborhood
            to the hist_service_g table.
        }

        $ps define hist.support ::snit::boolean on {
            If on, Athena will save, each week, the direct
            support, total support, and influence of each actor in
            each neighborhood to the hist_support table.
        }

        $ps define hist.volatility ::snit::boolean on {
            If on, Athena will save, each week, the volatility of each
            neighborhood to the hist_volatility table.
        }

        $ps define hist.vrel ::snit::boolean on {
            If on, Athena will save, each week, the vertical
            relationship of each civilian group with each actor
            to the hist_vrel table.
        }


        $ps subset plant {
            Parameters which affect the GOODS production infrastructure
            model.
        }

        $ps subset plant.bktsPerYear {
            Parameters that control the average output of a GOODS
            production plant in number of baskets produced per year.
        }

        $ps define plant.bktsPerYear.goods ::projectlib::posmoney 1B {
            The average output of a single GOODS production plant that makes
            goods baskets when the plant is running at full capacity.
        }

        $ps define plant.lifetime ::projectlib::iquantity 156 {
            The lifetime in weeks of an unmaintained GOODS production plant.
            The production of goods by plants will degrade
            to zero over this time span if no repair work is done.
            Setting this parameter to zero will cause plant degradation
            to be disabled.
        }

        $ps define plant.repairtime ::projectlib::iquantity 26 {
            The time in weeks it takes to repair a GOODS production plant
            from total disrepair to fully functional.  A plant in total
            disrepair does not mean that it is destroyed, just that
            it does not produce any goods.  Setting this parameter to
            zero will bring the repair level of all plants to fully 
            functional at the next tick.
        }

        $ps define plant.buildtime ::projectlib::iquantity 52 {
            The average time in weeks it takes to build a GOODS production 
            plant from scratch.  The inverse of this number is the
            maximum fractional amount of construction that can take place
            in one week.
        }

        $ps define plant.buildcost ::projectlib::money 1B {
            The average cost to build a GOODS production plant from scratch.
        }

        $ps define plant.repairfrac ::simlib::rfraction 0.001 {
            The cost to repair a GOODS production plant from total disrepair
            to fully functional expressed as a fraction of the cost to
            build a plant from scratch.
        }

        # NEXT, define rmf parameters
        $ps slave add [list ::simlib::rmf parm]

        # Service Model Parameters
        $ps subset service {
            Parameters which affect the Athena Service models.
        }

        foreach s [eabservice names] {
            $ps subset service.$s "
                Parameters which affect the Abstract $s Infrastructure
                Services model.
            "
    
            $ps define service.$s.alphaA ::simlib::rfraction 0.50 {
                Smoothing constant for computing the expected level of
                service <b>when the average amount of service has been
                higher than the expectation</b>.  If 1.0, the expected
                level of service will just be the current level of service
                (expectations change instantly); if 0.0, the expected
                level of service will never change at all.<p>
    
                The value can be thought of as 1 over the average age of
                the data in weeks.  Thus, the default value of 0.5 implies
                that the data used for smoothing has an average age of 2
                weeks.
            }
    
            $ps define service.$s.alphaX ::simlib::rfraction 0.25 {
                Smoothing constant for computing the expected level of
                service <b>when the expectation of service has been higher
                than the average amount</b>.  If 1.0, the expected
                level of service will just be the current level of service
                (expectations change instantly); if 0.0, the expected
                level of service will never change at all.  <p>
    
                The value can be thought of as 1 over the average age of
                the data in weeks.  Thus, the default value of 0.25 implies
                that the data used for smoothing has an average age of 4
                weeks.
            }
    
            $ps define service.$s.delta ::simlib::rfraction 0.1 {
                An actual service level A is presumed to be approximately
                equal to the expected service level X if
                abs(A-X) <= delta*X.
            }
    
            $ps define service.$s.gainNeeds ::simlib::rmagnitude 2.0 {
                A "gain" multiplier applied to the ENI service "needs"
                factor.  When the gain is 0.0, the needs factor is 0.0.
                When the gain is 1.0, then -1.0 <= needs <= 1.0.  When
                the gain is 2.0 (the default), then -2.0 <= needs <= 2.0,
                and so on.  Setting the gain greater than 1.0 allows the
                magnitude applied to the needs factor in the ENI rule set
                to represent a median value rather than an extreme value.
            }
    
            $ps define service.$s.gainExpect ::simlib::rmagnitude 2.0 {
                A "gain" multiplier applied to the ENI service "expectations"
                factor.  When the gain is 0.0, the expectations factor is 0.0.
                When the gain is 1.0, then -1.0 <= expectf <= 1.0.  When
                the gain is 2.0 (the default), then -2.0 <= expectf <= 2.0,
                and so on.  Setting the gain greater than 1.0 allows the
                magnitude applied to expectf in the ENI rule set
                to represent a median value rather than an extreme value.
            }
    
            $ps subset service.$s.actual {
                The default actual level of service, by neighborhood
                urbanization level, expressed as a fraction of the
                saturation level of service.  On scenario lock, the
                expected levels of service are set to this value.  
                This value can be changed using the SERVICE tactic.
            }
    
            $ps subset service.$s.required {
                The default required level of service, by neighborhood
                urbanization level, expressed as a fraction of the
                saturation level of service.
            }
    
            foreach ul [::projectlib::eurbanization names] {
                $ps define service.$s.actual.$ul \
                    ::simlib::rfraction 0.0 \
                    "Value of service.$s.actual for urbanization level $ul."
    
                $ps define service.$s.required.$ul \
                    ::simlib::rfraction 0.0 \
                    "Value of service.$s.required for urbanization level $ul."
            }
        }

        $ps setdefault service.ENERGY.actual.ISOLATED  0.0
        $ps setdefault service.ENERGY.actual.RURAL     0.4
        $ps setdefault service.ENERGY.actual.SUBURBAN  0.9
        $ps setdefault service.ENERGY.actual.URBAN     1.0

        $ps setdefault service.ENERGY.required.ISOLATED  0.0
        $ps setdefault service.ENERGY.required.RURAL     0.4
        $ps setdefault service.ENERGY.required.SUBURBAN  0.9
        $ps setdefault service.ENERGY.required.URBAN     1.0

        $ps setdefault service.TRANSPORT.actual.ISOLATED  0.0
        $ps setdefault service.TRANSPORT.actual.RURAL     0.4
        $ps setdefault service.TRANSPORT.actual.SUBURBAN  0.9
        $ps setdefault service.TRANSPORT.actual.URBAN     1.0

        $ps setdefault service.TRANSPORT.required.ISOLATED  0.0
        $ps setdefault service.TRANSPORT.required.RURAL     0.4
        $ps setdefault service.TRANSPORT.required.SUBURBAN  0.9
        $ps setdefault service.TRANSPORT.required.URBAN     1.0

        $ps setdefault service.WATER.actual.ISOLATED  0.8
        $ps setdefault service.WATER.actual.RURAL     0.9
        $ps setdefault service.WATER.actual.SUBURBAN  1.0
        $ps setdefault service.WATER.actual.URBAN     1.0

        $ps setdefault service.WATER.required.ISOLATED  0.8
        $ps setdefault service.WATER.required.RURAL     0.9
        $ps setdefault service.WATER.required.SUBURBAN  1.0
        $ps setdefault service.WATER.required.URBAN     1.0

        $ps subset service.ENI {
            Parameters which affect the Essential Non-Infrastructure
            Services model.
        }

        $ps define service.ENI.alphaA ::simlib::rfraction 0.50 {
            Smoothing constant for computing the expected level of
            service <b>when the average amount of service has been
            higher than the expectation</b>.  If 1.0, the expected
            level of service will just be the current level of service
            (expectations change instantly); if 0.0, the expected
            level of service will never change at all.<p>

            The value can be thought of as 1 over the average age of
            the data in weeks.  Thus, the default value of 0.5 implies
            that the data used for smoothing has an average age of 2
            weeks.
        }

        $ps define service.ENI.alphaX ::simlib::rfraction 0.25 {
            Smoothing constant for computing the expected level of
            service <b>when the expectation of service has been higher
            than the average amount</b>.  If 1.0, the expected
            level of service will just be the current level of service
            (expectations change instantly); if 0.0, the expected
            level of service will never change at all.  <p>

            The value can be thought of as 1 over the average age of
            the data in weeks.  Thus, the default value of 0.25 implies
            that the data used for smoothing has an average age of 4
            weeks.
        }

        $ps subset service.ENI.beta {
            The shape parameter for the service vs. funding curve, by
            neighborhood urbanization level.  If 1.0, the curve is
            linear; for values less than 1.0, the curve exhibits
            economies of scale.
        }

        $ps define service.ENI.delta ::simlib::rfraction 0.1 {
            An actual service level A is presumed to be approximately
            equal to the expected service level X if
            abs(A-X) <= delta*X.
        }

        $ps define service.ENI.gainNeeds ::simlib::rmagnitude 2.0 {
            A "gain" multiplier applied to the ENI service "needs"
            factor.  When the gain is 0.0, the needs factor is 0.0.
            When the gain is 1.0, then -1.0 <= needs <= 1.0.  When
            the gain is 2.0 (the default), then -2.0 <= needs <= 2.0,
            and so on.  Setting the gain greater than 1.0 allows the
            magnitude applied to the needs factor in the ENI rule set
            to represent a median value rather than an extreme value.
        }

        $ps define service.ENI.gainExpect ::simlib::rmagnitude 2.0 {
            A "gain" multiplier applied to the ENI service "expectations"
            factor.  When the gain is 0.0, the expectations factor is 0.0.
            When the gain is 1.0, then -1.0 <= expectf <= 1.0.  When
            the gain is 2.0 (the default), then -2.0 <= expectf <= 2.0,
            and so on.  Setting the gain greater than 1.0 allows the
            magnitude applied to expectf in the ENI rule set
            to represent a median value rather than an extreme value.
        }

        $ps define service.ENI.minSupport ::simlib::rfraction 0.0 {
            The minimum direct support an actor requires in a neighborhood
            in order to fund ENI services in that neighborhood.
        }

        $ps subset service.ENI.required {
            The required level of service, by neighborhood
            urbanization level, expressed as a fraction of the
            saturation level of service.
        }

        $ps subset service.ENI.saturationCost {
            The per capita cost of providing the saturation level of
            service, by neighborhood urbanization level, in $/week.
        }

        foreach ul [::projectlib::eurbanization names] {
            $ps define service.ENI.beta.$ul ::simlib::rfraction 1.0     \
                "Value of service.ENI.beta for urbanization level $ul."

            $ps define service.ENI.required.$ul \
                ::simlib::rfraction 0.0 \
                "Value of service.ENI.required for urbanization level $ul."

            $ps define service.ENI.saturationCost.$ul \
                ::projectlib::money 0.0 \
             "Value of service.ENI.saturationCost for urbanization level $ul."
        }

        $ps setdefault service.ENI.required.ISOLATED       0.0
        $ps setdefault service.ENI.required.RURAL          0.2
        $ps setdefault service.ENI.required.SUBURBAN       0.4
        $ps setdefault service.ENI.required.URBAN          0.6

        $ps setdefault service.ENI.saturationCost.ISOLATED 0.01
        $ps setdefault service.ENI.saturationCost.RURAL    0.10
        $ps setdefault service.ENI.saturationCost.SUBURBAN 0.20
        $ps setdefault service.ENI.saturationCost.URBAN    0.40

        # Strategy Model parameters

        $ps subset strategy {
            Parameters which affect the Athena Strategy Model.
        }

        $ps define strategy.autoDemob snit::boolean yes {
            If yes, Athena will automatically demobilize all force
            and organization group personnel that remain undeployed
            at the end of the strategy tock.
        }

        # NEXT, define uram parameters
        $ps slave add [list ::simlib::uram parm]

        # NEXT, destroy tempdb
        $tempdb destroy
    }
}

