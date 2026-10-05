local valid_names = {
  ["A. Ying"] = true,
  ["Andrew Ying"] = true,
}

function Pandoc(doc)
  doc = pandoc.utils.citeproc(doc)

  doc = doc:walk {
    Div = function(el)
      if not el.classes:includes("csl-entry") then
        return el
      end

      el.content = el.content:walk {
        Inlines = function(inlines)
          local result = {}
          local group = {}

          -- Process everything accumulated since the last comma
          local function flush()
            if #group == 0 then
              return
            end

            local text = pandoc.utils.stringify(group)

            -- Remove leading/trailing whitespace
            text = text:match("^%s*(.-)%s*$")

            if valid_names[text] then
              table.insert(result, pandoc.Strong(group))
            else
              for _, inline in ipairs(group) do
                table.insert(result, inline)
              end
            end

            group = {}
          end

          for _, inline in ipairs(inlines) do
            -- IEEE CSL usually attaches the comma to the Str:
            -- e.g. Str("Ying,")
            if inline.t == "Str" and inline.text:sub(-1) == "," then
              -- Remove comma temporarily
              local word = inline.text:sub(1, -2)

              if word ~= "" then
                table.insert(group, pandoc.Str(word))
              end

              flush()

              -- Put comma back outside the bold
              table.insert(result, pandoc.Str(","))
            else
              table.insert(group, inline)
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