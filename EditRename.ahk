#SingleInstance force
; #NoTrayIcon

iniPath := A_ScriptDir "\set.ini"

SplitPath(A_ScriptFullPath, , , , &app)

if !FileExist(iniPath)
{
    FileAppend("
    (
        ; 不要调整行顺序,不要删除行, 可以更改程序文件名,只传入一个文件无效
        ; 关闭编辑器时会自动进行修改
        ; 修改错误时右键托盘图标Exit退出

        ; 拖拽文件到程序或关联发送到菜单后运行 这种方法有文件数量限制
        ; 将所有文件路径保存至 %temp% 目录下的指定文件,然后将此文件作为唯一参数传入
        ; 直接运行程序,然后拖拽文件至界面上
        ; 将路径复制到剪贴板,然后将 clip 作为唯一参数传入
        ; 此三种方法没有文件数量限制

        ; editor 编辑器路径,需编辑器能在标题显示文件名
        ; filename 是否只修改文件名
        ; formatName 是否对文件名进行处理 移除首尾空格,多个空格替换为单个,替换非法字符为空
        ; logSave 是否记录log 用于恢复原始名称 路径为 程序所在目录\logtxt
        ; 如需全部恢复,拖拽 logtxt 至 restore.exe上, 部分恢复复制要恢复的所有行到新建文本文档(UTF-8),然后将其拖至 restore.exe上
        ; tipCount 结束后提示修改的项目数
        ; sendto 关联右键发送到菜单,需无参运行程序打开设置进行关联
        ; cp 指定编码,其他程序传入临时文件不能识别编码时设置,如需指定编码,请设置数字标识符
        ; 数字标识符参考 https://learn.microsoft.com/zh-cn/windows/win32/intl/code-page-identifiers
        ; 1为启用,0为禁用

    )", iniPath, "UTF-16")
    IniWrite("D:\OneDrive\Program\Notepad++\notepad++.exe", iniPath, "set", "editor")
    IniWrite(1, iniPath, "set", "filename")
    IniWrite(1, iniPath, "set", "formatName")
    IniWrite(0, iniPath, "set", "sendto")
    IniWrite(1, iniPath, "set", "tipCount")
    IniWrite(1, iniPath, "set", "logSave")
    IniWrite("", iniPath, "set", "cp")
}

editor := IniRead(iniPath, "set", "editor", "")
cp := IniRead(iniPath, "set", "cp", "")
filename := IniRead(iniPath, "set", "filename", 0)
formatName := IniRead(iniPath, "set", "formatName", 0)
tipCount := IniRead(iniPath, "set", "tipCount", 0)
log.logSave := IniRead(iniPath, "set", "logSave", 0)

if cp
    cp := "CP" cp

arr := []
count := 0
g := { temp: "" }


if A_Args.Length = 1
{
    ar := []
    if (InStr(A_Args[1], A_Temp))
    {
        loop parse FileRead(A_Args[1], cp), "`n", "`r"
            ar.Push(A_LoopField)

        if filename
            FilesProcess(ar)
        else
        {
            arr := ar
            g.temp := A_Args[1]
        }
    }
    else if StrLower(A_Args[1]) = "clip"
    {
        loop parse A_Clipboard, "`n", "`r"
            ar.Push(A_LoopField)
        FilesProcess(ar)
    }
}
else if A_Args.Length
    FilesProcess(A_Args)
else
{
    mygui := Gui()
    mygui.Opt("+AlwaysOnTop +ToolWindow")
    mygui.Title := app
    mygui.Add("Text", , "拖拽文件至此进行重命名")
    mygui.Add("Button", , "编辑ini").OnEvent("Click", Set)
    mygui.Show("w150 h70")
    mygui.OnEvent("DropFiles", (GuiObj, GuiCtrlObj, FileArray, X, Y) => (FilesProcess(FileArray), mygui.Destroy()))
    mygui.OnEvent("Escape", (*) => mygui.Destroy())
    mygui.OnEvent("Close", (*) => mygui.Destroy())
    WinWaitClose(mygui.Hwnd)


    Set(*)
    {
        RunWait(iniPath)
        sendToLnk := A_StartMenu "/../SendTo/" app ".lnk"

        if IniRead(iniPath, "set", "sendto", 0)
            CreateLnk(sendToLnk)
        else if FileExist(sendToLnk)
            try FileDelete(sendToLnk)

        CreateLnk(lnk)
        {
            if !IsSendToVisible(lnk)
            {
                try
                    FileDelete(lnk)
                FileCreateShortcut(A_ScriptFullPath, lnk)
            }

            IsSendToVisible(lnk)
            {
                if !FileExist(lnk) || (FileGetShortcut(lnk, &target), target != A_ScriptFullPath)
                    return false
                return true
            }
        }
    }
}

if !arr.Length
    ExitApp()

time := FileGetTime(g.temp)
SplitPath(g.temp, &title, &runDir)
Run(editor ' "' g.temp '"', runDir)

; if FileExist(editor)
; {
;     SplitPath(editor, &exe)
;     title .= " ahk_exe " exe
; }

if hwnd := WinWait(title, , 5)
    WinWaitClose(hwnd)
else
    MsgBox("编辑器可能配置错误")

OnExit(ExitFunc)

if FileGetTime(g.temp) != time
{
    arr2 := []

    loop parse FileRead(g.temp, cp), "`n", "`r"
        arr2.Push(A_LoopField)

    if arr.Length != arr2.Length
    {
        MsgBox("原始文件与目标文件数量不符")
        ExitApp()
    }

    loop arr.Length
    {
        souce := arr[A_Index]
        out := arr2[A_Index]
        if !FileExist(souce)
            continue

        if filename
        {
            SplitPath(souce, , &dir)
            out := dir "\" batchReplace(out)
        }
        else
        {
            SplitPath(out, , &dir, &ext, &name)
            if !DirExist(dir)
            {
                try
                    DirCreate(dir)
                catch
                {
                    log.Push(souce, out, "目标文件夹错误")
                    continue
                }
            }
            out := dir "\" batchReplace(name) "." ext
        }

        if out == souce
            continue

        if FileExist(out)
        {
            log.Push(souce, out, "目标文件已存在")
            continue
        }

        try
        {
            if DirExist(souce)
                DirMove(souce, out)
            else
                FileMove(souce, out)
            log.Push(souce, out)
            count++
        }
        catch Error as e
            log.Push(souce, out, "未知错误: " e.What)
    }
}

batchReplace(str)
{
    if !formatName
        return str

    str := RenameSafe(str)
    str := Trim(str)
    str := StrReplace(str, "  ", " ")
    ; str := StrReplace(str, "@@", "@")
    ; str := StrReplace(str, "##", "#")
    return str
}

ExitFunc(*)
{
    if log.logSave && log.list.Length
        log.Save()
    try
        FileDelete(g.temp)

    if tipCount && count
    {
        ; TrayTip("已处理 " count " 项", app)
        ToolTip(app ": 已处理 " count " 项")
        Sleep(2000)
    }
}

class log
{
    static list := []

    static logSave := true

    static logPath := A_ScriptDir "\log.txt"

    static Push(old, new := "", op := "移动")
    {
        if this.logSave
            this.list.Push([old, new, op])
    }

    static Save()
    {
        s := ""
        for i in this.list
            s .= i[1] "<-->" i[2] "<-->" i[3] "`n"
        FileAppend(s, this.logPath, "UTF-8")
    }
}


FilesProcess(list)
{
    files := ""
    for i in list
        if (FileExist(i))
            loop files i, "DF"
                arr.Push(A_LoopFileFullPath), files .= A_LoopFileFullPath "`n"

    if filename
    {
        files := ""
        for i in arr
        {
            SplitPath(i, &name)
            files .= name "`n"
        }
    }
    files := RTrim(files, "`n")

    guid := Trim(CreateGUID(), "{}")
    if (!guid)
        guid := A_TickCount
    g.temp := A_Temp "\" guid


    if (files)
    {
        try
            FileDelete(g.temp)
        FileAppend(files, g.temp, "UTF-8")
        cp := "UTF-8"
    }
}


#Include <CreateGUID>
#Include <RenameSafe>