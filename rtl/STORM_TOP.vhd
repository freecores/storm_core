-- #########################################################################################################
-- #                        <<< STORM CORE PROCESSOR SYSTEM by Stephan Nolting >>>                         #
-- # ***************************************************************************************************** #
-- #       ~ STORM System Top Entity ~      |                                                              #
-- #             File Hierarchy             | Make sure, that all files listed on the left are added to    #
-- # ---------------------------------------+ the project library, of which this file is the top entity.   #
-- # System File Hierarchy:                 |                                                              #
-- # - STORM_TOP.vhd (this file)            | This files instatiates the CORE itself, an internal working  #
-- #   + STORM_CORE.vhd (package file)      | memory, the Wishbone interface as well as an access arbiter. #
-- #   - SYSTEM_BRIDGE.vhd                  | The constant IO_BORDER gives the size of the internal memory #
-- #   - MEMORY.vhd                         | and the constant LOG2_IO_BORDER is the dual logarithm of     #
-- #   - WISHBONE_IO.vhd                    | this border address (see beneath).                           #
-- #   - CORE.vhd                           |                                                              #
-- #     - REG_FILE.vhd                     | CORE_ADR_OUT <  IO_BORDER : Access to internal memory        #
-- #     - OPERANT_UNIT.vhd                 | CORE_ADR_OUT >= IO_BORDER : Access to IO via Wishbone        #
-- #     - MS_UNIT.vhd                      |                                                              #
-- #       - MULTIPLICATION_UNIT.vhd        |  =/\= "To boldly go, where no core has gone before..." =/\=  #
-- #     -   BARREL_SHIFTER.vhd             |                                                              #
-- #     - ALU.vhd                          +------------------------------------------------------------- #
-- #       - ARITHMETICAL_UNIT.vhd          |                                                              #
-- #       - LOGICAL_UNIT.vhd               | The STORM Core System was created by Stephan Nolting         #
-- #     - FLOW_CTRL.vhd                    | Published at whttp://opencores.org/project,storm_core        #
-- #     - WB_UNIT.vhd                      | Contact me:                                                  #
-- #     - MCR_SYS.vhd                      | -> stnolting@googlemail.com                                  #
-- #     - LOAD_STORE_UNIT.vhd              | -> stnolting@web.de                                          #
-- #     - X1_OPCODE_DECODER.vhd            |                                                              #
-- # ***************************************************************************************************** #
-- # Version 1.1, 01.09.2011                                                                               #
-- #########################################################################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity STORM_TOP is
	port	(
-- ###############################################################################################
-- ##       Wishbone Interface                                                                  ##
-- ###############################################################################################

				CLK_I       : in  STD_LOGIC;
				RST_I       : in  STD_LOGIC;

				WB_DATA_I   : in  STD_LOGIC_VECTOR(31 downto 0);
				WB_DATA_O   : out STD_LOGIC_VECTOR(31 downto 0);
				WB_ADR_O    : out STD_LOGIC_VECTOR(31 downto 0);

				WB_ACK_I    : in  STD_LOGIC;
				WB_SEL_O    : out STD_LOGIC_VECTOR(03 downto 0);
				WB_WE_O     : out STD_LOGIC;
				WB_STB_O    : out STD_LOGIC;
				WB_CYC_O    : out STD_LOGIC;

-- ###############################################################################################
-- ##       Direct STORM Core Interface                                                         ##
-- ###############################################################################################

				MODE_O      : out STD_LOGIC_VECTOR(04 downto 0);
				D_ABT_I     : in  STD_LOGIC;
				I_ABT_I     : in  STD_LOGIC;
				IRQ_I       : in  STD_LOGIC;
				FIQ_I       : in  STD_LOGIC

			);
end STORM_TOP;

