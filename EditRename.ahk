;@Ahk2Exe-SetMainIcon     ico.ico
#SingleInstance force
FileEncoding("UTF-8")
version := 9

SplitPath(A_ScriptFullPath, , , , &app)
g := { gui: "", ex: "", rg: "", envNumRule: [1, 3, 1], envDateRule: "yyyy-MM-dd H-mm-ss", hasFolder: false }

GuiEx.Init()
ini.Init(A_ScriptDir "\set.ini")
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

class ini extends iniBase
{
    static Init(path)
    {
        super.Init(path)

        if !FileExist(this.editor)
        {
            MsgBox("未设置编辑器,请设置", app)
            this.editor := FileSelect("1", , app " 请选择要使用的编辑器", "*.exe")
            if this.editor
                this.WriteUpdate(this.editor, "editor")
            else
                ExitApp(1)
        }

        this.Update(version)
    }

    static Default()
    {
        this.Add("gui", "user", 1)
        this.Add("exit", , 0)
        this.Add("muiltTab", , 0)
        this.Add("fastMode", , 0)
        this.Add("env", , 0)
        this.Add("autoRe", , 0)
        ; this.Add("logError", , 0,"n")

        this.Add("editor", "set", , "f")
        this.Add("secondEditor", , , "f")
        this.Add("pathType", , 0)
        this.Add("subFolder", , 0)
        this.Add("subLevel", , 0)
        this.Add("guiX", , 0)
        this.Add("guiY", , 0)
        this.Add("exGui", , 0)
        this.Add("exFile", , 0)
        this.Add("exDir", , 0)
        this.Add("exSys", , 1)
        this.Add("exHide", , 1)
        this.Add("exReadonly", , 1)
        this.Add("exRP", , 1)
        this.Add("envChoose", , 1)
        this.Add("envEditText")

        this.Add(, "envEditArr", ["%n%1000;4;1;"], "ds")
        this.Add(, "re", ["替换多个空白为空;\s{2,}; `;1;2", "替换多个@为单个;@{2,};@;1;2"], "dsa5")
        this.Add(, "reSave", , "ds")
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
        else    ;if ini.logError
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
            return ToolTipEx("未存在可恢复文件")

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
            temp := TempPath()
            FileWrite(RTrim(files, "`n"), temp)

            if RunEditorWait(temp)
            {
                if this.restoreType != 3
                    return

                rArr := []
                loop parse FileRead(temp), "`n", "`r"
                {
                    tmp := StrSplit(A_LoopField, "<-->")
                    if tmp.Length == 2 && FileExist(tmp[2])
                        rArr.Push([tmp[2], tmp[1]])
                }
            }

            TryFileDelete(temp)
        }

        if rArr.Length
        {
            for i in rArr
            {
                try
                {
                    if DirExist(i[1])
                        DirMove(i[1], i[2], ini.fastMode ? "R" : ""), sucsess++
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
            ToolTipEx(app rtype msg)
        }
        else
            ToolTipEx("未存在可恢复文件")
    }
}

class data
{
    static arr := ""
    static subArr := ""
    static currentArr := []
    static path := ""
    static subFolder := -1
    static subLevel := -1
    static pathType := -1
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
                }
                else
                {
                    attrib := i[3]
                    isDir := i[2]
                    pushArr := [path, isDir, attrib]
                }

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
    }

    static Update()
    {
        if !FileExist(this.path) || this.isUpdate
            return

        this.isUpdate := true
        isChange := false

        if ini.subFolder
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
                    nameNoExt := name, ext := ""

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

        files := RTrim(files, "`n")
        Length := StrSplit(files, "`n").Length
        loop this.currentArr.Length - Length - 1
            files .= "`n"

        FileWrite(files, this.path)
        SetTitle(this.currentArr.Length)
        this.subFolder := ini.subFolder
        this.subLevel := ini.subLevel
        this.pathType := ini.pathType
    }
}

FileWrite(str, path, encoding := "UTF-8")
{
    f := FileOpen(path, "w", encoding)
    f.Write(str)
    f.Close()
}

ToolTipEx(s, time := 1000, wait := false)
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
    A_TrayMenu.Default := "界面"
    A_TrayMenu.ClickCount := 2
}

