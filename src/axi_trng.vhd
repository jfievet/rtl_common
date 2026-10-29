library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_trng is
    generic (
        G_SIM                  : boolean := false;
        G_ADDR_WIDTH           : positive := 32;
        G_DATA_WIDTH           : positive := 32;
        G_RO_COUNT             : positive := 8;
        G_RO_STAGES            : positive := 7;
        G_DEFAULT_ACCUM_CYCLES : positive := 1000;
        G_USE_ASYNC_RESET      : boolean := true;
        G_USE_SYNC_RESET       : boolean := true;
        G_ASYNC_RESET_ACTIVE   : std_logic := '1';
        G_SYNC_RESET_ACTIVE    : std_logic := '1'
    );
    port (
        clk           : in  std_logic;
        async_reset   : in  std_logic;
        sync_reset    : in  std_logic;
        s_axi_awvalid : in  std_logic;
        s_axi_awready : out std_logic;
        s_axi_awaddr  : in  std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
        s_axi_awprot  : in  std_logic_vector(2 downto 0);
        s_axi_wvalid  : in  std_logic;
        s_axi_wready  : out std_logic;
        s_axi_wdata   : in  std_logic_vector(31 downto 0);
        s_axi_wstrb   : in  std_logic_vector(3 downto 0);
        s_axi_bvalid  : out std_logic;
        s_axi_bready  : in  std_logic;
        s_axi_bresp   : out std_logic_vector(1 downto 0);
        s_axi_arvalid : in  std_logic;
        s_axi_arready : out std_logic;
        s_axi_araddr  : in  std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
        s_axi_arprot  : in  std_logic_vector(2 downto 0);
        s_axi_rvalid  : out std_logic;
        s_axi_rready  : in  std_logic;
        s_axi_rdata   : out std_logic_vector(31 downto 0);
        s_axi_rresp   : out std_logic_vector(1 downto 0)
    );
end entity;

architecture rtl of axi_trng is
    type t_state is (IDLE, BUSY, DONE);
    constant C_OKAY : std_logic_vector(1 downto 0) := "00";
    constant C_SLVERR : std_logic_vector(1 downto 0) := "10";
    constant C_CONTROL : unsigned(G_ADDR_WIDTH - 1 downto 0) :=
        to_unsigned(0, G_ADDR_WIDTH);
    constant C_STATUS : unsigned(G_ADDR_WIDTH - 1 downto 0) :=
        to_unsigned(4, G_ADDR_WIDTH);
    constant C_RANDOM_DATA : unsigned(G_ADDR_WIDTH - 1 downto 0) :=
        to_unsigned(8, G_ADDR_WIDTH);
    constant C_ACCUM_CYCLES : unsigned(G_ADDR_WIDTH - 1 downto 0) :=
        to_unsigned(12, G_ADDR_WIDTH);

    signal state : t_state;
    signal accum_cycles : unsigned(31 downto 0);
    signal random_data : std_logic_vector(31 downto 0);
    signal sampled_bits : std_logic_vector(G_RO_COUNT - 1 downto 0);
    signal generator_result : std_logic_vector(31 downto 0);
    signal generator_complete : std_logic;
    signal start : std_logic;
    signal clear : std_logic;
    signal reset_active : std_logic;

    signal aw_pending : std_logic;
    signal awaddr : std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
    signal w_pending : std_logic;
    signal wdata : std_logic_vector(31 downto 0);
    signal wstrb : std_logic_vector(3 downto 0);
    signal write_commit : std_logic;
    signal bvalid : std_logic;
    signal bresp : std_logic_vector(1 downto 0);
    signal rvalid : std_logic;
    signal rdata : std_logic_vector(31 downto 0);
    signal rresp : std_logic_vector(1 downto 0);

    signal s_awready : std_logic;
    signal s_wready  : std_logic;
    signal s_arready : std_logic;

