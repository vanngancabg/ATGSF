
IsGameForegroundV63(hotkeyName := "")
{
    static lastCheck := 0, lastHwnd := 0, lastResult := false
    hwnd := DllCall("GetForegroundWindow","Ptr")
    if (!hwnd)
        return lastResult := false
    if (hwnd = lastHwnd && A_TickCount - lastCheck < 250)
        return lastResult
    lastCheck := A_TickCount, lastHwnd := hwnd
    WinGet, activePid, PID, ahk_id %hwnd%
    WinGet, activeProcess, ProcessName, ahk_id %hwnd%
    if (!(activeProcess="Game.exe" || activeProcess="Diablo II.exe" || activeProcess="D2.exe"))
        return lastResult := false
    return lastResult := activePid && D2GetModuleBaseV35(activePid,"D2Client.dll")!=0
}
IsGameActive()
{
    return GameTargetHwndV63()!=0
}

BackgroundBirthV63(pid)
{
    h := DllCall("OpenProcess","UInt",0x1000,"Int",0,"UInt",pid,"Ptr")
    if (!h)
        return ""
    VarSetCapacity(created,8,0), VarSetCapacity(exited,8,0)
    VarSetCapacity(kernel,8,0), VarSetCapacity(user,8,0)
    ok := DllCall("GetProcessTimes","Ptr",h,"Ptr",&created,"Ptr",&exited,"Ptr",&kernel,"Ptr",&user)
    DllCall("CloseHandle","Ptr",h)
    return ok ? Format("{:08X}{:08X}",NumGet(created,4,"UInt"),NumGet(created,0,"UInt")) : ""
}

BackgroundBindV63(hwnd := 0)
{
    global backgroundHwndV63, backgroundPidV63, backgroundBirthV63
    if (!hwnd)
    {
        if (!IsGameForegroundV63())
            return false
        hwnd := WinExist("A")
    }
    WinGet, pid, PID, ahk_id %hwnd%
    WinGet, process, ProcessName, ahk_id %hwnd%
    WinGetTitle, title, ahk_id %hwnd%
    if (!pid || !(process="Game.exe" || process="Diablo II.exe" || process="D2.exe" || InStr(title,"Diablo II"))
        || !D2GetModuleBaseV35(pid,"D2Client.dll"))
        return false
    birth := BackgroundBirthV63(pid)
    if (birth="")
        return false
    backgroundHwndV63 := hwnd, backgroundPidV63 := pid, backgroundBirthV63 := birth
    return true
}

BackgroundValidV63()
{
    global backgroundHwndV63, backgroundPidV63, backgroundBirthV63
    if (!backgroundHwndV63 || !DllCall("IsWindow","Ptr",backgroundHwndV63))
        return false
    WinGet, pid, PID, ahk_id %backgroundHwndV63%
    WinGet, minmax, MinMax, ahk_id %backgroundHwndV63%
    return pid=backgroundPidV63 && minmax!=-1 && BackgroundBirthV63(pid)=backgroundBirthV63
}

BackgroundInputWatchV553()
{
    return
}

BackgroundRefreshV690(w)
{
    global backgroundBlockReasonV553
    hwnd := w.hwnd,pid := w.pid
    if (!hwnd || !pid || w.birth="" || !DllCall("IsWindow","Ptr",hwnd))
        return false
    WinGet, actualPid, PID, ahk_id %hwnd%
    if (actualPid!=pid || BackgroundBirthV63(pid)!=w.birth)
        return false
    appQueued := DllCall("PostMessage","Ptr",hwnd,"UInt",0x1C,"UPtr",1,"Ptr",0)
    windowQueued := DllCall("PostMessage","Ptr",hwnd,"UInt",0x6,"UPtr",1,"Ptr",0)
    focusQueued := DllCall("PostMessage","Ptr",hwnd,"UInt",0x7,"UPtr",0,"Ptr",0)
    queued := appQueued && windowQueued && focusQueued
    backgroundBlockReasonV553 := queued ? "" : "Chưa gửi được kích hoạt nền; sẽ thử lại nhịp sau."
    PortalLogWriteV66("BACKGROUND_INPUT_REFRESH pid=" . pid . " app_queued=" . appQueued
        . " window_queued=" . windowQueued . " focus_queued=" . focusQueued
        . " cadence_ms=1000 foreground_forced=0 actual_activation=UNCONFIRMED"
        ,"BACKGROUND_INPUT_REFRESH",1000)
    return queued
}

BackgroundActivityViewV693(hwnd)
{
    v := BackgroundViewReadV692(hwnd)
    result := BackgroundActivityTextV692(v.activity)
    return result
}

BackgroundActivityV692(previous,live,attacking)
{
    if (!IsObject(live))
        return "NO_PLAYER"
    if (live.HasKey("mode") && (live.mode=0 || live.mode=17))
        return "DEAD"
    if (attacking)
        return "ATTACK"
    if (!IsObject(previous) || previous.pid!=live.pid || previous.birth!=live.birth)
        return "SAMPLING"
    if ((live.x-previous.x)**2+(live.y-previous.y)**2>=1)
        return "MOVE"
    if (FarmReviveTownLevelV295(live.level))
        return "TOWN"
    return "IDLE"
}

BackgroundActivityTextV692(activity)
{
    if (activity="NO_WINDOW")
        return "mất"
    if (activity="NO_PLAYER")
        return "mất NV"
    if (activity="DEAD")
        return "chết"
    if (activity="SAMPLING")
        return "đo"
    if (activity="ATTACK")
        return "đánh"
    if (activity="MOVE")
        return "đi"
    if (activity="TOWN")
        return "thành"
    return "đứng"
}

BackgroundViewReadV692(hwnd)
{
    global currentAttackPidV550,currentAttackUidV520,currentAttackAtV520
    static previous := false
    v := {activity:"NO_WINDOW", level:0}
    if (!hwnd || !DllCall("IsWindow","Ptr",hwnd))
    {
        previous := false
        return v
    }
    WinGet, pid, PID, ahk_id %hwnd%
    contact := {pid:pid,hwnd:hwnd,birth:pid ? BackgroundBirthV63(pid) : ""}
    live := false
    try
        live := FarmStandSampleV650(contact)
    attacking := FarmWatchAttackingV688(live,currentAttackPidV550,currentAttackUidV520
        ,currentAttackAtV520,A_TickCount)
    v.activity := BackgroundActivityV692(previous,live,attacking)
    v.level := IsObject(live) ? live.level : 0
    previous := live
    return v
}


FarmBackgroundContextV704()
{
    global mapControlGuiStartV180,mapStage1BuffDoneV248,stage2StartPendingV381
    global farmDeadStartV695,coordTrackingEnabledV409
    return FarmControlRunningV186() || mapControlGuiStartV180 || IsObject(mapStage1BuffDoneV248)
        || stage2StartPendingV381 || IsObject(farmDeadStartV695) || coordTrackingEnabledV409
}


GameTargetHwndV63()
{
    global autoMonsterAttackOn, coordGoV59, backgroundHwndV63,sigTownV148,scosEntryV162,stageTwoV166,sigBackgroundV179,pickupBackgroundV181,pickupImageOn,sigBusyV147,pickupGroupActiveV26
    global mainToolHwndV67,buffSequenceOnV555
    static resolvingToolTargetV67 := false
    if (mainToolHwndV67 && WinActive("ahk_id " . mainToolHwndV67))
    {
        if (BackgroundValidV63())
            return backgroundHwndV63
        if (resolvingToolTargetV67)
            return 0
        resolvingToolTargetV67 := true
        try
            boundToolTargetV67 := SigBackgroundBindV179()
        finally
            resolvingToolTargetV67 := false
        return boundToolTargetV67 && BackgroundValidV63() ? backgroundHwndV63 : 0
    }
    if (FarmBackgroundContextV704() || (pickupBackgroundV181 && (pickupImageOn || pickupGroupActiveV26)) || sigBackgroundV179 || sigBusyV147 || buffSequenceOnV555 || autoMonsterAttackOn || IsObject(coordGoV59) || IsObject(scosEntryV162) || IsObject(stageTwoV166) || (IsObject(sigTownV148) && sigTownV148.auto))
        return BackgroundBoundTargetV705()
    return IsGameForegroundV63() ? WinExist("A") : 0
}

BackgroundBoundTargetV705()
{
    global backgroundPidV63,backgroundHwndV63,backgroundBirthV63
    static resolving := false,lastTry := 0
    if (BackgroundValidV63())
        return backgroundHwndV63
    if (resolving || (lastTry && A_TickCount-lastTry<500))
        return 0
    pid := backgroundPidV63,birth := backgroundBirthV63
    if (!pid || birth="" || BackgroundBirthV63(pid)!=birth)
        return 0
    resolving := true,lastTry := A_TickCount
    try
    {
        if (!SigBackgroundBindV179(pid) || !BackgroundValidV63())
            return 0
        PortalLogWriteV66("AUTO_BACKGROUND_TARGET_REBOUND pid=" . backgroundPidV63
            . " hwnd=" . backgroundHwndV63 . " tool_focus_required=0")
        return backgroundHwndV63
    }
    finally
        resolving := false
}


GameTargetMessageV63(hwnd,msg,wParam,lParam)
{
    if (!hwnd || GameTargetHwndV63()!=hwnd)
        return false
    return DllCall("PostMessage","Ptr",hwnd,"UInt",msg,"UPtr",wParam,"Ptr",lParam)
}

GameTargetKeyV63(spec)
{
    global sigBusyV147,sigSendingKeyV147,sigTownV148,sigTownSendingV148
    if (IsObject(sigTownV148) && !sigBusyV147 && !sigTownSendingV148 && !InStr(spec," up}"))
    {
        MapKeyTraceV174(spec,"BLOCK_SIG_TOWN")
        return false
    }
    if (sigBusyV147 && !sigSendingKeyV147 && !InStr(spec," up}"))
    {
        MapKeyTraceV174(spec,"BLOCK_SIG_BUSY")
        return false
    }
    if (!RegExMatch(spec,"i)^\{?(?:Ctrl|LControl)(?:\s+(?:down|up))?\}?$"))
        MovementCtrlSetV78(false,0,"KEY " . spec)
    static held := {}
    key := Trim(spec), action := ""
    if (RegExMatch(key,"^\{(.+?)(?:\s+(down|up))?\}$",m))
        key := m1, action := m2
    if (action!="up" && !DeathlordPressGateV87(key))
    {
        MapKeyTraceV174(spec,"BLOCK_DEATHLORD_GATE")
        return false
    }
    if (key="LButton" || key="RButton" || key="MButton" || key="XButton1" || key="XButton2"
        || key="WheelUp" || key="WheelDown")
        return GameTargetMouseKeyV64(key,action)
    vk := GetKeyVK(key), sc := GetKeySC(key)
    if (!vk)
    {
        MapKeyTraceV174(spec,"BLOCK_INVALID_KEY")
        return false
    }
    lp := 1 | ((sc & 255)<<16) | ((sc & 256) ? 0x1000000 : 0)
    if (action="up" && held.HasKey(key))
    {
        target := held[key], held.Delete(key)
        WinGet, pid, PID, % "ahk_id " . target.hwnd
        if (!DllCall("IsWindow","Ptr",target.hwnd) || pid!=target.pid || BackgroundBirthV63(pid)!=target.birth)
            return false
        return DllCall("PostMessage","Ptr",target.hwnd,"UInt",0x101,"UPtr",vk,"Ptr",lp|0xC0000000)
    }
    hwnd := GameTargetHwndV63()
    if (!hwnd)
    {
        MapKeyTraceV174(spec,"BLOCK_NO_TARGET")
        return false
    }
    WinGet, pid, PID, ahk_id %hwnd%
    birth := BackgroundBirthV63(pid)
    if (action="up")
        return GameTargetMessageV63(hwnd,0x101,vk,lp|0xC0000000)
    if (!GameTargetMessageV63(hwnd,0x100,vk,lp))
    {
        MapKeyTraceV174(spec,"KEYDOWN_FAILED")
        return false
    }
    MapKeyTraceV174(spec,"KEYDOWN_QUEUED")
    if (action="down")
    {
        held[key] := {hwnd:hwnd,pid:pid,birth:birth}
        return true
    }
    Sleep, 30
    WinGet, nowPid, PID, ahk_id %hwnd%
    if (!DllCall("IsWindow","Ptr",hwnd) || nowPid!=pid || BackgroundBirthV63(pid)!=birth)
        return false
    keyUpQueuedV174 := DllCall("PostMessage","Ptr",hwnd,"UInt",0x101,"UPtr",vk,"Ptr",lp|0xC0000000)
    MapKeyTraceV174(spec,"KEYUP_QUEUED=" . keyUpQueuedV174)
    return keyUpQueuedV174
}

GameTargetMouseKeyV64(key,action := "")
{
    MovementCtrlSetV78(false,0,"MOUSE_KEY " . key)
    global backgroundAimV64
    static held := {}
    hwnd := GameTargetHwndV63()
    if (action="up" && held.HasKey(key))
    {
        target := held[key], held.Delete(key)
        WinGet, pid, PID, % "ahk_id " . target.hwnd
        if (!DllCall("IsWindow","Ptr",target.hwnd) || pid!=target.pid || BackgroundBirthV63(pid)!=target.birth)
            return false
        return DllCall("PostMessage","Ptr",target.hwnd,"UInt",target.msg+1,"UPtr",target.upFlag,"Ptr",target.lp)
    }
    if (!hwnd)
        return false
    if (IsObject(backgroundAimV64) && backgroundAimV64.hwnd=hwnd)
        x := backgroundAimV64.x, y := backgroundAimV64.y
    else
    {
        VarSetCapacity(rect,16,0)
        if (!DllCall("GetClientRect","Ptr",hwnd,"Ptr",&rect))
            return false
        x := NumGet(rect,8,"Int")//2, y := NumGet(rect,12,"Int")//2
    }
    PortalLogWriteV66("MOUSE_KEY key=" . key . " action=" . action . " client_xy=" . x . "," . y . " hwnd=" . hwnd)
    lp := ((Round(y)&65535)<<16)|(Round(x)&65535)
    if (key="WheelUp" || key="WheelDown")
    {
        VarSetCapacity(pt,8,0), NumPut(x,pt,0,"Int"), NumPut(y,pt,4,"Int")
        if (!DllCall("ClientToScreen","Ptr",hwnd,"Ptr",&pt))
            return false
        lp := ((NumGet(pt,4,"Int")&65535)<<16)|(NumGet(pt,0,"Int")&65535)
        return GameTargetMessageV63(hwnd,0x20A,((key="WheelUp" ? 120 : -120)&65535)<<16,lp)
    }
    msg := key="LButton" ? 0x201 : key="RButton" ? 0x204 : key="MButton" ? 0x207 : 0x20B
    upFlag := key="XButton1" ? 0x10000 : key="XButton2" ? 0x20000 : 0
    flag := upFlag | (key="LButton" ? 1 : key="RButton" ? 2 : key="MButton" ? 16 : key="XButton1" ? 32 : 64)
    if (action="up")
        return GameTargetMessageV63(hwnd,msg+1,upFlag,lp)
    if (!GameTargetMessageV63(hwnd,0x200,0,lp) || !GameTargetMessageV63(hwnd,msg,flag,lp))
        return false
    if (action="down")
    {
        WinGet, pid, PID, ahk_id %hwnd%
        held[key] := {hwnd:hwnd,pid:pid,birth:BackgroundBirthV63(pid),msg:msg,upFlag:upFlag,lp:lp}
        return true
    }
    return GameTargetMessageV63(hwnd,msg+1,upFlag,lp)
}

GameTargetAimV63(x,y)
{
    global backgroundAimV64
    hwnd := GameTargetHwndV63()
    if (!GameTargetMessageV63(hwnd,0x200,0,((Round(y)&65535)<<16)|(Round(x)&65535)))
        return false
    backgroundAimV64 := {hwnd:hwnd,x:x,y:y}
    return true
}

GameTargetClickV63(button := "Right",x := -1,y := -1)
{
    MovementCtrlSetV78(false,0,"CLICK " . button)
    global autoMonsterAttackOn,scosEntryV162
    if (autoMonsterAttackOn && button="Left")
        PortalLogWriteV66("FARM_LEFT_CLICK requested_xy=" . x . "," . y . " source=WINDOW_CLICK helper=GameTargetClickV63")
    hwnd := GameTargetHwndV63()
    if (!hwnd)
        return false
    if ((x<0 || y<0) && button="Right" && IsObject(scosEntryV162)
        && scosEntryV162.map="BO" && scosEntryV162.phase="LOAD")
    {
        pointV454 := BOBuffPointV454(hwnd)
        if (!IsObject(pointV454))
            return false
        x := pointV454.x,y := pointV454.y
        PortalLogWriteV66("BO_FINAL_BUFF_AT_PLAYER client_xy=" . x . "," . y)
    }
    if (x<0 || y<0)
    {
        VarSetCapacity(rect,16,0)
        if (!DllCall("GetClientRect","Ptr",hwnd,"Ptr",&rect))
            return false
        x := NumGet(rect,8,"Int")//2, y := NumGet(rect,12,"Int")//2
    }
    lp := ((Round(y)&65535)<<16)|(Round(x)&65535)
    right := button="Right", msg := right ? 0x204 : 0x201, flag := right ? 2 : 1
    PortalLogWriteV66("WINDOW_CLICK button=" . button . " client_xy=" . x . "," . y . " hwnd=" . hwnd)
    if (!GameTargetMessageV63(hwnd,0x200,0,lp) || !GameTargetMessageV63(hwnd,msg,flag,lp))
        return false
    return GameTargetMessageV63(hwnd,msg+1,0,lp)
}

; V454: buff chinh minh tai vi tri nhan vat thuc tren man hinh.
; Neu khong doc duoc vi tri thi KHONG click giua man hinh (co the cham NPC).
GameTargetBuffSelfClickV454()
{
    hwndV454 := GameTargetHwndV63()
    if (!hwndV454)
        return false
    pointV454 := BOBuffPointV454(hwndV454)
    if (!IsObject(pointV454))
    {
        PortalLogWriteV66("BUFF_SELF_SKIP reason=PLAYER_SCREEN_POINT_UNAVAILABLE hwnd=" . hwndV454)
        return false
    }
    if (GameTargetHwndV63()!=hwndV454)
        return false
    PortalLogWriteV66("BUFF_SELF_CLICK client_xy=" . pointV454.x . "," . pointV454.y . " hwnd=" . hwndV454)
    return GameTargetClickV63("Right",pointV454.x,pointV454.y)
}

BackgroundHotkeyV63(key,label,options)
{
    if (label="Master456Handler" && !InStr(options,"Off"))
        return
    testKey := RegExReplace(key, "^[~*$<>!^+#]+")
    if (testKey = "" || testKey = "None" || testKey = "none" || testKey = "NONE" || testKey = "ERROR")
        return
    plainKey := RegExReplace(testKey, "^\^")
    if (!GetKeyVK(plainKey) && !GetKeySC(plainKey))
        return
    Hotkey, If, % Func("IsGameForegroundV63")
    Hotkey, %key%, %label%, %options%
    result := ErrorLevel
    Hotkey, If
    ErrorLevel := result
}

QCastTimer:
if (farmUserPausedV2026 && !castManualToggleV1801)
    return
if (buffSequenceRunningV555 || farmBuffExclusiveV621 || zRunning)
    return
FarmBuffTownSyncV509()
if (FarmTravelNoBuffV670() || CainCaveMoveActiveV502() || (autoMonsterAttackOn && !Stage2FightEnabledV9()))
    return
if (IsObject(sigTownV148))
    return
if (sigBusyV147)
    return
if (packetWatchArmedV1)
    return
if (master456Paused)
    return
if (xRunning)
    return
if (!QCastOn || (farmBuffModeV509!=1 && !castManualToggleV1801))
    return

if (!IsGameActive())
    return


Loop, 3
{
    if (!QCastOn || master456Paused || xRunning || zRunning || farmBuffExclusiveV621 || !IsGameActive())
        break
    qIndex := A_Index
    qKey := QCastKey%qIndex%
    qDelay := QCastDelay%qIndex%
    qLast := qCastLast%qIndex%

    if (!QuickBuffHasKey(qKey))
        continue

    if (qDelay < 0)
        qDelay := 0

    if (qLast = "" || qLast = 0 || A_TickCount - qLast >= qDelay)
    {
        if (QCastSendKey(qKey))
            qCastLast%qIndex% := A_TickCount
    }
}
return

FarmCastSyncV88(on)
{
    global QCastOn, master456Paused, master456Saved,farmBuffModeV509
    global qCastLast1, qCastLast2, qCastLast3, lastQCastDoubleKeyTime
    if (on && FarmTravelNoBuffV670())
        on := false
    if (on && master456Paused)
        master456Paused := false,master456Saved := false
    if (IsObject(master456Saved))
        master456Saved.cast := on ? true : false
    QCastOn := on && !master456Paused
    if (on)
        qCastLast1 := A_TickCount, qCastLast2 := A_TickCount, qCastLast3 := A_TickCount
    lastQCastDoubleKeyTime := 0
}

; Add only the manual CAST toggle/UI state to existing farm START and STOP.
; Do not replace any old start/stop action, pickup handoff, or pause behavior.
FarmCastToggleSetOnStartStopV2026(on,reason := "")
{
    global castManualToggleV1801,QCastOn
    castManualToggleV1801 := on ? true : false
    if (!on)
        QCastOn := false
    ; When START runs in town, existing FarmBuffTownSyncV509 still decides
    ; when the automatic CAST may actually fire after entering farm.
    GuiControl, 1:, CastToggleStatusV1801, % (castManualToggleV1801 ? "ON" : "OFF")
    PortalLogWriteV66("FARM_START_STOP_CAST reason=" . reason
        . " shortcut=" . (castManualToggleV1801 ? "ON" : "OFF") . " qcast=" . QCastOn)
}

FarmBuffStartV509()
{
    global farmBuffModeV509,QCastOn,master456Paused,master456Saved
    farmBuffModeV509 := 1,master456Paused := false,master456Saved := false
    QCastOn := false
    ResetAfterQuickBuff()
    FarmBuffTownSyncV509(true)
    PickupEnabledSetV71(true,true,false)
    FarmCastToggleSetOnStartStopV2026(true,"START")
    PortalLogWriteV66("BUFF_GROUPS_START cast4=TOWN_SYNC group5=BUFF_ONCE cycle6=MANUAL")
}

FarmBuffStopV509()
{
    global farmBuffModeV509,QCastOn,clickCastOn,cycleOn,master456Saved
    global sigBusyV147, sigCancelV147
    BuffSequenceSetV555(false)
    farmBuffModeV509 := 0,QCastOn := false,clickCastOn := false,cycleOn := false
    if (sigBusyV147) {
        sigCancelV147 := true
        sigBusyV147 := false
    }
    Cycle6GuiSyncV525()
    PickupCtrlEndV26()
    PickupEnabledSetV71(false,true,false)
    if (IsObject(master456Saved))
        master456Saved := {cast:false,click:false,cycle:false}
    FarmCastToggleSetOnStartStopV2026(false,"STOP")
    PortalLogWriteV66("BUFF_GROUPS_STOP cast4=OFF click5=OFF cycle6=OFF manual=AVAILABLE")
}

FarmBuffTownSyncV509(force := false)
{
    global farmBuffModeV509,QCastOn,master456Paused,qCastLast1,qCastLast2,qCastLast3,buffSequenceOnV555
    global farmControlOwnerV186
    static lastScosTravelV653 := false
    static lastRead := 0,lastPid := 0,lastLevel := 0
    if (farmBuffModeV509!=1 || (!force && A_TickCount-lastRead<400))
        return
    lastRead := A_TickCount
    pid := D2GetActiveGamePidV95()
    level := pid ? RoomRecordLevelV259(pid) : 0
    if (!level)
        return
    town := FarmReviveTownLevelV295(level)
    scosTravelV653 := FarmTravelNoBuffV670(pid,level)
    changed := force || pid!=lastPid || level!=lastLevel || town!=FarmReviveTownLevelV295(lastLevel)
        || scosTravelV653!=lastScosTravelV653
    lastPid := pid,lastLevel := level,lastScosTravelV653 := scosTravelV653
    if (!changed)
        return
    QCastOn := (buffSequenceOnV555 || (!town && !scosTravelV653)) && !master456Paused
    if (QCastOn)
        qCastLast1 := A_TickCount,qCastLast2 := A_TickCount,qCastLast3 := A_TickCount
    if (!town)
        FarmPickupSyncV57(0,0,-1,true)
    PortalLogWriteV66("CAST4_TOWN_TRANSITION level=" . level . " town=" . town
        . " cast4=" . QCastOn . " apply=ONCE manual=AVAILABLE")
}

FinalQuestItemV511(h,item)
{
    return IsObject(item) && (item.cls=1825 || item.cls=1839)
        && item.data && D2ReadU8V18(h,item.data)=7
}

QCastSendKey(key)
{
    global zRunning,farmBuffExclusiveV621
    global zKey, xKey, QCastOn, master456Paused, xRunning

    if (!QuickBuffHasKey(key))
        return false
    if (!QCastOn || master456Paused || xRunning || zRunning || farmBuffExclusiveV621 || !IsGameActive())
        return false
    key := Trim(key)
    if (key = "" || key = "None")
        return

    if (key = zKey)
    {
        Gosub, ZKeyHandler
        return true
    }

    if (key = xKey)
    {
        Gosub, XKeyHandler
        return true
    }

    if (!IsGameActive())
        return
    GameTargetKeyV63("{" . key . "}")
    Sleep, 200
    if (!IsGameActive() || !QCastOn || master456Paused || xRunning || zRunning || farmBuffExclusiveV621)
        return false
    GameTargetKeyV63("{" . key . " down}")
    try
    {
        Sleep, 200
    }
    finally
    {
        GameTargetKeyV63("{" . key . " up}")
    }
    return true
}

GetStepCount()
{
    global FKey1, FKey2, FKey3, FKey4
    global FKey5, FKey6, FKey7, FKey8
    global FKey9, FKey10

    Loop, 5
    {
        index := A_Index
        key := FKey%index%

        if (!QuickBuffHasKey(key))
            return index - 1
    }

    return 5
}

Cycle1Timer:
if (buffSequenceRunningV555 || farmBuffExclusiveV621)
    return
if (gameItemActionOwner!="" || IsObject(autoMonsterPacketPendingV1))
    return
if (FarmAttackHoldingV15())
    return
if (FarmTravelNoBuffV670() || CainCaveMoveActiveV502() || (autoMonsterAttackOn && !Stage2FightEnabledV9()))
    return
if (IsObject(sigTownV148))
    return
if (sigBusyV147)
    return
if (packetWatchArmedV1)
    return
if (master456Paused)
    return

if (!cycleOn)
    return

if (!cycle1On)
    return

if (zRunning)
    return

if (xRunning)
    return

if (!IsGameActive())
    return

if (nextStepTime != 0 && A_TickCount < nextStepTime)
    return

stepCount := GetStepCount()

if (stepCount <= 0)
    return

if (cycleStep > stepCount)
    cycleStep := 1

key := FKey%cycleStep%
delay := FDelay%cycleStep%

if (!QuickBuffHasKey(key))
{
    cycleStep := 1
    return
}

if (!IsGameActive())
    return
if (!GameTargetKeyV63("{" . key . "}"))
    return

nextStepTime := A_TickCount + delay

cycleStep++

if (cycleStep > stepCount)
    cycleStep := 1

return


ResetCastDelayWhenManualKey(key)
{
    global QCastKey1, QCastKey2, QCastKey3
    global qCastLast1, qCastLast2, qCastLast3, clickCastRows
    if (!IsGameForegroundV63())
        return
    key := Trim(key)
    if (key = "" || key = "None")
        return
    now := A_TickCount
    Loop, 3
    {
        i := A_Index
        castKey := QCastKey%i%
        if (CastKeysMatch(castKey, key))
            qCastLast%i% := now
    }
    for _, row in clickCastRows
        if (CastKeysMatch(row.key, key))
            row.last := now
}

ManualCastKeyDown(ih, vk, sc)
{
    global xRunning
    if (xRunning)
        return
    key := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    ResetCastDelayWhenManualKey(key)
}

CastKeysMatch(configKey, pressedKey)
{
    if (configKey = "" || configKey = "None")
        return false
    configSC := GetKeySC(configKey)
    pressedSC := GetKeySC(pressedKey)
    if (configSC && pressedSC)
        return configSC = pressedSC
    configVK := GetKeyVK(configKey)
    return configVK && configVK = GetKeyVK(pressedKey)
}

ZKeyHandler:
if (!IsGameForegroundV63())
    return
if (sigBusyV147)
    return
if (packetWatchArmedV1)
    return
if (A_ThisHotkey != "")
    ResetCastDelayWhenManualKey(zKey)


if (!IsGameActive())
    return

if (zRunning)
    return

if (xRunning)
    return

zRunning := true
zRunEpochV535 := farmRunEpochV535
DebugTraceWrite("character", "BUFF_START source=Z")

oldCycleOn := cycleOn
cycleOn := false

FarmSkillBaselineEnsureV621(D2GetActiveGamePidV95())
if (zSetKey != "" && zSetKey != "None")
{
    if (!IsGameActive())
        goto, ZKeyCleanup
    BuffCheckedSendV29(zSetKey)
    Sleep, %zSetDelay%
    if (!IsGameActive())
        goto, ZKeyCleanup
}

if (zFKey != "" && zFKey != "None")
{
    if (!IsGameActive())
        goto, ZKeyCleanup
    BuffCheckedSendV29(zFKey)
    Sleep, 30
    if (!IsGameActive())
        goto, ZKeyCleanup
    if (!IsGameActive())
        goto, ZKeyCleanup
    if (!GameTargetBuffSelfClickV454())
        goto, ZKeyCleanup
    Sleep, %zDelay1%
    if (!IsGameActive())
        goto, ZKeyCleanup
}

if (zFKey2 != "" && zFKey2 != "None")
{
    if (!IsGameActive())
        goto, ZKeyCleanup
    BuffCheckedSendV29(zFKey2)
    Sleep, 30
    if (!IsGameActive())
        goto, ZKeyCleanup
    if (!IsGameActive())
        goto, ZKeyCleanup
    if (!GameTargetBuffSelfClickV454())
        goto, ZKeyCleanup
    Sleep, %zDelay2%
    if (!IsGameActive())
        goto, ZKeyCleanup
}

if (zSetKey != "" && zSetKey != "None")
{
    if (!IsGameActive())
        goto, ZKeyCleanup
    BuffSetReturnV500(zSetKey,zSetDelay)
    BuffSetFixRightV500(zFKey2,zFKey)
}

ZKeyCleanup:
cycleStep := 1
nextStepTime := 0
if (zRunEpochV535=farmRunEpochV535)
    cycleOn := oldCycleOn
zRunning := false
return

XKeyHandler:
if (!IsGameForegroundV63())
    return
if (sigBusyV147)
    return
if (packetWatchArmedV1)
    return
if (!IsGameActive() || xRunning || zRunning)
    return
if (A_ThisHotkey != "")
    ResetCastDelayWhenManualKey(XKey)
xRunning := true
DebugTraceWrite("character", "BUFF_START source=X")
try
    QuickBuffRun()
finally
{
    ResetAfterQuickBuff()
    xRunning := false
    FarmSetVerifyTrigger()
}
return

DoubleKeyHandler:
if (!IsGameForegroundV63())
    return
if (master456Paused)
    return
if (xRunning)
    return

if (doubleKeyHeld)
    return
doubleKeyHeld := true
SetTimer, DoubleKeyReleaseWatch, 10

if (!IsGameActive())
    return

currentTime := A_TickCount

if (lastDoubleKeyTime != 0)
{
    elapsed := currentTime - lastDoubleKeyTime

    if (elapsed <= doubleTapMs)
    {
        cycleOn := !cycleOn
        Cycle6GuiSyncV525()

        cycleStep := 1
        nextStepTime := 0

        if (cycleOn)
            ToolTipInfoV386("Auto Bấm Dãy F: ON")
        else
            ToolTipInfoV386("Auto Bấm Dãy F: OFF")

        SetTimer, RemoveToolTip, -3000
        lastDoubleKeyTime := 0
        return
    }
}

