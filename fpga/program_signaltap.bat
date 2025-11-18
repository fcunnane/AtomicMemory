@echo off
echo.
echo Flashing SignalTap.sof (hands-free collapse demo)
echo.
quartus_pgm -c 1 -m jtag -o "p;SignalTap.sof"
echo.
echo Done! Open SignalTap_demo.stp and click Run Analysis.
pause
