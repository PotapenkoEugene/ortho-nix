--============================================================================
-- Obsidian Daily Note Generator v3 - Dashboard View
--============================================================================
--
-- Generates a read-only dashboard of project status.
-- No sync-back: daily notes are views, task state lives in project files.
--
-- Dashboard line format:
--   - [[PROJECT]] N️⃣
--       - first undone top-level objective
--
-- Age = calendar days since current objective appeared (keycap 1️⃣-9️⃣).
--
--============================================================================

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local Config = {
  daily_folder = "daily",
  projects_folder = "projects",
  personal_folder = "personal",

  undone_markers = { "[ ]", "[!]", "[>]" },
  done_markers = { "[x]", "[X]", "[~]" },

  indent_size = 4,

  sections = {
    today = "## Today",
    meetings = "## Meetings",
    important = "## Important",
    notes = "## Notes",
  },

  mails_folder = "mails",
  payments_file = "personal/payments.md",

  debug = false,
}

-- ============================================================================
-- DEBUG
-- ============================================================================

local Debug = {}

function Debug.log(msg, ...)
  if Config.debug then
    print(string.format("[DEBUG] " .. msg, ...))
  end
end

-- ============================================================================
-- UTILS
-- ============================================================================

local Utils = {}

function Utils.get_today_date()
  return os.date("%Y-%m-%d")
end

function Utils.parse_date(s)
  local y, m, d = s:match("(%d%d%d%d)-(%d%d)-(%d%d)")
  if y then
    return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
  end
  return nil
end

function Utils.days_between(d1, d2)
  local t1, t2 = Utils.parse_date(d1), Utils.parse_date(d2)
  if t1 and t2 then
    return math.floor(os.difftime(t2, t1) / 86400)
  end
  return 1
end

