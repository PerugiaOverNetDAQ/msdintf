--!@file HalfPlane_ClockManager.vhd
--!@brief Generate the slow clock and enable for the FE and the ADC
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@date 06/04/2020
--!@version 0.1 - 06/04/2020 - No error in analysis with GHDL

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.basic_package.all;
use work.FOOTpackage.all;

--!@brief Generate the slow clock and enable for the FE and the ADC
--!@details Free running clocks; the ADC one is delayed by the pADC2FE_CLK_DELAY number of cycles
entity HalfPlane_ClockManager is
  generic (
    pACTIVE_EDGE      : string  := "F";  --!"F": falling, "R": rising
    pADC2FE_CLK_DELAY : natural := 1  --!Delay between the FE and the ADC clocks
    );
  port (
    iCLK         : in  std_logic;       --!Main clock
    iRST         : in  std_logic;       --!Main reset
    -- control interface
    iEN          : in  std_logic;       --!Main enable
    iFE_CLK_DIV  : in  std_logic_vector(15 downto 0);  --!FE SlowClock divider
    iADC_CLK_DIV : in  std_logic_vector(15 downto 0);  --!ADC SlowClock divider
    -- Clk Outputs
    oFE_SLWCLK   : out std_logic;       --!FE Slow Clock
    oFE_SLWEN    : out std_logic;       --!FE Slow Enable
    oADC_SLWCLK  : out std_logic;       --!ADC Slow Clock
    oADC_SLWEN   : out std_logic        --!ADC Slow Enable
    );
end HalfPlane_ClockManager;

architecture std of HalfPlane_ClockManager is
  constant cCOUNTER_WIDTH : natural := 16;

  signal sCounterEn    : std_logic;
  signal sCounterRst   : std_logic;
  signal sCounterCount : std_logic_vector(cCOUNTER_WIDTH-1 downto 0);
  signal sEnREdge       : std_logic;
  signal sEnFEdge      : std_logic;

  signal sFeRising, sFeFalling   : std_logic;
  signal sFeEn                   : std_logic;
  signal sAdcEn                  : std_logic;
  signal sAdcRising, sAdcFalling : std_logic;
  signal sAdcEnOne, sAdcEnMulti  : std_logic;

begin

  en_edge : edge_detector
    port map (
      iCLK    => iCLK,
      iRST    => iRST,
      iD      => iEN,
      oQ      => sAdcEnOne,
      oEDGE_R => sEnREdge,
      oEDGE_F => sEnFEdge
      );

  --Immediately enable the FE clock divider, while apply a delay to the ADC clock divider
  sFeEn  <= iEN;
  sAdcEn <= iEN when (pADC2FE_CLK_DELAY = 0) else
            sAdcEnOne when (pADC2FE_CLK_DELAY = 1) else
            sAdcEnMulti;

  --Count when iEN='1'and the threshold is not reached
  --Reset when iEN has a falling edge
  delay_counter : counter
    generic map (
      pOVERLAP  => "Y",
      pBUSWIDTH => cCOUNTER_WIDTH
      )
    port map (
      iCLK   => iCLK,
      iEN    => sCounterEn,
      iRST   => sCounterRst,
      iLOAD  => '0',
      iDATA  => (others => '0'),
      oCOUNT => sCounterCount,
      oCARRY => open
      );

  --!@brief Enable the ADC divider after the FE divider (by pADC2FE_CLK_DELAY clks)
  --! @param[in] iCLK  Clock, used on rising edge
  DelayMngr_proc : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        sCounterEn  <= '0';
        sCounterRst <= '1';
        sAdcEnMulti <= '0';
      else
        --Count when the threshold is not reached
        sCounterEn  <= iEN and not sAdcEnMulti;
        --Reset when iEN has a falling edge
        sCounterRst <= sEnFEdge;

        --Enable the ADC divider when the counter reaches the threshold
        if (sCounterCount < pADC2FE_CLK_DELAY) then
          sAdcEnMulti <= '0';
        else
          sAdcEnMulti <= '1';
        end if;
      end if;  --iRST
    end if;  --rising_edge
  end process DelayMngr_proc;

  --!@brief Clock divider for the FE
  FE_div : clock_divider
    port map (
      iCLK             => iCLK,
      iRST             => iRST,
      iEN              => sFeEn,
      iFREQ_DIV        => iFE_CLK_DIV,
      oCLK_OUT         => oFE_SLWCLK,
      oCLK_OUT_RISING  => sFeRising,
      oCLK_OUT_FALLING => sFeFalling
      );

  --!@brief Clock divider for the ADC
  ADC_div : clock_divider
    port map (
      iCLK             => iCLK,
      iRST             => iRST,
      iEN              => sAdcEn,
      iFREQ_DIV        => iADC_CLK_DIV,
      oCLK_OUT         => oADC_SLWCLK,
      oCLK_OUT_RISING  => sAdcRising,
      oCLK_OUT_FALLING => sAdcFalling
      );

  -- Selectors for Falling or Rising active edge of the clock
  oFE_SLWEN <= sFeFalling when (pACTIVE_EDGE = "F") else
               sFeRising;
  oADC_SLWEN <= sAdcFalling when (pACTIVE_EDGE = "F") else
                sAdcRising;

end architecture std;
