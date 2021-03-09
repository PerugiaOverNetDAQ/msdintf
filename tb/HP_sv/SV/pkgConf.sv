import FOOTpackage::cadc_data_width;
import FOOTpackage::cfe_daisy_chain_depth;
import FOOTpackage::cfe_channels;
import FOOTpackage::cfe_clock_cycles;
import FOOTpackage::ctotal_adcs;


package pkgConf;
  time fast_clock_period = 13ns;
  int trans_count = 2;

  //ADC and FE configuration
  logic [15:0] adc_clock_divider = 16'd2;
  logic [15:0] fe_clock_divider  = adc_clock_divider*20;
  logic [15:0] adc_clock_duty = 16'd4;
  logic [15:0] fe_clock_duty  = 16'd7;
  logic [3:0]  CfgFe = 4'b0000;
  logic [31:0] int_trig_period = 'h00010000;
  time fe_clock_period = (2ns*fast_clock_period)*fe_clock_divider;

  //parameters and variables taken from FOOTpackage.vhd
  parameter adc_data_width = FOOTpackage::cadc_data_width;
  parameter fe_clock_cycles = FOOTpackage::cfe_clock_cycles;
  parameter total_adcs = FOOTpackage::ctotal_adcs;
  parameter pfe_hold2shift_delay = FOOTpackage::cfe_hold2shift_delay;
endpackage
