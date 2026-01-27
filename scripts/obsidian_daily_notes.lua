--============================================================================
-- Obsidian Daily Note Generator with Task Synchronization
--============================================================================
--
-- Features:
-- - Creates new daily note from template
-- - Imports undone tasks from previous day with day counter emoji
-- - Synchronizes work tasks with project files
-- - Preserves nested task/subtask/comment structure
--
--============================================================================

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local Config = {
  -- Paths (relative to vault root)
  daily_folder = "daily",
  projects_folder = "projects",
  
  -- Task markers that indicate undone tasks
  undone_markers = { "[ ]", "[~]", "[!]", "[>]" },
  
  -- Task marker that indicates done task
  done_marker = "[x]",
  
  -- Emoji used to track days spent on task
  day_counter_emoji = "\226\143\176",  -- UTF-8 for ⏰
  
  -- Indentation (4 spaces)
  indent_size = 4,
  indent_char = " ",
  
  -- Section headers in daily note (using concat to avoid nix issues)
  sections = {
    meetings = "## " .. "\240\159\145\165" .. " Meetings",
    work_objectives = "## " .. "\240\159\167\145\226\128\141\240\159\146\187" .. " Work Objectives",
    work_todos = "## " .. "\240\159\167\145\226\128\141\240\159\146\187" .. " Work todos",
    personal_todos = "## " .. "\240\159\143\161" .. " Personal todos",
    new_info = "## " .. "\240\159\147\145" .. " New info",
    scratch_notes = "## " .. "\240\159\147\157" .. " Scratch notes",
  },
  
  -- Section header in project file for objectives
  project_objectives_header = "## Objectives",
  
  -- Enable debug logging (set to true for troubleshooting)
  debug = false,
}

-- ============================================================================
-- DEBUG / LOGGING MODULE
-- ============================================================================

local Debug = {}

function Debug.log(message, ...)
  if Config.debug then
    local formatted = string.format(message, ...)
    print(string.format("[DAILY-NOTE DEBUG] %s", formatted))
  end
end

function Debug.log_table(name, tbl, indent)
  if not Config.debug then return end
  indent = indent or 0
  local prefix = string.rep("  ", indent)
  
  if type(tbl) ~= "table" then
    print(string.format("%s[DEBUG] %s = %s", prefix, name, tostring(tbl)))
    return
  end
  
  print(string.format("%s[DEBUG] %s = {", prefix, name))
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      Debug.log_table(tostring(k), v, indent + 1)
    else
      print(string.format("%s  [%s] = %s", prefix, tostring(k), tostring(v)))
    end
  end
  print(string.format("%s}", prefix))
end

function Debug.log_task_tree(name, tasks, indent)
  if not Config.debug then return end
  indent = indent or 0
  local prefix = string.rep("  ", indent)
  
  print(string.format("%s[DEBUG] %s:", prefix, name))
  for i, task in ipairs(tasks) do
    print(string.format("%s  [%d] text='%s' indent=%d is_task=%s marker='%s'",
      prefix, i, task.text or "", task.indent or 0, 
      tostring(task.is_task), task.marker or ""))
    if task.children and #task.children > 0 then
      Debug.log_task_tree("children", task.children, indent + 2)
    end
  end
end

-- ============================================================================
-- UTILITY MODULE
-- ============================================================================

local Utils = {}

-- Get current date as YYYY-MM-DD
function Utils.get_today_date()
  return os.date("%Y-%m-%d")
end

-- Get yesterday's date as YYYY-MM-DD
function Utils.get_yesterday_date()
  local now = os.time()
  local yesterday = now - (24 * 60 * 60)
  return os.date("%Y-%m-%d", yesterday)
end

-- Get vault root path
function Utils.get_vault_root()
  -- Try obsidian.nvim method first
  local ok, obsidian = pcall(require, "obsidian")
  if ok then
    local client = obsidian.get_client()
    if client and client.dir then
      return tostring(client.dir)
    end
  end
  
  -- Fallback: use current working directory
  return vim.fn.getcwd()
