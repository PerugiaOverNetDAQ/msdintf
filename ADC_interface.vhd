--!@file ADC_interface.vhd
--!@brief Low-level interface of the uStrip ADC (possibly, AD7276)
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@date 13/02/2020
--!@version 0.2 - 10/06/2020 - SV testbench


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.basic_package.all;
use work.FOOTpackage.all;

--!@brief Low-level interface of the uStrip ADC (possibly, AD7276)
--!@details Serial interface with the 12-bit ADC.
--!See the ADC datasheet for additional details
entity ADC_interface is
  port (
    iCLK  : in  std_logic;              --!Main clock
    iRST  : in  std_logic;              --!Main reset
    -- control interface
    oCNT  : out tControlIntfOut;        --!Control signals in output
    iCNT  : in  tControlIntfIn;         --!Control signals in input
    -- ADC interface
    oADC  : out tFpga2AdcIntf;          --!Signals from the FPGA to the ADC
    iADC  : in  tAdc2FpgaIntf;          --!Signals from the ADC to the FPGA
    -- Word in output
    oFIFO : out tFifoIn_ADC             --!Output data and write request
    );
end ADC_interface;

architecture std of ADC_interface is
  constant cCOUNT_INTERFACE : natural := 8;

  signal sCntIn    : tControlIntfIn;
  signal sCntOut   : tControlIntfOut;
  signal sFpga2Adc : tFpga2AdcIntf;
  signal sAdc2Fpga : tAdc2FpgaIntf;
  signal sOutWord  : tFifoIn_ADC;

  type tFsmAdc is (RESET, IDLE, ASSERT_CS, SAMPLE, WRITE_WORD);
  signal sAdcState, sNextAdcState : tFsmAdc;

  --!@brief Wait for the enable assertion to change state
  --!@param[in] en  If '1', go to destination state
  --!@param[in] src Source state; remain here until enable is asserted
  --!@param[in] dst Destination state; go here when enable is asserted
  --!@return FSM next state depending on the enable assertion
  function wait4en (en : std_logic; src : tFsmAdc; dst : tFsmAdc)
    return tFsmAdc is
    variable goto : tFsmAdc;
  begin
    if (en = '1') then
      goto := dst;
    else
      goto := src;
    end if;
    return goto;
  end function wait4en;

  type tCountInterface is record
    preset : std_logic_vector(cCOUNT_INTERFACE-1 downto 0);
    count  : std_logic_vector(cCOUNT_INTERFACE-1 downto 0);
    en     : std_logic;
    load   : std_logic;
    carry  : std_logic;
  end record tCountInterface;
  signal sCountRst  : std_logic := '0';
  signal sCountIntf : tCountInterface;

  type tShiftRegInterface is record
    en     : std_logic;
    load   : std_logic;
    serIn  : std_logic;
    parIn  : std_logic_vector(cADC_DATA_WIDTH-1 downto 0);
    serOut : std_logic;
    parOut : std_logic_vector(cADC_DATA_WIDTH-1 downto 0);
  end record tShiftRegInterface;
  signal sSrRst : std_logic;
  signal sSr    : tShiftRegInterface;

