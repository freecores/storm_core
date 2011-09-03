-- ######################################################
-- #      < STORM CORE SYSTEM by Stephan Nolting >      #
-- # ************************************************** #
-- #              Wihbone Interface Unit                #
-- # -------------------------------------------------- #
-- #                                                    #
-- # ************************************************** #
-- # Version 1.0.0, 19.07.2011                          #
-- ######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity WISHBONE_IO is
	port    (
-- ###############################################################################################
-- ##       Global Control                                                                      ##
-- ###############################################################################################

				CLK_I              : in  STD_LOGIC; -- clock signal, rising edge
				RST_I              : in  STD_LOGIC; -- reset signal, sync, active high

-- ###############################################################################################
-- ##       Access Port                                                                         ##
-- ###############################################################################################

				AP_ADR_I           : in  STD_LOGIC_VECTOR(31 downto 00); -- address
				AP_WR_DATA_I       : in  STD_LOGIC_VECTOR(31 downto 00); -- write data
				AP_RD_DATA_O       : out STD_LOGIC_VECTOR(31 downto 00); -- read data
				AP_BYTE_SEL_I      : in  STD_LOGIC_VECTOR(03 downto 00); -- byte select
				AP_RW_I            : in  STD_LOGIC; -- read/write
				AP_CS_I            : in  STD_LOGIC; -- chip select
				AP_DONE_O          : out STD_LOGIC; -- device is busy

-- ###############################################################################################
-- ##       Wishbone Port                                                                       ##
-- ###############################################################################################

				WB_DATA_I          : in  STD_LOGIC_VECTOR(31 downto 0);
				WB_DATA_O          : out STD_LOGIC_VECTOR(31 downto 0);
				WB_ADR_O           : out STD_LOGIC_VECTOR(31 downto 0);
				WB_ACK_I           : in  STD_LOGIC;
				WB_SEL_O           : out STD_LOGIC_VECTOR(03 downto 0);
				WB_WE_O            : out STD_LOGIC;
				WB_STB_O           : out STD_LOGIC;
				WB_CYC_O           : out STD_LOGIC

            );
end WISHBONE_IO;

architecture Structure of WISHBONE_IO is

	-- use data isolation when not using WB --
	constant use_isolation : boolean := FALSE;

	-- ready flag --
	signal RDY_FLAG : STD_LOGIC;

begin

	-- WISHBONE Interface Arbiter -------------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		WB_ARBITER: process (CLK_I, RST_I, AP_CS_I, WB_ACK_I, WB_DATA_I)
		begin
			if rising_edge(CLK_I) then
				if (RST_I = '1') then
					RDY_FLAG     <= '1'; -- ready as default
					AP_RD_DATA_O <= (others => '0');
				elsif (AP_CS_I = '1') then
					RDY_FLAG     <= WB_ACK_I;
					AP_RD_DATA_O <= WB_DATA_I;
				end if;
			end if;
		end process WB_ARBITER;


		-- ready output --
		AP_DONE_O <= RDY_FLAG;

		-- wb cycle ctrl --
		WB_STB_O <= AP_CS_I and RDY_FLAG;
		WB_CYC_O <= AP_CS_I and RDY_FLAG;



	-- WISHBONE Interface Operant Output ------------------------------------------------------
	-- -------------------------------------------------------------------------------------------
		WB_OPERAND_OUT: process(AP_CS_I, AP_ADR_I, AP_WR_DATA_I, AP_BYTE_SEL_I, AP_RW_I)
		begin
			if (use_isolation = true) then
				if (AP_CS_I = '1') then
					WB_ADR_O  <= AP_ADR_I;
					WB_DATA_O <= AP_WR_DATA_I;
					WB_SEL_O  <= AP_BYTE_SEL_I;
					WB_WE_O   <= AP_RW_I;
				else
					WB_ADR_O  <= (others => '0');
					WB_DATA_O <= (others => '0');
					WB_SEL_O  <= (others => '0');
					WB_WE_O   <= '0';
				end if;
			else
				WB_ADR_O  <= AP_ADR_I;
				WB_DATA_O <= AP_WR_DATA_I;
				WB_SEL_O  <= AP_BYTE_SEL_I;
				WB_WE_O   <= AP_RW_I;
			end if;
		end process WB_OPERAND_OUT;



end Structure;