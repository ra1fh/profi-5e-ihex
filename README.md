
Profi 5E IHEX loader
====================

IHEX loader that can be embedded into the
[Profi 5E](https://de.wikipedia.org/wiki/PROFI-5-Mikrocomputerfamilie)
monitor ROM. The Profi 5E is an 8085 based computer primarily used in
education.

### Build Dependencies

 * [python-intelhex](https://pypi.org/project/intelhex/)
 * [AS macroassembler](http://john.ccac.rwth-aachen.de:8000/as/)
 * The original ROM has to be supplied as profi-5e-monitor.bin

### Building

    make
	make embed

### Usage

To start the ihex loader, press F-E and then G to start. The display
shows "_ lAdE _". The symbols left and right will show a load
animation during transmission.

After the transfer completed successfully, the display shows
"EndE". If there was an error during transfer, the display would show
"FEHLEr". When neither of those is shown, there might have been an
internal error.

The first address of the ihex file will be stored such that the B-key
entry form is pre-populated with that address for easy starting.

The transfer speed setting is done as explained in the Profi-5E
documentation via the micro switches. On my system, transfer speeds
up to 1200 bit/s do work reliably.
