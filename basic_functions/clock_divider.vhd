--!@file clock_divider.vhd
--!@brief Divide the input clock to a slower clock
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@author Hikmat Nasimi, hikmat.nasimi@pi.infn.it
--!@date 10/08/2017
--!@version 1.0 - 10/08/2017 - Reduce logic occupation; Improve timing

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

--!@brief Divide the input clock to a slower clock
--!@details Generate a slower clock by counting iFREQ_DIV/2 cycles; generate
--!also the relative rising and falling edge flags.
entity clock_divider is
    generic(
      pPOLARITY : std_logic := '1'
    );
    port(
        --!Main clock
        iCLK                : in  std_logic;
        --!Reset
        iRST                : in  std_logic;
        --!Enable
        iEN                 : in  std_logic;
        --!Slow clock
        oCLK_OUT            : out std_logic;
        --!Rising edge of the slow clock; synchronous to the edge
        oCLK_OUT_RISING     : out std_logic;
        --!Falling edge of the slow clock; synchronous to the edge
        oCLK_OUT_FALLING    : out std_logic;
        --!Slow clock duration (in number of iCLK cycles)
        iFREQ_DIV           : in  std_logic_vector(15 downto 0)
    );
end clock_divider;

architecture Behavioral of clock_divider is
    signal clk_out              : std_logic := '0';
    signal clk_count            : std_logic_vector(15 downto 0) :=(others => '0');
    signal reset_cnt            : std_logic :='0';
    signal clk_out_rising       : std_logic :='0';
    signal clk_out_falling      : std_logic :='0';
    signal freq_divider_reduced : std_logic_vector(15 downto 0) :=(others => '0');
    signal enable_slv           : std_logic_vector(15 downto 0) :=(others => '0');

begin

    --!@brief Counter that increments at each cycle
    --!@test Summing enable_slv could add combinatorial length to the path
    --! @param[in]  iCLK  Clock, used on rising edge
    freq_down_scale : process (iCLK)
    begin
        if (rising_edge(iCLK)) then
            if(iRST = '1' or reset_cnt = '1') then
                clk_count <= (others => '0');
            else
                clk_count <= clk_count + conv_integer(enable_slv);
                --if(iEN='1') then
                --    clk_count <= clk_count + 1;
                --end if;
            end if;
        end if;
    end process freq_down_scale;

    --!@brief Add FFDs to the combinatorial signals
    --! @param[in]  iCLK  Clock, used on rising edge
    ffds : process (iCLK)
    begin
        if (rising_edge(iCLK)) then
            oCLK_OUT <= clk_out;
            if (pPOLARITY = '1') then
              oCLK_OUT_RISING <= clk_out_rising;
              oCLK_OUT_FALLING <= clk_out_falling;
            else
              oCLK_OUT_RISING <= clk_out_falling;
              oCLK_OUT_FALLING <= clk_out_rising;
            end if;

        end if;
    end process ffds;

    enable_slv(0)           <= iEN;
    enable_slv(15 downto 1) <= (others => '0');

    freq_divider_reduced    <= iFREQ_DIV - '1';
    reset_cnt               <= '1' when (clk_count = freq_divider_reduced) else
                               '0';
    clk_out                 <= pPOLARITY when (clk_count < ('0' & iFREQ_DIV(14 downto 1))) else
                               not pPOLARITY;
    clk_out_rising          <= '1' when (iEN = '1' and (clk_count = freq_divider_reduced )) else
                               '0';
    clk_out_falling         <= '1' when (iEN = '1' and (clk_count = '0'& freq_divider_reduced(14 downto 1))) else
                               '0';

end Behavioral;
