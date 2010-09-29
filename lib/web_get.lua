-------------------------------------------------------------
-- Download files using LuaSocket                          --
-- (C) 2010 Chris van Dijk (quigybo) <quigybo@hotmail.com> --
-------------------------------------------------------------

-- Prepare local environment
local http  = require("socket.http")
local url   = require("socket.url")
local ltn12 = require("ltn12")
local proxy = globals.http_proxy or os.getenv("http_proxy")


-- Returns header with information on file
get_file_header = function (u)
    local r, c, h = http.request{url = u, method = "HEAD", proxy = proxy}
    if c == 200 then return h else return r, c end
end

-- Choose local filepath based on url
parse_filename = function(u, filename)
    if not filename then
        -- Just take the last part of the url path
        local path = url.parse(u).path
        local path_parts = url.parse_path(path)
        local filename = path_parts[#path_parts]
    end

    -- Make download dir
    os.execute(string.format("mkdir -p %q", globals.download_dir))

    return globals.download_dir .. "/" .. filename
end

-- LTN12 filter to track the progress of the downloaded file
progress_filter = function (size)
    local total = 0
    return function (chunk)
        if chunk == nil then return nil end
        if chunk == "" then return "" end
        total = total + #chunk
        -- For now just print progress, eventually do something more useful
        print(string.format("Current: %s, total: %s, progress: %.f%%", #chunk, total, total / size * 100))
        return chunk
    end
end

http_get_file = function(w, u, filepath)
    print("-- Getting header info...")
    local h, e = get_file_header(u)
    if not h then w:error("Download error: " .. e) return end
    local size = tonumber(h["content-length"])

    -- Print some info that could be useful...
    print("Source: "   .. u)
    print("Target: "   .. filepath)
    print("Filesize: " .. size)
    print("Mimetype: " .. h["content-type"])

    -- Set up filter and sink for dowloading
    local filesink = ltn12.sink.file(io.open(filepath, "wb"))
    local sink = ltn12.sink.chain(progress_filter(size), filesink)

    -- Download the file
    print("-- Downloading file...")
    local r, e = http.request{
        url = u,
        sink = sink,
        proxy = proxy,
    }
    if not r then w:error("Download error: " .. e) return end
    w:notify("Download complete: " .. filepath)

    print("-- Finished!")
end

-- Override w:download() webview method
webview.methods.download = function (view, w, u, filename)
    local filepath = parse_filename(u, filename)
    local scheme = url.parse(u).scheme
    if scheme == "http" then
        http_get_file(w, u, filepath)
    elseif scheme == "ftp" then
        -- implement me!
    else
        w:error("Unknown scheme: " .. scheme)
    end
end

-- vim: et:sw=4:ts=8:sts=4:tw=80
