RoomRecordPrepareV258()
{
    global
    roomRecordPidV259 := SigBackgroundBindV179() ? backgroundPidV63 : 0
    mapButtonStartV172 := false,mapFarmStartPendingV170 := false
    SetTimer, MapButtonStartTimerV172, Off
    SetTimer, MapFarmStartV170, Off
    if (FarmControlRunningV186() || IsObject(coordGoV59) || farmResumeArmedV70 || farmStartRetryV237)
        FarmStopV124("RECORD_ROUTE_BUTTON")
    FarmPauseReleaseV256("RECORD_ROUTE_BUTTON")
    farmStopMoveV124 := false,coordGoV59 := false
    SetTimer, FarmStopMoveTimerV124, Off
    SetTimer, CoordGoTimerV59, Off
    return true
}

RoomRecordLevelV259(pid)
{
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return 0
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return 0
        
        mode := player ? D2ReadU32(h,player+0x10) : 0
        if (mode = 0 || mode = 17)
            return 0
            
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        return level
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

RoomMapButtonNameV22(level)
{
    global roomMapLastButtonV22,farmControlOwnerV186,libScrollTierV290
    liveGroupV412 := MapRouteGroupV412("",level)
    name := liveGroupV412!="MAP" ? liveGroupV412 : roomMapLastButtonV22
    if (name="")
    {
        if (level=270)
            name := "SCOS"
        else if (level=150)
            name := "CYC"
        else if (level=148)
            name := "UBU"
        else if (level=146)
            name := "TRAN"
        else if (level=168 || level=183 || level=184 || level=185)
            name := "CAIN"
        else if (level>=263 && level<=266)
            name := libScrollTierV290 ? libScrollTierV290 : "LIB"
        else
            name := farmControlOwnerV186
    }
    if (name="LIB")
        name := libScrollTierV290 ? libScrollTierV290 : "LIB"
    else if (name="M3000")
        name := "3000"
    else if (name="NAO")
        name := "FAUT"
    name := RegExReplace(name,"[\\/:*?""<>|\r\n]","-")
    name := RTrim(Trim(name)," .")
    return name!="" ? name : "MAP"
}

RoomMapNamedNumberV293(baseName)
{
    global routeMapsV21
    escaped := RegExReplace(baseName,"([\\.\*\+\?\[\]\{\}\(\)\^\$\|])","\$1")
    pattern := "i)^" . escaped . "(?:-Map\d+)?-(\d+)(?:-Map\d+)?$"
    highest := 0
    for _,map in routeMapsV21
        if (RegExMatch(map.name,pattern,m))
            highest := Max(highest,m1+0)
    nameOwnerV412 := "",nameLevelV412 := 0
    if (RegExMatch(baseName,"i)^([^-]+)(?:-Map(\d+))?",baseGroupV412))
        nameOwnerV412 := baseGroupV4121,nameLevelV412 := baseGroupV4122+0
    Loop, Files, % MapRouteDirectoryV408(nameOwnerV412,nameLevelV412) . "\*.ini"
    {
        SplitPath, A_LoopFileName,,,, stem
        if (RegExMatch(stem,pattern,m))
            highest := Max(highest,m1+0)
    }
    return baseName . "-" . (highest+1)
}


RoomMapUniqueNameV261(baseName,directory,ownFile := "")
{
    global routeMapsV21
    name := baseName,suffix := 1
    Loop
    {
        file := directory . "\" . name . ".ini"
        taken := FileExist(file) && file!=ownFile
        if (file!=ownFile)
            for _,map in routeMapsV21
                if (map.name=name)
                    taken := true
        if (!taken)
            return name
        suffix++,name := baseName . "-" . suffix
    }
}


FonEditBeginV414()
{
    global fonEditDepthV414,fonEditPreviousV414,coordTrackingEnabledV409,autoMapTrackingV10
    if (!fonEditDepthV414)
        fonEditPreviousV414 := coordTrackingEnabledV409
    fonEditDepthV414 := (fonEditDepthV414+0)+1
    coordTrackingEnabledV409 := false,autoMapTrackingV10 := false
    SetTimer, CoordCurrentTimerV15, Off
    SetTimer, RoomMapListTimerV110, Off
    GuiControl, 1:, CoordTrackingButtonV409, F-OFF
}

FonEditEndV414()
{
    global fonEditDepthV414,fonEditPreviousV414,coordTrackingEnabledV409,autoMapTrackingV10
    fonEditDepthV414 := Max(0,fonEditDepthV414-1)
    if (fonEditDepthV414)
        return
    SetTimer, RoomMapListTimerV110, 2000
    if (fonEditPreviousV414)
        FonTrackingEnableV410()
    else
    {
        coordTrackingEnabledV409 := false,autoMapTrackingV10 := false
        SetTimer, CoordCurrentTimerV15, Off
        GuiControl, 1:, CoordTrackingButtonV409, F-OFF
    }
}

BOCoordinateBlockedV471()
{
    global scosEntryV162,farmControlOwnerV186,mapWorkflowV185
    if (IsObject(scosEntryV162) && scosEntryV162.map="BO")
        return scosEntryV162.boStageV413!=4
    return farmControlOwnerV186="BO" && IsObject(mapWorkflowV185) && mapWorkflowV185.stage=3
}

BOCoordinateOffV471()
{
    return false
}

FonManualLoadV758()
{
    global coordCursorSnapshotV390,coordCurrentReadAtV132
    if (!FonTrackingEnableV410())
        return false
    coordCursorSnapshotV390 := false,coordCurrentReadAtV132 := 0
    PortalLogWriteV66("FON_MANUAL_REFRESH next=READ_LIVE_MAP tracking=ON")
    ok := FonLoadMapV382("MANUAL")
    if (ok)
    {
        CoordCurrentReadV15()
        CoordBoxRefreshV15(true)
    }
    return ok
}

FonTrackingEnableV410()
{
    global coordTrackingEnabledV409,autoMapTrackingV10,fonEditDepthV414
    if (fonEditDepthV414)
    {
        PortalLogWriteV66("FON_ENABLE_BLOCKED reason=ROUTE_EDIT depth=" . fonEditDepthV414,"FON_EDIT_BLOCKED",2000)
        return false
    }
    coordTrackingEnabledV409 := true,autoMapTrackingV10 := true
    GuiControl, 1:, CoordTrackingButtonV409, F-ON
    SetTimer, CoordCurrentTimerV15, 250
    return true
}

FonEnsureLiveV410(pid := 0)
{
    global farmControlOwnerV186,backgroundPidV63,scosEntryV162
    if (BOCoordinateBlockedV471())
        return BackgroundValidV63()
    if (!pid)
        pid := backgroundPidV63 ? backgroundPidV63 : CoordDisplayGamePidV1()
    level := pid ? RoomRecordLevelV259(pid) : 0
    if (BossSearchActiveV430(pid))
        return BackgroundValidV63() && BossSearchIdentityV430(pid,level)
    if (farmControlOwnerV186="BO")
    {
        if (!BackgroundValidV63() || pid!=backgroundPidV63)
            return false
        if (!IsObject(scosEntryV162) || scosEntryV162.phase!="FARM")
            return true
    }
    return pid && level ? Stage2MapWaitV381(pid,level) : false
}

Map263AutoLoadObserveV263(pid,level,x,y,levelPtrV395 := 0)
{
    static lastAttemptKeyV841 := "",nextAttemptAtV841 := 0
    global farmGD2TestV644
    if (LibFarmPinMatchesV2026(pid,level))
        return LibFarmPinRestoreV2026(pid,level,levelPtrV395)
    if (IsObject(farmGD2TestV644))
        return FarmGD2TestReadyV644(pid,level)

    if (CainCaveLiveModeV506(pid,level))
        return true
    global currentProfile,routeMapIdV21,coordSavedV15,coordTrackingEnabledV409
        global coordMapReadyV381,coordMapStateV381,mapLoadFailureV402,routePreviewV401,fonFirstLoadV763
    if (!coordTrackingEnabledV409 || !pid || !level || !x || !y || !levelPtrV395)
        return false
    if (BossSearchOwnsMapV430(pid,level))
        return true
    attemptKeyV841 := pid . "|" . currentProfile . "|" . level . "|" . levelPtrV395
    if (lastAttemptKeyV841!=attemptKeyV841)
        lastAttemptKeyV841 := attemptKeyV841,nextAttemptAtV841 := 0
if (!fonFirstLoadV763)
{
    fonFirstLoadV763 := true
    ; Re-enabling F-ON on the SAME map must keep the INI and yellow row.
    sameLoadedV845 := coordMapReadyV381 && IsObject(coordMapStateV381)
        && coordMapStateV381.loaded && coordMapStateV381.pid=pid
        && coordMapStateV381.level=level && coordMapStateV381.profile=currentProfile
        && coordMapStateV381.levelPtrV395=levelPtrV395
        && coordMapStateV381.mapId=routeMapIdV21
        && IsObject(coordSavedV15) && coordSavedV15.Length()
        && coordSavedV15[1].level=level
    if (sameLoadedV845)
        return true
    nextAttemptAtV841 := A_TickCount+1300
    return FonLoadMapV382("FON_FIRST",pid,level,x,y)
}
key := pid . "|" . currentProfile . "|" . level
    file := RoomProfileFileV108(currentProfile,routeMapIdV21)
    stampOK := MapFileStampReadV398(file,stamp)
    identityLive := IsObject(coordMapStateV381) && coordMapStateV381.loaded
        && coordMapStateV381.key=key && coordMapStateV381.levelPtrV395=levelPtrV395
        && coordMapStateV381.mapId=routeMapIdV21 && IsObject(coordSavedV15)
        && coordSavedV15.Length() && coordSavedV15[1].level=level
    ; Không giữ route cũ khi file bị sửa: phải đọc lại các điểm và bố cục.
    if (identityLive && (!stampOK || coordMapStateV381.fileV10!=file
        || coordMapStateV381.fileStampV10!=stamp))
    {
        coordMapReadyV381 := false
        if (A_TickCount<nextAttemptAtV841)
            return false
        nextAttemptAtV841 := A_TickCount+1300
        PortalLogWriteV66("FON_AUTO_RELOAD cause=ROUTE_FILE_CHANGED level=" . level)
        return FonLoadMapV382("AUTO_FILE_CHANGED",pid,level,x,y)
    }
    if (identityLive && !FarmReviveTownLevelV295(level)
        && !(level=39 || level=183 || level=184 || level=263 || level=241 || level=270)
        && coordMapStateV381.HasKey("layoutV841") && coordMapStateV381.layoutV841!=""
        && A_TickCount-coordMapStateV381.layoutCheckedAtV841>=2500)
    {
        ; V845: a partial Room2 read is NOT evidence of a different map.
        ; Keep the valid route/yellow watcher; reload only for a confirmed change.
        coordMapStateV381.layoutCheckedAtV841 := A_TickCount
        checkGeometryV841 := MapRoomLayoutReadV270(pid,level)
        if (!IsObject(checkGeometryV841) || checkGeometryV841.partial)
            PortalLogWriteV66("FON_LAYOUT_VERIFY_WAIT level=" . level . " loaded_map=KEPT", "FON_VERIFY_WAIT",5000)
        else if (checkGeometryV841.layout!=coordMapStateV381.layoutV841
            || checkGeometryV841.levelPtr!=levelPtrV395)
        {
            coordMapReadyV381 := false
            PortalLogWriteV66("FON_AUTO_RELOAD cause=ROOM_LAYOUT_CHANGED level=" . level)
            return FonLoadMapV382("AUTO_LAYOUT_CHANGE",pid,level,x,y)
        }
    }
    if (identityLive && coordMapReadyV381)
        return true
    coordMapReadyV381 := false
    if (A_TickCount<nextAttemptAtV841)
        return false
    nextAttemptAtV841 := A_TickCount+1300
    mapLoadFailureV402 := false,routePreviewV401 := false
    return FonLoadMapV382("AUTO_LEVEL_CHANGE",pid,level,x,y)
}

FonLoadErrorShowV385(text)
{
    global fonLoadErrorV385
    fonLoadErrorV385 := {text:text, shownAt:A_TickCount}
    SetTimer, FonLoadErrorFollowV385, 50
}

FonLoadErrorHideV385()
{
    global fonLoadErrorV385
    fonLoadErrorV385 := false
    SetTimer, FonLoadErrorFollowV385, Off
    ToolTip,,,, 5
}

FonLoadErrorFollowV385:
FonLoadErrorTickV385()
return

FonLoadErrorTickV385()
{
    global fonLoadErrorV385
    if (!IsObject(fonLoadErrorV385))
    {
        SetTimer, FonLoadErrorFollowV385, Off
        ToolTip,,,, 5
        return
    }
    if (A_TickCount-fonLoadErrorV385.shownAt>=800
        && (A_TimeIdlePhysical<300 || GetKeyState("LButton","P") || GetKeyState("RButton","P")))
    {
        FonLoadErrorHideV385()
        return
    }
    mouseMode := A_CoordModeMouse, tipMode := A_CoordModeToolTip
    CoordMode, Mouse, Screen
    CoordMode, ToolTip, Screen
    try
    {
        MouseGetPos, mx, my
        ToolTipInfoV386(fonLoadErrorV385.text, "mx+20", "my+20", 5)
    }
    finally
    {
        CoordMode, Mouse, %mouseMode%
        CoordMode, ToolTip, %tipMode%
    }
}
CoordMapUnavailableV381()
{
    global coordMapReadyV381,coordMapStateV381,coordMapAcceptedV381,coordCurrentLevelV400
    coordCurrentLevelV400 := 0
    coordMapReadyV381 := false,coordMapStateV381 := false,coordMapAcceptedV381 := false
}

FarmStartRowV394()
{
    global farmGD2TestV644
    if (IsObject(farmGD2TestV644) && farmGD2TestV644.starting)
        return farmGD2TestV644.row
    global scosEntryV162,coordRouteV16
    if (IsObject(scosEntryV162.commonRouteV3) && IsObject(scosEntryV162.commonRouteV3.pointsV724))
    {
        c := scosEntryV162.commonRouteV3
        return IsObject(coordRouteV16) && coordRouteV16.yellow>=1 ? coordRouteV16.yellow : c.startRowV724
    }
    global autoMapTrackingV10,coordYellowRowV350,coordSavedV15
    if (!IsObject(coordSavedV15) || !coordSavedV15.Length())
        return 0
    return coordYellowRowV350>=1 && coordYellowRowV350<=coordSavedV15.Length()
        ? coordYellowRowV350 : 1
}

Stage2RoomReplayReleaseV11()
{
    global roomExploreV89
    if (IsObject(roomExploreV89) && roomExploreV89.savedRouteOnly)
        RoomExploreEndV89("STANDARD_GD2_NEW_LOADED_ROUTE")
}

Stage2MapRequestV381(force := false)
{
    global farmControlOwnerV186
    pid := CoordDisplayGamePidV1()
    if (BossSearchActiveV430(pid))
        return BossSearchIdentityV430(pid,RoomRecordLevelV259(pid))
    level := pid ? RoomRecordLevelV259(pid) : 0
    if (!pid || !level)
        return false
    return Stage2MapWaitV381(pid,level,true)
}

Stage2StartWaitTimerV381:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    SetTimer, Stage2StartWaitTimerV381, Off
    return
}
if (!stage2StartPendingV381 || !autoMonsterAttackOn)
{
    stage2StartPendingV381 := false
    SetTimer, Stage2StartWaitTimerV381, Off
    return
}
if (!BackgroundValidV63() || !Stage2MapRequestV381())
    return
stage2StartPendingV381 := false
SetTimer, Stage2StartWaitTimerV381, Off
Gosub, AutoMonsterAttackToggle
if (farmControlOwnerV186="CAIN" && autoMonsterAttackOn && !IsObject(scosEntryV162))
    CainStage2AttachV379()
return

Stage2MapWaitV381(pid,level,force := false)
{
    global farmGD2TestV644
    if (IsObject(farmGD2TestV644))
        return FarmGD2TestReadyV644(pid,level)
    if (FarmCommonRouteActiveV3(pid,level))
        return FarmCommonRouteReadyV3(pid,level)

    if (CainCaveLiveModeV506(pid,level))
        return IsObject(MapLiveIdentityV399(pid,level))
    if (BOCoordinateBlockedV471())
        return BackgroundValidV63() && level>0
    global farmStartChoiceV2
    global currentProfile,routeMapIdV21,coordSavedV15,coordRouteV16,farmLoadedMapV56,coordMapSerialV381
    global coordMapStateV381,coordMapReadyV381,stage2MapFileV14
    global mapRunResumeV210,coordRunSelectedV210,farmStage2DoneV372,coordMoveDoneV14
    global farmControlOwnerV186
    if (BossSearchActiveV430(pid,level))
    {
        if (BossSearchIdentityV430(pid,level))
            return true
        return MapLoadFailedStopV397("BOSS_SEARCH_LIVE_MAP_READ_FAILED")
    }
    if (IsObject(farmStartChoiceV2) && farmStartChoiceV2.reloadPending)
        force := true
    baseV14 := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    hV14 := baseV14 ? D2OpenProcess(pid) : 0
    if (!hV14)
        return false
    priorCriticalV14 := A_IsCritical
    Critical, On
    try
    {
        playerV14 := D2ReadU32(hV14,baseV14+0x11BBFC)
        pathV14 := playerV14 ? D2ReadU32(hV14,playerV14+0x2C) : 0
        if (!pathV14 || !MonsterBossProbeReadV1(hV14,pathV14,0x20,pbV14))
            return false
        liveLevelV14 := CoordLevelV14(hV14,NumGet(pbV14,0x1C,"UInt"))
        room2V14 := D2ReadU32(hV14,NumGet(pbV14,0x1C,"UInt")+0x10)
        levelPtrV14 := room2V14 ? D2ReadU32(hV14,room2V14+0x58) : 0
        xV14 := NumGet(pbV14,2,"UShort"),yV14 := NumGet(pbV14,6,"UShort")
        if (!liveLevelV14 || liveLevelV14!=level || !levelPtrV14 || !xV14 || !yV14)
            return false
        if (LibFarmPinMatchesV2026(pid,level)
            && !LibFarmPinRestoreV2026(pid,level,levelPtrV14))
            return false
        if (LibFarmPinMatchesV2026(pid,level))
            force := false  ; Resume: dung cac diem da khoa, chi theo dong vang.
        if (!coordMapReadyV381 || !IsObject(coordMapStateV381) || !coordMapStateV381.loaded
            || coordMapStateV381.key!=pid . "|" . currentProfile . "|" . level
            || coordMapStateV381.mapId!=routeMapIdV21
            || coordMapStateV381.levelPtrV395!=levelPtrV14
            || !IsObject(coordSavedV15) || !coordSavedV15.Length()
            || coordSavedV15[1].level!=level)
            return false
        if (IsObject(farmStartChoiceV2))
        {
            FarmStartApplyYellowV2()
            farmStartChoiceV2.reloadPending := false
        }
        newMapV14 := !IsObject(stage2MapFileV14) || stage2MapFileV14.pid!=pid
            || stage2MapFileV14.profile!=currentProfile || stage2MapFileV14.level!=level
            || stage2MapFileV14.levelPtr!=levelPtrV14 || stage2MapFileV14.mapId!=routeMapIdV21
        newRouteV14 := force || newMapV14 || stage2MapFileV14.serial!=coordMapSerialV381
        if (newRouteV14)
        {
            rowV396 := FarmStartRowV394()
            Stage2RoomReplayReleaseV11()
            CoordRouteResetV16()
            mapRunResumeV210 := false,coordRunSelectedV210 := false
            farmStage2DoneV372 := false,coordMoveDoneV14 := false
            stage2MapFileV14 := {pid:pid,profile:currentProfile,level:level
                ,levelPtr:levelPtrV14,mapId:routeMapIdV21,serial:coordMapSerialV381}
            coordRouteV16.pid := pid,coordRouteV16.startLevel := level
            coordRouteV16.resumeRowV210 := rowV396,coordRouteV16.startAtYellowV367 := true
            coordRouteV16.yellow := rowV396
            PortalLogWriteV66("STAGE2_ROUTE_NEW level=" . level . " map=" . routeMapIdV21
                . " yellow=" . rowV396 . " source=FON_LIVE old_progress=DISCARDED")
        }
        if (!IsObject(coordSavedV15) || !coordSavedV15.Length() || coordSavedV15[1].level!=level)
            return false
        if (!IsObject(coordRouteV16) || coordRouteV16.pid!=pid || coordRouteV16.startLevel!=level
            || (coordRouteV16.HasKey("mapIdV396") && coordRouteV16.mapIdV396!=routeMapIdV21)
            || (coordRouteV16.HasKey("loadedSerialV11") && coordRouteV16.loadedSerialV11!=coordMapSerialV381))
        {
            rowV396 := FarmStartRowV394()
            CoordRouteResetV16()
            coordRouteV16.pid := pid,coordRouteV16.startLevel := level
            coordRouteV16.resumeRowV210 := rowV396,coordRouteV16.startAtYellowV367 := true
            coordRouteV16.yellow := rowV396
            PortalLogWriteV66("STAGE2_ROUTE_BEGIN level=" . level . " row=" . rowV396 . " source=FRESH_FILE")
        }
        coordRouteV16.mapIdV396 := routeMapIdV21
        coordRouteV16.loadedSerialV11 := coordMapSerialV381
        farmLoadedMapV56 := {pid:pid,profile:currentProfile,mapId:routeMapIdV21,level:level}
        return true
    }
    finally
    {
        DllCall("CloseHandle","Ptr",hV14)
        Critical, %priorCriticalV14%
    }
}

Ticket130ButtonV265:
if (ticket130BusyV265)
{
    sigCancelV147 := true
    return
}
InputBox, ticketCountV265, Tạo Vé130, Nhập số lượng vé cần tạo:, , 300, 140,,,,, 1
if (ErrorLevel)
    return
if (!RegExMatch(Trim(ticketCountV265),"^\d+$") || ticketCountV265<1 || ticketCountV265>999)
{
    ToolTipInfoV386("Nhập số lượng từ 1 đến 999.")
    SetTimer, RemoveToolTip, -2500
    return
}
Ticket130RunV265(ticketCountV265+0)
return

Ticket133ButtonV267:
if (ticket130BusyV265)
{
    sigCancelV147 := true
    return
}
InputBox, ticketCountV267, Tạo Vé133, Nhập số lượng vé cần tạo:, , 300, 140,,,,, 1
if (ErrorLevel)
    return
if (!RegExMatch(Trim(ticketCountV267),"^\d+$") || ticketCountV267<1 || ticketCountV267>999)
{
    ToolTipInfoV386("Nhập số lượng từ 1 đến 999.")
    SetTimer, RemoveToolTip, -2500
    return
}
Ticket130RunV265(ticketCountV267+0,true)
return

Ticket136ButtonV268:
if (ticket130BusyV265)
{
    sigCancelV147 := true
    return
}
InputBox, ticketCountV268, Tạo Vé136, Nhập số lượng vé cần tạo:, , 300, 140,,,,, 1
if (ErrorLevel)
    return
if (!RegExMatch(Trim(ticketCountV268),"^\d+$") || ticketCountV268<1 || ticketCountV268>999)
{
    ToolTipInfoV386("Nhập số lượng từ 1 đến 999.")
    SetTimer, RemoveToolTip, -2500
    return
}
Ticket130RunV265(ticketCountV268+0,2)
return

Ticket139ButtonV268:
if (ticket130BusyV265)
{
    sigCancelV147 := true
    return
}
InputBox, ticketCountV268, Tạo Vé139, Nhập số lượng vé cần tạo:, , 300, 140,,,,, 1
if (ErrorLevel)
    return
if (!RegExMatch(Trim(ticketCountV268),"^\d+$") || ticketCountV268<1 || ticketCountV268>999)
{
    ToolTipInfoV386("Nhập số lượng từ 1 đến 999.")
    SetTimer, RemoveToolTip, -2500
    return
}
Ticket130RunV265(ticketCountV268+0,3)
return

Ticket130MaterialMatchesV267(ctx,item)
{
    name := Ticket130NameV265(ctx,item)
    if (!ctx.soulModeV267)
        return ConsumableKnownNameV7(name)="GEM"
    Loop, Parse, name, `n, `r
        if (RegExMatch(Trim(A_LoopField),"i)^Heavenly Souls?$"))
            return true
    return false
}

Ticket130NameV265(ctx,item)
{
    global consumableClassRAMV7
    key := ctx.pid . "|" . item.cls,started := A_TickCount
    Loop
    {
        SigCheckV147(ctx)
        ConsumablePickupGroupV7(ctx.h,item.cls)
        ConsumableNamePollV7()
        if (consumableClassRAMV7.HasKey(key))
            return Trim(PickupOptCleanTextV12(consumableClassRAMV7[key]))
        if (A_TickCount-started>1500)
            SigFailV147("Chưa đọc được tên vật trong rương; dừng để tránh lấy nhầm")
        Sleep, 30
    }
}

Ticket130FindV265(ctx,wanted,skip := 0)
{
    for uid,a in SigSnapshotV147(ctx)
    {
        if (a.loc!=0 || a.owner!=ctx.inv || uid=skip || a.cls=1204
            || D2ReadU32(ctx.h,a.unit+0x10)=3 || D2ReadU32(ctx.h,a.unit+0x10)=5)
            continue
        if (wanted="ZAKARUM_EAR")
        {
            if (a.cls!=1804)
                continue
            SigLogV147("TICKET130_SEARCH wanted=" . wanted . " uid=" . uid . " class=" . a.cls . " name=Zakarum's Ear")
            return a
        }
        if (wanted="PARAGON_HAMMER")
        {
            if (a.cls!=1816)
                continue
            SigLogV147("TICKET133_SEARCH wanted=" . wanted . " uid=" . uid . " class=" . a.cls . " name=Paragon's Hammer")
            return a
        }
        if (wanted="SOUL_CRATE")
        {
            if (a.cls!=2346)
                continue
            SigLogV147("TICKET133_SEARCH wanted=" . wanted . " uid=" . uid . " class=" . a.cls . " name=Crate O' Souls")
            return a
        }
        name := Ticket130NameV265(ctx,a)
        SigLogV147("TICKET130_SEARCH wanted=" . wanted . " uid=" . uid . " class=" . a.cls . " name=" . name)
        if (wanted="GEM" && ConsumableKnownNameV7(name)="GEM")
            return a
        if (wanted="CLUSTER" && RegExMatch(name,"i)^(?:Diamond|Amethyst|Ruby|Topaz|Bloodstone|Onyx|Amber|Turquoise|Sapphire|Emerald|Rainbow Stone|Skull) Cluster(?: \(\d+\))?$"))
            return a
    }
    return false
}

Ticket130LooseGemsV266(ctx,limit)
{
    gems := []
    for uid,a in SigSnapshotV147(ctx)
    {
        if (a.loc!=0 || a.owner!=ctx.inv || a.cls=1204
            || D2ReadU32(ctx.h,a.unit+0x10)=3 || D2ReadU32(ctx.h,a.unit+0x10)=5)
            continue
        if (Ticket130MaterialMatchesV267(ctx,a))
        {
            gems.Push(a)
            if (gems.Length()>=limit)
                break
        }
    }
    return gems
}

Ticket130RetainedV266(ctx,item)
{
    retained := false
    for _,a in SigCubeItemsV147(ctx)
        if (a.cls=item.cls && a.q=item.q)
            retained := a
    if (!IsObject(retained))
        SigFailV147("Không xác nhận được vật dùng cube còn lại; ngưng")
    if (retained.uid!=item.uid)
    {
        home := ctx.returnHomesV265[item.uid]
        ctx.returnHomesV265.Delete(item.uid)
        home.uid := retained.uid,ctx.returnHomesV265[retained.uid] := home
    }
    return retained
}

