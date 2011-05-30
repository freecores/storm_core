-- ################################################
-- #         <<< STORM CORE PROCESSOR >>>         #
-- #               -- TOP ENTITY --               #
-- #       Created by Stephan Nolting (4788)      #
-- # +------------------------------------------+ #
-- #  Core Components Hierarchy:                  #
-- #  - CORE.vhd (this file)                      #
-- #    - STORM_CORE.vhd (package file)           #
-- #    - RES_SYNC.vhd                            #
-- #    - REG_FILE.vhd                            #
-- #    - REG_FILE.vhd                            #
-- #      - ADR_TRANSLATOR (same file)            #
-- #    - OPERANT_UNIT.vhd                        #
-- #    - MS_UNIT.vhd                             #
-- #      - MULTIPLICATION_UNIT.vhd               #
-- #      - BARREL_SHIFTER.vhd                    #
-- #    - ALU.vhd                                 #
-- #      - ARITHMETICAL_UNIT.vhd                 #
-- #      - LOGICAL_UNIT.vhd                      #
-- #    - FLOW_CTRL.vhd                           #
-- #    - WB_UNIT.vhd                             #
-- #    - MCR_SYS.vhd                             #
-- #    - LOAD_STORE_UNIT.vhd                     #
-- #    - X1_OPCODE_DECODER.vhd                   #
-- # +------------------------------------------+ #
-- # Version 1.2, 22.04.2011                      #
-- ################################################

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

				RES				: in  STD_LOGIC; -- global reset input (high active)
				CLK				: in  STD_LOGIC; -- global clock input

-- ###############################################################################################
-- ##       Instruction Memory Interface (only used for debugging)                              ##
-- ###############################################################################################

				HALT				: in  STD_LOGIC; -- halt processor
				PC_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- program counter

-- ###############################################################################################
-- ##       Status Information                                                                  ##
-- ###############################################################################################

				MODE				: out STD_LOGIC_VECTOR(04 downto 0); -- current processor mode

-- ###############################################################################################
-- ##       Debugging Ports                                                                     ##
-- ###############################################################################################

				DEBUG_FLAG		: out STD_LOGIC_VECTOR(03 downto 0); -- ignore this port
				DEBUG_REG		: out STD_LOGIC_VECTOR(15 downto 0); -- ignore this port
				DEBUG_INSTR		: out STD_LOGIC_VECTOR(31 downto 0); -- ignore this port

-- ###############################################################################################
-- ##      Memory Interface                                                                     ##
-- ###############################################################################################

				MREQ				: out STD_LOGIC; -- memory access in next cycle
				MEM_ADR			: out STD_LOGIC_VECTOR(31 downto 0); -- memory address
				MEM_RD_DTA		: in  STD_LOGIC_VECTOR(31 downto 0); -- data core <- memory
				MEM_WR_DTA		: out STD_LOGIC_VECTOR(31 downto 0); -- data core -> memory
				MEM_MODE			: out STD_LOGIC; -- byte/word transfer quantity
				MEM_WE			: out STD_LOGIC; -- write enable
				MEM_RW			: out STD_LOGIC; -- read/write signal
				MEM_OPC			: out STD_LOGIC; -- opcode/data fetch
				MEM_LOCK			: out STD_LOGIC; -- locked access
				MEM_ABORT		: in  STD_LOGIC; -- memory abort request

