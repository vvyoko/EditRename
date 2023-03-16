;@Ahk2Exe-SetMainIcon     ico.ico
#SingleInstance force
version := 14
FileEncoding("CP0")

app := "EditRename"
env.retsore()
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
    MainGui()


class ini extends iniBase
{
    static Init(path)
    {
        super.Init(path)

        if this.noEditMode
            this.gui := true
        else if !FileExist(this.editor)
        {
            MsgBox("未设置编辑器,请设置", app)
            this.editor := FileSelect("1", , app " 请选择要使用的编辑器", "*.exe")
            if this.editor
                this.WriteUpdate(this.editor, "editor")
            else
                ExitApp(1)
        }

        if this.version < 10 && this.envEditArr.Length
        {
            for i in this.envEditArr
                this.envEditArr[A_Index] := RegExReplace(i, "%([fptcar23nd]{1,2})%", "<$1>")
            this.WriteLoop("envEditArr")
        }

        if this.version < 13 && (this.re.Length || this.reSave.Length)
        {

            if this.re.Length
            {
                for i in this.re
                    this.re[A_Index] .= ";"
                this.WriteLoop("re")
                this.Get("re")
            }

            if this.reSave.Length
            {

                for i in this.reSave
                    this.reSave[A_Index] .= ";"
                this.WriteLoop("reSave")
                this.Get("reSave")
            }
        }

        _tips.disable := this.disableTips
        for i in this.property
            exp.type.Push(i), env.arr.Push([i, "<" i ">"])
        this.Update(version)
    }

    static Default()
    {
        this.Add("gui", "set", 1)
        this.Add("exit", , 0)
        this.Add("muiltTab", , 0)
        this.Add("fastMode", , 0)
        this.Add("disableTips", , 0)
        this.Add("existNum", , 0)
        this.Add("env", , 0, "c")
        this.Add("autoRe", , 0, "c")
        this.Add("editor", "set", , "f")
        this.Add("secondEditor", , , "f")
        this.Add("pathType", , 0, "c")
        this.Add("subFolder", , 0, "c")
        this.Add("subLevel", , 1, "c")
        this.Add("guiX", , 0)
        this.Add("guiY", , 0)
        this.Add("exGui", , 0)
        this.Add("exFile", , 0, "c")
        this.Add("exDir", , 0, "c")
        this.Add("exSys", , 1, "c")
        this.Add("exHide", , 1, "c")
        this.Add("exReadonly", , 1, "c")
        this.Add("exRP", , 1, "c")
        this.Add("envChoose", , 1)
        this.Add("envEditText")
        this.Add("actionChoose", , 1)
        this.Add("diff", , 0)
        this.Add("ld", , 0)
        this.Add("autoRefresh", , 0)
        this.Add("previewFull", , 0)
        this.Add("noEditMode", , 0)
        this.Add("trim", , 0)
        this.Add("safe", , 0)
        this.Add("guiMX", , 0)
        this.Add("guiMY", , 0)
        this.Add("undo", , 0)

        this.Add(, "envEditArr", , "ds")
        this.Add(, "re", ["替换多个空白为空;\s{2,}; `;1;2;", "替换多个@为单个;@{2,};@;1;2;"], "dsa6")
        this.Add(, "reSave", , "ds")
        this.Add("reSaveText")
        this.Add(, "tag", , "ds")
        this.Add("tagText")
        this.Add("tagLast", , 0)
        this.Add(, "property", , "dsm")
        this.Add(, "classify", , "ds")
    }
}

class log
{
    ;正常日志
    static list := []
    ;错误日志
    static listError := []
    ;最后日志路径
    static logLast := A_ScriptDir "\logLast.txt"
    ;正常日志路径
    static log := A_ScriptDir "\log.txt"
    ;错误日志路径
    static logError := A_ScriptDir "\logError.txt"
    ;恢复类型
    static restoreType := 0

    ;追加日志
    static Push(old, new, error := true)
    {
        if !error
            this.list.Push([old, new])
        else    ;if ini.logError
            this.listError.Push([old, new])
    }

    ;保存日志
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

    ;恢复日志
    static Restore(t)
    {
        this.restoreType := t
        p := t = 1 ? this.logLast : this.log
        success := 0
        failure := 0
        arr := []
        files := ""

        if !FileExist(p)
            return ToolTipEx("未存在可恢复文件")

        for i in StrSplit(FileRead(p), "`n")
        {
            tmp := StrSplit(i, "<-->")
            if tmp.Length = 2 && FileExist(tmp[2])
            {
                arr.Push([tmp[2], tmp[1]])
                files .= i "`n"
            }
        }

        if t = 3 && files
        {
            temp := TempPath()
            FileWrite(RTrim(files, "`n"), temp)
            if RunEditorWait(temp, , false)
            {
                if this.restoreType != 3
                    return
                arr := []
                for i in StrSplit(FileRead(temp), "`n")
                {
                    tmp := StrSplit(i, "<-->")
                    if tmp.Length = 2 && FileExist(tmp[2])
                        arr.Push([tmp[2], tmp[1]])
                }
            }
            TryFileDelete(temp)
        }

        if !arr.Length
            return ToolTipEx("未存在可恢复文件")

        loop arr.Length
        {
            index := arr.Length + 1 - A_Index
            i := arr[index]
            try
            {
                if DirExist(i[1])
                    DirMove(i[1], i[2], ini.fastMode ? "R" : ""), success++
                else if FileExist(i[1])
                    FileMove(i[1], i[2]), success++
            }
            catch
                failure++
        }

        switch t {
            case 1: rtype := " 恢复上次"
            case 2: rtype := " 恢复全部"
            case 3: rtype := " 恢复部分"
        }
        msg := " 共成功: " success " 项"
        if failure
            msg .= "; 失败: " failure " 项"
        ToolTipEx(app rtype msg)
    }
}

class data
{
    ;原始传入文件数组
    static sp := ""
    ;子目录文件数组
    static subSp := ""
    ;当前数组,为上两项的内存指向
    static currentSp := []
    ;保存待重命名列表界面跳过文件
    static continueMap := Map()
    ;临时文件路径
    static path := ""
    ;是否在编辑状态
    static length => this.currentSp.Length
    static inEdit => this.Length && FileExist(this.path)
    static time => Get(this.path, "time")
    static timeSave := 0
    ;生成时间,如果时间未变则表示文件未修改
    static InitTime := 0
    static subFolder := -1
    static subLevel := -1
    static pathType := -1
    static isUpdate := false
    static version := 0
    static title := 0
    static undo := ""
    static undoVersion := -1
    ;读取当前临时文件
    static Read => FileExist(this.path) ? FileRead(this.path) : ""
    ;恢复
    static Restore() => (this.title := 0, this.sp := this.subSp := this.undo := "", this.currentSp := [], this.continueMap := Map(), TryFileDelete(this.path), this.path := "")

    ;初始化并读取并写入临时文件
    static Init(arr)
    {
        this.subFolder := -1
        this.subLevel := -1
        this.pathType := -1
        this.path := TempPath(&title)
        this.title := title
        this.CreateArr(arr)
        this.Write2File()
        this.InitTime := this.time
        this.version++
    }

    ;加载文件并生成数组
    static CreateArr(list, new := false)
    {
        this.sp := []
        this.subSp := []
        isSub := ini.subFolder && ini.subLevel
        this.loopLength := 0

        MTitle("加载中...")
        for i in list
        {
            if FileExist(path := new ? i.souce : i)
            {
                if !new
                {
                    path := GetFullPath(path, &attrib)
                    isDir := InStr(attrib, "D") ? true : false
                }
                else
                {
                    attrib := i.attrib
                    isDir := i.isDir
                }
                pushSp := pathBase(path, isDir, attrib)
                this.subSp.Push(pushSp)
                this.sp.Push(pushSp)

                if isDir && isSub
                {
                    try
                        LoopFilesLevel(path, this.subSp, ini.subLevel)
                    catch
                        return
                }
            }
        }

        this.currentSp := isSub ? this.subSp : this.sp

        ;循环子文件夹层级 https://www.autohotkey.com/boards/viewtopic.php?style=19&p=392871#p392871
        LoopFilesLevel(rootFolder, arr, level := 1, enumerateFiles := true)
        {
            Loop Files, rootFolder . "\*", "D" . (enumerateFiles ? "F" : "")
            {
                arr.Push(pathBase(A_LoopFileFullPath, false, A_LoopFileAttrib))

                if arr.Length - 100 > this.loopLength
                    MTitle(this.loopLength := arr.Length)

                if (level > 1 && InStr(A_LoopFileAttrib, "D"))
                {
                    arr[arr.Length].isDir := true
                    arr[this.subSp.Length].isDir := true
                    LoopFilesLevel(A_LoopFilePath, arr, level - 1, enumerateFiles)
                }
            }
        }

        ;从短路径获取长路径及属性
        GetFullPath(f, &attrib)
        {
            loop files f, "DF"
            {
                attrib := A_LoopFileAttrib
                return A_LoopFileFullPath
            }
        }
    }

    ;根据属性更新数据
    static Update()
    {
        if !FileExist(this.path) || this.isUpdate
            return

        this.isUpdate := true
        isChange := false

        if ini.subFolder
        {
            ;包含子文件夹 且  (包含子文件夹发生更改 或  层级发生更改)
            if ini.subLevel && (this.subFolder != ini.subFolder || this.subLevel != ini.subLevel)
                this.CreateArr(this.sp, true), isChange := true
            ;层级变为0
            else if this.subLevel != ini.subLevel
                this.currentSp := this.sp, isChange := true
            ;路径发生更改
            else if this.pathType != ini.pathType
                this.currentSp := this.subSp, isChange := true
        }
        ;路径发生更改 或  (包含子目录发生更改 且 层级不为0)
        else if this.pathType != ini.pathType || (this.subFolder != ini.subFolder && ini.subLevel)
            this.currentSp := this.sp, isChange := true

        if isChange
            this.Write2File()
        this.isUpdate := false
    }

    ;将数组写入临时文件
    static Write2File()
    {
        this.subFolder := ini.subFolder
        this.subLevel := ini.subLevel
        this.pathType := ini.pathType

        MTitle("加载中...")
        files := ""
        for i in this.currentSp
            files .= i.ToTmp(A_Index)
        if !this.length
            return
        FileWrite(files, this.path)
        MTitle(this.Length)
    }

    static TmpToArr(wait := false, read := unset)
    {
        arr := StrSplit(IsSet(read) ? read : this.Read, "`n")
        if this.length != arr.Length
        {
            _tips.Clear()
            _tips.disable := true
            ToolTipEx("原始文件与目标文件数量不符 " this.length "/" arr.Length, 2000, wait)
            SetTimer(() => _tips.disable := ini.disableTips, -2000)
            return -1
        }
        return arr
    }
}

;文件路径核心
class pathBase
{
    ;目标路径
    _out => this.dir "\" this._name

    ;路径是否更改
    IsChange => this._out !== this.souce

    time => Get(this.souce, "time")
    timeC => Get(this.souce, "timeC")
    size => Get(this.souce, "size")
    sizeK => Get(this.souce, "sizeK")
    sizeM => Get(this.souce, "sizeM")

    imgW => this.Get("System.Image.HorizontalSize")
    imgH => this.Get("System.Image.VerticalSize")
    vidW => this.Get("System.Video.FrameWidth")
    vidH => this.Get("System.Video.FrameHeight")
    duration => (IsNumber(n := this.Get("System.Media.Duration")) ? n / 10000000 : "")
    aspectRatio => (IsNumber(this.imgW) && IsNumber(this.imgH) ? this.imgW / this.imgH : IsNumber(this.vidW) && IsNumber(this.vidH) ? this.vidW / this.vidH : "")

    ;缓存读取的属性
    propertyMap := Map()

    Get(Key)
    {
        if !this.propertyMap.Has(Key)
            this.propertyMap[key] := ShellProperty(this.dirSave, this.nameSave, key)
        return this.propertyMap[Key]
    }

    __New(path, isDir, attrib := "")
    {
        SplitPathEx(path, &name, &dir, &ext, &nameNoExt, isDir)
        this.souce := path
        this.dir := this.dirSave := dir
        this._name := this.nameSave := name
        this._nameNoExt := nameNoExt
        this._ext := ext
        this.attrib := attrib
        this.isDir := isDir
        this.count := 0
        this.diff := ""
        this.diffVersion := 0
        this.ld := ""
        this.ldVersion := 0
        this.lastOut := ""
        this.lastSouce := ""
        this.lastVersion := 0
    }

