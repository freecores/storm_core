-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #        Arithmetical/Logical/MCR_Contact Unit        #
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
				CTRL				: in  STD_LOGIC_VECTOR(31 downto 0); -- control lines

-- ###############################################################################################
-- ##			Operand Connection                                                                  ##
-- ###############################################################################################

				OP_A_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- operant a input
				OP_B_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- operant b input
				BP1_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- bypass input
				BP1_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- bypass output
				ALU_RES_OUT		: out STD_LOGIC_VECTOR(31 downto 0); -- alu result output
				DATA_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- data output

				SHIFT_V_IN		: in  STD_LOGIC_VECTOR(04 downto 0); -- shift value in
				SHIFT_M_IN		: in  STD_LOGIC_VECTOR(01 downto 0); -- shift mode in

				FLAG_IN			: in  STD_LOGIC_VECTOR(03 downto 0); -- alu flags input
				FLAG_OUT			: out STD_LOGIC_VECTOR(03 downto 0); -- alu flgas output

				MCR_DTA_OUT		: out STD_LOGIC_VECTOR(31 downto 0); -- mcr write data output
				MCR_DTA_IN		: in  STD_LOGIC_VECTOR(31 downto 0); -- mcr read data input

-- ###############################################################################################
-- ##			Verious Signals                                                                     ##
-- ###############################################################################################

				MREQ_OUT			: out STD_LOGIC;							-- memory request for next cycle

-- ###############################################################################################
-- ##			Forwarding Path                                                                     ##
-- ###############################################################################################

				ALU_FW_OUT		: out STD_LOGIC_VECTOR(38 downto 0)  -- forwarding path

			);
end ALU;

architecture ALU_STRUCTURE of ALU is

	-- local signals --
	signal	OP_B_TEMP, OP_B, OP_A		: STD_LOGIC_VECTOR(31 downto 0);
	signal	SHIFT_V_TEMP					: STD_LOGIC_VECTOR(04 downto 0);
	signal	SHIFT_M_TEMP					: STD_LOGIC_VECTOR(01 downto 0);
	signal	BP1								: STD_LOGIC_VECTOR(31 downto 0);
	signal	ALU_OUT, ALU_OUT_2			: STD_LOGIC_VECTOR(31 downto 0);
	signal	BS_CRY_LINE, BS_OVF_LINE	: STD_LOGIC;
	signal	ARITH_RES, LOGIC_RES			: STD_LOGIC_VECTOR(31 downto 0);
	signal	ARITH_FLAG_OUT					: STD_LOGIC_VECTOR(03 downto 0);
	signal	LOGIC_FLAG_OUT					: STD_LOGIC_VECTOR(03 downto 0);

