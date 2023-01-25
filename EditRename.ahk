;@Ahk2Exe-SetMainIcon     ico.ico
#SingleInstance force
FileEncoding("UTF-8")

SplitPath(A_ScriptFullPath, , , , &app)
g := { gui: "" }

ini.Init()
TrayMenu()

if A_Args.Length = 1
{
    tmpArr := []
    if (InStr(A_Args[1], A_Temp))
    {
        loop parse FileRead(A_Args[1]), "`n", "`r"
            tmpArr.Push(A_LoopField)
        BeginRename(tmpArr)
    }
    else if StrLower(A_Args[1]) = "clip"
    {
        loop parse A_Clipboard, "`n", "`r"
            tmpArr.Push(A_LoopField)
        BeginRename(tmpArr)
    }
    else if FileExist(A_Args[1])
        BeginRename(A_Args)
}
else if A_Args.Length
    BeginRename(A_Args)
else
    OpenGui()

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

    static ReadLoop(Section, arr)
    {
        loop
        {
            if !(var := this.Read(A_Index, , Section))
                break
            arr.Push(var)
        }
    }

    static map := {
        gui: [0, "user"],
        muiltTab: [0, "user"],
        logError: [0, "user"],
        editor: ["", "set"],
        secondEditor: ["", "set"],
        pathType: [0, "set"],
        subFolder: [0, "set"],
        subLevel: [0, "set"],
        filter: ["", "set"],
        guiX: [0, "set"],
        guiY: [0, "set"],
    }

    static Init()
    {
        if !FileExist(this.path)
            this.Create()

        for i in this.map.OwnProps()
            this.%i% := this.Get(i)

        if !FileExist(this.editor)
        {
            MsgBox("未设置编辑器,请设置", app)
            this.editor := FileSelect("1", , app " 请选择要使用的编辑器", "*.exe")
            if this.editor
                this.setWrite(this.editor, "editor")
            else
                ExitApp(1)
        }

        if !IsNumber(this.subLevel)
            this.subLevel := 0

        this.filterArr := []
        if this.filter
        {
            for i in StrSplit(this.filter)
                if InStr("RASHNDOCTL", i)
                    this.filterArr.Push(i)
        }

        this.reArr := []
        this.ReadLoop("reArr", this.reArr)
        loop this.reArr.Length
        {
            _r := StrSplit(this.reArr[A_Index], ";")
            if _r.Length == 4
                this.reArr[A_Index] := [_r[2], _r[3], _r[4]]
        }

        loop this.reArr.Length
        {
            index := this.reArr.Length + 1 - A_Index
            if index && Type(this.reArr[index]) != "Array"
                this.reArr.RemoveAt(index)
        }
    }

    static Create()
    {
        FileAppend("
        (
            ; 其他说明请查看 https://github.com/vvyoko/EditRename
            ; ini编辑完会在下一次运行时生效
            ; 不要调整行顺序,不要删除行,尽量在一项操作完成再进行后继续操作
            ; 关闭编辑器时会自动进行重命名
            ; 修改错误时右键托盘图标退出或直接关闭界面

            ; gui 在修改时显示界面 (为0时直接运行程序或者托盘启动界面)
            ; muiltTab 多标签编辑器切换标签立即进行重命名
            ; logError 记录失败日志,保存于 程序目录\logError.txt
            ; 1为启用,0为禁用

            ; reArr 自定义替换 (规则  ;搜索项;替换项;是否正则)
            ;       自带2个示例为未启用状态
            ;       如需启用请删除每项前面的 说明加; ,如 ;替换多个空白为空
            ;       增加需要递增序号,如 3=;%{2,};%;1
            ;       在启用时加载大量文件未修改关闭编辑器可能会影响速度
            ;       影响不大,可关闭界面或托盘菜单直接退出

        )", this.path, "UTF-16")

        this.setWrite(1, "gui")
        this.setWrite(0, "muiltTab")
        this.setWrite(0, "logError")

        this.Write(";替换多个空白为空;\s{2,}`; `;1", 1, "reArr")
        this.Write(";替换多个@为单个;@{2,}`;@`;1", 2, "reArr")

        this.setWrite("", "editor")
        this.setWrite("", "secondEditor")
        this.setWrite(1, "pathType")
        this.setWrite(0, "subFolder")
        this.setWrite(1, "subLevel")
        this.setWrite("", "filter")
    }
}