    ;路径批量操作  t 1动作 -1刷新 0正常
    static Batch(sp, out, attrib, t := 0)
    {
        if ini.exDir && sp.isDir
            return -1
        if ini.exFile && !sp.isDir
            return -1
        if ini.exSys && InStr(attrib, "S")
            return -1
        if ini.exHide && InStr(attrib, "H")
            return -1
        if ini.exReadonly && InStr(attrib, "R")
            return -1
        if ini.exRP && InStr(attrib, "L")
            return -1

        if t = 0 && !FileExist(sp.souce)
            return -1

        if t < 1 && data.timeSave = data.time
            return

        this.FromTmp(sp, out, ini.env ? true : false)

        if t < 1
            edit.RE(sp)

        if ini.trim
            sp.nameNoExt := Trim(sp.nameNoExt)

        if ini.safe
            sp.nameNoExt := RenameSafe(sp.nameNoExt)
    }

    static FromTmp(sp, out, isenv := false)
    {
        switch ini.pathType
        {
            case 0: sp.out := isenv ? env.exec(out, sp) : out
            case 1: sp.name := isenv ? env.exec(out, sp) : out
            case 2: sp.nameNoExt := isenv ? env.exec(out, sp) : out
            case 3: sp.ext := isenv ? env.exec(out, sp) : out
        }
    }

    ToTmp(index)
    {
        switch ini.pathType
        {
            case 0: return this.out IsLastLine(index)
            case 1: return this.Name IsLastLine(index)
            case 2: return this.nameNoExt IsLastLine(index)
            case 3: return this.ext IsLastLine(index)
        }
    }

    diffAndLDSet(full := false)
    {
        out := full ? this._out : this._name
        souce := full ? this.souce : this.nameSave

        if this.lastOut != out || this.lastSouce != this.souce
            this.lastOut := out, this.lastSouce := souce, this.lastVersion++

        if ini.diff && this.diffVersion != this.lastVersion
            this.diff := net.Diff(souce, out), this.diffVersion := this.lastVersion

        if ini.ld && this.ldVersion != this.lastVersion
        {
            if net.hasNet
                this.ld := net.LD(souce, out)
            else if this.diff
            {
                s := StrReplace(this.diff, "<->")
                this.ld := Round(StrLen(StrReplace(s, " ")) / 2)
            }
            this.ldVersion := this.lastVersion
        }
    }

    ;设置目标路径
    out
    {
        set
        {
            if Value == this._out
                return
            SplitPathEx(Value, &name, &dir, &ext, &nameNoExt, this.isDir)
            this._name := name
            this.dir := dir
            this._ext := ext
            this._nameNoExt := nameNoExt
        }
        get => this._out
    }

    ;设置名称
    name
    {
        set
        {
            if Value == this._name
                return
            this._name := Value
            SplitPathEx(this._out, , , &ext, &nameNoExt, this.isDir)
            this._nameNoExt := nameNoExt
            this._ext := ext
        }
        get => this._name
    }

    ;设置名称不带后缀名
    nameNoExt
    {
        set
        {
            if Value == this._nameNoExt
                return
            this._nameNoExt := Value
            this._name := Value (this._ext ? "." this._ext : "")
        }
        get => this._nameNoExt
    }

    ;设置后缀名
    ext
    {
        set
        {
            if this.isDir || Value == this._ext
                return
            this._ext := Value
            this._name := this._nameNoExt (Value ? "." Value : "")
        }
        get => this._ext
    }

    ;按 替换 中的规则执行替换
    Replace(var, arr)
    {
        if arr[6]
        {
            if Type(arr[6]) != "Array"
                arr[6] := exp.String2Arr(&(s := ";" arr[6]))

            if !exp.Exec(arr[6], this)
                return
        }
        count := 0
        if arr[4] = 1
            this.%var% := RegExReplace(this.%var%, arr[2], arr[3], &count)
        else
            this.%var% := StrReplace(this.%var%, arr[2], arr[3], arr[4] != 2, &count)
        this.count += count
    }

    ;移除原始路径到目标路径 s成功 f失败
    Move(&s, &f)
    {
        if !this.IsChange
            return 0
        try
        {
            if this.dirSave !== this.dir && !DirExist(this.dir)
                DirCreate(this.dir)

            if ini.existNum
                this.out := PathConflicts(this._out, this.isDir)

            if this.isDir
                DirMove(this.souce, this._out, ini.fastMode ? "R" : "")
            else
                FileMove(this.souce, this._out)

            log.Push(this.souce, this._out, false)
            s++
        }
        catch
        {
            log.Push(this.souce, this._out)
            f++
        }
    }
}

;全局变量
class g
{
    ;主界面
    static gui := ""
    ;副界面
    static ex := ""
    ;更多界面
    static mg := ""
    static running := false

    ;无需编辑器模式等待此变量
    static wait := true

    static pathTypeChange := ""

    static _refresh := ""

    static AddCheckboxEx(s, var, opt := "", text := "", tips := "") => s.AddCheckbox(opt " Checked" ini.%var%, text, var, tips)

    static Refresh()
    {
        if !this._refresh
            this._refresh := Refresh
        SetTimer(this._refresh, -100)

        Refresh()
        {
            if ini.autoRefresh && g.mg && g.mg.HasProp("Hwnd") && g.mg.HasProp("Refresh") && WinExist(g.mg.hwnd) && Type(g.mg.Refresh) = "Closure"
                g.mg.Refresh.Call(), g.mg.tab.Value := 1
        }
    }
}

class net
{
    static GetNetVersion() => RegRead("HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full", "Version", "")
    static hasNet := false
    static cs := ""
    static title := ""

    static Init()
    {
        cs := "
            (
                using System;
                using System.Text;
                class ViV 
                {
                    public string UrlDecode(string s)
                    {
                        return System.Web.HttpUtility.UrlDecode(s);
                    }

                    StringBuilder sb1 = new StringBuilder();
                    StringBuilder sb2 = new StringBuilder();
                    public string Diff(string s1, string s2, string separator = "<->")
                    {
                        sb1.Clear();
                        sb2.Clear();
                        sb1.Append(s1);
                        sb2.Append(s2);
                        while (LCS()) { }
                        sb1.Replace("  ", " ");
                        sb2.Replace("  ", " ");
                        return sb1.ToString().Trim() + separator + sb2.ToString().Trim();
                    }
                    
                    // https://stackoverflow.com/a/21797687
                    private bool LCS()
                    {
                        int[,] l = new int[sb1.Length, sb2.Length];
                        int lcs = -1;
                        int end = -1;
                        int end2 = -1;
            
                        for (int i = 0; i < sb1.Length; i++)
                        {
                            for (int j = 0; j < sb2.Length; j++)
                            {
                                if (sb1[i] == sb2[j])
                                {
                                    if (i == 0 || j == 0)
                                        l[i, j] = 1;
                                    else
                                        l[i, j] = l[i - 1, j - 1] + 1;
                                    if (l[i, j] > lcs)
                                    {
                                        lcs = l[i, j];
                                        end = i;
                                        end2 = j;
                                    }
                                }
                                else
                                    l[i, j] = 0;
                            }
                        }
            
                        if (lcs <= 1)
                            return false;
            
                        sb1.Remove(end - lcs + 1, lcs);
                        if (sb1.Length > 0)
                            sb1.Insert(end - lcs + 1, " ");
                        sb2.Remove(end2 - lcs + 1, lcs);
                        if (sb2.Length > 0)
                            sb2.Insert(end2 - lcs + 1, " ");
                        return true;
                    }
                    // https://siderite.dev/blog/super-fast-and-accurate-string-distance-sift3.html
                    public int Distance(string s1, string s2, int maxOffset = 5)
                    {
                        if (string.IsNullOrEmpty(s1))
                            return string.IsNullOrEmpty(s2) ? 0 : s2.Length;
            
                        if (string.IsNullOrEmpty(s2))
                            return s1.Length;
            
                        int c = 0;
                        int offset1 = 0;
                        int offset2 = 0;
                        int lcs = 0;
                        while ((c + offset1 < s1.Length) && (c + offset2 < s2.Length))
                        {
                            if (s1[c + offset1] == s2[c + offset2])
                                lcs++;
                            else
                            {
                                offset1 = offset2 = 0;
                                for (int i = 0; i < maxOffset; i++)
                                {
                                    if ((c + i < s1.Length) && (s1[c + i] == s2[c]))
                                    {
                                        offset1 = i;
                                        break;
                                    }
                                    if ((c + i < s2.Length) && (s1[c] == s2[c + i]))
                                    {
                                        offset2 = i;
                                        break;
                                    }
                                }
                            }
                            c++;
                        }
                        return (s1.Length + s2.Length) / 2 - lcs;
                    }
                }
            )"

    try
        {

            asm := CLR_CompileCS(cs, "System.Web.dll")
            obj := CLR_CreateObject(asm, "ViV")
            this.cs := obj
            this.hasNet := true
            this.title := "#"
        }
        catch Error as e
        {
            ; throw  e
        }
    }

    static UrlDecode(str, muilt := false)
    {
        if this.hasNet
            return this.cs.UrlDecode(str)

        if muilt && InStr(str, "`n")
        {
            tmp := StrReplace(str, "`n", ";")
            str := StrReplace(URIDecode(tmp), ";", "`n")
        }
        else
            str := URIDecode(str)
    }

    static Diff(s1, s2) => this.hasNet ? this.cs.Diff(s1, s2) : Diff(s1, s2)

    static LD(s1, s2) => this.cs.Distance(s1, s2)
}

class exp
{
    static type := [
        "全路径", "文件名", "不带扩展名", "扩展名", "文件夹", "属性",
        "修改时间", "创建时间", "大小 字节", "大小 KB", "大小 MB",
        "图片宽度 px", "图片高度 px", "视频宽度 px", "视频高度 px", "宽高比"
    ]

    static typeMap := Map(
        "全路径", "souce",
        "文件名", "name",
        "不带扩展名", "nameNoExt",
        "扩展名", "ext",
        "文件夹", "dir",
        "属性", "attrib",
        "修改时间", "time",
        "创建时间", "timeC",
        "大小 字节", "size",
        "大小 KB", "sizeK",
        "大小 MB", "sizeM",
        "宽高比", "aspectRatio",
        "图片宽度 px", "imgW",
        "图片高度 px", "imgH",
        "视频宽度 px", "vidW",
        "视频高度 px", "vidH",
        "时长 秒", "duration"
    )
    static condition := ["=", "!=", "==", "!==", ">", ">=", "<", "<=", "包含", "不包含", "正则匹配", "正则不匹配", "True", "False"]

    static Target(t) => this.typeMap.Has(t) ? this.typeMap[t] : t

    static states := { and: 1, or: 2 }

    static testLog(arr, &v := unset, r := unset)
    {
        if !IsSet(v)
            return
        orand := ""
        if IsNumber(arr[1])
            orand := arr[1] ? "AND " : "OR "
        if !IsSet(r)
            v .= "已中断 ", r := ""
        v .= orand Trim(arr[2]) " : " r " " arr[3] " " arr[4] "`n"
    }

    static Exec(list, sp, &v := unset)
    {
        b := false

        hasOr := list[1] & this.states.or
        hasAnd := list[1] & this.states.and
        for i in list
        {
            if A_Index = 1
                continue
            else if A_Index = 2
                b := Test(i, &v1)
            else if i[1] ;与运算
            {
                if !b && (A_Index = list.Length || (list[A_Index + 1][1] && !hasOr))
                {
                    this.testLog(i, &v)
                    return false
                }
                b := b && Test(i, &v1)
            }
            else ;或运算
            {
                if b && (A_Index = list.Length || !hasAnd || !list[A_Index + 1][1])
                {
                    this.testLog(i, &v)
                    return true
                }
                b := b || Test(i, &v1)
            }
            this.testLog(i, &v, v1)
        }
        return b


        Test(arr, &v := "")
        {
            if arr.Length != 4 || !StrLen(arr[4])
                return

            t := this.Target(arr[2])
            if ini.propertyMap.Has(t)
                v := sp.Get(t)
            else if !sp.HasProp(t)
                return
            else
                v := sp.%t%
            s := arr[4]
            switch arr[3]
            {
                case "=": return v = s
                case "!=": return v != s
                case "==": return v == s
                case "!==": return v !== s
                case ">": return IsNumber(v) && IsNumber(s) && v > s
                case ">=": return IsNumber(v) && IsNumber(s) && v >= s
                case "<": return IsNumber(v) && IsNumber(s) && v < s
                case "<=": return IsNumber(v) && IsNumber(s) && v <= s
                case "包含": return InStr(v, s)
                case "不包含": return !InStr(v, s)
                case "正则匹配":
                    try
                        return (v ~= s)
                case "正则不匹配":
                    try
                        return !(v ~= s)
                case "True": return StrLen(v)
                case "False": return !StrLen(v)
            }
        }
    }

