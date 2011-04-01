-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #         30x32 Bit Banked 1w3r Register File         #
-- # *************************************************** #
-- # Version 2.2, 01.04.2011                             #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity REG_FILE is
	port	(
-- ###############################################################################################
-- ##			Global Control                                                                      ##
-- ###############################################################################################

				CLK				: in  STD_LOGIC; -- global clock network
				RES				: in  STD_LOGIC; -- global reset network
				
-- ###############################################################################################
-- ##			Local Control                                                                       ##
-- ###############################################################################################
				
				CTRL_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- control lines
				OP_ADR_IN		: in  STD_LOGIC_VECTOR(11 downto 0); -- register addresses
				MODE_IN			: in  STD_LOGIC_VECTOR(04 downto 0); -- current mode
				
				DEBUG_R0			: out STD_LOGIC_VECTOR(07 downto 0);
				DEBUG_R1			: out STD_LOGIC_VECTOR(07 downto 0);

-- ###############################################################################################
-- ##			Operand Connection                                                                  ##
-- ###############################################################################################

				MEM_DATA_IN		: in  STD_LOGIC_VECTOR(31 downto 0); -- memory data path
				BP2_DATA_IN		: in  STD_LOGIC_VECTOR(31 downto 0); -- alu data path
				PC_IN				: in  STD_LOGIC_VECTOR(31 downto 0); -- current program counter

				OP_A_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- register a output
				OP_B_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- register b output
				OP_C_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- register c output

-- ###############################################################################################
-- ##			Forwarding Path                                                                     ##
-- ###############################################################################################

				WB_FW_OUT		: out STD_LOGIC_VECTOR(40 downto 0)  -- forwarding data & ctrl

			);
end REG_FILE;

architecture REG_FILE_STRUCTURE of REG_FILE is

	-- Operand buffers --
	signal	BP2_DATA		: STD_LOGIC_VECTOR(31 downto 0);
	signal	MEM_DATA		: STD_LOGIC_VECTOR(31 downto 0);

	-- Local Signals --
	signal	REG_WB_DATA	: STD_LOGIC_VECTOR(31 downto 0);

	-- Read Bus System --
	type		READ_BUS_TYPE is array (0 to 15) of STD_LOGIC_VECTOR(31 downto 0);
	signal	READ_BUS: READ_BUS_TYPE;

	-- Data Register File --
	type		REG_FILE_TYPE is array (0 to 29) of STD_LOGIC_VECTOR(31 downto 0);
	signal	REG_FILE	: REG_FILE_TYPE;

	-- Register Allocation Map
	-- --------------------------------------------------
	-- 00: USR32 R0		10: USR32 R10		20: FIQ32 R13
	-- 01: USR32 R1		11: USR32 R11		21: FIQ32 R14
	-- 02: USR32 R2		12: USR32 R12		22: SVP32 R13
	-- 03: USR32 R3		13: USR32 R13		23: SVP32 R14
	-- 04: USR32 R4		14: USR32 R14		24: ABT32 R13
	-- 05: USR32 R5		15: FIQ32 R8		25: ABT32 R14
	-- 06: USR32 R6		16: FIQ32 R9		26: IRQ32 R13
	-- 07: USR32 R7		17: FIQ32 R10		27: IRQ32 R14
	-- 08: USR32 R8		18: FIQ32 R11		28: UND32 R13
	-- 09: USR32 R9		19: FIQ32 R12		29: UND32 R14

