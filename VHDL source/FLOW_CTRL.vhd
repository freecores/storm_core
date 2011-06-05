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
-- ##			Instruction Interface																					##
-- ###############################################################################################

				INSTR_IN				: in  STD_LOGIC_VECTOR(31 downto 0); -- instr memory input
				INST_MREQ_OUT		: out STD_LOGIC; -- automatic instruction fetch memory request

-- ###############################################################################################
-- ##			OPCODE Decoder Connection																				##
-- ###############################################################################################

				OPCODE_DATA_OUT	: out STD_LOGIC_VECTOR(31 downto 0);
				OPCODE_CTRL_IN		: in  STD_LOGIC_VECTOR(99 downto 0);
				OPCODE_CTRL_OUT	: out STD_LOGIC_VECTOR(15 downto 0);

-- ###############################################################################################
-- ##			Operands																										##
-- ###############################################################################################

				PC_HALT_OUT			: out STD_LOGIC;

				SREG_IN				: in  STD_LOGIC_VECTOR(31 downto 0);
				EXECUTE_INT_IN		: in  STD_LOGIC;

				HOLD_BUS_IN			: in  STD_LOGIC_VECTOR(03 downto 0);

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

	-- Branch System --
	signal	BRANCH_TAKEN   : STD_LOGIC;
	signal 	DISABLE_CYCLE  : STD_LOGIC;

	-- Halt System --
	signal	HOLD_DIS_OF    : STD_LOGIC;
	signal	MULTI_CYCLE_OP : STD_LOGIC;
	
	-- Instruction Validation System --
	signal	VALID_INSTR    : STD_LOGIC;

	-- Control Busses --
	signal	DEC_CTRL       : STD_LOGIC_VECTOR(31 downto 0);
	signal	MS_CTRL        : STD_LOGIC_VECTOR(31 downto 0);
	signal	EX1_CTRL       : STD_LOGIC_VECTOR(31 downto 0);
	signal	CTRL_EX1_BUS   : STD_LOGIC_VECTOR(31 downto 0);
	signal	MEM_CTRL       : STD_LOGIC_VECTOR(31 downto 0);
	signal	WB_CTRL        : STD_LOGIC_VECTOR(31 downto 0);

