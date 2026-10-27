library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_uart is
    generic (
        USE_ASYNC_RESET    : boolean   := TRUE;
        USE_SYNC_RESET     : boolean   := TRUE;
        ASYNC_RESET_ACTIVE : std_logic := '1';
        SYNC_RESET_ACTIVE  : std_logic := '1';
        G_SYS_FREQ : natural := 50_000_000;
        G_BAUDRATE : natural := 115200;
        G_TX_DEPTH : natural := 16;
        G_RX_DEPTH : natural := 16;
        G_DEBUG_CONSOLE : boolean := false
    );
    port (
        ACLK    : in std_logic;
        async_reset : in std_logic;
        sync_reset  : in std_logic;
        AWADDR  : in std_logic_vector(31 downto 0);
        AWVALID : in std_logic;
        AWREADY : out std_logic;
        WDATA   : in std_logic_vector(31 downto 0);
        WSTRB   : in std_logic_vector(3 downto 0);
        WVALID  : in std_logic;
        WREADY  : out std_logic;
        BRESP   : out std_logic_vector(1 downto 0);
        BVALID  : out std_logic;
        BREADY  : in std_logic;
        ARADDR  : in std_logic_vector(31 downto 0);
        ARVALID : in std_logic;
        ARREADY : out std_logic;
        RDATA   : out std_logic_vector(31 downto 0);
        RRESP   : out std_logic_vector(1 downto 0);
        RVALID  : out std_logic;
        RREADY  : in std_logic;
        uart_tx : out std_logic;
        uart_rx : in std_logic
    );
end entity;

architecture rtl of axi_uart is
    function clog2(n : natural) return natural is
        variable r : natural := 0;
        variable v : natural := n - 1;
    begin
        while v > 0 loop
            r := r + 1;
            v := v / 2;
        end loop;
        return r;
    end function;

    constant C_TX_LW : natural := clog2(G_TX_DEPTH + 1);
    constant C_RX_LW : natural := clog2(G_RX_DEPTH + 1);
    constant C_UART_DIV : integer := integer((G_SYS_FREQ + G_BAUDRATE * 4) / (G_BAUDRATE * 8));
    constant C_ADDR_TX_DATA  : std_logic_vector(31 downto 0) := x"00000000";
    constant C_ADDR_RX_DATA  : std_logic_vector(31 downto 0) := x"00000004";
    constant C_ADDR_TX_LEVEL : std_logic_vector(31 downto 0) := x"00000008";
    constant C_ADDR_RX_LEVEL : std_logic_vector(31 downto 0) := x"0000000C";
    constant C_ADDR_RESET    : std_logic_vector(31 downto 0) := x"00000010";

    type wr_state_t is (WR_COLLECT, WR_RESPONSE);
    type rd_state_t is (RD_IDLE, RD_RESPONSE);
    signal wr_state : wr_state_t := WR_COLLECT;
    signal rd_state : rd_state_t := RD_IDLE;

    signal aw_seen, w_seen : std_logic;
    signal awaddr_hold : std_logic_vector(31 downto 0);
    signal wdata_hold : std_logic_vector(31 downto 0);
    signal wstrb_hold : std_logic_vector(3 downto 0);
    signal awready_r, wready_r, bvalid_r : std_logic;
    signal arready_r, rvalid_r : std_logic;
    signal rdata_r : std_logic_vector(31 downto 0);

    signal tx_fifo_wr_en : std_logic;
    signal tx_fifo_wr_data : std_logic_vector(7 downto 0);
    signal tx_fifo_rd_data : std_logic_vector(7 downto 0);
    signal tx_fifo_rd_ready : std_logic;
    signal tx_fifo_rd_valid : std_logic;
    signal tx_fifo_empty, tx_fifo_full : std_logic;
    signal tx_fifo_wr_ready : std_logic;
    signal tx_fifo_level_vec : std_logic_vector(C_TX_LW-1 downto 0);
    signal tx_axis_data : std_logic_vector(7 downto 0);
    signal tx_axis_valid : std_logic;
    signal tx_axis_ready : std_logic;

    signal rx_fifo_wr_data : std_logic_vector(7 downto 0);
    signal rx_fifo_rd_data : std_logic_vector(7 downto 0);
    signal rx_fifo_rd_ready : std_logic;
    signal rx_fifo_empty, rx_fifo_full : std_logic;
    signal rx_fifo_rd_valid : std_logic;
    signal rx_fifo_level_vec : std_logic_vector(C_RX_LW-1 downto 0);
    signal rx_axis_valid, rx_axis_ready : std_logic;
    signal fifo_reset_pulse : std_logic;
    signal core_resetn : std_logic;
