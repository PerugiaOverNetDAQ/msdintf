This repository contains the FPGA gateware to readout the microstrip detector of the FOOT experiment.

---
## Specifications for the FE-ADC sequencer

1.	[x] The system shall react to an **external trigger**
2.	[x] The system shall produce an **internal periodic trigger** for calibration purpose
	1. [x] The frequency of this trigger shall be settable via a register
3.	[x] During the whole operation of readout, the system shall assert a **busy line** to the central DAQ
4.	[x] 10 FEs are needed for a microstrip plane, divided into two subsets of 5 FEs connected in a daisy-chain fashion
	1.	FE: IDEAS IDE1140: 64-channel silicon-strip readout with analog mux output
5.	[x] For each chain of FEs there is 1 ADC, for a total of 2 ADCs in parallel to cover a u-strip plane
	1.	Serial ADC still TBC; possibly the AD7276

---

*Once a trigger occurs, the sequencer shall perform the following steps:*

1.	[x] **Assert the hold line** of the FEs
	1.	[x] The hold signal shall be asserted 6.5 us after the trigger
	2.	[x] This delay shall be settable from a register
2.	[x] **Send the clock** to the FEs and to the ADCs
3.	[x] Shift the analog output of the FEs into the ADCs
4.	[x] **Collect the digital output** from the ADCs
5.	[x] Up to now (12-Jan-2020), ADCs and FEs should have **synchronous clocks**, both at 1 MHz
	1.	[x] Variable frequency, settable by a register
	2.	[x] Possibility to have different frequencies for ADCs and FEs
6.	[] The clock of the FE shall have a duty-cycle lower than 50%, in order to avoid ringing at the sampling

---

*Desiderata:*

1.	[] Compression algorithm
	1.	There is the AMS one that may be implemented in FPGA
