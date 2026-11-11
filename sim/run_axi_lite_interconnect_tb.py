from pathlib import Path                                  
from vunit import VUnit                                  
                                  
ROOT = Path(__file__).parent / "../"     
                                  
# Call Vunit addons
VU = VUnit.from_argv()
VU.add_vhdl_builtins()
VU.add_verification_components()

# Source files                                
LIB = VU.add_library("lib")
LIB.add_source_files( ROOT / "src" / "axi_interconnect_single.vhd")
LIB.add_source_files( ROOT / "src" / "axi_lite_interconnect.vhd")
LIB.add_source_files( ROOT / "src" / "axi_lite_interconnect_pkg.vhd")

#Libraries
LIB.add_source_files( ROOT / "tb" / "axi_lite_interconnect_tb.vhd")

# Modelsim options
VU.set_sim_option('modelsim.init_files.after_load', [str(ROOT / 'sim' / 'wave_axi_lite_interconnect_tb.do')])
VU.set_sim_option('modelsim.vsim_flags', ["-voptargs=\"+acc\""])

VU.main()