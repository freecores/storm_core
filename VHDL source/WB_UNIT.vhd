-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #      Data Write Back Selector & MEM Read Input      #
-- # *************************************************** #
-- # Version 1.0, 18.04.2011                             #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity WB_UNIT is
	port	(
-- ###############################################################################################
-- ##       Global Control                                                                      ##
-- ###############################################################################################

				CLK				: in  STD_LOGIC;							 -- global clock network
				RES				: in  STD_LOGIC;							 -- global reset network
				CTRL_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- stage control

-- ###############################################################################################
-- ##       Operand Connection                                                                  ##
-- ###############################################################################################

				ALU_DATA_IN		: in  STD_LOGIC_VECTOR(31 downto 0); -- alu data input
				ADR_BUFF_IN		: in  STD_LOGIC_VECTOR(31 downto 0); -- alu address input

				WB_DATA_OUT		: out STD_LOGIC_VECTOR(31 downto 0); -- write back data output

				XMEM_RD_DATA	: in  STD_LOGIC_VECTOR(31 downto 0); -- memory data input

				INSTR_DAT_OUT	: out STD_LOGIC_VECTOR(31 downto 0); -- new instruction data output

-- ###############################################################################################
-- ##       Forwarding Path                                                                     ##
-- ###############################################################################################

				WB_FW_OUT		: out STD_LOGIC_VECTOR(40 downto 0)  -- forwarding data & ctrl

			);
end WB_UNIT;

architecture Structure of WB_UNIT is

	-- Pipeline Buffers --
	signal	ALU_DATA		: STD_LOGIC_VECTOR(31 downto 0);
	signal	ADR_BUFF		: STD_LOGIC_VECTOR(01 downto 0);

	-- MEM RD Buffer --
	signal	MEM_DATA		: STD_LOGIC_VECTOR(31 downto 0);

	-- Local Signals --
	signal	REG_WB_DATA	: STD_LOGIC_VECTOR(31 downto 0);

begin

	-- Pipeline Registers -----------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		PIPE_REG: process(CLK, RES, XMEM_RD_DATA)
		begin
			--- ALU Data ---
			if rising_edge(CLK) then
				if (RES = '1') then
					ALU_DATA <= (others => '0');
					ADR_BUFF <= (others => '0');
				else
					ALU_DATA <= ALU_DATA_IN;
					ADR_BUFF <= ADR_BUFF_IN(1 downto 0); -- we only need the 2 LSBs
				end if;
			end if;

			--- MEM Data ---
			if (USE_MEM_RD_FF = TRUE) then
				if falling_edge(CLK) then
					if (RES = '1') then
						MEM_DATA <= NOP_CMD; -- "NOP" Instruction
					else
						MEM_DATA <= XMEM_RD_DATA;
					end if;
				end if;
			else
				MEM_DATA <= XMEM_RD_DATA;
			end if;
		end process PIPE_REG;

		--- New Intsruction ---
		INSTR_DAT_OUT <= MEM_DATA;



	-- Write Back Data Selector -----------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		WB_DATA_MUX: process(CTRL_IN, MEM_DATA, ALU_DATA, ADR_BUFF, MEM_DATA)
			variable TEMP        : STD_LOGIC_VECTOR(02 downto 0);
			variable RD_DATA_TMP : STD_LOGIC_VECTOR(31 downto 0);
		begin

			--- Input Data Alignment ---
			TEMP := CTRL_IN(CTRL_MEM_M) & ADR_BUFF;
			case (TEMP) is
				when "000" => -- Word Transfer, word boundary, no offset
					RD_DATA_TMP := MEM_DATA(31 downto 00);
				when "001" => -- Word Transfer, one byte offset
					RD_DATA_TMP := MEM_DATA(07 downto 00) & MEM_DATA(31 downto 08);
				when "010" => -- Word Transfer, two bytes offset
					RD_DATA_TMP := MEM_DATA(15 downto 00) & MEM_DATA(31 downto 16);
				when "011" => -- Word Transfer, three bytes offset
					RD_DATA_TMP := MEM_DATA(23 downto 00) & MEM_DATA(31 downto 24);
				when "100" => -- Byte Transfer, word boundary, no offset
					RD_DATA_TMP := x"000000" & MEM_DATA(07 downto 00);
				when "101" => -- Byte Transfer,one byte offset
					RD_DATA_TMP := x"000000" & MEM_DATA(15 downto 08);
				when "110" => -- Byte Transfer,two bytes offset
					RD_DATA_TMP := x"000000" & MEM_DATA(23 downto 16);
				when "111" => -- Byte Transfer,three bytes offset
					RD_DATA_TMP := x"000000" & MEM_DATA(31 downto 24);
				when others => -- undefined
					RD_DATA_TMP := (others => '-');
			end case;

			--- Write Back Selector ---
			if (CTRL_IN(CTRL_MEM_ACC) = '1') and (CTRL_IN(CTRL_MEM_RW) = '0') then
				REG_WB_DATA <= RD_DATA_TMP; -- Memory read data
			else
				REG_WB_DATA <= ALU_DATA; -- ALU Operation
			end if;
		end process WB_DATA_MUX;

		-- Result Output --
		WB_DATA_OUT <= REG_WB_DATA;



	-- Forwarding Path --------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		WB_FW_OUT(FWD_DATA_MSB downto FWD_DATA_LSB) <= REG_WB_DATA;
		WB_FW_OUT(FWD_RD_MSB  downto  FWD_RD_LSB)   <= CTRL_IN(CTRL_RD_3 downto CTRL_RD_0);
		WB_FW_OUT(FWD_WB)                           <= CTRL_IN(CTRL_EN) and CTRL_IN(CTRL_WB_EN);


end Structure;