/*

===============================================================================
                   ------->  Revision History  <------
===============================================================================

   Date    Who  Ver  Changes
===============================================================================
20-Feb-26  DWW    1  Initial creation
===============================================================================
 

    This module provides clock-crossing for every signal that has to travel
    between the sys_clk domain and the chipif_clk domain

*/
module chip_if_cdc
(
			
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 sys_clk CLK" *)
    input   sys_clk,

    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 chipif_clk CLK" *)
    input   chipif_clk,

    // These strobe high for a cycle to tell us to update SMEM from an ABM
    input   sys_update_smem_stb,
    output      update_smem_stb,

    // SMEM write enable.  When this is low, writes to SMEM are paused
    input   sys_smem_wen,
    output      smem_wen,

    // These are used to tell the ABM manager to load an ABM from host RAM
    output  sys_load_abm_stb,
    input       load_abm_stb,
    output  sys_load_abm_0,
    input       load_abm_0,
    output  sys_load_abm_1,
    input       load_abm_1,

    // The ABM manager uses these to tell us when it's done loading an ABM
    // from host RAM
    input   sys_load_abm_idle_0,
    output      load_abm_idle_0,
    input   sys_load_abm_idle_1,
    output      load_abm_idle_1,

    // The address of an ABM in host RAM
    input  [63:0]     abm_host_addr,
    output [63:0] sys_abm_host_addr

);


//=============================================================================
// Synchronize sys_abm_host_addr[63:0]
//=============================================================================
xpm_cdc_array_single # (.WIDTH(64)) i_sync_sys_abm_host_addr
(
    .src_clk    (chipif_clk),
    .dest_clk   (   sys_clk),

    .src_in     (    abm_host_addr),
    .dest_out   (sys_abm_host_addr)
);
//=============================================================================


//=============================================================================
// If we see "load_abm_stb" delay the strobe for a few cycles to ensure that
// "load_abm_0" and "load_abm_1" are already across the CDC
//=============================================================================
reg[2:0] abm_stb_counter;
always @(posedge chipif_clk) begin
    if (load_abm_stb)
        abm_stb_counter <= 7;
    else if (abm_stb_counter)
        abm_stb_counter <= abm_stb_counter -1 ;
end
wire load_abm_stb_delayed = (abm_stb_counter == 1);
//=============================================================================



//=============================================================================
// Synchronize "sys_load_abm_stb_delayed"
//=============================================================================
strobe_cdc i_sync_sys_load_abm_stb 
(
    .src_clk    (chipif_clk),
    .src_stb    (load_abm_stb_delayed),
    .dst_stb    (sys_load_abm_stb),
    .dst_clk    (sys_clk)
);
//=============================================================================



//=============================================================================
// Synchronize sys_load_abm_0 and sys_load_abm_1
//=============================================================================
xpm_cdc_single sys_load_abm_0
(
   .src_clk (chipif_clk), 
   .dest_clk(   sys_clk), 

   .src_in  (    load_abm_0),
   .dest_out(sys_load_abm_0)
);

xpm_cdc_single sys_load_abm_1
(
   .src_clk (chipif_clk), 
   .dest_clk(   sys_clk), 

   .src_in  (    load_abm_1),
   .dest_out(sys_load_abm_1)
);
//=============================================================================



//=============================================================================
// Synchronize load_abm_idle_0 and load_abm_idle_1
//=============================================================================
xpm_cdc_single i_sync_load_abm_idle_0
(
   .src_clk (   sys_clk), 
   .dest_clk(chipif_clk), 

   .src_in  (sys_load_abm_idle_0),
   .dest_out(    load_abm_idle_0)
);

xpm_cdc_single  i_sync_load_abm_idle_1
(
   .src_clk (   sys_clk), 
   .dest_clk(chipif_clk), 

   .src_in  (sys_load_abm_idle_1),
   .dest_out(    load_abm_idle_1)
);
//=============================================================================


//=============================================================================
// Synchronize "sys_update_smem_stb"
//=============================================================================
strobe_cdc i_sync_update_smem_stb
(
    .src_clk    (sys_clk),
    .src_stb    (sys_update_smem_stb),
    .dst_stb    (    update_smem_stb),
    .dst_clk    (chipif_clk)
);
//=============================================================================


//=============================================================================
// Synchronize "smem_wen"  (SMEM write-enable)
//=============================================================================
xpm_cdc_single i_sync_smem_wen
(
   .src_clk (   sys_clk), 
   .dest_clk(chipif_clk), 
   .src_in  (sys_smem_wen),
   .dest_out(    smem_wen)
);
//=============================================================================




endmodule