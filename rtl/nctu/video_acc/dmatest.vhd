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
use grlib.DMA2AHB_Package.all;

library gaisler;
use gaisler.misc.all;

library techmap;
use techmap.gencomp.all;

entity dmatest is
  generic (
    slvidx  : integer := 0;	-- slave index
    ahbaddr : integer := 0;
    addrmsk : integer := 16#fff#;
    verid   : integer := 0;
    irq_no  : integer := 0;
	
	-- for dma
	mstidx : integer := 0;	-- master index
	dbuf   : integer := 4
  );

  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    ahbsi   : in  ahb_slv_in_type;
    ahbso   : out ahb_slv_out_type;
	
	-- for dma
	ahbmi : in  ahb_mst_in_type;
	ahbmo : out ahb_mst_out_type 
  );
end;

architecture rtl of dmatest is


constant hconfig : ahb_config_type := (
  0      => ahb_device_reg ( VENDOR_NCTU, NCTU_DMA, 0, verid, irq_no),
  4      => ahb_membar(ahbaddr, '1', '0', addrmsk),
  others => X"00000000"
);

constant mcomp_data : std_logic_vector := x"B0000000";

-- for dma
-- constant pconfig : apb_config_type := (
  -- 0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_AHBDMA, 0, 0, pirq),
  -- 1 => apb_iobar(paddr, pmask));

type dma_state_type is (idle, readc, writec, write_r, write_mode);
type dma_stage_type is (stage1, idlestage, stage2);

subtype word32 is std_logic_vector(31 downto 0);
type datavec is array (0 to dbuf-1) of word32;

type reg_type is record
  srcaddr : std_logic_vector(31 downto 0);
  srcinc  : std_logic_vector(1 downto 0);
  dstaddr : std_logic_vector(31 downto 0);
  dstinc  : std_logic_vector(1 downto 0);
  idstaddr : std_logic_vector(31 downto 0);
  idstinc  : std_logic_vector(1 downto 0);
  --len     : std_logic_vector(15 downto 0);
  enable  : std_logic;
  write   : std_logic;
  inhibit : std_logic;
  status  : std_logic_vector(1 downto 0);
  dstate  : dma_state_type;
  stage	  : dma_stage_type;
  data    : datavec;
  cnt     : integer range 0 to dbuf-1;
  idst_stride : std_logic_vector(11 downto 0);
  idst_width : std_logic_vector(3 downto 0);
  src_stride : std_logic_vector(11 downto 0);
  dst_stride : std_logic_vector(11 downto 0);
  src_width : std_logic_vector(3 downto 0);			-- 0~9
  dst_width : std_logic_vector(3 downto 0);			-- 0~9
  src_mcomp : std_logic;
  rfactor : std_logic_vector(31 downto 0);
  mcomp_mode : std_logic_vector(1 downto 0);
  beat : integer range 0 to 4;
  
  write_valid : std_logic; -- is the logic selected by a master
  write_addr : std_logic_vector(31 downto 0);
end record;

signal r, rin : reg_type;
signal dmai : dma_in_type;
signal dmao : dma_out_type;
----------------------------------