end

-- Build full path from vault root
function Utils.build_path(...)
  local parts = {...}
  local vault = Utils.get_vault_root()
  return vault .. "/" .. table.concat(parts, "/")
end

-- Check if file exists
function Utils.file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

-- Read file contents
function Utils.read_file(path)
  Debug.log("Reading file: %s", path)
  local f = io.open(path, "r")
  if not f then
    Debug.log("File not found: %s", path)
    return nil
  end
  local content = f:read("*all")
  f:close()
  Debug.log("Read %d bytes from %s", #content, path)
  return content
end

-- Write file contents
function Utils.write_file(path, content)
  Debug.log("Writing file: %s (%d bytes)", path, #content)
  local f = io.open(path, "w")
  if not f then
    Debug.log("ERROR: Cannot write to file: %s", path)
    return false
  end
  f:write(content)
  f:close()
  Debug.log("Successfully wrote file: %s", path)
  return true
end

-- Split string by newlines
function Utils.split_lines(str)
  local lines = {}
  for line in str:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end
  -- Remove last empty element if present
  if lines[#lines] == "" then
    table.remove(lines)
  end
  return lines
end

-- Join lines into string
function Utils.join_lines(lines)
  return table.concat(lines, "\n")
end

-- Get indentation level (count of leading spaces / indent_size)
function Utils.get_indent_level(line)
  local spaces = line:match("^(%s*)")
  return math.floor(#spaces / Config.indent_size)
end

-- Create indentation string
function Utils.make_indent(level)
  return string.rep(string.rep(Config.indent_char, Config.indent_size), level)
end

-- Strip leading/trailing whitespace
function Utils.trim(str)
  return str:match("^%s*(.-)%s*$")
end

-- Strip emoji counters from text for comparison
function Utils.strip_emoji_counters(text)
  -- Remove all day_counter_emoji and surrounding spaces
  local result = text:gsub("%s*" .. Config.day_counter_emoji .. "%s*", " ")
  -- Normalize multiple spaces
  result = result:gsub("%s+", " ")
  return Utils.trim(result)
end

-- Count emoji counters in text
function Utils.count_emoji_counters(text)
  local count = 0
  for _ in text:gmatch(Config.day_counter_emoji) do
    count = count + 1
  end
  return count
end

-- Add emoji counter to text (at the end, before any trailing link)
function Utils.add_emoji_counter(text, count)
  count = count or 1
  local emoji_str = string.rep(" " .. Config.day_counter_emoji, count)
  
  -- Check if text ends with a wiki link
  local link_pattern = "%[%[[^%]]+%]%]%s*$"
  local link = text:match(link_pattern)
  
  if link then
    -- Insert emoji before the link
    local before_link = text:gsub(link_pattern, "")
    before_link = Utils.trim(before_link)
    return before_link .. emoji_str .. " " .. link
  else
    return Utils.trim(text) .. emoji_str
  end
end

-- Extract project link from text (e.g., from "task text [[project1]]" extract "project1")
function Utils.extract_project_link(text)
  return text:match("%[%[([^%]]+)%]%]")
end

-- Deep copy a table
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

-- Check if line is a task (starts with "- [x]", "- [ ]", etc.)
function TaskParser.is_task_line(line)
  local trimmed = Utils.trim(line)
  -- Match "- [" followed by any char and "]"
  return trimmed:match("^%-%s*%[.%]") ~= nil
end

-- Check if line is a comment (starts with "- " but not a task)
function TaskParser.is_comment_line(line)
  local trimmed = Utils.trim(line)
  if trimmed:match("^%-%s*%[.%]") then
    return false  -- It's a task, not a comment
  end
  return trimmed:match("^%-") ~= nil
end

-- Check if task is undone
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

-- Extract marker from task line (e.g., "[ ]", "[x]", "[~]")
function TaskParser.extract_marker(line)
  local trimmed = Utils.trim(line)
  return trimmed:match("^%-%s*(%[.%])")
end

-- Extract text content from task/comment line (without marker)
function TaskParser.extract_text(line)
  local trimmed = Utils.trim(line)
  -- Remove "- [x] " or "- " prefix
  local text = trimmed:match("^%-%s*%[.%]%s*(.*)") or trimmed:match("^%-%s*(.*)")
  return text or trimmed
end

-- Parse lines into hierarchical task structure
function TaskParser.parse_task_tree(lines, start_idx, end_idx, base_indent)
  start_idx = start_idx or 1
  end_idx = end_idx or #lines
  base_indent = base_indent or 0
  
  Debug.log("Parsing task tree: lines %d-%d, base_indent=%d", start_idx, end_idx, base_indent)
  
  local tasks = {}
  local i = start_idx
  
  while i <= end_idx do
    local line = lines[i]
    local indent = Utils.get_indent_level(line)
    local trimmed = Utils.trim(line)
    
    -- Skip empty lines
    if trimmed == "" then
      i = i + 1
    -- Only process lines at base_indent level
    elseif indent == base_indent then
      local task = {
        raw_line = line,
        indent = indent,
        is_task = TaskParser.is_task_line(line),
        is_comment = TaskParser.is_comment_line(line),
        marker = TaskParser.extract_marker(line),
        text = TaskParser.extract_text(line),
        children = {},
        emoji_count = Utils.count_emoji_counters(line),
      }
      
      Debug.log("  Parsed item at line %d: indent=%d, is_task=%s, text='%s'",
        i, indent, tostring(task.is_task), task.text)
      
      -- Find children (lines with indent > base_indent until we hit base_indent again)
      local child_start = i + 1
      local child_end = i
      
      for j = i + 1, end_idx do
        local child_line = lines[j]
        local child_indent = Utils.get_indent_level(child_line)
        local child_trimmed = Utils.trim(child_line)
        
        if child_trimmed == "" then
          -- Empty line might separate tasks, check what comes after
          child_end = j
        elseif child_indent > base_indent then
          child_end = j
        else
          break
        end
      end
      
      -- Recursively parse children
      if child_end > i then
        task.children = TaskParser.parse_task_tree(lines, child_start, child_end, base_indent + 1)
      end
      
      table.insert(tasks, task)
      i = child_end + 1
    else
      -- Line has different indent than expected, skip
      i = i + 1
    end
  end
  
  Debug.log("Parsed %d items at indent level %d", #tasks, base_indent)
  return tasks
end

-- Convert task tree back to lines
function TaskParser.tree_to_lines(tasks, base_indent)
  base_indent = base_indent or 0
  local lines = {}
  
  for _, task in ipairs(tasks) do
    local indent_str = Utils.make_indent(base_indent)
    local line
    
    if task.is_task and task.marker then
      line = string.format("%s- %s %s", indent_str, task.marker, task.text)
    elseif task.is_comment then
      line = string.format("%s- %s", indent_str, task.text)
    else
      line = string.format("%s%s", indent_str, task.text or "")
    end
    
    table.insert(lines, line)
    
    -- Recursively add children
    if task.children and #task.children > 0 then
      local child_lines = TaskParser.tree_to_lines(task.children, base_indent + 1)
      for _, child_line in ipairs(child_lines) do
        table.insert(lines, child_line)
      end
    end
  end
  
  return lines
end

-- Filter to keep only undone tasks (and their children)
function TaskParser.filter_undone(tasks)
  local result = {}
  
  for _, task in ipairs(tasks) do
    if task.is_task then
      -- Check if task is undone
      local is_undone = false
      for _, marker in ipairs(Config.undone_markers) do
        if task.marker == marker then
          is_undone = true
          break
        end
      end
      
      if is_undone then
        -- Keep this task and all its children
        local copy = Utils.deep_copy(task)
        table.insert(result, copy)
      end
    elseif task.is_comment then
      -- Comments at top level are kept as-is
      table.insert(result, Utils.deep_copy(task))
    end
  end
  
  return result
end

-- Add emoji counter to undone tasks
function TaskParser.add_emoji_to_undone(tasks, increment)
  increment = increment or 1
  
  for _, task in ipairs(tasks) do
    if task.is_task then
      local is_undone = false
      for _, marker in ipairs(Config.undone_markers) do
        if task.marker == marker then
          is_undone = true
          break
        end
      end
      
      if is_undone then
        task.emoji_count = (task.emoji_count or 0) + increment
        task.text = Utils.add_emoji_counter(
          Utils.strip_emoji_counters(task.text), 
          task.emoji_count
        )
        Debug.log("Added emoji to task: '%s' (count=%d)", task.text, task.emoji_count)
      end
    end
    
    -- Recursively process children
    if task.children and #task.children > 0 then
      TaskParser.add_emoji_to_undone(task.children, increment)
    end
  end
end

-- ============================================================================
-- DAILY NOTE MODULE
-- ============================================================================

local DailyNote = {}

-- Generate daily note template (using string concat to avoid nix [[ ]] issues)
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
    '  - "' .. "[[Week]]" .. '"',
    '  - "' .. "[[Year]]" .. '"',
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
    "- ",
    "",
    Config.sections.scratch_notes,
    "- ",
    "",
  }
  
  return table.concat(lines, "\n")
end

-- Parse daily note into sections
function DailyNote.parse_sections(content)
  local lines = Utils.split_lines(content)
  local sections = {}
  local current_section = "frontmatter"
  local section_lines = {}
  
  -- Track frontmatter
  local in_frontmatter = false
  local frontmatter_count = 0
  
  for i, line in ipairs(lines) do
    -- Handle frontmatter delimiters
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
    -- Check for section headers
    elseif line:match("^## ") then
      -- Save previous section
      if current_section and #section_lines > 0 then
        sections[current_section] = section_lines
      end
      
      -- Determine new section
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
  
  -- Save last section
  if current_section and #section_lines > 0 then
    sections[current_section] = section_lines
  end
  
  Debug.log("Parsed sections: %s", table.concat(vim.tbl_keys(sections), ", "))
  return sections
end

-- Extract tasks from a section (skip the header line)
function DailyNote.extract_tasks_from_section(section_lines)
  if not section_lines or #section_lines == 0 then
    return {}
  end
  
  -- Skip header line (first line starting with ##)
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

-- Build section content from tasks
function DailyNote.build_section(header, tasks)
  local lines = {header}
  local task_lines = TaskParser.tree_to_lines(tasks, 0)
  
  for _, line in ipairs(task_lines) do
    table.insert(lines, line)
  end
  
  -- Ensure at least empty line if no tasks
  if #task_lines == 0 then
    table.insert(lines, "")
  end
  
  return lines
end

-- Reconstruct daily note from sections
function DailyNote.reconstruct(sections)
  local parts = {}
  
  -- Frontmatter
  if sections.frontmatter then
    table.insert(parts, Utils.join_lines(sections.frontmatter))
  end
  
  -- Header
  if sections.header then
    table.insert(parts, Utils.join_lines(sections.header))
  end
  
  -- Ordered sections
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

-- Get project file path from project name
function ProjectFile.get_path(project_name)
  return Utils.build_path(Config.projects_folder, project_name .. ".md")
end

-- Parse objectives section from project file
function ProjectFile.parse_objectives(content)
  local lines = Utils.split_lines(content)
  local in_objectives = false
  local objectives_lines = {}
  
  for _, line in ipairs(lines) do
    if line:match("^## Objectives") then
      in_objectives = true
    elseif in_objectives then
      -- Stop at next section header
      if line:match("^## ") then
        break
      end
      table.insert(objectives_lines, line)
    end
  end
  
  Debug.log("Found %d lines in objectives section", #objectives_lines)
  return TaskParser.parse_task_tree(objectives_lines, 1, #objectives_lines, 0)
end

-- Update objectives section in project file content
function ProjectFile.update_objectives(content, new_objectives)
  local lines = Utils.split_lines(content)
  local result = {}
  local in_objectives = false
  local objectives_written = false
  
  for i, line in ipairs(lines) do
    if line:match("^## Objectives") then
      in_objectives = true
      table.insert(result, line)
      
      -- Insert new objectives
      local obj_lines = TaskParser.tree_to_lines(new_objectives, 0)
      for _, obj_line in ipairs(obj_lines) do
        table.insert(result, obj_line)
      end
      objectives_written = true
    elseif in_objectives then
      -- Skip old objectives until next section
      if line:match("^## ") then
        in_objectives = false
        table.insert(result, line)
      end
      -- Skip lines in old objectives section
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

-- Normalize task text for comparison (strip emoji, normalize spaces)
function TaskSync.normalize_for_comparison(text)
  local normalized = Utils.strip_emoji_counters(text)
  -- Also remove project links for comparison
  normalized = normalized:gsub("%[%[[^%]]+%]%]", "")
  return Utils.trim(normalized)
end

-- Find matching task in list by normalized text
function TaskSync.find_matching_task(target_text, task_list)
  local normalized_target = TaskSync.normalize_for_comparison(target_text)
  
  for i, task in ipairs(task_list) do
    local normalized = TaskSync.normalize_for_comparison(task.text or "")
    if normalized == normalized_target then
      return i, task
    end
  end
  
  return nil, nil
end

-- Merge two task trees (combines children from both sources)
function TaskSync.merge_task_trees(daily_tasks, project_tasks)
  Debug.log("Merging task trees: %d daily tasks, %d project tasks", 
    #daily_tasks, #project_tasks)
  
  local merged = {}
  local processed_project_indices = {}
  
  -- First, process all daily tasks
  for _, daily_task in ipairs(daily_tasks) do
    local proj_idx, proj_task = TaskSync.find_matching_task(daily_task.text, project_tasks)
    
    if proj_task then
      -- Found matching task in project, merge children
      Debug.log("Matching task found: '%s'", daily_task.text)
      processed_project_indices[proj_idx] = true
      
      local merged_task = Utils.deep_copy(daily_task)
      
      -- Merge children recursively
      if #daily_task.children > 0 or (proj_task.children and #proj_task.children > 0) then
        merged_task.children = TaskSync.merge_task_trees(
          daily_task.children or {},
          proj_task.children or {}
        )
      end
      
      table.insert(merged, merged_task)
    else
      -- No match in project, keep daily task as-is
      table.insert(merged, Utils.deep_copy(daily_task))
    end
  end
  
  -- Then, add any project tasks that weren't in daily
  for i, proj_task in ipairs(project_tasks) do
    if not processed_project_indices[i] then
      Debug.log("Adding project-only task: '%s'", proj_task.text)
      table.insert(merged, Utils.deep_copy(proj_task))
    end
  end
  
  Debug.log("Merged result: %d tasks", #merged)
  return merged
end

-- Synchronize a linked work task with its project file
function TaskSync.sync_with_project(daily_task, project_name, existing_emoji_count)
  Debug.log("Syncing task with project '%s'", project_name)
  
  local project_path = ProjectFile.get_path(project_name)
  local project_content = Utils.read_file(project_path)
  
  if not project_content then
    Debug.log("Project file not found: %s", project_path)
    return daily_task, nil
  end
  
  -- Parse project objectives
  local project_objectives = ProjectFile.parse_objectives(project_content)
  Debug.log_task_tree("Project objectives", project_objectives)
  
  -- Find matching objective in project
  local daily_normalized = TaskSync.normalize_for_comparison(daily_task.text)
  local matched_objective = nil
  local matched_idx = nil
  
  for i, obj in ipairs(project_objectives) do
    if TaskSync.normalize_for_comparison(obj.text) == daily_normalized then
      matched_objective = obj
      matched_idx = i
      Debug.log("Found matching objective at index %d", i)
      break
    end
  end
  
  if not matched_objective then
    Debug.log("No matching objective found in project")
    return daily_task, project_content
  end
  
  -- Merge the task trees
  local merged_children = TaskSync.merge_task_trees(
    daily_task.children or {},
    matched_objective.children or {}
  )
  
  -- Create merged task for daily note (preserve emoji)
  local merged_daily = Utils.deep_copy(daily_task)
  merged_daily.children = merged_children
  -- Restore emoji count
  if existing_emoji_count and existing_emoji_count > 0 then
    merged_daily.text = Utils.add_emoji_counter(
      Utils.strip_emoji_counters(merged_daily.text),
      existing_emoji_count
    )
    merged_daily.emoji_count = existing_emoji_count
  end
  
  -- Create merged task for project (strip emoji)
  local merged_project = Utils.deep_copy(matched_objective)
  merged_project.children = TaskSync.strip_emoji_from_tree(merged_children)
  
  -- Update project objectives
  project_objectives[matched_idx] = merged_project
  local updated_project_content = ProjectFile.update_objectives(project_content, project_objectives)
  
  Debug.log_task_tree("Merged daily task", {merged_daily})
  
  return merged_daily, updated_project_content
end

-- Strip emoji counters from entire task tree (for project file)
function TaskSync.strip_emoji_from_tree(tasks)
  local result = {}
  
  for _, task in ipairs(tasks) do
    local stripped = Utils.deep_copy(task)
    stripped.text = Utils.strip_emoji_counters(task.text or "")
    stripped.emoji_count = 0
    
    if task.children and #task.children > 0 then
      stripped.children = TaskSync.strip_emoji_from_tree(task.children)
    end
    
    table.insert(result, stripped)
  end
  
  return result
end

-- Import objectives from all project files referenced in Work Objectives
function TaskSync.import_missing_project_objectives(work_objectives, existing_work_todos)
  Debug.log("Checking for missing project objectives to import")
  local new_todos = {}
  
  for _, objective in ipairs(work_objectives) do
    local project_name = Utils.extract_project_link(objective.text)
    
    if project_name then
      Debug.log("Checking project: %s", project_name)
      
      -- Check if we already have todos for this project
      local has_todos = false
      for _, todo in ipairs(existing_work_todos) do
        local todo_project = Utils.extract_project_link(todo.text or "")
        if todo_project == project_name then
          has_todos = true
          break
        end
      end
      
      if not has_todos then
        Debug.log("No existing todos for %s, importing from project file", project_name)
        
        local project_path = ProjectFile.get_path(project_name)
        local project_content = Utils.read_file(project_path)
        
        if project_content then
          local project_objectives = ProjectFile.parse_objectives(project_content)
          
          for _, proj_obj in ipairs(project_objectives) do
            -- Add project link to the objective text if not present
            local obj_copy = Utils.deep_copy(proj_obj)
            if not Utils.extract_project_link(obj_copy.text) then
              obj_copy.text = obj_copy.text .. " [[" .. project_name .. "]]"
            end
            table.insert(new_todos, obj_copy)
          end
        end
      end
    end
  end
  
  Debug.log("Found %d new project objectives to import", #new_todos)
  return new_todos
end

-- ============================================================================
-- MAIN WORKFLOW
-- ============================================================================

Debug.log("=== Starting Daily Note Creation ===")

local today = Utils.get_today_date()
local yesterday = Utils.get_yesterday_date()

Debug.log("Today: %s, Yesterday: %s", today, yesterday)

-- Paths
local today_path = Utils.build_path(Config.daily_folder, today .. ".md")
local yesterday_path = Utils.build_path(Config.daily_folder, yesterday .. ".md")

Debug.log("Today path: %s", today_path)
Debug.log("Yesterday path: %s", yesterday_path)

-- Check if today's note already exists
if Utils.file_exists(today_path) then
  Debug.log("Today's note already exists, opening it")
  vim.cmd("edit " .. today_path)
  return
end

-- Start with template
local today_content = DailyNote.generate_template(today)
local today_sections = DailyNote.parse_sections(today_content)

-- Try to load yesterday's note
local yesterday_content = Utils.read_file(yesterday_path)

if yesterday_content then
  Debug.log("Processing yesterday's note")
  local yesterday_sections = DailyNote.parse_sections(yesterday_content)
  
  -- ========================================================================
  -- STEP 1: Import Work Objectives (as-is)
  -- ========================================================================
  if yesterday_sections.work_objectives then
    today_sections.work_objectives = Utils.deep_copy(yesterday_sections.work_objectives)
    Debug.log("Imported work objectives")
  end
  
  -- ========================================================================
  -- STEP 2: Process Work Todos
  -- ========================================================================
  local work_todos = {}
  local project_updates = {}  -- {project_name = updated_content}
  
  if yesterday_sections.work_todos then
    local yesterday_todos = DailyNote.extract_tasks_from_section(yesterday_sections.work_todos)
    Debug.log_task_tree("Yesterday work todos", yesterday_todos)
    
    for _, todo in ipairs(yesterday_todos) do
      local project_name = Utils.extract_project_link(todo.text)
      
      if project_name then
        -- This is a linked project task - sync with project file
        Debug.log("Processing linked task for project: %s", project_name)
        
        local synced_task, updated_project = TaskSync.sync_with_project(
          todo, project_name, todo.emoji_count
        )
        
        -- Add emoji to undone subtasks (cumulative like personal todos)
        TaskParser.add_emoji_to_undone(synced_task.children or {}, 1)
        
        table.insert(work_todos, synced_task)
        
        if updated_project then
          project_updates[project_name] = updated_project
        end
      else
        -- Independent task - filter undone and add emoji
        if TaskParser.is_undone_task(todo.raw_line) then
          local task_copy = Utils.deep_copy(todo)
          -- Add emoji to undone tasks
          task_copy.emoji_count = (task_copy.emoji_count or 0) + 1
          task_copy.text = Utils.add_emoji_counter(
            Utils.strip_emoji_counters(task_copy.text),
            task_copy.emoji_count
          )
          -- Also add emoji to undone children
          TaskParser.add_emoji_to_undone(task_copy.children or {}, 1)
          table.insert(work_todos, task_copy)
        end
      end
    end
  end
  
  -- Import missing project objectives (from Work Objectives)
  local work_objectives = DailyNote.extract_tasks_from_section(
    today_sections.work_objectives or {}
  )
  local new_project_todos = TaskSync.import_missing_project_objectives(
    work_objectives, work_todos
  )
  
  for _, new_todo in ipairs(new_project_todos) do
    table.insert(work_todos, new_todo)
  end
  
  Debug.log_task_tree("Final work todos", work_todos)
  
  -- Build work todos section
  today_sections.work_todos = DailyNote.build_section(
    Config.sections.work_todos,
    work_todos
  )
  
  -- ========================================================================
  -- STEP 3: Process Personal Todos
  -- ========================================================================
  if yesterday_sections.personal_todos then
    local yesterday_personal = DailyNote.extract_tasks_from_section(
      yesterday_sections.personal_todos
    )
    Debug.log_task_tree("Yesterday personal todos", yesterday_personal)
    
    -- Filter undone tasks
    local undone_personal = TaskParser.filter_undone(yesterday_personal)
    
    -- Add emoji to all undone tasks (including nested)
    TaskParser.add_emoji_to_undone(undone_personal, 1)
    
    Debug.log_task_tree("Processed personal todos", undone_personal)
    
    today_sections.personal_todos = DailyNote.build_section(
      Config.sections.personal_todos,
      undone_personal
    )
  end
  
  -- ========================================================================
  -- STEP 4: Import other sections (as-is, with undone tasks)
  -- ========================================================================
  -- New info and Scratch notes are imported but not processed
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

-- Ensure directory exists
local daily_dir = Utils.build_path(Config.daily_folder)
vim.fn.mkdir(daily_dir, "p")

-- Write file
Utils.write_file(today_path, final_content)

-- Open the file
vim.cmd("edit " .. today_path)

Debug.log("=== Daily Note Creation Complete ===")
vim.notify("Daily note created: " .. today, vim.log.levels.INFO)
