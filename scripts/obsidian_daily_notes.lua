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
    events = "## Events",
    personal = "## Personal",
    work = "## Work",
    important = "## Important",
    notes = "## Notes",
  },

  calendar_script = os.getenv("HOME") .. "/.config/home-manager/scripts/calendar-events.sh",
  tasks_file = "personal/tasks.md",
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

-- Progress bar: fixed 4-bar width, percentage-based
-- 🟩 = full segment, 🟨 = partial, ⬜ = empty, ✅ = all done
function Utils.progress_bar(done, total)
  if total == 0 then return "" end
  if done == total then return "✅" end
  local pct = (done / total) * 100
  local bar = ""
  for i = 1, 4 do
    local threshold = i * 25
    if pct >= threshold then
      bar = bar .. "🟩"
    elseif pct > threshold - 25 then
      bar = bar .. "🟨"
    else
      bar = bar .. "⬜"
    end
  end
  return bar
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

-- Returns list of ALL top-level objectives with subtask progress:
-- { {marker, text, done, children_done, children_total}, ... }
-- Also returns first_undone_text (text of first undone objective, for age tracking)
function ProjectFile.all_objectives(content)
  local lines = Utils.split_lines(content)
  local in_obj = false
  local objectives = {}
  local current = nil

  local function flush()
    if current then table.insert(objectives, current) end
  end

  for _, line in ipairs(lines) do
    if line:match("^## Objectives") then
      in_obj = true
    elseif in_obj then
      if line:match("^## ") then break end

      local indent = Utils.get_indent_level(line)

      if indent == 0 and TaskParser.is_task(line) then
        flush()
        local m = TaskParser.marker(line)
        current = {
          marker = m,
          text = TaskParser.text(line),
          done = Utils.is_done(m),
          children_done = 0,
          children_total = 0,
        }
      elseif indent == 1 and current and TaskParser.is_task(line) then
        current.children_total = current.children_total + 1
        if Utils.is_done(TaskParser.marker(line)) then
          current.children_done = current.children_done + 1
        end
      end
    end
  end
  flush()

  -- Find first undone objective text (for age tracking)
  local first_undone_text = nil
  for _, obj in ipairs(objectives) do
    if not obj.done then
      first_undone_text = obj.text
      break
    end
  end

  return objectives, first_undone_text
end

-- ============================================================================
-- DASHBOARD
-- ============================================================================

local DailyNote = {} -- forward declaration (methods added later)
local Dashboard = {}

