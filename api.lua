pos.require("net.rttp")

local api = {
    url = {
        proto = 'rttp',
        domain = '',
        path = '',
    },
    history = {},
    log = pos.Logger('rBrowser.log'),
    urlBarElement = nil, ---@type TextInput
    pageElement = nil, ---@type ScrollField
    bookmarkButton = nil, ---@type Button
    bookmarkWindow = nil, ---@type Window
    bookmarkWindowInput = nil, ---@type TextInput
    refreshButton = nil, ---@type Button
    _cookies = {}, ---@type {str: str}
}

function api.addToHistory()
    local last = {
        proto = api.url.proto,
        domain = api.url.domain,
        path = api.url.path
    }
    table.insert(api.history, last)
end

---Sets the url bar TextInput elements
---@param urlBar TextInput
function api.setUrlBarElement(urlBar)
    api.urlBarElement = urlBar
end

function api.setPageElement(page)
    api.pageElement = page
end

function api.setPath(path, secure)
    api.addToHistory()
    if not path:start('/') then
        path = '/' .. path
    end
    api.url.path = path
    if api.urlBarElement then
        api.urlBarElement:setText(api.getUrl(true))
        api.setSecure(secure)
    end
    api.refresh()
end

function api.setSecure(secure)
    if not api.urlBarElement then
        return
    end

    if secure then
        api.urlBarElement.fg = colors.yellow
    else
        api.urlBarElement.fg = colors.white
    end
end

function api.appendPath(path)
    if path:start('/') then
        api.setPath(path)
    else
        api.setPath(fs.combine(api.url.path, path))
    end
end

function api.goHome()
    api.pageElement:clearElements()
    api.urlBarElement:setText('')
    api.url.proto, api.url.domain, api.url.path = '', '', ''
    api.bookmarkButton.fg = colors.lightGray

    local y = 3
    api.pageElement:addElement(pos.gui.TextBox(1,2,nil,nil,'Bookmarks:'))
    for url,name in pairs(api.bookmarks) do
        local btn = pos.gui.Button(1,y,#name,1,colors.gray,colors.lightBlue,name,function()
            api.setUrl(url)
        end)
        api.pageElement:addElement(btn)
        y = y + 1
    end
end

function api.setUrl(url)
    if (url == '') then
        api.goHome()
        return
    end
    api.addToHistory()
    api.url.proto, api.url.domain, api.url.path = net.splitUrl(url)
    if not api.url.proto then
        api.url.proto = 'rttp'
    end
    api.url.path = '/' .. api.url.path
    if api.urlBarElement then
        api.urlBarElement:setText(api.getUrl(true))
    end
    api.refresh()
end

function api.getUrl(hideRTTP, path)
    if hideRTTP and api.url.proto == 'rttp' then
        return api.url.domain .. api.url.path
    end
    if path then
        return api.url.proto .. '://' .. api.url.domain .. path
    end
    return api.url.proto .. '://' .. api.url.domain .. api.url.path
end

local pageElements = {} ---@type UiElement[]
local formElements = {} ---@type TextInput[]

