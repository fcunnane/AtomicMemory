#!/bin/bash
echo
echo "Flashing Atomic1024Bank.sof (clean 1024-cell array, no SignalTap)"
echo
quartus_pgm -c 1 -m jtag -o "p;Atomic1024Bank.sof"
echo
echo "Done! Board now running 1024 Atomic Memory cells."
read -p "Press Enter to exit"
