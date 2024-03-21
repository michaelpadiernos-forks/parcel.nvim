local M = {
  dependency_file_pattern = "composer.json",
}

M.get_outdated_packages = function(file_path)
  local cache = "/tmp/outdated-packages" .. file_path:gsub("/", "-")
  local exists = vim.loop.fs_stat(cache)
  if exists then
    local content = vim.fn.readfile(cache)
    if next(content) ~= nil then
      return vim.fn.json_decode(content)
    end
  end

  vim.fn.jobstart("composer outdated --locked --format=json > " .. cache, {
    cwd = file_path:match("(.*/)"),
    on_exit = function()
      print("Fetched outdated composer packages.")
    end,
  })
end

M.get_package_list = function(file_path)
  local cache = "/tmp/packages" .. file_path:gsub("/", "-")
  local exists = vim.loop.fs_stat(cache)
  if exists then
    local content = vim.fn.readfile(cache)
    if next(content) ~= nil then
      return vim.fn.json_decode(content)
    end
  end

  vim.fn.jobstart("composer show -i --format=json > " .. cache, {
    cwd = file_path:match("(.*/)"),
    on_exit = function()
      print("Fetched composer package versions.")
    end,
  })
end

M.show_current_version = function()
  local installed = M.get_package_list(vim.api.nvim_buf_get_name(0))
  if not installed or not installed.installed then
    return
  end

  local package_info = {}
  for _, item in ipairs(installed.installed) do
    if item.name ~= nil then
      package_info[item.name] = item
    end
  end

  local namespace = vim.api.nvim_create_namespace("composer-current-version")
  vim.api.nvim_buf_clear_namespace(0, namespace, 1, -1)

  for line_number, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, true)) do
    vim.api.nvim_win_set_cursor(0, { line_number, #line - 1 })
    local path = require("jsonpath").get()
    if path:find("^%.require") ~= nil or path:find('^%.%["require-dev') ~= nil then
      local package_name = line:match('"([^"]+)"')
      local info = package_info[package_name]
      if info ~= nil then
        local text = { { "installed: " .. info.version, "Comment" } }

        vim.api.nvim_buf_set_extmark(0, namespace, line_number - 1, 0, {
          virt_text = text,
        })
      end
    end
  end
end

M.show_new_version = function()
  local outdated = M.get_outdated_packages(vim.api.nvim_buf_get_name(0))
  if not outdated then
    return
  end

  local package_info = {}
  for _, item in ipairs(outdated.locked) do
    if item.name ~= nil then
      package_info[item.name] = item
    end
  end

  local namespace = vim.api.nvim_create_namespace("composer-new-version")
  vim.api.nvim_buf_clear_namespace(0, namespace, 1, -1)

  for line_number, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, true)) do
    vim.api.nvim_win_set_cursor(0, { line_number, #line - 1 })
    local path = require("jsonpath").get()
    if path:find("^%.require") ~= nil or path:find('^%.%["require-dev') ~= nil then
      local package_name = line:match('"([^"]+)"')
      local info = package_info[package_name]
      if info ~= nil then
        local text = {}
        if info["latest-status"] == "update-possible" then
          text = { { "| major: ", "Comment" }, { info.latest, "errorMsg" } }
        elseif info["latest-status"] == "semver-safe-update" then
          text = { { "| minor: ", "Comment" }, { info.latest, "warningMsg" } }
        end

        if text then
          vim.api.nvim_buf_set_extmark(0, namespace, line_number - 1, 0, {
            virt_text = text,
          })
        end
      end
    end
  end
end

return M
