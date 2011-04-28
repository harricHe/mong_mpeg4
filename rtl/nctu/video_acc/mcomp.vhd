---------------------------------------------------------------------------
-- mcomp.vhd
--
-- Motion Compensation Hardware for HW/SW Co-Design
--     Created:  YCC 03-31-2008
--     Modified: CJT 04-21-2008
--
-- This code is for the class "Embedded Firmware and Hardware/Software
-- Co-design" in Spring, 2008.
-- Dept. of Computer Science and Information Engineering
-- National Chiao Tung University
-- 1001 Ta-Hsueh Rd., Hsinchu, 300, Taiwan
--
---------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;

library techmap;
use techmap.gencomp.all;

entity mcomp is
  generic (
    ahbndx  : integer := 0;
    ahbaddr : integer := 0;
    addrmsk : integer := 16#fff#;
    verid   : integer := 0;
    irq_no  : integer := 0
  );

  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type
  );
end;

architecture rtl of mcomp is

constant hconfig : ahb_config_type := (
  0      => ahb_device_reg ( VENDOR_NCTU, NCTU_MCOMP, 0, verid, irq_no),
  4      => ahb_membar(ahbaddr, '1', '0', addrmsk),
  others => X"00000000"
);

signal reg_a : std_logic_vector(31 downto 0);  -- pixel value 1
signal reg_b : std_logic_vector(31 downto 0);  -- pixel value 2
signal reg_c : std_logic_vector(31 downto 0);  -- pixel value 3
signal reg_d : std_logic_vector(31 downto 0);  -- pixel value 4
signal reg_r : std_logic_vector(31 downto 0);  -- rounding value
signal valid : std_logic; -- is the logic selected by a master
signal temp_addr : std_logic_vector(31 downto 0);

-- pragma translate_off
-- The following signals are used for GHDL simulation, you don't
-- need these for ModleSim simulation
signal hsel    : std_logic_vector(0 to NAHBSLV-1); -- slave select
signal haddr   : std_logic_vector(31 downto 0);    -- address bus (byte)
signal hwrite  : std_ulogic;                       -- read/write
signal hwdata  : std_logic_vector(31 downto 0);    -- write data bus
signal hiready : std_ulogic;                       -- transfer done
-- pragma translate_on

begin
  ahbso.hresp   <= "00"; 
  ahbso.hsplit  <= (others => '0'); 
  ahbso.hirq    <= (others => '0');
  ahbso.hcache  <= '0';
  ahbso.hconfig <= hconfig;
  ahbso.hindex  <= ahbndx;

-- pragma translate_off
-- The following signals are used for GHDL simulation, you don't
-- need these for ModleSim simulation
  hsel    <= ahbsi.hsel;
  haddr   <= ahbsi.haddr;
  hwrite  <= ahbsi.hwrite;
  hwdata  <= ahbsi.hwdata;
  hiready <= ahbsi.hready;
-- pragma translate_on

  ready_ctrl : process (clk, rst)
  begin
      if rst = '0' then
          ahbso.hready <= '1';
      elsif rising_edge(clk ) then
          if (ahbsi.hsel(ahbndx) and ahbsi.htrans(1)) = '1' then
              ahbso.hready <= '1'; -- you should control this signal for
                                   -- multi-cycle data processing
          end if;
      end if;
  end process;

  addr_fetch : process (clk, rst)
  begin
      if rst = '0' then
          temp_addr <= (others => '0');
          valid <= '0';
      elsif rising_edge(clk) then
          if (ahbsi.hsel(ahbndx) and ahbsi.htrans(1) and
              ahbsi.hready and ahbsi.hwrite) = '1' then
              temp_addr <= ahbsi.haddr;
              valid <= '1';
          else
              valid <= '0';
          end if;
      end if;
  end process;

  write_process : process (clk, rst)
  begin
      if rst = '0' then
          reg_a <= (others => '0');
          reg_b <= (others => '0');
          reg_c <= (others => '0');
          reg_d <= (others => '0');
          reg_r <= (others => '0');
      elsif rising_edge(clk) then
          if valid = '1' then
              if    temp_addr(4 downto 2) = "000" then
                  reg_a <= ahbsi.hwdata;
              elsif temp_addr(4 downto 2) = "001" then
                  reg_b <= ahbsi.hwdata;
              elsif temp_addr(4 downto 2) = "010" then
                  reg_c <= ahbsi.hwdata;
              elsif temp_addr(4 downto 2) = "011" then
                  reg_d <= ahbsi.hwdata;
              elsif temp_addr(4 downto 2) = "100" then
                  reg_r <= ahbsi.hwdata;
              end if;
          end if;
      end if;
  end process;

  read_process : process (clk, rst)
  variable shift : std_logic_vector(31 downto 0);
  begin
      if rst = '0' then
          ahbso.hrdata <= (others => '0');
      elsif rising_edge(clk) then
          if (ahbsi.hsel(ahbndx) and ahbsi.hready) = '1' then
              if    ahbsi.haddr(4 downto 2) = "000" then
                  ahbso.hrdata <= reg_a;
              elsif ahbsi.haddr(4 downto 2) = "001" then
                  ahbso.hrdata <= reg_b;
              elsif ahbsi.haddr(4 downto 2) = "010" then
                  ahbso.hrdata <= reg_c;
              elsif ahbsi.haddr(4 downto 2) = "011" then
                  ahbso.hrdata <= reg_d;
              elsif ahbsi.haddr(4 downto 2) = "100" then
                  ahbso.hrdata <= reg_r;
              elsif ahbsi.haddr(4 downto 2) = "101" then
                  shift := reg_a + reg_b + 1 - reg_r;
            	  ahbso.hrdata <= ('0' & shift(31 downto 1));
              elsif ahbsi.haddr(4 downto 2) = "110" then
                  shift := reg_a + reg_b + reg_c + reg_d + 2 - reg_r;
            	  ahbso.hrdata <= ("00" & shift(31 downto 2));
              else
                  ahbso.hrdata <= (others => '0');
              end if;
    	  else
              ahbso.hrdata <= (others => '0');
          end if;
      end if;
  end process;

-- pragma translate_off
  bootmsg : report_version 
  generic map ("Lab3 " & tost(ahbndx) & ": Motion Compensation Module rev 1");
-- pragma translate_on
end;
