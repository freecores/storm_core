-- ######################################################
-- #      < STORM CORE SYSTEM by Stephan Nolting >      #
-- # ************************************************** #
-- #              Resource Access Arbiter               #
-- # -------------------------------------------------- #
-- #  This access arbiter can coordinate the resource   #
-- #  requests of two clients for two resources.        #
-- #  If a resource does not acknowledge the acces,     #
-- #  an interrupt to the corresponding client will be  #
-- #  transmitted.                                      #
-- #  If you want to disable resource 1, set the        #
-- #  switch address to 0x00000000.                     #
-- # ************************************************** #
-- # Version 1.1.0, 30.08.2011                          #
-- ######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity ACCESS_ARBITER is
	generic (
				  SWITCH_ADR       : natural; -- address border resource1/resource2
				  RE1_TO_CNT       : natural; -- resource 1 time out value
				  RE2_TO_CNT       : natural; -- resource 2 time out value
				  CL1_INT_EN       : boolean; -- allow interrupts for client 1
				  CL2_INT_EN       : boolean  -- allow interrupts for client 2
            );
	port    (
-- ###############################################################################################
-- ##       Global Control                                                                      ##
-- ###############################################################################################

				CLK_I              : in  STD_LOGIC; -- clock signal, rising edge
				RST_I              : in  STD_LOGIC; -- reset signal, sync, active high
				HALT_CLIENTS_O     : out STD_LOGIC; -- halt both clients

-- ###############################################################################################
-- ##       Client Port 1                                                                       ##
-- ###############################################################################################

				CL1_ACC_REQ_I      : in  STD_LOGIC; -- access request
				CL1_ADR_I          : in  STD_LOGIC_VECTOR(31 downto 00); -- address input
				CL1_WR_DATA_I      : in  STD_LOGIC_VECTOR(31 downto 00); -- write data
				CL1_RD_DATA_O      : out STD_LOGIC_VECTOR(31 downto 00); -- read data
				CL1_DQ_I           : in  STD_LOGIC_VECTOR(01 downto 00); -- data quantity
				CL1_RW_I           : in  STD_LOGIC; -- read/write select
				CL1_TAG_I          : in  STD_LOGIC_VECTOR(04 downto 00); -- tag input, here: mode
				CL1_ABORT_O        : out STD_LOGIC; -- access abort error

-- ###############################################################################################
-- ##       Client Port 2                                                                       ##
-- ###############################################################################################

				CL2_ACC_REQ_I      : in  STD_LOGIC; -- access request
				CL2_ADR_I          : in  STD_LOGIC_VECTOR(31 downto 00); -- address input
				CL2_WR_DATA_I      : in  STD_LOGIC_VECTOR(31 downto 00); -- write data
				CL2_RD_DATA_O      : out STD_LOGIC_VECTOR(31 downto 00); -- read data
				CL2_DQ_I           : in  STD_LOGIC_VECTOR(01 downto 00); -- data quantity
				CL2_RW_I           : in  STD_LOGIC; -- read/write select
				CL2_TAG_I          : in  STD_LOGIC_VECTOR(04 downto 00); -- tag input, here: mode
				CL2_ABORT_O        : out STD_LOGIC; -- access abort error

-- ###############################################################################################
-- ##       Resource Port 1                                                                     ##
-- ###############################################################################################

				RE1_ADR_O          : out STD_LOGIC_VECTOR(31 downto 00); -- address
				RE1_WR_DATA_O      : out STD_LOGIC_VECTOR(31 downto 00); -- write data
				RE1_RD_DATA_I      : in  STD_LOGIC_VECTOR(31 downto 00); -- read data
				RE1_BYTE_SEL_O     : out STD_LOGIC_VECTOR(03 downto 00); -- byte select
				RE1_RW_O           : out STD_LOGIC; -- read/write
				RE1_CS_O           : out STD_LOGIC; -- chip select
				RE1_DONE_I         : in  STD_LOGIC; -- transfer done

-- ###############################################################################################
-- ##       Resource Port 2                                                                     ##
-- ###############################################################################################

				RE2_ADR_O          : out STD_LOGIC_VECTOR(31 downto 00); -- address
				RE2_WR_DATA_O      : out STD_LOGIC_VECTOR(31 downto 00); -- write data
				RE2_RD_DATA_I      : in  STD_LOGIC_VECTOR(31 downto 00); -- read data
				RE2_BYTE_SEL_O     : out STD_LOGIC_VECTOR(03 downto 00); -- byte select
				RE2_RW_O           : out STD_LOGIC; -- read/write
				RE2_CS_O           : out STD_LOGIC; -- chip select
				RE2_DONE_I         : in  STD_LOGIC  -- transfer done

            );
