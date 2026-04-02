module secure_access_top (
    input wire clk,
    input wire rst_n,
    input wire btn_submit,
    input wire btn_change_pwd,
    input wire [7:0] dip_sw,


    output wire a, b, c, d, e, f, g,
    output wire com0, com1, com2, com3, 
    output wire [7:0] led,
    output wire buzzer
);

     wire sys_rst_n = ~rst_n;
    wire match_w;
    wire error_w;
    wire fsm_change_mode_w;
    wire reset_counter_w;
    wire start_timer_w;
    wire timer_done_w;
     wire [2:0] attempt_count_w;
    wire [2:0] system_status_w;

    // สายไฟจำลองสำหรับ LED
    wire [7:0] led_internal;

     verification_unit verif_inst (
        .clk(clk),
        .rst_n(sys_rst_n), 
        .dip_sw(dip_sw),
        .btn_submit(btn_submit), 
        .fsm_change_mode(fsm_change_mode_w),
        .match(match_w),
        .error(error_w)
    );

     counter_timer_unit timer_inst (
        .clk(clk),
        .rst_n(sys_rst_n), 
        .error_pulse(error_w),
        .reset_counter(reset_counter_w),
        .start_timer(start_timer_w),
        .attempt_count(attempt_count_w),
        .timer_done(timer_done_w)
    );

     control_unit_fsm fsm_inst (
        .clk(clk),
        .rst_n(sys_rst_n), 
        .match(match_w),
        .error(error_w),
        .btn_submit(btn_submit), 
        .attempt_count(attempt_count_w),
        .timer_done(timer_done_w),
        .btn_change_pwd(btn_change_pwd),
          .fsm_change_mode(fsm_change_mode_w),
        .reset_counter(reset_counter_w),
        .start_timer(start_timer_w),
        .system_status(system_status_w)
    );

     display_unit disp_inst (
        .clk(clk),
        .rst_n(sys_rst_n), 
        .system_status(system_status_w),
        .attempt_count(attempt_count_w),
          .btn_submit(btn_submit),
          .dip_sw(dip_sw),
        .a(a), .b(b), .c(c), .d(d), .e(e), .f(f), .g(g),
        .com0(com0), .com1(com1), .com2(com2), .com3(com3),
        .led(led),
          .buzzer(buzzer)
    );


endmodule