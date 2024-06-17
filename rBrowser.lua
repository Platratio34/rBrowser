pos.require("net.rttp")
-- local Logger = pos.require('logger')
-- local log = Logger("/home/.pgmLog/browser.log")
local log = pos.Logger('browser.log')
log:setLevel(pos.LoggerLevel.INFO)
log:info('Starting rBrowser')
-- local client = rttps.client
local tblStore = pos.require("tblStore")

local bkmFileName = "%appdata/browser/bookmarks.lua"

local args = {...}

local links = {}
local inputs = {}
local buttons = {}
local w, h = term.getSize()
local url = ""
local back = {}
local editURL = false

local reqWait = false

-- local f = fs.open("/home/.pgmLog/browser.log", "w")
-- f.write("")
-- f.close()

-- local function log(msg)
--     local f = fs.open("/home/.pgmLog/browser.log", "a")
--     f.write(msg.."\n")
--     f.close()
-- end

local cursorBlink = true;
local cursorBlinkTime = 0.75;
local cursorBlinkTimer = os.startTimer(cursorBlinkTime);
local cursorX, cursorY, cursorActive = 1, 1, false

local function drawBar()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.gray)
    term.clearLine()

    term.setTextColor(colors.lightGray)
    if reqWait then
        term.write("< O|")
    else
        term.write("< *|")
    end

    term.setCursorPos(5, 1)
    term.setTextColor(colors.white)
    term.write(url)
    if editURL then
        cursorX, cursorY = term.getCursorPos()
        cursorActive = true
    end
    -- if(editURL and cursorBlink) then
    --     term.setCursorBlink(true)
    --     term.setTextColor(colors.lightGray)
    --     term.write("_")
    -- else
    --     term.setCursorBlink(false)
    -- end

    term.setCursorPos(w-4, 1)
    term.setTextColor(colors.lightGray)
    term.write("+ X")
    term.setCursorPos(w, 1)
    term.setTextColor(colors.red)
    term.write("X")

    term.setBackgroundColor(colors.black)

    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
end

local function drawInput(inp, act)
    if not inp then return end
    act = act or false
    paintutils.drawBox(inp.x, inp.y, inp.x + inp.w, inp.y, colors.gray)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(inp.x, inp.y)
    if inp.hide == true then
        local str = string.rep("*", string.len(inp.val))
        term.write(str)
    else
        term.write(inp.val)
    end
    if act then
        cursorX, cursorY = term.getCursorPos()
        cursorActive = true
    end
    -- if act and cursorBlink then
    --     term.setTextColor(colors.lightGray)
    --     term.write("_")
    -- end
end

---Disply an RTTP message
---@param msg RttpMessage
local function display(msg)
    log:debug('Drawing')
    term.setBackgroundColor(colors.black)
    term.clear()
    links = {}
    inputs = {}
    buttons = {}

    msg.header.contentType = msg.header.contentType or "text/plain"

    log:debug(msg.header.contentType)
    if msg.header.contentType == "table/rtml" then
        log:debug("Displaying rtml")
        local body = msg.body
        if body == nil then
            term.setCursorPos(1,2)
            term.setTextColor(colors.red)
            term.write("Body was nil")
            drawBar()
            return
        end
        log:debug("Body length "..#body)
        for i=1,#body do
            local el = body[i]

            if not el then

            elseif el.type == "TEXT" then
                term.setCursorPos(el.x, el.y+1)
                term.setBackgroundColor(colors.black)
                if not (el.color == nil) then
                    local color = el.color
                    if type(color) == 'string' then
                        color = colors[color]
                    end
                    term.setTextColor(color)
                else
                    term.setTextColor(colors.white)
                end
                term.write(el.text)
            elseif el.type == "LINK" or el.type == "DOM-LINK" then
                local lnk = {
                    x = el.x,
                    y = el.y+1,
                    w = string.len(el.text),
                    href = el.href,
                    type = el.type
                }
                table.insert(links, lnk)
                term.setCursorPos(el.x, el.y+1)
                term.setTextColor(colors.lightBlue)
                term.setBackgroundColor(colors.gray)
                term.write(el.text)
            elseif el.type == "INPUT" then
                local inp = {
                    x = el.x,
                    y = el.y+1,
                    w = el.len,
                    name = el.name,
                    val = "",
                    hide = el.hide,
                    i = #inputs + 1
                }
                table.insert(inputs, inp)
                drawInput(inp)
            elseif el.type == "BUTTON" then
                local btn = {
                    x = el.x,
                    y = el.y+1,
                    w = string.len(el.text),
                    action = el.action
                }
                table.insert(buttons, btn)
                term.setCursorPos(el.x, el.y+1)
                term.setTextColor(colors.white)
                term.setBackgroundColor(colors.green)
                term.write(el.text)
            else
                log:error("Invalid RTML object type: '"..el.type.."'")
            end
        end
    elseif msg.header.contentType == "text/plain" then
        local lines = {}
        local body = msg.body
        while string.len(body) > w do
            table.insert(lines, string.sub(body,1,w))
            body = string.sub(body, w+1, -1)
        end
        table.insert(lines, body)

        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)
        for i=1,#lines do
            term.setCursorPos(1,i+1)
            term.write(lines[i])
        end
    end

    drawBar()

    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)

    if cursorActive then
        term.setCursorPos(cursorX, cursorY)
        term.setCursorBlink(true)
        cursorActive = false
    else
        term.setCursorBlink(false)
    end
