--!@file Data_Builder.vhd
--!@brief Combine the ADC 16-bit FIFOs into one output 32-bit FIFO
--!@author Keida Kanxheri (keida.kanxheri@pg.infn.it)

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.basic_package.all;
use work.FOOTpackage.all;
use work.DAQ_Package.all;

--!@brief Combine the ADC 16-bit FIFOs into one output 32-bit FIFO
entity Data_Builder is
  port (
    iCLK          : in  std_logic;
    iRST          : in  std_logic;
    iMULTI_FIFO   : in  tMultiAdcFifoOut;
    oMULTI_FIFO   : out tMultiAdcFifoIn;
    oCOLL_FIFO    : out tCollFifoOut;
    oDATA_VALID   : out std_logic;
    oEND_OF_EVENT : out std_logic
    );
end Data_Builder;

architecture std of Data_Builder is

  --Collector FIFO
  signal sCollFifoIn  : tFifoIn_ADC := c_TO_FIFO_INIT;
  signal sCollFifoOut : tCollFifoOut;
  signal sUsedW       : std_logic_vector(ceil_log2(cCOLL_FIFO_DEPTH)-1 downto 0);
  signal sUsedR       : std_logic_vector(ceil_log2(cCOLL_FIFO_DEPTH/2)-1 downto 0);

  --Output interface
  signal sDataValid  : std_logic;
  signal sEndOfEvent : std_logic;

  --
  type tFsmDB is (IDLE, PKT_LENGTH, HEADER_1, HEADER_2, HEADER_3, HEADER_4,
                  WRITE_WORD, OUT_VALID, FOOTER_1, FOOTER_2, FOOTER_3, EVENT_END
                  );
  signal state : tFsmDB;

  signal sDataDetected : std_logic;
  signal sWordCount    : natural range 0 to (cTOTAL_ADCs*2) := 0;

