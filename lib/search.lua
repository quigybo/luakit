--------------------------------------------------------
-- Search for a string in the current webview         --
-- (C) 2010 Mason Larobina <mason.larobina@gmail.com> --
--------------------------------------------------------

-- Add searching binds to normal mode
local key = lousy.bind.key
add_binds("normal", {
    key({}, "/", function (w) w:start_search("/") end),
    key({}, "?", function (w) w:start_search("?") end),

    key({}, "n", function (w, m)
        for i=1,m.count do w:search(nil, true)  end
        if w.search_state.ret == false then
            w:error("Pattern not found: " .. w.search_state.last_search)
        end
    end, {count=1}),

    key({}, "N", function (w, m)
        for i=1,m.count do w:search(nil, false) end
        if w.search_state.ret == false then
            w:error("Pattern not found: " .. w.search_state.last_search)
        end
    end, {count=1}),
})

-- Setup search mode
new_mode("search", {
    enter = function (w)
        -- Clear old search state
        w.search_state = {}
        w:set_prompt()
        w:set_input("/")
    end,

    leave = function (w)
        -- Check if search was aborted and return to original position
        local s = w.search_state
        if s.marker then
            w:get_current():set_scroll_vert(s.marker)
            s.marker = nil
        end
    end,

    changed = function (w, text)
        -- Check that the first character is '/' or '?' and update search
        if string.match(text, "^[\?\/]") then
            s = w.search_state
            s.last_search = string.sub(text, 2)
            if #text > 3 then
                w:search(string.sub(text, 2), (string.sub(text, 1, 1) == "/"))
                if s.ret == false and s.marker then w:get_current():set_scroll_vert(s.marker) end
            else
                w:clear_search(false)
            end
        else
            w:clear_search()
            w:set_mode()
        end
    end,

    activate = function (w, text)
        w.search_state.marker = nil
        -- Search if haven't already (won't have for short strings)
        if not w.search_state.searched then
            w:search(string.sub(text, 2), (string.sub(text, 1, 1) == "/"))
        end
        -- Ghost the last search term
        if w.search_state.ret then
            w:set_mode()
            w:set_prompt(text)
        else
            w:error("Pattern not found: " .. string.sub(text, 2))
        end
    end,

    history = {maxlen = 50},
})

-- Add binds to search mode
add_binds("search", {
    key({"Control"}, "j",       function (w) w:search(w.search_state.last_search, true)  end),
    key({"Control"}, "k",       function (w) w:search(w.search_state.last_search, false) end),
})

-- Add search functions to webview
for k, m in pairs({
    start_search = function (view, w, text)
        if string.match(text, "^[?/]") then
            w:set_mode("search")
            w:set_input(text)
        else
            return error("invalid search term, must start with '?' or '/'")
        end
    end,

    search = function (view, w, text, forward)
        if forward == nil then forward = true end

        -- Get search state (or new state)
        if not w.search_state then w.search_state = {} end
        local s = w.search_state

        -- Get search term
        text = text or s.last_search
        if not text or #text == 0 then
            return w:clear_search()
        end
        s.last_search = text

        if s.forward == nil then
            -- Haven't searched before, save some state.
            s.forward = forward
            s.marker = view:get_scroll_vert()
        else
            -- Invert direction if originally searching in reverse
            forward = (s.forward == forward)
        end

        s.searched = true
        s.ret = view:search(text, text ~= string.lower(text), forward, true);
    end,

    clear_search = function (view, w, clear_state)
        view:clear_search()
        if clear_state ~= false then
            w.search_state = {}
        else
            w.search_state.searched = false
        end
    end,

}) do webview.methods[k] = m end
