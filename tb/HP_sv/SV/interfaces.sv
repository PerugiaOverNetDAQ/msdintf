//Interface between the FrontEnd and the FPGA
interface FeFpgaIntf();
  logic G0;
  logic G1;
  logic G2;
  logic Holdn;
  logic DRst;
  logic ShiftInn;
  logic Clk;
  logic TestOn;
  logic ShiftOutn;

  //Ports seen from the FE
  modport FE(
    input  G0, G1, G2,
    input  Holdn, DRst, ShiftInn, Clk,
    input  TestOn,
    output ShiftOutn
  );

  //Ports seen from the FPGA
  modport FPGA(
    output G0, G1, G2,
    output Holdn, DRst, ShiftInn, Clk,
    output TestOn,
    input  ShiftOutn
  );
endinterface : FeFpgaIntf

//Interface between the ADC and the FPGA
interface AdcFpgaIntf #(parameter TotalAdcs) ();
  logic                 SClk;
  logic                 CsN;
  logic [TotalAdcs-1:0] SData;

  //Ports seen from the ADC
  modport ADC(
    input  SClk,CsN,
    output SData
  );

  //Ports seen from the FPGA
  modport FPGA(
    output SClk,CsN,
    input  SData
  );
endinterface : AdcFpgaIntf

//FIFO interface
interface FifoIntf #(parameter width, TotalAdcs) (input logic clk, rst);
  logic [width-1:0] data [TotalAdcs];
  logic [width-1:0] q [TotalAdcs];
  logic             rd [TotalAdcs];
  logic             wr [TotalAdcs];
  logic             aEmpty [TotalAdcs];
  logic             empty [TotalAdcs];
  logic             aFull [TotalAdcs];
  logic             full [TotalAdcs];

  modport FIFO(
    input  data, rd, wr,
    output q, aEmpty, empty, aFull, full
  );

  modport USER(
    output data, rd, wr,
    input  q, aEmpty, empty, aFull, full
  );
endinterface : FifoIntf

// Control interface
interface CntIntf (input clk, input rst);
  logic en;
  logic start;
  logic slwClk;
  logic slwEn;
  logic busy;
  logic error;
  logic reset;
  logic compl;

  modport SLAVE(
    input  en, start, slwClk, slwEn,
    output busy, error, reset, compl
  );

  modport MASTER(
    output en, start, slwClk, slwEn,
    input  busy, error, reset, compl
  );

endinterface : CntIntf

// Configuration ports to the MSD subpart
interface msdConfigIntf();
  logic [15:0] feClkDuty;
  logic [15:0] feClkDiv;
  logic [15:0] adcClkDuty;
  logic [15:0] adcClkDiv;
  logic [15:0] cfgPlane;
  logic [31:0] intTrgPeriod;
  logic [15:0] trg2Hold;

  modport FPGA(
    input feClkDuty, feClkDiv, adcClkDuty, adcClkDiv, cfgPlane, intTrgPeriod, trg2Hold
  );

  modport HPS(
    output feClkDuty, feClkDiv, adcClkDuty, adcClkDiv, cfgPlane, intTrgPeriod, trg2Hold
  );

endinterface : msdConfigIntf
