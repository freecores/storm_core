-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #             Arithmetical Operation Unit             #
-- # *************************************************** #
-- # Version 1.5.0, 19.03.2011                           #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity ARITHMETICAL_UNIT is
	port	(
				-- Function Operands --
				--------------------------------------------------
				OP_A			: in  STD_LOGIC_VECTOR(31 downto 00);
				OP_B			: in  STD_LOGIC_VECTOR(31 downto 00);
				RESULT		: out STD_LOGIC_VECTOR(31 downto 00);
				
				-- Flag Operands --
				--------------------------------------------------
				BS_OVF_IN	: in  STD_LOGIC;
				A_CARRY_IN	: in  STD_LOGIC;
				FLAG_OUT	 	: out STD_LOGIC_VECTOR(03 downto 00);
				
				-- Operation Control --
				--------------------------------------------------
				CTRL			: in  STD_LOGIC_VECTOR(02 downto 00)
			);
end ARITHMETICAL_UNIT;

architecture Behavioral of ARITHMETICAL_UNIT is

	-- local signals --
	signal	ADD_MODE		: STD_LOGIC_VECTOR(02 downto 00); -- adder mode control
	signal	ADDER_RES	: STD_LOGIC_VECTOR(32 downto 00); -- adder/subtractor result
	signal	CARRY_OUT	: STD_LOGIC;							-- internal carry output
	

begin

	-- Arithmetical Unit -----------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		ARITHMETICAL_CORE: process(CTRL, ADDER_RES, OP_A, OP_B)
		begin
			case(ARITHMETICAL_OP & CTRL) is -- Arithmetic Function Set

				-- ADD: result = OP_A + OP_B --
				when A_ADD =>
					ADD_MODE  <= "000";
					RESULT    <= ADDER_RES(31 downto 0);

				-- ADC: result = OP_A + OP_B + Carry-Flag --
				when A_ADC =>
					ADD_MODE  <= "100";
					RESULT    <= ADDER_RES(31 downto 0);

				-- SUB: result = OP_A - OP_B --
				when A_SUB =>
					ADD_MODE  <= "001";
					RESULT    <= ADDER_RES(31 downto 0);

				-- SBC: result = OP_A - OP_B - Carry-Flag --
				when A_SBC =>
					ADD_MODE  <= "101";
					RESULT    <= ADDER_RES(31 downto 0);

				-- RSB: result = OP_B - OP_A --
				when A_RSB =>
					ADD_MODE  <= "010";
					RESULT    <= ADDER_RES(31 downto 0);

				-- RSC: result = OP_B - OP_A - Carry-Flag --
				when A_RSC =>
					ADD_MODE  <= "110";
					RESULT    <= ADDER_RES(31 downto 0);

				-- CMP: result = OP_B, compares by F = OP_A - OP_B --
				when A_CMP =>
					ADD_MODE  <= "001";
					RESULT    <= OP_B;

				-- CMN: result = OP_A, compares by F = OP_A + OP_B --
				when A_CMN =>
					ADD_MODE  <= "000";
					RESULT    <= OP_A;
				
				-- Undefined --
				when others =>
					ADD_MODE	 <= (others => '0');
					RESULT    <= (others => '0');

			end case;
		end process ARITHMETICAL_CORE;



	-- Adder/Subtractor ------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		ADDER_SUBTRACTOR: process(ADD_MODE, OP_A, OP_B, A_CARRY_IN, ADDER_RES)
			variable ADDER_A, ADDER_B : std_logic_vector(32 downto 00);
			variable CARRY_IN         : std_logic_vector(00 downto 00);
		begin
			ADDER_A(32) := '0';
			ADDER_B(32) := '0';
			case (ADD_MODE(1 downto 0)) is
			
				when "00" => -- (+OP_A) + (+OP_B)
					ADDER_A(31 downto 0) := OP_A;
					ADDER_B(31 downto 0) := OP_B;
					
				when "01" => -- (+OP_A) + (-OP_B)
					ADDER_A(31 downto 0) := OP_A;
					ADDER_B(31 downto 0) := not OP_B;
					
				when "10" => -- (-OP_A) + (+OP_B)
					ADDER_A(31 downto 0) := not OP_A;
					ADDER_B(31 downto 0) := OP_B;

				when others => -- invalid
					ADDER_A(32 downto 0) := (others => '-');
					ADDER_B(32 downto 0) := (others => '-');

			end case;

			-- carry input logic --
			CARRY_IN(0) := (ADD_MODE(2) and A_CARRY_IN) xor (ADD_MODE(0) or ADD_MODE(1));
			
			-- adder/subtractor --
			ADDER_RES <= std_logic_vector(unsigned(ADDER_A) + unsigned(ADDER_B) + unsigned(CARRY_IN(0 downto 0)));
			
			-- carry output logic --
			CARRY_OUT <= ADDER_RES(32) xor (ADD_MODE(0) or ADD_MODE(1));

		end process ADDER_SUBTRACTOR;

	
	
	-- FLAG Logic ------------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		-- carry flag --
		FLAG_OUT(0) <=	CARRY_OUT;

		-- zero flag --
		FLAG_OUT(1) <= '1' when (ADDER_RES(31 downto 0) =  x"00000000") else '0';

		-- negative flag --
		FLAG_OUT(2) <= ADDER_RES(31); -- negative flag
		
		-- overflow flag --
		FLAG_OUT(3) <= (ADDER_RES(31) and (OP_A(31) xnor OP_B(31)));-- or BS_OVF_IN;


end Behavioral;