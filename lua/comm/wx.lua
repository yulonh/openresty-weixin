local json = require("cjson.safe")
local http = require "resty.http"
local httpc = http.new()

local _M = {}

-- 获取json数据
function _M.getJSON(uri, query)
    local res, err = httpc:request_uri(uri, {
            query = query,
            ssl_verify = false
        })
    -- 请求发生错误
    if not res then
        local err_msg = "failed to request uri: "..uri
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
        local err_msg = "failed to decode json data: "..res.body
        ngx.log(ngx.ERR, err_msg)
        return nil, err_msg
    else
        return ret, nil
    end
end


return _M