-------------------------------------------------------------------------------------------
-- Processador R8 - 2019/1
-- ELC1094 - Projeto de Processadores - Prof. Carara
-- Carlos Gewehr e Emilio Ferreia
-- Verso Atual: 0.2
-------------------------------------------------------------------------------------------
-- Changelog:
-- Carlos - v0.1: Adicionada descrio comportamental do processador R8 
-- Emilio - v0.12: Reajustes de estruturas e processos
-- Emilio - v0.13: Criação da ula separada dos estados
-- Carlos - v0.2: Adicionadas instruçoes PUSHF, POPF e RTI, e suporte para interrupções
-------------------------------------------------------------------------------------------	   

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
--use work.R8_pkg.all;

entity R8 is
	generic (
		-- Hardwired address for ISR
        ISR_ADDR : std_logic_vector(15 downto 0)
	);
    port( 
		-- 50 MHz clock from DCM
        clk      : in std_logic;
		
		-- From reset synchronizer
        rst      : in std_logic;
		
		-- Flag de interrupção por periferico
        irq      : in std_logic;
        
        -- Memory interface
        data_in  : in std_logic_vector(15 downto 0);
        data_out : out std_logic_vector(15 downto 0);
        address  : out std_logic_vector(15 downto 0);
        ce       : out std_logic;
        rw       : out std_logic 
    );
end R8;	 

architecture Behavioural of R8 is

	type State is (Sfetch, Sreg, Shalt, Sula, Swbk, Sld, Sst, Sjmp, Ssbrt, Spush, Srts, Spop, Sldsp, Spushf, Spopf, Srti, Sitr, Smul, Sdiv, Smfh, Smfl);
	type R8Instruction is (
        ADD, SUB, AAND, OOR, XXOR, ADDI, SUBI, NOT_A, 
        SL0, SL1, SR0, SR1,
        LDL, LDH, LD, ST, LDSP, POP, PUSH,
        JUMP_R, JUMP_A, JUMP_D, JSRR, JSR, JSRD,
        NOP, HALT,  RTS, 
		-- Novas instruções T3P2
		  PUSHF, POPF, RTI,
		-- Novas instruções T4P1
		  MUL, DIV, MFH, MFL
    ); 

	type RegisterArray is array (natural range <>) of std_logic_vector(15 downto 0); 
   type instrucionType is (tipo1, tipo2, outras);
	
	signal currentInstruction          : R8Instruction;
	signal currentState                : State;
	signal instType                    : instrucionType;                -- Instrução tipo 1, tipo 2 ou outra (instruçoes sem writeback no banco de registradores)
	
	-- Registradores do Processador
	signal regBank                     : RegisterArray(0 to 15);        -- Banco de registradores	 
    signal regPC                       : std_logic_vector(15 downto 0); -- Program Counter
    signal regIR                       : std_logic_vector(15 downto 0); -- Registrador de Instruçoes
    signal regSP                       : std_logic_vector(15 downto 0); -- Stack Pointer
    signal regA                        : std_logic_vector(15 downto 0); -- Primeiro reg lido do REGBANK
	signal regB                        : std_logic_vector(15 downto 0); -- Segundo reg lido do REGBANK
	signal regALU                      : std_logic_vector(15 downto 0); -- Registrador ALU
	signal regHIGH                     : std_logic_vector(15 downto 0); -- Registrador HIGH para MUL/DIV
	signal regLOW                      : std_logic_vector(15 downto 0); -- Registrador LOW para MUL/DIV

	-- Sinais combinacionais pra ALU
    signal ALUaux                      : std_logic_vector(16 downto 0); -- Sinal com 17 bits pra lidar com overflow 
    signal outALU                      : std_logic_vector(15 downto 0);  
    signal multiplicador               : std_logic_vector(31 downto 0);
    signal divisor                     : std_logic_vector(31 downto 0);
    
	-- Registrador de Flags
    signal regFLAGS : std_logic_vector(3 downto 0);
    alias n :std_logic is regFLAGS(3);
    alias z :std_logic is regFLAGS(2);
    alias c :std_logic is regFLAGS(1);
    alias v :std_logic is regFLAGS(0);
	
    -- Sinais auxiliares para geração de flags, atualizados combinacionalmente na ALU
    signal flagN, flagZ, flagC, flagV  : std_logic; -- Flags ALU| negativo, zero, carry, OVFLW
    
	-- Campos do registrador de instrução
	alias OPCODE      : std_logic_vector( 3 downto 0) is regIR(15 downto 12);
	alias REGTARGET   : std_logic_vector( 3 downto 0) is regIR(11 downto  8);
	alias REGSOURCE1  : std_logic_vector( 3 downto 0) is regIR( 7 downto  4);
	alias REGSOURCE2  : std_logic_vector( 3 downto 0) is regIR( 3 downto  0);
	alias CONSTANTE	: std_logic_vector( 7 downto 0) is regIR( 7 downto  0);
	alias JMPD_AUX    : std_logic_vector( 1 downto 0) is regIR(11 downto 10);
	alias JMPD_DESLOC : std_logic_vector( 9 downto 0) is regIR( 9 downto  0);
	alias JSRD_DESLOC : std_logic_vector(11 downto 0) is regIR(11 downto  0);
	
	signal interruptFlag : std_logic; -- Signals if processor is currently treating an interruption
	
