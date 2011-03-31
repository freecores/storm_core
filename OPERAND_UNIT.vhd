-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #        Operand Fetch & Forwarding/Stall Unit        #
-- # *************************************************** #
-- # Version 2.4.1, 25.03.2011                           #
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
				
				STALLS_OUT		: out STD_LOGIC_VECTOR(02 downto 0); -- insert n bubbles
				
-- ###############################################################################################
-- ##			Forwarding Pathes                                                                   ##
-- ###############################################################################################

				MSU_FW_IN		: in  STD_LOGIC_VECTOR(40 downto 0); -- msu forwarding data & ctrl
				ALU_FW_IN		: in  STD_LOGIC_VECTOR(40 downto 0); -- alu forwarding data & ctrl
				MEM_FW_IN		: in  STD_LOGIC_VECTOR(40 downto 0)  -- memory forwarding data & ctrl

			);
end OPERAND_UNIT;

architecture OPERAND_UNIT_STRUCTURE of OPERAND_UNIT is

	-- Local Signals --
	signal	OP_A, OP_B, OP_C	: STD_LOGIC_VECTOR(31 downto 0);
	
	-- Address Match --
	signal	MSU_A_MATCH, MSU_B_MATCH, MSU_C_MATCH	: STD_LOGIC;
	signal	ALU_A_MATCH, ALU_B_MATCH, ALU_C_MATCH	: STD_LOGIC;
	signal	MEM_A_MATCH, MEM_B_MATCH, MEM_C_MATCH	: STD_LOGIC;
	signal	MSU_MATCH,   ALU_MATCH,   MEM_MATCH		: STD_LOGIC;

