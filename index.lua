-- FakeName Changer - ALL BUBBLES EDITOR
-- Edits ur0:shell/db/app.db display titles only.
-- PARAM.SFO / app internals are untouched.

local APP_DB = "ur0:shell/db/app.db"
local DATA_DIR = "ux0:/data/FakeNameChanger"
local ORIGINAL_BACKUP = DATA_DIR .. "/app_original_first_run.db"
local LAST_BACKUP = DATA_DIR .. "/app_before_last_patch.db"
local AUTO_REBOOT_AFTER_PATCH = false
local PAGE_SIZE = 11

local WHITE = Color.new(235,235,228,255)
local SILVER = Color.new(185,185,180,255)
local MAROON = Color.new(112,18,28,255)
local MAROON_DARK = Color.new(48,8,13,255)
local OXBLOOD = Color.new(150,28,38,255)
local GREEN = Color.new(210,210,200,255)
local RED   = Color.new(190,45,55,255)
local YELL  = Color.new(200,175,145,255)
local GREY  = Color.new(145,145,140,255)
local DARK  = Color.new(5,5,6,255)
local PANEL = Color.new(16,16,17,245)
local PANEL_SOFT = Color.new(26,24,24,230)
local SEL   = Color.new(86,22,28,245)
local LINE  = Color.new(88,80,76,255)
local MENU_BG = nil

local function load_theme_assets()
    local ok, img
    if Graphics ~= nil and Graphics.loadImage ~= nil then
        ok, img = pcall(Graphics.loadImage, "app0:/menu_bg.png")
        if ok and img ~= nil then MENU_BG = img return end
    end
    if Image ~= nil and Image.load ~= nil then
        ok, img = pcall(Image.load, "app0:/menu_bg.png")
        if ok and img ~= nil then MENU_BG = img return end
    end
end

local function draw_theme_image()
    if MENU_BG == nil then return false end
    local ok = false
    if Graphics ~= nil and Graphics.drawImage ~= nil then
        ok = pcall(Graphics.drawImage, 0, 0, MENU_BG)
        if ok then return true end
    end
    if Image ~= nil and Image.draw ~= nil then
        ok = pcall(Image.draw, MENU_BG, 0, 0)
        if ok then return true end
        ok = pcall(Image.draw, 0, 0, MENU_BG)
        if ok then return true end
    end
    return false
end

local bubbles = {}
local selected = 1
local scroll = 1
local status = ""
local oldpad = 0
local prev_up = false
local prev_down = false
local prev_left = false
local prev_right = false
local hold_up = 0
local hold_down = 0
local hold_left = 0
local hold_right = 0
local pending_reboot = false
local home_locked = false

local function safe_tostring(v)
    if v == nil then return "" end
    return tostring(v)
end

local function clean_display_text(s)
    s = safe_tostring(s)
    s = string.gsub(s, "[%c]", " ")
    s = string.gsub(s, "%s+", " ")
    return s
end

local function sql_escape(s)
    s = clean_display_text(s)
    return string.gsub(s, "'", "''")
end

local function ensure_data_dir()
    if not System.doesDirExist(DATA_DIR) then
        System.createDirectory(DATA_DIR)
    end
end

local function backup_original_once()
    ensure_data_dir()
    if not System.doesFileExist(ORIGINAL_BACKUP) then
        System.copyFile(APP_DB, ORIGINAL_BACKUP)
    end
end

local function backup_before_patch()
    ensure_data_dir()
    System.copyFile(APP_DB, LAST_BACKUP)
    backup_original_once()
end

local function open_db()
    return Database.open(APP_DB)
end

