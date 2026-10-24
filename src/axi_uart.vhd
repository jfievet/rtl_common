library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_uart is
    generic (
        G_SYS_FREQ  : natural := 50_000_000;
        G_BAUDRATE  : natural := 115200;
        G_TX_DEPTH  : natural := 16;
        G_RX_DEPTH  : natural := 16
    );
    port (
        ACLK    : in  std_logic;
        ARESETn : in  std_logic;

        AWADDR  : in  std_logic_vector(31 downto 0);
        AWVALID : in  std_logic;
        AWREADY : out std_logic;

        WDATA   : in  std_logic_vector(31 downto 0);
        WSTRB   : in  std_logic_vector(3 downto 0);
        WVALID  : in  std_logic;
        WREADY  : out std_logic;

        BRESP   : out std_logic_vector(1 downto 0);
        BVALID  : out std_logic;
        BREADY  : in  std_logic;

        ARADDR  : in  std_logic_vector(31 downto 0);
        ARVALID : in  std_logic;
        ARREADY : out std_logic;

        RDATA   : out std_logic_vector(31 downto 0);
        RRESP   : out std_logic_vector(1 downto 0);
        RVALID  : out std_logic;
        RREADY  : in  std_logic;

        uart_tx : out std_logic;
        uart_rx : in  std_logic
    );
end entity;

architecture rtl of axi_uart is

    function clog2(n : natural) return natural is
        variable r : natural := 0;
        variable v : natural := n-1;
    begin
        while v > 0 loop
            r := r + 1;
            v := v / 2;
        end loop;
        return r;
    end function;

    constant C_TX_LW : natural := clog2(G_TX_DEPTH + 1);
    constant C_RX_LW : natural := clog2(G_RX_DEPTH + 1);

    constant C_ADDR_TX_DATA  : std_logic_vector(31 downto 0) := x"00000000";
    constant C_ADDR_RX_DATA  : std_logic_vector(31 downto 0) := x"00000004";
    constant C_ADDR_TX_LEVEL : std_logic_vector(31 downto 0) := x"00000008";
    constant C_ADDR_RX_LEVEL : std_logic_vector(31 downto 0) := x"0000000C";
    constant C_ADDR_RESET    : std_logic_vector(31 downto 0) := x"00000010";

    signal s_awready  : std_logic := '0';
    signal s_wready   : std_logic := '0';
    signal s_bvalid   : std_logic := '0';
    signal s_arready  : std_logic := '0';
    signal s_rvalid   : std_logic := '0';

    signal wr_fire    : std_logic;
    signal rd_fire    : std_logic;

    signal awaddr_reg : std_logic_vector(31 downto 0);
    signal araddr_reg : std_logic_vector(31 downto 0);

    -- TX FIFO
    signal tx_fifo_wr_en    : std_logic;
    signal tx_fifo_wr_data  : std_logic_vector(7 downto 0);
    signal tx_fifo_rd_en    : std_logic;
    signal tx_fifo_rd_data  : std_logic_vector(7 downto 0);
    signal tx_fifo_empty    : std_logic;
    signal tx_fifo_full     : std_logic;
    signal tx_fifo_level    : unsigned(C_TX_LW-1 downto 0);
    signal tx_fifo_level_vec: std_logic_vector(C_TX_LW-1 downto 0);
    signal uart_tx_valid_d1 : std_logic;

    -- RX FIFO
    signal rx_fifo_wr_en    : std_logic;
    signal rx_fifo_wr_data  : std_logic_vector(7 downto 0);
    signal rx_fifo_rd_en    : std_logic;
    signal rx_fifo_rd_data  : std_logic_vector(7 downto 0);
    signal rx_fifo_empty    : std_logic;
    signal rx_fifo_full     : std_logic;
    signal rx_fifo_level    : unsigned(C_RX_LW-1 downto 0);
    signal rx_fifo_level_vec: std_logic_vector(C_RX_LW-1 downto 0);

    -- UART core interface
    signal uart_tx_data  : std_logic_vector(7 downto 0);
    signal uart_tx_valid : std_logic;
    signal uart_tx_ready : std_logic := '1'; -- simple always-ready stub for now
    signal uart_rx_data  : std_logic_vector(7 downto 0);
    signal uart_rx_valid : std_logic;
    signal uart_rx_ready : std_logic;
    signal busy_tx_s     : std_logic;

    signal rst_sync        : std_logic;
    signal fifo_reset_pulse: std_logic := '0';

