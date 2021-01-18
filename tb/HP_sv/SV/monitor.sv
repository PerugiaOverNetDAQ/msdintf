class monitor;
  parameter adc_data_width = pkgConf::adc_data_width;
  int TransCount = pkgConf::trans_count;
  int TotalAdcs = pkgConf::total_adcs;
  int FeClockCycles = pkgConf::fe_clock_cycles;
  int TotalIterations = TransCount*FeClockCycles;

  logic delayed_rd;
  FeTransaction FeTrans;

  //virtual FifoIntf.USER #(adc_data_width) Fifo (tbench_top.clk, tbench_top.rst);
  virtual FifoIntf #(.width(pkgConf::adc_data_width), .TotalAdcs(pkgConf::total_adcs)) Fifo;
  mailbox mon2scb;

  function new(virtual FifoIntf #(.width(pkgConf::adc_data_width), .TotalAdcs(pkgConf::total_adcs)) Fifo, mailbox mon2scb);
    this.mon2scb = mon2scb;
    this.Fifo = Fifo;

    this.delayed_rd = '0;
  endfunction

  task read();
    for (int a=0; a<TotalAdcs; a++) begin
      Fifo.rd[a] = 0;
    end
    delayed_rd = 0;
    forever begin
      @(posedge Fifo.clk);
      delayed_rd = Fifo.rd[0];
      for (int a=0; a<TotalAdcs; a++) begin
        if (Fifo.empty[a] == 0)
          Fifo.rd[a] = 1;
        else
          Fifo.rd[a] = 0;
      end
    end //forever
  endtask : read

  task push();
    int i;
    repeat (TransCount) begin
      FeTrans = new();
      i=0;
      while (i<FeClockCycles) begin
        @(posedge Fifo.clk);
        if (delayed_rd == 1) begin
          //$info("[MON] Word in output when delayed_rd=1: %h", Fifo.q);
          for (int a=0; a<TotalAdcs; a++) begin
            //$info("[MON] Word in output %d: %h", a, Fifo.q[a]);
            FeTrans.AnalOut[i][a] = Fifo.q[a];
          end //for-loop a
          i++;
        end //delayed_rd
      end //while-i
      mon2scb.put(FeTrans);
    end //repeat
  endtask : push

  task main();
    fork
      this.read();
      this.push();
    join_any
  endtask : main

endclass : monitor
