`timescale 1 ns / 1 ns

import FOOTpackage::tfpga2feintf;
import FOOTpackage::tfe2fpgaintf;
import FOOTpackage::tfpga2adcintf;
import FOOTpackage::tadc2fpgaintf;
import FOOTpackage::tcontrolintfin;
import FOOTpackage::tcontrolintfout;
import FOOTpackage::tfifoout_adc;
import FOOTpackage::tfifoin_adc;
import FOOTpackage::msd_config;

import FOOTpackage::tmultiadc2fpgaintf;
import FOOTpackage::tmultiadcfifoout;
import FOOTpackage::tmultiadcfifoin;

`include "interfaces.sv"
`include "HPIntf_randomTest.sv"
`include "pkgConf.sv"

module tbench_top;
  //clock and reset signal declaration
  bit clk;
  bit rst;

  //clock generation
  always #pkgConf::fast_clock_period clk = ~clk;

  //reset Generation
  initial begin
    rst = 1;
    #50ns rst =0;
  end

  //creating instances of interfaces
  FeFpgaIntf FeIntf();
  AdcFpgaIntf #(pkgConf::total_adcs) AdcIntf ();
  CntIntf iCntIntf (clk, rst);
  FifoIntf #(.width(pkgConf::adc_data_width), .TotalAdcs(pkgConf::total_adcs)) iFifoIntf (clk, rst);

  //Test instance
  HPIntf_randomTest test1(FeIntf.FE, AdcIntf.ADC, iFifoIntf.USER);

  //Declaration of VHDL-equivalent signals for the DUT ports
  tcontrolintfin      sCntIn;
  tcontrolintfout     sCntOut;
  tfpga2feintf        fpga2fe;
  tfe2fpgaintf        fe2fpga;
  tfpga2adcintf       fpga2adc;
  tmultiadc2fpgaintf  adc2fpga;
  tmultiadcfifoout    sFifoOut;
  tmultiadcfifoin     sFifoIn;
  logic [15:0]        FeClkDiv;
  logic [15:0]        FeClkDuty;
  logic [15:0]        AdcClkDiv;
  logic [15:0]        AdcClkDuty;
  logic [3:0]         CfgFe;

  multiAdcPlaneInterface #(
    .pACTIVE_EDGE ("F")
  ) DUT (
    .iCLK         (clk),
    .iRST         (rst),
    .oCNT         (sCntOut),
    .iCNT         (sCntIn),
    .iFE_CLK_DIV  (FeClkDiv),
    .iFE_CLK_DUTY (FeClkDuty),
    .iADC_CLK_DIV (AdcClkDiv),
    .iADC_CLK_DUTY(AdcClkDuty),
    .iCFG_FE      (CfgFe),
    .oFE0         (fpga2fe),
    .oFE1         (),
    .iFE          (fe2fpga),
    .oADC0        (fpga2adc),
    .oADC1        (),
    .iMULTI_ADC   (adc2fpga),
    .oMULTI_FIFO  (sFifoOut),
    .iMULTI_FIFO  (sFifoIn)
  );

  //Initialization of signals and configurations
  initial begin
    FeClkDiv        <= pkgConf::fe_clock_divider;
    FeClkDuty       <= pkgConf::fe_clock_duty;
    AdcClkDiv       <= pkgConf::adc_clock_divider;
    AdcClkDuty      <= pkgConf::adc_clock_duty;
    CfgFe           <= pkgConf::CfgFe;
    for (int a=0;a<pkgConf::total_adcs;a++) begin
        iFifoIntf.wr[a]   <= 1'b0;
        iFifoIntf.data[a] <= 'h0000;
    end
    iCntIntf.slwClk <= 1'b0;
    iCntIntf.slwEn  <= 1'b0;
  end
  assign iCntIntf.en     = !rst;  //FIXME: has to be randomized
  assign iCntIntf.start  = !rst;  //FIXME: has to be randomized

  //Assignments of the ports to the interfaces signals
  assign iCntIntf.busy    = sCntOut.busy;
  assign iCntIntf.error   = sCntOut.error;
  assign iCntIntf.reset   = sCntOut.reset;
  assign iCntIntf.compl   = sCntOut.compl;
  assign sCntIn.en        = iCntIntf.en;
  assign sCntIn.start     = iCntIntf.start;
  assign sCntIn.slwclk    = iCntIntf.slwClk;
  assign sCntIn.slwen     = iCntIntf.slwEn;
  assign FeIntf.G0        = fpga2fe.g0;
  assign FeIntf.G1        = fpga2fe.g1;
  assign FeIntf.G2        = fpga2fe.g2;
  assign FeIntf.Holdn     = fpga2fe.hold;
  assign FeIntf.DRst      = fpga2fe.drst;
  assign FeIntf.ShiftInn  = fpga2fe.shiftin;
  assign FeIntf.Clk       = fpga2fe.clk;
  assign FeIntf.TestOn    = fpga2fe.teston;
  assign fe2fpga.shiftout = FeIntf.ShiftOutn;
  assign AdcIntf.SClk     = fpga2adc.sclk;
  assign AdcIntf.CsN      = fpga2adc.cs;
  //assign adc2fpga.sdata   = AdcIntf.SData;
  //assign iFifoIntf.q      = sFifoOut.q;
  //assign iFifoIntf.aEmpty = sFifoOut.aempty;
  //assign iFifoIntf.empty  = sFifoOut.empty;
  //assign iFifoIntf.aFull  = sFifoOut.afull;
  //assign iFifoIntf.full   = sFifoOut.full;
  //assign sFifoIn.data     = iFifoIntf.data;
  //assign sFifoIn.rd       = iFifoIntf.rd;
  //assign sFifoIn.wr       = iFifoIntf.wr;

  genvar a;
  generate
    for (a=0;a<pkgConf::total_adcs;a++) begin
      assign adc2fpga[a].sdata   = AdcIntf.SData[a];

      assign iFifoIntf.q[a]      = sFifoOut[a].q;
      assign iFifoIntf.aEmpty[a] = sFifoOut[a].aempty;
      assign iFifoIntf.empty[a]  = sFifoOut[a].empty;
      assign iFifoIntf.aFull[a]  = sFifoOut[a].afull;
      assign iFifoIntf.full[a]   = sFifoOut[a].full;

      assign sFifoIn[a].data     = iFifoIntf.data[a];
      assign sFifoIn[a].rd       = iFifoIntf.rd[a];
      assign sFifoIn[a].wr       = iFifoIntf.wr[a];
    end
  endgenerate

  ////enabling the wave dump
  //initial begin
  //  $dumpfile("dump.vcd"); $dumpvars;
  //end
endmodule
