local setmetatable = setmetatable

local _M = require('apicast.policy').new('Custom Log', '1.0')
local mt = { __index = _M }
local apicast = require('apicast').new()
local resty_env = require 'resty.env'
local cjson = require "cjson"

local breadcrumbid = ""
local response_body = ""

function _M.new()
    return setmetatable({}, mt)
end

function _M.rewrite()
	local random = math.random
	local template ='xxxxxxxxxxxxyyxxxxxxxxxxxxxxyy'
	breadcrumbid = string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v) end)
		
    --breadcrumbid = ngx.var.request_id..ngx.var.connection
    request_uri = ngx.var.request_uri
    response_body = ""
	if resty_env.get("APICAST_LOG_LEVEL") then
		local h = ngx.req.get_headers()
		local hs = ""

		local body = ngx.var.request_body or ""
		local simplified_body = body
		for k, v in pairs(h) do
			hs = hs..k..": "..v..";"
		end
		
		local cjson = require "cjson"
		
		if (body ~= '') then
			local decoded_body = cjson.decode(body)
			simplified_body = cjson.encode(decoded_body)
		end
		
		ngx.log(ngx.INFO, '(', breadcrumbid, ') ', 'Request URI : '..request_uri)
		ngx.log(ngx.INFO, '(', breadcrumbid, ') ', 'Request Headers: '..hs)
		ngx.log(ngx.INFO, '(', breadcrumbid, ') ', 'Request Body: '..body)
		ngx.log(ngx.INFO, '(', breadcrumbid, ') ', 'Request Simplified Body (Json keys do not have the same order as the real one and \'/\' will be escaped): '..simplified_body)
	end
	ngx.req.set_header("breadcrumbId", breadcrumbid)
end

function _M.header_filter()
    ngx.header.content_length = nil
    ngx.header["X-Application-Context"] = nil
end

function _M.body_filter()
    if resty_env.get("APICAST_LOG_LEVEL") then
        local resp_body = string.sub(ngx.arg[1], 1, 1000)
        ngx.ctx.buffered = (ngx.ctx.buffered or "") .. resp_body
        if ngx.arg[2] then
            response_body = ngx.ctx.buffered
        end
    end
end

function _M.log()
    ngx.header.content_length = nil

    if resty_env.get("APICAST_LOG_LEVEL") then
        local h = ngx.resp.get_headers()
        local hs = ""
        for k, v in pairs(h) do
            hs = hs..k..": "..v..";"
        end
        
        local response_time = ngx.var.request_time
        
        if response_time == nil or response_time == '' then
            response_time = 0
        end
        
        ngx.log(ngx.INFO, '(', breadcrumbid, ') ', 'Response_Status_'..ngx.status)
        ngx.log(ngx.INFO, '(', breadcrumbid, ') ', 'Response Status: '..ngx.status)
        ngx.log(ngx.INFO, '(', breadcrumbid, ') ', 'Response Headers: '..hs)
        ngx.log(ngx.INFO, '(', breadcrumbid, ') ', 'Response Body (Plese be aware of incomplete log for long response): '..response_body)
        ngx.log(ngx.INFO, '(', breadcrumbid, ') ', 'Response Time: '..tostring(tonumber(response_time)*1000)..' millis')
    end
end

return _M