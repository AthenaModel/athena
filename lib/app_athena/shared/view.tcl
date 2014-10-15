#-----------------------------------------------------------------------
# FILE: view.tcl
#
#   Athena View Manager
#
# PACKAGE:
#   app_sim(n) -- athena_sim(1) implementation package
#
# PROJECT:
#   Athena S&RO Simulation
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Module: view
#
# This module is responsible for creating temporary SQLite3 views 
# corresponding to data variables.  There are two kinds:
#
#   - Neighborhood variables, each of which is a single value that
#     varies over the domain of neighborhoods
#
#   - Time series variables, each of which is a single value that
#     varies with time.
#
#   - Eventually there will be a number of other view types:
#     *g* for groups, *u* for units, etc.
#
# The application requests a view given a variable name, and receives
# a dictionary of information about variable, including the view name.
# Each created view has a name like "tv$count", has two columns,
# *x*, the data value, and either *n* or *t*.
#
# Views are defined in the <viewdef> array; data related to the
# type of the *x* column (the range variable) is found in the
# <rangeInfo> array.
#
# Variable Names and Indices:
#
#    Each domain defines a number of variable types; each variable name
#    is a period-delimited list of the variable type and its relevant
#    indices.  For example, "sat.<g>.<c>" is the pattern for the
#    neighborhood variable "satisfaction of a group with a concern".
#    The "g" and "c" represent the indices of the variable in the relevant
#    SQL table or view.
#
# Checkpoint/Restore:
#    This module is a saveable(i), and participates in the checkpoint/
#    restore protocol.  It has no checkpointed data; however, it must
#    flush its cache of views on restore.