begin

	-- Address Match Detector --------------------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
		ADR_MATCH: process(OP_ADR_IN, MSU_FW_IN, ALU_FW_IN, MEM_FW_IN)
		begin

			--- Default Values ---
			MSU_A_MATCH <= '0'; MSU_B_MATCH <= '0'; MSU_C_MATCH <= '0';
			ALU_A_MATCH <= '0'; ALU_B_MATCH <= '0'; ALU_C_MATCH <= '0';
			MEM_A_MATCH <= '0'; MEM_B_MATCH <= '0'; MEM_C_MATCH <= '0';
		
			--- Multiply/Shift Unit ---
			if OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = MSU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				MSU_A_MATCH <= '1';
			end if;
			if OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = MSU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				MSU_B_MATCH <= not CTRL_IN(CTRL_CONST);
			end if;
			if OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = MSU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				MSU_C_MATCH <= '1';
			end if;

			--- Arithmetical/Logical Unit ---
			if OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = ALU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				ALU_A_MATCH <= '1';
			end if;
			if OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = ALU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				ALU_B_MATCH <= not CTRL_IN(CTRL_CONST);
			end if;
			if OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = ALU_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				ALU_C_MATCH <= '1';
			end if;

			--- Memory-Access Unit ---
			if OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = MEM_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				MEM_A_MATCH <= '1';
			end if;
			if OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = MEM_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				MEM_B_MATCH <= not CTRL_IN(CTRL_CONST);
			end if;
			if OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = MEM_FW_IN(FWD_RD_MSB downto FWD_RD_LSB) then
				MEM_C_MATCH <= '1';
			end if;
		
		end process ADR_MATCH;



	-- Local Data Dependency Detector & Forwarding Unit ------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
		DIRECT_DATA_DEPENDENCY_DETECTOR: process (CTRL_IN, ALU_FW_IN, MEM_FW_IN, ALU_A_MATCH, ALU_B_MATCH,
																ALU_C_MATCH, MEM_A_MATCH, MEM_B_MATCH, MEM_C_MATCH)
		begin
		
			-- Forward OP_X from EX-stage/MEM-stage if source and destination addresses are equal
			-- and if the the instruction in the corresponding stage will perform a valid data write back.
			-- Data from EX stage has higher priority than data from MEM stage.


			--- LOCAL DATA DEPENDENCY FOR OPERANT A ---
			----------------------------------------------------------------
			if (ALU_A_MATCH = '1') and (ALU_FW_IN(FWD_WB) = '1') then
				OP_A <= ALU_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			elsif (MEM_A_MATCH = '1') and (MEM_FW_IN(FWD_WB) = '1') then
				OP_A <= MEM_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			else
				OP_A <= OP_A_IN;
			end if;


			--- LOCAL DATA DEPENDENCY FOR OPERANT B ---
			----------------------------------------------------------------
			if (ALU_B_MATCH = '1') and (ALU_FW_IN(FWD_WB) = '1') then
				OP_B <= ALU_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			elsif (MEM_B_MATCH = '1') and (MEM_FW_IN(FWD_WB) = '1') then
				OP_B <= MEM_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);	
			else
				OP_B <= OP_B_IN;
			end if;


			--- LOCAL DATA DEPENDENCY FOR OPERANT C ---
			----------------------------------------------------------------
			if (ALU_C_MATCH = '1') and (ALU_FW_IN(FWD_WB) = '1') then
				OP_C <= ALU_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			elsif (MEM_C_MATCH = '1') and (MEM_FW_IN(FWD_WB) = '1') then
				OP_C <= MEM_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
			else
				OP_C <= OP_C_IN;
			end if;

	end process DIRECT_DATA_DEPENDENCY_DETECTOR;



	-- Address Match Detector For ANY Match ------------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
		MSU_MATCH <= (MSU_A_MATCH or MSU_B_MATCH or MSU_C_MATCH) and MSU_FW_IN(FWD_WB);
		ALU_MATCH <= (ALU_A_MATCH or ALU_B_MATCH or ALU_C_MATCH) and ALU_FW_IN(FWD_WB);



	-- Temporal Data Dependeny Detector and Bubble Inserter --------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
		BUBBLE_MACHINE: process(MSU_MATCH, ALU_MATCH, MSU_FW_IN, ALU_FW_IN)
		begin
			-- Data conflicts that cannot be solved by forwarding = Temporal Data Dependencies
			-- -> Pipeline Stalls (= Bubbles) needed

			if (MSU_MATCH = '1') then
				if (MSU_FW_IN(FWD_MEM_ACC) = '1') then
					STALLS_OUT <= OF_MS_MEM_DD; -- OF <- MS mem data conflict
				elsif (MSU_FW_IN(FWD_MCR_R_ACC) = '1') or (MSU_FW_IN(FWD_CY_NEED) = '1') then
					STALLS_OUT <= OF_MS_MCR_DD; -- OF <- MS mcr / flag data conflict
				else
					STALLS_OUT <= OF_MS_REG_DD; -- OF <- MS reg data conflict
				end if;
			elsif (ALU_MATCH = '1') and (ALU_FW_IN(FWD_MEM_ACC) = '1') then
				STALLS_OUT <= OF_EX_MEM_DD; -- OF <- EX mem data conflict
			else
				STALLS_OUT(2 downto 0) <= (others => '0'); -- no current/future stalls
			end if;
		end process BUBBLE_MACHINE;



	-- Multiplexer for operands A, B, BP1, Shift_Value ------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------
		OPERAND_MUX: process(CTRL_IN, PC2_IN, OP_A, OP_B, OP_C, IMM_IN, PC1_IN, SHIFT_VAL_IN)
		begin

			---- OPERANT A ----------------------------------------------
			if (CTRL_IN(CTRL_BRANCH) = '1') then -- BRANCH_INSTR signal
				OP_A_OUT <= PC2_IN;  -- delayed program counter
			else
				OP_A_OUT <= OP_A;		-- fowarding unit port A output
			end if;

			---- OPERANT B ----------------------------------------------
			if (CTRL_IN(CTRL_CONST) = '1') then -- CONST signal
				OP_B_OUT <= IMM_IN;	-- immediate
			else
				OP_B_OUT <= OP_B;		-- fowarding unit port B output
			end if;

			---- SHIFT VALUE --------------------------------------------
			if (CTRL_IN(CTRL_SHIFTR) = '1') then -- SHIFT_REG
				SHIFT_VAL_OUT <= OP_C(4 downto 0);	-- fowarding unit port C output
			else
				SHIFT_VAL_OUT <= SHIFT_VAL_IN;		-- immediate shift value
			end if;

			---- BYPASS DATA --------------------------------------------
			if (CTRL_IN(CTRL_LINK) = '1') then -- LINK signal
				BP1_OUT <= PC1_IN;	-- current program counter
			else
				BP1_OUT <= OP_C;		-- fowarding unit port C output
			end if;
		end process OPERAND_MUX;



end OPERAND_UNIT_STRUCTURE;