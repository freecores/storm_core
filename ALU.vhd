-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #         Arithmetical/Logical/MCR_Access Unit        #
-- # *************************************************** #
-- # Version 2.4, 18.03.2011                             #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity ALU is
	port	(
-- ###############################################################################################
-- ##			Global Control                                                                      ##
-- ###############################################################################################

				CLK				: in  STD_LOGIC;							 -- global clock line
				RES				: in  STD_LOGIC;							 -- global reset line
				CTRL				: in  STD_LOGIC_VECTOR(31 downto 0); -- stage control lines

-- ###############################################################################################
-- ##			Operand Connection                                                                  ##
-- ###############################################################################################

				OP_A_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- operant a input
				OP_B_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- operant b input
				BP1_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- bypass input
				BP1_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- bypass output
				ADR_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- alu address output
				RESULT_OUT		: out STD_LOGIC_VECTOR(31 downto 0); -- EX result output

				FLAG_IN			: in  STD_LOGIC_VECTOR(03 downto 0); -- alu flags input
				FLAG_OUT			: out STD_LOGIC_VECTOR(03 downto 0); -- alu flgas output

				PC_IN				: in  STD_LOGIC_VECTOR(31 downto 0); -- program counter input
				INT_CALL_IN		: in  STD_LOGIC;							 -- this is an interrupt call
				
				MS_CARRY_IN		: in  STD_LOGIC;							 -- multiply/shift carry
				MS_OVFL_IN		: in  STD_LOGIC;							 -- multiply/shift overflow

				MCR_DTA_OUT		: out STD_LOGIC_VECTOR(31 downto 0); -- mcr write data output
				MCR_DTA_IN		: in  STD_LOGIC_VECTOR(31 downto 0); -- mcr read data input

-- ###############################################################################################
-- ##			Verious Signals                                                                     ##
-- ###############################################################################################

				MREQ_OUT			: out STD_LOGIC;							-- memory request signal

-- ###############################################################################################
-- ##			Forwarding Path                                                                     ##
-- ###############################################################################################

				ALU_FW_OUT		: out STD_LOGIC_VECTOR(40 downto 0)  -- forwarding path

			);
end ALU;

architecture ALU_STRUCTURE of ALU is

	-- Pipeline Register --
	signal	OP_B, OP_A, BP1				: STD_LOGIC_VECTOR(31 downto 0);
	signal	MS_CARRY_REG, MS_OVFL_REG	: STD_LOGIC;

	-- Local Signals --
	signal	ALU_OUT, ALU_OUT_2			: STD_LOGIC_VECTOR(31 downto 0);
	signal	ARITH_RES, LOGIC_RES			: STD_LOGIC_VECTOR(31 downto 0);
	signal	ARITH_FLAG_OUT					: STD_LOGIC_VECTOR(03 downto 0);
	signal	LOGIC_FLAG_OUT					: STD_LOGIC_VECTOR(03 downto 0);

