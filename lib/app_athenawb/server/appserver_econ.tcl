#-----------------------------------------------------------------------
# TITLE:
#    appserver_econ.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Econ Model Reports
#
#    /app/econ/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module ECON {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /econ {econ/?} \
            text/html [myproc /econ:html]          \
            "Economic model status report."

        appserver register /econ/enabled/ {econ/enabled/?} \
            text/html [myproc /econ/enabled:html]          \
            "Economic model enabled."

        appserver register /econ/disabled/ {econ/disabled/?} \
            text/html [myproc /econ/disabled:html]          \
            "Economic model disabled."
    }

    #-------------------------------------------------------------------
    # /econ/status:       Econ model status report.
    #
    # No match parameters

    # /econ/status:html udict matchArray
    #

    proc /econ:html {udict matchArray} {
        ht page "Econ Model: Status" {
            ht title "Status" "Econ"

            ht putln {
                Athena reports on the status of the economic model
                providing insight into any problems there may be if
                something is not right with it.
            }

            ht para
            
            adb econ report ::appserver::ht
        }

        return [ht get]
    }

    proc /econ/enabled:html {udict matchArray} {
        upvar 1 $matchArray ""

        ht page "Economic Model Enabled"

        ht put {
            The economic model is <b>enabled</b>.<p>

            This means that it is necessary to
            provide sector-by-sector monetary flows for the economy under
            consideration.  This is done by filling in the cells in the Social
            Accounting Matrix on the SAM tab.<p>

            See <a href="/help/tab/economics/samexample.html">here</a> for an
            example of a SAM for a simple economy that can be used as a 
            quick start guide.<p>
    
            The economy consists of the following sectors, but only some
            sectors are absolutely required:<p>
    
            <ul>
              <li><b>goods</b> - this sector represents the total production
                  of goods and services present in the economy being modeled.
              <li><b>pop</b> - this sector represents the total amount of
                  labor in the economy.  Monetary flows in this sector have 
                  a direct effect on wages and unemployment.
              <li><b>black</b> - this sector represents the money flows in
                  and out of a sector whose product is considerd illegal.  
                  This sector could consist of any contraband such as arms or
                  narcotics. It is not necessary to model a black market 
                  sector, in which case all black market cells can be input
                  as zeroes.
              <li><b>actors</b> - this sector represents the monetary flows to
                  and from the actors defined in Athena.  Actor's income is 
                  defined when actors are created in the Political tab.
                  Actor's expenditures are completely defined by how they
                  spend money executing thier tactics as part of thier
                  strategy as defined on the Strategy tab. See below for more.
              <li><b>region</b> - this sector represents money flows into
                  and out of the local economy being modeled, but still within
                  the region of interest. If, for example, the economy being 
                  modeled is based on Afghanistan, the region sector may 
                  consist of Pakistan, Iran, China or other countries deemed 
                  appropriate.
              <li><b>world</b> - this sector represents the "Rest of the 
                  World". Monetary flows into and out of this sector are 
                  imports and exports. Note that the SAM cell for money flows
                  from the world to the world can be ignored, it doesn't
                  matter.
            </ul><p>
    
            <b>Actor Incomes</b><p>
            Actor incomes are defined on the Political tab. The actual 
            income received by actors depends on state of the economy and 
            may fluctuate week to week based on whether the economoy is 
            growing or shrinking.<p>
    
            <b>Actor Expenditures</b><p>
            Actors expend money while executing tactics as part of their 
            strategy.  The allocation of money to sectors is controlled on
            a tactic by tactic basis.  See the 
            <a href="/help/parmdb/econ/shares.html">econ.shares.*</a> family
            of parameters to define how actors allocate money to the economy 
            during strategy execution.<p>
        }

        ht /page
        return [ht get]
    }

    proc /econ/disabled:html {udict matchArray} {
        upvar 1 $matchArray ""

        ht page "Economic Model Disabled"

        ht put {
            The economic model is <b>disabled</b>.<p>
            
            This means it is not necessary
            to supply sector-by-sector monetary flows by way of the Social 
            Accounting Matrix.  Unemployment and goods consumption (or the lack
            thereof) still affect the civilian population.<p>  
            
            For the rulesets these models use:<p>
    
            <ul>
              <li> <b>CONSUMP</b> - Adjust the 
                   <a href="/help/parmdb/dam/consump/expectf.html">
                   expectations factor</a> and the 
                   <a href="/help/parmdb/dam/consump/povfrac.html">
                   poverty fraction</a> to alter the behavior of the
                   consumption model.
              <li> <b>UNEMP</b> - Adjust the
                   <a href="/help/parmdb/demog/playboxur.html">
                   playbox unemployment rate</a> to alter the behavior of
                   the unemployment model.
            </ul><p>
    
            Actor's incomes will not depend on the state of the economy, 
            they will always get their income as defined.<p>

        }

        ht /page
        return [ht get]
    }

}



