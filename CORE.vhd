-- ################################################
-- #         <<< STORM CORE PROCESSOR >>>         #
-- #               -- TOP ENTITY --               #
-- #       Created by Stephan Nolting (4788)      #
-- # +------------------------------------------+ #
-- # Core Components Hierarchy:                   #
-- # - CORE.vhd (this file)                       #
-- #   - STORM_CORE.vhd (package file)            #
-- #   - RES_SYNC.vhd                             #
-- #   - REG_FILE.vhd                             #
-- #   - OPERANT_UNIT.vhd                         #
-- #   - ALU.vhd                                  #
-- #     - BARREL_SHIFTER.vhd                     #
-- #     - ARITHMETICAL_UNIT.vhd                  #
-- #     - LOGICAL_UNIT.vhd                       #
-- #   - FLOW_CTRL.vhd                            #
-- #   - MCR_SYS.vhd                              #
-- #   - LOAD_STORE_UNIT.vhd                      #
-- #   - X1_OPCODE_DECODER.vhd                    #
-- # +------------------------------------------+ #
-- # Version 1.1, 18.03.2011                      #
-- ################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity CORE is
    Port (
-- ###############################################################################################
-- ##			Global Control Signals                                                              ##
-- ###############################################################################################

				RES				: in  STD_LOGIC; -- global reset input (high active)
				CLK				: in  STD_LOGIC; -- global clock input

-- ###############################################################################################
-- ##			Instruction Memory Interface                                                        ##
-- ###############################################################################################

				HALT_IF			: in  STD_LOGIC; -- halt instruction fetch
				INSTR_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- new CTRL word
				PC_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- program counter

-- ###############################################################################################
-- ##			Status Information                                                                  ##
-- ###############################################################################################

				MODE				: out STD_LOGIC_VECTOR(04 downto 0); -- current processor mode

-- ###############################################################################################
-- ##			Debugging Ports                                                                     ##
-- ###############################################################################################

				DEBUG_FLAG		: out STD_LOGIC_VECTOR(03 downto 0); -- debugging stuff
				DEBUG_REG		: out STD_LOGIC_VECTOR(15 downto 0); -- debugging stuff

-- ###############################################################################################
-- ##			Data Memory Interface                                                               ##
-- ###############################################################################################

				MREQ				: out STD_LOGIC; -- memory access in next cycle
				MEM_ADR			: out STD_LOGIC_VECTOR(31 downto 0); -- memory address
				MEM_RD_DTA		: in  STD_LOGIC_VECTOR(31 downto 0); -- data core <- memory
				MEM_WR_DTA		: out STD_LOGIC_VECTOR(31 downto 0); -- data core -> memory
				MEM_MODE			: out STD_LOGIC; -- byte/word transfer mode
				MEM_WE			: out STD_LOGIC; -- write enable
				MEM_ABORT		: in  STD_LOGIC; -- memory abort request

-- ###############################################################################################
-- ##			Interrupt Interface                                                                 ##
-- ###############################################################################################

				IRQ			: in  STD_LOGIC; -- interrupt request
				FIQ			: in  STD_LOGIC  -- fast interrupt request
			 );
end CORE;

