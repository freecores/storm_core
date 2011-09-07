-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #          Machine Control Register System            #
-- # *************************************************** #
-- # Version 3.1, 06.09.2011                             #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity MCR_SYS is
	port	(
-- ###############################################################################################
-- ##           Global Control                                                                  ##
-- ###############################################################################################

				CLK             : in  STD_LOGIC; -- global clock line
				G_HALT          : in  STD_LOGIC; -- global halt line
				RES             : in  STD_LOGIC; -- global reset line, high active

-- ###############################################################################################
-- ##           Global Control                                                                  ##
-- ###############################################################################################

				CTRL            : in  STD_LOGIC_VECTOR(31 downto 0); -- ctrl lines
				HALT_IN         : in  STD_LOGIC; -- halt request
				INT_TKN_OUT     : out STD_LOGIC; -- int taken signal

-- ###############################################################################################
-- ##           Operand Connection                                                              ##
-- ###############################################################################################

				FLAG_IN         : in  STD_LOGIC_VECTOR(03 downto 0); -- ALU flag input
				CMSR_OUT        : out STD_LOGIC_VECTOR(31 downto 0); -- sreg output

				REG_PC_OUT      : out STD_LOGIC_VECTOR(31 downto 0); -- PC value for manual ops
				JMP_PC_OUT      : out STD_LOGIC_VECTOR(31 downto 0); -- PC value for branches
				LNK_PC_OUT      : out STD_LOGIC_VECTOR(31 downto 0); -- PC value for linking
				INF_PC_OUT      : out STD_LOGIC_VECTOR(31 downto 0); -- PC value for instr fetch
				EXC_PC_OUT      : out STD_LOGIC_VECTOR(31 downto 0); -- PC value for exceptions

				MCR_DATA_IN     : in  STD_LOGIC_VECTOR(31 downto 0); -- mcr data input
				MCR_DATA_OUT    : out STD_LOGIC_VECTOR(31 downto 0); -- mcr data output

-- ###############################################################################################
-- ##           External Interrupt Lines                                                        ##
-- ###############################################################################################

				EX_FIQ_IN       : in  STD_LOGIC; -- fast int request
				EX_IRQ_IN       : in  STD_LOGIC; -- normal int request
				EX_ABT_IN       : in  STD_LOGIC; -- data abort int request
				EX_PRF_IN       : in  STD_LOGIC  -- instr abort int request

			);
end MCR_SYS;

architecture MCR_SYS_STRUCTURE of MCR_SYS is

	-- Internal Machine Control Registers --
	signal MCR_CMSR : STD_LOGIC_VECTOR(31 downto 0); -- Current Machine Status Register
	signal MCR_PC   : STD_LOGIC_VECTOR(31 downto 0); -- Program Counter
	signal SMSR_FIQ : STD_LOGIC_VECTOR(31 downto 0); -- Fast Interrupt Status Reg
	signal SMSR_SVC : STD_LOGIC_VECTOR(31 downto 0); -- Supervisor Status Reg
	signal SMSR_ABT : STD_LOGIC_VECTOR(31 downto 0); -- Prefetch Abort Status Reg
	signal SMSR_IRQ : STD_LOGIC_VECTOR(31 downto 0); -- Normal Interrupt Status Reg
	signal SMSR_UND : STD_LOGIC_VECTOR(31 downto 0); -- Undefined Instruction Status Reg

	-- Flag Construction Bus --
	signal FLAG_BUS : STD_LOGIC_VECTOR(31 downto 0);

	-- Context CTRL --
	signal CONT_EXE : STD_LOGIC;
	signal NEW_MODE : STD_LOGIC_VECTOR(04 downto 0);
	signal INT_VEC  : STD_LOGIC_VECTOR(04 downto 0);

	-- External Interrupt Sync FF --
	signal FIQ_SYNC  : STD_LOGIC;
	signal IRQ_SYNC  : STD_LOGIC;
	signal D_AB_SYNC : STD_LOGIC;
	signal P_AB_SYNC : STD_LOGIC;