begin

	-- #######################################################################################################
	-- ##			PIPELINE STAGE 0/1: OPERAND FETCH / INSTRUCTION DECODE                                      ##
	-- #######################################################################################################

	-- Instruction Fetch Unit --------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		OP_FETCH_UNIT: process(CLK, RES, INSTR_IN, HOLD_BUS_IN, MULTI_CYCLE_OP)
			variable IR_0, IR_1, IR_2, IR_3   : STD_LOGIC_VECTOR(31 downto 00);
			variable CYCLE_CNT                : STD_LOGIC_VECTOR(02 downto 00);
			variable	RD_CNT, WR_CNT           : STD_LOGIC_VECTOR(01 downto 00);
			variable RD_INC, WR_INC, WR_IR_EN : STD_LOGIC;
		begin

			--- Cycle Action Counter ---
			if rising_edge(CLK) then
				if (RES = '1') then -- Reset
					CYCLE_CNT := (others => '0');
				elsif (HOLD_BUS_IN(0) = '1') then -- Load counter with operand unit value
					CYCLE_CNT := HOLD_BUS_IN(3 downto 1);
				elsif (MULTI_CYCLE_OP = '1') then
					CYCLE_CNT :=  "001";
				elsif (to_integer(unsigned(CYCLE_CNT)) /= 0) then -- Decrement until zero
					CYCLE_CNT := Std_Logic_Vector(unsigned(CYCLE_CNT) - 1);
				end if;
			end if;

			--- Global IR Write Enable ---
			if rising_edge(CLK) then
				if (RES = '1') then
					WR_IR_EN := '0';
				elsif (to_integer(unsigned(CYCLE_CNT)) = 0) then
					WR_IR_EN := '1';
				else
					WR_IR_EN := '0';
				end if;
			end if;

			--- RD/WR CNT Enable & Stage Enable & Memory Request ---
			if (to_integer(unsigned(CYCLE_CNT)) > 1) or
				(HOLD_BUS_IN(0) = '1') or (MULTI_CYCLE_OP = '1') then
				RD_INC := '0';
				-- Multi-Cycle Operations: Freeze instruction fetch
				-- but keep pipeline enabled
				HOLD_DIS_OF <= not MULTI_CYCLE_OP;--'1';
				PC_HALT_OUT <= '1';
			else
				RD_INC := '1';
				HOLD_DIS_OF <= '0';
				PC_HALT_OUT <= '0';
			end if;
			if rising_edge(CLK) then -- memory request signal
				if (RES = '1') then
					INST_MREQ_OUT <= '0';
				else
					INST_MREQ_OUT <= RD_INC;
				end if;
			end if;
			if (to_integer(unsigned(CYCLE_CNT)) = 0) then
				WR_INC := '1';
			else
				WR_INC := '0';
			end if;

			--- Read/Write Address Counter ---
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

			--- Synchronous Instruction Buffer Write ---
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

			--- Asynchronous Instruction Buffer Read ---
			case (RD_CNT) is
				when "00"   => OPCODE_DATA_OUT <= IR_0;
				when "01"   => OPCODE_DATA_OUT <= IR_1;
				when "10"   => OPCODE_DATA_OUT <= IR_2;
				when "11"   => OPCODE_DATA_OUT <= IR_3;
				when others => OPCODE_DATA_OUT <= (others => '-');
			end case;

		end process OP_FETCH_UNIT;



	-- #######################################################################################################
	-- ##			PIPELINE STAGE 2: OPERAND FETCH                                                             ##
	-- #######################################################################################################

	-- Stage "Operand Fetch" Control Unit --------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		OF_CTRL_UNIT: process(CLK, RES, OPCODE_CTRL_IN, DISABLE_CYCLE, HOLD_DIS_OF)
			variable FORCE_DISABLE  : STD_LOGIC;
			variable OP_BUFFER      : STD_LOGIC_VECTOR(31 downto 0);
			variable M_CYC_CNT      : STD_LOGIC_VECTOR(04 downto 0);
		begin

			--- Opcode Decoder Connection ---
			if rising_edge(CLK) then
				if (RES = '1') then
					OP_BUFFER    := (others => '0');
					OP_ADR_OUT   <= (others => '0');
					IMM_OUT      <= (others => '0');
					SHIFT_M_OUT  <= (others => '0');
					SHIFT_C_OUT  <= (others => '0');
					M_CYC_CNT    := (others => '0');
				else
					M_CYC_CNT    := OPCODE_CTRL_IN(90 downto 86);
					OP_BUFFER    := OPCODE_CTRL_IN(31 downto 00);
					-- disable stage when branching --
					OP_BUFFER(CTRL_EN) := not (DISABLE_CYCLE or HOLD_DIS_OF);
					OP_ADR_OUT   <= OPCODE_CTRL_IN(43 downto 32);
					IMM_OUT      <= OPCODE_CTRL_IN(78 downto 47);
					SHIFT_M_OUT  <= OPCODE_CTRL_IN(80 downto 79);
					SHIFT_C_OUT  <= OPCODE_CTRL_IN(85 downto 81);
				end if;
			end if;

			--- Default Disable ---
			FORCE_DISABLE := '0';
			if (OP_BUFFER(CTRL_COND_3 downto CTRL_COND_0) = COND_NV) then
				FORCE_DISABLE := '1';
			end if;

			--- Multi-Cycle Operation Counter ---
			-- Freeze instruction fetch but keep pipeline enabled
			MULTI_CYCLE_OP <=  '0';
			if (to_integer(unsigned(OPCODE_CTRL_IN(90 downto 86))) /= 0) then
				MULTI_CYCLE_OP <= '1';
			end if;

			--- Multi-Cycle Counter Writeback ---
			OPCODE_CTRL_OUT(04 downto 00) <= M_CYC_CNT;

			--- Stage CTRL Bus ---
			DEC_CTRL <= OP_BUFFER;
			-- Disable Instruction Processing when inserting a dummy cycle and not
			-- performing a multi-cycle operation
			DEC_CTRL(CTRL_EN) <= OP_BUFFER(CTRL_EN) and (not FORCE_DISABLE);

		end process OF_CTRL_UNIT;


	-- Pipeline Stage "OPERAND FETCH" CTRL Bus ---------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		OF_CTRL_OUT <= DEC_CTRL;



	-- #######################################################################################################
	-- ##			PIPELINE STAGE 3: MULTIPLICATION & SHIFT                                                    ##
	-- #######################################################################################################

	-- Pipeline Registers ------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		STAGE_BUFFER_2: process(CLK, RES, DEC_CTRL, DISABLE_CYCLE)
		begin
			if rising_edge (CLK) then
				if (RES = '1') then
					MS_CTRL <= (others => '0');
					-- set 'never condition' for start up --
					MS_CTRL(CTRL_COND_3 downto CTRL_COND_0) <= COND_NV;
				else
					MS_CTRL <= DEC_CTRL;
					-- disable stage when branching --
					MS_CTRL(CTRL_EN) <= DEC_CTRL(CTRL_EN) and (not DISABLE_CYCLE);
				end if;
			end if;
		end process STAGE_BUFFER_2;


	-- Pipeline Stage "MULTIPLY/SHIFT" CTRL Bus --------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		MS_CTRL_OUT <= MS_CTRL;



	-- #####################################################################################################
	-- ##			PIPELINE STAGE 4: ALU OPERATION & MCR ACCESS                                              ##
	-- #####################################################################################################

	-- Pipeline Registers ------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		STAGE_BUFFER_3: process(CLK, RES, MS_CTRL, DISABLE_CYCLE)
		begin
			if rising_edge(CLK) then
				if (RES = '1') then
					EX1_CTRL <= (others => '0');
					-- set 'never condition' for start up --
					EX1_CTRL(CTRL_COND_3 downto CTRL_COND_0) <= COND_NV;
				else
					EX1_CTRL <= MS_CTRL;
					-- disable stage when branching --
					EX1_CTRL(CTRL_EN) <= MS_CTRL(CTRL_EN) and (not DISABLE_CYCLE);
				end if;
			end if;
		end process STAGE_BUFFER_3;


	-- Branch Cycle Arbiter ----------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		BR_CYCLE_ARBITER: process(CLK, RES, BRANCH_TAKEN)
			variable CA_CNT : STD_LOGIC_VECTOR(2 downto 0);
		begin

			--- Cycle Counter ---
			if rising_edge(CLK) then
				if (RES = '1') then -- reset
					CA_CNT := (others => '0');
				elsif (BRANCH_TAKEN = '1') then -- restart
					CA_CNT := Std_Logic_Vector(to_unsigned(DC_TAKEN_BRANCH, 3));
				elsif (CA_CNT /= "000") then -- decrement until zero
					CA_CNT := Std_Logic_Vector(unsigned(CA_CNT) - 1);
				end if;
			end if;

			--- Disable OF, MS and EX stage in next cycle ---
			DISABLE_CYCLE <= '0';
			if (to_integer(unsigned(CA_CNT)) /= 0) or (BRANCH_TAKEN = '1') then
				DISABLE_CYCLE <= '1';
			end if;

		end process BR_CYCLE_ARBITER;


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

				when others  => -- UNDEFINED
					EXECUTE := '0';

			end case;
			
			--- Valid Instruction Signal ---
			VALID_INSTR <= EX1_CTRL(CTRL_EN) and EXECUTE;
			
		end process COND_CHECK_SYS;


	-- Detector for automatic/manual branches ----------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		BRANCH_DETECTOR: process(EX1_CTRL, VALID_INSTR)
			variable TEMP : STD_LOGIC;
		begin
			TEMP := '0';
			if (EX1_CTRL(CTRL_RD_3 downto CTRL_RD_0) = C_PC_ADR) and (EX1_CTRL(CTRL_WB_EN) = '1') then
				TEMP := '1'; -- set if destination register is the PC
			end if;
			-- Branch Taken Signal --
			BRANCH_TAKEN <= VALID_INSTR and (EX1_CTRL(CTRL_BRANCH) or TEMP);
		end process BRANCH_DETECTOR;


	-- EX Stage CTRL_BUS and Link Control --------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		EX_CTRL_BUS_CONSTRUCTION: process(EX1_CTRL, BRANCH_TAKEN, VALID_INSTR, EXECUTE_INT_IN)
		begin

			--- CTRL_BUS for THIS stage ---
			EX1_CTRL_OUT              <= EX1_CTRL;
			EX1_CTRL_OUT(CTRL_BRANCH) <= BRANCH_TAKEN; -- insert branch taken signal
			EX1_CTRL_OUT(CTRL_EN)     <= VALID_INSTR;  -- insert current op validation

			--- CTRL_BUS for NEXT stage ---
			CTRL_EX1_BUS              <= EX1_CTRL;
			CTRL_EX1_BUS(CTRL_BRANCH) <= BRANCH_TAKEN; -- insert branch taken signal
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
	-- ##			PIPELINE STAGE 5: DATA MEMORY ACCESS                                                      ##
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


	-- Pipeline Stage "MEMORY" CTRL Bus ----------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------
		MEM_CTRL_OUT <= MEM_CTRL;



	-- #####################################################################################################
	-- ##			PIPELINE STAGE 6: DATA WRITE BACK                                                         ##
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