architecture CORE_STRUCTURE of CORE is

	-- ###############################################################################################
	-- ##	DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG ##
	-- ###############################################################################################

	signal	ALU_FLAGS			: STD_LOGIC_VECTOR(03 downto 0);
	signal	CMSR					: STD_LOGIC_VECTOR(31 downto 0);
	signal	MCR_DTA_RD			: STD_LOGIC_VECTOR(31 downto 0);
	signal	MCR_DTA_WR			: STD_LOGIC_VECTOR(31 downto 0);
	signal	IMMEDIATE			: STD_LOGIC_VECTOR(31 downto 0);
	signal	OP_ADR				: STD_LOGIC_VECTOR(11 downto 0);

	-- ###############################################################################################
	-- ##			GLOBAL SIGNALS FOR ALL STAGES                                                       ##
	-- ###############################################################################################

	signal	gCLK					: STD_LOGIC; -- global clock line
	signal	gRES					: STD_LOGIC; -- global reset line
	signal	INT_EXECUTE			: STD_LOGIC; -- execute interrupt
	signal	INT_VECTOR_BUS		: STD_LOGIC_VECTOR(04 downto 0); -- interrupt address

	-- ###############################################################################################
	-- ##			SIGNALS FOR PIPELINE STAGE 1: OPERAND FETCH / INSTRUCITON DECODE                    ##
	-- ###############################################################################################

	signal	OF_CTRL				: STD_LOGIC_VECTOR(31 downto 0); -- OF stage control lines
	signal	OF_OP_A				: STD_LOGIC_VECTOR(31 downto 0); -- operant A
	signal	OF_OP_B				: STD_LOGIC_VECTOR(31 downto 0); -- operant B
	signal	OF_OP_C				: STD_LOGIC_VECTOR(31 downto 0); -- operant C
	signal	OP_CONF_HALT		: STD_LOGIC; -- HALT-signal for mem-read-conflict
	signal	PC_HALT				: STD_LOGIC; -- halt program counter
	signal	OF_OP_A_OUT			: STD_LOGIC_VECTOR(31 downto 0); -- operand A output
	signal	OF_OP_B_OUT			: STD_LOGIC_VECTOR(31 downto 0); -- operand B output
	signal	OF_BP1_OUT			: STD_LOGIC_VECTOR(31 downto 0); -- bypass 1 output
	signal	SHIFT_VAL			: STD_LOGIC_VECTOR(04 downto 0); -- shift value
	signal	SHIFT_MOD			: STD_LOGIC_VECTOR(01 downto 0); -- shift mode
	signal	OPC_A					: STD_LOGIC_VECTOR(15 downto 0); -- opcode decoder input
	signal	OPC_B					: STD_LOGIC_VECTOR(99 downto 0); -- opcode decoder output
	signal	OP_DATA				: STD_LOGIC_VECTOR(31 downto 0); -- opcode decoder INSTR input

	-- ###############################################################################################
	-- ##			SIGNALS FOR PIPELINE STAGE 2: EXECUTION                                             ##
	-- ###############################################################################################

	signal	EX1_CTRL				: STD_LOGIC_VECTOR(31 downto 0); -- EX stage control lines
	signal	EX_BP1_OUT			: STD_LOGIC_VECTOR(31 downto 0); -- bypass 1 register
	signal	EX_ALU_OUT			: STD_LOGIC_VECTOR(31 downto 0); -- alu result output
	signal	ALU_FW_PATH			: STD_LOGIC_VECTOR(38 downto 0); -- alu forwarding path

	-- ###############################################################################################
	-- ##			SIGNALS FOR PIPELINE STAGE 3: MEMORY ACCESS                                         ##
	-- ###############################################################################################

	signal	MEM_CTRL				: STD_LOGIC_VECTOR(31 downto 0); -- MEM stage control lines
	signal	MEM_DATA				: STD_LOGIC_VECTOR(31 downto 0);
	signal	MEM_DTA_OUT       : STD_LOGIC_VECTOR(31 downto 0); -- mem.data and bp2 register
	signal	MEM_BP_OUT			: STD_LOGIC_VECTOR(31 downto 0); -- mem.data and bp2 register
	signal	MEM_FW_PATH			: STD_LOGIC_VECTOR(36 downto 0); -- memory forwarding path
	signal	SHIFT_VAL_BUFF		: STD_LOGIC_VECTOR(04 downto 0);
	signal	PC_1, PC_2			: STD_LOGIC_VECTOR(31 downto 0); -- delayed/current program counter
	
	-- ###############################################################################################
	-- ##			SIGNALS FOR PIPELINE STAGE 4: WRITE BACK                                            ##
	-- ###############################################################################################

	signal	WB_CTRL				: STD_LOGIC_VECTOR(31 downto 0); -- WB stage control lines



