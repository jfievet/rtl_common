library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_lite_interconnect_1x4 is
    generic (
        G_ADDR_WIDTH  : integer := 32;
        G_DATA_WIDTH  : integer := 32;
        G_STRB_WIDTH  : integer := 4;
        G_BASE0       : std_logic_vector(32-1 downto 0) := (others => '0');
        G_LIMIT0      : std_logic_vector(32-1 downto 0) := x"00000000";
        G_BASE1       : std_logic_vector(32-1 downto 0) := x"00010000";
        G_LIMIT1      : std_logic_vector(32-1 downto 0) := x"0001FFFF";
        G_BASE2       : std_logic_vector(32-1 downto 0) := x"00020000";
        G_LIMIT2      : std_logic_vector(32-1 downto 0) := x"0002FFFF";
        G_BASE3       : std_logic_vector(32-1 downto 0) := x"00030000";
        G_LIMIT3      : std_logic_vector(32-1 downto 0) := x"0003FFFF"
    );
    port (
        clk    : in  std_logic;
        resetn : in  std_logic;

        -- Master AXI4-Lite interface (input from system master)
        M_AWADDR  : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        M_AWVALID : in  std_logic;
        M_AWREADY : out std_logic;

        M_WDATA   : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
        M_WSTRB   : in  std_logic_vector(G_STRB_WIDTH-1 downto 0);
        M_WVALID  : in  std_logic;
        M_WREADY  : out std_logic;

        M_BRESP   : out std_logic_vector(1 downto 0);
        M_BVALID  : out std_logic;
        M_BREADY  : in  std_logic;

        M_ARADDR  : in  std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        M_ARVALID : in  std_logic;
        M_ARREADY : out std_logic;

        M_RDATA   : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        M_RRESP   : out std_logic_vector(1 downto 0);
        M_RVALID  : out std_logic;
        M_RREADY  : in  std_logic;

        -- Slave 0
        S0_AWADDR  : out std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        S0_AWVALID : out std_logic;
        S0_AWREADY : in  std_logic;

        S0_WDATA   : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        S0_WSTRB   : out std_logic_vector(G_STRB_WIDTH-1 downto 0);
        S0_WVALID  : out std_logic;
        S0_WREADY  : in  std_logic;

        S0_BRESP   : in  std_logic_vector(1 downto 0);
        S0_BVALID  : in  std_logic;
        S0_BREADY  : out std_logic;

        S0_ARADDR  : out std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        S0_ARVALID : out std_logic;
        S0_ARREADY : in  std_logic;

        S0_RDATA   : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
        S0_RRESP   : in  std_logic_vector(1 downto 0);
        S0_RVALID  : in  std_logic;
        S0_RREADY  : out std_logic;

        -- Slave 1
        S1_AWADDR  : out std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        S1_AWVALID : out std_logic;
        S1_AWREADY : in  std_logic;
        S1_WDATA   : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        S1_WSTRB   : out std_logic_vector(G_STRB_WIDTH-1 downto 0);
        S1_WVALID  : out std_logic;
        S1_WREADY  : in  std_logic;
        S1_BRESP   : in  std_logic_vector(1 downto 0);
        S1_BVALID  : in  std_logic;
        S1_BREADY  : out std_logic;
        S1_ARADDR  : out std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        S1_ARVALID : out std_logic;
        S1_ARREADY : in  std_logic;
        S1_RDATA   : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
        S1_RRESP   : in  std_logic_vector(1 downto 0);
        S1_RVALID  : in  std_logic;
        S1_RREADY  : out std_logic;

        -- Slave 2
        S2_AWADDR  : out std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        S2_AWVALID : out std_logic;
        S2_AWREADY : in  std_logic;
        S2_WDATA   : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        S2_WSTRB   : out std_logic_vector(G_STRB_WIDTH-1 downto 0);
        S2_WVALID  : out std_logic;
        S2_WREADY  : in  std_logic;
        S2_BRESP   : in  std_logic_vector(1 downto 0);
        S2_BVALID  : in  std_logic;
        S2_BREADY  : out std_logic;
        S2_ARADDR  : out std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        S2_ARVALID : out std_logic;
        S2_ARREADY : in  std_logic;
        S2_RDATA   : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
        S2_RRESP   : in  std_logic_vector(1 downto 0);
        S2_RVALID  : in  std_logic;
        S2_RREADY  : out std_logic;

        -- Slave 3
        S3_AWADDR  : out std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        S3_AWVALID : out std_logic;
        S3_AWREADY : in  std_logic;
        S3_WDATA   : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
        S3_WSTRB   : out std_logic_vector(G_STRB_WIDTH-1 downto 0);
        S3_WVALID  : out std_logic;
        S3_WREADY  : in  std_logic;
        S3_BRESP   : in  std_logic_vector(1 downto 0);
        S3_BVALID  : in  std_logic;
        S3_BREADY  : out std_logic;
        S3_ARADDR  : out std_logic_vector(G_ADDR_WIDTH-1 downto 0);
        S3_ARVALID : out std_logic;
        S3_ARREADY : in  std_logic;
        S3_RDATA   : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
        S3_RRESP   : in  std_logic_vector(1 downto 0);
        S3_RVALID  : in  std_logic;
        S3_RREADY  : out std_logic
    );
