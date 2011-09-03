-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #             Logical Operation Unit                  #
-- # *************************************************** #
-- # Version 1.5, 18.03.2011                             #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library work;
use work.STORM_core_package.all;

entity LOGICAL_UNIT is
	port	(
				-- Function Operands --
				--------------------------------------------------
				OP_A			: in  STD_LOGIC_VECTOR(31 downto 0);
				OP_B			: in  STD_LOGIC_VECTOR(31 downto 0);
				RESULT		: out STD_LOGIC_VECTOR(31 downto 0);
				
				-- Flag Operands --
				--------------------------------------------------
				BS_CRY_IN	: in  STD_LOGIC;
				BS_OVF_IN	: in  STD_LOGIC;
				L_CARRY_IN	: in  STD_LOGIC;
				FLAG_OUT 	: out STD_LOGIC_VECTOR(03 downto 0);
				
				-- Operation Control --
				--------------------------------------------------
				CTRL			: in  STD_LOGIC_VECTOR(02 downto 0)
			);
end LOGICAL_UNIT;

architecture Behavioral of LOGICAL_UNIT is

	-- local signals --
	signal	RESULT_TMP 		: STD_LOGIC_VECTOR(31 downto 0); -- internal result bus
	signal	TEMP_ZERO		: STD_LOGIC_VECTOR(31 downto 0); -- zero result

begin


	-- Logical Unit ----------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		LOGICAL_CORE: process(CTRL, OP_A, OP_B, L_CARRY_IN)
		begin
			case(LOGICAL_OP & CTRL) is -- ALU_FS

				-- AND: result = OP_A AND OP_B -- 
				when L_AND =>
					RESULT_TMP <= OP_A and OP_B;

				-- OR: result = OP_A OR OP_B --
				when L_OR =>
					RESULT_TMP <= OP_A or OP_B;

				-- XOR: result = OP_A XOR OP_B --
				when L_XOR =>
					RESULT_TMP <= OP_A xor OP_B;

				-- NOT: result = not(OP_A AND OP_B) --
				when L_NOT =>
					if (STORM_MODE = TRUE) then
						RESULT_TMP <= not(OP_A and OP_B);
					else
						RESULT_TMP <= not OP_B; -- ARM_OP: MVN
					end if;

				-- BIC: result = OP_A and (not OP_B) --
				when L_BIC =>
					RESULT_TMP <= OP_A and (not OP_B);

				-- MOV: result = OP_B --
				when L_MOV =>
					RESULT_TMP <= OP_B; -- boring, huh?

				-- TST: result = OP_B, compares by F = OP_A and OP_B --
				when L_TST =>
					RESULT_TMP <= OP_B;
					
				-- TEQ:  result = OP_A, compares by F = OP_A xor OP_B --
				when L_TEQ =>
					RESULT_TMP <= OP_A;
				
				-- Undefined --
				when others =>
					RESULT_TMP <= (others => '0');

			end case;
		end process LOGICAL_CORE;
		
		RESULT <= RESULT_TMP;
	


	-- FLAG Logic ------------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------

		-- carry flag --
		FLAG_OUT(0) <=	BS_CRY_IN when (CTRL = "110") else
							BS_CRY_IN when (CTRL = "111") else L_CARRY_IN;
		
		-- zero flag --
		TEMP_ZERO	<=	(OP_A and OP_B) when (CTRL = "110") else
							(OP_A xor OP_B) when (CTRL = "111") else RESULT_TMP;

		FLAG_OUT(1) <= '1' when (TEMP_ZERO = x"00000000") else '0';
		
		-- negative flag --
		FLAG_OUT(2) <=	(OP_A(31) and OP_B(31)) when (CTRL = "110") else
							(OP_A(31) xor OP_B(31)) when (CTRL = "111") else RESULT_TMP(31);
		
		-- overflow flag --
		FLAG_OUT(3) <=	BS_OVF_IN; -- keep barrelsshifter's overflow flag

	

end Behavioral;