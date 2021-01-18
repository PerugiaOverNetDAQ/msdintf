--!@file edge_detector.vhd
--!@brief Detect the rising and falling edges of an input signal
--!@author Mattia Barbanera, mattia.barbanera@infn.it
--!@author Hikmat Nasimi, hikmat.nasimi@pi.infn.it
--!@date 10/08/2017
--!@version 1.0 - 10/08/2017 -

library ieee;
use ieee.std_logic_1164.all;

--!@brief Detect the rising and falling edges of an input signal
--!@details Beside the edges, it generates a copy of the original signal
--!delayed of 1 clock cycle
entity edge_detector is
    port(
        iCLK    : in  std_logic;
        iRST    : in  std_logic;
        iD      : in  std_logic;
        oQ      : out std_logic;
        oEDGE_R : out std_logic;
        oEDGE_F : out std_logic
    );
end entity edge_detector;

architecture std of edge_detector is
    signal s_input_delay    : std_logic;
begin

    ffd_proc : process(iCLK, iRST)
    begin
        if (iRST = '1') then
            s_input_delay    <= '0';
        elsif (rising_edge(iCLK)) then
            s_input_delay    <= iD;
        end if;
    end process;

    oQ      <= s_input_delay;
    oEDGE_R <= not(s_input_delay) and iD;
    oEDGE_F <= s_input_delay and not(iD);

end architecture std;