begin

    rst_sync <= not ARESETn;

    -- Write handshake
    wr_fire <= AWVALID and WVALID and s_awready and s_wready;

    process(ACLK)
    begin
        if rising_edge(ACLK) then
            if rst_sync = '1' then
                s_awready <= '0';
                s_wready  <= '0';
                s_bvalid  <= '0';
                awaddr_reg<= (others => '0');
                fifo_reset_pulse <= '0';
                tx_fifo_wr_en <= '0';
            else
                tx_fifo_wr_en <= '0';
                fifo_reset_pulse <= '0';

                if s_awready = '0' then
                    s_awready <= AWVALID;
                elsif wr_fire = '1' then
                    s_awready <= '0';
                end if;

                if s_wready = '0' then
                    s_wready <= WVALID;
                elsif wr_fire = '1' then
                    s_wready <= '0';
                end if;

                if wr_fire = '1' then
                    awaddr_reg <= AWADDR;
                    if AWADDR = C_ADDR_TX_DATA then
                        if WSTRB(0) = '1' and tx_fifo_full = '0' then
                            tx_fifo_wr_en   <= '1';
                            tx_fifo_wr_data <= WDATA(7 downto 0);
                        end if;
                    elsif AWADDR = C_ADDR_RESET then
                        fifo_reset_pulse <= '1';
                    end if;
                    s_bvalid <= '1';
                elsif s_bvalid = '1' and BREADY = '1' then
                    s_bvalid <= '0';
                end if;

            end if;
        end if;
    end process;

    AWREADY <= s_awready;
    WREADY  <= s_wready;
    BRESP   <= "00";
    BVALID  <= s_bvalid;

    -- Read handshake
    rd_fire <= ARVALID and s_arready;

    process(ACLK)
        variable rdata_v : std_logic_vector(31 downto 0);
    begin
        if rising_edge(ACLK) then
            if rst_sync = '1' then
                s_arready   <= '0';
                s_rvalid    <= '0';
                araddr_reg  <= (others => '0');
                rx_fifo_rd_en <= '0';
                RDATA       <= (others => '0');
                uart_tx_valid_d1 <= '0';
            else
                rx_fifo_rd_en <= '0';

                if s_arready = '0' then
                    s_arready <= ARVALID;
                elsif rd_fire = '1' then
                    s_arready <= '0';
                end if;

                if rd_fire = '1' then
                    araddr_reg <= ARADDR;
                    rdata_v := (others => '0');

                    if ARADDR = C_ADDR_RX_DATA then
                        if rx_fifo_empty = '0' then
                            rx_fifo_rd_en <= '1';
                            rdata_v(7 downto 0) := rx_fifo_rd_data;
                        end if;
                    elsif ARADDR = C_ADDR_TX_LEVEL then
                        rdata_v(C_TX_LW-1 downto 0) := tx_fifo_level_vec;
                    elsif ARADDR = C_ADDR_RX_LEVEL then
                        rdata_v(C_RX_LW-1 downto 0) := rx_fifo_level_vec;
                    elsif ARADDR = C_ADDR_TX_DATA then
                        rdata_v(7 downto 0) := tx_fifo_rd_data;
                    else
                        rdata_v := (others => '0');
                    end if;

                    RDATA   <= rdata_v;
                    s_rvalid <= '1';
                elsif s_rvalid = '1' and RREADY = '1' then
                    s_rvalid <= '0';
                end if;
                uart_tx_valid_d1 <= uart_tx_valid;
            end if;
        end if;
    end process;

    ARREADY <= s_arready;
    RVALID  <= s_rvalid;
    RRESP   <= "00";

    -- UART / FIFO interaction
    uart_tx_valid <= '1' when tx_fifo_empty = '0' else '0';
    tx_fifo_rd_en <= (not busy_tx_s) and (not tx_fifo_empty);
    uart_tx_data  <= tx_fifo_rd_data;

    rx_fifo_wr_en   <= uart_rx_valid and (not rx_fifo_full);
    rx_fifo_wr_data <= uart_rx_data;
    uart_rx_ready   <= not rx_fifo_full;

    -- TX FIFO
    tx_fifo_i : entity work.axi_fifo
        generic map (
            DATA_WIDTH => 8,
            DEPTH      => G_TX_DEPTH
        )
        port map (
            clk           => ACLK,
            resetn        => not (rst_sync or fifo_reset_pulse),
            s_axis_tdata  => tx_fifo_wr_data,
            s_axis_tvalid => tx_fifo_wr_en,
            s_axis_tready => open,
            m_axis_tdata  => tx_fifo_rd_data,
            m_axis_tvalid => open,
            m_axis_tready => tx_fifo_rd_en,
            fifo_full     => tx_fifo_full,
            fifo_empty    => tx_fifo_empty,
            fifo_level    => tx_fifo_level_vec
        );

    -- RX FIFO
    rx_fifo_i : entity work.axi_fifo
        generic map (
            DATA_WIDTH => 8,
            DEPTH      => G_RX_DEPTH
        )
        port map (
            clk           => ACLK,
            resetn        => not (rst_sync or fifo_reset_pulse),
            s_axis_tdata  => rx_fifo_wr_data,
            s_axis_tvalid => rx_fifo_wr_en,
            s_axis_tready => open,
            m_axis_tdata  => rx_fifo_rd_data,
            m_axis_tvalid => open,
            m_axis_tready => rx_fifo_rd_en,
            fifo_full     => rx_fifo_full,
            fifo_empty    => rx_fifo_empty,
            fifo_level    => rx_fifo_level_vec
        );

    tx_fifo_level <= unsigned(tx_fifo_level_vec);
    rx_fifo_level <= unsigned(rx_fifo_level_vec);

    -- Placeholder UART core
    uart_i : entity work.uart
        generic map (
            G_SYS_FREQ => G_SYS_FREQ,
            G_BAUD     => G_BAUDRATE
        )
        port map (
            clk         => ACLK,
            byte_in     => uart_tx_data,
            byte_en_in  => uart_tx_valid_d1,
            uart_rx     => uart_rx,
            byte_out    => uart_rx_data,
            byte_en_out => uart_rx_valid,
            busy_tx     => busy_tx_s,
            uart_tx     => uart_tx
        );

end architecture;