end

local function keyToChar(key)
    if string.len(keys.getName(key))==1 then
        return keys.getName(key)
    elseif key == keys.period then
        return "."
    elseif key == keys.slash then
        return "/"
    elseif key == keys.minus then
        return "-"
    elseif key == keys.underscore then
        return "_"
    elseif key == keys.one then
        return "1"
    elseif key == keys.two then
        return "2"
    elseif key == keys.three then
        return "3"
    elseif key == keys.four then
        return "4"
    elseif key == keys.five then
        return "5"
    elseif key == keys.six then
        return "6"
    elseif key == keys.seven then
        return "7"
    elseif key == keys.eight then
        return "8"
    elseif key == keys.nine then
        return "9"
    elseif key == keys.zero then
        return "0"
    elseif key == keys.space then
        return " "
    end
    return ""
end

net.setup()

if not fs.exists(bkmFileName) then
    if not fs.exists("%appdata") then fs.makeDir("%appdata") end
    if not fs.exists("%appdata/browser") then fs.makeDir("%appdata/browser") end
    local f = fs.open(bkmFileName, "w")
    if f then
        f.write("{}")
        f.close()
    else
        log:error('Could not write to bookmark file')
    end
end

local domain = ""
local path = ""
if #args == 1 then
    _, domain, path = net.splitUrl(args[1])
    path = '/'..path
elseif #args == 2 then
    domain = args[1]
    path = args[2]
else
    editURL = true
end

