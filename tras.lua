local list = [[
#DEFINE $PL

#VAR $three 3

#FUNC $PL->coords->*=$ret
#RETURN $ret
#ENDFUNC

#FUNC $PL->all->*=$ret
#PRINT $ret
#VAR $test $ret
#RETURN $three test
#ENDFUNC

#EXEC $PL->all->$three
#PRINT $test
]]
local ForbiddenLetters = {
    ['\n']=true,
    [' ']=true,
    ['*']=true,
    ['-']=true,
    ['=']=true
}

local start = false
local res = {}
for i=1,list:len()do
    if not start then
        if list:sub(i,i)=='#'then
            start=i
        end
    else
        if list:sub(i,i)=='\n' then
            res[#res+1]=list:sub(start,i-1)
            start=false
        end
    end
end
local answers = {}
for i=1,#res do
    local retval = {}
    local strlen = res[i]:len()
    local start = false
    for j=1,strlen do
        if not start then
            if res[i]:sub(j,j)~=" "then
                start=j
            end
            if j==strlen then
                retval[#retval+1]=res[i]:sub(start,j):gsub(' ','')
            end
        elseif res[i]:sub(j,j)==" "or j==strlen then
            retval[#retval+1]=res[i]:sub(start,j):gsub(' ','')
            start=false
        end
    end
    local data = {}
    data.command = retval[1]
    table.remove(retval,1)
    data.data = retval
    answers[#answers+1]=data
end

local function IsVar(arg)
    if arg:sub(1,1)=='$'then
        return arg
    else
        return false
    end
end

local classes = {}
local Values = {}
local ConstValues = {}
local methodsVariables = {}

local function RegisterClass(arg)
    classes[arg]={}
    methodsVariables[arg]={}
    return classes[arg]
end

local function DoesClassExist(arg)
    return classes[arg]~=nil
end

local function GetClassMethod(class,method)
    return (classes[class] and classes[class][method])and classes[class][method]
end

local function RegisterMethod(class,method,variable)
    if classes[class]then
        methodsVariables[class][method]={}
        classes[class][method]={retval=nil,variable=variable}
        return classes[class][method]~=nil
    end
    return false
end

local function AddToMethod(class,method,cmd,arg)
    if classes[class]and classes[class][method]then
        classes[class][method][#classes[class][method]+1]={command=cmd,data=arg}
        return classes[class][method][#classes[class][method]]~=nil
    end
    return false
end

local function RegisterMethodReturn(class,method,arg)
    if classes[class]and classes[class][method]then
        classes[class][method].retval=arg
    end
end

local function RegisterMethodVariable(class,method,variable,value)
    if methodsVariables[class] and methodsVariables[class][method] then
        methodsVariables[class][method][variable]=value
    end
end

local function GetValue(arg,class,method)
    if class and method then
        if methodsVariables[class] and methodsVariables[class][method] and methodsVariables[class][method][arg]then
            return GetValue(methodsVariables[class][method][arg]or arg)
        end
    end
    return Values[arg]or ConstValues[arg]
end

local function GetMethodReturn(class,method)
    if classes[class]and classes[class][method]then
        return GetValue(classes[class][method].retval,class,method)
    end
    return nil
end

local function IsParam(class,method)
    if classes[class]and classes[class][method]then
        return classes[class][method].variable~=nil
    end
end

local function GetValueDefinition(value,class,method)
    local substr = value:sub(1,1)
    if substr=='$'then
        return (GetValue(value,class,method)or GetValue(value))or((class and method)and methodsVariables[class][method][value])
    elseif substr=='%'then
        return load("return "..value:sub(2,value:len()))()
    else
        return value
    end
end

local function SetValue(arg,value,class,method,override)
    if class and method then
        if methodsVariables[class]and methodsVariables[class][method]and not override then
            methodsVariables[class][method][arg]=GetValueDefinition(value,class,method)or GetValueDefinition(value)
        else
            Values[arg]=GetValueDefinition(value,class,method)
        end
    else
        Values[arg]=GetValueDefinition(value,class,method)
    end
end

local function SetConstValue(arg,value)
    if not ConstValues[arg]then
        ConstValues[arg]=value
    else
        print('[WARNING] VARIABLE '..arg..' IS CONSTANT')
    end
end

local function EvaluateExpression(arg,method)
    if arg and method then
        if GetValue(arg)==GetValue(method)then
            return true
        else
            return false
        end
    else
        if arg then
            return GetValue(arg)~="false"   
        end
    end
    return false
end

local function GetArg(arg,num)
    arg=arg..'\n'
    local start = false
    local num = num or 1
    local found = 0
    for i=1,arg:len()do
        if not start then
            if arg:sub(i,i)~=' 'then
                start=i
            end
        else
            local str = arg:sub(i,i)
            if str==" "or str=="-"or str=="="or str=="\n"then
                found=found+1
                if num==found then
                    local sub = arg:sub(start,i-1)
                    return (sub~=""and sub or nil)
                else
                    start=false
                end
            end
        end
    end
    return nil
end

local function GetVar(arg,num)
    arg=arg..'\n'
    local start = false
    local num = num or 1
    local found = 0
    for i=1,arg:len()do
        if not start then
            if arg:sub(i,i)=='$'then
                start=i
            end
        else
            local str = arg:sub(i,i)
            if ForbiddenLetters[str]then
                found=found+1
                if num==found then
                    local sub = arg:sub(start,i-1)
                    return (sub~=""and sub or nil)
                else
                    start=false
                end
            end
        end
    end
    return nil
end

local function GetMethod(arg,num)
    arg=arg..'\n'
    local start = false
    local num = num or 1
    local found = 0
    for i=1,arg:len()do
        if not start then
            if arg:sub(i-found,i+1-found)=='->'then
                start=i+2-found
            end
        else
            local str = arg:sub(i,i)
            if ForbiddenLetters[str]then
                found=found+1
                if num==found then
                    local sub = arg:sub(start,i-1)
                    return (sub~=""and sub or nil)
                else
                    start=false
                end
            end
        end
    end
    return nil
end

local function GetParam(arg,num)
    arg=arg..'\n'
    local start = false
    local num = num or 1
    local found = 0
    for i=1,arg:len()do
        if not start then
            if arg:sub(i-found,i+1-found)=='*='then
                start=i+2-found
            end
        else
            local str = arg:sub(i,i)
            if str==" "or str=="-"or str=="\n"then
                found=found+1
                if num==found then
                    local sub = arg:sub(start,i-1)
                    return (sub~=""and sub or nil)
                else
                    start=false
                end
            end
        end
    end
    return nil
end

function Splice(arg)
    local var = GetVar(arg,1)
    local method = GetMethod(arg,1)
    if not var or not method then
        return nil
    end
    return {
        class=var,
        method=method,
        arg={
            method = GetParam(arg,1)
        }
    }
end

local AwaitFunctionEnd = false
local LastMethod = nil

local AwaitLoopEnd = false

local functions = {
    ['#DEFINE'] = function(args)
        local var = IsVar(args[1])
        if var then
            return RegisterClass(args[1])
        end
    end,
    ['#FUNC'] = function(args)
        if AwaitFunctionEnd then
            AwaitFunctionEnd=false
            LastMethod=nil
        end
        local args = Splice(args[1])
        if args then
            if not DoesClassExist(args.class)then
                return false
            end
            local arg = args.arg.method
            RegisterMethod(args.class,args.method,arg)
            LastMethod={
                class=args.class,
                method=args.method
            }
            AwaitFunctionEnd=true
        end
        return args~=false
    end,
    ['#ENDFUNC'] = function(args)
        AwaitFunctionEnd=false
        LastMethod=nil
        return not AwaitFunctionEnd
    end,
    ['#RETURN'] = function(args,class,method)
        local args = GetVar(args[1],1)
        if args and (AwaitFunctionEnd or class or method) then
            RegisterMethodReturn(class or LastMethod.class,method or LastMethod.method,args)
            return true
        end
        return false
    end,
    ['#VAR'] = function(args,class,method)
        local p1,p2 = GetVar(args[1],1),args[2]
        SetValue(p1,p2,class,method,true)
        return (p1 and p2)
    end,
    ['#EXEC'] = function(args)
        local class,method,param,result = GetVar(args[1],1),GetMethod(args[1],1),GetMethod(args[1],2),GetParam(args[1],1)
        local res = ExecuteClassMethod(class,method,param)
        if result then
            SetValue(result,res)
        end
        return true
    end,
    ['#PRINT'] = function(args,class,method)
        local res = ""
        for i=1,#args do
            res=res..GetValue(args[i],class,method)..(i~=#args and " "or"")
        end
        print(res)
        return true
    end,
    ['#CONST'] = function(args)
        local var,value = GetVar(args[1],1),args[2]
        SetConstValue(var,value)
    end,
    ['#WHILE'] = function(args)
        local var,method = GetVar(args[1],1),GetMethod(args[1],1)
        local expr = EvaluateExpression(var,method)
        AwaitLoopEnd=true
        return true
    end,
    ['#ENDWHILE'] = function(args)
        AwaitLoopEnd=false
        return not AwaitLoopEnd
    end
}

function ExecuteClassMethod(class,method,param)
    local methods = GetClassMethod(class,method)
    if methods then
        if param then
            SetValue(methods.variable,GetValue(param),class,method)
            RegisterMethodVariable(class,method,methods.variable,param)
        end
        for i=1,#methods do
            if functions[methods[i].command]then
                functions[methods[i].command](methods[i].data,class,method)
            end
        end
        local method = GetMethodReturn(class,method)
        return method
    else
        return false
    end
end

for i=1,#answers do
    local cmd = answers[i].command:upper()
    if AwaitFunctionEnd and cmd~='#ENDFUNC' then
        AddToMethod(LastMethod.class,LastMethod.method,cmd,answers[i].data)
    else
        if AwaitLoopEnd and cmd~="#ENDWHILE" then

        else
            if functions[cmd]then
                if functions[cmd](answers[i].data) then
                    --print('Command: '..cmd..' Loaded')
                else
                    print('Command: '..cmd..' Failed To Load')
                end
            end
        end
    end
end