end entity;

architecture rtl of axi_lite_interconnect_1x4 is

constant C_SM_IDLE              : std_logic_vector(6 downto 0):="0000001";
constant C_SM_FEED_SLV_WR       : std_logic_vector(6 downto 0):="0000010";
constant C_SM_FEED_RESP_WR      : std_logic_vector(6 downto 0):="0000100";
constant C_SM_FEED_RESP_WR_1    : std_logic_vector(6 downto 0):="0000100";
constant C_SM_FEED_RESP_WR_2    : std_logic_vector(6 downto 0):="0001000";
constant C_SM_FEED_SLV_RD       : std_logic_vector(6 downto 0):="0010000";
constant C_SM_FEED_RESP_RD_1    : std_logic_vector(6 downto 0):="0100000";
constant C_SM_FEED_RESP_RD_2    : std_logic_vector(6 downto 0):="1000000";

signal main_sm                  : std_logic_vector(6 downto 0):=C_SM_IDLE;  
signal wr_new_addr              : std_logic_vector(G_ADDR_WIDTH-1 downto 0);
signal rd_new_addr              : std_logic_vector(G_ADDR_WIDTH-1 downto 0);
signal store_data               : std_logic_vector(G_DATA_WIDTH-1 downto 0); 
signal store_strobe             : std_logic_vector(G_STRB_WIDTH-1 downto 0);
signal slave_sel                : unsigned(1 downto 0) := (others => '0');
signal m_wready_int : std_logic := '1';
signal m_awready_int : std_logic := '1';
signal m_arready_int : std_logic := '1';
signal s0_awvalid_int : std_logic := '0';
signal s1_awvalid_int : std_logic := '0';
signal s2_awvalid_int : std_logic := '0';
signal s3_awvalid_int : std_logic := '0';
signal s0_bready_int : std_logic := '0';
signal s1_bready_int : std_logic := '0';
signal s2_bready_int : std_logic := '0';
signal s3_bready_int : std_logic := '0';
signal m_bvalid_int : std_logic := '0';
signal s0_arvalid_int : std_logic := '0';
signal s1_arvalid_int : std_logic := '0';
signal s2_arvalid_int : std_logic := '0';
signal s3_arvalid_int : std_logic := '0';
signal s0_rready_int : std_logic := '0';
signal s1_rready_int : std_logic := '0';
signal s2_rready_int : std_logic := '0';
signal s3_rready_int : std_logic := '0';
signal m_rvalid_int : std_logic := '0';

begin

