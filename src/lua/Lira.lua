if not (function()
        if gui == nil or gui.notify == nil then
            print("[Lira] environment error!")
            return false
        end
        if ffi == nil then
            gui.notify:add(gui.notification("Lira", "Lira requires insecure mode."))
            print("[Lira] Lira requires insecure mode.")
            return false
        end
        return true
    end)() then
    return
end


local NAME         = "Lira"
local VERSION      = "v1.7"
local DICTIONARY   = "Il"
local ID_LENGTH    = 5
local GROUP_A      = gui.ctx:find("lua>elements a")
local GROUP_B      = gui.ctx:find("lua>elements b")
local WHITE        = draw.color(255, 255, 255, 255)
local KEY_SPACE    = 0x20
local KEY_LBUTTON  = 0x01
local SND_ASYNC    = 0x0001
local SND_FILENAME = 0x00020000

local band         = bit.band
local bor          = bit.bor
local bxor         = bit.bxor
local rshift       = bit.rshift
local lshift       = bit.lshift
local rol          = bit.rol
local bnot         = bit.bnot

local function call(func, ...)
    func(...)
end

local GetAsyncKeyState = ffi.cast("short (__stdcall*)(int)", utils.find_export("user32.dll", "GetAsyncKeyState"))
local function isKeyDown(vkButton)
    return band(GetAsyncKeyState(vkButton), 0x8000) ~= 0
end

ffi.cdef [[
    typedef unsigned long DWORD;
    typedef int BOOL;
    typedef const char* LPCSTR;
    typedef void* HANDLE;
    typedef unsigned short WORD;
    typedef unsigned char BYTE;
    typedef char* LPSTR;
    typedef wchar_t* LPWSTR;
    typedef void* LPVOID;
    typedef const wchar_t* LPCWSTR;
    typedef struct _SECURITY_ATTRIBUTES {
        DWORD nLength;
        void* lpSecurityDescriptor;
        BOOL bInheritHandle;
    } SECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;
    BOOL CreateDirectoryA(LPCSTR lpPathName, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
    HANDLE CreateFileA(
        LPCSTR lpFileName,
        DWORD dwDesiredAccess,
        DWORD dwShareMode,
        LPSECURITY_ATTRIBUTES lpSecurityAttributes,
        DWORD dwCreationDisposition,
        DWORD dwFlagsAndAttributes,
        HANDLE hTemplateFile
    );
    BOOL ReadFile(
        HANDLE hFile,
        void* lpBuffer,
        DWORD nNumberOfBytesToRead,
        DWORD* lpNumberOfBytesRead,
        void* lpOverlapped
    );
    BOOL WriteFile(
        HANDLE hFile,
        const void* lpBuffer,
        DWORD nNumberOfBytesToWrite,
        DWORD* lpNumberOfBytesWritten,
        void* lpOverlapped
    );
    BOOL CloseHandle(HANDLE hObject);
    DWORD GetFileSize(HANDLE hFile, DWORD* lpFileSizeHigh);
    BOOL GetFileAttributesExA(
        LPCSTR lpFileName,
        int fInfoLevelId,
        void* lpFileInformation
    );
    BOOL DeleteFileA(LPCSTR lpFileName);
    DWORD GetLastError();
    DWORD GetModuleFileNameA(HANDLE hModule, LPSTR lpFilename, DWORD nSize);
    HANDLE GetModuleHandleA(LPCSTR lpModuleName);
    HANDLE FindFirstFileA(LPCSTR lpFileName, void* lpFindFileData);
    BOOL FindNextFileA(HANDLE hFindFile, void* lpFindFileData);
    BOOL FindClose(HANDLE hFindFile);
    HANDLE CreateToolhelp32Snapshot(DWORD dwFlags, DWORD th32ProcessID);
    BOOL Process32First(HANDLE hSnapshot, void* lppe);
    BOOL Process32Next(HANDLE hSnapshot, void* lppe);
    HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId);
    DWORD GetProcessImageFileNameA(HANDLE hProcess, LPSTR lpImageFileName, DWORD nSize);
    DWORD GetFileAttributesA(LPCSTR lpFileName);
    BOOL RemoveDirectoryA(LPCSTR lpPathName);
]]
local GENERIC_READ = 0x80000000
local GENERIC_WRITE = 0x40000000
local FILE_SHARE_READ = 0x00000001
local FILE_SHARE_WRITE = 0x00000002
local OPEN_EXISTING = 3
local CREATE_ALWAYS = 2
local FILE_ATTRIBUTE_NORMAL = 0x80
local INVALID_HANDLE_VALUE = ffi.cast("void*", -1)
local MAX_PATH = 260
local FILE_ATTRIBUTE_DIRECTORY = 0x10
local INVALID_FILE_ATTRIBUTES = 0xFFFFFFFF
local get_module_handle_addr = utils.find_export("kernel32.dll", "GetModuleHandleA")
if get_module_handle_addr == 0 then
    error("无法获取GetModuleHandleA函数")
end
local CreateDirectoryA = utils.find_export("kernel32.dll", "CreateDirectoryA")
local CreateFileA = utils.find_export("kernel32.dll", "CreateFileA")
local ReadFile = utils.find_export("kernel32.dll", "ReadFile")
local WriteFile = utils.find_export("kernel32.dll", "WriteFile")
local CloseHandle = utils.find_export("kernel32.dll", "CloseHandle")
local GetFileSize = utils.find_export("kernel32.dll", "GetFileSize")
local DeleteFileA = utils.find_export("kernel32.dll", "DeleteFileA")
local GetModuleFileNameA = utils.find_export("kernel32.dll", "GetModuleFileNameA")
local GetFileAttributesA = utils.find_export("kernel32.dll", "GetFileAttributesA")
local RemoveDirectoryA = utils.find_export("kernel32.dll", "RemoveDirectoryA")
local CRC32_TABLE = {}
local function init_crc32_table()
    for i = 0, 255 do
        local crc = i
        for j = 0, 7 do
            if bit.band(crc, 1) ~= 0 then
                crc = bit.bxor(bit.rshift(crc, 1), 0xEDB88320)
            else
                crc = bit.rshift(crc, 1)
            end
        end
        CRC32_TABLE[i] = crc
    end
end
init_crc32_table()
--文件系统
local files = {}
-- 创建文件夹
function files.create_folder(path)
    local create_dir_fn = ffi.cast("BOOL(__stdcall*)(LPCSTR, LPSECURITY_ATTRIBUTES)", CreateDirectoryA)
    local result = create_dir_fn(path, nil)
    return result ~= 0
end

-- 读取文件
function files.read(path)
    local create_file_fn = ffi.cast(
        "HANDLE(__stdcall*)(LPCSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE)", CreateFileA)
    local read_file_fn = ffi.cast("BOOL(__stdcall*)(HANDLE, void*, DWORD, DWORD*, void*)", ReadFile)
    local get_file_size_fn = ffi.cast("DWORD(__stdcall*)(HANDLE, DWORD*)", GetFileSize)
    local close_handle_fn = ffi.cast("BOOL(__stdcall*)(HANDLE)", CloseHandle)
    local handle = create_file_fn(path, GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nil)
    if handle == INVALID_HANDLE_VALUE then
        return nil
    end
    local size = get_file_size_fn(handle, nil)
    if size == 0xFFFFFFFF then
        close_handle_fn(handle)
        return nil
    end
    local buffer = ffi.new("uint8_t[?]", size + 1)
    local bytes_read = ffi.new("DWORD[1]")
    local success = read_file_fn(handle, buffer, size, bytes_read, nil)
    close_handle_fn(handle)
    if not success or bytes_read[0] ~= size then
        return nil
    end
    buffer[size] = 0
    return ffi.string(buffer, size)
end

-- 写入文件
function files.write(path, data)
    local create_file_fn = ffi.cast(
        "HANDLE(__stdcall*)(LPCSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE)", CreateFileA)
    local write_file_fn = ffi.cast("BOOL(__stdcall*)(HANDLE, const void*, DWORD, DWORD*, void*)", WriteFile)
    local close_handle_fn = ffi.cast("BOOL(__stdcall*)(HANDLE)", CloseHandle)
    local handle = create_file_fn(path, GENERIC_WRITE, FILE_SHARE_WRITE, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nil)
    if handle == INVALID_HANDLE_VALUE then
        return false
    end
    local bytes_written = ffi.new("DWORD[1]")
    local success = write_file_fn(handle, data, #data, bytes_written, nil)
    close_handle_fn(handle)
    return success ~= 0 and bytes_written[0] == #data
end

-- 获取文件CRC32校验和
function files.get_crc32(data)
    local crc = 0xFFFFFFFF
    for i = 1, #data do
        local byte = string.byte(data, i)
        crc = bit.bxor(bit.rshift(crc, 8), CRC32_TABLE[bit.band(bit.bxor(crc, byte), 0xFF)])
    end
    return bit.bxor(crc, 0xFFFFFFFF)
end

-- 判断文件是否存在
function files.file_exists(path)
    local get_attributes_fn = ffi.cast("DWORD(__stdcall*)(LPCSTR)", GetFileAttributesA)
    local attrs = get_attributes_fn(path)
    if attrs == INVALID_FILE_ATTRIBUTES then
        return false
    end
    return bit.band(attrs, FILE_ATTRIBUTE_DIRECTORY) == 0
end

-- 判断文件夹是否存在
function files.folder_exists(path)
    local get_attributes_fn = ffi.cast("DWORD(__stdcall*)(LPCSTR)", GetFileAttributesA)
    local attrs = get_attributes_fn(path)
    if attrs == INVALID_FILE_ATTRIBUTES then
        return false
    end
    return bit.band(attrs, FILE_ATTRIBUTE_DIRECTORY) ~= 0
end

-- 删除文件
function files.delete_file(path)
    local delete_file_fn = ffi.cast("BOOL(__stdcall*)(LPCSTR)", DeleteFileA)
    local result = delete_file_fn(path)
    return result ~= 0
end

-- 删除文件夹
function files.delete_folder(path)
    local remove_dir_fn = ffi.cast("BOOL(__stdcall*)(LPCSTR)", RemoveDirectoryA)
    local result = remove_dir_fn(path)
    return result ~= 0
end

--获取当前运行目录/cs2.exe的运行目录
function files.get_current_directory()
    local get_module_filename_fn = ffi.cast("DWORD(__stdcall*)(HANDLE, LPSTR, DWORD)", GetModuleFileNameA)
    local buffer = ffi.new("char[?]", MAX_PATH)
    local length = get_module_filename_fn(nil, buffer, MAX_PATH)
    if length == 0 then
        return nil
    end
    local path = ffi.string(buffer, length)
    local last_slash = string.find(path, "\\[^\\]*$")
    if last_slash then
        return string.sub(path, 1, last_slash)
    end
    return path
end

--获取脚本目录
function files.get_script_directory()
    local current_dir = files.get_current_directory()
    if not current_dir then
        return nil
    end
    local base_path = current_dir
    local pos = string.find(base_path:lower(), "game\\bin\\win64")
    if pos then
        local game_pos = string.find(base_path:lower(), "game", pos)
        if game_pos then
            local base_game_path = string.sub(base_path, 1, game_pos + 3) -- +3是"game"的长度
            return base_game_path .. "\\csgo\\fatality\\scripts\\"
        end
    end
    return current_dir
end

ffi.cdef [[
typedef struct {
    float x, y, z;
} QAngle;

typedef unsigned long DWORD;
typedef int BOOL;
typedef char CHAR;
typedef const char* LPCSTR;
typedef void* HANDLE;
typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
} FILETIME, *PFILETIME, *LPFILETIME;
typedef struct _WIN32_FIND_DATAA {
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
    DWORD    dwReserved0;
    DWORD    dwReserved1;
    CHAR     cFileName[260];
    CHAR     cAlternateFileName[14];
    DWORD    dwFileType; // Obsolete. Do not use.
    DWORD    dwCreatorType; // Obsolete. Do not use
    WORD     wFinderFlags; // Obsolete. Do not use
} WIN32_FIND_DATAA, *PWIN32_FIND_DATAA, *LPWIN32_FIND_DATAA;
]]

