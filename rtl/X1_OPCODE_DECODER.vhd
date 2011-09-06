-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #           ARM-Native OPCODE Decoding Unit           #
-- # *************************************************** #
-- # Version 2.4.6, 01.09.2011                           #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

-- ###############################################################################################
-- ##       Interface                                                                           ##
-- ###############################################################################################

entity X1_OPCODE_DECODER is
	Port	(
				OPCODE_DATA_IN  : in  STD_LOGIC_VECTOR(31 downto 0);
				OPCODE_CTRL_IN  : in  STD_LOGIC_VECTOR(15 downto 0);
				OPCODE_CTRL_OUT : out STD_LOGIC_VECTOR(99 downto 0)
			);
end X1_OPCODE_DECODER;

architecture instruction_decoder of X1_OPCODE_DECODER is

-- ###############################################################################################
-- ##       Local Signals                                                                       ##
-- ###############################################################################################

	-- INPUTS --
	signal	INSTR_REG       : STD_LOGIC_VECTOR(31 downto 00);
	signal	DUAL_OP         : STD_LOGIC;

	-- OUTPUTS --
	signal	DEC_CTRL        : STD_LOGIC_VECTOR(31 downto 00);
	signal	OP_ADR_OUT      : STD_LOGIC_VECTOR(11 downto 00);
	signal	IMM_OUT         : STD_LOGIC_VECTOR(31 downto 00);
	signal	SHIFT_M_OUT     : STD_LOGIC_VECTOR(01 downto 00);
	signal	SHIFT_C_OUT     : STD_LOGIC_VECTOR(04 downto 00);
	signal	NEXT_DUAL_OP    : STD_LOGIC;
	signal	REG_SEL         : STD_LOGIC_VECTOR(14 downto 12); -- weird, huh!? ^^