begin
	-- Decodifica instruçoes
    -- Decodifica o tipo das instruçoes
    instType <= tipo1 when currentInstruction = ADD  or 
                           currentInstruction = SUB  or
                           currentInstruction = AAND or
                           currentInstruction = OOR  or
                           currentInstruction = XXOR or
                           currentInstruction = SL0  or
                           currentInstruction = SL1  or
                           currentInstruction = SR0  or
                           currentInstruction = SR1  or 
                           currentInstruction = NOT_A else
        
                tipo2 when currentInstruction = ADDI or
                           currentInstruction = SUBI or
                           currentInstruction = LDL  or
                           currentInstruction = LDH  else
                outras;
                           
    currentInstruction <= ADD    when OPCODE = x"0" else 
                          SUB    when OPCODE = x"1" else
                          AAND   when OPCODE = x"2" else
                          OOR    when OPCODE = x"3" else
                          XXOR   when OPCODE = x"4" else
                          ADDI   when OPCODE = x"5" else
                          SUBI   when OPCODE = x"6" else
                          LDL    when OPCODE = x"7" else
                          LDH    when OPCODE = x"8" else
                          LD     when OPCODE = x"9" else
                          ST     when OPCODE = x"A" else      
					           SL0    when OPCODE = x"B"  and  REGSOURCE2 = x"0" else
				              SL1    when OPCODE = x"B"  and  REGSOURCE2 = x"1" else
                          SR0    when OPCODE = x"B"  and  REGSOURCE2 = x"2" else
				              SR1    when OPCODE = x"B"  and  REGSOURCE2 = x"3" else
                          NOT_A  when OPCODE = x"B"  and  REGSOURCE2 = x"4" else
                          NOP    when OPCODE = x"B"  and  REGSOURCE2 = x"5" else
                          HALT   when OPCODE = x"B"  and  REGSOURCE2 = x"6" else
				              LDSP   when OPCODE = x"B"  and  REGSOURCE2 = x"7" else
				              RTS    when OPCODE = x"B"  and  REGSOURCE2 = x"8" else
				              POP    when OPCODE = x"B"  and  REGSOURCE2 = x"9" else
                          PUSH   when OPCODE = x"B"  and  REGSOURCE2 = x"A" else
						  
						  -- Novas Instruções T4P1
						        MUL     when OPCODE = x"B" and REGSOURCE2 = x"B" else -- MULTIPLICAÇÃO
                          DIV     when OPCODE = x"B" and REGSOURCE2 = x"C" else -- DIVISÃO
                          MFH     when OPCODE = x"B" and REGSOURCE2 = x"D" else -- MOVE FROM HIGH
                          MFL     when OPCODE = x"B" and REGSOURCE2 = x"E" else -- MOVE FROM LOW
                          
                          JUMP_R when OPCODE = x"C" and (
                                      ( REGSOURCE2 = x"0") or             -- JMPR
                                      ( REGSOURCE2 = x"1" and n = '1') or -- JMPNR
                                      ( REGSOURCE2 = x"2" and z = '1') or -- JMPZR
                                      ( REGSOURCE2 = x"3" and c = '1') or -- JMPCR
                                      ( REGSOURCE2 = x"4" and v = '1')    -- JMPVR
                          )else
						  
                          JUMP_A when OPCODE = x"C" and (
                                      ( REGSOURCE2 = x"5") or             -- JMP
                                      ( REGSOURCE2 = x"6" and n = '1') or -- JMPN
                                      ( REGSOURCE2 = x"7" and z = '1') or -- JMPZ
                                      ( REGSOURCE2 = x"8" and c = '1') or -- JMPC
                                      ( REGSOURCE2 = x"9" and v = '1')    -- JMPV
                          )else
                          
                          JUMP_D when OPCODE = x"D" or ( OPCODE = x"E" and (  -- JMPD  
                                      ( JMPD_AUX = "00" and n = '1') or       -- JMPND
                                      ( JMPD_AUX = "01" and z = '1') or       -- JMPZD
                                      ( JMPD_AUX = "10" and c = '1') or       -- JMPCD
                                      ( JMPD_AUX = "11" and v = '1')          -- JMPVD
                                    )
                          )else 

                          JSRR  when OPCODE = x"C"  and  REGSOURCE2 = x"A" else
                          JSR   when OPCODE = x"C"  and  REGSOURCE2 = x"B" else
                          JSRD  when OPCODE = x"F" else

                          -- Novas Instruções T3P2
                          PUSHF when OPCODE = x"C" and REGSOURCE2 = x"C" else -- PUSH FLAGS
			                 POPF  when OPCODE = x"C" and REGSOURCE2 = x"D" else -- POP FLAGS
			                 RTI   when OPCODE = x"C" and REGSOURCE2 = x"E" else -- RETORNO DE INTERRUPCAO
                            
                          
                          NOP; -- Jumps condicionais com flag = 0
								                            
	process(clk, rst)
	begin
		if rst = '1' then      

			regPC    <= (others=>'0');
			regSP    <= (others=>'0');
         regALU   <= (others=>'0');
         regIR    <= (others=>'0');
         regA     <= (others=>'0');
         regB     <= (others=>'0');
			regFLAGS <= (others=>'0');
			regHIGH  <= (others=>'0');
			regLOW   <= (others=>'0');
            --data_out <= (others=>'0');
            
            for i in 0 to 15 loop
                regBank(i) <= (others => '0');
            end loop;
			
			interruptFlag <= '0';
            
            currentState <= Sfetch;
            
		elsif rising_edge(clk) then
			if currentState = Sfetch then  -- Requests next instruction from memory
			
				if irq = '1' and interruptFlag = '0' then
                    -- Defines next state
					currentState <= Sitr;
			    else
			    	-- Defines next state
					currentState <= Sreg;
					regIR <= data_in;

                    -- Increments Program Counter       
                    regPC <= regPC + 1;
				end if;

            elsif currentState = Sitr then
                -- Saves PC on stack
                regSP <= regSP - 1;

                -- InterruptFlag says on until RTI instruction is executed
                interruptFlag <= '1';

                -- Next instruction is the first instruction on the ISR subroutine
                regPC <= ISR_ADDR;

                -- Fetches first instruction of ISR subroutine
                currentState <= Sfetch;

			elsif currentState = Sreg then 
				-- Reads register bank
				regA <= regBank(to_integer(unsigned(REGSOURCE1)));
                
				if (instType = tipo2 or currentInstruction = PUSH or currentInstruction = MUL or currentInstruction = DIV) then
                    regB <= regBank(to_integer(unsigned(REGTARGET)));
				else
					regB <= regBank(to_integer(unsigned(REGSOURCE2)));
				end if;
                
				-- Defines next state
				if (currentInstruction = HALT) then
					currentState <= Shalt;
				else
					currentState <= Sula;
				end if;
				
			elsif currentState = Shalt then
				-- Idles until next reset (only leaves this state when signal rst = '1' or irq = '1')
                if irq = '1' and interruptFlag = '0' then
                    currentState <= Sitr;
                    regPC <= regPC - 1; -- In order to remain on halt on return from interruption
                else
                    currentState <= Shalt;
                end if;

			elsif currentState = Sula then
				-- Utilização da ALU
                regALU <= outALU;
                
                --Geração de flag
                if currentInstruction = ADD or currentInstruction = SUB or currentInstruction = ADDI or currentInstruction = SUBI then
                    v <= flagV; -- Flag de overflow
                    c <= flagC; -- Flag de carry
                end if;
                
                if (instType = tipo1) or (currentInstruction = ADDI or currentInstruction = SUBI) then
                    n <= flagN; -- Flag de negativo
                    z <= flagZ; -- Flag de zero
                end if;
                
				--Defines next state
				if (instType = tipo1) or (instType = tipo2) then
					currentState <= Swbk;   
				elsif currentInstruction = LD then
					currentState <= Sld;
				elsif currentInstruction = ST then
					currentState <= Sst;
				elsif currentInstruction = JUMP_R or currentInstruction = JUMP_A or currentInstruction = JUMP_D then
					currentState <= Sjmp;
				elsif (currentInstruction = JSR) or (currentInstruction = JSRR) or (currentInstruction = JSRD) then
					currentState <= Ssbrt;
				elsif currentInstruction = PUSH then
					currentState <= Spush;
				elsif currentInstruction = RTS then
					currentState <= Srts;
				elsif currentInstruction = POP then
					currentState <= Spop;
				elsif currentInstruction = LDSP then
					currentState <= Sldsp;
					
				-- NOVAS INSTRUÇOES T3P2
				elsif currentInstruction = PUSHF then
					currentState <= Spushf;
				elsif currentInstruction = POPF then
					currentState <= Spopf;
				elsif currentInstruction = RTI then
					currentState <= Srti;

				-- NOVAS INSTRUÇÔES T4P1
				elsif currentInstruction = MUL then
					currentState <= Smul;
				elsif currentInstruction = DIV then
					currentState <= Sdiv;
				elsif currentInstruction = MFH then
					currentState <= Smfh;
				elsif currentinstruction = MFL then
					currentState <= Smfl;

				else
					currentState <= Sfetch;
				end if;
				
			elsif currentState = Swbk then -- Ultimo ciclo de instrues logicas e aritmeticas
				regBank(to_integer(unsigned(REGTARGET))) <= regALU;
				currentState <= Sfetch;
                
			elsif currentState = Sld then -- Ultimo ciclo de load
				regBank(to_integer(unsigned(REGTARGET))) <= data_in;
				currentState <= Sfetch;
                
			elsif currentState = Sst then -- Ultimo ciclo de store
				currentState <= Sfetch;
                
			elsif currentState = Sjmp then -- Ultimo ciclo p/ saltos
                regPC <= regALU; -- Atualiza o PC
				currentState <= Sfetch;
                
			elsif currentState = Ssbrt then -- Ultimo ciclo Subrotina
                regPC <= regALU; -- Atualiza o PC
                regSP <= regSP - 1; 
				currentState <= Sfetch;
                
			elsif currentState = Spush then -- Ultimo ciclo p push
                regSP <= regSP - 1;      -- Adicionado na apresentação          
				currentState <= Sfetch;
                
			elsif currentState = Srts then -- Ultimo ciclo retorno subronita 
                regSP <= regSP + 1;
                regPC <= data_in; -- Volta o PC da pilha
				currentState <= Sfetch;
                
			elsif currentState = Spop then -- Ultimo ciclo de POP
                regSP <= regSP + 1;
                regBank(to_integer(unsigned(REGTARGET)))<= data_in; -- Banco de registradores enderaçado <= mem pelo SP
				currentState <= Sfetch;
                
			elsif currentState = Sldsp then -- Ultimo ciclo de load do SP
                regSP <= regALU;
				currentState <= Sfetch;
				
			-- NOVAS INSTRUÇOES T3P2
			elsif currentState = Spushf then
				regSP <= regSP - 1;
				currentState <= Sfetch;
				
			elsif currentState = Spopf then
				regSP <= regSP + 1;
				regFLAGS <= data_in(3 downto 0);
				currentState <= Sfetch;
				
			elsif currentState = Srti then
				regSP <= regSP + 1;
				regPC <= data_in;
				interruptFlag <= '0';
				currentState <= Sfetch;

			-- NOVAS INSTRUÇÔES T4P1
			elsif currentState = Smul then
				regHIGH <= multiplicador(31 downto 16);
				regLOW <= multiplicador(15 downto 0);
				currentState <= Sfetch;

			elsif currentState = Sdiv then
				regHIGH <= divisor(31 downto 16);
				regLOW <= divisor(15 downto 0);
				currentState <= Sfetch;

			elsif currentState = Smfh then
				regBank(to_integer(unsigned(REGTARGET))) <= regHIGH;
				currentState <= Sfetch;

			elsif currentState = Smfl then
				regBank(to_integer(unsigned(REGTARGET))) <= regLOW;
				currentState <= Sfetch;

            else
                currentState <= Shalt;
			end if;			
		end if;
	end process;

	multiplicador <= (regA * regB) when currentinstruction = MUL else (others=>'0');

	divisor(31 downto 16) <= STD_LOGIC_VECTOR ( UNSIGNED(regB) mod UNSIGNED(regA) ) when (currentInstruction = DIV and regA/= 0) else (others=>'0');																												  
	divisor(15 downto 0)  <= STD_LOGIC_VECTOR ( SIGNED(regB) / SIGNED(regA) ) when (currentInstruction = DIV and regA/= 0) else (others=>'0');
	
	ALUaux <= ('0' & regA) + ('0' & regB) when currentInstruction = ADD else
			  ('0' & regA) + ('0' & ((not(regB))+1)) when currentInstruction = SUB else
			  ('0' & regB) + ('0' & x"00" & CONSTANTE) when currentInstruction = ADDI else
			  ('0' & regB) + ((not('0' & x"00" & CONSTANTE))+1); -- when currentInstruction = SUBI;
    
    outALU <= ALUaux(15 downto 0) when (currentInstruction = ADD or currentInstruction = SUB or currentInstruction = ADDI or currentInstruction = SUBI) else 
              regA and regB when currentInstruction = AAND else
              regA or regB when currentInstruction = OOR else
              regA xor regB when currentInstruction = XXOR else
              regB(15 downto 8) & CONSTANTE when currentInstruction = LDL else
              CONSTANTE & regB(7 downto 0) when currentInstruction = LDH else
              regA + regB when currentInstruction = LD else --rt <= PMEM (Rs1 + Rs2)
              regA + regB when currentInstruction = ST else -- PMEM (Rs1 + Rs2) <- rt
              regA(14 downto 0) & '0' when  currentInstruction = SL0 else
              regA(14 downto 0) & '1' when  currentInstruction = SL1 else
              '0' & regA(15 downto 1) when currentInstruction = SR0 else
              '1' & regA(15 downto 1) when currentInstruction = SR1 else
              not(regA) when currentInstruction = NOT_A else
              regSP + 1 when currentInstruction = RTS or currentInstruction = POP or currentInstruction = POPF or currentInstruction = RTI else
              regPC + regA when currentInstruction = JUMP_R else
              regPC + (JMPD_DESLOC(9)&JMPD_DESLOC(9)&JMPD_DESLOC(9)&JMPD_DESLOC(9)&JMPD_DESLOC(9)&JMPD_DESLOC(9)&JMPD_DESLOC) when currentInstruction = JUMP_D else
              regPC + (JSRD_DESLOC(11) & JSRD_DESLOC(11) & JSRD_DESLOC(11) & JSRD_DESLOC(11) & JSRD_DESLOC) when currentInstruction = JSRD else
              regA when currentInstruction = JSR or currentInstruction = JSRR else
              regA; -- JMP_A, LDSP
              
    -- Flags para a ULA       
    flagC <= ALUaux(16); --carry
    flagV <= '1' when ((regA(15) = regB(15)) and (regA(15) /= outALU(15))) else '0'; -- overflow
    flagN <= outALU(15); -- negativo
    flagZ <= '1' when outALU = 0 else '0';  -- zero
	
    -- SINAIS MEMORIA 
    address <= regPC when currentState = Sfetch else
               --outALU when currentState = Sld or currentState = Sst or currentState = Spop or currentState = Srts else
               regALU when currentState = Sld or currentState = Sst or currentState = Spop or currentState = Srts or currentState = Spopf or currentState = Srti else
               regSP; -- Pra dar salto em uma subrotina e o PUSH (Spushf, Spush, Sitr)
                    
    data_out <= regBank(to_integer(unsigned(REGTARGET))) when currentState = Sst and rst = '0' else
                regB when currentState = Spush and rst = '0' else
                regPC when currentState = Ssbrt and rst = '0' else
				( "000000000000" & regFLAGS ) when currentState = Spushf and rst = '0' else
				regPC when currentState = Sitr and rst = '0' else
                (others=>'0');

    ce <= '1' when rst = '0' and (currentState = Sld or currentState = Ssbrt or currentState = Spush or currentState = Sst or currentState = Sfetch or currentState = Srts or currentState = Spop or
								  currentState = Spopf or currentState = Spushf or currentState = Sitr or currentState = Srti) else '0';
								  
    rw <= '1' when (currentState = Sfetch or currentState = Spop or currentState = Srts or currentState = Sld or currentState = Spopf or currentState = Srti) else '0';
    
end Behavioural;
