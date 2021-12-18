///
/// ForthSuper stack (FILO)
///
`ifndef FORTHSUPER_STACK
`define FORTHSUPER_STACK
`include "../source/forthsuper_if.sv"
typedef enum logic [1:0] { PUSH, POP, READ } stack_ops;
module stack #(
    parameter DEPTH = 64,
    parameter DSZ   = 32,
    parameter SSZ   = $clog2(DEPTH),
    parameter NEG1  = DEPTH - 1
    ) (
    ss_io           ss_if,         /// 32-bit stack bus
    input  logic    clk,           /// clock
    input  logic    rst,           /// reset
    input  logic    en             /// enable
    );
    logic [SSZ-1:0] sp_1, sp = 0; /// sp_1 = sp - 1
    logic [SSZ-1:0] ai;
    logic [DSZ-1:0] vi, vo;
    ///
    /// instance of EBR Single Port Memory
    ///
    pmi_ram_dq #(DEPTH, SSZ, DSZ, "noreg") ss (    /// noreg saves a cycle
        .Data      (vi),
        .Address   (ai),
        .Clock     (clk),
        .ClockEn   (1'b1),
        .WE        (ss_if.op == PUSH),
        .Reset     (rst),
        .Q         (vo)
    );
    always_comb begin
        sp_1 = sp + NEG1;
        case (ss_if.op)
        PUSH: begin
            ai      = sp;
            vi      = ss_if.t;         // push tos into stack
            ss_if.t = ss_if.vi;
        end
        POP: begin
            ai      = sp_1;
            ss_if.t = ss_if.s;
        end
        READ: begin
            ai = sp + vi;
        end
        endcase
    end
    ///
    /// using FF implies a pipedline design
    ///
    always_ff @(posedge clk) begin
        if (en) begin
            case (ss_if.op)
            PUSH: begin
                sp      <= sp + 1'b1;
                ss_if.s <= ss_if.t;
                $display("ss[%x] <- %x <- tos=%x", sp, ss_if.t, ss_if.vi);
            end                
            POP: begin
                sp      <= sp_1;
                ss_if.s <= vo;
                $display("ss[%x] -> %x -> tos=%x", sp_1, vo, ss_if.s);
            end
            READ: begin
                $display("%d <- ss[%x + %x]", vo, sp, vi);
            end
            endcase
        end
    end
endmodule: stack
///
/// Pseudo Dual-port stack (using EBR)
///
module dstack #(
    parameter DEPTH = 64,
    parameter DSZ   = 32,
    parameter SSZ   = $clog2(DEPTH),
    parameter NEG1  = DEPTH - 1
    ) (
    ss_io           ss_if,           /// 32-bit stack bus
    input  logic    clk,             /// clock
    input  logic    rst,             /// reset
    input  logic    en               /// enable
    );
    logic [SSZ-1:0] sp_1, sp = 0;   /// sp_1 = sp - 1
    logic [DSZ-1:0] vo;
    pmi_ram_dp #(
       .pmi_wr_addr_depth(DEPTH),
       .pmi_wr_addr_width(SSZ),
       .pmi_wr_data_width(DSZ),
       .pmi_rd_addr_depth(DEPTH),
       .pmi_rd_addr_width(SSZ),
       .pmi_rd_data_width(DSZ),
       .pmi_regmode("noreg")         // "reg"|"noreg"
       //.pmi_resetmode        ( ),  // "async"|"sync"
       //.pmi_init_file        ( ),  // string
       //.pmi_init_file_format ( ),  // "binary"|"hex"
       //.pmi_family           ( )   // "iCE40UP"|"common"
    ) ss (
       .Data      (ss_if.t),  // TOS (push ready)
       .WrAddress (sp),       // stack top pointer
       .RdAddress (sp_1),     // NOS pointer
       .WrClock   (clk),
       .RdClock   (clk),
       .WrClockEn (1'b1),
       .RdClockEn (1'b1),
       .WE        (ss_if.op == PUSH),
       .Reset     (rst),
       .Q         (vo)        // sp_1
    );
    ///
    /// TOS ready in current cycle
    ///
    always_comb begin
        sp_1 = sp + NEG1;
        case (ss_if.op)
        PUSH: ss_if.t = ss_if.vi;   // retain TOS
        POP:  ss_if.t = ss_if.s;    // pop NOS into TOS
        endcase
    end
    ///
    /// NOS ready in next cycle
    ///
    always_ff @(posedge clk) begin
        if (en) begin
            case (ss_if.op)
            PUSH: begin
                sp      <= sp + 1'b1;
                ss_if.s <= ss_if.t;
            end
            POP:  begin
                sp      <= sp_1;
                ss_if.s <= (sp_1 == NEG1) ? 'h0 : vo;
            end
            READ: begin
                $display("%d <- ss[%x + %x]", vo, sp, ss_if.vi);
            end
            endcase
        end
    end
endmodule: dstack
/*
///
/// Dual-port stack (using 3778 LUTs on iCE40UP5K, too expensive)
///
module dstack #(
    parameter DEPTH = 64,
    parameter DSZ   = 32,
    parameter SSZ   = $clog2(DEPTH),
    parameter NEG1  = DEPTH - 1
    ) (    
    ss_io           ss_if,           /// 32-bit stack bus
    input  logic    clk,             /// clock
    input  logic    rst,             /// reset
    input  logic    en               /// enable
    );
    logic [SSZ-1:0] sp_1, sp = 0;   /// sp_1 = sp - 1
    logic [DSZ-1:0] ram[DEPTH-1:0]; /// memory block 

    always_comb begin
        case (ss_if.op)
        PUSH: begin
            ss_if.s = ss_if.t;
            ss_if.t = ss_if.vi;
        end
        POP: begin
            ss_if.t = ss_if.s;
            ss_if.s = ram[sp_1];
        end
        endcase
        sp_1 = sp + NEG1;
    end
    // writing to the RAM
    always_ff @(posedge clk) begin
        case (ss_if.op)
        PUSH: begin
            ram[sp] <= ss_if.vi;
            sp      <= sp + 1'b1;
        end
        POP: begin
            sp      <= sp + NEG1;
        end
        endcase
    end
endmodule: dstack
*/
`endif // FORTHSUPER_STACK
