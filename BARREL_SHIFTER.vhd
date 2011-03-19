-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #              Barrelshifter Unit                     #
-- # *************************************************** #
-- # Version 1.2, 14.01.2011                             #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity BARREL_SHIFTER is
	port	(
				-- Function Operands --
				----------------------------------------------------
				SHIFT_DATA_IN	: in  STD_LOGIC_VECTOR(31 downto 0);
				SHIFT_DATA_OUT	: out STD_LOGIC_VECTOR(31 downto 0);
				
				-- Flag Operands --
				----------------------------------------------------
				CARRY_IN			: in  STD_LOGIC;
				CARRY_OUT		: out STD_LOGIC;
				OVERFLOW_OUT	: out STD_LOGIC;
				
				-- Operation Control --
				----------------------------------------------------
				SHIFT_MODE		: in  STD_LOGIC_VECTOR(01 downto 0);
				SHIFT_POS		: in  STD_LOGIC_VECTOR(04 downto 0)
			);
end BARREL_SHIFTER;

architecture Structure of BARREL_SHIFTER is

	signal	SHIFT_DATA : STD_LOGIC_VECTOR(31 downto 0);

begin

	-- Barrelshifter ---------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		BARREL_SHIFTER: process(SHIFT_MODE, SHIFT_POS, SHIFT_DATA_IN, CARRY_IN)
			variable shift_positions : integer;
		begin
			shift_positions := to_integer(unsigned(SHIFT_POS));
			case (SHIFT_MODE) is
				when S_LSL   => -- Logical Shift Left
					if (shift_positions = 0) then -- no shift, keep carry
						SHIFT_DATA <= SHIFT_DATA_IN;
						CARRY_OUT  <= CARRY_IN;
					else -- LSL #shift_positions
						SHIFT_DATA <= to_StdLogicVector(to_BitVector(SHIFT_DATA_IN) sll shift_positions);
						CARRY_OUT  <= SHIFT_DATA_IN(32 - shift_positions);
					end if;

				when S_LSR   => -- Logical Shift Right
					if (shift_positions = 0) then -- LSR #32
						SHIFT_DATA <= to_StdLogicVector(to_BitVector(SHIFT_DATA_IN) srl 32);
						CARRY_OUT  <= SHIFT_DATA_IN(31);
					else -- LSR #shift_positions
						SHIFT_DATA <= to_StdLogicVector(to_BitVector(SHIFT_DATA_IN) srl shift_positions);
						CARRY_OUT  <= SHIFT_DATA_IN(shift_positions - 1);
					end if;

				when S_ASR   => -- Arithmetical Shift Right
					if (shift_positions = 0) then -- ASR #32
						SHIFT_DATA <= to_StdLogicVector(to_BitVector(SHIFT_DATA_IN) sra 32);
						CARRY_OUT  <= SHIFT_DATA_IN(31);
					else -- ASR #shift_positions
						SHIFT_DATA <= to_StdLogicVector(to_BitVector(SHIFT_DATA_IN) sra shift_positions);
						CARRY_OUT  <= SHIFT_DATA_IN(shift_positions - 1);
					end if;
					
				when S_ROR => -- Rotate Right (Extended)
					if (shift_positions = 0) then -- RRX = ROR #1 and fill with carry flag
						SHIFT_DATA <= CARRY_IN & SHIFT_DATA_IN(31 downto 1); -- fill with carry flag
						CARRY_OUT  <= SHIFT_DATA_IN(0);
					else -- ROR #shift_positions
						SHIFT_DATA <= to_StdLogicVector(to_BitVector(SHIFT_DATA_IN) ror shift_positions);
						CARRY_OUT  <= SHIFT_DATA_IN(shift_positions - 1);
					end if;

				when others => -- undefined
					SHIFT_DATA_OUT <= (others => '-');
					CARRY_OUT      <= '-';
			end case;
			
			if (STORM_MODE = TRUE) then -- use cool overflow feature
				if (SHIFT_MODE = S_LSL) then -- overflow detection
					OVERFLOW_OUT <= SHIFT_DATA_IN(31) xor SHIFT_DATA(31);
				else
					OVERFLOW_OUT <= '0';
				end if;
			else
				OVERFLOW_OUT <= '0';
			end if;
			
		end process BARREL_SHIFTER;
		
		SHIFT_DATA_OUT <= SHIFT_DATA;


end Structure;