begin

	-- External Interrupt Signal Synchronizer ---------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		EXT_INT_SYNC: process(CLK)
		begin
			if rising_edge(CLK) then
				if (RES = '1') then
					FIQ_SYNC  <= '0';
					IRQ_SYNC  <= '0';
					D_AB_SYNC <= '0';
					P_AB_SYNC <= '0';
				elsif (G_HALT = '0') then
					FIQ_SYNC  <= EX_FIQ_IN;
					IRQ_SYNC  <= EX_IRQ_IN;
					D_AB_SYNC <= EX_ABT_IN;
					P_AB_SYNC <= EX_PRF_IN;
				end if;
			end if;
		end process EXT_INT_SYNC;



	-- Interrupt Handler System -----------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		INT_HANDLER: process(MCR_CMSR, CTRL, IRQ_SYNC, FIQ_SYNC, D_AB_SYNC, P_AB_SYNC, FLAG_IN)
			variable FIQ_TAKEN, IRQ_TAKEN : STD_LOGIC; -- external int handler
			variable UND_TAKEN, SWI_TAKEN : STD_LOGIC; -- software int handler
			variable PRF_TAKEN, DAT_TAKEN : STD_LOGIC; -- mem abort int handler
		begin
			-- FIQ Trap taken --
			FIQ_TAKEN := FIQ_SYNC and (not MCR_CMSR(SREG_FIQ_DIS));
			-- IRQ Trap taken --
			IRQ_TAKEN := IRQ_SYNC and (not MCR_CMSR(SREG_IRQ_DIS));
			-- Data Abort Trap taken --
			DAT_TAKEN := D_AB_SYNC;
			-- Prefetch Abort Trap taken --
			PRF_TAKEN := P_AB_SYNC;
			-- Software Interrupt Trap taken --
			SWI_TAKEN := CTRL(CTRL_EN) and CTRL(CTRL_SWI);
			-- Undefined Instruction Trap taken --
			UND_TAKEN := CTRL(CTRL_EN) and CTRL(CTRL_UND);

			-- default values --
			FLAG_BUS <= MCR_CMSR;
			FLAG_BUS(SREG_C_FLAG) <= FLAG_IN(0); -- Carry Flag
			FLAG_BUS(SREG_Z_FLAG) <= FLAG_IN(1); -- Zero Flag
			FLAG_BUS(SREG_N_FLAG) <= FLAG_IN(2); -- Negative Flag
			FLAG_BUS(SREG_O_FLAG) <= FLAG_IN(3); -- Overflow Flag
			CONT_EXE <= '1';
			FLAG_BUS(SREG_FIQ_DIS) <= MCR_CMSR(SREG_FIQ_DIS); -- keep current interrupt settings
			FLAG_BUS(SREG_IRQ_DIS) <= MCR_CMSR(SREG_IRQ_DIS); -- keep current interrupt settings

			-- interrupt hirarchie / priority list --
			if (DAT_TAKEN = '1') then		-- data abort
				INT_VEC  <= DAT_INT_VEC;
				FLAG_BUS(SREG_MODE_4 downto SREG_MODE_0) <= Abort32_MODE;
				NEW_MODE <= Abort32_MODE;
			elsif (FIQ_TAKEN = '1') then	-- fast interrupt request
				INT_VEC  <= FIQ_INT_VEC;
				FLAG_BUS(SREG_MODE_4 downto SREG_MODE_0) <= FIQ32_MODE;
				NEW_MODE <= FIQ32_MODE;
				FLAG_BUS(SREG_FIQ_DIS) <= '1'; -- disable FIQ
			elsif (IRQ_TAKEN = '1') then	-- interrupt request
				INT_VEC  <= IRQ_INT_VEC;
				FLAG_BUS(SREG_MODE_4 downto SREG_MODE_0) <= IRQ32_MODE;
				NEW_MODE <= IRQ32_MODE;
				FLAG_BUS(SREG_IRQ_DIS) <= '1'; -- disable IRQ
			elsif (PRF_TAKEN = '1') then	-- prefetch abort
				INT_VEC  <= PRF_INT_VEC;
				FLAG_BUS(SREG_MODE_4 downto SREG_MODE_0) <= Abort32_MODE;
				NEW_MODE <= Abort32_MODE;
			elsif (UND_TAKEN = '1') then	-- undefined instruction
				INT_VEC  <= UND_INT_VEC;
				FLAG_BUS(SREG_MODE_4 downto SREG_MODE_0) <= Undefined32_MODE;
				NEW_MODE <= Undefined32_MODE;
			elsif (SWI_TAKEN = '1') then	-- software interrupt
				INT_VEC  <= SWI_INT_VEC;
				FLAG_BUS(SREG_MODE_4 downto SREG_MODE_0) <= Supervisor32_MODE;
				NEW_MODE <= Supervisor32_MODE;
			else							-- normal operation
				CONT_EXE <= '0';
				INT_VEC  <= (others => '0');
				NEW_MODE <= MCR_CMSR(SREG_MODE_4 downto SREG_MODE_0); -- keep current mode
			end if;

		end process INT_HANDLER;



	-- Machine Control Registers ----------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		MREG_WRITE_ACCESS: process(CLK, RES, CTRL, MCR_CMSR, MCR_PC, SMSR_FIQ, SMSR_SVC, SMSR_ABT,
		                           SMSR_IRQ, SMSR_UND, CONT_EXE, HALT_IN, NEW_MODE)
			variable MWR_SMSR, MWR_CMSR	: STD_LOGIC;
			variable CURRENT_MODE       : STD_LOGIC_VECTOR(4 downto 0);
			variable CONT_RET           : STD_LOGIC;
			variable CMSR_ACC_CASE      : STD_LOGIC_VECTOR(2 downto 0);
			variable PC_ACC_CASE        : STD_LOGIC_VECTOR(3 downto 0);
		begin
			-- manual SMSR write access --
			MWR_SMSR := CTRL(CTRL_MREG_ACC) and CTRL(CTRL_MREG_M) and CTRL(CTRL_MREG_RW);

			-- manual CMSR write access --
			MWR_CMSR := CTRL(CTRL_MREG_ACC) and (not CTRL(CTRL_MREG_M)) and CTRL(CTRL_MREG_RW);
			-- current operating mode --
			CURRENT_MODE := MCR_CMSR(SREG_MODE_4 downto SREG_MODE_0);

			-- return from interrupt --
			CONT_RET := '0';
			if ((CTRL(CTRL_RD_3 downto CTRL_RD_0) = C_PC_ADR) and (CTRL(CTRL_AF) = '1') and
				(CURRENT_MODE /= User32_MODE)) then
				CONT_RET := '1';
			end if;

			-- synchronous write --
			if rising_edge(CLK) then
				if (RES = '1') then
					MCR_PC   <= (others => '0'); -- start at 0
					MCR_CMSR <= (others => '0');
					MCR_CMSR(SREG_FIQ_DIS) <= '1'; -- disable FIQ
					MCR_CMSR(SREG_IRQ_DIS) <= '1'; -- disable FIQ
					MCR_CMSR(SREG_MODE_4 downto SREG_MODE_0) <= Supervisor32_MODE; -- we're the boss after rest
					SMSR_FIQ <= x"ACABBAAF"; -- setup value
					SMSR_SVC <= x"00000013"; -- setup value
					SMSR_ABT <= x"B1B0B3AB"; -- setup value
					SMSR_IRQ <= x"B7BEB1DF"; -- setup value
					SMSR_UND <= x"B6B1B8FF"; -- setup value

				elsif (G_HALT = '0') then
					---- PROGRAM COUNTERS --------------------------------------------------------------

