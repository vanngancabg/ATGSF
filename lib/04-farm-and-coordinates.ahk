RoomMonsterSameRoomV113(h,ByRef monsterPath,ByRef playerPath)
{
    monsterRoom1 := NumGet(monsterPath,0x1C,"UInt"), playerRoom1 := NumGet(playerPath,0x1C,"UInt")
    if (!monsterRoom1 || !playerRoom1)
        return false
    monsterRoom2 := D2ReadU32(h,monsterRoom1+0x10), playerRoom2 := D2ReadU32(h,playerRoom1+0x10)
    return monsterRoom2 && monsterRoom2=playerRoom2
}

RoomAttackRoomValidV113(pid,unit,uid)
{
    global roomExploreV89
    base := D2GetModuleBaseV35(pid,"D2Client.dll"), h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        if (!player || !MonsterBossProbeReadV1(h,unit,0x30,ub)
            || NumGet(ub,0,"UInt")!=1 || NumGet(ub,12,"UInt")!=uid
            || NumGet(ub,16,"UInt")=0 || NumGet(ub,16,"UInt")=12)
            return false
        if (!MonsterBossProbeReadV1(h,NumGet(ub,0x2C,"UInt"),0x20,mp)
            || !MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,pp))
            return false
        playerRoom1 := NumGet(pp,0x1C,"UInt")
        if (roomExploreV89.skipCombatRoom && playerRoom1 && D2ReadU32(h,playerRoom1+0x10)=roomExploreV89.skipCombatRoom)
            return false
        allowed := RoomMonsterSameRoomV113(h,mp,pp)
        if (!allowed)
            AutoMonsterAttackLogV2("ROOM_ATTACK_SKIP uid=" . uid . " reason=MONSTER_IN_OTHER_ROOM",true)
        return allowed
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

CainLockedBossAttackValidV406(pid,unit,uid)
{
    global cainHuntRouteV403
    if (!CainHuntActiveV403() || !IsObject(cainHuntRouteV403) || cainHuntRouteV403.pid!=pid
        || !IsObject(cainHuntRouteV403.boss) || cainHuntRouteV403.boss.uid!=uid)
        return false
    boss := cainHuntRouteV403.boss
    base := D2GetModuleBaseV35(pid,"D2Client.dll"),h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        if (!player || !MonsterBossProbeReadV1(h,unit,0x30,ub)
            || NumGet(ub,0,"UInt")!=1 || NumGet(ub,0x0C,"UInt")!=uid
            || NumGet(ub,4,"UInt")!=boss.cls || NumGet(ub,0x10,"UInt")=0 || NumGet(ub,0x10,"UInt")=12)
            return false
        if (!MonsterBossProbeReadV1(h,NumGet(ub,0x2C,"UInt"),0x20,mp)
            || !MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,pp))
            return false
        return CoordLevelV14(h,NumGet(mp,0x1C,"UInt"))=CainHuntLevelV422()
            && CoordLevelV14(h,NumGet(pp,0x1C,"UInt"))=CainHuntLevelV422()
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

FarmCombatViewV624(pid,target,message)
{
    global farmCombatViewV624
    farmCombatViewV624 := {pid:pid,uid:IsObject(target) ? target.uid : 0
        ,cls:IsObject(target) ? target.cls : 0,text:message,at:A_TickCount}
}

FarmCombatSendResultV624(pid,unit,uid,sent)
{
    global farmCombatViewV624
    c := farmCombatViewV624
    cls := IsObject(c) && c.pid=pid && c.uid=uid ? c.cls : 0
    FarmCombatViewV624(pid,{uid:uid,cls:cls},sent ? "đang đánh" : "có quái; lệnh đánh chưa gửi")
    return sent
}

AutoMonsterPacketSendV1(pid, unit, uid)
{
    global farmBuffExclusiveV621
    if (farmBuffExclusiveV621)
    {
        AutoMonsterAttackLogV2("COMBAT_SEND_BLOCK reason=BUFF_EXCLUSIVE uid=" . uid)
        return false
    }
    global roomExploreV89,autoMonsterAttackOn,farmAttackHoldV15,farmAttackUsedV15
    global farmApproachV722
    closeV722 := IsObject(farmApproachV722) && farmApproachV722.pid=pid
        && IsObject(farmApproachV722.target) && farmApproachV722.target.uid=uid
        && farmApproachV722.target.unit=unit && A_TickCount-farmApproachV722.at<500
    if (!FarmCenterPolicyV741(pid) && !closeV722 && RoomFarmBoundaryV235() && !CainLockedBossAttackValidV406(pid,unit,uid)
        && !RoomAttackRoomValidV113(pid,unit,uid))
    {
        AutoMonsterAttackLogV2("COMBAT_SEND_BLOCK reason=ROOM_BOUNDARY uid=" . uid)
        return false
    }
    if (!NativeDispatchReadyV10(true) || D2GetActiveGamePidV95()!=pid)
    {
        AutoMonsterAttackLogV2("COMBAT_SEND_BLOCK reason=DISPATCH_NOT_READY uid=" . uid . " active=" . D2GetActiveGamePidV95() . " expected=" . pid)
        return false
    }
    farmAttackUsedV15 := true
    if (!AutoMonsterPacketCleanupV1())
    {
        AutoMonsterAttackLogV2("COMBAT_SEND_BLOCK reason=PACKET_OR_THREAD_BUSY uid=" . uid)
        return false
    }

    if (autoMonsterAttackOn)
    {
        if (!FarmCenterPolicyV741(pid))
            return Form6AttackV716(pid,unit,uid)
        global farmCenterCycleV741
        if (FarmCenterPendingV741(pid))
        {
            global farmItemLockV625
            if (FarmParentNextV767(farmCenterCycleV741.phase)="")
            {
                AutoMonsterAttackLogV2("COMBAT_SEND_BLOCK reason=CENTER_PHASE uid=" . uid . " phase=" . farmCenterCycleV741.phase)
                return false
            }
            cycleV741 := farmCenterCycleV741
        }
        else
            cycleV741 := FarmCenterCaptureV741(pid)
        if (!IsObject(cycleV741))
        {
            AutoMonsterAttackLogV2("COMBAT_SEND_BLOCK reason=CENTER_CAPTURE uid=" . uid)
            return false
        }
        nextParentV767 := FarmParentNextV767(cycleV741.phase)
        if (nextParentV767="")
            nextParentV767 := "ATTACK_MORE"
        ; Keep the source phase while Form6Attack temporarily requires ATTACK.
        ; Normal farm dispatch continues to validate against fixed B.
        originPhaseV1190 := cycleV741.phase
        cycleV741.dispatchOriginV1190 := originPhaseV1190
        farmCenterCycleV741 := cycleV741,cycleV741.phase := "ATTACK"
        try
            return Form6AttackV716(pid,unit,uid)
        finally
        {
            if (farmCenterCycleV741=cycleV741)
                cycleV741.phase := nextParentV767
            cycleV741.dispatchOriginV1190 := ""
        }
    }

    holdModeV17 := autoMonsterAttackOn && FarmAttackRowFiveV18()
    held := farmAttackHoldV15
    if (IsObject(held))
    {
        if (holdModeV17 && held.pid=pid && held.uid=uid && held.unit=unit && !held.releaseV15)
        {
            if (FarmAttackAimV16(held))
                return true
            FarmAttackHoldReleaseV15()
            return false
        }
        FarmAttackHoldReleaseV15()
        return false
    }
    if (autoMonsterAttackOn)
    {
        if (!LastAttackSkillV20())
        {
            FarmCombatViewV624(pid,{uid:uid},"có quái; chưa chọn được F cuối")
            return false
        }
        return FarmCombatSendResultV624(pid,unit,uid,NativeMapTestV5(true,{pid:pid,unit:unit,uid:uid,holdRightV15:holdModeV17}))
    }
    return FarmCombatSendResultV624(pid,unit,uid,NativeMapTestV5(true,{pid:pid,unit:unit,uid:uid}))
}
AutoMonsterAttackLogV2(message, throttle := false)
{
    if (!ManualLogActiveV81())
        return
    FarmInfoEventV4(message)
    global autoMonsterExportV2, pickupCubeTraceUntil
    if (RegExMatch(message,"^(MAP_MOVE_|NATIVE_|AUTO_NATIVE_|AUTO_CLIENT_|COMBAT_|LOW_HP_|ROUTE_|REVIVE_|FARM_|START|STOP)"))
        PortalLogWriteV66("FARM_ACTION " . message)
    if (!pickupCubeTraceUntil || A_TickCount>=pickupCubeTraceUntil)
        return
    static last := 0
    if (throttle && A_TickCount-last<2000)
        return
    last := A_TickCount
    log := TxtRootPathV816("Auto-GSF-Tu-Danh.txt")
    ManualLogAppendV81(A_Now . " tick=" . A_TickCount . " | " . message . "`r`n", log, "UTF-8")
    if (autoMonsterExportV2)
    {
        DebugTraceWrite("packet", "AUTO_DIAGNOSTIC " . message)
        DebugTraceWrite("monster", "AUTO_DIAGNOSTIC " . message)
    }
}

AutoGSFDrawTabV3(wParam, lParam, msg, hwnd)
{
    global AutoGSFTabHwndV3
    if (CoordDrawRowV17(lParam))
        return true
    if (!lParam || !AutoGSFTabHwndV3 || NumGet(lParam+0,0,"UInt")!=101)
        return
    hwndOffset := A_PtrSize=8 ? 24 : 20
    dcOffset := A_PtrSize=8 ? 32 : 24
    rectOffset := A_PtrSize=8 ? 40 : 28
    if (NumGet(lParam+0,hwndOffset,"Ptr")!=AutoGSFTabHwndV3)
        return
    item := NumGet(lParam+0,8,"UInt")
    if (item>3)
        return
    dc := NumGet(lParam+0,dcOffset,"Ptr")
    rect := lParam+rectOffset
    selected := (NumGet(lParam+0,16,"UInt") & 1)
    color := item=0 ? 0xFFD9B8 : item=1 ? 0xF0D1E5 : item=2 ? 0xD1F0DA : 0xB8E8FF
    brush := DllCall("gdi32\CreateSolidBrush","UInt",color,"Ptr")
    saved := DllCall("gdi32\SaveDC","Ptr",dc,"Int")
    try
    {
        DllCall("user32\FillRect","Ptr",dc,"Ptr",rect,"Ptr",brush)
        DllCall("user32\DrawEdge","Ptr",dc,"Ptr",rect,"UInt",5,"UInt",15)
        font := DllCall("SendMessage","Ptr",AutoGSFTabHwndV3,"UInt",0x31,"Ptr",0,"Ptr",0,"Ptr")
        if (font)
            DllCall("gdi32\SelectObject","Ptr",dc,"Ptr",font,"Ptr")
        DllCall("gdi32\SetBkMode","Ptr",dc,"Int",1)
        DllCall("gdi32\SetTextColor","Ptr",dc,"UInt",0)
        caption := item=0 ? "1. BUFF" : item=1 ? "2. NHẶT ĐỒ" : item=2 ? "3. FARM" : "4. LIST ITEM"
        DllCall("user32\DrawTextW","Ptr",dc,"WStr",caption,"Int",-1,"Ptr",rect,"UInt",0x25)
        if (NumGet(lParam+0,16,"UInt") & 0x10)
        {
            VarSetCapacity(focusRect,16,0)
            Loop, 4
                NumPut(NumGet(rect+0,(A_Index-1)*4,"Int"),focusRect,(A_Index-1)*4,"Int")
            DllCall("user32\InflateRect","Ptr",&focusRect,"Int",-4,"Int",-4)
            DllCall("user32\DrawFocusRect","Ptr",dc,"Ptr",&focusRect)
        }
    }
    finally
    {
        if (saved)
            DllCall("gdi32\RestoreDC","Ptr",dc,"Int",saved)
        if (brush)
            DllCall("gdi32\DeleteObject","Ptr",brush)
    }
    return true
}

CharacterDLLProbeTimerV3:
if (!ManualLogActiveV81())
{
    SetTimer, CharacterDLLProbeTimerV3, Off
    return
}
if (!pickupCubeTraceUntil || A_TickCount>=pickupCubeTraceUntil)
{
    SetTimer, CharacterDLLProbeTimerV3, Off
    return
}
if (!IsGameActive() || !IsObject(characterDLLProbeV3) || characterDLLProbeV3.busy)
    return
characterDLLProbeV3.busy := true
try
    CharacterDLLProbeScanV3()
catch probeErrorV3
    DebugTraceWrite("character", "ERROR message=" . probeErrorV3.Message)
finally
    characterDLLProbeV3.busy := false
return