-- HANDLE FindFirstFileA(LPCSTR lpFileName, WIN32_FIND_DATAA* lpFindFileData);
local FindFirstFileA = ffi.cast("void*(__stdcall*)(const char*, void*)",
    utils.find_export("kernel32.dll", "FindFirstFileA"))
-- BOOL FindNextFileA(HANDLE hFindFile, WIN32_FIND_DATAA* lpFindFileData);
local FindNextFileA = ffi.cast("bool(__stdcall*)(void*, void*)", utils.find_export("kernel32.dll", "FindNextFileA"))
-- BOOL FindClose(HANDLE hFindFile);
local FindClose = ffi.cast("bool(__stdcall*)(void*)", utils.find_export("kernel32.dll", "FindClose"))
-- bool PlaySoundA(const char* pszSound, void* hmod, unsigned int fdwSound);
local PlaySoundA = ffi.cast("bool(__stdcall*)(const char*, void*, uint32_t)",
    utils.find_export("winmm.dll", "PlaySoundA"))
local function listFiles(dir)
    local files = {}
    local data = ffi.new("WIN32_FIND_DATAA")

    local path = dir or ".\\?"

    local handle = FindFirstFileA(path, data)
    if handle == ffi.cast("void*", -1) then
        return nil, "FindFirstFileA failed"
    end

    repeat
        local name = ffi.string(data.cFileName)
        if name ~= "." and name ~= ".." then
            table.insert(files, name)
        end
    until not FindNextFileA(handle, data)

    FindClose(handle)
    return files
end
local function playSound(filename)
    PlaySoundA(filename, nil, SND_ASYNC + SND_FILENAME)
end

local Backend_connected = false
local function Backend_send(msg)
end
local function Backend_read()
end
local function Backend_close()
end
call(function ()
    local CreateFileA = ffi.cast("HANDLE(__stdcall*)(LPCSTR, DWORD, DWORD, LPVOID, DWORD, DWORD, HANDLE)", utils.find_export("kernel32.dll", "CreateFileA"))
    local WriteFile = ffi.cast("BOOL(__stdcall*)(HANDLE, LPCSTR, DWORD, DWORD*, LPVOID)", utils.find_export("kernel32.dll", "WriteFile"))
    local ReadFile = ffi.cast("BOOL(__stdcall*)(HANDLE, LPVOID, DWORD, DWORD*, LPVOID)", utils.find_export("kernel32.dll", "ReadFile"))
    local CloseHandle = ffi.cast("BOOL(__stdcall*)(HANDLE)", utils.find_export("kernel32.dll", "CloseHandle"))

    local BACKEND_PIPE = "\\\\.\\pipe\\LiraFABackend"
    local pipe_cstr = ffi.new("const char[?]", #BACKEND_PIPE + 1, BACKEND_PIPE)

    local handle = CreateFileA(
        pipe_cstr,
        bor(GENERIC_READ, GENERIC_WRITE),
        0, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nil
    )

    if handle == ffi.cast("HANDLE", -1) then
        gui.notify:add(gui.notification(NAME, "Failed to connect backend, some features are unavailable."))
        print("[Lira] Failed to connect backend, some features are unavailable.")
        return
    end

    Backend_send = function (msg)
        msg = msg .. "\n"
        local c_msg = ffi.new("const char[?]", #msg, msg)
        local written = ffi.new("DWORD[1]")
        WriteFile(handle, c_msg, #msg, written, nil)
    end

    Backend_read = function ()
        local buffer = ffi.new("char[4096]")
        local read = ffi.new("DWORD[1]")
        assert(ReadFile(handle, buffer, 4096, read, nil) ~= 0)

        local response = ffi.string(buffer, read[0])
        return response
    end

    Backend_close = function ()
        CloseHandle(handle)
    end

    Backend_connected = true
end)

math.randomseed(game.global_vars.real_time)
mods.events:add_listener("player_death")
mods.events:add_listener("player_spawn")
local function shuffleString(str)
    local chars = {}
    for i = 1, #str do
        chars[i] = str:sub(i, i)
    end

    for i = #chars, 2, -1 do
        local j = math.random(i)
        chars[i], chars[j] = chars[j], chars[i]
    end

    return table.concat(chars)
end
local function normalize(id)
    return NAME .. "_" .. id
end
local function sendChat(text)
    game.engine:client_cmd("say \"" .. text .. "\"")
end
local function sendNoti(title, message)
    gui.notify:add(gui.notification(title, message))
    if title == "Lira" then
        print("[Lira] " .. message)
    else
        print("[Lira] [" .. title .. "] " .. message)
    end
end
local function normalizeYaw(angle)
    return (angle % 360 + 360) % 360
end
local function getDirection(deltaMovement, yaw)
    -- 标准化 yaw
    yaw            = normalizeYaw(yaw)

    local rad      = math.rad(yaw)
    local forwardX = math.cos(rad)
    local forwardY = math.sin(rad)
    local rightX   = math.cos(rad - math.pi / 2)
    local rightY   = math.sin(rad - math.pi / 2)

    local motionX  = deltaMovement.x
    local motionY  = deltaMovement.y

    local forward  = motionX * forwardX + motionY * forwardY
    local strafe   = motionX * rightX + motionY * rightY

    return { forward = forward, strafe = strafe }
end
local function getSpeed(deltaMovement)
    local motionX = deltaMovement.x
    local motionY = deltaMovement.y
    return math.sqrt(motionX * motionX + motionY * motionY)
end
local function fixSlider(min, max)
    min = min:get_value()
    max = max:get_value()
    if min:get() > max:get() then
        local value = min:get()
        min:set(max:get())
        max:set(value)
    end
end
local function addDependsCustom(control, depend, dependLambda)
    control.inactive = not dependLambda()
    depend:add_callback(function()
        control.inactive = not dependLambda()
    end)
end
local function addDepends(control, depend)
    addDependsCustom(control, depend, function()
        return (not depend.inactive) or depend:get_value():get()
    end)
end
local function tern(cond, ifTrue, ifFalse)
    if cond then
        return ifTrue
    end
    return ifFalse
end
local function isInAir(player)
    local lp = player or entities.get_local_pawn()
    if lp == nil then return false end
    local m_fFlags = lp['m_fFlags']:get()
    if m_fFlags == 65664 then
        return true
    end
    return false
end
local function isT(player)
    local lp = player or entities.get_local_pawn()
    if lp == nil then return false end
    local m_iTeamNum = lp["m_iTeamNum"]:get()
    return m_iTeamNum == 2
end
local function isCT(player)
    local lp = player or entities.get_local_pawn()
    if lp == nil then return false end
    local m_iTeamNum = lp["m_iTeamNum"]:get()
    return m_iTeamNum == 3
end
local function getSensitivity(player)
    local lp = player or entities.get_local_pawn()
    if lp == nil then return false end
    local m_flMouseSensitivity = lp["m_flMouseSensitivity"]:get()
    return tern(m_flMouseSensitivity ~= nil, m_flMouseSensitivity, 1)
end
local function isSneaking(player)
    local lp = player or entities.get_local_pawn()
    if lp == nil then return false end
    local m_fFlags = lp['m_fFlags']:get()
    if m_fFlags == 65666 or m_fFlags == 65667 then
        return true
    end
    return false
end
-- local function getRotation(entity)
--     local cData = entity.v_angle:get()
--     local qAngle = ffi.cast("QAngle", cData)
--     return vector(qAngle.x, qAngle.y, qAngle.z)
-- end
local function getYawDiff(from, to)
    from = normalizeYaw(from)
    to = normalizeYaw(to)
    local diff1 = to - from
    local diff2 = from + (360 - to)
    if math.abs(diff1) <= math.abs(diff2) then
        return diff1
    else
        return diff2
    end
end
local function limit(value, min, max)
    if value < min then
        return min
    end
    if value > max then
        return max
    end
    return value
end
local function toraw(index)
    return 2 ^ (index - 1)
end
local function fromraw(value)
    return math.log(value, 2) + 1
end
local function setComboBox(comboBox, value)
    local bits = comboBox:get_value():get()
    bits:reset()
    bits:set_raw(toraw(value))
    comboBox:get_value():set(bits)
end
local function isSelected(comboBox, modeIndex) -- index从0开始数！
    local selected = comboBox:get_value():get():get_raw()
    return bit.band(selected, bit.lshift(1, modeIndex)) ~= 0
end
local function listFromFill(size, value)
    local result = {}
    for _ = 1, size do
        table.insert(result, value)
    end
    return result
end
local function posEqualsFull(pos1, pos2)
    return pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z
end
local function posEquals(pos1, pos2)
    return math.abs(pos1.x - pos2.x) < 1e-5
        and math.abs(pos1.y - pos2.y) < 1e-5
        and math.abs(pos1.z - pos2.z) < 1e-5
end
local function posToString(pos)
    return "{x=" .. pos.x .. ", y=" .. pos.y .. ", z=" .. pos.z .. "}"
end
local function rotEqualsFull(rot1, rot2)
    return rot1.yaw == rot2.yaw and rot1.pitch == rot2.pitch and rot1.roll == rot2.roll
end
local function rotEquals(rot1, rot2, inc)
    local fixedInc = inc or 1e-5
    return math.abs(rot1.yaw - rot2.yaw) < fixedInc
        and math.abs(rot1.pitch - rot2.pitch) < fixedInc
        and math.abs(rot1.roll - rot2.roll) < fixedInc
end
local function rotToString(rot)
    return "{yaw=" .. rot.yaw .. ", pitch=" .. rot.pitch .. ", roll=" .. rot.roll .. "}"
end
local function arrayToString(arr, size)
    local length = tern(size ~= nil, size, #arr)
    if length == 0 then
        return ""
    end
    local result = "{" .. tostring(arr[1])
    for i = 2, length do
        result = result .. ", " .. tostring(arr[i])
    end
    return result .. "}"
end
local function endswith(str, suffix)
    return suffix == "" or string.sub(str, -string.len(suffix)) == suffix
end
-- 计算两个向量的点积
local function dot(v1, v2)
    return v1.x * v2.x + v1.y * v2.y +
        v1.z *
        v2.z -- 定义如 Wikipedia 所示：∑ v1_i * v2_i&#8203;:contentReference[oaicite:3]{index=3}
end
-- 计算向量的模长
local function length(v)
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) -- 模长定义为 sqrt(x²+y²+z²)&#8203;:contentReference[oaicite:4]{index=4}
end
-- 计算两个向量之间的夹角（弧度）
local function angleBetween(v1, v2)
    local dotProd = dot(v1, v2)
    local lens    = length(v1) * length(v2)
    local cosA    = dotProd / lens -- 等价于 Java 中的 dot/(len1*len2)&#8203;:contentReference[oaicite:5]{index=5}

    -- 裁剪到 [-1,1]，避免 math.acos 返回 NaN&#8203;:contentReference[oaicite:6]{index=6}
    if cosA > 1 then cosA = 1 end
    if cosA < -1 then cosA = -1 end

    return math.acos(cosA) -- Lua math.acos 返回弧度&#8203;:contentReference[oaicite:7]{index=7}
end
local function directionFromYawPitch(yaw, pitch)
    -- 将度数转为弧度，并修正坐标系
    local yawRad   = math.rad(-yaw)
    local pitchRad = math.rad(-pitch)

    local x        = math.sin(yawRad) * math.cos(pitchRad)
    local y        = math.sin(pitchRad)
    local z        = math.cos(yawRad) * math.cos(pitchRad)

    -- 单位化
    local len      = math.sqrt(x * x + y * y + z * z)
    return { x = x / len, y = y / len, z = z / len }
end
local function takakoGetAngle(rotation, eyePos, targetPos)
    local toTarget = {
        x = targetPos.x - eyePos.x,
        y = targetPos.y - eyePos.y,
        z = targetPos.z - eyePos.z
    }
    local lookDir = directionFromYawPitch(rotation.yaw, rotation.pitch)

    return angleBetween(lookDir, toTarget)
end
local function getRotation(from, to)
    local diffX = to.x - from.x
    local diffY = to.y - from.y
    local diffZ = to.z - from.z
    local diffXY = math.sqrt(diffX * diffX + diffY * diffY)

    ---@diagnostic disable-next-line: deprecated
    local yaw = math.deg(math.atan2(diffY, diffX))
    ---@diagnostic disable-next-line: deprecated
    local pitch = -math.deg(math.atan2(diffZ, diffXY))

    return { yaw = yaw, pitch = pitch }
end
-- computeMaxSpreadOffsets(spread, inaccuracy) → yawRange, pitchRange
-- @param spread     武器 spread 值（sin(θ/2) 形式）
-- @param inaccuracy 当前 inaccuracy 值 I
local function computeMaxSpreadOffsets(spread, inaccuracy)
    -- 1) spread → 半锥角（弧度）
    --    spread = sin(θ/2) → halfCone_spread = θ/2 = asin(spread)
    local halfCone_spread = math.asin(spread) --

    -- 2) inaccuracy → 半锥角（弧度）
    --    AccurateRange R = 152.4 / I （米），在 R 处散布直径 0.3m → β/2 = atan(0.15·I/152.4)
    local halfCone_inac = math.atan((0.15 * inaccuracy) / 152.4) --

    -- 3) 合并最坏情况半锥角（弧度）
    local halfCone_total = halfCone_spread + halfCone_inac

    -- 4) 转为度数：deg = rad × (180/π)
    local halfCone_deg = halfCone_total * (180 / math.pi) --

    -- 返回对称范围
    return halfCone_deg
