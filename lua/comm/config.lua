local _M = {
    appid = "",
    secret = "",
    auth_url = "https://sz.api.weixin.qq.com/sns/auth",
    userinfo_url = "https://sz.api.weixin.qq.com/sns/userinfo",
    refresh_token_url = "https://sz.api.weixin.qq.com/sns/oauth2/refresh_token",
    access_token_url = "https://sz.api.weixin.qq.com/sns/oauth2/access_token",
    api_token_url = "https://api.weixin.qq.com/cgi-bin/token",
    merchant_url = "https://api.weixin.qq.com/merchant/",
    redis = {host = "yulonh.com"}
}

return _M
