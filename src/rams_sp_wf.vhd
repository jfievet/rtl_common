library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.rams_sp_wf_pkg.all;

entity rams_sp_wf is
generic (
    G_DEPTH         : integer := 1024;
    G_RAM_INIT      : ram_type
);
port(
    clk     : in std_logic;
    we      : in std_logic;
    en      : in std_logic;
    addr    : in std_logic_vector(integer(ceil(log2(real(G_DEPTH))))-1 downto 0);
    di      : in std_logic_vector(7 downto 0);
    do      : out std_logic_vector(7 downto 0)
);
end rams_sp_wf;

architecture syn of rams_sp_wf is

signal RAM : ram_type:=G_RAM_INIT;

begin

process(clk)
begin
    if rising_edge(clk) then
        if en = '1' then
            if we = '1' then
                RAM(to_integer(unsigned(addr))) <= di;
                do <= di;
            else
                do <= RAM(to_integer(unsigned(addr)));
            end if;
        end if;
    end if;
end process;

end syn;
