--!The Make-like Build Utility based on Lua
--
-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Copyright (C) 2015 - 2017, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        has_flags.lua
--

-- imports
import("lib.detect.cache")

-- attempt to check it from the argument list 
function _check_from_arglist(flags, opt)

    -- only one flag?
    if #flags > 1 then
        return 
    end

    -- make cache key
    local key = "detect.tools.link.has_flags"

    -- make allflags key
    local flagskey = opt.program .. "_" .. (opt.programver or "")

    -- load cache
    local cacheinfo = cache.load(key)

    -- get all allflags from argument list
    local allflags = cacheinfo[flagskey]
    if not allflags then

        -- get argument list
        allflags = {}
        local arglist = nil
        try 
        {
            function () os.runv(opt.program, {"-?"}) end,
            catch 
            {
                function (errors) arglist = errors end
            }
        }
        if arglist then
            for arg in arglist:gmatch("(/[%-%a%d]+)%s+") do
                allflags[arg:gsub("/", "-"):lower()] = true
            end
        end

        -- save cache
        cacheinfo[flagskey] = allflags
        cache.save(key, cacheinfo)
    end

    -- ok?
    return allflags[flags[1]:gsub("/", "-"):lower()]
end

-- try running to check flags
function _check_try_running(flags, opt)

    -- make an stub source file
    local flags_str = table.concat(flags, " "):lower()
    local winmain = flags_str:find("subsystem:windows")
    local sourcefile = path.join(os.tmpdir(), "detect", ifelse(winmain, "winmain_", "") .. "link_has_flags.c")
    if not os.isfile(sourcefile) then
        if winmain then
            io.writefile(sourcefile, "int WinMain(void* instance, void* previnst, char** argv, int argc)\n{return 0;}")
        else
            io.writefile(sourcefile, "int main(int argc, char** argv)\n{return 0;}")
        end
    end

    -- compile the source file
    local objectfile = os.tmpfile() .. ".obj"
    local binaryfile = os.tmpfile() .. ".exe"
    os.iorunv("cl", {"-c", "-nologo", "-Fo" .. objectfile, sourcefile})

    -- try link it
    local ok = try { function () os.execv(opt.program, table.join(flags, "-nologo", "-out:" .. binaryfile, objectfile)); return true end }

    -- remove files
    os.tryrm(objectfile)
    os.tryrm(binaryfile)

    -- ok?
    return ok
end

-- ignore some flags
function _ignore_flags(flags)
    local results = {}
    for _, flag in ipairs(flags) do
        if not flag:find("[%-/]def:.+%.def") then
            table.insert(results, flag)
        end
    end
    return results
end

-- has_flags(flags)?
-- 
-- @param opt   the argument options, .e.g {toolname = "", program = "", programver = "", toolkind = "[cc|cxx|ld|ar|sh|gc|rc|dc|mm|mxx]"}
--
-- @return      true or false
--
function main(flags, opt)

    -- ignore some flags
    flags = _ignore_flags(flags)
    if #flags == 0 then
        return true
    end

    -- attempt to check it from the argument list 
    if _check_from_arglist(flags, opt) then
        return true
    end

    -- try running to check it
    return _check_try_running(flags, opt)
end

