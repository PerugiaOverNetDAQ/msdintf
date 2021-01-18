class scoreboard;
  parameter adc_data_width = pkgConf::adc_data_width;
  int TransCount = pkgConf::trans_count;
  int FeClockCycles = pkgConf::fe_clock_cycles;
  int TotalIterations = TransCount*FeClockCycles;

  mailbox gen2scb;
  mailbox mon2scb;

  int TotErrors;

  function new(mailbox gen2scb, mailbox mon2scb);
    this.gen2scb = gen2scb;
    this.mon2scb = mon2scb;
    TotErrors = 0;
  endfunction

  task main();
    repeat (TransCount) begin
      FeTransaction GenWord;
      FeTransaction MonWord;
      gen2scb.get(GenWord);
      //$display("[SCB] Generator word: %h", GenWord.AnalOut[0]);
      mon2scb.get(MonWord);
      //$display("[SCB] Monitor word: %h", MonWord.AnalOut[0]);
      if (GenWord.AnalOut != MonWord.AnalOut) begin
        TotErrors++;
        $error("[SCB] Expected - Actual");
        for(int i=0; i<$size(GenWord.AnalOut);i++) begin
          $display("%h - %h", GenWord.AnalOut[i], MonWord.AnalOut[i]);
        end
      //end else begin
      //  $info("[SCB] Expected - Actual");
      //  for(int i=0; i<$size(GenWord.AnalOut);i++) begin
      //    $display("%h - %h", GenWord.AnalOut[i], MonWord.AnalOut[i]);
      //  end
      end
    end //repeat
  endtask : main

endclass : scoreboard