begin
    assert G_SYS_FREQ > 0 and G_BAUDRATE > 0 and C_UART_DIV >= 1
        report "Invalid UART frequency / baudrate" severity failure;

    core_resetn <= '0' when (USE_ASYNC_RESET and async_reset = ASYNC_RESET_ACTIVE) or
                           (USE_SYNC_RESET and sync_reset = SYNC_RESET_ACTIVE) or
                           fifo_reset_pulse = '1' else '1';
    AWREADY <= awready_r;
    WREADY <= wready_r;
    BVALID <= bvalid_r;
    BRESP <= "00";
    ARREADY <= arready_r;
    RVALID <= rvalid_r;
    RRESP <= "00";
    RDATA <= rdata_r;

    -- One synchronous controller for the AXI-Lite channels and TX FIFO/UART.
    process (ACLK, async_reset) is
        variable have_aw : boolean;
        variable have_w : boolean;
        variable addr_v : std_logic_vector(31 downto 0);
        variable data_v : std_logic_vector(31 downto 0);
        variable strb_v : std_logic_vector(3 downto 0);
        variable read_v : std_logic_vector(31 downto 0);
    begin
        if ((async_reset = ASYNC_RESET_ACTIVE) and (USE_ASYNC_RESET = true)) then
            wr_state <= WR_COLLECT;
            rd_state <= RD_IDLE;
            aw_seen <= '0';
            w_seen <= '0';
            awready_r <= '0';
            wready_r <= '0';
            bvalid_r <= '0';
            arready_r <= '0';
            rvalid_r <= '0';
            rdata_r <= (others => '0');
            tx_fifo_wr_en <= '0';
            tx_fifo_wr_data <= (others => '0');
            rx_fifo_rd_ready <= '0';
            fifo_reset_pulse <= '0';
            awaddr_hold <= (others => '0');
            wdata_hold <= (others => '0');
            wstrb_hold <= (others => '0');
        elsif rising_edge(ACLK) then
            if ((sync_reset = SYNC_RESET_ACTIVE) and (USE_SYNC_RESET = true)) then
                wr_state <= WR_COLLECT;
                rd_state <= RD_IDLE;
                aw_seen <= '0';
                w_seen <= '0';
                awready_r <= '0';
                wready_r <= '0';
                bvalid_r <= '0';
                arready_r <= '0';
                rvalid_r <= '0';
                rdata_r <= (others => '0');
                tx_fifo_wr_en <= '0';
                tx_fifo_wr_data <= (others => '0');
                rx_fifo_rd_ready <= '0';
                fifo_reset_pulse <= '0';
                awaddr_hold <= (others => '0');
                wdata_hold <= (others => '0');
                wstrb_hold <= (others => '0');
            elsif fifo_reset_pulse = '1' then
                wr_state <= WR_COLLECT;
                rd_state <= RD_IDLE;
                aw_seen <= '0';
                w_seen <= '0';
                awready_r <= '0';
                wready_r <= '0';
                bvalid_r <= '0';
                arready_r <= '0';
                rvalid_r <= '0';
                rdata_r <= (others => '0');
                tx_fifo_wr_en <= '0';
                tx_fifo_wr_data <= (others => '0');
                rx_fifo_rd_ready <= '0';
                fifo_reset_pulse <= '0';
                awaddr_hold <= (others => '0');
                wdata_hold <= (others => '0');
                wstrb_hold <= (others => '0');
            else
                tx_fifo_wr_en <= '0';
                rx_fifo_rd_ready <= '0';
                fifo_reset_pulse <= '0';

                -- AXI-Lite write: capture AW and W independently, respond once.
                case wr_state is
                    when WR_COLLECT =>
                        if aw_seen = '0' then awready_r <= '1'; else awready_r <= '0'; end if;
                        if w_seen = '0' then wready_r <= '1'; else wready_r <= '0'; end if;
                        have_aw := (aw_seen = '1');
                        have_w := (w_seen = '1');
                        addr_v := awaddr_hold;
                        data_v := wdata_hold;
                        strb_v := wstrb_hold;
                        if AWVALID = '1' and awready_r = '1' then
                            addr_v := AWADDR;
                            awaddr_hold <= AWADDR;
                            aw_seen <= '1';
                            have_aw := true;
                            awready_r <= '0';
                        end if;
                        if WVALID = '1' and wready_r = '1' then
                            data_v := WDATA;
                            strb_v := WSTRB;
                            wdata_hold <= WDATA;
                            wstrb_hold <= WSTRB;
                            w_seen <= '1';
                            have_w := true;
                            wready_r <= '0';
                        end if;
                        if have_aw and have_w then
                            -- Never acknowledge a TX write that cannot fit.
                            if addr_v /= C_ADDR_TX_DATA or strb_v(0) = '0' or tx_fifo_wr_ready = '1' then
                                if addr_v = C_ADDR_TX_DATA and strb_v(0) = '1' then
                                    tx_fifo_wr_data <= data_v(7 downto 0);
                                    tx_fifo_wr_en <= '1';
                                elsif addr_v = C_ADDR_RESET then
                                    fifo_reset_pulse <= '1';
                                end if;
                                aw_seen <= '0';
                                w_seen <= '0';
                                bvalid_r <= '1';
                                wr_state <= WR_RESPONSE;
                            end if;
                        end if;
                    when WR_RESPONSE =>
                        awready_r <= '0';
                        wready_r <= '0';
                        if BREADY = '1' and bvalid_r = '1' then
                            bvalid_r <= '0';
                            wr_state <= WR_COLLECT;
                        end if;
                end case;

                -- AXI-Lite read: exactly one response per accepted address.
                case rd_state is
                    when RD_IDLE =>
                        arready_r <= '1';
                        if ARVALID = '1' and arready_r = '1' then
                            arready_r <= '0';
                            read_v := (others => '0');
                            if ARADDR = C_ADDR_RX_DATA then
                                if rx_fifo_rd_valid = '1' then
                                    read_v(7 downto 0) := rx_fifo_rd_data;
                                    rx_fifo_rd_ready <= '1';
                                end if;
                            elsif ARADDR = C_ADDR_TX_LEVEL then
                                read_v(C_TX_LW-1 downto 0) := tx_fifo_level_vec;
                            elsif ARADDR = C_ADDR_RX_LEVEL then
                                read_v(C_RX_LW-1 downto 0) := rx_fifo_level_vec;
                            elsif ARADDR = C_ADDR_TX_DATA then
                                read_v(7 downto 0) := tx_fifo_rd_data;
                            end if;
                            rdata_r <= read_v;
                            rvalid_r <= '1';
                            rd_state <= RD_RESPONSE;
                        end if;
                    when RD_RESPONSE =>
                        arready_r <= '0';
                        if RREADY = '1' and rvalid_r = '1' then
                            rvalid_r <= '0';
                            rd_state <= RD_IDLE;
                        end if;
                end case;

            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- TX FIFO -> UART AXI-STREAM
    ---------------------------------------------------------------------------

    tx_axis_data     <= tx_fifo_rd_data;
    tx_axis_valid    <= tx_fifo_rd_valid;
    tx_fifo_rd_ready <= tx_axis_ready;

    tx_fifo_inst : entity work.axi_fifo
        generic map (
            USE_ASYNC_RESET    => USE_ASYNC_RESET,
            USE_SYNC_RESET     => USE_SYNC_RESET,
            ASYNC_RESET_ACTIVE => ASYNC_RESET_ACTIVE,
            SYNC_RESET_ACTIVE  => SYNC_RESET_ACTIVE,
            DATA_WIDTH => 8, DEPTH => G_TX_DEPTH)
        port map (
            soft_reset => fifo_reset_pulse,
            clk => ACLK,
            async_reset => async_reset,
            sync_reset => sync_reset,
            s_axis_tdata => tx_fifo_wr_data,
            s_axis_tvalid => tx_fifo_wr_en,
            s_axis_tready => tx_fifo_wr_ready,
            m_axis_tdata => tx_fifo_rd_data,
            m_axis_tvalid => tx_fifo_rd_valid,
            m_axis_tready => tx_fifo_rd_ready,
            fifo_full => tx_fifo_full,
            fifo_empty => tx_fifo_empty,
            fifo_level => tx_fifo_level_vec
        );

    -- RX UART -> FIFO uses AXI-Stream handshake.
    -- FIFO -> AXI-Lite read checks m_axis_tvalid before requesting a pop.
    rx_fifo_inst : entity work.axi_fifo
        generic map (
            USE_ASYNC_RESET    => USE_ASYNC_RESET,
            USE_SYNC_RESET     => USE_SYNC_RESET,
            ASYNC_RESET_ACTIVE => ASYNC_RESET_ACTIVE,
            SYNC_RESET_ACTIVE  => SYNC_RESET_ACTIVE,
            DATA_WIDTH => 8, DEPTH => G_RX_DEPTH)
        port map (
            soft_reset => fifo_reset_pulse,
            clk => ACLK,
            async_reset => async_reset,
            sync_reset => sync_reset,
            s_axis_tdata => rx_fifo_wr_data,
            s_axis_tvalid => rx_axis_valid,
            s_axis_tready => rx_axis_ready,
            m_axis_tdata => rx_fifo_rd_data,
            m_axis_tvalid => rx_fifo_rd_valid,
            m_axis_tready => rx_fifo_rd_ready,
            fifo_full => rx_fifo_full,
            fifo_empty => rx_fifo_empty,
            fifo_level => rx_fifo_level_vec
        );

    uart_inst : entity work.uart
        generic map (
            USE_ASYNC_RESET    => USE_ASYNC_RESET,
            USE_SYNC_RESET     => USE_SYNC_RESET,
            ASYNC_RESET_ACTIVE => ASYNC_RESET_ACTIVE,
            SYNC_RESET_ACTIVE  => SYNC_RESET_ACTIVE,
            uart_clock_divider => C_UART_DIV
        )
        port map (
            soft_reset => fifo_reset_pulse,
            clock => ACLK,
            async_reset => async_reset,
            sync_reset => sync_reset,

            s_axis_tdata => tx_axis_data,
            s_axis_tvalid => tx_axis_valid,
            s_axis_tready => tx_axis_ready,
            m_axis_tdata => rx_fifo_wr_data,
            m_axis_tvalid => rx_axis_valid,
            m_axis_tready => rx_axis_ready,
            tx_en => open,
            txd => uart_tx,
            rxd => uart_rx
        );

    ---------------------------------------------------------------------------
    -- DEBUG CONSOLE : UART TX
    ---------------------------------------------------------------------------
    -- Displays each transmitted UART byte in ASCII and HEX.
    -- Triggered only on a valid AXI-Stream handshake.
    -- Simulation only.
    ---------------------------------------------------------------------------

    gen_debug_console : if G_DEBUG_CONSOLE generate

        -- synthesis translate_off

    debug_tx_fifo_in_pr : process(ACLK)
        variable v_byte  : integer;
        variable v_ascii : character;
    begin
        if rising_edge(ACLK) then

            if core_resetn = '1' then

                if tx_fifo_wr_en = '1' and tx_fifo_wr_ready = '1' then

                    v_byte := to_integer(unsigned(tx_fifo_wr_data));

                    if v_byte >= 32 and v_byte <= 126 then
                        v_ascii := character'val(v_byte);
                    else
                        v_ascii := '.';
                    end if;

                    report "FIFO TX IN | ASCII: '" & v_ascii &
                           "' | HEX: 0x" & to_hstring(tx_fifo_wr_data)
                           severity note;

                end if;

            end if;

        end if;
    end process;


    debug_tx_fifo_out_pr : process(ACLK)
        variable v_byte  : integer;
        variable v_ascii : character;
    begin
        if rising_edge(ACLK) then

            if core_resetn = '1' then

                if tx_fifo_rd_valid = '1' and
                   tx_fifo_rd_ready = '1' then

                    v_byte := to_integer(unsigned(tx_fifo_rd_data));

                    if v_byte >= 32 and v_byte <= 126 then
                        v_ascii := character'val(v_byte);
                    else
                        v_ascii := '.';
                    end if;

                    report "FIFO TX OUT | ASCII: '" & v_ascii &
                           "' | HEX: 0x" & to_hstring(tx_fifo_rd_data)
                           severity note;

                end if;

            end if;

        end if;
    end process;

     debug_uart_tx_pr : process(ACLK)
         variable v_byte  : integer;
         variable v_ascii : character;
     begin
         if rising_edge(ACLK) then
             if core_resetn = '1' then
                 if tx_axis_valid = '1' and tx_axis_ready = '1' then
                     v_byte := to_integer(unsigned(tx_axis_data));
                     -- Printable ASCII characters (32 to 126)
                     if v_byte >= 32 and v_byte <= 126 then
                         v_ascii := character'val(v_byte);
                     else
                         v_ascii := '.';
                     end if;
                     report "UART TX | ASCII: '" & v_ascii &
                            "' | HEX: 0x" & to_hstring(tx_axis_data)
                            severity note;
                 end if;
             end if;
         end if;
     end process;
        -- synthesis translate_on

    end generate gen_debug_console;

end architecture;
