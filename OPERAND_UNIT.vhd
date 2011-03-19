-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #          Operand Fetch & Forwarding Unit            #
-- # *************************************************** #
-- # Version 2.3, 18.03.2011                             #
-- #######################################################


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity OPERAND_UNIT is
	port	(
-- ###############################################################################################
-- ##			Local Control                                                                       ##
-- ###############################################################################################
				
				CTRL_IN			: in  STD_LOGIC_VECTOR(31 downto 0);
				OP_ADR_IN		: in  STD_LOGIC_VECTOR(11 downto 0);
				CONF_HALT_OUT	: out STD_LOGIC;

-- ###############################################################################################
-- ##			Operand Connection                                                                  ##
-- ###############################################################################################

				OP_A_IN			: in 	STD_LOGIC_VECTOR(31 downto 0);
				OP_B_IN			: in	STD_LOGIC_VECTOR(31 downto 0);
				OP_C_IN			: in	STD_LOGIC_VECTOR(31 downto 0);
				SHIFT_VAL_IN	: in	STD_LOGIC_VECTOR(04 downto 0);
				PC1_IN			: in  STD_LOGIC_VECTOR(31 downto 0);
				PC2_IN			: in  STD_LOGIC_VECTOR(31 downto 0);
				IMM_IN			: in  STD_LOGIC_VECTOR(31 downto 0);
				IS_INT_IN		: in  STD_LOGIC;

				OP_A_OUT			: out	STD_LOGIC_VECTOR(31 downto 0);
				OP_B_OUT			: out	STD_LOGIC_VECTOR(31 downto 0);
				SHIFT_VAL_OUT	: out STD_LOGIC_VECTOR(04 downto 0);
				BP1_OUT			: out	STD_LOGIC_VECTOR(31 downto 0);
				
-- ###############################################################################################
-- ##			Forwarding Pathes                                                                   ##
-- ###############################################################################################

				ALU_FW_IN		: in  STD_LOGIC_VECTOR(38 downto 0);
				MEM_FW_IN		: in  STD_LOGIC_VECTOR(36 downto 0)

			);
end OPERAND_UNIT;

architecture OPERAND_UNIT_STRUCTURE of OPERAND_UNIT is

	-- local signals --
	signal OP_A, OP_B, OP_C	: STD_LOGIC_VECTOR(31 downto 0);

begin

	-- Data Dependency Detector & Forwarding Unit ------------------------------------------------------------
	-- ----------------------------------------------------------------------------------------------------------
	DATA_DEPENDENCY_DETECTOR: process(CTRL_IN, OP_ADR_IN, ALU_FW_IN, MEM_FW_IN, OP_A_IN, OP_B_IN, OP_C_IN)
	begin -- ex-data have higher priority than mem-data

		--- DATA DEPENDENCY FOR OPERANT A ---
		---------------------------------------------------------------------------------------
		if (OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = ALU_FW_IN(FWD_RD_3 downto FWD_RD_0)) and (ALU_FW_IN(FWD_WB) = '1') then
			-- do forward OP_A from EX stage if source/destination adresses are equal
			-- and if instruction in EX stage is valid (STAGE_ENABLE = 1)
			OP_A <= ALU_FW_IN(31 downto 0);
		elsif (OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = MEM_FW_IN(FWD_RD_3 downto FWD_RD_0)) and (MEM_FW_IN(FWD_WB) = '1') then
			-- do forward OP_A from MEM stage if source/destination adresses are equal
			-- and if instruction in MEM stage is valid (STAGE_ENABLE = 1)
			OP_A <= MEM_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
		else
			-- no forwarding, get new data from reg-file
			OP_A <= OP_A_IN;
		end if;
		
		--- DATA DEPENDENCY FOR OPERANT B ---
		---------------------------------------------------------------------------------------
		if (OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = ALU_FW_IN(FWD_RD_3 downto FWD_RD_0)) and (ALU_FW_IN(FWD_WB) = '1') then
			-- do forward OP_B from EX stage if source/destination adresses are equal
			-- and if instruction in EX stage is valid (STAGE_ENABLE = 1)	
			OP_B <= ALU_FW_IN(31 downto 0);
		elsif (OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = MEM_FW_IN(FWD_RD_3 downto FWD_RD_0)) and (MEM_FW_IN(FWD_WB) = '1') then
			-- do forward OP_B from EX stage if source/destination adresses are equal
			-- and if instruction in MEM stage is valid (STAGE_ENABLE = 1)
			OP_B <= MEM_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);	
		else
			-- no forwarding, get new data from reg-file
			OP_B <= OP_B_IN;
		end if;
		
		--- DATA DEPENDENCY FOR OPERANT C ---
		---------------------------------------------------------------------------------------
		if (OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = ALU_FW_IN(FWD_RD_3 downto FWD_RD_0)) and (ALU_FW_IN(FWD_WB) = '1') then
			-- do forward OP_A from EX stage if source/destination adresses are equal
			-- and if instruction in EX stage is valid (STAGE_ENABLE = 1)
			OP_C <= ALU_FW_IN(31 downto 00);
		elsif (OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0) = MEM_FW_IN(FWD_RD_3 downto FWD_RD_0)) and (MEM_FW_IN(FWD_WB) = '1') then
			-- do forward OP_A from MEM stage if source/destination adresses are equal
			-- and if instruction in MEM stage is valid (STAGE_ENABLE = 1)
			OP_C <= MEM_FW_IN(FWD_DATA_MSB downto FWD_DATA_LSB);
		else
			-- no forwarding, get new data from reg-file
			OP_C <= OP_C_IN;
		end if;

		--- MEMORY DATA DEPENDENCY ---
		---------------------------------------------------------------------------------------
		-- [RA(OF) = RD(EX)] or [(RB(OF) = RD(EX) and (CONSTANT = 0))]
		CONF_HALT_OUT <= '0'; -- default
		if ( OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0) = ALU_FW_IN(FWD_RD_3 downto FWD_RD_0)) or
			((OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0) = ALU_FW_IN(FWD_RD_3 downto FWD_RD_0)) and (CTRL_IN(CTRL_CONST) = '0')) then
			-- (EX_ENABLE = 1) and (MEM_READ_ACCES = 1)
			if ((ALU_FW_IN(FWD_WB) and ALU_FW_IN(FWD_MEM_ACC)) = '1') then
				CONF_HALT_OUT <= '1';
			end if;		
		end if;
		
	end process DATA_DEPENDENCY_DETECTOR;



	-- Multiplexer for operands A, B, BP1, Shift_Value ------------------------------------------------------
	-- ---------------------------------------------------------------------------------------------------------
	OPERAND_MUX: process(CTRL_IN, PC2_IN, OP_A, OP_B, OP_C, IMM_IN, PC1_IN, SHIFT_VAL_IN, IS_INT_IN)
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
			if (IS_INT_IN = '0') then -- is this an int call?
				BP1_OUT <= PC1_IN;	-- actual program counter
			else
				BP1_OUT <= PC2_IN;	-- past program counter when interrupt call
			end if;
		else
			BP1_OUT <= OP_C;		-- fowarding unit port C output
		end if;
	end process OPERAND_MUX;


end OPERAND_UNIT_STRUCTURE;