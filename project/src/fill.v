module fill # (parameter IW=2, AW=20, DW=512, BRAM_SIZE=32'h10_0000)
(
    input clk, resetn,

    //==================  This is an AXI4-master interface  ===================

    // "Specify write address"              -- Master --    -- Slave --
    output reg [AW-1:0]                     M_AXI_AWADDR,
    output                                  M_AXI_AWVALID,
    output     [7:0]                        M_AXI_AWLEN,
    output     [2:0]                        M_AXI_AWSIZE,
    output     [IW-1:0]                     M_AXI_AWID,
    output     [1:0]                        M_AXI_AWBURST,
    output                                  M_AXI_AWLOCK,
    output     [3:0]                        M_AXI_AWCACHE,
    output     [3:0]                        M_AXI_AWQOS,
    output     [2:0]                        M_AXI_AWPROT,
    input                                                   M_AXI_AWREADY,

    // "Write Data"                         -- Master --    -- Slave --
    output     [DW-1:0]                     M_AXI_WDATA,
    output     [(DW/8)-1:0]                 M_AXI_WSTRB,
    output                                  M_AXI_WVALID,
    output                                  M_AXI_WLAST,
    input                                                   M_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    input[1:0]                                              M_AXI_BRESP,
    input[IW-1:0]                                           M_AXI_BID,
    input                                                   M_AXI_BVALID,
    output                                  M_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    output     [AW-1:0]                     M_AXI_ARADDR,
    output                                  M_AXI_ARVALID,
    output     [2:0]                        M_AXI_ARPROT,
    output                                  M_AXI_ARLOCK,
    output     [IW-1:0]                     M_AXI_ARID,
    output     [2:0]                        M_AXI_ARSIZE,
    output     [7:0]                        M_AXI_ARLEN,
    output     [1:0]                        M_AXI_ARBURST,
    output     [3:0]                        M_AXI_ARCACHE,
    output     [3:0]                        M_AXI_ARQOS,
    input                                                   M_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    input[DW-1:0]                                           M_AXI_RDATA,
    input[IW-1:0]                                           M_AXI_RID,
    input                                                   M_AXI_RVALID,
    input[1:0]                                              M_AXI_RRESP,
    input                                                   M_AXI_RLAST,
    output                                  M_AXI_RREADY
    //==========================================================================
);

localparam DB               = (DW/8);
localparam BURST_SIZE       = 256;
localparam TOTAL_BURSTS     = BRAM_SIZE / BURST_SIZE;
localparam CYCLES_PER_BURST = BURST_SIZE / DB;


//=============================================================================
// This function swaps big-endian to little-endian or vice-versa
//=============================================================================
function [31:0] little_endian (input [31:0] value);
    little_endian = {value[7:0], value[15:8], value[23:16], value[31:24]};
endfunction
//=============================================================================



reg[7:0]  cycle_within_burst;
reg       awsm_state;
reg       wsm_state;
reg[31:0] w_burst_count, aw_burst_count;
reg[31:0] data;

assign M_AXI_AWSIZE  = $clog2(DB);
assign M_AXI_AWLEN   = CYCLES_PER_BURST-1;
assign M_AXI_AWVALID = (awsm_state == 1);
assign M_AXI_AWBURST = 1;
assign M_AXI_AWID    = 0;
assign M_AXI_AWLOCK  = 0;
assign M_AXI_AWCACHE = 0;
assign M_AXI_AWQOS   = 0;
assign M_AXI_AWPROT  = 0;
assign M_AXI_WSTRB   = -1;
assign M_AXI_WLAST   = (cycle_within_burst == CYCLES_PER_BURST-1);
assign M_AXI_WVALID  = (wsm_state == 1);
assign M_AXI_BREADY  = 1;

// M_AXI_WDATA is sequential 32-bit integers
assign M_AXI_WDATA[ 0 *32 +: 32] = little_endian(data +  0);
assign M_AXI_WDATA[ 1 *32 +: 32] = little_endian(data +  1);
assign M_AXI_WDATA[ 2 *32 +: 32] = little_endian(data +  2);
assign M_AXI_WDATA[ 3 *32 +: 32] = little_endian(data +  3);
assign M_AXI_WDATA[ 4 *32 +: 32] = little_endian(data +  4);
assign M_AXI_WDATA[ 5 *32 +: 32] = little_endian(data +  5);
assign M_AXI_WDATA[ 6 *32 +: 32] = little_endian(data +  6);
assign M_AXI_WDATA[ 7 *32 +: 32] = little_endian(data +  7);
assign M_AXI_WDATA[ 8 *32 +: 32] = little_endian(data +  8);
assign M_AXI_WDATA[ 9 *32 +: 32] = little_endian(data +  9);
assign M_AXI_WDATA[10 *32 +: 32] = little_endian(data + 10);
assign M_AXI_WDATA[11 *32 +: 32] = little_endian(data + 11);
assign M_AXI_WDATA[12 *32 +: 32] = little_endian(data + 12);
assign M_AXI_WDATA[13 *32 +: 32] = little_endian(data + 13);
assign M_AXI_WDATA[14 *32 +: 32] = little_endian(data + 14);
assign M_AXI_WDATA[15 *32 +: 32] = little_endian(data + 15);


// We're not going to use the read interface
assign M_AXI_ARADDR  = 0; 
assign M_AXI_ARVALID = 0; 
assign M_AXI_ARPROT  = 0;     
assign M_AXI_ARLOCK  = 0;  
assign M_AXI_ARID    = 0;   
assign M_AXI_ARSIZE  = 0;  
assign M_AXI_ARLEN   = 0; 
assign M_AXI_ARBURST = 0;  
assign M_AXI_ARCACHE = 0;   
assign M_AXI_ARQOS   = 0; 
assign M_AXI_RREADY  = 0;

//==============================================================================
// This strobes the "start" signal a few clock-cycles after we come out of 
// reset
//==============================================================================
reg[15:0] start_timer;
always @(posedge clk) begin
    if (resetn == 0)
        start_timer <= 1000;
    else if (start_timer)
        start_timer <= start_timer -1;
end

wire start = (start_timer == 1);
//==============================================================================

//=============================================================================
// This block drives the AW channel, sending one write-request for every 
// burst of data we want to send
//=============================================================================
always @(posedge clk) begin

    case (awsm_state)

        0:  if (start) begin
                aw_burst_count <= 1;
                M_AXI_AWADDR   <= 0;
                awsm_state     <= 1;
            end

        1:  if (M_AXI_AWVALID & M_AXI_AWREADY) begin
                if (aw_burst_count == TOTAL_BURSTS)
                    awsm_state <= 0;
                else begin
                    M_AXI_AWADDR   <= M_AXI_AWADDR + BURST_SIZE;
                    aw_burst_count <= aw_burst_count + 1;
                end
               
            end
    endcase
end
//=============================================================================


always @(posedge clk) begin

    case(wsm_state)
        0:  if (start) begin
                data               <= 0;
                w_burst_count      <= 1;
                cycle_within_burst <= 0;
                wsm_state          <= 1;
            end

        1:  if (M_AXI_WVALID & M_AXI_WREADY) begin
                data               <= data + 16;
                cycle_within_burst <= cycle_within_burst + 1;
                if (M_AXI_WLAST) begin
                    cycle_within_burst <= 0;
                    if (w_burst_count == TOTAL_BURSTS)
                        wsm_state <= 0;
                    else
                        w_burst_count <= w_burst_count + 1;
                end
            end

    endcase
end


endmodule

