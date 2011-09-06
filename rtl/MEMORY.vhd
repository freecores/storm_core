-- ######################################################
-- #      < STORM CORE SYSTEM by Stephan Nolting >      #
-- # ************************************************** #
-- #              Internal Working Memory               #
-- # ************************************************** #
-- # Version 2.8, 31.08.2011                            #
-- ######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.all;

entity MEMORY is
	generic	(
					MEM_SIZE      : natural; -- memory cells
					LOG2_MEM_SIZE : natural; -- log2(memory cells)
					SYNC_READ     : boolean  -- synchronous read
				);
	port	(
				CLK         : in  STD_LOGIC; -- memory master clock
				RES         : in  STD_LOGIC; -- reset, sync, high active

				DATA_IN     : in  STD_LOGIC_VECTOR(31 downto 0); -- write data
				DATA_OUT    : out STD_LOGIC_VECTOR(31 downto 0); -- read data
				ADR_IN      : in  STD_LOGIC_VECTOR(31 downto 0); -- adr in
				SEL_IN      : in  STD_LOGIC_VECTOR(03 downto 0); -- data quantity

				CS          : in  STD_LOGIC; -- chip select
				RW          : in  STD_LOGIC  -- read/write
			);
end MEMORY;

architecture Behavioral of MEMORY is

	--- Memory Type ---
	type RAM_8  is array(0 to MEM_SIZE - 1) of STD_LOGIC_VECTOR(7 downto 0);
	type RAM_32 is array(3 downto 0) of RAM_8;
	type RAM_IMAGE_TYPE is array (0 to MEM_SIZE - 1) of STD_LOGIC_VECTOR(31 downto 0);
	
	--- INIT MEMORY IMAGE ---
	-- can be used for debugging or to implement a start-up
	-- program, like a bootloader
	-----------------------------------------------------------------
	constant RAM_IMAGE : RAM_IMAGE_TYPE :=
	(
		-- place your order here
		others => x"F0013007"
	);
	-----------------------------------------------------------------

	--- Init RAM function ---
	function load_mem(IMAGE : RAM_IMAGE_TYPE) return RAM_32 is
		variable TEMP_MEM : RAM_32;
	begin
		for j in 0 to 3 loop
			for i in 0 to MEM_SIZE - 1 loop
				TEMP_MEM(j)(i) := IMAGE(i)(j*8+7 downto j*8);
			end loop;
		end loop;
		return TEMP_MEM;
	end load_mem;

	--- Internal Working Memory (Preloaded) ---
	signal MEM_FILE : RAM_32 := load_mem(RAM_IMAGE);

	--- Dummy memory for simulation ---
	signal SIM_MEM : RAM_IMAGE_TYPE;

begin

	-- STORM data/instruction memory -----------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		MEM_FILE_ACCESS: process(CLK, CS, RW, DATA_IN, ADR_IN, SEL_IN, MEM_FILE)
			variable ADR_TEMP, ADR_BUFFER : integer range 0 to MEM_SIZE - 1;
		begin
			--- RW Address ---
			ADR_TEMP := to_integer(unsigned(ADR_IN(LOG2_MEM_SIZE-1+2 downto 0+2))); -- word access

			--- Sync Write ---
			if rising_edge(CLK) then
				for i in 0 to 3 loop
					if (CS = '1') then
						if (RW = '1') then -- byte access
							if (SEL_IN(i) = '1') then -- subword select
								MEM_FILE(i)(ADR_TEMP) <= DATA_IN(8*i+7 downto 8*i);
							end if;
						end if;
						ADR_BUFFER := ADR_TEMP;
					end if;
				end loop;
			end if;

			--- Sync / Async Read ---
			for i in 0 to 3 loop
				if (SYNC_READ = TRUE) then
					DATA_OUT(8*i+7 downto 8*i) <= MEM_FILE(i)(ADR_BUFFER);
				else
					DATA_OUT(8*i+7 downto 8*i) <= MEM_FILE(i)(ADR_TEMP);
				end if;
			end loop;

		end process MEM_FILE_ACCESS;



	-- Dummy memory for simulation -----------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		DUMMY_MEM_PROC: process (MEM_FILE(3), MEM_FILE(2), MEM_FILE(1), MEM_FILE(0))
		begin
			-- use this memory dummy for simulation output
			-- -> its easier to analyse ;)
			for i in 0 to MEM_SIZE - 1 loop
				SIM_MEM(i) <= MEM_FILE(3)(i) & MEM_FILE(2)(i) & MEM_FILE(1)(i) & MEM_FILE(0)(i);
			end loop;
		end process DUMMY_MEM_PROC;

end Behavioral;