--signal readCountInRow : std_logic_vector(3 downto 0);	-- 0~9
--signal width : std_logic_vector(3 downto 0);			-- 0~9
type Data_Vector  is array (Natural range <> ) of Std_Logic_Vector(32-1 downto 0);
begin
	ahbso.hresp   <= "00"; 
	ahbso.hsplit  <= (others => '0');
	ahbso.hirq    <= (others => '0');
	ahbso.hcache  <= '0';
	ahbso.hconfig <= hconfig;
	ahbso.hindex  <= slvidx;
	
	ready_ctrl : process (clk, rst)
	begin
		if rst = '0' then
			ahbso.hready <= '1';
		elsif rising_edge(clk ) then
			if (ahbsi.hsel(slvidx) and ahbsi.htrans(1)) = '1' then
				ahbso.hready <= '1';
			end if;
		end if;
	end process;
	
	---------------------ahb dma----------------------
	comb : process(ahbsi, dmao, rst, r)
		variable v       : reg_type;
		variable regd    : std_logic_vector(31 downto 0);   -- data from registers
		variable start   : std_logic;
		variable burst   : std_logic;
		variable write   : std_logic;
		variable ready   : std_logic;
		variable retry   : std_logic;
		variable mexc    : std_logic;
		variable irq     : std_logic;
		variable address : std_logic_vector(31 downto 0);   -- DMA address
		--variable size    : std_logic_vector( 1 downto 0);   -- DMA transfer size
		--variable newlen  : std_logic_vector(15 downto 0);
		variable oldaddr : std_logic_vector(9 downto 0);
		variable newaddr : std_logic_vector(9 downto 0);
		variable oldsize : std_logic_vector( 1 downto 0);
		variable ainc    : std_logic_vector( 3 downto 0);
		variable trans_length : integer range 0 to 27;
		variable data 	: Data_Vector(26 downto 0);
		variable trans_size : integer range 0 to 32;
		variable DataPart:            Integer := 0;
		variable need_split_burst : Boolean;
		
		variable src_ram, src_mcomp, dst_ram, dst_mcomp : std_logic;
	begin
		v := r; 
		regd := (others => '0'); 
		burst := '0'; 
		start := '0';
		write := '0'; 
		ready := '0'; 
		mexc := '0';
		irq := '0'; 
		--size := r.srcinc; 
		start := r.enable;
		v.inhibit := '0';
		burst := '0'; 
		address := (others=>'0');
		--v.beat := 0;
		
		src_ram := not r.src_mcomp;
		src_mcomp := r.src_mcomp;
		dst_ram := r.src_mcomp;
		dst_mcomp := not r.src_mcomp;
		
		-- initialize
		if rst = '0' then
			v.dstate := idle; 
			v.stage := stage1;
			v.enable := '0'; 
			v.write := '0';
			v.cnt  := 0;
			v.srcaddr := (others=>'0');
			v.dstaddr := (others=>'0');
			v.srcinc := (others=>'0');
			v.dstinc := (others=>'0');
			v.src_stride := (others=>'0');
			v.src_width := (others=>'0');
			v.dst_stride := (others=>'0');
			v.dst_width := (others=>'0');
			v.src_mcomp := '0';
			v.write_addr := (others=>'0');
			v.write_valid := '0';
			v.rfactor := (others=>'0');
			v.mcomp_mode := (others=>'0');
			v.beat := 0;	
			dmai.LOCK <= '0';
		end if;

		if r.enable = '1' then
			v.inhibit := '0';
			burst := '1'; 
			
			if src_ram = '1' then	-- read from ram, write to mcomp, we need transfer(3*9=27) words
				trans_length := 27;	
			else					-- read from mcomp, write to ram, we need transfer(2*8=16) words 
				trans_length := 16;
			end if;
			
			if r.write = '0' then 
				address := r.srcaddr;
				oldaddr := r.srcaddr(9 downto 0); 
				oldsize := r.srcinc;
			else 
				address := r.dstaddr; 
				oldaddr := r.dstaddr(9 downto 0); 
				oldsize := r.dstinc; 
			end if;
			
			ainc := decode(oldsize);
			trans_size := conv_integer(ainc);
			newaddr := oldaddr + ainc(3 downto 0);
			
			-- transfer size
			if trans_size=4 then
				dmai.Size <= HSIZE32;
			elsif trans_size=2 then
				dmai.Size <= HSIZE16;
				if address(1 downto 0) = "00" then
					DataPart := 0;
				else
					DataPart := 1;
				end if;
			elsif trans_size=1 then
				dmai.Size <= HSIZE8;
				if address(1 downto 0) = "00" then
					DataPart := 0;
				elsif address(1 downto 0) = "01" then
					DataPart := 1;
				elsif address(1 downto 0) = "10" then
					DataPart := 2;
				else
					DataPart := 3;
				end if;
			--else
			--	report "Unsupported data width"
			--	severity Failure;
			end if;
		
			if r.write = '0' then	-- read from source
				--need_split_burst := (r.src_stride /= (31 downto 0 =>'0'));
				
				-- set new address of new burst
				if r.beat = 3 then
					v.srcaddr := r.srcaddr + r.src_stride(9 downto 0);
				end if;
				
				-- if we received a data from ram, increse beat
				if dmao.OKAY = '1' then
					if src_ram = '1'then	
						v.beat := r.beat + 1;
					else
						v.beat := 0;
					end if;
				elsif r.beat = 3 then
					v.beat := 0;
				end if;
				
				if	src_ram = '1' and
					((v.beat = 2 and ahbmi.hready = '1') or 	-- 3rd address sent
					(v.beat > 2 or dmao.Ready = '1'))  then		-- 3rd data got
					-- pause transfer
					v.inhibit := '1';
					burst := '0'; 
				end if;
				
				-- if we get a data from source
				if dmao.READY = '1' then

					-- align the data into dma buffer by the transfer size
					if trans_size=4 then		-- read 4 byte
					   v.data(r.cnt)    := dmao.Data;
					elsif trans_size=2 then		-- read 2 byte
					   v.data((r.cnt)/2)((31-16*((r.cnt) mod 2)) downto (16-(16*((r.cnt) mod 2)))) :=
						 dmao.Data((31-16*DataPart) downto (16-16*DataPart));
					   --DataPart := (DataPart + 1) mod 2;
					elsif trans_size=1 then		-- read 1 byte
					   v.data((r.cnt)/4)((31-8*((r.cnt) mod 4)) downto (24-(8*((r.cnt) mod 4)))) :=
						 dmao.Data((31-8*DataPart) downto (24-8*DataPart));
					   --DataPart := (DataPart + 1) mod 4;
					end if;
					
					
					if r.cnt = trans_length-1 then					-- if we already get all data
						v.write := '1'; 
						v.dstate := writec;
						v.cnt := 0; 
						v.inhibit := '1';
						burst := '0';
						address := r.dstaddr; 
						--size := r.dstinc;
					elsif src_mcomp = '1' and r.cnt >= 13 then	-- early stop the data request
						v.inhibit := '1';
						burst := '0';
						v.cnt := r.cnt + 1;
					else
						v.cnt := r.cnt + 1; 
					end if;
				end if;
			else	-- write to destination
				--need_split_burst := (r.dst_stride /= (31 downto 0 =>'0'));
				
				-- set new address of new burst
				if r.beat = 2 then
					v.dstaddr := r.dstaddr + r.dst_stride(9 downto 0);
				end if;
				
				
				-- if we write a data to the destination
				if dmao.OKAY = '1' then
					-- if we are writing to ram, we need to count the beats
					if dst_ram = '1' then	
						v.beat := r.beat + 1;
					else
						v.beat := 0;
					end if;
				elsif r.beat = 2 then
					v.beat := 0;
				end if;
				
				--if need_split_burst and (v.beat > 0 or r.beat > 0) then
				if  (dst_ram = '1' and (v.beat > 0 or r.beat > 0) and ahbmi.hready = '1') or
					(src_ram = '1' and not (r.dstate = writec or r.dstate = readc))then
					-- pause transfer
					v.inhibit := '1';
					burst := '0'; 
				end if;
				
				
				if dst_mcomp = '1' then
					-- write to mcomp, we need to write rfactor
					if r.dstate = write_r then 
						v.dstate  := write_mode;
						--start := '0';
					elsif r.dstate = write_mode then
						v.dstate := writec;
						--start := '0';
					elsif r.cnt = trans_length-1 then 
						v.dstate  := write_r;
					end if;
				elsif r.cnt = trans_length-1 then 
					start := '0'; 
				end if;
				
				-- state machine
				if r.cnt = trans_length-1 then
					--if(r.src_mcomp='1' or r.dstate = write_mode or r.stage = idlestage) then -- when write done, finish work
						
						if r.stage = stage1 and (r.dstate = write_mode or r.src_mcomp='1')then	
							-- change to idle stage
							v.stage := idlestage;
							v.dstate := idle;
						elsif r.stage = stage2 then	
							-- finish
							v.stage := stage1;
							v.dstate := idle;
							v.enable := '0'; 
							v.cnt := 0;
							v.write := '0';
							irq := start;
						elsif r.stage = idlestage then	
							-- change to stage2, mcomp to ram
							v.stage := stage2;
							v.dstate := readc;
							v.cnt := 0;
							v.write := '0'; 
							
							-- mcomp
							v.srcaddr := mcomp_data;
							v.src_stride := (others=>'0');
							v.srcinc := "10";
							
							-- ram
							v.dstaddr := r.idstaddr;
							v.dst_stride := r.idst_stride;
							v.dstinc := r.idstinc;
							
							v.src_mcomp := '1';
							--v.len := newlen; 
						end if;
					--end if;
				end if;
				
				if dmao.OKAY = '1' then
					if r.cnt < trans_length-1 then 
						v.cnt := r.cnt + 1; 
					end if;
				end if;
			end if;
		else -- r.enable = '0'
			v.beat := 0;
			address := (others=>'0');
		end if;

		-- AHB write address fetch
		if (ahbsi.hsel(slvidx) and ahbsi.htrans(1) and ahbsi.hready and ahbsi.hwrite) = '1' then
			v.write_addr := ahbsi.haddr;
			v.write_valid := '1';
		else
			v.write_valid := '0';
		end if;
		
		-- AHB write data fetch
		if(r.write_valid = '1')then
			case r.write_addr(5 downto 2) is
				when "0000" => -- 0x00
					v.srcaddr := ahbsi.hwdata;
				when "0001" => -- 0x04
					v.idstaddr := ahbsi.hwdata;
				when "0010" => -- 0x08
					--v.len := ahbsi.hwdata(15 downto 0);
					v.srcinc := ahbsi.hwdata(17 downto 16);
					v.idstinc := ahbsi.hwdata(19 downto 18);
					v.enable := ahbsi.hwdata(20);
					if v.enable = '1' then
						v.src_mcomp := '0';
						v.dstate := readc;
						v.stage := stage1;
						
						-- to mcomp
						v.dstaddr := mcomp_data;
						v.dst_stride := (others=>'0');
						v.dstinc := "10" ;
					end if;
				when "0011" => -- 0x0C
					v.src_stride := ahbsi.hwdata(31 downto 20);	-- 12 bits
					v.src_width := ahbsi.hwdata(19 downto 16);	-- 4 bits
					v.idst_stride := ahbsi.hwdata(15 downto 4);	-- 12 bits
					v.idst_width := ahbsi.hwdata(3 downto 0);	-- 4 bits
				-- when "0100" => -- 0x10
					-- v.src_width := ahbsi.hwdata(3 downto 0);
				-- when "0101" => -- 0x14
					-- v.dst_stride := ahbsi.hwdata;
				-- when "0110" => -- 0x18
					-- v.dst_width := ahbsi.hwdata(3 downto 0);
				when "0111" => -- 0x1C
					v.rfactor := "00" & ahbsi.hwdata(29 downto 0);		-- r factor
					v.mcomp_mode := ahbsi.hwdata(31 downto 30); -- mocmp mode
				when others => null;
			end case;
		end if;

		rin <= v;
		
		dmai.Request <= start and not v.inhibit;
		dmai.Lock <= r.enable;
		dmai.Beat 	<= HINCR;
		dmai.Burst   <= burst;
		dmai.Store   <= v.write;
		dmai.Address <= address;
		dmai.Reset	 <= '0';
		--dmai.Size    <= size;
		if r.write = '1' then
			if r.dstate = writec then
				dmai.Data <= r.data(r.cnt);
			elsif r.dstate = write_r then
				dmai.Data <= r.rfactor;
			elsif r.dstate = write_mode then
				dmai.Data <= (31 downto 2 => '0') & r.mcomp_mode;
			end if;
		else
			dmai.Data <= (others=>'0');
		end if;

	end process;
	
	regs : process(clk)
	begin 
		if rising_edge(clk) then 
			r <= rin; 
		end if; 
	end process;

	-- ahb reading
	ahb_read : process(clk, rst)
	begin 
		if rst = '0' then
			ahbso.hrdata  <= (others => '0');
		elsif rising_edge(clk) then 
			-- read DMA registers
			if (ahbsi.hsel(slvidx) and ahbsi.hready) = '1' then
				case ahbsi.haddr(3 downto 2) is
				when "00" => 
					ahbso.hrdata  <= r.srcaddr;
				when "01" => 
					ahbso.hrdata  <= r.dstaddr;
				when "10" => 
					--ahbso.hrdata <= (31 downto 21 => '0') & r.enable & r.srcinc & r.dstinc & r.len;
					ahbso.hrdata <= (31 downto 21 => '0') & r.enable & r.srcinc & r.dstinc & (15 downto 0 => '0');
				when others => 
					ahbso.hrdata  <= (others => '0');
				end case;
			end if;
		end if; 
	end process;

	
	-- master
	mst : DMA2AHB generic map(
		hindex => mstidx,
		vendorid => VENDOR_NCTU,
		deviceid => NCTU_MCOMP,
		version => verid
	)
	port map(
		-- AMBA AHB system signals
		HCLK => clk,
		HRESETn => rst,

		-- Direct Memory Access Interface
		DMAIn => dmai,
		DMAOut => dmao,

		-- AMBA AHB Master Interface
		AHBIn => ahbmi,
		AHBOut => ahbmo
	);
-- pragma translate_off
  bootmsg : report_version 
  generic map ("Final " & tost(slvidx) & ": dma test");
-- pragma translate_on
end;