-- ###############################################################################################
-- ##       Interrupt Interface                                                                 ##
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
	signal	MS_CTRL				: STD_LOGIC_VECTOR(31 downto 0);
	signal	BP_MS					: STD_LOGIC_VECTOR(31 downto 0);
	signal	OP_A_MS				: STD_LOGIC_VECTOR(31 downto 0);
	signal	OP_B_MS				: STD_LOGIC_VECTOR(31 downto 0);
	signal	MS_CARRY				: STD_LOGIC;
	signal	MS_OVFL				: STD_LOGIC;
	signal	MS_FW_PATH			: STD_LOGIC_VECTOR(40 downto 0);
	signal	WB_FW_PATH			: STD_LOGIC_VECTOR(40 downto 0);

	-- ###############################################################################################
	-- ##			GLOBAL SIGNALS FOR ALL STAGES                                                       ##
	-- ###############################################################################################

	signal	gCLK					: STD_LOGIC; -- global clock line
	signal	gRES					: STD_LOGIC; -- global reset line
	signal	INT_EXECUTE			: STD_LOGIC; -- execute interrupt
	signal	HALT_BUS				: STD_LOGIC_VECTOR(03 downto 0);
	signal	DATA_MREQ			: STD_LOGIC; -- manual memory request
	signal	INST_MREQ			: STD_LOGIC; -- automatic instruction memory request

	-- ###############################################################################################
	-- ##			SIGNALS FOR PIPELINE STAGE 1: OPERAND FETCH / INSTRUCITON DECODE                    ##
	-- ###############################################################################################

	signal	OF_CTRL				: STD_LOGIC_VECTOR(31 downto 0); -- OF stage control lines
	signal	OF_OP_A				: STD_LOGIC_VECTOR(31 downto 0); -- operant A
	signal	OF_OP_B				: STD_LOGIC_VECTOR(31 downto 0); -- operant B
	signal	OF_OP_C				: STD_LOGIC_VECTOR(31 downto 0); -- operant C
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
	signal	ALU_FW_PATH			: STD_LOGIC_VECTOR(41 downto 0); -- alu forwarding path
	
	signal	EX_BP_OUT			: STD_LOGIC_VECTOR(31 downto 0);
	signal	EX_ADR_OUT			: STD_LOGIC_VECTOR(31 downto 0);
	signal	EX_RES_OUT			: STD_LOGIC_VECTOR(31 downto 0);

	-- ###############################################################################################
	-- ##			SIGNALS FOR PIPELINE STAGE 3: MEMORY ACCESS                                         ##
	-- ###############################################################################################

	signal	MEM_CTRL				: STD_LOGIC_VECTOR(31 downto 0); -- MEM stage control lines
	signal	MEM_DATA				: STD_LOGIC_VECTOR(31 downto 0);
	signal	MEM_DTA_OUT       : STD_LOGIC_VECTOR(31 downto 0); -- mem_data and bp2 register
	signal	MEM_ADR_OUT			: STD_LOGIC_VECTOR(31 downto 0); -- mem_data address bypass
	signal	MEM_BP_OUT			: STD_LOGIC_VECTOR(31 downto 0); -- mem_data and bp2 register
	signal	MEM_FW_PATH			: STD_LOGIC_VECTOR(40 downto 0); -- memory forwarding path
	signal	SHIFT_VAL_BUFF		: STD_LOGIC_VECTOR(04 downto 0);
	signal	PC_1, PC_2, PC_3	: STD_LOGIC_VECTOR(31 downto 0); -- delayed/current program counter
	signal	INSTR_IN				: STD_LOGIC_VECTOR(31 downto 0); -- new instruction word
	
	-- ###############################################################################################
	-- ##			SIGNALS FOR PIPELINE STAGE 4: WRITE BACK                                            ##
	-- ###############################################################################################

	signal	WB_CTRL				: STD_LOGIC_VECTOR(31 downto 0); -- WB stage control lines
	signal	WB_DATA_LINE		: STD_LOGIC_VECTOR(31 downto 0); -- data write back line

