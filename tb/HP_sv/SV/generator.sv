class generator;
  int TransCount = pkgConf::trans_count;
  //declaring transaction class
  rand FeTransaction FeTrans;

  //creating mailbox handles
  mailbox gen2drv;
  mailbox gen2scb;

  //constructor: get the configuration from the environment
  function new (mailbox gen2drv, mailbox gen2scb);
    this.gen2drv = gen2drv;
    this.gen2scb = gen2scb;
  endfunction

  task main();
    repeat (TransCount) begin
      FeTrans = new();
      if(!FeTrans.randomize()) $fatal("[GEN] FeTrans randomization failed");
      gen2drv.put(FeTrans);

      //put the same transaction to a scoreboard mailbox as a reference
      gen2scb.put(FeTrans);
    end //repeat
  endtask : main

endclass
