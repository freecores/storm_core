-- #######################################################################################################
-- #                           <<< STORM CORE PROCESSOR by Stephan Nolting >>>                           #
-- # *************************************************************************************************** #
-- #      ~ STORM Core Top Entity ~      | The STORM core is a powerfull 32 bit open source RISC         #
-- #           File Hierarchy            | processor, partly compatible to the ARM architecture.         #
-- # ------------------------------------+ This is the top entity of the core itself. Please refer to    #
-- # Core File Hierarchy:                | the core's data sheet for more information.                   #
-- # - CORE.vhd (this file)              |                                                               #
-- #   + STORM_CORE.vhd (package file)   +---------------------------------------------------------------#
-- #   - REG_FILE.vhd                    |                                                               #
-- #   - OPERANT_UNIT.vhd                |   SSSS TTTTT  OOO  RRRR  M   M        CCCC  OOO  RRRR  EEEEE  #
-- #   - MS_UNIT.vhd                     |  S       T   O   O R   R MM MM       C     O   O R   R E      #
-- #     - MULTIPLICATION_UNIT.vhd       |   SSS    T   O   O RRRR  M M M  ###  C     O   O RRRR   EEE   #
-- #   -   BARREL_SHIFTER.vhd            |      S   T   O   O R  R  M   M       C     O   O R  R  E      #
-- #   - ALU.vhd                         |  SSSS    T    OOO  R   R M   M        CCCC  OOO  R   R EEEEE  #
-- #     - ARITHMETICAL_UNIT.vhd         |                                                               #
-- #     - LOGICAL_UNIT.vhd              +-------------------------------------------------------------- #
-- #   - FLOW_CTRL.vhd                   | The STORM Core Processor was created by Stephan Nolting       #
-- #   - WB_UNIT.vhd                     | Published at whttp://opencores.org/project,storm_core         #
-- #   - MCR_SYS.vhd                     | Contact me:                                                   #
-- #   - LOAD_STORE_UNIT.vhd             | -> stnolting@googlemail.com                                   #
-- #   - X1_OPCODE_DECODER.vhd           | -> stnolting@web.de                                           #
-- # *************************************************************************************************** #
-- # Version 1.4, 02.09.2011                                                                             #
-- #######################################################################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity CORE is
    Port (
-- ###############################################################################################
-- ##       Global Control Signals                                                              ##
-- ###############################################################################################

				RES             : in  STD_LOGIC; -- global reset input (high active)
				CLK             : in  STD_LOGIC; -- global clock input

-- ###############################################################################################
-- ##       Status and Control                                                                  ##
-- ###############################################################################################

				HALT            : in  STD_LOGIC; -- halt processor
				MODE            : out STD_LOGIC_VECTOR(04 downto 0); -- current processor mode

-- ###############################################################################################
-- ##      Data Memory Interface                                                                ##
-- ###############################################################################################

				D_MEM_REQ       : out STD_LOGIC; -- memory access in next cycle
				D_MEM_ADR       : out STD_LOGIC_VECTOR(31 downto 0); -- data address
				D_MEM_RD_DTA    : in  STD_LOGIC_VECTOR(31 downto 0); -- read data
				D_MEM_WR_DTA    : out STD_LOGIC_VECTOR(31 downto 0); -- write data
				D_MEM_DQ        : out STD_LOGIC_VECTOR(01 downto 0); -- data transfer quantity
				D_MEM_RW        : out STD_LOGIC; -- read/write signal
				D_MEM_ABORT     : in  STD_LOGIC; -- memory abort request

-- ###############################################################################################
-- ##      Instruction Memory Interface                                                         ##
-- ###############################################################################################

				I_MEM_REQ       : out STD_LOGIC; -- memory access in next cycle
				I_MEM_ADR       : out STD_LOGIC_VECTOR(31 downto 0); -- instruction address
				I_MEM_RD_DTA    : in  STD_LOGIC_VECTOR(31 downto 0); -- read data
				I_MEM_DQ		: out STD_LOGIC_VECTOR(01 downto 0); -- data transfer quantity
				I_MEM_ABORT     : in  STD_LOGIC; -- memory abort request

-- ###############################################################################################
-- ##      Interrupt Interface                                                                  ##
-- ###############################################################################################

				IRQ             : in  STD_LOGIC; -- interrupt request
				FIQ             : in  STD_LOGIC  -- fast interrupt request
			 );
end CORE;

