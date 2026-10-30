-- SDR SDRAM controller, IS42S16400-class (4 banks x 4096 rows x 256 columns x 16 bits)
-- VHDL-2008. 100 MHz SDRAM clock, same rising edge as i_clk.
-- BL=2, sequential, CL=3, closed page, auto-precharge, 32-bit aligned requests.
-- IMPORTANT: Board-level timing must be closed (DQ input/output delays and SDRAM clock phase).
-- IMPORTANT: Parameters below are conservative 100 MHz examples, not a substitute
-- for checking the exact SDRAM part/speed grade and temperature range.
-- Interface: request held high until a single-cycle rsp_valid; requester must drop
-- req_valid before issuing another request. Controller does not pipeline requests.
-- Reset restarts SDRAM initialization; memory contents are not reset.
-- With both reset generics false, power-up behavior is undefined until initialized.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram_controller is
    generic (
        G_USE_ASYNC_RESET      : boolean   := true;
        G_USE_SYNC_RESET       : boolean   := true;
        G_ASYNC_RESET_ACTIVE   : std_logic := '1';
        G_SYNC_RESET_ACTIVE    : std_logic := '1';
        G_POWERUP_CYCLES       : positive  := 20000; -- 200 us @ 100 MHz
        G_T_RP                 : positive  := 3;
        G_T_RCD                : positive  := 3;
        G_T_RFC                : positive  := 8;
        G_T_MRD                : positive  := 2;
        G_T_RAS                : positive  := 5;
        G_T_RC                 : positive  := 8;
        G_T_WR                 : positive  := 2;
        G_T_RTP                : positive  := 2;
        G_T_REFI               : positive  := 1500  -- 15 us; 4096 refresh/64 ms
    );
    port (
        i_clk         : in  std_logic;
        i_async_reset : in  std_logic;
        i_sync_reset  : in  std_logic;
        i_req_valid   : in  std_logic;
        i_req_write   : in  std_logic;
        i_req_addr    : in  std_logic_vector(22 downto 0);
        i_req_wdata   : in  std_logic_vector(31 downto 0);
        i_req_wstrb   : in  std_logic_vector(3 downto 0);
        o_rsp_valid   : out std_logic;
        o_rsp_rdata   : out std_logic_vector(31 downto 0);
        o_ready       : out std_logic;
        o_sdram_cke   : out std_logic;
        o_sdram_cs_n  : out std_logic;
        o_sdram_ras_n : out std_logic;
        o_sdram_cas_n : out std_logic;
        o_sdram_we_n  : out std_logic;
        o_sdram_ba    : out std_logic_vector(1 downto 0);
        o_sdram_addr  : out std_logic_vector(11 downto 0);
        o_sdram_dqm   : out std_logic_vector(1 downto 0);
        io_sdram_dq   : inout std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of sdram_controller is
    -- Commands {CS#,RAS#,CAS#,WE#}; CS# remains asserted during NOP.
    constant C_NOP  : std_logic_vector(3 downto 0) := "0111";
    constant C_ACT  : std_logic_vector(3 downto 0) := "0011";
    constant C_READ : std_logic_vector(3 downto 0) := "0101";
    constant C_WR   : std_logic_vector(3 downto 0) := "0100";
    constant C_PRE  : std_logic_vector(3 downto 0) := "0010";
    constant C_REF  : std_logic_vector(3 downto 0) := "0001";
    constant C_MRS  : std_logic_vector(3 downto 0) := "0000";
    -- A[2:0]=001 (BL2), A3=0 sequential, A[6:4]=011 (CL3), A9=0 burst write.
    constant C_MODE : std_logic_vector(11 downto 0) := x"031";

    type t_state is (
        ST_POWERUP, ST_INIT_PRE, ST_INIT_TRP, ST_INIT_REF1,
        ST_INIT_RFC1, ST_INIT_REF2, ST_INIT_RFC2, ST_INIT_MRS,
        ST_INIT_MRD, ST_IDLE, ST_ACT, ST_TRCD, ST_RW,
        ST_WRITE_SECOND, ST_READ_WAIT, ST_READ_FIRST, ST_READ_SECOND,
        ST_CLOSE_WAIT, ST_REFRESH, ST_REFRESH_WAIT, ST_RESPONSE, ST_RELEASE
    );
    type t_regs is record
        state        : t_state;
        delay_count  : natural range 0 to G_POWERUP_CYCLES + 32;
        refresh_cnt  : natural range 0 to G_T_REFI;
        refresh_due  : std_logic;
        req_write    : std_logic;
        req_addr     : std_logic_vector(22 downto 0);
        req_wdata    : std_logic_vector(31 downto 0);
        req_wstrb    : std_logic_vector(3 downto 0);
        read_data    : std_logic_vector(31 downto 0);
        rsp_valid    : std_logic;
    end record;
    constant C_RESET : t_regs := (
        state => ST_POWERUP, delay_count => G_POWERUP_CYCLES - 1,
        refresh_cnt => 0, refresh_due => '0', req_write => '0',
        req_addr => (others => '0'), req_wdata => (others => '0'),
        req_wstrb => (others => '0'), read_data => (others => '0'),
        rsp_valid => '0'
    );
    signal r, n : t_regs;
    signal cmd_i : std_logic_vector(3 downto 0);
    signal addr_i : std_logic_vector(11 downto 0);
    signal ba_i : std_logic_vector(1 downto 0);
    signal dqm_i : std_logic_vector(1 downto 0);
    signal dq_out_i : std_logic_vector(15 downto 0);
    signal dq_oe_i : std_logic;
    signal dq_in_i : std_logic_vector(15 downto 0);
    signal ready_i : std_logic;
    -- Conservative post-access recovery time: covers tRAS/tRP/tWR/tRTP
    -- and row-cycle requirements without tracking bank-specific timing.
    constant C_CLOSE : positive := G_T_RC + G_T_RP + G_T_WR + 4;
begin

    o_sdram_cke   <= '1';
    o_sdram_cs_n  <= cmd_i(3);
    o_sdram_ras_n <= cmd_i(2);
    o_sdram_cas_n <= cmd_i(1);
    o_sdram_we_n  <= cmd_i(0);
    o_sdram_addr  <= addr_i;
    o_sdram_ba    <= ba_i;
    o_sdram_dqm   <= dqm_i;
    io_sdram_dq   <= dq_out_i when dq_oe_i = '1' else (others => 'Z');
    dq_in_i       <= io_sdram_dq;
    o_rsp_valid   <= r.rsp_valid;
    o_rsp_rdata   <= r.read_data;
    ready_i       <= '1' when r.state = ST_IDLE else '0';
    o_ready       <= ready_i;

    process(
        r,
        i_req_valid,
        i_req_write,
        i_req_addr,
        i_req_wdata,
        i_req_wstrb,
        dq_in_i
    )
        variable v : t_regs;
        variable a : std_logic_vector(11 downto 0);
    begin
        v := r;
        cmd_i <= C_NOP;
        addr_i <= (others => '0');
        ba_i <= (others => '0');
        dqm_i <= "11";
        dq_out_i <= (others => '0');
        dq_oe_i <= '0';
        v.rsp_valid := '0';

        -- Refresh timer runs after initialization; pending refresh is serviced
        -- at an idle boundary. Requests are bounded by one closed-page access.
        if r.state = ST_IDLE or r.state = ST_ACT or r.state = ST_TRCD or
           r.state = ST_RW or r.state = ST_WRITE_SECOND or
           r.state = ST_READ_WAIT or r.state = ST_READ_FIRST or
           r.state = ST_READ_SECOND or r.state = ST_CLOSE_WAIT or
           r.state = ST_REFRESH or r.state = ST_REFRESH_WAIT or
           r.state = ST_RESPONSE or r.state = ST_RELEASE then
            if r.refresh_cnt = G_T_REFI - 1 then
                v.refresh_cnt := 0;
                v.refresh_due := '1';
            else
                v.refresh_cnt := r.refresh_cnt + 1;
            end if;
        end if;

        case r.state is
            when ST_POWERUP =>
                if r.delay_count = 0 then v.state := ST_INIT_PRE;
                else v.delay_count := r.delay_count - 1; end if;
            when ST_INIT_PRE =>
                cmd_i <= C_PRE;
                addr_i(10) <= '1'; -- precharge all banks
                v.delay_count := G_T_RP - 1;
                v.state := ST_INIT_TRP;
            when ST_INIT_TRP =>
                if r.delay_count = 0 then v.state := ST_INIT_REF1;
                else v.delay_count := r.delay_count - 1; end if;
            when ST_INIT_REF1 =>
                cmd_i <= C_REF;
                v.delay_count := G_T_RFC - 1;
                v.state := ST_INIT_RFC1;
            when ST_INIT_RFC1 =>
                if r.delay_count = 0 then v.state := ST_INIT_REF2;
                else v.delay_count := r.delay_count - 1; end if;
            when ST_INIT_REF2 =>
                cmd_i <= C_REF;
                v.delay_count := G_T_RFC - 1;
                v.state := ST_INIT_RFC2;
            when ST_INIT_RFC2 =>
                if r.delay_count = 0 then v.state := ST_INIT_MRS;
                else v.delay_count := r.delay_count - 1; end if;
            when ST_INIT_MRS =>
                cmd_i <= C_MRS;
                addr_i <= C_MODE;
                v.delay_count := G_T_MRD - 1;
                v.state := ST_INIT_MRD;
            when ST_INIT_MRD =>
                if r.delay_count = 0 then
                    v.refresh_cnt := 0;
                    v.refresh_due := '0';
                    v.state := ST_IDLE;
                else v.delay_count := r.delay_count - 1; end if;
            when ST_IDLE =>
                if r.refresh_due = '1' then
                    v.state := ST_REFRESH;
                elsif i_req_valid = '1' then
                    v.req_write := i_req_write;
                    v.req_addr := i_req_addr;
                    v.req_wdata := i_req_wdata;
                    v.req_wstrb := i_req_wstrb;
                    v.state := ST_ACT;
                end if;
            when ST_ACT =>
                cmd_i <= C_ACT;
                ba_i <= r.req_addr(22 downto 21);
                addr_i <= r.req_addr(20 downto 9);
                v.delay_count := G_T_RCD - 1;
                v.state := ST_TRCD;
            when ST_TRCD =>
                if r.delay_count = 0 then v.state := ST_RW;
                else v.delay_count := r.delay_count - 1; end if;
            when ST_RW =>
                ba_i <= r.req_addr(22 downto 21);
                a := (others => '0');
                a(7 downto 1) := r.req_addr(8 downto 2);
                a(10) := '1'; -- auto-precharge
                addr_i <= a;
                if r.req_write = '1' then
                    cmd_i <= C_WR;
                    dq_out_i <= r.req_wdata(15 downto 0);
                    dqm_i <= not r.req_wstrb(1 downto 0);
                    dq_oe_i <= '1';
                    v.state := ST_WRITE_SECOND;
                else
                    cmd_i <= C_READ;
                    v.delay_count := 1; -- CL=3: first capture at 3rd rising edge after READ
                    v.state := ST_READ_WAIT;
                end if;
            when ST_WRITE_SECOND =>
                dq_out_i <= r.req_wdata(31 downto 16);
                dqm_i <= not r.req_wstrb(3 downto 2);
                dq_oe_i <= '1';
                v.delay_count := C_CLOSE - 1;
                v.state := ST_CLOSE_WAIT;
            when ST_READ_WAIT =>
                if r.delay_count = 0 then v.state := ST_READ_FIRST;
                else v.delay_count := r.delay_count - 1; end if;
            when ST_READ_FIRST =>
                v.read_data(15 downto 0) := dq_in_i;
                v.state := ST_READ_SECOND;
            when ST_READ_SECOND =>
                v.read_data(31 downto 16) := dq_in_i;
                v.delay_count := C_CLOSE - 1;
                v.state := ST_CLOSE_WAIT;
            when ST_CLOSE_WAIT =>
                if r.delay_count = 0 then v.state := ST_RESPONSE;
                else v.delay_count := r.delay_count - 1; end if;
            when ST_RESPONSE =>
                v.rsp_valid := '1';
                v.state := ST_RELEASE;
            when ST_RELEASE =>
                if i_req_valid = '0' then v.state := ST_IDLE; end if;
            when ST_REFRESH =>
                cmd_i <= C_REF;
                v.refresh_due := '0';
                v.delay_count := G_T_RFC - 1;
                v.state := ST_REFRESH_WAIT;
            when ST_REFRESH_WAIT =>
                if r.delay_count = 0 then v.state := ST_IDLE;
                else v.delay_count := r.delay_count - 1; end if;
        end case;
        n <= v;
    end process;

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
