-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #      Operand Fetch & Data Dependency Detector       #
-- # *************************************************** #
-- # Version 2.4.5, 07.09.2011                           #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity OPERAND_UNIT is
	port	(
-- ###############################################################################################
-- ##           Global Control                                                                  ##
-- ###############################################################################################

				CTRL_IN         : in  STD_LOGIC_VECTOR(31 downto 0); -- control lines
				OP_ADR_IN       : in  STD_LOGIC_VECTOR(14 downto 0); -- operand addresses from decoder

-- ###############################################################################################
-- ##           Operand Connection                                                              ##
-- ###############################################################################################

				OP_A_IN         : in  STD_LOGIC_VECTOR(31 downto 0); -- operand A reg_file output
				OP_B_IN         : in  STD_LOGIC_VECTOR(31 downto 0); -- operant B reg_file output
				OP_C_IN         : in  STD_LOGIC_VECTOR(31 downto 0); -- operant C reg_file output
				SHIFT_VAL_IN    : in  STD_LOGIC_VECTOR(04 downto 0); -- immediate shift value
				REG_PC_IN       : in  STD_LOGIC_VECTOR(31 downto 0); -- PC value for manual access
				JMP_PC_IN       : in  STD_LOGIC_VECTOR(31 downto 0); -- PC value for branches
				LNK_PC_IN       : in  STD_LOGIC_VECTOR(31 downto 0); -- PC value for linking
				IMM_IN          : in  STD_LOGIC_VECTOR(31 downto 0); -- immediate data input

				OP_A_OUT        : out STD_LOGIC_VECTOR(31 downto 0); -- new operand A
				OP_B_OUT        : out STD_LOGIC_VECTOR(31 downto 0); -- new operant B
				SHIFT_VAL_OUT   : out STD_LOGIC_VECTOR(04 downto 0); -- new shift value
				BP1_OUT         : out STD_LOGIC_VECTOR(31 downto 0); -- new operant C (BP)

				HOLD_BUS_OUT    : out STD_LOGIC_VECTOR(02 downto 0); -- cycle control
				
-- ###############################################################################################
-- ##           Forwarding Paths                                                                ##
-- ###############################################################################################

				MSU_FW_IN       : in  STD_LOGIC_VECTOR(39 downto 0); -- msu forwarding data & ctrl
				ALU_FW_IN       : in  STD_LOGIC_VECTOR(39 downto 0); -- alu forwarding data & ctrl
				MEM_FW_IN       : in  STD_LOGIC_VECTOR(39 downto 0); -- memory forwarding data & ctrl
				WB_FW_IN        : in  STD_LOGIC_VECTOR(39 downto 0)  -- write back forwaring data & ctrl

			);
end OPERAND_UNIT;

architecture OPERAND_UNIT_STRUCTURE of OPERAND_UNIT is

	-- Local Signals --
	signal	OP_A, OP_B, OP_C : STD_LOGIC_VECTOR(31 downto 0);
	
	-- Address Match --
	signal	MSU_A_MATCH, MSU_B_MATCH, MSU_C_MATCH : STD_LOGIC;
	signal	ALU_A_MATCH, ALU_B_MATCH, ALU_C_MATCH : STD_LOGIC;
	signal	MEM_A_MATCH, MEM_B_MATCH, MEM_C_MATCH : STD_LOGIC;
	signal	WB_A_MATCH,  WB_B_MATCH,  WB_C_MATCH  : STD_LOGIC;
	signal	MSU_MATCH,   ALU_MATCH,   MEM_MATCH   : STD_LOGIC;