CharacterDLLProbeScanV3()
{
    global characterDLLProbeV3, zRunning, xRunning, currentProfile
    pid := D2GetActiveGamePidV95()
    if (!pid)
        return
    h := DllCall("OpenProcess","UInt",0x0410,"Int",0,"UInt",pid,"Ptr")
    if (!h)
    {
        DebugTraceWrite("character","OPEN_READ_FAIL error=" . A_LastError)
        return
    }
    try
    {
        base := D2GetModuleBaseV35(pid,"D2Client.dll")
        player := base ? D2ReadU32(h,base+0x11BBFC) : 0
        if (!MonsterBossProbeReadV1(h,player,0xEC,ub) || NumGet(ub,0,"UInt")!=0)
        {
            DebugTraceWrite("character","PLAYER_NOT_READY pid=" . pid)
            return
        }
        data := NumGet(ub,0x14,"UInt"), path := NumGet(ub,0x2C,"UInt")
        name := MonsterBossProbeReadV1(h,data,16,nb) ? StrGet(&nb,16,"CP0") : "UNREADABLE"
        xy := MonsterBossProbeReadV1(h,path,0x20,pb) ? NumGet(pb,2,"UShort") . "," . NumGet(pb,6,"UShort") : "UNREADABLE"
        levelIdV16 := CoordLevelV14(h,D2ReadU32(h,path+0x1C))
        townCandidateV16 := levelIdV16=1 || levelIdV16=40 || levelIdV16=75 || levelIdV16=103 || levelIdV16=109
        DebugTraceWrite("character", "POSITION level_id=" . levelIdV16 . " town_candidate=" . townCandidateV16
            . " town_rule=BASE_GAME_IDS_VERIFY_MEDIAN xy=" . xy . " mode=" . NumGet(ub,0x10,"UInt")
            . " z_buff_running=" . zRunning . " x_buff_running=" . xRunning . " profile=" . currentProfile)
        stats := NumGet(ub,0x5C,"UInt"), skills := NumGet(ub,0xA8,"UInt")
        text := "PLAYER pid=" . pid . " ptr=" . V92Hex(player) . " name=" . name
            . " uid=" . NumGet(ub,0xC,"UInt") . " class_id=" . NumGet(ub,4,"UInt")
            . " mode=" . NumGet(ub,0x10,"UInt") . " xy=" . xy . " stats=" . V92Hex(stats) . " skills=" . V92Hex(skills)
        if (MonsterBossProbeReadV1(h,stats,0x100,sb))
        {
            text .= "`r`nSTAT_ROOT_RAW=" . MonsterBossProbeHexV1(sb,0x100)
            for _, off in [0x48,0x24]
            {
                arr := NumGet(sb,off,"UInt"), count := NumGet(sb,off+4,"UShort"), capacity := NumGet(sb,off+6,"UShort")
                if (count<1 || count>1024 || capacity<count || !MonsterBossProbeReadV1(h,arr,count*8,ab))
                    continue
                text .= "`r`nSTATS source=+" . Format("{:02X}",off) . " count=" . count
                Loop, %count%
                {
                    at := (A_Index-1)*8
                    layer := NumGet(ab,at,"UShort"), id := NumGet(ab,at+2,"UShort"), value := NumGet(ab,at+4,"Int")
                    text .= "`r`nSTAT id=" . id . " layer=" . layer . " value=" . value
                    if (layer=0 && (id=6 || id=7 || id=8 || id=9))
                        text .= " fixed256=" . Round(value/256,2)
                }
                break
            }
            queue := [stats], seen := {}
            for _, off in [0x3C,0x40]
            {
                ptr := NumGet(sb,off,"UInt")
                if (ptr>=0x10000)
                    queue.Push(ptr)
            }
            index := 1
            while (index<=queue.Length() && index<=64)
            {
                node := queue[index], index++
                if (seen.HasKey(node) || !MonsterBossProbeReadV1(h,node,0x80,lb))
                    continue
                if (node!=stats && (NumGet(lb,8,"UInt")>5 || NumGet(lb,0x14,"UInt")>4096))
                    continue
                seen[node] := true
                text .= "`r`nSTATE_LIST_PROBE ptr=" . V92Hex(node)
                    . " state_at14=" . NumGet(lb,0x14,"UInt") . " skill_at1C=" . NumGet(lb,0x1C,"UInt")
                    . " level_at20=" . NumGet(lb,0x20,"UInt") . " expiry_at18=" . NumGet(lb,0x18,"UInt")
                    . " interpretation=UNCONFIRMED raw=" . MonsterBossProbeHexV1(lb,0x80)
                for _, off in [0x3C,0x40]
                {
                    ptr := NumGet(lb,off,"UInt")
                    if (ptr>=0x10000 && !seen.HasKey(ptr))
                        queue.Push(ptr)
                }
            }
        }
        if (MonsterBossProbeReadV1(h,skills,0x20,kb))
        {
            text .= "`r`nSKILL_ROOT_RAW=" . MonsterBossProbeHexV1(kb,0x20)
            for _, entry in [{slot:"FIRST",off:4},{slot:"LEFT",off:8},{slot:"RIGHT",off:12}]
            {
                skill := NumGet(kb,entry.off,"UInt")
                text .= "`r`nSKILL_SLOT_PROBE slot=" . entry.slot . " ptr=" . V92Hex(skill)
                    . " " . CharacterSkillProbeV3(h,skill)
            }
            skill := NumGet(kb,4,"UInt"), seenSkills := {}
            Loop, 128
            {
                if (!skill || seenSkills.HasKey(skill) || !MonsterBossProbeReadV1(h,skill,0x40,ks))
                    break
                seenSkills[skill] := true
                text .= "`r`nSKILL_LIST_PROBE ptr=" . V92Hex(skill) . " " . CharacterSkillProbeV3(h,skill)
                skill := NumGet(ks,4,"UInt")
            }
        }
        if (text!=characterDLLProbeV3.lastSnapshot)
        {
            DebugTraceWrite("character",text)
            characterDLLProbeV3.lastSnapshot := text
        }
        modules := ["D2Client.dll","D2Common.dll","D2Net.dll","D2Game.dll","D2Win.dll"]
        i := characterDLLProbeV3.moduleIndex
        if (i<=modules.Length())
        {
            module := modules[i]
            CharacterDLLExportsV3(h,pid,module)
            characterDLLProbeV3.moduleIndex := i+1
        }
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

CharacterSkillProbeV3(h,skill)
{
    if (!MonsterBossProbeReadV1(h,skill,0x40,b))
        return "READ_FAIL"
    row := NumGet(b,0,"UInt")
    id := MonsterBossProbeReadV1(h,row,0x20,t) ? NumGet(t,0,"UShort") : -1
    return "candidate_skill_id=" . id . " level_at28=" . NumGet(b,0x28,"UInt")
        . " interpretation=PROBE raw=" . MonsterBossProbeHexV1(b,0x40)
}

CharacterDLLExportsV3(h,pid,module)
{
    base := D2GetModuleBaseV35(pid,module)
    if (!MonsterBossProbeReadV1(h,base,0x40,dos) || NumGet(dos,0,"UShort")!=0x5A4D)
    {
        DebugTraceWrite("character","DLL_NOT_READY name=" . module)
        return
    }
    pe := NumGet(dos,0x3C,"UInt")
    if (pe>0x100000 || !MonsterBossProbeReadV1(h,base+pe,0x108,nt)
        || NumGet(nt,0,"UInt")!=0x4550 || NumGet(nt,24,"UShort")!=0x10B)
    {
        DebugTraceWrite("character","DLL_HEADER_INVALID name=" . module)
        return
    }
    size := NumGet(nt,24+56,"UInt"), expRva := NumGet(nt,24+96,"UInt"), expSize := NumGet(nt,24+100,"UInt")
    out := "DLL name=" . module . " base=" . V92Hex(base) . " timestamp=" . NumGet(nt,8,"UInt")
        . " image_size=" . size . " machine=" . Format("{:04X}",NumGet(nt,4,"UShort"))
    if (expRva && expRva<size && MonsterBossProbeReadV1(h,base+expRva,40,eb))
    {
        ordinalBase := NumGet(eb,16,"UInt"), n := NumGet(eb,20,"UInt"), nn := NumGet(eb,24,"UInt")
        fns := NumGet(eb,28,"UInt"), names := NumGet(eb,32,"UInt"), ords := NumGet(eb,36,"UInt")
        out .= " exports=" . n . " named=" . nn . " ordinal_base=" . ordinalBase
        named := {}
        if (nn>0 && nn<=4096 && names<size && ords<size
            && MonsterBossProbeReadV1(h,base+names,nn*4,np) && MonsterBossProbeReadV1(h,base+ords,nn*2,op))
        {
            Loop, %nn%
            {
                rva := NumGet(np,(A_Index-1)*4,"UInt"), ordinalIndex := NumGet(op,(A_Index-1)*2,"UShort")
                if (rva<size && MonsterBossProbeReadV1(h,base+rva,128,nameBuf))
                    named[ordinalIndex] := StrGet(&nameBuf,128,"CP0")
            }
        }
        if (n>0 && n<=4096 && fns<size && MonsterBossProbeReadV1(h,base+fns,n*4,fb))
        {
            Loop, %n%
            {
                index := A_Index-1, rva := NumGet(fb,index*4,"UInt")
                if (!rva || rva>=size)
                    continue
                out .= "`r`nEXPORT ordinal=" . (ordinalBase+index) . " name=" . (named.HasKey(index) ? named[index] : "ORDINAL_ONLY")
                    . " rva=" . V92Hex(rva) . " address=" . V92Hex(base+rva)
                    . " forwarded=" . (rva>=expRva && rva<expRva+expSize)
            }
        }
    }
    else
        out .= " exports=NONE_OR_UNREADABLE"
    if (module="D2Client.dll")
    {
        candidates := [{name:"ClickMap_COORDS",rva:0x1BF20},{name:"SetSelectedUnit_UNIT_PTR",rva:0x51860}
            ,{name:"GetSelectedUnit",rva:0x51A80},{name:"Attack_STRUCT",rva:0x1A060}]
        for _, fn in candidates
        {
            read := fn.rva<size && MonsterBossProbeReadV1(h,base+fn.rva,128,code)
            out .= "`r`nINTERNAL_FUNCTION_CANDIDATE name=" . fn.name . " reference=1.13c address=" . V92Hex(base+fn.rva)
                . " verified_in_this_build=0 readable=" . read . " bytes=" . (read ? MonsterBossProbeHexV1(code,128) : "READ_FAIL")
        }
    }
    DebugTraceWrite("character",out)
}

AutoMonsterAttackApplyStateV4()
{
    global autoMonsterAttackOn,configGuiVisible,autoMonsterToggleKeyV13,petLearnKeyV13,coordGetKeyV14,coordPointTextV14,farmNaoKeyV181
    global farmResetWatchEnabledV217,farmResetWatchMinutesV217
    MonsterKeysBindV13()
    GuiControl,, PetLearnKeyInputV13, % MouseKeyDisplayV616(petLearnKeyV13="" ? "None" : petLearnKeyV13)
    GuiControl,, FarmResetWatchCheckV217, %farmResetWatchEnabledV217%
    GuiControl,, FarmResetWatchMinutesV217, %farmResetWatchMinutesV217%
    CoordBoxRefreshV15(true)
    if (autoMonsterAttackOn)
        SetTimer, AutoMonsterAttackTimer, 250
    else
        SetTimer, AutoMonsterAttackTimer, Off
}


NativeAttackBuildV5(h,base)
{
    if (!MonsterBossProbeReadV1(h,base,64,dos))
        return false
    nt := base+NumGet(dos,0x3C,"UInt")
    if (!MonsterBossProbeReadV1(h,nt,84,pe)
        || NumGet(pe,0,"UInt")!=0x4550 || NumGet(pe,4,"UShort")!=0x14C
        || NumGet(pe,8,"UInt")!=1268107838 || NumGet(pe,80,"UInt")!=1265664)
        return false
    expected := "A14CBCB86F8B0D24B8BC6F83C0CF83EC283BC80F8F160A0000837C2430015355"
    if (!MonsterBossProbeReadV1(h,base+0x1A060,32,code))
        return false
    if (NumGet(code,1,"UInt")!=base+0xDBC4C || NumGet(code,7,"UInt")!=base+0x11B824)
        return false
    NumPut(0x6FB8BC4C,code,1,"UInt"), NumPut(0x6FBCB824,code,7,"UInt")
    return MonsterBossProbeHexV1(code,32)=expected
}

NativeAttackCaptureV5(w,esp)
{
    global nativeMapTemplateV5, nativeUnitTemplateV7
    if (!MonsterBossProbeReadV1(w.h,esp,12,args))
        return
    ptr := NumGet(args,4,"UInt"), targetMode := NumGet(args,8,"UInt")
    if (!MonsterBossProbeReadV1(w.h,ptr,28,a))
        return
    flags := NumGet(a,0,"UInt"), player := NumGet(a,4,"UInt"), unit := NumGet(a,8,"UInt")
    tx := NumGet(a,12,"UInt"), ty := NumGet(a,16,"UInt")
    uid := unit ? D2ReadU32(w.h,unit+12) : 0
    type := unit ? D2ReadU32(w.h,unit) : -1
    w.count++
    PacketWatchLogV1("NATIVE_ATTACK n=" . w.count . " flags=" . flags . " target_mode=" . targetMode
        . " player=" . V92Hex(player) . " target=" . V92Hex(unit) . " type=" . type . " uid=" . uid
        . " map=" . tx . "," . ty . " right_physical=" . GetKeyState("RButton","P")
        . " raw28=" . MonsterBossProbeHexV1(a,28))
    base := D2GetModuleBaseV35(w.pid,"D2Client.dll")
    if (unit && type=1 && targetMode=1 && GetKeyState("RButton","P")
        && player=D2ReadU32(w.h,base+0x11BBFC) && (flags=134 || flags=138)
        && NumGet(a,20,"UInt")=1 && NumGet(a,24,"UInt")=2)
    {
        nativeUnitTemplateV7 := {pid:w.pid,player:player,flags:flags,aux1:1,aux2:2,source:"LIVE_RIGHT_UNIT_CAPTURE"}
        PacketWatchLogV1("NATIVE_UNIT_TEMPLATE_READY flags=" . flags . " aux1=1 aux2=2 target_mode=1")
    }
    if (!unit && targetMode=0 && GetKeyState("RButton","P")
        && player=D2ReadU32(w.h,base+0x11BBFC) && tx>0 && ty>0 && tx<65536 && ty<65536
        && NumGet(a,20,"UInt")=0 && NumGet(a,24,"UInt")=0)
    {
        nativeMapTemplateV5 := {pid:w.pid,player:player,flags:flags}
        PacketWatchLogV1("NATIVE_MAP_TEMPLATE_READY flags=" . flags . " source=OBSERVED_RIGHT_GROUND_CLICK")
    }
}

NativeMapTestV5(attackUnit := false, autoTarget := false)
{
    MovementCtrlSetV78(false,0,"NativeMapTestV5")
    global nativeMapTemplateV5, nativeUnitTemplateV7, autoMonsterPacketPendingV1
    autoCall := IsObject(autoTarget)
    if (!NativeDispatchReadyV10(autoCall))
    {
        NativeDispatchLogV10(autoCall,"NATIVE_UNIT_BLOCK reason=DISPATCH_NOT_READY")
        return false
    }
    t := {pid:0,player:0,flags:6,source:"VERIFIED_DLL_RIGHT_DOWN_DISPATCH"}
    kind := autoCall ? "AUTO_UNIT" : attackUnit ? "UNIT" : "MAP"
    if (!IsObject(t) || IsObject(autoMonsterPacketPendingV1))
    {
        NativeDispatchLogV10(autoCall,"NATIVE_" . kind . "_SKIP reason=TEMPLATE_NOT_READY_OR_THREAD_BUSY")
        if (!autoCall)
        {
        ToolTipInfoV386("Chưa có mẫu click phù hợp hoặc phép thử trước chưa xong.")
        SetTimer, RemoveToolTip, -3500
        }
        return false
    }
    pid := D2GetActiveGamePidV95()
    if (!pid || (autoCall && pid!=autoTarget.pid) || (t.pid && pid!=t.pid))
        return false
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := DllCall("OpenProcess","UInt",0x043A,"Int",0,"UInt",pid,"Ptr")
    if (!h)
        return false
    remote := 0, owned := false
    try
    {
        if (!NativeRightClickBuildV9(h,base))
        {
            NativeDispatchLogV10(autoCall,"NATIVE_DISPATCH_SKIP reason=DLL_SIGNATURE_MISMATCH")
            return false
        }
        if (!autoCall)
            NativeAttackStateV8(h,base,"BEFORE_CALL")
        player := D2ReadU32(h,base+0x11BBFC)
        if ((t.player && player!=t.player) || !MonsterBossProbeReadV1(h,player,0x64,p))
            return false
        mode := NumGet(p,16,"UInt"), path := NumGet(p,0x2C,"UInt")
        if (mode=0 || mode=17 || !MonsterBossProbeReadV1(h,path,0x20,pb))
            return false
        inv := NumGet(p,0x60,"UInt")
        cursor := inv ? PickupCursorV4(h,inv) : false
        if (!IsObject(cursor) || cursor.unit)
            return false
        px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
        unit := 0, uid := 0
        tx := px+2, ty := py-1
        if (px<1 || py<2 || tx>65535)
            return false
        if (attackUnit)
        {
            if (autoCall)
            {
                if (!MonsterBossProbeReadV1(h,autoTarget.unit,0x30,selected)
                    || NumGet(selected,0,"UInt")!=1 || NumGet(selected,12,"UInt")!=autoTarget.uid
                    || NumGet(selected,16,"UInt")=0 || NumGet(selected,16,"UInt")=12
                    || !MonsterBossProbeReadV1(h,NumGet(selected,0x2C,"UInt"),0x20,selectedPath))
                    return false
                target := {unit:autoTarget.unit,uid:autoTarget.uid,x:NumGet(selectedPath,2,"UShort"),y:NumGet(selectedPath,6,"UShort")}
            }
            else
                target := NativeNearestUnitV7(h,pb)
            if (!IsObject(target))
            {
                NativeDispatchLogV10(autoCall,"NATIVE_UNIT_SKIP reason=NO_LIVE_MONSTER_IN_LOADED_ROOMS")
                if (!autoCall)
                {
                ToolTipInfoV386("Chưa có quái sống gần nhân vật để thử.")
                SetTimer, RemoveToolTip, -3500
                }
                return false
            }
            unit := target.unit, uid := target.uid, tx := target.x, ty := target.y
            if (MonsterClassExcludedV11(D2ReadU32(h,unit+4),h,unit))
                return false
        }
        if (!NativeRightSkillValidV9(h,base,player))
        {
            NativeDispatchLogV10(autoCall,"NATIVE_UNIT_BLOCK reason=RIGHT_SKILL_INVALID")
            return false
        }
        remote := DllCall("VirtualAllocEx","Ptr",h,"Ptr",0,"UPtr",256,"UInt",0x3000,"UInt",0x40,"Ptr")
        if (!remote || remote>0xFFFFFFFF)
            return false
        VarSetCapacity(blob,256,0)
        codeHex := NativeRightClickCodeV9(remote,base,player,autoCall && autoTarget.holdRightV15)
        codeLen := StrLen(codeHex)//2
        if (codeLen>128)
            return false
        Loop, %codeLen%
            NumPut("0x" . SubStr(codeHex,(A_Index-1)*2+1,2),blob,A_Index-1,"UChar")
        NumPut(6,blob,128,"UInt"), NumPut(player,blob,132,"UInt")
        holdMapV16 := autoCall && autoTarget.holdRightV15
        NumPut(holdMapV16 ? 0 : unit,blob,136,"UInt")
        NumPut(tx,blob,140,"UInt"), NumPut(ty,blob,144,"UInt")
        if (!DllCall("WriteProcessMemory","Ptr",h,"Ptr",remote,"Ptr",&blob,"UPtr",256,"UPtrP",written) || written!=256)
            return false
        DllCall("FlushInstructionCache","Ptr",h,"Ptr",remote,"UPtr",codeLen)
        if (D2GetActiveGamePidV95()!=pid || !NativeDispatchReadyV10(autoCall))
            return false
        if (attackUnit)
        {
            if (!MonsterBossProbeReadV1(h,unit,0x30,finalUnit)
                || NumGet(finalUnit,0,"UInt")!=1 || NumGet(finalUnit,12,"UInt")!=uid
                || NumGet(finalUnit,16,"UInt")=0 || NumGet(finalUnit,16,"UInt")=12)
                return false
            if (autoCall)
            {
                livePlayerV239 := D2ReadU32(h,base+0x11BBFC)
                fixedOKV1190 := livePlayerV239 && FarmFixedAttackValidV626(h,livePlayerV239,unit,uid,pid)
                radiusOKV1190 := fixedOKV1190 && ScosAttackRadiusValidV239(h,livePlayerV239,unit,uid)
                boOKV1190 := !BOCommonActiveV444(pid) || (radiusOKV1190 && BOAttackInRadiusV488(h,livePlayerV239,unit,pid))
                if (!fixedOKV1190 || !radiusOKV1190 || !boOKV1190)
                {
                    NativeDispatchLogV10(autoCall,"NATIVE_AUTO_UNIT_GUARD_BLOCK uid=" . uid
                        . " fixed=" . fixedOKV1190 . " radius=" . radiusOKV1190 . " bo=" . boOKV1190)
                    return false
                }
            }
        }
        thread := DllCall("CreateRemoteThread","Ptr",h,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
        if (!thread)
            return false
        autoMonsterPacketPendingV1 := {process:h,remote:remote,thread:thread,uid:uid,kind:kind . "_TEST",dispatchV9:true,autoCall:autoCall,setAt:A_TickCount}
        if (autoCall && autoTarget.holdRightV15)
        {
            autoMonsterPacketPendingV1.holdDownV15 := true
            autoMonsterPacketPendingV1.pid := pid,autoMonsterPacketPendingV1.base := base
            autoMonsterPacketPendingV1.player := player,autoMonsterPacketPendingV1.unit := unit
            autoMonsterPacketPendingV1.birth := BackgroundBirthV63(pid)
        }
        owned := true
        if (autoCall && attackUnit)
            AttackInfoRememberV550(pid,NumGet(finalUnit,4,"UInt"),uid,tx,ty,px,py)
        SetTimer, AutoMonsterPacketCleanupTimerV1, 50
        NativeDispatchLogV10(autoCall,"NATIVE_" . kind . "_TEST_DISPATCH player_map=" . px . "," . py . " target_map=" . tx . "," . ty
            . " target_mode=" . (attackUnit ? 1 : 0) . " uid=" . uid . " unit=" . V92Hex(unit)
            . " flags=6 struct_size=32 down_rva=0x1BC40 up_rva=0x18A00"
            . " method=" . (holdMapV16 ? "RIGHT_HOLD_MAP_AIM" : "D2CLIENT_RIGHT_DOWN_UP")
            . " mouse_moved=0 template_source=" . t.source . " effect=UNCONFIRMED")
        if (!autoCall)
        {
        ToolTipInfoV386(attackUnit ? "Đã gọi đánh thẳng quái 1 lần - ID " . uid : "Đã gọi thử 1 lần tại map (+2,-1). Xem log click phải.")
        SetTimer, RemoveToolTip, -2500
        }
        return true
    }
    finally
    {
        if (!owned)
        {
            NativeDispatchLogV10(autoCall,"NATIVE_" . kind . "_TEST_SKIP reason=VALIDATION_OR_DISPATCH_FAILED error=" . A_LastError)
            if (remote)
                DllCall("VirtualFreeEx","Ptr",h,"Ptr",remote,"UPtr",0,"UInt",0x8000)
            DllCall("CloseHandle","Ptr",h)
        }
    }
}


NativeTestReadyV6()
{
    global autoMonsterAttackOn, zRunning, xRunning, gameItemActionOwner
    reason := !IsGameActive() ? "Chưa ở cửa sổ game" : autoMonsterAttackOn ? "Hãy tắt Tự tìm quái và đánh"
        : (zRunning || xRunning) ? "Đang chạy buff - chờ buff xong" : gameItemActionOwner!="" ? "Đang xử lý vật phẩm - chờ thao tác xong" : ""
    if (reason="")
        return true
    PacketWatchLogV1("NATIVE_TEST_BLOCKED reason=" . reason . " game_active=" . IsGameActive()
        . " auto_attack=" . autoMonsterAttackOn . " z_running=" . zRunning . " x_running=" . xRunning
        . " item_owner=" . gameItemActionOwner)
    ToolTipInfoV386("Chưa bắt đầu dò: " . reason)
    SetTimer, RemoveToolTip, -3500
    return false
}


NativeNearestUnitV7(h, ByRef pb)
{
    px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort"), room := NumGet(pb,0x1C,"UInt")
    if (!room)
        return false
    rooms := MonsterLoadedRoomsV20(h,room), seenRooms := {}, seenUnits := {}
    best := false, bestDist := 0x7FFFFFFF, total := 0, start := A_TickCount
    for _,r in rooms
    {
        if (seenRooms.HasKey(r))
            continue
        seenRooms[r] := true
        u := D2ReadU32(h,r+0x74)
        Loop, 1024
        {
            if (!u || seenUnits.HasKey(u) || total>=2048 || A_TickCount-start>80)
                break
            seenUnits[u] := true, total++
            if (!MonsterBossProbeReadV1(h,u,0xEC,ub))
                break
            next := NumGet(ub,0xE8,"UInt"), mode := NumGet(ub,16,"UInt")
            uid := NumGet(ub,12,"UInt"), path := NumGet(ub,0x2C,"UInt")
            if (NumGet(ub,0,"UInt")=1 && uid && mode!=0 && mode!=12
                && MonsterBossProbeReadV1(h,path,0x20,mb))
            {
                x := NumGet(mb,2,"UShort"), y := NumGet(mb,6,"UShort")
                dist := (x-px)*(x-px)+(y-py)*(y-py)
                if (x>0 && y>0 && dist<bestDist)
                {
                    bestDist := dist
                    best := {unit:u,uid:uid,x:x,y:y}
                }
            }
            u := next
        }
        if (total>=2048 || A_TickCount-start>80)
            break
    }
    return best
}


NativeAttackDumpV8()
{
    global monsterExcludeClassesV11
    pid := D2GetActiveGamePidV95(), base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? DllCall("OpenProcess","UInt",0x0410,"Int",0,"UInt",pid,"Ptr") : 0
    if (!h)
    {
        PacketWatchLogV1("NATIVE_EXPORT_ERROR pid=" . pid . " base=" . V92Hex(base) . " error=" . A_LastError)
        return false
    }
    try
    {
        PacketWatchLogV1("NATIVE_CODE_DUMP_BEGIN pid=" . pid . " base=" . V92Hex(base) . " read_only=1")
        NativeAttackStateV8(h,base,"READ_ONLY_DUMP")
        RoomExportV19(h,base)
        PacketWatchLogV1("NATIVE_EXPORT build_verified=" . NativeRightClickBuildV9(h,base) . " exclusions=" . monsterExcludeClassesV11)
        for _,block in [{rva:0x186A0,size:32},{rva:0x1A010,size:80},{rva:0x1BC40,size:128},{rva:0x18A00,size:192},{rva:0x1A060,size:64},{rva:0x29F30,size:112}]
        {
            ok := MonsterBossProbeReadV1(h,base+block.rva,block.size,code)
            PacketWatchLogV1("NATIVE_CODE rva=" . V92Hex(block.rva) . " bytes=" . (ok ? MonsterBossProbeHexV1(code,block.size) : "READ_FAIL"))
        }
        PacketWatchLogV1("NATIVE_CODE_DUMP_END read_only=1")
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

NativeAttackStateV8(h,base,phase)
{
    player := D2ReadU32(h,base+0x11BBFC)
    ok := player && MonsterBossProbeReadV1(h,player,0xAC,p)
    path := ok ? NumGet(p,0x2C,"UInt") : 0
    info := ok ? NumGet(p,0xA8,"UInt") : 0
    right := info ? D2ReadU32(h,info+12) : 0
    left := info ? D2ReadU32(h,info+8) : 0
    skillRow := right ? D2ReadU32(h,right) : 0
    skillOK := skillRow && MonsterBossProbeReadV1(h,skillRow,2,sid)
    dimsOK := MonsterBossProbeReadV1(h,base+0xDBC48,8,dims)
    mouseOK := MonsterBossProbeReadV1(h,base+0x11B824,8,mouse)
    PacketWatchLogV1("NATIVE_STATE phase=" . phase . " player=" . V92Hex(player) . " unit_read=" . ok
        . " mode=" . (ok ? NumGet(p,16,"UInt") : -1) . " frame=" . (ok ? NumGet(p,0x44,"UInt") : -1)
        . " right_skill_ptr=" . V92Hex(right) . " right_skill_id=" . (skillOK ? NumGet(sid,0,"UShort") : -1)
        . " left_skill_ptr=" . V92Hex(left)
        . " internal_mouse=" . (mouseOK ? NumGet(mouse,4,"Int") . "," . NumGet(mouse,0,"Int") : "READ_FAIL")
        . " game_size=" . (dimsOK ? NumGet(dims,0,"UInt") . "," . NumGet(dims,4,"UInt") : "READ_FAIL")
        . " path=" . V92Hex(path))
}

NativeRightClickBuildV9(h,base)
{
    if (!NativeAttackBuildV5(h,base))
        return false
    if (!MonsterBossProbeReadV1(h,base+0x1BC40,15,down)
        || MonsterBossProbeHexV1(down,15)!="8BCEE899C9FFFF85C0746D8B460450")
        return false
    if (!MonsterBossProbeReadV1(h,base+0x18A00,8,up)
        || MonsterBossProbeHexV1(up,8)!="5356E8D9FBFFFF8B")
        return false
    return true
}

NativeRightSkillValidV9(h,base,player)
{
    info := D2ReadU32(h,player+0xA8)
    skill := info ? D2ReadU32(h,info+12) : 0
    row := skill ? D2ReadU32(h,skill) : 0
    if (!row || !MonsterBossProbeReadV1(h,row,2,skillIdBytes))
    {
        PacketWatchLogV1("NATIVE_DISPATCH_SKIP reason=NO_RIGHT_SKILL")
        return false
    }
    id := NumGet(skillIdBytes,0,"UShort")
    tablesRef := D2ReadU32(h,base+0xCE474)
    tables := tablesRef ? D2ReadU32(h,tablesRef) : 0
    count := tables ? D2ReadU32(h,tables+0xBA0) : 0
    rows := tables ? D2ReadU32(h,tables+0xB98) : 0
    if (!rows || count<1 || count>65536 || id>=count)
    {
        PacketWatchLogV1("NATIVE_DISPATCH_SKIP reason=INVALID_RIGHT_SKILL_TABLE id=" . id . " count=" . count)
        return false
    }
    return true
}

NativeRightClickCodeV9(remote,base,player,holdOnly := false)
{
    hex := "60BE" . NativeLE32V9(player) . "B8" . NativeLE32V9(base+0x29F30) . "FFD0A3" . NativeLE32V9(remote+212)
    hex .= "BE" . NativeLE32V9(remote+128) . "B8" . NativeLE32V9(base+0x1BC40) . "FFD0A3" . NativeLE32V9(remote+192)
    hex .= "8B16" . "8915" . NativeLE32V9(remote+200)
    hex .= "8B5608" . "8915" . NativeLE32V9(remote+204)
    hex .= "8B561C" . "8915" . NativeLE32V9(remote+208)
    if (holdOnly)
        return hex . "6131C0C20400"
    hex .= "B9" . NativeLE32V9(remote+128) . "C70112000000"
    hex .= "C705" . NativeLE32V9(base+0x11C2F8) . "00000000"
    hex .= "C705" . NativeLE32V9(base+0x11C2F4) . "00000000"
    hex .= "B8" . NativeLE32V9(base+0x18A00) . "FFD0A3" . NativeLE32V9(remote+196)
    hex .= "6131C0C20400"
    return hex
}

NativeLE32V9(value)
{
    out := ""
    Loop, 4
        out .= Format("{:02X}",(value>>((A_Index-1)*8)) & 255)
    return out
}

NativeDispatchReadyV10(autoCall := false)
{
    global autoMonsterAttackOn, packetWatchArmedV1, zRunning, xRunning, gameItemActionOwner, petLearnOnV12,buffSequenceOnV555
    if (!autoCall)
        return NativeTestReadyV6()
    return (autoMonsterAttackOn || buffSequenceOnV555 || CycCombatReadyV42() || ScosEntryBuffReadyV233(D2GetActiveGamePidV95()))
        && !petLearnOnV12 && IsGameActive() && !packetWatchArmedV1
        && !zRunning && !xRunning && gameItemActionOwner=""
}

NativeDispatchLogV10(autoCall,message)
{
    if (autoCall)
        AutoMonsterAttackLogV2(message)
    else
        PacketWatchLogV1(message)
}

PortalCastNormalizeV50(key)
{
    key := NormalizeOptionalKey(key)
    if (key="M3" || key="Mouse3")
        return "MButton"
    return key
}

CoordCastMarkV50(row)
{
    global roomExploreV89
    if (IsObject(roomExploreV89))
        return false
    global coordCastCountV50, coordCastPendingV50, coordCastLastRowV50, portalCastEveryV52, lastAttackPendingV20, pestiPointPendingV28
    if (row=coordCastLastRowV50)
        return
    coordCastLastRowV50 := row
    pestiPointPendingV28 := true
    lastAttackPendingV20 := true
    coordCastCountV50++
    if (coordCastCountV50>=portalCastEveryV52)
        coordCastPendingV50 := true, coordCastCountV50 := 0
}

PortalExitCancelV69()
{
    global portalExitPendingV69
    portalExitPendingV69 := false
}

PortalExitStartV69(h,player,pid)
{
    global portalExitPendingV69,townLevelV22
    portalExitPendingV69 := false
    path := D2ReadU32(h,player+0x2C)
    if (!MonsterBossProbeReadV1(h,path,0x20,pb))
        return false
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    return level && level!=townLevelV22
}

PortalExitTickV69(h,player,ByRef pb,pid)
{
    global portalExitPendingV69
    portalExitPendingV69 := false
    return false
}

PortalBackReadyV74(h,player,pid)
{
    global portalBackPendingV74
    portalBackPendingV74 := false
    return true
}

CoordCastTickV50(h,player,pid,roomClearV97 := false)
{
    if (CainIntermediateMapV370(pid))
        return false
    global roomExploreV89

    if (IsObject(roomExploreV89) && !roomClearV97)
        return false
    global farmLastCombatTickV72, monsterCombatUidV45, combatRecoverV48,combatMildRecoverV299, portalBackPendingV74
    global coordCastPendingV50, coordCastLastRowV50, portalCastKeyV50, portalCastEveryV52, reviveBuffPendingV34, deathlordRetryAtV31
    global portalBuffV85, coordRouteV16, portalBuffDeferredV998, farmCenterCycleV741
    global pestiPointPendingV28, lastAttackPendingV20
    if (!coordCastPendingV50)
    {
        portalBackPendingV74 := false
        return false
    }
    ; V1002: cac timer scan khong duoc mo cong som o diem N khi dang quet danh.
    if (IsObject(farmCenterCycleV741) && farmCenterCycleV741.pid=pid
        && farmCenterCycleV741.route=coordRouteV16
        && coordCastLastRowV50=farmCenterCycleV741.row
        && farmCenterCycleV741.phase!="PORTAL_CAST")
        return false
    if (monsterCombatUidV45 || IsObject(combatRecoverV48) || A_TickCount-farmLastCombatTickV72<1500)
    {
        if (roomClearV97)
            AutoMonsterAttackLogV2("ROOM_PORTAL_WAIT reason=COMBAT_OR_QUIET_DELAY uid=" . monsterCombatUidV45
                . " recovery=" . IsObject(combatRecoverV48) . " quiet_ms=" . (A_TickCount-farmLastCombatTickV72),true)
        return false
    }
    if (portalCastKeyV50="")
    {
        if (roomClearV97)
            AutoMonsterAttackLogV2("ROOM_PORTAL_SKIP reason=PORTAL_KEY_EMPTY")
        coordCastPendingV50 := false, portalBackPendingV74 := false
        return false
    }
    if (!NativeDispatchReadyV10(true) || D2GetActiveGamePidV95()!=pid || !AutoMonsterPacketCleanupV1())
        return false
    mode := D2ReadU32(h,player+0x10)
    if (mode!=1 && mode!=5)
        return false
    if (!PortalBackReadyV74(h,player,pid))
        return true
    if (!PortalExitStartV69(h,player,pid))
        return false
    if (!BuffCheckedSendV29(portalCastKeyV50))
    {
        PortalExitCancelV69()
        return true
    }
    portalBackPendingV74 := false
    ; V998: voi luong B->C, diem N chi MO CONG, KHONG BUFF.
    ; De buff den N+1 sau khi luong chinh xac nhan quet danh xong.
    deferBuffV998 := IsObject(farmCenterCycleV741) && farmCenterCycleV741.pid=pid
        && farmCenterCycleV741.route=coordRouteV16 && farmCenterCycleV741.phase="PORTAL_CAST"
    if (deferBuffV998)
    {
        portalBuffDeferredV998 := {pid:pid,route:coordRouteV16,epoch:farmCenterCycleV741.epoch
            ,fromRow:farmCenterCycleV741.row,row:farmCenterCycleV741.row+1}
        ; Khong de StateBuffTick buff qua co pending cu ngay tai diem mo cong.
        pestiPointPendingV28 := false,lastAttackPendingV20 := false
        PortalLogWriteV66("ROUTE_PORTAL_CAST key=" . portalCastKeyV50
            . " row=" . farmCenterCycleV741.row . " after=COMBAT_CLEAR next=ROUTE_BUFF_AT_ROW_" . portalBuffDeferredV998.row)
    }
    else
    {
        ; Cac luong khac giu nguyen hanh vi mo cong + buff cu.
        portalBuffV85 := {pid:pid,route:coordRouteV16,phase:"FORM1",startTickV1301:A_TickCount}
        PortalLogWriteV66("ROUTE_PORTAL_CAST key=" . portalCastKeyV50
            . " combat_quiet_ms=" . (A_TickCount-farmLastCombatTickV72) . " next=BUFF_AT_CURRENT_COORDINATE")
    }
    coordCastPendingV50 := false
    reviveBuffPendingV34 := false
    deathlordRetryAtV31 := 0
    AutoMonsterAttackLogV2("ROUTE_CAST_KEY key=" . portalCastKeyV50 . " every_saved_points=" . portalCastEveryV52 . " presses=1 effect=UNCONFIRMED")
    return true
}


FarmStuckCombatProgressV247()
{
    global coordRouteV16
    FarmWatchProgressV5()
    if (IsObject(coordRouteV16))
        coordRouteV16.standProbeV246 := false
}

FarmStandResetTickV246(x,y,level,pid)
{
    FarmWatchObserveV5(pid,level,x,y)
    return false
}

FarmScanLimitChangedV771:
GuiControlGet, liveFarmScanLimitV771,, FarmScanLimitInputV771
if (RegExMatch(liveFarmScanLimitV771,"^\d+$") && liveFarmScanLimitV771>=1 && liveFarmScanLimitV771<=999)
    farmScanLimitV771 := liveFarmScanLimitV771+0
return

MonsterRadiusChangedV239:
MonsterRadiusGetV239()
return

MonsterRadiusGetV239()
{
    global monsterRadiusV48
    GuiControlGet, visibleRadiusV239,, MonsterRadiusInputV48
    if (RegExMatch(visibleRadiusV239,"^\d+$") && visibleRadiusV239>=1 && visibleRadiusV239<=200)
        monsterRadiusV48 := visibleRadiusV239+0
    return monsterRadiusV48
}

; Gia tri BK tam cu duoc giu ngam cho cac profile/luong ngoai B->C.
; Khong con edit BK tam tren GUI: o hien tai la BK quet doc lap.
ItemCenterRadiusGetV810()
{
    global itemCenterRadiusV810
    return Max(1, Min(200, itemCenterRadiusV810+0))
}

PickupFailTeleRadiusGetV1253()
{
    global pickupFailTeleRadiusV1253
    if (ProfileControlExistsV365("PickupFailTeleRadiusInputV1253"))
    {
        GuiControlGet, radiusFromGuiV1253, 1:, PickupFailTeleRadiusInputV1253
        if (RegExMatch(radiusFromGuiV1253,"^\d+$") && radiusFromGuiV1253>=1 && radiusFromGuiV1253<=100)
            pickupFailTeleRadiusV1253 := radiusFromGuiV1253+0
    }
    return Max(1,Min(100,pickupFailTeleRadiusV1253+0))
}

PickupScanRadiusGetV810()
{
    global pickupScanRadiusV810
    GuiControlGet, scanRadiusInputV810, 1:, PickupScanRadiusInputV810
    if (RegExMatch(scanRadiusInputV810,"^\d+$") && scanRadiusInputV810>=1 && scanRadiusInputV810<=400)
        pickupScanRadiusV810 := scanRadiusInputV810+0
    return Max(1, Min(400, pickupScanRadiusV810+0))
}

MoveDelayGetV810()
{
    global moveDelayMsV810, MoveDelayInputV810
    GuiControlGet, tempMoveDelayV810,, MoveDelayInputV810
    if (RegExMatch(tempMoveDelayV810, "^\d+$") && tempMoveDelayV810>=0 && tempMoveDelayV810<=5000)
        moveDelayMsV810 := tempMoveDelayV810+0
    return Max(0, Min(5000, moveDelayMsV810+0))
}

MoveDelayChangedV810:
moveDelayMsV810 := MoveDelayGetV810()
moveDelaySectionV810 := ProfileSection(currentProfile)
IniWrite, %moveDelayMsV810%, % ProfileConfigPathV364(moveDelaySectionV810), %moveDelaySectionV810%, MoveDelayMs
return

MonsterScanRadiusV20(level)
{
    global farmControlOwnerV186
    baseRadius := MonsterRadiusGetV239()
    return !BOCommonActiveV444() && !BOFinalRouteActiveV451() && CainHuntActiveV403() && level=CainHuntLevelV422() ? baseRadius*2 : baseRadius
}

ScosCoordRadiusAreaV240(px,py,level)
{
    global coordRouteV16
    radius := MonsterRadiusGetV239()
    row := IsObject(coordRouteV16) ? coordRouteV16.yellow : 0
    valid := px>0 && py>0 && level=270
    return {x:px,y:py,radiusSq:valid ? radius*radius : 0,radius:radius,row:row
        ,valid:valid,source:"PLAYER_RADIUS"}
}

FarmRouteCombatAreaV627(pid,player,level)
{
    routePointsV724 := FarmRoutePointsV724()
    global coordRouteV16,farmFightLockV626
    r := coordRouteV16,count := routePointsV724.Length()
    if (!IsObject(r) || !count || r.pid!=pid || r.startLevel!=level)
    {
        farmFightLockV626 := false
        return false
    }
    if (!r.combatRowV627)
    {
        row := r.yellow>=1 && r.yellow<=count ? r.yellow : r.next
        if (row<1 || row>count || routePointsV724[row].level!=level)
            return false
        r.combatRowV627 := row
    }
    row := r.combatRowV627
    if (row>count)
    {
        farmFightLockV626 := false
        return {x:0,y:0,radiusSq:0,source:"SAVED_ROUTE_CLEARED",row:0}
    }
    point := routePointsV724[row]
    if (point.level!=level)
        return {x:0,y:0,radiusSq:0,source:"SAVED_ROUTE_MAP_MISMATCH",row:0}
    if (!IsObject(farmFightLockV626) || farmFightLockV626.routeV627!=r
        || farmFightLockV626.row!=row || farmFightLockV626.x!=point.x || farmFightLockV626.y!=point.y)
    {
        radius := MonsterScanRadiusV20(level)
        farmFightLockV626 := {pid:pid,player:player,level:level,x:point.x,y:point.y
            ,radiusSq:radius*radius,source:"SAVED_ROUTE_COMBAT_CENTER",row:row,routeV627:r}
        r.anchor := row-1,r.next := row,r.phase := "NEXT",r.forwardFloorV303 := row-1
        AutoMonsterAttackLogV2("COMBAT_ROUTE_CENTER row=" . row . " center=" . point.x . "," . point.y . " radius=" . radius)
    }
    return farmFightLockV626
}

FarmRouteCombatClearV627(h,player,pid,ByRef pb)
{
    routePointsV724 := FarmRoutePointsV724()
    global coordRouteV16,farmFightLockV626,monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44
    global coordNoTargetSinceV14,coordCastCountV50,coordCastLastRowV50,coordCastPendingV50
    global portalCastEveryV52,portalCastKeyV50,portalBuffV85,roomExploreV89
    r := coordRouteV16,c := farmFightLockV626
    if (!IsObject(r) || !IsObject(c) || c.pid!=pid || c.routeV627!=r || c.row!=r.combatRowV627)
        return false
    distance := (NumGet(pb,2,"UShort")-c.x)**2+(NumGet(pb,6,"UShort")-c.y)**2
    last := c.row=routePointsV724.Length()
    if (distance>25)
        return false
    portalRow := coordCastLastRowV50!=c.row && coordCastCountV50+1>=Max(1,portalCastEveryV52)
        && portalCastKeyV50!="" && !IsObject(roomExploreV89) && !CainIntermediateMapV370(pid)
    if (portalRow && distance>25)
        return false
    AutoMonsterPacketCleanupV1()
    monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
    if (!IsObject(roomExploreV89) && !CainIntermediateMapV370(pid))
    {
        CoordCastMarkV50(c.row)
        if (coordCastPendingV50)
        {
            CoordCastTickV50(h,player,pid)
            if (coordCastPendingV50 || IsObject(portalBuffV85))
                return true
        }
    }
    r.anchor := c.row,r.yellow := c.row,r.combatRowV627 := c.row+1,r.next := c.row+1
    r.phase := last ? "DONE" : "NEXT",r.forwardFloorV303 := r.anchor
    r.battlePending := false,r.lastDispatch := 0,r.legRow := 0,r.firstMoveAttempted := false
    r.escapeV84 := false,r.stuckProbe := false,r.bypass := false
    coordNoTargetSinceV14 := A_TickCount-250
    farmFightLockV626 := false
    AutoMonsterAttackLogV2("COMBAT_ROUTE_CLEARED row=" . c.row . " next=" . (last ? "DONE" : r.next))
    CoordBoxRefreshV15()
    return !last
}

FarmFixedAttackValidV626(h,player,unit,uid,pid)
{
    global farmItemLockV625,farmFightLockV626,farmApproachV722,autoMonsterAttackOn,farmCenterCycleV741
    itemGuardV750 := IsObject(farmItemLockV625) && farmItemLockV625.pid=pid && farmItemLockV625.player=player
    if (!itemGuardV750 && FarmCenterPolicyV741(pid))
    {
        if (!FarmCenterPendingV741(pid))
            return FarmPlayerTargetValidV741(h,player,unit,uid,pid)
        c := farmCenterCycleV741
        if (c.phase="ATTACK_FIRST" || c.phase="ATTACK_MORE" || c.phase="ATTACK"
            || c.phase="ROAD_ATTACK")
        {
            ; Khi danh quai can duong, Form6 phai kiem tra dung BK nhan vat
            ; da khoa, khong duoc loai muc tieu vi nam ngoai BK diem cu.
            roadV2026 := c.phase="ROAD_ATTACK"
                || (c.phase="ATTACK" && c.dispatchOriginV1190="ROAD_ATTACK")
            area := {pid:pid,player:player,level:c.level
                ,x:(roadV2026 ? c.roadX_V2026 : c.x)
                ,y:(roadV2026 ? c.roadY_V2026 : c.y)
                ,radiusSq:Max(1,MonsterRadiusGetV239())**2}
        }
        else
            return false
    }
    else
        area := IsObject(farmItemLockV625) ? farmItemLockV625 : farmFightLockV626
    if (!IsObject(area) || area.pid!=pid || area.player!=player)
        return true
    if (!MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,pp)
        || !MonsterBossProbeReadV1(h,unit,0x30,ub) || NumGet(ub,0,"UInt")!=1 || NumGet(ub,12,"UInt")!=uid
        || !MonsterBossProbeReadV1(h,NumGet(ub,0x2C,"UInt"),0x20,mp))
        return false
    if (CoordLevelV14(h,NumGet(pp,0x1C,"UInt"))!=area.level)
        return true
    if (!itemGuardV750 && autoMonsterAttackOn && Stage2FightEnabledV9() && IsObject(farmApproachV722)
        && farmApproachV722.pid=pid && farmApproachV722.player=player && farmApproachV722.level=area.level
        && A_TickCount-farmApproachV722.at<500 && CoordLevelV14(h,NumGet(mp,0x1C,"UInt"))=area.level
        && (NumGet(mp,2,"UShort")-NumGet(pp,2,"UShort"))**2+(NumGet(mp,6,"UShort")-NumGet(pp,6,"UShort"))**2<=farmApproachV722.radiusSq)
        return true
    return CoordLevelV14(h,NumGet(mp,0x1C,"UInt"))=area.level
        && MonsterInsideAreaV48(NumGet(mp,2,"UShort"),NumGet(mp,6,"UShort"),area)
}

ScosAttackRadiusValidV239(h,player,unit,uid)
{
    global monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44,farmCombatAreaV590,monsterRadiusV48
    global farmApproachV722,autoMonsterAttackOn
    playerPath := D2ReadU32(h,player+0x2C)
    if (!MonsterBossProbeReadV1(h,playerPath,0x20,pp))
        return false
    level := CoordLevelV14(h,NumGet(pp,0x1C,"UInt"))
    if (!level)
        return false
    if (level!=270 || BossSearchActiveV430(D2GetActiveGamePidV95(),level))
        return true
    if (!MonsterBossProbeReadV1(h,unit,0x30,u) || NumGet(u,0,"UInt")!=1 || NumGet(u,12,"UInt")!=uid
        || NumGet(u,16,"UInt")=0 || NumGet(u,16,"UInt")=12
        || !MonsterBossProbeReadV1(h,NumGet(u,0x2C,"UInt"),0x20,mp))
        return false
    px := NumGet(pp,2,"UShort"),py := NumGet(pp,6,"UShort")
    mx := NumGet(mp,2,"UShort"),my := NumGet(mp,6,"UShort")
    area := IsObject(farmCombatAreaV590) && farmCombatAreaV590.pid=D2GetActiveGamePidV95()
        && farmCombatAreaV590.level=level ? farmCombatAreaV590.area : ScosCoordRadiusAreaV240(px,py,level)
    radius := Sqrt(area.radiusSq)
    distCenterSq := (mx-area.x)**2+(my-area.y)**2
    distPlayerSq := (mx-px)**2+(my-py)**2
    targetLevel := CoordLevelV14(h,NumGet(mp,0x1C,"UInt"))
    stuckZoneV243 := MonsterStuckZoneExcludedV243(uid,mx,my,targetLevel,D2GetActiveGamePidV95())
    bkSq := Max(1,monsterRadiusV48)**2
    inCenterRadius := targetLevel=level && area.radiusSq>0 && distCenterSq<=area.radiusSq
    inPlayerRadius := distPlayerSq <= bkSq
    closeV722 := autoMonsterAttackOn && Stage2FightEnabledV9() && IsObject(farmApproachV722)
        && farmApproachV722.pid=D2GetActiveGamePidV95() && farmApproachV722.player=player
        && farmApproachV722.level=level && A_TickCount-farmApproachV722.at<500
        && targetLevel=level && distPlayerSq<=farmApproachV722.radiusSq
    global farmItemLockV625
    itemGuardV750 := IsObject(farmItemLockV625) && farmItemLockV625.pid=D2GetActiveGamePidV95()
        && farmItemLockV625.player=player && farmItemLockV625.level=level
    if (itemGuardV750 && !FarmCenterPolicyV741(D2GetActiveGamePidV95(),level))
        ok := targetLevel=level && MonsterInsideAreaV48(mx,my,farmItemLockV625) && !stuckZoneV243
    else if (FarmCenterPolicyV741(D2GetActiveGamePidV95(),level))
        ok := targetLevel=level && inCenterRadius && !stuckZoneV243
    else
        ok := (inCenterRadius || closeV722) && inPlayerRadius && !stuckZoneV243
    if (!ok && monsterCombatUidV45=uid)
        monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
    result := ok ? "ALLOW"
        : !inCenterRadius ? "BLOCK_OUTSIDE_CENTER_RADIUS"
        : !inPlayerRadius ? "BLOCK_FAR_FROM_PLAYER"
        : stuckZoneV243 ? "BLOCK_STUCK_ZONE" : "BLOCK_OTHER"
    PortalLogWriteV66("SCOS_ATTACK_RADIUS_CHECK uid=" . uid . " center=" . area.x . "," . area.y . " coord_row=" . area.row
        . " player=" . px . "," . py . " target=" . mx . "," . my
        . " dist_center=" . Round(Sqrt(distCenterSq),2) . " dist_player=" . Round(Sqrt(distPlayerSq),2)
        . " center_radius=" . radius . " player_radius=" . Sqrt(bkSq)
        . " target_level=" . targetLevel . " result=" . result,"SCOS_RADIUS_" . uid,1000)
    return ok
}

MonsterAttackAreaV48(h,ByRef pb)
{
    routePointsV724 := FarmRoutePointsV724()
    global roomExploreV89,monsterRadiusV48
    if (BOCommonActiveV444())
    {
        return BOCombatAreaV447(pb)
    }
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    global farmItemLockV625,farmFightLockV626
    if (IsObject(farmItemLockV625) && farmItemLockV625.pid=D2GetActiveGamePidV95() && farmItemLockV625.level=level)
        return farmItemLockV625
    if (IsObject(farmFightLockV626) && farmFightLockV626.pid=D2GetActiveGamePidV95() && farmFightLockV626.level=level)
        return farmFightLockV626
    scanRadiusV20 := MonsterScanRadiusV20(level)
    if (level=270)
        return ScosCoordRadiusAreaV240(NumGet(pb,2,"UShort"),NumGet(pb,6,"UShort"),level)
    if (IsObject(roomExploreV89))
        return {x:NumGet(pb,2,"UShort"),y:NumGet(pb,6,"UShort"),radiusSq:scanRadiusV20*scanRadiusV20,source:"ROOM_TEST_RADIUS",row:0}
    global coordRouteV16,monsterRadiusV48,monsterCombatUidV45,monsterRoadAreaV51
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    r := coordRouteV16
    if (IsObject(r) && r.phase="DONE")
        return {x:NumGet(pb,2,"UShort"),y:NumGet(pb,6,"UShort"),radiusSq:8589672450,source:"FREE_LOADED_MAP",row:0}
    if (IsObject(r) && r.phase="NEXT")
{
    idx := r.next
    if (idx>=1 && idx<=routePointsV724.Length())
    {
        p := routePointsV724[idx]
        if (p.level=level)
            return {x:NumGet(pb,2,"UShort"),y:NumGet(pb,6,"UShort")
                ,radiusSq:scanRadiusV20*scanRadiusV20,source:"ROAD_PLAYER_CENTER",row:idx}
    }
    return {x:0,y:0,radiusSq:0,source:"NO_ROUTE_DESTINATION",row:0}
}
    if (IsObject(r))
    {
        idx := r.anchor
        if (!idx)
            idx := r.next
        if (idx>=1 && idx<=routePointsV724.Length())
        {
            p := routePointsV724[idx]
            if (p.level=level)
                return {x:p.x,y:p.y,radiusSq:scanRadiusV20*scanRadiusV20,source:"SAVED_COORDINATE",row:idx+1}
        }
    }
    return {x:0,y:0,radiusSq:0,source:"NO_SAVED_COORDINATE",row:0}
}

MonsterInsideAreaV48(x,y,area)
{
    if (!IsObject(area))
        return true
    return (x-area.x)*(x-area.x)+(y-area.y)*(y-area.y)<=area.radiusSq
}


CombatRetreatPointV62(h,ByRef pb,target,turn := 0)
{
    routePointsV724 := FarmRoutePointsV724()
    global coordRouteV16,goalDetourV14,monsterRadiusV48,monsterExcludeClassesV11
    step := MapMoveDistanceGetV51()
    if (!step)
        return false
    px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
    room := NumGet(pb,0x1C,"UInt")
    level := CoordLevelV14(h,room)
    if (!room || !level)
        return false

    sumDx := 0, sumDy := 0, count := 0
    seen := {}
    radiusSq := monsterRadiusV48 * monsterRadiusV48
    for _, r in MonsterLoadedRoomsV20(h, room)
    {
        u := D2ReadU32(h, r+0x74)
        Loop, 1024
        {
            if (!u || seen.HasKey(u))
                break
            seen[u] := true
            if (D2ReadU32(h,u)=1)
            {
                mode := D2ReadU32(h,u+0x10)
                cls := D2ReadU32(h,u+4)
                uid := D2ReadU32(h,u+0x0C)
                if (mode!=0 && mode!=12 && uid && !MonsterClassExcludedV11(cls,h,u))
                {
                    mpath := D2ReadU32(h,u+0x2C)
                    if (MonsterBossProbeReadV1(h,mpath,0x20,mb))
                    {
                        mx := NumGet(mb,2,"UShort")
                        my := NumGet(mb,6,"UShort")
                        mlevel := CoordLevelV14(h,NumGet(mb,0x1C,"UInt"))
                        if (mlevel = level)
                        {
                            dSq := (mx-px)**2 + (my-py)**2
                            if (dSq <= radiusSq)
                            {
                                d := Sqrt(dSq)
                                if (d > 0)
                                {
                                    sumDx += (px-mx)/d
                                    sumDy += (py-my)/d
                                    count++
                                }
                            }
                        }
                    }
                }
            }
            nx := D2ReadU32(h,u+0xE8)
            if (nx=u)
                break
            u := nx
        }
    }

    dx := 0, dy := 0
    if (count > 0)
    {
        len := Sqrt(sumDx*sumDx + sumDy*sumDy)
        if (len > 0.001)
        {
            dx := sumDx / len
            dy := sumDy / len
        }
    }
    if (!dx && !dy)
    {
        if (IsObject(target) && MonsterBossProbeReadV1(h,target.path,0x20,tb))
        {
            dx := px-NumGet(tb,2,"UShort")
            dy := py-NumGet(tb,6,"UShort")
        }
        if (!dx && !dy)
            dx := 1
    }
    if (turn)
    {
        oldDx := dx
        dx := turn>0 ? -dy : dy
        dy := turn>0 ? oldDx : -oldDx
    }
    length := Sqrt(dx*dx+dy*dy)
    if (length < 0.001)
        length := 1
    tx := Max(1,Min(65535,Round(px+step*dx/length)))
    ty := Max(1,Min(65535,Round(py+step*dy/length)))
    area := MonsterAttackAreaV48(h,pb)
    if (IsObject(area) && area.radiusSq>0 && area.source!="FREE_LOADED_MAP")
    {
        bound := Sqrt(area.radiusSq)*0.85
        gx := tx-area.x, gy := ty-area.y, goalDist := Sqrt(gx*gx+gy*gy)
        if (goalDist>bound)
        tx := Round(area.x+gx*bound/goalDist), ty := Round(area.y+gy*bound/goalDist)
        if ((tx-px)*(tx-px)+(ty-py)*(ty-py)<4)
        tx := Round(area.x-dy*bound/length), ty := Round(area.y+dx*bound/length)
        if (!MonsterInsideAreaV48(tx,ty,area))
        tx := area.x, ty := area.y
    }
    if (IsObject(coordRouteV16) && coordRouteV16.phase="NEXT" && coordRouteV16.next>=1
        && coordRouteV16.next<=routePointsV724.Length() && coordRouteV16.closestGoalDistance>=0)
    {
        goal := routePointsV724[coordRouteV16.next]
        bound := coordRouteV16.closestGoalDistance+goalDetourV14
        gx := tx-goal.x, gy := ty-goal.y, retreatDist := Sqrt(gx*gx+gy*gy)
        if (retreatDist>bound && retreatDist>0)
        tx := Round(goal.x+gx*bound/retreatDist), ty := Round(goal.y+gy*bound/retreatDist)
    }
    return {x:tx,y:ty}
}

CombatLowHPAlternateV299(h,ByRef pb,pid,target)
{
    global roomExploreV89
    global combatMildRecoverV299, potHPThreshold, monsterCombatUidV45, monsterChaseV44,monsterLockUntilDeadV145
    if (!IsObject(combatMildRecoverV299) && !IsObject(target) && !monsterCombatUidV45)
        return false
    lifePlayerV305 := D2ReadU32(h,D2GetModuleBaseV35(pid,"D2Client.dll")+0x11BBFC)
    lifeV305 := MonsterBossProbeHPV2(h,D2ReadU32(h,lifePlayerV305+0x5C))
    hp := lifeV305.ok ? lifeV305.hp : D2GetCurrentHPV1()
    fullEnoughV305 := lifeV305.ok && lifeV305.maxraw>0 && lifeV305.raw>=lifeV305.maxraw*0.9
    PortalLogWriteV66("FARM_HP_DECISION branch=ALTERNATE hp=" . hp . " max=" . lifeV305.maxhp
        . " verified=" . lifeV305.ok . " threshold1=" . potHPThreshold
        . " band=" . CombatHPBandV305(hp,fullEnoughV305) . " full90=" . fullEnoughV305,"FARM_HP_ALTERNATE",1000)
    if (hp=0)
        return true
    if (hp<0 && !IsObject(combatMildRecoverV299))
        return false
    if (CombatHPBandV305(hp,fullEnoughV305)="NORMAL")
    {
        combatMildRecoverV299 := false
        return false
    }
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
    if (!level)
        return true
    if (!IsObject(combatMildRecoverV299) || combatMildRecoverV299.level!=level)
        combatMildRecoverV299 := {phase:"ATTACK",level:level,last:0,turn:0,lastX:px,lastY:py,stuck:0,attackWait:0}
    r := combatMildRecoverV299
    if (!NativeDispatchReadyV10(true) || D2GetActiveGamePidV95()!=pid || !AutoMonsterPacketCleanupV1()
        || (r.last && A_TickCount-r.last<250))
        return true
    if (r.phase="ATTACK" && IsObject(target))
    {
        if (!MonsterBossProbeReadV1(h,target.unit,0x30,ub))
            return true
        mode := NumGet(ub,0x10,"UInt")
        if (NumGet(ub,0,"UInt")!=1 || NumGet(ub,0x0C,"UInt")!=target.uid || mode=0 || mode=12)
            r.phase := "MOVE"
        else
        {
            if (target.level=270)
            {
                targetHPV243 := MonsterBossProbeHPV2(h,D2ReadU32(h,target.unit+0x5C))
                if (!MonsterChaseProgressV44(target.uid,px,py,target.dist,targetHPV243.ok ? targetHPV243.raw : -1
                    ,target.x,target.y,target.level,pid,h,target.unit))
                {
                    monsterCombatUidV45 := 0
                    r.phase := "MOVE",r.last := 0
                    return true
                }
            }
            player := D2ReadU32(h,D2GetModuleBaseV35(pid,"D2Client.dll")+0x11BBFC)
            if (AutoMonsterPacketSendV1(pid,target.unit,target.uid))
            {
                monsterCombatUidV45 := MonsterLockEligibleV308(NumGet(ub,4,"UInt")) ? target.uid : 0
                if (target.level=270 && IsObject(monsterChaseV44) && monsterChaseV44.uid=target.uid)
                {
                    if (!monsterChaseV44.since)
                        monsterChaseV44.since := A_TickCount
                    monsterChaseV44.queued++
                }
                else
                    monsterChaseV44 := false
                r.phase := "MOVE", r.last := A_TickCount, r.attackWait := 0
                AutoMonsterAttackLogV2("LOW_HP_ATTACK_ONCE uid=" . target.uid . " next=EVADE hp=" . hp)
                return true
            }
            else
            {
                if (!r.attackWait)
                    r.attackWait := A_TickCount
                if (A_TickCount-r.attackWait>=1000)
                    r.phase := "MOVE", r.attackWait := 0
            }
            if (r.phase!="MOVE")
                return true
        }
    }
    if (px=r.lastX && py=r.lastY)
        r.stuck++
    else
        r.stuck := 0, r.turn := 0
    if (r.stuck>=3)
        r.turn := r.turn=1 ? -1 : 1, r.stuck := 0
    point := CombatRetreatPointV62(h,pb,target,r.turn)
    if (!IsObject(point))
        return true
    if (NativeMovePointV14(pid,point.x,point.y,level))
    {
        r.lastX := px, r.lastY := py, r.last := A_TickCount, r.phase := "ATTACK"
        AutoMonsterAttackLogV2("LOW_HP_EVADE_ONCE destination=" . point.x . "," . point.y . " next=ATTACK hp=" . hp)
    }
    return true
}

CombatRecoverScanV298(h,ByRef pb)
{
    global monsterRadiusV48
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    radius := Max(1,monsterRadiusV48),seen := {},count := 0,started := A_TickCount
    result := {count:0,complete:true,dx:0,dy:0,nearest:false,radius:radius}
    for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
    {
        u := D2ReadU32(h,room+0x74)
        Loop, 1024
        {
            if (!u || seen.HasKey(u))
                break
            if (count>=2048 || A_TickCount-started>80)
            {
                result.complete := false
                return result
            }
            seen[u] := true,count++
            if (!MonsterBossProbeReadV1(h,u,0xEC,ub))
            {
                result.complete := false
                break
            }
            next := NumGet(ub,0xE8,"UInt"),mode := NumGet(ub,0x10,"UInt")
            if (NumGet(ub,0,"UInt")=1 && mode!=0 && mode!=12
                && !MonsterClassExcludedV11(NumGet(ub,4,"UInt"),h,u))
            {
                path := NumGet(ub,0x2C,"UInt")
                if (!MonsterBossProbeReadV1(h,path,0x20,mb))
                    result.complete := false
                else if (CoordLevelV14(h,NumGet(mb,0x1C,"UInt"))=level)
                {
                    x := NumGet(mb,2,"UShort"),y := NumGet(mb,6,"UShort")
                    dx := px-x,dy := py-y,dist := dx*dx+dy*dy
                    if (dist<=radius*radius)
                    {
                        result.count++
                        weight := Max(1,dist)
                        result.dx += dx/weight,result.dy += dy/weight
                        if (!IsObject(result.nearest) || dist<result.nearest.dist)
                            result.nearest := {x:x,y:y,dist:dist}
                    }
                }
            }
            u := next
            if (A_Index=1024 && u)
                result.complete := false
        }
    }
    return result
}

CombatHPBandV305(hp,fullEnough:=false)
{
    global potHPThreshold,potHPThreshold2V299
    if (fullEnough)
        return "NORMAL"
    if (hp<0)
        return "UNKNOWN"
    if (potHPThreshold2V299>0 && hp<potHPThreshold2V299)
        return "ESCAPE"
    if (potHPThreshold>0 && hp<=potHPThreshold)
        return "ALTERNATE"
    return "NORMAL"
}

CombatRoomsTouchV305(a,b)
{
    overlapX := Min(a.x+a.w,b.x+b.w)-Max(a.x,b.x)
    overlapY := Min(a.y+a.h,b.y+b.h)-Max(a.y,b.y)
    return (overlapY>0 && (a.x+a.w=b.x || b.x+b.w=a.x))
        || (overlapX>0 && (a.y+a.h=b.y || b.y+b.h=a.y))
}

CombatEscapeNeighborV305(h,ByRef pb,r)
{
    routePointsV724 := FarmRoutePointsV724()
    global chaseCheckSecV9
    room1 := NumGet(pb,0x1C,"UInt"),current := D2ReadU32(h,room1+0x10)
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    if (current!=r.escapeRoomV305)
    {
        r.previousRoomV305 := r.escapeRoomV305,r.escapeRoomV305 := current
        r.roomGoalV305 := false,r.roomProbeAtV305 := A_TickCount,r.roomProbeXV305 := px,r.roomProbeYV305 := py
    }
    moved := (px-r.roomProbeXV305)**2+(py-r.roomProbeYV305)**2>1
    blocked := !moved && A_TickCount-r.roomProbeAtV305>=Max(0.1,chaseCheckSecV9)*1000
    if (moved)
        r.roomProbeAtV305 := A_TickCount,r.roomProbeXV305 := px,r.roomProbeYV305 := py
    if (IsObject(r.roomGoalV305) && !blocked)
        return r.roomGoalV305
    if (blocked && IsObject(r.roomGoalV305))
    {
        r.blockedRoomsV305[r.roomGoalV305.room] := A_TickCount+3000
        r.roomGoalV305 := false,r.roomProbeAtV305 := A_TickCount
    }
    node := RoomExploreReadV89(h,current,r.level)
    if (!IsObject(node))
        return false
    best := false,bestRank := 1.0e30
    for _,address in node.links
    {
        other := RoomExploreReadV89(h,address,r.level)
        if (!IsObject(other) || !CombatRoomsTouchV305(node,other)
            || (r.blockedRoomsV305.HasKey(address) && A_TickCount<r.blockedRoomsV305[address]))
            continue
        onward := 0
        for _,nextAddress in other.links
        {
            if (nextAddress=current)
                continue
            nextRoom := RoomExploreReadV89(h,nextAddress,r.level,true)
            if (IsObject(nextRoom) && CombatRoomsTouchV305(other,nextRoom))
                onward++
        }
        point := {x:other.cx,y:other.cy,room:address},distance := 1.0e30
        for _,saved in routePointsV724
        {
            if (saved.level!=r.level || saved.x<other.x || saved.x>=other.x+other.w
                || saved.y<other.y || saved.y>=other.y+other.h)
                continue
            d := (px-saved.x)**2+(py-saved.y)**2
            if (d<distance)
                point.x := saved.x,point.y := saved.y,distance := d
        }
        rank := (onward ? 0 : 1000000000)+(address=r.previousRoomV305 ? 100000000 : 0)
            +Sqrt((px-point.x)**2+(py-point.y)**2)
        if (rank<bestRank)
            best := point,bestRank := rank
    }
    r.roomGoalV305 := best
    if (IsObject(best))
        AutoMonsterAttackLogV2("LOW_HP_ADJACENT_ROOM from=" . V92Hex(current) . " to=" . V92Hex(best.room)
            . " destination=" . best.x . "," . best.y . " prefer=ONWARD_EXIT_RECHECK_AFTER_ENTRY",true)
    return best
}

CombatRecoverTickV48(h,ByRef pb,pid,target)
{
    routePointsV724 := FarmRoutePointsV724()
    global combatRecoverV48,combatMildRecoverV299,potHPThreshold,potHPThreshold2V299,monsterCombatUidV45,monsterChaseV44,monsterRoadAreaV51
    global coordRouteV16,coordNoTargetSinceV14,farmLastCombatTickV72,monsterRadiusV48,teleportKeyV55,teleportIntervalSecV56
    player := D2ReadU32(h,D2GetModuleBaseV35(pid,"D2Client.dll")+0x11BBFC)
    life := MonsterBossProbeHPV2(h,D2ReadU32(h,player+0x5C))
    hp := life.ok ? life.hp : D2GetCurrentHPV1()
    fullEnough := life.ok && life.maxraw>0 && life.raw>=life.maxraw*0.9
    band := CombatHPBandV305(hp,fullEnough)
    PortalLogWriteV66("FARM_HP_DECISION branch=ESCAPE hp=" . hp . " max=" . life.maxhp
        . " verified=" . life.ok . " threshold1=" . potHPThreshold . " threshold2=" . potHPThreshold2V299
        . " band=" . band . " full90=" . fullEnough,"FARM_HP_ESCAPE",1000)
    if (!IsObject(combatRecoverV48) && (hp<=0 || band!="ESCAPE"))
        return false
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    if (!level)
        return IsObject(combatRecoverV48)
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    if (!IsObject(combatRecoverV48) || combatRecoverV48.level!=level || combatRecoverV48.pid!=pid)
    {
        row := 0,center := {x:px,y:py}
        orbitRadius := Max(0.7,monsterRadiusV48-1),orbitIndex := 0,bestDistance := -1
        Loop, 8
        {
            angle := (A_Index-1)*0.7853981633974483
            ox := Round(center.x+orbitRadius*Cos(angle)),oy := Round(center.y+orbitRadius*Sin(angle))
            distance := (px-ox)**2+(py-oy)**2
            if (bestDistance<0 || distance<bestDistance)
                bestDistance := distance,orbitIndex := A_Index-1
        }
        combatRecoverV48 := {pid:pid,level:level,last:0,moving:false,retreatRow:row
            ,center:center,orbitIndex:orbitIndex,orbitRadius:orbitRadius,probeX:px,probeY:py,probeTick:A_TickCount
            ,escapeAttempts:0,escapeLast:0,escapeDone:false,escapeFromX:px,escapeFromY:py,escapeRetryAt:0
            ,escapeRoomV305:0,previousRoomV305:0,roomGoalV305:false,blockedRoomsV305:{},roomProbeAtV305:0}
        combatMildRecoverV299 := false
        AutoMonsterAttackLogV2("LOW_HP_RECOVER_BEGIN hp=" . hp . " threshold2=" . potHPThreshold2V299
            . " next=TELEPORT_THEN_ADJACENT_ROOM_ESCAPE center=" . center.x . "," . center.y . " row=" . row)
    }
    r := combatRecoverV48
    monsterCombatUidV45 := 0,monsterChaseV44 := false,monsterRoadAreaV51 := false
    farmLastCombatTickV72 := A_TickCount
    if (IsObject(coordRouteV16))
        coordRouteV16.stuckProbe := false,coordRouteV16.moveProbe := false,coordRouteV16.lastDispatch := 0
    if (hp<0)
        return true
    if (!NativeDispatchReadyV10(true) || D2GetActiveGamePidV95()!=pid || !AutoMonsterPacketCleanupV1())
        return true
    if (band!="ESCAPE" && band!="UNKNOWN")
    {
        if (r.moving)
        {
            if (NativeMovePointV14(pid,px,py,level,false,false,true,false,{recover:r,stop:true}))
                r.moving := false
            return true
        }
        combatRecoverV48 := false,combatMildRecoverV299 := false,coordNoTargetSinceV14 := 0
        CoordResumeNearestV303(h,pb,pid,"AFTER_HP2_RECOVERY")
        AutoMonsterAttackLogV2("LOW_HP_RECOVER_DONE hp=" . life.hp . "/" . life.maxhp . " reason=CURRENT_HP_BAND band=" . band . " full90=" . fullEnough . " next=RESUME_CURRENT_BAND")
        return false
    }
    escapePointV305 := CombatEscapeNeighborV305(h,pb,r)
    if (IsObject(escapePointV305))
        r.center := {x:escapePointV305.x,y:escapePointV305.y}
    if (!r.escapeDone && teleportKeyV55!="")
    {
        if (r.escapeLast && A_TickCount-r.escapeLast>=300)
        {
            scan := CombatRecoverScanV298(h,pb)
            if (scan.complete && !scan.count)
                r.escapeDone := true
        }
        if (r.escapeAttempts>=3)
            r.escapeDone := true
        teleCooldown := Max(3,teleportIntervalSecV56)*1000
        if (!r.escapeDone && (!r.escapeLast || A_TickCount-r.escapeLast>=teleCooldown)
            && (!r.escapeRetryAt || A_TickCount>=r.escapeRetryAt))
        {
            if (CombatRecoverTeleportV302(h,pb,pid,r))
            {
                r.last := 0,r.probeX := px,r.probeY := py,r.probeTick := A_TickCount
                return true
            }
            r.escapeRetryAt := A_TickCount+300
        }
    }
    if (IsObject(escapePointV305))
    {
        if (!r.last || A_TickCount-r.last>=250)
            if (NativeMovePointV14(pid,escapePointV305.x,escapePointV305.y,level,false,false,true,false,{recover:r}))
                r.last := A_TickCount,r.moving := true
        return true
    }
    currentRoomV305 := RoomExploreReadV89(h,D2ReadU32(h,NumGet(pb,0x1C,"UInt")+0x10),level,true)
    if (IsObject(currentRoomV305))
        r.center := {x:currentRoomV305.cx,y:currentRoomV305.cy}
    else
        r.center := {x:px,y:py}
    if (r.last && A_TickCount-r.last<250)
        return true
    r.orbitRadius := Max(0.7,monsterRadiusV48-1)
    angle := r.orbitIndex*0.7853981633974483
    tx := Round(r.center.x+r.orbitRadius*Cos(angle)),ty := Round(r.center.y+r.orbitRadius*Sin(angle))
    reached := (px-tx)**2+(py-ty)**2<=4
    blocked := A_TickCount-r.probeTick>=1000 && (px-r.probeX)**2+(py-r.probeY)**2<=1
    if (reached || blocked)
    {
        r.orbitIndex := Mod(r.orbitIndex+1,8)
        angle := r.orbitIndex*0.7853981633974483
        tx := Round(r.center.x+r.orbitRadius*Cos(angle)),ty := Round(r.center.y+r.orbitRadius*Sin(angle))
        r.probeX := px,r.probeY := py,r.probeTick := A_TickCount
    }
    else if ((px-r.probeX)**2+(py-r.probeY)**2>1)
        r.probeX := px,r.probeY := py,r.probeTick := A_TickCount
    if (IsObject(currentRoomV305))
    {
        tx := Max(currentRoomV305.x+1,Min(currentRoomV305.x+currentRoomV305.w-2,tx))
        ty := Max(currentRoomV305.y+1,Min(currentRoomV305.y+currentRoomV305.h-2,ty))
    }
    if (NativeMovePointV14(pid,tx,ty,level,false,false,true,false,{recover:r}))
    {
        r.last := A_TickCount,r.moving := true
        AutoMonsterAttackLogV2("LOW_HP_RECOVER_ORBIT row=" . r.retreatRow . " center=" . r.center.x . "," . r.center.y
            . " destination=" . tx . "," . ty . " radius=" . monsterRadiusV48 . " hp=" . hp . " blocked=" . blocked,true)
    }
    return true
}

CombatRecoverTeleportV302(h,ByRef pb,pid,r)
{
    global combatRecoverV48,autoMonsterAttackOn,teleportKeyV55,backgroundAimV64
    if (combatRecoverV48!=r || !autoMonsterAttackOn || teleportKeyV55=""
        || r.escapeAttempts>=3 || D2GetActiveGamePidV95()!=pid
        || !NativeDispatchReadyV10(true) || !AutoMonsterPacketCleanupV1())
        return false
    hwnd := GameTargetHwndV63(),base := D2GetModuleBaseV35(pid,"D2Client.dll")
    player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
    if (!path || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=r.level)
        return false
    view := AutoMonsterAttackViewV1(h,base,hwnd,path)
    if (!IsObject(view) || view.gw<=64 || view.gh<=128)
        return false
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    dx := r.center.x-px,dy := r.center.y-py
    if (dx*dx+dy*dy<1)
    {
        scan := CombatRecoverScanV298(h,pb)
        dx := scan.dx,dy := scan.dy
        if (dx*dx+dy*dy<0.000001)
            dx := -1,dy := 0
    }
    failedMove := r.escapeAttempts && (px-r.escapeFromX)**2+(py-r.escapeFromY)**2<25
    turn := failedMove ? (r.escapeAttempts=1 ? 1.047197551196598 : -1.047197551196598) : 0
    rx := dx*Cos(turn)-dy*Sin(turn),ry := dx*Sin(turn)+dy*Cos(turn)
    sx := (rx-ry)*16,sy := (rx+ry)*8,length := Sqrt(sx*sx+sy*sy)
    if (length<0.001)
        return false
    ux := sx/length,uy := sy/length
    playerSX := Max(16,Min(view.gw-16,NumGet(pb,8,"Int")-view.ox))
    playerSY := Max(32,Min(view.gh-64,NumGet(pb,12,"Int")-view.oy))
    reachX := Abs(ux)<0.000001 ? 1000000 : (ux>0 ? view.gw-16-playerSX : 16-playerSX)/ux
    reachY := Abs(uy)<0.000001 ? 1000000 : (uy>0 ? view.gh-64-playerSY : 32-playerSY)/uy
    reach := Min(reachX,reachY)
    if (reach<1)
        return false
    clientX := Round((playerSX+ux*reach)*view.cw/view.gw)
    clientY := Round((playerSY+uy*reach)*view.ch/view.gh)
    try
    {
        if (!GameTargetAimV63(clientX,clientY))
            return false
        Sleep, 30
        if (combatRecoverV48!=r || !autoMonsterAttackOn || GameTargetHwndV63()!=hwnd
            || D2GetActiveGamePidV95()!=pid || !NativeDispatchReadyV10(true) || !AutoMonsterPacketCleanupV1())
            return false
        r.escapeAttempts++,r.escapeLast := A_TickCount,r.escapeFromX := px,r.escapeFromY := py
        sent := BuffCheckedSendV29(teleportKeyV55)
        AutoMonsterAttackLogV2("LOW_HP_ESCAPE_TELEPORT attempt=" . r.escapeAttempts . "/3 aim_client=" . clientX . "," . clientY
            . " previous_cast_no_move=" . failedMove . " sent=" . sent . " effect=WAIT_POSITION_CHANGE")
        return sent
    }
    finally
        backgroundAimV64 := false
}

ScosOrderedRouteV234()
{
    routePointsV724 := FarmRoutePointsV724()

    return IsObject(routePointsV724) && routePointsV724.Length()>0
        && (routePointsV724[1].level=270 || BOFinalRouteActiveV451())
}

CoordYellowIndexV48()
{
    global coordSavedV15,roomExploreV89,coordGoV59,scosEntryV162,coordYellowRowV350,coordRouteV16
    if (IsObject(coordGoV59))
        return coordGoV59.row
    if (IsObject(roomExploreV89) && roomExploreV89.savedRouteOnly)
        return roomExploreV89.displayRow
    if (IsObject(coordRouteV16) && coordRouteV16.pid && coordRouteV16.yellow>=1
        && coordRouteV16.yellow<=coordSavedV15.Length()
        && coordSavedV15[coordRouteV16.yellow].level=coordRouteV16.startLevel)
        return coordRouteV16.yellow
    return coordYellowRowV350>=1 && coordYellowRowV350<=coordSavedV15.Length() ? coordYellowRowV350 : 0
}


MonsterStuckZoneExcludedV243(uid,x,y,level,pid)
{
    global monsterStuckZonesV243,routeMapIdV21
    if (!IsObject(monsterStuckZonesV243))
        return false
    for _,zone in monsterStuckZonesV243
    {
        if (zone.HasKey("until") && A_TickCount >= zone.until)
            continue
        if (zone.pid!=pid || zone.level!=level || zone.mapId!=routeMapIdV21)
            continue
            
        if (zone.kind="ROOM")
        {
            if (x>=zone.x && x<zone.x+zone.w && y>=zone.y && y<zone.y+zone.h)
                return true
        }
        else if (zone.kind="UID")
        {
            if (uid=zone.uid)
                return true
        }
        else if (zone.kind="RADIUS")
        {
            if ((x-zone.x)**2+(y-zone.y)**2<=zone.radiusSq)
                return true
        }
    }
    return false
}


MonsterRoomAtV655(h,pid,level,x,y)
{
    live := MapLiveIdentityV399(pid,level)
    if (!IsObject(live))
        return false
    room := D2ReadU32(h,live.levelPtr+0x10),seen := {}
    Loop, 4096
    {
        if (!room || seen.HasKey(room))
            break
        seen[room] := true
        node := RoomExploreReadV89(h,room,level,true)
        if (IsObject(node) && x>=node.x && x<node.x+node.w && y>=node.y && y<node.y+node.h)
            return node
        room := D2ReadU32(h,room+0x24)
    }
    return false
}

MonsterStuckRoomAddV548(h,unit,uid,targetX,targetY,level,pid,playerX,playerY)
{
    global monsterStuckZonesV243, routeMapIdV21, monsterLockRoomSecV622
    lockMs := Max(1, monsterLockRoomSecV622) * 1000
    lockUntil := A_TickCount + lockMs
    
    if (!IsObject(monsterStuckZonesV243))
        monsterStuckZonesV243 := []
    
    room1 := 0, node := false
    if (h && unit && MonsterBossProbeReadV1(h,unit,0x30,ub) && NumGet(ub,0x2C,"UInt"))
    {
        path := NumGet(ub,0x2C,"UInt")
        if (MonsterBossProbeReadV1(h,path,0x20,pathBuf))
        {
            room1 := NumGet(pathBuf,0x1C,"UInt")
            if (room1)
                node := RoomExploreReadV89(h,D2ReadU32(h,room1+0x10),level,true)
        }
    }
    
    if (!IsObject(node) || targetX<node.x || targetX>=node.x+node.w || targetY<node.y || targetY>=node.y+node.h)
        node := MonsterRoomAtV655(h,pid,level,targetX,targetY)
    if (!IsObject(node))
    {
        AutoMonsterAttackLogV2("TARGET_ROOM_UNREADABLE uid=" . uid . " action=RETRY_ROOM_READ no_radius_or_uid_lock=1",true)
        return false
    }

    for _,zone in monsterStuckZonesV243
        if (zone.kind="ROOM" && zone.pid=pid && zone.level=level
            && zone.mapId=routeMapIdV21 && zone.room=node.r2)
        {
            zone.until := lockUntil
            return true
        }
            
    monsterStuckZonesV243.Push({kind:"ROOM",pid:pid,level:level,mapId:routeMapIdV21
        ,room:node.r2,x:node.x,y:node.y,w:node.w,h:node.h,until:lockUntil})
    
    AutoMonsterAttackLogV2("TARGET_STUCK_ROOM_LOCK trigger_uid=" . uid . " room=" . V92Hex(node.r2)
        . " rect=" . node.x . "," . node.y . "," . node.w . "," . node.h
        . " duration=" . lockMs . "ms")
    FonInfoPushV385("Đánh không tiến triển: tạm khóa phòng " . monsterLockRoomSecV622 . " giây; tiếp tục lộ trình.")
    return true
}

MonsterStuckZonesResetV243()
{
    global monsterStuckZonesV243,monsterProgressByUidV591
    monsterStuckZonesV243 := [],monsterProgressByUidV591 := {}
}

MonsterRetryExcludedV44(uid,x := -1,y := -1,level := 0,pid := 0)
{
    global monsterRetryUntilV44
    if (MonsterStuckZoneExcludedV243(uid,x,y,level,pid))
        return true
    if (!IsObject(monsterRetryUntilV44) || !monsterRetryUntilV44.HasKey(uid))
        return false
    if (A_TickCount<monsterRetryUntilV44[uid])
        return true
    monsterRetryUntilV44.Delete(uid)
    return false
}


; Road-farm send watchdog. Kept separate from MonsterChaseProgressV44's HP
; progress clock: an ally can reduce target HP while OUR dispatch is queued=0.

; Save only the most recently skipped combat-stuck monster for the Info view.
; cls means monster class ID, NOT its per-spawn UID. dist is real map distance.
FarmStuckSkipRememberV1234(uid,cls:=-1,dist:=-1,pid:=0)
{
    global farmStuckSkipInfoV1234,farmScanListV682,farmCombatViewV624
    global currentAttackPidV550,currentAttackUidV520,currentAttackClassV520,currentAttackDistV523
    global monsterChaseV44
    if (!uid)
        return false
    if (IsObject(farmScanListV682))
    {
        for _, mobV1234 in farmScanListV682
        {
            if (mobV1234.uid=uid)
            {
                if (cls<0)
                    cls := mobV1234.cls
                if (dist<0)
                    dist := Sqrt(mobV1234.dist)
                break
            }
        }
    }
    if (IsObject(monsterChaseV44) && monsterChaseV44.uid=uid
        && (!pid || monsterChaseV44.pid=pid) && dist<0)
        dist := monsterChaseV44.distance
    if (IsObject(farmCombatViewV624) && farmCombatViewV624.uid=uid
        && (!pid || farmCombatViewV624.pid=pid) && cls<0)
        cls := farmCombatViewV624.cls
    if (currentAttackUidV520=uid && (!pid || currentAttackPidV550=pid))
    {
        if (cls<0)
            cls := currentAttackClassV520
        if (dist<0)
            dist := currentAttackDistV523
    }
    ; A new monster REPLACES the old display value; never accumulate entries.
    farmStuckSkipInfoV1234 := {uid:uid,cls:cls,dist:dist,at:A_TickCount}
    return true
}

MonsterStuckUidSkipV711(uid,level,pid)
{
    global monsterStuckZonesV243,routeMapIdV21,monsterLockRoomSecV622
    global monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44
    global currentAttackUidV520,currentAttackAtV520,monsterProgressByUidV591
    if (!IsObject(monsterStuckZonesV243))
        monsterStuckZonesV243 := []
    until := A_TickCount+Max(1,monsterLockRoomSecV622)*1000
    found := false
    for _,zone in monsterStuckZonesV243
        if (zone.kind="UID" && zone.uid=uid && zone.pid=pid && zone.level=level && zone.mapId=routeMapIdV21)
            zone.until := until,found := true
    if (!found)
        monsterStuckZonesV243.Push({kind:"UID",uid:uid,pid:pid,level:level,mapId:routeMapIdV21,until:until})
    if (monsterCombatUidV45=uid)
        monsterCombatUidV45 := 0,monsterRoadAreaV51 := false
    if (IsObject(monsterChaseV44) && monsterChaseV44.uid=uid)
        monsterChaseV44 := false
    ; Clear stale attack/watchdog state or it reports the same skipped UID
    ; repeatedly while the selector is supposed to choose another monster.
    if (currentAttackUidV520=uid)
        currentAttackUidV520 := 0,currentAttackAtV520 := 0
    keyV917 := pid . "|" . level . "|" . uid
    if (IsObject(monsterProgressByUidV591) && monsterProgressByUidV591.HasKey(keyV917))
        monsterProgressByUidV591.Delete(keyV917)
    FarmAttackHoldReleaseV15()
}

MonsterStuckIncomingV711(h,pid,level,candidates,playerX:=0,playerY:=0)
{
    global monsterChaseV44,monsterCombatUidV45,monsterRadiusV48,monsterRoadAreaV51
    global monsterProgressByUidV591,farmCloseRadiusV391,chaseCheckSecV9
    c := monsterChaseV44
    ; Only switch after the configured timeout, including stalled packet sending.
    if (chaseCheckSecV9<=0)
        return false
    if (!IsObject(c) || c.pid!=pid || c.level!=level || monsterCombatUidV45!=c.uid
        || !c.since || (c.queued<1 && !c.farmWatchV1181)
        || A_TickCount-c.since<Max(1,chaseCheckSecV9)*1000
        || A_TickCount-c.seenAtV591>1500)
        return false
    current := false,near := false
    radiusSq := Max(1,farmCloseRadiusV391)**2
    for _,a in candidates
    {
        if (a.uid=c.uid)
            current := a
        else if (a.level=level && a.dist<=radiusSq && (!IsObject(near) || a.dist<near.dist))
            near := a
    }
    if (!IsObject(current) || !IsObject(near))
        return false
    hp := MonsterBossProbeHPV2(h,D2ReadU32(h,current.unit+0x5C))
    if (hp.ok && (c.hp<0 || hp.raw<c.hp || c.distance-Sqrt(current.dist)>1))
        return false
    oldUid := c.uid
    FarmStuckSkipRememberV1234(oldUid,current.cls,Sqrt(current.dist),pid)
    bkRadius := Max(1,monsterRadiusV48)
    skipDistanceV752 := MonsterSkipDistanceGetV752(bkRadius)
    bkHalfSq := skipDistanceV752*skipDistanceV752
    isClose := current.dist <= bkHalfSq
    monsterProgressByUidV591.Delete(pid . "|" . level . "|" . oldUid)
    if (isClose)
    {
        MonsterStuckUidSkipV711(oldUid,level,pid)
        PortalLogWriteV66("COMBAT_STUCK_SWITCH old_uid=" . oldUid . " new_uid=" . near.uid
            . " scope=UID dist_sq=" . Round(current.dist,1) . " half_bk_sq=" . Round(bkHalfSq,1))
    }
    else
    {
        if (monsterCombatUidV45=oldUid)
            monsterCombatUidV45 := 0,monsterRoadAreaV51 := false
        if (IsObject(monsterChaseV44) && monsterChaseV44.uid=oldUid)
            monsterChaseV44 := false
        FarmAttackHoldReleaseV15()
        roomOkV1172 := MonsterStuckRoomAddV548(h,current.unit,oldUid,current.x,current.y,level,pid,playerX,playerY)
        if (!roomOkV1172)
            MonsterStuckUidSkipV711(oldUid,level,pid)
        PortalLogWriteV66("COMBAT_STUCK_SWITCH old_uid=" . oldUid . " new_uid=" . near.uid
            . " scope=" . (roomOkV1172 ? "ROOM" : "UID_FALLBACK") . " dist_sq=" . Round(current.dist,1) . " half_bk_sq=" . Round(bkHalfSq,1))
    }
    monsterCombatUidV45 := near.uid
    FonInfoPushV385("Kẹt đánh: bỏ qua " . (isClose ? "quái UID " : "phòng chứa quái UID ") . oldUid . ", chuyển sang quái gần " . near.uid . ".")
    return near
}

MonsterChaseProgressV44(uid,x,y,distSq,hpRaw := -1,targetX := -1,targetY := -1,targetLevel := 0,pid := 0,h := 0,unit := 0,farmWatchV1181 := false)
{
    global monsterChaseV44, chaseCheckSecV9
    global monsterProgressByUidV591, monsterStuckZonesV243, routeMapIdV21
    global monsterCombatUidV45, monsterRoadAreaV51, monsterRadiusV48

    if (!IsObject(monsterProgressByUidV591))
        monsterProgressByUidV591 := {}

    keyV591 := pid . "|" . targetLevel . "|" . uid
    c := monsterProgressByUidV591[keyV591]

    if (!IsObject(c) || c.unitV591!=unit || A_TickCount-c.seenAtV591>30000)
    {
        if (monsterProgressByUidV591.Count()>=256)
        {
            oldestKeyV591 := "",oldestAtV591 := A_TickCount
            for oldKeyV591,oldV591 in monsterProgressByUidV591
                if (oldV591.seenAtV591<=oldestAtV591)
                    oldestKeyV591 := oldKeyV591,oldestAtV591 := oldV591.seenAtV591
            if (oldestKeyV591!="")
                monsterProgressByUidV591.Delete(oldestKeyV591)
        }
        ; V917: selected Farm combat targets must start the no-progress clock
        ; even if a blocked/remote attack command never enters the send queue.
        farmSelectedV917 := farmWatchV1181 || (pid && FarmCenterPendingV741(pid))
        c := {uid:uid, x:x, y:y, hp:hpRaw, distance:Sqrt(distSq)
            ,since:(farmSelectedV917 ? A_TickCount : 0), queued:0,farmWatchV1181:farmSelectedV917
            ,targetX:targetX, targetY:targetY, level:targetLevel, pid:pid
            ,unitV591:unit, seenAtV591:A_TickCount}
        monsterProgressByUidV591[keyV591] := c
        monsterChaseV44 := c
        return true
    }

    c.seenAtV591 := A_TickCount
    monsterChaseV44 := c
    distanceNow := Sqrt(distSq)

    hpChangedV592 := hpRaw>=0 && c.hp>=0 && hpRaw<c.hp
    ; Movement towards a distant monster is progress even if its HP is unreadable.
    distanceChangedV592 := c.distance-distanceNow>1

    if (hpChangedV592 || distanceChangedV592)
    {
        if (hpRaw>=0 && c.hp>=0 && hpRaw<c.hp)
            FarmStuckCombatProgressV247()
        c.x := x, c.y := y, c.hp := hpRaw, c.distance := distanceNow
        c.since := 0, c.queued := 0
        return true
    }

    if (hpRaw>=0 && c.hp<0)
    {
        c.hp := hpRaw, c.distance := distanceNow, c.since := 0, c.queued := 0
        return true
    }

    if (hpRaw>=0)
        c.hp := hpRaw

    ; V917: Farm monitors selected targets without requiring a successful
    ; attack packet. Other modes keep their original send-based threshold.
    farmSelectedV917 := farmWatchV1181 || (pid && FarmCenterPendingV741(pid))
    c.farmWatchV1181 := farmSelectedV917
    if (!c.since)
    {
        if (!farmSelectedV917)
            return true
        c.since := A_TickCount
    }
    if (c.queued<1 && !farmSelectedV917)
        return true
    ; 20261029 LOG FIX: packet=0 KHONG co nghia la danh bi ket.
    ; Khong khoa phong / bo qua UID khi CHUA QUEUE DUOC LENH DANH NAO.
    ; Luon giu lai muc tieu va thu gui lai; log tach loi GUI LENH voi loi DANH KHONG MAT MAU.
    if (farmSelectedV917 && c.queued<1)
    {
        if (chaseCheckSecV9>0 && A_TickCount-c.since>=Max(1,chaseCheckSecV9)*1000)
        {
            c.noSendRoundsV2026 := c.HasKey("noSendRoundsV2026") ? c.noSendRoundsV2026+1 : 1
            PortalLogWriteV66("FARM_COMBAT_NO_PACKET_RETRY uid=" . uid
                . " level=" . targetLevel . " distance=" . Round(distanceNow,2)
                . " packets=0 round=" . c.noSendRoundsV2026
                . " action=KEEP_TARGET_RETRY_SEND_NO_SKIP")
            if (c.noSendRoundsV2026=3)
                FonInfoPushV385("Chua gui duoc lenh danh UID " . uid
                    . ". Giu muc tieu va thu lai; kiem tra COMBAT_SEND_BLOCK trong log.")
            c.since := A_TickCount
        }
        return true
    }

    if (chaseCheckSecV9 > 0 && A_TickCount - c.since >= Max(1, chaseCheckSecV9) * 1000)
    {
        if (hpRaw < 0 || c.hp < 0 || hpRaw == c.hp)
        {
            bkRadius := Max(1, monsterRadiusV48)
            skipDistanceV752 := MonsterSkipDistanceGetV752(bkRadius)
            bkHalfSq := skipDistanceV752*skipDistanceV752
            isClose := distSq <= bkHalfSq
            ; Remember the stuck monster before clearing the combat target.
            stuckClsV1234 := (h && unit) ? D2ReadU32(h,unit+4) : -1
            FarmStuckSkipRememberV1234(uid,stuckClsV1234,distanceNow,pid)
            ; Mark the actual stuck target, not just the last packet UID.
            PortalLogWriteV66("FARM_COMBAT_STUCK_REAL uid=" . uid
                . " level=" . targetLevel . " distance=" . Round(distanceNow,2)
                . " timeout_sec=" . chaseCheckSecV9
                . " elapsed_ms=" . (A_TickCount-c.since)
                . " packets=" . c.queued . " farm_watch=" . c.farmWatchV1181
                . " hp_readable=" . (hpRaw>=0)
                . " action=" . (isClose ? "SKIP_UID" : "SKIP_ROOM_OR_UID")
                ,"FARM_COMBAT_STUCK_REAL_" . uid,1000)
            monsterProgressByUidV591.Delete(keyV591)
            monsterChaseV44 := false
            if (isClose)
            {
                MonsterStuckUidSkipV711(uid,targetLevel,pid)
                FonInfoPushV385("Bỏ qua quái UID " . uid . ": đánh không tiến triển sau "
                    . chaseCheckSecV9 . " giây (trong ngưỡng khóa quái); ưu tiên quái gần rồi tiếp tục lộ trình.")
                AutoMonsterAttackLogV2("TARGET_STUCK_NO_DAMAGE uid=" . uid . " time=" . chaseCheckSecV9
                    . "s hp_readable=" . (hpRaw>=0) . " dist_sq=" . Round(distSq,1) . " half_bk_sq=" . Round(bkHalfSq,1)
                    . " uid_locked=1 room_locked=0")
            }
            else
            {
                if (monsterCombatUidV45=uid)
                    monsterCombatUidV45 := 0,monsterRoadAreaV51 := false
                FarmAttackHoldReleaseV15()
                roomLockedV917 := MonsterStuckRoomAddV548(h,unit,uid,targetX,targetY,targetLevel,pid,x,y)
                ; If the remote monster room cannot be resolved, never leave
                ; the target eligible for immediate reselection.
                if (!roomLockedV917)
                    MonsterStuckUidSkipV711(uid,targetLevel,pid)
                FonInfoPushV385("Bỏ qua phòng chứa quái UID " . uid . ": đánh không tiến triển sau "
                    . chaseCheckSecV9 . " giây (ngoài ngưỡng khóa quái); ưu tiên phòng khác rồi tiếp tục lộ trình.")
                AutoMonsterAttackLogV2("TARGET_STUCK_NO_DAMAGE uid=" . uid . " time=" . chaseCheckSecV9
                    . "s hp_readable=" . (hpRaw>=0) . " dist_sq=" . Round(distSq,1) . " half_bk_sq=" . Round(bkHalfSq,1)
                    . " uid_locked=" . (!roomLockedV917) . " room_locked=" . roomLockedV917)
            }
            return false
        }
    }

    return true
}
MonsterClassExcludedV11(classId,h := 0,unit := 0)
{
    global monsterExcludeClassesV11
    for _,token in StrSplit(RegExReplace(monsterExcludeClassesV11,"[;\s]+",","),",")
    {
        if (RegExMatch(token,"^\d+$") && token+0=classId)
            return true
    }
    return h && unit ? MonsterKnownNonCombatV544(h,unit,classId) : false
}

MonsterNonCombatTablesV544(h)
{
    static cached := false, checked := 0
    pid := h ? DllCall("GetProcessId","Ptr",h,"UInt") : 0
    if (!pid)
        return false
    if (IsObject(cached) && cached.pid=pid && cached.handle=h && A_TickCount-checked<100)
        return cached.mon ? cached : false
    checked := A_TickCount,cached := {pid:pid,handle:h,mon:0}
    base := D2GetModuleBaseV35(pid,"D2Common.dll")
    if (!base || !MonsterBossProbeReadV1(h,base,0x40,dos) || NumGet(dos,0,"UShort")!=0x5A4D)
        return false
    pe := NumGet(dos,0x3C,"UInt")
    if (pe<0x40 || pe>0x1000 || !MonsterBossProbeReadV1(h,base+pe,0x60,header)
        || NumGet(header,0,"UInt")!=0x4550 || NumGet(header,4,"UShort")!=0x14C
        || NumGet(header,8,"UInt")!=0x4B95C439 || NumGet(header,0x50,"UInt")!=0xA9000)
        return false
    if (!MonsterBossProbeReadV1(h,base+0x99E1C,4,ptr))
        return false
    root := NumGet(ptr,0,"UInt")
    if (!MonsterBossProbeReadV1(h,root+0xA78,0x24,tables))
        return false
    mon := NumGet(tables,0,"UInt"),count := NumGet(tables,8,"UInt")
    if (mon<0x10000 || count<1 || count>65535 || mon+count*0x1A8>0xFFFFFFFF)
        return false
    cached := {pid:pid,handle:h,mon:mon,monCount:count
        ,extra:NumGet(tables,0x18,"UInt"),extraCount:NumGet(tables,0x20,"UInt")}
    return cached
}

MonsterKnownNonCombatV544(h,unit,classId)
{
    tables := MonsterNonCombatTablesV544(h)
    if (!IsObject(tables) || classId<0 || classId>=tables.monCount
        || !MonsterBossProbeReadV1(h,unit,0x18,ub)
        || NumGet(ub,0,"UInt")!=1 || NumGet(ub,4,"UInt")!=classId)
        return false
    row := tables.mon+classId*0x1A8,data := NumGet(ub,0x14,"UInt")
    if (!MonsterBossProbeReadV1(h,data,4,md) || NumGet(md,0,"UInt")!=row
        || !MonsterBossProbeReadV1(h,row,0x1A,record) || NumGet(record,0,"UShort")!=classId)
        return false
    flags := NumGet(record,0xC,"UInt")
    if (flags & 0x8000)
        return false
    if ((flags & 0x300)=0x300)
        return true
    extraId := NumGet(record,0x18,"UShort")
    if (tables.extra<0x10000 || tables.extraCount<1 || tables.extraCount>65535
        || extraId>=tables.extraCount || tables.extra+tables.extraCount*0x134>0xFFFFFFFF
        || !MonsterBossProbeReadV1(h,tables.extra+extraId*0x134,8,extra)
        || NumGet(extra,0,"UShort")!=extraId)
        return false
    flags2 := NumGet(extra,4,"UInt")
    return (flags2 & 0x22000)=0x22000 && !(flags2 & 8)
}

NativeExportTimerV12:
if (!ManualLogActiveV81())
{
    SetTimer, NativeExportTimerV12, Off
    return
}
if (!pickupCubeTraceUntil || A_TickCount>=pickupCubeTraceUntil)
{
    SetTimer, NativeExportTimerV12, Off
    return
}
if (!IsGameActive())
    return
SetTimer, NativeExportTimerV12, Off
NativeAttackDumpV8()
return

PetLearnNearestV12(fromGuiV137 := false)
{
    global monsterExcludeClassesV11, petLearnOnV12, petLearnDoneV12, petExcludeFileV12
    global petLearnEnabledV12
    if (!petLearnEnabledV12)
        return false
    pid := fromGuiV137 ? CoordDisplayGamePidV1() : D2GetActiveGamePidV95()
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? DllCall("OpenProcess","UInt",0x0410,"Int",0,"UInt",pid,"Ptr") : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return false
        target := PetBossHoveredUnitV223(h,base,pid)
        if (!IsObject(target))
            return false
        if (!MonsterBossProbeReadV1(h,target.unit,0x30,ub) || NumGet(ub,0,"UInt")!=1
            || NumGet(ub,12,"UInt")!=target.uid || NumGet(ub,16,"UInt")=0 || NumGet(ub,16,"UInt")=12)
            return false
        if (!petLearnOnV12 || petLearnDoneV12 || (!fromGuiV137 && D2GetActiveGamePidV95()!=pid))
            return false
        classId := NumGet(ub,4,"UInt")
        petLearnDoneV12 := true
        if (MonsterClassExcludedV11(classId))
        {
            ToolTipInfoV386("Class ID " . classId . " đã có — không thêm, không tìm con khác.")
            SetTimer, RemoveToolTip, -3000
            return true
        }
        oldList := monsterExcludeClassesV11
        monsterExcludeClassesV11 .= (Trim(monsterExcludeClassesV11)="" ? "" : ",") . classId
        if (!PetExcludeSaveV12())
        {
            monsterExcludeClassesV11 := oldList
            return false
        }
        PetExcludeRefreshV16()
        ToolTipInfoV386("Đã thêm đúng 1 Class ID: " . classId . " (con đang dưới chuột).")
        SetTimer, RemoveToolTip, -3000
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

PetExcludeLoadV12()
{
    global petExcludeFileV12, monsterExcludeClassesV11
    monsterExcludeClassesV11 := ""
    if (FileExist(petExcludeFileV12))
    {
        FileRead, content, %petExcludeFileV12%
        if (!ErrorLevel)
            monsterExcludeClassesV11 := RegExReplace(Trim(content," `t`r`n"),"\s+",",")
    }
    PetExcludeRefreshV16()
}

PetExcludeSaveV12()
{
    global petExcludeFileV12, monsterExcludeClassesV11
    content := "", seen := {}, normalized := ""
    for _,token in StrSplit(RegExReplace(monsterExcludeClassesV11,"[;\s]+",","),",")
    {
        if (!RegExMatch(token,"^\d+$"))
            continue
        id := token+0
        if (seen.HasKey(id))
            continue
        seen[id] := true
        content .= id . "`r`n"
        normalized .= (normalized="" ? "" : ",") . id
    }
    tmp := petExcludeFileV12 . ".tmp"
    file := FileOpen(tmp,"w","UTF-8-RAW")
    if (!IsObject(file))
        return false
    written := file.Write(content)
    file.Close()
    if (content!="" && written=0)
        return false
    FileMove, %tmp%, %petExcludeFileV12%, 1
    if (ErrorLevel)
        return false
    monsterExcludeClassesV11 := normalized
    return true
}

FarmHotkeyForegroundV154(hotkeyName := "")
{
    global autoMonsterAttackOn,backgroundHwndV63
    if (autoMonsterAttackOn)
        return backgroundHwndV63 && WinActive("ahk_id " . backgroundHwndV63) && IsGameForegroundV63()
    return (WinActive("ahk_exe Game.exe") || WinActive("ahk_exe Diablo II.exe")
        || WinActive("ahk_exe D2.exe")) && IsGameForegroundV63()
}

AutoMonsterToggleKeyHandlerV13:
if (FarmControlRunningV186() && !IsObject(farmMapPauseV52) && farmControlOwnerV186!="SCOS")
    return
if (!FarmControlRunningV186())
    farmControlOwnerV186 := "SCOS"
MapKeyTraceV174(autoMonsterToggleKeyV13,"L_HANDLER_ENTER hotkey=" . A_ThisHotkey)
foregroundFarmKeyV82 := DllCall("GetForegroundWindow","Ptr")
WinGet, foregroundFarmPidV124, PID, ahk_id %foregroundFarmKeyV82%
if (!FarmHotkeyForegroundV154() || (autoMonsterAttackOn && foregroundFarmPidV124!=backgroundPidV63))
{
    AutoMonsterAttackLogV2("FARM_KEY_REJECT key=" . autoMonsterToggleKeyV13 . " reason=FOREGROUND_GAME_PID",true)
    return
}
if (farmKeyHeldV124)
    return
farmKeyHeldV124 := true
SetTimer, FarmKeyReleaseTimerV124, 30
AutoMonsterAttackLogV2("FARM_KEY_RECEIVED key=" . autoMonsterToggleKeyV13 . " before=" . autoMonsterAttackOn,true)
Gosub, MapControlActionV168
return

FarmStartLevelReadyV757(owner,level,mode)
{
    return level>0 && mode>0 && mode!=17 && !FarmReviveTownLevelV295(level)
        && FarmStartMapStageV737(owner,level)=2
}

FarmStartInFarmV757(pid)
{
    global farmControlOwnerV186
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        if (!player || !MonsterBossProbeReadV1(h,player+0x10,4,modeBytes))
            return false
        mode := NumGet(modeBytes,0,"UInt"),path := D2ReadU32(h,player+0x2C)
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return false
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        owner := farmControlOwnerV186!="" ? farmControlOwnerV186 : "SCOS"
        return FarmStartLevelReadyV757(owner,level,mode)
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

FarmStartClearReviveBuffV757(level,mode,pid)
{
    global farmControlOwnerV186,reviveBuffPendingV34,entryBuffPendingV20
    global farmReviveV32,farmDeadStartV695
    if (!reviveBuffPendingV34 || IsObject(farmReviveV32) || IsObject(farmDeadStartV695))
        return false
    owner := farmControlOwnerV186!="" ? farmControlOwnerV186 : "SCOS"
    if (!FarmStartLevelReadyV757(owner,level,mode))
        return false
    reviveBuffPendingV34 := false,entryBuffPendingV20 := false
    PortalLogWriteV66("START_IN_FARM_BUFF_CLEAR level=" . level . " pid=" . pid . " next=KEEP_YELLOW_ROUTE")
    return true
}

FarmStartMapStageV737(mapName,level)
{
    global currentProfile
    if (level<=0)
        return 0
    plan := FarmMapPlanV10(mapName,level)
    if (IsObject(plan))
        return plan.final ? 2 : 1
    if (mapName="SCOS")
        return level=270 ? 2 : (level=109 || level=241) ? 1 : 0
    if (mapName="CAIN")
        return (level=183 || level=184 || level=185) ? 2 : 0
    if (mapName="NAO")
        return level=109 ? 1 : (!FarmReviveTownLevelV295(level) && level=NaoFarmLevelV312(level)) ? 2 : 0
    if (mapName="LIB")
        return level=103 ? 1 : (level>=263 && level<=266) ? 2 : 0
    if (mapName="BO")
    {
        if (FarmReviveTownLevelV295(level))
            return 1
        section := ProfileSection(currentProfile)
        IniRead, firstFarm, % ProfileConfigPathV364(section), %section%, BOFarmLevel2, 0
        IniRead, finalFarm, % ProfileConfigPathV364(section), %section%, BOFarmLevel4, 0
        return (firstFarm && level=firstFarm) || (finalFarm && level=finalFarm) ? 2 : 1
    }
    return 0
}

MapRunResumePrepareV210(mapName)
{
    global coordSavedV15,coordManualRowV59,coordPinnedYellowV136,autoMapTrackingV10
    global routeMapIdV21,backgroundPidV63,townLevelV22,mapWorkflowV185
    global mapRunResumeV210
    global coordRunSelectedV210,libRunChoiceV281,coordYellowRowV350
    mapRunResumeV210 := false
    level := FarmCurrentLevelV143()
    if (FarmStartMapStageV737(mapName,level)!=2)
        return 0
    if (MapScrollFarmV269(mapName) && IsObject(libRunChoiceV281) && libRunChoiceV281.mapId=routeMapIdV21)
        coordRunSelectedV210 := libRunChoiceV281
    oldMap := routeMapIdV21
    selected := FarmStartRowV394()
    oldPoint := selected>=1 && selected<=coordSavedV15.Length() ? coordSavedV15[selected] : false
    if (IsObject(coordRunSelectedV210) && coordRunSelectedV210.mapId=oldMap)
        selected := coordRunSelectedV210.row,oldPoint := coordRunSelectedV210
    requestedYellowV367 := coordYellowRowV350
    requestedMapV367 := routeMapIdV21
    CoordRouteResetV16()
    coordRunSelectedV210 := false
    if (!Stage2MapRequestV381(true))
        return -1
    if (!level && coordSavedV15.Length())
        level := coordSavedV15[1].level
    pid := backgroundPidV63,base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return -1
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb)
            || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=level)
            return -1
        row := 0
        row := FarmStartRowV394()
        if (row && coordSavedV15[row].level!=level)
            row := 0
        if (!row)
            return 0
        mapWorkflowV185 := {map:mapName,stage:2,startLevel:109,testRows:0,resumeMapIdV210:routeMapIdV21}
        MapStageSetV185(2)
        point := coordSavedV15[row]
        mapRunResumeV210 := {row:row,mapId:routeMapIdV21,pid:pid,x:point.x,y:point.y,level:level}
        coordRunSelectedV210 := false
        PortalLogWriteV66("RUN_RESET_FROM_YELLOW row=" . row . " map=" . routeMapIdV21 . " level=" . level . " route=RELOADED")
        return 1
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

FarmRuntimeResetV535(reason)
{
    global
    local timer
    farmUserPausedV2026 := false,farmPauseTickV2026 := 0

    PickupFarmResetV762()
    sigTerminalErrorV762 := ""
    monsterProgressByUidV591 := {}
    farmItemLockV625 := false
    farmFightLockV626 := false
    farmSkillPairV620 := false
    farmRunEpochV535++
    farmPickupTimedSkippedV1602 := {}
    farmCenterCycleV741 := false
    SetTimer, FarmPickupHandoffTimerV901, Off
    farmDeadStartV695 := false
    farmStartRetryV237 := false,stage2StartPendingV381 := false
    farmStage3PendingV237 := false,sigFarmResumePendingV237 := false,farmRestartReasonV238 := ""
    mapFarmStartPendingV170 := false,mapStage1BuffDoneV248 := false
    for _,timer in ["Stage2StartWaitTimerV381","FarmStage3RetryTimerV237","SigFarmResumeV152"
        ,"MapFarmStartV170","FarmStopMoveTimerV124"]
        SetTimer, %timer%, Off
    farmStopMoveV124 := false,farmMapPauseV52 := false,cainPausedV10 := false
    cainNoFightV361 := false,cainPauseFarmV361 := false,cainAttachRetryAtV379 := 0
    farmResumeArmedV70 := false,farmResumeOutsideV70 := false
    farmReviveV32 := false,reviveBuffPendingV34 := false
    entryBuffPendingV20 := false,pestiPointPendingV28 := false,lastAttackPendingV20 := false
    portalBuffV85 := false,portalExitPendingV69 := false,portalBackPendingV74 := false
    coordCastCountV50 := 0,coordCastLastRowV50 := 0,coordCastPendingV50 := false
    coordMoveDoneV14 := false,coordMoveTriesV14 := 0,coordNoTargetSinceV14 := 0
    monsterCombatUidV45 := 0,monsterChaseV44 := false,monsterRoadAreaV51 := false
    combatRecoverV48 := false,combatMildRecoverV299 := false
    farmPickupGuardV4 := false,pickupFarmWorkV75 := false
    farmPickupBlockedV57 := false,farmPickupAllowedV57 := true
    farmCubeSortOnceV253 := false,farmStage2DoneV372 := false,mapLoadFailureV402 := false
    farmLoadedMapV56 := false,stage2FlowV380 := false,stage2MapFileV14 := false
    coordRouteV16 := false,mapRunResumeV210 := false,coordRunSelectedV210 := false
	FarmStuckInfoDisableV10(true)
    MovementCtrlSetV78(false,0,reason)
    PortalLogWriteV66("FARM_RUNTIME_RESET reason=" . reason . " epoch=" . farmRunEpochV535
        . " route=RELOAD_ON_START yellow=KEPT live_action_locks=OWNED_BY_HANDLER")
}

FarmStartPrepareV2(reuse := false)
{
    global farmManualStoppedV2026
    farmManualStoppedV2026 := false
    global farmStartChoiceV2,currentProfile,routeMapIdV21,coordSavedV15,farmRunEpochV535
    global coordTrackingEnabledV409, autoMapTrackingV10
    FarmElapsedStartV1350()
    
    if (!coordTrackingEnabledV409) 
    {
        if (FonTrackingEnableV410())
            PortalLogWriteV66("FARM_START_AUTO_FON next=BAT_TU_DONG")
        else
            PortalLogWriteV66("FARM_START_AUTO_FON_FAIL next=BI_CHAN_BOI_EDIT")
    } 
    else 
    {
        SetTimer, CoordCurrentTimerV15, 250
    }

    FarmSkillBaselineEnsureV621(CoordDisplayGamePidV1())
    FarmRuntimeResetV535("MANUAL_START")
    FarmStartRouteDiscardV698(true)
    FarmBuffStartV509()
    FarmWatchStartV5()
    fresh := FonEnsureLiveV410(CoordDisplayGamePidV1())
    row := fresh ? FarmStartRowV394() : 0
    point := row ? coordSavedV15[row] : false
    farmStartChoiceV2 := {pid:CoordDisplayGamePidV1(),epoch:farmRunEpochV535,profile:currentProfile,mapId:routeMapIdV21
        ,reloadPending:true,freshV698:fresh}
    if (IsObject(point))
        farmStartChoiceV2.row := row,farmStartChoiceV2.level := point.level
            ,farmStartChoiceV2.x := point.x,farmStartChoiceV2.y := point.y
}
FarmStartRouteDiscardV698(stopTracking := false)
{
    global
    coordRouteV16 := false,stage2MapFileV14 := false,stage2FlowV380 := false
    farmLoadedMapV56 := false,farmStage2DoneV372 := false
    farmStartChoiceV2 := false,mapRunResumeV210 := false,coordRunSelectedV210 := false,libRunChoiceV281 := false
    farmStopMoveV124 := false,coordMoveDoneV14 := false,coordMoveTriesV14 := 0
    SetTimer, FarmStopMoveTimerV124, Off
}

FarmStartPortalOriginV699(level)
{
    global farmControlOwnerV186
    return FarmRevivePortalSourceV746(level)
}


FarmStartStateV698(pid)
{
    global farmReviveV32,farmControlOwnerV186
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        if (!player || !MonsterBossProbeReadV1(h,player+0x10,4,modeBytes))
            return false
        mode := NumGet(modeBytes,0,"UInt")
        if (mode=0 || mode=17)
            return {dead:true,town:false,portal:false}
        ; START khong can doc cong / danh gia thanh khi nhan vat con song.
        ; Chuyen ngay sang nap INI cua map hien tai + dong vang.
        return {dead:false,town:false,portal:false}
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

FarmDeadStartBeginV695()
{
    global
    local live
    live := FarmStartStateV698(backgroundPidV63)
    if (!IsObject(live))
    {
        FarmStartKeepV697("WAIT_LIVE_PLAYER")
        return true
    }
    ; START chay truc tiep tu dong vang khi con song, khong uu tien cong chi vi dang o thanh.
    ; Neu nhan vat chet thi van chuyen qua duy nhat luong hoi sinh.
    if (!live.dead)
        return false
    FarmRuntimeResetV535("START_REVIVE_OR_TOWN_PORTAL")
    FarmStartRouteDiscardV698(true)
    farmDeadStartV695 := {pid:backgroundPidV63,hwnd:backgroundHwndV63,epoch:farmRunEpochV535}
    farmReviveV32 := {pid:backgroundPidV63,esc:false,step:0,last:0,origin:false
        ,seen:{},townBuffDone:false,deathSeenV296:live.dead,startPortalOriginV699:live.level}
    reviveBuffPendingV34 := false
    autoMonsterAttackOn := true
    SetTimer, AutoMonsterAttackTimer, 250
    Gosub, MapControlButtonStatusV171
    FonInfoPushV385(live.dead ? "[START] Hồi sinh trước; sau đó kiểm tra cổng trong thành."
        : "[START] Hoi sinh truoc khi nap map va chay tu dong vang.")
    return true
}

; START preflight also uses AutoMonsterAttackTimer, not a second revive timer.
FarmDeadStartTickV695()
{
global
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    farmDeadStartV695 := false
    SetTimer, AutoMonsterAttackTimer, Off
    return
}
if (farmDeadStartBusyV695)
    return
farmDeadStartBusyV695 := true
try
{
    deadStartV695 := farmDeadStartV695
    if (!IsObject(deadStartV695) || !autoMonsterAttackOn
        || deadStartV695.epoch!=farmRunEpochV535)
    {
        farmDeadStartV695 := false
        SetTimer, AutoMonsterAttackTimer, Off
        return
    }
    if (!BackgroundValidV63() || backgroundPidV63!=deadStartV695.pid
        || backgroundHwndV63!=deadStartV695.hwnd || !IsGameActive())
        return
    deadBaseV695 := D2GetModuleBaseV35(deadStartV695.pid,"D2Client.dll")
    deadHV695 := deadBaseV695 ? D2OpenProcess(deadStartV695.pid) : 0
    if (!deadHV695)
        return
    try
    {
        deadPlayerV695 := D2ReadU32(deadHV695,deadBaseV695+0x11BBFC)
        if (!deadPlayerV695 || !MonsterBossProbeReadV1(deadHV695,deadPlayerV695+0x10,4,deadModeBytesV698))
            return
        deadModeV695 := NumGet(deadModeBytesV698,0,"UInt")
        deadPathV695 := D2ReadU32(deadHV695,deadPlayerV695+0x2C)
        if (deadModeV695=0 || deadModeV695=17)
        {
            VarSetCapacity(deadPBV695,0x20,0)
            FarmReviveTickV32(deadHV695,deadPlayerV695,deadPBV695,deadStartV695.pid
                ,deadStartV695.hwnd,deadBaseV695,deadPathV695,deadModeV695)
            return
        }
        if (!MonsterBossProbeReadV1(deadHV695,deadPathV695,0x20,deadPBV695))
            return
        FarmReviveTickV32(deadHV695,deadPlayerV695,deadPBV695,deadStartV695.pid
            ,deadStartV695.hwnd,deadBaseV695,deadPathV695,deadModeV695)
        return
    }
    finally
        DllCall("CloseHandle","Ptr",deadHV695)
}
finally
    farmDeadStartBusyV695 := false
}

FarmRoutePointsV724()
{
    global scosEntryV162,coordSavedV15
    c := IsObject(scosEntryV162) ? scosEntryV162.commonRouteV3 : false
    return IsObject(c) && IsObject(c.pointsV724) ? c.pointsV724 : coordSavedV15
}

CoordAdjacentRowV724(points,current,x,y,level)
{
    if (!IsObject(points) || !points.Length())
        return 0
    valid := current>=1 && current<=points.Length() && points[current].level=level
    first := valid ? Max(1,current-1) : 1,last := valid ? Min(points.Length(),current+1) : points.Length()
    best := valid ? current : 0
    bestSq := valid ? (x-points[current].x)**2+(y-points[current].y)**2 : 1.0e30
    Loop, % last-first+1
    {
        row := first+A_Index-1,p := points[row]
        if (p.level!=level)
            continue
        d := (x-p.x)**2+(y-p.y)**2
        if (d<bestSq)
            best := row,bestSq := d
    }
    return best
}

FarmStartApplyYellowV2()
{
    global farmStartChoiceV2,currentProfile,routeMapIdV21,coordSavedV15,farmRunEpochV535
    global coordYellowRowV350,coordPinnedYellowV136,coordLiveYellowV128,coordManualRowV59,coordNearbyRowV18
    c := farmStartChoiceV2,pid := CoordDisplayGamePidV1()
    if (!IsObject(c) || c.pid!=pid || c.epoch!=farmRunEpochV535 || c.profile!=currentProfile
        || c.mapId!=routeMapIdV21 || !c.row || RoomRecordLevelV259(pid)!=c.level)
        return false
    row := c.row,point := coordSavedV15[row]
    if (!IsObject(point) || point.x!=c.x || point.y!=c.y || point.level!=c.level)
        return false
    coordYellowRowV350 := row,coordPinnedYellowV136 := row,coordLiveYellowV128 := row
    coordManualRowV59 := row,coordNearbyRowV18 := row
    return true
}

FarmGoFullStopV2()
{
    global farmManualStoppedV2026,farmUserPausedV2026,farmPauseTickV2026
    farmUserPausedV2026 := false,farmPauseTickV2026 := 0
    farmManualStoppedV2026 := true
    stopPidV500 := CoordDisplayGamePidV1()
    if (stopPidV500)
        FarmSkillBaselineEnsureV621(stopPidV500,true)
    FarmWatchStopV5()
    CainAllStopV387(false)
    CoordBoxRefreshV15(true)
    ToolTip,,,,20
    Gosub, MapControlButtonStatusV171
    FonInfoPushV385("STOP cạnh Go: dừng Farm, chuyển nhặt thường, bật F-OFF.")
}

; V2026 - Farm START button: Start -> Pause -> Tiep. STOP remains a full reset.
FarmUserPauseToggleV2026(owner)
{
    global farmUserPausedV2026,farmPauseTickV2026,farmControlOwnerV186,farmManualStoppedV2026
    global scosEntryV162,stageTwoV166,coordRouteV16,farmCenterCycleV741
    global mapWorkflowV185,mapButtonStartV172,farmDeadStartV695,mapStage1BuffDoneV248
    global farmReviveV32,farmWatchV5,farmErrorRetryAtV740,farmLastCombatTickV72
    global farmMapJournalRunV940
    if (farmControlOwnerV186!=owner || (!FarmControlRunningV186() && !farmUserPausedV2026))
        return false
    if (!farmUserPausedV2026)
    {
        farmUserPausedV2026 := true
        farmPauseTickV2026 := A_TickCount
        FarmAttackHoldReleaseV15()
        MovementCtrlSetV78(false,0,"FARM_PAUSE")
        PortalLogWriteV66("FARM_PAUSE owner=" . owner . " state=PRESERVED")
        FonInfoPushV385("[PAUSE] " . owner . " — giu trang thai, bam nut lan nua de chay tiep.")
    }
    else
    {
        gapV2026 := Max(0,A_TickCount-farmPauseTickV2026)
        for _,stateV2026 in [scosEntryV162,stageTwoV166,coordRouteV16,farmCenterCycleV741
            ,mapWorkflowV185,mapButtonStartV172,farmDeadStartV695,mapStage1BuffDoneV248,farmReviveV32]
            FarmUserPauseShiftV2026(stateV2026,gapV2026)
        if (farmErrorRetryAtV740>10000000)
            farmErrorRetryAtV740 += gapV2026
        if (farmLastCombatTickV72>10000000)
            farmLastCombatTickV72 += gapV2026
        if (IsObject(farmWatchV5))
        {
            farmWatchV5.idleAtV650 := FarmWatchNowV688()
            farmWatchV5.standSampleV650 := false
        }
        farmUserPausedV2026 := false,farmPauseTickV2026 := 0
        farmManualStoppedV2026 := false
        PortalLogWriteV66("FARM_CONTINUE owner=" . owner . " pause_ms=" . gapV2026 . " state=PRESERVED")
        FonInfoPushV385("[TIEP] " . owner . " — chay tiep trang thai cu.")
    }
    Gosub, MapControlButtonStatusV171
    return true
}

FarmUserPauseShiftV2026(state,elapsed)
{
    if (!IsObject(state) || elapsed<=0)
        return
    for name,value in state
    {
        if (IsObject(value))
            continue
        if (!RegExMatch(name,"i)(until|tick|time|since|start|last|retry|next|deadline|stamp|at$)"))
            continue
        if (RegExMatch(value . "","^\d+$") && value>10000000 && value<A_TickCount+604800000)
            state[name] := value+elapsed
    }
}

FarmButtonStopV1()
{
    global farmControlOwnerV186,farmGD2TestV644,farmManualStoppedV2026,farmUserPausedV2026,farmPauseTickV2026
    farmUserPausedV2026 := false,farmPauseTickV2026 := 0
    farmManualStoppedV2026 := true
    FarmElapsedStopV1350()
    owner := IsObject(farmGD2TestV644) ? farmGD2TestV644.previousOwner : farmControlOwnerV186
    FarmWatchStopV5()
    CainAllStopV387(false)
    farmControlOwnerV186 := owner
    CoordBoxRefreshV15(true)
    Gosub, MapControlButtonStatusV171
    FonInfoPushV385("Đã dừng Farm; chuyển nhặt thường, bật F-OFF.")
    return true
}


MapControlActionV168:
if (FarmControlRunningV186() || IsObject(farmMapPauseV52) || cainPausedV10)
{
    FarmButtonStopV1()
    return
}
farmManualStoppedV2026 := false ; explicit START, including GO / hotkey
if (FarmStartForcedV702(farmControlOwnerV186!="" ? farmControlOwnerV186 : "SCOS"))
    return
if (SigBackgroundBindV179() && FarmDeadStartBeginV695())
    return
if (FarmStartHealthV536(farmControlOwnerV186!="" ? farmControlOwnerV186 : "SCOS"))
{
    if (!FarmControlRunningV186())
        FarmStartKeepV697("GAME_HEALTH_WAIT")
    return
}
if (!BackgroundBindV63(mapControlGuiStartV180 ? backgroundHwndV63 : 0))
{
    RecoveryStartMissingGameV492(farmControlOwnerV186!="" ? farmControlOwnerV186 : "SCOS")
    if (!FarmControlRunningV186())
        FarmStartKeepV697("GAME_BIND_NOT_READY")
    return
}
; START chung V2026: khong khoa vao thanh / level cua nut.
; Nap file INI cho map nhan vat DANG DUNG, giu dong vang neu cung map da chon.
startMapOwnerV737 := farmControlOwnerV186!="" ? farmControlOwnerV186 : "SCOS"
startMapPidV2026 := CoordDisplayGamePidV1()
startMapLevelV737 := FarmCurrentLevelV143()
if (!startMapPidV2026 || !startMapLevelV737)
{
    FonInfoPushV385("[START] Chua doc duoc nhan vat/map; khong the chay toa do.")
    return
}
if (!FonTrackingEnableV410())
{
    FonInfoPushV385("[START] F-ON dang bi khoa do sua toa do; vui long ket thuc sua.")
    return
}
if (!FonLoadMapV382("START_YELLOW",startMapPidV2026,startMapLevelV737))
{
    FonInfoPushV385("[START] Map " . startMapLevelV737 . " chua co INI phu hop; chua bat Farm.")
    PortalLogWriteV66("START_YELLOW_ABORT level=" . startMapLevelV737 . " reason=MAP_FILE_NOT_READY")
    return
}
if (!IsObject(coordSavedV15) || !coordSavedV15.Length() || coordSavedV15[1].level!=startMapLevelV737)
{
    FonInfoPushV385("[START] File toa do khong trung map dang dung; chua bat Farm.")
    return
}
startYellowRowV2026 := FarmStartRowV394()
FarmStartPrepareV2(mapControlGuiStartV180)
if (!pickupImageOn)
    PickupEnabledSetV71(true,false,false)
mapWorkflowV185 := {map:startMapOwnerV737,stage:2,startLevel:startMapLevelV737,testRows:0}
autoMonsterAttackOn := true
MapStageSetV185(2)
PortalLogWriteV66("START_YELLOW_DIRECT owner=" . startMapOwnerV737 . " level=" . startMapLevelV737
    . " row=" . startYellowRowV2026 . " mapId=" . routeMapIdV21 . " town_gate=NONE stage1=SKIPPED")
FonInfoPushV385("[START] Nap map " . startMapLevelV737 . ", Farm tu dong vang " . startYellowRowV2026)
Gosub, AutoMonsterAttackToggle
return

FarmKeyReleaseTimerV124:
farmPhysicalKeyV124 := RegExReplace(autoMonsterToggleKeyV13,"^[~*$<>!^+#]+")
if (farmPhysicalKeyV124="" || !GetKeyState(farmPhysicalKeyV124,"P"))
{
    farmKeyHeldV124 := false
    SetTimer, FarmKeyReleaseTimerV124, Off
}
return

FarmStopV124(reason)
{
    global
    FarmElapsedStopV1350()
    if (reason="HOTKEY" || InStr(reason,"USER_STOP") || reason="USER_SWITCH_MAP_BUTTON")
    {
        FarmButtonStopV1()
        return
    }
    FarmAttackHoldReleaseV15()
    stopYellowV378 := coordYellowRowV350
    cainNoFightV361 := false,cainPauseFarmV361 := false
    farmMapPauseV52 := false,farmLoadedMapV56 := false
    farmStage3PendingV237 := false,sigFarmResumePendingV237 := false,farmRestartReasonV238 := ""
    SetTimer, FarmStage3RetryTimerV237, Off
    SetTimer, SigFarmResumeV152, Off
    StageTwoStopV166(reason)
    ScosEntryStopV162(reason)
    if (IsObject(sigTownV148) && reason!="SIG_SET_TOWN_TEST" && reason!="CUBE_FULL_SIG")
        SigTownCancelV148("USER_STOP " . reason)
    autoMonsterAttackOn := false,farmResumeArmedV70 := false,farmResumeOutsideV70 := false
    if (IsObject(coordRouteV16))
        coordRouteV16.escapeV84 := false,coordRouteV16.stuckProbe := false
    SetTimer, AutoMonsterAttackTimer, Off
    SetTimer, FarmResumeTimerV70, Off
    AutoMonsterAttackLogV2("FARM_CANCEL reason=" . reason . " escape=OFF revive_resume=OFF",true)
    Gosub, AutoMonsterAttackToggle
    coordYellowRowV350 := stopYellowV378
    coordMapReadyV381 := true
    coordMapAcceptedV381 := false
    farmStopMoveV124 := false
    SetTimer, FarmStopMoveTimerV124, Off
}

FarmStopMoveTimerV124:
if (farmManualStoppedV2026)
{
    SetTimer, FarmStopMoveTimerV124, Off
    return
}
if (!IsObject(farmStopMoveV124) || autoMonsterAttackOn || IsObject(coordGoV59)
    || A_TickCount>=farmStopMoveV124.until || !BackgroundValidV63())
{
    farmStopMoveV124 := false
    SetTimer, FarmStopMoveTimerV124, Off
    return
}
if (!AutoMonsterPacketCleanupV1())
    return
stopPidV124 := farmStopMoveV124.pid
stopBaseV124 := D2GetModuleBaseV35(stopPidV124,"D2Client.dll")
stopHV124 := stopBaseV124 ? D2OpenProcess(stopPidV124) : 0
if (!stopHV124)
    return
try
{
    stopPlayerV124 := D2ReadU32(stopHV124,stopBaseV124+0x11BBFC)
    stopPathV124 := stopPlayerV124 ? D2ReadU32(stopHV124,stopPlayerV124+0x2C) : 0
    if (MonsterBossProbeReadV1(stopHV124,stopPathV124,0x20,stopPBV124))
    {
        stopLevelV124 := CoordLevelV14(stopHV124,NumGet(stopPBV124,0x1C,"UInt"))
        if (!farmStopMoveV124.nearestSelectedV303)
        {
            CoordResumeNearestV303(stopHV124,stopPBV124,stopPidV124,"USER_STOP")
            farmStopMoveV124.nearestSelectedV303 := true
        }
        stopGoalV124 := {pid:stopPidV124,level:stopLevelV124,row:0,redirect:true,stop:true,resumeFarm:false}
        coordGoV59 := stopGoalV124
        try
            stopSentV124 := NativeMovePointV14(stopPidV124,NumGet(stopPBV124,2,"UShort"),NumGet(stopPBV124,6,"UShort"),stopLevelV124,true,false,true,stopGoalV124)
        finally
            if (coordGoV59=stopGoalV124)
                coordGoV59 := false
        if (stopSentV124)
        {
            AutoMonsterAttackLogV2("FARM_STOP_MOVE point=LIVE_PLAYER_POSITION",true)
            farmStopMoveV124 := false
            SetTimer, FarmStopMoveTimerV124, Off
        }
    }
}
finally
    DllCall("CloseHandle","Ptr",stopHV124)
return

PetLearnKeyHandlerV13:
if (!IsGameForegroundV63())
    return
if (!IsGameActive())
    return
PetLearnRunV137(false)
KeyWait, %petLearnKeyV13%
return

PetLearnRunV137(fromGui := false)
{
    global petLearnOnV12,petLearnDoneV12,petBossGetTargetV222,sigBusyV147,packetWatchArmedV1,xRunning,zRunning
    global petLearnEnabledV12
    if (petLearnOnV12 || sigBusyV147 || packetWatchArmedV1 || xRunning || zRunning)
        return
    petLearnOnV12 := true,petLearnDoneV12 := false
    try
    {
        if (petBossGetTargetV222="BOSS")
        {
            if (!BossPriorityGetNearestV221(fromGui))
            {
                ToolTipInfoV386("Chưa lấy được Class ID boss. Đặt chuột lên boss rồi bấm phím GET.")
                SetTimer, RemoveToolTip, -2500
            }
            return
        }
        if (!petLearnEnabledV12)
        {
            ToolTipInfoV386("GET ID PET đang TẮT. Bật checkbox 'GET ID' cạnh nhãn PET để sử dụng.")
            SetTimer, RemoveToolTip, -3000
            return
        }
        GuiControlGet, editedPetV222, 1:, PetExcludeListV16
        if (!PetExcludeCommitV10(editedPetV222))
            return
        if (!PetLearnNearestV12(fromGui))
        {
            ToolTipInfoV386("Chưa lấy được Class ID pet. Đặt chuột lên pet rồi bấm phím GET.")
            SetTimer, RemoveToolTip, -2500
        }
    }
    finally
        petLearnOnV12 := false
}

MonsterKeysBindV13()
{
    global autoMonsterToggleKeyV13, petLearnKeyV13, coordGetKeyV14
    static oldAuto := "", oldPet := "", oldCoord := ""
    if (oldAuto!="")
    {
        BackgroundHotkeyV63("~$" . oldAuto,"AutoMonsterToggleKeyHandlerV13","Off UseErrorLevel")
    }
    if (oldPet!="")
        BackgroundHotkeyV63("~$" . oldPet,"PetLearnKeyHandlerV13","Off UseErrorLevel")
    if (oldCoord!="")
        BackgroundHotkeyV63("~$" . oldCoord,"CoordGetKeyHandlerV14","Off UseErrorLevel")
    oldCoord := coordGetKeyV14
    oldAuto := autoMonsterToggleKeyV13, oldPet := petLearnKeyV13
    if (oldAuto!="")
    {
        BackgroundHotkeyV63("~$" . oldAuto,"AutoMonsterToggleKeyHandlerV13","On P10 T2 UseErrorLevel")
    }
    if (oldPet!="")
        BackgroundHotkeyV63("~$" . oldPet,"PetLearnKeyHandlerV13","On UseErrorLevel")
    if (oldCoord!="")
        BackgroundHotkeyV63("~$" . oldCoord,"CoordGetKeyHandlerV14","On UseErrorLevel")
}

MonsterKeysValidateV13(autoKey,petKey,coordKey := "")
{
    global DoubleKey, FormDoubleKey, QCastDoubleKey, ClickCastKeyInput, XKey, ZRunKey
    global Belt4HPKey,Belt2HP2ManaKey,InvToCubeKey,Master456KeyInput,farmNaoKeyV181,sigKeyV147,sigSuKeyV181
    if ((autoKey!="" && (MapHotkeysMatchV178(autoKey,petKey) || MapHotkeysMatchV178(autoKey,coordKey)))
        || (petKey!="" && MapHotkeysMatchV178(petKey,coordKey)))
    {
        MsgBox, 48, Lỗi, Phím tự đánh, GET pet và GET tọa độ không được trùng nhau.
        return false
    }
    for _,key in [autoKey,petKey,coordKey]
    {
        if (key="")
            continue
        if (!GetKeyVK(RegExReplace(key,"^\^")) && !GetKeySC(RegExReplace(key,"^\^")))
        {
            MsgBox, 48, Lỗi, Phím tự đánh / GET pet / GET tọa độ không hợp lệ.
            return false
        }
        for _,used in [DoubleKey,FormDoubleKey,QCastDoubleKey,ClickCastKeyInput,XKey,ZRunKey,Belt4HPKey,Belt2HP2ManaKey,InvToCubeKey,Master456KeyInput,farmNaoKeyV181,sigKeyV147,sigSuKeyV181]
        {
            if (MapHotkeysMatchV178(key,used))
            {
                MsgBox, 48, Lỗi, Phím tự đánh / GET pet / GET tọa độ trùng phím chức năng khác.
                return false
            }
        }
    }
    return true
}

CoordGetKeyHandlerV14:
if (!IsGameForegroundV63())
    return
if (!IsGameActive())
    return
if (!CoordCaptureV14())
{
    ToolTipInfoV386("Chưa lấy được tọa độ map - vào game rồi bấm lại.")
    SetTimer, RemoveToolTip, -2500
}
KeyWait, %coordGetKeyV14%
return

CoordLevelV14(h,room)
{
    r2 := room ? D2ReadU32(h,room+0x10) : 0
    level := r2 ? D2ReadU32(h,r2+0x58) : 0
    return level ? D2ReadU32(h,level+0x1D0) : 0
}

CoordCaptureV14(updateYellowV131 := false,addAfterYellowV136 := false)
{
    FonEditBeginV414()
    try
        return CoordCaptureCoreV414(updateYellowV131,addAfterYellowV136)
    finally
        FonEditEndV414()
}

CoordCaptureCoreV414(updateYellowV131,addAfterYellowV136)
{
    global coordSavedV15,coordLiveYellowV128,coordNearbyRowV18,coordManualRowV59
    global coordPointTextV14,coordPointLevelV14,coordCurrentTextV15,coordCurrentRoomV130
    global roomRecordV108,autoMonsterAttackOn,coordGoV59,currentProfile
    global coordEditPointV127,coordInsertAnchorV57
    global coordPinnedYellowV136,coordYellowRowV350,routePreviewV401
    if (IsObject(roomRecordV108))
    {
        ToolTipInfoV386("Dừng lưu phòng hoặc ghi chèn trước khi GET tọa độ.")
        SetTimer, RemoveToolTip, -2500
        return true
    }
    pid := (updateYellowV131 || addAfterYellowV136) ? CoordDisplayGamePidV1() : D2GetActiveGamePidV95()
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? DllCall("OpenProcess","UInt",0x0410,"Int",0,"UInt",pid,"Ptr") : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return false
        x := NumGet(pb,2,"UShort"),y := NumGet(pb,6,"UShort")
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        if (!x || !y || !level || (!updateYellowV131 && !addAfterYellowV136 && D2GetActiveGamePidV95()!=pid))
            return false
        file := RoomProfileFileV108(),roomMode := FileExist(file)
        if (roomMode)
        {
            if (MapRouteHintV400(file)!=level)
            {
                if (!RoomRecordSelectLiveV400())
                    return true
                file := RoomProfileFileV108(),roomMode := FileExist(file)
                if (!roomMode || MapRouteHintV400(file)!=level)
                    return false
            }
            diskDataV401 := RoomMapReadV109(file,false,level)
            if (IsObject(diskDataV401))
                coordSavedV15 := diskDataV401.points
            else
            {
                sectionV401 := "Route-" . level
                IniRead, diskCountV401, %file%, %sectionV401%, Count, 0
                if (diskCountV401!=0)
                {
                    ToolTipInfoV386("Không đọc được lộ trình trong file đang chọn. Chưa ghi đè tọa độ.")
                    SetTimer, RemoveToolTip, -3500
                    return true
                }
                coordSavedV15 := []
            }
        }
        if (coordSavedV15.Length() && coordSavedV15[1].level!=level)
        {
            ToolTipInfoV386("Nhân vật đang ở map khác với lộ trình. Không chèn tọa độ.")
            SetTimer, RemoveToolTip, -2500
            return true
        }
        number := -1
        if (roomMode)
        {
            node := RoomExploreReadV89(h,D2ReadU32(h,NumGet(pb,0x1C,"UInt")+0x10),level)
            number := RoomRouteNumberV105(node,file)
            if (number<0)
                return false
        }
        anchor := CoordYellowIndexV48()
        insertAt := coordSavedV15.Length()+1
        if (addAfterYellowV136)
            insertAt := anchor>=1 && anchor<=coordSavedV15.Length() ? anchor+1 : 1
        oldPointV131 := false
        if (updateYellowV131)
        {
            if (anchor<1 || anchor>coordSavedV15.Length())
            {
                ToolTipInfoV386("Chọn dòng vàng cần cập nhật trước khi bấm UPDATE.")
                SetTimer, RemoveToolTip, -2500
                return true
            }
            insertAt := anchor,oldPointV131 := coordSavedV15[anchor]
            if (oldPointV131.level!=level)
            {
                ToolTipInfoV386("Nhân vật phải ở đúng map (level) của dòng vàng để UPDATE.")
                SetTimer, RemoveToolTip, -3000
                return true
            }
        }
        if (autoMonsterAttackOn || IsObject(coordGoV59))
            FarmStopV124(updateYellowV131 ? "UPDATE_YELLOW_COORDINATE" : "GET_INSERT_COORDINATE")
        newPoint := updateYellowV131 ? oldPointV131.Clone() : {x:x,y:y,level:level}
        newPoint.x := x,newPoint.y := y
        if (roomMode && !updateYellowV131)
            newPoint.roomNumber := number
        if (updateYellowV131)
            coordSavedV15[insertAt] := newPoint
        else
            coordSavedV15.InsertAt(insertAt,newPoint)
        if (roomMode && !RoomMapPointsWriteV126(file,level,coordSavedV15))
        {
            if (updateYellowV131)
                coordSavedV15[insertAt] := oldPointV131
            else
                coordSavedV15.RemoveAt(insertAt)
            ToolTipInfoV386("Không ghi được tọa độ vào file map. Giữ nguyên lộ trình.")
            SetTimer, RemoveToolTip, -3000
            return true
        }
        coordEditPointV127 := false,coordInsertAnchorV57 := false,coordManualRowV59 := insertAt
        coordNearbyRowV18 := insertAt
        coordPinnedYellowV136 := insertAt
        coordLiveYellowV128 := roomMode ? insertAt : 0
        coordYellowRowV350 := insertAt
        coordCurrentRoomV130 := number
        coordPointTextV14 := x . "," . y,coordCurrentTextV15 := coordPointTextV14,coordPointLevelV14 := level
        CoordRouteResetV16()
        CoordSavedStoreV15(currentProfile)
        routePreviewV401 := true
        RouteMapRefreshV21(false)
        SetTimer, CoordCurrentTimerV15, 500
        CoordBoxRefreshV15(true)
        ToolTipInfoV386((updateYellowV131 ? "Đã cập nhật dòng vàng " : addAfterYellowV136 ? "Đã thêm dưới dòng vàng " : "Đã thêm dòng cuối ") . (insertAt+1) . ": " . x . "," . y)
        SetTimer, RemoveToolTip, -2500
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

; Khi farm da nhan tin vat pham, khoa lenh di tu lo trinh cu.
; Khong anh huong lenh di chuyen rieng den tam nhat (FarmItemReturnV648).
FarmItemRoutePausedV903(pid)
{
    global autoMonsterAttackOn,farmItemLockV625
    return autoMonsterAttackOn && IsObject(farmItemLockV625)
        && farmItemLockV625.pid=pid
}

CoordMoveWhenClearV14(h,ByRef pb,pid)
{
    routePointsV724 := FarmRoutePointsV724()
    global coordRouteV16,coordNoTargetSinceV14,monsterCombatUidV45,teleportIntervalSecV56,monsterRoadAreaV51,monsterChaseV44,monsterRetryUntilV44
    global portalBackPendingV74,chaseCheckSecV9
    ; Uu tien vat pham: khong phat lenh di tuyen cu ke ca khi timer farm chen vao.
    if (FarmItemRoutePausedV903(pid))
        return false
    if (BOCommonActiveV444(pid))
        return BOCommonMoveV444(h,pb,pid)
    if (IsObject(portalBackPendingV74))
        return false
    if (monsterCombatUidV45)
        return false
    if (!NativeDispatchReadyV10(true) || !routePointsV724.Length())
        return false
    CoordRouteObserveV18(h,pb,pid)
    r := coordRouteV16
    if (!IsObject(r) || !r.next || r.phase="BLOCKED")
        return false
    if (r.battlePending)
    {
        r.battlePending := false
        AutoMonsterAttackLogV2("ROUTE_RESUME phase=" . r.phase . " destination_row=" . (r.next+1))
    }
    if (!coordNoTargetSinceV14)
        coordNoTargetSinceV14 := A_TickCount
    if (A_TickCount-coordNoTargetSinceV14<250)
        return false
    if (r.phase="DONE")
    {
        MapStage2RouteFinishV185()
        return true
    }
    if (r.phase="CLEAR")
    {
        if (r.next>=routePointsV724.Length())
        {
            r.phase := "DONE"
            AutoMonsterAttackLogV2("ROUTE_END last_row=" . (r.anchor+1) . " next=TOWN_CUBE_STAGE2")
            MapStage2RouteFinishV185()
            return true
        }
        r.next++, r.phase := "NEXT"
        r.tries := 0, r.bestDist := -1, r.lastDispatch := 0, r.moveProbe := false
        coordNoTargetSinceV14 := 0
        AutoMonsterAttackLogV2("ROUTE_NEXT from_row=" . (r.anchor+1) . " destination_row=" . (r.next+1) . " return_to_previous=0")
        CoordBoxRefreshV15()
        return true
    }
    idx := r.next
    if (idx<1 || idx>routePointsV724.Length())
        return false
    point := routePointsV724[idx]
    if (CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=point.level)
    {
        AutoMonsterAttackLogV2("ROUTE_WAIT reason=DIFFERENT_MAP row=" . (idx+1),true)
        return false
    }
    px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
    dist := (px-point.x)*(px-point.x)+(py-point.y)*(py-point.y)
    if (r.bestDist<0 || dist<r.bestDist-1)
        r.bestDist := dist, r.tries := 0
    if (r.tries>=3 && A_TickCount-r.lastDispatch>=1800)
    {
        AutoMonsterAttackLogV2("ROUTE_NO_PROGRESS row=" . (idx+1) . " player=" . px . "," . py . " target=" . point.x . "," . point.y . " return_to_start=0",true)
        r.tries := 0
    }
    if (A_TickCount-r.lastDispatch<250)
        return false
    if (CoordStuckMoveV392(pid,point.x,point.y,point.level,r,idx))
    {
        if (!IsObject(r.stuckProbe))
            r.stuckProbe := {x:px,y:py,since:A_TickCount}
        r.lastDispatch := A_TickCount, r.tries++
        r.moveProbe := {x:px,y:py,row:idx+1,at:A_TickCount,reported:false}
        AutoMonsterAttackLogV2("ROUTE_MOVE row=" . (idx+1) . " phase=" . r.phase . " yellow_row=" . (r.yellow+1) . " from=" . px . "," . py . " to=" . point.x . "," . point.y)
        return true
    }
    return false
}

CoordMoveReadyV60(pid,manualGo := false,portalGo := false)
{
    global coordGoV59, autoMonsterAttackOn, packetWatchArmedV1, zRunning, xRunning, gameItemActionOwner, petLearnOnV12
    global farmReviveV32, scosEntryV162
    if (!manualGo && !portalGo && IsObject(scosEntryV162))
        return scosEntryV162.pid=pid && BackgroundValidV63() && !packetWatchArmedV1
            && !zRunning && !xRunning && gameItemActionOwner=""
    if (portalGo)
        return IsObject(farmReviveV32) && farmReviveV32.pid=pid
            && autoMonsterAttackOn
            && IsGameActive() && D2GetActiveGamePidV95()=pid && !packetWatchArmedV1
            && !petLearnOnV12 && !zRunning && !xRunning && gameItemActionOwner=""
    if (!manualGo)
        return NativeDispatchReadyV10(true)
    global farmItemLockV625
    if (IsObject(farmItemLockV625) && FarmItemGoalValidV655(farmItemLockV625.returnGoalV655)
        && farmItemLockV625.pid=pid)
        return NativeDispatchReadyV10(true)
    return IsObject(coordGoV59) && coordGoV59.pid=pid && !autoMonsterAttackOn
        && IsGameActive() && D2GetActiveGamePidV95()=pid && !packetWatchArmedV1
        && !petLearnOnV12 && !zRunning && !xRunning && gameItemActionOwner=""
}

MovementCtrlSetV78(hold, pid := 0, reason := "UNSPECIFIED")
{
    global movementCtrlHeldV78, movementCtrlPidV78, movementCtrlGraceV78
    hold := false
    if (!hold)
    {
        oldPid := movementCtrlPidV78
        wasHeld := movementCtrlHeldV78
        movementCtrlHeldV78 := false, movementCtrlPidV78 := 0
        SetTimer, MovementCtrlTimerV78, Off
        if (wasHeld && oldPid)
        {
            AutoMonsterAttackLogV2("RUN_RELEASE_REQUEST reason=" . reason . " pid=" . oldPid)
            NativeRunKeyV83(oldPid,false)
        }
        return true
    }
    if (movementCtrlHeldV78 && movementCtrlPidV78!=pid)
        MovementCtrlSetV78(false,0,"MovementCtrlSetV78")
    if (!NativeRunKeyV83(pid,true))
        return false
    movementCtrlHeldV78 := true, movementCtrlPidV78 := pid
    movementCtrlGraceV78 := A_TickCount+150
    SetTimer, MovementCtrlTimerV78, 50
    return true
}

MovementCtrlTimerV78:
MovementCtrlWatchV78()
return

MovementCtrlWatchV78()
{
    MovementCtrlSetV78(false,0,"CTRL_MOVEMENT_DISABLED")
    return
    global movementCtrlHeldV78, movementCtrlPidV78, movementCtrlGraceV78
    global autoMonsterAttackOn, coordGoV59, xRunning, zRunning, gameItemActionOwner
    if (!movementCtrlHeldV78)
        return
    if ((!autoMonsterAttackOn && !IsObject(coordGoV59)) || !IsGameActive()
        || D2GetActiveGamePidV95()!=movementCtrlPidV78 || xRunning || zRunning)
    {
        MovementCtrlSetV78(false,0,"WATCH_CONTEXT")
        return
    }
    pid := movementCtrlPidV78
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
    {
        MovementCtrlSetV78(false,0,"WATCH_PLAYER mode=" . mode)
        return
    }
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        mode := player ? D2ReadU32(h,player+0x10) : -1
        held := D2ReadU32(h,base+0x11C3E8)
    }
    finally
        DllCall("CloseHandle","Ptr",h)
    if ((mode!=2 && mode!=3 && mode!=6) && A_TickCount>=movementCtrlGraceV78)
        MovementCtrlSetV78(false,0,"WATCH_PLAYER mode=" . mode)
    else if (mode=2 || ((mode=3 || mode=6) && !held))
        NativeRunKeyV83(pid,true)
}

NativeRunKeyV83(pid,hold)
{
    global nativeRunPendingV83
    previousRunCriticalV83 := A_IsCritical
    Critical, On
    try
    {
    NativeRunCleanupV83()
    if (IsObject(nativeRunPendingV83))
        return false
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? DllCall("OpenProcess","UInt",0x043A,"Int",0,"UInt",pid,"Ptr") : 0
    if (!h)
        return false
    remote := 0, owned := false
    try
    {
        if (!MonsterBossProbeReadV1(h,base+0x3AE40,20,downEntry)
            || MonsterBossProbeHexV1(downEntry,20)!="568B35FCBBBC6F85F6C705E8C3BC6F0100000074"
            || !MonsterBossProbeReadV1(h,base+0x3ADF0,20,upEntry)
            || MonsterBossProbeHexV1(upEntry,20)!="51568B35FCBBBC6F85F6C705E8C3BC6F00000000")
            return false
        player := D2ReadU32(h,base+0x11BBFC)
        if (!player)
            return false
        before := D2ReadU32(h,base+0x11C3E8)
        beforeMode := D2ReadU32(h,player+0x10)
        rva := hold ? 0x3AE40 : 0x3ADF0
        hex := "60B8" . NativeLE32V9(base+rva) . "FFD06131C0C20400"
        length := StrLen(hex)//2
        VarSetCapacity(code,length,0)
        Loop, %length%
            NumPut("0x" . SubStr(hex,(A_Index-1)*2+1,2),code,A_Index-1,"UChar")
        remote := DllCall("VirtualAllocEx","Ptr",h,"Ptr",0,"UPtr",length,"UInt",0x3000,"UInt",0x40,"Ptr")
        if (!remote || remote>0xFFFFFFFF
            || !DllCall("WriteProcessMemory","Ptr",h,"Ptr",remote,"Ptr",&code,"UPtr",length,"UPtrP",written) || written!=length)
            return false
        DllCall("FlushInstructionCache","Ptr",h,"Ptr",remote,"UPtr",length)
        thread := DllCall("CreateRemoteThread","Ptr",h,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
        if (!thread)
            return false
        nativeRunPendingV83 := {process:h,remote:remote,thread:thread}
        owned := true
        wait := DllCall("WaitForSingleObject","Ptr",thread,"UInt",100,"UInt")
        if (wait=0)
        {
            DllCall("GetExitCodeThread","Ptr",thread,"UIntP",exitCode)
            after := D2ReadU32(h,base+0x11C3E8)
            afterMode := D2ReadU32(h,player+0x10)
            AutoMonsterAttackLogV2("RUN_KEY_DLL hold=" . hold . " rva=" . V92Hex(rva) . " flag_before=" . before . " flag_after=" . after
                . " mode_before=" . beforeMode . " mode_after=" . afterMode . " exit_code=" . exitCode . " keyboard_sent=0 speed=UNCONFIRMED")
            NativeRunCleanupV83()
            return exitCode=0
        }
        AutoMonsterAttackLogV2("RUN_KEY_DLL_PENDING hold=" . hold . " wait=" . wait)
        SetTimer, NativeRunCleanupTimerV83, 50
        return false
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
    finally
    {
        if (previousRunCriticalV83)
            Critical, %previousRunCriticalV83%
        else
            Critical, Off
    }
}

NativeRunCleanupTimerV83:
NativeRunCleanupV83()
return

NativeRunCleanupV83()
{
    global nativeRunPendingV83
    p := nativeRunPendingV83
    if (!IsObject(p))
    {
        SetTimer, NativeRunCleanupTimerV83, Off
        return
    }
    if (DllCall("WaitForSingleObject","Ptr",p.thread,"UInt",0,"UInt")!=0)
        return
    DllCall("CloseHandle","Ptr",p.thread)
    DllCall("VirtualFreeEx","Ptr",p.process,"Ptr",p.remote,"UPtr",0,"UInt",0x8000)
    DllCall("CloseHandle","Ptr",p.process)
    nativeRunPendingV83 := false
    SetTimer, NativeRunCleanupTimerV83, Off
}

NativeMovePointV14(pid,x,y,levelWanted := 0,manualGo := false,portalGo := false,allowShort := false, goGoal := false, routeGuard := false)
{
    ; No concurrent B->C/normal item move while an item escape owns movement.
    ; The recovery's own NativeMovePointV14(...,goGoal=itemGoal) remains allowed.
    global farmItemLockV625
    if (FarmItemEscapeActiveV20261029(pid)
        && (!manualGo || !IsObject(goGoal)
            || goGoal!=farmItemLockV625.returnGoalV655))
    {
        PortalLogWriteV66("FARM_ITEM_ESCAPE_BLOCK_OLD_MOVE target=" . x . "," . y
            ,"FARM_ITEM_ESCAPE_BLOCK_OLD_MOVE",1000)
        return false
    }
    if (!FarmAttackHoldReleaseV15())
        return false
    global stage2FlowV380,farmReviveV32
    global autoMonsterPacketPendingV1, coordPointLevelV14, coordGoV59, coordRouteV16,mapMoveDistanceV197,scosEntryV162,combatRecoverV48,combatMildRecoverV299,monsterRadiusV48
    if (IsObject(scosEntryV162) && scosEntryV162.map="BO" && scosEntryV162.pid=pid
        && scosEntryV162.phase="LOAD" && !scosEntryV162.buffDoneV413)
    {
        PortalLogWriteV66("BO_ENTRY_MOVE_BLOCKED reason=BUFF_AT_PORTAL requested=" . x . "," . y,"BO_ENTRY_MOVE_BLOCKED",1000)
        return false
    }
    if (IsObject(routeGuard) && IsObject(routeGuard.searchV430))
    {
        searchV479 := routeGuard.searchV430,scanV479 := searchV479.commonScanV446
        if (searchV479.owner="BO" && !routeGuard.stop && IsObject(scanV479) && scanV479.target
            && A_TickCount-scanV479.at<500)
        {
            PortalLogWriteV66("BO_MOVE_BLOCKED reason=MONSTER_IN_RADIUS next=ATTACK","BO_MOVE_BLOCKED",1000)
            return false
        }
    }
    if (manualGo && (!IsObject(goGoal) || !CoordRecoveryGoalValidV655(goGoal)))
        return false
    if (!levelWanted)
        levelWanted := coordPointLevelV14
    if (!CoordMoveReadyV60(pid,manualGo,portalGo) || D2GetActiveGamePidV95()!=pid || !AutoMonsterPacketCleanupV1())
        return false
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? DllCall("OpenProcess","UInt",0x043A,"Int",0,"UInt",pid,"Ptr") : 0
    if (!h)
        return false
    remote := 0, owned := false
    try
    {
        if (!NativeRightClickBuildV9(h,base)
            || !MonsterBossProbeReadV1(h,base+0x1A010,17,entry)
            || MonsterBossProbeHexV1(entry,17)!="558B6C240C568B752C505156E8CD23FFFF"
            || !MonsterBossProbeReadV1(h,base+0x186A0,13,prepareEntry)
            || MonsterBossProbeHexV1(prepareEntry,13)!="83EC14558B6C2420568B742420")
            return false
        player := D2ReadU32(h,base+0x11BBFC), mode := player ? D2ReadU32(h,player+16) : 0
        redirectMove := manualGo && IsObject(goGoal) && goGoal.redirect && (mode=2 || mode=3 || mode=6)
        reviveMoveV720 := portalGo && IsObject(farmReviveV32) && farmReviveV32.pid=pid
            && IsObject(routeGuard) && routeGuard.revive=farmReviveV32
        routeMoveV197 := !manualGo && !portalGo && IsObject(routeGuard)
            && routeGuard.route=coordRouteV16 && coordRouteV16.phase="NEXT"
            && routeGuard.row=coordRouteV16.next && routeGuard.row=coordRouteV16.anchor+1
        entryGoalV49 := scosEntryV162
        entryMoveV49 := !manualGo && !portalGo && IsObject(entryGoalV49)
            && entryGoalV49.pid=pid && BackgroundValidV63()
        recoverMoveV298 := !manualGo && !portalGo && IsObject(routeGuard)
            && IsObject(combatRecoverV48) && routeGuard.recover=combatRecoverV48
            && combatRecoverV48.pid=pid && combatRecoverV48.level=levelWanted
        searchMoveV430 := IsObject(routeGuard) && IsObject(routeGuard.searchV430)
            && BossSearchActiveV430(pid,levelWanted) && stage2FlowV380.searchV430=routeGuard.searchV430
        escapeStopV642 := IsObject(routeGuard) && IsObject(routeGuard.escapeStopV642)
            && ((routeMoveV197 && coordRouteV16.escapeV84=routeGuard.escapeStopV642)
                || (manualGo && IsObject(goGoal.routeV392) && goGoal.routeV392.escapeV84=routeGuard.escapeStopV642))
        routeRedirectV197 := (routeMoveV197 || entryMoveV49 || recoverMoveV298 || searchMoveV430 || escapeStopV642) && (mode=2 || mode=3 || mode=6)
        if (mode!=1 && mode!=5 && !redirectMove && !routeRedirectV197
            && !(reviveMoveV720 && (mode=2 || mode=3 || mode=6)))
        {
            AutoMonsterAttackLogV2("MAP_MOVE_WAIT player_mode=" . mode, true)
            return false
        }
        path := D2ReadU32(h,player+0x2C)
        if (!MonsterBossProbeReadV1(h,path,0x20,pb)
            || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=levelWanted)
            return false
        inv := D2ReadU32(h,player+0x60), cursor := inv ? PickupCursorV4(h,inv) : false
        if (!IsObject(cursor) || cursor.unit)
            return false
        px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
        distance := Sqrt((x-px)*(x-px)+(y-py)*(y-py))
        stopGo := escapeStopV642 || (manualGo && IsObject(goGoal) && goGoal.stop) || (recoverMoveV298 && routeGuard.stop)
            || (reviveMoveV720 && routeGuard.stop)
            || (searchMoveV430 && routeGuard.stop)
            || (entryMoveV49 && IsObject(routeGuard) && routeGuard.entry=entryGoalV49 && routeGuard.stop)
        ; ITEM_MOVE FIX: Dich tam vat pham phai duoc di toi truoc,
        ; roi moi quet/danh BK/2. Khong de FarmApproachScanV722 chan lenh
        ; di den vat pham vi co quai tren duong.
        if (!stopGo && routeMoveV197)
        {
            closeScanV722 := FarmApproachScanV722(h,player,pid)
            if (IsObject(closeScanV722) && (!closeScanV722.complete || IsObject(closeScanV722.target)))
                return false
        }
        if (!stopGo && distance=0)
            return false
        stepLimitV197 := recoverMoveV298 ? Max(1,monsterRadiusV48*1.5,MapMoveDistanceGetV51()) : MapMoveDistanceGetV51()
        if (!stepLimitV197)
            return false
        if (searchMoveV430 && routeGuard.searchV430.owner="BO")
            stepLimitV197 := Min(stepLimitV197,Max(1,MonsterRadiusGetV239())*2)
        nativePathingV505 := !stopGo
        ratio := distance>stepLimitV197 ? stepLimitV197/distance : 1
        stepX := Round(px+(x-px)*ratio), stepY := Round(py+(y-py)*ratio)
        if (stepX<1 || stepX>65535 || stepY<1 || stepY>65535)
            return false
        commonPathV505 := nativePathingV505 ? D2GetModuleBaseV35(pid,"D2Common.dll") : 0
        if (nativePathingV505 && (!commonPathV505
            || !MonsterBossProbeReadV1(h,commonPathV505+0x34F80,13,typeEntryV503)
            || MonsterBossProbeHexV1(typeEntryV503,13)!="8B4424048B483085C98B542408"))
            return false
        dataOffsetV503 := nativePathingV505 ? 128 : 0
        allocationV503 := nativePathingV505 ? 512 : 256
        remote := DllCall("VirtualAllocEx","Ptr",h,"Ptr",0,"UPtr",allocationV503,"UInt",0x3000,"UInt",0x40,"Ptr")
        if (!remote || remote>0xFFFFFFFF)
            return false
        moveCommand := 1
        hex := NativeMoveCodeV19(remote+dataOffsetV503,base,player,moveCommand,nativePathingV505,commonPathV505)
        VarSetCapacity(blob,allocationV503,0), length := StrLen(hex)//2
        if (length<1 || length>128+dataOffsetV503)
            return false
        Loop, %length%
            NumPut("0x" . SubStr(hex,(A_Index-1)*2+1,2),blob,A_Index-1,"UChar")
        moveFlags := (Abs(stepX-px)<3 && Abs(stepY-py)<3) ? 0x11 : 1
        NumPut(moveFlags,blob,128+dataOffsetV503,"UInt"), NumPut(player,blob,132+dataOffsetV503,"UInt")
        NumPut(stepX,blob,140+dataOffsetV503,"UInt"), NumPut(stepY,blob,144+dataOffsetV503,"UInt")
        NumPut(1,blob,148+dataOffsetV503,"UInt")
        NumPut(stepX,blob,216+dataOffsetV503,"UInt"), NumPut(stepY,blob,220+dataOffsetV503,"UInt")
        NumPut(0xFFFFFFFF,blob,196+dataOffsetV503,"UInt")
        if (!DllCall("WriteProcessMemory","Ptr",h,"Ptr",remote,"Ptr",&blob,"UPtr",allocationV503,"UPtrP",written) || written!=allocationV503)
            return false
        DllCall("FlushInstructionCache","Ptr",h,"Ptr",remote,"UPtr",length)
        previousGoCriticalV76 := A_IsCritical
        Critical, On
        try
        {
            if (!CoordMoveReadyV60(pid,manualGo,portalGo) || D2GetActiveGamePidV95()!=pid
                || (manualGo && !CoordRecoveryGoalValidV655(goGoal))
                || (escapeStopV642 && (manualGo ? goGoal.routeV392.escapeV84!=routeGuard.escapeStopV642
                    : coordRouteV16.escapeV84!=routeGuard.escapeStopV642))
                || (entryMoveV49 && scosEntryV162!=entryGoalV49)
                || (IsObject(routeGuard) && !manualGo && (IsObject(routeGuard.revive)
                    ? (!reviveMoveV720 || farmReviveV32!=routeGuard.revive)
                    : IsObject(routeGuard.recover) ? (combatRecoverV48!=routeGuard.recover || combatRecoverV48.pid!=pid || combatRecoverV48.level!=levelWanted)
                    : IsObject(routeGuard.searchV430) ? (!BossSearchActiveV430(pid,levelWanted)
                        || stage2FlowV380.searchV430!=routeGuard.searchV430)
                    : IsObject(routeGuard.entry) ? (scosEntryV162!=routeGuard.entry || routeGuard.entry.pid!=pid)
                    : (coordRouteV16!=routeGuard.route || coordRouteV16.next!=routeGuard.row
                        || routeGuard.row!=coordRouteV16.anchor+1))))
                return false
            MovementCtrlSetV78(false,0,"MOVE_WITHOUT_CTRL")
            thread := DllCall("CreateRemoteThread","Ptr",h,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
            if (!thread)
            {
                MovementCtrlSetV78(false,0,"NativeMovePointV14")
                return false
            }
            autoMonsterPacketPendingV1 := {process:h,remote:remote,thread:thread,uid:0,kind:"MAP_MOVE",moveCall:true,resultOffsetV503:192+dataOffsetV503,setAt:A_TickCount}
            routeV465 := manualGo && IsObject(goGoal) ? goGoal.routeV392
                : IsObject(routeGuard) ? routeGuard.route : false
            if (levelWanted=163 && IsObject(routeV465) && !IsObject(routeV465.obstacleV465))
            {
                wV465 := routeV465.walkWindowV465
                if (!IsObject(wV465) || wV465.row!=routeV465.next)
                    routeV465.walkWindowV465 := wV465 := {row:routeV465.next,x:px,y:py,since:A_TickCount,queued:0}
                wV465.queued++
            }
            owned := true
            if (searchMoveV430 && routeGuard.searchV430.owner="BO")
                routeGuard.searchV430.walkingV482 := !stopGo
            SetTimer, AutoMonsterPacketCleanupTimerV1, 50
            AutoMonsterAttackLogV2("MAP_MOVE_DISPATCH point=" . x . "," . y . " method=" . (nativePathingV505 ? "NATIVE_PATH_MODE1" : "PREPARE_THEN_MOVE") . " step=" . stepX . "," . stepY . " from=" . px . "," . py . " move_input=" . stepLimitV197 . " prepare_flags=" . V92Hex(moveFlags) . " mode=" . moveCommand . " move_interval_ms=250 mouse_moved=0 effect=UNCONFIRMED")
            return true
        }
        finally
        {
            if (previousGoCriticalV76)
                Critical, %previousGoCriticalV76%
            else
                Critical, Off
        }
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

CoordRoomLiveCountV133(h,ByRef pb)
{
    room := NumGet(pb,0x1C,"UInt")
    if (!room)
        return -1
    u := D2ReadU32(h,room+0x74),seen := {},count := 0,start := A_TickCount
    while (u)
    {
        if (seen.HasKey(u) || seen.Count()>=2048 || A_TickCount-start>80
            || !MonsterBossProbeReadV1(h,u,0xEC,ub))
            return -1
        seen[u] := true
        if (NumGet(ub,0,"UInt")=1 && NumGet(ub,0x10,"UInt")!=0 && NumGet(ub,0x10,"UInt")!=12
            && !MonsterClassExcludedV11(NumGet(ub,4,"UInt"),h,u))
        {
            if (!MonsterBossProbeReadV1(h,NumGet(ub,0x2C,"UInt"),0x20,mp))
                return -1
            if (RoomMonsterSameRoomV113(h,mp,pb))
                count++
        }
        u := NumGet(ub,0xE8,"UInt")
    }
    return count
}
CoordCursorHoverUnitV600()
{
    direct := CoordCursorTargetV209()
    if (direct!="")
        return direct
    pid := D2GetActiveGamePidV95(),hwnd := GameTargetHwndV63()
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h || !hwnd)
    {
        if (h)
            DllCall("CloseHandle","Ptr",h)
        return ""
    }
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!path || !MonsterBossProbeReadV1(h,path,0x20,pb))
            return ""
        view := AutoMonsterAttackViewV1(h,base,hwnd,path)
        if (!IsObject(view))
            return ""
        VarSetCapacity(mouse,8,0)
        if (!DllCall("GetCursorPos","Ptr",&mouse) || !DllCall("ScreenToClient","Ptr",hwnd,"Ptr",&mouse))
            return ""
        mx := NumGet(mouse,0,"Int"),my := NumGet(mouse,4,"Int")
        if (mx<0 || my<0 || mx>=view.cw || my>=view.ch)
            return ""
        px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
        psx := NumGet(pb,8,"Int")-view.ox,psy := NumGet(pb,12,"Int")-view.oy
        best := false,bestDistance := 24*24,seen := {},started := A_TickCount,scanned := 0
        for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
        {
            u := D2ReadU32(h,room+0x74)
            while (u && !seen.HasKey(u) && scanned<1024 && A_TickCount-started<40)
            {
                seen[u] := true,scanned++
                if (!MonsterBossProbeReadV1(h,u,0xEC,ub))
                    break
                next := NumGet(ub,0xE8,"UInt"),mode := NumGet(ub,16,"UInt")
                up := NumGet(ub,0x2C,"UInt")
                if (NumGet(ub,0,"UInt")=1 && mode!=0 && mode!=12
                    && up && MonsterBossProbeReadV1(h,up,0x20,mp))
                {
                    dx := NumGet(mp,2,"UShort")-px,dy := NumGet(mp,6,"UShort")-py
                    sx := Round(((dx-dy)*16+psx)*view.cw/view.gw)
                    sy := Round(((dx+dy)*8+psy-8)*view.ch/view.gh)
                    distance := (sx-mx)**2+(sy-my)**2
                    if (distance<bestDistance)
                        bestDistance := distance,best := {cls:NumGet(ub,4,"UInt"),uid:NumGet(ub,12,"UInt")}
                }
                u := next
            }
            if (scanned>=1024 || A_TickCount-started>=40)
                break
        }
        return IsObject(best) ? "QUÁI ID: " . best.cls . " | UID: " . best.uid : ""
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

CoordCursorTimerV132:
CoordCursorDisplayV132()
return


ViewDisplayApplyV601()
{
    global viewIdV54,viewPosV291,fonInfoOnV385,FonInfoHwndV385
    global fonInfoStuckDismissedV552,fonInfoAutoStuckV552,farmStuckInfoAutoV10
    fonInfoOnV385 := viewIdV54 ? true : false
    fonInfoAutoStuckV552 := false,farmStuckInfoAutoV10 := false
    fonInfoStuckDismissedV552 := !viewIdV54
    if (viewIdV54)
        SetTimer, FonInfoTimerV385, 250
    else
    {
        SetTimer, FonInfoTimerV385, Off
        Gui, FonInfoV385:Destroy
        FonInfoHwndV385 := 0
    }
    if (viewIdV54 || viewPosV291)
        SetTimer, CoordCursorTimerV132, 500
    else
    {
        SetTimer, CoordCursorTimerV132, Off
        ToolTip,,,,20
    }
}

ViewPositionReadV601()
{
    pid := D2GetActiveGamePidV95(),base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!path || !MonsterBossProbeReadV1(h,path,0x20,pb))
            return false
        x := NumGet(pb,2,"UShort"),y := NumGet(pb,6,"UShort"),room1 := NumGet(pb,0x1C,"UInt")
        level := CoordLevelV14(h,room1),room2 := room1 ? D2ReadU32(h,room1+0x10) : 0
        if (!x || !y || !level)
            return false
        return {pid:pid,level:level,x:x,y:y,room1:room1,room2:room2
            ,number:RoomGroupNumberV118(h,pb,level),monsters:CoordRoomLiveCountV133(h,pb),at:A_TickCount}
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

CoordCursorDisplayV132()
{
    global coordCurrentTextV15,coordCurrentRoomV130,coordCurrentReadAtV132,coordLiveMonsterCountV133
    global viewIdV54,viewPosV291,lastTipV218,lastTipPosV218,coordCursorSnapshotV390
    global fonInfoOnV385,coordTrackingEnabledV409,mainToolHwndV67

    MouseGetPos,,,hoverWin
    if (mainToolHwndV67 && hoverWin=mainToolHwndV67)
    {
        ToolTip,,,,20
        lastTipV218 := "",lastTipPosV218 := ""
        return
    }
    if (GetKeyState("LButton","P") || GetKeyState("RButton","P"))
        return
    activePid := D2GetActiveGamePidV95()
    WinGet, hoverPid, PID, ahk_id %hoverWin%
    if (!activePid || hoverPid!=activePid)
    {
        ToolTip,,,,20
        lastTipV218 := "",lastTipPosV218 := ""
        return
    }
    if (!viewIdV54 && !viewPosV291)
    {
        ToolTip,,,,20
        lastTipV218 := "",lastTipPosV218 := ""
        return
    }
    if (!IsGameActive() && !WinActive("Auto-GSF ahk_class AutoHotkeyGUI"))
    {
        ToolTip,,,,20
        lastTipV218 := "",lastTipPosV218 := ""
        return
    }
    mouseMode := A_CoordModeMouse,tipMode := A_CoordModeToolTip
    CoordMode, Mouse, Screen
    CoordMode, ToolTip, Screen
    try
    {
        MouseGetPos, mouseX,mouseY
        tipText := ""
        snapV390 := ViewPositionReadV601()
        posFresh := IsObject(snapV390)
        if (viewPosV291 && posFresh && IsObject(snapV390) && A_TickCount-snapV390.at<=2000)
        {
            roomText := snapV390.number>=0 ? "Phòng: " . snapV390.number : ""
            tipText := "Map: " . snapV390.level . (roomText!="" ? " | " . roomText : "")
            tipText .= "`nXY: " . snapV390.x . "," . snapV390.y . " | Quái: " . snapV390.monsters
            tipText .= "`nRoom1: " . V92Hex(snapV390.room1) . " | Room2: " . V92Hex(snapV390.room2)
        }
        if (viewIdV54)
        {
            hoverText := CoordCursorHoverUnitV600()
            if (hoverText!="")
                tipText .= (tipText!="" ? "`n" : "") . hoverText
        }
        if (tipText="")
        {
            ToolTip,,,,20
            lastTipV218 := "",lastTipPosV218 := ""
            return
        }
        tipX := mouseX+18
        tipY := mouseY+24
        tipPos := tipX . "," . tipY
        if (tipText=lastTipV218 && tipPos=lastTipPosV218)
            return
        lastTipV218 := tipText
        lastTipPosV218 := tipPos
        ToolTip, %tipText%, %tipX%, %tipY%, 20
    }
    finally
    {
        CoordMode, Mouse, %mouseMode%
        CoordMode, ToolTip, %tipMode%
    }
}
CoordCursorTargetV209()
{
    global currentAttackUidV520,currentAttackAtV520
    if (!IsGameActive())
        return ""
    pid := D2GetActiveGamePidV95()
    MouseGetPos,,,hoverWindow
    WinGet, hoverPid, PID, ahk_id %hoverWindow%
    if (!pid || hoverPid!=pid)
        return ""
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return ""
    try
    {
        if (!MonsterBossProbeReadV1(h,base+0x51A80,8,getter))
            return ""
        if (NumGet(getter,0,"UChar")!=0xA1
            || (NumGet(getter,5,"UChar")!=0xC3 && NumGet(getter,5,"UChar")!=0xC2))
            return ""
        selectedAddr := NumGet(getter,1,"UInt")
        if (selectedAddr<base || selectedAddr>=base+0x200000)
            return ""
        unit := D2ReadU32(h,selectedAddr)
        if (!unit || !MonsterBossProbeReadV1(h,unit,0x14,ub))
            return ""
        kind := NumGet(ub,0,"UInt"),classId := NumGet(ub,4,"UInt"),uid := NumGet(ub,0x0C,"UInt")
        if ((kind!=1 && kind!=2 && kind!=4) || !uid || classId>65535
            || D2ReadU32(h,selectedAddr)!=unit)
            return ""
        if (kind=4)
        {
            itemData := D2ReadU32(h,unit+0x14)
            if (!itemData || !MonsterBossProbeReadV1(h,itemData,4,ib))
                return ""
            quality := NumGet(ib,0,"UInt")
            if (quality<1 || quality>9 || D2ReadU32(h,selectedAddr)!=unit)
                return ""
            return "CLASS: " . classId . " | ITEMDATA: " . Format("{:02X}",quality) . "`nUID: " . uid
        }
        if (kind=1)
        {
            lockMarkV600 := MonsterLockEligibleV308(classId) ? "[LOCK]" : "[KHÔNG LOCK]"
            if (currentAttackUidV520=uid && A_TickCount-currentAttackAtV520<10000)
                lockMarkV600 .= " [ĐANG ĐÁNH]"
            return "ID: " . classId . " " . lockMarkV600 . " | UID: " . uid . " | Type: " . kind
        }
        return "ID: " . classId . " | UID: " . uid . " | Type: " . kind
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

CoordTrackingToggleV409:
if (fonEditDepthV414)
{
    ToolTipInfoV386("Đang Tạo/Sửa lộ trình: F-OFF đến khi lưu xong.")
    SetTimer, RemoveToolTip, -2500
    return
}
coordTrackingEnabledV409 := !coordTrackingEnabledV409
autoMapTrackingV10 := coordTrackingEnabledV409
GuiControl, 1:, CoordTrackingButtonV409, % coordTrackingEnabledV409 ? "F-ON" : "F-OFF"
if (coordTrackingEnabledV409)
{
    ; V845: F-ON is a position/yellow-line watcher, not the manual Load button.
    FonTrackingEnableV410()
    SetTimer, CoordCurrentTimerV15, 250
    CoordCurrentReadV15()
}
else
{
    SetTimer, CoordCurrentTimerV15, Off
    coordCursorSnapshotV390 := false
    coordCurrentReadAtV132 := 0
    fonFirstLoadV763 := false
    ToolTip,,,,20
}
return

CoordCurrentTimerV15:
CoordCurrentReadV15()
return

CoordCurrentReadV15()
{
    global coordCurrentTextV15, coordNearbyRowV18, autoMonsterAttackOn, coordManualRowV59,coordCurrentRoomV130,coordCurrentReadAtV132,coordLiveMonsterCountV133
    global coordLiveYellowV128
    global autoMapTrackingV10,coordCursorSnapshotV390,coordCurrentLevelV400,coordTrackingEnabledV409
    if (!coordTrackingEnabledV409)
        return
    coordCursorSnapshotV390 := false
    pid := CoordDisplayGamePidV1(), base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? DllCall("OpenProcess","UInt",0x0410,"Int",0,"UInt",pid,"Ptr") : 0
    if (!h)
    {
        if (!pid)
            CoordMapUnavailableV381()
        return
    }
    try
    {
        player := D2ReadU32(h,base+0x11BBFC), path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
        {
            CoordMapUnavailableV381()
            return
        }
        x := NumGet(pb,2,"UShort"), y := NumGet(pb,6,"UShort")
        if (x && y && WinExist("ahk_pid " . pid))
        {
            coordCurrentTextV15 := x . "," . y
            entryLevelV263 := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
            if (!entryLevelV263)
            {
                CoordMapUnavailableV381()
                return
            }
            FarmPortalObserveV725(h,player,pb,pid)
            coordCurrentLevelV400 := entryLevelV263
            liveRoom2V395 := D2ReadU32(h,NumGet(pb,0x1C,"UInt")+0x10)
            liveLevelPtrV395 := liveRoom2V395 ? D2ReadU32(h,liveRoom2V395+0x58) : 0
            Lib263EntryObserveV841(pid,entryLevelV263,x,y,liveLevelPtrV395)
            Map263AutoLoadObserveV263(pid,entryLevelV263,x,y,liveLevelPtrV395)
            CoordPortalArrivalObserveV307(h,pb,pid,entryLevelV263)
            coordLiveMonsterCountV133 := CoordRoomLiveCountV133(h,pb)
            coordCurrentReadAtV132 := A_TickCount
            coordCurrentRoomV130 := RoomGroupNumberV118(h,pb,CoordLevelV14(h,NumGet(pb,0x1C,"UInt")))
            room1V390 := NumGet(pb,0x1C,"UInt")
            room2V390 := room1V390 ? D2ReadU32(h,room1V390+0x10) : 0
            coordCursorSnapshotV390 := {pid:pid,level:entryLevelV263,x:x,y:y
                ,room1:room1V390,room2:room2V390,number:coordCurrentRoomV130
                ,monsters:coordLiveMonsterCountV133,at:A_TickCount}
            FarmWatchObserveV5(pid,entryLevelV263,x,y)
            CoordLiveRoomYellowV128(h,pb,CoordLevelV14(h,NumGet(pb,0x1C,"UInt")))
            LibFarmPinYellowV2026(pid,entryLevelV263)
            CoordBoxRefreshV15()
        }
        else
            CoordMapUnavailableV381()
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

CoordBoxRefreshV15(force := false)
{
    global coordBoxLastV15, CoordListHwndV15, coordRowsV17, coordColorLastV17
    global mainToolHwndV67
    if (!force && (GetKeyState("LButton","P") || GetKeyState("RButton","P")))
    {
        MouseGetPos,,, coordMouseWindowV394
        if (mainToolHwndV67 && coordMouseWindowV394=mainToolHwndV67)
            return
    }
    if (!CoordListHwndV15 || !DllCall("IsWindow","Ptr",CoordListHwndV15))
        return
    text := CoordBoxTextV16(), colorKey := CoordColorKeyV17()
    if (!force && text=coordBoxLastV15 && colorKey=coordColorLastV17)
        return
    if (force || text!=coordBoxLastV15)
    {
        selection := DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x188,"Ptr",0,"Ptr",0,"Int")
        top := DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x18E,"Ptr",0,"Ptr",0,"Int")
        DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0xB,"Ptr",0,"Ptr",0)
        coordRowsV17 := StrSplit(text,"`n","`r")
        DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x184,"Ptr",0,"Ptr",0)
        for _,row in coordRowsV17
            DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x180,"Ptr",0,"Str",row)
        if (selection>=0 && selection<coordRowsV17.Length())
            DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x186,"Ptr",selection,"Ptr",0)
        if (top>=0)
            DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x197,"Ptr",top,"Ptr",0)
        DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0xB,"Ptr",1,"Ptr",0)
    }
    if (colorKey!=coordColorLastV17)
    {
        activeYellow := CoordYellowIndexV48()
        if (activeYellow>0 && activeYellow<coordRowsV17.Length())
        {
            DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x186,"Ptr",activeYellow,"Ptr",0)
            DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x197,"Ptr",Max(0,activeYellow-4),"Ptr",0)
        }
    }
    coordBoxLastV15 := text, coordColorLastV17 := colorKey
    DllCall("RedrawWindow","Ptr",CoordListHwndV15,"Ptr",0,"Ptr",0,"UInt",0x105)
}

FonLoadMapV382(reason := "MANUAL", inPid := 0, inLevel := 0, inX := 0, inY := 0)
{
    global coordTrackingEnabledV409,fonLoadBusyV410,fonLoadReasonV410
    ; LIB 130/133/136/139: F-ON khong bao gio pick lai INI khi da khoa map.
    ; Ke ca START_YELLOW, REVIVE_LIVE_MAP, MANUAL hay AUTO_LAYOUT_CHANGE.
    pinPidV2026 := inPid ? inPid : CoordDisplayGamePidV1()
    pinLevelV2026 := inLevel ? inLevel : (pinPidV2026 ? RoomRecordLevelV259(pinPidV2026) : 0)
    if (LibFarmPinMatchesV2026(pinPidV2026,pinLevelV2026))
        return LibFarmPinRestoreV2026(pinPidV2026,pinLevelV2026)
    if (fonLoadBusyV410)
    {
        PortalLogWriteV66("FON_LOAD_BLOCKED reason=LOAD_IN_PROGRESS request=" . reason,"FON_BUSY",2000)
        return false
    }
    priorCritical := A_IsCritical
    Critical, On
    fonLoadBusyV410 := true,fonLoadReasonV410 := reason
    Thread, NoTimers, true
    SetTimer, CoordCurrentTimerV15, Off
    try
        return FonLoadMapCoreV410(reason,inPid,inLevel,inX,inY)
    finally
    {
        fonLoadBusyV410 := false,fonLoadReasonV410 := ""
        if (coordTrackingEnabledV409)
            SetTimer, CoordCurrentTimerV15, 250
        Thread, NoTimers, false
        Critical, %priorCritical%
    }
}

FonLoadMapCoreV410(reason, inPid, inLevel, inX, inY)
{
    global currentProfile,routeMapIdV21,routeMapsV21,coordCurrentLevelV400,routePreviewV401,mapLoadFailureV402
    global coordSavedV15,coordYellowRowV350,coordPointLevelV14,coordPointTextV14
    global coordMapReadyV381,coordMapStateV381,coordMapAcceptedV381,coordMapSerialV381,roomMapSelectionResetV111
    global coordLiveYellowV128,coordPinnedYellowV136,coordNearbyRowV18,coordManualRowV59
    global fonCursorV724
    savedYellowV410 := coordYellowRowV350
    oldMapV724 := routeMapIdV21,oldPointsV724 := coordSavedV15
    oldStateV724 := coordMapStateV381
    pid := inPid
    level := inLevel
    x := inX
    y := inY
    if (!pid || !level || !x || !y)
    {
        pid := CoordDisplayGamePidV1()
        if (!pid)
        {
            FonInfoPushV385("[F-ON] LỖI: không tìm thấy cửa sổ Diablo II")
            FonLoadErrorShowV385("F-ON: không tìm thấy cửa sổ Diablo II.")
            return MapLoadFailedStopV397("FON")
        }
        base := D2GetModuleBaseV35(pid,"D2Client.dll")
        h := base ? D2OpenProcess(pid) : 0
                if (!h)
        {
            FonInfoPushV385("[F-ON] LỖI: không mở được D2Client.dll")
            FonLoadErrorShowV385("F-ON: không mở được D2Client.dll.")
            return MapLoadFailedStopV397("FON")
        }
        try
        {
            player := D2ReadU32(h,base+0x11BBFC)
            path := player ? D2ReadU32(h,player+0x2C) : 0
            if (path && MonsterBossProbeReadV1(h,path,0x20,pb))
            {
                x := NumGet(pb,2,"UShort")
                y := NumGet(pb,6,"UShort")
                level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
            }
        }
        finally
            DllCall("CloseHandle","Ptr",h)
    }
    if (!level || !x || !y)
    {
        ToolTipInfoV386("F-ON: chưa đọc được vị trí nhân vật.")
        SetTimer, RemoveToolTip, -3000
        return MapLoadFailedStopV397("FON")
    }
    coordCurrentLevelV400 := level
    if (level>=263 && level<=266)
    {
        entryIdentityV2026 := MapLiveIdentityV399(pid,level)
        if (!IsObject(entryIdentityV2026)
            || !LibFarmEntryReadyV2026(pid,level,entryIdentityV2026.levelPtr,x,y))
        {
            PortalLogWriteV66("LIB_FON_ENTRY_REQUIRED level=" . level
                . " reason=NOT_AT_PORTAL_ENTRY map=KEPT_no_repick", "LIB_ENTRY_REQUIRED", 2500)
            return false
        }
    }
    if (reason="MANUAL" || reason="RECORD_SELECT_LIVE")
        mapLoadFailureV402 := false
    RoomMapsSyncV110(true,level,true,true)
    candidatesV396 := []
    PortalLogWriteV66("FON_LOAD_SCAN reason=" . reason . " level=" . level
        . " directory=" . MapRouteDirectoryV408("",level) . " registered=" . routeMapsV21.Length(),"FON_LOAD_SCAN",2000)
    for _,mapV396 in routeMapsV21
    {
        fileV396 := RoomProfileFileV108(currentProfile,mapV396.id)
        if (!FonFileAllowedV846(fileV396,level))
            continue
        dataV396 := RoomMapReadV109(fileV396,false,level)
        if (!IsObject(dataV396))
            PortalLogWriteV66("FON_FILE_REJECT level=" . level . " recorded=" . MapRouteHintV400(fileV396)
                . " exists=" . (FileExist(fileV396) ? 1 : 0) . " file=" . fileV396
                . " reason=WRONG_LEVEL_OR_EMPTY_OR_INVALID_ROUTE","FON_REJECT_" . mapV396.id,2000)
        if (IsObject(dataV396) && dataV396.level=level && dataV396.points.Length())
            candidatesV396.Push({id:mapV396.id,data:dataV396})
    }
    if (!candidatesV396.Length())
    {
        FonInfoPushV385("[F-ON] Không có file lộ trình cho map " . level)
        FonLoadErrorShowV385("F-ON: chưa tìm thấy file lộ trình map " . level . ". Chọn hoặc lưu đúng file map.")
        PortalLogWriteV66("FON_LOAD_FAIL level=" . level . " reason=NO_ROUTE_FILE candidates=0 display=KEPT ready=FALSE")
        MapLoadFailedStopV397("FON")
        if (!IsObject(coordSavedV15) || !coordSavedV15.Length())
            MapEmptyRouteSelectV400(level)
        return false
    }
    ; V843: special selection only for 39,183,184,263,241,270.
    ; Other IDs run exactly the V68 room-layout filter and nearest-route logic.
    liveGeometryV841 := false
    pickedV396 := false
    if (level=39 || level=183 || level=184)
    {
        snapshotV843 := MapCollisionSnapshotV821(pid,level)
        hashPickV843 := BoHashFindV830(snapshotV843,0)
        ; BO (39): after returning from town, only nearby Room1 collision
        ; samples may be loaded. The original full-multiset HASH check stays
        ; first; a partial check is permitted only with a FULL, exact saved
        ; Room2 layout and enough overlapping HASH values.
        if (level=39 && IsObject(snapshotV843) && IsObject(hashPickV843)
            && (hashPickV843.status="NEW" || hashPickV843.status="AMBIGUOUS"))
        {
            boPartialV852 := BoHashLoadPartialV852(snapshotV843,candidatesV396,pid)
            if (IsObject(boPartialV852) && boPartialV852.status="MATCH")
                hashPickV843 := boPartialV852
            else if (IsObject(boPartialV852) && boPartialV852.status="AMBIGUOUS")
                hashPickV843 := boPartialV852
        }
        if (IsObject(hashPickV843) && hashPickV843.status="MATCH")
            for _,candidateV843 in candidatesV396
                if (candidateV843.id=hashPickV843.id)
                {
                    pickedV396 := candidateV843
                    break
                }
        ; V849: F-ON is READ-ONLY. A legacy INI without saved HASH must be
        ; enrolled explicitly through TẠO; never write a HASH signature on Load.
        if (!IsObject(pickedV396))
        {
            PortalLogWriteV66("FON_HASH_REJECT level=" . level . " result=" . (IsObject(hashPickV843) ? hashPickV843.status : "READ_FAILED"))
            FonLoadErrorShowV385("HASH " . level . ": khong trung du bo HASH da luu, thieu chu ky, hoac nhieu INI cung khop; xem log FON_HASH_REJECT.")
            return MapLoadFailedStopV397("FON_HASH_NO_MATCH")
        }
    }
    else if (level=1)
    {
        ; Fixed town map. Pick among verified THANH level-1 routes by nearest waypoint.
        ; This avoids geometry-read failures and never invokes collision HASH.
        bestTownDistanceV848 := 1.0e30
        for _,townCandidateV848 in candidatesV396
        {
            nearestTownV848 := 1.0e30
            for _,townPointV848 in townCandidateV848.data.points
            {
                dTownV848 := (townPointV848.x-x)**2 + (townPointV848.y-y)**2
                if (dTownV848<nearestTownV848)
                    nearestTownV848 := dTownV848
            }
            if (!IsObject(pickedV396) || nearestTownV848<bestTownDistanceV848
                || (nearestTownV848=bestTownDistanceV848 && townCandidateV848.id=routeMapIdV21))
            {
                pickedV396 := townCandidateV848
                bestTownDistanceV848 := nearestTownV848
            }
        }
        PortalLogWriteV66("FON_THANH_MAP1_SELECT level=1 candidates=" . candidatesV396.Length()
            . " route=" . (IsObject(pickedV396) ? pickedV396.id : 0)
            . " distance2=" . bestTownDistanceV848 . " hash=OFF")
    }
    else if (level=263)
    {
        liveV843 := MapLiveIdentityV399(pid,level)
        if (IsObject(liveV843))
            pickedV396 := Lib263PickV841(candidatesV396,pid,liveV843.levelPtr,x,y)
        if (!IsObject(pickedV396))
        {
            PortalLogWriteV66("FON_LIB263_NO_SPAWN_MATCH level=" . level . " x=" . x . " y=" . y)
            FonLoadErrorShowV385("LIB263: điểm đầu qua cổng không khớp INI.")
            return MapLoadFailedStopV397("FON_LIB263_NO_MATCH")
        }
    }
    else if (level=241 || level=270)
    {
        pickedV396 := ScosFixedPickV841(candidatesV396,routeMapIdV21)
        if (!IsObject(pickedV396))
        {
            FonLoadErrorShowV385("SCOS " . level . ": có nhiều INI; hãy chọn đúng file.")
            return MapLoadFailedStopV397("FON_SCOS_AMBIGUOUS")
        }
    }
    else
    {
        ; Chỉ chấp nhận route sau khi nhận diện level + hình học phòng thực tế.
        liveGeometryV841 := false
        candidatesV396 := MapGatesFilterV397(candidatesV396,pid,level,liveGeometryV841)
        if (!candidatesV396.Length())
        {
            FonLoadErrorShowV385("Chưa đọc được file khớp bố trí map. Giữ tọa độ đã load và chờ đọc lại.")
            PortalLogWriteV66("FON_LOAD_FAIL level=" . level . " reason=ROOM_LAYOUT_NOT_MATCHED")
            return MapLoadFailedStopV397("FON")
        }
        ; Khi nhiều file có CÙNG bố cục, chọn đường có tọa độ gần nhân vật nhất.
        ; Tuyệt đối không ép về ID đã chọn trước đó nếu file khác phù hợp hơn.
        pickedV396 := false,bestEntryV396 := 1.0e30
        for _,candidateV396 in candidatesV396
        {
            distanceV396 := 1.0e30
            for _,pointV841 in candidateV396.data.points
            {
                pointDistanceV841 := (pointV841.x-x)**2+(pointV841.y-y)**2
                if (pointDistanceV841<distanceV396)
                    distanceV396 := pointDistanceV841
            }
            if (!IsObject(pickedV396) || distanceV396<bestEntryV396
                || (distanceV396=bestEntryV396 && candidateV396.id=routeMapIdV21))
                pickedV396 := candidateV396,bestEntryV396 := distanceV396
        }
    }
    ; Xác minh lại: nhân vật không được đổi tầng/map ngay lúc đang quét phòng.
    verifiedIdentityV841 := MapLiveIdentityV399(pid,level)
    if (!IsObject(verifiedIdentityV841)
        || (IsObject(liveGeometryV841) && liveGeometryV841.levelPtr!=verifiedIdentityV841.levelPtr))
        return MapLoadFailedStopV397("MAP_CHANGED_DURING_LAYOUT_SCAN")
    Stage2RoomReplayReleaseV11()
    routeMapIdV21 := pickedV396.id
    coordSavedV15 := pickedV396.data.points
    coordPointLevelV14 := level
    coordPointTextV14 := coordSavedV15[1].x . "," . coordSavedV15[1].y
    liveIdentityV724 := MapLiveIdentityV399(pid,level)
    sameRouteV724 := IsObject(fonCursorV724) && fonCursorV724.pid=pid
        && fonCursorV724.birth=BackgroundBirthV63(pid) && fonCursorV724.profile=currentProfile
        && fonCursorV724.level=level && fonCursorV724.mapId=routeMapIdV21
        && IsObject(liveIdentityV724) && fonCursorV724.levelPtr=liveIdentityV724.levelPtr
        && fonCursorV724.count=coordSavedV15.Length()
        && fonCursorV724.firstX=coordSavedV15[1].x && fonCursorV724.firstY=coordSavedV15[1].y
        && fonCursorV724.lastX=coordSavedV15[coordSavedV15.Length()].x
        && fonCursorV724.lastY=coordSavedV15[coordSavedV15.Length()].y
    if (reason="MANUAL" || reason="REVIVE_LIVE_MAP")
        row := CoordAdjacentRowV724(coordSavedV15,0,x,y,level)
    ; Moi nut START deu nap lai file map. Chi giu dong vang neu van cung file.
    else if (reason="START_YELLOW" && oldMapV724=routeMapIdV21)
        row := savedYellowV410>=1 && savedYellowV410<=coordSavedV15.Length() ? savedYellowV410 : 1
    else if (sameRouteV724)
        row := oldMapV724=routeMapIdV21 && savedYellowV410>=1 && savedYellowV410<=coordSavedV15.Length()
            ? savedYellowV410 : fonCursorV724.row
    else
        row := 1
    if (!row)
        row := 1
    coordYellowRowV350 := row
    coordLiveYellowV128 := row
    coordPinnedYellowV136 := row
    coordNearbyRowV18 := row
    coordManualRowV59 := row
    keyV382 := pid . "|" . currentProfile . "|" . level
    coordMapSerialV381 += 1
    liveIdentityV399 := MapLiveIdentityV399(pid,level)
    if (!IsObject(liveIdentityV399))
        return MapLoadFailedStopV397("MAP_CHANGED_DURING_LOAD")
    keepLevelPtrV395 := liveIdentityV399.levelPtr
    fileV10 := RoomProfileFileV108(currentProfile,routeMapIdV21)
    if (!MapFileStampReadV398(fileV10,fileStampV398))
    {
        FonLoadErrorShowV385("STOP FARM: không đọc được file map " . fileV10)
        return MapLoadFailedStopV397("FON_FILE_STAMP")
    }
    fonCursorV724 := {pid:pid,birth:BackgroundBirthV63(pid),profile:currentProfile,level:level,mapId:routeMapIdV21
        ,levelPtr:keepLevelPtrV395,row:row,playerX:x,playerY:y,count:coordSavedV15.Length(),firstX:coordSavedV15[1].x,firstY:coordSavedV15[1].y
        ,lastX:coordSavedV15[coordSavedV15.Length()].x,lastY:coordSavedV15[coordSavedV15.Length()].y}
    coordMapStateV381 := {key:keyV382,pid:pid,level:level,profile:currentProfile,loaded:true,mapId:routeMapIdV21,retryAt:0,serial:coordMapSerialV381,levelPtrV395:keepLevelPtrV395,fileV10:fileV10,fileStampV10:fileStampV398
        ,layoutV841:IsObject(liveGeometryV841) ? liveGeometryV841.layout : ""
        ,layoutCheckedAtV841:A_TickCount}
    RouteMapRefreshV21()
    CoordBoxRefreshV15(true)
    routePreviewV401 := false,mapLoadFailureV402 := false
    coordMapReadyV381 := true
    roomMapSelectionResetV111 := false
    FonLoadErrorHideV385()
    FonInfoPushV385("[F-ON] OK: level " . level . " map " . routeMapIdV21 . " dòng " . row . (reason="AUTO_LEVEL_CHANGE" ? " (qua cổng)" : ""))
    PortalLogWriteV66("FON_LOAD_OK reason=" . reason . " level=" . level
        . " map=" . routeMapIdV21 . " yellow=" . row
        . " ready=TRUE serial=" . coordMapStateV381.serial)
    if (level>=263 && level<=266)
        LibFarmPinSaveV2026(pid,level,keepLevelPtrV395)
    ToolTipInfoV386("F-ON OK - level " . level . " - route " . routeMapIdV21 . " - dòng " . row)
    SetTimer, RemoveToolTip, -2500
    return true
}

CoordAddAfterYellowV136:
if (!CoordCaptureV14(false,true))
{
    ToolTipInfoV386("Chưa lấy được tọa độ nhân vật để ADD.")
    SetTimer, RemoveToolTip, -2500
    return
}
if (coordYellowRowV350>=1 && coordYellowRowV350<=coordSavedV15.Length())
{
    DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x186,"Ptr",coordYellowRowV350,"Ptr",0)
    DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x197,"Ptr",Max(0,coordYellowRowV350-4),"Ptr",0)
    CoordBoxRefreshV15(true)
}
return

CoordDeleteYellowV136:
if (IsObject(roomRecordV108))
{
    ToolTipInfoV386("Dừng lưu phòng trước khi xóa dòng.")
    SetTimer, RemoveToolTip, -2500
    return
}
coordDeleteRowV136 := CoordYellowIndexV48()
if (coordDeleteRowV136<1)
    return
DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x186,"Ptr",coordDeleteRowV136,"Ptr",0)
Gosub, CoordDeleteRowV15
return

CoordSelectInsertV57:
if (A_GuiEvent="Normal" || A_GuiEvent="DoubleClick")
{
    selectedInsertRowV57 := DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x188,"Ptr",0,"Ptr",0,"Int")
    if (selectedInsertRowV57>=1 && selectedInsertRowV57<=coordSavedV15.Length())
    {
        if (autoMonsterAttackOn && ScosOrderedRouteV234())
        {
            CoordBoxRefreshV15(true)
            return
        }
        if (autoMonsterAttackOn && IsObject(coordRouteV16) && selectedInsertRowV57<coordRouteV16.yellow)
        {
            CoordBoxRefreshV15(true)
            return
        }
        coordRunSelectedV210 := {mapId:routeMapIdV21,row:selectedInsertRowV57,x:coordSavedV15[selectedInsertRowV57].x,y:coordSavedV15[selectedInsertRowV57].y,level:coordSavedV15[selectedInsertRowV57].level}
        coordLiveYellowV128 := coordSavedV15[selectedInsertRowV57].HasKey("roomNumber") ? selectedInsertRowV57 : 0
        coordNearbyRowV18 := selectedInsertRowV57,coordManualRowV59 := selectedInsertRowV57
        coordPinnedYellowV136 := selectedInsertRowV57
        coordYellowRowV350 := selectedInsertRowV57
        coordEditPointV127 := false,coordInsertAnchorV57 := false
        CoordRouteResetV16()
        coordRouteV16.anchor := selectedInsertRowV57,coordRouteV16.yellow := selectedInsertRowV57
        coordRouteV16.next := selectedInsertRowV57+1
        coordRouteV16.phase := coordRouteV16.next>coordSavedV15.Length() ? "DONE" : "NEXT"
        CoordBoxRefreshV15(true)
    }
}
return

