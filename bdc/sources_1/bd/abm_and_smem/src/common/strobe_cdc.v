module strobe_cdc
(
    input   src_clk,
    input   src_stb,
    
    input   dst_clk,
    output reg dst_stb
);


// Any time src_stb goes high, these will change state
reg edge_carrier_src;
wire edge_carrier_dst;


//=============================================================================
// Any time we sense a pulse on src_stb, create an edge on the edge-carrier
//=============================================================================
always @(posedge src_clk) begin
    if (src_stb) edge_carrier_src <= ~edge_carrier_src;
end
//=============================================================================


//=============================================================================
// Destination strobe occurs whenever there is an edge on the carrier
//=============================================================================
reg prior_edge_carrier_dst;
always @(posedge dst_clk)prior_edge_carrier_dst <= edge_carrier_dst;

always @(posedge dst_clk) begin
    dst_stb <= (prior_edge_carrier_dst != edge_carrier_dst);
end
//=============================================================================


//=============================================================================
// Synchronize the edge carrier
//=============================================================================
xpm_cdc_single i_sync_edge_carrier
(
    .src_clk (src_clk         ),
    .src_in  (edge_carrier_src),
    .dest_clk(dst_clk         ),
    .dest_out(edge_carrier_dst)
);
//=============================================================================




endmodule
