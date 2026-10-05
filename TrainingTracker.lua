_addon.name = 'TrainingTracker'
_addon.author = 'Alden Park'
_addon.version = '0.4'
_addon.commands = {'trainingtracker', 'tt'}

require('luau')
texts = require('texts')
config = require('config')

local defaults = {Position = {X = 30, Y = 220}}
local settings = config.load(defaults)
config.save(settings)

local display = texts.new('${text}', {
    pos = {x = settings.Position.X, y = settings.Position.Y},
    bg = {alpha = 180, red = 0, green = 0, blue = 0},
    padding = 8,
    flags = {draggable = true},
    text = {font = 'Arial', size = 11, alpha = 255, red = 255, green = 255, blue = 255},
})

local state = {
    active = false,
    targets = {},
    area = nil,
    current = 0,
    total = nil,
    progresses = {},
    reading_targets = false,
    test_status = nil,
}

local function refresh()
    if not state.active then
        display:hide()
        return
    end

    local lines = {}
    if state.test_status then lines[#lines + 1] = state.test_status end
    if state.area then lines[#lines + 1] = 'Area: ' .. state.area end
    lines[#lines + 1] = 'Training targets:'
    if #state.targets == 0 then
        lines[#lines + 1] = state.reading_targets and '  (reading page...)' or '  (targets unknown)'
    end
    for _, target in ipairs(state.targets) do lines[#lines + 1] = '  ' .. target end
    for _, progress in ipairs(state.progresses) do
        lines[#lines + 1] = ('Progress: %d/%d'):format(progress.current, progress.total)
    end
    display:text(table.concat(lines, '\n'))
    display:show()
end

local function clear()
    state.active = false
    state.targets = {}
    state.area = nil
    state.current = 0
    state.total = nil
    state.progresses = {}
    state.reading_targets = false
    state.test_status = nil
    refresh()
end

local function save_position()
    -- texts objects can be dragged directly; persist their final coordinates
    -- when the addon unloads or the character logs out.
    local x, y = display:pos()
    if x and y then
        settings.Position.X, settings.Position.Y = x, y
        config.save(settings)
    end
end

local function self_test()
    state.active = true
    state.area = 'West Ronfaure (mock)'
    state.targets = {'3 Orcs', '2 Scarab Beetles'}
    state.progresses = {{current = 1, total = 3}, {current = 1, total = 3}}
    state.reading_targets = false
    state.test_status = '[MOCK TEST] simulated training progress'
    refresh()
    windower.add_to_chat(207, 'TrainingTracker mock test displayed.')
end

windower.register_event('incoming text', function(original, modified, mode)
    local text = original:gsub(string.char(0x7F, 0x31), '')

    -- Only a mode-151 manual/tome page can start a new training record. Other
    -- dialog containing similar wording must not erase the current panel.
    if mode == 151 and text:find('The information on this page instructs you', 1, true)
        and #state.targets == 0 then
        state.active = true
        state.targets = {}
        state.area = nil
        state.reading_targets = true
        refresh()
        return
    end

    -- Progress can arrive without the page-opening text (for example when
    -- the addon was loaded after training was selected). Keep that evidence
    -- instead of dropping it just because the targets are unknown.
    local progress_current, progress_total = text:match('You defeated a designated target%. %(Progress:%s*(%d+)/(%d+)%)')
    if progress_current then
        state.active = true
    elseif not state.active then
        return
    end

    local combat_text = text:match('^[^:]+ uses ') or text:match('^[^:]+ readies ')
        or text:match('^[^:]+ casts ') or text:match('^[^:]+ starts casting ')
        or text:match('^[^:]+ hits ') or text:match('^[^:]+ misses ')
    if state.reading_targets and #state.targets == 0 and mode == 151 and not combat_text then
        local target_line, members_line = text:match('^([^\a]+)\a(.+)$')
        if target_line and target_line:match('^%d+%s') and members_line:match('^%d+%s') then
            state.targets[#state.targets + 1] = target_line:gsub('%.$', '')
            state.targets[#state.targets + 1] = members_line:gsub('%.$', '')
        elseif text:match('^%d+ .+%.?$') then
            state.targets[#state.targets + 1] = text:gsub('%.$', '')
        elseif text:find('Target level range:', 1, true) then
            state.reading_targets = false
        end
    end

    local area = text:match('^Training area:%s*(.+)%.?$')
    if area then
        state.area = area
        state.reading_targets = false
    end

    local current, total = progress_current, progress_total
    if current then
        current, total = tonumber(current), tonumber(total)
        local found = false
        for _, progress in ipairs(state.progresses) do
            -- Same totals can belong to different target groups. Only advance
            -- an existing entry when this is its next sequential progress;
            -- another 1/3 therefore remains a separate entry. The game does
            -- not include mob identity in this message, so out-of-order
            -- advances cannot be assigned more precisely.
            if progress.total == total and current == progress.current + 1 then
                progress.current = current
                found = true
                break
            end
        end
        if not found then
            state.progresses[#state.progresses + 1] = {current = current, total = total}
        end
    end

    if text:find('You have successfully completed the training regime', 1, true) then
        for _, progress in ipairs(state.progresses) do
            if progress.current < progress.total then progress.current = progress.total end
        end
    elseif text:find('Your current training regime will begin anew', 1, true) then
        for _, progress in ipairs(state.progresses) do progress.current = 0 end
    elseif text:find('Training regime canceled', 1, true) then
        clear()
        return
    end

    refresh()
end)

windower.register_event('addon command', function(command, ...)
    local args = {...}
    command = (command or ''):lower()
    if command == 'hide' then
        display:hide()
    elseif command == 'show' then
        refresh()
        if not state.active then
            windower.add_to_chat(207, 'TrainingTracker has no training page yet; select a page after loading the addon.')
        end
    elseif command == 'test' then
        self_test()
    elseif command == 'clear' or command == 'reset' then
        if command == 'reset' then
            clear()
            settings.Position.X, settings.Position.Y = defaults.Position.X, defaults.Position.Y
            display:pos(settings.Position.X, settings.Position.Y)
            config.save(settings)
        else
            clear()
        end
    elseif command == 'pos' or command == 'position' then
        local x, y = tonumber(args[1]), tonumber(args[2])
        if x and y then
            settings.Position.X, settings.Position.Y = x, y
            display:pos(x, y)
            config.save(settings)
        end
    elseif command == 'move' then
        local dx, dy = tonumber(args[1]) or 0, tonumber(args[2]) or 0
        settings.Position.X = settings.Position.X + dx
        settings.Position.Y = settings.Position.Y + dy
        display:pos(settings.Position.X, settings.Position.Y)
        config.save(settings)
    elseif command == 'help' then
        windower.add_to_chat(207, '//tt show|hide|clear|reset|test')
        windower.add_to_chat(207, '//tt pos <x> <y>  or  //tt move <dx> <dy>')
    end
end)

windower.register_event('logout', function()
    save_position()
    clear()
end)
windower.register_event('unload', save_position)

windower.register_event('load', function()
    windower.add_to_chat(207, 'TrainingTracker loaded. It starts tracking the next training page you read.')
end)