lastDoubleKeyTime := currentTime

return

QCastDoubleKeyHandler:
return

FormDoubleKeyHandler:
if (!IsGameForegroundV63())
    return
if (xRunning)
    return

if (formDoubleKeyHeld)
    return
formDoubleKeyHeld := true
SetTimer, FormDoubleKeyReleaseWatch, 10

currentTime := A_TickCount

if (lastFormDoubleKeyTime != 0)
{
    elapsed := currentTime - lastFormDoubleKeyTime

    if (elapsed <= formDoubleTapMs)
    {
        if (configGuiVisible)
        {
            Gosub, SaveFormPosition
            Gui, Hide
            configGuiVisible := false
        }
        else
        {
            Gosub, ShowConfig
        }

        lastFormDoubleKeyTime := 0
        return
    }
}

lastFormDoubleKeyTime := currentTime

return

FarmInfoTranslateV4(message)
{
    if (RegExMatch(message,"i)(?:ghi log|xuất log|ghi tình trạng|\[INFO\]|đã xuất map)"))
        return ""
    if (RegExMatch(message,"i)[:：]\s*(?:ON|OFF|BẬT|TẮT)(?:\s*[—-]\s*ĐÃ HỦY DI CHUYỂN)?\s*$") )
        return ""
    if (RegExMatch(message,"i)(?:NO_SELECTED_ROUTE|NO_ROUTE_FILE|MAP_LOAD_WAIT|CAIN_LOAD_WAIT)"))
        return "Đang chờ file lộ trình khớp map hiện tại."
    if (RegExMatch(message,"i)(?:READ_FAILED|PLAYER_NOT_READABLE|LIVE_MAP_READ_FAILED)"))
        return "Chưa đọc được dữ liệu game; đang chờ lượt đọc tiếp theo."
    if (RegExMatch(message,"i)NO_LIVE_TARGET"))
        return "Chưa thấy quái sống hợp lệ để đánh trong lượt quét."
    if (RegExMatch(message,"i)(?:STUCK.*TELE|DELAY_TELEPORT|TELEPORT.*DISPATCH)"))
        return "Đang thử teleport để thoát chỗ kẹt."
    if (RegExMatch(message,"i)(?:ROUTE_MOVE|MAP_MOVE_DISPATCH)"))
        return "Đã gửi lệnh đi tới điểm tiếp theo; đang chờ vị trí thay đổi."
    if (RegExMatch(message,"i)MAP_MOVE_WAIT"))
        return "Nhân vật đang thực hiện thao tác khác; lệnh đi đang chờ."
    if (RegExMatch(message,"i)ROUTE_NO_PROGRESS"))
        return "Đã gửi lệnh đi nhưng nhân vật chưa tiến tới điểm đích."
    if (RegExMatch(message,"i)(?:ROUTE_WAIT|MAP_LOAD_WAIT|CAIN_LOAD_WAIT)"))
        return "Đang chờ dữ liệu lộ trình phù hợp với map hiện tại."
    if (RegExMatch(message,"i)(?:CAIN_EXIT|WAIT_MAP_CHANGE)"))
        return "Đã gửi lệnh vào cổng; đang chờ xác nhận chuyển map."
    if (RegExMatch(message,"i)MAP_STAGE2_DONE"))
        return "Đã đi hết lộ trình; đang chờ bước hoàn tất của map."
    if (RegExMatch(message,"i)(?:STAGE2_ROUTE_NEW|RUN_RESET_FROM_YELLOW|FARM_START_FROM_YELLOW)"))
        return "Đã nạp lộ trình mới từ dòng vàng."
    if (RegExMatch(message,"i)CAIN_ROOM_NEXT"))
        return "Đã chọn phòng tiếp giáp; đang tìm đường sang phòng đó."
    if (RegExMatch(message,"i)CAIN_WALL_BLOCKED"))
        return "Đường đang bị chặn; đang lần vách trái tìm lối đi."
    if (RegExMatch(message,"i)SCOS_241_STANDARD_BEGIN"))
        return "Scos map 241: đang đi lộ trình chuẩn, không đánh và không nhặt."
    if (RegExMatch(message,"i)SCOS_241_STANDARD_END"))
        return "Đã rời map 241; tiếp tục quy trình farm Scos."
    if (RegExMatch(message,"[À-ỹĐđ]") && !RegExMatch(message,"[A-Za-z_][A-Za-z_0-9]*=|V\d{2,}|_[A-Z]{2,}"))
        return message
    return ""
}

FarmInfoEventV4(message)
{
    global manualLogOnV81,farmInfoEventV4
    if (!manualLogOnV81)
        return
    readable := FarmInfoTranslateV4(message)
    if (readable!="")
        farmInfoEventV4 := {text:readable,at:A_TickCount}
}

FarmInfoLogStartV4()
{
    global fonInfoOnV385,fonInfoLogV385,farmInfoSessionV4,farmInfoPreviousV4
    global farmInfoEventV4,farmInfoLastV4,farmInfoLastAtV4,manualLogFilesV98
    global fonInfoAutoStuckV552
    fonInfoAutoStuckV552 := false
    farmInfoPreviousV4 := fonInfoOnV385,farmInfoSessionV4 := true
    farmInfoEventV4 := false,farmInfoLastV4 := "",farmInfoLastAtV4 := 0
    fonInfoLogV385 := []
    manualLogFilesV98["Auto-GSF-Tinh-Trang.txt"] := true
    FonInfoPushV385("Bắt đầu ghi tình trạng; Info chỉ quan sát hoạt động hiện tại.")
    ManualLogAppendV81(A_Now . " | Bắt đầu ghi tình trạng.`r`n",TxtRootPathV816("Auto-GSF-Tinh-Trang.txt"))
    SetTimer, FarmInfoLogTimerV589, 500
}

FarmInfoLogTimerV589:
if (farmInfoSessionV4)
    FarmInfoWriteStateV4(FarmInfoStateV4())
else
    SetTimer, FarmInfoLogTimerV589, Off
return

FarmInfoLogStopV4()
{
    global fonInfoOnV385,farmInfoSessionV4,farmInfoPreviousV4,farmInfoEventV4,FonInfoHwndV385
    if (!farmInfoSessionV4)
        return
    ManualLogAppendV81(A_Now . " | " . StrReplace(FarmInfoStateV4(),"`r`n"," ")
        . "`r`n" . A_Now . " | Đã dừng ghi tình trạng.`r`n",TxtRootPathV816("Auto-GSF-Tinh-Trang.txt"))
    SetTimer, FarmInfoLogTimerV589, Off
    farmInfoSessionV4 := false,farmInfoEventV4 := false
}

FarmInfoPhaseV4(phase)
{
    names := {"WP":"đi tới hoặc tìm WP","OPEN_WAIT":"chờ bảng WP mở"
        ,"SELECT_WAIT":"chờ chuyển map sau khi chọn WP","WALK":"di chuyển tới cửa map"
        ,"COMBAT":"đi qua map trung gian","FARM":"farm trong map","LOAD":"chờ nạp lộ trình"
        ,"CUBE":"xử lý vật phẩm trong cube để mở cổng","PORTAL":"tìm hoặc chờ vào cổng"
        ,"EXIT_PORTAL":"đi ra khỏi cổng vừa vào","WAIT_MAP":"chờ xác nhận chuyển map"
        ,"MAP":"chuẩn bị lộ trình trong map","ENTRY_BUFF":"buff trước khi di chuyển"
        ,"CAVE_MOVE":"lần vách và tìm đường sang phòng kế bên","EXIT":"tiếp cận cổng thoát"}
    return names.HasKey(phase) ? names[phase] : "chuẩn bị bước tiếp theo"
}

FarmInfoStateV4()
{
    global
    local text,prefix,row,point,phase,c,steps
    prefix := farmControlOwnerV186!="" ? farmControlOwnerV186 . ": " : ""
    if (sigTerminalErrorV762!="")
        return "SIG đã dừng: " . sigTerminalErrorV762
    if (backgroundBlockReasonV553!="")
        return backgroundBlockReasonV553
    if (!backgroundHwndV63 || !DllCall("IsWindow","Ptr",backgroundHwndV63))
        return "Chưa nhận được cửa sổ game để tiếp tục."
    if (sigBusyV147)
        return "Đang SIG " . (sigActiveModeV182="SET" ? "Set" : sigActiveModeV182="SU" ? "SU" : "vật phẩm") . "; chờ cube và thu hồi đồ xong."
    if (IsObject(ticketPickupWaitV279) && ticketPickupWaitV279.sigScopeV654)
        return prefix . "SIG đã xong; đang nhặt và chờ Done trước khi di chuyển."
    if (IsObject(scosEntryV162) && scosEntryV162.stage1SigBlockedV654
        && !scosEntryV162.stage1SigDoneV374 && !scosEntryV162.preSigDoneV310)
        return prefix . "SIG chưa hoàn tất: " . sigLastStopReasonV63
    if (IsObject(sigTownV148))
        return "Đang làm quy trình về thành, sắp đồ và SIG."
    if (IsObject(stageTwoV166))
    {
        if (stageTwoV166.loginRecoveryV489)
            return "Đang khôi phục đăng nhập game theo quy trình hiện có."
        steps := {"ESC":"mở menu thoát phòng","SAVE_EXIT":"lưu và thoát phòng cũ"
            ,"WAIT_LOBBY":"chờ màn hình tạo phòng","NAME_FIELD":"chọn ô tên phòng"
            ,"TYPE_NAME":"điền tên phòng mới","CREATE":"bấm tạo phòng","WAIT_GAME":"chờ vào phòng mới"
            ,"RECOVER":"kiểm tra lại màn hình game"}
        phase := stageTwoV166.phase
        return "Giai đoạn tạo phòng: " . (steps.HasKey(phase) ? steps[phase] : "chờ game xử lý bước hiện tại") . "."
    }
    if (xRunning || zRunning)
        return xRunning ? "Đang buff nhanh; farm chờ buff xong." : "Đang buff set phụ; chờ chuyển về set chính."
    if (IsObject(farmReviveV32) || reviveBuffPendingV34)
        return "Đang hồi sinh hoặc chuẩn bị buff để trở lại map."
    if (gameItemActionOwner!="")
        return gameItemActionOwner="Pickup" ? "Đang nhặt hoặc cất đồ; farm chờ thao tác này xong." : "Đang xử lý vật phẩm; farm đang chờ."
    if (petLearnOnV12)
        return "Đang lấy ID pet; farm chờ thao tác này xong."
    if (packetWatchArmedV1)
        return "Đang thu lệnh game để kiểm tra; farm chờ thao tác này xong."
    c := FarmInfoStuckStateV552()
    if (IsObject(c))
        return prefix . "Đang xử lý kẹt tại dòng " . (c.row+1) . "; thử đường đi hoặc teleport để thoát."
    if (currentAttackUidV520 && A_TickCount-currentAttackAtV520<1500)
        return prefix . "Vừa gửi lệnh đánh ID " . currentAttackClassV520 . ", UID " . currentAttackUidV520 . ", khoảng cách " . currentAttackDistV523 . "."
    if (IsObject(autoMonsterPacketPendingV1))
        return prefix . "Đang chờ game xử lý lệnh vừa gửi."
    if (monsterCombatUidV45)
        return prefix . "Đang giữ mục tiêu quái cá thể " . monsterCombatUidV45 . "; chưa chuyển sang đi tiếp."
    if (IsObject(scosEntryV162) && !IsObject(scosEntryV162.commonRouteV3))
    {
        phase := scosEntryV162.map="CAIN" && scosEntryV162.cainPhaseV383!="" ? scosEntryV162.cainPhaseV383 : scosEntryV162.phase
        text := prefix . "Đang " . FarmInfoPhaseV4(phase) . "."
    }
    else if (autoMonsterAttackOn || IsObject(coordGoV59))
    {
        row := IsObject(coordRouteV16) ? coordRouteV16.next : 0
        point := IsObject(coordGoV59) ? coordGoV59 : coordSavedV15[row]
        if (IsObject(coordRouteV16) && coordRouteV16.phase="DONE")
            text := prefix . "Đã hết lộ trình; đang chờ bước hoàn tất hoặc về thành."
        else if (IsObject(point))
            text := prefix . "Đi tới " . point.x . ", " . point.y . (row ? " (dòng " . row . ")" : "") . "."
        else
            text := prefix . "Chưa có điểm đến hợp lệ; đang chờ lộ trình."
        if (IsObject(scosEntryV162) && IsObject(scosEntryV162.commonRouteV3))
            text .= " Chế độ không đánh, không nhặt."
    }
    else
        text := prefix . (FarmControlRunningV186() ? "Đang chờ bước tiếp theo." : "Farm đã dừng.")
    c := coordCursorSnapshotV390
    if (IsObject(c) && A_TickCount-c.at<2000)
        text .= "`r`nVị trí vừa đọc: map " . c.level . ", tọa độ " . c.x . ", " . c.y . "."
    if (IsObject(farmInfoEventV4) && A_TickCount-farmInfoEventV4.at<4000)
        text .= "`r`n" . farmInfoEventV4.text
    return text
}

FarmInfoWriteStateV4(text)
{
    global manualLogOnV81,farmInfoLastV4,farmInfoLastAtV4
    if (!manualLogOnV81 || (text=farmInfoLastV4 && A_TickCount-farmInfoLastAtV4<3000))
        return
    farmInfoLastV4 := text,farmInfoLastAtV4 := A_TickCount
    ManualLogAppendV81(A_Now . " | " . StrReplace(text,"`r`n"," ") . "`r`n",TxtRootPathV816("Auto-GSF-Tinh-Trang.txt"))
}

FonInfoPushV385(text,displayRaw := false)
{
    global fonInfoOnV385, fonInfoLogV385
    if (!fonInfoOnV385)
        return
    if (!IsObject(fonInfoLogV385))
        fonInfoLogV385 := []
    if (!displayRaw && InStr(text,"Mục tiêu ID:")=1)
        return
    text := displayRaw ? RegExReplace(text,"[\r\n]+"," | ") : FarmInfoTranslateV4(text)
    if (text="")
        return
    FormatTime, tsV385,, HH:mm:ss
    fonInfoLogV385.Push(tsV385 . " " . text)
    while (fonInfoLogV385.Length()>8)
        fonInfoLogV385.RemoveAt(1)
}

ToolTipInfoV386(text, x := "", y := "", which := 1)
{
    global fonInfoOnV385,viewIdV54,viewPosV291,viewTipV640
    static lastOverlayText := {}
    if (text = "")
        return
        
    if (viewTipV640)
    {
        if (x = "" || y = "")
            ToolTip, %text%
        else
            ToolTip, %text%, %x%, %y%
        SetTimer, RemoveToolTip, -2500
        
        if (fonInfoOnV385)
            FonInfoPushV385(text,true)
        return
    }
    
    if (!fonInfoOnV385)
    {
        lastOverlayText := {}
        return
    }
    if ((which=2 && !viewIdV54) || (which=20 && !viewIdV54 && !viewPosV291))
        return
    if (which!=1 && lastOverlayText.HasKey(which) && lastOverlayText[which]=text)
        return
    lastOverlayText[which] := text
    FonInfoPushV385(text,true)
}

FonInfoTimerV385:
FonInfoRenderV385()
return

FarmElapsedStartV1350()
{
    global farmElapsedStartedAtV1350,farmElapsedSavedSecV1350
    if (farmElapsedStartedAtV1350!="")
        return
    farmElapsedStartedAtV1350 := A_Now
    farmElapsedSavedSecV1350 := 0
}

FarmElapsedStopV1350()
{
    global farmElapsedStartedAtV1350,farmElapsedSavedSecV1350
    if (farmElapsedStartedAtV1350="")
        return
    secondsV1350 := A_Now
    EnvSub, secondsV1350, %farmElapsedStartedAtV1350%, Seconds
    farmElapsedSavedSecV1350 := Max(0,secondsV1350)
    farmElapsedStartedAtV1350 := ""
}

FarmElapsedTextV1350()
{
    global farmElapsedStartedAtV1350,farmElapsedSavedSecV1350
    secondsV1350 := farmElapsedSavedSecV1350
    if (farmElapsedStartedAtV1350!="")
    {
        secondsV1350 := A_Now
        EnvSub, secondsV1350, %farmElapsedStartedAtV1350%, Seconds
    }
    secondsV1350 := Max(0,Floor(secondsV1350))
    hoursV1350 := Floor(secondsV1350/3600)
    minutesV1350 := Mod(Floor(secondsV1350/60),60)
    secondsRemainderV1350 := Mod(secondsV1350,60)
    return "H: " . hoursV1350 . " giờ " . Format("{:02d}",minutesV1350)
        . " phút " . Format("{:02d}",secondsRemainderV1350)
}

FonInfoRenderV385()
{
    global fonInfoOnV385,FonInfoHwndV385,fonInfoLogV385,farmControlOwnerV186,mapWorkflowV185
    global coordCursorSnapshotV390,coordYellowRowV350,coordSavedV15,stageTwoV166
    global sigBusyV147,sigActiveModeV182,pickupImageOn,QCastOn,cycleOn,xRunning,zRunning
    global currentAttackUidV520,currentAttackClassV520,currentAttackAtV520,currentAttackDistV523
    global currentAttackPidV550,backgroundPidV63,FonInfoBodyV385,autoMonsterAttackOn,FonInfoStatusV622,cainNoFightV361,FonInfoGD4TimerV659
    global backgroundBlockReasonV553, farmScanListV682, farmScanSelectedV682
    global farmGroundItemCountV710, farmItemLockV625,farmStuckSkipInfoV1234,castManualToggleV1801

    if (!fonInfoOnV385)
    {
        SetTimer, FonInfoTimerV385, Off
        return
    }
	    if (!fonInfoOnV385)
    {
        SetTimer, FonInfoTimerV385, Off
        return
    }

    gamePidV385 := backgroundPidV63 ? backgroundPidV63 : D2GetActiveGamePidV95()
    if (!gamePidV385)
    {
        if (DllCall("IsWindow","Ptr",FonInfoHwndV385))
            Gui, FonInfoV385:Hide
        return
    }

    state := FarmInfoStateV4()
    FarmInfoWriteStateV4(state)
    hwnd := GameTargetHwndV63()
    state := FarmInfoStateV4()
    FarmInfoWriteStateV4(state)
    hwnd := GameTargetHwndV63()
    if (!hwnd)
    {
        if (DllCall("IsWindow","Ptr",FonInfoHwndV385))
            Gui, FonInfoV385:Hide
        return
    }
    VarSetCapacity(rect,16,0),VarSetCapacity(origin,8,0)
    if (!DllCall("GetClientRect","Ptr",hwnd,"Ptr",&rect)
        || !DllCall("ClientToScreen","Ptr",hwnd,"Ptr",&origin))
        return
    gameW := NumGet(rect,8,"Int"),gameH := NumGet(rect,12,"Int")
    width := Max(170,Floor(gameW/8)),contentW := width-16,formH := 86
    left := NumGet(origin,0,"Int") + gameW - width - 5
    top := NumGet(origin,4,"Int") + 5
    if (!FonInfoHwndV385 || !DllCall("IsWindow","Ptr",FonInfoHwndV385))
    {
        Gui, FonInfoV385:Destroy
        Gui, FonInfoV385:New, +AlwaysOnTop -Caption +ToolWindow +E0x20 +HwndFonInfoHwndV385
        Gui, FonInfoV385:Color, 0F0F0F
        Gui, FonInfoV385:Font, s9 c00FF00, Consolas
        Gui, FonInfoV385:Font, s8 c00FF00, Arial
        Gui, FonInfoV385:Add, Text, x8 y5 w%contentW% h16 +0xC vFonInfoGD4TimerV659 BackgroundTrans
        Gui, FonInfoV385:Add, Text, x8 y23 w%contentW% h16 +0xC vFonInfoStatusV622 BackgroundTrans
        Gui, FonInfoV385:Font, s9 c00FF00, Consolas
        Gui, FonInfoV385:Add, Text, x8 y41 w%contentW% h56 vFonInfoBodyV385 BackgroundTrans
        WinSet, Transparent, 205, % "ahk_id " . FonInfoHwndV385
    }
        vitalsInfo := D2ReadHealVitalsV3()
    hpText := vitalsInfo.hp >= 0 ? vitalsInfo.hp : "Lỗi"
    pidText := vitalsInfo.pid ? vitalsInfo.pid : "N/A"
    
    gd4TimerTextV659 := FarmWatchTimerTextV659() . " | CAST: " . (castManualToggleV1801 ? "ON" : "OFF") . " | PID: " . pidText
    GuiControl, FonInfoV385:, FonInfoGD4TimerV659, %gd4TimerTextV659%
    
    vitalsDebug := D2ReadHealVitalsV3()
    hpText := vitalsDebug.hp >= 0 ? vitalsDebug.hp : "Lỗi"
    lvlDebug := RoomRecordLevelV259(backgroundPidV63)
    
    statusV615 := "HP: " . hpText . " | Map: " . lvlDebug
    GuiControl, FonInfoV385:, FonInfoStatusV622, %statusV615%

    scanTextV682 := ""
    if (IsObject(farmScanListV682) && farmScanListV682.Length() > 0)
    {
        selectedCV682 := false, othersV682 := []
        for _, cV682 in farmScanListV682
        {
            if (cV682.uid = farmScanSelectedV682)
                selectedCV682 := cV682
            else
                othersV682.Push(cV682)
        }
        orderedV682 := []
        if (IsObject(selectedCV682))
            orderedV682.Push(selectedCV682)
        for _, cV682 in othersV682
            orderedV682.Push(cV682)

        maxLinesV682 := 12, shownV682 := 0
        for _, cV682 in orderedV682
        {
            if (shownV682 >= maxLinesV682)
                break
            shownV682++
            markV682 := (cV682.uid = farmScanSelectedV682) ? "> " : "  "
            scanTextV682 .= "`r`n" . markV682 . cV682.cls . " | " . Round(Sqrt(cV682.dist), 1)
            if (cV682.priority)
                scanTextV682 .= " [BOSS]"
        }
        if (orderedV682.Length() > maxLinesV682)
            scanTextV682 .= "`r`n  ... +" . (orderedV682.Length() - maxLinesV682) . " nữa"
    }

    bgTextV682 := BackgroundActivityViewV693(hwnd)
        statusLineV682 := "FARM " . (autoMonsterAttackOn ? "ON" : "OFF")
        . " | BG " . bgTextV682 . "`r`n------------------"

    itemInfoV710 := "`r`nItem quét: " . (farmGroundItemCountV710+0)
    lockRadiusV710 := 0
    if (IsObject(farmItemLockV625))
        lockRadiusV710 := Round(Sqrt(farmItemLockV625.pickupRadiusSqV648))
    itemInfoV710 .= "`r`nKhóa BK nhặt: " . lockRadiusV710

    body := statusLineV682 . itemInfoV710
    body .= "`r`n--------------------`r`n" . ViewActivityStateV606()
    
    ; One compact line above DS QUET. New stuck target overwrites previous.
    body .= "`r`n----------------------"
    if (IsObject(farmStuckSkipInfoV1234))
    {
        lastClsV1234 := farmStuckSkipInfoV1234.cls >= 0 ? farmStuckSkipInfoV1234.cls : "?"
        lastDistV1234 := farmStuckSkipInfoV1234.dist >= 0 ? Round(farmStuckSkipInfoV1234.dist,1) : "?"
        body .= "`r`nID kẹt: " . lastClsV1234 . " | " . lastDistV1234
    }
    else
        body .= "`r`nID kẹt: -- | --"
    body .= "`r`n----------------------`r`n-- DS QUÉT (" . farmScanListV682.Length() . ") --"
    maxLinesV682 := 3
    linesAddedV682 := 0
    if (scanTextV682 != "")
    {
        body .= scanTextV682
        linesAddedV682 := StrLen(scanTextV682) ? StrSplit(scanTextV682, "`r`n").Length() - 1 : 0
    }
    Loop, % (maxLinesV682 - linesAddedV682)
        body .= "`r`n "
    body .= "`r`n----------------------`r`n" . FarmElapsedTextV1350()

    GuiControlGet, bodyHwndV605, FonInfoV385:Hwnd, FonInfoBodyV385
    dpiScaleV605 := A_ScreenDPI/96
    VarSetCapacity(textRectV605,16,0)
    NumPut(Round(contentW*dpiScaleV605),textRectV605,8,"Int")
    textDcV605 := DllCall("GetDC","Ptr",bodyHwndV605,"Ptr")
    if (textDcV605)
    {
        textFontV605 := DllCall("SendMessage","Ptr",bodyHwndV605,"UInt",0x31,"Ptr",0,"Ptr",0,"Ptr")
        oldFontV605 := textFontV605 ? DllCall("SelectObject","Ptr",textDcV605,"Ptr",textFontV605,"Ptr") : 0
        measuredV605 := DllCall("DrawTextW","Ptr",textDcV605,"WStr",body,"Int",-1,"Ptr",&textRectV605,"UInt",0xC10)
        if (oldFontV605)
            DllCall("SelectObject","Ptr",textDcV605,"Ptr",oldFontV605)
        DllCall("ReleaseDC","Ptr",bodyHwndV605,"Ptr",textDcV605)
        if (measuredV605>0)
            bodyHV605 := Ceil((NumGet(textRectV605,12,"Int")-NumGet(textRectV605,4,"Int"))/dpiScaleV605)+2
    }
    if (!bodyHV605)
        bodyHV605 := 90
    formH := bodyHV605+47
    GuiControl, FonInfoV385:Move, FonInfoBodyV385, w%contentW% h%bodyHV605%
    GuiControl, FonInfoV385:, FonInfoBodyV385, %body%
    Gui, FonInfoV385:Show, x%left% y%top% w%width% h%formH% NoActivate, Info
}

FarmWatchTimerTextV659()
{
    global farmWatchV5
    w := farmWatchV5
    if (!IsObject(w))
        return "Đứng: đang khởi tạo"
    if (!w.enabled)
        return "Đứng: tắt"
    ; The Info clock reports character inactivity, not SIG recovery locks.
    ; Live SIG work is character activity; stale pending SIG flags are not.
    ; Activity can override a stale wait even if its SIG flag is still set.
    elapsed := w.sigPausedV753 && !w.sigWaitBypassedV1080 ? 0
        : Floor(Max(0,FarmWatchNowV688()-w.idleAtV650)/1000)
    return "Đứng: " . elapsed . "/" . Round(w.period/1000) . "s"
}

ViewActivityStateV606()
{
    global farmCombatViewV624,backgroundPidV63,farmCenterCycleV741,farmRunEpochV535,farmScanListV682
    global backgroundBlockReasonV553,sigBusyV147,sigTownV148,stageTwoV166
    global ticketPickupWaitV279,sigLastStopReasonV63,sigTerminalErrorV762
    global xRunning,zRunning,farmReviveV32,reviveBuffPendingV34,gameItemActionOwner
    global petLearnOnV12,packetWatchArmedV1,autoMonsterAttackOn,coordGoV59,coordRouteV16
    global scosEntryV162,currentAttackUidV520,currentAttackAtV520,monsterCombatUidV45,currentAttackClassV520,currentAttackDistV523
    global monsterChaseV44,chaseCheckSecV9,teleportIntervalSecV56,farmItemLockV625
    global monsterLockNoDamageSecV621,monsterLockRoomSecV622
    activity := "đã dừng",stuck := "không"
    running := autoMonsterAttackOn || (IsObject(coordGoV59) && !coordGoV59.stop) || FarmControlRunningV186()
    r := IsObject(coordGoV59) && !coordGoV59.stop && IsObject(coordGoV59.routeV392)
        ? coordGoV59.routeV392 : coordRouteV16
    ; ITEM_MOVE su dung route rieng. Doc dung route nay de hien dong ho xet ket.
    itemGoalInfoV1801 := IsObject(farmItemLockV625) && IsObject(farmCenterCycleV741)
        && farmCenterCycleV741.pid=backgroundPidV63
        && farmCenterCycleV741.phase="ITEM_MOVE"
        && IsObject(farmItemLockV625.returnGoalV655)
        ? farmItemLockV625.returnGoalV655 : false
    if (IsObject(itemGoalInfoV1801) && IsObject(itemGoalInfoV1801.routeV392))
        r := itemGoalInfoV1801.routeV392
    e := IsObject(itemGoalInfoV1801) && IsObject(r.escapeV84)
        ? r.escapeV84 : FarmInfoStuckStateV552()
    if (IsObject(e))
    {
        stage := e.stageV589
        names := {"BACK":"đang lùi","LEFT":"đang né trái","RIGHT":"đang né phải","TELE":"đang teleport","RETURN":"về tọa độ trước"}
        stuck := names.HasKey(stage) ? names[stage] : "đang tìm lối thoát"
        if (stage="TELE" && !e.sentV589 && r.lastTeleport)
        {
            remaining := Max(0,Max(3,teleportIntervalSecV56)-(A_TickCount-r.lastTeleport)/1000)
            if (remaining>0)
                stuck := "chờ teleport " . Round(remaining,1) . "s"
        }
        if (e.stepAt)
            stuck .= " (" . Round(Max(0,A_TickCount-e.stepAt)/1000,1) . "s)"
    }
    else if (running && IsObject(r.obstacleV465))
    {
        e := r.obstacleV465
        names := {"BACK":"đang lùi","LEFT":"đang né trái","RIGHT":"đang né phải"}
        stuck := names.HasKey(e.stage) ? names[e.stage] : "đang tìm lối thoát"
        if (e.since)
            stuck .= " (" . Round(Max(0,A_TickCount-e.since)/1000,1) . "s)"
    }
    else if (running && !monsterCombatUidV45 && IsObject(r.stuckProbe) && r.stuckProbe.since && r.phase="NEXT")
        stuck := "di chuyển " . Round(Max(0,A_TickCount-r.stuckProbe.since)/1000,1) . "/" . Max(1,chaseCheckSecV9) . "s"
    if (running && IsObject(farmCenterCycleV741)
        && farmCenterCycleV741.pid=backgroundPidV63
        && farmCenterCycleV741.phase="ITEM_MOVE" && stuck="không")
        stuck := IsObject(itemGoalInfoV1801) ? "nhặt: đang đợi xét kẹt" : "nhặt: chưa khởi tạo xét kẹt"
    if (sigTerminalErrorV762!="")
        activity := "SIG đã dừng: " . sigTerminalErrorV762
    else if (backgroundBlockReasonV553!="")
        activity := "chờ: " . backgroundBlockReasonV553
    else if (sigBusyV147)
        activity := "SIG"
    else if (IsObject(ticketPickupWaitV279) && ticketPickupWaitV279.sigScopeV654)
        activity := "SIG: nhặt đồ, chờ Done"
    else if (IsObject(scosEntryV162) && scosEntryV162.stage1SigBlockedV654
        && !scosEntryV162.stage1SigDoneV374 && !scosEntryV162.preSigDoneV310)
        activity := "chờ SIG: " . sigLastStopReasonV63
    else if (IsObject(sigTownV148))
        activity := "về thành / sắp đồ / SIG"
    else if (IsObject(stageTwoV166))
        activity := "chờ thoát / tạo phòng"
    else if (xRunning || zRunning)
        activity := "buff"
    else if (IsObject(farmReviveV32) || reviveBuffPendingV34)
        activity := "hồi sinh / buff"
    else if (gameItemActionOwner!="")
        activity := gameItemActionOwner="Pickup" ? "Nhặt vật phẩm"
    else if (petLearnOnV12 || packetWatchArmedV1)
        activity := "chờ lấy dữ liệu game"
    else if (IsObject(e))
        activity := "xử lý kẹt"
    else if (IsObject(farmCenterCycleV741) && farmCenterCycleV741.pid=backgroundPidV63 && farmCenterCycleV741.epoch=farmRunEpochV535)
    {
        phaseV768 := farmCenterCycleV741.phase
        itemMoveStatusV914 := IsObject(itemGoalInfoV1801) && IsObject(r.escapeV84)
            ? "Đang thoát kẹt để quay lại nhặt vật phẩm"
            : "Đi tới vật phẩm; không tiến thì xét kẹt và thoát kẹt"
        activity := phaseV768="ATTACK_FIRST" ? "Quét+đánh quái quanh dòng " . farmCenterCycleV741.row
            : phaseV768="ATTACK_MORE" ? "Quét+đánh quái quanh dòng " . farmCenterCycleV741.row
            : phaseV768="ITEM_MOVE" ? itemMoveStatusV914
            : phaseV768="ITEM_ATTACK" ? "Đánh quái BK/2 quanh vật phẩm"
            : phaseV768="ATTACK" ? "Đang đánh quái"
            : phaseV768="PICKUP" ? "Kích nhặt (nếu có đồ)"
            : phaseV768="PICKUP_BUSY" ? "Đang nhặt vật phẩm"
            : phaseV768="CHECK" ? "Kiểm tra vị trí dòng " . farmCenterCycleV741.row
            : phaseV768="RETURN" ? "Đi/tele về dòng " . (IsObject(farmCenterCycleV741.forwardV756) ? farmCenterCycleV741.forwardV756.row : farmCenterCycleV741.row + 1)
            : phaseV768="MOVE" ? "Chuẩn bị đi tới dòng " . (IsObject(farmCenterCycleV741.forwardV756) ? farmCenterCycleV741.forwardV756.row : farmCenterCycleV741.row + 1)
            : "Quy trình " . farmCenterCycleV741.row . " → " . (IsObject(farmCenterCycleV741.forwardV756) ? farmCenterCycleV741.forwardV756.row : farmCenterCycleV741.row + 1) . ": " . phaseV768
    }
    else if (currentAttackUidV520 && A_TickCount-currentAttackAtV520<1500)
        activity := "đánh"
    else if (monsterCombatUidV45 && running)
        activity := "bám mục tiêu đánh"
    else if (IsObject(scosEntryV162) && !IsObject(scosEntryV162.commonRouteV3))
    {
        phase := scosEntryV162.map="CAIN" && scosEntryV162.cainPhaseV383!=""
            ? scosEntryV162.cainPhaseV383 : scosEntryV162.phase
        activity := FarmInfoPhaseV4(phase)
    }
    else if (running)
        activity := IsObject(r) && r.phase="NEXT" ? "di chuyển" : "chờ bước tiếp theo"
    cV624 := farmCombatViewV624
    if (running && IsObject(cV624) && cV624.pid=backgroundPidV63 && A_TickCount-cV624.at<1500
        && !xRunning && !zRunning && gameItemActionOwner="" && !sigBusyV147
        && !IsObject(stageTwoV166) && !IsObject(sigTownV148) && !IsObject(e) && !IsObject(farmCenterCycleV741))
    {
        if (cV624.uid)
            activity := cV624.text
        else if (activity="di chuyển")
            activity := IsObject(farmScanListV682) && farmScanListV682.Length() ? "có quái quanh nhân vật; chờ lượt đánh" : "di chuyển; chưa thấy quái quanh nhân vật"
    }
    ; Info only: show the ACTUALLY SENT attack, not just a scanned candidate.
    ; The fresh combat scan must belong to this PID and the same UID.
    if (running && IsObject(farmCenterCycleV741) && farmCenterCycleV741.pid=backgroundPidV63
        && (farmCenterCycleV741.phase="ATTACK" || farmCenterCycleV741.phase="ATTACK_FIRST"
            || farmCenterCycleV741.phase="ATTACK_MORE" || farmCenterCycleV741.phase="ROAD_ATTACK"
            || farmCenterCycleV741.phase="ITEM_ATTACK")
        && currentAttackUidV520 && currentAttackAtV520
        && A_TickCount-currentAttackAtV520<1500
        && IsObject(cV624) && cV624.pid=backgroundPidV63
        && cV624.uid=currentAttackUidV520 && A_TickCount-cV624.at<1500)
    {
        activity := "Đang đánh ID " . currentAttackClassV520 . " | " . Round(currentAttackDistV523,1)
        if (IsObject(farmScanListV682))
        {
            for _, infoMobV1240 in farmScanListV682
            {
                if (infoMobV1240.uid=currentAttackUidV520)
                {
                    if (infoMobV1240.priority)
                        activity .= " [BOSS]"
                    break
                }
            }
        }
    }
    if (IsObject(r.retryV611) && r.retryV611.hold)
    {
        stuck := "Cần thay tọa độ mới"
        if (activity="di chuyển" || activity="xử lý kẹt" || activity="chờ bước tiếp theo")
            activity := "đứng chờ; quái tới thì đánh"
    }
    activity := RegExReplace(activity, "[\r\n]+", " ")
    
    if (StrLen(activity) <= 10)
        activity .= "`r`n "

    ; Hien dong ho ket DI CHUYEN va QUAI tai cung dong "Ket"; khong them dong rieng.
    combatTimerV1210 := FarmCombatStuckInfoV1210(running)
    if (combatTimerV1210!="")
        stuck := stuck="không" ? combatTimerV1210 : stuck . " | " . combatTimerV1210
    return "Kẹt: " . stuck . "`r`nĐang làm: " . activity
}

