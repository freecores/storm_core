-- #######################################################
-- #             STORM core system package               #
-- #         Created by Stephan Nolting (4788)           #
-- # +-------------------------------------------------+ #
-- # Core Components Hierarchy:                          #
-- # - STORM_TOP.vhd                                     #
-- #   + STORM_CORE.vhd (this file)                      #
-- #   - SYSTEM_BRIDGE.vhd                               #
-- #   - MEMORY.vhd                                      #
-- #   - WISHBONE_IO.vhd                                 #
-- #   - CORE.vhd                                        #
-- #     - REG_FILE.vhd                                  #
-- #       - ADR_TRANSLATOR (same file)                  #
-- #     - OPERANT_UNIT.vhd                              #
-- #     - MS_UNIT.vhd                                   #
-- #       - MULTIPLICATION_UNIT.vhd                     #
-- #     -   BARREL_SHIFTER.vhd                          #
-- #     - ALU.vhd                                       #
-- #       - ARITHMETICAL_UNIT.vhd                       #
-- #       - LOGICAL_UNIT.vhd                            #
-- #     - FLOW_CTRL.vhd                                 #
-- #     - WB_UNIT.vhd                                   #
-- #     - MCR_SYS.vhd                                   #
-- #     - LOAD_STORE_UNIT.vhd                           #
-- #     - X1_OPCODE_DECODER.vhd                         #
-- # +-------------------------------------------------+ #
-- # Version 2.4.3, 19.07.2011                           #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package STORM_core_package is

  -- ARCHITECTURE CONSTANTS -----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
	constant STORM_MODE        : boolean := FALSE; -- use STORM extension architecture
	constant USE_BIG_ENDIAN    : boolean := TRUE; -- use big endian memory
	constant MEM_RB_SYNC_FF_EN : boolean := TRUE; -- memory readback sync (only for simulation?!)
	constant NOP_CMD           : STD_LOGIC_VECTOR(31 downto 00) := x"F0013007"; -- Dummy OPCODE

  -- DUMMY CYCLES FOR TEMPORAL PIPELINE CONFLICTS -------------------------------------------
  -- -------------------------------------------------------------------------------------------
 	constant DC_TAKEN_BRANCH	: natural := 2; -- empty cycles after taken branch
	constant OF_MS_REG_DD		: natural := 1; -- of-ms reg/reg conflict
	constant OF_WB_MEM_DD		: natural := 1; -- of-wb reg/mem conflict
	constant OF_EX_MEM_DD		: natural := 2; -- of-ex reg/mem conflict
	constant OF_MS_MEM_DD		: natural := 3; -- of-ms reg/mem conflict

  -- ADDRESS CONSTANTS ----------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
	constant C_SP_ADR		: STD_LOGIC_VECTOR(3 downto 0) := "1101"; -- Stack Pointer = R13
	constant C_LR_ADR		: STD_LOGIC_VECTOR(3 downto 0) := "1110"; -- Link Register = R14
	constant C_PC_ADR		: STD_LOGIC_VECTOR(3 downto 0) := "1111"; -- Prog. Counter = R15

  -- OPERAND ADR BUS LOCATIONS --------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
	constant OP_A_ADR_0			: natural :=  0; -- OP A ADR LSB
	constant OP_A_ADR_3			: natural :=  3; -- OP A ADR MSB
	constant OP_B_ADR_0			: natural :=  4; -- OP B ADR LSB
	constant OP_B_ADR_3			: natural :=  7; -- OP B ADR MSB
	constant OP_C_ADR_0			: natural :=  8; -- OP C ADR LSB
	constant OP_C_ADR_3			: natural := 11; -- OP C ADR MSB
	constant OP_A_IS_REG        : natural := 12; -- OP A is a reg adr
	constant OP_B_IS_REG        : natural := 13; -- OP B is a reg adr
	constant OP_C_IS_REG        : natural := 14; -- OP C is a reg adr

  -- OPERAND CONSTANTS ----------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
	constant RD               : STD_LOGIC := '0';
	constant WR               : STD_LOGIC := '1';
	constant DQ_WORD          : STD_LOGIC_VECTOR(1 downto 0) := "00";
	constant DQ_BYTE          : STD_LOGIC_VECTOR(1 downto 0) := "01";
	constant DQ_HALFWORD      : STD_LOGIC_VECTOR(1 downto 0) := "10"; -- "11"

  -- FORWARDING BUS LOCATIONS ---------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
	constant FWD_DATA_LSB     : natural :=  0; -- Forwardind Data Bit 0
	constant FWD_DATA_MSB     : natural := 31; -- Forwarding Data Bit 31
	constant FWD_RD_LSB       : natural := 32; -- Destination Adr Bit 0
	constant FWD_RD_MSB       : natural := 35; -- Destination Adr Bit 3
	constant FWD_WB           : natural := 36; -- Data in stage will be written back to reg
	constant FWD_CY_NEED      : natural := 37; -- Carry flag is needed
	constant FWD_MCR_R_ACC    : natural := 38; -- MCR Read Access
	constant FWD_MEM_R_ACC    : natural := 39; -- Memory Read Access

  -- CTRL BUS LOCATIONS ---------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
	constant CTRL_EN          : natural :=  0; -- stage enable
	constant CTRL_CONST       : natural :=  1; -- is immediate value
	constant CTRL_BRANCH      : natural :=  2; -- branch control
	constant CTRL_LINK        : natural :=  3; -- link
	constant CTRL_SHIFTR      : natural :=  4; -- use register shift offset
	constant CTRL_WB_EN	      : natural :=  5; -- write back enable

	constant CTRL_RD_0        : natural :=  6; -- destination register adr bit 0
	constant CTRL_RD_1        : natural :=  7; -- destination register adr bit 1
	constant CTRL_RD_2        : natural :=  8; -- destination register adr bit 2
	constant CTRL_RD_3        : natural :=  9; -- destination register adr bit 3

	constant CTRL_SWI         : natural := 10; -- software interrup
	constant CTRL_UND         : natural := 11; -- undefined instruction interrupt

	constant CTRL_COND_0      : natural := 12; -- condition code bit 0
	constant CTRL_COND_1      : natural := 13; -- condition code bit 1
	constant CTRL_COND_2      : natural := 14; -- condition code bit 2
	constant CTRL_COND_3      : natural := 15; -- condition code bit 3

	constant CTRL_MS          : natural := 16; -- '0' = shift, '1' = multiply
	constant CTRL_AF          : natural := 17; -- alter flags
	constant CTRL_ALU_FS_0    : natural := 18; -- alu function set bit 0
	constant CTRL_ALU_FS_1    : natural := 19; -- alu function set bit 1
	constant CTRL_ALU_FS_2    : natural := 20; -- alu function set bit 2
	constant CTRL_ALU_FS_3    : natural := 21; -- alu function set bit 3

	constant CTRL_MEM_ACC     : natural := 22; -- '1' = Access memory
	constant CTRL_MEM_DQ_0    : natural := 23; -- '0' = word, '1' = byte
	constant CTRL_MEM_DQ_1    : natural := 24; -- '0' = see above, '1' = halfword
	constant CTRL_MEM_SE      : natural := 25; -- '0' = no sign extension, '1' = sign extension
	constant CTRL_MEM_RW      : natural := 26; -- '0' = read, '1' = write
	constant CTRL_MEM_USER    : natural := 27; -- '1' = access memory with "user_mode" output

	constant CTRL_MREG_ACC    : natural := 28; -- '1' = Access machine register file
	constant CTRL_MREG_M      : natural := 29; -- '0' = CMSR, '1' = SMSR
	constant CTRL_MREG_RW     : natural := 30; -- '0' = read, '1' = write
	constant CTRL_MREG_FA     : natural := 31; -- '0' = whole access, '1' = flag access

	-- Progress Redefinitions --
	constant CTRL_MODE_0      : natural := CTRL_AF;       -- mode bit 0
	constant CTRL_MODE_1      : natural := CTRL_ALU_FS_0; -- mode bit 1
	constant CTRL_MODE_2      : natural := CTRL_ALU_FS_1; -- mode bit 2
	constant CTRL_MODE_3      : natural := CTRL_ALU_FS_2; -- mode bit 3
	constant CTRL_MODE_4      : natural := CTRL_ALU_FS_3; -- mode bit 4

  -- SREG BIT LOCATIONS ---------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
	constant SREG_MODE_0      : natural :=  0; -- mode bit 0
	constant SREG_MODE_1      : natural :=  1; -- mode bit 1
	constant SREG_MODE_2      : natural :=  2; -- mode bit 2
	constant SREG_MODE_3      : natural :=  3; -- mode bit 3
	constant SREG_MODE_4      : natural :=  4; -- mode bit 4
	constant SREG_THUMB       : natural :=  5; -- execute thumb instructions
	constant SREG_FIQ_DIS     : natural :=  6; -- disable FIQ
	constant SREG_IRQ_DIS     : natural :=  7; -- disable IRQ

	constant SREG_O_FLAG      : natural := 28; -- overflow flag
	constant SREG_C_FLAG      : natural := 29; -- carry flag
	constant SREG_Z_FLAG      : natural := 30; -- zero flag
	constant SREG_N_FLAG      : natural := 31; -- negative flag

  -- INTERRUPT VECTORS ----------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
	constant RES_INT_VEC : STD_LOGIC_VECTOR(4 downto 0) := "00000"; -- hardware reset
	constant UND_INT_VEC : STD_LOGIC_VECTOR(4 downto 0) := "00100"; -- going to Undefined32_MODE
	constant SWI_INT_VEC : STD_LOGIC_VECTOR(4 downto 0) := "01000"; -- going to Supervisor32_MODE
	constant PRF_INT_VEC : STD_LOGIC_VECTOR(4 downto 0) := "01100"; -- going to Abort32_MODE
	constant DAT_INT_VEC : STD_LOGIC_VECTOR(4 downto 0) := "10000"; -- going to Abort32_MODE
	constant IRQ_INT_VEC : STD_LOGIC_VECTOR(4 downto 0) := "11000"; -- going to IRQ32_MODE
	constant FIQ_INT_VEC : STD_LOGIC_VECTOR(4 downto 0) := "11100"; -- going to FIQ32_MODE

  -- PROCESSOR MODE CONSTANTS ---------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
	constant User32_MODE        : STD_LOGIC_VECTOR(4 downto 0) := "10000";
	constant FIQ32_MODE         : STD_LOGIC_VECTOR(4 downto 0) := "10001";
	constant IRQ32_MODE         : STD_LOGIC_VECTOR(4 downto 0) := "10010";
	constant Supervisor32_MODE  : STD_LOGIC_VECTOR(4 downto 0) := "10011";
	constant Abort32_MODE       : STD_LOGIC_VECTOR(4 downto 0) := "10111";
	constant Undefined32_MODE   : STD_LOGIC_VECTOR(4 downto 0) := "11011";

  -- CONDITION OPCODES ----------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
	constant COND_EQ		: STD_LOGIC_VECTOR(3 downto 0) := "0000";
	constant COND_NE		: STD_LOGIC_VECTOR(3 downto 0) := "0001";
	constant COND_CS		: STD_LOGIC_VECTOR(3 downto 0) := "0010";
	constant COND_CC		: STD_LOGIC_VECTOR(3 downto 0) := "0011";
	constant COND_MI		: STD_LOGIC_VECTOR(3 downto 0) := "0100";
	constant COND_PL		: STD_LOGIC_VECTOR(3 downto 0) := "0101";
	constant COND_VS		: STD_LOGIC_VECTOR(3 downto 0) := "0110";
	constant COND_VC		: STD_LOGIC_VECTOR(3 downto 0) := "0111";
	constant COND_HI		: STD_LOGIC_VECTOR(3 downto 0) := "1000";
	constant COND_LS		: STD_LOGIC_VECTOR(3 downto 0) := "1001";
	constant COND_GE		: STD_LOGIC_VECTOR(3 downto 0) := "1010";
	constant COND_LT		: STD_LOGIC_VECTOR(3 downto 0) := "1011";
	constant COND_GT		: STD_LOGIC_VECTOR(3 downto 0) := "1100";
	constant COND_LE		: STD_LOGIC_VECTOR(3 downto 0) := "1101";
	constant COND_AL		: STD_LOGIC_VECTOR(3 downto 0) := "1110";
	constant COND_NV		: STD_LOGIC_VECTOR(3 downto 0) := "1111";

  -- COOL WORKING MUSIC ---------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
	-- Carrie Underwood - Last Name
	-- Sugarland - Something More
	-- Taylor Swift - Today Was A Fairy Tale
	-- Montgomery Gentry - One In Every Crowd
	-- Tim McGraw - Something Like That
	-- Rascal Flatts - These Days
	-- Coldwater Jane - Bring On The Love
	-- Reba McEntire - The Night The Lights Went Out In Georgia
	-- Laura Bell Bundy - Giddy Up On
	-- Jerrod Niemann - Lover, Lover
	-- Craig Morgan - Redneck Yacht Club
	-- Travis Tritt - I'm Gonna Be Somebody
	-- Crystal Shawanda - You Can Let Go
	-- Dixie Chicks - Wide Open Spaces
	-- Collin Raye - I Can Still Feel You
	-- Jason Aldean - She's Country
	-- Tracy Lawrence - For the Love

  -- INTERNAL MNEMONICS ---------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
	constant LOGICAL_OP			: STD_LOGIC	:= '0';	
	constant ARITHMETICAL_OP	: STD_LOGIC := '1';	

	constant L_AND		: STD_LOGIC_VECTOR(3 downto 0) := "0000"; -- logical and
	constant L_OR		: STD_LOGIC_VECTOR(3 downto 0) := "0001"; -- logical or
	constant L_XOR		: STD_LOGIC_VECTOR(3 downto 0) := "0010"; -- logical exclusive or
	constant L_NOT		: STD_LOGIC_VECTOR(3 downto 0) := "0011"; -- logical not (-and)
	constant L_BIC		: STD_LOGIC_VECTOR(3 downto 0) := "0100"; -- bit clear
	constant L_MOV		: STD_LOGIC_VECTOR(3 downto 0) := "0101"; -- pass operant B
	constant L_TST		: STD_LOGIC_VECTOR(3 downto 0) := "0110"; -- compare by logical and
	constant L_TEQ		: STD_LOGIC_VECTOR(3 downto 0) := "0111"; -- compare by logical xor

	constant A_ADD		: STD_LOGIC_VECTOR(3 downto 0) := "1000"; -- add
	constant A_ADC		: STD_LOGIC_VECTOR(3 downto 0) := "1001"; -- add with carry
	constant A_SUB		: STD_LOGIC_VECTOR(3 downto 0) := "1010"; -- sub
	constant A_SBC		: STD_LOGIC_VECTOR(3 downto 0) := "1011"; -- sub with carry
	constant A_RSB		: STD_LOGIC_VECTOR(3 downto 0) := "1100"; -- reverse sub
	constant A_RSC		: STD_LOGIC_VECTOR(3 downto 0) := "1101"; -- reverse sub with carry
	constant A_CMP		: STD_LOGIC_VECTOR(3 downto 0) := "1110"; -- compare by subtraction
	constant A_CMN		: STD_LOGIC_VECTOR(3 downto 0) := "1111"; -- compare by addition

	constant PassA		: STD_LOGIC_VECTOR(3 downto 0) := L_TEQ;  -- pass operant A
	constant PassB		: STD_LOGIC_VECTOR(3 downto 0) := L_MOV;  -- pass operant B

	constant S_LSL		: STD_LOGIC_VECTOR(1 downto 0) := "00";	-- logical shift left
	constant S_LSR		: STD_LOGIC_VECTOR(1 downto 0) := "01";	-- logical shift right
	constant S_ASR		: STD_LOGIC_VECTOR(1 downto 0) := "10";	-- arithmetical shift right
	constant S_ROR		: STD_LOGIC_VECTOR(1 downto 0) := "11";	-- rotate right
	constant S_RRX		: STD_LOGIC_VECTOR(1 downto 0) := "11";	-- rotate right extended

  -- COMPONENT Machine Control System -------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component MCR_SYS
	 port	(
				CLK				: in  STD_LOGIC;
				G_HALT          : in  STD_LOGIC;
				RES				: in  STD_LOGIC;
				CTRL			: in  STD_LOGIC_VECTOR(31 downto 0);
				HALT_IN			: in  STD_LOGIC;
				INT_TKN_OUT		: out STD_LOGIC;
				FLAG_IN			: in  STD_LOGIC_VECTOR(03 downto 0);
				CMSR_OUT		: out STD_LOGIC_VECTOR(31 downto 0);
				REG_PC_OUT		: out STD_LOGIC_VECTOR(31 downto 0);
				JMP_PC_OUT		: out STD_LOGIC_VECTOR(31 downto 0);
				LNK_PC_OUT		: out STD_LOGIC_VECTOR(31 downto 0);
				INF_PC_OUT		: out STD_LOGIC_VECTOR(31 downto 0);
				EXC_PC_OUT		: out STD_LOGIC_VECTOR(31 downto 0);
				MCR_DATA_IN		: in  STD_LOGIC_VECTOR(31 downto 0);
				MCR_DATA_OUT	: out STD_LOGIC_VECTOR(31 downto 0);
				EX_FIQ_IN		: in  STD_LOGIC;
				EX_IRQ_IN		: in  STD_LOGIC;
				EX_ABT_IN		: in  STD_LOGIC;
				EX_PRF_IN       : in  STD_LOGIC
			);
  end component;

  -- COMPONENT Operant Unit -----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component OPERAND_UNIT
	 port	(
				CTRL_IN         : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_ADR_IN       : in  STD_LOGIC_VECTOR(14 downto 0);
				OP_A_IN         : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_B_IN         : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_C_IN         : in  STD_LOGIC_VECTOR(31 downto 0);
				SHIFT_VAL_IN    : in  STD_LOGIC_VECTOR(04 downto 0);
				REG_PC_IN       : in  STD_LOGIC_VECTOR(31 downto 0);
				JMP_PC_IN       : in  STD_LOGIC_VECTOR(31 downto 0);
				LNK_PC_IN       : in  STD_LOGIC_VECTOR(31 downto 0);
				IMM_IN          : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_A_OUT        : out STD_LOGIC_VECTOR(31 downto 0);
				OP_B_OUT        : out STD_LOGIC_VECTOR(31 downto 0);
				SHIFT_VAL_OUT   : out STD_LOGIC_VECTOR(04 downto 0);
				BP1_OUT         : out STD_LOGIC_VECTOR(31 downto 0);
				HOLD_BUS_OUT    : out STD_LOGIC_VECTOR(02 downto 0);
				MSU_FW_IN       : in  STD_LOGIC_VECTOR(39 downto 0);
				ALU_FW_IN       : in  STD_LOGIC_VECTOR(39 downto 0);
				MEM_FW_IN       : in  STD_LOGIC_VECTOR(39 downto 0);
				WB_FW_IN        : in  STD_LOGIC_VECTOR(39 downto 0)
			);
  end component;
  
  -- COMPONENT Register File ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component REG_FILE
	 port	(
				CLK             : in  STD_LOGIC;
				G_HALT          : in  STD_LOGIC;
				RES             : in  STD_LOGIC;
				CTRL_IN         : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_ADR_IN       : in  STD_LOGIC_VECTOR(14 downto 0);
				MODE_IN         : in  STD_LOGIC_VECTOR(04 downto 0);
				WB_DATA_IN      : in  STD_LOGIC_VECTOR(31 downto 0);
				REG_PC_IN       : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_A_OUT        : out STD_LOGIC_VECTOR(31 downto 0);
				OP_B_OUT        : out STD_LOGIC_VECTOR(31 downto 0);
				OP_C_OUT        : out STD_LOGIC_VECTOR(31 downto 0)
			);
  end component;

  -- COMPONENT Memory Interface -------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component LOAD_STORE_UNIT
    port (
				CLK				: in  STD_LOGIC;
				G_HALT          : in  STD_LOGIC;
				RES				: in  STD_LOGIC;
				CTRL_IN			: in  STD_LOGIC_VECTOR(31 downto 0);
				MEM_DATA_IN		: in  STD_LOGIC_VECTOR(31 downto 0);
				MEM_ADR_IN		: in  STD_LOGIC_VECTOR(31 downto 0);
				MEM_BP_IN		: in  STD_LOGIC_VECTOR(31 downto 0);
				MODE_IN         : in  STD_LOGIC_VECTOR(04 downto 0);
				ADR_OUT			: out STD_LOGIC_VECTOR(31 downto 0);
				BP_OUT			: out STD_LOGIC_VECTOR(31 downto 0);
				LDST_FW_OUT		: out STD_LOGIC_VECTOR(39 downto 0);
				XMEM_MODE       : out STD_LOGIC_VECTOR(04 downto 0);
				XMEM_ADR		: out STD_LOGIC_VECTOR(31 downto 0);
				XMEM_WR_DTA		: out STD_LOGIC_VECTOR(31 downto 0);
				XMEM_ACC_REQ    : out STD_LOGIC;
				XMEM_RW			: out STD_LOGIC;
				XMEM_DQ			: out STD_LOGIC_VECTOR(01 downto 0)
			);
  end component;

  -- COMPONENT Opcode Decoder ---------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component X1_OPCODE_DECODER
	port	(
				OPCODE_DATA_IN  : in  STD_LOGIC_VECTOR(31 downto 0);
				OPCODE_CTRL_IN  : in  STD_LOGIC_VECTOR(15 downto 0);
				OPCODE_CTRL_OUT : out STD_LOGIC_VECTOR(99 downto 0)
			);
  end component;

  -- COMPONENT Operation Control System -----------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component FLOW_CTRL
	 port	(
				RES             : in  STD_LOGIC;
				CLK             : in  STD_LOGIC;
				G_HALT          : in  STD_LOGIC;
				INSTR_IN        : in  STD_LOGIC_VECTOR(31 downto 0);
				INST_MREQ_OUT   : out STD_LOGIC;
				OPCODE_DATA_OUT : out STD_LOGIC_VECTOR(31 downto 0);
				OPCODE_CTRL_IN  : in  STD_LOGIC_VECTOR(99 downto 0);
				OPCODE_CTRL_OUT : out STD_LOGIC_VECTOR(15 downto 0);
				PC_HALT_OUT     : out STD_LOGIC;
				SREG_IN         : in  STD_LOGIC_VECTOR(31 downto 0);
				EXECUTE_INT_IN  : in  STD_LOGIC;
				HOLD_BUS_IN     : in  STD_LOGIC_VECTOR(02 downto 0);
				OP_ADR_OUT      : out STD_LOGIC_VECTOR(14 downto 0);
				IMM_OUT         : out STD_LOGIC_VECTOR(31 downto 0);
				SHIFT_M_OUT     : out STD_LOGIC_VECTOR(01 downto 0);
				SHIFT_C_OUT     : out STD_LOGIC_VECTOR(04 downto 0);
				OF_CTRL_OUT     : out STD_LOGIC_VECTOR(31 downto 0);
				MS_CTRL_OUT     : out STD_LOGIC_VECTOR(31 downto 0);
				EX1_CTRL_OUT    : out STD_LOGIC_VECTOR(31 downto 0);
				MEM_CTRL_OUT    : out STD_LOGIC_VECTOR(31 downto 0);
				WB_CTRL_OUT     : out STD_LOGIC_VECTOR(31 downto 0)
			);
  end component;
  
  -- COMPONENT Multiplication/Shift Unit ----------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component MS_UNIT
    port	(
				CLK             : in  STD_LOGIC;
				G_HALT          : in  STD_LOGIC;
				RES             : in  STD_LOGIC;
				CTRL            : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_A_IN         : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_B_IN         : in  STD_LOGIC_VECTOR(31 downto 0);
				BP_IN           : in  STD_LOGIC_VECTOR(31 downto 0);
				CARRY_IN        : in  STD_LOGIC;
				SHIFT_V_IN      : in  STD_LOGIC_VECTOR(04 downto 0);
				SHIFT_M_IN      : in  STD_LOGIC_VECTOR(01 downto 0);
				OP_A_OUT        : out STD_LOGIC_VECTOR(31 downto 0);
				BP_OUT          : out STD_LOGIC_VECTOR(31 downto 0);
				RESULT_OUT      : out STD_LOGIC_VECTOR(31 downto 0);
				CARRY_OUT       : out STD_LOGIC;
				OVFL_OUT        : out STD_LOGIC;
				MSU_FW_OUT      : out STD_LOGIC_VECTOR(39 downto 0)
			);
  end component;


  -- COMPONENT MS_UNIT/Multiplication Unit --------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component MULTIPLY_UNIT
    port	(
				OP_B            : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_C            : in  STD_LOGIC_VECTOR(31 downto 0);
				RESULT          : out STD_LOGIC_VECTOR(31 downto 0);
				CARRY_OUT       : out STD_LOGIC;
				OVFL_OUT        : out STD_LOGIC
			);
  end component;
  
  -- COMPONENT MS_UNIT/Barrel Shifter Unit --------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component BARREL_SHIFTER
    port (
				SHIFT_DATA_IN   : in  STD_LOGIC_VECTOR(31 downto 0);
				SHIFT_DATA_OUT  : out STD_LOGIC_VECTOR(31 downto 0);
				CARRY_IN        : in  STD_LOGIC;
				CARRY_OUT       : out STD_LOGIC;
				OVERFLOW_OUT    : out STD_LOGIC;
				SHIFT_MODE      : in  STD_LOGIC_VECTOR(01 downto 0);
				SHIFT_POS       : in  STD_LOGIC_VECTOR(04 downto 0)
			);
  end component;
  
  -- COMPONENT Data Operation Unit ----------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component ALU
	 port	(
				CLK             : in  STD_LOGIC;
				G_HALT          : in  STD_LOGIC;
				RES             : in  STD_LOGIC;
				CTRL            : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_A_IN         : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_B_IN         : in  STD_LOGIC_VECTOR(31 downto 0);
				BP1_IN          : in  STD_LOGIC_VECTOR(31 downto 0);
				BP1_OUT         : out STD_LOGIC_VECTOR(31 downto 0);
				ADR_OUT         : out STD_LOGIC_VECTOR(31 downto 0);
				RESULT_OUT      : out STD_LOGIC_VECTOR(31 downto 0);
				FLAG_IN         : in  STD_LOGIC_VECTOR(03 downto 0);
				FLAG_OUT        : out STD_LOGIC_VECTOR(03 downto 0);
				EXC_PC_IN       : in  STD_LOGIC_VECTOR(31 downto 0);
				INT_CALL_IN     : in  STD_LOGIC;
				MS_CARRY_IN     : in  STD_LOGIC;
				MS_OVFL_IN      : in  STD_LOGIC;
				MCR_DTA_OUT     : out STD_LOGIC_VECTOR(31 downto 0);
				MCR_DTA_IN      : in  STD_LOGIC_VECTOR(31 downto 0);
				ALU_FW_OUT      : out STD_LOGIC_VECTOR(39 downto 0)
			);
  end component;

  -- COMPONENT ALU/Arithmetical Unit --------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component ARITHMETICAL_UNIT
    port	(
				OP_A            : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_B            : in  STD_LOGIC_VECTOR(31 downto 0);
				RESULT          : out STD_LOGIC_VECTOR(31 downto 0);
				BS_OVF_IN       : in  STD_LOGIC;
				A_CARRY_IN      : in  STD_LOGIC;
				FLAG_OUT        : out STD_LOGIC_VECTOR(03 downto 0);
				CTRL            : in  STD_LOGIC_VECTOR(02 downto 0)
			);
  end component;

  -- COMPONENT ALU/Logical Unit -------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component LOGICAL_UNIT
    port	(
				OP_A            : in  STD_LOGIC_VECTOR(31 downto 0);
				OP_B            : in  STD_LOGIC_VECTOR(31 downto 0);
				RESULT          : out STD_LOGIC_VECTOR(31 downto 0);
				BS_CRY_IN       : in  STD_LOGIC;
				BS_OVF_IN       : in  STD_LOGIC;
				L_CARRY_IN      : in  STD_LOGIC;
				FLAG_OUT        : out STD_LOGIC_VECTOR(03 downto 0);
				CTRL            : in  STD_LOGIC_VECTOR(02 downto 0)
			);
  end component;

  -- Write Back Unit ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  component WB_UNIT
    port	(
				CLK             : in  STD_LOGIC;
				G_HALT          : in  STD_LOGIC;
				RES             : in  STD_LOGIC;
				CTRL_IN         : in  STD_LOGIC_VECTOR(31 downto 0);
				ALU_DATA_IN     : in  STD_LOGIC_VECTOR(31 downto 0);
				ADR_BUFF_IN     : in  STD_LOGIC_VECTOR(31 downto 0);
				WB_DATA_OUT     : out STD_LOGIC_VECTOR(31 downto 0);
				XMEM_RD_DATA    : in  STD_LOGIC_VECTOR(31 downto 0);
				WB_FW_OUT       : out STD_LOGIC_VECTOR(39 downto 0)
			);
  end component;

end STORM_core_package;