--					PC_ACC_CASE := CONT_EXE & CTRL(CTRL_BRANCH) & HALT_IN & MCR_CMSR(SREG_THUMB);
--					case PC_ACC_CASE is
--						-- load PC with interrupt vector
--						when "1000" | "1001" | "1010" | "1011" | "1100" | "1101" | "1110" | "1111" =>
--							MCR_PC <= x"000000" & "000" & INT_VEC;
--						-- load PC with brnach destination
--						when "0100" | "0101" | "0110" | "0111" =>
--							MCR_PC <= MCR_DATA_IN;
--						-- normal ARM operation
--						when "0000" =>
--							MCR_PC <= Std_Logic_Vector(unsigned(MCR_PC) + 4);
--						-- normal THUMB operation
--						when "0001" =>
--							MCR_PC <= Std_Logic_Vector(unsigned(MCR_PC) + 2);
--						-- keep value
--						when others =>
--							MCR_PC <= MCR_PC;
--					end case;

					if (CONT_EXE = '1') then -- load PC with interrupt vector
						MCR_PC <= x"000000" & "000" & INT_VEC;
					elsif (CTRL(CTRL_BRANCH) = '1') then -- taken branch
						MCR_PC <= MCR_DATA_IN;
					elsif (HALT_IN = '0') then -- no hold request -> normal operation
						if (MCR_CMSR(SREG_THUMB) = '1') then
						-- THUMB MODE --
							MCR_PC <= Std_Logic_Vector(unsigned(MCR_PC) + 2);
						else
						-- ARM MODE --
							MCR_PC <= Std_Logic_Vector(unsigned(MCR_PC) + 4);
						end if;
					end if;

					---- CURRENT MACHINE STATUS REGISTER -----------------------------------------------
					CMSR_ACC_CASE := CTRL(CTRL_EN) & CONT_RET & MWR_CMSR;
					case CMSR_ACC_CASE is
						when "110" | "111" => -- context down change
							case (CURRENT_MODE) is -- current mode
								when FIQ32_MODE         => MCR_CMSR <= SMSR_FIQ;
								when Supervisor32_MODE  => MCR_CMSR <= SMSR_SVC;
								when Abort32_MODE       => MCR_CMSR <= SMSR_ABT;
								when IRQ32_MODE         => MCR_CMSR <= SMSR_IRQ;
								when Undefined32_MODE   => MCR_CMSR <= SMSR_UND;
								when others             => MCR_CMSR <= MCR_CMSR;
							end case;
						when "101" => -- manual write
							if (CURRENT_MODE = User32_MODE) or (CTRL(CTRL_MREG_FA) = '1') then -- restricted access for user mode
								MCR_CMSR <= MCR_DATA_IN(31 downto 28) & MCR_CMSR(27 downto 0);
							else
								MCR_CMSR <= MCR_DATA_IN(31 downto 0); -- full sreg access
							end if;
						when "100" => -- automatic access
							if (CTRL(CTRL_AF) = '1') then -- alter flags
								MCR_CMSR <= FLAG_BUS(31 downto 0); -- update whole sreg
							else
								MCR_CMSR <= MCR_CMSR(31 downto 28) & FLAG_BUS(27 downto 0); -- update without flags
							end if;
						when others => -- keep CMSR
							MCR_CMSR <= MCR_CMSR;
					end case;

