-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #        Operand Fetch & Forwarding/Stall Unit        #
-- # *************************************************** #
-- # Version 2.4.2, 01.04.2011                           #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity OPERAND_UNIT is
	port	(
-- ###############################################################################################
-- ##			Global Control                                                                      ##
-- ###############################################################################################

				CLK				: in  STD_LOGIC; -- global clock
				RES				: in  STD_LOGIC; -- global reset (active high)

				CTRL_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- control lines
				OP_ADR_IN		: in  STD_LOGIC_VECTOR(11 downto 0); -- operand addresses from decoder

-- ###############################################################################################
-- ##			Operand Connection                                                                  ##
-- ###############################################################################################

				OP_A_IN			: in 	STD_LOGIC_VECTOR(31 downto 0); -- operand A reg_file output
				OP_B_IN			: in	STD_LOGIC_VECTOR(31 downto 0); -- operant B reg_file output
				OP_C_IN			: in	STD_LOGIC_VECTOR(31 downto 0); -- operant C reg_file output
				SHIFT_VAL_IN	: in	STD_LOGIC_VECTOR(04 downto 0); -- immediate shift value input
				PC1_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- current program counter
				PC2_In			: in  STD_LOGIC_VECTOR(31 downto 0); -- delayed program counter
				IMM_IN			: in  STD_LOGIC_VECTOR(31 downto 0); -- immediate data input

				OP_A_OUT			: out	STD_LOGIC_VECTOR(31 downto 0); -- new operand A
				OP_B_OUT			: out	STD_LOGIC_VECTOR(31 downto 0); -- new operant B
				SHIFT_VAL_OUT	: out STD_LOGIC_VECTOR(04 downto 0); -- new shift value
				BP1_OUT			: out	STD_LOGIC_VECTOR(31 downto 0); -- new operant C (BP)
				
				HOLD_BUS_OUT	: out STD_LOGIC_VECTOR(02 downto 0); -- insert n bubbles
				
-- ###############################################################################################
-- ##			Forwarding Pathes                                                                   ##
-- ###############################################################################################

				MSU_FW_IN		: in  STD_LOGIC_VECTOR(40 downto 0); -- msu forwarding data & ctrl
				ALU_FW_IN		: in  STD_LOGIC_VECTOR(40 downto 0); -- alu forwarding data & ctrl
				MEM_FW_IN		: in  STD_LOGIC_VECTOR(40 downto 0); -- memory forwarding data & ctrl
				WB_FW_IN			: in  STD_LOGIC_VECTOR(40 downto 0)  -- write back forwaring data & ctrl

			);
end OPERAND_UNIT;

architecture OPERAND_UNIT_STRUCTURE of OPERAND_UNIT is

	-- Local Signals --
	signal	OP_A, OP_B, OP_C	: STD_LOGIC_VECTOR(31 downto 0);
	
	-- Address Match --
	signal	MSU_A_MATCH, MSU_B_MATCH, MSU_C_MATCH	: STD_LOGIC;
	signal	ALU_A_MATCH, ALU_B_MATCH, ALU_C_MATCH	: STD_LOGIC;
	signal	MEM_A_MATCH, MEM_B_MATCH, MEM_C_MATCH	: STD_LOGIC;
	signal	WB_A_MATCH,  WB_B_MATCH,  WB_C_MATCH	: STD_LOGIC;
	signal	MSU_MATCH,   ALU_MATCH,   MEM_MATCH		: STD_LOGIC;