Ticket130PrepareGemsV266(ctx,cube,target)
{
    gems := Ticket130LooseGemsV266(ctx,target)
    missing := target-gems.Length(),cluster := false
    SigLogV147("TICKET130_GEM_PLAN target=" . target . " loose=" . gems.Length() . " split=" . missing)
    Loop, %missing%
    {
        SigCheckV147(ctx)
        if (!IsObject(cluster))
        {
            cluster := Ticket130FindV265(ctx,ctx.soulModeV267 ? "SOUL_CRATE" : "CLUSTER")
            if (!IsObject(cluster))
                SigFailV147(ctx.soulModeV267 ? "Không đủ Heavenly Soul và không tìm thấy Crate O' Souls" : "Không đủ gem và không tìm thấy Gem Cluster")
            Ticket130ReserveV265(ctx,cluster)
            SigToCubeV147(ctx,cluster,cube,true)
            SigLogV147("TICKET130_CLUSTER_ENTER uid=" . cluster.uid . " split=" . missing)
        }
        output := SigTransmuteV147(ctx,[cluster],1,cluster)
        cluster := Ticket130RetainedV266(ctx,cluster)
        gem := output[1]
        if (!Ticket130MaterialMatchesV267(ctx,gem))
            SigFailV147("Tách chưa ra " . ctx.materialNameV267 . "; ngưng, giữ sản phẩm")
        if (A_Index=missing)
        {
            gems.InsertAt(1,gem)
            SigLogV147("TICKET130_GEM_KEEP_CUBE uid=" . gem.uid . " next=RETURN_CLUSTER_THEN_EAR")
        }
        else
        {
            SigReturnV147(ctx,gem)
            all := SigSnapshotV147(ctx)
            if (!all.HasKey(gem.uid) || all[gem.uid].loc!=0 || all[gem.uid].owner!=ctx.inv)
                SigFailV147(ctx.materialNameV267 . " đã tách chưa về rương; ngưng")
            gems.Push(all[gem.uid])
        }
        SigLogV147("TICKET130_GEM_PREPARED split_done=" . A_Index . " split_needed=" . missing . " ready=" . gems.Length())
    }
    if (IsObject(cluster))
    {
        SigReturnV147(ctx,cluster)
        ctx.returnHomesV265.Delete(cluster.uid)
        SigLogV147("TICKET130_CLUSTER_HOME next=MOVE_ZAKARUM_EAR")
    }
    return gems
}

TicketItemSizeV277(ctx,cls)
{
    if (!IsObject(ctx.itemSizesV277))
        ctx.itemSizesV277 := {}
    if (ctx.itemSizesV277.HasKey(cls))
        return ctx.itemSizesV277[cls]
    common := D2GetModuleBaseV35(ctx.pid,"D2Common.dll")
    table := common ? D2ReadU32(ctx.h,common+0x9FB98) : 0
    count := common ? D2ReadU32(ctx.h,common+0x9FB94) : 0
    if (!table || cls<0 || cls>=count || count>65535)
        SigFailV147("Không đọc được bảng kích thước vật phẩm")
    w := D2ReadU8V18(ctx.h,table+cls*0x1A8+0x10F)
    h := D2ReadU8V18(ctx.h,table+cls*0x1A8+0x110)
    if (w<1 || w>16 || h<1 || h>16)
        SigFailV147("Không đọc được kích thước vật phẩm class=" . cls)
    size := {w:w,h:h},ctx.itemSizesV277[cls] := size
    return size
}

TicketInventoryPlaceV277(ctx,item)
{
    all := SigSnapshotV147(ctx),occupied := {},extentX := 0,extentY := 0
    size := TicketItemSizeV277(ctx,item.cls)
    for uid,a in all
        if (a.loc=0 && a.owner=ctx.inv && uid!=item.uid && D2ReadU32(ctx.h,a.unit+0x10)!=3)
        {
            footprint := TicketItemSizeV277(ctx,a.cls)
            extentX := Max(extentX,a.x+footprint.w),extentY := Max(extentY,a.y+footprint.h)
            Loop, % footprint.h
            {
                yy := a.y+A_Index-1
                Loop, % footprint.w
                    occupied[(a.x+A_Index-1) . "," . yy] := true
            }
        }
    if (IsObject(ctx.returnHomesV265))
        for _,home in ctx.returnHomesV265
            extentX := Max(extentX,home.x+home.w),extentY := Max(extentY,home.y+home.h)
    if (!extentX || !extentY || extentX>32 || extentY>32)
        SigFailV147("Chưa xác định được vùng ô rương để đặt vật")
    cursor := PickupCursorV4(ctx.h,ctx.inv)
    rejected := 0
    Loop, % extentY
    {
        y := A_Index-1
        Loop, % extentX
        {
            x := A_Index-1
            if (x+size.w>extentX || y+size.h>extentY)
                continue
            free := true
            Loop, % size.h
            {
                yy := y+A_Index-1
                Loop, % size.w
                    if (occupied.HasKey((x+A_Index-1) . "," . yy) || SigReservedHomeCellV192(ctx,x+A_Index-1,yy))
                    {
                        free := false
                        break
                    }
                if (!free)
                    break
            }
            if (!free)
                continue
            cursor := PickupCursorV4(ctx.h,ctx.inv)
            if (!IsObject(cursor) || cursor.uid!=item.uid)
            {
                if (SigWaitLocV147(ctx,item.uid,0,100))
                    return true
                SigLiftV147(ctx,item)
            }
            SigLogV147("TICKET_EMPTY_SLOT uid=" . item.uid . " xy=" . x . "," . y . " size=" . size.w . "x" . size.h)
            bytes := [0x18],SigDwordV147(bytes,item.uid),SigDwordV147(bytes,x),SigDwordV147(bytes,y),SigDwordV147(bytes,0)
            SigPacketV147(ctx,bytes)
            if (SigWaitLocV147(ctx,item.uid,0,700))
            {
                SigLogV147("TICKET_PLACED uid=" . item.uid . " xy=" . x . "," . y . " cursor=EMPTY")
                return true
            }
            rejected++
            SigLogV147("TICKET_SLOT_REJECTED uid=" . item.uid . " xy=" . x . "," . y)
        }
    }
    SigFailV147("Không còn ô trống phù hợp để đặt vật; UID=" . item.uid . "; rejected=" . rejected)
}

TicketCubeClearV278(ctx,cube,items)
{
    if (!items.Length())
    {
        SigLogV147("TICKET_CUBE_EMPTY uid=" . cube.uid . " method=ALREADY_EMPTY")
        return true
    }
    SigCubeDropPickupV280(ctx,cube)
    ctx.cubeDroppedV278 := true
    if (SigCubeItemsV147(ctx).Length())
        SigFailV147("Cube nhặt lại chưa trống; dừng tạo vé")
    SigLogV147("TICKET_CUBE_EMPTY cube_uid=" . cube.uid . " method=DROP_PICK_NO_POSITION_LOCK")
    return true
}

Ticket130ReserveV265(ctx,item)
{
    all := SigSnapshotV147(ctx),live := all[item.uid]
    if (!IsObject(live) || live.loc!=0 || live.owner!=ctx.inv)
        SigFailV147("Vật cần lấy không còn trong rương")
    if (!IsObject(ctx.returnHomesV265))
        ctx.returnHomesV265 := {}
    sizeV277 := TicketItemSizeV277(ctx,item.cls)
    ctx.returnHomesV265[item.uid] := {uid:item.uid,x:live.x,y:live.y,w:sizeV277.w,h:sizeV277.h}
    SigLogV147("TICKET_HOME_RESERVED uid=" . item.uid . " class=" . item.cls . " xy=" . live.x . "," . live.y)
}

Ticket130HomeV265(ctx,item,home)
{
    all := SigSnapshotV147(ctx)
    live := all[item.uid]
    if (IsObject(live) && live.loc=0 && live.owner=ctx.inv && live.x=home.x && live.y=home.y)
        return true
    cursor := PickupCursorV4(ctx.h,ctx.inv)
    if (!IsObject(cursor) || cursor.uid!=item.uid)
        SigLiftV147(ctx,item)
    bytes := [0x18],SigDwordV147(bytes,item.uid),SigDwordV147(bytes,home.x),SigDwordV147(bytes,home.y),SigDwordV147(bytes,0)
    SigPacketV147(ctx,bytes)
    live := SigWaitLocV147(ctx,item.uid,0)
    if (!IsObject(live) || live.x!=home.x || live.y!=home.y)
        SigFailV147("Không trả được vật về đúng ô đã giữ; dừng, không quăng vật")
    SigLogV147("TICKET_HOME_RESTORED uid=" . item.uid . " xy=" . live.x . "," . live.y)
    return true
}

TicketPickupFinishV279(pid,level)
{
    global ticketPickupWaitV279,sigCancelV147,pickupImageOn,pickupTimerBusy
    global pickupBackgroundV181
    ticketPickupWaitV279 := {pid:pid,level:level,checks:0,emptyAt:0,done:false,scanAt:0,remaining:-1,active:true,resetProtectedV754:true}
    previousBackgroundV279 := pickupBackgroundV181
    pickupBackgroundV181 := true
    global cubeResetSerialV754
    pickupSerialV754 := cubeResetSerialV754
    FarmWatchSigGateV753(FarmWatchStateV688(),FarmWatchNowV688())
    started := A_TickCount
    try
    {
        PickupEnabledSetV71(true,true,false)
        SetTimer, PickupImageTimer, Off
        while (A_TickCount-started<120000)
        {
            if (sigCancelV147)
                throw Exception("Đã dừng chờ nhặt; chưa xác nhận hết đồ dưới đất")
            if (!pickupImageOn)
                throw Exception("Nhặt đã dừng / rương đầy; đồ dưới đất chưa được xác nhận hết")
            if (RoomRecordLevelV259(pid)!=level)
                throw Exception("Đã rời map; chưa xác nhận nhặt hết đồ")
            if (!pickupTimerBusy && GameItemActionBeginV4("Pickup", "cube"))
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
            if (ticketPickupWaitV279.done && !pickupTimerBusy
                && A_TickCount-ticketPickupWaitV279.scanAt<1000)
            {
                if (!CubeResetVerifiedV754(pid,level,pickupSerialV754))
                {
                    Sleep, 100
                    continue
                }
                SigLogV147("TICKET_PICKUP_CONFIRMED checks=" . ticketPickupWaitV279.checks . " eligible_ground=0 cursor=EMPTY")
                return true
            }
            ToolTipInfoV386("Đã tạo vé - đang kiểm tra / nhặt đồ dưới đất. Còn " . (ticketPickupWaitV279.remaining<0 ? "chưa quét" : ticketPickupWaitV279.remaining) . " món trong danh sách.")
            Sleep, 100
        }
        throw Exception("Tạo vé chưa hoàn tất: chưa xác nhận nhặt hết sau 120 giây")
    }
    finally
    {
        ticketPickupWaitV279 := false
        if (pickupImageOn)
            SetTimer, PickupImageTimer, 20
        pickupBackgroundV181 := previousBackgroundV279
    }
}

