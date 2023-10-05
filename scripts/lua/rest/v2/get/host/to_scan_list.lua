--
-- (C) 2013-23 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local vs_utils = require "vs_utils"
local search_map = _GET["map_search"]
local format_utils = require "format_utils"

local port = _GET["port"]

local sort = _GET["sort"]

local function portCheck(tcp_ports_list, port) 
    if (isEmptyString(port)) then
        return true
    else 
        local ports = split(tcp_ports_list,",")
        for _, item in ipairs(ports) do
            if (item == port) then
                return true
            end
        end

        return false
    end
end


local function format_epoch(value)
    if (value.last_scan~= nil and value.last_scan.epoch~= nil) then
        return format_utils.formatPastEpochShort(value.last_scan.epoch)
    else 
        return value.last_scan.time
    end
end

local function format_result(result) 
    local rsp = {}
    if result then
        if not isEmptyString(sort) and sort == 'ip' then
            table.sort(result, function (k1, k2)  return (k1.host or k1.host_name) < (k2.host or k2.host_name) end )
        end
        for _,value in ipairs(result) do
            -- FIX ME with udp port check
            if portCheck(value.tcp_ports_list, port) then
                if (isEmptyString(search_map)) then
                    rsp[#rsp+1] = value
                    rsp[#rsp].num_vulnerabilities_found = format_high_num_value_for_tables(value, "num_vulnerabilities_found")
                    rsp[#rsp].num_open_ports = format_high_num_value_for_tables(value, "num_open_ports")
                    rsp[#rsp].tcp_ports = format_high_num_value_for_tables(value, "tcp_ports")
                    rsp[#rsp].udp_ports = format_high_num_value_for_tables(value, "udp_ports")
                    if (rsp[#rsp].tcp_ports == 0 and rsp[#rsp].udp_ports == 0) then
                        rsp[#rsp].tcp_ports = rsp[#rsp].num_open_ports
                    end
                    if(rsp[#rsp].last_scan) then
                        rsp[#rsp].last_scan.time = format_epoch(value)
                    end
                else 
                    if (value.host == search_map or string.find(value.host,search_map) or string.find(value.host_name,search_map)) then
                        rsp[#rsp+1] = value
                        rsp[#rsp].num_vulnerabilities_found = format_high_num_value_for_tables(value, "num_vulnerabilities_found")
                        rsp[#rsp].num_open_ports = format_high_num_value_for_tables(value, "num_open_ports")
                        if(rsp[#rsp].last_scan) then
                            rsp[#rsp].last_scan.time = format_epoch(value)
                        end
                    end
                end

                if (next(rsp) and not isEmptyString(rsp[#rsp].tcp_ports_list)) then
                    local formatted_ports_list = ""
                    for index,port in ipairs(split(rsp[#rsp].tcp_ports_list,',')) do
                        local service_name = mapServiceName(port, "tcp")
                        local port_label = vs_utils.format_port_label(port, service_name, "tcp")
                        
    
                        
                        if (index == 1) then
                            formatted_ports_list = port_label
                        else
                            formatted_ports_list = string.format("%s,%s",formatted_ports_list,port_label)
                        end
                    end
    
                    rsp[#rsp].tcp_ports_list = formatted_ports_list
                end

                if not isEmptyString(sort) and sort == 'ip' then
                    rsp[#rsp].host = ternary(isEmptyString(rsp[#rsp].host_name), rsp[#rsp].host, rsp[#rsp].host_name)
                end
            end
        end

        if not isEmptyString(sort) and sort == 'ip' then
            table.sort(rsp, function (k1, k2)  return k1.host < k2.host end )
        end



    end 
    return rsp 
end

local function retrieve_host(host) 
    local result = vs_utils.retrieve_hosts_to_scan()

    return format_result(result)
end

rest_utils.answer(rest_utils.consts.success.ok, retrieve_host())

