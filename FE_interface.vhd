--!@file FE_interface.vhd
--!@brief Low-level interface of the uStrip FrontEnd IDE1140_DS
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@date 28/01/2020
--!@version 0.3 - 10/06/2020 - SV testbench

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.basic_package.all;
use work.FOOTpackage.all;

--!@brief Low-level interface of the uStrip FrontEnd IDE1140_DS
--!@details See the FE datasheet for additional details on the interface
--!@todo The deassertion of enable input shall stop the FSM
entity FE_interface is
  port (
    iCLK      : in  std_logic;          --!Main clock
    iRST      : in  std_logic;          --!Main reset
    -- control interface
    oCNT      : out tControlIntfOut;    --!Control signals in output
    iCNT      : in  tControlIntfIn;     --!Control signals in input
    iCNT_G    : in  std_logic_vector(2 downto 0);  --!Values for FE G* parameters
    iCNT_Test : in  std_logic;          --!Flag to activate the FE test-mode
    -- FE interface
    oFE       : out tFpga2FeIntf;       --!Signals from the FPGA to the FE
    iFE       : in  tFe2FpgaIntf        --!Signals from the FE to the FPGA
    );
end FE_interface;

architecture std of FE_interface is
  constant cCOUNT_INTERFACE : natural := 16;

  signal sCntIn   : tControlIntfIn;
  signal sCntOut  : tControlIntfOut;
  signal sFpga2Fe : tFpga2FeIntf;
  signal sFe2Fpga : tFe2FpgaIntf;

  type tFsmFe is (RESET, IDLE, SYNCH_START, HOLD, SHIFT,
                  CLOCK_FORWARD, SYNCH_END, COMPLETE
                  );
  signal sFeState, sNextFeState : tFsmFe;

  --!@brief Wait for the enable assertion to change state
  --!@param[in] en  If '1', go to destination state
  --!@param[in] src Source state; remain here until enable is asserted
  --!@param[in] dst Destination state; go here when enable is asserted
  --!@return FSM next state depending on the enable assertion
  function wait4en (en : std_logic; src : tFsmFe; dst : tFsmFe) return tFsmFe is
    variable goto : tFsmFe;
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
  signal sCountRst  : std_logic;
  signal sCountIntf : tCountInterface;