begin

	-- Pipeline Registers -----------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		PIPE_REG: process(CLK, RES)
		begin
			if rising_edge(CLK) then
				if (RES = '1') then
					BP2_DATA <= (others => '0');
					MEM_DATA <= (others => '0');
				else
					BP2_DATA <= BP2_DATA_IN;
					MEM_DATA <= MEM_DATA_IN; 
				end if;
			end if;
		end process PIPE_REG;



	-- Write Back Data Selector -----------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		WB_DATA_MUX: process(CTRL_IN, MEM_DATA, BP2_DATA)
		begin
			if (CTRL_IN(CTRL_MEM_ACC) = '1') and (CTRL_IN(CTRL_MEM_RW) = '0') then
				-- memory read access --
				REG_WB_DATA <= MEM_DATA;
			else
				-- register/mcr read access --
				REG_WB_DATA <= BP2_DATA;
			end if;
		end process WB_DATA_MUX;



	-- Forwarding Path --------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		WB_FW_OUT(FWD_DATA_MSB downto FWD_DATA_LSB) <= REG_WB_DATA;
		WB_FW_OUT(FWD_RD_MSB  downto  FWD_RD_LSB)   <= CTRL_IN(CTRL_RD_3 downto CTRL_RD_0);
		WB_FW_OUT(FWD_WB)                           <= CTRL_IN(CTRL_EN) and CTRL_IN(CTRL_WB_EN);



	-- Register File Write Access ---------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		REGFILE_WRITE_ACCESS: process(CTRL_IN, CLK, REG_WB_DATA)
			variable VIRT_REG_SEL : STD_LOGIC_VECTOR(15 downto 0);
			variable REAL_REG_SEL : STD_LOGIC_VECTOR(29 downto 0);
		begin

			--- One-Hot Virtual Register Select ---
			case (CTRL_IN(CTRL_RD_3 downto CTRL_RD_0)) is
				when "0000" => VIRT_REG_SEL := "0000000000000001"; -- R0_<mode>
				when "0001" => VIRT_REG_SEL := "0000000000000010"; -- R1_<mode>
				when "0010" => VIRT_REG_SEL := "0000000000000100"; -- R2_<mode>
				when "0011" => VIRT_REG_SEL := "0000000000001000"; -- R3_<mode>
				when "0100" => VIRT_REG_SEL := "0000000000010000"; -- R4_<mode>
				when "0101" => VIRT_REG_SEL := "0000000000100000"; -- R5_<mode>
				when "0110" => VIRT_REG_SEL := "0000000001000000"; -- R6_<mode>
				when "0111" => VIRT_REG_SEL := "0000000010000000"; -- R7_<mode>
				when "1000" => VIRT_REG_SEL := "0000000100000000"; -- R8_<mode>
				when "1001" => VIRT_REG_SEL := "0000001000000000"; -- R9_<mode>
				when "1010" => VIRT_REG_SEL := "0000010000000000"; -- R10_<mode>
				when "1011" => VIRT_REG_SEL := "0000100000000000"; -- R11_<mode>
				when "1100" => VIRT_REG_SEL := "0001000000000000"; -- R12_<mode>
				when "1101" => VIRT_REG_SEL := "0010000000000000"; -- R13_<mode>
				when "1110" => VIRT_REG_SEL := "0100000000000000"; -- R14_<mode>
				when others => VIRT_REG_SEL := "1000000000000000"; -- R15_<mode>
			end case;

			--- Address Mapping Virtual Register -> Real Register ---
			REAL_REG_SEL := (others => '0');
			REAL_REG_SEL(07 downto 00) := VIRT_REG_SEL(07 downto 00);

			case (CTRL_IN(CTRL_MODE_4 downto CTRL_MODE_0)) is
	
				when User32_MODE =>
					REAL_REG_SEL(14 downto 08) := VIRT_REG_SEL(14 downto 08);

				when FIQ32_MODE =>
					REAL_REG_SEL(21 downto 15) := VIRT_REG_SEL(14 downto 08);
	
				when Supervisor32_MODE =>
					REAL_REG_SEL(12 downto 08) := VIRT_REG_SEL(12 downto 08);
					REAL_REG_SEL(23 downto 22) := VIRT_REG_SEL(14 downto 13);

				when Abort32_MODE =>
					REAL_REG_SEL(12 downto 08) := VIRT_REG_SEL(12 downto 08);
					REAL_REG_SEL(25 downto 24) := VIRT_REG_SEL(14 downto 13);

				when IRQ32_MODE =>
					REAL_REG_SEL(12 downto 08) := VIRT_REG_SEL(12 downto 08);
					REAL_REG_SEL(27 downto 26) := VIRT_REG_SEL(14 downto 13);

				when Undefined32_MODE =>
					REAL_REG_SEL(12 downto 08) := VIRT_REG_SEL(12 downto 08);
					REAL_REG_SEL(29 downto 28) := VIRT_REG_SEL(14 downto 13);

				when others =>
					REAL_REG_SEL(29 downto 00) := (others => '0');

			end case;

			--- Synchronous Write ---
			if rising_edge(CLK) then
				if ((CTRL_IN(CTRL_EN) and CTRL_IN(CTRL_WB_EN)) = '1') then
				
					for i in 0 to 29 loop
						if REAL_REG_SEL(i) = '1' then
							REG_FILE(i) <= REG_WB_DATA;
						else
							REG_FILE(i) <= REG_FILE(i);
						end if;
					end loop;
				
				end if;
			end if;

		end process REGFILE_WRITE_ACCESS;



	-- Register File Read Access ----------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		REGFILE_READ_ACCESS: process(MODE_IN, PC_IN, REG_FILE)
			variable VIRT_REG_SEL : STD_LOGIC_VECTOR(15 downto 0);
			variable REAL_REG_SEL : STD_LOGIC_VECTOR(29 downto 0);
		begin
		
			--- Read Bus Construction ---
			for i in 0 to 7 loop
				READ_BUS(i) <= REG_FILE(i);
			end loop;
			READ_BUS(15) <= PC_IN; -- there is just one PC
			case (MODE_IN) is

				when User32_MODE =>
					--READ_BUS(14 downto 00) <= REG_FILE(14 downto 00);
					for i in 8 to 14 loop
						READ_BUS(i) <= REG_FILE(i);
					end loop;

				when FIQ32_MODE =>
					--READ_BUS(14 downto 08) <= REG_FILE(21 downto 15);
					for i in 08 to 14 loop
						READ_BUS(i) <= REG_FILE(i+7);
					end loop;

				when Supervisor32_MODE =>
					--READ_BUS(12 downto 08) <= REG_FILE(12 downto 08);
					--READ_BUS(14 downto 13) <= REG_FILE(23 downto 22);
					for i in 08 to 12 loop
						READ_BUS(i) <= REG_FILE(i);
					end loop;
					for i in 13 to 14 loop
						READ_BUS(i) <= REG_FILE(i+9);
					end loop;

				when Abort32_MODE =>
					--READ_BUS(12 downto 08) <= REG_FILE(12 downto 08);
					--READ_BUS(14 downto 13) <= REG_FILE(25 downto 24);
					for i in 08 to 12 loop
						READ_BUS(i) <= REG_FILE(i);
					end loop;
					for i in 13 to 14 loop
						READ_BUS(i) <= REG_FILE(i+11);
					end loop;

				when IRQ32_MODE =>
					--READ_BUS(12 downto 08) <= REG_FILE(12 downto 08);
					--READ_BUS(14 downto 13) <= REG_FILE(27 downto 26);
					for i in 08 to 12 loop
						READ_BUS(i) <= REG_FILE(i);
					end loop;
					for i in 13 to 14 loop
						READ_BUS(i) <= REG_FILE(i+13);
					end loop;

				when Undefined32_MODE =>
					--READ_BUS(12 downto 08) <= REG_FILE(12 downto 08);
					--READ_BUS(14 downto 13) <= REG_FILE(29 downto 28);
					for i in 08 to 12 loop
						READ_BUS(i) <= REG_FILE(i);
					end loop;
					for i in 13 to 14 loop
						READ_BUS(i) <= REG_FILE(i+15);
					end loop;

				when others =>
					--READ_BUS(14 downto 00) <= REG_FILE(14 downto 00);
					for i in 8 to 14 loop
						READ_BUS(i) <= REG_FILE(i);
					end loop;

			end case;
		end process REGFILE_READ_ACCESS;



	-- Operand Read Access ----------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		--- Read Access ---
		OP_A_OUT <= READ_BUS(to_integer(unsigned(OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0))));
		OP_B_OUT <= READ_BUS(to_integer(unsigned(OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0))));
		OP_C_OUT <= READ_BUS(to_integer(unsigned(OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0))));

		--- Debugging Stuff ---
		DEBUG_R0(7 downto 0) <= READ_BUS(0)(7 downto 0);
		DEBUG_R1(7 downto 0) <= READ_BUS(1)(7 downto 0);



end REG_FILE_STRUCTURE;