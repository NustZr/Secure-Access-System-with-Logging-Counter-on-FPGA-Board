// ------------------------------------------------------------------
// 1. โมดูลกรองสัญญาณปุ่มกด (Button Debounce)
// ป้องกันปัญหาหน้าสัมผัสสวิตช์เด้ง (Bouncing) ที่ทำให้มองเห็นเป็นการกดหลายครั้ง
// ------------------------------------------------------------------
module debounce (
input wire clk,       // สัญญาณนาฬิกา 20MHz จากบอร์ด Surveyor-6
input wire btn_in,    // สัญญาณดิบจาก Push Button
output reg btn_out    // สัญญาณที่กรองแล้ว
);
// ใช้ Counter นับเวลาประมาณ 20ms เพื่อยืนยันการกดปุ่ม (20MHz * 20ms = 400,000)
reg [18:0] counter;
reg btn_sync_0, btn_sync_1;

```
 always @(posedge clk) begin
    // Synchronize สัญญาณเพื่อป้องกัน Metastability
    btn_sync_0 <= btn_in;
    btn_sync_1 <= btn_sync_0;
	  end

	  always @(posedge clk) begin
    if (btn_sync_1 == btn_out) begin
        counter <= 0;
    end else begin
        counter <= counter + 1;
        if (counter == 400000) begin
            btn_out <= btn_sync_1;
            counter <= 0;
        end
    end
end
```

endmodule

// ------------------------------------------------------------------
// 2. โมดูลหลักสำหรับตรวจสอบรหัสผ่าน (Verification Unit)
// ------------------------------------------------------------------
module verification_unit (
input wire clk,              // Clock 20MHz
input wire rst_n,            // สัญญาณ Reset (Active Low)
input wire [7:0] dip_sw,     // ข้อมูลรหัสผ่าน 8 บิตจาก DIP Switch
input wire btn_submit,       // ปุ่มกดยืนยันรหัสผ่าน (Push Button)
input wire fsm_change_mode,  // สัญญาณจาก FSM บอกว่าอยู่ในโหมด "ตั้งรหัสใหม่" หรือไม่ (1 = เปลี่ยนรหัส, 0 = ตรวจสอบ)

```
output reg match,            // ส่งสัญญาณ 1-clock pulse ไปบอก FSM ว่า "รหัสถูก"
output reg error             // ส่งสัญญาณ 1-clock pulse ไปบอก FSM ว่า "รหัสผิด"
```

);

// --- ส่วนที่ 1: การกรองสัญญาณ (Input Debounce & Edge Detection) ---
wire btn_debounced;
reg btn_prev;
wire submit_pulse;

```
 // ดึงโมดูล debounce มาใช้งาน
debounce db_inst (
    .clk(clk),
    .btn_in(btn_submit),
    .btn_out(btn_debounced)
);

 // ตรวจจับขอบขาขึ้น (Edge Detector) เพื่อให้การกดปุ่ม 1 ครั้ง สร้าง Pulse แค่ 1 Clock
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) btn_prev <= 1'b0;
    else        btn_prev <= btn_debounced;
end
assign submit_pulse = btn_debounced & ~btn_prev; // จะเป็น 1 แค่เสี้ยววินาทีตอนกดปุ่ม

 // --- ส่วนที่ 2 & 3: Password Register และ Correct Password ROM ---
reg [7:0] correct_password; // ทำหน้าที่เป็น ROM เก็บค่ารหัสผ่านที่ถูกต้อง
reg [7:0] input_password;   // ทำหน้าที่เป็น Register ล็อกค่าจาก DIP Switch

 always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // ค่า Initial Password แบบ Hardcode ตามที่ออกแบบไว้ (10101010)
        correct_password <= 8'b10101010;
        input_password <= 8'b00000000;
        match <= 1'b0;
        error <= 1'b0;
		end else begin
        // เคลียร์สัญญาณ pulse เสมอเพื่อไม่ให้ค้าง
        match <= 1'b0;
        error <= 1'b0;

			// เมื่อมีการกดปุ่ม Submit (เกิด submit_pulse)
        if (submit_pulse) begin

            if (fsm_change_mode) begin
                // [กรณีอยู่ในโหมด CHANGE PASSWORD]
                // อัปเดตรหัสผ่านใหม่ลงไปใน correct_password ทันที
                correct_password <= dip_sw;
            end else begin
				 // [กรณีอยู่ในโหมดปกติตรวจสอบรหัส]
                // ขั้นที่ 2: ล็อกข้อมูล (Password Register) จาก DIP Switch เข้ามาเก็บไว้
                input_password <= dip_sw;

					  // ขั้นที่ 3 & 4: เปรียบเทียบ (Comparator) และตัดสินผลลัพธ์
                if (dip_sw == correct_password) begin
                    match <= 1'b1; // ตรงกันทุกบิต -> ส่ง Match ไปหา FSM
                end else begin
                    error <= 1'b1; // ผิดแม้แต่บิตเดียว -> ส่ง Error ไปหา FSM
							end
            end

        end
    end
end
```

endmodule