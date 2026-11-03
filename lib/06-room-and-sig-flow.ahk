ScosNextMapPointV685(x,y)
{
    return {x:5958,y:11317,source:"SCOS_241_TO_270_BOUNDARY"}
}

ScosMap2JoinTickV689(r,ctx,ByRef pb,level,px,py)
{
    if (!IsObject(r.scosJoinV685))
    {
        result := FarmNoFightFlowV8(r,ctx,pb,level,"SCOS_MAP2")
        if (result!="DONE")
            return result
        FarmCommonRouteEndV3(r)
        r.scosJoinV685 := ScosNextMapPointV685(0,0)
        r.stage1StuckV384 := false
        r.last := 0
        PortalLogWriteV66("SCOS_MAP_JOIN from=241 to=270 target=5958,11317 method=MOVE_OR_STUCK_TELE no_portal=1")
    }
    join := r.scosJoinV685
    if (join.doneV694)
        return "DONE"
    if (level=270)
    {
        join.doneV694 := true
        r.stage1StuckV384 := false
        PortalLogWriteV66("SCOS_MAP_JOIN_DONE level=" . level . " xy=" . px . "," . py . " result=DONE next=FARM_MAP3")
        return "DONE"
    }
    playerV718 := D2ReadU32(ctx.h,D2GetModuleBaseV35(r.pid,"D2Client.dll")+0x11BBFC)
    if (!FarmBeforeFinalEntryV718(r,ctx.h,playerV718,level,270))
        return "RUN"
    MapStage1MoveV374(ctx,join.x,join.y)
    return "RUN"
}

ScosMap2HandoffV694(r,ctx,player,ByRef pb,level,px,py)
{
    if (ScosMap2JoinTickV689(r,ctx,pb,level,px,py)!="DONE")
        return false
    if (!ScosMap3AdvanceTickV696(r,ctx,player,pb,level,px,py))
        return false
    r.scosLevelV8 := level
    r.scosStepV8 := "DONE"
    r.phase := "MAP"
    return FarmMainFlowV8(r,ctx,player,level,px,py)
}


ScosMap3NextPointV696(points)
{
    if (!IsObject(points) || points.Length()<2)
        return false
    point := points[2]
    if (!IsObject(point) || point.level!=270 || !point.x || !point.y)
        return false
    return {x:point.x,y:point.y,row:2}
}

ScosMap3AdvanceTickV696(r,ctx,player,ByRef pb,level,px,py)
{
    global scosEntryV162,coordSavedV15,autoMonsterAttackOn
    global xRunning,zRunning,gameItemActionOwner
    if (scosEntryV162!=r)
        return false
    if (level!=270)
    {
        if (level=241)
        {
            if (IsObject(r.scosInwardV696))
                r.scosInwardV696.done := false
            MapStage1MoveV374(ctx,r.scosJoinV685.x,r.scosJoinV685.y)
        }
        return false
    }
    if (FarmFinalEntryPreparedV718(r,r.pid,level))
        return true
    inward := r.scosInwardV696
    if (IsObject(inward) && inward.done)
        return true
    if (!IsObject(inward))
        r.scosInwardV696 := inward := {done:false}
    r.phase := "SCOS_MAP3_ADVANCE"
    autoMonsterAttackOn := true
    SetTimer, AutoMonsterAttackTimer, Off
    FarmCastSyncV88(false)
    if (!IsObject(inward.point))
    {
        if (!Stage2MapWaitV381(r.pid,270,true) || scosEntryV162!=r)
            return false
        inward.point := ScosMap3NextPointV696(coordSavedV15)
        if (!IsObject(inward.point))
        {
            FonInfoPushV385("Scos map 3: thiếu tọa độ 2; chưa buff.")
            return false
        }
        r.stage1StuckV384 := false,r.last := 0
        PortalLogWriteV66("SCOS_MAP3_ADVANCE target=" . inward.point.x . "," . inward.point.y
            . " row=" . inward.point.row . " combat=ON buff=DEFERRED")
    }
    if (xRunning || zRunning || gameItemActionOwner!="" || !AutoMonsterPacketCleanupV1())
        return false
    if (FarmPreBuffCombatCheckV710(ctx.h,player,pb,r.pid))
        return false
    if (scosEntryV162!=r)
        return false
    point := inward.point
    if ((px-point.x)**2+(py-point.y)**2>4)
    {
        MapStage1MoveV374(ctx,point.x,point.y)
        return false
    }
    inward.done := true,r.stage1StuckV384 := false
    FarmAttackHoldReleaseV15()
    autoMonsterAttackOn := false
    PortalLogWriteV66("SCOS_MAP3_ADVANCE_DONE level=270 xy=" . px . "," . py . " next=CHECK_AND_BUFF")
    return true
}


ScosFlowTickV3(r,ctx,player,ByRef pb,level,px,py)
{
    global scosEntryV162,farmControlOwnerV186,coordSavedV15
    global xRunning, zRunning, gameItemActionOwner, packetWatchArmedV1
    if (scosEntryV162!=r || !level)
        return
    farmControlOwnerV186 := "SCOS",r.until := A_TickCount+120000
    ctx.entryStateV42 := r
    if (IsObject(r.scosJoinV685) && (level=241 || level=270))
    {
        ScosMap2HandoffV694(r,ctx,player,pb,level,px,py)
        return
    }
    if (r.scosLevelV8!=level)
    {
        FarmCommonRouteEndV3(r)
        r.scosLevelV8 := level,r.scosStepV8 := "SIG"
        r.scosJoinV685 := false,r.stage1StuckV384 := false
        r.scosTownRouteV8 := false,r.goldVisitV8 := false,r.wpFlowV8 := false
        r.phase := level=109 ? "WP" : "MAP"
        FonInfoPushV385("Scos: đã vào map " . level . ".")
    }
    
    if (level=270)
    {
        FarmMainFlowV8(r,ctx,player,level,px,py)
        return
    }
    
    if (level=241)
    {
        ScosMap2HandoffV694(r,ctx,player,pb,level,px,py)
        return
    }

    if (level!=109)
        return
    if (r.scosStepV8="SIG")
    {
        if (!FarmSigFlowV8(r))
            return
        r.scosStepV8 := "ROUTE"
        return
    }
    if (r.scosStepV8="ROUTE")
    {
        if (FarmNoFightFlowV8(r,ctx,pb,level,"SCOS_MAP1")!="DONE")
            return
        r.scosTownRouteV8 := coordSavedV15.Clone()
        FarmCommonRouteEndV3(r)
        r.scosStepV8 := "WP"
        FonInfoPushV385("Scos map 1: đã hết lộ trình; chuẩn bị vào WP.")
        return
    }
    if (r.scosStepV8="WP")
        FarmWaypointFlowV8(r,ctx,pb,level,px,py,429,241)
}

FarmSharedEntryOptionsV781(r)
{
    global farmEntrySigV315,farmEntryGoldV315
    if (!IsObject(r))
        return false
    r.entrySigV315 := farmEntrySigV315 ? true : false
    r.entryGoldV315 := farmEntryGoldV315 ? true : false
    r.goldAlongDoneV12 := false,r.goldAlongBusyV12 := false
    r.goldBeforeExitAtV781 := 0
    PortalLogWriteV66("FARM_SHARED_ENTRY map=" . r.map . " sig=" . r.entrySigV315
        . " gold=" . r.entryGoldV315 . " sig_engine=MANUAL_SIG gold_engine=FAUT")
    return true
}

ScosEntryArmV162(hwnd := 0)
{
    global scosEntryV162,autoMonsterAttackOn,pickupImageOn,packetWatchArmedV1,backgroundPidV63,farmEntryGoldV315
    if (packetWatchArmedV1 || !BackgroundBindV63(hwnd))
        return false
    pid := backgroundPidV63,base := D2GetModuleBaseV35(pid,"D2Client.dll"),h := D2OpenProcess(pid)
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        level := path ? CoordLevelV14(h,D2ReadU32(h,path+0x1C)) : 0
        if (level!=109 && level!=241 && level!=270)
            return false
        scosEntryV162 := {map:"SCOS",pid:pid,until:A_TickCount+120000,phase:level=109 ? "WP" : "WALK",row:1,last:0,pickup:pickupImageOn}
        FarmSharedEntryOptionsV781(scosEntryV162)
        PickupEnabledSetV71(false,true,false)
        SetTimer, ScosEntryTimerV162, 250
        FarmPickupSyncV57(0,0,-1,true)
        PortalLogWriteV66("MAP_STAGE1_START map=SCOS level=" . level . " target=FIRST_SAVED_COORD buff=ON_FARM_MAP_ENTRY")
        ToolTipInfoV386("SCOS: map 1 farm chuẩn không đánh + WP → map 2 không đánh → map 3 farm → về thành.")
        SetTimer, RemoveToolTip, -3000
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

ScosEntryTimerV162:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    SetTimer, ScosEntryTimerV162, Off
    return
}
ScosEntryTickV162()
return

ScosEntryTickV162()
{
    global farmManualStoppedV2026,farmUserPausedV2026
    if (farmUserPausedV2026)
        return
    if (farmManualStoppedV2026)
        return
    global sigBusyV147
    if (sigBusyV147 || SigPickupOwnedV764())
        return
    global buffSequenceRunningV555
    if (buffSequenceRunningV555)
        return
    global cainPausedV10
    if (cainPausedV10)
        return

    global scosEntryV162,autoMonsterAttackOn,scosStartFarmV162,mapFarmStartPendingV170,coordSavedV15,mapStage1BuffDoneV248
    global farmReviveV32
    static busy := false
    if (busy || !IsObject(scosEntryV162))
        return
    busy := true,h := 0
    try
    {
        r := scosEntryV162
        if (r.map="BO")
        {
            global farmControlOwnerV186
            if (farmControlOwnerV186="")
            {
                farmControlOwnerV186 := "BO"
                PortalLogWriteV66("BO_OWNER_RESTORED source=LIVE_ENTRY")
            }
            PortalLogWriteV66("BO_ENTRY_STATE stage=" . r.boStageV413 . " phase=" . r.phase
                . " farm=" . autoMonsterAttackOn . " owner=" . farmControlOwnerV186,"BO_ENTRY_STATE",1000)
        }
        if (r.map="BO" && r.phase="PORTAL")
            r.until := Max(r.until,A_TickCount+60000)
        if (r.retryAtV237 && A_TickCount<r.retryAtV237)
            return
        if (A_TickCount>=r.until || !BackgroundValidV63())
        {
            FarmRestartOnErrorV238("ENTRY_TIMEOUT_OR_GAME_NOT_READY")
            return
        }
        base := D2GetModuleBaseV35(r.pid,"D2Client.dll"),h := D2OpenProcess(r.pid)
        if (!h)
            return
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        modeV725 := player ? D2ReadU32(h,player+0x10) : -1
        if (!player)
            return
        if (modeV725=0 || modeV725=17)
        {
            if (!r.reviveOwnerV725)
                r.reviveOwnerV725 := true,r.reviveFarmWasOnV725 := autoMonsterAttackOn
            autoMonsterAttackOn := true
            if (!MonsterBossProbeReadV1(h,path,0x20,pb))
                VarSetCapacity(pb,0x20,0)
            FarmReviveTickV32(h,player,pb,r.pid,GameTargetHwndV63(),base,path,modeV725)
            return
        }
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return
        if (IsObject(farmReviveV32) && farmReviveV32.pid=r.pid)
        {
            if (!r.reviveOwnerV725)
                r.reviveOwnerV725 := true,r.reviveFarmWasOnV725 := autoMonsterAttackOn
            autoMonsterAttackOn := true
            FarmReviveTickV32(h,player,pb,r.pid,GameTargetHwndV63(),base,path,modeV725)
            return
        }
        if (r.reviveOwnerV725)
        {
            autoMonsterAttackOn := r.reviveFarmWasOnV725
            r.reviveOwnerV725 := false
        }
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt")),px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
        FarmWatchObserveV5(r.pid,level,px,py)
        ctx := {pid:r.pid,h:h,playerV12:player,scosEntry:true,entryStateV42:r}
        if (scosEntryV162!=r)
            return
        if (r.map="BO")
        {
            BOEntryTickV413(r,ctx,player,pb,level,px,py)
            return
        }
        if (r.map="VIZ")
        {
            VizEntryTickV687(r,ctx,player,pb,level,px,py)
            return
        }
        if (CainQuestReturnV369(h,player,r.pid))
            return
        if (!MapStage1BuffFirstV368(r,ctx,player))
            return
        ; All six map start buttons share the manual SIG pipeline, with
        ; stage1SigDoneV374 guarding against redoing it on a later map.
        if (FarmSharedSigMapV781(r.map))
        {
            ; A second town visited in the same run may have new gold/items.
            if (FarmReviveTownLevelV295(level))
            {
                if (r.townGoldLevelV781!=level)
                {
                    r.townGoldLevelV781 := level
                    r.goldAlongDoneV12 := false,r.goldAlongBusyV12 := false
                    r.goldActionV8 := false
                }
            }
            else
                r.townGoldLevelV781 := 0
            if (!MapStage1SigReadyV374(r))
                return
        }
        else if (!r.cainActiveV368 && FarmReviveTownLevelV295(level))
            if (!MapStage1SigReadyV374(r))
                return
        if (FarmMapAltTickV199(h,player,pb,r.pid))
            return
        if (MapScrollFarmV269(r.map))
        {
            Map130EntryTickV257(r,ctx,player,pb,level,px,py)
            return
        }
        if (r.map="UBU")
        {
            UbuEntryTickV62(r,ctx,player,pb,level,px,py)
            return
        }
        if (r.map="CYC")
        {
            CycEntryTickV42(r,ctx,player,pb,level,px,py)
            return
        }
        if (r.map="NAO")
        {
                        NaoEntryTickV188(r,ctx,player,pb,level,px,py)
            return
        }
        if (r.map="TRAN")
        {
            TranEntryTickV358(r,ctx,player,pb,level,px,py)
            return
        }
        if (r.map="CAIN")
        {
            CainEntryTickV360(r,ctx,player,pb,level,px,py)
            return
        }
        if (r.map="M3000")
        {
            Farm3000EntryTickV297(r,ctx,player,pb,level,px,py)
            return
        }
        ScosFlowTickV3(r,ctx,player,pb,level,px,py)
        return
    }
    catch e
    {
        if (IsObject(r) && r.map="BO")
        {
            BOErrorReportV463(r,e.Message,"ENTRY line=" . e.Line . " function=" . e.What)
            return
        }
        FarmRestartOnErrorV238("ENTRY_ERROR " . e.Message)
    }
    finally
    {
        if (h)
            DllCall("CloseHandle","Ptr",h)
        busy := false
    }
}


MapStage1MoveV374(ctx,x,y)
{
    global scosEntryV162,teleportKeyV55,teleportIntervalSecV56,chaseCheckSecV9
    r := scosEntryV162
    if (!IsObject(r))
        return
    base := D2GetModuleBaseV35(ctx.pid,"D2Client.dll")
    player := base ? D2ReadU32(ctx.h,base+0x11BBFC) : 0
    path := player ? D2ReadU32(ctx.h,player+0x2C) : 0
    if (!path || !MonsterBossProbeReadV1(ctx.h,path,0x20,pb))
        return
    level := CoordLevelV14(ctx.h,NumGet(pb,0x1C,"UInt"))
    px := NumGet(pb,2,"UShort")
    py := NumGet(pb,6,"UShort")

    if (Stage1StuckTickV384(r,ctx,pb,ctx.pid,px,py,x,y,level))
        return

    if (A_TickCount-r.last<250)
        return
    sent := level ? NativeMovePointV14(ctx.pid,x,y,level,false,false,true,false,false) : false
    r.last := A_TickCount
    PortalLogWriteV66("SCOS_ENTRY_MOVE target=" . x . "," . y . " row=" . r.row
        . " method=NATIVE_FARM_MOVE queued=" . sent)
}

Stage1StuckTickV384(r,ctx,ByRef pb,pid,px,py,x,y,level)
{
    global chaseCheckSecV9,teleportKeyV55,teleportIntervalSecV56,xRunning,zRunning
    global gameItemActionOwner,packetWatchArmedV1,backgroundAimV64

    if (IsObject(r.stage1StuckV384) && (r.stage1StuckV384.goalXV679!=x
        || r.stage1StuckV384.goalYV679!=y || r.stage1StuckV384.levelV679!=level))
        r.stage1StuckV384 := false
    if (!IsObject(r.stage1StuckV384))
        r.stage1StuckV384 := {phase:"PROBE",x:px,y:py,since:A_TickCount
            ,lastTele:0,direction:1,tries:0,walkAt:0,goalXV679:x,goalYV679:y,levelV679:level}

    s := r.stage1StuckV384

    if (s.phase="PROBE")
    {
        if ((px-s.x)**2+(py-s.y)**2>=4)
        {
            s.x := px,s.y := py,s.since := A_TickCount
            return false
        }
        if (A_TickCount-s.since < Max(1,chaseCheckSecV9)*1000)
            return false
        if (teleportKeyV55="")
        {
            s.x := px,s.y := py,s.since := A_TickCount
            return false
        }
        s.phase := "CAST",s.direction := 1,s.tries := 0
        s.gd4StartedAtV679 := A_TickCount
        FarmWatchStuckBeginV679(s,pid,"GD1",s.gd4StartedAtV679)
        PortalLogWriteV66("GD1_STUCK_BEGIN row=" . r.row . " pos=" . px . "," . py
            . " target=" . x . "," . y . " wait_ms=" . (Max(1,chaseCheckSecV9)*1000))
    }

    if (xRunning || zRunning || gameItemActionOwner!="" || packetWatchArmedV1
        || !AutoMonsterPacketCleanupV1())
        return true

    if (s.phase="CAST")
    {
        cooldown := Max(1,teleportIntervalSecV56)*1000
        if (s.lastTele && A_TickCount-s.lastTele<cooldown)
            return true
        dx := x-px, dy := y-py
        if (s.direction=-1)
            dx := -dx, dy := -dy
        base := D2GetModuleBaseV35(pid,"D2Client.dll")
        player := base ? D2ReadU32(ctx.h,base+0x11BBFC) : 0
        path := player ? D2ReadU32(ctx.h,player+0x2C) : 0
        view := AutoMonsterAttackViewV1(ctx.h,base,GameTargetHwndV63(),path)
        if (!IsObject(view))
        {
            if (BuffCheckedSendV29(teleportKeyV55))
            {
                s.lastTele := A_TickCount,s.phase := "SETTLE"
                s.x := px,s.y := py
                PortalLogWriteV66("GD1_STUCK_TELE key=" . teleportKeyV55
                    . " pos=" . px . "," . py . " target=" . x . "," . y
                    . " direction=" . (s.direction=1 ? "GOAL" : "REVERSE") . " aim=NONE")
            }
            return true
        }
        sx := (dx-dy)*16, sy := (dx+dy)*8
        len := Sqrt(sx*sx+sy*sy)
        if (len<1)
            len := 1
        playerSX := NumGet(pb,8,"Int")-view.ox
        playerSY := NumGet(pb,12,"Int")-view.oy
        reach := Min(len,Min(view.gw,view.gh)*0.30)
        aimX := Max(16,Min(view.gw-16,playerSX+sx*reach/len))
        aimY := Max(32,Min(view.gh-64,playerSY+sy*reach/len))
        clientX := Round(aimX*view.cw/view.gw)
        clientY := Round(aimY*view.ch/view.gh)
        GameTargetAimV63(clientX,clientY)
        Sleep, 30
        if (BuffCheckedSendV29(teleportKeyV55))
        {
            s.lastTele := A_TickCount,s.phase := "SETTLE"
            s.x := px,s.y := py
            PortalLogWriteV66("GD1_STUCK_TELE key=" . teleportKeyV55
                . " pos=" . px . "," . py . " target=" . x . "," . y
                . " direction=" . (s.direction=1 ? "GOAL" : "REVERSE")
                . " aim=" . clientX . "," . clientY)
        }
        backgroundAimV64 := false
        return true
    }

    if (s.phase="SETTLE")
    {
        if (A_TickCount-s.lastTele<250)
            return true
        s.x := px,s.y := py,s.since := A_TickCount
        s.phase := "WALK"
        return true
    }

    if (s.phase="WALK")
    {
        NativeMovePointV14(pid,x,y,level,false,false,true)
        s.x := px,s.y := py,s.since := A_TickCount
        s.phase := "VERIFY",s.walkAt := A_TickCount
        PortalLogWriteV66("GD1_STUCK_WALK row=" . r.row . " from=" . s.x . "," . s.y)
        return true
    }

    if (s.phase="VERIFY")
    {
        movedSq := (px-s.x)**2+(py-s.y)**2
        beforeGoal := Sqrt((s.x-x)**2+(s.y-y)**2)
        nowGoal := Sqrt((px-x)**2+(py-y)**2)
        closing := beforeGoal-nowGoal
        if (movedSq>=4 && closing>=1)
        {
            PortalLogWriteV66("GD1_STUCK_RECOVERED moved=" . movedSq
                . " closing=" . Round(closing,2))
            r.stage1StuckV384 := false
            return false
        }
        if (A_TickCount-s.walkAt<Max(1,chaseCheckSecV9)*1000)
            return true
        if (s.direction=1)
        {
            s.direction := -1,s.phase := "CAST"
            PortalLogWriteV66("GD1_STUCK_REVERSE row=" . r.row)
            return true
        }
        s.tries++
        if (s.tries>=2)
        {
            PortalLogWriteV66("GD1_STUCK_REPEAT row=" . r.row
                . " pos=" . px . "," . py . " target=" . x . "," . y . " gd4_timer=KEEP")
            s.tries := 0,s.direction := 1,s.phase := "CAST"
            return true
        }
        s.direction := 1,s.phase := "CAST"
        return true
    }

    return false
}

WpCaptureTimerV161:
if (!manualLogOnV81 || !IsObject(wpCaptureV161))
{
    SetTimer, WpCaptureTimerV161, Off
    return
}
if (!wpCaptureV161.until)
{
    if (A_TickCount-wpCaptureV161.armed>=30000)
    {
        PortalLogWriteV66("WP_CAPTURE_END reason=NO_FOREGROUND_GAME")
        wpCaptureV161 := false
        SetTimer, WpCaptureTimerV161, Off
        return
    }
    wpPidV161 := D2GetActiveGamePidV95()
    if (!IsGameForegroundV63() || !wpPidV161)
        return
    pickupCubeTraceUntil := A_TickCount+30000
    nativeAttackProbeV5 := false
    packetWatchArmedV1 := true
    if (!PacketWatchStartV1(wpPidV161))
    {
        PacketWatchStopV1()
        PortalLogWriteV66("WP_CAPTURE_END reason=ATTACH_FAILED")
        wpCaptureV161 := false
        SetTimer, WpCaptureTimerV161, Off
        return
    }
    wpCaptureV161.until := A_TickCount+30000
    PortalLogWriteV66("WP_CAPTURE_READY duration_ms=30000 action=MANUAL_OPEN_WAYPOINT_AND_SELECT_MAP")
    ToolTipInfoV386("DÒ WP SẴN SÀNG: mở waypoint và chọn map bằng tay. Dò 30 giây.")
    SetTimer, RemoveToolTip, -8000
}
if (A_TickCount>=wpCaptureV161.until)
{
    PacketWatchStopV1()
    PortalLogWriteV66("WP_CAPTURE_END reason=30_SECONDS_DONE")
    wpCaptureV161 := false
    pickupCubeTraceUntil := 0
    SetTimer, WpCaptureTimerV161, Off
    ToolTipInfoV386("DÒ WP XONG: bấm Dừng log rồi gửi log cổng.")
    SetTimer, RemoveToolTip, -5000
    return
}
Critical, On
PacketWatchPollV1()
Critical, Off
if (!IsObject(packetWatchV1))
{
    wpCaptureV161 := false
    SetTimer, WpCaptureTimerV161, Off
}
return

StageTwoTestArmTimerV167:
stageTwoTestWaitV167 := 0
SetTimer, StageTwoTestArmTimerV167, Off
return

StageTwoStopV166(reason)
{
    global stageTwoV166
    if (reason="HOTKEY" || InStr(reason,"USER_STOP"))
        FarmBuffStopV509()
    if (!IsObject(stageTwoV166))
        return
    automatedV769 := stageTwoV166.continuous || stageTwoV166.restartRunV17
    if (automatedV769 && RegExMatch(reason,"^(TIMEOUT|CREATE_FAILED|ERROR|WATCHDOG)"))
        FarmErrorKeepV769("STAGE3_ERROR " . reason)
    stageTwoV166 := false
    SetTimer, StageTwoTimerV166, Off
    PortalLogWriteV66("STAGE3_STOP reason=" . reason)
}

; GD3/GD4: end the OLD Farm session. Only the selected map and the
; active GD3/GD4 controller are allowed to cross the boundary. Saved profile,
; hotkeys and other independent features are not part of Farm runtime state.
FarmStageFreshStopV1802(stage,controller := false)
{
    global farmControlOwnerV186,mapWorkflowV185,farmRestartReasonV238,stageTwoV166
    global farmWatchV5
    mapName := IsObject(mapWorkflowV185) && mapWorkflowV185.map!="" ? mapWorkflowV185.map : (farmControlOwnerV186!="" ? farmControlOwnerV186 : "SCOS")
    reason := farmRestartReasonV238
    FarmMapJournalFinishV940("GD" . stage . "_FRESH_STOP")
    CainAllStopV387(false)
    ; Reinitialize the standing/recovery clock as part of a new Farm session.
    farmWatchV5 := false
    ; Only the selected map and an explicitly new stage controller survive.
    farmControlOwnerV186 := mapName
    mapWorkflowV185 := {map:mapName,stage:3,startLevel:0,testRows:0}
    farmRestartReasonV238 := reason
    if (IsObject(controller))
        stageTwoV166 := controller
    PortalLogWriteV66("STAGE" . stage . "_FRESH_STOP map=" . mapName
        . " old_farm=OFF route=RESET old_combat=OFF old_pickup=OFF")
}

StageTwoArmV166(continuous := false)
{
    global stageTwoV166,backgroundPidV63,backgroundHwndV63,farmRestartReasonV238
    if (farmRestartReasonV238!="COMPLETE" && farmRestartReasonV238!="STUCK")
        return false
    if (!BackgroundValidV63())
        return false
    GameRoomHistoryCaptureV252(backgroundPidV63)
    FarmStageFreshStopV1802(3)
    stageTwoV166 := {pid:backgroundPidV63,hwnd:backgroundHwndV63,phase:"ESC",birth:BackgroundBirthV63(backgroundPidV63),at:A_TickCount,until:A_TickCount+120000,tries:0,continuous:continuous,restartRunV17:farmRestartReasonV238="STUCK"}
    PickupEnabledSetV71(false,true,false)
    SetTimer, StageTwoTimerV166, 250
    PortalLogWriteV66("STAGE3_START action=SAVE_EXIT_CREATE_RESTART")
    return true
}

StageTwoTimerV166:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    SetTimer, StageTwoTimerV166, Off
    return
}
StageTwoTickV166()
return

StageTwoWindowV166(r)
{
    return RecoveryGameWindowContactV498(r) ? r.hwnd : 0
}

StageTwoKeyV166(r,key)
{
    hwnd := StageTwoWindowV166(r)
    if (!hwnd)
        return false
    vk := GetKeyVK(key),sc := GetKeySC(key),lp := 1 | ((sc & 255)<<16)
    if (!vk || !DllCall("PostMessage","Ptr",hwnd,"UInt",0x100,"UPtr",vk,"Ptr",lp))
        return false
    Sleep, 40
    return DllCall("PostMessage","Ptr",hwnd,"UInt",0x101,"UPtr",vk,"Ptr",lp|0xC0000000)
}