-- Scan folder for projects with at least one undone objective
-- Returns list of {name, objectives, first_undone_text, age}
function Dashboard.scan(folder)
  local dir = Utils.build_path(folder)
  local files = vim.fn.glob(dir .. "/*.md", false, true)
  local entries = {}

  for _, fp in ipairs(files) do
    local name = fp:match("([^/]+)%.md$")
    if name then
      local content = Utils.read_file(fp)
      if content then
        local objectives, first_undone_text = ProjectFile.all_objectives(content)
        if first_undone_text then -- has at least one undone objective
          table.insert(entries, {
            name = name,
            objectives = objectives,
            first_undone_text = first_undone_text,
            age = 1,
          })
          Debug.log("Found: %s -> %d objectives", name, #objectives)
        end
      end
    end
  end

  return entries
end

-- Parse lines from a dashboard section for age tracking
-- Returns: linked = {[name] = {age, first_undone_text}}, unlinked = {{text, age}, ...}
function Dashboard.parse_prev_lines(section_lines, linked, unlinked)
  linked = linked or {}
  unlinked = unlinked or {}
  local current_project = nil
  local last_unlinked = nil

  for _, line in ipairs(section_lines or {}) do
    local trimmed = Utils.trim(line)
    local indent = Utils.get_indent_level(line)

    if trimmed == "" then
      -- skip blank lines
    elseif indent == 0 and trimmed:match("^%-") then
      current_project = nil
      last_unlinked = nil
      local text = TaskParser.text(line)
      local project = Utils.extract_link(text)

      if project then
        local age = Utils.extract_age(text)
        linked[project] = { age = age, first_undone_text = "" }
        current_project = project
      else
        -- Unlinked personal task
        local m = TaskParser.marker(line)
        if not Utils.is_done(m) then
          last_unlinked = {
            text = Utils.strip_age(text),
            age = Utils.extract_age(text),
            notes = {},
          }
          table.insert(unlinked, last_unlinked)
        end
      end
    elseif indent >= 1 and trimmed:match("^%-") then
      if last_unlinked and not current_project then
        -- Indented line under unlinked task: preserve as note
        table.insert(last_unlinked.notes, line)
      elseif current_project then
        -- Indented objective line: find first undone for age tracking
        local entry = linked[current_project]
        if entry.first_undone_text == "" then
          local obj_text = trimmed:match("^%-%s*(.*)") or trimmed
          local clean = obj_text:gsub("%s*[🟩🟨⬜✅]+%s*$", "")
          clean = Utils.trim(clean)
          local marker = trimmed:match("^%-%s*(%[.%])")
          if marker and Utils.is_done(marker) then
            -- skip done objectives
          else
            entry.first_undone_text = clean
          end
        end
      end
    end
  end

  return linked, unlinked
end

-- Parse previous daily note for age tracking + carry-forward
-- Reads Personal + Work sections (with backward compat for Today)
function Dashboard.parse_prev(content)
  local sections = DailyNote.parse_sections(content)
  local linked, unlinked = {}, {}

  -- Parse Personal section (unlinked tasks + personal projects)
  Dashboard.parse_prev_lines(sections.personal, linked, unlinked)
  -- Parse Work section (work projects)
  Dashboard.parse_prev_lines(sections.work, linked, unlinked)
  -- Backward compat: old "## Today" section (combined)
  Dashboard.parse_prev_lines(sections.today, linked, unlinked)

  return linked, unlinked
end

function Dashboard.same_objective(a, b)
  if not a or not b or a == "" or b == "" then return false end
  return Utils.trim(a):lower() == Utils.trim(b):lower()
end

function Dashboard.make_lines(e)
  local lines = { string.format("- [[%s]] %s", e.name, Utils.keycap(e.age)) }
  for _, obj in ipairs(e.objectives) do
    if not obj.done then
      local progress = Utils.progress_bar(obj.children_done, obj.children_total)
      local bar = ""
      if obj.marker == "[>]" then
        bar = " ⏳"
      else
        bar = progress ~= "" and (" " .. progress) or ""
      end
      table.insert(lines, string.format("    - %s%s", obj.text, bar))
    end
  end
  return lines
end

-- Returns a list of lines for an unlinked task (with optional notes)
function Dashboard.make_unlinked_lines(t)
  local lines = { string.format("- [ ] %s %s", t.text, Utils.keycap(t.age)) }
  if t.notes then
    for _, note in ipairs(t.notes) do
      table.insert(lines, note)
    end
  end
  return lines
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
-- TASKS (personal/tasks.md)
-- ============================================================================

local Tasks = {}

-- Parse tasks file into structured list
-- Each entry: {text, marker, notes={...}, date}
-- date stored as trailing (YYYY-MM-DD) on the task line
function Tasks.read()
  local path = Utils.build_path(Config.tasks_file)
  local content = Utils.read_file(path)
  local entries = {}
  local existing = {} -- lowercase text -> index in entries

  if not content then return entries, existing end

  local current = nil
  for line in content:gmatch("([^\n]*)\n?") do
    local trimmed = Utils.trim(line)
    local indent = Utils.get_indent_level(line)

    if indent == 0 and trimmed:match("^%- %[.%]") then
      local marker = trimmed:match("^%- (%[.%])")
      local rest = trimmed:match("^%- %[.%]%s*(.*)")
      -- Extract date from trailing (YYYY-MM-DD)
      local date = rest:match("%((%d%d%d%d%-%d%d%-%d%d)%)%s*$")
      local text = rest:gsub("%s*%(%d%d%d%d%-%d%d%-%d%d%)%s*$", "")
      current = {
        text = text,
        marker = marker,
        notes = {},
        date = date,
        done = Utils.is_done(marker),
      }
      table.insert(entries, current)
      existing[text:lower()] = #entries
    elseif indent >= 1 and current and trimmed:match("^%-") then
      table.insert(current.notes, line)
    end
  end

  return entries, existing
end

-- Write tasks back to file
function Tasks.write(entries)
  local path = Utils.build_path(Config.tasks_file)
  local lines = { "# Tasks", "" }
  for _, e in ipairs(entries) do
    local date_str = e.date and (" (" .. e.date .. ")") or ""
    table.insert(lines, string.format("- %s %s%s", e.marker, e.text, date_str))
    for _, note in ipairs(e.notes) do
      table.insert(lines, note)
    end
  end
  Utils.write_file(path, table.concat(lines, "\n") .. "\n")
end

-- Sync Google Tasks into file (add new ones)
function Tasks.sync_google(google_tasks, today_date)
  local entries, existing = Tasks.read()
  local changed = false
  local last_entry = nil

  for _, line in ipairs(google_tasks) do
    if line:match("^%- %[.%]") then
      local text = line:match("^%- %[.%]%s*(.*)") or line
      if not existing[text:lower()] then
        last_entry = {
          text = text,
          marker = "[ ]",
          notes = {},
          date = today_date,
          done = false,
        }
        table.insert(entries, last_entry)
        existing[text:lower()] = #entries
        changed = true
        Debug.log("Task added from Google: %s", text)
      else
        last_entry = nil
      end
    elseif line:match("^    %- ") and last_entry then
      table.insert(last_entry.notes, line)
    end
  end

  if changed then Tasks.write(entries) end
  return entries, existing
end

-- Sync tasks from previous daily note's Personal section back to file
-- - Marks done tasks as [x]
-- - Adds manually written tasks that aren't in the file yet
function Tasks.sync_from_daily(prev_personal_lines, ref_date)
  if not prev_personal_lines then return end

  local entries, existing = Tasks.read()
  local changed = false
  local last_entry = nil

  for _, line in ipairs(prev_personal_lines) do
    local trimmed = Utils.trim(line)
    local indent = Utils.get_indent_level(line)

    if indent == 0 and trimmed:match("^%- %[.%]") then
      last_entry = nil
      local marker = trimmed:match("^%- (%[.%])")
      local text = Utils.strip_age(trimmed:match("^%- %[.%]%s*(.*)") or "")
      if text == "" then goto continue end

      local idx = existing[text:lower()]
      if idx then
        -- Existing task: sync done status, track for note merging
        if Utils.is_done(marker) and not entries[idx].done then
          entries[idx].marker = marker
          entries[idx].done = true
          changed = true
          Debug.log("Task marked done: %s", text)
        end
        last_entry = entries[idx]
      else
        -- New task from daily note: add to file
        local entry = {
          text = text,
          marker = marker,
          notes = {},
          date = ref_date,
          done = Utils.is_done(marker),
        }
        table.insert(entries, entry)
        existing[text:lower()] = #entries
        last_entry = entry
        changed = true
        Debug.log("Task added from daily note: %s", text)
      end
    elseif indent >= 1 and last_entry and trimmed:match("^%-") then
      -- Indented note under task: merge if not already present
      local already = false
      for _, n in ipairs(last_entry.notes) do
        if Utils.trim(n) == trimmed then already = true; break end
      end
      if not already then
        table.insert(last_entry.notes, line)
        changed = true
        Debug.log("Note merged into task: %s", trimmed)
      end
    else
      last_entry = nil
    end

    ::continue::
  end

  if changed then Tasks.write(entries) end
end

-- Get undone tasks for display, with age calculated from creation date
function Tasks.get_undone(today_date)
  local entries = Tasks.read()
  local result = {}
  for _, e in ipairs(entries) do
    if not e.done then
      local age = 1
      if e.date then
        age = math.max(1, Utils.days_between(e.date, today_date))
      end
      table.insert(result, {
        text = e.text,
        age = math.min(age, 9),
        notes = e.notes,
      })
    end
  end
  return result
end

-- ============================================================================
-- CALENDAR
-- ============================================================================

local Calendar = {}

-- Fetch today's events and tasks by calling the calendar script
-- Returns: events (list of lines), tasks (list of lines)
function Calendar.fetch()
  local output = vim.fn.system(Config.calendar_script)
  if vim.v.shell_error ~= 0 then return {}, {} end

  local events, tasks = {}, {}
  local in_tasks = false
  for line in output:gmatch("([^\n]*)\n?") do
    local trimmed = Utils.trim(line)
    if trimmed == "---TASKS---" then
      in_tasks = true
    elseif trimmed ~= "" then
      if in_tasks then
        table.insert(tasks, line) -- preserve indentation for note lines
      else
        table.insert(events, trimmed)
      end
    end
  end
  return events, tasks
end

-- ============================================================================
-- DAILY NOTE
-- ============================================================================

function DailyNote.parse_sections(content)
  local lines = Utils.split_lines(content)
  local sections = {}
  local key, buf = nil, {}

  for _, line in ipairs(lines) do
    local new_key = nil
    if line == Config.sections.events then new_key = "events"
    elseif line == "## Meetings" then new_key = "events" -- backward compat
    elseif line == Config.sections.personal then new_key = "personal"
    elseif line == Config.sections.work then new_key = "work"
    elseif line == "## Today" then new_key = "today" -- backward compat
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
      prev_linked, prev_unlinked = Dashboard.parse_prev(content)
      prev_sections = DailyNote.parse_sections(content)
      days_gap = Utils.days_between(ref_date, today)
      Debug.log("Ref: %s, Days gap: %d", ref_date, days_gap)
    end
  end

  -- Scan project folders for undone objectives
  local work = Dashboard.scan(Config.projects_folder)
  local personal = Dashboard.scan(Config.personal_folder)

  -- Calculate ages (same first_undone_text = increment, different = reset to 1)
  for _, e in ipairs(work) do
    local prev = prev_linked[e.name]
    if prev and Dashboard.same_objective(prev.first_undone_text, e.first_undone_text) then
      e.age = math.min(prev.age + days_gap, 9)
    end
  end

  for _, e in ipairs(personal) do
    local prev = prev_linked[e.name]
    if prev and Dashboard.same_objective(prev.first_undone_text, e.first_undone_text) then
      e.age = math.min(prev.age + days_gap, 9)
    end
  end

  -- Fetch calendar events and Google Tasks
  local events_lines, google_tasks = Calendar.fetch()

  -- Sync tasks from previous daily note back to tasks file (done + new manual tasks)
  Tasks.sync_from_daily(prev_sections.personal, ref_date or today)

  -- Sync Google Tasks into tasks file (adds new ones)
  Tasks.sync_google(google_tasks, today)

  -- Read undone tasks from file (source of truth)
  local unlinked = Tasks.get_undone(today)

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

  -- Build Personal lines: unlinked tasks -> personal projects
  local personal_lines = {}
  for _, t in ipairs(unlinked) do
    for _, line in ipairs(Dashboard.make_unlinked_lines(t)) do
      table.insert(personal_lines, line)
    end
  end
  for _, e in ipairs(personal) do
    for _, line in ipairs(Dashboard.make_lines(e)) do
      table.insert(personal_lines, line)
    end
  end

  -- Build Work lines: work projects
  local work_lines = {}
  for _, e in ipairs(work) do
    for _, line in ipairs(Dashboard.make_lines(e)) do
      table.insert(work_lines, line)
    end
  end

  -- Sync mail tasks from digests into payments.md
  Mail.sync()
  local mail_tasks = Mail.get_undone()

  -- Events: fall back to carry-forward if fetch returned nothing
  if #events_lines == 0 and DailyNote.has_content(prev_sections.events) then
    events_lines = prev_sections.events
  end

  -- Carry forward Notes from previous note if they have content
  local notes_lines = {}
  if DailyNote.has_content(prev_sections.notes) then
    notes_lines = prev_sections.notes
  end

  -- Build final output: Events -> Personal -> Work -> Important -> Notes
  local out = {
    "---",
    "tags:",
    "  - daily",
    'date: "' .. today .. '"',
    "---",
    "",
    "# " .. today,
    "",
    Config.sections.events,
  }

  if #events_lines > 0 then
    for _, line in ipairs(events_lines) do table.insert(out, line) end
  else
    table.insert(out, "")
  end
  table.insert(out, "")

  table.insert(out, Config.sections.personal)
  for _, line in ipairs(personal_lines) do table.insert(out, line) end
  if #mail_tasks > 0 then
    -- Build set of existing unlinked task texts to deduplicate against mail
    local seen = {}
    for _, t in ipairs(unlinked) do
      seen[t.text:lower()] = true
    end
    for _, line in ipairs(mail_tasks) do
      local text = line:match("^%- %[.%]%s*(.*)") or ""
      if not seen[text:lower()] then
        table.insert(out, line)
      end
    end
  end
  if #personal_lines == 0 and #mail_tasks == 0 then table.insert(out, "") end
  table.insert(out, "")

  table.insert(out, Config.sections.work)
  for _, line in ipairs(work_lines) do table.insert(out, line) end
  if #work_lines == 0 then table.insert(out, "") end
  table.insert(out, "")

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
