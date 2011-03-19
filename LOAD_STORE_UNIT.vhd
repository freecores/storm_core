-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #       Load/Store Unit for Data Memory Access        #
-- # *************************************************** #
-- # Version 2.3, 18.03.2011                             #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library work;
use work.STORM_core_package.all;

entity LOAD_STORE_UNIT is
port	(
-- ###############################################################################################
-- ##			Global Control                                                                      ##
-- ###############################################################################################

				CLK				: in  STD_LOGIC;
				RES				: in  STD_LOGIC;
				CTRL_IN			: in  STD_LOGIC_VECTOR(31 downto 0);

-- ###############################################################################################
-- ##			Operand Connection                                                                  ##
-- ###############################################################################################

				MEM_DATA_IN		: in  STD_LOGIC_VECTOR(31 downto 0);
				MEM_ADR_IN		: in  STD_LOGIC_VECTOR(31 downto 0);
				MEM_BP_IN		: in  STD_LOGIC_VECTOR(31 downto 0);
				
				DATA_OUT			: out STD_LOGIC_VECTOR(31 downto 0);
				BP_OUT			: out STD_LOGIC_VECTOR(31 downto 0);
				
-- ###############################################################################################
-- ##			Forwarding Path                                                                     ##
-- ###############################################################################################

				LDST_FW_OUT	: out STD_LOGIC_VECTOR(36 downto 0);

-- ###############################################################################################
-- ##			External Memory Interface                                                           ##
-- ###############################################################################################

				XMEM_ADR			: out STD_LOGIC_VECTOR(31 downto 0);
				XMEM_RD_DTA		: in  STD_LOGIC_VECTOR(31 downto 0);
				XMEM_WR_DTA		: out STD_LOGIC_VECTOR(31 downto 0);
				XMEM_WE			: out STD_LOGIC;
				XMEM_MODE		: out STD_LOGIC
				
		);
end LOAD_STORE_UNIT;


architecture LOAD_STORE_UNIT_STRUCTURE of LOAD_STORE_UNIT is

	-- local signals --
	signal	DATA_BUFFER	: STD_LOGIC_VECTOR(31 downto 0);
	signal	ADR_BUFFER	: STD_LOGIC_VECTOR(31 downto 0);
	signal	BP				: STD_LOGIC_VECTOR(31 downto 0);

begin

	-- Pipeline-Buffers -----------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		MEM_BUFFER: process(CLK, RES)
		begin
			if rising_edge(CLK) then
				if (RES = '1') then
					DATA_BUFFER <= (others => '0');
					ADR_BUFFER  <= (others => '0');
					BP			   <= (others => '0');
				else
					DATA_BUFFER <= MEM_DATA_IN;	-- Memory write data buffer
					ADR_BUFFER  <= MEM_ADR_IN;		-- Memory adress buffer
					BP			   <= MEM_BP_IN;		-- Memory bypass buffer
				end if;
			end if;
		end process MEM_BUFFER;


	-- Forwarding CTRL Path -------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		LDST_FW_OUT(FWD_RD_3 downto FWD_RD_0) <= CTRL_IN(CTRL_RD_3 downto CTRL_RD_0);
		LDST_FW_OUT(FWD_WB) <= CTRL_IN(CTRL_EN) and CTRL_IN(CTRL_WB_EN);


	-- Forwarding Data Path -------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		MEM_FORWARD_MUX: process(CTRL_IN(CTRL_MEM_ACC), CTRL_IN(CTRL_MEM_RW))
		begin
			-- memory read access
			if (CTRL_IN(CTRL_MEM_ACC) = '1') and (CTRL_IN(CTRL_MEM_RW) = '0') then
				LDST_FW_OUT(FWD_DATA_MSB downto FWD_DATA_LSB) <= XMEM_RD_DTA;
			else -- register/mcr read access
				LDST_FW_OUT(FWD_DATA_MSB downto FWD_DATA_LSB) <= BP;
			end if;
		end process MEM_FORWARD_MUX;
	

	-- Output Data Alignment ------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		WRITE_DATA_ALIGN: process(CTRL_IN(CTRL_MEM_M), DATA_BUFFER)
		begin
			if (CTRL_IN(CTRL_MEM_M) = '0') then -- Word Transfer
				XMEM_WR_DTA <= DATA_BUFFER;
			else -- Byte Transfer
				XMEM_WR_DTA <= DATA_BUFFER(7 downto 0) & DATA_BUFFER(7 downto 0) &
									DATA_BUFFER(7 downto 0) & DATA_BUFFER(7 downto 0);
			end if;
		end process WRITE_DATA_ALIGN;


	-- Input Data Alignment -------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		READ_DATA_ALIGN: process(CTRL_IN(CTRL_MEM_M), ADR_BUFFER(1 downto 0), XMEM_RD_DTA)
			variable BYTE_OUT_TMP : STD_LOGIC_VECTOR(07 downto 0);
			variable WORD_OUT_TMP : STD_LOGIC_VECTOR(31 downto 0);
		begin

			case (ADR_BUFFER(1 downto 0)) is
				when "00" => -- word boundary
					WORD_OUT_TMP := XMEM_RD_DTA; -- not implemented yet, doing word transfer now
					BYTE_OUT_TMP := XMEM_RD_DTA(07 downto 00);
				when "01" => -- one byte offset
					WORD_OUT_TMP := XMEM_RD_DTA; -- not implemented yet, doing word transfer now
					BYTE_OUT_TMP := XMEM_RD_DTA(15 downto 08);
				when "10" => -- two bytes offset
					WORD_OUT_TMP := XMEM_RD_DTA; -- not implemented yet, doing word transfer now
					BYTE_OUT_TMP := XMEM_RD_DTA(23 downto 16);
				when "11" => -- three bytes offset
					WORD_OUT_TMP := XMEM_RD_DTA; -- not implemented yet, doing word transfer now
					BYTE_OUT_TMP := XMEM_RD_DTA(31 downto 24);
				when others => -- undefined
					WORD_OUT_TMP := (others => '-');
					BYTE_OUT_TMP := (others => '-');
			end case;


			if (CTRL_IN(CTRL_MEM_M) = '0') then -- Word Transfer
				DATA_OUT <= WORD_OUT_TMP;
			else -- Byte Transfer
				DATA_OUT <= x"000000" & BYTE_OUT_TMP; -- fill with zeros
			end if;

		end process READ_DATA_ALIGN;


	-- External Memory Control Interface ------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		-- write enable --
		XMEM_WE   <= CTRL_IN(CTRL_EN) and CTRL_IN(CTRL_MEM_ACC) and CTRL_IN(CTRL_MEM_RW);
		
		-- byte/word transfer --
		XMEM_MODE <= CTRL_IN(CTRL_MEM_M);
		
		-- address word --
		XMEM_ADR  <= ADR_BUFFER;


	-- Bypass Output --------------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		BP_OUT <= BP;



end LOAD_STORE_UNIT_STRUCTURE;