CoordGoStopV296:
FarmGoFullStopV2()
return

CoordGoRequiredV26:
coordGoCommandV285 := "GO"
coordGoOnceRequestV26 := false
Gosub, CoordGoStartV59
return

CoordGoCancelV41(goal)
{
    global coordGoV59
    if (!CoordGoInterruptV139(goal))
        return false
    base := D2GetModuleBaseV35(goal.pid,"D2Client.dll")
    h := base ? D2OpenProcess(goal.pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb) || IsObject(coordGoV59))
            return false
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        if (!level)
            return false
        stopGoal := {pid:goal.pid,level:level,row:goal.row,redirect:true,stop:true,resumeFarm:false}
        coordGoV59 := stopGoal
        try
            return NativeMovePointV14(goal.pid,NumGet(pb,2,"UShort"),NumGet(pb,6,"UShort"),level,true,false,true,stopGoal)
        finally
            if (coordGoV59=stopGoal)
                coordGoV59 := false
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}


CoordGoPrevV138:
coordGoCommandV285 := "PREV"
prevGoRowV138 := CoordYellowIndexV48()
if (prevGoRowV138<1)
    prevGoRowV138 := DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x188,"Ptr",0,"Ptr",0,"Int")
prevGoRowV138--
if (prevGoRowV138<1 || prevGoRowV138>coordSavedV15.Length())
{
    ToolTipInfoV386("Không còn tọa độ trước đó.")
    SetTimer, RemoveToolTip, -2500
    return
}
coordGoRequestedRowV740 := prevGoRowV138
DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x186,"Ptr",prevGoRowV138,"Ptr",0)
coordGoOnceRequestV26 := false
Gosub, CoordGoStartV59
return

