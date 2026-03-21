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
     out the HSI bus, synhronous with the hsi_clk.

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


module smem_writer_hsi_s1
(
    

    (* X_INTERFACE_INFO      = "xilinx.com:signal:clock:1.0 clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET resetn, ASSOCIATED_BUSIF axis_out" *)
    input       clk,
    input       resetn,

    // When start strobes high, this is the chunk-index in the ABM
    input[31:0] i_chunk_index,

    // When start strobes high, this holds 1 chunk of data to write to SMEM.
    // The individual 32-bit words in this field must be in little-endian 
    // byte order    
    input[2047:0] i_smem_data,

    // When this goes high, we will start pushing data to the output stream
    input       i_start,
    
    // This is high when we're ready for someone to tell us to start
    output      ready,

    // This is asserted when the entire chunk has been flushed the SMEM
    // on the sensor chip
    output      done,

    //----------------------------------------------------------
    // This feeds a FIFO
    //----------------------------------------------------------
    output reg [31:0] axis_out_tdata,
    output            axis_out_tuser,
    output            axis_out_tlast,
    output            axis_out_tvalid,
    input             axis_out_tready,
    //----------------------------------------------------------

    // This strobes high every time a 32-bit word gets written
    // to the FIFO that eventually outputs to SMEM
    output           smem_write_stb,
    
    // The FIFO reader tells us when the FIFO is empty
    input            fifo_empty

);

genvar i;

// The "smem_data" field is 2048 bits wide: 1 chunk of data for one bank/row
localparam DW = 2048;

// Number of 32-bit words that will fit into smem_data
localparam WORDS_PER_CHUNK = DW / 32;

// For a 2048 bit chunk, there are 64 words per chunk, numbered 0 thru 63
localparam LAST_WORD = WORDS_PER_CHUNK - 1;


// Our 256 bytes of smem_data<N> contain a total of 64 32-bit words. This
// value will increment from 0 to 63
reg[5:0] word_number;

//-----------------------------------------------------------------------------
// These are registered versions of the corresponding input ports
//-----------------------------------------------------------------------------
reg[31:0] element[0:WORDS_PER_CHUNK-1];
reg       start;
reg[ 2:0] bank;
reg[ 8:0] row;
//-----------------------------------------------------------------------------


//=============================================================================
// This function swaps big-endian to little-endian or vice-versa
//=============================================================================
function [31:0] byte_swap (input [31:0] value);
    byte_swap = {value[7:0], value[15:8], value[23:16], value[31:24]};
endfunction
//=============================================================================


//=============================================================================
// Register the input fields to make timing closure simpler
//=============================================================================
always @(posedge clk) begin
    if (resetn == 0) begin
        bank  <= 0;
        row   <= 0;
        start <= 0;
    end

    else begin
        bank  <= i_chunk_index[ 2:0];
        row   <= i_chunk_index[11:3];
        start <= i_start;
    end
end
//=============================================================================


//=============================================================================
// This registers "smem_data" into an array of 64 32-bit words
//=============================================================================
for (i=0; i<WORDS_PER_CHUNK; i=i+1) begin
    always @(posedge clk) element[i] <= i_smem_data[i*32 +: 32];
end
//=============================================================================


//=============================================================================
// This state machine waits for someone to tell us to start, then:
//   (1) Drives the chunk_index out the AXI stream (with TUSER set to 1)
//   (2) Drives 64 32-bit words out the AXI stream (with TUSER set to 0)
//  
// The last 32-bit word driven out has the TLAST bit set on the AXI stream
//=============================================================================
reg[1:0] fsm_state;
localparam FSM_IDLE      = 0;
localparam FSM_EMIT_CMD  = 1;
localparam FSM_EMIT_DATA = 2;
//-----------------------------------------------------------------------------
always @(posedge clk) begin
    if (resetn == 0) begin
        fsm_state <= 0;
    end

    else case(fsm_state)

        // Wait for someone to tell us to start
        FSM_IDLE:
            if (start) fsm_state <= FSM_EMIT_CMD;

        // Wait for the {row, bank} command word to be accepted
        FSM_EMIT_CMD:
            if (axis_out_tvalid & axis_out_tready) begin
                word_number <= 0;
                fsm_state   <= FSM_EMIT_DATA;
            end

        // Wait for each ABM word to be accepted
        FSM_EMIT_DATA:
            if (axis_out_tvalid & axis_out_tready) begin
                if (word_number == LAST_WORD)
                    fsm_state <= FSM_IDLE;
                else
                    word_number <= word_number + 1;
            end

    endcase

end
//-----------------------------------------------------------------------------
assign axis_out_tuser  = (fsm_state == FSM_EMIT_CMD);

assign axis_out_tlast  = (fsm_state == FSM_EMIT_DATA)
                       & (word_number == LAST_WORD);

assign axis_out_tvalid = (fsm_state != FSM_IDLE && resetn == 1); 

// This strobes high every time a 32-bit word is written to the FIFO
assign smem_write_stb = (fsm_state == FSM_EMIT_DATA)
                      & axis_out_tvalid & axis_out_tready;
//=============================================================================
 

//=============================================================================
// When we're driving data out of the AXI stream, tdata is always either
// the SMEM {row, bank}, or the current data-word.   The data arriving at the
// input of this module is in little-endian byte order.  The HSI bus expects
// data to be in big-endian byte order, so we swap the byte order here
//=============================================================================
always @* begin
    case (fsm_state)
        FSM_EMIT_CMD:  axis_out_tdata = {row, bank};
        FSM_EMIT_DATA: axis_out_tdata = byte_swap(element[word_number]);
        default:       axis_out_tdata = 0;
    endcase
end
//=============================================================================

// We're ready to accept another chunk of data when the state machine is idle
assign ready = (fsm_state == FSM_IDLE) & (start == 0) & (i_start == 0);

// All chunks have been written to SMEM when this is asserted
assign done = (ready & fifo_empty);


endmodule