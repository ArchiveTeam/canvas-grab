local url_count = 0
local item_type = os.getenv("item_type")
local item_data = os.getenv("item_data")
local item_dir = assert(os.getenv("item_dir"))

read_file = function(file)
  if file then
    local f = io.open(file)
    local data = f:read("*all")
    f:close()
    return data or ""
  else
    return ""
  end
end


function trim5(s)
  return s:match'^%s*(.*%S)' or ''
end


wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  -- canvas strips the leading slash so we can't use --no-parent effectively
  if string.match(urlpos['url']['url'], "canv%.as") then
    if verdict and urlpos["link_inline_p"] == 1 then
      verdict = true
    elseif verdict and item_type == 'drawing'
    and string.match(urlpos['url']['url'], "/p/([a-zA-Z0-9]+)")  == item_data then
      verdict = true
    elseif verdict and item_type == 'profile'
    and string.match(urlpos['url']['url'], "/user/([a-zA-Z0-9]+)")  == item_data then
      verdict = true
    else
      verdict = false
    end
  end

  return verdict
end


wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. url["url"] .. ".  \r")
  io.stdout:flush()

  local status_code = http_stat["statcode"]

  if status_code >= 500 then
    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 60")
    return wget.actions.CONTINUE
  end

  -- We're okay; sleep a bit (if we have to) and continue
  local sleep_time = 0.1 * (math.random(75, 125) / 100.0)

  if string.match(url["host"], "canvasugc")
  or string.match(url["host"], "amazonaws") then
    -- We should be able to go fast on images since that's what a web browser does
    sleep_time = 0
  end

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}

  if string.match(url, "/p/") then
    local html_source = read_file(file)

    -- grab the processed images
    for url in string.gmatch(html_source, 'data-original="(https://[^"]+)"') do
      table.insert(urls, {
        url=url
      })
    end
  end

  return urls
end