-- print("Seding request to "..domain.." "..path)
local homePage = pos.require("os.bin.rBrowser.rBrowser-home").home()
log:info('Starting main loop')
while true do
    ---@type RttpMessage|string
    local msg = homePage
    if not (domain == "") then
        reqWait = true
        drawBar()
        path = path or "/"
        if path == '' then
            path = '/'
        end
        -- if string.byte(domain, 1) >= 0x30 and string.byte(domain, 1) <= 0x39 then
        --     domain = net.
        -- end
        local ip = net.ipToNumber(domain)
        log:info('GET: '..domain..path)
        if ip >= 0 then
            msg = rttp.getSync(ip, path)
            log:info('GET: '..net.ipFormat(ip))
        else
            msg = rttp.getSync(domain, path)
        end
        reqWait = false
        table.insert(back, {domain, path})
    end

    if msg == nil then
        -- print("Somthing went wrong")
        -- return
        msg = {
            header={contentType="table/rtml"},
            body={
                {type="TEXT", x=(w-19)/2, y=h/2, text="Somthing Went Wrong", color=colors.red}
            }
        }
    end

    if msg == "timeout" then
        log:error("Request Timeout")
        msg = {
            header={contentType="table/rtml"},
            body={
                {type="TEXT", x=(w-15)/2, y=h/2, text="Request Timeout", color=colors.red}
            }
        }
    end
    if msg == "unknown_host" then
        log:error("Unknown Host")
        msg = {
            header={contentType="table/rtml"},
            body={
                {type="TEXT", x=(w-15)/2, y=h/2, text="Unknown Host", color=colors.red}
            }
        }
    end
    if type(msg) == "string" then
        log:error("NET: "..msg)
        msg = {
            header={contentType="table/rtml"},
            body={
                {type="TEXT", x=(w-15)/2, y=h/2, text="Error: "..msg, color=colors.red}
            }
        }
    end
    if type(msg) ~= "table" then
        log:error("Malformed Message")
        msg = {
            header={contentType="table/rtml"},
            body={
                {type="TEXT", x=(w-15)/2, y=h/2, text="Error: Malformed Message", color=colors.red}
            }
        }
    end
    if type(msg.body) == "table" and msg.cypher then
        log:error("Decryption Failure")
        msg = {
            header = { contentType = "table/rtml" },
            body = {
                { type = "TEXT", x = (w - 15) / 2, y = h / 2, text = "Error: Decryption Failure", color = colors.red }
            }
        }
    end

    if msg.header.code == rttp.responseCodes.movedPermanently or msg.header.code == rttp.responseCodes.movedTemporarily then
        path = msg.header.redirect
        log:info("Redirect: "..path)
        if #back > 0 then
            back[#back] = { domain, path }
        end
    else
        url = domain..path
        display(msg)
        local link = nil
        local activeInput = nil
        while not link do
            local event = { os.pullEvent() }
            
            if event[1] == "mouse_click" then
                local eventN, button, x, y = unpack(event)

                if not (activeInput == nil) then drawInput(activeInput, false) end
                activeInput = nil
                if y == 1 then
                    if x == w then
                        term.setBackgroundColor(colors.black)
                        term.clear()
                        term.setCursorPos(1, 1)
                        return
                    elseif x == w - 2 then
                        domain = ""
                        path = ""
                        drawBar()
                        break
                    elseif x == w - 4 then
                        local f = fs.open
                        local bkms = tblStore.loadF(bkmFileName)
                        local ex = false
                        for i = 1, #bkms do
                            if bkms[i].href == url then
                                ex = true
                            end
                        end
                        if not ex then
                            table.insert(bkms, { name = url, href = url })
                            tblStore.saveF(bkms, bkmFileName)
                        end
                    elseif x == 1 then
                        if #back > 0 then
                            local b = table.remove(back)
                            domain = b[1]
                            path = b[2]
                            drawBar()
                            break
                        end
                    elseif x == 3 then
                        break
                    else
                        editURL = true
                        drawBar()
                    end
                else
                    editURL = false
                    for i = 1, #links do
                        local lnk = links[i]
                        if x >= lnk.x and x < lnk.x + lnk.w and y == lnk.y then
                            link = lnk
                            break
                        end
                    end
                    for i = 1, #buttons do
                        local btn = buttons[i]
                        if x >= btn.x and x < btn.x + btn.w and y == btn.y then
                            -- do thing with button here
                            if btn.action == "SUBMIT" then
                                local rsp = {
                                    vals = {},
                                    type = "BUTTON_SUBMIT"
                                }
                                for j = 1, #inputs do
                                    local inp = inputs[j]
                                    rsp.vals[inp.name] = inp.val
                                end
                                log:debug("Button pressed")
                                local message = rttp.postSync(domain, path, "object/lua", rsp)
                                if message ~= "timeout" then
                                    log:debug("Button response code " .. message.header.code)
                                    if message.header.code == 307 then
                                        -- path = msg.header.redirect
                                        link = {
                                            type = "LINK",
                                            href = message.header.redirect
                                        }
                                    else
                                        if message.header.contentType == "text/plain" then
                                            log:debug("Response: " .. message.body)
                                        end
                                    end
                                else
                                    log:error("Button timeout")
                                end
                            end
                            break
                        end
                    end
                    for i = 1, #inputs do
                        local inp = inputs[i]
                        if x >= inp.x and x < inp.x + inp.w and y == inp.y then
                            drawInput(activeInput, false)
                            activeInput = inp
                            drawInput(activeInput, true)
                            break
                        end
                    end
                end
            elseif event[1] == "char" then
                if editURL then
                    url = url .. event[2]
                    drawBar()
                elseif not (activeInput == nil) then
                    activeInput.val = activeInput.val .. event[2]
                    drawInput(activeInput, true)
                end
            elseif event[1] == "key" then
                local eventN, key, hold = unpack(event)
                local kN = keys.getName(key)
                if editURL then
                    if key == keys.backspace then
                        url = string.sub(url, 1, -2)
                    elseif key == keys.enter or key == keys.numPadEnter then
                        _, domain, path = net.splitUrl(url)
                        path = '/'..path
                        editURL = false
                        drawBar()
                        break
                    else
                        -- url = url..keyToChar(key)
                    end
                    drawBar()
                elseif not (activeInput == nil) then
                    if key == keys.backspace then
                        activeInput.val = string.sub(activeInput.val, 1, -2)
                        drawInput(activeInput, true)
                    elseif key == keys.enter or key == keys.numPadEnter then
                        drawInput(activeInput, false)
                        activeInput = nil
                    else
                        -- activeInput.val = activeInput.val..keyToChar(key)
                        drawInput(activeInput, true)
                    end
                end
                if key == keys.tab then
                    if activeInput == nil and #inputs > 0 then
                        activeInput = inputs[1]
                    end
                    if activeInput ~= nil then
                        local i = activeInput.i + 1
                        if i > #inputs then
                            drawInput(activeInput, false)
                            activeInput = nil
                        else
                            drawInput(activeInput, false)
                            activeInput = inputs[i]
                        end
                    end
                end
            elseif event[1] == "timer" then
                if event[2] == cursorBlinkTimer then
                    cursorBlink = not cursorBlink;
                    cursorBlinkTimer = os.startTimer(cursorBlinkTime)
                    -- drawInput(activeInput, true)
                    -- drawBar();
                end
            end
        end
        if link then
            if link.type == "DOM-LINK" then
                _, domain, path = net.splitUrl(link.href)
                path = '/'..path
            else
                if not string.start(link.href, '/') then
                    path = fs.combine(path, link.href)
                else
                    path = link.href
                end
            end
        end
        os.sleep(0.1)
    end
end