--!@file Data_Builder_Top.vhd
--!@brief Instantiate the Data_Builder.vhd and the multiAdcPlaneInterface.vhd
--!@author Keida Kanxheri (keida.kanxheri@pg.infn.it)
--!@author Mattia Barbanera (mattia.barbanera@infn.it)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.basic_package.all;
use work.FOOTpackage.all;

--!@brief Instantiate the Data_Builder.vhd and the multiAdcPlaneInterface.vhd
--!@details Top to interconnect all of the u-strip-related modules
entity Data_Builder_Top is
  port (
    iCLK         : in  std_logic;          --!Main clock
    iRST         : in  std_logic;          --!Main reset
    -- control interface
    iEN          : in  std_logic;          --!Enable
    iTRIG        : in  std_logic;          --!External trigger
    oCNT         : out tControlIntfOut;    --!Control signals in output
    oCAL_TRIG    : out std_logic;          --!Internal trigger output
    iMSD_CONFIG  : in  msd_config;         --!Configuration from the control registers
    -- First FE-ADC chain ports
    oFE0         : out tFpga2FeIntf;       --!Output signals to the FE1
    oADC0        : out tFpga2AdcIntf;      --!Output signals to the ADC1
    -- Second FE-ADC chain ports
    oFE1         : out tFpga2FeIntf;       --!Output signals to the FE2
    oADC1        : out tFpga2AdcIntf;      --!Output signals to the ADC2
    iMULTI_ADC   : in  tMultiAdc2FpgaIntf; --!Input signals from the ADC1
    --to event builder signals
    oDATA        : out tAllFifoOut_ADC;
    DATA_VALID   : out std_logic;
    END_OF_EVENT : out std_logic
    );
end Data_Builder_Top;


architecture std of Data_Builder_Top is

  signal sCLK        : std_logic;
  signal sRST        : std_logic;
  signal sTrigInt    : std_logic;
  signal sTrigRising : std_logic;
  signal soFE0       : tFpga2FeIntf;
  signal soFE1       : tFpga2FeIntf;
  signal siFE        : tFe2FpgaIntf;

  signal soADC0        : tFpga2AdcIntf;
  signal soADC1        : tFpga2AdcIntf;
  signal siMULTI_ADC   : tMultiAdc2FpgaIntf;  --!Input signals from the ADC1
  signal soMULTI_FIFO  : tMultiAdcFifoOut;    --!Output interface of a FIFO1
  signal siMULTI_FIFO  : tMultiAdcFifoIn;     --!Input interface of a FIFO1
  signal sDATA_VALID   : std_logic;
  signal sEND_OF_EVENT : std_logic;
  signal soDATA        : tAllFifoOut_ADC;

  signal sCntOut         : tControlIntfOut;
  signal sCntIn          : tControlIntfIn;
  signal sHpCfg          : std_logic_vector (3 downto 0);
  signal sExtTrigDel     : std_logic;
  signal sCalTrig        : std_logic;
  signal sExtTrigDelBusy : std_logic;


begin

  --- Combinatorial assignments ------------------------------------------------
  sCLK          <= iCLK;
  sRST          <= iRST;
  siMULTI_ADC   <= iMULTI_ADC;
  siFE.ShiftOut <= '1';

  DATA_VALID   <= sDATA_VALID;
  END_OF_EVENT <= sEND_OF_EVENT;
  oDATA        <= soDATA;
  oCNT.busy    <= sCntOut.busy or sExtTrigDelBusy;
  oCNT.error   <= sCntOut.error;
  oCNT.reset   <= sCntOut.reset;
  oCNT.compl   <= sCntOut.compl;
  oCAL_TRIG    <= sCalTrig;
  oFE0         <= soFE0;
  oFE1         <= soFE1;
  oADC0        <= soADC0;
  oADC1        <= soADC1;

  sHpCfg   <= iMSD_CONFIG.cfgPlane(3 downto 0);
  sTrigInt <= iMSD_CONFIG.cfgPlane(4);

  sCntIn.en    <= iEN;
  sCntIn.start <= sCalTrig when sTrigInt = '1' else
                  sExtTrigDel;
  sCntIn.slwClk <= '0';
  sCntIn.slwEn  <= '0';

  --!@test Trigger already filtered from stationary signals
  --trig_edge : edge_detector
  --  port map(
  --    iCLK    => iCLK,
  --    iRST    => '0',
  --    iD      => iTRIG,
  --    oEDGE_R => sTrigRising
  --    );
	sTrigRising <= iTRIG;
  ------------------------------------------------------------------------------

  --!@brief Pulse generator for calibration triggers
  --!@todo Also the Cal triggers have to be delayed as the external trigger?
  cal_trigger_gen : pulse_generator
    generic map(
      pWIDTH    => 32,
      pPOLARITY => '1',
      pLENGTH   => 1
      ) port map(
        iCLK           => sCLK,
        iRST           => sRST,
        iEN            => sTrigInt,
        oPULSE         => sCalTrig,
        oPULSE_RISING  => open,
        oPULSE_FALLING => open,
        iPERIOD        => iMSD_CONFIG.intTrgPeriod
        );

  --!@brief Delay the external trigger before the FE start
  ext_trig_delay : delay_timer
    port map(
      iCLK   => sCLK,
      iRST   => sRST,
      iSTART => sTrigRising,
      iDELAY => iMSD_CONFIG.trg2Hold,
      oBUSY  => sExtTrigDelBusy,
      oOUT   => sExtTrigDel
      );

  --!@brief Low-level multiple ADCs plane interface
  DETECTOR_INTERFACE : multiAdcPlaneInterface
    generic map (
      pACTIVE_EDGE => "F"               --!"F": falling, "R": rising
      )
    port map (
      iCLK          => sCLK,            --!Main clock
      iRST          => sRST,            --!Main reset
      -- control interface
      oCNT          => sCntOut,
      iCNT          => sCntIn,          --!Control signals in output
      iFE_CLK_DIV   => iMSD_CONFIG.feClkDiv,    --!FE SlowClock divider
      iFE_CLK_DUTY  => iMSD_CONFIG.feClkDuty,   --!FE SlowClock duty cycle
      iADC_CLK_DIV  => iMSD_CONFIG.adcClkDiv,   --!ADC SlowClock divider
      iADC_CLK_DUTY => iMSD_CONFIG.adcClkDuty,  --!ADC SlowClock divider
      iCFG_FE       => sHpCfg,          --!FE configurations
      -- FE interface
      oFE0          => soFE0,           --!Output signals to the FE1
      oFE1          => soFE1,           --!Input signals from the FE1
      iFE           => siFE,            --!Input signals from the FE2
      -- ADC interface
      oADC0         => soADC0,          --!Output signals to the ADC2
      oADC1         => soADC1,          --!Output signals to the ADC1
      iMULTI_ADC    => siMULTI_ADC,     --!Input signals from the ADC1
      -- FIFO output interface
      oMULTI_FIFO   => soMULTI_FIFO,    --!Output interface of a FIFO1
      iMULTI_FIFO   => siMULTI_FIFO  --!Input interface of a FIFO1   -----define
      );

  --!@brief Collects data from the MSD and assembles them in a single packet
  EVENT_BUILDER : Data_Builder
    port map (
      iCLK         => sCLK,
      iRST         => sRST,
      iMULTI_FIFO  => soMULTI_FIFO,
      oMULTI_FIFO  => siMULTI_FIFO,
      oDATA        => soDATA,
      DATA_VALID   => sDATA_VALID,
      END_OF_EVENT => sEND_OF_EVENT
      );


end architecture;
