adservers=newDS()

function preresolve(dq)
        if(not adservers:check(dq.qname)) then
                return false
        end

        -- Return NXDOMAIN (non-existent domain), which 
        dq.rcode = pdns.NXDOMAIN -- set NXDOMAIN answer
        return true  
end

adservers:add(dofile("/etc/powerdns/adblocklist.lua"))