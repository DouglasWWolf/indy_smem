/*
    It's very common to have two modules in a master/slave arrangement where 
    the master module strobes a signal high to tell the slave "hey, go do 
    your thing!" and the slave immediately changes a status bit to indicate
    that it's busy doing the thing.  

    The master module waits for the slave's status to change to "no longer 
    busy" before continung on to do something else.

    If the master and slave are in different clock domains, the signal synchro
    process will take several cycles, meaning that the slave's "Hey, I'm busy!"
    signal won't reach the master immediatly.

    This module overcomes that obstacle by driving an output signal to the
    "active" state immediately upon seensing the "Hey go do something! strobe
    and not allowing it to become inactive until the slave's state indicates
    that it is genuinely inactive.

*/

module idle_busy_cdc # (parameter ACTIVE =  1)
(
    input   master_clk,
    input   master_trigger,
    input   master_resetn,
    
    input   slave_clk,
    input   slave_state,

    // This is synchronous to master_clk
    output  output_state
);

// This is "slave_state", synchronized to "master_clk"
wire sync_slave_state;


// One bit state of our state machine.   
// In state 0, we're waiting for a trigger.
// In state 1, we've been triggered and are waiting for the slave
// to tell us it's busy
reg fsm_state;

always @(posedge master_clk) begin

    // If we're in reset, start over
    if (resetn == 0)
        fsm_state <= 0;

    // Otherwise, we're not in reset...
    else case(fsm_state)
        
        // If we saw the trigger, go wait for sync_slave_state
        // to "catch_up" to the value we expect it to be.
        0:  if (master_trigger)
                fsm_state <= 1;

        // We're waiting for "slave_state" to get to its "triggered" value
        1:  if (sync_slave_state == ACTIVE)
                fsm_state <= 0;
    endcase
end

// The output state is "ACTIVE" while the trigger is active or after a trigger
// has occured and we are waiting for "sync_slave_state" to get to the ACTIVE 
// state.
//
// Output state reflects the slave's output state when we're idle and not 
// triggered
assign output_state = (master_trigger | fsm_state) ? ACTIVE : sync_slave_state;


//=============================================================================
// Synchronize "slave_state" into "sync_slave_state"
//=============================================================================
xpm_cdc_single # (.SRC_INPUT_REG (0)) i_sync_edge_carrier
(
    .src_clk (slave_clk       ),
    .src_in  (slave_state     ),
    .dest_clk(master_clk      ),
    .dest_out(sync_slave_state)
);
//=============================================================================


endmodule