-- #######################################################
-- #     < STORM CORE PROCESSOR by Stephan Nolting >     #
-- # *************************************************** #
-- #      Reset Synchronizer (do we really need him?)    #
-- # *************************************************** #
-- # Version 1.0, 18.03.2011                             #
-- #######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity RES_SYNC is
    Port ( CLK : in  STD_LOGIC;
           RES_IN : in  STD_LOGIC;
           RES_OUT : out  STD_LOGIC);
end RES_SYNC;

architecture Behavioral of RES_SYNC is

	-- local signals --
	signal SYNC_RES	: STD_LOGIC_VECTOR(1 downto 0); -- shift reg for sync reset

begin

	-- Reset Synchronizer -------------------------------------------------------
	-- -----------------------------------------------------------------------------
	EXTERNAL_SYNC: process(CLK, RES_IN, SYNC_RES)
	begin
		if rising_edge(CLK) then
			SYNC_RES(0) <= RES_IN;
			SYNC_RES(1) <= SYNC_RES(0);
			RES_OUT <= SYNC_RES(0) or SYNC_RES(1) or RES_IN;
		end if;
	end process EXTERNAL_SYNC;

end Behavioral;