begin
    assert G_DATA_WIDTH = 32
        report "Only G_DATA_WIDTH = 32 is supported" severity failure;
    assert G_ADDR_WIDTH >= 4
        report "G_ADDR_WIDTH must be at least 4" severity failure;
    assert G_RO_STAGES mod 2 = 1
        report "G_RO_STAGES must be odd" severity failure;
    assert G_ASYNC_RESET_ACTIVE = '0' or G_ASYNC_RESET_ACTIVE = '1'
        report "Invalid asynchronous reset polarity" severity failure;
    assert G_SYNC_RESET_ACTIVE = '0' or G_SYNC_RESET_ACTIVE = '1'
        report "Invalid synchronous reset polarity" severity failure;

    reset_active <= '1' when
        (G_USE_ASYNC_RESET and async_reset = G_ASYNC_RESET_ACTIVE) or
        (G_USE_SYNC_RESET and sync_reset = G_SYNC_RESET_ACTIVE) else '0';

    s_awready <= '1' when aw_pending = '0' and bvalid = '0' and
                        reset_active = '0' else '0';

    s_wready <= '1' when w_pending = '0' and bvalid = '0' and
                        reset_active = '0' else '0';

    s_arready <= '1' when rvalid = '0' and reset_active = '0' else '0';

    -- Drive AXI output ports
    s_axi_awready <= s_awready;
    s_axi_wready  <= s_wready;
    s_axi_arready <= s_arready;

    s_axi_bvalid <= bvalid;
    s_axi_bresp <= bresp;
    s_axi_rvalid <= rvalid;
    s_axi_rdata <= rdata;
    s_axi_rresp <= rresp;

    write_commit <= '1' when aw_pending = '1' and w_pending = '1' and
                             bvalid = '0' and reset_active = '0' else '0';
    clear <= '1' when write_commit = '1' and unsigned(awaddr) = C_CONTROL
                      and wstrb(0) = '1' and wdata(1) = '1' else '0';
    start <= '1' when write_commit = '1' and unsigned(awaddr) = C_CONTROL
                      and wstrb(0) = '1' and wdata(0) = '1'
                      and clear = '0' and state = IDLE else '0';

    entropy_source : entity work.trng_entropy_source
        generic map (
            G_SIM => G_SIM,
            G_RO_COUNT => G_RO_COUNT,
            G_RO_STAGES => G_RO_STAGES,
            G_USE_ASYNC_RESET => G_USE_ASYNC_RESET,
            G_USE_SYNC_RESET => G_USE_SYNC_RESET,
            G_ASYNC_RESET_ACTIVE => G_ASYNC_RESET_ACTIVE,
            G_SYNC_RESET_ACTIVE => G_SYNC_RESET_ACTIVE
        )
        port map (
            clk => clk, async_reset => async_reset, sync_reset => sync_reset,
            sampled_bits => sampled_bits
        );

    random_generator : entity work.trng_random_generator
        generic map (
            G_RO_COUNT => G_RO_COUNT,
            G_USE_ASYNC_RESET => G_USE_ASYNC_RESET,
            G_USE_SYNC_RESET => G_USE_SYNC_RESET,
            G_ASYNC_RESET_ACTIVE => G_ASYNC_RESET_ACTIVE,
            G_SYNC_RESET_ACTIVE => G_SYNC_RESET_ACTIVE
        )
        port map (
            clk => clk, async_reset => async_reset, sync_reset => sync_reset,
            start => start, clear => clear, accum_cycles => accum_cycles,
            sampled_bits => sampled_bits, result => generator_result,
            complete => generator_complete
        );

    process(clk, async_reset)
        variable merged_cycles : unsigned(31 downto 0);

        procedure reset_registers is
        begin
            state <= IDLE;
            accum_cycles <= to_unsigned(G_DEFAULT_ACCUM_CYCLES, 32);
            random_data <= (others => '0');
            aw_pending <= '0';
            awaddr <= (others => '0');
            w_pending <= '0';
            wdata <= (others => '0');
            wstrb <= (others => '0');
            bvalid <= '0';
            bresp <= C_OKAY;
            rvalid <= '0';
            rdata <= (others => '0');
            rresp <= C_OKAY;
        end procedure;
    begin
        if G_USE_ASYNC_RESET and async_reset = G_ASYNC_RESET_ACTIVE then
            reset_registers;
        elsif rising_edge(clk) then
            if G_USE_SYNC_RESET and sync_reset = G_SYNC_RESET_ACTIVE then
                reset_registers;
            else
                if s_awready = '1' and s_axi_awvalid = '1' then
                    awaddr <= s_axi_awaddr;
                    aw_pending <= '1';
                end if;
                if s_wready = '1' and s_axi_wvalid = '1' then
                    wdata <= s_axi_wdata;
                    wstrb <= s_axi_wstrb;
                    w_pending <= '1';
                end if;

                if bvalid = '1' and s_axi_bready = '1' then
                    bvalid <= '0';
                end if;

                if write_commit = '1' then
                    aw_pending <= '0';
                    w_pending <= '0';
                    bvalid <= '1';
                    bresp <= C_OKAY;

                    if unsigned(awaddr) = C_CONTROL then
                        -- Commands are decoded above and consumed on this edge.
                        null;
                    elsif unsigned(awaddr) = C_ACCUM_CYCLES then
                        merged_cycles := accum_cycles;
                        for i in 0 to 3 loop
                            if wstrb(i) = '1' then
                                merged_cycles(8 * i + 7 downto 8 * i) :=
                                    unsigned(wdata(8 * i + 7 downto 8 * i));
                            end if;
                        end loop;
                        if state /= IDLE or merged_cycles = 0 then
                            bresp <= C_SLVERR;
                        else
                            accum_cycles <= merged_cycles;
                        end if;
                    else
                        -- Includes read-only, unaligned and unmapped addresses.
                        bresp <= C_SLVERR;
                    end if;
                end if;

                if rvalid = '1' and s_axi_rready = '1' then
                    rvalid <= '0';
                end if;
                if s_arready = '1' and s_axi_arvalid = '1' then
                    rvalid <= '1';
                    rresp <= C_OKAY;
                    rdata <= (others => '0');
                    if unsigned(s_axi_araddr) = C_CONTROL then
                        null;
                    elsif unsigned(s_axi_araddr) = C_STATUS then
                        case state is
                            when IDLE => rdata <= x"00000000";
                            when BUSY => rdata <= x"00000001";
                            when DONE => rdata <= x"00000002";
                        end case;
                    elsif unsigned(s_axi_araddr) = C_RANDOM_DATA then
                        rdata <= random_data;
                    elsif unsigned(s_axi_araddr) = C_ACCUM_CYCLES then
                        rdata <= std_logic_vector(accum_cycles);
                    else
                        rresp <= C_SLVERR;
                    end if;
                end if;

                if clear = '1' then
                    state <= IDLE;
                    random_data <= (others => '0');
                elsif start = '1' then
                    state <= BUSY;
                elsif state = BUSY and generator_complete = '1' then
                    random_data <= generator_result;
                    state <= DONE;
                end if;
            end if;
        end if;
    end process;
end architecture;
