
.PHONY: clean default upload embed

AS = asl -cpu 8085 -gnuerrors
PRJ = ihex-8085
SPD = 300
SIM = /dev/cuaU1

# profi-5e-monitor.bin needs to be supplied
MONITORROM = profi-5e-monitor

#
# profi-5e-hex.bin is the output file with embedded intel-hex
# functionality
#
IHEXROM = profi-5e-ihex

default: $(PRJ).hex $(PRJ).bin

$(PRJ)-0000.hex: $(PRJ)-0000.p
	p2hex $(PRJ)-0000.p

$(PRJ)-0000.bin: $(PRJ)-0000.p
	p2bin $(PRJ)-0000.p

$(PRJ)-0000.p: $(PRJ).asm
	$(AS) -D EMBED -L $(PRJ) -o $(PRJ)-0000.p $(PRJ).asm

embed: $(IHEXROM).bin

$(IHEXROM).bin: $(MONITORROM).bin $(PRJ)-0000.hex
	bin2hex.py $(MONITORROM).bin $(MONITORROM).hex
	hexmerge.py -o $(IHEXROM).hex --overlap=replace \
		$(MONITORROM).hex $(PRJ)-0000.hex
	hex2bin.py $(IHEXROM).hex $(IHEXROM).bin

#
# Build targets with load address 0x2000 for testing
# with memSIM2 in second EPROM slot
#
$(PRJ)-2000.hex: $(PRJ)-2000.p
	p2hex $(PRJ)-2000.p

$(PRJ)-2000.bin: $(PRJ)-2000.p
	p2bin $(PRJ)-2000.p

$(PRJ)-2000.p: $(PRJ).asm
	$(AS) -L $(PRJ) -o $(PRJ)-2000.p $(PRJ).asm


upload: $(PRJ)-2000.bin
	memsimctl -d $(SIM) -m 2764 -w $(PRJ)-2000.bin

clean:
	rm -f $(PRJ)-0000.hex $(PRJ)-0000.bin $(PRJ)-0000.prn
	rm -f $(PRJ)-0000.p $(PRJ)-0000.lst
	rm -f $(PRJ)-2000.hex $(PRJ)-2000.bin $(PRJ)-2000.prn
	rm -f $(PRJ)-2000.p $(PRJ)-2000.lst
	rm -f $(IHEXROM).bin $(IHEXROM).hex
	rm -f $(MONITORROM).hex
