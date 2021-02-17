
.PHONY: clean default upload embed

AS = asl -cpu 8085 -gnuerrors
PRJ = ihex-8085
SPD = 300
CUA = /dev/cuaU0

# profi-5e-monitor.bin needs to be supplied
MONITORROM = profi-5e-monitor

# profi-5e-hex.bin is the output file with embedded intel-hex
# functionality
IHEXROM = profi-5e-ihex

default: $(PRJ).hex $(PRJ).bin

$(PRJ).hex: $(PRJ).p
	p2hex $(PRJ).p

$(PRJ).bin: $(PRJ).p
	p2bin $(PRJ).p

$(PRJ).p: $(PRJ).asm
	$(AS) -L $(PRJ) $(PRJ).asm

embed: $(IHEXROM).bin

$(IHEXROM).bin: $(MONITORROM).bin $(PRJ).hex
	bin2hex.py $(MONITORROM).bin $(MONITORROM).hex
	hexmerge.py -o $(IHEXROM).hex --overlap=replace $(MONITORROM).hex $(PRJ).hex ihex-patch.hex
	hex2bin.py $(IHEXROM).hex $(IHEXROM).bin

clean:
	rm -f $(PRJ).hex $(PRJ).bin $(PRJ).prn $(PRJ).p $(PRJ).lst
	rm -f $(IHEXROM).bin $(IHEXROM).hex
	rm -f $(MONITORROM).hex
