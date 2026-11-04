-- Any potential baud rate limitations must be verified based on the clock frequency,
-- the divider value, and the synthesis and timing results.
-- uart_clock_divider must remain between 1 and 4096.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity uart is
  generic (
    USE_ASYNC_RESET    : boolean   := TRUE;
    USE_SYNC_RESET     : boolean   := TRUE;
    ASYNC_RESET_ACTIVE : std_logic := '1';
    SYNC_RESET_ACTIVE  : std_logic := '1';
    uart_clock_divider : integer   := 108 -- round(clock / uart_bitrate*8)  ie. for 100e6/115200/8=108
  );
  port (
    clock       : in    std_logic;
    async_reset : in    std_logic;
        -- Internal software clear remains synchronous.
        soft_reset : in std_logic := '0';
    sync_reset  : in    std_logic;

    s_axis_tdata  : in    std_logic_vector(7 downto 0);
    s_axis_tvalid : in    std_logic;
    s_axis_tready : out   std_logic;

    m_axis_tdata  : out   std_logic_vector(7 downto 0);
    m_axis_tvalid : out   std_logic;
    m_axis_tready : in    std_logic;

    tx_en : out   std_logic; -- unused
    txd   : out   std_logic;
    rxd   : in    std_logic
  );
end entity uart;

architecture rtl of uart is

  type uart_tx_state_t is (
    sm_tx_idle,
    sm_tx_bit_start,
    sm_tx_data,
    sm_tx_bit_stop
  );

  type uart_rx_state_t is (
    sm_rx_idle,
    sm_rx_bit_start,
    sm_rx_data,
    sm_rx_bit_stop
  );

  signal uart_clock_tx_cnt          : unsigned(11 downto 0);
  signal uart_clock_tx_en           : std_logic;
  signal uart_clock_tx_en_pulse_cnt : unsigned(2 downto 0);
  signal uart_clock_rx_cnt          : unsigned(11 downto 0);
  signal uart_clock_rx_en           : std_logic;
  signal uart_clock_rx_en_pulse_cnt : unsigned(2 downto 0);
  signal uart_tx_sm                 : uart_tx_state_t := sm_tx_idle;
  signal uart_rx_sm                 : uart_rx_state_t := sm_rx_idle;

  signal tx_bit_index : unsigned(2 downto 0);
  signal rx_bit_index : unsigned(2 downto 0);

  signal stored_data     : std_logic_vector(7 downto 0);
  signal s_axis_tready_t : std_logic;
  signal m_axis_tvalid_t : std_logic;

