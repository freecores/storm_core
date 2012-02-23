-- ######################################################
-- #      < STORM CORE SYSTEM by Stephan Nolting >      #
-- # ************************************************** #
-- #              Internal Working Memory               #
-- # ************************************************** #
-- # Last modified: 16.02.2012                          #
-- ######################################################

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.STORM_core_package.ALL;

entity MEMORY is
	generic	(
				MEM_SIZE      : natural := 256;  -- memory cells
				LOG2_MEM_SIZE : natural := 8     -- log2(memory cells)
			);
	port	(
				-- Wishbone Bus --
				WB_CLK_I      : in  STD_LOGIC; -- memory master clock
				WB_RST_I      : in  STD_LOGIC; -- high active sync reset
				WB_CTI_I      : in  STD_LOGIC_VECTOR(02 downto 0); -- cycle indentifier
				WB_TGC_I      : in  STD_LOGIC_VECTOR(06 downto 0); -- cycle tag
				WB_ADR_I      : in  STD_LOGIC_VECTOR(LOG2_MEM_SIZE-1 downto 0); -- adr in
				WB_DATA_I     : in  STD_LOGIC_VECTOR(31 downto 0); -- write data
				WB_DATA_O     : out STD_LOGIC_VECTOR(31 downto 0); -- read data
				WB_SEL_I      : in  STD_LOGIC_VECTOR(03 downto 0); -- data quantity
				WB_WE_I       : in  STD_LOGIC; -- write enable
				WB_STB_I      : in  STD_LOGIC; -- valid cycle
				WB_ACK_O      : out STD_LOGIC; -- acknowledge
				WB_HALT_O     : out STD_LOGIC  -- throttle master
			);
end MEMORY;

architecture Behavioral of MEMORY is

	--- Are we simulating? ---
	constant IS_SIM : boolean := TRUE;

	--- Ack Buffer --
	signal WB_ACK_O_INT : STD_LOGIC;

	--- Memory Type ---
	type RAM_8  is array(0 to MEM_SIZE - 1) of STD_LOGIC_VECTOR(7 downto 0);
	type RAM_32 is array(3 downto 0) of RAM_8;
	type RAM_IMAGE_TYPE is array (0 to MEM_SIZE - 1) of STD_LOGIC_VECTOR(31 downto 0);
	
	--- INIT MEMORY IMAGE ---
	-----------------------------------------------------------------
	constant RAM_IMAGE : RAM_IMAGE_TYPE :=
	(
000000 => x"EA000012",
000001 => x"E59FF014",
000002 => x"E59FF014",
000003 => x"E59FF014",
000004 => x"E59FF014",
000005 => x"E1A00000",
000006 => x"E51FFFF0",
000007 => x"E59FF010",
000008 => x"00000038",
000009 => x"0000003C",
000010 => x"00000040",
000011 => x"00000044",
000012 => x"00000048",
000013 => x"0000004C",
000014 => x"EAFFFFFE",
000015 => x"EAFFFFFE",
000016 => x"EAFFFFFE",
000017 => x"EAFFFFFE",
000018 => x"EAFFFFFE",
000019 => x"EAFFFFFE",
000020 => x"E59F00C8",
000021 => x"E10F1000",
000022 => x"E3C1107F",
000023 => x"E38110DB",
000024 => x"E129F001",
000025 => x"E1A0D000",
000026 => x"E2400080",
000027 => x"E10F1000",
000028 => x"E3C1107F",
000029 => x"E38110D7",
000030 => x"E129F001",
000031 => x"E1A0D000",
000032 => x"E2400080",
000033 => x"E10F1000",
000034 => x"E3C1107F",
000035 => x"E38110D1",
000036 => x"E129F001",
000037 => x"E1A0D000",
000038 => x"E2400080",
000039 => x"E10F1000",
000040 => x"E3C1107F",
000041 => x"E38110D2",
000042 => x"E129F001",
000043 => x"E1A0D000",
000044 => x"E2400080",
000045 => x"E10F1000",
000046 => x"E3C1107F",
000047 => x"E38110D3",
000048 => x"E129F001",
000049 => x"E1A0D000",
000050 => x"E2400080",
000051 => x"E10F1000",
000052 => x"E3C1107F",
000053 => x"E38110DF",
000054 => x"E129F001",
000055 => x"E1A0D000",
000056 => x"E3A00000",
000057 => x"E59F1038",
000058 => x"E59F2038",
000059 => x"E1510002",
000060 => x"0A000001",
000061 => x"34810004",
000062 => x"3AFFFFFB",
000063 => x"E3A00000",
000064 => x"E1A01000",
000065 => x"E1A02000",
000066 => x"E1A0B000",
000067 => x"E1A07000",
000068 => x"E59FA014",
000069 => x"E1A0E00F",
000070 => x"E1A0F00A",
000071 => x"EAFFFFFE",
000072 => x"00000A00",
000073 => x"00000184",
000074 => x"00000184",
000075 => x"00000130",
000076 => x"E3E03A01",
000077 => x"E3A02000",
000078 => x"E52DE004",
000079 => x"E5032FDF",
000080 => x"E3A0E001",
000081 => x"E5032FDF",
000082 => x"E1A0100E",
000083 => x"E1A0000E",
000084 => x"E1A02000",
000085 => x"EA000000",
000086 => x"E3A0E001",
000087 => x"E2820001",
000088 => x"E08EC001",
000089 => x"E5031FDF",
000090 => x"E350001E",
000091 => x"E3A01000",
000092 => x"E1A02001",
000093 => x"CAFFFFF7",
000094 => x"E1A0100E",
000095 => x"E1A0E00C",
000096 => x"EAFFFFF2",
others => x"F0013007"
	);
	-----------------------------------------------------------------

	--- Init RAM function ---
	function load_mem(IMAGE : RAM_IMAGE_TYPE; j : natural) return RAM_8 is
		variable TEMP_MEM : RAM_8;
	begin
		for i in 0 to MEM_SIZE - 1 loop
			TEMP_MEM(i) := IMAGE(i)(8*j+7 downto 8*j);
		end loop;
		return TEMP_MEM;
	end load_mem;

	--- Internal Working Memory ---
	signal MEM_FILE_HH : RAM_8 := load_mem(RAM_IMAGE, 3);
	signal MEM_FILE_HL : RAM_8 := load_mem(RAM_IMAGE, 2);
	signal MEM_FILE_LH : RAM_8 := load_mem(RAM_IMAGE, 1);
	signal MEM_FILE_LL : RAM_8 := load_mem(RAM_IMAGE, 0);

	--- Dummy memory for simulation ---
	signal SIM_MEM : RAM_IMAGE_TYPE;