function Utils.find_last_daily_note(today)
  local dir = Utils.build_path(Config.daily_folder)
  local files = vim.fn.glob(dir .. "/*.md", false, true)
  local dates = {}
  for _, f in ipairs(files) do
    local d = f:match("(%d%d%d%d%-%d%d%-%d%d)%.md$")
    if d and d < today then table.insert(dates, d) end
  end
  table.sort(dates)
  return dates[#dates]
end

function Utils.get_vault_root()
  local ok, Obsidian = pcall(require, "obsidian")
  if ok and Obsidian.dir then
    return tostring(Obsidian.dir)
  end
  return vim.fn.getcwd()
end

function Utils.build_path(...)
  return Utils.get_vault_root() .. "/" .. table.concat({...}, "/")
end

function Utils.file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

function Utils.read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*all")
  f:close()
  return content
end

function Utils.write_file(path, content)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(content)
  f:close()
  return true
end

function Utils.split_lines(str)
  local lines = {}
  for line in str:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end
  if lines[#lines] == "" then table.remove(lines) end
  return lines
end

function Utils.trim(s)
  return s:match("^%s*(.-)%s*$")
end

function Utils.get_indent_level(line)
  local spaces = line:match("^(%s*)")
  return math.floor(#spaces / Config.indent_size)
end

function Utils.escape_pattern(s)
  return s:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

-- Keycap number emoji: 1️⃣ through 9️⃣
function Utils.keycap(n)
  n = math.max(1, math.min(9, n))
  return string.char(0x30 + n) .. "\xef\xb8\x8f" .. "\xe2\x83\xa3"
end

function Utils.extract_age(text)
  for n = 9, 1, -1 do
    if text:find(Utils.keycap(n), 1, true) then return n end
  end
  return 0
end

function Utils.strip_age(text)
  local result = text
  for n = 9, 1, -1 do
    result = result:gsub("%s*" .. Utils.escape_pattern(Utils.keycap(n)) .. "%s*", " ")
  end
  return Utils.trim(result)
end

function Utils.is_done(marker)
  if not marker then return false end
  local m = marker:lower()
  for _, dm in ipairs(Config.done_markers) do
    if m == dm:lower() then return true end
  end
  return false
end

function Utils.extract_link(text)
  return text:match("%[%[([^%]]+)%]%]")
end

-- ============================================================================
-- TASK PARSER (minimal)
-- ============================================================================

local TaskParser = {}

function TaskParser.is_task(line)
  return Utils.trim(line):match("^%-%s*%[.%]") ~= nil
end

function TaskParser.marker(line)
  return Utils.trim(line):match("^%-%s*(%[.%])")
end

function TaskParser.text(line)
  local t = Utils.trim(line)
  return t:match("^%-%s*%[.%]%s*(.*)") or t:match("^%-%s*(.*)") or t
end

-- ============================================================================
-- PROJECT FILE
-- ============================================================================

local ProjectFile = {}

function ProjectFile.path(name, folder)
  return Utils.build_path(folder or Config.projects_folder, name .. ".md")
end

-- Returns {marker, objective_text, display_text} for first undone top-level objective
-- display_text = first undone direct child, or objective_text if no undone children
function ProjectFile.first_undone(content)
  local lines = Utils.split_lines(content)
  local in_obj = false
  local current = nil
  local first_child = nil

  for _, line in ipairs(lines) do
    if line:match("^## Objectives") then
      in_obj = true
    elseif in_obj then
      if line:match("^## ") then break end

      local indent = Utils.get_indent_level(line)

      if indent == 0 and TaskParser.is_task(line) then
        -- New top-level: return previous if it was undone
        if current then
          current.display_text = first_child or current.objective_text
          return current
        end
        local m = TaskParser.marker(line)
        if not Utils.is_done(m) then
          current = { marker = m, objective_text = TaskParser.text(line) }
          first_child = nil
        end
      elseif indent == 1 and current and TaskParser.is_task(line) then
        local m = TaskParser.marker(line)
        if not first_child and not Utils.is_done(m) then
          first_child = TaskParser.text(line)
        end
      end
    end
  end

  -- Handle last objective in file
  if current then
    current.display_text = first_child or current.objective_text
    return current
  end
  return nil
end

-- ============================================================================
-- DASHBOARD
-- ============================================================================

local Dashboard = {}

-- Scan folder for projects with undone objectives
function Dashboard.scan(folder)
  local dir = Utils.build_path(folder)
  local files = vim.fn.glob(dir .. "/*.md", false, true)
  local entries = {}

  for _, fp in ipairs(files) do
    local name = fp:match("([^/]+)%.md$")
    if name then
      local content = Utils.read_file(fp)
      if content then
        local obj = ProjectFile.first_undone(content)
        if obj then
          table.insert(entries, {
            name = name,
            marker = obj.marker,
            objective_text = obj.objective_text,
            display_text = obj.display_text,
            age = 1,
          })
          Debug.log("Found: %s -> %s", name, obj.objective_text)
        end
      end
    end
  end

  return entries
end

-- Parse previous Today section for age tracking
-- Returns: linked = {[name] = {age, objective_text}}, unlinked = {{text, age}, ...}
-- Handles both new nested format and old "-- display_text" format
function Dashboard.parse_prev_today(content)
  local lines = Utils.split_lines(content)
  local in_today = false
  local linked, unlinked = {}, {}
  local current_project = nil

  for _, line in ipairs(lines) do
    if line == Config.sections.today then
      in_today = true
    elseif in_today then
      if line:match("^## ") then break end
      local trimmed = Utils.trim(line)
      local indent = Utils.get_indent_level(line)

      if trimmed == "" then
        -- skip blank lines
      elseif indent == 0 and trimmed:match("^%-") then
        current_project = nil
        local text = TaskParser.text(line)
        local project = Utils.extract_link(text)

        if project then
          local age = Utils.extract_age(text)
          -- Old format compat: extract objective from "-- text" suffix
          local old_obj = Utils.trim(text:match("%-%-+%s*(.+)$") or "")
          linked[project] = { age = age, objective_text = old_obj }
          current_project = project
        else
          -- Unlinked personal task — filter done markers (old format compat)
          local m = TaskParser.marker(line)
          if not Utils.is_done(m) then
            table.insert(unlinked, {
              text = Utils.strip_age(text),
              age = Utils.extract_age(text),
            })
          end
        end
      elseif indent >= 1 and current_project and trimmed:match("^%-") then
        -- New format: indented objective line after project
        local obj_text = trimmed:match("^%-%s*(.*)") or trimmed
        linked[current_project].objective_text = obj_text
      end
    end
  end

  return linked, unlinked
end

function Dashboard.same_objective(a, b)
  if not a or not b or a == "" or b == "" then return false end
  return Utils.trim(a):lower() == Utils.trim(b):lower()
end

function Dashboard.make_lines(e)
  return {
    string.format("- [[%s]] %s", e.name, Utils.keycap(e.age)),
    string.format("    - %s", e.objective_text),
  }
end

function Dashboard.make_unlinked_line(t)
  return string.format("- %s %s", t.text, Utils.keycap(t.age))
end

-- ============================================================================
-- MAIL
-- ============================================================================

local Mail = {}

-- Scan mail digest files for ## Tasks sections, return list of task lines
function Mail.scan_mail_tasks(since_date)
  local dir = Utils.build_path(Config.mails_folder)
  local files = vim.fn.glob(dir .. "/*.md", false, true)
  local tasks = {}

  for _, fp in ipairs(files) do
    local date = fp:match("(%d%d%d%d%-%d%d%-%d%d)%.md$")
    if date and (not since_date or date >= since_date) then
      local content = Utils.read_file(fp)
      if content then
        local in_tasks = false
        for line in content:gmatch("([^\n]*)\n?") do
          if line:match("^## Tasks") then
            in_tasks = true
          elseif in_tasks then
            if line:match("^## ") then break end
            local trimmed = Utils.trim(line)
            if trimmed:match("^%- %[.%]") then
              table.insert(tasks, trimmed)
            end
          end
        end
      end
    end
  end

  return tasks
end

-- Read payments.md, return list of all lines and set of existing task texts (sink file for all mail tasks)
function Mail.read_payments_file()
  local path = Utils.build_path(Config.payments_file)
  local content = Utils.read_file(path)
  local lines = {}
  local existing = {}

  if content then
    lines = Utils.split_lines(content)
    for _, line in ipairs(lines) do
      local trimmed = Utils.trim(line)
      if trimmed:match("^%- %[.%]") then
        -- Normalize: strip marker, trim for comparison
        local text = trimmed:match("^%- %[.%]%s*(.*)") or ""
        existing[text:lower()] = true
      end
    end
  end

  return lines, existing
end

-- Sync mail digest tasks into payments.md (append new, skip duplicates)
function Mail.sync()
  local pay_lines, existing = Mail.read_payments_file()
  local mail_tasks = Mail.scan_mail_tasks()
  local added = 0

  for _, task in ipairs(mail_tasks) do
    local text = task:match("^%- %[.%]%s*(.*)") or ""
    if not existing[text:lower()] then
      table.insert(pay_lines, task)
      existing[text:lower()] = true
      added = added + 1
      Debug.log("Mail task added: %s", text)
    end
  end

  if added > 0 or #pay_lines == 0 then
    local path = Utils.build_path(Config.payments_file)
    -- Ensure header exists
    if #pay_lines == 0 or not pay_lines[1]:match("^# ") then
      table.insert(pay_lines, 1, "# Payments")
      table.insert(pay_lines, 2, "")
    end
    Utils.write_file(path, table.concat(pay_lines, "\n") .. "\n")
  end

  Debug.log("Mail sync: %d new tasks added", added)
end

-- Get undone tasks from payments.md for daily note display
function Mail.get_undone()
  local path = Utils.build_path(Config.payments_file)
  local content = Utils.read_file(path)
  if not content then return {} end

  local tasks = {}
  for line in content:gmatch("([^\n]*)\n?") do
    local trimmed = Utils.trim(line)
    local marker = trimmed:match("^%- (%[.%])")
    if marker and not Utils.is_done(marker) then
      table.insert(tasks, trimmed)
    end
  end
  return tasks
end

-- ============================================================================
-- DAILY NOTE
-- ============================================================================

local DailyNote = {}

function DailyNote.parse_sections(content)
  local lines = Utils.split_lines(content)
  local sections = {}
  local key, buf = nil, {}

  for _, line in ipairs(lines) do
    local new_key = nil
    if line == Config.sections.today then new_key = "today"
    elseif line == Config.sections.meetings then new_key = "meetings"
    elseif line == Config.sections.notes then new_key = "notes"
    elseif line:match("^## ") then new_key = "other"
    end

    if new_key then
      if key then sections[key] = buf end
      key, buf = new_key, {}
    elseif key then
      table.insert(buf, line)
    end
  end
  if key then sections[key] = buf end
  return sections
end

function DailyNote.has_content(lines)
  if not lines then return false end
  for _, line in ipairs(lines) do
    local t = Utils.trim(line)
    if t ~= "" and t ~= "-" then return true end
  end
  return false
end

-- ============================================================================
-- MAIN
-- ============================================================================

Debug.log("=== Daily Note v3 (Dashboard) ===")

local today = Utils.get_today_date()
local today_path = Utils.build_path(Config.daily_folder, today .. ".md")

local function generate(ref_date)
  -- Load reference daily note for age tracking + carry-forward
  local prev_linked, prev_unlinked = {}, {}
  local prev_sections = {}
  local days_gap = 1

  if ref_date then
    local ref_path = Utils.build_path(Config.daily_folder, ref_date .. ".md")
    local content = Utils.read_file(ref_path)
    if content then
      prev_linked, prev_unlinked = Dashboard.parse_prev_today(content)
      prev_sections = DailyNote.parse_sections(content)
      days_gap = Utils.days_between(ref_date, today)
      Debug.log("Ref: %s, Days gap: %d", ref_date, days_gap)
    end
  end

  -- Scan project folders for undone objectives
  local work = Dashboard.scan(Config.projects_folder)
  local personal = Dashboard.scan(Config.personal_folder)

  -- Calculate ages (same objective_text = increment, different = reset to 1)
  for _, e in ipairs(work) do
    local prev = prev_linked[e.name]
    if prev and Dashboard.same_objective(prev.objective_text, e.objective_text) then
      e.age = math.min(prev.age + days_gap, 9)
    end
  end

  for _, e in ipairs(personal) do
    local prev = prev_linked[e.name]
    if prev and Dashboard.same_objective(prev.objective_text, e.objective_text) then
      e.age = math.min(prev.age + days_gap, 9)
    end
  end

  -- Carry forward unlinked personal tasks (done already filtered in parse_prev_today)
  local unlinked = {}
  for _, t in ipairs(prev_unlinked) do
    table.insert(unlinked, {
      text = t.text,
      age = math.min(t.age + days_gap, 9),
    })
  end

  -- Sort each group by age descending, then name ascending
  local function sort_by_age(list, key)
    table.sort(list, function(a, b)
      if a.age ~= b.age then return a.age > b.age end
      return (a[key] or "") < (b[key] or "")
    end)
  end

  sort_by_age(unlinked, "text")
  sort_by_age(personal, "name")
  sort_by_age(work, "name")

  -- Build Today lines: unlinked -> personal -> work
  local today_lines = {}
  for _, t in ipairs(unlinked) do
    table.insert(today_lines, Dashboard.make_unlinked_line(t))
  end
  for _, e in ipairs(personal) do
    for _, line in ipairs(Dashboard.make_lines(e)) do
      table.insert(today_lines, line)
    end
  end
  for _, e in ipairs(work) do
    for _, line in ipairs(Dashboard.make_lines(e)) do
      table.insert(today_lines, line)
    end
  end

  -- Sync mail tasks from digests into payments.md
  Mail.sync()
  local mail_tasks = Mail.get_undone()

  -- Carry forward Meetings/Notes from previous note if they have content
  local meetings_lines = {}
  local notes_lines = {}
  if DailyNote.has_content(prev_sections.meetings) then
    meetings_lines = prev_sections.meetings
  end
  if DailyNote.has_content(prev_sections.notes) then
    notes_lines = prev_sections.notes
  end

  -- Build final output: Meetings -> Today -> Notes
  local out = {
    "---",
    "tags:",
    "  - daily",
    'date: "' .. today .. '"',
    "---",
    "",
    "# " .. today,
    "",
    Config.sections.meetings,
  }

  if #meetings_lines > 0 then
    for _, line in ipairs(meetings_lines) do table.insert(out, line) end
  else
    table.insert(out, "")
  end
  table.insert(out, "")

  table.insert(out, Config.sections.today)
  for _, line in ipairs(today_lines) do table.insert(out, line) end
  if #today_lines == 0 then table.insert(out, "") end
  table.insert(out, "")

  if #mail_tasks > 0 then
    table.insert(out, Config.sections.important)
    for _, line in ipairs(mail_tasks) do table.insert(out, line) end
    table.insert(out, "")
  end

  table.insert(out, Config.sections.notes)
  if #notes_lines > 0 then
    for _, line in ipairs(notes_lines) do table.insert(out, line) end
  else
    table.insert(out, "- ")
  end
  table.insert(out, "")

  -- Write daily note
  local final = table.concat(out, "\n")
  vim.fn.mkdir(Utils.build_path(Config.daily_folder), "p")
  Utils.write_file(today_path, final)
  vim.cmd("edit! " .. today_path)

  Debug.log("=== Done ===")
end

-- First call: create if missing, otherwise just open
if Utils.file_exists(today_path) then
  vim.cmd((vim.bo.modified and "tabedit " or "edit ") .. today_path)
else
  generate(Utils.find_last_daily_note(today))
  vim.notify("Daily note created: " .. today, vim.log.levels.INFO)
end

-- Register refresh command (persists in the notes popup nvim session)
vim.api.nvim_create_user_command("DailyRefresh", function()
  generate(today)
  vim.notify("Daily note refreshed: " .. today, vim.log.levels.INFO)
end, { desc = "Refresh today's daily note (re-scan project files)" })
