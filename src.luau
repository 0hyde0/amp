--[[
MIT License

Copyright (c) 2022-2024 TheGreatSageEqualToHeaven
Copyright (c) 2019-2024 Roblox Corporation
Copyright (c) 1994–2019 Lua.org, PUC-Rio.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local Deserialize = (function()
	local type = type
	local pcall = pcall
	local error = error
	local tonumber = tonumber
	local assert = assert
	local setmetatable = setmetatable

	local string_format = string.format

	local table_move = table.move
	local table_pack = table.pack
	local table_unpack = table.unpack
	local table_create = table.create
	local table_insert = table.insert
	local table_remove = table.remove
	local table_concat = table.concat

	local coroutine_create = coroutine.create
	local coroutine_yield = coroutine.yield
	local coroutine_resume = coroutine.resume
	local coroutine_close = coroutine.close

	local buffer_fromstring = buffer.fromstring
	local buffer_len = buffer.len
	local buffer_readu8 = buffer.readu8
	local buffer_readu32 = buffer.readu32
	local buffer_readstring = buffer.readstring
	local buffer_readf32 = buffer.readf32
	local buffer_readf64 = buffer.readf64

	local bit32_bor = bit32.bor
	local bit32_band = bit32.band
	local bit32_btest = bit32.btest
	local bit32_rshift = bit32.rshift
	local bit32_lshift = bit32.lshift
	local bit32_extract = bit32.extract

	local ttisnumber = function(v) return type(v) == "number" end
	local ttisstring = function(v) return type(v) == "string" end
	local ttisboolean = function(v) return type(v) == "boolean" end
	local ttisfunction = function(v) return type(v) == "function" end
	
	local opList = {
		{ "NOP", 0, 0, false },
		{ "BREAK", 0, 0, false },
		{ "LOADNIL", 1, 0, false },
		{ "LOADB", 3, 0, false },
		{ "LOADN", 4, 0, false },
		{ "LOADK", 4, 3, false },
		{ "MOVE", 2, 0, false },
		{ "GETGLOBAL", 1, 1, true },
		{ "SETGLOBAL", 1, 1, true },
		{ "GETUPVAL", 2, 0, false },
		{ "SETUPVAL", 2, 0, false },
		{ "CLOSEUPVALS", 1, 0, false },
		{ "GETIMPORT", 4, 4, true },
		{ "GETTABLE", 3, 0, false },
		{ "SETTABLE", 3, 0, false },
		{ "GETTABLEKS", 3, 1, true },
		{ "SETTABLEKS", 3, 1, true },
		{ "GETTABLEN", 3, 0, false },
		{ "SETTABLEN", 3, 0, false },
		{ "NEWCLOSURE", 4, 0, false },
		{ "NAMECALL", 3, 1, true },
		{ "CALL", 3, 0, false },
		{ "RETURN", 2, 0, false },
		{ "JUMP", 4, 0, false },
		{ "JUMPBACK", 4, 0, false },
		{ "JUMPIF", 4, 0, false },
		{ "JUMPIFNOT", 4, 0, false },
		{ "JUMPIFEQ", 4, 0, true },
		{ "JUMPIFLE", 4, 0, true },
		{ "JUMPIFLT", 4, 0, true },
		{ "JUMPIFNOTEQ", 4, 0, true },
		{ "JUMPIFNOTLE", 4, 0, true },
		{ "JUMPIFNOTLT", 4, 0, true },
		{ "ADD", 3, 0, false },
		{ "SUB", 3, 0, false },
		{ "MUL", 3, 0, false },
		{ "DIV", 3, 0, false },
		{ "MOD", 3, 0, false },
		{ "POW", 3, 0, false },
		{ "ADDK", 3, 2, false },
		{ "SUBK", 3, 2, false },
		{ "MULK", 3, 2, false },
		{ "DIVK", 3, 2, false },
		{ "MODK", 3, 2, false },
		{ "POWK", 3, 2, false },
		{ "AND", 3, 0, false },
		{ "OR", 3, 0, false },
		{ "ANDK", 3, 2, false },
		{ "ORK", 3, 2, false },
		{ "CONCAT", 3, 0, false },
		{ "NOT", 2, 0, false },
		{ "MINUS", 2, 0, false },
		{ "LENGTH", 2, 0, false },
		{ "NEWTABLE", 2, 0, true },
		{ "DUPTABLE", 4, 3, false },
		{ "SETLIST", 3, 0, true },
		{ "FORNPREP", 4, 0, false },
		{ "FORNLOOP", 4, 0, false },
		{ "FORGLOOP", 4, 8, true },
		{ "FORGPREP_INEXT", 4, 0, false },
		{ "FASTCALL3", 3, 1, true },
		{ "FORGPREP_NEXT", 4, 0, false },
		{ "DEP_FORGLOOP_NEXT", 0, 0, false },
		{ "GETVARARGS", 2, 0, false },
		{ "DUPCLOSURE", 4, 3, false },
		{ "PREPVARARGS", 1, 0, false },
		{ "LOADKX", 1, 1, true },
		{ "JUMPX", 5, 0, false },
		{ "FASTCALL", 3, 0, false },
		{ "COVERAGE", 5, 0, false },
		{ "CAPTURE", 2, 0, false },
		{ "SUBRK", 3, 7, false },
		{ "DIVRK", 3, 7, false },
		{ "FASTCALL1", 3, 0, false },
		{ "FASTCALL2", 3, 0, true },
		{ "FASTCALL2K", 3, 1, true },
		{ "FORGPREP", 4, 0, false },
		{ "JUMPXEQKNIL", 4, 5, true },
		{ "JUMPXEQKB", 4, 5, true },
		{ "JUMPXEQKN", 4, 6, true },
		{ "JUMPXEQKS", 4, 6, true },
		{ "IDIV", 3, 0, false },
		{ "IDIVK", 3, 2, false },
	}

	local LUA_MULTRET = -1
	local LUA_GENERALIZED_TERMINATOR = -2

	local function luau_newsettings()
		return {
			vectorCtor = function() error("vectorCtor was not provided") end,
			vectorSize = 4,
			useNativeNamecall = false,
			namecallHandler = function() error("Native __namecall handler was not provided") end,
			extensions = {},
			callHooks = {},
			errorHandling = true,
			generalizedIteration = true,
			allowProxyErrors = false,
			useImportConstants = false,
			staticEnvironment = {},
			decodeOp = function(op) return op end
		}
	end

	local function luau_validatesettings(luau_settings)
		assert(type(luau_settings) == "table", "luau_settings should be a table")
		assert(type(luau_settings.vectorCtor) == "function", "luau_settings.vectorCtor should be a function")
		assert(type(luau_settings.vectorSize) == "number", "luau_settings.vectorSize should be a number")
		assert(type(luau_settings.useNativeNamecall) == "boolean", "luau_settings.useNativeNamecall should be a boolean")
		assert(type(luau_settings.namecallHandler) == "function", "luau_settings.namecallHandler should be a function")
		assert(type(luau_settings.extensions) == "table", "luau_settings.extensions should be a table of functions")
		assert(type(luau_settings.callHooks) == "table", "luau_settings.callHooks should be a table of functions")
		assert(type(luau_settings.errorHandling) == "boolean", "luau_settings.errorHandling should be a boolean")
		assert(type(luau_settings.generalizedIteration) == "boolean", "luau_settings.generalizedIteration should be a boolean")
		assert(type(luau_settings.allowProxyErrors) == "boolean", "luau_settings.allowProxyErrors should be a boolean")
		assert(type(luau_settings.staticEnvironment) == "table", "luau_settings.staticEnvironment should be a table")
		assert(type(luau_settings.useImportConstants) == "boolean", "luau_settings.useImportConstants should be a boolean")
		assert(type(luau_settings.decodeOp) == "function", "luau_settings.decodeOp should be a function")
	end

	local function getmaxline(module, protoid)
		local proto = if (protoid == nil) then module.mainProto else module.protoList[protoid]
		local size = -1

		assert(proto.lineinfoenabled, "proto must have debug enabled")

		for pc = 1, proto.sizecode do
			local line = proto.instructionlineinfo[pc]
			size = if (line > size) then line else size
		end

		for i, subid in proto.protos do
			local maxline = getmaxline(module, subid)
			size = if (maxline > size) then maxline else size
		end

		return size
	end

	local function getcoverage(module, protoid, depth, callback, size)
		local proto = if (protoid == nil) then module.mainProto else module.protoList[protoid]

		assert(proto.lineinfoenabled, "proto must have debug enabled")

		local buffer = {}

		for pc = 1, proto.sizecode do
			local inst = proto.code[pc]
			local line = proto.instructionlineinfo[pc]

			if (inst.opcode ~= 69) then --[[ COVERAGE ]]
				continue
			end

			local hits = inst.E

			buffer[line] = if ((buffer[line] or 0) > hits) then buffer[line] else hits
		end

		callback(proto.debugname, proto.linedefined, depth, buffer, size)

		for i, subid in proto.protos do
			getcoverage(module, subid, depth + 1, callback, size)
		end
	end

	local function luau_getcoverage(module, protoid, callback)
		assert(type(module) == "table", "module must be a table")
		assert(type(protoid) == "number" or type(protoid) == "nil", "protoid must be a number or nil")
		assert(type(callback) == "function", "callback must be a function")
		getcoverage(module, protoid, 0, callback, getmaxline(module))
	end

	local function resolveImportConstant(static, count, k0, k1, k2)
		local res = static[k0]
		if count < 2 or res == nil then
			return res
		end
		res = res[k1]
		if count < 3 or res == nil then
			return res
		end
		res = res[k2]
		return res
	end

	local function luau_deserialize(bytecode, luau_settings)
		if luau_settings == nil then
			luau_settings = luau_newsettings()
		else 
			luau_validatesettings(luau_settings)
		end

		local stream = if type(bytecode) == "string" then buffer_fromstring(bytecode) else bytecode
		local cursor = 0

		local function readByte()
			local byte = buffer_readu8(stream, cursor)
			cursor = cursor + 1
			return byte
		end

		local function readWord()
			local word = buffer_readu32(stream, cursor)
			cursor = cursor + 4
			return word
		end

		local function readFloat()
			local float = buffer_readf32(stream, cursor)
			cursor = cursor + 4
			return float
		end

		local function readDouble()
			local double = buffer_readf64(stream, cursor)
			cursor = cursor + 8
			return double
		end

		local function readVarInt()
			local result = 0

			for i = 0, 4 do
				local value = readByte()
				result = bit32_bor(result, bit32_lshift(bit32_band(value, 0x7F), i * 7))
				
				if not bit32_btest(value, 0x80) then
					break
				end
			end

			return result
		end

		local function readString()
			local size = readVarInt()

			if size == 0 then
				return ""
			else
				local str = buffer_readstring(stream, cursor, size)
				cursor = cursor + size

				return str
			end
		end

		local luauVersion = readByte()
		local typesVersion = 0

		if luauVersion == 0 then
			error("the provided bytecode is an error message",0)
		elseif luauVersion < 3 or luauVersion > 6 then
			error("the version of the provided bytecode is unsupported: " .. luauVersion)
		elseif luauVersion >= 4 then
			typesVersion = readByte()
		end

		local stringCount = readVarInt()
		local stringList = table_create(stringCount)

		for i = 1, stringCount do
			stringList[i] = readString()
		end

		local function readInstruction(codeList, indexfn)
			local index = readWord()
			local value = luau_settings.decodeOp(index)
			local opcode = bit32_band(value, 0xFF)

			local opinfo = opList[opcode + 1]
			local opname = opinfo[1]
			local opmode = opinfo[2]
			local kmode = opinfo[3]
			local usesAux = opinfo[4]

			local inst = {
				opcode = opcode;
				opname = opname;
				opmode = opmode;
				kmode = kmode;
				usesAux = usesAux;
			}

			table_insert(codeList, inst)

			if opmode == 1 then --[[ A ]]
				inst.A = bit32_band(bit32_rshift(value, 8), 0xFF)
			elseif opmode == 2 then --[[ AB ]]
				inst.A = bit32_band(bit32_rshift(value, 8), 0xFF)
				inst.B = bit32_band(bit32_rshift(value, 16), 0xFF)
			elseif opmode == 3 then --[[ ABC ]]
				inst.A = bit32_band(bit32_rshift(value, 8), 0xFF)
				inst.B = bit32_band(bit32_rshift(value, 16), 0xFF)
				inst.C = bit32_band(bit32_rshift(value, 24), 0xFF)
			elseif opmode == 4 then --[[ AD ]]
				inst.A = bit32_band(bit32_rshift(value, 8), 0xFF)
				local temp = bit32_band(bit32_rshift(value, 16), 0xFFFF)
				inst.D = if temp < 0x8000 then temp else temp - 0x10000
			elseif opmode == 5 then --[[ AE ]]
				local temp = bit32_band(bit32_rshift(value, 8), 0xFFFFFF)
				inst.E = if temp < 0x800000 then temp else temp - 0x1000000
			end

			if usesAux then 
				local aux = readWord()
				inst.aux = aux

				table_insert(codeList, {value = aux, opname = "auxvalue" })
			end

			return usesAux
		end

		local function checkkmode(inst, k)
			local kmode = inst.kmode

			if kmode == 1 then --// AUX
				inst.K = k[inst.aux +  1]
			elseif kmode == 2 then --// C
				inst.K = k[inst.C + 1]
			elseif kmode == 3 then--// D
				inst.K = k[inst.D + 1]
			elseif kmode == 4 then --// AUX import
				local extend = inst.aux
				local count = bit32_rshift(extend, 30)
				local id0 = bit32_band(bit32_rshift(extend, 20), 0x3FF)

				inst.K0 = k[id0 + 1]
				inst.KC = count
				if count == 2 then
					local id1 = bit32_band(bit32_rshift(extend, 10), 0x3FF)

					inst.K1 = k[id1 + 1]
				elseif count == 3 then
					local id1 = bit32_band(bit32_rshift(extend, 10), 0x3FF)
					local id2 = bit32_band(bit32_rshift(extend, 0), 0x3FF)

					inst.K1 = k[id1 + 1]
					inst.K2 = k[id2 + 1]
				end
				if luau_settings.useImportConstants then
					inst.K = resolveImportConstant(
						luau_settings.staticEnvironment,
						count, inst.K0, inst.K1, inst.K2
					)
				end
			elseif kmode == 5 then --// AUX boolean low 1 bit
				inst.K = bit32_extract(inst.aux, 0, 1) == 1
				inst.KN = bit32_extract(inst.aux, 31, 1) == 1
			elseif kmode == 6 then --// AUX number low 24 bits
				inst.K = k[bit32_extract(inst.aux, 0, 24) + 1]
				inst.KN = bit32_extract(inst.aux, 31, 1) == 1
			elseif kmode == 7 then --// B
				inst.K = k[inst.B + 1]
			elseif kmode == 8 then --// AUX number low 16 bits
				inst.K = bit32_band(inst.aux, 0xf)
			end
		end

		local function readProto(bytecodeid)
			local maxstacksize = readByte()
			local numparams = readByte()
			local nups = readByte()
			local isvararg = readByte() ~= 0
			local typesize = 0
			local __flags = 0

			if luauVersion >= 4 then
				__flags = readByte() --// flags 
				typesize = readVarInt();
				cursor = cursor + typesize;
			end
			
			local sizecode = readVarInt()
			local codelist = table_create(sizecode)

			local skipnext = false 
			for i = 1, sizecode do
				if skipnext then 
					skipnext = false
					continue 
				end

				skipnext = readInstruction(codelist, i)
			end
			
			local insts = {}
			
			for i, v in codelist do
				table.insert(insts, v.opname ~= "auxvalue" and v.opname or nil)
			end
			
			local debugcodelist = table_create(sizecode) 
			for i = 1, sizecode do 
				debugcodelist[i] = codelist[i].opcode
			end 

			local sizek = readVarInt()
			local klist = table_create(sizek)

			for i = 1, sizek do
				local kt = readByte()
				local k

				if kt == 0 then --// Nil
					k = nil
				elseif kt == 1 then --// Bool
					k = readByte() ~= 0
				elseif kt == 2 then --// Number
					k = readDouble()
				elseif kt == 3 then --// String
					k = stringList[readVarInt()]
				elseif kt == 4 then --// Import
					k = readWord()
				elseif kt == 5 then --// Table
					local dataLength = readVarInt()
					k = table_create(dataLength)

					for i = 1, dataLength do
						k[i] = readVarInt()
					end
				elseif kt == 6 then --// Closure
					k = readVarInt()
				elseif kt == 7 then --// Vector
					local x,y,z,w = readFloat(), readFloat(), readFloat(), readFloat()

					if luau_settings.vectorSize == 4 then
						k = luau_settings.vectorCtor(x,y,z,w)
					else 
						k = luau_settings.vectorCtor(x,y,z)
					end
				end

				klist[i] = k
			end
			
			-- // 2nd pass to replace constant references in the instruction
			for i = 1, sizecode do
				checkkmode(codelist[i], klist)
			end
			
			local sizep = readVarInt()
			local protolist = table_create(sizep)

			for i = 1, sizep do
				protolist[i] = readVarInt() + 1
			end
			
			local linedefined = readVarInt()

			local debugnameindex = readVarInt()
			local debugname 

			if debugnameindex ~= 0 then
				debugname = stringList[debugnameindex]
			else 
				debugname = nil
			end

			-- // lineinfo
			local lineinfoenabled = readByte() ~= 0
			local instructionlineinfo = nil 
			
			if lineinfoenabled then
				local linegaplog2 = readByte()

				local intervals = bit32_rshift((sizecode - 1), linegaplog2) + 1

				local lineinfo = table_create(sizecode)
				local abslineinfo = table_create(intervals)
				
				local lastoffset = 0
				for j = 1, sizecode do
					lastoffset += readByte()
					lineinfo[j] = lastoffset
				end
				
				local lastline = 0
				for j = 1, intervals do
					lastline += readWord()
					abslineinfo[j] = lastline % (2 ^ 32)
				end
				
				instructionlineinfo = table_create(sizecode)

				for i = 1, sizecode do 
					--// p->abslineinfo[pc >> p->linegaplog2] + p->lineinfo[pc];
					table_insert(instructionlineinfo, abslineinfo[bit32_rshift(i - 1, linegaplog2) + 1] + lineinfo[i])
				end
			end

			-- // debuginfo
			if readByte() ~= 0 then
				local sizel = readVarInt()
				for i = 1, sizel do
					readVarInt()
					readVarInt()
					readVarInt()
					readByte()
				end
				local sizeupvalues = readVarInt()
				for i = 1, sizeupvalues do
					readVarInt()
				end
			end
			
			return {
				MaximumStackSize = maxstacksize;
				ParameterCount = numparams;
				UpvalueCount = nups;
				IsVariableArgument = isvararg;
				LineDefined = linedefined;
				DebuggingName = debugname;

				CodeSize = sizecode;
				Code = codelist;
				CodeDebugList = debugcodelist;

				ConstantSize = sizek;
				ConstantTable = klist;

				ProtoSize = sizep;
				ProtoTable = protolist;

				LineInfoEnabled = lineinfoenabled;
				InstructionLineInfo = instructionlineinfo;

				Id = bytecodeid;
			}
		end

		-- userdataRemapping (not used in VM, left unused)
		if typesVersion == 3 then
			local index = readByte()

			while index ~= 0 do
				readVarInt()

				index = readByte()
			end
		end

		local protoCount = readVarInt()
		local protoList = table_create(protoCount)
		
		for i = 1, protoCount do
			protoList[i] = readProto(i - 1)
		end

		local mainProto = protoList[readVarInt() + 1]

		assert(cursor == buffer_len(stream), "deserializer cursor position mismatch")

		mainProto.debugname = "(main)"

		return {
			StringList = stringList,
			ProtoList = protoList,
			MainProto = mainProto
		}
	end

	return function(b)
		local s = luau_newsettings()
		s.decodeOp = function(x) return (x * 203) % 256 end

		local a, b = pcall(luau_deserialize, b)
		if a == false then
			a, b = pcall(luau_deserialize, b, s)
		end
		return b
	end
end)()

--[[
Decompiler
]]

function NamesGenerator()
	local NameGenState = 1
	local NameGenStates = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'}
	local NameGenMaxState = #NameGenStates

	local function Generate()
		local a = math.floor(NameGenState / 52)
		a = a < 1 and NameGenState or a
		local b = math.floor(a / 52)
		local c = math.floor(b / 52)
		local _a = NameGenStates[a] or ""
		local _b = NameGenStates[b] or ""
		local _c = NameGenStates[c] or ""

		NameGenState += 1

		return _a .. _b .. _c
	end
	
	return Generate
end

local DecmopileNameGen = NamesGenerator()

function _decompile(MainProto, ProtoTable, StringTable, Indent, Upvalues, ParentName)
	local Upvalues = Upvalues or {}
	local Namecall = ""
	local Codes = {}
	local Ends = {}
	local CurrentName = DecmopileNameGen()
	local ParentName = ParentName or CurrentName

	local LastStatement = ""
	
	local NewTableActive = false
	local NewTableLeft = {}
	local NewTableVars = {}
	local NewTableIndexes = {}
	
	local CachedClosures = {}
	local AlreadyDefined = {}

	local function Statement2Args(kw1, kw2, s, ci, e)
		local IsWhile = false
		local IndentPaste = ("  "):rep(Indent)

		for Index1 = ci, #MainProto.Code do
			local Code = MainProto.Code[ci]

			if Code.opname == "JUMPBACK" then
				IsWhile = true
				break
			end
		end

		table.insert(Ends, ci + e)

		table.insert(Codes, IndentPaste .. (IsWhile and kw1 or kw2) .. " (" .. s .. ") " .. (IsWhile and "do" or "then"))

		Indent += 1
	end
	
	local function Operation2Args(t, s1, o, s2, cn)
		local IndentPaste = ("  "):rep(Indent)
		local AddLocalPaste = AlreadyDefined[t] and "" or "local "
		
		table.insert(Codes, IndentPaste .. AddLocalPaste .. t .. " = " .. s1 .. " " .. o .. " " .. s2)
	end
	
	for i, v in Upvalues do
		local IndentPaste = ("  "):rep(Indent)	
		
		table.insert(Codes, IndentPaste .. "--UPVALUE " .. i .. " => " .. CurrentName .. v)
	end
	
	local OldLength = #Codes
	local OldParseDiff = 0
	
	local function AddIfTable(ip, al, a, v)
		table.insert(Codes, ip .. al .. CurrentName .. a .. " = " .. v)
	end

	for CodeIndex = 1, #MainProto.Code do
		local CodeParseTime = tick()
		local IndentPaste = ("  "):rep(Indent)
		local Code = MainProto.Code[CodeIndex]
		
		if Code.opname == "auxvalue" then
			continue
		end

		local AddLocalPaste = AlreadyDefined[CurrentName .. Code.A] and "" or "local "
		
		if not AlreadyDefined[CurrentName .. Code.A] then
			AlreadyDefined[CurrentName .. Code.A] = true
		end

		for i, v in Ends do
			if CodeIndex == v + 1 then
				Indent -= 1
				IndentPaste = ("  "):rep(Indent)

				table.insert(Codes, IndentPaste .. "end")
				table.remove(Ends, i)
			end
		end
		
		if Code.opname == "NOP" then
			continue
		elseif Code.opname == "BREAK" then
			table.insert(Codes, IndentPaste .. "break")
		elseif Code.opname == "LOADNIL" then
			AddIfTable(IndentPaste, AddLocalPaste, Code.A, "nil")
		elseif Code.opname == "LOADB" then
			AddIfTable(IndentPaste, AddLocalPaste, Code.A, (Code.B == 0 and "true" or "false"))
		elseif Code.opname == "LOADN" then
			AddIfTable(IndentPaste, AddLocalPaste, Code.A, Code.D)
		elseif Code.opname == "LOADK" then
			local Value = Code.K

			if Value == nil then
				Value = "nil"
			elseif type(Value) == "number" then
				Value = tostring(Value)
			elseif type(Value) == "boolean" then
				Value = Value and "true" or "false"
			elseif type(Value) == "table" then
				Value = "{ ... --[[not implemented]] }"
			elseif type(Value) == "string" then
				Value = "\"" .. Value .. "\""
			else
				Value = "nil -- [[ERROR: Type " .. type(Value) .. "]]"
			end

			AddIfTable(IndentPaste, AddLocalPaste, Code.A, Value)
		elseif Code.opname == "MOVE" then
			AddIfTable(IndentPaste, AddLocalPaste, Code.A, CurrentName .. Code.B)
		elseif Code.opname == "GETGLOBAL" then
			local Value = Code.K

			if Value == nil then
				Value = "nil"
			elseif type(Value) == "number" then
				Value = tostring(Value)
			elseif type(Value) == "boolean" then
				Value = Value and "true" or "false"
			elseif type(Value) == "table" then
				Value = "{ ... --[[not implemented]] }"
			elseif type(Value) == "string" then
				Value = "\"" .. Value .. "\""
			else
				Value = "nil -- [[ERROR: Type " .. type(Value) .. "]]"
			end

			AddIfTable(IndentPaste, AddLocalPaste, Code.A, " = " .. Value)
		elseif Code.opname == "SETGLOBAL" then
			local Value = Code.K

			if Value == nil then
				Value = "nil"
			elseif type(Value) == "number" then
				Value = tostring(Value)
			elseif type(Value) == "boolean" then
				Value = Value and "true" or "false"
			elseif type(Value) == "table" then
				Value = "{ ... --[[not implemented]] }"
			elseif type(Value) == "string" then

			else
				Value = "nil -- [[ERROR: Type " .. type(Value) .. "]]"
			end

			table.insert(Codes, IndentPaste .. Value .. " = " .. CurrentName .. Code.A)
		elseif Code.opname == "GETUPVAL" then
			if Upvalues[Code.B + 1] ~= nil then
				AddIfTable(IndentPaste, AddLocalPaste, Code.A, ParentName .. Upvalues[Code.B + 1])
			else
				error("")
			end
		elseif Code.opname == "SETUPVAL" then
			table.insert(Codes, IndentPaste .. ParentName .. Upvalues[Code.B + 1] .. " = " .. CurrentName .. Code.A)
		elseif Code.opname == "CLOSEUPVAL" then
		elseif Code.opname == "GETIMPORT" then
			local Count = Code.KC
			local r = ""

			if Count == 1 then
				r = Code.K0
			elseif Count == 2 then
				r = Code.K0 .. "[\"" .. Code.K1 .. "\"]"
			elseif Count == 3 then
				r = Code.K0 .. "[\"" .. Code.K1 .. "\"]" .. "[\"" .. Code.K2 .. "\"]"
			end

			AddIfTable(IndentPaste, AddLocalPaste, Code.A, r)
		elseif Code.opname == "GETTABLE" then
			AddIfTable(IndentPaste, AddLocalPaste, Code.A, CurrentName .. Code.B .. "[" .. CurrentName .. Code.C .. "]")
		elseif Code.opname == "SETTABLE" then
			table.insert(Codes, IndentPaste .. CurrentName .. Code.B .. "[" .. CurrentName .. Code.C .. "]" .. " = " .. CurrentName .. Code.A)
		elseif Code.opname == "GETTABLEKS" then
			local Value = Code.K

			AddIfTable(IndentPaste, AddLocalPaste, Code.A, CurrentName .. Code.B .. "[\"" .. Value .. "\"]")
		elseif Code.opname == "SETTABLEKS" then
			local Value = Code.K

			table.insert(Codes, IndentPaste .. CurrentName .. Code.B .. "[\"" .. Value .. "\"]" .. " = " .. CurrentName .. Code.A)
		elseif Code.opname == "GETTABLEN" then
			AddIfTable(IndentPaste, AddLocalPaste, Code.A, CurrentName .. Code.B .. "[" .. Code.C .. "]")
		elseif Code.opname == "SETTABLEN" then
			table.insert(Codes, IndentPaste .. CurrentName .. Code.B .. "[" .. Code.C .. "]" .. " = " .. CurrentName .. Code.A)
		elseif Code.opname == "NEWCLOSURE" then
			local NewProto = ProtoTable[MainProto.ProtoTable[Code.D + 1]]
			local Info = " --[[ Function name: " .. (NewProto.DebuggingName or "??") .. ", Line defined: " .. NewProto.LineDefined .. ", Id: " .. NewProto.Id .. "]]"
			local NewProtoCode = ""
			local Arguments = {}

			if CachedClosures[NewProto.Id] ~= nil then
				local Cached = CachedClosures[NewProto.Id]

				NewProtoCode = Cached[1]
				Arguments = Cached[2]
				local NamesInvolved = Cached[3] 

				if NamesInvolved[CurrentName] ~= nil then
					table.insert(Codes, IndentPaste .. "local " .. CurrentName .. Code.A .. " = " .. CurrentName .. NamesInvolved[CurrentName])
				else
					if #NewProtoCode == 0 then
						table.insert(Codes, IndentPaste .. "local " .. CurrentName .. Code.A .. " = function" .. (#Arguments > 0 and " ( " .. table.concat(Arguments, " ") .. " )" or "()") .. " end" .. Info)
					else
						table.insert(Codes, IndentPaste .. "local " .. CurrentName .. Code.A .. " = function" .. (#Arguments > 0 and " ( " .. table.concat(Arguments, " ") .. " )" or "()") .. Info)
						table.insert(Codes, NewProtoCode)
						table.insert(Codes, IndentPaste .. "end")
					end

					NamesInvolved[CurrentName] = Code.A

					Cached = {NewProtoCode, Arguments, NamesInvolved}
				end

				Info = Info .. " --[[CACHED]]"
			else
				local NewProtoUpvalues = {}

				for Index1 = CodeIndex + 1, #MainProto.Code do
					local Code1 = MainProto.Code[Index1]

					if Code1.opname == "CAPTURE" then
						if Code1.A == 0 then --VAL
							table.insert(NewProtoUpvalues, Code1.B) 
						elseif Code1.A == 1 then --REF
							table.insert(NewProtoUpvalues, Code1.B)
						elseif Code1.A == 2 then --UPVAL
							table.insert(NewProtoUpvalues, Upvalues[Code1.B + 1])
						end
					else
						break
					end
				end

				local s, npc = pcall(_decompile, NewProto, ProtoTable, StringTable, Indent + 1, NewProtoUpvalues, ParentName)

				if s == false then
					print(npc)
					error("")
				end

				for Index = 1, NewProto.ParameterCount do
					table.insert(Arguments, CurrentName .. (Index - 1))
				end

				local Cached = {}
				Cached[1] = npc
				Cached[2] = Arguments
				Cached[3] = {[CurrentName] = Code.A}

				CachedClosures[NewProto.Id] = Cached

				NewProtoCode = npc

				if #NewProtoCode == 0 then
					table.insert(Codes, IndentPaste .. "local " .. CurrentName .. Code.A .. " = function" .. (#Arguments > 0 and " ( " .. table.concat(Arguments, " ") .. " )" or "()") .. " end" .. Info)
				else
					table.insert(Codes, IndentPaste .. "local " .. CurrentName .. Code.A .. " = function" .. (#Arguments > 0 and " ( " .. table.concat(Arguments, " ") .. " )" or "()") .. Info)
					table.insert(Codes, NewProtoCode)
					table.insert(Codes, IndentPaste .. "end")
				end
			end
		elseif Code.opname == "NAMECALL" then
			Namecall = CurrentName .. Code.B .. ":" .. Code.K
		elseif Code.opname == "CALL" then
			local Variables = {}
			local Arguments = {}

			if Code.C > 1 then
				for Index1 = 1, Code.C - 1 do
					table.insert(Variables, CurrentName .. (Code.A + Index1 - 1))
				end
			elseif Code.C == 0 then
				table.insert(Variables, CurrentName .. Code.A)
			end

			if Code.B > 1 then
				for Index1 = 1, Code.B + (Namecall ~= "" and -2 or -1) do
					table.insert(Arguments, CurrentName .. (Code.A + Index1 + (Namecall ~= "" and 1 or 0)))
				end
			elseif Code.B == 0 then
				table.insert(Arguments, CurrentName .. Code.A + 1)
			end

			table.insert(Codes, IndentPaste .. ((Indent > 0 and #Variables > 0) and "local " or "") .. (#Variables > 0 and table.concat(Variables, ", ") .. " = " or "") .. (Namecall ~= "" and Namecall or CurrentName .. Code.A) .. "(" .. table.concat(Arguments, ", ") .. ")")

			Namecall = ""
		elseif Code.opname == "RETURN" then
			local Returns = {}

			if Code.B >= 1 then
				for Index1 = 1, Code.B - 1 do
					table.insert(Returns, CurrentName .. (Code.A + Index1 - 1))
				end
			end
			
			local Skip = false

			if #Returns == 0 then
				if CodeIndex ~= #MainProto.Code then
					local NextCode = MainProto.Code[CodeIndex + 1]

					if NextCode.opname == "CLOSEUPVALS" then
						Skip = true
					end
				else
					Skip = true
				end
			end

			if not Skip then
				table.insert(Codes, IndentPaste .. "return " .. table.concat(Returns, ", "))
			end

			if #Ends == 0 then
				break
			end
		elseif Code.opname == "JUMP" then
			table.insert(Codes, ("  "):rep(Indent - 1) .. "else")
		elseif Code.opname == "JUMPBACK" then
			Indent -= 1
			table.insert(Codes, IndentPaste .. "end")
		elseif Code.opname == "JUMPIF" then
			Statement2Args("while", "if not", CurrentName .. Code.A, CodeIndex, Code.D)
		elseif Code.opname == "JUMPIFNOT" then
			Statement2Args("while not", "if", CurrentName .. Code.A, CodeIndex, Code.D)
		elseif Code.opname == "JUMPIFEQ" then
			Statement2Args("while", "if not", CurrentName .. Code.A .. " == " .. CurrentName .. Code.aux, CodeIndex, Code.D)
		elseif Code.opname == "JUMPIFLE" then
			Statement2Args("while", "if not", CurrentName .. Code.A .. " <= " .. CurrentName .. Code.aux, CodeIndex, Code.D)
		elseif Code.opname == "JUMPIFLT" then
			Statement2Args("while", "if not", CurrentName .. Code.A .. " < " .. CurrentName .. Code.aux, CodeIndex, Code.D)
		elseif Code.opname == "JUMPIFNOTEQ" then
			Statement2Args("while not", "if", CurrentName .. Code.A .. " == " .. CurrentName .. Code.aux, CodeIndex, Code.D)
		elseif Code.opname == "JUMPIFNOTLE" then
			Statement2Args("while not", "if", CurrentName .. Code.A .. " <= " .. CurrentName .. Code.aux, CodeIndex, Code.D)
		elseif Code.opname == "JUMPIFNOTLT" then
			Statement2Args("while not", "if", CurrentName .. Code.A .. " < " .. CurrentName .. Code.aux, CodeIndex, Code.D)
		elseif Code.opname == "ADD" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "+", CurrentName .. Code.C, CurrentName)
		elseif Code.opname == "SUB" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "-", CurrentName .. Code.C, CurrentName)
		elseif Code.opname == "MUL" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "*", CurrentName .. Code.C, CurrentName)
		elseif Code.opname == "DIV" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "/", CurrentName .. Code.C, CurrentName)
		elseif Code.opname == "MOD" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "%", CurrentName .. Code.C, CurrentName)
		elseif Code.opname == "POW" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "^", CurrentName .. Code.C, CurrentName)
		elseif Code.opname == "ADDK" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "+", Code.K, CurrentName)
		elseif Code.opname == "SUBK" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "-", Code.K, CurrentName)
		elseif Code.opname == "MULK" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "*", Code.K, CurrentName)
		elseif Code.opname == "DIVK" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "/", Code.K, CurrentName)
		elseif Code.opname == "MODK" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "%", Code.K, CurrentName)
		elseif Code.opname == "POWK" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "^", Code.K, CurrentName)
		elseif Code.opname == "AND" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "and", CurrentName .. Code.C, CurrentName)
		elseif Code.opname == "OR" then
			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "or", CurrentName .. Code.C, CurrentName)
		elseif Code.opname == "ANDK" then
			local Value = Code.K

			if Value == nil then
				Value = "nil"
			elseif type(Value) == "number" then
				Value = tostring(Value)
			elseif type(Value) == "boolean" then
				Value = Value and "true" or "false"
			elseif type(Value) == "table" then
				Value = "{ ... --[[not implemented]] }"
			elseif type(Value) == "string" then
				Value = "\"" .. Value .. "\""
			else
				Value = "nil -- [[ERROR: Type " .. type(Value) .. "]]"
			end

			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "or", Value, CurrentName)
		elseif Code.opname == "ORK" then
			local Value = Code.K

			if Value == nil then
				Value = "nil"
			elseif type(Value) == "number" then
				Value = tostring(Value)
			elseif type(Value) == "boolean" then
				Value = Value and "true" or "false"
			elseif type(Value) == "table" then
				Value = "{ ... --[[not implemented]] }"
			elseif type(Value) == "string" then
				Value = "\"" .. Value .. "\""
			else
				Value = "nil -- [[ERROR: Type " .. type(Value) .. "]]"
			end

			Operation2Args(CurrentName .. Code.A, CurrentName .. Code.B, "or", Value, CurrentName)
		elseif Code.opname == "CONCAT" then
			AddIfTable(IndentPaste, AddLocalPaste, Code.A, CurrentName .. Code.B .. " .. " .. CurrentName .. Code.C)
		elseif Code.opname == "NOT" then
			table.insert(Codes, IndentPaste .. AddLocalPaste .. CurrentName .. Code.A .. " = not " .. CurrentName .. Code.B)
		elseif Code.opname == "MINUS" then
			table.insert(Codes, IndentPaste .. AddLocalPaste .. CurrentName .. Code.A .. " = -" .. CurrentName .. Code.B)
		elseif Code.opname == "LENGTH" then
			table.insert(Codes, IndentPaste .. AddLocalPaste .. CurrentName .. Code.A .. " = #" .. CurrentName .. Code.B)
		elseif Code.opname == "NEWTABLE" then
			table.insert(Codes, IndentPaste .. AddLocalPaste .. Code.A .. " = {} --[[Size: " .. Code.aux .. "]]")
		elseif Code.opname == "DUPTABLE" then
			--Support later
		elseif Code.opname == "SETLIST" then
			for Index1 = 1, Code.C - 1 do
				table.insert(Codes, IndentPaste .. CurrentName .. Code.A .. "[" .. (Code.aux + Index1) .. "] = " .. CurrentName .. (Code.B + Index1))
			end
		elseif Code.opname == "FORNPREP" then
			table.insert(Codes, IndentPaste .. "for "  .. CurrentName .. (Code.A + 2) .. " = " .. CurrentName .. (Code.A + 2) .. "," .. Code.A .. CurrentName .. Code.A .. ", " .. (Code.A + 1) .. " do")
		elseif Code.opname == "FORNLOOP" then
			table.insert(Codes, IndentPaste .. "end")
		elseif Code.opname == "FORGLOOP" then
		elseif Code.opname == "FORGLOOP_INEXT" then
		elseif Code.opname == "FASTCALL3" then
		elseif Code.opname == "FORGLOOP_NEXT" then
		elseif Code.opname == "NATIVECALL" then
		elseif Code.opname == "GETVARARGS" then
		elseif Code.opname == "DUPCLOSURE" then
			local NewProto = ProtoTable[Code.K + 1]
			local Info = " --[[ Function name: " .. (NewProto.DebuggingName or "??") .. ", Line defined: " .. NewProto.LineDefined .. ", Id: " .. NewProto.Id .. "]]"
			local NewProtoCode = ""
			local Arguments = {}

			if CachedClosures[NewProto.Id] ~= nil then
				local Cached = CachedClosures[NewProto.Id]

				NewProtoCode = Cached[1]
				Arguments = Cached[2]
				local NamesInvolved = Cached[3] 
				
				if NamesInvolved[CurrentName] ~= nil then
					table.insert(Codes, IndentPaste .. "local " .. CurrentName .. Code.A .. " = " .. CurrentName .. NamesInvolved[CurrentName])
				else
					if #NewProtoCode == 0 then
						table.insert(Codes, IndentPaste .. "local " .. CurrentName .. Code.A .. " = function" .. (#Arguments > 0 and " ( " .. table.concat(Arguments, " ") .. " )" or "()") .. " end" .. Info)
					else
						table.insert(Codes, IndentPaste .. "local " .. CurrentName .. Code.A .. " = function" .. (#Arguments > 0 and " ( " .. table.concat(Arguments, " ") .. " )" or "()") .. Info)
						table.insert(Codes, NewProtoCode)
						table.insert(Codes, IndentPaste .. "end")
					end
					
					NamesInvolved[CurrentName] = Code.A
					
					Cached = {NewProtoCode, Arguments, NamesInvolved}
				end

				Info = Info .. " --[[CACHED]]"
			else
				local NewProtoUpvalues = {}

				for Index1 = CodeIndex + 1, #MainProto.Code do
					local Code1 = MainProto.Code[Index1]

					if Code1.opname == "CAPTURE" then
						if Code1.A == 0 then --VAL
							table.insert(NewProtoUpvalues, Code1.B) 
						elseif Code1.A == 1 then --REF
							table.insert(NewProtoUpvalues, Code1.B)
						elseif Code1.A == 2 then --UPVAL
							table.insert(NewProtoUpvalues, Upvalues[Code1.B + 1])
						end
					else
						break
					end
				end

				local s, npc = pcall(_decompile, NewProto, ProtoTable, StringTable, Indent + 1, NewProtoUpvalues, ParentName)

				if s == false then
					print(npc)
					error("")
				end

				for Index = 1, NewProto.ParameterCount do
					table.insert(Arguments, CurrentName .. (Index - 1))
				end

				local Cached = {}
				Cached[1] = npc
				Cached[2] = Arguments
				Cached[3] = {[CurrentName] = Code.A}

				CachedClosures[NewProto.Id] = Cached

				NewProtoCode = npc
				
				if #NewProtoCode == 0 then
					table.insert(Codes, IndentPaste .. "local " .. CurrentName .. Code.A .. " = function" .. (#Arguments > 0 and " ( " .. table.concat(Arguments, " ") .. " )" or "()") .. " end" .. Info)
				else
					table.insert(Codes, IndentPaste .. "local " .. CurrentName .. Code.A .. " = function" .. (#Arguments > 0 and " ( " .. table.concat(Arguments, " ") .. " )" or "()") .. Info)
					table.insert(Codes, NewProtoCode)
					table.insert(Codes, IndentPaste .. "end")
				end
			end
		elseif Code.opname == "PREPVARARGS" then
		elseif Code.opname == "LOADKX" then
		elseif Code.opname == "JUMPX" then
		elseif Code.opname == "FASTCALL" then
		elseif Code.opname == "COVERAGE" then
		elseif Code.opname == "SUBRK" then
		elseif Code.opname == "DIVRK" then
		elseif Code.opname == "FASTCALL1" then
		elseif Code.opname == "FASTCALL2" then
		elseif Code.opname == "FASTCALL2K" then
		elseif Code.opname == "FORGPREP" then
		elseif Code.opname == "JUMPXEQKNIL" then
			table.insert(Codes, IndentPaste .. "if " .. CurrentName .. Code.A .. " == nil then")
			Indent += 1
			table.insert(Ends, CodeIndex + Code.D)
		elseif Code.opname == "JUMPXEQKB" then
			table.insert(Codes, IndentPaste .. "if " .. CurrentName .. Code.A .. " == " .. (Code.K == true and "true" or "false") .. " then")
			Indent += 1
			table.insert(Ends, CodeIndex + Code.D)
		elseif Code.opname == "JUMPXEQKN" then
			table.insert(Codes, IndentPaste .. "if " .. CurrentName .. Code.A .. " == " .. Code.K .. " then")
			Indent += 1
			table.insert(Ends, CodeIndex + Code.D)
		elseif Code.opname == "JUMPXEQKS" then
			table.insert(Codes, IndentPaste .. "if " .. CurrentName .. Code.A .. " == \"" .. Code.K .. "\" then")
			Indent += 1
			table.insert(Ends, CodeIndex + Code.D)
		elseif Code.opname == "IDIV" then
		elseif Code.opname == "IDIVK" then
		end
		
		if #Codes == OldLength then
			local Names = {
				"auxvalue",
				"RETURN"
			}

			if table.find(Names, Code.opname) == nil then
				print("Unsupported opcode detected:", Code.opname, Code)
			end
		end
	end

	return table.concat(Codes, "\n")
end

function Decompile(Bytecode)
	local Deserialized = Deserialize(Bytecode)
	local MainProto = Deserialized.MainProto
	local ProtoTable = Deserialized.ProtoList
	local StringTable = Deserialized.StringList

	local Start = tick()
	local Script = tostring(_decompile(MainProto, ProtoTable, StringTable, 0))
	local End = tick()
	local TimeTook = math.round((End - Start) * 100) / 100
	
	return "--[[\n  Decompiled using Ampersand, took " .. TimeTook .. " seconds]]\n\n" .. Script
end

return Decompile
