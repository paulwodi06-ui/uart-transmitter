module uart_tx #(
    parameter CLOCK_FREQ = 1000000,
    parameter BAUD_RATE = 100000
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic [7:0] data_in,

    output logic       tx,
    output logic       busy
);

    localparam int CLKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;

    localparam int BAUD_COUNT_WIDTH =
        (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT) : 1;

    localparam logic [BAUD_COUNT_WIDTH-1:0] BAUD_MAX =
        BAUD_COUNT_WIDTH'(CLKS_PER_BIT - 1);

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state;

    logic [7:0] data_reg;
    logic [2:0] bit_count;
    logic [BAUD_COUNT_WIDTH-1:0] baud_count;

    always_ff @(posedge clk) begin 
        // We're using an active-HIGH, synchronous reset. When rst = 1, the registers take their reset values at the next rising clock edge.
        if (rst) begin
            state      <= IDLE;
            baud_count <= 0;
            bit_count  <= 0;
            data_reg   <= 0;
            tx         <= 1;
            busy       <= 0;
        end
        else begin // This contains the normal operation of our transmitter when reset isn't active.
            case (state)
                IDLE: begin
                    tx   <= 1;
                    busy <= 0;

                    if (tx_start) begin 
                        data_reg   <= data_in;
                        state      <= START;
                        baud_count <= 0;
                        bit_count  <= 0;
                        busy <= 1;
                    end
                end

                START: begin
                    tx   <= 0;
                    busy <= 1;

                    if (baud_count == BAUD_MAX) begin // equivalent to if (baud_count == 9)
                        baud_count <= 0;
                        state      <= DATA;
                    end
                    else begin
                        baud_count <= baud_count + 1;
                    end
                end

                DATA: begin
                    tx   <= data_reg[bit_count];
                    busy <= 1;

                    if (baud_count == BAUD_MAX) begin
                        baud_count <= 0;

                        if (bit_count == 7) begin
                            state <= STOP;
                        end
                        else begin
                            bit_count <= bit_count + 1;
                        end

                    end
                    else begin
                        baud_count <= baud_count + 1;
                    end
                end

                STOP: begin
                    tx   <= 1;
                    busy <= 1;

                    if (baud_count == BAUD_MAX) begin
                        baud_count <= 0;
                        state      <= IDLE;
                    end
                    else begin
                        baud_count <= baud_count + 1;
                    end
                end

                    default: state <= IDLE;
                endcase
            end
        end


endmodule