begin

  s_axis_tready <= s_axis_tready_t;
  m_axis_tvalid <= m_axis_tvalid_t;

  uart_clock_pr : process (clock, async_reset) is
  begin

    if ((async_reset = ASYNC_RESET_ACTIVE) and (USE_ASYNC_RESET = true)) then
        uart_clock_tx_cnt <= (others => '0');
        uart_clock_tx_en  <= '0';
        uart_clock_rx_cnt <= (others => '0');
        uart_clock_rx_en <= '0';
    elsif rising_edge(clock) then
        if ((sync_reset = SYNC_RESET_ACTIVE) and (USE_SYNC_RESET = true)) then
            uart_clock_tx_cnt <= (others => '0');
            uart_clock_tx_en  <= '0';
            uart_clock_rx_cnt <= (others => '0');
            uart_clock_rx_en <= '0';
        elsif soft_reset = '1' then
            uart_clock_tx_cnt <= (others => '0');
            uart_clock_tx_en  <= '0';
            uart_clock_rx_cnt <= (others => '0');
            uart_clock_rx_en <= '0';
      else
        if (uart_tx_sm = sm_tx_idle) then
          uart_clock_tx_cnt <= (others => '0');
          uart_clock_tx_en  <= '0';
        else
          if (uart_clock_tx_cnt = to_unsigned(uart_clock_divider - 1, 12)) then
            uart_clock_tx_cnt <= (others => '0');
            uart_clock_tx_en  <= '1';
          else
            uart_clock_tx_cnt <= uart_clock_tx_cnt + 1;
            uart_clock_tx_en  <= '0';
          end if;
        end if;

        if (uart_rx_sm = sm_rx_idle) then
          uart_clock_rx_cnt <= (others => '0');
          uart_clock_rx_en  <= '0';
        else
          if (uart_clock_rx_cnt = to_unsigned(uart_clock_divider - 1, 12)) then
            uart_clock_rx_cnt <= (others => '0');
            uart_clock_rx_en  <= '1';
          else
            uart_clock_rx_cnt <= uart_clock_rx_cnt + 1;
            uart_clock_rx_en  <= '0';
          end if;
        end if;
      end if;
    end if;

  end process uart_clock_pr;

  uart_tx_pr : process (clock, async_reset) is
  begin

    if ((async_reset = ASYNC_RESET_ACTIVE) and (USE_ASYNC_RESET = true)) then
        txd         <= '1';
        stored_data <= (others => '0');
        uart_tx_sm <= sm_tx_idle;
        tx_bit_index <= (others => '0');
        uart_clock_tx_en_pulse_cnt <= (others => '0');
        s_axis_tready_t <= '0';
    elsif rising_edge(clock) then
        if ((sync_reset = SYNC_RESET_ACTIVE) and (USE_SYNC_RESET = true)) then
            txd         <= '1';
            stored_data <= (others => '0');
            uart_tx_sm <= sm_tx_idle;
            tx_bit_index <= (others => '0');
            uart_clock_tx_en_pulse_cnt <= (others => '0');
            s_axis_tready_t <= '0';
        elsif soft_reset = '1' then
            txd         <= '1';
            stored_data <= (others => '0');
            uart_tx_sm <= sm_tx_idle;
            tx_bit_index <= (others => '0');
            uart_clock_tx_en_pulse_cnt <= (others => '0');
            s_axis_tready_t <= '0';
      else
        -- tx sm
        case uart_tx_sm is

          when sm_tx_idle =>

            tx_bit_index <= (others => '0');
            uart_clock_tx_en_pulse_cnt <= (others => '0');
            if (s_axis_tvalid = '1' and s_axis_tready_t = '1') then
              s_axis_tready_t <= '0';
              stored_data     <= s_axis_tdata;
              uart_tx_sm      <= sm_tx_bit_start;
            else
              s_axis_tready_t <= '1';
            end if;

          when sm_tx_bit_start =>

            txd <= '0';
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 3)) then
              uart_tx_sm <= sm_tx_data;
            end if;

          when sm_tx_data =>

            txd <= stored_data(to_integer(tx_bit_index));
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 3)) then
              if (tx_bit_index = to_unsigned(7, 3)) then
                uart_tx_sm <= sm_tx_bit_stop;
              else
                tx_bit_index <= tx_bit_index + 1;
              end if;
            end if;

          when sm_tx_bit_stop =>

            txd <= '1';
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 3)) then
              uart_tx_sm <= sm_tx_idle;
              tx_bit_index <= (others => '0');
            end if;

          when others =>

            uart_tx_sm <= sm_tx_idle;

            tx_bit_index <= (others => '0');

        end case;

        -- tx subcounter
        if (uart_clock_tx_en = '1') then
          uart_clock_tx_en_pulse_cnt <= uart_clock_tx_en_pulse_cnt + 1;
        end if;
      end if;
    end if;

  end process uart_tx_pr;

  uart_rx_pr : process (clock, async_reset) is
  begin

    if ((async_reset = ASYNC_RESET_ACTIVE) and (USE_ASYNC_RESET = true)) then
        m_axis_tvalid_t <= '0';
        m_axis_tdata    <= (others => '0');
        uart_rx_sm <= sm_rx_idle;
        rx_bit_index <= (others => '0');
        uart_clock_rx_en_pulse_cnt <= (others => '0');
    elsif rising_edge(clock) then
        if ((sync_reset = SYNC_RESET_ACTIVE) and (USE_SYNC_RESET = true)) then
            m_axis_tvalid_t <= '0';
            m_axis_tdata    <= (others => '0');
            uart_rx_sm <= sm_rx_idle;
            rx_bit_index <= (others => '0');
            uart_clock_rx_en_pulse_cnt <= (others => '0');
        elsif soft_reset = '1' then
            m_axis_tvalid_t <= '0';
            m_axis_tdata    <= (others => '0');
            uart_rx_sm <= sm_rx_idle;
            rx_bit_index <= (others => '0');
            uart_clock_rx_en_pulse_cnt <= (others => '0');
      else
        -- rx sm
        case uart_rx_sm is

          when sm_rx_idle =>

            rx_bit_index <= (others => '0');
            uart_clock_rx_en_pulse_cnt <= (others => '0');
            m_axis_tvalid_t            <= '0';
            if (rxd = '0') then
              uart_rx_sm <= sm_rx_bit_start;
            else
            end if;

          when sm_rx_bit_start =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 3)) then
            -- HANDLE AN ERROR HERE TBD
            end if;
            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(7, 3)) then
              uart_rx_sm <= sm_rx_data;
            end if;

          when sm_rx_data =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 3)) then
              m_axis_tdata(to_integer(rx_bit_index)) <= rxd;
            end if;
            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(7, 3)) then
              if (rx_bit_index = to_unsigned(7, 3)) then
                uart_rx_sm <= sm_rx_bit_stop;
              else
                rx_bit_index <= rx_bit_index + 1;
              end if;
            end if;

          when sm_rx_bit_stop =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 3)) then
              -- HANDLE AN ERROR HERE TBD
              uart_rx_sm <= sm_rx_idle;
              rx_bit_index <= (others => '0');
            end if;

          -- if uart_clock_rx_en='1' and uart_clock_rx_en_pulse_cnt=to_unsigned(7,32) then
          --    uart_rx_sm <= SM_RX_IDLE;
          -- end if;
          when others =>

            uart_rx_sm <= sm_rx_idle;

            rx_bit_index <= (others => '0');

        end case;

        -- Set m_axis_tvalid_t when sampling data bit 7.
        if (uart_rx_sm = sm_rx_data and rx_bit_index = to_unsigned(7, 3) and uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 3)) then
          m_axis_tvalid_t <= '1';
        elsif (m_axis_tvalid_t = '1' and m_axis_tready = '1') then
          m_axis_tvalid_t <= '0';
        end if;

        -- rx subcounter
        if (uart_clock_rx_en = '1') then
          uart_clock_rx_en_pulse_cnt <= uart_clock_rx_en_pulse_cnt + 1;
        end if;
      end if;
    end if;

  end process uart_rx_pr;

end architecture rtl;