Ticket130RunV265(count,soulMode:=false,entryV293:=false)
{
    global ticket130BusyV265,sigBusyV147,sigCancelV147,sigActiveModeV182,sigBackgroundV179
    global pickupImageOn,pickupTimerBusy,autoMonsterAttackOn,scosEntryV162,stageTwoV166,sigTownV148
    global sigCubeUiOpenV159,pickupRoundResetV1,ticketPickupWaitV279
    if (sigBusyV147 || autoMonsterAttackOn || (IsObject(scosEntryV162) && (!IsObject(entryV293) || scosEntryV162!=entryV293)) || IsObject(stageTwoV166) || IsObject(sigTownV148))
    {
        ToolTipInfoV386("Dừng Farm / SIG trước khi tạo vé.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    if (!SigBackgroundBindV179() || !PickupActivateGameV13())
        return false
    oldBackground := sigBackgroundV179,oldPickup := pickupImageOn
    sigBackgroundV179 := true
    PickupEnabledSetV71(false,true,false)
    start := A_TickCount
    while (pickupTimerBusy && A_TickCount-start<4000)
        Sleep, 50
    if (pickupTimerBusy || !GameItemActionBeginV4("Cube","cube",true))
    {
        sigBackgroundV179 := oldBackground
        ToolTipInfoV386("Đang xử lý đồ hoặc có vật trên chuột; chưa tạo vé.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    materialPerTicket := soulMode ? soulMode+0 : 1
    cost := soulMode=3 ? 200000 : soulMode=2 ? 100000 : 50000
    ticketLevel := soulMode=3 ? 139 : soulMode=2 ? 136 : soulMode ? 133 : 130
    ticketClassV289 := soulMode=3 ? 2391 : soulMode=2 ? 2390 : soulMode ? 2389 : 2348
    ticketCaption := "Vé" . ticketLevel
    reagentName := soulMode ? "Paragon's Hammer" : "Zakarum's Ear"
    ticket130BusyV265 := true,sigBusyV147 := true,sigCancelV147 := false,sigActiveModeV182 := "VE" . ticketLevel
    FarmWatchSigGateV753(FarmWatchStateV688(),FarmWatchNowV688())
    GuiControl, Disable, SigButtonV147
    GuiControl, Disable, SigSuButtonV181
    ctx := false,done := 0,message := "",cleanupOK := true,phase := "OPEN_CONTEXT",existingTicketReadyV738 := false
    SigLogV147("TICKET130_START requested=" . count)
    try
    {
        ctx := SigOpenContextV149()
        ctx.ticketEntryV293 := entryV293
        ctx.ticketPlacementV277 := true
        ctx.soulModeV267 := soulMode
        ctx.materialNameV267 := soulMode ? "Heavenly Soul" : "gem"
        SigLogV147("TICKET_RECIPE mode=" . ticketCaption . " reagent=" . reagentName . " material=" . ctx.materialNameV267 . " material_per_ticket=" . materialPerTicket . " gold_per_ticket=" . cost)
        phase := "CHECK_TOWN"
        level := RoomRecordLevelV259(ctx.pid)
        SigLogV147("TICKET130_LEVEL level=" . level)
        if (level!=1 && level!=40 && level!=75 && level!=103 && level!=109)
            SigFailV147("Tạo vé khi nhân vật ở thành")
        if (IsObject(entryV293))
        {
            phase := "CHECK_EXISTING_TICKET"
            existingV738 := false,cubeV738 := false
            for uidV738,itemV738 in SigSnapshotV147(ctx)
            {
                modeV738 := D2ReadU32(ctx.h,itemV738.unit+0x10)
                if (itemV738.cls=1204 && itemV738.q=2 && itemV738.loc=0 && itemV738.owner=ctx.inv)
                    cubeV738 := itemV738
                if (itemV738.cls!=ticketClassV289 || itemV738.q!=2 || modeV738=3 || modeV738=5)
                    continue
                if (itemV738.loc=0 && itemV738.owner=ctx.inv)
                    existingV738 := itemV738
                else if (itemV738.loc=3 && (!IsObject(existingV738) || existingV738.loc!=0))
                    existingV738 := itemV738
            }
            if (IsObject(existingV738))
            {
                if (existingV738.loc=3)
                {
                    if (!IsObject(cubeV738))
                        SigFailV147("Có vé trong Cube nhưng chưa thấy Cube trong túi; chưa tạo thêm vé")
                    ctx.cubeUid := cubeV738.uid
                    SigReturnV147(ctx,existingV738)
                }
                if (!SigWaitLocV147(ctx,existingV738.uid,0))
                    SigFailV147("Có vé sẵn nhưng chưa xác nhận lấy ra túi; chưa tạo thêm vé")
                existingTicketReadyV738 := true
                message := "Có sẵn " . ticketCaption . " - dùng vé này, bỏ qua tạo vé"
                PortalLogWriteV66("LIB_EXISTING_TICKET tier=" . ticketLevel . " uid=" . existingV738.uid
                    . " class=" . ticketClassV289 . " recipe=SKIPPED")
            }
        }
        if (!existingTicketReadyV738)
        {
            phase := "FIND_CUBE",cube := false,all := SigSnapshotV147(ctx)
            SigLogV147("TICKET130_INVENTORY count=" . all.Count() . " inv=" . V92Hex(ctx.inv))
            for uid,a in all
                if (a.cls=1204)
                {
                    SigLogV147("TICKET130_CUBE_CANDIDATE uid=" . uid . " quality=" . a.q
                        . " loc=" . a.loc . " owner=" . V92Hex(a.owner) . " xy=" . a.x . "," . a.y)
                    if (a.q=2 && a.loc=0 && a.owner=ctx.inv)
                        cube := a
                }
            if (!IsObject(cube))
                SigFailV147("Không tìm thấy Cube trong rương")
            ctx.cubeUid := cube.uid
            phase := "CHECK_CUBE_CONTENTS",inside := SigCubeItemsV147(ctx)
            SigLogV147("TICKET130_CUBE_CONTENTS " . SigItemsTextV150(inside))
            phase := "CHECK_GOLD"
            money := ScosGoldReadV229(ctx.h,ctx.player)
            SigLogV147("TICKET130_GOLD readable=" . IsObject(money) . " carried=" . money.gold . " bank=" . money.bank . " required=" . cost)
            if (!IsObject(money))
                SigFailV147("Chưa đọc được tiền trên người; chưa lấy vật ra")
            if (money.gold + money.bank < cost)
                SigFailV147("Tổng vàng không đủ: người " . money.gold . " + rương " . money.bank . " < " . cost)
            phase := soulMode ? "FIND_PARAGON_HAMMER" : "FIND_ZAKARUM_EAR"
            reagent := Ticket130FindV265(ctx,soulMode ? "PARAGON_HAMMER" : "ZAKARUM_EAR")
            if (!IsObject(reagent))
                SigFailV147("Không tìm thấy " . reagentName . " trong rương")
            target := Min(count,Floor((money.gold + money.bank)/cost))
            SigLogV147("TICKET130_PLAN requested=" . count . " affordable=" . Floor(money.gold/cost) . " target=" . target)
            phase := "CLEAR_CUBE_TO_GROUND"
            TicketCubeClearV278(ctx,cube,inside)
            if (SigCubeItemsV147(ctx).Length())
                SigFailV147("Cube chưa trống sau khi thả đồ")
            phase := "PREPARE_GEMS"
            gems := Ticket130PrepareGemsV266(ctx,cube,target*materialPerTicket)
            phase := soulMode ? "MOVE_PARAGON_HAMMER" : "MOVE_ZAKARUM_EAR"
            Ticket130ReserveV265(ctx,reagent)
            SigToCubeV147(ctx,reagent,cube,true)
            materialIndex := 0
            Loop, %target%
            {
                SigCheckV147(ctx)
                money := ScosGoldReadV229(ctx.h,ctx.player)
                if (!IsObject(money))
                    SigFailV147("Không đọc được tiền; ngưng tạo vé")
                if (money.gold + money.bank < cost)
                {
                    message := "Tổng vàng hết (người " . money.gold . " + rương " . money.bank . " < " . cost . ")"
                    break
                }
                phase := "GET_PREPARED_MATERIALS"
                inputs := [reagent],consumed := []
                Loop, %materialPerTicket%
                {
                    materialIndex++
                    all := SigSnapshotV147(ctx),prepared := gems[materialIndex]
                    if (!all.HasKey(prepared.uid))
                        SigFailV147("Không thấy " . ctx.materialNameV267 . " đã chuẩn bị; ngưng")
                    gem := all[prepared.uid]
                    if (gem.loc=3 && materialIndex=1 && prepared.loc=3)
                        SigLogV147("TICKET_USE_MATERIAL_IN_CUBE uid=" . gem.uid . " transfer=SKIP")
                    else
                    {
                        if (gem.loc!=0 || gem.owner!=ctx.inv)
                            SigFailV147(ctx.materialNameV267 . " đã chuẩn bị không còn trong rương; ngưng")
                        phase := "MOVE_MATERIAL"
                        Ticket130ReserveV265(ctx,gem)
                        SigToCubeV147(ctx,gem,cube,true)
                    }
                    inputs.Push(gem),consumed.Push(gem)
                }
                money := ScosGoldReadV229(ctx.h,ctx.player)
                if (!IsObject(money) || (money.gold + money.bank) < cost)
                {
                    message := "Tổng vàng không đủ; ngưng trước khi cube"
                    break
                }
                phase := "TRANSMUTE"
                output := SigTransmuteV147(ctx,inputs,1,reagent)
                reagent := Ticket130RetainedV266(ctx,reagent)
                if (output[1].cls!=ticketClassV289 || D2ReadU8V18(ctx.h,output[1].data)!=2)
                    SigFailV147("Cube không ra " . ticketCaption . " (class " . ticketClassV289 . "/02); ngưng, giữ sản phẩm")
                for _,usedMaterial in consumed
                    ctx.returnHomesV265.Delete(usedMaterial.uid)
                SigReturnV147(ctx,output[1])
                done++
                SigLogV147("TICKET130_CREATED done=" . done . " requested=" . count . " uid=" . output[1].uid . " gem_class=" . gem.cls)
                ToolTipInfoV386("Tạo " . ticketCaption . ": " . done . "/" . target)
                all := SigSnapshotV147(ctx)
                if (!all.HasKey(reagent.uid) || all[reagent.uid].loc!=3)
                    SigFailV147(reagentName . " không còn trong Cube; ngưng")
                reagent := all[reagent.uid]
            }
            if (message="")
                message := target<count ? "Đã làm đủ số vé theo tiền hiện có" : "Tạo vé xong"
        }
    }
    catch e
    {
        message := e.Message
        SigLogV147("TICKET130_STOP phase=" . phase . " done=" . done . " requested=" . count . " reason=" . e.Message)
        PortalLogWriteV66("TICKET130_STOP phase=" . phase . " reason=" . e.Message)
    }
    finally
    {
        sigCancelV147 := false
        if (IsObject(ctx))
        {
            try
            {
                cursor := PickupCursorV4(ctx.h,ctx.inv)
                if (IsObject(cursor) && cursor.uid)
                {
                    all := SigSnapshotV147(ctx)
                    held := all.HasKey(cursor.uid) ? all[cursor.uid] : cursor
                    SigReturnV147(ctx,held)
                }
                if (IsObject(reagent))
                    for _,a in SigCubeItemsV147(ctx)
                        SigReturnV147(ctx,a)
                SigCloseCubeV156()
            }
            catch restoreError
            {
                cleanupOK := false
                message .= " - Chưa trả được vật: " . restoreError.Message
                SigLogV147("TICKET_RESTORE_FAILED reason=" . restoreError.Message)
            }
            DllCall("CloseHandle","Ptr",ctx.h)
        }
        sigBusyV147 := false,sigActiveModeV182 := ""
        cancelledV575 := sigCancelV147
        sigCancelV147 := false,sigBackgroundV179 := oldBackground,pickupRoundResetV1 := true
        GameItemActionEndV4("Cube")
        if (cleanupOK && IsObject(ctx) && (done>0 || ctx.cubeDroppedV278))
        {
            try
            {
                TicketPickupFinishV279(ctx.pid,level)
                message .= " - Đã kiểm tra hết món trong danh sách nhặt dưới đất"
            }
            catch pickupErrorV279
            {
                cleanupOK := false
                message := "CHƯA HOÀN TẤT: " . pickupErrorV279.Message
                SigLogV147("TICKET_PICKUP_INCOMPLETE reason=" . pickupErrorV279.Message)
            }
        }
        if (cleanupOK && !cancelledV575)
            PickupEnabledSetV71(oldPickup,true,false)
        ticket130BusyV265 := false
        FarmWatchSigGateV753(FarmWatchStateV688(),FarmWatchNowV688())
        GuiControl, Enable, SigButtonV147
        GuiControl, Enable, SigSuButtonV181
    }
    SigLogV147("TICKET130_END done=" . done . " requested=" . count . " restore_ok=" . cleanupOK . " reason=" . message)
    ToolTipInfoV386(existingTicketReadyV738 ? message : message . " - Đã tạo " . done . "/" . count . " vé.")
    SetTimer, RemoveToolTip, -6000
    return (existingTicketReadyV738 || done=count) && cleanupOK
}

LibAutoTicketChangedV293:
if (!IsObject(libAutoTicketV293))
    libAutoTicketV293 := {}
for _,tierV293 in [130,133,136,139]
{
    GuiControlGet, enabledV293,, LibAutoTicket%tierV293%V293
    libAutoTicketV293[tierV293] := enabledV293=1
}
LibAutoTicketSaveV293(currentProfile)
return

LibAutoTicketSaveV293(name)
{
    global libAutoTicketV293,ConfigFile
    if (!IsObject(libAutoTicketV293))
        return
    section := ProfileSection(name)
    for _,tier in [130,133,136,139]
        IniWrite, % libAutoTicketV293[tier] ? 1 : 0, % ProfileConfigPathV364(section), %section%, LibAutoTicket%tier%
}

ProfileConfigPathV364(section)
{
    global ConfigFile, currentProfile, profileList
    if (SubStr(section,1,8)!="Profile_")
        return ConfigFile
    best := ""
    names := profileList . "|" . currentProfile
    Loop, Parse, names, |
    {
        name := A_LoopField
        base := ProfileSection(name)
        if (name!="" && (section=base || InStr(section,base . "_RouteMap_")=1)
            && StrLen(name)>StrLen(best))
            best := name
    }
    return best!="" ? ProfileFile(best) : ConfigFile
}

ProfileNameValidV364(name)
{
    return name!="" && !RegExMatch(name,"[\\/:*?""<>|\[\]\x00-\x1F]")
        && name=RTrim(name," .")
        && !RegExMatch(name,"i)^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)")
}

ProfileMigrateV364()
{
    global ConfigFile, profileList
    EnsureProfileFolder()
    Loop, Parse, profileList, |
    {
        name := A_LoopField
        if (name="")
            continue
        dest := ProfileFile(name)
        if (FileExist(dest))
            continue
        old := A_ScriptDir . "\Profiles\" . SubStr(dest,StrLen(ProfileFolder())+2)
        if (FileExist(old))
            FileCopy, %old%, %dest%, 0
        base := ProfileSection(name)
        IniRead, sections, %ConfigFile%
        Loop, Parse, sections, `n, `r
        {
            section := A_LoopField
            if (section!=base && InStr(section,base . "_RouteMap_")!=1)
                continue
            IniRead, raw, %ConfigFile%, %section%
            Loop, Parse, raw, `n, `r
            {
                at := InStr(A_LoopField,"=")
                if (!at)
                    continue
                key := SubStr(A_LoopField,1,at-1), value := SubStr(A_LoopField,at+1)
                IniRead, exists, %dest%, %section%, %key%, __MISSING_V364__
                if (exists="__MISSING_V364__")
                    IniWrite, %value%, %dest%, %section%, %key%
            }
        }
    }
}

ProfileCaptureControlsV364(name)
{
    global mainToolHwndV67
    if (!mainToolHwndV67 || !DllCall("IsWindow", "Ptr", mainToolHwndV67))
        return
    file := ProfileFile(name), section := ProfileSection(name)
    RecoveryLoginSettingsSaveV489(name)
    Form6SaveV716(section)
    pairs := ProfileControlPairsV364()
    Loop, Parse, pairs, |
    {
        parts := StrSplit(A_LoopField,":")
        control := parts[1], key := parts[2]
        try
        {
            GuiControlGet, hwnd, 1:Hwnd, %control%
            if (ErrorLevel || !hwnd)
                continue
            GuiControlGet, value, 1:, %hwnd%
            if (ErrorLevel)
                continue
        }
        catch controlErrorV364
            continue
        if (RegExMatch(key,"i)(Delay|Interval|Seconds|Radius|Threshold|Cooldown|TapMs|Minutes|Distance|RouteCastEvery|StateID|LevelID)$")
            && value!="" && !RegExMatch(value,"^\d+(\.\d+)?$"))
            continue
        if (value="None" && !InStr(key,"DoubleKey"))
            value := ""
        if (key="RouteCastKey" || key="StuckTeleportKey")
            value := PortalCastNormalizeV50(value)
        if (key="PickupImageOn")
            value := 1
        IniWrite, %value%, %file%, %section%, %key%
    }
}

ProfileControlPairsV364()
{
    return "MapTestModeCheckV656:MapTestMode|RouteRecordDistanceInputV649:RouteRecordMinDistance|BuffSequenceDelayInputV555:BuffSequenceDelayMs|MonsterLockRoomSecInputV622:MonsterLockRoomSec|MonsterSkipDistanceInputV752:MonsterSkipDistance|ZRunKey:ZKey|ZSetKey:ZSetKey|ZSetDelay:ZSetDelay|ZKeyF1:ZFKey|ZKeyF2:ZFKey2|ZDelay1:ZDelay1|ZDelay2:ZDelay2|XKey:XKey|XDelay:XDelay|QCastDoubleKey:QCastDoubleKey|QCastDoubleTapMs:QCastDoubleTapMs|ClickCastKeyInput:ClickCastDoubleKey|ClickCastMsInput:ClickCastDoubleTapMs|DoubleKey:DoubleKey|DoubleTapMs:DoubleTapMs|FormDoubleKey:FormDoubleKey|FormDoubleTapMs:FormDoubleTapMs|Master456KeyInput:Master456Key|AutoPotOn:AutoPotOn|PotMode:PotMode|PotHPThreshold:PotHPThreshold|PotHPThreshold2InputV299:PotHPThreshold2|PotCooldown:PotCooldown|InvHealOn:InvHealOn|CubeHealOn:CubeHealOn|InvManaOn:InvManaOn|CubeManaOn:CubeManaOn|ManaOn:ManaOn|ManaMode:ManaMode|ManaThreshold:ManaThreshold|ManaCooldown:ManaCooldown|Belt4HPKey:Belt4HPKey|Belt2HP2ManaKey:Belt2HP2ManaKey|InvToCubeKey:InvToCubeKey|CubePickupDelayInput:CubePickupDelayMs|CubeTransferDelayInput:CubeTransferDelayMs|PickupEnabledInputV79:PickupImageOn|PickupToggleKeyInputV79:PickupToggleKey|PickupRadius:PickupRadius|PickupFailTeleRadiusInputV1253:PickupFailTeleRadius|PickupStashKeyInputV14:PickupStashKey|PickupSetKeyInputV14:PickupSetKey|PickupSUKeyInputV14:PickupSUKey|SigKeyInputV147:SigKey|SigSuKeyInputV181:SigSuKey|ItemInspectKeyInputV287:ItemInspectKey|SigTUInputV586:SigTU|SigSUInputV510:SigSU|SigSSUInputV13:SigSSU|RareWarningHideInputV19:RareWarningHidden|ExcludeModeV329:ExcludeMode|ExcludeDeleteModeV332:ExcludeDeleteMode|MonsterRadiusInputV48:MonsterAttackRadius|FarmScanLimitInputV771:FarmScanLimit|MonsterLockUntilDeadInputV145:MonsterLockUntilDead|PortalCastInputV50:RouteCastKey|PortalCastEveryInputV52:RouteCastEvery|TeleportKeyInputV55:StuckTeleportKey|TeleportIntervalInputV56:StuckTeleportIntervalSeconds|ChaseCheckInputV9:ChaseCheckSeconds|MapMoveDistanceInputV197:MapMoveDistance|BOMoveMinimumInputV456:BOMoveMinimum|MoveDelayInputV810:MoveDelayMs|GoalDetourInputV14:GoalDetourDistance|ViewIdInputV54:ViewID|ViewIdInputV54:ViewID|ViewPosInputV291:ViewPos|StateBuffKeyInputV17:StateBuffCastKey|PestilenceKeyInputV18:PinnacleCastKey|AnathemaKeyInputV518:AnathemaCastKey|DeathlordStateInputV19:DeathlordStateID|PestilenceStateInputV19:PinnacleStateID|AnathemaStateInputV518:AnathemaStateID|TownLevelInputV22:TownLevelID|OutsideLevelInputV22:OutsideLevelID|ContinuousMapInputV64:ContinuousMap|FarmResetWatchCheckV217:FarmBrainResetWatch|FarmResetWatchMinutesV217:FarmBrainResetMinutes|FarmEntrySigCheckV315:FarmEntrySig|FarmEntryGoldCheckV347:FarmEntryGold|AutoLoadMapCheckV348:AutoLoadMap|PetLearnKeyInputV13:PetLearnKey|PetLearnEnabledInputV12:PetLearnEnabled|PetExcludeDistanceInputV604:PetExcludeDistance|FKey1:FKey1|FKey2:FKey2|FKey3:FKey3|FKey4:FKey4|FKey5:FKey5|FDelay1:FDelay1|FDelay2:FDelay2|FDelay3:FDelay3|FDelay4:FDelay4|FDelay5:FDelay5|QCastKey1:QCastKey1|QCastKey2:QCastKey2|QCastKey3:QCastKey3|QCastDelay1:QCastDelay1|QCastDelay2:QCastDelay2|QCastDelay3:QCastDelay3|RClickKey1:ClickCastKey1|RClickKey2:ClickCastKey2|RClickKey3:ClickCastKey3|RClickKey4:ClickCastKey4|RClickKey5:ClickCastKey5|RClickKey6:ClickCastKey6|RClickDelay1:ClickCastDelay1|RClickDelay2:ClickCastDelay2|RClickDelay3:ClickCastDelay3|RClickDelay4:ClickCastDelay4|RClickDelay5:ClickCastDelay5|RClickDelay6:ClickCastDelay6|LibAutoTicket130V293:LibAutoTicket130|LibAutoTicket133V293:LibAutoTicket133|LibAutoTicket136V293:LibAutoTicket136|LibAutoTicket139V293:LibAutoTicket139"
}

ProfileRefreshControlsV364(name)
{
    global mainToolHwndV67
    if (!mainToolHwndV67 || !DllCall("IsWindow", "Ptr", mainToolHwndV67))
        return
    file := ProfileFile(name), section := ProfileSection(name)
    pairs := ProfileControlPairsV364()
    Loop, Parse, pairs, |
    {
        parts := StrSplit(A_LoopField,":"), control := parts[1], key := parts[2]
        try
        {
            GuiControlGet, hwnd, 1:Hwnd, %control%
            if (ErrorLevel || !hwnd)
                continue
        }
        catch controlErrorV364
            continue
        IniRead, value, %file%, %section%, %key%, __MISSING_V364__
        if (key="PickupImageOn")
            value := 1
        if (value="__MISSING_V364__")
            continue
        if (InStr("|DoubleKey|FormDoubleKey|QCastDoubleKey|ClickCastKeyInput|PotMode|ManaMode|", "|" . control . "|")
            || RegExMatch(control,"^FKey[1-5]$"))
        {
            if (value="")
                value := "None"
            GuiControl, 1:ChooseString, %control%, %value%
        }
        else
            GuiControl, 1:, %control%, %value%
    }
}

ProfileControlExistsV365(control)
{
    global mainToolHwndV67
    if (!mainToolHwndV67 || !DllCall("IsWindow", "Ptr", mainToolHwndV67))
        return false
    try
    {
        GuiControlGet, controlHwndV365, 1:Hwnd, %control%
        return !ErrorLevel && controlHwndV365
    }
    catch controlErrorV365
        return false
}

ProfileStoredV520(name)
{
    if (!ProfileNameValidV364(name) || !FileExist(ProfileFile(name)))
        return false
    file := ProfileFile(name),base := ProfileSection(name)
    IniRead, sections, %file%
    Loop, Parse, sections, `n, `r
        if (A_LoopField=base)
            return true
    return false
}

ProfileDiscoverFilesV366()
{
    global profileList,ConfigFile
    names := "Default",seen := {Default:true}
    Loop, Parse, profileList, |
    {
        name := Trim(A_LoopField)
        if (name="" || seen.HasKey(name) || !ProfileStoredV520(name))
            continue
        seen[name] := true,names .= "|" . name
    }
    pattern := ProfileFolder() . "\*.ini"
    Loop, Files, %pattern%, F
    {
        SplitPath, A_LoopFileName,,,, name
        if (seen.HasKey(name) || !ProfileStoredV520(name))
            continue
        seen[name] := true,names .= "|" . name
    }
    profileList := names
    IniWrite, %profileList%, %ConfigFile%, Profiles, Names
}

FarmTravelNoBuffV670(pid := 0,level := 0)
{
    global scosEntryV162
    r := scosEntryV162
    if (!IsObject(r) || (pid && r.pid!=pid))
        return false
    if (!level)
        level := RoomRecordLevelV259(r.pid)
    if (!level)
        return false
    if (r.map="SCOS" && level=270 && IsObject(r.scosJoinV685)
        && !r.scosInwardV696.done)
        return true
    if (FarmReviveTownLevelV295(level))
        return true
    if ((r.map="SCOS" && level=241) || (r.map="CYC" && level=137)
        || (r.map="UBU" && level=147) || (r.map="CAIN" && (level=183 || level=184)))
        return true
    c := r.commonRouteV3
    return IsObject(c) && c.pid=r.pid && c.level=level && !c.fightOn
}

MapStage1BuffFirstV368(r,ctx,player)
{
    global scosEntryV162
    if (r.stage1BuffDoneV368)
        return true
    if (FarmTravelNoBuffV670(r.pid))
    {
        r.stage1BuffDoneV368 := true
        FarmCastSyncV88(false)
        return true
    }
    if (!r.HasKey("stage1PhaseV368"))
        r.stage1PhaseV368 := r.phase
    r.phase := "ENTRY_BUFF"
    if (!RouteBuffSequenceV20(ctx.h,player,r.pid,true) || scosEntryV162!=r)
        return false
    r.phase := r.stage1PhaseV368
    r.stage1BuffDoneV368 := true
    return true
}

CainQuestReturnV369(h,player,pid)
{
    return false
}

Stage2FlowConfigureV380(mode := "NORMAL",wantClass := 0,wantData := -1,combatOn := true)
{
    global stage2FlowV380,backgroundPidV63,farmControlOwnerV186,cainHuntRouteV403
    if (mode!="NORMAL" && mode!="ITEM")
        return false
    if (mode="ITEM" && (wantClass<=0 || wantData<0))
        return false
    stage2FlowV380 := {mode:mode,pid:backgroundPidV63,owner:farmControlOwnerV186
        ,combatOnV9: combatOn ? true : false
        ,itemClass:wantClass,itemData:wantData,done:false,pickupAtV380:0
        ,levelV427:mode="ITEM" ? FarmCurrentLevelV143() : 0,flowNameV427:mode="ITEM" ? "FARM_ITEM" : "NORMAL"
        ,baselineReadyV389:false,baselineCountV389:0,currentCountV389:0}
    if (mode="ITEM")
    {
        cainHuntRouteV403 := false
        Stage2ItemBaselineInitV389()
    }
    PortalLogWriteV66("STAGE2_FLOW mode=" . mode . " class=" . wantClass . " itemdata=" . wantData
        . " combat=" . (combatOn ? "ON_FIGHT_AND_PICKUP" : "OFF_NO_FIGHT_NO_PICKUP"))
    return true
}

Stage2FightEnabledV9()
{
    if (FarmCommonRouteActiveV3())
        return FarmCommonCombatV10()

    global stage2FlowV380,backgroundPidV63,farmControlOwnerV186
    r := stage2FlowV380
    return !IsObject(r) || r.pid!=backgroundPidV63 || r.owner!=farmControlOwnerV186
        || !r.HasKey("combatOnV9") || r.combatOnV9
}

Stage2PickupEnabledV9()
{
    global stage2FlowV380,backgroundPidV63,farmControlOwnerV186
    r := stage2FlowV380
    return !IsObject(r) || r.pid!=backgroundPidV63 || r.owner!=farmControlOwnerV186
        || !r.HasKey("combatOnV9") || r.combatOnV9
}

Stage2FlowModeV380()
{
    global stage2FlowV380,backgroundPidV63,farmControlOwnerV186
    r := stage2FlowV380
    return IsObject(r) && r.pid=backgroundPidV63 && r.owner=farmControlOwnerV186 ? r.mode : "NORMAL"
}

CainModeApplyV16(r,newSession := false,enablePickup := true)
{
    global stage2FlowV380,backgroundPidV63,cainNoFightV361,cainPauseFarmV361
    global farmPickupBlockedV57,farmPickupAllowedV57,mapWorkflowV185
    if (!IsObject(r))
        return false
    if (!IsObject(mapWorkflowV185) || mapWorkflowV185.map!="CAIN")
        mapWorkflowV185 := {map:"CAIN",stage:2,startLevel:40,testRows:0}
    MapStageSetV185(2)
    r.cainLevelV19 := FarmCurrentLevelV143()
    if (CainCaveMapV502(r.cainLevelV19))
    {
        Stage2FlowConfigureV380("NORMAL",0,-1,false)
        r.cainModeV383 := "CAVE_MOVE",r.cainPickupResumeV370 := false,r.cainPickupHeldV370 := true
        cainNoFightV361 := true,cainPauseFarmV361 := true
        FarmCastSyncV88(false)
        PickupEnabledSetV71(false,true,false)
        farmPickupBlockedV57 := true,farmPickupAllowedV57 := false
        return true
    }
    if (r.cainLevelV19=185)
    {
        if (newSession || !IsObject(stage2FlowV380) || stage2FlowV380.mode!="ITEM"
            || stage2FlowV380.pid!=r.pid || stage2FlowV380.owner!="CAIN")
            CainFinalFarmBeginV388(r,enablePickup)
        r.cainModeV383 := "ITEM"
        r.cainPickupResumeV370 := enablePickup
        FarmCastSyncV88(enablePickup)
        CainIntermediatePickupResumeV370(r)
    }
    else
    {
        Stage2FlowConfigureV380("NORMAL",0,-1,true)
        r.cainModeV383 := "NORMAL"
        cainNoFightV361 := false
        r.cainPickupResumeV370 := false,r.cainPickupHeldV370 := true
        FarmCastSyncV88(true)
        PickupEnabledSetV71(false,true,false)
        farmPickupBlockedV57 := true,farmPickupAllowedV57 := false
    }
    return true
}

Stage2FlowSelectCainV380()
{
    if (FarmCommonRouteActiveV3())
    {
        Stage2FlowConfigureV380("NORMAL",0,-1,FarmCommonCombatV10())
        return
    }

    global farmControlOwnerV186,scosEntryV162,stage2FlowV380,backgroundPidV63
    if (IsObject(stage2FlowV380) && stage2FlowV380.flowNameV427="FARM_ITEM"
        && stage2FlowV380.owner=farmControlOwnerV186 && stage2FlowV380.pid=backgroundPidV63
        && stage2FlowV380.levelV427=FarmCurrentLevelV143() && !stage2FlowV380.done)
        return
    if (farmControlOwnerV186="BO" && IsObject(scosEntryV162))
    {
        wantedV413 := scosEntryV162.boStageV413=4 ? 1825 : 668
        if (!IsObject(stage2FlowV380) || stage2FlowV380.owner!="BO"
            || stage2FlowV380.pid!=backgroundPidV63 || stage2FlowV380.itemClass!=wantedV413)
            FarmItemFlowBeginV427(wantedV413,7,false)
        return
    }
    if (farmControlOwnerV186="CAIN")
    {
        if (IsObject(scosEntryV162) && scosEntryV162.cainActiveV368)
            CainModeApplyV16(scosEntryV162,false,true)
        else
            Stage2FlowConfigureV380("NORMAL",0,-1,true)
        return
    }
    Stage2FlowConfigureV380()
}

Stage2ItemDoneV380()
{
    global stage2FlowV380
    return Stage2FlowModeV380()="ITEM" && stage2FlowV380.done
}

Stage2ItemCheckV380(h,player,pid)
{
    global stage2FlowV380,scosEntryV162
    if (Stage2FlowModeV380()!="ITEM" || stage2FlowV380.pid!=pid)
        return false
    if (BOFinalRouteActiveV451(pid) && !scosEntryV162.boBossKilledV454)
        return false
    r := stage2FlowV380
    if (!r.done)
    {
        count := Stage2ItemCountV380(h,player,r.itemClass,r.itemData)
        if (count<0)
            return false
        boFarmV31 := r.owner="BO" && r.itemData=7 && IsObject(scosEntryV162)
            && scosEntryV162.map="BO" && scosEntryV162.pid=pid && scosEntryV162.phase="FARM"
        boExistingV29 := boFarmV31 && scosEntryV162.boStageV413=2 && r.itemClass=668
        boFinalPickupV31 := boFarmV31 && scosEntryV162.boStageV413=4 && r.itemClass=1825
        if (boFinalPickupV31 && !r.baselineReadyV389)
        {
            Stage2ItemBaselineSetV389(r,count)
            if (!Stage2ItemCubeBaselineV420(h,player,r))
                r.baselineReadyV389 := false
            return false
        }
        if (!boExistingV29 && !boFinalPickupV31)
        {
            if (!r.baselineReadyV389)
            {
                Stage2ItemBaselineSetV389(r,count)
                if (!Stage2ItemCubeBaselineV420(h,player,r))
                    r.baselineReadyV389 := false
                return false
            }
            r.currentCountV389 := count
            if (count<=r.baselineCountV389)
                return false
        }
        r.currentCountV389 := count
        if (!Stage2ItemNewInCubeV420(h,player,r,boExistingV29 || boFinalPickupV31,boFinalPickupV31))
            return false
        if (!BossSearchCleanupReadyV431(h,player,r))
            return false
        r.done := true
        FarmCastSyncV88(false)
        MapStage2RouteFinishV185()
        PortalLogWriteV66("STAGE2_ITEM_DONE class=" . r.itemClass . " itemdata=" . r.itemData
            . " baseline=" . r.baselineCountV389 . " current=" . r.currentCountV389
            . " gained=" . (r.currentCountV389-r.baselineCountV389)
            . " confirmed=" . (boFinalPickupV31 ? "BO_FINAL_PICKED_NEW_UID_IN_INVENTORY_OR_CUBE" : boExistingV29 ? "BO_ITEM_IN_INVENTORY_OR_CUBE" : "NEW_ITEM_IN_CUBE")
            . " next=CALLER_DECIDES")
    }
    return true
}

CainStage2AttachV379()
{
    global scosEntryV162,backgroundPidV63,coordRouteV16,routeMapIdV21
    global cainNoFightV361,cainPauseFarmV361,pickupImageOn,farmStage2DoneV372
    level := FarmCurrentLevelV143()
    if (!level || FarmReviveTownLevelV295(level))
        return false
    if (!Stage2MapWaitV381(backgroundPidV63,level,true))
    {
        PortalLogWriteV66("CAIN_ATTACH_WAIT level=" . level . " reason=FRESH_FILE_NOT_READY"
            ,"CAIN_ATTACH_WAIT",2000)
        return false
    }
    r := {map:"CAIN",pid:backgroundPidV63,until:A_TickCount+600000,phase:"MAP",row:1,last:0
        ,pickup:pickupImageOn,startLevel:40,cainActiveV368:true,cainLastLevelV361:level
        ,cainPhaseV361:level=183 ? "RUN_GD2" : level=184 ? "RUN_GD3" : "RUN_GD4",cainRouteLoadedV361:true
        ,cainMapBuffDoneV368:true,stage1BuffDoneV368:true}
    r.cainPickupResumeV370 := true,r.cainPickupHeldV370 := true
    r.cainLevelV19 := level
    r.cainPhaseV383 := "WAIT"
    r.cainItemBaselineV361 := 0
    r.cainItemWaitLogV383 := 0
    r.cainExitWaitV383 := 0
    r.cainMoveAtV383 := 0
    r.cainInteractAtV383 := 0
    r.cainRunLogV383 := 0
    r.cainWaitLogV383 := 0
    r.cainNoRouteLoggedV383 := false
    scosEntryV162 := r,cainNoFightV361 := false,cainPauseFarmV361 := false
    farmStage2DoneV372 := false
    CainModeApplyV16(r,true,true)
    SetTimer, ScosEntryTimerV162, 250
    PortalLogWriteV66("CAIN_STAGE2_START level=" . level . " route_id=" . routeMapIdV21
        . " yellow=" . coordRouteV16.yellow . " flow=" . Stage2FlowModeV380())
    return true
}

CainIntermediateMapV370(pid := 0)
{
    global scosEntryV162
    r := scosEntryV162
    if (IsObject(r) && r.map="BO" && (!pid || r.pid=pid))
        return r.phase!="TOWN"
    if (!IsObject(r) || r.map!="CAIN" || !r.cainActiveV368 || (pid && r.pid!=pid))
        return false
    if (FarmCurrentLevelV143()=185)
        return false
    phase := r.cainPhaseV383
    return phase="WAIT" || phase="RUN"
}

CainIntermediatePickupHoldV370()
{
    global scosEntryV162,pickupImageOn,farmPickupBlockedV57
    if (!CainIntermediateMapV370())
        return false
    r := scosEntryV162
    if (!r.cainPickupHeldV370)
    {
        r.cainPickupResumeV370 := pickupImageOn
        r.cainPickupHeldV370 := true
        farmPickupBlockedV57 := true
        PickupEnabledSetV71(false,true,false)
        PortalLogWriteV66("CAIN_INTERMEDIATE_CUBE_FULL town=BLOCKED pickup=PAUSED next=CAVE")
    }
    return true
}

CainIntermediatePickupResumeV370(r)
{
    global farmPickupBlockedV57,farmPickupAllowedV57
    if (!Stage2PickupEnabledV9())
    {
        r.cainPickupHeldV370 := true
        PickupEnabledSetV71(false,true,false)
        farmPickupBlockedV57 := true,farmPickupAllowedV57 := false
        return
    }
    farmPickupBlockedV57 := false
    r.cainPickupHeldV370 := false
    PickupEnabledSetV71(r.cainPickupResumeV370,true,false)
    PortalLogWriteV66("CAIN_GD4_PICKUP_RESTORED town_sig=NORMAL")
}

FarmPickupFullHoldV371()
{
    global autoMonsterAttackOn,farmPickupBlockedV57,pickupFarmWorkV75
    if (BossSearchActiveV430())
    {
        farmPickupBlockedV57 := false,pickupFarmWorkV75 := false
        return
    }
    if (!autoMonsterAttackOn)
        return
    PickupEnabledSetV71(false,true,false)
    farmPickupBlockedV57 := true
    pickupFarmWorkV75 := false
    SigLogV147("FARM_CONTAINER_FULL pickup=OFF farm=CONTINUE town_sig=OFF")
}

FarmStage2DoneCurrentV372(pid)
{
    global farmStage2DoneV372,coordRouteV16
    return IsObject(farmStage2DoneV372) && farmStage2DoneV372.pid=pid
        && farmStage2DoneV372.route=coordRouteV16 && IsObject(coordRouteV16)
        && coordRouteV16.phase="DONE"
}


MapStage2FlowTimerV372:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    SetTimer, MapStage2FlowTimerV372, Off
    return
}
if (cainPausedV10)
    return
MapStage2FlowCompleteV372()
return

MapStage2FlowCompleteV372()
{
    if (FarmCommonRouteActiveV3())
        return

    global mapWorkflowV185,farmControlOwnerV186,farmStage2DoneV372
    global backgroundPidV63,autoMonsterAttackOn,xRunning,zRunning,gameItemActionOwner
    global sigTownV148,sigBusyV147
    if (!IsObject(mapWorkflowV185) || mapWorkflowV185.stage!=2 || (mapWorkflowV185.map="CAIN" || mapWorkflowV185.map="BO")
        || mapWorkflowV185.map!=farmControlOwnerV186 || !FarmStage2DoneCurrentV372(backgroundPidV63))
        return
    r := farmStage2DoneV372
    if (r.handled || r.owner!=mapWorkflowV185.map || !autoMonsterAttackOn
        || xRunning || zRunning || gameItemActionOwner!="" || sigBusyV147 || IsObject(sigTownV148))
        return
    if (!FarmNormalFinalMapV577(mapWorkflowV185.map,FarmCurrentLevelV143()))
        return
    if (Lab1SingleRunV310())
    {
        r.handled := true
        if (!FarmStage3RequestV313("COMPLETE"))
        {
            FarmErrorKeepV769("LAB_STAGE3_HANDOFF_FAILED")
        }
        return
    }
    r.handled := true
    if (FarmStage3RequestV313("COMPLETE"))
    {
        PortalLogWriteV66("MAP_FLOW_STAGE2_DONE next=STAGE3_DLL no_town=1")
        return
    }
    FarmErrorKeepV769("MAP_STAGE3_HANDOFF_FAILED")
    FarmCombatYieldV237()
    PickupEnabledSetV71(false,true,false)
    farmRestartReasonV238 := ""
    ToolTipInfoV386("Đã hết lộ trình — giữ phiên farm, chờ xử lý chuyển bước.")
    SetTimer, RemoveToolTip, -4000
    PortalLogWriteV66("MAP_FLOW_STAGE2_DONE next=ERROR_KEEP_FARM")
}

ScosEntryMoveV162(ctx,x,y)
{
    return MapStage1MoveV374(ctx,x,y)
}

MapStage9V373(ctx,level,target,kind:="AUTO",destination:=0)
{
    if (!IsObject(ctx) || !IsObject(target) || !target.uid)
        return false
    if (kind="WP" && destination>0)
    {
        bytes := [0x49]
        SigDwordV147(bytes,target.uid)
        SigDwordV147(bytes,destination)
        SigPacketV147(ctx,bytes)
        return true
    }
    if (kind="WP")
    {
        if (IsObject(ctx.entryStateV42) && ctx.entryStateV42.map="CAIN")
        {
            live := {unit:target.unit,uid:target.uid,cls:target.cls,typ:2,x:target.x,y:target.y}
            return EnterPortalInteractV363(ctx.pid,level,live)
        }
        return SigTownPortalInteractV148(ctx.pid,level,target,true)
    }
    typ := target.HasKey("typ") ? target.typ : D2ReadU32(ctx.h,target.unit)
    if (typ!=2 && typ!=5)
        typ := 2
    fullTarget := {unit:target.unit,uid:target.uid,cls:target.cls,typ:typ,x:target.x,y:target.y}
    return EnterPortalInteractV363(ctx.pid,level,fullTarget)
}


MapSigFlowV374(mode:="BOTH")
{
    global autoMonsterAttackOn
    ; MapStage1SigReadyV374 has already checked the option frozen at
    ; map-button press. Do not silently skip SIG if the GUI changes later.
    FarmAttackHoldReleaseV15()
    autoMonsterAttackOn := false
    SetTimer, AutoMonsterAttackTimer, Off
    FarmCastSyncV88(false)
    return SigStartBackgroundV183(mode)
}


RoutePlanNewV375:
RoutePlanChooseV375(true)
return
RoutePlanOpenV375:
RoutePlanChooseV375(false)
return

RoutePlanChooseV375(create)
{
    global routeRecordV358
    if (IsObject(routeRecordV358))
        return
    root := A_ScriptDir . "\LoTrinh"
    FileCreateDir, %root%
    options := create ? "S16" : "3"
    FileSelectFile, chosen, %options%, % root . "\Farm-Flow.txt", Chọn file lộ trình, Lộ trình (*.txt)
    if (chosen="")
        return
    if (!RegExMatch(chosen,"i)\.txt$"))
        chosen .= ".txt"
    if (!FileExist(chosen))
    {
        f := FileOpen(chosen,"w","UTF-8")
        if (!IsObject(f))
            return RoutePlanErrorV375()
        f.Write("`; FARM FLOW - các bước chạy từ trên xuống`r`n`; MOVE = GĐ1 không đánh`; FARM = GĐ2 chung, hết map báo DONE`r`n`; WP / CAVE / PORTAL = GĐ9`; SIG / GOLD gọi theo checkbox`r`n`; BOSS class=... `; PICK class=1839 itemdata=07 `; TOWN `; NEWGAME`r`n")
        f.Close()
    }
    RoutePlanLoadV375(chosen)
}

RoutePlanLoadV375(file)
{
    global routePlanV375,ConfigFile
    f := FileOpen(file,"r","UTF-8")
    if (!IsObject(f))
        return RoutePlanErrorV375()
    raw := f.Read(),f.Close()
    routePlanV375.file := file
    GuiControl, RoutePlan:, PlanTextV375, %raw%
    GuiControl, RoutePlan:, PlanFileV375, %file%
    IniWrite, %file%, %ConfigFile%, RoutePlan, LastFile
    return true
}

RoutePlanSaveLabelV375:
RoutePlanSaveV375()
return
RoutePlanSaveV375()
{
    global routePlanV375,routeRecordV358
    if (!IsObject(routePlanV375) || routePlanV375.file="" || IsObject(routeRecordV358))
        return false
    GuiControlGet, raw, RoutePlan:, PlanTextV375
    raw := StrReplace(StrReplace(raw,"`r`n","`n"),"`r","`n")
    raw := StrReplace(raw,"`n","`r`n")
    temp := routePlanV375.file . ".tmp"
    f := FileOpen(temp,"w","UTF-8")
    if (!IsObject(f))
        return RoutePlanErrorV375()
    f.Write(raw),f.Close()
    FileMove, %temp%, % routePlanV375.file, 1
    if (ErrorLevel)
        return RoutePlanErrorV375()
    return true
}

RoutePlanRecordV375:
RoutePlanRecordStartV375()
return
RoutePlanRecordStartV375()
{
    global routePlanV375,routeRecordV358,roomRecordV108,backgroundPidV63,backgroundHwndV63
    if (IsObject(routeRecordV358))
        return
    if (IsObject(roomRecordV108))
    {
        ToolTipInfoV386("Dừng bộ ghi tọa độ cũ trước khi ghi lộ trình này.")
        SetTimer, RemoveToolTip, -3000
        return
    }
    if (!RoutePlanSaveV375())
    {
        ToolTipInfoV386("Chọn File mới hoặc Mở file trước khi Ghi tiếp.")
        SetTimer, RemoveToolTip, -3000
        return
    }
    if (!SigBackgroundBindV179() || !PickupActivateGameV13())
        return
    routeRecordV358 := {pid:backgroundPidV63,hwnd:backgroundHwndV63,startAt:A_TickCount,clicks:[],planV375:true}
    RoutePlanRecordingUiV375(true)
    Hotkey, ~*LButton, RouteRecordMouseDownV358, On
    ToolTipInfoV386("Đang ghi tiếp: chỉ click trái trong game; không ghi các tọa độ di chuyển trung gian.")
    SetTimer, RemoveToolTip, -4000
}

RoutePlanStopV375:
RouteRecordStopV358("PLAN_PAUSE")
return
RoutePlanGuiClose:
RoutePlanGuiEscape:
RouteRecordStopV358("PLAN_CLOSE")
RoutePlanSaveV375()
Gui, RoutePlan:Hide
return

RoutePlanRecordingUiV375(active)
{
    state := active ? "Disable" : "Enable"
    for _,control in ["PlanNewV375","PlanOpenV375","PlanSaveV375","PlanAddV375","PlanRecordV375"]
        GuiControl, RoutePlan:%state%, %control%
    option := active ? "+ReadOnly" : "-ReadOnly"
    GuiControl, RoutePlan:%option%, PlanTextV375
}

RoutePlanAddV375:
if (IsObject(routeRecordV358) || !RoutePlanSaveV375())
    return
GuiControlGet, kindV375, RoutePlan:, PlanActionV375
kindsV375 := {"WP":"WP","Chui hang":"CAVE","Vào cổng":"PORTAL","Đánh boss":"BOSS"
    ,"Nhặt item":"PICK","Farm GĐ2":"FARM","SIG":"SIG","Cất tiền":"GOLD"
    ,"Về thành":"TOWN","Tạo game mới":"NEWGAME","DONE":"DONE"}
kindV375 := kindsV375[kindV375]
GuiControlGet, paramsV375, RoutePlan:, PlanParamsV375
RoutePlanAppendV375(kindV375 . (Trim(paramsV375)!="" ? " " . Trim(paramsV375) : ""))
return

RoutePlanAppendV375(line)
{
    global routePlanV375
    if (!IsObject(routePlanV375) || routePlanV375.file="")
        return false
    f := FileOpen(routePlanV375.file,"r","UTF-8")
    if (!IsObject(f))
        return RoutePlanErrorV375()
    raw := f.Read(),f.Close()
    prefix := (raw!="" && SubStr(raw,0)!="`n") ? "`r`n" : ""
    f := FileOpen(routePlanV375.file,"a","UTF-8")
    if (!IsObject(f))
        return RoutePlanErrorV375()
    f.Write(prefix . line . "`r`n"),f.Close()
    GuiControl, RoutePlan:, PlanTextV375, % raw . prefix . line . "`r`n"
    return true
}

RoutePlanCopyV375:
GuiControlGet, copyV375, RoutePlan:, PlanTextV375
Clipboard := copyV375
return

RoutePlanErrorV375()
{
    ToolTipInfoV386("Không ghi/đọc được file lộ trình; các dòng cũ được giữ.")
    SetTimer, RemoveToolTip, -4000
    return false
}

SigResumePickupV655(state)
{
    global sigSessionActiveV1321,pickupSigListOnlyV1321
    global sigBusyV147,sigCancelV147,sigActiveModeV182,sigLastStopReasonV63,sigBackgroundV179
    global pickupImageOn,pickupTimerBusy,sigPostPickupV655,sigCompleteSerialV655,sigCompletePidV655,ticketPickupWaitV279,sigResetPendingV753
    if (!IsObject(state) || sigBusyV147 || IsObject(ticketPickupWaitV279) || pickupTimerBusy || !BackgroundValidV63()
        || D2GetActiveGamePidV95()!=state.pid || !GameItemActionBeginV4("Cube","cube",false))
        return false
    oldBackground := sigBackgroundV179
    sigBackgroundV179 := true
    sigBusyV147 := true,sigCancelV147 := false,sigActiveModeV182 := "SET_SU"
    sigSessionActiveV1321 := true
    GuiControl, 1:, SigButtonV147, Hủy
    try
    {
        if (!SigWaitPickupDoneV320(state.pid,state.level,state.scope))
            return false
        sigPostPickupV655 := false,sigCompleteSerialV655++,sigCompletePidV655 := state.pid
        sigResetPendingV753 := false
        sigLastStopReasonV63 := "COMPLETED_PICKUP_VERIFIED"
        pickupSigListOnlyV1321 := true
        PickupEnabledSetV71(true,true,false)
        SigLogV147("SIG_RESUME_DONE_NORMAL_PICKUP_ON filter=ITEM_NHAT_TXT_ONLY")
        return true
    }
    catch pickupErrorV655
    {
        sigLastStopReasonV63 := pickupErrorV655.Message
        FonInfoPushV385("[SIG] Chưa nhặt xong: " . pickupErrorV655.Message)
        return false
    }
    finally
    {
        sigBusyV147 := false,sigActiveModeV182 := "",sigBackgroundV179 := oldBackground
        sigSessionActiveV1321 := false
        FarmWatchSigGateV753(FarmWatchStateV688(),FarmWatchNowV688())
        GameItemActionEndV4("Cube")
        GuiControl, 1:, SigButtonV147, Sig
    }
}


MapStage1SigReadyV374(r)
{
    global scosEntryV162,sigCancelV147,sigLastStopReasonV63,sigPostPickupV655,sigCompleteSerialV655,sigCompletePidV655
    global sigBusyV147,sigActiveModeV182,pickupTimerBusy,ticketPickupWaitV279
    if (r.sigErrorHoldV769)
        return false
    if (r.stage1SigDoneV374 || r.preSigDoneV310)
        return true
    if (r.HasKey("entrySigV315"))
        enabledV374 := r.entrySigV315
    else
        GuiControlGet, enabledV374, 1:, FarmEntrySigCheckV315
    if (!enabledV374)
    {
        r.stage1SigDoneV374 := true
        return true
    }
    if (r.stage1SigBlockedV654)
    {
        if (sigCompletePidV655=r.pid && sigCompleteSerialV655>r.sigFailedSerialV655)
        {
            r.stage1SigBlockedV654 := false,r.stage1SigDoneV374 := true,r.preSigDoneV310 := true
            return true
        }
        if (SigProtectionEndedV761(r.pid))
        {
            r.stage1SigBlockedV654 := false
            return false
        }
        if (sigCancelV147)
            return SigEntryStopV762(r,"Đã hủy SIG")
        if (InStr(sigLastStopReasonV63,"Packet transmute"))
            return SigEntryStopV762(r,sigLastStopReasonV63)
        if (r.sigAttemptsV762>=3 || A_TickCount-r.sigFailedAtV762>=360000)
            return SigEntryStopV762(r,"SIG thất bại sau tối đa 3 lượt: " . sigLastStopReasonV63)
        if (A_TickCount<r.sigRetryAtV762)
            return false
        if (sigBusyV147 || sigActiveModeV182!="" || pickupTimerBusy
            || IsObject(ticketPickupWaitV279) || RemoteThreadBusyV740(r.pid))
        {
            if (A_TickCount-r.sigWaitAtV762>=15000)
                return SigEntryStopV762(r,"Lệnh trước chưa kết thúc sau 15 giây; giữ đồ và dừng")
            return false
        }
    }
    r.sigAttemptsV762 := r.sigAttemptsV762+1
    before := A_TickCount
    if (r.stage1SigBlockedV654 && IsObject(sigPostPickupV655) && sigPostPickupV655.pid=r.pid)
        ok := SigResumePickupV655(sigPostPickupV655)
    else
        ok := MapSigFlowV374()
    if (scosEntryV162!=r)
        return false
    r.until += A_TickCount-before
    if (ok)
    {
        r.stage1SigBlockedV654 := false,r.stage1SigDoneV374 := true,r.preSigDoneV310 := true
        return true
    }
    if (SigProtectionEndedV761(r.pid))
    {
        r.stage1SigBlockedV654 := false
        return false
    }
    r.stage1SigDoneV374 := false,r.preSigDoneV310 := false,r.stage1SigBlockedV654 := true
    r.sigFailedSerialV655 := sigCompleteSerialV655+0
    if (!r.sigFailedAtV762)
        r.sigFailedAtV762 := A_TickCount
    r.sigWaitAtV762 := A_TickCount,r.sigRetryAtV762 := A_TickCount+3000
    FonInfoPushV385("[SIG] Lượt " . r.sigAttemptsV762 . "/3 lỗi: " . sigLastStopReasonV63)
	if (InStr(sigLastStopReasonV63,"Packet transmute") && InStr(sigLastStopReasonV63,"đã thu hồi đồ"))
	{
    r.stage1SigBlockedV654 := false
    r.stage1SigDoneV374 := true
    r.preSigDoneV310 := true
    r.sigErrorHoldV769 := false
    SigLogV147("SIG_ENTRY_SKIP reason=TRANSMUTE_FAILED_RECOVERED_OK next=CONTINUE_FARM")
    return true
	}
if (sigCancelV147 || r.sigAttemptsV762>=3)
    return SigEntryStopV762(r,sigLastStopReasonV63)
    return false
}

CainButtonActionV387()
{
    global scosEntryV162,coordSavedV15,backgroundPidV63,farmControlOwnerV186
    global clickCastOn,cycleOn,cainPausedV10,autoMapTrackingV10,mapLoadFailureV402
    if (farmControlOwnerV186="CAIN" && (FarmControlRunningV186() || cainPausedV10 || farmUserPausedV2026))
        return FarmUserPauseToggleV2026("CAIN")
    if (FarmControlRunningV186())
        return false
    farmControlOwnerV186 := "CAIN"
    if (FarmStartForcedV702("CAIN"))
        return true
    if (SigBackgroundBindV179() && FarmDeadStartBeginV695())
        return true
    if (FarmStartHealthV536("CAIN"))
    {
        if (!FarmControlRunningV186())
        {
            farmControlOwnerV186 := "CAIN"
            FarmStartKeepV697("GAME_HEALTH_WAIT")
        }
        return true
    }
    startLevelV737 := FarmCurrentLevelV143()
    if (startLevelV737 && !FarmStartMapStageV737("CAIN",startLevelV737))
    {
        ToolTipInfoV386("CAIN: map " . startLevelV737 . " không thuộc lộ trình của nút này.")
        SetTimer, RemoveToolTip, -3500
        return true
    }
    FarmStartPrepareV2()
    mapLoadFailureV402 := false
    if (!CainCaveMapV502(FarmCurrentLevelV143()))
    {
        if (IsObject(mapLoadFailureV402) && !FarmReviveTownLevelV295(FarmCurrentLevelV143()))
        {
            farmControlOwnerV186 := "CAIN"
            FarmStartKeepV697("CAIN_MAP_LOAD_WAIT")
            return true
        }
    }
    r := scosEntryV162
    if (!IsObject(r) && FarmControlRunningV186() && farmControlOwnerV186="CAIN")
    {
        CainStage2AttachV379()
        return true
    }
    if ((IsObject(r) && r.map="CAIN")
        || (FarmControlRunningV186() && farmControlOwnerV186="CAIN"))
    {
        CainPauseToggleV10(r)
        return true
    }
    level := FarmCurrentLevelV143()
    if (!FarmControlRunningV186() && FarmStartMapStageV737("CAIN",level)=2)
    {
        farmControlOwnerV186 := "CAIN"
        r := {map:"CAIN",pid:backgroundPidV63,until:A_TickCount+600000,phase:"MAP"
            ,row:1,last:0,pickup:false,startLevel:40,cainActiveV368:true
            ,cainLevelV19:level
            ,cainPhaseV383:"WAIT",cainPhaseV361:level=185 ? "RUN_GD4" : (level=184 ? "RUN_GD3" : "RUN_GD2")}
        r.cainSavedClickV387 := clickCastOn,r.cainSavedCycleV387 := cycleOn
        scosEntryV162 := r
        if (!CainStartLoadedV387(r))
        {
            scosEntryV162 := false
            FarmStartKeepV697("CAIN_ROUTE_LOAD_WAIT")
        }
        return true
    }
    return false
}

CainRouteReloadFromYellowV15(r)
{
    global coordCursorSnapshotV390,stage2MapFileV14
    if (!IsObject(r) || !r.pid)
        return false
    levelV506 := RoomRecordLevelV259(r.pid)
    if (r.map="CAIN" && CainCaveMapV502(levelV506))
        return IsObject(MapLiveIdentityV399(r.pid,levelV506))
    liveV15 := coordCursorSnapshotV390
    if (!IsObject(liveV15) || liveV15.pid!=r.pid || !liveV15.level)
        return false
    if (!Stage2MapWaitV381(r.pid,liveV15.level,true))
        return false
    PortalLogWriteV66("CAIN_MANUAL_ROUTE_NEW level=" . liveV15.level
        . " yellow=" . FarmStartRowV394() . " source=FON_LIVE")
    return true
}

CainPauseToggleV10(r)
{
    return FarmUserPauseToggleV2026("CAIN")
}

CainStartLoadedV387(r)
{
    global
    local row,level
    Critical, On
    if (!CainRouteReloadFromYellowV15(r))
    {
        Critical, Off
        return false
    }
    level := FarmCurrentLevelV143()
    if (CainCaveMapV502(level))
    {
        r.cainCaveV502 := false,r.cainPhaseV383 := "CAVE_MOVE",r.cainResumeStartV387 := false
        CainModeApplyV16(r,true,false)
        autoMonsterAttackOn := false,farmStopMoveV124 := false,coordGoV59 := false
        SetTimer, FarmStopMoveTimerV124, Off
        SetTimer, CoordGoTimerV59, Off
        SetTimer, AutoMonsterAttackTimer, Off
        SetTimer, CainResumeBuffTimerV387, Off
        SetTimer, ScosEntryTimerV162, 250
        Critical, Off
        FonInfoPushV385("[CAIN] Map " . level . ": chỉ lấy vị trí cổng/hang, di chuyển lần vách; không đánh/nhặt")
        return true
    }
    FarmStartApplyYellowV2()
    row := FarmStartRowV394()
    farmStartChoiceV2 := false
    if (!row)
    {
        Critical, Off
        return
    }
    level := coordSavedV15[row].level
    r.cainResumeStartV387 := true
    r.stage1BuffDoneV368 := false
    r.stage1PhaseV368 := r.phase
    cainPauseFarmV361 := false
    autoMonsterAttackOn := false
    farmMapPauseV52 := false
    farmStopMoveV124 := false,coordGoV59 := false
    SetTimer, FarmStopMoveTimerV124, Off
    SetTimer, CoordGoTimerV59, Off
    SetTimer, CoordGoInputTimerV139, Off
    CoordRouteResetV16()
    coordRouteV16.pid := r.pid,coordRouteV16.startLevel := level
    coordRouteV16.resumeRowV210 := row,coordRouteV16.startAtYellowV367 := true
    coordRouteV16.yellow := row
    farmStage2DoneV372 := false
    coordMoveDoneV14 := false,coordMoveTriesV14 := 0
    coordCastCountV50 := 0,coordCastLastRowV50 := 0
    coordCastPendingV50 := false,pestiPointPendingV28 := false,lastAttackPendingV20 := false
    reviveBuffPendingV34 := false,portalBuffV85 := false
    portalExitPendingV69 := false,portalBackPendingV74 := false
    deathlordRetryAtV31 := 0
    if (r.cainActiveV368)
    {
        r.cainPhaseV383 := "RUN"
        r.cainExitWaitV383 := 0,r.cainMoveAtV383 := 0,r.cainInteractAtV383 := 0
        CainModeApplyV16(r,true,false)
        r.cainModeV383 := Stage2FlowModeV380()
    }
    SetTimer, ScosEntryTimerV162, Off
    SetTimer, AutoMonsterAttackTimer, Off
    SetTimer, CainResumeBuffTimerV387, 50
    Critical, Off
    FonInfoPushV385("[CAIN START] Nạp mới file, dòng vàng " . row . " -> buff -> chạy/đánh/nhặt theo giai đoạn")
    return true
}

CainResumeBuffTimerV387:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    SetTimer, CainResumeBuffTimerV387, Off
    return
}
CainResumeBuffTickV387()
return

CainResumeBuffTickV387()
{
    global
    local r,h,base,player,ctx
    static busy := false
    r := scosEntryV162
    if (!IsObject(r) || r.map!="CAIN" || !r.cainResumeStartV387)
    {
        SetTimer, CainResumeBuffTimerV387, Off
        return
    }
    if (busy)
        return
    busy := true,h := 0
    try
    {
        if (!FonEnsureLiveV410(r.pid))
            return
        base := D2GetModuleBaseV35(r.pid,"D2Client.dll")
        h := base ? D2OpenProcess(r.pid) : 0
        player := h ? D2ReadU32(h,base+0x11BBFC) : 0
        if (!player)
            return
        ctx := {pid:r.pid,h:h,scosEntry:true,entryStateV42:r}
        if (!MapStage1BuffFirstV368(r,ctx,player))
            return
        if (scosEntryV162!=r || !r.cainResumeStartV387)
            return
        r.cainResumeStartV387 := false
        farmPickupBlockedV57 := false
        clickCastOn := false,cycleOn := r.cainSavedCycleV387
        Cycle6GuiSyncV525()
        if (r.cainActiveV368)
        {
            autoMonsterAttackOn := true
            farmResumeArmedV70 := true,farmResumeOutsideV70 := false
            CainModeApplyV16(r,false,true)
            FarmCastSyncV88(Stage2FightEnabledV9())
            FarmPickupSyncV57(0,0,-1,true)
            SetTimer, AutoMonsterAttackTimer, 250
            SetTimer, FarmResumeTimerV70, 500
        }
        else
            autoMonsterAttackOn := r.cainResumeAttackV387
        SetTimer, CainResumeBuffTimerV387, Off
        SetTimer, ScosEntryTimerV162, 250
        FonInfoPushV385("[CAIN] Buff xong - chạy hành trình mới từ dòng vàng")
    }
    finally
    {
        if (h)
            DllCall("CloseHandle","Ptr",h)
        busy := false
    }
}

CainAllStopV387(showNotice := true)
{
    global
    farmGD2TestV644 := false
    GuiControl, 1:, FarmGD2TestButtonV644, Run test
    if (sigBusyV147 && sigActiveModeV182="HOP")
        sigCancelV147 := true
    if (showNotice)
        FarmSkillBaselineEnsureV621(CoordDisplayGamePidV1(),true)
    autoMonsterAttackOn := false
    SetTimer, AutoMonsterAttackTimer, Off
    SetTimer, FarmPickupHandoffTimerV901, Off
    FarmWatchStateV688()
    SetTimer, FarmCrashWatchTimerV631, Off
    local orderedRowV740 := CoordYellowIndexV48()
    if (orderedRowV740>=1 && orderedRowV740<=coordSavedV15.Length())
        coordYellowRowV350 := orderedRowV740
    FarmRuntimeResetV535("FARM_STOP")
    farmStartChoiceV2 := false,farmStartHealthV536 := false
    FarmBuffStopV509()
    if (castManualToggleV1801)
        QCastOn := true
    FarmAttackHoldReleaseV15()
    local stoppedOwner := farmControlOwnerV186,timer
    cainPausedV10 := false
    autoMonsterAttackOn := false
    scosEntryV162 := false,stageTwoV166 := false
    mapButtonStartV172 := false,mapFarmStartPendingV170 := false,stage2StartPendingV381 := false
    farmResumeArmedV70 := false,farmResumeOutsideV70 := false
    farmStage3PendingV237 := false,sigFarmResumePendingV237 := false,farmRestartReasonV238 := ""
    if (IsObject(sigTownV148) && sigTownV148.auto)
        SigTownCancelV148("FARM_STOP")
    for _,timer in ["AutoMonsterAttackTimer","CainResumeBuffTimerV387","ScosEntryTimerV162"
        ,"StageTwoTimerV166","StageTwoTestArmTimerV167","StageTwoKeyLogTimerV164"
        ,"MapButtonStartTimerV172","MapFarmStartV170","Stage2StartWaitTimerV381"
        ,"MapStage2FlowTimerV372","FarmResumeTimerV70","FarmStage3RetryTimerV237","SigFarmResumeV152"
        ,"CoordGoTimerV59","CoordGoInputTimerV139"]
        SetTimer, %timer%, Off
    coordGoV59 := false,coordRouteV16 := false,roomExploreV89 := false
    stage2FlowV380 := false,farmStage2DoneV372 := false,cainHuntRouteV403 := false
    cainNoFightV361 := false,cainPauseFarmV361 := false,cainAttachRetryAtV379 := 0
    cainBossUidV361 := 0,cainBossClassV361 := 0,cainBossKilledV361 := false
    reviveBuffPendingV34 := false,farmReviveV32 := false
    portalBuffV85 := false,portalExitPendingV69 := false,portalBackPendingV74 := false
    farmMapPauseV52 := false,farmLoadedMapV56 := false
    farmControlOwnerV186 := "",mapWorkflowV185 := false
    mapRunResumeV210 := false,coordRunSelectedV210 := false
    coordCastCountV50 := 0,coordCastLastRowV50 := 0,coordCastPendingV50 := false
    pestiPointPendingV28 := false,lastAttackPendingV20 := false
    monsterCombatUidV45 := 0,monsterChaseV44 := false,monsterRoadAreaV51 := false
    combatRecoverV48 := false,combatMildRecoverV299 := false
    farmPickupBlockedV57 := false,farmPickupAllowedV57 := true,pickupFarmWorkV75 := false
    MovementCtrlSetV78(false,0,"FARM_STOP")
    farmStopMoveV124 := false
    SetTimer, FarmStopMoveTimerV124, Off
    if (coordTrackingEnabledV409 && !fonEditDepthV414)
        Gosub, CoordTrackingToggleV409
    ; STOP transfers pickup ownership to normal (non-Farm) pickup.
    farmPickupAllowedV57 := false, pickupFarmWorkV75 := false
    PickupEnabledSetV71(true,false,false)
    farmPickupAllowedV57 := false
    PortalLogWriteV66("FARM_STOP owner=" . stoppedOwner . " manual=" . farmManualStoppedV2026
        . " farm=OFF pickup=NORMAL fon=" . (coordTrackingEnabledV409 ? "ON" : "OFF") . " independent_features=KEPT")
    if (showNotice)
    {
        FonInfoPushV385("[STOP] Kết thúc " . (stoppedOwner!="" ? stoppedOwner : "lộ trình đang chạy"))
        ToolTipInfoV386("ĐÃ DỪNG LỘ TRÌNH " . stoppedOwner)
        SetTimer, RemoveToolTip, -2500
    }
}

CainHuntActiveV403()
{
    return CainHuntLevelV422()>0
}

CainHuntLevelV422()
{
    return FarmItemFlowLevelV427()
}

CainHuntClassesV423()
{
    if (BOFinalRouteActiveV451())
        return {1584:true}
    global bossPriorityClassesV221
    GuiControlGet, liveBossTextV403, 1:, BossPriorityListV221
    textV403 := ErrorLevel ? bossPriorityClassesV221 : liveBossTextV403
    idsV423 := {}
    for _,valueV423 in StrSplit(RegExReplace(textV403,"[,;\s]+",","),",")
    {
        valueV423 := Trim(valueV423)
        if (RegExMatch(valueV423,"^\d+$") && valueV423+0>0
            && !MonsterClassExcludedV11(valueV423+0))
            idsV423[valueV423+0] := true
    }
    return idsV423
}

CainHuntLockedV404(pid,level)
{
    global cainHuntRouteV403
    return level=CainHuntLevelV422() && CainHuntActiveV403() && IsObject(cainHuntRouteV403)
        && cainHuntRouteV403.pid=pid && IsObject(cainHuntRouteV403.boss)
}

CainHuntBossTickV403(h,player,ByRef pb,pid)
{
    if (BOCommonActiveV444(pid))
        return false
    global cainHuntRouteV403,monsterCombatUidV45,coordGoV59,monsterRadiusV48
    global scosEntryV162,gameItemActionOwner,packetWatchArmedV1,xRunning,zRunning,autoMonsterAttackOn
    global farmControlOwnerV186
    huntLevelV422 := CainHuntLevelV422()
    if (!CainHuntActiveV403() || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=huntLevelV422)
        return false
    room2V404 := D2ReadU32(h,NumGet(pb,0x1C,"UInt")+0x10)
    levelPtrV404 := room2V404 ? D2ReadU32(h,room2V404+0x58) : 0
    if (!levelPtrV404)
        return false
    if (!IsObject(cainHuntRouteV403) || cainHuntRouteV403.pid!=pid || cainHuntRouteV403.levelPtr!=levelPtrV404)
        cainHuntRouteV403 := {pid:pid,levelPtr:levelPtrV404,boss:false}
    wanted := CainHuntClassesV423()
    if (!wanted.Count())
    {
        CainHuntReleaseV407(IsObject(cainHuntRouteV403.boss) ? cainHuntRouteV403.boss.uid : 0)
        return false
    }
    if (IsObject(cainHuntRouteV403.boss) && !wanted.HasKey(cainHuntRouteV403.boss.cls))
        CainHuntReleaseV407(cainHuntRouteV403.boss.uid)
    lockedUID := IsObject(cainHuntRouteV403.boss) ? cainHuntRouteV403.boss.uid : 0
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort"),seen := {},target := false
    best := farmControlOwnerV186="BO" ? -1 : 1.0e30
    for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
    {
        unit := D2ReadU32(h,room+0x74)
        Loop, 1024
        {
            if (!unit || seen.HasKey(unit) || seen.Count()>=4096)
                break
            seen[unit] := true
            if (!MonsterBossProbeReadV1(h,unit,0xEC,ub))
                break
            next := NumGet(ub,0xE8,"UInt"),uid := NumGet(ub,0x0C,"UInt"),cls := NumGet(ub,4,"UInt"),mode := NumGet(ub,0x10,"UInt")
            if (NumGet(ub,0,"UInt")=1 && wanted.HasKey(cls) && uid && (!lockedUID || uid=lockedUID))
            {
                if (mode=0 || mode=12)
                {
                    if (BOFinalRouteActiveV451(pid) && cls=1584)
                    {
                        scosEntryV162.boBossKilledV454 := true
                        PortalLogWriteV66("BO_FINAL_BOSS_DEAD class=1584 uid=" . uid . " next=SORT_TRANSFER_THEN_PICKUP")
                    }
                    if (uid=lockedUID)
                        cainHuntRouteV403.boss := false,monsterCombatUidV45 := 0
                }
                else if (MonsterBossProbeReadV1(h,NumGet(ub,0x2C,"UInt"),0x20,mb)
                    && CoordLevelV14(h,NumGet(mb,0x1C,"UInt"))=huntLevelV422)
                {
                    x := NumGet(mb,2,"UShort"),y := NumGet(mb,6,"UShort"),d := (x-px)**2+(y-py)**2
                    if ((farmControlOwnerV186="BO" && d>best) || (farmControlOwnerV186!="BO" && d<best))
                        target := {unit:unit,uid:uid,cls:cls,x:x,y:y,level:huntLevelV422,dist:d},best := d
                }
            }
            unit := next
        }
    }
    if (!IsObject(target))
    {
        CainHuntReleaseV407(lockedUID)
        return false
    }
    if (!lockedUID)
    {
        cainHuntRouteV403.approachPending := true,cainHuntRouteV403.combatProbe := false
        if (BOFinalRouteActiveV451(pid))
            PortalLogWriteV66("BO_FINAL_BOSS_LOCK class=1584 uid=" . target.uid . " route=PAUSED pickup=OFF until=DEAD")
        PortalLogWriteV66("CAIN_FINAL_BOSS_LOCK class=" . target.cls . " uid=" . target.uid)
    }
    cainHuntRouteV403.boss := target,monsterCombatUidV45 := target.uid
    if (gameItemActionOwner!="" || packetWatchArmedV1 || xRunning || zRunning || !autoMonsterAttackOn)
        return true
    hpInfoV405 := MonsterBossProbeHPV2(h,D2ReadU32(h,target.unit+0x5C))
    hpRawV405 := hpInfoV405.ok ? hpInfoV405.raw : -1
    blockedV405 := CainHuntCombatStuckV405(target,px,py,hpRawV405)
    PortalLogWriteV66("CAIN_BOSS_STATE level=huntLevelV422 class=" . target.cls . " uid=" . target.uid
        . " hp_raw=" . hpRawV405 . " distance=" . Round(Sqrt(target.dist),2)
        . " player=" . px . "," . py . " target=" . target.x . "," . target.y
        . " stuck=" . blockedV405 . " locked=1", "CAIN_BOSS_STATE",1000)
    farV405 := target.dist>MonsterScanRadiusV20(huntLevelV422)**2
    boRouteOnlyV458 := BOFinalRouteActiveV451(pid)
    if (boRouteOnlyV458)
    {
        cainHuntRouteV403.approachPending := false
        if (farV405)
        {
            monsterCombatUidV45 := 0
            PortalLogWriteV66("BO_FINAL_BOSS_WAIT_RADIUS uid=" . target.uid . " distance=" . Round(Sqrt(target.dist),2)
                . " movement=SAVED_XY_ONLY chase=OFF","BO_FINAL_BOSS_WAIT_RADIUS",1000)
            return false
        }
    }
    if (!boRouteOnlyV458 && (cainHuntRouteV403.approachPending || blockedV405 || farV405) && target.dist>4)
    {
        reasonV405 := blockedV405 ? "BOSS_HP_AND_DISTANCE_UNCHANGED" : cainHuntRouteV403.approachPending ? "BOSS_FOUND" : "BOSS_OUTSIDE_ATTACK_RADIUS"
        if (CainHuntTeleportV405(h,pb,pid,target,reasonV405))
            return true
    }
    if (!boRouteOnlyV458 && farV405)
        return CainHuntMoveV403(h,pb,pid,target)
    if (D2ReadU32(h,target.unit+0x0C)!=target.uid || D2ReadU32(h,target.unit+4)!=target.cls
        || D2ReadU32(h,target.unit+0x10)=0 || D2ReadU32(h,target.unit+0x10)=12)
        return true
    if (AutoMonsterPacketSendV1(pid,target.unit,target.uid))
    {
        AttackIdTipV12(target.cls,Round(Sqrt(target.dist),1))
        probeV405 := cainHuntRouteV403.combatProbe
        if (IsObject(probeV405) && probeV405.uid=target.uid)
        {
            if (!probeV405.since)
                probeV405.since := A_TickCount
            probeV405.queued++
        }
    }
    return true
}

CainHuntReleaseV407(uid)
{
    global cainHuntRouteV403,monsterCombatUidV45,monsterChaseV44,monsterRoadAreaV51
    if (!IsObject(cainHuntRouteV403))
        return
    cainHuntRouteV403.boss := false,cainHuntRouteV403.goal := false
    cainHuntRouteV403.combatProbe := false,cainHuntRouteV403.approachPending := false
    if (uid && monsterCombatUidV45=uid)
        monsterCombatUidV45 := 0,monsterChaseV44 := false,monsterRoadAreaV51 := false
    if (uid)
        PortalLogWriteV66("CAIN_FINAL_BOSS_RELEASE uid=" . uid . " reason=NOT_VISIBLE_OR_DEAD next=COMMON_FARM_ROUTE")
}

CainHuntRouteLoopV407()
{
    global coordRouteV16,coordSavedV15,coordNoTargetSinceV14,scosEntryV162
    huntLevelV422 := CainHuntLevelV422()
    r := coordRouteV16
    if (!CainHuntActiveV403() || !IsObject(r) || r.startLevel!=huntLevelV422 || r.phase!="DONE"
        || CainHuntLockedV404(r.pid,huntLevelV422) || !IsObject(coordSavedV15) || !coordSavedV15.Length())
        return false
    for _,point in coordSavedV15
        if (point.level!=huntLevelV422)
            return false
    r.anchor := 0,r.next := 1,r.yellow := 1,r.phase := "NEXT",r.forwardFloorV303 := 0
    r.tries := 0,r.bestDist := -1,r.lastDispatch := 0,r.moveProbe := false
    r.stuckProbe := false,r.escapeV84 := false,r.bypass := false,r.battlePending := false
    r.firstMoveAttempted := false,r.legRow := 0,r.closestGoalDistance := -1
    coordNoTargetSinceV14 := A_TickCount-250
    CoordBoxRefreshV15()
    PortalLogWriteV66("ITEM_HUNT_ROUTE_LOOP level=" . huntLevelV422 . " next_row=1 rows=" . coordSavedV15.Length())
    return true
}

CainHuntCombatStuckV405(target,px,py,hpRaw)
{
    global cainHuntRouteV403,chaseCheckSecV9
    c := cainHuntRouteV403.combatProbe,distance := Sqrt(target.dist)
    if (!IsObject(c) || c.uid!=target.uid)
    {
        cainHuntRouteV403.combatProbe := {uid:target.uid,x:px,y:py,hp:hpRaw,distance:distance,since:0,queued:0}
        return false
    }
    hpProgress := hpRaw>=0 && c.hp>=0 && hpRaw<c.hp
    if (hpProgress)
        FarmWatchProgressV5()
    closing := c.distance-distance>=1
    moved := (px-c.x)**2+(py-c.y)**2>4
    if (hpProgress || closing || moved)
    {
        c.x := px,c.y := py,c.hp := hpRaw,c.distance := distance,c.since := 0,c.queued := 0
        return false
    }
    if (hpRaw>=0 && c.hp<0)
        c.hp := hpRaw
    return c.queued>=2 && c.since && A_TickCount-c.since>=Max(1,chaseCheckSecV9)*1000
}

CainHuntTeleportV405(h,ByRef pb,pid,target,reason)
{
    if (CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))=163)
        return false
    global cainHuntRouteV403,coordGoV59,coordManualTeleLastV296,coordRouteV16
    global teleportKeyV55,teleportIntervalSecV56,autoMonsterAttackOn
    if (!IsObject(cainHuntRouteV403) || !autoMonsterAttackOn || teleportKeyV55=""
        || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=CainHuntLevelV422())
        return false
    r := cainHuntRouteV403
    lastTele := Max(r.lastTele+0,coordManualTeleLastV296+0,IsObject(coordRouteV16) ? coordRouteV16.lastTeleport+0 : 0)
    if (lastTele && A_TickCount-lastTele<Max(3,teleportIntervalSecV56)*1000)
        return false
    if (r.teleRetryAt && A_TickCount<r.teleRetryAt)
        return false
    if ((target.x-NumGet(pb,2,"UShort"))**2+(target.y-NumGet(pb,6,"UShort"))**2<=4)
    {
        r.approachPending := false
        return false
    }
    goal := {pid:pid,level:target.level,x:target.x,y:target.y,row:0,requiredArrival:true,stop:false}
    priorGoal := coordGoV59,coordGoV59 := goal
    try
        sent := CoordGoTeleportV284(h,pb,goal)
    finally
        if (coordGoV59=goal)
            coordGoV59 := priorGoal
    if (cainHuntRouteV403!=r || !autoMonsterAttackOn)
        return false
    if (!sent)
    {
        r.teleRetryAt := A_TickCount+300
        return false
    }
    r.lastTele := A_TickCount,coordManualTeleLastV296 := r.lastTele
    r.teleRetryAt := 0,r.approachPending := false,r.combatProbe := false
    if (IsObject(coordRouteV16))
        coordRouteV16.lastTeleport := r.lastTele
    if (IsObject(r.goal) && IsObject(r.goal.routeV392))
        r.goal.routeV392.lastTeleport := r.lastTele
    PortalLogWriteV66("CAIN_BOSS_TELEPORT uid=" . target.uid . " class=" . target.cls
        . " destination=" . target.x . "," . target.y . " reason=" . reason . " next=RESCAN_ATTACK")
    return true
}