begin

	-- Pipeline-Buffers ------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		ALU_BUFFER: process(CLK, RES)
		begin
			if rising_edge (CLK) then
				if (RES = '1') then
					OP_A         <= (others => '0');
					OP_B         <= (others => '0');
					BP1          <= (others => '0');
					MS_CARRY_REG <= '0';
					MS_OVFL_REG  <= '0';
				else
					OP_A         <= OP_A_IN;
					OP_B		    <= OP_B_IN;
					BP1	       <= BP1_IN;
					MS_CARRY_REG <= MS_CARRY_IN;
					MS_OVFL_REG  <= MS_OVFL_IN;
				end if;
			end if;
		end process ALU_BUFFER;



	-- Forwarding Paths ------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		ALU_FW_OUT(FWD_DATA_MSB downto FWD_DATA_LSB) <= ALU_OUT(31 downto 0);
		ALU_FW_OUT(FWD_RD_MSB   downto   FWD_RD_LSB) <= CTRL(CTRL_RD_3 downto CTRL_RD_0);
		
		ALU_FW_OUT(FWD_WB)        <= (CTRL(CTRL_EN) and CTRL(CTRL_WB_EN));--(CTRL(CTRL_EN) and (not CTRL(CTRL_BRANCH)) and CTRL(CTRL_WB_EN)); -- write back enabled
		ALU_FW_OUT(FWD_MEM_ACC)   <= CTRL(CTRL_MEM_ACC)  and (not CTRL(CTRL_MEM_RW)); -- memory read access
		ALU_FW_OUT(FWD_MCR_R_ACC) <= CTRL(CTRL_MREG_ACC) and (not CTRL(CTRL_MREG_RW)); -- mreg read access



	-- Arithemtical / Logical Units ------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		Arithmetical_Core:
			ARITHMETICAL_UNIT
				port map	(
								OP_A			=> OP_A,
								OP_B			=> OP_B,
								RESULT		=> ARITH_RES,
								BS_OVF_IN	=> MS_OVFL_REG,
								A_CARRY_IN	=> FLAG_IN(1),
								FLAG_OUT 	=> ARITH_FLAG_OUT,
								CTRL			=> CTRL(CTRL_ALU_FS_2 downto CTRL_ALU_FS_0)
							);

		Logical_Core:
			LOGICAL_UNIT
				port map (
								OP_A			=> OP_A,
								OP_B			=> OP_B,
								RESULT		=> LOGIC_RES,
								BS_CRY_IN	=> MS_CARRY_REG,
								BS_OVF_IN	=> MS_OVFL_REG,
								L_CARRY_IN	=> FLAG_IN(1),
								FLAG_OUT 	=> LOGIC_FLAG_OUT,
								CTRL			=> CTRL(CTRL_ALU_FS_2 downto CTRL_ALU_FS_0)
							);


		OPERATION_RESULT_MUX: process(CTRL(CTRL_ALU_FS_3))
		begin
			if (CTRL(CTRL_ALU_FS_3) = LOGICAL_OP) then -- LOGICAL OPERATION
				ALU_OUT  <= LOGIC_RES;
				FLAG_OUT <= LOGIC_FLAG_OUT;
			else -- ARITHMETICAL OPERATION
				ALU_OUT  <= ARITH_RES;
				FLAG_OUT <= ARITH_FLAG_OUT;
			end if;
		end process OPERATION_RESULT_MUX;



	-- Stage Data Mux --------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		DATA_OUT_MUX: process(CTRL, MCR_DTA_IN, ALU_OUT)
		begin
			if (CTRL(CTRL_MREG_ACC) = '1') and (CTRL(CTRL_MREG_RW) = '0') then
			--- MCR Read Access ---
				RESULT_OUT <= MCR_DTA_IN;
			else
			--- Normal Operation ---
				RESULT_OUT <= ALU_OUT;
			end if;

			--- MCR Connection ---
			MCR_DTA_OUT <= ALU_OUT;

			--- Memory Address ---
			ADR_OUT <= ALU_OUT;
		end process DATA_OUT_MUX;



	-- Bypass System ---------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		BP_MANAGER: process (BP1, PC_IN, CTRL)
		begin
			if (INT_CALL_IN = '1') then
				-- Interrupt Call --
				BP1_OUT <= PC_IN;
			else
				-- ALU Operation --
				BP1_OUT <= BP1;
			end if;
		end process BP_MANAGER;



--	-- Memory Request Signal -------------------------------------------------------------------------------
--	-- --------------------------------------------------------------------------------------------------------
--		MEM_REQ: process(CTRL(CTRL_EN), CTRL(CTRL_MEM_ACC))
--		begin
--			MREQ_OUT <= '0';
--			if (CTRL(CTRL_EN) = '1') and (CTRL(CTRL_MEM_ACC) = '1') then
--				MREQ_OUT <= '1';
--			end if;		
--		end process MEM_REQ;
	MREQ_OUT <= '1';



end ALU_STRUCTURE;