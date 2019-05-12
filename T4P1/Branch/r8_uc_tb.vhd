library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity r8_uC_tb is
end r8_uC_tb;

architecture behavioral of r8_uC_tb is
    signal clk : std_logic := '0';
    signal rst : std_logic;
    signal port_io : std_logic_vector(15 downto 0);
	 
begin
    R8: entity work.R8_uC_TOPLVL
        port map(
            clk => clk,
            rst => rst
        );

    clk <= not clk after 5 ns; -- 100 MHz
    rst <= '1', '0' after 5 ns;
	 port_io <= "ZZZZZZZZZZZZZZZZ";

    --end process;
end behavioral;
