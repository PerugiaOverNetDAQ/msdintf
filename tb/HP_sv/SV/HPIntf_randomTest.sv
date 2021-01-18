`include "environment.sv"

program HPIntf_randomTest(FeFpgaIntf.FE FeIntf, AdcFpgaIntf.ADC AdcIntf,
                            FifoIntf.USER Fifo);

  environment env;

  initial begin
    //Create the environment and initialise its variables
    env = new(FeIntf, AdcIntf, Fifo);

    //Run the test
    $display("[TST] Test Running");
    env.run();

  end //initial
endprogram : HPIntf_randomTest
