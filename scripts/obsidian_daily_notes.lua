--============================================================================
-- Obsidian Daily Note Generator v2 - Improved Task Synchronization
--============================================================================
--
-- Key behaviors:
-- 1. Work Objectives: Mark as [x] if corresponding Work todo was completed
-- 2. Work todos: Only import uncompleted tasks for objectives that are [ ]
-- 3. Completed Work todos sync their state + new comments back to project file
-- 4. Personal todos: Filter out completed top-level, keep children as-is
-- 5. Emoji counter (⏰) increments on uncompleted tasks each day
--
--============================================================================

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local Config = {
  daily_folder = "daily",
  projects_folder = "projects",

  undone_markers = { "[ ]", "[~]", "[!]", "[>]" },
  done_marker = "[x]",

  day_counter_emoji = "\226\143\176",  -- UTF-8 for ⏰

  indent_size = 4,
  indent_char = " ",

  sections = {
    meetings = "## " .. "\240\159\145\165" .. " Meetings",
    work_objectives = "## " .. "\240\159\167\145\226\128\141\240\159\146\187" .. " Work Objectives",
    work_todos = "## " .. "\240\159\167\145\226\128\141\240\159\146\187" .. " Work todos",
    personal_todos = "## " .. "\240\159\143\161" .. " Personal todos",
    new_info = "## " .. "\240\159\147\145" .. " New info",
    scratch_notes = "## " .. "\240\159\147\157" .. " Scratch notes",
  },

  project_objectives_header = "## Objectives",

  debug = false,  -- Set to true for testing
}

-- ============================================================================
-- DEBUG MODULE
-- ============================================================================

local Debug = {}

function Debug.log(message, ...)
  if Config.debug then
    local formatted = string.format(message, ...)
    print(string.format("[DEBUG] %s", formatted))
  end
end

-- ============================================================================
-- UTILITY MODULE
-- ============================================================================

local Utils = {}

function Utils.get_today_date()
  return os.date("%Y-%m-%d")
end

function Utils.get_yesterday_date()
  local now = os.time()
  local yesterday = now - (24 * 60 * 60)
  return os.date("%Y-%m-%d", yesterday)
end

function Utils.get_vault_root()
  local ok, obsidian = pcall(require, "obsidian")
  if ok then
    local client = obsidian.get_client()
    if client and client.dir then
      return tostring(client.dir)
    end
  end
  return vim.fn.getcwd()
end

function Utils.build_path(...)
  local parts = {...}
  local vault = Utils.get_vault_root()
  return vault .. "/" .. table.concat(parts, "/")
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

function Utils.join_lines(lines)
  return table.concat(lines, "\n")
end