; V1210: Info cu van hien ID/Dist/[BOSS], chi them dong xet ket quai.
; Doc ca dong ho theo muc tieu va watchdog (khong can packet da gui).
FarmCombatStuckInfoV1210(running)
{
    global farmCenterCycleV741,backgroundPidV63,monsterChaseV44,farmWatchV5
    global chaseCheckSecV9
    if (!running)
        return ""
    cycle := farmCenterCycleV741
    ; Chi hien dong ho QUAI khi bot dang danh, khong hien khoi khoi luc MOVE/CHECK.
    if (IsObject(cycle) && cycle.pid=backgroundPidV63
        && cycle.phase!="ATTACK" && cycle.phase!="ATTACK_FIRST"
        && cycle.phase!="ATTACK_MORE" && cycle.phase!="ROAD_ATTACK"
        && cycle.phase!="ITEM_ATTACK")
        return ""
    now := A_TickCount,uid := 0,since := 0
    c := monsterChaseV44
    if (IsObject(c) && c.uid && c.pid=backgroundPidV63
        && c.seenAtV591 && now-c.seenAtV591<2000 && c.since)
        uid := c.uid,since := c.since
    w := farmWatchV5
    if (IsObject(w) && w.pid=backgroundPidV63 && IsObject(w.combatStallProbeV903))
    {
        p := w.combatStallProbeV903
        if (p.uid && p.pid=backgroundPidV63 && p.since && (!uid || uid=p.uid))
            uid := p.uid,since := p.since
    }
    if (uid && since)
        return "quái " . Round(Max(0,now-since)/1000,1) . "/" . Max(1,chaseCheckSecV9) . "s"
    return ""
}


FarmInfoStuckStateV552()
{
    global autoMonsterAttackOn,coordRouteV16,coordGoV59
    if (autoMonsterAttackOn && IsObject(coordRouteV16) && IsObject(coordRouteV16.escapeV84))
        return coordRouteV16.escapeV84
    if (IsObject(coordGoV59) && !coordGoV59.stop && IsObject(coordGoV59.routeV392)
        && IsObject(coordGoV59.routeV392.escapeV84))
        return coordGoV59.routeV392.escapeV84
    return false
}

InfoStuckWatchV552()
{
    return
}

AttackInfoRememberV550(pid,cls,uid,x,y,px,py)
{
    global currentAttackUidV520,currentAttackClassV520,currentAttackX_V520,currentAttackY_V520
    global currentAttackAtV520,currentAttackDistV523,currentAttackPidV550
    currentAttackPidV550 := pid,currentAttackUidV520 := uid,currentAttackClassV520 := cls
    currentAttackX_V520 := x,currentAttackY_V520 := y,currentAttackAtV520 := A_TickCount
    currentAttackDistV523 := Round(Sqrt((x-px)**2+(y-py)**2),1)
}


FonInfoCloseV385()
{
    global fonInfoOnV385,fonInfoAutoStuckV552,fonInfoStuckDismissedV552,backgroundBlockReasonV553
	FarmStuckInfoDisableV10(true)
    fonInfoAutoStuckV552 := false
    fonInfoStuckDismissedV552 := IsObject(FarmInfoStuckStateV552()) || backgroundBlockReasonV553!=""
    fonInfoOnV385 := false
    SetTimer, FonInfoTimerV385, Off
    Gui, FonInfoV385:Destroy
    global viewIdV54
    viewIdV54 := false
    if (ProfileControlExistsV365("ViewIdInputV54"))
        GuiControl, 1:, ViewIdInputV54, 0

}
farmStuckInfoAutoV10 := false

FarmStuckInfoEnableV10()
{
    return
}

FarmStuckInfoDisableV10(force := false)
{
    return
}
DoubleKeyReleaseWatch:
if (!GetKeyState(doubleKey, "P"))
{
    doubleKeyHeld := false
    SetTimer, DoubleKeyReleaseWatch, Off
}
return

QCastDoubleKeyReleaseWatch:
if (!GetKeyState(qCastDoubleKey, "P"))
{
    qCastDoubleKeyHeld := false
    SetTimer, QCastDoubleKeyReleaseWatch, Off
}
return

FormDoubleKeyReleaseWatch:
if (!GetKeyState(formDoubleKey, "P"))
{
    formDoubleKeyHeld := false
    SetTimer, FormDoubleKeyReleaseWatch, Off
}
return

RemoveToolTip:
ToolTip
return


NormalizeOptionalKey(key)
{
    key := Trim(key)
    if (key = "" || RegExMatch(key,"i)^(?:None|Error)$"))
        return ""
    return RegExReplace(key,"i)(^|[~*$<>!^+#])(?:M3|Mouse3)$","$1MButton")
}

ShowConfig:
Critical
if (guiBuilding)
    return
guiBuilding := true
Gui, -AlwaysOnTop +MinimizeBox
IniRead, formX, %ConfigFile%, Window, X,
IniRead, formY, %ConfigFile%, Window, Y,
if (formX = "ERROR")
    formX := ""
if (formY = "ERROR")
    formY := ""

zRunKeyShow := (zKey = "" ? "None" : zKey)
zSetKeyShow := (zSetKey = "" ? "None" : zSetKey)
zFKeyShow := (zFKey = "" ? "None" : zFKey)
zFKey2Show := (zFKey2 = "" ? "None" : zFKey2)
xKeyShow := (xKey = "" ? "None" : xKey)

Gui, Destroy
Gui, +HwndmainToolHwndV67
Gui, Margin, 0, 0
Gui, Font, s9, Segoe UI
Gui, Color, F7F7F7
Gui, Add, Text, BackgroundTrans x6 y10 w42 h20, Profile:
Gui, Add, DropDownList, x50 y6 w110 vProfileSelect gLoadProfileFromGui, %profileList%
GuiControl, ChooseString, ProfileSelect, %currentProfile%
Gui, Add, Text, BackgroundTrans x166 y10 w25 h20, Tên:
Gui, Add, Edit, x194 y6 w95 h24 vNewProfileName, %currentProfile%
Gui, Add, Button, x295 y5 w75 h26 gAddProfile, LƯU PROFILE
Gui, Add, Button, x376 y5 w77 h26 gDeleteProfile, XÓA PROFILE

Gui, Add, Tab2, x0 y36 w459 h545 +0x2400 vAutoGSFMainTabs gRememberTabV6 hwndAutoGSFTabHwndV3 AltSubmit, 1. BUFF|2. NHẶT ĐỒ|3. FARM|4. ITEM NHẶT
tabScaleV3 := A_ScreenDPI / 96
tabItemSizeV3 := (Round(24*tabScaleV3)<<16) | Round(112*tabScaleV3)
SendMessage, 0x1329, 0, %tabItemSizeV3%,, ahk_id %AutoGSFTabHwndV3%
Gui, Tab, 1


Gui, Add, Progress, x6 y66 w250 h185 BackgroundEDFFF1 Disabled, 0
Gui, Font, s10 Bold c004CFF
Gui, Add, GroupBox, x6 y66 w250 h185, 1. BUFF SET PHỤ
Gui, Font, s9 Norm cDefault
Gui, Add, Text, BackgroundTrans x17 y94 w68, Chuyển set:
Gui, Add, Edit, x88 y90 w54 h20 vZSetKey, % MouseKeyDisplayV616(zSetKeyShow)
Gui, Add, Text, BackgroundTrans x149 y94 w35, Delay:
Gui, Add, Edit, x187 y90 w54 h20 vZSetDelay, %zSetDelay%
Gui, Add, Text, BackgroundTrans x17 y124 w68, Kill 1:
Gui, Add, Edit, x88 y120 w54 h20 vZKeyF1, % MouseKeyDisplayV616(zFKeyShow)
Gui, Add, Text, BackgroundTrans x149 y124 w35, Delay:
Gui, Add, Edit, x187 y120 w54 h20 vZDelay1, %zDelay1%
Gui, Add, Text, BackgroundTrans x17 y154 w68, Kill 2:
Gui, Add, Edit, x88 y150 w54 h20 vZKeyF2, % MouseKeyDisplayV616(zFKey2Show)
Gui, Add, Text, BackgroundTrans x149 y154 w35, Delay:
Gui, Add, Edit, x187 y150 w54 h20 vZDelay2, %zDelay2%
Gui, Font, s9 Norm cDefault
Gui, Add, Text, BackgroundTrans x17 y186 w88, Phím chạy set:
Gui, Add, Edit, x105 y182 w136 h20 vZRunKey, % MouseKeyDisplayV616(zRunKeyShow)
Gui, Add, Text, BackgroundTrans x17 y216 w224 h20 vBuffSetLeftInfoV501, Kill trái: chưa GET

Gui, Add, Progress, x6 y258 w250 h113 BackgroundFFF3E9 Disabled, 0
Gui, Font, s10 Bold c004CFF
Gui, Add, GroupBox, x6 y258 w250 h113, 2. BUFF NHANH
Gui, Font, s9 Norm cDefault
Gui, Add, Text, BackgroundTrans x17 y292 w68, Phím buff:
Gui, Add, Edit, x88 y288 w153 h20 vXKey, % MouseKeyDisplayV616(xKeyShow)
Gui, Add, Text, BackgroundTrans x17 y322 w68, Delay:
Gui, Add, Edit, x88 y318 w65 h20 vXDelay, %xDelay%
Gui, Add, Text, BackgroundTrans x17 y348 w224 h18 Center, Chạy 4 -> 5 -> 6 (chạy 1 lần)

master456Show := (master456Key = "" ? "None" : master456Key)

Gui, Add, Progress, x263 y66 w190 h139 BackgroundF4EEFF Disabled, 0
Gui, Font, s10 Bold c004CFF
Gui, Add, GroupBox, x263 y66 w190 h139, 4. PHÍM CAST
Gui, Font, s9 Norm cDefault
Gui, Add, Text, BackgroundTrans x272 y87 w172 Center, Chỉ bấm phím
Loop, 3
{
    i := A_Index
    yy := 110 + ((i - 1) * 29)
    ty := yy + 4
    keyValue := QCastKey%i%
    if (keyValue = "")
        keyValue := "None"
    delayValue := QCastDelay%i%
    Gui, Add, Text, BackgroundTrans x272 y%ty% w23 Center, %i%
    Gui, Add, Edit, x299 y%yy% w63 h20 vQCastKey%i%, % MouseKeyDisplayV616(keyValue)
    Gui, Add, Text, BackgroundTrans x366 y%ty% w34, Delay:
    Gui, Add, Edit, x402 y%yy% w41 h20 vQCastDelay%i%, %delayValue%
}

Gui, Add, Progress, x263 y212 w190 h214 BackgroundFFF3E9 Disabled, 0
Gui, Font, s9 Bold c004CFF
Gui, Add, GroupBox, x263 y212 w190 h214, 5. Bấm + Click Phải -> Trở Về F
Gui, Font, s9 Norm cDefault
Gui, Add, Text, BackgroundTrans x272 y234 w23 Center, STT
Gui, Add, Text, BackgroundTrans x299 y234 w63 Center, Phím
Gui, Add, Text, BackgroundTrans x373 y234 w70 Center, Delay
Loop, 6
{
    i := A_Index
    yy := 255 + ((i - 1) * 28)
    ty := yy + 4
    keyValue := clickCastRows[i].key
    if (keyValue = "")
        keyValue := "None"
    delayValue := clickCastRows[i].delay
    Gui, Add, Text, BackgroundTrans x272 y%ty% w23 Center, %i%
    Gui, Add, Edit, x299 y%yy% w63 h20 vRClickKey%i%, % MouseKeyDisplayV616(keyValue)
    Gui, Add, Edit, x373 y%yy% w70 h20 vRClickDelay%i%, %delayValue%
}

Gui, Add, Progress, x263 y433 w190 h138 BackgroundFFFBEA Disabled, 0
Gui, Font, s10 Bold c004CFF
Gui, Add, GroupBox, x263 y433 w190 h138, 6. Chọn kill đánh
Gui, Font, s9 Norm cDefault
Gui, Add, Edit, x272 y459 w171 h22 vForm6KeyInputV716 gForm6InputChangedV716, % MouseKeyDisplayV616(form6KeyV716)
Gui, Add, Radio, x272 y496 w171 h22 Group vForm6ClickV716 gForm6ModeChangedV716, Kill đánh phải
Gui, Add, Radio, x272 y531 w125 h22 vForm6HoldV716 gForm6ModeChangedV716, Kill đè phải
Gui, Add, Edit, x405 y531 w38 h22 Number Center Limit4 vForm6CountInputV716 gForm6InputChangedV716, %form6CountV716%
Form6RefreshV716()
Loop, 5
{
    i := A_Index
    currentKey := FKey%i%
    currentDelay := FDelay%i%
    if (currentKey = "")
        currentKey := "None"
    Gui, Add, Edit, x0 y0 w1 h1 Hidden vFKey%i%, % MouseKeyDisplayV616(currentKey)
    Gui, Add, Edit, x0 y0 w1 h1 Hidden vFDelay%i%, %currentDelay%
}

Gui, Add, Progress, x6 y378 w250 h185 BackgroundFFF0F8 Disabled, 0
Gui, Font, s9 Bold c004CFF
Gui, Add, GroupBox, x6 y378 w250 h185, 3. Kil buff 1 lần (lần 2 tắt)
Gui, Font, s9 Norm cDefault
Gui, Add, Text, BackgroundTrans x17 y408 w86 h20, Deathlord:
Gui, Add, Edit, x108 y404 w50 h22 Number vDeathlordStateInputV19, %deathlordStateV19%
Gui, Add, Text, BackgroundTrans x163 y408 w10 h20, /
Gui, Add, Edit, x177 y404 w64 h22 vStateBuffKeyInputV17, % MouseKeyDisplayV616(stateBuffKeyV17="" ? "None" : stateBuffKeyV17)
Gui, Add, Text, BackgroundTrans x17 y438 w86 h20, Pinnacle:
Gui, Add, Edit, x108 y434 w50 h22 Number vPestilenceStateInputV19, %pestilenceStateV19%
Gui, Add, Text, BackgroundTrans x163 y438 w10 h20, /
Gui, Add, Edit, x177 y434 w64 h22 vPestilenceKeyInputV18, % MouseKeyDisplayV616(pestilenceKeyV18="" ? "None" : pestilenceKeyV18)
Gui, Add, Text, BackgroundTrans x17 y468 w86 h20, Anathema:
Gui, Add, Edit, x108 y464 w50 h22 Number vAnathemaStateInputV518, %anathemaStateV518%
Gui, Add, Text, BackgroundTrans x163 y468 w10 h20, /
Gui, Add, Edit, x177 y464 w64 h22 vAnathemaKeyInputV518, % MouseKeyDisplayV616(anathemaKeyV518="" ? "None" : anathemaKeyV518)
Gui, Add, Button, x17 y494 w112 h23 gBuffGetLayoutV19, GET ID SKILL
Gui, Add, Edit, x137 y494 w104 h23 ReadOnly vBuffGetResultV19, %buffGetTextV22%
Gui, Add, Text, BackgroundTrans x17 y533 w94 h18, Bật/tắt Cast:
Gui, Add, Edit, x113 y528 w66 h22 vCastToggleKeyInputV1801 gCastToggleKeyChangedV1801, % MouseKeyDisplayV616(castToggleKeyV1801="" ? "None" : castToggleKeyV1801)
Gui, Add, Text, BackgroundTrans x184 y533 w58 h18 Center vCastToggleStatusV1801, % castManualToggleV1801 ? "ON" : "OFF"
Gui, Add, DropDownList, x0 y0 w1 h1 Hidden vQCastDoubleKey, None|Left|Right|Up|Down|Home|End|PgUp|PgDn
GuiControl, ChooseString, QCastDoubleKey, %qCastDoubleKey%
Gui, Add, Edit, x0 y0 w1 h1 Hidden vQCastDoubleTapMs, %qCastDoubleTapMs%
Gui, Add, DropDownList, x0 y0 w1 h1 Hidden vClickCastKeyInput, None|Left|Right|Up|Down|Home|End|PgUp|PgDn
GuiControl, ChooseString, ClickCastKeyInput, %clickCastDoubleKey%
Gui, Add, Edit, x0 y0 w1 h1 Hidden vClickCastMsInput, %clickCastDoubleTapMs%
Gui, Add, DropDownList, x0 y0 w1 h1 Hidden vDoubleKey, None|Left|Right|Up|Down|Home|End|PgUp|PgDn
GuiControl, ChooseString, DoubleKey, %doubleKey%
Gui, Add, Edit, x0 y0 w1 h1 Hidden vDoubleTapMs, %doubleTapMs%
Gui, Add, DropDownList, x0 y0 w1 h1 Hidden vFormDoubleKey, None|Left|Right|Up|Down|Home|End|PgUp|PgDn
GuiControl, ChooseString, FormDoubleKey, %formDoubleKey%
Gui, Add, Edit, x0 y0 w1 h1 Hidden vFormDoubleTapMs, %formDoubleTapMs%
Gui, Add, Edit, x0 y0 w1 h1 Hidden Center vMaster456KeyInput, %master456Show%

Gui, Tab, 2
Gui, Add, Progress, x6 y66 w219 h500 BackgroundEAFCFF Disabled, 0
Gui, Font, s10 Bold c004CFF
Gui, Add, GroupBox, x6 y66 w219 h500, HP / MANA

checkOpt := autoPotOn ? "Checked" : ""
Gui, Font, s9 Bold cRed
Gui, Add, Checkbox, BackgroundTrans -Theme x15 y93 w16 h15 vAutoPotOn %checkOpt%,
Gui, Add, Text, BackgroundTrans x33 y95 w174 h18 vCheckboxCaption_AutoPotOn gCheckboxCaptionToggleV301, Buff HP Belt
Gui, Font, s9 Norm cRed
Gui, Add, Text, BackgroundTrans x15 y170 w42, Pot :
Gui, Add, DropDownList, x92 y166 w115 vPotMode, 1|2|3|4|Auto(1-4)
GuiControl, ChooseString, PotMode, %potMode%
Gui, Add, Text, BackgroundTrans x15 y200 w74, Ngưỡng 1/2:
Gui, Add, Edit, x92 y196 w50 h20 vPotHPThreshold, %potHPThreshold%
Gui, Add, Text, BackgroundTrans x146 y200 w8, /
Gui, Add, Edit, x157 y196 w50 h20 Number vPotHPThreshold2InputV299, %potHPThreshold2V299%
Gui, Add, Text, BackgroundTrans x15 y230 w68, Cooldown :
Gui, Add, Edit, x92 y226 w115 h20 vPotCooldown, %potCooldown%

manaOpt := manaOn ? "Checked" : ""
Gui, Font, s9 Bold cBlue
Gui, Add, Checkbox, BackgroundTrans -Theme x15 y266 w16 h15 vManaOn %manaOpt%,
Gui, Add, Text, BackgroundTrans x33 y268 w112 h18 vCheckboxCaption_ManaOn gCheckboxCaptionToggleV301, Buff MP Belt
Gui, Font, s9 Norm cBlue
Gui, Add, Text, BackgroundTrans x15 y343 w42, Pot :
Gui, Add, DropDownList, x92 y339 w115 vManaMode, 1|2|3|4|Auto(1-4)
GuiControl, ChooseString, ManaMode, %manaMode%
Gui, Add, Text, BackgroundTrans x15 y373 w52, Ngưỡng :
Gui, Add, Edit, x92 y369 w115 h20 vManaThreshold, %manaThreshold%
Gui, Add, Text, BackgroundTrans x15 y403 w68, Cooldown :
Gui, Add, Edit, x92 y399 w115 h20 vManaCooldown, %manaCooldown%

Gui, Font, s9 Bold cRed
invHealOpt := invHealOn ? "Checked" : ""
Gui, Add, Checkbox, BackgroundTrans -Theme x15 y115 w16 h15 vInvHealOn %invHealOpt%,
Gui, Add, Text, BackgroundTrans x33 y117 w174 h18 vCheckboxCaption_InvHealOn gCheckboxCaptionToggleV301, Buff HP Rương
cubeHealOpt := cubeHealOn ? "Checked" : ""
Gui, Add, Checkbox, BackgroundTrans -Theme x15 y137 w16 h15 vCubeHealOn %cubeHealOpt%,
Gui, Add, Text, BackgroundTrans x33 y139 w174 h18 vCheckboxCaption_CubeHealOn gCheckboxCaptionToggleV301, Buff HP Cube
Gui, Font, s9 Bold cBlue
invManaOpt := invManaOn ? "Checked" : ""
Gui, Add, Checkbox, BackgroundTrans -Theme x15 y288 w16 h15 vInvManaOn %invManaOpt%,
Gui, Add, Text, BackgroundTrans x33 y290 w112 h18 vCheckboxCaption_InvManaOn gCheckboxCaptionToggleV301, Buff MP Rương
cubeManaOpt := cubeManaOn ? "Checked" : ""
Gui, Add, Checkbox, BackgroundTrans -Theme x15 y310 w16 h15 vCubeManaOn %cubeManaOpt%,
Gui, Add, Text, BackgroundTrans x33 y312 w112 h18 vCheckboxCaption_CubeManaOn gCheckboxCaptionToggleV301, Buff MP Cube

Gui, Font, s9 Norm cDefault
Gui, Add, Button, x120 y255 w90 h30 vInventoryArrangeButtonV576 gInventoryArrangeButtonV576, Sắp Rương
Gui, Add, Button, x120 y300 w90 h30 vTransferStashButtonV630 gTransferStashButtonV630, Chuyển Khố
Gui, Font, s9 Norm cBlue

Gui, Font, s9 Norm cRed
Gui, Add, Text, BackgroundTrans x15 y434 w30, Bấm
Gui, Add, Edit, x48 y430 w35 h20 Center vBelt4HPKey, % MouseKeyDisplayV616(belt4HPKey)
Gui, Add, Text, BackgroundTrans x88 y434 w126, 16HP Rương→Belt

Gui, Font, s9 Norm cBlue
Gui, Add, Text, BackgroundTrans x15 y464 w30, Bấm
Gui, Add, Edit, x48 y460 w35 h20 Center vBelt2HP2ManaKey, % MouseKeyDisplayV616(belt2HP2ManaKey)

Gui, Font, s9 Norm cRed
Gui, Add, Text, BackgroundTrans x88 y464 w126, 8HP + 8MP → Belt
Gui, Font, s9 Norm cBlue

Gui, Font, s9 Norm cRed
Gui, Add, Text, BackgroundTrans x15 y494 w30, Bấm
Gui, Add, Edit, x48 y490 w35 h20 Center vInvToCubeKey, % MouseKeyDisplayV616(invToCubeKey)
Gui, Add, Text, BackgroundTrans x88 y494 w126, Rương → Cube
Gui, Add, Text, BackgroundTrans x15 y524 w45 h20, Delay:
Gui, Add, Edit, x63 y520 w55 h20 Center vCubePickupDelayInput, %cubePickupDelayMs%
Gui, Add, Text, BackgroundTrans x123 y524 w10 h20, /
Gui, Add, Edit, x138 y520 w55 h20 Center vCubeTransferDelayInput, %cubeTransferDelayMs%
Gui, Add, Text, BackgroundTrans x197 y524 w22 h20, ms

Gui, Add, Progress, x235 y66 w219 h515 BackgroundEAFCFF Disabled, 0
Gui, Font, s10 Bold c004CFF
Gui, Add, GroupBox, x235 y66 w219 h515, NHẶT VẬT PHẨM
Gui, Font, s9 Norm cBlue
Gui, Add, Checkbox, BackgroundTrans -Theme x244 y94 w16 h15 vPickupEnabledInputV79 gPickupUiToggleV79 Checked%pickupImageOn%,
Gui, Add, Text, BackgroundTrans x262 y92 w30 h18 vCheckboxCaption_PickupEnabledInputV79 gCheckboxCaptionToggleV301, Nhặt
Gui, Add, Edit, x299 y90 w42 h24 vPickupToggleKeyInputV79, % MouseKeyDisplayV616(pickupToggleKeyV79="" ? "None" : pickupToggleKeyV79)
Gui, Add, Text, BackgroundTrans x348 y93 w55 h18, Bán kính:
Gui, Add, Edit, x409 y90 w36 h24 vPickupRadius, %pickupRadius%
; Cùng dòng: BK quét đồ và BK Tele khi nhặt lỗi; không thay đổi logic của hai bán kính.
Gui, Add, Text, BackgroundTrans x244 y123 w48 h18, BK quét:
Gui, Add, Edit, x295 y119 w33 h22 Number vPickupScanRadiusInputV810, %pickupScanRadiusV810%
Gui, Add, Text, BackgroundTrans x335 y123 w71 h18, BK Tele lỗi:
Gui, Add, Edit, x410 y119 w35 h22 Number Limit3 vPickupFailTeleRadiusInputV1253, %pickupFailTeleRadiusV1253%
rareWarningKeyShowV1 := (rareWarningKeyV1 = "" ? "None" : rareWarningKeyV1)
Gui, Add, Edit, x244 y145 w45 h22 Hidden vRareWarningKeyInputV1, None
Gui, Add, Checkbox, BackgroundTrans -Theme x244 y156 w16 h15 vRareWarningHideInputV19 gRareWarningHideChangedV19 Checked%rareWarningHiddenV19%,
Gui, Add, Text, BackgroundTrans x262 y155 w183 h18 vCheckboxCaption_RareWarningHideInputV19 gCheckboxCaptionToggleV301, Ẩn/hiện DS nhặt
Gui, Font, s9 Norm cDefault
Gui, Add, Edit, x244 y183 w40 h24 vPickupStashKeyInputV14 gPickupGroupKeysChangedV14, % MapHotkeyDisplayV178(pickupStashKeyV14)
Gui, Add, Text, BackgroundTrans x292 y186 w105 h20, Nhặt vào rương
Gui, Add, Button, x405 y183 w40 h24 gPickupButton0V146, Nhặt
Gui, Add, Edit, x244 y214 w40 h24 vPickupSetKeyInputV14 gPickupGroupKeysChangedV14, % MapHotkeyDisplayV178(pickupSetKeyV14)
Gui, Add, Text, BackgroundTrans x292 y217 w105 h20, Nhặt Set Cube
Gui, Add, Button, x405 y214 w40 h24 gPickupButton5V146, Nhặt
Gui, Add, Edit, x244 y245 w40 h24 vPickupSUKeyInputV14 gPickupGroupKeysChangedV14, % MapHotkeyDisplayV178(pickupSUKeyV14)
Gui, Add, Text, BackgroundTrans x292 y248 w105 h20, Nhặt Unique Cube
Gui, Add, Button, x405 y245 w40 h24 gPickupButton7V146, Nhặt
Gui, Add, Text, BackgroundTrans x244 y279 w27 h18, Bấm
Gui, Add, Edit, x278 y276 w40 h24 vSigKeyInputV147 gSigKeyChangedV147, % MouseKeyDisplayV616(sigKeyV147="" ? "None" : sigKeyV147)
Gui, Add, Text, BackgroundTrans x326 y279 w73 h18, Set + mảnh
Gui, Add, Button, x405 y276 w40 h24 vSigButtonV147 gSigButtonV147, Sig
Gui, Add, Edit, x0 y0 w1 h1 Hidden vSigSuKeyInputV181, % MapHotkeyDisplayV178(sigSuKeyV181)
Gui, Add, Button, x0 y0 w1 h1 Hidden vSigSuButtonV181 gSigSuButtonV181, Sig
Gui, Add, Checkbox, BackgroundTrans -Theme x244 y313 w16 h15 vSigTUInputV586 gSigTierChangedV13 Checked%sigTUV586%,
Gui, Add, Text, BackgroundTrans x262 y312 w22 h18 vCheckboxCaption_SigTUInputV586 gCheckboxCaptionToggleV301, TU
Gui, Add, Checkbox, BackgroundTrans -Theme x294 y313 w16 h15 vSigSUInputV510 gSigTierChangedV13 Checked%sigSUV510%,
Gui, Add, Text, BackgroundTrans x312 y312 w22 h18 vCheckboxCaption_SigSUInputV510 gCheckboxCaptionToggleV301, SU
Gui, Add, Checkbox, BackgroundTrans -Theme x344 y313 w16 h15 vSigSSUInputV13 gSigTierChangedV13 Checked%sigSSUV13%,
Gui, Add, Text, BackgroundTrans x362 y312 w28 h18 vCheckboxCaption_SigSSUInputV13 gCheckboxCaptionToggleV301, SSU
Gui, Add, Text, BackgroundTrans x244 y345 w27 h18, Bấm
Gui, Add, Edit, x278 y342 w48 h24 vItemInspectKeyInputV287 gItemInspectKeyChangedV287, % MapHotkeyDisplayV178(itemInspectKeyV287)
Gui, Add, Text, BackgroundTrans x334 y345 w111 h18, GET item
Gui, Add, Checkbox, BackgroundTrans -Theme x244 y379 w16 h15 vExcludeModeV329 gExcludeModeChangedV329 Checked%excludeModeV329%,
Gui, Add, Text, BackgroundTrans x262 y378 w183 h18 vCheckboxCaption_ExcludeModeV329 gCheckboxCaptionToggleV301, Lưu class vào DS loại trừ
Gui, Add, Checkbox, BackgroundTrans -Theme x244 y410 w16 h15 vExcludeDeleteModeV332 gExcludeDeleteModeChangedV332 Checked%excludeDeleteModeV332%,
Gui, Add, Text, BackgroundTrans x262 y409 w183 h18 vCheckboxCaption_ExcludeDeleteModeV332 gCheckboxCaptionToggleV301, Xóa class khỏi DS loại trừ
Gui, Add, Edit, BackgroundFFFFFF x244 y437 w201 h64 ReadOnly vItemInspectResultV287, Rê chuột vào vật rồi bấm phím GET.
GameRoomHistoryLoadV252()
Gui, Add, Text, BackgroundTrans x244 y513 w201 h18, Phòng hiện tại / gần nhất:
Gui, Add, Edit, BackgroundFFFFFF x244 y537 w201 h24 ReadOnly vGameRoomNameV252, % GameRoomHistoryLatestV252()
; V1181: save when game is entered, not only in Save & Exit.
SetTimer, GameRoomHistoryWatchTimerV1181, 500