begin
	-- #######################################################################################################
	-- ##			GLOBAL CONTROL FOR ALL STAGES                                                               ##
	-- #######################################################################################################

	-- Global CLOCK & RESET Network
	-- ------------------------------------------------------------------------------
	gCLK <= CLK and (not HALT);

	Reset_Synchronizer:
	RES_SYNC
	port map	(		CLK		=> gCLK,							-- global clock net
						RES_IN	=> RES,							-- external reset
						RES_OUT	=> gRES							-- global active high reset net
					);


	-- Instruction Decoder
	-- ------------------------------------------------------------------------------
	Instruction_Decoder:
	X1_OPCODE_DECODER
		port map	(
						OPCODE_DATA_IN  => OP_DATA,			-- current instruction word
						OPCODE_CTRL_IN  => OPC_A,				-- control feedback input
						OPCODE_CTRL_OUT => OPC_B				-- control lines output
					);


	-- Operation Flow Control System
	-- ------------------------------------------------------------------------------
	Operation_Flow_Control:
	FLOW_CTRL
		port map	(
						RES              => gRES,				-- global active high reset
						CLK              => gCLK,				-- global clock net
						INSTR_IN			  => INSTR_IN,			-- instruction input
						INST_MREQ_OUT    => INST_MREQ,		-- instr fetch memory request
						OPCODE_DATA_OUT  => OP_DATA,			-- instruction register output
						OPCODE_CTRL_IN	  => OPC_B,				-- control lines input
						OPCODE_CTRL_OUT  => OPC_A,				-- control feedback output
						PC_HALT_OUT		  => PC_HALT,			-- halt instruction fetch output
						SREG_IN          => CMSR,				-- current machine status register
						EXECUTE_INT_IN	  => INT_EXECUTE,		-- execute interupt request
						HOLD_BUS_IN      => HALT_BUS,			-- number of bubbles
						OP_ADR_OUT       => OP_ADR,			-- operand register addresses
						IMM_OUT          => IMMEDIATE,		-- immediate output
						SHIFT_M_OUT      => SHIFT_MOD,		-- shift mode output
						SHIFT_C_OUT      => SHIFT_VAL,		-- immediate shif value output
						OF_CTRL_OUT      => OF_CTRL,			-- stage control OF
						MS_CTRL_OUT      => MS_CTRL,			-- stage control MS
						EX1_CTRL_OUT     => EX1_CTRL,			-- stage control EX
						MEM_CTRL_OUT     => MEM_CTRL,			-- stage control MA
						WB_CTRL_OUT      => WB_CTRL			-- stage control WB
					);


	-- Machine Control System
	-- ------------------------------------------------------------------------------
	Machine_Control_System:
	MCR_SYS
		port map	(
						CLK				=> gCLK,					-- global clock net
						RES				=> gRES,					-- global active high reset
						CTRL				=> EX1_CTRL,			-- stage control
						HALT_IN			=> PC_HALT,				-- halt program counter
						INT_TKN_OUT		=> INT_EXECUTE,		-- execute interrupt output
						FLAG_IN			=> ALU_FLAGS,			-- alu flags input
						CMSR_OUT			=> CMSR,					-- current machine status register
						PC1_OUT			=> PC_1,					-- current program counter
						PC2_OUT			=> PC_2,					-- delayed progam counter
						PC3_OUT			=> PC_3,					-- x2 delayed program counter
						MCR_DATA_IN		=> MCR_DTA_WR,			-- mcr write data input
						MCR_DATA_OUT	=> MCR_DTA_RD,			-- mcr read data output
						EX_FIQ_IN		=> FIQ,					-- external fast interrupt request
						EX_IRQ_IN		=> IRQ,					-- external interrupt request
						EX_ABT_IN		=> MEM_ABORT			-- external memory abort request
					);


	-- External Interface
	-- ------------------------------------------------------------------------------
		DEBUG_FLAG  <= CMSR(31 downto 28);
		DEBUG_INSTR <= OP_DATA;
		PC_OUT      <= PC_1; -- current program counter output					
		MODE        <= CMSR(SREG_MODE_4 downto SREG_MODE_0); -- current processor mode
		MREQ        <= INST_MREQ or DATA_MREQ; -- memory request


	-- #######################################################################################################
	-- ##			PIPELINE STAGE 2: OPERAND FETCH & INSTRUCITON DECODE                                        ##
	-- #######################################################################################################

	-- Data Register File
	-- ------------------------------------------------------------------------------
	Register_File:
	REG_FILE
		port map	(
						CLK				=> gCLK,					-- global clock net
						RES				=> gRES,					-- global active high reset
						CTRL_IN			=> WB_CTRL,				-- stage control
						OP_ADR_IN		=> OP_ADR,				-- operand addresses
						MODE_IN			=> CMSR(SREG_MODE_4 downto SREG_MODE_0), -- current processor mode
						DEBUG_R0			=> DEBUG_REG(07 downto 00), -- debugging stuff
						DEBUG_R1			=> DEBUG_REG(15 downto 08), -- debugging stuff
						WB_DATA_IN		=> WB_DATA_LINE,		-- write back bus
						PC_IN				=> PC_2,					-- delayed program counter
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
						OP_A_IN			=> OF_OP_A,				-- register A input
						OP_B_IN			=> OF_OP_B,				-- register B input
						OP_C_IN			=> OF_OP_C,				-- register C input
						SHIFT_VAL_IN	=> SHIFT_VAL,			-- immediate shift value in
						PC2_IN			=> PC_2, 				-- delayed program counter
						PC3_IN			=> PC_3,					-- 2x delayed program counter
						IMM_IN			=> IMMEDIATE,			-- immediate value
						OP_A_OUT			=> OF_OP_A_OUT,		-- operand A data output
						OP_B_OUT			=> OF_OP_B_OUT,		-- operant B data output
						SHIFT_VAL_OUT	=> SHIFT_VAL_BUFF,	-- shift operand output
						BP1_OUT			=> OF_BP1_OUT,			-- bypass data output
						HOLD_BUS_OUT	=> HALT_BUS,			-- insert n bubbles
						MSU_FW_IN		=> MS_FW_PATH,			-- ms forwarding path
						ALU_FW_IN		=> ALU_FW_PATH,		-- alu forwarding path
						MEM_FW_IN		=> MEM_FW_PATH,		-- memory forwarding path
						WB_FW_IN			=> WB_FW_PATH			-- write back forwarding path
					);


	-- #######################################################################################################
	-- ##			PIPELINE STAGE 3: MULTIPLICATION & SHIFT                                                    ##
	-- #######################################################################################################

	-- Multiply/Shift Unit
	-- ------------------------------------------------------------------------------
	Multishifter:
	MS_UNIT
		port map	(
						CLK				=> gCLK,					-- global clock line
						RES				=> gRES,					-- global reset line
						CTRL				=> MS_CTRL,				-- stage control
						OP_A_IN			=> OF_OP_A_OUT,		-- operant a input
						OP_B_IN			=> OF_OP_B_OUT,		-- operant b input
						BP_IN				=> OF_BP1_OUT,			-- bypass input
						CARRY_IN			=> CMSR(SREG_C_FLAG),-- carry input
						SHIFT_V_IN		=> SHIFT_VAL_BUFF,	-- shift value in
						SHIFT_M_IN		=> SHIFT_MOD,			-- shift mode in
						OP_A_OUT			=> OP_A_MS,				-- operant a bypass output
						BP_OUT			=> BP_MS,				-- bypass output
						RESULT_OUT		=> OP_B_MS,				-- operation result
						CARRY_OUT		=> MS_CARRY,			-- operation carry signal
						OVFL_OUT			=> MS_OVFL,				-- operation overflow signal
						MSU_FW_OUT		=> MS_FW_PATH			-- forwarding path
					);


	-- #######################################################################################################
	-- ##			PIPELINE STAGE 4: ALU OPERATION & MCR ACCESS                                                ##
	-- #######################################################################################################

	-- Arithmetical/Logical Unit
	-- ------------------------------------------------------------------------------
	Operator:
	ALU
		port map	(
						CLK				=> gCLK,					-- global clock net
						RES				=> gRES,					-- global active high reset
						CTRL				=> EX1_CTRL,			-- stage control
						OP_A_IN			=> OP_A_MS,				-- operand A input
						OP_B_IN			=> OP_B_MS,				-- operant B input
						BP1_IN			=> BP_MS,				-- bypass data input
						BP1_OUT			=> EX_BP1_OUT,			-- bypass data output
						ADR_OUT			=> EX_ADR_OUT,			-- memory access address
						RESULT_OUT		=> EX_RES_OUT,			-- EX result data
						FLAG_IN			=> CMSR(31 downto 28), -- sreg alu flags input
						FLAG_OUT			=> ALU_FLAGS,			-- alu flags output
						PC_IN				=> PC_3,					-- pc for INT_LINK
						INT_CALL_IN		=> INT_EXECUTE,		-- this is an interrupt call	
						MS_CARRY_IN		=> MS_CARRY,			-- ms carry output
						MS_OVFL_IN		=> MS_OVFL,				-- ms overflow output
						MCR_DTA_OUT		=> MCR_DTA_WR,			-- mcr write data output
						MCR_DTA_IN		=> MCR_DTA_RD,			-- mcr read data input
						DATA_MREQ_OUT	=> DATA_MREQ,			-- memory access in next cycle
						ALU_FW_OUT		=> ALU_FW_PATH			-- alu forwarding path
					);


	-- #####################################################################################################
	-- ##			PIPELINE STAGE 5: DATA MEMORY ACCESS                                                      ##
	-- #####################################################################################################

	-- Memory Access System
	-- ------------------------------------------------------------------------------
	Memory_Access:
	LOAD_STORE_UNIT
		port map	(
						CLK				=> gCLK,				-- global clock net
						RES				=> gRES,				-- global reset net
						CTRL_IN			=> MEM_CTRL,		-- stage control
						MEM_DATA_IN		=> EX_RES_OUT,		-- EX data result
						MEM_ADR_IN		=> EX_ADR_OUT,		-- memory access address
						MEM_BP_IN		=> EX_BP1_OUT,		-- bp/write data input
						ADR_OUT			=> MEM_ADR_OUT,	-- address bypass output
						BP_OUT			=> MEM_BP_OUT,		-- bypass(data) output
						INSTR_ADR_IN	=> PC_1,				-- current program counter
						LDST_FW_OUT		=> MEM_FW_PATH,	-- memory forwarding path
						XMEM_ADR			=> MEM_ADR,			-- memory address output
						XMEM_WR_DTA		=> MEM_WR_DTA,		-- memory write data output
						XMEM_WE			=> MEM_WE,			-- memory write enable
						XMEM_RW			=> MEM_RW,			--	read/write
						XMEM_BW			=> MEM_MODE,		-- memory data quantity
						XMEM_OPC			=> MEM_OPC,			-- Opcode/data fetch
						XMEM_LOCK		=> MEM_LOCK			-- locked operation
					);


	-- #####################################################################################################
	-- ##			PIPELINE STAGE 6: DATA WRITE BACK                                                         ##
	-- #####################################################################################################

	-- Data Write Back System
	-- ------------------------------------------------------------------------------
	Data_Write_Back:
	WB_UNIT
		port map	(
						CLK				=> gCLK,				-- global clock net
						RES				=> gRES,				-- global reset net
						CTRL_IN			=> WB_CTRL,			-- stage control
						ALU_DATA_IN		=> MEM_BP_OUT,		-- alu data input
						ADR_BUFF_IN		=> MEM_ADR_OUT,	-- address bypass input 
						WB_DATA_OUT		=> WB_DATA_LINE,	-- data write back line
						XMEM_RD_DATA	=> MEM_RD_DTA,		-- memory read data
						INSTR_DAT_OUT	=> INSTR_IN,		-- instruction input
						WB_FW_OUT		=> WB_FW_PATH		-- forwarding path
					);
	
end CORE_STRUCTURE;