CainHuntMoveV403(h,ByRef pb,pid,target)
{
    global cainHuntRouteV403,coordGoV59
    if (CainHuntTeleportV405(h,pb,pid,target,"CHASE_LOCKED_BOSS"))
        return true
    if (!IsObject(cainHuntRouteV403.goal) || cainHuntRouteV403.goal.uid!=target.uid)
        cainHuntRouteV403.goal := {pid:pid,level:target.level,x:target.x,y:target.y,uid:target.uid,row:0,requiredArrival:true,stop:false}
    goal := cainHuntRouteV403.goal,goal.x := target.x,goal.y := target.y
    priorGoal := coordGoV59,coordGoV59 := goal
    try
    {
        if (!CoordGoFarmStuckV392(h,pb,goal))
            NativeMovePointV14(pid,target.x,target.y,target.level,true,false,true,goal)
    }
    finally
        if (coordGoV59=goal)
            coordGoV59 := priorGoal
    return true
}

CainFinalFarmBeginV388(r,enablePickup := true)
{
    global cainNoFightV361,cainPauseFarmV361,farmPickupBlockedV57,farmPickupAllowedV57,cainHuntRouteV403
    cainHuntRouteV403 := false
    r.cainPhaseV361 := "FLOW_ITEM"
    r.cainLevelV19 := 185
    r.cainFinalDoneV388 := false
    FarmItemFlowBeginV427(1839,7,false)
    r.cainModeV383 := "ITEM"
    r.cainPickupResumeV370 := true
    if (enablePickup)
        CainIntermediatePickupResumeV370(r)
    else
    {
        PickupEnabledSetV71(false,true,false)
        farmPickupBlockedV57 := true,farmPickupAllowedV57 := false
    }
    PortalLogWriteV66("CAIN_FINAL_BEGIN level=185 flow=FARM_ITEM class=1839 itemdata=07")
}

