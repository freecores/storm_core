-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #        32x32 Bit Banked 1w3r Register File          #
-- # *************************************************** #
-- # Version 2.0, 18.03.2011                             #
-- #######################################################


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity REG_FILE is
	port	(
-- ###############################################################################################
-- ##			Global Control                                                                      ##
-- ###############################################################################################

				CLK				: in  STD_LOGIC;
				RES				: in  STD_LOGIC;
				
-- ###############################################################################################
-- ##			Local Control                                                                       ##
-- ###############################################################################################
				
				CTRL_IN			: in  STD_LOGIC_VECTOR(31 downto 0);
				OP_ADR_IN		: in  STD_LOGIC_VECTOR(11 downto 0);
				MODE_IN			: in  STD_LOGIC_VECTOR(04 downto 0); -- current mode
				
				DEBUG_R0			: out STD_LOGIC_VECTOR(07 downto 0);
				DEBUG_R1			: out STD_LOGIC_VECTOR(07 downto 0);

-- ###############################################################################################
-- ##			Operand Connection                                                                  ##
-- ###############################################################################################

				MEM_DATA_IN		: in  STD_LOGIC_VECTOR(31 downto 0);
				BP2_DATA_IN		: in  STD_LOGIC_VECTOR(31 downto 0);
				PC_IN				: in  STD_LOGIC_VECTOR(31 downto 0);

				OP_A_OUT			: out STD_LOGIC_VECTOR(31 downto 0);
				OP_B_OUT			: out STD_LOGIC_VECTOR(31 downto 0);
				OP_C_OUT			: out STD_LOGIC_VECTOR(31 downto 0)
				
			);
end REG_FILE;

architecture REG_FILE_STRUCTURE of REG_FILE is

	-- Operand buffers --
	signal	BP2_DATA		: STD_LOGIC_VECTOR(31 downto 0);
	signal	MEM_DATA		: STD_LOGIC_VECTOR(31 downto 0);
	
	-- Local Signals --
	signal	REG_WB_DATA	: STD_LOGIC_VECTOR(31 downto 0);

	-- User Mode Registers --
	type		USER32_REG_FILE_TYPE is array(0 to 14) of STD_LOGIC_VECTOR(31 downto 0);
	signal	USER32_REG_FILE			: USER32_REG_FILE_TYPE;

	-- Fast Int Req Mode Registers --
	type		FIQ32_REG_FILE_TYPE is array(8 to 14) of STD_LOGIC_VECTOR(31 downto 0);
	signal	FIQ32_REG_FILE				: FIQ32_REG_FILE_TYPE;
	
	-- Supervisor Mode Registers --
	type		SUPERVISOR32_REG_FILE_TYPE is array(13 to 14) of STD_LOGIC_VECTOR(31 downto 0);
	signal	SUPERVISOR32_REG_FILE	: SUPERVISOR32_REG_FILE_TYPE;
	
	-- Abort Mode Registers --
	type		ABORT32_REG_FILE_TYPE is array(13 to 14) of STD_LOGIC_VECTOR(31 downto 0);
	signal	ABORT32_REG_FILE			: ABORT32_REG_FILE_TYPE;
	
	-- Int Req Mode Registers --
	type		IRQ32_REG_FILE_TYPE is array(13 to 14) of STD_LOGIC_VECTOR(31 downto 0);
	signal	IRQ32_REG_FILE				: IRQ32_REG_FILE_TYPE;
	
	-- Undefined Mode Registers --
	type		UNDEFINED32_REG_FILE_TYPE is array(13 to 14) of STD_LOGIC_VECTOR(31 downto 0);
	signal	UNDEFINED32_REG_FILE		: UNDEFINED32_REG_FILE_TYPE;


