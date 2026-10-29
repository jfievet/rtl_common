library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trng_entropy_source is
    generic (
        G_SIM                : boolean := false;
        G_RO_COUNT           : positive := 8;
        G_RO_STAGES          : positive := 7;
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

architecture rtl of trng_entropy_source is
begin
    assert G_ASYNC_RESET_ACTIVE = '0' or G_ASYNC_RESET_ACTIVE = '1'
        report "Invalid asynchronous reset polarity" severity failure;
    assert G_SYNC_RESET_ACTIVE = '0' or G_SYNC_RESET_ACTIVE = '1'
        report "Invalid synchronous reset polarity" severity failure;

    simulation_source : if G_SIM generate
        prbs : entity work.trng_prbs32
            generic map (
                G_RO_COUNT => G_RO_COUNT,
                G_USE_ASYNC_RESET => G_USE_ASYNC_RESET,
                G_USE_SYNC_RESET => G_USE_SYNC_RESET,
                G_ASYNC_RESET_ACTIVE => G_ASYNC_RESET_ACTIVE,
                G_SYNC_RESET_ACTIVE => G_SYNC_RESET_ACTIVE
            )
            port map (
                clk => clk, async_reset => async_reset,
                sync_reset => sync_reset, sampled_bits => sampled_bits
            );
    end generate;

    hardware_source : if not G_SIM generate
        oscillators : for i in 0 to G_RO_COUNT - 1 generate
            signal oscillator_bit : std_logic;
            signal sample_meta : std_logic;
            signal sample_sync : std_logic;
            attribute preserve : boolean;
            attribute dont_merge : boolean;
            attribute preserve of sample_meta, sample_sync : signal is true;
            attribute dont_merge of sample_meta, sample_sync : signal is true;
        begin
            ring_oscillator : entity work.trng_ring_oscillator
                generic map (G_RO_STAGES => G_RO_STAGES)
                port map (oscillator_bit => oscillator_bit);

            process(clk, async_reset)
            begin
                if G_USE_ASYNC_RESET and async_reset = G_ASYNC_RESET_ACTIVE then
                    sample_meta <= '0';
                    sample_sync <= '0';
                elsif rising_edge(clk) then
                    if G_USE_SYNC_RESET and sync_reset = G_SYNC_RESET_ACTIVE then
                        sample_meta <= '0';
                        sample_sync <= '0';
                    else
                        sample_meta <= oscillator_bit;
                        sample_sync <= sample_meta;
                    end if;
                end if;
            end process;

            sampled_bits(i) <= sample_sync;
        end generate;
    end generate;
end architecture;
