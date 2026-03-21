/*

===============================================================================
                   ------->  Revision History  <------
===============================================================================

   Date    Who  Ver  Changes
===============================================================================
20-Feb-26  DWW    1  Initial creation
===============================================================================
        
    This module provides an interface to a Clock Wizard to allow its
    output frequency to be changed and measured

*/


module clock_mgr # (parameter DW=32, AW=12, FREQ_HZ = 250000000)
(
    (* X_INTERFACE_INFO      = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET resetn, ASSOCIATED_BUSIF M_AXI" *)
    input clk,
    input resetn,

    // These are used to set the clock's frequency divisor registers
    input [31:0] div_in,    

    // These are the clock's current VCO and frequency divisor registers
    output reg[31:0] vco_out, div_out,

    // When this strobes high, vco_in and div_in are written to the clock wizard
    input  configure,

    // The clock who's frequency we want to measure
    input  test_clk,

    // The value of FREQ_HZ
    output[31:0] ref_clock_freq,

    // The measured frequency of the test_clk
    output[31:0] freq_out,

    //====================  An AXI-Lite Master Interface  ======================
    // "Specify write address"          -- Master --    -- Slave --
    output [AW-1:0]                     M_AXI_AWADDR,
    output                              M_AXI_AWVALID,
    output    [2:0]                     M_AXI_AWPROT,
    input                                               M_AXI_AWREADY,

    // "Write Data"                     -- Master --    -- Slave --
    output [DW-1:0]                     M_AXI_WDATA,
    output [DW/8-1:0]                   M_AXI_WSTRB,
    output                              M_AXI_WVALID,
    input                                               M_AXI_WREADY,

    // "Send Write Response"            -- Master --    -- Slave --
    input  [1:0]                                        M_AXI_BRESP,
    input                                               M_AXI_BVALID,
    output                              M_AXI_BREADY,

    // "Specify read address"           -- Master --    -- Slave --
    output [AW-1:0]                     M_AXI_ARADDR,
    output [   2:0]                     M_AXI_ARPROT,
    output                              M_AXI_ARVALID,
    input                                               M_AXI_ARREADY,

    // "Read data back to master"       -- Master --    -- Slave --
    input [DW-1:0]                                      M_AXI_RDATA,
    input                                               M_AXI_RVALID,
    input [1:0]                                         M_AXI_RRESP,
    output                              M_AXI_RREADY
    //==========================================================================
);

// These are taken from the register definitions in Xilinx/AMD PG065
localparam  SLAVE_VCO_REG    = 10'h200;
localparam  SLAVE_DIV_REG    = 10'h208;
localparam  SLAVE_CONFIG_REG = 10'h25C;

//==================  The AXI Master Control Interface  ====================
// AMCI signals for performing AXI writes
reg [AW-1:0]  AMCI_WADDR;
reg [DW-1:0]  AMCI_WDATA;
reg           AMCI_WRITE;
wire[   1:0]  AMCI_WRESP;
wire          AMCI_WIDLE;

// AMCI signals for performing AXI reads
reg [AW-1:0]  AMCI_RADDR;
reg           AMCI_READ ;
wire[DW-1:0]  AMCI_RDATA;
wire[   1:0]  AMCI_RRESP;
wire          AMCI_RIDLE;
//==========================================================================

// The outside world needs to know the frequency of the reference clock
assign ref_clock_freq = FREQ_HZ;

// We read these two registers from the clock-wizard shortly after
// coming out of reset
reg[31:0] initial_vco, initial_div;

// Bit 0 says "We've read the two configuration registers"
// Bit 1 says "We've copied the two config registers to the output ports"
reg [1:0] initialized;

// This is a countdown timer from the moment we come out of reset
reg [15:0] initialization_delay;

//==========================================================================
// This is the initialization state machine.  A few cycles after we come
// out of reset, this state machine will read the two clock-definition
// registers, store them in "initial_vco" and "initial_div".   We then set
// "initialized[0]" to indicate that those fields contains valid data.
//==========================================================================
reg[ 1:0] ism_state;
//--------------------------------------------------------------------------
always @(posedge clk) begin

    // This strobes high for a single clock-cycle at a time
    AMCI_READ <= 0;

    if (resetn == 0) begin
        initialized[0]       <= 0;
        initialization_delay <= 250;
        ism_state            <= 0;
    end

    else case(ism_state)
        

        // Wait for a few clock-cycles to pass after we come out of reset.
        // When that delay is done, start a read the VCO configuration 
        // register.
        0:  if (initialization_delay)
                initialization_delay <= initialization_delay - 1;
            else begin
                AMCI_RADDR <= SLAVE_VCO_REG;
                AMCI_READ  <= 1;
                ism_state  <= 1;
            end

        // When that read is complete, store the value, and start a read of
        // the frequency-divisor register
        1:  if (AMCI_RIDLE) begin
                initial_vco <= AMCI_RDATA;
                AMCI_RADDR  <= SLAVE_DIV_REG;
                AMCI_READ   <= 1;
                ism_state   <= 2;
            end

        // When that read is complete, store the result
        2:  if (AMCI_RIDLE) begin
                initial_div <= AMCI_RDATA;
                ism_state   <= 3;
            end

        // Finally, set the flag saying "we've read both clock def registers"
        3:  initialized[0] <= 1;

    endcase
end
//==========================================================================




//==========================================================================
// This state machine updates the two configuration registers in the clock
// wizard, then writes to the appropriate clock-wizard register to tell
// it to update the clock frequency in accordance with the new settings.
//==========================================================================
reg[1:0] fsm_state;
//--------------------------------------------------------------------------
always @(posedge clk) begin

    // This strobes high for a single cycle at a time
    AMCI_WRITE <= 0;

    // If we need to copy the initial settings to the output ports, do so
    if (initialized == 2'b01) begin
        vco_out        <= initial_vco;
        div_out        <= initial_div;
        initialized[1] <= 1;
    end

    if (resetn == 0) begin
        fsm_state      <= 0;
        initialized[1] <= 0;
    end

    else case(fsm_state) 
        
        // Send the clock-frequency divisor to the Clock Wizard
        0:  if (configure) begin
                AMCI_WADDR <= SLAVE_DIV_REG;
                AMCI_WDATA <= div_in;
                AMCI_WRITE <= 1;
                fsm_state  <= 1;
            end

        // When that write is complete, update div_out and write
        // a "start configuration" to the appropriate register in
        // the clock-wizard
        1:  if (AMCI_WIDLE) begin
                div_out    <= AMCI_WDATA;
                AMCI_WADDR <= SLAVE_CONFIG_REG;
                AMCI_WDATA <= 3;
                AMCI_WRITE <= 1;
                fsm_state  <= 2;
            end

        // When that write is complete, go back to idle
        2:  if (AMCI_WIDLE) fsm_state <= 0;

    endcase

end
//==========================================================================


//==========================================================================
// Instantiate a frequency counter
//==========================================================================
clock_mgr_freq_ctr # (.FREQ_HZ(FREQ_HZ)) frequency_counter
(
    .clk     (clk     ),
    .test_clk(test_clk),
    .freq_out(freq_out)
);
//==========================================================================


//==========================================================================
// This instantiates an AXI4-Lite master
//==========================================================================
axi4_lite_master # (.DW(DW), .AW(AW)) axi4_master
(
    // Clock and reset
    .clk            (clk),
    .resetn         (resetn),

    // AXI Master Control Interface for performing writes
    .AMCI_WADDR     (AMCI_WADDR),
    .AMCI_WDATA     (AMCI_WDATA),
    .AMCI_WRITE     (AMCI_WRITE),
    .AMCI_WRESP     (AMCI_WRESP),
    .AMCI_WIDLE     (AMCI_WIDLE),

    // AXI Master Control Interface for performing reads
    .AMCI_RADDR     (AMCI_RADDR),
    .AMCI_READ      (AMCI_READ ),
    .AMCI_RDATA     (AMCI_RDATA),
    .AMCI_RRESP     (AMCI_RRESP),
    .AMCI_RIDLE     (AMCI_RIDLE),

    // AXI4-Lite AW channel
    .AXI_AWADDR     (M_AXI_AWADDR ),
    .AXI_AWVALID    (M_AXI_AWVALID),
    .AXI_AWPROT     (M_AXI_AWPROT ),
    .AXI_AWREADY    (M_AXI_AWREADY),

    // AXI4-Lite W channel
    .AXI_WDATA      (M_AXI_WDATA  ),
    .AXI_WSTRB      (M_AXI_WSTRB  ),
    .AXI_WVALID     (M_AXI_WVALID ),
    .AXI_WREADY     (M_AXI_WREADY ),

    // AXI4-Lite B channel
    .AXI_BRESP      (M_AXI_BRESP  ),
    .AXI_BVALID     (M_AXI_BVALID ),
    .AXI_BREADY     (M_AXI_BREADY ),

     // AXI4-Lite AR channel
    .AXI_ARADDR     (M_AXI_ARADDR ),
    .AXI_ARPROT     (M_AXI_ARPROT ),
    .AXI_ARVALID    (M_AXI_ARVALID),
    .AXI_ARREADY    (M_AXI_ARREADY),

    .AXI_RDATA      (M_AXI_RDATA  ),
    .AXI_RVALID     (M_AXI_RVALID ),
    .AXI_RRESP      (M_AXI_RRESP  ),
    .AXI_RREADY     (M_AXI_RREADY )
);
//=============================================================================


endmodule