begin

	-- ###############################################################################################
	-- ##       Internal Signal Connection                                                          ##
	-- ###############################################################################################

	INSTR_REG <= OPCODE_DATA_IN;
	DUAL_OP   <= OPCODE_CTRL_IN(0);
	
	OPCODE_CTRL_OUT(31 downto 00) <= DEC_CTRL;
	OPCODE_CTRL_OUT(43 downto 32) <= OP_ADR_OUT;
	OPCODE_CTRL_OUT(46 downto 44) <= REG_SEL;
	OPCODE_CTRL_OUT(78 downto 47) <= IMM_OUT;
	OPCODE_CTRL_OUT(80 downto 79) <= SHIFT_M_OUT;
	OPCODE_CTRL_OUT(85 downto 81) <= SHIFT_C_OUT;
	OPCODE_CTRL_OUT(86)           <= NEXT_DUAL_OP;
	OPCODE_CTRL_OUT(99 downto 87) <= (others => '0'); -- unused


	-- ###############################################################################################
	-- ##       ARM COMPATIBLE OPCODE DECODER                                                       ##
	-- ###############################################################################################

	OPCODE_DECODER: process (INSTR_REG, DUAL_OP)
		variable temp_3, temp_4, temp_5 : std_logic_vector(2 downto 0);
		variable B_TEMP_1, B_TEMP_2     : std_logic_vector(1 downto 0);
	begin

		--- DEFAULT CONTROL ---
		DEC_CTRL									<= (others => '0');
		DEC_CTRL(CTRL_RD_3    downto CTRL_RD_0)		<= INSTR_REG(15 downto 12); -- R_DEST
		DEC_CTRL(CTRL_COND_3  downto CTRL_COND_0)	<= INSTR_REG(31 downto 28); -- Condition
		
		OP_ADR_OUT(OP_A_ADR_3 downto OP_A_ADR_0)	<= INSTR_REG(19 downto 16);
		OP_ADR_OUT(OP_B_ADR_3 downto OP_B_ADR_0)	<= INSTR_REG(03 downto 00);
		OP_ADR_OUT(OP_C_ADR_3 downto OP_C_ADR_0)	<= INSTR_REG(11 downto 08);
		REG_SEL										<= (others => '0'); -- all operands are anything but registers
		IMM_OUT										<= (others => '0');
		SHIFT_C_OUT									<= (others => '0');
		SHIFT_M_OUT									<= (others => '0');
		NEXT_DUAL_OP								<= '0';

		--- INSTRUCTION CLASS DECODER ---
		case INSTR_REG(27 downto 26) is
		
			when "00" => -- ALU DATA PROCESSING / SREG ACCESS / MUL(MAC) / (S/U/HW/B) MEM ACCESS
			-- ===================================================================================
				if ((INSTR_REG(27 downto 22) = "000000") and (INSTR_REG(7 downto 4) = "1001")) then
				-- MUL/MAC
				----------------------------------------------------------------------------------
					DEC_CTRL(CTRL_AF)                        <= INSTR_REG(20); -- ALTER_FLAGS
					DEC_CTRL(CTRL_WB_EN)                     <= '1'; -- WB_ENABLE
					DEC_CTRL(CTRL_MS)                        <= '1'; -- select multiplicator
					DEC_CTRL(CTRL_RD_3    downto  CTRL_RD_0) <= INSTR_REG(19 downto 16);
					OP_ADR_OUT(OP_A_ADR_3 downto OP_A_ADR_0) <= INSTR_REG(15 downto 12);
					OP_ADR_OUT(OP_B_ADR_3 downto OP_B_ADR_0) <= INSTR_REG(11 downto 08);
					OP_ADR_OUT(OP_C_ADR_3 downto OP_C_ADR_0) <= INSTR_REG(03 downto 00);
					REG_SEL(OP_B_IS_REG)                     <= '1'; -- OP B is always reg
					REG_SEL(OP_C_IS_REG)                     <= '1'; -- OP C is always reg
					if (INSTR_REG(21) = '1') then -- perform MAC operation
						DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_ADD;
						REG_SEL(OP_A_IS_REG) <= '1';
					else -- perform MUL operation
						DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= PassB;
						REG_SEL(OP_A_IS_REG) <= '0';
					end if;

				elsif (INSTR_REG(27 downto 25) = "000") and (INSTR_REG(7) = '1') and (INSTR_REG(4) = '1') then
				-- Halfword / Signed Data Transfer / Data Swap
				----------------------------------------------------------------------------------
					DEC_CTRL(CTRL_RD_3    downto  CTRL_RD_0) <= INSTR_REG(15 downto 12); -- R_DATA
					OP_ADR_OUT(OP_A_ADR_3 downto OP_A_ADR_0) <= INSTR_REG(19 downto 16); -- BASE
					OP_ADR_OUT(OP_B_ADR_3 downto OP_B_ADR_0) <= INSTR_REG(03 downto 00); -- Offset
					OP_ADR_OUT(OP_C_ADR_3 downto OP_C_ADR_0) <= INSTR_REG(15 downto 12); -- W_DATA
					IMM_OUT                                  <= x"000000" & INSTR_REG(11 downto 08) & INSTR_REG(03 downto 00); -- IMMEDIATE
					DEC_CTRL(CTRL_CONST)                     <= INSTR_REG(22); -- IS_CONST
					DEC_CTRL(CTRL_MEM_SE)                    <= INSTR_REG(6);
					
					if (INSTR_REG(5) = '1') then
						DEC_CTRL(CTRL_MEM_DQ_1 downto CTRL_MEM_DQ_0) <= DQ_HALFWORD;
					else
						DEC_CTRL(CTRL_MEM_DQ_1 downto CTRL_MEM_DQ_0) <= DQ_BYTE;
					end if;

					if (INSTR_REG(23) = '0') then -- sub index
						DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_SUB; -- ALU_CTRL = SUB
					else -- add index
						DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_ADD; -- ALU_CTRL = ADD
					end if;

					temp_5 := INSTR_REG(20) & INSTR_REG(24) & INSTR_REG(21);
					case temp_5 is -- L_P_W

						when "110" => -- load, pre indexing, no write back
						----------------------------------------------------------------------------------
							DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)	<= INSTR_REG(15 downto 12); -- R_DEST
							DEC_CTRL(CTRL_MEM_ACC)					<= '1'; -- MEM_ACCESS
							DEC_CTRL(CTRL_MEM_RW)					<= '0'; -- MEM_READ
							DEC_CTRL(CTRL_WB_EN)					<= '1'; -- WB EN
							NEXT_DUAL_OP							<= '0';
							REG_SEL(OP_A_IS_REG)                    <= '1';
							REG_SEL(OP_B_IS_REG)                    <= not INSTR_REG(22);
							REG_SEL(OP_C_IS_REG)                    <= '0';

						when "111" => -- load, pre indexing, write back
						----------------------------------------------------------------------------------
							if (DUAL_OP = '0') then -- ADD/SUB Ra,Ra,Op_B
								DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)	<= INSTR_REG(19 downto 16); -- R_DEST
								DEC_CTRL(CTRL_MEM_ACC)					<= '0'; -- MEM_ACCESS
								DEC_CTRL(CTRL_WB_EN)					<= '1'; -- WB EN
								NEXT_DUAL_OP 							<= '1';
								REG_SEL(OP_A_IS_REG)                    <= '1';
								REG_SEL(OP_B_IS_REG)                    <= not INSTR_REG(22);
								REG_SEL(OP_C_IS_REG)                    <= '0';

							else -- LD Rd, Ra
								DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)			<= INSTR_REG(15 downto 12); -- R_DEST
								DEC_CTRL(CTRL_MEM_ACC)							<= '1'; -- MEM_ACCESS
								DEC_CTRL(CTRL_WB_EN)							<= '1'; -- WB EN
								NEXT_DUAL_OP									<= '0';
								DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0)	<= PassA; -- ALU_CTRL = PassA
								REG_SEL(OP_A_IS_REG)                    		<= '1';
								REG_SEL(OP_B_IS_REG)                   			<= '0';
								REG_SEL(OP_C_IS_REG)                    		<= '0';
							end if;


						when "100" | "101" => -- load, post indexing, allways write back
						----------------------------------------------------------------------------------
							if (DUAL_OP = '0') then -- LD Rd,Ra
								DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)			<= INSTR_REG(15 downto 12); -- R_DEST
								DEC_CTRL(CTRL_MEM_ACC)							<= '1'; -- MEM_ACCESS
								DEC_CTRL(CTRL_MEM_RW)							<= '0'; -- MEM_READ
								DEC_CTRL(CTRL_WB_EN)							<= '1'; -- WB EN
								DEC_CTRL(CTRL_MEM_USER)							<= INSTR_REG(21); -- access in pseudo-user-mode
								NEXT_DUAL_OP									<= '1';
								DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0)	<= PassA; -- ALU_CTRL = PassA
								REG_SEL(OP_A_IS_REG)                    		<= '1';
								REG_SEL(OP_B_IS_REG)                    		<= '0';
								REG_SEL(OP_C_IS_REG)                    		<= '0';

							else -- ADD/SUB Ra,Ra,Op_B
								DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)	<= INSTR_REG(19 downto 16); -- R_DEST
								DEC_CTRL(CTRL_MEM_ACC)					<= '0'; -- MEM_ACCESS
								DEC_CTRL(CTRL_WB_EN)					<= '1'; -- WB EN
								NEXT_DUAL_OP							<= '0';
								REG_SEL(OP_A_IS_REG)                    <= '1';
								REG_SEL(OP_B_IS_REG)                    <= not INSTR_REG(22);
								REG_SEL(OP_C_IS_REG)                    <= '0';
							end if;


						when "010" => -- store, pre indexing, no write back
						----------------------------------------------------------------------------------
							DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)	<= "0000"; -- R_DEST wayne
							DEC_CTRL(CTRL_MEM_ACC)					<= '1'; -- MEM_ACCESS
							DEC_CTRL(CTRL_MEM_RW)					<= '1'; -- MEM_WRITE
							DEC_CTRL(CTRL_WB_EN)					<= '0'; -- WB EN
							NEXT_DUAL_OP							<= '0';
							REG_SEL(OP_A_IS_REG)                    <= '1';
							REG_SEL(OP_B_IS_REG)                    <= not INSTR_REG(22);
							REG_SEL(OP_C_IS_REG)                    <= '1';


						when "011" => -- store, pre indexing, write back
						----------------------------------------------------------------------------------
							DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)	<= INSTR_REG(19 downto 16); -- R_DEST
							DEC_CTRL(CTRL_MEM_ACC)					<= '1'; -- MEM_ACCESS
							DEC_CTRL(CTRL_MEM_RW)					<= '1'; -- MEM_WRITE
							DEC_CTRL(CTRL_WB_EN)					<= '1'; -- WB EN
							NEXT_DUAL_OP							<= '0';
							REG_SEL(OP_A_IS_REG)                    <= '1';
							REG_SEL(OP_B_IS_REG)                    <= not INSTR_REG(22);
							REG_SEL(OP_C_IS_REG)                    <= '1';


						when others => -- store, post indexing, allways write back
						----------------------------------------------------------------------------------
							if (DUAL_OP = '0') then -- ST Ra, Rd
								DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)			<= INSTR_REG(15 downto 12); -- R_DEST
								DEC_CTRL(CTRL_MEM_ACC)							<= '1'; -- MEM_ACCESS
								DEC_CTRL(CTRL_MEM_RW)							<= '1'; -- MEM_WRITE
								DEC_CTRL(CTRL_WB_EN)							<= '0'; -- WB EN
								DEC_CTRL(CTRL_MEM_USER)							<= INSTR_REG(21); -- access in pseudo-user-mode
								NEXT_DUAL_OP									<= '1';
								DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) 	<= PassA; -- ALU_CTRL = PassA
								REG_SEL(OP_A_IS_REG)                    		<= '1';
								REG_SEL(OP_B_IS_REG)                    		<= '0';
								REG_SEL(OP_C_IS_REG)                    		<= '1';
									
							else -- ADD/SUB Ra,Ra,Op_B
								DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)	<= INSTR_REG(19 downto 16); -- R_DEST
								DEC_CTRL(CTRL_MEM_ACC)					<= '0'; -- MEM_ACCESS
								DEC_CTRL(CTRL_MEM_RW)					<= '0'; -- MEM_WRITE
								DEC_CTRL(CTRL_WB_EN)					<= '1'; -- WB EN
								NEXT_DUAL_OP							<= '0';
								REG_SEL(OP_A_IS_REG)                    <= '1';
								REG_SEL(OP_B_IS_REG)                    <= not INSTR_REG(22);
								REG_SEL(OP_C_IS_REG)                    <= '0';
							end if;

					end case;

				elsif (INSTR_REG(27 downto 23) = "00010") and (INSTR_REG(21 downto 20) = "00") and (INSTR_REG(11 downto 4) = "00001001") then
				-- Single Data Swap SWP
				----------------------------------------------------------------------------------
					OP_ADR_OUT(OP_A_ADR_3  downto OP_A_ADR_0)    <= INSTR_REG(19 downto 16); -- BASE
					OP_ADR_OUT(OP_C_ADR_3  downto OP_C_ADR_0)    <= INSTR_REG(03 downto 00); -- W_DATA
					DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= PassA; -- ALU_CTRL = PassA
					DEC_CTRL(CTRL_MEM_DQ_1 downto CTRL_MEM_DQ_0) <= '0' & INSTR_REG(22); -- DATA QUANTITY
					DEC_CTRL(CTRL_MEM_ACC)                       <= '1'; -- MEM_ACCESS
					REG_SEL(OP_A_IS_REG)                         <= '1';
					REG_SEL(OP_B_IS_REG)                         <= '0';
					if (DUAL_OP = '0') then
						NEXT_DUAL_OP          <= '1';
						DEC_CTRL(CTRL_MEM_RW) <= '0'; -- MEM_READ
						DEC_CTRL(CTRL_WB_EN)  <= '1'; -- WB EN
						REG_SEL(OP_C_IS_REG)  <= '0';
						DEC_CTRL(CTRL_WB_EN)  <= '1'; -- WB_ENABLE
					else
						NEXT_DUAL_OP          <= '0';
						DEC_CTRL(CTRL_MEM_RW) <= '1'; -- MEM_WRITE
						DEC_CTRL(CTRL_WB_EN)  <= '0'; -- WB EN
						REG_SEL(OP_C_IS_REG)  <= '1';
						DEC_CTRL(CTRL_WB_EN)  <= '0'; -- WB_ENABLE
					end if;


				else -- ALU operation / MCR access
				----------------------------------------------------------------------------------
					DEC_CTRL(CTRL_AF)      <= INSTR_REG(20); -- ALTER_FLAGS
					DEC_CTRL(CTRL_WB_EN)   <= '1';           -- WB_ENABLE
					DEC_CTRL(CTRL_CONST)   <= INSTR_REG(25); -- IS_CONST
					DEC_CTRL(CTRL_MREG_M)  <= INSTR_REG(22); -- CMSR/SMSR access
					DEC_CTRL(CTRL_MREG_RW) <= INSTR_REG(21); -- read/write access
					DEC_CTRL(CTRL_MREG_FA) <= not INSTR_REG(16); -- only flag access?

					B_TEMP_1 := INSTR_REG(25) & INSTR_REG(04);
					case B_TEMP_1 is
						when "10" | "11" => -- IS_CONST
							REG_SEL(OP_A_IS_REG)    <= '1';
							REG_SEL(OP_B_IS_REG)    <= '0';
							REG_SEL(OP_C_IS_REG)    <= '0';
							SHIFT_C_OUT				<= INSTR_REG(11 downto 08) & '0'; -- SHIFT_POS x2
							if (INSTR_REG(11 downto 08) = "0000") then
								SHIFT_M_OUT			<= S_LSL; -- SHIFT MODE = anything but ROR
							else
								SHIFT_M_OUT			<= S_ROR; -- SHIFT MODE = ROR
							end if;
							IMM_OUT					<= x"000000" & INSTR_REG(07 downto 00); -- IMMEDIATE
							DEC_CTRL(CTRL_SHIFTR)	<= '0'; -- SHIFT WITH IMMEDIATE
	
						when "00" => -- shift REG_B direct
							REG_SEL(OP_A_IS_REG)    <= '1';
							REG_SEL(OP_B_IS_REG)    <= '1';
							REG_SEL(OP_C_IS_REG)    <= '0';
							SHIFT_C_OUT				<= INSTR_REG(11 downto 07); -- SHIFT POS
							SHIFT_M_OUT				<= INSTR_REG(06 downto 05); -- SHIFT MODE
							IMM_OUT					<= (others => '0'); -- IMMEDIATE
							DEC_CTRL(CTRL_SHIFTR)	<= '0'; -- SHIFT WITH IMMEDIATE

						when others => -- shift REG_B with REG_C
							REG_SEL(OP_A_IS_REG)    <= '1';
							REG_SEL(OP_B_IS_REG)    <= '1';
							REG_SEL(OP_C_IS_REG)    <= '1';
							SHIFT_C_OUT				<= (others => '0'); -- SHIFT POS
							SHIFT_M_OUT				<= INSTR_REG(06 downto 05); -- SHIFT MODE
							IMM_OUT					<= (others => '0'); -- IMMEDIATE
							DEC_CTRL(CTRL_SHIFTR)	<= '1'; -- SHIFT_REG
					end case;

					case (INSTR_REG(24 downto 21)) is -- ALU FUNCTION SET
						when "0000" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= L_AND;
						when "0001" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= L_XOR;
						when "0010" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_SUB;
						when "0011" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_RSB;
						when "0100" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_ADD;
						when "0101" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_ADC;
						when "0110" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_SBC;
						when "0111" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_RSC;

						-- ALU-Operations / MCR Access --
						when "1000" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= L_TST; -- read SREG
											DEC_CTRL(CTRL_WB_EN)        <= '0'; -- disable register write back
											if (INSTR_REG(20) = '0') then -- ALTER FLAGS ?
												DEC_CTRL(CTRL_MREG_ACC)	<= '1'; -- access MREG
												DEC_CTRL(CTRL_WB_EN)    <= '1'; -- re-enable register write back
												REG_SEL(OP_A_IS_REG)    <= '0';
												REG_SEL(OP_B_IS_REG)    <= '0';
												REG_SEL(OP_C_IS_REG)    <= '0';
											end if;

						when "1001" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= L_TEQ; -- write SREG
											DEC_CTRL(CTRL_WB_EN)        <= '0'; -- disable register write back
											if (INSTR_REG(20) = '0') then -- ALTER FLAGS ?
												DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= PassB; -- write SREG
												DEC_CTRL(CTRL_MREG_ACC)	<= '1'; -- access MREG
												REG_SEL(OP_A_IS_REG)    <= '0';
												REG_SEL(OP_B_IS_REG)    <= '1';
												REG_SEL(OP_C_IS_REG)    <= '0';
											end if;

						when "1010" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_CMP; -- read SREG
											DEC_CTRL(CTRL_WB_EN)        <= '0'; -- disable register write back
											if (INSTR_REG(20) = '0') then -- ALTER FLAGS ?
												DEC_CTRL(CTRL_MREG_ACC)	<= '1'; -- access MREG
												DEC_CTRL(CTRL_WB_EN)    <= '1'; -- re-enable register write back
												REG_SEL(OP_A_IS_REG)    <= '0';
												REG_SEL(OP_B_IS_REG)    <= '0';
												REG_SEL(OP_C_IS_REG)    <= '0';
											end if;

						when "1011" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_CMN; -- write SREG
											DEC_CTRL(CTRL_WB_EN)        <= '0'; -- disable register write back
											if (INSTR_REG(20) = '0') then -- ALTER FLAGS ?
												DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= PassB; -- write SREG
												DEC_CTRL(CTRL_MREG_ACC)	<= '1'; -- access MREG
												REG_SEL(OP_A_IS_REG)    <= '0';
												REG_SEL(OP_B_IS_REG)    <= '1';
												REG_SEL(OP_C_IS_REG)    <= '0';
											end if;

						when "1100" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= L_OR;
						when "1101" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= L_MOV;
						when "1110" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= L_BIC;
						when "1111" => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= L_NOT;
						when others => DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= (others => '0');
					end case;

				end if;
			


			when "01" => -- UNDEFINED INSTRUCTION INTERRUPT / SINGLE MEMORY ACCESS
			-- ============================================================================================
				if (INSTR_REG(25) = '1') and (INSTR_REG(4) = '1') then -- UDI
				----------------------------------------------------------------------------------
					DEC_CTRL(CTRL_UND) <= '1'; --undefined instruction

				else -- Single Data Transfer
				----------------------------------------------------------------------------------

					OP_ADR_OUT(OP_A_ADR_3 downto OP_A_ADR_0)		<= INSTR_REG(19 downto 16); -- BASE
					OP_ADR_OUT(OP_B_ADR_3 downto OP_B_ADR_0)		<= INSTR_REG(03 downto 00); -- OFFSET
					OP_ADR_OUT(OP_C_ADR_3 downto OP_C_ADR_0)		<= INSTR_REG(15 downto 12); -- DATA
					NEXT_DUAL_OP									<= '0';
					DEC_CTRL(CTRL_CONST)							<= not INSTR_REG(25); -- IS_CONST
					if (INSTR_REG(22) = '0') then -- W/B quantity
						DEC_CTRL(CTRL_MEM_DQ_1 downto CTRL_MEM_DQ_0) <= DQ_WORD;
					else
						DEC_CTRL(CTRL_MEM_DQ_1 downto CTRL_MEM_DQ_0) <= DQ_BYTE;
					end if;

					B_TEMP_2 := INSTR_REG(25) & INSTR_REG(04);
					case B_TEMP_2 is
						when "00" | "01" => -- IS_CONST
							SHIFT_C_OUT				<= (others => '0'); -- SHIFT POS
							SHIFT_M_OUT				<= S_LSL; -- SHIFT MODE = wayne
							IMM_OUT(31 downto 00)	<= x"00000" & INSTR_REG(11 downto 00); -- unsigned IMMEDIATE
							DEC_CTRL(CTRL_SHIFTR)	<= '0'; -- SHIFT_REG

						when "10" => -- shift REG_B direct
							SHIFT_C_OUT				<= INSTR_REG(11 downto 07); -- SHIFT POS
							SHIFT_M_OUT				<= INSTR_REG(06 downto 05); -- SHIFT MODE
							IMM_OUT(31 downto 00)	<= (others => '0'); -- IMMEDIATE
							DEC_CTRL(CTRL_SHIFTR)	<= '0'; -- SHIFT_REG

						when others => -- shift REG_B with REG_C
							SHIFT_C_OUT				<= (others => '0'); -- SHIFT POS
							SHIFT_M_OUT				<= INSTR_REG(06 downto 05); -- SHIFT MODE
							IMM_OUT(31 downto 00)	<= (others => '0'); -- IMMEDIATE
							DEC_CTRL(CTRL_SHIFTR)	<= '1'; -- SHIFT_REG
					end case;

					if (INSTR_REG(23) = '0') then -- sub index
						DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_SUB; -- ALU_CTRL = SUB
					else -- add index
						DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) <= A_ADD; -- ALU_CTRL = ADD
					end if;

					temp_3 := INSTR_REG(20) & INSTR_REG(24) & INSTR_REG(21);
					case temp_3 is -- L_P_W

						when "110" => -- load, pre indexing, no write back
						----------------------------------------------------------------------------------
							DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)		<= INSTR_REG(15 downto 12); -- R_DEST
							DEC_CTRL(CTRL_MEM_ACC)						<= '1'; -- MEM_ACCESS
							DEC_CTRL(CTRL_MEM_RW)						<= '0'; -- MEM_READ
							DEC_CTRL(CTRL_WB_EN)						<= '1'; -- WB EN
							NEXT_DUAL_OP								<= '0';
							REG_SEL(OP_A_IS_REG)    					<= '1';
							REG_SEL(OP_B_IS_REG)   						<= INSTR_REG(25);
							REG_SEL(OP_C_IS_REG)    					<= '0';


						when "111" => -- load, pre indexing, write back
						----------------------------------------------------------------------------------
							if (DUAL_OP = '0') then -- ADD/SUB Ra,Ra,Op_B
								DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)	<= INSTR_REG(19 downto 16); -- R_DEST
								DEC_CTRL(CTRL_MEM_ACC)					<= '0'; -- MEM_ACCESS
								DEC_CTRL(CTRL_WB_EN)					<= '1'; -- WB EN
								NEXT_DUAL_OP 							<= '1';
								REG_SEL(OP_A_IS_REG)    				<= '1';
								REG_SEL(OP_B_IS_REG)   					<= INSTR_REG(25);
								REG_SEL(OP_C_IS_REG)    				<= '0';

							else -- LD Rd, Ra
								DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)			<= INSTR_REG(15 downto 12); -- R_DEST
								DEC_CTRL(CTRL_MEM_ACC)							<= '1'; -- MEM_ACCESS
								DEC_CTRL(CTRL_WB_EN)							<= '1'; -- WB EN
								NEXT_DUAL_OP									<= '0';
								DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0)	<= PassA; -- ALU_CTRL = PassA
								REG_SEL(OP_A_IS_REG)    						<= '1';
								REG_SEL(OP_B_IS_REG)   							<= '0';
								REG_SEL(OP_C_IS_REG)    						<= '0';
							end if;


						when "100" | "101" => -- load, post indexing, allways write back
						----------------------------------------------------------------------------------
							if (DUAL_OP = '0') then -- LD Rd,Ra
								DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)			<= INSTR_REG(15 downto 12); -- R_DEST
								DEC_CTRL(CTRL_MEM_ACC)							<= '1'; -- MEM_ACCESS
								DEC_CTRL(CTRL_MEM_RW)							<= '0'; -- MEM_READ
								DEC_CTRL(CTRL_WB_EN)							<= '1'; -- WB EN
								DEC_CTRL(CTRL_MEM_USER)							<= INSTR_REG(21); -- access in pseudo-user-mode
								NEXT_DUAL_OP									<= '1';
								DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0)	<= PassA; -- ALU_CTRL = PassA
								REG_SEL(OP_A_IS_REG)    						<= '1';
								REG_SEL(OP_B_IS_REG)   							<= '0';
								REG_SEL(OP_C_IS_REG)    						<= '0';

							else -- ADD/SUB Ra,Ra,Op_B
								DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)	<= INSTR_REG(19 downto 16); -- R_DEST
								DEC_CTRL(CTRL_MEM_ACC)					<= '0'; -- MEM_ACCESS
								DEC_CTRL(CTRL_WB_EN)					<= '1'; -- WB EN
								NEXT_DUAL_OP							<= '0';
								REG_SEL(OP_A_IS_REG)    				<= '1';
								REG_SEL(OP_B_IS_REG)   					<= INSTR_REG(25);
								REG_SEL(OP_C_IS_REG)    				<= '0';
							end if;


						when "010" => -- store, pre indexing, no write back
						----------------------------------------------------------------------------------
							DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)	<= "0000"; -- R_DEST
							DEC_CTRL(CTRL_MEM_ACC)					<= '1'; -- MEM_ACCESS
							DEC_CTRL(CTRL_MEM_RW)					<= '1'; -- MEM_WRITE
							DEC_CTRL(CTRL_WB_EN)					<= '0'; -- WB EN
							NEXT_DUAL_OP							<= '0';
							REG_SEL(OP_A_IS_REG)    				<= '1';
							REG_SEL(OP_B_IS_REG)   					<= INSTR_REG(25);
							REG_SEL(OP_C_IS_REG)    				<= '1';


						when "011" => -- store, pre indexing, write back
						----------------------------------------------------------------------------------
							DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)	<= INSTR_REG(19 downto 16); -- R_DEST
							DEC_CTRL(CTRL_MEM_ACC)					<= '1'; -- MEM_ACCESS
							DEC_CTRL(CTRL_MEM_RW)					<= '1'; -- MEM_WRITE
							DEC_CTRL(CTRL_WB_EN)					<= '1'; -- WB EN
							NEXT_DUAL_OP							<= '0';
							REG_SEL(OP_A_IS_REG)    				<= '1';
							REG_SEL(OP_B_IS_REG)   					<= INSTR_REG(25);
							REG_SEL(OP_C_IS_REG)    				<= '1';


						when others => -- store, post indexing, allways write back
						----------------------------------------------------------------------------------
							if (DUAL_OP = '0') then -- ST Ra, Rd
								DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)			<= INSTR_REG(15 downto 12); -- R_DEST
								DEC_CTRL(CTRL_MEM_ACC)							<= '1'; -- MEM_ACCESS
								DEC_CTRL(CTRL_MEM_RW)							<= '1'; -- MEM_WRITE
								DEC_CTRL(CTRL_WB_EN)							<= '0'; -- WB EN
								DEC_CTRL(CTRL_MEM_USER)							<= INSTR_REG(21); -- access in pseudo-user-mode
								NEXT_DUAL_OP									<= '1';
								DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0) 	<= PassA; -- ALU_CTRL = PassA
								REG_SEL(OP_A_IS_REG)    						<= '1';
								REG_SEL(OP_B_IS_REG)   							<= '0';
								REG_SEL(OP_C_IS_REG)    						<= '1';
									
							else -- ADD/SUB Ra,Ra,Op_B
								DEC_CTRL(CTRL_RD_3 downto CTRL_RD_0)	<= INSTR_REG(19 downto 16); -- R_DEST
								DEC_CTRL(CTRL_MEM_ACC)					<= '0'; -- MEM_ACCESS
								DEC_CTRL(CTRL_MEM_RW)					<= '0'; -- MEM_WRITE
								DEC_CTRL(CTRL_WB_EN)					<= '1'; -- WB EN
								NEXT_DUAL_OP							<= '0';
								REG_SEL(OP_A_IS_REG)    				<= '1';
								REG_SEL(OP_B_IS_REG)   					<= INSTR_REG(25);
								REG_SEL(OP_C_IS_REG)    				<= '0';
							end if;

					end case;
				end if;

			
			when "10" => -- BRANCH OPERATIONS / BLOCK DATA TRANSFER
			-- ============================================================================================
				if (INSTR_REG(25) = '1') then -- Branch (and Link)
				----------------------------------------------------------------------------------
					DEC_CTRL(CTRL_LINK)   <= INSTR_REG(24); -- LINK
					DEC_CTRL(CTRL_WB_EN)  <= INSTR_REG(24); -- WB_EN
					DEC_CTRL(CTRL_CONST)  <= '1'; -- IS_CONST
					DEC_CTRL(CTRL_BRANCH) <= '1'; -- BRANCH_INSTR
					SHIFT_C_OUT           <= "00010"; -- SHIFT POS = 2 => x4
					SHIFT_M_OUT           <= S_LSL; -- SHIFT MODE
					DEC_CTRL(CTRL_ALU_FS_3 downto CTRL_ALU_FS_0)	<= A_ADD; -- ALU.ADD
					IMM_OUT(23 downto 0)  <= INSTR_REG(23 downto 0);
					for i in 24 to 31 loop
						IMM_OUT(i) <= INSTR_REG(23); -- IMMEDIATE sign extension
					end loop;
					
				else -- Block Data Transfer
				----------------------------------------------------------------------------------
					DEC_CTRL(CTRL_UND) <= '1'; -- undefined instruction, since block data transfers are not implemented

				end if;



			when others => -- COPROCESSOR INTERFACE / SOFTWARE INTERRUPT
			-- ============================================================================================
				if (INSTR_REG(25 downto 24) = "11") then -- SOFTWARE INTERRUPT
				----------------------------------------------------------------------------------
					DEC_CTRL(CTRL_SWI) <= '1'; -- 24-bit tag is ignored by processor

				else -- COPROCESSOR OPERATION
				----------------------------------------------------------------------------------
					DEC_CTRL(CTRL_UND) <= '1'; -- undefined instruction, since coprocessor operations are not implemented

				end if;

		end case;

	end process OPCODE_DECODER;


end instruction_decoder;