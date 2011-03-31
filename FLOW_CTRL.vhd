-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #             Operation Flow Control Unit             #
-- # *************************************************** #
-- # Version 2.6.1, 25.03.2011                           #
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

				EXT_HALT_IN			: in  STD_LOGIC;
				PC_HALT_OUT			: out STD_LOGIC;

				SREG_IN				: in  STD_LOGIC_VECTOR(31 downto 0);
				EXECUTE_INT_IN		: in  STD_LOGIC;

				STALLS_IN			: in  STD_LOGIC_VECTOR(02 downto 0);

-- ###############################################################################################
-- ##			Pipeline Stage Control																					##
-- ###############################################################################################

				OP_ADR_OUT			: out STD_LOGIC_VECTOR(11 downto 0);
				IMM_OUT				: out STD_LOGIC_VECTOR(31 downto 0);
				SHIFT_M_OUT			: out STD_LOGIC_VECTOR(01 downto 0);
				SHIFT_C_OUT			: out STD_LOGIC_VECTOR(04 downto 0);

				OF_CTRL_OUT			: out STD_LOGIC_VECTOR(31 downto 0);
				MS_CTRL_OUT			: out STD_LOGIC_VECTOR(31 downto 0);
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
	signal	BRANCH_TAKEN			: STD_LOGIC;
	signal	BRANCH_NOP_CYCLES		: STD_LOGIC;
	signal	PC_IR_HALT				: STD_LOGIC;
	signal	HALT_GLOBAL_IF			: STD_LOGIC;
	
	-- Bubble Generator --
	signal	INSERT_BUBBLE			: STD_LOGIC;
	
	-- Instruction Validation System --
	signal	VALID_INSTR				: STD_LOGIC;

	-- Control Busses --
	signal	MS_CTRL					: STD_LOGIC_VECTOR(31 downto 0);
	signal	MS_CTRL_INT				: STD_LOGIC_VECTOR(31 downto 0);	
	signal	EX1_CTRL					: STD_LOGIC_VECTOR(31 downto 0);
	signal	MEM_CTRL					: STD_LOGIC_VECTOR(31 downto 0);
	signal	DEC_CTRL					: STD_LOGIC_VECTOR(31 downto 0);
	signal	WB_CTRL					: STD_LOGIC_VECTOR(31 downto 0);
	signal	CTRL_EX1_OUT			: STD_LOGIC_VECTOR(31 downto 0);
	
	-- Operand Control --
	signal	DUAL_OP					: STD_LOGIC_VECTOR(04 downto 0);
	signal	NEXT_DUAL_OP			: STD_LOGIC_VECTOR(04 downto 0);

	-- CTRL Buffer For ALU-Stage --
	signal	MULTI_OP_HALT			: STD_LOGIC;

