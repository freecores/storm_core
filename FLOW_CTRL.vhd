-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #             Operation Flow Control Unit             #
-- # *************************************************** #
-- # Version 2.5, 18.03.2011                             #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity FLOW_CTRL is
    Port (
-- ###############################################################################################
-- ##			Global Control																								##
-- ###############################################################################################

				RES					: in  STD_LOGIC; -- global reset input (high active)
				CLK					: in  STD_LOGIC; -- global clock input

-- ###############################################################################################
-- ##			Instruction Word Input																					##
-- ###############################################################################################

				INSTR_IN				: in  STD_LOGIC_VECTOR(31 downto 0);

-- ###############################################################################################
-- ##			OPCODE Decoder Connection																				##
-- ###############################################################################################

				OPCODE_DATA_OUT	: out STD_LOGIC_VECTOR(31 downto 0);
				OPCODE_CTRL_IN		: in  STD_LOGIC_VECTOR(99 downto 0);
				OPCODE_CTRL_OUT	: out STD_LOGIC_VECTOR(15 downto 0);
			  
-- ###############################################################################################
-- ##			Operands																										##
-- ###############################################################################################

				OP_CONF_HALT_IN	: in  STD_LOGIC;
				EXT_HALT_IN			: in  STD_LOGIC;
				PC_HALT_OUT			: out STD_LOGIC;

				SREG_IN				: in  STD_LOGIC_VECTOR(31 downto 0);
				INT_VECTOR_IN		: in  STD_LOGIC_VECTOR(04 downto 0);
				EXECUTE_INT_IN		: in  STD_LOGIC;
				
-- ###############################################################################################
-- ##			Pipeline Stage Control																					##
-- ###############################################################################################

				OP_ADR_OUT			: out STD_LOGIC_VECTOR(11 downto 0);
				IMM_OUT				: out STD_LOGIC_VECTOR(31 downto 0);
				SHIFT_M_OUT			: out STD_LOGIC_VECTOR(01 downto 0);
				SHIFT_C_OUT			: out STD_LOGIC_VECTOR(04 downto 0);
				
				OF_CTRL_OUT			: out STD_LOGIC_VECTOR(31 downto 0);
				EX1_CTRL_OUT		: out STD_LOGIC_VECTOR(31 downto 0);
				MEM_CTRL_OUT		: out STD_LOGIC_VECTOR(31 downto 0);
				WB_CTRL_OUT			: out STD_LOGIC_VECTOR(31 downto 0)

			 );
end FLOW_CTRL;

architecture FLOW_CTRL_STRUCTURE of FLOW_CTRL is

-- ###############################################################################################
-- ##			Local Signals																								##
-- ###############################################################################################

	-- Instruction Register --
	signal	INSTR_REG				: STD_LOGIC_VECTOR(31 downto 0);

	-- Branch System --
	signal	BT_FF						: STD_LOGIC_VECTOR(BT_NOP_CYCLES-1 downto 0);
	signal	BRANCH_TAKEN			: STD_LOGIC;
	signal	BRANCH_NOP_CYCLES		: STD_LOGIC;
	signal	PC_IR_HALT				: STD_LOGIC;
	
	-- Instruction Validation System --
	signal	VALID_INSTR				: STD_LOGIC;
	signal	EXECUTE          		: STD_LOGIC;

	-- Control Busses --
	signal	EX1_CTRL					: STD_LOGIC_VECTOR(31 downto 0);
	signal	MEM_CTRL					: STD_LOGIC_VECTOR(31 downto 0);
	signal	DEC_CTRL					: STD_LOGIC_VECTOR(31 downto 0);
	signal	CTRL_EX1_OUT			: STD_LOGIC_VECTOR(31 downto 0);
	
	-- Operand Control --
	signal	DUAL_OP					: STD_LOGIC_VECTOR(04 downto 0);
	signal	NEXT_DUAL_OP			: STD_LOGIC_VECTOR(04 downto 0);

	-- CTRL Buffer For ALU-Stage --
	signal	MULTI_OP_HALT			: STD_LOGIC;