Gui, Tab, 3
Gui, Add, Progress, x6 y66 w150 h281 BackgroundFFF3DF Disabled, 0
Gui, Add, Progress, x162 y66 w83 h138 BackgroundEAF5E8 Disabled, 0
Gui, Add, Progress, x162 y209 w83 h138 BackgroundEAF5E8 Disabled, 0
Gui, Add, Progress, x6 y357 w239 h215 BackgroundEAF5E8 Disabled, 0
Gui, Add, Progress, x255 y66 w199 h88 BackgroundEAF5FF Disabled, 0
Gui, Add, Progress, x255 y354 w199 h224 BackgroundEAF5FF Disabled, 0
Gui, Add, Progress, x255 y164 w199 h178 BackgroundF3ECFF Disabled, 0
Gui, Font, s10 Bold c004CFF
 
Gui, Font, s9 Bold c004CFF
Gui, Add, GroupBox, x162 y66 w83 h160, PET Loại Trừ
Gui, Font, s8 Norm cDefault

Gui, Add, Text, BackgroundTrans x168 y84 w45 h16, Bỏ Qua
Gui, Add, Edit, x215 y82 w25 h20 Number Limit4 vMonsterLockNoDamageSecInputV621, %monsterLockNoDamageSecV621%
Gui, Add, Text, BackgroundTrans x168 y106 w45 h16, Khóa (s)
Gui, Add, Edit, x215 y104 w25 h20 Number Limit4 vMonsterLockRoomSecInputV622, %monsterLockRoomSecV622%

Gui, Add, Text, BackgroundTrans x166 y128 w48 h16, BK Lock
Gui, Add, Edit, x215 y126 w25 h20 Number Limit3 vMonsterSkipDistanceInputV752 gMonsterSkipDistanceChangedV752, %monsterSkipDistanceV752%
petInitialV16 := PetExcludeTextV16()
Gui, Add, Edit, x168 y152 w71 h66 Multi -Wrap WantReturn vPetExcludeListV16 hwndPetExcludeHwndV16, % petInitialV16 . "`r`n"

Gui, Font, s9 Bold c004CFF
Gui, Add, GroupBox, x162 y235 w83 h112, Boss Ưu Tiên
Gui, Font, s8 Norm cDefault
bossInitialV221 := BossPriorityTextV221()
Gui, Add, Edit, x168 y256 w71 h85 Multi -Wrap WantReturn vBossPriorityListV221 hwndBossPriorityHwndV222, % bossInitialV221 . "`r`n"

