`include "FeTransaction.sv"
`include "generator.sv"
`include "FootDriver.sv"
`include "monitor.sv"
`include "scoreboard.sv"

class environment;
  int TransCount = pkgConf::trans_count;
  int FeClockCycles = pkgConf::fe_clock_cycles;
  int TotalIterations = TransCount*FeClockCycles;

  generator   gen;
  FootDriver  drv;
  monitor     mon;
  scoreboard  scb;

  mailbox gen2drv;
  mailbox gen2scb;
  mailbox mon2scb;

  //virtual interfaces
  virtual FeFpgaIntf FeIntf;
  //virtual AdcFpgaIntf AdcIntf;
  virtual FifoIntf #(.width(pkgConf::adc_data_width), .TotalAdcs(pkgConf::total_adcs)) Fifo;

  virtual AdcFpgaIntf #(pkgConf::total_adcs) AdcIntf;


  function new(virtual FeFpgaIntf FeIntf, virtual AdcFpgaIntf #(pkgConf::total_adcs) AdcIntf,
                virtual FifoIntf #(.width(pkgConf::adc_data_width), .TotalAdcs(pkgConf::total_adcs)) Fifo);
    this.FeIntf = FeIntf;
    this.AdcIntf = AdcIntf;
    this.Fifo = Fifo;

    gen2drv = new();
    gen2scb = new();
    mon2scb = new();
    gen = new(gen2drv, gen2scb);
    drv = new(AdcIntf, FeIntf, gen2drv);
    mon = new(Fifo, mon2scb);
    scb = new(gen2scb, mon2scb);
  endfunction

  task pre_test();
    $display("[ENV] Transactions: %d;\n      FE Channels:  %d",
              TransCount, FeClockCycles);
  endtask : pre_test

  //Actual test
  task test();
    fork
      gen.main();
      drv.main();
      mon.main();
      scb.main();
    join
  endtask : test

  task post_test();
    $display("[ENV] Total transactions: %d - Total errors: %d",
              TransCount, scb.TotErrors);
  endtask : post_test

  task run();
    pre_test();

    test();

    post_test();

    $stop;
  endtask : run

endclass : environment
