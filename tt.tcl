super proc TickCmd {args} {update idletasks}
super adb advance -ticks 30 -tickcmd ::TickCmd -background yes