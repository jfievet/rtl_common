library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trng_prbs32 is
    generic (
        G_RO_COUNT           : positive := 8;
        G_USE_ASYNC_RESET    : boolean := true;
        G_USE_SYNC_RESET     : boolean := true;
        G_ASYNC_RESET_ACTIVE : std_logic := '1';
        G_SYNC_RESET_ACTIVE  : std_logic := '1'
    );
    port (
        clk          : in  std_logic;
        async_reset  : in  std_logic;
        sync_reset   : in  std_logic;
        sampled_bits : out std_logic_vector(G_RO_COUNT - 1 downto 0)
    );
end entity;

architecture rtl of trng_prbs32 is
    constant C_SEED : std_logic_vector(31 downto 0) := x"00000001";
    signal state : std_logic_vector(31 downto 0);

    function advance(value : std_logic_vector(31 downto 0))
        return std_logic_vector is
    begin
        return value(30 downto 0) &
            (value(31) xor value(21) xor value(1) xor value(0));
    end function;
begin
    assert G_ASYNC_RESET_ACTIVE = '0' or G_ASYNC_RESET_ACTIVE = '1'
        report "Invalid asynchronous reset polarity" severity failure;
    assert G_SYNC_RESET_ACTIVE = '0' or G_SYNC_RESET_ACTIVE = '1'
        report "Invalid synchronous reset polarity" severity failure;

    process(clk, async_reset)
    begin
        if G_USE_ASYNC_RESET and async_reset = G_ASYNC_RESET_ACTIVE then
            state <= C_SEED;
        elsif rising_edge(clk) then
            if G_USE_SYNC_RESET and sync_reset = G_SYNC_RESET_ACTIVE then
                state <= C_SEED;
            else
                state <= advance(state);
            end if;
        end if;
    end process;

    process(state)
        variable lookahead : std_logic_vector(31 downto 0);
    begin
        lookahead := state;
        for i in 0 to G_RO_COUNT - 1 loop
            sampled_bits(i) <= lookahead(31);
            lookahead := advance(lookahead);
        end loop;
    end process;

end rtl;