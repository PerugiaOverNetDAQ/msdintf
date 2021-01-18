class FootDriver;
  //ADC AD7476 time constraints
  ////parameter time tq = 10ns; //Minimum quiet time between conversions
  ////parameter time t2 = 10ns; //CS to SCLK setup time
  ////parameter time t3 = 22ns; //Delay from CS until SDATA three-state disabled
  ////parameter time t4 = 40ns; //Data access time after SCLK falling edge
  ////parameter time t7 = 10ns; //SCLK to data valid hold time
  ////parameter time t8 = 36ns; //SCLK falling edge to SDATA high-impedance

  //ADC time constraints
  parameter time tq = 4ns; //Minimum quiet time between conversions
  parameter time t2 = 6ns; //CS to SCLK setup time
  parameter time t3 = 4ns; //Delay from CS until SDATA three-state disabled
  parameter time t4 = 15ns; //Data access time after SCLK falling edge
  parameter time t7 = 5ns; //SCLK to data valid hold time
  parameter time t8 = 14ns; //SCLK falling edge to SDATA high-impedance

  //Total number of transactions generated
  int  TransCount       = pkgConf::trans_count;
  int  TotalAdcs        = pkgConf::total_adcs;
  int  FeClockCycles    = pkgConf::fe_clock_cycles;
  time fe_clock_period  = pkgConf::fe_clock_period;

  //handles for the two virtual interfaces of ADC and FE
  virtual AdcFpgaIntf #(pkgConf::total_adcs) ifAdc;
  virtual FeFpgaIntf ifFe;

  //creating mailbox handle
  mailbox gen2drv;
  mailbox fe2adc; //analog values to be passed from the FE to the ADC

  //constructor: get the interfaces and mailboxes handles from the environment
  function new(virtual AdcFpgaIntf #(pkgConf::total_adcs) ifAdc, virtual FeFpgaIntf ifFe,
                mailbox gen2drv);
    this.ifAdc = ifAdc;
    this.ifFe = ifFe;
    this.gen2drv = gen2drv;

    this.fe2adc = new();
  endfunction

  //Task for Front-End driver
  task FeDriver();
    ifFe.ShiftOutn = '1;
    for (int t=0; t<TransCount;t++) begin
      FeTransaction FeTrans;
      gen2drv.get(FeTrans); //blocking acquisition of the transaction

      @(negedge ifFe.Holdn);
      @(negedge ifFe.ShiftInn);

      fe2adc.put(FeTrans.AnalOut[0]);
      //$info("[DRV-FE] Word in output: [0]:%h - [1]:%h", FeTrans.AnalOut[0][0], FeTrans.AnalOut[0][1]);
      for (int i=1; i<FeClockCycles; i++)  begin
        @(negedge ifFe.Clk);
        //$info("[DRV-FE] Word in output: [0]:%h - [1]:%h", FeTrans.AnalOut[i][0], FeTrans.AnalOut[i][1]);
        fe2adc.put(FeTrans.AnalOut[i]);
      end //for-loop i
      #(fe_clock_period/2ns);
      ifFe.ShiftOutn = '0;
      #(fe_clock_period/2ns);
      ifFe.ShiftOutn = '1;
    end //for-loop t
  endtask : FeDriver

  //Task for ADC driver
  task AdcDriver();
    logic [pkgConf::total_adcs-1:0] [pkgConf::adc_data_width-1:0] pData;
    shortint unsigned AnalVal [pkgConf::total_adcs];
    ifAdc.SData = 'z;

    forever begin
      //Get the analog value and convert it in a 16-bit word
      fe2adc.get(AnalVal);
      for (int a=0; a<TotalAdcs; a++) begin
        pData[TotalAdcs-a-1] = pkgConf::adc_data_width'(AnalVal[a]);
        //$info("[ADC-FE] %d AnalVal:%h pData:%h", a, AnalVal[a], pData[a]);
      end //for-loop a;
      //Send the word serially
      @(negedge ifAdc.CsN);
      #t3; //CSn setup time
      for (int a=0; a<TotalAdcs; a++) begin
        ifAdc.SData[a] = pData[a][pkgConf::adc_data_width-1];
      end //for-loop a
      for (int i=1; i<pkgConf::adc_data_width; i++) begin
        @(negedge ifAdc.SClk);
        #t7; //SCLK setup time
        for (int a=0; a<TotalAdcs; a++) begin
          ifAdc.SData[a] = pData[a][pkgConf::adc_data_width-i-1];
        end //for-loop a
      end //for-loop i

      @(negedge ifAdc.SClk);
      #t8; //SCLK to H-Z time
      ifAdc.SData = 'z;
      #tq; //Quiet time
    end  //forever
    $display("[DRV-ADC] Concluded");
  endtask : AdcDriver

  //Launch the two threads and wait for their execution
  task main();
    fork
      this.FeDriver();
      this.AdcDriver();
    join_any
  endtask : main

endclass
