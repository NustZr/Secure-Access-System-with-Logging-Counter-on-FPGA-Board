module display_unit (
input wire clk,

input wire rst_n,

input wire [2:0] system_status,
input wire [2:0] attempt_count,
input wire btn_submit,

input wire [7:0] dip_sw,  

```
 output wire a, b, c, d, e, f, g,
output reg com0, com1, com2, com3,
output reg [7:0] led,
output reg buzzer
```

);
reg [23:0] blink_counter;
reg blink_state;
reg slow_blink_state;
reg [15:0] tone_counter;
reg buzzer_wave;
reg [15:0] current_tone_max;

```
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tone_counter <= 0;
        buzzer_wave <= 0;
    end else begin
			if (tone_counter >= current_tone_max) begin
            tone_counter <= 0;
            buzzer_wave <= ~buzzer_wave; 
        end else begin
            tone_counter <= tone_counter + 1;
        end
    end
end


reg [2:0] prev_status;
reg [25:0] open_timer;       
reg [24:0] set_beep_timer;   

 always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        blink_counter <= 0;
        blink_state <= 0;
        slow_blink_state <= 0;
        prev_status <= 3'd0;
        open_timer <= 26'd50_000_000; 
        set_beep_timer <= 25'd20_000_000;
    end else begin
			// สร้างจังหวะกระพริบ
        if (blink_counter >= 24'd2_500_000) begin
            blink_counter <= 0;
            blink_state <= ~blink_state;
            if (blink_state == 1'b1) slow_blink_state <= ~slow_blink_state;
        end else begin
            blink_counter <= blink_counter + 1;
        end

			// จำหน้าจอล่าสุดไว้
        prev_status <= system_status;


        if (system_status == 3'd1 && prev_status != 3'd1) begin
            open_timer <= 0; // เพิ่งเข้าหน้า OPEN ให้เริ่มจับเวลาใหม่!
        end else if (system_status == 3'd1 && open_timer < 26'd50_000_000) begin
            open_timer <= open_timer + 1;
        end


        if (system_status == 3'd4 && prev_status != 3'd4) begin
            set_beep_timer <= 0; // เพิ่งเข้าหน้า SET ให้เริ่มจับเวลา
        end else if (system_status == 3'd4 && set_beep_timer < 25'd15_000_000) begin
            set_beep_timer <= set_beep_timer + 1;
        end
    end
end

 // ------------------------------------------------------------------
// ควบคุมไฟ LED และ เสียงแบบใหม่ล่าสุด!
// ------------------------------------------------------------------
always @(*) begin
    led = 8'b00000000;
    buzzer = 1'b0;
	  current_tone_max = 16'd10000;

	  case (system_status)
        3'd0: begin // IDLE
            led[0] = (attempt_count >= 3'd1) ? 1'b1 : 1'b0;
            led[1] = (attempt_count >= 3'd2) ? 1'b1 : 1'b0;
            led[2] = (attempt_count >= 3'd3) ? 1'b1 : 1'b0;
            led[7] = btn_submit;
        end

			3'd1: begin // OPEN
            if (open_timer < 26'd3_000_000) begin
                // 0 - 0.15 วิ: ปี๊ปสั้นที่ 1
                led = 8'b11110000;
                buzzer = 1'b1;
            end
            else if (open_timer < 26'd5_000_000) begin
                // 0.15 - 0.25 วิ: พักจังหวะ
                led = 8'b00000000;
                buzzer = 1'b0;
            end
				 else if (open_timer < 26'd8_000_000) begin
                // 0.25 - 0.40 วิ: ปี๊ปสั้นที่ 2
                led = 8'b00001111;
                buzzer = 1'b1;
            end
            else if (open_timer < 26'd10_000_000) begin
                // 0.40 - 0.50 วิ: พักจังหวะ
                led = 8'b00000000;
                buzzer = 1'b0;
            end
				 else if (open_timer < 26'd24_000_000) begin
                // 0.50 - 1.20 วิ: ปี๊ปยาวววว (Ta-Daaa!) โชว์ความสำเร็จ
                led = 8'b11111111; // สว่างวาบทุกดวง
                buzzer = 1'b1;
            end
            else if (open_timer < 26'd40_000_000) begin
                // 1.20 - 2.00 วิ: เงียบแล้วปล่อยไฟกระพริบวิบวับสวยๆ จนจบ
                led = blink_state ? 8'b11110000 : 8'b00001111;
                buzzer = 1'b0;
            end
				 else begin
                // เลย 2 วิแล้ว ดับหมด
                led = 8'b00000000;
                buzzer = 1'b0;
            end
        end

			3'd2: begin // ERROR
            led[0] = (attempt_count >= 3'd1) ? 1'b1 : 1'b0;
            led[1] = (attempt_count >= 3'd2) ? 1'b1 : 1'b0;
            led[2] = (attempt_count >= 3'd3) ? 1'b1 : 1'b0;
            led[7] = btn_submit;
            buzzer = 1'b1;
        end

			3'd3: begin // LOCK
            led = blink_state ? 8'b10101010 : 8'b01010101;
            buzzer = blink_state;
        end

			3'd4: begin // SET (ตั้งรหัสใหม่)

            led = 8'b00000000;


            buzzer = 1'b0;
        end
    endcase
end

 // ------------------------------------------------------------------
// ควบคุม 7-Segment 
// ------------------------------------------------------------------
reg [15:0] refresh_counter;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) refresh_counter <= 16'd0;
    else        refresh_counter <= refresh_counter + 1'b1;
end
 wire [1:0] digit_select = refresh_counter[15:14];

reg [6:0] seg_data;
always @(*) begin
    com0 = 1'b1; com1 = 1'b1; com2 = 1'b1; com3 = 1'b1;
    seg_data = 7'b0000000;
    case (digit_select)
        2'b00: begin
				 com3 = 1'b0;
            case (system_status)
                3'd0: seg_data = 7'b1000000;
                3'd1: seg_data = 7'b0111111;
                3'd2: seg_data = 7'b1111001;
                3'd3: seg_data = 7'b0111000;
                3'd4: seg_data = 7'b1101101;
                default: seg_data = 7'b0000000;
            endcase
        end
			2'b01: begin
            com2 = 1'b0;
            case (system_status)
                3'd0: seg_data = 7'b1000000;
                3'd1: seg_data = 7'b1110011;
                3'd2: seg_data = 7'b1010000;
                3'd3: seg_data = 7'b0111111;
                3'd4: seg_data = 7'b1111001;
                default: seg_data = 7'b0000000;
            endcase
        end
			2'b10: begin
            com1 = 1'b0;
            case (system_status)
                3'd0: seg_data = 7'b1000000;
                3'd1: seg_data = 7'b1111001;
                3'd2: seg_data = 7'b1010000;
                3'd3: seg_data = 7'b0111001;
                3'd4: seg_data = 7'b1111000;
                default: seg_data = 7'b0000000;
            endcase
        end
			2'b11: begin
            com0 = 1'b0;
            case (system_status)
                3'd0: seg_data = 7'b1000000;
                3'd1: seg_data = 7'b1010100;
                3'd2: seg_data = 7'b0000000;
                3'd3: seg_data = 7'b0000000;
                3'd4: seg_data = 7'b0000000;
                default: seg_data = 7'b0000000;
            endcase
        end
    endcase
end
 assign {g, f, e, d, c, b, a} = seg_data;
```

endmodule