CoordGoNextV80:
coordGoCommandV285 := "NEXT"
nextGoRowV80 := CoordYellowIndexV48()
if (nextGoRowV80<1)
    nextGoRowV80 := DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x188,"Ptr",0,"Ptr",0,"Int")
nextGoRowV80++
if (nextGoRowV80<1 || nextGoRowV80>coordSavedV15.Length())
{
    ToolTipInfoV386("Không còn tọa độ kế tiếp.")
    SetTimer, RemoveToolTip, -2500
    return
}
coordGoRequestedRowV740 := nextGoRowV80
DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x186,"Ptr",nextGoRowV80,"Ptr",0)
coordGoOnceRequestV26 := false
Gosub, CoordGoStartV59
return

CoordGoStartV59:
goSingleV26 := false
coordGoOnceRequestV26 := false
MovementCtrlSetV78(false,0,"CoordGoStartV59")
goRowV59 := coordGoRequestedRowV740>=1 ? coordGoRequestedRowV740
    : DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x188,"Ptr",0,"Ptr",0,"Int")
coordGoRequestedRowV740 := 0
if (goRowV59<1 || goRowV59>coordSavedV15.Length())
{
    ToolTipInfoV386("Chọn một tọa độ đã lưu rồi bấm GO.")
    SetTimer, RemoveToolTip, -2500
    return
}
goPidV59 := CoordDisplayGamePidV1()
if (!goPidV59)
{
    ToolTipInfoV386("Không tìm thấy cửa sổ game.")
    SetTimer, RemoveToolTip, -2500
    return
}
SetTimer, CoordGoTimerV59, Off
CainAllStopV387(false)
farmStopMoveV124 := false
SetTimer, FarmStopMoveTimerV124, Off
farmResumeArmedV70 := false, farmResumeOutsideV70 := false
SetTimer, FarmResumeTimerV70, Off
CoordRouteResetV16()
    coordManualRowV59 := goRowV59, coordNearbyRowV18 := goRowV59
    coordLiveYellowV128 := goRowV59,coordPinnedYellowV136 := goRowV59
    coordYellowRowV350 := goRowV59
    pointGoV59 := coordSavedV15[goRowV59]
