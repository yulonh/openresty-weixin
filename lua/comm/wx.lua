local json = require("cjson.safe")
local http = require "resty.http"

local _M = {}

-- 获取json数据
function _M.getJSON(uri, query, body)
    local method = 'GET'
    if body ~= nil and body ~= '' then
        method = 'POST'
    end

    local httpc = http.new()
    local res, err = httpc:request_uri(uri, {
        method = method,
        query = query,
        body = body,
        ssl_verify = false
    })
    -- 请求发生错误
    if not res then
        local err_msg = "failed to request uri: " .. uri
        ngx.log(ngx.ERR, err_msg, err)
        return nil, err_msg
    end
    -- 返回码非200
    if 200 ~= res.status then
        ngx.log(ngx.ERR, res.body)
        return nil, res.body
    end

    local ret = json.decode(res.body)
    if not ret then
        local err_msg = "failed to decode json data: " .. res.body
        ngx.log(ngx.ERR, err_msg)
        return nil, err_msg
    else
        return ret, nil
    end
end

-- 获取公用接口调用token
function _M.getAPIToken()
    local redis = require "comm.redis"
    local red = redis:new()
    local api_token = red:get('api_token')

    -- 从数据库获取成功,直接返回
    if api_token then
        return api_token
    end

    -- 数据库的已过期或没有,从微信接口获取
    local config = require("comm.config")
    local res, err = _M.getJSON(config.api_token_url, { grant_type = 'client_credential', appid = config.appid, secret = config.secret })

    if not res then
        return nil, err
    else
        red:set('api_token', res.access_token)
        red:expire('api_token', res.expires_in)
        return res.access_token
    end
end


return _M