CainFinalFarmDoneV388(r,h,player)
{
    global scosEntryV162,sigTownV148,farmStage2DoneV372,cainPauseFarmV361,farmRestartReasonV238
    global xRunning,zRunning,gameItemActionOwner,packetWatchArmedV1,sigBusyV147
    if (!FarmItemFlowDoneV427())
        return false
    if (!r.cainFinalDoneV388)
    {
        r.cainFinalDoneV388 := true
        r.cainPhaseV383 := "DONE"
        MapStage2RouteFinishV185()
        FonInfoPushV385("[CAIN 185] GĐ2 DONE - đã nhặt thêm 1839/07; tiếp theo mở cổng về thành")
        PortalLogWriteV66("CAIN_FINAL_DONE result=STAGE2_ITEM_DONE next=RETURN_TOWN")
    }
    cainPauseFarmV361 := true
    if (xRunning || zRunning || gameItemActionOwner!="" || packetWatchArmedV1 || sigBusyV147
        || !AutoMonsterPacketCleanupV1())
        return true
    inv := D2ReadU32(h,player+0x60)
    cursor := inv ? PickupCursorV4(h,inv) : false
    if (!IsObject(cursor) || cursor.unit)
        return true
    if (IsObject(farmStage2DoneV372))
        farmStage2DoneV372.handled := true
    scosEntryV162 := false
    SetTimer, ScosEntryTimerV162, Off
    cainPauseFarmV361 := false
    if (FarmStage3RequestV313("COMPLETE"))
    {
        PortalLogWriteV66("CAIN_FINAL_HANDOFF next=STAGE3_DLL no_town=1")
        return true
    }
    FarmErrorKeepV769("CAIN_STAGE3_HANDOFF_FAILED")
    FarmCombatYieldV237()
    PickupEnabledSetV71(false,true,false)
    farmRestartReasonV238 := ""
    ToolTipInfoV386("CAIN: đã có vật cần — giữ phiên farm, chờ xử lý chuyển bước.")
    SetTimer, RemoveToolTip, -4000
    PortalLogWriteV66("CAIN_FINAL_HANDOFF next=ERROR_KEEP_FARM")
    return true
}

Stage2ItemBaselineInitV389()
{
    global stage2FlowV380
    r := stage2FlowV380
    if (!IsObject(r) || r.mode!="ITEM")
        return false
    h := D2OpenProcess(r.pid)
    if (!h)
        return false
    try
    {
        base := D2GetModuleBaseV35(r.pid,"D2Client.dll")
        player := base ? D2ReadU32(h,base+0x11BBFC) : 0
        count := Stage2ItemCountV380(h,player,r.itemClass,r.itemData)
        if (count<0 || stage2FlowV380!=r)
            return false
        Stage2ItemBaselineSetV389(r,count)
        if (!Stage2ItemCubeBaselineV420(h,player,r))
        {
            r.baselineReadyV389 := false
            return false
        }
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

Stage2ItemBaselineSetV389(r,count)
{
    r.baselineCountV389 := count
    r.currentCountV389 := count
    r.baselineReadyV389 := true
    PortalLogWriteV66("STAGE2_ITEM_BASELINE class=" . r.itemClass . " itemdata=" . r.itemData
        . " inventory_plus_cube=" . count . " done=REQUIRES_COUNT_INCREASE")
    FonInfoPushV385("[GĐ2 ITEM] Ban đầu: " . count . " món trong rương + cube; chờ nhặt thêm")
}

FarmCloseNoDamageV391(h,target,pid,hpRaw)
{
    global monsterChaseV44,chaseCheckSecV9,petLearnEnabledV12,monsterExcludeClassesV11,petExcludeDistanceV604
    c := monsterChaseV44
    if (!petLearnEnabledV12)
    {
        if (IsObject(c))
            c.petCloseProbeV603 := false
        return false
    }
    if (!IsObject(c) || c.uid!=target.uid || c.pid!=pid || c.level!=target.level)
        return false
    radiusV604 := petExcludeDistanceV604
    if (radiusV604<1 || target.dist>=radiusV604*radiusV604 || hpRaw<=0)
    {
        c.petCloseProbeV603 := false
        return false
    }
    w := c.petCloseProbeV603
    if (!IsObject(w) || w.hp!=hpRaw || A_TickCount-w.seen>1500)
    {
        c.petCloseProbeV603 := w := {hp:hpRaw,since:0,seen:A_TickCount}
        return false
    }
    w.seen := A_TickCount
    if (!w.since)
    {
        if (c.queued>0)
            w.since := A_TickCount
        return false
    }
    requiredMs := Max(1,chaseCheckSecV9)*1000
    if (A_TickCount-w.since<requiredMs)
        return false
    if (!MonsterBossProbeReadV1(h,target.unit,0x30,ub) || NumGet(ub,0,"UInt")!=1
        || NumGet(ub,12,"UInt")!=target.uid || NumGet(ub,16,"UInt")=0 || NumGet(ub,16,"UInt")=12
        || (target.cls && NumGet(ub,4,"UInt")!=target.cls))
    {
        c.petCloseProbeV603 := false
        return false
    }
    fresh := MonsterBossProbeHPV2(h,D2ReadU32(h,target.unit+0x5C))
    if (!fresh.ok || fresh.raw!=w.hp)
    {
        c.petCloseProbeV603 := false
        return false
    }
    cls := NumGet(ub,4,"UInt")
    if (!cls)
        return false
    if (!MonsterClassExcludedV11(cls))
    {
        previousList := monsterExcludeClassesV11
        monsterExcludeClassesV11 .= (Trim(monsterExcludeClassesV11)="" ? "" : ",") . cls
        if (!PetExcludeSaveV12())
        {
            monsterExcludeClassesV11 := previousList
            AutoMonsterAttackLogV2("PET_AUTO_ADD_FAILED class=" . cls . " uid=" . target.uid . " reason=SAVE_FAILED")
            return false
        }
        PetExcludeRefreshV16()
    }
    AutoMonsterAttackLogV2("PET_AUTO_ADDED class=" . cls . " uid=" . target.uid
        . " unchanged_ms=" . (A_TickCount-w.since) . " required_ms=" . requiredMs
        . " hp_raw=" . fresh.raw . " distance=" . Round(Sqrt(target.dist),1) . " max_distance=" . radiusV604 . " next=SKIP_CLASS")
    c.petCloseProbeV603 := false
    return true
}


CoordGoFarmStuckV392(h,ByRef pb,goal)
{
    global coordGoV59,coordManualTeleLastV296,coordSavedV15
    if (coordGoV59!=goal || goal.stop)
        return false
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    if (!IsObject(goal.routeV392))
    {
        previous := coordSavedV15[goal.row-1]
        if (IsObject(previous) && previous.level=goal.level)
            previous := {x:previous.x,y:previous.y,level:previous.level}
        else
            previous := {x:px,y:py,level:goal.level}
        goal.pointsV392 := [previous,goal]
        goal.routeV392 := {pid:goal.pid,anchor:1,next:2,phase:"NEXT",lastTeleport:coordManualTeleLastV296
            ,startX:px,startY:py,startLevel:goal.level,stuckProbe:false}
    }
    r := goal.routeV392
    handled := CoordStuckTickV84(h,pb,goal.pid,goal)
    coordManualTeleLastV296 := r.lastTeleport
    return handled
}

CoordStuckMoveV392(pid,x,y,level,r,row,manualGoal := false)
{
    global coordGoV59
    if (IsObject(manualGoal))
    {
        if (!CoordRecoveryGoalValidV655(manualGoal) || manualGoal.stop)
            return false
        return NativeMovePointV14(pid,x,y,level,true,false,true,manualGoal)
    }
    return NativeMovePointV14(pid,x,y,level,false,false,false,false,{route:r,row:row})
}

HopButtonV556:
if (sigBusyV147 && sigActiveModeV182="HOP")
{
    sigCancelV147 := true
    return
}
if (sigBusyV147 || hopPromptV557)
    return
hopPromptV557 := true
InputBox, hopCountV557, HOP, Nhập tổng số thành phẩm cần ghép:, , 330, 145,,,,, 1
hopPromptV557 := false
if (ErrorLevel)
    return
if (!RegExMatch(Trim(hopCountV557),"^\d+$") || hopCountV557<1 || hopCountV557>9999)
{
    ToolTipInfoV386("HOP: nhập số lượng từ 1 đến 9999.")
    SetTimer, RemoveToolTip, -3000
    return
}
HopRunV556(hopCountV557+0)
return

HopInfoV557(text)
{
    global sigLastStopReasonV63
    sigLastStopReasonV63 := "HOP: " . text
    ToolTipInfoV386(sigLastStopReasonV63)
    FonInfoPushV385(sigLastStopReasonV63)
    SigLogV147("HOP " . text)
}

HopRulesV557()
{
    file := TxtRootPathV816("Rune.txt"),rules := [],seen := {}
    if (!FileExist(file))
    {
        FileAppend, 2354|02`r`n, %file%, UTF-8
        if (ErrorLevel)
            SigFailV147("HOP: không tạo được txt\Rune.txt cạnh tool")
    }
    FileRead, raw, %file%
    if (ErrorLevel)
        SigFailV147("HOP: không đọc được Rune.txt")
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField," `t" . Chr(0xFEFF))
        if (line="" || SubStr(line,1,1)="#" || SubStr(line,1,1)=";")
            continue
        if (!RegExMatch(line,"^(\d+)\s*\|\s*02$",m)
            || m1+0<=0 || m1+0=1204 || m1+0=1733 || m1+0=2439)
            SigFailV147("HOP: Rune.txt sai dòng " . A_Index . ": " . line)
        cls := m1+0
        if (!seen.HasKey(cls))
            rules.Push(cls),seen[cls] := true
    }
    if (!rules.Length())
        SigFailV147("HOP: Rune.txt chưa có dòng CLASS|02")
    return rules
}

HopLiveV557(ctx,item,loc:=-1,normalOnly:=true)
{
    all := SigSnapshotV147(ctx),a := all[item.uid]
    if (!IsObject(a) || a.cls!=item.cls || (normalOnly ? a.q!=2 : a.q!=item.q) || (loc>=0 && a.loc!=loc)
        || D2ReadU32(ctx.h,a.unit+0x10)=3 || D2ReadU32(ctx.h,a.unit+0x10)=5)
        SigFailV147("HOP: vật đã đổi trạng thái, CLASS=" . item.cls . " UID=" . item.uid)
    return a
}

HopFindV557(ctx,cls,loc,skip:=false)
{
    for uid,a in SigSnapshotV147(ctx)
        if (a.cls=cls && a.q=2 && a.loc=loc
            && (loc!=0 || a.owner=ctx.inv) && (!IsObject(skip) || !skip.HasKey(uid))
            && D2ReadU32(ctx.h,a.unit+0x10)!=3 && D2ReadU32(ctx.h,a.unit+0x10)!=5)
            return a
    return false
}