Gui, Font, s8 Norm cDefault
Gui, Add, Button, x10  y374 w42 h28 vVeLab6ButtonV321 gVeLabButtonV321, VeLab6
Gui, Add, Button, x58  y374 w42 h28 vVeLab7ButtonV321 gVeLabButtonV321, VeLab7
Gui, Add, Button, x106 y374 w42 h28 vVeLab8ButtonV321 gVeLabButtonV321, VeLab8
Gui, Add, Button, x154 y374 w42 h28 vVeLab9ButtonV321 gVeLabButtonV321, VeLab9
Gui, Add, Button, x202 y374 w42 h28 vVeLab10ButtonV321 gVeLabButtonV321, VeLab10
Gui, Add, Button, x10  y408 w42 h28 +0x2000 vFarm130RunButtonV257 gFarm130ButtonV257, 130`nStart
Gui, Add, Button, x58  y408 w42 h28 +0x2000 vFarm133RunButtonV290 gFarm133ButtonV290, 133`nStart
Gui, Add, Button, x106 y408 w42 h28 +0x2000 vFarm136RunButtonV290 gFarm136ButtonV290, 136`nStart
Gui, Add, Button, x154 y408 w42 h28 +0x2000 vFarm139RunButtonV290 gFarm139ButtonV290, 139`nStart
Gui, Add, Button, x202 y408 w42 h28 +0x2000 vFarmExtra3000ButtonV297 gFarmExtra3000ButtonV297, 3000`nStart
Gui, Add, Button, x10  y442 w42 h28 +0x2000 vMapControlRunButtonV171 gMapControlButtonV168, SCOS`nStart
Gui, Add, Button, x58  y442 w42 h28 +0x2000 vFarmNaoRunButtonV184 gFarmNaoButtonV184, FAUT`nStart
Gui, Add, Button, x106 y442 w42 h28 +0x2000 vFarmCycRunButtonV42 gFarmCycButtonV42, CYC`nStart
Gui, Add, Button, x154 y442 w42 h28 +0x2000 vFarmUbuRunButtonV62 gFarmUbuButtonV62, UBU`nStart
Gui, Add, Button, x202 y442 w42 h28 +0x2000 vFarmExtraCAINButtonV297 gFarmExtraCAINButtonV297, CAIN`nStart
Gui, Add, Button, x10  y476 w42 h28 +0x2000 vFarmExtraTRANButtonV297 gFarmExtraTRANButtonV297, TRAN`nStart
Gui, Add, Button, x58  y476 w42 h28 vFarmExtraWEAButtonV297 gFarmExtraWEAButtonV297, WEA
Gui, Add, Button, x106 y476 w42 h28 +0x2000 vFarmExtraVIZButtonV297 gFarmExtraVIZButtonV297, VIZ`nStart
Gui, Add, Button, x154 y476 w42 h28 +0x2000 vFarmBOButtonV413 gFarmBOButtonV413, BO`nStart
Gui, Add, Button, x202 y476 w42 h28 +0x2000 vHopButtonV556 gHopButtonV556, HOP

Gui, Font, s8 Norm cDefault
Gui, Add, Button, x10 y513 w135 h25 vBuffSequenceButtonV555 gBuffSequenceToggleV555, Auto Buff Delay
Gui, Add, Edit, x154 y514 w80 h23 Number Center vBuffSequenceDelayInputV555 gBuffSequenceDelayChangedV555, %buffSequenceDelayV555%

Gui, Add, Checkbox, BackgroundTrans -Theme x15 y548 w16 h15 vFarmEntrySigCheckV315 gFarmEntryOptionsChangedV315 Checked%farmEntrySigV315%,
Gui, Add, Text, BackgroundTrans x31 y550 w24 h18 vCheckboxCaption_FarmEntrySigCheckV315 gCheckboxCaptionToggleV301, SIG
Gui, Add, Checkbox, BackgroundTrans -Theme x58 y548 w16 h15 vFarmEntryGoldCheckV347 gFarmEntryOptionsChangedV315 Checked%farmEntryGoldV315%,
Gui, Add, Text, BackgroundTrans x76 y550 w50 h18 vCheckboxCaption_FarmEntryGoldCheckV347 gCheckboxCaptionToggleV301, Cất Item
Gui, Add, Checkbox, Hidden vAutoLoadMapCheckV348 Checked%autoLoadMapV340%,

Gui, Add, Checkbox, BackgroundTrans -Theme x128 y548 w16 h15 vRecoveryStartTestV537 gRecoveryStartChangedV726,
Gui, Add, Text, BackgroundTrans x146 y550 w55 h18 vCheckboxCaption_RecoveryStartTestV537, Vào GĐ4
Gui, Add, Checkbox, BackgroundTrans -Theme x201 y548 w16 h15 vMapTestModeCheckV656 gMapTestModeChangedV656 Checked%mapTestModeV656%,
Gui, Add, Text, BackgroundTrans x219 y550 w35 h18 vCheckboxCaption_MapTestModeCheckV656 gCheckboxCaptionToggleV301, Mode

SetTimer, MapControlButtonStatusV171, 200

Gui, Font, s10 Bold c004CFF
Gui, Add, GroupBox, x6 y66 w150 h281, TỰ ĐÁNH
Gui, Font, s8 Norm cDefault


Gui, Add, Text, BackgroundTrans x15 y97 w49 h18, BK đánh:
Gui, Add, Edit, x63 y94 w23 h20 Number vMonsterRadiusInputV48 gMonsterRadiusChangedV239, %monsterRadiusV48%
Gui, Add, Text, Hidden BackgroundTrans x89 y97 w38 h18, Quét:
Gui, Add, Edit, Hidden x128 y94 w25 h20 Number Limit3 vFarmScanLimitInputV771 gFarmScanLimitChangedV771, %farmScanLimitV771%
Gui, Add, Checkbox, Hidden BackgroundTrans -Theme x95 y93 w16 h15 vMonsterLockUntilDeadInputV145 gMonsterLockUntilDeadToggleV145 Checked%monsterLockUntilDeadV145%,
Gui, Add, Text, Hidden BackgroundTrans x113 y95 w27 h20 vCheckboxCaption_MonsterLockUntilDeadInputV145 gCheckboxCaptionToggleV301, Khóa
Gui, Add, Text, BackgroundTrans  x15 y125 w60 h18, Mở Cổng :
Gui, Add, Edit, x73 y121 w32 h20 vPortalCastInputV50, % portalCastKeyV50="MButton" ? "M3" : portalCastKeyV50="" ? "None" : portalCastKeyV50
Gui, Add, Text, BackgroundTrans  x109 y125 w8 h18, /
Gui, Add, Edit, x120 y121 w25 h20 Number vPortalCastEveryInputV52, %portalCastEveryV52%
Gui, Add, Text, BackgroundTrans  x15 y153 w56 h18, Cast(tele)
Gui, Add, Edit, x65 y149 w40 h20 vTeleportKeyInputV55, % teleportKeyV55="" ? "None" : teleportKeyV55="MButton" ? "M3" : teleportKeyV55
Gui, Add, Text, BackgroundTrans  x109 y153 w8 h18, /
Gui, Add, Edit, x120 y149 w25 h20 Number vTeleportIntervalInputV56, %teleportIntervalSecV56%
Gui, Add, Text, BackgroundTrans x15 y181 w116 h18, Bước di chuyển :
Gui, Add, Edit, x120 y177 w25 h20 Number vMapMoveDistanceInputV197 gMapMoveDistanceChangedV197, %mapMoveDistanceV197%

Gui, Add, Text, BackgroundTrans  x15 y209 w116 h18, Cho phép xa đích :
Gui, Add, Edit, x120 y205 w25 h20 Number vGoalDetourInputV14, %goalDetourV14%

Gui, Add, Text, BackgroundTrans  x15 y237 w116 h18, Thời gian xét kẹt(s) :
Gui, Add, Edit, x120 y233 w25 h20 Number vChaseCheckInputV9, %chaseCheckSecV9%

Gui, Add, Text, BackgroundTrans x15 y265 w104 h18, Đi tối thiểu :
Gui, Add, Edit, x120 y261 w25 h20 Number vBOMoveMinimumInputV456 gBOMoveMinimumChangedV456, %boMoveMinimumV456%
Gui, Add, Checkbox, BackgroundTrans -Theme x15 y289 w16 h15 vViewIdInputV54 gViewIdChangedV54 Checked%viewIdV54%,
Gui, Add, Text, BackgroundTrans x33 y291 w46 h20 vCheckboxCaption_ViewIdInputV54 gCheckboxCaptionToggleV301, View ID
Gui, Add, Checkbox, BackgroundTrans -Theme x80 y289 w16 h15 vViewPosInputV291 gViewPosChangedV291 Checked%viewPosV291%,
Gui, Add, Text, BackgroundTrans x98 y291 w50 h20 vCheckboxCaption_ViewPosInputV291 gCheckboxCaptionToggleV301, View Pos
Gui, Add, Checkbox, BackgroundTrans -Theme x15 y309 w16 h15 vViewTipInputV640 gViewTipChangedV640 Checked%viewTipV640%,
Gui, Add, Text, BackgroundTrans x33 y311 w46 h20 vCheckboxCaption_ViewTipInputV640 gCheckboxCaptionToggleV301, Tip
Gui, Add, Text, BackgroundTrans x15 y328 w68 h18, Move Delay:
Gui, Add, Edit, x91 y320 w54 h20 Number Limit5 vMoveDelayInputV810 gMoveDelayChangedV810, %moveDelayMsV810%

Gui, Font, s10 Bold c004CFF
Gui, Add, GroupBox, x255 y66 w199 h118, MAP SCOS
Gui, Font, s9 Norm cDefault
Gui, Add, DropDownList, x264 y91 w181 h160 AltSubmit vRouteMapSelectV21 gRouteMapSelectV21,
Gui, Add, Button, x264 y119 w105 h25 gRouteMapReloadV843, TẢI LẠI INI
Gui, Add, Text, BackgroundTrans x380 y124 w20 h18, KC
Gui, Add, Edit, x403 y119 w42 h25 Number Limit4 vRouteRecordDistanceInputV649 gRouteRecordDistanceChangedV649, %routeRecordDistanceV649%
boHashThresholdV830 := BoHashThresholdGetV830()
Gui, Add, Button, x264 y149 w88 h25 vRoomTestButtonV89 gRoomTestToggleV89, Tạo
Gui, Add, Button, x357 y149 w88 h25 vRoomContinueButtonV58 gRoomContinueToggleV58, Sửa
RouteMapRefreshV21()
SetTimer, RoomMapListTimerV110, 2000
Gui, Font, s10 Bold c004CFF
Gui, Add, GroupBox, x255 y354 w199 h224,
Gui, Font, s8 Norm cDefault
Gui, Add, Button, x264 y350 w43 h24 gCoordGoStopV296, STOP
Gui, Add, Button, x323 y350 w35 h24 gCoordGoRequiredV26, GO
Gui, Add, Button, x362 y350 w35 h24 gCoordGoPrevV138, Prev
Gui, Add, Button, x401 y350 w34 h24 gCoordGoNextV80, Next
Gui, Font, s8 Norm cDefault
coordInitialV16 := CoordBoxTextV16()
Gui, Add, ListBox, x264 y379 w120 h188 +0x50 +0x100 -0x2 vCoordListInputV15 gCoordSelectInsertV57 hwndCoordListHwndV15
DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x1A0,"Ptr",0,"Ptr",Round(20*A_ScreenDPI/96))
Gui, Add, Button, x400 y379 w43 h28 vCoordTrackingButtonV409 gCoordTrackingToggleV409, F-ON
Gui, Add, Button, x400 y413 w43 h28 gCoordAddAfterYellowV136, ADD
Gui, Add, Button, x400 y447 w43 h28 vRoomInsertButtonV125 gRoomInsertToggleV125, UPDATE
Gui, Add, Button, x400 y481 w15 h24 gCoordMoveUpV144, ↑
Gui, Add, Button, x418 y481 w15 h24 gCoordMoveDownV144, ↓
Gui, Add, Button, x400 y511 w43 h24 vCoordDeleteButtonV125 gCoordDeleteYellowV136, XÓA
Gui, Add, Button, x400 y541 w43 h26 gLoadMapManualV341, Load
Gui, Font, s10 Bold c004CFF
Gui, Add, GroupBox, x255 y194 w199 h148, KHU VỰC FARM
Gui, Font, s9 Norm cDefault
Gui, Add, Text, BackgroundTrans  x264 y219 w82 h20, Trong thành:
Gui, Add, Edit, x349 y215 w43 h24 Number vTownLevelInputV22, %townLevelV22%
Gui, Add, Button, x399 y215 w37 h24 gTownGetV22, GET
Gui, Add, Text, BackgroundTrans  x264 y249 w82 h20, Ngoài thành:
Gui, Add, Edit, x349 y245 w43 h24 Number vOutsideLevelInputV22, %outsideLevelV22%
Gui, Add, Button, x399 y245 w37 h24 gOutsideGetV22, GET
Gui, Add, Checkbox, BackgroundTrans -Theme x264 y277 w16 h15 vContinuousMapInputV64 gContinuousMapChangedV64 Checked%continuousMapV168%,
Gui, Add, Text, BackgroundTrans x282 y279 w98 h18 vCheckboxCaption_ContinuousMapInputV64 gCheckboxCaptionToggleV301, Chạy liên tục
Gui, Add, Button, x383 y274 w64 h24 gFarmMapJournalOpenV940, Nhật ký
Gui, Font, s8 Norm cDefault
Gui, Add, Checkbox, BackgroundTrans -Theme x264 y309 w16 h16 vFarmResetWatchCheckV217 gFarmResetWatchChangedV217 Checked%farmResetWatchEnabledV217%,
Gui, Add, Text, x284 y307 w40 h22 +0x200 vCheckboxCaption_FarmResetWatchCheckV217 gCheckboxCaptionToggleV301, Đứng
Gui, Add, Edit, x330 y307 w30 h22 Number Center vFarmResetWatchMinutesV217 gFarmResetWatchChangedV217, %farmResetWatchMinutesV217%
Gui, Add, Text, x366 y307 w77 h22 +0x200, phút Farm
CoordBoxRefreshV15(true)
SetTimer, CoordCurrentTimerV15, 500
SetTimer, FarmMapJournalTimerV940, 1000
ViewDisplayApplyV601()

Gui, Tab, 4
Gui, Font, s9 Norm cDefault
Gui, Add, Text, BackgroundTrans x10 y65 w210 h20, DANH SÁCH NHẶT
Gui, Add, Text, BackgroundTrans x230 y65 w218 h20, NHẶT / THÊM / LOẠI TRỪ
Gui, Add, TreeView, x10 y87 w210 h319 +Buttons +Lines +Root vPickupCatalogV8 gPickupCatalogClickV8
UniquePickupCleanDuplicateV19()
PickupCatalogBuildV8()
PickupSplitInitV490()
pickupEditorTextV8 := PickupEditorReadV8()
Gui, Color, F7F7F7, FFFFFF
Gui, Font, s9 Norm c000000
Gui, Add, Edit, x230 y87 w218 h377 Multi +Wrap +VScroll -HScroll vPickupEditorInputV8, %pickupEditorTextV8%
Gui, Add, Text, BackgroundTrans x10 y418 w210 h18, VẬT PHẨM KHÔNG SIG
Gui, Add, Edit, x10 y440 w210 h136 Multi +Wrap +VScroll -HScroll vPickupNoSigEditorV490, %pickupNoSigTextV490%
RecoveryLoginLoadV489()
Gui, Add, Text, BackgroundTrans x230 y477 w35 h20, Game
Gui, Add, Edit, x268 y474 w147 h22 vRecoveryGamePathInputV489 gRecoverySettingsChangedV489, %recoveryGamePathV489%
Gui, Add, Button, x419 y474 w29 h22 gRecoveryGameBrowseV489, ...
Gui, Add, Text, BackgroundTrans x230 y505 w35 h20, ID
Gui, Add, Edit, x268 y502 w180 h22 vRecoveryAccountInputV489 gRecoverySettingsChangedV489, %recoveryAccountV489%
Gui, Add, Text, BackgroundTrans x230 y533 w35 h20, Pass
Gui, Add, Edit, x268 y530 w180 h22 Password vRecoveryPasswordInputV489 gRecoverySettingsChangedV489, %recoveryPasswordV489%
Gui, Add, Text, BackgroundTrans x230 y560 w218 h16 vRecoveryLoginStatusV489, GĐ4: mở lại và đăng nhập khi mất cửa sổ game.
Gui, Font, s9 Norm cDefault
Gui, Add, Text, Hidden x10 y577 w438 h11 vPickupEditorStatusV8,

Gui, Tab
GuiControl, Choose, AutoGSFMainTabs, %selectedTabV6%
Gui, Font, s8 Norm cDefault

Gui, Add, Button, x6   y589 w55 h26 gSaveConfig, Lưu
Gui, Add, Button, x68  y589 w102 h26 vRouteRecordButtonV358 gRouteRecordToggleV358, Ghi Tọa Độ
Gui, Add, Button, x177 y589 w82 h26 vFarmGD2TestButtonV644 gFarmGD2TestButtonV644, Run test
Gui, Add, Button, x266 y589 w82 h26 vExportLogButtonV81 gExportHPManaLog, Xuất Log
Gui, Add, Button, x355 y589 w98 h26 gPickupGuideShowV8, Hướng dẫn

validFormPos := (formX != "" && formY != "" && formX > -2000 && formY > -2000
    && formX < A_ScreenWidth && formY < A_ScreenHeight)

if (validFormPos)
    Gui, Show, x%formX% y%formY% w459 h624 NA, Auto-GSF V38 - Tên + Option
else
    Gui, Show, Center w459 h624 NA, Auto-GSF V38 - Tên + Option

for _,enableBtnV171 in ["MapControlRunButtonV171","FarmNaoRunButtonV184","FarmCycRunButtonV42","FarmUbuRunButtonV62","FarmExtra3000ButtonV297","FarmExtraTRANButtonV297","FarmExtraCAINButtonV297","FarmBOButtonV413","Farm130RunButtonV257","Farm133RunButtonV290","Farm136RunButtonV290","Farm139RunButtonV290"]
    GuiControl, Enable, %enableBtnV171%

guiBuilding := false
Critical, Off
configGuiVisible := true
SetTimer, RareWarningFollowGameV20, 200
SetTimer, RareWarningScanTimerV23, 350
RareWarningRenderV16()
return

FonStartupAutoLoadV340:
if (fonStartupLoadDoneV763)
    return
if (!autoLoadMapV340 || !coordTrackingEnabledV409
    || IsObject(roomRecordV108) || roomRecordFinishingV21)
    return
if (fonLoadBusyV410)
{
    if (autoLoadMapAttemptsV340<30)
        SetTimer, FonStartupAutoLoadV340, -1500
    return
}
autoLoadMapAttemptsV340++
startupPidV340 := CoordDisplayGamePidV1()
if (!startupPidV340)
{
    if (autoLoadMapAttemptsV340<30)
        SetTimer, FonStartupAutoLoadV340, -1500
    return
}
startupLevelV340 := RoomRecordLevelV259(startupPidV340)
if (!startupLevelV340)
{
    if (autoLoadMapAttemptsV340<30)
        SetTimer, FonStartupAutoLoadV340, -1500
    return
}
if (FonLoadMapV382("STARTUP_AUTO",startupPidV340,startupLevelV340))
{
    fonStartupLoadDoneV763 := true
    autoLoadMapAttemptsV340 := 0
    ToolTipInfoV386("Tự động Load map thành công.")
    SetTimer, RemoveToolTip, -1800
}
else if (autoLoadMapAttemptsV340<30)
    SetTimer, FonStartupAutoLoadV340, -2000
else
{
    fonStartupLoadDoneV763 := true
    PortalLogWriteV66("FON_STARTUP_AUTOLOAD_GIVEUP attempts=" . autoLoadMapAttemptsV340,"FON_AUTOLOAD_GIVEUP",5000)
}
return

PickupCatalogClickV8:
if (A_GuiEvent="DoubleClick" && A_EventInfo>0)
{
    pickupNameV8 := pickupCatalogNamesV11.HasKey(A_EventInfo) ? pickupCatalogNamesV11[A_EventInfo] : ""
    if (pickupNameV8="" || pickupNameV8="Khác")
        return
    PickupEditorInsertV574(pickupNameV8)
}
return

PickupEditorInsertV574(name)
{
    GuiControlGet, edit, 1:Hwnd, PickupEditorInputV8
    if (!edit)
        return false
    length := DllCall("GetWindowTextLength","Ptr",edit,"Int")
    VarSetCapacity(raw,(length+1)*2,0)
    DllCall("GetWindowText","Ptr",edit,"Str",raw,"Int",length+1)
    start := 0,finish := 0
    DllCall("SendMessage","Ptr",edit,"UInt",0xB0,"UIntP",start,"UIntP",finish,"Ptr")

    prefix := SubStr(raw, 1, start)
    posAdd := InStr(prefix, "#=== Nhặt Thêm")
    posCube := InStr(prefix, "#=== Chuyển Charm Vào Cube")
    posStore := InStr(prefix, "#=== Chuyển Vào Kho")
    posExclude := InStr(prefix, "#=== Không Nhặt")
    
    maxPos := 0
    if (posAdd > maxPos)
        maxPos := posAdd
    if (posCube > maxPos)
        maxPos := posCube
    if (posStore > maxPos)
        maxPos := posStore
    if (posExclude > maxPos)
        maxPos := posExclude
        
    if (posCube == maxPos && posCube > 0)
        name .= " [cube]"
    
    text := name . "`r`n"
    if (start > 0 && SubStr(raw, start, 1) != "`n" && SubStr(raw, start, 1) != "`r") {
        text := "`r`n" . text
    }

    DllCall("SendMessage","Ptr",edit,"UInt",0xB1,"Ptr",start,"Ptr",finish,"Ptr")
    DllCall("SendMessage","Ptr",edit,"UInt",0xC2,"Ptr",1,"Str",text,"Ptr")
    
    caretPos := start + StrLen(text)
    DllCall("SendMessage","Ptr",edit,"UInt",0xB1,"Ptr",caretPos,"Ptr",caretPos,"Ptr")

    if (!IsGameForegroundV63())
        GuiControl, 1:Focus, PickupEditorInputV8
    DllCall("SendMessage","Ptr",edit,"UInt",0xB7,"Ptr",0,"Ptr",0,"Ptr")
    GuiControl, 1:, PickupEditorStatusV8, Đã chèn tại con trỏ; bấm LƯU để áp dụng.
    return true
}
PickupCatalogParentChainV8(name)
{
    static chain := 0
    if (PickupNameNormalizeV8(name)="relic")
        return ["Charm"]
    if (PickupNameNormalizeV8(name)="runestone")
        return ["Rune"]
    if (!IsObject(chain) || !chain.Count())
    {
        chain := {}
        for _,tier in ["TU","SU","SSU","SSSU"]
            chain[tier] := ["Unique"]
        for _,sub in ["Gem thường","Gem Flawless","Gem Perfect"]
            chain[sub] := ["Gem"]
        for _,sub in ["Rune thường","Rune Enchanted","Rune Great","Rune Elemental"]
            chain[sub] := ["Rune"]
        gems := "Diamond|Amethyst|Ruby|Topaz|Bloodstone|Onyx|Amber|Turquoise|Sapphire|Emerald|Rainbow Stone|Skull"
        Loop, Parse, gems, |
        {
            chain[A_LoopField] := ["Gem thường","Gem"]
            chain["Flawless " . A_LoopField] := ["Gem Flawless","Gem"]
            chain["Perfect " . A_LoopField] := ["Gem Perfect","Gem"]
        }
        for _,set in [["Rune thường","El|Eld|Tir|Nef|Eth|Ith|Tal|Ral|Ort|Thul|Amn|Sol|Shael|Dol|Hel|Io|Lum|Ko|Fal|Lem|Pul|Um|Mal|Ist|Gul|Vex|Ohm|Lo|Sur|Ber|Jah|Cham|Zod"]
            ,["Rune Enchanted","Ol|Elq|Tyr|Nif|Xeth|Xith|Thal|Rhal|Urt|Tuul|Ahmn|Zol|Shaen|Doj|Hem|Iu|Lux|Ka|Fel|Lew|Phul|Un|Mhal|Yst|Gur|Vez|Ohn|Loz|Zur|Bur|Iah|Yham|Xod"]
            ,["Rune Great","Taha|Ghal|Qor"]
            ,["Rune Elemental","Fire|Stone|Arcane|Poison|Light|Ice"]]
        {
            parentName := set[1]
            Loop, Parse, % set[2], |
                chain[A_LoopField . " Rune"] := [parentName,"Rune"]
        }
        shrines := "Abandoned|Creepy|Eerie|Enchanted|Fascinating|Hidden|Intimidating|Magical|Ornate|Quiet|Sacred|Shimmering|Spiritual|Tainted|Trinity|Weird"
        for _,name in StrSplit(PickupCharmNamesV731(),"|")
            chain[name] := ["Charm"]
        chain["Small Cycle"] := ["Cycle"]
        chain["Shrine (10)"] := ["Shrine"]
        Loop, Parse, shrines, |
            chain[A_LoopField . " Shrine"] := ["Shrine"]
        for _,name in ["Sacred Essence","Heavenly Soul","Mark of Infusion","Crate O' Souls","Crate O' Sacred Essence"]
            chain[name] := ["Material"]
        for _,name in ["Signet of Learning","Greater Signet of Learning","Large Signet of Learning","Custom Signet"]
            chain[name] := ["Signet"]
        for _,name in ["Oil of Augmentation","Oil of Conjuration","Oil of Greater Luck","Oil of Intensity"]
            chain[name] := ["Oil"]
        for _,group in ["Arcane","Corrupted"]
            for _,suffix in ["Shard","Crystal","Cluster"]
                chain[group . " " . suffix] := [group]
    }
    return chain.HasKey(name) ? chain[name] : []
}

RecoveryStartChangedV726:
GuiControlGet, recoveryStartCheckedV726, 1:, RecoveryStartTestV537
if (recoveryStartCheckedV726)
    GuiControl, 1:, RecoveryLoginStatusV489, GĐ4 đã chọn; chọn map để bắt đầu.
else
    GuiControl, 1:, RecoveryLoginStatusV489, GĐ4 chưa chọn; chọn map sẽ không mở game.
return

CheckboxCaptionToggleV301:
checkboxCaptionTargetV301 := SubStr(A_GuiControl,17)
GuiControlGet, checkboxCaptionHwndV301, 1:Hwnd, %checkboxCaptionTargetV301%
if (checkboxCaptionHwndV301)
    SendMessage, 0xF5, 0, 0,, ahk_id %checkboxCaptionHwndV301%
return

PickupEditorSaveV8:
PickupSplitSaveV490()
return

PickupOptShowV12:
GuiControlGet, pickupOptDraftV12, 1:, PickupEditorInputV8
Gui, PickupOptV12:New, +Owner1 +Resize +MinSize720x480
Gui, PickupOptV12:Font, s9, Segoe UI
Gui, PickupOptV12:Add, Text, BackgroundTrans x12 y12 w760 h38, % "Light Plate [2-5] hoặc {2-5} = +2 đến +5 All Skills. [Fire dance] hoặc {Fire dance} đều được. Chỉ nhập tên = nhặt hết loại đó. # tắt dòng. Muốn lọc Angelic, tắt nhóm Angelic nhặt hết và thêm angelic vào luật."
Gui, PickupOptV12:Add, Text, BackgroundTrans x12 y57 w55 h20, Tên đồ:
Gui, PickupOptV12:Add, Edit, x68 y54 w230 h24 vPickupOptNameV12
Gui, PickupOptV12:Add, Text, BackgroundTrans x310 y57 w52 h20, Option:
Gui, PickupOptV12:Add, Edit, x363 y54 w265 h24 vPickupOptStatV12
Gui, PickupOptV12:Add, Text, BackgroundTrans x12 y88 w55 h20, Loại:
Gui, PickupOptV12:Add, Edit, x68 y84 w230 h24 vPickupOptTypeV12
Gui, PickupOptV12:Add, Text, BackgroundTrans x310 y88 w318 h20, Option [2-5] = +2 đến +5 All Skills
Gui, PickupOptV12:Add, Button, x642 y54 w128 h54 gPickupOptAddV12, THÊM LUẬT
Gui, PickupOptV12:Add, Edit, x12 y120 w758 h290 Multi -Wrap +VScroll +HScroll vPickupOptTextV12, %pickupOptDraftV12%
Gui, PickupOptV12:Add, Button, x12 y421 w120 h28 vPickupOptSaveButtonV12 gPickupOptSaveV12, LƯU
Gui, PickupOptV12:Add, Button, x145 y421 w120 h28 vPickupOptExampleButtonV12 gPickupOptExampleV12, THÊM MẪU (#)
Gui, PickupOptV12:Add, Button, x278 y421 w110 h28 vPickupOptHelpButtonV12 gPickupOptHelpV12, CÁCH NHẬP
Gui, PickupOptV12:Add, Text, BackgroundTrans x12 y458 w758 h20 vPickupOptStatusV12, Nhập tên và option; không nhập option thì nhặt hết loại đồ đó.
Gui, PickupOptV12:Show, w782 h492, Nhặt theo tên và option - D2MX
Gui, 1:Default
return

PickupOptAddV12:
GuiControlGet, optNameV12, PickupOptV12:, PickupOptNameV12
GuiControlGet, optStatV12, PickupOptV12:, PickupOptStatV12
GuiControlGet, optTypeV12, PickupOptV12:, PickupOptTypeV12
optNameV12 := Trim(optNameV12),optStatV12 := Trim(optStatV12),optTypeV12 := Trim(optTypeV12)
if (optNameV12="")
{
    GuiControl, PickupOptV12:, PickupOptStatusV12, Nhập tên đồ trước.
    return
}
optLineV12 := optTypeV12="" ? optNameV12 : Chr(34) . optNameV12 . Chr(34) . " " . optTypeV12
if (optStatV12!="")
    optLineV12 .= " " . ((SubStr(optStatV12,1,1)="{" || SubStr(optStatV12,1,1)="[") ? optStatV12 : "{" . optStatV12 . "}")
if (!IsObject(PickupOptParseV12(optLineV12,optErrorV12)))
{
    GuiControl, PickupOptV12:, PickupOptStatusV12, %optErrorV12%
    return
}
GuiControlGet, optDraftV12, PickupOptV12:, PickupOptTextV12
if (PickupEditorHasV10(optDraftV12,optLineV12))
    GuiControl, PickupOptV12:, PickupOptStatusV12, Đã có luật này (kể cả dòng #).
else
{
    GuiControl, PickupOptV12:, PickupOptTextV12, % RTrim(optDraftV12,"`r`n") . "`r`n" . optLineV12
    GuiControl, PickupOptV12:, PickupOptStatusV12, Đã thêm vào bản nháp; bấm LƯU để áp dụng.
}
return

PickupOptSaveV12:
GuiControlGet, optDraftV12, PickupOptV12:, PickupOptTextV12
GuiControl, 1:, PickupEditorInputV8, %optDraftV12%
if (!PickupSplitSaveV490())
{
    GuiControl, PickupOptV12:, PickupOptStatusV12, Chưa lưu được; kiểm tra dòng nhập trong danh sách chính.
    return
}
optCleanV12 := PickupEditorReadV8()
GuiControl, PickupOptV12:, PickupOptTextV12, %optCleanV12%
GuiControl, PickupOptV12:, PickupOptStatusV12, Đã lưu và cập nhật danh sách trái.
return

PickupOptExampleV12:
GuiControlGet, optDraftV12, PickupOptV12:, PickupOptTextV12
optDraftV12 := PickupEditorDedupV10(RTrim(optDraftV12,"`r`n") . "`r`n" . PickupOptExamplesV12(),optRemovedV12)
GuiControl, PickupOptV12:, PickupOptTextV12, %optDraftV12%
GuiControl, PickupOptV12:, PickupOptStatusV12, Đã thêm mẫu ở trạng thái # tắt; bỏ # từng dòng muốn dùng rồi LƯU.
return

PickupOptHelpV12:
MsgBox, 64, Cách nhập luật nhặt, % PickupOptHelpV12()
return

PickupOptV12GuiSize:
if (A_EventInfo!=1)
{
    GuiControl, PickupOptV12:Move, PickupOptTextV12, % "w" . (A_GuiWidth-24) . " h" . (A_GuiHeight-202)
    for _,controlV12 in ["PickupOptSaveButtonV12","PickupOptExampleButtonV12","PickupOptHelpButtonV12"]
        GuiControl, PickupOptV12:Move, %controlV12%, % "y" . (A_GuiHeight-71)
    GuiControl, PickupOptV12:Move, PickupOptStatusV12, % "y" . (A_GuiHeight-34) . " w" . (A_GuiWidth-24)
}
return

PickupOptV12GuiClose:
PickupOptV12GuiEscape:
Gui, PickupOptV12:Destroy
Gui, 1:Default
return

PickupGuideShowV8:
guideFileV64 := TxtRootPathV816("Huong-dan.txt")
if (!FileExist(guideFileV64))
    guideFileV64 := A_ScriptDir . "\Huong-dan"
if (!RareWarningReadTextV35(guideFileV64,guideTextV64,false))
{
    MsgBox, 48, Hướng dẫn, Không đọc được Huong-dan.txt. Đặt file hướng dẫn trong thư mục txt cạnh file AHK.
    return
}
Gui, PickupHelpV8:Destroy
Gui, PickupHelpV8:New, +Owner1 +Resize +MinSize400x300
Gui, PickupHelpV8:Font, s9, Segoe UI
Gui, PickupHelpV8:Add, Edit, x10 y10 w610 h520 Multi ReadOnly +Wrap +VScroll -HScroll vPickupHelpTextV8, %guideTextV64%
Gui, PickupHelpV8:Show, w630 h540, Hướng dẫn Auto-GSF
Gui, 1:Default
return

PickupHelpV8GuiSize:
if (A_EventInfo!=1)
    GuiControl, PickupHelpV8:Move, PickupHelpTextV8, % "w" . (A_GuiWidth-20) . " h" . (A_GuiHeight-20)
return

PickupHelpV8GuiClose:
Gui, PickupHelpV8:Destroy
Gui, 1:Default
return

ViewIdChangedV54:
GuiControlGet, viewIdV54,, ViewIdInputV54
viewIdV54 := viewIdV54 ? true : false
ToolTip,,,,2
SetTimer, AttackIdTipWatchV12, Off
viewIdSectionV54 := ProfileSection(currentProfile)
IniWrite, %viewIdV54%, % ProfileConfigPathV364(viewIdSectionV54), %viewIdSectionV54%, ViewID
lastTipV218 := "",lastTipPosV218 := ""
ToolTip,,,,20
ViewDisplayApplyV601()
if (viewIdV54)
    SetTimer, AttackIdTipWatchV12, 1000
else
{
    SetTimer, AttackIdTipWatchV12, Off
    ToolTip,,,, 2
}
if (viewIdV54 || viewPosV291)
    CoordCursorDisplayV132()
return

ViewPosChangedV291:
GuiControlGet, viewPosV291,, ViewPosInputV291
viewPosV291 := viewPosV291 ? true : false
ToolTip,,,,2
viewPosSectionV291 := ProfileSection(currentProfile)
IniWrite, %viewPosV291%, % ProfileConfigPathV364(viewPosSectionV291), %viewPosSectionV291%, ViewPos
lastTipV218 := "",lastTipPosV218 := ""
ToolTip,,,,20
ViewDisplayApplyV601()
if (viewIdV54 || viewPosV291)
    CoordCursorDisplayV132()
return

ViewTipChangedV640:
GuiControlGet, viewTipV640,, ViewTipInputV640
viewTipV640 := viewTipV640 ? true : false
viewTipSectionV640 := ProfileSection(currentProfile)
IniWrite, %viewTipV640%, % ProfileConfigPathV364(viewTipSectionV640), %viewTipSectionV640%, ViewTip
return

PetLearnEnabledChangedV12:
GuiControlGet, petLearnEnabledV12,, PetLearnEnabledInputV12
petLearnEnabledV12 := petLearnEnabledV12 ? true : false
if (IsObject(monsterChaseV44))
    monsterChaseV44.petCloseProbeV603 := false
petLearnSectionV12 := ProfileSection(currentProfile)
IniWrite, %petLearnEnabledV12%, % ProfileConfigPathV364(petLearnSectionV12), %petLearnSectionV12%, PetLearnEnabled
if (petLearnEnabledV12)
{
    ToolTipInfoV386("GET ID PET: BẬT — bấm phím GET để thêm Class vào DS loại trừ.")
    SetTimer, RemoveToolTip, -2500
}
else
{
    ToolTipInfoV386("GET ID PET: TẮT — phím GET không còn lấy pet.")
    SetTimer, RemoveToolTip, -2500
}
return
MonsterLockUntilDeadToggleV145:
GuiControlGet, monsterLockUntilDeadV145,, MonsterLockUntilDeadInputV145
monsterLockUntilDeadV145 := monsterLockUntilDeadV145 ? true : false
sectionV145 := ProfileSection(currentProfile)
IniWrite, %monsterLockUntilDeadV145%, % ProfileConfigPathV364(sectionV145), %sectionV145%, MonsterLockUntilDead
return

ApplyConfig:
if (xRunning)
    return
GuiControlGet, potCooldownDraftV730, 1:, PotCooldown
if (!RegExMatch(potCooldownDraftV730,"^\d+$") || potCooldownDraftV730<1)
{
    MsgBox, 48, Lỗi, Cooldown HP phải là số nguyên lớn hơn 0 (mili giây).
    return
}
GuiControlGet, petManualTextV10,, PetExcludeListV16
if (!PetExcludeCommitV10(petManualTextV10))
    return
GuiControlGet, bossManualV221,, BossPriorityListV221
if (!BossPriorityCommitV221(bossManualV221))
    return

GuiControlGet, ZRunKey,     1:, ZRunKey
GuiControlGet, ZSetKey,     1:, ZSetKey
GuiControlGet, ZSetDelay,   1:, ZSetDelay
GuiControlGet, ZKeyF1,      1:, ZKeyF1
GuiControlGet, ZDelay1,     1:, ZDelay1
GuiControlGet, ZKeyF2,      1:, ZKeyF2
GuiControlGet, ZDelay2,     1:, ZDelay2
GuiControlGet, XKey,        1:, XKey
GuiControlGet, XDelay,      1:, XDelay
GuiControlGet, QCastKey1,   1:, QCastKey1
GuiControlGet, QCastKey2,   1:, QCastKey2
GuiControlGet, QCastKey3,   1:, QCastKey3
GuiControlGet, QCastDelay1, 1:, QCastDelay1
GuiControlGet, QCastDelay2, 1:, QCastDelay2
GuiControlGet, QCastDelay3, 1:, QCastDelay3
GuiControlGet, RClickKey1,  1:, RClickKey1
GuiControlGet, RClickKey2,  1:, RClickKey2
GuiControlGet, RClickKey3,  1:, RClickKey3
GuiControlGet, RClickKey4,  1:, RClickKey4
GuiControlGet, RClickKey5,  1:, RClickKey5
GuiControlGet, RClickKey6,  1:, RClickKey6
GuiControlGet, RClickDelay1,1:, RClickDelay1
GuiControlGet, RClickDelay2,1:, RClickDelay2
GuiControlGet, RClickDelay3,1:, RClickDelay3
GuiControlGet, RClickDelay4,1:, RClickDelay4
GuiControlGet, RClickDelay5,1:, RClickDelay5
GuiControlGet, RClickDelay6,1:, RClickDelay6
GuiControlGet, QCastDoubleKey,   1:, QCastDoubleKey
GuiControlGet, QCastDoubleTapMs, 1:, QCastDoubleTapMs
GuiControlGet, ClickCastKeyInput,1:, ClickCastKeyInput
GuiControlGet, ClickCastMsInput, 1:, ClickCastMsInput
GuiControlGet, DoubleKey,        1:, DoubleKey
GuiControlGet, DoubleTapMs,      1:, DoubleTapMs
GuiControlGet, FormDoubleKey,    1:, FormDoubleKey
GuiControlGet, FormDoubleTapMs,  1:, FormDoubleTapMs
GuiControlGet, Master456KeyInput,1:, Master456KeyInput
GuiControlGet, AutoPotOn,       1:, AutoPotOn
GuiControlGet, PotMode,         1:, PotMode
GuiControlGet, PotHPThreshold,  1:, PotHPThreshold
GuiControlGet, PotHPThreshold2InputV299, 1:, PotHPThreshold2InputV299
GuiControlGet, InvHealOn,       1:, InvHealOn
GuiControlGet, CubeHealOn,      1:, CubeHealOn
GuiControlGet, InvManaOn,       1:, InvManaOn
GuiControlGet, CubeManaOn,      1:, CubeManaOn
GuiControlGet, ManaOn,          1:, ManaOn
GuiControlGet, ManaMode,        1:, ManaMode
GuiControlGet, ManaThreshold,   1:, ManaThreshold
GuiControlGet, ManaCooldown,    1:, ManaCooldown
GuiControlGet, Belt4HPKey,      1:, Belt4HPKey
GuiControlGet, Belt2HP2ManaKey, 1:, Belt2HP2ManaKey
GuiControlGet, InvToCubeKey,    1:, InvToCubeKey
GuiControlGet, CubePickupDelayInput,   1:, CubePickupDelayInput
GuiControlGet, CubeTransferDelayInput, 1:, CubeTransferDelayInput
GuiControlGet, PickupEnabledInputV79,   1:, PickupEnabledInputV79
GuiControlGet, PickupToggleKeyInputV79, 1:, PickupToggleKeyInputV79
GuiControlGet, PickupRadius,            1:, PickupRadius
GuiControlGet, PickupFailTeleRadiusInputV1253, 1:, PickupFailTeleRadiusInputV1253
GuiControlGet, PickupStashKeyInputV14,  1:, PickupStashKeyInputV14
GuiControlGet, PickupSetKeyInputV14,    1:, PickupSetKeyInputV14
GuiControlGet, PickupSUKeyInputV14,     1:, PickupSUKeyInputV14
GuiControlGet, SigKeyInputV147,         1:, SigKeyInputV147
GuiControlGet, SigSuKeyInputV181,       1:, SigSuKeyInputV181
GuiControlGet, ItemInspectKeyInputV287, 1:, ItemInspectKeyInputV287
GuiControlGet, SigTUInputV586,         1:, SigTUInputV586
GuiControlGet, SigSUInputV510,         1:, SigSUInputV510
GuiControlGet, SigSSUInputV13,          1:, SigSSUInputV13
GuiControlGet, RareWarningHideInputV19, 1:, RareWarningHideInputV19
GuiControlGet, ExcludeModeV329,         1:, ExcludeModeV329
GuiControlGet, ExcludeDeleteModeV332,   1:, ExcludeDeleteModeV332
GuiControlGet, MonsterRadiusInputV48,        1:, MonsterRadiusInputV48
GuiControlGet, FarmScanLimitInputV771,       1:, FarmScanLimitInputV771
GuiControlGet, MonsterLockUntilDeadInputV145,1:, MonsterLockUntilDeadInputV145
GuiControlGet, PortalCastInputV50,           1:, PortalCastInputV50
GuiControlGet, PortalCastEveryInputV52,      1:, PortalCastEveryInputV52
GuiControlGet, TeleportKeyInputV55,          1:, TeleportKeyInputV55
GuiControlGet, TeleportIntervalInputV56,     1:, TeleportIntervalInputV56
GuiControlGet, ChaseCheckInputV9,            1:, ChaseCheckInputV9
GuiControlGet, MapMoveDistanceInputV197,     1:, MapMoveDistanceInputV197
GuiControlGet, BOMoveMinimumInputV456,         1:, BOMoveMinimumInputV456

GuiControlGet, GoalDetourInputV14,           1:, GoalDetourInputV14
GuiControlGet, ViewIdInputV54,               1:, ViewIdInputV54
GuiControlGet, ViewPosInputV291,             1:, ViewPosInputV291
GuiControlGet, StateBuffKeyInputV17,         1:, StateBuffKeyInputV17
GuiControlGet, PestilenceKeyInputV18,        1:, PestilenceKeyInputV18
GuiControlGet, DeathlordStateInputV19,       1:, DeathlordStateInputV19
GuiControlGet, PestilenceStateInputV19,      1:, PestilenceStateInputV19
GuiControlGet, AnathemaStateInputV518, 1:, AnathemaStateInputV518
GuiControlGet, AnathemaKeyInputV518, 1:, AnathemaKeyInputV518
GuiControlGet, TownLevelInputV22,            1:, TownLevelInputV22
GuiControlGet, OutsideLevelInputV22,         1:, OutsideLevelInputV22
GuiControlGet, ContinuousMapInputV64,        1:, ContinuousMapInputV64
GuiControlGet, FarmResetWatchCheckV217,      1:, FarmResetWatchCheckV217
GuiControlGet, FarmResetWatchMinutesV217,    1:, FarmResetWatchMinutesV217
GuiControlGet, FarmEntrySigCheckV315,        1:, FarmEntrySigCheckV315
GuiControlGet, FarmEntryGoldCheckV347,       1:, FarmEntryGoldCheckV347
GuiControlGet, AutoLoadMapCheckV348,         1:, AutoLoadMapCheckV348
GuiControlGet, PetLearnKeyInputV13,          1:, PetLearnKeyInputV13
Gui, Submit, NoHide
GuiControlGet, viewTipV640, 1:, ViewTipInputV640
viewTipV640 := viewTipV640 ? true : false

healExhausted := {HP: {Cube: false, Ruong: false, Belt: false}
    , Mana: {Cube: false, Ruong: false, Belt: false}}
oldXKeyBeforeSubmit := xKey
oldZKeyBeforeSubmit := zKey
oldBelt4HPKeyBeforeSubmit := belt4HPKey
oldBelt2HP2ManaKeyBeforeSubmit := belt2HP2ManaKey
oldInvToCubeKeyBeforeSubmit := invToCubeKey
configApplyOK := false

GuiControlGet, QCastKey1,, QCastKey1
GuiControlGet, QCastKey2,, QCastKey2
GuiControlGet, QCastKey3,, QCastKey3
GuiControlGet, QCastDelay1,, QCastDelay1
GuiControlGet, QCastDelay2,, QCastDelay2
GuiControlGet, QCastDelay3,, QCastDelay3
Gui, Submit, NoHide

newAutoMonsterKeyV13 := NormalizeMapHotkeyV178(autoMonsterToggleKeyV13)
newPetLearnKeyV13 := NormalizeOptionalKey(PetLearnKeyInputV13)
newCoordGetKeyV14 := ""
if (!FarmNaoKeySaveV181())
    return
FarmEntrySettingsSaveV578()
if (!MonsterKeysValidateV13(newAutoMonsterKeyV13,newPetLearnKeyV13,newCoordGetKeyV14))
    return

newMaster456Key := NormalizeOptionalKey(Master456KeyInput)
if (newMaster456Key != "" && !GetKeyVK(newMaster456Key) && !GetKeySC(newMaster456Key))
    newMaster456Key := ""
for _, usedToggleKey in [DoubleKey, FormDoubleKey, QCastDoubleKey, ClickCastKeyInput, XKey, ZRunKey, Belt4HPKey, Belt2HP2ManaKey, InvToCubeKey]
{
    if (newMaster456Key != "" && CastKeysMatch(newMaster456Key, usedToggleKey))
    {
        newMaster456Key := ""
        break
    }
}

newClickRows := []
Loop, 6
{
    i := A_Index
    GuiControlGet, newClickKey,, RClickKey%i%
    GuiControlGet, newClickDelay,, RClickDelay%i%
    newClickKey := NormalizeOptionalKey(newClickKey)
    if newClickDelay is not integer
    {
        MsgBox, 48, Lỗi, Delay Click dòng %i% phải là số nguyên.
        return
    }
    if (newClickDelay < 0)
    {
        MsgBox, 48, Lỗi, Delay Click dòng %i% không được âm.
        return
    }
    if (newClickKey != "" && !GetKeyVK(newClickKey) && !GetKeySC(newClickKey))
    {
        MsgBox, 48, Lỗi, Phím Click dòng %i% không hợp lệ.
        return
    }
    newClickRows.Push({key: newClickKey, delay: newClickDelay + 0, last: A_TickCount})
}
if (!InStr("|None|Left|Right|Up|Down|Home|End|PgUp|PgDn|", "|" . ClickCastKeyInput . "|"))
{
    MsgBox, 48, Lỗi, Phím Double Tap Click không hợp lệ.
    return
}
if ClickCastMsInput is not integer
{
    MsgBox, 48, Lỗi, Khoảng cách Double Tap Click phải là số nguyên.
    return
}
if (ClickCastMsInput < 50)
{
    MsgBox, 48, Lỗi, Khoảng cách Double Tap Click tối thiểu là 50 ms.
    return
}
if (ClickCastKeyInput!="None" && (ClickCastKeyInput = DoubleKey || ClickCastKeyInput = FormDoubleKey || ClickCastKeyInput = QCastDoubleKey))
{
    MsgBox, 48, Lỗi, Phím Double Tap Click không được trùng ba phím Double Tap còn lại.
    return
}


if CubePickupDelayInput is not integer
{
    MsgBox, 48, Lỗi, Delay nhấc bình Rương→Cube phải là số nguyên (ms).
    return
}
if (CubePickupDelayInput < 10 || CubePickupDelayInput > 5000)
{
    MsgBox, 48, Lỗi, Delay nhấc bình Rương→Cube phải từ 10 đến 5000 ms.
    return
}
if CubeTransferDelayInput is not integer
{
    MsgBox, 48, Lỗi, Delay Rương→Cube phải là số nguyên (ms).
    return
}
if (CubeTransferDelayInput < 10 || CubeTransferDelayInput > 5000)
{
    MsgBox, 48, Lỗi, Delay Rương→Cube phải từ 10 đến 5000 ms.
    return
}
cubePickupDelayMs := CubePickupDelayInput + 0
cubeTransferDelayMs := CubeTransferDelayInput + 0

pickupRadius := PickupRadius + 0
if (pickupRadius < 1)
    pickupRadius := 1
if (!RegExMatch(PickupFailTeleRadiusInputV1253,"^\d+$") || PickupFailTeleRadiusInputV1253<1 || PickupFailTeleRadiusInputV1253>100)
{
    MsgBox, 48, Lỗi, BK teleport khi nhặt lỗi phải từ 1 đến 100 ô.
    return
}
pickupFailTeleRadiusV1253 := PickupFailTeleRadiusInputV1253+0
pickupLastClick := 0
newPickupToggleV79 := NormalizeOptionalKey(PickupToggleKeyInputV79)
if (newPickupToggleV79!="")
{
    for _,pickupOtherKeyV79 in [ZRunKey,XKey,DoubleKey,FormDoubleKey,QCastDoubleKey,CoordGetKeyInputV14,PetLearnKeyInputV13,InvToCubeKey,Belt4HPKey,Belt2HP2ManaKey,ClickCastKeyInput,Master456KeyInput]
    {
        if (newPickupToggleV79=NormalizeOptionalKey(pickupOtherKeyV79))
        {
            newPickupToggleV79 := ""
            break
        }
    }
}
pickupToggleKeyV79 := newPickupToggleV79
PickupToggleBindV79()
if (!SigKeySaveV147() || !SigSuKeySaveV181())
    return
Gosub, SigTierChangedV13
newRareWarningKeyV1 := ""
Gosub, RareWarningHideChangedV19
newGetIdKey := ""
newDeleteIdKey := ""
getIdKey := ""
deleteIdKey := ""
rareWarningKeyV1 := newRareWarningKeyV1
if (rareWarningKeyV1 != "")
    BackgroundHotkeyV63("~$" . rareWarningKeyV1,"RareWarningGetHandlerV1","On")
deleteIdKey := newDeleteIdKey

FKey9 := ""
FKey10 := ""
FDelay9 := 0
FDelay10 := 0
Loop, 5
{
    index := A_Index
    FKey%index% := NormalizeOptionalKey(FKey%index%)
}

configApplyOK := false

zKey := NormalizeOptionalKey(ZRunKey)
zSetKey := NormalizeOptionalKey(ZSetKey)
zSetDelay := ZSetDelay
zFKey := NormalizeOptionalKey(ZKeyF1)
zFKey2 := NormalizeOptionalKey(ZKeyF2)
XKey := NormalizeOptionalKey(XKey)
Loop, 3
{
    i := A_Index
    QCastKey%i% := NormalizeOptionalKey(QCastKey%i%)
}
Loop, 3
{
    i := A_Index
    qDelayCheck := QCastDelay%i%
    if qDelayCheck is not integer
        QCastDelay%i% := 0
    else if (qDelayCheck < 0)
        QCastDelay%i% := 0
}
forIndex := 0
Loop, 3
{
    i := A_Index
    checkDelay := (i = 1) ? zSetDelay : ((i = 2) ? zDelay1 : zDelay2)
    if checkDelay is not integer
    {
        MsgBox, 48, Lỗi, Delay Buff Set Phụ phải là số nguyên.
        return
    }
    if (checkDelay < 0)
    {
        MsgBox, 48, Lỗi, Delay Buff Set Phụ không được âm.
        return
    }
}
if XDelay is not integer
    XDelay := 200
if (XDelay < 0)
    XDelay := 200

if (XKey != "" && zKey = XKey)
{
    return
}

if (oldZKeyBeforeSubmit != "")
    BackgroundHotkeyV63("~$" . oldZKeyBeforeSubmit,"ZKeyHandler","Off")

if (zKey != "")
    BackgroundHotkeyV63("~$" . zKey,"ZKeyHandler","On")

oldXKey := oldXKeyBeforeSubmit

if (oldXKey != "")
{
    BackgroundHotkeyV63("~$" . oldXKey,"XKeyHandler","Off")
}

xKey := XKey

if (xKey != "")
        BackgroundHotkeyV63("~$" . xKey,"XKeyHandler","On")

if (DoubleKey != "None"
&& DoubleKey != "Left"
&& DoubleKey != "Right"
&& DoubleKey != "Up"
&& DoubleKey != "Down"
&& DoubleKey != "Home"
&& DoubleKey != "End"
&& DoubleKey != "PgUp"
&& DoubleKey != "PgDn")
{
    MsgBox, 48, Lỗi, Phím Double Tap Auto không hợp lệ.
    return
}

if (FormDoubleKey != "None"
&& FormDoubleKey != "Left"
&& FormDoubleKey != "Right"
&& FormDoubleKey != "Up"
&& FormDoubleKey != "Down"
&& FormDoubleKey != "Home"
&& FormDoubleKey != "End"
&& FormDoubleKey != "PgUp"
&& FormDoubleKey != "PgDn")
{
    MsgBox, 48, Lỗi, Phím Double Tap mở / đóng Form không hợp lệ.
    return
}

if (QCastDoubleKey != "None"
&& QCastDoubleKey != "Left"
&& QCastDoubleKey != "Right"
&& QCastDoubleKey != "Up"
&& QCastDoubleKey != "Down"
&& QCastDoubleKey != "Home"
&& QCastDoubleKey != "End"
&& QCastDoubleKey != "PgUp"
&& QCastDoubleKey != "PgDn")
{
    MsgBox, 48, Lỗi, Phím Double Tap Q Cast không hợp lệ.
    return
}

if QCastDoubleTapMs is not integer
{
    MsgBox, 48, Lỗi, Khoảng cách Double Tap Q Cast phải là số nguyên.
    return
}

if (QCastDoubleTapMs < 50)
{
    MsgBox, 48, Lỗi, Khoảng cách Double Tap Q Cast tối thiểu là 50 ms.
    return
}

Loop, 5
{
    index := A_Index
    delay := FDelay%index%
    if delay is not integer
        FDelay%index% := 200
    else if (delay < 0)
        FDelay%index% := 200
}

Loop, 3
{
    qIndex := A_Index
    qKey := QCastKey%qIndex%
    if (qKey != "" && StrLen(qKey) > 20)
    {
        MsgBox, 48, Lỗi, Phím Cast dòng %qIndex% không hợp lệ.
        return
    }
}

foundBlank := false

Loop, 5
{
    index := A_Index
    key := FKey%index%

    if (key = "")
    {
        foundBlank := true
    }
    else
    {
        if (foundBlank)
        {
            MsgBox, 48, Lỗi, Cycle 1 không được bỏ trống ở giữa.`nHãy sắp xếp các phím liên tục từ trên xuống.
            return
        }
    }
}

if DoubleTapMs is not integer
{
    MsgBox, 48, Lỗi, Khoảng cách Double Tap Auto phải là số nguyên.
    return
}

if (DoubleTapMs < 50)
{
    MsgBox, 48, Lỗi, Khoảng cách Double Tap Auto tối thiểu là 50 ms.
    return
}

if FormDoubleTapMs is not integer
{
    MsgBox, 48, Lỗi, Khoảng cách Double Tap Form phải là số nguyên.
    return
}

if (FormDoubleTapMs < 50)
{
    MsgBox, 48, Lỗi, Khoảng cách Double Tap Form tối thiểu là 50 ms.
    return
}

oldDoubleKey := doubleKey

if (oldDoubleKey != "")
{
    ToolDoubleBindV18(oldDoubleKey,"DoubleKeyHandler","Off")
}

doubleKey := DoubleKey
doubleTapMs := DoubleTapMs
lastDoubleKeyTime := 0
doubleKeyHeld := false
SetTimer, DoubleKeyReleaseWatch, Off

ToolDoubleBindV18(doubleKey,"DoubleKeyHandler","On")

oldFormDoubleKey := formDoubleKey

if (oldFormDoubleKey != "")
{
    ToolDoubleBindV18(oldFormDoubleKey,"FormDoubleKeyHandler","Off")
}

formDoubleKey := FormDoubleKey
formDoubleTapMs := FormDoubleTapMs
lastFormDoubleKeyTime := 0
formDoubleKeyHeld := false
SetTimer, FormDoubleKeyReleaseWatch, Off

ToolDoubleBindV18(formDoubleKey,"FormDoubleKeyHandler","On")

oldQCastDoubleKey := qCastDoubleKey
if (oldQCastDoubleKey != "")
    ToolDoubleBindV18(oldQCastDoubleKey,"QCastDoubleKeyHandler","Off")

