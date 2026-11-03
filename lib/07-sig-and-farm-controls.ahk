RoomWaitV90(pid,px,py,level)
{
    global coordSavedV15, coordRouteV16, monsterRetryUntilV44
    if (!IsObject(coordRouteV16) || coordRouteV16.phase!="DONE" || coordSavedV15.Length()!=1)
    {
        coordSavedV15 := [{x:px,y:py,level:level}]
        savedRetry := monsterRetryUntilV44
        CoordRouteResetV16()
        monsterRetryUntilV44 := savedRetry
        coordRouteV16.pid := pid, coordRouteV16.anchor := 1, coordRouteV16.next := 1, coordRouteV16.phase := "DONE"
    }
}


RoomAllLiveV93(h,r,currentRoom1,px,py)
{
    result := {best:false,count:0,incomplete:false}, bestDist := 1.0e30
    rooms := MonsterLoadedRoomsV20(h,currentRoom1)
    for _,room1 in rooms
    {
        room2 := D2ReadU32(h,room1+0x10)
        if (room2!=r.current)
            continue
        node := RoomExploreReadV89(h,room2,r.level)
        if (!IsObject(node) || !node.r1)
        {
            result.incomplete := true
            continue
        }
        scan := RoomLiveGoalV90(h,node,px,py)
        result.count += scan.count
        if (scan.incomplete)
            result.incomplete := true
        if (IsObject(scan.best))
        {
            d := (scan.best.x-px)**2+(scan.best.y-py)**2
            if (d<bestDist)
            {
                result.best := scan.best, result.best.room2 := room2
                bestDist := d
            }
        }
    }
    return result
}


RoomClearBuffBeginV96(h,player,pid,r,room2)
{
    global coordCastPendingV50, portalBuffV85, coordRouteV16, monsterCombatUidV45, monsterChaseV44, portalCastKeyV50
    monsterCombatUidV45 := 0, monsterChaseV44 := false
    coordRouteV16.escapeV84 := false, coordRouteV16.stuckProbe := false
    coordCastPendingV50 := true
    CoordCastTickV50(h,player,pid,true)
    if (!coordCastPendingV50)
    {
        r.clearBuffDone[room2] := true, r.pendingClearRoom := 0, r.roomPortalCount := 0
        AutoMonsterAttackLogV2("ROOM_CLEAR_PORTAL room2=" . V92Hex(room2) . " key=" . portalCastKeyV50
            . " pipeline=ORIGINAL_COORD_CAST buff_pending=" . IsObject(portalBuffV85)
            . " order=STEP_BACK_PORTAL_MOVE_AWAY_X_Z_F_NEXT_ROOM effect=UNCONFIRMED")
    }
    return true
}


CoordTeleBlockedV96(reason)
{
    global teleportKeyV55, coordRouteV16
    AutoMonsterAttackLogV2("STUCK_TELEPORT_BLOCKED reason=" . reason . " key=" . (teleportKeyV55="" ? "EMPTY" : teleportKeyV55)
        . " phase=" . coordRouteV16.phase . " anchor=" . coordRouteV16.anchor . " next=" . coordRouteV16.next)
    return false
}


ItemInspectKeyChangedV287:
ItemInspectKeySaveV287()
return

ItemInspectButtonV287:
if (!ItemInspectKeySaveV287())
    return
GuiControl,, ItemInspectResultV287, % "Đưa chuột vào vật phẩm trong 2 giây."
SetTimer, ItemInspectDelayedV287, -2000
return

ItemInspectDelayedV287:
ItemInspectReadV287()
return

ItemInspectHotkeyV287:
if (!IsGameForegroundV63())
    return
SetTimer, ItemInspectDelayedV287, Off
ItemInspectReadV287()
return

ItemInspectReadV287()
{
    global excludeModeV329, excludeDeleteModeV332
    if (PickupEditorGetV638())
        return
    if (excludeModeV329)
        result := PickupExcludeAddV329()
    else if (excludeDeleteModeV332)
        result := PickupExcludeRemoveV332()
    else
        result := ItemInspectHoverV288()
    GuiControl, 1:, ItemInspectResultV287, %result%
}