local function load_bubbles()
    local db = open_db()
    local q = "SELECT titleId, title FROM tbl_appinfo_icon " ..
              "WHERE titleId IS NOT NULL AND title IS NOT NULL " ..
              "ORDER BY title COLLATE NOCASE"
    local rows = Database.execQuery(db, q)
    Database.close(db)

    bubbles = {}
    if rows then
        for i=1,#rows do
            local id = rows[i].titleId or rows[i].titleid or rows[i].TITLEID
            local title = rows[i].title or rows[i].TITLE
            if id ~= nil and title ~= nil then
                bubbles[#bubbles + 1] = { titleId = clean_display_text(id), title = clean_display_text(title) }
            end
        end
    end

    if #bubbles < 1 then
        status = "No bubbles found. app.db access may be blocked."
        selected = 1
        scroll = 1
    else
        if selected > #bubbles then selected = #bubbles end
        if selected < 1 then selected = 1 end
        if scroll > selected then scroll = selected end
        if selected >= scroll + PAGE_SIZE then scroll = selected - PAGE_SIZE + 1 end
        if scroll < 1 then scroll = 1 end
        status = ""
    end
end

local function visible_title(row)
    local t = clean_display_text(row.title or "")
    if #t > 33 then t = string.sub(t, 1, 30) .. "..." end
    return t
end

local function draw_line(x1, x2, y1, y2, c)
    Graphics.fillRect(x1, x2, y1, y2, c)
end

local function draw_label(x, y, s, c, bold)
    Graphics.debugPrint(x, y, s, c)
    if bold then
        Graphics.debugPrint(x + 1, y, s, c)
    end
end

local function pad2(n)
    n = tonumber(n) or 0
    if n < 10 then return "0" .. tostring(n) end
    return tostring(n)
end

local function get_clock_strings()
    local h, mi, s = 0, 0, 0
    local day_num, d, mo, y = 1, 1, 1, 2000
    if System ~= nil and System.getTime ~= nil then
        local ok, a, b, c = pcall(System.getTime)
        if ok then
            h, mi, s = a or 0, b or 0, c or 0
        end
    end
    if System ~= nil and System.getDate ~= nil then
        local ok, a, b, c, d2 = pcall(System.getDate)
        if ok then
            day_num, d, mo, y = a or 1, b or 1, c or 1, d2 or 2000
        end
    end

    local suffix = "AM"
    local hour12 = tonumber(h) or 0
    if hour12 >= 12 then suffix = "PM" end
    hour12 = hour12 % 12
    if hour12 == 0 then hour12 = 12 end

    local date_text = pad2(mo) .. "/" .. pad2(d) .. "/" .. tostring(y)
    local time_text = tostring(hour12) .. ":" .. pad2(mi) .. " " .. suffix
    return date_text, time_text
end

local function get_battery_status()
    local pct = 0
    local charging = false
    if System ~= nil and System.getBatteryPercentage ~= nil then
        local ok, val = pcall(System.getBatteryPercentage)
        if ok and val ~= nil then pct = tonumber(val) or 0 end
    end
    if System ~= nil and System.isBatteryCharging ~= nil then
        local ok, val = pcall(System.isBatteryCharging)
        if ok then charging = not not val end
    end
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
    return pct, charging
end

local function draw_battery_widget(x, y, pct, charging)
    local body_w = 34
    local body_h = 13
    local cap_w = 4

    draw_line(x, x + body_w, y, y + 1, WHITE)
    draw_line(x, x + body_w, y + body_h, y + body_h + 1, WHITE)
    draw_line(x, x + 1, y, y + body_h + 1, WHITE)
    draw_line(x + body_w, x + body_w + 1, y, y + body_h + 1, WHITE)
    Graphics.fillRect(x + body_w + 1, x + body_w + cap_w, y + 4, y + body_h - 3, WHITE)

    local inner_left = x + 2
    local inner_right = x + body_w - 2
    local inner_top = y + 2
    local inner_bottom = y + body_h - 2
    local inner_total = inner_right - inner_left
    local fill_w = math.floor(inner_total * pct / 100)
    local fill_color = WHITE
    if pct <= 20 then fill_color = RED end
    if charging then fill_color = Color.new(120, 220, 120, 255) end
    if fill_w > 0 then
        Graphics.fillRect(inner_left, inner_left + fill_w, inner_top, inner_bottom, fill_color)
    end
end

local function draw_top_status()
    local date_text, time_text = get_clock_strings()
    local pct, charging = get_battery_status()
    local text_y = 18

    draw_label(618, text_y, date_text, WHITE, true)
    draw_label(760, text_y, time_text, WHITE, true)

    local pct_text = tostring(pct) .. "%"
    draw_label(854, text_y, pct_text, WHITE, true)

    draw_battery_widget(912, 22, pct, charging)
end


local function draw_scroll_arrows()
    if #bubbles <= PAGE_SIZE then return end

    local arrow_x = 866
    local arrow_color = WHITE
    local last_visible = scroll + PAGE_SIZE - 1
    if last_visible > #bubbles then last_visible = #bubbles end

    if scroll > 1 then
        draw_label(arrow_x, 132, "^", arrow_color, true)
    end
    if last_visible < #bubbles then
        draw_label(arrow_x, 382, "v", arrow_color, true)
    end
end

local function draw_bg()
    if draw_theme_image() then
        Graphics.fillRect(0, 960, 0, 544, Color.new(0,0,0,34))
        Graphics.fillRect(0, 960, 0, 54, Color.new(12,8,10,185))
        Graphics.fillRect(0, 960, 54, 56, MAROON)
        Graphics.fillRect(62, 898, 70, 400, Color.new(0,0,0,94))
        Graphics.fillRect(62, 898, 420, 522, Color.new(0,0,0,146))
        draw_line(18, 26, 0, 544, MAROON)
        draw_line(934, 942, 0, 544, MAROON)
        draw_line(36, 924, 14, 16, OXBLOOD)
        draw_line(36, 924, 26, 28, MAROON)
        draw_line(70, 890, 66, 68, LINE)
        draw_line(70, 890, 88, 90, MAROON)
        draw_line(70, 890, 400, 402, LINE)
        draw_line(70, 890, 420, 422, MAROON)
        draw_line(70, 890, 522, 524, LINE)
        draw_line(60, 62, 88, 522, LINE)
        draw_line(898, 900, 88, 522, LINE)
        return
    end

    Graphics.fillRect(0, 960, 0, 544, DARK)
    Graphics.fillRect(0, 960, 0, 54, Color.new(12,8,10,185))
    Graphics.fillRect(0, 960, 54, 56, MAROON)
    Graphics.fillRect(0, 44, 0, 544, MAROON_DARK)
    Graphics.fillRect(916, 960, 0, 544, MAROON_DARK)
    Graphics.fillRect(50, 910, 52, 530, PANEL)
    Graphics.fillRect(62, 898, 70, 400, PANEL_SOFT)
    Graphics.fillRect(62, 898, 420, 522, Color.new(10,10,10,226))

    draw_line(18, 26, 0, 544, MAROON)
    draw_line(934, 942, 0, 544, MAROON)
    draw_line(36, 924, 14, 16, OXBLOOD)
    draw_line(36, 924, 26, 28, MAROON)
    draw_line(70, 890, 66, 68, LINE)
    draw_line(70, 890, 88, 90, MAROON)
    draw_line(70, 890, 400, 402, LINE)
    draw_line(70, 890, 420, 422, MAROON)
    draw_line(70, 890, 522, 524, LINE)
    draw_line(60, 62, 88, 522, LINE)
    draw_line(898, 900, 88, 522, LINE)
end

local function draw()
    Graphics.initBlend()
    Screen.clear(DARK)
    draw_bg()

    draw_label(88, 16, "FakeName Changer", WHITE, true)
    Graphics.debugPrint(88, 38, "Rename LiveArea bubble titles only. PARAM.SFO untouched.", WHITE)
    draw_top_status()

    local count_text = "Loaded Bubbles: " .. #bubbles
    draw_label(74, 106, count_text, WHITE, true)
    draw_label(372, 106, "Pick One & Press X", WHITE, true)
    draw_scroll_arrows()

    local y = 136
    local last = math.min(scroll + PAGE_SIZE - 1, #bubbles)
    for i=scroll,last do
        local row = bubbles[i]
        if i == selected then
            Graphics.fillRect(70, 890, y - 4, y + 17, SEL)
            Graphics.debugPrint(84, y, "> " .. row.titleId .. "  |  " .. visible_title(row), GREEN)
        else
            Graphics.debugPrint(84, y, "  " .. row.titleId .. "  |  " .. visible_title(row), WHITE)
        end
        y = y + 24
    end

    draw_label(84, 416, "Controls", WHITE, true)
    Graphics.debugPrint(84, 436, "Move: D-Pad / Left Stick", YELL)
    Graphics.debugPrint(470, 436, "Page: L / R", YELL)
    Graphics.debugPrint(84, 456, "X: Rename", YELL)
    Graphics.debugPrint(470, 456, "□: Backup", YELL)
    Graphics.debugPrint(84, 476, "Select: Refresh", YELL)
    Graphics.debugPrint(470, 476, "Start: Apply / Reboot", YELL)

    local hint_left = "Triangle: Restore + Reboot"
    local hint_right = "Home Lock: After first save"
    if pending_reboot then
        hint_right = "Pending edits: Press START"
    end
    Graphics.debugPrint(84, 496, hint_left, SILVER)
    Graphics.debugPrint(470, 496, hint_right, SILVER)

    Graphics.termBlend()
    Screen.flip()
end

local function wait_release()
    repeat
        Screen.waitVblankStart()
    until Controls.read() == 0
    oldpad = 0
    prev_up, prev_down, prev_left, prev_right = false, false, false, false
    hold_up, hold_down, hold_left, hold_right = 0, 0, 0, 0
end

local function move_selection(delta)
    if #bubbles < 1 then return end
    selected = selected + delta
    while selected < 1 do
        selected = selected + #bubbles
    end
    while selected > #bubbles do
        selected = selected - #bubbles
    end

    if #bubbles <= PAGE_SIZE then
        scroll = 1
        return
    end

    if selected < scroll then
        scroll = selected
    elseif selected >= scroll + PAGE_SIZE then
        scroll = selected - PAGE_SIZE + 1
    end

    if scroll < 1 then scroll = 1 end
    local max_scroll = #bubbles - PAGE_SIZE + 1
    if scroll > max_scroll then scroll = max_scroll end
end

local function page_selection(delta)
    if #bubbles < 1 then return end
    move_selection(delta * PAGE_SIZE)
end

local function lock_home_after_edit()
    if home_locked then return true end
    local ok = false
    if Controls ~= nil and Controls.lockHomeButton ~= nil then
        ok = pcall(function()
            Controls.lockHomeButton()
        end)
    end
    if ok then
        home_locked = true
        return true
    end
    return false
end

local function reboot_now(msg)
    status = msg or "Rebooting..."
    draw()
    System.wait(900)
    System.reboot()
end

local function patch_selected_title(new_title)
    if #bubbles < 1 then
        status = "No bubble selected."
        return false
    end
    new_title = clean_display_text(new_title)
    if new_title == nil or new_title == "" then
        status = "Canceled: empty title not applied."
        return false
    end
    if #new_title > 64 then new_title = string.sub(new_title, 1, 64) end

    local row = bubbles[selected]
    backup_before_patch()

    local db = open_db()
    local q = "UPDATE tbl_appinfo_icon SET title = '" .. sql_escape(new_title) ..
              "' WHERE titleId = '" .. sql_escape(row.titleId) .. "'"
    Database.execQuery(db, q)
    Database.close(db)

    row.title = new_title
    pending_reboot = true
    if lock_home_after_edit() then
        status = "Saved. Home locked. Edit more, then press START to reboot/apply."
    else
        status = "Saved. Home lock unavailable in this runtime. Press START to reboot."
    end
    return true
end

local function restore_last_backup()
    if not System.doesFileExist(LAST_BACKUP) then
        status = "No last backup found yet."
        return false
    end
    System.copyFile(LAST_BACKUP, APP_DB)
    pending_reboot = true
    lock_home_after_edit()
    status = "Restored last backup."
    return true
end

local function make_manual_backup()
    backup_before_patch()
    status = "Backup saved to ux0:/data/FakeNameChanger"
end

local function ask_for_title(current_title)
    local initial = current_title or ""
    local ok_start = pcall(function()
        Keyboard.start("FakeName Changer", initial, 64, TYPE_DEFAULT, MODE_TEXT, OPT_NO_AUTOCAP + OPT_NO_ASSISTANCE)
    end)

    if not ok_start then
        status = "Keyboard failed. This LPP runtime may not support it."
        return nil
    end

    while true do
        draw()
        local st = Keyboard.getState()
        if st == FINISHED then
            local text = Keyboard.getInput()
            Keyboard.clear()
            return text
        elseif st == CANCELED then
            Keyboard.clear()
            status = "Keyboard canceled."
            return nil
        end
        Screen.waitVblankStart()
    end
end

local function handle_repeat(is_down, was_down, counter, first_delay, repeat_delay, action)
    if is_down then
        if not was_down then
            action()
            return 1, true
        else
            counter = counter + 1
            if counter > first_delay and ((counter - first_delay) % repeat_delay == 0) then
                action()
            end
            return counter, true
        end
    end
    return 0, false
end

load_theme_assets()
ensure_data_dir()
backup_original_once()
load_bubbles()

while true do
    draw()
    if pending_reboot then lock_home_after_edit() end
    local pad = Controls.read()
    local analogX, analogY = Controls.readLeftAnalog()

    local up_now = Controls.check(pad, SCE_CTRL_UP) or analogY < 116
    local down_now = Controls.check(pad, SCE_CTRL_DOWN) or analogY > 140
    local left_now = Controls.check(pad, SCE_CTRL_LTRIGGER) or analogX < 110
    local right_now = Controls.check(pad, SCE_CTRL_RTRIGGER) or analogX > 146

    if Controls.check(pad, SCE_CTRL_CROSS) and not Controls.check(oldpad, SCE_CTRL_CROSS) then
        wait_release()
        if #bubbles > 0 then
            local row = bubbles[selected]
            local new_title = ask_for_title(row.title)
            if new_title ~= nil then
                patch_selected_title(new_title)
                draw()
            end
        end
    elseif Controls.check(pad, SCE_CTRL_SQUARE) and not Controls.check(oldpad, SCE_CTRL_SQUARE) then
        wait_release()
        make_manual_backup()
    elseif Controls.check(pad, SCE_CTRL_TRIANGLE) and not Controls.check(oldpad, SCE_CTRL_TRIANGLE) then
        wait_release()
        local ok = restore_last_backup()
        draw()
        if ok then
            reboot_now("Backup restored. Rebooting...")
        end
    elseif Controls.check(pad, SCE_CTRL_SELECT) and not Controls.check(oldpad, SCE_CTRL_SELECT) then
        wait_release()
        load_bubbles()
    elseif Controls.check(pad, SCE_CTRL_START) and not Controls.check(oldpad, SCE_CTRL_START) then
        wait_release()
        if pending_reboot then
            reboot_now("Rebooting now so LiveArea refreshes...")
        else
            reboot_now("No pending edits. Rebooting anyway...")
        end
    elseif Controls.check(pad, SCE_CTRL_CIRCLE) and not Controls.check(oldpad, SCE_CTRL_CIRCLE) then
        wait_release()
        if pending_reboot then
            status = "Exit blocked. Press START to reboot/apply changes."
        else
            status = "Exit disabled. Press START to reboot."
        end
    else
        hold_up, prev_up = handle_repeat(up_now and not down_now, prev_up, hold_up, 16, 3, function() move_selection(-1) end)
        hold_down, prev_down = handle_repeat(down_now and not up_now, prev_down, hold_down, 16, 3, function() move_selection(1) end)
        hold_left, prev_left = handle_repeat(left_now and not right_now, prev_left, hold_left, 18, 6, function() page_selection(-1) end)
        hold_right, prev_right = handle_repeat(right_now and not left_now, prev_right, hold_right, 18, 6, function() page_selection(1) end)
    end

    oldpad = pad
    Screen.waitVblankStart()
end
