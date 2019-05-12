-------------------------------------------------------------------------------------------------------------
-- Design unit: R8_uC
-- Description: Instantiation of R8 processor with an I/O Port, meant for synthisys on Nexys 3 board
-- Author: Carlos Gewehr and Emilio Ferreira (cggewehr@gmail.com, emilio.ferreira@ecomp.ufsm.br)
------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
--use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity R8_uC is
    generic (
        ASSEMBLY_FILE : string
    );
	port (
		clk: in std_logic;
		rst: in std_logic;
        port_io: inout std_logic_vector(15 downto 0)
	);
end R8_uC;

architecture behavioral of R8_uC is
   
    signal clk_2                                     : std_logic;                      -- 50 MHz clock from DCM
	 signal reset_sync                                : std_logic;                      -- Synchronized reset
	 signal ce, rw                                    : std_logic;                      -- Auxiliary signals for R8 processor instantiation
	 signal rw_MEM, clk_MEM, en_MEM, en_PORT          : std_logic;                      -- Auxiliary signals for R8 processor instantiation

    signal data_PORT, data_MEM_in, data_mem_out      : std_logic_vector(15 downto 0); 
    signal data_r8_in, data_r8_out, address          : std_logic_vector(15 downto 0);

    alias address_PORT                     : std_logic_vector(1 downto 0) is address(1 downto 0);
    alias mem_address                      : std_logic_vector(14 downto 0)is address(14 downto 0);
    alias ID_PERIFERICO                    : std_logic_vector(3 downto 0) is address(7 downto  4);  -- Perf. ID
    alias REG_PERIFERICO                   : std_logic_vector(3 downto 0) is address(3 downto  0);  -- Perf. Address
    alias ENABLE_PERIFERICO                : std_logic is address(15); 							    -- Perf. Enable (I/O operation to be carried out on peripheral)
	
    -- Tristate for bidirectional bus between processor and i/o port
	signal TRISTATE_TO_EN     : std_logic;
	
	-- Interruption Interface
	signal irq_R8             : std_logic;
	signal irq_PORT           : std_logic_vector(15 downto 0);
   
begin

	-- Xilinx DCM
    ClockManager: entity work.ClockManager
        port map(
            clk_in   => clk,
            clk_div2 => clk_2,
            clk_div4 => open
        );
        
    -- Reset synchronizer    
    ResetSynchronizer: entity work.ResetSynchronizer
        port map(
            clk     => clk_2,
            rst_in  => rst,
            rst_out => reset_sync
        );
		
    -- Processor signals
    data_r8_in <= data_MEM_out when ENABLE_PERIFERICO = '0' else data_PORT;

    -- Peripheral generated interruption
    irq_R8 <= ( irq_PORT(15) or irq_PORT(14) or irq_PORT(13) or irq_PORT(12) or irq_PORT(11) or irq_PORT(10) or irq_PORT(9) or irq_PORT(8) or
                irq_PORT(7) or irq_PORT(6) or irq_PORT(5) or irq_PORT(4) or irq_PORT(3) or irq_PORT(2) or irq_PORT(1) or irq_PORT(0) ); 
    --irq_R8 <= or irq_PORT -- Only works if compiled on VHDL-2008

    -- Processor
    R8Processor: entity work.R8 
		generic map(
			ISR_ADDR => "0000000000000001" -- Address for ISR, always @ second memory position
		)
        port map(
            clk      => clk_2,
            rst      => reset_sync,
			   irq      => irq_R8,
            address  => address,
            data_out => data_r8_out,
            data_in  => data_r8_in,
            ce       => ce,
            rw       => rw                 -- Write : 0, Read : 1
        );
		
    -- Memory signals
    clk_MEM <= not clk_2; -- Makes memory sensitive to falling edge
    rw_MEM  <= not rw;    -- Writes when 0, Reads when 1
    en_MEM  <= '1' when (ce = '1' and ENABLE_PERIFERICO = '0') else '0'; -- address(15)      
    
    -- Memory
    Memory: entity work.Memory 
        generic map(
            DATA_WIDTH => 16,
            ADDR_WIDTH => 15,
            IMAGE => ASSEMBLY_FILE -- Assembly code (must be in same directory)
        )
        port map(
            clk => clk_MEM,
            wr  => rw_MEM,
            en  => en_MEM,
            address  => mem_address, 
            data_in  => data_r8_out,
            data_out => data_MEM_out    
        );
		
    -- Port signals
    en_PORT <= '1' when (ce = '1' and ENABLE_PERIFERICO = '1') else '0';   
        
    -- Tristate between i/o port and processor
	data_PORT <= data_r8_out when TRISTATE_TO_EN = '1' else (others=>'Z');
	TRISTATE_TO_EN <= '1' when rw = '0' else '0';  -- Enables when writes

    -- I/O port 
    IO_Port: entity work.BidirectionalPort
        generic map(
			DATA_WIDTH          => 16, -- Port width in bits
			PORT_DATA_ADDR      => "00",    
			PORT_CONFIG_ADDR    => "01",     
			PORT_ENABLE_ADDR    => "10",
			PORT_IRQ_ADDR       => "11"
        )
        port map(
            clk => clk_2, 
            rst => reset_sync,
				
            -- Processor Interface
            data => data_PORT,
            address => address_PORT,
            rw => rw_MEM,              -- 0: read; 1: write
            ce => en_PORT,
			   irq => irq_PORT,
				
            -- External interface
			   port_io => port_io   
        );

end behavioral;