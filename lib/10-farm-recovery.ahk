BoHashBindLegacyV846(snapshot,candidates,pid,level)
{
    global currentProfile
    if (!IsObject(snapshot) || !IsObject(candidates) || !candidates.Length()
        || (level!=39 && level!=183 && level!=184))
        return {status:"NO_DATA"}
    observed := BoHashListFromSnapshotV830(snapshot)
    if (!observed.Length())
        return {status:"NO_DATA"}
    geometry := MapRoomLayoutReadV270(pid,level)
    if (!IsObject(geometry) || geometry.partial || geometry.layout="")
    {
        PortalLogWriteV66("HASH_LEGACY_SKIP level=" . level . " reason=LIVE_GEOMETRY_NOT_READY")
        return {status:"NOT_READY"}
    }
    eligible := []
    for _,candidate in candidates
    {
        file := RoomProfileFileV108(currentProfile,candidate.id)
        if (IsObject(BoHashReadV830(file,level)))
            continue
        ; Only a saved FULL geometry is an admissible association.
        ; Never attach a signature merely because the level or one spawn matches.
        if (candidate.data.roomLayout!="" && candidate.data.roomLayout=geometry.layout)
            eligible.Push({id:candidate.id,file:file})
        else if (candidate.data.roomLayout="" && candidates.Length()=1)
        {
            ; Exactly the same V68 legacy condition: only ONE candidate and
            ; its route lies entirely inside at least TWO distinct live rooms.
            legacyFitV846 := MapRoutePointsFitRoomsV841(candidate.data.points,geometry)
            if (legacyFitV846.ok && legacyFitV846.rooms>=2)
                eligible.Push({id:candidate.id,file:file})
        }
    }
    if (eligible.Length()!=1)
    {
        PortalLogWriteV66("HASH_LEGACY_SKIP level=" . level . " reason="
            . (eligible.Length()=0 ? "NO_EXACT_OLD_LAYOUT" : "AMBIGUOUS_OLD_LAYOUT")
            . " eligible=" . eligible.Length())
        return {status:eligible.Length()>1 ? "AMBIGUOUS" : "NO_MATCH"}
    }
    if (!BoHashWriteV830(eligible[1].file,snapshot,observed,observed.Length()))
    {
        PortalLogWriteV66("HASH_LEGACY_SKIP level=" . level . " reason=SIDECAR_WRITE_FAILED")
        return {status:"WRITE_FAILED"}
    }
    PortalLogWriteV66("HASH_LEGACY_OK level=" . level . " id=" . eligible[1].id
        . " rooms=" . snapshot.totalRooms . " hash_count=" . observed.Length()
        . " file=" . eligible[1].file)
    return {status:"MATCH",id:eligible[1].id,file:eligible[1].file}
}


BoHashThresholdChangedV830:
GuiControlGet, editBoHashV830, 1:, BoHashThresholdInputV830
if (!RegExMatch(editBoHashV830,"^\d+$") || editBoHashV830<1 || editBoHashV830>100)
    return
boHashThresholdV830 := editBoHashV830+0
sectionBoHashV830 := ProfileSection(currentProfile)
IniWrite, %boHashThresholdV830%, % ProfileConfigPathV364(sectionBoHashV830), %sectionBoHashV830%, BoHashThreshold
; V851: show the exact minimum for TẠO, based on original HASH count.
; This never changes Load matching or saved signatures.
if (routeMapIdV21)
{
    thresholdFileV851 := RoomProfileFileV108(currentProfile,routeMapIdV21)
    thresholdLevelV851 := MapRouteHintV400(thresholdFileV851)
    if (thresholdLevelV851=39 || thresholdLevelV851=183 || thresholdLevelV851=184)
    {
        thresholdSavedV851 := BoHashReadV830(thresholdFileV851,thresholdLevelV851)
        if (IsObject(thresholdSavedV851))
        {
            neededV851 := Ceil(thresholdSavedV851.max*boHashThresholdV830/100)
            ToolTipInfoV386("TẠO: " . boHashThresholdV830 . "% cần " . neededV851 . "/" . thresholdSavedV851.max
                . " HASH gốc; còn " . thresholdSavedV851.hashes.Length() . " HASH ổn định. LOAD không dùng H%.")
            SetTimer, RemoveToolTip, -3500
        }
    }
}
return


; ===== END special map matching =====

