--- Mimic the AWK type system.

local intmt = {}
local strmt = {}

local function atoi(e) return tonumber(e) or 0 end

function strmt.__add(l,r) return  atoi(l) +  atoi(r) end
function strmt.__sub(l,r) return  atoi(l) -  atoi(r) end
function strmt.__mul(l,r) return  atoi(l) *  atoi(r) end
function strmt.__div(l,r) return  atoi(l) /  atoi(r) end
function strmt.__mod(l,r) return  atoi(l) %  atoi(r) end
function strmt.__pow(l,r) return  atoi(l) ^  atoi(r) end
function strmt.__lt (l,r) return  atoi(l) <  atoi(r) end
function strmt.__eq (l,r) return  atoi(l) == atoi(r) end
function strmt.__le (l,r) return  atoi(l) <= atoi(r) end
function strmt.__unm(l)   return -atoi(l) end

function intmt.__add(l, r) return  (atoi(l) or l and 1 or 0) +  (atoi(r) or r and 1 or 0)  end
function intmt.__sub(l, r) return  (atoi(l) or l and 1 or 0) -  (atoi(r) or r and 1 or 0)  end
function intmt.__mul(l, r) return  (atoi(l) or l and 1 or 0) *  (atoi(r) or r and 1 or 0)  end
function intmt.__div(l, r) return  (atoi(l) or l and 1 or 0) /  (atoi(r) or r and 1 or 0)  end
function intmt.__mod(l, r) return  (atoi(l) or l and 1 or 0) %  (atoi(r) or r and 1 or 0)  end
function intmt.__pow(l, r) return  (atoi(l) or l and 1 or 0) ^  (atoi(r) or r and 1 or 0)  end
function intmt.__lt (l, r) return  (atoi(l) or l and 1 or 0) <  (atoi(r) or r and 1 or 0)  end
function intmt.__eq (l, r) return  (atoi(l) or l and 1 or 0) == (atoi(r) or r and 1 or 0)  end
function intmt.__le (l, r) return  (atoi(l) or l and 1 or 0) <= (atoi(r) or r and 1 or 0)  end
function intmt.__unm(l)    return -(atoi(l) or l and 1 or 0)  end
function intmt.__tostring(l) return (tonumber(l) or "")  end

debug.setmetatable("", strmt)
debug.setmetatable(true, intmt)
debug.setmetatable(nil, intmt)