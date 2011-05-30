-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- # Load/Store Unit for Data/Instruction Memory Access  #
-- # *************************************************** #
-- # Version 2.4, 17.04.2011, Little Endian Access       #
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

				ADR_OUT			: out STD_LOGIC_VECTOR(31 downto 0);
				BP_OUT			: out STD_LOGIC_VECTOR(31 downto 0);

				INSTR_ADR_IN	: in  STD_LOGIC_VECTOR(31 downto 0);

-- ###############################################################################################
-- ##			Forwarding Path                                                                     ##
-- ###############################################################################################

				LDST_FW_OUT		: out STD_LOGIC_VECTOR(40 downto 0);

-- ###############################################################################################
-- ##			External Memory Interface                                                           ##
-- ###############################################################################################

				XMEM_ADR			: out STD_LOGIC_VECTOR(31 downto 0); -- Address Output
				XMEM_WR_DTA		: out STD_LOGIC_VECTOR(31 downto 0); -- Data Output
				XMEM_WE			: out STD_LOGIC; -- Write Enable
				XMEM_RW			: out STD_LOGIC; -- Read/write signal
				XMEM_BW			: out STD_LOGIC; -- Byte/Word Quantity
				XMEM_OPC			: out STD_LOGIC; -- Instruction/Data fetch
				XMEM_LOCK		: out STD_LOGIC  -- Locked Memory Access

		);
end LOAD_STORE_UNIT;

architecture LOAD_STORE_UNIT_STRUCTURE of LOAD_STORE_UNIT is

	-- Pipeline Regs --
	signal	DATA_BUFFER	: STD_LOGIC_VECTOR(31 downto 0);
	signal	ADR_BUFFER	: STD_LOGIC_VECTOR(31 downto 0);
	signal	BP_BUFFER	: STD_LOGIC_VECTOR(31 downto 0);

	-- Local Signals --
	signal	BP_TEMP		: STD_LOGIC_VECTOR(31 downto 0);

begin

	-- Pipeline-Buffers -----------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		MEM_BUFFER: process(CLK, RES)
		begin
			if rising_edge(CLK) then
				if (RES = '1') then
					DATA_BUFFER <= (others => '0');
					ADR_BUFFER  <= (others => '0');
					BP_BUFFER   <= (others => '0');
				else
					DATA_BUFFER <= MEM_DATA_IN;	-- Memory write data buffer
					ADR_BUFFER  <= MEM_ADR_IN;		-- Memory adress buffer
					BP_BUFFER   <= MEM_BP_IN;		-- Memory bypass buffer
				end if;
			end if;
		end process MEM_BUFFER;
		
		-- Address Output --
		ADR_OUT <= ADR_BUFFER;



	-- Bypass Multiplexer ---------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		BP_MUX: process(CTRL_IN, BP_BUFFER, DATA_BUFFER)
		begin
			if (CTRL_IN(CTRL_LINK) = '0') then
				BP_TEMP <= DATA_BUFFER;
			else
				BP_TEMP <= BP_BUFFER;
			end if;
		end process BP_MUX;

		-- Stage Bypass Output --
		BP_OUT <= BP_TEMP;



	-- Forwarding Path ------------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		LDST_FW_OUT(FWD_RD_MSB downto FWD_RD_LSB)     <= CTRL_IN(CTRL_RD_3 downto CTRL_RD_0);
		LDST_FW_OUT(FWD_WB)                           <= CTRL_IN(CTRL_EN) and CTRL_IN(CTRL_WB_EN);
		LDST_FW_OUT(FWD_DATA_MSB downto FWD_DATA_LSB) <= BP_TEMP;



	-- External Memory Interface --------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		MEM_DATA_INTERFACE: process(CLK, RES, CTRL_IN, BP_BUFFER, ADR_BUFFER, INSTR_ADR_IN)
			variable OUTPUT_DATA_BUFFER : STD_LOGIC_VECTOR(31 downto 0);
		begin

			--- DATA/INSTR Selector ---
			if ((CTRL_IN(CTRL_EN) and CTRL_IN(CTRL_MEM_ACC)) = '1') then
				XMEM_ADR  <= ADR_BUFFER;           -- Data Address
				XMEM_OPC  <= '0';                  -- Data Fetch
				XMEM_RW   <= CTRL_IN(CTRL_MEM_RW); -- Read/Write
				XMEM_BW   <= CTRL_IN(CTRL_MEM_M);  -- Data Quantity
				XMEM_LOCK <= '0';
			else
				XMEM_ADR  <= INSTR_ADR_IN; -- Instruction Address
				XMEM_OPC  <= '1';          -- Instruction Fetch
				XMEM_RW   <= '0';          -- Read Access
				XMEM_BW   <= '0';          -- Word Quantity
				XMEM_LOCK <= '0';          -- not implemented yet
			end if;

			--- Output Data Alignment ---
			if (CTRL_IN(CTRL_MEM_M) = '0') then -- Word Transfer
				OUTPUT_DATA_BUFFER := BP_BUFFER;
			else -- Byte Transfer
				OUTPUT_DATA_BUFFER := BP_BUFFER(7 downto 0) & BP_BUFFER(7 downto 0) &
											 BP_BUFFER(7 downto 0) & BP_BUFFER(7 downto 0);
			end if;

			--- Synchronized Data & Ctrl ---
			if falling_edge(CLK) then
				if (RES = '1') then
					XMEM_WR_DTA <= (others => '0'); -- write data ouput
					XMEM_WE     <= '0'; -- data write enable
				else
					XMEM_WR_DTA <= OUTPUT_DATA_BUFFER;
					XMEM_WE     <= CTRL_IN(CTRL_EN) and CTRL_IN(CTRL_MEM_ACC) and CTRL_IN(CTRL_MEM_RW);
				end if;
			end if;

		end process MEM_DATA_INTERFACE;


end LOAD_STORE_UNIT_STRUCTURE;