RoomRecordNewTargetV424()
{
    global currentProfile,routeMapIdV21,routeMapsV21,routeMapNextV21,coordCurrentLevelV400
    pid := CoordDisplayGamePidV1(),level := pid ? RoomRecordLevelV259(pid) : 0
    if (!level)
    {
        ToolTipInfoV386("Chưa đọc được map hiện tại để tạo file lộ trình mới.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    coordCurrentLevelV400 := level
    ; Explicit record-button handling only; no effect on ordinary-map F-ON loader.
    if (level=39 || level=183 || level=184)
        return BoHashAutoTargetV830(pid,level)
    if (level=263 || level=241 || level=270)
    {
        RoomMapsSyncV110(true,level,true)
        knownV843 := []
        for _,entV843 in routeMapsV21
        {
            fileV843 := RoomProfileFileV108(currentProfile,entV843.id)
            if (!MapRouteFileInScopeV408(fileV843,level))
                continue
            dataV843 := RoomMapReadV109(fileV843,false,level)
            if (IsObject(dataV843) && dataV843.points.Length())
                knownV843.Push({id:entV843.id,data:dataV843})
        }
        chosenV843 := false
        if (level=263)
        {
            liveV843 := MapLiveIdentityV399(pid,level)
            if (IsObject(liveV843))
                chosenV843 := Lib263PickV841(knownV843,pid,liveV843.levelPtr,liveV843.x,liveV843.y)
        }
        else
            chosenV843 := ScosFixedPickV841(knownV843,routeMapIdV21)
        if (IsObject(chosenV843))
        {
            PortalLogWriteV66("RECORD_REUSE_EXISTING level=" . level . " route=" . chosenV843.id . " action=SHOW_ONLY")
            return RouteMapActivateV21(chosenV843.id)
        }
    }
    selected := routeMapIdV21 ? RoomProfileFileV108(currentProfile,routeMapIdV21) : ""
    if (selected!="" && FileExist(selected) && MapRouteHintV400(selected)=level
        && MapRouteFileInScopeV408(selected,level))
    {
        routeSection := "Route-" . level
        IniRead, emptyCount, %selected%, %routeSection%, Count, INVALID
        if (emptyCount="0")
            return true
        IniRead, selectedSectionsV424, %selected%
        if (!RegExMatch(selectedSectionsV424,"m)^Route-\d+\r?$"))
            return true
    }
    owner := RoomMapButtonNameV22(level),baseName := owner . "-Map" . level
    directory := MapRouteDirectoryV408(owner,level)
    FileCreateDir, %directory%
    if (!InStr(FileExist(directory),"D"))
        return false
    RoomMapsSyncV110(true,level)
    name := RoomMapNamedNumberV293(baseName)
    file := directory . "\" . name . ".ini"
    if (FileExist(file))
        return false
    IniWrite, %name%, %file%, Map, Name
    if (ErrorLevel)
        return false
    metadata := {RecordBaseName:baseName,AutoName:1,AutoButton:owner,AutoLevel:level,RecordedLevel:level}
    if (RegExMatch(name,"-(\d+)$",numberV424))
        metadata.RecordNumber := numberV4241+0
    for key,value in metadata
    {
        IniWrite, %value%, %file%, Map, %key%
        if (ErrorLevel)
        {
            FileDelete, %file%
            return false
        }
    }
    newId := routeMapNextV21++
    section := RouteMapSectionForV656(currentProfile,newId)
    IniWrite, %file%, % ProfileConfigPathV364(section), %section%, RoomMapFile
    if (ErrorLevel)
    {
        FileDelete, %file%
        routeMapNextV21 := newId
        return false
    }
    IniWrite, 0, % ProfileConfigPathV364(section), %section%, CoordSavedCount
    routeMapsV21.Push({id:newId,name:name})
    RouteMapActivateV21(newId)
    PortalLogWriteV66("ROOM_RECORD_NEW_TARGET level=" . level . " route_id=" . newId
        . " file=" . file . " old_files=PRESERVED")
    return true
}

BOMapDirectoryNormalizeV426()
{
    global mapRelocatedFilesV412
    static doneV426 := false
    if (doneV426)
        return
    destinationDirV426 := A_ScriptDir . "\Map\BO"
    FileCreateDir, %destinationDirV426%
    if (!InStr(FileExist(destinationDirV426),"D"))
        return
    if (!IsObject(mapRelocatedFilesV412))
        mapRelocatedFilesV412 := {}
    for _,oldDirV426 in [A_ScriptDir . "\Map\MAP\BO",A_ScriptDir . "\Map\MAP"]
    {
        patternV426 := oldDirV426 . "\*.ini"
        Loop, Files, %patternV426%, F
        {
            sourceV426 := A_LoopFileFullPath
            IniRead, ownerV426, %sourceV426%, Map, AutoButton, %A_Space%
            if (oldDirV426=A_ScriptDir . "\Map\MAP" && ownerV426!="BO"
                && !RegExMatch(A_LoopFileName,"i)^BO-"))
                continue
            destinationV426 := destinationDirV426 . "\" . A_LoopFileName
            if (FileExist(destinationV426))
                continue
            FileMove, %sourceV426%, %destinationV426%, 0
            if (!ErrorLevel)
            {
                mapRelocatedFilesV412[sourceV426] := destinationV426
                PortalLogWriteV66("BO_MAP_PATH_NORMALIZED from=" . sourceV426 . " to=" . destinationV426)
            }
        }
    }
    doneV426 := true
}

FarmItemFlowBeginV427(wantClass,wantData := 7,startEngine := true,searchBoss := false,bossIDs := "")
{
    global
    if (wantClass<=0 || wantData<0 || !BackgroundValidV63() || !FarmCurrentLevelV143())
        return false
    if (!Stage2FlowConfigureV380("ITEM",wantClass,wantData,true))
        return false
    if (searchBoss && !BossSearchBeginV430(backgroundPidV63,FarmCurrentLevelV143(),bossIDs))
        return false
    cainNoFightV361 := false,cainPauseFarmV361 := false
    farmPickupBlockedV57 := false,farmPickupAllowedV57 := true
    if (searchBoss && !pickupImageOn)
        PickupEnabledSetV71(true,true,false)
    if (!startEngine)
        return true
    autoMonsterAttackOn := true,farmResumeInternalV70 := true
    try
        Gosub, AutoMonsterAttackToggle
    finally
        farmResumeInternalV70 := false
    return autoMonsterAttackOn && Stage2FlowModeV380()="ITEM"
}

FarmItemFlowLevelV427()
{
    global stage2FlowV380,backgroundPidV63,farmControlOwnerV186
    r := stage2FlowV380
    return IsObject(r) && r.flowNameV427="FARM_ITEM" && r.mode="ITEM" && !r.done
        && r.pid=backgroundPidV63 && r.owner=farmControlOwnerV186 ? r.levelV427+0 : 0
}

FarmItemFlowRunningV427(pid,level)
{
    global stage2FlowV380
    return FarmItemFlowLevelV427()>0 && level=FarmItemFlowLevelV427()
        && stage2FlowV380.pid=pid
}

FarmItemFlowDoneV427()
{
    global stage2FlowV380,backgroundPidV63,farmControlOwnerV186
    r := stage2FlowV380
    if (!IsObject(r) || r.flowNameV427!="FARM_ITEM" || r.mode!="ITEM"
        || r.pid!=backgroundPidV63 || r.owner!=farmControlOwnerV186)
        return false
    if (r.done)
        return true
    base := D2GetModuleBaseV35(r.pid,"D2Client.dll"),h := base ? D2OpenProcess(r.pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        return player ? Stage2ItemCheckV380(h,player,r.pid) : false
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}


FarmBossItemBeginV430(wantClass,wantData := 7,startEngine := true,bossIDs := "")
{
    return FarmItemFlowBeginV427(wantClass,wantData,startEngine,true,bossIDs)
}

BossSearchBeginV430(pid,level,bossIDs := "")
{
    global stage2FlowV380,farmControlOwnerV186,backgroundPidV63
    if (!IsObject(stage2FlowV380) || pid!=backgroundPidV63 || stage2FlowV380.pid!=pid
        || stage2FlowV380.owner!=farmControlOwnerV186 || !level || FarmReviveTownLevelV295(level))
        return false
    identity := MapLiveIdentityV399(pid,level)
    if (!IsObject(identity))
        return false
    CoordRouteResetV16()
    stage2FlowV380.searchV430 := {pid:pid,owner:farmControlOwnerV186,level:level,levelPtr:identity.levelPtr
        ,phase:"SEARCH",bossIDs:bossIDs,boss:false,targetRoom:0,blockedRooms:{},retryUIDs:{},motion:false,lastMove:0,lastTele:0}
    PortalLogWriteV66("BOSS_SEARCH_BEGIN owner=" . farmControlOwnerV186 . " level=" . level . " route=NONE")
    return true
}

BossSearchActiveV430(pid := 0,level := 0)
{
    global stage2FlowV380,backgroundPidV63,farmControlOwnerV186
    if (!pid)
        pid := backgroundPidV63
    s := IsObject(stage2FlowV380) ? stage2FlowV380.searchV430 : false
    return IsObject(s) && s.pid=pid && pid=backgroundPidV63 && s.owner=farmControlOwnerV186
        && (!level || s.level=level)
}

BossSearchIdentityV430(pid,level)
{
    global stage2FlowV380
    if (!BossSearchActiveV430(pid,level))
        return false
    identity := MapLiveIdentityV399(pid,level)
    return IsObject(identity) && identity.levelPtr=stage2FlowV380.searchV430.levelPtr
}

BossSearchOwnsMapV430(pid,level)
{
    global scosEntryV162
    if (IsObject(scosEntryV162) && scosEntryV162.map="BO" && scosEntryV162.pid=pid
        && scosEntryV162.boStageV413=4)
        return false
    return !FarmReviveTownLevelV295(level) && (BossSearchActiveV430(pid,level)
        || (IsObject(scosEntryV162) && scosEntryV162.map="BO" && scosEntryV162.pid=pid))
}

BossSearchScanV430(h,ByRef pb,s)
{
    result := {known:false,groups:{},boss:false,allV431:[]},seen := {},wanted := {}
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort"),bestBoss := 1.0e30
    for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
    {
        if (!MonsterBossProbeReadV1(h,room,0x78,rb))
            return result
        room2 := NumGet(rb,0x10,"UInt")
        if (CoordLevelV14(h,room)!=s.level)
            continue
        if (!result.groups.HasKey(room2))
            result.groups[room2] := {count:0,best:false}
        unit := NumGet(rb,0x74,"UInt")
        while (unit)
        {
            if (seen.HasKey(unit))
                break
            if (seen.Count()>=4096 || !MonsterBossProbeReadV1(h,unit,0xEC,ub))
                return result
            seen[unit] := true
            cls := NumGet(ub,4,"UInt"),mode := NumGet(ub,16,"UInt"),uid := NumGet(ub,12,"UInt")
            if (NumGet(ub,0,"UInt")=1 && uid && mode!=0 && mode!=12 && !MonsterClassExcludedV11(cls,h,unit))
            {
                if (!MonsterBossProbeReadV1(h,NumGet(ub,0x2C,"UInt"),0x20,mb))
                    return result
                actual := NumGet(mb,0x1C,"UInt")
                if (!actual || !MonsterBossProbeReadV1(h,actual+0x10,4,ar))
                    return result
                actual2 := NumGet(ar,0,"UInt"),level := CoordLevelV14(h,actual)
                if (level=s.level)
                {
                    x := NumGet(mb,2,"UShort"),y := NumGet(mb,6,"UShort"),dist := (x-px)**2+(y-py)**2
                    retry := s.retryUIDs.HasKey(uid) && A_TickCount<s.retryUIDs[uid]
                    candidate := {unit:unit,uid:uid,cls:cls,x:x,y:y,level:level,room2:actual2,dist:dist,priority:false}
                    result.allV431.Push(candidate)
                    if (candidate.priority && !retry && (!IsObject(s.boss) || uid=s.boss.uid))
                    {
                        if (dist<bestBoss)
                            result.boss := candidate,bestBoss := dist
                    }
                    if (!s.blockedRooms.HasKey(actual2) && !retry
                        && !MonsterRetryExcludedV44(uid,x,y,level,s.pid))
                    {
                        if (!result.groups.HasKey(actual2))
                            result.groups[actual2] := {count:0,best:false}
                        group := result.groups[actual2],group.count++
                        if (!IsObject(group.best) || (candidate.priority && !group.best.priority)
                            || (candidate.priority=group.best.priority && dist<group.best.dist))
                            group.best := candidate
                    }
                }
            }
            unit := NumGet(ub,0xE8,"UInt")
        }
    }
    result.known := true
    return result
}

BossSearchReleaseV430(s,reason)
{
    global monsterCombatUidV45,monsterChaseV44,monsterRoadAreaV51
    s.boss := false,s.motion := false,s.targetRoom := 0,s.targetUIDV440 := 0,s.phase := "SEARCH",s.exploreV432 := false,s.leftDetourV433 := false
    monsterCombatUidV45 := 0,monsterChaseV44 := false,monsterRoadAreaV51 := false
    PortalLogWriteV66("BOSS_SEARCH_RESCAN reason=" . reason . " next=BOSS_THEN_ADJACENT_MONSTERS")
}

BossSearchSkipV430(s,target,reason)
{
    if (IsObject(s.cleanupV431) && !s.cleanupV431.done)
    {
        s.retryUIDs[target.uid] := A_TickCount+30000
        s.motion := false
        PortalLogWriteV66("BOSS_ITEM_CLEANUP_RETRY uid=" . target.uid . " reason=" . reason
            . " done=0 item_use=WAIT")
        return
    }
    if (target.uid)
        s.retryUIDs[target.uid] := A_TickCount+3000
    else
        s.blockedRooms[target.room2] := A_TickCount+3000
    PortalLogWriteV66("BOSS_SEARCH_SKIP room=" . V92Hex(target.room2) . " uid=" . target.uid
        . " boss=" . target.priority . " reason=" . reason . " next=OTHER_ROOM")
    BossSearchReleaseV430(s,reason)
}

BossSearchMoveV430(h,ByRef pb,s,target,hpRaw := -1,attackStuck := false)
{
    if (s.tubeV14)
        return FarmTubeMoveV14(h,pb,s,target)
    global chaseCheckSecV9,teleportIntervalSecV56,teleportKeyV55,coordGoV59,coordManualTeleLastV296,boMoveMinimumV456,moveDelayMsV810
    global monsterLockRoomSecV622
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort"),dist := Sqrt(target.dist)
    p := s.motion,motionKey := s.phase="BOSS" ? "UID|" . target.uid : "ROOM|" . target.room2
    if (BossSearchLeftTickV433(h,pb,s,target,motionKey))
        return true
    if (!IsObject(p) || p.key!=motionKey)
        s.motion := p := {key:motionKey,uid:target.uid,dist:dist,hp:hpRaw,since:0,queued:0,teleAttempts:0,teleAt:0,probeX:px,probeY:py}
    if (s.owner!="BO" && (p.dist-dist>=1 || (p.uid=target.uid && hpRaw>=0 && p.hp>=0 && hpRaw<p.hp)))
        p.dist := dist,p.hp := hpRaw,p.since := 0,p.queued := 0,p.teleAttempts := 0,p.teleAt := 0
    stuckWaitV420 := Max(1,chaseCheckSecV9)*1000
    stuck := attackStuck || (p.since && p.queued && A_TickCount-p.since>=stuckWaitV420)
    if (s.owner="BO")
    {
        stuck := false
        if (p.since && p.queued>=2 && A_TickCount-p.since>=stuckWaitV420)
        {
            travelledV456 := Sqrt((px-p.probeX)**2+(py-p.probeY)**2)
            stuck := travelledV456<Max(5,boMoveMinimumV456)
            PortalLogWriteV66("BO_MOVE_WINDOW distance=" . Round(travelledV456,2) . " minimum=" . boMoveMinimumV456
                . " sent=" . p.queued . " elapsed_ms=" . (A_TickCount-p.since) . " stuck=" . stuck)
            if (!stuck)
                p.since := 0,p.queued := 0,p.probeX := px,p.probeY := py,p.dist := dist
        }
    }
    if (stuck)
    {
        if (s.owner="BO")
        {
            if (target.room2 && target.room2+0 > 0 && !IsObject(s.cleanupV431))
            {
                currentRoom := D2ReadU32(h,NumGet(pb,0x1C,"UInt")+0x10)
                if (target.room2 != currentRoom)
                {
                    lockDuration := Max(1, monsterLockRoomSecV622) * 1000
                    s.blockedRooms[target.room2] := A_TickCount + lockDuration
                    s.exploreV432 := false
                    s.motion := false
                    s.leftDetourV433 := false
                    
                    if (s.previousRoomV432 && s.previousRoomV432 != target.room2 && s.previousRoomV432 != currentRoom)
                    {
                        s.backtrackingV432 := true
                        s.preferNewRoomsV507 := false
                        PortalLogWriteV66("BO_STUCK_LOCK_BACK room=" . V92Hex(target.room2) . " duration_ms=" . lockDuration . " next=BACK")
                        return true
                    }
                    else
                    {
                        s.backtrackingV432 := false
                        s.zigzagV474 := {dx:1,dy:0,goal:false,leg:0}
                        PortalLogWriteV66("BO_STUCK_LOCK_ZIGZAG room=" . V92Hex(target.room2) . " duration_ms=" . lockDuration . " next=ZIGZAG")
                        return BOZigzagTickV474(h,pb,s)
                    }
                }
            }
            if (s.preferNewRoomsV507 && s.phase="EXPLORE")
            {
                if (BOFirstMapTeleportV485(h,pb,s,target))
                {
                    s.motion := false,s.commonScanV446 := false
                    return true
                }
                return BORoomCrossRetryV507(s,"CROSSING_BLOCKED")
            }
            if (BOFirstMapTeleportV485(h,pb,s,target))
            {
                s.motion := false,s.commonScanV446 := false
                return true
            }
            BossSearchLeftBeginV433(s,target,px,py,motionKey)
            return true
        }
        if (s.owner!="BO" && s.phase="EXPLORE" && BossSearchEdgeAdvanceV432(s))
            return true
        if (s.owner!="BO" && s.phase!="EXPLORE" && BossSearchFollowEdgeV435(h,pb,s,target,p))
            return true
        if (!p.leftTriedV433)
        {
            p.leftTriedV433 := true
            if (BossSearchLeftBeginV433(s,target,px,py,motionKey,s.owner="BO" ? 120 : 95))
                return true
        }
        if (s.owner!="BO" && !p.rightTriedV434)
        {
            p.rightTriedV434 := true
            if (BossSearchLeftBeginV433(s,target,px,py,motionKey,-95))
                return true
        }
        if (p.teleAt && A_TickCount-p.teleAt<Max(1,chaseCheckSecV9)*1000)
            return true
        if (p.teleAttempts>=2 || teleportKeyV55="")
        {
            BossSearchSkipV430(s,target,"WALK_AND_TELE_NO_PROGRESS")
            return true
        }
        last := Max(s.lastTele+0,coordManualTeleLastV296+0)
        if (last && A_TickCount-last<Max(3,teleportIntervalSecV56)*1000)
            return true
        goal := {pid:s.pid,level:s.level,x:target.x,y:target.y,row:0,requiredArrival:true,stop:false}
        priorGoal := coordGoV59,coordGoV59 := goal
        try
            sent := CoordGoTeleportV284(h,pb,goal)
        finally
            if (coordGoV59=goal)
                coordGoV59 := priorGoal
        p.teleAttempts++,p.teleAt := A_TickCount
        if (sent)
            s.lastTele := A_TickCount,coordManualTeleLastV296 := s.lastTele
        PortalLogWriteV66("BOSS_SEARCH_TELE uid=" . target.uid . " attempt=" . p.teleAttempts . " queued=" . sent)
        return true
    }
    if (A_TickCount-s.lastMove<Max(0,moveDelayMsV810))
        return true
    if (NativeMovePointV14(s.pid,target.x,target.y,s.level,false,false,true,false,{searchV430:s}))
    {
        s.lastMove := A_TickCount,p.queued++
        if (!p.since)
            p.since := A_TickCount,p.probeX := px,p.probeY := py
    }
    return true
}

BossSearchAttackV430(h,player,ByRef pb,s,target)
{
    global monsterChaseV44,chaseCheckSecV9,farmCloseRadiusV391
    hp := MonsterBossProbeHPV2(h,D2ReadU32(h,target.unit+0x5C)),hpRaw := hp.ok ? hp.raw : -1
    c := monsterChaseV44
    if (IsObject(c) && c.uid=target.uid && c.pid=s.pid && c.level=s.level
        && c.queued>=2 && c.since && A_TickCount-c.since>=Max(1,chaseCheckSecV9)*1000
        && target.dist>farmCloseRadiusV391*farmCloseRadiusV391
        && (hpRaw<0 || c.hp<0 || hpRaw>=c.hp))
        return BossSearchMoveV430(h,pb,s,target,hpRaw,true)
    s.motion := false,s.leftDetourV433 := false,s.exploreV432 := false
    return BossSearchHoldAttackV436(h,player,pb,s,target)
}

BossSearchTickV430(h,player,ByRef pb,pid)
{
    global stage2FlowV380,monsterCombatUidV45,autoMonsterAttackOn,xRunning,zRunning,gameItemActionOwner,packetWatchArmedV1
    s := stage2FlowV380.searchV430
    if (!BossSearchActiveV430(pid,s.level) || stage2FlowV380.done)
        return true
    if (!autoMonsterAttackOn || xRunning || zRunning || packetWatchArmedV1 || gameItemActionOwner!=""
        || !AutoMonsterPacketCleanupV1())
        return true
    current := D2ReadU32(h,NumGet(pb,0x1C,"UInt")+0x10)
    if (D2ReadU32(h,current+0x58)!=s.levelPtr || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=s.level)
    {
        MapLoadFailedStopV397("BOSS_SEARCH_LIVE_MAP_CHANGED")
        return true
    }
    for room,until in s.blockedRooms
        if (A_TickCount>=until)
            s.blockedRooms.Delete(room)
    BossSearchRoomsObserveV432(s,current)
    scan := BossSearchScanV430(h,pb,s)
    if (!scan.known)
    {
        if (IsObject(s.cleanupV431))
            s.cleanupV431.emptyAt := 0
        return true
    }
    if (IsObject(s.cleanupV431))
        return BossSearchCleanupTickV431(h,player,pb,s,scan)
    if (Stage2PickupEnabledV9())
    {
        FarmPickupFirstV75()
        cursor := PickupCursorV4(h,D2ReadU32(h,player+0x60))
        if (!IsObject(cursor) || cursor.unit || gameItemActionOwner!="")
            return true
    }
    target := false
    for _,a in scan.allV431
    {
        if ((s.retryUIDs.HasKey(a.uid) && A_TickCount<s.retryUIDs[a.uid])
            || MonsterRetryExcludedV44(a.uid,a.x,a.y,a.level,s.pid))
            continue
        if (!IsObject(target) || a.dist<target.dist)
            target := a
    }
    if (IsObject(target))
    {
        if (s.targetUIDV440!=target.uid)
        {
            s.motion := false,s.leftDetourV433 := false,s.exploreV432 := false
            s.targetUIDV440 := target.uid
        }
        s.targetRoom := target.room2,s.phase := "FIGHT"
        return BossSearchAttackV430(h,player,pb,s,target)
    }
    node := RoomExploreReadV89(h,current,s.level)
    if (!IsObject(node))
        return true
    s.targetUIDV440 := 0
    return BossSearchExploreTickV432(h,pb,s,node)

}

BOFirstFarmMapV497(s)
{
    global scosEntryV162
    r := scosEntryV162
    return IsObject(r) && r.map="BO" && r.pid=s.pid && r.boStageV413=2 && r.phase="FARM"
}

BOChaseHeadingRememberV497(ByRef pb,s)
{
    global pickupRadius
    origin := s.chaseOriginV497
    if (!BOFirstFarmMapV497(s) || !IsObject(origin) || IsObject(s.chaseHeadingV497))
        return false
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    previous := s.chasePositionV497
    s.chasePositionV497 := {x:px,y:py}
    if ((px-origin.x)**2+(py-origin.y)**2<=Max(1,pickupRadius)**2)
        return false
    dx := IsObject(previous) ? px-previous.x : px-origin.x
    dy := IsObject(previous) ? py-previous.y : py-origin.y
    length := Sqrt(dx*dx+dy*dy)
    if (length<1)
    {
        dx := px-origin.x,dy := py-origin.y,length := Sqrt(dx*dx+dy*dy)
    }
    if (length<1)
        return false
    s.chaseHeadingV497 := {dx:dx/length,dy:dy/length}
    PortalLogWriteV66("BO_CHASE_HEADING_SAVED live_xy=" . px . "," . py
        . " heading=" . Round(dx/length,3) . "," . Round(dy/length,3)
        . " pickup_radius=" . pickupRadius . " next=KEEP_HEADING_AFTER_PICKUP")
    return true
}

BOCombatRouteRebaseV488(ByRef pb,s,force := false)
{
    if (!force)
    {
        BOChaseHeadingRememberV497(pb,s)
        return false
    }
    origin := s.fightOriginV488
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort"),radius := Max(1,MonsterRadiusGetV239())
    if (!force && (!IsObject(origin) || (px-origin.x)**2+(py-origin.y)**2<=radius*radius))
        return false
    sweep := s.zigzagV474,detour := s.leftDetourV433
    dx := IsObject(sweep) ? sweep.dx : IsObject(detour) ? detour.dx : 1
    dy := IsObject(sweep) ? sweep.dy : IsObject(detour) ? detour.dy : 0
    heading := s.chaseHeadingV497
    resumedChase := force && BOFirstFarmMapV497(s) && IsObject(heading)
    if (resumedChase)
    {
        dx := heading.dx,dy := heading.dy
        s.zigzagSideV474 := {x:-dy,y:dx}
        PortalLogWriteV66("BO_PICKUP_RESUME_CHASE heading=" . Round(dx,3) . "," . Round(dy,3)
            . " horizontal=PERPENDICULAR_TO_CHASE vertical=ALONG_CHASE old_coordinate=DISCARDED")
    }
    if (force)
        s.chaseHeadingV497 := false,s.chaseOriginV497 := false,s.chasePositionV497 := false
    s.zigzagV474 := {dx:dx,dy:dy,goal:false,leg:0}
    s.motion := false,s.leftDetourV433 := false,s.exploreV432 := false,s.unvisitedSearchV462 := false
    s.fightOriginV488 := {x:px,y:py}
    PortalLogWriteV66("BO_ROUTE_REBASE live_xy=" . px . "," . py . " reason=" . (force ? "PICKUP_FINISHED" : "COMBAT_DRIFT_OVER_BK")
        . " old_coordinate=DISCARDED next=" . (resumedChase ? "ZIGZAG_ALONG_SAVED_CHASE_HEADING" : "NEW_ZIGZAG_FROM_LIVE_POSITION"))
    return true
}

BOAttackInRadiusV488(h,player,unit,pid)
{
    if (!MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,pb)
        || !MonsterBossProbeReadV1(h,D2ReadU32(h,unit+0x2C),0x20,mb))
        return false
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    if (!BossSearchActiveV430(pid,level) || CoordLevelV14(h,NumGet(mb,0x1C,"UInt"))!=level)
        return false
    x := NumGet(mb,2,"UShort"),y := NumGet(mb,6,"UShort")
    areaV503 := BOCombatAreaV447(pb)
    ok := Abs(x-areaV503.x)+Abs(y-areaV503.y)<=areaV503.radius
    if (!ok)
        PortalLogWriteV66("BO_ATTACK_RADIUS_REJECT uid=" . D2ReadU32(h,unit+12) . " next=RESCAN_WITHOUT_CHASE","BO_ATTACK_RADIUS_REJECT",1000)
    return ok
}

BOCombatAreaV447(ByRef pb)
{
    global stage2FlowV380,pickupRadius
    s := stage2FlowV380.searchV430,c := s.itemCenterV447
    if (IsObject(c))
    {
        c.radius := Max(1,pickupRadius)
        return {x:c.x,y:c.y,radius:c.radius,radiusSq:c.radius*c.radius,source:"BO_GROUND_ITEM_PICKUP_RADIUS",row:0}
    }
    radius := Max(1,pickupRadius),origin := s.fightOriginV488
    cx := IsObject(origin) ? origin.x : NumGet(pb,2,"UShort")
    cy := IsObject(origin) ? origin.y : NumGet(pb,6,"UShort")
    return {x:cx,y:cy,radius:radius,radiusSq:radius*radius,source:"BO_FIXED_PICKUP_RADIUS",row:0}
}

BOItemCenterUpdateV447(h,player,ByRef pb,pid)
{
    global stage2FlowV380,pickupRadius,pickupRoundResetV1,monsterCombatUidV45,monsterChaseV44,monsterRoadAreaV51
    r := stage2FlowV380,s := r.searchV430
    if (IsObject(s.itemCenterV447))
        return true
    seen := {},best := false,bestDist := 1.0e30
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
    {
        unit := D2ReadU32(h,room+0x74)
        Loop, 4096
        {
            if (!unit || seen.HasKey(unit))
                break
            seen[unit] := true
            if (!MonsterBossProbeReadV1(h,unit,0xEC,ub))
                return false
            next := NumGet(ub,0xE8,"UInt"),mode := NumGet(ub,0x10,"UInt")
            data := NumGet(ub,0x14,"UInt"),uid := NumGet(ub,0x0C,"UInt")
            cls := NumGet(ub,4,"UInt")
            if (NumGet(ub,0,"UInt")=4 && uid && cls!=1214 && (mode=3 || mode=5) && data
                && PickupFileHasRuleV97(cls,D2ReadU8V18(h,data),data,h,unit))
            {
                path := NumGet(ub,0x2C,"UInt")
                if (path && MonsterBossProbeReadV1(h,path,0x14,ip))
                {
                    x := NumGet(ip,0x0C,"UInt"),y := NumGet(ip,0x10,"UInt")
                    dist := Abs(x-px)+Abs(y-py)
                    if (x && y && dist<=pickupRadius && dist<bestDist)
                        best := {uid:uid,cls:cls,x:x,y:y,radius:Max(1,pickupRadius)},bestDist := dist
                }
            }
            unit := next
        }
    }
    if (!IsObject(best))
        return false
    s.itemCenterV447 := best,s.motion := false,s.exploreV432 := false,s.leftDetourV433 := false
    s.commonScanV446 := false,s.pickupPassV441 := false,s.phase := "ITEM_CLEAR"
    s.afterCombatPickupV486 := true
    monsterCombatUidV45 := 0,monsterChaseV44 := false,monsterRoadAreaV51 := false
    pickupRoundResetV1 := true
    if (AutoMonsterPacketCleanupV1())
        NativeMovePointV14(pid,px,py,s.level,false,false,true,false,{searchV430:s,stop:true})
    PortalLogWriteV66("BO_ITEM_CENTER_LOCK uid=" . best.uid . " class=" . best.cls
        . " center=" . best.x . "," . best.y . " radius=" . best.radius
        . " route=HOLD next=CLEAR_ITEM_RADIUS_THEN_PICKUP")
    return true
}

BOCommonPublishV446(pid,target,complete,px,py)
{
    global stage2FlowV380
    s := stage2FlowV380.searchV430
    s.commonScanV446 := {at:A_TickCount,complete:complete,target:IsObject(target)}
    if (IsObject(target))
    {
        if (!s.afterCombatPickupV486)
        {
            s.fightOriginV488 := {x:px,y:py}
            if (BOFirstFarmMapV497(s))
            {
                s.chaseOriginV497 := {x:px,y:py},s.chasePositionV497 := {x:px,y:py}
                s.chaseHeadingV497 := false
            }
        }
        s.phase := "FIGHT",s.pickupPassV441 := false,s.afterCombatPickupV486 := true
        s.prePickupSortedV448 := false,s.prePickupDoneV448 := false,s.prePickupAtV448 := 0
        s.motion := false
        d := s.leftDetourV433
        if (IsObject(d))
            d.since := 0,d.queued := 0,d.last := 0
    }
}

BOCombatStopWalkV482(h,player,ByRef pb,s)
{
    if (!s.walkingV482)
        return false
    mode := D2ReadU32(h,player+0x10)
    if (mode!=2 && mode!=3 && mode!=6)
    {
        s.walkingV482 := false
        return false
    }
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    if (NativeMovePointV14(s.pid,px,py,s.level,false,false,true,false,{searchV430:s,stop:true}))
        PortalLogWriteV66("BO_ZIGZAG_COMBAT_STOP live_xy=" . px . "," . py . " next=ATTACK_THEN_RESUME_SAME_LEG")
    return true
}

BOCommonClearV446(pid)
{
    global stage2FlowV380
    if (!BOCommonActiveV444(pid))
        return false
    c := stage2FlowV380.searchV430.commonScanV446
    return IsObject(c) && c.complete && !c.target && A_TickCount-c.at<500
}

BOPrePickupV448(h,player,pid,s)
{
    global gameItemActionOwner,pickupTimerBusy,scosEntryV162
    wasReadyV453 := s.prePickupDoneV448
    if (pickupTimerBusy || gameItemActionOwner!="" || !AutoMonsterPacketCleanupV1())
        return false
    if (!s.prePickupAtV448)
        s.prePickupAtV448 := A_TickCount
    if (!GameItemActionBeginV4("BOPrePickup","cube",true))
        return false
    errorV448 := "",clearV448 := "WAIT"
    try
    {
        if (!s.prePickupSortedV448)
        {
            ctx := {pid:pid,h:h,player:player,inv:D2ReadU32(h,player+0x60)
                ,scosEntry:true,entryStateV42:scosEntryV162}
            SigSortContainerV191(ctx)
            SigCheckV147(ctx)
            s.prePickupSortedV448 := true
            PortalLogWriteV66("BO_PRE_PICKUP_SORT_DONE next=SELECT_GROUND_ITEM")
        }
        clearV448 := "CLEAR"
    }
    catch e
        errorV448 := e.Message
    finally
        GameItemActionEndV4("BOPrePickup")
    if (errorV448!="")
    {
        PortalLogWriteV66("BO_PRE_PICKUP_WAIT reason=" . errorV448 . " stop=0 next=RETRY_SORT_AND_TRANSFER","BO_PRE_PICKUP_WAIT",1000)
        return false
    }
    if (clearV448!="CLEAR")
    {
        PortalLogWriteV66("BO_FINAL_TRANSFER_WAIT result=" . clearV448 . " stop=0 next=VERIFY_OR_RETRY","BO_FINAL_TRANSFER_WAIT",1000)
        return false
    }
    s.prePickupDoneV448 := true
    if (wasReadyV453)
        return true
    PortalLogWriteV66("BO_PRE_PICKUP_READY sort=OK next=SELECT_AND_CHECK_PICKUP")
    return false
}

BOErrorReportV463(r,reason,source := "")
{
    global scosEntryV162,cainPauseFarmV361
    if (!IsObject(r) || r.map!="BO" || scosEntryV162!=r)
        return false
    messageV463 := "BO GĐ" . r.boStageV413 . "/" . r.phase . ": " . reason
    if (source!="")
        messageV463 .= " | " . source
    if (r.errorTextV463=messageV463 && A_TickCount-r.errorAtV463<2000)
        return true
    r.errorTextV463 := messageV463,r.errorAtV463 := A_TickCount
    r.retryAtV237 := A_TickCount+1000
    if (r.until<A_TickCount+60000)
        r.until := A_TickCount+60000
    if (r.phase="FARM")
        cainPauseFarmV361 := false
    FonInfoPushV385("[BO LỖI] " . messageV463)
    PortalLogWriteV66("BO_ERROR_RETAINED stage=" . r.boStageV413 . " phase=" . r.phase
        . " reason=" . reason . " source=" . source . " auto_stop=0 state=KEPT next=RECHECK_CURRENT_STEP")
    return true
}

BOFinalHuntTickV454(h,player,ByRef pb,pid)
{
    global scosEntryV162,coordCastPendingV50,pestiPointPendingV28,lastAttackPendingV20
    global monsterCombatUidV45,monsterChaseV44,monsterRoadAreaV51
    r := scosEntryV162
    r.boPickupPriorityV503 := true
    try
        pickupFirstV503 := FarmPickupFirstV75()
    finally
        r.boPickupPriorityV503 := false
    if (pickupFirstV503)
        return true
    if (StateBuffTickV17(h,player,pb,pid) || CombatRecoverTickV48(h,pb,pid,false))
        return true
    if (!r.boBossKilledV454)
    {
        if (CainHuntBossTickV403(h,player,pb,pid))
            return true
        if (r.boBossKilledV454)
            return true
        monsterCombatUidV45 := 0,monsterChaseV44 := false,monsterRoadAreaV51 := false
        CoordRouteObserveV18(h,pb,pid)
        if (!CoordStuckTickV84(h,pb,pid))
            CoordMoveWhenClearV14(h,pb,pid)
        PortalLogWriteV66("BO_FINAL_FIND_BOSS class=1584 pickup=WAIT_FOR_DEATH"
            ,"BO_FINAL_FIND_BOSS",1000)
        return true
    }
    if (!r.boFinalPickupPreparedV454)
    {
        if (!GameItemActionBeginV4("BOFinalPrePickup","cube",true))
            return true
        try
        {
            ctx := {pid:pid,h:h,player:player,inv:D2ReadU32(h,player+0x60)
                ,scosEntry:true,entryStateV42:r}
            if (!r.boFinalSortedV454)
            {
                SigSortContainerV191(ctx)
                SigCheckV147(ctx)
                r.boFinalSortedV454 := true
            }
            r.boFinalPickupPreparedV454 := true
        }
        finally
            GameItemActionEndV4("BOFinalPrePickup")
        return true
    }
    FarmPickupFirstV75()
    return true
}

BOBuffPointV454(hwnd)
{
    ; Doc chinh PID cua cua so game dang nhan buff (foreground/background).
    if (!hwnd)
        return false
    WinGet, pid, PID, ahk_id %hwnd%
    if (!pid)
        return false
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return false
        view := AutoMonsterAttackViewV1(h,base,hwnd,path)
        if (!IsObject(view))
            return false
        xV454 := Round((NumGet(pb,8,"Int")-view.ox)*view.cw/view.gw)
        yV454 := Round((NumGet(pb,12,"Int")-view.oy)*view.ch/view.gh)
        if (xV454<16 || xV454>=view.cw-16 || yV454<16 || yV454>=view.ch-16)
            return false
        return {x:xV454,y:yV454}
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

BOFinalRouteActiveV451(pid := 0)
{
    global scosEntryV162,backgroundPidV63,farmControlOwnerV186
    if (!pid)
        pid := backgroundPidV63
    return farmControlOwnerV186="BO" && IsObject(scosEntryV162)
        && scosEntryV162.map="BO" && scosEntryV162.pid=pid
        && scosEntryV162.boStageV413=4 && scosEntryV162.phase="FARM"
}

BOCommonActiveV444(pid := 0)
{
    global stage2FlowV380,backgroundPidV63,farmControlOwnerV186
    if (!pid)
        pid := backgroundPidV63
    return farmControlOwnerV186="BO" && BossSearchActiveV430(pid)
}

BOPickupPriorityV421(h,player,ByRef pb,pid)
{
    global stage2FlowV380,pickupImageOn,pickupRadius,pickupFarmWorkV75,pickupRoundResetV1
    s := stage2FlowV380.searchV430
    if (!pickupImageOn || !Stage2PickupEnabledV9())
        return false
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort"),seen := {},found := false
    for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
    {
        unit := D2ReadU32(h,room+0x74)
        Loop, 1024
        {
            if (!unit || seen.HasKey(unit))
                break
            seen[unit] := true
            if (D2ReadU32(h,unit)=4 && (D2ReadU32(h,unit+0x10)=3 || D2ReadU32(h,unit+0x10)=5))
            {
                data := D2ReadU32(h,unit+0x14),cls := D2ReadU32(h,unit+4),path := D2ReadU32(h,unit+0x2C)
                if (data && path)
                {
                    ix := D2ReadU32(h,path+0x0C),iy := D2ReadU32(h,path+0x10)
                    if (cls!=1214 && Abs(ix-px)+Abs(iy-py)<=pickupRadius
                        && PickupFileHasRuleV97(cls,D2ReadU8V18(h,data),data,h,unit))
                    {
                        found := true
                        break
                    }
                }
            }
            next := D2ReadU32(h,unit+0xE8)
            if (next=unit)
                break
            unit := next
        }
        if (found)
            break
    }
    if (!found && !pickupFarmWorkV75)
    {
        s.pickupHoldV421 := false
        return false
    }
    if (!s.pickupHoldV421)
    {
        s.pickupHoldV421 := true,s.motion := false,s.leftDetourV433 := false
        s.prePickupSortedV448 := false,s.prePickupDoneV448 := false,s.prePickupAtV448 := 0
        pickupRoundResetV1 := true
    }
    s.commonScanV446 := false
    modeV503 := D2ReadU32(h,player+0x10)
    s.walkingV482 := modeV503=2 || modeV503=3 || modeV503=6
    if (BOCombatStopWalkV482(h,player,pb,s))
        return true
    if (!BOPrePickupV448(h,player,pid,s))
        return true
    s.pickupPriorityV421 := true
    try
        working := FarmPickupFirstV75()
    finally
        s.pickupPriorityV421 := false
    PortalLogWriteV66("BO_PICKUP_PRIORITY matching_drop=" . found . " working=" . working
        . " movement=PAUSED","BO_PICKUP_PRIORITY",1000)
    return pickupImageOn && (found || working)
}

BOCommonPickupGateV444(h,player,ByRef pb,pid)
{
    global stage2FlowV380,ticketPickupWaitV279,pickupRoundResetV1
    s := stage2FlowV380.searchV430
    if (!BOCommonClearV446(pid))
        return "WAIT"
    s.phase := "PICKUP"
    global pickupImageOn
    if (!pickupImageOn)
        return "WAIT"
    if (!BOPrePickupV448(h,player,pid,s))
        return "WAIT"
    if (!s.pickupPassV441)
    {
        s.pickupPassV441 := true
        ticketPickupWaitV279 := {pid:pid,level:s.level,checks:0,emptyAt:0,done:false,scanAt:0,remaining:-1,active:true}
        pickupRoundResetV1 := true
    }
    pickupWorkingV448 := FarmPickupFirstV75()
    if (!pickupImageOn)
    {
        s.prePickupDoneV448 := false,s.prePickupSortedV448 := false
        PortalLogWriteV66("BO_PICKUP_PAUSED pickup=OFF stop=0 next=WAIT_FOR_PICKUP_ON_THEN_SORT_TRANSFER","BO_PICKUP_PAUSED",1000)
        return "WAIT"
    }
    if (pickupWorkingV448 || !BossSearchPickupDoneV438(pid))
        return "WAIT"
    if (!BOPickupAllowedV441(h,player,pid))
        return "WAIT"
    if (Stage2ItemCheckV380(h,player,pid))
        return "WAIT"
    return "CLEAR"
}

BOCommonMoveV444(h,ByRef pb,pid)
{
    global stage2FlowV380
    s := stage2FlowV380.searchV430
    if (IsObject(s.itemCenterV447))
        return false
    if (!BOCommonClearV446(pid) || s.afterCombatPickupV486)
    {
        PortalLogWriteV66("BO_MOVE_WAIT reason=FRESH_SCAN_OR_PICKUP_PROOF clear=" . BOCommonClearV446(pid)
            . " pickup_done=" . BossSearchPickupDoneV438(pid),"BO_MOVE_WAIT",1000)
        return false
    }
    current := D2ReadU32(h,NumGet(pb,0x1C,"UInt")+0x10)
    if (D2ReadU32(h,current+0x58)!=s.levelPtr)
    {
        PortalLogWriteV66("BO_MOVE_WAIT reason=LIVE_MAP_CHANGED","BO_MOVE_WAIT",1000)
        return false
    }
    BossSearchRoomsObserveV432(s,current)
    node := RoomExploreReadV89(h,current,s.level)
    if (!IsObject(node))
        return false
    if (!s.preferNewRoomsV507)
    {
        s.preferNewRoomsV507 := true,s.motion := false,s.exploreV432 := false
        PortalLogWriteV66("BO_NEW_ROOM_MODE visited=" . s.roomVisitsV432.Count() . " zigzag=OFF old_room_fallback=OFF")
    }
    s.leftDetourV433 := false,s.zigzagV474 := false
    movedV482 := BossSearchExploreTickV432(h,pb,s,node)
    s.commonScanV446 := false
    return movedV482
}

BORoomCrossRetryV507(s,reason)
{
    e := s.exploreV432
    if (!IsObject(e))
        return true
    if (BossSearchEdgeAdvanceV432(s))
    {
        PortalLogWriteV66("BO_NEW_ROOM_CROSS_RETRY from=" . V92Hex(e.from) . " to=" . V92Hex(e.to)
            . " variant=" . e.variant . " reason=" . reason . " zigzag=OFF")
        return true
    }
    BOBlockCurrentPassageV473(s)
    s.exploreV432 := false,s.motion := false,s.leftDetourV433 := false,s.zigzagV474 := false
    s.unvisitedSearchV462 := false,s.phase := "SEARCH"
    PortalLogWriteV66("BO_NEW_ROOM_EDGE_SKIP from=" . V92Hex(e.from) . " to=" . V92Hex(e.to)
        . " reason=" . reason . " next=OTHER_NEW_ROOM visited=PRESERVED zigzag=OFF")
    return true
}

BOCommonFinishReadyV444(h,player,s)
{
    return BOCommonClearV446(s.pid) && BossSearchPickupDoneV438(s.pid)
        && BOPickupAllowedV441(h,player,s.pid)
}

BOPickupAllowedV441(h,player,pid)
{
    global stage2FlowV380,scosEntryV162
    if (!IsObject(scosEntryV162) || scosEntryV162.map!="BO"
        || scosEntryV162.pid!=pid || scosEntryV162.phase!="FARM")
        return true
    if (scosEntryV162.boPickupPriorityV503)
        return true
    if (scosEntryV162.boStageV413=4)
        return scosEntryV162.boBossKilledV454 ? true : false
    if (!BossSearchActiveV430(pid))
        return false
    s := stage2FlowV380.searchV430
    if (s.pickupPriorityV421)
        return true
    if (!s.afterCombatPickupV486)
        return false
    if (s.phase!="PICKUP")
        return false
    return BOCommonClearV446(pid)
}


BossSearchCleanupReadyV431(h,player,r)
{
    global ticketPickupWaitV279,pickupRoundResetV1
    if (!IsObject(r.searchV430))
        return true
    s := r.searchV430
    if (s.owner="BO")
        return BOCommonFinishReadyV444(h,player,s)
    if (IsObject(s.cleanupV431))
        return s.cleanupV431.done && BossSearchPickupDoneV438(s.pid)
    path := D2ReadU32(h,player+0x2C)
    if (!MonsterBossProbeReadV1(h,path,0x20,pb))
        return false
    room := NumGet(pb,0x1C,"UInt"),room2 := room ? D2ReadU32(h,room+0x10) : 0
    if (CoordLevelV14(h,room)!=s.level || D2ReadU32(h,room2+0x58)!=s.levelPtr)
        return false
    radius := s.owner="BO" ? MonsterRadiusGetV239() : MonsterScanRadiusV20(s.level)
    if (radius<=0)
        return false
    s.cleanupV431 := {x:NumGet(pb,2,"UShort"),y:NumGet(pb,6,"UShort"),radius:radius
        ,radiusSq:radius*radius,done:false,emptyAt:0}
    ticketPickupWaitV279 := {pid:s.pid,level:s.level,checks:0,emptyAt:0,done:false,scanAt:0,remaining:-1,active:true}
    pickupRoundResetV1 := true
    s.phase := "CLEANUP",s.boss := false,s.motion := false,s.targetRoom := 0
    PortalLogWriteV66("BOSS_ITEM_READY class=" . r.itemClass . " in_cube=1 done=0"
        . " cleanup_center=" . s.cleanupV431.x . "," . s.cleanupV431.y . " radius=" . radius
        . " next=CLEAR_RADIUS_BEFORE_USE_OR_NEXT_STAGE")
    return false
}

BossSearchCleanupTickV431(h,player,ByRef pb,s,scan)
{
    c := s.cleanupV431
    if (!IsObject(c) || !scan.known)
        return true
    if (s.owner!="BO")
        FarmPickupFirstV75()
    target := false,count := 0,best := 1.0e30
    for _,a in scan.allV431
    {
        if ((a.x-c.x)**2+(a.y-c.y)**2>c.radiusSq
            && (s.owner!="BO" || a.dist>c.radiusSq))
            continue
        count++
        if (s.retryUIDs.HasKey(a.uid) && A_TickCount<s.retryUIDs[a.uid])
            continue
        if (!IsObject(target) || (a.priority && !target.priority)
            || (a.priority=target.priority && a.dist<best))
            target := a,best := a.dist
    }
    if (count)
    {
        c.done := false,c.emptyAt := 0
        if (s.owner="BO")
            s.phase := "FIGHT"
        if (IsObject(target))
            BossSearchHoldAttackV436(h,player,pb,s,target)
        PortalLogWriteV66("BOSS_ITEM_CLEANUP remaining=" . count . " radius=" . c.radius
            . " done=0 item_use=WAIT","BOSS_ITEM_CLEANUP",1000)
        return true
    }
    if (s.owner="BO")
    {
        s.phase := "PICKUP"
        FarmPickupFirstV75()
    }
    if (!c.emptyAt)
        c.emptyAt := A_TickCount
    else if (A_TickCount-c.emptyAt>=500)
    {
        c.done := true,s.motion := false
        PortalLogWriteV66("BOSS_ITEM_CLEANUP_DONE remaining=0 confirmed=FULL_LIVE_SCANS"
            . " next=ITEM_DONE_THEN_CALLER_NEXT_STAGE")
    }
    return true
}

BossSearchRoomsObserveV432(s,current)
{
    if (!IsObject(s.roomVisitsV432))
        s.roomVisitsV432 := {},s.currentRoomV432 := 0,s.previousRoomV432 := 0,s.stepsV432 := 0
    if (s.currentRoomV432=current)
        return
    old := s.currentRoomV432
    if (s.owner="BO" && old && IsObject(s.blockedPassagesV473))
        s.blockedPassagesV473.Delete(BOBlockedPassageKeyV473(old,current))
    s.previousRoomV432 := old,s.currentRoomV432 := current
    s.roomVisitsV432[current] := s.roomVisitsV432.HasKey(current) ? s.roomVisitsV432[current]+1 : 1
    if (s.owner="BO")
        PortalLogWriteV66("BO_ROOM_VISITED room=" . V92Hex(current) . " unique_visited=" . s.roomVisitsV432.Count())
    if (s.owner="BO" && IsObject(s.leftDetourV433))
        return
    if (IsObject(s.exploreV432))
    {
        s.stepsV432++
        PortalLogWriteV66("BOSS_SEARCH_EMPTY_ROOM_ENTER from=" . V92Hex(old) . " to=" . V92Hex(current)
            . " steps=" . s.stepsV432 . " next=RESCAN_BOSS_AND_MONSTERS")
        s.exploreV432 := false,s.motion := false,s.leftDetourV433 := false
        if (s.phase="EXPLORE")
            s.phase := "SEARCH"
    }
}

BossSearchPassageV432(a,b,px,py,variant := 0)
{
    if (!IsObject(a) || !IsObject(b))
        return false
    loY := Max(a.y,b.y)+1,hiY := Min(a.y+a.h,b.y+b.h)-2
    loX := Max(a.x,b.x)+1,hiX := Min(a.x+a.w,b.x+b.w)-2
    insetX := Min(6,b.w-2),insetY := Min(6,b.h-2),axis := ""
    if (hiY>=loY && a.x+a.w=b.x)
        fixed := b.x+insetX,axis := "Y",lo := loY,hi := hiY,along := py
    else if (hiY>=loY && b.x+b.w=a.x)
        fixed := b.x+b.w-1-insetX,axis := "Y",lo := loY,hi := hiY,along := py
    else if (hiX>=loX && a.y+a.h=b.y)
        fixed := b.y+insetY,axis := "X",lo := loX,hi := hiX,along := px
    else if (hiX>=loX && b.y+b.h=a.y)
        fixed := b.y+b.h-1-insetY,axis := "X",lo := loX,hi := hiX,along := px
    else if (px<b.x || px>=b.x+b.w)
        fixed := px<b.x ? b.x+insetX : b.x+b.w-1-insetX,axis := "Y",lo := b.y+1,hi := b.y+b.h-2,along := py
    else if (py<b.y || py>=b.y+b.h)
        fixed := py<b.y ? b.y+insetY : b.y+b.h-1-insetY,axis := "X",lo := b.x+1,hi := b.x+b.w-2,along := px
    if (axis="" || hi<lo)
        return false
    along := variant=1 ? lo : variant=2 ? hi : variant=3 ? Round(lo+(hi-lo)*0.25)
        : variant=4 ? Round(lo+(hi-lo)*0.75) : Max(lo,Min(hi,along))
    return axis="Y" ? {x:fixed,y:along} : {x:along,y:fixed}
}

BossSearchEdgeAdvanceV432(s)
{
    e := s.exploreV432
    if (!IsObject(e) || e.variant>=4)
        return false
    e.variant++,s.motion := false,s.leftDetourV433 := false
    PortalLogWriteV66("BOSS_SEARCH_FOLLOW_EDGE to=" . V92Hex(e.to) . " variant=" . e.variant . " next=WALK_SIDE")
    return true
}

BOBlockedPassageKeyV473(a,b)
{
    return a<b ? a . "|" . b : b . "|" . a
}

BOBlockedPassageV473(s,a,b)
{
    return s.owner="BO" && IsObject(s.blockedPassagesV473)
        && s.blockedPassagesV473.HasKey(BOBlockedPassageKeyV473(a,b))
}

BOBlockCurrentPassageV473(s)
{
    e := s.exploreV432
    if (!IsObject(e) || !e.from || !e.to)
        return
    if (!IsObject(s.blockedPassagesV473))
        s.blockedPassagesV473 := {}
    key := BOBlockedPassageKeyV473(e.from,e.to)
    previousV473 := s.blockedPassagesV473[key]
    nextVariantV473 := Max(e.variant+1,IsObject(previousV473) ? previousV473.variant : 1)
    failedPointsV473 := IsObject(previousV473) ? previousV473.points : {}
    failedGoalV473 := BossSearchPassageV432(e.a,e.b,e.x,e.y,e.variant)
    if (IsObject(failedGoalV473))
        failedPointsV473[failedGoalV473.x . "|" . failedGoalV473.y] := true
    s.blockedPassagesV473[key] := {variant:nextVariantV473,points:failedPointsV473}
    s.unvisitedSearchV462 := false
    PortalLogWriteV66("BO_BLOCKED_PASSAGE from=" . V92Hex(e.from) . " to=" . V92Hex(e.to)
        . " failed_variant=" . e.variant . " next=OTHER_CONNECTION visited=PRESERVED")
}

BOUnvisitedNextV462(h,s,node,px,py)
{
    searchV462 := s.unvisitedSearchV462
    if (!IsObject(searchV462) || searchV462.current!=node.r2)
    {
        searchV462 := {current:node.r2,queue:[{room:node.r2,first:0}],seen:{},index:1}
        searchV462.seen[node.r2] := true
        s.unvisitedSearchV462 := searchV462
    }
    queueV462 := searchV462.queue,seenV462 := searchV462.seen,indexV462 := searchV462.index
    startedV462 := A_TickCount
    while (indexV462<=queueV462.Length() && seenV462.Count()<2048)
    {
        entryV462 := queueV462[indexV462],indexV462++
        hereV462 := entryV462.room=node.r2 ? node : RoomExploreReadV89(h,entryV462.room,s.level)
        if (!IsObject(hereV462))
            continue
        for _,nextV462 in hereV462.links
        {
            if (seenV462.HasKey(nextV462) || s.blockedRooms.HasKey(nextV462)
                || BOBlockedPassageV473(s,entryV462.room,nextV462))
                continue
            otherV462 := RoomExploreReadV89(h,nextV462,s.level)
            if (!IsObject(otherV462))
                continue
            firstV462 := entryV462.first ? entryV462.first : nextV462
            hopV462 := firstV462=nextV462 ? otherV462 : RoomExploreReadV89(h,firstV462,s.level)
            passageV462 := BossSearchPassageV432(node,hopV462,px,py)
            if (!IsObject(passageV462))
                continue
            seenV462[nextV462] := true
            if (!s.roomVisitsV432.HasKey(nextV462))
            {
                PortalLogWriteV66("BO_UNVISITED_TARGET current=" . V92Hex(node.r2) . " first_hop=" . V92Hex(firstV462)
                    . " target_unvisited=" . V92Hex(nextV462) . " visited=" . s.roomVisitsV432.Count())
                s.unvisitedSearchV462 := false
                return {node:hopV462,goal:passageV462,frontier:nextV462}
            }
            queueV462.Push({room:nextV462,first:firstV462})
        }
        if (A_TickCount-startedV462>120)
        {
            searchV462.index := indexV462
            PortalLogWriteV66("BO_UNVISITED_SEARCH_WAIT read_rooms=" . seenV462.Count(),"BO_UNVISITED_SEARCH_WAIT",1000)
            return {waiting:true}
        }
    }
    s.unvisitedSearchV462 := false
    return false
}

BossSearchExploreTickV432(h,ByRef pb,s,node)
{
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort"),current := node.r2
    e := s.exploreV432
    if (!IsObject(e) || e.from!=current || s.blockedRooms.HasKey(e.to))
    {
        best := 1.0e30,picked := false,pickedGoal := false,pickedVariantV473 := 0
        if (s.owner="BO")
        {
            unvisitedV462 := BOUnvisitedNextV462(h,s,node,px,py)
            if (IsObject(unvisitedV462) && unvisitedV462.waiting)
                return true
            if (IsObject(unvisitedV462))
                picked := unvisitedV462.node,pickedGoal := unvisitedV462.goal
        }
        if (!IsObject(picked))
        for _,next in node.links
        {
            if (s.blockedRooms.HasKey(next) || BOBlockedPassageV473(s,current,next)
                || (s.owner="BO" && s.preferNewRoomsV507 && s.roomVisitsV432.HasKey(next)))
                continue
            other := RoomExploreReadV89(h,next,s.level)
            goal := BossSearchPassageV432(node,other,px,py)
            if (!IsObject(goal))
                continue
            visits := s.roomVisitsV432.HasKey(next) ? s.roomVisitsV432[next] : 0
            rank := s.owner="BO"
                ? visits*100000000+(next=s.previousRoomV432 ? 10000 : 0)+(goal.x-px)**2+(goal.y-py)**2
                : visits*1000000+(next=s.previousRoomV432 ? 1000000000 : 0)+(goal.x-px)**2+(goal.y-py)**2
            if (rank<best)
                best := rank,picked := other,pickedGoal := goal
        }
        if (!IsObject(picked) && s.owner="BO")
        {
            for _,next in node.links
            {
                failedV473 := s.blockedPassagesV473[BOBlockedPassageKeyV473(current,next)]
                if (!IsObject(failedV473) || failedV473.variant>4 || s.blockedRooms.HasKey(next)
                    || (s.preferNewRoomsV507 && s.roomVisitsV432.HasKey(next)))
                    continue
                other := RoomExploreReadV89(h,next,s.level)
                goal := false
                while (failedV473.variant<=4)
                {
                    goal := BossSearchPassageV432(node,other,px,py,failedV473.variant)
                    if (IsObject(goal) && !failedV473.points.HasKey(goal.x . "|" . goal.y))
                        break
                    failedV473.variant++,goal := false
                }
                if (!IsObject(goal))
                    continue
                picked := other,pickedGoal := goal,pickedVariantV473 := failedV473.variant
                PortalLogWriteV66("BO_PASSAGE_ALTERNATIVE from=" . V92Hex(current) . " to=" . V92Hex(next)
                    . " variant=" . pickedVariantV473 . " reason=NO_OTHER_CONNECTION")
                break
            }
        }
                if (!IsObject(picked))
        {
            if (s.owner="BO")
            {
                if (!IsObject(s.zigzagV474))
                    s.zigzagV474 := {dx:1,dy:0,goal:false,leg:0}
                return BOZigzagTickV474(h,pb,s)
            }
            if (s.owner!="BO")
                s.blockedRooms := {}
            PortalLogWriteV66("BOSS_SEARCH_ROOM_WAIT current=" . V92Hex(current)
                . " neighbors=" . node.links.Length() . " reason=NO_READABLE_UNBLOCKED_LINK","BOSS_SEARCH_ROOM_WAIT",2000)
            return true
        }
        s.exploreV432 := e := {from:current,to:picked.r2,a:node,b:picked,x:px,y:py,variant:pickedVariantV473}
        s.motion := false,s.phase := "EXPLORE",s.targetRoom := picked.r2
        PortalLogWriteV66("BOSS_SEARCH_EMPTY_ROOM_SELECT from=" . V92Hex(current) . " to=" . V92Hex(picked.r2)
            . " goal=" . pickedGoal.x . "," . pickedGoal.y . " monster_required=0 route=NONE")
    }
    goal := BossSearchPassageV432(e.a,e.b,e.x,e.y,e.variant)
    if (!IsObject(goal))
    {
        s.blockedRooms[e.to] := A_TickCount+3000
        BossSearchReleaseV430(s,"UNREADABLE_ROOM_SIDE")
        return true
    }
    dist := (goal.x-px)**2+(goal.y-py)**2
    if (dist<=4 && current!=e.to)
    {
        if (s.owner="BO")
        {
            if (s.preferNewRoomsV507)
                return BORoomCrossRetryV507(s,"POINT_REACHED_ROOM_NOT_ENTERED")
            turnSeedV426 := {x:px+(goal.x-e.x),y:py+(goal.y-e.y)}
            if (turnSeedV426.x=px && turnSeedV426.y=py)
                turnSeedV426.y := py-1
            global chaseCheckSecV9
            if (!e.sideWaitV452)
                e.sideWaitV452 := A_TickCount
            if (A_TickCount-e.sideWaitV452<Max(1,chaseCheckSecV9)*1000)
                return true
            if (!IsObject(s.leftDetourV433))
                BossSearchLeftBeginV433(s,turnSeedV426,px,py,"ROOM|" . e.to)
            return BossSearchLeftTickV433(h,pb,s,turnSeedV426,"ROOM|" . e.to)
        }
        if (!BossSearchEdgeAdvanceV432(s))
        {
            s.blockedRooms[e.to] := A_TickCount+3000
            BossSearchReleaseV430(s,"SIDE_REACHED_WITHOUT_ROOM_TRANSFER")
        }
        return true
    }
    target := {uid:0,cls:0,room2:e.to,x:goal.x,y:goal.y,level:s.level,dist:dist,priority:false}
    return BossSearchMoveV430(h,pb,s,target)
}

BORecoveryBeginV452(s,target,px,py,key)
{
    BOBlockCurrentPassageV473(s)
    dx := target.x-px,dy := target.y-py
    oldSweepV481 := s.zigzagV474
    if (IsObject(oldSweepV481))
    {
        dx := oldSweepV481.dx,dy := oldSweepV481.dy
        PortalLogWriteV66("BO_ZIGZAG_SKIP_REMAINDER live_xy=" . px . "," . py
            . " cancelled_goal=" . target.x . "," . target.y . " original_heading=" . dx . "," . dy
            . " next=SIDE_2BK_THEN_REVERSE_SAME_AXIS")
    }
    if (!dx && !dy)
        return false
    if (BOFirstFarmMapV497(s))
    {
        length := Sqrt(dx*dx+dy*dy)
        dx := dx/length,dy := dy/length
    }
    else if (Abs(dx)>=Abs(dy))
        dx := dx>=0 ? 1 : -1,dy := 0
    else
        dy := dy>=0 ? 1 : -1,dx := 0
    if (!IsObject(s.zigzagSideV474))
        s.zigzagSideV474 := {x:-dy,y:dx}
    side := s.zigzagSideV474
    pairSignV504 := s.turnPairLastV504 ? -s.turnPairLastV504 : 1
    crossV504 := dx*side.y-dy*side.x
    if ((crossV504>=0 ? 1 : -1)!=pairSignV504)
        side := {x:-side.x,y:-side.y}
    s.zigzagSideV474 := side
    d := {key:key,stage:"SIDE_1",originX:px,originY:py,dx:dx,dy:dy,pairSignV504:pairSignV504
        ,sideX:side.x,sideY:side.y,radius:Max(1,MonsterRadiusGetV239())
        ,since:0,last:0,queued:0,probeX:px,probeY:py,attempt:1}
    s.zigzagV474 := false,s.motion := false,s.exploreV432 := false
    s.leftDetourV433 := d
    PortalLogWriteV66("BO_ZIGZAG_PAIR_BEGIN pair=" . (pairSignV504=1 ? "TT" : "PP")
        . " previous=" . (s.turnPairLastV504=1 ? "TT" : s.turnPairLastV504=-1 ? "PP" : "NONE") . " same_pair=BLOCKED")
    BORecoveryGoalV452(d,px,py,"SIDE_1")
    return true
}

BORecoveryGoalV452(d,px,py,stage)
{
    d.stage := stage
    multiplier := 2
    sign := 1
    d.tx := Round(d.originX+d.sideX*d.radius*multiplier*sign)
    d.ty := Round(d.originY+d.sideY*d.radius*multiplier*sign)
    d.since := 0,d.last := 0,d.queued := 0,d.probeX := px,d.probeY := py
    PortalLogWriteV66("BO_ZIGZAG_SIDE attempt=" . d.attempt . " distance=" . d.radius*multiplier
        . " from=" . px . "," . py . " goal=" . d.tx . "," . d.ty . " next=REVERSE")
}

BOZigzagReverseV474(s,d,px,py)
{
    if ((px-d.originX)**2+(py-d.originY)**2>=4)
        s.teleAttemptedV505 := false,s.teleProbeV504 := false
    s.turnPairLastV504 := d.pairSignV504
    if ((px-d.originX)*d.sideX+(py-d.originY)*d.sideY<0)
        s.zigzagSideV474 := {x:-d.sideX,y:-d.sideY}
    s.zigzagV474 := {dx:-d.dx,dy:-d.dy,goal:false,leg:0}
    s.unvisitedSearchV462 := false
    BossSearchReleaseV430(s,"ZIGZAG_SIDE_DONE_REVERSE")
    s.commonScanV446 := false
    PortalLogWriteV66("BO_ZIGZAG_REVERSE from=" . px . "," . py . " heading=" . -d.dx . "," . -d.dy
        . " old_room_target=RELEASED")
}

BOZigzagCornerV480(s,d,px,py)
{
    s.turnPairLastV504 := d.pairSignV504
    angle := 45 * ATan(1) * 4 / 180
    c := Cos(angle), s_val := Sin(angle)
    nextDx := d.dx * c - d.dy * s_val
    nextDy := d.dx * s_val + d.dy * c
    s.zigzagV474 := {dx:nextDx,dy:nextDy,goal:false,leg:0}
    s.zigzagSideV474 := {x:-nextDy,y:nextDx}
    BossSearchReleaseV430(s,"ZIGZAG_SIDE_BLOCKED_TURN_45")
    s.commonScanV446 := false
    PortalLogWriteV66("BO_ZIGZAG_CORNER_45 from=" . px . "," . py
        . " new_heading=" . Round(nextDx,3) . "," . Round(nextDy,3) . " next=CONTINUE_ZIGZAG")
}
BORecoveryTickV452(h,ByRef pb,s)
{
    global chaseCheckSecV9,boMoveMinimumV456
    d := s.leftDetourV433
    if (!IsObject(d))
        return false
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    if ((px-d.tx)**2+(py-d.ty)**2<=4)
    {
        BOZigzagReverseV474(s,d,px,py)
        return true
    }
    if (d.since && d.queued>=2 && A_TickCount-d.since>=Max(1,chaseCheckSecV9)*1000)
    {
        travelled := Sqrt((px-d.probeX)**2+(py-d.probeY)**2)
        PortalLogWriteV66("BO_SIDE_MOVE_WINDOW distance=" . Round(travelled,2) . " minimum=" . boMoveMinimumV456
            . " elapsed_ms=" . (A_TickCount-d.since) . " stuck=" . (travelled<Max(5,boMoveMinimumV456)))
        if (travelled<Max(5,boMoveMinimumV456))
        {
            PortalLogWriteV66("BO_ZIGZAG_SIDE_BLOCKED live_xy=" . px . "," . py
                . " planned_distance=" . d.radius*2 . " next=TURN_SWEEP_AXIS_90")
            if (BOFirstMapTeleportV485(h,pb,s,{x:d.tx,y:d.ty}))
                d.since := 0,d.queued := 0,d.probeX := px,d.probeY := py
            else
                BOZigzagCornerV480(s,d,px,py)
            return true
        }
        d.since := 0,d.queued := 0,d.probeX := px,d.probeY := py
    }
    if (A_TickCount-d.last>=250 && NativeMovePointV14(s.pid,d.tx,d.ty,s.level,false,false,true,false,{searchV430:s}))
    {
        d.last := A_TickCount,d.queued++
        if (!d.since)
            d.since := A_TickCount,d.probeX := px,d.probeY := py
    }
    return true
}

BOFirstMapTeleportV485(h,ByRef pb,s,target)
{
    global scosEntryV162,teleportKeyV55,teleportIntervalSecV56,coordManualTeleLastV296,coordGoV59,chaseCheckSecV9
    r := scosEntryV162
    if (!IsObject(r) || r.map!="BO" || r.pid!=s.pid || r.boStageV413!=2 || r.phase!="FARM")
        return false
    if (!BOCommonClearV446(s.pid))
        return true
    if (teleportKeyV55="")
    {
        PortalLogWriteV66("BO_TELE_FIRST_SKIP reason=TELE_KEY_EMPTY next=ZIGZAG","BO_TELE_FIRST_SKIP",1000)
        return false
    }
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort"),probeV504 := s.teleProbeV504
    if (IsObject(probeV504))
    {
        movedV504 := (px-probeV504.x)**2+(py-probeV504.y)**2>=4
        if (!movedV504 && A_TickCount-probeV504.at<Max(0.5,chaseCheckSecV9)*1000)
            return true
        s.teleProbeV504 := false
        if (!movedV504)
        {
            PortalLogWriteV66("BO_TELE_FIRST_NO_PROGRESS next=ZIGZAG xy=" . px . "," . py)
            return false
        }
        PortalLogWriteV66("BO_TELE_FIRST_PROGRESS xy=" . px . "," . py . " next=CONTINUE_WALK")
        return true
    }
    if (s.teleAttemptedV505)
    {
        PortalLogWriteV66("BO_TELE_ONCE_ALREADY_TRIED next=ZIGZAG","BO_TELE_ONCE_ALREADY_TRIED",1000)
        return false
    }
    s.teleAttemptedV505 := true
    last := Max(s.lastTele+0,coordManualTeleLastV296+0)
    if (last && A_TickCount-last<Max(3,teleportIntervalSecV56)*1000)
    {
        PortalLogWriteV66("BO_TELE_FIRST_SKIP reason=COOLDOWN next=ZIGZAG","BO_TELE_FIRST_SKIP",1000)
        return false
    }
    goal := {pid:s.pid,level:s.level,x:target.x,y:target.y,row:0,requiredArrival:true,stop:false,autoCallV504:true}
    prior := coordGoV59,coordGoV59 := goal
    try
        sent := CoordGoTeleportV284(h,pb,goal)
    finally
        if (coordGoV59=goal)
            coordGoV59 := prior
    if (sent)
    {
        s.lastTele := A_TickCount,coordManualTeleLastV296 := s.lastTele
        s.teleProbeV504 := {x:px,y:py,at:A_TickCount}
    }
    PortalLogWriteV66("BO_FIRST_MAP_STUCK_TELE goal=" . target.x . "," . target.y
        . " queued=" . sent . " readiness=AUTO_FARM next=" . (sent ? "VERIFY_MOVEMENT" : "ZIGZAG"))
    return sent
}

BOZigzagTickV474(h,ByRef pb,s)
{
    sweep := s.zigzagV474
    if (!IsObject(sweep))
        return false
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    goal := sweep.goal
    if (!IsObject(goal) || (px-goal.x)**2+(py-goal.y)**2<=4)
    {
        if (s.tubeV14 && IsObject(goal))
            s.blockedV14 := 0
        if (IsObject(goal) && (px-goal.startXV505)**2+(py-goal.startYV505)**2>=4)
            s.teleAttemptedV505 := false,s.teleProbeV504 := false
        step := Min(Max(3,MapMoveDistanceGetV51()),Max(1,MonsterRadiusGetV239())*2)
        if (s.tubeV14)
        {
            side := sweep.leg && Mod(sweep.leg,2) ? -1 : 1
            sweep.dx := (s.forwardXV14-s.forwardYV14*side)/Sqrt(2)
            sweep.dy := (s.forwardYV14+s.forwardXV14*side)/Sqrt(2)
        }
        sweep.leg++,s.motion := false
        PortalLogWriteV66("BO_ZIGZAG_CHECKPOINT leg=" . sweep.leg . " live_xy=" . px . "," . py
            . " next_step=" . step . " scan=FRESH_BEFORE_MOVE")
        sweep.goal := goal := {uid:0,cls:0,room2:"ZIGZAG_" . sweep.leg,startXV505:px,startYV505:py
            ,x:Round(px+sweep.dx*step),y:Round(py+sweep.dy*step),level:s.level,priority:false}
    }
    goal.dist := (goal.x-px)**2+(goal.y-py)**2
    s.phase := "ZIGZAG"
    return BossSearchMoveV430(h,pb,s,goal)
}

BossSearchLeftBeginV433(s,target,px,py,key,turnAngle := 95)
{
    if (s.owner="BO")
        return BORecoveryBeginV452(s,target,px,py,key)
    dx := target.x-px,dy := target.y-py,len := Sqrt(dx*dx+dy*dy)
    if (len<1)
        return false
    angle := turnAngle*ATan(1)*4/180,step := Max(3,MapMoveDistanceGetV51())
    tx := Round(px+(dx*Cos(angle)+dy*Sin(angle))*step/len)
    ty := Round(py+(-dx*Sin(angle)+dy*Cos(angle))*step/len)
    if (tx<1 || tx>65535 || ty<1 || ty>65535)
        return false
    s.leftDetourV433 := {angle:turnAngle,key:key,x:px,y:py,tx:tx,ty:ty,since:0,last:0,queued:0,probeX:px,probeY:py}
    PortalLogWriteV66("MONSTER_SEARCH_TURN angle=" . turnAngle . " from=" . px . "," . py . " goal=" . tx . "," . ty)
    return true
}

BossSearchLeftTickV433(h,ByRef pb,s,target,key)
{
    if (s.owner="BO")
        return BORecoveryTickV452(h,pb,s)
    global chaseCheckSecV9
    d := s.leftDetourV433
    if (!IsObject(d))
        return false
    if (d.key!=key)
    {
        s.leftDetourV433 := false
        return false
    }
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    if ((px-d.x)**2+(py-d.y)**2>=4)
    {
        s.leftDetourV433 := false
        if (IsObject(s.motion))
            s.motion.since := 0,s.motion.queued := 0,s.motion.dist := Sqrt(target.dist)
        PortalLogWriteV66("MONSTER_SEARCH_TURN_RECOVERED angle=" . d.angle . " next=CONTINUE_ORIGINAL_DIRECTION")
        return true
    }
    if (d.since && d.queued && A_TickCount-d.since>=Max(1,chaseCheckSecV9)*1000)
    {
        s.leftDetourV433 := false
        PortalLogWriteV66("MONSTER_SEARCH_TURN_BLOCKED angle=" . d.angle . " next=" . (d.angle=95 ? "RIGHT_95" : "TELE"))
        return false
    }
    if (A_TickCount-d.last>=250 && NativeMovePointV14(s.pid,d.tx,d.ty,s.level,false,false,true,false,{searchV430:s}))
    {
        d.last := A_TickCount,d.queued++
        if (!d.since)
            d.since := A_TickCount
    }
    return true
}

BossSearchNoDamageV434(h,target,pid,hpRaw)
{
    return FarmCloseNoDamageV391(h,target,pid,hpRaw)
}


BossSearchFollowEdgeV435(h,ByRef pb,s,target,p)
{
    global chaseCheckSecV9
    current := D2ReadU32(h,NumGet(pb,0x1C,"UInt")+0x10)
    node := RoomExploreReadV89(h,current,s.level)
    if (!IsObject(node))
        return false
    if (!IsObject(p.edgeV435))
    {
        best := 1.0e30,picked := false
        for _,next in node.links
        {
            other := RoomExploreReadV89(h,next,s.level)
            point := BossSearchPassageV432(node,other,NumGet(pb,2,"UShort"),NumGet(pb,6,"UShort"))
            if (!IsObject(point))
                continue
            rank := (point.x-target.x)**2+(point.y-target.y)**2
            if (rank<best)
                best := rank,picked := other
        }
        if (!IsObject(picked))
            return false
        p.edgeV435 := {from:current,a:node,b:picked,variant:0,since:0,last:0}
    }
    e := p.edgeV435
    if (e.from!=current || e.variant>4)
        return false
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    goal := BossSearchPassageV432(e.a,e.b,px,py,e.variant)
    if (!IsObject(goal))
        return false
    if ((goal.x-px)**2+(goal.y-py)**2<=4
        || (e.since && A_TickCount-e.since>=Max(1,chaseCheckSecV9)*1000))
    {
        e.variant++,e.since := 0
        return e.variant<=4
    }
    if (A_TickCount-e.last>=250
        && NativeMovePointV14(s.pid,goal.x,goal.y,s.level,false,false,true,false,{searchV430:s}))
    {
        e.last := A_TickCount
        if (!e.since)
        {
            e.since := A_TickCount
            PortalLogWriteV66("MONSTER_SEARCH_FOLLOW_EDGE variant=" . e.variant . " next=LEFT_95_THEN_RIGHT_95_THEN_TELE")
        }
    }
    return true
}

BossSearchHoldAttackV436(h,player,ByRef pb,s,target)
{
    global xRunning,zRunning,packetWatchArmedV1,gameItemActionOwner,monsterChaseV44,monsterCombatUidV45
    if (xRunning || zRunning || packetWatchArmedV1 || gameItemActionOwner!=""
        || !BossSearchActiveV430(s.pid,s.level) || !AutoMonsterPacketCleanupV1())
        return true
    hp := MonsterBossProbeHPV2(h,D2ReadU32(h,target.unit+0x5C))
    hpRaw := hp.ok ? hp.raw : -1
    if (BossSearchNoDamageV434(h,target,s.pid,hpRaw))
        return true
    if (!MonsterChaseProgressV44(target.uid,NumGet(pb,2,"UShort"),NumGet(pb,6,"UShort"),target.dist
        ,hpRaw,target.x,target.y,target.level,s.pid,h,target.unit))
    {
        monsterCombatUidV45 := 0
        return true
    }
    if (!MonsterBossProbeReadV1(h,target.unit,0x30,ub) || NumGet(ub,0,"UInt")!=1
        || NumGet(ub,12,"UInt")!=target.uid || NumGet(ub,4,"UInt")!=target.cls
        || NumGet(ub,16,"UInt")=0 || NumGet(ub,16,"UInt")=12)
        return true
    if (AutoMonsterPacketSendV1(s.pid,target.unit,target.uid))
    {
        AttackIdTipV12(target.cls,Round(Sqrt(target.dist),1))
        if (IsObject(monsterChaseV44) && monsterChaseV44.uid=target.uid)
        {
            if (!monsterChaseV44.since)
                monsterChaseV44.since := A_TickCount
            monsterChaseV44.queued++
        }
    }
    return true
}

BossSearchHoldReadyV436(pid,level)
{
    global stage2FlowV380
    r := stage2FlowV380,s := IsObject(r) ? r.searchV430 : false
    c := IsObject(s) ? s.cleanupV431 : false
    if (!IsObject(c))
        return true
    if (!BossSearchActiveV430(pid,level))
        return false
    base := D2GetModuleBaseV35(pid,"D2Client.dll"),h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb)
            || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=level)
            return false
        scan := BossSearchScanV430(h,pb,s)
        if (!scan.known)
        {
            c.done := false,c.emptyAt := 0
            return false
        }
        for _,a in scan.allV431
            if ((a.x-c.x)**2+(a.y-c.y)**2<=c.radiusSq
                || (s.owner="BO" && a.dist<=c.radiusSq))
            {
                c.done := false,c.emptyAt := 0
                break
            }
        if (c.done)
            return true
        BossSearchCleanupTickV431(h,player,pb,s,scan)
        return c.done
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}


BOFinalItemActiveV442(pid)
{
    global farmControlOwnerV186,scosEntryV162
    return farmControlOwnerV186="BO" && IsObject(scosEntryV162)
        && scosEntryV162.map="BO" && scosEntryV162.pid=pid && BackgroundValidV63()
}

PickupCharmCubeMarkedV571(ctx,item,ByRef ready)
{
    global pickupOptRulesV12
    ready := true,hasRule := false
    for _,rule in pickupOptRulesV12
        if (rule.cubeCharmV571)
            hasRule := true
    if (!hasRule)
        return false
    q := D2ReadU8V18(ctx.h,item.data),flags := D2ReadU32(ctx.h,item.data+0x18)
    for _,rule in pickupOptRulesV12
    {
        if (!rule.cubeCharmV571)
            continue
        if ((rule.HasKey("exactClassV638") || rule.charmV571 || rule.setV574) && !rule.stats.Length() && !rule.tiers.Count())
        {
            if (PickupOptRuleMatchV12(rule,q,flags,"","","",ctx.h,item.cls))
            {
                ready := true
                return true
            }
            continue
        }
        PickupOptPollV12()
        info := PickupOptReadV12(ctx.h,item.unit,item.cls,q,item.data,flags)
        if (!IsObject(info) || !info.ok)
        {
            ready := false
            continue
        }
        if (PickupOptRuleMatchV12(rule,q,flags,info.name,info.stats,"",ctx.h,item.cls))
        {
            ready := true
            return true
        }
    }
    return false
}

PickupCubeRouteV574(ctx,item)
{
    relic := false
    if (D2ReadU8V18(ctx.h,item.data)=7)
    {
        started := A_TickCount
        Loop
        {
            relic := PickupRelicNameV567(ctx,item.cls,ready)
            if (ready)
                break
            SigCheckV147(ctx)
            if (A_TickCount-started>=3000)
                SigFailV147("Chuyển Cube: chưa phân biệt được Relic/Charm; chưa di chuyển đồ")
            Sleep, 30
        }
    }
    SigLogV147("CUBE_RULE_ROUTE uid=" . item.uid . " class=" . item.cls
        . " mode=" . (relic ? "RELIC_SHARED_ALLOWANCE" : "EXACT_ITEM"))
    return PickupRelicSwapV567(ctx,item,!relic)
}

PickupRelicNameV567(ctx,cls,ByRef ready)
{
    global consumableClassRAMV7
    ConsumablePickupGroupV7(ctx.h,cls)
    key := ctx.pid . "|" . cls
    ready := IsObject(consumableClassRAMV7) && consumableClassRAMV7.HasKey(key)
    return ready && RegExMatch(PickupOptCleanTextV12(consumableClassRAMV7[key]),"i)\bRelic\b")
}

PickupRelicMarkedV567(ctx,item,ByRef ready)
{
    global pickupOptRulesV12,consumableClassRAMV7
    ready := true,hasRule := false
    for _,rule in pickupOptRulesV12
        if (rule.cubeRelicV567)
            hasRule := true
    if (!hasRule)
        return false
    if (!PickupRelicNameV567(ctx,item.cls,ready))
        return false
    q := D2ReadU8V18(ctx.h,item.data),flags := D2ReadU32(ctx.h,item.data+0x18)
    base := consumableClassRAMV7[ctx.pid . "|" . item.cls]
    for _,rule in pickupOptRulesV12
    {
        if (!rule.cubeRelicV567)
            continue
        if (!rule.stats.Length() && !rule.tiers.Count())
        {
            if (PickupOptRuleMatchV12(rule,q,flags,"","",base,ctx.h,item.cls))
            {
                ready := true
                return true
            }
            continue
        }
        PickupOptPollV12()
        info := PickupOptReadV12(ctx.h,item.unit,item.cls,q,item.data,flags)
        if (!IsObject(info) || !info.ok)
        {
            ready := false
            continue
        }
        if (PickupOptRuleMatchV12(rule,q,flags,info.name,info.stats,base,ctx.h,item.cls))
        {
            ready := true
            return true
        }
    }
    return false
}

PickupRelicStoredV567(ctx,item)
{
    all := SigSnapshotV147(ctx),live := all[item.uid]
    if (!IsObject(live) || live.cls!=item.cls || live.q!=item.q
        || D2ReadU32(ctx.h,live.unit+0x10)!=0)
        return false
    return live
}

PickupRelicSwapV567(ctx,item,charmMode:=false)
{
    global pickupStashListV217
    label := charmMode ? "Vật phẩm" : "Relic"
    SigCheckV147(ctx)
    ground := SigGroundV147(ctx)
    if (!ground.HasKey(item.uid) || ground[item.uid].cls!=item.cls)
        SigFailV147(label . " [cube]: vật dưới đất đã thay đổi")
    item := ground[item.uid],cube := false,original := false,home := false,success := false
    all := SigSnapshotV147(ctx)
    for uid,a in all
        if (a.cls=1204 && a.q=2 && a.loc=0 && a.owner=ctx.inv && D2ReadU32(ctx.h,a.unit+0x10)=0)
        {
            cube := a
            break
        }
    started := A_TickCount
    Loop
    {
        waiting := false
        for uid,a in all
        {
            if (a.loc!=0 || a.owner!=ctx.inv || uid=item.uid || a.cls=1204
                || D2ReadU32(ctx.h,a.unit+0x10)!=0)
                continue
            if (charmMode && (a.cls!=item.cls || a.q!=item.q))
                continue
                        
            ready := true
            if (charmMode || PickupRelicNameV567(ctx,a.cls,ready))
            {
                original := a
                break
            }
            if (!ready)
                waiting := true
        }
        if (IsObject(original) || !waiting)
            break
        SigCheckV147(ctx)
        if (A_TickCount-started>3000)
            SigFailV147(label . " [cube]: chưa nhận diện xong vật phẩm trong túi, chưa di chuyển đồ")
        Sleep, 30
        ConsumableNamePollV7()
    }
    if (!IsObject(cube) && IsObject(original))
        SigFailV147(label . " [cube]: cần Cube trong túi trước khi đổi tạm vật phẩm")
    if (IsObject(cube))
        ctx.cubeUid := cube.uid
    try
    {
        if (IsObject(original))
        {
            home := {uid:original.uid,cls:original.cls,q:original.q,x:original.x,y:original.y}
            SigLogV147("ITEM_SWAP_BEGIN ground_uid=" . item.uid . " original_uid=" . original.uid
                . " original_class=" . original.cls . " home=" . home.x . "," . home.y)
            SigToCubeV147(ctx,original,cube,true)
        }
        bytes := [0x16],SigDwordV147(bytes,4),SigDwordV147(bytes,item.uid),SigDwordV147(bytes,0)
        SigPacketV147(ctx,bytes)
        fresh := SigWaitLocV147(ctx,item.uid,0,2500)
        if (!IsObject(fresh) || fresh.cls!=item.cls || fresh.q!=item.q)
            SigFailV147(label . " [cube]: chưa xác nhận vật phẩm mới vào túi")
                if (!IsObject(original))
{
    UniqueRememberPickedV18(ctx.h,fresh)
    if (IsObject(pickupStashListV217))
        pickupStashListV217.Delete(item.uid)
    success := true
    SigLogV147("CUBE_RULE_PICK_TO_INVENTORY uid=" . item.uid . " class=" . item.cls . " destination=INVENTORY reason=NO_MATCHING_OLD_ITEM")
    return true
}
        SigToCubeV147(ctx,fresh,cube,true)
        if (IsObject(original))
        {
            original := PickupRelicStoredV567(ctx,original)
            if (!IsObject(original) || original.loc!=3)
                SigFailV147(label . " [cube]: chưa tìm lại đúng UID vật phẩm ban đầu trong Cube")
            Ticket130HomeV265(ctx,original,home)
        }
        newLive := PickupRelicStoredV567(ctx,item)
        if (!IsObject(newLive) || newLive.loc!=3)
            SigFailV147(label . " [cube]: chưa xác nhận vật phẩm mới trong Cube")
        if (IsObject(home))
        {
            all := SigSnapshotV147(ctx),old := all[home.uid]
            if (!IsObject(old) || old.cls!=home.cls || old.q!=home.q || old.loc!=0 || old.owner!=ctx.inv || old.x!=home.x || old.y!=home.y)
                SigFailV147(label . " [cube]: Vật phẩm ban đầu chưa về đúng ô cũ")
        }
        UniqueRememberPickedV18(ctx.h,newLive)
        if (IsObject(pickupStashListV217))
        {
            pickupStashListV217.Delete(item.uid)
            if (IsObject(home))
                pickupStashListV217.Delete(home.uid)
        }
        success := true
        SigLogV147("ITEM_SWAP_DONE new_uid=" . item.uid . " new_location=CUBE original_uid=" . home.uid . " original_location=SAVED_INVENTORY_CELL")
        FonInfoPushV385(label . " mới vào Cube; vật ban đầu đã trả về ô cũ.")
        return true
    }
    finally
    {
        if (!success && IsObject(home))
        {
            try
            {
                all := SigSnapshotV147(ctx),old := all[home.uid],newItem := all[item.uid]
                cursor := PickupCursorV4(ctx.h,ctx.inv)
                newInBag := IsObject(newItem) && newItem.loc=0 && newItem.owner=ctx.inv
                    && D2ReadU32(ctx.h,newItem.unit+0x10)=0
                if (IsObject(old) && (old.loc=3 || (IsObject(cursor) && cursor.uid=home.uid))
                    && !newInBag && IsObject(cursor) && (!cursor.unit || cursor.uid=home.uid))
                    Ticket130HomeV265(ctx,old,home)
            }
            catch restoreError
                SigLogV147("ITEM_SWAP_RESTORE_WAIT original_uid=" . home.uid . " reason=" . restoreError.Message)
            FonInfoPushV385(label . " [cube] chưa xong; đã giữ đồ, kiểm tra vật gốc UID " . home.uid . ".")
        }
        try
        {
            cursor := PickupCursorV4(ctx.h,ctx.inv)
            if (IsObject(cursor) && !cursor.unit)
                SigCloseCubeV156()
        }
        catch closeError
            SigLogV147("ITEM_SWAP_CLOSE_WAIT reason=" . closeError.Message)
    }
}

PickupRelicRoundV567(h,player,pid,item)
{
    global sigBusyV147,sigCancelV147,sigActiveModeV182,sigBackgroundV179,sigSendingKeyV147
    global xRunning,zRunning,pickupImageOn
    inv := D2ReadU32(h,player+0x60)
    if (!inv)
        return "WAIT"
    ctx := {pid:pid,h:h,player:player,inv:inv,first:D2ReadU32(h,inv+0x10)}
    charmCube := PickupCharmCubeMarkedV571(ctx,item,ready)
    if (!ready)
        return "WAIT"
    marked := charmCube ? true : PickupRelicMarkedV567(ctx,item,ready)
    if (!ready)
        return "WAIT"
    if (!marked)
        return "PASS"
    if (sigBusyV147 || xRunning || zRunning || !AutoMonsterPacketCleanupV1())
        return "WAIT"
    priorCancel := sigCancelV147,priorMode := sigActiveModeV182,priorBackground := sigBackgroundV179
    sigBusyV147 := true,sigCancelV147 := false,sigBackgroundV179 := true,sigActiveModeV182 := charmCube ? "CHARM_CUBE" : "RELIC_CUBE"
    try
    {
        if (charmCube)
            PickupCubeRouteV574(ctx,item)
        else
            PickupRelicSwapV567(ctx,item)
        return "DONE"
    }
    catch e
    {
        DebugTraceWrite("pickup","CUBE_RULE_ERROR uid=" . item.uid . " class=" . item.cls . " reason=" . e.Message)
        PickupEnabledSetV71(false,true,false)
        ToolTipInfoV386(e.Message . " — nhặt đã tắt, không quăng đồ.")
        SetTimer, RemoveToolTip, -5000
        return "ERROR"
    }
    finally
    {
        sigBusyV147 := false,sigCancelV147 := priorCancel,sigActiveModeV182 := priorMode
        sigBackgroundV179 := priorBackground,sigSendingKeyV147 := false
    }
}

PickupFailedInventoryReadyV551(h,player,pid,groundUid,groundUnit)
{
    global labInventoryOnlyV311
    if (Lab1SingleRunV310() && labInventoryOnlyV311)
        return true
    if (!MonsterBossProbeReadV1(h,groundUnit,0x18,ub)
        || NumGet(ub,0,"UInt")!=4 || NumGet(ub,12,"UInt")!=groundUid)
        return true
    cls := NumGet(ub,4,"UInt"),data := NumGet(ub,0x14,"UInt")
    if (cls=1204)
        return true
    if (!MonsterBossProbeReadV1(h,data,0x2C,id))
        return false
    quality := NumGet(id,0,"UChar")
    fileIndex := quality=7 ? NumGet(id,0x28,"UInt") : -1
    cleared := PickupMatchingInventoryClearV551(h,player,pid,cls,quality,groundUid,fileIndex)
    V104CubeLog("FAILED_PICKUP_MATCHING_INVENTORY class=" . cls . " itemdata=" . quality
        . " file_index=" . fileIndex . " ground_uid=" . groundUid . " result=" . cleared)
    return cleared="CLEAR"
}


BossSearchPickupDoneV438(pid)
{
    global ticketPickupWaitV279
    w := ticketPickupWaitV279
    return IsObject(w) && w.pid=pid && w.done
}

FarmWatchNowV688()
{
    return DllCall("GetTickCount64","Int64")
}

FarmWatchStateV688()
{
    global farmWatchV5,farmControlOwnerV186,mapWorkflowV185
    if (!IsObject(farmWatchV5))
        farmWatchV5 := {owner:"",pid:0,hwnd:0,birth:"",enabled:false,period:60000
            ,idleAtV650:FarmWatchNowV688(),retryAtV688:0}
    w := farmWatchV5
    owner := farmControlOwnerV186!="" ? farmControlOwnerV186 : mapWorkflowV185.map
    if (owner!="")
        w.owner := owner
    return w
}


PickupFarmBudgetActiveV762(pid)
{
    global pickupImageOn
    if (!pid || !pickupImageOn)
        return false
    level := RoomRecordLevelV259(pid)
    return level>0 && !FarmReviveTownLevelV295(level)
}

PickupFarmResetV762()
{
    global pickupFarmAttemptsV762
    pickupFarmAttemptsV762 := {}
}

PickupFarmKeyV762(pid,uid)
{
    global farmRunEpochV535
    return pid . "|" . farmRunEpochV535 . "|" . uid
}

PickupFarmStateV762(pid,uid,cls:=0)
{
    global pickupFarmAttemptsV762
    if (!IsObject(pickupFarmAttemptsV762))
        pickupFarmAttemptsV762 := {}
    key := PickupFarmKeyV762(pid,uid)
    if (!pickupFarmAttemptsV762.HasKey(key))
        pickupFarmAttemptsV762[key] := {uid:uid,cls:cls,tries:0,lastAt:0,skip:false,skipUntil:0}
    state := pickupFarmAttemptsV762[key]
    if (cls)
        state.cls := cls
    return state
}

PickupFarmSkipV762(pid,uid,cls,reason,durationMs:=0)
{
    global pickupContextModeV765,sigFailedItemsV765
    if (pickupContextModeV765 = "SIG")
    {
        if (!IsObject(sigFailedItemsV765))
            sigFailedItemsV765 := {}
        if (!sigFailedItemsV765.HasKey(uid))
        {
            sigFailedItemsV765[uid] := {uid:uid,cls:cls,reason:reason,at:A_TickCount}
            DebugTraceWrite("pickup","SIG_PICKUP_FAIL uid=" . uid . " class=" . cls . " reason=" . reason)
            FonInfoPushV385("[SIG] Chưa nhặt được UID " . uid . " class " . cls
                . " — " . reason . ". Tiếp tục quét và thử nhặt; chưa báo Done.")
        }
        return true
    }
    state := PickupFarmStateV762(pid,uid,cls)
    ; Farm: khong bo qua BAT KY vat pham nao nam trong danh sach nhat.
    ; Loi tam thoi chi ngu 2 giay de Farm tiep tuc danh/di roi thu lai.
    ; SIG giu nguyen luong rieng o phia tren.
    if (PickupFarmBudgetActiveV762(pid))
    {
        FarmPickupTimedSkipV1602(pid,RoomRecordLevelV259(pid),uid,reason)
        state.skip := false, state.skipUntil := 0
        state.tries := 0, state.lastAt := 0, state.startedAtV940 := 0
        DebugTraceWrite("pickup","FARM_PICKUP_RETRY_NO_SKIP uid=" . uid
            . " class=" . cls . " reason=" . reason . " next=RESCAN_AND_TELE")
        return false
    }
    if (state.skip)
        return true
    state.skip := true
    state.skipUntil := A_TickCount+Max(1000,durationMs)
    DebugTraceWrite("pickup","FARM_PICKUP_SKIP uid=" . uid . " class=" . cls
        . " reason=" . reason . " until=" . state.skipUntil)
    FonInfoPushV385("[Nhặt farm] Bỏ qua UID " . uid . " trong lượt farm này; " . reason)
    return true
}

PickupFarmIgnoredV762(pid,uid)
{
    global pickupFarmAttemptsV762,pickupContextModeV765,sigFailedItemsV765
    if (pickupContextModeV765!="SIG"
        && FarmPickupTimedIgnoreV1602(pid,RoomRecordLevelV259(pid),uid))
        return true
    ; SIG records unresolved pickup failures for its DONE proof, but must
    ; keep scanning and trying the same UID while it remains on the ground.
    if (pickupContextModeV765 = "SIG")
        return false
    ; Farm khong dung danh sach UID skip (ke ca skip cu cua cac lan retry).
    if (PickupFarmBudgetActiveV762(pid))
        return false
    if (!IsObject(pickupFarmAttemptsV762))
        return false
    key := PickupFarmKeyV762(pid,uid)
    if (!pickupFarmAttemptsV762.HasKey(key))
        return false
    state := pickupFarmAttemptsV762[key]
    if (!PickupFarmBudgetActiveV762(pid))
        return false
    if (state.skip && state.skipUntil && A_TickCount>=state.skipUntil)
    {
        state.skip := false,state.tries := 0,state.lastAt := 0,state.startedAtV940 := 0
    }
    return state.skip
}

PickupFarmTryV762(pid,uid,cls:=0)
{
    if (!PickupFarmBudgetActiveV762(pid))
        return true
    if (PickupFarmIgnoredV762(pid,uid))
        return false
    state := PickupFarmStateV762(pid,uid,cls)
    ; Ba lan gui loi KHONG phai ly do bo qua item farm.
    ; Nghi ngan giua cac dot roi thu lai de con co the TELE xu ly loi.
    if (state.tries>=3)
    {
        if (A_TickCount-state.lastAt<350)
            return false
        state.tries := 0
    }
    if (state.tries && A_TickCount-state.lastAt<100)
        return false
    state.tries++
    state.lastAt := A_TickCount
    DebugTraceWrite("pickup","FARM_PICKUP_TRY uid=" . uid . " attempt=" . state.tries . "/3")
    return true
}

PickupFarmForgetV762(pid,uid)
{
    global pickupFarmAttemptsV762
    if (IsObject(pickupFarmAttemptsV762))
        pickupFarmAttemptsV762.Delete(PickupFarmKeyV762(pid,uid))
}

PickupFarmSkipUnitV762(h,unit)
{
    global pickupFarmAttemptsV762
    if (!IsObject(pickupFarmAttemptsV762) || !pickupFarmAttemptsV762.Count())
        return false
    mode := D2ReadU32(h,unit+0x10)
    if (mode!=3 && mode!=5)
        return false
    return PickupFarmIgnoredV762(D2GetProcessIdFromHandle(h),D2ReadU32(h,unit+0x0C))
}

SigEntryStopV762(r,reason)
{
    global sigTerminalErrorV762,sigLastStopReasonV63
    if (reason="")
        reason := "Không khởi động được SIG"
    r.stage1SigBlockedV654 := false,r.sigErrorHoldV769 := true
    SigLogV147("SIG_ENTRY_ABORT attempts=" . r.sigAttemptsV762 . " reason=" . reason . " next=ERROR_KEEP_FARM")
    FarmErrorKeepV769("SIG_ENTRY_FAILED " . reason)
    sigTerminalErrorV762 := reason
    sigLastStopReasonV63 := reason
    FonInfoPushV385("[SIG] Lỗi; phiên farm vẫn bật, chờ xử lý: " . reason)
    ToolTipInfoV386("SIG đã dừng: " . reason . " — giữ đồ, không gửi lặp.")
    SetTimer, RemoveToolTip, -10000
    return false
}

CubeResetProofSerialV754()
{
    global cubeResetSerialV754
    return cubeResetSerialV754
}

CubeResetPendingV754(pid:=0)
{
    global cubeResetHoldsV754
    if (!IsObject(cubeResetHoldsV754))
        return false
    for _,state in cubeResetHoldsV754
        if (!pid || state.pid=pid)
            return true
    return false
}

CubeResetHoldV754(pid,h,player,uid)
{
    global cubeResetHoldsV754,cubeResetSerialV754
    if (!IsObject(cubeResetHoldsV754))
        cubeResetHoldsV754 := {}
    SigProtectionArmV761(pid)
    level := RoomRecordLevelV259(pid)
    path := D2ReadU32(h,player+0x2C)
    x := D2ReadU16(h,path+2),y := D2ReadU16(h,path+6)
    cubeResetSerialV754++
    key := pid . "|" . level . "|" . uid
    cubeResetHoldsV754[key] := {pid:pid,level:level,uid:uid,serial:cubeResetSerialV754
        ,x:x,y:y,checks:0,emptyAt:0}
    FarmWatchSigGateV753(FarmWatchStateV688(),FarmWatchNowV688())
    PortalLogWriteV66("CUBE_RESET_HOLD uid=" . uid . " next=WAIT_VERIFIED_PICKUP")
}

CubeResetConfirmV754(pid,level,h,player,serial,onlyUid:=0)
{
    global cubeResetHoldsV754
    if (!level || !CubeResetPendingV754(pid) || RoomRecordLevelV259(pid)!=level)
        return false
    inv := D2ReadU32(h,player+0x60)
    cursor := PickupCursorV4(h,inv)
    if (!inv || !IsObject(cursor) || cursor.unit)
        return false
    all := V9SnapshotAllItems({h:h,inv:inv,first:D2ReadU32(h,inv+0x10)})
    cleared := false
    for key,state in cubeResetHoldsV754.Clone()
    {
        if (state.pid!=pid || state.level!=level || state.serial>serial || (onlyUid && state.uid!=onlyUid))
            continue
        cube := all[state.uid]
        if (!IsObject(cube) || cube.cls!=1204 || cube.loc!=0 || cube.owner!=inv
            || D2ReadU32(h,cube.unit+0x10)=3 || D2ReadU32(h,cube.unit+0x10)=5)
            continue
        if (cubeResetHoldsV754[key].serial!=state.serial)
            continue
        cubeResetHoldsV754.Delete(key)
        cleared := true
        PortalLogWriteV66("CUBE_RESET_PICKUP_DONE uid=" . state.uid . " next=RESUME_IDLE_WHEN_WORK_FINISHED")
    }
    if (cleared)
        FarmWatchSigGateV753(FarmWatchStateV688(),FarmWatchNowV688())
    return cleared
}

CubeResetVerifiedV754(pid,level,serial)
{
    if (!CubeResetPendingV754(pid))
        return true
    base := D2GetModuleBaseV35(pid,"D2Client.dll")
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        if (!player)
            return false
        CubeResetConfirmV754(pid,level,h,player,serial)
        return !CubeResetPendingV754(pid)
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

CubeResetNormalScanV754(pid,level,h,player,serial,clear,px,py)
{
    global cubeResetHoldsV754,sigBusyV147,sigActiveModeV182,ticketPickupWaitV279
    if (!CubeResetPendingV754(pid) || sigBusyV147 || sigActiveModeV182!=""
        || IsObject(ticketPickupWaitV279))
        return
    ready := false,readySerial := 0,readyUid := 0
    for _,state in cubeResetHoldsV754
    {
        if (state.pid!=pid || state.level!=level || state.serial>serial)
            continue
        if (!clear || state.x<1 || state.y<1 || (px-state.x)**2+(py-state.y)**2>1)
        {
            state.checks := 0,state.emptyAt := 0
            continue
        }
        if (!state.emptyAt)
            state.emptyAt := A_TickCount
        state.checks++
        if (state.checks>=3 && A_TickCount-state.emptyAt>=1200)
            ready := true,readySerial := state.serial,readyUid := state.uid
    }
    if (ready)
        CubeResetConfirmV754(pid,level,h,player,readySerial,readyUid)
}

SigProtectionArmV761(pid)
{
    global sigProtectionSessionV761,sigSessionSerialV761,backgroundPidV63,backgroundBirthV63,backgroundHwndV63
    if (!pid)
        return sigSessionSerialV761+0
    state := sigProtectionSessionV761
    if (!IsObject(state) || state.ended)
    {
        birth := BackgroundBirthV63(pid)
        if (birth="" && pid=backgroundPidV63)
            birth := backgroundBirthV63
        sigSessionSerialV761++
        sigProtectionSessionV761 := {pid:pid,birth:birth,hwnd:pid=backgroundPidV63 ? backgroundHwndV63 : 0
            ,roomName:GameRoomLiveNameV252(pid),serial:sigSessionSerialV761,nextProbe:0,ended:false}
    }
    return sigSessionSerialV761+0
}

SigProtectionEvidenceV761(state,code,now)
{
    if (code="PROCESS_EXITED" || code="PROCESS_REPLACED" || code="NEW_ROOM")
        return true
    definite := code="WINDOW_LOST" || code="LEFT_SESSION" || code="UNEXPECTED_LOBBY"
        || code="STAGE3_LOBBY" || code="CRASH_DIALOG"
    if (!definite)
    {
        state.evidenceCode := "",state.evidenceAt := 0,state.evidenceReads := 0
        return false
    }
    if (state.evidenceCode!=code)
        state.evidenceCode := code,state.evidenceAt := now,state.evidenceReads := 0
    state.evidenceReads++
    return state.evidenceReads>=2 && now-state.evidenceAt>=2000
}

SigProtectionEndedV761(pid)
{
    global sigProtectionSessionV761
    return IsObject(sigProtectionSessionV761) && sigProtectionSessionV761.pid=pid && sigProtectionSessionV761.ended
}

SigProtectionProcessCodeV761(state)
{
    if (!state.pid)
        return ""
    Process, Exist, % state.pid
    if (!ErrorLevel)
        return "PROCESS_EXITED"
    birth := BackgroundBirthV63(state.pid)
    if (state.birth!="" && birth!="" && state.birth!=birth)
        return "PROCESS_REPLACED"
    if (state.birth="" && birth!="")
        state.birth := birth
    return ""
}

SigProtectionMenuCodeV761(state)
{
    ui := RecoveryMenuSnapshotV528(state)
    if (!IsObject(ui) || !ui.ok)
        return ""
    if (ui.login || ui.menu || ui.character || ui.splash)
        return "LEFT_SESSION"
    lobby := StageThreeUiV533(state)
    if (IsObject(lobby) && lobby.ok
        && (IsObject(lobby.roles.openCreate) || IsObject(lobby.roles.createRoom)))
        return "UNEXPECTED_LOBBY"
    return ""
}

SigProtectionPurgeV761(state)
{
    global sigResetPendingV753,sigPostPickupV655,ticketPickupWaitV279,cubeResetHoldsV754,scosEntryV162
    sigResetPendingV753 := false
    if (IsObject(sigPostPickupV655) && sigPostPickupV655.pid=state.pid)
        sigPostPickupV655 := false
    if (IsObject(ticketPickupWaitV279) && ticketPickupWaitV279.pid=state.pid)
        ticketPickupWaitV279 := false
    if (IsObject(cubeResetHoldsV754))
        for key,hold in cubeResetHoldsV754.Clone()
            if (hold.pid=state.pid)
                cubeResetHoldsV754.Delete(key)
    if (IsObject(scosEntryV162) && scosEntryV162.pid=state.pid)
        scosEntryV162.stage1SigBlockedV654 := false,scosEntryV162.sigFailLoggedV374 := false
}

SigProtectionReleaseV761(state,reason)
{
    global sigProtectionSessionV761,sigSessionSerialV761,sigResetPendingV753,sigPostPickupV655
    global ticketPickupWaitV279,cubeResetHoldsV754,sigBusyV147,sigCancelV147,sigActiveModeV182,sigSendingKeyV147
    global sigLastStopReasonV63,scosEntryV162,pickupRoundResetV1,farmWatchV5
    if (!IsObject(state) || state.ended)
        return false
    if (IsObject(sigProtectionSessionV761) && sigProtectionSessionV761!=state)
        return false
    activeCallback := sigBusyV147 || sigActiveModeV182!=""
        || (IsObject(ticketPickupWaitV279) && ticketPickupWaitV279.pid=state.pid)
    state.ended := true
    sigSessionSerialV761++
    sigCancelV147 := true
    SigProtectionPurgeV761(state)
    if (!activeCallback)
        sigActiveModeV182 := "",sigSendingKeyV147 := false
    sigLastStopReasonV63 := "Phiên game cũ đã kết thúc; đã xóa trạng thái SIG cũ"
    pickupRoundResetV1 := true
    if (IsObject(farmWatchV5))
    {
        ; Only the end of a protected SIG session restarts the idle interval.
        ; Losing an unrelated game session must not erase elapsed standing time.
        if (farmWatchV5.sigPausedV753)
            farmWatchV5.idleAtV650 := FarmWatchNowV688()
        farmWatchV5.sigPausedV753 := false
        farmWatchV5.retryAtV688 := 0
        farmWatchV5.standSampleV650 := false
    }
    PortalLogWriteV66("SIG_SESSION_RELEASE reason=" . reason . " pid=" . state.pid . " old_contexts=INVALIDATED next=RECOVERY_ALLOWED")
    return true
}

SigProtectionWatchV761()
{
    global sigProtectionSessionV761,backgroundPidV63,sigPostPickupV655,ticketPickupWaitV279,scosEntryV162
    global sigBusyV147,sigActiveModeV182,sigCancelV147
    static busy := false
    if (busy)
        return false
    busy := true
    try
    {
        if (IsObject(sigProtectionSessionV761) && sigProtectionSessionV761.ended
            && !sigBusyV147 && sigActiveModeV182="" && !IsObject(ticketPickupWaitV279))
        {
            SigProtectionPurgeV761(sigProtectionSessionV761)
            sigCancelV147 := false
        }
        blocked := IsObject(scosEntryV162) && scosEntryV162.stage1SigBlockedV654
        if (!SigResetProtectedV753() && !blocked)
            return false
        state := sigProtectionSessionV761
        if (!IsObject(state))
        {
            pid := backgroundPidV63
            if (IsObject(sigPostPickupV655))
                pid := sigPostPickupV655.pid
            else
                if (IsObject(ticketPickupWaitV279))
                    pid := ticketPickupWaitV279.pid
            if (!pid)
                return false
            SigProtectionArmV761(pid)
            state := sigProtectionSessionV761
        }
        if (state.ended)
            return false
        now := FarmWatchNowV688()
        if (now<state.nextProbe)
            return false
        state.nextProbe := now+1000
        code := SigProtectionProcessCodeV761(state)
        if (code="")
        {
            probe := FarmWatchProbeV541(state)
            code := probe.code
        }
        if (code="DLL_READ_UNKNOWN" || code="DLL_VERSION_UNKNOWN" || code="CHARACTER_UNREADABLE"
            || code="NO_PLAYER_STALLED" || code="MODAL_WITHOUT_GAME")
        {
            menuCode := SigProtectionMenuCodeV761(state)
            if (menuCode!="")
                code := menuCode
        }
        if (code="IN_GAME")
        {
            name := GameRoomLiveNameV252(state.pid)
            if (state.roomName!="" && name!="" && name!=state.roomName)
                code := "NEW_ROOM"
            else
                if (state.roomName="" && name!="")
                    state.roomName := name
        }
        if (!SigProtectionEvidenceV761(state,code,now))
            return false
        return SigProtectionReleaseV761(state,code)
    }
    finally
        busy := false
}

SigResetProtectedV753()
{
    global sigBusyV147,sigSendingKeyV147,sigActiveModeV182,ticketPickupWaitV279
    global sigPostPickupV655,sigResetPendingV753,ticket130BusyV265
    return SigPickupOwnedV764() || CubeResetPendingV754() || ticket130BusyV265 || sigResetPendingV753 || IsObject(sigPostPickupV655)
        || sigBusyV147 || sigSendingKeyV147 || sigActiveModeV182!=""
        || (IsObject(ticketPickupWaitV279) && ticketPickupWaitV279.active
            && (ticketPickupWaitV279.sigScopeV654 || ticketPickupWaitV279.resetProtectedV754))
}

; Only an executing SIG / SIG-owned pickup is character activity.
; sigResetPending, sigPostPickup and Cube reset holds are SAFETY flags,
; never proof the character is acting (Farm may already be running).
FarmWatchSigActiveV753()
{
    global sigBusyV147,sigActiveModeV182,ticketPickupWaitV279
    if (sigBusyV147 || sigActiveModeV182!="" || SigPickupOwnedV764())
        return true
    return IsObject(ticketPickupWaitV279) && ticketPickupWaitV279.active
        && (ticketPickupWaitV279.sigScopeV654 || ticketPickupWaitV279.resetProtectedV754)
}

; A confirmed real action overrides a pending watchdog wait, regardless
; of which workflow left that wait in place. Do not touch the live
; SIG/Cube/pickup safety locks: this is only the standing watchdog state.
FarmWatchRealActivityV1080(w,now)
{
    w.idleAtV650 := now
    w.retryAtV688 := 0
    w.activeThisTickV691 := true
    if (w.sigPausedV753 || FarmWatchSigActiveV753())
    {
        w.sigWaitBypassedV1080 := true
        w.sigPausedV753 := false
    }
}

FarmWatchSigGateV753(w,now)
{
    sigActive := FarmWatchSigActiveV753()
    ; Once the SIG job truly ends, future independent SIG jobs can pause
    ; the counter again; an old waiting flag must not block a live farmer.
    if (!sigActive)
        w.sigWaitBypassedV1080 := false
    if (sigActive && w.sigWaitBypassedV1080)
        return false
    if (sigActive)
    {
        ; Working SIG is character activity. Keep a live baseline so that
        ; movement/attack can immediately override a stale SIG wait.
        w.idleAtV650 := now
        w.retryAtV688 := 0
        w.sigPausedV753 := true
        w.activeThisTickV691 := true
        return true
    }
    if (w.sigPausedV753)
    {
        ; A completed SIG starts a fresh inactivity interval; no time jump.
        w.idleAtV650 := now
        w.retryAtV688 := 0
        w.workProgressV736 := false
        w.sigPausedV753 := false
        w.activeThisTickV691 := false
        return true
    }
    return false
}

FarmWatchAttackingV688(sample,pid,uid,at,tick)
{
    if (!IsObject(sample))
        return false
    attackMode := sample.mode=7 || sample.mode=8
        || (sample.mode>=10 && sample.mode<=16) || sample.mode=18
    return attackMode && pid=sample.pid && uid>0 && at>0 && tick-at>=0 && tick-at<1200
}

FarmWatchIdleStateV688(w,sample,attacking,now)
{
    if (!w.enabled)
    {
        w.activeThisTickV691 := false
        w.standSampleV650 := false
        return false
    }
    ; Always examine real character activity BEFORE inspecting any wait.
    ; This is what releases the watchdog from a stale SIG/wait flag.
    if (IsObject(sample))
    {
        w.sampleMissingAtV650 := 0
        previous := w.standSampleV650
        same := IsObject(previous) && previous.pid=sample.pid && previous.birth=sample.birth
        moved := same && ((sample.x-previous.x)**2+(sample.y-previous.y)**2>=1)
        attackMode := sample.mode=7 || sample.mode=8 || sample.mode=9
            || (sample.mode>=10 && sample.mode<=16) || sample.mode=18
        animated := same && attackMode && (previous.mode!=sample.mode || previous.frame!=sample.frame)
        w.standSampleV650 := sample
        if (moved || animated)
        {
            FarmWatchRealActivityV1080(w,now)
            return false
        }
    }
    else if (!w.sampleMissingAtV650)
        w.sampleMissingAtV650 := now

    ; A live attack mode plus a recent dispatched attack is a short activity
    ; signal; the independent combat-stall probe still rejects non-progress.
    if (attacking)
    {
        FarmWatchRealActivityV1080(w,now)
        return false
    }

    ; Do not interrupt a working SIG. A confirmed resumed action above
    ; bypasses only the stale watchdog wait, never SIG's item protection.
    if (FarmWatchSigGateV753(w,now))
        return false
    w.activeThisTickV691 := false
    ; Missing player, first sample or a stationary character are all idle.
    return now-w.idleAtV650>=w.period
}

; One shared activity refresh for the watchdog timer and every automatic
; stage/reconnect wait: none may act on a stale standing clock.
FarmWatchRefreshActivityV1080(w,ByRef sample := "",force := false)
{
    global currentAttackUidV520,currentAttackAtV520,currentAttackPidV550
    now := FarmWatchNowV688()
    if (!force && w.HasKey("watchProbedAtV1080") && now-w.watchProbedAtV1080<250)
    {
        sample := w.watchSampleV1080
        return w.watchIdleDueV1080
    }
    sample := false
    try
        sample := FarmStandSampleV650(w)
    attacking := FarmWatchAttackingV688(sample,currentAttackPidV550,currentAttackUidV520
        ,currentAttackAtV520,A_TickCount)
    now := FarmWatchNowV688()
    due := FarmWatchIdleStateV688(w,sample,attacking,now)
    w.watchSampleV1080 := sample
    w.watchProbedAtV1080 := now
    w.watchIdleDueV1080 := due
    return due
}

FarmWatchItemsV736(h,player)
{
    inv := D2ReadU32(h,player+0x60)
    if (!inv || !MonsterBossProbeReadV1(h,inv,0x24,ib))
        return ""
    first := NumGet(ib,0x10,"UInt"),cursor := NumGet(ib,0x20,"UInt")
    queue := [first,cursor],seen := {},items := {},index := 1
    while (index<=queue.Length())
    {
        if (index>8192)
            return ""
        unit := queue[index],index++
        if (!unit || seen.HasKey(unit))
            continue
        seen[unit] := true
        if (!MonsterBossProbeReadV1(h,unit,0xEC,ub))
            return ""
        typ := NumGet(ub,0,"UInt"),data := NumGet(ub,0x14,"UInt")
        for _,offset in [0xE4,0xE8]
        {
            next := NumGet(ub,offset,"UInt")
            if (next && !seen.HasKey(next))
                queue.Push(next)
        }
        if (typ!=4 || !data)
            continue
        if (!MonsterBossProbeReadV1(h,data,0xDC,db))
            return ""
        uid := NumGet(ub,0x0C,"UInt"),path := NumGet(ub,0x2C,"UInt")
        if (!uid || !path || !MonsterBossProbeReadV1(h,path,0x14,pb))
            return ""
        items[uid] := NumGet(ub,4,"UInt") . ":" . NumGet(ub,0x10,"UInt")
            . ":" . NumGet(db,0x45,"UChar") . ":" . NumGet(db,0x5C,"UInt")
            . ":" . NumGet(pb,0x0C,"UInt") . ":" . NumGet(pb,0x10,"UInt")
        for _,offset in [0x60,0x64,0x6C,0x70,0x84,0xAC,0xB0,0xB4,0xC8,0xD8]
        {
            next := NumGet(db,offset,"UInt")
            if (next && !seen.HasKey(next) && D2ReadU32(h,next)=4)
                queue.Push(next)
        }
    }
    result := "cursor=" . cursor
    for uid,item in items
        result .= "|" . uid . ":" . item
    if (!PickupReadU32V4(h,inv+0x20,checkCursor) || checkCursor!=cursor)
        return ""
    return result
}

FarmWatchStartV5()
{
    w := FarmWatchStateV688()
    FarmWatchSettingsV5()
    ; Starting Farm is not character activity: preserve the standing clock.
    w.standSampleV650 := false
    w.sampleMissingAtV650 := 0
    w.healthEvidenceV541 := false
    w.retryAtV688 := 0
}

FarmWatchStopV5()
{
    w := FarmWatchStateV688()
    ; Stopping Farm is not character activity either.
    w.standSampleV650 := false
    w.sampleMissingAtV650 := 0
}

FarmWatchSettingsV5()
{
    global farmResetWatchEnabledV217,farmResetWatchMinutesV217
    w := FarmWatchStateV688()
    enable := farmResetWatchEnabledV217 ? true : false
    minutes := Max(1,Min(60,farmResetWatchMinutesV217))
    if (w.enabled!=enable)
    {
        ; Only reset the idle clock when the user changes the enabled state.
        ; A timer tick must not restart the countdown every second.
        w.idleAtV650 := FarmWatchNowV688()
        w.standSampleV650 := false
        w.sampleMissingAtV650 := 0
        w.workProgressV736 := false
        w.retryAtV688 := 0
        w.activeThisTickV691 := false
    }
    w.enabled := enable
    w.period := minutes*60000
}

FarmWatchProgressV5()
{
    global farmWatchV5
    if (IsObject(farmWatchV5) && farmWatchV5.enabled)
    {
        ; This hook is only called after confirmed HP progress.
        now := FarmWatchNowV688()
        farmWatchV5.progressAt := now
        ; HP changes alone are not proof that this character attacked/moved.
        ; The live character sampler is the sole source for resetting standing.
    }
}

FarmWatchObserveV5(pid,level,x,y)
{
    global farmWatchV5,farmControlOwnerV186,backgroundPidV63,backgroundHwndV63,backgroundBirthV63
    w := farmWatchV5
    if (!IsObject(w) || !pid || !level || !x || !y)
        return
    if (farmControlOwnerV186!="")
        w.owner := farmControlOwnerV186
    birth := pid=backgroundPidV63 ? backgroundBirthV63 : BackgroundBirthV63(pid)
    if (pid=backgroundPidV63)
        w.pid := pid,w.hwnd := backgroundHwndV63,w.birth := backgroundBirthV63
    ; First sight of a character/session is just a baseline, not movement.
    if (!w.HasKey("x") || w.samplePid!=pid || w.sampleBirthV650!=birth
        || w.sampleMissingAtV650 || !IsObject(w.standSampleV650))
    {
        w.samplePid := pid,w.sampleBirthV650 := birth
        w.level := level,w.x := x,w.y := y
        return
    }
    if (w.level!=level || (x-w.x)**2+(y-w.y)**2>=1)
    {
        ; Only changed coordinates/map from the same live character prove movement.
        now := FarmWatchNowV688()
        w.progressAt := now,w.level := level,w.x := x,w.y := y
        if (w.enabled)
            FarmWatchRealActivityV1080(w,now)
    }
}


FarmWatchStuckBeginV679(episode,pid,kind,started:=0)
{
    return false
}


FarmStuckWatchTimerV679:
if (farmUserPausedV2026)
    return
FarmWatchStuckDueV679()
return

FarmWatchStuckDueV679()
{
    return
}

FarmWatchPhaseV541()
{
    global stageTwoV166,scosEntryV162,sigTownV148,mapWorkflowV185,autoMonsterAttackOn
    if (IsObject(stageTwoV166))
        return "STAGE3:" . stageTwoV166.phase . ":" . stageTwoV166.loginStepV489
    if (IsObject(scosEntryV162))
        return "ENTRY:" . scosEntryV162.map . ":" . scosEntryV162.phase . ":" . scosEntryV162.boStageV413 . ":" . scosEntryV162.cainPhaseV383
    if (IsObject(sigTownV148))
        return "TOWN:" . sigTownV148.step
    return autoMonsterAttackOn ? "FARM" : "IDLE"
}

FarmWatchResultV541(code,reason,candidate := false,confirmMs := 0,samples := 1)
{
    return {code:code,reason:reason,candidate:candidate,confirmMs:confirmMs,samples:samples}
}

FarmWatchDialogTextV541(dialog)
{
    WinGet, children, ControlListHwnd, ahk_id %dialog%
    text := "",count := 0
    Loop, Parse, children, `n, `r
    {
        child := A_LoopField+0
        WinGetClass, cls, ahk_id %child%
        if (cls!="Static")
            continue
        if (++count>8)
            break
        VarSetCapacity(buf,2048,0),answer := 0
        if (DllCall("SendMessageTimeoutW","Ptr",child,"UInt",0xD,"UPtr",1024,"Ptr",&buf
            ,"UInt",34,"UInt",100,"PtrP",answer,"Ptr"))
            text .= " " . StrGet(&buf,"UTF-16")
    }
    return text
}

FarmWatchProbeV541(w,windowOnlyV631 := false)
{
    global backgroundPidV63,backgroundHwndV63,backgroundBirthV63,stageTwoV166
    pid := w.pid ? w.pid : backgroundPidV63
    birth := w.birth!="" ? w.birth : backgroundBirthV63
    hwnd := w.hwnd ? w.hwnd : backgroundHwndV63
    if (!pid || birth="")
        return FarmWatchResultV541("NO_IDENTITY","Chưa xác định được tiến trình game; không kết luận game lỗi")
    Process, Exist, %pid%
    if (!ErrorLevel)
        return FarmWatchResultV541("PROCESS_EXITED","Tiến trình game đã đóng/crash",true)
    liveBirth := BackgroundBirthV63(pid)
    if (liveBirth="")
        return FarmWatchResultV541("PROCESS_READ_UNKNOWN","Chưa đọc được danh tính tiến trình game")
    if (liveBirth!=birth)
        return FarmWatchResultV541("PROCESS_REPLACED","Tiến trình game cũ đã kết thúc",true)
    WinGet, windowsV541, List, ahk_pid %pid%
    Loop, %windowsV541%
    {
        dialog := windowsV541%A_Index%
        WinGetClass, cls, ahk_id %dialog%
        if (cls!="#32770" || !DllCall("IsWindowVisible","Ptr",dialog))
            continue
        WinGetTitle, title, ahk_id %dialog%
        body := FarmWatchDialogTextV541(dialog)
        if (RegExMatch(title . " " . body,"i)unhandled exception|access[_ ]violation|assertion (?:failure|failed)|fatal error|c0000005|diablo ii exception|application error|unrecoverable internal error|bad inventory data|out of memory"))
            return FarmWatchResultV541("CRASH_DIALOG","Game hiện thông báo crash/exception",true,500,2)
    }
    contact := {pid:pid,hwnd:hwnd,birth:birth}
    if (!RecoveryGameWindowContactV498(contact))
        return FarmWatchResultV541("WINDOW_LOST","Không còn cửa sổ game trong đúng tiến trình",true,2000,2)
    hwnd := contact.hwnd,w.hwnd := hwnd
    WinGet, minmax, MinMax, ahk_id %hwnd%
    if (minmax=-1)
        return FarmWatchResultV541("MINIMIZED","Game đang thu nhỏ; không coi là lỗi")
    answer := 0
    if (DllCall("IsHungAppWindow","Ptr",hwnd)
        || !DllCall("SendMessageTimeoutW","Ptr",hwnd,"UInt",0,"Ptr",0,"Ptr",0,"UInt",34,"UInt",500,"PtrP",answer,"Ptr"))
        return FarmWatchResultV541("WINDOW_HUNG","Cửa sổ game liên tục không phản hồi",true,3000,3)
    if (windowOnlyV631)
        return FarmWatchResultV541("WINDOW_RESPONDING","Cửa sổ game còn phản hồi")
    base := D2GetModuleBaseV35(pid,"D2Client.dll"),h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return FarmWatchResultV541("DLL_READ_UNKNOWN","Không đọc được DLL game; chưa đủ bằng chứng để đóng game")
    try
    {
        if (!RecoveryMenuModuleV528(h,base,0x4B95CA3E,0x135000))
            return FarmWatchResultV541("DLL_VERSION_UNKNOWN","DLL game khác phiên bản; không coi lỗi đọc là game treo")
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (player && MonsterBossProbeReadV1(h,path,0x20,pb))
        {
            level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
            x := NumGet(pb,2,"UShort"),y := NumGet(pb,6,"UShort")
            if (level && x && y)
            {
                FarmWatchObserveV5(pid,level,x,y)
                mode := D2ReadU32(h,player+0x10)
                if (mode=0 || mode=17)
                    return FarmWatchResultV541("DEAD_OR_REVIVING","Nhân vật đang chết/hồi sinh; giữ luồng hồi sinh")
                return FarmWatchResultV541("IN_GAME","Game còn nhân vật/map hợp lệ; đứng yên không phải bằng chứng lỗi")
            }
        }
        ui := RecoveryMenuSnapshotV528(contact)
        if (ui.ok && !ui.modal && (ui.login || ui.menu || ui.character || ui.splash))
            return FarmWatchResultV541("LEFT_SESSION","Game đã văng về màn hình đăng nhập/chọn nhân vật",true,3000,2)
        if (!ui.ok)
            return FarmWatchResultV541("CHARACTER_UNREADABLE","Không đọc được nhân vật trong luồng đang chơi",true,30000,3)
        multi := D2GetModuleBaseV35(pid,"D2Multi.dll"),lobby := false
        if (multi && RecoveryMenuModuleV528(h,multi,0x4B95C235,0x3F000))
            for _,control in ui.controls
                if (control.type=6 && (control.callback=multi+0x15380 || control.callback=multi+0x142C0))
                    lobby := true
        if (lobby && IsObject(stageTwoV166) && stageTwoV166.pid=pid)
            return FarmWatchResultV541("STAGE3_LOBBY","GĐ3 đang ở sảnh/tạo phòng; tiếp tục GĐ3")
        if (lobby)
            return FarmWatchResultV541("UNEXPECTED_LOBBY","Game đã ra sảnh ngoài luồng tạo phòng",true,3000,2)
        if (ui.modal)
            return FarmWatchResultV541("MODAL_WITHOUT_GAME","Game mắc ở thông báo/chờ kết nối và không có nhân vật",true,30000,3)
        return FarmWatchResultV541("NO_PLAYER_STALLED","Game không vào lại được map/nhân vật trong cùng một bước",true,30000,3)
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

FarmWatchConfirmV541(state,probe)
{
    if (!probe.candidate)
    {
        state.healthEvidenceV541 := false
        return false
    }
    key := state.pid . "|" . state.birth . "|" . probe.code . "|" . FarmWatchPhaseV541()
    e := state.healthEvidenceV541
    if (!IsObject(e) || e.key!=key)
        state.healthEvidenceV541 := e := {key:key,at:A_TickCount,reads:0}
    e.reads++
    return e.reads>=probe.samples && A_TickCount-e.at>=probe.confirmMs
}

FarmWatchHealthV5(w)
{
    probe := FarmWatchProbeV541(w)
    w.healthProbeV541 := probe
    return probe.candidate ? probe.reason : ""
}

FarmStandSampleV650(w)
{
    global backgroundPidV63,backgroundHwndV63
    global sigBusyV147,gameItemActionOwner,xRunning,zRunning,buffSequenceRunningV555
    pid := backgroundPidV63 ? backgroundPidV63 : w.pid
    birth := pid ? BackgroundBirthV63(pid) : ""
    if (birth="")
    {
        pid := CoordDisplayGamePidV1()
        birth := pid ? BackgroundBirthV63(pid) : ""
    }
    if (pid && birth!="")
    {
        w.pid := pid,w.birth := birth
        contact := {pid:pid,birth:birth,hwnd:backgroundPidV63=pid ? backgroundHwndV63 : w.hwnd}
        if (RecoveryGameWindowContactV498(contact))
            w.hwnd := contact.hwnd
    }
    base := birth!="" ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!player || !MonsterBossProbeReadV1(h,path,0x20,pb))
            return false
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        x := NumGet(pb,2,"UShort"),y := NumGet(pb,6,"UShort")
        if (!level || !x || !y || BackgroundBirthV63(pid)!=birth)
            return false
        if (!MonsterBossProbeReadV1(h,player,0x48,unitSampleV736))
            return false
        itemSampleV736 := FarmWatchItemsV736(h,player)
        workingV736 := sigBusyV147 || gameItemActionOwner!="" || xRunning || zRunning || buffSequenceRunningV555
        return {pid:pid,birth:birth,hwnd:w.hwnd,level:level,x:x,y:y
            ,mode:NumGet(unitSampleV736,0x10,"UInt"),frame:NumGet(unitSampleV736,0x44,"UInt")
            ,items:itemSampleV736,working:workingV736}
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

FarmWatchDueV5()
{
    global currentAttackUidV520,currentAttackAtV520,currentAttackPidV550
    global stageTwoV166,mapWorkflowV185
    static busy := false
    if (busy)
        return
    busy := true
    try
    {
        w := FarmWatchStateV688()
        FarmWatchSettingsV5()
        SigProtectionWatchV761()
        ; Farm ON/OFF does not decide whether the character is standing.
        if (!w.enabled)
            return
        ; Always read the character first, even while a recovery or SIG
        ; workflow is waiting for a status that may never arrive.
        idleDue := FarmWatchRefreshActivityV1080(w,sample,true)
        now := FarmWatchNowV688()
        if (IsObject(stageTwoV166) && stageTwoV166.loginRecoveryV489)
            return  ; Existing recovery owns reconnect; the clock is still refreshed.
        if (w.sigPausedV753)
            return
        FarmWatchCombatStuckV903(w)
        if (!w.activeThisTickV691)
        {
            try
                BackgroundRefreshV690(w)
        }
        if (idleDue)
        {
            ; If the character cannot be read (disconnected/menu/crash), that
            ; is NOT movement and must not cancel the timeout. The recovery
            ; flow then relaunches Game.exe and logs back in with saved settings.
            reason := IsObject(sample) ? "không đánh và không di chuyển"
                : "không đọc được nhân vật / có thể mất kết nối"
            PortalLogWriteV66("FARM_STAND_TIMEOUT idle_ms=" . (now-w.idleAtV650)
                . " sample=" . (IsObject(sample) ? "LIVE" : "MISSING")
                . " next=STAGE4", "FARM_STAND_TIMEOUT",5000)
            FarmWatchRecoverV5(w,"Đứng " . (w.period/60000) . " phút: " . reason)
        }
    }
    finally
        busy := false
}

; Independent once-per-second backstop for the existing per-target stuck handler.
; Does not interrupt pickup, recover game, or change the configured stuck interval.
FarmWatchCombatStuckV903(w)
{
    ; Independently detect a stalled attack. Do not depend on c.since/c.queued,
    ; which can stay zero when the attack loop is busy.
    ; Only detect here; reuse the existing stuck handler unchanged.
    global autoMonsterAttackOn,monsterChaseV44,chaseCheckSecV9
    global farmPickupPhaseV806,currentAttackPidV550,currentAttackUidV520,currentAttackAtV520
    global monsterCombatUidV45
    if (!IsObject(w))
        return false
    if (!autoMonsterAttackOn || farmPickupPhaseV806 || !w.pid)
    {
        w.combatStallProbeV903 := false
        return false
    }
    ; BC_LOG_FIX: once the B fight is over, the last attack UID stays cached.
    ; Do not report the same stale UID as a combat stall during MOVE C,
    ; ITEM_MOVE or pickup. Real route/item stuck checks still run separately.
    global farmCenterCycleV741
    if (FarmCenterPendingV741(w.pid)
        && farmCenterCycleV741.phase!="ATTACK"
        && farmCenterCycleV741.phase!="ATTACK_FIRST"
        && farmCenterCycleV741.phase!="ATTACK_MORE"
        && farmCenterCycleV741.phase!="ROAD_ATTACK"
        && farmCenterCycleV741.phase!="ITEM_ATTACK")
    {
        w.combatStallProbeV903 := false
        return false
    }
    now := A_TickCount
    uid := currentAttackUidV520, pid := currentAttackPidV550
    ; A selected attack must still be active, not a stale target from an old fight.
    if (!uid || pid!=w.pid || !currentAttackAtV520)
    {
        w.combatStallProbeV903 := false
        return false
    }
    c := monsterChaseV44
    level := (IsObject(c) && c.pid=pid && c.uid=uid) ? c.level : 0
    ; A remote/rapidly changed target can lose monsterChaseV44 before
    ; the backstop fires; use the live Farm cycle level for the UID lock.
    if (!level && FarmCenterPendingV741(pid))
        level := farmCenterCycleV741.level
    hp := (IsObject(c) && c.pid=pid && c.uid=uid) ? c.hp : -1
    probe := w.combatStallProbeV903
    if (!IsObject(probe) || probe.uid!=uid || probe.pid!=pid)
    {
        w.combatStallProbeV903 := {uid:uid,pid:pid,level:level,hp:hp,since:now}
        return false
    }
    if (level)
        probe.level := level
    ; HP decreasing means combat progressed: reset the timeout.
    if (hp>=0 && (probe.hp<0 || hp<probe.hp))
    {
        probe.hp := hp, probe.since := now
        return false
    }
    if (hp>=0)
        probe.hp := hp
    if (now-probe.since<Max(1,chaseCheckSecV9)*1000)
        return false
    ; Timeout reached. Without the real map level a UID lock cannot match
    ; MonsterRetryExcludedV44 and the same monster is targeted again.
    if (!probe.level)
    {
        PortalLogWriteV66("FARM_COMBAT_STUCK_INPUT uid=" . uid
            . " action=WAIT_LEVEL_UNKNOWN", "FARM_COMBAT_STUCK_LEVEL",1000)
        return false
    }
    FarmStuckSkipRememberV1234(uid,-1,-1,pid)
    w.combatStallProbeV903 := false
    MonsterStuckUidSkipV711(uid,probe.level,pid)
    PortalLogWriteV66("FARM_COMBAT_STUCK_INPUT uid=" . uid
        . " level=" . probe.level . " check_sec=" . chaseCheckSecV9
        . " action=SKIP_UID_AND_RESUME")
    FonInfoPushV385("Xét kẹt đánh đủ " . chaseCheckSecV9 . " giây: bỏ qua quái UID " . uid . ", tiếp tục farm.")
    return true
}

FarmWatchRecoverV5(w,reason,confirmedWindowV631 := false)
{
    global farmWatchV5,stageTwoV166,mapWorkflowV185,farmControlOwnerV186,farmRestartReasonV238
    global recoveryGamePathV489,farmStopMoveV124
    ; Re-read actual movement/attacks before starting recovery. A pending
    ; wait/retry must never win over newly observed character activity.
    FarmWatchRefreshActivityV1080(w,recoverySampleV1080)
    now := FarmWatchNowV688()
    if (w.sigPausedV753 || now-w.idleAtV650<w.period)
        return false
    if (w.recoveringV631 || now<w.retryAtV688
        || (IsObject(stageTwoV166) && stageTwoV166.loginRecoveryV489))
        return false
    w.recoveringV631 := true
    w.retryAtV688 := now+5000
    try
    {
        RecoveryLoginSettingsSaveV489()
        if (!FileExist(RecoveryGameExecutableV735(recoveryGamePathV489)))
        {
            FonInfoPushV385(reason . ". Cần đúng đường dẫn Game.exe; bộ đếm vẫn chạy và tự thử lại.")
            return false
        }
        owner := farmControlOwnerV186!="" ? farmControlOwnerV186 : w.owner
        resumeMap := owner!="" && owner!="TEST"
        r := {pid:w.pid,hwnd:w.hwnd,birth:w.birth,phase:"RECOVER",at:A_TickCount
            ,until:A_TickCount+180000,tries:0,continuous:resumeMap,restartRunV17:resumeMap
            ,recoveryOnlyV688:!resumeMap}
        ; Use the up-to-date watchdog state, not a stale SIG wait token.
        FarmWatchRefreshActivityV1080(w,recoverySampleV1080)
        if (w.sigPausedV753 || FarmWatchNowV688()-w.idleAtV650<w.period)
            return false
        farmStopMoveV124 := false
        SetTimer, FarmStopMoveTimerV124, Off
        farmControlOwnerV186 := owner,farmRestartReasonV238 := "STUCK"
        mapWorkflowV185 := resumeMap ? {map:owner,stage:3,startLevel:0,testRows:0} : false
        stageTwoV166 := r
        if (!RecoveryLoginBeginV489(r,"IDLE_TIMEOUT",true))
        {
            if (stageTwoV166=r)
                stageTwoV166 := false
            return false
        }
        w.retryAtV688 := now+w.period
        FonInfoPushV385(reason . ". Đang phục hồi game.")
        SetTimer, StageTwoTimerV166, 250
        return true
    }
    finally
        w.recoveringV631 := false
}

FarmMainFlowV8(r,ctx,player,level,px,py,finishMap := true,key := "",points := false,ByRef pathBuffer := false)
{
    global scosEntryV162
    if (scosEntryV162!=r)
        return false
    if (!finishMap)
    {
        ctx.playerV10 := player
        return FarmCommonRouteTickV3(r,ctx,pathBuffer,level,key,points,false,true)
    }
    FarmCommonRouteEndV3(r)
    return MapEntryFirstBuffFinishV248(r,ctx,player,level,px,py,false)
}

FarmNoFightFlowV8(r,ctx,ByRef pb,level,key,points := false,handoff := false)
{
    return FarmCommonRouteTickV3(r,ctx,pb,level,key,points,handoff)
}

FarmSigFlowV8(r)
{
    return MapStage1SigReadyV374(r)
}


FarmGoldFlowV8(r,ctx,player,ByRef pb,px,py)
{
    global scosEntryV162
    if (scosEntryV162!=r)
        return false
    g := r.goldActionV8
    if (!IsObject(g))
        r.goldActionV8 := g := {pid:r.pid,phase:"WP",stashRouteDoneV230:true,entryGoldV315:true}
    state := g.goldStepV229
    message := state="OPEN_WAIT" ? "Cất tiền: đã gửi lệnh mở rương, đang chờ để gửi tiền."
        : state="VERIFY" ? "Cất tiền: đã gửi tiền, đang chờ số dư xác nhận."
        : state="CLOSE" ? "Cất tiền: đã xác nhận tiền vào rương, đang đóng rương."
        : "Cất tiền: đang mở rương ở gần nhân vật."
    FarmGoldInfoV9(g,message)
    return !ScosGoldBeforeWpV229(g,ctx,player,pb,px,py,true)
}


FarmWaypointFlowV8(r,ctx,ByRef pb,level,px,py,wpClass,destination)
{
    global scosEntryV162
    if (scosEntryV162!=r)
        return false
    w := r.wpFlowV8
    if (!IsObject(w))
        r.wpFlowV8 := w := {phase:"OPEN",at:0}
    if (w.phase="SELECT_WAIT")
    {
        if (A_TickCount-w.at<3000)
            return false
        w.phase := "OPEN"
    }
    if (w.phase="OPEN_WAIT")
    {
        if (A_TickCount-w.at<500)
            return false
        if (A_TickCount-w.at>5000)
        {
            w.phase := "OPEN"
            PortalLogWriteV66("WP_TIMEOUT reason=MENU_NOT_OPENED next=RETRY_OPEN")
            return false
        }
        if (!MapStage9V373(ctx,level,{uid:w.uid},"WP",destination))
            return false
        WpCloseAfterSelectV331("SHARED_WP")
        if (scosEntryV162!=r)
            return false
        w.phase := "SELECT_WAIT",w.at := A_TickCount
        return false
    }
    wp := wpClass ? CycObjectV42(ctx.h,pb,wpClass) : TranFindWaypointV358(ctx.h,pb,px,py)
    if (!IsObject(wp))
    {
        if (r.map="CAIN" && level=168)
            return FarmCainGateV14(r,ctx,pb,level,px,py)
        return false
    }
    if ((px-wp.x)**2+(py-wp.y)**2>400)
    {
        distance := Sqrt((px-wp.x)**2+(py-wp.y)**2)
        approach := {x:Round(wp.x+(px-wp.x)*5/distance),y:Round(wp.y+(py-wp.y)*5/distance)}
        FarmNoFightFlowV8(r,ctx,pb,level,"WP_" . wp.uid,[approach])
        return false
    }
    FarmCommonRouteEndV3(r)
    if (MapStage9V373(ctx,level,wp,"WP"))
    {
        w.uid := wp.uid,w.phase := "OPEN_WAIT",w.at := A_TickCount
        FonInfoPushV385("Đã mở WP; đang chọn map " . destination . ".")
    }
    return false
}

FarmGoldInfoV9(r,message)
{
    if (r.infoAtV9 && A_TickCount-r.infoAtV9<3000)
        return
    r.infoTextV9 := message,r.infoAtV9 := A_TickCount
    FonInfoPushV385(message)
}


FarmCommonCombatV10()
{
    global scosEntryV162
    return IsObject(scosEntryV162.commonRouteV3) && scosEntryV162.commonRouteV3.fightOn
}

FarmMapPlanV10(map,level)
{
    if (map="CYC")
    {
        if (level=75 || level=109)
            return {town:true,gold:true,fight:false,wp:level=75 ? 237 : 429,next:137}
        if (level=137)
            return {fight:false,exitClass:194,next:164,kind:"OBJECT"}
        if (level=164)
            return {fight:true,exitClass:60,next:150,kind:"OBJECT"}
        if (level=150)
            return {final:true}
    }
    else if (map="UBU")
    {
        if (level=75)
            return {town:true,gold:true,fight:false,wp:237,next:140}
        if (level=140)
            return {fight:true,exitClass:0,next:147,kind:"HANG"}
        if (level=147)
            return {fight:false,exitClass:0,next:148,kind:"HANG"}
        if (level=148)
            return {final:true}
    }
    else if (map="TRAN")
    {
        if (level=40)
            return {town:true,gold:false,fight:false,wp:0,next:146}
        if (level=146)
            return {final:true}
    }
    else if (map="CAIN")
    {
        if (level=40)
            return {town:true,gold:true,fight:false,wp:0,next:168}
        if (level=168)
            return {town:false,waypoint:true,fight:true,wp:0,next:183}
    }
        else if (map="M3000")
    {
        if (level=75)
            return {town:true,gold:true,fight:false,wp:237,next:140}
        if (level=109)
            return {town:true,gold:true,fight:false,wp:429,next:75}
        if (level=140)
            return {fight:true,exitClass:60,next:141,kind:"PORTAL"}
        if (level=141)
            return {final:true}
    }
    else if (map="VIZ")
    {
        if (level=75)
            return {town:true,gold:true,fight:false,wp:237,next:154}
        if (level=109)
            return {town:true,gold:true,fight:false,wp:429,next:75}
        if (level=154)
            return {final:true, viz:true}
    }
    return false
}

FarmMapAssemblyV10(r,ctx,player,ByRef pb,level,px,py,map)
{
    global scosEntryV162,farmControlOwnerV186,coordSavedV15
    if (scosEntryV162!=r || !level)
        return false
    plan := FarmMapPlanV10(map,level)
    if (!IsObject(plan))
    {
        FonInfoPushV385(map . ": map " . level . " không thuộc lộ trình đã ghép.")
        return false
    }
    farmControlOwnerV186 := map,ctx.entryStateV42 := r
    if (r.assemblyLevelV10!=level)
    {
        FarmCommonRouteEndV3(r)
        r.assemblyLevelV10 := level,r.assemblyStepV10 := plan.town ? "SIG" : "ROUTE"
        r.assemblyRouteV10 := false,r.goldVisitV8 := false,r.wpFlowV8 := false,r.exitFlowV10 := false
        r.phase := plan.town ? "WP" : "COMBAT"
        FonInfoPushV385(map . ": đã vào map " . level . ".")
    }
    r.until := A_TickCount+300000
    
    if (plan.final)
    {
        if (map="VIZ") 
        {
            result := FarmMainFlowV8(r,ctx,player,level,px,py,false,"VIZ_MAP",false,pb)
            if (result == "DONE" && scosEntryV162==r) 
            {
                r.vizRoute := coordSavedV15.Clone()
                FarmCommonRouteEndV3(r)
                r.phase := "SEARCH"
                Stage2FlowConfigureV380("ITEM",1830,7,true)
                MapStageSetV185(2)
                autoMonsterAttackOn := true
                SetTimer, AutoMonsterAttackTimer, Off
                farmPickupBlockedV57 := false,farmPickupAllowedV57 := true
                PickupEnabledSetV71(true,true,false)
                FonInfoPushV385("Viz: lộ trình DONE; tìm boss 1629.")
            }
            return true
        }
        return FarmMainFlowV8(r,ctx,player,level,px,py)
    }
    
    if (r.assemblyStepV10="SIG")
    {
        if (!FarmSigFlowV8(r))
            return false
        r.assemblyStepV10 := "ROUTE"
        return false
    }
    if (r.assemblyStepV10="ROUTE")
    {
        key := map . "_MAP_" . level
        result := plan.fight ? FarmMainFlowV8(r,ctx,player,level,px,py,false,key,false,pb)
            : FarmNoFightFlowV8(r,ctx,pb,level,key)
        if (result!="DONE" || scosEntryV162!=r)
            return false
        r.assemblyRouteV10 := coordSavedV15.Clone()
        FarmCommonRouteEndV3(r)
        r.assemblyStepV10 := "EXIT"
        return false
    }
    if (r.assemblyStepV10="EXIT")
    {
        if (plan.town || plan.waypoint)
            return FarmWaypointFlowV8(r,ctx,pb,level,px,py,plan.wp,plan.next)
        return FarmExitFlowV10(r,ctx,player,pb,level,px,py,plan)
    }
    return false
}

FarmExitFlowV10(r,ctx,player,ByRef pb,level,px,py,plan)
{
    global scosEntryV162
    if (scosEntryV162!=r)
        return false
    e := r.exitFlowV10
    if (!IsObject(e))
        r.exitFlowV10 := e := {at:0,target:false}
    target := e.target
    if (IsObject(target))
        target := plan.kind="HANG" ? UbuExitV62(ctx.h,pb,target.x,target.y,1,target.cls)
            : CycObjectV42(ctx.h,pb,plan.exitClass,target.x,target.y,1)
    if (!IsObject(target))
    {
        points := r.assemblyRouteV10
        last := IsObject(points) && points.Length() ? points[points.Length()] : {x:px,y:py}
        target := plan.kind="HANG" ? UbuExitV62(ctx.h,pb,last.x,last.y,50)
            : CycObjectV42(ctx.h,pb,plan.exitClass,last.x,last.y,50)
        if (!IsObject(target))
            target := plan.kind="HANG" ? UbuExitV62(ctx.h,pb,px,py,100)
                : CycObjectV42(ctx.h,pb,plan.exitClass,px,py,100)
        if (!IsObject(target))
            return false
    }
    e.target := target
    if ((px-target.x)**2+(py-target.y)**2>100)
    {
        key := "EXIT_" . level . "_" . target.uid
        points := [{x:target.x,y:target.y}]
        if (plan.fight)
            FarmMainFlowV8(r,ctx,player,level,px,py,false,key,points,pb)
        else
            FarmNoFightFlowV8(r,ctx,pb,level,key,points)
        return false
    }
    FarmCommonRouteEndV3(r)
    if (e.at && A_TickCount-e.at<1500)
        return false
    if (MapStage9V373(ctx,level,target))
    {
        e.at := A_TickCount
        FonInfoPushV385(r.map . ": đang vào lối sang map " . plan.next . ".")
    }
    return false
}


FarmSharedSigMapV781(map)
{
    return map="SCOS" || map="NAO" || map="CYC" || map="UBU" || map="M3000" || map="LIB"
}

FarmSharedGoldExitReadyV781(r,ctx,ByRef pb,level)
{
    global scosEntryV162
    if (scosEntryV162!=r || !FarmSharedSigMapV781(r.map)
        || !r.entryGoldV315 || r.goldAlongDoneV12 || !FarmReviveTownLevelV295(level))
        return true
    player := ctx.playerV12
    if (!player)
        return false
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    gold := ScosGoldReadV229(ctx.h,player)
    if (!IsObject(gold))
        return false
    if ((!gold.gold || gold.bank>=gold.limit) && !TownStorePendingV628(ctx,player,r))
    {
        r.goldAlongDoneV12 := true
        return true
    }
    ; Keep the FAUT deposit/verification/close sequence. If the saved route
    ; did not pass within five tiles of the chest, go to it before leaving town.
    stash := CycObjectV42(ctx.h,pb,267)
    if (!IsObject(stash))
    {
        if (!r.goldBeforeExitAtV781)
            r.goldBeforeExitAtV781 := A_TickCount
        if (A_TickCount-r.goldBeforeExitAtV781>15000)
            throw Exception("Cất tiền: chưa tìm thấy rương 267 trước khi rời thành")
        return false
    }
    r.goldBeforeExitAtV781 := 0
    distance := Sqrt((px-stash.x)**2+(py-stash.y)**2)
    if (distance>20)
    {
        MapStage1MoveV374(ctx,Round(stash.x+(px-stash.x)*5/distance)
            ,Round(stash.y+(py-stash.y)*5/distance))
        return false
    }
    if (!FarmGoldFlowV8(r,ctx,player,pb,px,py))
        return false
    r.goldAlongDoneV12 := true
    PortalLogWriteV66("FARM_SHARED_GOLD_DONE map=" . r.map . " level=" . level . " next=CONTINUE_ROUTE")
    return true
}

FarmGoldAlongRouteV12(r,ctx,ByRef pb,level)
{
    global scosEntryV162,coordRouteV16,autoMonsterAttackOn
    if (scosEntryV162!=r || !r.entryGoldV315 || r.goldAlongDoneV12 || !FarmReviveTownLevelV295(level))
        return false
    c := r.commonRouteV3
    if (!IsObject(c) || c.fightOn || !IsObject(coordRouteV16))
        return false
    player := ctx.playerV12,px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    if (!player || !px || !py)
        return false
    if (!r.goldAlongBusyV12)
    {
        gold := ScosGoldReadV229(ctx.h,player)
        if (!IsObject(gold))
            return true
        if ((!gold.gold || gold.bank>=gold.limit) && !TownStorePendingV628(ctx,player,r))
        {
            r.goldAlongDoneV12 := true
            return false
        }
        stash := CycObjectV42(ctx.h,pb,267)
        if (!IsObject(stash) || (px-stash.x)**2+(py-stash.y)**2>25)
            return false
        r.goldAlongBusyV12 := true,r.goldActionV8 := false
        autoMonsterAttackOn := false
        MapStage1MoveV374(ctx,px,py)
        FonInfoPushV385("Đang đi qua rương trong tầm cất tiền: cất tại đây rồi đi tiếp.")
        return true
    }
    if (!FarmGoldFlowV8(r,ctx,player,pb,px,py))
        return true
    if (scosEntryV162!=r || r.commonRouteV3!=c)
        return true
    r.goldAlongBusyV12 := false,r.goldAlongDoneV12 := true
    autoMonsterAttackOn := true
    FonInfoPushV385("Đã cất tiền; tiếp tục lộ trình, không quay lại rương.")
    return false
}

PickupMatchingInventoryClearV551(h,player,pid,itemClass,itemData,groundUid,fileIndex := -1)
{
    global pickupStashListV217
    static lastTry := 0,lastUid := 0,lastPid := 0
    inv := D2ReadU32(h,player+0x60),first := inv ? D2ReadU32(h,inv+0x10) : 0
    cursor := inv ? PickupCursorV4(h,inv) : false
    if (!inv || !IsObject(cursor) || cursor.unit)
        return "WAIT"
    if (!first)
        return "CLEAR"
    all := V9SnapshotAllItems({pid:pid,h:h,inv:inv,first:first})
    if (!IsObject(all))
        return "WAIT"
    for uid,item in all
    {
        if (item.cls!=itemClass || item.loc!=0 || item.owner!=inv || !item.data
            || D2ReadU8V18(h,item.data)!=itemData || uid=groundUid)
            continue
        if (fileIndex>=0)
        {
            if (!MonsterBossProbeReadV1(h,item.data+0x28,4,indexBytes))
                return "WAIT"
            if (NumGet(indexBytes,0,"UInt")!=fileIndex)
                continue
        }
        if (lastPid=pid && lastUid=uid && A_TickCount-lastTry<750)
            return "WAIT"
        lastTry := A_TickCount,lastUid := uid,lastPid := pid,item.uid := uid
        result := PickupMoveToCubeV2(h,pid,inv,item)
        if (result="MOVED" && IsObject(pickupStashListV217))
            pickupStashListV217.Delete(uid)
        FonInfoPushV385(result="MOVED" ? "Đã chuyển vật phẩm cần nhặt từ rương vào cube; tiếp tục nhặt vật phẩm dưới đất."
            : "Chưa chuyển được vật phẩm vào cube; giữ bước chuyển, chưa về thành.")
        return result="MOVED" ? "MOVED" : "WAIT"
    }
    return "CLEAR"
}

FarmCainGateV14(r,ctx,ByRef pb,level,px,py)
{
    global scosEntryV162
    if (scosEntryV162!=r)
        return false
    exit := CainFindExitV383(ctx.h,pb,px,py)
    if (!IsObject(exit))
        return false
    if ((px-exit.x)**2+(py-exit.y)**2>100)
    {
        FarmMainFlowV8(r,ctx,ctx.playerV12,level,px,py,false,"CAIN_EXIT_" . exit.uid,[{x:exit.x,y:exit.y}],pb)
        return false
    }
    FarmCommonRouteEndV3(r)
    if (!r.cainGateAtV14 || A_TickCount-r.cainGateAtV14>=1500)
        if (MapStage9V373(ctx,level,exit))
            r.cainGateAtV14 := A_TickCount
    return false
}

FarmTubeMoveV14(h,ByRef pb,s,target)
{
    return CainWallFollowV506(h,pb,s,target.portalV14 ? target : false)
}

CainWallGridV506(h,ByRef pb)
{
    static cacheV506 := {key:"", at:0, g:0}
    room := NumGet(pb,0x1C,"UInt"),px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    cacheKeyV506 := DllCall("GetProcessId","Ptr",h,"UInt") . "|" . room
    if (cacheV506.key=cacheKeyV506 && A_TickCount-cacheV506.at<500 && IsObject(cacheV506.g)
        && px>=cacheV506.g.x && px<cacheV506.g.x+cacheV506.g.n
        && py>=cacheV506.g.y && py<cacheV506.g.y+cacheV506.g.n)
        return cacheV506.g
    radius := 20,n := radius*2+1
    g := {x:px-radius,y:py-radius,n:n,cells:[],known:[],distance:[],nearest:false,maps:0}
    Loop, % n*n
        g.cells.Push(0x27),g.known.Push(false),g.distance.Push(0)
    for _,r1 in MonsterLoadedRoomsV20(h,room)
    {
        coll := D2ReadU32(h,r1+0x20)
        if (!coll || !MonsterBossProbeReadV1(h,coll,0x24,header))
            continue
        ox := NumGet(header,0,"Int"),oy := NumGet(header,4,"Int")
        w := NumGet(header,8,"UInt"),hh := NumGet(header,12,"UInt"),data := NumGet(header,32,"UInt")
        if (!data || w<1 || hh<1 || w>1024 || hh>1024 || w*hh>262144
            || ox<0 || oy<0 || ox>65535 || oy>65535)
            continue
        x1 := Max(g.x,ox),x2 := Min(g.x+n-1,ox+w-1)
        y1 := Max(g.y,oy),y2 := Min(g.y+n-1,oy+hh-1)
        if (x1>x2 || y1>y2 || !MonsterBossProbeReadV1(h,data,w*hh*2,raw))
            continue
        g.maps++
        Loop, % y2-y1+1
        {
            wy := y1+A_Index-1
            Loop, % x2-x1+1
            {
                wx := x1+A_Index-1,i := (wy-g.y)*n+wx-g.x+1
                mask := NumGet(raw,((wy-oy)*w+wx-ox)*2,"UShort")
                g.cells[i] := mask,g.known[i] := true
                g.distance[i] := (mask & 0x21) ? 0 : 99
                d := (wx-px)**2+(wy-py)**2
                if ((mask & 1) && (!IsObject(g.nearest) || d<g.nearest.d))
                    g.nearest := {x:wx,y:wy,d:d}
            }
        }
    }
    center := radius*n+radius+1
    if (!g.maps || !g.known[center] || (g.cells[center] & 0x21))
        return false
    Loop, % n
    {
        yy := A_Index
        Loop, % n
        {
            xx := A_Index,i := (yy-1)*n+xx
            d := g.distance[i]
            if (xx>1)
                d := Min(d,g.distance[i-1]+1)
            if (yy>1)
            {
                d := Min(d,g.distance[i-n]+1)
                if (xx>1)
                    d := Min(d,g.distance[i-n-1]+1)
                if (xx<n)
                    d := Min(d,g.distance[i-n+1]+1)
            }
            g.distance[i] := d
        }
    }
    Loop, % n
    {
        yy := n-A_Index+1
        Loop, % n
        {
            xx := n-A_Index+1,i := (yy-1)*n+xx,d := g.distance[i]
            if (xx<n)
                d := Min(d,g.distance[i+1]+1)
            if (yy<n)
            {
                d := Min(d,g.distance[i+n]+1)
                if (xx>1)
                    d := Min(d,g.distance[i+n-1]+1)
                if (xx<n)
                    d := Min(d,g.distance[i+n+1]+1)
            }
            g.distance[i] := d
        }
    }
    cacheV506 := {key:cacheKeyV506, at:A_TickCount, g:g}
    return g
}

CainWallCellV506(g,x,y)
{
    xx := Round(x)-g.x,yy := Round(y)-g.y
    if (xx<0 || yy<0 || xx>=g.n || yy>=g.n)
        return {known:false,blocked:true,gap:0,wall:false}
    i := yy*g.n+xx+1
    return {known:g.known[i],blocked:!g.known[i] || (g.cells[i] & 0xC21)
        ,gap:g.distance[i],wall:g.known[i] && (g.cells[i] & 0x21)}
}

CainWallLineV506(g,x,y,tx,ty,gap := 1)
{
    steps := Ceil(Max(Abs(tx-x),Abs(ty-y)))
    if (!steps)
        return true
    Loop, % steps
    {
        c := CainWallCellV506(g,x+(tx-x)*A_Index/steps,y+(ty-y)*A_Index/steps)
        if (c.blocked || c.gap<gap)
            return false
    }
    return true
}

CainWallFollowV506(h,ByRef pb,s,portal := false)
{
    global scosEntryV162,chaseCheckSecV9
    if (!CainCaveMapV502(s.level) || !BossSearchActiveV430(s.pid,s.level)
        || !IsObject(scosEntryV162) || scosEntryV162.cainTubeV14!=s)
        return false
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    if (!IsObject(s.wallFollowV506))
        s.wallFollowV506 := {dx:s.forwardXV14,dy:s.forwardYV14,goal:false,visits:{},blocked:{},last:0,side:1,oriented:false,recent:[]}
    f := s.wallFollowV506
    if (IsObject(f.goal))
    {
        if (px!=f.px || py!=f.py)
            f.px := px,f.py := py,f.movedAt := A_TickCount
        if ((px-f.goal.x)**2+(py-f.goal.y)**2<=2)
        {
            f.dx := f.goal.dx,f.dy := f.goal.dy
            f.recent.Push({x:f.goal.fromX,y:f.goal.fromY})
            if (f.recent.Length()>10)
                f.recent.RemoveAt(1)
            f.goal := false
            key := Floor(px/3) . ":" . Floor(py/3)
            f.visits[key] := f.visits[key]+1
        }
        else if (f.sent && A_TickCount-f.movedAt>=Max(0.5,chaseCheckSecV9)*1000)
        {
            f.blocked[f.goal.key] := A_TickCount+5000
            PortalLogWriteV66("CAIN_COLLISION_STUCK xy=" . px . "," . py . " next=REPLAN_WALL tele=OFF","CAIN_COLLISION_STUCK",1000)
            f.goal := false
        }
        else
        {
            if (!f.sent && A_TickCount-f.last>=250)
            {
                f.last := A_TickCount
                if (NativeMovePointV14(s.pid,f.goal.x,f.goal.y,s.level,false,false,true,false,{searchV430:s}))
                    f.sent := true,f.movedAt := A_TickCount
                else
                    PortalLogWriteV66("CAIN_COLLISION_SEND_WAIT xy=" . px . "," . py . " target=" . f.goal.x . "," . f.goal.y,"CAIN_COLLISION_SEND_WAIT",1500)
            }
            return true
        }
    }
    g := CainWallGridV506(h,pb)
    if (!IsObject(g))
    {
        FonInfoPushV385("Cain " . s.level . ": chưa đọc được ô va chạm; chờ dữ liệu phòng.")
        PortalLogWriteV66("CAIN_COLLISION_WAIT level=" . s.level . " xy=" . px . "," . py . " tele=OFF","CAIN_COLLISION_WAIT",2000)
        return false
    }
    center := CainWallCellV506(g,px,py),minGap := Min(2,Max(1,center.gap))
    if (IsObject(portal) && (portal.x-px)*f.dx+(portal.y-py)*f.dy>=0
        && CainWallLineV506(g,px,py,portal.x,portal.y,1))
    {
        dx := portal.x-px,dy := portal.y-py,len := Sqrt(dx*dx+dy*dy)
        best := {x:Round(px+dx*Min(6,len)/len),y:Round(py+dy*Min(6,len)/len),dx:dx/len,dy:dy/len,key:"PORTAL"}
    }
    else
    {
        best := false,bestScore := 1.0e30
        if (!f.oriented && center.gap<=5 && IsObject(g.nearest))
        {
            wx := g.nearest.x-px,wy := g.nearest.y-py,len := Sqrt(wx*wx+wy*wy)
            if (len>0)
            {
                dx := wy/len,dy := -wx/len
                if (dx*f.dx+dy*f.dy<0)
                    dx := -dx,dy := -dy,f.side := -1
                f.dx := dx,f.dy := dy,f.oriented := true,f.started := true
            }
        }
        Loop, 6
        {
            pass := Mod(A_Index-1,3)+1
            minimumForward := A_Index<=3 ? 0.70 : -0.001
            reach := pass=1 ? 5 : 2
            checkGap := pass=3 ? 1 : minGap
            Loop, 16
            {
                angle := (A_Index-1)*0.3926990817,dx := Cos(angle),dy := Sin(angle)
                tx := Round(px+dx*reach),ty := Round(py+dy*reach),key := tx . ":" . ty
                ax := tx-px,ay := ty-py,actualLen := Sqrt(ax*ax+ay*ay)
                if (actualLen<1)
                    continue
                dx := ax/actualLen,dy := ay/actualLen
                forward := dx*f.dx+dy*f.dy
                if (forward<minimumForward)
                    continue
                retraces := false
                for _,old in f.recent
                    if ((tx-old.x)**2+(ty-old.y)**2<=2)
                    {
                        retraces := true
                        break
                    }
                if (retraces)
                    continue
                if ((f.blocked.HasKey(key) && A_TickCount<f.blocked[key])
                    || !CainWallLineV506(g,px,py,tx,ty,checkGap))
                    continue
                c := CainWallCellV506(g,tx,ty),sideGap := 12
                Loop, 11
                {
                    left := CainWallCellV506(g,tx-f.side*dy*A_Index,ty+f.side*dx*A_Index)
                    if (!left.known)
                        break
                    if (left.wall)
                    {
                        sideGap := A_Index
                        break
                    }
                }
                forward := dx*f.dx+dy*f.dy
                visits := f.visits[Floor(tx/3) . ":" . Floor(ty/3)]+0
                if (!f.started)
                    score := (1-forward)*5+c.gap*2+visits*2
                else
                    score := Abs(sideGap-3.5)*2+Abs(c.gap-3.5)+(1-forward)*3+visits*2
                if (score<bestScore)
                    bestScore := score,best := {x:tx,y:ty,dx:dx,dy:dy,key:key}
            }
            if (IsObject(best))
                break
        }
    }
    if (!IsObject(best))
    {
        PortalLogWriteV66("CAIN_COLLISION_NO_STEP level=" . s.level . " xy=" . px . "," . py . " gap=" . center.gap . " tele=OFF","CAIN_COLLISION_NO_STEP",1500)
        return false
    }
    best.fromX := px,best.fromY := py
    f.goal := best,f.px := px,f.py := py,f.movedAt := A_TickCount,f.sent := false,f.last := 0
    PortalLogWriteV66("CAIN_COLLISION_WALL_MOVE level=" . s.level . " from=" . px . "," . py . " target=" . best.x . "," . best.y
        . " gap=" . center.gap . " desired_gap=3-4 maps=" . g.maps . " forward_only=1 wall_side=" . f.side . " tele=OFF","CAIN_COLLISION_WALL_MOVE",1000)
    if (NativeMovePointV14(s.pid,best.x,best.y,s.level,false,false,true,false,{searchV430:s}))
        f.sent := true,f.last := A_TickCount
    return true
}


FarmAttackHoldingV15()
{
    global farmAttackHoldV15,autoMonsterPacketPendingV1
    return IsObject(farmAttackHoldV15) || (IsObject(autoMonsterPacketPendingV1) && autoMonsterPacketPendingV1.holdDownV15)
}

FarmAttackHoldReleaseV15()
{
    global farmAttackHoldV15,autoMonsterPacketPendingV1
    if (IsObject(farmAttackHoldV15) && farmAttackHoldV15.form6V716)
        return Form6ReleaseV716()
    pending := autoMonsterPacketPendingV1
    if (IsObject(pending))
    {
        if (pending.holdDownV15)
            pending.releaseV15 := true
        if (IsObject(farmAttackHoldV15))
            farmAttackHoldV15.releaseV15 := true
        return !pending.holdDownV15 && !pending.holdUpV15 && !IsObject(farmAttackHoldV15)
    }
    held := farmAttackHoldV15
    if (!IsObject(held))
        return true
    held.releaseV15 := true
    if (held.birth="" || BackgroundBirthV63(held.pid)!=held.birth)
    {
        DllCall("VirtualFreeEx","Ptr",held.process,"Ptr",held.remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",held.process)
        farmAttackHoldV15 := false
        return true
    }
    code := "60B9" . NativeLE32V9(held.remote+128) . "C70112000000"
    code .= "C705" . NativeLE32V9(held.base+0x11C2F8) . "00000000"
    code .= "C705" . NativeLE32V9(held.base+0x11C2F4) . "00000000"
    code .= "B8" . NativeLE32V9(held.base+0x18A00) . "FFD06131C0C20400"
    length := StrLen(code)//2
    VarSetCapacity(blob,128,0)
    Loop, %length%
        NumPut("0x" . SubStr(code,(A_Index-1)*2+1,2),blob,A_Index-1,"UChar")
    SetTimer, AutoMonsterPacketCleanupTimerV1, 50
    if (!DllCall("WriteProcessMemory","Ptr",held.process,"Ptr",held.remote,"Ptr",&blob,"UPtr",128,"UPtrP",written) || written!=128)
        return false
    DllCall("FlushInstructionCache","Ptr",held.process,"Ptr",held.remote,"UPtr",length)
    thread := DllCall("CreateRemoteThread","Ptr",held.process,"Ptr",0,"UPtr",0,"Ptr",held.remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
    if (!thread)
        return false
    autoMonsterPacketPendingV1 := {process:held.process,remote:held.remote,thread:thread,uid:held.uid
        ,kind:"RIGHT_UP",holdUpV15:true,setAt:A_TickCount,autoCall:true}
    farmAttackHoldV15 := false
    return false
}

FarmAttackKeepV15()
{
    global farmAttackHoldV15,autoMonsterAttackOn,monsterCombatUidV45
    if (IsObject(farmAttackHoldV15) && farmAttackHoldV15.form6V716)
        return Form6KeepV716(farmAttackHoldV15)
    held := farmAttackHoldV15
    if (!IsObject(held) || held.releaseV15 || !autoMonsterAttackOn || !Stage2FightEnabledV9()
        || !FarmAttackRowFiveV18()
        || monsterCombatUidV45!=held.uid || D2GetActiveGamePidV95()!=held.pid)
        return false
    if (!MonsterBossProbeReadV1(held.process,held.unit,0x14,unit))
        return false
    return NumGet(unit,0,"UInt")=1 && NumGet(unit,12,"UInt")=held.uid
        && NumGet(unit,16,"UInt")!=0 && NumGet(unit,16,"UInt")!=12
}

FarmAttackReleaseWaitV15()
{
    if (FarmAttackHoldReleaseV15())
        return true
    at := A_TickCount
    while (A_TickCount-at<750)
    {
        AutoMonsterPacketCleanupV1()
        if (FarmAttackHoldReleaseV15())
            return true
        Sleep, 10
    }
    return false
}


FarmAttackAimV16(held)
{
    if (held.form6V716)
        return Form6AimNextV716(held)
    hwnd := GameTargetHwndV63()
    WinGet, pid, PID, ahk_id %hwnd%
    if (!hwnd || pid!=held.pid || !MonsterBossProbeReadV1(held.process,held.unit,0x30,unit)
        || NumGet(unit,0,"UInt")!=1 || NumGet(unit,12,"UInt")!=held.uid
        || NumGet(unit,16,"UInt")=0 || NumGet(unit,16,"UInt")=12
        || !MonsterBossProbeReadV1(held.process,NumGet(unit,0x2C,"UInt"),0x20,path))
        return false
    playerPath := D2ReadU32(held.process,held.player+0x2C)
    view := AutoMonsterAttackViewV1(held.process,held.base,hwnd,playerPath)
    point := IsObject(view) ? AutoMonsterAttackPointV1(path,view) : false
    if (!IsObject(point))
        return false
    VarSetCapacity(xy,8,0)
    NumPut(NumGet(path,2,"UShort"),xy,0,"UInt")
    NumPut(NumGet(path,6,"UShort"),xy,4,"UInt")
    if (!DllCall("WriteProcessMemory","Ptr",held.process,"Ptr",held.remote+140,"Ptr",&xy,"UPtr",8,"UPtrP",written) || written!=8)
        return false
    lp := ((Round(point.y)&65535)<<16)|(Round(point.x)&65535)
    aimed := GameTargetMessageV63(hwnd,0x200,2,lp)
    if (aimed && MonsterBossProbeReadV1(held.process,playerPath,0x20,pp))
        AttackInfoRememberV550(pid,NumGet(unit,4,"UInt"),held.uid,NumGet(path,2,"UShort"),NumGet(path,6,"UShort")
            ,NumGet(pp,2,"UShort"),NumGet(pp,6,"UShort"))
    return aimed
}


FarmAttackRowFiveV18()
{
    global FKey1,FKey2,FKey3,FKey4,FKey5
    Loop, 5
    {
        row := A_Index
        if (!QuickBuffHasKey(FKey%row%))
            return false
    }
    return true
}


Form6ModeChangedV716:
Form6ReleaseV716()
GuiControlGet, form6HoldSelectedV716, 1:, Form6HoldV716
form6ModeV716 := form6HoldSelectedV716 ? 2 : 1
Form6RefreshV716()
return

Form6InputChangedV716:
Form6ReadV716()
return

Form6ReadV716()
{
    global form6KeyV716,form6CountV716
    if (ProfileControlExistsV365("Form6KeyInputV716"))
    {
        GuiControlGet, value, 1:, Form6KeyInputV716
        value := NormalizeOptionalKey(value)
        if (value="" || GetKeyVK(value) || GetKeySC(value))
            form6KeyV716 := value
    }
    if (ProfileControlExistsV365("Form6CountInputV716"))
    {
        GuiControlGet, value, 1:, Form6CountInputV716
        if (RegExMatch(value,"^\d+$") && value>=1 && value<=2048)
            form6CountV716 := value+0
    }
}

Form6RefreshV716()
{
    global form6KeyV716,form6CountV716,form6ModeV716
    GuiControl, 1:, Form6KeyInputV716, % MouseKeyDisplayV616(form6KeyV716)
    GuiControl, 1:, Form6CountInputV716, %form6CountV716%
    GuiControl, 1:, Form6ClickV716, % form6ModeV716=1 ? 1 : 0
    GuiControl, 1:, Form6HoldV716, % form6ModeV716=2 ? 1 : 0
}

Form6SaveV716(section)
{
    global form6KeyV716,form6CountV716,form6ModeV716
    Form6ReadV716()
    IniWrite, %form6KeyV716%, % ProfileConfigPathV364(section), %section%, Form6AttackKey
    IniWrite, %form6CountV716%, % ProfileConfigPathV364(section), %section%, Form6TargetCount
    IniWrite, %form6ModeV716%, % ProfileConfigPathV364(section), %section%, Form6AttackMode
}

Form6LoadV716(section)
{
    global form6KeyV716,form6CountV716,form6ModeV716
    Form6ReleaseV716()
    IniRead, form6KeyV716, % ProfileConfigPathV364(section), %section%, Form6AttackKey,
    IniRead, form6CountV716, % ProfileConfigPathV364(section), %section%, Form6TargetCount, 4
    IniRead, form6ModeV716, % ProfileConfigPathV364(section), %section%, Form6AttackMode, 1
    form6KeyV716 := NormalizeOptionalKey(form6KeyV716)
    if (form6KeyV716!="" && !GetKeyVK(form6KeyV716) && !GetKeySC(form6KeyV716))
        form6KeyV716 := ""
    if (!RegExMatch(form6CountV716,"^\d+$") || form6CountV716<1 || form6CountV716>2048)
        form6CountV716 := 4
    if (form6ModeV716!=2)
        form6ModeV716 := 1
    Form6RefreshV716()
}

Form6ReleaseV716()
{
    global farmAttackHoldV15
    held := farmAttackHoldV15
    if (!IsObject(held) || !held.form6V716)
        return true
    held.releaseV15 := true
    if (held.downV716 && BackgroundBirthV63(held.pid)=held.birth && DllCall("IsWindow","Ptr",held.hwnd))
    {
        WinGet, originalPidV716, PID, % "ahk_id " . held.hwnd
        if (originalPidV716=held.pid && !DllCall("PostMessage","Ptr",held.hwnd,"UInt",0x205,"UPtr",0,"Ptr",held.lp))
            return false
    }
    DllCall("CloseHandle","Ptr",held.process)
    farmAttackHoldV15 := false
    return true
}

Form6KeepV716(held)
{
    global autoMonsterAttackOn,form6ModeV716,farmRunEpochV535
    return autoMonsterAttackOn && form6ModeV716=2 && !held.releaseV15 && !held.doneV716
        && Stage2FightEnabledV9() && held.epoch=farmRunEpochV535
        && D2GetActiveGamePidV95()=held.pid && BackgroundBirthV63(held.pid)=held.birth
        && A_TickCount-held.lastAimV716<750
}

Form6PointV716(held,target)
{
    if (!MonsterBossProbeReadV1(held.process,target.unit,0x30,ub)
        || NumGet(ub,0,"UInt")!=1 || NumGet(ub,12,"UInt")!=target.uid
        || NumGet(ub,16,"UInt")=0 || NumGet(ub,16,"UInt")=12
        || MonsterClassExcludedV11(NumGet(ub,4,"UInt"),held.process,target.unit)
        || !MonsterBossProbeReadV1(held.process,NumGet(ub,0x2C,"UInt"),0x20,path))
    {
        AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=TARGET_INVALID uid=" . target.uid)
        return false
    }
    player := D2ReadU32(held.process,held.base+0x11BBFC)
    playerPath := player ? D2ReadU32(held.process,player+0x2C) : 0
    if (!playerPath || !MonsterBossProbeReadV1(held.process,playerPath,0x20,pb))
    {
        AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=PLAYER_PATH_INVALID uid=" . target.uid)
        return false
    }
    if (CoordLevelV14(held.process,NumGet(path,0x1C,"UInt"))!=CoordLevelV14(held.process,NumGet(pb,0x1C,"UInt")))
    {
        AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=TARGET_LEVEL_MISMATCH uid=" . target.uid)
        return false
    }
    if (!FarmFixedAttackValidV626(held.process,player,target.unit,target.uid,held.pid))
    {
        AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=FIXED_CENTER_REJECT uid=" . target.uid)
        return false
    }
    if (!ScosAttackRadiusValidV239(held.process,player,target.unit,target.uid))
    {
        AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=RADIUS_REJECT uid=" . target.uid)
        return false
    }
    if (BOCommonActiveV444(held.pid) && !BOAttackInRadiusV488(held.process,player,target.unit,held.pid))
    {
        AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=BO_RADIUS_REJECT uid=" . target.uid)
        return false
    }
    view := AutoMonsterAttackViewV1(held.process,held.base,held.hwnd,playerPath)
    pointVTrace := IsObject(view) ? AutoMonsterAttackPointV1(path,view) : false
    if (!IsObject(pointVTrace))
        AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=SCREEN_PROJECTION uid=" . target.uid)
    return pointVTrace
}

Form6AimNextV716(held)
{
    global farmCenterCycleV741
    if (IsObject(farmCenterCycleV741) && farmCenterCycleV741.pid=held.pid && farmCenterCycleV741.phase!="ATTACK")
    {
        AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=AIM_CENTER_PHASE uid=" . held.uid . " phase=" . farmCenterCycleV741.phase)
        return false
    }
    if (held.releaseV15 || held.doneV716 || !NativeDispatchReadyV10(true)
        || D2GetActiveGamePidV95()!=held.pid || BackgroundBirthV63(held.pid)!=held.birth)
    {
        AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=AIM_GUARD uid=" . held.uid . " release=" . held.releaseV15 . " done=" . held.doneV716 . " next=" . held.nextV716)
        return false
    }
    while (held.nextV716<=held.rowsV716.Length())
    {
        target := held.rowsV716[held.nextV716]
        point := Form6PointV716(held,target)
        if (!IsObject(point))
        {
            AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=POINT_REJECT uid=" . target.uid . " next=" . held.nextV716)
            held.nextV716++
            continue
        }
        held.lp := ((Round(point.y)&65535)<<16)|(Round(point.x)&65535)
        if (!GameTargetMessageV63(held.hwnd,0x200,held.downV716 ? 2 : 0,held.lp))
        {
            AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=MOUSE_MOVE_MESSAGE uid=" . target.uid)
            return false
        }
        if (!held.downV716)
        {
            held.downV716 := true
            if (!GameTargetMessageV63(held.hwnd,0x204,2,held.lp))
            {
                Form6ReleaseV716()
                AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=RIGHT_DOWN_MESSAGE uid=" . target.uid)
                return false
            }
        }
        held.unit := target.unit,held.uid := target.uid,held.lastAimV716 := A_TickCount
        held.nextV716++,held.doneV716 := held.nextV716>held.rowsV716.Length()
        return true
    }
    held.doneV716 := true
    AutoMonsterAttackLogV2("COMBAT_FORM6_BLOCK reason=NO_VALID_TARGETS uid=" . held.uid)
    Form6ReleaseV716()
    return false
}

Form6AttackV716(pid,unit,uid)
{
    ; V20261029: one live Farm attack dispatch. Avoid the separate held-mouse
    ; screen-projection route, which can reject a valid unit with queued=0.
    ; The Form6 mode selector stays for profile compatibility; automatic Farm
    ; always sends a native right-click on the selected live unit.
    global farmAttackHoldV15,form6KeyV716,form6ModeV716
    if (IsObject(farmAttackHoldV15))
        FarmAttackHoldReleaseV15()
    if (QuickBuffHasKey(form6KeyV716))
    {
        if (!QuickBuffSend(form6KeyV716))
        {
            AutoMonsterAttackLogV2("COMBAT_SEND_BLOCK reason=SKILL_KEY_NOT_SENT uid=" . uid . " key=" . form6KeyV716)
            return false
        }
    }
    else if (!LastAttackSkillV20())
    {
        AutoMonsterAttackLogV2("COMBAT_SEND_BLOCK reason=LAST_SKILL_NOT_SENT uid=" . uid)
        return false
    }
    ; The skill key is posted asynchronously. Let the game thread process it
    ; before NativeRightSkillValidV9 reads the selected right-hand skill.
    Sleep, 90
    if (!NativeDispatchReadyV10(true) || D2GetActiveGamePidV95()!=pid)
    {
        AutoMonsterAttackLogV2("COMBAT_SEND_BLOCK reason=NOT_READY_AFTER_SKILL uid=" . uid)
        return false
    }
    sentV20261029 := NativeMapTestV5(true,{pid:pid,unit:unit,uid:uid})
    if (!sentV20261029)
        AutoMonsterAttackLogV2("COMBAT_SEND_BLOCK reason=NATIVE_UNIT_SEND_FAILED uid=" . uid . " mode=" . form6ModeV716)
    return FarmCombatSendResultV624(pid,unit,uid,sentV20261029)
}

InventoryArrangeButtonV576:
if (sigBusyV147 && sigActiveModeV182="ARRANGE")
{
    sigCancelV147 := true
    return
}
InventoryArrangeRunV576()
return

InventoryArrangeFitsV576(slots,uid,x,y,w,h,width:=15,height:=10)
{
    if (x<0 || y<0 || x+w>width || y+h>height)
        return false
    for id,a in slots
        if (id!=uid && x<a.x+a.w && x+w>a.x && y<a.y+a.h && y+h>a.y)
            return false
    return true
}

InventoryArrangeFreeV576(slots,item,rightUp:=true)
{
    Loop, % 15-item.w+1
    {
        x := rightUp ? 15-item.w-(A_Index-1) : A_Index-1
        Loop, % 10-item.h+1
        {
            y := rightUp ? 10-item.h-(A_Index-1) : A_Index-1
            if (InventoryArrangeFitsV576(slots,item.uid,x,y,item.w,item.h))
                return {x:x,y:y,w:item.w,h:item.h}
        }
    }
    return false
}

InventoryArrangeBeforeV576(a,b)
{
    if (a.group!=b.group)
        return a.group<b.group
    if (a.group=1 && a.level!=b.level)
        return a.level<b.level
    if (a.group=2 && a.orderV581!=b.orderV581)
        return a.orderV581<b.orderV581
    if (a.group!=1 && a.w*a.h!=b.w*b.h)
        return a.w*a.h>b.w*b.h
    if (a.cls!=b.cls)
        return a.cls<b.cls
    return a.uid<b.uid
}

InventoryArrangeBufferV579(ByRef current,targets,ByRef moves)
{
    Loop, 14
    {
        bx := A_Index-1
        Loop, 9
        {
            by := A_Index-1
            if (!InventoryArrangeFitsV576(targets,-579,bx,by,2,2))
                continue
            buffer := {x:bx,y:by,w:2,h:2},trial := current.Clone(),clearing := [],possible := true
            for uid,a in current
            {
                if (!(bx<a.x+a.w && bx+2>a.x && by<a.y+a.h && by+2>a.y))
                    continue
                blocked := trial.Clone(),blocked[-579] := buffer
                temp := InventoryArrangeFreeV576(blocked,{uid:uid,w:a.w,h:a.h},false)
                if (!IsObject(temp))
                {
                    possible := false
                    break
                }
                clearing.Push({uid:uid,x:temp.x,y:temp.y}),trial[uid] := temp
            }
            if (!possible)
                continue
            current := trial
            for _,move in clearing
                moves.Push(move)
            SigLogV147("ARRANGE_BUFFER x=" . bx . " y=" . by . " size=2x2 clearing_moves=" . clearing.Length())
            return buffer
        }
    }
    throw Exception("Sắp xếp: chưa dọn được vùng trống 4 ô (2x2); chưa di chuyển đồ")
}

InventoryArrangeBufferSlotV579(current,item,buffer)
{
    if (item.w>2 || item.h>2)
        return false
    Loop, % 3-item.w
    {
        x := buffer.x+A_Index-1
        Loop, % 3-item.h
        {
            y := buffer.y+A_Index-1
            if (InventoryArrangeFitsV576(current,item.uid,x,y,item.w,item.h))
                return {x:x,y:y,w:item.w,h:item.h}
        }
    }
    return false
}

InventoryArrangePlanV576(items)
{
    targets := {},current := {},moves := [],charmColumnV578 := 14,charmBottomV578 := 10
    for _,a in items
    {
        current[a.uid] := {x:a.x,y:a.y,w:a.w,h:a.h}
        if (!InventoryArrangeFitsV576(targets,a.uid,a.x,a.y,a.w,a.h))
        {
            if (a.x<0 || a.y<0 || a.x+a.w>15 || a.y+a.h>10)
                throw Exception("Sắp xếp: vật nằm ngoài lưới 15 x 10 trong ảnh")
        }
        if (a.group=0)
        {
            if (!InventoryArrangeFitsV576(targets,a.uid,0,0,a.w,a.h))
                throw Exception("Sắp xếp: có nhiều Cube hoặc ô Cube bị trùng")
            targets[a.uid] := {x:0,y:0,w:a.w,h:a.h}
        }
        else
        {
            target := false
            if (a.group=1)
            {
                while (charmColumnV578>=0 && !IsObject(target))
                {
                    yyV578 := charmBottomV578-a.h
                    while (yyV578>=0)
                    {
                        if (InventoryArrangeFitsV576(targets,a.uid,charmColumnV578,yyV578,a.w,a.h))
                        {
                            target := {x:charmColumnV578,y:yyV578,w:a.w,h:a.h}
                            charmBottomV578 := yyV578
                            break
                        }
                        yyV578--
                    }
                    if (!IsObject(target))
                        charmColumnV578--,charmBottomV578 := 10
                }
            }
            else
                target := InventoryArrangeFreeV576(targets,a)
            if (!IsObject(target))
                throw Exception("Sắp xếp: bố cục không đủ ô cho CLASS " . a.cls)
            targets[a.uid] := target
        }
    }
    needsMove := false
    for uid,a in current
        if (a.x!=targets[uid].x || a.y!=targets[uid].y)
            needsMove := true
    if (!needsMove)
        return {targets:targets,moves:moves}
    bufferV579 := InventoryArrangeBufferV579(current,targets,moves),firstV579 := false
    for _,a in items
    {
        now := current[a.uid],dst := targets[a.uid]
        if (a.group!=1 || a.w*a.h>2 || (now.x=dst.x && now.y=dst.y))
            continue
        if (!IsObject(firstV579) || now.x>current[firstV579.uid].x
            || (now.x=current[firstV579.uid].x && now.y+now.h>current[firstV579.uid].y+current[firstV579.uid].h))
            firstV579 := a
    }
    if (IsObject(firstV579))
    {
        temp := InventoryArrangeBufferSlotV579(current,firstV579,bufferV579)
        if (!IsObject(temp))
            throw Exception("Sắp xếp: 4 ô tạm chưa trống cho charm đầu tiên")
        moves.Push({uid:firstV579.uid,x:temp.x,y:temp.y}),current[firstV579.uid] := temp
    }
    buffered := {},limit := items.Length()*6+200
    Loop, %limit%
    {
        remaining := 0,progress := false
        for _,a in items
        {
            now := current[a.uid],dst := targets[a.uid]
            if (now.x=dst.x && now.y=dst.y)
                continue
            remaining++
            if (InventoryArrangeFitsV576(current,a.uid,dst.x,dst.y,a.w,a.h))
            {
                moves.Push({uid:a.uid,x:dst.x,y:dst.y})
                current[a.uid] := dst.Clone(),progress := true
            }
        }
        if (!remaining)
            return {targets:targets,moves:moves}
        if (progress)
        {
            buffered := {}
            continue
        }
        moved := false
        for _,a in items
        {
            now := current[a.uid],dst := targets[a.uid]
            if ((now.x=dst.x && now.y=dst.y) || buffered.HasKey(a.uid))
                continue
            occupied := current.Clone(),occupied.Delete(a.uid)
            occupied[a.uid] := now
            probe := {uid:-1,w:a.w,h:a.h}
            temp := InventoryArrangeBufferSlotV579(occupied,probe,bufferV579)
            if (!IsObject(temp))
            {
                occupied[-579] := bufferV579
                temp := InventoryArrangeFreeV576(occupied,probe,false)
            }
            if (!IsObject(temp))
                continue
            moves.Push({uid:a.uid,x:temp.x,y:temp.y})
            current[a.uid] := temp,buffered[a.uid] := true,moved := true
            break
        }
        if (!moved)
            throw Exception("Sắp xếp: thiếu ô trống tạm để đổi chỗ; chưa di chuyển đồ")
    }
    throw Exception("Sắp xếp: chưa tính được thứ tự đổi chỗ; chưa di chuyển đồ")
}

InventoryArrangeRunV576()
{
    global sigBusyV147,sigCancelV147,sigActiveModeV182,sigBackgroundV179,sigSendingKeyV147
    global pickupImageOn,pickupTimerBusy,xRunning,zRunning,buffSequenceRunningV555,pickupRoundResetV1
    if (sigBusyV147 || pickupTimerBusy || xRunning || zRunning || buffSequenceRunningV555)
    {
        ToolTipInfoV386("Sắp xếp: chờ thao tác buff/nhặt hiện tại xong rồi bấm lại")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    if (!SigBackgroundBindV179())
        return false
    oldBg := sigBackgroundV179,oldPickup := pickupImageOn
    sigBackgroundV179 := true
    if (!GameItemActionBeginV4("Cube","cube",true))
    {
        sigBackgroundV179 := oldBg
        return false
    }
    sigBusyV147 := true,sigCancelV147 := false,sigActiveModeV182 := "ARRANGE"
    PickupEnabledSetV71(false,true,false)
    GuiControl, 1:, InventoryArrangeButtonV576, Dừng Xếp
    ctx := false,success := false,restoreSlot := false,message := "",stepV577 := "OPEN_CONTEXT",readUidV577 := 0,readClassV577 := -1
    try
    {
        ctx := SigOpenContextV149()
        FonInfoPushV385("Sắp xếp: Sort item to cont")
        stepV577 := "SORT_TO_CONTAINER"
        SigSortContainerV191(ctx)
        stepV577 := "SNAPSHOT"
        items := [],before := SigSnapshotV147(ctx)
        orderV581 := {"1920|7":1,"1734|2":2,"1735|2":3,"1736|2":4,"2168|2":5,"2149|2":6,"1733|2":7,"2346|2":8}
        SigLogV147("ARRANGE_SNAPSHOT total=" . before.Count() . " inventory=" . V92Hex(ctx.inv))
        for uid,a in before
        {
            if (a.loc!=0 || a.owner!=ctx.inv || D2ReadU32(ctx.h,a.unit+0x10)!=0)
                continue
            readUidV577 := uid,readClassV577 := a.cls,stepV577 := "ITEM_SIZE"
            size := TicketItemSizeV277(ctx,a.cls)
            a.w := size.w,a.h := size.h,a.group := 4,a.level := 0
            if (a.cls=1204)
                a.group := 0
            else if (orderV581.HasKey(a.cls . "|" . a.q))
                a.group := 2,a.orderV581 := orderV581[a.cls . "|" . a.q]
            else
            {
                if (PickupIsCharmV571(ctx.h,a.cls))
                {
                    stepV577 := "CHARM_LEVEL"
                    a.group := 1,text := HopTextV557(ctx,a,false)
                    if (RegExMatch(text,"im)\bRequired\s+Level\s*:?\s*(\d+)",m))
                        a.level := m1+0
                }
            }
            inserted := false
            for index,b in items
                if (InventoryArrangeBeforeV576(a,b))
                {
                    items.InsertAt(index,a),inserted := true
                    break
                }
            if (!inserted)
                items.Push(a)
            if (Mod(items.Length(),8)=0)
                FonInfoPushV385("Sắp xếp: đọc " . items.Length() . " vật phẩm")
        }
        if (!items.Length())
            SigFailV147("Sắp xếp: không thấy đồ trong rương ngoài")
        stepV577 := "PLAN_LAYOUT"
        SigLogV147("ARRANGE_ITEMS count=" . items.Length() . " cube_target=0,0 grid=15x10")
        plan := InventoryArrangePlanV576(items),expected := {}
        SigLogV147("ARRANGE_PLAN moves=" . plan.moves.Length())
        for _,a in items
            expected[a.uid] := {cls:a.cls,x:a.x,y:a.y,w:a.w,h:a.h}
        for index,move in plan.moves
        {
            stepV577 := "VERIFY_BEFORE_MOVE",readUidV577 := move.uid
            SigCheckV147(ctx)
            all := SigSnapshotV147(ctx)
            for uid,a in all
                if (a.loc=0 && a.owner=ctx.inv && !expected.HasKey(uid))
                    SigFailV147("Sắp xếp: có vật mới trong rương; dừng để tính lại bố cục")
            for uid,a in expected
            {
                live := all[uid]
                if (!IsObject(live) || live.cls!=a.cls || live.loc!=0 || live.owner!=ctx.inv || live.x!=a.x || live.y!=a.y)
                    SigFailV147("Sắp xếp: đồ thay đổi trong lúc chạy; dừng kiểm tra UID " . uid)
            }
            item := all[move.uid],restoreSlot := expected[move.uid].Clone(),restoreSlot.uid := move.uid
            stepV577 := "MOVE_ITEM",readClassV577 := item.cls
            SigLogV147("ARRANGE_MOVE uid=" . move.uid . " class=" . item.cls . " from=" . restoreSlot.x . "," . restoreSlot.y . " to=" . move.x . "," . move.y)
            Ticket130HomeV265(ctx,item,move)
            expected[move.uid].x := move.x,expected[move.uid].y := move.y,restoreSlot := false
            if (Mod(index,5)=0)
                FonInfoPushV385("Sắp xếp: " . index . "/" . plan.moves.Length())
        }
        stepV577 := "VERIFY_FINAL"
        all := SigSnapshotV147(ctx)
        for uid,dst in plan.targets
            if (!IsObject(all[uid]) || all[uid].loc!=0 || all[uid].owner!=ctx.inv || all[uid].x!=dst.x || all[uid].y!=dst.y)
                SigFailV147("Sắp xếp: chưa xác nhận đúng ô UID " . uid)
        SigLogV147("ARRANGE_DONE items=" . items.Length() . " cube_target=0,0 verified=1")
        success := true,message := "Sắp xếp xong: Cube → Charm theo level → các vật theo thứ tự đã chỉ định → đồ khác"
    }
    catch e
    {
        message := e.Message
        SigLogV147("ARRANGE_ERROR step=" . stepV577 . " uid=" . readUidV577 . " class=" . readClassV577 . " reason=" . e.Message . " what=" . e.What . " line=" . e.Line)
        FonInfoPushV385("Sắp xếp dừng ở " . stepV577 . ": " . e.Message)
        if (IsObject(ctx) && IsObject(restoreSlot) && !sigCancelV147)
        {
            try
            {
                cursor := PickupCursorV4(ctx.h,ctx.inv)
                if (IsObject(cursor) && cursor.uid=restoreSlot.uid)
                    Ticket130HomeV265(ctx,cursor,restoreSlot)
            }
            catch restoreError
                message .= " — kiểm tra vật trên chuột UID " . restoreSlot.uid
        }
    }
    finally
    {
        canRestore := !sigCancelV147
        if (IsObject(ctx))
        {
            cursor := PickupCursorV4(ctx.h,ctx.inv)
            canRestore := canRestore && IsObject(cursor) && !cursor.unit
            DllCall("CloseHandle","Ptr",ctx.h)
        }
        sigBusyV147 := false,sigSendingKeyV147 := false,sigActiveModeV182 := ""
        sigBackgroundV179 := oldBg,pickupRoundResetV1 := true
        GameItemActionEndV4("Cube")
        if (canRestore)
            PickupEnabledSetV71(oldPickup,true,false)
        GuiControl, 1:, InventoryArrangeButtonV576, Dừng Sắp
    }
    ToolTipInfoV386(message)
    SetTimer, RemoveToolTip, -6000
    return success
}
TransferStashButtonV630:
if (sigActiveModeV182="TRANSFER")
{
    sigCancelV147 := true
    return
}
if (sigBusyV147)
{
    ToolTipInfoV386("Chuyển Kho: đang có thao tác đồ khác.")
    return
}
TransferStashRunV631()
return

TransferStashRunV631()
{
    global sigBusyV147,sigCancelV147,sigActiveModeV182,sigBackgroundV179,sigSendingKeyV147
    global pickupTimerBusy,pickupRoundResetV1
    if (!SigBackgroundBindV179() || !IsGameActive())
        return false
    if (pickupTimerBusy || !AutoMonsterPacketCleanupV1() || !GameItemActionBeginV4("Cube","cube",true))
    {
        ToolTipInfoV386("Chuyển Kho: chờ thao tác đồ hiện tại xong rồi thử lại.")
        return false
    }
    oldBg := sigBackgroundV179,oldSending := sigSendingKeyV147
    ctx := false,success := false,message := "",held := false
    sigBusyV147 := true,sigCancelV147 := false,sigActiveModeV182 := "TRANSFER",sigBackgroundV179 := true
    GuiControl, 1:, TransferStashButtonV630, Dừng Chuyển
    try
    {
        ctx := SigOpenContextV149(),ctx.transferStashV631 := true
        path := D2ReadU32(ctx.h,ctx.player+0x2C)
        if (!path || !MonsterBossProbeReadV1(ctx.h,path,0x20,pb))
            throw Exception("Chưa đọc được vị trí nhân vật để tìm kho.")
        stash := CycObjectV42(ctx.h,pb,267)
        if (!IsObject(stash))
            throw Exception("Chưa quét thấy kho để chuyển.")
        if ((stash.x-NumGet(pb,2,"UShort"))**2+(stash.y-NumGet(pb,6,"UShort"))**2>400)
            throw Exception("Cần đứng gần kho để chuyển.")
        r := {storeDoneV628:false,storeSourcesV629:{},pid:ctx.pid}
        if (!TownStoreRunV628(r,ctx,ctx.player))
            throw Exception("Chưa chạy xong chuyển kho.")
        success := true
        message := "Đã kiểm tra/cất tiền và chuyển " . (r.storeMovedV631+0) . " món theo danh sách."
    }
    catch e
        message := "Lỗi chuyển kho: " . e.Message
    finally
    {
        if (IsObject(ctx))
        {
            cursor := PickupCursorV4(ctx.h,ctx.inv)
            held := !IsObject(cursor) || cursor.unit
            DllCall("CloseHandle","Ptr",ctx.h)
        }
        sigBusyV147 := false,sigCancelV147 := false,sigActiveModeV182 := ""
        sigBackgroundV179 := oldBg,sigSendingKeyV147 := oldSending,pickupRoundResetV1 := true
        GameItemActionEndV4("Cube")
        if (held)
            PickupEnabledSetV71(false,true,false)
        GuiControl, 1:, TransferStashButtonV630, Chuyển Khố
    }
    ToolTipInfoV386(message)
    return success
}
TownStoreKeyV631(ctx,spec)
{
    global sigSendingKeyV147,sigTownSendingV148
    SigCheckV147(ctx)
    oldSending := sigSendingKeyV147,oldTownSending := sigTownSendingV148
    sigSendingKeyV147 := true,sigTownSendingV148 := true
    try
        return GameTargetKeyV63(spec)
    finally
        sigSendingKeyV147 := oldSending,sigTownSendingV148 := oldTownSending
}

TownStoreNativeWaitV631(ctx)
{
    started := A_TickCount
    while (!AutoMonsterPacketCleanupV1())
    {
        SigCheckV147(ctx)
        if (A_TickCount-started>4000)
            throw Exception("Chuyển Kho: lệnh mở thủ khố chưa hoàn tất.")
        Sleep, 25
    }
}

FarmCrashWatchTimerV631:
if (farmUserPausedV2026)
    return
FarmCrashWatchTickV631()
return

FarmCrashWatchTickV631()
{
    return
}


TownStoreLiveStoredV635(ctx,item)
{
    SigCheckV147(ctx)
    cursor := PickupCursorV4(ctx.h,ctx.inv)
    if (!IsObject(cursor) || cursor.unit)
        return false
    all := SigSnapshotV147(ctx),live := all[item.uid]
    if (!IsObject(live))
        live := SigLiveItemV148(ctx,item.uid,item.unit)
    return IsObject(live) && live.uid=item.uid && live.cls=item.cls && live.q=item.q
        && live.loc=4 && D2ReadU32(ctx.h,live.unit+0x10)=0
}

TownStoreUiReadV676(ctx)
{
    SigCheckV147(ctx)
    base := D2GetModuleBaseV35(ctx.pid,"D2Client.dll")
    if (!base || !RecoveryMenuModuleV528(ctx.h,base,0x4B95CA3E,0x135000)
        || !MonsterBossProbeReadV1(ctx.h,base+0xBE424,8,code))
        throw Exception("Chuyển Kho: chưa đọc được hàm trạng thái UI; chưa xác nhận đóng kho")
    if (NumGet(code,0,"UChar")!=0x8B || NumGet(code,1,"UChar")!=0x04
        || NumGet(code,2,"UChar")!=0x85 || NumGet(code,7,"UChar")!=0xC3)
        throw Exception("Chuyển Kho: hàm trạng thái UI khác bản hỗ trợ; chưa xác nhận đóng kho")
    table := NumGet(code,3,"UInt")
    if (table<base || table+0x98>base+0x135000
        || !MonsterBossProbeReadV1(ctx.h,table,0x98,flags))
        throw Exception("Chuyển Kho: không đọc được trạng thái kho/Cube")
    stash := NumGet(flags,0x19*4,"UInt"),cube := NumGet(flags,0x1A*4,"UInt")
    menu := NumGet(flags,0x09*4,"UInt")
    if (stash>1 || cube>1 || menu>1)
        throw Exception("Chuyển Kho: trạng thái UI không hợp lệ; chưa xác nhận đóng kho")
    return {stash:stash,cube:cube,menu:menu}
}

TownStoreCloseBatchV636(r,ctx)
{
    global sigCubeUiOpenV159,cubeTransferDelayMs
    r.storeUiClosedV633 := false
    started := A_TickCount,lastSend := 0,stable := 0,sends := 0
    Loop
    {
        ui := TownStoreUiReadV676(ctx)
        if (ui.menu)
            throw Exception("Chuyển Kho: menu game đang mở; chưa cho chạy bước tiếp theo")
        if (!ui.stash && !ui.cube)
        {
            stable++
            if (stable>=2)
            {
                ctx.townStoreStashOpenV631 := false,sigCubeUiOpenV159 := false
                r.storeUiClosedV633 := true
                SigLogV147("TOWN_STORE_UI_CLOSED verified=LIVE_UI stash=0 cube=0 menu=0 esc_count=" . sends)
                return true
            }
        }
        else
        {
            stable := 0
            if (sends<3 && (!lastSend || A_TickCount-lastSend>=1000))
            {
                cursor := PickupCursorV4(ctx.h,ctx.inv)
                if (!IsObject(cursor) || cursor.unit)
                    throw Exception("Chuyển Kho: chuột chưa trống; chưa gửi lệnh đóng kho")
                if (!TownStoreKeyV631(ctx,"{Esc}"))
                    throw Exception("Chuyển Kho: chưa gửi được lệnh đóng kho/Cube")
                sends++,lastSend := A_TickCount
                SigLogV147("TOWN_STORE_UI_CLOSE_SENT stash=" . ui.stash . " cube=" . ui.cube . " attempt=" . sends . " next=VERIFY_LIVE_UI")
            }
        }
        if (A_TickCount-started>=4000)
            throw Exception("Chuyển Kho: kho/Cube chưa đóng; chưa cho di chuyển hoặc mở cổng")
        Sleep, % Max(50,Min(200,cubeTransferDelayMs))
    }
}