architecture Structure of STORM_TOP is

	-- Address border between internal memory and external IO
	-- IO_BORDER = Absolute size of internal memory (in IO_BORDER * 32 byte)
	-- **************************************************************************
	-- **************************************************************************
			constant IO_BORDER      : natural := 512;
			constant LOG2_IO_BORDER : natural := 9; -- log2(INT_MEM_END)
	-- **************************************************************************
	-- **************************************************************************

	-- reset sync --
	signal SYNC_RES : STD_LOGIC_VECTOR(1 downto 0) := "11";
	signal RST_INT  : STD_LOGIC;

	-- special processor lines --
	signal ST_HALT : STD_LOGIC;
	signal ST_MODE : STD_LOGIC_VECTOR(04 downto 00);

	-- D-MEM interface --
	signal ST_D_MEM_REQ    : STD_LOGIC;
	signal ST_D_MEM_ADR    : STD_LOGIC_VECTOR(31 downto 0);
	signal ST_D_MEM_RD_DTA : STD_LOGIC_VECTOR(31 downto 0);
	signal ST_D_MEM_WR_DTA : STD_LOGIC_VECTOR(31 downto 0);
	signal ST_D_MEM_DQ     : STD_LOGIC_VECTOR(01 downto 0);
	signal ST_D_MEM_RW     : STD_LOGIC;
	signal ST_D_MEM_ABORT  : STD_LOGIC;
	
	-- I-MEM interface --
	signal ST_I_MEM_REQ    : STD_LOGIC;
	signal ST_I_MEM_ADR    : STD_LOGIC_VECTOR(31 downto 0);
	signal ST_I_MEM_RD_DTA : STD_LOGIC_VECTOR(31 downto 0);
	signal ST_I_MEM_DQ     : STD_LOGIC_VECTOR(01 downto 0);
	signal ST_I_MEM_ABORT  : STD_LOGIC;

	-- Memory interface --
	signal MEM_RD_DATA     : STD_LOGIC_VECTOR(31 downto 0);
	signal MEM_WR_DATA     : STD_LOGIC_VECTOR(31 downto 0);
	signal MEM_ADR         : STD_LOGIC_VECTOR(31 downto 0);
	signal MEM_SEL         : STD_LOGIC_VECTOR(03 downto 0);
	signal MEM_CS          : STD_LOGIC;
	signal MEM_RW          : STD_LOGIC;

	-- Abort Signals --
	signal D_ABORT         : STD_LOGIC;
	signal I_ABORT         : STD_LOGIC;

	-- Wishbone interface --
	signal WI_RD_DATA      : STD_LOGIC_VECTOR(31 downto 0);
	signal WI_WR_DATA      : STD_LOGIC_VECTOR(31 downto 0);
	signal WI_ADR          : STD_LOGIC_VECTOR(31 downto 0);
	signal WI_SEL          : STD_LOGIC_VECTOR(03 downto 0);
	signal WI_CS           : STD_LOGIC;
	signal WI_RW           : STD_LOGIC;
	signal WI_DONE         : STD_LOGIC;

  -- storm component --
  -- =============== --
  component CORE
    Port (
				RES             : in  STD_LOGIC; -- global reset input (high active)
				CLK             : in  STD_LOGIC; -- global clock input

				HALT            : in  STD_LOGIC; -- halt processor
				MODE            : out STD_LOGIC_VECTOR(04 downto 0); -- current processor mode

				D_MEM_REQ       : out STD_LOGIC; -- memory access in next cycle
				D_MEM_ADR       : out STD_LOGIC_VECTOR(31 downto 0); -- data address
				D_MEM_RD_DTA    : in  STD_LOGIC_VECTOR(31 downto 0); -- read data
				D_MEM_WR_DTA    : out STD_LOGIC_VECTOR(31 downto 0); -- write data
				D_MEM_DQ        : out STD_LOGIC_VECTOR(01 downto 0); -- data transfer quantity
				D_MEM_RW        : out STD_LOGIC; -- read/write signal
				D_MEM_ABORT     : in  STD_LOGIC; -- memory abort request

				I_MEM_REQ       : out STD_LOGIC; -- memory access in next cycle
				I_MEM_ADR       : out STD_LOGIC_VECTOR(31 downto 0); -- instruction address
				I_MEM_RD_DTA    : in  STD_LOGIC_VECTOR(31 downto 0); -- read data
				I_MEM_DQ        : out STD_LOGIC_VECTOR(01 downto 0); -- data transfer quantity
				I_MEM_ABORT     : in  STD_LOGIC; -- memory abort request

				IRQ             : in  STD_LOGIC; -- interrupt request
				FIQ             : in  STD_LOGIC  -- fast interrupt request
			);
  end component;

  -- access arbiter component --
  -- ======================== --
  component ACCESS_ARBITER
	generic (
					SWITCH_ADR       : natural; -- address border resource1/resource2
					RE1_TO_CNT       : natural; -- resource 1 time out value
					RE2_TO_CNT       : natural; -- resource 2 time out value
					CL1_INT_EN       : boolean; -- allow interrupts for client 1
					CL2_INT_EN       : boolean  -- allow interrupts for client 2
            );
	port    (
				CLK_I              : in  STD_LOGIC; -- clock signal, rising edge
				RST_I              : in  STD_LOGIC; -- reset signal, sync, active high
				HALT_CLIENTS_O     : out STD_LOGIC; -- halt both clients

				CL1_ACC_REQ_I      : in  STD_LOGIC; -- access request
				CL1_ADR_I          : in  STD_LOGIC_VECTOR(31 downto 00); -- address input
				CL1_WR_DATA_I      : in  STD_LOGIC_VECTOR(31 downto 00); -- write data
				CL1_RD_DATA_O      : out STD_LOGIC_VECTOR(31 downto 00); -- read data
				CL1_DQ_I           : in  STD_LOGIC_VECTOR(01 downto 00); -- data quantity
				CL1_RW_I           : in  STD_LOGIC; -- read/write select
				CL1_TAG_I          : in  STD_LOGIC_VECTOR(04 downto 00); -- tag input, here: mode
				CL1_ABORT_O        : out STD_LOGIC; -- access abort error

				CL2_ACC_REQ_I      : in  STD_LOGIC; -- access request
				CL2_ADR_I          : in  STD_LOGIC_VECTOR(31 downto 00); -- address input
				CL2_WR_DATA_I      : in  STD_LOGIC_VECTOR(31 downto 00); -- write data
				CL2_RD_DATA_O      : out STD_LOGIC_VECTOR(31 downto 00); -- read data
				CL2_DQ_I           : in  STD_LOGIC_VECTOR(01 downto 00); -- data quantity
				CL2_RW_I           : in  STD_LOGIC; -- read/write select
				CL2_TAG_I          : in  STD_LOGIC_VECTOR(04 downto 00); -- tag input, here: mode
				CL2_ABORT_O        : out STD_LOGIC; -- access abort error

				RE1_ADR_O          : out STD_LOGIC_VECTOR(31 downto 00); -- address
				RE1_WR_DATA_O      : out STD_LOGIC_VECTOR(31 downto 00); -- write data
				RE1_RD_DATA_I      : in  STD_LOGIC_VECTOR(31 downto 00); -- read data
				RE1_BYTE_SEL_O     : out STD_LOGIC_VECTOR(03 downto 00); -- byte select
				RE1_RW_O           : out STD_LOGIC; -- read/write
				RE1_CS_O           : out STD_LOGIC; -- chip select
				RE1_DONE_I         : in  STD_LOGIC; -- transfer done

				RE2_ADR_O          : out STD_LOGIC_VECTOR(31 downto 00); -- address
				RE2_WR_DATA_O      : out STD_LOGIC_VECTOR(31 downto 00); -- write data
				RE2_RD_DATA_I      : in  STD_LOGIC_VECTOR(31 downto 00); -- read data
				RE2_BYTE_SEL_O     : out STD_LOGIC_VECTOR(03 downto 00); -- byte select
				RE2_RW_O           : out STD_LOGIC; -- read/write
				RE2_CS_O           : out STD_LOGIC; -- chip select
				RE2_DONE_I         : in  STD_LOGIC  -- transfer done
            );
  end component;

  -- internal memory component --
  -- ========================= --
  component MEMORY
    generic	(
					MEM_SIZE      : natural;
					LOG2_MEM_SIZE : natural
			);
    port	(
				CLK           : in  STD_LOGIC;
				RES           : in  STD_LOGIC;
				DATA_IN       : in  STD_LOGIC_VECTOR(31 downto 0);
				DATA_OUT      : out STD_LOGIC_VECTOR(31 downto 0);
				ADR_IN        : in  STD_LOGIC_VECTOR(31 downto 0);
				SEL_IN        : in  STD_LOGIC_VECTOR(03 downto 0);
				CS            : in  STD_LOGIC;
				RW            : in  STD_LOGIC
			);
  end component;

  -- wishbone interface component --
  -- ============================ --
  component WISHBONE_IO
    port	(
				CLK_I              : in  STD_LOGIC;
				RST_I              : in  STD_LOGIC;
				AP_ADR_I           : in  STD_LOGIC_VECTOR(31 downto 00);
				AP_WR_DATA_I       : in  STD_LOGIC_VECTOR(31 downto 00);
				AP_RD_DATA_O       : out STD_LOGIC_VECTOR(31 downto 00);
				AP_BYTE_SEL_I      : in  STD_LOGIC_VECTOR(03 downto 00);
				AP_RW_I            : in  STD_LOGIC;
				AP_CS_I            : in  STD_LOGIC;
				AP_DONE_O          : out STD_LOGIC;
				WB_DATA_I          : in  STD_LOGIC_VECTOR(31 downto 0);
				WB_DATA_O          : out STD_LOGIC_VECTOR(31 downto 0);
				WB_ADR_O           : out STD_LOGIC_VECTOR(31 downto 0);
				WB_ACK_I           : in  STD_LOGIC;
				WB_SEL_O           : out STD_LOGIC_VECTOR(03 downto 0);
				WB_WE_O            : out STD_LOGIC;
				WB_STB_O           : out STD_LOGIC;
				WB_CYC_O           : out STD_LOGIC
			);
  end component;

