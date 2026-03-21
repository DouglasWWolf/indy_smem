/*
===============================================================================
                   ------->  Revision History  <------
===============================================================================

   Date    Who  Ver  Changes
===============================================================================
18-Feb-26  DWW    1  Initial creation
===============================================================================
*/


/*
     This module writes a chunk (i.e., 256 bytes) of data to SMEM via the
     HSI interface as a "command word" followed by a series of 64 32-bit data  
     words.  The "command word" is simply the {row, bank} where this chunk
     of data will be stored in SMEM.

     When the 'start' input strobes high, this module begins sending smem_data<N>
     to a FIFO, and on the other side of that FIFO is logic that clocks the data
     out the HSI bus, synhronous with the clk.

     When this module is ready to accept more data (i.e., when it's ready for 
     someone to assert 'start'), the 'ready' signal is asserted.

     When this module is completely idle (i.e., all data has been clocked out 
     the HSI bus and has been written to SMEM), the 'done' signal is asserted.

     If the 'async_enable' line is asserted at any point, the HSI bus pauses
     until 'async_enable' is de-asserted.  


    To understand this module, it's useful to know that an ABM (Activation Bitmap)
    is a blob of data that is carved into 256 byte "chunks" of data. There is
    one 256 byte chunk for each combination of sensor-chip row and bank.  (There
    are 512 rows and 8 banks, for a total of 4096 chunks)

    One of the inputs to this module is "chunk_index".  A single chunk of incoming
    data is the aforementioned 256 bytes (i.e., 2048 bits). The "chunk_index" is simply
    a sequential integer that indicates which chunk (of the ABM) is being processed.
    The order of chunks of data in an ABM is:
           Row 0  : bank0, bank1, bank2, bank3, bank4, bank5, bank6, bank7
           Row 1  : bank0, bank1, bank2, bank3, bank4, bank5, bank6, bank7
           Row 2  : bank0, bank1, bank2, bank3, bank4, bank5, bank6, bank7
           (...)
           Row 511: bank0, bank1, bank2, bank3, bank4, bank5, bank6, bank7
    
    The SMEM row and bank can be derived from the "chunk_index" like this:
        Bank = chunk_index[ 2:0]
        Row  = chunk_index[11:3]

    It's worth noting that the order of chunks of data in sensor-chip SMEM is:
        Bank 0: row 0, row 1, row2, row3, [...], row 511
        Bank 1: row 0, row 1, row2, row3, [...], row 511
        Bank 2: row 0, row 1, row2, row3, [...], row 511
            (...)
        Bank 7: row 0, row 1, row2, row3, [...], row 511
*/


