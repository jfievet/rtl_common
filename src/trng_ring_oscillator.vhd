library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trng_ring_oscillator is
    generic (
        G_RO_STAGES : positive := 7
    );
    port (
        oscillator_bit : out std_logic
    );
end entity;

architecture rtl of trng_ring_oscillator is
    signal stage_links : std_logic_vector(G_RO_STAGES - 1 downto 0);
    attribute keep : boolean;
    attribute keep of stage_links : signal is true;
begin
    assert G_RO_STAGES mod 2 = 1
        report "G_RO_STAGES must be odd" severity failure;

    -- Each stage has its own preserved combinational node.
    stages : for i in 0 to G_RO_STAGES - 1 generate
        signal node : std_logic;
        attribute keep of node : signal is true;
    begin
        first_stage : if i = 0 generate
            node <= not stage_links(G_RO_STAGES - 1);
        end generate;
        other_stage : if i > 0 generate
            node <= not stage_links(i - 1);
        end generate;
        stage_links(i) <= node;
    end generate;

    oscillator_bit <= stage_links(G_RO_STAGES - 1);
end architecture;