begin

	-- Address Match Detector --------------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
		ADR_MATCH: process(OP_ADR_IN, MSU_FW_IN, ALU_FW_IN, MEM_FW_IN, WB_FW_IN)
		begin

			--- Default Values ---
			MSU_A_MATCH <= '0'; MSU_B_MATCH <= '0'; MSU_C_MATCH <= '0';
			ALU_A_MATCH <= '0'; ALU_B_MATCH <= '0'; ALU_C_MATCH <= '0';
			MEM_A_MATCH <= '0'; MEM_B_MATCH <= '0'; MEM_C_MATCH <= '0';
			WB_A_MATCH  <= '0'; WB_B_MATCH  <= '0'; WB_C_MATCH  <= '0';
		
			--- Multiply/Shift Unit ---
			if OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = MSU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				MSU_A_MATCH <= MSU_FW_IN(FWD_WB);
			end if;
			if OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = MSU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				MSU_B_MATCH <= MSU_FW_IN(FWD_WB);--not CTRL_IN(CTRL_CONST);
			end if;
			if OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = MSU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				MSU_C_MATCH <= MSU_FW_IN(FWD_WB);
			end if;

			--- Arithmetical/Logical Unit ---
			if OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = ALU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				ALU_A_MATCH <= ALU_FW_IN(FWD_WB);
			end if;
			if OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = ALU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				ALU_B_MATCH <= ALU_FW_IN(FWD_WB);--not CTRL_IN(CTRL_CONST);
			end if;
			if OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = ALU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				ALU_C_MATCH <= ALU_FW_IN(FWD_WB);
			end if;

			--- Memory-Access Unit ---
			if OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = MEM_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				MEM_A_MATCH <= MEM_FW_IN(FWD_WB);
			end if;
			if OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = MEM_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				MEM_B_MATCH <= MEM_FW_IN(FWD_WB);--not CTRL_IN(CTRL_CONST);
			end if;
			if OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = MEM_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				MEM_C_MATCH <= MEM_FW_IN(FWD_WB);
			end if;

			--- Register File/Write Back ---
			if OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = WB_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				WB_A_MATCH <= WB_FW_IN(FWD_WB);
			end if;
			if OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = WB_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				WB_B_MATCH <= WB_FW_IN(FWD_WB);--not CTRL_IN(CTRL_CONST);
			end if;
			if OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = WB_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				WB_C_MATCH <= WB_FW_IN(FWD_WB);
			end if;
		
		end process ADR_MATCH;



	-- Local Data Dependency Detector & Forwarding Unit ------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
		LOCAL_DATA_DEPENDENCY_DETECTOR: process  (CTRL_IN, ALU_FW_IN, MEM_FW_IN, ALU_A_MATCH, ALU_B_MATCH,
																ALU_C_MATCH, MEM_A_MATCH, MEM_B_MATCH, MEM_C_MATCH, WB_A_MATCH,
																WB_B_MATCH, WB_C_MATCH)
		begin
		
			-- Forward OP_X from EX/MEM/WB-stage if source and destination addresses are equal
			-- and if the the instruction in the corresponding stage will perform a valid data write back.
			-- Data from early stages has higher priority than data from later stages.


			--- LOCAL DATA DEPENDENCY FOR OPERANT A ---------------------
			----------------------------------------------------------------
			if (ALU_A_MATCH = '1') then
				OP_A <= ALU_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			elsif (MEM_A_MATCH = '1') then
				OP_A <= MEM_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			elsif (WB_A_MATCH = '1') then
				OP_A <= WB_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			else
				OP_A <= OP_A_IN;
			end if;

			--- LOCAL DATA DEPENDENCY FOR OPERANT B ---------------------
			----------------------------------------------------------------
			if (ALU_B_MATCH = '1') then
				OP_B <= ALU_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			elsif (MEM_B_MATCH = '1') then
				OP_B <= MEM_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			elsif (WB_B_MATCH = '1') then
				OP_B <= WB_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			else
				OP_B <= OP_B_IN;
			end if;

			--- LOCAL DATA DEPENDENCY FOR OPERANT C ---------------------
			----------------------------------------------------------------
			if (ALU_C_MATCH = '1') then
				OP_C <= ALU_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			elsif (MEM_C_MATCH = '1') then
				OP_C <= MEM_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			elsif (WB_C_MATCH = '1') then
				OP_C <= WB_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			else
				OP_C <= OP_C_IN;
			end if;

	end process LOCAL_DATA_DEPENDENCY_DETECTOR;



	-- Address Match Detector For ANY Match ------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
		MSU_MATCH <= (MSU_A_MATCH or MSU_B_MATCH or MSU_C_MATCH);
		ALU_MATCH <= (ALU_A_MATCH or ALU_B_MATCH or ALU_C_MATCH);



	-- Temporal Data Dependeny Detector and Bubble Inserter --------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
		CYCLE_ARBITER_INPUT: process(MSU_MATCH, ALU_MATCH, MSU_FW_IN, ALU_FW_IN)
		begin
			-- Data conflicts that cannot be solved by forwarding = Temporal Data Dependencies
			-- -> Pipeline Stalls (= Bubbles) needed
			
			-- MSU_MATCH only	   => 1 cycle(s) of wait
			-- MSU_MATCH and mem => 2 cycle(s) of wait
			-- ALU_MATCH and mem => 2 cycle(s) of wait
			-- BRANCH				=> 3 cycle(s) of invalid

			-- HOLD/INVALIDADE enable --
			HOLD_BUS_OUT(0) <= MSU_MATCH or (ALU_MATCH and ALU_FW_IN(FWD_MEM_ACC));

			-- Cycles needed to solve the temporal data dependency --
			HOLD_BUS_OUT(2 downto 1) <= (others => '0'); -- default
			if ((MSU_MATCH = '1') and (MSU_FW_IN(FWD_MEM_ACC) = '1')) then --or
					HOLD_BUS_OUT(2 downto 1) <= "01"; -- OF <- MS mem_data/mcr conflict
			end if;

		end process CYCLE_ARBITER_INPUT;



	-- Operand Multiplexers ---------------------------------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------
		OPERAND_MUX: process(CTRL_IN, PC2_IN, OP_A, OP_B, OP_C, IMM_IN, PC1_IN, SHIFT_VAL_IN)
		begin

			---- OPERANT A ----------------------------------------------
			----------------------------------------------------------------
			if (CTRL_IN(CTRL_BRANCH) = '1') then -- BRANCH_INSTR signal
				-- delayed program counter --
				OP_A_OUT <= PC2_IN;
			else
				-- fowarding unit port A output --
				OP_A_OUT <= OP_A;
			end if;

			---- OPERANT B ----------------------------------------------
			----------------------------------------------------------------
			if (CTRL_IN(CTRL_CONST) = '1') then -- CONST signal
				-- immediate --
				OP_B_OUT <= IMM_IN;
			else
				-- fowarding unit port B output --
				OP_B_OUT <= OP_B;
			end if;

			---- SHIFT VALUE --------------------------------------------
			----------------------------------------------------------------
			if (CTRL_IN(CTRL_SHIFTR) = '1') then -- SHIFT_REG
				-- fowarding unit port C output --
				SHIFT_VAL_OUT <= OP_C(4 downto 0);
			else
				-- immediate shift value --
				SHIFT_VAL_OUT <= SHIFT_VAL_IN;
			end if;

			---- BYPASS DATA --------------------------------------------
			----------------------------------------------------------------
			if (CTRL_IN(CTRL_LINK) = '1') then -- LINK signal
				-- current program counter --
				BP1_OUT <= PC1_IN;
			else
				-- fowarding unit port C output --
				BP1_OUT <= OP_C;
			end if;
		end process OPERAND_MUX;



end OPERAND_UNIT_STRUCTURE;