function Utils.get_indent_level(line)
  local spaces = line:match("^(%s*)")
  return math.floor(#spaces / Config.indent_size)
end

function Utils.make_indent(level)
  return string.rep(string.rep(Config.indent_char, Config.indent_size), level)
end

function Utils.trim(str)
  return str:match("^%s*(.-)%s*$")
end

function Utils.strip_emoji_counters(text)
  -- For comparison: strips emoji and normalizes whitespace
  local result = text:gsub("%s*" .. Config.day_counter_emoji .. "%s*", " ")
  result = result:gsub("%s+", " ")
  return Utils.trim(result)
end

function Utils.remove_emoji_only(text)
  -- For project files: strips emoji but preserves original whitespace
  local result = text:gsub("%s*" .. Config.day_counter_emoji, "")
  return Utils.trim(result)
end

function Utils.count_emoji_counters(text)
  local count = 0
  for _ in text:gmatch(Config.day_counter_emoji) do
    count = count + 1
  end
  return count
end

function Utils.add_emoji_counter(text, count)
  count = count or 1
  local emoji_str = string.rep(" " .. Config.day_counter_emoji, count)

  local link_pattern = "%[%[[^%]]+%]%]%s*$"
  local link = text:match(link_pattern)

  if link then
    local before_link = text:gsub(link_pattern, "")
    before_link = Utils.trim(before_link)
    return before_link .. emoji_str .. " " .. link
  else
    return Utils.trim(text) .. emoji_str
  end
end

function Utils.extract_project_link(text)
  return text:match("%[%[([^%]]+)%]%]")
end

function Utils.deep_copy(orig)
  local copy
  if type(orig) == "table" then
    copy = {}
    for k, v in pairs(orig) do
      copy[k] = Utils.deep_copy(v)
    end
  else
    copy = orig
  end
  return copy
end

-- ============================================================================
-- TASK PARSER MODULE
-- ============================================================================

local TaskParser = {}

function TaskParser.is_task_line(line)
  local trimmed = Utils.trim(line)
  return trimmed:match("^%-%s*%[.%]") ~= nil
end

function TaskParser.is_list_item(line)
  local trimmed = Utils.trim(line)
  return trimmed:match("^%-") ~= nil
end

function TaskParser.is_done_task(line)
  local trimmed = Utils.trim(line)
  return trimmed:match("^%-%s*%[x%]") ~= nil
end

function TaskParser.is_undone_task(line)
  local trimmed = Utils.trim(line)
  for _, marker in ipairs(Config.undone_markers) do
    local escaped = marker:gsub("[%[%]]", "%%%1")
    if trimmed:match("^%-%s*" .. escaped) then
      return true
    end
  end
  return false
end

function TaskParser.extract_marker(line)
  local trimmed = Utils.trim(line)
  return trimmed:match("^%-%s*(%[.%])")
end

function TaskParser.extract_text(line)
  local trimmed = Utils.trim(line)
  local text = trimmed:match("^%-%s*%[.%]%s*(.*)") or trimmed:match("^%-%s*(.*)")
  return text or trimmed
end

function TaskParser.parse_task_tree(lines, start_idx, end_idx, base_indent)
  start_idx = start_idx or 1
  end_idx = end_idx or #lines
  base_indent = base_indent or 0

  local tasks = {}
  local i = start_idx

  while i <= end_idx do
    local line = lines[i]
    local indent = Utils.get_indent_level(line)
    local trimmed = Utils.trim(line)

    if trimmed == "" then
      i = i + 1
    elseif indent == base_indent and TaskParser.is_list_item(line) then
      local task = {
        raw_line = line,
        indent = indent,
        is_task = TaskParser.is_task_line(line),
        marker = TaskParser.extract_marker(line),
        text = TaskParser.extract_text(line),
        children = {},
        emoji_count = Utils.count_emoji_counters(line),
      }

      -- Find children
      local child_end = i
      for j = i + 1, end_idx do
        local child_line = lines[j]
        local child_indent = Utils.get_indent_level(child_line)
        local child_trimmed = Utils.trim(child_line)

        if child_trimmed == "" then
          child_end = j
        elseif child_indent > base_indent then
          child_end = j
        else
          break
        end
      end

      if child_end > i then
        task.children = TaskParser.parse_task_tree(lines, i + 1, child_end, base_indent + 1)
      end

      table.insert(tasks, task)
      i = child_end + 1
    else
      i = i + 1
    end
  end

  return tasks
end

function TaskParser.tree_to_lines(tasks, base_indent, add_spacing)
  base_indent = base_indent or 0
  add_spacing = add_spacing or false
  local lines = {}

  for i, task in ipairs(tasks) do
    -- Add blank line between top-level tasks if spacing enabled (not before first)
    if add_spacing and base_indent == 0 and i > 1 then
      table.insert(lines, "")
    end

    local indent_str = Utils.make_indent(base_indent)
    local line

    if task.is_task and task.marker then
      line = string.format("%s- %s %s", indent_str, task.marker, task.text)
    else
      line = string.format("%s- %s", indent_str, task.text)
    end

    table.insert(lines, line)

    if task.children and #task.children > 0 then
      local child_lines = TaskParser.tree_to_lines(task.children, base_indent + 1, false)
      for _, child_line in ipairs(child_lines) do
        table.insert(lines, child_line)
      end
    end
  end

  return lines
end

-- ============================================================================
-- DAILY NOTE MODULE
-- ============================================================================

local DailyNote = {}

function DailyNote.generate_template(date)
  local lines = {
    "---",
    'id: "' .. date .. '"',
    "aliases: []",
    "tags:",
    "  - daily",
    "  - daily-notes",
    "Data created: " .. os.date("%H:%M"),
    'date: "' .. date .. '"',
    "links:",
    '  - "[[Week]]"',
    '  - "[[Year]]"',
    "---",
    "",
    "# " .. "\240\159\151\147\239\184\143" .. " " .. date,
    "",
    Config.sections.meetings,
    "",
    Config.sections.work_objectives,
    "",
    Config.sections.work_todos,
    "",
    Config.sections.personal_todos,
    "",
    Config.sections.new_info,
    "-",
    "",
    Config.sections.scratch_notes,
    "-",
    "",
  }
  return table.concat(lines, "\n")
end

function DailyNote.parse_sections(content)
  local lines = Utils.split_lines(content)
  local sections = {}
  local current_section = "frontmatter"
  local section_lines = {}
  local in_frontmatter = false
  local frontmatter_count = 0

  for i, line in ipairs(lines) do
    if line == "---" then
      frontmatter_count = frontmatter_count + 1
      if frontmatter_count == 1 then
        in_frontmatter = true
        table.insert(section_lines, line)
      elseif frontmatter_count == 2 then
        in_frontmatter = false
        table.insert(section_lines, line)
        sections[current_section] = section_lines
        section_lines = {}
        current_section = "header"
      end
    elseif in_frontmatter then
      table.insert(section_lines, line)
    elseif line:match("^## ") then
      if current_section and #section_lines > 0 then
        sections[current_section] = section_lines
      end

      section_lines = {line}
      if line == Config.sections.meetings then
        current_section = "meetings"
      elseif line == Config.sections.work_objectives then
        current_section = "work_objectives"
      elseif line == Config.sections.work_todos then
        current_section = "work_todos"
      elseif line == Config.sections.personal_todos then
        current_section = "personal_todos"
      elseif line == Config.sections.new_info then
        current_section = "new_info"
      elseif line == Config.sections.scratch_notes then
        current_section = "scratch_notes"
      else
        current_section = "other_" .. i
      end
    else
      table.insert(section_lines, line)
    end
  end

  if current_section and #section_lines > 0 then
    sections[current_section] = section_lines
  end

  return sections
end

function DailyNote.extract_tasks_from_section(section_lines)
  if not section_lines or #section_lines == 0 then return {} end

  local task_lines = {}
  local skip_header = true

  for _, line in ipairs(section_lines) do
    if skip_header and line:match("^## ") then
      skip_header = false
    elseif not skip_header then
      table.insert(task_lines, line)
    end
  end

  return TaskParser.parse_task_tree(task_lines, 1, #task_lines, 0)
end

function DailyNote.build_section(header, tasks, options)
  options = options or {}
  local add_spacing = options.spacing or false

  local lines = {header}

  local task_lines = TaskParser.tree_to_lines(tasks, 0, add_spacing)

  for _, line in ipairs(task_lines) do
    table.insert(lines, line)
  end

  if #task_lines == 0 then
    table.insert(lines, "")
  end

  -- Add trailing blank line for section separation
  table.insert(lines, "")

  return lines
end

function DailyNote.reconstruct(sections)
  local parts = {}

  if sections.frontmatter then
    table.insert(parts, Utils.join_lines(sections.frontmatter))
  end

  if sections.header then
    table.insert(parts, Utils.join_lines(sections.header))
  end

  local section_order = {
    {key = "meetings", header = Config.sections.meetings},
    {key = "work_objectives", header = Config.sections.work_objectives},
    {key = "work_todos", header = Config.sections.work_todos},
    {key = "personal_todos", header = Config.sections.personal_todos},
    {key = "new_info", header = Config.sections.new_info},
    {key = "scratch_notes", header = Config.sections.scratch_notes},
  }

  for _, section in ipairs(section_order) do
    if sections[section.key] then
      table.insert(parts, Utils.join_lines(sections[section.key]))
    end
  end

  return table.concat(parts, "\n")
end

-- ============================================================================
-- PROJECT FILE MODULE
-- ============================================================================

local ProjectFile = {}

function ProjectFile.get_path(project_name)
  return Utils.build_path(Config.projects_folder, project_name .. ".md")
end

function ProjectFile.parse_objectives(content)
  local lines = Utils.split_lines(content)
  local in_objectives = false
  local objectives_lines = {}

  for _, line in ipairs(lines) do
    if line:match("^## Objectives") then
      in_objectives = true
    elseif in_objectives then
      if line:match("^## ") then
        break
      end
      table.insert(objectives_lines, line)
    end
  end

  return TaskParser.parse_task_tree(objectives_lines, 1, #objectives_lines, 0)
end

function ProjectFile.update_objectives(content, new_objectives)
  local lines = Utils.split_lines(content)
  local result = {}
  local in_objectives = false

  for i, line in ipairs(lines) do
    if line:match("^## Objectives") then
      in_objectives = true
      table.insert(result, line)

      local obj_lines = TaskParser.tree_to_lines(new_objectives, 0)
      for _, obj_line in ipairs(obj_lines) do
        table.insert(result, obj_line)
      end
    elseif in_objectives then
      if line:match("^## ") then
        in_objectives = false
        -- Add blank line before next section
        table.insert(result, "")
        table.insert(result, line)
      end
    else
      table.insert(result, line)
    end
  end

  return Utils.join_lines(result)
end

-- ============================================================================
-- TASK SYNCHRONIZATION MODULE
-- ============================================================================

local TaskSync = {}

function TaskSync.normalize_text(text)
  local normalized = Utils.strip_emoji_counters(text)
  normalized = normalized:gsub("%[%[[^%]]+%]%]", "")
  return Utils.trim(normalized)
end

function TaskSync.find_matching_task(target_text, task_list)
  local normalized_target = TaskSync.normalize_text(target_text)

  for i, task in ipairs(task_list) do
    local normalized = TaskSync.normalize_text(task.text or "")
    if normalized == normalized_target then
      return i, task
    end
  end

  return nil, nil
end

-- Merge daily into project: keep ALL project items, add NEW daily items, update status
-- Project is the archive - never delete anything from it
function TaskSync.merge_daily_into_project(daily_children, project_children)
  -- Start with all project children (the archive)
  local merged = {}
  for _, pc in ipairs(project_children or {}) do
    table.insert(merged, Utils.deep_copy(pc))
  end

  -- For each daily child, either update existing or add new
  for _, dc in ipairs(daily_children or {}) do
    local idx, pc = TaskSync.find_matching_task(dc.text, merged)
    if idx then
      -- Found match - update status if daily is [x]
      if dc.marker == "[x]" then
        merged[idx].marker = "[x]"
        merged[idx].is_task = true
      end
      -- Recursively merge children
      merged[idx].children = TaskSync.merge_daily_into_project(
        dc.children or {},
        merged[idx].children or {}
      )
    else
      -- New item from daily - add to project (strip emoji first)
      local stripped = Utils.deep_copy(dc)
      stripped.text = Utils.remove_emoji_only(dc.text or "")
      stripped.emoji_count = 0
      if dc.children and #dc.children > 0 then
        stripped.children = TaskSync.strip_emoji_from_tree(dc.children)
      end
      table.insert(merged, stripped)
    end
  end

  return merged
end

-- Sync daily task to project file (update status, add new items, never delete)
function TaskSync.sync_to_project(daily_task, project_name)
  Debug.log("Syncing task to project: %s", project_name)

  local project_path = ProjectFile.get_path(project_name)
  local project_content = Utils.read_file(project_path)

  if not project_content then
    Debug.log("Project file not found: %s", project_path)
    return nil
  end

  local project_objectives = ProjectFile.parse_objectives(project_content)
  local daily_normalized = TaskSync.normalize_text(daily_task.text)

  -- Find matching objective
  for i, obj in ipairs(project_objectives) do
    if TaskSync.normalize_text(obj.text) == daily_normalized then
      Debug.log("Found matching objective at index %d", i)

      -- Update marker if daily task is done
      if daily_task.marker == "[x]" then
        project_objectives[i].marker = "[x]"
        project_objectives[i].is_task = true
      end

      -- Merge children: keep all project items, add new daily items, update status
      project_objectives[i].children = TaskSync.merge_daily_into_project(
        daily_task.children or {},
        obj.children or {}
      )

      break
    end
  end

  return ProjectFile.update_objectives(project_content, project_objectives)
end

-- Filter out [x] done tasks with their entire subtree (for daily import)
function TaskSync.filter_undone_tree(tasks)
  local result = {}
  for _, task in ipairs(tasks or {}) do
    -- Skip [x] done tasks entirely (with all children)
    if task.marker ~= "[x]" then
      local copy = Utils.deep_copy(task)
      -- Recursively filter children
      if task.children and #task.children > 0 then
        copy.children = TaskSync.filter_undone_tree(task.children)
      end
      table.insert(result, copy)
    end
  end
  return result
end

-- Strip emoji counters from entire task tree
function TaskSync.strip_emoji_from_tree(tasks)
  local result = {}
  for _, task in ipairs(tasks) do
    local stripped = Utils.deep_copy(task)
    -- Use remove_emoji_only to preserve original whitespace
    stripped.text = Utils.remove_emoji_only(task.text or "")
    stripped.emoji_count = 0
    if task.children and #task.children > 0 then
      stripped.children = TaskSync.strip_emoji_from_tree(task.children)
    end
    table.insert(result, stripped)
  end
  return result
end

-- Load objective from project file for importing into Work todos
-- Only imports uncompleted tasks (filters out [x] done with their subtrees)
function TaskSync.load_project_objective(project_name, objective_text)
  local project_path = ProjectFile.get_path(project_name)
  local project_content = Utils.read_file(project_path)

  if not project_content then
    Debug.log("Project file not found: %s", project_path)
    return nil
  end

  local project_objectives = ProjectFile.parse_objectives(project_content)
  local normalized_daily = TaskSync.normalize_text(objective_text)

  Debug.log("Looking for objective matching: '%s'", normalized_daily)

  for _, obj in ipairs(project_objectives) do
    local normalized_proj = TaskSync.normalize_text(obj.text)
    Debug.log("  Comparing with project objective: '%s'", normalized_proj)

    -- Match if project text starts with daily text (handles "Objective 2" matching "Objective 2 project2")
    if normalized_proj:sub(1, #normalized_daily) == normalized_daily then
      Debug.log("  -> Match found!")

      -- Skip if the objective itself is done
      if obj.marker == "[x]" then
        Debug.log("  -> Objective is done, skipping")
        return nil
      end

      -- Add project link to text if not present
      local task_copy = Utils.deep_copy(obj)
      if not Utils.extract_project_link(task_copy.text) then
        task_copy.text = task_copy.text .. " [[" .. project_name .. "]]"
      end

      -- Filter out done subtasks with their children
      task_copy.children = TaskSync.filter_undone_tree(obj.children or {})

      return task_copy
    end
  end

  Debug.log("  -> No match found")
  return nil
end

-- ============================================================================
-- MAIN WORKFLOW
-- ============================================================================

Debug.log("=== Starting Daily Note Creation ===")

local today = Utils.get_today_date()
local yesterday = Utils.get_yesterday_date()

Debug.log("Today: %s, Yesterday: %s", today, yesterday)

local today_path = Utils.build_path(Config.daily_folder, today .. ".md")
local yesterday_path = Utils.build_path(Config.daily_folder, yesterday .. ".md")

-- Check if today's note exists
if Utils.file_exists(today_path) then
  Debug.log("Today's note already exists, opening it")
  vim.cmd("edit " .. today_path)
  return
end

-- Start with template
local today_content = DailyNote.generate_template(today)
local today_sections = DailyNote.parse_sections(today_content)

-- Load yesterday's note
local yesterday_content = Utils.read_file(yesterday_path)

if yesterday_content then
  Debug.log("Processing yesterday's note")
  local yesterday_sections = DailyNote.parse_sections(yesterday_content)

  -- Parse yesterday's work objectives and todos
  local yesterday_objectives = DailyNote.extract_tasks_from_section(yesterday_sections.work_objectives or {})
  local yesterday_todos = DailyNote.extract_tasks_from_section(yesterday_sections.work_todos or {})

  -- Build lookup: project_name -> completed todo task
  local completed_todos = {}  -- project_name -> daily_task (if top-level completed)
  local uncompleted_todos = {}  -- project_name -> daily_task (if top-level uncompleted)

  for _, todo in ipairs(yesterday_todos) do
    local project_name = Utils.extract_project_link(todo.text)
    if project_name then
      if todo.marker == "[x]" then
        completed_todos[project_name] = todo
        Debug.log("Completed todo for project: %s", project_name)
      else
        uncompleted_todos[project_name] = todo
        Debug.log("Uncompleted todo for project: %s", project_name)
      end
    end
  end

  -- ========================================================================
  -- STEP 1: Process Work Objectives
  -- Mark as [x] if corresponding todo was completed
  -- ========================================================================
  local new_objectives = {}

  for _, obj in ipairs(yesterday_objectives) do
    local copy = Utils.deep_copy(obj)
    local project_name = Utils.extract_project_link(obj.text)

    if project_name and obj.is_task and completed_todos[project_name] then
      -- This objective's todo was completed - mark as done
      copy.marker = "[x]"
      copy.is_task = true
      Debug.log("Marking objective as done: %s", obj.text)
    end

    table.insert(new_objectives, copy)
  end

  today_sections.work_objectives = DailyNote.build_section(
    Config.sections.work_objectives,
    new_objectives
  )

  -- ========================================================================
  -- STEP 2: Process Work Todos
  -- - Sync ALL todos to project files (update status, add new items)
  -- - Import uncompleted tasks for [ ] objectives from project
  -- - Objectives without checkbox (just -): don't import
  -- ========================================================================
  local project_updates = {}  -- project_name -> updated content
  local new_todos = {}

  -- Sync ALL work todos to project files (update status, add new subtasks/comments)
  for _, todo in ipairs(yesterday_todos) do
    local project_name = Utils.extract_project_link(todo.text)
    if project_name then
      local updated = TaskSync.sync_to_project(todo, project_name)
      if updated then
        project_updates[project_name] = updated
      end
    end
  end

  -- Import uncompleted tasks for objectives that are [ ]
  for _, obj in ipairs(yesterday_objectives) do
    local project_name = Utils.extract_project_link(obj.text)

    if project_name and obj.is_task and obj.marker ~= "[x]" then
      -- This objective has a checkbox and is not done

      if not completed_todos[project_name] then
        -- No completed todo for this project - import from project file
        local imported = TaskSync.load_project_objective(project_name, obj.text)
        if imported then
          Debug.log("Imported objective from project: %s", project_name)
          table.insert(new_todos, imported)
        end
      end
    elseif project_name and not obj.is_task then
      -- Objective is just a comment (no checkbox) - don't import
      Debug.log("Skipping comment objective: %s", obj.text)
    end
  end

  today_sections.work_todos = DailyNote.build_section(
    Config.sections.work_todos,
    new_todos,
    {spacing = true}
  )

  -- ========================================================================
  -- STEP 3: Process Personal Todos
  -- - Filter out completed top-level tasks
  -- - Keep children as-is (including completed subtasks)
  -- - Increment emoji counter for uncompleted tasks
  -- ========================================================================
  local yesterday_personal = DailyNote.extract_tasks_from_section(yesterday_sections.personal_todos or {})
  local new_personal = {}

  for _, task in ipairs(yesterday_personal) do
    -- Only keep uncompleted top-level tasks
    if task.marker ~= "[x]" then
      local copy = Utils.deep_copy(task)

      -- Increment emoji counter for the top task (if undone)
      if task.is_task then
        local is_undone = false
        for _, marker in ipairs(Config.undone_markers) do
          if task.marker == marker then is_undone = true break end
        end

        if is_undone then
          copy.emoji_count = (copy.emoji_count or 0) + 1
          copy.text = Utils.add_emoji_counter(
            Utils.strip_emoji_counters(copy.text),
            copy.emoji_count
          )
        end
      end

      table.insert(new_personal, copy)
    else
      Debug.log("Filtering out completed personal task: %s", task.text)
    end
  end

  today_sections.personal_todos = DailyNote.build_section(
    Config.sections.personal_todos,
    new_personal
  )

  -- ========================================================================
  -- STEP 4: Import other sections
  -- ========================================================================
  if yesterday_sections.new_info then
    today_sections.new_info = Utils.deep_copy(yesterday_sections.new_info)
  end

  if yesterday_sections.scratch_notes then
    today_sections.scratch_notes = Utils.deep_copy(yesterday_sections.scratch_notes)
  end

  -- ========================================================================
  -- STEP 5: Write updated project files
  -- ========================================================================
  for project_name, updated_content in pairs(project_updates) do
    local project_path = ProjectFile.get_path(project_name)
    Debug.log("Writing updated project file: %s", project_path)
    Utils.write_file(project_path, updated_content)
  end
else
  Debug.log("No yesterday's note found, starting fresh")
end

-- ========================================================================
-- STEP 6: Write today's note
-- ========================================================================
local final_content = DailyNote.reconstruct(today_sections)

local daily_dir = Utils.build_path(Config.daily_folder)
vim.fn.mkdir(daily_dir, "p")

Utils.write_file(today_path, final_content)

vim.cmd("edit " .. today_path)

Debug.log("=== Daily Note Creation Complete ===")
vim.notify("Daily note created: " .. today, vim.log.levels.INFO)
