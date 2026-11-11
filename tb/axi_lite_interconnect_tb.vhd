library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axi_lite_interconnect_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
use vunit_lib.bus_master_pkg.all;
use vunit_lib.axi_lite_master_pkg.all;

entity axi_lite_interconnect_tb is
    generic (
        runner_cfg : string;
        G_USE_SERIAL_INTERCONNECT : boolean := true
    );
end entity;

architecture tb of axi_lite_interconnect_tb is
    constant N_S : integer := 2;
    constant N_M : integer := 4;
    constant CLK_PERIOD : time := 10 ns;
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    -- Package arrays may be wider than the number of enabled ports.
    constant BASE_ADDR : axi_32b_bus_type := (
        0 => x"00000000", 1 => x"00001000",
        2 => x"00002000", 3 => x"00003000", others => (others => '0'));
    constant END_ADDR : axi_32b_bus_type := (
        0 => x"00000FFF", 1 => x"00001FFF",
        2 => x"00002FFF", 3 => x"00003FFF", others => (others => '0'));

    signal s_awvalid, s_awready, s_wvalid, s_wready : std_logic_vector(nb_axi_lite_array-1 downto 0) := (others => '0');
    signal s_bvalid, s_bready, s_arvalid, s_arready : std_logic_vector(nb_axi_lite_array-1 downto 0) := (others => '0');
    signal s_rvalid, s_rready : std_logic_vector(nb_axi_lite_array-1 downto 0) := (others => '0');
    signal s_awaddr, s_wdata, s_araddr, s_rdata : axi_32b_bus_type := (others => (others => '0'));
    signal s_wstrb : axi_4b_bus_type := (others => (others => '0'));
    signal s_bresp, s_rresp : axi_2b_bus_type := (others => (others => '0'));

    signal m_awvalid, m_awready, m_wvalid, m_wready : std_logic_vector(nb_axi_lite_array-1 downto 0) := (others => '0');
    signal m_bvalid, m_bready, m_arvalid, m_arready : std_logic_vector(nb_axi_lite_array-1 downto 0) := (others => '0');
    signal m_rvalid, m_rready : std_logic_vector(nb_axi_lite_array-1 downto 0) := (others => '0');
    signal m_awaddr, m_wdata, m_araddr, m_rdata : axi_32b_bus_type := (others => (others => '0'));
    signal m_wstrb : axi_4b_bus_type := (others => (others => '0'));
    signal m_bresp, m_rresp : axi_2b_bus_type := (others => (others => '0'));

    type handle_array_t is array (0 to N_S-1) of bus_master_t;
    constant handles : handle_array_t := (
        0 => new_bus(data_length => 32, address_length => 32),
        1 => new_bus(data_length => 32, address_length => 32));

