-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- # Load/Store Unit for Data/Instruction Memory Access  #
-- # *************************************************** #
-- # Version 2.5, 14.07.2011                             #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library work;
use work.STORM_core_package.all;

entity LOAD_STORE_UNIT is
port	(
-- ###############################################################################################
-- ##           Global Control                                                                  ##
-- ###############################################################################################

				CLK             : in  STD_LOGIC;
				G_HALT          : in  STD_LOGIC; -- global halt line
				RES             : in  STD_LOGIC;
				CTRL_IN         : in  STD_LOGIC_VECTOR(31 downto 0);

-- ###############################################################################################
-- ##           Operand Connection                                                              ##
-- ###############################################################################################

				MEM_DATA_IN     : in  STD_LOGIC_VECTOR(31 downto 0);
				MEM_ADR_IN      : in  STD_LOGIC_VECTOR(31 downto 0);
				MEM_BP_IN       : in  STD_LOGIC_VECTOR(31 downto 0);
				
				MODE_IN         : in  STD_LOGIC_VECTOR(04 downto 0);

				ADR_OUT         : out STD_LOGIC_VECTOR(31 downto 0);
				BP_OUT          : out STD_LOGIC_VECTOR(31 downto 0);

-- ###############################################################################################
-- ##           Forwarding Path                                                                 ##
-- ###############################################################################################

				LDST_FW_OUT     : out STD_LOGIC_VECTOR(40 downto 0);

-- ###############################################################################################
-- ##           External Memory Interface                                                       ##
-- ###############################################################################################

				XMEM_MODE       : out STD_LOGIC_VECTOR(04 downto 0); -- processor mode for access
				XMEM_ADR        : out STD_LOGIC_VECTOR(31 downto 0); -- Address Output
				XMEM_WR_DTA     : out STD_LOGIC_VECTOR(31 downto 0); -- Data Output
				XMEM_ACC_REQ    : out STD_LOGIC; -- Access Request
				XMEM_RW         : out STD_LOGIC; -- Read/write signal
				XMEM_DQ         : out STD_LOGIC_VECTOR(01 downto 0) -- Data Quantity

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
				elsif (G_HALT = '0') then
					DATA_BUFFER <= MEM_DATA_IN;	-- Memory write data buffer
					ADR_BUFFER  <= MEM_ADR_IN;		-- Memory adress buffer
					BP_BUFFER   <= MEM_BP_IN;		-- Memory bypass buffer
				end if;
			end if;
		end process MEM_BUFFER;
		
		-- Address Output --
		ADR_OUT  <= ADR_BUFFER;

		-- Data MEM Address --
		XMEM_ADR <= ADR_BUFFER;



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
		BP_OUT  <= BP_TEMP;



	-- Forwarding Path ------------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		LDST_FW_OUT(FWD_RD_MSB downto FWD_RD_LSB)     <= CTRL_IN(CTRL_RD_3 downto CTRL_RD_0);
		LDST_FW_OUT(FWD_WB)                           <= CTRL_IN(CTRL_EN) and CTRL_IN(CTRL_WB_EN);
		LDST_FW_OUT(FWD_DATA_MSB downto FWD_DATA_LSB) <= BP_TEMP;



	-- External Memory Interface --------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		MEM_DATA_INTERFACE: process(CTRL_IN, BP_BUFFER, MODE_IN)
			variable OUTPUT_DATA_BUFFER : STD_LOGIC_VECTOR(31 downto 0);
			variable ENDIAN_TMP         : STD_LOGIC_VECTOR(31 downto 0);
		begin
			--- Output Data Alignment ---
			case (CTRL_IN(CTRL_MEM_DQ_1 downto CTRL_MEM_DQ_0)) is
				when DQ_WORD => -- Word Transfer
					OUTPUT_DATA_BUFFER := BP_BUFFER;
				when DQ_BYTE => -- Byte Transfer
					OUTPUT_DATA_BUFFER := BP_BUFFER(07 downto 00) & BP_BUFFER(07 downto 00) &
					                      BP_BUFFER(07 downto 00) & BP_BUFFER(07 downto 00);
				when others => -- Halfword Transfer
					OUTPUT_DATA_BUFFER := BP_BUFFER(15 downto 00) & BP_BUFFER(15 downto 00);
			end case;

			--- Endianess Converter ---
			if (USE_BIG_ENDIAN = FALSE) then -- Little Endian
				ENDIAN_TMP := OUTPUT_DATA_BUFFER(07 downto 00) & OUTPUT_DATA_BUFFER(15 downto 08) &
				              OUTPUT_DATA_BUFFER(23 downto 16) & OUTPUT_DATA_BUFFER(31 downto 24);
			else -- Big Endian
				ENDIAN_TMP := OUTPUT_DATA_BUFFER(31 downto 24) & OUTPUT_DATA_BUFFER(23 downto 16) &
				              OUTPUT_DATA_BUFFER(15 downto 08) & OUTPUT_DATA_BUFFER(07 downto 00);
			end if;

			--- D-MEM Interface ---
			XMEM_WR_DTA  <= ENDIAN_TMP;
			XMEM_RW      <= CTRL_IN(CTRL_MEM_RW); -- Read/Write
			XMEM_DQ      <= CTRL_IN(CTRL_MEM_DQ_1 downto CTRL_MEM_DQ_0);  -- Data Quantity
			XMEM_ACC_REQ <= CTRL_IN(CTRL_EN) and CTRL_IN(CTRL_MEM_ACC);

			--- Mode for MEM access --
			if (CTRL_IN(CTRL_MEM_USER) = '1') then
				XMEM_MODE <= User32_MODE; -- force user_mode
			else
				XMEM_MODE <= MODE_IN; -- current processor mode
			end if;

		end process MEM_DATA_INTERFACE;


end LOAD_STORE_UNIT_STRUCTURE;