begin

	-- Pipeline-Buffers ------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		EX_BUFFER: process(CLK, RES)
		begin
			if rising_edge (CLK) then
				if (RES = '1') then
					OP_A         <= (others => '0');
					OP_B_TEMP    <= (others => '0');
					BP1          <= (others => '0');
					SHIFT_V_TEMP <= (others => '0');
					SHIFT_M_TEMP <= (others => '0');
				else
					OP_A         <= OP_A_IN;
					OP_B_TEMP    <= OP_B_IN;
					BP1	       <= BP1_IN;
					SHIFT_V_TEMP <= SHIFT_V_IN;
					SHIFT_M_TEMP <= SHIFT_M_IN;
				end if;
			end if;
		end process EX_BUFFER;



	-- Forwarding Paths ------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		-- MREG_READ_ACCESS & MEM_READ_ACCESS & STAGE_ENABLE & R_DEST 
		ALU_FW_OUT(FWD_DATA_MSB downto FWD_DATA_LSB) <= ALU_OUT(31 downto 0);
		ALU_FW_OUT(FWD_RD_3 downto FWD_RD_0)         <= CTRL(CTRL_RD_3 downto CTRL_RD_0);
		
		ALU_FW_OUT(FWD_WB)      <= (CTRL(CTRL_EN) and (not CTRL(CTRL_BRANCH)) and CTRL(CTRL_WB_EN)); -- write back enabled
		ALU_FW_OUT(FWD_MEM_ACC) <= CTRL(CTRL_MEM_ACC)  and (not CTRL(CTRL_MEM_RW)); -- memory read access
		ALU_FW_OUT(FWD_MCR_ACC) <= CTRL(CTRL_MREG_ACC) and (not CTRL(CTRL_MREG_RW)); -- mreg read access



	-- Barrelshifter ---------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		Barrelshifter:
			BARREL_SHIFTER
				port map (
								SHIFT_DATA_IN	=> OP_B_TEMP,
								SHIFT_DATA_OUT	=> OP_B,
								CARRY_IN			=> FLAG_IN(1),
								CARRY_OUT		=> BS_CRY_LINE,
								OVERFLOW_OUT	=> BS_OVF_LINE,
								SHIFT_MODE		=> SHIFT_M_TEMP,
								SHIFT_POS		=> SHIFT_V_TEMP
							);


	-- Arithemtical / Logical Core -------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		Arithmetical_Core:
			ARITHMETICAL_UNIT
				port map	(
								OP_A			=> OP_A,
								OP_B			=> OP_B,
								RESULT		=> ARITH_RES,
								BS_OVF_IN	=> BS_OVF_LINE,
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
								BS_CRY_IN	=> BS_CRY_LINE,
								BS_OVF_IN	=> BS_OVF_LINE,
								L_CARRY_IN	=> FLAG_IN(1),
								FLAG_OUT 	=> LOGIC_FLAG_OUT,
								CTRL			=> CTRL(CTRL_ALU_FS_2 downto CTRL_ALU_FS_0)
							);


		OPERATION_RESULT_MUX: process(CTRL(CTRL_ALU_FS_3))
		begin
			if (CTRL(CTRL_ALU_FS_3) = LOGICAL_OP) then
				ALU_OUT  <= LOGIC_RES;
				FLAG_OUT <= LOGIC_FLAG_OUT;
			else -- CTRL(CTRL_ALU_FS_3) = ARITHMETICAL_OP
				ALU_OUT  <= ARITH_RES;
				FLAG_OUT <= ARITH_FLAG_OUT;
			end if;
		end process OPERATION_RESULT_MUX;



	-- Stage Data Mux --------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		DATA_OUT_MUX: process(CTRL(CTRL_MREG_ACC), CTRL(CTRL_MREG_RW))
		begin
			if (CTRL(CTRL_MREG_ACC) = '1') and (CTRL(CTRL_MREG_RW) = '0') then -- mcr read access
				ALU_OUT_2 <= MCR_DTA_IN;
			else -- normal alu operation
				ALU_OUT_2 <= ALU_OUT;
			end if;
		end process DATA_OUT_MUX;
		
		MCR_DTA_OUT <= ALU_OUT;		-- MCR connection
		ALU_RES_OUT <= ALU_OUT_2;	-- ALU result



	-- Bypass System ---------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		BP_MANAGER: process (BP1, ALU_OUT_2, CTRL(CTRL_LINK))
		begin
			if (CTRL(CTRL_LINK) = '1') then
				BP1_OUT <= BP1;
			else
				BP1_OUT <= ALU_OUT_2;
			end if;
		end process BP_MANAGER;

		DATA_OUT <= BP1;



	-- Memory Request Generator ----------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		MEM_REQ: process(CTRL(CTRL_EN), CTRL(CTRL_MEM_ACC))
		begin
			MREQ_OUT <= '0';
			if (CTRL(CTRL_EN) = '1') and (CTRL(CTRL_MEM_ACC) = '1') then
				MREQ_OUT <= '1';
			end if;		
		end process MEM_REQ;



end ALU_STRUCTURE;