library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_gpio is
  port (
    -- AXI4-Lite clock & reset
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;

    -- AXI4-Lite write address channel
    s_axi_awaddr  : in  std_logic_vector(32-1 downto 0);
    s_axi_awprot  : in  std_logic_vector(2 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;

    -- AXI4-Lite write data channel
    s_axi_wdata   : in  std_logic_vector(32-1 downto 0);
    s_axi_wstrb   : in  std_logic_vector((32/8)-1 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;

    -- AXI4-Lite write response channel
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;

    -- AXI4-Lite read address channel
    s_axi_araddr  : in  std_logic_vector(32-1 downto 0);
    s_axi_arprot  : in  std_logic_vector(2 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;

    -- AXI4-Lite read data channel
    s_axi_rdata   : out std_logic_vector(32-1 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;

    -- GPIO
    gpio_in  : in  std_logic_vector(31 downto 0);
    gpio_out : out std_logic_vector(31 downto 0)
  );
end entity axi_gpio;

architecture rtl of axi_gpio is

  -- Address decode: 2 LSBs are byte address inside 32-bit word
  constant ADDR_LSB          : integer := 2; -- 4-byte alignment
  constant OPT_MEM_ADDR_BITS : integer := 1; -- 2 registers: 0x0, 0x4

  -- Internal AXI registers
  signal axi_awready  : std_logic;
  signal axi_wready   : std_logic;
  signal axi_bvalid   : std_logic;
  signal axi_bresp    : std_logic_vector(1 downto 0);

  signal axi_arready  : std_logic;
  signal axi_rvalid   : std_logic;
  signal axi_rresp    : std_logic_vector(1 downto 0);
  signal axi_rdata    : std_logic_vector(32-1 downto 0);

  signal awaddr_reg   : std_logic_vector(32-1 downto 0);
  signal araddr_reg   : std_logic_vector(32-1 downto 0);

  signal aw_en        : std_logic;

  -- GPIO registers
  signal reg_gpio_out : std_logic_vector(31 downto 0);

begin

  -- AXI outputs
  s_axi_awready <= axi_awready;
  s_axi_wready  <= axi_wready;
  s_axi_bvalid  <= axi_bvalid;
  s_axi_bresp   <= axi_bresp;
  s_axi_arready <= axi_arready;
  s_axi_rvalid  <= axi_rvalid;
  s_axi_rresp   <= axi_rresp;
  s_axi_rdata   <= axi_rdata;

  -- Connect GPIO out register to port
  gpio_out <= reg_gpio_out;

  ------------------------------------------------------------------------------
  -- Write address handshake
  ------------------------------------------------------------------------------
  process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        axi_awready <= '0';
        aw_en       <= '1';
      else
        if (axi_awready = '0') and (s_axi_awvalid = '1') and (s_axi_wvalid = '1') and (aw_en = '1') then
          axi_awready <= '1';
          awaddr_reg  <= s_axi_awaddr;
          aw_en       <= '0';
        elsif (s_axi_bready = '1' and axi_bvalid = '1') then
          aw_en       <= '1';
          axi_awready <= '0';
        else
          axi_awready <= '0';
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Write data handshake
  ------------------------------------------------------------------------------
  process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        axi_wready <= '0';
      else
        if (axi_wready = '0') and (s_axi_wvalid = '1') and (s_axi_awvalid = '1') and (aw_en = '1') then
          axi_wready <= '1';
        else
          axi_wready <= '0';
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Write to GPIO_OUT at address 0x0
  ------------------------------------------------------------------------------
  process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        reg_gpio_out <= (others => '0');
      else
        if (axi_awready = '1' and s_axi_awvalid = '1' and
            axi_wready  = '1' and s_axi_wvalid  = '1') then

          -- Decode 32-bit word address (0x0 and 0x4)
          case awaddr_reg(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB) is

            -- Address 0x0 : GPIO_OUT write
            when "00" =>
              -- Byte-enable support through WSTRB
              for i in 0 to 3 loop
                if s_axi_wstrb(i) = '1' then
                  reg_gpio_out(8*i+7 downto 8*i) <= s_axi_wdata(8*i+7 downto 8*i);
                end if;
              end loop;

            when others =>
              null;
          end case;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Write response channel
  ------------------------------------------------------------------------------
  process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        axi_bvalid <= '0';
        axi_bresp  <= (others => '0');
      else
        if (axi_awready = '1' and s_axi_awvalid = '1' and
            axi_wready  = '1' and s_axi_wvalid  = '1' and
            axi_bvalid  = '0') then
          axi_bvalid <= '1';
          axi_bresp  <= "00";    -- OKAY
        elsif (s_axi_bready = '1' and axi_bvalid = '1') then
          axi_bvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Read address handshake
  ------------------------------------------------------------------------------
  process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        axi_arready <= '0';
        araddr_reg  <= (others => '0');
      else
        if (axi_arready = '0' and s_axi_arvalid = '1') then
          axi_arready <= '1';
          araddr_reg  <= s_axi_araddr;
        else
          axi_arready <= '0';
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Read data channel
  ------------------------------------------------------------------------------
  process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        axi_rvalid <= '0';
        axi_rresp  <= (others => '0');
        axi_rdata  <= (others => '0');
      else
        if (axi_arready = '1' and s_axi_arvalid = '1' and axi_rvalid = '0') then
          -- Address decode for read
          case araddr_reg(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB) is
            -- 0x0: could return GPIO_OUT (optional / debug)
            when "00" =>
              axi_rdata <= reg_gpio_out;

            -- 0x4: GPIO_IN read
            when "01" =>
              axi_rdata <= gpio_in;

            when others =>
              axi_rdata <= (others => '0');
          end case;

          axi_rvalid <= '1';
          axi_rresp  <= "00";  -- OKAY

        elsif (axi_rvalid = '1' and s_axi_rready = '1') then
          axi_rvalid <= '0';
        end if;
      end if;
    end if;
  end process;

end architecture rtl;