qCastDoubleKey := "None"
qCastDoubleTapMs := QCastDoubleTapMs
lastQCastDoubleKeyTime := 0
qCastDoubleKeyHeld := false
SetTimer, QCastDoubleKeyReleaseWatch, Off
ToolDoubleBindV18(qCastDoubleKey,"QCastDoubleKeyHandler","On")


newTeleportKeyV55 := PortalCastNormalizeV50(TeleportKeyInputV55)
if (newTeleportKeyV55!="" && !GetKeyVK(newTeleportKeyV55) && !GetKeySC(newTeleportKeyV55))
{
    MsgBox, 48, Lỗi, Phím cast khi kẹt không hợp lệ. None để tắt.
    return
}
if TeleportIntervalInputV56 is not integer
{
    MsgBox, 48, Lỗi, Khoảng cách teleport phải là số nguyên từ 1 đến 3600 giây.
    return
}
if (TeleportIntervalInputV56<1 || TeleportIntervalInputV56>3600)
{
    MsgBox, 48, Lỗi, Khoảng cách teleport phải từ 1 đến 3600 giây.
    return
}
if (!RegExMatch(ChaseCheckInputV9, "^\d+$") || ChaseCheckInputV9<1 || ChaseCheckInputV9>3600)
{
    MsgBox, 48, Lỗi, Thời gian xét kẹt/đánh hụt phải từ 1 đến 3600 giây.
    return
}
if (!RegExMatch(MapMoveDistanceInputV197,"^\d+$") || MapMoveDistanceInputV197<1 || MapMoveDistanceInputV197>200)
{
    MsgBox, 48, Lỗi, Khoảng di chuyển phải từ 1 đến 200 đơn vị tọa độ.
    return
}

if (!RegExMatch(GoalDetourInputV14, "^\d+$") || GoalDetourInputV14<0 || GoalDetourInputV14>200)
{
    MsgBox, 48, Lỗi, Khoảng cách cho phép xa đích phải từ 0 đến 200.
    return
}
newStateBuffKeyV17 := PortalCastNormalizeV50(StateBuffKeyInputV17)
if (newStateBuffKeyV17!="" && !GetKeyVK(newStateBuffKeyV17) && !GetKeySC(newStateBuffKeyV17))
{
    MsgBox, 48, Lỗi, Phím Auto Buff không hợp lệ.
    return
}
newPestilenceKeyV18 := PortalCastNormalizeV50(PestilenceKeyInputV18)
if (newPestilenceKeyV18!="" && !GetKeyVK(newPestilenceKeyV18) && !GetKeySC(newPestilenceKeyV18))
{
    MsgBox, 48, Lỗi, Phím Pinnacle không hợp lệ.
    return
}
newAnathemaKeyV518 := PortalCastNormalizeV50(AnathemaKeyInputV518)
if (newAnathemaKeyV518!="" && !GetKeyVK(newAnathemaKeyV518) && !GetKeySC(newAnathemaKeyV518))
{
    MsgBox, 48, Lỗi, Phím Anathema không hợp lệ.
    return
}
if (AnathemaStateInputV518!="" && (!RegExMatch(AnathemaStateInputV518,"^\d+$") || AnathemaStateInputV518>4095))
{
    MsgBox, 48, Lỗi, ID Anathema phải từ 0 đến 4095 hoặc để trống.
    return
}
anathemaKeyV518 := newAnathemaKeyV518
anathemaStateV518 := Trim(AnathemaStateInputV518)
pestilenceKeyV18 := newPestilenceKeyV18
if (KnownFarmLevelV522(TownLevelInputV22))
{
    MsgBox, 48, ID thành không đúng, % "ID " . TownLevelInputV22 . " là map farm. Hãy GET ID khi nhân vật đang ở trong thành."
    return
}
townLevelV22 := TownLevelInputV22
outsideLevelV22 := OutsideLevelInputV22
GuiControlGet, buffGetTextV22,, BuffGetResultV19
deathlordStateV19 := DeathlordStateInputV19
pestilenceStateV19 := PestilenceStateInputV19
stateBuffKeyV17 := newStateBuffKeyV17
stateBuffCheckSecV17 := 3
mapMoveDistanceV197 := MapMoveDistanceInputV197+0
if (RegExMatch(BOMoveMinimumInputV456,"^\d+$") && BOMoveMinimumInputV456>=1)
    boMoveMinimumV456 := Max(5,BOMoveMinimumInputV456+0)
goalDetourV14 := Round(GoalDetourInputV14)
monsterLockUntilDeadV145 := MonsterLockUntilDeadInputV145 ? true : false

if RegExMatch("" . MonsterLockNoDamageSecInputV621, "^\d+$")
    monsterLockNoDamageSecV621 := Max(0, Min(3600, MonsterLockNoDamageSecInputV621 + 0))
if RegExMatch("" . MonsterLockRoomSecInputV622, "^\d+$")
    monsterLockRoomSecV622 := Max(1, Min(3600, MonsterLockRoomSecInputV622 + 0))
if (!RegExMatch(MonsterSkipDistanceInputV752,"^\d+$") || MonsterSkipDistanceInputV752>200)
{
    MsgBox, 48, Lỗi, BK Lock: nhập khoảng cách 0–200. Số 0 tự lấy nửa BK đánh.
    return
}
monsterSkipDistanceV752 := MonsterSkipDistanceInputV752+0
sigSSSUV13 := false

chaseCheckSecV9 := ChaseCheckInputV9
ChaseMissResetV6()
teleportIntervalSecV56 := TeleportIntervalInputV56
teleportKeyV55 := newTeleportKeyV55
castKeyV50 := PortalCastNormalizeV50(PortalCastInputV50)
if (castKeyV50!="" && !GetKeyVK(castKeyV50) && !GetKeySC(castKeyV50))
{
    MsgBox, 48, Lỗi, Phím cast không hợp lệ. M3 là chuột giữa; None để tắt.
    return
}
if PortalCastEveryInputV52 is not integer
{
    MsgBox, 48, Lỗi, Số tọa độ mở về thành phải là số nguyên từ 1 đến 999.
    return
}
if (PortalCastEveryInputV52<1 || PortalCastEveryInputV52>999)
{
    MsgBox, 48, Lỗi, Số tọa độ mở về thành phải từ 1 đến 999.
    return
}
portalCastEveryV52 := PortalCastEveryInputV52
portalCastKeyV50 := castKeyV50
if MonsterRadiusInputV48 is not integer
{
    MsgBox, 48, Lỗi, Bán kính đánh phải là số nguyên từ 1 đến 200 đơn vị map.
    return
}
if (MonsterRadiusInputV48<1 || MonsterRadiusInputV48>200)
{
    MsgBox, 48, Lỗi, Bán kính đánh phải từ 1 đến 200 đơn vị map.
    return
}
monsterRadiusV48 := MonsterRadiusInputV48
if FarmScanLimitInputV771 is not integer
{
    MsgBox, 48, Lỗi, Số Quét phải là số nguyên từ 1 đến 999.
    return
}
if (FarmScanLimitInputV771<1 || FarmScanLimitInputV771>999)
{
    MsgBox, 48, Lỗi, Số Quét phải từ 1 đến 999.
    return
}
farmScanLimitV771 := FarmScanLimitInputV771+0
if PotHPThreshold is not integer
{
    MsgBox, 48, Lỗi, Ngưỡng HP phải là số nguyên.
    return
}
if (PotHPThreshold < 1)
{
    MsgBox, 48, Lỗi, Ngưỡng HP phải lớn hơn 0.
    return
}
if PotHPThreshold2InputV299 is not integer
{
    MsgBox, 48, Lỗi, Ngưỡng HP 2 phải là số nguyên.
    return
}
if (PotHPThreshold2InputV299<1 || PotHPThreshold2InputV299>=PotHPThreshold)
{
    MsgBox, 48, Lỗi, Ngưỡng HP 2 phải lớn hơn 0 và nhỏ hơn ngưỡng HP 1.
    return
}
potHPThreshold := PotHPThreshold
potHPThreshold2V299 := PotHPThreshold2InputV299
potMode := PotMode
autoPotOn := AutoPotOn
invHealOn := InvHealOn
invManaOn := InvManaOn
cubeHealOn := CubeHealOn
cubeManaOn := CubeManaOn
newInvToCubeKey := NormalizeOptionalKey(InvToCubeKey)
newBelt4HPKey := NormalizeOptionalKey(Belt4HPKey)
newBelt2HP2ManaKey := NormalizeOptionalKey(Belt2HP2ManaKey)

if (oldBelt4HPKeyBeforeSubmit != "" && oldBelt4HPKeyBeforeSubmit != "None")
    BackgroundHotkeyV63("~$" . oldBelt4HPKeyBeforeSubmit,"Belt4HPHandler","Off")
if (oldBelt2HP2ManaKeyBeforeSubmit != "" && oldBelt2HP2ManaKeyBeforeSubmit != "None")
    BackgroundHotkeyV63("~$" . oldBelt2HP2ManaKeyBeforeSubmit,"Belt2HP2ManaHandler","Off")

belt4HPKey := newBelt4HPKey
belt2HP2ManaKey := newBelt2HP2ManaKey
if (oldInvToCubeKeyBeforeSubmit != "" && oldInvToCubeKeyBeforeSubmit != "None")
    BackgroundHotkeyV63("~$" . oldInvToCubeKeyBeforeSubmit,"InvToCubeHandler","Off")
invToCubeKey := newInvToCubeKey
if (invToCubeKey != "")
    BackgroundHotkeyV63("~$" . invToCubeKey,"InvToCubeHandler","On")

if (belt4HPKey != "")
    BackgroundHotkeyV63("~$" . belt4HPKey,"Belt4HPHandler","On")
if (belt2HP2ManaKey != "")
    BackgroundHotkeyV63("~$" . belt2HP2ManaKey,"Belt2HP2ManaHandler","On")

potCooldown := potCooldownDraftV730+0

if ManaThreshold is not integer
{
    MsgBox, 48, Lỗi, Ngưỡng Mana phải là số nguyên.
    return
}
if (ManaThreshold < 1)
{
    MsgBox, 48, Lỗi, Ngưỡng Mana phải lớn hơn 0.
    return
}
manaOn := ManaOn
manaMode := ManaMode
manaThreshold := ManaThreshold
manaCooldown := ManaCooldown

cycleStep := 1
nextStepTime := 0

qCastLast1 := A_TickCount
qCastLast2 := A_TickCount
qCastLast3 := A_TickCount

ToolDoubleBindV18(clickCastDoubleKey,"ClickCastDoubleHandler","Off")
clickCastDoubleKey := "None"
clickCastDoubleTapMs := ClickCastMsInput + 0
lastClickCastTap := 0
clickCastHeld := false
SetTimer, ClickCastReleaseWatch, Off
clickCastRows := newClickRows
ToolDoubleBindV18(clickCastDoubleKey,"ClickCastDoubleHandler","On")
ClearExtraFRows()
if (master456Key != "")
    BackgroundHotkeyV63("~$" . master456Key,"Master456Handler","Off UseErrorLevel")
master456Key := "None"
if (master456Key != "")
    BackgroundHotkeyV63("~$" . master456Key,"Master456Handler","On")
autoMonsterToggleKeyV13 := newAutoMonsterKeyV13
petLearnKeyV13 := newPetLearnKeyV13
coordGetKeyV14 := newCoordGetKeyV14
AutoMonsterAttackApplyStateV4()
configApplyOK := true

return

SaveConfig:
if (!PickupSplitSaveV490())
    return
RecoveryLoginSettingsSaveV489()
GuiControlGet, ZKeyF2,, ZKeyF2
GuiControlGet, QCastKey1,, QCastKey1
GuiControlGet, QCastKey2,, QCastKey2
GuiControlGet, QCastKey3,, QCastKey3
GuiControlGet, QCastDelay1,, QCastDelay1
GuiControlGet, QCastDelay2,, QCastDelay2
GuiControlGet, QCastDelay3,, QCastDelay3

GuiControlGet, farmResetWatchEnabledV217, 1:, FarmResetWatchCheckV217
GuiControlGet, farmResetWatchMinutesV217, 1:, FarmResetWatchMinutesV217
GuiControlGet, continuousMapV168, 1:, ContinuousMapInputV64
GuiControlGet, autoLoadMapV340, 1:, AutoLoadMapCheckV348
GuiControlGet, farmEntrySigV315, 1:, FarmEntrySigCheckV315
GuiControlGet, farmEntryGoldV315, 1:, FarmEntryGoldCheckV347
if farmResetWatchMinutesV217 is not integer
    farmResetWatchMinutesV217 := 1
farmResetWatchMinutesV217 := Max(1, Min(60, farmResetWatchMinutesV217))
farmResetWatchEnabledV217 := farmResetWatchEnabledV217 ? true : false
continuousMapV168 := continuousMapV168 ? true : false
autoLoadMapV340 := autoLoadMapV340 ? true : false
farmEntrySigV315 := farmEntrySigV315 ? true : false
farmEntryGoldV315 := farmEntryGoldV315 ? true : false

Gosub, ApplyConfig
if (!configApplyOK)
    return

SaveAllConfig()
if (!SaveProfile(currentProfile))
{
    MsgBox, 48, Lỗi, % "Chưa lưu được file profile: " . ProfileFile(currentProfile)
    return
}

delaySaveSection := ProfileSection(currentProfile)
IniWrite, %cubePickupDelayMs%, % ProfileConfigPathV364(delaySaveSection), %delaySaveSection%, CubePickupDelayMs
IniWrite, %cubeTransferDelayMs%, % ProfileConfigPathV364(delaySaveSection), %delaySaveSection%, CubeTransferDelayMs

kill2GeneralSave := (zFKey2 = "" ? "None" : zFKey2)
IniWrite, %kill2GeneralSave%, %ConfigFile%, Z, FKey2
kill2Section := ProfileSection(currentProfile)
kill2SaveValue := (zFKey2 = "" ? "None" : zFKey2)
IniWrite, %kill2SaveValue%, % ProfileConfigPathV364(kill2Section), %kill2Section%, ZFKey2

IniWrite, % farmResetWatchEnabledV217 ? 1 : 0, % ProfileConfigPathV364(kill2Section), %kill2Section%, FarmBrainResetWatch
IniWrite, %farmResetWatchMinutesV217%, % ProfileConfigPathV364(kill2Section), %kill2Section%, FarmBrainResetMinutes
IniWrite, % continuousMapV168 ? 1 : 0, % ProfileConfigPathV364(kill2Section), %kill2Section%, ContinuousMap
IniWrite, % autoLoadMapV340 ? 1 : 0, % ProfileConfigPathV364(kill2Section), %kill2Section%, AutoLoadMap
IniWrite, % farmEntrySigV315 ? 1 : 0, % ProfileConfigPathV364(kill2Section), %kill2Section%, FarmEntrySig
IniWrite, % farmEntryGoldV315 ? 1 : 0, % ProfileConfigPathV364(kill2Section), %kill2Section%, FarmEntryGold

ToolTipInfoV386("Đã lưu cấu hình")
SetTimer, RemoveToolTip, -2000
return

ProfileLiveMapReloadV523:
if (guiBuilding)
{
    SetTimer, ProfileLiveMapReloadV523, -100
    return
}
if (xRunning || zRunning || sigBusyV147 || packetWatchArmedV1 || gameItemActionOwner!=""
    || fonLoadBusyV410 || IsObject(roomRecordV108))
{
    SetTimer, ProfileLiveMapReloadV523, -100
    return
}
profileLivePidV523 := CoordDisplayGamePidV1()
profileLiveLevelV523 := profileLivePidV523 ? RoomRecordLevelV259(profileLivePidV523) : 0
if (!profileLiveLevelV523)
    return
profileLiveNameV523 := currentProfile
profileLiveLoadedV523 := FonLoadMapV382("PROFILE_CHANGE_LIVE",profileLivePidV523,profileLiveLevelV523)
if (profileLiveNameV523=currentProfile && profileLiveLoadedV523)
{
    RouteMapRefreshV21()
    CoordBoxRefreshV15(true)
}
PortalLogWriteV66("PROFILE_LIVE_MAP profile=" . profileLiveNameV523 . " pid=" . profileLivePidV523
    . " level=" . profileLiveLevelV523 . " loaded=" . profileLiveLoadedV523 . " farm_started=0")
return

LoadProfileFromGui:
if (xRunning)
{
    GuiControl, ChooseString, ProfileSelect, %currentProfile%
    ToolTipInfoV386("Đang chạy Buff — không đổi Profile.")
    SetTimer, RemoveToolTip, -2500
    return
}
if (IsObject(roomRecordV108))
{
    GuiControl, ChooseString, ProfileSelect, %currentProfile%
    ToolTipInfoV386("Dừng lưu phòng hoặc ghi chèn trước khi đổi profile.")
    SetTimer, RemoveToolTip, -2500
    return
}

GuiControlGet, requestedProfileV366, 1:, ProfileSelect
requestedProfileV366 := Trim(requestedProfileV366)
if (requestedProfileV366 = "")
    return
if (requestedProfileV366!="Default" && !ProfileStoredV520(requestedProfileV366))
{
    RemoveProfileName(requestedProfileV366)
    ProfileDiscoverFilesV366()
    GuiControl, 1:, ProfileSelect, |%profileList%
    GuiControl, 1:ChooseString, ProfileSelect, %currentProfile%
    ToolTipInfoV386("Đã bỏ profile không còn file: " . requestedProfileV366)
    SetTimer, RemoveToolTip, -3000
    return
}
SaveProfile(currentProfile)
if (!LoadProfile(requestedProfileV366))
{
    GuiControl, 1:ChooseString, ProfileSelect, %currentProfile%
    ToolTipInfoV386("Không tải được profile: " . requestedProfileV366 . "`nFile: " . ProfileFile(requestedProfileV366))
    SetTimer, RemoveToolTip, -5000
    return
}
RefreshClickCastControls()
IniWrite, %currentProfile%, %ConfigFile%, Profiles, Current
IniWrite, %currentProfile%, %ConfigFile%, Settings, LastProfile

Loop, 5
{
    index := A_Index
    currentKey := FKey%index%
    currentDelay := FDelay%index%
    if (currentKey = "")
        currentKey := "None"
    GuiControl,, FKey%index%, % MouseKeyDisplayV616(currentKey)
    GuiControl,, FDelay%index%, %currentDelay%
}
Loop, 3
{
    qIndex := A_Index
    qCurrentKey := QCastKey%qIndex%
    qCurrentDelay := QCastDelay%qIndex%
    if (qCurrentKey = "")
        qCurrentKey := "None"
    GuiControl,, QCastKey%qIndex%, % MouseKeyDisplayV616(qCurrentKey)
    GuiControl,, QCastDelay%qIndex%, %qCurrentDelay%
}
GuiControl,, XKey, % MouseKeyDisplayV616(xKey)
GuiControl,, XDelay, %xDelay%
zRunShow := (zKey = "" ? "None" : zKey)
GuiControl,, ZRunKey, % MouseKeyDisplayV616(zRunShow)
GuiControl,, ZSetKey, % MouseKeyDisplayV616(zSetKey)
GuiControl,, ZSetDelay, %zSetDelay%
zShowF1 := zFKey
zShowF2 := (zFKey2 = "" ? "None" : zFKey2)
GuiControl,, ZKeyF1, % MouseKeyDisplayV616(zShowF1)
GuiControl,, ZKeyF2, % MouseKeyDisplayV616(zShowF2)
GuiControl,, ZDelay1, %zDelay1%
GuiControl,, ZDelay2, %zDelay2%
GuiControl, ChooseString, DoubleKey, %doubleKey%
GuiControl,, DoubleTapMs, %doubleTapMs%
GuiControl, ChooseString, FormDoubleKey, %formDoubleKey%
GuiControl,, FormDoubleTapMs, %formDoubleTapMs%
GuiControl, ChooseString, ProfileSelect, %currentProfile%
GuiControl,, NewProfileName, %currentProfile%
GuiControl, % autoPotOn ? "+Checked" : "-Checked", AutoPotOn
GuiControl, % invHealOn ? "+Checked" : "-Checked", InvHealOn
GuiControl, % cubeHealOn ? "+Checked" : "-Checked", CubeHealOn
GuiControl, % invManaOn ? "+Checked" : "-Checked", InvManaOn
GuiControl, % cubeManaOn ? "+Checked" : "-Checked", CubeManaOn
GuiControl,, InvToCubeKey, % MouseKeyDisplayV616(invToCubeKey)
GuiControl,, CubePickupDelayInput, %cubePickupDelayMs%
GuiControl,, CubeTransferDelayInput, %cubeTransferDelayMs%
GuiControl,, Belt4HPKey, % MouseKeyDisplayV616(belt4HPKey)
GuiControl,, Belt2HP2ManaKey, % MouseKeyDisplayV616(belt2HP2ManaKey)
GuiControl, ChooseString, PotMode, %potMode%
GuiControl,, PortalCastInputV50, % portalCastKeyV50="MButton" ? "M3" : portalCastKeyV50="" ? "None" : portalCastKeyV50
GuiControl,, MonsterRadiusInputV48, %monsterRadiusV48%
GuiControl,, FarmScanLimitInputV771, %farmScanLimitV771%
GuiControl,, PortalCastEveryInputV52, %portalCastEveryV52%
GuiControl,, TeleportKeyInputV55, % teleportKeyV55="" ? "None" : teleportKeyV55="MButton" ? "M3" : teleportKeyV55
GuiControl,, TeleportIntervalInputV56, %teleportIntervalSecV56%
GuiControl,, ChaseCheckInputV9, %chaseCheckSecV9%
GuiControl,, MapMoveDistanceInputV197, %mapMoveDistanceV197%
GuiControl,, BOMoveMinimumInputV456, %boMoveMinimumV456%

GuiControl,, GoalDetourInputV14, %goalDetourV14%
GuiControl,, MonsterLockUntilDeadInputV145, %monsterLockUntilDeadV145%
GuiControl,, ViewIdInputV54, %viewIdV54%
GuiControl,, ViewPosInputV291, %viewPosV291%
GuiControl,, StateBuffKeyInputV17, % MouseKeyDisplayV616(stateBuffKeyV17="" ? "None" : stateBuffKeyV17)
GuiControl,, PestilenceKeyInputV18, % MouseKeyDisplayV616(pestilenceKeyV18="" ? "None" : pestilenceKeyV18)
GuiControl,, DeathlordStateInputV19, %deathlordStateV19%
GuiControl,, PestilenceStateInputV19, %pestilenceStateV19%
GuiControl,, AnathemaStateInputV518, %anathemaStateV518%
GuiControl,, AnathemaKeyInputV518, % MouseKeyDisplayV616(anathemaKeyV518="" ? "None" : anathemaKeyV518)
GuiControl,, TownLevelInputV22, %townLevelV22%
GuiControl,, OutsideLevelInputV22, %outsideLevelV22%
GuiControl,, BuffGetResultV19, %buffGetTextV22%
GuiControl,, PotHPThreshold, %potHPThreshold%
GuiControl,, PotHPThreshold2InputV299, %potHPThreshold2V299%
GuiControl,, PotCooldown, %potCooldown%
GuiControl, % manaOn ? "+Checked" : "-Checked", ManaOn
GuiControl, ChooseString, ManaMode, %manaMode%
GuiControl,, ManaThreshold, %manaThreshold%
GuiControl,, ManaCooldown, %manaCooldown%
GuiControl,, RareWarningKeyInputV1, % MouseKeyDisplayV616(rareWarningKeyV1="" ? "None" : rareWarningKeyV1)
GuiControl,, RareWarningHideInputV19, %rareWarningHiddenV19%
RareWarningRenderV16()
GuiControl,, PickupRadius, %pickupRadius%
GuiControl,, PickupFailTeleRadiusInputV1253, %pickupFailTeleRadiusV1253%
GuiControl,, SigKeyInputV147, % MouseKeyDisplayV616(MapHotkeyDisplayV178(sigKeyV147))
GuiControl,, ItemInspectKeyInputV287, % MapHotkeyDisplayV178(itemInspectKeyV287)
GuiControl,, SigSuKeyInputV181, % MapHotkeyDisplayV178(sigSuKeyV181)
GuiControl,, PickupStashKeyInputV14, % MapHotkeyDisplayV178(pickupStashKeyV14)
GuiControl,, PickupSetKeyInputV14, % MapHotkeyDisplayV178(pickupSetKeyV14)
GuiControl,, PickupSUKeyInputV14, % MapHotkeyDisplayV178(pickupSUKeyV14)
GuiControl,, SigTUInputV586, %sigTUV586%
GuiControl,, SigSUInputV510, %sigSUV510%
GuiControl,, SigSSUInputV13, %sigSSUV13%
GuiControl,, PickupToggleKeyInputV79, % MouseKeyDisplayV616(pickupToggleKeyV79="" ? "None" : pickupToggleKeyV79)

GuiControl, 1:, FarmResetWatchCheckV217, % farmResetWatchEnabledV217 ? 1 : 0
GuiControl, 1:, FarmResetWatchMinutesV217, %farmResetWatchMinutesV217%
GuiControl, 1:, ContinuousMapInputV64, % continuousMapV168 ? 1 : 0
GuiControl, 1:, AutoLoadMapCheckV348, % autoLoadMapV340 ? 1 : 0
GuiControl, 1:, FarmEntrySigCheckV315, % farmEntrySigV315 ? 1 : 0
GuiControl, 1:, FarmEntryGoldCheckV347, % farmEntryGoldV315 ? 1 : 0
if (IsObject(libAutoTicketV293))
    for _,tierV293 in [130,133,136,139]
        GuiControl, 1:, LibAutoTicket%tierV293%V293, % libAutoTicketV293[tierV293] ? 1 : 0

if (!GetKeyState("LButton","P"))
    GuiControl, 1:, PickupEnabledInputV79, %pickupImageOn%

ToolTipInfoV386("Đã load profile: " . currentProfile)
SetTimer, RemoveToolTip, -2000
return

AddProfile:
if (xRunning)
    return

GuiControlGet, NewProfileName, 1:, NewProfileName

name := Trim(NewProfileName)

if (name = "")
{
    MsgBox, 48, Lỗi, Hãy nhập tên Profile.
    return
}

if (!ProfileNameValidV364(name))
{
    MsgBox, 48, Lỗi, Tên profile không hợp lệ hoặc chứa ký tự dành riêng cho tên file.
    return
}
if (ProfileExists(name) || FileExist(ProfileFile(name)))
{
    MsgBox, 48, Lỗi, Profile này đã tồn tại. Hãy chọn tên khác.
    return
}
SaveProfile(currentProfile)


Loop, 5
{
    i := A_Index
    GuiControl,, FKey%i%, None
    GuiControl,, FDelay%i%, 0
}

Loop, 3
{
    i := A_Index
    GuiControl,, QCastKey%i%, None
    GuiControl,, QCastDelay%i%, 0
}

Loop, 6
{
    i := A_Index
    GuiControl,, RClickKey%i%, None
    GuiControl,, RClickDelay%i%, 0
}

GuiControl,, ZSetKey, None
GuiControl,, ZSetDelay, 200
GuiControl,, ZKeyF1, None
GuiControl,, ZKeyF2, None
GuiControl,, ZDelay1, 200
GuiControl,, ZDelay2, 200

GuiControl,, Belt4HPKey, None
GuiControl,, Belt2HP2ManaKey, None
GuiControl,, InvToCubeKey, None

GuiControl, 1:, FarmResetWatchCheckV217, 0
GuiControl, 1:, FarmResetWatchMinutesV217, 5
GuiControl, 1:, ContinuousMapInputV64, 0
GuiControl, 1:, AutoLoadMapCheckV348, 1
GuiControl, 1:, FarmEntrySigCheckV315, 1
GuiControl, 1:, FarmEntryGoldCheckV347, 1
if (IsObject(libAutoTicketV293))
    for _,tierV293 in [130,133,136,139]
        GuiControl, 1:, LibAutoTicket%tierV293%V293, 0

previousProfileV364 := currentProfile
currentProfile := name
Gosub, ApplyConfig

if (!configApplyOK)
{
    currentProfile := previousProfileV364
    return
}
PickupCtrlEndV26()

currentProfile := name
if (!SaveProfile(currentProfile))
{
    currentProfile := previousProfileV364
    MsgBox, 48, Lỗi, % "Chưa tạo được file profile: " . ProfileFile(name)
    return
}
AddProfileName(name)
LoadProfile(currentProfile)
IniWrite, %currentProfile%, %ConfigFile%, Profiles, Current
IniWrite, %currentProfile%, %ConfigFile%, Settings, LastProfile

GuiControl,, ProfileSelect, |%profileList%
GuiControl, ChooseString, ProfileSelect, %currentProfile%
GuiControl,, NewProfileName,

ToolTipInfoV386("Đã thêm profile: " . currentProfile)
SetTimer, RemoveToolTip, -2000
return

DeleteProfile:
if (xRunning)
    return

GuiControlGet, selectedDeleteProfileV520, 1:, ProfileSelect
name := Trim(selectedDeleteProfileV520)
if (name="")
{
    ProfileDiscoverFilesV366()
    GuiControl, 1:, ProfileSelect, |%profileList%
    GuiControl, 1:ChooseString, ProfileSelect, %currentProfile%
    ToolTipInfoV386("Đã dọn danh sách profile rỗng hoặc không còn file.")
    SetTimer, RemoveToolTip, -2500
    return
}
if (name = "Default")
{
    MsgBox, 48, Lỗi, Không thể xóa Profile Default.
    return
}

Gui, +OwnDialogs
MsgBox, 36, Xác nhận, Xóa Profile "%name%"?
IfMsgBox, No
    return

if (!DeleteProfileData(name))
{
    MsgBox, 48, Lỗi, % "Chưa xóa được file profile: " . ProfileFile(name)
    return
}
RemoveProfileName(name)
currentProfile := "Default"
IniWrite, %currentProfile%, %ConfigFile%, Profiles, Current
IniWrite, %currentProfile%, %ConfigFile%, Settings, LastProfile
LoadProfile(currentProfile)
RefreshClickCastControls()

GuiControl,, ProfileSelect, |%profileList%
GuiControl, ChooseString, ProfileSelect, %currentProfile%

Loop, 5
{
    index := A_Index
    currentKey := FKey%index%
    currentDelay := FDelay%index%

    if (currentKey = "")
        currentKey := "None"

    GuiControl,, FKey%index%, % MouseKeyDisplayV616(currentKey)
    GuiControl,, FDelay%index%, %currentDelay%
}

Loop, 3
{
    qIndex := A_Index
    qCurrentKey := QCastKey%qIndex%
    qCurrentDelay := QCastDelay%qIndex%
    if (qCurrentKey = "")
        qCurrentKey := "None"
    GuiControl,, QCastKey%qIndex%, % MouseKeyDisplayV616(qCurrentKey)
    GuiControl,, QCastDelay%qIndex%, %qCurrentDelay%
}

