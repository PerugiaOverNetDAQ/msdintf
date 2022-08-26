--!@file countGenerator.vhd
--!@brief Generate a pulse after N occurrences
--!
--!@details Generate a pulse after N occurrences, iLENGTH long;
--!generate also the RISING and FALLING edges
--!
--!@author Mattia Barbanera, mattia.barbanera@infn.it

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;
use work.basic_package.all;

--!@copydoc countGenerator.vhd
entity countGenerator is
  generic(
    --!Counter width
    pWIDTH    : natural := 32;
    --!Polarity of the pulse
    pPOLARITY : std_logic := '1'
  );
  port(
    --!Main clock
    iCLK          : in  std_logic;
    --!Reset
    iRST          : in  std_logic;
    --!Enable
    iCOUNT        : in  std_logic;
    --!Number of occurences to count
    iOCCURRENCES  : in  std_logic_vector(pWIDTH-1 downto 0);
    --!Length of the pulse
    iLENGTH       : in std_logic_vector(pWIDTH-1 downto 0);
    --!Pulse
    oPULSE        : out std_logic;
    --!Output pulse flag (1 clock-cycle long)
    oPULSE_FLAG   : out std_logic
  );
end countGenerator;

--!@copydoc countGenerator.vhd
architecture Behavioral of countGenerator is
  signal sSlvEnable   : std_logic_vector(pWIDTH-1 downto 0):= (others=>'0');
  signal sCounter     : std_logic_vector(pWIDTH-1 downto 0):= (others=>'0');
  signal sPulse       : std_logic:= '0';
  signal sRstCnt      : std_logic:= '0';

  signal sOutShaperCount : unsigned(pWIDTH-1 downto 0) := (others => '0');
  type tOccState is (IDLE, OUT_GEN, WAIT_NEXT);
  signal sOccState : tOccState;

begin

  sSlvEnable(0)           <= iCOUNT;
  sSlvEnable(pWIDTH-1 downto 1) <= (others => '0');
  --!@brief Counter that increments at each iCOUNT
  --!@test Summing sSlvEnable could add combinatorial length to the path
  --!@param[in]  iCLK  Clock, used on rising edge
  count_proc : process (iCLK)
  begin
  if (rising_edge(iCLK)) then
    if(iRST = '1' or sRstCnt = '1') then
      sCounter <= (others => '0');
    else
      sCounter <= sCounter + conv_integer(sSlvEnable);
      --if(iCOUNT='1') then
      --    sCounter <= sCounter + 1;
      --end if;
    end if;
  end if;
  end process count_proc;

  pulse_gen_proc : process (iCLK)
  begin
    if (rising_edge(iCLK)) then
      if (iRST = '1') then
        sOccState <= IDLE;
        sOutShaperCount <= (others => '0');
        sPulse <= not pPOLARITY;
        oPULSE_FLAG <= not pPOLARITY;
      else
        case (sOccState) is
          when IDLE =>
            sOutShaperCount <= (others => '0');
            sPulse <= not pPOLARITY;
            oPULSE_FLAG <= not pPOLARITY;
            if (sRstCnt = '1') then
              oPULSE_FLAG <= pPOLARITY;
              sOccState <= OUT_GEN;
            end if;

          when OUT_GEN =>
            sOutShaperCount <= sOutShaperCount + 1;
            sPulse <= pPOLARITY;
            oPULSE_FLAG <= not pPOLARITY;
            if (sOutShaperCount > unsigned(iLENGTH)-1) then
              sOccState <= WAIT_NEXT;
            end if;

          when WAIT_NEXT =>
            sPulse <= not pPOLARITY;
            oPULSE_FLAG <= not pPOLARITY;
            sOutShaperCount <= (others => '0');
            sOccState <= IDLE;

          when others =>
            sPulse <= not pPOLARITY;
            oPULSE_FLAG <= not pPOLARITY;
            sOutShaperCount <= (others => '0');
            sOccState <= IDLE;

        end case;
      end if; --RST
    end if; --CLK
  end process pulse_gen_proc;

  --pulse_gen_proc : process (iCLK)
  --begin
  --  if (rising_edge(iCLK)) then
  --    if (iRST = '1') then
  --      sOutShaperCount <= (others => '1');
  --    else
  --      if (sRstCnt = '1') then
  --        sOutShaperCount <= (others => '0');
  --        sPulse      <=  pPOLARITY;
  --      elsif (sOutShaperCount < to_unsigned(iLENGTH, pWIDTH)-1) then
  --        sOutShaperCount <= sOutShaperCount + 1;
  --      else
  --        sPulse      <=  not pPOLARITY;
  --      end if;
  --
  --      oPULSE_FLAG <= sRstCnt;
  --    end if;
  --  end if;
  --end process pulse_gen_proc;

  sRstCnt     <=  '1' when (sCounter = iOCCURRENCES) else
                  '0';
  oPULSE <= sPulse;

end Behavioral;
