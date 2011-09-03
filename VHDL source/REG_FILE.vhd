-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #         30x32-Bit Banked 1w3r Register File         #
-- #             (+ address translation unit)            #
-- # *************************************************** #
-- # Version 2.3, 28.05.2011                             #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity REG_FILE is
	port	(
-- ###############################################################################################
-- ##       Global Control                                                                      ##
-- ###############################################################################################

				CLK				: in  STD_LOGIC; -- global clock network
				RES				: in  STD_LOGIC; -- global reset network

-- ###############################################################################################
-- ##       Local Control                                                                       ##
-- ###############################################################################################

				CTRL_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- control lines
				OP_ADR_IN		: in  STD_LOGIC_VECTOR(11 downto 0); -- operand addresses
				MODE_IN			: in  STD_LOGIC_VECTOR(04 downto 0); -- current mode

				DEBUG_R0			: out STD_LOGIC_VECTOR(07 downto 0); -- debugging stuff
				DEBUG_R1			: out STD_LOGIC_VECTOR(07 downto 0); -- debugging stuff

-- ###############################################################################################
-- ##       Operand Connection                                                                  ##
-- ###############################################################################################

				WB_DATA_IN		: in  STD_LOGIC_VECTOR(31 downto 0); -- write back data path
				PC_IN				: in  STD_LOGIC_VECTOR(31 downto 0); -- current program counter

				OP_A_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- register A output
				OP_B_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- register B output
				OP_C_OUT			: out STD_LOGIC_VECTOR(31 downto 0)  -- register C output

			);
end REG_FILE;

architecture REG_FILE_STRUCTURE of REG_FILE is

	-- Data Register File --
	type   REG_FILE_TYPE is array (0 to 31) of STD_LOGIC_VECTOR(31 downto 0);
	signal REG_FILE : REG_FILE_TYPE;

	-- Memory <-> Register Allocation Map
	-- ----------------------------------------------------------------------
	-- 00: USR32 R0		10: USR32 R10		20: FIQ32 R13		30: Dummy PC
	-- 01: USR32 R1		11: USR32 R11		21: FIQ32 R14		31: Dummy Reg
	-- 02: USR32 R2		12: USR32 R12		22: SVP32 R13
	-- 03: USR32 R3		13: USR32 R13		23: SVP32 R14
	-- 04: USR32 R4		14: USR32 R14		24: ABT32 R13
	-- 05: USR32 R5		15: FIQ32 R8		25: ABT32 R14
	-- 06: USR32 R6		16: FIQ32 R9		26: IRQ32 R13
	-- 07: USR32 R7		17: FIQ32 R10		27: IRQ32 R14
	-- 08: USR32 R8		18: FIQ32 R11		28: UND32 R13
	-- 09: USR32 R9		19: FIQ32 R12		29: UND32 R14

	-- Address Busses --
	signal R_ADR_PORT_A, R_ADR_PORT_B, R_ADR_PORT_C : STD_LOGIC_VECTOR(4 downto 0);
	signal R_ADR_DB1, R_ADR_DB2                     : STD_LOGIC_VECTOR(4 downto 0);
	signal W_ADR_PORT, PC_ADR_PORT                  : STD_LOGIC_VECTOR(4 downto 0);

	-- Address Translator --
	component ADR_TRANSLATION_UNIT
		port	(
					REG_ADR_IN	: in  STD_LOGIC_VECTOR(3 downto 0);
					MODE_IN		: in  STD_LOGIC_VECTOR(4 downto 0);
					ADR_OUT		: out STD_LOGIC_VECTOR(4 downto 0)
				);
	end component;

begin

	-- Register File Write Access ---------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------

		--- Write Access Data Port ---
		write_access_data_port:
			ADR_TRANSLATION_UNIT
				port map (
								REG_ADR_IN	=> CTRL_IN(CTRL_RD_3 downto CTRL_RD_0),
								MODE_IN		=> CTRL_IN(CTRL_MODE_4 downto CTRL_MODE_0),
								ADR_OUT		=> W_ADR_PORT
							);

		--- Clock Triggered Write ---
		SYNCHRONOUS_MEM_WRITE: process(CLK, W_ADR_PORT, WB_DATA_IN, CTRL_IN)
		begin
			if rising_edge(CLK) then
				if ((CTRL_IN(CTRL_EN) and CTRL_IN(CTRL_WB_EN)) = '1') then
					REG_FILE(to_integer(unsigned(W_ADR_PORT))) <= WB_DATA_IN;
				end if;
			end if;
		end process SYNCHRONOUS_MEM_WRITE;



	-- Register File Read Access ----------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------

		--- Read Access Port A ---
		read_access_port_a:
			ADR_TRANSLATION_UNIT
				port map (
								REG_ADR_IN	=> OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0),
								MODE_IN		=> MODE_IN,
								ADR_OUT		=> R_ADR_PORT_A
							);

		--- Read Access Port B ---
		read_access_port_b:
			ADR_TRANSLATION_UNIT
				port map (
								REG_ADR_IN	=> OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0),
								MODE_IN		=> MODE_IN,
								ADR_OUT		=> R_ADR_PORT_B
							);

		--- Read Access Port C ---
		read_access_port_c:
			ADR_TRANSLATION_UNIT
				port map (
								REG_ADR_IN	=> OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0),
								MODE_IN		=> MODE_IN,
								ADR_OUT		=> R_ADR_PORT_C
							);

		--- Read Access Debug Port 1 ---
		read_access_bebug_1:
			ADR_TRANSLATION_UNIT
				port map (
								REG_ADR_IN	=> "0000", -- R0
								MODE_IN		=> User32_MODE,
								ADR_OUT		=> R_ADR_DB1
							);

		--- Read Access Debug Port 2 ---
		read_access_debug_2:
			ADR_TRANSLATION_UNIT
				port map (
								REG_ADR_IN	=> "0001", -- R1
								MODE_IN		=> User32_MODE,
								ADR_OUT		=> R_ADR_DB2
							);


		--- Memory Read Access ---
		OP_A_OUT <= REG_FILE(to_integer(unsigned(R_ADR_PORT_A))) when 
						(OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) /= C_PC_ADR) else PC_IN;
		OP_B_OUT <= REG_FILE(to_integer(unsigned(R_ADR_PORT_B))) when 
						(OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) /= C_PC_ADR) else PC_IN;
		OP_C_OUT <= REG_FILE(to_integer(unsigned(R_ADR_PORT_C))) when 
						(OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) /= C_PC_ADR) else PC_IN;

		DEBUG_R0(7 downto 0) <= REG_FILE(to_integer(unsigned(R_ADR_DB1)))(7 downto 0);
		DEBUG_R1(7 downto 0) <= REG_FILE(to_integer(unsigned(R_ADR_DB2)))(7 downto 0);



