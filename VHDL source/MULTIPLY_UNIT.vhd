-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #                Multiplication Unit                  #
-- # *************************************************** #
-- # Version 1.0.0, 19.03.2011                           #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity MULTIPLY_UNIT is
	port	(
				-- Function Operands --
				--------------------------------------------------
				OP_B			: in  STD_LOGIC_VECTOR(31 downto 0);
				OP_C			: in  STD_LOGIC_VECTOR(31 downto 0);
				RESULT		: out STD_LOGIC_VECTOR(31 downto 0);
				
				-- Flag Results --
				--------------------------------------------------
				CARRY_OUT	: out STD_LOGIC;
				OVFL_OUT		: out STD_LOGIC
			);
end MULTIPLY_UNIT;

architecture Behavioral of MULTIPLY_UNIT is

	-- local signals --
	signal	TEMP	: STD_LOGIC_VECTOR(63 downto 0);

begin

	-- Multiplication Unit ---------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		TEMP <= std_logic_vector(unsigned(OP_B) * unsigned(OP_C));

		RESULT <= TEMP(31 downto 0);

		--CARRY_OUT <= '1' when (TEMP(63 downto 32) = x"00000001") else '0';
		--OVFL_OUT  <= '0' when (TEMP(63 downto 33) = (x"0000000" & "000")) else '1';


end Behavioral;