function api.refresh()
    local dest = api.url.domain ---@type string|number
    local dIp = net.ipToNumber(dest)
    if dIp > 0 then
        dest = dIp
    end
    
    if api.urlBarElement then
        api.urlBarElement:setText(api.getUrl(true))
        api.setSecure(false)
    end
    if api.refreshButton then
        api.refreshButton.text = 'O'
    end
    pos.gui.redrawWindows()

    local rt = rttp.getSync(dest, api.url.path, api._cookies[dest])
    
    if api.refreshButton then
        api.refreshButton.text = '*'
    end
    
    api.bookmarkWindow:hide()
    if api.bookmarks[api.getUrl(true)] then
        api.bookmarkButton.fg = colors.green
        api.bookmarkWindowInput:setText(api.bookmarks[api.getUrl(true)])
    else
        api.bookmarkButton.fg = colors.lightGray
    end

    api.pageElement:clearElements()

    if type(rt) == "string" then
        api.log:error('Network error on GET:' .. api.getUrl() .. ' : ' .. rt)
        local text = pos.gui.TextBox(1, 1, nil, colors.red, 'Net Error: ' .. rt)
        api.pageElement:addElement(text)
        return
    end
    
    -- api.log:debug(textutils.serialiseJSON(rt.header))
    if rt.header.cookies then
        -- api.log:info('Storing cookies')
        if not api._cookies[dest] then
            api._cookies[dest] = {}
        end
        for name, cookie in pairs(rt.header.cookies) do
            -- api.log:debug('Storing cookie "' .. name .. '": "' .. cookie .. '"')
            api._cookies[dest][name] = cookie
        end
    end
    
    if rt.header.code == rttp.responseCodes.movedTemporarily or rt.header.code == rttp.responseCodes.movedPermanently then
        api.setPath(rt.header.redirect)
        return
    end
    if rt.header.code ~= rttp.responseCodes.okay then
        api.log:warn('Recived response ' .. rttp.codeName(rt.header.code))
        -- local text = pos.gui.TextBox(1, 1, nil, colors.red, 'Error: ' .. rt.body)
        -- api.pageElement:addElement(text)
        -- return
    end

    if rt.header.certificate then
        api.setSecure(true)
    else
        api.setSecure(false)
    end
    if rt.header.contentType == 'text/plain' then
        local text = pos.gui.TextBox(1, 1, nil, nil, rt.body)
        api.pageElement:addElement(text)
        return
    elseif rt.header.contentType == 'table/rtml' then
        local lInp = nil
        local nEls = {}
        pageElements = {}
        formElements = {}
        for i = 1, #rt.body do
            local rEl = rt.body[i] ---@type RTMLElement
            local gEl = nil
            local color = rEl.color
            if type(color) == 'string' then
                color = colors[color]
            end
            local bgColor = rEl.bgColor
            if type(bgColor) == 'string' then
                bgColor = colors[bgColor]
            end
            if rEl.type == "TEXT" then
                gEl = pos.gui.TextBox(rEl.x, rEl.y, bgColor or colors.black, color or colors.white, rEl.text)
            elseif rEl.type == "LINK" then
                gEl = pos.gui.Button(rEl.x, rEl.y, string.len(rEl.text), 1, bgColor or colors.gray, color or colors.lightBlue, rEl.text,
                    function()
                        api.appendPath(rEl.href)
                    end)
            elseif rEl.type == "DOM-LINK" then
                gEl = pos.gui.Button(rEl.x, rEl.y, string.len(rEl.text), 1, bgColor or colors.gray, color or colors.lightBlue, rEl.text,
                    function()
                        api.setUrl(rEl.href)
                    end)
            elseif rEl.type == 'INPUT' then
                gEl = pos.gui.TextInput(rEl.x, rEl.y, rEl.len, bgColor or colors.gray, color or colors.white, function(text) end)
                gEl.name = rEl.name
                if rEl.hide then
                    gEl.hideText = true
                end
                if rEl.next then
                    table.insert(nEls, { fE = gEl, next = rEl.next })
                end
                if lInp then lInp.next = gEl end
                lInp = gEl
                formElements[rEl.name] = gEl
            elseif rEl.type == 'BUTTON' then
                gEl = pos.gui.Button(rEl.x, rEl.y, string.len(rEl.text), 1, bgColor or colors.green, color or colors.white, rEl.text,
                    function()
                        local msg
                        local path = api.url.path
                        if rEl.action == 'SUBMIT' then
                            local rsp = {
                                vals = {},
                                type = "BUTTON_SUBMIT",
                            }
                            for name, el in pairs(formElements) do
                                rsp.vals[name] = el.text
                            end

                            msg = rttp.postSync(dest, path, 'object/lua', rsp, api._cookies[dest])
                        elseif rEl.action == 'PUSH' then
                            local rsp = {
                                type = "BUTTON_PUSH",
                                id = rEl.id,
                            }
                            path = '/' .. fs.combine(path, rEl.href)

                            msg = rttp.postSync(dest, path, 'object/lua', rsp, api._cookies[dest])
                        else
                            api.log:warn('Unknown button action: ' .. rEl.action)
                            return
                        end
                        
                        if type(msg) ~= 'string' then
                            if msg.header.cookies then
                                -- api.log:info('Storing cookies')
                                if not api._cookies[dest] then
                                    api._cookies[dest] = {}
                                end
                                for name, cookie in pairs(msg.header.cookies) do
                                    -- api.log:debug('Storing cookie "' .. name .. '": "' .. cookie .. '"')
                                    api._cookies[dest][name] = cookie
                                end
                            end

                            api.log:debug("Button response code " .. msg.header.code)
                            if msg.header.code == rttp.responseCodes.movedTemporarily then
                                api.appendPath(msg.header.redirect)
                            elseif msg.header.code == rttp.responseCodes.okay then
                                if msg.header.contentType == "text/plain" then
                                    api.log:debug("Button Response: " .. msg.body)
                                end
                            else
                                if msg.header.contentType == "text/plain" then
                                    api.log:warn('Button error on POST:' .. api.getUrl(false,path) .. ' : ' .. msg.body)
                                else
                                    api.log:warn('Button error on POST:' .. api.getUrl(false,path))
                                end
                            end
                        else
                            api.log:warn("Network error on POST:" .. api.getUrl(false,path) .. " : " .. msg)
                        end
                    end)
            end
            if gEl then
                if rEl.id then
                    pageElements[rEl.id] = gEl
                end
                api.pageElement:addElement(gEl)
            end
        end
        for _, t in pairs(nEls) do
            if t.next then
                if formElements[t.next] then
                    t.fE.next = formElements[t.next]
                else
                    api.log:warn('Form element '..t.fE.name..' indecated element "'..t.next..'" as next, but it does not exist')
                end
            end
        end
        return
    end
