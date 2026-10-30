-- AXI4-Lite 32-bit to single-outstanding SDRAM request adapter
-- VHDL-2008
-- Address is a byte offset within the 8 MiB SDRAM window.
-- Only word-aligned accesses are supported; WSTRB selects individual bytes.
-- The request is held stable until rsp_valid is asserted by the controller.
-- rsp_valid is a one-cycle completion pulse while req_valid is asserted.
-- Resetting this adapter while the SDRAM controller is active requires
-- coordinated reset of the SDRAM controller as well.

library ieee;
use ieee.std_logic_1164.all;

entity axi_lite_sdram is
    generic (
        G_USE_ASYNC_RESET    : boolean   := true;
        G_USE_SYNC_RESET     : boolean   := true;
        G_ASYNC_RESET_ACTIVE : std_logic := '1';
        G_SYNC_RESET_ACTIVE  : std_logic := '1'
    );
    port (
        i_clk         : in  std_logic;
        i_async_reset : in  std_logic;
        i_sync_reset  : in  std_logic;

        -- AXI4-Lite slave, 32-bit address and data
        s_axi_awaddr  : in  std_logic_vector(31 downto 0);
        s_axi_awvalid : in  std_logic;
        s_axi_awready : out std_logic;
        s_axi_wdata   : in  std_logic_vector(31 downto 0);
        s_axi_wstrb   : in  std_logic_vector(3 downto 0);
        s_axi_wvalid  : in  std_logic;
        s_axi_wready  : out std_logic;
        s_axi_bresp   : out std_logic_vector(1 downto 0);
        s_axi_bvalid  : out std_logic;
        s_axi_bready  : in  std_logic;
        s_axi_araddr  : in  std_logic_vector(31 downto 0);
        s_axi_arvalid : in  std_logic;
        s_axi_arready : out std_logic;
        s_axi_rdata   : out std_logic_vector(31 downto 0);
        s_axi_rresp   : out std_logic_vector(1 downto 0);
        s_axi_rvalid  : out std_logic;
        s_axi_rready  : in  std_logic;

        -- SDRAM controller transaction interface
        o_req_valid   : out std_logic;
        o_req_write   : out std_logic;
        o_req_addr    : out std_logic_vector(22 downto 0);
        o_req_wdata   : out std_logic_vector(31 downto 0);
        o_req_wstrb   : out std_logic_vector(3 downto 0);
        i_rsp_valid   : in  std_logic;
        i_rsp_rdata   : in  std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of axi_lite_sdram is
    constant C_OKAY   : std_logic_vector(1 downto 0) := "00";
    constant C_SLVERR : std_logic_vector(1 downto 0) := "10";
    constant C_DECERR : std_logic_vector(1 downto 0) := "11";

    type t_state is (ST_IDLE, ST_REQUEST, ST_BRESP, ST_RRESP);
    type t_regs is record
        state      : t_state;
        aw_pending : std_logic;
        w_pending  : std_logic;
        awaddr     : std_logic_vector(31 downto 0);
        wdata      : std_logic_vector(31 downto 0);
        wstrb      : std_logic_vector(3 downto 0);
        req_write  : std_logic;
        req_addr   : std_logic_vector(22 downto 0);
        req_wdata  : std_logic_vector(31 downto 0);
        req_wstrb  : std_logic_vector(3 downto 0);
        bresp      : std_logic_vector(1 downto 0);
        rresp      : std_logic_vector(1 downto 0);
        rdata      : std_logic_vector(31 downto 0);
    end record;

    constant C_RESET : t_regs := (
        state => ST_IDLE, aw_pending => '0', w_pending => '0',
        awaddr => (others => '0'), wdata => (others => '0'),
        wstrb => (others => '0'), req_write => '0',
        req_addr => (others => '0'), req_wdata => (others => '0'),
        req_wstrb => (others => '0'), bresp => C_OKAY,
        rresp => C_OKAY, rdata => (others => '0')
    );

    signal r, n : t_regs;
    signal awready_i, wready_i, arready_i : std_logic;
    signal bvalid_i, rvalid_i, req_valid_i : std_logic;
    signal aw_take, w_take, ar_take : std_logic;
begin

    -- Write address and data may arrive independently. Reads are admitted
    -- only when no write half-transaction is buffered (write priority).
    awready_i <= '1' when r.state = ST_IDLE and r.aw_pending = '0' else '0';
    wready_i  <= '1' when r.state = ST_IDLE and r.w_pending  = '0' else '0';
    arready_i <= '1' when r.state = ST_IDLE and r.aw_pending = '0'
                    and r.w_pending = '0' and s_axi_awvalid = '0'
                    and s_axi_wvalid = '0' else '0';

    aw_take <= awready_i and s_axi_awvalid;
    w_take  <= wready_i  and s_axi_wvalid;
    ar_take <= arready_i and s_axi_arvalid;

    bvalid_i <= '1' when r.state = ST_BRESP else '0';
    rvalid_i <= '1' when r.state = ST_RRESP else '0';
    req_valid_i <= '1' when r.state = ST_REQUEST else '0';

    s_axi_awready <= awready_i;
    s_axi_wready  <= wready_i;
    s_axi_arready <= arready_i;
    s_axi_bvalid  <= bvalid_i;
    s_axi_rvalid  <= rvalid_i;
    s_axi_bresp   <= r.bresp;
    s_axi_rresp   <= r.rresp;
    s_axi_rdata   <= r.rdata;
    o_req_valid   <= req_valid_i;
    o_req_write   <= r.req_write;
    o_req_addr    <= r.req_addr;
    o_req_wdata   <= r.req_wdata;
    o_req_wstrb   <= r.req_wstrb;

    process(all)
        variable v : t_regs;
        variable addr_v : std_logic_vector(31 downto 0);
        variable data_v : std_logic_vector(31 downto 0);
        variable strb_v : std_logic_vector(3 downto 0);
        variable have_aw, have_w : std_logic;
    begin
        v := r;
        addr_v := r.awaddr;
        data_v := r.wdata;
        strb_v := r.wstrb;
        have_aw := r.aw_pending;
        have_w := r.w_pending;

        case r.state is
            when ST_IDLE =>
                if aw_take = '1' then
                    addr_v := s_axi_awaddr;
                    have_aw := '1';
                    v.awaddr := s_axi_awaddr;
                end if;
                if w_take = '1' then
                    data_v := s_axi_wdata;
                    strb_v := s_axi_wstrb;
                    have_w := '1';
                    v.wdata := s_axi_wdata;
                    v.wstrb := s_axi_wstrb;
                end if;
                v.aw_pending := have_aw;
                v.w_pending := have_w;

                if have_aw = '1' and have_w = '1' then
                    v.aw_pending := '0';
                    v.w_pending := '0';
                    v.req_write := '1';
                    v.req_addr := addr_v(22 downto 0);
                    v.req_wdata := data_v;
                    v.req_wstrb := strb_v;
                    v.bresp := C_OKAY;
                    if addr_v(31 downto 23) /= "000000000" then
                        v.bresp := C_DECERR;
                        v.state := ST_BRESP;
                    elsif addr_v(1 downto 0) /= "00" then
                        v.bresp := C_SLVERR;
                        v.state := ST_BRESP;
                    elsif strb_v = "0000" then
                        v.state := ST_BRESP;
                    else
                        v.state := ST_REQUEST;
                    end if;
                elsif ar_take = '1' then
                    v.req_write := '0';
                    v.req_addr := s_axi_araddr(22 downto 0);
                    v.req_wdata := (others => '0');
                    v.req_wstrb := (others => '0');
                    v.rresp := C_OKAY;
                    v.rdata := (others => '0');
                    if s_axi_araddr(31 downto 23) /= "000000000" then
                        v.rresp := C_DECERR;
                        v.state := ST_RRESP;
                    elsif s_axi_araddr(1 downto 0) /= "00" then
                        v.rresp := C_SLVERR;
                        v.state := ST_RRESP;
                    else
                        v.state := ST_REQUEST;
                    end if;
                end if;

            when ST_REQUEST =>
                if i_rsp_valid = '1' then
                    if r.req_write = '1' then
                        v.state := ST_BRESP;
                    else
                        v.rdata := i_rsp_rdata;
                        v.state := ST_RRESP;
                    end if;
                end if;

            when ST_BRESP =>
                if s_axi_bready = '1' then
                    v.state := ST_IDLE;
                end if;

            when ST_RRESP =>
                if s_axi_rready = '1' then
                    v.state := ST_IDLE;
                end if;
        end case;
        n <= v;
    end process;

    -- Single sequential driver for the complete register record.
    -- Generic-controlled asynchronous and synchronous resets.
    p_registers : process(i_clk, i_async_reset)
    begin
        if ((i_async_reset = G_ASYNC_RESET_ACTIVE) and
            (G_USE_ASYNC_RESET = true)) then
            r <= C_RESET;
        elsif rising_edge(i_clk) then
            if ((i_sync_reset = G_SYNC_RESET_ACTIVE) and
                (G_USE_SYNC_RESET = true)) then
                r <= C_RESET;
            else
                r <= n;
            end if;
        end if;
    end process;
end architecture;