end REG_FILE_STRUCTURE;

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------


-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #         REG-FILE Address Translation Unit           #
-- # *************************************************** #
-- # Version 1.1, 28.05.2011                             #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity ADR_TRANSLATION_UNIT is
	port	(
				-- Register Address Input --
				--------------------------------------------------
				REG_ADR_IN	: in  STD_LOGIC_VECTOR(3 downto 0);
				
				-- MODE Input --
				--------------------------------------------------
				MODE_IN		: in  STD_LOGIC_VECTOR(4 downto 0);
				
				-- Memory Address Output --
				--------------------------------------------------
				ADR_OUT		: out STD_LOGIC_VECTOR(4 downto 0)
			);
end ADR_TRANSLATION_UNIT;

architecture ADRTU_STRUCTURE of ADR_TRANSLATION_UNIT is

begin

	-- Address Translator -----------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		ADR_TRANSLATOR: process(REG_ADR_IN, MODE_IN)
			variable VIRT_REG_SEL : STD_LOGIC_VECTOR(15 downto 0);
			variable REAL_REG_SEL : STD_LOGIC_VECTOR(31 downto 0);
			variable temp         : integer range 0 to 31;
		begin

			--- One-Hot Virtual Register Select ---
			case (REG_ADR_IN) is
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
				when "1111" => VIRT_REG_SEL := "1000000000000000"; -- DUMMY PC
				when others => VIRT_REG_SEL := "----------------"; -- undefined
			end case;

			--- Address Mapping: Virtual Register -> Real Register ---
			REAL_REG_SEL := (others => '0');
			REAL_REG_SEL(07 downto 00) := VIRT_REG_SEL(07 downto 00); -- R0-R7 are always the same
			REAL_REG_SEL(31) := VIRT_REG_SEL(15); -- PC access = dummy access

			case (MODE_IN) is

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

			--- Address Encoder ---
			case (REAL_REG_SEL) is
				when "00000000000000000000000000000001" => ADR_OUT <= "00000";
				when "00000000000000000000000000000010" => ADR_OUT <= "00001";
				when "00000000000000000000000000000100" => ADR_OUT <= "00010";
				when "00000000000000000000000000001000" => ADR_OUT <= "00011";
				when "00000000000000000000000000010000" => ADR_OUT <= "00100";
				when "00000000000000000000000000100000" => ADR_OUT <= "00101";
				when "00000000000000000000000001000000" => ADR_OUT <= "00110";
				when "00000000000000000000000010000000" => ADR_OUT <= "00111";
				when "00000000000000000000000100000000" => ADR_OUT <= "01000";
				when "00000000000000000000001000000000" => ADR_OUT <= "01001";
				when "00000000000000000000010000000000" => ADR_OUT <= "01010";
				when "00000000000000000000100000000000" => ADR_OUT <= "01011";
				when "00000000000000000001000000000000" => ADR_OUT <= "01100";
				when "00000000000000000010000000000000" => ADR_OUT <= "01101";
				when "00000000000000000100000000000000" => ADR_OUT <= "01110";
				when "00000000000000001000000000000000" => ADR_OUT <= "01111";
				when "00000000000000010000000000000000" => ADR_OUT <= "10000";
				when "00000000000000100000000000000000" => ADR_OUT <= "10001";
				when "00000000000001000000000000000000" => ADR_OUT <= "10010";
				when "00000000000010000000000000000000" => ADR_OUT <= "10011";
				when "00000000000100000000000000000000" => ADR_OUT <= "10100";
				when "00000000001000000000000000000000" => ADR_OUT <= "10101";
				when "00000000010000000000000000000000" => ADR_OUT <= "10110";
				when "00000000100000000000000000000000" => ADR_OUT <= "10111";
				when "00000001000000000000000000000000" => ADR_OUT <= "11000";
				when "00000010000000000000000000000000" => ADR_OUT <= "11001";
				when "00000100000000000000000000000000" => ADR_OUT <= "11010";
				when "00001000000000000000000000000000" => ADR_OUT <= "11011";
				when "00010000000000000000000000000000" => ADR_OUT <= "11100";
				when "00100000000000000000000000000000" => ADR_OUT <= "11101";
--				when "01000000000000000000000000000000" => ADR_OUT <= "11111";
--				when "10000000000000000000000000000000" => ADR_OUT <= "11111";
				when others                             => ADR_OUT <= "11111";
			end case;

		end process ADR_TRANSLATOR;


end ADRTU_STRUCTURE;