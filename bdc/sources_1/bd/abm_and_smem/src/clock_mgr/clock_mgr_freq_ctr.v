/*

===============================================================================
                   ------->  Revision History  <------
===============================================================================

   Date    Who  Ver  Changes
===============================================================================
20-Feb-26  DWW    1  Initial creation
===============================================================================
        
    This module measures a clock frequency by inverting a flip-flop every
    "test_clk/1000" clock-cycles, the counting the edges of that signal
    for one tenth of a second.

*/


module clock_mgr_freq_ctr # (parameter FREQ_HZ = 250000000)
(
     // The clock that drives this module
    input clk,

    // The clock whose frequency we want to measure
    input test_clk,

    // The measured frequency of "test_clk"
    output reg[31:0] freq_out
);

// We'll divide down "test_clk" by this
localparam CLK_DIVISOR = 1000;

// We're going to count edges of "flip_flop" for 1/10th second
localparam TENTH_SECOND = FREQ_HZ / 10;

// Synchronous to "clk", and running at 1/1000th the frequency of "test_clk"
wire flip_flop;
reg  prior_flip_flop;

// We always need to know the state of the flip-flop on the prior clock cycle
always @(posedge clk) prior_flip_flop <= flip_flop;

// Detect both rising and falling edges of flip_flop
wire ff_edge = prior_flip_flop ^ flip_flop;

//=============================================================================
// Here we're going to measure the frequenty of "test_clk"
//=============================================================================
reg[31:0] frequency_counter;
reg[31:0] edge_count;
//-----------------------------------------------------------------------------
always @(posedge clk) begin

    // Count the number of edges
    if (ff_edge) edge_count  <= edge_count + 1;
    
    if (frequency_counter)
        frequency_counter <= frequency_counter - 1;
    else begin
        freq_out          <= edge_count * (10 * CLK_DIVISOR);
        frequency_counter <= TENTH_SECOND - 1;
        edge_count        <= ff_edge;
    end

end
//=============================================================================





//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
//        Everything From here down is in the "test_clk" clock domain
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><
//<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><


//=============================================================================
// Here we generate an edge on a flip-flop every CLK_DIVISOR clock cycles
//=============================================================================
reg       local_ff;
reg[31:0] divide_counter;
//-----------------------------------------------------------------------------
always @(posedge test_clk) begin
    if (divide_counter)
        divide_counter <= divide_counter - 1;
    else begin
        local_ff       <= !local_ff;
        divide_counter <= CLK_DIVISOR - 1;
    end
end
//=============================================================================

//=============================================================================
// Synchronize "local_ff" into "flip_flop"
//=============================================================================
xpm_cdc_single #
(
    .DEST_SYNC_FF  (4),
    .INIT_SYNC_FF  (0),
    .SIM_ASSERT_CHK(0),
    .SRC_INPUT_REG (0)
)
sync_flip_flop
(
    .src_clk (         ),
    .src_in  (local_ff ),
    .dest_clk(clk      ),
    .dest_out(flip_flop)
);
//=============================================================================

endmodule