process(clk)
begin
        
    if rising_edge(clk) then

        if resetn='0' then

            wr_new_addr   <= (others => '0');
            rd_new_addr   <= (others => '0');
            store_data    <= (others => '0');
            store_strobe  <= (others => '0');
            slave_sel     <= (others => '0');
            S0_WVALID     <= '0';
            S1_WVALID     <= '0';
            S2_WVALID     <= '0';
            S3_WVALID     <= '0';

            main_sm         <= C_SM_IDLE;
            m_wready_int    <= '1';
            m_awready_int   <= '1';
            m_arready_int   <= '1';
            s0_awvalid_int  <= '0';
            s1_awvalid_int  <= '0';
            s2_awvalid_int  <= '0';
            s3_awvalid_int  <= '0';
            s0_bready_int   <= '0';
            s1_bready_int   <= '0';
            s2_bready_int   <= '0';
            s3_bready_int   <= '0';
            m_bvalid_int    <= '0';
            s0_arvalid_int  <= '0';
            s1_arvalid_int  <= '0';
            s2_arvalid_int  <= '0';
            s3_arvalid_int  <= '0';
            s0_rready_int   <= '0';
            s1_rready_int   <= '0';
            s2_rready_int   <= '0';
            s3_rready_int   <= '0';
            m_rvalid_int    <= '0';

        else
            
            -- Detect a write (Adress and data must be written at the same time)
            case main_sm is

                when C_SM_IDLE =>

                    ------------------------------
                    -- Write part
                    ------------------------------

                    if M_AWVALID='1' and m_awready_int='1' then
                        m_awready_int <= '0';
                    else
                        m_awready_int <= '1';
                    end if;

                    if M_WVALID='1' and m_wready_int='1' then
                        m_wready_int <= '0';
                    else
                        m_wready_int <= '1';
                    end if;

                    if M_WVALID='1' and m_wready_int='1' then
                        if M_AWVALID='1' and m_awready_int='1' then
                            main_sm  <= C_SM_FEED_SLV_WR;
                            store_data <= M_WDATA;
                            store_strobe <= M_WSTRB;
                            if unsigned(M_AWADDR) >= unsigned(G_BASE0) and unsigned(M_AWADDR) <= unsigned(G_LIMIT0) then
                                s0_awvalid_int <= '1';
                                s1_awvalid_int <= '0';
                                s2_awvalid_int <= '0';
                                s3_awvalid_int <= '0';
                                S0_WVALID  <= '1';
                                S1_WVALID  <= '0';
                                S2_WVALID  <= '0';
                                S3_WVALID  <= '0';
                                slave_sel  <= to_unsigned(0, 2);
                            elsif unsigned(M_AWADDR) >= unsigned(G_BASE1) and unsigned(M_AWADDR) <= unsigned(G_LIMIT1) then
                                s0_awvalid_int <= '0';
                                s1_awvalid_int <= '1';
                                s2_awvalid_int <= '0';
                                s3_awvalid_int <= '0';
                                S0_WVALID  <= '0';
                                S1_WVALID  <= '1';
                                S2_WVALID  <= '0';
                                S3_WVALID  <= '0';
                                slave_sel  <= to_unsigned(1, 2);
                            elsif unsigned(M_AWADDR) >= unsigned(G_BASE2) and unsigned(M_AWADDR) <= unsigned(G_LIMIT2) then
                                s0_awvalid_int <= '0';
                                s1_awvalid_int <= '0';
                                s2_awvalid_int <= '1';
                                s3_awvalid_int <= '0';
                                S0_WVALID  <= '0';
                                S1_WVALID  <= '0';
                                S2_WVALID  <= '1';
                                S3_WVALID  <= '0';
                                slave_sel  <= to_unsigned(2, 2);
                            elsif unsigned(M_AWADDR) >= unsigned(G_BASE3) and unsigned(M_AWADDR) <= unsigned(G_LIMIT3) then
                                s0_awvalid_int <= '0';
                                s1_awvalid_int <= '0';
                                s2_awvalid_int <= '0';
                                s3_awvalid_int <= '1';
                                S0_WVALID  <= '0';
                                S1_WVALID  <= '0';
                                S2_WVALID  <= '0';
                                S3_WVALID  <= '1';
                                slave_sel  <= to_unsigned(3, 2);
                            else
                                s0_awvalid_int <= '0';
                                s1_awvalid_int <= '0';
                                s2_awvalid_int <= '0';
                                s3_awvalid_int <= '0';
                                S0_WVALID  <= '0';
                                S1_WVALID  <= '0';
                                S2_WVALID  <= '0';
                                S3_WVALID  <= '0';
                                slave_sel  <= to_unsigned(0, 2); -- default
                            end if;
                        end if;
                    end if;

                    if M_AWVALID='1' and m_awready_int='1' then -- this if is to prevent warnings comparing when addr = U
                        if unsigned(M_AWADDR) >= unsigned(G_BASE0) and unsigned(M_AWADDR) <= unsigned(G_LIMIT0) then
                            wr_new_addr <= std_logic_vector(unsigned(M_AWADDR) - unsigned(G_BASE0));
                        elsif unsigned(M_AWADDR) >= unsigned(G_BASE1) and unsigned(M_AWADDR) <= unsigned(G_LIMIT1) then
                            wr_new_addr <= std_logic_vector(unsigned(M_AWADDR) - unsigned(G_BASE1));
                        elsif unsigned(M_AWADDR) >= unsigned(G_BASE2) and unsigned(M_AWADDR) <= unsigned(G_LIMIT2) then
                            wr_new_addr <= std_logic_vector(unsigned(M_AWADDR) - unsigned(G_BASE2));
                        elsif unsigned(M_AWADDR) >= unsigned(G_BASE3) and unsigned(M_AWADDR) <= unsigned(G_LIMIT3) then
                            wr_new_addr <= std_logic_vector(unsigned(M_AWADDR) - unsigned(G_BASE3));
                        end if;
                    end if;

                    ------------------------------
                    -- Read part
                    ------------------------------

                    if M_ARVALID='1' and m_arready_int='1' then
                        m_arready_int <= '0';
                    else
                        m_arready_int <= '1';
                    end if;


                    if M_ARVALID='1' and m_arready_int='1' then
                        main_sm  <= C_SM_FEED_SLV_RD;
                        if unsigned(M_ARADDR) >= unsigned(G_BASE0) and unsigned(M_ARADDR) <= unsigned(G_LIMIT0) then
                            s0_arvalid_int <= '1';
                            s1_arvalid_int <= '0';
                            s2_arvalid_int <= '0';
                            s3_arvalid_int <= '0';
                            slave_sel  <= to_unsigned(0, 2);
                        elsif unsigned(M_ARADDR) >= unsigned(G_BASE1) and unsigned(M_ARADDR) <= unsigned(G_LIMIT1) then
                            s0_arvalid_int <= '0';
                            s1_arvalid_int <= '1';
                            s2_arvalid_int <= '0';
                            s3_arvalid_int <= '0';
                            slave_sel  <= to_unsigned(1, 2);
                        elsif unsigned(M_ARADDR) >= unsigned(G_BASE2) and unsigned(M_ARADDR) <= unsigned(G_LIMIT2) then
                            s0_arvalid_int <= '0';
                            s1_arvalid_int <= '0';
                            s2_arvalid_int <= '1';
                            s3_arvalid_int <= '0';
                            slave_sel  <= to_unsigned(2, 2);
                        elsif unsigned(M_ARADDR) >= unsigned(G_BASE3) and unsigned(M_ARADDR) <= unsigned(G_LIMIT3) then
                            s0_arvalid_int <= '0';
                            s1_arvalid_int <= '0';
                            s2_arvalid_int <= '0';
                            s3_arvalid_int <= '1';
                            slave_sel  <= to_unsigned(3, 2);
                        else
                            s0_arvalid_int <= '0';
                            s1_arvalid_int <= '0';
                            s2_arvalid_int <= '0';
                            s3_arvalid_int <= '0';
                            slave_sel  <= to_unsigned(0, 2); -- default
                        end if;
                    end if;

                    if M_ARVALID='1' and m_arready_int='1' then -- this if is to prevent warnings comparing when addr = U

                        if unsigned(M_ARADDR) >= unsigned(G_BASE0) and unsigned(M_ARADDR) <= unsigned(G_LIMIT0) then
                            rd_new_addr <= std_logic_vector(unsigned(M_ARADDR) - unsigned(G_BASE0));
                        elsif unsigned(M_ARADDR) >= unsigned(G_BASE1) and unsigned(M_ARADDR) <= unsigned(G_LIMIT1) then
                            rd_new_addr <= std_logic_vector(unsigned(M_ARADDR) - unsigned(G_BASE1));
                        elsif unsigned(M_ARADDR) >= unsigned(G_BASE2) and unsigned(M_ARADDR) <= unsigned(G_LIMIT2) then
                            rd_new_addr <= std_logic_vector(unsigned(M_ARADDR) - unsigned(G_BASE2));
                        elsif unsigned(M_ARADDR) >= unsigned(G_BASE3) and unsigned(M_ARADDR) <= unsigned(G_LIMIT3) then
                            rd_new_addr <= std_logic_vector(unsigned(M_ARADDR) - unsigned(G_BASE3));
                        end if;
                        
                    end if;


                when C_SM_FEED_SLV_WR =>

                    if (s0_awvalid_int = '1' and S0_AWREADY = '1') or
                    (s1_awvalid_int = '1' and S1_AWREADY = '1') or
                    (s2_awvalid_int = '1' and S2_AWREADY = '1') or
                    (s3_awvalid_int = '1' and S3_AWREADY = '1') then
                        s0_awvalid_int <= '0';
                        s1_awvalid_int <= '0';
                        s2_awvalid_int <= '0';
                        s3_awvalid_int <= '0';
                        S0_WVALID <= '0';
                        S1_WVALID <= '0';
                        S2_WVALID <= '0';
                        S3_WVALID <= '0';
                        main_sm <= C_SM_FEED_RESP_WR_1;
                    end if;

                when C_SM_FEED_RESP_WR_1 =>

                    case slave_sel is
                        when "00" =>
                            if S0_BVALID='1' and s0_bready_int='1' then
                                s0_bready_int <= '0';
                                m_bvalid_int  <= '1';
                                M_BRESP       <= S0_BRESP;
                                main_sm       <= C_SM_FEED_RESP_WR_2;
                            else
                                s0_bready_int <= '1';
                                s1_bready_int <= '0';
                                s2_bready_int <= '0';
                                s3_bready_int <= '0';
                            end if;
                        when "01" =>
                            if S1_BVALID='1' and s1_bready_int='1' then
                                s1_bready_int <= '0';
                                m_bvalid_int  <= '1';
                                M_BRESP       <= S1_BRESP;
                                main_sm       <= C_SM_FEED_RESP_WR_2;
                            else
                                s0_bready_int <= '0';
                                s1_bready_int <= '1';
                                s2_bready_int <= '0';
                                s3_bready_int <= '0';
                            end if;
                        when "10" =>
                            if S2_BVALID='1' and s2_bready_int='1' then
                                s2_bready_int <= '0';
                                m_bvalid_int  <= '1';
                                M_BRESP       <= S2_BRESP;
                                main_sm       <= C_SM_FEED_RESP_WR_2;
                            else
                                s0_bready_int <= '0';
                                s1_bready_int <= '0';
                                s2_bready_int <= '1';
                                s3_bready_int <= '0';
                            end if;
                        when "11" =>
                            if S3_BVALID='1' and s3_bready_int='1' then
                                s3_bready_int <= '0';
                                m_bvalid_int  <= '1';
                                M_BRESP       <= S3_BRESP;
                                main_sm       <= C_SM_FEED_RESP_WR_2;
                            else
                                s0_bready_int <= '0';
                                s1_bready_int <= '0';
                                s2_bready_int <= '0';
                                s3_bready_int <= '1';
                            end if;
                        when others =>
                            s0_bready_int <= '0';
                            s1_bready_int <= '0';
                            s2_bready_int <= '0';
                            s3_bready_int <= '0';
                    end case;


                when C_SM_FEED_RESP_WR_2 =>

                    if m_bvalid_int='1' and M_BREADY='1' then
                        m_bvalid_int <= '0';
                        main_sm      <= C_SM_IDLE;
                    end if;

                when C_SM_FEED_SLV_RD      =>

                    case slave_sel is
                        when "00" =>
                            if s0_arvalid_int = '1' and S0_ARREADY = '1' then
                                s0_arvalid_int <= '0';
                                main_sm  <= C_SM_FEED_RESP_RD_1;
                            else
                                s0_arvalid_int <= '1';
                            end if;
                        when "01" =>
                            if s1_arvalid_int = '1' and S1_ARREADY = '1' then
                                s1_arvalid_int <= '0';
                                main_sm  <= C_SM_FEED_RESP_RD_1;
                            else
                                s1_arvalid_int <= '1';
                            end if;
                        when "10" =>
                            if s2_arvalid_int = '1' and S2_ARREADY = '1' then
                                s2_arvalid_int <= '0';
                                main_sm  <= C_SM_FEED_RESP_RD_1;
                            else
                                s2_arvalid_int <= '1';
                            end if;
                        when "11" =>
                            if s3_arvalid_int = '1' and S3_ARREADY = '1' then
                                s3_arvalid_int <= '0';
                                main_sm  <= C_SM_FEED_RESP_RD_1;
                            else
                                s3_arvalid_int <= '1';
                            end if;
                        when others =>
                            -- STALL
                    end case;

                when C_SM_FEED_RESP_RD_1      =>

                    case slave_sel is
                        when "00" =>
                            if S0_RVALID = '1' and s0_rready_int = '1' then
                                s0_rready_int <= '0';
                                m_rvalid_int  <= '1';
                                M_RDATA       <= S0_RDATA;
                                M_RRESP       <= S0_RRESP;
                                main_sm       <= C_SM_FEED_RESP_RD_2;
                            else
                                s0_rready_int <= '1';
                                s1_rready_int <= '0';
                                s2_rready_int <= '0';
                                s3_rready_int <= '0';
                            end if;
                        when "01" =>
                            if S1_RVALID = '1' and s1_rready_int = '1' then
                                s1_rready_int <= '0';
                                m_rvalid_int  <= '1';
                                M_RDATA       <= S1_RDATA;
                                M_RRESP       <= S1_RRESP;
                                main_sm       <= C_SM_FEED_RESP_RD_2;
                            else
                                s0_rready_int <= '0';
                                s1_rready_int <= '1';
                                s2_rready_int <= '0';
                                s3_rready_int <= '0';
                            end if;
                        when "10" =>
                            if S2_RVALID = '1' and s2_rready_int = '1' then
                                s2_rready_int <= '0';
                                m_rvalid_int  <= '1';
                                M_RDATA       <= S2_RDATA;
                                M_RRESP       <= S2_RRESP;
                                main_sm       <= C_SM_FEED_RESP_RD_2;
                            else
                                s0_rready_int <= '0';
                                s1_rready_int <= '0';
                                s2_rready_int <= '1';
                                s3_rready_int <= '0';
                            end if;
                        when "11" =>
                            if S3_RVALID = '1' and s3_rready_int = '1' then
                                s3_rready_int <= '0';
                                m_rvalid_int  <= '1';
                                M_RDATA       <= S3_RDATA;
                                M_RRESP       <= S3_RRESP;
                                main_sm       <= C_SM_FEED_RESP_RD_2;
                            else
                                s0_rready_int <= '0';
                                s1_rready_int <= '0';
                                s2_rready_int <= '0';
                                s3_rready_int <= '1';
                            end if;
                        when others =>
                            s0_rready_int <= '0';
                            s1_rready_int <= '0';
                            s2_rready_int <= '0';
                            s3_rready_int <= '0';
                    end case;

                when others =>

                    if m_rvalid_int='1' and M_RREADY='1' then
                        m_rvalid_int <= '0';
                        main_sm      <= C_SM_IDLE;
                    end if;

            end case;

        end if;

    end if;
