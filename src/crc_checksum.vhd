library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity crc_checksum is
    generic (
        USE_ASYNC_RESET    : boolean   := TRUE;
        USE_SYNC_RESET     : boolean   := TRUE;
        ASYNC_RESET_ACTIVE : std_logic := '1';
        SYNC_RESET_ACTIVE  : std_logic := '1';
        poly_size          : integer   := 32;
        poly_value         : std_logic_vector(31 downto 0);
        data_in_width      : integer := 8
    );
    port (
        clock       : in std_logic;
        async_reset : in std_logic;
        sync_reset  : in std_logic;
        data_in     : in std_logic_vector(data_in_width - 1 downto 0);
        data_in_en  : in std_logic;
        init_in     : in std_logic;
        data_out    : out std_logic_vector(poly_size - 1 downto 0);
        data_out_en : out std_logic
    );
end entity crc_checksum;

architecture rtl of crc_checksum is

    signal checksum : std_logic_vector(poly_size - 1 downto 0);

begin

    main_pr : process (clock, async_reset) is

        variable v_checksum    : std_logic_vector(poly_size - 1 downto 0);
        variable v_a_input_xor : std_logic;
        variable v_b_input_xor : std_logic;
        variable v_ab_xor      : std_logic;

    begin

        if ((async_reset = ASYNC_RESET_ACTIVE) and (USE_ASYNC_RESET = true)) then
            v_checksum := (others  => '0');
            checksum    <= (others => '0');
            data_out_en <= '0';
        elsif rising_edge(clock) then
            if ((sync_reset = SYNC_RESET_ACTIVE) and (USE_SYNC_RESET = true)) then
                v_checksum := (others  => '0');
                checksum    <= (others => '0');
                data_out_en <= '0';
            else
                if (init_in = '1') then
                    v_checksum := (others => '1');
                else
                    v_checksum := checksum;
                end if;

                if (data_in_en = '1') then

                    for i in data_in_width - 1 downto 0 loop

                        v_a_input_xor := data_in(I);
                        v_b_input_xor := v_checksum(poly_size - 1);
                        v_ab_xor      := v_a_input_xor xor v_b_input_xor;

                        for j in 1 to poly_size - 1 loop

                            if (poly_value(poly_size - J) = '1') then
                                v_checksum(poly_size - J) := v_checksum(poly_size - J - 1) xor v_ab_xor;
                            else
                                v_checksum(poly_size - J) := v_checksum(poly_size - J - 1);
                            end if;

                        end loop;

                        v_checksum(0) := v_ab_xor;

                    end loop;

                end if;

                checksum    <= v_checksum;
                data_out_en <= data_in_en;
            end if;
        end if;

    end process main_pr;

    data_out <= checksum;

end architecture rtl;
