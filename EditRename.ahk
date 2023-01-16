;@Ahk2Exe-SetMainIcon     ico.ico

#SingleInstance force
FileEncoding("UTF-8")
; #NoTrayIcon


SplitPath(A_ScriptFullPath, , , , &app)

ini.Init()
TrayMenu
tmpArr := []

if A_Args.Length = 1
{
    if (InStr(A_Args[1], A_Temp))
    {
        loop parse FileRead(A_Args[1], ini.cp), "`n", "`r"
            tmpArr.Push(A_LoopField)

        if ini.filename
            BeginRename(tmpArr, , , ini.cp)
        else
            BeginRename(tmpArr, ini.filename, A_Args[1])
    }
    else if StrLower(A_Args[1]) = "clip"
    {
        loop parse A_Clipboard, "`n", "`r"
            tmpArr.Push(A_LoopField)
        BeginRename(tmpArr)
    }
}
else if A_Args.Length
    BeginRename(A_Args)
else
    myG.OpenGui()

class ini
{
    static path := A_ScriptDir "\set.ini"

    static Get(key)
    {
        if this.map.HasProp(key)
            return this.Read(key, this.map.%key%[1], this.map.%key%[2])
    }

    static Read(Key, default := "", section := "") => IniRead(this.path, section, key, default)

    static setWrite(value, key) => this.Write(value, key, this.map.%key%[2])

    static Write(value := "", Key := "", section := "")
    {
        static sectionSave := section
        if section
            sectionSave := section
        IniWrite(value, this.path, sectionSave, key)
    }

    static Delete(section, key) => IniDelete(this.path, section, key)

    static ReadLoop(Section, arr)
    {
        loop
        {
            if !(var := this.Read(A_Index, , Section))
                break
            arr.Push(var)
        }

        loop
        {
            if arr.Length < A_Index
                break

            var := arr[A_Index]
            temp := []
            for i in arr
                if var = i
                    temp.Push(A_Index)

            temp.RemoveAt(1)
            loop temp.Length
                arr.RemoveAt(temp[temp.Length - A_Index + 1])
        }
    }

    static WriteLoop(Section, arr)
    {
        loop
        {
            if (var := this.Read(arr.Length + A_Index, , Section))
                this.Delete(Section, arr.Length + A_Index)
            else
                break
        }

        for i in arr
            if this.Read(arr.Length + A_Index, , Section) != i
                this.Write(i, A_Index, Section)
    }

    static map := {
        editor: ["", "set"],
        secondEditor: ["", "set"],
        gui: [0, "set"],
        muiltTab: [0, "set"],
        filename: [0, "set"],
        formatName: [0, "set"],
        tipCount: [0, "set"],
        logSave: [0, "set"],
        sendto: [0, "set"],
        cp: ["", "set"],
        guiX: [0, "tmp"],
        guiY: [0, "tmp"],
    }

    static Init()
    {
        if !FileExist(this.path)
            this.Create()

        for i in this.map.OwnProps()
            this.%i% := this.Get(i)

        if !this.editor || !FileExist(this.editor)
        {
            MsgBox("未设置编辑器,请设置", app)
            this.editor := FileSelect("1", , app " 请选择要使用的编辑器", "*.exe")
            if this.editor
                this.setWrite(this.editor, "editor")
            else
                ExitApp(1)
        }
        if this.cp
            this.cp := "CP" this.cp

        this.reArr := []
        this.ReadLoop("reArr", this.reArr)
        loop this.reArr.Length
        {
            _r := StrSplit(this.reArr[A_Index], ";")
            if _r.Length == 4
                this.reArr[A_Index] := [_r[2], _r[3], _r[4]]
        }
    }

