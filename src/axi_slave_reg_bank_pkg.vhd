library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package axi_slave_reg_bank_pkg is

    constant C_DATA_WIDTH : positive := 32;
    constant C_DEPTH      : positive := 32;

    type reg_bank_t is array (0 to C_DEPTH-1) of std_logic_vector(C_DATA_WIDTH-1 downto 0);

end package axi_slave_reg_bank_pkg;