coordGoV59 := {pid:goPidV59,x:pointGoV59.x,y:pointGoV59.y,level:pointGoV59.level,row:goRowV59,redirect:true,singleMove:goSingleV26,requiredArrival:!goSingleV26,manualInterrupt:goSingleV26,commandV285:coordGoCommandV285,physicalKeys:CoordPhysicalKeysV139()}
CoordBoxRefreshV15(true)
if (!BackgroundBindV63(WinExist("ahk_pid " . goPidV59)))
{
    coordGoV59 := false
    return
}
SetTimer, CoordGoTimerV59, 250
SetTimer, CoordGoInputTimerV139, 25
return

CoordGoTimerV59:
if (!IsObject(coordGoV59) || autoMonsterAttackOn)
{
    coordGoV59 := false
    SetTimer, CoordGoTimerV59, Off
    return
}
if (coordGoV59.manualInterrupt && (zRunning || xRunning || gameItemActionOwner!=""))
{
    CoordGoInterruptV139(coordGoV59)
    return
}
if (!IsGameActive() || D2GetActiveGamePidV95()!=coordGoV59.pid || zRunning || xRunning || gameItemActionOwner!="")
    return
CoordGoTickV59()
return

CoordGoInputTimerV139:
if (!IsObject(coordGoV59) || !coordGoV59.manualInterrupt || coordGoV59.stop)
{
    SetTimer, CoordGoInputTimerV139, Off
    return
}
if (!IsGameForegroundV63() || !WinActive("ahk_id " . GameTargetHwndV63())
    || D2GetActiveGamePidV95()!=coordGoV59.pid)
    return
