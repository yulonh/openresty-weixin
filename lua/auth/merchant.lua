local config = require("comm.config")
local json = require("cjson.safe")
local wx = require("comm.wx")
local ERR_CODE = require("comm.err_code")

-- 读取get参数
local args = ngx.req.get_uri_args()
local action = args.action

if action == nil or action == '' then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(json.encode({ code = -1, msg = '缺少action参数' }))
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
end

-- 读取post参数
ngx.req.read_body()
local data = ngx.req.get_body_data()

-- 转成json对象
if data ~= nil and data ~= '' then
    local post_json = json.decode(data)
    if not post_json then
        ngx.status = ngx.HTTP_BAD_REQUEST
        ngx.say(json.encode({ code = -1, msg = 'POST数据格式错误,必须是正确的JSON格式' }))
        return ngx.exit(ngx.HTTP_BAD_REQUEST)
    end
end

local api_token, err = wx.getAPIToken()
if not api_token then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(json.encode({ code = -1, msg = '获取api_token失败:' .. err }))
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
end

local res, err = wx.getJSON(config.merchant_url .. action, { access_token = api_token }, data)
if not res then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(json.encode({ code = -1, msg = err }))
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
end

ngx.say(json.encode(res))
return ngx.exit(ngx.HTTP_OK)