    static hasAnd := false, hasOr := false
    static String2Arr(&str)
    {
        if RegExMatch(str, "(;(>>>exp<>.+<>.+<>.+))", &m)
        {
            arr := [0]
            str := StrReplace(str, m[1])

            for i in StrSplit(m[2], ">>>exp")
            {
                if InStr(i, "<>")
                {
                    arr2 := StrSplit(i, "<>")
                    if arr2.Length = 4
                        arr.Push(arr2)
                    if A_Index > 2
                    {
                        if arr[1]
                            arr[1] |= this.states.and
                        else
                            arr[1] |= this.states.or
                    }
                }
            }
            return arr
        }
        return ""
    }
}


class action
{
    static STitle := ""
    static MGTtitle := ""

    static Title(str, tick := true)
    {
        if g.ex
            this.STitle.Call(str, tick)
        if g.mg
            this.MGTtitle.Call(str, tick)
        g.running := false
    }


    static dir := A_ScriptDir "\Action\"

    static Read(name) => name && FileExist(this.dir name) ? FileRead(this.dir name) : ""

    static GetArr()
    {
        arr := []
        loop files this.dir "*.*", "F"
            arr.Push(A_LoopFileName)
        return arr
    }

    ;执行动作
    static Exec(name)
    {
        if g.running
            return this.Title("在编辑状态中...")

        if !data.inEdit
            return this.Title("未在编辑状态")

        if !FileExist(path := this.dir name)
            return this.Title("规则不存在?")

        g.running := true

        if ini.undo
        {
            data.undoVersion := data.version
            data.undo := []
            for i in data.currentSp
                data.undo.Push(pathBase(i.out, i.isDir, i.attrib))
        }

        ; now := A_TickCount
        hasUri := false
        actionArr := []
        conditionAArr := []
        env.retsore()
        for i in StrSplit(FileRead(path), "`n")
        {
            _exp := exp.String2Arr(&i)

            if RegExMatch(i, "^;全局;")
            {
                if _exp
                    conditionAArr.Push(_exp)
            }
            else if RegExMatch(i, "^;插入([前后]);(.+)", &m)
            {
                if (rule := m[2]) ~= "<[dn]>"
                    rule := env.RuleUpdate(rule)
                actionArr.Push(["i", [rule, m[1] = "前" ? 0 : 1], _exp])
            }
            else if RegExMatch(i, "^;转换;(.+)", &m)
            {
                if net.hasNet
                    actionArr.Push(["c", m[1], _exp])
                else if m[1] != "D"
                    actionArr.Push(["c", m[1], _exp])
                else
                    hasUri := true, DArr := []
            }
            else if RegExMatch(i, "^;排除([选消]);(.+)", &m)
            {
                fm := Map("文件", "exFile", "目录", "exDir", "符号", "exRP", "只读", "exReadonly", "隐藏", "exHide", "系统", "exSys")
                select := m[1] = "选"
                if m[2] = "所有"
                {
                    for k, v in fm
                        ini.ChangeKey(g.gui.%v%.Value := select, v)
                }
                else if fm.Has(m[2])
                    ini.ChangeKey(g.gui.%fm[m[2]]%.Value := select, fm[m[2]])
            }
            else if RegExMatch(i, "^;替换;(.+)", &m)
            {
                arr := StrSplit(m[1], ";")
                if arr.Length = 6
                    actionArr.Push(["r", arr, _exp])
            }
            else if RegExMatch(i, "^;移动;(.+)", &m)
                actionArr.Push(["m", m[1], _exp])
            else if RegExMatch(i, "^;删除;(.+)", &m)
                actionArr.Push(["d", , _exp])
        }

        if !actionArr.Length && !hasUri
            return this.Title("未存在符合的动作")

        tmp := ""
        isChange := false
        pos := 0
        delCount := 0

        if (arr2 := data.TmpToArr()) = -1
            return this.Title("原始文件与目标文件数量不符")

        for i in data.currentSp
        {
            if newPos := PosTitle(&pos, A_Index, arr2)
                this.Title(name "执行中...: " newPos)

            index := A_Index

            out := arr2[index]
            if pathBase.Batch(i, arr2[index], i.attrib, 1) = -1
            {
                if hasUri
                    DArr.Push(i)
                tmp .= i.ToTmp(index)
                continue
            }

            for k in conditionAArr
                if !exp.Exec(k, i)
                    continue 2

            for k in actionArr
            {
                if k[3] && !exp.Exec(k[3], i)
                    continue

                switch k[1]
                {
                    case "i":
                        if k[2][2]
                            i.nameNoExt := env.exec(i.nameNoExt k[2][1], i)
                        else
                            i.nameNoExt := env.exec(k[2][1] i.nameNoExt, i)
                    case "r":
                        try
                            edit.REItem(i, k[2])
                        catch
                            actionArr.RemoveAt(A_Index)
                    case "c":
                        if nameNoExt := edit.Convert(k[2], i.nameNoExt, true)
                            i.nameNoExt := nameNoExt
                    case "m": i.dir := k[2]
                    case "d": delCount += TryFileDelete(i.souce, true) ? 1 : 0
                }
            }

            if hasUri
                DArr.Push(i)

            if !isChange
                isChange := i.IsChange
            tmp .= i.ToTmp(index)
        }

        if hasUri
        {
            nameNoExts := ""
            for i in DArr
                nameNoExts .= i.nameNoExt IsLastLine(A_Index)

            nameNoExts := edit.Convert("D", nameNoExts)

            if nameNoExts
            {
                isChange := true
                arr := StrSplit(nameNoExts, ";")
                tmp := ""
                if arr.Length != data.length || arr.Length != DArr.Length
                    ToolTipEx("D 发生错误已跳过全部转换")
                else
                {
                    for i in DArr
                        if A_Index <= data.length
                            tmp .= i.dir "\" arr[A_Index] (i.ext ? "." i.ext : "") IsLastLine(A_Index)
                }
                if !tmp
                    isChange := false
            }
            else
                ToolTipEx("D 发生错误已跳过全部转换")
        }

        if isChange && tmp
        {
            if hasUri
                g.pathTypeChange.Call(0, false)
            FileWrite(tmp, data.path), this.Title(name "执行完成" (delCount ? ", 删除 " delCount " 个文件" : ""))
        }
        else if delCount
            this.Title(name " 删除 " delCount " 个文件")
        else
            this.Title(name " 未发生修改")
    }


    ;删除动作
    static Delete(str)
    {
        FileRecycle(path := action.dir str)
        arr := this.GetArr()
        if g.ex.acAll
        {
            g.ex.acAll.Delete()
            g.ex.acAll.Add(arr)
            if arr.Length
                g.ex.acAll.Value := 1
        }
        if g.mg
        {
            g.mg.acAll.Delete()
            g.mg.acAll.Add(arr)
            if arr.Length
                g.mg.acAll.Value := 1
        }
    }
}

class edit
{
    ;批量执行自动替换
    static RE(sp)
    {
        if ini.autoRe
            for i in ini.reArr
            {
                try
                    this.REItem(sp, i)
                catch
                    ini.reArr.RemoveAt(A_Index), ToolTipEx("规则错误: " ini.re[A_Index])
            }
    }

    ;执行单个替换规则
    static REItem(sp, arr)
    {
        switch arr[5]
        {
            case 0: sp.Replace("out", arr)
            case 1: sp.Replace("name", arr)
            case 2: sp.Replace("nameNoExt", arr)
            case 3: sp.Replace("ext", arr)
        }
    }


    ;转换
    static Convert(cType, str, muilt := false, &t := "", len := 0)
    {
        switch cType
        {
            case "繁": t := "简转繁", str := LCMapString(str, len, 2)
            case "简": t := "繁转简", str := LCMapString(str, len, 1)
            case "大": t := "大写", str := StrUpper(str)
            case "小": t := "小写", str := StrLower(str)
            case "首": t := "首字母大写", str := StrTitle(str)
            case "半": t := "全角转半角", str := LCMapString(str, len, 4)
            case "全": t := "半角转全角", str := LCMapString(str, len, 3)
            case "D": t := "URI解码", str := net.UrlDecode(str, muilt)
        }
        return str
    }

}

class env
{
    static arr := [
        ["递增数字", "<n>1;3;1;"],
        ["图包目录命名", "<p>"],
        ["当前时间", "<d>yyyy-MM-dd H-mm-ss;"],
        ["上级目录名称", "<f>"],
        ["文件修改时间", "<t>"],
        ["文件创建时间", "<tc>"],
        ["随机八位数字", "<r>"],
        ["GUID", "<rg>"],
    ]

    static retsore()
    {
        this.envNumRule := [1, 3, 1]
        this.envDateRule := "yyyy-MM-dd H-mm-ss"
    }

    ;环境变量替换成目标值
    static exec(str, sp)
    {
        if !ini.env
            return str

        if !RegExMatch(str, "(<(.+)>)", &m)
            return str
        if ini.propertyMap.Has(m[2])
            str := StrReplace(str, m[1], sp.Get(m[2]))

        if InStr(str, "<p>")
        {
            if sp.isDir
            {
                p := 0
                v := 0
                size := 0
                pExt := Map("jpeg", true, "jpg", true, "png", true, "webp", true, "bmp", true)
                vExt := Map("mp4", true, "mkv", true, "wmv", true, "avi", true, "webm", true, "ts", true)
                loop files sp.souce "\*.*", "FR"
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
                s .= GetSizeReadable(size, 0) "]"
                str := StrReplace(str, "<p>", s)
            }
            else
                str := StrReplace(str, "<p>")
        }

        if InStr(str, "<f>")
            str := StrReplace(str, "<f>", StrReplace(RegExReplace(sp.dir, ".+\\"), ":"))

        if InStr(str, "<d>")
        {
            str := this.RuleUpdate(str, 1)
            str := StrReplace(str, "<d>", FormatTime(A_Now, this.envDateRule))
        }

        if InStr(str, "<n>")
        {
            str := this.RuleUpdate(str, 2)
            n := this.envNumRule[1]
            len := StrLen(n)
            loop this.envNumRule[2] - len
                n := "0" n
            str := StrReplace(str, "<n>", n)
            this.envNumRule[1] += this.envNumRule[3]
        }

        if InStr(str, "<t>")
            str := StrReplace(str, "<t>", GetFormatTime(sp.time))

        if InStr(str, "<tc>")
            str := StrReplace(str, "<tc>", GetFormatTime(sp.timeC))

        if InStr(str, "<r>")
            str := StrReplace(str, "<r>", Random(10000000, 99999999))

        if InStr(str, "<rg>")
            str := StrReplace(str, "<rg>", StrReplace(Trim(CreateGUID(), "{}"), "-"))

        return str

        GetFormatTime(time) => FormatTime(time, "yyyy-MM-dd H-mm-ss")
    }

    ;更新变量规则并返回不带规则的变量
    static RuleUpdate(str, all := 3)
    {
        if ini.env
        {
            if all = 3 || all = 1
            {
                if RegExMatch(str, "<d>((.+);)", &m)
                {
                    this.envDateRule := m[2]
                    str := StrReplace(str, m[1])
                    m := ""
                }
            }
            if all >= 2
            {
                if RegExMatch(str, "<n>((\d+);(\d+);(\d+);)", &m)
                {
                    if IsNumber(m[2])
                        this.envNumRule[1] := m[2]
                    if IsNumber(m[3])
                        this.envNumRule[2] := m[3]
                    if IsNumber(m[4])
                        this.envNumRule[3] := m[4]
                    str := StrReplace(str, m[1])
                }
            }
        }
        return str
    }

}

Get(path, t, df := 0)
{
    if !FileExist(path)
        return df
    try
        switch t, 0
        {
            case "attrib": return FileGetAttrib(path)
            case "time": return FileGetTime(path)
            case "timeC": return FileGetTime(path, "C")
            case "size": return FileGetSize(path)
            case "sizeK": return FileGetSize(path, "K")
            case "sizeM": return FileGetSize(path, "M")
        }
    catch
        return df
}

;清空并写入文本到文件
FileWrite(str, path, encoding := "UTF-8")
{
    f := FileOpen(path, "w", encoding)
    f.Write(str)
    f.Close()

    if path = data.path
        g.Refresh()
}

;提示并等待或关闭提示
ToolTipEx(s, time := 1000, wait := false)
{
    ToolTip(s)
    if wait
        Sleep(time)
    else
        SetTimer(ToolTip, -time)
}