    static Create()
    {
        FileAppend("
        (
            ; 不要调整行顺序,不要删除行, 可以更改程序文件名,只传入一个文件无效
            ; 关闭编辑器时会自动进行重命名,显示界面时点击关闭手动退出

            ; 拖拽文件到程序图标 这种方法有文件数量限制
            ; 将所有文件路径保存至 %temp% 目录下的指定文件,然后将此文件作为唯一参数传入
            ; 直接运行程序,然后拖拽文件至界面上
            ; 将路径复制到剪贴板,然后将 clip 作为唯一参数传入
            ; 此三种方法没有文件数量限制

            ; editor 编辑器路径,需编辑器能在标题显示文件名
            ; secondEditor 备用编辑器,当此编辑器在运行时切换至此编辑器,用于启动较慢的备用编辑器,比方vscode...
            ; gui 是否在修改时显示界面,用于修改路径及恢复及退出
            ; muiltTab 多标签编辑器切换标签立即进行重命名
            ; filename 修改文件名类型
            ; formatName 是否对文件名进行处理 移除首尾空格,替换非法字符为空
            ; logSave 是否记录log 用于恢复原始名称,部分恢复保留需要恢复的行,其余删除然后关闭
            ; tipCount 结束后提示修改的项目数
            ; cp 指定编码,其他程序传入临时文件不能识别编码时设置,如需指定编码,请设置数字标识符 参考 https://learn.microsoft.com/zh-cn/windows/win32/intl/code-page-identifiers
            ; reArr 为自定义替换,添加请按序号递增  ;搜索项;替换项;是否正则
            ; 1为启用,0为禁用

        )", this.path, "UTF-16")


        this.setWrite("", "editor")
        this.setWrite("", "secondEditor")
        this.setWrite(1, "gui")
        this.setWrite(0, "muiltTab")
        this.setWrite(1, "filename")
        this.setWrite(1, "formatName")
        this.setWrite(1, "tipCount")
        this.setWrite(1, "logSave")
        this.setWrite("", "cp")

        this.Write(";\s{2,}`; `;1", 1, "reArr")
        ; this.Write(";@{2,}`;@`;1", 2, "reArr")
        ; this.Write(";#{2,}`;#`;1", 3, "reArr")
    }
}

class log
{
    static list := []

    static lastLog := A_ScriptDir "\lastLog.txt"
    static log := A_ScriptDir "\log.txt"

    static Push(old, new := "", op := "移动")
    {
        if ini.logSave
            this.list.Push([old, new, op])
    }

    static Save()
    {
        s := ""
        for i in this.list
            s .= i[1] "<-->" i[2] "<-->" i[3] "`n"
        FileAppend(s, this.log)

        try
            FileDelete(this.lastLog)
        FileAppend(s, this.lastLog)
        this.list := []
    }

    static Restore(t)
    {
        p := t == 1 ? this.lastLog : this.log
        sucsess := 0
        failure := 0
        rArr := []
        files := ""

        if !FileExist(p)
            return

        loop parse FileRead(p), "`n", "`r"
        {
            if (A_LoopField ~= "<-->移动$")
            {
                tmp := StrSplit(A_LoopField, "<-->")
                if tmp.Length == 3 && FileExist(tmp[2])
                {
                    rArr.Push([tmp[2], tmp[1]])
                    files .= A_LoopField "`n"
                }
            }
        }

        if t == 3 && files
        {
            files := RTrim(files, "`n")
            guid := Trim(CreateGUID(), "{}")
            if (!guid)
                guid := A_TickCount
            _temp := A_Temp "\" guid ".txt"
            FileAppend(files, _temp)

            _time := FileGetTime(_temp)
            SplitPath(_temp, &_title, &_runDir)
            Run(ini.editor ' "' _temp '"', _runDir)

            if _hwnd := WinWait(_title, , 5)
            {
                WinWaitClose(_hwnd)
                if myG.gui && myG.restore != 3
                    return

                if FileGetTime(_temp) != _time
                {
                    rArr := []
                    loop parse FileRead(_temp), "`n", "`r"
                    {
                        if (A_LoopField ~= "<-->移动$")
                        {
                            tmp := StrSplit(A_LoopField, "<-->")
                            if tmp.Length == 3 && FileExist(tmp[2])
                                rArr.Push([tmp[2], tmp[1]])
                        }
                    }

                }
            }
        }

        if rArr.Length
        {
            for i in rArr
            {
                try
                {
                    if DirExist(i[1])
                        DirMove(i[1], i[2]), sucsess++
                    else if FileExist(i[1])
                        FileMove(i[1], i[2]), sucsess++
                }
                catch
                    failure++
            }

            switch t {
                case 1: rtype := " 恢复上次"
                case 2: rtype := " 恢复全部"
                case 3: rtype := " 恢复部分"
            }
            ToolTipEx(app rtype " 共成功: " sucsess " 项; 失败: " failure " 项", 1000)
        }
        else
            ToolTipEx("未存在可恢复文件", 1000)
    }
}

ToolTipEx(s, time := 2000, wait := false)
{
    ToolTip(s)
    if wait
        Sleep(time)
    else
        SetTimer(() => ToolTip(), -time)
}


class myG
{
    static temp := ""
    static arr := []
    static blankLine := 0
    static restore := 0
    static gui := ""

