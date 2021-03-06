--!@file Data_Builder_Top.vhd
--!@brief Instantiate the Data_Builder.vhd and the multiAdcPlaneInterface.vhd
--!@details Top to interconnect all of the u-strip-related modules
--!@author Keida Kanxheri (keida.kanxheri@pg.infn.it)
--!@author Mattia Barbanera (mattia.barbanera@infn.it)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.basic_package.all;
use work.FOOTpackage.all;

--!@copydoc Data_Builder_Top.vhd
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
    oCOLL_FIFO    : out tCollFifoOut;
    oDATA_VALID   : out std_logic;
    oEND_OF_EVENT : out std_logic
    );
end Data_Builder_Top;

--!@copydoc Data_Builder_Top.vhd
architecture std of Data_Builder_Top is
  --FE+ADC
  signal sFeIn         : tFe2FpgaIntf;
  signal sMultiFifoOut : tMultiAdcFifoOut;    --!Output interface of a FIFO1
  signal sMultiFifoIn  : tMultiAdcFifoIn;     --!Input interface of a FIFO1

  --Configuration
  signal sCntOut  : tControlIntfOut;
  signal sCntIn   : tControlIntfIn;
  signal sHpCfg   : std_logic_vector (11 downto 0);
  signal sAdcFast : std_logic;

  --Trigger
  signal sCalTrigEn : std_logic;
  signal sCalTrig   : std_logic;
  signal sTrigMux   : std_logic;
  signal sTrig      : std_logic;


  --Busy
  signal sTrigDelBusy : std_logic;
  signal sTrigBusy    : std_logic;
  signal sExtendBusy  : std_logic;

begin

  --- Combinatorial assignments ------------------------------------------------
  oCNT.busy    <= sCntOut.busy or sTrigBusy or sExtendBusy;
  oCNT.error   <= sCntOut.error;
  oCNT.reset   <= sCntOut.reset;
  oCNT.compl   <= sCntOut.compl;
  oCAL_TRIG    <= sCalTrig;

  sAdcFast   <= iMSD_CONFIG.cfgPlane(15);
  sCalTrigEn <= iMSD_CONFIG.cfgPlane(14);
  sHpCfg     <= iMSD_CONFIG.cfgPlane(11 downto 0);

  sCntIn.en     <= iEN;
  sCntIn.start  <= sTrig;
  sCntIn.slwClk <= '0';
  sCntIn.slwEn  <= '0';

  sTrigMux <= sCalTrig when sCalTrigEn = '1' else
              iTRIG;

  ------------------------------------------------------------------------------

  --!@brief delay lines
  busy_delay : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      sTrigBusy <= sTrigDelBusy;
      sFeIn.ShiftOut <= '1';
      sFeIn.initRst  <= sTrigMux;
    end if;
  end process;

  --!@brief Pulse generator for calibration triggers
  cal_trigger_gen : pulse_generator
    generic map(
      pWIDTH    => 32,
      pPOLARITY => '1',
      pLENGTH   => 10
      ) port map(
        iCLK           => iCLK,
        iRST           => iRST,
        iEN            => sCalTrigEn,
        oPULSE         => sCalTrig,
        oPULSE_RISING  => open,
        oPULSE_FALLING => open,
        iPERIOD        => iMSD_CONFIG.intTrgPeriod
        );

  --!@brief Delay the trigger before the FE start
  ext_trig_delay : delay_timer
    generic map(
      pWIDTH => 16
    )
    port map(
      iCLK   => iCLK,
      iRST   => iRST,
      iSTART => sTrigMux,
      iDELAY => iMSD_CONFIG.trg2Hold,
      oBUSY  => sTrigDelBusy,
      oOUT   => sTrig
      );

  --!@brief Extend busy from [320 ns, ~20 ms], in multiples of 320 ns
  busy_extend : delay_timer
  generic map(
    pWIDTH => 20
  )
  port map(
    iCLK   => iCLK,
    iRST   => iRST,
    iSTART => sCntOut.compl,
    iDELAY => iMSD_CONFIG.extendBusy & "0000",
    oBUSY  => sExtendBusy,
    oOUT   => open
    );

  --!@brief Low-level multiple ADCs plane interface
  DETECTOR_INTERFACE : multiAdcPlaneInterface
    generic map (
      pACTIVE_EDGE => "F" --!"F": falling, "R": rising
      )
    port map (
      iCLK          => iCLK,
      iRST          => iRST,
      -- control interface
      oCNT          => sCntOut,
      iCNT          => sCntIn,
      iFE_CLK_DIV   => iMSD_CONFIG.feClkDiv,
      iFE_CLK_DUTY  => iMSD_CONFIG.feClkDuty,
      iADC_CLK_DIV  => iMSD_CONFIG.adcClkDiv,
      iADC_CLK_DUTY => iMSD_CONFIG.adcClkDuty,
      iADC_DELAY    => iMSD_CONFIG.adcDelay,
      iCFG_FE       => sHpCfg,
      iADC_FAST     => sAdcFast,
      -- FE interface
      oFE0          => oFE0,
      oFE1          => oFE1,
      iFE           => sFeIn,
      -- ADC interface
      oADC0         => oADC0,
      oADC1         => oADC1,
      iMULTI_ADC    => iMULTI_ADC,
      -- FIFO output interface
      oMULTI_FIFO   => sMultiFifoOut,
      iMULTI_FIFO   => sMultiFifoIn
      );

  --!@brief Collects data from the MSD and assembles them in a single packet
  EVENT_BUILDER : Data_Builder
    port map (
      iCLK          => iCLK,
      iRST          => iRST,
      iMULTI_FIFO   => sMultiFifoOut,
      oMULTI_FIFO   => sMultiFifoIn,
      oCOLL_FIFO    => oCOLL_FIFO,
      oDATA_VALID   => oDATA_VALID,
      oEND_OF_EVENT => oEND_OF_EVENT
      );


end architecture;