class log
{
    static list := []
    static listError := []
    static logLast := A_ScriptDir "\logLast.txt"
    static log := A_ScriptDir "\log.txt"
    static logError := A_ScriptDir "\logError.txt"
    static restoreType := 0

    static Push(old, new, error := true)
    {
        if !error
            this.list.Push([old, new])
        else if ini.logError
            this.listError.Push([old, new])
    }

    static Save()
    {
        if this.list.Length
        {
            s := ""
            for i in this.list
                s .= i[1] "<-->" i[2] "`n"
            FileAppend(s, this.log)
            FileWrite(s, this.logLast)
            this.list := []
        }

        if this.listError.Length
        {
            s := ""
            for i in this.listError
                s .= i[1] "<-->" i[2] "`n"
            FileWrite(s, this.logError)
            this.listError := []
        }
    }

    static Restore(t)
    {
        this.restoreType := t
        p := t == 1 ? this.logLast : this.log
        sucsess := 0
        failure := 0
        rArr := []
        files := ""

        if !FileExist(p)
            return ToolTipEx("未存在可恢复文件", 1000)

        loop parse FileRead(p), "`n", "`r"
        {
            tmp := StrSplit(A_LoopField, "<-->")
            if tmp.Length == 2 && FileExist(tmp[2])
            {
                rArr.Push([tmp[2], tmp[1]])
                files .= A_LoopField "`n"
            }
        }

        if t == 3 && files
        {
            files := RTrim(files, "`n")
            temp := TempPath()
            FileWrite(files, temp)

            time := FileGetTime(temp)
            SplitPath(temp, &title, &runDir)
            Run(ini.editor ' "' temp '"', runDir)

            if hwnd := WinWait(title, , 5)
            {
                WinWaitClose(hwnd)
                if g.gui && this.restoreType != 3
                    return

                if FileGetTime(temp) != time
                {
                    rArr := []
                    loop parse FileRead(temp), "`n", "`r"
                    {
                        tmp := StrSplit(A_LoopField, "<-->")
                        if tmp.Length == 2 && FileExist(tmp[2])
                            rArr.Push([tmp[2], tmp[1]])
                    }
                }
            }
            try
                FileDelete(temp)
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
            msg := " 共成功: " sucsess " 项"
            if failure
                msg .= "; 失败: " failure " 项"
            ToolTipEx(app rtype msg, 1000)
        }
        else
            ToolTipEx("未存在可恢复文件", 1000)
    }
}

class data
{
    static arr := ""
    static arrInit := ""
    static subArr := ""
    static currentArr := []
    static path := ""
    static subFolder := -1
    static subLevel := -1
    static pathType := -1
    static filter := ""
    static isUpdate := false

    static Init(arr)
    {
        this.subFolder := -1
        this.subLevel := -1
        this.pathType := -1
        this.path := TempPath()
        this.CreateArr(arr)
        this.Write2File()
    }

