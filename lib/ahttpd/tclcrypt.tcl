# tclcrypt.tcl
#
# Unix crypt in pure tcl
# From http://mini.net/tcl/crypt by Michael A. Cleverly (23/Nov/2000)
#
# Used as a fallback for installations without libcrypt.so compiled.
# It's always better to have the compiled C version available, of course

# This version uses the [lset] command introduced in Tcl 8.4.
# It seems to result in a 40-45% improvement in speed over the original 
# version which uses [array]s.

proc ::ahttpd::crypt {password salt} {
    set IP {58 50 42 34 26 18 10  2 60 52 44 36 28 20 12  4 62 54 46 38 30
	22 14  6 64 56 48 40 32 24 16  8 57 49 41 33 25 17  9  1 59 51
	43 35 27 19 11  3 61 53 45 37 29 21 13  5 63 55 47 39 31 23 15 7}

    set FP {40  8 48 16 56 24 64 32 39  7 47 15 55 23 63 31 38  6 46 14 54
	22 62 30 37  5 45 13 53 21 61 29 36  4 44 12 52 20 60 28 35  3
	43 11 51 19 59 27 34  2 42 10 50 18 58 26 33  1 41  9 49 17 57 25}
    
    set PC1_C {57 49 41 33 25 17  9  1 58 50 42 34 26 18 10  2 59 51 43 35 27
	19 11  3 60 52 44 36}
    
    set PC1_D {63 55 47 39 31 23 15  7 62 54 46 38 30 22 14  6 61 53 45 37 29
	21 13  5 28 20 12  4}
    
    set shifts {1 1 2 2 2 2 2 2 1 2 2 2 2 2 2 1}
    
    set PC2_C {14 17 11 24 1 5 3 28 15 6 21 10 23 19 12 4 26 8 16 7 27 20 13 2}
    
    set PC2_D {41 52 31 37 47 55 30 40 51 45 33 48 44 49 39 56 34 53 46 42 50
	36 29 32}
    
    set e {32  1  2  3  4  5  4  5  6  7  8  9  8  9 10 11 12 13 12 13 14 15
	16 17 16 17 18 19 20 21 20 21 22 23 24 25 24 25 26 27 28 29 28 29
	30 31 32 1}
    
    set S {{14  4 13  1  2 15 11  8  3 10  6 12  5  9  0  7  0 15  7  4 14  2
	13  1 10  6 12 11  9  5  3  8  4  1 14  8 13  6  2 11 15 12  9  7
	3 10  5  0 15 12  8  2  4  9  1  7  5 11  3 14 10  0  6 13}
	
	{15  1  8 14  6 11  3  4  9  7  2 13 12  0  5 10  3 13  4  7 15  2
	    8 14 12  0  1 10  6  9 11  5  0 14  7 11 10  4 13  1  5  8 12  6
	    9  3  2 15 13  8 10  1  3 15  4  2 11  6  7 12  0  5 14 9}
	
	{10  0  9 14  6  3 15  5  1 13 12  7 11  4  2  8 13  7  0  9  3  4
	    6 10  2  8  5 14 12 11 15  1 13  6  4  9  8 15  3  0 11  1  2 12
	    5 10 14  7  1 10 13  0  6  9  8  7  4 15 14  3 11  5  2 12}
	
	{ 7 13 14  3  0  6  9 10  1  2  8  5 11 12  4 15 13  8 11  5  6 15
	    0  3  4  7  2 12  1 10 14  9 10  6  9  0 12 11  7 13 15  1  3 14
	    5  2  8  4  3 15  0  6 10  1 13  8  9  4  5 11 12  7  2 14}
	
	{ 2 12  4  1  7 10 11  6  8  5  3 15 13  0 14  9 14 11  2 12  4  7
	    13  1  5  0 15 10  3  9  8  6  4  2  1 11 10 13  7  8 15  9 12  5
	    6  3  0 14 11  8 12  7  1 14  2 13  6 15  0  9 10  4  5  3}
	
	{12  1 10 15  9  2  6  8  0 13  3  4 14  7  5 11 10 15  4  2  7 12
	    9  5  6  1 13 14  0 11  3  8  9 14 15  5  2  8 12  3  7  0  4 10
	    1 13 11  6  4  3  2 12  9  5 15 10 11 14  1  7  6  0  8 13}
	
	{ 4 11  2 14 15  0  8 13  3 12  9  7  5 10  6  1 13  0 11  7  4  9
	    1 10 14  3  5 12  2 15  8  6  1  4 11 13 12  3  7 14 10 15  6  8
	    0  5  9  2  6 11 13  8  1  4 10  7  9  5  0 15 14  2  3 12}
	
	{13  2  8  4  6 15 11  1 10  9  3 14  5  0 12  7  1 15 13  8 10  3
	    7  4 12  5  6 11  0 14  9  2  7 11  4  1  9 12 14  2  0  6 10 13
	    15  3  5  8  2  1 14  7  4 10  8 13 15 12  9  0  3  5  6 11}}
    
    set P {16  7 20 21 29 12 28 17  1 15 23 26  5 18 31 10  2  8 24 14 32 27
	3  9 19 13 30  6 22 11  4 25}
    
    set block {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	0 0 0 0 0 0}
    
    set KS {{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
	{0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
	    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}}
    
    set iobuf {0 0 0 0 0 0 0 0 0 0 0 0 0}
    set f {0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
    
    set pw [split $password ""]
    set pw_pos 0
    for {set i 0} {[scan [lindex $pw $pw_pos] %c c] != -1 && $i < 64} \
	{incr pw_pos} {
	    
	    for {set j 0} {$j < 7} {incr j ; incr i} {
		lset block $i [expr {($c >> (6 - $j)) & 01}]
	    }
	    incr i
	    
	}
    
    set C [list]
    set D [list]
    for {set i 0} {$i < 28} {incr i} {
	lappend C [lindex $block [expr {[lindex $PC1_C $i] - 1}]]
	lappend D [lindex $block [expr {[lindex $PC1_D $i] - 1}]]
    }
    
    for {set i 0} {$i < 16} {incr i} {
	for {set k 0} {$k < [lindex $shifts $i]} {incr k} {
	    set t [lindex $C 0]
	    for {set j 0} {$j < 27} {incr j} {
		lset C $j [lindex $C [expr {$j + 1}]]
	    }

	    lset C 27 $t
	    set t [lindex $D 0]
	    for {set j 0} {$j < 27} {incr j} {
		lset D $j [lindex $D [expr {$j + 1}]]
	    }
	    lset D 27 $t
	}
	
	for {set j 0} {$j < 24} {incr j} {
	    lset KS $i $j [lindex $C [expr {[lindex $PC2_C $j] - 1}]]
	    lset KS $i [expr {$j + 24}] \
		[lindex $D [expr {[lindex $PC2_D $j] - 28 - 1}]]
	}
    }
    
    set E [list]
    for {set i 0} {$i < 48} {incr i} {
	lappend E [lindex $e $i]
    }
    
    for {set i 0} {$i < 66} {incr i} {
	lset block $i 0
    }
    
    set salt [split $salt ""]
    set salt_pos 0
    set val_Z 90
    set val_9 57
    set val_period 46
    
    for {set i 0} {$i < 2} {incr i} {
	scan [lindex $salt $salt_pos] %c c
	incr salt_pos
	lset iobuf $i $c
	
	if {$c > $val_Z} {
	    incr c -6
	}
	if {$c > $val_9} {
	    incr c -7
	}
	incr c -$val_period
	for {set j 0} {$j < 6} {incr j} {
	    if {[expr {($c >> $j) & 01}]} {
		set temp [lindex $E [expr {6 * $i + $j}]]
		lset E [expr {6 * $i + $j}] \
		    [lindex $E [expr {6 * $i + $j + 24}]]
		lset E [expr {6 * $i + $j + 24}] $temp
	    }
	}
    }
    
    set edflag 0
    for {set h 0} {$h < 25} {incr h} {
	set L [list]
	for {set j 0} {$j < 64} {incr j} {
	    lappend L [lindex $block [expr {[lindex $IP $j] - 1}]]
	}
	
	for {set ii 0} {$ii < 16} {incr ii} {
	    if {$edflag} {
		set i [expr {15 - $ii}]
	    } else {
		set i $ii
	    }
	    
	    set tempL [list]
	    for {set j 0} {$j < 32} {incr j} {
		lappend tempL [lindex $L [expr {$j + 32}]]
	    }
	    
	    set preS [list]
	    for {set j 0} {$j < 48} {incr j} {
		lappend preS \
		    [expr {[lindex $L [expr {[lindex $E $j] - 1 + 32}]] ^ [lindex $KS $i $j]}]
	    }

	    for {set j 0} {$j < 8} {incr j} {
		set t [expr {6 * $j}]
		set k [lindex $S $j [expr {
				([lindex $preS $t] << 5) +
				([lindex $preS [expr {$t + 1}]] << 3) +
				([lindex $preS [expr {$t + 2}]] << 2) +
				([lindex $preS [expr {$t + 3}]] << 1) +
				[lindex $preS [expr {$t + 4}]] +
				([lindex $preS [expr {$t + 5}]] << 4)
			    }]]

		set t [expr {4 * $j}]
		lset f $t              [expr {($k >> 3) & 01}]
		lset f [expr {$t + 1}] [expr {($k >> 2) & 01}]
		lset f [expr {$t + 2}] [expr {($k >> 1) & 01}]
		lset f [expr {$t + 3}] [expr { $k       & 01}]
	    }
	    
	    for {set j 0} {$j < 32} {incr j} {
		lset L [expr {$j + 32}] \
		    [expr {[lindex $L $j] ^ [lindex $f [expr {[lindex $P $j] - 1}]]}]
	    }
	    
	    for {set j 0} {$j < 32} {incr j} {
		lset L $j [lindex $tempL $j]
	    }
	}
	
	for {set j 0} {$j < 32} {incr j} {
	    set t [lindex $L $j]
	    lset L $j [lindex $L [expr {$j + 32}]]
	    lset L [expr {$j + 32}] $t
	}
	
	for {set j 0} {$j < 64} {incr j} {
	    lset block $j [lindex $L [expr {[lindex $FP $j] - 1}]]
	}
    }
    
    for {set i 0} {$i < 11} {incr i} {
	set c 0
	for {set j 0} {$j < 6} {incr j} {
	    set c [expr {$c << 1}]
	    set c [expr {$c | [lindex $block [expr {6 * $i + $j}]]}]
	}
	incr c $val_period
	if {$c > $val_9} {
	    incr c 7
	}
	if {$c > $val_Z} {
	    incr c 6
	}
	lset iobuf [expr {$i + 2}] $c
    }
    
    if {[lindex $iobuf 1] == 0} {
	lset iobuf 1 [lindex $iobuf 0]
    }
    
    set encrypted ""
    foreach element $iobuf {
	append encrypted [format %c $element]
    }
    
    return $encrypted
}
