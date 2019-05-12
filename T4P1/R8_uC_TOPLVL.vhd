-------------------------------------------------------------------------------------------------------------
-- Design unit: R8_uC_TOPLVL
-- Description: Instantiation of R8 microcontroller connected to CryptoMessage peripheral
-- Author: Carlos Gewehr and Emilio Ferreira (cggewehr@gmail.com, emilio.ferreira@ecomp.ufsm.br)
------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity R8_uC_TOPLVL is
	port (
		clk: in std_logic; -- 100MHz board clock
		rst: in std_logic  -- Synchronous reset
	);
end R8_uC_TOPLVL;

architecture Behavioural of R8_uC_TOPLVL is

	-- Basic signals
	signal clk_2, clk_4               : std_logic; -- 50MHz clock for uC, 25MHz clock for CryptoMessage
	signal reset_sync                 : std_logic; -- Synchronous reset

	-- Auxiliary signals
	signal TRISTATE_CRYPTO_TO_PORT_EN : std_logic; 
	signal TRISTATE_CRYPTO_TO_PORT    : std_logic_vector(7 downto 0);

	-- Microcontroller signals
	signal port_io_uC                 : std_logic_vector(15 downto 0);

	-- CryptoMessage signals
	signal data_in_crypto             : std_logic_vector(7 downto 0);
	signal data_out_crypto            : std_logic_vector(7 downto 0);
	signal keyEXG_crypto              : std_logic;
	signal data_AV_crypto             : std_logic;
	signal ack_crypto                 : std_logic;
	signal eom_crypto                 : std_logic;

begin

	-- Xilinx DCM
    ClockManager: entity work.ClockManager
        port map(
            clk_in   => clk,
            clk_div2 => clk_2,
            clk_div4 => clk_4
        );
        
    -- Reset synchronizer    
    ResetSynchronizer: entity work.ResetSynchronizer
        port map(
            clk     => clk_2,
            --clk     => clk,
            rst_in  => rst,
            rst_out => reset_sync
        );

    -- R8 Microcontroller (Processor, Memory and I/O Port)
    Microcontroller: entity work.R8_uC
    	generic map (
    		ASSEMBLY_FILE => "AssemblyT4P1_BRAM.txt"
    	)
    	port map (
    		clk     => clk_2,
    		--clk     => clk,
    		rst     => reset_sync,
    		--rst     => rst,
    		port_io => port_io_uC
    	);

    -- CryptoMessage peripheral
    CryptoMessage: entity work.CryptoMessage
        generic map(
            MSG_INTERVAL => 2000, -- Waits 2000 clocks before sending next msg
            FILE_NAME  => "empire.txt"
        )
    	port map(
    		clk         => clk_4,
    		--clk         => clk,
    		rst         => reset_sync,
    		--rst         => rst,
    		data_in     => data_in_crypto,
    		data_out    => data_out_crypto,
    		keyExchange => keyEXG_crypto,
    		data_AV     => data_AV_crypto,
    		ack         => ack_crypto,
    		eom         => eom_crypto
    	);

    data_in_crypto <= port_io_uC(15 downto 8);
   	port_io_uC(3) <= data_AV_crypto;
   	port_io_uC(2) <= keyEXG_crypto;
   	ack_crypto <= port_io_uC(1);
   	port_io_uC(0) <= eom_crypto;

    TRISTATE_CRYPTO_TO_PORT <= data_out_crypto;
    TRISTATE_CRYPTO_TO_PORT_EN <= port_io_uC(7);

    port_io_uC(15 downto 8) <= TRISTATE_CRYPTO_TO_PORT when TRISTATE_CRYPTO_TO_PORT_EN = '1' else (others=>'Z');
	
end architecture Behavioural;