begin

	-- Address Match Detector --------------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
		ADR_MATCH: process(OP_ADR_IN, MSU_FW_IN, ALU_FW_IN, MEM_FW_IN, WB_FW_IN, CTRL_IN(CTRL_EN))
		begin

			--- Default Values ---
			MSU_A_MATCH <= '0'; MSU_B_MATCH <= '0'; MSU_C_MATCH <= '0';
			ALU_A_MATCH <= '0'; ALU_B_MATCH <= '0'; ALU_C_MATCH <= '0';
			MEM_A_MATCH <= '0'; MEM_B_MATCH <= '0'; MEM_C_MATCH <= '0';
			WB_A_MATCH  <= '0'; WB_B_MATCH  <= '0'; WB_C_MATCH  <= '0';
		
			--- Multiply/Shift Unit ---
			if (OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = MSU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB)) and (OP_ADR_IN(OP_A_IS_REG) = '1') then
				MSU_A_MATCH <= MSU_FW_IN(FWD_WB) and CTRL_IN(CTRL_EN);
			end if;
			if (OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = MSU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB)) and (OP_ADR_IN(OP_B_IS_REG) = '1') then
				MSU_B_MATCH <= MSU_FW_IN(FWD_WB) and CTRL_IN(CTRL_EN);
			end if;
			if (OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = MSU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB)) and (OP_ADR_IN(OP_C_IS_REG) = '1') then
				MSU_C_MATCH <= MSU_FW_IN(FWD_WB) and CTRL_IN(CTRL_EN);
			end if;

			--- Arithmetical/Logical Unit ---
			if (OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = ALU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB)) and (OP_ADR_IN(OP_A_IS_REG) = '1') then
				ALU_A_MATCH <= ALU_FW_IN(FWD_WB) and CTRL_IN(CTRL_EN);
			end if;
			if (OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = ALU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB)) and (OP_ADR_IN(OP_B_IS_REG) = '1') then
				ALU_B_MATCH <= ALU_FW_IN(FWD_WB) and CTRL_IN(CTRL_EN);
			end if;
			if (OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = ALU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB)) and (OP_ADR_IN(OP_C_IS_REG) = '1') then
				ALU_C_MATCH <= ALU_FW_IN(FWD_WB) and CTRL_IN(CTRL_EN);
			end if;

			--- Memory-Access Unit ---
			if (OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = MEM_FW_IN(FWD_RD_MSB downto FWD_RD_LSB)) and (OP_ADR_IN(OP_A_IS_REG) = '1') then
				MEM_A_MATCH <= MEM_FW_IN(FWD_WB) and CTRL_IN(CTRL_EN);
			end if;
			if (OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = MEM_FW_IN(FWD_RD_MSB downto FWD_RD_LSB)) and (OP_ADR_IN(OP_B_IS_REG) = '1') then
				MEM_B_MATCH <= MEM_FW_IN(FWD_WB) and CTRL_IN(CTRL_EN);
			end if;
			if (OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = MEM_FW_IN(FWD_RD_MSB downto FWD_RD_LSB)) and (OP_ADR_IN(OP_C_IS_REG) = '1') then
				MEM_C_MATCH <= MEM_FW_IN(FWD_WB) and CTRL_IN(CTRL_EN);
			end if;

			--- Write Back Unit ---
			if (OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = WB_FW_IN( FWD_RD_MSB downto FWD_RD_LSB)) and (OP_ADR_IN(OP_A_IS_REG) = '1') then
				WB_A_MATCH  <= WB_FW_IN(FWD_WB) and CTRL_IN(CTRL_EN);
			end if;
			if (OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = WB_FW_IN( FWD_RD_MSB downto FWD_RD_LSB)) and (OP_ADR_IN(OP_B_IS_REG) = '1') then
				WB_B_MATCH  <= WB_FW_IN(FWD_WB) and CTRL_IN(CTRL_EN);
			end if;
			if (OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = WB_FW_IN( FWD_RD_MSB downto FWD_RD_LSB)) and (OP_ADR_IN(OP_C_IS_REG) = '1') then
				WB_C_MATCH  <= WB_FW_IN(FWD_WB) and CTRL_IN(CTRL_EN);
			end if;
		
		end process ADR_MATCH;



	-- Local Data Dependency Detector & Forwarding Unit ------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
		LOCAL_DATA_DEPENDENCE_DETECTOR: process(CTRL_IN, ALU_FW_IN, MEM_FW_IN, ALU_A_MATCH, ALU_B_MATCH,
		                                        ALU_C_MATCH, MEM_A_MATCH, MEM_B_MATCH, MEM_C_MATCH, WB_A_MATCH,
		                                        WB_B_MATCH, WB_C_MATCH, WB_FW_IN, OP_A_IN, OP_B_IN, OP_C_IN)
			variable LDD_A, LDD_B, LDD_C : std_logic_vector(2 downto 0);
		begin
			-- Forward OP_X from EX/MEM/WB-stage if source and destination addresses are equal
			-- and if the the instruction in the corresponding stage will perform a valid data write back.
			-- Data from early stages have higher priority than data from later stages.

			--- LOCAL DATA DEPENDENCY FOR OPERANT A ---------------------
			----------------------------------------------------------------
			LDD_A := ALU_A_MATCH & MEM_A_MATCH & WB_A_MATCH;
			case LDD_A is
				when "100" | "101" | "110" | "111" =>
					OP_A <= ALU_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
				when "010" | "011" =>
					OP_A <= MEM_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
				when "001" =>
					OP_A <= WB_FW_IN( FWD_DATA_MSB downto FWD_DATA_LSB);
				when others => -- "000"
					OP_A <= OP_A_IN;
			end case;

			--- LOCAL DATA DEPENDENCY FOR OPERANT B ---------------------
			----------------------------------------------------------------
			LDD_B := ALU_B_MATCH & MEM_B_MATCH & WB_B_MATCH;
			case LDD_B is
				when "100" | "101" | "110" | "111" =>
					OP_B <= ALU_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
				when "010" | "011" =>
					OP_B <= MEM_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
				when "001" =>
					OP_B <= WB_FW_IN( FWD_DATA_MSB downto FWD_DATA_LSB);
				when others => -- "000"
					OP_B <= OP_B_IN;
			end case;

			--- LOCAL DATA DEPENDENCY FOR OPERANT C ---------------------
			----------------------------------------------------------------
			LDD_C := ALU_C_MATCH & MEM_C_MATCH & WB_C_MATCH;
			case LDD_C is
				when "100" | "101" | "110" | "111" =>
					OP_C <= ALU_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
				when "010" | "011" =>
					OP_C <= MEM_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
				when "001" =>
					OP_C <= WB_FW_IN( FWD_DATA_MSB downto FWD_DATA_LSB);
				when others => -- "000"
					OP_C <= OP_C_IN;
			end case;

	end process LOCAL_DATA_DEPENDENCE_DETECTOR;



	-- Address Match Detector For ANY Match ------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
		MSU_MATCH <= MSU_A_MATCH or MSU_B_MATCH or MSU_C_MATCH;
		ALU_MATCH <= ALU_A_MATCH or ALU_B_MATCH or ALU_C_MATCH;
		MEM_MATCH <= MEM_A_MATCH or MEM_B_MATCH or MEM_C_MATCH;


	-- Temporal Data Dependency Detector ---------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
		TEMPORAL_DDD: process(MSU_MATCH, ALU_MATCH, MSU_FW_IN, ALU_FW_IN, MEM_FW_IN, MEM_MATCH)
		begin
			-- Data conflicts that cannot be solved by forwarding = Temporal Data Dependencies
			-- -> Pipeline Stalls & Bubbles needed
			-- Early stages have higher priority than later ones!

			-- MSU_MATCH (REG/FLAG) => 1 cycle(s) HALT_IF
			-- ALU_MATCH and mem_r  => 2 cycle(s) HALT_IF
			-- MSU_MATCH and mem_r  => 3 cycle(s) HALT_IF
			
			-- Normal Operation default
			HOLD_BUS_OUT(2 downto 1) <= "00"; -- 0
			HOLD_BUS_OUT(0)          <= '0';  -- disable

			if (MSU_MATCH = '1') or (MSU_FW_IN(FWD_CY_NEED) = '1') then
			-- MS Register match
				if (MSU_FW_IN(FWD_MEM_R_ACC) = '1') then
				-- Data dependency OF <-> WB (mem read) form MS
					HOLD_BUS_OUT(2 downto 1) <= "11"; -- 3
					HOLD_BUS_OUT(0)          <= '1';  -- enable
				elsif (MSU_FW_IN(FWD_MCR_R_ACC) = '1') then
				-- Data dependency OF <-> MA (MCR access)
					HOLD_BUS_OUT(2 downto 1) <= "10"; -- 2
					HOLD_BUS_OUT(0)          <= '1';  -- enable
				else
				-- Data dependency OF <-> EX
					HOLD_BUS_OUT(2 downto 1) <= "01"; -- 1
					HOLD_BUS_OUT(0)          <= '1';  -- enable
				end if;

			elsif (ALU_MATCH = '1') then
			-- EX Register Match
				if (ALU_FW_IN(FWD_MEM_R_ACC) = '1') then
				-- Data dependency OF <-> WB (mem read) from EX
					HOLD_BUS_OUT(2 downto 1) <= "10"; -- 2
					HOLD_BUS_OUT(0)          <= '1';  -- enable
				elsif (ALU_FW_IN(FWD_MCR_R_ACC) = '1') then
				-- Data dependency OF <-> MA (MCR access)
					HOLD_BUS_OUT(2 downto 1) <= "01"; -- 1
					HOLD_BUS_OUT(0)          <= '1';  -- enable
				end if;
				
			elsif (MEM_MATCH = '1') and (MEM_FW_IN(FWD_MEM_R_ACC) = '1') then
			-- MEM Register Match with MEM_R access
				HOLD_BUS_OUT(2 downto 1) <= "01"; -- 1
				HOLD_BUS_OUT(0)          <= '1';  -- disable

			end if;

		end process TEMPORAL_DDD;



	-- Operand Multiplexers ---------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------
		OPERAND_MUX: process(CTRL_IN, OP_A, OP_B, OP_C, IMM_IN, JMP_PC_IN, LNK_PC_IN, SHIFT_VAL_IN)
		begin

			--- OPERANT A ---
			----------------------------------------------------------------
			if (CTRL_IN(CTRL_BRANCH) = '1') then -- BRANCH_INSTR signal
				-- delayed program counter --
				OP_A_OUT <= JMP_PC_IN;
			else
				-- fowarding unit port A output --
				OP_A_OUT <= OP_A;
			end if;

			--- OPERANT B ---
			----------------------------------------------------------------
			if (CTRL_IN(CTRL_CONST) = '1') then -- CONST signal
				-- immediate --
				OP_B_OUT <= IMM_IN;
			else
				-- fowarding unit port B output --
				OP_B_OUT <= OP_B;
			end if;

			--- SHIFT VALUE --
			----------------------------------------------------------------
			if (CTRL_IN(CTRL_SHIFTR) = '1') then -- SHIFT_REG
				-- fowarding unit port C output --
				SHIFT_VAL_OUT <= OP_C(4 downto 0);
			else
				-- immediate shift value --
				SHIFT_VAL_OUT <= SHIFT_VAL_IN;
			end if;

			--- BYPASS DATA ---
			----------------------------------------------------------------
			if (CTRL_IN(CTRL_LINK) = '1') then -- LINK signal
				-- current program counter --
				BP1_OUT <= LNK_PC_IN;
			else
				-- fowarding unit port C output --
				BP1_OUT <= OP_C;
			end if;
		end process OPERAND_MUX;



end OPERAND_UNIT_STRUCTURE;