begin
  -- Combinatorial assignments -------------------------------------------------
  oCNT   <= sCntOut;
  sCntIn <= iCNT;

  oADC.SClk <= sFpga2Adc.SClk;
  oADC.Cs   <= not sFpga2Adc.Cs;

  sAdc2Fpga <= iADC;

  oFIFO         <= sOutWord;
  sOutWord.data <= sSr.parOut;
  sOutWord.wr   <= '1' when (sAdcState = WRITE_WORD) else
                 '0';
  sOutWord.rd <= '0';

  ------------------------------------------------------------------------------

  --! @brief Output signals in a synchronous fashion, without reset
  --! @param[in] iCLK Clock, used on rising edge
  ADC_synch_signals_proc : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (sAdcState = SAMPLE) then
        sFpga2Adc.SClk <= sCntIn.slwClk;
      else
        sFpga2Adc.SClk <= '1';
      end if;

      if (sAdcState = ASSERT_CS or sAdcState = SAMPLE) then
        sFpga2Adc.Cs <= '1';
      else
        sFpga2Adc.Cs <= '0';
      end if;

      if (sNextAdcState /= IDLE) then
        sCntOut.busy <= '1';
      else
        sCntOut.busy <= '0';
      end if;

      if (sNextAdcState = RESET) then
        sCntOut.reset <= '1';
      else
        sCntOut.reset <= '0';
      end if;

      --!@todo How do I check the "when others" statement?
      sCntOut.error <= '0';

      --!@todo The compl flag can be anticipated to the 13th cycle of the ADC /
      --!to save some conversione time
      --since the ADC releases its input at that moment
      if (sNextAdcState = WRITE_WORD) then
        sCntOut.compl <= '1';
      else
        sCntOut.compl <= '0';
      end if;

      if (sAdcState = SAMPLE or sAdcState = ASSERT_CS) then
        sSr.en <= sCntIn.slwEn;
      else
        sSr.en <= '0';
      end if;

    end if;
  end process ADC_synch_signals_proc;

  sCountRst <= '1' when (sAdcState /= SAMPLE) else
               '0';
  sCountIntf.en <= sCntIn.slwEn when (sAdcState = SAMPLE) else
                   '0';
  sCountIntf.load   <= '0';
  sCountIntf.preset <= (others => '0');
  --!@brief Multi-purpose counter to implement delays in the FSM
  delay_timer : counter
    generic map(
      pOVERLAP  => "Y",
      pBUSWIDTH => cCOUNT_INTERFACE
      )
    port map(
      iCLK   => iCLK,
      iRST   => sCountRst,
      iEN    => sCountIntf.en,
      iLOAD  => sCountIntf.load,
      iDATA  => sCountIntf.preset,
      oCOUNT => sCountIntf.count,
      oCARRY => sCountIntf.carry
      );

  sSrRst <= '1' when (sAdcState = RESET or sAdcState = IDLE) else
            '0';
  sSr.serIn <= sAdc2Fpga.SData;
  sSr.load  <= '0';
  sSr.parIn <= (others => '0');
  --! @brief Shift register to sample and deserialize the ADC output
  sampler : shift_register
    generic map(
      pWIDTH => cADC_DATA_WIDTH,
      pDIR   => "LEFT"                  --"RIGHT"
      )
    port map(
      iCLK      => iCLK,
      iRST      => sSrRst,
      iEN       => sSr.en,
      iLOAD     => sSr.load,
      iSHIFT    => sSr.serIn,
      iDATA     => sSr.parIn,
      oSER_DATA => sSr.serOut,
      oPAR_DATA => sSr.parOut
      );

  --! @brief Add FFDs to the combinatorial signals \n
  --! @param[in] iCLK  Clock, used on rising edge
  ffds : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        sAdcState <= RESET;
      else
        sAdcState <= sNextAdcState;
      end if;  --iRST
    end if;  --rising_edge
  end process ffds;

  --! @brief Combinatorial FSM to operate the ADC
  --! @param[in] sAdcState Current state of the FSM
  --! @param[in] sCntIn Input signals of the control interface
  --! @param[in] sCountIntf.count Output of the delay counter
  --! @return sNextAdcState  Next state of the FSM
  --! @vhdlflow
  FSM_ADC_proc : process (sAdcState, sCntIn, sCountIntf.count)
  begin
    case (sAdcState) is
      --Reset the FSM
      when RESET =>
        sNextAdcState <= wait4en(sCntIn.slwEn, RESET, IDLE);

      --Wait for the start signal to be asserted
      when IDLE =>
        if (sCntIn.en = '1' and sCntIn.start = '1') then
          sNextAdcState <= ASSERT_CS;
        else
          sNextAdcState <= IDLE;
        end if;

      --Assert the CS line
      when ASSERT_CS =>
        sNextAdcState <= wait4en(sCntIn.slwEn, ASSERT_CS, SAMPLE);

      --Sample the incoming 16 bits
      when SAMPLE =>
        if (sCountIntf.count <
            int2slv((cADC_DATA_WIDTH-1), sCountIntf.count'length)) then
          sNextAdcState <= SAMPLE;
        else
          sNextAdcState <= WRITE_WORD;
        end if;

      --Write the deserialized word in output
      when WRITE_WORD =>
        sNextAdcState <= IDLE;

      --State not foreseen
      when others =>
        sNextAdcState <= RESET;

    end case;
  end process FSM_ADC_proc;


end architecture std;