inputGoalV139 := coordGoV59
inputKeysV139 := CoordPhysicalKeysV139()
for inputKeyV139,_ in inputKeysV139
{
    if (!inputGoalV139.physicalKeys.HasKey(inputKeyV139))
    {
        CoordGoInterruptV139(inputGoalV139)
        return
    }
}
if (coordGoV59=inputGoalV139)
    inputGoalV139.physicalKeys := inputKeysV139
return

CoordPhysicalKeysV139()
{
    keys := {}
    Loop, 254
    {
        vk := A_Index
        if (vk=3 || vk=7 || vk=16 || vk=17 || vk=18)
            continue
        if (GetKeyState(Format("vk{:02X}",vk),"P"))
            keys[vk] := true
    }
    return keys
}

CoordGoInterruptV139(goal)
{
    global coordGoV59,farmResumeArmedV70,farmResumeOutsideV70
    Critical, On
    if (coordGoV59!=goal)
    {
        Critical, Off
        return false
    }
    coordGoV59 := false
    SetTimer, CoordGoTimerV59, Off
    SetTimer, CoordGoInputTimerV139, Off
    farmResumeArmedV70 := false,farmResumeOutsideV70 := false
    SetTimer, FarmResumeTimerV70, Off
    MovementCtrlSetV78(false,0,"MANUAL_INPUT_CANCEL_PREV_NEXT")
    Critical, Off
    return true
}
CoordGoTeleportToV303(h,ByRef pb,goal,direction:=1)
{
    if (CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))=163)
        return false
    global teleportKeyV55,backgroundAimV64,coordGoV59
    if (!IsObject(goal) || !CoordRecoveryGoalValidV655(goal) || teleportKeyV55="")
        return false
    if (!IsGameActive() || D2GetActiveGamePidV95()!=goal.pid)
        return false
    if (!FarmAttackReleaseWaitV15())
        return false
    ; V1251: goal.itemReturnV655 la lenh ITEM_MOVE cua FARM (khong phai GO tay).
    ; GO tay giu NativeDispatchReady(false); ITEM_MOVE dung khoa auto cua FARM.
    pickupItemMoveV1251 := FarmItemGoalValidV655(goal)
    escapeItemV20261029 := pickupItemMoveV1251 && IsObject(goal.routeV392)
        && IsObject(goal.routeV392.escapeV84)
    if (!(pickupItemMoveV1251 ? NativeDispatchReadyV10(true) : NativeDispatchReadyV10(false))
        || !AutoMonsterPacketCleanupV1())
        return false
    base := D2GetModuleBaseV35(goal.pid,"D2Client.dll")
    player := base ? D2ReadU32(h,base+0x11BBFC) : 0
    path := player ? D2ReadU32(h,player+0x2C) : 0
    if (!MonsterBossProbeReadV1(h,path,0x20,pb) || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=goal.level)
        return false
    view := AutoMonsterAttackViewV1(h,base,GameTargetHwndV63(),path)
    if (!IsObject(view))
        return false
    px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
    dx := goal.x - px, dy := goal.y - py
    ; Item Tele is strictly owned by confirmed movement-stuck recovery.
    if (pickupItemMoveV1251 && !escapeItemV20261029)
        return false
    vectorV661 := CoordEscapeVectorV661(dx,dy,direction,px,py)
    dx := vectorV661.x,dy := vectorV661.y
    if (dx*dx+dy*dy < 1)
        return false
    sx := (dx-dy)*16, sy := (dx+dy)*8
    length := Sqrt(sx*sx+sy*sy)
    if (length<1)
        return false
    ; Tele cua ITEM_MOVE khong bi gioi han boi BK danh.
    reach := pickupItemMoveV1251 ? 1 : MonsterRadiusGetV239()/Sqrt(dx*dx+dy*dy)
    if (IsObject(direction))
        reach := Min(1,reach)
    aimX := Max(16,Min(view.gw-16,NumGet(pb,8,"Int")-view.ox+sx*reach))
    aimY := Max(32,Min(view.gh-64,NumGet(pb,12,"Int")-view.oy+sy*reach))
    try
    {
        if (!GameTargetAimV63(Round(aimX*view.cw/view.gw),Round(aimY*view.ch/view.gh)))
            return false
        Sleep, 30
        if (!CoordRecoveryGoalValidV655(goal) || !IsGameActive() || D2GetActiveGamePidV95()!=goal.pid
            || !(pickupItemMoveV1251 ? NativeDispatchReadyV10(true) : NativeDispatchReadyV10(false)))
            return false
        if (!BuffCheckedSendV29(teleportKeyV55))
            return false
        AutoMonsterAttackLogV2("GO_TELE_SENT row=" . goal.row . " key=" . teleportKeyV55
            . " goal=" . goal.x . "," . goal.y
            . " recovery=" . (escapeItemV20261029 ? "ITEM_STUCK" : "MANUAL_GO")
            . " effect=WAIT_POSITION_CHANGE")
        return true
    }
    finally
        backgroundAimV64 := false
}