;托盘菜单
TrayMenu()
{
    A_TrayMenu.Delete()
    A_TrayMenu.Add("界面", (*) => MainGui())
    A_TrayMenu.Add("恢复上次", (*) => log.Restore(1))
    A_TrayMenu.Add("退出", (*) => ExitApp())
    A_TrayMenu.Default := "界面"
    A_TrayMenu.ClickCount := 2
}

;设置主界面标题
MTitle(str)
{
    if g.gui
        g.gui.Title := str " - " app net.title
}

;生成临时文件路径
TempPath(&title := "")
{
    if !(guid := StrReplace(Trim(CreateGUID(), "{}"), "-"))
        guid := A_TickCount A_Now
    return A_Temp "\" (title := guid) ".txt"
}

;尝试删除
TryFileDelete(path, rec := false)
{
    try
    {
        rec ? FileRecycle(path) : FileDelete(path)
        return true
    }
}

;主界面
MainGui()
{
    if g.gui && WinExist(g.gui.hwnd)
        return WinActivate()

    _tips.allowNotActive := false
    g.gui := main := GuiEx("+AlwaysOnTop +ToolWindow", data.length " - " app)
    main.MarginY := 1
    main.Add("Text", , "拖拽文件至此进行重命名")

    AddCheckboxEx("subFolder", , "包含子目录").OnEvent("Click", (ctrl, info) => (ini.subFolder := ctrl.Value, data.Update()))
    main.AddEditUpDown("层级", "yp", " w50 h18", , ini.subLevel, "subLevel", "遍历的层级,`n太快切换可能会阻塞`n阻塞时切换下 包含子目录 即可").OnEvent("Change", SubLevelChange)

    pathType := ini.pathType
    main.Add("GroupBox", "xs Section w170 r3", "路径").GetPos(&x, &y)
    full := main.AddRadio("Section x" x + 10 " y" y + 20 " Checked" (pathType = 0), "全路径")
    full.OnEvent("Click", SetPathType)
    name := main.AddRadio("yp x106 Checked" (pathType = 1), "文件名")
    name.OnEvent("Click", SetPathType)
    nameNoExt := main.AddRadio("xs Checked" (pathType = 2), "不带扩展名", , "不带扩展名的文件名")
    g.pathTypeChange := pathTypeChange
    nameNoExt.OnEvent("Click", SetPathType)
    ext := main.AddRadio("yp Checked" (pathType = 3), "扩展名")
    ext.OnEvent("Click", SetPathType)

    main.Add("GroupBox", "xs Section w170 r3 y+20 x" x, "排除").GetPos(, &y)
    g.gui.exFile := AddCheckboxEx("exFile", "Section x" x + 10 " y" y + 20, "文件")
    g.gui.exDir := AddCheckboxEx("exDir", "yp", "目录")
    g.gui.exRP := AddCheckboxEx("exRP", "yp", "符号", "通常是符号链接")
    g.gui.exReadonly := AddCheckboxEx("exReadonly", "xs", "只读")
    g.gui.exHide := AddCheckboxEx("exHide", "yp", "隐藏")
    g.gui.exSys := AddCheckboxEx("exSys", "yp", "系统")

    AddCheckboxEx(var, opt := "", text := "", tips := "") => g.AddCheckboxEx(main, var, opt, text, tips)

    main.Add("GroupBox", "xs Section w170 r2 y+20 x" x, "恢复").GetPos(, &y)
    main.AddRadio("x" x + 10 " y" y + 20, "上次").OnEvent("Click", (*) => log.Restore(1))
    main.AddRadio("yp", "全部", , "log.txt太大可能影响速度,可删除").OnEvent("Click", (*) => log.Restore(2))
    main.AddRadio("yp", "部分", , "log.txt太大可能影响速度,可删除").OnEvent("Click", (*) => log.Restore(3))

    main.AddButton("xs", "设", "打开设置界面").OnEvent("Click", (*) => MoreGui(4))
    main.AddButton("yp", "列", "查看文件列表").OnEvent("Click", (*) => MoreGui())
    main.AddButton("yp", "关", "关闭而不进行重命名").OnEvent("Click", (*) => (data.Restore(), g.wait := false, g.mg ? g.mg.LV.Delete() : ""))
    main.AddButton("yp", "重", "直接执行重命名").OnEvent("Click", (*) => g.wait := false)
    main.AddButton("yp", "X", "
    (
        副界面 一些简单编辑
        副界面会跟随在主界面右侧
        如关闭主界面前未关闭副界面
        则下次启动会同时启动副界面
    )").OnEvent("Click", exGui)

    pos := ""
    if ini.guiX || ini.guiY
        pos := " x" ini.guiX " y" ini.guiY
    main.Show(pos)
    main.OnEvent("DropFiles", (GuiObj, GuiCtrlObj, FileArray, X, Y) => BeginRename(FileArray))
    main.OnClose(CloseG)
    GuiEx.OnMouseMove()
    if !net.hasNet
        net.Init(), main.Title .= net.title

    if ini.exGui
        exGui()

    ;从其他界面设置路径类型并按需更新
    pathTypeChange(num, update := true)
    {
        if ini.pathType = num
            return

        ini.pathType := num

        switch ini.pathType
        {
            case 0: full.Value := 1
            case 1: Name.Value := 1
            case 2: nameNoExt.Value := 1
            case 3: ext.Value := 1
        }

        if update
            data.Update()
    }


    ;设置路径类型并更新
    SetPathType(ctrl, info)
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

    ;设置子文件夹层级并更新
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
}

;关闭主界面并保存设置
CloseG(ctrl)
{
    if g.mg && g.mg.HasProp("Hwnd") && WinExist(g.mg.hwnd)
        g.mg.Destroy(), g.mg := ""

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

;副界面
ExGui(*)
{
    if g.ex && WinExist(g.ex.hwnd)
    {
        g.ex.Destroy()
        return g.ex := ""
    }

    envNameArr := []
    for i in env.arr
        envNameArr.Push(i[1])


    action.STitle := STitle
    g.ex := ex := GuiEx("+AlwaysOnTop +ToolWindow", app net.title)
    ex.AddText(, "以下需编辑器支持重载")
    AddCheckboxEx("undo", "yp w10")
    ex.AddButton("yp ", "撤消", "撤消上一步操作 仅此界面)`n需选中左边方框`n选中时增加耗时,消耗双倍内存").OnEvent("Click", UndoFunc)
    ex.AddButton("yp", "重命名", "直接执行重命名").OnEvent("Click", (*) => g.wait := false)

    ex.AddLink("yp", , "https://github.com/vvyoko/EditRename", "主页", "GitHub")

    acArr := action.GetArr()

    UndoFunc(*)
    {
        if g.running
            return STitle("在编辑状态中...")

        if !ini.undo || !data.undo || data.undoVersion != data.version || data.undo.length != data.length
            return STitle("不可撤消")

        g.running := true

        files := ""
        for i in data.undo
            files .= i.ToTmp(A_Index)
        FileWrite(files, data.path)
        data.undo := ""
        return STitle("撤消完成")
    }

    g.ex.acAll := acAll := ex.AddDropDownListEx("动作", acArr, "xs", "w165", ini.actionChoose <= acArr.Length ? ini.actionChoose : 1, "actionChoose", "
    (
        连续执行多项操作
        点击 造 添加动作及查看说明
        点击 执行 执行当前动作
        执行前可执行其他编辑
        完成后仅支持在编辑器编辑
        不要执行其他编辑操作,会重置修改
    )")
    ex.MarginY := 1
    ; ex.AddButton("yp w20", "-", "删除动作").OnEvent("Click", (*) => action.Delete(acAll.Text))
    ex.AddButton("yp", "造", "生成动作").OnEvent("Click", (*) => MoreGui(3))
    ex.AddButton("yp", "执行", "执行当前动作").OnEvent("Click", (*) => action.Exec(acAll.Text))
    ex.RY()

    envDDL := ex.AddDropDownListEx("变量", envNameArr, "xs", "w165", ini.envChoose, , "简单说明查看 设置-环境变量`n前3项有详细说明,选择并悬浮查看")
    envDDL.OnEvent("Change", EnvChange)
    ex.MarginY := 1
    ex.AddButton("yp", "追", "追加到下面编辑框").OnEvent("Click", (ctrl, info) => insert.Text .= (insert.Text ? " " : "") env.arr[envDDL.Value][2])
    ex.AddButton("yp", "换", "替换下面编辑框").OnEvent("Click", (ctrl, info) => insert.Text := env.arr[envDDL.Value][2])
    ex.RY()
    envLink := ex.AddLink("yp", , , "说明")
    envLink.Text := ""

    insert := ex.AddComboBoxEx("插入", ini.envEditArr, "xs", "w165", , , "通过 前 后 按钮添加`n可添加变量及其规则`n可将常用保存下次调用`n", , "w20", , "w20")
    insert.Text := ini.envEditText
    ex.MarginY := 1
    ex.AddButton("yp", "前", "在当前文件每项前添加当前内容`n防误操作全路径不工作").OnEvent("Click", (*) => Change("before"))
    ex.AddButton("yp", "后", "在当前文件每项后添加当前内容`n防误操作全路径不工作").OnEvent("Click", (*) => Change("after"))
    ex.RY()

    g.ex.reSave := ReSave := ex.AddComboBoxEx("替换", ini.reSave, "xs", "w165", , , "替换为空 搜索项`n简单替换 搜索项;替换项`n复杂规则通过 造 生成`n点击 替 即时替换", , "w20", , "w20")
    ReSave.Text := ini.reSaveText
    ex.MarginY := 1
    ex.AddButton("yp", "造", "生成替换规则").OnEvent("Click", (*) => MoreGui(2))
    ex.AddButton("yp", "替", "使用当前规则在当前文件替换").OnEvent("Click", (*) => Change("re"))

    ex.AddButton("xs", "繁", "简转繁,如转换后字数有变化则失败`n防误操作全路径不工作").OnEvent("Click", (*) => Change("繁"))
    ex.AddButton("yp", "简", "繁转简,如转换后字数有变化则失败`n防误操作全路径不工作").OnEvent("Click", (*) => Change("简"))
    ex.AddButton("yp", "半", "全角转半角`n防误操作会切换至不带扩展名操作").OnEvent("Click", (*) => Change("半"))
    ex.AddButton("yp", "全", "半角转全角`n防误操作会切换至不带扩展名操作").OnEvent("Click", (*) => Change("全"))
    ex.AddButton("yp", "大", "大写").OnEvent("Click", (*) => Change("大"))
    ex.AddButton("yp", "小", "小写").OnEvent("Click", (*) => Change("小"))
    ex.AddButton("yp", "首", "首字母大写").OnEvent("Click", (*) => Change("首"))
    ex.AddButton("yp", "D", "URI解码`n防误操作全路径不工作").OnEvent("Click", (*) => Change("D"))
    ex.RY()

    ex.AddText("xs", "拖拽文件至本界面添加标签,与编辑器无关")
    tag := ex.AddComboBoxEx("标签", ini.tag, , "w178", , , "在文件名前添加标签加空格`n支持变量,自动替换,恢复", , "w20", , "w20")
    tag.Text := ini.tagText
    ex.MarginY := 1
    AddCheckboxEx("tagLast", "yp", "末端", "在文件名后扩展名前添加标签")

    g.gui.GetPos(&x, &y, &w, &h)
    ex.Show("x" x + w - 10 " y" y)
    ex.GetPos(, , &w)
    g.OnMove := OnMove
    g.ex.Change := Change
    SetTimer(g.OnMove, 100)
    ex.OnClose(CloseEx)
    ex.OnEvent("DropFiles", TagAdd)

    ;添加标签
    TagAdd(GuiObj, GuiCtrlObj, FileArray, X, Y)
    {
        if !StrLen(tagStr := tag.Text) && !(ini.autoRe && ini.reArr.Length)
            return

        if StrLen(tagStr) && tagStr !== ini.tagText
            ini.ChangeKey(tagStr, "tagText")

        success := 0
        failure := 0
        env.retsore()
        tagStr := env.RuleUpdate(tagStr)
        pos := 0
        for i in FileArray
        {
            if newPos := PosTitle(&pos, A_Index, FileArray)
                STitle("添加标签...: " newPos, false)

            sp := pathBase(i, DirExist(i))
            sp.nameNoExt := ini.tagLast ? sp.nameNoExt " " tagStr : tagStr " " sp.nameNoExt
            edit.RE(sp)
            sp.nameNoExt := RenameSafe(env.exec(sp.nameNoExt, sp))
            sp.Move(&success, &failure)
        }
        log.Save()
        STitle("添加标签完成: " success "\" failure "\" FileArray.Length, false)
    }

    AddCheckboxEx(var, opt := "", text := "", tips := "") => g.AddCheckboxEx(ex, var, opt, text, tips)

    ;变量提示
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
                如果同时在一项中插入多个<n>,同样会递增

                手动在编辑器中设置规则
                在第一项 <n> 后跟随规则,后续<n>将按此递增
            )"
    case 2: ctrl.Tips := "只对文件夹命名, 示例 [35P-2V-550M]"
        case 3: ctrl.Tips := "
            (
                规则 时间格式; (如不设置默认格式如下)
                <d>yyyy-MM-dd H-mm-ss; 为 2023-01-29 22-58-29
                详细格式请点击说明查看

                手动在编辑器中设置规则
                在第一项 <d> 后跟随 时间格式; 后续<d>遵守此规则
            )"
    envLink.Text := '<a id="help" href="https://wyagd001.github.io/v2/docs/lib/FormatTime.htm#Date_Formats">说明</a>'
        default: ctrl.Tips := "简单说明请悬浮 环境变量 查看`n前3项有详细说明,选择并悬浮查看"
        }
    }

    ;跟随主界面移动
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

    ;简单的编辑
    Change(str := "")
    {
        if g.running
            return STitle("在编辑状态中...")

        if !data.inEdit
            return STitle("未在编辑状态")

        if (str = "before" || str = "after" || str = "繁" || str = "简" || str == "D") && !ini.pathType && !GuiEx.Debug
            return STitle("目前为全路径,已跳过")

        if str = "before" && str = "after" && (!ini.env || !StrLen(insert.Text))
            return STitle("未启用环境变量或当前变量为空")

        if str = "re" && !StrLen(ReSave.Text)
            return STitle("未设置替换项")

        g.running := true

        if ini.undo
        {
            data.undoVersion := data.version
            data.undo := []
            for i in data.currentSp
                data.undo.Push(pathBase(i.out, i.isDir, i.attrib))
        }

        STitle("处理中...")
        f := data.Read
        t := "未知"
        tmp := ""
        if str = "re"
        {
            ini.ChangeKey(ReSave.Text, "reSaveText")
            t := "替换"
            arr := StrSplit(ReSave.Text, ";")
            if (arr2 := data.TmpToArr(, f)) = -1
                return STitle("原始文件与目标文件数量不符")
            for i in data.currentSp
            {
                pathBase.FromTmp(i, arr2[A_Index])
                switch arr.Length
                {
                    case 1: i.nameNoExt := StrReplace(i.nameNoExt, arr[1])
                    case 2: i.nameNoExt := StrReplace(i.nameNoExt, arr[1], arr[2])
                    case 6:
                        try
                            edit.REItem(i, arr)
                        catch
                            return STitle("规则可能出错")
                    default: return STitle("未设置替换规则或规则不正确 " arr.Length)
                }
                tmp .= i.ToTmp(A_Index)
            }
        }
        else if (isBefore := str = "before") || str = "after"
        {
            ini.ChangeKey(insert.Text, "envEditText")
            t := isBefore ? "前添加" : "后添加"
            envSave := ini.env
            ini.env := InStr(insert.Text, "<")
            rule := env.RuleUpdate(insert.Text)
            arr := StrSplit(RegExReplace(f, isBefore ? "mS)^" : "mS)$", rule), "`n")
            if arr.Length = data.length
            {
                for i in arr
                    tmp .= env.exec(i, data.currentSp[A_Index]) IsLastLine(A_Index)
            }
            else
            {
                if GuiEx.Debug
                    ToolTipEx("直接替换出错,循环替换")
                for i in StrSplit(f, "`n")
                    tmp .= env.exec(RegExReplace(i, isBefore ? "^" : "$", rule), data.currentSp[A_Index]) IsLastLine(A_Index)
            }
            ini.env := envSave
        }
        else
        {
            len := 0

            if (ts := str = "简" || str = "繁")
                len := StrLen(f)

            if (str = "半" || str = "全") && ini.pathType != 2
            {
                STitle("更新中...")
                g.pathTypeChange.Call(2)
            }
            tmp := edit.Convert(str, f, true, &t, len)
            if ts && (afterLen := StrLen(tmp)) != len
                return STitle("字数不正确,已跳过 " len "/" afterLen, false)
        }
        if !tmp
            return STitle(t "失败")

        FileWrite(tmp, data.path)
        STitle(t "处理完成")
    }

    STitle(str, tick := true) => (ex.Title := str " " (tick ? A_TickCount : "") net.title, g.running := false)
}

;关闭副界面
CloseEx(ctrl)
{
    ctrl.Destroy()
    g.ex := ""
}

;文件列表,替换,动作,设置界面
MoreGui(tab := 1)
{
    if g.mg && WinExist(g.mg.hwnd)
    {
        _tips.disable := ini.disableTips
        if tab = g.mg.tab.Value && !IsWinCover(g.mg.hwnd)
        {
            SavePos()
            g.mg.Destroy()
            return g.mg := ""
        }
        g.mg.tab.Value := tab
        return WinActivate(g.mg.hwnd)
    }

    g.mg := mg := GuiEx("Resize +MinSize800x640", app net.title)
    action.MGTtitle := MGTtitle

    mg.RX()
    g.mg.tab := mg.Add("Tab3", , ["列表", "替换", "动作", "设置", "其他"])

    g.mg.tab.UseTab(1)
    AddCheckboxEx("previewFull", "Section", "完全加载", "加载所有文件,无效信息更多,多次更新更平滑`n取消则只加载修改过的文件,每次更新都会完全重新生成列表").OnEvent("Click", Refresh)
    AddCheckboxEx("autoRefresh", "yp", "自动刷新", "启用后软件本身产生修改大部分情况能自动刷新`n编辑器中的修改则需手动刷新")
    AddCheckboxEx("diff", "yp", "计算差异", "如右侧有计算距离则影响不大`n否则可能结果和效率都差强人意,酌情使用").OnEvent("Click", Refresh)

    if net.hasNet
        AddCheckboxEx("ld", "yp", "计算距离", "Sift3,`n指两个字串之间，由一个转成另一个所需的最少编辑操作次数。").OnEvent("Click", Refresh)

    mg.path := ""

    mg.AddButton("yp", "重命名", "直接执行重命名").OnEvent("Click", (*) => g.wait := false)
    mg.AddButton("yp", "关闭", "关闭而不进行重命名").OnEvent("Click", (*) => (data.Restore(), g.wait := false, g.mg.LV.Delete()))
    mg.AddButton("yp", "刷新").OnEvent("Click", Refresh)
    if ini.noEditMode
        mg.AddButton("yp", "在编辑器中打开", "打开编辑器编辑`n产生的修改也有效 需手动刷新").OnEvent("Click", (*) => (FileExist(data.path) ? (WinExist(data.title) ? WinActivate(data.title) : RunEditor(data.path)) : " "))

    mg.AddText("xs", "标题计数只是加载列表与重命名无关,开始计数即可点击重命名, 选中表示跳过此项重命名`n按F2可简单编辑,完成其他动作后编辑,防止被恢复, 右键某行更多操作 (Ctrl或Shift点击选择多行右键选中)")

    mg.SetFont("", "Arial")
    lvArr := ["原路径", "新路径", "差异", "距离", "文件夹", "目录", "选中", "#"]
    g.mg.LV := mg.AddListView("xs r26 w780 +LV0x10000 Grid Checked", lvArr)
    if ini.previewFull
        g.mg.LV.Opt("-ReadOnly")
    LVRowAuto(false)
    g.mg.LV.Length := 0
    mg.SetFont("", "Segoe UI")

    g.mg.tab.UseTab(2)
    reIsRe := mg.AddCheckbox("Section ", "是否正则")
    reIsRe.OnEvent("Click", RuleGenerate)

    reIgnoreCase := mg.AddCheckbox("yp Checked1", "忽略大小写")
    reIgnoreCase.OnEvent("Click", RuleGenerate)

    rePathType := mg.AddDropDownListEx("限定路径", ["全路径", "文件名", "不带扩展名", "扩展名"], "yp", "w90", 3)
    rePathType.OnEvent("Change", RuleGenerate)

    mg.AddTextEdit("导入", "xs", "w600 x73", , , "将完整规则粘贴至此进行测试及修改").OnEvent("Change", RuleInput)

    reDescription := mg.AddTextEdit("说明", "xs", "w600 x73", , , "明确规则用途便于选择")
    reDescription.OnEvent("Change", RuleGenerate)

    reNeedle := mg.AddTextEdit("搜索项", "xs", "x73 w525")
    reNeedle.OnEvent("Change", RuleGenerate)

    mg.AddButton("yp r3", "直接替换", "直接在当前文件中替换`n全路径时不工作").OnEvent("Click", RuleButton)

    reReplacement := mg.AddTextEdit("替换项", "x24 y158", "x73 w525")
    reReplacement.OnEvent("Change", RuleGenerate)

    reExp := AddExp()

    reTip := mg.AddCheckbox("yp x+77", "提示当前表达式内容", , "用于测试表达式是否正确`n启用后如表达式不为空则会在规则变更时提示`n会禁用悬浮提示防止干扰")
    reTip.OnEvent("Click", RuleGenerate)

    mg.AddText()

    mg.AddButton("xs Section  Checked1 x" reExp.x, "生成").OnEvent("Click", RuleGenerate)
    reRule := mg.AddEdit("yp  w600 ReadOnly", , , "生成的规则")

    rePath := mg.AddTextEdit("路径", "xs", "x73 w600 r8", , , "拖入文件或手动填写路径`n或在列表里点击某项")
    rePath.OnEvent("change", RuleTest)

    reResult := mg.AddTextEdit("结果", "Xs", "x73 w600 ReadOnly r8", , , "测试结果")

    mg.AddButton("xs", "添加到自动替换", "添加到自动替换,需要点 + 保存").OnEvent("Click", RuleButton)
    mg.AddButton("yp", "添加到替换", "添加到 副界面-替换,需要点 + 保存`n全路径时不工作").OnEvent("Click", RuleButton)
    mg.AddButton("yp", "追加到动作流程", "追加到右标签动作流程").OnEvent("Click", RuleButton)

    mg.AddLink("yp x+190", , "https://wyagd001.github.io/v2/docs/misc/RegEx-QuickRef.htm", "正则参考", "正则版本 PCRE 8.30`n更多详情请浏览")

    g.mg.tab.UseTab(3)
    acArr := action.GetArr()
    acName := mg.AddTextEdit("名称", "Section", "w550 x73", ini.actionChoose <= acArr.Length ? acArr[ini.actionChoose] : "", , "动作名称,必填")
    acName.OnEvent("Change", (ctrl, info) => acEdit.Value := action.Read(RenameSafe(ctrl.Value)))

    acConvert := mg.AddDropDownListEx("转换", ["繁", "简", "半", "全", "大", "小", "首", "D"], "xs", "w50 x73", , , "多项同时使用可能有冲突`n仅操作 不带扩展名")
    mg.AddButton("yp", "+").OnEvent("Click", (*) => ActionAdd("转换", acConvert.Text))

    acFilter := mg.AddDropDownListEx("排除", ["文件", "目录", "符号", "只读", "隐藏", "系统", "所有"], "yp x+303", "x+20 w50", , , "如有设置在动作完成后请不要修改`n可能产生文件夹和文件被分离情况")
    mg.AddButton("yp", "+", "排除").OnEvent("Click", (*) => ActionAdd("排除选", acFilter.Text))
    mg.AddButton("yp", "-", "取消排除").OnEvent("Click", (*) => ActionAdd("排除消", acFilter.Text))

    acReplace := mg.AddTextEdit("替换", "xs", "w480 x73", , , "建议通过左标签添加")
    mg.AddButton("yp", "+").OnEvent("Click", (*) => ActionAdd("替换", acReplace.Value))

    acInsert := mg.AddTextEdit("插入", "xs", "w480 x73", , , "规则等同于副界面 插入`n如需插入变量需在设置中选中 环境变量`n需插入变量在副界面生成然后复制`n包含规则的相同变量仅最后一个规则有效`n仅操作 不带扩展名")
    mg.AddButton("yp", "前").OnEvent("Click", (*) => ActionAdd("插入前", acInsert.Value))
    mg.AddButton("yp", "后").OnEvent("Click", (*) => ActionAdd("插入后", acInsert.Value))

    acExp := AddExp("w600", "w300", "为空则无条件`n不为空时会在添加动作的时候自动追加条件`n只有在满足条件的情况才会执行此动作`n不包括 排除 及非C#的转换 D", false)
    mg.AddButton("yp x+218", "全局", "添加整个流程的全局条件,多项则需同时满足").OnEvent("Click", (*) => ActionAddExp())

    mg.AddText()
    acMove := mg.AddTextEdit("移动", "xs Section x" acExp.x, "x73 w327 ReadOnly", , , "移到符合条件的文件到指定文件夹`n为防出错,不能手动设置,需拖拽文件夹到此页面`n在开始重命名时移动,能恢复`n必需设置条件或包含全局条,用于整理")
    mg.AddButton("yp", "+").OnEvent("Click", (*) => ActionAddIO("移动", acMove.Value))
    mg.AddButton("yp x+140", "删除", "删除符合条件的文件到回收站`n在执行动作过程中直接删除,需手动进回收站恢复`n必需设置条件或包含全局条件,用于整理").OnEvent("Click", (*) => ActionAddIO("删除", " "))

    g.mg.acAll := acAll := mg.AddDropDownListEx("动作", acArr, "xs", " x73 w405", ini.actionChoose <= acArr.Length ? ini.actionChoose : 1, , "所有动作`n设置不同的名称并保存新增")
    acAll.OnEvent("change", (ctrl, info) => acEdit.Value := action.Read(acName.Value := ctrl.Text))
    mg.AddButton("yp", "保存", "保存或新增规则").OnEvent("Click", ActionSave)
    mg.AddButton("yp", "-", "删除动作").OnEvent("Click", (*) => action.Delete(acAll.Text))
    mg.AddButton("yp", "保存并替换", "保存并直接在当前文件中执行当前动作").OnEvent("Click", (*) => ActionSave("替"))
    g.mg.acEdit := acEdit := mg.AddEdit("xs r19 w600", acAll.Text ? action.Read(acAll.Text) : "", , "
    (
        动作流程,按行依次执行
        点击 存 保存或新增规则
        尽量不要手动添加
        可调整行顺序(执行顺序)
        添加错误时可删除指定行

        排除总是最开始执行
    )")

    if !net.hasNet
        acEdit.Tips .= "`n转换 D(URI) 总是最后执行"

    g.mg.tab.UseTab(4)
    AddCheckboxEx("exit", "Section", "完成后退出", "仅在外部传入参数及成功命名部分文件后退出`n直接运行程序不会退出")
    AddCheckboxEx("gui", "yp x200", "修改时显示界面", "关闭后通过直接运行程序或者托盘菜单启动界面").GetPos(&x)
    AddCheckboxEx("noEditMode", "yp x400", "无需编辑器模式", "下次重命名不使用编辑器直接启动本界面`n在完全加载的情况下可按F2手动重命名`n适用于不太频繁在编辑器中编辑的用户`n需手动点击 列表-重命名 开始重命名")
    mg.AddButton("yp x600", "编辑器", "选择默认编辑器`n需编辑器标题能显示文件名").OnEvent("Click", (*) => ChooseEditor())

    AddCheckboxEx("muiltTab", "xs", "多标签编辑器", "多标签编辑器切换标签立即进行重命名")
    mg.AddCheckbox("yp x200 Checked" ini.disableTips, "禁用悬浮提示").OnEvent("Click", (ctrl, info) => (ini.ChangeKey(_tips.disable := ctrl.Value, "disableTips"), _tips.Clear()))
    AddCheckboxEx("fastMode", "yp x400", "加快文件夹重命名速度", "副作用可能会遗留部分文件(被其他程序占用),不能移动到其他硬盘")
    mg.AddButton("yp x600", "备用编辑器", "选择备用编辑器`n一些类似IDE的编辑器启动较慢`n如已经运行则使用此编辑器,否则使用默认编辑器").OnEvent("Click", (*) => ChooseEditor(true))

    AddCheckboxEx("existNum", "xs", "文件存在追加序号", "仅针对修过的文件,多一层检查稍微影响速度`n1.txt 存在时追加为 1_1.txt 防止重名`n不启用则跳过重名文件")
    AddCheckboxEx("trim", "yp x200", "移除首尾空白", "仅操作不带扩展名的文件名")
    AddCheckboxEx("safe", "yp x400", "移除非法字符", "将非法符号替换成全角 比方说*/?`n仅操作文件名")
    mg.AddButton("yp x600", "打开程序所在目录").OnEvent("Click", (*) => Run(A_ScriptDir))

    AddCheckboxEx("env", "xs", "环境变量", "
    (
        启用时将会在重命名时将包含的变量替换为特殊的内容
        需要计算的可能耗时较久,酌情使用
        可手动在编辑器中添加,或简单通过副界面 变量 添加
        <f> 上级目录名称
        <p> 图包目录命名  需要计算 [35P-2V-550M]
        <t> 文件修改时间 需要计算
        <tc> 文件创建时间 需要计算
        <r> 随机八位数字
        <rg> GUID
        <n> 递增数字 详细说明在副界面 变量 中选择悬浮查看
        <d> 当前时间 详细说明同上
    )")
    AddCheckboxEx("autoRe", "yp x200", "启用自动替换", "自动替换中存在符合要求规则时自动替换`n`n启用并存在规则时加载大量文件未修改关闭编辑器可能会影响速度`n`n影响不大,可关闭界面或托盘菜单直接退出")
    reAuto := mg.AddComboBoxEx("", ini.re, "yp", "w168", , , "通过 替换 标签生成规则`n增删会在下次启动时生效", , "w20", , "w20")

    mg.AddText()

    mg.AddComboBoxEx("属性", ini.property, "xs", "x73 w300", , , "资源管理器的属性名称,类似 分辨率 时长等等...`n表示其对应的属性`n在此添加下次启动会在表达式和变量中新增")

    g.mg.tab.UseTab(5)
    mg.AddText("Section")
    etcClassify := mg.AddComboBoxEx("分类", ini.classify, , "x73 w250", , , "提取文件名指定的部分(正则中的$1)`n在文件所在位置新建以此命名的文件夹并移动到此`n通过主界面排除指定属性的文件`n示例`n正则: (\[.+?\])`n路径: D:\test\123 [作者] 666`n结果: D:\test\[作者]\123 [作者] 666")
    etcClassifyOnlyReplace := mg.AddCheckbox("yp", "替换提取的部分", , "启用示例结果: D:\test\[作者]\123  666")
    mg.AddButton("yp", "开始分类").OnEvent("Click", (*) => OtherFunc("分类"))

    mg.AddText()
    mg.AddText("xs", "补零")
    etcAdd0 := mg.AddEditUpDown("位数", "yp x73", "Number w50", "Range2-9", 2, , "某些软件不支持自然语言排序,在数字前增加0便于排序`n位置为空则为第一个出现的数字`n示例: 3`n路径: 你 1 好呀 3.txt`n结果: 你 001 好呀 3.txt ")
    etcAdd0Text := mg.AddTextEdit("位置", "yp", "w260", , , "为在此字符串之后出现的第一个数字补全`n示例: 好`n结果: 你 1 好呀 003.txt")
    mg.AddButton("yp x+60", "开始补零").OnEvent("Click", (*) => OtherFunc("补零"))

    mg.AddText("xs")
    mg.AddButton(, "以TXT文件第一行为文件名", "找到首个不为空的行作为文件名`n如果此行字数超过200则跳过此文件`n可能有编码问题,注意预览").OnEvent("Click", (*) => OtherFunc("检索TXT"))
    mg.AddButton("yp x+50", "合并文件夹", "打开合并文件夹的界面`n与编辑器无关").OnEvent("Click", MergeFolder)
    mg.AddText()

    ChooseEditor(second := false)
    {
        path := mg.FileSelect("1", , app (second ? " 请选择备用编辑器" : " 请选择编辑器"), "*.exe")
        if path
        {
            if !second
                ini.ChangeKey(path, "editor")
            else
                ini.ChangeKey(path, "secondEditor")
        }
    }

    MergeFolder(*)
    {
        static mfHwnd := 0
        if WinExist(mfHwnd)
            return WinActivate()

        mf := GuiEx(" +ToolWindow +Owner" mg.Hwnd, "合并文件夹")
        mfText := mf.AddText("w190", "拖拽进来的文件夹为顶层文件夹`n将此文件夹所有内容移至顶级文件夹并删除所有子文件夹`n`n支持拖拽多项`n非文件夹会跳过`n重名时遵循 文件存在追加序号`n不支持恢复谨慎操作")
        mf.OnEvent("DropFiles", MFDropFiles)
        mf.OnClose((*) => mf.Destroy())
        mfHwnd := mf.Hwnd
        mf.Show("w200 h180")

        MFDropFiles(GuiObj, GuiCtrlObj, FileArray, X, Y)
        {
            count := dirCount := failure := 0
            dirMap := Map()
            for i in FileArray
            {
                if !DirExist(i)
                    continue
                dirCount++
                loop files i "\*.*", "FDR"
                {
                    if InStr(A_LoopFileAttrib, "D")
                    {
                        dirMap[A_LoopFileFullPath] := true
                        continue
                    }
                    sp := pathBase(A_LoopFileFullPath, 0, A_LoopFileAttrib)
                    if sp.dirSave = i
                        continue
                    sp.dir := i
                    if ini.existNum
                        sp.out := PathConflicts(sp.out)
                    try
                        FileMove(sp.souce, sp.out), count++
                    catch
                    {
                        if dirMap.Has(sp.dirSave)
                            dirMap.Delete(sp.dirSave)
                        failure++
                    }
                }
            }
            if count
            {
                for i in dirMap
                {
                    try
                        DirDelete(i)
                    catch
                        failure++
                }

                msg := "合并" dirCount "个文件夹`n合并至上级目录" count "项"
                if failure
                    msg .= "`n失败" failure "项`n可能有残余文件或文件夹"
                mfText.Value := msg
            }
            else
                mfText.Value := "未发生合并"
        }
    }

    OtherFunc(t)
    {
        static isRun := false
        if !data.length || isRun
            return
        if t = "补零"
        {
            if !IsInteger(etcAdd0.Value) || etcAdd0.Value < 2
                return
            try
                RegExMatch(1, etcAdd0Text.Value)
            catch
                return MGTtitle("位置错误,可能包含非法字符")
        }
        else if t = "分类"
        {
            if !etcClassify.Text
                return

            try
                RegExMatch(1, etcClassify.Text)
            catch
                return MGTtitle("正则错误")
        }
        isRun := true
        tmp := ""
        pos := count := 0
        for i in data.currentSp
        {
            if newPos := PosTitle(&pos, A_Index, data.currentSp)
                MGTtitle(t "..." newPos)
            switch t
            {
                case "补零":
                    if RegExMatch(i.nameNoExt, "(" etcAdd0Text.Value ".*?)(\d+)(.*)", &n) && (len := StrLen(n[2])) < etcAdd0.Value
                    {
                        num := n[2]
                        loop etcAdd0.Value - len
                            num := "0" num
                        i.nameNoExt := n[1] num n[3]
                        count++
                    }
                case "分类":
                    if RegExMatch(i.nameNoExt, etcClassify.Text, &_dir)
                    {
                        i.dir := i.dir "\" _dir[1]
                        if etcClassifyOnlyReplace.Value
                            i.nameNoExt := StrReplace(i.nameNoExt, _dir[1])
                        count++
                    }
                case "检索TXT":
                    if StrLower(i.ext) = "txt" && FileExist(i.souce)
                    {
                        loop read, i.souce
                        {
                            if (line := Trim(A_LoopReadLine)) && StrLen(line) <= 200
                            {
                                i.nameNoExt := line, count++
                                break
                            }
                        }
                    }
            }
            tmp .= i.ToTmp(A_Index)
        }
        if count
            FileWrite(tmp, data.path)
        else
            MGTtitle(t "完成,未发生修改")
        isRun := false
    }

    g.mg.tab.Value := tab
    mg.OnClose(Close)
    mg.OnEvent("DropFiles", DropFiles)
    mg.OnEvent("Size", GuiAutoSize)
    g.mg.LV.OnEvent("ItemCheck", LVItemCheck)
    g.mg.LV.OnEvent("ItemSelect", (ctrl, row, Selected) => Selected ? rePath.Value := mg.path := LVGetPath(row) : "")
    g.mg.LV.OnEvent("ContextMenu", LVContextMenu)
    g.mg.LV.OnEvent("ItemEdit", LVItemEdit)
    g.mg.Refresh := Refresh
    g.mg.tab.OnEvent("Change", TabChange)
    pos := ""
    if ini.guiMX && ini.guiMY
        pos := " x" ini.guiMX " y" ini.guiMY
    mg.Show(pos)
    Refresh()

    AddCheckboxEx(var, opt := "", text := "", tips := "") => g.AddCheckboxEx(mg, var, "r2 " opt, text, tips)

    AddExp(gbw := "w650", textw := "w350", textTip := "为空则无条件`n不为空只有在满足条件的情况才会替换", isReplace := true)
    {
        tmp := {}
        mg.AddGroupBox("Section xs r3 " gbw, "表达式").GetPos(&x, &y)
        tmp.x := x
        tmp.y := y
        tmp.path := mg.AddDropDownList("Section x73 y" y + 20, exp.type, "2", , "如需要更多请在 设置 - 属性 添加")
        tmp.exp := mg.AddDropDownList("yp w90", exp.condition, 9, , "= 比较数字及字符串,不区分大小写`n== 区分大小写`n> < 比较数字`n字符串长度不为0则True,否则False")
        tmp.text := mg.AddEdit("yp " textw, , , textTip)
        tmp.text.GetPos(&x1)

        tmp.and := mg.AddRadio("xs r2 Checked", "逻辑与", , "用于追加逻辑")
        tmp.or := mg.AddRadio("yp r2", "逻辑或", , "用于追加逻辑")
        btn := mg.AddButton("yp x" x1, "追加", "在动作流程最后一项中追加表达式")
        btn.OnEvent("Click", AppendExp)

        if isReplace
        {
            tmp.text.Tips .= "`n需手动点击生成"
            tmp.path.Tips .= "`n需手动点击生成"
            tmp.exp.Tips .= "`n需手动点击生成"
            btn.Tips := "追加后不要进行其他操作,否则会恢复"
            mg.AddButton("yp", "替换", "替换最后追加的表达式").OnEvent("Click", btnReplace)
            mg.AddButton("yp", "测试", "用于追加后不能修改的测试").OnEvent("Click", btnTest)

            btnTest(*)
            {
                reTip.Value := true
                if !RegExMatch(reRule.Value, ">>>exp[01]")
                    RuleGenerate()
                else
                    RuleTest(rePath)
            }

            btnReplace(*)
            {
                if !RegExMatch(reRule.Value, ".*(>>>exp[01].*)$", &m)
                    return MGTtitle("未存在追加表达式")
                reRule.Value := StrReplace(reRule.Value, m[1])
                AppendExp()
                btnTest()
            }
        }

        AppendExp(*)
        {
            if !StrLen(tmp.text.Value)
                return MGTtitle("表达式内容为空")

            o := isReplace ? reRule : acEdit

            str := ">>>exp" (tmp.and.Value ? 1 : 0) "<>" tmp.path.Text "<>" tmp.exp.Text "<>" tmp.text.Value
            if InStr(reRule.Value, str)
                return MGTtitle("已存在相同表达式")

            if !isReplace
            {
                a := StrSplit(o.Value, "`n")
                if !InStr(a[a.Length], ";>>>exp<>")
                    return MGTtitle("未设置起始条件")

                o.Value .= str
                acEdit.Value .= str, tmp.text.Value := ""
            }
            else
                o.Value .= str, RuleTest(rePath)
        }
        return tmp
    }

    TabChange(ctrl, info)
    {
        if !reTip.Value
            return
        if ctrl.Value = 2
            TipsChange()
        else
            _tips.disable := ini.disableTips
        _tips.Clear()
    }

    DropFiles(GuiObj, GuiCtrlObj, FileArray, X, Y)
    {
        switch g.mg.tab.Value
        {
            case 1:
                if data.length
                    data.Restore(), Refresh()
                SetTimer(BeginRename.Bind(FileArray), -100)
            case 2:
                rePath.Value := ""
                for i in FileArray
                    if A_Index < 6
                        rePath.Value .= i "`n"
                RuleTest(rePath)
            case 3:
                if DirExist(FileArray[1])
                    acMove.Value := FileArray[1]
        }

    }

    Close(*)
    {
        SavePos()
        mg.Destroy()
        _tips.disable := ini.disableTips
        g.mg := ""
    }

    SavePos()
    {
        g.mg.GetPos(&x, &y, &w, &h)
        ini.ChangeKey(x, "guiMX")
        ini.ChangeKey(y, "guiMY")
    }

    ;更新界面大小
    GuiAutoSize(thisGui, MinMax, Width, Height)
    {
        static _timer := Timer, wDiff := "", hDiff := ""
        SetTimer(_timer, -100)
        if !IsNumber(wDiff)
        {
            WinGetPos(, , &w1, &h1)
            wDiff := w1 - Width, hDiff := h1 - Height
        }

        Timer()
        {
            if MinMax = -1
                return
            g.mg.GetPos(, , &w, &h)

            if IsNumber(wDiff) && IsNumber(hDiff)
                w -= wDiff, h -= hDiff
            g.mg.tab.Move(, , w - 8, h - 2)
            g.mg.LV.Move(, , w - 20, h - 118)
            g.mg.acEdit.Move(, , w - 200, h - 347)

        }
    }

    ;获取当前列的路径
    LVGetPath(row, souce := true, &index := 0)
    {
        index := g.mg.LV.GetText(row, lvArr.Length)
        return souce ? data.currentSp[index].souce : data.currentSp[index].out
    }

    ;手动编辑
    LVItemEdit(ctrl, row)
    {
        ; ini.noEditMode &&
        if ini.previewFull && (out := ctrl.GetText(row, 1)) != LVGetPath(row, , &index)
        {
            sp := data.currentSp[index]
            if dir := ctrl.GetText(row, 5)
                name := sp.Name, sp.name := out
            else
                name := sp.souce, sp.out := out
            if ini.diff || ini.ld
                sp.diffAndLDSet(dir)
            _diff := ini.diff ? sp.diff : ""
            _ld := net.hasNet && ini.ld ? sp.ld : ""
            ctrl.Modify(Row, , name, out, _diff, _ld)
        }
    }

    ;右键菜单
    LVContextMenu(ctrl, Row, IsRightClick, X, Y)
    {
        LVMenu := Menu()

        if Row > 0 && Row <= g.mg.LV.Length && ctrl.HasProp("GetText")
        {
            souce := LVGetPath(Row)
            out := LVGetPath(Row, false)
            LVMenu.Add("复制原路径", (*) => A_Clipboard := souce)
            LVMenu.Add("复制新路径", (*) => A_Clipboard := out)
            LVMenu.Add("复制原路径+新路径", (*) => A_Clipboard := souce "`n" out)
            LVMenu.Add()
            LVMenu.Add("打开文件", (*) => Run(souce))
            LVMenu.Add("打开所在文件夹", (*) => OpenAndSelect(souce))
            LVMenu.Add()
            LVMenu.Add("选中多行", (*) => LVSelected())
            LVMenu.Add("取消选中多行", (*) => LVSelected(false))
            LVMenu.Add()
        }
        LVMenu.Add("自动调整列宽", (*) => LVRowAuto())
        LVMenu.Add("还原初始列宽", (*) => LVRowAuto(false))
        LVMenu.Show(X, Y)
    }

    ;调整列宽
    LVRowAuto(auto := true)
    {
        if auto
        {
            loop lvArr.Length
                g.mg.LV.ModifyCol(A_Index, "AutoHdr")
            return
        }
        g.mg.LV.ModifyCol(1, 300)
        g.mg.LV.ModifyCol(2, 300)
        g.mg.LV.ModifyCol(3, 200)
        g.mg.LV.ModifyCol(4, "Integer AutoHdr")
        g.mg.LV.ModifyCol(5, 100)
        g.mg.LV.ModifyCol(6, "Integer AutoHdr")
        g.mg.LV.ModifyCol(7, "Integer AutoHdr")
        g.mg.LV.ModifyCol(8, "Integer 50")
    }

    ;选中项目并在过滤map中增减
    LVItemCheck(ctrl, Row, Checked)
    {
        path := LVGetPath(Row)
        if Checked
        {
            if !data.continueMap.Has(path)
                data.continueMap[path] := true
        }
        else
        {
            if data.continueMap.Has(path)
                data.continueMap.Delete(path)
        }
        ctrl.Modify(Row, Checked ? "Check" : "-Check", , , , , , , Checked)
    }

    ;选中或清除选中
    LVSelected(Checked := true)
    {
        Row := 0
        Loop
        {
            Row := g.mg.LV.GetNext(Row)
            if !Row
                break
            path := LVGetPath(Row)
            isNew := true
            if Checked
                data.continueMap[path] := true
            else if data.continueMap.Has(path)
                data.continueMap.Delete(path)
            g.mg.LV.Modify(Row, Checked ? "Check" : "-Check", , , , , , , Checked)
        }
    }

    ;更新列表
    Refresh(*)
    {
        static rTimer := timer, cancel := false

        if !data.inEdit
        {
            g.mg.LV.Delete(), g.mg.LV.Length := 0
            return MGTtitle("未在编辑状态")
        }

        cancel := true
        SetTimer(rTimer, -200)

        timer()
        {
            static arr := [], df := -1, ld := -1, dataVersion := -1, previewFull := -1, InitChange := false, sub := false, thisGui := ""

            if !data.length
                return g.mg.LV.Delete()

            cancel := false
            count := 0
            ;0返回,1,更新,2,清空并更新
            s := 0
            if previewFull != ini.previewFull
                s := 2, g.mg.LV.Opt((ini.previewFull ? "-" : "") "ReadOnly")
            else if thisGui != g.mg || dataVersion != data.version || sub != (ini.subFolder && ini.subLevel)
                s := 2
            else if data.InitTime != (time := data.time) || InitChange
            {
                states1 := df != ini.diff || (net.hasNet && ld != ini.ld)    ;状态切换
                states2 := ini.isIniChange || data.timeSave != time    ;存在修改
                if ini.previewFull
                {
                    if states1 || states2
                        s := 1
                }
                else
                {
                    if states2
                        s := 2
                    else if states1
                        s := 1
                }
            }

            if !s
                return MGTtitle("未发生修改")

            if s = 2
                arr := [], df := ld := -1, g.mg.LV.Delete(), InitChange := false
            else
                g.mg.LV.ModifyCol(lvArr.Length, "Sort")

            if !(!ini.previewFull && s = 1)
            {
                g.mg.LV.Length := data.length
                g.mg.LV.Opt("Count" data.length)

                if (arr2 := data.TmpToArr()) = -1
                    return MTitle("原始文件与目标文件数量不符")
                env.retsore()
                pos := 0
                for i in data.currentSp
                {
                    if !g.mg
                        return

                    if !g.wait || cancel
                        return

                    if newPos := PosTitle(&pos, A_Index, data.currentSp)
                        MGTtitle((ini.previewFull ? "加载中..." : "刷新中... ") newPos, false)

                    if pathBase.Batch(i, arr2[A_Index], i.attrib) = -1 && !ini.previewFull
                        continue

                    if IsChange := i.IsChange
                        count++, InitChange := true
                    if !ini.previewFull
                    {
                        if IsChange
                            arr.Push(i)
                        continue
                    }

                    if (dirChange := i.dir != i.dirSave)
                        souce := i.souce, out := i.out, dir := i.diff := i.ld := "", IsChange := true
                    else
                        souce := i.nameSave, out := i.name, dir := i.dirSave

                    if IsChange && (ini.diff || ini.ld)
                        i.diffAndLDSet(dirChange ? true : dir)

                    out := IsChange ? out : ""
                    _diff := IsChange && ini.diff ? i.diff : ""
                    _ld := IsChange && ini.ld ? i.ld : ""
                    if s = 1
                    {
                        if dirChange
                            g.mg.LV.Modify(A_Index, , souce, out, _diff, _ld, "")
                        else
                            g.mg.LV.Modify(A_Index, , , out, _diff, _ld)
                    }
                    else
                    {
                        isCheck := data.continueMap.Has(i.souce)
                        g.mg.LV.Add("Check" isCheck, souce, out, _diff, _ld, dir, i.isDir, isCheck, A_Index)
                    }
                }
            }


            if !ini.previewFull && (s > 0)
            {
                g.mg.LV.Length := arr.Length
                g.mg.LV.Opt("Count" arr.Length)
                pos := 0
                for i in arr
                {
                    if !g.mg
                        return
                    if !g.wait || cancel
                        return g.mg.LV.Delete()

                    if newPos := PosTitle(&pos, A_Index, arr)
                        MGTtitle("加载中... " newPos, false)

                    if i.dir == i.dirSave
                        souce := i.nameSave, out := i.name, dir := i.dirSave
                    else
                        souce := i.souce, out := i.out, dir := ""

                    if ini.diff || ini.ld
                        i.diffAndLDSet(dir)

                    if s = 2
                    {
                        isCheck := data.continueMap.Has(i.souce)
                        g.mg.LV.Add("Check" isCheck, souce, out, ini.diff ? i.diff : "", ini.ld ? i.ld : "", dir, i.isDir, isCheck, A_Index)
                    }
                    else
                        g.mg.LV.Modify(A_Index, , , , ini.diff ? i.diff : "", ini.ld ? i.ld : "")
                }
            }

            ini.isIniChange := false
            data.timeSave := data.time
            dataVersion := data.version
            previewFull := ini.previewFull
            df := ini.diff
            ld := ini.ld
            thisGui := g.mg
            sub := (ini.subFolder && ini.subLevel)
            MGTtitle("刷新完成,共 " data.length " 项, " count " 项将会被重命名", false)
        }
    }

    ;追加全局条件
    ActionAddExp(*)
    {
        if !StrLen(acExp.text.Value)
            return MGTtitle("表达式内容为空")
        str := ";全局;;>>>exp<>" acExp.path.Text "<>" acExp.exp.Text "<>" acExp.text.Value
        if InStr(acEdit.Value, str)
            return MGTtitle("已存在相同操作")
        acEdit.Value .= "`n" str
        acExp.text.Value := ""
    }

    ;用于整理的操作,必需包含条件
    ActionAddIO(t, str)
    {
        if !StrLen(acExp.text.Value) && !InStr(acEdit.Value, ";全局;;>>>exp<>")
            return MGTtitle("未设置条件")
        if StrLen(acExp.text.Value)
            str .= ";>>>exp<>" acExp.path.Text "<>" acExp.exp.Text "<>" acExp.text.Value
        acExp.text.Value := ""
        acMove.Value := ""
        acEdit.Value .= "`n" ";" t ";" str
    }

    ;追加动作流程
    ActionAdd(t, str)
    {
        if !StrLen(str)
            return MGTtitle("内容为空")

        str := ";" t ";" str
        if StrLen(acExp.text.Value)
            str .= ";>>>exp<>" acExp.path.Text "<>" acExp.exp.Text "<>" acExp.text.Value

        for i in StrSplit(acEdit.Value, "`n")
            if i == str
                return MGTtitle("已存在相同操作")

        acExp.text.Value := ""
        acMove.Value := ""
        acEdit.Value .= "`n" str
    }

    ;保存动作流程
    ActionSave(ctrl, info := "")
    {
        if !acEdit.Value || !acName.Value
            return MGTtitle("未设置名称或未存在动作流程")

        nameSafe := RenameSafe(acName.Value)
        if !DirExist(action.dir)
            DirCreate(action.dir)

        f := FileOpen(action.dir nameSafe, "w")
        f.Write(Trim(acEdit.Value, "`n"))
        f.Close()

        if ctrl = "替"
        {
            if data.inEdit
                action.Exec(nameSafe), MGTtitle("保存并替换")
            else
                MGTtitle("未在编辑状态")
        }
        else
            MGTtitle("保存完成")

        for i in acArr
            if nameSafe = i
                return
        acArr.Push(nameSafe)
        acAll.Delete()
        acAll.Add(acArr)
        acAll.Value := acArr.Length
        g.ex.acAll.Delete()
        g.ex.acAll.Add(acArr)
        g.ex.acAll.Value := acArr.Length
    }

    ;导入并测试替换规则
    RuleInput(ctrl, info)
    {
        if !(text := ctrl.Value)
            return

        if RegExMatch(text, "^;替换;(.+)")
        {
            text := StrReplace(text, ";替换;")
            text := StrReplace(text, ";;>>>exp<>", ";>>>exp<>")
        }

        arr := StrSplit(text, ";")

        if arr.Length < 5
            return reResult.Value := "导入错误 " A_TickCount
        reExp.text.Value := ""
        try
        {
            reDescription.Value := arr[1]
            reReplacement.Value := arr[3]
            reIsRe.Value := arr[4] = 1

            if arr[4] = 2
                reIgnoreCase.Value := 1
            else if reIsRe.Value && RegExMatch(arr[2], "(i.*\))", &flags)
            {
                reIgnoreCase.Value := 1
                if flags[1] ~= "^i\)$"
                    arr[2] := StrReplace(arr[2], "i)")
                else
                    arr[2] := StrReplace(arr[2], flags[1], StrReplace(flags[1], "i"))
            }
            else
                reIgnoreCase.Value := 0

            reNeedle.Value := arr[2]
            rePathType.Value := arr[5] + 1
            if arr.Length > 5 && arr[6]
            {
                arr2 := StrSplit(arr[6], ">>>exp")
                if arr2.Length < 2
                    return
                arr3 := StrSplit(arr2[arr2.Length], "<>")

                if arr3.Length < 4
                    return

                if InStr(arr3[1], "1")
                    reExp.and.Value := 1
                else if InStr(arr3[1], "0")
                    reExp.or.Value := 1
                if exp.typeMap.Has(arr3[2])
                    reExp.path.Text := arr3[2]
                for i in exp.condition
                    if i = arr[3]
                        reExp.exp.Text := arr3[3]
                reExp.text.Value := arr3[4]
            }
            reRule.Value := text
            RuleTest(rePath)
        }
        catch Error as e
            return reResult.Value := "导入错误`n" e.What "`n" e.Message
    }

    ;添加替换规则到其他地方或直接执行替换
    RuleButton(ctrl, info)
    {
        if !reRule.Value
            return
        if !rePathType.Value && (ctrl.Text == "添加到替换" || ctrl.Text == "直接替换")
            return

        switch ctrl.Text
        {
            case "添加到自动替换": reAuto.Text := reRule.Value, g.mg.tab.Value := 4
            case "添加到替换": g.ex.reSave.Text := reRule.Value
            case "追加到动作流程":
                acEdit.Value .= "`n;替换;"
                if StrLen(reExp.text.Value)
                    acEdit.Value .= StrReplace(reRule.Value, ";>>>exp<>", ";;>>>exp<>")
                else
                    acEdit.Value .= reRule.Value
                g.mg.tab.Value := 3
            case "直接替换":
                g.ex.reSave.Text := reRule.Value
                g.ex.Change.Call("re")
        }
    }

    ;生成替换规则
    RuleGenerate(*)
    {
        n := reNeedle.Value
        isReNum := reIsRe.Value
        if reIsRe.Value
        {
            if reIgnoreCase.Value
            {
                if RegExMatch(n, "^\s?([imsxADJUXSC`a`n`r]*)\)", &flags)
                {
                    if !InStr(flags[1], "i")
                        n := "i" n
                }
                else
                    n := "i)" n

            }
            else if RegExMatch(n, "(^\s?([imsxADJUXSC`a`n`r]*)\))", &flags) && InStr(flags[2], "i")
            {
                flag := StrReplace(flags[2], "i")
                n := StrReplace(n, flags[1], flag (StrLen(flag) ? ")" : ""))
            }
        }
        else
            isReNum := reIgnoreCase.Value ? 2 : 0

        n := reDescription.Value ";" n

        n .= ";" reReplacement.Value ";" isReNum ";" rePathType.Value - 1
        reRule.Value := n ";"
        if StrLen(reExp.text.Value)
            reRule.Value .= ">>>exp<>" reExp.path.Text "<>" reExp.exp.Text "<>" reExp.text.Value
        RuleTest(rePath)
    }

    ;测试替换规则
    RuleTest(ctrl, info := "")
    {
        TipsChange()
        s := Trim(ctrl.Value, '"')
        if ctrl.Value !== s
            ctrl.Value := s

        if !reRule.Value
        {
            RuleGenerate()
            if !reRule.Value
                return
        }

        count := 0
        reResult.Value := ""
        for i in StrSplit(s, "`n")
        {
            if !i
                continue

            sp := pathBase(i, DirExist(i), Get(i, "attrib", ""))
            arr := StrSplit(reRule.Value, ";")

            if arr[6]
            {
                _t := arr[6]
                arr[6] := exp.String2Arr(&(s := ";" arr[6]))
                if reTip.Value
                    try
                    {
                        res := exp.Exec(arr[6], sp, &var := "")
                        ToolTipEx(var "结果 : " (res ? "符合" : "不符合"), 2000)
                    }
                    catch Error as e
                        ToolTipEx("表达式错误 : " _t "`n" e.What "`n" e.Message, 2000)
            }

            try
                edit.REItem(sp, arr)
            catch Error as e
                return reResult.Value := e.What "`n" e.Message

            reResult.Value .= sp.out "`n"
            count += sp.count

        }
        MGTtitle("替换" count "项", false)
    }

    TipsChange()
    {
        if reTip.Value && StrLen(reExp.text.Value)
            _tips.disable := true, _tips.Clear()
        else
            _tips.disable := ini.disableTips
    }

    MGTtitle(str, tick := true) => g.mg.Title := str (tick ? " " A_TickCount : "") " - " app net.title
}

RunEditor(path)
{
    SplitPath(path, &title, &runDir)
    editor := ini.editor
    if ini.secondEditor && FileExist(ini.secondEditor)
    {
        SplitPath(ini.secondEditor, &editorName)
        if editorName && WinExist("ahk_exe " editorName)
            editor := ini.secondEditor
    }
    Run(editor ' "' path '"', runDir)
    return title
}

;等待临时文件关闭
RunEditorWait(path, bool := false, rename := true)
{
    if g.mg || rename && ini.noEditMode
    {
        while g.wait
            Sleep(50)
        return true
    }
    else
    {

        time := Get(path, "time")
        title := RunEditor(path)
        if hwnd := WinWait(title, , 3)
        {
            data.title := hwnd
            if ini.muiltTab
            {
                while WinExist(title)
                {
                    if !g.wait
                        break
                    Sleep(100)
                }
            }
            else
            {
                loop
                {
                    if !g.wait || WinWaitClose(hwnd, , 0.2)
                        break
                }
            }

            try
                if bool || !g.wait || Get(path, "time") != time
                    return true
            catch
                return false
        }
        else
        {
            if g.gui
                g.gui.Opt("+OwnDialogs")
            MsgBox("编辑器可能配置错误,即将退出", app)
            TryFileDelete(data.path)
            ExitApp()
        }
    }
}

;开始重命名
BeginRename(list)
{
    if data.length
        return

    data.version++
    if ini.gui && !g.gui
        MainGui()
    if !g.mg && ini.noEditMode && data.version
        MoreGui()

    data.Init(list)

    success := 0
    failure := 0

    if RunEditorWait(data.path, ini.autoRe && ini.reArr.Length) && data.length
    {
        if (arr2 := data.TmpToArr(true)) = -1
            ExitApp(1)
        pos := 0
        env.retsore()
        for i in data.currentSp
        {
            index := A_Index

            if newPos := PosTitle(&pos, A_Index, data.currentSp)
                MTitle(newPos)

            if pathBase.Batch(i, arr2[index], i.attrib) = -1
                continue

            if data.continueMap.Has(i.souce)
                continue

            successSave := success
            i.Move(&success, &failure)
            if i.isDir && success > successSave
            {
                for k in data.currentSp
                {
                    if A_Index <= index
                        continue
                    if !InStr(k.out, i.souce)
                        break
                    k.out := StrReplace(k.out, i.souce, i.out)
                }
            }
        }
    }
    TryFileDelete(data.path)

    log.Save()

    willExit := !g.gui || (A_Args.Length && ini.exit && success)
    if willExit && g.gui && WinExist(g.gui.Hwnd)
        CloseG(0)

    if success || failure
    {
        msg := app ": 已处理 " success "/" data.length " 项"
        if failure
            msg .= "; 失败: " failure " 项"
        ToolTipEx(msg, 2000, willExit)
    }
    else
        ToolTipEx("未发生修改")

    if willExit
        ExitApp()

    if success || failure
        MTitle(success "/" failure "/" data.length)
    else
        MTitle(0)

    data.Restore()
    data.version++
    g.wait := true
    g.Refresh()
}

;分隔路径
SplitPathEx(Path, &name := "", &dir := "", &ext := "", &nameNoExt := "", isDir := false)
{
    SplitPath(Path, &name, &dir, &ext, &nameNoExt)
    if isDir && ext
        nameNoExt := name, ext := ""
}

IsLastLine(index) => index = data.length ? "" : "`n"

PosTitle(&pos, index, arr)
{
    if index > pos + 100
        return arr.Length - (pos := index) "/" arr.Length
}

#Include <CreateGUID>
#Include <GuiEx>
#Include <GetSizeReadable>
#Include <RenameSafe>
#Include <Convert>
#Include <PathConflicts>
#Include <OpenAndSelect>
#Include <ShellProperty>
#Include <Diff>
#Include <CLR>
#Include <IsWinCover>