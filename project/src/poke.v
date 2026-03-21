/*
    This is connected to a block of RAM via its AXI interface.   We divide that
    RAM is divide into 256 byte rows, and each row is divided into 64 four-byte 
    "entries".

    A single 256 byte row is comprised of four 64-byte data-cycles
    A single data-cycle is composed of 16 "entries".
*/
module poke # (parameter AW=20, DW=512, IW=2)
(

    input clk, resetn,

    // Rows are 0 though 4095
    input[31:0] row,

    // An entry within a row is 0 thru 63
    input[31:0] entry,

    // This is the value to stuff into that entry
    input[31:0] value,

    // We write the value to the specified row/entry on the rising edge
    input   start,
    
    // This is high when we're busy
    output  busy,

    //==================  This is an AXI4-master interface  ===================

    // "Specify write address"              -- Master --    -- Slave --
    output     [AW-1:0]                     M_AXI_AWADDR,
    output reg                              M_AXI_AWVALID,
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
    output reg                              M_AXI_WVALID,
    output                                  M_AXI_WLAST,
    input                                                   M_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    input[1:0]                                              M_AXI_BRESP,
    input[IW-1:0]                                           M_AXI_BID,
    input                                                   M_AXI_BVALID,
    output                                  M_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    output     [AW-1:0]                     M_AXI_ARADDR,
    output reg                              M_AXI_ARVALID,
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
genvar i;

localparam DB = DW/8;

// This is the address of the first entry in the row
wire[31:0] row_addr = row * 256;

// This is the byte offset (within the row) of the selected entry
wire[31:0] entry_offset = entry * 4;

// Force RAM address to be on a 64-byte boundary
wire[31:0] ram_addr = (row_addr + entry_offset) & 32'hFFFF_FFC0;

// There are 16 entries in a single data-cycle
wire[31:0] entry_index = entry & 32'hF;

// AW-channel constants
assign M_AXI_AWLEN   = 0;
assign M_AXI_AWADDR  = ram_addr;
assign M_AXI_AWSIZE  = $clog2(DB);
assign M_AXI_AWID    = 0;
assign M_AXI_AWBURST = 1;   
assign M_AXI_AWLOCK  = 0;
assign M_AXI_AWCACHE = 0;
assign M_AXI_AWQOS   = 0;
assign M_AXI_AWPROT  = 0;

// W-channel constants
assign M_AXI_WSTRB = -1;
assign M_AXI_WLAST =  1;

// B-channel constants
assign M_AXI_BREADY = (resetn == 1);

// AR-channel constants
assign M_AXI_ARADDR  = ram_addr;
assign M_AXI_ARPROT  = 0; 
assign M_AXI_ARLOCK  = 0;
assign M_AXI_ARID    = 0;
assign M_AXI_ARSIZE  = $clog2(DB);
assign M_AXI_ARLEN   = 0;
assign M_AXI_ARBURST = 1;  
assign M_AXI_ARCACHE = 0;  
assign M_AXI_ARQOS   = 0;

// R-channel constants
assign M_AXI_RREADY = (resetn == 1);


//=============================================================================
// This function swaps big-endian to little-endian or vice-versa
//=============================================================================
function [31:0] little_endian (input [31:0] value);
    little_endian = {value[7:0], value[15:8], value[23:16], value[31:24]};
endfunction
//=============================================================================



reg[31:0] data[0:15];

// Fill in M_AXI_WDATA with our array of data
for (i=0; i<16; i=i+1) begin
    assign M_AXI_WDATA[i * 32 +: 32] = data[i];
end

reg[2:0] fsm_state;

always @(posedge clk) begin
    
    if (resetn == 0) begin
        fsm_state     <= 0;
        M_AXI_ARVALID <= 0;
        M_AXI_AWVALID <= 0;
        M_AXI_WVALID  <= 0;
    end
    
    else case(fsm_state)
        
        // If we're told to start, issue a read of one 64-byte data-cycle
        0:  if (start) begin
                M_AXI_ARVALID <= 1;
                fsm_state     <= fsm_state + 1;
            end

        // Wait for the read to be accepted
        1:  if (M_AXI_ARVALID & M_AXI_ARREADY) begin
                M_AXI_ARVALID <= 0;
                fsm_state     <= fsm_state + 1;
            end

        // Wait for the data to arrive
        2:  if (M_AXI_RREADY & M_AXI_RVALID) begin
                data[ 0] <= M_AXI_RDATA[ 0 * 32 +: 32];
                data[ 1] <= M_AXI_RDATA[ 1 * 32 +: 32];
                data[ 2] <= M_AXI_RDATA[ 2 * 32 +: 32];
                data[ 3] <= M_AXI_RDATA[ 3 * 32 +: 32];
                data[ 4] <= M_AXI_RDATA[ 4 * 32 +: 32];
                data[ 5] <= M_AXI_RDATA[ 5 * 32 +: 32];
                data[ 6] <= M_AXI_RDATA[ 6 * 32 +: 32];
                data[ 7] <= M_AXI_RDATA[ 7 * 32 +: 32];
                data[ 8] <= M_AXI_RDATA[ 8 * 32 +: 32];
                data[ 9] <= M_AXI_RDATA[ 9 * 32 +: 32];
                data[10] <= M_AXI_RDATA[10 * 32 +: 32];
                data[11] <= M_AXI_RDATA[11 * 32 +: 32];
                data[12] <= M_AXI_RDATA[12 * 32 +: 32];
                data[13] <= M_AXI_RDATA[13 * 32 +: 32];
                data[14] <= M_AXI_RDATA[14 * 32 +: 32];
                data[15] <= M_AXI_RDATA[15 * 32 +: 32];
                
                data[entry_index] <= little_endian(value);
                M_AXI_AWVALID     <= 1;
                fsm_state         <= fsm_state + 1;
            end

        // Wait for the address to be accepted, then write the data
        3:  if (M_AXI_AWVALID & M_AXI_AWREADY) begin
                M_AXI_AWVALID <= 0;
                M_AXI_WVALID  <= 1;
                fsm_state     <= fsm_state + 1;
            end

        // Wait for the data to be accepted
        4:  if (M_AXI_WVALID & M_AXI_WREADY) begin
                M_AXI_WVALID <= 0;
                fsm_state    <= fsm_state + 1;
            end

        // Wait for the B-channel acknowlegement
        5:  if (M_AXI_BVALID & M_AXI_BREADY)
                fsm_state <= 0;

    endcase
end

assign busy = (fsm_state != 0) | (start);

endmodule