end

function api.back()
    local last = table.remove(api.history, #api.history)
    api.url.domain = last.domain
    api.url.path = last.path
    api.url.proto = last.proto
    api.refresh()
end

api.bookmarks = {} ---@type table<string, string> Bookmark names indexed by URL
local bookmarkPath = '%appdata%/browser/bookmarks'
function api.loadBookmarks()
    if not fs.exists(bookmarkPath .. '.json') then
        if not fs.exists(bookmarkPath .. '.lua') then
            return
        end

        api.log:info('Translating LUA bookmark file to JSON')

        local f = fs.open(bookmarkPath .. '.lua', 'r')
        if not f then
            api.log:error('Could not open bookmark file')
            return
        end

        local bkms = textutils.unserialise(f.readAll())
        f.close()
        if not bkms then
            api.log:error('Bookmark file corrupted')
            return
        end
        api.bookmarks = {}
        for _,bkm in pairs(bkms) do
            api.bookmarks[bkm.href] = bkm.name
        end
        api.saveBookmarks()
        return
    end

    local f = fs.open(bookmarkPath .. '.json', 'r')
    if not f then
        api.log:error('Could not open bookmark file')
        return
    end
    local bkms = textutils.unserialiseJSON(f.readAll())
    f.close()
    if not bkms then
        api.log:error('Bookmark file corrupted')
        return
    end
    api.bookmarks = bkms
end

function api.saveBookmarks()
    local f = fs.open(bookmarkPath .. '.json', 'w')
    if not f then
        api.log:warn('Unable to save to bookmark file')
        return
    end
    f.write(textutils.serialiseJSON(api.bookmarks))
    f.close()
end

function api.bookmark()
    local url = api.getUrl(true)
    if api.bookmarks[url] then
        api.bookmarkWindow:show()
    else
        api.bookmarks[url] = url
        api.bookmarkButton.fg = colors.green
        api.bookmarkWindowInput:setText(url)
    end
    api.saveBookmarks()
end

api.gui = loadfile('gui.lua')(api)

api.loadBookmarks()
api.goHome()

return api