begin
    clk <= not clk after CLK_PERIOD/2;
    rst <= '1', '0' after 10*CLK_PERIOD;

    dut : entity work.axi_lite_interconnect(rtl)
        generic map (
            USE_ASYNC_RESET => false,
            USE_SYNC_RESET => true,
            nb_slave_ports => N_S,
            nb_master_ports => N_M,
            USE_SERIAL_INTERCONNECT => G_USE_SERIAL_INTERCONNECT,
            addr_start => BASE_ADDR,
            addr_end => END_ADDR,
            addr_offset => BASE_ADDR)
        port map (
            clock => clk, async_reset => rst, sync_reset => rst,
            s_axi_awvalid => s_awvalid, s_axi_awready => s_awready, s_axi_awaddr => s_awaddr,
            s_axi_wvalid => s_wvalid, s_axi_wready => s_wready, s_axi_wdata => s_wdata,
            s_axi_wstrb => s_wstrb, s_axi_bvalid => s_bvalid, s_axi_bready => s_bready,
            s_axi_bresp => s_bresp, s_axi_arvalid => s_arvalid, s_axi_arready => s_arready,
            s_axi_araddr => s_araddr, s_axi_rvalid => s_rvalid, s_axi_rready => s_rready,
            s_axi_rdata => s_rdata, s_axi_rresp => s_rresp,
            m_axi_awvalid => m_awvalid, m_axi_awready => m_awready, m_axi_awaddr => m_awaddr,
            m_axi_wvalid => m_wvalid, m_axi_wready => m_wready, m_axi_wdata => m_wdata,
            m_axi_wstrb => m_wstrb, m_axi_bvalid => m_bvalid, m_axi_bready => m_bready,
            m_axi_bresp => m_bresp, m_axi_arvalid => m_arvalid, m_axi_arready => m_arready,
            m_axi_araddr => m_araddr, m_axi_rvalid => m_rvalid, m_axi_rready => m_rready,
            m_axi_rdata => m_rdata, m_axi_rresp => m_rresp);

    masters : for k in 0 to N_S-1 generate
        master : entity vunit_lib.axi_lite_master
            generic map (bus_handle => handles(k))
            port map (
                aclk => clk,
                awvalid => s_awvalid(k), awready => s_awready(k), awaddr => s_awaddr(k),
                wvalid => s_wvalid(k), wready => s_wready(k), wdata => s_wdata(k),
                wstrb => s_wstrb(k), bvalid => s_bvalid(k), bready => s_bready(k),
                bresp => s_bresp(k), arvalid => s_arvalid(k), arready => s_arready(k),
                araddr => s_araddr(k), rvalid => s_rvalid(k), rready => s_rready(k),
                rdata => s_rdata(k), rresp => s_rresp(k));
    end generate;

    -- Four simple AXI-Lite slaves, one 32-bit register per destination.
    -- AW and W are accepted independently; WSTRB is honored.
    slaves : for k in 0 to N_M-1 generate
        slave_model : process
            variable reg_data : std_logic_vector(31 downto 0) := (others => '0');
            variable saved_aw : boolean := false;
            variable saved_w : boolean := false;
            variable saved_strb : std_logic_vector(3 downto 0);
            variable saved_data : std_logic_vector(31 downto 0);
            variable aw_addr : std_logic_vector(31 downto 0);
            variable read_addr : std_logic_vector(31 downto 0);
        begin
            m_awready(k) <= '0'; m_wready(k) <= '0'; m_bvalid(k) <= '0';
            m_bresp(k) <= "00"; m_arready(k) <= '0'; m_rvalid(k) <= '0';
            m_rresp(k) <= "00"; m_rdata(k) <= (others => '0');
            loop
                wait until rising_edge(clk);
                if rst = '1' then
                    reg_data := (others => '0'); saved_aw := false; saved_w := false;
                    m_awready(k) <= '0'; m_wready(k) <= '0'; m_bvalid(k) <= '0';
                    m_arready(k) <= '0'; m_rvalid(k) <= '0';
                else
                    -- Ready registered; detect handshakes using previous ready value.
                    if m_awvalid(k) = '1' and m_awready(k) = '1' then
                        saved_aw := true;
                        aw_addr := m_awaddr(k);
                    end if;
                    if m_wvalid(k) = '1' and m_wready(k) = '1' then
                        saved_w := true;
                        saved_data := m_wdata(k);
                        saved_strb := m_wstrb(k);
                    end if;
                    m_awready(k) <= '0';
                    m_wready(k) <= '0';
                    if not saved_aw and m_bvalid(k) = '0' then m_awready(k) <= '1'; end if;
                    if not saved_w and m_bvalid(k) = '0' then m_wready(k) <= '1'; end if;
                    if m_bvalid(k) = '1' and m_bready(k) = '1' then
                        m_bvalid(k) <= '0';
                    elsif saved_aw and saved_w and m_bvalid(k) = '0' then
                        for b in 0 to 3 loop
                            if saved_strb(b) = '1' then
                                reg_data(8*b+7 downto 8*b) := saved_data(8*b+7 downto 8*b);
                            end if;
                        end loop;
                        saved_aw := false; saved_w := false;
                        m_bvalid(k) <= '1';
                    end if;
                    if m_arvalid(k) = '1' and m_arready(k) = '1' then
                        read_addr := m_araddr(k);
                        m_rdata(k) <= reg_data;
                        m_rvalid(k) <= '1';
                    elsif m_rvalid(k) = '1' and m_rready(k) = '1' then
                        m_rvalid(k) <= '0';
                    end if;
                    m_arready(k) <= '0';
                    if m_rvalid(k) = '0' then m_arready(k) <= '1'; end if;
                end if;
            end loop;
        end process;
    end generate;

    test_runner : process
        variable data_read : std_logic_vector(31 downto 0);
        variable addr : std_logic_vector(31 downto 0);
        variable value : std_logic_vector(31 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);
        wait until rst = '0';
        wait until rising_edge(clk);
        if run("test_001_routing_2x4") then
            for master_id in 0 to N_S-1 loop
                for dest in 0 to N_M-1 loop
                    addr := std_logic_vector(to_unsigned(dest*4096, 32));
                    value := std_logic_vector(to_unsigned(16#10000# + master_id*256 + dest, 32));
                    write_bus(net, handles(master_id), addr, value);
                    read_bus(net, handles(master_id), addr, data_read);
                    check_equal(data_read, value,
                        "master=" & integer'image(master_id) & " dest=" & integer'image(dest));
                end loop;
            end loop;
        elsif run("test_002_repeated_accesses") then
            for i in 0 to 31 loop
                addr := std_logic_vector(to_unsigned((i mod N_M)*4096, 32));
                value := std_logic_vector(to_unsigned(i*37+5, 32));
                write_bus(net, handles(i mod N_S), addr, value);
                read_bus(net, handles(i mod N_S), addr, data_read);
                check_equal(data_read, value, "iteration=" & integer'image(i));
            end loop;
        end if;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 100 us);
end architecture;
