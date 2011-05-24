-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #             Operation Flow Control Unit             #
-- # *************************************************** #
-- # Version 2.7.0, 25.05.2011                           #
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

				INSTR_IN				: in  STD_LOGIC_VECTOR(31 downto 0); -- instr memory input

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

				HOLD_BUS_IN			: in  STD_LOGIC_VECTOR(02 downto 0);

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
	signal	INSTR_REG		: STD_LOGIC_VECTOR(31 downto 0);

	-- Branch System --
	signal	BRANCH_TAKEN	: STD_LOGIC;
	signal	PC_IR_HALT		: STD_LOGIC;
	signal	HALT_GLOBAL_IF	: STD_LOGIC;
	
	-- Bubble Generator --
	signal	INSERT_BUBBLE	: STD_LOGIC;
	
	-- Instruction Validation System --
	signal	VALID_INSTR		: STD_LOGIC;

	-- Control Busses --
	signal	DEC_CTRL			: STD_LOGIC_VECTOR(31 downto 0);
	signal	MS_CTRL			: STD_LOGIC_VECTOR(31 downto 0);
	signal	MS_CTRL_INT		: STD_LOGIC_VECTOR(31 downto 0);	
	signal	EX1_CTRL			: STD_LOGIC_VECTOR(31 downto 0);
	signal	CTRL_EX1_BUS	: STD_LOGIC_VECTOR(31 downto 0);
	signal	MEM_CTRL			: STD_LOGIC_VECTOR(31 downto 0);
	signal	WB_CTRL			: STD_LOGIC_VECTOR(31 downto 0);
	
	-- Operand Control --
	signal	DUAL_OP			: STD_LOGIC_VECTOR(04 downto 0);
	signal	NEXT_DUAL_OP	: STD_LOGIC_VECTOR(04 downto 0);

	-- CTRL Buffer For ALU-Stage --
	signal	MULTI_OP_HALT	: STD_LOGIC;
	
	-- Manual Data Memory Access --
	signal	MEM_DAT_ACC		: STD_LOGIC;

	-- Prefetch Output --
	signal	PRF_OUT			: STD_LOGIC_VECTOR(31 downto 0);