CoordGoTickV59()
{
    global coordGoV59,farmResumeArmedV70,farmResumeOutsideV70,teleportIntervalSecV56,coordManualTeleLastV296
    global chaseCheckSecV9
    global teleportKeyV55,zRunning,xRunning,gameItemActionOwner,packetWatchArmedV1,petLearnOnV12,backgroundAimV64
    goal := coordGoV59
    if (!IsObject(goal))
        return
    base := D2GetModuleBaseV35(goal.pid,"D2Client.dll")
    h := base ? DllCall("OpenProcess","UInt",0x0410,"Int",0,"UInt",goal.pid,"Ptr") : 0
    if (!h)
        return
    try
    {
        player := D2ReadU32(h,base+0x11BBFC), path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return
        if (coordGoV59!=goal)
            return
        if (CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=goal.level)
            return
        px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
        if (goal.stop)
        {
            mode := D2ReadU32(h,player+0x10)
            stopped := mode=1 || mode=5 || mode=0 || mode=17
            if (!stopped)
                stopped := NativeMovePointV14(goal.pid,px,py,goal.level,true,false,true,goal)
            stopReadyV84 := mode=1 || mode=5 || mode=0 || mode=17
            if (stopReadyV84 && AutoMonsterPacketCleanupV1())
            {
                Critical, On
                resumeFarmV84 := coordGoV59=goal && goal.resumeFarm
                if (coordGoV59=goal)
                {
                    coordGoV59 := false
                    SetTimer, CoordGoTimerV59, Off
                }
                Critical, Off
                farmResumeArmedV70 := false,farmResumeOutsideV70 := false
                SetTimer, FarmResumeTimerV70, Off
            }
            return
        }
        arrivalSq := goal.singleMove ? 0 : 25
        if ((px-goal.x)*(px-goal.x)+(py-goal.y)*(py-goal.y)<=arrivalSq)
        {
            Critical, On
            if (coordGoV59!=goal)
            {
                Critical, Off
                return
            }
            MovementCtrlSetV78(false,0,"CoordGoTickV59")
            goal.stop := true,goal.resumeFarm := false
            Critical, Off
            NativeMovePointV14(goal.pid,px,py,goal.level,true,false,true,goal)
            ToolTipInfoV386("ĐÃ ĐẾN TỌA ĐỘ DÒNG " . goal.row . " — DỪNG")
            SetTimer, RemoveToolTip, -2500
            return
        }
        if (goal.requiredArrival && CoordGoFarmStuckV392(h,pb,goal))
            return
        if (CoordStuckMoveV392(goal.pid,goal.x,goal.y,goal.level,goal.routeV392,2,goal)
            && coordGoV59=goal)
        {
            rV613 := goal.routeV392
            if (IsObject(rV613) && !IsObject(rV613.stuckProbe))
                rV613.stuckProbe := {x:px,y:py,since:A_TickCount,dist:Sqrt((px-goal.x)**2+(py-goal.y)**2),goalRow:2}
            if (goal.singleMove)
            {
                CoordGoInterruptV139(goal)
                ToolTipInfoV386("ĐÃ GỬI DI CHUYỂN 1 LẦN.")
                SetTimer, RemoveToolTip, -2000
            }
        }
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

