-- ######################################################
-- #      < STORM CORE SYSTEM by Stephan Nolting >      #
-- # ************************************************** #
-- #             STORM CORE SYSTEM Testbench            #
-- # ************************************************** #
-- # Version 1.0, 20.07.2011                            #
-- ######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity STORM_TOP_TB is
end STORM_TOP_TB;

architecture Structure of STORM_TOP_TB is

	-- clock/reset --
	signal CLK, RES : STD_LOGIC := '0';

	-- wishbone interface --
	signal WB_DATA_I : std_logic_vector(31 downto 0);
	signal WB_DATA_O : std_logic_vector(31 downto 0);
	signal WB_ADR_O  : std_logic_vector(31 downto 0);
	signal WB_ACK_I  : std_logic;
	signal WB_SEL_O  : std_logic_vector(03 downto 0);
	signal WB_WE_O   : std_logic;
	signal WB_STB_O  : std_logic;
	signal WB_CYC_O  : std_logic;

	-- debug signals --
	signal IN32, OUT32 : std_logic_vector(31 downto 0);

	-- STORM SYSTEM TOP ENTITY --------------------
	-- -----------------------------------------------
	component STORM_TOP
	port	(
				CLK_I       : in  std_logic;
				RST_I       : in  std_logic;
				WB_DATA_I   : in  std_logic_vector(31 downto 0);
				WB_DATA_O   : out std_logic_vector(31 downto 0);
				WB_ADR_O    : out std_logic_vector(31 downto 0);
				WB_ACK_I    : in  std_logic;
				WB_SEL_O    : out std_logic_vector(03 downto 0);
				WB_WE_O     : out std_logic;
				WB_STB_O    : out std_logic;
				WB_CYC_O    : out std_logic;
				MODE_O      : out std_logic_vector(04 downto 0);
				D_ABT_I     : in  std_logic;
				I_ABT_I     : in  std_logic;
				IRQ_I       : in  std_logic;
				FIQ_I       : in  std_logic
			);
	end component;

begin

	-- STORM CORE SYSTEM ----------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		STORM_TOP_INST: STORM_TOP
			port map (
						CLK_I       => CLK,
						RST_I       => RES,
						WB_DATA_I   => WB_DATA_I,
						WB_DATA_O   => WB_DATA_O,
						WB_ADR_O    => WB_ADR_O,
						WB_ACK_I    => WB_ACK_I,
						WB_SEL_O    => WB_SEL_O,
						WB_WE_O     => WB_WE_O,
						WB_STB_O    => WB_STB_O,
						WB_CYC_O    => WB_CYC_O,
						MODE_O      => open,
						D_ABT_I     => '0',
						I_ABT_I     => '0',
						IRQ_I       => '0',
						FIQ_I       => '0'
					);

	-- Clock/Reset Generator ------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		CLK <= not CLK after 20 ns;
		RES <= '1', '0' after 170 ns;


	-- Wishbone simulation --------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
			WB_DATA_I <= (others => '0');
			WB_ACK_I  <= '1';


end Structure;