GuiControl,, XKey, % MouseKeyDisplayV616(xKey)
GuiControl,, XDelay, %xDelay%
zRunShow := (zKey = "" ? "None" : zKey)
GuiControl,, ZRunKey, % MouseKeyDisplayV616(zRunShow)
GuiControl,, ZSetKey, % MouseKeyDisplayV616(zSetKey)
GuiControl,, ZSetDelay, %zSetDelay%
zShowF1 := zFKey
zShowF2 := (zFKey2 = "" ? "None" : zFKey2)
GuiControl,, ZKeyF1, % MouseKeyDisplayV616(zShowF1)
GuiControl,, ZKeyF2, % MouseKeyDisplayV616(zShowF2)
GuiControl,, ZDelay1, %zDelay1%
GuiControl,, ZDelay2, %zDelay2%
GuiControl, ChooseString, DoubleKey, %doubleKey%
GuiControl,, DoubleTapMs, %doubleTapMs%
GuiControl, ChooseString, FormDoubleKey, %formDoubleKey%
GuiControl,, FormDoubleTapMs, %formDoubleTapMs%
GuiControl,, NewProfileName,
GuiControl, % autoPotOn ? "+Checked" : "-Checked", AutoPotOn
GuiControl, % invHealOn ? "+Checked" : "-Checked", InvHealOn
GuiControl, % cubeHealOn ? "+Checked" : "-Checked", CubeHealOn
GuiControl, % invManaOn ? "+Checked" : "-Checked", InvManaOn
GuiControl, % cubeManaOn ? "+Checked" : "-Checked", CubeManaOn
GuiControl,, InvToCubeKey, % MouseKeyDisplayV616(invToCubeKey)
GuiControl,, CubePickupDelayInput, %cubePickupDelayMs%
GuiControl,, CubeTransferDelayInput, %cubeTransferDelayMs%
GuiControl,, Belt4HPKey, % MouseKeyDisplayV616(belt4HPKey)
GuiControl,, Belt2HP2ManaKey, % MouseKeyDisplayV616(belt2HP2ManaKey)
GuiControl, ChooseString, PotMode, %potMode%
GuiControl,, PortalCastInputV50, % portalCastKeyV50="MButton" ? "M3" : portalCastKeyV50="" ? "None" : portalCastKeyV50
GuiControl,, MonsterRadiusInputV48, %monsterRadiusV48%
GuiControl,, FarmScanLimitInputV771, %farmScanLimitV771%
GuiControl,, PortalCastEveryInputV52, %portalCastEveryV52%
GuiControl,, TeleportKeyInputV55, % teleportKeyV55="" ? "None" : teleportKeyV55="MButton" ? "M3" : teleportKeyV55
GuiControl,, TeleportIntervalInputV56, %teleportIntervalSecV56%
GuiControl,, ChaseCheckInputV9, %chaseCheckSecV9%
GuiControl,, MapMoveDistanceInputV197, %mapMoveDistanceV197%
GuiControl,, BOMoveMinimumInputV456, %boMoveMinimumV456%

GuiControl,, GoalDetourInputV14, %goalDetourV14%
GuiControl,, MonsterLockUntilDeadInputV145, %monsterLockUntilDeadV145%
GuiControl,, ViewIdInputV54, %viewIdV54%
GuiControl,, ViewPosInputV291, %viewPosV291%
GuiControl,, StateBuffKeyInputV17, % MouseKeyDisplayV616(stateBuffKeyV17="" ? "None" : stateBuffKeyV17)
GuiControl,, PestilenceKeyInputV18, % MouseKeyDisplayV616(pestilenceKeyV18="" ? "None" : pestilenceKeyV18)
GuiControl,, DeathlordStateInputV19, %deathlordStateV19%
GuiControl,, PestilenceStateInputV19, %pestilenceStateV19%
GuiControl,, AnathemaStateInputV518, %anathemaStateV518%
GuiControl,, AnathemaKeyInputV518, % MouseKeyDisplayV616(anathemaKeyV518="" ? "None" : anathemaKeyV518)
GuiControl,, TownLevelInputV22, %townLevelV22%
GuiControl,, OutsideLevelInputV22, %outsideLevelV22%
GuiControl,, BuffGetResultV19, %buffGetTextV22%
GuiControl,, PotHPThreshold, %potHPThreshold%
GuiControl,, PotHPThreshold2InputV299, %potHPThreshold2V299%
GuiControl,, PotCooldown, %potCooldown%
GuiControl, % manaOn ? "+Checked" : "-Checked", ManaOn
GuiControl, ChooseString, ManaMode, %manaMode%
GuiControl,, ManaThreshold, %manaThreshold%
GuiControl,, ManaCooldown, %manaCooldown%
GuiControl,, PickupRadius, %pickupRadius%
GuiControl,, PickupFailTeleRadiusInputV1253, %pickupFailTeleRadiusV1253%
GuiControl,, SigKeyInputV147, % MouseKeyDisplayV616(MapHotkeyDisplayV178(sigKeyV147))
GuiControl,, ItemInspectKeyInputV287, % MapHotkeyDisplayV178(itemInspectKeyV287)
GuiControl,, SigSuKeyInputV181, % MapHotkeyDisplayV178(sigSuKeyV181)
GuiControl,, PickupStashKeyInputV14, % MapHotkeyDisplayV178(pickupStashKeyV14)
GuiControl,, PickupSetKeyInputV14, % MapHotkeyDisplayV178(pickupSetKeyV14)
GuiControl,, PickupSUKeyInputV14, % MapHotkeyDisplayV178(pickupSUKeyV14)
GuiControl,, SigTUInputV586, %sigTUV586%
GuiControl,, SigSUInputV510, %sigSUV510%
GuiControl,, SigSSUInputV13, %sigSSUV13%
GuiControl,, PickupToggleKeyInputV79, % MouseKeyDisplayV616(pickupToggleKeyV79="" ? "None" : pickupToggleKeyV79)
GuiControl, 1:, PickupEnabledInputV79, %pickupImageOn%

ToolTipInfoV386("Đã xóa profile: " . name)
SetTimer, RemoveToolTip, -2000
return

ProfileFolder()
{
    return A_ScriptDir . "\profile"
}

ProfileFile(name)
{
    safe := RegExReplace(name, "[\\/:*?""<>|]", "_")
    safe := RTrim(safe, " .")
    if (safe = "")
        safe := "Default"
    return ProfileFolder() . "\" . safe . ".ini"
}

EnsureProfileFolder()
{
    folder := ProfileFolder()
    if (!FileExist(folder))
        FileCreateDir, %folder%
}


ProfileSection(name)
{
    safe := name
    StringReplace, safe, safe, [, (, All
    StringReplace, safe, safe, ], ), All
    return "Profile_" . safe
}

ProfileExists(name)
{
    global profileList
    Loop, Parse, profileList, |
    {
        if (A_LoopField = name)
            return true
    }
    return false
}

AddProfileName(name)
{
    global profileList, ConfigFile
    name := Trim(name)
    if (!ProfileNameValidV364(name) || ProfileExists(name))
        return
    if (profileList = "")
        profileList := name
    else
        profileList .= "|" . name
    IniWrite, %profileList%, %ConfigFile%, Profiles, Names
}

RemoveProfileName(name)
{
    global profileList, ConfigFile
    newList := ""
    Loop, Parse, profileList, |
    {
        item := A_LoopField
        if (item = "" || item = name)
            continue
        if (newList = "")
            newList := item
        else
            newList .= "|" . item
    }
    if (!InStr("|" . newList . "|", "|Default|"))
        newList := "Default" . (newList != "" ? "|" . newList : "")
    profileList := newList
    IniWrite, %profileList%, %ConfigFile%, Profiles, Names
}

DeleteProfileData(name)
{
    global ConfigFile
    if (!ProfileNameValidV364(name) || name="Default")
        return false
    file := ProfileFile(name)
    if (FileExist(file))
    {
        FileDelete, %file%
        if (FileExist(file))
            return false
    }
    legacy := A_ScriptDir . "\Profiles\" . SubStr(file,StrLen(ProfileFolder())+2)
    if (FileExist(legacy))
    {
        FileDelete, %legacy%
        if (FileExist(legacy))
            return false
    }
    base := ProfileSection(name)
    IniRead, sections, %ConfigFile%
    Loop, Parse, sections, `n, `r
    {
        section := A_LoopField
        if (section=base || InStr(section,base . "_RouteMap_")=1)
        {
            IniDelete, %ConfigFile%, %section%
            if (ErrorLevel)
                return false
        }
    }
    return true
}

SaveProfile(name)
{
    global petExcludeDistanceV604
    if (name = "")
        name := "Default"
    EnsureProfileFolder()
    wasCritical := A_IsCritical
    Critical, On
    try
    {
        SaveProfileBody(name)
        ProfileCaptureControlsV364(name)
    }
    finally
        Critical, %wasCritical%
    return ProfileStoredV520(name)
}

SaveProfileBody(name)
{
    global mapTestModeV656
    testSectionV656 := ProfileSection(name)
    IniWrite, %mapTestModeV656%, % ProfileConfigPathV364(testSectionV656), %testSectionV656%, MapTestMode
    global routeRecordDistanceV649
    global buffSequenceDelayV555
    buffSequenceDelayV555 := BuffSequenceDelayGetV555()
    buffSectionV555 := ProfileSection(name)
    IniWrite, %buffSequenceDelayV555%, % ProfileConfigPathV364(buffSectionV555), %buffSectionV555%, BuffSequenceDelayMs
    global libAutoTicketV293
    BossPrioritySaveV221(name)
    global pickupToCubeV37
    global rareWarningHiddenV19
    global excludeModeV329, excludeDeleteModeV332
    global pickupStashKeyV14,pickupSetKeyV14,pickupSUKeyV14
    global sigTUV586,sigSUV510,sigSSUV13,sigSSSUV13,itemInspectKeyV287
    global mapMoveDistanceV197, farmMapPauseV52, farmLoadedMapV56,boMoveMinimumV456
    global monsterLockUntilDeadV145,viewIdV54,viewPosV291,viewTipV640
    global monsterLockNoDamageSecV621,monsterLockRoomSecV622,monsterSkipDistanceV752
    global farmResetWatchEnabledV217, farmResetWatchMinutesV217
    global continuousMapV168, autoLoadMapV340
    global libScrollTierV290, farmControlOwnerV186
    global fautLab1V309, labNumberV314
    global sigTownLogTestEnabledV148, sigCubeCaptureEnabledV151, roomSavedReplayEnabledV116
    global farmEntrySigV315, farmEntryGoldV315
    global farmWatchdogSecondsV578, pickupColorVariation
    global autoMapTrackingV10
    global pickupDestinationV119,pickupGroupOnlyV26,master456Key
    SaveMaster456Key()
    Master456StateSaveV121(name)
    SaveClickCastConfig(ProfileSection(name))
    global monsterRadiusV48, farmScanLimitV771, portalCastKeyV50, portalCastEveryV52, teleportKeyV55, teleportIntervalSecV56, chaseCheckSecV9, teleLockSecV13, goalDetourV14, stateBuffKeyV17, stateBuffCheckSecV17, pestilenceKeyV18, deathlordStateV19, pestilenceStateV19, townLevelV22, outsideLevelV22, buffGetTextV22, anathemaStateV518, anathemaKeyV518
    global itemCenterRadiusV810, pickupScanRadiusV810, moveDelayMsV810, pickupFailTeleRadiusV1253
    global farmResumeArmedV70, farmResumeOutsideV70
    global ConfigFile, autoMonsterAttackOn, monsterExcludeClassesV11, autoMonsterToggleKeyV13, petLearnKeyV13, coordGetKeyV14, coordPointTextV14, coordPointLevelV14, coordMoveDoneV14, coordMoveTriesV14,
    global zKey, xKey, doubleKey, doubleTapMs, formDoubleKey, formDoubleTapMs, qCastDoubleKey, qCastDoubleTapMs
    global zSetKey, zSetDelay, xDelay, zFKey, zFKey2, zDelay1, zDelay2, zDelay3
    global FKey1, FKey2, FKey3, FKey4, FKey5, FKey6, FKey7, FKey8, FKey9, FKey10
    global FDelay1, FDelay2, FDelay3, FDelay4, FDelay5, FDelay6, FDelay7, FDelay8, FDelay9, FDelay10
    global QCastKey1, QCastKey2, QCastKey3, QCastDelay1, QCastDelay2, QCastDelay3
    global autoPotOn, invHealOn, invManaOn, cubeHealOn, cubeManaOn, invToCubeKey, cubePickupDelayMs, cubeTransferDelayMs, belt4HPKey, belt2HP2ManaKey, potMode, potCaptureKey1, potHPThreshold, potHPThreshold2V299, potCooldown
    global manaOn, manaMode, manaThreshold, manaCooldown, manaLastDrink
    global sigKeyV147,sigSuKeyV181,farmNaoKeyV181,pickupBackgroundV181
    global farmResetWatchEnabledV217,farmResetWatchMinutesV217
    global pickupToggleKeyV79, pickupImageOn, getIdKey, deleteIdKey, pickupRadius, rareWarningKeyV1
	global petLearnEnabledV12

    if (name = "")
        name := "Default"

    section := ProfileSection(name)
    LibAutoTicketSaveV293(name)
    IniWrite, 0, % ProfileConfigPathV364(section), %section%, AutoMonsterAttackOn
    IniWrite, %monsterRadiusV48%, % ProfileConfigPathV364(section), %section%, MonsterAttackRadius
    itemCenterRadiusV810 := ItemCenterRadiusGetV810()
    IniWrite, %itemCenterRadiusV810%, % ProfileConfigPathV364(section), %section%, ItemCenterRadius
    pickupScanRadiusV810 := PickupScanRadiusGetV810()
    IniWrite, %pickupScanRadiusV810%, % ProfileConfigPathV364(section), %section%, PickupScanRadius
    moveDelayMsV810 := MoveDelayGetV810()
    IniWrite, %moveDelayMsV810%, % ProfileConfigPathV364(section), %section%, MoveDelayMs
    IniWrite, %farmScanLimitV771%, % ProfileConfigPathV364(section), %section%, FarmScanLimit
    IniWrite, %portalCastKeyV50%, % ProfileConfigPathV364(section), %section%, RouteCastKey
    IniWrite, %portalCastEveryV52%, % ProfileConfigPathV364(section), %section%, RouteCastEvery
    IniWrite, %teleportKeyV55%, % ProfileConfigPathV364(section), %section%, StuckTeleportKey
    IniWrite, %teleportIntervalSecV56%, % ProfileConfigPathV364(section), %section%, StuckTeleportIntervalSeconds
    IniWrite, %chaseCheckSecV9%, % ProfileConfigPathV364(section), %section%, ChaseCheckSeconds
    IniWrite, %boMoveMinimumV456%, % ProfileConfigPathV364(section), %section%, BOMoveMinimum
    IniWrite, %mapMoveDistanceV197%, % ProfileConfigPathV364(section), %section%, MapMoveDistance
    IniWrite, %farmResetWatchMinutesV217%, % ProfileConfigPathV364(section), %section%, FarmBrainResetMinutes
    
    IniWrite, %goalDetourV14%, % ProfileConfigPathV364(section), %section%, GoalDetourDistance
    IniWrite, %monsterLockUntilDeadV145%, % ProfileConfigPathV364(section), %section%, MonsterLockUntilDead
    IniWrite, %viewIdV54%, % ProfileConfigPathV364(section), %section%, ViewID
    IniWrite, %viewPosV291%, % ProfileConfigPathV364(section), %section%, ViewPos
    IniWrite, %viewTipV640%, % ProfileConfigPathV364(section), %section%, ViewTip
    IniWrite, %routeRecordDistanceV649%, % ProfileConfigPathV364(section), %section%, RouteRecordMinDistance
	IniWrite, %monsterLockNoDamageSecV621%, % ProfileConfigPathV364(section), %section%, MonsterLockNoDamageSec
	IniWrite, %monsterLockRoomSecV622%, % ProfileConfigPathV364(section), %section%, MonsterLockRoomSec
    IniWrite, %monsterSkipDistanceV752%, % ProfileConfigPathV364(section), %section%, MonsterSkipDistance
	
    IniWrite, %stateBuffKeyV17%, % ProfileConfigPathV364(section), %section%, StateBuffCastKey
    
	IniWrite, %pestilenceKeyV18%, % ProfileConfigPathV364(section), %section%, PestilenceCastKey
    IniWrite, %deathlordStateV19%, % ProfileConfigPathV364(section), %section%, DeathlordStateID
    IniWrite, %pestilenceStateV19%, % ProfileConfigPathV364(section), %section%, PestilenceStateID
    IniWrite, %pestilenceKeyV18%, % ProfileConfigPathV364(section), %section%, PinnacleCastKey
    IniWrite, %pestilenceStateV19%, % ProfileConfigPathV364(section), %section%, PinnacleStateID
    IniWrite, %anathemaKeyV518%, % ProfileConfigPathV364(section), %section%, AnathemaCastKey
    IniWrite, %anathemaStateV518%, % ProfileConfigPathV364(section), %section%, AnathemaStateID
    IniWrite, %townLevelV22%, % ProfileConfigPathV364(section), %section%, TownLevelID
    IniWrite, %outsideLevelV22%, % ProfileConfigPathV364(section), %section%, OutsideLevelID
    IniWrite, %buffGetTextV22%, % ProfileConfigPathV364(section), %section%, BuffGetResult
    IniWrite, %monsterExcludeClassesV11%, % ProfileConfigPathV364(section), %section%, MonsterExcludeClasses
    IniWrite, %autoMonsterToggleKeyV13%, % ProfileConfigPathV364(section), %section%, AutoMonsterToggleKey
    IniWrite, %petLearnKeyV13%, % ProfileConfigPathV364(section), %section%, PetLearnKey
	IniWrite, % petLearnEnabledV12 ? 1 : 0, % ProfileConfigPathV364(section), %section%, PetLearnEnabled
    IniWrite, %coordGetKeyV14%, % ProfileConfigPathV364(section), %section%, CoordGetKey
    IniWrite, %coordPointTextV14%, % ProfileConfigPathV364(section), %section%, CoordPoint
    IniWrite, %coordPointLevelV14%, % ProfileConfigPathV364(section), %section%, CoordLevel
    CoordSavedStoreV15(name)
    IniWrite, %zKey%, % ProfileConfigPathV364(section), %section%, ZKey
    IniWrite, %xKey%, % ProfileConfigPathV364(section), %section%, XKey
    IniWrite, %doubleKey%, % ProfileConfigPathV364(section), %section%, DoubleKey
    IniWrite, %doubleTapMs%, % ProfileConfigPathV364(section), %section%, DoubleTapMs
    IniWrite, %formDoubleKey%, % ProfileConfigPathV364(section), %section%, FormDoubleKey
    IniWrite, %formDoubleTapMs%, % ProfileConfigPathV364(section), %section%, FormDoubleTapMs
    IniWrite, %qCastDoubleKey%, % ProfileConfigPathV364(section), %section%, QCastDoubleKey
    IniWrite, %qCastDoubleTapMs%, % ProfileConfigPathV364(section), %section%, QCastDoubleTapMs
    IniWrite, %zSetKey%, % ProfileConfigPathV364(section), %section%, ZSetKey
    IniWrite, %zSetDelay%, % ProfileConfigPathV364(section), %section%, ZSetDelay
    IniWrite, %xDelay%, % ProfileConfigPathV364(section), %section%, XDelay
    IniWrite, %zFKey%, % ProfileConfigPathV364(section), %section%, ZFKey
    saveZFKey2 := (zFKey2 = "" ? "None" : zFKey2)
    IniWrite, %saveZFKey2%, % ProfileConfigPathV364(section), %section%, ZFKey2
    IniWrite, %zDelay1%, % ProfileConfigPathV364(section), %section%, ZDelay1
    IniWrite, %zDelay2%, % ProfileConfigPathV364(section), %section%, ZDelay2
    IniWrite, %zDelay3%, % ProfileConfigPathV364(section), %section%, ZDelay3
    IniWrite, %autoPotOn%, % ProfileConfigPathV364(section), %section%, AutoPotOn
    IniWrite, %invHealOn%, % ProfileConfigPathV364(section), %section%, InvHealOn
    IniWrite, %cubeHealOn%, % ProfileConfigPathV364(section), %section%, CubeHealOn
    IniWrite, %invManaOn%, % ProfileConfigPathV364(section), %section%, InvManaOn
    IniWrite, %cubeManaOn%, % ProfileConfigPathV364(section), %section%, CubeManaOn
    IniWrite, %invToCubeKey%, % ProfileConfigPathV364(section), %section%, InvToCubeKey
    IniWrite, %cubePickupDelayMs%, % ProfileConfigPathV364(section), %section%, CubePickupDelayMs
    IniWrite, %cubeTransferDelayMs%, % ProfileConfigPathV364(section), %section%, CubeTransferDelayMs
    IniWrite, %belt4HPKey%, % ProfileConfigPathV364(section), %section%, Belt4HPKey
    IniWrite, %belt2HP2ManaKey%, % ProfileConfigPathV364(section), %section%, Belt2HP2ManaKey
    IniWrite, %potMode%, % ProfileConfigPathV364(section), %section%, PotMode
    IniWrite, %potCaptureKey1%, % ProfileConfigPathV364(section), %section%, PotCaptureKey1
    IniWrite, %potHPThreshold%, % ProfileConfigPathV364(section), %section%, PotHPThreshold
    IniWrite, %potHPThreshold2V299%, % ProfileConfigPathV364(section), %section%, PotHPThreshold2
    IniWrite, %potCooldown%, % ProfileConfigPathV364(section), %section%, PotCooldown
    IniWrite, %manaOn%, % ProfileConfigPathV364(section), %section%, ManaOn
    IniWrite, %manaMode%, % ProfileConfigPathV364(section), %section%, ManaMode
    IniWrite, %manaThreshold%, % ProfileConfigPathV364(section), %section%, ManaThreshold
    IniWrite, %manaCooldown%, % ProfileConfigPathV364(section), %section%, ManaCooldown
    IniWrite, %farmNaoKeyV181%, % ProfileConfigPathV364(section), %section%, FarmNaoKey
    IniWrite, %pickupStashKeyV14%, % ProfileConfigPathV364(section), %section%, PickupStashKey
    IniWrite, %pickupSetKeyV14%, % ProfileConfigPathV364(section), %section%, PickupSetKey
    IniWrite, %pickupSUKeyV14%, % ProfileConfigPathV364(section), %section%, PickupSUKey
    IniWrite, %sigTUV586%, % ProfileConfigPathV364(section), %section%, SigTU
    IniWrite, %sigSUV510%, % ProfileConfigPathV364(section), %section%, SigSU
    IniWrite, %sigSSUV13%, % ProfileConfigPathV364(section), %section%, SigSSU
    IniWrite, %sigSSSUV13%, % ProfileConfigPathV364(section), %section%, SigSSSU
    IniWrite, %itemInspectKeyV287%, % ProfileConfigPathV364(section), %section%, ItemInspectKey
    IniWrite, %sigSuKeyV181%, % ProfileConfigPathV364(section), %section%, SigSuKey
    IniWrite, %sigKeyV147%, % ProfileConfigPathV364(section), %section%, SigKey
    IniWrite, %pickupToggleKeyV79%, % ProfileConfigPathV364(section), %section%, PickupToggleKey
    IniWrite, 1, % ProfileConfigPathV364(section), %section%, PickupImageOn
    IniWrite, 1, % ProfileConfigPathV364(section), %section%, PickupToCube
    IniWrite, %pickupDestinationV119%, % ProfileConfigPathV364(section), %section%, PickupDestination
    IniWrite, %pickupGroupOnlyV26%, % ProfileConfigPathV364(section), %section%, PickupGroupOnly
    masterProfileKeyV121 := master456Key="" ? "None" : master456Key
    IniWrite, %masterProfileKeyV121%, % ProfileConfigPathV364(section), %section%, Master456Key
    IniWrite, %getIdKey%, % ProfileConfigPathV364(section), %section%, GetIdKey
    IniWrite, %deleteIdKey%, % ProfileConfigPathV364(section), %section%, DeleteIdKey
    IniWrite, %pickupRadius%, % ProfileConfigPathV364(section), %section%, PickupRadius
    pickupFailTeleRadiusV1253 := PickupFailTeleRadiusGetV1253()
    IniWrite, %pickupFailTeleRadiusV1253%, % ProfileConfigPathV364(section), %section%, PickupFailTeleRadius
    IniWrite, % excludeModeV329 ? 1 : 0, % ProfileConfigPathV364(section), %section%, ExcludeMode
    IniWrite, % excludeDeleteModeV332 ? 1 : 0, % ProfileConfigPathV364(section), %section%, ExcludeDeleteMode
	    IniWrite, %rareWarningKeyV1%, % ProfileConfigPathV364(section), %section%, RareWarningKey
    IniWrite, %rareWarningHiddenV19%, % ProfileConfigPathV364(section), %section%, RareWarningHidden
IniWrite, %libScrollTierV290%, % ProfileConfigPathV364(section), %section%, LibScrollTier
IniWrite, %farmControlOwnerV186%, % ProfileConfigPathV364(section), %section%, FarmControlOwner
IniWrite, %fautLab1V309%, % ProfileConfigPathV364(section), %section%, FautLab1
IniWrite, %labNumberV314%, % ProfileConfigPathV364(section), %section%, LabNumber
IniWrite, % continuousMapV168 ? 1 : 0, % ProfileConfigPathV364(section), %section%, ContinuousMap
IniWrite, % autoLoadMapV340 ? 1 : 0, % ProfileConfigPathV364(section), %section%, AutoLoadMap
IniWrite, %sigTownLogTestEnabledV148%, % ProfileConfigPathV364(section), %section%, SigTownLogTest
IniWrite, %sigCubeCaptureEnabledV151%, % ProfileConfigPathV364(section), %section%, SigCubeCapture
IniWrite, %roomSavedReplayEnabledV116%, % ProfileConfigPathV364(section), %section%, RoomSavedReplay
IniWrite, %pickupColorVariation%, % ProfileConfigPathV364(section), %section%, PickupColorVariation
IniWrite, %farmWatchdogSecondsV578%, % ProfileConfigPathV364(section), %section%, FarmBrainWatchdogSecs
IniWrite, %stateBuffCheckSecV17%, % ProfileConfigPathV364(section), %section%, StateBuffCheckSec
IniWrite, % farmResetWatchEnabledV217 ? 1 : 0, % ProfileConfigPathV364(section), %section%, FarmBrainResetWatch
IniWrite, % farmEntrySigV315 ? 1 : 0, % ProfileConfigPathV364(section), %section%, FarmEntrySig
IniWrite, % farmEntryGoldV315 ? 1 : 0, % ProfileConfigPathV364(section), %section%, FarmEntryGold

    Loop, 3
    {
        qIndex := A_Index
        qKey := QCastKey%qIndex%
        qDelay := QCastDelay%qIndex%
        IniWrite, %qKey%, % ProfileConfigPathV364(section), %section%, QCastKey%qIndex%
        IniWrite, %qDelay%, % ProfileConfigPathV364(section), %section%, QCastDelay%qIndex%
    }

    Loop, 10
    {
        index := A_Index
        key := FKey%index%
        delay := FDelay%index%
        IniWrite, %key%, % ProfileConfigPathV364(section), %section%, FKey%index%
        IniWrite, %delay%, % ProfileConfigPathV364(section), %section%, FDelay%index%
    }

}

LoadProfile(name)
{
    global petExcludeDistanceV604
    if (name = "")
        name := "Default"
    EnsureProfileFolder()
    file := ProfileFile(name), section := ProfileSection(name)
    if (!FileExist(file))
        return false
    IniRead, sectionsV366, %file%
    if (!InStr("`n" . sectionsV366 . "`n", "`n" . section . "`n"))
        return false
    wasCritical := A_IsCritical
    Critical, On
    LoadProfileBody(name)
    ProfileRefreshControlsV364(name)
    RecoveryLoginLoadV489()
    SetTimer, ProfileLiveMapReloadV523, -50
    Critical, %wasCritical%
    return true
}

