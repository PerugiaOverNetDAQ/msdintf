class FeTransaction;
  parameter TransDepth = pkgConf::fe_clock_cycles;
  parameter TotalAdcs  = pkgConf::total_adcs;
  parameter AdcWidth   = pkgConf::adc_data_width;

  //rand shortint unsigned AnalOut [TransDepth] [TotalAdcs];
  rand logic [TransDepth-1:0] [TotalAdcs-1:0] [AdcWidth-1:0] AnalOut;
  //shortint unsigned AnalOut[TransDepth] = {'h8000, 'hC000, 'hE000, 'hF000,
  //                                          'hAAAA, 'h5555, 'h1000, 'hFFFF,
  //                                          'h0001, 'h0003, 'h0007, 'h000F
  //                                        };
  //logic [TransDepth-1:0] [TotalAdcs-1:0] [AdcWidth-1:0] AnalOut =
  //'{ '{'h8000, 'h8000},
  //   '{'h8888, 'h1111},
  //   '{'hAAAA, 'h5555},
  //   '{'hAAAA, 'h5555}
  //};

endclass : FeTransaction
