-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #                Multiply/Shift Unit                  #
-- # *************************************************** #
-- # Version 1.0.0, 21.03.2011                           #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity MS_UNIT is
	port	(
-- ###############################################################################################
-- ##			Global Control                                                                      ##
-- ###############################################################################################

				CLK				: in  STD_LOGIC;							 -- global clock line
				RES				: in  STD_LOGIC;							 -- global reset line
				CTRL				: in  STD_LOGIC_VECTOR(31 downto 0); -- stage control lines

-- ###############################################################################################
-- ##			Operant Connection                                                                  ##
-- ###############################################################################################

				OP_A_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- operant a input
				OP_B_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- operant b input
				BP_IN				: in  STD_LOGIC_VECTOR(31 downto 0); -- bypass input
				CARRY_IN			: in  STD_LOGIC;							 -- carry input

				SHIFT_V_IN		: in  STD_LOGIC_VECTOR(04 downto 0); -- shift value in
				SHIFT_M_IN		: in  STD_LOGIC_VECTOR(01 downto 0); -- shift mode in

				OP_A_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- operant a bypass
				BP_OUT			: out STD_LOGIC_VECTOR(31 downto 0); -- bypass output
				RESULT_OUT		: out STD_LOGIC_VECTOR(31 downto 0); -- operation result
				CARRY_OUT		: out STD_LOGIC;							 -- operation carry signal
				OVFL_OUT			: out STD_LOGIC;							 -- operation overflow signal

-- ###############################################################################################
-- ##			Forwarding Path                                                                     ##
-- ###############################################################################################

				MSU_FW_OUT		: out STD_LOGIC_VECTOR(40 downto 0)  -- forwarding path

			);
end MS_UNIT;

architecture Structural of MS_UNIT is

	-- Pipeline Registers --
	signal	OP_A_REG			: STD_LOGIC_VECTOR(31 downto 0);
	signal	OP_B_REG			: STD_LOGIC_VECTOR(31 downto 0);
	signal	BP_REG			: STD_LOGIC_VECTOR(31 downto 0);
	signal	SHIFT_V_TEMP	: STD_LOGIC_VECTOR(04 downto 0);
	signal	SHIFT_M_TEMP	: STD_LOGIC_VECTOR(01 downto 0);
	
	-- Local Signals --
	signal	OP_RESULT		: STD_LOGIC_VECTOR(31 downto 0);
	signal	SFT_DATA			: STD_LOGIC_VECTOR(31 downto 0);
	signal	MUL_DATA			: STD_LOGIC_VECTOR(31 downto 0);
	signal	SFT_CARRY		: STD_LOGIC;
	signal	MUL_CARRY		: STD_LOGIC;
	signal	SFT_OVFL			: STD_LOGIC;
	signal	MUL_OVFL			: STD_LOGIC;

begin

	-- Pipeline-Buffers ------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		MS_BUFFER: process(CLK, RES)
		begin
			if rising_edge (CLK) then
				if (RES = '1') then
					OP_A_REG     <= (others => '0');
					OP_B_REG     <= (others => '0');
					BP_REG       <= (others => '0');
					SHIFT_V_TEMP <= (others => '0');
					SHIFT_M_TEMP <= (others => '0');
				else
					OP_A_REG     <= OP_A_IN;
					OP_B_REG     <= OP_B_IN;
					BP_REG       <= BP_IN;
					SHIFT_V_TEMP <= SHIFT_V_IN;
					SHIFT_M_TEMP <= SHIFT_M_IN;
				end if;
			end if;
		end process MS_BUFFER;



	-- Multiplicator ---------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		Multiplicator:
			MULTIPLY_UNIT
				port map	(
								OP_B			=> OP_B_REG,	-- operand B input
								OP_C			=> BP_REG,		-- operand C input
								RESULT		=> MUL_DATA,	-- multiplication data result
								CARRY_OUT	=> MUL_CARRY,	-- multiplication carry result
								OVFL_OUT		=> MUL_OVFL		-- multiplication overflow result
							);


	-- Barrelshifter ---------------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		Barrelshifter:
			BARREL_SHIFTER
				port map (
								SHIFT_DATA_IN	=> OP_B_REG,		-- data getting shifted
								SHIFT_DATA_OUT	=> SFT_DATA,		-- shift data result
								CARRY_IN			=> CARRY_IN,		-- carry input
								CARRY_OUT		=> SFT_CARRY,		-- carry output
								OVERFLOW_OUT	=> SFT_OVFL,		-- overflow output
								SHIFT_MODE		=> SHIFT_M_TEMP,	-- shift mode
								SHIFT_POS		=> SHIFT_V_TEMP	-- shift positions
							);
							
							
	-- Operation Result Selector ---------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		RESULT_DATA_MUX: process(CTRL(CTRL_MS))
		begin

			if (CTRL(CTRL_MS) = '1') then -- use multiply result
				OP_RESULT <= MUL_DATA;
				CARRY_OUT <= MUL_CARRY;
				OVFL_OUT  <= MUL_OVFL;
			else -- use shift result
				OP_RESULT <= SFT_DATA;
				CARRY_OUT <= SFT_CARRY;
				OVFL_OUT  <= SFT_OVFL;
			end if;

		end process RESULT_DATA_MUX;



	-- Module Data Output ----------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		RESULT_OUT <= OP_RESULT; -- Operation Data Result
		OP_A_OUT   <= OP_A_REG;  -- Operant A Output
		BP_OUT     <= BP_REG;    -- Bypass Output



	-- Forwarding Path -----------------------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		-- Operation Data Result --
		MSU_FW_OUT(FWD_DATA_MSB downto FWD_DATA_LSB) <= OP_RESULT;

		-- Destination Register Address --
		MSU_FW_OUT(FWD_RD_MSB downto FWD_RD_LSB) <= CTRL(CTRL_RD_3 downto CTRL_RD_0);

		-- Data Write Back Enabled --
		MSU_FW_OUT(FWD_WB) <= CTRL(CTRL_EN) and CTRL(CTRL_WB_EN);

		-- Carry-Need For Rotate Right Extended Shift --
		MSU_FW_OUT(FWD_CY_NEED) <= '1' when ((CTRL(CTRL_EN) = '1') and (SHIFT_M_TEMP = S_RRX) and (SHIFT_V_TEMP = "00000")) else '0';

		-- MREG Read Access --
		MSU_FW_OUT(FWD_MCR_R_ACC) <= CTRL(CTRL_EN) and CTRL(CTRL_MREG_ACC) and (not CTRL(CTRL_MREG_RW));

		-- Memory Read Access --
		MSU_FW_OUT(FWD_MEM_ACC) <= CTRL(CTRL_EN) and CTRL(CTRL_MEM_ACC)  and (not CTRL(CTRL_MEM_RW));



end Structural;