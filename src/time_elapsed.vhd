library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity time_elapsed is
    generic (
        G_USE_ASYNC_RESET    : boolean   := TRUE;
        G_USE_SYNC_RESET     : boolean   := TRUE;
        G_ASYNC_RESET_ACTIVE : std_logic := '1';
        G_SYNC_RESET_ACTIVE  : std_logic := '1'
    );
    port (
        clk          : in  std_logic;
        async_reset  : in  std_logic;
        sync_reset   : in  std_logic;
        sync_pulse   : in  std_logic;
        elapsed_time : out std_logic_vector(63 downto 0)
    );
end entity time_elapsed;

architecture rtl of time_elapsed is

    signal counter       : unsigned(63 downto 0);
    signal captured_time : unsigned(63 downto 0);

begin

    process(clk, async_reset)
    begin
        if G_USE_ASYNC_RESET and (async_reset = G_ASYNC_RESET_ACTIVE) then
            counter       <= (others => '0');
            captured_time <= (others => '0');

        elsif rising_edge(clk) then
            if G_USE_SYNC_RESET and (sync_reset = G_SYNC_RESET_ACTIVE) then
                counter       <= (others => '0');
                captured_time <= (others => '0');

            else
                -- Free-running 64-bit counter
                counter <= counter + 1;

                -- Capture counter value on synchronization pulse
                if sync_pulse = '1' then
                    captured_time <= counter;
                end if;

            end if;
        end if;
    end process;

    elapsed_time <= std_logic_vector(captured_time);

end architecture rtl;