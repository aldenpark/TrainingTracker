-- Minimal offline tests for TrainingTracker's state transitions.
local events = {}
local rendered = ''

_addon = {}
windower = {
    register_event = function(name, fn) events[name] = fn end,
    add_to_chat = function() end,
}

package.preload['luau'] = function() return {} end
package.preload['config'] = function()
    return {load = function(defaults) return defaults end, save = function() end}
end
package.preload['texts'] = function()
    return {new = function()
        return {
            text = function(_, value) rendered = value end,
            show = function() end,
            hide = function() end,
            pos = function() end,
        }
    end}
end

dofile('TrainingTracker.lua')
local incoming = events['incoming text']
local command = events['addon command']

local function assert_contains(value, expected)
    assert(value:find(expected, 1, true), ('expected %q in %q'):format(expected, value))
end

-- Unknown progress is displayed and a later page fills in its metadata.
incoming('You defeated a designated target. (Progress: 1/3)', '', 0)
assert_contains(rendered, 'targets unknown')
assert_contains(rendered, 'Progress: 1/3')
incoming('The information on this page instructs you to defeat the following:', '', 151)
incoming('3 Orcs.', '', 151)
incoming('Training area: West Ronfaure.', '', 151)
assert_contains(rendered, 'Area: West Ronfaure')
assert_contains(rendered, '3 Orcs')
assert_contains(rendered, 'Progress: 1/3')

-- Equal totals represent separate target groups.
incoming('You defeated a designated target. (Progress: 1/3)', '', 0)
assert_contains(rendered, 'Progress: 1/3\nProgress: 1/3')

-- Reset clears tracking and restores the default position without errors.
command('reset')
command('show')

print('TrainingTracker tests passed')
