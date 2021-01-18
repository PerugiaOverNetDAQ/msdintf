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
    iCLK         : in  std_logic;       --!Main clock
    iRST         : in  std_logic;       --!Main reset
    -- control interface
    iEN          : in  std_logic;       --!Enable
    iTRIG        : in  std_logic;       --!External trigger
    oCNT         : out tControlIntfOut;     --!Control signals in output
    oCAL_TRIG    : out std_logic;
    iFE_CLK_DIV  : in  std_logic_vector(15 downto 0);  --!FE SlowClock divider
    iADC_CLK_DIV : in  std_logic_vector(15 downto 0);  --!ADC SlowClock divider
    iFE_CLK_DUTY : in  std_logic_vector(15 downto 0);  --!FE SlowClock duty cycle
    --!iCFG_PLANE bits: 2:0: FE-Gs;  3: FE-test; 4: Ext-TRG; 15:5: x
    iCFG_PLANE   : in  std_logic_vector(15 downto 0);  --!uSTRIP configurations
    iTRG_PERIOD  : in  std_logic_vector(15 downto 0);  --!Clock-cycles between two triggers
    iTRG2HOLD    : in  std_logic_vector(15 downto 0);  --!Clock-cycles between an external trigger and the FE-HOLD signal
    -- First FE-ADC chain ports
    oFE0         : out tFpga2FeIntf;    --!Output signals to the FE1
    oADC0        : out tFpga2AdcIntf;   --!Output signals to the ADC1
    -- Second FE-ADC chain ports
    oFE1         : out tFpga2FeIntf;    --!Output signals to the FE2
    oADC1        : out tFpga2AdcIntf;   --!Output signals to the ADC2
    iMULTI_ADC   : in  tMultiAdc2FpgaIntf;  --!Input signals from the ADC1
    --to event builder signals
    oDATA        : out tAllFifoOut_ADC;
    DATA_VALID   : out std_logic;
    END_OF_EVENT : out std_logic
    );
end Data_Builder_Top;


architecture std of Data_Builder_Top is

  signal sCLK     : std_logic;
  signal sRST     : std_logic;
  signal sEn      : std_logic;
  signal sTrigInt : std_logic;
  signal siTrig   : std_logic;
  signal soFE0    : tFpga2FeIntf;
  signal soFE1    : tFpga2FeIntf;
  signal siFE     : tFe2FpgaIntf;

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
  signal siFE_CLK_DUTY   : std_logic_vector(15 downto 0);
  signal siCFG_PLANE     : std_logic_vector(15 downto 0);
  signal siTRG_PERIOD    : std_logic_vector(15 downto 0);
  signal siTRG2HOLD      : std_logic_vector(15 downto 0);
  signal siFE_CLK_DIV    : std_logic_vector(15 downto 0);
  signal siADC_CLK_DIV   : std_logic_vector(15 downto 0);


begin

  --- Combinatorial assignments ------------------------------------------------
  sCLK          <= iCLK;
  sRST          <= iRST;
  sEN           <= iEN;
  siTrig        <= iTRIG;
  siMULTI_ADC   <= iMULTI_ADC;
  siFE.ShiftOut <= '1';

  DATA_VALID    <= sDATA_VALID;
  END_OF_EVENT  <= sEND_OF_EVENT;
  oDATA         <= soDATA;
  oCNT          <= sCntOut;
  oCAL_TRIG     <= sCalTrig;
  oFE0          <= soFE0;
  oFE1          <= soFE1;
  oADC0         <= soADC0;
  oADC1         <= soADC1;

  siTRG_PERIOD  <= iTRG_PERIOD;
  siTRG2HOLD    <= iTRG2HOLD;
  siFE_CLK_DIV  <= iFE_CLK_DIV;
  siADC_CLK_DIV <= iADC_CLK_DIV;
  

  sHpCfg   <= iCFG_PLANE(3 downto 0);
  sTrigInt <= iCFG_PLANE(4);

  sCntIn.en    <= iEN;
  sCntIn.start <= sCalTrig when sTrigInt = '1' else
                  sExtTrigDel;
  sCntIn.slwClk <= '0';
  sCntIn.slwEn  <= '0';
  ------------------------------------------------------------------------------

  --!@brief Pulse generator for calibration triggers
  --!@todo Also the Cal triggers have to be delayed as the external trigger?
  cal_trigger_gen : pulse_generator
    generic map(
      pPOLARITY => '1',
      pLENGTH   => 1
      ) port map(
        iCLK           => sCLK,
        iRST           => sRST,
        iEN            => sTrigInt,
        oPULSE         => sCalTrig,
        oPULSE_RISING  => open,
        oPULSE_FALLING => open,
        iPERIOD        => siTRG_PERIOD
        );

  --!@brief Delay the external trigger before the FE start
  ext_trig_delay : delay_timer
    port map(
      iCLK   => sCLK,
      iRST   => sRST,
      iSTART => siTRIG,
      iDELAY => siTRG2HOLD,
      oBUSY  => sExtTrigDelBusy,
      oOUT   => sExtTrigDel
      );

  --!@brief Low-level multiple ADCs plane interface
  DETECTOR_INTERFACE : multiAdcPlaneInterface
    generic map (
      pACTIVE_EDGE => "F"               --!"F": falling, "R": rising
      )
    port map (
      iCLK         => sCLK,             --!Main clock
      iRST         => sRST,             --!Main reset
      -- control interface
      oCNT         => sCntOut,
      iCNT         => sCntIn,           --!Control signals in output
      iFE_CLK_DIV  => siFE_CLK_DIV,
      iADC_CLK_DIV => siADC_CLK_DIV,
      iCFG_FE      => sHpCfg,
      -- FE interface
      oFE0         => soFE0,            --!Output signals to the FE1
      oFE1         => soFE1,            --!Input signals from the FE1
      iFE          => siFE,             --!Input signals from the FE2
      -- ADC interface
      oADC0        => soADC0,           --!Output signals to the ADC2
      oADC1        => soADC1,           --!Output signals to the ADC1
      iMULTI_ADC   => siMULTI_ADC,      --!Input signals from the ADC1
      -- FIFO output interface
      oMULTI_FIFO  => soMULTI_FIFO,     --!Output interface of a FIFO1
      iMULTI_FIFO  => siMULTI_FIFO  --!Input interface of a FIFO1   -----define
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