end ACCESS_ARBITER;

architecture Structure of ACCESS_ARBITER is

	-- local signals --
	signal CL1_BYTE_SEL, CL2_BYTE_SEL       : STD_LOGIC_VECTOR(03 downto 0);
	signal CL1_O_INT, CL2_O_INT             : STD_LOGIC_VECTOR(31 downto 0);
	signal CL1_RE1_REQ, CL1_RE2_REQ         : STD_LOGIC;
	signal CL2_RE1_REQ, CL2_RE2_REQ         : STD_LOGIC;
	signal CL1_RE1_REQ_FF, CL1_RE2_REQ_FF   : STD_LOGIC;
	signal CL2_RE1_REQ_FF, CL2_RE2_REQ_FF   : STD_LOGIC;
	signal RE_NOT_RDY                       : STD_LOGIC;
	signal COLLISION, COLL_FLAG             : STD_LOGIC;
	signal RE_ACC_SWITCH, RE_ACC_SWITCH_NXT : STD_LOGIC;
	signal CL_RB_SEL, CL_RB_SEL_NXT         : STD_LOGIC;
	signal CL1_DELAY_EN, CL1_DELAY_EN_NXT   : STD_LOGIC;
	signal CL2_DELAY_EN, CL2_DELAY_EN_NXT   : STD_LOGIC;
	signal SAH_EN, SAH_EN_NXT               : STD_LOGIC;

	-- Debug --
	signal buff1, buff2 : STD_LOGIC_VECTOR(31 downto 0);
	signal sbuff1, sbuff2 : STD_LOGIC_VECTOR(31 downto 0);

