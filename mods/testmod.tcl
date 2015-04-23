# testmod.tcl
mod athena 6.3.0a9 2 "My test mod 2" {
    proc doit {} {
        puts "I really did it again!"
    }
}

mod athena 6.3.0a9 1 "My test mod" {
    proc doit {} {
        puts "I did it!"
    }
}

mod app_athenawb 6.3.0a9 1 "My app mod" {
    proc doit2 {} {
        puts "I didn't do it!"
    }
}