module dump();
    initial begin
        $dumpfile ("edu_tpu.vcd");
        $dumpvars (0, edu_tpu);
        #1;
    end
endmodule