SetTitle(str)
{
    if g.gui
        g.gui.Title := str " - " app
}

TempPath()
{
    if !(guid := StrReplace(Trim(CreateGUID(), "{}"), "-"))
        guid := A_TickCount A_Now
    return A_Temp "\" guid ".txt"
}

TryFileDelete(path)
{
    try
        FileDelete(path)
}

OpenGui()
{
    if g.gui && WinExist(g.gui.hwnd)
        return WinActivate()

    _tips.allowNotActive := false
    g.gui := ui := GuiEx("+AlwaysOnTop +ToolWindow", data.currentArr.Length " - " app)
    ui.Add("Text", , "拖拽文件至此进行重命名")

    AddCheckboxEx("subFolder", , "包含子目录").OnEvent("Click", (ctrl, info) => (ini.subFolder := ctrl.Value, data.Update()))
    ui.AddEditUpDown("层级", "yp", " w50 h18", , ini.subLevel, "subLevel", "遍历的层级,`n太快切换可能会阻塞`n阻塞时切换下 包含子目录 即可").OnEvent("Change", SubLevelChange)

    pathType := ini.pathType
    ui.Add("GroupBox", "xs Section w180 r2", "路径").GetPos(&x, &y)
    full := ui.AddRadio("Section x" x + 10 " y" y + 20 " Checked" (pathType == 0), "全路径")
    full.OnEvent("Click", EditType)
    g.name := name := ui.AddRadio("yp x118 Checked" (pathType == 1), "文件名")
    name.OnEvent("Click", EditType)
    g.nameNoExt := nameNoExt := ui.AddRadio("xs Checked" (pathType == 2), "不带扩展名", , "不带扩展名的文件名")
    nameNoExt.OnEvent("Click", EditType)
    g.ext := ext := ui.AddRadio("yp Checked" (pathType == 3), "扩展名")
    ext.OnEvent("Click", EditType)
    ext.ToolTip := ext.Text

    ui.Add("GroupBox", "xs Section w180 r2 y+20 x" x, "排除").GetPos(&x, &y)
    AddCheckboxEx("exFile", "Section x" x + 10 " y" y + 20, "文件")
    AddCheckboxEx("exDir", "yp", "目录")
    AddCheckboxEx("exRP", "yp", "符号", "通常是符号链接")
    AddCheckboxEx("exReadonly", "xs", "只读")
    AddCheckboxEx("exHide", "yp", "隐藏")
    AddCheckboxEx("exSys", "yp", "系统")

    AddCheckboxEx(var, opt := "", text := "", tips := "") => ui.AddCheckbox(opt " Checked" ini.%var%, text, var, tips)

    ui.Add("GroupBox", "xs Section w180 r1 y+20 x" x, "恢复").GetPos(&x, &y)
    ui.AddRadio("x" x + 10 " y" y + 20, "上次").OnEvent("Click", (*) => log.Restore(1))
    ui.AddRadio("yp", "全部").OnEvent("Click", (*) => log.Restore(2))
    ui.AddRadio("yp", "部分").OnEvent("Click", (*) => log.Restore(3))

    ui.AddButton("xs", "编辑器", "选择默认编辑器`n需编辑器标题能显示文件名").OnEvent("Click", (*) => ChooseEditor())
    ui.AddButton("yp", "备", "选择备用编辑器`n一些类似IDE的编辑器启动较慢`n如已经运行则使用此编辑器,否则使用默认编辑器").OnEvent("Click", (*) => ChooseEditor(true))
    ui.AddButton("yp", "目录", "打开程序所在目录").OnEvent("Click", (*) => Run(A_ScriptDir))
    ui.AddButton("yp", "EX", "
    (
        副界面 其他设置及一些简单编辑
        副界面会跟随在主界面右侧
        如关闭主界面前未关闭副界面
        则下次启动会同时启动副界面
    )").OnEvent("Click", exGui)

    pos := ""
    if ini.guiX || ini.guiY
        pos := " x" ini.guiX " y" ini.guiY
    ui.Show("w200 " pos)
    ui.OnEvent("DropFiles", (GuiObj, GuiCtrlObj, FileArray, X, Y) => BeginRename(FileArray))
    ui.OnClose(CloseG)
    GuiEx.OnMouseMove()

    if ini.exGui
        exGui()

    EditType(ctrl, info)
    {
        switch ctrl
        {
            case full: t := 0
            case name: t := 1
            case nameNoExt: t := 2
            case ext: t := 3
        }
        ini.ChangeKey(t, "pathType")
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
            ini.subLevel := ctrl.Value
            data.Update()
        }
    }

    ChooseEditor(second := false)
    {
        path := ui.FileSelect("1", , app (second ? " 请选择备用编辑器" : " 请选择编辑器"), "*.exe")
        if path
        {
            if !second
                ini.ChangeKey(path, "editor")
            else
                ini.ChangeKey(path, "secondEditor")
        }
    }
}