begin
	-- #######################################################################################################
	-- ##			GLOBAL CONTROL FOR ALL STAGES                                                               ##
	-- #######################################################################################################

	-- Reset Syncronizer
	-- ------------------------------------------------------------------------------
	gCLK <= CLK;
	Reset_Synchronizer:
	RES_SYNC
		port map	(	CLK		=> CLK,								-- external clock
						RES_IN	=> RES,								-- external reset
						RES_OUT	=> gRES								-- global active high reset
					);



	-- Instruction Decoder
	-- ------------------------------------------------------------------------------
	Instruction_Decoder:
	X1_OPCODE_DECODER
		port map	(
						OPCODE_DATA_IN  => OP_DATA,				-- current instruction word
						OPCODE_CTRL_IN  => OPC_A,					-- control feedback input
						OPCODE_CTRL_OUT => OPC_B					-- control lines output
					);



	-- Operation Flow Control System
	-- ------------------------------------------------------------------------------
	Operation_Flow_Control:
	FLOW_CTRL
		port map	(
						RES              => gRES,					-- global active high reset
						CLK              => gCLK,					-- global clock net
						INSTR_IN			  => INSTR_IN,				-- external instruction input
						OPCODE_DATA_OUT  => OP_DATA,				-- instruction register output
						OPCODE_CTRL_IN	  => OPC_B,					-- control lines input
						OPCODE_CTRL_OUT  => OPC_A,					-- control feedback output
						OP_CONF_HALT_IN  => OP_CONF_HALT,		-- resource conflict in
						EXT_HALT_IN		  => HALT_IF,				-- external halt instr fetch request
						PC_HALT_OUT		  => PC_HALT,				-- halt instruction fetch output
						SREG_IN          => CMSR,					-- current machine status register
						INT_VECTOR_IN	  => INT_VECTOR_BUS,		-- interrupt jump vector input
						EXECUTE_INT_IN	  => INT_EXECUTE,			-- execute interupt request
						OP_ADR_OUT       => OP_ADR,				-- operand register addresses
						IMM_OUT          => IMMEDIATE,			-- immediate output
						SHIFT_M_OUT      => SHIFT_MOD,			-- shift mode output
						SHIFT_C_OUT      => SHIFT_VAL,			-- immediate shif value output
						OF_CTRL_OUT      => OF_CTRL,				-- stage control OF
						EX1_CTRL_OUT     => EX1_CTRL,				-- stage control EX
						MEM_CTRL_OUT     => MEM_CTRL,				-- stage control MA
						WB_CTRL_OUT      => WB_CTRL				-- stage control WB
					);
					

	-- Debugging Stuff
	-- ------------------------------------------------------------------------------
	DEBUG_FLAG <= CMSR(31 downto 28);

	-- Machine Control System
	-- ------------------------------------------------------------------------------
	Machine_Control_System:
	MCR_SYS
		port map	(
						CLK				=> gCLK,					-- global clock net
						RES				=> gRES,					-- global active high reset
						CTRL				=> EX1_CTRL,			-- stage flow control
						HALT_IN			=> PC_HALT,				-- halt program counter
						INT_TKN_OUT		=> INT_EXECUTE,		-- execute interrupt output
						INT_VEC_OUT		=> INT_VECTOR_BUS,	-- interrupt jump vector output
						FLAG_IN			=> ALU_FLAGS,			-- alu flags input
						CMSR_OUT			=> CMSR,					-- current machine status register
						PC1_OUT			=> PC_1,					-- current program counter
						PC2_OUT			=> PC_2,					-- delayed progeam counter
						MCR_DATA_IN		=> MCR_DTA_WR,			-- mcr write data input
						MCR_DATA_OUT	=> MCR_DTA_RD,			-- mcr read data output
						EX_FIQ_IN		=> FIQ,					-- external fast interrupt request
						EX_IRQ_IN		=> IRQ,					-- external interrupt request
						EX_ABT_IN		=> MEM_ABORT			-- external memory abort request
					);

	PC_OUT <= PC_1; -- current program counter output					
	MODE   <= CMSR(SREG_MODE_4 downto SREG_MODE_0); -- current processor mode


	-- #######################################################################################################
	-- ##			PIPELINE STAGE 1/4: OPERAND FETCH / INSTRUCITON DECODE / DATA WRITE BACK                    ##
	-- #######################################################################################################

	-- Data Register File
	-- ------------------------------------------------------------------------------
	Register_File:
	REG_FILE
		port map	(
						CLK				=> gCLK,					-- global clock net
						RES				=> gRES,					-- global active high reset
						CTRL_IN			=> WB_CTRL,				-- stage flow control
						OP_ADR_IN		=> OP_ADR,				-- operand addresses
						MODE_IN			=> CMSR(SREG_MODE_4 downto SREG_MODE_0), -- current processor mode
						DEBUG_R0			=> DEBUG_REG(07 downto 00), -- debugging stuff
						DEBUG_R1			=> DEBUG_REG(15 downto 08), -- debugging stuff
						MEM_DATA_IN		=> MEM_DTA_OUT,		-- memory data path
						BP2_DATA_IN		=> MEM_BP_OUT,			-- alu data path
						PC_IN				=> PC_1,					-- current program counter
						OP_A_OUT			=> OF_OP_A,				-- register A output
						OP_B_OUT			=> OF_OP_B,				-- register B output
						OP_C_OUT       => OF_OP_C				-- register C output
					);

	-- Operant Fetch Unit
	-- ------------------------------------------------------------------------------
	Operand_Fetch_Unit:
	OPERAND_UNIT
		port map	(
						CTRL_IN			=> OF_CTRL,				-- stage flow control
						OP_ADR_IN		=> OP_ADR,				-- register operand address
						CONF_HALT_OUT	=> OP_CONF_HALT,		-- resource write conflict
						OP_A_IN			=> OF_OP_A,				-- register A input
						OP_B_IN			=> OF_OP_B,				-- register B input
						OP_C_IN			=> OF_OP_C,				-- register C input
						SHIFT_VAL_IN	=> SHIFT_VAL,			-- immediate shift value in
						PC1_IN			=> PC_1, 				-- current program counter
						PC2_IN			=> PC_2,					-- delayed program counter
						IMM_IN			=> IMMEDIATE,			-- immediate value
						IS_INT_IN		=> INT_EXECUTE,		-- execute interrupt request
						OP_A_OUT			=> OF_OP_A_OUT,		-- operand A data output
						OP_B_OUT			=> OF_OP_B_OUT,		-- operant B data output
						SHIFT_VAL_OUT	=> SHIFT_VAL_BUFF,	-- shift operand output
						BP1_OUT			=> OF_BP1_OUT,			-- bypass data output
						ALU_FW_IN		=> ALU_FW_PATH,		-- alu forwarding path
						MEM_FW_IN		=> MEM_FW_PATH			-- memory forwarding path
					);

	-- #######################################################################################################
	-- ##			PIPELINE STAGE 0/2: ALU OPERATION / INSTRUCTION FETCH / MCR ACCESS                          ##
	-- #######################################################################################################

	-- Arithmetical/Logical Unit
	-- ------------------------------------------------------------------------------
	Operator:
	ALU
		port map	(
						CLK				=> gCLK,					-- global clock net
						RES				=> gRES,					-- global active high reset
						CTRL				=> EX1_CTRL,			-- stage flow control
						OP_A_IN			=> OF_OP_A_OUT,		-- operand A input
						OP_B_IN			=> OF_OP_B_OUT,		-- operant B input
						BP1_IN			=> OF_BP1_OUT,			-- bypass data input
						BP1_OUT			=> EX_BP1_OUT,			-- bypass data output
						ALU_RES_OUT		=> EX_ALU_OUT,			-- operation result
						DATA_OUT			=> MEM_DATA,			-- memory data output
						SHIFT_V_IN		=> SHIFT_VAL_BUFF,	-- shift value input
						SHIFT_M_IN		=> SHIFT_MOD,			-- shift mode input
						FLAG_IN			=> CMSR(31 downto 28), -- sreg alu flags input
						FLAG_OUT			=> ALU_FLAGS,			-- alu flags output
						MCR_DTA_OUT		=> MCR_DTA_WR,			-- mcr write data output
						MCR_DTA_IN		=> MCR_DTA_RD,			-- mcr read data input
						MREQ_OUT			=> MREQ,					-- memory access in next cycle
						ALU_FW_OUT		=> ALU_FW_PATH			-- alu forwarding path
					);


	-- #######################################################################################################
	-- ##			PIPELINE STAGE 3: MEMORY ACCESS                                                             ##
	-- #######################################################################################################

	-- Data Memory Access System
	-- ------------------------------------------------------------------------------
	Data_Memory_Access:
	LOAD_STORE_UNIT
		port map	(
						CLK				=> gCLK,					-- global clock net
						RES				=> gRES,					-- global active high reset
						CTRL_IN			=> MEM_CTRL,			-- stage flow control
						MEM_DATA_IN		=> MEM_DATA,			-- memory write data input
						MEM_ADR_IN		=> EX_ALU_OUT,			-- memory address input
						MEM_BP_IN		=> EX_BP1_OUT,			-- memory bypass data input
						DATA_OUT			=> MEM_DTA_OUT,		-- memory read data output
						BP_OUT			=> MEM_BP_OUT,			-- memory bypass data output
						LDST_FW_OUT		=> MEM_FW_PATH,		-- mem forwarding path
						XMEM_ADR			=> MEM_ADR,				-- mem address
						XMEM_RD_DTA		=> MEM_RD_DTA,			-- mem read data
						XMEM_WR_DTA		=> MEM_WR_DTA,			-- mem write data
						XMEM_WE			=> MEM_WE,				-- mem write enable
						XMEM_MODE		=> MEM_MODE				-- byte/word transfer
					);

end CORE_STRUCTURE;