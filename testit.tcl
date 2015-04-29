package require kiteutils
namespace import kiteutils::*

set filename myfile.txt

if {[file exists $filename]} {
    puts "Found $filename:\n[readfile $filename]\n"
}

puts "Writing $filename"
set f [open $filename w]

puts $f "argv<$argv>\n[clock format [clock seconds]]"

close $f

puts "Contents of $filename:\n[readfile $filename]"