CloseG(ctrl)
{
    if g.ex && g.ex.HasProp("Hwnd") && WinExist(g.ex.hwnd)
    {
        ini.ChangeKey(1, "exGui")
        CloseEx(g.ex)
    }
    else
        ini.ChangeKey(0, "exGui")

    g.gui.GetPos(&x, &y)
    ini.ChangeKey(x, "guiX")
    ini.ChangeKey(y, "guiY")
    ini.SaveThis()
    g.gui.Destroy()

    if ctrl
    {
        TryFileDelete(data.path)
        ExitApp()
    }
}

ExGui(*)
{
    if g.ex && WinExist(g.ex.hwnd)
    {
        g.ex.Destroy()
        return g.ex := ""
    }

    envArr := [
        ["递增数字", "%n%1;3;1;"],
        ["图包目录命名", "%p%"],
        ["当前时间", "%d%yyyy-MM-dd H-mm-ss;"],
        ["上级目录名称", "%f%"],
        ["文件修改时间", "%t%"],
        ["文件创建时间", "%tc%"],
        ["文件访问时间", "%ta%"],
        ["随机八位数字", "%r%"],
        ["开机毫秒数", "%r2%"],
        ["GUID", "%r3%"],
    ]
    envNameArr := []
    for i in envArr
        envNameArr.Push(i[1])

    g.ex := s := GuiEx("+AlwaysOnTop +ToolWindow", app)

    AddCheckboxEx("exit", , "完成后退出", "仅在外部传入参数及成功命名部分文件后退出`n直接运行程序不会退出")
    AddCheckboxEx("gui", "yp x+20", "修改时显示界面", "关闭后通过直接运行程序或者托盘菜单启动界面")
    AddCheckboxEx("env", "xs", "环境变量", "
    (
        启用时将会在重命名时将包含的变量替换为特殊的内容
        需要计算的可能耗时较久,酌情使用
        可手动在编辑器中添加,或简单通过下面 所有变量 添加
        %f% 上级目录名称
        %p% 图包目录命名  需要计算 [35P-2V-550M]
        %t% 文件修改时间 需要计算
        %tc% 文件创建时间 需要计算
        %ta% 文件访问时间 需要计算
        %r% 随机八位数字
        %r2% 开机毫秒数
        %r3% GUID
        %n% 递增数字 详细说明在所有变量中选择悬浮查看
        %d% 当前时间 详细说明同上
    )")
    AddCheckboxEx("fastMode", "yp x+32", "加快文件夹重命名速度", "副作用可能会遗留部分文件(被其他程序占用),不能移动到其他硬盘")
    AddCheckboxEx("muiltTab", "xs", "多标签编辑器", "多标签编辑器切换标签立即进行重命名")

    AddCheckboxEx("autoRe", "yp", "启用自动替换", "自动替换中存在符合要求规则时自动替换`n`n启用并存在规则时加载大量文件未修改关闭编辑器可能会影响速度`n`n影响不大,可关闭界面或托盘菜单直接退出")

    s.AddButton("yp", "生成规则", "简单生成替换规则").OnEvent("Click", (*) => RuleCreate())
    ; AddCheckboxEx("logError", "yp", "记录失败日志", "用于命名失败时浏览具体失败文件`n保存于 程序目录\logError.txt")

    g.ex.reAuto := s.AddComboBoxEx("自动替换", ini.re, "xs", "w162", , , "规则 搜索项;替换项;是否正则;限定路径`n可通过 生成规则 简单生成", , "w20", , "w20")

    g.ex.reSave := ReSave := s.AddComboBoxEx("替换", ini.reSave, "xs", "w152", , , "只手动替换 规则同上`n点击 替 即时替换", , "w20", , "w20")
    s.AddButton("yp", "替", "使用当前规则在当前文件替换").OnEvent("Click", (*) => Change("re"))

    s.AddText("xs", "编辑器需支持重载,防误操作,全路径以下功能不工作")

    s.AddText("xs", "所有变量")
    envDDL := s.AddDropDownList("w110 yp", envNameArr, ini.envChoose, , "简单说明请悬浮 环境变量 查看`n前3项有详细说明,选择并悬浮查看")
    envDDL.OnEvent("Change", EnvChange)
    s.AddButton("yp", "追", "追加到下面编辑框").OnEvent("Click", (ctrl, info) => envEdit.Text .= (envEdit.Text ? " " : "") envArr[envDDL.Value][2])
    s.AddButton("yp", "替", "替换下面编辑框").OnEvent("Click", (ctrl, info) => envEdit.Text := envArr[envDDL.Value][2])
    envLink := s.AddLink("yp", , , "说明")
    envLink.Text := ""
    envEdit := s.AddComboBoxEx("当前变量", ini.envEditArr, "xs", "w162", , , "只手动替换`n可添加其他内容,但仍需选中环境变量`n可添加变量规则 如附带示例;`n可将常用保存下次调用`n", , "w20", , "w20")
    envEdit.Text := ini.envEditText

    s.AddButton("xs", "前添加", "在当前文件每项前添加当前变量").OnEvent("Click", (*) => Change("before"))
    s.AddButton("yp", "后添加", "在当前文件每项后添加当前变量").OnEvent("Click", (*) => Change("after"))
    s.AddButton("yp", "简转繁", "如转换后字数有变化则失败").OnEvent("Click", (*) => Change("s2t"))
    s.AddButton("yp", "繁转简", "如转换后字数有变化则失败").OnEvent("Click", (*) => Change("t2s"))
    s.AddLink("yp", , "https://github.com/vvyoko/EditRename", "主页", "GitHub")

    AddCheckboxEx(var, opt := "", text := "", tips := "") => s.AddCheckbox(opt " Checked" ini.%var%, text, var, tips)

    g.gui.GetPos(&x, &y, &w, &h)
    s.Show("x" x + w - 10 " y" y)
    s.GetPos(, , &w)
    g.OnMove := OnMove
    g.ex.Change := Change
    SetTimer(g.OnMove, 100)

    s.OnClose(CloseEx)

    EnvChange(ctrl, info)
    {
        ini.ChangeKey(ctrl.Value, "envChoose")
        envLink.Text := ""

        if ctrl.Value <= 3 || StrLen(ctrl.Tips) > 50
            GuiEx.TipsClear()

        switch ctrl.Value
        {
            case 1: ctrl.Tips := "
            (
                规则 初始值;位数;增量;  (如不设置默认为 1;3;1;)

                手动在编辑器中设置规则
                当 包含子目录 时第一项为最后一项,后续为逆序向前
                在第一项 %n% 后跟随规则,后续%n%将按此递增
            )"
            case 2: ctrl.Tips := "只对文件夹命名, 示例 [35P-2V-550M]"
            case 3: ctrl.Tips := "
            (
                规则 时间格式; (如不设置默认格式如下)
                %d%yyyy-MM-dd H-mm-ss; 为 2023-01-29 22-58-29
                详细格式请点击说明查看

                手动在编辑器中设置规则
                当 包含子目录 时第一项为最后一项
                在第一项 %d% 后跟随 时间格式; 后续%d%遵守此规则
            )"
                envLink.Text := '<a id="help" href="https://wyagd001.github.io/v2/docs/lib/FormatTime.htm#Date_Formats">说明</a>'
            default: ctrl.Tips := "简单说明请悬浮 环境变量 查看`n前3项有详细说明,选择并悬浮查看"
        }
    }

    OnMove()
    {
        try
        {
            if !g.ex || (g.ex.HasProp("Hwnd") && !WinExist(g.ex.Hwnd))
            {
                SetTimer(g.OnMove, 0)
                return
            }
            g.gui.GetPos(&x, &y, &w, &h)
            g.ex.Move(x + w - 10, y)
        }
        catch
            SetTimer(g.OnMove, 0)
    }

    Change(str := "")
    {
        ini.ChangeKey(envEdit.Text, "envEditText")

        if !data.currentArr.Length || !FileExist(data.path)
            return STitle("未在编辑状态")
        if str != "re" && !ini.pathType && !GuiEx.Debug
            return STitle("目前为全路径,已跳过")
        if str != "s2t" && str != "t2s" && str != "re" && (!ini.env || !StrLen(envEdit.Text))
            return STitle("未启用环境变量或当前变量为空")

        STitle("处理中...")
        f := FileRead(data.path)

        t := ""
        if str == "s2t" || str == "t2s"
        {
            t := str == "t2s" ? "繁转简" : "简转繁"
            tmp := TS(f, str == "t2s", beforeLen := StrLen(f))
            if (afterLen := StrLen(f)) != beforeLen
                return STitle("字数不正确,已跳过 " beforeLen "/" afterLen)
        }
        else if str == "re"
        {
            t := "替换"
            arr := StrSplit(ReSave.Text, ";")
            if arr.Length == 5 && arr[5] ~= "^[123]$"
            {
                ini.pathType := arr[5]
                switch ini.pathType
                {
                    case 1: g.Name.Value := 1
                    case 2: g.nameNoExt.Value := 1
                    case 3: g.ext.Value := 1
                }
                STitle("更新中...")
                data.Update()
                f := FileRead(data.path)
                arr.RemoveAt(5)
            }

            if arr.Length != 4
                return STitle("未设置替换规则或规则不正确 " arr.Length)

            try
                tmp := RegStrExReplace(f, arr)
            catch
                return STitle("规则可能出错")
        }
        else if (isBefore := str == "before") || str == "after"
        {
            t := isBefore ? "前添加" : "后添加"

            rule := envEdit.Text
            if RegExMatch(rule, "%d%((.+);)", &m)
            {
                g.envDateRule := m[2]
                rule := StrReplace(rule, m[1])
                m := ""
            }
            if RegExMatch(rule, "%n%((\d+);(\d+);(\d+);)", &m)
            {
                if IsNumber(m[2])
                    g.envNumRule[1] := m[2]
                if IsNumber(m[3])
                    g.envNumRule[2] := m[3]
                if IsNumber(m[4])
                    g.envNumRule[3] := m[4]
                rule := StrReplace(rule, m[1])
            }
            tmp := ""
            arr := StrSplit(RegExReplace(f, isBefore ? "mS)^" : "mS)$", rule))
            if arr.Length == data.currentArr.Length
            {
                for i in arr
                    tmp .= Env(i, data.currentArr[A_Index][1], data.currentArr[A_Index][2]) "`n"
            }
            else
            {
                if GuiEx.Debug
                    ToolTipEx("直接替换出错,循环替换")
                loop parse f, "`n", "`r"
                    tmp .= Env(RegExReplace(A_LoopField, isBefore ? "^" : "$", rule), data.currentArr[A_Index][1], data.currentArr[A_Index][2]) "`n"
            }
            tmp := RTrim(tmp, "`n")
        }

        FileWrite(tmp, data.path)
        STitle(t "处理完成")

        TS(string, toSimp := 0, max := 0)
        {
            static LCMAP_SIMPLIFIED_CHINESE := 0x02000000, LCMAP_TRADITIONAL_CHINESE := 0x04000000
            if !max
                max := StrLen(string)

            VarSetStrCapacity(&output, max + 10)
            DllCall("kernel32\LCMapStringW", "UInt", DllCall("kernel32\GetUserDefaultLCID"), "UInt", !toSimp ? LCMAP_TRADITIONAL_CHINESE : LCMAP_SIMPLIFIED_CHINESE, "Str", string, "Int", -1, "Str", output, "Int", max + 10)
            string := output
            VarSetStrCapacity(&output, -1)
            Return string
        }
    }

    STitle(str) => s.Title := str " " A_TickCount
}

CloseEx(ctrl)
{
    ctrl.Destroy()
    g.ex := ""

    if g.rg && g.rg.HasProp("Hwnd") && WinExist(g.rg.hwnd)
    {
        g.rg.Destroy()
        g.rg := ""
    }
}

RuleCreate()
{
    if g.rg && WinExist(g.rg.hwnd)
    {
        g.rg.Destroy()
        return g.rg := ""
    }

    g.rg := rg := GuiEx("+ToolWindow +AlwaysOnTop", "生成规则")
    description := rg.AddTextEdit("说明", , "w300 x57", "清除广告网址")
    description.OnEvent("Change", (*) => RuleGenerate())
    Needle := rg.AddTextEdit("搜索项", "xs", "w300", "[0-9a-z]{5,}\.[a-z]{3}[@ ]")
    Needle.OnEvent("Change", (*) => RuleGenerate())
    Replacement := rg.AddTextEdit("替换项", "Xs", "w300")
    Replacement.OnEvent("Change", (*) => RuleGenerate())
    isRe := rg.AddCheckbox("xs Checked1", "是否正则")
    isRe.OnEvent("Click", (*) => RuleGenerate())
    ignoreCase := rg.AddCheckbox("yp Checked1", "忽略大小写", , "为搜索正则设置忽略大小写参数")
    ignoreCase.OnEvent("Click", (*) => RuleGenerate())
    rg.AddText("yp", "限定路径: ")
    pathType := rg.AddDropDownList("yp w90", ["全路径", "文件名", "不带扩展名", "扩展名"], 3)
    pathType.OnEvent("Change", (*) => RuleGenerate())
    rg.AddButton("xs", "生成").OnEvent("Click", RuleGenerate)
    rule := rg.AddEdit("yp x57 w300 ReadOnly", , , "生成的规则")
    rg.AddText()
    path := rg.AddTextEdit("路径", "xs", "x57 w300 r4", "D:\1024sS.coM aa-11.net.mp4", , "拖入文件或手动填写路径")
    path.OnEvent("change", RuleTest)
    result := rg.AddTextEdit("结果", "Xs", "x57 w300 ReadOnly r4", , , "测试结果")
    rg.AddButton("xs", "添加到自动替换", "添加后需要点 + 保存").OnEvent("Click", (*) => g.ex.reAuto.Text := rule.Value)
    rg.AddButton("yp", "添加到替换", "添加后需要点 + 保存`n全路径时不工作").OnEvent("Click", (*) => pathType.Value > 1 ? g.ex.reSave.Text := rule.Value : "")
    rg.AddButton("yp", "直接替换", "直接在当前编辑器中替换").OnEvent("Click", (*) => pathType.Value > 1 ? (g.ex.reSave.Text := rule.Value, g.ex.Change.Call("re")) : "")
    rg.AddLink("yp x+20", , "https://wyagd001.github.io/v2/docs/misc/RegEx-QuickRef.htm", "正则参考", "正则版本 PCRE 8.30`n更多详情请浏览")

    rg.Show()
    rg.OnEvent("DropFiles", (GuiObj, GuiCtrlObj, FileArray, X, Y) => (path.Value := FileArray[1], RuleTest(path, 1)))
    rg.OnClose(CloseRG)

    CloseRG(*)
    {
        rg.Destroy()
        g.rg := ""
    }

    RuleGenerate(*)
    {
        r := Needle.Value

        if isRe.Value
        {
            if ignoreCase.Value
            {
                if RegExMatch(r, "(.+)\)", &flags)
                {
                    if !InStr(flags[1], "i")
                        r := "i" r
                }
                else
                    r := "i)" r
            }
            else if RegExMatch(r, "((.+)\))", &flags) && InStr(flags[2], "i")
            {
                flag := StrReplace(flags[2], "i")
                r := StrReplace(r, flags[1], flag (StrLen(flag) ? ")" : ""))
            }
        }

        r := description.Value ";" r

        r .= ";" Replacement.Value ";" isRe.Value ";" pathType.Value - 1
        rule.Value := r
        RuleTest(path, 1)
    }

    RuleTest(ctrl, info)
    {
        souce := Trim(ctrl.Value, '"')
        if ctrl.Value != souce
            ctrl.Value := souce

        if !rule.Value
        {
            RuleGenerate()
            if !rule.Value
                return
        }


        SplitPath(souce, &name, &dir, &ext, &nameNoext)

        if DirExist(souce) && InStr(name, ".")
            nameNoext := name, ext := ""

        arr := StrSplit(rule.Value, ";")

        try
            switch arr[5]
            {
                case 0: return result.Value := RegStrExReplace(souce, arr)
                case 1: nameNoExt := RegStrExReplace(name, arr), ext := ""
                case 2: nameNoExt := RegStrExReplace(nameNoExt, arr)
                case 3: ext := RegStrExReplace(ext, arr)
            }
        catch
            return result.Value := "规则出错"

        result.Value := dir "\" nameNoExt (ext ? "." ext : "")
    }
}


RunEditorWait(path, bool := false)
{
    time := FileGetTime(path)
    SplitPath(path, &title, &runDir)
    editor := ini.editor
    if ini.secondEditor && FileExist(ini.secondEditor)
    {
        SplitPath(ini.secondEditor, &editorName)
        if editorName && WinExist("ahk_exe " editorName)
            editor := ini.secondEditor
    }
    Run(editor ' "' path '"', runDir)

    if hwnd := WinWait(title, , 3)
    {
        if ini.muiltTab
        {
            while WinExist(title)
                Sleep(20)
        }
        else
            WinWaitClose(hwnd)

        if FileGetTime(path) != time || bool
            return true
    }
    else
        ToolTipEx("编辑器可能配置错误")
}

BeginRename(list)
{
    if data.currentArr.Length
        return

    if ini.gui && !g.gui
        OpenGui()

    data.Init(list)

    sucsess := 0
    failure := 0

    if RunEditorWait(data.path, ini.autoRe && ini.reArr.Length)
    {
        arr2 := []

        loop parse FileRead(data.path), "`n", "`r"
            arr2.Push(A_LoopField)

        if data.currentArr.Length != arr2.Length
        {
            ToolTipEx("原始文件与目标文件数量不符 " data.currentArr.Length "/" arr2.Length, 2000, true)
            ExitApp(1)
        }

        length := arr2.Length
        g.envNumRule := [1, 3, 1]
        g.envDateRule := "yyyy-MM-dd H-mm-ss"
        loop arr2.Length
        {
            index := !ini.subFolder || !ini.subLevel ? A_Index : arr2.Length + 1 - A_Index

            souce := data.currentArr[index][1]
            isDir := data.currentArr[index][2]
            out := arr2[index]

            if length - index > 100
            {
                SetTitle(index "/" arr2.Length)
                length := index
            }

            if ini.exDir && isDir
                continue

            if ini.exFile && !isDir
                continue

            if ini.exSys && InStr(data.currentArr[index][3], "S")
                continue

            if ini.exHide && InStr(data.currentArr[index][3], "H")
                continue

            if ini.exReadonly && InStr(data.currentArr[index][3], "R")
                continue

            if ini.exRP && InStr(data.currentArr[index][3], "L")
                continue

            if !FileExist(souce)
                continue

            if ini.env
                out := Env(out, souce, isDir)


            if ini.pathType
            {
                SplitPath(souce, &name, &dir, &ext, &nameNoExt)

                if ini.pathType == 1
                {
                    name := out
                    if isDir && InStr(name, ".")
                        nameNoExt := name, ext := ""
                }
                else
                {
                    if ini.pathType == 2
                    {
                        nameNoExt := out
                        if isDir && InStr(name, ".")
                            ext := ""
                    }
                    else if ini.pathType == 3
                    {
                        ext := out
                        if isDir && InStr(name, ".")
                            nameNoExt := name, ext := ""
                    }
                }
            }
            else
            {
                SplitPath(out, &name, &dir, &ext, &nameNoExt)

                if isDir && InStr(name, ".")
                    nameNoExt := name, ext := ""

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

            out := dir "\" nameNoExt (ext ? "." ext : "")

            if ini.autoRe
            {
                for i in ini.reArr
                {
                    try
                    {
                        if !i[5]
                            out := RegStrExReplace(out, i)
                        else
                        {
                            switch i[5]
                            {
                                case 1: nameNoExt := RegStrExReplace(name, i), ext := ""
                                case 2: nameNoExt := RegStrExReplace(nameNoExt, i)
                                case 2: ext := RegStrExReplace(ext, i)
                            }
                            out := dir "\" nameNoExt (ext ? "." ext : "")
                        }
                    }
                    catch
                        ini.reArr.RemoveAt(A_Index)
                }
            }

            if out == souce
                continue

            try
            {
                if isDir
                    DirMove(souce, out, ini.fastMode ? "R" : "")
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

    TryFileDelete(data.path)

    log.Save()

    willExit := !g.gui || (A_Args.Length && ini.exit && sucsess)

    if willExit && g.gui && WinExist(g.gui.Hwnd)
        CloseG(0)

    if sucsess || failure
    {
        msg := app ": 已处理 " sucsess "/" data.currentArr.Length " 项"
        if failure
            msg .= "; 失败: " failure " 项"
        ToolTipEx(msg, 2000, willExit)
    }
    else
        ToolTipEx("未发生修改")

    if willExit
        ExitApp()

    if sucsess || failure
        SetTitle(sucsess "/" failure "/" data.currentArr.Length)
    else
        SetTitle(0)

    data.currentArr := []
}

RegStrExReplace(s, arr) => (arr[4] ? RegExReplace : StrReplace)(s, arr[2], arr[3])

Env(str, path, isFolder := false)
{
    if InStr(str, "%p%")
    {
        if isFolder
        {
            p := 0
            v := 0
            size := 0
            pExt := Map("jpeg", true, "jpg", true, "png", true, "webp", true, "bmp", true)
            vExt := Map("mp4", true, "mkv", true, "wmv", true, "avi", true, "webm", true, "ts", true)
            loop files path "\*.*", "FR"
            {
                ext := StrLower(A_LoopFileExt)
                if pExt.Has(ext)
                    p++
                else if vExt.Has(ext)
                    v++
                size += A_LoopFileSize
            }

            s := "["
            if p
                s .= p "P-"
            if v
                s .= v "V-"
            s .= GetSizeReadableByte(size, 0) "]"
            str := StrReplace(str, "%p%", s)
        }
        else
            str := StrReplace(str, "%p%")
    }

    if InStr(str, "%f%")
    {
        SplitPath(path, , &folder)
        str := StrReplace(str, "%f%", StrReplace(RegExReplace(folder, ".+\\"), ":"))
    }

    if InStr(str, "%d%")
    {
        t := FileGetTime(path)

        if RegExMatch(str, "%d%((.+);)", &ft)
        {
            g.envDateRule := ft[2]
            str := StrReplace(str, ft[1])
        }

        str := StrReplace(str, "%d%", FormatTime(t, g.envDateRule))
    }

    if InStr(str, "%n%")
    {
        if RegExMatch(str, "%n%((\d+);(\d+);(\d+);)", &rule)
        {
            if IsNumber(rule[2])
                g.envNumRule[1] := rule[2]
            if IsNumber(rule[3])
                g.envNumRule[2] := rule[3]
            if IsNumber(rule[4])
                g.envNumRule[3] := rule[4]
            str := StrReplace(str, rule[1])
        }

        n := g.envNumRule[1]
        len := StrLen(n)
        loop g.envNumRule[2] - len
            n := "0" n
        str := StrReplace(str, "%n%", n)
        g.envNumRule[1] += g.envNumRule[3]
    }

    if InStr(str, "%t%")
        str := StrReplace(str, "%t%", GetFormatTime())

    if InStr(str, "%tc%")
        str := StrReplace(str, "%tc%", GetFormatTime("C"))

    if InStr(str, "%ta%")
        str := StrReplace(str, "%ta%", GetFormatTime("A"))

    if InStr(str, "%r%")
        str := StrReplace(str, "%r%", Random(10000000, 99999999))

    if InStr(str, "%r2%")
        str := StrReplace(str, "%r2%", A_TickCount)

    if InStr(str, "%r3%")
        str := StrReplace(str, "%r3%", StrReplace(Trim(CreateGUID(), "{}"), "-"))

    return str

    GetFormatTime(WhichTime := "M") => FormatTime(FileGetTime(path, WhichTime), "yyyy-MM-dd H-mm-ss")
}

#Include <CreateGUID>
#Include <GuiEx>
#Include <iniBase>
#Include <GetSizeReadable>