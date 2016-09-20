local json = require("cjson.safe")
local config = require("comm.config")
local ERR_CODE = require("comm.err_code")
local wx = require("comm.wx")
local access_token = ngx.ctx.user.access_token

-- 如果scope包含snsapi_userinfo模式登录并且没有拉取过userinfo
local has_userinfo = string.find(ngx.ctx.user.scope, "snsapi_userinfo")
if not ngx.ctx.user.userinfo and has_userinfo then
    local res, err = wx.getJSON(config.userinfo_url, {
            access_token=access_token,
            openid=ngx.ctx.user.openid,
            lang="zh_CN"
        })
    -- 请求发生错误
    if not res then
        ngx.status = ngx.HTTP_BAD_REQUEST
        ngx.say(json.encode({code = -1, msg = err_msg}))
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    end

    if not res.errcode then
        -- 存入用户信息到redis
        local redis = require "comm.redis"
        local red = redis:new()
        -- 合并信息
        res.userinfo = true
        local ok, err = red:hmset(access_token, res)
        if not ok then
            local err_msg = "failed to merge user info"
            ngx.log(ngx.ERR, err_msg, err)
            ngx.status = ngx.HTTP_BAD_REQUEST
            ngx.say(json.encode({code = -1, msg = err_msg}))
            ngx.exit(ngx.HTTP_BAD_REQUEST)
        else
            local res, err = red:hgetall(access_token)
            if res and table.getn(res)>0 then
                user = red:array_to_hash(res)
                ngx.ctx.user = user
                ngx.say(json.encode(ngx.ctx.user))
                ngx.exit(ngx.HTTP_OK)
            end
        end
    else
        -- 获取userinfo失败
        local err_msg = ERR_CODE[res.errcode]
        ngx.status = ngx.HTTP_BAD_REQUEST
        ngx.say(json.errcode({code=-1,msg=err_msg}))
        ngx.log(ngx.ERR, err_msg)
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    end
else
    ngx.say(json.encode(ngx.ctx.user))
    ngx.exit(ngx.HTTP_OK)
end