StageTwoClickV166(r,x,y)
{
    hwnd := StageTwoWindowV166(r)
    VarSetCapacity(rect,16,0)
    if (!hwnd || !DllCall("GetClientRect","Ptr",hwnd,"Ptr",&rect))
        return false
    w := NumGet(rect,8,"Int"),hh := NumGet(rect,12,"Int")
    if (w<1 || hh<1)
        return false
    x := Round(x*w/1024),y := Round(y*hh/768),lp := (y<<16)|(x & 65535)
    DllCall("PostMessage","Ptr",hwnd,"UInt",0x200,"UPtr",0,"Ptr",lp)
    ok := DllCall("PostMessage","Ptr",hwnd,"UInt",0x201,"UPtr",1,"Ptr",lp)
    Sleep, 40
    ok := DllCall("PostMessage","Ptr",hwnd,"UInt",0x202,"UPtr",0,"Ptr",lp) && ok
    PortalLogWriteV66("STAGE3_CLICK phase=" . r.phase . " client_xy=" . x . "," . y . " sent=" . ok)
    return ok
}

StageThreeUiV533(r)
{
    ui := RecoveryMenuSnapshotV528(r)
    if (!ui.ok)
        return ui
    multi := D2GetModuleBaseV35(r.pid,"D2Multi.dll")
    h := multi ? D2OpenProcess(r.pid) : 0
    if (!h)
        return {ok:false,reason:"D2MULTI_NOT_READY"}
    try
    {
        if (!RecoveryMenuModuleV528(h,multi,0x4B95C235,0x3F000))
            return {ok:false,reason:"D2MULTI_VERSION"}
        namePtr := D2ReadU32(h,multi+0x39D2C)
        for _,c in ui.controls
        {
            if (c.type=6 && c.callback=multi+0x15380)
                ui.roles.openCreate := c
            if (c.type=6 && c.callback=multi+0x142C0)
                ui.roles.createRoom := c
            if (c.type=6 && c.callback=multi+0x8770)
                ui.modal := true
            if (c.type=1 && c.ptr=namePtr)
                ui.roles.roomName := c
        }
        StageThreeCanvasV539(r,h,ui)
        if (IsObject(ui.roles.createRoom))
        {
            candidate := false
            for _,c in ui.controls
                if (c.type=1 && c.w>=100 && c.h>=10 && c.h<=40
                    && c.y<ui.roles.createRoom.y && c.x>=ui.width/3)
                    if (!IsObject(candidate) || c.y<candidate.y || (c.y=candidate.y && c.x<candidate.x))
                        candidate := c
            if (IsObject(candidate))
                ui.roles.roomName := candidate
        }
        else
            ui.roles.Delete("roomName")
        ui.createForm := IsObject(ui.roles.createRoom) && IsObject(ui.roles.roomName) && !ui.modal
        shape := ""
        if (ManualLogActiveV81())
            for index,c in ui.controls
            {
                if (index>48)
                    break
                shape .= (shape="" ? "" : ";") . c.type . ":" . c.x . "," . c.y . "," . c.w . "," . c.h
                    . ":cb=" . V92Hex(c.callback)
            }
        PortalLogWriteV66("STAGE3_DLL_STATE phase=" . r.phase . " create_form=" . ui.createForm
            . " open_button=" . IsObject(ui.roles.openCreate) . " modal=" . ui.modal
            . " canvas=" . ui.width . "x" . ui.height . " canvas_source=" . ui.canvasSourceV539
            . " controls=" . shape,"STAGE3_DLL_STATE",1500)
        return ui
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

StageThreeCanvasV539(r,h,ui)
{
    ui.canvasValidV539 := true,ui.canvasSourceV539 := "EXISTING_MENU"
    createPanel := IsObject(ui.roles.createRoom)
    button := createPanel ? ui.roles.createRoom : ui.roles.openCreate
    if (!IsObject(button))
        return
    needW := button.x+button.w,needH := button.y
    width := ui.width,height := ui.height,source := "LOBBY_BACKGROUND_OR_DEFAULT"
    client := D2GetModuleBaseV35(r.pid,"D2Client.dll")
    if (client && RecoveryMenuModuleV528(h,client,0x4B95CA3E,0x135000)
        && MonsterBossProbeReadV1(h,client+0xDBC48,8,size))
    {
        nativeW := NumGet(size,0,"UInt"),nativeH := NumGet(size,4,"UInt")
        if (nativeW>=640 && nativeW<=8192 && nativeH>=480 && nativeH<=8192
            && nativeW>=needW && nativeH>=needH)
            width := Max(width,nativeW),height := Max(height,nativeH),source := "D2CLIENT_RENDER_SIZE"
    }
    cached := r.createButtonCanvasV540
    key := r.pid . "|" . r.birth
    if (IsObject(cached) && cached.key=key && cached.w>=needW && cached.h>=needH)
        width := Max(width,cached.w),height := Max(height,cached.h),source := "SAME_GAME_CREATE_BUTTONS"
    if (width<needW || height<needH)
    {
        if (needW<=1024 && needH<=768)
            width := Max(width,1024),height := Max(height,768),source := "LIVE_LOBBY_EXCEEDS_800X600"
        else
        {
            ui.canvasValidV539 := false
            return
        }
    }
    ui.buttonWidthV540 := width,ui.buttonHeightV540 := height,ui.canvasSourceV539 := source
    r.createButtonCanvasV540 := {key:key,w:width,h:height}
    if (!createPanel)
        ui.width := width,ui.height := height
}

StageThreeClickV533(r,role)
{
    ui := StageThreeUiV533(r)
    if (!ui.ok || ui.modal || !ui.canvasValidV539)
    {
        PortalLogWriteV66("STAGE3_DLL_WAIT phase=" . r.phase . " reason=" . ui.reason
            . " modal=" . ui.modal,"STAGE3_DLL_WAIT",1500)
        return false
    }
    if (role="openCreate" && ui.createForm)
        return true
    c := ui.roles[role]
    if (!IsObject(c) || (role!="openCreate" && !ui.createForm))
        return false
    hwnd := StageTwoWindowV166(r)
    VarSetCapacity(rect,16,0)
    if (!hwnd || !DllCall("GetClientRect","Ptr",hwnd,"Ptr",&rect))
        return false
    w := NumGet(rect,8,"Int"),height := NumGet(rect,12,"Int")
    if (w<1 || height<1 || c.w<1 || c.h<1)
        return false
    canvasW := role="roomName" ? ui.width : ui.buttonWidthV540
    canvasH := role="roomName" ? ui.height : ui.buttonHeightV540
    if (canvasW<1 || canvasH<1)
        return false
    x := Round((c.x+c.w/2)*w/canvasW),y := Round((c.y-c.h/2)*height/canvasH)
    if (x<0 || y<0 || x>=w || y>=height)
        return false
    lp := (y<<16)|(x & 65535)
    DllCall("PostMessage","Ptr",hwnd,"UInt",0x200,"UPtr",0,"Ptr",lp)
    if (!DllCall("PostMessage","Ptr",hwnd,"UInt",0x201,"UPtr",1,"Ptr",lp))
        return false
    Sleep, 40
    sent := DllCall("PostMessage","Ptr",hwnd,"UInt",0x202,"UPtr",0,"Ptr",lp)
    PortalLogWriteV66("STAGE3_DLL_CLICK phase=" . r.phase . " role=" . role . " client_xy=" . x . "," . y . " queued=" . sent
        . " native_canvas=" . canvasW . "x" . canvasH . " client_size=" . w . "x" . height
        . " canvas_source=" . ui.canvasSourceV539)
    if (sent && role="roomName")
    {
        Sleep, 80
        check := StageThreeUiV533(r)
        return check.ok && check.createForm && check.roles.roomName.ptr=c.ptr && check.focus=c.ptr
    }
    return sent
}

StageThreeNameReadV533(r)
{
    ui := StageThreeUiV533(r)
    if (!ui.ok || !ui.createForm)
        return ""
    h := D2OpenProcess(r.pid)
    if (!h)
        return ""
    try
        return D2ReadUnicodeV33(h,ui.roles.roomName.ptr+0x5C,64)
    finally
        DllCall("CloseHandle","Ptr",h)
}

StageTwoNameV166(r)
{
    hwnd := StageTwoWindowV166(r)
    if (!hwnd || !StageThreeClickV533(r,"roomName"))
        return false
    Random, a, 97, 122
    Random, b, 97, 122
    Random, n, 0, 99
    name := Chr(a) . Chr(b) . Format("{:02}",n)
    if (!StageTwoKeyV166(r,"End"))
        return false
    Loop, 24
        if (!DllCall("PostMessage","Ptr",hwnd,"UInt",0x102,"UPtr",8,"Ptr",1))
            return false
    Loop, Parse, name
    {
        if (!DllCall("PostMessage","Ptr",hwnd,"UInt",0x102,"UPtr",Asc(A_LoopField),"Ptr",1))
            return false
        Sleep, 35
    }
    Sleep, 80
    if (StageThreeNameReadV533(r)!=name)
    {
        PortalLogWriteV66("STAGE3_DLL_NAME_WAIT reason=TEXT_NOT_CONFIRMED create=NOT_SENT","STAGE3_DLL_NAME_WAIT",1500)
        return false
    }
    r.name := name
    PortalLogWriteV66("STAGE3_ROOM_NAME value=" . name . " verified=DLL_EDIT_BUFFER")
    return true
}

StageThreeExitCleanupTimerV534:
StageThreeExitCleanupV534()
return

StageThreeExitCleanupV534()
{
    global stageThreeExitPendingV534
    pending := stageThreeExitPendingV534
    if (!IsObject(pending))
    {
        SetTimer, StageThreeExitCleanupTimerV534, Off
        return true
    }
    wait := DllCall("WaitForSingleObject","Ptr",pending.thread,"UInt",0)
    if (wait!=0)
        return false
    DllCall("GetExitCodeThread","Ptr",pending.thread,"UIntP",result)
    DllCall("VirtualFreeEx","Ptr",pending.process,"Ptr",pending.remote,"UPtr",0,"UInt",0x8000)
    DllCall("CloseHandle","Ptr",pending.thread)
    DllCall("CloseHandle","Ptr",pending.process)
    stageThreeExitPendingV534 := false
    SetTimer, StageThreeExitCleanupTimerV534, Off
    PortalLogWriteV66("STAGE3_SAVE_EXIT_DLL_END pid=" . pending.pid . " return=" . V92Hex(result)
        . " completed=" . (result=0x534) . " effect=WAIT_LOBBY_CONFIRMATION")
    return true
}

StageThreeExitBytesV534(h,address,expected)
{
    if (!RegExMatch(expected,"i)^(?:[0-9A-F]{2})+$"))
        return false
    length := StrLen(expected)//2
    if (!MonsterBossProbeReadV1(h,address,length,actual))
        return false
    StringUpper, expected, expected
    return MonsterBossProbeHexV1(actual,length)==expected
}

StageThreeExitV534(r)
{
    global stageThreeExitPendingV534
    if (r.exitSentV534)
        return true
    if (!StageThreeExitCleanupV534() || !StageTwoWindowV166(r) || !FarmAttackReleaseWaitV15())
        return false
    base := D2GetModuleBaseV35(r.pid,"D2Client.dll"),h := base ? D2OpenProcess(r.pid) : 0
    if (!h)
        return false
    remote := 0,thread := 0
    try
    {
        if (!RecoveryMenuModuleV528(h,base,0x4B95CA3E,0x135000))
        {
            PortalLogWriteV66("STAGE3_SAVE_EXIT_WAIT reason=D2CLIENT_VERSION","STAGE3_SAVE_EXIT_WAIT",2000)
            return false
        }
        expected := "C705" . NativeLE32V9(base+0xF8C9C) . "00000000C705"
            . NativeLE32V9(base+0x11C404) . "01000000E8F71DFDFFC705"
            . NativeLE32V9(base+0x11C3A4) . "01000000C3"
        if (!StageThreeExitBytesV534(h,base+0x42850,expected))
        {
            exitActualV563 := MonsterBossProbeReadV1(h,base+0x42850,StrLen(expected)//2,exitBytesV563)
                ? MonsterBossProbeHexV1(exitBytesV563,StrLen(expected)//2) : "READ_FAILED"
            senderActualV563 := MonsterBossProbeReadV1(h,base+0x14660,19,senderBytesV563)
                ? MonsterBossProbeHexV1(senderBytesV563,19) : "READ_FAILED"
            PortalLogWriteV66("STAGE3_SAVE_EXIT_WAIT reason=D2CLIENT_EXIT_ENTRY_SIGNATURE base=" . V92Hex(base)
                . " expected=" . expected . " actual_42850=" . exitActualV563 . " sender_14660=" . senderActualV563
                ,"STAGE3_SAVE_EXIT_WAIT",2000)
            return false
        }
        player := D2ReadU32(h,base+0x11BBFC)
        path := player ? D2ReadU32(h,player+0x2C) : 0
        level := path ? CoordLevelV14(h,D2ReadU32(h,path+0x1C)) : 0
        if (!level || !StageTwoWindowV166(r))
            return false
        code := "60B8" . NativeLE32V9(base+0x42850) . "FFD061B834050000C20400"
        length := StrLen(code)//2
        VarSetCapacity(blob,length,0)
        Loop, %length%
            NumPut("0x" . SubStr(code,A_Index*2-1,2),blob,A_Index-1,"UChar")
        remote := DllCall("VirtualAllocEx","Ptr",h,"Ptr",0,"UPtr",length,"UInt",0x3000,"UInt",0x40,"Ptr")
        if (!remote || !DllCall("WriteProcessMemory","Ptr",h,"Ptr",remote,"Ptr",&blob,"UPtr",length,"UPtrP",written) || written!=length)
            return false
        DllCall("FlushInstructionCache","Ptr",h,"Ptr",remote,"UPtr",length)
        if (!StageTwoWindowV166(r))
            return false
        thread := DllCall("CreateRemoteThread","Ptr",h,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
        if (!thread)
            return false
        stageThreeExitPendingV534 := {process:h,remote:remote,thread:thread,pid:r.pid,birth:r.birth}
        r.exitSentV534 := true,r.exitAtV534 := A_TickCount
        h := 0,remote := 0
        SetTimer, StageThreeExitCleanupTimerV534, 100
        PortalLogWriteV66("STAGE3_SAVE_EXIT_DLL_SENT pid=" . r.pid . " entry=42850 click=0 next=WAIT_LOBBY")
        return true
    }
    finally
    {
        if (remote && !thread)
            DllCall("VirtualFreeEx","Ptr",h,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        if (h)
            DllCall("CloseHandle","Ptr",h)
    }
}

StageThreeGameActivateV680(r)
{
    global stageTwoV166,backgroundPidV63,backgroundHwndV63
    if (stageTwoV166!=r || r.phase!="WAIT_GAME")
        return false
    if (r.gameActivatedV680)
        return true
    hwnd := StageTwoWindowV166(r)
    if (!hwnd || !BackgroundValidV63() || backgroundPidV63!=r.pid || backgroundHwndV63!=hwnd
        || !DllCall("IsWindowEnabled","Ptr",hwnd) || DllCall("IsHungAppWindow","Ptr",hwnd))
        return false
    if (r.gameActivateAtV680 && A_TickCount-r.gameActivateAtV680<1000)
        return false
    r.gameActivateAtV680 := A_TickCount
    queued := true
    for _,message in [{id:0x1C,wp:1},{id:0x6,wp:1},{id:0x7,wp:0}]
        if (!DllCall("PostMessage","Ptr",hwnd,"UInt",message.id,"UPtr",message.wp,"Ptr",0))
            queued := false
    if (queued && stageTwoV166=r && r.phase="WAIT_GAME" && BackgroundValidV63()
        && backgroundPidV63=r.pid && backgroundHwndV63=hwnd)
        r.gameActivatedV680 := true
    PortalLogWriteV66("STAGE3_NEW_GAME_BACKGROUND_INPUT pid=" . r.pid . " hwnd=" . V92Hex(hwnd)
        . " queued=" . r.gameActivatedV680 . " foreground_forced=0 focus_message=SETFOCUS"
        . " once_per_new_room=1 effect=WAIT_LIVE_PROGRESS next="
        . (r.gameActivatedV680 ? "RESTART_FARM" : "WAIT_INPUT_QUEUE"))
    return r.gameActivatedV680
}

; V987: Re-enter character using the existing GD3 click dispatcher.
; No GD4 loginRecovery flag or recovery timer is involved in this action.
StageThreeCharacterEnterV987(r)
{
    global stageTwoV166
    if (stageTwoV166!=r || r.loginRecoveryV489)
        return false
    ui := RecoveryMenuSnapshotV528(r)
    if (!ui.ok || ui.modal || !ui.character || !IsObject(ui.roles.enter)
        || !ui.width || !ui.height)
        return false
    c := ui.roles.enter
    x := Round((c.x+c.w/2)*1024/ui.width)
    y := Round((c.y-c.h/2)*768/ui.height)
    if (x<0 || y<0 || x>=1024 || y>=768)
        return false
    sent := StageTwoClickV166(r,x,y)
    PortalLogWriteV66("STAGE3_CHAR_REENTER method=DLL_ENTER_CONTROL sent=" . sent
        . " next=WAIT_LOBBY_NO_STAGE4","STAGE3_CHAR_REENTER",1000)
    return sent
}

StageTwoTickV166()
{
    global farmManualStoppedV2026,farmUserPausedV2026
    if (farmUserPausedV2026)
        return
    if (farmManualStoppedV2026)
        return false
    global stageTwoV166,farmShowItemsPendingV165,continuousMapV168,farmRestartReasonV238
    global mapWorkflowV185,farmRunEpochV535
    static busy := false
    if (busy || !IsObject(stageTwoV166))
        return
    busy := true,h := 0
    try
    {
        r := stageTwoV166
        if (r.loginRecoveryV489)
        {
            RecoveryLoginTickV489(r)
            return
        }
        if (r.retryAtV237 && A_TickCount<r.retryAtV237)
            return
        if (A_TickCount>=r.until || !StageTwoWindowV166(r))
        {
            if (!RecoveryGameWindowContactV498(r) && RecoveryLoginBeginV489(r,"GAME_WINDOW_CONTACT_LOST"))
                return
            if (r.continuous || r.restartRunV17)
            {
                FarmRestartOnErrorV238("STAGE3_TIMEOUT_OR_GAME_NOT_READY")
            }
            else
                StageTwoStopV166("TIMEOUT_OR_GAME_WINDOW_CLOSED")
            return
        }
        base := D2GetModuleBaseV35(r.pid,"D2Client.dll"),h := base ? D2OpenProcess(r.pid) : 0
        player := h ? D2ReadU32(h,base+0x11BBFC) : 0
        path := player ? D2ReadU32(h,player+0x2C) : 0
        level := path ? CoordLevelV14(h,D2ReadU32(h,path+0x1C)) : 0
        elapsed := A_TickCount-r.at
        if (r.phase="RECOVER")
        {
            if (level)
                r.phase := "ESC",r.at := A_TickCount
            else if (StageTwoKeyV166(r,"Esc"))
                r.phase := "WAIT_LOBBY",r.at := A_TickCount,r.tries := 0
            return
        }
        if (r.phase="ESC")
        {
            GameRoomHistoryCaptureV252(r.pid)
            r.phase := "SAVE_EXIT",r.at := A_TickCount
            return
        }
        if (r.phase="SAVE_EXIT")
        {
            if (!level)
            {
                lobbyV534 := StageThreeUiV533(r)
                if (lobbyV534.ok && !lobbyV534.modal && IsObject(lobbyV534.roles.openCreate))
                {
                    r.phase := "WAIT_LOBBY",r.at := A_TickCount
                    PortalLogWriteV66("STAGE3_SAVE_EXIT_LOBBY_CONFIRMED next=CREATE_ROOM")
                }
                return
            }
            if (!r.exitSentV534)
            {
                if (!StageThreeExitV534(r))
                    return
                r.at := A_TickCount
            }
            else if (A_TickCount-r.exitAtV534>=10000)
                PortalLogWriteV66("STAGE3_SAVE_EXIT_WAIT reason=MAP_STILL_PRESENT duplicate_call=0","STAGE3_SAVE_EXIT_WAIT",2000)
            return
        }
        if (r.phase="WAIT_LOBBY" && !level && elapsed>=4000)
                if (r.phase="WAIT_LOBBY" && !level && elapsed>=4000)
        {
            if (RecoveryLoginScreenV489(r,"CONNECTING"))
            {
                PortalLogWriteV66("STAGE3_WAIT_LOBBY reason=PLEASE_WAIT login_again=0","STAGE3_WAIT_LOBBY",2000)
                return
            }
            if (RecoveryLoginScreenV489(r,"CHAR"))
            {
                ; V987: Character select is part of GD3 room creation, not a GD4 reset.
                ; Re-enter the character with the existing UI helper; never set loginRecovery here.
                r.lobbyReadyAtV494 := 0
                if (!r.lastEnterClickV494 || A_TickCount-r.lastEnterClickV494>=2000)
                {
                    if (StageThreeCharacterEnterV987(r))
                        r.lastEnterClickV494 := A_TickCount
                }
                PortalLogWriteV66("STAGE3_WAIT_LOBBY reason=STILL_AT_CHAR_SELECT next=RE_ENTER_NO_STAGE4","STAGE3_WAIT_LOBBY",2000)
                return
            }
            if (!RecoveryLobbyReadyV528(r))
            {
                PortalLogWriteV66("STAGE3_WAIT_LOBBY reason=LOBBY_NOT_VERIFIED","STAGE3_WAIT_LOBBY",2000)
                return
            }
            if (!StageThreeClickV533(r,"openCreate"))
                return
            r.phase := "NAME_FIELD",r.at := A_TickCount
            return
        }
        if (r.phase="NAME_FIELD" && elapsed>=750)
        {
            createUiV533 := StageThreeUiV533(r)
            if (!createUiV533.ok || createUiV533.modal)
                return
            if (!createUiV533.createForm)
            {
                if (!r.openCreateAtV533 || A_TickCount-r.openCreateAtV533>=1500)
                {
                    StageThreeClickV533(r,"openCreate")
                    r.openCreateAtV533 := A_TickCount
                }
                return
            }
            if (!StageThreeClickV533(r,"roomName"))
                return
            r.phase := "TYPE_NAME",r.at := A_TickCount
            return
        }
        if (r.phase="TYPE_NAME" && elapsed>=250)
        {
            if (!StageTwoNameV166(r))
                return
            r.tries++
            r.phase := "CREATE",r.at := A_TickCount
            return
        }
        if (r.phase="CREATE" && elapsed>=500)
        {
            if (StageThreeNameReadV533(r)!=r.name)
            {
                r.phase := "NAME_FIELD",r.at := A_TickCount
                return
            }
            if (!StageThreeClickV533(r,"createRoom"))
                return
            GameRoomHistoryCaptureV252(r.pid,r.name,"CREATE_CLICKED")
            ; A fresh room never inherits the old game's route/activation/ALT state.
            r.gameActivatedV680 := false,r.gameActivateAtV680 := 0
            r.routeResetNewRoomV612 := false,r.altDoneV421 := false
            r.freshFarmStartedV1802 := false
            r.phase := "WAIT_GAME",r.at := A_TickCount
            return
        }
        if (r.phase="WAIT_GAME")
        {
            if (player && path && D2ReadU32(h,player)=0 && D2ReadU32(h,player+0x0C)
                && (MapStage1ReadyV185(level) || (r.authenticatedV494 && level=75) || (r.recoveryOnlyV688 && level>0)) && elapsed>=1500)
            {
                if (r.authenticatedV494 && level=75 && !MapStage1ReadyV185(level))
                    PortalLogWriteV66("STAGE4_WAIT_GAME_TOWN_ACCEPT level=" . level . " pid=" . r.pid . " next=INPUT_ACTIVATE_STAGE1")
                if (!MonsterBossProbeReadV1(h,path,0x20,entryPBV680)
                    || CoordLevelV14(h,NumGet(entryPBV680,0x1C,"UInt"))!=level
                    || !NumGet(entryPBV680,2,"UShort") || !NumGet(entryPBV680,6,"UShort"))
                    return
                ; The new room is already live: capture before any later stage can fail.
                GameRoomHistoryCaptureV252(r.pid)
                if (!StageThreeGameActivateV680(r))
                    return
                if (r.authenticatedV494 && !r.windowGameAppliedV1503)
                    RecoveryWindowPositionRestoreV1503(r,"IN_GAME")
                if (r.authenticatedV494 && !r.stage4InputReadyLoggedV681)
                {
                    r.stage4InputReadyLoggedV681 := true
                    PortalLogWriteV66("STAGE4_CHARACTER_IN_GAME_INPUT_READY pid=" . r.pid . " next=STAGE1")
                }
                if (r.recoveryOnlyV688)
                {
                    StageTwoStopV166("WATCHDOG_ROOM_READY_NO_ROUTE")
                    return
                }
                if (!FarmEntryActivateV565(r.pid,r.hwnd,r))
                    return
                if (!r.routeResetNewRoomV612)
                {
                    FarmNewRoomRouteResetV612(r.pid,level)
                    r.routeResetNewRoomV612 := true
                }
                if (!r.altDoneV421)
                {
                    if (!MonsterBossProbeReadV1(h,path,0x20,altPBV421))
                        return
                    farmShowItemsPendingV165 := true
                    FarmMapAltTickV199(h,player,altPBV421,r.pid,true)
                    if (farmShowItemsPendingV165)
                        return
                    r.altDoneV421 := true
                    PortalLogWriteV66("STAGE3_NEW_GAME_ALT level=" . level . " presses=1 next=STAGE1_OR_END")
                }
                if (r.restartRunV17 || (r.continuous && continuousMapV168))
                {
                    ; START a genuinely fresh Farm, once, only after the new
                    ; game has been verified. Never resume the previous route.
                    if (!r.freshFarmStartedV1802)
                    {
                        FarmStartPrepareV2()
                        r.freshFarmStartedV1802 := true
                        PortalLogWriteV66("STAGE_FRESH_START map=" . mapWorkflowV185.map
                            . " pid=" . r.pid . " epoch=" . farmRunEpochV535
                            . " route=NEW session=NEW")
                    }
                    if (MapStage1RestartV185(r.hwnd))
                    {
                        farmRestartReasonV238 := ""
                        StageTwoStopV166("CONTINUOUS_NEW_ROOM_READY")
                    }
                    else
                        FarmRestartOnErrorV238("STAGE1_RESTART_NOT_READY")
                    return
                }
                StageTwoStopV166("TEST_COMPLETE_NEW_ROOM_READY")
                PortalLogWriteV66("STAGE3_TEST_COMPLETE farm=OFF next=STOP")
                ToolTipInfoV386("TEST GIAI ĐOẠN 3 XONG - đã vào phòng mới - Farm tắt")
                SetTimer, RemoveToolTip, -5000
                return
            }
            if (!level && elapsed>=15000)
            {
                if (r.tries>=5)
                {
                    if (!r.continuous && !r.restartRunV17)
                    {
                        StageTwoStopV166("CREATE_FAILED_AFTER_5_ATTEMPTS")
                        return
                    }
                    FarmRestartOnErrorV238("STAGE3_FIVE_CREATE_ATTEMPTS_FAILED")
                    return
                }
                StageTwoKeyV166(r,"Esc")
                r.phase := "NAME_FIELD",r.at := A_TickCount
                PortalLogWriteV66("STAGE3_CREATE_RETRY reason=NO_GAME_AFTER_15_SECONDS")
            }
        }
    }
    catch e
    {
        if (IsObject(r) && (r.continuous || r.restartRunV17))
        {
            FarmRestartOnErrorV238("STAGE3_ERROR " . e.Message)
        }
        else
            StageTwoStopV166("ERROR " . e.Message)
    }
    finally
    {
        if (h)
            DllCall("CloseHandle","Ptr",h)
        busy := false
    }
}

RecoveryGameBrowseV489:
FileSelectFile, recoveryChosenV489, 3,, Chọn game hoặc shortcut mở game, Game (*.exe; *.lnk)
if (recoveryChosenV489!="")
{
    GuiControl, 1:, RecoveryGamePathInputV489, %recoveryChosenV489%
    RecoveryLoginSettingsSaveV489()
}
return

RecoverySettingsChangedV489:
RecoveryLoginSettingsSaveV489()
return

RecoveryGamePathNormalizeV493(value)
{
    return value
}

RecoveryGameExecutableV735(value,ByRef launchCommandV735 := "",ByRef launchDirV735 := "")
{
    command := Trim(value," `t`r`n"),exe := ""
    launchCommandV735 := "",launchDirV735 := ""
    if (SubStr(command,1,1)=Chr(34))
    {
        quoteEnd := InStr(command,Chr(34),false,2)
        if (!quoteEnd)
            return ""
        exe := SubStr(command,2,quoteEnd-2)
        launchCommandV735 := command
    }
    else if (RegExMatch(command,"i)^(.+?\.(?:exe|lnk))(?=\s|$)(.*)$",match))
    {
        exe := match1
        launchCommandV735 := Chr(34) . exe . Chr(34) . match2
    }
    else
        return ""
    SplitPath, exe,, launchDirV735
    return exe
}

RecoveryLoginLoadV489()
{
    global ConfigFile,currentProfile,recoveryGamePathV489,recoveryAccountV489,recoveryPasswordV489
    global recoverySettingsLoadingV734
    previousLoadingV734 := recoverySettingsLoadingV734,recoverySettingsLoadingV734 := true
    try
    {
        file := ProfileFile(currentProfile),section := ProfileSection(currentProfile)
        fields := {},migrationOK := true
        for _,spec in [{key:"RecoveryGamePath",legacy:"GamePath"}
            ,{key:"RecoveryAccount",legacy:"Account"}
            ,{key:"RecoveryPasswordProtected",legacy:"PasswordProtected"}]
        {
            key := spec.key,legacyKey := spec.legacy
            IniRead, value, %file%, %section%, %key%, __MISSING_LOGIN_V734__
            if (value="__MISSING_LOGIN_V734__")
            {
                IniRead, value, %ConfigFile%, LoginRecovery, %legacyKey%, %A_Space%
                if (key="RecoveryGamePath")
                    value := RecoveryGamePathNormalizeV493(value)
                else
                    value := Trim(value)
                EnsureProfileFolder()
                storedValueV735 := key="RecoveryGamePath" ? Chr(34) . value . Chr(34) : value
                IniWrite, %storedValueV735%, %file%, %section%, %key%
                if (ErrorLevel)
                    migrationOK := false
            }
            fields[key] := value
        }
        recoveryGamePathV489 := RecoveryGamePathNormalizeV493(fields.RecoveryGamePath)
        recoveryAccountV489 := Trim(fields.RecoveryAccount)
        recoveryPasswordV489 := RecoveryPasswordCryptV489(Trim(fields.RecoveryPasswordProtected),false)
        if (ProfileControlExistsV365("RecoveryGamePathInputV489"))
            GuiControl, 1:, RecoveryGamePathInputV489, %recoveryGamePathV489%
        if (ProfileControlExistsV365("RecoveryAccountInputV489"))
            GuiControl, 1:, RecoveryAccountInputV489, %recoveryAccountV489%
        if (ProfileControlExistsV365("RecoveryPasswordInputV489"))
            GuiControl, 1:, RecoveryPasswordInputV489, %recoveryPasswordV489%
        if (!migrationOK)
            FonInfoPushV385("Không lưu chuyển được Game / ID / Pass vào profile " . currentProfile . ".")
        return migrationOK
    }
    finally
        recoverySettingsLoadingV734 := previousLoadingV734
}

RecoveryLoginSettingsSaveV489(profileName := "")
{
    global currentProfile,recoveryGamePathV489,recoveryAccountV489,recoveryPasswordV489
    global recoverySettingsLoadingV734,guiBuilding
    if (recoverySettingsLoadingV734 || guiBuilding)
        return false
    fields := {}
    for _,spec in [{control:"RecoveryGamePathInputV489",key:"RecoveryGamePath"}
        ,{control:"RecoveryAccountInputV489",key:"RecoveryAccount"}
        ,{control:"RecoveryPasswordInputV489",key:"RecoveryPasswordProtected"}]
    {
        control := spec.control
        if (!ProfileControlExistsV365(control))
            return false
        GuiControlGet, value, 1:, %control%
        if (ErrorLevel)
            return false
        fields[spec.key] := value
    }
    fields.RecoveryGamePath := RecoveryGamePathNormalizeV493(fields.RecoveryGamePath)
    fields.RecoveryAccount := Trim(fields.RecoveryAccount)
    passwordDraftV734 := fields.RecoveryPasswordProtected
    encryptedV734 := RecoveryPasswordCryptV489(passwordDraftV734,true)
    if (passwordDraftV734!="" && encryptedV734="")
    {
        GuiControl, 1:, RecoveryLoginStatusV489, Không mã hóa được Pass; chưa lưu thay đổi đăng nhập.
        return false
    }
    fields.RecoveryPasswordProtected := encryptedV734
    profileName := profileName!="" ? profileName : currentProfile
    EnsureProfileFolder()
    file := ProfileFile(profileName),section := ProfileSection(profileName),savedOK := true
    for key,value in fields
    {
        storedValueV735 := key="RecoveryGamePath" ? Chr(34) . value . Chr(34) : value
        IniWrite, %storedValueV735%, %file%, %section%, %key%
        if (ErrorLevel)
        {
            savedOK := false
            continue
        }
        IniRead, savedValue, %file%, %section%, %key%, __MISSING_LOGIN_V734__
        if (savedValue="__MISSING_LOGIN_V734__" || savedValue!=value)
            savedOK := false
    }
    recoveryGamePathV489 := fields.RecoveryGamePath
    recoveryAccountV489 := fields.RecoveryAccount
    recoveryPasswordV489 := passwordDraftV734
    if (savedOK)
        GuiControl, 1:, RecoveryLoginStatusV489, % "Đã lưu Game / ID / Pass vào profile " . profileName . "."
    else
    {
        GuiControl, 1:, RecoveryLoginStatusV489, % "Không lưu đủ Game / ID / Pass: " . file
        FonInfoPushV385("Không lưu đủ Game / ID / Pass vào profile " . profileName . ".")
    }
    return savedOK
}

RecoveryPasswordCryptV489(value,protect := true)
{
    if (value="")
        return ""
    if (protect)
    {
        size := StrPut(value,"UTF-16")*2
        VarSetCapacity(data,size,0),StrPut(value,&data,"UTF-16")
    }
    else
    {
        if (!RegExMatch(value,"i)^(?:[0-9a-f]{2})+$"))
            return ""
        size := StrLen(value)//2,VarSetCapacity(data,size,0)
        Loop, %size%
            NumPut("0x" . SubStr(value,(A_Index-1)*2+1,2),data,A_Index-1,"UChar")
    }
    VarSetCapacity(input,A_PtrSize*2,0),VarSetCapacity(output,A_PtrSize*2,0)
    NumPut(size,input,0,"UInt"),NumPut(&data,input,A_PtrSize,"Ptr")
    fn := protect ? "Crypt32\CryptProtectData" : "Crypt32\CryptUnprotectData"
    if (!DllCall(fn,"Ptr",&input,"Ptr",0,"Ptr",0,"Ptr",0,"Ptr",0,"UInt",1,"Ptr",&output))
        return ""
    ptr := NumGet(output,A_PtrSize,"Ptr"),length := NumGet(output,0,"UInt"),result := ""
    try
    {
        if (protect)
        {
            Loop, %length%
                result .= Format("{:02X}",NumGet(ptr+0,A_Index-1,"UChar"))
        }
        else
            result := StrGet(ptr,"UTF-16")
    }
    finally
        DllCall("LocalFree","Ptr",ptr)
    return result
}

RecoveryGameWindowContactV498(r)
{
    if (!IsObject(r) || !r.pid)
        return false
    birthV499 := BackgroundBirthV63(r.pid)
    if (r.birth!="" && birthV499!="" && birthV499!=r.birth)
        return false
    if (r.hwnd && DllCall("IsWindow","Ptr",r.hwnd))
    {
        WinGet, pidV499, PID, % "ahk_id " . r.hwnd
        if (pidV499=r.pid)
            return true
    }
    WinGet, windowsV499, List, % "ahk_pid " . r.pid
    Loop, %windowsV499%
    {
        hwndV499 := windowsV499%A_Index%
        WinGetClass, classV499, ahk_id %hwndV499%
        WinGetTitle, titleV499, ahk_id %hwndV499%
        if (classV499="Diablo II" || (classV499!="#32770" && InStr(titleV499,"Diablo II")))
        {
            r.hwnd := hwndV499
            return true
        }
    }
    return false
}

FarmStartForcedV702(mapName)
{
    GuiControlGet, forceStage4V702, 1:, RecoveryStartTestV537
    if (!forceStage4V702)
        return false
    RecoveryForceStartV538(mapName)
    if (!FarmControlRunningV186())
        FarmStartKeepV697("MANUAL_GD4_WAIT")
    return true
}


; V986: GĐ4 TU DONG CHI DUOC KICH HOAT SAU KHI DU THOI GIAN "DUNG" INPUT.
; Moi nhanh loi game / mat cua so / loi bat dau / GD3 can chung cong nay.
; "Vao GD4" la nut thu cong va khong phu thuoc timer nay.
FarmWatchAutoRecoveryDueV986(sourceV986 := "")
{
    ; No new timer or game-window check. Read the original Đứng counter only.
    w := FarmWatchStateV688()
    FarmWatchSettingsV5()
    ; Refresh character activity before any automatic Stage 4 wait/due test.
    if (w.enabled)
        FarmWatchRefreshActivityV1080(w,watchSampleV1080)
    nowV986 := FarmWatchNowV688()
    if (!w.enabled || !w.period || w.sigPausedV753
        || nowV986-w.idleAtV650<w.period)
    {
        PortalLogWriteV66("STAGE4_AUTO_WAIT source=" . sourceV986
            . " enabled=" . w.enabled . " elapsed_ms=" . Max(0,nowV986-w.idleAtV650)
            . " required_ms=" . w.period . " next=WATCH_IDLE_INPUT", "STAGE4_AUTO_WAIT", 2000)
        return false
    }
    PortalLogWriteV66("STAGE4_AUTO_DUE source=" . sourceV986
        . " elapsed_ms=" . Max(0,nowV986-w.idleAtV650) . " required_ms=" . w.period
        . " next=GD4_ALLOWED", "STAGE4_AUTO_DUE", 1000)
    return true
}

FarmStartHealthV536(mapName)
{
    global backgroundPidV63,backgroundHwndV63,backgroundBirthV63,farmStartHealthV536
    global farmControlOwnerV186,mapButtonStartV172,mapWorkflowV185,farmRestartReasonV238,stageTwoV166
    if (FarmStartForcedV702(mapName))
        return true
    if (!SigBackgroundBindV179())
    {
        contact := {pid:backgroundPidV63,hwnd:backgroundHwndV63,birth:backgroundBirthV63}
        if (!RecoveryGameWindowContactV498(contact))
        {
            mapButtonStartV172 := false
            SetTimer, MapButtonStartTimerV172, Off
            GuiControl, 1:, RecoveryStartTestV537, 0
            RecoveryStartMissingGameV492(mapName)
            return true
        }
    }
    r := {pid:backgroundPidV63,hwnd:backgroundHwndV63,birth:backgroundBirthV63
        ,progressAt:A_TickCount,period:0x7FFFFFFF}
    WinGet, startMinV536, MinMax, % "ahk_id " . r.hwnd
    if (startMinV536=-1)
        DllCall("ShowWindowAsync","Ptr",r.hwnd,"Int",4)
    reason := FarmWatchHealthV5(r)
    if (reason="")
    {
        farmStartHealthV536 := false
        return false
    }
    ui := StageThreeUiV533(r)
    if (ui.ok && !ui.modal && IsObject(ui.roles.openCreate))
    {
        mapButtonStartV172 := false
        SetTimer, MapButtonStartTimerV172, Off
        FarmRuntimeResetV535("START_FROM_LOBBY")
        farmControlOwnerV186 := mapName,farmRestartReasonV238 := "STUCK"
        mapWorkflowV185 := {map:mapName,stage:3,startLevel:0,testRows:0}
        if (StageTwoArmV166(true))
            stageTwoV166.phase := "WAIT_LOBBY",stageTwoV166.at := A_TickCount-4000
        return true
    }
    key := r.pid . "|" . r.birth . "|" . mapName
    if (!IsObject(farmStartHealthV536) || farmStartHealthV536.key!=key)
        farmStartHealthV536 := {key:key,pid:r.pid,birth:r.birth}
    confirmed := FarmWatchConfirmV541(farmStartHealthV536,r.healthProbeV541)
    if (!confirmed)
    {
        farmControlOwnerV186 := mapName
        mapButtonStartV172 := {hwnd:r.hwnd,pid:r.pid,at:A_TickCount,phase:"WAIT_HEALTH"}
        SetTimer, MapButtonStartTimerV172, 250
        PortalLogWriteV66("START_GAME_HEALTH_WAIT reason=" . reason . " next=FRESH_SNAPSHOT","START_GAME_HEALTH",1500)
        return true
    }
    mapButtonStartV172 := false
    SetTimer, MapButtonStartTimerV172, Off
    RecoveryStartErrorV536(mapName,r,reason)
    if (!FarmControlRunningV186())
        FarmStartKeepV697("GAME_RECOVERY_WAIT")
    return true
}

RecoveryForceStartV538(mapName)
{
    global backgroundPidV63,backgroundHwndV63,backgroundBirthV63,mapButtonStartV172
    GuiControl, 1:, RecoveryStartTestV537, 0
    mapButtonStartV172 := false
    SetTimer, MapButtonStartTimerV172, Off
    SigBackgroundBindV179()
    r := {pid:backgroundPidV63,hwnd:backgroundHwndV63,birth:backgroundBirthV63}
    if (r.pid && r.birth!="" && BackgroundBirthV63(r.pid)=r.birth)
        return RecoveryStartErrorV536(mapName,r,"MANUAL_FORCE_STAGE4",true)
    return RecoveryStartMissingGameV492(mapName,true)
}

RecoveryStartErrorV536(mapName,contact,reason,manualV986 := false)
{
    global stageTwoV166,mapWorkflowV185,farmControlOwnerV186,farmRestartReasonV238,recoveryGamePathV489
    if (!manualV986 && !FarmWatchAutoRecoveryDueV986("START_ERROR_" . reason))
        return false
    if (!contact.pid || contact.birth="" || BackgroundBirthV63(contact.pid)!=contact.birth)
        return RecoveryStartMissingGameV492(mapName,manualV986)
    RecoveryLoginSettingsSaveV489()
    if (!FileExist(RecoveryGameExecutableV735(recoveryGamePathV489)))
    {
        FonInfoPushV385("[GĐ4] Game lỗi; cần chọn đúng đường dẫn Game.exe để mở lại.")
        return false
    }
    r := {pid:contact.pid,hwnd:contact.hwnd,birth:contact.birth,phase:"RECOVER"
        ,at:A_TickCount,until:A_TickCount+180000,tries:0,continuous:true,restartRunV17:true}
    farmControlOwnerV186 := mapName,farmRestartReasonV238 := "STUCK"
    mapWorkflowV185 := {map:mapName,stage:3,startLevel:0,testRows:0}
    stageTwoV166 := r
    if (!RecoveryLoginBeginV489(r,"START_GAME_ERROR: " . reason,true,manualV986))
    {
        stageTwoV166 := false
        return false
    }
    SetTimer, StageTwoTimerV166, 250
    FonInfoPushV385("[GĐ4] " . reason . " -> đóng game -> mở và đăng nhập lại -> tiếp tục " . mapName)
    PortalLogWriteV66("START_GAME_ERROR_STAGE4 reason=" . reason . " pid=" . r.pid
        . " close=BOUND_PID_BIRTH_ONLY next=RELAUNCH_LOGIN_STAGE3")
    return true
}

RecoveryStartMissingGameV492(mapName,manualV986 := false)
{
    global stageTwoV166,mapWorkflowV185,farmControlOwnerV186,farmRestartReasonV238
    global backgroundPidV63,backgroundHwndV63,backgroundBirthV63,recoveryGamePathV489,recoveryAccountV489,recoveryPasswordV489
    if (!manualV986 && !FarmWatchAutoRecoveryDueV986("START_WINDOW_LOST"))
        return false
    contactV499 := {pid:backgroundPidV63,hwnd:backgroundHwndV63,birth:backgroundBirthV63}
    if (RecoveryGameWindowContactV498(contactV499))
    {
        PortalLogWriteV66("STAGE4_BLOCKED reason=GAME_WINDOW_STILL_CONNECTED source=START next=KEEP_CURRENT_STAGE","STAGE4_CONNECTED",2000)
        return false
    }
    RecoveryLoginSettingsSaveV489()
    if (!FileExist(RecoveryGameExecutableV735(recoveryGamePathV489)))
    {
        GuiControl, 1:, RecoveryLoginStatusV489, Start: đường dẫn Game chưa đúng; chọn lại Game.exe.
        FonInfoPushV385("[GĐ4] Không mở được: đường dẫn Game chưa tồn tại")
        PortalLogWriteV66("STAGE4_START_BLOCKED reason=GAME_PATH_NOT_FOUND account_present=" . (recoveryAccountV489!="")
            . " password_present=" . (recoveryPasswordV489!="") . " credentials_logged=0")
        return false
    }
    targetPid := 0,targetHwnd := 0
    if (backgroundHwndV63 && DllCall("IsWindow","Ptr",backgroundHwndV63))
    {
        WinGet, pid, PID, % "ahk_id " . backgroundHwndV63
        WinGet, path, ProcessPath, % "ahk_id " . backgroundHwndV63
        if (pid=backgroundPidV63 && path=RecoveryGameExecutableV735(recoveryGamePathV489))
            targetPid := pid,targetHwnd := backgroundHwndV63
    }
    if (!targetPid)
    {
        candidates := [],seenPids := {}
        WinGet, windowsV492, List
        Loop, %windowsV492%
        {
            hwnd := windowsV492%A_Index%
            WinGet, path, ProcessPath, ahk_id %hwnd%
            if (path!=RecoveryGameExecutableV735(recoveryGamePathV489))
                continue
            WinGet, pid, PID, ahk_id %hwnd%
            if (seenPids.HasKey(pid))
                continue
            seenPids[pid] := true
            candidates.Push({pid:pid,hwnd:hwnd})
        }
        if (candidates.Length()=1)
            targetPid := candidates[1].pid,targetHwnd := candidates[1].hwnd
        else if (candidates.Length()>1)
        {
            FonInfoPushV385("[START] Có nhiều tiến trình game cùng đường dẫn; chưa chọn được game lỗi")
            PortalLogWriteV66("STAGE4_START_BLOCKED reason=MULTIPLE_GAME_PROCESSES count=" . candidates.Length() . " credentials_logged=0")
            return false
        }
    }
    r := {pid:targetPid,hwnd:targetHwnd,birth:targetPid ? BackgroundBirthV63(targetPid) : ""
        ,phase:"RECOVER",at:A_TickCount,until:A_TickCount+180000,tries:0,continuous:true,restartRunV17:true}
    if (RecoveryGameWindowContactV498(r))
    {
        PortalLogWriteV66("STAGE4_BLOCKED reason=GAME_WINDOW_STILL_CONNECTED source=START next=KEEP_CURRENT_STAGE","STAGE4_CONNECTED",2000)
        return false
    }
    previousStage := stageTwoV166,previousMap := mapWorkflowV185
    stageTwoV166 := r
    mapWorkflowV185 := {map:mapName,stage:3,startLevel:0,testRows:0}
    farmControlOwnerV186 := mapName,farmRestartReasonV238 := "STUCK"
    if (!RecoveryLoginBeginV489(r,"GAME_WINDOW_CONTACT_LOST_AT_START",false,manualV986))
    {
        stageTwoV166 := previousStage,mapWorkflowV185 := previousMap
        return false
    }
    SetTimer, StageTwoTimerV166, 250
    PortalLogWriteV66("START_STAGE1_TO_STAGE3_RECOVERY map=" . mapName . " existing_pid=" . targetPid . " launch_mode=3dfx")
    return true
}

; Save the window position before Stage 4 / automatic game reset. The relaunch
; is always windowed at the game's 1024x768 client resolution.
RecoveryWindowPositionCaptureV1503(r)
{
    global backgroundHwndV63,backgroundPidV63,recoveryWindowPositionV1503
    hwnd := IsObject(r) && r.hwnd && DllCall("IsWindow","Ptr",r.hwnd) ? r.hwnd : 0
    if (!hwnd && backgroundHwndV63 && DllCall("IsWindow","Ptr",backgroundHwndV63))
        hwnd := backgroundHwndV63
    if (!hwnd && IsObject(r) && r.pid)
        hwnd := WinExist("ahk_pid " . r.pid)
    if (!hwnd || !DllCall("IsWindowVisible","Ptr",hwnd))
        return false
    WinGet, statusV1503, MinMax, % "ahk_id " . hwnd
    if (statusV1503=-1)
        return false
    WinGetPos, wxV1503, wyV1503, wwV1503, whV1503, % "ahk_id " . hwnd
    if (wwV1503<100 || whV1503<100)
        return false
    pos := {x:wxV1503,y:wyV1503}
    recoveryWindowPositionV1503 := pos
    if (IsObject(r))
        r.savedWindowPositionV1503 := pos
    PortalLogWriteV66("GAME_WINDOW_POSITION_SAVED xy=" . pos.x . "," . pos.y
        . " before=GAME_RESET")
    return true
}

RecoveryWindowPositionRestoreV1503(r,phase:="WINDOW_READY")
{
    global recoveryWindowPositionV1503
    if (!IsObject(r) || !r.hwnd || !DllCall("IsWindow","Ptr",r.hwnd))
        return false
    pos := IsObject(r.savedWindowPositionV1503) ? r.savedWindowPositionV1503 : recoveryWindowPositionV1503
    WinGet, actualPidV1503, PID, % "ahk_id " . r.hwnd
    if (actualPidV1503!=r.pid)
        return false
    ; Once at bind and once at the GD4 character-to-game boundary, never during Farm.
    stamp := phase="IN_GAME" ? "windowGameAppliedV1503" : "windowBindAppliedV1503"
    if (r[stamp])
        return true
    WinGet, statusV1503, MinMax, % "ahk_id " . r.hwnd
    if (statusV1503!=0)
        DllCall("ShowWindowAsync","Ptr",r.hwnd,"Int",9)
    WinGet, styleV1503, Style, % "ahk_id " . r.hwnd
    WinGet, exStyleV1503, ExStyle, % "ahk_id " . r.hwnd
    VarSetCapacity(rectV1503,16,0)
    NumPut(1024,rectV1503,8,"Int"),NumPut(768,rectV1503,12,"Int")
    if (!DllCall("AdjustWindowRectEx","Ptr",&rectV1503,"UInt",styleV1503,"Int",0,"UInt",exStyleV1503))
        return false
    widthV1503 := NumGet(rectV1503,8,"Int")-NumGet(rectV1503,0,"Int")
    heightV1503 := NumGet(rectV1503,12,"Int")-NumGet(rectV1503,4,"Int")
    targetX := IsObject(pos) ? pos.x : Floor((A_ScreenWidth-widthV1503)/2)
    targetY := IsObject(pos) ? pos.y : Floor((A_ScreenHeight-heightV1503)/2)
    xV1503 := Max(0,Min(targetX,A_ScreenWidth-widthV1503))
    yV1503 := Max(0,Min(targetY,A_ScreenHeight-heightV1503))
    WinMove, % "ahk_id " . r.hwnd,, % xV1503, % yV1503, % widthV1503, % heightV1503
    WinGet, statusV1503, MinMax, % "ahk_id " . r.hwnd
    WinGetPos, axV1503, ayV1503, awV1503, ahV1503, % "ahk_id " . r.hwnd
    if (statusV1503!=0 || Abs(axV1503-xV1503)>2 || Abs(ayV1503-yV1503)>2
        || Abs(awV1503-widthV1503)>4 || Abs(ahV1503-heightV1503)>4)
    {
        PortalLogWriteV66("GAME_WINDOW_POSITION_RETRY phase=" . phase
            . " goal=" . xV1503 . "," . yV1503 . "," . widthV1503 . "x" . heightV1503
            . " actual=" . axV1503 . "," . ayV1503 . "," . awV1503 . "x" . ahV1503
            ,"WINDOW_POSITION_RETRY",2000)
        return false
    }
    r[stamp] := true
    PortalLogWriteV66("GAME_WINDOW_POSITION_RESTORED phase=" . phase
        . " xy=" . axV1503 . "," . ayV1503 . " size=" . awV1503 . "x" . ahV1503)
    return true
}

RecoveryLoginBeginV489(r,reason,scheduledCheck := false,manualV986 := false)
{
    global stageTwoV166,recoveryGamePathV489,recoveryAccountV489,recoveryPasswordV489,autoMonsterAttackOn
    global sigBusyV147,sigCancelV147,scosEntryV162,coordGoV59,farmRestartReasonV238
    ; V986: Tat ca duong reset tu dong phai qua bo dem input, ke ca loi GD3.
    if (!manualV986 && !FarmWatchAutoRecoveryDueV986("LOGIN_BEGIN_" . reason))
        return false
    if (stageTwoV166!=r)
        return false
    if (SigResetProtectedV753())
        return false
    if (!scheduledCheck && RecoveryGameWindowContactV498(r))
    {
        PortalLogWriteV66("STAGE4_BLOCKED reason=GAME_WINDOW_STILL_CONNECTED source=" . reason
            . " next=KEEP_CURRENT_STAGE","STAGE4_CONNECTED",2000)
        return false
    }
    RecoveryLoginSettingsSaveV489()
    if (!FileExist(RecoveryGameExecutableV735(recoveryGamePathV489)))
    {
        GuiControl, 1:, RecoveryLoginStatusV489, GĐ4: chọn lại đường dẫn Game.exe.
        PortalLogWriteV66("STAGE4_LOGIN_WAIT reason=GAME_PATH_NOT_FOUND credentials_logged=0","STAGE4_LOGIN_WAIT",2000)
        return false
    }
    if (stageTwoV166!=r)
        return false

    if (SigResetProtectedV753())
        return false
    ; Capture user-selected window position before auto/manual reset, not a fixed corner.
    RecoveryWindowPositionCaptureV1503(r)
    ; GD4 is an explicit STOP -> fresh game -> START cycle. STOP old Farm
    ; BEFORE closing the game; retain only this login/create-room controller.
    FarmStageFreshStopV1802(4,r)
    ; GD4 must not reuse any per-room steps from the previous GD3 run.
    r.freshFarmStartedV1802 := false
    r.routeResetNewRoomV612 := false,r.altDoneV421 := false
    r.gameActivatedV680 := false,r.gameActivateAtV680 := 0
    r.exitSentV534 := false,r.exitAtV534 := 0,r.lastEnterClickV494 := 0
    r.openCreateAtV533 := 0,r.tries := 0,r.name := ""
    r.windowGameAppliedV1503 := false,r.stage4InputReadyLoggedV681 := false
    r.stage4ManualV986 := manualV986 ? true : false
    r.stage4CleanupV1555 := false
    r.loginRecoveryV489 := true,r.phase := "LOGIN_RECOVERY",r.loginStepV489 := "CLOSE",r.loginAtV489 := A_TickCount
    r.retryAtV237 := 0,r.until := A_TickCount+180000
    GuiControl, 1:, RecoveryLoginStatusV489, GĐ4: đóng game cũ rồi mở lại.
    FonInfoPushV385("[GĐ4] Phục hồi đăng nhập → trả về GĐ3 tạo phòng")
    PortalLogWriteV66("STAGE4_LOGIN_BEGIN reason=" . reason . " next=CLOSE_BOUND_GAME_ONLY credentials_logged=0")
    SetTimer, StageTwoTimerV166, 250
    return true
}

; GĐ4 / BƯỚC 1: CHỈ KILL GAME CŨ. Tuyệt đối không mở cửa sổ mới ở đây.
; Ưu tiên PID đã gắn, sau đó tìm mọi Game.exe cùng đường dẫn đã cấu hình
; để không bỏ sót cửa sổ lỗi khi PID cũ không còn hợp lệ.
RecoveryKillOldGameV1555(r)
{
    global recoveryGamePathV489
    exe := RecoveryGameExecutableV735(recoveryGamePathV489)
    if (exe="")
        return false
    SplitPath, exe, exeName
    pids := {},seen := {}
    if (r.pid && r.birth!="" && BackgroundBirthV63(r.pid)=r.birth)
        pids[r.pid] := true

    ; Bắt cả cửa sổ lỗi (có thể mất liên kết với r.pid).
    WinGet, gameWindowsV1555, List
    Loop, %gameWindowsV1555%
    {
        hwndV1555 := gameWindowsV1555%A_Index%
        WinGet, pidV1555, PID, ahk_id %hwndV1555%
        if (!pidV1555 || seen.HasKey(pidV1555))
            continue
        seen[pidV1555] := true
        WinGet, pathV1555, ProcessPath, ahk_id %hwndV1555%
        if (pathV1555=exe)
            pids[pidV1555] := true
    }

    ; Bắt tiến trình game mất cửa sổ / bị treo; không dựa riêng vào PID cũ.
    try
    {
        for procV1555 in ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId,ExecutablePath FROM Win32_Process WHERE Name='" . exeName . "'")
        {
            pidV1555 := procV1555.ProcessId
            if (pidV1555 && procV1555.ExecutablePath=exe)
                pids[pidV1555] := true
        }
    }
    catch eV1555
    {
        PortalLogWriteV66("STAGE4_KILL_WMI_UNAVAILABLE fallback=WINDOW_AND_BOUND_PID")
    }
    for pidV1555,_ in pids
    {
        Process, Exist, %pidV1555%
        if (ErrorLevel)
        {
            Process, Close, %pidV1555%
            Process, Exist, %pidV1555%
            if (ErrorLevel)
            {
                PortalLogWriteV66("STAGE4_KILL_RETRY pid=" . pidV1555)
                return false
            }
        }
    }
    ; Không mở game mới cho tới khi danh sách cũ đã kill xong.
    return true
}

; Farm runtime was already STOPped at GD4 entry. This is only a
; defensive cleanup after the old process has actually exited.
RecoveryAfterKillResetV1555(r)
{
    global scosEntryV162,coordGoV59,farmRestartReasonV238,autoMonsterAttackOn
    if (r.stage4CleanupV1555)
        return
    FarmAttackHoldReleaseV15()
    scosEntryV162 := false,coordGoV59 := false
    SetTimer, ScosEntryTimerV162, Off
    SetTimer, CoordGoTimerV59, Off
    SetTimer, CoordGoInputTimerV139, Off
    SetTimer, CainResumeBuffTimerV387, Off
    SetTimer, MapStage2FlowTimerV372, Off
    CoordRouteResetV16()
    autoMonsterAttackOn := false
    SetTimer, AutoMonsterAttackTimer, Off
    PickupEnabledSetV71(false,true,false)
    FarmCastSyncV88(false)
    r.stage4CleanupV1555 := true
}

RecoveryLoginStepV489(r,step)
{
    r.loginStepV489 := step,r.loginAtV489 := A_TickCount
    GuiControl, 1:, RecoveryLoginStatusV489, % "GĐ4: " . step
    PortalLogWriteV66("STAGE4_LOGIN_STEP step=" . step . " credentials_logged=0")
}

RecoveryMenuModuleV528(h,base,stamp,imageSize)
{
    if (!base || !MonsterBossProbeReadV1(h,base,0x40,dos) || NumGet(dos,0,"UShort")!=0x5A4D)
        return false
    pe := NumGet(dos,0x3C,"UInt")
    return pe>=0x40 && pe<=0x1000 && MonsterBossProbeReadV1(h,base+pe,0x80,nt)
        && NumGet(nt,0,"UInt")=0x4550 && NumGet(nt,4,"UShort")=0x14C
        && NumGet(nt,8,"UInt")=stamp && NumGet(nt,0x50,"UInt")=imageSize
}

RecoveryMenuSnapshotV528(r)
{
    if (!IsObject(r) || !StageTwoWindowV166(r))
        return {ok:false,reason:"GAME_WINDOW"}
    win := D2GetModuleBaseV35(r.pid,"D2Win.dll"),launch := D2GetModuleBaseV35(r.pid,"D2Launch.dll")
    h := win && launch ? D2OpenProcess(r.pid) : 0
    if (!h)
        return {ok:false,reason:"MENU_DLL_NOT_READY"}
    try
    {
        if (!RecoveryMenuModuleV528(h,win,0x4B95C21D,0xCF000)
            || !RecoveryMenuModuleV528(h,launch,0x4B95C258,0x2D000))
            return {ok:false,reason:"MENU_DLL_VERSION"}
        if (!MonsterBossProbeReadV1(h,win+0x214A0,4,headBuf))
            return {ok:false,reason:"CONTROL_HEAD_READ"}
        head := NumGet(headBuf,0,"UInt"),ptr := head,controls := [],seen := {}
        ui := {ok:true,reason:"OK",controls:controls,roles:{},width:800,height:600,modal:false
            ,focus:D2ReadU32(h,win+0x214B0),winBase:win,launchBase:launch,head:head}
        account := D2ReadU32(h,launch+0x254FC),password := D2ReadU32(h,launch+0x25504)
        modalCount := D2ReadU32(h,launch+0x25E34)
        modalPtrs := {}
        if (modalCount>0 && modalCount<=64 && MonsterBossProbeReadV1(h,launch+0x253C0,modalCount*4,modalBuf))
            Loop, %modalCount%
                modalPtrs[NumGet(modalBuf,(A_Index-1)*4,"UInt")] := true
        Loop, 256
        {
            if (!ptr)
                break
            if (ptr<0x10000 || Mod(ptr,4) || seen.HasKey(ptr)
                || !MonsterBossProbeReadV1(h,ptr,0x40,b))
                return {ok:false,reason:"CONTROL_LIST_CHANGING"}
            seen[ptr] := true
            type := NumGet(b,0,"UInt"),x := NumGet(b,0xC,"Int"),y := NumGet(b,0x10,"Int")
            w := NumGet(b,0x14,"Int"),height := NumGet(b,0x18,"Int"),cb := NumGet(b,0x34,"UInt")
            if (type<1 || type>13 || Abs(x)>16384 || Abs(y)>16384 || w<0 || w>16384 || height<0 || height>16384)
                return {ok:false,reason:"CONTROL_LAYOUT_INVALID"}
            c := {ptr:ptr,type:type,x:x,y:y,w:w,h:height,callback:cb}
            controls.Push(c)
            if (modalPtrs.HasKey(ptr))
                ui.modal := true
            if (type=2 && w>=640 && height>=480 && x=0 && Abs(y-height)<=4)
                ui.width := Max(ui.width,w),ui.height := Max(ui.height,height)
            if (type=2 && cb=launch+0x187C0 && w>=640 && height>=480)
                ui.roles.splash := c
            if (type=1 && ptr=account)
                ui.roles.account := c
            if (type=1 && ptr=password)
                ui.roles.password := c
            if (type=6 && cb=launch+0x19980)
                ui.roles.network := c
            if (type=6 && cb=launch+0x1A180)
                ui.roles.login := c
            if (type=6 && cb=launch+0xDEC0)
                ui.roles.enter := c
            if (type=4 && w=200 && height=92 && x>=0 && y>height && y<600)
                if (!IsObject(ui.roles.character) || y<ui.roles.character.y
                    || (y=ui.roles.character.y && x<ui.roles.character.x))
                    ui.roles.character := c
            ptr := NumGet(b,0x3C,"UInt")
        }
        if (ptr || D2ReadU32(h,win+0x214A0)!=head)
            return {ok:false,reason:"CONTROL_LIST_CHANGING"}
        if (IsObject(ui.roles.login))
        {
            edits := []
            for _,c in controls
                if (c.type=1 && c.w>0 && c.h>0 && c.y<ui.roles.login.y
                    && c.x<=ui.roles.login.x+ui.roles.login.w/2
                    && c.x+c.w>=ui.roles.login.x+ui.roles.login.w/2)
                    edits.Push(c)
            if (edits.Length()=2 && Abs(edits[1].x-edits[2].x)<=4
                && Abs(edits[1].w-edits[2].w)<=4 && Abs(edits[1].y-edits[2].y)>edits[1].h)
            {
                topEdit := edits[1].y<edits[2].y ? edits[1] : edits[2]
                bottomEdit := edits[1].y<edits[2].y ? edits[2] : edits[1]
                ui.roles.account := topEdit,ui.roles.password := bottomEdit
            }
        }
        ui.login := IsObject(ui.roles.account) && IsObject(ui.roles.password) && IsObject(ui.roles.login)
        ui.character := IsObject(ui.roles.enter) && IsObject(ui.roles.character)
        ui.menu := IsObject(ui.roles.network) && !ui.login && !ui.character
        ui.splash := IsObject(ui.roles.splash) && !ui.login && !ui.menu && !ui.character && !ui.modal
        return ui
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

RecoveryMenuReadV528(r)
{
    ui := RecoveryMenuSnapshotV528(r)
    if (!ui.ok)
    {
        message := ui.reason="MENU_DLL_VERSION" ? "GĐ4: DLL menu khác phiên bản đã gửi; chưa nhận diện được."
            : "GĐ4: chờ đọc control menu (" . ui.reason . ")."
        GuiControl, 1:, RecoveryLoginStatusV489, %message%
        PortalLogWriteV66("STAGE4_MENU_READ method=DLL_CONTROLS reason=" . ui.reason,"MENU_DLL_READ",2000)
    }
    if (ui.ok)
    {
        if (!ui.controls.Length() || (!ui.login && !ui.menu && !ui.character && !ui.modal))
        {
            message := "GĐ4: " . r.loginStepV489 . " — đọc được " . ui.controls.Length() . " control, chưa nhận ra màn hình."
            GuiControl, 1:, RecoveryLoginStatusV489, %message%
        }
        if (ManualLogActiveV81())
        {
            shape := ""
            for index,c in ui.controls
            {
                if (index>40)
                    break
                shape .= (shape="" ? "" : ";") . c.type . ":" . c.x . "," . c.y . "," . c.w . "," . c.h
                    . ":cb=" . V92Hex(c.callback) . ":ptr=" . V92Hex(c.ptr)
            }
            PortalLogWriteV66("STAGE4_MENU_STATE build=DLL_CONTROLS_V531 step=" . r.loginStepV489
                . " count=" . ui.controls.Length() . " login=" . ui.login . " menu=" . ui.menu
                . " character=" . ui.character . " modal=" . ui.modal . " focus=" . V92Hex(ui.focus)
                . " win_base=" . V92Hex(ui.winBase) . " launch_base=" . V92Hex(ui.launchBase)
                . " head=" . V92Hex(ui.head) . " canvas=" . ui.width . "x" . ui.height
                . " controls=" . shape . " text_read=0 credentials_logged=0","STAGE4_MENU_STATE",1500)
        }
    }
    return ui
}

RecoveryLoginScreenV489(r,kind)
{
    ui := RecoveryMenuReadV528(r)
    if (!ui.ok)
        return false
    if (kind="CONNECTING")
        return ui.modal
    if (ui.modal)
        return false
    return kind="LOGIN" ? ui.login : kind="MENU" ? ui.menu : kind="CHAR" ? ui.character : false
}
RecoveryLobbyReadyV528(r)
{
    if (!IsObject(r) || !StageTwoWindowV166(r))
        return false
    multi := D2GetModuleBaseV35(r.pid,"D2Multi.dll")
    if (!multi)
        return false
    h := D2OpenProcess(r.pid)
    if (!h)
        return false
    try
    {
        if (!RecoveryMenuModuleV528(h,multi,0x4B95C235,0x3F000))
            return false
        ui := RecoveryMenuSnapshotV528(r)
        if (!ui.ok || ui.modal)
            return false
        for _,c in ui.controls
        {
            if (c.type=6 && c.callback=multi+0x15380)
                return true
            if (c.type=6 && c.callback=multi+0x142C0)
                return true
        }
        return false
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}
RecoveryMenuFocusV495(r)
{
    global stageTwoV166
    hwnd := StageTwoWindowV166(r)
    if (!hwnd || stageTwoV166!=r || !r.loginRecoveryV489
        || !DllCall("IsWindowEnabled","Ptr",hwnd) || DllCall("IsHungAppWindow","Ptr",hwnd))
        return false
    WinGet, minmaxV664, MinMax, ahk_id %hwnd%
    if (minmaxV664=-1)
    {
        DllCall("ShowWindowAsync","Ptr",hwnd,"Int",4)
        return false
    }
    return stageTwoV166=r
}

RecoveryMenuClickV495(r,x,y)
{
    if (!RecoveryMenuFocusV495(r))
        return false
    ui := RecoveryMenuReadV528(r)
    if (!ui.ok || ui.modal)
        return false
    step := r.loginStepV489
    role := step="WAIT_MENU" && ui.menu ? "network" : step="WAIT_MENU" && ui.splash ? "splash"
        : step="TYPE_ACCOUNT" && ui.login ? "account"
        : step="TYPE_PASSWORD" && ui.login ? "password" : step="SUBMIT_LOGIN" && ui.login ? "login"
        : step="WAIT_CHARACTER" && ui.character ? "character" : step="ENTER_LOBBY" && ui.character ? "enter" : ""
    c := role!="" ? ui.roles[role] : false
    if (!IsObject(c))
    {
        if (step="WAIT_MENU" && !ui.controls.Length())
            return StageTwoKeyV166(r,"Enter")
        return false
    }
    VarSetCapacity(rect,16,0)
    if (!DllCall("GetClientRect","Ptr",r.hwnd,"Ptr",&rect))
        return false
    w := NumGet(rect,8,"Int"),height := NumGet(rect,12,"Int")
    if (w<1 || height<1 || c.w<1 || c.h<1)
        return false
    cx := Round((c.x+c.w/2)*w/ui.width),cy := Round((c.y-c.h/2)*height/ui.height)
    if (cx<0 || cy<0 || cx>=w || cy>=height)
        return false
    lp := (cy<<16)|(cx & 65535)
    DllCall("PostMessage","Ptr",r.hwnd,"UInt",0x200,"UPtr",0,"Ptr",lp)
    if (!DllCall("PostMessage","Ptr",r.hwnd,"UInt",0x201,"UPtr",1,"Ptr",lp))
        return false
    Sleep, 40
    sent := DllCall("PostMessage","Ptr",r.hwnd,"UInt",0x202,"UPtr",0,"Ptr",lp)
    PortalLogWriteV66("STAGE4_MENU_CLICK step=" . step . " role=" . role
        . " method=DLL_CONTROL_RECT client_xy=" . cx . "," . cy . " queued=" . sent . " credentials_logged=0")
    if (sent && (role="account" || role="password"))
    {
        Sleep, 80
        check := RecoveryMenuReadV528(r)
        if (!check.ok || !check.login || check.modal || check.focus!=c.ptr)
        {
            PortalLogWriteV66("STAGE4_EDIT_FOCUS_WAIT role=" . role . " typed=0 credentials_logged=0","EDIT_FOCUS_WAIT",1000)
            return false
        }
    }
    return sent
}

RecoveryLoginTextV489(r,text,clearSaved := false)
{
    hwnd := StageTwoWindowV166(r)
    if (!hwnd)
        return false
    if (clearSaved)
    {
        ctrlLp := 1 | ((GetKeySC("Ctrl") & 255)<<16)
        if (!DllCall("PostMessage","Ptr",hwnd,"UInt",0x100,"UPtr",0x11,"Ptr",ctrlLp))
            return false
        selected := false
        try
        {
            Sleep, 40
            selected := StageTwoKeyV166(r,"a")
            selected := DllCall("PostMessage","Ptr",hwnd,"UInt",0x102,"UPtr",1,"Ptr",1) && selected
        }
        finally
            DllCall("PostMessage","Ptr",hwnd,"UInt",0x101,"UPtr",0x11,"Ptr",ctrlLp|0xC0000000)
        if (!selected || !StageTwoKeyV166(r,"Delete"))
            return false
        if (!StageTwoKeyV166(r,"End"))
            return false
        Loop, 64
            if (!DllCall("PostMessage","Ptr",hwnd,"UInt",0x102,"UPtr",8,"Ptr",1))
                return false
    }
    Loop, Parse, text
        if (!DllCall("PostMessage","Ptr",hwnd,"UInt",0x102,"UPtr",Asc(A_LoopField),"Ptr",1))
            return false
    if (clearSaved)
        PortalLogWriteV66("STAGE4_LOGIN_FIELD_REPLACED step=" . r.loginStepV489 . " clear=CTRL_A_DELETE credentials_logged=0")
    return true
}

RecoveryLoginTickV489(r)
{
    global stageTwoV166,recoveryGamePathV489,recoveryAccountV489,recoveryPasswordV489,backgroundPidV63,backgroundHwndV63
    if (stageTwoV166!=r)
        return
    if (SigResetProtectedV753())
    {
        r.until := A_TickCount+180000
        r.loginAtV489 := A_TickCount
        PortalLogWriteV66("STAGE4_SIG_DEFER next=WAIT_SIG_AND_PICKUP","STAGE4_SIG_DEFER",2000)
        return
    }
    if (A_TickCount >= r.until)
    {
        r.until := A_TickCount+180000
        RecoveryLoginStepV489(r,"CLOSE")
        GuiControl, 1:, RecoveryLoginStatusV489, GĐ4: Quá 3 phút, thử phục hồi lại; giữ farm.
        PortalLogWriteV66("STAGE4_TIMEOUT_RETRY farm=KEPT next=REOPEN_GAME credentials_logged=0")
        return
    }
    step := r.loginStepV489,elapsed := A_TickCount-r.loginAtV489
    PortalLogWriteV66("STAGE4_LOGIN_WAIT build=DLL_CONTROLS_V531 step=" . step . " elapsed_ms=" . elapsed
        . " pid=" . r.pid . " hwnd=" . V92Hex(r.hwnd) . " credentials_logged=0","STAGE4_LOGIN_WAIT_STEP",1500)
    if (step="CLOSE")
    {
        ; Capture the LAST position just before closing (supports user moving window).
        RecoveryWindowPositionCaptureV1503(r)
        ; BƯỚC 1 GĐ4: KILL GAME; không kèm bước dừng Farm phía trước.
        if (!RecoveryKillOldGameV1555(r))
            return
        r.oldWindowsV489 := {}
        WinGet, windowsV489, List
        Loop, %windowsV489%
            r.oldWindowsV489[windowsV489%A_Index%] := true
        ; Sau khi kill, khôi phục trạng thái cho lần mở game mới.
        RecoveryAfterKillResetV1555(r)
        RecoveryLoginStepV489(r,"LAUNCH")
        return
    }
    if (step="LAUNCH")
    {
        launchExeV735 := RecoveryGameExecutableV735(recoveryGamePathV489,launchCommandV735,launchDirV489)
        if (!launchExeV735 || !FileExist(launchExeV735))
        {
            GuiControl, 1:, RecoveryLoginStatusV489, Không tìm thấy file mở game trong dòng lệnh; sửa lại Game.
            return
        }
        if (!RegExMatch(launchCommandV735,"i)(?:^|\s)-w(?:\s|$)"))
            launchCommandV735 .= " -w"
        Run, %launchCommandV735%, %launchDirV489%, UseErrorLevel, launchedPidV489
        if (ErrorLevel)
        {
            GuiControl, 1:, RecoveryLoginStatusV489, Không mở được đường dẫn game; sửa lại Game.
            return
        }
        r.launchedPidV489 := launchedPidV489
        RecoveryLoginStepV489(r,"WAIT_WINDOW")
        return
    }
    if (step="WAIT_WINDOW")
    {
        WinGet, windowsV489, List
        Loop, %windowsV489%
        {
            hwnd := windowsV489%A_Index%
            if (r.oldWindowsV489.HasKey(hwnd))
                continue
            WinGet, pidV489, PID, ahk_id %hwnd%
            WinGet, exeV489, ProcessName, ahk_id %hwnd%
            if (!(exeV489="Game.exe" || exeV489="Diablo II.exe" || exeV489="D2.exe"))
                continue
            if (SigBackgroundBindV179(pidV489))
            {
                hwnd := backgroundHwndV63
                if (r.oldWindowsV489.HasKey(hwnd))
                    continue
                r.hwnd := hwnd,r.pid := pidV489,r.birth := BackgroundBirthV63(pidV489)
                VarSetCapacity(rectV496,16,0)
                DllCall("GetClientRect","Ptr",hwnd,"Ptr",&rectV496)
                WinGetClass, clsV496, ahk_id %hwnd%
                PortalLogWriteV66("STAGE4_WINDOW_BOUND method=SAME_STAGE3_SELECTOR hwnd=" . V92Hex(hwnd)
                    . " class=" . clsV496 . " client_size=" . NumGet(rectV496,8,"Int") . "x" . NumGet(rectV496,12,"Int"))
                r.menuViewportV495 := false
                RecoveryWindowPositionRestoreV1503(r,"WINDOW_READY")
                RecoveryLoginStepV489(r,"WAIT_MENU")
                return
            }
        }
        if (elapsed>60000)
        {
            GuiControl, 1:, RecoveryLoginStatusV489, Chờ cửa sổ game quá lâu; thử mở lại.
            RecoveryLoginStepV489(r,"CLOSE")
        }
        return
    }
    if (!StageTwoWindowV166(r))
    {
        RecoveryLoginStepV489(r,"CLOSE")
        return
    }
    if (!r.windowBindAppliedV1503)
        RecoveryWindowPositionRestoreV1503(r,"WINDOW_READY")
    if (step="WAIT_MENU")
    {
        if (RecoveryLoginScreenV489(r,"LOGIN"))
            RecoveryLoginStepV489(r,"TYPE_ACCOUNT")
        else if (RecoveryLoginScreenV489(r,"MENU"))
        {
            if (RecoveryMenuClickV495(r,512,584))
                RecoveryLoginStepV489(r,"WAIT_LOGIN")
        }
        else if (elapsed>=3000 && (!r.dismissAtV489 || A_TickCount-r.dismissAtV489>=2000))
        {
            RecoveryMenuClickV495(r,512,384)
            r.dismissAtV489 := A_TickCount
        }
    }
    else if (step="WAIT_LOGIN")
    {
        if (RecoveryLoginScreenV489(r,"LOGIN"))
            RecoveryLoginStepV489(r,"TYPE_ACCOUNT")
        else if (elapsed>=1500 && RecoveryLoginScreenV489(r,"MENU"))
        {
            PortalLogWriteV66("STAGE4_MENU_RETRY reason=MENU_STILL_VISIBLE next=CLICK_VERIFIED_NETWORK_CONTROL")
            RecoveryLoginStepV489(r,"WAIT_MENU")
        }
    }
    else if (step="TYPE_ACCOUNT")
    {
        if (recoveryAccountV489="" || recoveryPasswordV489="")
        {
            GuiControl, 1:, RecoveryLoginStatusV489, Game đã mở: nhập ID / Pass để đăng nhập.
            PortalLogWriteV66("STAGE4_LOGIN_WAIT reason=ACCOUNT_OR_PASSWORD_MISSING credentials_logged=0","STAGE4_LOGIN_WAIT",2000)
            r.loginAtV489 := A_TickCount
            return
        }
        if (RecoveryMenuClickV495(r,510,547) && RecoveryLoginTextV489(r,recoveryAccountV489,true))
            RecoveryLoginStepV489(r,"TYPE_PASSWORD")
    }
    else if (step="TYPE_PASSWORD" && elapsed>=250)
    {
        if (RecoveryMenuClickV495(r,510,595) && RecoveryLoginTextV489(r,recoveryPasswordV489,true))
            RecoveryLoginStepV489(r,"SUBMIT_LOGIN")
    }
    else if (step="SUBMIT_LOGIN" && elapsed>=250)
    {
        if (RecoveryMenuClickV495(r,512,636))
            RecoveryLoginStepV489(r,"WAIT_CHARACTER")
    }
    else if (step="WAIT_CHARACTER" && elapsed>=2000 && RecoveryLoginScreenV489(r,"CHAR"))
    {
        if (RecoveryMenuClickV495(r,170,132))
            RecoveryLoginStepV489(r,"ENTER_LOBBY")
    }
        else if (step="ENTER_LOBBY" && elapsed>=500)
    {
        if (RecoveryMenuClickV495(r,530,573))
            RecoveryLoginStepV489(r,"WAIT_LOBBY")
    }
        else if (step="ENTER_LOBBY" && elapsed>=500)
    {
        if (RecoveryMenuClickV495(r,530,573))
        {
            r.lastEnterClickV494 := A_TickCount
            RecoveryLoginStepV489(r,"WAIT_LOBBY")
        }
    }
    else if (step="WAIT_LOBBY")
    {
        if (RecoveryLoginScreenV489(r,"CONNECTING"))
        {
            r.lobbyReadyAtV494 := 0
            PortalLogWriteV66("STAGE4_WAIT_LOBBY reason=CONNECTING login_again=0","STAGE4_WAIT_LOBBY",2000)
        }
        else if (RecoveryLoginScreenV489(r,"CHAR"))
        {
            r.lobbyReadyAtV494 := 0
            if (!r.lastEnterClickV494 || A_TickCount-r.lastEnterClickV494>=2000)
            {
                if (RecoveryMenuClickV495(r,530,573))
                {
                    r.lastEnterClickV494 := A_TickCount
                    PortalLogWriteV66("STAGE4_WAIT_LOBBY reason=STILL_AT_CHAR_SELECT next=RE_ENTER","STAGE4_WAIT_LOBBY",1000)
                }
            }
        }
        else
        {
            lobbyUiV528 := RecoveryMenuReadV528(r)
            if (!lobbyUiV528.ok || !lobbyUiV528.controls.Length() || lobbyUiV528.login
                || lobbyUiV528.menu || lobbyUiV528.character || lobbyUiV528.modal)
            {
                r.lobbyReadyAtV494 := 0
                return
            }
            if (!RecoveryLobbyReadyV528(r))
            {
                r.lobbyReadyAtV494 := 0
                return
            }
            if (!r.lobbyReadyAtV494)
                r.lobbyReadyAtV494 := A_TickCount
            if (A_TickCount-r.lobbyReadyAtV494>=400)
            {
                r.loginRecoveryV489 := false,r.phase := "WAIT_LOBBY",r.at := A_TickCount-4000
                r.until := A_TickCount+120000,r.tries := 0,r.retryAtV237 := 0,r.altDoneV421 := false
                r.authenticatedV494 := true
                GuiControl, 1:, RecoveryLoginStatusV489, Đã đăng nhập; GĐ3 chỉ tạo phòng.
                PortalLogWriteV66("STAGE4_LOGIN_DONE next=STAGE3_WAIT_LOBBY_CREATE login_again=0 credentials_logged=0")
                return
            }
        }
    }
    if (elapsed>=90000)
    {
        PortalLogWriteV66("STAGE4_LOGIN_RETRY step=" . step . " next=REOPEN_GAME credentials_logged=0")
        RecoveryLoginStepV489(r,"CLOSE")
    }
}

StageTwoKeyLogTimerV164:
if (!manualLogOnV81)
{
    SetTimer, StageTwoKeyLogTimerV164, Off
    return
}
for stageKeyV164,_ in stageTwoKeysV164
{
    stageDownV164 := GetKeyState(stageKeyV164,"P")
    stageOldV164 := stageTwoKeysV164[stageKeyV164]
    stageTwoKeysV164[stageKeyV164] := stageDownV164
    if (!stageDownV164 || stageOldV164 || !IsGameForegroundV63())
        continue
    PortalLogWriteV66("MANUAL_KEY key=" . stageKeyV164)
    StageTwoImageV164(WinExist("A"),"KEY_" . stageKeyV164)
}
return

StageTwoImageV164(hwnd,reason)
{
    global manualLogOnV81,manualLogFolderV81,manualLogSessionV95
    static busy := false,number := 0,session := ""
    if (busy || !manualLogOnV81 || !hwnd || !WinActive("ahk_id " . hwnd))
        return
    busy := true,dc := 0,mem := 0,bmp := 0,old := 0
    try
    {
        if (session!=manualLogSessionV95)
            session := manualLogSessionV95,number := 0
        VarSetCapacity(rect,16,0)
        if (!DllCall("GetClientRect","Ptr",hwnd,"Ptr",&rect))
            return
        w := NumGet(rect,8,"Int"),hh := NumGet(rect,12,"Int")
        if (w<1 || hh<1 || w>4096 || hh>4096)
            return
        dc := DllCall("GetDC","Ptr",hwnd,"Ptr")
        mem := DllCall("gdi32\CreateCompatibleDC","Ptr",dc,"Ptr")
        VarSetCapacity(info,40,0)
        NumPut(40,info,0,"UInt"),NumPut(w,info,4,"Int"),NumPut(-hh,info,8,"Int")
        NumPut(1,info,12,"UShort"),NumPut(32,info,14,"UShort")
        bits := 0
        bmp := DllCall("gdi32\CreateDIBSection","Ptr",dc,"Ptr",&info,"UInt",0,"Ptr*",bits,"Ptr",0,"UInt",0,"Ptr")
        if (!mem || !bmp || !bits)
            return
        old := DllCall("gdi32\SelectObject","Ptr",mem,"Ptr",bmp,"Ptr")
        if (!DllCall("gdi32\BitBlt","Ptr",mem,"Int",0,"Int",0,"Int",w,"Int",hh,"Ptr",dc,"Int",0,"Int",0,"UInt",0x00CC0020))
            return
        size := w*hh*4
        VarSetCapacity(header,14,0)
        NumPut(0x4D42,header,0,"UShort"),NumPut(size+54,header,2,"UInt"),NumPut(54,header,10,"UInt")
        number++
        name := session . "-" . Format("{:04}",number) . "-Stage2-" . reason . ".bmp"
        file := FileOpen(manualLogFolderV81 . "\" . name,"w")
        if (!IsObject(file))
            return
        wrote := 0
        okHeader := DllCall("WriteFile","Ptr",file.__Handle,"Ptr",&header,"UInt",14,"UInt*",wrote,"Ptr",0) && wrote=14
        okInfo := DllCall("WriteFile","Ptr",file.__Handle,"Ptr",&info,"UInt",40,"UInt*",wrote,"Ptr",0) && wrote=40
        okPixels := DllCall("WriteFile","Ptr",file.__Handle,"Ptr",bits,"UInt",size,"UInt*",wrote,"Ptr",0) && wrote=size
        file.Close()
        if (!okHeader || !okInfo || !okPixels)
        {
            FileDelete, % manualLogFolderV81 . "\" . name
            PortalLogWriteV66("STAGE2_SCREEN_ERROR reason=WRITE_FAILED file=" . name)
            return
        }
        PortalLogWriteV66("STAGE2_SCREEN file=" . name . " client_size=" . w . "x" . hh . " reason=" . reason)
    }
    catch e
    {
        if (IsObject(file))
            file.Close()
        PortalLogWriteV66("STAGE2_SCREEN_ERROR reason=" . e.Message)
    }
    finally
    {
        if (old)
            DllCall("gdi32\SelectObject","Ptr",mem,"Ptr",old)
        if (bmp)
            DllCall("gdi32\DeleteObject","Ptr",bmp)
        if (mem)
            DllCall("gdi32\DeleteDC","Ptr",mem)
        if (dc)
            DllCall("ReleaseDC","Ptr",hwnd,"Ptr",dc)
        busy := false
    }
}

EntryMouseLogTimerV160:
if (!manualLogOnV81)
{
    SetTimer, EntryMouseLogTimerV160, Off
    return
}
for entryButtonV160,_ in entryMouseStateV160
{
    entryDownV160 := GetKeyState(entryButtonV160,"P")
    entryWasDownV160 := entryMouseStateV160[entryButtonV160]
    entryMouseStateV160[entryButtonV160] := entryDownV160
    if (!entryDownV160 || entryWasDownV160 || !IsGameForegroundV63())
        continue
    entryHwndV160 := WinExist("A")
    VarSetCapacity(entryPointV160,8,0)
    if (!DllCall("GetCursorPos","Ptr",&entryPointV160) || !DllCall("ScreenToClient","Ptr",entryHwndV160,"Ptr",&entryPointV160))
        continue
    PortalLogWriteV66("MANUAL_MOUSE_DOWN button=" . entryButtonV160 . " client_xy=" . NumGet(entryPointV160,0,"Int") . "," . NumGet(entryPointV160,4,"Int") . " hwnd=" . entryHwndV160 . " source=PHYSICAL_MOUSE")
    StageTwoImageV164(entryHwndV160,"CLICK_" . entryButtonV160)
    PortalLogSnapshotV66()
}
return

PortalLogTimerV66:
if (!ManualLogActiveV81())
{
    SetTimer, PortalLogTimerV66, Off
    return
}
if (!portalLogUntilV66 || A_TickCount>=portalLogUntilV66)
{
    SetTimer, PortalLogTimerV66, Off
    if (portalLogUntilV66)
        ManualLogAppendV81(A_Now . " | END reason=" . (portalLogAutoV73 ? "10_SECONDS_AFTER_LAST_PORTAL_CAST" : "120_SECONDS") . "`r`n", portalLogFileV66, "UTF-8")
    portalLogUntilV66 := 0
    return
}
PortalLogSnapshotV66()
return

PortalLogSnapshotV66()
{
    if (!ManualLogActiveV81())
        return false
    global autoMonsterAttackOn, farmReviveV32, townLevelV22, outsideLevelV22, portalLogLastLevelV66, xRunning, zRunning, gameItemActionOwner, portalCastKeyV50, portalLogAutoV73
    pid := CoordDisplayGamePidV1(), hwnd := pid ? WinExist("ahk_pid " . pid) : 0
    if (!pid || !hwnd)
    {
        PortalLogWriteV66("WAIT reason=NO_VALID_GAME_WINDOW foreground_game=" . IsGameForegroundV63(),"wait",2000)
        return
    }
    base := D2GetModuleBaseV35(pid,"D2Client.dll"), h := base ? D2OpenProcess(pid) : 0
    if (!h)
    {
        PortalLogWriteV66("WAIT reason=OPEN_PROCESS_FAILED pid=" . pid,"wait",2000)
        return
    }
    try
    {
        player := D2ReadU32(h,base+0x11BBFC), path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
        {
            PortalLogWriteV66("WAIT reason=PLAYER_PATH_NOT_READY pid=" . pid,"wait",2000)
            return
        }
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt")), mode := D2ReadU32(h,player+0x10)
        px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
        if (level && level!=portalLogLastLevelV66)
        {
            PortalLogWriteV66("MAP_CHANGE before=" . portalLogLastLevelV66 . " after=" . level . " is_town=" . (level=townLevelV22) . " is_outside=" . (level=outsideLevelV22))
            portalLogLastLevelV66 := level
        }
        r := farmReviveV32
        inv := D2ReadU32(h,player+0x60), cursor := inv ? PickupCursorV4(h,inv) : false
        room1 := NumGet(pb,0x1C,"UInt"), room2 := room1 ? D2ReadU32(h,room1+0x10) : 0
        levelPtr := room2 ? D2ReadU32(h,room2+0x58) : 0
        global scosEntryV162,cainPausedV10,farmControlOwnerV186
        if (IsObject(scosEntryV162))
            PortalLogWriteV66("ENTRY_SNAPSHOT map=" . scosEntryV162.map . " phase=" . scosEntryV162.phase
                . " bo_stage=" . scosEntryV162.boStageV413 . " owner=" . farmControlOwnerV186
                . " paused=" . (cainPausedV10 ? 1 : 0),"ENTRY_SNAPSHOT",1000)
        PortalLogWriteV66("PLAYER_PATH path=" . V92Hex(path) . " room1=" . V92Hex(room1) . " room2=" . V92Hex(room2)
            . " level_ptr=" . V92Hex(levelPtr) . " cursor_uid=" . (IsObject(cursor) ? cursor.uid : -1),"path_detail",500)
        PortalLogWriteV66("RUN_FLAGS always_run=" . D2ReadU32(h,base+0x11C3EC) . " run_held=" . D2ReadU32(h,base+0x11C3E8)
            . " player_mode=" . mode . " ctrl_physical=" . GetKeyState("Ctrl","P") . " xy=" . px . "," . py,"run_flags",250)
        PortalLogWriteV66("SNAPSHOT pid=" . pid . " hwnd=" . hwnd . " foreground_game=" . IsGameForegroundV63() . " farm=" . autoMonsterAttackOn
            . " mode=" . mode . " level=" . level . " town_config=" . townLevelV22 . " outside_config=" . outsideLevelV22 . " xy=" . px . "," . py
            . " revival=" . IsObject(r) . " step=" . (IsObject(r) ? r.step : -1) . " origin=" . (IsObject(r) && IsObject(r.origin) ? r.origin.x . "," . r.origin.y : "NONE")
            . " seen_count=" . (IsObject(r) && IsObject(r.seen) ? r.seen.Count() : 0) . " x_running=" . xRunning . " z_running=" . zRunning . " item_owner=" . gameItemActionOwner . " portal_key=" . portalCastKeyV50,"snapshot",portalLogAutoV73 ? 250 : 1000)
        seen := {}, count := 0, objects := 0, output := ""
        for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
        {
            u := D2ReadU32(h,room+0x74)
            Loop, 256
            {
                if (!u || seen.HasKey(u) || count>=1024)
                    break
                seen[u] := true, count++
                if (!MonsterBossProbeReadV1(h,u,0xEC,ub))
                    break
                next := NumGet(ub,0xE8,"UInt")
                if (NumGet(ub,0,"UInt")=2)
                {
                    cls := NumGet(ub,4,"UInt"), uid := NumGet(ub,0x0C,"UInt"), op := NumGet(ub,0x2C,"UInt")
                    if (MonsterBossProbeReadV1(h,op,0x18,ob))
                    {
                        ox := NumGet(ob,0x0C,"UInt"), oy := NumGet(ob,0x10,"UInt")
                        dist := (ox-px)*(ox-px)+(oy-py)*(oy-py)
                        if (dist<=1600 && objects<24)
                        {
                            objects++
                            output .= " uid=" . uid . ":class=" . cls . ":mode=" . NumGet(ub,0x10,"UInt") . ":xy=" . ox . "," . oy . ":distance=" . Round(Sqrt(dist),2)
                                . ":portal_class=" . (cls=59 || cls=60) . ":already_tried=" . (IsObject(r) && IsObject(r.seen) ? r.seen.HasKey(uid) : false)
                        }
                    }
                }
                u := next
            }
        }
        PortalLogWriteV66("NEAR_OBJECTS count=" . objects . " scanned=" . count . output,"objects",2000)
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}


RoomInsertToggleV125:
if (!CoordCaptureV14(true))
{
    ToolTipInfoV386("Chưa đọc được tọa độ nhân vật để cập nhật dòng vàng.")
    SetTimer, RemoveToolTip, -2500
}
return

RoomInsertStopV125()
{
    global roomRecordV108,currentProfile
    r := roomRecordV108
    if (!IsObject(r) || !r.insertMode)
        return false
    SetTimer, RoomRecordTimerV108, Off
    if (!RoomInsertCommitV125(r))
    {
        ToolTipInfoV386("Chưa lưu được đoạn chèn. Đoạn ghi vẫn được giữ; bấm DỪNG CHÈN để thử lại.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    inserted := r.segment.Length(),roomRecordV108 := false
    GuiControl,, RoomInsertButtonV125, UPDATE
    GuiControl,, RoomTestButtonV89, Tạo
    GuiControl,, RoomContinueButtonV58, Sửa
    GuiControl, Enable, CoordDeleteButtonV125
    RouteMapRefreshV21(false)
    CoordSavedLoadV15(currentProfile)
    CoordBoxRefreshV15(true)
    ToolTipInfoV386("Đã chèn " . inserted . " phòng sau dòng " . r.afterRow . "; giữ nguyên phần phía sau.")
    SetTimer, RemoveToolTip, -3000
    return true
}

RoomInsertCommitV125(r)
{
    if (!r.segment.Length())
        return true
    data := RoomMapReadV109(r.file)
    if (!IsObject(data) || data.level!=r.level || data.points.Length()!=r.original.Length()
        || r.original.Length()+r.segment.Length()>10000)
        return false
    for i,point in r.original
    {
        live := data.points[i]
        if (live.x!=point.x || live.y!=point.y || live.roomNumber!=point.roomNumber)
            return false
    }
    merged := []
    for i,point in r.original
    {
        merged.Push(point)
        if (i=r.afterRow)
            for _,newPoint in r.segment
                merged.Push(newPoint)
    }
    temp := r.file . ".insert.tmp"
    FileCopy, % r.file, %temp%, 1
    if (ErrorLevel)
        return false
    section := "Route-" . r.level,sequence := ""
    for i,point in merged
    {
        key := "Room" . i,value := point.roomNumber . "|" . point.x . "," . point.y
        IniWrite, %value%, %temp%, %section%, %key%
        if (ErrorLevel)
            return false
        sequence .= (sequence="" ? "" : "-") . point.roomNumber
    }
    count := merged.Length()
    IniWrite, %sequence%, %temp%, %section%, Sequence
    if (ErrorLevel)
        return false
    IniWrite, %count%, %temp%, %section%, Count
    if (ErrorLevel)
        return false
    check := RoomMapReadV109(temp)
    if (!IsObject(check) || check.level!=r.level || check.points.Length()!=count)
        return false
    for i,point in merged
        if (check.points[i].x!=point.x || check.points[i].y!=point.y || check.points[i].roomNumber!=point.roomNumber)
            return false
    FileMove, %temp%, % r.file, 1
    return !ErrorLevel
}

RoomRecordFinishV21(r)
{
    global roomRecordV108,roomRecordFinishingV21,currentProfile
    if (!IsObject(r) || roomRecordFinishingV21)
        return false
    priorCriticalV21 := A_IsCritical
    Critical, On
    roomRecordFinishingV21 := true
    startedV21 := A_TickCount
    Hotkey, ~*LButton, RoomRecordClickV358, Off
    SetTimer, RoomRecordTimerV108, Off
    try
    {
        verifiedV399 := RoomMapReadV109(r.file,false,r.level)
        if (!IsObject(verifiedV399) || !verifiedV399.points.Length())
        {
            ToolTipInfoV386("Chưa lưu được lộ trình: file không có tọa độ hợp lệ. Giữ phiên ghi và bản sao cũ; bấm Dừng lại sau khi ghi điểm.")
            SetTimer, RemoveToolTip, -4000
            Hotkey, ~*LButton, RoomRecordClickV358, On
            SetTimer, RoomRecordTimerV108, 100
            return false
        }
        if (!RoomRecordMetadataFinishV413(r))
        {
            ToolTipInfoV386("Chưa lưu hoàn tất: tọa độ và dữ liệu phòng không cùng map. Giữ file đang ghi và bản sao cũ.")
            SetTimer, RemoveToolTip, -4000
            Hotkey, ~*LButton, RoomRecordClickV358, On
            SetTimer, RoomRecordTimerV108, 100
            return false
        }
        verifiedV399 := RoomMapReadV109(r.file,false,r.level)
        if (!RoomRecordNameFinalizeV54(r))
        {
            Hotkey, ~*LButton, RoomRecordClickV358, On
            SetTimer, RoomRecordTimerV108, 100
            return false
        }
        if (r.backupFileV276!="")
        {
            backupV21 := r.backupFileV276
            FileDelete, %backupV21%
        }
        roomRecordV108 := false
        GuiControl,, RoomTestButtonV89, Tạo
        GuiControl,, RoomContinueButtonV58, Sửa
        RoomRecordedPublishV399(r,verifiedV399)
        RouteMapRefreshV21(false)
        CoordBoxRefreshV15(true)
        PortalLogWriteV66("ROOM_RECORD_FINISH file=" . r.file . " points=" . (r.addedV141+0)
            . " elapsed_ms=" . (A_TickCount-startedV21) . " refresh=SELECTED_FILE_ONLY")
        if (r.fonEditHeldV414)
        {
            r.fonEditHeldV414 := false
            FonEditEndV414()
        }
        ToolTipInfoV386("Đã lưu " . verifiedV399.points.Length() . " tọa độ — map " . r.level . ". File: " . r.file)
        SetTimer, RemoveToolTip, -3000
        return true
    }
    finally
    {
        roomRecordFinishingV21 := false
        Critical, %priorCriticalV21%
    }
}

RoomRecordNameFinalizeV54(r)
{
    global mapTestModeV656
    global ConfigFile,routeMapsV21
    if (!IsObject(r) || !r.freshStartedV195 || !r.level || !r.addedV141)
        return true
    if (r.continueV58)
        return true
    oldFile := r.file
    SplitPath, oldFile,,,, currentName
    IniRead, savedOwnerV412, %oldFile%, Map, AutoButton, %A_Space%
    if (Trim(savedOwnerV412)="")
    {
        if (RegExMatch(currentName,"i)^(BO|CAIN|SCOS|FAUT|NAO|CYC|UBU|TRAN|LIB|130|133|136|139|3000|M3000|WEA|VIZ|THANH)(?:-|$)",savedNameV412))
            savedOwnerV412 := savedNameV4121
        else
            savedOwnerV412 := RoomMapButtonNameV22(r.level)
    }
    SplitPath, oldFile,,directory
    FileCreateDir, %directory%
    if (!InStr(FileExist(directory),"D"))
    {
        ToolTipInfoV386("Không tạo được thư mục map. File đang ghi vẫn được giữ.")
        return false
    }
    IniRead, baseName, %oldFile%, Map, RecordBaseName, %currentName%
    IniRead, recordNumberV294, %oldFile%, Map, RecordNumber, 0
    if (baseName="LIB" && !recordNumberV294 && RegExMatch(currentName,"i)^LIB-(\d+)$",numberV294))
        recordNumberV294 := numberV2941+0
    IniRead, autoNameV22, %oldFile%, Map, AutoName, 0
    if (autoNameV22=1)
    {
        IniRead, autoButtonV22, %oldFile%, Map, AutoButton, MAP
        IniRead, autoLevelV22, %oldFile%, Map, AutoLevel, 0
        baseName := autoButtonV22 . "-Map" . r.level
        if (autoLevelV22=r.level && recordNumberV294>0)
            newName := baseName . "-" . recordNumberV294
        else
            newName := RoomMapNamedNumberV293(baseName)
    }
    else
        newName := baseName="LIB" && recordNumberV294>0 ? baseName . "-Map" . r.level . "-" . recordNumberV294 : baseName . "-Map" . r.level
    ; V850: TẠO already allocated the map's final name and stored its HASH
    ; alongside that exact INI. Never rename only the route on DỪNG.
    ; This applies solely to maps with a collision-HASH sidecar.
    if ((r.level=39 || r.level=183 || r.level=184)
        && FileExist(oldFile . ".hash.ini"))
        newName := currentName
    newFile := directory . "\" . newName . ".ini"
    if (newFile!=oldFile)
    {
        newName := RoomMapUniqueNameV261(newName,directory,oldFile)
        newFile := directory . "\" . newName . ".ini"
        ; V850: protect any sidecar in case another renaming path runs.
        oldSidecarV850 := oldFile . ".hash.ini"
        newSidecarV850 := newFile . ".hash.ini"
        if (FileExist(oldSidecarV850) && FileExist(newSidecarV850))
        {
            ToolTipInfoV386("Tên file HASH đích đã có; giữ tên INI cũ để tránh mất liên kết.")
            return false
        }
        FileMove, %oldFile%, %newFile%, 0
        if (ErrorLevel)
        {
            ToolTipInfoV386("Không đổi được tên file map. Kiểm tra quyền ghi rồi bấm DỪNG lại.")
            SetTimer, RemoveToolTip, -4000
            return false
        }
        sidecarMovedV850 := false
        if (FileExist(oldSidecarV850))
        {
            FileMove, %oldSidecarV850%, %newSidecarV850%, 0
            if (ErrorLevel)
            {
                FileMove, %newFile%, %oldFile%, 0
                ToolTipInfoV386("Không đổi được tên HASH đi cùng INI. Giữ lại file gốc.")
                return false
            }
            sidecarMovedV850 := true
        }
        section := RouteMapSectionForV656(r.profile,r.mapChoice,MapFileIsTestV656(oldFile))
        IniWrite, %newFile%, % ProfileConfigPathV364(section), %section%, RoomMapFile
        if (ErrorLevel)
        {
            if (sidecarMovedV850)
                FileMove, %newSidecarV850%, %oldSidecarV850%, 0
            FileMove, %newFile%, %oldFile%, 0
            ToolTipInfoV386("Không cập nhật được liên kết file map. Bấm DỪNG lại sau khi kiểm tra config.ini.")
            SetTimer, RemoveToolTip, -4000
            return false
        }
        r.file := newFile
    }
    IniWrite, %baseName%, %newFile%, Map, RecordBaseName
    if (autoNameV22=1)
    {
        IniWrite, % r.level, %newFile%, Map, AutoLevel
        if (RegExMatch(newName,"-(\d+)$",autoNumberV22))
            IniWrite, %autoNumberV221%, %newFile%, Map, RecordNumber
    }
    IniWrite, % r.level, %newFile%, Map, RecordedLevel
    IniWrite, %newName%, %newFile%, Map, Name
    if (MapFileIsTestV656(newFile)=mapTestModeV656)
        for _,map in routeMapsV21
            if (map.id=r.mapChoice)
                map.name := newName
    return true
}

RoomContinueToggleV58:
if (IsObject(roomRecordV108))
{
    Gosub, RoomTestToggleV89
    return
}
RoomContinueStartV58()
return

RoomContinueStartV58()
{
    global roomRecordV108
    FonEditBeginV414()
    try
        return RoomContinueCoreV414()
    finally
    {
        if (IsObject(roomRecordV108))
            roomRecordV108.fonEditHeldV414 := true
        else
            FonEditEndV414()
    }
}

RoomContinueCoreV414()
{
    global
    if (!RoomRecordSelectLiveV400())
        return false
    row := coordManualRowV59>=1 ? coordManualRowV59 : CoordYellowIndexV48()
    file := RoomProfileFileV108()
    data := RoomMapReadV109(file)
    if (!IsObject(data) || row<1 || row>data.points.Length())
    {
        ToolTipInfoV386("Chọn một dòng tọa độ hoặc dòng vàng trước khi bấm LƯU TIẾP.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    if (!RoomRecordPrepareV258())
        return false
    if (RoomRecordLevelV259(roomRecordPidV259)!=data.level)
    {
        ToolTipInfoV386("Nhân vật phải ở đúng map của lộ trình để lưu tiếp.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    totalRowsV387 := data.points.Length()
    tailRowsV387 := totalRowsV387 - row
    if (tailRowsV387 > 0)
    {
        MsgBox, 36, Sửa lộ trình, File map hiện có %totalRowsV387% điểm.`n`nDòng vàng đang chọn: %row%.`nToàn bộ %tailRowsV387% điểm SAU dòng này sẽ bị XÓA khi bắt đầu ghi lại.`n`nCác điểm từ dòng 1 đến dòng %row% vẫn được giữ.`n`nTiếp tục SỬA LỘ TRÌNH?
        IfMsgBox, No
            return false
    }
    continueSnapshotV413 := RoomRecordSnapshotV413(roomRecordPidV259,data.level)
    continueGeometryV275 := IsObject(continueSnapshotV413) ? continueSnapshotV413.geometry : false
    if (!IsObject(continueGeometryV275))
    {
        ToolTipInfoV386("Chưa đọc được toàn bộ phòng của map; chưa sửa lộ trình.")
        SetTimer, RemoveToolTip, -3500
        return false
    }
    Critical, On
    try
    {
        keep := []
        Loop, %row%
            keep.Push(data.points[A_Index].Clone())
        temp := file . ".continue.tmp"
        backup := file . ".before-continue-" . A_Now . "-" . A_TickCount . ".bak"
        FileCopy, %file%, %backup%, 0
        if (ErrorLevel)
            return RoomContinueErrorV58()
        FileCopy, %file%, %temp%, 1
        if (ErrorLevel)
            return RoomContinueErrorV58()
        section := "Route-" . data.level
        IniRead, raw, %temp%, %section%
        Loop, Parse, raw, `n, `r
        {
            if (RegExMatch(A_LoopField,"^Room(\d+)=",m) && m1+0>row)
            {
                key := "Room" . m1
                IniDelete, %temp%, %section%, %key%
                if (ErrorLevel)
                    return RoomContinueErrorV58()
            }
        }
        if (!RoomRecordRoomsWriteV413(temp,data.level,keep,continueGeometryV275)
            || !RoomMapPointsWriteV126(temp,data.level,keep)
            || !MapRoomLayoutSaveV270(temp,continueGeometryV275)
            || !RoomRecordGatesWriteV413(temp,data.level,continueSnapshotV413.gates)
            || !RoomRecordSnapshotStillLiveV413(continueSnapshotV413))
            return RoomContinueErrorV58()
        FileMove, %temp%, %file%, 1
        if (ErrorLevel)
            return RoomContinueErrorV58()
        coordSavedV15 := keep
        coordManualRowV59 := row,coordPinnedYellowV136 := row,coordLiveYellowV128 := row
        coordPointLevelV14 := data.level
        anchor := keep[row]
        roomRecordV108 := {recordOnly:true,continueV58:true,pid:roomRecordPidV259,file:file,profile:currentProfile
            ,mapChoice:routeMapIdV21,level:data.level,lastNumber:anchor.roomNumber
            ,freshStartedV195:true,appendStartedV141:true,addedV141:0,geometrySavedV270:true,geometryV275:continueGeometryV275,backupFileV276:backup,snapshotV413:continueSnapshotV413
            ,lastPointV358:{x:anchor.x,y:anchor.y,level:data.level}}
        CoordBoxRefreshV15(true)
        SetTimer, RoomRecordTimerV108, 100
        Hotkey, ~*LButton, RoomRecordClickV358, On
        GuiControl,, RoomTestButtonV89, Dừng
        GuiControl,, RoomContinueButtonV58, Dừng
        ToolTipInfoV386("LƯU TIẾP sau dòng " . (row+1) . ": đã xóa tọa độ phía sau; giữ nguyên các dòng trước.")
        SetTimer, RemoveToolTip, -3000
        return true
    }
    finally
        Critical, Off
}

RoomContinueErrorV58()
{
    ToolTipInfoV386("Không ghi được lộ trình lưu tiếp. File gốc được giữ; kiểm tra quyền ghi.")
    SetTimer, RemoveToolTip, -4000
    return false
}

RoomTestToggleV89:
if (IsObject(roomRecordV108) && roomRecordV108.insertMode)
{
    RoomInsertStopV125()
    return
}
if (!IsObject(roomRecordV108) && IsObject(routeRecordV358))
{
    ToolTipInfoV386("Đang Ghi Map — dừng lại trước khi Tạo/Sửa Map.")
    SetTimer, RemoveToolTip, -3000
    return
}
if (IsObject(roomRecordV108))
{
    RoomRecordFinishV21(roomRecordV108)
    return
}
FonEditBeginV414()
try
{
if (!RoomRecordNewTargetV424())
    return
roomRecordFileV117 := RoomProfileFileV108()
if (!routeMapIdV21 || !FileExist(roomRecordFileV117))
{
    MsgBox, 48, Lưu phòng, Chọn map đã có file tọa độ. Dùng THÊM MAP để tạo map và file cùng tên trước.
    return
}
    dataCheckV386 := RoomMapReadV109(roomRecordFileV117)
    if (IsObject(dataCheckV386) && dataCheckV386.points.Length())
    {
        ToolTipInfoV386("Đã chọn INI có tọa độ; hiện đường cũ. Không ghi đè; dùng Sửa để ghi tiếp.")
        SetTimer, RemoveToolTip, -3500
        return
    }
if (!RoomRecordPrepareV258())
    return
recordLevelV275 := RoomRecordLevelV259(roomRecordPidV259)
recordGeometryV275 := false
CoordSavedLoadV15(currentProfile)
RoomExploreEndV89("RECORD_START")
roomRecordV108 := {recordOnly:true,pid:roomRecordPidV259,file:roomRecordFileV117,profile:currentProfile
    ,mapChoice:routeMapIdV21,lastNumber:-1,level:recordLevelV275,geometryV275:recordGeometryV275}
if (!RoomRecordFreshStartV195(roomRecordV108,recordLevelV275))
{
    roomRecordV108 := false
    ToolTipInfoV386("Không lưu được dữ liệu toàn map; chưa bắt đầu ghi lộ trình.")
    SetTimer, RemoveToolTip, -3500
    return
}
SetTimer, RoomRecordTimerV108, 100
Hotkey, ~*LButton, RoomRecordClickV358, On
GuiControl,, RoomTestButtonV89, Dừng
GuiControl,, RoomContinueButtonV58, Sửa Map
ToolTipInfoV386("Đã bắt đầu ghi map " . recordLevelV275 . " - F-OFF trong lúc ghi; bấm DỪNG để lưu.")
SetTimer, RemoveToolTip, -3000
return
}
finally
{
    if (IsObject(roomRecordV108))
        roomRecordV108.fonEditHeldV414 := true
    else
        FonEditEndV414()
}
RouteRecordDistanceChangedV649:
GuiControlGet, routeRecordDistanceEditV649, 1:, RouteRecordDistanceInputV649
if (RegExMatch(routeRecordDistanceEditV649,"^\d+$"))
    routeRecordDistanceV649 := Min(9999,routeRecordDistanceEditV649+0)
return

RoomRecordClickV358:
if (!IsObject(roomRecordV108))
    return
RoomRecordCaptureClickV358(roomRecordV108)
return

RoomRecordCaptureClickV358(r)
{
    global routeRecordDistanceV649
    if (!IsObject(r))
        return
    base := D2GetModuleBaseV35(r.pid,"D2Client.dll")
    h := base ? D2OpenProcess(r.pid) : 0
    if (!h)
        return
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return
        room1 := NumGet(pb,0x1C,"UInt")
        level := CoordLevelV14(h,room1)
        if (!level)
            return
        if (r.freshStartedV195 && r.level && r.level!=level)
        {
            ToolTipInfoV386("Đã qua map khác: bấm Dừng để lưu map vừa ghi, rồi tạo lộ trình mới.")
            SetTimer, RemoveToolTip, -2500
            return
        }
        r.level := level
        minDistanceV649 := Max(0,routeRecordDistanceV649+0)
        pxV358 := NumGet(pb,2,"UShort"), pyV358 := NumGet(pb,6,"UShort")
        if (IsObject(r.lastPointV358) && r.lastPointV358.level=level)
        {
            dxV358 := pxV358 - r.lastPointV358.x
            dyV358 := pyV358 - r.lastPointV358.y
            if (dxV358*dxV358 + dyV358*dyV358 < minDistanceV649*minDistanceV649)
            {
                PortalLogWriteV66("ROOM_RECORD_SKIP_CLOSE row=" . (r.addedV141+0)
                    . " xy=" . pxV358 . "," . pyV358
                    . " last=" . r.lastPointV358.x . "," . r.lastPointV358.y
                    . " dist2=" . (dxV358*dxV358 + dyV358*dyV358) . " min=" . minDistanceV649)
                return
            }
        }
        node := RoomExploreReadV89(h,D2ReadU32(h,room1+0x10),level,true)
        if (!IsObject(node))
            return
        if (!FileExist(r.file))
        {
            RoomRecordStopV358()
            ToolTipInfoV386("File map đã mất. Dừng lưu; không tạo file thay thế.")
            SetTimer, RemoveToolTip, -3000
            return
        }
        if (!r.freshStartedV195)
        {
            if (!RoomRecordFreshStartV195(r,level))
            {
                RoomRecordStopV358()
                ToolTipInfoV386("Không tạo được lộ trình mới. Dừng lưu; kiểm tra file map và quyền ghi.")
                SetTimer, RemoveToolTip, -5000
                return
            }
        }
        if (!RoomRecordSameMapV413(r))
        {
            ToolTipInfoV386("Map đã đổi phiên dù cùng ID. Bấm Dừng để lưu phần đã ghi; tạo lộ trình mới cho map hiện tại.")
            SetTimer, RemoveToolTip, -3500
            return
        }
        if (IsObject(r.snapshotV413.geometry) && !RoomRecordRectV413(r.snapshotV413.geometry,pxV358,pyV358))
        {
            ToolTipInfoV386("Tọa độ vừa đọc không thuộc dữ liệu phòng của phiên ghi. Chưa thêm điểm này.")
            SetTimer, RemoveToolTip, -3500
            return
        }
        node.routeNumber := RoomRouteNumberV105(node,r.file)
        if (node.routeNumber<0)
            return
        if (RoomRecordAppendV141(r,node,pxV358,pyV358))
        {
            r.lastNumber := node.routeNumber
            r.lastPointV358 := {x:pxV358, y:pyV358, level:level}
            GuiControl,, RoomTestButtonV89, % "Dừng (" . (r.addedV141+0) . ")"
            PortalLogWriteV66("ROOM_RECORD_CLICK row=" . r.addedV141
                . " room=" . node.routeNumber
                . " xy=" . pxV358 . "," . pyV358)
        }
        else
            GuiControl,, RoomTestButtonV89, Lỗi
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

RoomRecordStopV358()
{
    global roomRecordV108
    if (!IsObject(roomRecordV108))
        return
    Hotkey, ~*LButton, RoomRecordClickV358, Off
    heldV414 := roomRecordV108.fonEditHeldV414
    roomRecordV108 := false
    SetTimer, RoomRecordTimerV108, Off
    if (heldV414)
        FonEditEndV414()
    GuiControl,, RoomTestButtonV89, Tạo
    GuiControl,, RoomContinueButtonV58, Sửa
}
RoomRecordTimerV108:
RoomRecordTickV108()
return

MapTownDirectoryPrepareV411()
{
    global mapRelocatedFilesV412,mapTestModeV656
    static prepared := false
    if (mapTestModeV656)
        return
    if (prepared)
        return
    prepared := true
    mapRelocatedFilesV412 := {}
    townDirectory := A_ScriptDir . "\Map\THANH"
    FileCreateDir, %townDirectory%
    pattern := A_ScriptDir . "\Map\*.ini"
    Loop, Files, %pattern%, F
    {
        source := A_LoopFileFullPath
        level := MapRouteHintV400(source)
        IniRead, owner, %source%, Map, AutoButton, %A_Space%
        if (Trim(owner)="")
        {
            SplitPath, source,,,,stem
            if (RegExMatch(stem,"i)^(BO|CAIN|SCOS|FAUT|NAO|CYC|UBU|TRAN|LIB|130|133|136|139|3000|M3000|WEA|VIZ|THANH)(?:-|$)",m))
                owner := m1
        }
        group := MapRouteGroupV412(owner,level)
        directory := A_ScriptDir . "\Map\" . group
        FileCreateDir, %directory%
        if (!InStr(FileExist(directory),"D"))
            continue
        destination := directory . "\" . A_LoopFileName
        if (FileExist(destination))
            continue
        FileMove, %source%, %destination%, 0
        if (!ErrorLevel)
            mapRelocatedFilesV412[source] := destination
    }
}

MapRouteGroupV412(owner := "",level := 0)
{
    ; Level 1 is a THANH (town) map, never BO. Do not infer folder from stale farm owner.
    if (level=1)
        return "THANH"
    ; Special levels override stale owner/group state; all other levels keep V68 behavior.
    if (level=39)
        return "BO"
    if (level=183 || level=184)
        return "CAIN"
    if (level=263)
        return "LIB"
    if (level=241)
        return "SCOS"
    if (FarmReviveTownLevelV295(level) || owner="THANH")
        return "THANH"
    if (owner="BO")
        return "BO"
    if (level=168 || level=183 || level=184 || level=185)
        return "CAIN"
    if (level=270)
        return "SCOS"
    if (level=155)
        return "FAUT"
    if (level=150)
        return "CYC"
    if (level=148 || level=147)
        return "UBU"
    if (level=146)
        return "TRAN"
    if (level>=263 && level<=266)
        return "LIB"
    if (level=141)
        return "3000"
    if (owner="NAO")
        owner := "FAUT"
    else if (owner="M3000")
        owner := "3000"
    else if (owner=130 || owner=133 || owner=136 || owner=139)
        owner := "LIB"
    for _,group in ["CAIN","SCOS","FAUT","CYC","UBU","TRAN","LIB","3000","WEA","VIZ","THANH"]
        if (owner=group)
            return group
    return "MAP"
}

MapRouteDirectoryV408(owner := "",level := 0)
{
    global farmControlOwnerV186,coordCurrentLevelV400,roomMapLastButtonV22,mapTestModeV656
    if (mapTestModeV656)
        return A_ScriptDir . "\Map\Test"
    if (owner="")
    {
        if (!level)
            level := coordCurrentLevelV400+0
        owner := farmControlOwnerV186!="" ? farmControlOwnerV186 : roomMapLastButtonV22
    }
    return A_ScriptDir . "\Map\" . MapRouteGroupV412(owner,level)
}

MapRouteFileInScopeV408(file,level := 0)
{
    global farmControlOwnerV186,mapTestModeV656
    if (mapTestModeV656 || MapFileIsTestV656(file))
        return mapTestModeV656 && MapFileIsTestV656(file)
    SplitPath, file,,directory
    directory := RTrim(directory,"\")
    if (directory=MapRouteDirectoryV408("",level))
        return true
    if (level=263 && directory=A_ScriptDir . "\Map\THANH")
    {
        SplitPath, file,,,,stemV843
        return RegExMatch(stemV843,"i)^(LIB|130)-Map263-[0-9]+(?:\([0-9]+\))?$") ? true : false
    }
    return farmControlOwnerV186="BO" && !FarmReviveTownLevelV295(level)
        && directory=A_ScriptDir . "\Map\BO"
}

RoomProfileFileV108(profile := "",mapId := 0)
{
    global currentProfile,routeMapIdV21,ConfigFile,mapRelocatedFilesV412,mapTestModeV656
    if (profile="")
        profile := currentProfile
    if (!mapId)
        mapId := routeMapIdV21
    section := RouteMapSectionForV656(profile,mapId)
    IniRead, linked, % ProfileConfigPathV364(section), %section%, RoomMapFile, MISSING
    if (linked!="MISSING" && linked!="" && (mapTestModeV656=MapFileIsTestV656(linked)))
    {
        if (mapTestModeV656)
            return linked
        relocated := ""
        if (IsObject(mapRelocatedFilesV412) && mapRelocatedFilesV412.HasKey(linked))
            relocated := mapRelocatedFilesV412[linked]
        else if (!FileExist(linked))
        {
            SplitPath, linked,name,directory
            if (RTrim(directory,"\")=A_ScriptDir . "\Map")
            {
                for _,group in ["THANH","BO","CAIN","SCOS","FAUT","CYC","UBU","TRAN","LIB","3000","WEA","VIZ","MAP"]
                {
                    candidate := A_ScriptDir . "\Map\" . group . "\" . name
                    if (FileExist(candidate))
                    {
                        relocated := candidate
                        break
                    }
                }
            }
        }
        if (relocated!="" && FileExist(relocated))
        {
            IniWrite, %relocated%, % ProfileConfigPathV364(section), %section%, RoomMapFile
            return relocated
        }
        return linked
    }
    safe := RegExReplace(profile,"[\\/:*?""<>|]","_")
    safe := RTrim(safe," .")
    if (safe="")
        safe := "Default"
    return MapRouteDirectoryV408() . "\" . safe . "-Map-" . mapId . ".ini"
}

RoomMapListTimerV110:
if (!autoMonsterAttackOn && !IsObject(farmMapPauseV52) && !IsObject(roomRecordV108) && !roomRecordFinishingV21)
{
    if (RoomMapsSyncV110(false,coordCurrentLevelV400,coordTrackingEnabledV409))
        RouteMapRefreshV21()
    if (roomMapSelectionResetV111)
    {
        roomMapSelectionResetV111 := false
        if (coordTrackingEnabledV409)
            CoordCurrentReadV15()
        else
        {
            if (routeMapIdV21)
                CoordSavedLoadV15(currentProfile)
            else
                coordSavedV15 := [], coordPointTextV14 := "", coordPointLevelV14 := 0
            CoordBoxRefreshV15(true)
        }
    }
}
return

; V846: F-ON may read legacy routes saved in any existing Map category.
; This does not alter normal GUI map listing, manual recording or old selection logic.
FonFileAllowedV846(file,level)
{
    global mapTestModeV656
    if (level=263)
        return MapRouteFileInScopeV408(file,level)
    if (mapTestModeV656 || MapFileIsTestV656(file))
        return mapTestModeV656 && MapFileIsTestV656(file)
    if (MapRouteHintV400(file)!=level)
        return false
    SplitPath, file,fileNameV848,dirV846
    if (level=1)
    {
        ; Town level 1: never select a BO or other category INI, even if it has the same ID.
        if (dirV846=A_ScriptDir . "\Map\THANH")
            return true
        ; Support a legacy root INI only if its metadata/name explicitly says THANH.
        if (dirV846=A_ScriptDir . "\Map")
        {
            IniRead, townOwnerV848, %file%, Map, AutoButton, %A_Space%
            return (townOwnerV848="THANH" || RegExMatch(fileNameV848,"i)^THANH[-_]")) ? true : false
        }
        return false
    }
    if (dirV846=A_ScriptDir . "\Map")
        return true
    for _,groupV846 in ["MAP","THANH","BO","CAIN","SCOS","FAUT","CYC","UBU","TRAN","LIB","3000","WEA","VIZ"]
        if (dirV846=A_ScriptDir . "\Map\" . groupV846)
            return true
    return false
}

RoomMapsSyncV110(allowFarmStartV143 := false,levelV408 := 0,keepCoordinatesV721 := false,scanAllLevelV846 := false)
{
    global currentProfile,ConfigFile,routeMapsV21,routeMapIdV21,routeMapNextV21,autoMonsterAttackOn,roomRecordV108,roomMapSelectionResetV111
    global farmControlOwnerV186,mapTestModeV656,roomRecordFinishingV21
    global coordMapStateV381,coordMapReadyV381,coordMapAcceptedV381,stage2MapFileV14,farmLoadedMapV56
    if (!IsObject(routeMapsV21) || (!allowFarmStartV143 && (autoMonsterAttackOn || IsObject(roomRecordV108))))
        return false
    oldMaps := routeMapsV21, newMaps := [], selectedFound := false, changed := false
    directoryV408 := MapRouteDirectoryV408("",levelV408)
    if (!mapTestModeV656 && farmControlOwnerV186="BO")
        BOMapDirectoryNormalizeV426()
    for _,mapV408 in oldMaps
    {
        otherFileV408 := RoomProfileFileV108(currentProfile,mapV408.id)
        SplitPath, otherFileV408,,otherDirV408
        if (!mapTestModeV656 && !MapFileIsTestV656(otherFileV408) && otherDirV408!=directoryV408 && FileExist(otherFileV408)
            && !(scanAllLevelV846 && levelV408>0 && MapRouteHintV400(otherFileV408)=levelV408)
            && !(levelV408=263 && otherDirV408=A_ScriptDir . "\Map\THANH" && MapRouteHintV400(otherFileV408)=263)
            && !(farmControlOwnerV186="BO" && !FarmReviveTownLevelV295(levelV408)
                && otherDirV408=A_ScriptDir . "\Map\BO"))
        {
            newMaps.Push(mapV408)
            if (mapV408.id=routeMapIdV21)
                selectedFound := true
        }
    }
    pattern := directoryV408 . "\*.ini", files := ""
    Loop, Files, %pattern%, F
        files .= A_LoopFileFullPath . "`n"
    if (scanAllLevelV846 && levelV408>0 && !mapTestModeV656)
    {
        ; F-ON only: look up real level across all old and new MAP subfolders.
        ; Filter by level before adding to avoid registering all files indiscriminately.
        for _,folderV846 in ["MAP","THANH","BO","CAIN","SCOS","FAUT","CYC","UBU","TRAN","LIB","3000","WEA","VIZ"]
        {
            otherPatternV846 := A_ScriptDir . "\Map\" . folderV846 . "\*.ini"
            Loop, Files, %otherPatternV846%, F
            {
                if (A_LoopFileDir=directoryV408)
                    continue
                if (MapRouteHintV400(A_LoopFileFullPath)=levelV408)
                    files .= A_LoopFileFullPath . "`n"
            }
        }
        ; Also support legacy INIs stored directly under Map.
        legacyRootV846 := A_ScriptDir . "\Map\*.ini"
        Loop, Files, %legacyRootV846%, F
            if (MapRouteHintV400(A_LoopFileFullPath)=levelV408)
                files .= A_LoopFileFullPath . "`n"
    }
    if (levelV408=263 && !mapTestModeV656 && !scanAllLevelV846)
    {
        legacyPatternV843 := A_ScriptDir . "\Map\THANH\*.ini"
        Loop, Files, %legacyPatternV843%, F
        {
            SplitPath, A_LoopFileFullPath,,,,legacyStemV843
            if (RegExMatch(legacyStemV843,"i)^(LIB|130)-Map263-[0-9]+(?:\([0-9]+\))?$")
                && MapRouteHintV400(A_LoopFileFullPath)=263)
                files .= A_LoopFileFullPath . "`n"
        }
    }
    Sort, files
    Loop, Parse, files, `n, `r
    {
        file := A_LoopField
        if (file="")
            continue
        data := RoomMapReadV109(file,true)
        IniRead, metadataName, %file%, Map, Name, MISSING
        if (!IsObject(data) && metadataName="MISSING")
            continue
        id := 0
        for _,map in oldMaps
            if (RoomProfileFileV108(currentProfile,map.id)=file)
            {
                id := map.id
                break
            }
        if (!id)
            id := routeMapNextV21++
        SplitPath, file,,,, name
        mapSection := RouteMapSectionForV656(currentProfile,id)
        IniRead, linkedFile, % ProfileConfigPathV364(mapSection), %mapSection%, RoomMapFile, MISSING
        if (linkedFile!=file)
            IniWrite, %file%, % ProfileConfigPathV364(mapSection), %mapSection%, RoomMapFile
        newMaps.Push({id:id,name:name})
        if (id=routeMapIdV21)
            selectedFound := true
    }
    if (newMaps.Length()!=oldMaps.Length())
        changed := true
    else
        for i,map in newMaps
            if (map.id!=oldMaps[i].id || map.name!=oldMaps[i].name)
            {
                changed := true
                break
            }
    routeMapsV21 := newMaps
    if (!selectedFound && !IsObject(roomRecordV108) && !roomRecordFinishingV21)
    {
        changed := true
        coordMapStateV381 := false,coordMapReadyV381 := false,coordMapAcceptedV381 := false
        stage2MapFileV14 := false,farmLoadedMapV56 := false
        if (!keepCoordinatesV721)
        {
            routeMapIdV21 := newMaps.Length() ? newMaps[1].id : 0
            roomMapSelectionResetV111 := true
            CoordRouteInvalidateV10()
        }
        else
            roomMapSelectionResetV111 := false
    }
    if (changed)
        RouteMapsStoreV21(currentProfile)
    return changed
}

RoomMapLoadV109:
FileSelectFile, roomMapSourceV109, 3, % MapRouteDirectoryV408(), Chọn file map đã lưu phòng, Map phòng (*.ini)
if (ErrorLevel || roomMapSourceV109="")
    return
roomMapDataV109 := RoomMapReadV109(roomMapSourceV109)
if (!IsObject(roomMapDataV109) || roomMapDataV109.points.Length()<2)
{
    MsgBox, 48, Load map, File không có lộ trình phòng hợp lệ (cần ít nhất 2 lượt phòng).
    return
}
if (IsObject(roomRecordV108))
{
    roomRecordV108 := false
    SetTimer, RoomRecordTimerV108, Off
    GuiControl,, RoomTestButtonV89, Tạo
    GuiControl,, RoomContinueButtonV58, Sửa
}
if (autoMonsterAttackOn)
{
    autoMonsterAttackOn := false
    Gosub, AutoMonsterAttackToggle
}
roomMapChosenV109 := 0
for _,mapV109 in routeMapsV21
{
    roomMapExistingV109 := RoomProfileFileV108(currentProfile,mapV109.id)
    roomMapSectionV109 := RouteMapSectionForV656(currentProfile,mapV109.id)
    IniRead, roomMapOriginV109, % ProfileConfigPathV364(roomMapSectionV109), %roomMapSectionV109%, RoomMapSource, MISSING
    if (roomMapSourceV109=roomMapExistingV109 || roomMapSourceV109=roomMapOriginV109)
    {
        roomMapChosenV109 := mapV109.id
        break
    }
}
if (roomMapChosenV109 && roomMapSourceV109!=RoomProfileFileV108(currentProfile,roomMapChosenV109))
{
    roomMapDestV109 := RoomProfileFileV108(currentProfile,roomMapChosenV109)
    ; Keep original INI: do not overwrite when a source alias resolves to another file.
    MsgBox, 48, Load map, INI đã có trong danh sách. Hãy chọn file gốc; không ghi đè INI cũ.
    return
}
if (!roomMapChosenV109)
{
    roomMapChosenV109 := routeMapNextV21
    roomMapDestV109 := RoomProfileFileV108(currentProfile,roomMapChosenV109)
    SplitPath, roomMapDestV109,, roomMapDirectoryV408
    FileCreateDir, %roomMapDirectoryV408%
    if (ErrorLevel)
    {
        MsgBox, 48, Load map, Không tạo được thư mục Map.
        return
    }
    FileCopy, %roomMapSourceV109%, %roomMapDestV109%, 0
    if (ErrorLevel)
    {
        MsgBox, 48, Load map, Không sao chép được file map. Lộ trình cũ được giữ nguyên.
        return
    }
    SplitPath, roomMapSourceV109,,,, roomMapNameV109
    roomMapNameV109 := StrReplace(roomMapNameV109,"|","_")
    routeMapsV21.Push({id:roomMapChosenV109,name:roomMapNameV109})
    routeMapNextV21 := roomMapChosenV109+1
    roomMapSectionV109 := RouteMapSectionForV656(currentProfile,roomMapChosenV109)
    IniWrite, %roomMapSourceV109%, % ProfileConfigPathV364(roomMapSectionV109), %roomMapSectionV109%, RoomMapSource
}
RouteMapActivateV21(roomMapChosenV109)
CoordSavedStoreV15(currentProfile)
ToolTipInfoV386("Đã load map và dãy phòng. Bật farm để chạy.")
SetTimer, RemoveToolTip, -3000
return

RoomMapReadV109(file,metadataOnly := false,expectedLevel := 0)
{
    global outsideLevelV22
    if (!FileExist(file))
        return false
    fileLevelV402 := MapRouteHintV400(file)
    if (expectedLevel && fileLevelV402 && fileLevelV402!=expectedLevel)
        return false
    IniRead, sections, %file%
    preferredLevelV399 := expectedLevel ? expectedLevel : (fileLevelV402 ? fileLevelV402 : outsideLevelV22)
    chosen := "", level := 0
    Loop, Parse, sections, `n, `r
    {
        if (!RegExMatch(A_LoopField,"^Route-(\d+)$",match))
            continue
        section := A_LoopField
        IniRead, format, %file%, %section%, Format, MISSING
        if (format!="ROOM_CENTERS_V1")
            continue
        if (expectedLevel && match1+0!=expectedLevel)
            continue
        if (chosen="" || match1+0=preferredLevelV399)
            chosen := section, level := match1+0
        if (level=preferredLevelV399)
            break
    }
    if (chosen="")
        return false
    IniRead, count, %file%, %chosen%, Count, 0
    if (!RegExMatch(count,"^\d+$") || count<1 || count>10000)
        return false
    if (metadataOnly)
        return {level:level,count:count+0}
    points := []
    Loop, %count%
    {
        key := "Room" . A_Index
        IniRead, value, %file%, %chosen%, %key%, MISSING
        if (!RegExMatch(value,"^(\d+)\|(\d+),(\d+)$",m)
            || m2<1 || m2>65535 || m3<1 || m3>65535)
            return false
        points.Push({x:m2+0,y:m3+0,level:level,roomNumber:m1+0})
    }
    geometrySectionV270 := "Geometry-" . level
    IniRead, roomCountV270, %file%, %geometrySectionV270%, RoomCount, 0
    IniRead, totalRoomsV275, %file%, %geometrySectionV270%, TotalRooms, %roomCountV270%
    roomCountV270 := totalRoomsV275
    IniRead, roomLayoutV270, %file%, %geometrySectionV270%, Layout, %A_Space%
    roomLayoutV270 := Trim(roomLayoutV270)
    IniRead, partialV399, %file%, %geometrySectionV270%, Partial, 0
    return {level:level,points:points,roomCount:roomCountV270+0,roomLayout:roomLayoutV270
        ,gates:MapGatesFileReadV397(file,level),partial:partialV399+0}
}

RoomRouteFileV108()
{
    global roomRecordV108,roomExploreV89
    if (IsObject(roomRecordV108))
        return roomRecordV108.file
    if (IsObject(roomExploreV89) && roomExploreV89.file!="")
        return roomExploreV89.file
    return RoomProfileFileV108()
}

RoomRecordSnapshotV413(pid,level)
{
    first := MapLiveIdentityV399(pid,level)
    if (!IsObject(first))
        return false
    geometry := MapRoomLayoutReadV270(pid,level)
    gates := MapGatesReadV397(pid,level)
    last := MapLiveIdentityV399(pid,level)
    if (!IsObject(last) || last.levelPtr!=first.levelPtr)
        return false
    if (IsObject(geometry) && !RoomRecordRectV413(geometry,last.x,last.y))
        return false
    return {pid:pid,level:level,levelPtr:first.levelPtr,geometry:geometry
        ,gates:IsObject(gates) ? gates : []}
}

RoomRecordRectV413(geometry,x,y)
{
    if (!IsObject(geometry) || !IsObject(geometry.rects))
        return ""
    for key,_ in geometry.rects
    {
        rect := StrSplit(key,"_")
        if (rect.Length()=4 && x>=rect[1] && x<rect[1]+rect[3] && y>=rect[2] && y<rect[2]+rect[4])
            return key
    }
    return ""
}

RoomRecordSnapshotStillLiveV413(snapshot)
{
    live := MapLiveIdentityV399(snapshot.pid,snapshot.level)
    return IsObject(live) && live.levelPtr=snapshot.levelPtr
}

RoomRecordSameMapV413(r)
{
    if (!IsObject(r.snapshotV413))
        return false
    live := MapLiveIdentityV399(r.pid,r.level)
    return IsObject(live) && live.levelPtr=r.snapshotV413.levelPtr
}

RoomRecordGatesWriteV413(file,level,gates)
{
    if (!FileExist(file) || !IsObject(gates))
        return false
    section := "Gates-" . level
    IniDelete, %file%, %section%
    IniWrite, EXIT_XY_ROOM_V1, %file%, %section%, Format
    if (ErrorLevel)
        return false
    IniWrite, % gates.Length(), %file%, %section%, Count
    if (ErrorLevel)
        return false
    for i,gate in gates
    {
        key := "Gate" . i
        IniWrite, % gate.key, %file%, %section%, %key%
        if (ErrorLevel)
            return false
    }
    return IsObject(MapGatesFileReadV397(file,level))
}

RoomRecordRoomsWriteV413(file,level,points,geometry)
{
    if (!IsObject(geometry))
        return false
    section := "Rooms-" . level,numbers := {},used := {},next := 1
    for _,point in points
    {
        key := RoomRecordRectV413(geometry,point.x,point.y)
        if (key="")
            return false
        if (!numbers.HasKey(key))
        {
            number := point.roomNumber
            if (number<1 || used.HasKey(number))
            {
                while (used.HasKey(next))
                    next++
                number := next
            }
            numbers[key] := number,used[number] := true
            next := Max(next,number+1)
        }
        point.roomNumber := numbers[key]
    }
    IniDelete, %file%, %section%
    for key,number in numbers
    {
        IniWrite, %number%, %file%, %section%, %key%
        if (ErrorLevel)
            return false
    }
    IniWrite, %next%, %file%, %section%, NextNumber
    return !ErrorLevel
}

RoomRecordMetadataFinishV413(r)
{
    data := RoomMapReadV109(r.file,false,r.level)
    if (!IsObject(data) || !IsObject(r.snapshotV413))
        return false
    snapshot := r.snapshotV413
    if (RoomRecordSameMapV413(r))
    {
        refreshed := RoomRecordSnapshotV413(r.pid,r.level)
        if (IsObject(refreshed) && refreshed.levelPtr=snapshot.levelPtr)
            snapshot := refreshed
    }
    geometry := snapshot.geometry
    if (!IsObject(geometry))
        return false
    temp := r.file . ".metadata.tmp"
    FileCopy, % r.file, %temp%, 1
    if (ErrorLevel)
        return false
    if (!RoomRecordRoomsWriteV413(temp,r.level,data.points,geometry)
        || !RoomMapPointsWriteV126(temp,r.level,data.points)
        || !MapRoomLayoutSaveV270(temp,geometry)
        || !RoomRecordGatesWriteV413(temp,r.level,snapshot.gates))
        return false
    FileMove, %temp%, % r.file, 1
    if (ErrorLevel)
        return false
    r.snapshotV413 := snapshot,r.geometryV275 := geometry
    return true
}

RoomRecordFreshStartV195(r,level)
{
    if (!IsObject(r) || !level || !FileExist(r.file))
        return false
    snapshotV413 := RoomRecordSnapshotV413(r.pid,level)
    if (!IsObject(snapshotV413))
        return false
    geometryV275 := snapshotV413.geometry
    temp := r.file . ".fresh.tmp"
    backup := r.file . ".before-record-" . A_Now . "-" . A_TickCount . ".bak"
    FileCopy, % r.file, %backup%, 0
    if (ErrorLevel)
        return false
    FileCopy, % r.file, %temp%, 1
    if (ErrorLevel)
        return false
    IniRead, oldSectionsV402, %temp%
    Loop, Parse, oldSectionsV402, `n, `r
        if (RegExMatch(A_LoopField,"^(Route|Geometry|Gates|Rooms)-\d+$"))
        {
            oldSectionV402 := A_LoopField
            IniDelete, %temp%, %oldSectionV402%
            if (ErrorLevel)
                return false
        }
    section := "Route-" . level,roomSection := "Rooms-" . level
    IniWrite, %level%, %temp%, Map, RecordedLevel
    if (ErrorLevel)
        return false
    geometrySectionV274 := "Geometry-" . level
    IniDelete, %temp%, %geometrySectionV274%
    gateSectionV397 := "Gates-" . level
    IniDelete, %temp%, %gateSectionV397%
    IniDelete, %temp%, %section%
    IniWrite, ROOM_CENTERS_V1, %temp%, %section%, Format
    if (ErrorLevel)
        return false
    IniWrite, 0, %temp%, %section%, Count
    if (ErrorLevel)
        return false
    IniWrite, %A_Space%, %temp%, %section%, Sequence
    if (ErrorLevel)
        return false
    if (IsObject(geometryV275))
    {
        if (!MapRoomLayoutSaveV270(temp,geometryV275))
        {
            PortalLogWriteV66("MAP_GEOMETRY_SAVE_FAILED level=" . level . " action=CONTINUE_WITHOUT_GEOMETRY")
            r.geometrySavedV270 := false
        }
        else
        {
            r.geometrySavedV270 := true
            PortalLogWriteV66("MAP_GEOMETRY_SAVED source=RECORD_START level=" . level
                . " total_rooms=" . geometryV275.count . " partial=" . (geometryV275.HasKey("partial") ? geometryV275.partial : 0))
        }
    }
    else
    {
        r.geometrySavedV270 := false
        PortalLogWriteV66("MAP_GEOMETRY_SKIP level=" . level . " reason=READ_FAILED continue=1")
    }
    if (!RoomRecordGatesWriteV413(temp,level,snapshotV413.gates))
        return false
    if (!RoomRecordSnapshotStillLiveV413(snapshotV413))
        return false
    r.snapshotV413 := snapshotV413
    r.geometryV275 := IsObject(geometryV275) ? geometryV275 : false
    FileMove, %temp%, % r.file, 1
    if (ErrorLevel)
        return false
    r.backupFileV276 := backup
    r.freshStartedV195 := true,r.lastNumber := -1
    r.appendStartedV141 := false,r.addedV141 := 0
    r.lastPointV358 := false
    return true
}
RoomRecordAppendV141(r,node,x,y)
{
    static busy := false
    if (busy || !IsObject(r) || !IsObject(node) || !FileExist(r.file))
        return false
    busy := true
    try
    {
        section := "Route-" . node.level

        IniRead, currentCount, % r.file, %section%, Count, MISSING
        if (currentCount="MISSING")
            currentCount := 0
        else if (!RegExMatch(currentCount,"^\d+$") || currentCount+0>10000)
            return RoomRecordErrorV141(r)
        else
            currentCount := currentCount+0

        if (currentCount>0)
        {
            lastKey := "Room" . currentCount
            IniRead, lastValue, % r.file, %section%, %lastKey%, MISSING
            if (RegExMatch(lastValue,"^(\d+)\|(\d+),(\d+)$",m)
                && m1+0=node.routeNumber && m2+0=x && m3+0=y)
            {
                r.appendStartedV141 := true
                r.lastNumber := node.routeNumber
                return true
            }
        }

        if (currentCount>=10000 || x<1 || y<1)
            return RoomRecordErrorV141(r)

        newStep := currentCount+1
        key := "Room" . newStep
        value := node.routeNumber . "|" . x . "," . y
        IniWrite, %value%, % r.file, %section%, %key%
        if (ErrorLevel)
            return RoomRecordErrorV141(r)

        IniWrite, %newStep%, % r.file, %section%, Count
        if (ErrorLevel)
            return RoomRecordErrorV141(r)

        IniRead, oldSeq, % r.file, %section%, Sequence, %A_Space%
        if (oldSeq="ERROR")
            oldSeq := ""
        newSeq := oldSeq="" ? node.routeNumber : oldSeq . "-" . node.routeNumber
        IniWrite, %newSeq%, % r.file, %section%, Sequence

        r.appendStartedV141 := true,r.addedV141 := (r.addedV141+0)+1
        r.lastNumber := node.routeNumber
        return true
    }
    finally
        busy := false
}

RoomRecordErrorV141(r)
{
    if (!r.lastErrorV141 || A_TickCount-r.lastErrorV141>3000)
    {
        r.lastErrorV141 := A_TickCount
        ToolTipInfoV386("LƯU PHÒNG THẤT BẠI: kiểm tra file map và quyền ghi. Các dòng cũ được giữ nguyên.")
        SetTimer, RemoveToolTip, -3000
    }
    return false
}

RoomRecordTickV108()
{
    global roomRecordV108,currentProfile,routeMapIdV21,townLevelV22
    r := roomRecordV108
    if (!IsObject(r))
        return
    if (r.profile!=currentProfile)
    {
        RoomRecordStopV358()
        return
    }
    pid := r.pid ? r.pid : CoordDisplayGamePidV1()
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return
    try
    {
        player := D2ReadU32(h,base+0x11BBFC), mode := player ? D2ReadU32(h,player+0x10) : 0
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if (mode=0 || mode=17 || !MonsterBossProbeReadV1(h,path,0x20,pb))
            return
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        if (!level || level=townLevelV22)
            return
        if (!FileExist(r.file))
        {
            RoomRecordStopV358()
            ToolTipInfoV386("File map đã mất. Dừng lưu; không tạo file thay thế.")
            SetTimer, RemoveToolTip, -3000
            return
        }
        
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}


CoordLiveRoomYellowV128(h,ByRef pb,level)
{
    ; V845: F-ON follows the recorded route without rewriting/reloading the INI.
    ; A stable nearby waypoint for 500ms moves the yellow highlight.
    static pendingRowV845 := 0, pendingSinceV845 := 0, pendingKeyV845 := ""
    global coordSavedV15,coordYellowRowV350,coordLiveYellowV128,coordNearbyRowV18,coordPinnedYellowV136
    global coordTrackingEnabledV409,fonCursorV724,currentProfile,routeMapIdV21
    global coordMapReadyV381,coordMapStateV381,coordRouteV16,autoMonsterAttackOn
    global coordGoV59,roomExploreV89,coordMapSerialV381
    if (!coordTrackingEnabledV409 || !coordMapReadyV381
        || !IsObject(coordMapStateV381) || !coordMapStateV381.loaded
        || coordMapStateV381.level!=level || coordMapStateV381.mapId!=routeMapIdV21
        || coordMapStateV381.profile!=currentProfile
        || !IsObject(coordSavedV15) || !coordSavedV15.Length()
        || coordSavedV15[1].level!=level)
    {
        pendingKeyV845 := "",pendingRowV845 := 0
        return
    }
    pxV845 := NumGet(pb,2,"UShort"),pyV845 := NumGet(pb,6,"UShort")
    rowV845 := CoordYellowIndexV48()
    if (rowV845<1 || rowV845>coordSavedV15.Length()
        || coordSavedV15[rowV845].level!=level)
        rowV845 := 1
    ; When the farm/GO engine owns movement, its own yellow row is authoritative.
    ; Only the passive F-ON watcher may infer a new row from position.
    if (!autoMonsterAttackOn && !FarmControlRunningV186() && !IsObject(coordGoV59)
        && !(IsObject(roomExploreV89) && roomExploreV89.savedRouteOnly))
    {
        bestV845 := rowV845,bestSqV845 := 1.0e30
        currentSqV845 := (pxV845-coordSavedV15[rowV845].x)**2
            +(pyV845-coordSavedV15[rowV845].y)**2
        ; No Room2 or HASH requirement. Only a waypoint near the player qualifies.
        for iV845,pV845 in coordSavedV15
        {
            if (pV845.level!=level)
                continue
            sqV845 := (pxV845-pV845.x)**2+(pyV845-pV845.y)**2
            ; Prefer the nearby adjacent route row on crossings of long routes.
            scoreV845 := sqV845 + Min(Abs(iV845-rowV845),6)*4
            if (sqV845<=144 && scoreV845<bestSqV845)
                bestV845 := iV845,bestSqV845 := scoreV845
        }
        yellowKeyV845 := coordMapSerialV381 . "|" . routeMapIdV21 . "|" . level
        if (bestV845!=rowV845 && (currentSqV845>144
            || (pxV845-coordSavedV15[bestV845].x)**2
                +(pyV845-coordSavedV15[bestV845].y)**2+9<currentSqV845))
        {
            if (pendingRowV845!=bestV845 || pendingKeyV845!=yellowKeyV845)
            {
                pendingRowV845 := bestV845,pendingKeyV845 := yellowKeyV845
                pendingSinceV845 := A_TickCount
            }
            else if (A_TickCount-pendingSinceV845>=500)
            {
                rowV845 := bestV845
                pendingRowV845 := 0
                coordYellowRowV350 := rowV845,coordPinnedYellowV136 := rowV845
                coordLiveYellowV128 := rowV845,coordNearbyRowV18 := rowV845
                ; CoordYellowIndexV48 can prioritize this old route's yellow.
                ; The farm is OFF, so the UI cursor may safely follow F-ON.
                if (IsObject(coordRouteV16) && coordRouteV16.yellow>=1)
                    coordRouteV16.yellow := rowV845
                PortalLogWriteV66("FON_YELLOW_ADVANCE map=" . routeMapIdV21
                    . " level=" . level . " row=" . rowV845 . " x=" . pxV845 . " y=" . pyV845
                    ,"FON_YELLOW",400)
                CoordBoxRefreshV15(true)
            }
        }
        else
            pendingRowV845 := 0
    }
    else
        pendingRowV845 := 0
    ; Observing the same loaded map updates the cursor, not the INI or map ID.
    if (rowV845>=1 && rowV845<=coordSavedV15.Length())
    {
        coordYellowRowV350 := rowV845,coordLiveYellowV128 := rowV845
        coordNearbyRowV18 := rowV845,coordPinnedYellowV136 := rowV845
        if (IsObject(fonCursorV724) && fonCursorV724.level=level
            && fonCursorV724.profile=currentProfile && fonCursorV724.mapId=routeMapIdV21)
            fonCursorV724.row := rowV845,fonCursorV724.playerX := pxV845,fonCursorV724.playerY := pyV845
    }
}
CoordRouteInvalidateV10()
{
    global coordSavedV15,coordPointLevelV14,coordPointTextV14,coordYellowRowV350,coordLiveYellowV128
    global coordNearbyRowV18,coordPinnedYellowV136,coordManualRowV59,coordMapStateV381
    global coordGoV59,coordRouteV16,roomExploreV89,farmLoadedMapV56
    if (IsObject(roomExploreV89))
        RoomExploreEndV89("ROUTE_FILE_UNAVAILABLE")
    farmLoadedMapV56 := false
    coordSavedV15 := [],coordPointLevelV14 := 0,coordPointTextV14 := ""
    coordYellowRowV350 := 0,coordLiveYellowV128 := 0,coordNearbyRowV18 := 0
    coordPinnedYellowV136 := 0,coordManualRowV59 := 0,coordMapStateV381 := false
    coordGoV59 := false
    SetTimer, CoordGoTimerV59, Off
    CoordRouteResetV16()
    CoordBoxRefreshV15(true)
}

RoomGroupNumberV118(h,ByRef pb,level)
{
    room1 := NumGet(pb,0x1C,"UInt")
    node := RoomExploreReadV89(h,D2ReadU32(h,room1+0x10),level,true)
    if (!IsObject(node))
        return -1
    file := RoomProfileFileV108(), section := "Rooms-" . level
    key := node.x . "_" . node.y . "_" . node.w . "_" . node.h
    IniRead, number, %file%, %section%, %key%, MISSING
    return RegExMatch(number,"^\d+$") ? number+0 : -1
}

RoomGroupObserveV118(h,ByRef pb,level)
{
    routePointsV724 := FarmRoutePointsV724()
    global coordRouteV16,monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44
    global autoMapTrackingV10,coordLiveYellowV128,coordNearbyRowV18
    r := coordRouteV16
    if (!IsObject(r) || r.phase!="NEXT" || !routePointsV724.Length())
        return
    current := (r.anchor>=1 && r.anchor<=routePointsV724.Length())
        ? routePointsV724[r.anchor] : 0
    number := RoomGroupNumberV118(h,pb,level)
    row := r.anchor+1, reached := 0
    if (row>=1 && row<=routePointsV724.Length())
    {
        point := routePointsV724[row]
        finalFarmPointV577 := row=routePointsV724.Length() && !FarmCommonRouteActiveV3(0,level)
        arrivalSqV577 := finalFarmPointV577 ? 25 : (point.HasKey("arrivalSqV3") ? Max(0,point.arrivalSqV3) : 25)
        nearPoint := (NumGet(pb,2,"UShort")-point.x)**2+(NumGet(pb,6,"UShort")-point.y)**2
            <=arrivalSqV577
        if (point.level=level && nearPoint)
            reached := row
    }
    if (!reached || (r.lastArrivalV343 && A_TickCount-r.lastArrivalV343<300))
        return
    r.lastArrivalV343 := A_TickCount
    oldRow := r.anchor
    r.anchor := reached,r.yellow := reached,r.next := reached+1
    r.phase := r.next>routePointsV724.Length() ? "DONE" : "NEXT"
    r.escapeV84 := false,r.stuckProbe := false,r.moveProbe := false,r.lastDispatch := 0
    r.firstMoveAttempted := false,r.bypass := false,r.legRow := 0
    global coordNoTargetSinceV14
    coordNoTargetSinceV14 := A_TickCount-250
    monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
    CoordCastMarkV50(reached)
    RoomExploreLogV89("ROOM_GROUP_ADVANCE from_row=" . oldRow . " to_row=" . reached . " room=" . number . " saved_room=" . point.roomNumber . " order=FORWARD_ONLY source=" . (nearPoint ? "SUCCESSOR_XY" : "LIVE_ROOM"))
    CoordBoxRefreshV15(true)
}

RoomFarmBoundaryV235()
{
    global roomExploreV89
    if (BossSearchActiveV430())
        return false
    return !ScosOrderedRouteV234() && IsObject(roomExploreV89)
}

RoomCoordinateModeV116()
{
    routePointsV724 := FarmRoutePointsV724()
    if (BOCommonActiveV444())
        return false
    global autoMonsterAttackOn,roomExploreV89
    return !ScosOrderedRouteV234() && autoMonsterAttackOn && !IsObject(roomExploreV89) && IsObject(routePointsV724)
        && routePointsV724.Length()>0 && routePointsV724[1].HasKey("roomNumber")
}

RoomExploreLogV89(message)
{
    if (ManualLogActiveV81())
        ManualLogAppendV81(A_Now . " tick=" . A_TickCount . " | " . message . "`r`n",A_ScriptDir . "\Auto-GSF-Test-Phong.log")
}

RoomExploreEndV89(reason)
{
    global roomExploreV89, coordSavedV15, coordPointTextV14, coordPointLevelV14,coordNearbyRowV18
    global coordCastPendingV50, portalBackPendingV74, portalBuffV85, stateBuffKeyV17, deathlordStateV19
    global coordYellowRowV350
    r := roomExploreV89
    if (!IsObject(r))
        return
    RoomExploreLogV89("TEST_END reason=" . reason . " discovered=" . r.nodes.Count() . " visited=" . r.visited.Count())
    if (r.savedRouteOnly)
        coordYellowRowV350 := r.displayRow
    stateBuffKeyV17 := r.savedZKey, deathlordStateV19 := r.savedZState
    roomExploreV89 := false
    coordCastPendingV50 := false, portalBackPendingV74 := false, portalBuffV85 := false
    PortalExitCancelV69()
    CoordRouteResetV16()
    GuiControl,, RoomTestButtonV89, Tạo
    GuiControl,, RoomContinueButtonV58, Sửa
    if (reason!="STANDARD_GD2_NEW_LOADED_ROUTE" && reason!="ROUTE_FILE_UNAVAILABLE")
        Stage2MapRequestV381(true)
    CoordBoxRefreshV15(true)
}

RoomExploreStopV89(reason)
{
    global
    rV89 := roomExploreV89
    if (!IsObject(rV89))
        return
    RoomExploreEndV89(reason)
    autoMonsterAttackOn := false
    Gosub, AutoMonsterAttackToggle
    farmResumeArmedV70 := false, farmResumeOutsideV70 := false
    SetTimer, FarmResumeTimerV70, Off
    baseV89 := D2GetModuleBaseV35(rV89.pid,"D2Client.dll")
    hV89 := baseV89 ? D2OpenProcess(rV89.pid) : 0
    if (hV89)
    {
        try
        {
            playerV89 := D2ReadU32(hV89,baseV89+0x11BBFC), pathV89 := playerV89 ? D2ReadU32(hV89,playerV89+0x2C) : 0
            if (MonsterBossProbeReadV1(hV89,pathV89,0x20,pbV89) && D2GetActiveGamePidV95()=rV89.pid)
            {
                coordGoV59 := {pid:rV89.pid,x:NumGet(pbV89,2,"UShort"),y:NumGet(pbV89,6,"UShort"),level:CoordLevelV14(hV89,NumGet(pbV89,0x1C,"UInt")),row:0,redirect:true,stop:true,resumeFarm:false}
                SetTimer, CoordGoTimerV59, 50
            }
        }
        finally
            DllCall("CloseHandle","Ptr",hV89)
    }
}

RoomExploreReadV89(h,r2,level,geometryOnlyV141 := false)
{
    if (r2<0x10000 || !MonsterBossProbeReadV1(h,r2,0x60,b))
        return false
    lp := NumGet(b,0x58,"UInt")
    if (!lp || D2ReadU32(h,lp+0x1D0)!=level)
        return false
    x := NumGet(b,0x34,"UInt"), y := NumGet(b,0x38,"UInt"), w := NumGet(b,0x3C,"UInt"), ht := NumGet(b,0x40,"UInt")
    if (!w || !ht || w>200 || ht>200 || (x+w)*5>65535 || (y+ht)*5>65535)
        return false
    r1 := NumGet(b,0x30,"UInt"), near := NumGet(b,8,"UInt"), n := NumGet(b,0x2C,"UInt"), links := []
    if (geometryOnlyV141)
        return {r2:r2,level:level,x:x*5,y:y*5,w:w*5,h:ht*5,cx:Round((x+w/2)*5),cy:Round((y+ht/2)*5)}
    if (n>64 || (n && near<0x10000))
        return false
    if (n && !MonsterBossProbeReadV1(h,near,n*4,nb))
        return false
    Loop, %n%
    {
        q := NumGet(nb,(A_Index-1)*4,"UInt")
        if (q>=0x10000 && q!=r2)
            links.Push(q)
    }
    loaded := r1>=0x10000 && D2ReadU32(h,r1+0x10)=r2
    return {r2:r2,r1:loaded ? r1 : 0,level:level,x:x*5,y:y*5,w:w*5,h:ht*5,cx:Round((x+w/2)*5),cy:Round((y+ht/2)*5),links:links,raw:MonsterBossProbeHexV1(b,0x60)}
}

RoomExploreDiscoverV89(h,r,r2)
{
    node := RoomExploreReadV89(h,r2,r.level)
    if (!IsObject(node))
        return false
    fresh := !r.nodes.HasKey(r2)
    node.routeNumber := RoomRouteNumberV105(node)
    r.nodes[r2] := node
    if (fresh)
    {
        links := ""
        for _,p in node.links
            links .= (links="" ? "" : ",") . V92Hex(p)
        RoomExploreLogV89("ROOM_DISCOVER room2=" . V92Hex(r2) . " room1=" . V92Hex(node.r1) . " loaded=" . (node.r1!=0)
            . " map=" . node.level . " rect=" . node.x . "," . node.y . "," . node.w . "," . node.h . " center=" . node.cx . "," . node.cy
            . " links=" . links . " " . RoomDescribeV19(h,r2) . " raw_room2=" . node.raw)
        if (node.r1 && MonsterBossProbeReadV1(h,node.r1,0x80,rb))
            RoomExploreLogV89("ROOM1_RAW room=" . V92Hex(node.r1) . " bytes=" . MonsterBossProbeHexV1(rb,0x80))
    }
    return node
}

RoomRouteNumberV105(node,file := "")
{
    if (!IsObject(node))
        return -1
    if (file="")
        file := RoomRouteFileV108()
    section := "Rooms-" . node.level
    key := node.x . "_" . node.y . "_" . node.w . "_" . node.h
    IniRead, number, %file%, %section%, %key%, MISSING
    if (number!="MISSING")
        return number+0
    IniRead, number, %file%, %section%, NextNumber, 1
    number += 0
    IniWrite, %number%, %file%, %section%, %key%
    if (ErrorLevel)
        return -1
    nextNumber := number+1
    IniWrite, %nextNumber%, %file%, %section%, NextNumber
    return number
}

RoomRouteReachedV105(r,node,px,py,kind)
{
    if (!IsObject(node) || node.routeNumber<0)
        return false
    file := RoomRouteFileV108()
    section := "Route-" . node.level
    if (r.savedRouteOnly)
        return true
    if (r.insertMode)
    {
        r.segment.Push({x:node.cx,y:node.cy,level:node.level,roomNumber:node.routeNumber})
        RoomExploreLogV89("ROOM_INSERT_CAPTURE after_row=" . r.afterRow . " room=" . node.routeNumber . " segment_count=" . r.segment.Length())
        return true
    }
    if (!r.routeFileStarted)
    {
        if (!r.recordOnly)
            RoomRouteLoadV106(r,node)
        if (!FileExist(file))
            return false
        IniRead, oldCount, %file%, %section%, Count, 0
        if (!RegExMatch(oldCount,"^\d+$") || oldCount>10000)
            return false
        oldSequence := "", lastNumber := -1
        Loop, %oldCount%
        {
            oldKey := "Room" . A_Index
            IniRead, oldValue, %file%, %section%, %oldKey%, MISSING
            if (!RegExMatch(oldValue,"^(\d+)\|(\d+),(\d+)$",oldRoom))
                return false
            lastNumber := oldRoom1+0
            oldSequence .= (oldSequence="" ? "" : "-") . lastNumber
        }
        r.routeFileStarted := true, r.routeStepCount := oldCount+0, r.routeSequence := oldSequence
        IniWrite, ROOM_CENTERS_V1, %file%, %section%, Format
        if (ErrorLevel)
        {
            r.routeFileStarted := false
            return false
        }
        if (r.recordOnly && oldCount>0 && lastNumber=node.routeNumber)
            return true
    }
    if (!FileExist(file) || r.routeStepCount>=10000)
        return false
    step := r.routeStepCount+1
    sequence := r.routeSequence . (r.routeSequence="" ? "" : "-") . node.routeNumber
    value := node.routeNumber . "|" . node.cx . "," . node.cy
    key := "Room" . step
    if (r.recordOnly)
    {
        IniRead, existingStepV140, %file%, %section%, %key%, MISSING
        IniRead, currentCountV140, %file%, %section%, Count, 0
        if (existingStepV140!="MISSING" || !RegExMatch(currentCountV140,"^\d+$") || currentCountV140+0!=r.routeStepCount)
        {
            if (!r.appendConflictShownV140)
            {
                r.appendConflictShownV140 := true
                ToolTipInfoV386("File map có số dòng không khớp. Không ghi đè tọa độ cũ; dừng lưu và kiểm tra file.")
                SetTimer, RemoveToolTip, -4000
            }
            return false
        }
    }
    IniWrite, %value%, %file%, %section%, %key%
    if (ErrorLevel)
    {
        AutoMonsterAttackLogV2("ROOM_ROUTE_SAVE_FAILED file=MAP_PROFILE room_entry=" . step,true)
        if (!r.routeFileErrorShown)
        {
            r.routeFileErrorShown := true
            ToolTipInfoV386("Không ghi được file phòng trong thư mục Map.")
            SetTimer, RemoveToolTip, -3000
        }
        return false
    }
    IniWrite, %sequence%, %file%, %section%, Sequence
    if (ErrorLevel)
        return false
    IniWrite, %step%, %file%, %section%, Count
    if (ErrorLevel)
        return false
    r.routeStepCount := step, r.routeSequence := sequence
    RoomExploreLogV89("ROOM_ROUTE_SAVED number=" . node.routeNumber . " step=" . step . " kind=" . kind . " xy=" . px . "," . py . " sequence=" . sequence)
    return true
}

RoomRouteLoadV106(r,startNode)
{
    file := RoomRouteFileV108(), section := "Route-" . startNode.level
    IniRead, count, %file%, %section%, Count, 0
    count := Min(10000,Max(0,count+0))
    steps := [], startIndex := 0
    Loop, %count%
    {
        key := "Room" . A_Index
        IniRead, value, %file%, %section%, %key%, MISSING
        fields := StrSplit(value,"|"), xy := fields.Length()>=2 ? StrSplit(fields[2],",") : []
        if (fields.Length()<2 || xy.Length()!=2 || !RegExMatch(fields[1],"^\d+$")
            || !RegExMatch(xy[1],"^\d+$") || !RegExMatch(xy[2],"^\d+$"))
            break
        steps.Push({number:fields[1]+0,x:xy[1]+0,y:xy[2]+0})
        if (!startIndex && fields[1]+0=startNode.routeNumber)
            startIndex := steps.Length()
    }
    if (startIndex && steps.Length()>startIndex)
    {
        r.routeReplay := steps, r.routeReplayIndex := startIndex+1, r.displayRow := startIndex
        RoomExploreLogV89("ROOM_ROUTE_REPLAY_START steps=" . steps.Length() . " next=" . r.routeReplayIndex . " room_number=" . startNode.routeNumber)
    }
}

RoomSkipBlockedCombatV115(r,reason)
{
    global coordRouteV16,monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44,coordNoTargetSinceV14
    node := r.nodes[r.current], oldIndex := r.routeReplayIndex
    if (IsObject(r.routeReplay) && IsObject(node))
    {
        if (r.routeReplayIndex<=r.routeReplay.Length() && r.routeReplay[r.routeReplayIndex].number=node.routeNumber)
            r.routeReplayIndex++
    }
    r.skipCombatRoom := r.current, r.replayWaitUntil := 0
    r.target := 0, r.goalUid := 0, r.goalKind := "", r.travelMs := 0
    r.forceReturn := false, r.backtracking := false, r.routeFallback := false
    monsterCombatUidV45 := 0, monsterRoadAreaV51 := false, monsterChaseV44 := false
    coordNoTargetSinceV14 := A_TickCount-250
    if (IsObject(coordRouteV16))
        coordRouteV16.escapeV84 := false, coordRouteV16.stuckProbe := false, coordRouteV16.bypass := false
    RoomExploreLogV89("ROOM_COMBAT_SKIP reason=" . reason . " room2=" . V92Hex(r.current)
        . " from_row=" . oldIndex . " next_row=" . r.routeReplayIndex . " action=NEXT_SAVED_ROOM no_target_lock=1 teleport=OFF")
}

RoomWalkBlockedV107(r,reason)
{
    global coordRouteV16, monsterRetryUntilV44, monsterCombatUidV45, monsterRoadAreaV51, monsterChaseV44
    failedRoom := r.target, failedUid := r.goalUid, wasReturning := r.backtracking
    if (r.savedRouteOnly)
    {
        if (failedUid)
        {
            RoomSkipBlockedCombatV115(r,reason)
            return
        }
        r.replayWaitUntil := A_TickCount+1000
        r.target := 0, r.goalUid := 0, r.goalKind := "", r.travelMs := 0
        r.forceReturn := false, r.backtracking := false, r.routeFallback := false
        monsterCombatUidV45 := 0, monsterRoadAreaV51 := false, monsterChaseV44 := false
        if (IsObject(coordRouteV16))
            coordRouteV16.escapeV84 := false, coordRouteV16.stuckProbe := false, coordRouteV16.bypass := false
        RoomExploreLogV89("ROOM_ROUTE_BLOCKED next_row=" . r.routeReplayIndex . " uid=" . failedUid
            . " reason=" . reason . " action=KEEP_SAVED_SEQUENCE teleport=OFF")
        return
    }
    if (failedUid)
    {
        if (!IsObject(monsterRetryUntilV44))
            monsterRetryUntilV44 := {}
        monsterRetryUntilV44[failedUid] := A_TickCount+30000
    }
    if (failedRoom && failedRoom!=r.current && !wasReturning)
        r.closedBranches[failedRoom] := true
    RoomRouteFailureV106(r)
    if (wasReturning)
        r.forceReturn := false
    r.target := 0, r.goalUid := 0, r.goalKind := "", r.travelMs := 0, r.backtracking := false
    monsterCombatUidV45 := 0, monsterRoadAreaV51 := false, monsterChaseV44 := false
    if (IsObject(coordRouteV16))
        coordRouteV16.escapeV84 := false, coordRouteV16.stuckProbe := false, coordRouteV16.bypass := false
    RoomExploreLogV89("ROOM_WALK_BLOCKED reason=" . reason . " teleport=OFF action=" . (wasReturning ? "RESCAN_OTHER_BRANCH" : "RETURN_ONE_ROOM")
        . " from=" . V92Hex(r.current) . " failed=" . V92Hex(failedRoom))
}

RoomRouteFailureV106(r)
{
    if (r.savedRouteOnly)
    {
        r.replayWaitUntil := A_TickCount+1000
        r.forceReturn := false, r.backtracking := false, r.routeFallback := false
        RoomExploreLogV89("ROOM_ROUTE_RETRY next_row=" . r.routeReplayIndex . " action=KEEP_SAVED_SEQUENCE")
        return
    }
    if (IsObject(r.routeReplay))
        RoomExploreLogV89("ROOM_ROUTE_REPLAY_INTERRUPTED next=" . r.routeReplayIndex . " action=RETURN_ONE_ROOM_THEN_NEW_BRANCH")
    r.routeReplay := false, r.forceReturn := true, r.routeFallback := true
}

RoomDisplayReachedV112(r,node,returning)
{
    if (!IsObject(node))
        return
    index := r.routeReplayIndex
    if (IsObject(r.routeReplay) && index<=r.routeReplay.Length() && r.routeReplay[index].number=node.routeNumber)
    {
        r.displayRow := index
        return
    }
    if (returning && !r.savedRouteOnly)
    {
        index := r.displayRow-1
        while (index>=1)
        {
            if (r.saved[index].roomNumber=node.routeNumber)
            {
                r.displayRow := index
                return
            }
            index--
        }
    }
}

RoomRouteReplayTickV106(r,room2,px,py,level)
{
    if (!IsObject(r.routeReplay))
        return false
    if (r.savedRouteOnly && A_TickCount<r.replayWaitUntil)
    {
        RoomWaitV90(r.pid,px,py,level)
        return true
    }
    Loop, 16
    {
        index := r.routeReplayIndex
        if (index>r.routeReplay.Length())
        {
            r.routeReplay := false
            RoomExploreLogV89("ROOM_ROUTE_REPLAY_END next=" . (r.savedRouteOnly ? "WAIT_AT_LAST_ROOM" : "EXPLORE_NEW_BRANCH"))
            return false
        }
        step := r.routeReplay[index], nextRoom := 0
        for address,node in r.nodes
            if (node.routeNumber=step.number)
            {
                nextRoom := address
                break
            }
        if (!nextRoom && r.savedRouteOnly)
        {
            RoomSetGoalV90(r,{x:step.x,y:step.y,uid:0},0,px,py,level,"REPLAY_SAVED_ROUTE")
            return true
        }
        if (!nextRoom || (!r.savedRouteOnly && r.closedBranches.HasKey(nextRoom)))
        {
            RoomRouteFailureV106(r)
            RoomExploreLogV89("ROOM_ROUTE_REPLAY_INVALID number=" . step.number . " action=RETURN_THEN_RESCAN")
            return false
        }
        if (nextRoom=room2)
        {
            r.routeReplayIndex++
            continue
        }
        RoomSetGoalV90(r,{x:step.x,y:step.y,uid:0},nextRoom,px,py,level,"REPLAY_SAVED_ROUTE")
        return true
    }
    return true
}

RoomExploreNextV89(h,r,current,px,py)
{
    if (r.savedRouteOnly)
        return 0
    node := r.nodes[current], best := 0, bestDist := 1.0e30
    if (IsObject(node))
    {
        for _,q in node.links
        {
            if (r.visited.HasKey(q) || r.closedBranches.HasKey(q) || (r.blocked.HasKey(q) && A_TickCount<r.blocked[q]))
                continue
            other := RoomExploreReadV89(h,q,r.level)
            if (!IsObject(other) || !other.r1)
                continue
            scan := RoomLiveGoalV90(h,other,px,py)
            if (scan.incomplete)
                continue
            aim := {x:other.cx,y:other.cy}
            distance := (aim.x-px)**2+(aim.y-py)**2
            if (distance<bestDist)
                best := q, bestDist := distance
        }
    }
    if (best)
    {
        r.backtracking := false
        return best
    }
    if (r.trail.Length()>1)
    {
        previous := r.trail[r.trail.Length()-1]
        r.closedBranches[current] := true
        r.backtracking := true
        RoomExploreLogV89("ROOM_BRANCH_CLOSED room2=" . V92Hex(current) . " return_to=" . V92Hex(previous.room)
            . " selection=SKIP_THIS_BRANCH_FOR_SESSION")
        RoomExploreLogV89("ROOM_BACKTRACK from=" . V92Hex(current) . " to=" . V92Hex(previous.room)
            . " recorded_xy=" . previous.x . "," . previous.y . " depth=" . r.trail.Length() . " reason=NO_NEW_REACHABLE_BRANCH")
        return previous.room
    }
    r.backtracking := false
    AutoMonsterAttackLogV2("ROOM_ROUTE_WAIT reason=NO_NEW_BRANCH_AT_START",true)
    return 0
}

RoomExploreUnitsV89(h,node)
{
    if (!node.r1)
        return
    RoomExploreLogV89("ROOM_UNITS room2=" . V92Hex(node.r2) . " " . RoomUnitsV19(h,node.r1))
    text := ""
    u := D2ReadU32(h,node.r1+0x74), seen := {}, n := 0
    while (u && n<128 && !seen.HasKey(u))
    {
        if (!MonsterBossProbeReadV1(h,u,0xEC,b))
            break
        seen[u] := true, n++
        typ := NumGet(b,0,"UInt"), cls := NumGet(b,4,"UInt"), uid := NumGet(b,12,"UInt"), mode := NumGet(b,16,"UInt"), path := NumGet(b,0x2C,"UInt")
        xy := "NA"
        if (MonsterBossProbeReadV1(h,path,0x20,p))
            xy := (typ=0 || typ=1) ? NumGet(p,2,"UShort") . "," . NumGet(p,6,"UShort") : NumGet(p,0x0C,"UInt") . "," . NumGet(p,0x10,"UInt")
        text .= A_Now . " tick=" . A_TickCount . " | ROOM_UNIT room2=" . V92Hex(node.r2) . " type=" . typ . " class=" . cls . " uid=" . uid . " mode=" . mode . " xy=" . xy . " excluded_pet=" . (typ=1 && MonsterClassExcludedV11(cls,h,u)) . "`r`n"
        u := NumGet(b,0xE8,"UInt")
    }
    if (text!="" && ManualLogActiveV81())
        ManualLogAppendV81(text,A_ScriptDir . "\Auto-GSF-Test-Phong.log")
}

RoomExploreTickV89(h,player,ByRef pb,pid,mode)
{
    global roomExploreV89, coordSavedV15, coordRouteV16, monsterCombatUidV45, xRunning, zRunning, gameItemActionOwner, manualLogStartV81, portalCastEveryV52
    r := roomExploreV89
    if (!IsObject(r))
        return false
    if (r.pid!=pid || mode=0 || mode=17 || (!r.manualReplay && !ManualLogActiveV81()))
    {
        stopReasonV99 := r.pid!=pid ? "GAME_PID_CHANGED" : (mode=0 || mode=17) ? "PLAYER_DEAD" : "LOG_NOT_ACTIVE"
        stopDetailV99 := stopReasonV99 . " player_mode=" . mode . " bound_pid=" . r.pid . " live_pid=" . pid
            . " log_active=" . ManualLogActiveV81() . " player=" . V92Hex(player)
            . " xy=" . NumGet(pb,2,"UShort") . "," . NumGet(pb,6,"UShort")
        AutoMonsterAttackLogV2("ROOM_TEST_STOP " . stopDetailV99)
        RoomExploreStopV89(stopDetailV99)
        return true
    }
    room1 := NumGet(pb,0x1C,"UInt"), room2 := room1 ? D2ReadU32(h,room1+0x10) : 0
    level := CoordLevelV14(h,room1), px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
    if (!room2 || !level)
        return true
    if (!r.level)
        r.level := level, r.player := player
    if (r.level!=level || r.player!=player)
    {
        RoomExploreStopV89("MAP_OR_PLAYER_CHANGED")
        return true
    }
    if (A_TickCount-r.lastScan>=1000 || r.current!=room2)
    {
        r.lastScan := A_TickCount
        node := RoomExploreDiscoverV89(h,r,room2)
        if (!IsObject(node))
            return true
        dumpUnits := !r.lastUnits || A_TickCount-r.lastUnits>=5000 || r.current!=room2
        for _,q in node.links
        {
            if (r.nodes.Count()>=512)
                break
            neighbour := RoomExploreDiscoverV89(h,r,q)
            if (dumpUnits && IsObject(neighbour) && neighbour.r1)
                RoomExploreUnitsV89(h,neighbour)
        }
        if (dumpUnits)
        {
            RoomExploreUnitsV89(h,node)
            r.lastUnits := A_TickCount
        }
    }
    if (r.current!=room2)
    {
        foundTrailV104 := 0
        for trailIndexV104,trailStepV104 in r.trail
            if (trailStepV104.room=room2)
                foundTrailV104 := trailIndexV104
        if (foundTrailV104)
        {
            while (r.trail.Length()>foundTrailV104)
                r.trail.Pop()
        }
        else
            r.trail.Push({room:room2,x:px,y:py})
        RoomRouteReachedV105(r,r.nodes[room2],px,py,foundTrailV104 ? "RETURN" : "ENTER")
        r.backtracking := false
        RoomExploreLogV89("ROOM_TRAIL_REACHED room2=" . V92Hex(room2) . " xy=" . px . "," . py . " depth=" . r.trail.Length())
        r.current := room2, r.visited[room2] := true
        if (r.skipCombatRoom && IsObject(r.routeReplay) && r.routeReplayIndex<=r.routeReplay.Length()
            && r.routeReplay[r.routeReplayIndex].number=r.nodes[room2].routeNumber)
            r.skipCombatRoom := 0
        if (r.savedRouteOnly)
        {
            RoomDisplayReachedV112(r,r.nodes[room2],foundTrailV104!=0)
            CoordBoxRefreshV15(true)
        }
        RoomExploreLogV89("ROOM_ENTER room2=" . V92Hex(room2) . " player=" . px . "," . py . " discovered=" . r.nodes.Count() . " visited=" . r.visited.Count() . " reached_target=" . (r.target=room2))
        r.target := 0, r.goalUid := 0, r.travelMs := 0
    }
    if (r.trail.Length())
    {
        trailTailV104 := r.trail[r.trail.Length()]
        trailTailV104.x := px, trailTailV104.y := py
    }
    now := A_TickCount, elapsed := r.lastTick ? Min(500,now-r.lastTick) : 0
    r.lastTick := now
    if (r.target && !monsterCombatUidV45 && !xRunning && !zRunning && gameItemActionOwner="")
        r.travelMs += elapsed
    if (r.target && !IsObject(RoomExploreReadV89(h,r.target,level)))
    {
        RoomExploreLogV89("ROOM_TARGET_INVALID room2=" . V92Hex(r.target))
        r.target := 0
    }
    if (r.target && r.target!=room2 && r.travelMs>=15000)
    {
        RoomExploreLogV89("ROOM_MOVE_TIMEOUT room2=" . V92Hex(r.target) . " player=" . px . "," . py . " result=NOT_ENTERED exclude_ms=30000")
        if (!r.goalUid && !r.backtracking && !r.savedRouteOnly)
            r.closedBranches[r.target] := true
        if (!r.goalUid)
            RoomRouteFailureV106(r)
        r.blocked[r.target] := now+30000, r.target := 0, r.goalUid := 0
    }
    if (r.pendingClearRoom)
    {
        RoomClearBuffBeginV96(h,player,pid,r,r.pendingClearRoom)
        return true
    }
    for clearedRoomV101,_ in r.visited
    {
        if (clearedRoomV101!=room2 || r.skipCombatRoom=room2)
            continue
        clearNodeV101 := RoomExploreReadV89(h,clearedRoomV101,level)
        if (!IsObject(clearNodeV101) || !clearNodeV101.r1)
            continue
        clearScanV101 := RoomLiveGoalV90(h,clearNodeV101,px,py)
        if (clearedRoomV101=room2)
            AutoMonsterAttackLogV2("ROOM_CLEAR_CHECK room2=" . V92Hex(room2) . " live=" . clearScanV101.count
                . " incomplete=" . clearScanV101.incomplete . " counted=" . r.clearBuffDone.HasKey(room2),true)
        if (clearScanV101.incomplete)
            continue
        if (clearScanV101.count)
            continue
        if (!r.clearBuffDone.HasKey(clearedRoomV101))
        {
            r.clearBuffDone[clearedRoomV101] := true
            r.roomPortalCount++
            roomThresholdV105 := Max(1,portalCastEveryV52)
            AutoMonsterAttackLogV2("ROOM_CLEAR_COUNT source_room=" . V92Hex(clearedRoomV101)
                . " count=" . r.roomPortalCount . " required=" . roomThresholdV105 . " setting=RouteCastEvery")
            if (r.roomPortalCount>=roomThresholdV105)
            {
                r.pendingClearRoom := clearedRoomV101
                AutoMonsterAttackLogV2("ROOM_PORTAL_THRESHOLD count=" . r.roomPortalCount . " required=" . roomThresholdV105
                    . " next=ORIGINAL_PORTAL_BUFF_PIPELINE")
                RoomClearBuffBeginV96(h,player,pid,r,clearedRoomV101)
                return true
            }
        }
    }
    live := RoomAllLiveV93(h,r,room1,px,py)
    if (r.savedRouteOnly && r.skipCombatRoom!=room2 && IsObject(live) && !live.incomplete && live.count && !IsObject(live.best))
        RoomSkipBlockedCombatV115(r,"NO_ELIGIBLE_CURRENT_ROOM_TARGET")
    if (r.skipCombatRoom=room2)
        live := {count:0,incomplete:false,best:false}
    if (!IsObject(live) || live.incomplete)
        return true
    if (r.forceReturn && !r.savedRouteOnly)
    {
        r.forceReturn := false
        if (r.trail.Length()>1)
        {
            previousRouteV106 := r.trail[r.trail.Length()-1]
            r.backtracking := true, r.target := previousRouteV106.room
            r.closedBranches[room2] := true
        }
    }
    if (!r.savedRouteOnly && r.backtracking && r.target && r.trail.Length()>1)
    {
        trailReturnV104 := r.trail[r.trail.Length()-1]
        RoomSetGoalV90(r,{x:trailReturnV104.x,y:trailReturnV104.y,uid:0},trailReturnV104.room,px,py,level,"RETURN_RECORDED_TRAIL")
        return false
    }
    if (!live.count && RoomRouteReplayTickV106(r,room2,px,py,level))
        return false
    if (!live.count && r.savedRouteOnly && !r.routeFallback && !r.forceReturn && !r.backtracking && !IsObject(r.routeReplay))
    {
        RoomWaitV90(pid,px,py,level)
        return false
    }
    if (live.count)
    {
        if (r.cleared.HasKey(room2))
            r.cleared.Delete(room2)
        if (IsObject(live.best))
        {
            RoomSetGoalV90(r,live.best,live.best.room2,px,py,level,"NEAREST_LOADED_MONSTER")
            if ((live.best.x-px)**2+(live.best.y-py)**2<=25 && IsObject(coordRouteV16.escapeV84))
                coordRouteV16.escapeV84 := false, coordRouteV16.stuckProbe := false, coordRouteV16.bypass := false
        }
        else
            RoomWaitV90(pid,px,py,level)
    }
    else
    {
        if (!r.cleared.HasKey(room2))
        {
            r.cleared[room2] := true
            RoomExploreLogV89("LOADED_ROOMS_CLEAR current=" . V92Hex(room2) . " live_monsters=0 next=UNVISITED_ROOM")
        }
        if (r.goalUid || r.target=room2)
            r.target := 0, r.goalUid := 0
        next := r.target ? r.target : RoomExploreNextV89(h,r,room2,px,py)
        node := next ? RoomExploreReadV89(h,next,level) : false
        otherLive := IsObject(node) && node.r1 ? RoomLiveGoalV90(h,node,px,py,r.goalUid) : false
        if (IsObject(otherLive) && !otherLive.incomplete)
        {
            if (r.backtracking && r.trail.Length()>1)
            {
                returnStepV104 := r.trail[r.trail.Length()-1]
                goal := {x:returnStepV104.x,y:returnStepV104.y,uid:0,source:"RECORDED_PREVIOUS_ROOM_POSITION"}
                kindV104 := "RETURN_RECORDED_TRAIL"
            }
            else
            {
                goal := {x:node.cx,y:node.cy,uid:0,source:"ROOM_CENTER"}
                kindV104 := "NEXT_ROOM_ENTRY"
            }
            RoomSetGoalV90(r,goal,next,px,py,level,kindV104)
        }
        else
            RoomWaitV90(pid,px,py,level)
    }
    part := Floor((A_TickCount-manualLogStartV81)/10000)+1
    if (r.lastPart!=part)
    {
        r.lastPart := part
        RoomExploreLogV89("ROOM_SESSION_SNAPSHOT part=" . part . " current=" . V92Hex(room2) . " player=" . px . "," . py . " target=" . V92Hex(r.target) . " goal_uid=" . r.goalUid . " goal_kind=" . r.goalKind)
        for trailIndexV104,trailStepV104 in r.trail
            RoomExploreLogV89("ROOM_TRAIL_SNAPSHOT index=" . trailIndexV104 . " room2=" . V92Hex(trailStepV104.room)
                . " xy=" . trailStepV104.x . "," . trailStepV104.y)
        for _,node in r.nodes
            RoomExploreLogV89("ROOM_GEOMETRY room2=" . V92Hex(node.r2) . " map=" . node.level . " rect=" . node.x . "," . node.y . "," . node.w . "," . node.h . " visited=" . r.visited.HasKey(node.r2))
    }
    return false
}

RoomLiveGoalV90(h,node,px,py,preferred := 0)
{
    global monsterRetryUntilV44
    result := {best:false,count:0,incomplete:false,floor:false}
    u := node.r1 ? D2ReadU32(h,node.r1+0x74) : 0, seen := {}, n := 0, score := 1.0e30, floorScore := 1.0e30
    while (u)
    {
        if (n>=2048 || seen.HasKey(u) || !MonsterBossProbeReadV1(h,u,0xEC,b))
        {
            result.incomplete := true
            break
        }
        seen[u] := true, n++
        typ := NumGet(b,0,"UInt"), cls := NumGet(b,4,"UInt"), uid := NumGet(b,12,"UInt"), mode := NumGet(b,16,"UInt"), path := NumGet(b,0x2C,"UInt")
        isMonster := typ=1 && !MonsterClassExcludedV11(cls,h,u)
        alive := isMonster && mode!=0 && mode!=12
        pathRead := (isMonster || typ=2) && MonsterBossProbeReadV1(h,path,0x20,p)
        if (isMonster && pathRead)
        {
            actualRoom1 := NumGet(p,0x1C,"UInt")
            actualRoom2 := actualRoom1 ? D2ReadU32(h,actualRoom1+0x10) : 0
            if (!actualRoom2)
            {
                result.incomplete := alive ? true : result.incomplete
                alive := false, isMonster := false
            }
            else if (actualRoom2!=node.r2)
                alive := false, isMonster := false
        }
        if (alive)
            result.count++
        if ((isMonster || typ=2) && pathRead)
        {
            x := typ=1 ? NumGet(p,2,"UShort") : NumGet(p,0x0C,"UInt")
            y := typ=1 ? NumGet(p,6,"UShort") : NumGet(p,0x10,"UInt")
            if (x>=node.x && x<node.x+node.w && y>=node.y && y<node.y+node.h)
            {
                dist := (x-px)**2+(y-py)**2
                if (alive && uid && (!monsterRetryUntilV44.HasKey(uid) || A_TickCount>=monsterRetryUntilV44[uid]))
                {
                    rank := dist
                    if (rank<score)
                        result.best := {x:x,y:y,uid:uid,unit:u,class:cls}, score := rank
                }
                else if (!alive && dist<floorScore)
                    result.floor := {x:x,y:y,uid:0,source:typ=1 ? "CORPSE_POSITION" : "OBJECT_POSITION"}, floorScore := dist
            }
        }
        else if (alive)
            result.incomplete := true
        u := NumGet(b,0xE8,"UInt")
    }
    return result
}


RoomSetGoalV90(r,goal,room2,px,py,level,kind)
{
    global coordSavedV15, coordRouteV16, monsterRetryUntilV44
    same := r.target=room2 && r.goalUid=goal.uid && r.goalKind=kind && coordSavedV15.Length()=2
    if (same)
    {
        if (!goal.uid && kind="NEXT_ROOM_ENTRY")
            return
        old := coordSavedV15[2]
        if ((old.x-goal.x)**2+(old.y-goal.y)**2<9)
        {
            if (coordRouteV16.phase="DONE" && (px-goal.x)**2+(py-goal.y)**2>25)
            {
                coordSavedV15[2] := {x:goal.x,y:goal.y,level:level}
                coordRouteV16.anchor := 1, coordRouteV16.next := 2, coordRouteV16.phase := "NEXT"
                coordRouteV16.closestGoalDistance := -1, coordRouteV16.lastDispatch := 0
            }
            return
        }
        coordSavedV15[2] := {x:goal.x,y:goal.y,level:level}
        if (coordRouteV16.phase="DONE" && (px-goal.x)**2+(py-goal.y)**2>25)
            coordRouteV16.anchor := 1, coordRouteV16.next := 2, coordRouteV16.phase := "NEXT"
        coordRouteV16.closestGoalDistance := -1
    }
    else
    {
        coordSavedV15 := [{x:px,y:py,level:level},{x:goal.x,y:goal.y,level:level}]
        savedRetry := monsterRetryUntilV44
        CoordRouteResetV16()
        monsterRetryUntilV44 := savedRetry
        coordRouteV16.pid := r.pid, coordRouteV16.anchor := 1, coordRouteV16.next := 2, coordRouteV16.yellow := 1, coordRouteV16.phase := "NEXT"
        r.travelMs := 0
    }
    r.target := room2, r.goalUid := goal.uid, r.goalKind := kind
    RoomExploreLogV89("ROOM_GO target=" . V92Hex(room2) . " aim=" . goal.x . "," . goal.y . " goal_uid=" . goal.uid . " method=" . kind . " source=" . (goal.uid ? "LIVE_MONSTER_COORDINATES" : goal.source) . " reached=UNCONFIRMED")
}
