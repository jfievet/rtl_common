library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trng_random_generator is
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
        start        : in  std_logic;
        clear        : in  std_logic;
        accum_cycles : in  unsigned(31 downto 0);
        sampled_bits : in  std_logic_vector(G_RO_COUNT - 1 downto 0);
        result       : out std_logic_vector(31 downto 0);
        complete     : out std_logic
    );
end entity;

architecture rtl of trng_random_generator is
    constant C_MIX_MASK : unsigned(31 downto 0) := x"00400007";
    signal accumulator : unsigned(31 downto 0);
    signal mixed : unsigned(31 downto 0);
    signal remaining : unsigned(31 downto 0);
begin
    assert G_ASYNC_RESET_ACTIVE = '0' or G_ASYNC_RESET_ACTIVE = '1'
        report "Invalid asynchronous reset polarity" severity failure;
    assert G_SYNC_RESET_ACTIVE = '0' or G_SYNC_RESET_ACTIVE = '1'
        report "Invalid synchronous reset polarity" severity failure;

    process(accumulator, sampled_bits)
        variable m : unsigned(31 downto 0);
        variable feedback : std_logic;
    begin
        m := rotate_left(accumulator, 5);

        for i in 0 to G_RO_COUNT - 1 loop
            feedback := m(31) xor sampled_bits(i);
            m := shift_left(m, 1);

            -- Bitwise masking also propagates unknown samples in simulation.
            for j in 0 to 31 loop
                m(j) := m(j) xor (C_MIX_MASK(j) and feedback);
            end loop;
        end loop;

        mixed <= m;
    end process;

    -- The consumer captures mixed on the terminal accumulation edge.
    complete <= '1' when remaining = 1 and clear = '0' and start = '0' else '0';
    result <= std_logic_vector(mixed) when remaining /= 0 else
              std_logic_vector(accumulator);

    process(clk, async_reset)
    begin
        if G_USE_ASYNC_RESET and async_reset = G_ASYNC_RESET_ACTIVE then
            accumulator <= (others => '0');
            remaining <= (others => '0');
        elsif rising_edge(clk) then
            if G_USE_SYNC_RESET and sync_reset = G_SYNC_RESET_ACTIVE then
                accumulator <= (others => '0');
                remaining <= (others => '0');
            elsif clear = '1' then
                accumulator <= (others => '0');
                remaining <= (others => '0');
            elsif start = '1' and remaining = 0 then
                accumulator <= (others => '0');
                remaining <= accum_cycles;
            elsif remaining /= 0 then
                accumulator <= mixed;
                remaining <= remaining - 1;
            end if;
        end if;
    end process;
end architecture;
