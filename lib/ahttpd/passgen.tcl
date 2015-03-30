#-----------------------------------------------------------------------
# TITLE:
#    passgen.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): Password Generator
#
#    Generate a password according to the passgen_rules array.
#    No sanity checks on the supplied rules are done.
#
#    Source: http://mini.net/tcl/Password%20Generator
#    Author: Mark Oakden http:/wiki.tcl.tk/MNO
#    Version: 1.0
#
#    Modifications:
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::passgen {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # dataset array:
    #
    # Datasets for password generation:-
    # separate lowercase and UPPERCASE letters so we can demand minimum
    # number of each separately.

    typevariable dataset -array {
        letters "abcdefghijklmnopqrstuvwxyz"
        LETTERS "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        numbers "0123456789"
        punctuation "!\"\x{00A3}$%^&*()_+-={};':@#~<>,.?/\\|"
    }

    # rules array
    #
    # The rules determine characteristics of the randomly generated 
    # passwords.  Presently available are:
    # 
    # len            - password length
    # <dataset>,min  - minimum number of characters from <dataset>
    #                  entry on the passgen array
    typevariable rules -array {
        len             7
        letters,min     1
        LETTERS,min     1
        numbers,min     1
        punctuation,min 1
    }

    #-------------------------------------------------------------------
    # Public Type Methods

    # generate a password
    typemethod generate {} {
        # Algorithm
        # 1. foreach dataset with a min parameter, choose exactly min
        #    random chars from it
        # 2. concatenate results of above into password
        # 3. concatenate all datasets into large dataset
        # 4. choose desired_length-password_length chars from large
        # 5. concatenate (4) and (2)
        # 6. shuffle (5)
        
        set password {}
        foreach indx [array names rules *,min] {
            set ds_name [lindex [split $indx ,] 0]
            set num $rules($indx)
            for {set i 1} {$i <= $num} {incr i 1} {
                append password [OneCharFrom $dataset($ds_name)]
            }
        }
        
        set all_data {}
        foreach set [array names dataset] {
            append all_data $dataset($set)
        }
        
        set rem_len [expr $rules(len) - [string length $password]]
        for {set i 1} {$i <= $rem_len} {incr i 1} {
            append password [OneCharFrom $all_data]
        }
        
        return [Shuffle $password]
    }

    # generate a salt
    typemethod salt {} {
        set dataset(saltstr) "$dataset(LETTERS)$dataset(letters)$dataset(numbers)"
        set slen [string len $dataset(saltstr)]
        return "[string index $dataset(saltstr) [expr round(rand() * $slen)]][string index $dataset(saltstr) [expr round(rand() * $slen)]]"
    }


    #-------------------------------------------------------------------
    # Helper Procs
    

    # picks a (pseudo)random char from str
    proc OneCharFrom { str } {
        set len [string length $str]
        set indx [expr int(rand()*$len)]
        return [string index $str $indx]
    }

    # given a string, and integers i and j, swap the ith and jth chars of str
    # return the result
    proc Swap { str i j } {
        if { $i == $j } {
            return $str
        }
        if { $i > $j } {
            set t $j
            set j $i
            set i $t
        }
        set pre [string range $str 0 [expr $i - 1]]
        set chari [string index $str $i]
        set mid [string range $str [expr $i + 1] [expr $j - 1]]
        set charj [string index $str $j]
        set end [string range $str [expr $j + 1] end]
        
        set ret ${pre}${charj}${mid}${chari}${end}
        return $ret
    }

    # for a string of length n,  swap random pairs of chars n times
    # and return the result
    proc Shuffle { str } {
        set len [string length $str]
        for { set i 1 } { $i <= $len } { incr i 1 } {
            set indx1 [expr int(rand()*$len)]
            set indx2 [expr int(rand()*$len)]
            set str [Swap $str $indx1 $indx2]
        }
        return $str
    }    
}
