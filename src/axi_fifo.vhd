library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_fifo is
    generic (
        USE_ASYNC_RESET    : boolean   := TRUE;
        USE_SYNC_RESET     : boolean   := TRUE;
        ASYNC_RESET_ACTIVE : std_logic := '1';
        SYNC_RESET_ACTIVE  : std_logic := '1';
        DATA_WIDTH : positive := 32;
        DEPTH      : positive := 16
    );
    port (
        clk           : in  std_logic;
        async_reset : in std_logic;
        -- Internal software clear remains synchronous.
        soft_reset : in std_logic := '0';
        sync_reset  : in std_logic;

        s_axis_tdata  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;

        m_axis_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;

        fifo_full     : out std_logic;
        fifo_empty    : out std_logic;
        fifo_level    : out std_logic_vector
    );
end entity;

architecture rtl of axi_fifo is

    function clog2(n : positive) return natural is
        variable result : natural;
        variable value  : natural;
    begin
        result := 0;
        value  := n - 1;

        while value > 0 loop
            result := result + 1;
            value  := value / 2;
        end loop;

        return result;
    end function;

    constant LEVEL_WIDTH : positive := clog2(DEPTH + 1);

    subtype ptr_t is natural range 0 to DEPTH - 1;

    type ram_t is array (0 to DEPTH - 1) of
        std_logic_vector(DATA_WIDTH-1 downto 0);

    signal ram : ram_t;

    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M9K";

    signal wr_ptr : ptr_t;
    signal rd_ptr : ptr_t;

    -- Number of words held in RAM, excluding output_data.
    signal ram_level : unsigned(LEVEL_WIDTH-1 downto 0);

    signal output_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal output_valid : std_logic;

    signal input_transfer  : std_logic;
    signal output_transfer : std_logic;
    signal load_output     : std_logic;

    signal total_level : unsigned(LEVEL_WIDTH-1 downto 0);

    signal s_axis_tready_int : std_logic;
begin

    s_axis_tready <= s_axis_tready_int;

    total_level <= ram_level + 1 when output_valid = '1'
                   else ram_level;

    fifo_full  <= '1' when total_level = to_unsigned(DEPTH, LEVEL_WIDTH)
                  else '0';

    fifo_empty <= '1' when total_level = 0
                  else '0';

    fifo_level <= std_logic_vector(total_level);

    -- Accept a new word whenever the complete FIFO is not full.
    s_axis_tready_int <= '1'
        when total_level < to_unsigned(DEPTH, LEVEL_WIDTH)
        else '0';

    m_axis_tdata  <= output_data;
    m_axis_tvalid <= output_valid;

    input_transfer  <= s_axis_tvalid and s_axis_tready_int;
    output_transfer <= output_valid and m_axis_tready;

    -- Refill the output register when it is empty, or when its current
    -- word is being consumed.
    load_output <= '1'
        when ram_level /= 0 and
             (output_valid = '0' or output_transfer = '1')
        else '0';

    process (clk, async_reset) is
        variable next_wr_ptr : ptr_t;
        variable next_rd_ptr : ptr_t;
    begin
        if ((async_reset = ASYNC_RESET_ACTIVE) and (USE_ASYNC_RESET = true)) then
            wr_ptr       <= 0;
            rd_ptr       <= 0;
            ram_level    <= (others => '0');
            output_data  <= (others => '0');
            output_valid <= '0';
        elsif rising_edge(clk) then
            if ((sync_reset = SYNC_RESET_ACTIVE) and (USE_SYNC_RESET = true)) then
                wr_ptr       <= 0;
                rd_ptr       <= 0;
                ram_level    <= (others => '0');
                output_data  <= (others => '0');
                output_valid <= '0';
            elsif soft_reset = '1' then
                wr_ptr       <= 0;
                rd_ptr       <= 0;
                ram_level    <= (others => '0');
                output_data  <= (others => '0');
                output_valid <= '0';
            else
                next_wr_ptr := wr_ptr;
                next_rd_ptr := rd_ptr;

                --------------------------------------------------------
                -- Output-register refill from synchronous memory
                --------------------------------------------------------
                if load_output = '1' then
                    output_data  <= ram(rd_ptr);
                    output_valid <= '1';

                    if rd_ptr = DEPTH - 1 then
                        next_rd_ptr := 0;
                    else
                        next_rd_ptr := rd_ptr + 1;
                    end if;

                elsif output_transfer = '1' then
                    output_valid <= '0';
                end if;

                --------------------------------------------------------
                -- Write RAM
                --------------------------------------------------------
                if input_transfer = '1' then
                    ram(wr_ptr) <= s_axis_tdata;

                    if wr_ptr = DEPTH - 1 then
                        next_wr_ptr := 0;
                    else
                        next_wr_ptr := wr_ptr + 1;
                    end if;
                end if;

                wr_ptr <= next_wr_ptr;
                rd_ptr <= next_rd_ptr;

                --------------------------------------------------------
                -- Number of words stored in RAM
                --------------------------------------------------------
                if input_transfer = '1' and load_output = '0' then
                    ram_level <= ram_level + 1;

                elsif input_transfer = '0' and load_output = '1' then
                    ram_level <= ram_level - 1;
                end if;
            end if;
        end if;
    end process;

end architecture;