    static CreateArr(list, new := false)
    {
        subArr := []
        arr := []
        isSub := ini.subFolder && ini.subLevel
        this.loopLength := 0

        if !new
            this.arrInit := []

        SetTitle("加载中...")
        for i in list
        {
            if FileExist(path := new ? i[1] : i)
            {
                if !new
                {
                    path := GetFullPath(path, &attrib)
                    isDir := InStr(attrib, "D") ? true : false
                    pushArr := [path, isDir, attrib]
                    this.arrInit.Push(pushArr)
                }
                else
                {
                    attrib := i[3]
                    isDir := i[2]
                    pushArr := [path, isDir, attrib]
                }

                if AttribFilter(attrib)
                    continue

                subArr.Push(pushArr)
                arr.Push(pushArr)

                if isDir && isSub
                    LoopFilesLevel(path, subArr, ini.subLevel)
            }
        }

        this.arr := arr
        this.subArr := subArr
        this.currentArr := isSub ? subArr : arr

        ; https://www.autohotkey.com/boards/viewtopic.php?style=19&p=392871#p392871
        LoopFilesLevel(rootFolder, arr, level := 1, enumerateFiles := true)
        {
            Loop Files, rootFolder . "\*", "D" . (enumerateFiles ? "F" : "")
            {
                if AttribFilter(A_LoopFileAttrib)
                    continue

                arr.Push([A_LoopFileFullPath, 0, A_LoopFileAttrib])

                if arr.Length - 100 > this.loopLength
                    SetTitle(this.loopLength := arr.Length)

                if (level > 1 && InStr(A_LoopFileAttrib, "D"))
                {
                    arr[arr.Length][2] := 1
                    LoopFilesLevel(A_LoopFilePath, arr, level - 1, enumerateFiles)
                }
            }
        }

        GetFullPath(f, &attrib)
        {
            loop files f, "DF"
            {
                attrib := A_LoopFileAttrib
                return A_LoopFileFullPath
            }
        }

        AttribFilter(attrib)
        {
            for i in ini.filterArr
                if InStr(attrib, i)
                    return true
        }
    }

    static Update()
    {
        if !FileExist(this.path) || this.isUpdate
            return

        this.isUpdate := true
        isChange := false
        if this.filter != ini.filter
            this.CreateArr(this.arrInit.Clone(), true), isChange := true
        else if ini.subFolder
        {
            if ini.subLevel && (this.subFolder != ini.subFolder || this.subLevel != ini.subLevel)
                this.CreateArr(this.arr, true), isChange := true
            else if this.subLevel != ini.subLevel
                this.currentArr := this.arr, isChange := true
            else if this.pathType != ini.pathType
                this.currentArr := this.subArr, isChange := true
        }
        else if this.pathType != ini.pathType || (this.subFolder != ini.subFolder && ini.subLevel)
            this.currentArr := this.arr, isChange := true

        if isChange
            this.Write2File()
        this.isUpdate := false
    }

    static Write2File()
    {
        files := ""
        SetTitle("加载中...")
        if ini.pathType
        {
            for i in this.currentArr
            {
                SplitPath(i[1], &name, &dir, &ext, &nameNoExt)
                if i[2] && InStr(name, ".")
                {
                    nameNoExt := name
                    ext := ""
                }

                switch ini.pathType
                {
                    case 1: files .= name "`n"
                    case 2: files .= nameNoExt "`n"
                    case 3: files .= ext "`n"
                }
            }
        }
        else
            for i in this.currentArr
                files .= i[1] "`n"

        FileWrite(RTrim(files, "`n"), this.path)
        SetTitle(this.currentArr.Length)
        this.subFolder := ini.subFolder
        this.subLevel := ini.subLevel
        this.pathType := ini.pathType
        this.filter := ini.filter
    }
}

FileWrite(str, path)
{
    f := FileOpen(path, "w")
    f.Write(str)
    f.Close()
}

ToolTipEx(s, time := 2000, wait := false)
{
    ToolTip(s)
    if wait
        Sleep(time)
    else
        SetTimer(() => ToolTip(), -time)
}

TrayMenu()
{
    A_TrayMenu.Delete()
    A_TrayMenu.Add("界面", (*) => OpenGui())
    A_TrayMenu.Add("恢复上次", (*) => log.Restore(1))
    A_TrayMenu.Add("退出", (*) => ExitApp())
}

SetTitle(str)
{
    if g.gui
        g.gui.Title := str " - " app
}

TempPath()
{
    if !(guid := Trim(CreateGUID(), "{}"))
        guid := A_TickCount
    return A_Temp "\" guid ".txt"
}

