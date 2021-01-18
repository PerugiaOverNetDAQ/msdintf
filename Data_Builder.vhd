--!@file Data_Builder.vhd
--!@brief Combine the ADC 16-bit FIFOs into one output 32-bit FIFO
--!@author Keida Kanxheri (keida.kanxheri@pg.infn.it)

library IEEE;
use IEEE.std_logic_1164.all;
--use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

--use work.SERIALIZE_PKG.all;
use work.basic_package.all;
use work.FOOtpackage.all;  --file which contain constant and logic values for all the project

--!@brief Combine the ADC 16-bit FIFOs into one output 32-bit FIFO
entity Data_Builder is
  port (
    iCLK         : in  std_logic;
    iRST         : in  std_logic;
    iMULTI_FIFO  : in  tMultiAdcFifoOut;
	 oMULTI_FIFO  : out tMultiAdcFifoIn;
    oDATA        : out tAllFifoOut_ADC;
    DATA_VALID   : out std_logic;
    END_OF_EVENT : out std_logic
    );
end Data_Builder;

architecture std of Data_Builder is

  signal sFifoIn        : tFifoOut_ADC;
  signal sFifoIn_o      : tMultiAdcFifoOut;
  signal rd_valid_1     : std_logic_vector (cTOTAL_ADCS-1 downto 0)     := (others => '0');
  signal rd_valid_2     : std_logic_vector (cTOTAL_ADCS-1 downto 0)     := (others => '0');
  signal rd_valid       : std_logic_vector ((2*cTOTAL_ADCS)-1 downto 0) := (others => '0');
  signal data_long      : std_logic_vector (cADC_DATA_WIDTH-1 downto 0) := (others => '0');
  signal sFifoOut       : tAllFifoOut_ADC;
  signal s_wr           : std_logic;
  signal s_rd           : std_logic;
  signal s_DATA_VALID   : std_logic;
  signal sCLK           : std_logic;
  signal sRST           : std_logic;
  signal s_end_of_event : std_logic;
  signal data_detected : std_logic;
  signal s_used_w       : std_logic_vector(ceil_log2(cADC_FIFO_DEPTH)-1 downto 0);
  signal s_used_r       : std_logic_vector(ceil_log2((cADC_FIFO_DEPTH*cADC_DATA_WIDTH)/(cADC_DATA_WIDTH*2))-1 downto 0);



  subtype index0 is natural range 0 to cTOTAL_ADCs;
  subtype index1 is natural range 0 to (cTOTAL_ADCs*2);
  subtype index2 is natural range 0 to (2*cFE_CLOCK_CYCLES*cTOTAL_ADCs);
  subtype index3 is natural range 0 to (2*cFE_CLOCK_CYCLES*cTOTAL_ADCs*2);



  type tFsmDB is (RESET, IDLE, WRITE_WORD, WRITING_FINISHED, OUT_VALID, EVENT_END
                  );
  signal state, nextstate : tFsmDB;

  signal count : index1 := 0;

  constant all_ones : std_logic_vector((2*cTOTAL_ADCs)-1 downto 0) := (others => '1');

begin

  -- Combinatorial assignments -------------------------------------------------
  sFifoIn_o    <= iMULTI_FIFO;
  oDATA        <= sFifoOut;
  DATA_VALID   <= s_DATA_VALID;
  END_OF_EVENT <= s_end_of_event;
  sCLK         <= iCLK;
  sRST         <= iRST;
  data_detected <= not(sFifoIn_o(0).empty or sFifoIn_o(1).empty or sFifoIn_o(2).empty or sFifoIn_o(3).empty 
  or sFifoIn_o(4).empty or sFifoIn_o(5).empty or sFifoIn_o(6).empty or sFifoIn_o(7).empty 
  or sFifoIn_o(8).empty or sFifoIn_o(9).empty);
  
  data_det_gen:
  
  for i in 0 to cTOTAL_ADCs-1 generate
  
  
  oMULTI_FIFO(i).rd <= '1'when data_detected = '1' and state = IDLE else
                     '0';
  end generate data_det_gen;
  ------------------------------------------------------------------------------





  ---components   -----------------------------------------
  ADC_FIFO : entity work.parametric_fifo_dp
    generic map(
      pDEPTH        => cADC_FIFO_DEPTH,
      pWIDTHW       => cADC_DATA_WIDTH,
      pWIDTHR       => cADC_DATA_WIDTH*2,
      pUSEDW_WIDTHW => ceil_log2(cADC_FIFO_DEPTH),
      pUSEDW_WIDTHR => ceil_log2((cADC_FIFO_DEPTH*cADC_DATA_WIDTH)/(cADC_DATA_WIDTH*2)),
      pSHOW_AHEAD   => "OFF"
      )
    port map(
      iCLK_W => sCLK,
      iCLK_R => sCLK,
      iRST   => sRST,

      oEMPTY_W => sFifoIn.empty,
      oFULL_W  => sFifoIn.full,
      oUSEDW_W => s_used_w,
      iWR_REQ  => s_wr,
      iDATA    => data_long,

      oEMPTY_R => sFifoOut.empty,
      oFULL_R  => sFifoOut.full,
      oUSEDW_R => s_used_r,
      iRD_REQ  => s_rd,
      oQ       => sFifoOut.q
      );


  -- Handles writes to the FIFO
  fsm : process (sCLK)
  begin
    if (rising_edge(sCLK)) then
      if (iRST = '1') then
        state <= RESET;
      else
        state <= nextstate;
      end if;  --iRST
    end if;  --rising_edge
  end process fsm;

  FSM_FIFO_proc : process (state, s_used_w, s_used_r)
  begin
    case (state) is
      --Reset the FSM
      when RESET =>
        nextstate <= IDLE;

      when IDLE =>
        if (data_detected = '1')then
        nextstate <= WRITE_WORD;
        else
        nextstate <= IDLE;
        end if;

      when WRITE_WORD =>
        if(to_integer(unsigned(s_used_w)) < (2*cTOTAL_ADCs*cFE_CHANNELS))then
		    if (count < cTOTAL_ADCs-1) then
          nextstate <= WRITE_WORD;
			 else
			 nextstate <= IDLE;
			 end if;
        else
          nextstate <= OUT_VALID;
        end if;

      when OUT_VALID =>
        if(to_integer(unsigned(s_used_r)) > 1)then
          nextstate <= OUT_VALID;
        else
          nextstate <= EVENT_END;
        end if;

      when EVENT_END =>
        nextstate <= IDLE;

      when others =>
        nextstate <= RESET;

    end case;
  end process FSM_FIFO_proc;


  FIFOs_signal_process : process (sCLK)
  --variable count : integer range 0 to cTOTAL_ADCs-1 := 0;
  begin
    if (rising_edge(sCLK)) then

      if (state = WRITE_WORD) then
        s_wr <= '1';
          data_long <= sFifoIn_o(count).q;
          count     <= count +1;
      else
        s_wr <= '0';
		  count <= 0;
      end if;

      if(state = OUT_VALID) then
        s_rd         <= '1';
        s_DATA_VALID <= '1';
      else
        s_rd         <= '0';
        s_DATA_VALID <= '0';
      end if;

      if (state = EVENT_END) then
        s_end_of_event <= '1';
      else
        s_end_of_event <= '0';
      end if;
    end if;
  end process;


end std;