architecture CORE_STRUCTURE of CORE is

	-- ###############################################################################################
	-- ##           Internal Signals                                                                ##
	-- ###############################################################################################

	signal ALU_FLAGS        : STD_LOGIC_VECTOR(03 downto 0); -- CMSR/SMSR flag bits
	signal CMSR             : STD_LOGIC_VECTOR(31 downto 0); -- current machine status register
	signal MCR_DTA_RD       : STD_LOGIC_VECTOR(31 downto 0); -- machine control register read data
	signal MCR_DTA_WR       : STD_LOGIC_VECTOR(31 downto 0); -- machine control register write data
	signal IMMEDIATE        : STD_LOGIC_VECTOR(31 downto 0); -- immediate value
	signal OP_ADR           : STD_LOGIC_VECTOR(14 downto 0); -- operand register adresses and enables
	signal MS_CTRL          : STD_LOGIC_VECTOR(31 downto 0); -- multishifter control lines
	signal BP_MS            : STD_LOGIC_VECTOR(31 downto 0); -- multishifter bypass
	signal OP_A_MS          : STD_LOGIC_VECTOR(31 downto 0); -- operand A for multishifter
	signal OP_B_MS          : STD_LOGIC_VECTOR(31 downto 0); -- operand B for multishifter
	signal MS_CARRY         : STD_LOGIC;                     -- multishifter carry output
	signal MS_OVFL          : STD_LOGIC;                     -- multishifter overflow output
	signal MS_FW_PATH       : STD_LOGIC_VECTOR(40 downto 0); -- multishifter forwarding bus
	signal WB_FW_PATH       : STD_LOGIC_VECTOR(40 downto 0); -- write back unit forwarding bus
	signal gCLK             : STD_LOGIC;                     -- global clock line
	signal gRES             : STD_LOGIC;                     -- global reset line
	signal G_HALT           : STD_LOGIC;                     -- gloabl halt line
	signal INT_EXECUTE      : STD_LOGIC;                     -- execute interrupt
	signal HALT_BUS         : STD_LOGIC_VECTOR(02 downto 0); -- temporal data dependencie bus
	signal OF_CTRL          : STD_LOGIC_VECTOR(31 downto 0); -- OF stage control lines
	signal OF_OP_A          : STD_LOGIC_VECTOR(31 downto 0); -- operant A
	signal OF_OP_B          : STD_LOGIC_VECTOR(31 downto 0); -- operant B
	signal OF_OP_C          : STD_LOGIC_VECTOR(31 downto 0); -- operant C
	signal PC_HALT          : STD_LOGIC;                     -- halt instruction fetch
	signal OF_OP_A_OUT      : STD_LOGIC_VECTOR(31 downto 0); -- operand A output
	signal OF_OP_B_OUT      : STD_LOGIC_VECTOR(31 downto 0); -- operand B output
	signal OF_BP1_OUT       : STD_LOGIC_VECTOR(31 downto 0); -- bypass 1 output
	signal SHIFT_VAL        : STD_LOGIC_VECTOR(04 downto 0); -- shift value
	signal SHIFT_MOD        : STD_LOGIC_VECTOR(01 downto 0); -- shift mode
	signal OPC_A            : STD_LOGIC_VECTOR(15 downto 0); -- opcode decoder input
	signal OPC_B            : STD_LOGIC_VECTOR(99 downto 0); -- opcode decoder output
	signal OP_DATA          : STD_LOGIC_VECTOR(31 downto 0); -- opcode decoder INSTR input
	signal EX1_CTRL         : STD_LOGIC_VECTOR(31 downto 0); -- EX stage control lines
	signal EX_BP1_OUT       : STD_LOGIC_VECTOR(31 downto 0); -- bypass 1 register
	signal EX_ALU_OUT       : STD_LOGIC_VECTOR(31 downto 0); -- alu result output
	signal ALU_FW_PATH      : STD_LOGIC_VECTOR(41 downto 0); -- alu forwarding path
	signal EX_BP_OUT        : STD_LOGIC_VECTOR(31 downto 0);
	signal EX_ADR_OUT       : STD_LOGIC_VECTOR(31 downto 0);
	signal EX_RES_OUT       : STD_LOGIC_VECTOR(31 downto 0);
	signal MEM_CTRL         : STD_LOGIC_VECTOR(31 downto 0); -- MEM stage control lines
	signal MEM_DATA         : STD_LOGIC_VECTOR(31 downto 0);
	signal MEM_DTA_OUT      : STD_LOGIC_VECTOR(31 downto 0); -- mem_data and bp2 register
	signal MEM_ADR_OUT      : STD_LOGIC_VECTOR(31 downto 0); -- mem_data address bypass
	signal MEM_BP_OUT       : STD_LOGIC_VECTOR(31 downto 0); -- mem_data and bp2 register
	signal MEM_FW_PATH      : STD_LOGIC_VECTOR(40 downto 0); -- memory forwarding path
	signal SHIFT_VAL_BUFF   : STD_LOGIC_VECTOR(04 downto 0); -- shift value for barrelshifter
	signal REG_PC           : STD_LOGIC_VECTOR(31 downto 0); -- PC value for manual operations
	signal JMP_PC           : STD_LOGIC_VECTOR(31 downto 0); -- PC value for branches
	signal LNK_PC           : STD_LOGIC_VECTOR(31 downto 0); -- PC value for linking
	signal INF_PC           : STD_LOGIC_VECTOR(31 downto 0); -- PC value instruction fetch
	signal EXC_PC           : STD_LOGIC_VECTOR(31 downto 0); -- PC value for exceptions
	signal WB_CTRL          : STD_LOGIC_VECTOR(31 downto 0); -- WB stage control lines
	signal WB_DATA_LINE     : STD_LOGIC_VECTOR(31 downto 0); -- data write back line

