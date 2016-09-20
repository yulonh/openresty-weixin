FROM openresty/openresty
# author
MAINTAINER dengyulong <dengyulong@gf.com.cn>
COPY . /home/openresty
ENTRYPOINT ["/usr/local/openresty/bin/openresty", "-p", "/home/openresty", "-g", "daemon off;"]