OpenGui()
{
    if g.gui && WinExist(g.gui.hwnd)
        return WinActivate()

    g.gui := Gui()
    g.gui.SetFont(, "Segoe UI")
    g.gui.Opt("+AlwaysOnTop +ToolWindow")
    SetTitle(data.currentArr.Length)
    g.gui.Add("Text", , "拖拽文件至此进行重命名")

    g.gui.Add("Checkbox", "Checked" ini.subFolder, "包含子目录").OnEvent("Click", (ctrl, info) => (ini.setWrite(ini.subFolder := ctrl.Value, "subFolder"), data.Update()))
    g.gui.Add("Text", "yp ", "层级")
    g.gui.Add("Edit", "yp Number w50 h18", "").OnEvent("Change", SubLevelChange)
    g.gui.Add("UpDown", "yp", ini.subLevel)

    pathType := ini.pathType
    g.gui.Add("GroupBox", "xs Section w180 r2", "路径").GetPos(&x, &y)
    full := g.gui.Add("Radio", "Section x" x + 10 " y" y + 20 " Checked" (pathType == 0), "全路径")
    full.OnEvent("Click", EditType)
    name := g.gui.Add("Radio", "yp Checked" (pathType == 1), "文件名")
    name.OnEvent("Click", EditType)
    ext := g.gui.Add("Radio", "xs Checked" (pathType == 3), "扩展名")
    ext.OnEvent("Click", EditType)
    nameNoExt := g.gui.Add("Radio", "yp Checked" (pathType == 2), "不带扩展名")
    nameNoExt.OnEvent("Click", EditType)

    g.gui.Add("GroupBox", "xs Section w180 r1 y+20 x" x, "过滤").GetPos(&x, &y)
    dir := g.gui.Add("Checkbox", "x" x + 10 " y" y + 20 " Checked" InStr(ini.filter, "D"), "目录")
    dir.OnEvent("Click", FilterChange)
    sys := g.gui.Add("Checkbox", "yp Checked" InStr(ini.filter, "S"), "系统")
    sys.OnEvent("Click", FilterChange)
    hide := g.gui.Add("Checkbox", "yp Checked" InStr(ini.filter, "H"), "隐藏")
    hide.OnEvent("Click", FilterChange)

    g.gui.Add("GroupBox", "xs Section w180 r1 y+20 x" x, "恢复").GetPos(&x, &y)
    g.gui.Add("Radio", "x" x + 10 " y" y + 20, "上次").OnEvent("Click", (*) => log.Restore(1))
    g.gui.Add("Radio", "yp", "全部").OnEvent("Click", (*) => log.Restore(2))
    g.gui.Add("Radio", "yp", "部分").OnEvent("Click", (*) => log.Restore(3))

    g.gui.Add("Button", "xs", "编辑器").OnEvent("Click", (*) => ChooseEditor())
    g.gui.Add("Button", "yp", "备").OnEvent("Click", (*) => ChooseEditor(true))
    g.gui.Add("Button", "yp", "目录").OnEvent("Click", (*) => Run(A_ScriptDir))
    g.gui.Add("Button", "yp", "ini").OnEvent("Click", (*) => Run(ini.path))

    pos := ""
    if ini.guiX || ini.guiY
        pos := " x" ini.guiX " y" ini.guiY
    g.gui.Show("w200 " pos)
    g.gui.OnEvent("DropFiles", (GuiObj, GuiCtrlObj, FileArray, X, Y) => BeginRename(FileArray))
    g.gui.OnEvent("Escape", ExitG)
    g.gui.OnEvent("Close", ExitG)

    EditType(ctrl, info)
    {
        switch ctrl
        {
            case full: t := 0
            case name: t := 1
            case nameNoExt: t := 2
            case ext: t := 3
        }
        ini.setWrite(ini.pathType := t, "pathType")
        data.Update()
    }

    SubLevelChange(ctrl, info)
    {
        static time := ""
        SetTimer(() => Update(time := A_TickCount), -200)

        Update(tick)
        {
            if time != A_TickCount
                return

            ini.setWrite(ini.subLevel := ctrl.Value, "subLevel")
            data.Update()
        }
    }

    FilterChange(ctrl, info)
    {
        switch ctrl
        {
            case dir: IniChange("D", ctrl.Value)
            case sys: IniChange("S", ctrl.Value)
            case hide: IniChange("H", ctrl.Value)
        }
        data.Update()

        IniChange(attrib, add)
        {
            if add && !InStr(ini.filter, attrib)
            {
                ini.setWrite(ini.filter .= attrib, "filter")
                ini.filterArr.Push(attrib)
            }
            else if !add && InStr(ini.filter, attrib)
            {
                ini.setWrite(ini.filter := StrReplace(ini.filter, attrib), "filter")
                loop ini.filterArr.Length
                {
                    if ini.filterArr[ini.filterArr.Length + 1 - A_Index] == attrib
                    {
                        ini.filterArr.RemoveAt(ini.filterArr.Length + 1 - A_Index)
                        break
                    }
                }
            }
        }
    }

    ChooseEditor(second := false)
    {
        g.gui.Opt("+OwnDialogs")
        path := FileSelect("1", , app (second ? " 请选择备用编辑器" : " 请选择编辑器"))
        if path
        {
            if !second
                ini.setWrite(ini.editor := path, "editor")
            else
                ini.setWrite(ini.secondEditor := path, "secondEditor")
        }
    }

    ExitG(*)
    {
        g.gui.GetPos(&x, &y)
        ini.setWrite(x, "guiX")
        ini.setWrite(y, "guiY")
        try
            FileDelete(data.path)
        ExitApp()
    }
}