HopTextV557(ctx,item,normalOnly:=true)
{
    global pickupOptJobV12
    label := normalOnly ? "HOP" : "Sắp xếp"
    started := A_TickCount
    while (IsObject(pickupOptJobV12))
    {
        SigCheckV147(ctx)
        PickupOptPollV12()
        if (A_TickCount-started>3500)
            SigFailV147(label . ": đang chờ lượt đọc thông tin vật phẩm")
        Sleep, 30
    }
    item := HopLiveV557(ctx,item,-1,normalOnly)
    seed := D2ReadU32(ctx.h,item.data+0x14)
    job := PickupOptStartV12(ctx.pid,item.unit,item.cls,item.q,item.data,item.uid,seed,true)
    if (!IsObject(job))
        SigFailV147(label . ": chưa đọc được thông tin CLASS=" . item.cls)
    started := A_TickCount
    try
    {
        while (DllCall("WaitForSingleObject","Ptr",job.th,"UInt",0)!=0)
        {
            SigCheckV147(ctx)
            if (A_TickCount-started>3000)
                SigFailV147(label . ": đọc thông tin quá hạn")
            Sleep, 30
        }
        exitCode := 0
        if (!DllCall("GetExitCodeThread","Ptr",job.th,"UInt*",exitCode) || exitCode!=1)
            SigFailV147(label . ": game chưa trả thông tin vật phẩm")
        live := HopLiveV557(ctx,item,-1,normalOnly)
        if (live.unit!=item.unit || live.data!=item.data || D2ReadU32(ctx.h,live.data+0x14)!=seed)
            SigFailV147(label . ": vật thay đổi trong lúc đọc thông tin")
        return PickupOptCleanTextV12(PickupOptReadWideV12(job.hp,job.name,512)) . "`n"
            . PickupOptCleanTextV12(PickupOptReadWideV12(job.hp,job.stats,4096),true)
    }
    finally
    {
        if (DllCall("WaitForSingleObject","Ptr",job.th,"UInt",0)=0)
            DllCall("VirtualFreeEx","Ptr",job.hp,"Ptr",job.remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",job.th),DllCall("CloseHandle","Ptr",job.hp)
    }
}

HopQuantityV557(ctx,item)
{
    text := HopTextV557(ctx,item)
    if (!RegExMatch(text,"im)\bQuantity\s*:?\s*([0-9][0-9,]*)",m))
        SigFailV147("HOP: chưa đọc được Quantity của CLASS=" . item.cls . "; chưa tách rune")
    value := StrReplace(m1,",")+0
    if (value<0 || value>10000000)
        SigFailV147("HOP: Quantity không hợp lệ")
    return value
}

HopCloseV557(ctx)
{
    global sigSendingKeyV147,sigCubeUiOpenV159
    if (!ctx.hopStashOpen && !sigCubeUiOpenV159)
        return
    SigCheckV147(ctx)
    sigSendingKeyV147 := true
    try
    {
        if (!GameTargetKeyV63("{Esc}"))
            SigFailV147("HOP: chưa đóng được cửa sổ đồ")
    }
    finally
        sigSendingKeyV147 := false
    ctx.hopStashOpen := false,sigCubeUiOpenV159 := false
    Sleep, 200
}

HopMoveV557(ctx,point,row)
{
    global coordGoV59,sigSendingKeyV147,chaseCheckSecV9
    HopCloseV557(ctx)
    GameItemActionEndV4("Cube")
    goal := {pid:ctx.pid,x:point.x,y:point.y,level:point.level,row:row,redirect:true
        ,requiredArrival:true,singleMove:false,manualInterrupt:false}
    SetTimer, CoordGoTimerV59, Off
    SetTimer, CoordGoInputTimerV139, Off
    coordGoV59 := goal,started := A_TickCount
    lastX := -1,lastY := -1,progressAt := started,lastSend := 0
    HopInfoV557("đi tọa độ " . row . " (" . point.x . "," . point.y . ")")
    try
    {
        Loop
        {
            SigCheckV147(ctx)
            if (coordGoV59!=goal)
                SigFailV147("HOP: đã dừng hoặc thay đổi lệnh di chuyển")
            path := D2ReadU32(ctx.h,ctx.player+0x2C)
            if (!MonsterBossProbeReadV1(ctx.h,path,0x20,pb)
                || CoordLevelV14(ctx.h,NumGet(pb,0x1C,"UInt"))!=point.level)
                SigFailV147("HOP: đã đổi map trong khi đi tọa độ")
            px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
            if ((px-point.x)**2+(py-point.y)**2<=4)
                break
            if (px!=lastX || py!=lastY)
                lastX := px,lastY := py,progressAt := A_TickCount
            mode := D2ReadU32(ctx.h,ctx.player+0x10)
            moving := mode=2 || mode=3 || mode=6
            if (A_TickCount-started>120000)
                SigFailV147("HOP: chưa đến tọa độ " . row . " sau 120 giây")
            sigSendingKeyV147 := true
            try
            {
                recovering := CoordGoFarmStuckV392(ctx.h,pb,goal)
                if (!recovering && (!lastSend || (!moving && A_TickCount-lastSend>=350)
                    || (moving && A_TickCount-progressAt>=Max(1,chaseCheckSecV9)*1000
                        && A_TickCount-lastSend>=350)))
                    if (NativeMovePointV14(ctx.pid,point.x,point.y,point.level,true,false,true,goal))
                        lastSend := A_TickCount
            }
            finally
                sigSendingKeyV147 := false
            Sleep, 150
        }
    }
    finally
    {
        if (coordGoV59=goal)
            CoordGoCancelV41(goal)
    }
    wait := A_TickCount
    while (!AutoMonsterPacketCleanupV1())
    {
        SigCheckV147(ctx)
        if (A_TickCount-wait>4000)
            SigFailV147("HOP: đang chờ lệnh di chuyển kết thúc")
        Sleep, 30
    }
    if (!GameItemActionBeginV4("Cube","cube",true))
        SigFailV147("HOP: chưa lấy được lượt xử lý Cube sau di chuyển")
}

HopOpenStashV557(ctx)
{
    if (ctx.hopStashOpen)
        return
    HopCloseV557(ctx)
    path := D2ReadU32(ctx.h,ctx.player+0x2C)
    if (!MonsterBossProbeReadV1(ctx.h,path,0x20,pb))
        SigFailV147("HOP: chưa đọc được vị trí thủ khố")
    stash := CycObjectV42(ctx.h,pb,267)
    level := CoordLevelV14(ctx.h,NumGet(pb,0x1C,"UInt")),started := A_TickCount
    if (!IsObject(stash))
        SigFailV147("HOP: không thấy thủ khố ở tọa độ cuối n")
    while (!SigTownInteractStashV342(ctx.pid,level,stash))
    {
        SigCheckV147(ctx)
        if (A_TickCount-started>4000)
            SigFailV147("HOP: chưa mở được thủ khố ở tọa độ cuối n")
        Sleep, 100
    }
    ctx.hopStashOpen := true
    Sleep, 600
    SigCheckV147(ctx)
}

HopGridInitV559(ctx)
{
    grid := {cells:{},items:{},width:0,height:0,serial:0}
    for uid,a in SigSnapshotV147(ctx)
        if (a.loc=0 && a.owner=ctx.inv && D2ReadU32(ctx.h,a.unit+0x10)=0)
        {
            size := TicketItemSizeV277(ctx,a.cls)
            if (a.x<0 || a.y<0 || a.x+size.w>32 || a.y+size.h>32)
                SigFailV147("HOP: vùng túi không hợp lệ khi quét ô trống")
            grid.width := Max(grid.width,a.x+size.w),grid.height := Max(grid.height,a.y+size.h)
            grid.serial += 1
            slot := {x:a.x,y:a.y,w:size.w,h:size.h,token:grid.serial,uid:uid}
            grid.items[uid] := slot
            Loop, % slot.h
            {
                yy := slot.y+A_Index-1
                Loop, % slot.w
                    grid.cells[(slot.x+A_Index-1) . "," . yy] := slot.token
            }
        }
    if (!grid.width || !grid.height)
        SigFailV147("HOP: chưa xác định được vùng túi để nhớ ô trống")
    ctx.hopGridV559 := grid
    SigLogV147("HOP_FREE_CELLS_SCAN_ONCE width=" . grid.width . " height=" . grid.height)
}

HopSlotFitsV559(grid,x,y,w,h,token:=0)
{
    if (x<0 || y<0 || x+w>grid.width || y+h>grid.height)
        return false
    Loop, %h%
    {
        yy := y+A_Index-1
        Loop, %w%
        {
            key := (x+A_Index-1) . "," . yy
            if (grid.cells.HasKey(key) && grid.cells[key]!=token)
                return false
        }
    }
    return true
}

HopSlotReserveV559(ctx,item,x:=-1,y:=-1)
{
    grid := ctx.hopGridV559,size := TicketItemSizeV277(ctx,item.cls)
    if (!IsObject(grid))
        SigFailV147("HOP: chưa quét ô trống đầu phiên")
    if (x<0)
    {
        found := false
        Loop, % grid.height
        {
            yy := A_Index-1
            Loop, % grid.width
            {
                xx := A_Index-1
                if (HopSlotFitsV559(grid,xx,yy,size.w,size.h))
                {
                    x := xx,y := yy,found := true
                    break
                }
            }
            if (found)
                break
        }
        if (!found)
            SigFailV147("HOP: hết ô trống đã nhớ cho vật CLASS=" . item.cls)
    }
    if (!HopSlotFitsV559(grid,x,y,size.w,size.h))
        SigFailV147("HOP: ô đã nhớ không đủ chỗ cho vật CLASS=" . item.cls)
    grid.serial += 1
    slot := {x:x,y:y,w:size.w,h:size.h,token:grid.serial,uid:item.uid}
    Loop, % slot.h
    {
        yy := slot.y+A_Index-1
        Loop, % slot.w
            grid.cells[(slot.x+A_Index-1) . "," . yy] := slot.token
    }
    grid.items[item.uid] := slot
    return slot
}

HopSlotReleaseV559(ctx,slot)
{
    grid := ctx.hopGridV559
    Loop, % slot.h
    {
        yy := slot.y+A_Index-1
        Loop, % slot.w
        {
            key := (slot.x+A_Index-1) . "," . yy
            if (grid.cells.HasKey(key) && grid.cells[key]=slot.token)
                grid.cells.Delete(key)
        }
    }
    if (grid.items.HasKey(slot.uid) && grid.items[slot.uid]=slot)
        grid.items.Delete(slot.uid)
}

HopReturnV559(ctx,item,slot:=false)
{
    grid := ctx.hopGridV559,size := TicketItemSizeV277(ctx,item.cls)
    if (!IsObject(slot))
        slot := HopSlotReserveV559(ctx,item)
    if (size.w>slot.w || size.h>slot.h
        || !HopSlotFitsV559(grid,slot.x,slot.y,slot.w,slot.h,slot.token))
        SigFailV147("HOP: ô trả vật đã nhớ không còn hợp lệ")
    cursor := PickupCursorV4(ctx.h,ctx.inv)
    if (!IsObject(cursor) || cursor.uid!=item.uid)
        SigLiftV147(ctx,item)
    bytes := [0x18],SigDwordV147(bytes,item.uid),SigDwordV147(bytes,slot.x)
    SigDwordV147(bytes,slot.y),SigDwordV147(bytes,0)
    SigPacketV147(ctx,bytes)
    live := SigWaitLocV147(ctx,item.uid,0,2000)
    if (!IsObject(live) || live.cls!=item.cls || live.q!=item.q || live.x!=slot.x || live.y!=slot.y)
        SigFailV147("HOP: chưa trả vật về ô đã nhớ " . slot.x . "," . slot.y . "; không dò ô khác")
    if (grid.items.HasKey(slot.uid) && grid.items[slot.uid]=slot)
        grid.items.Delete(slot.uid)
    slot.uid := item.uid,grid.items[item.uid] := slot
    SigLogV147("HOP_RETURN_SAVED_CELL uid=" . item.uid . " xy=" . slot.x . "," . slot.y)
    return slot
}

HopProductReturnV559(ctx,item,inputs)
{
    grid := ctx.hopGridV559,slots := [],size := TicketItemSizeV277(ctx,item.cls)
    for _,a in inputs
    {
        if (!grid.items.HasKey(a.uid))
            SigFailV147("HOP: không còn nhớ ô nguyên liệu UID=" . a.uid)
        slots.Push(grid.items[a.uid])
    }
    for _,slot in slots
        HopSlotReleaseV559(ctx,slot)
    for _,slot in slots
        if (HopSlotFitsV559(grid,slot.x,slot.y,size.w,size.h))
            return HopReturnV559(ctx,item,HopSlotReserveV559(ctx,item,slot.x,slot.y))
    SigFailV147("HOP: thành phẩm không vừa ô của ba nguyên liệu; giữ trong Cube")
}

HopStashTakeV557(ctx,item)
{
    HopOpenStashV557(ctx)
    live := HopLiveV557(ctx,item,4)
    home := {cls:live.cls,q:live.q,x:live.x,y:live.y,loc:live.loc}
    invHome := HopSlotReserveV559(ctx,live)
    cursor := PickupCursorV4(ctx.h,ctx.inv)
    if (!IsObject(cursor) || cursor.unit)
        SigFailV147("HOP: có vật trên chuột trước khi lấy thủ khố")
    bytes := [0x19],SigDwordV147(bytes,live.uid)
    SigPacketV147(ctx,bytes)
    if (!SigWaitLocV147(ctx,live.uid,4))
        SigFailV147("HOP: chưa nhấc được container trong thủ khố")
    HopReturnV559(ctx,live,invHome)
    return {item:HopLiveV557(ctx,live,0),home:home,invHome:invHome}
}

HopStashPutV557(ctx,record)
{
    HopOpenStashV557(ctx)
    item := HopLiveV557(ctx,record.item),home := record.home
    if (item.cls!=home.cls || item.q!=home.q)
        SigFailV147("HOP: container không khớp ô thủ khố đã nhớ")
    SigLiftV147(ctx,item)
    bytes := [0x18],SigDwordV147(bytes,item.uid),SigDwordV147(bytes,home.x)
    SigDwordV147(bytes,home.y),SigDwordV147(bytes,home.loc)
    SigPacketV147(ctx,bytes)
    started := A_TickCount
    Loop
    {
        all := SigSnapshotV147(ctx),live := all[item.uid],cursor := PickupCursorV4(ctx.h,ctx.inv)
        if (IsObject(live) && live.cls=home.cls && live.q=home.q && live.loc=home.loc
            && live.x=home.x && live.y=home.y && IsObject(cursor) && !cursor.unit)
        {
            HopSlotReleaseV559(ctx,record.invHome)
            return true
        }
        if (A_TickCount-started>3000)
            SigFailV147("HOP: chưa trả container " . home.cls . " về đúng ô thủ khố " . home.x . "," . home.y)
        Sleep, 50
    }
}

HopSplitV557(ctx,cube,record,count,quantity:=-1)
{
    item := HopLiveV557(ctx,record.item,0),items := [],expectedClass := -1
    if (SigCubeItemsV147(ctx).Length())
        SigFailV147("HOP: Cube chưa trống trước khi tách")
    SigToCubeV147(ctx,item,cube,true)
    Loop, %count%
    {
        SigCheckV147(ctx)
        if (quantity>=0 && quantity-A_Index<2)
            SigFailV147("HOP: không tách rune xuống dưới 2")
        outputs := SigTransmuteV147(ctx,[item],1,item)
        if (outputs.Length()!=1 || outputs[1].cls=item.cls
            || outputs[1].cls=1204 || (expectedClass>=0 && outputs[1].cls!=expectedClass))
            SigFailV147("HOP: sản phẩm tách không khớp; giữ vật trong Cube")
        expectedClass := outputs[1].cls,retained := false
        for _,a in SigCubeItemsV147(ctx)
            if (a.cls=item.cls && a.q=item.q)
                retained := a
        if (!IsObject(retained))
            SigFailV147("HOP: chưa xác nhận container còn lại sau tách")
        item := retained,record.item := retained
        HopReturnV559(ctx,outputs[1])
        items.Push(HopLiveProductV557(ctx,outputs[1],0))
    }
    if (quantity>=0)
    {
        started := A_TickCount
        while (HopQuantityV557(ctx,item)!=quantity-count)
        {
            if (A_TickCount-started>2500)
                SigFailV147("HOP: số rune còn lại chưa khớp; không tách thêm")
            Sleep, 100
        }
    }
    HopReturnV559(ctx,item,record.invHome)
    record.item := HopLiveV557(ctx,item,0)
    return items
}

HopLiveProductV557(ctx,item,loc)
{
    all := SigSnapshotV147(ctx),live := all[item.uid]
    if (!IsObject(live) || live.cls!=item.cls || live.q!=item.q || live.loc!=loc
        || (loc=0 && live.owner!=ctx.inv) || D2ReadU32(ctx.h,live.unit+0x10)!=0)
        SigFailV147("HOP: chưa xác nhận vật " . item.uid . " trong túi/Cube")
    return live
}

HopPickupV557(ctx,dropPoint)
{
    pickupSerialV754 := CubeResetProofSerialV754()
    HopInfoV557("nhặt nhanh đúng những món đã thả từ Cube")
    started := A_TickCount
    Loop
    {
        SigCheckV147(ctx)
        all := SigSnapshotV147(ctx),pending := 0,ground := false
        for uid,a in ctx.hopDropped
        {
            live := all[uid]
            if (IsObject(live) && live.cls=a.cls && live.q=a.q
                && (live.loc=3 || (live.loc=0 && live.owner=ctx.inv))
                && D2ReadU32(ctx.h,live.unit+0x10)!=3 && D2ReadU32(ctx.h,live.unit+0x10)!=5)
                continue
            pending++
            if (!IsObject(ground))
                ground := SigGroundV147(ctx)
            found := ground[uid]
            if (!IsObject(found))
                continue
            if (found.cls!=a.cls || found.q!=a.q
                || (found.x-dropPoint.x)**2+(found.y-dropPoint.y)**2>225)
                SigFailV147("HOP: món đã thả không khớp vị trí/CLASS UID=" . uid)
            SigPickV147(ctx,found)
        }
        if (!pending)
            break
        if (A_TickCount-started>120000)
            SigFailV147("HOP: vẫn còn " . pending . " món chưa nhặt được; chưa báo Done")
        Sleep, 60
    }
    all := SigSnapshotV147(ctx)
    for uid,a in ctx.hopDropped
        if (!IsObject(all[uid]) || all[uid].cls!=a.cls || all[uid].q!=a.q
            || (all[uid].loc!=0 && all[uid].loc!=3) || (all[uid].loc=0 && all[uid].owner!=ctx.inv)
            || D2ReadU32(ctx.h,all[uid].unit+0x10)=3 || D2ReadU32(ctx.h,all[uid].unit+0x10)=5)
            SigFailV147("HOP: chưa nhặt lại vật đã thả UID=" . uid . "; chưa báo Done")
    CubeResetConfirmV754(ctx.pid,dropPoint.level,ctx.h,ctx.player,pickupSerialV754)
    if (CubeResetPendingV754(ctx.pid))
        SigFailV147("HOP: chưa xác nhận Cube và đồ đã nhặt hết; giữ khóa reset")
}

HopRunV556(total)
{
    global sigBusyV147,sigCancelV147,sigActiveModeV182,sigBackgroundV179,sigSendingKeyV147
    global pickupTimerBusy,xRunning,zRunning,packetWatchArmedV1,buffSequenceOnV555
    global pickupRoundResetV1,sigLastStopReasonV63,coordGoV59
    if (sigBusyV147 || FarmControlRunningV186() || IsObject(coordGoV59) || pickupTimerBusy
        || xRunning || zRunning || packetWatchArmedV1 || buffSequenceOnV555)
    {
        HopInfoV557("dừng farm/buff và chờ thao tác đồ xong rồi bấm lại")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    if (!SigBackgroundBindV179())
        return false
    oldBackground := sigBackgroundV179,sigBackgroundV179 := true
    if (!GameItemActionBeginV4("Cube","cube",true))
    {
        sigBackgroundV179 := oldBackground
        HopInfoV557("chưa xử lý được: có vật trên chuột hoặc thao tác đồ đang chạy")
        SetTimer, RemoveToolTip, -4000
        return false
    }
    sigBusyV147 := true,sigCancelV147 := false,sigActiveModeV182 := "HOP"
    GuiControl, 1:, HopButtonV556, HOP`nStop
    ctx := 0,done := 0,message := "",success := false
    try
    {
        rules := HopRulesV557(),ctx := SigOpenContextV149()
        path := D2ReadU32(ctx.h,ctx.player+0x2C)
        if (!MonsterBossProbeReadV1(ctx.h,path,0x20,pb))
            SigFailV147("HOP: chưa lấy được tọa độ nhân vật")
        level := CoordLevelV14(ctx.h,NumGet(pb,0x1C,"UInt"))
        if (!FarmReviveTownLevelV295(level))
            SigFailV147("HOP: chỉ chạy ở trong thành; không cần tải danh sách tọa độ")
        dropPoint := {x:NumGet(pb,2,"UShort"),y:NumGet(pb,6,"UShort"),level:level}
        ; Kiểm tra trước để không quăng đồ rồi mới biết thành này chưa tải thủ khố.
        stash := CycObjectV42(ctx.h,pb,267)
        if (!IsObject(stash))
            SigFailV147("HOP: chưa thấy thủ khố trong vùng đã tải; hãy đến gần thủ khố")
        cube := HopFindV557(ctx,1204,0)
        if (!IsObject(cube))
            SigFailV147("HOP: không có Cube 1204|02 trong túi")
        ctx.cubeUid := cube.uid,ctx.hopDropped := {}
        for _,a in SigCubeItemsV147(ctx)
            ctx.hopDropped[a.uid] := a
        ; Quăng Cube ngay tại vị trí đứng ở bất kỳ thành nào, nhặt lại Cube trống.
        HopInfoV557("quăng Cube và lấy lại Cube trống tại chỗ")
        SigCubeDropPickupV280(ctx,cube)
        if (SigCubeItemsV147(ctx).Length())
            SigFailV147("HOP: Cube nhặt lại chưa trống")
        cube := HopLiveV557(ctx,cube,0)
        ; Nếu thủ khố ở xa thì tự đến gần, không dùng map/tọa độ đã lưu.
        dist := Sqrt((stash.x-dropPoint.x)**2+(stash.y-dropPoint.y)**2)
        if (dist>15)
        {
            approach := {x:Round(stash.x+(dropPoint.x-stash.x)*6/dist)
                ,y:Round(stash.y+(dropPoint.y-stash.y)*6/dist),level:level}
            HopMoveV557(ctx,approach,"thủ khố")
        }
        HopGridInitV559(ctx)
        used := {}
        for _,runeClass in rules
        {
            Loop
            {
                if (done>=total)
                    break
                HopOpenStashV557(ctx)
                rune := HopFindV557(ctx,runeClass,4,used)
                if (!IsObject(rune))
                    break
                used[rune.uid] := true,quantity := HopQuantityV557(ctx,rune)
                if (quantity<=2)
                    continue
                second := HopFindV557(ctx,2439,4)
                if (!IsObject(second))
                    SigFailV147("HOP: thiếu container 2439|02 trong thủ khố")
                batch := Min(total-done,quantity-2)
                HopInfoV557("lấy 2 container; rune " . runeClass . " có " . quantity . ", tách " . batch . ", chừa 2")
                runeRecord := HopStashTakeV557(ctx,rune)
                secondRecord := HopStashTakeV557(ctx,second)
                HopCloseV557(ctx)
                one := HopSplitV557(ctx,cube,runeRecord,batch,quantity)
                two := HopSplitV557(ctx,cube,secondRecord,batch)
                HopOpenStashV557(ctx)
                HopStashPutV557(ctx,runeRecord)
                HopStashPutV557(ctx,secondRecord)
                HopCloseV557(ctx)
                cluster := HopFindV557(ctx,1733,0),clusterRecord := false
                if (!IsObject(cluster))
                {
                    HopOpenStashV557(ctx)
                    cluster := HopFindV557(ctx,1733,4)
                    if (!IsObject(cluster))
                        SigFailV147("HOP: thiếu Arcane Cluster 1733|02 trong túi/thủ khố")
                    clusterRecord := HopStashTakeV557(ctx,cluster)
                    HopCloseV557(ctx)
                }
                else
                {
                    if (!ctx.hopGridV559.items.HasKey(cluster.uid))
                        SigFailV147("HOP: chưa nhớ vị trí Arcane Cluster trong túi")
                    clusterRecord := {item:cluster,invHome:ctx.hopGridV559.items[cluster.uid]}
                }
                HopInfoV557("tách " . batch . " Arcane Crystal")
                three := HopSplitV557(ctx,cube,clusterRecord,batch)
                if (IsObject(clusterRecord.home))
                {
                    HopStashPutV557(ctx,clusterRecord)
                    HopCloseV557(ctx)
                }
                Loop, %batch%
                {
                    i := A_Index
                    a := HopLiveProductV557(ctx,one[i],0),b := HopLiveProductV557(ctx,two[i],0)
                    c := HopLiveProductV557(ctx,three[i],0)
                    if (a.uid=b.uid || b.uid=c.uid || a.uid=c.uid
                        || a.cls=b.cls || b.cls=c.cls || a.cls=c.cls)
                        SigFailV147("HOP: ba loại nguyên liệu không riêng biệt")
                    SigToCubeV147(ctx,a,cube,true)
                    SigToCubeV147(ctx,b,cube,true)
                    SigToCubeV147(ctx,c,cube,true)
                    products := SigTransmuteV147(ctx,[a,b,c],1)
                    if (products.Length()!=1 || products[1].cls=a.cls || products[1].cls=b.cls
                        || products[1].cls=c.cls || products[1].cls=1204)
                        SigFailV147("HOP: sản phẩm ghép không khớp; giữ trong Cube")
                    HopProductReturnV559(ctx,products[1],[a,b,c])
                    HopLiveProductV557(ctx,products[1],0)
                    done++
                    HopInfoV557("đã ghép " . done . "/" . total)
                }
            }
            if (done>=total)
                break
        }
        HopCloseV557(ctx)
        path := D2ReadU32(ctx.h,ctx.player+0x2C)
        if (!MonsterBossProbeReadV1(ctx.h,path,0x20,pb))
            SigFailV147("HOP: chưa lấy được tọa độ để trở lại điểm nhặt")
        if ((NumGet(pb,2,"UShort")-dropPoint.x)**2+(NumGet(pb,6,"UShort")-dropPoint.y)**2>1)
            HopMoveV557(ctx,dropPoint,"nhặt đồ")
        HopPickupV557(ctx,dropPoint)
        success := done=total
        message := success ? "Done — " . done . "/" . total . ", đã nhặt lại đồ."
            : "Đã ghép " . done . "/" . total . "; hết rune dùng được trong Rune.txt, đã nhặt lại đồ."
    }
    catch e
        message := "Dừng " . done . "/" . total . ": " . e.Message
    finally
    {
        if (IsObject(ctx))
            DllCall("CloseHandle","Ptr",ctx.h)
        sigBusyV147 := false,sigSendingKeyV147 := false,sigActiveModeV182 := ""
        sigBackgroundV179 := oldBackground,pickupRoundResetV1 := true
        GameItemActionEndV4("Cube")
        GuiControl, 1:, HopButtonV556, HOP
    }
    HopInfoV557(message)
    SetTimer, RemoveToolTip, -7000
    return success
}

FarmBOButtonV413:
roomMapLastButtonV22 := "BO"
if (farmControlOwnerV186="BO" && (FarmControlRunningV186() || farmUserPausedV2026))
{
    FarmUserPauseToggleV2026("BO")
    return
}
farmBOButtonDispatchV413 := true
try
    Gosub, MapControlButtonV168
finally
    farmBOButtonDispatchV413 := false
return

BOEntryArmV413(hwnd)
{
    global
    local level,section,firstFarm,finalFarm,stage
    if (!BackgroundBindV63(hwnd))
        return false
    level := FarmCurrentLevelV143()
    if (!level)
        return false
    PickupCtrlEndV26()
    PickupAutoGroupsRefreshV7()
    section := ProfileSection(currentProfile)
    IniRead, firstFarm, % ProfileConfigPathV364(section), %section%, BOFarmLevel2, 0
    IniRead, finalFarm, % ProfileConfigPathV364(section), %section%, BOFarmLevel4, 0
    stage := !FarmReviveTownLevelV295(level) && level=finalFarm && finalFarm ? 4
        : !FarmReviveTownLevelV295(level) && level=firstFarm && firstFarm ? 2 : 1
    scosEntryV162 := {map:"BO",pid:backgroundPidV63,until:A_TickCount+3600000
        ,phase:stage=1 ? "CUBE" : "LOAD",boStageV413:stage,pickup:pickupImageOn,row:1,last:0}
    if (stage!=4)
        BOCoordinateOffV471()
    boStartRSentV417 := GameTargetKeyV63("{r}")
    PortalLogWriteV66("BO_START fon=OFF key=R presses=1 queued=" . boStartRSentV417)
    PickupEnabledSetV71(false,true,false)
    cainPauseFarmV361 := true
    SetTimer, ScosEntryTimerV162, 250
    return true
}

BOFindMaterialV413(ctx,wanted,oldIds := false)
{
    all := SigSnapshotV147(ctx)
    for uid,a in all
        if (a.cls=wanted && a.q=7 && (a.loc=0 || a.loc=3)
            && (!IsObject(oldIds) || !oldIds.HasKey(uid)))
            return a
    for uid,a in SigGroundV147(ctx)
        if (a.cls=wanted && a.q=7 && (!IsObject(oldIds) || !oldIds.HasKey(uid)))
            return a
    return false
}

BOCombinedSigV459(ctx,cube)
{
    global sigBusyV147,sigActiveModeV182,sigTUV586,sigSUV510,sigSSUV13,sigSSSUV13
    rV467 := ctx.entryStateV42
    if (!ctx.boSigBeforeCubeV461 || !IsObject(rV467)
        || rV467.boStageV413!=1 || rV467.boStartSigAttemptedV467)
        return true
    rV467.boStartSigAttemptedV467 := true
    oldBusyV459 := sigBusyV147,oldModeV459 := sigActiveModeV182
    sigBusyV147 := true,sigActiveModeV182 := "SET_SU"
    ctx.boCombinedSigV459 := true
    try
    {
        if (!SetNoSigLoadV227(ctx))
            SigFailV147("Không đọc được danh sách Set không SIG")
        GuiControlGet, sigTUV586, 1:, SigTUInputV586
GuiControlGet, sigSUV510, 1:, SigSUInputV510
        GuiControlGet, sigSSUV13, 1:, SigSSUInputV13
        SigReserveReagentHomesV192(ctx)
        PortalLogWriteV66("BO_COMBINED_SIG_BEGIN cube_uid=" . cube.uid . " drop=ALREADY_DONE pickup=DEFER_UNTIL_PORTAL")
        SigGroupVerifiedV16(ctx,cube,5)
        SigGroupVerifiedV16(ctx,cube,7)
        for _,itemV459 in SigCubeItemsV147(ctx)
        {
            SigCheckV147(ctx)
            SigReturnV147(ctx,itemV459)
        }
        SigSortContainerV191(ctx)
        SigCheckV147(ctx)
        PortalLogWriteV66("BO_COMBINED_SIG_DONE sort=OK pickup_calls=0 next=PORTAL_MATERIAL_TO_CUBE")
        return true
    }
    finally
    {
        ctx.boCombinedSigV459 := false
        sigBusyV147 := oldBusyV459,sigActiveModeV182 := oldModeV459
    }
}

BOCubePortalV413(r,level)
{
    global
    if (pickupTimerBusy || sigBusyV147 || xRunning || zRunning || gameItemActionOwner!="")
        return false
    if (r.boStageV413=3 && !BossSearchHoldReadyV436(r.pid,level))
        return false
    local oldPickupV575 := pickupImageOn
    if (!GameItemActionBeginV4("BOCube","cube",true))
        return false
    PickupEnabledSetV71(false,true,false)
    local ctx := false,oldBg := sigBackgroundV179,cube := false,a,uid,all,material,path,pb,bytes,exits
    sigBackgroundV179 := true,sigCancelV147 := false
    try
    {
        ctx := SigOpenContextV149()
        ctx.scosEntry := true,ctx.entryStateV42 := r
        ctx.boSigBeforeCubeV461 := false
        SigSortContainerV191(ctx)
        SigCheckV147(ctx)
        PortalLogWriteV66("BO_PRE_CUBE_SORT stage=" . r.boStageV413 . " next=FIND_MATERIAL_THEN_DROP_PICKUP_CUBE")
        material := BOFindMaterialV413(ctx,r.boStageV413=1 ? 8 : 668)
        if (!IsObject(material))
            throw Exception("Không thấy vật liệu " . (r.boStageV413=1 ? "8/07" : "668/07 trong rương, cube hoặc dưới đất"))
        if (r.boStageV413=1)
        {
            if (material.loc=-1)
                SigPickV147(ctx,material)
            else if (material.loc=3)
                SigReturnV147(ctx,material)
            Ticket130ReserveV265(ctx,material)
            r.boFirstMaterialUidV475 := material.uid
            r.boFirstMaterialHomeV475 := ctx.returnHomesV265[material.uid]
            PortalLogWriteV66("BO_FIRST_MATERIAL_KEEP_INVENTORY uid=" . material.uid
                . " home=" . r.boFirstMaterialHomeV475.x . "," . r.boFirstMaterialHomeV475.y . " cube_drop=EXCLUDED")
        }
        all := SigSnapshotV147(ctx)
        for uid,a in all
            if (a.cls=1204 && a.loc=0 && a.owner=ctx.inv)
                cube := a
        if (!IsObject(cube))
            throw Exception("Không thấy cube trong rương")
        ctx.cubeUid := cube.uid
        if (SigCubeItemsV147(ctx).Length())
            SigCubeDropPickupV280(ctx,cube)
        if (SigCubeItemsV147(ctx).Length())
            throw Exception("Cube nhặt lại chưa trống")
        SigCheckV147(ctx)
        if (SigCubeItemsV147(ctx).Length())
            throw Exception("Cube còn đồ sau SIG; chưa mở cổng")
        material := BOFindMaterialV413(ctx,r.boStageV413=1 ? 8 : 668)
        if (!IsObject(material))
            throw Exception("Không thấy vật phẩm mở cổng sau SIG/Sort")
        if (r.boStageV413=1)
        {
            all := SigSnapshotV147(ctx)
            material := all[r.boFirstMaterialUidV475]
            if (!IsObject(material) || material.loc!=0 || material.owner!=ctx.inv)
                throw Exception("Vật mở cổng 1 không còn trong rương; không lấy vật khác thay thế")
            Ticket130ReserveV265(ctx,material)
            r.boFirstMaterialHomeV475 := ctx.returnHomesV265[material.uid]
            PortalLogWriteV66("BO_FIRST_MATERIAL_HOME uid=" . material.uid
                . " xy=" . r.boFirstMaterialHomeV475.x . "," . r.boFirstMaterialHomeV475.y
                . " size=" . r.boFirstMaterialHomeV475.w . "x" . r.boFirstMaterialHomeV475.h)
        }
        SigToCubeV147(ctx,material,cube,true)
        path := D2ReadU32(ctx.h,ctx.player+0x2C)
        if (!MonsterBossProbeReadV1(ctx.h,path,0x20,pb))
            throw Exception("Không đọc được vị trí trước khi cube")
        r.oldPortalsV413 := {}
        r.boPortalMaterialUidV469 := material.uid
        r.boCubeX_V469 := NumGet(pb,2,"UShort"),r.boCubeY_V469 := NumGet(pb,6,"UShort")
        exits := ScanExitObjectsV363(ctx.h,pb,NumGet(pb,2,"UShort"),NumGet(pb,6,"UShort"))
        for _,a in exits
            r.oldPortalsV413[a.typ . "|" . a.uid] := true
        bytes := [0x20],SigDwordV147(bytes,cube.uid)
        SigDwordV147(bytes,NumGet(pb,2,"UShort")),SigDwordV147(bytes,NumGet(pb,6,"UShort"))
        sourceRoom2V427 := D2ReadU32(ctx.h,NumGet(pb,0x1C,"UInt")+0x10)
        r.fromLevelPtrV427 := sourceRoom2V427 ? D2ReadU32(ctx.h,sourceRoom2V427+0x58) : 0
        r.fromLevelV413 := level,r.boCubeAttemptV487 := true
        r.boReturnCubeUidV477 := cube.uid,r.boTransmuteAtV477 := A_TickCount
        r.portalAtV413 := A_TickCount,r.enterAtV413 := 0
        r.boPickupDoneV413 := false,r.boPortalPickupStartedV468 := 0
        r.boEntranceV483 := false,r.boPortalPickupBackgroundSavedV483 := false
        SigPacketV147(ctx,bytes)
        r.boPortalPendingV487 := true
        r.phase := r.boStageV413=1 ? "RETURN_MATERIAL" : "PORTAL"
        sigCubeUiOpenV159 := true
        Sleep, 250
        SigCheckV147(ctx)
        SigPacketV147(ctx,[0x4F,0x18,0,0,0,0,0])
        SigCloseCubeV156()
        PortalLogWriteV66("BO_CUBE stage=" . r.boStageV413 . " material_class=" . material.cls . " live_uid=" . material.uid . " next=PICKUP_NEW_PORTAL")
    }
    finally
    {
        if (IsObject(ctx))
            DllCall("CloseHandle","Ptr",ctx.h)
        sigBackgroundV179 := oldBg
        GameItemActionEndV4("BOCube")
        if (!sigCancelV147)
            PickupEnabledSetV71(oldPickupV575,true,false)
    }
    return true
}

BOReturnFirstMaterialV477(r,ByRef pb,level,px,py)
{
    global sigBackgroundV179,scosEntryV162,pickupTimerBusy,sigBusyV147,sigCubeUiOpenV159
    if (pickupTimerBusy || sigBusyV147 || A_TickCount-r.boTransmuteAtV477<250)
        return false
    if (!GameItemActionBeginV4("BOReturnMaterial","cube"))
        return false
    ctx := false,previousBgV477 := sigBackgroundV179
    sigBackgroundV179 := true
    try
    {
        ctx := SigOpenContextV149()
        ctx.scosEntry := true,ctx.entryStateV42 := r,ctx.cubeUid := r.boReturnCubeUidV477
        livePathV478 := D2ReadU32(ctx.h,ctx.player+0x2C)
        if (!MonsterBossProbeReadV1(ctx.h,livePathV478,0x20,livePBV478)
            || CoordLevelV14(ctx.h,NumGet(livePBV478,0x1C,"UInt"))!=level)
            return false
        portalReadyV477 := false
        exitsV478 := ScanExitObjectsV363(ctx.h,livePBV478,NumGet(livePBV478,2,"UShort"),NumGet(livePBV478,6,"UShort"))
        for _,exitV477 in exitsV478
            if (!r.oldPortalsV413.HasKey(exitV477.typ . "|" . exitV477.uid)
                && (exitV477.typ=5 || exitV477.cls=59 || exitV477.cls=60))
            {
                portalReadyV477 := true
                break
            }
        if (!portalReadyV477)
        {
            PortalLogWriteV66("BO_RETURN_MATERIAL_WAIT reason=PORTAL_NOT_CONFIRMED objects=" . exitsV478.Length()
                . " room1=" . V92Hex(NumGet(livePBV478,0x1C,"UInt")) . " recube=OFF","BO_RETURN_MATERIAL_WAIT",1000)
            return false
        }
        ctx.returnHomesV265 := {}
        ctx.returnHomesV265[r.boFirstMaterialUidV475] := r.boFirstMaterialHomeV475
        allV477 := SigSnapshotV147(ctx),liveV477 := allV477[r.boFirstMaterialUidV475]
        cursorV477 := PickupCursorV4(ctx.h,ctx.inv)
        ownCursorV477 := IsObject(cursorV477) && cursorV477.unit && cursorV477.uid=r.boFirstMaterialUidV475
        if (IsObject(cursorV477) && cursorV477.unit && !ownCursorV477)
            return false
        if (ownCursorV477)
            liveV477 := cursorV477
        if (!ownCursorV477 && !(IsObject(liveV477) && liveV477.loc=0 && liveV477.owner=ctx.inv))
        {
            foundV477 := false
            for _,itemV477 in SigCubeItemsV147(ctx)
                if (itemV477.cls=8 && itemV477.q=7)
                    foundV477 := true
            if (!foundV477)
            {
                PortalLogWriteV66("BO_RETURN_MATERIAL_WAIT reason=LIVE_ITEM_NOT_READY recube=OFF","BO_RETURN_MATERIAL_WAIT",1000)
                return false
            }
            liveV477 := Ticket130RetainedV266(ctx,{uid:r.boFirstMaterialUidV475,cls:8,q:7})
            r.boFirstMaterialUidV475 := liveV477.uid
            r.boFirstMaterialHomeV475 := ctx.returnHomesV265[liveV477.uid]
        }
        if (!ownCursorV477 && liveV477.loc=3)
            sigCubeUiOpenV159 := true
        SigReturnV147(ctx,liveV477)
        SigCloseCubeV156()
        if (scosEntryV162!=r)
            return false
        r.phase := "PORTAL",r.portalAtV413 := A_TickCount
        PortalLogWriteV66("BO_FIRST_MATERIAL_RETURNED uid=" . liveV477.uid
            . " home=" . r.boFirstMaterialHomeV475.x . "," . r.boFirstMaterialHomeV475.y
            . " size=" . r.boFirstMaterialHomeV475.w . "x" . r.boFirstMaterialHomeV475.h
            . " method=VE139_RETAINED_HOME next=PICKUP_THEN_ENTER")
        return true
    }
    finally
    {
        if (IsObject(ctx))
            DllCall("CloseHandle","Ptr",ctx.h)
        sigBackgroundV179 := previousBgV477
        GameItemActionEndV4("BOReturnMaterial")
    }
}

BOEntranceFindV483(r,exits)
{
    pinned := r.boEntranceV483,best := false,bestDist := 1.0e30
    for _,a in exits
    {
        if (IsObject(pinned))
        {
            if (a.uid=pinned.uid && a.typ=pinned.typ && a.cls=pinned.cls)
            {
                r.boEntranceV483 := a
                return a
            }
            continue
        }
        if (r.oldPortalsV413.HasKey(a.typ . "|" . a.uid)
            || !(a.typ=5 || a.cls=59 || a.cls=60))
            continue
        dist := (a.x-r.boCubeX_V469)**2+(a.y-r.boCubeY_V469)**2
        if (dist<bestDist)
            best := a,bestDist := dist
    }
    if (IsObject(best))
    {
        r.boEntranceV483 := best
        PortalLogWriteV66("BO_PORTAL_PIN uid=" . best.uid . " type=" . best.typ
            . " xy=" . best.x . "," . best.y . " pending=UNTIL_CONFIRMED_TRANSFER")
    }
    return best
}

BOPortalCombatTickV483(r,ctx,player,ByRef pb)
{
    global stage2FlowV380,pickupTimerBusy,gameItemActionOwner
    if (r.boStageV413!=3 || pickupTimerBusy || gameItemActionOwner!="")
        return false
    if (!AutoMonsterPacketCleanupV1())
        return true
    s := IsObject(stage2FlowV380) ? stage2FlowV380.searchV430 : false
    if (!IsObject(s) || !BossSearchActiveV430(r.pid,r.fromLevelV413))
        return false
    scan := BossSearchScanV430(ctx.h,pb,s)
    if (!scan.known)
        return true
    radius := Max(1,MonsterRadiusGetV239()),target := false
    for _,a in scan.allV431
    {
        if (a.dist>radius*radius || (s.retryUIDs.HasKey(a.uid) && A_TickCount<s.retryUIDs[a.uid])
            || MonsterRetryExcludedV44(a.uid,a.x,a.y,a.level,r.pid))
            continue
        if (!IsObject(target) || a.dist<target.dist)
            target := a
    }
    if (!IsObject(target))
        return false
    r.stage1StuckV384 := false,r.last := 0
    mode := D2ReadU32(ctx.h,player+0x10)
    s.walkingV482 := mode=2 || mode=3 || mode=6
    if (!BOCombatStopWalkV482(ctx.h,player,pb,s))
        BossSearchHoldAttackV436(ctx.h,player,pb,s,target)
    PortalLogWriteV66("BO_PORTAL_COMBAT uid=" . target.uid . " distance=" . Round(Sqrt(target.dist),2)
        . " phase=PORTAL pending=KEPT next=RESUME_SAME_ENTRANCE","BO_PORTAL_COMBAT",1000)
    return true
}

BOConsumedPortalTransferV487(r,ctx,ByRef pb,level)
{
    global scosEntryV162,farmControlOwnerV186,ticketPickupWaitV279,pickupBackgroundV181
    if (scosEntryV162!=r || (r.boStageV413!=1 && r.boStageV413!=3)
        || !r.boCubeAttemptV487 || !r.fromLevelV413 || !level || FarmReviveTownLevelV295(level))
        return false
    room2 := D2ReadU32(ctx.h,NumGet(pb,0x1C,"UInt")+0x10)
    levelPtr := room2 ? D2ReadU32(ctx.h,room2+0x58) : 0
    if (level=r.fromLevelV413 && (!r.enterAtV413 || !r.fromLevelPtrV427 || !levelPtr || levelPtr=r.fromLevelPtrV427))
        return false
    previous := r.boStageV413
    r.boCubeConsumedV487 := true,r.boPortalPendingV487 := false,r.boCubeAttemptV487 := false
    r.boStageV413 := previous=1 ? 2 : 4
    r.phase := "EXIT_PORTAL",r.buffDoneV413 := false,r.boRouteReadyV419 := false
    r.boExitPortalV500 := false
    if (previous=1 || previous=3)
    {
        offsetV500 := Round(20/Sqrt(2))
        r.boExitPortalV500 := {level:level,x:NumGet(pb,2,"UShort")-offsetV500
            ,y:NumGet(pb,6,"UShort")-offsetV500,at:0}
        r.enterAtV413 := 0
        PortalLogWriteV66("BO_EXIT_PORTAL stage=" . r.boStageV413 . " target=" . r.boExitPortalV500.x . "," . r.boExitPortalV500.y
            . " direction=SCREEN_UP distance=20 next=WALK_THEN_BUFF")
    }
    if (r.boStageV413=4 && FarmFinalEntryPreparedV718(r,r.pid,level))
    {
        r.phase := "LOAD",r.buffDoneV413 := true,r.boExitPortalV500 := false
        PortalLogWriteV66("BO_FINAL_ENTRY buff=PREPARED_BEFORE_PORTAL next=FARM_NO_ARRIVAL_BUFF")
    }
    r.retryAtV237 := 0,r.errorTextV463 := "",r.errorAtV463 := 0,r.until := A_TickCount+3600000
    if (r.boPortalPickupBackgroundSavedV483)
        pickupBackgroundV181 := r.boPortalPickupBackgroundV468
    ticketPickupWaitV279 := false
    farmControlOwnerV186 := "BO"
    PickupEnabledSetV71(false,true,false)
    BOFarmMapRememberV417(r.boStageV413,level)
    FonInfoPushV385("[BO GĐ" . r.boStageV413 . "] Đã vào map " . level . " — cổng GĐ" . previous . " đã sử dụng")
    PortalLogWriteV66("BO_PORTAL_TRANSFER from=" . r.fromLevelV413 . " to=" . level
        . " completed_stage=" . previous . " next_stage=" . r.boStageV413 . " phase=" . r.phase . " material_check=OFF recube=0")
    return true
}

BOEntryTickV413(r,ctx,player,ByRef pb,level,px,py)
{
    global
    local target := false,a,all,uid,wanted,exitsV469,waitV468,sentV468,liveRoom2V427,liveLevelPtrV427
    if (level && scosEntryV162=r && BOConsumedPortalTransferV487(r,ctx,pb,level))
        return
    if (!level || scosEntryV162!=r || xRunning || zRunning || packetWatchArmedV1 || (gameItemActionOwner!="" && !(r.phase="PORTAL" && gameItemActionOwner="Pickup")))
        return
    if (r.phase="EXIT_PORTAL")
    {
        cainPauseFarmV361 := true
        exitV500 := r.boExitPortalV500
        if (!IsObject(exitV500) || level!=exitV500.level || !AutoMonsterPacketCleanupV1())
            return
        if ((px-exitV500.x)**2+(py-exitV500.y)**2>4)
        {
            if (!exitV500.at || A_TickCount-exitV500.at>=250)
            {
                sentV500 := NativeMovePointV14(r.pid,exitV500.x,exitV500.y,level,false,false,true,false,{entry:r})
                exitV500.at := A_TickCount
                PortalLogWriteV66("BO_EXIT_WALK stage=" . r.boStageV413 . " target=" . exitV500.x . "," . exitV500.y . " sent=" . sentV500
                    . " buff=WAIT portal_interact=OFF","BO_EXIT_WALK",1000)
            }
            return
        }
        modeV500 := D2ReadU32(ctx.h,player+0x10)
        if (modeV500=2 || modeV500=3 || modeV500=6)
        {
            NativeMovePointV14(r.pid,px,py,level,false,false,true,false,{entry:r,stop:true})
            return
        }
        if (modeV500!=1 && modeV500!=5)
            return
        r.phase := "LOAD",r.boArrivalXV472 := px,r.boArrivalYV472 := py
        r.stage1StuckV384 := false,r.last := 0
        PortalLogWriteV66("BO_EXIT_DONE stage=" . r.boStageV413 . " xy=" . px . "," . py . " next=BUFF_THEN_FARM portal_interact=OFF")
        return
    }
    if (r.phase="RETURN_MATERIAL")
    {
        BOReturnFirstMaterialV477(r,pb,level,px,py)
        return
    }
    if (r.phase="RECREATE")
    {
        PickupEnabledSetV71(false,true,false)
        FarmCastSyncV88(false)
        if (!AutoMonsterPacketCleanupV1() || pickupTimerBusy || sigBusyV147)
            return
        farmRestartReasonV238 := "COMPLETE"
        if (!StageTwoArmV166(true))
            return
        stageTwoV166.restartRunV17 := true
        if (!IsObject(mapWorkflowV185))
            mapWorkflowV185 := {map:"BO",stage:3,startLevel:level,testRows:0}
        MapStageSetV185(3)
        scosEntryV162 := false
        SetTimer, ScosEntryTimerV162, Off
        PortalLogWriteV66("BO_EXISTING_PORTAL_STAGE3 next=SAVE_EXIT_CREATE_RESTART_BO")
        return
    }
    if (r.phase="CUBE")
    {
        if (r.boCubeAttemptV487 && IsObject(r.oldPortalsV413))
        {
            target := BOEntranceFindV483(r,ScanExitObjectsV363(ctx.h,pb,px,py))
            if (r.boPortalPendingV487 || IsObject(target))
            {
                r.boPortalPendingV487 := true,r.phase := "PORTAL"
                PortalLogWriteV66("BO_CUBE_ALREADY_USED stage=" . r.boStageV413 . " next=ENTER_EXISTING_PORTAL recube=0")
                return
            }
        }
        cainPauseFarmV361 := true
        FarmCastSyncV88(false)
        if (r.boStageV413=1)
        {
            for _,a in ScanExitObjectsV363(ctx.h,pb,px,py)
                if (a.typ=2 && a.cls=60)
                {
                    r.phase := "RECREATE"
                    PortalLogWriteV66("BO_EXISTING_PORTAL_BEFORE_CUBE uid=" . a.uid
                        . " cube=SKIP enter=SKIP next=STAGE3_NEW_GAME")
                    return
                }
        }
        if (r.boStageV413=1)
        {
            if (!MapStage1SigReadyV374(r))
                return
            r.boStartSigAttemptedV467 := true
        }
        if (AutoMonsterPacketCleanupV1())
            BOCubePortalV413(r,level)
        return
    }
    if (r.phase="PORTAL")
    {
        liveRoom2V427 := D2ReadU32(ctx.h,NumGet(pb,0x1C,"UInt")+0x10)
        liveLevelPtrV427 := liveRoom2V427 ? D2ReadU32(ctx.h,liveRoom2V427+0x58) : 0
        r.until := Max(r.until,A_TickCount+60000)
        if (level!=r.fromLevelV413)
        {
            PortalLogWriteV66("BO_PORTAL_PENDING reason=OTHER_MAP_WITHOUT_CONFIRMED_ENTRANCE level=" . level
                . " source=" . r.fromLevelV413 . " stage=KEPT","BO_PORTAL_PENDING",1000)
            return
        }
        exitsV469 := ScanExitObjectsV363(ctx.h,pb,px,py)
        target := BOEntranceFindV483(r,exitsV469)
        if (BOPortalCombatTickV483(r,ctx,player,pb))
            return
        if ((!r.boPortalPickupStartedV468 || r.boPickupDoneV413) && A_TickCount-r.portalAtV413>45000)
        {
            r.portalAtV413 := A_TickCount
            PortalLogWriteV66("BO_PORTAL_PENDING reason=ENTER_DELAY stage=KEPT next=RETRY_SAME_ENTRANCE","BO_PORTAL_PENDING",1000)
        }
        if (!r.boPickupDoneV413)
        {
            if (!r.boPortalPickupStartedV468 || !IsObject(ticketPickupWaitV279)
                || ticketPickupWaitV279.pid!=r.pid || ticketPickupWaitV279.level!=level)
            {
                r.boPortalPickupStartedV468 := A_TickCount
                ticketPickupWaitV279 := {pid:r.pid,level:level,checks:0,emptyAt:0,done:false,scanAt:0,remaining:-1,active:true,resetProtectedV754:true,dropSerialV754:CubeResetProofSerialV754()}
                if (!pickupTimerBusy)
                    pickupRoundResetV1 := true
                if (!r.boPortalPickupBackgroundSavedV483)
                {
                    r.boPortalPickupBackgroundV468 := pickupBackgroundV181
                    r.boPortalPickupBackgroundSavedV483 := true
                }
                pickupBackgroundV181 := true
                if (!pickupImageOn)
                    PickupEnabledSetV71(true,true,false)
                PortalLogWriteV66("BO_PORTAL_PICKUP_BEGIN mode=ENTRY_SINGLE_TICK next=WAIT_FRESH_EMPTY_SCAN")
                return
            }
            if (!pickupImageOn)
            {
                PickupEnabledSetV71(true,true,false)
                pickupRoundResetV1 := true
                ticketPickupWaitV279 := {pid:r.pid,level:level,checks:0,emptyAt:0,done:false,scanAt:0,remaining:-1,active:true,resetProtectedV754:true,dropSerialV754:CubeResetProofSerialV754()}
                PortalLogWriteV66("BO_PORTAL_PICKUP_RESUME stage=KEPT next=FRESH_PICKUP_SCAN")
                return
            }
            if (!pickupTimerBusy && gameItemActionOwner="" && GameItemActionBeginV4("Pickup","cube"))
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
            waitV468 := ticketPickupWaitV279
            if (IsObject(waitV468) && waitV468.pid=r.pid && waitV468.level=level
                && waitV468.done && !pickupTimerBusy && A_TickCount-waitV468.scanAt<1000)
            {
                if (!CubeResetVerifiedV754(r.pid,level,waitV468.dropSerialV754))
                    return
                r.boPickupDoneV413 := true,r.portalAtV413 := A_TickCount
                PickupEnabledSetV71(false,true,false)
                pickupBackgroundV181 := r.boPortalPickupBackgroundV468
                ticketPickupWaitV279 := false
                PortalLogWriteV66("BO_PORTAL_PICKUP_DONE next=FIND_ENTRANCE")
                return
            }
            PortalLogWriteV66("BO_PORTAL_PICKUP_WAIT remaining=" . waitV468.remaining
                . " checks=" . waitV468.checks . " reason=" . waitV468.blockReasonV468
                . " pickup_on=" . pickupImageOn . " busy=" . pickupTimerBusy,"BO_PORTAL_PICKUP_WAIT",1000)
            if (A_TickCount-r.boPortalPickupStartedV468>120000)
            {
                r.boPortalPickupStartedV468 := A_TickCount
                PortalLogWriteV66("BO_PORTAL_PENDING reason=PICKUP_DELAY detail=" . waitV468.blockReasonV468
                    . " stage=KEPT next=CONTINUE_PICKUP_THEN_ENTER","BO_PORTAL_PENDING",1000)
            }
            return
        }
        if (pickupTimerBusy || gameItemActionOwner!="")
            return
        exitsV469 := ScanExitObjectsV363(ctx.h,pb,px,py)
        target := BOEntranceFindV483(r,exitsV469)
        if (!IsObject(target))
        {
            if (IsObject(r.boEntranceV483))
            {
                ScosEntryMoveV162(ctx,r.boEntranceV483.x,r.boEntranceV483.y)
                PortalLogWriteV66("BO_PORTAL_PENDING reason=ENTRANCE_TEMPORARILY_UNLOADED uid=" . r.boEntranceV483.uid
                    . " next=RETURN_TO_SAVED_ENTRANCE","BO_PORTAL_PENDING",1000)
            }
            else
                PortalLogWriteV66("BO_PORTAL_WAIT reason=NO_ENTRANCE objects=" . exitsV469.Length() . " pickup=DONE stage=KEPT","BO_PORTAL_WAIT",1000)
            return
        }
        if ((px-target.x)**2+(py-target.y)**2>100)
        {
            ScosEntryMoveV162(ctx,target.x,target.y)
            return
        }
        modeV499 := D2ReadU32(ctx.h,player+0x10)
        if (modeV499=2 || modeV499=3 || modeV499=6)
        {
            stoppedV499 := NativeMovePointV14(r.pid,px,py,level,false,false,true,false,{entry:r,stop:true})
            PortalLogWriteV66("BO_PORTAL_STOP_WALK uid=" . target.uid . " sent=" . stoppedV499 . " next=INTERACT_SAME_ENTRANCE","BO_PORTAL_STOP_WALK",1000)
            return
        }
        if (modeV499!=1 && modeV499!=5)
        {
            PortalLogWriteV66("BO_PORTAL_WAIT reason=PLAYER_BUSY mode=" . modeV499 . " stage=KEPT","BO_PORTAL_BUSY",1000)
            return
        }
        if (!r.enterAtV413 || A_TickCount-r.enterAtV413>=1500)
        {
            sentV468 := EnterPortalInteractV363(r.pid,level,target)
            PortalLogWriteV66("BO_PORTAL_ENTER uid=" . target.uid . " queued=" . sentV468,"BO_PORTAL_ENTER",1000)
            if (sentV468)
                r.enterAtV413 := A_TickCount
        }
        return
    }
    if (r.phase="LOAD")
    {
        cainPauseFarmV361 := true
        if (!IsObject(MapLiveIdentityV399(r.pid,level)))
        {
            MapLoadFailedStopV397("BO_LIVE_ROOM_READ_FAILED")
            return
        }
        if (scosEntryV162!=r)
            return
        if (r.boStageV413=4 && IsObject(stage2FlowV380))
            stage2FlowV380.searchV430 := false
        if (r.boStageV413!=4)
            r.boRouteReadyV419 := true
        if (!r.buffDoneV413)
        {
            PortalLogWriteV66("BO_BUFF_POSITION stage=" . r.boStageV413 . " current=" . px . "," . py
                . " arrival=" . r.boArrivalXV472 . "," . r.boArrivalYV472 . " movement=BLOCKED","BO_BUFF_POSITION",1000)
            if (!RouteBuffSequenceV20(ctx.h,player,r.pid,true))
            {
                PortalLogWriteV66("BO_BUFF_WAIT stage=" . r.boStageV413 . " level=" . level
                    . " route_ready=1 farm=OFF","BO_BUFF_WAIT",1000)
                return
            }
            if (scosEntryV162!=r || cainPausedV10)
                return
            r.buffDoneV413 := true
            PortalLogWriteV66("BO_BUFF_DONE stage=" . r.boStageV413 . " next=FARM_ITEM")
        }
        if (r.boStageV413=4 && !r.boRouteReadyV419)
        {
            if (!Stage2MapWaitV381(r.pid,level,true))
                return
            if (scosEntryV162!=r)
                return
            r.boRouteReadyV419 := true
            PortalLogWriteV66("BO_FINAL_ROUTE_READY level=" . level . " start_row=" . FarmStartRowV394()
                . " next=STANDARD_FARM_ITEM_ROUTE")
        }
        wanted := r.boStageV413=2 ? 668 : 1825
        flowStartedV30 := r.boStageV413=4 ? FarmItemFlowBeginV427(wanted,7,false)
            : FarmBossItemBeginV430(wanted,7,false)
        if (!flowStartedV30)
        {
            MapLoadFailedStopV397(r.boStageV413=4 ? "BO_FINAL_ROUTE_FARM_START_FAILED" : "BO_BOSS_SEARCH_START_FAILED")
            return
        }
        r.oldItemsV413 := {}
        ctx.player := player,ctx.inv := D2ReadU32(ctx.h,player+0x60)
        for uid,a in SigSnapshotV147(ctx)
            if (a.cls=wanted && a.q=7)
                r.oldItemsV413[uid] := true
        r.phase := "FARM",r.farmLevelV413 := level
        if (r.boStageV413=4)
            r.boBossKilledV454 := false,r.boFinalPickupPreparedV454 := false,r.boFinalSortedV454 := false
        farmStage2DoneV372 := false
        mapStage1BuffDoneV248 := {pid:r.pid,map:"BO",level:level,buffDone:true}
        MapStageSetV185(2)
        autoMonsterAttackOn := true,scosStartFarmV162 := true
        try
            Gosub, AutoMonsterAttackToggle
        finally
            scosStartFarmV162 := false,mapStage1BuffDoneV248 := false
        if (scosEntryV162!=r || !autoMonsterAttackOn)
            return
        cainPauseFarmV361 := false
        if (r.boStageV413=4)
            PortalLogWriteV66("BO_FINAL_BOSS_HUNT route=SAVED_XY boss=1584 lock=UNTIL_DEAD pickup=AFTER_DEATH item=1825/07")
        FonInfoPushV385("[BO GĐ" . r.boStageV413 . "] Farm + nhặt " . wanted . "/07")
        return
    }
    if (r.phase="FARM")
    {
        if (!FarmItemFlowDoneV427())
        {
            return
        }
        cainPauseFarmV361 := true
        FarmCastSyncV88(false)
        PickupEnabledSetV71(false,true,false)
        if (r.boStageV413=2)
        {
            r.boStageV413 := 3,r.phase := "CUBE"
            r.boCubeAttemptV487 := false,r.boPortalPendingV487 := false,r.boCubeConsumedV487 := false
            r.fromLevelV413 := 0,r.fromLevelPtrV427 := 0,r.enterAtV413 := 0
            return
        }
        r.phase := "TOWN"
    }
    if (r.phase="TOWN")
    {
        if (!IsObject(stage2FlowV380) || !stage2FlowV380.done
            || !Stage2ItemNewInCubeV420(ctx.h,player,stage2FlowV380,true,true))
        {
            r.phase := "FARM"
            if (IsObject(stage2FlowV380))
                stage2FlowV380.done := false
            cainPauseFarmV361 := false
            PickupEnabledSetV71(true,true,false)
            return
        }
        if (pickupTimerBusy || !AutoMonsterPacketCleanupV1())
            return
        if (IsObject(farmStage2DoneV372))
            farmStage2DoneV372.handled := true
        scosEntryV162 := false
        SetTimer, ScosEntryTimerV162, Off
        cainPauseFarmV361 := false
        if (FarmStage3RequestV313("COMPLETE"))
        {
            PortalLogWriteV66("BO_DONE item=1825/07 next=STAGE3_DLL no_town=1")
            return
        }
        FarmErrorKeepV769("BO_STAGE3_HANDOFF_FAILED")
        FarmCombatYieldV237()
        PickupEnabledSetV71(false,true,false)
        farmRestartReasonV238 := ""
        ToolTipInfoV386("BO: đã có vật cuối — giữ phiên farm, chờ xử lý chuyển bước.")
        SetTimer, RemoveToolTip, -4000
        PortalLogWriteV66("BO_DONE item=1825/07 next=ERROR_KEEP_FARM")
        return
    }
}

BOFarmMapRememberV417(stage,level)
{
    global currentProfile
    if ((stage!=2 && stage!=4) || !level || FarmReviveTownLevelV295(level))
        return false
    section := ProfileSection(currentProfile),key := "BOFarmLevel" . stage
    IniWrite, %level%, % ProfileConfigPathV364(section), %section%, %key%
    return !ErrorLevel
}

Stage2CommonPickupTargetV420(cls,q)
{
    global farmControlOwnerV186,stage2FlowV380,backgroundPidV63
    r := stage2FlowV380
    return IsObject(r) && r.owner=farmControlOwnerV186
        && r.pid=backgroundPidV63 && r.mode="ITEM" && !r.done
        && cls=r.itemClass && q+0=r.itemData
}

Stage2ItemCubeBaselineV420(h,player,r)
{
    inv := player ? D2ReadU32(h,player+0x60) : 0
    first := inv ? D2ReadU32(h,inv+0x10) : 0
    cursor := inv ? PickupCursorV4(h,inv) : false
    if (!first || !IsObject(cursor) || cursor.unit)
        return false
    all := V9SnapshotAllItems({h:h,inv:inv,first:first})
    if (!IsObject(all))
        return false
    r.initialItemUIDsV420 := {}
    for uid,item in all
        if (item.cls=r.itemClass && item.data && D2ReadU8V18(h,item.data)=r.itemData
            && (item.loc=3 || (item.loc=0 && item.owner=inv)))
            r.initialItemUIDsV420[uid] := true
    return true
}

Stage2ItemNewInCubeV420(h,player,r,allowExisting := false,requireNew := false)
{
    if ((!allowExisting || requireNew) && !IsObject(r.initialItemUIDsV420))
        return false
    inv := player ? D2ReadU32(h,player+0x60) : 0
    first := inv ? D2ReadU32(h,inv+0x10) : 0
    cursor := inv ? PickupCursorV4(h,inv) : false
    if (!first || !IsObject(cursor) || cursor.unit)
        return false
    all := V9SnapshotAllItems({h:h,inv:inv,first:first})
    if (!IsObject(all))
        return false
    for uid,item in all
        if (item.cls=r.itemClass && item.data
            && (item.loc=3 || ((allowExisting || FinalQuestItemV511(h,item)) && item.loc=0 && item.owner=inv))
            && D2ReadU8V18(h,item.data)=r.itemData && ((allowExisting && !requireNew) || !r.initialItemUIDsV420.HasKey(uid)))
        {
            r.completedItemUIDV420 := uid
            return true
        }
    return false
}

; ===== V843: isolated special map matching; loader for other maps is V68 =====

MapCollisionSampleV821(h,room1,rectKey)
{
    if (room1<0x10000)
        return false
    coll := D2ReadU32(h,room1+0x20)
    if (coll<0x10000)
        return false
    cx := D2ReadU32(h,coll),cy := D2ReadU32(h,coll+4)
    w := D2ReadU32(h,coll+8),hh := D2ReadU32(h,coll+12)
    mapPtr := D2ReadU32(h,coll+0x20)
    rect := StrSplit(rectKey,"_")
    ; Reject unexpected headers so a memory pointer cannot be treated as a map.
    if (rect.Length()!=4 || cx!=rect[1]+0 || cy!=rect[2]+0
        || w!=rect[3]+0 || hh!=rect[4]+0
        || w<1 || hh<1 || w>200 || hh>200 || mapPtr<0x10000)
        return false
    bytesCount := Min(2048,w*hh*2)
    VarSetCapacity(bytes,bytesCount,0),got := 0
    if (!DllCall("ReadProcessMemory","Ptr",h,"Ptr",mapPtr,"Ptr",&bytes
        ,"UPtr",bytesCount,"UPtr*",got) || got!=bytesCount)
        return false
    hash := 2166136261
    Loop, %bytesCount%
        hash := Mod((hash ^ NumGet(bytes,A_Index-1,"UChar"))*16777619,4294967296)
    return {hash:Format("{:08X}",hash),bytes:bytesCount}
}

MapCollisionSnapshotV821(pid,level,requiredLevelPtr := 0)
{
    if (!pid || !(level=39 || level=183 || level=184 || (level>=263 && level<=266)))
        return false
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        r1 := path ? D2ReadU32(h,path+0x1C) : 0
        r2 := r1 ? D2ReadU32(h,r1+0x10) : 0
        lp := r2 ? D2ReadU32(h,r2+0x58) : 0
        if (!lp || (requiredLevelPtr && lp!=requiredLevelPtr)
            || D2ReadU32(h,lp+0x1D0)!=level)
            return false
        expected := D2ReadU32(h,lp+0x08)
        address := D2ReadU32(h,lp+0x10)
        if (expected<1 || expected>4096 || address<0x10000)
            return false
        snapshot := {level:level,levelPtr:lp,totalRooms:expected,hashes:{}
            ,loadedRooms:0,failedSamples:0,chainRooms:0
            ,seedA:D2ReadU32(h,lp+0x1C4),seedB:D2ReadU32(h,lp+0x1C8)}
        seen := {},start := A_TickCount
        while (address)
        {
            if (seen.HasKey(address) || seen.Count()>=4096 || A_TickCount-start>3500)
                return false
            seen[address] := true
            if (!MonsterBossProbeReadV1(h,address,0x60,b)
                || NumGet(b,0x58,"UInt")!=lp)
                return false
            x := NumGet(b,0x34,"UInt")*5,y := NumGet(b,0x38,"UInt")*5
            w := NumGet(b,0x3C,"UInt")*5,hh := NumGet(b,0x40,"UInt")*5
            if (!w || !hh || w>1000 || hh>1000)
                return false
            key := x . "_" . y . "_" . w . "_" . hh
            loadedR1 := NumGet(b,0x30,"UInt")
            if (loadedR1>=0x10000 && D2ReadU32(h,loadedR1+0x10)=address)
            {
                snapshot.loadedRooms++
                sample := MapCollisionSampleV821(h,loadedR1,key)
                if (IsObject(sample))
                    snapshot.hashes[key] := sample
                else
                    snapshot.failedSamples++
            }
            address := NumGet(b,0x24,"UInt")
        }
        snapshot.chainRooms := seen.Count()
        if (snapshot.chainRooms!=expected || !seen.HasKey(r2))
            return false
        endR1 := D2ReadU32(h,path+0x1C)
        endR2 := endR1 ? D2ReadU32(h,endR1+0x10) : 0
        if (!endR2 || D2ReadU32(h,endR2+0x58)!=lp)
            return false
        return snapshot
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

; LIB 130/133/136/139: chon INI CHI MOT LAN luc vua vao cong.
; Map duoc luu trong RAM kem mapId + diem + dong vang. Ve town/chet/qua cong
; ve LAI cung map: khong matching room, khong tu load file tu vi tri hien tai.
LibFarmPinMatchesV2026(pid,level)
{
    global libFarmPinnedMapV2026,currentProfile,libScrollTierV290
    p := libFarmPinnedMapV2026
    return (level>=263 && level<=266) && IsObject(p) && p.pid=pid && p.level=level
        && p.birth=BackgroundBirthV63(pid) && p.profile=currentProfile
        && p.tier=libScrollTierV290 && IsObject(p.points) && p.points.Length()>0
}

LibFarmEntryReadyV2026(pid,level,levelPtr,x,y)
{
    global lib263EntryV841
    e := lib263EntryV841
    ; Khong su dung toa do nhan vat da chay xa de doan file ban do.
    return (level>=263 && level<=266) && IsObject(e) && e.from103
        && e.pid=pid && e.level=level && e.levelPtr=levelPtr
        && A_TickCount-e.at<=15000
        && (x-e.x)**2+(y-e.y)**2<=30*30
}

LibFarmPinSaveV2026(pid,level,levelPtr)
{
    global libFarmPinnedMapV2026,currentProfile,libScrollTierV290
    global coordSavedV15,routeMapIdV21,coordYellowRowV350,coordMapStateV381
    ; Core da xac nhan portal-entry luc bat dau load + verify cung level o cuoi.
    ; Khong kiem tra lai timeout 15s sau khi doc file/hinh hoc mat thoi gian.
    if (!IsObject(coordSavedV15) || !coordSavedV15.Length())
        return false
    file := IsObject(coordMapStateV381) ? coordMapStateV381.fileV10 : ""
    stamp := IsObject(coordMapStateV381) ? coordMapStateV381.fileStampV10 : ""
    row := Max(1,Min(coordSavedV15.Length(),coordYellowRowV350))
    libFarmPinnedMapV2026 := {pid:pid,birth:BackgroundBirthV63(pid),profile:currentProfile
        ,tier:libScrollTierV290,level:level,mapId:routeMapIdV21,levelPtr:levelPtr
        ,points:coordSavedV15.Clone(),yellow:row,file:file,stamp:stamp}
    PortalLogWriteV66("LIB_FON_PIN_FIRST level=" . level . " tier=" . libScrollTierV290
        . " map=" . routeMapIdV21 . " points=" . coordSavedV15.Length()
        . " yellow=" . row . " next=YELLOW_ONLY")
    return true
}

LibFarmPinYellowV2026(pid,level)
{
    global libFarmPinnedMapV2026,coordRouteV16,coordYellowRowV350,routeMapIdV21
    if (!LibFarmPinMatchesV2026(pid,level))
        return false
    p := libFarmPinnedMapV2026
    if (routeMapIdV21!=p.mapId)
        return false
    r := coordRouteV16
    row := IsObject(r) && r.pid=pid && r.startLevel=level && r.yellow>=1
        ? r.yellow : coordYellowRowV350
    if (row>=1 && row<=p.points.Length() && row>p.yellow)
    {
        p.yellow := row
        PortalLogWriteV66("LIB_FON_YELLOW_ONLY level=" . level . " map=" . p.mapId
            . " yellow=" . p.yellow, "LIB_FON_YELLOW", 350)
    }
    return true
}

LibFarmPinRestoreV2026(pid,level,levelPtr:=0)
{
    global libFarmPinnedMapV2026,currentProfile,routeMapIdV21,coordSavedV15
    global coordPointLevelV14,coordPointTextV14,coordMapReadyV381,coordMapStateV381
    global coordMapSerialV381,coordYellowRowV350,coordPinnedYellowV136
    global coordLiveYellowV128,coordNearbyRowV18,coordManualRowV59,fonCursorV724
    global coordMapAcceptedV381,routePreviewV401,mapLoadFailureV402,roomMapSelectionResetV111
    if (!LibFarmPinMatchesV2026(pid,level))
        return false
    p := libFarmPinnedMapV2026
    identity := MapLiveIdentityV399(pid,level)
    if (!IsObject(identity) || (levelPtr && identity.levelPtr!=levelPtr))
        return false
    good := coordMapReadyV381 && IsObject(coordMapStateV381) && coordMapStateV381.loaded
        && coordMapStateV381.pid=pid && coordMapStateV381.level=level
        && coordMapStateV381.levelPtrV395=identity.levelPtr
        && coordMapStateV381.mapId=p.mapId && routeMapIdV21=p.mapId
        && IsObject(coordSavedV15) && coordSavedV15.Length()=p.points.Length()
        && coordSavedV15[1].x=p.points[1].x && coordSavedV15[1].y=p.points[1].y
    if (good)
    {
        LibFarmPinYellowV2026(pid,level)
        return true
    }
    ; Sau ve town / load map khac, khoi phuc CHINH mapId + points da khoa.
    ; Khong chay FonLoadMapCore, RoomMapRead, Lib263Pick hay MapGatesFilter.
    routeMapIdV21 := p.mapId,coordSavedV15 := p.points.Clone()
    coordPointLevelV14 := level
    coordPointTextV14 := coordSavedV15[1].x . "," . coordSavedV15[1].y
    yellow := Max(1,Min(coordSavedV15.Length(),p.yellow))
    coordYellowRowV350 := yellow,coordLiveYellowV128 := yellow
    coordPinnedYellowV136 := yellow,coordNearbyRowV18 := yellow,coordManualRowV59 := yellow
    coordMapSerialV381 += 1
    coordMapStateV381 := {key:pid . "|" . currentProfile . "|" . level
        ,pid:pid,level:level,profile:currentProfile,loaded:true,mapId:p.mapId
        ,retryAt:0,serial:coordMapSerialV381,levelPtrV395:identity.levelPtr
        ,fileV10:p.file,fileStampV10:p.stamp,layoutV841:"",layoutCheckedAtV841:A_TickCount}
    coordMapReadyV381 := true,coordMapAcceptedV381 := false
    routePreviewV401 := false,mapLoadFailureV402 := false,roomMapSelectionResetV111 := false
    fonCursorV724 := {pid:pid,birth:BackgroundBirthV63(pid),profile:currentProfile
        ,level:level,mapId:p.mapId,levelPtr:identity.levelPtr,row:yellow
        ,playerX:identity.x,playerY:identity.y,count:p.points.Length()
        ,firstX:p.points[1].x,firstY:p.points[1].y
        ,lastX:p.points[p.points.Length()].x,lastY:p.points[p.points.Length()].y}
    FonLoadErrorHideV385()
    PortalLogWriteV66("LIB_FON_RESTORE_PIN level=" . level . " tier=" . p.tier
        . " map=" . p.mapId . " yellow=" . yellow . " reason=RETURN_FROM_PORTAL reload=NO")
    CoordBoxRefreshV15(true)
    return true
}

Lib263EntryObserveV841(pid,level,x,y,levelPtr)
{
    global lib263EntryV841
    static previousPid := 0,previousLevel := 0
    if (level>=263 && level<=266 && pid && levelPtr && x && y)
    {
        if (!IsObject(lib263EntryV841) || lib263EntryV841.pid!=pid
            || lib263EntryV841.level!=level || lib263EntryV841.levelPtr!=levelPtr)
        {
            lib263EntryV841 := {pid:pid,level:level,levelPtr:levelPtr,x:x,y:y
                ,at:A_TickCount,from103:(previousPid=pid && previousLevel=103) ? 1 : 0}
            PortalLogWriteV66("LIB_ENTRY_CAPTURE level=" . level . " xy=" . x . "," . y
                . " from103=" . lib263EntryV841.from103 . " level_ptr=" . V92Hex(levelPtr))
        }
    }
    else if (level<263 || level>266)
        lib263EntryV841 := false
    previousPid := pid,previousLevel := level
}

Lib263AnchorV841(pid,levelPtr,x,y)
{
    global lib263EntryV841
    if (IsObject(lib263EntryV841) && lib263EntryV841.pid=pid
        && lib263EntryV841.levelPtr=levelPtr)
        return lib263EntryV841
    ; First load is protected by LibFarmEntryReadyV2026. Never infer a new
    ; layout from a position far inside the dungeon.
    return {pid:pid,levelPtr:levelPtr,x:x,y:y,from103:0}
}

Lib263PickV841(candidates,pid,levelPtr,x,y)
{
    global currentProfile
    if (!IsObject(candidates) || !candidates.Length())
        return false
    anchor := Lib263AnchorV841(pid,levelPtr,x,y)
    primary := [],others := []
    for _,entry in candidates
    {
        file := RoomProfileFileV108(currentProfile,entry.id)
        SplitPath, file,,,,stem
        ; The five known LIB layouts win over duplicate 130-map archives.
        if (RegExMatch(stem,"i)^LIB-Map263-[1-5]$"))
            primary.Push(entry)
        else
            others.Push(entry)
    }
    if (primary.Length())
    {
        chosen := Lib263PickFromListV841(primary,anchor)
        if (IsObject(chosen))
            return chosen
    }
    return Lib263PickFromListV841(others,anchor)
}

Lib263PickFromListV841(candidates,anchor)
{
    best := false,bestD2 := 1.0e30,secondD2 := 1.0e30
    for _,entry in candidates
    {
        if (!IsObject(entry.data) || !IsObject(entry.data.points) || !entry.data.points.Length())
            continue
        pt := entry.data.points[1]
        d2 := (anchor.x-pt.x)*(anchor.x-pt.x)+(anchor.y-pt.y)*(anchor.y-pt.y)
        PortalLogWriteV66("LIB263_ENTRY_COMPARE route_id=" . entry.id
            . " spawn=" . anchor.x . "," . anchor.y
            . " saved_first=" . pt.x . "," . pt.y
            . " dist=" . Round(Sqrt(d2),2))
        if (d2<bestD2)
            secondD2 := bestD2,bestD2 := d2,best := entry
        else if (d2<secondD2)
            secondD2 := d2
    }
    if (!IsObject(best) || bestD2>30*30
        || (secondD2<1.0e29 && Sqrt(secondD2)-Sqrt(bestD2)<12))
        return false
    PortalLogWriteV66("LIB263_ENTRY_PICK route_id=" . best.id
        . " distance=" . Round(Sqrt(bestD2),2) . " from103=" . anchor.from103)
    return best
}

ScosFixedPickV841(candidates,currentId)
{
    if (!IsObject(candidates) || !candidates.Length())
        return false
    for _,entry in candidates
        if (entry.id=currentId)
            return entry
    return candidates.Length()=1 ? candidates[1] : false
}

BoHashThresholdGetV830()
{
    global currentProfile,boHashThresholdV830
    section := ProfileSection(currentProfile)
    IniRead, saved, % ProfileConfigPathV364(section), %section%, BoHashThreshold, 80
    if (!RegExMatch(saved,"^\d+$") || saved<1 || saved>100)
        saved := 80
    boHashThresholdV830 := saved+0
    return boHashThresholdV830
}

BoHashListFromSnapshotV830(snapshot)
{
    list := []
    if (!IsObject(snapshot) || !IsObject(snapshot.hashes))
        return list
    text := ""
    for rect,sample in snapshot.hashes
        if (IsObject(sample) && RegExMatch(sample.hash,"^[A-Fa-f0-9]{8}$"))
        {
            hashInputV834 := sample.hash
            StringUpper, upperHashV834, hashInputV834
            text .= upperHashV834 . "`n"
        }
    Sort, text
    Loop, Parse, text, `n, `r
        if (A_LoopField!="")
            list.Push(A_LoopField)
    return list
}

BoHashReadV830(file,level)
{
    if (!FileExist(file))
        return false
    ; Check an independent HASH index first, then legacy embedded INI metadata.
    indexV846 := file . ".hash.ini"
    if (FileExist(indexV846))
        file := indexV846
    section := "HashRecognition-" . level
    IniRead, readLevel, %file%, %section%, LevelID, -1
    IniRead, readRooms, %file%, %section%, TotalRooms, -1
    IniRead, readMax, %file%, %section%, TongHashMax, -1
    IniRead, readOriginal, %file%, %section%, OriginalHashCount, -1
    IniRead, readCount, %file%, %section%, StableCount, -1
    if (readLevel!=level || readRooms<1 || readMax<1 || readOriginal<1
        || readMax!=readOriginal || readCount<1 || readCount>readMax)
        return false
    hashes := []
    Loop, %readCount%
    {
        key := "H_" . A_Index
        IniRead, value, %file%, %section%, %key%, ERROR
        if (!RegExMatch(value,"^[A-Fa-f0-9]{8}$"))
            return false
        StringUpper, upperHashV834, value
        hashes.Push(upperHashV834)
    }
    return {rooms:readRooms+0,max:readMax+0,hashes:hashes}
}

BoHashOverlapV830(known,observed,ByRef common)
{
    common := [],stock := {},found := 0
    for _,hash in observed
        stock[hash] := (stock.HasKey(hash) ? stock[hash] : 0)+1
    for _,hash in known
        if (stock.HasKey(hash) && stock[hash]>0)
        {
            stock[hash]--
            common.Push(hash)
            found++
        }
    return found
}

BoHashFindV830(snapshot,forRecord := 1)
{
    global routeMapsV21,currentProfile
    if (!IsObject(snapshot) || (snapshot.level!=39 && snapshot.level!=183 && snapshot.level!=184)
        || !IsObject(snapshot.hashes))
        return {status:"NO_DATA"}
    observed := BoHashListFromSnapshotV830(snapshot)
    count := observed.Length()
    if (!count)
        return {status:"NO_DATA"}
    ; V849: H% belongs ONLY to the TẠO / recording path.
    ; Loading requires the entire saved stable HASH multiset to be present.
    if (forRecord)
        pct := BoHashThresholdGetV830()
    best := false, bestScore := -1, ties := 0
    for _,entry in routeMapsV21
    {
        file := RoomProfileFileV108(currentProfile,entry.id)
        if (!FonFileAllowedV846(file,snapshot.level))
            continue
        ; Loading must ignore HASH sidecars whose route INI has no saved points.
        ; A newly created but unfinished map is RECORD-only, not a load target.
        if (!forRecord)
        {
            routeV852 := RoomMapReadV109(file,false,snapshot.level)
            if (!IsObject(routeV852) || !routeV852.points.Length())
                continue
        }
        saved := BoHashReadV830(file,snapshot.level)
        if (!IsObject(saved))
        {
            PortalLogWriteV66("HASH_SKIP level=" . snapshot.level . " id=" . entry.id . " reason=NO_SIGNATURE file=" . file)
            continue
        }
        if (forRecord && (saved.rooms!=snapshot.totalRooms || saved.max!=count))
        {
            PortalLogWriteV66("HASH_SKIP level=" . snapshot.level . " id=" . entry.id
                . " reason=COUNT_MISMATCH rooms=" . saved.rooms . "/" . snapshot.totalRooms
                . " hashes=" . saved.max . "/" . count)
            continue
        }
        n := BoHashOverlapV830(saved.hashes,observed,common)
        if (!forRecord)
        {
            ; Only HASH values decide the load: do not apply H%, room counts,
            ; or original hash-count gates here. Compare as a multiset so a
            ; repeated saved HASH must occur that many times in live data.
            PortalLogWriteV66("HASH_LOAD_COMPARE id=" . entry.id . " level=" . snapshot.level
                . " saved_stable=" . saved.hashes.Length() . " matched=" . n
                . " live_hashes=" . count . " rule=ALL_SAVED_HASH_VALUES")
            if (n!=saved.hashes.Length())
                continue
            ; Multiple matching signatures are ambiguous; never pick arbitrarily.
            ties++
            if (!IsObject(best))
                best := {status:"MATCH",id:entry.id,file:file,snapshot:snapshot}
            continue
        }
        ; TẠO: keep the exact original room/hash counts and original-max
        ; denominator when applying H% and filtering stable values.
        score := 100.0*n/saved.max
        PortalLogWriteV66("HASH_CREATE_COMPARE id=" . entry.id . " level=" . snapshot.level . " rooms=" . snapshot.totalRooms
            . " total_hash=" . count . " saved_stable=" . saved.hashes.Length()
            . " matched=" . n . " pct=" . Round(score,2) . " threshold=" . pct)
        if (score+0.00001<pct)
            continue
        if (score>bestScore+0.00001)
        {
            best := {status:"MATCH",id:entry.id,file:file,common:common,score:score,snapshot:snapshot}
            bestScore := score,ties := 1
        }
        else if (Abs(score-bestScore)<0.00001)
            ties++
    }
    if (ties>1)
        return {status:"AMBIGUOUS",matches:ties}
    if (IsObject(best))
        return best
    return {status:"NEW",snapshot:snapshot,observed:observed}
}

; V852: only the BO level uses a guarded, read-only partial HASH fallback.
; When the player returns from town, collision samples from distant rooms
; may be unloaded even though the same Room2 map layout still exists.
; Never choose a map based on the geometry alone or an ambiguous match.
BoHashLoadPartialV852(snapshot,candidates,pid)
{
    global currentProfile
    if (!IsObject(snapshot) || snapshot.level!=39 || !IsObject(candidates)
        || !candidates.Length() || !pid || !IsObject(snapshot.hashes))
        return {status:"NO_DATA"}
    liveV852 := MapRoomLayoutReadV270(pid,39)
    if (!IsObject(liveV852) || liveV852.partial || liveV852.layout=""
        || liveV852.levelPtr!=snapshot.levelPtr)
    {
        PortalLogWriteV66("HASH_PARTIAL_WAIT level=39 reason=LIVE_LAYOUT_NOT_READY", "HASH_PARTIAL_WAIT",2000)
        return {status:"NOT_READY"}
    }
    observedV852 := BoHashListFromSnapshotV830(snapshot)
    if (!observedV852.Length())
        return {status:"NO_DATA"}
    chosenV852 := false,matchesV852 := 0
    for _,candidateV852 in candidates
    {
        dataV852 := candidateV852.data
        if (!IsObject(dataV852) || dataV852.partial || dataV852.roomLayout=""
            || dataV852.roomLayout!=liveV852.layout)
            continue
        fileV852 := RoomProfileFileV108(currentProfile,candidateV852.id)
        savedV852 := BoHashReadV830(fileV852,39)
        if (!IsObject(savedV852) || savedV852.rooms!=snapshot.totalRooms)
            continue
        matchedV852 := BoHashOverlapV830(savedV852.hashes,observedV852,commonV852)
        ; Require 70% of the smaller HASH set, with at least four samples
        ; when available. Layout equality is an additional independent guard.
        smallerV852 := Min(savedV852.hashes.Length(),observedV852.Length())
        neededV852 := Max(Min(4,smallerV852),Ceil(smallerV852*0.70))
        PortalLogWriteV66("HASH_PARTIAL_COMPARE level=39 id=" . candidateV852.id
            . " saved=" . savedV852.hashes.Length() . " live=" . observedV852.Length()
            . " matched=" . matchedV852 . " needed=" . neededV852
            . " rooms=" . snapshot.totalRooms . " layout=EXACT")
        if (matchedV852<neededV852)
            continue
        matchesV852++
        chosenV852 := candidateV852
    }
    if (matchesV852>1)
    {
        PortalLogWriteV66("HASH_PARTIAL_REJECT level=39 reason=AMBIGUOUS matches=" . matchesV852)
        return {status:"AMBIGUOUS",matches:matchesV852}
    }
    if (matchesV852=1)
    {
        PortalLogWriteV66("HASH_PARTIAL_MATCH level=39 id=" . chosenV852.id
            . " method=HASH_PLUS_EXACT_FULL_LAYOUT")
        return {status:"MATCH",id:chosenV852.id}
    }
    return {status:"NEW"}
}

BoHashWriteV830(file,snapshot,stable,originalCount)
{
    if (!FileExist(file) || !IsObject(snapshot) || !IsObject(stable)
        || stable.Length()<1 || originalCount<stable.Length())
        return false
    ; Never modify the user's route INI: only maintain the independent HASH index.
    indexV846 := file . ".hash.ini"
    temp := indexV846 . ".tmp"
    if (FileExist(temp))
        FileDelete, %temp%
    section := "HashRecognition-" . snapshot.level
    IniWrite, BO_FNV32_MULTISET_V830, %temp%, %section%, Format
    IniWrite, % snapshot.level, %temp%, %section%, LevelID
    IniWrite, % snapshot.totalRooms, %temp%, %section%, TotalRooms
    IniWrite, % originalCount, %temp%, %section%, TongHashMax
    IniWrite, % originalCount, %temp%, %section%, OriginalHashCount
    count := stable.Length()
    IniWrite, %count%, %temp%, %section%, StableCount
    for i,hash in stable
    {
        key := "H_" . i
        IniWrite, %hash%, %temp%, %section%, %key%
        if (ErrorLevel)
            return false
    }
    IniRead, verifyCount, %temp%, %section%, StableCount, ERROR
    IniRead, verifyMax, %temp%, %section%, TongHashMax, ERROR
    if (verifyCount!=count || verifyMax!=originalCount)
        return false
    FileMove, %temp%, %indexV846%, 1
    return !ErrorLevel
}

BoHashAutoTargetV830(pid,level)
{
    global currentProfile,routeMapIdV21,routeMapNextV21,routeMapsV21,coordPointLevelV14
    if (!pid || (level!=39 && level!=183 && level!=184))
        return false
    RoomMapsSyncV110(true,level)
    snapshot := MapCollisionSnapshotV821(pid,level)
    result := BoHashFindV830(snapshot)
    if (!IsObject(result) || result.status="NO_DATA")
    {
        ToolTipInfoV386("Chưa lấy được HASH tầng " . level . "; chưa tạo map khi thiếu dữ liệu.")
        SetTimer, RemoveToolTip, -4500
        return false
    }
    if (result.status="AMBIGUOUS")
    {
        ToolTipInfoV386("HASH đạt ngưỡng ở nhiều map. Không lọc/tạo map để tránh nhầm.")
        SetTimer, RemoveToolTip, -4000
        return false
    }
    if (result.status="MATCH")
    {
        saved := BoHashReadV830(result.file,level)
        if (!IsObject(saved) || !RouteMapActivateV21(result.id))
        {
            ToolTipInfoV386("Không chọn được INI HASH đã nhận diện; giữ nguyên dữ liệu.")
            return false
        }
        if (!BoHashWriteV830(result.file,snapshot,result.common,saved.max))
        {
            ToolTipInfoV386("Đã chọn INI, nhưng lỗi lưu bộ HASH. Bộ cũ được giữ.")
            return false
        }
        PortalLogWriteV66("HASH_REUSE level=" . level . " id=" . result.id . " pct=" . Round(result.score,2)
            . " stable=" . result.common.Length() . " hash_max=" . saved.max . " file=" . result.file)
        return true
    }
    ; Before creating a blank file, permit a one-time verified legacy association.
    if (result.status="NEW")
    {
        legacyCandidatesV846 := []
        for _,legacyEntryV846 in routeMapsV21
        {
            legacyFileV846 := RoomProfileFileV108(currentProfile,legacyEntryV846.id)
            if (!FonFileAllowedV846(legacyFileV846,level))
                continue
            legacyDataV846 := RoomMapReadV109(legacyFileV846,false,level)
            if (IsObject(legacyDataV846) && legacyDataV846.points.Length())
                legacyCandidatesV846.Push({id:legacyEntryV846.id,data:legacyDataV846})
        }
        migratedV846 := BoHashBindLegacyV846(snapshot,legacyCandidatesV846,pid,level)
        if (IsObject(migratedV846) && migratedV846.status="MATCH")
            return RouteMapActivateV21(migratedV846.id)
        if (IsObject(migratedV846) && migratedV846.status="AMBIGUOUS")
        {
            ToolTipInfoV386("Có nhiều INI cũ trùng bố cục; không tự tạo hoặc chọn nhầm HASH.")
            return false
        }
    }
    ; Completely unknown signature: ONLY NOW create a new empty map identity.
    ; No Route-* points are written here; pressing TẠO will seed point 1 later.
    owner := RoomMapButtonNameV22(level)
    baseName := owner . "-Map" . level
    directory := MapRouteDirectoryV408(owner,level)
    FileCreateDir, %directory%
    if (!InStr(FileExist(directory),"D"))
        return false
    name := RoomMapNamedNumberV293(baseName)
    file := directory . "\" . name . ".ini"
    if (FileExist(file))
        return false
    IniWrite, %name%, %file%, Map, Name
    IniWrite, %baseName%, %file%, Map, RecordBaseName
    IniWrite, 1, %file%, Map, AutoName
    IniWrite, %owner%, %file%, Map, AutoButton
    IniWrite, %level%, %file%, Map, AutoLevel
    IniWrite, %level%, %file%, Map, RecordedLevel
    ; V850: store the chosen number before recording begins; do not let
    ; RoomRecordNameFinalizeV54 allocate a different number on STOP.
    if (RegExMatch(name,"-(\d+)$",hashNumberV850))
        IniWrite, %hashNumberV8501%, %file%, Map, RecordNumber
    if (!BoHashWriteV830(file,snapshot,result.observed,result.observed.Length()))
    {
        FileDelete, %file%
        return false
    }
    newId := routeMapNextV21++
    section := RouteMapSectionForV656(currentProfile,newId)
    IniWrite, %file%, % ProfileConfigPathV364(section), %section%, RoomMapFile
    IniWrite, 0, % ProfileConfigPathV364(section), %section%, CoordSavedCount
    routeMapsV21.Push({id:newId,name:name})
    if (!RouteMapActivateV21(newId))
        return false
    PortalLogWriteV66("HASH_CREATE level=" . level . " id=" . newId . " total_rooms=" . snapshot.totalRooms
        . " hash_max=" . result.observed.Length() . " file=" . file)
    return true
}

; V846: migrate a pre-HASH INI only if FULL map geometry identifies exactly
; one candidate. A failed or ambiguous match never changes routes or HASH.