begin

	-- Data Quantity Decoder ------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		CLIENT1_DQ_DECODER: process(CL1_DQ_I, CL1_ADR_I(1 downto 0))
			variable TEMP : STD_LOGIC_VECTOR(03 downto 00);
		begin
			TEMP := CL1_DQ_I & CL1_ADR_I(1 downto 0);
			case (TEMP) is
				when "0000" | "0001" | "0010" | "0011" => -- WORD with any offset
					CL1_BYTE_SEL <= "1111";
				when "0100" => -- BYTE with no offset
					CL1_BYTE_SEL <= "0001";
				when "0101" => -- BYTE with one byte offset
					CL1_BYTE_SEL <= "0010";
				when "0110" => -- BYTE with two bytes offset
					CL1_BYTE_SEL <= "0100";
				when "0111" => -- BYTE with three bytes offset
					CL1_BYTE_SEL <= "1000";
				when "1000" | "1100" => -- HALFWORD with no offset
					CL1_BYTE_SEL <= "0011";
				when "1001" | "1101" => -- HALFWORD with one byte offset
					CL1_BYTE_SEL <= "0110";
				when "1010" | "1110" => -- HALFWORD with two bytes offset
					CL1_BYTE_SEL <= "1100";
				when others          => -- HALFWORD with three bytes offset
					CL1_BYTE_SEL <= "1001";
			end case;			
		end process CLIENT1_DQ_DECODER;


		CLIENT2_DQ_DECODER: process(CL2_DQ_I, CL2_ADR_I(1 downto 0))
			variable TEMP : STD_LOGIC_VECTOR(03 downto 00);
		begin
			TEMP := CL2_DQ_I & CL2_ADR_I(1 downto 0);
			case (TEMP) is
				when "0000" | "0001" | "0010" | "0011" => -- WORD with any offset
					CL2_BYTE_SEL <= "1111";
				when "0100" => -- BYTE with no offset
					CL2_BYTE_SEL <= "0001";
				when "0101" => -- BYTE with one byte offset
					CL2_BYTE_SEL <= "0010";
				when "0110" => -- BYTE with two bytes offset
					CL2_BYTE_SEL <= "0100";
				when "0111" => -- BYTE with three bytes offset
					CL2_BYTE_SEL <= "1000";
				when "1000" | "1100" => -- HALFWORD with no offset
					CL2_BYTE_SEL <= "0011";
				when "1001" | "1101" => -- HALFWORD with one byte offset
					CL2_BYTE_SEL <= "0110";
				when "1010" | "1110" => -- HALFWORD with two bytes offset
					CL2_BYTE_SEL <= "1100";
				when others          => -- HALFWORD with three bytes offset
					CL2_BYTE_SEL <= "1001";
			end case;			
		end process CLIENT2_DQ_DECODER;



	-- Access Identification ------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		ACCESS_ID: process(CL1_ADR_I, CL2_ADR_I, CL1_ACC_REQ_I, CL2_ACC_REQ_I)
		begin
			--- Client 1 Access ---
			if (to_integer(unsigned(CL1_ADR_I)) < SWITCH_ADR) then
				CL1_RE1_REQ <= CL1_ACC_REQ_I;
				CL1_RE2_REQ <= '0';
			else
				CL1_RE1_REQ <= '0';
				CL1_RE2_REQ <= CL1_ACC_REQ_I;
			end if;

			--- Client 2 Access ---
			if (to_integer(unsigned(CL2_ADR_I)) < SWITCH_ADR) then
				CL2_RE1_REQ <= CL2_ACC_REQ_I;
				CL2_RE2_REQ <= '0';
			else
				CL2_RE1_REQ <= '0';
				CL2_RE2_REQ <= CL2_ACC_REQ_I;
			end if;
		end process ACCESS_ID;

		--- Collision Detector ---
		COLLISION <= (CL1_RE1_REQ and CL2_RE1_REQ) or (CL1_RE2_REQ and CL2_RE2_REQ);



	-- Collion HIStory Flag -------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		COLL_FLAG_SYNC: process(CLK_I, RST_I, COLLISION)
			variable F_INT : STD_LOGIC;
		begin
			if rising_edge(CLK_I) then
				if (RST_I = '1') then
					F_INT := '0';
				else
					F_INT := COLLISION and (not F_INT);
				end if;
			end if;
			--- Collision HIStory Flag ---
			COLL_FLAG      <= F_INT;
		end process COLL_FLAG_SYNC;

		--- Sample & Hold enable ---
		SAH_EN_NXT <= (CL1_DELAY_EN or CL2_DELAY_EN) and (not COLL_FLAG) and (not SAH_EN) and COLLISION;

		--- Freeze Clients ---
		HALT_CLIENTS_O <= COLLISION and (not COLL_FLAG);



	-- Access Arbiter -------------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		lcars_de_command: process(COLLISION, COLL_FLAG, CL1_RE2_REQ, CL2_RE1_REQ)
			variable TEMP : STD_LOGIC_VECTOR(1 downto 0);
		begin
			TEMP := COLLISION & COLL_FLAG;
			case TEMP is
			
				when "00" =>
					RE_ACC_SWITCH <= CL1_RE2_REQ or CL2_RE1_REQ; -- 0: CL1 -> RE1, CL2 -> RE2

				when "10" =>
					RE_ACC_SWITCH <= CL1_RE2_REQ or CL2_RE1_REQ; -- 0: CL1 -> RE1, CL2 -> RE2

				when "11" =>
					RE_ACC_SWITCH <= not (CL1_RE2_REQ or CL2_RE1_REQ); -- 0: CL1 -> RE1, CL2 -> RE2

				when others =>
					RE_ACC_SWITCH <= CL1_RE2_REQ or CL2_RE1_REQ; -- 0: CL1 -> RE1, CL2 -> RE2
			
			end case;
		end process lcars_de_command;
	
	
		CL1_DELAY_EN_NXT <= '0';--COLLISION and (CL1_RE1_REQ_FF or CL1_RE2_REQ_FF);
		CL2_DELAY_EN_NXT <= COLLISION and (CL2_RE1_REQ_FF or CL2_RE2_REQ_FF);
	
	
		CTRL_UNIT: process(CLK_I, RST_I)
		begin
			--- Buffer FF's ---
			if rising_edge(CLK_I) then
				if (RST_I = '1') then
					CL1_RE1_REQ_FF <= '0';
					CL1_RE2_REQ_FF <= '0';
					CL2_RE1_REQ_FF <= '0';
					CL2_RE2_REQ_FF <= '0';
					CL_RB_SEL      <= '0';
					CL1_DELAY_EN   <= '0';
					CL2_DELAY_EN   <= '0';
					SAH_EN         <= '0';
				else
					CL_RB_SEL      <= RE_ACC_SWITCH;
					CL1_DELAY_EN   <= CL1_DELAY_EN_NXT;
					CL2_DELAY_EN   <= CL2_DELAY_EN_NXT;
					SAH_EN         <= SAH_EN_NXT;
					if ((COLLISION and (not COLL_FLAG)) = '0') then
						CL1_RE1_REQ_FF <= CL1_RE1_REQ;
						CL1_RE2_REQ_FF <= CL1_RE2_REQ;
						CL2_RE1_REQ_FF <= CL2_RE1_REQ;
						CL2_RE2_REQ_FF <= CL2_RE2_REQ;
					end if;
				end if;
			end if;
		end process CTRL_UNIT;



	-- Access Control Output Switch -----------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		RE1_ADR_O      <= CL1_ADR_I     when (RE_ACC_SWITCH = '0') else CL2_ADR_I;
		RE1_WR_DATA_O  <= CL1_WR_DATA_I when (RE_ACC_SWITCH = '0') else CL2_WR_DATA_I;
		RE1_BYTE_SEL_O <= CL1_BYTE_SEL  when (RE_ACC_SWITCH = '0') else CL2_BYTE_SEL;
		RE1_RW_O       <= CL1_RW_I      when (RE_ACC_SWITCH = '0') else CL2_RW_I;
		RE1_CS_O       <= CL1_RE1_REQ or CL2_RE1_REQ;

		RE2_ADR_O      <= CL1_ADR_I     when (RE_ACC_SWITCH = '1') else CL2_ADR_I;
		RE2_WR_DATA_O  <= CL1_WR_DATA_I when (RE_ACC_SWITCH = '1') else CL2_WR_DATA_I;
		RE2_BYTE_SEL_O <= CL1_BYTE_SEL  when (RE_ACC_SWITCH = '1') else CL2_BYTE_SEL;
		RE2_RW_O       <= CL1_RW_I      when (RE_ACC_SWITCH = '1') else CL2_RW_I;
		RE2_CS_O       <= CL1_RE2_REQ or CL2_RE2_REQ;



	-- Read-Back Control ----------------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		RB_CTRL: process(CLK_I, RST_I, CL_RB_SEL, CL1_DELAY_EN, SAH_EN, RE1_RD_DATA_I, RE2_RD_DATA_I, CL2_DELAY_EN)
			variable CL1_INT, CL2_INT       : STD_LOGIC_VECTOR(31 downto 0);
			variable CL1_BUFFER, CL2_BUFFER : STD_LOGIC_VECTOR(31 downto 0);
		begin
			--- Client RB select ---
			if (CL_RB_SEL = '0') then
				CL1_INT := RE1_RD_DATA_I;
				CL2_INT := RE2_RD_DATA_I;
			else
				CL1_INT := RE2_RD_DATA_I;
				CL2_INT := RE1_RD_DATA_I;
			end if;

			--- Client 1 buffer ---
			if rising_edge(CLK_I) then
				if (RST_I = '1') then
					CL1_BUFFER := (others => '0');
					CL2_BUFFER := (others => '0');
				else
					CL1_BUFFER := CL1_INT;
					CL2_BUFFER := CL2_INT;
				end if;
			end if;
			buff1 <= CL1_BUFFER;
			buff2 <= CL2_BUFFER;
			if (CL1_DELAY_EN = '1') then
				CL1_O_INT <= CL1_BUFFER;
			else
				CL1_O_INT <= CL1_INT;
			end if;
			if (CL2_DELAY_EN = '1') then
				CL2_O_INT <= CL2_BUFFER;
			else
				CL2_O_INT <= CL2_INT;
			end if;
		end process RB_CTRL;
		
		
		SAMPLE_AND_HOLD: process(CLK_I, RST_I, CL1_O_INT, CL2_O_INT, SAH_EN)
			variable CL1_SAH, CL2_SAH : STD_LOGIC_VECTOR(31 downto 0);
		begin			
			--- Sample & Hold ---
			if rising_edge(CLK_I) then
				if (RST_I = '1') then
					CL1_SAH := (others => '0');
					CL2_SAH := (others => '0');
				else
					CL1_SAH := CL1_O_INT;
					CL2_SAH := CL2_O_INT;
				end if;
			end if;
			sbuff1 <= CL1_SAH;
			sbuff2 <= CL2_SAH;
			if (MEM_RB_SYNC_FF_EN = FALSE) then
				if (SAH_EN = '1') then
					CL1_RD_DATA_O <= CL1_SAH;
					CL2_RD_DATA_O <= CL2_SAH;
				else
					CL1_RD_DATA_O <= CL1_O_INT;
					CL2_RD_DATA_O <= CL2_O_INT;
				end if;
			else
				if falling_edge(CLK_I) then
					if (SAH_EN = '1') then
						CL1_RD_DATA_O <= CL1_SAH;
						CL2_RD_DATA_O <= CL2_SAH;
					else
						CL1_RD_DATA_O <= CL1_O_INT;
						CL2_RD_DATA_O <= CL2_O_INT;
					end if;
				end if;
			end if;
		end process SAMPLE_AND_HOLD;



	-- Resource Timeout Counter ---------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		TIMEOUT_CNT: process(CLK_I, RST_I, RE1_DONE_I, CL1_RE1_REQ, CL2_RE1_REQ, RE2_DONE_I, CL1_RE2_REQ, CL2_RE2_REQ)
			variable CNT_RE1 : integer range 0 to RE1_TO_CNT;
			variable CL1_RE1, CL2_RE1 : std_logic;
			variable CNT_RE2 : integer range 0 to RE2_TO_CNT;
			variable CL1_RE2, CL2_RE2 : std_logic;
		begin
			--- Timeout Resource 1 Counter ---
			if rising_edge(CLK_I) then
				if (RST_I = '1') or (RE1_DONE_I = '1') then
					CNT_RE1 :=  0;
					CL1_RE1 := '0';
					CL2_RE1 := '0';
				elsif (CL1_RE1_REQ = '1') or (CL2_RE1_REQ = '1') then
					CNT_RE1 := RE1_TO_CNT;
					CL1_RE1 := CL1_RE1_REQ;
					CL2_RE1 := CL2_RE1_REQ;
				elsif (CNT_RE1 /= 0) then
					CNT_RE1 := CNT_RE1 - 1;
					CL1_RE1 := CL1_RE1;
					CL2_RE1 := CL2_RE1;
				end if;
			end if;

			--- Timeout Resource 2 Counter ---
			if rising_edge(CLK_I) then
				if (RST_I = '1') or (RE2_DONE_I = '1') then
					CNT_RE2 :=  0;
					CL1_RE2 := '0';
					CL2_RE2 := '0';
				elsif (CL1_RE2_REQ = '1') or (CL2_RE2_REQ = '1') then
					CNT_RE2 := RE2_TO_CNT;
					CL1_RE2 := CL1_RE2_REQ;
					CL2_RE2 := CL2_RE2_REQ;
				elsif (CNT_RE2 /= 0) then
					CNT_RE2 := CNT_RE2 - 1;
					CL1_RE2 := CL1_RE2;
					CL2_RE2 := CL2_RE2;
				end if;
			end if;

			--- Interrupt for client 1 when time out ---
			if (CNT_RE2 = 1) and (CL1_INT_EN = TRUE) then
				CL1_ABORT_O <= CL1_RE1 or CL1_RE2;
			else
				CL1_ABORT_O <= '0';
			end if;

			--- Interrupt for client 2 when time out ---
			if (CNT_RE2 = 1) and (CL2_INT_EN = TRUE) then
				CL2_ABORT_O <= CL2_RE1 or CL2_RE2;
			else
				CL2_ABORT_O <= '0';
			end if;

		end process TIMEOUT_CNT;
		
		-- resource not ready signal --
		RE_NOT_RDY <= not (RE1_DONE_I and RE2_DONE_I);



end Structure;