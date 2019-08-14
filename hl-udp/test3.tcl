package require snit

snit::type test {
    option -a
    option -b
    option -c
}

test foo

puts [foo info options]