begin

	-- #####################################################################################################
	-- ##			Pipeline Stage 0: Instruction Fetch						                                       ##
	-- #####################################################################################################
	
		STAGE_BUFFER_0: process(CLK, RES)
		begin
			if rising_edge(CLK) then
				if (RES = '1') then
					INSTR_REG <= x"F0000000"; -- set never condition for start up
				elsif (PC_IR_HALT = '0') then
					INSTR_REG <= INSTR_IN;
				end if;			
			end if;
		end process STAGE_BUFFER_0;
		
		OPCODE_DATA_OUT <= INSTR_REG;



	-- #####################################################################################################
	-- ##			Pipeline Stage 1: Instruction Decode / Operand Fetch                                      ##
	-- #####################################################################################################

		STAGE_BUFFER_1: process(CLK, RES)
		begin
			if rising_edge (CLK) then
				if (RES = '1') then
					DUAL_OP <= (others => '0');
				else
					DUAL_OP <= NEXT_DUAL_OP;
				end if;
			end if;
		end process STAGE_BUFFER_1;


	-- Opcode Decoder Connection -----------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		OPCODE_CTRL_OUT(04 downto 00) <= DUAL_OP;
		OPCODE_CTRL_OUT(09 downto 05) <= INT_VECTOR_IN;
		OPCODE_CTRL_OUT(10)           <= EXECUTE_INT_IN;

		DEC_CTRL(31 downto 01)	<= OPCODE_CTRL_IN(31 downto 01);
		OP_ADR_OUT					<= OPCODE_CTRL_IN(43 downto 32);
		IMM_OUT						<= OPCODE_CTRL_IN(78 downto 47);
		SHIFT_M_OUT					<= OPCODE_CTRL_IN(80 downto 79);
		SHIFT_C_OUT					<= OPCODE_CTRL_IN(85 downto 81);
		NEXT_DUAL_OP				<= OPCODE_CTRL_IN(90 downto 86);


	-- HALT System -------------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		MULTI_OP_HALT			<= '0' when (NEXT_DUAL_OP = "00000") else '1';
		PC_IR_HALT				<= OP_CONF_HALT_IN or MULTI_OP_HALT or EXT_HALT_IN;
		PC_HALT_OUT				<= PC_IR_HALT;
		DEC_CTRL(CTRL_EN) 	<=	OP_CONF_HALT_IN;


	-- CTRL Connection ---------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		OF_CTRL_OUT <= DEC_CTRL;


	-- #####################################################################################################
	-- ##			Pipeline Stage 2: Execution																					##
	-- #####################################################################################################

		STAGE_BUFFER_2: process(CLK)
		begin
			if rising_edge(CLK) then
				if (RES = '1') then
					BT_FF      <= (others => '0');
					EX1_CTRL   <= x"F0000000";
				else
					BT_FF(BT_NOP_CYCLES-1 downto 0) <= BT_FF(BT_NOP_CYCLES-2 downto 0) & BRANCH_TAKEN;
					EX1_CTRL   <= DEC_CTRL;
				end if;
			end if;
		end process STAGE_BUFFER_2;


	-- Condition Check System --------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		COND_CHECK_SYS: process(EX1_CTRL, SREG_IN)
		begin
			case EX1_CTRL(CTRL_COND_3 downto CTRL_COND_0) is

				when COND_EQ => -- EQ = EQUAL: Zero set
					EXECUTE <= SREG_IN(SREG_Z_FLAG);

				when COND_NE => -- NE = NOT EQUAL: Zero clr
					EXECUTE <= not SREG_IN(SREG_Z_FLAG);

				when COND_CS => -- CS = UNISGNED OR HIGHER: Carry set
					EXECUTE <= SREG_IN(SREG_C_FLAG);

				when COND_CC => -- CC = UNSIGNED LOWER: Carry clr
					EXECUTE <= not SREG_IN(SREG_C_FLAG);

				when COND_MI => -- MI = NEGATIVE: Negative set
					EXECUTE <= SREG_IN(SREG_N_FLAG);

				when COND_PL => -- PL = POSITIVE OR ZERO: Negative clr
					EXECUTE <= not SREG_IN(SREG_N_FLAG);

				when COND_VS => -- VS = OVERFLOW: Overflow set
					EXECUTE <= SREG_IN(SREG_O_FLAG);

				when COND_VC => -- VC = NO OVERFLOW: Overflow clr
					EXECUTE <= not SREG_IN(SREG_O_FLAG);

				when COND_HI => -- HI = UNSIGNED HIGHER: Carry set and Zero clr
					EXECUTE <= SREG_IN(SREG_C_FLAG) and (not SREG_IN(SREG_Z_FLAG));

				when COND_LS => -- LS = UNSIGNED LOWER OR SAME: Carry clr or Zero set
					EXECUTE <= (not SREG_IN(SREG_C_FLAG)) or SREG_IN(SREG_Z_FLAG);

				when COND_GE => -- GE = GREATER OR EQUAL
					EXECUTE <= not(SREG_IN(SREG_N_FLAG) xor SREG_IN(SREG_O_FLAG));

				when COND_LT => -- LT = LESS THAN
					EXECUTE <= SREG_IN(SREG_N_FLAG) xor SREG_IN(SREG_O_FLAG);

				when COND_GT => -- GT = GREATER THAN
					EXECUTE <= (not SREG_IN(SREG_Z_FLAG)) and SREG_IN(SREG_O_FLAG);

				when COND_LE => -- LE = LESS THAN OR EQUAL
					EXECUTE <= SREG_IN(SREG_Z_FLAG) and (SREG_IN(SREG_N_FLAG) xor SREG_IN(SREG_O_FLAG));

				when COND_AL => -- AL = ALWAYS
					EXECUTE <= '1';

				when COND_NV => -- NV = NEVER
					EXECUTE <= '0';

				when others => -- UNDEFINED
					EXECUTE <= '0';

			end case;		
		end process COND_CHECK_SYS;


	-- Figure out if current instruction is valid ------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		BRANCH_NOP_CYCLES <= '1' when (BT_FF(BT_NOP_CYCLES-1 downto 0) = "00") else '0';
		VALID_INSTR       <= (not EX1_CTRL(CTRL_EN)) and EXECUTE and BRANCH_NOP_CYCLES;


	-- Test For Manual Branch --------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		BRANCH_DETECTOR: process(EX1_CTRL, VALID_INSTR)
			variable TEMP : STD_LOGIC;
		begin
			TEMP := '0';
			if (EX1_CTRL(CTRL_RD_3 downto CTRL_RD_0) = C_PC_ADR) and (EX1_CTRL(CTRL_WB_EN) = '1') then
				TEMP := '1';
			end if;
			BRANCH_TAKEN <= VALID_INSTR and (EX1_CTRL(CTRL_BRANCH) or TEMP);
		end process BRANCH_DETECTOR;


	-- Link Control ------------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		MR_SPOCK: process(EX1_CTRL, BRANCH_TAKEN, VALID_INSTR)
		begin
			CTRL_EX1_OUT					<= EX1_CTRL;
			CTRL_EX1_OUT(CTRL_BRANCH)	<= BRANCH_TAKEN; -- insert if a branch is taken
			CTRL_EX1_OUT(CTRL_EN)		<= VALID_INSTR;  -- insert current op validation

			-- Insert RD = LR when performing Link Operations --
			if (EX1_CTRL(CTRL_LINK) = '1') then
				CTRL_EX1_OUT(CTRL_RD_3 downto CTRL_RD_0) <= C_LR_ADR;
			end if;
		end process MR_SPOCK;


	-- Pipeline Stage "EXECUTE" CTRL Bus ---------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		EX1_CTRL_OUT <= CTRL_EX1_OUT;


	-- #####################################################################################################
	-- ##			Pipeline Stage 3 / 4: Data Memory Access / Data Writeback											##
	-- #####################################################################################################

		STAGE_BUFFER_3: process(CLK)
		begin
			if rising_edge (CLK) then
				if (RES = '1') then
					MEM_CTRL		<= (others => '0');
					WB_CTRL_OUT	<= (others => '0');
				else
					MEM_CTRL		<= CTRL_EX1_OUT;
					MEM_CTRL(CTRL_MODE_4 downto CTRL_MODE_0) <= SREG_IN(SREG_MODE_4 downto SREG_MODE_0);
					WB_CTRL_OUT	<= MEM_CTRL;
				end if;
			end if;
		end process STAGE_BUFFER_3;


	-- Pipeline Stage "MEMORY" CTRL Bus ----------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		MEM_CTRL_OUT <= MEM_CTRL;



end FLOW_CTRL_STRUCTURE;