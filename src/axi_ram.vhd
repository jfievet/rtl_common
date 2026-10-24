library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.rams_sp_wf_pkg.all;

entity axi_ram is
    generic (
        G_DATA_WIDTH : positive := 32;
        G_ADDR_WIDTH : positive := 10;
        G_DEPTH      : positive := 1024;
        G_RAM_VENDOR : integer  := 1 -- 0: PLACEHOLDER, 1:Xilinx BRAM
    );
    port (
        clk            : in  std_logic;                          -- Added clock
        resetn         : in  std_logic;                          -- Added active-low reset
        mem_axi_awvalid : in  std_logic;
        mem_axi_awready : out std_logic;
        mem_axi_awaddr  : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        mem_axi_awprot  : in  std_logic_vector(2 downto 0);
        mem_axi_wvalid  : in  std_logic;
        mem_axi_wready  : out std_logic;
        mem_axi_wdata   : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
        mem_axi_wstrb   : in  std_logic_vector((G_DATA_WIDTH/8)-1 downto 0);
        mem_axi_bvalid  : out std_logic;
        mem_axi_bready  : in  std_logic;
        mem_axi_arvalid : in  std_logic;
        mem_axi_arready : out std_logic;
        mem_axi_araddr  : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        mem_axi_arprot  : in  std_logic_vector(2 downto 0);
        mem_axi_rvalid  : out std_logic;
        mem_axi_rready  : in  std_logic;
        mem_axi_rdata   : out std_logic_vector(G_DATA_WIDTH-1 downto 0)
    );
end entity;

architecture rtl of axi_ram is
    constant NUM_BANKS : integer := G_DEPTH / 256; -- Each bank is 256 words
    subtype bank_addr_t is std_logic_vector(7 downto 0); -- 8 bits for 256 locations

    -- RAM bank signals
    signal wr_en_bank   : std_logic_vector(NUM_BANKS-1 downto 0);
    signal wr_addr_bank : bank_addr_t;
    signal rd_addr_bank : bank_addr_t;
    signal wr_data_bank : std_logic_vector(31 downto 0);
    signal rd_data_bank : std_logic_vector(31 downto 0);
    type rd_data_vec_t is array (0 to NUM_BANKS-1) of std_logic_vector(31 downto 0);
    signal rd_data_vec  : rd_data_vec_t;

    signal bank_sel_wr  : integer range 0 to NUM_BANKS-1;
    signal bank_sel_rd  : integer range 0 to NUM_BANKS-1;
    signal bvalid_s  : std_logic := '0';
    signal rvalid_s  : std_logic := '0';
    signal rdata_s   : std_logic_vector(G_DATA_WIDTH-1 downto 0) := (others => '0');

    -- Xilinx Address and data signals
    signal ram_addr : std_logic_vector(G_ADDR_WIDTH-1 downto 0);
    signal ram_0_we : std_logic;
    signal ram_1_we : std_logic;
    signal ram_2_we : std_logic;
    signal ram_3_we : std_logic;
    signal ram_di   : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal ram_0_do : std_logic_vector(7 downto 0);
    signal ram_1_do : std_logic_vector(7 downto 0);
    signal ram_2_do : std_logic_vector(7 downto 0);
    signal ram_3_do : std_logic_vector(7 downto 0);