begin

  -- Combinatorial assignments -------------------------------------------------
  oCOLL_FIFO.aEmpty <= sCollFifoOut.aEmpty;
  oCOLL_FIFO.empty  <= sCollFifoOut.empty;
  oCOLL_FIFO.aFull  <= sCollFifoOut.aFull;
  oCOLL_FIFO.full   <= sCollFifoOut.full;

  oDATA_VALID   <= sDataValid;
  oEND_OF_EVENT <= sEndOfEvent;

  --!@test Updated from all or-s; could use only the first FIFO
  sDataDetected <= not(iMULTI_FIFO(0).empty and iMULTI_FIFO(1).empty
                       and iMULTI_FIFO(2).empty and iMULTI_FIFO(3).empty
                       and iMULTI_FIFO(4).empty and iMULTI_FIFO(5).empty
                       and iMULTI_FIFO(6).empty and iMULTI_FIFO(7).empty
                       and iMULTI_FIFO(8).empty and iMULTI_FIFO(9).empty);

  data_det_gen : for i in 0 to cTOTAL_ADCs-1 generate
    oMULTI_FIFO(i).data <= (others => '0');
    oMULTI_FIFO(i).wr   <= '0';
    oMULTI_FIFO(i).rd   <= '1' when sDataDetected = '1' and state = IDLE else
                         '0';
  end generate data_det_gen;
  ------------------------------------------------------------------------------

  sCollFifoOut.aempty <= '1';
  sCollFifoOut.afull  <= '0';
  --- components   -----------------------------------------
  COLL_FIFO : entity work.parametric_fifo_dp
    generic map(
      pDEPTH        => cCOLL_FIFO_DEPTH,
      pWIDTHW       => cADC_DATA_WIDTH,
      pWIDTHR       => cADC_DATA_WIDTH*2,
      pUSEDW_WIDTHW => ceil_log2(cCOLL_FIFO_DEPTH),
      pUSEDW_WIDTHR => ceil_log2(cCOLL_FIFO_DEPTH/2),
      pSHOW_AHEAD   => "OFF"
      )
    port map(
      iCLK_W => iCLK,
      iCLK_R => iCLK,
      iRST   => iRST,

      oEMPTY_W => open,
      oFULL_W  => open,
      oUSEDW_W => sUsedW,
      iWR_REQ  => sCollFifoIn.wr,
      iDATA    => sCollFifoIn.data,

      oEMPTY_R => sCollFifoOut.empty,
      oFULL_R  => sCollFifoOut.full,
      oUSEDW_R => sUsedR,
      iRD_REQ  => sCollFifoIn.rd,
      oQ       => sCollFifoOut.q
      );


  FSM_FIFO_proc : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        sCollFifoIn.wr <= '0';
        sWordCount     <= 0;
        oCOLL_FIFO.q <= int2slv(0, oCOLL_FIFO.q'length);
        sDataValid     <= '0';
        sCollFifoIn.rd <= '0';
        sEndOfEvent    <= '0';
        state          <= IDLE;
      else
        sDataValid       <= '0';
        sEndOfEvent      <= '0';
        sCollFifoIn.wr   <= '0';
        sCollFifoIn.rd   <= '0';
        oCOLL_FIFO.q   <= int2slv(0, oCOLL_FIFO.q'length);
        case (state) is
          when IDLE =>
            sCollFifoIn.data <= iMULTI_FIFO(0).q;
            sWordCount <= 0;
            if (to_integer(unsigned(sUsedW)) > (cTOTAL_ADCs*cFE_CLOCK_CYCLES)-1)then
              state <= PKT_LENGTH;
            else
              if (sDataDetected = '1')then
                state <= WRITE_WORD;
              else
                state <= IDLE;
              end if;
            end if;

          when WRITE_WORD =>
            if (sWordCount < cTOTAL_ADCs) then
              sCollFifoIn.data <= iMULTI_FIFO(sWordCount).q;
              sWordCount     <= sWordCount +1;
              sCollFifoIn.wr <= '1';
              state          <= WRITE_WORD;
            else
              sCollFifoIn.data <= iMULTI_FIFO(0).q;
              sWordCount     <= 0;
              sCollFifoIn.wr <= '0';
              state          <= IDLE;
            end if;

          when PKT_LENGTH =>
            oCOLL_FIFO.q <= int2slv((cTOTAL_ADCs*cFE_CLOCK_CYCLES)/2 +8, oCOLL_FIFO.q'length);
            sDataValid     <= '1';
            state          <= HEADER_1;

          when HEADER_1 =>
            oCOLL_FIFO.q <= std_logic_vector(Header1_ES);
            sDataValid     <= '1';
            state          <= HEADER_2;

          when HEADER_2 =>
            oCOLL_FIFO.q <= std_logic_vector(Header2_ES);
            sDataValid     <= '1';
            state          <= HEADER_3;

          when HEADER_3 =>
            oCOLL_FIFO.q <= std_logic_vector(Header3_ES);
            sDataValid     <= '1';
            state          <= HEADER_4;

          when HEADER_4 =>
            oCOLL_FIFO.q <= std_logic_vector(Header4_ES);
            sDataValid     <= '1';
            sCollFifoIn.rd <= '1';
            state          <= OUT_VALID;

          when OUT_VALID =>
            oCOLL_FIFO.q <= sCollFifoOut.q(15 downto 0) & sCollFifoOut.q(31 downto 16);
            sDataValid     <= '1';
            sCollFifoIn.rd <= '1';
            if(to_integer(unsigned(sUsedR)) > 1)then
              state <= OUT_VALID;
            else
              state <= FOOTER_1;
            end if;

          when FOOTER_1 =>
            oCOLL_FIFO.q <= std_logic_vector(Footer1_ES);
            sDataValid     <= '1';
            state          <= FOOTER_2;

          when FOOTER_2 =>
            oCOLL_FIFO.q <= std_logic_vector(Footer2_ES);
            sDataValid     <= '1';
            state          <= FOOTER_3;

          when FOOTER_3 =>
            oCOLL_FIFO.q <= std_logic_vector(Footer3_ES);
            sDataValid     <= '1';
            state          <= EVENT_END;

          when EVENT_END =>
            oCOLL_FIFO.q <= int2slv(0, oCOLL_FIFO.q'length);
            sEndOfEvent    <= '1';
            state          <= IDLE;

          when others =>
            state <= IDLE;

        end case;
      end if;  --rst
    end if;  --clk
  end process FSM_FIFO_proc;

end std;