ItemInspectHoverV288()
{
    pid := D2GetActiveGamePidV95()
    if (!pid)
        return "GET: chưa nhận được cửa sổ game."
    MouseGetPos,,,hoverWindow
    WinGet, hoverPid, PID, ahk_id %hoverWindow%
    if (hoverPid!=pid)
        return "GET: chuột chưa ở trên cửa sổ game."
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return "GET: không mở được bộ nhớ D2Client."
    try
    {
        selectedAddr := base+0x11B834
        unit := D2ReadU32(h,selectedAddr)
        if (!unit)
            return "GET: con trỏ vật = 0. Rê lên vật để hiện tên rồi bấm phím GET."
        if (!MonsterBossProbeReadV1(h,unit,0x18,ub))
            return "GET: không đọc được vật đang trỏ."
        kind := NumGet(ub,0,"UInt"),classId := NumGet(ub,4,"UInt"),uid := NumGet(ub,12,"UInt")
        if (kind>5 || classId>65535 || !uid)
            return "GET: dữ liệu vật không hợp lệ."
        if (kind!=4)
            return "CLASS: " . classId . "`nTYPE: " . kind . " | UID: " . uid . "`nĐối tượng này không phải vật phẩm."
        itemData := NumGet(ub,0x14,"UInt")
        if (!itemData || !MonsterBossProbeReadV1(h,itemData,4,ib))
            return "GET: không đọc được ITEMDATA."
        quality := NumGet(ib,0,"UInt")
        if (quality<1 || quality>9)
            return "GET: ITEMDATA không hợp lệ: " . quality
        if (D2ReadU32(h,selectedAddr)!=unit)
            return "GET: đã đổi vật dưới chuột; bấm lại."
        return "CLASS: " . classId . "`nITEMDATA: " . Format("{:02X}",quality) . "`nUID: " . uid
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}
ExcludeModeChangedV329:
GuiControlGet, excludeModeV329,, ExcludeModeV329
excludeModeV329 := excludeModeV329 ? true : false
if (excludeModeV329 && excludeDeleteModeV332)
{
    excludeDeleteModeV332 := false
    GuiControl, 1:, ExcludeDeleteModeV332, 0
}
ToolTipInfoV386(excludeModeV329 ? "GET = lưu CLASS vào DS loại trừ" : "GET = xem CLASS/ITEMDATA")
SetTimer, RemoveToolTip, -1500
return

ExcludeDeleteModeChangedV332:
GuiControlGet, excludeDeleteModeV332,, ExcludeDeleteModeV332
excludeDeleteModeV332 := excludeDeleteModeV332 ? true : false
if (excludeDeleteModeV332 && excludeModeV329)
{
    excludeModeV329 := false
    GuiControl, 1:, ExcludeModeV329, 0
}
ToolTipInfoV386(excludeDeleteModeV332 ? "GET = XÓA CLASS khỏi DS loại trừ" : "GET = xem CLASS/ITEMDATA")
SetTimer, RemoveToolTip, -1500
return

PickupExcludeFileV329()
{
    return TxtRootPathV816("Item-Nhat-Loai-Tru.txt")
}

; V57: Name|ClassID|Quality (hoac Name|ClassID voi dong cu khong co Quality)
; van LOAI TRU THEO CLASS nhu truoc, khong doi quy tac nhat.
PickupExcludeLineClassV57(line,ByRef cls)
{
    cls := 0
    line := Trim(line," `t`r`n" . Chr(0xFEFF))
    if (RegExMatch(line,"i)^CLASS\s*=\s*(\d+)(?:\s*\||\s*$)",m))
        cls := m1+0
    else if (RegExMatch(line,"^[^|]+\|\s*(\d+)(?:\s*\|.*)?$",m))
        cls := m1+0
    return cls>0 && cls<65536
}

PickupExcludeLoadV329()
{
    global pickupExcludeClassesV329,pickupExcludeRulesV490,pickupExcludeGroupsV491,pickupOptRevisionV12,pickupRoundResetV1
    pickupOptRevisionV12++,pickupRoundResetV1 := true
    file := PickupExcludeFileV329()
    set := {},pickupExcludeRulesV490 := [],pickupExcludeGroupsV491 := {}
    if (FileExist(file))
    {
        FileRead, raw, %file%
        Loop, Parse, raw, `n, `r
        {
            line := Trim(A_LoopField," `t`r`n" . Chr(0xFEFF))
            if (line="" || SubStr(line,1,1)="#")
                continue
            if (PickupExcludeLineClassV57(line,excludedClsV57))
                set[excludedClsV57] := true
            else
            {
    group := PickupAutoGroupParseV7(line)
    if (group!="" && SubStr(group,1,5)!="NAME:" && !PickupOptIsRuleV12(line))
        pickupExcludeGroupsV491[group] := true
    else if (SubStr(group,1,5)="NAME:")
    {
        targetName := SubStr(group,6)
        for _, info in pickupOptCacheV12
            if (info.ok && info.HasKey("cls") && PickupNameNormalizeV8(info.name) = targetName)
            {
                set[info.cls] := true
                break
            }
    }
    if (!PickupExcludeLineClassV57(line,excludedRuleClsV57)
        && IsObject(rule := PickupOptParseV12(line,error)))
        pickupExcludeRulesV490.Push(rule)
}
        }
    }
    pickupExcludeClassesV329 := set
    return set.Count()
}

PickupExcludeAddV329()
{
    global pickupExcludeClassesV329
    pid := D2GetActiveGamePidV95()
    if (!pid)
        return "GET: chưa nhận được cửa sổ game."
    MouseGetPos,,,hoverWin
    WinGet, hoverPid, PID, ahk_id %hoverWin%
    if (hoverPid!=pid)
        return "GET: chuột chưa ở trên cửa sổ game."
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return "GET: không mở được bộ nhớ D2Client."
    try
    {
        unit := D2ReadU32(h, base+0x11B834)
        if (!unit || !MonsterBossProbeReadV1(h,unit,0x18,ub))
            return "GET: con trỏ vật = 0. Rê lên vật rồi bấm lại."
        cls := NumGet(ub,4,"UInt"), uid := NumGet(ub,12,"UInt"), kind := NumGet(ub,0,"UInt")
        if (!cls || !uid || cls>65535 || kind>5)
            return "GET: dữ liệu vật không hợp lệ."
        name := kind=4 ? PickupExcludeReadNameV717(h,pid,unit,cls,uid) : ""
        if (kind=4 && name="")
            return "GET: chưa đọc được tên món; chưa thêm. Giữ chuột trên món rồi bấm lại."
        file := PickupExcludeFileV329(),raw := ""
        if (FileExist(file) && !RareWarningReadTextV35(file,raw,false))
            return "GET: không đọc được file loại trừ."
        ; GET item: dung cung thu tu ten|class|quality nhu danh sach nhat.
        ; Khong nham KIND=4 (loai unit) thanh quality cua vat pham.
        if (kind=4)
        {
            dataV57 := D2ReadU32(h,unit+0x14)
            qualityV57 := dataV57 ? D2ReadU8V18(h,dataV57) : 0
            if (qualityV57<1 || qualityV57>9)
                return "GET: khong doc duoc quality; chua luu vao loai tru."
            newLineV57 := name . "|" . cls . "|" . Format("{:02d}",qualityV57)
        }
        else
            newLineV57 := "CLASS=" . cls
        raw := PickupExcludeNormalizeV717(raw),content := "",found := false
        Loop, Parse, raw, `n, `r
        {
            existing := Trim(A_LoopField)
            if (existing="")
                continue
            if (PickupExcludeLineClassV57(existing,oldClsV57) && oldClsV57=cls)
            {
                if (!found)
                    content .= newLineV57 . "`r`n"
                found := true
            }
            else
                content .= existing . "`r`n"
        }
        if (!found)
            content .= newLineV57 . "`r`n"
        if (!RareWarningWriteTextV35(file,content))
            return "GET: không ghi được file loại trừ."
        PickupExcludeLoadV329()
        synced := PickupCanonicalExcludeSyncV491()
        return (found ? "ĐÃ CẬP NHẬT: " : "ĐÃ LOẠI TRỪ: ") . (name!="" ? name . " — " : "")
            . "CLASS " . cls . (synced ? "" : " — đã lưu, chưa đồng bộ ô danh sách.")
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}
PickupExcludeReadNameV717(h,pid,unit,cls,uid)
{
    global sigBusyV147,xRunning,zRunning
    if (sigBusyV147 || xRunning || zRunning)
        return ""
    data := D2ReadU32(h,unit+0x14)
    if (!data)
        return ""
    quality := D2ReadU8V18(h,data),seed := D2ReadU32(h,data+0x14),started := A_TickCount
    if (quality<1 || quality>9)
        return ""
    Loop
    {
        if (D2GetActiveGamePidV95()!=pid || D2ReadU32(h,unit)!=4 || D2ReadU32(h,unit+4)!=cls
            || D2ReadU32(h,unit+0x0C)!=uid || D2ReadU32(h,unit+0x14)!=data
            || D2ReadU32(h,data+0x14)!=seed)
            return ""
        PickupOptPollV12()
        info := PickupOptReadV12(h,unit,cls,quality,data,D2ReadU32(h,data+0x18))
        if (IsObject(info) && info.ok)
        {
            name := PickupGetNameV638(info.name)  ; GET exclude: chi lay ten item, khong lay dong option/stat
                        if (quality=7)
            {
                un := PickupUniqueStringNameV766(h,pid,data)
                if (un!="")
                    name := un
            }
            else if (quality=5)
            {
                tmpCtx := {h:h,pid:pid,setNoSigNamesV227:[],setNameCacheV227:{},setKeepLoggedV227:{}}
                sn := SigSetNameV227(tmpCtx,{unit:unit,uid:uid,cls:cls,data:data})
                if (sn!="")
                    name := sn
            }
			if (name!="")
                return name
        }
        if (A_TickCount-started>=3000)
            return ""
        Sleep, 30
    }
}

PickupExcludeRemoveV332()
{
    global pickupExcludeClassesV329
    pid := D2GetActiveGamePidV95()
    if (!pid)
        return "GET: chưa nhận được cửa sổ game."
    MouseGetPos,,,hoverWin
    WinGet, hoverPid, PID, ahk_id %hoverWin%
    if (hoverPid!=pid)
        return "GET: chuột chưa ở trên cửa sổ game."
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return "GET: không mở được bộ nhớ D2Client."
    try
    {
        unit := D2ReadU32(h, base+0x11B834)
        if (!unit || !MonsterBossProbeReadV1(h,unit,0x18,ub))
            return "GET: con trỏ vật = 0. Rê lên vật rồi bấm lại."
        cls := NumGet(ub,4,"UInt"), uid := NumGet(ub,12,"UInt"), kind := NumGet(ub,0,"UInt")
        if (!cls || !uid || cls>65535 || kind>5)
            return "GET: dữ liệu vật không hợp lệ."
        if (!pickupExcludeClassesV329.HasKey(cls))
            return "CLASS " . cls . " không có trong DS loại trừ."
        file := PickupExcludeFileV329()
        if (!FileExist(file))
            return "GET: file loại trừ không tồn tại."
        FileRead, raw, %file%
        content := "", removed := 0
        Loop, Parse, raw, `n, `r
        {
            line := Trim(A_LoopField)
            if (line="")
                continue
            if (PickupExcludeLineClassV57(line,oldClsV57) && oldClsV57=cls)
            {
                removed++
                continue
            }
            content .= line . "`r`n"
        }
        if (!removed)
            return "GET: không tìm thấy dòng CLASS " . cls . " để xóa."
        f := FileOpen(file,"w","UTF-8")
        if (!IsObject(f))
            return "GET: không ghi được file loại trừ."
        f.Write(content)
        f.Close()
        pickupExcludeClassesV329.Delete(cls)
        PickupCanonicalExcludeSyncV491()
        return "ĐÃ XÓA: CLASS " . cls . " (" . removed . " dòng)"
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}
ItemInspectKeySaveV287()
{
    global itemInspectKeyV287,ConfigFile,currentProfile
    GuiControlGet, key,, ItemInspectKeyInputV287
    key := NormalizeMapHotkeyV178(key)
    if (!UtilityKeyValidV181(key,"ItemInspectKeyInputV287"))
        return false
    itemInspectKeyV287 := key
    section := ProfileSection(currentProfile)
    IniWrite, %itemInspectKeyV287%, % ProfileConfigPathV364(section), %section%, ItemInspectKey
    ItemInspectBindV287()
    return true
}

ItemInspectBindV287()
{
    global itemInspectKeyV287
    static previous := ""
    if (previous!="")
        BackgroundHotkeyV63("$" . previous,"ItemInspectHotkeyV287","Off UseErrorLevel")
    for _,process in ["Game.exe","Diablo II.exe","D2.exe"]
    {
        criterion := "ahk_exe " . process
        Hotkey, IfWinActive, %criterion%
        if (previous!="")
            Hotkey, % "$" . previous, ItemInspectHotkeyV287, Off UseErrorLevel
        if (itemInspectKeyV287!="")
            Hotkey, % "$" . itemInspectKeyV287, ItemInspectHotkeyV287, On UseErrorLevel
    }
    Hotkey, IfWinActive
    previous := itemInspectKeyV287
}

SigKeyChangedV147:
if (!sigBusyV147)
    SigKeySaveV147()
return

SigButtonV147:
if (sigBusyV147 || IsObject(ticketPickupWaitV279))
{
    sigCancelV147 := true ; Nut Huy la chu dong cua nguoi dung.
    return
}
if (!SigKeySaveV147())
    return
SigStartBackgroundV183("BOTH")
return

SigHotkeyV147:
if (!IsGameForegroundV63())
    return
sigWaitV147 := RegExReplace(sigKeyV147,"^[~*$<>!^+#]+")
KeyWait, %sigWaitV147%
if (!IsGameForegroundV63())
    return
SigStartBackgroundV183("BOTH")
return

SigKeySaveV147()
{
    global sigKeyV147,ConfigFile,currentProfile
    GuiControlGet, key,, SigKeyInputV147
    key := NormalizeMapHotkeyV178(key)
    if (!UtilityKeyValidV181(key,"SigKeyInputV147"))
        return false
    sigKeyV147 := key
    section := ProfileSection(currentProfile)
    IniWrite, %sigKeyV147%, % ProfileConfigPathV364(section), %section%, SigKey
    SigBindV147()
    return true
}

SigBindV147()
{
    global sigKeyV147,sigSuKeyV181,farmNaoKeyV181,pickupBackgroundV181
    static previous := ""
    if (previous!="")
        BackgroundHotkeyV63("$" . previous,"SigHotkeyV147","Off UseErrorLevel")
    previous := sigKeyV147
    if (previous!="")
        BackgroundHotkeyV63("$" . previous,"SigHotkeyV147","On UseErrorLevel")
}

SigLogV147(text)
{
    DebugTraceWrite("cube","SIG " . text)
}

SigFailV147(reason)
{
    throw Exception(reason)
}

SigOpenContextV149()
{
    if (!IsGameActive())
        SigFailV147("Không còn cửa sổ game trước khi mở phiên Sig")
    pid := D2GetActiveGamePidV95()
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    if (!base)
        SigFailV147("Không đọc được D2Client.dll cho Sig; PID=" . pid)
    h := D2OpenProcess(pid)
    if (!h)
        SigFailV147("Không mở được bộ nhớ game cho Sig; PID=" . pid)
    try
    {
        player := SigReadU32V149(h,base + 0x11BBFC,"PLAYER")
        if (!player)
            SigFailV147("Con trỏ nhân vật chưa sẵn sàng sau khi về thành")
        inv := SigReadU32V149(h,player+0x60,"INVENTORY")
        if (!inv)
            SigFailV147("Con trỏ rương chưa sẵn sàng sau khi về thành")
        first := SigReadU32V149(h,inv+0x10,"FIRST_ITEM")
        SigLogV147("CONTEXT pid=" . pid . " base=" . Format("{:08X}",base)
            . " player=" . Format("{:08X}",player) . " inv=" . Format("{:08X}",inv))
        serialV761 := SigProtectionArmV761(pid)
        return {pid:pid,h:h,d2base:base,player:player,inv:inv,first:first,sigSessionV761:serialV761}
    }
    catch e
    {
        DllCall("CloseHandle","Ptr",h)
        throw e
    }
}

SigReadU32V149(h,address,label)
{
    VarSetCapacity(value,4,0),got := 0
    ok := DllCall("ReadProcessMemory","Ptr",h,"Ptr",address,"Ptr",&value,"UPtr",4,"UPtr*",got)
    err := A_LastError
    if (!ok || got!=4)
    {
        SigLogV147("READ_FAIL field=" . label . " address=" . Format("{:08X}",address)
            . " bytes=" . got . " error=" . err)
        SigFailV147("Không đọc được bộ nhớ Sig: " . label . "; lỗi=" . err)
    }
    return NumGet(&value,0,"UInt")
}

SigCheckV147(ctx)
{
    global sigCancelV147,scosEntryV162,autoMonsterAttackOn,backgroundPidV63,sigSessionSerialV761
    if (ctx.HasKey("sigSessionV761") && ctx.sigSessionV761!=sigSessionSerialV761)
        SigFailV147("Phiên SIG cũ đã kết thúc; không thao tác lên game mới")
    if (ctx.farmSortV253)
    {
        if (!autoMonsterAttackOn || !BackgroundValidV63() || ctx.pid!=backgroundPidV63
            || D2GetActiveGamePidV95()!=ctx.pid)
            SigFailV147("Đã dừng phiên Sort Cube khi farm")
        return
    }
    if (ctx.scosEntry)
    {
        if (!IsObject(scosEntryV162) || scosEntryV162.pid!=ctx.pid
            || (IsObject(ctx.entryStateV42) && scosEntryV162!=ctx.entryStateV42)
            || !BackgroundValidV63() || D2GetActiveGamePidV95()!=ctx.pid)
            throw Exception("Đã dừng phiên vào map")
        return
    }
    if (IsObject(ctx.ticketEntryV293) && (!IsObject(scosEntryV162) || scosEntryV162!=ctx.ticketEntryV293))
        SigFailV147("Đã dừng phiên tạo vé vào map")
    if (sigCancelV147)
        SigFailV147("Đã hủy Sig")
    if (!IsGameActive() || D2GetActiveGamePidV95()!=ctx.pid)
        SigFailV147("Dừng Sig: cửa sổ/phiên game không còn hợp lệ")
}

SigSnapshotV147(ctx)
{
    SigCheckV147(ctx)
    ctx.first := D2ReadU32(ctx.h,ctx.inv+0x10)
    result := V9SnapshotAllItems(ctx)
    for uid,item in result
    {
        item.uid := uid
        item.q := D2ReadU8V18(ctx.h,item.data)
    }
    return result
}

SigGroundV147(ctx,radius:=0)
{
    global pickupRadius
    SigCheckV147(ctx)
    scanRadiusV147 := radius>0 ? radius : Max(1,pickupRadius)
    result := {}, seen := {}
    path := D2ReadU32(ctx.h,ctx.player+0x2C)
    room := path ? D2ReadU32(ctx.h,path+0x1C) : 0
    px := D2ReadU16(ctx.h,path+2), py := D2ReadU16(ctx.h,path+6)
    if (!room)
        SigFailV147("Không đọc được phòng nhân vật")
    for _,r in ScosLoadedUnitsRegionsV235(ctx.h,room,D2ReadU32(ctx.h,room+0x10))
    {
        u := D2ReadU32(ctx.h,r+0x74)
        Loop, 4096
        {
            if (!u || seen.HasKey(u))
                break
            seen[u] := true
            if (D2ReadU32(ctx.h,u)=4)
            {
                uid := D2ReadU32(ctx.h,u+0x0C), cls := D2ReadU32(ctx.h,u+4)
                data := D2ReadU32(ctx.h,u+0x14), ip := D2ReadU32(ctx.h,u+0x2C)
                mode := D2ReadU32(ctx.h,u+0x10)
                x := ip ? D2ReadU32(ctx.h,ip+0x0C) : 0
                y := ip ? D2ReadU32(ctx.h,ip+0x10) : 0
                if (uid && data && cls!=1214 && (mode=3 || mode=5)
                    && (x-px)**2+(y-py)**2<=scanRadiusV147*scanRadiusV147)
                    result[uid] := {uid:uid,cls:cls,unit:u,data:data,q:D2ReadU8V18(ctx.h,data),x:x,y:y,loc:-1}
            }
            next := D2ReadU32(ctx.h,u+0xE8)
            if (next=u)
                break
            u := next
        }
    }
    return result
}

SigPacketV147(ctx, bytes, sigma:=false)
{
    global sigCubeUiOpenV159
    SigCheckV147(ctx)
    if (RemoteThreadBusyV740(ctx.pid))
        SigFailV147("Lệnh cũ chưa kết thúc; giữ đồ và chờ thử lại")
    size := bytes.Length()
    if (size<1 || size>127)
        SigFailV147("Độ dài packet không hợp lệ")
    base := D2GetModuleBaseV35(ctx.pid,sigma ? "D2Sigma.dll" : "D2Net.dll")
    if (!base)
        SigFailV147("Không tìm thấy DLL gửi lệnh")
    if (sigma)
    {
        expected := [0x8B,0x54,0x24,0x04,0xE8,0x27,0x90,0xFF,0xFF,0xC2,0x04,0]
        for i,b in expected
            if (D2ReadU8V18(ctx.h,base+0x488B0+i-1)!=b)
                SigFailV147("DLL Sigma khác bản hàm gửi đã dò; dừng gửi lệnh")
    }
    h := DllCall("OpenProcess","UInt",0x043A,"Int",0,"UInt",ctx.pid,"Ptr")
    remote := h ? DllCall("VirtualAllocEx","Ptr",h,"Ptr",0,"UPtr",256,"UInt",0x3000,"UInt",0x40,"Ptr") : 0
    if (!remote)
    {
        if (h)
            DllCall("CloseHandle","Ptr",h)
        SigFailV147("Không tạo được phiên gửi lệnh")
    }
    VarSetCapacity(packet,size,0)
    for i,b in bytes
        NumPut(b,packet,i-1,"UChar")
    codeBytes := [0x53]
    if (sigma)
    {
        codeBytes.Push(0xB9)
        SigDwordV147(codeBytes,remote+128)
        codeBytes.Push(0x6A), codeBytes.Push(size)
    }
    else
    {
        codeBytes.Push(0x68)
        SigDwordV147(codeBytes,remote+128)
        codeBytes.Push(0x6A), codeBytes.Push(1), codeBytes.Push(0x6A), codeBytes.Push(size)
    }
    codeBytes.Push(0xB8)
    SigDwordV147(codeBytes,base+(sigma ? 0x488B0 : 0x7650))
    for _,b in [0xFF,0xD0,0x5B,0x31,0xC0,0xC2,0x04,0x00]
        codeBytes.Push(b)
    n := codeBytes.Length(), VarSetCapacity(code,n,0)
    for i,b in codeBytes
        NumPut(b,code,i-1,"UChar")
    wp:=0,wc:=0,wait:=-1,th:=0
    okp := DllCall("WriteProcessMemory","Ptr",h,"Ptr",remote+128,"Ptr",&packet,"UPtr",size,"UPtrP",wp)
    okc := DllCall("WriteProcessMemory","Ptr",h,"Ptr",remote,"Ptr",&code,"UPtr",n,"UPtrP",wc)
    try
    {
        SigCheckV147(ctx)
        if (okp && okc && wp=size && wc=n)
        {
            th := DllCall("CreateRemoteThread","Ptr",h,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
            if (th)
            {
                wait := DllCall("WaitForSingleObject","Ptr",th,"UInt",1000)
            }
        }
    }
    finally
    {
        RemoteThreadFinishV740(h,th,remote,wait)
    }
    SigLogV147("PACKET opcode=" . Format("{:02X}",bytes[1]) . " len=" . size . " wait=" . wait)
    if (wait!=0)
        SigFailV147("Gửi lệnh thất bại; dừng lượt Sig")
    if (bytes[1]=0x20 && (!ctx.scosEntry || ctx.lab6TicketV320))
        sigCubeUiOpenV159 := true
}
SigDwordV147(bytes,value)
{
    Loop, 4
        bytes.Push((value >> ((A_Index-1)*8)) & 255)
}

SigLiveItemV148(ctx, uid, unitHint)
{
    if (!unitHint || !uid)
        return false
    if (D2ReadU32(ctx.h,unitHint)!=4 || D2ReadU32(ctx.h,unitHint+0x0C)!=uid)
        return false
    data := D2ReadU32(ctx.h,unitHint+0x14)
    if (!data)
        return false
    path := D2ReadU32(ctx.h,unitHint+0x2C)
    return {uid:uid, unit:unitHint, data:data
        , cls:D2ReadU32(ctx.h,unitHint+0x04)
        , q:D2ReadU8V18(ctx.h,data)
        , loc:D2ReadU8V18(ctx.h,data+0x45)
        , owner:D2ReadU32(ctx.h,data+0x5C)
        , x:path ? D2ReadU32(ctx.h,path+0x0C) : -1
        , y:path ? D2ReadU32(ctx.h,path+0x10) : -1}
}

SigWaitLocV147(ctx,uid,loc,timeout:=4000,unitHint:=0)
{
    global cubePickupDelayMs, cubeTransferDelayMs
    start := A_TickCount
    pollSleep := (loc=4) ? Max(15,Floor(cubePickupDelayMs/2)) : Max(20,Floor(cubeTransferDelayMs/2))
    while (A_TickCount-start<timeout)
    {
        SigCheckV147(ctx)
        if (loc=4)
        {
            cursor := PickupCursorV4(ctx.h,ctx.inv)
            if (IsObject(cursor) && cursor.uid=uid)
                return cursor
        }
        else
        {
            live := unitHint ? SigLiveItemV148(ctx,uid,unitHint) : false
            if (!IsObject(live) || live.loc!=loc)
            {
                all := SigSnapshotV147(ctx)
                live := all.HasKey(uid) ? all[uid] : false
            }
            if (IsObject(live) && live.loc=loc)
            {
                mode := D2ReadU32(ctx.h,live.unit+0x10)
                cursor := PickupCursorV4(ctx.h,ctx.inv)
                if (mode!=3 && mode!=5 && (loc!=0 || live.owner=ctx.inv)
                    && IsObject(cursor) && !cursor.unit)
                    return live
            }
        }
        Sleep, %pollSleep%
    }
    return false
}

SigLiftV147(ctx,item)
{
    global cubePickupDelayMs, cubeTransferDelayMs
    all := SigSnapshotV147(ctx)
    if (!all.HasKey(item.uid) || all[item.uid].cls!=item.cls
        || (all[item.uid].loc!=0 && all[item.uid].loc!=3))
        SigFailV147("Item đã đổi vị trí trước khi nhấc")
    cursor := PickupCursorV4(ctx.h,ctx.inv)
    if (!IsObject(cursor) || cursor.unit)
        SigFailV147("Đang có item trên chuột; dừng Sig")
    if (all[item.uid].loc=3)
    {
        path := D2ReadU32(ctx.h,ctx.player+0x2C)
        openBytes := [0x20]
        SigDwordV147(openBytes,ctx.cubeUid)
        SigDwordV147(openBytes,D2ReadU16(ctx.h,path+2))
        SigDwordV147(openBytes,D2ReadU16(ctx.h,path+6))
        SigLogV147("CUBE_OPEN_FOR_LIFT uid=" . item.uid . " cube_uid=" . ctx.cubeUid)
        SigPacketV147(ctx,openBytes)
        Sleep, 100
    }
    SigLogV147("LIFT uid=" . item.uid . " class=" . item.cls . " loc=" . all[item.uid].loc
        . " owner=" . V92Hex(all[item.uid].owner) . " mode=" . D2ReadU32(ctx.h,all[item.uid].unit+0x10))
    bytes := [0x19], SigDwordV147(bytes,item.uid)
    SigPacketV147(ctx,bytes)
    if (!SigWaitLocV147(ctx,item.uid,4))
        SigFailV147("Nhấc item không được xác nhận; UID=" . item.uid . "; CLASS=" . item.cls)
    
    Sleep, % Max(10, cubeTransferDelayMs)
    SigCheckV147(ctx)
}

SigCubeDropPickupV280(ctx,cube)
{
    global cubePickupDelayMs, cubeTransferDelayMs
    SigCheckV147(ctx)
    if (!ctx.HasKey("sigSessionV761"))
        ctx.sigSessionV761 := SigProtectionArmV761(ctx.pid)
    CubeResetHoldV754(ctx.pid,ctx.h,ctx.player,cube.uid)
    SigLiftV147(ctx,cube)
    bytes := [0x17], SigDwordV147(bytes,cube.uid)
    SigPacketV147(ctx,bytes)
    waitStart := A_TickCount
    while (A_TickCount-waitStart<1500)
    {
        cursor := PickupCursorV4(ctx.h,ctx.inv)
        if (IsObject(cursor) && !cursor.unit)
            break
        Sleep, 30
    }
    Sleep, % Max(10, cubeTransferDelayMs)
    bytes := [0x16], SigDwordV147(bytes,4), SigDwordV147(bytes,cube.uid), SigDwordV147(bytes,0)
    SigPacketV147(ctx,bytes)
    if (!SigWaitLocV147(ctx,cube.uid,0,3000))
        SigFailV147("Chưa nhặt lại được Cube; UID=" . cube.uid)

    all := SigSnapshotV147(ctx)
    if (IsObject(all[cube.uid]) && all[cube.uid].loc=0
        && all[cube.uid].owner=ctx.inv
        && all[cube.uid].x=0 && all[cube.uid].y=0)
    {
        SigLogV147("CUBE_HOME_TOPLEFT_KEPT uid=" . cube.uid)
        return true
    }
    SigLogV147("CUBE_LANDED_AT uid=" . cube.uid
        . " xy=" . all[cube.uid].x . "," . all[cube.uid].y
        . " owner=" . V92Hex(all[cube.uid].owner) . " inv=" . V92Hex(ctx.inv)
        . " force_topleft=1 page=0_ONLY")
    for _,placeDst in [0]
    {
        SigLiftV147(ctx,cube)
        bytes := [0x18]
        SigDwordV147(bytes,cube.uid)
        SigDwordV147(bytes,0), SigDwordV147(bytes,0), SigDwordV147(bytes,placeDst)
        SigPacketV147(ctx,bytes)
        Sleep, 250
        all := SigSnapshotV147(ctx)
        if (IsObject(all[cube.uid]) && all[cube.uid].loc=0
            && all[cube.uid].owner=ctx.inv
            && all[cube.uid].x=0 && all[cube.uid].y=0)
        {
            SigLogV147("CUBE_TOPLEFT_RESTORED uid=" . cube.uid . " dst=" . placeDst)
            return true
        }
    }
    SigLogV147("CUBE_TOPLEFT_FAILED uid=" . cube.uid
        . " last_xy=" . all[cube.uid].x . "," . all[cube.uid].y
        . " action=ACCEPT_ANY_POSITION")
    return true
}

SigPickV147(ctx,item)
{
    if (!ctx.cubeRouteActiveV574)
    {
        charmWaitV572 := A_TickCount
        Loop
        {
            charmMarkedV572 := PickupCharmCubeMarkedV571(ctx,item,charmReadyV572)
            if (charmReadyV572)
                break
            SigCheckV147(ctx)
            if (A_TickCount-charmWaitV572>3000)
                SigFailV147("Charm [cube]: chưa đọc được điều kiện nhặt")
            Sleep, 30
        }
        if (charmMarkedV572)
            return PickupCubeRouteV574(ctx,item)
    }
    if (!ctx.relicSwapActiveV567)
    {
        relicWaitV567 := A_TickCount
        Loop
        {
            markedV567 := PickupRelicMarkedV567(ctx,item,readyV567)
            if (readyV567)
                break
            SigCheckV147(ctx)
            if (A_TickCount-relicWaitV567>3000)
                SigFailV147("Relic [cube]: chưa đọc được luật nhặt")
            Sleep, 30
        }
        if (markedV567)
        {
            ctx.relicSwapActiveV567 := true
            try
                return PickupRelicSwapV567(ctx,item)
            finally
                ctx.relicSwapActiveV567 := false
        }
    }
    ground := SigGroundV147(ctx)
    if (!ground.HasKey(item.uid) || ground[item.uid].cls!=item.cls)
        SigFailV147("Không còn thấy item dưới đất")
    bytes := [0x16], SigDwordV147(bytes,4), SigDwordV147(bytes,item.uid), SigDwordV147(bytes,0)
    SigPacketV147(ctx,bytes)
    if (!SigWaitLocV147(ctx,item.uid,0))
    {
        gateStartedV551 := A_TickCount
        while (!PickupFailedInventoryReadyV551(ctx.h,ctx.player,ctx.pid,item.uid,ground[item.uid].unit))
        {
            SigCheckV147(ctx)
            if (A_TickCount-gateStartedV551>5000)
                SigFailV147("Chưa chuyển được món trùng trong rương vào cube; UID=" . item.uid . "; CLASS=" . item.cls)
            Sleep, 100
        }
        SigPacketV147(ctx,bytes)
        if (!SigWaitLocV147(ctx,item.uid,0))
            SigFailV147("Chưa xác nhận nhặt vào túi đồ trung gian; UID=" . item.uid . "; CLASS=" . item.cls)
    }
    UniqueRememberPickedV18(ctx.h,item)
}

SigRecipeCatalystV755(item,reusable)
{
    return IsObject(item) && IsObject(reusable) && item.uid>0 && item.uid=reusable.uid
        && item.q=2 && reusable.q=2 && item.cls=reusable.cls
        && (item.cls=1734 || item.cls=1735)
}

SigCatalystToCubeV755(ctx,item,cube,wantedClass)
{
    if ((wantedClass!=1734 && wantedClass!=1735) || !IsObject(item))
        SigFailV147("Tem SIG không hợp lệ; không đưa vào Cube")
    all := SigSnapshotV147(ctx),live := all[item.uid]
    if (!IsObject(live))
    {
        ground := SigGroundV147(ctx)
        live := ground[item.uid]
    }
    if (!IsObject(live) || live.cls!=wantedClass || live.q!=2 || live.uid!=item.uid)
        SigFailV147("Chưa xác nhận đúng tem SIG; UID=" . item.uid)
    SigToCubeV147(ctx,live,cube,true)
    SigLogV147("SIG_CATALYST_TO_CUBE uid=" . live.uid . " class=" . live.cls . " retained=1")
}

SigToCubeV147(ctx,item,cube,storageOnly:=false)
{
    if (!storageOnly && SigWarningProtectedV15(ctx,item))
        SigFailV147("Đồ được giữ khỏi SIG: không đưa vào Cube để ghép")
    ground := SigGroundV147(ctx)
    all := SigSnapshotV147(ctx)
    if (ground.HasKey(item.uid))
    {
        SigLogV147("TO_CUBE_PICK_GROUND uid=" . item.uid . " class=" . item.cls)
        SigPickV147(ctx,ground[item.uid])
    }
    else if (!all.HasKey(item.uid))
        SigFailV147("Không thấy nguyên liệu để đưa vào Cube; UID=" . item.uid)
    if (!SigWaitLocV147(ctx,cube.uid,0,100))
        SigFailV147("Cube không còn trong rương")
    SigRememberReagentHomeV192(ctx,item)
    SigLiftV147(ctx,item)
    bytes := [0x2A], SigDwordV147(bytes,item.uid), SigDwordV147(bytes,cube.uid)
    SigPacketV147(ctx,bytes)
    if (!SigWaitLocV147(ctx,item.uid,3))
        SigFailV147("Cube từ chối item; dừng lượt Sig")
}

SigReturnV147(ctx,item)
{
    if (IsObject(ctx.returnHomesV265) && ctx.returnHomesV265.HasKey(item.uid))
        return Ticket130HomeV265(ctx,item,ctx.returnHomesV265[item.uid])
    if ((item.cls=1734 || item.cls=1735) && item.q=2
        && IsObject(ctx.reagentHomesV192) && ctx.reagentHomesV192.HasKey(item.cls))
        return SigReturnReagentHomeV192(ctx,item,ctx.reagentHomesV192[item.cls])
    if (ctx.ticketPlacementV277)
        return TicketInventoryPlaceV277(ctx,item)
    cursor := PickupCursorV4(ctx.h,ctx.inv)
    if (!IsObject(cursor) || !cursor.unit || cursor.uid!=item.uid)
        SigLiftV147(ctx,item)
    all := SigSnapshotV147(ctx), occupied := {}
    sizeV655 := TicketItemSizeV277(ctx,item.cls)
    for uid,a in all
    {
        if (a.loc!=0 || a.owner!=ctx.inv || uid=item.uid)
            continue
        otherV655 := TicketItemSizeV277(ctx,a.cls)
        Loop, % otherV655.h
        {
            yyV655 := a.y+A_Index-1
            Loop, % otherV655.w
                occupied[(a.x+A_Index-1) . "," . yyV655] := true
        }
    }
    Loop, 150
    {
        x := Mod(A_Index-1,15), y := Floor((A_Index-1)/15)
        freeV655 := x+sizeV655.w<=15 && y+sizeV655.h<=10
        Loop, % sizeV655.h
        {
            yyV655 := y+A_Index-1
            Loop, % sizeV655.w
                if (occupied.HasKey((x+A_Index-1) . "," . yyV655) || SigReservedHomeCellV192(ctx,x+A_Index-1,yyV655))
                    freeV655 := false
        }
        if (!freeV655)
            continue
        cursor := PickupCursorV4(ctx.h,ctx.inv)
        if (!IsObject(cursor) || cursor.uid!=item.uid)
        {
            if (SigWaitLocV147(ctx,item.uid,0,300))
                return true
            SigFailV147("Item trên chuột đã thay đổi")
        }
        bytes := [0x18], SigDwordV147(bytes,item.uid), SigDwordV147(bytes,x), SigDwordV147(bytes,y), SigDwordV147(bytes,0)
        SigPacketV147(ctx,bytes)
        if (SigWaitLocV147(ctx,item.uid,0,500))
        {
            SigLogV147("RETURN_INVENTORY uid=" . item.uid . " class=" . item.cls . " xy=" . x . "," . y . " destination=0")
            return true
        }
    }
    SigFailV147("Rương đầy: không trả được item, đang giữ trên chuột")
}

SigCubeItemsV147(ctx)
{
    result := []
    for uid,a in SigSnapshotV147(ctx)
        if (a.loc=3)
            result.Push(a)
    return result
}

SigItemsTextV150(items)
{
    text := ""
    for _,a in items
        text .= (text="" ? "" : "; ") . "uid=" . a.uid . ",class=" . a.cls
            . ",quality=" . a.q . ",loc=" . a.loc
    return text="" ? "EMPTY" : text
}

SigWarningProtectedV15(ctx,item)
{
    global sigTUV586,sigSUV510,sigSSUV13,sigSSSUV13
    if (!IsObject(item) || !item.data)
        return false
    q := D2ReadU8V18(ctx.h,item.data)
    if (PickupNoSigMatchV490(ctx,item,q))
        return true
    if (ctx.boCombinedSigV459 && q=7 && (item.cls=8 || item.cls=668 || item.cls=1825))
    {
        SigLogV147("SIG_KEEP_BO_MATERIAL uid=" . item.uid . " class=" . item.cls . " reason=BO_STAGE_PROTECTION")
        return true
    }
    idx := D2ReadU32(ctx.h,item.data+0x28)
    if (q=5 && SigSetProtectedV227(ctx,item))
        return true
    if (q=7 && (sigSSUV13 || sigSSSUV13))
    {
        wlvl := 0
        tier := UniqueItemsTierFromLiveTableV1(ctx.h,idx,wlvl)
        if ((tier="SSU" && sigSSUV13) || (tier="SSSU" && sigSSSUV13))
            return false
    }
    return false
}

SigTransmuteV147(ctx,inputs,expected,reusable:=false,suPiecesV213:=0,setPiecesV609:=0)
{
    RareWarningLoadV1()
    requestedIdsV150 := {}
    for _,requestedItemV150 in inputs
        requestedIdsV150[requestedItemV150.uid] := true
    for _,a in SigCubeItemsV147(ctx)
        if (!requestedIdsV150.HasKey(a.uid)
            && !SigRecipeCatalystV755(a,reusable) && SigWarningProtectedV15(ctx,a))
        {
            SigLogV147("SIG_TRANSMUTE_RETURN_PROTECTED uid=" . a.uid . " class=" . a.cls . " next=RETURN_TO_STASH")
            SigReturnV147(ctx,a)
        }
    safeInputs := []
    insideForGuardV150 := SigCubeItemsV147(ctx),insideIdsV150 := {}
    for _,insideItemV150 in insideForGuardV150
        insideIdsV150[insideItemV150.uid] := true
    for _,protectedItemV15 in inputs
    {
        if (!insideIdsV150.HasKey(protectedItemV15.uid)
            && !SigRecipeCatalystV755(protectedItemV15,reusable)
            && SigWarningProtectedV15(ctx,protectedItemV15))
        {
            SigLogV147("SIG_TRANSMUTE_SKIP_PROTECTED uid=" . protectedItemV15.uid . " class=" . protectedItemV15.cls)
            allP := SigSnapshotV147(ctx)
            if (allP.HasKey(protectedItemV15.uid) && allP[protectedItemV15.uid].loc=3)
            {
                try
                    SigReturnV147(ctx,allP[protectedItemV15.uid])
                catch e
                    SigLogV147("SIG_TRANSMUTE_RETURN_FAIL uid=" . protectedItemV15.uid . " reason=" . e.Message)
            }
            continue
        }
        safeInputs.Push(protectedItemV15)
    }
    inputs := safeInputs
    if (!inputs.Length())
    {
        SigLogV147("SIG_TRANSMUTE_ALL_PROTECTED count=0")
        return []
    }
    inside := SigCubeItemsV147(ctx), ids := {}
    for _,a in inputs
        ids[a.uid] := true
    if (inside.Length()!=inputs.Length())
        SigFailV147("Cube có đồ ngoài nhóm; không gửi transmute")
    for _,a in inside
        if (!ids.HasKey(a.uid))
            SigFailV147("Nhóm đồ trong Cube không khớp; không gửi transmute")
    SigLogV147("TRANSMUTE_BEFORE count=" . inside.Length() . " items=" . SigItemsTextV150(inside))
    path := D2ReadU32(ctx.h,ctx.player+0x2C)
    px := D2ReadU16(ctx.h,path+2), py := D2ReadU16(ctx.h,path+6)
    openBytes := [0x20]
    SigDwordV147(openBytes,ctx.cubeUid), SigDwordV147(openBytes,px), SigDwordV147(openBytes,py)
    SigLogV147("CUBE_OPEN_SEND route=D2NET uid=" . ctx.cubeUid . " xy=" . px . "," . py)
    SigPacketV147(ctx,openBytes)
    Sleep, 250
    SigCheckV147(ctx)
    SigLogV147("TRANSMUTE_SEND route=D2NET packet=4F180000000000 inputs=" . inputs.Length() . " expected=" . expected)
    SigPacketV147(ctx,[0x4F,0x18,0x00,0x00,0x00,0x00,0x00])
    start := A_TickCount, lastState := ""
    while (A_TickCount-start<3500)
    {
        Sleep, 100
        inside := SigCubeItemsV147(ctx), unchanged := false, results := [], kept := 0
        for _,a in inside
        {
            if (IsObject(reusable) && a.cls=reusable.cls && a.q=reusable.q)
            {
                kept++
                continue
            }
            results.Push(a)
            if (ids.HasKey(a.uid))
                unchanged := true
        }
        state := SigItemsTextV150(inside)
        if (lastState!=state)
        {
            SigLogV147("TRANSMUTE_AFTER elapsed_ms=" . (A_TickCount-start) . " count=" . inside.Length()
                . " input_remaining=" . unchanged . " items=" . state)
            lastState := state
        }
        if (setPiecesV609>0 && kept=0 && SigSetMergeResultValidV609(results,setPiecesV609))
        {
            SigLogV147("SET_FRAGMENT_MERGE_CONFIRMED pieces=" . setPiecesV609 . " items=" . SigItemsTextV150(results))
            return results
        }
        if (suPiecesV213>0 && kept=0 && SigSuMergeResultValidV213(results,suPiecesV213))
        {
            SigLogV147("SU_FRAGMENT_MERGE_CONFIRMED pieces=" . suPiecesV213 . " outputs=" . results.Length() . " items=" . SigItemsTextV150(results))
            return results
        }
        if (!suPiecesV213 && !setPiecesV609 && !unchanged && results.Length()=expected && kept=(IsObject(reusable) ? 1 : 0))
        {
            SigLogV147("TRANSMUTE inputs=" . inputs.Length() . " outputs=" . expected . " class=" . results[1].cls)
            return results
        }
    }
    SigLogV147("TRANSMUTE_TIMEOUT count=" . inside.Length() . " expected=" . expected . " items=" . SigItemsTextV150(inside))
    SigFailV147("Packet transmute chưa ra đúng sản phẩm; dừng, không gửi lặp")
}

SigCloseCubeV156()
{
    global sigSendingKeyV147,sigCubeUiOpenV159
    if (!sigCubeUiOpenV159)
    {
        SigLogV147("CUBE_CLOSE_SKIP reason=ALREADY_CLOSED")
        return true
    }
    sigSendingKeyV147 := true
    try
        sent := GameTargetKeyV63("{Esc}")
    finally
        sigSendingKeyV147 := false
    if (sent)
        sigCubeUiOpenV159 := false
    Sleep, 200
    SigLogV147("CUBE_CLOSE_ESC sent=" . sent . " next=PICKUP_OR_RETURN")
    return sent
}

SigCandidatesV155(ctx,quality,cls:=0,groundOnly:=false)
{
    result := [],seen := {}
    if (!groundOnly)
        for uid,a in SigSnapshotV147(ctx)
            if (a.loc=0 && a.owner=ctx.inv && a.q=quality
                && (!cls || a.cls=cls) && D2ReadU32(ctx.h,a.unit+0x10)=0
                && SigItemAllowedForRecipeV11(ctx,a,quality))
                result.Push(a),seen[uid]:=true
    if (!ctx.sigInventoryOnlyV718)
        for uid,a in SigGroundV147(ctx)
            if (!seen.HasKey(uid) && a.q=quality && (!cls || a.cls=cls)
                && SigItemAllowedForRecipeV11(ctx,a,quality))
                result.Push(a),seen[uid]:=true
    return result
}

SigItemAllowedForRecipeV11(ctx,item,quality)
{
    global sigTUV586,sigSUV510,sigSSUV13,sigSSSUV13
    if (!IsObject(item) || !item.data)
        return false
    if (TownStoreMatchV628(ctx.h,item.unit,item.cls,item.q,item.data,storeReadyV628) || !storeReadyV628)
        return false
    if (SigWarningProtectedV15(ctx,item))
    {
        SigLogV147("SIG_SKIP_WARNING uid=" . item.uid . " class=" . item.cls)
        return false
    }
    if (quality!=7)
        return true
    fileIndex := D2ReadU32(ctx.h,item.data+0x28)
    wlvl := 0
    tier := UniqueItemsTierFromLiveTableV1(ctx.h,fileIndex,wlvl)
    allowed := (tier="TU" && sigTUV586) || (tier="SU" && sigSUV510) || (tier="SSU" && sigSSUV13) || (tier="SSSU" && sigSSSUV13)
    SigLogV147("SIG_UNIQUE_CHECK uid=" . item.uid . " class=" . item.cls
        . " fileIndex=" . fileIndex . " wLvl=" . wlvl . " tier=" . tier
        . " allowed=" . (allowed ? 1 : 0)
        . " reason=" . (tier="UNKNOWN" ? "TIER_NOT_READ" : allowed ? "ELIGIBLE" : "TIER_CHECKBOX_OFF"))
    return allowed
}

SigReturnCatalystsV652(ctx,wantedClass := 0,required := false)
{
    SigCheckV147(ctx)
    cursor := PickupCursorV4(ctx.h,ctx.inv)
    if (!IsObject(cursor))
        SigFailV147("Không đọc được chuột khi trả catalyst")
    if (cursor.unit)
    {
        cls := D2ReadU32(ctx.h,cursor.unit+4),data := D2ReadU32(ctx.h,cursor.unit+0x14)
        if ((cls!=1734 && cls!=1735) || !data || D2ReadU8V18(ctx.h,data)!=2
            || (wantedClass && cls!=wantedClass))
            SigFailV147("Có vật phẩm khác trên chuột; chưa trả được catalyst")
        held := {uid:cursor.uid,unit:cursor.unit,cls:cls,data:data,q:2}
        SigReturnV147(ctx,held)
        if (!SigWaitLocV147(ctx,held.uid,0,2000))
            SigFailV147("Chưa xác nhận catalyst trên chuột về rương")
    }
    found := false
    for _,a in SigCubeItemsV147(ctx)
    {
        if ((a.cls!=1734 && a.cls!=1735) || a.q!=2 || (wantedClass && a.cls!=wantedClass))
            continue
        found := true
        SigLogV147("CATALYST_RETURN_FRESH class=" . a.cls . " uid=" . a.uid . " source=CUBE")
        SigReturnV147(ctx,a)
        if (!SigWaitLocV147(ctx,a.uid,0,2000))
            SigFailV147("Chưa xác nhận catalyst " . a.cls . " về rương")
    }
    for uid,a in SigSnapshotV147(ctx)
    {
        if ((a.cls!=1734 && a.cls!=1735) || a.q!=2 || (wantedClass && a.cls!=wantedClass))
            continue
        if (a.loc=3)
            SigFailV147("Catalyst vẫn còn trong Cube; chưa hoàn tất SIG")
        if (a.loc=0 && a.owner=ctx.inv && D2ReadU32(ctx.h,a.unit+0x10)=0)
        {
            found := true
            SigLogV147("CATALYST_RETURN_VERIFIED class=" . a.cls . " uid=" . uid . " destination=INVENTORY")
        }
    }
    if (required && !found)
        SigFailV147("Không tìm thấy catalyst " . wantedClass . " sau cube để trả về rương")
    return true
}

SigGroupV147(ctx,cube,quality,resumeStep5:=false)
{
    reagentClass := quality=7 ? 1735 : 1734
    expectedProductClass := quality=7 ? 1732 : 1700
    SigLogV147("RECIPE quality=" . quality . " reagent=" . reagentClass . "/02 product=" . expectedProductClass . "/02")
    ground := SigCandidatesV155(ctx,quality,0,true)
    candidates := SigCandidatesV155(ctx,quality,0,false)
    SigLogV147("SET_COUNT quality=" . quality . " ground=" . ground.Length() . " total=" . candidates.Length() . " source=GROUND_AND_INVENTORY batch_order=10_THEN_5")
    if (quality=7 && candidates.Length()>=1 && candidates.Length()<5 && !resumeStep5)
    {
        SigSuUnder5V215(ctx,cube,candidates)
        SigMergeSuFragmentsV213(ctx,cube)
        return
    }
    if (candidates.Length()<1 && !resumeStep5)
    {
        if (quality=7)
            SigMergeSuFragmentsV213(ctx,cube)
        return
    }
    reagent := 0
    for uid,a in SigSnapshotV147(ctx)
        if (a.loc=0 && a.owner=ctx.inv && a.cls=reagentClass && a.q=2 && D2ReadU32(ctx.h,a.unit+0x10)=0)
        {
            reagent := a
            break
        }
    if (!IsObject(reagent))
        for uid,a in SigGroundV147(ctx)
            if (a.cls=reagentClass && a.q=2)
            {
                reagent := a
                break
            }
    if (!IsObject(reagent) && resumeStep5)
        for _,a in SigCubeItemsV147(ctx)
            if (a.cls=reagentClass && a.q=2)
                reagent := a
    if (!IsObject(reagent))
    {
        for _,a in SigCubeItemsV147(ctx)
            if (a.cls=reagentClass && a.q=2)
            {
                reagent := a
                break
            }
        if (IsObject(reagent))
        {
            SigReturnV147(ctx,reagent)
            SigLogV147("CATALYST_RESCUE_FROM_CUBE class=" . reagentClass)
            reagent := 0
        }
        SigLogV147("SIG_SKIP_NO_CATALYST quality=" . quality
            . " reagent_class=" . reagentClass
            . " next=CONTINUE_OTHER_QUALITY")
        return
    }
    productClass := 0, productQuality := 0, reagentInside := false
    if (resumeStep5)
    {
        reagent := 0
        for _,a in SigCubeItemsV147(ctx)
            if (a.cls=reagentClass && a.q=2)
                reagent := a
        if (!IsObject(reagent))
            SigFailV147("Test bước 5: đặt " . reagentClass . "/02 trong Cube cùng thành phẩm")
        reagentInside := true
        for _,a in SigCubeItemsV147(ctx)
            if (a.cls!=reagentClass)
            {
                productClass := a.cls,productQuality := a.q
                SigReturnV147(ctx,a)
            }
        if (!productClass)
            productClass := expectedProductClass,productQuality := 2
        SigLogV147("STEP5_RETURN_PRODUCTS reagent=KEEP_IN_CUBE next=CHECK_SET")
        SigCloseCubeV156()
    }
    Loop, 40
    {
        candidates := SigCandidatesV155(ctx,quality,0,false)
        count := candidates.Length()
        if (count<1)
            break
        n := count>=10 ? 10 : count>=5 ? 5 : count
        SigLogV147("SET_BATCH available=" . count . " take=" . n . " reagent_inside=" . reagentInside)
        inputs := []
        Loop, %n%
        {
            a := candidates[A_Index]
            SigToCubeV147(ctx,a,cube)
            inputs.Push(a)
        }
        if (!reagentInside)
            SigCatalystToCubeV755(ctx,reagent,cube,reagentClass)
        inputs.Push(reagent)
        if (quality=7)
            SigUniqueBatchGuardV510(ctx,inputs)
        output := SigTransmuteV147(ctx,inputs,n=10 ? 2 : 1,reagent)
        if (quality=7)
        {
            expectedSuClassV213 := n>=5 ? 1732 : 1727+n
            for _,product in output
                if (product.cls!=expectedSuClassV213 || product.q!=2)
                    SigFailV147("Sản phẩm SU không khớp " . expectedSuClassV213 . "/02; dừng xử lý")
        }
        if (quality=5)
        {
            expectedSetV609 := n>=5 ? 1700 : 1695+n
            for _,product in output
                if (product.cls!=expectedSetV609 || product.q!=2)
                    SigFailV147("Sản phẩm Set không khớp " . expectedSetV609 . "/02; giữ đồ, dừng xử lý")
        }
        productClass := quality=7 ? expectedProductClass : 1700
        productQuality := quality=7 ? 2 : output[1].q
        reagent := 0
        for _,a in SigCubeItemsV147(ctx)
            if (a.cls=reagentClass && a.q=2)
            {
                reagent := a
                break
            }
        if (!IsObject(reagent))
            SigFailV147("Không thấy vật kèm sau cube")
        reagentInside := true
        for _,a in output
            SigReturnV147(ctx,a)
        SigLogV147("SET_BATCH_DONE returned_products=" . output.Length() . " reagent=KEEP_IN_CUBE")
        SigCloseCubeV156()
    }
    if (reagentInside)
    {
        SigReturnCatalystsV652(ctx,reagentClass,true)
        SigLogV147("REAGENT_RETURN class=" . reagentClass . " source=FRESH_SCAN next=" . (quality=7 ? "SORT_TO_CONTAINER" : "MERGE_INVENTORY_SIG"))
        SigCloseCubeV156()
    }
    if (quality=7)
    {
        SigLogV147("SU_STEP2 action=MERGE_GROUND_AND_INVENTORY_FRAGMENTS classes=1728,1729,1730,1731 quality=02 reagent=NONE")
        SigMergeSuFragmentsV213(ctx,cube)
    }
    else
        SigMergeInventoryV158(ctx,cube,productClass,productQuality)
}

SigUniqueBatchGuardV510(ctx,inputs)
{
    all := SigSnapshotV147(ctx)
    for i,item in inputs
    {
        fresh := all[item.uid]
        if (!IsObject(fresh) || fresh.cls!=item.cls || fresh.q!=item.q || fresh.loc!=3)
            SigFailV147("Chưa xác nhận đúng nguyên liệu trong Cube; UID=" . item.uid . "; CLASS=" . item.cls)
        if (fresh.q=7)
        {
            started := A_TickCount
            Loop
            {
                SigCheckV147(ctx)
                storeMatch := TownStoreMatchV628(ctx.h,fresh.unit,fresh.cls,fresh.q,fresh.data,storeReady)
                if (storeReady)
                    break
                if (A_TickCount-started>=4000)
                    SigFailV147("Chưa đọc xong điều kiện giữ/cất Unique; UID=" . fresh.uid . "; CLASS=" . fresh.cls)
                PickupOptPollV12()
                Sleep, 50
            }
            SigLogV147("SIG_UNIQUE_INPUT_REFRESH uid=" . fresh.uid . " class=" . fresh.cls
                . " old_data=" . V92Hex(item.data) . " live_data=" . V92Hex(fresh.data) . " loc=" . fresh.loc)
            if (!SigItemAllowedForRecipeV11(ctx,fresh,7))
                SigFailV147("Unique chưa được check SIG hoặc được giữ/cất; UID=" . fresh.uid . "; CLASS=" . fresh.cls)
        }
        inputs[i] := fresh
    }
}

SigSuMergeResultValidV213(items,pieces)
{
    products := Floor(pieces/5),remainder := Mod(pieces,5),finished := 0,left := 0
    if (items.Length()!=products+(remainder ? 1 : 0))
        return false
    for _,a in items
    {
        if (a.q!=2)
            return false
        if (a.cls=1732)
            finished++
        else if (remainder && a.cls=1727+remainder)
            left++
        else
            return false
    }
    return finished=products && left=(remainder ? 1 : 0)
}
SigSuUnder5V215(ctx,cube,items)
{
    global cubePickupDelayMs
    count := items.Length()
    SigLogV147("SU_UNDER5_BEGIN count=" . count . " recipe=TEM_1735_PLUS_" . count . "_ITEM07")
    reagent := 0
    for uid,a in SigSnapshotV147(ctx)
        if (a.loc=0 && a.owner=ctx.inv && a.cls=1735 && a.q=2
            && D2ReadU32(ctx.h,a.unit+0x10)=0)
        {
            reagent := a
            break
        }
    if (!IsObject(reagent))
        for uid,a in SigGroundV147(ctx)
            if (a.cls=1735 && a.q=2)
            {
                reagent := a
                break
            }
    if (!IsObject(reagent))
        for _,a in SigCubeItemsV147(ctx)
            if (a.cls=1735 && a.q=2)
            {
                reagent := a
                break
            }
    if (!IsObject(reagent))
    {
        SigFailV147("Không thấy tem 1735/02 để cube SU <5")
        return
    }
    SigLogV147("SU_UNDER5_REAGENT uid=" . reagent.uid)
    if (SigCubeItemsV147(ctx).Length())
        SigFailV147("Cube chưa trống trước khi cube SU <5")
    inputs := []
    for _,a in items
    {
        SigCheckV147(ctx)
        SigToCubeV147(ctx,a,cube)
        inputs.Push(a)
    }
    SigCheckV147(ctx)
    SigCatalystToCubeV755(ctx,reagent,cube,1735)
    inputs.Push(reagent)
    expectedClass := 1727 + count
    SigLogV147("SU_UNDER5_TRANSMUTE inputs=" . inputs.Length()
        . " expected_class=" . expectedClass . "/02 result=1_FRAGMENT")
    SigUniqueBatchGuardV510(ctx,inputs)
    output := SigTransmuteV147(ctx, inputs, 1, reagent)
    SigReturnCatalystsV652(ctx,1735,true)
    if (output.Length()!=1 || output[1].cls!=expectedClass || output[1].q!=2)
    {
        SigLogV147("SU_UNDER5_UNEXPECTED output=" . SigItemsTextV150(output))
        SigFailV147("Sản phẩm SU <5 không đúng: cần " . expectedClass . "/02")
    }
    SigLogV147("SU_UNDER5_CONFIRMED fragment_class=" . expectedClass
        . " uid=" . output[1].uid . " q=" . output[1].q)
    for _,a in output
        SigReturnV147(ctx,a)
    SigLogV147("SU_UNDER5_DONE count=" . count . " fragment_class=" . expectedClass)
    SigCloseCubeV156()
}

SigMergeSuFragmentsV213(ctx,cube)
{
    SigReturnCatalystsV652(ctx)
    matching := [],pieces := 0,seen := {}
    for uid,a in SigSnapshotV147(ctx)
        if (a.loc=0 && a.owner=ctx.inv && a.q=2 && a.cls>=1728 && a.cls<=1731
            && D2ReadU32(ctx.h,a.unit+0x10)=0 && !SigWarningProtectedV15(ctx,a))
        {
            matching.Push(a),pieces += a.cls-1727,seen[uid] := true
        }
    for uid,a in SigGroundV147(ctx)
        if (!seen.HasKey(uid) && a.q=2 && a.cls>=1728 && a.cls<=1731
            && !SigWarningProtectedV15(ctx,a))
        {
            matching.Push(a),pieces += a.cls-1727,seen[uid] := true
        }
    SigLogV147("SU_FRAGMENT_SCAN count=" . matching.Length() . " pieces=" . pieces
        . " finished_expected=" . Floor(pieces/5) . " remainder=" . Mod(pieces,5) . " source=GROUND_AND_INVENTORY reagent=NONE passes=ONE")
        if (matching.Length()>=2)
    {
        remaining := matching.Clone()
        while (remaining.Length()>0)
        {
            n := Min(10, remaining.Length())
            batch := [], batchPieces := 0
            Loop, %n%
            {
                a := remaining[A_Index]
                batch.Push(a)
                batchPieces += a.cls - 1727
            }
            Loop, %n%
                remaining.RemoveAt(1)

            if (SigCubeItemsV147(ctx).Length())
                SigFailV147("Cube chưa trống trước khi ghép mảnh SU")
            inputs := []
            for _,a in batch
            {
                SigToCubeV147(ctx,a,cube)
                inputs.Push(a)
            }
            expected := Floor(batchPieces/5)+(Mod(batchPieces,5) ? 1 : 0)
            SigLogV147("SU_FRAGMENT_BATCH items=" . n . " pieces=" . batchPieces
                . " expected=" . expected . " remaining=" . remaining.Length())
            output := SigTransmuteV147(ctx,inputs,expected,false,batchPieces)
            for _,a in output
                SigReturnV147(ctx,a)
            SigCloseCubeV156()
        }
    }
    SigSortContainerV191(ctx)
    SigLogV147("SU_FRAGMENT_FINISH remainder_pieces=" . Mod(pieces,5) . " repeat=NO next=RESTORE_GROUND")
}

SigMergeInventoryV158(ctx,cube,productClass,productQuality)
{
    SigReturnCatalystsV652(ctx)
    SigMergeSetFragmentsV609(ctx,cube)
    SigMergeSetClassV508(ctx,cube,1700,2)
}

SigSetMergeResultValidV609(items,pieces)
{
    finished := 0,remainderCount := 0,remainder := Mod(pieces,5)
    if (items.Length()!=Floor(pieces/5)+(remainder ? 1 : 0))
        return false
    for _,a in items
    {
        if (a.q!=2)
            return false
        if (a.cls=1700)
            finished++
        else if (remainder && a.cls=1695+remainder)
            remainderCount++
        else
            return false
    }
    return finished=Floor(pieces/5) && remainderCount=(remainder ? 1 : 0)
}

SigMergeSetFragmentsV609(ctx,cube)
{
    Loop
    {
        SigCheckV147(ctx)
        RareWarningLoadV1()
        matching := [],seen := {}
        for uid,a in SigSnapshotV147(ctx)
            if (a.loc=0 && a.owner=ctx.inv && a.q=2 && a.cls>=1696 && a.cls<=1699
                && D2ReadU32(ctx.h,a.unit+0x10)=0 && !SigWarningProtectedV15(ctx,a))
                matching.Push(a),seen[uid] := true
        for uid,a in SigGroundV147(ctx)
            if (!seen.HasKey(uid) && a.q=2 && a.cls>=1696 && a.cls<=1699 && !SigWarningProtectedV15(ctx,a))
                matching.Push(a),seen[uid] := true
        if (matching.Length()<2)
            return true
        if (SigCubeItemsV147(ctx).Length())
            SigFailV147("Cube chưa trống trước khi ghép mảnh Set")
        inputs := [matching[1],matching[2]]
        pieces := inputs[1].cls-1695+inputs[2].cls-1695
        for _,a in inputs
            SigToCubeV147(ctx,a,cube)
        SigLogV147("SET_FRAGMENT_PAIR pieces=" . pieces . " inputs=" . SigItemsTextV150(inputs))
        output := SigTransmuteV147(ctx,inputs,Floor(pieces/5)+(Mod(pieces,5) ? 1 : 0),false,0,pieces)
        for _,a in output
            SigReturnV147(ctx,a)
        SigCloseCubeV156()
    }
}

SigMergeSetClassV508(ctx,cube,productClass,productQuality)
{
    matching := [],seen := {},inventoryCount := 0,groundCount := 0
    for uid,a in SigSnapshotV147(ctx)
        if (a.loc=0 && a.owner=ctx.inv && a.cls=productClass && a.q=productQuality
            && D2ReadU32(ctx.h,a.unit+0x10)=0 && !SigWarningProtectedV15(ctx,a))
            matching.Push(a),seen[uid] := true,inventoryCount++
    for uid,a in SigGroundV147(ctx)
        if (!seen.HasKey(uid) && a.cls=productClass && a.q=productQuality
            && !SigWarningProtectedV15(ctx,a))
            matching.Push(a),seen[uid] := true,groundCount++
    SigLogV147("SET_FRAGMENT_SCAN class=" . productClass . " inventory=" . inventoryCount
        . " ground=" . groundCount . " total=" . matching.Length() . " source=GROUND_AND_INVENTORY")
    remaining := matching.Length(), offset := 1
    SigLogV147("SMALL_SIG_GROUP class=" . productClass . " available=" . remaining . " batch_order=10_THEN_5")
    while (remaining>=5)
    {
        n := 5,inputs := []
        Loop, %n%
        {
            a := matching[offset],offset++
            SigToCubeV147(ctx,a,cube)
            inputs.Push(a)
        }
        output := SigTransmuteV147(ctx,inputs,n=10 ? 2 : 1)
        for _,a in output
            SigReturnV147(ctx,a)
        remaining -= n
        SigLogV147("SMALL_SIG_BATCH_DONE take=" . n . " remaining=" . remaining)
        SigCloseCubeV156()
    }
    SigSortContainerV191(ctx)
    SigLogV147("SORT_DONE small_sig_left=" . remaining . " next=RESTORE_GROUND")
}

SigSortContainerV191(ctx)
{
    SigPacketV147(ctx,[0x4A,0x04,0x00,0x00,0x00],true)
    Sleep, 350
    SigLogV147("SORT_TO_CONTAINER_SENT packet=4A04000000 next=RESTORE_GROUND")
    SigCloseCubeV156()
}

SigGroupVerifiedV16(ctx,cube,quality)
{
    global sigTUV586,sigSUV510,sigSSUV13,sigSSSUV13
    if (quality=7 && !sigTUV586 && !sigSUV510 && !sigSSUV13 && !sigSSSUV13)
    {
        SigLogV147("SIG_UNIQUE_SKIP reason=ALL_TIER_CHECKBOXES_OFF quality=7")
        return true
    }
    if (!ctx.sigInventoryPassDoneV718 && !ctx.sigInventoryOnlyV718)
    {
        ctx.sigInventoryOnlyV718 := true
        try
        {
            SigLogV147("SIG_INVENTORY_FIRST_BEGIN ground_inputs=DEFERRED")
            SigGroupVerifiedV16(ctx,cube,5)
            SigGroupVerifiedV16(ctx,cube,7)
            ctx.sigInventoryPassDoneV718 := true
            SigLogV147("SIG_INVENTORY_FIRST_DONE next=GROUND_ITEMS")
        }
        finally
            ctx.sigInventoryOnlyV718 := false
    }
    emptyChecks := 0
    Loop
    {
        SigCheckV147(ctx)
        RareWarningLoadV1()
        items := SigCandidatesV155(ctx,quality,0,false)
        threshold := 1
        SigLogV147("SIG_RECHECK quality=" . quality . " total_ground_inventory=" . items.Length() . " empty_checks=" . emptyChecks)
        if (items.Length()>=threshold)
        {
            emptyChecks := 0
            SigGroupV147(ctx,cube,quality)
        }
        else if (++emptyChecks>=3)
        {
            if (quality=5)
                SigMergeInventoryV158(ctx,cube,1700,2)
            else if (quality=7)
                SigMergeSuFragmentsV213(ctx,cube)
            return true
        }
        Sleep, 250
    }
}
SigPickupScopeV654(pid,level)
{
    global pickupRadius,pickupScanRadiusV810
    base := D2GetModuleBaseV35(pid,"D2Client.dll"),h := base ? D2OpenProcess(pid) : 0
    if (!h)
        throw Exception("Không đọc được vùng nhặt sau SIG")
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb) || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=level)
            throw Exception("Chưa xác nhận vị trí nhặt sau SIG")
        return {x:NumGet(pb,2,"UShort"),y:NumGet(pb,6,"UShort")
            ,radius:Max(Max(1,pickupRadius),Max(1,pickupScanRadiusV810))}
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}


SigPickupOwnedV764()
{
    global sigPickupOwnerV764
    return IsObject(sigPickupOwnerV764) && sigPickupOwnerV764.active
}

SigPickupProofReadyV764(w,pid,level)
{
    global pickupTimerBusy,ticketPickupWaitV279
    if (!IsObject(w) || ticketPickupWaitV279!=w || !w.active || !w.done || pickupTimerBusy
        || !w.scanAt || A_TickCount-w.scanAt>=1000 || w.level!=level || w.pid!=pid)
        return false
    return CubeResetVerifiedV754(pid,level,w.scanSerialV764)
}

SigPickupWaitTextV764(w)
{
    if (w.blockReasonV468="GROUND_ITEMS")
        return "đang nhặt đồ"
    if (w.blockReasonV468="PICKUP_ROUND" || w.blockReasonV468="ITEM_CONFIRM")
        return "đang xác nhận món vừa nhặt"
    if (w.blockReasonV468="ITEM_NAME_JOB")
        return "đang đọc tên/điều kiện đồ"
    if (w.blockReasonV468="ROOM_READ")
        return "đang xác nhận lại vùng nhặt"
    if (w.blockReasonV468="CURSOR_BUSY")
        return "đang xác nhận vật trên chuột"
    if (w.blockReasonV468="MAP_CHANGED")
        return "map đã thay đổi"
    if (!w.done)
        return "đang xác nhận hết đồ"
    return "đang xác nhận Cube đã về túi"
}

; V1307: Fast pickup is separate from the legacy Farm/manual pickup controller.
; One packet per UID per round, fresh ground scan at the start of each of 3 rounds.
; Never teleport or approach an item from this controller.
SigFreshStartV1307()
{
    global ticketPickupWaitV279,sigPickupOwnerV764,sigFailedItemsV765
    global sigPostPickupV655,pickupContextModeV765,pickupRoundResetV1
    global sigResetPendingV753,sigRunEpochV1320,pickupLastClick
    global sigTerminalErrorV762,sigLastStopReasonV63
    ; Chi duoc khoi tao sau khi SIG cu da thoat; khong tai su dung state.
    sigRunEpochV1320 := (sigRunEpochV1320+0)+1
    if (IsObject(ticketPickupWaitV279) && !ticketPickupWaitV279.active)
        ticketPickupWaitV279 := false
    if (IsObject(sigPickupOwnerV764) && !sigPickupOwnerV764.active)
        sigPickupOwnerV764 := false
    sigFailedItemsV765 := {}
    sigPostPickupV655 := false
    pickupContextModeV765 := ""
    pickupRoundResetV1 := true,pickupLastClick := 0
    sigResetPendingV753 := false
    sigTerminalErrorV762 := "",sigLastStopReasonV63 := ""
    SigLogV147("SIG_FRESH_START epoch=" . sigRunEpochV1320 . " old_transient=CLEARED")
}

SigFastPickupV1307(pid,level,scope:=false)
{
    global sigCancelV147,pickupImageOn,pickupBackgroundV181,pickupRadius
    global pickupContextModeV765
    global ticketPickupWaitV279,sigPickupOwnerV764,pickupTimerBusy
    global sigFailedItemsV765
    if (IsObject(ticketPickupWaitV279) || SigPickupOwnedV764())
        throw Exception("Nhặt Nhanh: đang có lượt nhặt khác")
    ctx := SigOpenContextV149()
    if (ctx.pid!=pid)
    {
        DllCall("CloseHandle","Ptr",ctx.h)
        throw Exception("Nhặt Nhanh: game đã đổi PID")
    }
    previousMode := pickupContextModeV765
    previousBackground := pickupBackgroundV181
    groundRadiusV1307 := IsObject(scope) ? Max(1,scope.radius) : 0
    w := {pid:pid,level:level,active:true,done:false,round:0,remaining:-1}
    ticketPickupWaitV279 := w
    sigPickupOwnerV764 := w
    pickupContextModeV765 := "SIG_FAST"
    pickupBackgroundV181 := true
    SigLogV147("FAST_PICKUP_START pid=" . pid . " mode=SCAN_UNTIL_EMPTY confirm=3 interval=300ms rules=IGNORE"
        . " radius=" . (groundRadiusV1307 ? groundRadiusV1307 : pickupRadius))
    emptyChecks := 0
    lastNotice := 0
    lastLog := 0
    started := A_TickCount
    try
    {
        SetTimer, PickupImageTimer, Off
        ; Do not use a fixed number of rounds: do not announce Done while
        ; any item from the SIG drop area remains visible on the ground.
        Loop
        {
            w.round++
            if (sigCancelV147 || RoomRecordLevelV259(pid)!=level || !IsGameActive()
                || D2GetActiveGamePidV95()!=pid)
                throw Exception("Nhặt Nhanh: SIG bị hủy, thoát game hoặc đổi map; chưa nhặt hết")
            ground := groundRadiusV1307 ? SigGroundV147(ctx,groundRadiusV1307) : SigGroundV147(ctx)
            remaining := {}
            for uid,item in ground
            {
                ; The saved area identifies the SIG drop zone. Ignore Pickup.txt
                ; here so SIG's own dropped items cannot be filtered out.
                if (IsObject(scope) && ((item.x-scope.x)**2+(item.y-scope.y)**2>scope.radius*scope.radius))
                    continue
                remaining[uid] := item
            }
            w.remaining := remaining.Count()
            if (!w.remaining)
            {
                cursor := PickupCursorV4(ctx.h,ctx.inv)
                if (!IsObject(cursor) || cursor.unit)
                {
                    emptyChecks := 0
                    if (!lastNotice || A_TickCount-lastNotice>=15000)
                    {
                        lastNotice := A_TickCount
                        SigLogV147("FAST_PICKUP_WAIT_CURSOR round=" . w.round)
                        ToolTipInfoV386("SIG: đang chờ vật trên chuột; chưa báo Done")
                    }
                }
                else
                {
                    emptyChecks++
                    if (emptyChecks>=3)
                    {
                        ; Final independent scan before marking success.
                        verify := groundRadiusV1307 ? SigGroundV147(ctx,groundRadiusV1307) : SigGroundV147(ctx)
                        found := false
                        for uid,item in verify
                            if (!IsObject(scope) || (item.x-scope.x)**2+(item.y-scope.y)**2<=scope.radius*scope.radius)
                            {
                                found := true
                                break
                            }
                        if (!found)
                        {
                            w.done := true
                            SigLogV147("FAST_PICKUP_DONE rounds=" . w.round . " remaining=0 empty_checks=" . emptyChecks)
                            return true
                        }
                        emptyChecks := 0
                    }
                }
                Sleep, 300
                continue
            }
            emptyChecks := 0
            if (!lastLog || A_TickCount-lastLog>=3000)
            {
                lastLog := A_TickCount
                SigLogV147("FAST_PICKUP_SCAN round=" . w.round . " remaining=" . w.remaining)
            }
            if ((!lastNotice || A_TickCount-lastNotice>=15000) && A_TickCount-started>=15000)
            {
                lastNotice := A_TickCount
                ToolTipInfoV386("SIG: còn " . w.remaining . " vật dưới đất; đang quét nhặt lại, chưa báo Done")
            }
            for uid,item in remaining
            {
                if (sigCancelV147 || RoomRecordLevelV259(pid)!=level || !IsGameActive()
                    || D2GetActiveGamePidV95()!=pid)
                    throw Exception("Nhặt Nhanh: SIG bị hủy hoặc đổi map; chưa nhặt hết")
                current := groundRadiusV1307 ? SigGroundV147(ctx,groundRadiusV1307) : SigGroundV147(ctx)
                if (!current.HasKey(uid))
                    continue
                ; Items explicitly marked for Chuyen Cube must use the
                ; existing safe SWAP transaction BEFORE picking the new item.
                ; Do not send an ordinary pickup packet first in this case.
                liveCubeItemV1308 := current[uid]
                charmCubeV1308 := PickupCharmCubeMarkedV571(ctx,liveCubeItemV1308,charmReadyV1308)
                if (!charmReadyV1308)
                    continue
                if (charmCubeV1308)
                {
                    PickupCubeRouteV574(ctx,liveCubeItemV1308)
                    SigLogV147("FAST_PICKUP_SWAP_CUBE uid=" . uid . " type=CHARM")
                    continue
                }
                relicCubeV1308 := PickupRelicMarkedV567(ctx,liveCubeItemV1308,relicReadyV1308)
                if (!relicReadyV1308)
                    continue
                if (relicCubeV1308)
                {
                    PickupRelicSwapV567(ctx,liveCubeItemV1308)
                    SigLogV147("FAST_PICKUP_SWAP_CUBE uid=" . uid . " type=RELIC")
                    continue
                }
                ; The normal farm packet has a three-attempt cap per UID.
                ; Reset that farm-only cap for this confirmed SIG recovery,
                ; allowing a stubborn ground item to be retried next scan.
                PickupFarmForgetV762(pid,uid)
                info := ""
                sent := D2RemotePickupPacket(ctx.h,uid,info,item.cls)
                SigLogV147("FAST_PICKUP_SEND round=" . w.round . " uid=" . uid . " sent=" . sent . " info=" . info)
                Sleep, 300
                sigStillGroundV1308 := groundRadiusV1307
                    ? SigGroundV147(ctx,groundRadiusV1307) : SigGroundV147(ctx)
                if (sigStillGroundV1308.HasKey(uid))
                {
                    sigSwapReadyV1308 := PickupFailedInventoryReadyV551(ctx.h,ctx.player,pid
                        ,uid,sigStillGroundV1308[uid].unit)
                    if (!sigSwapReadyV1308)
                        SigLogV147("FAST_PICKUP_SWAP_WAIT uid=" . uid . " next=RESCAN_NO_SKIP")
                }
                invFirst := D2ReadU32(ctx.h,ctx.inv+0x10)
                if (invFirst)
                {
                    snapshot := V9SnapshotAllItems({pid:pid,h:ctx.h,inv:ctx.inv,first:invFirst})
                    if (snapshot.HasKey(uid))
                    {
                        picked := snapshot[uid]
                        if (picked.loc=0 && picked.owner=ctx.inv && picked.cls!=1204)
                        {
                            picked.uid := uid
                            cubeStatus := PickupMoveToCubeV2(ctx.h,pid,ctx.inv,picked)
                            SigLogV147("FAST_PICKUP_CUBE uid=" . uid . " result=" . cubeStatus)
                        }
                    }
                }
            }
        }
    }
    finally
    {
        w.active := false
        if (ticketPickupWaitV279=w)
            ticketPickupWaitV279 := false
        if (sigPickupOwnerV764=w)
            sigPickupOwnerV764 := false
        pickupContextModeV765 := previousMode
        pickupBackgroundV181 := previousBackground
        DllCall("CloseHandle","Ptr",ctx.h)
    }
}

SigWaitPickupDoneV320(pid,level,scope:=false)
{
    global ticketPickupWaitV279,sigPickupOwnerV764,sigCancelV147,pickupImageOn,pickupTimerBusy
    global pickupBackgroundV181,sigBusyV147,sigActiveModeV182
    global pickupContextModeV765,sigFailedItemsV765
    if (SigPickupOwnedV764())
        throw Exception("Đang có một lượt thu hồi SIG khác; không mở lượt nhặt chồng")
    scopeV654 := IsObject(scope) ? scope : SigPickupScopeV654(pid,level)
    w := {pid:pid,level:level,checks:0,emptyAt:0,done:false,scanAt:0,remaining:-1,active:true
        ,sigScopeV654:true,xV654:scopeV654.x,yV654:scopeV654.y,radiusV654:scopeV654.radius,scanSerialV764:0
        ,failNoticeAt:0,blockReasonV468:""}
    sigPickupOwnerV764 := w,ticketPickupWaitV279 := w
    previousBackgroundV320 := pickupBackgroundV181
    previousModeV765 := pickupContextModeV765
    pickupContextModeV765 := "SIG"
    sigFailedItemsV765 := {}
    pickupBackgroundV181 := true
    started := A_TickCount,ok := false
    sigBusyV147 := false
    GameItemActionEndV4("Cube")
    FarmWatchSigGateV753(FarmWatchStateV688(),FarmWatchNowV688())
    try
    {
        PickupEnabledSetV71(true,true,false)
        SetTimer, PickupImageTimer, Off
        while (A_TickCount-started<120000 || (IsObject(sigFailedItemsV765) && sigFailedItemsV765.Count()>0))
        {
            if (sigCancelV147)
                throw Exception("Đã hủy thu hồi SIG")
            if (ticketPickupWaitV279!=w)
                throw Exception("Lượt xác nhận nhặt SIG bị thay đổi; chưa được phép báo Done")
            if (!pickupImageOn)
                throw Exception("Nhặt bị tắt trong lúc thu hồi SIG; chưa xác nhận hết đồ")
            if (RoomRecordLevelV259(pid)!=level)
                throw Exception("Đã rời map; chưa xác nhận nhặt hết đồ SIG")
            if (!pickupTimerBusy && GameItemActionBeginV4("Pickup","cube"))
            {
                pickupTimerBusy := true
                try
                    PickupV61Tick()
                finally
                {
                    pickupTimerBusy := false
                    GameItemActionEndV4("Pickup")
                }
            }
            if (IsObject(sigFailedItemsV765) && sigFailedItemsV765.Count()>0)
            {
                baseV765 := D2GetModuleBaseV35(pid,"D2Client.dll")
                hV765 := baseV765 ? D2OpenProcess(pid) : 0
                if (hV765)
                {
                    try
                    {
                        playerV765 := D2ReadU32(hV765,baseV765+0x11BBFC)
                        pathV765 := playerV765 ? D2ReadU32(hV765,playerV765+0x2C) : 0
                        if (pathV765 && MonsterBossProbeReadV1(hV765,pathV765,0x20,pbV765)
                            && CoordLevelV14(hV765,NumGet(pbV765,0x1C,"UInt"))=level)
                        {
                            invV765 := D2ReadU32(hV765,playerV765+0x60)
                            if (invV765)
                            {
                                ctxV765 := {pid:pid,h:hV765,player:playerV765,inv:invV765,first:D2ReadU32(hV765,invV765+0x10)}
                                groundV765 := SigGroundV147(ctxV765)
                                for failUidV765,failInfoV765 in sigFailedItemsV765.Clone()
                                {
                                    if (!groundV765.HasKey(failUidV765))
                                    {
                                        sigFailedItemsV765.Delete(failUidV765)
                                        SigLogV147("SIG_FAIL_CLEARED uid=" . failUidV765 . " reason=NOT_ON_GROUND")
                                    }
                                }
                            }
                        }
                    }
                    finally
                        DllCall("CloseHandle","Ptr",hV765)
                }
            }
            if (IsObject(sigFailedItemsV765) && sigFailedItemsV765.Count()>0
                && (!w.failNoticeAt || A_TickCount-w.failNoticeAt >= 15000))
            {
                w.failNoticeAt := A_TickCount
                failListV765 := ""
                for failUidV765,failInfoV765 in sigFailedItemsV765
                    failListV765 .= (failListV765="" ? "" : ", ") . "UID " . failUidV765 . " class " . failInfoV765.cls
                ToolTipInfoV386("[SIG] Chưa nhặt được: " . failListV765 . ". Nhặt tay hoặc dọn Cube; tool chạy tiếp khi hết.")
            }
            if (SigPickupProofReadyV764(w,pid,level)
                && (!IsObject(sigFailedItemsV765) || sigFailedItemsV765.Count()=0))
            {
                SigLogV147("SIG_PICKUP_CONFIRMED checks=" . w.checks . " eligible_ground=0 cursor=EMPTY")
                ok := true
                break
            }
            ToolTipInfoV386("SIG: còn " . (w.remaining<0 ? "chưa quét" : w.remaining)
                . " món — " . SigPickupWaitTextV764(w))
            Sleep, 100
        }
        if (!ok)
            throw Exception("Thu hồi SIG chưa hoàn tất: " . SigPickupWaitTextV764(w))
    }
    finally
    {
        w.active := false
        if (ticketPickupWaitV279=w)
            ticketPickupWaitV279 := false
        if (sigPickupOwnerV764=w)
            sigPickupOwnerV764 := false
        if (pickupImageOn)
            SetTimer, PickupImageTimer, 20
        pickupBackgroundV181 := previousBackgroundV320
        pickupContextModeV765 := previousModeV765
        sigFailedItemsV765 := {}
    }
    return ok
}
SigInventoryToCubeV719(ctx,cube)
{
    moved := 0
    Loop
    {
        SigCheckV147(ctx)
        nextItem := false
        for uid,item in SigSnapshotV147(ctx)
        {
            if (item.loc!=0 || item.owner!=ctx.inv || !item.data || item.cls=1204
                || SigReusableItemV225(item) || D2ReadU32(ctx.h,item.unit+0x10)!=0)
                continue
            if ((item.q!=5 && item.q!=7) || PickupIsCharmV571(ctx.h,item.cls))
                continue
            if (item.q=7)
            {
                if (!MonsterBossProbeReadV1(ctx.h,item.data+0x28,4,uniqueIndexV719))
                    continue
                tierV719 := UniqueItemsTierFromLiveTableV1(ctx.h,NumGet(uniqueIndexV719,0,"UInt"),wLvlV719)
                if (!UniqueKnownTierV4(tierV719))
                    continue
            }
            nextItem := item
            break
        }
        if (!IsObject(nextItem))
        {
            SigLogV147("SIG_REMAINDERS_TO_CUBE_DONE moved=" . moved)
            return true
        }
        SigToCubeV147(ctx,nextItem,cube,true)
        moved++
        SigLogV147("SIG_REMAINDER_TO_CUBE uid=" . nextItem.uid . " class=" . nextItem.cls)
    }
}

SigFlowCraftV901(ctx,resumeStep5)
{
        if (!resumeStep5)
        {
            SigLogV147("SORT_BEFORE_CUBE packet=4A04000000")
            SigPacketV147(ctx,[0x4A,0x04,0x00,0x00,0x00],true)
            Sleep, 200
        }
        SigCheckV147(ctx)
        cube := 0
        if (!PickupFileFirstRuleV97(cls,q) || cls!=1204 || q!="02")
            SigFailV147("Không xác nhận được luật Cube cố định của danh sách nhặt")
        for uid,a in SigSnapshotV147(ctx)
            if (a.cls=1204 && a.q=2 && a.loc=0 && a.owner=ctx.inv)
            {
                cube := a
                break
            }
        if (!IsObject(cube))
            SigFailV147("Không thấy Cube 1204|02 trong rương")
        ctx.cubeUid := cube.uid
        SigReserveReagentHomesV192(ctx)
        SigLogV147("BEGIN pid=" . ctx.pid . " cube_uid=" . cube.uid)
        if (resumeStep5)
        {
            SigLogV147("RESUME_STEP5 skip=TOWN_SORT_DROP_SET")
            SigGroupV147(ctx,cube,5,true)
            SigGroupVerifiedV16(ctx,cube,7)
        }
        else
        {
        if (SigCubeItemsV147(ctx).Length())
			SigCubeDropPickupV280(ctx,cube)
		else
			SigLogV147("CUBE_DROP_SKIP reason=ALREADY_EMPTY next=SET_GROUP")
		SigLogV147("SIG_MODE_BRANCH mode=SET_PLUS_SELECTED_UNIQUES set_fragments=ON")
		SigGroupVerifiedV16(ctx,cube,5)
		SigGroupVerifiedV16(ctx,cube,7)
        }
        SigReturnCatalystsV652(ctx)
        ; KHONG thu cont lan 2 o day: doi den khi nhat SIG hoan tat.
        SigInventoryToCubeV719(ctx,cube)
        SigCloseCubeV156()
    return cube
}

SigFlowPickupV901(ctx,cube,mode)
{
    global sigPostPickupV655,sigBusyV147,gameItemActionOwner,sigCancelV147
    levelSigV320 := RoomRecordLevelV259(ctx.pid)
    SigLogV147("SIG_TO_PICKUP mode=" . mode . " level=" . levelSigV320 . " next=REAL_PICKUP")
    sigPostPickupV655 := {pid:ctx.pid,level:levelSigV320,scope:ctx.sigPickupScopeV654}
    if (!SigFastPickupV1307(ctx.pid,levelSigV320,ctx.sigPickupScopeV654))
        SigFailV147("Nhặt chưa xác nhận hết đồ; dừng Sig")
    sigBusyV147 := true
    ; The main SigRunV147 already acquired the Cube action lock. Do not
    ; acquire it again: GameItemActionBeginV4 rejects even the same owner.
    ; This is the exact same shared flow for the Sig button and map entry.
    if (gameItemActionOwner="Cube")
        SigLogV147("SIG_CUBE_LOCK_REUSE after=FAST_PICKUP owner=Cube")
    else
    {
        if (gameItemActionOwner!="")
            SigFailV147("Đang có thao tác đồ khác sau nhặt SIG: " . gameItemActionOwner)
        if (sigCancelV147 || !GameItemActionBeginV4("Cube","cube",true))
            SigFailV147("Chưa lấy được quyền chuyển đồ còn lại vào Cube")
        SigLogV147("SIG_CUBE_LOCK_REACQUIRED after=FAST_PICKUP")
    }
    SigInventoryToCubeV719(ctx,cube)
    SigCloseCubeV156()
    ; Transmute thu thanh pham lan 2: CHI GUI sau khi nhat xong.
    SigLogV147("SIG_SORT_AFTER_PICKUP_BEGIN packet=4A04000000 verify_items=NO")
    SigSortContainerV191(ctx)
    SigLogV147("SIG_SORT_AFTER_PICKUP_SENT result=NO_CHECK")
    return true
}

SigRunV147(mode:="BOTH",resumeStep5:=false)
{
    mode := "BOTH"
    RareWarningLoadV1()
    global sigBusyV147,sigCancelV147,sigSendingKeyV147,xRunning,zRunning,packetWatchArmedV1
    global pickupRoundResetV1,pickupLastClick,sigCubeUiOpenV159,sigBackgroundV179,sigActiveModeV182
    global sigLastStopReasonV63,pickupTimerBusy,pickupFarmWorkV75,pickupOptJobV12
    global sigPostPickupV655,sigCompleteSerialV655,sigCompletePidV655,sigResetPendingV753
    global sigSessionActiveV1321,pickupSigListOnlyV1321
    global sigTUV586,sigSUV510,sigSSUV13,sigSSSUV13,pickupImageOn,sigSessionSerialV761,sigRunEpochV1320
    oldPickupV575 := pickupImageOn,heldV575 := false
    global ticketPickupWaitV279,scosEntryV162
    if (sigBusyV147 || IsObject(ticketPickupWaitV279) || !IsGameActive() || xRunning || zRunning || packetWatchArmedV1)
    {
        SigLogV147("START_REJECT busy=" . sigBusyV147 . " target=" . GameTargetHwndV63()
            . " x=" . xRunning . " z=" . zRunning . " packet_watch=" . packetWatchArmedV1)
        ToolTipInfoV386("Chưa chạy Sig: game không sẵn sàng hoặc đang có thao tác khác.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    SigFreshStartV1307()
    GuiControlGet, sigTUV586, 1:, SigTUInputV586
GuiControlGet, sigSUV510, 1:, SigSUInputV510
    GuiControlGet, sigSSUV13, 1:, SigSSUInputV13
    sigBusyV147 := true,sigCancelV147 := false
    FarmWatchSigGateV753(FarmWatchStateV688(),FarmWatchNowV688())
    PickupCtrlEndV26()
    PickupEnabledSetV71(false,true,false)
    pickupFarmWorkV75 := false
    SetTimer, PickupImageTimer, Off
    SigLogV147("PICKUP_OFF before=SIG group_pickup=OFF restore=PREVIOUS_STATE")
    drainStartedV225 := A_TickCount
    while (pickupTimerBusy && A_TickCount-drainStartedV225<4000 && !sigCancelV147)
        Sleep, 50
    if (pickupTimerBusy || sigCancelV147 || !GameItemActionBeginV4("Cube","cube",true))
    {
        sigBusyV147 := false
        FarmWatchSigGateV753(FarmWatchStateV688(),FarmWatchNowV688())
        if (!sigCancelV147)
            PickupEnabledSetV71(oldPickupV575,true,false)
        SigLogV147("START_REJECT reason=ITEM_ACTION_LOCK_OR_CURSOR pickup=OFF")
        ToolTipInfoV386("Chưa chạy Sig: đang xử lý đồ hoặc có vật phẩm trên chuột.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    sigBusyV147 := true, sigCancelV147 := false
    sigSessionActiveV1321 := true
    sigCubeUiOpenV159 := resumeStep5 ? true : false
    sigResetPendingV753 := true
    sigActiveModeV182 := "SET_SU",sigPostPickupV655 := false
    GuiControl,, SigButtonV147, Hủy
    GuiControl, Disable, SigSuButtonV181
    SigLogV147("ACTIVE_MODE mode=" . sigActiveModeV182)
    ctx := 0, success := false, message := "SIG xong — đã ghép mảnh, nhặt đồ và chuyển Set/TU/SU/SSU/SSSU còn lại vào Cube"
    try
    {
        ctx := SigOpenContextV149()
        ctx.sigRunEpochV1320 := sigRunEpochV1320 ; context/PID moi cua luot hien tai
        SigLogV147("SIG_NEW_CONTEXT epoch=" . ctx.sigRunEpochV1320 . " pid=" . ctx.pid)
        ; Cap nhat DS Khong SIG khi bat dau SIG, ke ca khi file vua duoc sua tren dia.
        if (FileExist(PickupNoSigFileV490()))
            PickupNoSigLoadV490()
        ctx.boCombinedSigV459 := IsObject(scosEntryV162) && scosEntryV162.map="BO"
            && scosEntryV162.pid=ctx.pid && scosEntryV162.boStageV413=1
        ctx.sigPickupScopeV654 := SigPickupScopeV654(ctx.pid,RoomRecordLevelV259(ctx.pid))
        if (!SetNoSigLoadV227(ctx))
            SigFailV147("Không đọc được danh sách Set không SIG; dừng để giữ đồ")
        tooltipWaitV225 := A_TickCount
        Loop
        {
            SigCheckV147(ctx)
            PickupOptPollV12()
            if (!IsObject(pickupOptJobV12))
                break
            if (A_TickCount-tooltipWaitV225>4000)
                SigFailV147("Đang đọc tên/option item; nhặt đã tắt, chờ rồi SIG lại")
            Sleep, 50
        }
        cube := SigFlowCraftV901(ctx,resumeStep5)
        if (!SigFlowPickupV901(ctx,cube,mode))
            SigFailV147("Nhặt SIG chưa hoàn thành")
        success := true
        sigLastStopReasonV63 := "COMPLETED_PICKUP_VERIFIED"
        sigPostPickupV655 := false,sigCompleteSerialV655++,sigCompletePidV655 := ctx.pid
        SigLogV147("END mode=" . mode . " pickup=REAL_VERIFIED")
    }
    catch e
    {
        message := "Sig: " . e.Message
        sigLastStopReasonV63 := e.Message
        if (sigBusyV147 && !sigCancelV147 && IsObject(ctx) && ctx.cubeUid && IsGameActive() && D2GetActiveGamePidV95()=ctx.pid)
        {
            try
                SigReturnCatalystsV652(ctx)
            catch catalystErrorV652
            {
                message .= " — trả catalyst: " . catalystErrorV652.Message
                SigLogV147("CATALYST_RETURN_ON_ERROR_FAILED reason=" . catalystErrorV652.Message)
            }
        }
        if (IsObject(ctx) && IsGameActive() && D2GetActiveGamePidV95()=ctx.pid)
        {
            cursor := PickupCursorV4(ctx.h,ctx.inv)
            if (IsObject(cursor) && cursor.unit)
            {
                heldV575 := true
                PickupEnabledSetV71(false,true,false)
                message .= " — có item trên chuột, nhặt đã tắt"
            }
        }
        SigLogV147("STOP reason=" . e.Message)
        if (!sigCancelV147 && !heldV575 && IsObject(ctx) && IsObject(ctx.sigPickupScopeV654)
            && IsGameActive() && D2GetActiveGamePidV95()=ctx.pid
            && ctx.sigSessionV761=sigSessionSerialV761)
        {
            try
            {
                SigCloseCubeV156()
                recoveryLevelV764 := RoomRecordLevelV259(ctx.pid)
                sigPostPickupV655 := {pid:ctx.pid,level:recoveryLevelV764,scope:ctx.sigPickupScopeV654}
                SigLogV147("SIG_ERROR_PICKUP_BEGIN next=REAL_PICKUP_BEFORE_STOP")
                if (SigWaitPickupDoneV320(ctx.pid,recoveryLevelV764,ctx.sigPickupScopeV654))
                {
                    sigPostPickupV655 := false,sigResetPendingV753 := false
                    sigLastStopReasonV63 := e.Message . " — đã thu hồi đồ, dừng SIG"
                    message := "SIG lỗi — đã thu hồi đồ: " . e.Message
                    SigLogV147("SIG_ERROR_PICKUP_DONE craft_success=0")
                }
            }
            catch collectErrorV764
            {
                sigLastStopReasonV63 := e.Message . " — thu hồi chưa xong: " . collectErrorV764.Message
                message := sigLastStopReasonV63
                SigLogV147("SIG_ERROR_PICKUP_FAILED reason=" . collectErrorV764.Message)
            }
        }
    }
    finally
    {
        if (IsObject(ctx))
            DllCall("CloseHandle","Ptr",ctx.h)
        sigBusyV147 := false, sigSendingKeyV147 := false
        pickupRoundResetV1 := true, pickupLastClick := 0
        GameItemActionEndV4("Cube")
        if (!sigCancelV147 && !heldV575)
        {
            if (success)
            {
                pickupSigListOnlyV1321 := true
                PickupEnabledSetV71(true,true,false)
                SigLogV147("SIG_DONE_NORMAL_PICKUP_ON filter=ITEM_NHAT_TXT_ONLY")
            }
            else
            {
                PickupEnabledSetV71(false,true,false)
                SigLogV147("SIG_NOT_FINISHED_NORMAL_PICKUP_OFF")
            }
        }
        sigSessionActiveV1321 := false
        SetTimer, PickupImageTimer, 20
        GuiControl,, SigButtonV147, Sig
        GuiControl,, SigSuButtonV181, Sig
        GuiControl, Enable, SigButtonV147
        GuiControl, Enable, SigSuButtonV181
        sigActiveModeV182 := ""
        if (success)
            sigResetPendingV753 := false
        FarmWatchSigGateV753(FarmWatchStateV688(),FarmWatchNowV688())
    }
    ToolTipInfoV386(message)
    SetTimer, RemoveToolTip, -5000
    return success
}


SigCubeCaptureStopV151()
{
    global sigCubeCaptureV151
    SetTimer, SigCubeCaptureTimerV151, Off
    if (!IsObject(sigCubeCaptureV151))
        return
    PacketWatchStopV1()
    sigCubeCaptureV151 := false
}

SigCubeCaptureTimerV151:
if (!IsObject(sigCubeCaptureV151) || !ManualLogActiveV81())
{
    SigCubeCaptureStopV151()
    return
}
if (!sigCubeCaptureV151.until)
{
    if (A_TickCount-sigCubeCaptureV151.armed>=30000)
    {
        SigLogV147("CUBE_CAPTURE_STOP reason=NO_FOREGROUND_GAME")
        SigCubeCaptureStopV151()
        return
    }
    capturePidV151 := D2GetActiveGamePidV95()
    if (!IsGameActive() || !capturePidV151)
        return
    if (!PacketWatchStartV1(capturePidV151))
    {
        SigLogV147("CUBE_CAPTURE_STOP reason=ATTACH_FAILED")
        SigCubeCaptureStopV151()
        return
    }
    sigCubeCaptureV151.until := A_TickCount+15000
    ToolTipInfoV386("DÒ CUBE ĐÃ SẴN SÀNG: mở cube và bấm C bằng tay. Dò trong 15 giây.")
    SetTimer, RemoveToolTip, -15000
}
if (A_TickCount>=sigCubeCaptureV151.until)
{
    SigLogV147("CUBE_CAPTURE_STOP reason=15_SECONDS_DONE")
    SigCubeCaptureStopV151()
    ToolTipInfoV386("DÒ CUBE XONG: gửi log Rương-Cube của lần này.")
    SetTimer, RemoveToolTip, -5000
    return
}
Critical, On
PacketWatchPollV1()
Critical, Off
if (!IsObject(packetWatchV1))
{
    SigCubeCaptureStopV151()
    return
}
captureCV151 := IsGameForegroundV63() && GetKeyState("c","P")
if (captureCV151 && !sigCubeCaptureV151.lastC)
    SigLogV147("CUBE_CAPTURE_MANUAL_C")
sigCubeCaptureV151.lastC := captureCV151
return

FarmCombatYieldV237()
{
    global autoMonsterAttackOn,farmResumeArmedV70,farmResumeOutsideV70
    FarmAttackHoldReleaseV15()
    autoMonsterAttackOn := false
    farmResumeArmedV70 := false,farmResumeOutsideV70 := false
    FarmCastSyncV88(false)
	    FonInfoPushV385("Đang chuyển bước xử lý; phiên farm vẫn tiếp tục.")
    SetTimer, AutoMonsterAttackTimer, Off
    SetTimer, FarmResumeTimerV70, Off
    MovementCtrlSetV78(false,0,"SIG_PHASE_HANDOFF")
    PortalLogWriteV66("FARM_PHASE_HANDOFF run=ON combat=YIELD route=PRESERVED")
}


SigTownCancelV148(reason)
{
    global sigTownV148,sigCancelV147,sigBusyV147
    if (!IsObject(sigTownV148))
        return
    SigLogV147("TOWN_TEST_STOP step=" . sigTownV148.step . " reason=" . reason . " return_to_map=0")
    restorePickupV575 := sigTownV148.pickupBeforeV575
    sigTownV148 := false
    if (!sigBusyV147 && !RegExMatch(reason,"i)STOP|CANCEL|EXIT|PROFILE|SHUTDOWN"))
        PickupEnabledSetV71(restorePickupV575,true,false)
    if (sigBusyV147)
        sigCancelV147 := true
    SetTimer, SigTownTimerV148, Off
}

SigTownStepV148(r,step)
{
    r.step := step,r.stepAt := A_TickCount,r.last := 0
    SigLogV147("TOWN_TEST_STEP " . step)
}

SigTownEnterReadyV148(pid,level)
{
    global sigTownV148,manualLogOnV81,autoMonsterAttackOn,xRunning,zRunning,gameItemActionOwner,packetWatchArmedV1
    return IsObject(sigTownV148) && sigTownV148.pid=pid
        && ((sigTownV148.step="ENTER" && sigTownV148.source=level)
            || (sigTownV148.step="RETURN_PORTAL" && sigTownV148.town=level))
        && (sigTownV148.auto || manualLogOnV81)
        && !autoMonsterAttackOn && !xRunning && !zRunning && !packetWatchArmedV1 && gameItemActionOwner=""
        && IsGameActive() && D2GetActiveGamePidV95()=pid
}

SigTownNewPortalV148(h,ByRef pb,r)
{
    global farmControlOwnerV186
    libReturnV280 := r.libReturnV283
    seen := {}, px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort"),best := false,bestDist := libReturnV280 ? 1.0e30 : 401
    for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
    {
        u := D2ReadU32(h,room+0x74)
        Loop, 1024
        {
            if (!u || seen.HasKey(u))
                break
            seen[u] := true
            cls := D2ReadU32(h,u+4),uid := D2ReadU32(h,u+0x0C)
            if (D2ReadU32(h,u)=2 && uid
                && (libReturnV280 ? cls=59 : ((cls=59 || cls=60) && !r.before.HasKey(uid))))
            {
                path := D2ReadU32(h,u+0x2C)
                x := D2ReadU32(h,path+0x0C),y := D2ReadU32(h,path+0x10)
                d := (x-px)**2+(y-py)**2
                if (d<bestDist)
                    best := {unit:u,uid:uid,cls:cls,x:x,y:y},bestDist := d
            }
            next := D2ReadU32(h,u+0xE8)
            if (next=u)
                break
            u := next
        }
    }
    return best
}

SigTownMoveV148(r,x,y,level,stop:=false)
{
    global coordGoV59
    if (!IsGameActive() || D2GetActiveGamePidV95()!=r.pid)
        return false
    goal := {pid:r.pid,level:level,row:0,redirect:true,stop:stop,resumeFarm:false}
    coordGoV59 := goal
    try
        return NativeMovePointV14(r.pid,x,y,level,true,false,true,goal)
    finally
        if (coordGoV59=goal)
            coordGoV59 := false
}

SigCubeFullQueueV153()
{
    global autoMonsterAttackOn,sigTownV148,sigBusyV147,labInventoryOnlyV311
    if (BossSearchActiveV430())
    {
        V104CubeLog("ITEM_SEARCH_CUBE_REJECT farm=CONTINUE pickup=RETRY target_inventory=CHECK")
        return
    }
    if (CainIntermediatePickupHoldV370())
        return
    if (Lab1SingleRunV310())
    {
        labInventoryOnlyV311 := true
        SigLogV147("LAB_CUBE_FULL next=PICK_TO_INVENTORY farm=CONTINUE town_sig=OFF")
        return
    }
    if (autoMonsterAttackOn && !IsObject(sigTownV148) && !sigBusyV147)
        SetTimer, SigCubeFullStartV153, -10
}

SigCubeFullStartV153:
if (CainIntermediatePickupHoldV370())
    return
if (!autoMonsterAttackOn || IsObject(sigTownV148) || sigBusyV147)
    return
if (gameItemActionOwner!="" || xRunning || zRunning)
{
    SetTimer, SigCubeFullStartV153, -100
    return
}
if (!IsObject(farmCubeSortOnceV253) || farmCubeSortOnceV253.pid!=backgroundPidV63
    || farmCubeSortOnceV253.birth!=backgroundBirthV63)
{
    if (!GameItemActionBeginV4("FarmCubeSort","cube",true))
    {
        SetTimer, SigCubeFullStartV153, -100
        return
    }
    sortCtxV253 := false
    try
    {
        sortCtxV253 := SigOpenContextV149()
        sortCtxV253.farmSortV253 := true
        farmCubeSortOnceV253 := {pid:backgroundPidV63,birth:backgroundBirthV63,attempted:true}
        SigPacketV147(sortCtxV253,[0x4A,0x04,0x00,0x00,0x00],true)
        Sleep, 350
        SigLogV147("AUTO_CUBE_FULL sort_attempt=1 next=CONTINUE_FARM town=0")
    }
    catch sortErrorV253
    {
        SigLogV147("AUTO_CUBE_SORT_ERROR reason=" . sortErrorV253.Message . " next=CONTINUE_FARM")
    }
    finally
    {
        if (IsObject(sortCtxV253) && sortCtxV253.h)
            DllCall("CloseHandle","Ptr",sortCtxV253.h)
        pickupRoundResetV1 := true,pickupLastClick := 0
        GameItemActionEndV4("FarmCubeSort")
    }
    return
}
FarmPickupFullHoldV371()
return

SigFarmResumeV152:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    SetTimer, SigFarmResumeV152, Off
    return
}
if (!IsObject(sigFarmResumePendingV237))
    return
if (!BackgroundValidV63())
{
    SetTimer, SigFarmResumeV152, -2000
    return
}
if (sigFarmResumePendingV237.pid!=backgroundPidV63)
    return
sigFarmResumePendingV237 := false
farmResumeInternalV70 := true
autoMonsterAttackOn := true
try
    Gosub, AutoMonsterAttackToggle
finally
    farmResumeInternalV70 := false
SigLogV147("FARM_RESUMED after=SIG auto=" . autoMonsterAttackOn . " route=FRESH_FILE_FROM_YELLOW old_route=DISCARDED")
return

SigTownTimerV148:
if (farmUserPausedV2026 && IsObject(sigTownV148) && sigTownV148.auto)
    return
SigTownTickV148()
return

SigTownInteractStashV342(pid, level, stash)
{
    global autoMonsterPacketPendingV1
    if (!IsObject(stash) || !AutoMonsterPacketCleanupV1())
        return false
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? DllCall("OpenProcess","UInt",0x043A,"Int",0,"UInt",pid,"Ptr") : 0
    if (!h)
        return false
    remote := 0, owned := false
    try
    {
        if (!NativeRightClickBuildV9(h,base)
            || !MonsterBossProbeReadV1(h,base+0x2AC10,12,entry)
            || MonsterBossProbeHexV1(entry,12)!="83EC2C53550FB7E98BDA5657")
            return false
        player := D2ReadU32(h,base+0x11BBFC), mode := player ? D2ReadU32(h,player+0x10) : 0
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if ((mode!=1 && mode!=5) || !MonsterBossProbeReadV1(h,path,0x20,pb)
            || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=level
            || (NumGet(pb,2,"UShort")-stash.x)**2+(NumGet(pb,6,"UShort")-stash.y)**2>400)
            return false
        inv := D2ReadU32(h,player+0x60), cursor := inv ? PickupCursorV4(h,inv) : false
        if (!IsObject(cursor) || cursor.unit)
            return false
        live := CycObjectV42(h,pb,stash.cls,stash.x,stash.y,1)
        if (!IsObject(live) || live.uid!=stash.uid || live.unit!=stash.unit)
            return false
        remote := DllCall("VirtualAllocEx","Ptr",h,"Ptr",0,"UPtr",128,"UInt",0x3000,"UInt",0x40,"Ptr")
        if (!remote || remote>0xFFFFFFFF)
            return false
        hex := FarmPortalCodeTownOnlyV68(base,stash.uid,level,2)
        length := StrLen(hex)//2
        VarSetCapacity(blob,128,0)
        Loop, %length%
            NumPut("0x" . SubStr(hex,(A_Index-1)*2+1,2),blob,A_Index-1,"UChar")
        if (!DllCall("WriteProcessMemory","Ptr",h,"Ptr",remote,"Ptr",&blob,"UPtr",128,"UPtrP",written) || written!=128)
            return false
        DllCall("FlushInstructionCache","Ptr",h,"Ptr",remote,"UPtr",length)
        currentPlayer := D2ReadU32(h,base+0x11BBFC)
        currentPath := currentPlayer ? D2ReadU32(h,currentPlayer+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,currentPath,0x20,currentPb)
            || CoordLevelV14(h,NumGet(currentPb,0x1C,"UInt"))!=level
            || D2ReadU32(h,stash.unit)!=2
            || D2ReadU32(h,stash.unit+0x0C)!=stash.uid
            || D2ReadU32(h,stash.unit+4)!=stash.cls)
            return false
        thread := DllCall("CreateRemoteThread","Ptr",h,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
        if (!thread)
            return false
        autoMonsterPacketPendingV1 := {process:h,remote:remote,thread:thread,uid:stash.uid,kind:"PORTAL_DLL",portalCall:true,setAt:A_TickCount}
        owned := true
        SetTimer, AutoMonsterPacketCleanupTimerV1, 50
        SigLogV147("SIG_TOWN_STASH_INTERACT uid=" . stash.uid . " class=" . stash.cls
            . " xy=" . stash.x . "," . stash.y . " queued=1")
        return true
    }
    finally
    {
        if (!owned)
        {
            if (remote)
                DllCall("VirtualFreeEx","Ptr",h,"Ptr",remote,"UPtr",0,"UInt",0x8000)
            DllCall("CloseHandle","Ptr",h)
        }
    }
}

TownStoreLoadV628(raw)
{
    global townStoreRulesV628,townStoreGroupsV637
    townStoreRulesV628 := [],townStoreGroupsV637 := {}
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField," `t`r`n" . Chr(0xFEFF))
        if (line="" || SubStr(line,1,1)="#")
            continue
        if (RegExMatch(line,"i)^CLASS\s*=\s*(\d+)",m))
        {
            townStoreRulesV628.Push({name:".*",stats:[],qualities:{},tiers:{},eth:false,exactClassV638:m1+0,raw:line})
            continue
        }
        if (RegExMatch(line,"^[^|]+\|\s*(\d+)(?:\s*\|.*)?$",m))
        {
            townStoreRulesV628.Push({name:".*",stats:[],qualities:{},tiers:{},eth:false,exactClassV638:m1+0,raw:line})
            continue
        }
        if (RegExMatch(line,"^\d+$",m))
        {
            townStoreRulesV628.Push({name:".*",stats:[],qualities:{},tiers:{},eth:false,exactClassV638:line+0,raw:line})
            continue
        }
        group := PickupAutoGroupParseV7(line)
        if (group!="" && SubStr(group,1,5)!="NAME:")
            townStoreGroupsV637[group] := true
        else if (IsObject(rule := PickupOptParseV12(line,error)))
            townStoreRulesV628.Push(rule)
    }
}

TownStoreEnabledV629()
{
    global townStoreRulesV628,townStoreGroupsV637
    if (!IsObject(townStoreRulesV628) || !IsObject(townStoreGroupsV637))
    {
        RareWarningReadTextV35(UniquePickupFileV3(),raw,true)
        parts := PickupCanonicalParseV491(raw)
        TownStoreLoadV628(parts.store)
    }
    return townStoreRulesV628.Length()>0 || townStoreGroupsV637.Count()>0
}

TownStoreMatchV628(h,unit,cls,q,data,ByRef ready)
{
    global townStoreRulesV628,townStoreGroupsV637,consumableClassRAMV7
    ready := true
    if (!TownStoreEnabledV629())
        return false
    if (!h || !unit || !data)
    {
        ready := false
        return false
    }
    needsNameV638 := townStoreGroupsV637.Count()>0
        for _,rule in townStoreRulesV628
    {
        if (rule.HasKey("exactClassV638"))
        {
            if (cls+0=rule.exactClassV638)
                return true
        }
        else
            needsNameV638 := true
    }
    if (!needsNameV638)
        return false
    groups := townStoreGroupsV637,tier := ""
    if ((q=5 && groups.HasKey("SET_XANH")) || (q=7 && groups.HasKey("UNIQUE")))
        return true
    if (groups.HasKey("CHARM") && PickupIsCharmV571(h,cls))
        return true
    if (groups.HasKey("ANGELIC") && PickupSetIsAngelicV13(h,cls,data,unit))
        return true
    if (q=7)
    {
        tier := UniqueItemsTierFromLiveTableV1(h,D2ReadU32(h,data+0x28),wlvl)
        if (tier!="" && groups.HasKey(tier))
            return true
    }
    ConsumablePickupGroupV7(h,cls)
    pid := DllCall("GetProcessId","Ptr",h,"UInt"),key := pid . "|" . cls
    baseReady := IsObject(consumableClassRAMV7) && consumableClassRAMV7.HasKey(key)
    baseName := baseReady ? consumableClassRAMV7[key] : ""
    for group,_ in groups
        if (PickupAlertGroupMatchV14(group,q,tier,q=5,baseName))
            return true
    PickupOptPollV12()
    flags := D2ReadU32(h,data+0x18)
    info := PickupOptReadV12(h,unit,cls,q,data,flags)
    if (!IsObject(info) || !info.ok)
    {
        ready := false
        return false
    }
        realName := info.name
    if (q=7)
    {
        un := PickupUniqueStringNameV766(h,DllCall("GetProcessId","Ptr",h,"UInt"),data)
        if (un!="")
            realName := un
    }
    else if (q=5)
    {
        tmpPid := DllCall("GetProcessId","Ptr",h,"UInt")
        tmpCtx := {h:h,pid:tmpPid,setNoSigNamesV227:[],setNameCacheV227:{},setKeepLoggedV227:{}}
        sn := SigSetNameV227(tmpCtx,{unit:unit,uid:D2ReadU32(h,unit+0x0C),cls:cls,data:data})
        if (sn!="")
            realName := sn
    }
    name := RegExReplace(realName . "`n" . baseName,Chr(255) . "c.","")
    for group,_ in groups
        if (PickupAlertGroupMatchV14(group,q,tier,q=5,name))
            return true
    for _,rule in townStoreRulesV628
        if (PickupOptRuleMatchV12(rule,q,flags,realName,info.stats,baseName,h,cls))
            return true
    ready := baseReady
    return false
}

TownStorePrepareV629(r,ctx,player)
{
    if (!TownStoreEnabledV629())
        return {items:[],pending:false}
    ctx.player := player,ctx.inv := D2ReadU32(ctx.h,player+0x60)
    if (!ctx.inv)
        throw Exception("Chuyển Kho: chưa đọc được túi nhân vật")
    if (!IsObject(r.storeSourcesV629) || r.storePlayerV629!=player || r.storePidV629!=ctx.pid)
        r.storeSourcesV629 := {},r.storePlayerV629 := player,r.storePidV629 := ctx.pid
    
    all := SigSnapshotV147(ctx),ground := SigGroundV147(ctx)
    for uid,a in all
        if (a.loc=3 && r.storePhaseV632!="GROUND" && D2ReadU32(ctx.h,a.unit+0x10)=0 && !r.storeSourcesV629.HasKey(uid))
            r.storeSourcesV629[uid] := {uid:uid,cls:a.cls,q:a.q,seed:D2ReadU32(ctx.h,a.data+0x14),source:"CUBE"}
    for uid,a in ground
        if (a.cls!=1204 && r.storePhaseV632!="CUBE" && !r.storeSourcesV629.HasKey(uid))
            r.storeSourcesV629[uid] := {uid:uid,cls:a.cls,q:a.q,seed:D2ReadU32(ctx.h,a.data+0x14),source:"GROUND"}
    result := {items:[],pending:false},remove := []
    for uid,record in r.storeSourcesV629
    {
        a := ground.HasKey(uid) ? ground[uid] : all[uid]
        if (!IsObject(a) || a.cls!=record.cls || a.q!=record.q
            || D2ReadU32(ctx.h,a.data+0x14)!=record.seed || a.loc=4)
        {
            remove.Push(uid)
            continue
        }
        if (!(a.loc=-1 || a.loc=3 || (a.loc=0 && a.owner=ctx.inv)))
            continue
        if (a.cls=1204)
            continue
        if (TownStoreMatchV628(ctx.h,a.unit,a.cls,a.q,a.data,ready))
            a.storeSourceV629 := record.source,a.storeSeedV629 := record.seed,result.items.Push(a)
        else if (!ready)
            result.pending := true
    }
    for _,uid in remove
        r.storeSourcesV629.Delete(uid)
    return result
}
TownStorePendingV628(ctx,player,r)
{
    result := TownStorePrepareV629(r,ctx,player)
    return result.pending || result.items.Length()>0
}

TownStoreRunV628(r,ctx,player)
{
    global gameItemActionOwner,sigBusyV147,sigBackgroundV179,sigActiveModeV182
    global pickupImageOn,pickupRoundResetV1,sigCancelV147,sigCubeUiOpenV159
    if (r.storeDoneV628)
        return true
    parentLock := ctx.transferStashV631 && gameItemActionOwner="Cube"
    if (!parentLock && !GameItemActionBeginV4("Cube","cube",true))
        return false
    oldBusy := sigBusyV147,oldBg := sigBackgroundV179,oldMode := sigActiveModeV182
    oldPickup := pickupImageOn,started := A_TickCount
    sigBusyV147 := true,sigBackgroundV179 := true,sigActiveModeV182 := "TRANSFER"
    PickupEnabledSetV71(false,true,false)
    try
    {
        ctx.player := player,ctx.inv := D2ReadU32(ctx.h,player+0x60),cube := false
        for uid,a in SigSnapshotV147(ctx)
            if (a.cls=1204 && a.q=2 && a.loc=0 && a.owner=ctx.inv)
                cube := a
        cubeInInventory := IsObject(cube),cubeOnGround := false
        if (!cubeInInventory)
            for uid,a in SigGroundV147(ctx)
                if (a.cls=1204 && a.q=2)
                    cube := a,cubeOnGround := true
        if (!IsObject(cube))
            throw Exception("Chuyển Kho: cần thấy Cube trong túi hoặc dưới đất")
        ctx.cubeUid := cube.uid
        if (r.goldStepV229="OPEN_WAIT" || r.goldStepV229="VERIFY"
            || r.goldStepV342="OPEN_WAIT" || r.goldStepV342="VERIFY")
            ctx.townStoreStashOpenV631 := true
        TownStoreReadCloseV641(r,ctx)
        for _,phase in ["GROUND","CUBE"]
        {
            if (phase="CUBE" && !cubeInInventory)
                continue
            work := {storePhaseV632:phase,storeSourcesV629:{},pid:ctx.pid}
            waitAt := A_TickCount
            Loop
            {
                SigCheckV147(ctx)
                result := TownStorePrepareV629(work,ctx,player)
                if (!result.items.Length())
                {
                    if (!result.pending)
                        break
                    if (A_TickCount-waitAt>15000)
                        throw Exception("Chuyển Kho: chưa đọc xong tên/opt")
                    Sleep, 50
                    continue
                }
                item := result.items[1]
                if (item.loc=-1)
                    item := TownStoreGroundStageV639(ctx,item)
                TownStorePutV628(ctx,item)
                work.storeSourcesV629.Delete(item.uid)
                r.storeMovedV631 := r.storeMovedV631+1,waitAt := A_TickCount
                FonInfoPushV385("Chuyển Kho: đã cất " . r.storeMovedV631 . " món")
            }
        }
        TownStoreCloseBatchV636(r,ctx)
        if (cubeOnGround)
        {
            GameItemActionEndV4("Cube")
            pickupRoundResetV1 := true
            SigLogV147("TOWN_STORE_GROUND_PICKUP worker=SigWaitPickupDoneV320 cube_uid=" . cube.uid)
            if (!SigWaitPickupDoneV320(ctx.pid,RoomRecordLevelV259(ctx.pid)))
                throw Exception("Chuyển Kho: chưa nhặt xong Cube và đồ còn lại")
            all := SigSnapshotV147(ctx),back := all[cube.uid]
            if (!IsObject(back) || back.cls!=1204 || back.loc!=0 || back.owner!=ctx.inv)
                throw Exception("Chuyển Kho: chưa xác nhận Cube đã về túi")
        }
        r.storeDoneV628 := true
        SigLogV147("TOWN_STORE_DIRECT_DONE moved=" . (r.storeMovedV631+0) . " stash_ui=READ_THEN_CLOSED source=GROUND_AND_CUBE")
        return true
    }
    catch e
    {
        SigLogV147("TOWN_STORE_DIRECT_ERROR reason=" . e.Message)
        throw e
    }
    finally
    {
        try
        {
            cursor := PickupCursorV4(ctx.h,ctx.inv)
            if (IsObject(cursor) && !cursor.unit)
                TownStoreCloseBatchV636(r,ctx)
        }
        catch closeError
            SigLogV147("TOWN_STORE_CLOSE_WAIT reason=" . closeError.Message)
        ctx.storeOccupiedV641 := false
        if (r.HasKey("until"))
            r.until += A_TickCount-started
        sigBusyV147 := oldBusy,sigBackgroundV179 := oldBg,sigActiveModeV182 := oldMode
        pickupRoundResetV1 := true
        if (!parentLock)
            GameItemActionEndV4("Cube")
        if (!sigCancelV147)
            PickupEnabledSetV71(oldPickup,true,false)
    }
}


TownStoreInventorySlotV629(ctx,item,probeOnlyV636:=false)
{
    grid := {width:15,height:10,cells:{}},size := TicketItemSizeV277(ctx,item.cls)
    for uid,a in SigSnapshotV147(ctx)
        if (a.loc=0 && a.owner=ctx.inv && D2ReadU32(ctx.h,a.unit+0x10)=0)
        {
            f := TicketItemSizeV277(ctx,a.cls)
            if (a.x<0 || a.y<0 || a.x+f.w>grid.width || a.y+f.h>grid.height)
                throw Exception("Chuyển Kho: vị trí đồ trong túi ngoài lưới 15x10; chưa nhấc vật")
            Loop, % f.h
            {
                yy := a.y+A_Index-1
                Loop, % f.w
                    grid.cells[(a.x+A_Index-1) . "," . yy] := true
            }
        }
    if (grid.width<1 || grid.height<1 || grid.width>32 || grid.height>32)
        throw Exception("Chuyển Kho: chưa xác định được vùng túi trung gian")
    Loop, % grid.height
    {
        y := A_Index-1
        Loop, % grid.width
        {
            x := A_Index-1
            if (HopSlotFitsV559(grid,x,y,size.w,size.h))
                return {x:x,y:y}
        }
    }
    if (probeOnlyV636)
        return false
    throw Exception("Chuyển Kho: túi trung gian chưa đủ ô trống; chưa nhấc vật")
}


TownStoreOpenV629(ctx,closeCube:=false)
{
    global sigCubeUiOpenV159, cubeTransferDelayMs
    SigCheckV147(ctx)
    if (ctx.townStoreStashOpenV631 && !closeCube)
        return true
    if (closeCube)
    {
        TownStoreCloseBatchV636({},ctx)
    }
    path := D2ReadU32(ctx.h,ctx.player+0x2C)
    if (!MonsterBossProbeReadV1(ctx.h,path,0x20,pb))
        throw Exception("Chuyển Kho: chưa đọc được vị trí nhân vật")
    stash := CycObjectV42(ctx.h,pb,267),level := CoordLevelV14(ctx.h,NumGet(pb,0x1C,"UInt"))
    if (!IsObject(stash) || (stash.x-NumGet(pb,2,"UShort"))**2+(stash.y-NumGet(pb,6,"UShort"))**2>400)
        throw Exception("Chuyển Kho: chưa ở gần thủ khố")
    started := A_TickCount
    while (!SigTownInteractStashV342(ctx.pid,level,stash))
    {
        SigCheckV147(ctx)
        if (A_TickCount-started>4000)
            throw Exception("Chuyển Kho: chưa mở lại được thủ khố")
        Sleep, 100
    }
    TownStoreNativeWaitV631(ctx)
    Sleep, % Max(300, cubeTransferDelayMs*5)
    SigCheckV147(ctx)
    ctx.townStoreStashOpenV631 := true
    return true
}

TownStorePutV628(ctx,item)
{
    SigCheckV147(ctx)
    all := SigSnapshotV147(ctx),live := all[item.uid],cursor := PickupCursorV4(ctx.h,ctx.inv)
    if (!IsObject(live) || live.cls!=item.cls || live.q!=item.q || live.cls=1204
        || (live.loc!=0 && live.loc!=3) || !IsObject(cursor) || cursor.unit)
        throw Exception("Chuyển Kho: vật đã đổi hoặc chuột chưa trống; chưa nhấc vật")
    if (!IsObject(ctx.storeOccupiedV641))
        throw Exception("Chuyển Kho: chưa đọc ô trống khi kho mở; chưa nhấc vật")
    item := live,occupied := ctx.storeOccupiedV641.Clone(),size := TicketItemSizeV277(ctx,item.cls),slot := false
    Loop, 14
    {
        y := A_Index-1
        Loop, 14
        {
            x := A_Index-1,free := x+size.w<=14 && y+size.h<=14
            Loop, % size.h
            {
                yy := y+A_Index-1
                Loop, % size.w
                    if (occupied.HasKey((x+A_Index-1) . "," . yy))
                        free := false
            }
            if (free)
            {
                slot := {x:x,y:y}
                break 2
            }
        }
    }
    if (!IsObject(slot))
        throw Exception("Chuyển Kho: chưa có ô phù hợp trong dữ liệu kho; chưa nhấc vật")
    if (item.loc=3)
        SigLiftV147(ctx,item)
    else
    {
        bytes := [0x19],SigDwordV147(bytes,item.uid)
        SigPacketV147(ctx,bytes)
        if (!SigWaitLocV147(ctx,item.uid,4,2000))
            throw Exception("Chuyển Kho: chưa nhấc được vật bằng 0x19")
    }
    bytes := [0x18],SigDwordV147(bytes,item.uid),SigDwordV147(bytes,slot.x)
    SigDwordV147(bytes,slot.y),SigDwordV147(bytes,4)
    SigLogV147("TOWN_STORE_DIRECT_PLACE uid=" . item.uid . " class=" . item.cls . " source=" . item.loc
        . " xy=" . slot.x . "," . slot.y . " opcode=18 destination=4 ui=0")
    sigmaBase := D2GetModuleBaseV35(ctx.pid,"D2Sigma.dll"),sigmaReady := sigmaBase ? true : false
    expected := [0x8B,0x54,0x24,0x04,0xE8,0x27,0x90,0xFF,0xFF,0xC2,0x04,0]
    if (sigmaReady)
        for i,v in expected
            if (D2ReadU8V18(ctx.h,sigmaBase+0x488B0+i-1)!=v)
                sigmaReady := false
    for _,route in ["SIGMA","D2NET"]
    {
        if (TownStoreLiveStoredV635(ctx,item))
            return TownStoreCommitV641(ctx,item,slot,size)
        cursor := PickupCursorV4(ctx.h,ctx.inv)
        if (!IsObject(cursor) || cursor.uid!=item.uid)
            break
        if (route="SIGMA" && !sigmaReady)
        {
            SigLogV147("TOWN_STORE_TEST_SKIP route=SIGMA reason=DLL_SIGNATURE_MISMATCH")
            continue
        }
        SigLogV147("TOWN_STORE_TEST_SEND uid=" . item.uid . " route=" . route
            . " opcode=18 len=17 destination=4 xy=" . slot.x . "," . slot.y
            . " old_sig_0_0=" . (slot.x=0 && slot.y=0 ? 1 : 0) . " known_cells=" . occupied.Count())
        try
            SigPacketV147(ctx,bytes,route="SIGMA")
        catch sendError
        {
            SigLogV147("TOWN_STORE_TEST_SEND_ERROR route=" . route . " reason=" . sendError.Message)
            if (TownStoreLiveStoredV635(ctx,item))
                return TownStoreCommitV641(ctx,item,slot,size)
            break
        }
        started := A_TickCount
        Loop
        {
            SigCheckV147(ctx)
            if (TownStoreLiveStoredV635(ctx,item))
            {
                SigLogV147("TOWN_STORE_CONFIRMED uid=" . item.uid . " page=4 cursor=EMPTY route=" . route)
                return TownStoreCommitV641(ctx,item,slot,size)
            }
            if (A_TickCount-started>2500)
                break
            Sleep, 50
        }
        cursor := PickupCursorV4(ctx.h,ctx.inv),snapshot := SigSnapshotV147(ctx),now := snapshot[item.uid]
        if (!IsObject(now))
            now := SigLiveItemV148(ctx,item.uid,item.unit)
        SigLogV147("TOWN_STORE_TEST_STATE uid=" . item.uid . " route=" . route
            . " cursor_uid=" . (IsObject(cursor) ? cursor.uid : -1)
            . " item_found=" . (IsObject(now) ? 1 : 0)
            . " page45=" . (IsObject(now) ? now.loc : -1)
            . " page47=" . (IsObject(now) ? D2ReadU8V18(ctx.h,now.data+0x47) : -1)
            . " mode=" . (IsObject(now) ? D2ReadU32(ctx.h,now.unit+0x10) : -1)
            . " xy=" . (IsObject(now) ? now.x . "," . now.y : "UNKNOWN"))
    }
    cursor := PickupCursorV4(ctx.h,ctx.inv)
    if (IsObject(cursor) && cursor.uid=item.uid)
    {
        if (item.loc=3)
        {
            bytes := [0x2A],SigDwordV147(bytes,item.uid),SigDwordV147(bytes,ctx.cubeUid)
            SigPacketV147(ctx,bytes)
            if (!SigWaitLocV147(ctx,item.uid,3,3000,item.unit))
                throw Exception("Chuyển Kho: chưa trả được vật về Cube; kiểm tra vật trên chuột")
        }
        else
            Ticket130HomeV265(ctx,item,{x:item.x,y:item.y})
        throw Exception("Chuyển Kho: chưa xác nhận 0x18 đích 4; đã trả vật về nơi cũ")
    }
    throw Exception("Chuyển Kho: chưa xác định được vật sau lệnh, dừng và giữ nguyên để kiểm tra")
}


SigTownTickV148()
{
    global sigTownV148,manualLogOnV81,autoMonsterAttackOn,portalCastKeyV50,sigTownSendingV148
    global xRunning,zRunning,gameItemActionOwner,farmStopMoveV124,sigFarmResumePendingV237,farmCubeSortOnceV253
    global farmControlOwnerV186
    static busy := false
    if (busy || !IsObject(sigTownV148))
        return
    busy := true,r := sigTownV148,h := 0
    try
    {
        if (r.retryAtV237 && A_TickCount<r.retryAtV237)
            return
        if ((!r.auto && !manualLogOnV81) || autoMonsterAttackOn)
        {
            SigTownCancelV148("LOG_STOP_OR_FARM_RESTARTED")
            return
        }
        if (A_TickCount-r.at>120000)
            throw Exception("Hết thời gian test, đứng lại và kiểm tra log")
        if (!IsGameActive())
        {
            if (r.step!="WAIT_GAME")
                throw Exception("Rời cửa sổ game: đã dừng test")
            if (A_TickCount-r.stepAt>30000)
                throw Exception("Chưa chuyển vào game trong 30 giây")
            return
        }
        activePid := D2GetActiveGamePidV95()
        if (!r.pid && r.step="WAIT_GAME")
            r.pid := activePid
        if (!activePid || activePid!=r.pid)
            throw Exception("Cửa sổ game khác nhân vật đã chọn")
        if (r.step="WAIT_GAME" && !r.auto)
        {
            if (!IsGameForegroundV63() || !BackgroundBindV63(WinExist("A")))
                throw Exception("Không gắn được cửa sổ game cho test Sig")
            SigLogV147("TOWN_TEST_BOUND pid=" . r.pid . " source=FOREGROUND")
        }
        if (xRunning || zRunning || gameItemActionOwner!="" || !AutoMonsterPacketCleanupV1())
            return
        base := D2GetModuleBaseV35(r.pid,"D2Client.dll"),h := D2OpenProcess(r.pid)
        player := h ? D2ReadU32(h,base+0x11BBFC) : 0,path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt")),mode := D2ReadU32(h,player+0x10)
        px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
        if (r.step="WAIT_GAME" && !r.source)
        {
            if (!level)
                return
            if (portalCastKeyV50="")
                throw Exception("Chưa cài phím mở cổng")
            r.source := level,r.town := 0
            SigLogV147("TOWN_TEST_GAME_READY pid=" . r.pid . " source=" . level . " town=" . r.town . " key=" . portalCastKeyV50)
        }
        SigLogV147("TOWN_TEST_STATE step=" . r.step . " level=" . level . " xy=" . px . "," . py . " mode=" . mode)
        libTownArrivalV283 := r.libReturnV283
            && (level=1 || level=40 || level=75 || level=103 || level=109)
            && (r.step="WAIT_GAME" || r.step="WAIT_IDLE" || r.step="FIND_PORTAL" || r.step="ENTER" || r.step="WAIT_TOWN")
        if (level && level!=r.source && (r.step="ENTER" || r.step="WAIT_TOWN" || libTownArrivalV283))
        {
            r.town := level
            SigLogV147("TOWN_TEST_PORTAL_ARRIVED level=" . level . " expected_town_check=OFF")
            r.townX := px,r.townY := py
            r.portal := FarmPortalTargetV67(h,pb,px,py)
            r.px := IsObject(r.portal) ? r.portal.x : px
            r.py := IsObject(r.portal) ? r.portal.y : py
            SigTownStepV148(r,"TOWN_IDLE")
        }
        if (r.step="WAIT_GAME")
        {
            if (level!=r.source)
                throw Exception("Nhân vật không còn ở map xuất phát")
            farmStopMoveV124 := false
            SetTimer, FarmStopMoveTimerV124, Off
            SigTownMoveV148(r,px,py,level,true)
            SigTownStepV148(r,"WAIT_IDLE")
            return
        }
        if (r.step="WAIT_IDLE")
        {
            if (A_TickCount-r.stepAt>10000)
                throw Exception("Nhân vật chưa dừng di chuyển")
            if ((mode!=1 && mode!=5) || A_TickCount-r.stepAt<400)
                return
            r.before := FarmNearbyPortalsV61(h,pb)
            sigTownSendingV148 := true
            try
                sent := BuffCheckedSendV29(portalCastKeyV50)
            finally
                sigTownSendingV148 := false
            SigLogV147("TOWN_TEST_OPEN key=" . portalCastKeyV50 . " sent=" . sent)
            if (!sent)
                throw Exception("Không gửi được phím mở cổng")
            SigTownStepV148(r,"FIND_PORTAL")
            return
        }
        if (r.step="FIND_PORTAL")
        {
            target := SigTownNewPortalV148(h,pb,r)
            if (!IsObject(target))
            {
                if (A_TickCount-r.stepAt>8000)
                    throw Exception("Không tìm thấy cổng mới vừa mở")
                return
            }
            r.target := target,r.tries := 0
            SigLogV147("TOWN_TEST_PORTAL uid=" . target.uid . " xy=" . target.x . "," . target.y)
            SigTownStepV148(r,"ENTER")
        }
        if (r.step="ENTER")
        {
            if (level!=r.source)
                return
            if (r.libReturnV283)
            {
                livePortalV286 := SigTownNewPortalV148(h,pb,r)
                if (!IsObject(livePortalV286))
                {
                    r.target := false
                    SigTownStepV148(r,"FIND_PORTAL")
                    return
                }
                if (!IsObject(r.target) || r.target.uid!=livePortalV286.uid
                    || r.target.x!=livePortalV286.x || r.target.y!=livePortalV286.y)
                {
                    SigLogV147("LIB_TOWN_PORTAL_REFRESH old_uid=" . r.target.uid . " new_uid=" . livePortalV286.uid)
                    r.tries := 0,r.last := 0,r.stepAt := A_TickCount
                }
                r.target := livePortalV286
            }
            if (A_TickCount-r.stepAt>15000)
                throw Exception("Không về được thành qua cổng")
            if (mode!=1 && mode!=5)
                return
            if (r.last && A_TickCount-r.last<1500)
                return
            if (r.tries>=3)
                throw Exception("Đã thử vào cổng 3 lần, chưa đổi map")
            if (r.libReturnV283
                && (px-r.target.x)**2+(py-r.target.y)**2>16)
            {
                approachLengthV286 := Sqrt((px-r.target.x)**2+(py-r.target.y)**2)
                approachXV286 := Round(r.target.x+(px-r.target.x)*3/approachLengthV286)
                approachYV286 := Round(r.target.y+(py-r.target.y)*3/approachLengthV286)
                movedV280 := SigTownMoveV148(r,approachXV286,approachYV286,level)
                r.last := A_TickCount
                SigLogV147("LIB_TOWN_PORTAL_APPROACH uid=" . r.target.uid . " xy=" . r.target.x . "," . r.target.y . " queued=" . movedV280)
                return
            }
            sent := SigTownPortalInteractV148(r.pid,r.source,r.target)
            SigLogV147("TOWN_TEST_ENTER uid=" . r.target.uid . " queued=" . sent . " attempt=" . (r.tries+1))
            if (sent)
                r.tries++
            r.last := A_TickCount
            return
        }
                if (r.step="TOWN_IDLE")
        {
            if ((mode!=1 && mode!=5) || A_TickCount-r.stepAt<400)
                return
            if (r.finishFarmStage2)
            {
                sigTownV148 := false
                SetTimer, SigTownTimerV148, Off
                MapStage2CompleteV185(true)
                PickupEnabledSetV71(r.pickupBeforeV575,true,false)
                return
            }
            r.tries := 0,r.at := A_TickCount
            SigTownStepV148(r,"RETURN_PORTAL")
            return
        }
	}	
    finally
    {
        if (h)
            DllCall("CloseHandle","Ptr",h)
        busy := false,sigTownSendingV148 := false
    }
}

SigTownPortalInteractV148(pid,level,target,mapEntry:=false)
{
    global autoMonsterPacketPendingV1, townLevelV22, outsideLevelV22,scosEntryV162
    ubuEntryV62 := mapEntry && IsObject(scosEntryV162) && scosEntryV162.map="UBU"
    targetTypeV62 := ubuEntryV62 && IsObject(target) && target.typ=5 ? 5 : 2
    cycEntryV43 := mapEntry && IsObject(scosEntryV162) && scosEntryV162.map="CYC"
    tranWpOKV358 := mapEntry && IsObject(scosEntryV162) && scosEntryV162.map="TRAN"
        && IsObject(target) && (target.cls=156 || target.cls=285 || target.cls=286
            || target.cls=237 || target.cls=429)
    cainWpOKV360 := mapEntry && IsObject(scosEntryV162) && scosEntryV162.map="CAIN"
        && scosEntryV162.phase="OPEN_WAIT40" && level=40 && target.cls=156
    waypointV226 := mapEntry && IsObject(scosEntryV162) && IsObject(target)
        && ((scosEntryV162.phase="WP" && ((level=109 && target.cls=429) || (level=75 && target.cls=237)))
            || tranWpOKV358 || cainWpOKV360)
    stashV229 := mapEntry && IsObject(scosEntryV162) && (scosEntryV162.map="" || scosEntryV162.map="SCOS" || scosEntryV162.map="NAO" || MapScrollFarmV269(scosEntryV162.map))
        && scosEntryV162.phase="WP" && !scosEntryV162.goldDoneV229 && (level=109 || (MapScrollFarmV269(scosEntryV162.map) && level=103))
        && IsObject(target) && target.cls=267
    entryStateV43 := mapEntry ? scosEntryV162 : false
    if (mapEntry && IsObject(scosEntryV162) && scosEntryV162.phase="WP" && !waypointV226 && !stashV229)
        return false
    if (cycEntryV43 && !waypointV226 && (!IsObject(target)
        || !((level=137 && target.cls=194) || (level=164 && target.cls=60))))
        return false
    if (!MapPortalReadyV188(pid,level,mapEntry))
        return false
    if (!IsObject(target) || !MapPortalReadyV188(pid,level,mapEntry) || !AutoMonsterPacketCleanupV1())
        return false
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? DllCall("OpenProcess","UInt",0x043A,"Int",0,"UInt",pid,"Ptr") : 0
    if (!h)
        return false
    remote := 0, owned := false
    try
    {
        if (!NativeRightClickBuildV9(h,base)
            || !MonsterBossProbeReadV1(h,base+0x2AC10,12,entry)
            || MonsterBossProbeHexV1(entry,12)!="83EC2C53550FB7E98BDA5657")
        {
            PortalLogWriteV66("PORTAL_DLL_BLOCK reason=BUILD_OR_INTERACT_SIGNATURE_MISMATCH","dll_build",2000)
            return false
        }
        player := D2ReadU32(h,base+0x11BBFC), mode := player ? D2ReadU32(h,player+0x10) : 0
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if ((mode!=1 && mode!=5) || !MonsterBossProbeReadV1(h,path,0x20,pb)
            || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=level
            || (NumGet(pb,2,"UShort")-target.x)**2+(NumGet(pb,6,"UShort")-target.y)**2>400)
            return false
        inv := D2ReadU32(h,player+0x60), cursor := inv ? PickupCursorV4(h,inv) : false
        if (!IsObject(cursor) || cursor.unit)
            return false
        wpSearchRadiusV226 := (IsObject(scosEntryV162) && (scosEntryV162.map="TRAN" || scosEntryV162.map="CAIN")) ? 3 : 1
        live := (waypointV226 || stashV229) ? CycObjectV42(h,pb,target.cls,target.x,target.y,wpSearchRadiusV226)
            : ubuEntryV62 ? UbuExitV62(h,pb,target.x,target.y,1,target.cls)
            : cycEntryV43 ? CycObjectV42(h,pb,target.cls,target.x,target.y,1)
            : FarmPortalTargetV67(h,pb,target.x,target.y)
        if (!IsObject(live) || live.uid!=target.uid || live.unit!=target.unit
            || live.x!=target.x || live.y!=target.y)
            return false
        remote := DllCall("VirtualAllocEx","Ptr",h,"Ptr",0,"UPtr",128,"UInt",0x3000,"UInt",0x40,"Ptr")
        if (!remote || remote>0xFFFFFFFF)
            return false
        hex := FarmPortalCodeTownOnlyV68(base,target.uid,level,targetTypeV62)
        length := StrLen(hex)//2
        VarSetCapacity(blob,128,0)
        Loop, %length%
            NumPut("0x" . SubStr(hex,(A_Index-1)*2+1,2),blob,A_Index-1,"UChar")
        if (!DllCall("WriteProcessMemory","Ptr",h,"Ptr",remote,"Ptr",&blob,"UPtr",128,"UPtrP",written) || written!=128)
            return false
        DllCall("FlushInstructionCache","Ptr",h,"Ptr",remote,"UPtr",length)
        currentPlayer := D2ReadU32(h,base+0x11BBFC)
        currentPath := currentPlayer ? D2ReadU32(h,currentPlayer+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,currentPath,0x20,currentPb)
            || CoordLevelV14(h,NumGet(currentPb,0x1C,"UInt"))!=level
            || !MapPortalReadyV188(pid,level,mapEntry)
            || (mapEntry && scosEntryV162!=entryStateV43)
            || D2ReadU32(h,target.unit)!=targetTypeV62 || D2ReadU32(h,target.unit+0x0C)!=target.uid
            || D2ReadU32(h,target.unit+4)!=target.cls)
            return false
        recordEntryV725 := mapEntry && (target.cls=59 || target.cls=60)
        if (recordEntryV725 && !FarmPortalRecordV725(pid,h,player,"ENTRY",target))
            return false
        thread := DllCall("CreateRemoteThread","Ptr",h,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
        if (!thread)
            return false
        autoMonsterPacketPendingV1 := {process:h,remote:remote,thread:thread,uid:target.uid,kind:"PORTAL_DLL",portalCall:true}
        owned := true
        if (recordEntryV725)
        {
            portalSessionV725 := FarmPortalSessionV725(pid)
            if (IsObject(portalSessionV725.pendingEntry))
                portalSessionV725.pendingEntry.sentAt := A_TickCount
        }
        SetTimer, AutoMonsterPacketCleanupTimerV1, 50
        PortalLogWriteV66("PORTAL_INTERACT_SENT uid=" . target.uid . " class=" . target.cls
            . " xy=" . target.x . "," . target.y . " player=" . NumGet(currentPb,2,"UShort") . "," . NumGet(currentPb,6,"UShort")
            . " level=" . level . " mapEntry=" . mapEntry . " waypoint=" . (waypointV226 ? 1 : 0)
            . " method=SigTownPortalInteractV148")
        return true
    }
    finally
    {
        if (!owned)
        {
            if (remote)
                DllCall("VirtualFreeEx","Ptr",h,"Ptr",remote,"UPtr",0,"UInt",0x8000)
            DllCall("CloseHandle","Ptr",h)
        }
    }
}

ContinuousMapEnabledV168()
{
    global continuousMapV168
    return continuousMapV168
}

MapControlButtonV168:
stopOwnerV1 := farmVizButtonDispatchV687 ? "VIZ" : farmBOButtonDispatchV413 ? "BO" : farmExtraTRANButtonDispatchV358 ? "TRAN" : farmExtra3000ButtonDispatchV297 ? "M3000" : farm130ButtonDispatchV257 ? "LIB" : farmUbuButtonDispatchV62 ? "UBU" : farmCycButtonDispatchV42 ? "CYC" : farmNaoButtonDispatchV186 ? "NAO" : farmExtraCAINButtonDispatchV297 ? "CAIN" : "SCOS"
if ((FarmControlRunningV186() || farmUserPausedV2026) && farmControlOwnerV186=stopOwnerV1)
{
    FarmUserPauseToggleV2026(stopOwnerV1)
    return
}
if (farmUserPausedV2026 && farmControlOwnerV186!=stopOwnerV1)
    FarmButtonStopV1()
if ((FarmControlRunningV186() || IsObject(farmMapPauseV52) || cainPausedV10)
    && (farmControlOwnerV186=stopOwnerV1 || farmControlOwnerV186=""))
{
    FarmUserPauseToggleV2026(stopOwnerV1)
    return
}
requestedFarmOwnerV186 := farmVizButtonDispatchV687 ? "VIZ" : farmBOButtonDispatchV413 ? "BO" : farmExtraTRANButtonDispatchV358 ? "TRAN" : farmExtra3000ButtonDispatchV297 ? "M3000" : farm130ButtonDispatchV257 ? "LIB" : farmUbuButtonDispatchV62 ? "UBU" : farmCycButtonDispatchV42 ? "CYC" : farmNaoButtonDispatchV186 ? "NAO" : farmExtraCAINButtonDispatchV297 ? "CAIN" : "SCOS"
roomMapLastButtonV22 := requestedFarmOwnerV186="LIB" ? libScrollTierV290
    : requestedFarmOwnerV186="M3000" ? "3000" : requestedFarmOwnerV186="NAO" ? "FAUT" : requestedFarmOwnerV186
FonInfoPushV385("[NÚT " . requestedFarmOwnerV186 . "] " . (FarmControlRunningV186() ? "STOP" : "START") . " farm=" . (autoMonsterAttackOn ? "ON" : "OFF"))
if (FarmControlRunningV186() && farmControlOwnerV186!="" && farmControlOwnerV186!=requestedFarmOwnerV186)
{
    FarmStopV124("USER_SWITCH_MAP_BUTTON")
    mapButtonStartV172 := false,mapFarmStartPendingV170 := false
    SetTimer, MapButtonStartTimerV172, Off
    SetTimer, MapFarmStartV170, Off
    FarmPauseReleaseV256("USER_SWITCH_MAP_BUTTON")
}
farmControlOwnerV186 := requestedFarmOwnerV186
farmManualStoppedV2026 := false ; explicit START from Farm button
if (FarmStartForcedV702(requestedFarmOwnerV186))
    return
if (!FarmControlRunningV186())
    farmControlOwnerV186 := requestedFarmOwnerV186
MapKeyTraceV174("RUN_BUTTON","CLICK L_sent=0")
if (IsObject(mapButtonStartV172))
{
    mapButtonStartV172 := false
    SetTimer, MapButtonStartTimerV172, Off
    return
}
if (FarmControlRunningV186())
{
    Gosub, MapControlActionV168
    return
}
if (!SigBackgroundBindV179())
{
    MapKeyTraceV174("RUN_BUTTON","BIND_FAILED L_sent=0 next=STAGE4_RECOVERY")
    RecoveryStartMissingGameV492(requestedFarmOwnerV186)
    if (!FarmControlRunningV186())
        FarmStartKeepV697("GAME_BIND_NOT_READY")
    return
}
mapControlPidV168 := backgroundPidV63,mapControlHwndV168 := backgroundHwndV63
mapButtonStartV172 := {hwnd:mapControlHwndV168,pid:mapControlPidV168,at:A_TickCount,phase:"RELEASE"}
MapKeyTraceV174("RUN_BUTTON","WAIT_MOUSE_RELEASE L_sent=0")
SetTimer, MapButtonStartTimerV172, 50
return


MapFarmStartV170:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    SetTimer, MapFarmStartV170, Off
    return
}
if (!mapFarmStartPendingV170)
    return
if (!BackgroundValidV63() || IsObject(scosEntryV162) || IsObject(stageTwoV166))
{
    PortalLogWriteV66("STAGE2_START_WAIT run=ON reason=GAME_OR_STAGE_NOT_READY","STAGE2_START_WAIT",2000)
    SetTimer, MapFarmStartV170, -2000
    return
}
mapFarmStartPendingV170 := false
Gosub, MapStage2StartV185
return

FarmEntryActivateV565(pid,hwnd,state)
{
    global stageTwoV166,mapStage1BuffDoneV248,backgroundPidV63,backgroundHwndV63
    if (!IsObject(state) || (state!=stageTwoV166 && state!=mapStage1BuffDoneV248)
        || !BackgroundValidV63() || backgroundPidV63!=pid || backgroundHwndV63!=hwnd
        || !DllCall("IsWindowEnabled","Ptr",hwnd) || DllCall("IsHungAppWindow","Ptr",hwnd))
        return false
    if (state.entryFocusDoneV565)
        return true
    if (state.entryFocusAtV565 && A_TickCount-state.entryFocusAtV565<1000)
        return false
    state.entryFocusAtV565 := A_TickCount
    appQueuedV665 := DllCall("PostMessage","Ptr",hwnd,"UInt",0x1C,"UPtr",1,"Ptr",0)
    windowQueuedV665 := DllCall("PostMessage","Ptr",hwnd,"UInt",0x6,"UPtr",1,"Ptr",0)
    if (appQueuedV665 && windowQueuedV665
        && (state=stageTwoV166 || state=mapStage1BuffDoneV248) && BackgroundValidV63())
        state.entryFocusDoneV565 := true
    PortalLogWriteV66("FARM_ENTRY_BACKGROUND_READY pid=" . pid . " hwnd=" . V92Hex(hwnd)
        . " app_queued=" . appQueuedV665 . " window_queued=" . windowQueuedV665
        . " foreground_forced=0 effect=UNCONFIRMED once_per_entry=1")
    return state.entryFocusDoneV565
}

MapStage2ArrivalBuffV313()
{
    global mapStage1BuffDoneV248,backgroundPidV63,backgroundHwndV63
    r := mapStage1BuffDoneV248
    if (!IsObject(r) || r.buffDone)
        return true
    base := D2GetModuleBaseV35(backgroundPidV63,"D2Client.dll"),h := base ? D2OpenProcess(backgroundPidV63) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (r.pid!=backgroundPidV63 || !MonsterBossProbeReadV1(h,path,0x20,pb)
            || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=r.level)
            return false
        if (!FarmEntryActivateV565(r.pid,backgroundHwndV63,r))
            return false
        if (!RouteBuffSequenceV20(h,player,r.pid,true))
            return false
        r.buffDone := true
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

MapStage2StartReadyV535()
{
    global farmRunEpochV535,mapWorkflowV185,mapFarmStartPendingV170
    epoch := farmRunEpochV535
    MapStageSetV185(2)
    ready := BackgroundValidV63() && MapStage2ArrivalBuffV313()
    if (epoch!=farmRunEpochV535 || !IsObject(mapWorkflowV185))
        return false
    if (!ready)
    {
        mapFarmStartPendingV170 := true
        SetTimer, MapFarmStartV170, -500
    }
    return ready
}

MapStage2StartV185:
if (!MapStage2StartReadyV535())
    return
autoMonsterAttackOn := true
scosStartFarmV162 := true
MapStageSetV185(2)
PortalLogWriteV66("MAP_STAGE2_START action=FARM entry_buff=COMPLETED_ON_MAP_ENTRY")
try
    Gosub, AutoMonsterAttackToggle
finally
{
    scosStartFarmV162 := false
    mapStage1BuffDoneV248 := false
}
return

FarmResetWatchTimerV217:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
    return
if (!FarmControlRunningV186() && !autoMonsterAttackOn)
    return
try
    FarmWatchDueV5()
return

MapControlButtonStatusV171:
BackgroundInputWatchV553()
InfoStuckWatchV552()
if (GetKeyState("LButton","P") || GetKeyState("RButton","P"))
    return
mapControlRunningV171 := FarmControlRunningV186() || IsObject(farmMapPauseV52) || cainPausedV10 || farmUserPausedV2026
for _,buttonV1 in [{control:"MapControlRunButtonV171",name:"SCOS",owner:"SCOS"}
    ,{control:"FarmNaoRunButtonV184",name:"FAUT",owner:"NAO"}
    ,{control:"FarmCycRunButtonV42",name:"CYC",owner:"CYC"}
    ,{control:"FarmUbuRunButtonV62",name:"UBU",owner:"UBU"}
    ,{control:"FarmExtra3000ButtonV297",name:"3000",owner:"M3000"}
    ,{control:"FarmExtraTRANButtonV297",name:"TRAN",owner:"TRAN"}
    ,{control:"FarmExtraCAINButtonV297",name:"CAIN",owner:"CAIN"}
    ,{control:"FarmBOButtonV413",name:"BO",owner:"BO"}
    ,{control:"FarmExtraVIZButtonV297",name:"VIZ",owner:"VIZ"}]
{
    activeV1 := mapControlRunningV171 && farmControlOwnerV186=buttonV1.owner
    captionV1 := buttonV1.name . "`n" . (activeV1 ? (farmUserPausedV2026 ? "Tiếp" : "Pause") : "Start")
    GuiControlGet, currentV1, 1:, % buttonV1.control
    if (currentV1!=captionV1)
        GuiControl, 1:, % buttonV1.control, %captionV1%
}
for _,tierV1 in [130,133,136,139]
{
    controlV1 := tierV1=130 ? "Farm130RunButtonV257" : "Farm" . tierV1 . "RunButtonV290"
    activeV1 := mapControlRunningV171 && farmControlOwnerV186="LIB" && libScrollTierV290=tierV1
    captionV1 := tierV1 . "`n" . (activeV1 ? (farmUserPausedV2026 ? "Tiếp" : "Pause") : "Start")
    GuiControlGet, currentV1, 1:, %controlV1%
    if (currentV1!=captionV1)
        GuiControl, 1:, %controlV1%, %captionV1%
}
return


MapButtonStartTimerV172:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    SetTimer, MapButtonStartTimerV172, Off
    return
}
if (!IsObject(mapButtonStartV172))
{
    SetTimer, MapButtonStartTimerV172, Off
    return
}
if (mapButtonStartV172.phase="WAIT_HEALTH")
{
    healthMapV536 := farmControlOwnerV186!="" ? farmControlOwnerV186 : "SCOS"
    if (FarmStartHealthV536(healthMapV536))
        return
    mapButtonStartV172.phase := "RELEASE"
}
if (!BackgroundValidV63() || backgroundHwndV63!=mapButtonStartV172.hwnd
    || backgroundPidV63!=mapButtonStartV172.pid
    || autoMonsterAttackOn || IsObject(scosEntryV162) || IsObject(stageTwoV166))
{
    MapKeyTraceV174("RUN_BUTTON","START_ABORT reason=BOUND_GAME_OR_BUSY")
    mapButtonStartV172 := false
    SetTimer, MapButtonStartTimerV172, Off
    if (!FarmControlRunningV186())
        FarmStartKeepV697("GAME_CHANGED_BEFORE_START")
    return
}
if (GetKeyState("LButton","P"))
    return
if (sigBusyV147 || IsObject(sigTownV148) || gameItemActionOwner!="" || xRunning || zRunning
    || autoMonsterAttackBusy || pickupTimerBusy)
{
    if (mapButtonStartV172.phase!="WAIT_ACTION")
    {
        mapButtonStartV172.phase := "WAIT_ACTION"
        FonInfoPushV385("[START] Đã nhận; chạy ngay sau thao tác buff/vật phẩm đang kết thúc.")
    }
    return
}
mapButtonStartV172 := false
SetTimer, MapButtonStartTimerV172, Off
mapControlGuiStartV180 := true
try
{
    MapKeyTraceV174("RUN_BUTTON","CALL_FARM_ACTION route=BOUND_GAME_DIRECT L_sent=0")
    Gosub, MapControlActionV168
    MapKeyTraceV174("RUN_BUTTON","FARM_ACTION_RETURN farm=" . autoMonsterAttackOn
        . " entry=" . IsObject(scosEntryV162) . " stage2=" . IsObject(stageTwoV166))
}
finally
    mapControlGuiStartV180 := false
return


MapKeyTraceV174(key,result)
{
    if (!ManualLogActiveV81())
        return
    global autoMonsterAttackOn,backgroundHwndV63,backgroundPidV63,scosEntryV162,stageTwoV166
    global sigBusyV147,sigSendingKeyV147,sigTownV148,sigTownSendingV148
    global gameItemActionOwner,xRunning,zRunning,reviveBuffPendingV34,farmKeyHeldV124
    global packetWatchArmedV1,autoOn
    hwnd := GameTargetHwndV63()
    foregroundHwndV175 := DllCall("GetForegroundWindow","Ptr")
    WinGet, foregroundPidV175, PID, ahk_id %foregroundHwndV175%
    PortalLogWriteV66("MAP_KEY key=" . key . " result=" . result
        . " active_hwnd=" . foregroundHwndV175 . " active_pid=" . foregroundPidV175
        . " active_is_bound=" . (foregroundHwndV175=backgroundHwndV63 && backgroundHwndV63!=0)
        . " physical_L=" . GetKeyState("L","P")
        . " target=" . hwnd . " bound=" . backgroundHwndV63 . " pid=" . backgroundPidV63
        . " foreground=" . IsGameForegroundV63() . " valid=" . BackgroundValidV63()
        . " farm=" . autoMonsterAttackOn . " entry=" . IsObject(scosEntryV162)
        . " stage2=" . IsObject(stageTwoV166) . " sig_busy=" . sigBusyV147
        . " sig_send=" . sigSendingKeyV147 . " sig_town=" . IsObject(sigTownV148)
        . " town_send=" . sigTownSendingV148 . " owner=" . gameItemActionOwner
        . " x=" . xRunning . " z=" . zRunning . " buff_pending=" . reviveBuffPendingV34
        . " farm_key_held=" . farmKeyHeldV124 . " packet_watch=" . packetWatchArmedV1
        . " auto_on=" . autoOn . MapWindowInputStateV176())
}

MapWindowInputStateV176()
{
    global backgroundHwndV63
    hwnd := backgroundHwndV63
    if (!hwnd)
    {
        pid := CoordDisplayGamePidV1()
        hwnd := pid ? WinExist("ahk_pid " . pid) : 0
    }
    tid := hwnd ? DllCall("GetWindowThreadProcessId","Ptr",hwnd,"Ptr",0,"UInt") : 0
    size := 8+6*A_PtrSize+16
    VarSetCapacity(info,size,0),NumPut(size,info,0,"UInt")
    ok := tid ? DllCall("GetGUIThreadInfo","UInt",tid,"Ptr",&info) : 0
    result := " game_hwnd=" . hwnd . " game_thread=" . tid . " gui_info_ok=" . ok
    if (ok)
        result .= " gui_flags=" . NumGet(info,4,"UInt")
            . " input_active=" . NumGet(info,8,"Ptr")
            . " input_focus=" . NumGet(info,8+A_PtrSize,"Ptr")
            . " input_capture=" . NumGet(info,8+2*A_PtrSize,"Ptr")
            . " menu_owner=" . NumGet(info,8+3*A_PtrSize,"Ptr")
    if (hwnd)
    {
        WinGet, minmax, MinMax, ahk_id %hwnd%
        result .= " game_enabled=" . DllCall("IsWindowEnabled","Ptr",hwnd)
            . " game_visible=" . DllCall("IsWindowVisible","Ptr",hwnd) . " game_minmax=" . minmax
    }
    return result
}

MapInputWatchV176:
if (!ManualLogActiveV81())
{
    SetTimer, MapInputWatchV176, Off
    return
}
mapInputStateV176 := DllCall("GetForegroundWindow","Ptr") . "|" . GetKeyState("L","P")
    . "|" . backgroundHwndV63 . "|" . backgroundPidV63 . "|" . autoMonsterAttackOn
    . "|" . farmKeyHeldV124 . "|" . sigBusyV147 . "|" . sigSendingKeyV147
    . "|" . IsObject(sigTownV148) . "|" . sigTownSendingV148 . "|" . gameItemActionOwner
    . "|" . xRunning . "|" . zRunning . "|" . reviveBuffPendingV34
    . "|" . packetWatchArmedV1 . "|" . autoOn . MapWindowInputStateV176()
if (mapInputStateV176!=mapInputLastV176)
{
    mapInputLastV176 := mapInputStateV176
    MapKeyTraceV174("INPUT_WATCH","STATE_CHANGED")
}
return

NormalizeMapHotkeyV178(key)
{
    key := NormalizeOptionalKey(key)
    return RegExReplace(key,"i)^Ctrl\s*\+\s*","^")
}

MouseKeyDisplayV616(key)
{
    return RegExReplace(key,"i)MButton","M3")
}

MapHotkeyDisplayV178(key)
{
    return key="" ? "None" : MouseKeyDisplayV616(key)
}

MapHotkeysMatchV178(first,second)
{
    first := NormalizeMapHotkeyV178(first),second := NormalizeMapHotkeyV178(second)
    if ((SubStr(first,1,1)="^")!=(SubStr(second,1,1)="^"))
        return false
    return CastKeysMatch(RegExReplace(first,"^\^"),RegExReplace(second,"^\^"))
}

SigBackgroundBindV179(pid := 0)
{
    if (!pid)
        pid := CoordDisplayGamePidV1()
    if (!pid)
        return false
    best := 0,bestScore := -1
    WinGet, windows, List, ahk_pid %pid%
    Loop, %windows%
    {
        hwnd := windows%A_Index%
        WinGetClass, cls, ahk_id %hwnd%
        WinGetTitle, title, ahk_id %hwnd%
        VarSetCapacity(rect,16,0)
        if (!DllCall("IsWindowVisible","Ptr",hwnd) || cls="#32770"
            || !DllCall("GetClientRect","Ptr",hwnd,"Ptr",&rect))
            continue
        w := NumGet(rect,8,"Int"),h := NumGet(rect,12,"Int")
        gameClass := cls="Diablo II"
        if ((!gameClass && !InStr(title,"Diablo II")) || w<640 || h<480)
            continue
        score := (gameClass ? 1000 : 0)+(InStr(title,"Diablo II") ? 100 : 0)
            + (DllCall("GetWindow","Ptr",hwnd,"UInt",4,"Ptr") ? 0 : 10)
        if (ManualLogActiveV81())
            PortalLogWriteV66("SIG_WINDOW_CANDIDATE hwnd=" . hwnd . " class=" . cls
                . " title=" . title . " client=" . w . "x" . h . " score=" . score)
        if (score>bestScore)
            best := hwnd,bestScore := score
    }
    if (!best || !BackgroundBindV63(best))
        return false
    if (ManualLogActiveV81())
        PortalLogWriteV66("SIG_BUTTON_BACKGROUND hwnd=" . best . " pid=" . pid . " activate=0")
    return true
}


UtilityKeyValidV181(key,ownControl)
{
    if (key="")
        return true
    plain := RegExReplace(key,"^\^")
    if (!GetKeyVK(plain) && !GetKeySC(plain))
    {
        ToolTipInfoV386("Phím không hợp lệ.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    for _,control in ["ItemInspectKeyInputV287","SigKeyInputV147","SigSuKeyInputV181","PickupToggleKeyInputV79","ZRunKey","XKey","DoubleKey","FormDoubleKey","QCastDoubleKey","PetLearnKeyInputV13","InvToCubeKey","Belt4HPKey","Belt2HP2ManaKey","ClickCastKeyInput","Master456KeyInput"]
    {
        if (control=ownControl)
            continue
        GuiControlGet, other,, %control%
        if (MapHotkeysMatchV178(key,other))
        {
            ToolTipInfoV386("Phím bị trùng chức năng khác. Chọn phím riêng.")
            SetTimer, RemoveToolTip, -3000
            return false
        }
    }
    return true
}

FarmNaoKeyChangedV181:
FarmNaoKeySaveV181()
return

FarmNaoKeySaveV181()
{
    global farmNaoKeyV181,ConfigFile,currentProfile
    key := farmNaoKeyV181
    key := NormalizeMapHotkeyV178(key)
    if (!UtilityKeyValidV181(key,"FarmNaoKeyInputV181"))
        return false
    farmNaoKeyV181 := key
    section := ProfileSection(currentProfile)
    IniWrite, %farmNaoKeyV181%, % ProfileConfigPathV364(section), %section%, FarmNaoKey
    FarmNaoBindV184()
    return true
}

SigTierChangedV13:
GuiControlGet, sigTUV586, 1:, SigTUInputV586
GuiControlGet, sigSUV510, 1:, SigSUInputV510
GuiControlGet, sigSSUV13,, SigSSUInputV13
sigTierSectionV13 := ProfileSection(currentProfile)
IniWrite, %sigTUV586%, % ProfileConfigPathV364(sigTierSectionV13), %sigTierSectionV13%, SigTU
IniWrite, %sigSUV510%, % ProfileConfigPathV364(sigTierSectionV13), %sigTierSectionV13%, SigSU
IniWrite, %sigSSUV13%, % ProfileConfigPathV364(sigTierSectionV13), %sigTierSectionV13%, SigSSU
IniWrite, %sigSSSUV13%, % ProfileConfigPathV364(sigTierSectionV13), %sigTierSectionV13%, SigSSSU
return

PickupActivateGameV13()
{
    return SigBackgroundBindV179() && BackgroundValidV63()
}

SigSuKeyChangedV181:
if (!sigBusyV147)
    SigSuKeySaveV181()
return

SigSuKeySaveV181()
{
    global sigSuKeyV181,ConfigFile,currentProfile
    GuiControlGet, key,, SigSuKeyInputV181
    key := NormalizeMapHotkeyV178(key)
    if (!UtilityKeyValidV181(key,"SigSuKeyInputV181"))
        return false
    sigSuKeyV181 := key
    section := ProfileSection(currentProfile)
    IniWrite, %sigSuKeyV181%, % ProfileConfigPathV364(section), %section%, SigSuKey
    SigSuBindV181()
    return true
}

SigSuBindV181()
{
    global sigSuKeyV181
    static previous := ""
    if (previous!="")
        BackgroundHotkeyV63("$" . previous,"SigSuHotkeyV181","Off UseErrorLevel")
    previous := sigSuKeyV181
    if (previous!="")
        BackgroundHotkeyV63("$" . previous,"SigSuHotkeyV181","On UseErrorLevel")
}

SigSuHotkeyV181:
if (!IsGameForegroundV63())
    return
sigSuWaitV181 := RegExReplace(sigSuKeyV181,"^[~*$<>!^+#]+")
KeyWait, %sigSuWaitV181%
if (!IsGameForegroundV63())
    return
SigStartBackgroundV183("BOTH")
return

SigSuButtonV181:
if (!sigBusyV147 && !SigSuKeySaveV181())
    return
SigStartBackgroundV183("BOTH")
return

SigStartBackgroundV183(mode := "BOTH")
{
    global sigBusyV147,sigActiveModeV182,sigCancelV147,sigBackgroundV179,sigArmedV147
    global backgroundHwndV63,backgroundPidV63,ticketPickupWaitV279
    global sigTerminalErrorV762
    mode := "BOTH",capMode := "SET_SU"
    if (sigBusyV147 || IsObject(ticketPickupWaitV279))
    {
        ; Loi goi trung khong duoc huy luot SIG dang chay.
        SigLogV147("SIG_DUPLICATE_IGNORED mode=" . mode)
        return false
    }
    sigTerminalErrorV762 := ""
    sigArmedV147 := 0
    SigLogV147("START_REQUEST mode=" . mode . " cap=" . capMode . " foreground=" . IsGameForegroundV63())
    if (!SigBackgroundBindV179())
    {
        SigLogV147("START_REJECT mode=" . mode . " reason=NO_MAIN_GAME_WINDOW")
        ToolTipInfoV386("Không tìm thấy cửa sổ game chính để chạy Sig nền.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    if (!PickupActivateGameV13())
        return false
    wasBackground := sigBackgroundV179
    sigBackgroundV179 := true,sigCancelV147 := false
    try
    {
        SigLogV147("START_BOUND mode=" . mode . " hwnd=" . backgroundHwndV63
            . " pid=" . backgroundPidV63 . " foreground=" . IsGameForegroundV63() . " wait_for_focus=0")
        return SigRunV147(mode)
    }
    finally
        sigBackgroundV179 := wasBackground
}

FarmNaoBindV184()
{
    global farmNaoKeyV181
    static previous := ""
    if (previous!="")
        BackgroundHotkeyV63("$" . previous,"FarmNaoHotkeyV184","Off UseErrorLevel")
    previous := farmNaoKeyV181
    if (previous!="")
        BackgroundHotkeyV63("$" . previous,"FarmNaoHotkeyV184","On UseErrorLevel")
}

FarmNaoHotkeyV184:
if (FarmControlRunningV186() && !IsObject(farmMapPauseV52) && farmControlOwnerV186!="NAO")
    return
if (!FarmHotkeyForegroundV154())
    return
farmNaoWaitV184 := RegExReplace(farmNaoKeyV181,"^[~*$<>!^+#]+")
KeyWait, %farmNaoWaitV184%
if (!FarmHotkeyForegroundV154())
    return
if (!FarmControlRunningV186())
{
    fautLab1V309 := false
labNumberV314 := 1
    FarmEntrySettingsSaveV578()
    farmControlOwnerV186 := "NAO"
}
MapKeyTraceV174(farmNaoKeyV181,"FARM_FAUT_HOTKEY route=MAP_STAGE1_DISPATCH")
Gosub, MapControlActionV168
return

FarmEntryOptionsChangedV315:
GuiControlGet, farmEntrySigV315, 1:, FarmEntrySigCheckV315
GuiControlGet, farmEntryGoldV315, 1:, FarmEntryGoldCheckV347
section := ProfileSection(currentProfile)
IniWrite, %farmEntrySigV315%, % ProfileConfigPathV364(section), %section%, FarmEntrySig
IniWrite, %farmEntryGoldV315%, % ProfileConfigPathV364(section), %section%, FarmEntryGold
if (A_GuiControl="FarmEntrySigCheckV315" && farmEntrySigV315
    && !sigBusyV147 && !IsObject(ticketPickupWaitV279))
    SigStartBackgroundV183("BOTH")
return

AutoLoadMapChangedV340:
GuiControlGet, autoLoadMapV340, 1:, AutoLoadMapCheckV348
autoLoadMapV340 := autoLoadMapV340 ? true : false
autoLoadMapSectionV340 := ProfileSection(currentProfile)
IniWrite, %autoLoadMapV340%, % ProfileConfigPathV364(autoLoadMapSectionV340), %autoLoadMapSectionV340%, AutoLoadMap
return

LoadMapManualV341:
if (IsObject(roomRecordV108) || roomRecordFinishingV21)
{
    ToolTipInfoV386("Dừng lưu lộ trình trước khi bấm Load.")
    SetTimer, RemoveToolTip, -2500
    return
}
autoLoadMapPendingV340 := false
Gui, 1:Default
FonManualLoadV758()
return

VeLabButtonV321:
if (veLabBusyV321)
{
    sigCancelV147 := true
    return
}
RegExMatch(A_GuiControl,"VeLab(6|7|8|9|10)Button",veLabSelectedV321)
veLabLevelV321 := veLabSelectedV3211+0
if (!IsObject(VeLabRecipeV324(veLabLevelV321)))
{
    ToolTipInfoV386("Chưa có CLASS Đá và vé LAB" . veLabLevelV321 . " để nối công thức.")
    SetTimer, RemoveToolTip, -4000
    return
}
if (sigBusyV147 || FarmControlRunningV186())
{
    ToolTipInfoV386("Dừng Farm / SIG trước khi tạo vé LAB.")
    SetTimer, RemoveToolTip, -3000
    return
}
try
    veLabMaxV322 := VeLabStoneCountV322(VeLabRecipeV324(veLabLevelV321).stone)
catch e
{
    ToolTipInfoV386(e.Message)
    SetTimer, RemoveToolTip, -4000
    return
}
Gui, VeLabQuantity:Destroy
Gui, VeLabQuantity:New, +Owner1 +LabelVeLabQuantityV322, % "Tạo vé LAB" . veLabLevelV321
Gui, VeLabQuantity:Font, s9, Segoe UI
Gui, VeLabQuantity:Add, Text, x12 y12 w230 h20, % "Có " . veLabMaxV322 . " Đá LAB" . veLabLevelV321 . " trong rương và cube"
Gui, VeLabQuantity:Add, Text, x12 y42 w65 h20, Số lượng:
Gui, VeLabQuantity:Add, Edit, x80 y39 w156 h23 Number vVeLabQuantityInputV322, %veLabMaxV322%
Gui, VeLabQuantity:Add, UpDown, % "Range0-" . veLabMaxV322, %veLabMaxV322%
Gui, VeLabQuantity:Add, Button, x80 y76 w75 h25 Default gVeLabQuantitySubmitV322, Tạo vé
Gui, VeLabQuantity:Add, Button, x162 y76 w75 h25 gVeLabQuantityCancelV322, Hủy
Gui, VeLabQuantity:Show, w250 h113
Gui, 1:Default
return

VeLabQuantitySubmitV322:
GuiControlGet, veLabCountV321, VeLabQuantity:, VeLabQuantityInputV322
if (!RegExMatch(Trim(veLabCountV321),"^\d+$") || veLabCountV321<1)
{
    ToolTipInfoV386("Nhập số lượng lớn hơn 0.")
    SetTimer, RemoveToolTip, -3000
    return
}
try
    veLabMaxV322 := VeLabStoneCountV322(VeLabRecipeV324(veLabLevelV321).stone)
catch e
{
    ToolTipInfoV386(e.Message)
    SetTimer, RemoveToolTip, -4000
    return
}
if (veLabCountV321>veLabMaxV322)
{
    ToolTipInfoV386("Hiện chỉ có " . veLabMaxV322 . " Đá LAB" . veLabLevelV321 . ".")
    SetTimer, RemoveToolTip, -3000
    return
}
Gui, VeLabQuantity:Destroy
Gui, 1:Default
VeLabRunV321(veLabLevelV321,veLabCountV321+0)
return

VeLabQuantityCancelV322:
VeLabQuantityV322Close:
VeLabQuantityV322Escape:
Gui, VeLabQuantity:Destroy
Gui, 1:Default
return

VeLabRecipeV324(tier)
{
    static recipes := {6:{stone:2007,ticket:2037},7:{stone:2008,ticket:2038},8:{stone:2009,ticket:2039}}
    return recipes.HasKey(tier) ? recipes[tier] : false
}

VeLabReadContextV323()
{
    global backgroundPidV63
    if (!BackgroundValidV63())
        throw Exception("Chưa tìm thấy cửa sổ game để đếm đá / tạo vé")
    pid := backgroundPidV63,base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        throw Exception("Không đọc được game để đếm đá / tạo vé")
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),inv := player ? D2ReadU32(h,player+0x60) : 0
        if (!player || !inv)
            throw Exception("Chưa đọc được nhân vật và rương trong game")
        return {pid:pid,h:h,d2base:base,player:player,inv:inv,first:D2ReadU32(h,inv+0x10)}
    }
    catch e
    {
        DllCall("CloseHandle","Ptr",h)
        throw e
    }
}

VeLabStoneCountV322(stoneClass)
{
    if (!SigBackgroundBindV179() || !PickupActivateGameV13())
        throw Exception("Chưa đọc được cửa sổ game để đếm đá")
    ctx := VeLabReadContextV323(),count := 0
    try
    {
        for uid,item in V9SnapshotAllItems(ctx)
            if (item.cls=stoneClass && D2ReadU8V18(ctx.h,item.data)=2
                && (item.loc=3 || (item.loc=0 && item.owner=ctx.inv)))
                count++
        return count
    }
    finally
        DllCall("CloseHandle","Ptr",ctx.h)
}

VeLabRunV321(tier,count)
{
    global veLabBusyV321,scosEntryV162,sigBusyV147,sigCancelV147,pickupTimerBusy,pickupImageOn,backgroundPidV63
    recipe := VeLabRecipeV324(tier)
    if (!IsObject(recipe))
        return false
    if (veLabBusyV321 || sigBusyV147 || FarmControlRunningV186())
    {
        ToolTipInfoV386("Dừng Farm / SIG trước khi tạo vé LAB.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    if (!SigBackgroundBindV179() || !PickupActivateGameV13())
        return false
    level := RoomRecordLevelV259(backgroundPidV63)
    if (!FarmReviveTownLevelV295(level))
    {
        ToolTipInfoV386("Tạo vé LAB khi nhân vật ở thành.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    oldPickup := pickupImageOn,ctx := false,done := 0,message := "",verified := false
    veLabBusyV321 := true,sigCancelV147 := false
    PickupEnabledSetV71(false,true,false)
    for _,n in [6,7,8,9,10]
        GuiControl, Disable, % "VeLab" . n . "ButtonV321"
    GuiControl, Enable, % "VeLab" . tier . "ButtonV321"
    GuiControl,, % "VeLab" . tier . "ButtonV321", Dừng
    try
    {
        started := A_TickCount
        while (pickupTimerBusy && A_TickCount-started<4000)
            Sleep, 50
        if (pickupTimerBusy)
            throw Exception("Đang có thao tác nhặt; chưa tạo vé LAB")
        ctx := VeLabReadContextV323()
        r := {map:"LAB_TICKET",pid:ctx.pid,until:A_TickCount+180000,phase:"TICKET",labNumberV314:tier,stoneClassV324:recipe.stone,ticketClassV324:recipe.ticket}
        scosEntryV162 := r,ctx.scosEntry := true
        SigLogV147("VELAB_START tier=" . tier . " requested=" . count)
        Loop
        {
            if (sigCancelV147 || scosEntryV162!=r || !BackgroundValidV63() || D2GetActiveGamePidV95()!=r.pid)
                throw Exception("Đã dừng tạo vé LAB")
            if (RoomRecordLevelV259(r.pid)!=level)
                throw Exception("Đã rời thành; ngừng tạo vé LAB")
            if (r.lab6StepV318="PICKUP_GROUND" && !r.batchCountedV321)
            {
                done++,r.batchCountedV321 := true
                SigLogV147("VELAB_CREATED tier=" . tier . " done=" . done . " requested=" . count . " uid=" . r.lab6TicketUidV318)
                if (done<count)
                {
                    r.lab6StepV318 := "VERIFY_EMPTY_CUBE",r.lab6TicketDoneV318 := false,r.batchCountedV321 := false
                    r.lab6TicketUidV318 := 0
                }
            }
            if (Lab6TicketTickV318(r,ctx,ctx.player))
            {
                verified := done=count
                break
            }
            Sleep, 100
        }
        message := "Đã tạo " . done . "/" . count . " vé LAB" . tier . " và nhặt xong."
    }
    catch e
    {
        message := "Tạo vé LAB" . tier . ": " . done . "/" . count . " - " . e.Message
        SigLogV147("VELAB_STOP tier=" . tier . " done=" . done . " reason=" . e.Message)
    }
    finally
    {
        if (IsObject(ctx))
            DllCall("CloseHandle","Ptr",ctx.h)
        if (IsObject(r) && scosEntryV162=r)
            scosEntryV162 := false
        veLabBusyV321 := false,sigCancelV147 := false
        PickupEnabledSetV71(oldPickup,true,false)
        for _,n in [6,7,8,9,10]
        {
            GuiControl,, % "VeLab" . n . "ButtonV321", % "VeLab" . n
            GuiControl, Enable, % "VeLab" . n . "ButtonV321"
        }
    }
    ToolTipInfoV386(message)
    SetTimer, RemoveToolTip, -6000
    return verified
}
VizEntryArmV687(hwnd)
{
    global scosEntryV162,backgroundPidV63,pickupImageOn,cainPauseFarmV361,farmEntryGoldV315
    if (!BackgroundBindV63(hwnd))
        return false
    level := FarmCurrentLevelV143()
    if (level!=75 && level!=109 && level!=154)
    {
        FonInfoPushV385("Viz: cần đứng ở map 75, 109 hoặc Vizjun 154.")
        return false
    }
    PickupCtrlEndV26()
    scosEntryV162 := {map:"VIZ",pid:backgroundPidV63,until:A_TickCount+180000
        ,phase:(level=154) ? "ROUTE" : "WP",row:1,last:0,pickup:pickupImageOn
        ,vizBase:-1,vizLastCast:0,lastLevel:0}
    scosEntryV162.entryGoldV315 := farmEntryGoldV315
    cainPauseFarmV361 := false
    PickupEnabledSetV71(false,true,false)
    SetTimer, ScosEntryTimerV162, 250
    return true
}

VizBossActiveV687()
{
    global scosEntryV162,farmControlOwnerV186
    return farmControlOwnerV186="VIZ" && IsObject(scosEntryV162)
        && scosEntryV162.map="VIZ" && (scosEntryV162.phase="SEARCH" || scosEntryV162.phase="BOSS")
}

VizScanV687(h,ByRef pb,pid)
{
    global monsterRadiusV48
    result := {known:false,boss:false,near:false},seen := {}
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
    {
        if (CoordLevelV14(h,room)!=154)
            continue
        if (!MonsterBossProbeReadV1(h,room+0x74,4,head))
            return result
        u := NumGet(head,0,"UInt")
        while (u && !seen.HasKey(u))
        {
            if (seen.Count()>=4096 || !MonsterBossProbeReadV1(h,u,0xEC,ub))
                return result
            seen[u] := true
            cls := NumGet(ub,4,"UInt"),mode := NumGet(ub,16,"UInt"),uid := NumGet(ub,12,"UInt")
            if (NumGet(ub,0,"UInt")=1 && uid && mode!=0 && mode!=12)
            {
                if (!MonsterBossProbeReadV1(h,NumGet(ub,0x2C,"UInt"),0x20,mb))
                    return result
                x := NumGet(mb,2,"UShort"),y := NumGet(mb,6,"UShort")
                dist := (x-px)**2+(y-py)**2
                a := {unit:u,uid:uid,cls:cls,x:x,y:y,dist:dist}
                if (cls=1629)
                {
                    if (!IsObject(result.boss) || dist<result.boss.dist)
                        result.boss := a
                }
                else if (dist<=Max(1,monsterRadiusV48)**2 && !MonsterClassExcludedV11(cls,h,u)
                    && !MonsterRetryExcludedV44(uid,x,y,154,pid)
                    && (!IsObject(result.near) || dist<result.near.dist))
                    result.near := a
            }
            u := NumGet(ub,0xE8,"UInt")
        }
    }
    result.known := seen.Count()>0
    return result
}

VizLeftClickV687(ctx,player,boss)
{
    if (!IsObject(boss) || !MonsterBossProbeReadV1(ctx.h,boss.unit,0x30,ub)
        || NumGet(ub,0,"UInt")!=1 || NumGet(ub,4,"UInt")!=1629
        || NumGet(ub,12,"UInt")!=boss.uid || NumGet(ub,16,"UInt")=0 || NumGet(ub,16,"UInt")=12)
        return false
    base := D2GetModuleBaseV35(ctx.pid,"D2Client.dll"),hwnd := GameTargetHwndV63()
    view := AutoMonsterAttackViewV1(ctx.h,base,hwnd,D2ReadU32(ctx.h,player+0x2C))
    if (!IsObject(view) || !MonsterBossProbeReadV1(ctx.h,NumGet(ub,0x2C,"UInt"),0x20,mb))
        return false
    point := AutoMonsterAttackPointV1(mb,view)
    if (!IsObject(point))
        return false
    if (!FarmAttackHoldReleaseV15() || !AutoMonsterPacketCleanupV1())
        return false
    sent := GameTargetClickV63("Left",point.x,point.y)
    PortalLogWriteV66("VIZ_BOSS_LEFT_CLICK uid=" . boss.uid . " queued=" . sent
        . " client_xy=" . point.x . "," . point.y . " next_check_ms=6000")
    return sent
}

VizEntryTickV687(r,ctx,player,ByRef pb,level,px,py)
{
    global scosEntryV162,autoMonsterAttackOn,stage2FlowV380,farmPickupAllowedV57,farmPickupBlockedV57
    global pickupTimerBusy,xRunning,zRunning,gameItemActionOwner,coordSavedV15,monsterRadiusV48
    if (scosEntryV162!=r)
        return
    r.until := A_TickCount+180000

    if (r.lastLevel != level)
    {
        FarmCommonRouteEndV3(r)
        r.lastLevel := level
        r.wpFlowV8 := false
        r.entryBuffDoneV233 := false
        r.vizStage2EnteredV688 := false
        r.phase := (level=154) ? "ROUTE" : "WP"
        PortalLogWriteV66("VIZ_ENTRY_LEVEL level=" . level . " xy=" . px . "," . py . " phase=" . r.phase)
    }

    if (level=75 || level=109)
    {
        FarmMapAssemblyV10(r,ctx,player,pb,level,px,py,"VIZ")
        return
    }
    if (level!=154 || D2ReadU32(ctx.h,player+0x10)=0 || D2ReadU32(ctx.h,player+0x10)=17)
        return

    if (!r.vizStage2EnteredV688)
    {
        r.vizStage2EnteredV688 := true
        r.phase := "ROUTE"
        PortalLogWriteV66("VIZ_STAGE1_TO_STAGE2 level=" . level . " xy=" . px . "," . py . " phase=ROUTE")
    }

        scan := VizScanV687(ctx.h,pb,r.pid)
    if (IsObject(scan.boss))
        r.vizBoss := scan.boss
    else if (r.phase="BOSS")
        r.phase := "FINAL_ATTACK"

    if (r.phase="ROUTE" || r.phase="FIND_ROUTE")
    {
        routePoints := r.phase="FIND_ROUTE" ? r.vizRoute : coordSavedV15
        nearLastCoord := false
        lastCoord := false
        if (IsObject(routePoints) && routePoints.Length() > 0)
        {
            lastCoord := routePoints[routePoints.Length()]
            nearThreshold := Max(80, monsterRadiusV48 * 1.5)
            if (IsObject(lastCoord) && (px-lastCoord.x)**2+(py-lastCoord.y)**2 <= nearThreshold*nearThreshold)
                nearLastCoord := true
        }
        
                if (nearLastCoord)
        {
            r.vizLastCoordV689 := lastCoord
            if (!IsObject(r.vizRoute))
                r.vizRoute := coordSavedV15.Clone()
            FarmCommonRouteEndV3(r)
            Stage2FlowConfigureV380("ITEM",1830,7,true)
            MapStageSetV185(2)
            autoMonsterAttackOn := true
            SetTimer, AutoMonsterAttackTimer, Off
            farmPickupBlockedV57 := false,farmPickupAllowedV57 := true
            PickupEnabledSetV71(true, true, false)
            r.phase := "FINAL_ATTACK"
            FonInfoPushV385("Viz: gần tọa độ cuối - boss kill trái, quái kill phải.")
        }
        else
        {
            if (r.phase="FIND_ROUTE" && IsObject(scan.boss))
                result := "DONE"
            else
            {
                result := FarmMainFlowV8(r,ctx,player,level,px,py,false,"VIZ_FARM",r.phase="FIND_ROUTE" ? r.vizRoute : false,pb)
            }
            if (result!="DONE" || scosEntryV162!=r)
                return
                
            if (!IsObject(r.vizRoute))
                r.vizRoute := coordSavedV15.Clone()
                
            FarmCommonRouteEndV3(r)
            r.phase := "SEARCH"
            Stage2FlowConfigureV380("ITEM",1830,7,true)
            MapStageSetV185(2)
            autoMonsterAttackOn := true
            SetTimer, AutoMonsterAttackTimer, Off
            farmPickupBlockedV57 := false,farmPickupAllowedV57 := true
            PickupEnabledSetV71(true,true,false)
            FonInfoPushV385("Viz: lộ trình DONE; tìm boss 1629, đánh chuột trái.")
            return
        }
    }

    if (pickupTimerBusy || xRunning || zRunning || gameItemActionOwner!="" || !AutoMonsterPacketCleanupV1())
        return

    if (Stage2ItemNewInCubeV420(ctx.h,player,stage2FlowV380,true,true))
    {
        FonInfoPushV385("Viz DONE: charm 1830/07 mới (UID " . stage2FlowV380.completedItemUIDV420 . "); chuyển GĐ3.")
        PortalLogWriteV66("VIZ_DONE next=GD3")
        scosEntryV162 := false
        SetTimer, ScosEntryTimerV162, Off
        MapStageSetV185(2)
        FarmStage3RequestV313("COMPLETE")
        return
    }

    if (IsObject(scan.boss))
    {
        if ((px-scan.boss.x)**2+(py-scan.boss.y)**2 > 25)
        {
            MapStage1MoveV374(ctx,scan.boss.x,scan.boss.y)
            return
        }
        if (!r.vizBossNextCheck || A_TickCount >= r.vizBossNextCheck)
        {
            if (VizLeftClickV687(ctx,player,scan.boss))
            {
                r.phase := "BOSS"
                r.vizLastCast := A_TickCount
                r.vizBossNextCheck := A_TickCount + 6000
                PortalLogWriteV66("VIZ_BOSS_ATTACK uid=" . scan.boss.uid . " next_left_ms=6000")
            }
            return
        }
        halfRadius := Max(1,monsterRadiusV48/2)
        if (IsObject(scan.near) && scan.near.dist<=halfRadius*halfRadius
            && LastAttackSkillV20() && scosEntryV162=r
            && (!r.vizMobNextCheck || A_TickCount>=r.vizMobNextCheck))
        {
            a := scan.near
            if (NativeMapTestV5(true,{pid:r.pid,unit:a.unit,uid:a.uid}))
            {
                r.vizMobNextCheck := A_TickCount+1000
                PortalLogWriteV66("VIZ_QUEST1_DEFEND_RIGHT uid=" . a.uid . " radius=" . halfRadius)
            }
        }
        return
    }

    if (r.phase="FINAL_ATTACK" && !IsObject(scan.boss) && !IsObject(scan.near)
        && IsObject(r.vizLastCoordV689)
        && (px-r.vizLastCoordV689.x)**2+(py-r.vizLastCoordV689.y)**2 > 25)
    {
        MapStage1MoveV374(ctx, r.vizLastCoordV689.x, r.vizLastCoordV689.y)
        return
    }
	if (r.phase="SEARCH")
    {
        if (IsObject(r.vizBoss) && (px-r.vizBoss.x)**2+(py-r.vizBoss.y)**2>25)
            MapStage1MoveV374(ctx,r.vizBoss.x,r.vizBoss.y)
        else if (scan.known)
        {
            r.phase := "FIND_ROUTE"
            FonInfoPushV385("Viz: chưa thấy boss 1629; tìm tiếp theo lộ trình đã lưu.")
        }
        return
    }
    
    if (!scan.known)
        return
        
    if (IsObject(scan.near))
    {
        if (scan.near.dist <= 25 && LastAttackSkillV20() && scosEntryV162=r)
        {
            if (!r.vizMobNextCheck || A_TickCount >= r.vizMobNextCheck)
            {
                a := scan.near
                if (NativeMapTestV5(true,{pid:r.pid,unit:a.unit,uid:a.uid}))
                {
                    AttackIdTipV12(a.cls,Round(Sqrt(a.dist),1))
                    r.vizMobNextCheck := A_TickCount + 1000
                    PortalLogWriteV66("VIZ_MOB_RIGHT_CLICK uid=" . a.uid . " dist=" . Round(Sqrt(a.dist),1))
                }
            }
        }
        return
    }
    FarmPickupFirstV75()
}

GetPortalButtonV361:
GetPortalCoordsV361()
return
EnterPortalButtonV363:
EnterNearestPortalV363()
return
FarmExtraCAINButtonV297:
roomMapLastButtonV22 := "CAIN"
if (CainButtonActionV387())
    return
farmExtraCAINButtonDispatchV297 := true
try
    Gosub, MapControlButtonV168
finally
    farmExtraCAINButtonDispatchV297 := false
return

FarmExtraVIZButtonV297:
roomMapLastButtonV22 := "VIZ"
farmVizButtonDispatchV687 := true
try
    Gosub, MapControlButtonV168
finally
    farmVizButtonDispatchV687 := false
return

FarmExtraWEAButtonV297:
ToolTipInfoV386("WEA: nút chưa gán chức năng.")
SetTimer, RemoveToolTip, -2000
return


FarmExtraTRANButtonV297:
farmExtraTRANButtonDispatchV358 := true
try
    Gosub, MapControlButtonV168
finally
    farmExtraTRANButtonDispatchV358 := false
return
FarmNaoButtonV184:
if ((FarmControlRunningV186() || farmUserPausedV2026) && farmControlOwnerV186="NAO")
{
    FarmUserPauseToggleV2026("NAO")
    return
}
if (FarmControlRunningV186() && farmControlOwnerV186="NAO" && fautLab1V309)
    FarmStopV124("SWITCH_LAB1_TO_FAUT")
if (!FarmControlRunningV186() || farmControlOwnerV186!="NAO")
    fautLab1V309 := false
Gosub, FarmNaoDispatchV309
return

FarmNaoDispatchV309:
GuiControlGet, forceNaoStartV703, 1:, RecoveryStartTestV537
if (!forceNaoStartV703 && !FarmNaoKeySaveV181())
    return
if (!FarmControlRunningV186())
    FarmEntrySettingsSaveV578()
MapKeyTraceV174("FARM_NAO_BUTTON","CLICK route=MAP_STAGE1_DISPATCH")
farmNaoButtonDispatchV186 := true
try
    Gosub, MapControlButtonV168
finally
    farmNaoButtonDispatchV186 := false
return

FarmCycButtonV42:
farmCycButtonDispatchV42 := true
try
    Gosub, MapControlButtonV168
finally
    farmCycButtonDispatchV42 := false
return

CycEntryArmV42(hwnd)
{
    global scosEntryV162,pickupImageOn,packetWatchArmedV1,backgroundPidV63,farmEntryGoldV315
    if (packetWatchArmedV1 || !BackgroundBindV63(hwnd))
        return false
    pid := backgroundPidV63,base := D2GetModuleBaseV35(pid,"D2Client.dll"),h := D2OpenProcess(pid)
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return false
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        if (level!=75 && level!=109 && level!=137 && level!=164 && level!=150)
            return false
        scosEntryV162 := {map:"CYC",pid:pid,until:A_TickCount+300000,phase:"WP",row:1,last:0,pickup:pickupImageOn,lastLevel:0}
        FarmSharedEntryOptionsV781(scosEntryV162)
        PickupEnabledSetV71(false,true,false)
        SetTimer, ScosEntryTimerV162, 250
        FarmPickupSyncV57(0,0,-1,true)
        PortalLogWriteV66("MAP_STAGE1_START map=CYC level=" . level . " route=WP137_STAIRS164_PORTAL150")
        ToolTipInfoV386("GĐ1 CYC: WP → Caldeum → cầu thang → di chuyển → cổng → GĐ2.")
        SetTimer, RemoveToolTip, -4000
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

CycCombatReadyV42(pid := 0)
{
    global scosEntryV162
    r := scosEntryV162
    if (!IsObject(r) || (r.map!="CYC" && r.map!="UBU" && r.map!="M3000") || r.phase!="COMBAT" || !BackgroundValidV63()
        || (pid && r.pid!=pid) || D2GetActiveGamePidV95()!=r.pid)
        return false
    base := D2GetModuleBaseV35(r.pid,"D2Client.dll"),h := base ? D2OpenProcess(r.pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        level := path ? CoordLevelV14(h,D2ReadU32(h,path+0x1C)) : 0
        mapOK := r.map="UBU" ? (level=140 || level=147 || level=148) : r.map="M3000" ? (level=140 || level=141) : (level=164)
        return path && mapOK && scosEntryV162=r
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

CycObjectV42(h,ByRef pb,classId,x := 0,y := 0,radius := 0)
{
    seen := {},best := false,bestDist := radius ? radius*radius+1 : 1.0e20
    if (!radius)
        x := NumGet(pb,2,"UShort"),y := NumGet(pb,6,"UShort")
    for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
    {
        u := D2ReadU32(h,room+0x74)
        Loop, 4096
        {
            if (!u || seen.HasKey(u))
                break
            seen[u] := true
            if (D2ReadU32(h,u)=2 && D2ReadU32(h,u+4)=classId)
            {
                uid := D2ReadU32(h,u+0x0C),path := D2ReadU32(h,u+0x2C)
                if (uid && MonsterBossProbeReadV1(h,path,0x18,ob))
                {
                    ox := NumGet(ob,0x0C,"UInt"),oy := NumGet(ob,0x10,"UInt"),d := (ox-x)**2+(oy-y)**2
                    if (d<bestDist)
                        best := {unit:u,uid:uid,cls:classId,x:ox,y:oy},bestDist := d
                }
            }
            next := D2ReadU32(h,u+0xE8)
            if (next=u)
                break
            u := next
        }
    }
    return best
}

WpCloseAfterSelectV331(logPrefix := "WP")
{
    Sleep, 500
    GameTargetKeyV63("{Esc}")
    Sleep, 300
    wpPidV331 := D2GetActiveGamePidV95()
    wpBaseV331 := wpPidV331 ? D2GetModuleBaseV35(wpPidV331, "D2Client.dll") : 0
    wpHV331 := wpBaseV331 ? D2OpenProcess(wpPidV331) : 0
    if (wpHV331)
    {
        wpPlayerV331 := D2ReadU32(wpHV331, wpBaseV331 + 0x11BBFC)
        wpModeV331 := wpPlayerV331 ? D2ReadU32(wpHV331, wpPlayerV331 + 0x10) : 0
        DllCall("CloseHandle", "Ptr", wpHV331)
        PortalLogWriteV66(logPrefix . "_AFTER_ESC mode=" . wpModeV331)
        if (wpModeV331 = 14)
        {
            GameTargetKeyV63("{Esc}")
            Sleep, 200
            PortalLogWriteV66(logPrefix . "_ESC_EXTRA_CLOSE_ESCAPE_MENU")
        }
    }
}

CycEntryTickV42(r,ctx,player,ByRef pb,level,px,py)
{
    return FarmMapAssemblyV10(r,ctx,player,pb,level,px,py,"CYC")
}


MapRunRestartCheckV17(mapName,hwnd)
{
    return 0
}

MapStage1ArmV185(mapName,hwnd)
{
    global mapWorkflowV185,cainNoFightV361,cainPauseFarmV361,scosEntryV162
    if (!BackgroundBindV63(hwnd))
        return RecoveryStartMissingGameV492(mapName)
    if (!FarmCurrentLevelV143())
    {
        PortalLogWriteV66("STAGE1_WAIT reason=MAP_OR_PLAYER_NOT_READABLE stage4=OFF","STAGE1_WAIT_PLAYER",2000)
        return false
    }
    cainNoFightV361 := false,cainPauseFarmV361 := false
    if (MapScrollFarmV269(mapName))
    {
        if (!Map130EntryArmV257(hwnd,mapName))
            return false
    }
    else if (mapName="UBU")
    {
        if (!UbuEntryArmV62(hwnd))
            return false
    }
    else if (mapName="CYC")
    {
        if (!CycEntryArmV42(hwnd))
            return false
    }
        else if (mapName="NAO")
    {
        if (!NaoEntryArmV188(hwnd))
            return false
    }
    else if (mapName="M3000")
    {
        if (!Farm3000EntryArmV297(hwnd))
            return false
    }
    else if (mapName="TRAN")
    {
        if (!TranEntryArmV358(hwnd))
            return false
    }
    else if (mapName="BO")
    {
        if (!BOEntryArmV413(hwnd))
            return false
    }
        else if (mapName="CAIN")
    {
        if (!CainEntryArmV360(hwnd))
            return false
    }
    else if (mapName="VIZ")
    {
        if (!VizEntryArmV687(hwnd))
            return false
    }
    else if (mapName!="SCOS" || !ScosEntryArmV162(hwnd))
        return false
    MonsterStuckZonesResetV243()
    tranStartLevelV358 := mapName="VIZ" ? 75 : mapName="TRAN" ? 40 : 109
    mapWorkflowV185 := {map:mapName,stage:1,startLevel:tranStartLevelV358,testRows:0}
    return true
}

MapStageSetV185(stage)
{
    global mapWorkflowV185,farmStage2DoneV372
    if (stage=0)
        FarmWatchStopV5()
    if (IsObject(mapWorkflowV185))
    {
        if (stage=2 && mapWorkflowV185.stage!=2)
            farmStage2DoneV372 := false
        mapWorkflowV185.stage := stage
        if (stage=2 && mapWorkflowV185.map!="CAIN" && mapWorkflowV185.map!="BO")
            SetTimer, MapStage2FlowTimerV372, 250
        else
            SetTimer, MapStage2FlowTimerV372, Off
    }
}

MapStage1ReadyV185(level)
{
    global mapWorkflowV185
    if (IsObject(mapWorkflowV185) && (mapWorkflowV185.map="CAIN" || mapWorkflowV185.map="BO"))
        return level>0
    if (IsObject(mapWorkflowV185) && MapScrollFarmV269(mapWorkflowV185.map))
        return level=103
    if (IsObject(mapWorkflowV185) && mapWorkflowV185.map="UBU")
        return level=75
    if (IsObject(mapWorkflowV185) && mapWorkflowV185.map="CYC")
        return level=75 || level=109
    if (IsObject(mapWorkflowV185) && mapWorkflowV185.map="M3000")
        return level=75 || level=109 || level=140 || level=141
    startLevel := IsObject(mapWorkflowV185) ? mapWorkflowV185.startLevel : 0
    if (startLevel<=0)
        startLevel := IsObject(mapWorkflowV185) && mapWorkflowV185.map="TRAN" ? 40 : 109
    return level=startLevel
}

FarmNewRoomRouteResetV612(pid,level)
{
    global farmStartChoiceV2,libRunChoiceV281,stage2MapFileV14,stage2FlowV380
    global coordMapReadyV381,coordMapAcceptedV381,coordMapSerialV381
    global farmStage2DoneV372,coordMoveDoneV14,mapRunResumeV210,coordRunSelectedV210
    global coordCastPendingV50,coordCastLastRowV50,coordCastCountV50
    global coordCursorSnapshotV390,coordCurrentReadAtV132,coordCurrentLevelV400
    global coordNoTargetSinceV14,portalExitPendingV69,portalBackPendingV74
    global fonCursorV724,farmPortalSessionsV725
    global sigProtectionSessionV761,farmMapJournalHoldEpochV940
    if (IsObject(sigProtectionSessionV761) && sigProtectionSessionV761.pid=pid)
        SigProtectionReleaseV761(sigProtectionSessionV761,"NEW_ROOM_CONFIRMED")
    ; Ket thuc luot map truoc (neu chua ket thuc), cho map moi duoc ghi tu dau.
    FarmMapJournalFinishV940("NEW_ROOM")
    farmMapJournalHoldEpochV940 := -1
    PickupFarmResetV762()
    fonCursorV724 := false,farmPortalSessionsV725 := {}
    farmSkillPairV620 := false
    Stage2RoomReplayReleaseV11()
    CoordRouteResetV16()
    farmStartChoiceV2 := false,libRunChoiceV281 := false
    stage2MapFileV14 := false,stage2FlowV380 := false
    coordMapReadyV381 := false,coordMapAcceptedV381 := false
    global coordMapStateV381
    coordMapStateV381 := false
    coordMapSerialV381 += 1
    farmStage2DoneV372 := false,coordMoveDoneV14 := false
    mapRunResumeV210 := false,coordRunSelectedV210 := false
    coordCastPendingV50 := false,coordCastLastRowV50 := 0,coordCastCountV50 := 0
    coordNoTargetSinceV14 := 0,portalExitPendingV69 := false,portalBackPendingV74 := false
    PortalLogWriteV66("NEW_ROOM_ROUTE_RESET pid=" . pid . " level=" . level
        . " farm_progress=RESET radar_display=KEPT next=WAIT_RADAR_NEW_ROOM")
}

MapStage1RestartV185(hwnd)
{
    global mapWorkflowV185
    mapName := IsObject(mapWorkflowV185) ? mapWorkflowV185.map : "SCOS"
    return MapStage1ArmV185(mapName,hwnd)
}

FarmStage3RetryTimerV237:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    SetTimer, FarmStage3RetryTimerV237, Off
    return
}
if (!farmStage3PendingV237 || (farmRestartReasonV238!="COMPLETE" && farmRestartReasonV238!="STUCK")
    || (farmRestartReasonV238="STUCK" && !farmResetWatchEnabledV217))
{
    farmStage3PendingV237 := false
    SetTimer, FarmStage3RetryTimerV237, Off
    return
}
if (!BackgroundValidV63() && IsGameForegroundV63())
    BackgroundBindV63(WinExist("A"))
if (!BackgroundValidV63() || xRunning || zRunning || sigBusyV147 || gameItemActionOwner!="" || !AutoMonsterPacketCleanupV1())
    return
if (StageTwoArmV166(farmRestartReasonV238="STUCK" || ContinuousMapEnabledV168()))
{
    stageTwoV166.restartRunV17 := farmRestartReasonV238="STUCK"
    farmStage3PendingV237 := false
    SetTimer, FarmStage3RetryTimerV237, Off
    MapStageSetV185(3)
}
return

MapStage2CompleteV185(recoveryVerified:=false)
{
    global farmStage3PendingV237,backgroundPidV63
    completeLevelV264 := RoomRecordLevelV259(backgroundPidV63)
    if (completeLevelV264!=1 && completeLevelV264!=40 && completeLevelV264!=75
        && completeLevelV264!=103 && completeLevelV264!=109)
    {
        PortalLogWriteV66("MAP_STAGE3_BLOCKED reason=NOT_CONFIRMED_IN_TOWN level=" . completeLevelV264
            . " recovery_verified=" . recoveryVerified)
        ToolTipInfoV386("Chưa xác nhận nhân vật ở thành - không chuyển GĐ3.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    if (!recoveryVerified)
    {
        PortalLogWriteV66("MAP_STAGE3_BLOCKED reason=PICKUP_NOT_VERIFIED")
        ToolTipInfoV386("Chưa xác nhận nhặt xong - dừng tại thành - không thoát game")
        SetTimer, RemoveToolTip, -5000
        return false
    }
    SigLogV147("MAP_STAGE2_COMPLETE location=TOWN farm=OFF cube_ok=1")
    if (FarmStage3RequestV313("COMPLETE"))
        return true
    FarmErrorKeepV769("TOWN_STAGE3_HANDOFF_FAILED")
    ToolTipInfoV386("GĐ2 xong; giữ phiên farm, chờ xử lý chuyển bước.")
    SetTimer, RemoveToolTip, -5000
    return false
}

; NHAT: one shared checkbox. Farm uses TELE pickup; SIG uses confirmed regular pickup.

FarmControlRunningV186()
{
    global farmStartRetryV237,mapButtonStartV172,autoMonsterAttackOn,scosEntryV162,stageTwoV166,mapFarmStartPendingV170,sigTownV148,farmStage3PendingV237,sigFarmResumePendingV237
    return farmStartRetryV237 || IsObject(sigFarmResumePendingV237) || farmStage3PendingV237 || IsObject(mapButtonStartV172) || autoMonsterAttackOn || IsObject(scosEntryV162)
        || IsObject(stageTwoV166) || mapFarmStartPendingV170 || (IsObject(sigTownV148) && sigTownV148.auto)
}

NaoEntryArmV188(hwnd)
{
    global scosEntryV162,pickupImageOn,packetWatchArmedV1,backgroundPidV63,fautLab1V309,labInventoryOnlyV311,labNumberV314,farmEntrySigV315,farmEntryGoldV315
    if (packetWatchArmedV1 || !BackgroundBindV63(hwnd))
        return false
    pid := backgroundPidV63,base := D2GetModuleBaseV35(pid,"D2Client.dll"),h := D2OpenProcess(pid)
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return false
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        if (level!=109 && (level!=NaoFarmLevelV312(level) || FarmReviveTownLevelV295(level)))
            return false
        px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
        scosEntryV162 := {map:"NAO",pid:pid,until:A_TickCount+120000,phase:level=109 ? "WP" : "MAP",row:1,last:0,pickup:pickupImageOn,shiftX:5138,shiftY:5060}
        FarmSharedEntryOptionsV781(scosEntryV162)
        labInventoryOnlyV311 := false
        scosEntryV162.lab1V310 := fautLab1V309,scosEntryV162.labNumberV314 := labNumberV314,scosEntryV162.preSigDoneV310 := false
        scosEntryV162.entrySigV315 := farmEntrySigV315 ? true : false
        if (!farmEntryGoldV315)
            scosEntryV162.shiftX := px,scosEntryV162.shiftY := py
        scosEntryV162.entryClassV309 := fautLab1V309 ? 2031+labNumberV314 : 1958
        scosEntryV162.entryQualityV309 := fautLab1V309 ? 2 : 7
        PickupEnabledSetV71(false,true,false)
        SetTimer, ScosEntryTimerV162, 250
        FarmPickupSyncV57(0,0,-1,true)
        PortalLogWriteV66("MAP_STAGE1_START map=NAO level=" . level . " origin=" . px . "," . py . " use_item_at=5138,5060 town_route=SCOS_STASH_AND_GOLD item=" . scosEntryV162.entryClassV309 . "/" . scosEntryV162.entryQualityV309 . " destination=LIVE_ENTRY_MAP")
        ToolTipInfoV386((fautLab1V309 ? "GĐ1 LAB" . labNumberV314 . (farmEntryGoldV315 ? " - cất tiền" : " - tại chỗ") . (farmEntrySigV315 ? " - SIG" : "") . " - mở cổng" : "GĐ1 FAUT - cất tiền - mở cổng"))
        SetTimer, RemoveToolTip, -3000
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

NaoPortalsV188(ctx,ByRef pb,includeBlueV198 := false)
{
    portals := {},seen := {}
    for _,room in MonsterLoadedRoomsV20(ctx.h,NumGet(pb,0x1C,"UInt"))
    {
        u := D2ReadU32(ctx.h,room+0x74)
        Loop, 256
        {
            if (!u || seen.HasKey(u))
                break
            seen[u] := true
            portalClassV198 := D2ReadU32(ctx.h,u+4)
            if (D2ReadU32(ctx.h,u)=2 && (portalClassV198=60 || (includeBlueV198 && portalClassV198=59)))
            {
                path := D2ReadU32(ctx.h,u+0x2C)
                if (MonsterBossProbeReadV1(ctx.h,path,0x18,ob))
                {
                    uid := D2ReadU32(ctx.h,u+0x0C)
                    portals[uid] := {uid:uid,unit:u,cls:portalClassV198,x:NumGet(ob,0x0C,"UInt"),y:NumGet(ob,0x10,"UInt")}
                }
            }
            u := D2ReadU32(ctx.h,u+0xE8)
        }
    }
    return portals
}

Lab6RecipeItemV318(ctx,cls,uid:=0)
{
    for itemUid,item in SigSnapshotV147(ctx)
        if (item.cls=cls && item.q=2 && (!uid || itemUid=uid)
            && (item.loc=3 || (item.loc=0 && item.owner=ctx.inv
                && D2ReadU32(ctx.h,item.unit+0x10)!=3 && D2ReadU32(ctx.h,item.unit+0x10)!=5)))
            return item
    for itemUid,item in SigGroundV147(ctx)
        if (item.cls=cls && item.q=2 && (!uid || itemUid=uid))
            return item
    return false
}