begin

    -- Only instantiate this logic for ICE40UP EBR (vendor = 0)
    gen_ice40up : if G_RAM_VENDOR = 0 generate
        -- Decode bank and address
        bank_sel_wr  <= to_integer(unsigned(mem_axi_awaddr(G_ADDR_WIDTH-1 downto 10)));
        wr_addr_bank <= mem_axi_awaddr(9 downto 2);
        bank_sel_rd  <= to_integer(unsigned(mem_axi_araddr(G_ADDR_WIDTH-1 downto 10)));
        rd_addr_bank <= mem_axi_araddr(9 downto 2);
        wr_data_bank <= mem_axi_wdata;

        -- Write enable for each bank
        gen_wr_en: for i in 0 to NUM_BANKS-1 generate
            wr_en_bank(i) <= '1' when (bank_sel_wr = i and mem_axi_awvalid = '1' and mem_axi_wvalid = '1' and bvalid_s = '0') else '0';
        end generate;

        -- Instantiate RAM banks
        gen_ram: for i in 0 to NUM_BANKS-1 generate

            -- EMPTY --

        end generate;
        rdata_s <= rd_data_vec(bank_sel_rd) when bank_sel_rd < NUM_BANKS else (others=>'0');
    end generate;

    gen_xilinx : if G_RAM_VENDOR = 1 generate

    begin

        -- Write and read address selection
        ram_addr <= mem_axi_awaddr when (mem_axi_awvalid = '1' and mem_axi_wvalid = '1') else mem_axi_araddr;
        ram_0_we   <= '1' when (mem_axi_awvalid = '1' and mem_axi_wvalid = '1' and bvalid_s = '0' and mem_axi_wstrb(0)='1') else '0';
        ram_1_we   <= '1' when (mem_axi_awvalid = '1' and mem_axi_wvalid = '1' and bvalid_s = '0' and mem_axi_wstrb(1)='1') else '0';
        ram_2_we   <= '1' when (mem_axi_awvalid = '1' and mem_axi_wvalid = '1' and bvalid_s = '0' and mem_axi_wstrb(2)='1') else '0';
        ram_3_we   <= '1' when (mem_axi_awvalid = '1' and mem_axi_wvalid = '1' and bvalid_s = '0' and mem_axi_wstrb(3)='1') else '0';
        ram_di   <= mem_axi_wdata;
        ram_0_inst : entity work.rams_sp_wf
            generic map (
                G_DEPTH     => G_DEPTH,
                G_RAM_INIT  => C_RAM_0_INIT
            )
            port map (
                clk  => clk,
                we   => ram_0_we,
                en   => '1',
                addr => ram_addr(integer(ceil(log2(real(G_DEPTH))))-1+2 downto 2),
                di   => ram_di(7 downto 0),
                do   => ram_0_do
            );

        ram_1_inst : entity work.rams_sp_wf
            generic map (
                G_DEPTH     => G_DEPTH,
                G_RAM_INIT  => C_RAM_1_INIT
            )
            port map (
                clk  => clk,
                we   => ram_1_we,
                en   => '1',
                addr => ram_addr(integer(ceil(log2(real(G_DEPTH))))-1+2 downto 2),
                di   => ram_di(15 downto 8),
                do   => ram_1_do
            );

        ram_2_inst : entity work.rams_sp_wf
            generic map (
                G_DEPTH     => G_DEPTH,
                G_RAM_INIT  => C_RAM_2_INIT
            )
            port map (
                clk  => clk,
                we   => ram_2_we,
                en   => '1',
                addr => ram_addr(integer(ceil(log2(real(G_DEPTH))))-1+2 downto 2),
                di   => ram_di(23 downto 16),
                do   => ram_2_do
            );

        ram_3_inst : entity work.rams_sp_wf
            generic map (
                G_DEPTH     => G_DEPTH,
                G_RAM_INIT  => C_RAM_3_INIT
            )
            port map (
                clk  => clk,
                we   => ram_3_we,
                en   => '1',
                addr => ram_addr(integer(ceil(log2(real(G_DEPTH))))-1+2 downto 2),
                di   => ram_di(31 downto 24),
                do   => ram_3_do
            );

            
        -- Output data mux
        rdata_s <= ram_3_do & ram_2_do & ram_1_do & ram_0_do;

    end generate;

    process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                bvalid_s <= '0';
                rvalid_s <= '0';
            else
                -- Write response logic
                if (mem_axi_awvalid = '1' and mem_axi_wvalid = '1' and bvalid_s = '0') then
                    bvalid_s <= '1';
                elsif (bvalid_s = '1' and mem_axi_bready = '1') then
                    bvalid_s <= '0';
                end if;

                -- Read response logic
                if (mem_axi_arvalid = '1' and rvalid_s = '0') then
                    rvalid_s <= '1';
                elsif (rvalid_s = '1' and mem_axi_rready = '1') then
                    rvalid_s <= '0';
                end if;
            end if;
        end if;
    end process;

    -- AXI ready/valid logic (same as before)
    mem_axi_awready <= '1' when (mem_axi_awvalid = '1' and bvalid_s = '0') else '0';
    mem_axi_wready  <= '1' when (mem_axi_wvalid  = '1' and bvalid_s = '0') else '0';
    mem_axi_arready <= '1' when (mem_axi_arvalid = '1' and rvalid_s = '0') else '0';

    -- AXI response signals
    mem_axi_bvalid <= bvalid_s;
    mem_axi_rvalid <= rvalid_s;
    mem_axi_rdata  <= rdata_s;

end architecture;