begin

	-- #######################################################################################################
	-- ##			PIPELINE STAGE 1/5: OPERAND FETCH & INSTRUCITON DECODE / DATA WRITE BACK                    ##
	-- #######################################################################################################

	-- Instruction Fetch Unit --------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		OP_FETCH_UNIT: process(CLK, RES, INSTR_IN, HOLD_BUS_IN)
			variable IR_0, IR_1, IR_2, IR_3    : STD_LOGIC_VECTOR(31 downto 00);
			variable CYCLE_CNT, RD_CNT, WR_CNT : STD_LOGIC_VECTOR(01 downto 00);
			variable RD_INC, WR_INC, WR_IR_EN  : STD_LOGIC;
			
		begin

			-- Cycle Action Counter --
			if rising_edge(CLK) then
				if (RES = '1') then -- Reset
					CYCLE_CNT := (others => '0');
				elsif (HOLD_BUS_IN(0) = '1') then -- Load counter
					CYCLE_CNT := HOLD_BUS_IN(2 downto 1);
				elsif (CYCLE_CNT /= "00") then -- Decrement until zero
					CYCLE_CNT := Std_Logic_Vector(unsigned(CYCLE_CNT) - 1);
				end if;
			end if;


			-- Global IR Write Enable
			if rising_edge(CLK) then
				if (RES = '1') then
					WR_IR_EN := '0';
				elsif (CYCLE_CNT = "00") then
					WR_IR_EN := '1';
				else
					WR_IR_EN := '0';
				end if;
			end if;


			-- RD/WR CNT enable & external CTRL --
			if (to_integer(unsigned(CYCLE_CNT)) > 1) or (HOLD_BUS_IN(0) = '1') then
				RD_INC := '0';
				HALT_GLOBAL_IF <= '1';
			else
				RD_INC := '1';
				HALT_GLOBAL_IF <= '0';
			end if;
			if (to_integer(unsigned(CYCLE_CNT)) = 0) then
				WR_INC := '1';
			else
				WR_INC := '0';
			end if;


			-- Read/Write Address Counter --
			if rising_edge(CLK) then
				if (RES = '1') then
					RD_CNT := "11"; -- we need 1 entry difference
					WR_CNT := "00";
				else
					if (RD_INC = '1') then
						RD_CNT := Std_Logic_Vector(unsigned(RD_CNT) + 1);
					end if;
					if (WR_INC = '1') then
						WR_CNT := Std_Logic_Vector(unsigned(WR_CNT) + 1);
					end if;
				end if;
			end if;


			-- Synchronous Instruction Buffer Write --
			if rising_edge(CLK) then
				if (RES = '1') then
					IR_0 := NOP_CMD;
					IR_1 := NOP_CMD;
					IR_2 := NOP_CMD;
					IR_3 := NOP_CMD;
				elsif (WR_IR_EN = '1') then
					case (WR_CNT) is
						when "00"   => IR_0 := INSTR_IN;
						when "01"   => IR_1 := INSTR_IN;
						when "10"   => IR_2 := INSTR_IN;
						when "11"   => IR_3 := INSTR_IN;
						when others => NULL;
					end case;
				end if;
			end if;


			-- Asynchronous Instruction Buffer Read --
			case (RD_CNT) is
				when "00"   => INSTR_REG <= IR_0;
				when "01"   => INSTR_REG <= IR_1;
				when "10"   => INSTR_REG <= IR_2;
				when "11"   => INSTR_REG <= IR_3;
				when others => INSTR_REG <= (others => '-');
			end case;

		end process OP_FETCH_UNIT;


	-- Opcode Decoder Connection -----------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		-- primary control --
		OPCODE_DATA_OUT <= INSTR_REG;
		
		-- secondary control --
		OPCODE_CTRL_OUT(04 downto 00) <= DUAL_OP;
		OPCODE_CTRL_OUT(10 downto 05) <= (others => '0');


	-- Stage "Operand Fetch" Control Unit --------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		OF_CTRL_UNIT: process(OPCODE_CTRL_IN, MULTI_OP_HALT, EXT_HALT_IN, INSERT_BUBBLE, MEM_DAT_ACC, HALT_GLOBAL_IF)
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
			PC_IR_HALT  <= HALT_GLOBAL_IF or MULTI_OP_HALT or EXT_HALT_IN or MEM_DAT_ACC;
			PC_HALT_OUT <= PC_IR_HALT;

			-- Halt Instruction Processing --
			DEC_CTRL(CTRL_EN) <= not (EXT_HALT_IN or FORCE_DISABLE or HALT_GLOBAL_IF or INSERT_BUBBLE or MEM_DAT_ACC);

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
					-- set 'never condition' for start up --
					MS_CTRL_INT(CTRL_COND_3 downto CTRL_COND_0) <= COND_NV;
				else
					MS_CTRL_INT <= DEC_CTRL;
				end if;
			end if;
		end process STAGE_BUFFER_2;


	-- Branch Cycle Arbiter ----------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		BR_CYCLE_ARBITER: process(CLK, RES, BRANCH_TAKEN)
			variable CA_CNT : STD_LOGIC_VECTOR(1 downto 0);
		begin

			--- Cycle Counter ---
			if rising_edge(CLK) then
				if (RES = '1') then -- reset
					CA_CNT := (others => '0');
				elsif (BRANCH_TAKEN = '1') then -- restart
					CA_CNT := "10";
				elsif (CA_CNT /= "00") then -- decrement until zero
					CA_CNT := Std_Logic_Vector(unsigned(CA_CNT) - 1);
				end if;
			end if;

			--- INSERT NOP ---
			if (CA_CNT /= "00") or (BRANCH_TAKEN = '1') then
				INSERT_BUBBLE <= '1';
			else
				INSERT_BUBBLE <= '0';
			end if;

		end process BR_CYCLE_ARBITER;


