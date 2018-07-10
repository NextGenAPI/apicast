--- Policy module
-- Policies should define a method for each of the nginx phases (rewrite,
-- access, etc.) in which they want to run code. When Apicast runs each of
-- those phases, if the policy has been loaded, it will run the code in the
-- method with the phase name. So for example, if we want to define a policy
-- that needs to execute something in the rewrite phase, we need to write
-- a 'rewrite' method.

local _M = { }

local PHASES = {
    'init', 'init_worker',
    'rewrite', 'access',
    'content', 'balancer',
    'header_filter', 'body_filter',
    'post_action',  'log', 'metrics',

    'ssl_certificate',
}

local GC = require('apicast.gc')
local setmetatable_gc_clone = GC.setmetatable_gc_clone
local ipairs = ipairs
local format = string.format
local pcall = pcall

local sandbox = require('apicast.sandbox')

local noop = function() end

local function __tostring(policy)
    return format("Policy: %s (%s)", policy._NAME, policy._VERSION)
end

local function __eq(policy, other)
    return policy._NAME == other._NAME and policy._VERSION == other._VERSION
end

-- TODO: this could be somewhere else shared with TemplateString.
local allowed_funcs = {
    -- TODO: just an example of what we could expose.
    get_header = function(header)
        return ngx.req.get_headers()[header]
    end
}

local function evaluate_condition(condition)
    -- TODO: add quota to sandbox call to prevent resource exhaustion.
    local ok, result = pcall(sandbox.run, 'return ' .. condition, { env = allowed_funcs })

    if ok then
        return result
    else
        -- TODO: show error and return false
        return false
    end
end

--- Initialize new policy
-- Returns a new policy that you can extend however you want.
-- @tparam string name Name of the new policy.
-- @tparam string version Version of the new policy. Default value is 0.0
-- @treturn policy New policy
-- @treturn table New policy metatable.
function _M.new(name, version)
    local policy = {
        _NAME = name,
        _VERSION = version or '0.0',
    }

    local mt = { __index = policy, __tostring = __tostring, policy = policy }


    function policy.new(config)
        local p = setmetatable_gc_clone({}, mt)

        for _, phase in _M.phases() do
            local original_func = p[phase]

            p[phase] = function(...)
                if evaluate_condition((config and config.condition) or 'true') then
                    original_func(...)
                end
            end
        end

        return p
    end

    for _, phase in _M.phases() do
        policy[phase] = noop
    end

    return setmetatable(policy, { __tostring = __tostring, __eq = __eq }), mt
end

function _M.phases()
    return ipairs(PHASES)
end

return _M