BeginRename(list)
{
    if data.currentArr.Length
        return

    if ini.gui && !g.gui
        OpenGui()

    data.Init(list)

    time := FileGetTime(data.path)
    SplitPath(data.path, &title, &runDir)
    editor := ini.editor
    if ini.secondEditor && FileExist(ini.secondEditor)
    {
        SplitPath(ini.secondEditor, &editorName)
        if editorName && WinExist("ahk_exe " editorName)
            editor := ini.secondEditor
    }
    Run(editor ' "' data.path '"', runDir)
    sucsess := 0
    failure := 0

    if hwnd := WinWait(title, , 5)
    {
        if ini.muiltTab
        {
            while WinExist(title)
                Sleep(20)
        }
        else
            WinWaitClose(hwnd)

        if FileGetTime(data.path) != time || ini.reArr.Length
        {
            arr2 := []

            loop parse FileRead(data.path), "`n", "`r"
                arr2.Push(A_LoopField)

            if data.currentArr.Length != arr2.Length
            {
                MsgBox("原始文件与目标文件数量不符")
                ExitApp(1)
            }

            length := arr2.Length
            loop arr2.Length
            {
                index := arr2.Length + 1 - A_Index
                souce := data.currentArr[index][1]
                isDir := data.currentArr[index][2]
                out := arr2[index]

                if length - index > 100
                {
                    SetTitle(index "/" arr2.Length)
                    length := index
                }

                if !FileExist(souce)
                    continue

                if ini.pathType
                {
                    SplitPath(souce, &name, &dir, &ext, &nameNoExt)

                    if ini.pathType == 1
                        name := out
                    else
                    {
                        if isDir && InStr(name, ".")
                        {
                            nameNoExt := name
                            ext := ""
                        }
                        if ini.pathType == 2
                            name := out (ext ? "." ext : "")
                        else if ini.pathType == 3
                            name := nameNoExt (out ? "." out : "")
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
                            failure++
                            log.Push(souce, out)
                            continue
                        }
                    }
                }

                for i in ini.reArr
                    name := (i[3] ? RegExReplace : StrReplace)(name, i[1], i[2])

                out := dir "\" name

                if out == souce
                    continue

                if FileExist(out)
                {
                    failure++
                    log.Push(souce, out)
                    continue
                }

                try
                {
                    if isDir
                        DirMove(souce, out)
                    else
                        FileMove(souce, out)
                    log.Push(souce, out, false)
                    sucsess++
                }
                catch Error as e
                {
                    failure++
                    log.Push(souce, out)
                }
            }
        }
    }
    else
        MsgBox("编辑器可能配置错误")

    try
        FileDelete(data.path)

    log.Save()

    if sucsess || failure
    {
        msg := app ": 已处理 " sucsess "/" data.currentArr.Length " 项"
        if failure
            msg .= "; 失败: " failure " 项"
        ToolTipEx(msg, , !g.gui)
    }

    if !g.gui
        ExitApp()

    if sucsess || failure
        SetTitle(sucsess "/" failure "/" data.currentArr.Length)
    else
        SetTitle(0)

    data.currentArr := []
}

#Include <CreateGUID>
#Include <RenameSafe>