--		CYCLE_ARBITER: process(CLK, RES, HOLD_BUS_IN, BRANCH_TAKEN)
--			variable CA_CNT, CA_CNT_NXT : STD_LOGIC_VECTOR(2 downto 0);
--			variable INV_FF, INV_FF_NXT : STD_LOGIC;
--		begin
--
--			--- Cycle Counter Input ---
--			if (CA_CNT = "000") then
--				if (BRANCH_TAKEN = '1') then
--					CA_CNT_NXT := "011";
--					INV_FF_NXT := '1';
--				elsif (HOLD_BUS_IN(0) = '1') then
--					CA_CNT_NXT := '0' & HOLD_BUS_IN(2 downto 1);
--					INV_FF_NXT := '0';
--				else
--					-- normal operation --
--					CA_CNT_NXT := "000";
--					INV_FF_NXT := '0';
--				end if;
--			else
--				-- counting down --
--				CA_CNT_NXT := Std_Logic_Vector(unsigned(CA_CNT) - 1);
--				INV_FF_NXT := INV_FF;
--			end if;
--
--			--- Cycle Counter ---
--			if rising_edge(CLK) then
--				if (RES = '1') then
--					CA_CNT := (others => '0');
--					INV_FF := '0';
--				else
--					CA_CNT := CA_CNT_NXT;
--					INV_FF := INV_FF_NXT;
--				end if;
--			end if;
--
--			--- HALT Output ---
--			HALT_GLOBAL_IF <= '1';
--			if (CA_CNT = "000") and (HOLD_BUS_IN(0) = '0') then
--				HALT_GLOBAL_IF <= '0';
--			end if;
--
--			--- NOP Output ---
--			INSERT_BUBBLE <= INV_FF or BRANCH_TAKEN;
--
--		end process CYCLE_ARBITER;



	-- Pipeline Stage "MULTIPLY/SHIFT" CTRL Bus --------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		MS_CTRL_ALLOCATION: process(MS_CTRL, INSERT_BUBBLE, MS_CTRL_INT)
		begin
			MS_CTRL				<= MS_CTRL_INT;
			MS_CTRL(CTRL_EN)	<= MS_CTRL_INT(CTRL_EN)	and (not INSERT_BUBBLE);
		end process MS_CTRL_ALLOCATION;

		MS_CTRL_OUT <= MS_CTRL;


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
					-- set 'never condition' for start up --
					EX1_CTRL(CTRL_COND_3 downto CTRL_COND_0) <= COND_NV;
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
			
			--- Valid Instruction Signal ---
			VALID_INSTR <= EX1_CTRL(CTRL_EN) and EXECUTE;
			
		end process COND_CHECK_SYS;


	-- Test For Manual Branch --------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		BRANCH_DETECTOR: process(EX1_CTRL, VALID_INSTR)
			variable TEMP : STD_LOGIC;
		begin
			TEMP := '0';
			if (EX1_CTRL(CTRL_RD_3 downto CTRL_RD_0) = C_PC_ADR) and (EX1_CTRL(CTRL_WB_EN) = '1') then
				TEMP := '1'; -- set if destination register is the PC
			end if;
			BRANCH_TAKEN <= (VALID_INSTR and (EX1_CTRL(CTRL_BRANCH) or TEMP));
		end process BRANCH_DETECTOR;


	-- EX Stage CTRL_BUS and Link Control --------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		EX_CTRL_BUS_CONSTRUCTION: process(EX1_CTRL, BRANCH_TAKEN, VALID_INSTR, EXECUTE_INT_IN)
		begin

			--- CTRL_BUS for THIS stage ---
			EX1_CTRL_OUT              <= EX1_CTRL;
			EX1_CTRL_OUT(CTRL_BRANCH) <= BRANCH_TAKEN; -- insert branch taken sign
			EX1_CTRL_OUT(CTRL_EN)     <= VALID_INSTR;  -- insert current op validation

			--- CTRL_BUS for NEXT stage ---
			CTRL_EX1_BUS              <= EX1_CTRL;
			CTRL_EX1_BUS(CTRL_BRANCH) <= BRANCH_TAKEN; -- insert branch taken sign
			CTRL_EX1_BUS(CTRL_EN)     <= VALID_INSTR;  -- insert current op validation

			--- Branch & Link Operation for Interrupt Call ---
			if (EXECUTE_INT_IN = '1') then
				CTRL_EX1_BUS(CTRL_MEM_ACC)  <= '0'; -- disable memory access
				CTRL_EX1_BUS(CTRL_MREG_ACC) <= '0'; -- disable mcr access
				CTRL_EX1_BUS(CTRL_EN)       <= '1'; -- force enable
				CTRL_EX1_BUS(CTRL_LINK)     <= '1'; -- force LR pass
				CTRL_EX1_BUS(CTRL_WB_EN)	 <= '1'; -- force LR write back
			end if;

			--- Insert RD = LR when performing Link Operations ---
			if (EX1_CTRL(CTRL_LINK) = '1') or (EXECUTE_INT_IN = '1') then
				CTRL_EX1_BUS(CTRL_RD_3 downto CTRL_RD_0) <= C_LR_ADR;
			end if;
		end process EX_CTRL_BUS_CONSTRUCTION;


	-- Pipeline Stage "EXECUTE" CTRL Bus ---------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		--EX1_CTRL_OUT <= CTRL_EX1_BUS;


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
					MEM_CTRL <= CTRL_EX1_BUS;
					MEM_CTRL(CTRL_MODE_4 downto CTRL_MODE_0) <= SREG_IN(SREG_MODE_4 downto SREG_MODE_0);
				end if;
			end if;
		end process STAGE_BUFFER_4;


	-- Manual Data Memory Access -----------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		MANUAL_MEM_ACCESS: process(MEM_CTRL, WB_CTRL)
			variable TEMP_A, TEMP_B : STD_LOGIC;
		begin
			-- Hold instruction fetch for at leat 1 cycle when performing data memory access
			TEMP_A := MEM_CTRL(CTRL_EN) and MEM_CTRL(CTRL_MEM_ACC);
			-- Hold instruction fetch for 2 cycles when performing a read data memory access
			TEMP_B := WB_CTRL(CTRL_EN) and WB_CTRL(CTRL_MEM_ACC) and (not WB_CTRL(CTRL_MEM_RW));

			MEM_DAT_ACC <= TEMP_A or TEMP_B;
		end process MANUAL_MEM_ACCESS;


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