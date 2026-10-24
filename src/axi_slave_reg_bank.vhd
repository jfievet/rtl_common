library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.axi_slave_reg_bank_pkg.all;

entity axi_slave_reg_bank is
generic (
    G_ADDR_WIDTH : positive := 32;
    G_DATA_WIDTH : positive := 32
);
    port (
        clk                     : in  std_logic;                          -- Added clock
        resetn                  : in  std_logic;                          -- Added active-low reset
        mem_axi_awvalid         : in  std_logic;
        mem_axi_awready         : out std_logic;
        mem_axi_awaddr          : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        mem_axi_awprot          : in  std_logic_vector(2 downto 0);
        mem_axi_wvalid          : in  std_logic;
        mem_axi_wready          : out std_logic;
        mem_axi_wdata           : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
        mem_axi_wstrb           : in  std_logic_vector((G_DATA_WIDTH/8)-1 downto 0);
        mem_axi_bvalid          : out std_logic;
        mem_axi_bready          : in  std_logic;
        mem_axi_arvalid         : in  std_logic;
        mem_axi_arready         : out std_logic;
        mem_axi_araddr          : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        mem_axi_arprot          : in  std_logic_vector(2 downto 0);
        mem_axi_rvalid          : out std_logic;
        mem_axi_rready          : in  std_logic;
        mem_axi_rdata           : out std_logic_vector(G_DATA_WIDTH-1 downto 0);

        register_bank_wr        : out reg_bank_t;
        register_bank_wr_en     : out std_logic_vector(C_DEPTH-1 downto 0);
        register_bank_rd        : in reg_bank_t

    );
end entity;

architecture rtl of axi_slave_reg_bank is

    signal reg_bank : reg_bank_t := (others => (others => '0'));
    signal wr_en_vec : std_logic_vector(C_DEPTH-1 downto 0) := (others => '0');
    signal bvalid_s  : std_logic := '0';
    signal rvalid_s  : std_logic := '0';
    signal rdata_s   : std_logic_vector(C_DATA_WIDTH-1 downto 0) := (others => '0');

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                bvalid_s <= '0';
                rvalid_s <= '0';
                reg_bank <= (others => (others => '0'));
                wr_en_vec <= (others => '0');
            else
                wr_en_vec <= (others => '0'); -- Default: no write

                -- Write response logic
                if (mem_axi_awvalid = '1' and mem_axi_wvalid = '1' and bvalid_s = '0') then
                    reg_bank(to_integer(unsigned(mem_axi_awaddr(G_ADDR_WIDTH-1 downto 2)))) <= mem_axi_wdata;
                    wr_en_vec(to_integer(unsigned(mem_axi_awaddr(G_ADDR_WIDTH-1 downto 2)))) <= '1';
                    bvalid_s <= '1';
                elsif (bvalid_s = '1' and mem_axi_bready = '1') then
                    bvalid_s <= '0';
                end if;

                -- Read response logic
                if (mem_axi_arvalid = '1' and rvalid_s = '0') then
                    -- Use external register_bank_rd for read data
                    rdata_s <= register_bank_rd(to_integer(unsigned(mem_axi_araddr(G_ADDR_WIDTH-1 downto 2))));
                    rvalid_s <= '1';
                elsif (rvalid_s = '1' and mem_axi_rready = '1') then
                    rvalid_s <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Connect internal signals to entity ports
    register_bank_wr    <= reg_bank;
    register_bank_wr_en <= wr_en_vec;

    -- AXI ready/valid logic
    mem_axi_awready <= '1' when (mem_axi_awvalid = '1' and bvalid_s = '0') else '0';
    mem_axi_wready  <= '1' when (mem_axi_wvalid  = '1' and bvalid_s = '0') else '0';
    mem_axi_arready <= '1' when (mem_axi_arvalid = '1' and rvalid_s = '0') else '0';

    -- AXI response signals
    mem_axi_bvalid <= bvalid_s;
    mem_axi_rvalid <= rvalid_s;
    mem_axi_rdata  <= rdata_s;

end architecture;