begin

	-- #######################################################################################################
	-- ##			PIPELINE STAGE 1/5: OPERAND FETCH & INSTRUCITON DECODE / DATA WRITE BACK                    ##
	-- #######################################################################################################

	-- Pipeline Registers ------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		STAGE_BUFFER_1: process(CLK, RES)
		begin
			if rising_edge (CLK) then
				if (RES = '1') then
					INSTR_REG <= (others => '0');
					INSTR_REG(31 downto 28) <= COND_NV; -- set 'never condition' for start up
					DUAL_OP <= (others => '0');
				else
					DUAL_OP <= NEXT_DUAL_OP;
					if (PC_IR_HALT = '0') then
						INSTR_REG <= INSTR_IN;
					end if;
				end if;
			end if;
		end process STAGE_BUFFER_1;


	-- Opcode Decoder Connection -----------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		-- primary control --
		OPCODE_DATA_OUT <= INSTR_REG;
		
		-- secondary control --
		OPCODE_CTRL_OUT(04 downto 00) <= DUAL_OP;
		OPCODE_CTRL_OUT(10 downto 05) <= (others => '0');


	-- Stage "Operand Fetch" Control Unit --------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		OF_CTRL_UNIT: process(OPCODE_CTRL_IN, INSERT_BUBBLE, MULTI_OP_HALT, EXT_HALT_IN)
			variable FORCE_DISABLE : STD_LOGIC;
		begin
		
			--- Opcode Decoder Connection ---
			DEC_CTRL			<= OPCODE_CTRL_IN(31 downto 00);
			OP_ADR_OUT		<= OPCODE_CTRL_IN(43 downto 32);
			IMM_OUT			<= OPCODE_CTRL_IN(78 downto 47);
			SHIFT_M_OUT		<= OPCODE_CTRL_IN(80 downto 79);
			SHIFT_C_OUT		<= OPCODE_CTRL_IN(85 downto 81);
			NEXT_DUAL_OP	<= OPCODE_CTRL_IN(90 downto 86);

			--- Default Disable ---
			FORCE_DISABLE := '0';
			if (OPCODE_CTRL_IN(CTRL_COND_3 downto CTRL_COND_0) = COND_NV) then
				FORCE_DISABLE := '1';
			end if;
			
			--- Multi-Cycle Operation in Progress ---
			MULTI_OP_HALT <= '1';
			if (OPCODE_CTRL_IN(90 downto 86) = "00000") then
				MULTI_OP_HALT	<= '0' ;
			end if;

			-- Halt Instruction Fetch --
			PC_IR_HALT			<= HALT_GLOBAL_IF or MULTI_OP_HALT or EXT_HALT_IN;
			PC_HALT_OUT			<= PC_IR_HALT;

			-- Halt Instruction Processing --
			DEC_CTRL(CTRL_EN) <= not (EXT_HALT_IN or FORCE_DISABLE or HALT_GLOBAL_IF);
		
		end process OF_CTRL_UNIT;


	-- Pipeline Stage "OPERAND FETCH" CTRL Bus ---------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		OF_CTRL_OUT <= DEC_CTRL;
		

	-- #######################################################################################################
	-- ##			PIPELINE STAGE 2: MULTIPLICATION & SHIFT                                                    ##
	-- #######################################################################################################

	-- Pipeline Registers ------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		STAGE_BUFFER_2: process(CLK, RES)
		begin
			if rising_edge (CLK) then
				if (RES = '1') then
					MS_CTRL_INT <= (others => '0');
					MS_CTRL_INT(CTRL_COND_3 downto CTRL_COND_0) <= COND_NV; -- set 'never condition' for start up
				else
					MS_CTRL_INT <= DEC_CTRL;
				end if;
			end if;
		end process STAGE_BUFFER_2;


	-- Instruction Fetch Halt / Bubble Generator -------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		HB_GENERATOR: process(CLK, RES, BRANCH_TAKEN, STALLS_IN, EXECUTE_INT_IN)
			variable BUBBLE_CNT, BUBBLE_CNT_NXT   : STD_LOGIC_VECTOR(1 downto 0);
			variable HALT_IF_CNT, HALT_IF_CNT_NXT : STD_LOGIC_VECTOR(1 downto 0);
		begin

			--- Bubble Counter Input ---
			if (BUBBLE_CNT = "00") and (EXECUTE_INT_IN = '0') then
				if (BRANCH_TAKEN = '1') then	-- Branch_taken/jump/int_call
					BUBBLE_CNT_NXT := DC_TAKEN_BRANCH;
				else									-- Normal operation
					BUBBLE_CNT_NXT := "00";
				end if;			
			else
				BUBBLE_CNT_NXT := std_logic_vector(unsigned(BUBBLE_CNT)  - 1);
			end if;

			--- Halt Counter Input ---
			if (HALT_IF_CNT = "00") then
				if (STALLS_IN(0) = '1') then	-- Temporal resource conflict
					HALT_IF_CNT_NXT := STALLS_IN(2 downto 1);
				else									-- Normal operation
					HALT_IF_CNT_NXT := "00";
				end if;			
			else
				HALT_IF_CNT_NXT := std_logic_vector(unsigned(HALT_IF_CNT) - 1);
			end if;

			--- Halt/Bubble Counter ---
			if rising_edge(CLK) then
				if (RES = '1') then
					BUBBLE_CNT  := (others => '0');
					HALT_IF_CNT := (others => '0');
				else
					BUBBLE_CNT  := BUBBLE_CNT_NXT;
					HALT_IF_CNT := HALT_IF_CNT_NXT;
				end if;
			end if;

			--- Insert Bubbles ---
			INSERT_BUBBLE <= '1';
			if (BUBBLE_CNT = "00") and (BRANCH_TAKEN = '0') then -- and (EXECUTE_INT_IN = '0') then
				INSERT_BUBBLE <= '0';
			end if;
			
			--- Halt Instruction Fetch ---
			HALT_GLOBAL_IF <= '1';
			if (HALT_IF_CNT = "00") and (HALT_IF_CNT_NXT = "00") then
				HALT_GLOBAL_IF <= '0';
			end if;

		end process HB_GENERATOR;


	-- Pipeline Stage "MULTIPLY/SHIFT" CTRL Bus --------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		MS_CTRL_ALLOCATION: process(MS_CTRL, INSERT_BUBBLE)
		begin
			MS_CTRL				<= MS_CTRL_INT;
			MS_CTRL(CTRL_EN)	<= MS_CTRL_INT(CTRL_EN)	and (not INSERT_BUBBLE);
		end process MS_CTRL_ALLOCATION;
		
		MS_CTRL_OUT <= MS_CTRL; -- MS_CTRL


	-- #####################################################################################################
	-- ##			PIPELINE STAGE 3/0: ALU OPERATION & MCR ACCESS / INSTRUCTION FETCH                        ##
	-- #####################################################################################################

	-- Pipeline Registers ------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		STAGE_BUFFER_3: process(CLK)
		begin
			if rising_edge(CLK) then
				if (RES = '1') then
					EX1_CTRL <= (others => '0');
					EX1_CTRL(CTRL_COND_3 downto CTRL_COND_0) <= COND_NV; -- set 'never condition' for start up
				else
					EX1_CTRL <= MS_CTRL;
				end if;
			end if;
		end process STAGE_BUFFER_3;


	-- Condition Check System --------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		COND_CHECK_SYS: process(EX1_CTRL, SREG_IN)
			variable EXECUTE : STD_LOGIC;
		begin
			case EX1_CTRL(CTRL_COND_3 downto CTRL_COND_0) is

				when COND_EQ => -- EQ = EQUAL: Zero set
					EXECUTE := SREG_IN(SREG_Z_FLAG);

				when COND_NE => -- NE = NOT EQUAL: Zero clr
					EXECUTE := not SREG_IN(SREG_Z_FLAG);

				when COND_CS => -- CS = UNISGNED OR HIGHER: Carry set
					EXECUTE := SREG_IN(SREG_C_FLAG);

				when COND_CC => -- CC = UNSIGNED LOWER: Carry clr
					EXECUTE := not SREG_IN(SREG_C_FLAG);

				when COND_MI => -- MI = NEGATIVE: Negative set
					EXECUTE := SREG_IN(SREG_N_FLAG);

				when COND_PL => -- PL = POSITIVE OR ZERO: Negative clr
					EXECUTE := not SREG_IN(SREG_N_FLAG);

				when COND_VS => -- VS = OVERFLOW: Overflow set
					EXECUTE := SREG_IN(SREG_O_FLAG);

				when COND_VC => -- VC = NO OVERFLOW: Overflow clr
					EXECUTE := not SREG_IN(SREG_O_FLAG);

				when COND_HI => -- HI = UNSIGNED HIGHER: Carry set and Zero clr
					EXECUTE := SREG_IN(SREG_C_FLAG) and (not SREG_IN(SREG_Z_FLAG));

				when COND_LS => -- LS = UNSIGNED LOWER OR SAME: Carry clr or Zero set
					EXECUTE := (not SREG_IN(SREG_C_FLAG)) or SREG_IN(SREG_Z_FLAG);

				when COND_GE => -- GE = GREATER OR EQUAL
					EXECUTE := not(SREG_IN(SREG_N_FLAG) xor SREG_IN(SREG_O_FLAG));

				when COND_LT => -- LT = LESS THAN
					EXECUTE := SREG_IN(SREG_N_FLAG) xor SREG_IN(SREG_O_FLAG);

				when COND_GT => -- GT = GREATER THAN
					EXECUTE := (not SREG_IN(SREG_Z_FLAG)) and SREG_IN(SREG_O_FLAG);

				when COND_LE => -- LE = LESS THAN OR EQUAL
					EXECUTE := SREG_IN(SREG_Z_FLAG) and (SREG_IN(SREG_N_FLAG) xor SREG_IN(SREG_O_FLAG));

				when COND_AL => -- AL = ALWAYS
					EXECUTE := '1';

				when COND_NV => -- NV = NEVER
					EXECUTE := '0';

				when others => -- UNDEFINED
					EXECUTE := '0';

			end case;
			
			--- Valid Instruction Command ---
			VALID_INSTR <= EX1_CTRL(CTRL_EN) and EXECUTE;
			
		end process COND_CHECK_SYS;


	-- Test For Manual Branch --------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		BRANCH_DETECTOR: process(EX1_CTRL, VALID_INSTR, EXECUTE_INT_IN)
			variable TEMP : STD_LOGIC;
		begin
			TEMP := '0';
			if (EX1_CTRL(CTRL_RD_3 downto CTRL_RD_0) = C_PC_ADR) and (EX1_CTRL(CTRL_WB_EN) = '1') then
				TEMP := '1'; -- set if destination register is the PC
			end if;
			BRANCH_TAKEN <= (VALID_INSTR and (EX1_CTRL(CTRL_BRANCH) or TEMP)) or EXECUTE_INT_IN;
		end process BRANCH_DETECTOR;


	-- Link Control ------------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		LINK_CONTROL: process(EX1_CTRL, BRANCH_TAKEN, VALID_INSTR, EXECUTE_INT_IN)
		begin
			CTRL_EX1_OUT					 <= EX1_CTRL;
			CTRL_EX1_OUT(CTRL_BRANCH)	 <= BRANCH_TAKEN; -- insert if a branch is taken
			CTRL_EX1_OUT(CTRL_EN)		 <= VALID_INSTR;  -- insert current op validation
			
			-- Jump Operation for Interrupt Call --
			if (EXECUTE_INT_IN = '1') then
				CTRL_EX1_OUT(CTRL_MEM_ACC)  <= '0'; -- disable memory
				CTRL_EX1_OUT(CTRL_EN)       <= '1'; -- force enable
				CTRL_EX1_OUT(CTRL_LINK)     <= '1'; -- force LR write back
				CTRL_EX1_OUT(CTRL_WB_EN)	 <= EX1_CTRL(CTRL_WB_EN) or EXECUTE_INT_IN;
				CTRL_EX1_OUT(CTRL_RD_3 downto CTRL_RD_0) <= C_LR_ADR;
			end if;

			-- Insert RD = LR when performing Link Operations --
			if (EX1_CTRL(CTRL_LINK) = '1') then
				CTRL_EX1_OUT(CTRL_RD_3 downto CTRL_RD_0) <= C_LR_ADR;
			end if;
		end process LINK_CONTROL;


	-- Pipeline Stage "EXECUTE" CTRL Bus ---------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		EX1_CTRL_OUT <= CTRL_EX1_OUT;


	-- #####################################################################################################
	-- ##			PIPELINE STAGE 4: DATA MEMORY ACCESS                                                      ##
	-- #####################################################################################################

	-- Pipeline Registers ------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		STAGE_BUFFER_4: process(CLK, RES)
		begin
			if rising_edge (CLK) then
				if (RES = '1') then
					MEM_CTRL <= (others => '0');
				else
					MEM_CTRL <= CTRL_EX1_OUT;
					MEM_CTRL(CTRL_MODE_4 downto CTRL_MODE_0) <= SREG_IN(SREG_MODE_4 downto SREG_MODE_0);
				end if;
			end if;
		end process STAGE_BUFFER_4;


	-- Pipeline Stage "MEMORY" CTRL Bus ----------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		MEM_CTRL_OUT <= MEM_CTRL;


	-- #####################################################################################################
	-- ##			PIPELINE STAGE 5: DATA WRITE BACK                                                         ##
	-- #####################################################################################################

	-- Pipeline Registers ------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		STAGE_BUFFER_5: process(CLK, RES)
		begin
			if rising_edge (CLK) then
				if (RES = '1') then
					WB_CTRL <= (others => '0');
				else
					WB_CTRL <= MEM_CTRL;
				end if;
			end if;
		end process STAGE_BUFFER_5;


	-- Pipeline Stage "WRITE BACK" CTRL Bus ------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		WB_CTRL_OUT <= WB_CTRL;


end FLOW_CTRL_STRUCTURE;