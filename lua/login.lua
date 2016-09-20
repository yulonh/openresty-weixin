local config = require("comm.config")
local json = require("cjson.safe")
local wx = require("comm.wx")
local ERR_CODE = require("comm.err_code")
-- 获取URI参数
local args = ngx.req.get_uri_args()
local code = args.code
-- 参数无效
if code == nil or code == "" then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(json.encode({code=-1,msg="缺少code参数"}))
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
end

local res, err = wx.getJSON(config.access_token_url, {
        appid=config.appid,
        secret=config.secret,
        code=code,
        grant_type="authorization_code"
    })

if not res then
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(json.encode({code = -1, msg = err}))
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

if not res.errcode then
    local access_token = res.access_token
    -- 设置cookie
    ngx.header["Set-Cookie"]="access_token="..access_token..";Path=/; HttpOnly"
    -- 存入用户信息到redis
    local redis = require "comm.redis"
    local red = redis:new()
    local outdate_token = red:get(res.openid)
    red:init_pipeline()
    red:hmset(access_token, res)
    -- 设置超时
    red:expire(access_token,res.expires_in) 
    local resfresh_token_key = "refresh_token."..res.access_token
    red:set(resfresh_token_key, res.refresh_token)
    -- refresh_token超时为30天
    red:expire(resfresh_token_key, 2592000)
    -- 删除过期的信息
    if outdate_token then 
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
        ngx.say(json.encode({code = -1, msg = err_msg}))
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    else
        ngx.say(json.encode({code = 0, msg = "login success"}))
        ngx.exit(ngx.HTTP_OK)
    end
else
    local err_msg = ERR_CODE[res.errcode]
    ngx.status = ngx.HTTP_BAD_REQUEST
    ngx.say(json.encode({code=-1,msg=err_msg}))
    ngx.log(ngx.ERR, err_msg)
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end


