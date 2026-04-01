module control_unit_fsm (
input wire clk,

input wire rst_n,

input wire match,

input wire error,

input wire btn_submit,

input wire [2:0] attempt_count,
input wire timer_done,

input wire btn_change_pwd,

```
 output reg fsm_change_mode,
output reg reset_counter,
output reg start_timer,
output reg [2:0] system_status
```

);

```
localparam S_IDLE  = 3'd0;
localparam S_OPEN  = 3'd1;
localparam S_ERROR = 3'd2;
localparam S_LOCK  = 3'd3;
localparam S_SET   = 3'd4;

reg [2:0] current_state, next_state;

 // 1. กรองสัญญาณปุ่มเปลี่ยนรหัส
reg [18:0] db_count;
reg btn_sync_0, btn_sync_1, btn_clean, btn_prev;
wire change_pwd_pulse;

always @(posedge clk) begin
    btn_sync_0 <= btn_change_pwd;
    btn_sync_1 <= btn_sync_0;
    if (btn_sync_1 == btn_clean) db_count <= 0;
    else begin
	  db_count <= db_count + 1;
        if (db_count == 400000) begin
            btn_clean <= btn_sync_1;
            db_count <= 0;
        end
    end
end

 always @(posedge clk or negedge rst_n) begin
    if (!rst_n) btn_prev <= 1'b0;
    else        btn_prev <= btn_clean;
end
assign change_pwd_pulse = btn_clean & ~btn_prev;

 // 2. กรองสัญญาณปุ่ม Submit
wire btn_sub_debounced;
debounce db_sub_fsm (
    .clk(clk),
    .btn_in(btn_submit),
    .btn_out(btn_sub_debounced)
);

 reg btn_sub_prev;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) btn_sub_prev <= 1'b0;
    else        btn_sub_prev <= btn_sub_debounced;
end
wire submit_release = ~btn_sub_debounced & btn_sub_prev;

 // ------------------------------------------------------------------
ตัวจับเวลา 2 วินาที สำหรับหน้า Err โดยเฉพาะ
// ------------------------------------------------------------------
reg [25:0] err_timer;
reg err_timeout;

 always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        err_timer <= 0;
        err_timeout <= 0;
    end else if (current_state == S_ERROR) begin
        // นับไป 40,000,000 รอบคล็อก (บอร์ด 20MHz = 2 วินาที)
        if (err_timer < 26'd40_000_000) begin
            err_timer <= err_timer + 1'b1;
            err_timeout <= 0;
        end else begin
				 err_timeout <= 1'b1; // ครบ 2 วินาทีแล้ว ส่งสัญญาณเตือน!
        end
    end else begin
        err_timer <= 0;
        err_timeout <= 0;
    end
end

 // 3. FSM Memory
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else        current_state <= next_state;
end

 // 4. FSM Logic
always @(*) begin
    next_state = current_state;
    fsm_change_mode = 1'b0;
    reset_counter = 1'b0;
    start_timer = 1'b0;
    system_status = current_state;

	  case (current_state)
        S_IDLE: begin
            if (match) begin
                next_state = S_OPEN;
                reset_counter = 1'b1;
            end else if (error) begin
                if (attempt_count >= 3'd2) begin
                    next_state = S_LOCK;
                end else begin
                    next_state = S_ERROR;
                end
            end
        end

			S_ERROR: begin
            // (ในระหว่าง 2 วินาทีนี้ ต่อให้ผู้ใช้กดปุ่มรัวๆ ระบบก็จะเมินเฉยครับ)
            if (err_timeout) begin
                next_state = S_IDLE;
                // สังเกตว่าเราไม่สั่ง reset_counter = 1'b1;
                // เพื่อให้หลอดไฟ LED ยังจำจำนวนครั้งที่ผิดค้างไว้ได้ครับ
            end
        end

			S_LOCK: begin
            start_timer = 1'b1;
            if (timer_done) begin
                next_state = S_IDLE;
                reset_counter = 1'b1;
            end
        end

			S_OPEN: begin
            if (change_pwd_pulse) begin
                next_state = S_SET;
            end
        end

			S_SET: begin
            fsm_change_mode = 1'b1;
            if (submit_release) begin
                next_state = S_IDLE;
            end
        end

        default: next_state = S_IDLE;
    endcase
end
```

endmodule