begin
	-- #######################################################################################################
	-- ##           GLOBAL CONTROL FOR ALL STAGES                                                           ##
	-- #######################################################################################################

	-- Global CLOCK, HALT and RESET Network
	-- ------------------------------------------------------------------------------
		gCLK   <= CLK;
		gRES   <= RES;
		G_HALT <= HALT; -- maybe try clock gating?!



	-- Instruction Decoder
	-- ------------------------------------------------------------------------------
		Instruction_Decoder:
		X1_OPCODE_DECODER
			port map	(
							OPCODE_DATA_IN  => OP_DATA,			-- current instruction word
							OPCODE_CTRL_IN  => OPC_A,			-- control feedback input
							OPCODE_CTRL_OUT => OPC_B			-- control lines output
						);


	-- Operation Flow Control System
	-- ------------------------------------------------------------------------------
		Operation_Flow_Control:
		FLOW_CTRL
			port map	(
							RES              => gRES,			-- global active high reset
							CLK              => gCLK,			-- global clock net
							G_HALT           => G_HALT,			-- global halt signal
							INSTR_IN         => I_MEM_RD_DTA,	-- instruction input
							INST_MREQ_OUT    => I_MEM_REQ,		-- instr fetch memory request
							OPCODE_DATA_OUT  => OP_DATA,		-- instruction register output
							OPCODE_CTRL_IN   => OPC_B,			-- control lines input
							OPCODE_CTRL_OUT  => OPC_A,			-- control feedback output
							PC_HALT_OUT      => PC_HALT,		-- halt instruction fetch output
							SREG_IN          => CMSR,			-- current machine status register
							EXECUTE_INT_IN   => INT_EXECUTE,	-- execute interupt request
							HOLD_BUS_IN      => HALT_BUS,		-- number of bubbles
							OP_ADR_OUT       => OP_ADR,			-- operand register addresses
							IMM_OUT          => IMMEDIATE,		-- immediate output
							SHIFT_M_OUT      => SHIFT_MOD,		-- shift mode output
							SHIFT_C_OUT      => SHIFT_VAL,		-- immediate shif value output
							OF_CTRL_OUT      => OF_CTRL,		-- stage control OF
							MS_CTRL_OUT      => MS_CTRL,		-- stage control MS
							EX1_CTRL_OUT     => EX1_CTRL,		-- stage control EX
							MEM_CTRL_OUT     => MEM_CTRL,		-- stage control MA
							WB_CTRL_OUT      => WB_CTRL			-- stage control WB
						);


	-- Machine Control System
	-- ------------------------------------------------------------------------------
		Machine_Control_System:
		MCR_SYS
			port map	(
							CLK             => gCLK,				-- global clock net
							G_HALT          => G_HALT,				-- global halt signal
							RES             => gRES,				-- global active high reset
							CTRL            => EX1_CTRL,			-- stage control
							HALT_IN         => PC_HALT,				-- halt program counter
							INT_TKN_OUT     => INT_EXECUTE,			-- execute interrupt output
							FLAG_IN         => ALU_FLAGS,			-- alu flags input
							CMSR_OUT        => CMSR,				-- current machine status register
							REG_PC_OUT      => REG_PC,				-- PC value for manual operations
							JMP_PC_OUT      => JMP_PC,				-- PC value for branches
							LNK_PC_OUT      => LNK_PC,				-- PC value for linking
							INF_PC_OUT      => INF_PC,				-- PC value for instruction fetch
							EXC_PC_OUT      => EXC_PC,				-- PC value for exceptions
							MCR_DATA_IN     => MCR_DTA_WR,			-- mcr write data input
							MCR_DATA_OUT    => MCR_DTA_RD,			-- mcr read data output
							EX_FIQ_IN       => FIQ,					-- external fast interrupt request
							EX_IRQ_IN       => IRQ,					-- external interrupt request
							EX_ABT_IN       => D_MEM_ABORT,			-- external D memory abort request
							EX_PRF_IN       => I_MEM_ABORT			-- external I memory abort request
						);


	-- External Interface
	-- ------------------------------------------------------------------------------
		I_MEM_ADR   <= INF_PC;
		I_MEM_DQ    <= DQ_WORD;


	-- #######################################################################################################
	-- ##           PIPELINE STAGE 2: OPERAND FETCH & INSTRUCITON DECODE                                    ##
	-- #######################################################################################################

	-- Data Register File
	-- ------------------------------------------------------------------------------
		Register_File:
		REG_FILE
			port map	(
							CLK             => gCLK,				-- global clock net
							G_HALT          => G_HALT,				-- global halt signal
							RES             => gRES,				-- global active high reset
							CTRL_IN         => WB_CTRL,				-- stage control
							OP_ADR_IN       => OP_ADR,				-- operand addresses
							MODE_IN         => CMSR(SREG_MODE_4 downto SREG_MODE_0), -- current processor mode
							WB_DATA_IN      => WB_DATA_LINE,		-- write back bus
							REG_PC_IN       => REG_PC,				-- PC for manual operations
							OP_A_OUT        => OF_OP_A,				-- register A output
							OP_B_OUT        => OF_OP_B,				-- register B output
							OP_C_OUT        => OF_OP_C				-- register C output
						);

	-- Operant Fetch Unit
	-- ------------------------------------------------------------------------------
		Operand_Fetch_Unit:
		OPERAND_UNIT
			port map	(
							CTRL_IN         => OF_CTRL,			-- stage flow control
							OP_ADR_IN       => OP_ADR,			-- register operand address
							OP_A_IN         => OF_OP_A,			-- register A input
							OP_B_IN         => OF_OP_B,			-- register B input
							OP_C_IN         => OF_OP_C,			-- register C input
							SHIFT_VAL_IN    => SHIFT_VAL,		-- immediate shift value in
							REG_PC_IN       => REG_PC, 			-- PC value for manual operations
							JMP_PC_IN       => JMP_PC,			-- PC value for branches
							LNK_PC_IN       => LNK_PC,			-- PC value for linking
							IMM_IN          => IMMEDIATE,		-- immediate value
							OP_A_OUT        => OF_OP_A_OUT,		-- operand A data output
							OP_B_OUT        => OF_OP_B_OUT,		-- operant B data output
							SHIFT_VAL_OUT   => SHIFT_VAL_BUFF,	-- shift operand output
							BP1_OUT         => OF_BP1_OUT,		-- bypass data output
							HOLD_BUS_OUT    => HALT_BUS,		-- insert n bubbles
							MSU_FW_IN       => MS_FW_PATH,		-- ms forwarding path
							ALU_FW_IN       => ALU_FW_PATH,		-- alu forwarding path
							MEM_FW_IN       => MEM_FW_PATH,		-- memory forwarding path
							WB_FW_IN        => WB_FW_PATH		-- write back forwarding path
						);


	-- #######################################################################################################
	-- ##           PIPELINE STAGE 3: MULTIPLICATION & SHIFT                                                ##
	-- #######################################################################################################

	-- Multiply/Shift Unit
	-- ------------------------------------------------------------------------------
		Multishifter:
		MS_UNIT
			port map	(
							CLK             => gCLK,				-- global clock line
							G_HALT          => G_HALT,				-- global halt signal
							RES             => gRES,				-- global reset line
							CTRL            => MS_CTRL,				-- stage control
							OP_A_IN         => OF_OP_A_OUT,			-- operant a input
							OP_B_IN         => OF_OP_B_OUT,			-- operant b input
							BP_IN           => OF_BP1_OUT,			-- bypass input
							CARRY_IN        => CMSR(SREG_C_FLAG),	-- carry input
							SHIFT_V_IN      => SHIFT_VAL_BUFF,		-- shift value in
							SHIFT_M_IN      => SHIFT_MOD,			-- shift mode in
							OP_A_OUT        => OP_A_MS,				-- operant a bypass output
							BP_OUT          => BP_MS,				-- bypass output
							RESULT_OUT      => OP_B_MS,				-- operation result
							CARRY_OUT       => MS_CARRY,			-- operation carry signal
							OVFL_OUT        => MS_OVFL,				-- operation overflow signal
							MSU_FW_OUT      => MS_FW_PATH			-- forwarding path
						);


	-- #######################################################################################################
	-- ##           PIPELINE STAGE 4: ALU OPERATION & MCR ACCESS                                            ##
	-- #######################################################################################################

	-- Arithmetical/Logical Unit
	-- ------------------------------------------------------------------------------
		Operator:
		ALU
			port map	(
							CLK             => gCLK,				-- global clock net
							G_HALT          => G_HALT,				-- global halt signal
							RES             => gRES,				-- global active high reset
							CTRL            => EX1_CTRL,			-- stage control
							OP_A_IN         => OP_A_MS,				-- operand A input
							OP_B_IN         => OP_B_MS,				-- operant B input
							BP1_IN          => BP_MS,				-- bypass data input
							BP1_OUT         => EX_BP1_OUT,			-- bypass data output
							ADR_OUT         => EX_ADR_OUT,			-- memory access address
							RESULT_OUT      => EX_RES_OUT,			-- EX result data
							FLAG_IN         => CMSR(31 downto 28),	-- sreg alu flags input
							FLAG_OUT        => ALU_FLAGS,			-- alu flags output
							EXC_PC_IN       => EXC_PC,				-- pc for INT_LINK
							INT_CALL_IN     => INT_EXECUTE,			-- this is an interrupt call	
							MS_CARRY_IN     => MS_CARRY,			-- ms carry output
							MS_OVFL_IN      => MS_OVFL,				-- ms overflow output
							MCR_DTA_OUT     => MCR_DTA_WR,			-- mcr write data output
							MCR_DTA_IN      => MCR_DTA_RD,			-- mcr read data input
							ALU_FW_OUT      => ALU_FW_PATH			-- alu forwarding path
						);


	-- #####################################################################################################
	-- ##           PIPELINE STAGE 5: DATA MEMORY ACCESS                                                  ##
	-- #####################################################################################################

	-- Memory Access System
	-- ------------------------------------------------------------------------------
		Memory_Access:
		LOAD_STORE_UNIT
			port map	(
							CLK             => gCLK,			-- global clock net
							G_HALT          => G_HALT,			-- global halt signal
							RES             => gRES,			-- global reset net
							CTRL_IN         => MEM_CTRL,		-- stage control
							MEM_DATA_IN     => EX_RES_OUT,		-- EX data result
							MEM_ADR_IN      => EX_ADR_OUT,		-- memory access address
							MEM_BP_IN       => EX_BP1_OUT,		-- bp/write data input
							MODE_IN         => CMSR(SREG_MODE_4 downto SREG_MODE_0), -- current processor mode
							ADR_OUT         => MEM_ADR_OUT,		-- address bypass output
							BP_OUT          => MEM_BP_OUT,		-- bypass(data) output
							LDST_FW_OUT     => MEM_FW_PATH,		-- memory forwarding path
							XMEM_MODE       => MODE,            -- processor mode for access
							XMEM_ADR        => D_MEM_ADR,		-- D memory address output
							XMEM_WR_DTA     => D_MEM_WR_DTA,	-- memory write data output
							XMEM_ACC_REQ    => D_MEM_REQ,		-- access request
							XMEM_RW         => D_MEM_RW,		-- read/write
							XMEM_DQ         => D_MEM_DQ			-- memory data quantity
						);


	-- #####################################################################################################
	-- ##           PIPELINE STAGE 6: DATA WRITE BACK                                                     ##
	-- #####################################################################################################

	-- Data Write Back System
	-- ------------------------------------------------------------------------------
		Data_Write_Back:
		WB_UNIT
			port map	(
							CLK             => gCLK,			-- global clock net
							G_HALT          => G_HALT,			-- global halt signal
							RES             => gRES,			-- global reset net
							CTRL_IN         => WB_CTRL,			-- stage control
							ALU_DATA_IN     => MEM_BP_OUT,		-- alu data input
							ADR_BUFF_IN     => MEM_ADR_OUT,		-- address bypass input 
							WB_DATA_OUT     => WB_DATA_LINE,	-- data write back line
							XMEM_RD_DATA    => D_MEM_RD_DTA,	-- memory read data
							WB_FW_OUT       => WB_FW_PATH		-- forwarding path
						);
	
end CORE_STRUCTURE;