begin

	-- STORM data/instruction memory -----------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		MEM_FILE_ACCESS: process(WB_CLK_I)
		begin
			--- Sync Write ---
			if rising_edge(WB_CLK_I) then
				if (WB_RST_I = '1') then
					WB_ACK_O_INT <= '0';
				else

				--- Data Read/Write ---
					if (WB_STB_I = '1') then
						if (WB_WE_I = '1') then
							if (WB_SEL_I(0) = '1') then
								MEM_FILE_LL(to_integer(unsigned(WB_ADR_I))) <= WB_DATA_I(8*0+7 downto 8*0);
							end if;
							if (WB_SEL_I(1) = '1') then
								MEM_FILE_LH(to_integer(unsigned(WB_ADR_I))) <= WB_DATA_I(8*1+7 downto 8*1);
							end if;
							if (WB_SEL_I(2) = '1') then
								MEM_FILE_HL(to_integer(unsigned(WB_ADR_I))) <= WB_DATA_I(8*2+7 downto 8*2);
							end if;
							if (WB_SEL_I(3) = '1') then
								MEM_FILE_HH(to_integer(unsigned(WB_ADR_I))) <= WB_DATA_I(8*3+7 downto 8*3);
							end if;
						end if;
						WB_DATA_O(8*0+7 downto 8*0) <= MEM_FILE_LL(to_integer(unsigned(WB_ADR_I)));
						WB_DATA_O(8*1+7 downto 8*1) <= MEM_FILE_LH(to_integer(unsigned(WB_ADR_I)));
						WB_DATA_O(8*2+7 downto 8*2) <= MEM_FILE_HL(to_integer(unsigned(WB_ADR_I)));
						WB_DATA_O(8*3+7 downto 8*3) <= MEM_FILE_HH(to_integer(unsigned(WB_ADR_I)));
--					else
--						WB_DATA_O <= (others => '0');
					end if;

					--- ACK Control ---
					if (WB_CTI_I = "000") or (WB_CTI_I = "111") then
						WB_ACK_O_INT <= WB_STB_I and (not WB_ACK_O_INT);
					else
						WB_ACK_O_INT <= WB_STB_I;
					end if;
				end if;
			end if;
		end process MEM_FILE_ACCESS;

		--- ACK Signal ---
		WB_ACK_O <= WB_ACK_O_INT;

		--- Throttle ---
		WB_HALT_O <= '0'; -- yeay, we're at full speed!



	-- Dummy memory for simulation -----------------------------------------------------------------------
	-- --------------------------------------------------------------------------------------------------------
		-- use this memory dummy for simulation output
		DEBUG_SIM_MEM:
		if (IS_SIM = TRUE) generate
			GEN_DEBUG_MEM:
			for i in 0 to MEM_SIZE - 1 generate
				SIM_MEM(i) <= MEM_FILE_HH(i) & MEM_FILE_HL(i) & MEM_FILE_LH(i) & MEM_FILE_LL(i);
			end generate;
		end generate;


end Behavioral;