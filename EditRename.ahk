#SingleInstance force
; #NoTrayIcon

iniPath := A_ScriptDir "\set.ini"

if !FileExist(iniPath)
{
    FileAppend("
    (
        ; 不要调整行顺序,不要删除行,可以编辑文件夹,只传入一个文件无效
        ; 拖拽文件到程序或关联发送到菜单后运行 这种方法有文件数量限制
        ; 将所有文件路径保存至 %temp% 目录下的指定文件,然后将此文件作为唯一参数传入
        ; 直接运行程序,然后拖拽文件至界面上
        ; 将路径复制到剪贴板,然后将 clip 作为唯一参数传入
        ; 此三种方法没有文件数量限制

        ; editor 编辑器路径,需编辑器能在标题显示文件名
        ; sendto 关联右键发送到菜单,需无参运行程序打开设置进行关联
        ; tipCount 结束后提示修改的项目数
        ; logSave 是否记录log
        ; logPath log保存位置,为空则为 程序所在目录\log.txt
        ; cp 指定编码,其他程序传入临时文件不能识别编码时设置,如需指定编码,请设置数字标识符
        ; 数字标识符参考 https://learn.microsoft.com/zh-cn/windows/win32/intl/code-page-identifiers
        ; 1为启用,0为禁用

    )", iniPath, "UTF-16")
    IniWrite("D:\OneDrive\Program\Notepad++\notepad++.exe", iniPath, "set", "editor")
    IniWrite(0, iniPath, "set", "sendto")
    IniWrite(1, iniPath, "set", "tipCount")
    IniWrite(1, iniPath, "set", "logSave")
    IniWrite("", iniPath, "set", "logPath")
    IniWrite("", iniPath, "set", "cp")
}

editor := IniRead(iniPath, "set", "editor", "")
cp := IniRead(iniPath, "set", "cp", "")
tipCount := IniRead(iniPath, "set", "tipCount", 1)
log.logSave := IniRead(iniPath, "set", "logSave", 1)
log.logPath := IniRead(iniPath, "set", "logPath", "")

if (!log.logPath)
    log.logPath := A_ScriptDir "\log.txt"
if cp
    cp := "CP" cp

arr := []
count := 0
g := { temp: "" }


if A_Args.Length = 1
{
    if (InStr(A_Args[1], A_Temp))
    {
        g.temp := A_Args[1]
        loop parse FileRead(g.temp, cp), "`n", "`r"
            arr.Push(A_LoopField)
    }
    else if StrLower(A_Args[1]) = "clip"
    {
        ar := []
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
    mygui.Title := "编辑重命名"
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
        sendToLnk := A_StartMenu "/../SendTo/编码重命名.lnk"

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
    str := RenameSafe(str)
    str := Trim(str)
    str := StrReplace(str, "  ", " ")
    str := StrReplace(str, "@@", "@")
    str := StrReplace(str, "##", "#")
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
        TrayTip("已处理 " count " 项", "重命名")
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
        s := RTrim(s, "`n")
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