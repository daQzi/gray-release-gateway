local redis = require("resty.redis")

--关闭连接
local function close_redis(red)  
    if not red then  
        return  
    end  
    --释放连接(连接池实现)  
    local pool_max_idle_time = 10000 --毫秒  
    local pool_size = 100 --连接池大小  
    local ok, err = red:set_keepalive(pool_max_idle_time, pool_size)  
    if not ok then  
        ngx.log(ngx.ERR,"set keepalive error : ", err)  
    end  
end

--参数
local ip = "192.168.100.26"			--redis ip
local port = 6379          			--redis port
local timeout = 1000				--redis timeout
local database = 0					--redis database
local rKey = "Device_Route"			--redis根节点key
local headerKey = "deviceCode"		--head变量key
local defaultRouteKey = "Device_Route_Default"		--默认路由key
local defaultRoute = ngx.shared.routes				--默认路由缓存
local sharedTimeOut = 60						--失效时间(秒)

local routes = _G.routes

--创建实例  
local red = redis:new()  
--设置超时（毫秒）  
red:set_timeout(timeout)
--建立连接  
local ok, err = red:connect(ip, port)

if not ok then  
    ngx.log(ngx.ERR,err)
    return close_redis(red)  
end  
--设置db
red:select(database)

local default
local route = defaultRoute:get(defaultRouteKey)
if route then
	default = route
else
	--读取默认路由
	default = red:get(defaultRouteKey)
	local ok, err = defaultRoute:set(defaultRouteKey, default,sharedTimeOut)
	ngx.log(ngx.ALERT, "default_route=", default)
end	


--获取header key
local headers = ngx.req.get_headers()
local deviceCode = headers[headerKey]

--deviceCode=null
if deviceCode == nil then
	ngx.exec(tostring(default));
    return
end

--读redis
local route, err = red:get(rKey.."_"..deviceCode)
if not route then  
    ngx.say("get msg error : ", err)  
    return close_redis(red)  
end  
close_redis(red)
--得到的数据为空处理  
if route == ngx.null then  
    route = ''  --比如默认值  
end 

if route == '' then
	ngx.exec(tostring(default));
    return
end

if route ~= '' then
    ngx.exec(tostring(route));
    return
end