--					if (CTRL(CTRL_EN) and CONT_RET) = '1' then -- context down change
--						case (CURRENT_MODE) is -- current mode
--							when FIQ32_MODE         => MCR_CMSR <= SMSR_FIQ;
--							when Supervisor32_MODE  => MCR_CMSR <= SMSR_SVC;
--							when Abort32_MODE       => MCR_CMSR <= SMSR_ABT;
--							when IRQ32_MODE         => MCR_CMSR <= SMSR_IRQ;
--							when Undefined32_MODE   => MCR_CMSR <= SMSR_UND;
--							when others             => MCR_CMSR <= MCR_CMSR;
--						end case;
--					elsif (CTRL(CTRL_EN) and MWR_CMSR) = '1' then -- manual write
--						if (CURRENT_MODE = User32_MODE) or (CTRL(CTRL_MREG_FA) = '1') then -- restricted access for user mode
--							MCR_CMSR <= MCR_DATA_IN(31 downto 28) & MCR_CMSR(27 downto 0);
--						else
--							MCR_CMSR <= MCR_DATA_IN(31 downto 0); -- full sreg access
--						end if;						
--					elsif (CTRL(CTRL_EN) = '1') then -- automatic access
--						if (CTRL(CTRL_AF) = '1') then -- alter flags
--							MCR_CMSR <= FLAG_BUS(31 downto 0); -- update whole sreg
--						else
--							MCR_CMSR <= MCR_CMSR(31 downto 28) & FLAG_BUS(27 downto 0); -- update without flags
--						end if;
--					end if;

					---- SAVED MACHINE STATUS REGISTER -------------------------------------------------
					if (CONT_EXE = '1') then -- context up change
						case (NEW_MODE) is
							when FIQ32_MODE        => SMSR_FIQ <= MCR_CMSR;
							when Supervisor32_MODE => SMSR_SVC <= MCR_CMSR;
							when Abort32_MODE      => SMSR_ABT <= MCR_CMSR;
							when IRQ32_MODE        => SMSR_IRQ <= MCR_CMSR;
							when Undefined32_MODE  => SMSR_UND <= MCR_CMSR;
							when others            => NULL;
						end case;
					elsif (CTRL(CTRL_EN) and MWR_SMSR) = '1' then -- manual data write
						if (CTRL(CTRL_MREG_FA) = '1') then
							-- flag access only --
							case (CURRENT_MODE) is
								when FIQ32_MODE        => SMSR_FIQ <= MCR_DATA_IN(31 downto 28) & SMSR_FIQ(27 downto 0);
								when Supervisor32_MODE => SMSR_SVC <= MCR_DATA_IN(31 downto 28) & SMSR_SVC(27 downto 0);
								when Abort32_MODE      => SMSR_ABT <= MCR_DATA_IN(31 downto 28) & SMSR_ABT(27 downto 0);
								when IRQ32_MODE        => SMSR_IRQ <= MCR_DATA_IN(31 downto 28) & SMSR_IRQ(27 downto 0);
								when Undefined32_MODE  => SMSR_UND <= MCR_DATA_IN(31 downto 28) & SMSR_UND(27 downto 0);
								when others            => NULL;
							end case;
						else
							-- full SMSR access --
							case (CURRENT_MODE) is
								when FIQ32_MODE        => SMSR_FIQ <= MCR_DATA_IN;
								when Supervisor32_MODE => SMSR_SVC <= MCR_DATA_IN;
								when Abort32_MODE      => SMSR_ABT <= MCR_DATA_IN;
								when IRQ32_MODE        => SMSR_IRQ <= MCR_DATA_IN;
								when Undefined32_MODE  => SMSR_UND <= MCR_DATA_IN;
								when others            => NULL;
							end case;
						end if;
					end if;

				end if;
			end if;
		end process MREG_WRITE_ACCESS;



	-- MCR Read Access --------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		MREG_READ_ACCESS: process(CTRL, MCR_CMSR, SMSR_FIQ, SMSR_SVC, SMSR_ABT, SMSR_IRQ, SMSR_UND)
			variable MRD_SMSR, MRD_CMSR : STD_LOGIC;
		begin
			-- manual SMSR_mode read access request --
			MRD_SMSR := CTRL(CTRL_MREG_ACC) and CTRL(CTRL_MREG_M) and (not CTRL(CTRL_MREG_RW));
			-- manual CMSR read access request --
			MRD_CMSR := CTRL(CTRL_MREG_ACC) and (not CTRL(CTRL_MREG_M)) and (not CTRL(CTRL_MREG_RW));

			if (MRD_CMSR and CTRL(CTRL_EN)) = '1' then
				MCR_DATA_OUT <= MCR_CMSR;
			elsif (MRD_SMSR and CTRL(CTRL_EN)) = '1' then
				case (MCR_CMSR(SREG_MODE_4 downto SREG_MODE_0)) is
					when FIQ32_MODE        => MCR_DATA_OUT <= SMSR_FIQ;
					when Supervisor32_MODE => MCR_DATA_OUT <= SMSR_SVC;
					when Abort32_MODE      => MCR_DATA_OUT <= SMSR_ABT;
					when IRQ32_MODE        => MCR_DATA_OUT <= SMSR_IRQ;
					when Undefined32_MODE  => MCR_DATA_OUT <= SMSR_UND;
					when others            => MCR_DATA_OUT <= (others => '0');
				end case;
			else
				MCR_DATA_OUT <= (others => '0');
			end if;		
		end process MREG_READ_ACCESS;



	-- MCR PC Output ----------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		PC_DELAY_UNIT: process(CLK, RES, HALT_IN, MCR_PC)
			variable PC_A, PC_B, PC_C, PC_D : STD_LOGIC_VECTOR(31 downto 00);
		begin
			--- PC delay chain ---
			if rising_edge(CLK) then
				if (RES = '1') then
					PC_A := (others => '0');
					PC_B := (others => '0');
					PC_C := (others => '0');
					PC_D := (others => '0');
				elsif (G_HALT = '0') then
					PC_D := PC_C;
					PC_C := PC_B;
					PC_B := PC_A;
					if (HALT_IN = '0') then
						PC_A := MCR_PC;
					end if;
				end if;
			end if;

			--- PC output ---
			INF_PC_OUT <= MCR_PC; -- PC value for instruction fetch
			JMP_PC_OUT <= PC_A;   -- PC value for branch operations
			LNK_PC_OUT <= PC_B;   -- PC value for link operations
			REG_PC_OUT <= PC_A;   -- PC value for manual operations
			EXC_PC_OUT <= PC_D;   -- PC value for exceptions
			
		end process PC_DELAY_UNIT;



	-- MCR Data Output --------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------
		CMSR_OUT    <= MCR_CMSR; -- current status register
		INT_TKN_OUT <= CONT_EXE; -- interrupt was taken


end MCR_SYS_STRUCTURE;