end
local function gaussianRandom()
    local u1, u2 = math.random(), math.random()
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local to32 = function(x) return band(x, 0xFFFFFFFF) end
--—— ChaCha20 “quarter round” ——--
local function quarterround(state, a, b, c, d)
    state[a] = to32(state[a] + state[b]); state[d] = rol(bxor(state[d], state[a]), 16)
    state[c] = to32(state[c] + state[d]); state[b] = rol(bxor(state[b], state[c]), 12)
    state[a] = to32(state[a] + state[b]); state[d] = rol(bxor(state[d], state[a]), 8)
    state[c] = to32(state[c] + state[d]); state[b] = rol(bxor(state[b], state[c]), 7)
end

--—— ChaCha20 一个 block 函数 ——--
local function chacha20_block(key, counter, nonce)
    -- 常量："expand 32-byte k"
    local state = {
        0x61707865, 0x3320646E, 0x79622D32, 0x6B206574,
        -- key: 8×32‑bit words
        key[1], key[2], key[3], key[4],
        key[5], key[6], key[7], key[8],
        -- counter 和 nonce: 1×32‑bit counter + 3×32‑bit nonce
        to32(counter),
        nonce[1], nonce[2], nonce[3],
    }
    local working = { unpack(state) }
    -- 20 rounds = 10 × (column round + diagonal round)
    for i = 1, 10 do
        -- column rounds
        quarterround(working, 1, 5, 9, 13)
        quarterround(working, 2, 6, 10, 14)
        quarterround(working, 3, 7, 11, 15)
        quarterround(working, 4, 8, 12, 16)
        -- diagonal rounds
        quarterround(working, 1, 6, 11, 16)
        quarterround(working, 2, 7, 12, 13)
        quarterround(working, 3, 8, 9, 14)
        quarterround(working, 4, 5, 10, 15)
    end
    -- state + working, 输出 64 字节
    local out = {}
    for i = 1, 16 do
        local v = to32(working[i] + state[i])
        -- 拆成 4 字节小端
        out[#out + 1] = string.char(band(v, 0xFF))
        out[#out + 1] = string.char(band(rshift(v, 8), 0xFF))
        out[#out + 1] = string.char(band(rshift(v, 16), 0xFF))
        out[#out + 1] = string.char(band(rshift(v, 24), 0xFF))
    end
    return table.concat(out)
end

--—— 简单 FNV-1a 32-bit 哈希 ——--
local function fnv1a32(data)
    local hash = 2166136261
    for i = 1, #data do
        hash = to32(bxor(hash, data:byte(i)))
        hash = to32(hash * 16777619)
    end
    return hash
end

--—— 从 game.global_vars_* 收集熵 ——--
local function collect_entropy()
    local gv = game.global_vars
    local fields = {
        gv.real_time, gv.frame_count, gv.abs_frame_time, gv.max_clients,
        gv.ticks_this_frame, gv.frame_time, gv.cur_time,
        gv.tick_fraction, gv.tick_count, math.random()
    }
    -- 将每个数字按小端 4 字节写入字符串
    local s = {}
    for _, v in ipairs(fields) do
        local x = to32(math.floor(v * 1e6))
        s[#s + 1] = string.char(
            band(x, 0xFF),
            band(rshift(x, 8), 0xFF),
            band(rshift(x, 16), 0xFF),
            band(rshift(x, 24), 0xFF)
        )
    end
    return table.concat(s)
end

--—— 初始化 ChaCha20 密钥（8×32-bit）和随机 nonce ——--
local function init_state()
    local entropy = collect_entropy()
    local key = {}
    for i = 1, 8 do
        -- 生成新熵块
        local h = fnv1a32(entropy)
        entropy = string.char(
            band(h, 0xFF),
            band(rshift(h, 8), 0xFF),
            band(rshift(h, 16), 0xFF),
            band(rshift(h, 24), 0xFF)
        )
        key[i] = h
    end
    -- nonce: 基于最后熵派生出三个值
    local base = fnv1a32(entropy)
    local nonce = {
        base,
        bxor(base, 0xA5A5A5A5),
        band(bnot(base), 0xFFFFFFFF)
    }
    return key, nonce
end
--- 当前离传入yaw最近的目标pawn（如果有）
--- @param yaw number 一般是准心yaw
--- @return any? 目标pawn对象
local function getTargetNearYaw(yaw)
    local self = entities:get_local_pawn()
    if self == nil then
        return nil
    end

    local minDelta = 999999
    local result = nil

    local startPos = self:get_abs_origin()
    entities.players:for_each(function(entry)
        local entity = entry.entity
        if (entity == nil) then
            return
        end
        if (entity == self) or (not entity:is_enemy()) then
            return
        end
        local curYaw = getRotation(startPos, entity:get_abs_origin()).yaw
        local delta = math.abs(normalizeYaw(yaw) - normalizeYaw(curYaw))
        delta = math.min(delta, 360 - delta)

        if delta < minDelta then
            minDelta = delta
            result = entity
        end
    end)

    return result
end
local _matrixStack = {}
local function pushMatrix()
    local context = draw.surface.g
    table.insert(_matrixStack, {
        texture = context.texture,
        frag_shader = context.frag_shader,
        alpha = context.alpha,
        rotation = context.rotation,
        anti_alias = context.anti_alias
    })
end
local function popMatrix()
    local context = draw.surface.g
    local matrix = table.remove(_matrixStack, #_matrixStack)
    context.texture = matrix.texture
    context.frag_shader = matrix.frag_shader
    context.alpha = matrix.alpha
    context.rotation = matrix.rotation
    context.anti_alias = matrix.anti_alias
end

local LRUCache = {}
LRUCache.__index = LRUCache

-- 构造函数
function LRUCache.new(capacity)
    local self = setmetatable({}, LRUCache)
    self.capacity = capacity
    self.cache = {} -- 哈希表存储缓存
    self.order = {} -- 双向链表维护元素顺序
    self.size = 0
    return self
end

-- 移动节点到链表的头部（表示最近使用）
local function move_to_front(self, key)
    -- 从链表中移除节点并移动到最前
    local index = self.cache[key]
    table.remove(self.order, index)
    table.insert(self.order, 1, key)
    -- 更新哈希表中的位置
    self.cache[key] = 1
end

-- 获取缓存中的值
function LRUCache:get(key)
    if not self.cache[key] then
        return nil
    end
    -- 移动到最近使用
    move_to_front(self, key)
    return self[key]
end

-- 插入一个新值或更新已存在值
function LRUCache:set(key, value)
    if not self.cache[key] then
        if self.size >= self.capacity then
            -- 删除最久未使用的元素
            local least_used_key = self.order[self.capacity]
            self.cache[least_used_key] = nil
            self[least_used_key] = nil
            table.remove(self.order, self.capacity)
            self.size = self.size - 1
        end
        -- 插入新的缓存项
        self.size = self.size + 1
        self.cache[key] = 1
        self[key] = value
        table.insert(self.order, 1, key)
    else
        -- 更新已存在值，并移动到头部
        self[key] = value
        move_to_front(self, key)
    end
end

-- 返回一个迭代器
function LRUCache:iter()
    local index = 0
    local size = self.size
    return function()
        index = index + 1
        if index <= size then
            local key = self.order[index]
            return key, self[key]
        end
    end
end

-- DICTIONARY = shuffleString(DICTIONARY)
local DICT_SIZE = #DICTIONARY
local NameGenerator_length = ID_LENGTH
local NameGenerator_counters = listFromFill(ID_LENGTH, 0)
local function NameGenerator_incrementCounters()
    local i = NameGenerator_length
    while i >= 1 do
        NameGenerator_counters[i] = NameGenerator_counters[i] + 1
        if NameGenerator_counters[i] < DICT_SIZE then
            return
        end
        NameGenerator_counters[i] = 0
        i = i - 1
    end

    NameGenerator_length = NameGenerator_length + 1
    NameGenerator_counters[NameGenerator_length] = 0
    -- DICTIONARY = shuffleString(DICTIONARY)
end
local function NameGenerator_generate()
    local chars = {}
    for i = 1, NameGenerator_length do
        local index = NameGenerator_counters[i] or 0
        chars[i] = DICTIONARY:sub(index + 1, index + 1)
    end

    NameGenerator_incrementCounters()
    return table.concat(chars)
end

local SecureRandom = {}
SecureRandom.__index = SecureRandom

function SecureRandom.new()
    local key, nonce = init_state()
    return setmetatable({
        key     = key,
        nonce   = nonce,
        counter = 0,
    }, SecureRandom)
end

-- 产生 n 字节随机流
function SecureRandom:random_bytes(n)
    local out = {}
    while n > 0 do
        local block = chacha20_block(self.key, self.counter, self.nonce)
        self.counter = to32(self.counter + 1)
        if n >= 64 then
            out[#out + 1] = block
            n = n - 64
        else
            out[#out + 1] = block:sub(1, n)
            break
        end
    end
    return table.concat(out)
end

-- 产生一个 0≤x<1 的浮点数
function SecureRandom:random()
    -- 取 6 字节，构造一个 48-bit 整数，再除以 2^48
    local bytes = self:random_bytes(6)
    local x = 0
    for i = 1, 6 do
        x = x * 256 + bytes:byte(i)
    end
    return x / 2 ^ 48
end

-- 产生 [lower,upper] 之间的整数
function SecureRandom:random_int(lower, upper)
    lower = lower or 0
    upper = upper or 0xFFFFFFFF
    local range = upper - lower + 1
    -- 拒绝采样避免偏差
    local bits = math.ceil(math.log(range, 2))
    local bytes = math.ceil(bits / 8)
    while true do
        local data = self:random_bytes(bytes)
        local v = 0
        for i = 1, bytes do v = v * 256 + data:byte(i) end
        if v < range * math.floor(2 ^ (8 * bytes) / range) then
            return lower + (v % range)
        end
    end
end

local ContextualRandom = {}
ContextualRandom.__index = ContextualRandom

-- 构造器：可选参数控制各隐变量初始规模
function ContextualRandom.new(opts)
    opts = opts or {}
    local self = setmetatable({
        x        = 0.5,                  -- 上一次输出
        mu       = 0.5,                  -- 漂移的中心
        trend    = 0,                    -- 当前趋势
        sigma    = opts.sigma or 0.05,   -- 随机冲击幅度
        theta    = opts.theta or 0.1,    -- 回归速率：x→mu
        drift    = opts.drift or 0.01,   -- mu 自身漂移速率
        momentum = opts.momentum or 0.8, -- 趋势惯性
        baseRng  = opts.baseRng or SecureRandom.new()
    }, ContextualRandom)
    return self
end

-- 生成下一个随机值
function ContextualRandom:random()
    -- 1) 中心 μ 轻微漂移
    local dmu = (self.baseRng:random() - 0.5) * self.drift
    self.mu = self.mu + dmu

    -- 2) 趋势 trend 加上冲击并保留动量
    local shock = (self.baseRng:random() - 0.5) * self.sigma
    self.trend = self.trend * self.momentum + shock

    -- 3) 基于 Ornstein–Uhlenbeck 型过程更新 x
    local dx = self.theta * (self.mu - self.x) + self.trend
    self.x = self.x + dx

    -- 4) 边界处理，保持 x ∈ [0,1)
    if self.x < 0 then
        self.x = -self.x; self.trend = -self.trend
    end
    if self.x >= 1 then
        self.x = 2 - self.x
        self.trend = -self.trend
    end

    return self.x
end

-- 生成整数 [a,b]
function ContextualRandom:random_int(a, b)
    a = a or 0; b = b or 1
    local r = self:random()
    return math.floor(a + r * (b - a + 1))
end

local function addSpace(group)
    group:add(gui.spacer(gui.control_id(normalize(NameGenerator_generate()))))
    group:reset()
end
local function addLabel(group, value, color)
    local label = gui.label(
        gui.control_id(normalize(NameGenerator_generate())),
        value,
        color or WHITE,
        true
    )
    addSpace(group)
    group:add(label)
    group:reset()
end
local function newCheckbox(group, name, defaultValue)
    local checkbox = gui.checkbox(gui.control_id(normalize(NameGenerator_generate())))
    checkbox:set_value(defaultValue or false)
    local wrapper = gui.make_control(name, checkbox)
    group:add(wrapper)
    group:reset()
    return checkbox
end
local function newComboBox(group, name, options, defaultValue)
    local comboBox = gui.combo_box(gui.control_id(normalize(NameGenerator_generate())))
    for _, option in ipairs(options) do
        comboBox:add(gui.selectable(
            gui.control_id(normalize(NameGenerator_generate())),
            option
        ))
    end
    if defaultValue ~= nil then
        setComboBox(comboBox, defaultValue)
    end
    local wrapper = gui.make_control(name, comboBox)
    group:add(wrapper)
    group:reset()
    return comboBox
end
local function newMultiBox(group, name, options, defaultValue)
    local comboBox = gui.combo_box(gui.control_id(normalize(NameGenerator_generate())))
    comboBox.allow_multiple = true
    for _, option in ipairs(options) do
        comboBox:add(gui.selectable(
            gui.control_id(normalize(NameGenerator_generate())),
            option
        ))
    end
    if defaultValue ~= nil then
        setComboBox(comboBox, defaultValue)
    end
    local wrapper = gui.make_control(name, comboBox)
    group:add(wrapper)
    group:reset()
    return comboBox
end
local function newSlider(group, name, defaultValue, min, max, inc, format)
    local slider = gui.slider(
        gui.control_id(normalize(NameGenerator_generate())),
        min, max, { tern(format ~= nil, format, "%.0f") }, inc
    )
    slider:get_value():set(defaultValue)
    local wrapper = gui.make_control(name, slider)
    group:add(wrapper)
    group:reset()
    return slider
end
local function newTextInput(group, name, defaultValue)
    local textInput = gui.text_input(gui.control_id(normalize(NameGenerator_generate())))
    if defaultValue ~= nil then
        textInput:set_value(defaultValue)
    end
    local wrapper = gui.make_control(name, textInput)
    group:add(wrapper)
    group:reset()
    return textInput
end
local function newButton(group, name, buttonName)
    local button = gui.button(
        gui.control_id(normalize(NameGenerator_generate())),
        buttonName
    )
    local wrapper = gui.make_control(name, button)
    group:add(wrapper)
    group:reset()
    return button
end

local lastPosition = { x = 0, y = 0, z = 0 }
local position = { x = 0, y = 0, z = 0 } -- z轴是垂直轴
local lastYaw = 0
local yaw = 0
local deltaMovement = { x = 0, y = 0, z = 0 }
local ticksExisted = -1
events.create_move:add(function(cmd)
    local local_player = entities.get_local_pawn()
    ticksExisted = ticksExisted + 1
    if posEquals(position, { x = 0, y = 0, z = 0 }) and posEquals(lastPosition, { x = 0, y = 0, z = 0 }) then
        position = local_player:get_abs_origin()
        lastPosition = position
    else
        lastPosition = position
        position = local_player:get_abs_origin()
    end
    if yaw == 0 and lastYaw == 0 then
        yaw = local_player:get_abs_angles().y
        lastYaw = yaw
    else
        lastYaw = yaw
        yaw = local_player:get_abs_angles().y
    end
    deltaMovement = {
        x = position.x - lastPosition.x,
        y = position.y - lastPosition.y,
        z = position.z - lastPosition.z
    }
end)
events.present_queue:add(function()
    local local_player = entities.get_local_pawn()
    if local_player == nil or (not local_player:is_alive()) then
        lastPosition = { x = 0, y = 0, z = 0 }
        position = { x = 0, y = 0, z = 0 }
        lastYaw = 0
        yaw = 0
        deltaMovement = { x = 0, y = 0, z = 0 }
        ticksExisted = -1
    end
end)

addSpace(GROUP_A)
addLabel(GROUP_A, "                                   Lira")
addSpace(GROUP_B)
addLabel(GROUP_B, "                                   Lira")
local PEEKASSIST = gui.ctx:find("misc>movement>peek assist")
local AUTOSTOP_MODES = { "Legit", "LegitFast" }
local autoStop = newCheckbox(GROUP_A, "AutoStop")
addLabel(GROUP_B, "AutoStop")
local autoStopMode = newComboBox(GROUP_B, "Mode", AUTOSTOP_MODES)
local autoStopChance = newSlider(GROUP_B, "Chance", 100, 80, 100, 0.5, "%.1f%%")
local autoStopMinTargetSpeed = newSlider(GROUP_B, "Min Target Speed", 0.2, 0.2, 1, 0.01, "%.2f")
local autoStopMaxTargetSpeed = newSlider(GROUP_B, "Max Target Speed", 0.3, 0.2, 1, 0.01, "%.2f")
local autoStopInAir = newCheckbox(GROUP_B, "In Air", false)
local autoStopNotWhileSpace = newCheckbox(GROUP_B, "Not While Space", true)
local autoStopNotWhileMoving = newCheckbox(GROUP_B, "Not While Moving", true)
local autoStopNotWhilePeekAssist = newCheckbox(GROUP_B, "Not While PeekAssist", true)
local autoStopMinStartDelay = newSlider(GROUP_B, "Min Start Delay", 0, 0, 100, 5, "%.0fms")
local autoStopMaxStartDelay = newSlider(GROUP_B, "Max Start Delay", 20, 0, 100, 5, "%.0fms")
local autoStopMinBetweenDelay = newSlider(GROUP_B, "Min Between Delay", 100, 0, 500, 5, "%.0fms")
local autoStopMaxBetweenDelay = newSlider(GROUP_B, "Max Between Delay", 200, 0, 500, 5, "%.0fms")
local autoStopFail = newCheckbox(GROUP_B, "Fail", true)
local autoStopFailChance = newSlider(GROUP_B, "Fail Chance", 5, 0, 10, 0.1, "%.1f%%")
addDepends(autoStopFailChance, autoStopFail)
local autoStopMinFailTargetSpeed = newSlider(GROUP_B, "Min Fail Target Speed", 0.4, 0.3, 1, 0.01, "%.1f")
addDepends(autoStopMinFailTargetSpeed, autoStopFail)
local autoStopMaxFailTargetSpeed = newSlider(GROUP_B, "Max Fail Target Speed", 0.5, 0.3, 1, 0.01, "%.1f")
addDepends(autoStopMaxFailTargetSpeed, autoStopFail)
local autoStopOverMove = newCheckbox(GROUP_B, "OverMove", true)
local autoStopOverMoveChance = newSlider(GROUP_B, "OverMove Chance", 10, 0, 30, 1, "%.0f%%")
addDepends(autoStopOverMoveChance, autoStopOverMove)
local autoStopMinOverMoveTime = newSlider(GROUP_B, "Min OverMove Time", 10, 0, 50, 5, "%.0fms")
addDepends(autoStopMinOverMoveTime, autoStopOverMove)
local autoStopMaxOverMoveTime = newSlider(GROUP_B, "Max OverMove Time", 20, 0, 50, 5, "%.0fms")
addDepends(autoStopMaxOverMoveTime, autoStopOverMove)
local autoStopDontCounterStrafeIfYouAlreadyDidLegit = newCheckbox(GROUP_B, "DontCounterStrafeIfYouAlreadyDidLegit", true)
local autoStopStartTime = nil
local autoStopDecontinueSpeed = nil
local autoStopFinishTime = nil
local autoStopStarted = false
local function autoStopTryStart()
    if isSelected(autoStopMode, 1) then -- LegitFast
        autoStopStartTime = nil
        return true
    end
    local time = game.global_vars.real_time * 1000
    if autoStopStartTime == nil then
        if math.random() < 1 - (autoStopChance:get_value():get() / 100) then
            autoStopStartTime = 1e308
        else
            autoStopStartTime = time + math.random(
                autoStopMinStartDelay:get_value():get(),
                autoStopMaxStartDelay:get_value():get()
            )
        end
    end

    if time >= autoStopStartTime then
        autoStopDecontinueSpeed = nil
        return true
    end
    return false
end
local function autoStopTryContinue(speed)
    if not autoStopFail:get_value():get() then
        return true
    end

    if autoStopDecontinueSpeed == nil then
        local fail = math.random() >= 1 - (autoStopFailChance:get_value():get() / 100)
        autoStopDecontinueSpeed = tern(fail, math.random(
            autoStopMinFailTargetSpeed:get_value():get(),
            autoStopMaxFailTargetSpeed:get_value():get()
        ), -1)
    end

    if speed <= autoStopDecontinueSpeed then
        autoStopDecontinueSpeed = nil
        return false
    end
    return true
end
local function autoStopTryFinish()
    if autoStopStartTime == nil then
        return true
    end

    local time = game.global_vars.real_time * 1000
    if autoStopOverMove:get_value():get() then
        if autoStopFinishTime == nil then
            local overmove = math.random() >= 1 - (autoStopOverMoveChance:get_value():get() / 100)
            autoStopFinishTime = time + (tern(overmove, math.random(
                autoStopMinOverMoveTime:get_value():get(),
                autoStopMaxOverMoveTime:get_value():get()
            ), 0))
        end
    else
        autoStopFinishTime = time
    end

    if time >= autoStopFinishTime then
        autoStopFinishTime = nil
        autoStopStartTime = nil
        autoStopDecontinueSpeed = nil
        return true
    end
    return false
end
local function autoStopReset()
    autoStopStartTime = nil
    autoStopDecontinueSpeed = nil
    autoStopFinishTime = nil
    autoStopStarted = false
end

events.create_move:add(function(cmd)
    fixSlider(autoStopMinStartDelay, autoStopMaxStartDelay)
    fixSlider(autoStopMinBetweenDelay, autoStopMaxBetweenDelay)
    fixSlider(autoStopMinTargetSpeed, autoStopMaxTargetSpeed)
    fixSlider(autoStopMinFailTargetSpeed, autoStopMaxFailTargetSpeed)
    fixSlider(autoStopMinOverMoveTime, autoStopMaxOverMoveTime)
    if ticksExisted < 64 then
        autoStopReset()
        return
    end
    if (not autoStop:get_value():get())
        or ((not autoStopInAir:get_value():get()) and isInAir())
        or (autoStopNotWhileSpace:get_value():get() and gui.input:is_key_down(KEY_SPACE)) then
        autoStopReset()
        return
    end
    if (not autoStopInAir:get_value():get()) and isInAir() then
        autoStopReset()
        return
    end
    if autoStopNotWhilePeekAssist:get_value():get() and PEEKASSIST:get_value():get() then
        autoStopReset()
        return
    end

    local movement = { [0] = cmd:get_forwardmove(), cmd:get_leftmove() }
    local direction = getDirection(deltaMovement, yaw)
    -- 忽略小值
    local targetSpeed = math.random(
        autoStopMinTargetSpeed:get_value():get(),
        autoStopMaxTargetSpeed:get_value():get()
    )
    if math.abs(direction.forward) < targetSpeed then
        direction.forward = 0
    end
    if math.abs(direction.strafe) < targetSpeed then
        direction.strafe = 0
    end

    local smart = autoStopDontCounterStrafeIfYouAlreadyDidLegit:get_value():get()
    local shouldForward = direction.forward ~= 0 and
        tern(smart, movement[0] == 0, tern(direction.forward > 0, movement[0] <= 0, movement[0] >= 0))
    local shouldStrafe = direction.strafe ~= 0 and
        tern(smart, movement[1] == 0, tern(direction.strafe > 0, movement[1] >= 0, movement[1] <= 0))
    if autoStopNotWhileMoving:get_value():get() and (not (movement[0] == 0 and movement[1] == 0)) then
        shouldForward = false
        shouldStrafe = false
    end
    if shouldForward then
        if (autoStopStarted or autoStopTryStart()) and autoStopTryContinue(math.abs(direction.forward)) then
            autoStopStarted = true
            cmd:set_forwardmove(tern(direction.forward > 0, -1, 1))
        end
    elseif autoStopStarted and autoStopTryFinish() then
        autoStopStarted = false
    end

    if shouldStrafe then
        if (autoStopStarted or autoStopTryStart()) and autoStopTryContinue(math.abs(direction.strafe)) then
            autoStopStarted = true
            cmd:set_leftmove(tern(direction.strafe > 0, 1, -1))
        end
    elseif autoStopStarted and autoStopTryFinish() then
        autoStopStarted = false
    end
end)

local KILLMESSAGE_SILENCEFIX = {
    "@[欣欣公益19.99无需脱盒] 你的付费客户端怎么打不过欣欣公益呢 我们也有布吉岛客户端呢",
    "@[欣欣公益19.99无需脱盒] 你的付费客户端怎么打不过欣欣公益呢 我们也有布吉岛客户端呢",
    "@[欣欣公益19.99无需脱盒] 你的付费客户端怎么打不过欣欣公益呢 我们也有最强的布吉岛",
    "@[欣欣公益19.99无需脱盒] 你还不知道欣欣工艺无需脱盒吗 无需脱盒工具箱 我们也有布吉岛客户端呢",
    "@SilenceFix Best The Config Free",
    "@欣欣公益19.99 现在全天开放公益权限内置进服 看到了就赶快加入我们一起免费试用并获取吧 我们也有最强的布吉岛",
    "@[欣欣公益19.99无需脱盒] 花雨庭第一大端 用户最多 我们也有布吉岛客户端呢 客户端最稳定且最暴力",
    "@欣欣公益19.99 现在全天开放公益权限内置进服 学生党可以放学游玩花雨庭！快来免费获取吧 我们也有最强的布吉岛",
}
local KILLMESSAGE_RISE = {
    "Wow! My combo is Rise'n!",
    "Why would someone as bad as you not use Rise 6.0?",
    "Here's your ticket to spectator from Rise 6.0!",
    "I see you're a pay to lose player, huh?",
    "Do you need some PvP advice? Well Rise 6.0 is all you need.",
    "Hey! Wise up, don't waste another day without Rise.",
    "You didn't even stand a chance against Rise.",
    "We regret to inform you that your free trial of life has unfortunately expired.",
    "RISE against other cheaters by getting Rise!",
    "You can pay for that loss by getting Rise.",
    "Remember to use hand sanitizer to get rid of bacteria like you!",
    "Hey, try not to drown in your own salt.",
    "Having problems with forgetting to left click? Rise 6.0 can fix it!",
    "Come on, is that all you have against Rise 6.0?",
    "Rise up today by getting Rise 6.0!",
    "Get Rise, you need it.",
    "how about you rise up to heaven by ending it",
    "Did you know Watchdog has banned 6346 players in the last 7 days."
}
local KILLMESSAGE_RISEGO = {
    "Missed {} due to correction",
    "Missed {} due to spread",
    "Missed {} due to prediction error",
    "Missed {} due to invalid backtrack",
    "Missed {} due to ?",
    "Shot at head, and missed head, but hit anyways because of spread (lol)",
    "Missed {} due to resolver",
}
local KILLMESSAGE_XINXIN = {
    "内部是60元哈 你给了欣欣哥40元 请在支付我20元售后费哈 因为欣欣哥是更新参数的 我呢是来搞售后滴 只要我在线 售后会特别的好呢 请你放心 我们是绝对不会让你吃亏的呢哈学生党！"
}
local KILLMESSAGE_MODE = { "SilenceFix", "Rise", "Rise:GO", "XinXin", "Custom" }
local killmessage = newCheckbox(GROUP_A, "Killmessage")
addLabel(GROUP_B, "Killmessage")
local killmessageMode = newComboBox(GROUP_B, "Mode", KILLMESSAGE_MODE)
local killmessageCustomMsg = newTextInput(GROUP_B, "Custom Msg")
local killmessageEnemyCheck = newCheckbox(GROUP_B, "Enemy Check", true)
events.event:add(function(event)
    if event:get_name() ~= "player_death" or (not killmessage:get_value():get()) then
        return
    end

    local attacker = event:get_controller("attacker")
    local victim = event:get_controller("userid")
    local local_controller = entities.get_local_controller()

    if not attacker or not victim or attacker ~= local_controller then
        return
    end
    if killmessageEnemyCheck:get_value():get() and (not victim:is_enemy()) then
        return
    end

    local msgList = {}

    if isSelected(killmessageMode, 0) then
        msgList = KILLMESSAGE_SILENCEFIX
    elseif isSelected(killmessageMode, 1) then
        msgList = KILLMESSAGE_RISE
    elseif isSelected(killmessageMode, 2) then
        msgList = KILLMESSAGE_RISEGO
    elseif isSelected(killmessageMode, 3) then
        msgList = KILLMESSAGE_XINXIN
    elseif isSelected(killmessageMode, 4) then
        msgList = { killmessageCustomMsg:get_value():get() }
    end

    if #msgList == 0 then
        return
    end

    local message = string.gsub(msgList[math.random(#msgList)], "{}", victim:get_name())
    sendChat(message)
end)

-- 基于一个假设：射击一定符合顺序weapon_fire -> bullet_impact -> player_hurt -> player_death
local HITLOG_STATE = {
    NONE = 0,
    FIRE = 1,
    HIT = 2
}
local HITLOG_HITGROUP = {
    [1] = "head",
    [2] = "chest",
    [3] = "stomach",
    [4] = "left arm",
    [5] = "right arm",
    [6] = "left leg",
    [7] = "right leg",
    [8] = "neck",
    [10] = "gear"
}
local HITLOG_TARGETS = { "Self", "Team", "All" }
local hitLog = newCheckbox(GROUP_A, "HitLog")
addLabel(GROUP_B, "HitLog")
local hitLogTarget = newComboBox(GROUP_B, "Target", HITLOG_TARGETS)
local hitLogNotWhileManualShot = newCheckbox(GROUP_B, "Not While Manual Shot", true)
local hitLogShowMiss = newCheckbox(GROUP_B, "Show Miss", true)
local hitLogAnalyzer = newCheckbox(GROUP_B, "Miss Analyzer", true)
hitLogAnalyzer.tooltip = "analyze the reason why missed if possible"
-- {
--     controllerName: {
--         controller = controller
--         state = HITLOG_STATE.NONE,
--         hitPos = { x = 0, y = 0, z = 0 },
--         shotYaw = 0,
--         shotPos = { x = 0, y = 0, z = 0 }
--     }
-- }
local hitLogData = LRUCache.new(20)
hitLog:add_callback(function()
    hitLogData = LRUCache.new(20)
end)
local function hitLogIsTarget(target)
    if target == nil then
        return false
    end

    local mode = HITLOG_TARGETS[fromraw(hitLogTarget:get_value():get():get_raw())]
    if mode == "Self" then
        local self = entities.get_local_controller()
        return self ~= nil and target == self
    elseif mode == "Team" then
        return not target:is_enemy()
    elseif mode == "All" then
        return true
    end
    return false
end
local function hitLogAnalyze(data)
    local self = entities.get_local_controller()
    if not data.controller:get_pawn():is_alive() then
        return "death"
    end
    if data.state == HITLOG_STATE.FIRE then
        return "unregistered"
    end
    if data.hitPos.x == data.shotPos.x
        and data.hitPos.z == data.shotPos.z then
        return "anticheat"
    end
    if data.controller == self then
        if deltaMovement.x ~= 0 or deltaMovement.y ~= 0 or deltaMovement.z ~= 0 then
            if data.hitPos.x == data.shotPos.x and data.hitPos.z == data.shotPos.z then
                return "anticheat"
            end
            if math.abs(deltaMovement.y) > 0.05 or isInAir() or deltaMovement.x > 2 or deltaMovement.z > 2 then
                return "spread"
            end
        else
            return "resolver"
        end
    end

    return "unknown"
end
local function hitLogSend(message)
    sendNoti("HitLog", message)
end
local function hitLogGetPrefix(attacker, hit)
    local self = entities.get_local_controller()
    if attacker == nil or hit == nil then
        return tern(hit, "Unknown hit ", "Unknown missed ")
    end
    if hit then
        if self ~= nil and attacker == self then
            return "Hit "
        end
        return attacker:get_name() .. " hit "
    end
    if self ~= nil and attacker == self then
        return "Missed "
    end
    return attacker:get_name() .. " missed "
end
local function hitLogUpdateState(data, newState)
    if newState ~= nil then
        data.state = newState
        return
    end

    if data.state ~= HITLOG_STATE.NONE then
        if hitLogShowMiss:get_value():get() then
            local prefix = hitLogGetPrefix(data.controller, false)
            if prefix == nil then
                return
            end
            if hitLogAnalyzer:get_value():get() then
                local result = hitLogAnalyze(data)
                if result == nil then
                    return
                end
                hitLogSend(prefix .. "due to " .. result .. ".")
            else
                hitLogSend(prefix .. ".")
            end
        end
    end
    data.state = HITLOG_STATE.NONE
end
events.event:add(function(event)
    if not hitLog:get_value():get() then
        return
    end
    if event:get_name() ~= "weapon_fire" then
        return
    end

    local controller = event:get_controller("userid")
    if not hitLogIsTarget(controller) then
        return
    end
    local weapon = controller:get_active_weapon()
    if weapon == nil or (not weapon:is_gun()) then
        return
    end
    if (hitLogNotWhileManualShot:get_value():get())
        and entities.get_local_controller() == controller
        and isKeyDown(KEY_LBUTTON) then
        return
    end

    local data = hitLogData:get(controller:get_name())
    if data == nil then
        data = {
            controller = controller,
            state = HITLOG_STATE.NONE,
            hitPos = { x = 0, y = 0, z = 0 },
            shotYaw = 0,
            shotPos = { x = 0, y = 0, z = 0 }
        }
        hitLogData:set(controller:get_name(), data)
    end
    hitLogUpdateState(data, HITLOG_STATE.FIRE)
    data.shotYaw = yaw
    data.shotPos = position
end)
events.event:add(function(event)
    if not hitLog:get_value():get() then
        return
    end
    if event:get_name() ~= "bullet_impact" then
        return
    end
    local target = event:get_controller("userid")
    if target == nil then
        return
    end
    local data = hitLogData:get(target:get_name())
    if data == nil then
        return
    end

    if data.state == HITLOG_STATE.NONE then
        return
    end
    hitLogUpdateState(data, HITLOG_STATE.HIT)
    data.hitPos = {
        x = event:get_float("x"),
        y = event:get_float("y"),
        z = event:get_float("z")
    }
end)
events.event:add(function(event)
    if not hitLog:get_value():get() then
        return
    end
    if event:get_name() ~= "player_hurt" then
        return
    end
    local attacker = event:get_controller("attacker")
    if attacker == nil then
        return
    end
    local data = hitLogData:get(attacker:get_name())
    if data == nil then
        return
    end

    if data.state == HITLOG_STATE.NONE then
        return
    end
    hitLogUpdateState(data, HITLOG_STATE.NONE)

    local target = event:get_controller("userid")
    if target == nil then
        return
    end
    local group = HITLOG_HITGROUP[event:get_int("hitgroup")]
    if group == nil then
        group = "unknown"
    end

    local msg = hitLogGetPrefix(attacker, true) ..
        target:get_name() .. " in " .. group .. " for " .. event:get_int("dmg_health") .. " damage."
    hitLogSend(msg)
end)
events.create_move:add(function(cmd)
    if not hitLog:get_value():get() then
        return
    end

    entities.controllers:for_each(function(entry)
        local target = entry.entity
        if target == nil then
            return
        end

        local data = hitLogData:get(target:get_name())
        if data == nil then
            return
        end
        hitLogUpdateState(data)
    end)
end)

call(function()
    local ANTICHEAT_TARGETS = { "Self", "Team", "Enemy" }
    local anticheat = newCheckbox(GROUP_A, "Anticheat")
    addLabel(GROUP_B, "AntiCheat")
    local anticheatTarget = newMultiBox(GROUP_B, "Target", ANTICHEAT_TARGETS)
    local anticheatThreshold = newSlider(GROUP_B, "Threshold", 0.001, 0.001, 0.01, 0.001, "%.3f")
    local anticheatMinVL = newSlider(GROUP_B, "Min VL", 20, 1, 100, 1)
    local anticheatMaxVL = newSlider(GROUP_B, "Max VL", 50, 1, 100, 1)
    local anticheatPlayers = LRUCache.new(20)
    anticheat:add_callback(function()
        anticheatPlayers = LRUCache.new(20)
    end)
    local function anticheatFlag(data, checkName, vlAdd, message)
        local newVL = data.vl + vlAdd
        if newVL >= anticheatMinVL:get_value():get() and newVL <= anticheatMaxVL:get_value():get() then
            if message == nil then
                sendNoti("LiraAC", data.player:get_name() .. " failed " .. checkName .. " (VL:" .. newVL .. ")")
            else
                sendNoti("LiraAC",
                    data.player:get_name() .. " failed " .. checkName .. " (VL:" .. newVL .. ") | " .. message)
            end
        end
        data.vl = newVL
    end
    local anticheatChecks = {
        [newCheckbox(GROUP_B, "BadPacket (A)", true)] = function(data)
            -- print(data.player:get_name() .. " " .. string.format("%.2f", data.yaw) .. " " .. string.format("%.2f", data.pitch))
            if data.pitch > 90 or data.pitch < -90 then
                anticheatFlag(data, "BadPacket (A)", 1, "Invalid Pitch.")
            end
        end,
        [newCheckbox(GROUP_B, "Aim (A)", true)] = function(data)
            local from = data.rotHistory[3]
            local mid = data.rotHistory[2]
            local to = data.rotHistory[1]
            if rotEqualsFull(from, to) and (not rotEquals(from, mid, anticheatThreshold:get_value():get() * 10)) then
                anticheatFlag(data, "Aim (A)", 1, "Inhuman Mouse Movement.")
            end
        end,
        [newCheckbox(GROUP_B, "Aim (B)", false)] = function(data)
            if data.lastAttackPos == nil or data.lastAttackTicks > 16 then
                return
            end

            -- mc是20tick的，而cs2是64tick的；我们需要摘取数据。
            local TICKS = { 64, 61, 58, 54, 51, 48, 45, 42, 38, 35, 32, 29, 26, 22, 19, 16, 13, 10, 6, 3 }
            local POS_MULTIPLIER = 0.02247596153846153846153846153846 -- 根据玩家移动速度估算

            -- 格式为：deltaPitch * 20 + joltPitch * 20 + angle * 20 + joltYaw * 20 + deltaYaw * 20
            local takakoData = {}
            for _, i in ipairs(TICKS) do
                local deltaPitch = data.rotHistory[i].pitch - data.rotHistory[i - 1].pitch
                takakoData[0] = deltaPitch
                table.insert(takakoData, deltaPitch)
            end
            for _, i in ipairs(TICKS) do
                local deltaPitch = data.rotHistory[i].pitch - data.rotHistory[i - 1].pitch
                local lastDeltaPitch = data.rotHistory[i - 1].pitch - data.rotHistory[i - 2].pitch
                table.insert(takakoData, math.abs(deltaPitch - lastDeltaPitch))
            end
            for _, i in ipairs(TICKS) do
                local eyePos = data.player:get_eye_pos()
                local targetPos = data.lastAttackPos
                -- cs2与mc的坐标系不同
                local fixedEyePos = {
                    x = eyePos.x * POS_MULTIPLIER,
                    y = eyePos.z * POS_MULTIPLIER,
                    z = eyePos.y * POS_MULTIPLIER
                }
                local fixedTargetPos = {
                    x = targetPos.x * POS_MULTIPLIER,
                    y = targetPos.z * POS_MULTIPLIER,
                    z = targetPos.y * POS_MULTIPLIER
                }
                local angle = takakoGetAngle(data.rotHistory[i], fixedEyePos, fixedTargetPos)
                table.insert(takakoData, angle)
            end
            for _, i in ipairs(TICKS) do
                local deltaYaw = data.rotHistory[i].yaw - data.rotHistory[i - 1].yaw
                local lastDeltaYaw = data.rotHistory[i - 1].yaw - data.rotHistory[i - 2].yaw
                table.insert(takakoData, math.abs(deltaYaw - lastDeltaYaw))
            end
            for _, i in ipairs(TICKS) do
                local deltaYaw = data.rotHistory[i].yaw - data.rotHistory[i - 1].yaw
                table.insert(takakoData, deltaYaw)
            end

            http.post("http://127.0.0.1:5555/predict", {
                headers = {
                    ["Content-Type"] = "application/json",
                    ["Accept"] = "application/json"
                },
                json = {
                    data = takakoData, -- 测试
                    token = "d13e478c-c521-4898-934d-c1fa58bb0a49"
                }
            }, function(success, response)
                if not success then
                    print("Takako Error")
                    return
                end
                local takakoRes = json.parse(response.body)
                if takakoRes.message == nil then
                    print("Takako Error")
                    return
                end
                if takakoRes.message ~= "success" then
                    print("Takako Error: " .. takakoRes.message)
                    return
                end
                if takakoRes.predicted == nil then
                    print("Takako Error: Unfair Response")
                    return
                end

                if (tonumber(takakoRes.predicted) - anticheatThreshold:get_value():get()) > 0.8 then
                    anticheatFlag(data, "Aim (B)", 0.1,
                        string.format("Heuristic AI checks. Probability=%.2f%%", takakoRes.predicted))
                end
            end)
        end,
        [newCheckbox(GROUP_B, "Speed (A)", true)] = function(data)
            if data.onGroundTicks < 20 or isSneaking(data.player) then
                return
            end

            local speeds = {} -- size 63
            for i = 2, 64 do
                local speed = getSpeed({
                    x = data.posHistory[i].x - data.posHistory[i - 1].x,
                    y = data.posHistory[i].y - data.posHistory[i - 1].y
                })
                if speed == 0 or speed >= (1.2187356474227 - anticheatThreshold:get_value():get() * 2) then -- 合法最快稳定慢走速度1.2187356474227
                    return
                end
                table.insert(speeds, speed)
            end

            -- 检查慢走
            for i = 1, 61 do
                local min = speeds[i];
                for j = 2, 4 do
                    local newSpeed = speeds[i + j]
                    if newSpeed <= min then
                        break
                    end

                    min = newSpeed
                end
            end

            anticheatFlag(data, "Speed (A)", 0.5, "Inhuman Key Input. (Maybe SlowWalk?)")
        end,
        [(function()
            local option = newCheckbox(GROUP_B, "Aim (C)", true)
            events.event:add(function(event)
                if not anticheat:get_value():get() then
                    return
                end
                if not option:get_value():get() then
                    return
                end
                if event:get_name() ~= "bullet_impact" then
                    return
                end

                local target = event:get_pawn_from_id("userid")
                if target == nil then
                    return
                end

                local data = anticheatPlayers:get(target:get_name())
                if data == nil then
                    return
                end

                local weapon = target:get_active_weapon()
                if weapon == nil then
                    return
                end
                local spread = weapon:get_spread(csweapon_mode.primary_mode)
                local inaccuracy = weapon:get_inaccuracy(csweapon_mode.primary_mode)
                if weapon:get_id() == weapon_id.revolver then
                    spread = math.max(spread, weapon:get_spread(csweapon_mode.secondary_mode))
                    inaccuracy = math.max(inaccuracy, weapon:get_inaccuracy(csweapon_mode.secondary_mode))
                end
                local startPos = data.player:get_abs_origin()
                local hitPos = { x = event:get_float("x"), y = event:get_float("y"), z = event:get_float("z") }
                local maxDelta = computeMaxSpreadOffsets(spread, inaccuracy) + 20
                -- TODO 因为subtick所以我必须做最保守估计
                local maxYawDelta = maxDelta + math.abs(data.deltaYaw)
                local maxPitchDelta = maxDelta + math.abs(data.deltaPitch)
                local exceptRotation = getRotation(startPos, hitPos)

                -- TODO 目前还无法拿到pitch roll rotation
                local yawDelta = math.abs(normalizeYaw(data.player:get_abs_angles().y - exceptRotation.yaw))
                yawDelta = math.min(yawDelta, 360 - yawDelta)
                if yawDelta > maxYawDelta * (1 + anticheatThreshold:get_value():get() * 10) then
                    anticheatFlag(data, "Aim (C)", 1,
                        string.format("Impossible hit. yaw=%.3f predict=%.3f delta=%.3f except=%.3f deltaYaw=%.3f",
                            data.player:get_abs_angles().y, exceptRotation.yaw, yawDelta, maxYawDelta,
                            data.deltaYaw))
                end
            end)
            return option
        end)()] = function()
        end
    }
    local function anticheatIsValidTarget(player)
        local self = entities.get_local_pawn()
        if isSelected(anticheatTarget, 0) then
            if self ~= nil and player == self then
                return true
            end
        end
        if isSelected(anticheatTarget, 1) then
            if not player:is_enemy() then
                return true
            end
        end
        if isSelected(anticheatTarget, 2) then
            if player:is_enemy() then
                return true
            end
        end
        return false
    end
    events.create_move:add(function(cmd)
        fixSlider(anticheatMinVL, anticheatMaxVL)
        if not anticheat:get_value():get() then
            return
        end

        entities.players:for_each(function(entry)
            local target = entry.entity
            if target == nil or (not anticheatIsValidTarget(target)) then
                return
            end

            local pos = target:get_abs_origin()
            local angle = target:get_abs_angles()

            local data = anticheatPlayers:get(target:get_name())
            if data == nil then
                data = {
                    player = target,
                    ticksExisted = 0,
                    vl = 0,
                    x = pos.x,
                    y = pos.y,
                    z = pos.z,
                    deltaX = 0,
                    deltaY = 0,
                    deltaZ = 0,
                    lastDeltaX = 0,
                    lastDeltaY = 0,
                    lastDeltaZ = 0,
                    yaw = angle.y,
                    pitch = angle.x,
                    roll = angle.z,
                    deltaYaw = 0,
                    deltaPitch = 0,
                    deltaRoll = 0,
                    posHistory = listFromFill(64, { x = 0, y = 0, z = 0 }),
                    rotHistory = listFromFill(64, { yaw = 0, pitch = 0, roll = 0 }),
                    onGround = isInAir(target),
                    lastOnGround = false,
                    landPos = { x = 0, y = 0, z = 0 },
                    lastLandPos = { x = 0, y = 0, z = 0 },
                    onGroundTicks = 0,
                    offGroundTicks = 0,
                    lastOnGroundTicks = 0,
                    lastOffGroundTicks = 0,
                    maxAirZ = -1,
                    lastMaxAirZ = -1,
                    lastAttackPos = nil,
                    lastAttackTicks = 0
                }
                data.posHistory[1] = { x = data.x, y = data.y, z = data.z }
                data.rotHistory[1] = { yaw = data.yaw, pitch = data.pitch, roll = data.roll }
                anticheatPlayers:set(target:get_name(), data)
            else
                data.ticksExisted = data.ticksExisted + 1
                data.player = target
                data.lastDeltaX = data.deltaX
                data.lastDeltaY = data.deltaY
                data.lastDeltaZ = data.deltaZ
                data.deltaX = pos.x - data.x
                data.deltaY = pos.y - data.y
                data.deltaZ = pos.z - data.z
                data.deltaYaw = angle.y - data.yaw
                data.deltaPitch = angle.x - data.pitch
                data.deltaRoll = angle.z - data.roll
                data.x = pos.x
                data.y = pos.y
                data.z = pos.z
                data.yaw = angle.y
                data.pitch = angle.x
                data.roll = angle.z
                table.remove(data.posHistory, #data.posHistory)
                table.insert(data.posHistory, 1, { x = data.x, y = data.y, z = data.z })
                table.remove(data.rotHistory, #data.rotHistory)
                table.insert(data.rotHistory, 1, { yaw = data.yaw, pitch = data.pitch, roll = data.roll })
                data.lastOnGround = data.onGround
                data.lastOnGroundTicks = data.onGroundTicks
                data.lastOffGroundTicks = data.offGroundTicks
                data.lastMaxAirZ = data.maxAirZ
                if not isInAir(target) then
                    data.onGround = true
                    data.onGroundTicks = data.onGroundTicks + 1
                    data.offGroundTicks = 0
                    data.lastLandPos = data.landPos
                    data.landPos = { x = data.x, y = data.y, z = data.z }
                    data.maxAirZ = -1
                else
                    data.onGround = false
                    data.offGroundTicks = data.offGroundTicks + 1
                    data.onGroundTicks = 0
                    data.maxAirZ = math.max(data.maxAirZ, data.z)
                end
                if data.lastAttackPos ~= nil then
                    data.lastAttackTicks = data.lastAttackTicks + 1
                end

                if data.ticksExisted > 20 then
                    for option, check in pairs(anticheatChecks) do
                        if option:get_value():get() then
                            check(data)
                        end
                    end
                end

                if data.ticksExisted % (64 * 60) == 0 then
                    data.vl = math.ceil(data.vl * 0.5)
                end
            end
        end)
    end)
    events.event:add(function(event)
        if not anticheat:get_value():get() then
            return
        end
        if event:get_name() ~= "player_hurt" then
            return
        end
        local attacker = event:get_pawn_from_id("attacker")
        if attacker == nil then
            return
        end

        local target = event:get_pawn_from_id("userid")
        if target == nil then
            return
        end

        local data = anticheatPlayers:get(attacker:get_name())
        if data == nil then
            return
        end

        data.lastAttackPos = target:get_abs_origin()
        data.lastAttackTicks = 0
    end)
end)

call(function()
    local disabler = newCheckbox(GROUP_A, "Disabler")
    addLabel(GROUP_B, "Disabler")
    local disablerMode = newMultiBox(GROUP_B, "Mode", { "Pitch", "Reslover", "Spectator" })
    local disablerNoPitchAdjustOnLMB = newCheckbox(GROUP_B, "No pitch adjust on LMB", true)
    local disablerResloverTick = newSlider(GROUP_B, "Reslover Tick", 2, 2, 30, 1)
    local disablerResloverForce = newCheckbox(GROUP_B, "Reslover Force", false)
    local disablerRandomMode = newComboBox(GROUP_B, "Random Mode",
        { "None", "Random", "SecureRandom", "Gaussian", "Intave" })
    local disablerLockView = newCheckbox(GROUP_B, "Lock View", false)
    addDependsCustom(disablerResloverTick, disablerMode, function()
        return isSelected(disablerMode, 1)
    end)
    addDependsCustom(disablerResloverForce, disablerMode, function()
        return isSelected(disablerMode, 0) and isSelected(disablerMode, 1)
    end)
    addDependsCustom(disablerRandomMode, disablerMode, function()
        return isSelected(disablerMode, 1)
    end)
    local disablerSecureRandom
    local disablerIntaveRandom
    local disablerTick
    local disablerLastOffset
    local function disablerRefresh()
        disablerSecureRandom = SecureRandom.new()
        disablerIntaveRandom = ContextualRandom.new()
        disablerTick = 0
        disablerLastOffset = { yaw = 0, pitch = 0 }
    end
    disabler:add_callback(disablerRefresh)
    disablerMode:add_callback(disablerRefresh)
    disablerRefresh()
    events.create_move:add(function(cmd)
        if not disabler:get_value():get() then
            return
        end

        local beginAngles = cmd:get_viewangles()

        if isSelected(disablerMode, 0) then
            local angles = cmd:get_viewangles()
            angles.x = -3402823346297399750336966557696
            cmd:set_viewangles(angles)
        end
        if isSelected(disablerMode, 1) then
            local angles = cmd:get_viewangles()

            local rng = function()
                return tern(disablerTick % disablerResloverTick:get_value():get() == 0, 1, 0)
            end
            if isSelected(disablerRandomMode, 1) then
                rng = math.random
            elseif isSelected(disablerRandomMode, 2) then
                rng = function()
                    return disablerSecureRandom:random()
                end
            elseif isSelected(disablerRandomMode, 3) then
                rng = function ()
                    return limit(gaussianRandom(), 0, 1)
                end
            elseif isSelected(disablerRandomMode, 4) then
                rng = function()
                    return disablerIntaveRandom:random()
                end
            end

            if disablerResloverForce:get_value():get() or rng() >= 0.5 then
                angles.x = 3402823346297399750336966557696
            else
                angles.x = -3402823346297399750336966557696
            end
            cmd:set_viewangles(angles)
        end
        if isSelected(disablerMode, 2) then
            local angles = cmd:get_viewangles()

            if disablerTick % disablerResloverTick:get_value():get() == 0 then
                angles.z = 3402823346297399750336966557696
            else
                angles.z = -3402823346297399750336966557696
            end
            cmd:set_viewangles(angles)
        end

        if disablerLockView:get_value():get() then
            local angles = cmd:get_viewangles()
            local lastOffset = disablerLastOffset
            disablerLastOffset = {
                yaw = angles.y - beginAngles.y,
                pitch = angles.x - beginAngles.x
            }
            angles.x = angles.x - lastOffset.pitch
            angles.y = angles.y - lastOffset.yaw
            cmd:set_viewangles(angles)
            cmd:lock_angles()
        end

        if disablerNoPitchAdjustOnLMB:get_value():get() and isKeyDown(KEY_LBUTTON) then
            local angles = cmd:get_viewangles()
            angles.x = beginAngles.x
            cmd:set_viewangles(angles)
        end

        disablerTick = disablerTick + 1
    end)
end)

call(function()
    local HITSOUND_PATH = files.get_script_directory() .. "hitsounds\\"
    local HITSOUND_SUFFIX = ".wav"

    local hitSound = newCheckbox(GROUP_A, "HitSound")
    addLabel(GROUP_B, "HitSound")
    local hitSoundModes = {}
    local hitSoundModeObjects = {}
    local hitSoundMode = newComboBox(GROUP_B, "Mode", {})
    local function hitSoundRefresh()
        for _, selectable in pairs(hitSoundModeObjects) do
            hitSoundMode:remove(selectable)
        end
        hitSoundModes = {}
        hitSoundModeObjects = {}

        if not files.folder_exists(HITSOUND_PATH) then
            files.create_folder(HITSOUND_PATH)
            return
        end

        local paths = listFiles(HITSOUND_PATH .. "*")
        if paths == nil then
            return
        end
        for _, path in ipairs(paths) do
            if endswith(path, HITSOUND_SUFFIX) then
                local name = string.sub(path, 1, #path - string.len(HITSOUND_SUFFIX))
                local selectable = gui.selectable(
                    gui.control_id(normalize(NameGenerator_generate())),
                    name
                )
                table.insert(hitSoundModes, name)
                table.insert(hitSoundModeObjects, selectable)
                hitSoundMode:add(selectable)
            end
        end
    end
    newButton(GROUP_B, "Refresh", "Run"):add_callback(hitSoundRefresh)
    hitSoundRefresh()
    local function hitSoundPlayNow()
        for i, name in pairs(hitSoundModes) do
            if isSelected(hitSoundMode, i - 1) then
                playSound(HITSOUND_PATH .. name .. HITSOUND_SUFFIX)
                return
            end
        end
    end
    newButton(GROUP_B, "Preview", "Play"):add_callback(hitSoundPlayNow)
    events.event:add(function(event)
        if not hitSound:get_value():get() then
            return
        end
        if event:get_name() ~= "player_hurt" then
            return
        end
        local attacker = event:get_controller("attacker")
        if attacker == nil then
            return
        end
        local self = entities.get_local_controller()
        if self == nil or self ~= attacker then
            return
        end

        hitSoundPlayNow()
    end)
end)


call(function()
    local enabled = newCheckbox(GROUP_A, "Strafe")
    addLabel(GROUP_B, "Strafe")
    local mode = newComboBox(GROUP_B, "Mode", { "Legit" })
    local onlyWhileKey = newCheckbox(GROUP_B, "Only While Key", true)

    events.create_move:add(function(cmd)
        if not enabled:get_value():get() then
            return
        end
        if not isInAir() then
            return
        end

        if isSelected(mode, 0) then
            local forward = cmd:get_forwardmove()
            local strafe = cmd:get_leftmove()
            if forward == 0 and strafe == 0 then
                if onlyWhileKey:get_value():get() then
                    return
                end
                local direction = getDirection(deltaMovement, yaw)
                forward = direction.forward
                strafe = direction.strafe
            end
            if forward == 0 then
                return
            end
            local reversed = tern(forward > 0, 1, -1)

            cmd:set_forwardmove(0)
            if yaw > lastYaw then
                cmd:set_leftmove(1 * reversed)
            else
                cmd:set_leftmove(-1 * reversed)
            end
        end
    end)
end)


call(function()
    local enabled = newCheckbox(GROUP_A, "SilentAim")
    addLabel(GROUP_B, "SilentAim")
    local mode = newComboBox(GROUP_B, "Mode", { "Instant" })
    local fov = newSlider(GROUP_B, "FOV", 10, 1, 180, 1)
    local inAir = newCheckbox(GROUP_B, "In Air", false)
    local aimBase = newComboBox(GROUP_B, "Aim Base", { "Head", "Foot" })
    local offsetX = newSlider(GROUP_B, "Offset X", 0, -100, 100, 5)
    local offsetY = newSlider(GROUP_B, "Offset Y", 0, -100, 100, 5)
    local offsetZ = newSlider(GROUP_B, "Offset Z", 0, -100, 100, 5)
    local noise = newCheckbox(GROUP_B, "Noise", false)
    local randomMode = newComboBox(GROUP_B, "Random Mode", { "Random", "SecureRandom", "Gaussian", "Intave" })
    local noiseScale = newSlider(GROUP_B, "Scale", 1.0, 0.1, 1.0, 0.01, "%.2f")
    local lockView = newCheckbox(GROUP_B, "Lock View", false)

    local secureRandom = SecureRandom.new()
    local intaveRandom = ContextualRandom.new()

    events.create_move:add(function(cmd)
        if cmd == nil then
            return
        end
        if not enabled:get_value():get() then
            return
        end

        local self = entities:get_local_pawn()
        if self == nil then
            return
        end

        if (not inAir:get_value():get()) and isInAir() then
            return
        end

        local selfPos = self:get_eye_pos()
        local angles = cmd:get_viewangles()

        local fovVal = fov:get_value():get()
        local aimBaseVal
        if isSelected(aimBase, 0) then
            aimBaseVal = 0
        elseif isSelected(aimBase, 1) then
            aimBaseVal = 1
        else
            return
        end
        local offsetXVal = offsetX:get_value():get()
        local offsetYVal = offsetY:get_value():get()
        local offsetZVal = offsetZ:get_value():get()

        local delta = fovVal
        local target = nil
        entities.players:for_each(function(entry)
            local entity = entry.entity
            if entity == nil then
                return
            end
            if not entity:is_enemy() then
                return
            end
            if not entity:is_alive() then
                return
            end

            local pos
            if aimBaseVal == 0 then
                pos = entity:get_eye_pos()
            else
                pos = entity:get_abs_origin()
            end
            pos = {
                x = pos.x + offsetXVal,
                y = pos.y + offsetYVal,
                z = pos.z + offsetZVal
            }
            local rotation = getRotation(selfPos, pos)
            if noise:get_value():get() then
                local rng = math.random
                if isSelected(randomMode, 1) then
                    rng = function()
                        return secureRandom:random()
                    end
                elseif isSelected(randomMode, 2) then
                    rng = function ()
                        return limit(gaussianRandom(), 0, 1)
                    end
                elseif isSelected(randomMode, 3) then
                    rng = function()
                        return intaveRandom:random()
                    end
                end

                rotation.yaw = rotation.yaw + rng() * noiseScale:get_value():get()
                rotation.pitch = rotation.pitch + rng() * noiseScale:get_value():get()
            end
            rotation.pitch = limit(rotation.pitch, -89, 89)

            local deltaYaw = getYawDiff(angles.y, rotation.yaw)
            local deltaPitch = rotation.pitch - angles.x
            local newRotation = {
                yaw = angles.y + deltaYaw,
                pitch = rotation.pitch
            }

            local newDelta = math.sqrt(deltaYaw * deltaYaw + deltaPitch * deltaPitch)
            if newDelta > delta then
                return
            end

            delta = newDelta
            target = newRotation
        end)

        if target == nil then
            return
        end

        angles.x = target.pitch
        angles.y = target.yaw
        cmd:set_viewangles(angles)
        if lockView:get_value():get() then
            cmd:lock_angles()
        end
    end)
end)


call(function ()
    local MOD_NAME = "Backtrack"
    local enabled = newCheckbox(GROUP_A, MOD_NAME)
    addLabel(GROUP_B, MOD_NAME)
    local maxDelay = newSlider(GROUP_B, "Max Delay", 200, 0, 250, 5, "%.0fms")
    local onlyWhilePeek = newCheckbox(GROUP_B, "Only While Peek", false)
    local lastState = false

    local function updateState()
        if enabled:get_value():get() and ((not onlyWhilePeek:get_value():get()) or PEEKASSIST:get_value():get()) then
            if lastState then
                return
            end
            Backend_send("enable " .. MOD_NAME)
            lastState = true
        else
            if not lastState then
                return
            end
            Backend_send("disable " .. MOD_NAME)
            lastState = false
        end
    end

    enabled.inactive = not Backend_connected
    enabled:add_callback(updateState)
    maxDelay:add_callback(function ()
        Backend_send(MOD_NAME .. " " .. maxDelay:get_value():get())
    end)
    events.create_move:add(updateState)
end)

call(function ()
    local MOD_NAME = "FakeLag"
    local enabled = newCheckbox(GROUP_A, MOD_NAME)
    addLabel(GROUP_B, MOD_NAME)
    local maxDelay = newSlider(GROUP_B, "Max Delay", 200, 0, 250, 5, "%.0fms")
    local releaseOnShot = newCheckbox(GROUP_B, "Release On Shot", false)
    local lastState = false

    local function updateState()
        if enabled:get_value():get() then
            if lastState then
                return
            end
            Backend_send("enable " .. MOD_NAME)
            lastState = true
        else
            if not lastState then
                return
            end
            Backend_send("disable " .. MOD_NAME)
            lastState = false
        end
    end

    enabled.inactive = not Backend_connected
    enabled:add_callback(updateState)
    maxDelay:add_callback(function ()
        Backend_send(MOD_NAME .. " " .. maxDelay:get_value():get())
    end)
    events.event:add(function(event)
        if not enabled:get_value():get() then
            return
        end
        if not releaseOnShot:get_value():get() then
            return
        end
        if event:get_name() ~= "weapon_fire" then
            return
        end

        local controller = event:get_controller("userid")
        if controller == nil then
            return
        end
        local self = entities.get_local_controller()
        if self == nil or self ~= controller then
            return
        end

        Backend_send("disable " .. MOD_NAME)
        updateState()
    end)
end)

newButton(GROUP_A, "Safe-Unload", "Unload"):add_callback(function ()
    Backend_close()
    error("Lira Unloaded!")
end)


sendNoti(NAME, NAME .. " " .. VERSION .. " Loaded!")