begin

	-- Reset Synchronizer ---------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		RESET_SYNC: process(CLK_I, RST_I, SYNC_RES)
		begin
			if rising_edge(CLK_I) then
				RST_INT     <= SYNC_RES(0) or SYNC_RES(1) or RST_I;
				SYNC_RES(1) <= SYNC_RES(0);
				SYNC_RES(0) <= RST_I;
			end if;
		end process RESET_SYNC;



	-- STORM Core Processor -------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		PROCESSOR_CORE: CORE
		Port map (
						RES             => RST_INT,
						CLK             => CLK_I,
						HALT            => ST_HALT,
						MODE            => ST_MODE,

						D_MEM_REQ       => ST_D_MEM_REQ,
						D_MEM_ADR       => ST_D_MEM_ADR,
						D_MEM_RD_DTA    => ST_D_MEM_RD_DTA,
						D_MEM_WR_DTA    => ST_D_MEM_WR_DTA,
						D_MEM_DQ        => ST_D_MEM_DQ,
						D_MEM_RW        => ST_D_MEM_RW,
						D_MEM_ABORT     => ST_D_MEM_ABORT,

						I_MEM_REQ       => ST_I_MEM_REQ,
						I_MEM_ADR       => ST_I_MEM_ADR,
						I_MEM_RD_DTA    => ST_I_MEM_RD_DTA,
						I_MEM_DQ        => ST_I_MEM_DQ,
						I_MEM_ABORT     => ST_I_MEM_ABORT,

						IRQ             => IRQ_I,
						FIQ             => FIQ_I
					);
			 
			 --- external interface ---
			 MODE_O  <= ST_MODE;



	-- Access Arbiter -------------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		PERIPHERAL_UNIT: ACCESS_ARBITER
		generic map (
					  SWITCH_ADR       => IO_BORDER,
					  RE1_TO_CNT       => 200,
					  RE2_TO_CNT       => 200,
					  CL1_INT_EN       => FALSE,
					  CL2_INT_EN       => FALSE
				)
		port map (
					CLK_I              => CLK_I,
					RST_I              => RST_INT,
					HALT_CLIENTS_O     => ST_HALT,

					CL1_ACC_REQ_I      => ST_D_MEM_REQ,
					CL1_ADR_I          => ST_D_MEM_ADR,
					CL1_WR_DATA_I      => ST_D_MEM_WR_DTA,
					CL1_RD_DATA_O      => ST_D_MEM_RD_DTA,
					CL1_DQ_I           => ST_D_MEM_DQ,
					CL1_RW_I           => ST_D_MEM_RW,
					CL1_TAG_I          => ST_MODE,
					CL1_ABORT_O        => D_ABORT,

					CL2_ACC_REQ_I      => ST_I_MEM_REQ,
					CL2_ADR_I          => ST_I_MEM_ADR,
					CL2_WR_DATA_I      => (others => '0'),
					CL2_RD_DATA_O      => ST_I_MEM_RD_DTA,
					CL2_DQ_I           => ST_I_MEM_DQ,
					CL2_RW_I           => '0', -- read only
					CL2_TAG_I          => ST_MODE,
					CL2_ABORT_O        => I_ABORT,

					RE1_ADR_O          => MEM_ADR,
					RE1_WR_DATA_O      => MEM_WR_DATA,
					RE1_RD_DATA_I      => MEM_RD_DATA,
					RE1_BYTE_SEL_O     => MEM_SEL,
					RE1_RW_O           => MEM_RW,
					RE1_CS_O           => MEM_CS,
					RE1_DONE_I         => '1', -- mem is allways ready

					RE2_ADR_O          => WI_ADR,
					RE2_WR_DATA_O      => WI_WR_DATA,
					RE2_RD_DATA_I      => WI_RD_DATA,
					RE2_BYTE_SEL_O     => WI_SEL,
					RE2_RW_O           => WI_RW,
					RE2_CS_O           => WI_CS,
					RE2_DONE_I         => WI_DONE
				);


	--- External Abort Interrupts ---
		ST_D_MEM_ABORT <= D_ABORT or D_ABT_I;
		ST_I_MEM_ABORT <= I_ABORT or I_ABT_I;
				

	-- Internal Memory ------------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		WORKING_MEMORY: MEMORY
		generic	map (
						MEM_SIZE      => IO_BORDER,
						LOG2_MEM_SIZE => LOG2_IO_BORDER
					 )
		port map	(
						CLK           => CLK_I,
						RES           => RST_INT,
						DATA_IN       => MEM_WR_DATA,
						DATA_OUT      => MEM_RD_DATA,
						ADR_IN        => MEM_ADR,
						SEL_IN        => MEM_SEL,
						CS            => MEM_CS,
						RW            => MEM_RW
					);



	-- Wishbone Interface ---------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		WISHBONE_INTERFACE: WISHBONE_IO
		Port map (
					CLK_I              => CLK_I,
					RST_I              => RST_INT,

					AP_ADR_I           => WI_ADR,
					AP_WR_DATA_I       => WI_WR_DATA,
					AP_RD_DATA_O       => WI_RD_DATA,
					AP_BYTE_SEL_I      => WI_SEL,
					AP_RW_I            => WI_RW,
					AP_CS_I            => WI_CS,
					AP_DONE_O          => WI_DONE,

					WB_DATA_I          => WB_DATA_I,
					WB_DATA_O          => WB_DATA_O,
					WB_ADR_O           => WB_ADR_O,
					WB_ACK_I           => WB_ACK_I,
					WB_SEL_O           => WB_SEL_O,
					WB_WE_O            => WB_WE_O,
					WB_STB_O           => WB_STB_O,
					WB_CYC_O           => WB_CYC_O
				);



end Structure;