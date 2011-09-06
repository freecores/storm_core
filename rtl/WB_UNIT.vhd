-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #      Data Write Back Selector & MEM Read Input      #
-- # *************************************************** #
-- # Version 1.3, 05.09.2011                             #
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

				CLK           : in  STD_LOGIC; -- global clock network
				G_HALT        : in  STD_LOGIC; -- global halt line
				RES           : in  STD_LOGIC; -- global reset network
				CTRL_IN       : in  STD_LOGIC_VECTOR(31 downto 0); -- stage control

-- ###############################################################################################
-- ##       Operand Connection                                                                  ##
-- ###############################################################################################

				ALU_DATA_IN   : in  STD_LOGIC_VECTOR(31 downto 0); -- alu data input
				ADR_BUFF_IN   : in  STD_LOGIC_VECTOR(31 downto 0); -- alu address input

				WB_DATA_OUT   : out STD_LOGIC_VECTOR(31 downto 0); -- write back data output
				XMEM_RD_DATA  : in  STD_LOGIC_VECTOR(31 downto 0); -- memory data input

-- ###############################################################################################
-- ##       Forwarding Path                                                                     ##
-- ###############################################################################################

				WB_FW_OUT     : out STD_LOGIC_VECTOR(40 downto 0)  -- forwarding data & ctrl

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
				elsif (G_HALT = '0') then
					ALU_DATA <= ALU_DATA_IN;
					ADR_BUFF <= ADR_BUFF_IN(1 downto 0); -- we only need the 2 LSBs
				end if;
			end if;

			--- MEM Data ---
			MEM_DATA <= XMEM_RD_DATA;

		end process PIPE_REG;



	-- Write Back Data Selector -----------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		WB_DATA_MUX: process(CTRL_IN, MEM_DATA, ALU_DATA, ADR_BUFF)
			variable TEMP        : STD_LOGIC_VECTOR(04 downto 00);
			variable ENDIAN_TMP  : STD_LOGIC_VECTOR(31 downto 00);
			variable RD_DATA_TMP : STD_LOGIC_VECTOR(31 downto 00);
		begin

			--- Endianess Converter ---
			if (USE_BIG_ENDIAN = FALSE) then -- Little Endian
				ENDIAN_TMP := MEM_DATA(07 downto 00) & MEM_DATA(15 downto 08) &
                              MEM_DATA(23 downto 16) & MEM_DATA(31 downto 24);
			else -- Big Endian
				ENDIAN_TMP := MEM_DATA(31 downto 24) & MEM_DATA(23 downto 16) &
				              MEM_DATA(15 downto 08) & MEM_DATA(07 downto 00);
			end if;

			--- Input Data Alignment ---
			TEMP := CTRL_IN(CTRL_MEM_DQ_1 downto CTRL_MEM_DQ_0) & ADR_BUFF & CTRL_IN(CTRL_MEM_SE);
			-- TEMP = Quantity(2) & LSB_ADR(2) & Sign_extension(1)
			case (TEMP) is
				-- WORD TRANSFER --
				when "00000" | "00001" => -- word transfer, no offset, SE not possible
					RD_DATA_TMP := ENDIAN_TMP(31 downto 00);
				when "00010" | "00011" => -- word transfer, one byte offset, SE not possible
					RD_DATA_TMP := ENDIAN_TMP(23 downto 00) & ENDIAN_TMP(31 downto 24);
				when "00100" | "00101" => -- word transfer, two bytes offset, SE not possible
					RD_DATA_TMP := ENDIAN_TMP(15 downto 00) & ENDIAN_TMP(31 downto 16);
				when "00110" | "00111" => -- word transfer, three bytes offset, SE not possible
					RD_DATA_TMP := ENDIAN_TMP(07 downto 00) & ENDIAN_TMP(31 downto 08);

				-- BYTE TRANSFER --
				when "01000" => -- byte transfer, no offset, no sign extension
					RD_DATA_TMP := x"000000" & ENDIAN_TMP(07 downto 00);
				when "01001" => -- byte transfer, no offset, sign extension
					RD_DATA_TMP(7 downto 0) := ENDIAN_TMP(07 downto 00);
					for i in 8 to 31 loop
						RD_DATA_TMP(i) := ENDIAN_TMP(07);
					end loop;
				when "01010" => -- byte transfer, one byte offset, no sign extension
					RD_DATA_TMP := x"000000" & ENDIAN_TMP(15 downto 08);
				when "01011" => -- byte transfer, one byte offset, sign extension
					RD_DATA_TMP(7 downto 0) := ENDIAN_TMP(15 downto 08); 
					for i in 8 to 31 loop
						RD_DATA_TMP(i) := ENDIAN_TMP(15);
					end loop;
				when "01100" => -- byte transfer, two bytes offset, no sign extension
					RD_DATA_TMP := x"000000" & ENDIAN_TMP(23 downto 16);
				when "01101" => -- byte transfer, two bytes offset, sign extension
					RD_DATA_TMP(7 downto 0) := ENDIAN_TMP(23 downto 16);
					for i in 8 to 31 loop
						RD_DATA_TMP(i) := ENDIAN_TMP(23);
					end loop;
				when "01110" => -- byte transfer, three bytes offset, no sign extension
					RD_DATA_TMP := x"000000" & ENDIAN_TMP(31 downto 24);
				when "01111" => -- byte transfer, three bytes offset, sign extension
					RD_DATA_TMP(7 downto 0) := ENDIAN_TMP(31 downto 24);
					for i in 8 to 31 loop
						RD_DATA_TMP(i) := ENDIAN_TMP(31);
					end loop;

				-- HALFWORD TRANSFER --
				when "10000" | "11000" => -- halfword transfer, no offset, no sign extension
					RD_DATA_TMP := x"0000" & ENDIAN_TMP(15 downto 00);
				when "10001" | "11001" => -- halfword transfer, no offset, sign extension
					RD_DATA_TMP(15 downto 00) := ENDIAN_TMP(15 downto 00);
					for i in 16 to 31 loop
						RD_DATA_TMP(i) := ENDIAN_TMP(15);
					end loop;
				when "10010" | "11010" => -- halfword transfer, one byte offset, no sign extension
					RD_DATA_TMP := x"0000" & ENDIAN_TMP(23 downto 08);
				when "10011" | "11011" => -- halfword transfer, one byte offset, sign extension
					RD_DATA_TMP(15 downto 00) := ENDIAN_TMP(23 downto 08);
					for i in 16 to 31 loop
						RD_DATA_TMP(i) := ENDIAN_TMP(23);
					end loop;
				when "10100" | "11100" => -- halfword transfer, two bytes offset, no sign extension
					RD_DATA_TMP := x"0000" & ENDIAN_TMP(31 downto 16);
				when "10101" | "11101" => -- halfword transfer, two bytes offset, sign extension
					RD_DATA_TMP(15 downto 00) := ENDIAN_TMP(31 downto 16);
					for i in 16 to 31 loop
						RD_DATA_TMP(i) := ENDIAN_TMP(31);
					end loop;
				when "10110" | "11110" => -- halfword transfer, three bytes offset, no sign extension
					RD_DATA_TMP := x"0000" & ENDIAN_TMP(07 downto 00) & ENDIAN_TMP(31 downto 24);
				when others => -- halfword transfer, three bytes offset, sign extension
					RD_DATA_TMP(15 downto 00) := ENDIAN_TMP(07 downto 00) & ENDIAN_TMP(31 downto 24);
					for i in 16 to 31 loop
						RD_DATA_TMP(i) := ENDIAN_TMP(07);
					end loop;
			end case;

			--- Write Back Selector ---
			if (CTRL_IN(CTRL_MEM_ACC) = '1') and (CTRL_IN(CTRL_MEM_RW) = RD) then
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