    static OpenGui()
    {
        if this.gui && WinExist(this.gui.hwnd)
            return WinActivate()

        this.gui := Gui()
        this.gui.SetFont(, "Segoe UI")
        this.gui.Opt("+AlwaysOnTop +ToolWindow")
        this.gui.Title := this.arr.Length " - " app
        this.gui.Add("Text", , "拖拽文件至此进行重命名")

        filename := ini.filename
        rs1 := this.gui.Add("GroupBox", "Section w180 r2", "路径")
        rs1.GetPos(&x, &y)

        full := this.gui.Add("Radio", "Section x" x + 10 " y" y + 20 " Checked" (filename == 0), "全路径")
        full.OnEvent("Click", EditType)
        name := this.gui.Add("Radio", "yp Checked" (filename == 1), "文件名")
        name.OnEvent("Click", EditType)
        ext := this.gui.Add("Radio", "xs Checked" (filename == 3), "扩展名")
        ext.OnEvent("Click", EditType)
        nameNoExt := this.gui.Add("Radio", "yp Checked" (filename == 2), "不带扩展名")
        nameNoExt.OnEvent("Click", EditType)


        rs2 := this.gui.Add("GroupBox", "xs Section w180 r1 y+20 x" x, "恢复")
        rs2.GetPos(&x, &y)
        this.gui.Add("Radio", "x" x + 10 " y" y + 20, "上次").OnEvent("Click", (*) => log.Restore(this.restore := 1))
        this.gui.Add("Radio", "yp", "全部").OnEvent("Click", (*) => log.Restore(this.restore := 2))
        this.gui.Add("Radio", "yp", "部分").OnEvent("Click", (*) => log.Restore(this.restore := 3))


        this.gui.Add("Button", "xs", "自定义编辑器").OnEvent("Click", ChooseEditor)
        this.gui.Add("Button", "yp x+18", "更多设置").OnEvent("Click", (*) => Run(ini.path))

        pos := ""
        if ini.guiX || ini.guiY
            pos := " X" ini.guiX " y" ini.guiY
        this.gui.Show("w200 " pos)
        this.gui.OnEvent("DropFiles", (GuiObj, GuiCtrlObj, FileArray, X, Y) => BeginRename(FileArray))
        this.gui.OnEvent("Escape", ExitG)
        this.gui.OnEvent("Close", ExitG)

        EditType(ctrl, Info)
        {
            switch ctrl
            {
                case full: t := 0
                case name: t := 1
                case nameNoExt: t := 2
                case ext: t := 3
            }
            ini.filename := t
            ini.setWrite(t, "filename")

            if !FileExist(this.temp) || !this.arr.Length
                return

            files := ""
            if t == 0
                for i in this.arr
                    files .= i "`n"
            files := FilenameType(this.arr, files)

            loop this.blankLine
                files .= "`n"

            f := FileOpen(this.temp, "w")
            f.Write(files)
            f.Close()
        }

        ChooseEditor(*)
        {
            this.gui.Opt("+OwnDialogs")
            path := FileSelect("1", , app " 请选择编辑器")
            if path
                ini.setWrite(ini.editor := path, "editor")
        }

        ExitG(*)
        {
            this.gui.GetPos(&x, &y)
            ini.setWrite(x, "guiX")
            ini.setWrite(y, "guiY")
            try
                FileDelete(this.temp)
            ExitApp()
        }
    }
}

FilenameType(arr, files := "")
{
    if filename := ini.filename
    {
        files := ""
        for i in arr
        {
            SplitPath(i, &name, &dir, &ext, &nameNoExt)
            switch filename
            {
                case 1: files .= name "`n"
                case 2: files .= nameNoExt "`n"
                case 3: files .= ext "`n"
            }
        }
    }
    return RTrim(files, "`n")
}

BeginRename(list, notfull := true, tmep := "", cp := "")
{
    if ini.gui && !myG.gui
        myG.OpenGui()

    arr := list

    if notfull || !tmep
    {
        arr := []
        files := ""
        for i in list
            if (FileExist(i))
                loop files i, "DF"
                    arr.Push(A_LoopFileFullPath), files .= A_LoopFileFullPath "`n"

        guid := Trim(CreateGUID(), "{}")
        if (!guid)
            guid := A_TickCount
        tmep := A_Temp "\" guid ".txt"

        files := FilenameType(arr, files)

        if (files)
        {
            try
                FileDelete(tmep)
            FileAppend(files, tmep)
        }
    }

    myG.temp := tmep
    myG.arr := arr
    ;空白的行用于填充
    myG.blankLine := 0
    loop
    {
        if !myG.arr[myG.arr.Length - A_Index + 1]
            myG.blankLine ++
        else
            break
    }
    if myG.gui
        myG.gui.Title := arr.Length " - " app

    time := FileGetTime(tmep)
    SplitPath(tmep, &title, &runDir)
    editor := ini.editor
    if ini.secondEditor && FileExist(ini.secondEditor)
    {
        SplitPath(ini.secondEditor, &editorName)
        if editorName && WinExist("ahk_exe " editorName)
            editor := ini.secondEditor
    }

    Run(editor ' "' tmep '"', runDir)
    count := 0

    if hwnd := WinWait(title, , 5)
    {
        if ini.muiltTab
            WinWaitNotActive(title)
        else
            WinWaitClose(hwnd)

        if FileGetTime(tmep) != time || ini.formatName
        {
            arr2 := []

            loop parse FileRead(tmep, cp), "`n", "`r"
                arr2.Push(A_LoopField)

            if arr.Length != arr2.Length
            {
                MsgBox("原始文件与目标文件数量不符")
                ExitApp(1)
            }

            loop arr.Length
            {
                souce := arr[A_Index]
                out := arr2[A_Index]
                if !FileExist(souce)
                    continue

                if filename := ini.filename
                {
                    SplitPath(souce, &name, &dir, &ext, &nameNoExt)
                    switch filename
                    {
                        case 1: out := dir "\" batchReplace(out)
                        case 2: out := dir "\" batchReplace(out (ext ? "." ext : ""))
                        case 3: out := dir "\" batchReplace(nameNoExt (out ? "." out : ""))
                    }
                }
                else
                {
                    SplitPath(out, &name, &dir)
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
                    out := dir "\" batchReplace(name)
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
    }
    else
        MsgBox("编辑器可能配置错误")

    try
        FileDelete(tmep)

    if ini.logSave && log.list.Length
        log.Save()

    if ini.tipCount && count
        ToolTipEx(app ": 已处理 " count "/" arr.Length " 项", , !myG.gui)

    if myG.gui
    {
        if count
            myG.gui.Title := count "/" arr.Length " - " app
        else
            myG.gui.Title := "0 - " app
    }
    else
        ExitApp()

    batchReplace(str)
    {
        if ini.formatName
            str := Trim(RenameSafe(str))

        for i in ini.reArr
            if Type(i) == "Array"
                str := (i[3] ? RegExReplace : StrReplace)(str, i[1], i[2])

        return str
    }
}

TrayMenu()
{
    A_TrayMenu.Delete()
    A_TrayMenu.Add("界面", (*) => myG.OpenGui())
    A_TrayMenu.Add("恢复上次", (*) => log.Restore(1))
    A_TrayMenu.Add("退出", (*) => ExitApp())
}
#Include <CreateGUID>
#Include <RenameSafe>