begin

	-- Pipeline-Buffers ---------------------------------------------------------------
	-- -----------------------------------------------------------------------------------
		OF_BUFFER: process(CLK)
		begin
			if rising_edge(CLK) then
				if (RES = '1') then
					BP2_DATA <= (others => '0');
					MEM_DATA <= (others => '0');
				else
					BP2_DATA <= BP2_DATA_IN;
					MEM_DATA <= MEM_DATA_IN; 
				end if;
			end if;
		end process OF_BUFFER;
	
	
	
	-- Data Flow Switch ---------------------------------------------------------------
	-- -----------------------------------------------------------------------------------
		WB_DATA_MUX: process(CTRL_IN, MEM_DATA, BP2_DATA)
		begin
			-- memory read access
			if (CTRL_IN(CTRL_MEM_ACC) = '1') and (CTRL_IN(CTRL_MEM_RW) = '0') then
				REG_WB_DATA <= MEM_DATA;
			else -- register/mcr read access
				REG_WB_DATA <= BP2_DATA;
			end if;
		end process WB_DATA_MUX;



	-- Banked Register File Write Access ----------------------------------------------
	-- -----------------------------------------------------------------------------------
		BANK_REG_WRITE_ACCESS: process(CLK, CTRL_IN(CTRL_RD_3 downto CTRL_RD_0))
			variable REG_ADR  : integer range 0 to 15;
		begin
		
			REG_ADR := to_integer(unsigned(CTRL_IN(CTRL_RD_3 downto CTRL_RD_0)));
		
			if falling_edge(CLK) then
				if ((CTRL_IN(CTRL_EN) and CTRL_IN(CTRL_WB_EN)) = '1') then
	
					case (CTRL_IN(CTRL_MODE_4 downto CTRL_MODE_0)) is -- old mode
					
						when USER32_MODE =>
							USER32_REG_FILE(REG_ADR) <= REG_WB_DATA;
							
						when FIQ32_MODE =>
							if (REG_ADR < 8) then
								USER32_REG_FILE(REG_ADR) <= REG_WB_DATA;
							else
								FIQ32_REG_FILE(REG_ADR) <= REG_WB_DATA;
							end if;

						when Supervisor32_MODE =>
							if (REG_ADR < 13) then
								USER32_REG_FILE(REG_ADR) <= REG_WB_DATA;
							else
								Supervisor32_REG_FILE(REG_ADR) <= REG_WB_DATA;
							end if;
							
						when Abort32_MODE =>
							if (REG_ADR < 13) then
								USER32_REG_FILE(REG_ADR) <= REG_WB_DATA;
							else
								Abort32_REG_FILE(REG_ADR) <= REG_WB_DATA;
							end if;
							
						when IRQ32_MODE =>
							if (REG_ADR < 13) then
								USER32_REG_FILE(REG_ADR) <= REG_WB_DATA;
							else
								IRQ32_REG_FILE(REG_ADR) <= REG_WB_DATA;
							end if;
							
						when Undefined32_MODE =>
							if (REG_ADR < 13) then
								USER32_REG_FILE(REG_ADR) <= REG_WB_DATA;
							else
								UNDEFINED32_REG_FILE(REG_ADR) <= REG_WB_DATA;
							end if;
							
						when others =>
							NULL;

					end case;
	
				end if;
			end if;
		end process BANK_REG_WRITE_ACCESS;
		


	-- Banked Register File Read Access -----------------------------------------------
	-- -----------------------------------------------------------------------------------
		BANK_REG_READ_ACCESS: process(OP_ADR_IN, MODE_IN)
			variable REG_ADR_A, REG_ADR_B, REG_ADR_C  : integer range 0 to 15;
		begin
		
			REG_ADR_A := to_integer(unsigned(OP_ADR_IN(OP_A_ADR_3 downto OP_A_ADR_0)));
			REG_ADR_B := to_integer(unsigned(OP_ADR_IN(OP_B_ADR_3 downto OP_B_ADR_0)));
			REG_ADR_C := to_integer(unsigned(OP_ADR_IN(OP_C_ADR_3 downto OP_C_ADR_0)));
			
			DEBUG_R0(7 downto 0) <= USER32_REG_FILE(13)(7 downto 0);
			DEBUG_R1(7 downto 0) <= USER32_REG_FILE(14)(7 downto 0);
	
			case (MODE_IN) is -- current mode
					
				when USER32_MODE =>
					if (REG_ADR_A < 15) then
						OP_A_OUT <= USER32_REG_FILE(REG_ADR_A);
					else
						OP_A_OUT <= PC_IN;
					end if;
					if (REG_ADR_B < 15) then
						OP_B_OUT <= USER32_REG_FILE(REG_ADR_B);
					else
						OP_B_OUT <= PC_IN;
					end if;
					if (REG_ADR_C < 15) then
						OP_C_OUT <= USER32_REG_FILE(REG_ADR_C);
					else
						OP_C_OUT <= PC_IN;
					end if;

		
				when FIQ32_MODE =>
					if (REG_ADR_A < 8) then
						OP_A_OUT <= USER32_REG_FILE(REG_ADR_A);
					elsif (REG_ADR_A = 15) then
						OP_A_OUT <= PC_IN;
					else
						OP_A_OUT <= FIQ32_REG_FILE(REG_ADR_A);
					end if;
					if (REG_ADR_B < 8) then
						OP_B_OUT <= USER32_REG_FILE(REG_ADR_B);
					elsif (REG_ADR_B = 15) then
						OP_B_OUT <= PC_IN;
					else
						OP_B_OUT <= FIQ32_REG_FILE(REG_ADR_B);
					end if;
					if (REG_ADR_C < 8) then
						OP_C_OUT <= USER32_REG_FILE(REG_ADR_C);
					elsif (REG_ADR_C = 15) then
						OP_C_OUT <= PC_IN;
					else
						OP_C_OUT <= FIQ32_REG_FILE(REG_ADR_C);
					end if;


				when Supervisor32_MODE =>
					if (REG_ADR_A < 13) then
						OP_A_OUT <= USER32_REG_FILE(REG_ADR_A);
					elsif (REG_ADR_A = 15) then
						OP_A_OUT <= PC_IN;
					else
						OP_A_OUT <= SUPERVISOR32_REG_FILE(REG_ADR_A);
					end if;
					if (REG_ADR_B < 13) then
						OP_B_OUT <= USER32_REG_FILE(REG_ADR_B);
					elsif (REG_ADR_B = 15) then
						OP_B_OUT <= PC_IN;
					else
						OP_B_OUT <= SUPERVISOR32_REG_FILE(REG_ADR_B);
					end if;
					if (REG_ADR_C < 13) then
						OP_C_OUT <= USER32_REG_FILE(REG_ADR_C);
					elsif (REG_ADR_C = 15) then
						OP_C_OUT <= PC_IN;
					else
						OP_C_OUT <= SUPERVISOR32_REG_FILE(REG_ADR_C);
					end if;


				when Abort32_MODE =>
					if (REG_ADR_A < 13) then
						OP_A_OUT <= USER32_REG_FILE(REG_ADR_A);
					elsif (REG_ADR_A = 15) then
						OP_A_OUT <= PC_IN;
					else
						OP_A_OUT <= ABORT32_REG_FILE(REG_ADR_A);
					end if;
					if (REG_ADR_B < 13) then
						OP_B_OUT <= USER32_REG_FILE(REG_ADR_B);
					elsif (REG_ADR_B = 15) then
						OP_B_OUT <= PC_IN;
					else
						OP_B_OUT <= ABORT32_REG_FILE(REG_ADR_B);
					end if;
					if (REG_ADR_C < 13) then
						OP_C_OUT <= USER32_REG_FILE(REG_ADR_C);
					elsif (REG_ADR_C = 15) then
						OP_C_OUT <= PC_IN;
					else
						OP_C_OUT <= ABORT32_REG_FILE(REG_ADR_C);
					end if;


				when IRQ32_MODE =>
					if (REG_ADR_A < 13) then
						OP_A_OUT <= USER32_REG_FILE(REG_ADR_A);
					elsif (REG_ADR_A = 15) then
						OP_A_OUT <= PC_IN;
					else
						OP_A_OUT <= IRQ32_REG_FILE(REG_ADR_A);
					end if;
					if (REG_ADR_B < 13) then
						OP_B_OUT <= USER32_REG_FILE(REG_ADR_B);
					elsif (REG_ADR_B = 15) then
						OP_B_OUT <= PC_IN;
					else
						OP_B_OUT <= IRQ32_REG_FILE(REG_ADR_B);
					end if;
					if (REG_ADR_C < 13) then
						OP_C_OUT <= USER32_REG_FILE(REG_ADR_C);
					elsif (REG_ADR_C = 15) then
						OP_C_OUT <= PC_IN;
					else
						OP_C_OUT <= IRQ32_REG_FILE(REG_ADR_C);
					end if;


				when Undefined32_MODE =>
					if (REG_ADR_A < 13) then
						OP_A_OUT <= USER32_REG_FILE(REG_ADR_A);
					elsif (REG_ADR_A = 15) then
						OP_A_OUT <= PC_IN;
					else
						OP_A_OUT <= UNDEFINED32_REG_FILE(REG_ADR_A);
					end if;
					if (REG_ADR_B < 13) then
						OP_B_OUT <= USER32_REG_FILE(REG_ADR_B);
					elsif (REG_ADR_B = 15) then
						OP_B_OUT <= PC_IN;
					else
						OP_B_OUT <= UNDEFINED32_REG_FILE(REG_ADR_B);
					end if;
					if (REG_ADR_C < 13) then
						OP_C_OUT <= USER32_REG_FILE(REG_ADR_C);
					elsif (REG_ADR_C = 15) then
						OP_C_OUT <= PC_IN;
					else
						OP_C_OUT <= UNDEFINED32_REG_FILE(REG_ADR_C);
					end if;
					
				
				when others =>
					OP_A_OUT <= (others => '-');
					OP_B_OUT <= (others => '-');
					OP_C_OUT <= (others => '-');

			end case;
		end process BANK_REG_READ_ACCESS;


end REG_FILE_STRUCTURE;