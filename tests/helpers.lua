local M = {}

---Assert two values are equal, with a readable message on failure.
function M.eq(actual, expected, msg)
  if actual ~= expected then
    error(
      string.format(
        "%sexpected %s, got %s",
        msg and (msg .. ": ") or "",
        vim.inspect(expected),
        vim.inspect(actual)
      ),
      2
    )
  end
end

---Assert two tables are equal by deep comparison.
function M.same(actual, expected, msg)
  if not vim.deep_equal(actual, expected) then
    error(
      string.format(
        "%sexpected %s, got %s",
        msg and (msg .. ": ") or "",
        vim.inspect(expected),
        vim.inspect(actual)
      ),
      2
    )
  end
end

---Assert a value is truthy.
function M.ok(value, msg)
  if not value then
    error(msg or "expected a truthy value", 2)
  end
end

---Assert a value is falsy.
function M.falsy(value, msg)
  if value then
    error(
      string.format(
        "%sexpected falsy, got %s",
        msg and (msg .. ": ") or "",
        vim.inspect(value)
      ),
      2
    )
  end
end

---Create a temp directory that is removed when the test run ends.
function M.tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

---Write `content` to `path`, creating parent directories as needed.
function M.write(path, content)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local fd = assert(vim.uv.fs_open(path, "w", 420))
  assert(vim.uv.fs_write(fd, content))
  assert(vim.uv.fs_close(fd))
end

---Set a file's mtime to `seconds` (an absolute unix timestamp).
function M.set_mtime(path, seconds)
  assert(vim.uv.fs_utime(path, seconds, seconds))
end

return M
