local ERR_CODE = require("comm.err_code")
local redis = require "comm.redis"
local red = redis:new()
local json = require("cjson.safe")
local http = require "resty.http"
local httpc = http.new()
local config = require("comm.config")
local wx = require("comm.wx")
local access_token = ngx.var.cookie_access_token

-- cookie为空
if access_token == nil or access_token == '' then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.say(json.encode({code=-1,msg="access_token无效"}))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

local function refresh_token()
    -- redis中的用户信息已过期，尝试用refresh_token去刷新
    local last_refresh_token_key = "refresh_token."..access_token
    local refresh_token, err = red:get(last_refresh_token_key)
    if refresh_token then 
        local res, err = wx.getJSON(config.refresh_token_url, {appid=config.appid,grant_type="refresh_token",refresh_token=refresh_token})
        -- 请求发生错误
        if not res then
            ngx.status = ngx.HTTP_BAD_REQUEST
            ngx.say(json.encode({code=-1, msg=err}))
            return ngx.exit(ngx.HTTP_BAD_REQUEST)
        end

        if not res.errcode then
            local access_token = res.access_token
            -- 设置cookie
            ngx.header["Set-Cookie"]="access_token="..access_token..";Path=/; HttpOnly"
            local outdate_token = red:get(res.openid)
            -- 存入用户信息到redis
            red:init_pipeline()
            red:hmset(access_token, res)
            -- 设置超时
            red:expire(access_token,res.expires_in) 
            -- 旧的refresh_token已失效，删除
            red:del(last_refresh_token_key)
            local resfresh_token_key = "refresh_token."..res.access_token
            red:set(resfresh_token_key, res.refresh_token)
            -- refresh_token超时为30天
            red:expire(resfresh_token_key, 2592000) 
            -- 删除过期的信息
            if outdate_token and outdate_token ~= res.access_token then 
                red:del(outdate_token)
                red:del("refresh_token."..outdate_token)
            end
            -- 设置openid对应的access_token
            red:set(res.openid, res.access_token)
            local ok, err = red:commit_pipeline()
            if not ok then
                local err_msg = "failed to set user info"
                ngx.log(ngx.ERR, err_msg, err)
                ngx.status = ngx.HTTP_BAD_REQUEST
                ngx.say(json.encode({code = -1, msg = err_msg, err = err }))
                ngx.exit(ngx.HTTP_BAD_REQUEST)
            else
                ngx.ctx.user = res
                return true
            end
        else
            -- 刷新access_token失败，可能refresh_token已失效
            err_msg = ERR_CODE[res.errcode]
            ngx.status = ngx.HTTP_UNAUTHORIZED
            ngx.say(json.encode({code=-1, msg=err_msg}))
            ngx.log(ngx.ERR, "auth failed: "..err_msg)
            return ngx.exit(ngx.HTTP_UNAUTHORIZED)
        end
    else
        -- refresh_token没找到
        err_msg = "refresh_token已失效"
        ngx.status = ngx.HTTP_UNAUTHORIZED
        ngx.say(json.encode({code=-1, msg=err_msg}))
        ngx.log(ngx.ERR, "auth failed: "..err_msg)
        return ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
end

-- 从redis获取用户信息
local res, err = red:hgetall(access_token)
if res and table.getn(res)>0 then
    user = red:array_to_hash(res)
    ngx.ctx.user = user
    return true
else
    return refresh_token()
end