begin
  -- Combinatorial assignments -------------------------------------------------
  oCNT   <= sCntOut;
  sCntIn <= iCNT;

  oFE.G0      <= sFpga2Fe.G0;
  oFE.G1      <= sFpga2Fe.G1;
  oFE.G2      <= sFpga2Fe.G2;
  oFE.Hold    <= not sFpga2Fe.Hold;
  oFE.DRst    <= sFpga2Fe.DRst;
  oFE.ShiftIn <= not sFpga2Fe.ShiftIn;
  oFE.Clk     <= sFpga2Fe.Clk;
  oFE.TestOn  <= sFpga2Fe.TestOn;

  sFe2Fpga <= iFE;

  sFpga2Fe.G0 <= iCNT_G(0);
  sFpga2Fe.G1 <= iCNT_G(1);
  sFpga2Fe.G2 <= iCNT_G(2);
  ------------------------------------------------------------------------------

  --! @brief Output signals in a synchronous fashion, without reset
  --! @param[in] iCLK Clock, used on rising edge
  FE_synch_signals_proc : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      sFpga2Fe.TestOn <= iCNT_Test;

      --!@bug not clear if the hold has to be hold or is just a pulse
      if (sFeState = HOLD or sFeState = SHIFT or sFeState = CLOCK_FORWARD
            or sFeState = SYNCH_END) then
        sFpga2Fe.Hold <= '1';
      else
        sFpga2Fe.Hold <= '0';
      end if;

      if (sFeState = RESET) then
        sFpga2Fe.DRst <= '1';
      else
        sFpga2Fe.DRst <= '0';
      end if;

      if (sFeState = SHIFT) then
        sFpga2Fe.ShiftIn <= '1';
      else
        sFpga2Fe.ShiftIn <= '0';
      end if;

      if (sFeState = SHIFT or sFeState = CLOCK_FORWARD
            or sFeState = SYNCH_END) then
        sFpga2Fe.Clk <= sCntIn.slwClk;
      else
        sFpga2Fe.Clk <= '1';
      end if;

      if (sNextFeState /= IDLE) then
        sCntOut.busy <= '1';
      else
        sCntOut.busy <= '0';
      end if;

      if (sNextFeState = RESET) then
        sCntOut.reset <= '1';
      else
        sCntOut.reset <= '0';
      end if;

      --!@todo How do I check the "when others" statement?
      sCntOut.error <= '0';

      if (sNextFeState = COMPLETE) then
        sCntOut.compl <= '1';
      else
        sCntOut.compl <= '0';
      end if;

    end if;
  end process FE_synch_signals_proc;

  sCountRst <= '1' when (sFeState = RESET or sFeState = IDLE) else
               '0';
  sCountIntf.en <= sCntIn.slwEn when (sFeState = HOLD or sFeState = SHIFT
                                        or sFeState = CLOCK_FORWARD) else
                   '0';
  sCountIntf.load   <= '0';
  sCountIntf.preset <= (others => '0');
  --! @brief Multi-purpose counter to implement delays in the FSM
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

  --! @brief Add FFDs to the combinatorial signals \n
  --! @param[in] iCLK  Clock, used on rising edge
  ffds : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        sFeState <= RESET;
      else
        sFeState <= sNextFeState;
      end if;  --iRST
    end if;  --rising_edge
  end process ffds;

  --! @brief Combinatorial FSM to operate the FEs
  --! @param[in] sFeState  Current state of the FSM
  --! @param[in] sCntIn Input signals of the control interface
  --! @param[in] sCountIntf.count Output of the delay counter
  --! @return sNextFeState  Next state of the FSM
  --! @todo Add a control of the shift_out_b from the last FE;
  --! @todo Sensitivity list can be substituted by 'all' (VHDL-2008)
  --! @vhdlflow
  FSM_FE_proc : process (sFeState, sCntIn, sCountIntf.count)
  begin
    case (sFeState) is
      --Reset the FSM
      when RESET =>
        sNextFeState <= wait4en(sCntIn.slwEn, RESET, IDLE);

        --Wait for the START signal to be asserted
      when IDLE =>
        if (sCntIn.en = '1' and sCntIn.start = '1') then
          sNextFeState <= SYNCH_START;
        else
          sNextFeState <= IDLE;
        end if;

        --Wait for the slow clock enable before starting
      when SYNCH_START =>
        sNextFeState <= wait4en(sCntIn.slwEn, SYNCH_START, HOLD);

        --Assert the HOLD signal
      when HOLD =>
        sNextFeState <= wait4en(sCntIn.slwEn, HOLD, SHIFT);

        --Assert the SHIFT signal
      when SHIFT =>
        sNextFeState <= wait4en(sCntIn.slwEn, SHIFT, CLOCK_FORWARD);

        --Send the clock to the FE(s)
      when CLOCK_FORWARD =>
        if (sCountIntf.count <
            int2slv(cFE_CLOCK_CYCLES, sCountIntf.count'length)) then
          sNextFeState <= CLOCK_FORWARD;
        else
          sNextFeState <= SYNCH_END;
        end if;

        --Wait for the slow clock enable before ending the readout
      when SYNCH_END =>
        sNextFeState <= wait4en(sCntIn.slwEn, SYNCH_END, COMPLETE);

      when COMPLETE =>
        sNextFeState <= IDLE;

        --State not foreseen
      when others =>
        sNextFeState <= RESET;

    end case;
  end process FSM_FE_proc;


end architecture std;