end process;


S0_AWADDR <= wr_new_addr;
S1_AWADDR <= wr_new_addr;
S2_AWADDR <= wr_new_addr;
S3_AWADDR <= wr_new_addr;

S0_WDATA <= store_data;
S1_WDATA <= store_data;
S2_WDATA <= store_data;
S3_WDATA <= store_data;

S0_WSTRB <= store_strobe;
S1_WSTRB <= store_strobe;
S2_WSTRB <= store_strobe;
S3_WSTRB <= store_strobe;

S0_ARADDR <= rd_new_addr;
S1_ARADDR <= rd_new_addr;
S2_ARADDR <= rd_new_addr;
S3_ARADDR <= rd_new_addr;

M_WREADY <= m_wready_int;
M_AWREADY <= m_awready_int;
M_ARREADY <= m_arready_int;

S0_AWVALID <= s0_awvalid_int;
S1_AWVALID <= s1_awvalid_int;
S2_AWVALID <= s2_awvalid_int;
S3_AWVALID <= s3_awvalid_int;

M_BVALID <= m_bvalid_int;

S0_ARVALID <= s0_arvalid_int;
S1_ARVALID <= s1_arvalid_int;
S2_ARVALID <= s2_arvalid_int;
S3_ARVALID <= s3_arvalid_int;

S0_RREADY <= s0_rready_int;
S1_RREADY <= s1_rready_int;
S2_RREADY <= s2_rready_int;
S3_RREADY <= s3_rready_int;

M_RVALID <= m_rvalid_int;

S0_BREADY    <= s0_bready_int;
S1_BREADY    <= s1_bready_int;
S2_BREADY    <= s2_bready_int;
S3_BREADY    <= s3_bready_int;

end architecture;