module smem_writer_hsi_s2 # (parameter HSI_IDLE_COUNT = 8, REGISTER_COUNT = 2)
(
    (* X_INTERFACE_INFO      = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF axis_in" *)
    input       clk,

    // This AXI stream arrives to us from a FIFO
    input[31:0] axis_in_tdata,
    input       axis_in_tuser,
    input       axis_in_tlast,
    input       axis_in_tvalid,
    output      axis_in_tready,

    //----------------------------------------------------------
    // These should all be packed into FPGA IOBs
    //----------------------------------------------------------
    output        chip_hsi_pclk,
    output [31:0] chip_hsi_data,
    output        chip_hsi_cmd,
    output        chip_hsi_valid,
    output        chip_hsi_eop,
    //----------------------------------------------------------

    // SMEM write-enable: when this is low, SMEM updating is paused
    input            smem_wen,

    // This is asserted when no data is availble to read on the input stream
    output           fifo_empty
);
genvar i;

localparam LAST_REG_IDX = REGISTER_COUNT - 1;

// The HSI bus current values and next values
reg[31:0] current_data,  next_data;  
reg       current_cmd,   next_cmd;   
reg       current_valid, next_valid;
reg       current_eop,   next_eop;


//=============================================================================
// The HSI psuedo-clock is half the frequency of the clock that drives this
// module
//=============================================================================
reg hsi_pclk, hsi_pclk_falling_edge;
//-----------------------------------------------------------------------------
always @(posedge clk) begin
    if (hsi_pclk) begin
        hsi_pclk              <= 0;
        hsi_pclk_falling_edge <= 1;
    end else begin
        hsi_pclk              <= 1;
        hsi_pclk_falling_edge <= 0;        
    end
end
//=============================================================================

// We change the bus values only on the falling edge of hsi_pclk
wire[31:0] hsi_data  = (hsi_pclk_falling_edge) ? next_data  : current_data;
wire       hsi_cmd   = (hsi_pclk_falling_edge) ? next_cmd   : current_cmd;
wire       hsi_valid = (hsi_pclk_falling_edge) ? next_valid : current_valid;
wire       hsi_eop   = (hsi_pclk_falling_edge) ? next_eop   : current_eop;


//=============================================================================
// The IOBs where the chip_hsi_* signals live are on the outside edges of the
// FPGA.   We multi-register those signals to ease timing of signals that need
// to get from the center of the FPGA to the edge of the FPGA
//=============================================================================
reg       pre_pclk  [0:REGISTER_COUNT-1];
reg[31:0] pre_data  [0:REGISTER_COUNT-1];  
reg       pre_cmd   [0:REGISTER_COUNT-1];   
reg       pre_valid [0:REGISTER_COUNT-1];
reg       pre_eop   [0:REGISTER_COUNT-1];

for (i=1; i <= LAST_REG_IDX ; i=i+1) begin
    always @(posedge clk) begin
        pre_pclk [i] <= pre_pclk [i-1];
        pre_data [i] <= pre_data [i-1];
        pre_cmd  [i] <= pre_cmd  [i-1];
        pre_valid[i] <= pre_valid[i-1];
        pre_eop  [i] <= pre_eop  [i-1];
    end
end
//=============================================================================




//=============================================================================
// Feed our hsi_* signals into the register chain, and extract our chip_hsi_*
// signals out the other end of the chain.  Having a few registers between us
// and the pin (which is at the edge of the FPGA) make timing closure easier.
//=============================================================================
always @(posedge clk) begin
    pre_pclk [0] <= hsi_pclk;
    pre_data [0] <= hsi_data;
    pre_cmd  [0] <= hsi_cmd;
    pre_eop  [0] <= hsi_eop;
    pre_valid[0] <= hsi_valid;
end
    
assign chip_hsi_pclk  = pre_pclk [LAST_REG_IDX]; 
assign chip_hsi_data  = pre_data [LAST_REG_IDX];  
assign chip_hsi_cmd   = pre_cmd  [LAST_REG_IDX];  
assign chip_hsi_eop   = pre_eop  [LAST_REG_IDX];  
assign chip_hsi_valid = pre_valid[LAST_REG_IDX];   
//=============================================================================

//=============================================================================
// This block reads data from the FIFO and buffers it.  When  our state
// machine that feeds the HSI bus needs more data, it will fetch it from our
// buffered values
//=============================================================================
reg[1:0] buf_state = 0;
wire buf_empty = (buf_state[0] == buf_state[1]);
wire buf_full  = (buf_state[0] != buf_state[1]);

reg       buf_eop;
reg       buf_cmd;
reg[31:0] buf_data;
//-----------------------------------------------------------------------------
always @(posedge clk) begin
    if (axis_in_tvalid & axis_in_tready) begin
        buf_eop      <= axis_in_tlast;
        buf_cmd      <= axis_in_tuser;
        buf_data     <= axis_in_tdata;
        buf_state[0] <= ~buf_state[0];
    end
end

// We're ready to accept new data from the FIFO when our buffer is empty
assign axis_in_tready = buf_empty;

// This is asserted when there is no data available in the FIFO
assign fifo_empty = (axis_in_tready == 1 && axis_in_tvalid == 0);
//=============================================================================


//=============================================================================
// This state machine is responsible for fetching buffered data and writing
// it to the HSI bus on falling edges of "hsi_pclk"
//=============================================================================
localparam FSM_WAIT_FALLING_EDGE = 1;
localparam FSM_WAIT_IDLE         = 2;
reg[1:0] fsm_state = FSM_WAIT_FALLING_EDGE;
reg[3:0] idle_counter;

always @(posedge clk) begin
   
    case (fsm_state) 

        // We change outgoing data on the falling edges of hsi_pclk
        FSM_WAIT_FALLING_EDGE:
            if (hsi_pclk_falling_edge) begin
                if (next_eop) begin
                    next_eop     <= 0;
                    next_cmd     <= 0;
                    next_data    <= 0;
                    next_valid   <= 0;
                    idle_counter <= HSI_IDLE_COUNT;
                    fsm_state    <= FSM_WAIT_IDLE;
                end else if (buf_full & smem_wen) begin
                    next_eop     <= buf_eop;
                    next_cmd     <= buf_cmd;
                    next_data    <= buf_data;
                    next_valid   <= 1;
                    buf_state[1] <= ~buf_state[1];
                end else begin
                    next_eop     <= 0;
                    next_cmd     <= 0;
                    next_data    <= 0;
                    next_valid   <= 0;
                end
            end

        FSM_WAIT_IDLE:
            if (idle_counter == 0)
                fsm_state <= FSM_WAIT_FALLING_EDGE;
            else if (hsi_pclk_falling_edge)
                idle_counter <= idle_counter - 1;

    endcase
end
//=============================================================================


//=============================================================================
// On the falling edge of hsi_pclk, latch the new outgoing bus signals
//=============================================================================
always @(posedge clk) begin
    if (hsi_pclk_falling_edge) begin
        current_cmd   <= next_cmd;
        current_data  <= next_data;
        current_eop   <= next_eop;
        current_valid <= next_valid;
    end
end
//=============================================================================


endmodule