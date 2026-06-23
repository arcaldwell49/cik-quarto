local function stringify(value)
  if value == nil then
    return nil
  end
  return pandoc.utils.stringify(value)
end

local function trim(value)
  if value == nil then
    return nil
  end
  return value:match("^%s*(.-)%s*$")
end

local function sentence_period(value)
  value = trim(value)
  if value == nil or value == "" then
    return ""
  end
  if value:match("[%.%?%!:]$") then
    return value
  end
  return value .. "."
end

local function initial(name)
  if name == nil or name == "" then
    return nil
  end
  return name:sub(1, 1):upper() .. "."
end

local function format_author_name(name)
  name = trim(name)
  if name == nil or name == "" then
    return nil
  end

  local particles = {
    da = true,
    de = true,
    del = true,
    der = true,
    di = true,
    du = true,
    la = true,
    le = true,
    van = true,
    von = true
  }

  local parts = {}
  for part in name:gmatch("%S+") do
    table.insert(parts, part)
  end

  if #parts == 1 then
    return parts[1]
  end

  local family_start = #parts
  while family_start > 1 and particles[parts[family_start - 1]:lower()] do
    family_start = family_start - 1
  end

  local family = table.concat(parts, " ", family_start)
  local initials = {}
  for i = 1, family_start - 1 do
    local value = initial(parts[i])
    if value then
      table.insert(initials, value)
    end
  end

  if #initials == 0 then
    return family
  end

  return family .. ", " .. table.concat(initials, " ")
end

local function format_author(author)
  if author == nil then
    return nil
  end

  if author.t == "MetaMap" or type(author) == "table" then
    if author.family then
      local family = stringify(author.family)
      local given = stringify(author.given)
      if given and given ~= "" then
        local initials = {}
        for part in given:gmatch("%S+") do
          table.insert(initials, initial(part))
        end
        return family .. ", " .. table.concat(initials, " ")
      end
      return family
    end

    if author.name then
      return format_author_name(stringify(author.name))
    end
  end

  return format_author_name(stringify(author))
end

local function join_authors(authors)
  if #authors == 0 then
    return nil
  end
  if #authors == 1 then
    return authors[1]
  end
  if #authors == 2 then
    return authors[1] .. ", & " .. authors[2]
  end

  local result = {}
  for i = 1, #authors do
    if i == #authors then
      table.insert(result, "& " .. authors[i])
    else
      table.insert(result, authors[i])
    end
  end

  return table.concat(result, ", ")
end

local function author_list(meta)
  local result = {}
  local authors = meta.author

  if authors == nil then
    return result
  end

  if authors.t == "MetaList" or type(authors) == "table" then
    for _, author in ipairs(authors) do
      local formatted = format_author(author)
      if formatted and formatted ~= "" then
        table.insert(result, formatted)
      end
    end
  else
    local formatted = format_author(authors)
    if formatted and formatted ~= "" then
      table.insert(result, formatted)
    end
  end

  return result
end

local function citation_year(meta)
  local date = stringify(meta.date)

  if date == nil or date == "" then
    return "n.d."
  end

  if date:match("Sys%.Date") then
    return os.date("%Y")
  end

  local year = date:match("(%d%d%d%d)")
  if year then
    return year
  end

  return "n.d."
end

local function doi_url(meta)
  local doi = stringify(meta.doi)
  doi = trim(doi)

  if doi == nil or doi == "" then
    return nil
  end

  doi = doi:gsub("^https?://dx%.doi%.org/", "")
  doi = doi:gsub("^https?://doi%.org/", "")

  return "https://doi.org/" .. doi
end

local function build_cite_as(meta)
  if meta["cite-as"] then
    return meta
  end

  local authors = join_authors(author_list(meta))
  local year = citation_year(meta)
  local title = sentence_period(stringify(meta.title))
  local journal = stringify(meta["journal-title"]) or "Communications in Kinesiology"
  local doi = doi_url(meta)

  local pieces = {}
  if authors then
    table.insert(pieces, authors)
  end
  table.insert(pieces, "(" .. year .. ").")
  if title ~= "" then
    table.insert(pieces, title)
  end
  if journal and journal ~= "" then
    table.insert(pieces, sentence_period(journal))
  end
  if doi then
    table.insert(pieces, doi)
  end

  meta["cite-as"] = pandoc.MetaInlines(pandoc.Str(table.concat(pieces, " ")))
  return meta
end

return {
  {
    Meta = build_cite_as
  }
}