snit::type view {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Group: Look-up Tables

    # Type Variable: domains
    #
    # Array of human-readable domain names, by domain code.

    typevariable domains -array {
        n "neighborhood"
        t "time series"
    }

    # Type Variable: rangeInfo
    #
    # This variable is an array of dictionaries of information about
    # various range types, e.g., satisfaction.  It's used when building
    # the view dictionaries.  The values that should be defined for
    # each range type are as follows.
    #
    #   rmin     - The lower bound for the range type, or "" if none.
    #   rmax     - The upper bound for the range type, or "" if none.
    #   gradient - A gradient(n) appropriate for visualizing this
    #              range type, or "" if none.

    typevariable rangeInfo -array {
        rcoverage {
            rmin     0.0
            rmax     1.0
            gradient covgradient
            units    Coverage
            decimals 2
        }

        rel {
            rmin     -1.0
            rmax     1.0
            gradient relgradient
            units    Relationship 
            decimals 2
        }

        qcoop {
            rmin     0.0
            rmax     100.0
            gradient coopgradient
            units    Cooperation
            decimals 1
        }

        qsat {
            rmin     -100.0
            rmax     100.0
            gradient satgradient
            units    Satisfaction
            decimals 1
        }

        qsecurity {
            rmin     -100.0
            rmax     100.0
            gradient secgradient
            units    Security
            decimals 1
        }

        rcap {
            rmin     0
            rmax     ""
            gradient ""
            units    goodsBKT
            decimals 1
        }

        rcpi {
            rmin     0
            rmax     ""
            gradient pcfgradient
            units    CPI
            decimals 2
        }

        rdollars {
            rmin     0
            rmax     ""
            gradient {}
            units    $
            decimals 2
        }

        rfraction {
            rmin     0.0
            rmax     1.0
            gradient covgradient
            units    Fraction
            decimals 2
        }

        rpcf {
            rmin     0
            rmax     ""
            gradient pcfgradient
            units    PCF
            decimals 2
        }

        rpercent {
            rmin     0.0
            rmax     100.0
            gradient {}
            units    Percent
            decimals 1
        }

        rpop {
            rmin     0
            rmax     ""
            gradient ""
            units    people
            decimals 0
        }

        runits {
            rmin     0
            rmax     ""
            gradient ""
            units    Units
            decimals 1
        }
    }

    # Type Variable: viewdef
    #
    # View definition dictionaries.  For each _domain,vartype_,
    # we have the following keys.
    #
    #   indices    - A list of index names, e.g., {f g}
    #
    #   validation - A proc that validates the combination
    #                of indices.  See, for example, "fg_coop", below.
    #
    #   rtype      - The range type, used to key into the rangeInfo
    #                array.  It might or might not be a genuine data type.
    #
    #   query      - The SELECT statement used to define the view, with
    #                with variables $1, $2, etc., for the parameters.
    #                It must have a column with the same name as the 
    #                _domain_, and an "x0" column for the range.
    #
    # NOTE: All views should span the entire _domain_, with NULL in
    # x0 for missing values.

    typevariable viewdef -array {
        n,cap {
            indices {}
            validation {}
            rtype rcap
            query {
                SELECT n, cap AS x0
                FROM econ_n
            }
        }

        n,cov {
            indices {g a}
            validation ga
            rtype rcoverage
            query {
                SELECT n, coverage AS x0
                FROM activity_nga
                WHERE g='$1' AND a='$2'
            }
        }

        n,nbcoop {
            indices {g}
            validation g_frc
            rtype qcoop
            query {
                SELECT n, nbcoop AS x0
                FROM uram_nbcoop
                WHERE g='$1'
            }
        }

        n,nbmood {
            indices {}
            validation {}
            rtype qsat
            query {
                SELECT n, nbmood AS x0 
                FROM uram_n
            }
        }

        n,nbmood0 {
            indices {}
            validation {}
            rtype qsat
            query {
                SELECT n, nbmood0 AS x0 
                FROM uram_n
            }
        }

        n,none {
            indices {}
            validation {}
            rtype qsat
            query {
                SELECT n, 0.0 AS x0
                FROM nbhoods
            }
        }

        n,pcf {
            indices {}
            validation {}
            rtype rpcf
            query {
                SELECT n, pcf AS x0
                FROM nbhoods
            }
        }

        n,sec {
            indices {g}
            validation g
            rtype qsecurity
            query {
                SELECT n, security AS x0
                FROM force_ng
                WHERE g='$1'
            }
        }

        t,consumers {
            indices {}
            validation {}
            rtype rpop
            query {
                SELECT t    AS t,
                       consumers AS x0
                FROM hist_econ
            }
        }

        t,coop {
            indices {f g}
            validation fg_coop
            rtype qcoop
            query {
                SELECT t    AS t,
                       coop AS x0
                FROM hist_coop
                WHERE f='$1' AND g='$2'
            }
        }

        t,basecoop {
            indices {f g}
            validation fg_coop
            rtype qcoop
            query {
                SELECT t    AS t,
                       base AS x0
                FROM hist_coop
                WHERE f='$1' AND g='$2'
            }
        }
        
        t,natcoop {
            indices {f g}
            validation fg_coop
            rtype qcoop
            query {
                SELECT t   AS t,
                       nat AS x0
                FROM hist_coop
                WHERE f='$1' AND g='$2'
            }
        }

        t,cpi {
            indices {}
            validation {}
            rtype rcpi
            query {
                SELECT t   AS t,
                       cpi AS x0
                FROM hist_econ
            }
        }

        t,dgdp {
            indices {}
            validation {}
            rtype rdollars
            query {
                SELECT t    AS t,
                       dgdp AS x0
                FROM hist_econ
            }
        }


        t,hrel {
            indices {f g}
            validation fg_rel
            rtype rel
            query {
                SELECT t    AS t,
                       hrel AS x0
                FROM hist_hrel
                WHERE f='$1' AND g='$2'
            }
        }

        t,basehrel {
            indices {f g}
            validation fg_rel
            rtype rel
            query {
                SELECT t    AS t,
                       base AS x0
                FROM hist_hrel
                WHERE f='$1' AND g='$2'
            }
        }

        t,nathrel {
            indices {f g}
            validation fg_rel
            rtype rel
            query {
                SELECT t   AS t,
                       nat AS x0
                FROM hist_hrel
                WHERE f='$1' AND g='$2'
            }
        }

        t,labor {
            indices {}
            validation {}
            rtype rpop
            query {
                SELECT t    AS t,
                       labor AS x0
                FROM hist_econ
            }
        }

        t,lsf {
            indices {}
            validation {}
            rtype rfraction
            query {
                SELECT t   AS t,
                       lsf AS x0
                FROM hist_econ
            }
        }

        t,mood {
            indices {g}
            validation g_sat
            rtype qsat
            query {
                SELECT t    AS t,
                       mood AS x0
                FROM hist_mood
                WHERE g='$1'
            }
        }

        t,nbcoop {
            indices {n g}
            validation ng_coop
            rtype qcoop
            query {
                SELECT t      AS t,
                       nbcoop AS x0
                FROM hist_nbcoop
                WHERE n='$1' AND g='$2'
            }
        }

        t,nbmood {
            indices {n}
            validation n
            rtype qsat
            query {
                SELECT t      AS t,
                       nbmood AS x0
                FROM hist_nbmood
                WHERE n='$1'
            }
        }

        t,price {
            indices {i}
            validation i
            rtype rdollars
            query {
                SELECT t      AS t,
                       p      AS x0
                FROM hist_econ_i
                WHERE i='$1'
            }
        }

        t,qd {
            indices {i j}
            validation ij
            rtype rdollars
            query {
                SELECT t      AS t,
                       qd     AS x0
                FROM hist_econ_ij
                WHERE i='$1' AND j='$2'
            }
        }

        t,qs {
            indices {i}
            validation i
            rtype runits
            query {
                SELECT t      AS t,
                       qs     AS x0
                FROM hist_econ_i
                WHERE i='$1'
            }
        }

        t,rev {
            indices {i}
            validation i
            rtype rdollars
            query {
                SELECT t      AS t,
                       rev    AS x0
                FROM hist_econ_i
                WHERE i='$1'
            }
        }

        t,sat {
            indices {g c}
            validation gc_sat
            rtype qsat
            query {
                SELECT t   AS t,
                       sat AS x0
                FROM hist_sat
                WHERE g='$1' AND c='$2'
            }
        }

        t,basesat {
            indices {g c}
            validation gc_sat
            rtype qsat
            query {
                SELECT t    AS t,
                       base AS x0
                FROM hist_sat
                WHERE g='$1' AND c='$2'
            }
        }

        t,natsat {
            indices {g c}
            validation gc_sat
            rtype qsat
            query {
                SELECT t   AS t,
                       nat AS x0
                FROM hist_sat
                WHERE g='$1' AND c='$2'
            }
        }

        t,ur {
            indices {}
            validation {}
            rtype rpercent
            query {
                SELECT t    AS t,
                       ur   AS x0
                FROM hist_econ
            }
        }

        t,vrel {
            indices {g a}
            validation ga_vrel
            rtype rel
            query {
                SELECT t    AS t,
                       vrel AS x0
                FROM hist_vrel
                WHERE g='$1' AND a='$2'
            }
        }

        t,basevrel {
            indices {g a}
            validation ga_vrel
            rtype rel
            query {
                SELECT t    AS t,
                       base AS x0
                FROM hist_vrel
                WHERE g='$1' AND a='$2'
            }
        }

        t,natvrel {
            indices {g a}
            validation ga_vrel
            rtype rel
            query {
                SELECT t   AS t,
                       nat AS x0
                FROM hist_vrel
                WHERE g='$1' AND a='$2'
            }
        }

        t,x {
            indices {i j}
            validation ij
            rtype rdollars
            query {
                SELECT t      AS t,
                       x      AS x0
                FROM hist_econ_ij
                WHERE i='$1' AND j='$2'
            }
        }

    }


    #-------------------------------------------------------------------
    # Group: Uncheckpointed Variables

    # Type Variable: views
    #
    # Array of view dicts by "$domain,$varname".  This variable isn't
    # checkpointed, but it should be flushed on restore.

    typevariable views -array {}

    # Type Variable: data
    #
    # Array of scalar variables.
    #
    # viewCounter - View counter; used to name created views.
    
    typevariable data -array {
        viewCounter 0
    }

    #-------------------------------------------------------------------
    # Group: Initialization

    # Type Method: init
    #
    # Initializes the module, registering it as a saveable.

    typemethod init {} {
        log detail view "init"

        # FIRST, Flush the cache whenever the scenario is reloaded.
        notifier bind ::sim <DbSyncA> ::view [mytypemethod FlushCache]

        # NEXT, the module is up.
        log detail view "init complete"
    }

    # FlushCache
    #
    # Flushes the view cache when the RDB changes out from under it.

    typemethod FlushCache {} {
        array unset views
    }


    #-------------------------------------------------------------------
    # Group: View Queries
    #
    # Each of the commands in this section returns a view dictionary
    # given one or more variable names.  Applications should always 
    # request a new view dictionary prior to using the view; created views
    # are cached for speed.
    #
    # View Dictionary:
    #
    #  view     - SQLite view name
    #  domain   - Domain, *t* or *n*.
    #  count    - Number of variables included
    #  varnames - List of variable names.
    #  meta     - Variable metadata; key is a variable name, value is a 
    #             dictionary of variable info.
    #
    # Variable Dictionary:
    #
    #  varname  - Name of the variable 
    #  rtype    - Variable range type
    #  units    - Units: human readable text
    #  decimals - Number of decimal places for this kind of data
    #  rmin     - Range min, or "" if none.
    #  rmax     - Range max, or "" if none.
    #  gradient - Gradient(n) for this range type.

    # Type Method: n get
    #
    # Returns a view dictionary for the given neighborhood _varnames_.
    #
    # Syntax:
    #   n get _varnames_
    #
    #   varnames - A list of one or more variable names for the 
    #              neighborhood domain.

    typemethod "n get" {varnames} {
        if {[llength $varnames] == 1} {
            return [$type GetView n [lindex $varnames 0]]
        } else {
            return [$type GetCompositeView n $varnames]
        }
    }

    # Type Method: t get
    #
    # Returns a view dictionary for the time series variable(s)
    # with the given _varnames_.
    #
    # Syntax:
    #   t get _varnames_
    #
    #   varnames - A list of one or more variable names for the 
    #              time series domain.

    typemethod "t get" {varnames} {
        if {[llength $varnames] == 1} {
            return [$type GetView t [lindex $varnames 0]]
        } else {
            return [$type GetCompositeView t $varnames]
        }
    }

    # Type Method: GetView
    #
    # Returns a view dictionary for the _domain_ variable
    # with the given _varname_.
    #
    # Syntax:
    #   GetView _domain varname_
    #
    #   domain  - *n* (neighborhood) or *t* (time in ticks)
    #   varname - A variable name for the specified domain.

    typemethod GetView {domain varname} {
        # FIRST, if the view already exists, return it.
        if {[info exists views($domain,$varname)]} {
            return $views($domain,$varname)
        }

        # NEXT, validate the inputs
        $type ValidateVarname $domain $varname

        # NEXT, generate a view ID
        set vid "tv[incr data(viewCounter)]"

        # NEXT, split the variable name into its components
        set varlist [split $varname .]
        lassign $varlist vartype 1 2 3 4 5 6 7 8 9

        # NEXT, create the view
        set query [dict get $viewdef($domain,$vartype) query]
        set rtype [dict get $viewdef($domain,$vartype) rtype]

        rdb eval "CREATE TEMPORARY VIEW $vid AS [subst $query]"

        set vdict [dict create]
        dict set vdict view     $vid
        dict set vdict domain   $domain
        dict set vdict count    1

        dict set vdict meta $varname $rangeInfo($rtype)
        dict set vdict meta $varname rtype $rtype

        set views($domain,$varname) $vdict

        # NEXT, return the ID
        return $views($domain,$varname)
    }

    # Type Method: GetCompositeView
    #
    # Returns a view dictionary for the _domain_ variables
    # with the given _varnames_.  The created view will 
    # have columns x0, x1, etc.
    #
    # Syntax:
    #   GetCompositeView _domain varnames_
    #
    #   domain   - *n* (neighborhood) or *t* (time in ticks)
    #   varnames - A list of variable names for the specified domain.

    typemethod GetCompositeView {domain varnames} {
        # FIRST, get the composite variable name.
        set composite [join $varnames ,]

        # FIRST, if the view already exists, return it.
        if {[info exists views($domain,$composite)]} {
            return $views($domain,$composite)
        }

        # NEXT, create a new view ID and begin to fill in the
        # view dictionary.
        set vid "tv[incr data(viewCounter)]"
        
        set vdict [dict create \
                       view   $vid                \
                       domain $domain             \
                       count  [llength $varnames]]
                       

        # NEXT, get a view for each variable.
        set vids [list]

        foreach varname $varnames {
            set tdict [$type GetView $domain $varname]

            lappend vids [dict get $tdict view]
            
            dict set vdict meta $varname \
                [dict get $tdict meta $varname]
        }

        # NEXT, create the new view
        set i 0
        set columns [list]
        set joins ""

        foreach v $vids {
            # FIRST, get the column name
            lappend columns "$v.x0 AS x$i"
            incr i

            # NEXT, set up the joins.
            if {$joins eq ""} {
                set joins "$v"
            } else {
                append joins " JOIN $v USING ($domain)"
            }
        }

        set sql "
            CREATE TEMPORARY VIEW $vid AS
            SELECT [lindex $vids 0].$domain,[join $columns ,]
            FROM $joins
        "

        rdb eval $sql

        # NEXT, save the view dict.
        set views($domain,$composite) $vdict

        # NEXT, return the view dict
        return $views($domain,$composite)
    }

    # Type Method: n validate
    #
    # Validates a _varname_ for the neighborhood domain.
    # Returns the validated varname, which is in canonical form.
    #
    # Syntax:
    #   n validate _varname_
    #
    #   varname - The neighborhood variable name.

    typemethod "n validate" {varname} {
        return [$type ValidateVarname n $varname]
    }

    # Type Method: n exists
    #
    # Returns 1 if there is a neighborhood variable called
    #  _varname_, and 0 otherwise.
    #
    # Syntax:
    #   n exists _varname_
    #
    #   varname - The neighborhood variable name.

    typemethod "n exists" {varname} {
        if {[catch {$type n validate $varname}]} {
            return 0
        }

        return 1
    }


    # Type Method: t validate
    #
    # Validates a _varname_ for the time series domain.
    # Returns the validated varname, which is in canonical form.
    #
    # Syntax:
    #   t validate _varname_
    #
    #   varname - The time series variable name.

    typemethod "t validate" {varname} {
        return [$type ValidateVarname t $varname]
    }


    # Type Method: t exists
    #
    # Returns 1 if there is a time series variable called
    #  _varname_, and 0 otherwise.
    #
    # Syntax:
    #   t exists _varname_
    #
    #   varname - The time series variable name.

    typemethod "t exists" {varname} {
        if {[catch {$type t validate $varname}]} {
            return 0
        }

        return 1
    }

    #-------------------------------------------------------------------
    # Group: Validation
    #
    # This section contains private validation methods for use when 
    # validating variable names.

    # Type Method: ValidateVarname
    #
    # Validates a _varname_ for the particular _domain_.
    # Returns the validated varname, which is in canonical form.
    #
    # Specs have the syntax "<vartype>?.<indexValue>...?".  The _domain_
    # and _vartype_ must be known.  The index values may not contain 
    # characters that would allow injection attacks: "':,
    #
    # Canonical Form:
    #   At present, all variables have the same canonical form:
    #   the vartype is lower case and the index values are upper case.
    #   At some point in the future the latter condition might be
    #   relaxed in favor of vartype-specific validation; at present,
    #   though, it works in all cases.
    #
    # Syntax:
    #   ValidateVarname _domain varname_
    #
    #   domain  - *n* or *t*
    #   varname - The variable name.

    typemethod ValidateVarname {domain varname} {
        # FIRST, split the varname into canonical tokens.
        set varlist [split $varname .]
        set vartype [string tolower [lindex $varlist 0]]
        set ivalues [string toupper [lrange $varlist 1 end]]

        # NEXT, verify the domain and var type.
        if {![info exists viewdef($domain,$vartype)]} {
            return -code error -errorcode INVALID \
            "Invalid $domains($domain) variable type: \"$vartype\""
        }

        # NEXT, get the view definition for this var type.
        set def $viewdef($domain,$vartype)
        set indices [dict get $def indices]

        # NEXT, validate the number of index values.
        if {[llength $ivalues] != [llength $indices]} {
            set pattern [VartypePattern $vartype $indices]

            return -code error -errorcode INVALID \
 "Invalid $domains($domain) variable: expected \"$pattern\", got \"$varname\""
        }

        # NEXT, validate the index values.
        set valcmd [dict get $def validation]

        if {$valcmd ne ""} {
            $valcmd $domain $vartype {*}$ivalues
        }

        # NEXT, return the canonicalized var name
        return [join [linsert $ivalues 0 $vartype] .]
    }

    # Proc: VartypePattern
    #
    # Returns the pattern given the var type and indices, for use
    # in error messages.
    #
    # Syntax:
    #   VartypePattern _spectype indices_
    #
    #   vartype  - The variable type, e.g., "sat"
    #   indices  - The variable's indices, e.g., {g c}

    proc VartypePattern {vartype indices} {
        set pattern $vartype

        foreach arg $indices {
            append pattern ".<$arg>"
        }

        return $pattern
    }

    # proc: ValidateIndex
    #
    # Validates a single index value, producing a good error message.
    # Executes the script; if it is caught, and the code is INVALID,
    # Throws INVALID with the full error message.  Otherwise,
    # any error is rethrown.
    #
    # Syntax:
    #   ValidateIndex _domain vartype index script_
    #
    #    domain  - The domain
    #    vartype - The variable type, e.g., "sat"
    #    index   - The specific index, e.g., "g"
    #    value   - The index value
    #    script  - A validation script.

    proc ValidateIndex {domain vartype index value script} {
        if {[catch {
            uplevel 1 $script
        } result opts]} {
            # FIRST, rethrow programming errors
            if {[lindex [dict get $opts -errorcode] 0] ne "INVALID"} {
                return {*}$opts $result
            }

            # NEXT, produce the error message.
            set def     $viewdef($domain,$vartype)
            set indices [dict get $def indices]
            set pattern [VartypePattern $vartype $indices]
            
            return -code error -errorcode INVALID \
                "$pattern: <$index>=\"$value\", $result"
        }

        return
    }
    

    # Proc: fg_coop
    #
    # Validates {f g} for cooperation
    
    proc fg_coop {domain vartype f g} {
        ValidateIndex $domain $vartype f $f {civgroup validate $f}
        ValidateIndex $domain $vartype g $g {frcgroup validate $g}
    }

    # Proc: fg_rel
    #
    # Validates {f g} for horizontal relationships
    
    proc fg_rel {domain vartype f g} {
        ValidateIndex $domain $vartype f $f {group validate $f}
        ValidateIndex $domain $vartype g $g {group validate $g}
    }

    # Proc: ga
    #
    # Validates {g a} where is an activity.
    
    proc ga {domain vartype g a} {
        ValidateIndex $domain $vartype g $g {group validate $g}
        ValidateIndex $domain $vartype a $a {
            set gtype [group gtype $g]

            switch -exact -- $gtype {
                CIV     { ptype civa     validate $a }
                FRC     { ptype frca+cov validate $a }
                ORG     { ptype orga     validate $a }
                default { error "Unexpected gtype: \"$gtype\""   }
            }
        }
    }

    # Proc: gc
    #
    # Validates {g c} where is g is a CIV group and c is a
    # concern.
    
    proc gc {domain vartype g c} {
        ValidateIndex $domain $vartype g $g {civgroup validate $g}
        ValidateIndex $domain $vartype c $c {ptype c validate $c}
    }

    # Proc: g
    #
    # Validates {g} as a group
    
    proc g {domain vartype g} {
        ValidateIndex $domain $vartype g $g {group validate $g}
    }

    # Proc: g_sat
    #
    # Validates {g} as a satisfaction group
    
    proc g_sat {domain vartype g} {
        ValidateIndex $domain $vartype g $g {civgroup validate $g}
    }

    # Proc: g_frc
    #
    # Validates {g} as a force group
    
    proc g_frc {domain vartype g} {
        ValidateIndex $domain $vartype g $g {frcgroup validate $g}
    }

    # Proc: i
    #
    # Validates {i} as a sector
    
    proc i {domain vartype i} {
        ValidateIndex $domain $vartype i $i {econ sector validate $i}
    }

    # Proc: i
    #
    # Validates {i} as a sector
    
    proc i {domain vartype i} {
        ValidateIndex $domain $vartype i $i {esector validate $i}
    }

    # Proc: ij
    #
    # Validates {i} as a sector
    
    proc ij {domain vartype i j} {
        ValidateIndex $domain $vartype i $i {esector validate $i}
        ValidateIndex $domain $vartype j $j {esector validate $j}
    }


    # Proc: n
    #
    # Validates {n} as a nbhood
    
    proc n {domain vartype n} {
        ValidateIndex $domain $vartype n $n {nbhood validate $n}
    }

    # Proc: fg_coop
    #
    # Validates {f g} for cooperation
    
    proc fg_coop {domain vartype f g} {
        ValidateIndex $domain $vartype f $f {civgroup validate $f}
        ValidateIndex $domain $vartype g $g {frcgroup validate $g}
    }

    # Proc: ng_coop
    #
    # Validates {n g} for cooperation
    
    proc ng_coop {domain vartype n g} {
        ValidateIndex $domain $vartype n $n {nbhood   validate $n}
        ValidateIndex $domain $vartype g $g {frcgroup validate $g}
    }

    # Proc: ga_vrel
    #
    # Validates {g a} for vrel
    
    proc ga_vrel {domain vartype g a} {
        ValidateIndex $domain $vartype g $g {group validate $g}
        ValidateIndex $domain $vartype a $a {actor validate $a}
    }

    # Proc: gc_sat
    #
    # Validates {n g c} as a satisfaction curve
    
    proc gc_sat {domain vartype g c} {
        ValidateIndex $domain $vartype g $g {civgroup validate $g}
        ValidateIndex $domain $vartype c $c {ptype c validate $c}
    }
}