LoadProfileBody(name)
{
    global monsterSkipDistanceV752
    skipSectionV752 := ProfileSection(name)
    IniRead, monsterSkipDistanceV752, % ProfileConfigPathV364(skipSectionV752), %skipSectionV752%, MonsterSkipDistance, 4
    if (!RegExMatch(monsterSkipDistanceV752,"^\d+$") || monsterSkipDistanceV752>200)
        monsterSkipDistanceV752 := 4
    if (ProfileControlExistsV365("MonsterSkipDistanceInputV752"))
        GuiControl, 1:, MonsterSkipDistanceInputV752, %monsterSkipDistanceV752%
    global mapTestModeV656
    testSectionV656 := ProfileSection(name)
    IniRead, mapTestModeV656, % ProfileConfigPathV364(testSectionV656), %testSectionV656%, MapTestMode, 0
    mapTestModeV656 := mapTestModeV656=1
    if (ProfileControlExistsV365("MapTestModeCheckV656"))
        GuiControl, 1:, MapTestModeCheckV656, %mapTestModeV656%
    global routeRecordDistanceV649
    global buffSequenceDelayV555,buffSequenceOnV555
    if (buffSequenceOnV555)
        BuffSequenceSetV555(false)
    buffSectionV555 := ProfileSection(name)
    IniRead, buffSequenceDelayV555, % ProfileConfigPathV364(buffSectionV555), %buffSectionV555%, BuffSequenceDelayMs, 30000
    if (!RegExMatch(buffSequenceDelayV555,"^\d+$") || buffSequenceDelayV555<1)
        buffSequenceDelayV555 := 30000
    buffSequenceDelayV555 := Min(86400000,buffSequenceDelayV555+0)
    if (ProfileControlExistsV365("BuffSequenceDelayInputV555"))
        GuiControl, 1:, BuffSequenceDelayInputV555, %buffSequenceDelayV555%
    BuffSequenceGuiSyncV555()
    global libAutoTicketV293
    global pickupToCubeV37
    global rareWarningHiddenV19
    global excludeModeV329, excludeDeleteModeV332
    global pickupStashKeyV14,pickupSetKeyV14,pickupSUKeyV14
    global sigTUV586,sigSUV510,sigSSUV13,sigSSSUV13,itemInspectKeyV287
    global mapMoveDistanceV197, farmMapPauseV52, farmLoadedMapV56,boMoveMinimumV456
    global itemCenterRadiusV810, pickupScanRadiusV810, moveDelayMsV810, pickupFailTeleRadiusV1253
    global monsterLockUntilDeadV145,viewIdV54,viewPosV291,viewTipV640
    global monsterLockNoDamageSecV621,monsterLockRoomSecV622,monsterSkipDistanceV752
    global farmResetWatchEnabledV217, farmResetWatchMinutesV217
    global continuousMapV168, autoLoadMapV340
    global libScrollTierV290, farmControlOwnerV186
    global fautLab1V309, labNumberV314
    global sigTownLogTestEnabledV148, sigCubeCaptureEnabledV151, roomSavedReplayEnabledV116
    global farmEntrySigV315, farmEntryGoldV315
    global farmWatchdogSecondsV578, pickupColorVariation
    global autoMapTrackingV10,coordPinnedYellowV136
    global currentProfile,master456Key,QCastOn,clickCastOn,cycleOn,master456Paused,master456Saved,cycleStep,nextStepTime,farmBuffModeV509
    global pickupDestinationV119,pickupGroupOnlyV26,rareWarningKeyV1
    global monsterRadiusV48, farmScanLimitV771, portalCastKeyV50, portalCastEveryV52, teleportKeyV55, teleportIntervalSecV56, chaseCheckSecV9, teleLockSecV13, goalDetourV14, stateBuffKeyV17, stateBuffCheckSecV17, pestilenceKeyV18, deathlordStateV19, pestilenceStateV19, townLevelV22, outsideLevelV22, buffGetTextV22, anathemaStateV518, anathemaKeyV518
    global farmResumeArmedV70, farmResumeOutsideV70
    global ConfigFile, autoMonsterAttackOn, monsterExcludeClassesV11, autoMonsterToggleKeyV13, petLearnKeyV13, coordGetKeyV14, coordPointTextV14, coordPointLevelV14, coordMoveDoneV14, coordMoveTriesV14
    global zKey, xKey, doubleKey, doubleTapMs, formDoubleKey, formDoubleTapMs, qCastDoubleKey, qCastDoubleTapMs
    global zSetKey, zSetDelay, xDelay, zFKey, zFKey2, zDelay1, zDelay2, zDelay3
    global FKey1, FKey2, FKey3, FKey4, FKey5, FKey6, FKey7, FKey8, FKey9, FKey10
    global FDelay1, FDelay2, FDelay3, FDelay4, FDelay5, FDelay6, FDelay7, FDelay8, FDelay9, FDelay10
    global QCastKey1, QCastKey2, QCastKey3, QCastDelay1, QCastDelay2, QCastDelay3
    global autoPotOn, invHealOn, invManaOn, cubeHealOn, cubeManaOn, invToCubeKey, cubePickupDelayMs, cubeTransferDelayMs, belt4HPKey, belt2HP2ManaKey, potMode, potCaptureKey1, potHPThreshold, potHPThreshold2V299, potCooldown, potLastDrink, potCycle, potFarCount
    global manaOn, manaMode, manaThreshold, manaCooldown, manaLastDrink, healExhausted
    global sigKeyV147,sigSuKeyV181,farmNaoKeyV181,pickupBackgroundV181
    global farmResetWatchEnabledV217,farmResetWatchMinutesV217
    global pickupToggleKeyV79, pickupImageOn, getIdKey, deleteIdKey, pickupRadius, pickupLastClick
	    global petLearnEnabledV12

    section := ProfileSection(name)

    IniRead, test, % ProfileConfigPathV364(section), %section%, ZKey, %A_Space%
    test := NormalizeOptionalKey(test)
    currentProfile := name
    coordPinnedYellowV136 := 0
    IniWrite, %name%, %ConfigFile%, Profiles, Current
    if (master456Key!="")
        BackgroundHotkeyV63("~$" . master456Key,"Master456Handler","Off UseErrorLevel")
    IniRead, masterProfileKeyV121, % ProfileConfigPathV364(section), %section%, Master456Key, MISSING
    if (masterProfileKeyV121="MISSING")
        IniRead, masterProfileKeyV121, %ConfigFile%, Master456, Key, None
    master456Key := "None"
    if (master456Key!="")
        BackgroundHotkeyV63("~$" . master456Key,"Master456Handler","On UseErrorLevel")
    if (ProfileControlExistsV365("Master456KeyInput"))
        GuiControl,, Master456KeyInput, % master456Key="" ? "None" : master456Key
    IniRead, monsterLockUntilDeadV145, % ProfileConfigPathV364(section), %section%, MonsterLockUntilDead, 0
    monsterLockUntilDeadV145 := monsterLockUntilDeadV145=1
    IniRead, viewIdV54, % ProfileConfigPathV364(section), %section%, ViewID, 1
    viewIdV54 := viewIdV54=1
    IniRead, viewPosV291, % ProfileConfigPathV364(section), %section%, ViewPos, 0
    viewPosV291 := viewPosV291=1
	IniRead, viewTipV640, % ProfileConfigPathV364(section), %section%, ViewTip, 1
	viewTipV640 := viewTipV640=1
    
    IniRead, routeRecordDistanceV649, % ProfileConfigPathV364(section), %section%, RouteRecordMinDistance, 12
    if (!RegExMatch(routeRecordDistanceV649,"^\d+$") || routeRecordDistanceV649>9999)
        routeRecordDistanceV649 := 12
    if (ProfileControlExistsV365("RouteRecordDistanceInputV649"))
        GuiControl, 1:, RouteRecordDistanceInputV649, %routeRecordDistanceV649%
	IniRead, monsterLockNoDamageSecV621, % ProfileConfigPathV364(section), %section%, MonsterLockNoDamageSec, 5
if (!RegExMatch(monsterLockNoDamageSecV621,"^\d+$") || monsterLockNoDamageSecV621<0 || monsterLockNoDamageSecV621>3600)
    monsterLockNoDamageSecV621 := 5
if (ProfileControlExistsV365("MonsterLockNoDamageSecInputV621"))
    GuiControl, 1:, MonsterLockNoDamageSecInputV621, %monsterLockNoDamageSecV621%

IniRead, monsterLockRoomSecV622, % ProfileConfigPathV364(section), %section%, MonsterLockRoomSec, 30
if (!RegExMatch(monsterLockRoomSecV622,"^\d+$") || monsterLockRoomSecV622<1 || monsterLockRoomSecV622>3600)
    monsterLockRoomSecV622 := 30
if (ProfileControlExistsV365("MonsterLockRoomSecInputV622"))
    GuiControl, 1:, MonsterLockRoomSecInputV622, %monsterLockRoomSecV622%
	
	ViewDisplayApplyV601()

    IniRead, mapMoveDistanceV197, % ProfileConfigPathV364(section), %section%, MapMoveDistance, 12
    if (!RegExMatch(mapMoveDistanceV197,"^\d+$") || mapMoveDistanceV197<1 || mapMoveDistanceV197>200)
        mapMoveDistanceV197 := 12
    IniRead, boMoveMinimumV456, % ProfileConfigPathV364(section), %section%, BOMoveMinimum, 5
    if (!RegExMatch(boMoveMinimumV456,"^\d+$") || boMoveMinimumV456<1)
        boMoveMinimumV456 := 5
    boMoveMinimumV456 := Max(5,boMoveMinimumV456)
    IniRead, chaseCheckSecV9, % ProfileConfigPathV364(section), %section%, ChaseCheckSeconds, 3
    if (!RegExMatch(chaseCheckSecV9, "^\d+$") || chaseCheckSecV9<1 || chaseCheckSecV9>3600)
        chaseCheckSecV9 := 3
    IniRead, teleportIntervalSecV56, % ProfileConfigPathV364(section), %section%, StuckTeleportIntervalSeconds, 5
    if (!RegExMatch(teleportIntervalSecV56,"^\d+$") || teleportIntervalSecV56<1 || teleportIntervalSecV56>3600)
        teleportIntervalSecV56 := 5
    IniRead, teleportKeyV55, % ProfileConfigPathV364(section), %section%, StuckTeleportKey, %A_Space%
    teleportKeyV55 := PortalCastNormalizeV50(teleportKeyV55)
    if (teleportKeyV55!="" && !GetKeyVK(teleportKeyV55) && !GetKeySC(teleportKeyV55))
        teleportKeyV55 := ""
    IniRead, portalCastEveryV52, % ProfileConfigPathV364(section), %section%, RouteCastEvery, 2
    if (!RegExMatch(portalCastEveryV52,"^\d+$") || portalCastEveryV52<1 || portalCastEveryV52>999)
        portalCastEveryV52 := 2
    IniRead, portalCastKeyV50, % ProfileConfigPathV364(section), %section%, RouteCastKey, MButton
    portalCastKeyV50 := PortalCastNormalizeV50(portalCastKeyV50)
    if (portalCastKeyV50!="" && !GetKeyVK(portalCastKeyV50) && !GetKeySC(portalCastKeyV50))
        portalCastKeyV50 := "MButton"
    IniRead, monsterRadiusV48, % ProfileConfigPathV364(section), %section%, MonsterAttackRadius, 12
    if (!RegExMatch(monsterRadiusV48,"^\d+$") || monsterRadiusV48<1 || monsterRadiusV48>200)
        monsterRadiusV48 := 12
    IniRead, itemCenterRadiusV810, % ProfileConfigPathV364(section), %section%, ItemCenterRadius, 12
    if (!RegExMatch(itemCenterRadiusV810,"^\d+$") || itemCenterRadiusV810<1 || itemCenterRadiusV810>200)
        itemCenterRadiusV810 := 12
    itemCenterRadiusV810 += 0
    ; BK quet moi: khong ke thua ItemCenterRadius (BK tam) de tranh thu hep pham vi.
    ; Ho so cu tu khoi tao BK danh x2, giong hanh vi cu cua timer nhat.
    IniRead, pickupScanRadiusV810, % ProfileConfigPathV364(section), %section%, PickupScanRadius, 0
    if (!RegExMatch(pickupScanRadiusV810,"^\d+$") || pickupScanRadiusV810<1 || pickupScanRadiusV810>400)
        pickupScanRadiusV810 := Max(1,Min(400,monsterRadiusV48*2))
    pickupScanRadiusV810 += 0
    if (ProfileControlExistsV365("PickupScanRadiusInputV810"))
        GuiControl, 1:, PickupScanRadiusInputV810, %pickupScanRadiusV810%
    IniRead, moveDelayMsV810, % ProfileConfigPathV364(section), %section%, MoveDelayMs, 250
    if (!RegExMatch(moveDelayMsV810, "^\d+$") || moveDelayMsV810<0 || moveDelayMsV810>5000)
        moveDelayMsV810 := 250
    moveDelayMsV810 += 0
    if (ProfileControlExistsV365("MoveDelayInputV810"))
        GuiControl, 1:, MoveDelayInputV810, %moveDelayMsV810%
    IniRead, farmScanLimitV771, % ProfileConfigPathV364(section), %section%, FarmScanLimit, 5
    if (!RegExMatch(farmScanLimitV771,"^\d+$") || farmScanLimitV771<1 || farmScanLimitV771>999)
        farmScanLimitV771 := 5
    farmScanLimitV771 += 0
    defaultGoalDetourV14 := Round(Max(3,monsterRadiusV48*0.5))
    IniRead, goalDetourV14, % ProfileConfigPathV364(section), %section%, GoalDetourDistance, %defaultGoalDetourV14%
    if (!RegExMatch(goalDetourV14,"^\d+(\.\d+)?$") || goalDetourV14<0 || goalDetourV14>200)
        goalDetourV14 := defaultGoalDetourV14
    goalDetourV14 := Round(goalDetourV14)
    IniRead, stateBuffKeyV17, % ProfileConfigPathV364(section), %section%, StateBuffCastKey, %A_Space%
    stateBuffKeyV17 := PortalCastNormalizeV50(stateBuffKeyV17)
    if (stateBuffKeyV17!="" && !GetKeyVK(stateBuffKeyV17) && !GetKeySC(stateBuffKeyV17))
        stateBuffKeyV17 := ""
    IniRead, pestilenceKeyV18, % ProfileConfigPathV364(section), %section%, PestilenceCastKey, %A_Space%
    pestilenceKeyV18 := PortalCastNormalizeV50(pestilenceKeyV18)
    if (pestilenceKeyV18!="" && !GetKeyVK(pestilenceKeyV18) && !GetKeySC(pestilenceKeyV18))
        pestilenceKeyV18 := ""
    IniRead, deathlordStateV19, % ProfileConfigPathV364(section), %section%, DeathlordStateID, %A_Space%
    IniRead, pestilenceStateV19, % ProfileConfigPathV364(section), %section%, PestilenceStateID, %A_Space%
    IniRead, pestilenceKeyV18, % ProfileConfigPathV364(section), %section%, PinnacleCastKey, %pestilenceKeyV18%
    IniRead, pestilenceStateV19, % ProfileConfigPathV364(section), %section%, PinnacleStateID, %pestilenceStateV19%
    pestilenceKeyV18 := PortalCastNormalizeV50(pestilenceKeyV18)
    IniRead, anathemaKeyV518, % ProfileConfigPathV364(section), %section%, AnathemaCastKey, %A_Space%
    anathemaKeyV518 := PortalCastNormalizeV50(anathemaKeyV518)
    if (anathemaKeyV518!="" && !GetKeyVK(anathemaKeyV518) && !GetKeySC(anathemaKeyV518))
        anathemaKeyV518 := ""
    IniRead, anathemaStateV518, % ProfileConfigPathV364(section), %section%, AnathemaStateID, %A_Space%
    anathemaStateV518 := Trim(anathemaStateV518)
    if (anathemaStateV518!="" && (!RegExMatch(anathemaStateV518,"^\d+$") || anathemaStateV518>4095))
        anathemaStateV518 := ""
    IniRead, townLevelV22, % ProfileConfigPathV364(section), %section%, TownLevelID, %A_Space%
    IniRead, outsideLevelV22, % ProfileConfigPathV364(section), %section%, OutsideLevelID, %A_Space%
    IniRead, buffGetTextV22, % ProfileConfigPathV364(section), %section%, BuffGetResult, %A_Space%
    deathlordStateV19 := Trim(deathlordStateV19), pestilenceStateV19 := Trim(pestilenceStateV19)
    townLevelV22 := Trim(townLevelV22), outsideLevelV22 := Trim(outsideLevelV22)
    if (KnownFarmLevelV522(townLevelV22))
    {
        wrongTownV522 := townLevelV22
        townLevelV22 := 40
        IniWrite, %townLevelV22%, % ProfileConfigPathV364(section), %section%, TownLevelID
        PortalLogWriteV66("PROFILE_TOWN_REPAIR profile=" . name . " old=" . wrongTownV522 . " town=40 reason=FARM_LEVEL_NOT_TOWN")
    }
    stateBuffCheckSecV17 := 3
    farmResumeArmedV70 := false, farmResumeOutsideV70 := false
    SetTimer, FarmResumeTimerV70, Off
    autoMonsterAttackOn := false
    cainNoFightV361 := false,cainPauseFarmV361 := false
    farmMapPauseV52 := false,farmLoadedMapV56 := false
    FarmCastSyncV88(false)
    SetTimer, AutoMonsterAttackTimer, Off
    IniRead, monsterExcludeClassesV11, % ProfileConfigPathV364(section), %section%, MonsterExcludeClasses, %A_Space%
    monsterExcludeClassesV11 := Trim(monsterExcludeClassesV11)
    IniRead, autoMonsterToggleKeyV13, % ProfileConfigPathV364(section), %section%, AutoMonsterToggleKey, %A_Space%
    IniRead, petLearnKeyV13, % ProfileConfigPathV364(section), %section%, PetLearnKey, '
    if (petLearnKeyV13=";")
        petLearnKeyV13 := "'"
    autoMonsterToggleKeyV13 := NormalizeMapHotkeyV178(autoMonsterToggleKeyV13)
    petLearnKeyV13 := NormalizeOptionalKey(petLearnKeyV13)
	    IniRead, petLearnEnabledV12, % ProfileConfigPathV364(section), %section%, PetLearnEnabled, 0
    petLearnEnabledV12 := petLearnEnabledV12=1
    if (ProfileControlExistsV365("PetLearnEnabledInputV12"))
        GuiControl, 1:, PetLearnEnabledInputV12, %petLearnEnabledV12%
    IniRead, coordGetKeyV14, % ProfileConfigPathV364(section), %section%, CoordGetKey, %A_Space%
    IniRead, coordPointTextV14, % ProfileConfigPathV364(section), %section%, CoordPoint, %A_Space%
    IniRead, coordPointLevelV14, % ProfileConfigPathV364(section), %section%, CoordLevel, 0
    coordGetKeyV14 := ""
    coordPointTextV14 := Trim(coordPointTextV14)
    RouteMapsLoadV21(name)
    RouteMapRefreshV21()
    CoordSavedLoadV15(name)
    CoordRouteResetV16()
    coordMoveDoneV14 := false, coordMoveTriesV14 := 0
    PetExcludeLoadV12()
    BossPriorityLoadV221(name)

    if (belt4HPKey != "" && belt4HPKey != "None")
        BackgroundHotkeyV63("~$" . belt4HPKey,"Belt4HPHandler","Off UseErrorLevel")
    if (belt2HP2ManaKey != "" && belt2HP2ManaKey != "None")
        BackgroundHotkeyV63("~$" . belt2HP2ManaKey,"Belt2HP2ManaHandler","Off UseErrorLevel")

    BackgroundHotkeyV63("~$" . zKey,"ZKeyHandler","Off")
    if (xKey != "")
        BackgroundHotkeyV63("~$" . xKey,"XKeyHandler","Off")
    ToolDoubleBindV18(doubleKey,"DoubleKeyHandler","Off")
    ToolDoubleBindV18(formDoubleKey,"FormDoubleKeyHandler","Off")
    ToolDoubleBindV18(qCastDoubleKey,"QCastDoubleKeyHandler","Off")
    if (rareWarningKeyV1 != "")
        BackgroundHotkeyV63("~$" . rareWarningKeyV1,"RareWarningGetHandlerV1","Off UseErrorLevel")
    if (invToCubeKey != "" && invToCubeKey != "None")
        BackgroundHotkeyV63("~$" . invToCubeKey,"InvToCubeHandler","Off")

    zKey := test
    IniRead, xKey, % ProfileConfigPathV364(section), %section%, XKey,
    IniRead, doubleKey, % ProfileConfigPathV364(section), %section%, DoubleKey, Left
    IniRead, doubleTapMs, % ProfileConfigPathV364(section), %section%, DoubleTapMs, 1000
    IniRead, formDoubleKey, % ProfileConfigPathV364(section), %section%, FormDoubleKey, Right
    IniRead, formDoubleTapMs, % ProfileConfigPathV364(section), %section%, FormDoubleTapMs, 1000
    qCastDoubleKey := "None"
    IniRead, qCastDoubleTapMs, % ProfileConfigPathV364(section), %section%, QCastDoubleTapMs, 1000
    IniRead, zSetKey, % ProfileConfigPathV364(section), %section%, ZSetKey,
    IniRead, zSetDelay, % ProfileConfigPathV364(section), %section%, ZSetDelay, 150
    IniRead, xDelay, % ProfileConfigPathV364(section), %section%, XDelay, 150
    IniRead, zFKey, % ProfileConfigPathV364(section), %section%, ZFKey,
    IniRead, zFKey2, % ProfileConfigPathV364(section), %section%, ZFKey2,
    IniRead, zDelay1, % ProfileConfigPathV364(section), %section%, ZDelay1, 150
    IniRead, zDelay2, % ProfileConfigPathV364(section), %section%, ZDelay2, 150
    IniRead, zDelay3, % ProfileConfigPathV364(section), %section%, ZDelay3, 500
    IniRead, autoPotOn, % ProfileConfigPathV364(section), %section%, AutoPotOn, 0
    IniRead, invHealOn, % ProfileConfigPathV364(section), %section%, InvHealOn, 0
    IniRead, cubeHealOn, % ProfileConfigPathV364(section), %section%, CubeHealOn, 0
    IniRead, invManaOn, % ProfileConfigPathV364(section), %section%, InvManaOn, %invHealOn%
    IniRead, cubeManaOn, % ProfileConfigPathV364(section), %section%, CubeManaOn, %cubeHealOn%
    IniRead, invToCubeKey, % ProfileConfigPathV364(section), %section%, InvToCubeKey, None
    invToCubeKey := NormalizeOptionalKey(invToCubeKey)
    
	IniRead, cubePickupDelayMs, % ProfileConfigPathV364(section), %section%, CubePickupDelayMs, 30
if cubePickupDelayMs is not integer
    cubePickupDelayMs := 30
if (cubePickupDelayMs < 10 || cubePickupDelayMs > 5000)
    cubePickupDelayMs := 30
    
	IniRead, cubeTransferDelayMs, % ProfileConfigPathV364(section), %section%, CubeTransferDelayMs, 30
if cubeTransferDelayMs is not integer
    cubeTransferDelayMs := 30
if (cubeTransferDelayMs < 10 || cubeTransferDelayMs > 5000)
    cubeTransferDelayMs := 30
	
	IniRead, belt4HPKey, % ProfileConfigPathV364(section), %section%, Belt4HPKey, None
    IniRead, belt2HP2ManaKey, % ProfileConfigPathV364(section), %section%, Belt2HP2ManaKey, None
    belt4HPKey := NormalizeOptionalKey(belt4HPKey)
    belt2HP2ManaKey := NormalizeOptionalKey(belt2HP2ManaKey)
    IniRead, potMode, % ProfileConfigPathV364(section), %section%, PotMode, Auto(1-4)
    IniRead, potCaptureKey1, % ProfileConfigPathV364(section), %section%, PotCaptureKey1, n
    IniRead, potHPThreshold, % ProfileConfigPathV364(section), %section%, PotHPThreshold, 7000
    hp2DefaultV299 := Max(1,Floor(potHPThreshold/2))
    IniRead, potHPThreshold2V299, % ProfileConfigPathV364(section), %section%, PotHPThreshold2, %hp2DefaultV299%
    IniRead, potCooldown, % ProfileConfigPathV364(section), %section%, PotCooldown, 3000
    if (!RegExMatch(potCooldown,"^\d+$") || potCooldown<1)
        potCooldown := 3000
    IniRead, manaOn, % ProfileConfigPathV364(section), %section%, ManaOn, 0
    IniRead, manaMode, % ProfileConfigPathV364(section), %section%, ManaMode, Auto(1-4)
    IniRead, manaThreshold, % ProfileConfigPathV364(section), %section%, ManaThreshold, 1000
    IniRead, manaCooldown, % ProfileConfigPathV364(section), %section%, ManaCooldown, 3000
    pickupImageOn := true
    IniWrite, 1, % ProfileConfigPathV364(section), %section%, PickupImageOn
    ; Checkbox Cube đã bỏ: nhặt thường luôn ưu tiên Cube (vẫn giữ các luồng rương chuyên biệt).
    pickupToCubeV37 := true
    IniRead, pickupDestinationV119, % ProfileConfigPathV364(section), %section%, PickupDestination,
    pickupGroupOnlyV26 := ""
    if (pickupDestinationV119!="STASH" && pickupDestinationV119!="CUBE")
        pickupDestinationV119 := ""
    pickupBackgroundV181 := false
    libAutoTicketV293 := {}
    for _,tierV293 in [130,133,136,139]
    {
        IniRead, enabledV293, % ProfileConfigPathV364(section), %section%, LibAutoTicket%tierV293%, 0
        libAutoTicketV293[tierV293] := enabledV293=1
        if (ProfileControlExistsV365("LibAutoTicket" . tierV293 . "V293"))
            GuiControl,, LibAutoTicket%tierV293%V293, % enabledV293=1
    }
    global farmEntrySigV315,farmEntryGoldV315
    IniRead, farmEntrySigV315, % ProfileConfigPathV364(section), %section%, FarmEntrySig, 1
    IniRead, farmEntryGoldV315, % ProfileConfigPathV364(section), %section%, FarmEntryGold, 1
    farmEntrySigV315 := farmEntrySigV315=1,farmEntryGoldV315 := farmEntryGoldV315=1
    if (ProfileControlExistsV365("FarmEntrySigCheckV315"))
        GuiControl,, FarmEntrySigCheckV315, %farmEntrySigV315%
    if (ProfileControlExistsV365("FarmEntryGoldCheckV347"))
        GuiControl,, FarmEntryGoldCheckV347, %farmEntryGoldV315%
    IniRead, farmResetWatchEnabledV217, % ProfileConfigPathV364(section), %section%, FarmBrainResetWatch, 0
    farmResetWatchEnabledV217 := (farmResetWatchEnabledV217=1)
    IniRead, farmResetWatchMinutesV217, % ProfileConfigPathV364(section), %section%, FarmBrainResetMinutes, __MISSING__
    if (farmResetWatchMinutesV217="__MISSING__")
    {
        IniRead, resetLegacySecsV53, % ProfileConfigPathV364(section), %section%, FarmBrainResetSecs, 60
        if resetLegacySecsV53 is not integer
            resetLegacySecsV53 := 60
        farmResetWatchMinutesV217 := Ceil(Max(60,Min(3600,resetLegacySecsV53))/60)
        IniWrite, %farmResetWatchMinutesV217%, % ProfileConfigPathV364(section), %section%, FarmBrainResetMinutes
    }
    if farmResetWatchMinutesV217 is not integer
        farmResetWatchMinutesV217 := 1
    farmResetWatchMinutesV217 := Max(1,Min(60,farmResetWatchMinutesV217))
    IniRead, farmNaoKeyV181, % ProfileConfigPathV364(section), %section%, FarmNaoKey,
farmNaoKeyV181 := NormalizeMapHotkeyV178(farmNaoKeyV181)
FarmNaoBindV184()
IniRead, libScrollTierV290, % ProfileConfigPathV364(section), %section%, LibScrollTier, 130
if (libScrollTierV290!=130 && libScrollTierV290!=133 && libScrollTierV290!=136 && libScrollTierV290!=139)
    libScrollTierV290 := 130
IniRead, farmControlOwnerV186, % ProfileConfigPathV364(section), %section%, FarmControlOwner,
if (farmControlOwnerV186!="SCOS" && farmControlOwnerV186!="NAO" && farmControlOwnerV186!="CYC"
    && farmControlOwnerV186!="UBU" && farmControlOwnerV186!="M3000"
    && farmControlOwnerV186!="TRAN" && farmControlOwnerV186!="CAIN" && farmControlOwnerV186!="LIB" && farmControlOwnerV186!="BO" && farmControlOwnerV186!="VIZ")
    farmControlOwnerV186 := ""
IniRead, fautLab1V309, % ProfileConfigPathV364(section), %section%, FautLab1, 0
fautLab1V309 := fautLab1V309=1
IniRead, labNumberV314, % ProfileConfigPathV364(section), %section%, LabNumber, 1
if (labNumberV314<1 || labNumberV314>10)
    labNumberV314 := 1
IniRead, continuousMapV168, % ProfileConfigPathV364(section), %section%, ContinuousMap, 0
continuousMapV168 := continuousMapV168=1
IniRead, autoLoadMapV340, % ProfileConfigPathV364(section), %section%, AutoLoadMap, 1
autoLoadMapV340 := autoLoadMapV340=1
IniRead, sigTownLogTestEnabledV148, % ProfileConfigPathV364(section), %section%, SigTownLogTest, 1
sigTownLogTestEnabledV148 := sigTownLogTestEnabledV148=1
IniRead, sigCubeCaptureEnabledV151, % ProfileConfigPathV364(section), %section%, SigCubeCapture, 0
sigCubeCaptureEnabledV151 := sigCubeCaptureEnabledV151=1
IniRead, roomSavedReplayEnabledV116, % ProfileConfigPathV364(section), %section%, RoomSavedReplay, 0
roomSavedReplayEnabledV116 := roomSavedReplayEnabledV116=1
IniRead, pickupColorVariation, % ProfileConfigPathV364(section), %section%, PickupColorVariation, 60
IniRead, farmWatchdogSecondsV578, % ProfileConfigPathV364(section), %section%, FarmBrainWatchdogSecs, 60
IniRead, stateBuffCheckSecV17, % ProfileConfigPathV364(section), %section%, StateBuffCheckSec, 3
    IniRead, pickupStashKeyV14, % ProfileConfigPathV364(section), %section%, PickupStashKey, ^0
    IniRead, pickupSetKeyV14, % ProfileConfigPathV364(section), %section%, PickupSetKey, ^5
    IniRead, pickupSUKeyV14, % ProfileConfigPathV364(section), %section%, PickupSUKey, ^7
    pickupStashKeyV14 := NormalizeMapHotkeyV178(pickupStashKeyV14)
    ; Sửa cấu hình bị bản 48 đổi nhầm từ ^0 sang !0; vẫn là Ctrl+0.
    if (pickupStashKeyV14="!0")
    {
        pickupStashKeyV14 := "^0"
        IniWrite, %pickupStashKeyV14%, % ProfileConfigPathV364(section), %section%, PickupStashKey
    }
    pickupSetKeyV14 := NormalizeMapHotkeyV178(pickupSetKeyV14)
    pickupSUKeyV14 := NormalizeMapHotkeyV178(pickupSUKeyV14)
    PickupGroupBindV14()
    IniRead, sigTUV586, % ProfileConfigPathV364(section), %section%, SigTU, 0
    IniRead, sigSUV510, % ProfileConfigPathV364(section), %section%, SigSU, 0
    IniRead, sigSSUV13, % ProfileConfigPathV364(section), %section%, SigSSU, 0
    sigSSSUV13 := false
    sigTUV586 := sigTUV586=1, sigSUV510 := sigSUV510=1, sigSSUV13 := sigSSUV13=1, sigSSSUV13 := false
    IniRead, sigSuKeyV181, % ProfileConfigPathV364(section), %section%, SigSuKey,
    sigSuKeyV181 := NormalizeMapHotkeyV178(sigSuKeyV181)
    SigSuBindV181()
    IniRead, sigKeyV147, % ProfileConfigPathV364(section), %section%, SigKey,
    sigKeyV147 := NormalizeMapHotkeyV178(sigKeyV147)
    SigBindV147()
    IniRead, itemInspectKeyV287, % ProfileConfigPathV364(section), %section%, ItemInspectKey,
    itemInspectKeyV287 := NormalizeMapHotkeyV178(itemInspectKeyV287)
    ItemInspectBindV287()
    IniRead, pickupToggleKeyV79, % ProfileConfigPathV364(section), %section%, PickupToggleKey,
    pickupToggleKeyV79 := NormalizeOptionalKey(pickupToggleKeyV79)
    PickupToggleBindV79()
    getIdKey := ""
    rareWarningKeyV1 := ""
    rareWarningKeyV1 := NormalizeOptionalKey(rareWarningKeyV1)
    IniRead, rareWarningHiddenV19, % ProfileConfigPathV364(section), %section%, RareWarningHidden, 0
    rareWarningHiddenV19 := rareWarningHiddenV19=1
    if (ProfileControlExistsV365("RareWarningHideInputV19"))
        GuiControl,, RareWarningHideInputV19, %rareWarningHiddenV19%
    IniRead, excludeModeV329, % ProfileConfigPathV364(section), %section%, ExcludeMode, 0
    IniRead, excludeDeleteModeV332, % ProfileConfigPathV364(section), %section%, ExcludeDeleteMode, 0
    excludeModeV329 := excludeModeV329=1
    excludeDeleteModeV332 := excludeDeleteModeV332=1
    if (ProfileControlExistsV365("ExcludeModeV329"))
        GuiControl, 1:, ExcludeModeV329, %excludeModeV329%
    if (ProfileControlExistsV365("ExcludeDeleteModeV332"))
        GuiControl, 1:, ExcludeDeleteModeV332, %excludeDeleteModeV332%
    RareWarningRenderV16()
    deleteIdKey := ""
    IniRead, pickupRadius, % ProfileConfigPathV364(section), %section%, PickupRadius, 4
    IniRead, pickupFailTeleRadiusV1253, % ProfileConfigPathV364(section), %section%, PickupFailTeleRadius, 4
    if (!RegExMatch(pickupFailTeleRadiusV1253,"^\d+$") || pickupFailTeleRadiusV1253<1 || pickupFailTeleRadiusV1253>100)
        pickupFailTeleRadiusV1253 := 4
    pickupFailTeleRadiusV1253 += 0
    if (ProfileControlExistsV365("PickupFailTeleRadiusInputV1253"))
        GuiControl, 1:, PickupFailTeleRadiusInputV1253, %pickupFailTeleRadiusV1253%
    pickupRadius += 0
    if (pickupRadius < 1)
        pickupRadius := 4
    pickupLastClick := 0
    manaLastDrink := 0
    healExhausted := {HP: {Cube: false, Ruong: false, Belt: false}
        , Mana: {Cube: false, Ruong: false, Belt: false}}
    potCycle := 1
    potFarCount := 0
    
    Loop, 10
    {
        index := A_Index
        IniRead, tempKey, % ProfileConfigPathV364(section), %section%, FKey%index%,
        IniRead, tempDelay, % ProfileConfigPathV364(section), %section%, FDelay%index%, 0
        FKey%index% := NormalizeOptionalKey(tempKey)
        FDelay%index% := tempDelay
    }

    ClearExtraFRows()
    Loop, 3
    {
        index := A_Index
        IniRead, tempKey, % ProfileConfigPathV364(section), %section%, QCastKey%index%,
        IniRead, tempDelay, % ProfileConfigPathV364(section), %section%, QCastDelay%index%, 0
        QCastKey%index% := tempKey
        QCastDelay%index% := tempDelay
    }


    LoadClickCastConfig(section)
    if (zKey != "")
        BackgroundHotkeyV63("~$" . zKey,"ZKeyHandler","On")
    if (xKey != "")
        BackgroundHotkeyV63("~$" . xKey,"XKeyHandler","On")
    ToolDoubleBindV18(doubleKey,"DoubleKeyHandler","On")
    ToolDoubleBindV18(formDoubleKey,"FormDoubleKeyHandler","On")
    ToolDoubleBindV18(qCastDoubleKey,"QCastDoubleKeyHandler","On")
    if (rareWarningKeyV1 != "")
        BackgroundHotkeyV63("~$" . rareWarningKeyV1,"RareWarningGetHandlerV1","On")
    if (invToCubeKey != "")
        BackgroundHotkeyV63("~$" . invToCubeKey,"InvToCubeHandler","On")

    if (belt4HPKey != "")
        BackgroundHotkeyV63("~$" . belt4HPKey,"Belt4HPHandler","On")
    if (belt2HP2ManaKey != "")
        BackgroundHotkeyV63("~$" . belt2HP2ManaKey,"Belt2HP2ManaHandler","On")

    farmBuffModeV509 := 0
    QCastOn := false,clickCastOn := false,cycleOn := false
    Master456StateLoadV121(name)
    cycleStep := 1
    nextStepTime := 0
    AutoMonsterAttackApplyStateV4()
}
