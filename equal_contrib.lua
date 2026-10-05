local bib_file = "publications.bib"

-- citation key -> set of equal-contribution names
local equal_contrib = {}


local function trim(s)
  return s:match("^%s*(.-)%s*$")
end


-- Convert BibTeX "Ying, Andrew" -> rendered "Andrew Ying"
local function normalize_name(name)
  name = trim(name)

  local family, given = name:match("^([^,]+),%s*(.+)$")

  if family and given then
    return trim(given) .. " " .. trim(family)
  end

  return name
end


local function load_equal_contrib()
  local file = assert(io.open(bib_file, "r"))
  local bib = file:read("*all")
  file:close()

  -- Find entry key and equalcontrib field.
  for key, body in bib:gmatch("@[%w%-]+%s*{%s*([^,]+),%s*(.-)\n}") do
    local field = body:match(
      "[Ee][Qq][Uu][Aa][Ll][Cc][Oo][Nn][Tt][Rr][Ii][Bb]%s*=%s*{(.-)}"
    )

    if field then
      equal_contrib[trim(key)] = {}

      -- Split names on BibTeX's "and".
      for name in (field .. " and "):gmatch("(.-)%s+and%s+") do
        name = normalize_name(name)
        equal_contrib[trim(key)][name] = true
      end
    end
  end
end


local function star()
  return pandoc.Superscript {
    pandoc.Str("*")
  }
end


function Pandoc(doc)
  load_equal_contrib()

  doc = doc:walk {
    Div = function(el)
      if not el.classes:includes("csl-entry") then
        return el
      end

      local key = el.identifier:gsub("^ref%-", "")

      if not key or not equal_contrib[key] then
        return el
      end

      local starred = equal_contrib[key]

      el.content = el.content:walk {
        Inlines = function(inlines)
          local result = {}
          local group = {}

          local function flush()
            if #group == 0 then
              return
            end

            local name = trim(pandoc.utils.stringify(group))

            -- Preserve the existing content. This includes the
            -- Strong produced by bold-name.lua.
            for _, item in ipairs(group) do
              table.insert(result, item)
            end

            if starred[name] then
              table.insert(result, star())
            end

            group = {}
          end

          for _, item in ipairs(inlines) do
            -- Your current CSL separates authors with commas.
            if item.t == "Str" and item.text:sub(-1) == "," then
              local word = item.text:sub(1, -2)

              if word ~= "" then
                table.insert(group, pandoc.Str(word))
              end

              flush()
              table.insert(result, pandoc.Str(","))
            else
              table.insert(group, item)
            end
          end

          flush()
          return result
        end
      }

      return el
    end
  }

  return doc
end