#SingleInstance force
SetWorkingDir(A_ScriptDir)
FileEncoding("UTF-8")
SendMode("Input")

if !A_Args.Length
    ExitApp()

count := 0
failure := 0
loop parse FileRead(A_Args[1]), "`n", "`r"
{
    if (A_LoopField ~= "<-->移动$")
    {
        tmp := StrSplit(A_LoopField, "<-->")
        if tmp.Length == 3 && FileExist(tmp[2])
        {
            try
            {
                FileMove(tmp[2], tmp[1])
                count++
            }
            catch
                failure++
        }
    }
}

if count
{
    ToolTip("共恢复: " count " 项; 失败: " failure " 项")
    Sleep(2000)
}