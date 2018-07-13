local lpeg = require('lpeg')

local tostring = tostring
local ipairs = ipairs
local loadstring = loadstring
local pack = table.pack
local insert = table.insert
local concat = table.concat

local _M = {}

local value_of = {
  request_method = function() return ngx.req.get_method() end,
  request_host = function() return ngx.var.host end,
  request_path = function() return ngx.var.uri end
}

local function value_of_attr(attr)
  return '"' .. value_of[attr]() .. '"'
end

local function to_op(op)
  if op == "!=" then
    return "~="
  else
    return op
  end
end

local function evaluate(...)
  local expr = {}

  for _, arg in ipairs(pack(...)) do
    insert(expr, tostring(arg))
  end

  expr = concat(expr, '')

  local f = loadstring("return " .. expr)

  return f()
end

local parser = lpeg.P({
  "expr";

  expr =
    lpeg.V("spc") *
    lpeg.V("attr") *
    lpeg.V("spc") *
    (
      lpeg.V("op") *
      lpeg.V("spc") *
      lpeg.V("string") *
      lpeg.V("spc")
    )^-1
    / evaluate,

  attr =
    lpeg.C(
      lpeg.P('request_method') +
      lpeg.P('request_host') +
      lpeg.P('request_path')
    )
    / value_of_attr,

  spc = lpeg.S(" \t\n")^0,

  op = lpeg.C(
         lpeg.P('==') +
         lpeg.P('~=') +
         lpeg.P('!=')
       )
       / to_op,

  string =
    lpeg.C(
      (lpeg.P('"') + lpeg.P("'")) *
      (
        lpeg.R("AZ") +
        lpeg.R("az") +
        lpeg.R("09") +
        lpeg.S("/_")
      )^0 *
      (lpeg.P('"') + lpeg.P("'"))
    )
    / tostring
})

function _M.evaluate(expression)
  return parser:match(expression)
end

return _M
