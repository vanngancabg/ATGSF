Lab6TicketTickV318(r,ctx,player)
{
    global scosEntryV162,sigBusyV147,sigBackgroundV179,sigActiveModeV182
    global pickupTimerBusy,xRunning,zRunning,sigCubeUiOpenV159
    labCaption := "LAB" . r.labNumberV314
    if (scosEntryV162!=r || sigBusyV147 || pickupTimerBusy || xRunning || zRunning)
        return false
    if (r.lab6StepV318="PICKUP_GROUND")
    {
        pickupStarted := A_TickCount
        try
        {
            if (!TicketPickupFinishV279(r.pid,RoomRecordLevelV259(r.pid)) || scosEntryV162!=r)
                return false
            PickupEnabledSetV71(false,true,false)
            r.lab6TicketDoneV318 := true,r.lab6StepV318 := "DONE"
            SigLogV147(labCaption . "_TICKET_DONE class=" . r.ticketClassV324 . " quality=02 uid=" . r.lab6TicketUidV318 . " ground=VERIFIED next=END_TICKET_BATCH")
            return true
        }
        finally
            r.until += A_TickCount-pickupStarted
    }
    if (!GameItemActionBeginV4("Cube","cube",true))
        return false
    oldBackground := sigBackgroundV179,oldMode := sigActiveModeV182
    sigBusyV147 := true,sigBackgroundV179 := true,sigActiveModeV182 := labCaption . "_TICKET"
    started := A_TickCount
    try
    {
        ctx.player := player,ctx.inv := D2ReadU32(ctx.h,player+0x60)
        ctx.entryStateV42 := r,ctx.ticketPlacementV277 := true,ctx.lab6TicketV320 := true
        if (!IsObject(r.lab6HomesV318))
            r.lab6HomesV318 := {}
        ctx.returnHomesV265 := r.lab6HomesV318
        cube := Lab6RecipeItemV318(ctx,1204,r.lab6CubeUidV319)
        if (IsObject(cube) && cube.loc!=0 && r.lab6StepV318="VERIFY_EMPTY_CUBE")
        {
            SigPickV147(ctx,cube)
            cube := Lab6RecipeItemV318(ctx,1204,r.lab6CubeUidV319)
        }
        if (!IsObject(cube) || cube.loc!=0)
            throw Exception(labCaption . ": không thấy cube 1204/02 trong rương")
        ctx.cubeUid := cube.uid
        if (r.lab6StepV318="")
            r.lab6StepV318 := "EMPTY_CUBE"
        step := r.lab6StepV318
        SigLogV147(labCaption . "_TICKET_STEP step=" . step)
        if (step="EMPTY_CUBE")
        {
            inside := SigCubeItemsV147(ctx)
            r.lab6CubeUidV319 := cube.uid,r.lab6StepV318 := "VERIFY_EMPTY_CUBE"
            TicketCubeClearV278(ctx,cube,inside)
            return false
        }
        if (step="VERIFY_EMPTY_CUBE")
        {
            if (SigCubeItemsV147(ctx).Length())
                throw Exception(labCaption . ": cube chưa trống sau khi thả và nhặt lại; chưa tạo vé")
            cluster := Lab6RecipeItemV318(ctx,1733)
            if (!IsObject(cluster))
                throw Exception(labCaption . ": không thấy Cluster 1733/02 trong rương hoặc cube")
            if (cluster.loc!=0)
            {
                SigPickV147(ctx,cluster)
                cluster := Lab6RecipeItemV318(ctx,1733,cluster.uid)
            }
            r.lab6ClusterUidV318 := cluster.uid
            Ticket130ReserveV265(ctx,cluster)
            r.lab6StepV318 := "CLUSTER_TO_AC"
            return false
        }
        if (step="CLUSTER_TO_AC")
        {
            cluster := Lab6RecipeItemV318(ctx,1733,r.lab6ClusterUidV318)
            if (!IsObject(cluster))
                throw Exception(labCaption . ": chưa tìm thấy Cluster đã chọn")
            if (cluster.loc!=3)
                SigToCubeV147(ctx,cluster,cube)
            inside := SigCubeItemsV147(ctx)
            if (inside.Length()!=1 || inside[1].uid!=cluster.uid)
                throw Exception(labCaption . ": cube phải chỉ có Cluster trước khi cube ra AC")
            r.lab6StepV318 := "WAIT_AC"
            SigTransmuteV147(ctx,[cluster],1,cluster)
            return false
        }
        if (step="WAIT_AC")
        {
            inside := SigCubeItemsV147(ctx)
            cluster := Lab6RecipeItemV318(ctx,1733),ac := Lab6RecipeItemV318(ctx,1732)
            if (inside.Length()!=2 || !IsObject(cluster) || cluster.loc!=3 || !IsObject(ac) || ac.loc!=3)
                throw Exception(labCaption . ": chưa xác nhận Cluster + AC 1732/02; không cube lặp")
            if (cluster.uid!=r.lab6ClusterUidV318 && r.lab6HomesV318.HasKey(r.lab6ClusterUidV318))
                r.lab6HomesV318[cluster.uid] := r.lab6HomesV318[r.lab6ClusterUidV318]
            r.lab6ClusterUidV318 := cluster.uid,r.lab6AcUidV318 := ac.uid
            r.lab6StepV318 := "RETURN_CLUSTER"
            return false
        }
        if (step="RETURN_CLUSTER")
        {
            cluster := Lab6RecipeItemV318(ctx,1733,r.lab6ClusterUidV318)
            if (!IsObject(cluster))
                throw Exception(labCaption . ": chưa tìm thấy Cluster để trả về rương")
            if (cluster.loc!=0)
                SigReturnV147(ctx,cluster)
            cluster := Lab6RecipeItemV318(ctx,1733,r.lab6ClusterUidV318)
            if (!IsObject(cluster) || cluster.loc!=0)
                throw Exception(labCaption . ": chưa xác nhận Cluster về rương")
            r.lab6StepV318 := "AC_AND_STONE"
            return false
        }
        if (step="AC_AND_STONE")
        {
            ac := Lab6RecipeItemV318(ctx,1732,r.lab6AcUidV318)
            if (!IsObject(ac) || ac.loc!=3)
                throw Exception(labCaption . ": chưa thấy AC trong cube sau khi trả Cluster")
            stone := Lab6RecipeItemV318(ctx,r.stoneClassV324)
            if (!IsObject(stone))
                throw Exception(labCaption . ": không thấy Đá " . r.labNumberV314 . " " . r.stoneClassV324 . "/02 trong rương hoặc cube")
            if (stone.loc!=3)
                SigToCubeV147(ctx,stone,cube)
            inside := SigCubeItemsV147(ctx)
            if (inside.Length()!=2)
                throw Exception(labCaption . ": cube phải chỉ có AC và Đá " . r.labNumberV314)
            r.lab6StepV318 := "WAIT_TICKET"
            SigTransmuteV147(ctx,[ac,stone],1)
            return false
        }
        if (step="WAIT_TICKET")
        {
            inside := SigCubeItemsV147(ctx)
            ticket := inside.Length()=1 ? inside[1] : false
            if (!IsObject(ticket) || ticket.cls!=r.ticketClassV324 || ticket.q!=2)
            {
                SigLogV147(labCaption . "_TICKET_WAIT cube=" . SigItemsTextV150(inside))
                throw Exception(labCaption . ": chưa xác nhận vé " . r.ticketClassV324 . "/02; không cube lặp")
            }
            r.lab6TicketUidV318 := ticket.uid,r.lab6StepV318 := "RETURN_TICKET"
            SigLogV147(labCaption . "_TICKET_FOUND uid=" . ticket.uid . " class=2037 quality=02 loc=" . ticket.loc . " next=RETURN_TICKET")
            return false
        }
        if (step="RETURN_TICKET")
        {
            ticket := Lab6RecipeItemV318(ctx,r.ticketClassV324,r.lab6TicketUidV318)
            if (!IsObject(ticket))
                throw Exception(labCaption . ": chưa tìm thấy vé đã tạo")
            if (ticket.loc!=0)
            {
                SigLogV147(labCaption . "_TICKET_RETURN_BEGIN uid=" . ticket.uid . " class=" . ticket.cls . " loc=" . ticket.loc)
                SigReturnV147(ctx,ticket)
            }
            ticket := Lab6RecipeItemV318(ctx,r.ticketClassV324,r.lab6TicketUidV318)
            if (!IsObject(ticket) || ticket.loc!=0)
                throw Exception(labCaption . ": chưa xác nhận vé về rương")
            if (!SigCloseCubeV156())
                throw Exception(labCaption . ": chưa đóng được cube sau khi trả vé; chưa bật nhặt")
            r.lab6StepV318 := "PICKUP_GROUND"
            SigLogV147(labCaption . "_TICKET_RETURNED class=" . r.ticketClassV324 . " quality=02 uid=" . ticket.uid . " location=INVENTORY cube=CLOSED next=PICKUP_GROUND")
            return false
        }
        return r.lab6TicketDoneV318
    }
    finally
    {
        r.until += A_TickCount-started
        try
            SigCloseCubeV156()
        finally
        {
            sigBusyV147 := false,sigBackgroundV179 := oldBackground,sigActiveModeV182 := oldMode
            GameItemActionEndV4("Cube")
        }
    }
}

NaoEntryTickV188(r,ctx,player,ByRef pb,level,px,py)
{
    global scosEntryV162,farmControlOwnerV186,coordSavedV15
    global xRunning, zRunning, gameItemActionOwner, packetWatchArmedV1
    
    if (scosEntryV162!=r || !level)
        return
        
    farmControlOwnerV186 := "NAO",r.until := A_TickCount+120000
    ctx.entryStateV42 := r
    
    targetLevelV312 := NaoFarmLevelV312(level)
    
    if (r.scosLevelV8!=level)
    {
        FarmCommonRouteEndV3(r)
        r.scosLevelV8 := level,r.scosStepV8 := "SIG"
        r.scosTownRouteV8 := false,r.goldVisitV8 := false,r.wpFlowV8 := false
        r.phase := level=109 ? "WP" : "MAP"
        FonInfoPushV385("Faut: đã vào map " . level . ".")
    }
    
    if (level=targetLevelV312)
    {
        FarmMainFlowV8(r,ctx,player,level,px,py)
        return
    }
    
    if (level!=109)
        throw Exception("Farm Faut vào nhầm map " . level)
        
    if (r.scosStepV8="SIG")
    {
        if (!FarmSigFlowV8(r))
            return
        r.scosStepV8 := "ROUTE"
        return
    }
    
    if (r.scosStepV8="ROUTE")
    {
        if (FarmNoFightFlowV8(r,ctx,pb,level,"NAO_MAP1")!="DONE")
            return
        r.scosTownRouteV8 := coordSavedV15.Clone()
        FarmCommonRouteEndV3(r)
        r.scosStepV8 := "WP"
        FonInfoPushV385("Faut map 1: đã hết lộ trình; chuẩn bị mở cổng.")
        return
    }
    
    if (r.scosStepV8="WP")
    {
        if (xRunning || zRunning || gameItemActionOwner!="" || packetWatchArmedV1 || !AutoMonsterPacketCleanupV1())
            return
            
        inv := D2ReadU32(ctx.h,player+0x60)
        cursor := inv ? PickupCursorV4(ctx.h,inv) : false
        if (!IsObject(cursor) || cursor.unit)
            return
            
        if (!r.oldPortals)
        {
            r.oldPortals := NaoPortalsV188(ctx,pb)
            r.shiftX := px, r.shiftY := py
        }

        if (r.phase != "PORTAL_WAIT")
        {
            items := V9SnapshotAllItems({h:ctx.h,inv:inv,first:D2ReadU32(ctx.h,inv+0x10)}),chosen := 0
            for uid,item in items
                if (item.cls=r.entryClassV309 && D2ReadU8V18(ctx.h,item.data)=r.entryQualityV309 && (item.loc=0 || (r.lab1V310 && item.loc=3)) && item.owner=inv && D2ReadU32(ctx.h,item.unit+0x10)!=3)
                {
                    chosen := uid
                    break
                }
            if (!chosen)
                throw Exception("Không thấy món mở cổng " . r.entryClassV309 . "/" . r.entryQualityV309 . " trong túi")
                
            bytes := [0x20],SigDwordV147(bytes,chosen),SigDwordV147(bytes,px),SigDwordV147(bytes,py)
            r.phase := "PORTAL_WAIT",r.openAt := A_TickCount
            SigPacketV147(ctx,bytes)
            PortalLogWriteV66("NAO_OPEN_PORTAL item=" . r.entryClassV309 . "/" . r.entryQualityV309 . " uid=" . chosen . " xy=" . px . "," . py)
            return
        }
        
        if (A_TickCount-r.openAt>15000)
            throw Exception("Không xác nhận được cổng vào map Faut")
        if (A_TickCount-r.openAt<500)
            return
            
        portals := NaoPortalsV188(ctx,pb),target := false,count := 0
        for uid,portal in portals
            if (!r.oldPortals.HasKey(uid) && (portal.x-r.shiftX)**2+(portal.y-r.shiftY)**2<=144)
                target := portal,count++
                
        if (count>1)
            throw Exception("Có nhiều cổng mới gần nhau - dừng để tránh vào nhầm")
        if (!IsObject(target))
        {
            if (!r.scanLogAt || A_TickCount-r.scanLogAt>=1000)
            {
                r.scanLogAt := A_TickCount
                PortalLogWriteV66("NAO_PORTAL_SCAN room=" . V92Hex(NumGet(pb,0x1C,"UInt")) . " portals=" . portals.Count() . " new_near=" . count)
            }
            return
        }
        
        if (!r.portalLogged)
        {
            r.portalLogged := true
            PortalLogWriteV66("NAO_PORTAL_FOUND uid=" . target.uid . " xy=" . target.x . "," . target.y . " distance2=" . ((px-target.x)**2+(py-target.y)**2))
        }
            
        if ((px-target.x)**2+(py-target.y)**2>9)
        {
            ScosEntryMoveV162(ctx,target.x,target.y)
            return
        }
        
        if (r.enterAt && A_TickCount-r.enterAt<1500)
            return
            
        sent := MapStage9V373(ctx,109,target)
        r.enterAt := A_TickCount
        PortalLogWriteV66("NAO_ENTER_PORTAL uid=" . target.uid . " xy=" . target.x . "," . target.y . " expected=LIVE_ENTRY_MAP method=NATIVE queued=" . sent)
        return
    }
}

MapPortalReadyV188(pid,level,mapEntry:=false)
{
    global scosEntryV162,autoMonsterAttackOn,xRunning,zRunning,gameItemActionOwner,packetWatchArmedV1
    if (!mapEntry)
        return SigTownEnterReadyV148(pid,level)
    entryPhaseV43 := IsObject(scosEntryV162)
        && ((scosEntryV162.phase="WP" && (level=109 || level=75 || (MapScrollFarmV269(scosEntryV162.map) && level=103)))
            || (MapScrollFarmV269(scosEntryV162.map) && scosEntryV162.phase="PORTAL_WAIT" && level=103)
            || (scosEntryV162.map="UBU" && scosEntryV162.phase="COMBAT" && (level=140 || level=147))
            || (scosEntryV162.map="M3000" && scosEntryV162.phase="COMBAT" && (level=140 || level=141))
            || (scosEntryV162.map="NAO" && scosEntryV162.phase="PORTAL_WAIT" && level=109)
            || (scosEntryV162.map="CYC" && ((scosEntryV162.phase="WALK" && level=137)
            || (scosEntryV162.phase="PORTAL" && level=164)))
            || (scosEntryV162.map="CAIN" && ((level=40 && (scosEntryV162.phase="WP40" || scosEntryV162.phase="OPEN_WAIT40"))
            || (level=168 && scosEntryV162.phase="PORTAL168")))
        || (scosEntryV162.map="TRAN" && level=40
            && (scosEntryV162.phase="MAP" || scosEntryV162.phase="WP")))

    return entryPhaseV43 && scosEntryV162.pid=pid
        && !autoMonsterAttackOn && !xRunning && !zRunning && !packetWatchArmedV1 && gameItemActionOwner=""
        && BackgroundValidV63() && D2GetActiveGamePidV95()=pid
}

FarmResetWatchChangedV217:
GuiControlGet, rwEnabled,, FarmResetWatchCheckV217
GuiControlGet, rwMinutesV217,, FarmResetWatchMinutesV217
if rwMinutesV217 is not integer
    rwMinutesV217 := 1
if (rwMinutesV217 < 1)
    rwMinutesV217 := 1
if (rwMinutesV217 > 60)
    rwMinutesV217 := 60
farmResetWatchEnabledV217 := rwEnabled ? true : false
farmResetWatchMinutesV217 := rwMinutesV217
FarmWatchSettingsV5()
resetWatchSinceV217 := 0
if (IsObject(coordRouteV16))
    coordRouteV16.standProbeV246 := false
section := ProfileSection(currentProfile)
IniWrite, % farmResetWatchEnabledV217 ? 1 : 0, % ProfileConfigPathV364(section), %section%, FarmBrainResetWatch
IniWrite, %farmResetWatchMinutesV217%, % ProfileConfigPathV364(section), %section%, FarmBrainResetMinutes
return

FarmEntrySettingsSaveV578()
{
    global farmResetWatchEnabledV217,farmResetWatchMinutesV217
    global ConfigFile,currentProfile,farmEntrySigV315,farmEntryGoldV315
    GuiControlGet, rwEnabled,, FarmResetWatchCheckV217
    GuiControlGet, rwMinutes,, FarmResetWatchMinutesV217
    if rwMinutes is not integer
        rwMinutes := 1
    farmResetWatchEnabledV217 := rwEnabled ? true : false
    farmResetWatchMinutesV217 := Max(1,Min(60,rwMinutes))
    FarmWatchSettingsV5()
    section := ProfileSection(currentProfile)
    IniWrite, % farmResetWatchEnabledV217 ? 1 : 0, % ProfileConfigPathV364(section), %section%, FarmBrainResetWatch
    IniWrite, %farmResetWatchMinutesV217%, % ProfileConfigPathV364(section), %section%, FarmBrainResetMinutes
    IniWrite, % farmEntrySigV315 ? 1 : 0, % ProfileConfigPathV364(section), %section%, FarmEntrySig
    IniWrite, % farmEntryGoldV315 ? 1 : 0, % ProfileConfigPathV364(section), %section%, FarmEntryGold
}

SigReserveReagentHomesV192(ctx)
{
    ctx.reagentHomesV192 := {}
    for uid,a in SigSnapshotV147(ctx)
        if ((a.cls=1734 || a.cls=1735) && a.q=2 && a.loc=0 && a.owner=ctx.inv
            && D2ReadU32(ctx.h,a.unit+0x10)=0 && !ctx.reagentHomesV192.HasKey(a.cls))
        {
            ctx.reagentHomesV192[a.cls] := {uid:uid,x:a.x,y:a.y}
            SigLogV147("REAGENT_HOME_RESERVE class=" . a.cls . " uid=" . uid . " xy=" . a.x . "," . a.y)
        }
}

SigRememberReagentHomeV192(ctx,item)
{
    if ((item.cls!=1734 && item.cls!=1735) || item.q!=2)
        return
    all := SigSnapshotV147(ctx)
    if (!all.HasKey(item.uid))
        SigFailV147("Không đọc được ô vật kèm trước khi đưa vào Cube")
    a := all[item.uid]
    if (a.loc!=0 || a.owner!=ctx.inv)
        SigFailV147("Vật kèm chưa ở rương để lưu ô trả về")
    if (!IsObject(ctx.reagentHomesV192))
        ctx.reagentHomesV192 := {}
    ctx.reagentHomesV192[item.cls] := {uid:item.uid,x:a.x,y:a.y}
    SigLogV147("REAGENT_HOME_CAPTURE class=" . item.cls . " uid=" . item.uid . " xy=" . a.x . "," . a.y . " next=LIFT_TO_CUBE")
}

SigReservedHomeCellV192(ctx,x,y)
{
    if (IsObject(ctx.returnHomesV265))
        for _,home in ctx.returnHomesV265
            if (x>=home.x && x<home.x+(home.w ? home.w : 1)
                && y>=home.y && y<home.y+(home.h ? home.h : 1))
                return true
    if (IsObject(ctx.reagentHomesV192))
        for _,home in ctx.reagentHomesV192
            if (home.x=x && home.y=y)
                return true
    return false
}

SigReturnReagentHomeV192(ctx,item,home)
{
    if (home.x<0 || home.x>14 || home.y<0 || home.y>9)
    {
        SigLogV147("REAGENT_RETURN_HOME_INVALID class=" . item.cls . " uid=" . item.uid
            . " xy=" . home.x . "," . home.y . " grid=15x10")
        SigFailV147("Ô trả về của vật kèm không hợp lệ: " . home.x . "," . home.y)
    }
    cursor := PickupCursorV4(ctx.h,ctx.inv)
    if (!IsObject(cursor) || !cursor.unit || cursor.uid!=item.uid)
        SigLiftV147(ctx,item)
    bytes := [0x18],SigDwordV147(bytes,item.uid),SigDwordV147(bytes,home.x),SigDwordV147(bytes,home.y),SigDwordV147(bytes,0)
    SigLogV147("REAGENT_RETURN_HOME_SEND class=" . item.cls . " uid=" . item.uid . " xy=" . home.x . "," . home.y . " other_cells=DISABLED")
    SigPacketV147(ctx,bytes)
    started := A_TickCount
    while (A_TickCount-started<4000)
    {
        all := SigSnapshotV147(ctx)
        if (all.HasKey(item.uid))
        {
            a := all[item.uid]
            cursor := PickupCursorV4(ctx.h,ctx.inv)
            mode := D2ReadU32(ctx.h,a.unit+0x10)
            if (a.loc=0 && a.owner=ctx.inv && a.cls=item.cls && a.q=2
                && mode!=3 && mode!=5 && IsObject(cursor) && !cursor.unit)
            {
                if (a.x!=home.x || a.y!=home.y)
                    SigFailV147("Vật kèm về sai ô đã giữ - dừng Sig")
                SigLogV147("REAGENT_RETURN_HOME_CONFIRMED class=" . item.cls . " uid=" . item.uid . " xy=" . a.x . "," . a.y)
                return true
            }
        }
        Sleep, 50
    }
    SigFailV147("Không trả được vật kèm về ô đã giữ - dừng Sig")
}

MapMoveDistanceGetV51()
{
    global mapMoveDistanceV197, farmMapPauseV52, farmLoadedMapV56,boMoveMinimumV456
    if (!RegExMatch(mapMoveDistanceV197,"^\d+$") || mapMoveDistanceV197<1 || mapMoveDistanceV197>200)
        return 0
    return mapMoveDistanceV197+0
}

BOMoveMinimumChangedV456:
GuiControlGet, boMinimumEditV456,, BOMoveMinimumInputV456
if (RegExMatch(boMinimumEditV456,"^\d+$") && boMinimumEditV456>=1)
{
    boMoveMinimumV456 := Max(5,boMinimumEditV456+0)
    boMinimumSectionV456 := ProfileSection(currentProfile)
    IniWrite, %boMoveMinimumV456%, % ProfileConfigPathV364(boMinimumSectionV456), %boMinimumSectionV456%, BOMoveMinimum
}
return

MapMoveDistanceChangedV197:
GuiControlGet, moveDistanceEditV197,, MapMoveDistanceInputV197
if (RegExMatch(moveDistanceEditV197,"^\d+$") && moveDistanceEditV197>=1 && moveDistanceEditV197<=200)
{
    mapMoveDistanceV197 := moveDistanceEditV197+0
    moveDistanceSectionV197 := ProfileSection(currentProfile)
    IniWrite, %mapMoveDistanceV197%, % ProfileConfigPathV364(moveDistanceSectionV197), %moveDistanceSectionV197%, MapMoveDistance
}
return


FarmGameInputReadyV532(pid)
{
    hwnd := GameTargetHwndV63()
    if (!pid || !hwnd)
        return false
    WinGet, targetPid, PID, ahk_id %hwnd%
    if (targetPid!=pid)
        return false
    VarSetCapacity(rect,16,0)
    if (!DllCall("GetClientRect","Ptr",hwnd,"Ptr",&rect))
        return false
    w := NumGet(rect,8,"Int"),height := NumGet(rect,12,"Int")
    if (w<320 || height<240)
        return false
    x := Floor(w/2),y := Floor(height/2)
    sent := GameTargetMessageV63(hwnd,0x200,0,(y<<16)|(x & 65535))
    PortalLogWriteV66("FARM_GAME_INPUT_INIT pid=" . pid . " hwnd=" . V92Hex(hwnd)
        . " client_xy=" . x . "," . y . " queued=" . sent . " physical_cursor_moved=0 clicks=0")
    return sent
}

FarmMapAltTickV199(h,player,ByRef pb,pid,newGameV532 := false)
{
    global townLevelV22,zRunning,xRunning,gameItemActionOwner,packetWatchArmedV1,farmShowItemsPendingV165
    static state := false
    mode := player ? D2ReadU32(h,player+0x10) : 0
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    if (!pid || !level || mode=0 || mode=17)
        return false
    if (!IsObject(state) || state.pid!=pid)
        state := {pid:pid,level:0,pending:true,gameName:"",checked:0}
    if (farmShowItemsPendingV165)
        state.checked := 0
    if (newGameV532)
        state.inputReadyV532 := false
    if (!state.checked || A_TickCount-state.checked>=1000)
    {
        state.checked := A_TickCount
        gameNameV282 := GameRoomLiveNameV252(pid)
        if (gameNameV282!="")
        {
            if (state.gameName!="" && state.gameName!=gameNameV282)
                state.pending := true,state.inputReadyV532 := false
            state.gameName := gameNameV282
        }
    }
    if (state.level!=level)
    {
        state.level := level
        FarmPickupSyncV57(pid,level,mode,true)
    }
    if (farmShowItemsPendingV165)
        state.pending := true
    if (!state.pending)
        return false
    if (zRunning || xRunning || gameItemActionOwner!="" || packetWatchArmedV1
        || !AutoMonsterPacketCleanupV1())
        return true
    if (!state.inputReadyV532)
    {
        if (!FarmGameInputReadyV532(pid))
            return true
        state.inputReadyV532 := true
    }
    if (GameTargetKeyV63("{Alt}"))
    {
        state.pending := false,farmShowItemsPendingV165 := false
        PortalLogWriteV66("FARM_GAME_ENTER_ALT level=" . level . " key=ALT presses=1 foreground_required=0")
    }
    return true
}

RareWarningReadTextV35(file,ByRef raw,createMissing:=false)
{
    raw := "", f := false
    try
    {
        if (!FileExist(file))
            return createMissing ? RareWarningWriteTextV35(file,"") : true
        f := FileOpen(file,"r","UTF-8")
        if (!IsObject(f))
            return false
        raw := f.Read()
        return true
    }
    catch e
        return false
    finally
    {
        if (IsObject(f))
            f.Close()
    }
}

RareWarningWriteTextV35(file,content)
{
    temp := file . ".write.tmp", f := false
    try
    {
        f := FileOpen(temp,"w","UTF-8")
        if (!IsObject(f))
            return false
        written := f.Write(content), f.Close(), f := false
        if (content!="" && !written)
            return false
        if (file=UniquePickupFileV3() && FileExist(file))
        {
            backup := file . ".before-save.bak"
            FileCopy, %file%, %backup%, 1
            if (ErrorLevel)
                return false
        }
        FileMove, %temp%, %file%, 1
        return !ErrorLevel
    }
    catch e
        return false
    finally
    {
        if (IsObject(f))
            f.Close()
    }
}

RareWarningRemoveV35(cls,q,idx,pickupFile:="")
{
    previousCritical := A_IsCritical
    Critical, On
    try
    {
        file := pickupFile!="" ? pickupFile : UniquePickupFileV3()
        if (!RareWarningReadTextV35(file,raw,true))
            return false
        key := RareWarningRuleKeyV29(cls,q,idx), wildcard := RareWarningRuleKeyV29(cls,q,-1)
        content := "", changed := false
        Loop, Parse, raw, `n, `r
        {
            line := A_LoopField
            if (UniqueRuleParseV18(line,rowClass,rowQ,rowIndex,rowTier))
            {
                rowKey := RareWarningRuleKeyV29(rowClass,rowQ,rowIndex)
                if (rowKey=key || rowKey=wildcard)
                {
                    changed := true
                    continue
                }
            }
            if (Trim(line)!="")
                content .= line . "`r`n"
        }
        if (changed && !RareWarningWriteTextV35(file,content))
            return false
        if (pickupFile!="")
        {
            UniquePickupReloadRAMV1()
            return !UniquePickupHasV1(cls,idx)
        }
        RareWarningLoadV1()
        return !UniquePickupHasV1(cls,idx)
    }
    finally
    {
        if (previousCritical)
            Critical, %previousCritical%
        else
            Critical, Off
    }
}

UniquePickupCleanDuplicateV19()
{
    global rareWarningFileErrorV30
    file := UniquePickupFileV3(),rareWarningFileErrorV30 := ""
    if (!FileExist(file))
    {
        initial := PickupCanonicalTextV491("","","","",PickupCanonicalDefaultsV491())
        if (!RareWarningWriteTextV35(file,initial))
        {
            rareWarningFileErrorV30 := "Không tạo được file nhặt"
            return false
        }
    }
    if (!RareWarningReadTextV35(file,raw,false))
    {
        rareWarningFileErrorV30 := "Không đọc được file nhặt; giữ nguyên dữ liệu hiện có"
        return false
    }
    cleaned := PickupExcludeSectionTextV663(raw,"",true)
    if (cleaned!=raw)
    {
        backup := file . ".before-exclude-clean.bak"
        if (!FileExist(backup))
        {
            FileCopy, %file%, %backup%, 0
            if (ErrorLevel)
            {
                rareWarningFileErrorV30 := "Không sao lưu được danh sách trước khi gộp Không Nhặt"
                return false
            }
        }
        if (!RareWarningWriteTextV35(file,cleaned))
        {
            rareWarningFileErrorV30 := "Không cập nhật được mục Không Nhặt; giữ bản sao lưu"
            return false
        }
    }
    return true
}

UniquePickupReloadRAMV1()
{
    global uniquePickupRulesV1,uniquePickupClassesV1,rareWarningFileErrorV30,pickupAutoGroupsV7,pickupOptRulesV12,pickupOptRevisionV12,pickupColorsV14,pickupExactAlertsV14
    previousCritical := A_IsCritical
    Critical, On
    try
    {
        if (!UniquePickupCleanDuplicateV19())
            return 0
        file := UniquePickupFileV3()
        if (!RareWarningReadTextV35(file,raw,true))
        {
            rareWarningFileErrorV30 := "Không đọc được file"
            return 0
        }
        partsV491 := PickupCanonicalParseV491(raw)
        TownStoreLoadV628(partsV491.store)
        if (partsV491.canonical)
        {
            global pickupCanonicalExcludeTextV491
            if (partsV491.exclude!=pickupCanonicalExcludeTextV491)
            {
                if (!RareWarningWriteTextV35(PickupExcludeFileV329(),partsV491.exclude))
                    return 0
                PickupExcludeLoadV329()
                pickupCanonicalExcludeTextV491 := partsV491.exclude
            }
        }
        raw := PickupCanonicalDefaultsV491() . (partsV491.canonical ? partsV491.left . partsV491.add : raw)
        rules := {}, classes := {}, groups := {}, optRules := [], colors := {}, exactAlerts := {}
        Loop, Parse, raw, `n, `r
        {
            cleanLineV14 := PickupColorStripV14(A_LoopField,lineColorV14)
            if (SubStr(Trim(cleanLineV14),1,1)="#" || Trim(cleanLineV14)="")
                continue
            if (PickupShortParseV638(cleanLineV14,shortNameV638,shortClassV638,shortQualityV638))
            {
                exactAlerts[RareWarningRuleKeyV29(shortClassV638,shortQualityV638,-1)] := {color:lineColorV14,label:shortNameV638}
                if (shortQualityV638=7)
                    rules[shortClassV638 . "|-1"] := true,classes[shortClassV638] := true
                continue
            }
            if (PickupOptIsRuleV12(A_LoopField))
            {
                parsed := PickupOptParseV12(A_LoopField,parseError)
                if (IsObject(parsed))
                    optRules.Push(parsed)
                else
                    rareWarningFileErrorV30 := "Luật tên/opt dòng " . A_Index . ": " . parseError
                continue
            }
            group := PickupAutoGroupParseV7(A_LoopField)
            if (group!="")
            {
                groups[group] := true
                if (lineColorV14!="")
                    colors[group] := lineColorV14
                if (SubStr(group,1,5)="NAME:")
                {
                    parsed := PickupOptParseV12(Trim(A_LoopField),parseError)
                    if (IsObject(parsed))
                        optRules.Push(parsed)
                }
                continue
            }
            if (!UniqueRuleParseV18(A_LoopField,cls,q,idx,tier))
                continue
            if (q=7)
            {
                exactAlerts[RareWarningRuleKeyV29(cls,q,idx)] := {color:lineColorV14,label:tier}
                rules[cls . "|" . idx] := true
                classes[cls] := true
            }
        }
        cubeActionsV678 := PickupCubeRulesTextV574(partsV491.cube)
        Loop, Parse, cubeActionsV678, `n, `r
        {
            lineV678 := Trim(A_LoopField)
            if (lineV678="")
                continue
            actionV678 := PickupOptParseV12(lineV678,actionErrorV678)
            if (IsObject(actionV678))
            {
                actionV678.actionOnlyV678 := true
                optRules.Push(actionV678)
            }
            else
                rareWarningFileErrorV30 := "Luật Chuyển Cube: " . actionErrorV678
        }
        uniquePickupRulesV1 := rules, uniquePickupClassesV1 := classes,pickupAutoGroupsV7 := groups,pickupOptRulesV12 := optRules
        pickupColorsV14 := colors,pickupExactAlertsV14 := exactAlerts
        pickupOptRevisionV12++
        return rules.Count()
    }
    finally
    {
        if (previousCritical)
            Critical, %previousCritical%
        else
            Critical, Off
    }
}


UniquePickupHasV1(cls,fileIndex)
{
    global uniquePickupRulesV1
    if (!IsObject(uniquePickupRulesV1))
        UniquePickupReloadRAMV1()
    return uniquePickupRulesV1.HasKey((cls+0) . "|" . (fileIndex+0))
        || uniquePickupRulesV1.HasKey((cls+0) . "|-1")
}

UniquePickupAddV1(cls,fileIndex,tier:="",q:=7)
{
    if (cls<=0 || q!=7)
        return false
    if (UniqueKnownTierV4(tier) && PickupAutoGroupEnabledV7(tier))
        return true
    previousCritical := A_IsCritical
    Critical, On
    try
    {
        UniquePickupReloadRAMV1()
        if (UniquePickupHasV1(cls,fileIndex))
            return false
        file := UniquePickupFileV3()
        if (!RareWarningReadTextV35(file,existing,true))
            return false
        prefix := (existing!="" && SubStr(existing,0)!="`n") ? "`r`n" : ""
        line := prefix . "CLASS=" . (cls+0) . " | FILEINDEX=" . (fileIndex+0) . " | ITEMDATA=" . Format("{:02X}",q+0) . " | TIER=" . tier . "`r`n"
        if (!RareWarningWriteTextV35(file,existing . line))
            return false
        UniquePickupReloadRAMV1()
        return true
    }
    finally
    {
        if (previousCritical)
            Critical, %previousCritical%
        else
            Critical, Off
    }
}

UniquePickupRemoveV1(cls,fileIndex)
{
    return RareWarningRemoveV35(cls,7,fileIndex,UniquePickupFileV3())
}


FarmExtra3000ButtonV297:
farmExtra3000ButtonDispatchV297 := true
try
    Gosub, MapControlButtonV168
finally
    farmExtra3000ButtonDispatchV297 := false
return

FarmUbuButtonV62:
farmUbuButtonDispatchV62 := true
try
    Gosub, MapControlButtonV168
finally
    farmUbuButtonDispatchV62 := false
return

UbuEntryArmV62(hwnd)
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
        if (level!=75 && level!=140 && level!=147 && level!=148)
            return false
        scosEntryV162 := {map:"UBU",pid:pid,until:A_TickCount+300000,phase:"WP",row:1,last:0,pickup:pickupImageOn,lastLevel:0}
        FarmSharedEntryOptionsV781(scosEntryV162)
        PickupEnabledSetV71(false,true,false)
        SetTimer, ScosEntryTimerV162, 250
        FarmPickupSyncV57(0,0,-1,true)
        PortalLogWriteV66("MAP_STAGE1_START map=UBU level=" . level . " route=WP140_CEMETERY147_UBU148")
        ToolTipInfoV386("GĐ1 UBU: WP 140 → 147 → 148 → GĐ2 farm.")
        SetTimer, RemoveToolTip, -4000
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

UbuExitV62(h,ByRef pb,gx,gy,radius:=30,classId:=0)
{
    seen := {},best := false,bestDist := radius*radius
    for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
    {
        u := D2ReadU32(h,room+0x74)
        Loop, 4096
        {
            if (!u || seen.HasKey(u))
                break
            seen[u] := true
            typ := D2ReadU32(h,u),cls := D2ReadU32(h,u+4),uid := D2ReadU32(h,u+0x0C)
            if (typ=5 && uid && (!classId || cls=classId))
            {
                path := D2ReadU32(h,u+0x2C)
                x := path ? D2ReadU32(h,path+0x0C) : 0
                y := path ? D2ReadU32(h,path+0x10) : 0
                dist := (x-gx)**2+(y-gy)**2
                if (path && dist<=bestDist)
                    best := {unit:u,uid:uid,cls:cls,typ:5,x:x,y:y},bestDist := dist
            }
            next := D2ReadU32(h,u+0xE8)
            if (next=u)
                break
            u := next
        }
    }
    return best
}

CainEntryArmV360(hwnd)
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
        if (level!=40 && level!=168)
            return false
        scosEntryV162 := {map:"CAIN",pid:pid,until:A_TickCount+300000,phase:level=40 ? "MOVE40" : "MAP",row:1,last:0
            ,pickup:pickupImageOn,startLevel:40,wpTargetLevel:168}
        scosEntryV162.entryGoldV315 := farmEntryGoldV315
        scosEntryV162.cainPhaseV383 := "WAIT"
        PickupEnabledSetV71(false,true,false)
        SetTimer, ScosEntryTimerV162, 250
        FarmPickupSyncV57(0,0,-1,true)
        PortalLogWriteV66("MAP_STAGE1_START map=CAIN level=40 route=WP156_TO_168_THEN_PORTAL60 flow=LIVE_MAP_ID")
        ToolTipInfoV386("GĐ1 CAIN: WP 156 → 168 → portal 60 → farm.")
        SetTimer, RemoveToolTip, -3000
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}
EnterPortalInteractV363(pid, level, target)
{
    global autoMonsterPacketPendingV1,scosEntryV162
    if (!IsObject(target) || !AutoMonsterPacketCleanupV1())
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
            || (NumGet(pb,2,"UShort")-target.x)**2+(NumGet(pb,6,"UShort")-target.y)**2>400)
            return false
        inv := D2ReadU32(h,player+0x60), cursor := inv ? PickupCursorV4(h,inv) : false
        if (!IsObject(cursor) || cursor.unit)
            return false
        if (D2ReadU32(h,target.unit)!=target.typ
            || D2ReadU32(h,target.unit+0x0C)!=target.uid
            || D2ReadU32(h,target.unit+4)!=target.cls)
            return false
        if (IsObject(scosEntryV162) && scosEntryV162.pid=pid
            && !FarmBeforeFinalEntryV718(scosEntryV162,h,player,level))
            return false
        if (!AutoMonsterPacketCleanupV1())
            return false
        remote := DllCall("VirtualAllocEx","Ptr",h,"Ptr",0,"UPtr",128,"UInt",0x3000,"UInt",0x40,"Ptr")
        if (!remote || remote>0xFFFFFFFF)
            return false
        hex := FarmPortalCodeTownOnlyV68(base,target.uid,level,target.typ)
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
            || D2ReadU32(h,target.unit)!=target.typ
            || D2ReadU32(h,target.unit+0x0C)!=target.uid
            || D2ReadU32(h,target.unit+4)!=target.cls)
            return false
        recordEntryV725 := IsObject(scosEntryV162) && target.typ=2 && (target.cls=59 || target.cls=60)
        if (recordEntryV725 && !FarmPortalRecordV725(pid,h,player,"ENTRY",target))
            return false
        thread := DllCall("CreateRemoteThread","Ptr",h,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
        if (!thread)
            return false
        autoMonsterPacketPendingV1 := {process:h,remote:remote,thread:thread,uid:target.uid,kind:"PORTAL_DLL",portalCall:true,setAt:A_TickCount}
        owned := true
        if (recordEntryV725)
        {
            portalSessionV725 := FarmPortalSessionV725(pid)
            if (IsObject(portalSessionV725.pendingEntry))
                portalSessionV725.pendingEntry.sentAt := A_TickCount
        }
        SetTimer, AutoMonsterPacketCleanupTimerV1, 50
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
ScanExitObjectsV363(h, ByRef pb, px, py, excludeStash := true)
{
    list := []
    seen := {}
    for _,room in MonsterLoadedRoomsV20(h, NumGet(pb,0x1C,"UInt"))
    {
        u := D2ReadU32(h,room+0x74)
        Loop, 4096
        {
            if (!u || seen.HasKey(u))
                break
            seen[u] := true
            typ := D2ReadU32(h,u)
            if (typ=2 || typ=5)
            {
                cls := D2ReadU32(h,u+4)
                uid := D2ReadU32(h,u+0x0C)
                op  := D2ReadU32(h,u+0x2C)
                if (uid && MonsterBossProbeReadV1(h,op,0x18,ob))
                {
                    skip := false
                    if (excludeStash && cls=267)
                        skip := true
                    if (cls=237 || cls=285 || cls=286 || cls=429)
                        skip := true
                    if (!skip)
                    {
                        ox := NumGet(ob,0x0C,"UInt")
                        oy := NumGet(ob,0x10,"UInt")
                        d  := (ox-px)**2 + (oy-py)**2
                        list.Push({unit:u, uid:uid, cls:cls, typ:typ, x:ox, y:oy, d:d})
                    }
                }
            }
            next := D2ReadU32(h,u+0xE8)
            if (next=u)
                break
            u := next
        }
    }
    Loop, % list.Length()
    {
        i := A_Index, nearest := i
        Loop, % list.Length()-i
        {
            j := i+A_Index
            if (list[j].d < list[nearest].d)
                nearest := j
        }
        if (nearest != i)
            swap := list[i], list[i] := list[nearest], list[nearest] := swap
    }
    return list
}

MoveToTargetV363(pid, x, y, level)
{
    global coordGoV59
    if (!BackgroundValidV63() || D2GetActiveGamePidV95()!=pid)
        return false
    goal := {pid:pid,x:x,y:y,level:level,row:0,redirect:true,stop:false,resumeFarm:false}
    coordGoV59 := goal
    try
        return NativeMovePointV14(pid,x,y,level,true,false,true,goal)
    finally
        if (coordGoV59=goal)
            coordGoV59 := false
}

EnterNearestPortalV363()
{
    pid := CoordDisplayGamePidV1()
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
    {
        return
    }
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
        {
            return
        }
        px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        mode := D2ReadU32(h,player+0x10)

        list := ScanExitObjectsV363(h, pb, px, py)
        if (!list.Length())
        {
            return
        }
        txt := ""
        Loop, % Min(5, list.Length())
            txt .= (A_Index=1 ? "" : " | ") . "t" . list[A_Index].typ . "c" . list[A_Index].cls . " d=" . Round(Sqrt(list[A_Index].d))

        best := list[1]
        distance := Sqrt(best.d)
        if (distance > 8)
        {
            DllCall("CloseHandle","Ptr",h)
            h := 0
            sentMove := MoveToTargetV363(pid, best.x, best.y, level)
            return
        }
        if (mode != 1 && mode != 5)
        {
            return
        }
        DllCall("CloseHandle","Ptr",h)
        h := 0
        sent := EnterPortalInteractV363(pid, level, best)
    }
    finally
        if (h)
            DllCall("CloseHandle","Ptr",h)
}
GetPortalCoordsV361()
{
    pid := CoordDisplayGamePidV1()
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
    {
        return
    }
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
        {
            return
        }
        px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))

        list := []
        seen := {}
        for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
        {
            u := D2ReadU32(h,room+0x74)
            Loop, 4096
            {
                if (!u || seen.HasKey(u))
                    break
                seen[u] := true
                typ := D2ReadU32(h,u)
                if (typ=2 || typ=5)
                {
                    cls := D2ReadU32(h,u+4), uid := D2ReadU32(h,u+0x0C)
                    op := D2ReadU32(h,u+0x2C)
                    useIt := (cls=59 || cls=60 || cls=156 || cls=266
                           || cls=194 || cls=288
                           || cls=237 || cls=285 || cls=286 || cls=429)
                    if (useIt && uid && MonsterBossProbeReadV1(h,op,0x18,ob))
                    {
                        ox := NumGet(ob,0x0C,"UInt"), oy := NumGet(ob,0x10,"UInt")
                        d := (ox-px)**2 + (oy-py)**2
                        kind := "PORTAL"
                        if (cls=237 || cls=285 || cls=286 || cls=429)
                            kind := "WP"
                        else if (cls=194 || cls=288)
                            kind := "STAIR"
                        list.Push({uid:uid, cls:cls, typ:typ, x:ox, y:oy, d:d, kind:kind})
                    }
                }
                next := D2ReadU32(h,u+0xE8)
                if (next=u)
                    break
                u := next
            }
        }
        if (!list.Length())
        {
            Clipboard := ""
            return
        }
        Loop, % list.Length()
        {
            i := A_Index, nearest := i
            Loop, % list.Length()-i
            {
                j := i+A_Index
                if (list[j].d < list[nearest].d)
                    nearest := j
            }
            if (nearest != i)
                swap := list[i], list[i] := list[nearest], list[nearest] := swap
        }
        txt := ""
        Loop, % Min(4, list.Length())
        {
            it := list[A_Index]
            txt .= (A_Index=1 ? "" : " | ") . it.kind . " c" . it.cls . " " . it.x . "," . it.y . " d=" . Round(Sqrt(it.d))
        }
        Clipboard := list[1].x . "," . list[1].y
    }
    finally
        if (h)
            DllCall("CloseHandle","Ptr",h)
}


CainEntryTickV360(r,ctx,player,ByRef pb,level,px,py)
{
    global scosEntryV162,cainPauseFarmV361,autoMonsterAttackOn
    global xRunning,zRunning,gameItemActionOwner,packetWatchArmedV1
    if (scosEntryV162!=r || !level || xRunning || zRunning || gameItemActionOwner!="" || packetWatchArmedV1
        || !AutoMonsterPacketCleanupV1())
        return
    if (r.cainAssemblyLevelV14!=level)
    {
        FarmCommonRouteEndV3(r)
        r.cainAssemblyLevelV14 := level,r.wpFlowV8 := false
        r.cainTubeV14 := false,r.cainCaveV502 := false
        r.cainPhaseV383 := "WAIT",r.cainModeV383 := ""
        cainPauseFarmV361 := false
    }
    r.until := A_TickCount+600000
    if (level=40 || level=168)
    {
        r.cainActiveV368 := level!=40
        return FarmMapAssemblyV10(r,ctx,player,pb,level,px,py,"CAIN")
    }
    r.cainActiveV368 := true
    if (CainCaveMapV502(level))
        return CainCaveTravelTickV502(r,ctx,player,pb,level,px,py)
    if (level=185)
        return CainFlowTickV383(r,ctx,player,pb,level,px,py)
}

Stage2ItemCountV380(h,player,wantClass,wantQual)
{
    inv := player ? D2ReadU32(h,player+0x60) : 0
    if (!inv)
        return -1
    first := D2ReadU32(h,inv+0x10)
    if (!first)
        return -1
    cursor := PickupCursorV4(h,inv)
    if (!IsObject(cursor) || cursor.unit)
        return -1
    all := V9SnapshotAllItems({h:h,inv:inv,first:first})
    if (!IsObject(all))
        return -1
    count := 0
    for uid,item in all
    {
        if (item.cls != wantClass || !item.data)
            continue
        q := D2ReadU8V18(h,item.data)
        if (q = wantQual && (item.loc=3 || (item.loc=0 && item.owner=inv)))
            count++
    }
    return count
}
CainFlowTickV383(r,ctx,player,ByRef pb,level,px,py)
{
    global scosEntryV162,coordRouteV16,coordSavedV15,stage2MapFileV14
    global autoMonsterAttackOn,cainPauseFarmV361,cainPausedV10
    global xRunning,zRunning,gameItemActionOwner,packetWatchArmedV1,chaseCheckSecV9
    if (scosEntryV162!=r || cainPausedV10 || !level)
        return
    r.cainLevelV19 := level
    if (CainCaveMapV502(level) && r.cainPhaseV383!="WAIT_MAP" && r.cainPhaseV383!="EXIT")
    {
        CainCaveTravelTickV502(r,ctx,player,pb,level,px,py)
        return
    }
    if (level=185 && r.cainModeV383!="ITEM" && r.cainPhaseV383!="WAIT_MAP")
    {
        r.cainPhaseV383 := "WAIT"
        cainPauseFarmV361 := true
    }
    if (r.cainPhaseV383="DONE")
    {
        CainFinalFarmDoneV388(r,ctx.h,player)
        return
    }
    if (r.cainPhaseV383="WAIT" || r.cainPhaseV383="")
    {
        cainPauseFarmV361 := true
        if (!Stage2MapWaitV381(r.pid,level,true))
        {
            PortalLogWriteV66("CAIN_LOAD_WAIT level=" . level
                . " old_route=NOT_ACCEPTED","CAIN_LOAD_WAIT",2000)
            return
        }
        CainModeApplyV16(r,true,true)
        r.cainPhaseV383 := "RUN"
        r.cainExitWaitV383 := 0,r.cainMoveAtV383 := 0,r.cainInteractAtV383 := 0
        r.cainWaitSinceV383 := 0
        autoMonsterAttackOn := true,cainPauseFarmV361 := false
        SetTimer, AutoMonsterAttackTimer, 250
        PortalLogWriteV66("CAIN_NEW_ROUTE level=" . level
            . " yellow=" . FarmStartRowV394() . " rows=" . coordSavedV15.Length()
            . " mode=" . r.cainModeV383 . " source=FRESH_FILE")
        return
    }
    if (r.cainPhaseV383="RUN")
    {
        if (!Stage2MapWaitV381(r.pid,level))
            return
        if (level=185)
        {
            CainFinalFarmDoneV388(r,ctx.h,player)
            return
        }
        if (IsObject(coordRouteV16) && coordRouteV16.pid=r.pid
            && coordRouteV16.startLevel=level && coordRouteV16.phase="DONE")
        {
            r.cainPhaseV383 := "EXIT",cainPauseFarmV361 := true
            r.cainExitWaitV383 := 0,r.cainMoveAtV383 := 0,r.cainInteractAtV383 := 0
            PortalLogWriteV66("CAIN_ROUTE_DONE level=" . level . " next=EXIT")
        }
        return
    }
    if (r.cainPhaseV383="EXIT")
    {
        cainPauseFarmV361 := true
        if (xRunning || zRunning || gameItemActionOwner!="" || packetWatchArmedV1
            || !AutoMonsterPacketCleanupV1())
            return
        portal := CainCaveMapV502(level) ? CainCaveLiveExitV502(r,ctx.h,pb,px,py) : CainFindExitV383(ctx.h,pb,px,py)
        if (!IsObject(portal))
        {
            if (!r.cainExitWaitV383)
                r.cainExitWaitV383 := A_TickCount
            if (A_TickCount-r.cainExitWaitV383>20000)
                throw Exception("CAIN: không tìm thấy cổng thoát map " . level)
            return
        }
        if ((px-portal.x)**2+(py-portal.y)**2>(CainCaveMapV502(level) ? 100 : 1))
        {
            if (CainCaveMapV502(level))
            {
                r.cainPhaseV383 := "CAVE_MOVE",r.cainCaveV502.leg := false
                return
            }
            if (!r.cainMoveAtV383 || A_TickCount-r.cainMoveAtV383>=250)
            {
                ScosEntryMoveV162(ctx,portal.x,portal.y)
                r.cainMoveAtV383 := A_TickCount
            }
            return
        }
        if (CainCaveMapV502(level))
        {
            exitModeV502 := D2ReadU32(ctx.h,player+0x10)
            if (exitModeV502=2 || exitModeV502=3 || exitModeV502=6)
            {
                NativeMovePointV14(r.pid,px,py,level,false,false,true,false,{entry:r,stop:true})
                return
            }
            if (exitModeV502!=1 && exitModeV502!=5)
                return
        }
        if (r.cainInteractAtV383 && A_TickCount-r.cainInteractAtV383<1500)
            return
        target := {unit:portal.unit,uid:portal.uid,cls:portal.cls,typ:portal.typ,x:portal.x,y:portal.y}
        if (!EnterPortalInteractV363(r.pid,level,target))
            return
        room2 := D2ReadU32(ctx.h,NumGet(pb,0x1C,"UInt")+0x10)
        r.cainWaitLevelV383 := level
        r.cainWaitLevelPtrV15 := room2 ? D2ReadU32(ctx.h,room2+0x58) : 0
        r.cainWaitSinceV383 := A_TickCount,r.cainInteractAtV383 := A_TickCount
        r.cainPhaseV383 := "WAIT_MAP"
        PortalLogWriteV66("CAIN_EXIT from_level=" . level . " next=WAIT_MAP")
        return
    }
    if (r.cainPhaseV383="WAIT_MAP")
    {
        cainPauseFarmV361 := true
        room2 := D2ReadU32(ctx.h,NumGet(pb,0x1C,"UInt")+0x10)
        levelPtr := room2 ? D2ReadU32(ctx.h,room2+0x58) : 0
        if (!levelPtr)
            return
        if (level=r.cainWaitLevelV383
            && (!r.cainWaitLevelPtrV15 || levelPtr=r.cainWaitLevelPtrV15))
        {
            if (A_TickCount-r.cainWaitSinceV383>Max(3,chaseCheckSecV9)*1000)
            {
                r.cainPhaseV383 := "EXIT"
                r.cainInteractAtV383 := 0,r.cainMoveAtV383 := 0,r.cainExitWaitV383 := 0
            }
            return
        }
        CoordRouteResetV16()
        stage2MapFileV14 := false
        r.cainPhaseV383 := "WAIT",r.cainCaveV502 := false
        r.cainMoveAtV383 := 0,r.cainInteractAtV383 := 0,r.cainExitWaitV383 := 0
        r.until := A_TickCount+600000
        PortalLogWriteV66("CAIN_MAP_CHANGED from=" . r.cainWaitLevelV383 . " to=" . level
            . " next=FRESH_FILE_FROM_YELLOW")
    }
}

CainCaveMapV502(level)
{
    return level=183 || level=184
}

CainCaveMoveActiveV502()
{
    global scosEntryV162,farmControlOwnerV186
    return farmControlOwnerV186="CAIN" && IsObject(scosEntryV162) && scosEntryV162.map="CAIN"
        && CainCaveMapV502(FarmCurrentLevelV143())
}

CainCaveLiveModeV506(pid,level)
{
    global scosEntryV162,farmControlOwnerV186
    return CainCaveMapV502(level) && IsObject(scosEntryV162) && scosEntryV162.map="CAIN"
        && scosEntryV162.pid=pid && farmControlOwnerV186="CAIN"
}

CainCaveTileDestinationV506(h,room2,tileNo := -1,wantedDestination := 0)
{
    tile := D2ReadU32(h,room2+0x4C),seen := {}
    Loop, 256
    {
        if (tile<0x10000 || seen.HasKey(tile) || !MonsterBossProbeReadV1(h,tile,0x14,tb))
            break
        seen[tile] := true
        other := NumGet(tb,0,"UInt"),numberPtr := NumGet(tb,0x10,"UInt")
        if (tileNo=-1 || (numberPtr>=0x10000 && D2ReadU32(h,numberPtr)=tileNo))
        {
            lp := other>=0x10000 ? D2ReadU32(h,other+0x58) : 0
            destination := lp ? D2ReadU32(h,lp+0x1D0) : 0
            if (destination>0 && destination<1024 && (!wantedDestination || destination=wantedDestination))
                return destination
        }
        tile := NumGet(tb,4,"UInt")
    }
    return 0
}


CainCaveLiveExitV502(r,h,ByRef pb,px,py)
{
    nav := r.cainCaveV502
    if (IsObject(nav) && nav.wallV513)
        return CainCaveWallExitV513(nav,h,pb,px,py)
    if (!IsObject(nav) || !IsObject(nav.goal))
        return false
    best := false,bestDist := 1.0e30
    for _,exit in ScanExitObjectsV363(h,pb,px,py)
    {
        if (!(exit.typ=5 || exit.cls=266 || exit.cls=60))
            continue
        if (nav.goal.HasKey("typ") && exit.typ!=nav.goal.typ)
            continue
        if (nav.goal.HasKey("cls") && (nav.goal.typ=2 || nav.goal.source="LIVE_PRESET") && exit.cls!=nav.goal.cls)
            continue
        if (exit.typ=5 && nav.goal.room2)
        {
            destinationV506 := CainCaveTileDestinationV506(h,nav.goal.room2,exit.cls)
            expectedV506 := nav.level=183 ? 184 : 185
            if (destinationV506 && destinationV506!=expectedV506)
                continue
        }
        dist := (exit.x-nav.goal.x)**2+(exit.y-nav.goal.y)**2
        matchRadiusV506 := nav.goal.matchRadiusSq ? nav.goal.matchRadiusSq : 400
        if (dist<=matchRadiusV506 && dist<bestDist)
            best := exit,bestDist := dist
    }
    return best
}

CainCaveMapSnapshotV511(pid,level)
{
    base := D2GetModuleBaseV35(pid,"D2Client.dll"),h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        room1 := path ? D2ReadU32(h,path+0x1C) : 0,current := room1 ? D2ReadU32(h,room1+0x10) : 0
        lp := current ? D2ReadU32(h,current+0x58) : 0
        if (!lp || D2ReadU32(h,lp+0x1D0)!=level)
            return false
        expected := D2ReadU32(h,lp+8),address := D2ReadU32(h,lp+0x10)
        seen := {},nodes := {},rects := {},layout := "",failed := 0,started := A_TickCount
        while (address>=0x10000 && !seen.HasKey(address) && seen.Count()<4096)
        {
            if (A_TickCount-started>1500)
                break
            seen[address] := true
            if (!MonsterBossProbeReadV1(h,address,0x60,raw))
            {
                failed++
                break
            }
            next := NumGet(raw,0x24,"UInt")
            node := RoomExploreReadV89(h,address,level,true)
            if (IsObject(node))
            {
                nodes[address] := node
                rects[node.x . "_" . node.y . "_" . node.w . "_" . node.h] := true
            }
            else
                failed++
            address := next
        }
        if (!nodes.HasKey(current))
            return false
        for key,_ in rects
            layout .= key . "`n"
        Sort, layout
        layout := StrReplace(RTrim(layout,"`n"),"`n","|")
        complete := expected>0 && expected<=4096 && nodes.Count()=expected && !failed
        geometry := {level:level,levelPtr:lp,count:rects.Count(),layout:layout,rects:rects,partial:complete ? 0 : 1}
        live := MapLiveIdentityV399(pid,level)
        if (!IsObject(live) || live.levelPtr!=lp)
            return false
        PortalLogWriteV66("CAIN_MAP_GEOMETRY level=" . level . " header_rooms=" . expected
            . " read_rooms=" . nodes.Count() . " complete=" . complete . " failed=" . failed
            ,"CAIN_MAP_GEOMETRY",2000)
        return {pid:pid,level:level,levelPtr:lp,current:current,nodes:nodes,geometry:geometry}
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

CainCaveWallExitV513(nav,h,ByRef pb,px,py)
{
    expected := nav.level=183 ? 184 : 185,best := false,rankBest := 1.0e30
    for _,exit in ScanExitObjectsV363(h,pb,px,py)
    {
        if (!(exit.typ=5 || exit.cls=266 || exit.cls=60 || exit.cls=59))
            continue
        path := D2ReadU32(h,exit.unit+0x2C),room1 := path ? D2ReadU32(h,path+0x1C) : 0
        room2 := room1 ? D2ReadU32(h,room1+0x10) : 0
        if (!room2)
        {
            current := D2ReadU32(h,NumGet(pb,0x1C,"UInt")+0x10)
            node := RoomExploreReadV89(h,current,nav.level,true)
            if (IsObject(node) && exit.x>=node.x && exit.x<node.x+node.w
                && exit.y>=node.y && exit.y<node.y+node.h)
                room2 := current
        }
        destination := exit.typ=5 && room2 ? CainCaveTileDestinationV506(h,room2,exit.cls) : 0
        key := exit.typ . "|" . exit.uid . "|" . exit.cls
        xyKey := exit.typ . "|" . exit.cls . "|" . exit.x . "|" . exit.y
        entryDist := (exit.x-nav.entryX)**2+(exit.y-nav.entryY)**2
        if ((destination && destination!=expected) || (!destination && entryDist<=225))
        {
            nav.entryUIDsV513[key] := true,nav.entryXYV513[xyKey] := true
            continue
        }
        if (nav.entryUIDsV513.HasKey(key) || nav.entryXYV513.HasKey(xyKey))
            continue
        rank := (destination=expected ? 0 : 1000000000)+exit.d
        if (rank<rankBest)
            best := exit,rankBest := rank
    }
    return best
}

CainCaveTravelTickV502(r,ctx,player,ByRef pb,level,px,py)
{
    global scosEntryV162,stage2FlowV380,autoMonsterAttackOn,cainPauseFarmV361
    if (scosEntryV162!=r || !CainCaveMapV502(level))
        return false
    cainPauseFarmV361 := true,autoMonsterAttackOn := false
    SetTimer, AutoMonsterAttackTimer, Off
    if (!IsObject(r.cainTubeV14))
    {
        if (!Stage2FlowConfigureV380("NORMAL",0,-1,false) || !BossSearchBeginV430(r.pid,level))
            return false
        state := stage2FlowV380.searchV430
        state.tubeV14 := true
        room2 := D2ReadU32(ctx.h,NumGet(pb,0x1C,"UInt")+0x10)
        node := RoomExploreReadV89(ctx.h,room2,level,true)
        dx := IsObject(node) ? node.cx-px : 1,dy := IsObject(node) ? node.cy-py : 0
        length := Sqrt(dx*dx+dy*dy)
        state.forwardXV14 := length>=1 ? dx/length : 1
        state.forwardYV14 := length>=1 ? dy/length : 0
        state.zigzagV474 := {dx:1,dy:0,goal:false,leg:0}
        r.cainTubeV14 := state
        r.cainCaveV502 := {level:level,entryX:px,entryY:py,entryUIDsV513:{},entryXYV513:{}}
        CainCaveWallExitV513(r.cainCaveV502,ctx.h,pb,px,py)
        FonInfoPushV385("Cain map " . level . ": bám vách theo hướng tiến, cách 3-4 ô; không đi lùi/tele.")
        return false
    }
    state := r.cainTubeV14
    if (!BossSearchIdentityV430(r.pid,level) || stage2FlowV380.searchV430!=state)
        return false
    portal := CainCaveWallExitV513(r.cainCaveV502,ctx.h,pb,px,py)
    if (IsObject(portal) && A_TickCount>=state.portalPauseV14)
    {
        if ((px-portal.x)**2+(py-portal.y)**2<=100)
        {
            mode := D2ReadU32(ctx.h,player+0x10)
            if (mode!=1 && mode!=5)
            {
                NativeMovePointV14(r.pid,px,py,level,false,false,true,false,{entry:r,stop:true})
                return false
            }
            if (!state.portalAtV14 || A_TickCount-state.portalAtV14>=1500)
            {
                if (EnterPortalInteractV363(r.pid,level,portal))
                {
                    state.portalAtV14 := A_TickCount
                    FonInfoPushV385("Cain map " . level . ": đã thấy cổng, đang vào map tiếp theo.")
                }
            }
            return false
        }
        state.phase := "PORTAL"
        goal := {uid:0,cls:portal.cls,room2:"EXIT_" . portal.uid,x:portal.x,y:portal.y
            ,level:level,dist:(px-portal.x)**2+(py-portal.y)**2,portalV14:true}
        return BossSearchMoveV430(ctx.h,pb,state,goal)
    }
    return CainWallFollowV506(ctx.h,pb,state)
}


CainFindExitV383(h,ByRef pb,px,py)
{
    for _,target in ScanExitObjectsV363(h,pb,px,py)
    {
        if (target.typ=5)
            return target
        if (target.cls=266 || target.cls=60 || target.cls=59)
            return target
        if (target.cls=156 || target.cls=429 || target.cls=237)
            return target
    }
    return false
}

TranEntryArmV358(hwnd)
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
        if (level!=40)
            return false
        scosEntryV162 := {map:"TRAN",pid:pid,until:A_TickCount+180000,phase:"MAP",row:1,last:0,pickup:pickupImageOn,startLevel:40}
        scosEntryV162.entryGoldV315 := farmEntryGoldV315
        PickupEnabledSetV71(false,true,false)
        SetTimer, ScosEntryTimerV162, 250
        FarmPickupSyncV57(0,0,-1,true)
        PortalLogWriteV66("MAP_STAGE1_START map=TRAN level=40 route=5_clicks_from_log")
        ToolTipInfoV386("GĐ1 TRAN: di theo 5 điểm trong thành 40.")
        SetTimer, RemoveToolTip, -3000
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

TranEntryTickV358(r,ctx,player,ByRef pb,level,px,py)
{
    return FarmMapAssemblyV10(r,ctx,player,pb,level,px,py,"TRAN")
}

TranFindWaypointV358(h,ByRef pb,px,py)
{
    seen := {},best := false,bestRank := 1.0e30
    for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
    {
        u := D2ReadU32(h,room+0x74)
        Loop, 4096
        {
            if (!u || seen.HasKey(u))
                break
            seen[u] := true
            if (D2ReadU32(h,u)=2)
            {
                cls := D2ReadU32(h,u+4)
                uid := D2ReadU32(h,u+0x0C),path := D2ReadU32(h,u+0x2C)
                mode := D2ReadU32(h,u+0x10)
                if (uid && MonsterBossProbeReadV1(h,path,0x18,ob))
                {
                    x := NumGet(ob,0x0C,"UInt"),y := NumGet(ob,0x10,"UInt")
                    d := (x-px)**2+(y-py)**2
                    isWp := false
                    if ((cls=285 || cls=286) && mode=1)
                        isWp := true
                    else if (cls=156 && mode=2)
                        isWp := true
                    else if (cls=237 || cls=429)
                        isWp := true
                    if (isWp && d<bestRank)
                        best := {unit:u,uid:uid,cls:cls,x:x,y:y},bestRank := d
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


Farm3000EntryArmV297(hwnd)
{
    global scosEntryV162,pickupImageOn,packetWatchArmedV1,backgroundPidV63,farmEntryGoldV315
    if (packetWatchArmedV1 || !BackgroundBindV63(hwnd))
    {
        PortalLogWriteV66("M3000_ARM_FAIL reason=BIND_OR_PACKET_WATCH hwnd=" . hwnd)
        return false
    }
    pid := backgroundPidV63,base := D2GetModuleBaseV35(pid,"D2Client.dll"),h := D2OpenProcess(pid)
    if (!h)
    {
        PortalLogWriteV66("M3000_ARM_FAIL reason=OPEN_PROCESS pid=" . pid)
        return false
    }
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
        {
            PortalLogWriteV66("M3000_ARM_FAIL reason=PLAYER_PATH_READ pid=" . pid)
            return false
        }
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        if (level!=75 && level!=109 && level!=140 && level!=141)
        {
            PortalLogWriteV66("M3000_ARM_FAIL reason=BAD_LEVEL level=" . level . " allowed=75,109,140,141")
            ToolTipInfoV386("GĐ1 3000: cần ở thành 75/109 hoặc map 140/141. Đang ở " . level . ".")
            SetTimer, RemoveToolTip, -4000
            return false
        }
        scosEntryV162 := {map:"M3000",pid:pid,until:A_TickCount+300000,phase:"WP",row:1,last:0,pickup:pickupImageOn,lastLevel:0}
        FarmSharedEntryOptionsV781(scosEntryV162)
        PickupEnabledSetV71(false,true,false)
        SetTimer, ScosEntryTimerV162, 250
        FarmPickupSyncV57(0,0,-1,true)
        PortalLogWriteV66("MAP_STAGE1_START map=M3000 level=" . level . " entry_gold=" . farmEntryGoldV315)
        ToolTipInfoV386("GĐ1 3000: đang chạy (level " . level . ").")
        SetTimer, RemoveToolTip, -3000
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

Farm3000EntryTickV297(r,ctx,player,ByRef pb,level,px,py)
{
    return FarmMapAssemblyV10(r,ctx,player,pb,level,px,py,"M3000")
}


UbuEntryTickV62(r,ctx,player,ByRef pb,level,px,py)
{
    return FarmMapAssemblyV10(r,ctx,player,pb,level,px,py,"UBU")
}

SigGroundDiagnosticV63()
{
    global pickupRadius,sigBusyV147,sigLastStopReasonV63
    pid := D2GetActiveGamePidV95()
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
    {
        DebugTraceWrite("cube","SIG_GROUND_READ_FAIL reason=NO_GAME_MEMORY")
        return
    }
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
        {
            DebugTraceWrite("cube","SIG_GROUND_READ_FAIL reason=NO_PLAYER_PATH")
            return
        }
        room := NumGet(pb,0x1C,"UInt"),level := CoordLevelV14(h,room)
        if (!room || !level)
        {
            DebugTraceWrite("cube","SIG_GROUND_READ_FAIL reason=NO_ROOM_OR_LEVEL")
            return
        }
        px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
        seen := {},nearCount := 0,setCount := 0,uniqueCount := 0,loadedCount := 0
        ctx := {h:h,inv:D2ReadU32(h,player+0x60)}
        DebugTraceWrite("cube","SIG_GROUND_CHECK manual=1 read_only=1 sig_busy=" . sigBusyV147
            . " last_stop=" . sigLastStopReasonV63 . " level=" . level . " player_xy=" . px . "," . py . " pickup_radius=" . pickupRadius)
        for _,r in MonsterLoadedRoomsV20(h,room)
        {
            u := D2ReadU32(h,r+0x74)
            Loop, 4096
            {
                if (!u || seen.HasKey(u))
                    break
                seen[u] := true
                mode := D2ReadU32(h,u+0x10)
                if (D2ReadU32(h,u)=4 && (mode=3 || mode=5))
                {
                    data := D2ReadU32(h,u+0x14),ip := D2ReadU32(h,u+0x2C)
                    if (data && ip)
                    {
                        uid := D2ReadU32(h,u+0x0C),cls := D2ReadU32(h,u+4),q := D2ReadU8V18(h,data)
                        x := D2ReadU32(h,ip+0x0C),y := D2ReadU32(h,ip+0x10)
                        distance := Abs(x-px)+Abs(y-py),loadedCount++
                        inRadius := distance<=Max(4,pickupRadius)
                        if (inRadius)
                        {
                            nearCount++
                            if (q=5)
                                setCount++
                            if (q=7)
                                uniqueCount++
                        }
                        tier := "",wlvl := 0
                        if (q=7)
                            tier := UniqueItemsTierFromLiveTableV1(h,D2ReadU32(h,data+0x28),wlvl)
                        DebugTraceWrite("cube","SIG_GROUND_ITEM uid=" . uid . " class=" . cls . " quality=" . q
                            . " tier=" . tier . " xy=" . x . "," . y . " distance=" . distance . " within_pickup_radius=" . inRadius)
                    }
                }
                next := D2ReadU32(h,u+0xE8)
                if (next=u)
                    break
                u := next
            }
        }
        cursor := ctx.inv ? PickupCursorV4(h,ctx.inv) : false
        DebugTraceWrite("cube","SIG_GROUND_SUMMARY nearby=" . nearCount . " set=" . setCount . " unique=" . uniqueCount
            . " all_loaded_ground=" . loadedCount . " cursor_uid=" . (IsObject(cursor) ? cursor.uid : "READ_FAIL")
            . " scope=LOADED_ROOMS_ONLY")
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}


; V942 - Nhat ky map append-only: tach tung LUOT FARM theo ten.
; Chi ghi khi bat dau/ket thuc, khong ghi theo tick/dong vang doi.
FarmMapJournalPathV940()
{
    return TxtRootPathV816("Farm_LichSuMap.txt")
}

FarmMapJournalLabelV940(owner)
{
    ; Tren giao dien FAUT dung ma dieu khien NAO.
    return owner="NAO" ? "FAUT" : owner
}

FarmMapJournalWriteV940(message)
{
    fileV940 := FarmMapJournalPathV940()
    FileAppend, % message . "`r`n", %fileV940%, UTF-8
    return !ErrorLevel
}

FarmMapJournalOpenV940:
fileV940 := FarmMapJournalPathV940()
if (!FileExist(fileV940))
    FileAppend, % "", %fileV940%, UTF-8
Run, % "notepad.exe " . Chr(34) . fileV940 . Chr(34),, UseErrorLevel
if (ErrorLevel)
    MsgBox, 48, Nhật ký map, Không mở được file nhật ký.`n%fileV940%
return

FarmMapJournalTimerV940:
if (farmUserPausedV2026)
    return
FarmMapJournalTickV940()
return

FarmMapJournalTickV940()
{
    global farmMapJournalRunV940,farmMapJournalHoldEpochV940
    global farmControlOwnerV186,mapWorkflowV185,stageTwoV166
    global farmRunEpochV535,backgroundPidV63
    activeV940 := FarmControlRunningV186() || IsObject(mapWorkflowV185) || IsObject(stageTwoV166)
    stageV940 := IsObject(mapWorkflowV185) ? mapWorkflowV185.stage : 0
    rowV940 := CoordYellowIndexV48()
    if (IsObject(farmMapJournalRunV940) && rowV940>0)
        farmMapJournalRunV940.lastRow := rowV940
    if (IsObject(farmMapJournalRunV940))
        FarmMapJournalDeathPollV940()
    if (!activeV940 || stageV940>=3)
    {
        if (IsObject(farmMapJournalRunV940))
            FarmMapJournalFinishV940(!activeV940 ? "STOP" : "COMPLETE")
        if (!activeV940)
            farmMapJournalHoldEpochV940 := -1
        return
    }
    ; Sau khi ket thuc GĐ2, khong mo phien moi trong GĐ3/GĐ4.
    ; Chi bat dau lai khi map moi/lan Farm moi co epoch moi.
    if (IsObject(farmMapJournalRunV940) || farmMapJournalHoldEpochV940=farmRunEpochV535)
        return
    ownerV940 := IsObject(mapWorkflowV185) ? mapWorkflowV185.map : farmControlOwnerV186
    if (ownerV940="")
        ownerV940 := "FARM"
    rowTextV940 := rowV940>0 ? rowV940 : "--"
    farmMapJournalRunV940 := {at:A_TickCount,owner:ownerV940,pid:backgroundPidV63
        ,epoch:farmRunEpochV535,startRow:rowV940,lastRow:rowV940,deathCountV940:0}
    FormatTime, startedV940,, dd/MM/yyyy HH:mm:ss
    FarmMapJournalWriteV940("FARM " . FarmMapJournalLabelV940(ownerV940) . ":`r`n"
        . "    Bắt đầu: " . startedV940 . " | Dòng vàng: " . rowTextV940)
    ; Neu bat dau Farm khi nhan vat da chet thi ghi nhan ngay lan chet do.
    FarmMapJournalDeathPollV940(true)
}

; V941: trang thai chung cho ca nhan dien hoi sinh va timer nhat ky.
; Mot lan chet chi duoc ghi mot dong; chi mo khoa sau khi song on dinh >= 1.5s.
FarmMapJournalDeathObserveV940(pid,mode)
{
    global farmMapJournalRunV940,farmMapJournalDeathStateV940
    if (!pid || mode<0)
        return
    st := farmMapJournalDeathStateV940
    if (!IsObject(st) || st.pid!=pid)
    {
        st := {pid:pid,dead:false,aliveAt:0,lastObserved:0}
        farmMapJournalDeathStateV940 := st
    }
    st.lastObserved := A_TickCount
    run := farmMapJournalRunV940
    deadNow := mode=0 || mode=17
    if (deadNow)
    {
        st.aliveAt := 0
        ; Khong khoa su kien chet khi chua bat dau phien nhat ky.
        if (st.dead || !IsObject(run) || run.pid!=pid)
            return
        st.dead := true
        run.deathCountV940 := (run.HasKey("deathCountV940") ? run.deathCountV940 : 0)+1
        row := CoordYellowIndexV48()
        if (row<1)
            row := run.lastRow
        rowText := row>0 ? row : "--"
        FormatTime, when,, dd/MM/yyyy HH:mm:ss
        FarmMapJournalWriteV940("    Chết lần " . run.deathCountV940 . ": " . when
            . " | Dòng vàng: " . rowText)
        return
    }
    ; Khong xem read loi la song; chi nhan mode doc duoc cua nhan vat.
    if (st.dead)
    {
        if (!st.aliveAt)
            st.aliveAt := A_TickCount
        else if (A_TickCount-st.aliveAt>=1500)
            st.dead := false,st.aliveAt := 0
    }
}

; Timer chi doc mode khi detector hoi sinh khong cap nhat trong 0.9 giay.
FarmMapJournalDeathPollV940(force := false)
{
    global farmMapJournalRunV940,farmMapJournalDeathStateV940
    run := farmMapJournalRunV940
    if (!IsObject(run) || !run.pid)
        return
    st := farmMapJournalDeathStateV940
    if (!force && IsObject(st) && st.pid=run.pid && st.lastObserved
        && A_TickCount-st.lastObserved<900)
        return
    base := D2GetModuleBaseV35(run.pid,"D2Client.dll")
    h := base ? D2OpenProcess(run.pid) : 0
    if (!h)
        return
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        if (!player || !MonsterBossProbeReadV1(h,player+0x10,4,modeBytes))
            return
        mode := NumGet(modeBytes,0,"UInt")
        FarmMapJournalDeathObserveV940(run.pid,mode)
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

FarmMapJournalFinishV940(reason)
{
    global farmMapJournalRunV940,farmMapJournalHoldEpochV940,farmRunEpochV535
    runV940 := farmMapJournalRunV940
    if (!IsObject(runV940))
        return
    endRowV940 := CoordYellowIndexV48()
    if (endRowV940<1)
        endRowV940 := runV940.lastRow
    rowTextV940 := endRowV940>0 ? endRowV940 : "--"
    secondsV940 := Floor(Max(0,A_TickCount-runV940.at)/1000)
    durationV940 := Floor(secondsV940/60) . " phút " . Mod(secondsV940,60) . " giây"
    resetV940 := InStr(reason,"GD4_RESET") ? " | Reset GĐ4" : ""
    FormatTime, endedV940,, dd/MM/yyyy HH:mm:ss
    FarmMapJournalWriteV940("    Kết thúc: " . endedV940 . " | Dòng vàng: " . rowTextV940
        . resetV940 . "`r`n    Thời gian: " . durationV940
        . "`r`n--------------------------------")
    farmMapJournalHoldEpochV940 := runV940.epoch
    farmMapJournalRunV940 := false
}

ContinuousMapChangedV64:
GuiControlGet, continuousMapV168,, ContinuousMapInputV64
continuousMapV168 := continuousMapV168 ? true : false
continuousMapSectionV168 := ProfileSection(currentProfile)
IniWrite, %continuousMapV168%, % ProfileConfigPathV364(continuousMapSectionV168), %continuousMapSectionV168%, ContinuousMap
if (IsObject(stageTwoV166))
    stageTwoV166.continuous := continuousMapV168
return

GuideTextV64()
{
    text := ""
    text .= "HƯỚNG DẪN AUTO-GSF`r`n"
    text .= "Bản đi kèm: Form 5 có 6 dòng; SIG lấy cả đồ trong rương; SCOS buff tại tọa độ 2.`r`n"
    text .= "`r`n"
    text .= "1. BẮT ĐẦU VÀ LƯU CẤU HÌNH`r`n"
    text .= "- Mở game và chọn đúng nhân vật/cửa sổ cần điều khiển, sau đó mở tool.`r`n"
    text .= "- Profile: chọn bộ cấu hình muốn dùng. Ô Tên và LƯU PROFILE dùng để lưu profile; XÓA PROFILE xóa profile đang chọn.`r`n"
    text .= "- Lưu ở cuối cửa sổ: lưu các ô phím, delay, lựa chọn và danh sách đã chỉnh. Một số ô tự lưu ngay khi thay đổi; vẫn nên bấm Lưu sau khi thiết lập xong.`r`n"
    text .= "- Phím: nhập tên phím như F1, F2, Q, E... None hoặc để trống nghĩa là không dùng ở ô hỗ trợ phím tùy chọn. M3 là chuột giữa ở ô có hỗ trợ.`r`n"
    text .= "- Delay thông thường tính bằng mili giây: 1000 = 1 giây. Các ô ghi (s), giây hoặc phút dùng đúng đơn vị trên giao diện.`r`n"
    text .= "`r`n"
    text .= "2. TAB BUFF — FORM 1: BUFF SET PHỤ`r`n"
    text .= "- Chuyển set: phím đổi bộ vũ khí. Delay bên cạnh là thời gian chờ sau khi đổi set.`r`n"
    text .= "- Kill 1 / Kill 2: phím của hai skill cần dùng khi ở set phụ; mỗi dòng có delay riêng.`r`n"
    text .= "- Phím chạy set: phím gọi lượt buff set phụ. Tool đổi set, dùng các skill đã nhập rồi đổi về set chính.`r`n"
    text .= "- Kill trái: thông tin skill trái mà tool đã đọc được để hỗ trợ giữ đúng thiết lập của set.`r`n"
    text .= "`r`n"
    text .= "3. TAB BUFF — FORM 2: BUFF NHANH`r`n"
    text .= "- Phím buff: phím gọi một lượt buff nhanh theo các dòng đã cấu hình.`r`n"
    text .= "- Delay: khoảng chờ dùng trong lượt buff nhanh, tính bằng mili giây.`r`n"
    text .= "- Dòng 4 -> 5 -> 6 mô tả thứ tự dùng nhóm phím cast, nhóm cast + click và chọn skill đánh sau buff. Đây là một lượt, không phải lệnh tự chạy farm.`r`n"
    text .= "`r`n"
    text .= "4. TAB BUFF — FORM 3: KIỂM TRA BUFF`r`n"
    text .= "- Deathlord, Pinnacle, Anathema: mỗi dòng gồm ID trạng thái và phím skill tương ứng. Dấu / ngăn hai ô ID và phím.`r`n"
    text .= "- ID là ID trạng thái buff, không phải Class ID của quái hoặc vật phẩm.`r`n"
    text .= "- GET ID SKILL: hỗ trợ đọc thông tin skill trong game; kết quả hiện ở ô bên cạnh.`r`n"
    text .= "- Tool đọc trạng thái hiện tại để dùng skill còn thiếu, tránh bấm lại skill dạng bật/tắt khi trạng thái đã có.`r`n"
    text .= "- Auto Buff Delay: bấm để bật/tắt chạy buff theo khoảng thời gian của ô bên cạnh. Ô này tính bằng mili giây.`r`n"
    text .= "`r`n"
    text .= "5. TAB BUFF — FORM 4: PHÍM CAST`r`n"
    text .= "- Có 3 dòng Phím / Delay. Nhập các phím cần bấm trong nhóm cast.`r`n"
    text .= "- Nhóm này chỉ bấm phím; phần dùng skill cần click phải được đặt ở Form 5.`r`n"
    text .= "- Dòng bỏ trống hoặc None không được thực hiện. Bấm Lưu sau khi chỉnh.`r`n"
    text .= "`r`n"
    text .= "6. TAB BUFF — FORM 5: BẤM + CLICK PHẢI`r`n"
    text .= "- Có 6 dòng, mỗi dòng gồm Phím và Delay.`r`n"
    text .= "- Dùng cho skill cần chọn bằng phím rồi click phải để thi triển trong lượt buff.`r`n"
    text .= "- Hai dòng 5 và 6 được lưu/nạp cùng cơ chế với bốn dòng đầu.`r`n"
    text .= "- Khi chạy buff nhanh, các dòng hợp lệ được xử lý theo thứ tự. Việc chọn lại skill cuối lượt do luồng buff hiện có thực hiện.`r`n"
    text .= "`r`n"
    text .= "7. TAB BUFF — FORM 6: CHỌN SKILL ĐÁNH`r`n"
    text .= "- Ô trên cùng: phím chọn skill đánh.`r`n"
    text .= "- Kill đánh phải: chọn skill rồi đánh mục tiêu bằng click phải.`r`n"
    text .= "- Kill đè phải: giữ chuột phải và hướng lần lượt qua nhóm mục tiêu của lượt quét.`r`n"
    text .= "- Ô số bên cạnh Kill đè phải: số mục tiêu tối đa trong một nhóm. Chỉ chọn một trong hai chế độ.`r`n"
    text .= "- Khi hết nhóm hoặc cần nhả chuột, tool kết thúc lượt giữ rồi dùng lượt quét tiếp theo để chọn nhóm mới.`r`n"
    text .= "- Nếu bỏ trống phím skill, tool dùng lựa chọn skill cuối theo cấu hình F hiện có.`r`n"
    text .= "- Bước đánh trước buff có luồng riêng: dùng phím skill đánh rồi click phải, không chạy nguyên nhóm giữ chuột của Form 6.`r`n"
    text .= "`r`n"
    text .= "8. TAB NHẶT ĐỒ — HP VÀ MANA`r`n"
    text .= "- Buff HP Belt / Buff MP Belt: bật dùng bình trên belt theo cấu hình.`r`n"
    text .= "- Pot: chọn ô belt hoặc chế độ Auto(1-4) nếu có trong danh sách.`r`n"
    text .= "- Ngưỡng: mức HP/MP kích hoạt dùng bình. Nhóm HP có Ngưỡng 1/2 để cấu hình hai ngưỡng.`r`n"
    text .= "- Cooldown: thời gian chờ giữa các lượt dùng (mili giây). HP phải lớn hơn 0; đổi profile vẫn giữ lượt chờ HP đang còn.`r`n"
    text .= "- Buff HP Rương / HP Cube / MP Rương / MP Cube: bật các nguồn bình tương ứng.`r`n"
    text .= "- Phím 16HP Rương -> Belt: chuyển nhóm bình HP từ rương nhân vật lên belt.`r`n"
    text .= "- Phím 8HP + 8MP -> Belt: nạp hỗn hợp bình theo nhóm đã ghi trên giao diện.`r`n"
    text .= "- Phím Rương -> Cube và hai ô Delay: cấu hình chuyển vật phẩm từ rương nhân vật sang Cube và thời gian chờ nhặt/chuyển.`r`n"
    text .= "- Sắp Rương: chạy chức năng sắp đồ trong rương nhân vật.`r`n"
    text .= "- Chuyển Khố: chuyển theo chức năng kho khi đọc được kho gần nhân vật; không yêu cầu đứng riêng ở thành 109.`r`n"
    text .= "`r`n"
    text .= "9. TAB NHẶT ĐỒ — BẬT NHẶT VÀ CÁC NHÓM`r`n"
    text .= "- Nhặt: công tắc nhặt tự động. Ô phím bên cạnh dùng để bật/tắt nhặt.`r`n"
    text .= "- Bán kính: phạm vi xét đồ để nhặt quanh vùng đang được luồng nhặt sử dụng.`r`n"
    text .= "- BK teleport khi nhặt lỗi: khoảng cách dùng khi teleport tới hoặc qua vật phẩm sau khi nhặt thất bại; mặc định 4 ô, chỉnh từ 1 đến 100.`r`n"
    text .= "- Nhặt thẳng vào Cube: bật cách xử lý đưa đồ vào Cube theo cơ chế nhặt của tool.`r`n"
    text .= "- Ẩn/hiện DS nhặt: điều khiển hiển thị danh sách/cảnh báo nhặt.`r`n"
    text .= "- Nhặt vào rương / Nhặt Set Cube / Nhặt Unique Cube: mỗi nhóm có ô phím riêng và nút Nhặt để gọi trực tiếp.`r`n"
    text .= "- GET item: phím gọi chức năng đọc/thêm vật phẩm theo cơ chế GET. Danh sách cụ thể được quản lý ở tab ITEM NHẶT.`r`n"
    text .= "`r`n"
    text .= "10. SIG — ĐỒ DƯỚI ĐẤT VÀ TRONG RƯƠNG`r`n"
    text .= "- Bấm Sig hoặc phím Sig để xử lý Set và các loại Unique đã chọn.`r`n"
    text .= "- TU / SU / SSU / SSSU: chỉ loại được tích chọn mới được dùng cho công thức Unique tương ứng. Set có lượt xử lý riêng.`r`n"
    text .= "- Bản này lấy nguyên liệu hợp lệ từ cả dưới đất và rương nhân vật. Rương nhân vật là túi mang theo, không phải đồ đang nằm trong khố.`r`n"
    text .= "- Mỗi lượt ghép đều quét lại cả hai nguồn; không chỉ kiểm tra rương ở lần đầu.`r`n"
    text .= "- Đồ trong danh sách không SIG, đồ được đánh dấu giữ và đồ đang chờ cất kho được kiểm tra trước khi đưa vào công thức.`r`n"
    text .= "- Chuẩn bị Cube và các tem/nguyên liệu đúng loại trong rương. Tool kiểm tra vị trí đồ, đưa nguyên liệu vào Cube, ghép, xử lý mảnh và trả vật phẩm dùng lại.`r`n"
    text .= "- Set hoặc SU còn ít món vẫn đi qua nhánh công thức tương ứng; không mặc định chờ đủ 5 mới xử lý.`r`n"
    text .= "- Ghép xong, SIG đóng Cube rồi gọi nhặt thật và kiểm tra hoàn tất.`r`n"
    text .= "- Khi SIG đang chạy, nút đổi thành Hủy; bấm Hủy để yêu cầu dừng lượt đang làm.`r`n"
    text .= "- Khi có lỗi item trên chuột/Cube, giữ nguyên hiện trạng để đọc thông báo hoặc xuất log kiểm tra.`r`n"
    text .= "`r`n"
    text .= "11. TAB FARM — CÁC Ô TỰ ĐÁNH`r`n"
    text .= "- BK đánh: bán kính tìm quái của luồng farm chính.`r`n"
    text .= "- Mở Cổng: phím mở cổng; ô sau dấu / là số tọa độ giữa các lần mở cổng theo lộ trình.`r`n"
    text .= "- Cast(tele): phím teleport; ô sau dấu / là khoảng thời gian tính bằng giây.`r`n"
    text .= "- Bước di chuyển: độ dài bước dùng khi tính điểm di chuyển.`r`n"
    text .= "- Cho phép xa đích: khoảng cho phép lệch/đi xa điểm đích trong xử lý đường đi.`r`n"
    text .= "- Thời gian xét kẹt(s): thời gian quan sát không tiến triển trước khi chuyển sang xử lý kẹt.`r`n"
    text .= "- Đi tối thiểu: ngưỡng di chuyển tối thiểu trong xử lý có dùng tùy chọn này.`r`n"
    text .= "- PET Loại Trừ: danh sách Class ID cần bỏ qua khi chọn mục tiêu. Bỏ Qua và Khóa(s) đặt thời gian xét bỏ qua/khóa quái hoặc vùng kẹt theo luồng hiện có.`r`n"
    text .= "- BK Lock: bán kính dùng chung khi xét kẹt quái và xác định đã đến gần vật phẩm để nhặt; 0 tự lấy BK đánh / 2.`r`n"
    text .= "- Boss Ưu Tiên: danh sách boss để luồng farm chính xét ưu tiên. Bước đánh trước buff không có ưu tiên boss riêng.`r`n"
    text .= "`r`n"
    text .= "12. VIEW ID, VIEW POS VÀ TIP`r`n"
    text .= "- View ID: bật bảng thông tin farm, trạng thái đánh/nhặt, danh sách mục tiêu và thông tin vật phẩm.`r`n"
    text .= "- Item quét: số item hợp lệ tìm thấy trong lượt quét nhặt của luồng farm; không phải tổng số item trong rương hay tổng số đã nhặt cả buổi.`r`n"
    text .= "- Khóa BK nhặt: bán kính của vùng nhặt đang khóa; 0 khi chưa có vùng khóa.`r`n"
    text .= "- View Pos: xem map, tọa độ, phòng và thông tin vị trí đọc được từ game.`r`n"
    text .= "- Tip: bật/tắt thông báo ngắn. Một số phần hiển thị nhường thao tác khi bạn giữ chuột hoặc đang thao tác trên tool.`r`n"
    text .= "`r`n"
    text .= "13. ĐÁNH TRƯỚC KHI BUFF`r`n"
    text .= "- Lấy vị trí vừa lên làm tâm cố định; phạm vi chọn quái là BK đánh / 2.`r`n"
    text .= "- Chọn quái hợp lệ trong vùng này; không có ngưỡng 5 đơn vị để phân biệt đứng đánh/đuổi như bản cũ.`r`n"
    text .= "- Quái chạy ra ngoài vùng sẽ không được đuổi tiếp. Tâm vùng không chạy theo nhân vật.`r`n"
    text .= "- Khi không còn quái hợp lệ trong vùng, nhân vật quay về điểm buff rồi mới bắt đầu buff.`r`n"
    text .= "- Riêng SCOS map 270: điểm buff là tọa độ 2 trong lộ trình. Tool đánh và đi vào tọa độ 2 trước; không quay về tọa độ 1 sát ranh map 241/270 để buff.`r`n"
    text .= "- SCOS thiếu tọa độ 2 hợp lệ thì chờ, không tự buff ở ranh giới.`r`n"
    text .= "`r`n"
    text .= "14. MAP, LỘ TRÌNH VÀ GHI TỌA ĐỘ`r`n"
    text .= "- MAP SCOS là tên khung chọn map/lộ trình. Danh sách dùng để chọn map cần thao tác.`r`n"
    text .= "- THÊM MAP / XÓA MAP: thêm hoặc xóa map được chọn trong danh sách.`r`n"
    text .= "- Tạo / Sửa: gọi chức năng tạo hoặc ghi sửa lộ trình/phòng theo chế độ ghi hiện có.`r`n"
    text .= "- KC: khoảng cách dùng khi ghi tọa độ.`r`n"
    text .= "- Danh sách tọa độ: chọn dòng muốn thao tác; dòng vàng biểu thị điểm đang được theo dõi/chọn theo trạng thái tool.`r`n"
    text .= "- GO: đi tới tọa độ chọn. Prev / Next: đi tới điểm trước/sau.`r`n"
    text .= "- STOP cạnh GO: dừng luồng điều khiển đang chạy. GO/Prev/Next là thao tác đi thủ công và đưa farm về trạng thái dừng để nhận lệnh mới.`r`n"
    text .= "- F-ON: bật/tắt theo dõi vị trí/map theo cơ chế hiện có.`r`n"
    text .= "- ADD: thêm tọa độ sau dòng vàng. UPDATE: gọi chế độ cập nhật/chèn theo nút hiện tại. Hai mũi tên: đổi thứ tự dòng. XÓA: xóa dòng. Load: nạp map thủ công.`r`n"
    text .= "- Ghi Tọa Độ ở cuối cửa sổ: bật/tắt chức năng ghi tuyến; bấm lại khi ghi xong.`r`n"
    text .= "- Run test: chạy thử giai đoạn 2 với tuyến đã chuẩn bị; đây là chế độ test, không phải nút khởi động vòng farm đầy đủ.`r`n"
    text .= "- Mode trong cụm nút farm: đổi vùng map thường/test; chế độ test dùng thư mục Map\Test.`r`n"
    text .= "`r`n"
    text .= "15. CÁC NÚT FARM VÀ TÙY CHỌN ĐI KÈM`r`n"
    text .= "- SCOS, FAUT, CYC, UBU, CAIN, TRAN, VIZ, BO: chọn quy trình farm mang tên tương ứng. Các map cần có tuyến và điều kiện vào map phù hợp.`r`n"
    text .= "- 130 / 133 / 136 / 139: gọi nhóm farm theo cấp cuộn tương ứng. 3000: gọi quy trình 3000.`r`n"
    text .= "- VeLab6 đến VeLab10: gọi quy trình về LAB tương ứng theo chức năng hiện có.`r`n"
    text .= "- WEA: hiện chưa được gán chức năng; bấm sẽ hiện thông báo.`r`n"
    text .= "- Nút farm đang chạy hiện Stop; bấm lại để dừng. Bấm Start sau đó để bắt đầu lượt mới.`r`n"
    text .= "- SIG: bật bước SIG trong quy trình vào map khi quy trình đó sử dụng tùy chọn này.`r`n"
    text .= "- Cất Item: bật bước cất tiền/vật phẩm phù hợp trong quy trình có hỗ trợ.`r`n"
    text .= "- HOP: đứng trong thành có thủ khố đã tải, nhập số thành phẩm 1-9999; tự quăng/nhặt Cube trống, đến gần thủ khố ghép theo Rune.txt, về điểm thả nhặt nhanh đúng đồ đã rơi. Không cần danh sách tọa độ. Bấm lại để hủy.`r`n"
    text .= "`r`n"
    text .= "16. KHU VỰC FARM VÀ PHỤC HỒI GAME`r`n"
    text .= "- Trong thành / Ngoài thành: ID map dùng cho kiểm tra khu vực. GET đọc ID map tại vị trí hiện tại vào ô tương ứng.`r`n"
    text .= "- Chạy Map liên tục: điều khiển việc nối lượt farm tiếp sau khi tạo phòng mới. Bấm Lưu sau khi cấu hình nếu cần lưu các ô khác cùng lúc.`r`n"
    text .= "- Đứng ... phút Farm: khoảng thời gian không thấy di chuyển/đánh trước khi gọi phục hồi trong lúc farm đang chạy.`r`n"
    text .= "- Chỉ di chuyển/đánh được xác nhận mới làm mới thời gian hoạt động; không đọc được nhân vật vẫn được tính là chưa thấy hoạt động.`r`n"
    text .= "- Game / nút ... ở tab ITEM NHẶT: chọn đường dẫn Game.exe dùng để mở lại.`r`n"
    text .= "- ID / Pass: thông tin đăng nhập dùng trong phục hồi. Ô Pass được che trên giao diện; mật khẩu lưu được bảo vệ theo tài khoản Windows.`r`n"
    text .= "- Vào GĐ4: tích chọn là chạy ngay luồng mở lại/đăng nhập phục hồi, không cần bấm Start.`r`n"
    text .= "- Khi phục hồi, tool ngắt tác vụ của phiên game cũ và giữ yêu cầu farm để tiếp tục. Quá 3 phút sẽ thử phục hồi lại thay vì tự hủy vì hết thời gian.`r`n"
    text .= "`r`n"
    text .= "17. TAB ITEM NHẶT — CÁC DANH SÁCH`r`n"
    text .= "- Cột trái: danh mục có sẵn, gồm tên từng Charm và Relic; mở tool là có. Danh mục được dùng cho nhặt mặc định, mục Không Nhặt chặn trước.`r`n"
    text .= "- Ô phải là văn bản luật nhặt. Giữ các tiêu đề để phân biệt từng mục; bấm Lưu sau khi sửa.`r`n"
    text .= "- Nhặt Thêm: những loại/tên vật phẩm cần nhặt thêm.`r`n"
    text .= "- Chuyển Charm Vào Cube: danh sách vật phẩm dùng luồng chuyển Cube; có thể nhập tên như Charm hoặc Relic, không cần thêm [cube] trong mục này.`r`n"
    text .= "- Chuyển Vào Kho (Cất Tiền): đồ phù hợp trong Cube hoặc dưới đất được xử lý qua túi trung gian để cất kho khi chạy bước cất tiền; luật này bỏ qua đồ đã có sẵn trong túi.`r`n"
    text .= "- Không Nhặt: mỗi loại trên một dòng, ví dụ Gem, Rune thường, Charm. Đây là danh sách loại trừ nhặt.`r`n"
    text .= "- Vật phẩm không SIG ở ô trái phía dưới: danh sách giữ khỏi công thức SIG, khác với Không Nhặt.`r`n"
    text .= "- Không Nhặt chỉ cần một khối. Bản hiện tại gộp các khối/dòng loại trừ trùng khi đọc/lưu.`r`n"
    text .= "`r`n"
    text .= "18. CÁCH VIẾT TÊN, OPTION VÀ MÀU`r`n"
    text .= "- Light Plated Boots: nhặt loại đó, không thêm điều kiện option.`r`n"
    text .= "- Light Plate [2-5]: lọc từ +2 đến +5 All Skills. Full Helm [3]: lọc +3 All Skills.`r`n"
    text .= "- Angelic [2-5] {doc}: kết hợp All Skills và option có Poison; doc/độc đều dùng được.`r`n"
    text .= "- ""Leather Gloves"" {Fire dance}: lọc loại đồ và chữ option tương ứng.`r`n"
    text .= "- [] và {} dùng như nhau. Các nhóm riêng cần cùng thỏa điều kiện; dấu | trong cùng một nhóm cho phép chọn một trong các điều kiện.`r`n"
    text .= "- Rune [red]: luật Rune có màu cảnh báo đỏ. Các màu hỗ trợ gồm red, green, blue, yellow, gold, white, orange, purple, grey, pink, tan, darkgreen, black.`r`n"
    text .= "- Set xanh [Zakarum]: luật nhặt Set, đồng thời giữ các bộ được chỉ rõ khỏi SIG theo cú pháp Set của tool.`r`n"
    text .= "- # ở đầu dòng dùng để tắt dòng/ghi chú. Tên không phân biệt hoa thường nhưng cần đúng loại tên mà game cung cấp.`r`n"
    text .= "- Luật nhặt rộng có thể vẫn nhận một món không đạt luật option hẹp. Muốn chỉ nhặt theo option thì kiểm tra và bỏ các luật nhặt rộng trùng loại.`r`n"
    text .= "`r`n"
    text .= "19. XUẤT LOG VÀ HƯỚNG DẪN`r`n"
    text .= "- Xuất Log: bấm để bắt đầu ghi chẩn đoán; bấm lần nữa để dừng và lấy gói log theo thông báo của tool.`r`n"
    text .= "- Muốn kiểm tra lỗi chui cổng, đánh, buff, nhặt hoặc SIG: bật log trước khi thực hiện lại thao tác gây lỗi rồi dừng log sau khi lỗi xảy ra.`r`n"
    text .= "- Hướng dẫn: mở cửa sổ có thanh cuộn và tạo/cập nhật Huong-dan-Auto-GSF.txt trong thư mục txt nếu thư mục cho phép ghi.`r`n"
    text .= "- Cửa sổ hướng dẫn có thể kéo rộng/cao; dùng cuộn chuột hoặc thanh cuộn để đọc tiếp.`r`n"
    text .= "`r`n"
    text .= "GHI CHÚ`r`n"
    text .= "Tài liệu mô tả cấu hình và luồng trong bản AHK đi kèm. Các thay đổi được kiểm tra trên mã nguồn; chưa được chạy xác nhận trực tiếp trong Diablo II/AutoHotkey trên Windows.`r`n"
    return text
}

UniqueKnownTierV4(tier)
{
    return tier="TU" || tier="SU" || tier="SSU" || tier="SSSU"
}


SetPickupVerifiedV4(h,cls,itemData)
{
    if (!h || !itemData || cls<0 || D2ReadU32(h,itemData)!=5)
        return false
    idx := D2ReadU32(h,itemData+0x28)
    pid := DllCall("GetProcessId","Ptr",h,"UInt")
    commonBase := pid ? D2GetModuleBaseV35(pid,"D2Common.dll") : 0
    if (!commonBase)
        return false
    sgpt := D2ReadU32(h,commonBase+0x99E1C)
    if (!sgpt)
        return false
    setTable := D2ReadU32(h,sgpt+0xC18),setCount := D2ReadU32(h,sgpt+0xC1C)
    itemTable := D2ReadU32(h,commonBase+0x9FB98),itemCount := D2ReadU32(h,commonBase+0x9FB94)
    if (!setTable || !itemTable || setCount<1 || setCount>32767 || itemCount<1 || itemCount>65535 || idx>=setCount || cls>=itemCount)
        return false
    record := setTable+idx*0x1B8
    if (D2ReadU16(h,record)!=idx)
        return false
    setCode := D2ReadU32(h,record+0x28)
    itemCode := D2ReadU32(h,itemTable+cls*0x1A8+0x80)
    return setCode!=0 && setCode=itemCode
}

UniqueLowNormalCodeV6(code)
{
    padding := (code >> 24) & 0xFF
    if (padding!=0 && padding!=0x20)
        return false
    code := code & 0xFFFFFF
    return code=0x6E6972 || code=0x756D61 || code=0x77656A
        || code=0x767161 || code=0x767163
}


PickupIsCharmV571(h,cls)
{
    static verified := {}
    if (!h || cls<0)
        return false
    pid := DllCall("GetProcessId","Ptr",h,"UInt")
    common := pid ? D2GetModuleBaseV35(pid,"D2Common.dll") : 0
    if (!common)
        return false
    moduleKey := pid . "|" . common
    if (!verified.HasKey(moduleKey))
    {
        if (!RecoveryMenuModuleV528(h,common,0x4B95C439,0xA9000))
            return false
        verified[moduleKey] := true
    }
    items := D2ReadU32(h,common+0x9FB98),count := D2ReadU32(h,common+0x9FB94)
    types := D2ReadU32(h,common+0xA0AD0),typeCount := D2ReadU32(h,common+0xA0AD4)
    if (!items || !types || count<1 || count>65535 || cls>=count || typeCount<1 || typeCount>32767)
        return false
    if (!MonsterBossProbeReadV1(h,items+cls*0x1A8+0x11E,4,itemTypes))
        return false
    pending := [NumGet(itemTypes,0,"UShort"),NumGet(itemTypes,2,"UShort")],seen := {},index := 1
    Loop, 128
    {
        if (index>pending.Length())
            break
        type := pending[index],index++
        if (type<=0 || type>=typeCount || seen.HasKey(type))
            continue
        seen[type] := true
        if (!MonsterBossProbeReadV1(h,types+type*0xE4,0x18,record))
            continue
        if (NumGet(record,0x17,"UChar"))
            return true
        pending.Push(NumGet(record,4,"UShort")),pending.Push(NumGet(record,6,"UShort"))
    }
    return false
}

ConsumablePickupGroupV7(h,cls)
{
    global consumableClassRAMV7,consumableNameJobsV7,consumableLastPidV7
    if (!IsObject(consumableClassRAMV7))
        consumableClassRAMV7 := {},consumableNameJobsV7 := {}
    ConsumableNamePollV7()
    pid := h ? DllCall("GetProcessId","Ptr",h,"UInt") : consumableLastPidV7
    if (!pid || cls<0)
        return ""
    key := pid . "|" . cls
    if (consumableClassRAMV7.HasKey(key))
        return PickupNameMatchV8(consumableClassRAMV7[key])
    if (!h || consumableNameJobsV7.HasKey(key) || consumableNameJobsV7.Count()>=4)
        return ""
    common := D2GetModuleBaseV35(pid,"D2Common.dll")
    if (!common)
        return ""
    table := D2ReadU32(h,common+0x9FB98),count := D2ReadU32(h,common+0x9FB94)
    if (!table || count<1 || count>65535 || cls>=count)
        return ""
    record := table+cls*0x1A8
    VarSetCapacity(itemHeaderV7,0xF6,0),gotV7 := 0
    if (!DllCall("ReadProcessMemory","Ptr",h,"Ptr",record,"Ptr",&itemHeaderV7,"UPtr",0xF6,"UPtr*",gotV7) || gotV7!=0xF6)
        return ""
    nameId := NumGet(itemHeaderV7,0xF4,"UShort")
    lang := D2GetModuleBaseV35(pid,"D2Lang.dll")
    if (!lang)
        return ""
    job := ConsumableNameStartV7(pid,lang+0x9450,nameId)
    if (IsObject(job))
    {
        job.key := key,job.pid := pid
        consumableNameJobsV7[key] := job,consumableLastPidV7 := pid
    }
    return ""
}

ConsumableNameStartV7(pid,fn,nameId)
{
    hp := DllCall("OpenProcess","UInt",0x043A,"Int",0,"UInt",pid,"Ptr")
    if (!hp)
        return false
    remote := DllCall("VirtualAllocEx","Ptr",hp,"Ptr",0,"UPtr",32,"UInt",0x3000,"UInt",0x40,"Ptr")
    if (!remote)
    {
        DllCall("CloseHandle","Ptr",hp)
        return false
    }
    VarSetCapacity(code,18,0)
    NumPut(0x53,code,0,"UChar")
    NumPut(0x08244C8B,code,1,"UInt")
    NumPut(0xC033,code,5,"UShort")
    NumPut(0xBB,code,7,"UChar"),NumPut(fn,code,8,"UInt")
    NumPut(0xD3FF,code,12,"UShort"),NumPut(0x5B,code,14,"UChar")
    NumPut(0xC2,code,15,"UChar"),NumPut(4,code,16,"UShort")
    wrote := 0
    if (!DllCall("WriteProcessMemory","Ptr",hp,"Ptr",remote,"Ptr",&code,"UPtr",18,"UPtr*",wrote) || wrote!=18)
    {
        DllCall("VirtualFreeEx","Ptr",hp,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hp)
        return false
    }
    DllCall("FlushInstructionCache","Ptr",hp,"Ptr",remote,"UPtr",18)
    th := DllCall("CreateRemoteThread","Ptr",hp,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",nameId,"UInt",0,"Ptr",0,"Ptr")
    if (!th)
    {
        DllCall("VirtualFreeEx","Ptr",hp,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hp)
        return false
    }
    return {hp:hp,remote:remote,th:th}
}

ConsumableNamePollV7()
{
    global consumableClassRAMV7,consumableNameJobsV7
    if (!IsObject(consumableNameJobsV7) || !consumableNameJobsV7.Count())
        return
    done := []
    for key,job in consumableNameJobsV7
    {
        if (DllCall("WaitForSingleObject","Ptr",job.th,"UInt",0)!=0)
            continue
        ptr := 0,name := ""
        if (DllCall("GetExitCodeThread","Ptr",job.th,"UInt*",ptr) && ptr)
        {
            VarSetCapacity(wide,514,0),got := 0
            if (DllCall("ReadProcessMemory","Ptr",job.hp,"Ptr",ptr,"Ptr",&wide,"UPtr",512,"UPtr*",got) && got=512)
                name := StrGet(&wide,"UTF-16")
        }
        consumableClassRAMV7[key] := name
        DllCall("VirtualFreeEx","Ptr",job.hp,"Ptr",job.remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",job.th),DllCall("CloseHandle","Ptr",job.hp)
        done.Push(key)
    }
    for _,key in done
        consumableNameJobsV7.Delete(key)
}

ConsumableNameCleanupV7()
{
    global consumableNameJobsV7
    if (!IsObject(consumableNameJobsV7))
        return
    for _,job in consumableNameJobsV7
    {
        if (DllCall("WaitForSingleObject","Ptr",job.th,"UInt",0)=0)
            DllCall("VirtualFreeEx","Ptr",job.hp,"Ptr",job.remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",job.th),DllCall("CloseHandle","Ptr",job.hp)
    }
    consumableNameJobsV7 := {}
}

ConsumableKnownNameV7(name)
{
    name := RegExReplace(name,Chr(255) . "c.","")
    runes := "El|Eld|Tir|Nef|Eth|Ith|Tal|Ral|Ort|Thul|Amn|Sol|Shael|Dol|Hel|Io|Lum|Ko|Fal|Lem|Pul|Um|Mal|Ist|Gul|Vex|Ohm|Lo|Sur|Ber|Jah|Cham|Zod"
        . "|Ol|Elq|Tyr|Nif|Xeth|Xith|Thal|Rhal|Urt|Tuul|Ahmn|Zol|Shaen|Doj|Hem|Iu|Lux|Ka|Fel|Lew|Phul|Un|Mhal|Yst|Gur|Vez|Ohn|Loz|Zur|Bur|Iah|Yham|Xod"
        . "|Taha|Ghal|Qor|Fire|Stone|Arcane|Poison|Light|Ice"
    shrines := "Abandoned|Creepy|Eerie|Enchanted|Fascinating|Hidden|Intimidating|Magical|Ornate|Quiet|Sacred|Shimmering|Spiritual|Tainted|Trinity|Weird"
    gems := "Diamond|Amethyst|Ruby|Topaz|Bloodstone|Onyx|Amber|Turquoise|Sapphire|Emerald|Rainbow Stone|Skull"
    Loop, Parse, name, `n, `r
    {
        line := Trim(RegExReplace(A_LoopField,"\s+"," "))
        if (RegExMatch(line,"i)^(?:" . runes . ") Rune$") || RegExMatch(line,"i)^(?:Great|Enchanted|Elemental) Rune$"))
            return "RUNE"
        if (RegExMatch(line,"i)^(?:(?:Flawless|Perfect) )?(?:" . gems . ")$"))
            return "GEM"
        if (RegExMatch(line,"i)^(?:" . shrines . ") Shrine(?: \(\d+\))?$") || RegExMatch(line,"i)^Shrine(?: \(\d+\))?$"))
            return "SHRINE"
        if (RegExMatch(line,"i)^Oil of [A-Za-z ]+$"))
            return "OIL"
        if (RegExMatch(line,"i)^Arcane (?:Shard|Shards|Crystal|Cluster)$"))
            return "ARCANE"
        if (RegExMatch(line,"i)^Corrupted (?:Shard|Shards|Crystal|Cluster)$"))
            return "CORRUPTED"
        if (RegExMatch(line,"i)^(?:Sacred Essence|Heavenly Soul|Heavenly Souls|Mark of Infusion|Crate O' (?:Souls|Sacred Essence))$"))
            return "MATERIAL"
        if (RegExMatch(line,"i)\bSignet\b"))
		return "SIGNET"
    }
    return ""
}


PickupAutoGroupParseV7(line)
{
    line := PickupColorStripV14(Trim(line," `t`r`n" . Chr(0xFEFF)),ignoredColorV14)
    if (PickupShortParseV638(line,shortName,shortClass,shortQuality))
        return ""
    if (IsObject(SetNoSigParseV227(line)))
        return "SET_XANH"
    if (RegExMatch(line,"i)^ITEMDATA\s*=\s*07\s*\|\s*TIER\s*=\s*(TU|SU|SSU|SSSU)\s*$",m))
    {
        StringUpper, group, m1
        return group
    }
    if (RegExMatch(line,"i)^ITEMDATA\s*=\s*05\s*\|\s*TIER\s*=\s*(SET_XANH|SET)\s*$"))
        return "SET_XANH"
    if (RegExMatch(line,"i)^GROUP\s*=\s*(RUNE|GEM|SHRINE|OIL|ARCANE|CORRUPTED|MATERIAL|SIGNET|CHARM)\s*$",m))
    {
        StringUpper, group, m1
        return group
    }
    if (SubStr(line,1,1)="#" || line="" || InStr(line,"=") || PickupOptIsRuleV12(line))
        return ""
    StringUpper, plain, line
    if (plain="SET" || plain="SET XANH" || plain="SET_XANH")
        return "SET_XANH"
    if (RegExMatch(plain,"^(TU|SU|SSU|SSSU|UNIQUE|RUNE|GEM|SHRINE|OIL|ARCANE|CORRUPTED|MATERIAL|SIGNET|ANGELIC|CHARM)$"))
        return plain
    aliases := {"GEM THƯỜNG":"GEM_NORMAL","GEM NORMAL":"GEM_NORMAL","GEM FLAWLESS":"GEM_FLAWLESS","GEM PERFECT":"GEM_PERFECT","RUNE THƯỜNG":"RUNE_NORMAL","RUNE NORMAL":"RUNE_NORMAL","RUNE ENCHANTED":"RUNE_ENCHANTED","RUNE GREAT":"RUNE_GREAT","RUNE ELEMENTAL":"RUNE_ELEMENTAL"}
    if (aliases.HasKey(plain))
        return aliases[plain]
    patterns := PickupCatalogPatternsV9()
    normalized := PickupNameNormalizeV8(line)
    if (patterns.HasKey(normalized))
        return "FILTER:" . normalized
    return "NAME:" . normalized
}
PickupSetIsAngelicV13(h,cls,itemData,unit)
{
    global pickupAngelicSetIdsV13
    if (!IsObject(pickupAngelicSetIdsV13))
        pickupAngelicSetIdsV13 := {}
    if (!h || !itemData)
        return false
    setId := D2ReadU16(h,itemData+0x2C)
    if (setId && pickupAngelicSetIdsV13.HasKey(setId))
        return pickupAngelicSetIdsV13[setId]
    if (!unit)
        return false
    ctx := {pid:DllCall("GetProcessId","Ptr",h,"UInt"), h:h}
    name := SigSetNameV227(ctx,{unit:unit, uid:D2ReadU32(h,unit+0x0C), cls:cls, data:itemData})
    isAngelic := InStr(name,"Angelic",false) > 0
    if (setId)
        pickupAngelicSetIdsV13[setId] := isAngelic
    return isAngelic
}
PickupAutoGroupEnabledV7(group)
{
    global pickupAutoGroupsV7
    if (!IsObject(pickupAutoGroupsV7))
        UniquePickupReloadRAMV1()
    if (!IsObject(pickupAutoGroupsV7))
        return false
    if (pickupAutoGroupsV7.HasKey(group))
        return true
    for _,ancestor in PickupGroupParentChainV8(group)
        if (pickupAutoGroupsV7.HasKey(ancestor))
            return true
    return false
}

PickupGroupParentChainV8(group)
{
    if (UniqueKnownTierV4(group))
        return ["UNIQUE"]
    if (SubStr(group,1,4)="GEM_")
        return ["GEM"]
    if (SubStr(group,1,5)="RUNE_")
        return ["RUNE"]
    return []
}


PickupAutoGroupsRefreshV7()
{
    static lastStamp := ""
    file := UniquePickupFileV3()
    FileGetTime, stampTime, %file%, M
    FileGetSize, stampSize, %file%
    stamp := stampTime . "|" . stampSize
    if (stamp!=lastStamp)
    {
        UniquePickupReloadRAMV1()
        FileGetTime, stampTime, %file%, M
        FileGetSize, stampSize, %file%
        lastStamp := stampTime . "|" . stampSize
    }
}

ConsumableNamesPendingV7()
{
    global consumableNameJobsV7
    return (IsObject(consumableNameJobsV7) && consumableNameJobsV7.Count()>0) || PickupOptPendingV12()
}


PickupNameNormalizeV8(name)
{
    name := Trim(RegExReplace(RegExReplace(name,Chr(255) . "c.",""),"\s+"," "))
    StringLower, name, name
    return name
}

PickupNameMatchV8(name)
{
    global pickupAutoGroupsV7
    if (name="")
        return ""
    Loop, Parse, name, `n, `r
    {
        normalized := PickupNameNormalizeV8(A_LoopField)
        key := "NAME:" . normalized
        if (PickupAutoGroupEnabledV7(key))
            return key
    }
    patterns := PickupCatalogPatternsV9()
    plain := RegExReplace(name,Chr(255) . "c.","")
    for selector,_ in pickupAutoGroupsV7
    {
        if (SubStr(selector,1,7)!="FILTER:")
            continue
        filter := SubStr(selector,8)
        if (patterns.HasKey(filter) && RegExMatch(plain,"im)" . patterns[filter]))
            return selector
    }
    group := ConsumableKnownNameV7(name)
    if (group!="" && PickupAutoGroupEnabledV7(group))
        return group
    sub := PickupNamedSubtypeV8(name,group)
    return sub!="" && PickupAutoGroupEnabledV7(sub) ? sub : group
}

PickupNamedSubtypeV8(name,group)
{
    if (group="GEM")
    {
        Loop, Parse, name, `n, `r
        {
            line := PickupNameNormalizeV8(A_LoopField)
            if (ConsumableKnownNameV7(line)!="GEM")
                continue
            return RegExMatch(line,"^perfect ") ? "GEM_PERFECT" : (RegExMatch(line,"^flawless ") ? "GEM_FLAWLESS" : "GEM_NORMAL")
        }
    }
    if (group="RUNE")
    {
        enchanted := "Ol|Elq|Tyr|Nif|Xeth|Xith|Thal|Rhal|Urt|Tuul|Ahmn|Zol|Shaen|Doj|Hem|Iu|Lux|Ka|Fel|Lew|Phul|Un|Mhal|Yst|Gur|Vez|Ohn|Loz|Zur|Bur|Iah|Yham|Xod"
        Loop, Parse, name, `n, `r
        {
            line := PickupNameNormalizeV8(A_LoopField)
            if (ConsumableKnownNameV7(line)!="RUNE")
                continue
            if (RegExMatch(line,"i)^(?:Taha|Ghal|Qor|Great) Rune$"))
                return "RUNE_GREAT"
            if (RegExMatch(line,"i)^(?:Fire|Stone|Arcane|Poison|Light|Ice|Elemental) Rune$"))
                return "RUNE_ELEMENTAL"
            if (RegExMatch(line,"i)^(?:" . enchanted . "|Enchanted) Rune$"))
                return "RUNE_ENCHANTED"
            return "RUNE_NORMAL"
        }
    }
    return ""
}


PickupNoSigFileV490()
{
    return TxtRootPathV816("Item-Khong-Sig.txt")
}

PickupCanonicalDefaultsV491()
{
    return "Horadric Cube`r`nCharm`r`nUnique`r`nSet xanh`r`nMastercrafted`r`nRune`r`nGem`r`nShrine`r`nOil`r`nArcane`r`nCorrupted`r`nMaterial`r`nSignet`r`nCycle`r`nMystic Orb`r`nContainer`r`nRunestone`r`nEssence`r`nVessel`r`nEnchant Scroll`r`nEnchanting`r`nMystic Dye`r`nTreasure`r`nItem Design`r`nBelladonna Extract`r`nRiftstone`r`nScroll of Summoning`r`nRelic`r`nTrophy`r`nOccult Effigy`r`nEmblem`r`nQuest Item`r`nCube Reagent`r`n"
        . StrReplace(PickupCharmNamesV731(),"|","`r`n") . "`r`n"
}


PickupShortParseV638(line,ByRef name,ByRef cls,ByRef q)
{
    name := "",cls := 0,q := 0
    if (!RegExMatch(Trim(line),"i)^([^|]+)\|\s*(\d+)\s*\|\s*(0[1-9])\s*$",m))
        return false
    name := Trim(m1),cls := m2+0,q := ("0x" . m3)+0
    return name!="" && SubStr(name,1,1)!="#" && cls>0 && cls<65536 && q>=1 && q<=9
}

PickupLeftCategoryV638(line)
{
    if (PickupShortParseV638(line,label,cls,q))
        name := label
    else
        name := Trim(RegExReplace(line,"[\[{].*$","")," `t" . Chr(34))
    for _,parent in PickupCatalogParentChainV8(name)
    {
        ancestors := PickupCatalogParentChainV8(parent)
        return ancestors.Length() ? ancestors[ancestors.Length()] : parent
    }
    group := PickupAutoGroupParseV7(name)
    if (group="RUNE" || SubStr(group,1,5)="RUNE_")
        return "Rune"
    if (group="GEM" || SubStr(group,1,4)="GEM_")
        return "Gem"
    if (UniqueKnownTierV4(group) || group="UNIQUE")
        return "Unique"
    if (group="SET_XANH")
        return "Set xanh"
    for _,candidate in ["Horadric Cube","Charm","Mastercrafted","Rune","Gem","Shrine","Oil","Arcane","Corrupted","Material","Signet","Cycle","Mystic Orb","Container","Runestone","Essence","Vessel","Enchant Scroll","Enchanting","Mystic Dye","Treasure","Item Design","Belladonna Extract","Riftstone","Scroll of Summoning","Relic","Trophy","Occult Effigy","Emblem","Quest Item","Cube Reagent"]
    {
        if (PickupNameNormalizeV8(name)=PickupNameNormalizeV8(candidate))
            return candidate
        if (PickupAlertGroupMatchV14(PickupAutoGroupParseV7(candidate),0,"",false,name))
            return candidate
    }
    return "Angelic"
}


PickupNameIndexPutV638(index,name,cls,q)
{
    name := PickupNameNormalizeV8(name)
    if (name="" || cls<1 || q<1 || q>9)
        return
    identity := cls . "|" . Format("{:02X}",q)
    if (!index.HasKey(name))
        index[name] := identity
    else if (index[name]!=identity)
        index[name] := ""
}

PickupNameIndexV638()
{
    global pickupOptCacheV12,consumableClassRAMV7
    index := {},pid := D2GetActiveGamePidV95(),h := pid ? D2OpenProcess(pid) : 0
    if (!h)
        return index
    try
    {
        PickupOptPollV12()
        player := D2ReadU32(h,D2GetModuleBaseV35(pid,"D2Client.dll")+0x11BBFC)
        inv := player ? D2ReadU32(h,player+0x60) : 0
        if (inv)
        {
            ctx := {pid:pid,h:h,player:player,inv:inv,first:D2ReadU32(h,inv+0x10)}
            for uid,item in V9SnapshotAllItems(ctx)
            {
                q := D2ReadU8V18(h,item.data),key := pid . "|" . item.cls
                if (IsObject(consumableClassRAMV7) && consumableClassRAMV7.HasKey(key))
                    PickupNameIndexPutV638(index,consumableClassRAMV7[key],item.cls,q)
            }
        }
        for cacheKey,info in pickupOptCacheV12
        {
            if (!info.ok || info.pid!=pid)
                continue
            fields := StrSplit(cacheKey,"|"),unit := fields[2]+0,data := fields[4]+0
            if (D2ReadU32(h,unit)!=4 || D2ReadU32(h,unit+0x0C)!=info.uid
                || D2ReadU32(h,unit+0x14)!=data || D2ReadU32(h,data+0x14)!=fields[5]+0)
                continue
            cls := D2ReadU32(h,unit+4),q := D2ReadU8V18(h,data)
            PickupNameIndexPutV638(index,PickupGetNameV638(info.name),cls,q)
            key := pid . "|" . cls
            if (IsObject(consumableClassRAMV7) && consumableClassRAMV7.HasKey(key))
                PickupNameIndexPutV638(index,consumableClassRAMV7[key],cls,q)
        }
    }
    finally
        DllCall("CloseHandle","Ptr",h)
    return index
}

PickupUpgradeNamesV638(raw,index)
{
    result := ""
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField),group := PickupAutoGroupParseV7(line)
        key := PickupNameNormalizeV8(line)
        if (SubStr(group,1,5)="NAME:" && !PickupOptIsRuleV12(line)
            && !PickupShortParseV638(line,label,cls,q) && index.HasKey(key) && index[key]!="")
            line .= "|" . index[key]
        if (line!="")
            result .= line . "`r`n"
    }
    return PickupEditorDedupV10(result,removed)
}
PickupUniqueStringNameV766(h,pid,itemData)
{
    fileIndex := D2ReadU32(h,itemData+0x28)
    common := D2GetModuleBaseV35(pid,"D2Common.dll")
    if (!common)
        return ""
    sgpt := D2ReadU32(h,common+0x99E1C)
    if (!sgpt)
        return ""
    tablePtr := D2ReadU32(h,sgpt+0xC24)
    tableCount := D2ReadU32(h,sgpt+0xC28)
    if (!tablePtr || fileIndex>=tableCount)
        return ""
    record := tablePtr+fileIndex*0x14C
    if (D2ReadU16(h,record)!=fileIndex)
        return ""
    stringId := D2ReadU16(h,record+2)
    if (!stringId || stringId=65535)
        return ""
    lang := D2GetModuleBaseV35(pid,"D2Lang.dll")
    if (!lang)
        return ""
    job := ConsumableNameStartV7(pid,lang+0x9450,stringId)
    if (!IsObject(job))
        return ""
    started := A_TickCount
    while (DllCall("WaitForSingleObject","Ptr",job.th,"UInt",0)!=0)
    {
        if (A_TickCount-started>2000)
        {
            DllCall("CloseHandle","Ptr",job.th)
            DllCall("CloseHandle","Ptr",job.hp)
            return ""
        }
        Sleep, 20
    }
    ptr := 0,name := ""
    if (DllCall("GetExitCodeThread","Ptr",job.th,"UInt*",ptr) && ptr)
        name := PickupOptCleanTextV12(PickupOptReadWideV12(job.hp,ptr,512))
    DllCall("VirtualFreeEx","Ptr",job.hp,"Ptr",job.remote,"UPtr",0,"UInt",0x8000)
    DllCall("CloseHandle","Ptr",job.th)
    DllCall("CloseHandle","Ptr",job.hp)
    return Trim(name)
}
PickupGetNameV638(raw,statsRaw:="")
{
    raw := RegExReplace(raw,Chr(255) . "c.","")
    if (statsRaw!="")
    {
        statsRaw := RegExReplace(statsRaw,Chr(255) . "c.","")
        baseName := ""
        Loop, Parse, raw, `n, `r
            if (Trim(A_LoopField)!="")
            {
                baseName := Trim(A_LoopField)
                break
            }
        for _,line in StrSplit(statsRaw,"`n")
        {
            line := Trim(line)
            if (line="" || InStr(line,baseName) || RegExMatch(line,"^[+-]|^\d|^[A-Za-z ]+:\s"))
                continue
            if (!RegExMatch(line,"^(?:\+|-)") && !RegExMatch(line,"^\d"))
                return StrReplace(line,"|","/")
        }
    }
    Loop, Parse, raw, `n, `r
        if (Trim(A_LoopField)!="")
            return StrReplace(Trim(A_LoopField),"|","/")
    return ""
}

PickupEditorGetV638()
{
    global pickupGetTargetV638,sigBusyV147,xRunning,zRunning
    target := pickupGetTargetV638
    GuiControlGet, tab, 1:, AutoGSFMainTabs
    if (tab!=4 || (target!="PickupEditorInputV8" && target!="PickupNoSigEditorV490"))
        return false
    if (sigBusyV147 || xRunning || zRunning)
        return true
    pid := D2GetActiveGamePidV95(),base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return true
    message := "GET: rê chuột lên đúng vật phẩm rồi bấm lại."
    try
    {
        MouseGetPos,,,hoverWindow
        WinGet, hoverPid, PID, ahk_id %hoverWindow%
        unit := hoverPid=pid ? D2ReadU32(h,base+0x11B834) : 0
        if (unit && D2ReadU32(h,unit)=4)
        {
            uid := D2ReadU32(h,unit+0x0C),cls := D2ReadU32(h,unit+4),data := D2ReadU32(h,unit+0x14)
            q := D2ReadU8V18(h,data),seed := D2ReadU32(h,data+0x14),started := A_TickCount
            if (uid && cls>0 && q>=1 && q<=9)
            {
                Loop
                {
                    if (D2GetActiveGamePidV95()!=pid || D2ReadU32(h,unit+0x0C)!=uid
                        || D2ReadU32(h,unit+0x14)!=data || D2ReadU32(h,data+0x14)!=seed)
                        break
                    PickupOptPollV12()
                    info := PickupOptReadV12(h,unit,cls,q,data,D2ReadU32(h,data+0x18))
                    if (IsObject(info) && info.ok)
                    {
                        name := PickupGetNameV638(info.name, info.stats)
                                    if (q=7)
            {
                un := PickupUniqueStringNameV766(h,pid,data)
                if (un!="")
                    name := un
            }
            else if (q=5)
            {
                tmpCtx := {h:h,pid:pid,setNoSigNamesV227:[],setNameCacheV227:{},setKeepLoggedV227:{}}
                sn := SigSetNameV227(tmpCtx,{unit:unit,uid:uid,cls:cls,data:data})
                if (sn!="")
                    name := sn
            }
						if (name!="")
                        {
                            row := name . "|" . cls . "|" . Format("{:02X}",q)
                            if (target="PickupEditorInputV8")
                                added := PickupEditorInsertV574(row)
                            else
                                added := PickupKeepInsertV638(row)
                            message := added ? "GET: " . row . " — bấm Lưu để áp dụng." : "GET: món này đã có trong mục đang chọn."
                            break
                        }
                    }
                    if (A_TickCount-started>=3000)
                    {
                        message := "GET: chưa đọc được tên món, chưa thêm; bấm lại."
                        break
                    }
                    Sleep, 30
                }
            }
        }
    }
    finally
        DllCall("CloseHandle","Ptr",h)
    ToolTipInfoV386(message)
    SetTimer, RemoveToolTip, -2500
    return true
}

PickupKeepInsertV638(row)
{
    GuiControlGet, raw, 1:, PickupNoSigEditorV490
    if (PickupEditorHasV10(raw,row))
        return false
    GuiControlGet, edit, 1:Hwnd, PickupNoSigEditorV490
    start := 0,finish := 0
    DllCall("SendMessage","Ptr",edit,"UInt",0xB0,"UIntP",start,"UIntP",finish,"Ptr")
    prefix := SubStr(raw,1,start)
    text := (start>0 && SubStr(prefix,0)!="`n" ? "`r`n" : "") . row . "`r`n"
    DllCall("SendMessage","Ptr",edit,"UInt",0xC2,"Ptr",1,"Str",text,"Ptr")
    return true
}

PickupCanonicalParseV491(raw)
{
    result := {add:"",input:"",left:"",exclude:"",cube:"",store:"",keep:"",canonical:false}
    section := "INPUT"
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField," `t`r`n" . Chr(0xFEFF))
        if (SubStr(line,1,1)="#" && InStr(line, "==="))
        {
            if (InStr(line,"Nhặt Thêm") || InStr(line,"Nhặt hết") || InStr(line,"Nhập Để Thêm"))
                section := "INPUT", result.canonical := true
            else if (InStr(line,"Chuyển Charm Vào Cube") || InStr(line,"Chuyển Cube"))
                section := "CUBE", result.canonical := true
            else if (InStr(line,"Chuyển Vào Kho"))
                section := "STORE", result.canonical := true
            else if (InStr(line,"Không Nhặt"))
                section := "EXCLUDE", result.canonical := true
            continue
        }
        line := Trim(RegExReplace(line,"\s*;.*$",""))
        if (line="")
            continue
            
        if (section="INPUT")
            result.input .= line . "`r`n"
        else if (section="STORE")
            result.store .= line . "`r`n"
        else if (section="EXCLUDE")
            result.exclude .= line . "`r`n"
        else if (section="CUBE")
            result.cube .= Trim(RegExReplace(line,"i)\[\s*cube\s*\]","")) . "`r`n"
    }
    
    result.left := result.input
    result.add := "" 
    result.input := PickupEditorDedupV10(result.input, removed)
    result.cube := PickupEditorDedupV10(result.cube, removed)
    result.store := PickupEditorDedupV10(result.store, removed)
    result.exclude := PickupExcludeNormalizeV717(result.exclude)
    return result
}

PickupCanonicalTextV491(add := "",excluded := "",cube := "",store := "",inputText := "")
{
    if (inputText="")
        inputText := add
        
    return "#=== Nhặt Thêm ===`r`n" . Rtrim(inputText,"`r`n") . (inputText!="" ? "`r`n" : "")
        . "`r`n#=== Chuyển Charm Vào Cube`r`n" . Rtrim(cube,"`r`n") . (cube!="" ? "`r`n" : "")
        . "`r`n#=== Chuyển Vào Kho (Cất Tiền)`r`n" . Rtrim(store,"`r`n") . (store!="" ? "`r`n" : "")
        . "`r`n#=== Không Nhặt`r`n" . Rtrim(excluded,"`r`n") . (excluded!="" ? "`r`n" : "")
}

PickupCubeRulesTextV574(raw)
{
    text := ""
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField)
        if (line!="" && SubStr(line,1,1)!="#")
            text .= line . " [cube]`r`n"
    }
    return text
}

PickupCanonicalAllowTextV491(raw)
{
    parts := PickupCanonicalParseV491(raw)
    return parts.canonical ? parts.left . parts.add . parts.store . PickupCubeRulesTextV574(parts.cube) : raw . "`r`nCharm`r`n"
}

PickupExcludeNormalizeV717(raw)
{
    seen := {},out := ""
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField," `t`r`n" . Chr(0xFEFF))
        if (line="" || (RegExMatch(line,"^#={3,}") && InStr(line,"Không Nhặt")))
            continue
        if (PickupExcludeLineClassV57(line,excludeClsV57))
        {
            key := "CLASS:" . excludeClsV57
            ; Dong cu chi luu KIND va ADDED, KHONG luu quality.
            ; Chuyen ve ten|class, khong tu dat mot quality gia.
            if (RegExMatch(line,"i)^CLASS\s*=\s*\d+",legacyV57)
                && RegExMatch(line,"i)(?:^|\|)\s*NAME\s*=\s*([^|]+)",nameV57))
                line := Trim(nameV571) . "|" . excludeClsV57
            else if (RegExMatch(line,"i)^CLASS\s*=\s*\d+",legacyV57))
                line := "CLASS=" . excludeClsV57
        }
        else
        {
            key := RegExReplace(line,"[ \t]+"," ")
            StringLower, key, key
            key := "LINE:" . key
        }
        if (seen.HasKey(key))
            continue
        seen[key] := true
        out .= line . "`r`n"
    }
    return out
}

PickupExcludeSectionTextV663(raw,excluded,fromExisting := false)
{
    if (fromExisting)
    {
        excluded := "",active := false,found := false
        Loop, Parse, raw, `n, `r
        {
            line := Trim(A_LoopField," `t`r`n" . Chr(0xFEFF))
            if (RegExMatch(line,"^#={3,}"))
            {
                active := InStr(line,"Không Nhặt") ? true : false
                found := found || active
                continue
            }
            if (active)
                excluded .= A_LoopField . "`r`n"
        }
        if (!found)
            return raw
    }
    body := PickupExcludeNormalizeV717(excluded)
    pattern := "m)(*ANYCRLF)^[ \t]*#={3,}[^\r\n]*(?:\r\n|\n|\r|$)"
    pos := 1,cursor := 1,out := "",inserted := false
    while (headerPos := RegExMatch(raw,pattern,header,pos))
    {
        bodyStart := headerPos+StrLen(header)
        nextPos := RegExMatch(raw,pattern,nextHeader,bodyStart)
        if (InStr(header,"Không Nhặt"))
        {
            out .= SubStr(raw,cursor,headerPos-cursor)
            if (!inserted)
            {
                out .= "#=== Không Nhặt`r`n" . body . (nextPos ? "`r`n" : "")
                inserted := true
            }
            cursor := nextPos ? nextPos : StrLen(raw)+1
        }
        if (!nextPos)
            break
        pos := nextPos
    }
    out .= SubStr(raw,cursor)
    if (!inserted && fromExisting)
        return raw
    if (!inserted)
        out .= (out!="" && SubStr(out,0)!="`n" ? "`r`n" : "")
            . "`r`n#=== Không Nhặt`r`n" . body
    return out
}

PickupCanonicalExcludeSyncV491()
{
    file := UniquePickupFileV3(),excludeFile := PickupExcludeFileV329()
    if (!FileExist(file) || !RareWarningReadTextV35(file,raw,false))
        return false
    if (!PickupCanonicalParseV491(raw).canonical || !RareWarningReadTextV35(excludeFile,excluded,false))
        return false
    normalized := PickupExcludeNormalizeV717(excluded)
    if (normalized!=excluded && !RareWarningWriteTextV35(excludeFile,normalized))
        return false
    changed := PickupExcludeSectionTextV663(raw,normalized)
    if (changed!=raw && !RareWarningWriteTextV35(file,changed))
        return false
    if (ProfileControlExistsV365("PickupEditorInputV8"))
    {
        GuiControlGet, editorRaw, 1:, PickupEditorInputV8
        editorChanged := PickupExcludeSectionTextV663(editorRaw,normalized)
        if (editorChanged!=editorRaw)
            GuiControl, 1:, PickupEditorInputV8, %editorChanged%
    }
    return true
}


PickupCatalogCustomV490()
{
    global pickupCatalogNamesV11
    if (!RareWarningReadTextV35(UniquePickupFileV3(),raw,true))
        return
    parts := PickupCanonicalParseV491(raw),rules := parts.left . parts.add
    roots := {},known := {},used := {},angelicRows := [],defaultRoots := {}
    for node,name in pickupCatalogNamesV11
    {
        known[PickupNameNormalizeV8(name)] := node
        if (!TV_GetParent(node))
        {
            roots[PickupNameNormalizeV8(name)] := node
            defaultRoots[PickupNameNormalizeV8(name)] := true
        }
    }
    Loop, Parse, rules, `n, `r
    {
        line := Trim(A_LoopField)
        if (line="" || SubStr(line,1,1)="#")
            continue
        groupName := PickupLeftCategoryV638(line),key := PickupNameNormalizeV8(groupName)
        if (key="angelic")
        {
            angelicRows.Push(line)
            continue
        }
        if (!roots.HasKey(key))
            roots[key] := PickupCatalogNodeV11(groupName,0,false)
        used[key] := true
        display := line
        if (PickupShortParseV638(line,label,cls,q))
            display := label
        if (!known.HasKey(PickupNameNormalizeV8(display)))
            PickupCatalogNodeV11(line,roots[key],false)
    }
    for key,node in roots
        if (!used.HasKey(key) && !defaultRoots.HasKey(key))
        {
            remove := []
            for child,_ in pickupCatalogNamesV11
            {
                p := child
                while (p && p!=node)
                    p := TV_GetParent(p)
                if (p=node)
                    remove.Push(child)
            }
            for _,child in remove
                pickupCatalogNamesV11.Delete(child)
            TV_Delete(node)
        }
        
    angelicKey := PickupNameNormalizeV8("Angelic")
    if (!roots.HasKey(angelicKey))
    {
        angelicRoot := PickupCatalogNodeV11("Angelic",0,false)
        roots[angelicKey] := angelicRoot
    }
    else
        angelicRoot := roots[angelicKey]
    for _,line in angelicRows
        if (PickupNameNormalizeV8(line)!="angelic")
            PickupCatalogNodeV11(line,angelicRoot,false)
}

PickupSplitInitV490()
{
    global pickupExcludeTextV490,pickupNoSigTextV490
    if (!UniquePickupCleanDuplicateV19())
        return false
    source := UniquePickupFileV3()
    if (!RareWarningReadTextV35(source,raw,false))
        return false
    parts := PickupCanonicalParseV491(raw)
    if (!FileExist(PickupNoSigFileV490()))
        if (!RareWarningWriteTextV35(PickupNoSigFileV490(),parts.keep))
            return false
    if (!RareWarningReadTextV35(PickupNoSigFileV490(),pickupNoSigTextV490,false))
        return false
    if (!FileExist(PickupExcludeFileV329()))
        if (!RareWarningWriteTextV35(PickupExcludeFileV329(),parts.exclude))
            return false
    pickupExcludeTextV490 := parts.exclude
    PickupExcludeLoadV329(),PickupNoSigLoadV490(),UniquePickupReloadRAMV1()
    PickupCatalogBuildV8()
    return true
}

PickupHeadersEnsureV684(raw)
{
    found := {}
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField," `t`r`n" . Chr(0xFEFF))
        if (SubStr(line,1,1)!="#" || !InStr(line,"==="))
            continue
        if (InStr(line,"Nhặt Thêm") || InStr(line,"Nhặt hết") || InStr(line,"Nhập Để Thêm"))
            found.input := true
        else if (InStr(line,"Chuyển Charm Vào Cube") || InStr(line,"Chuyển Cube"))
            found.cube := true
        else if (InStr(line,"Chuyển Vào Kho"))
            found.store := true
        else if (InStr(line,"Không Nhặt"))
            found.exclude := true
    }
    if (!found.input)
        raw := "#=== Nhặt Thêm ===`r`n`r`n" . raw
    for _,section in [{key:"cube",title:"Chuyển Charm Vào Cube"}
        ,{key:"store",title:"Chuyển Vào Kho (Cất Tiền)"},{key:"exclude",title:"Không Nhặt"}]
        if (!found[section.key])
            raw .= (raw!="" && SubStr(raw,0)!="`n" ? "`r`n" : "")
                . "`r`n#=== " . section.title . "`r`n`r`n"
    return raw
}

PickupSplitSaveV490()
{
    GuiControlGet, raw, 1:, PickupEditorInputV8
    raw := PickupHeadersEnsureV684(raw)
    GuiControlGet, keep, 1:, PickupNoSigEditorV490
    parts := PickupCanonicalParseV491(raw)
    if (parts.keep!="")
        keep := PickupEditorDedupV10(keep . "`r`n" . parts.keep,removed)
    
    inputList := PickupEditorDedupV10(parts.input, removed)
    
    index := PickupNameIndexV638()
    parts.cube := PickupUpgradeNamesV638(parts.cube,index)
    parts.store := PickupUpgradeNamesV638(parts.store,index)
    parts.exclude := PickupExcludeNormalizeV717(PickupUpgradeNamesV638(parts.exclude,index))
    raw := PickupExcludeSectionTextV663(raw,parts.exclude)
    keep := PickupUpgradeNamesV638(keep,index)
    inputList := PickupUpgradeNamesV638(inputList,index)
    
    if (!PickupOptValidateTextV12(inputList,error) || !PickupOptValidateTextV12(parts.store,error)
        || !PickupOptValidateTextV12(PickupCubeRulesTextV574(parts.cube),error)
        || !PickupSplitValidateV490(parts.exclude,error)
        || !PickupSplitValidateV490(keep,error,true))
    {
        GuiControl, 1:Show, PickupEditorStatusV8
        GuiControl, 1:, PickupEditorStatusV8, %error%
        return false
    }
    
    if (!RareWarningWriteTextV35(PickupExcludeFileV329(),parts.exclude)
        || !RareWarningWriteTextV35(PickupNoSigFileV490(),keep)
        || !RareWarningWriteTextV35(UniquePickupFileV3(),raw))
    {
        GuiControl, 1:Show, PickupEditorStatusV8
        GuiControl, 1:, PickupEditorStatusV8, Không lưu được danh sách; giữ bản nhập để thử lại.
        return false
    }
    
    PickupExcludeLoadV329(),PickupNoSigLoadV490(),UniquePickupReloadRAMV1()
    PickupCatalogBuildV8()
    GuiControl, 1:, PickupEditorInputV8, % PickupEditorReadV8()
    GuiControl, 1:, PickupNoSigEditorV490, %keep%
    GuiControl, 1:Hide, PickupEditorStatusV8
    return true
}

PickupSplitValidateV490(raw,ByRef error,noSig := false)
{
    error := ""
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField)
        if (line="" || SubStr(line,1,1)="#"
            || (!noSig && PickupExcludeLineClassV57(line,classV57))
            || RegExMatch(line,"i)^CLASS\s*=\s*\d+"))
            continue
        parsed := noSig ? SetNoSigParseV227(line) : false
        if (IsObject(parsed))
            continue
        if (!IsObject(PickupOptParseV12(line,why)))
        {
            error := (noSig ? "Không SIG" : "Không nhặt") . " dòng " . A_Index . ": " . why
            return false
        }
    }
    return true
}

PickupNoSigLoadV490()
{
    global pickupNoSigRulesV490,pickupNoSigClassesV490,pickupOptRevisionV12
    pickupNoSigRulesV490 := [],pickupNoSigClassesV490 := {}
    if (RareWarningReadTextV35(PickupNoSigFileV490(),raw,true))
        Loop, Parse, raw, `n, `r
        {
            line := Trim(A_LoopField)
            if (line="" || SubStr(line,1,1)="#" || IsObject(SetNoSigParseV227(line)))
                continue
            if (RegExMatch(line,"i)^CLASS\s*=\s*(\d+)",m))
                pickupNoSigClassesV490[m1+0] := true
            else if (IsObject(rule := PickupOptParseV12(line,error)))
                pickupNoSigRulesV490.Push(rule)
        }
    pickupOptRevisionV12++
}

PickupRuleListMatchV490(rules,h,unit,cls,q,data,ByRef ready)
{
    global consumableClassRAMV7
    ready := true
    if (!IsObject(rules) || !rules.Length())
        return false
    if (!unit || !h || !data)
    {
        ready := false
        return false
    }
    needsNameV638 := false
    for _,rule in rules
        if (rule.HasKey("exactClassV638"))
        {
            if (PickupOptRuleMatchV12(rule,q,0,"","","",h,cls))
                return true
        }
        else
            needsNameV638 := true
    if (!needsNameV638)
        return false
    PickupOptPollV12()
    flags := D2ReadU32(h,data+0x18)
    info := PickupOptReadV12(h,unit,cls,q,data,flags)
    if (!IsObject(info) || !info.ok)
    {
        ready := false
        return false
    }
    ConsumablePickupGroupV7(h,cls)
    classKeyV499 := info.pid . "|" . cls
    baseNameV499 := IsObject(consumableClassRAMV7) && consumableClassRAMV7.HasKey(classKeyV499) ? consumableClassRAMV7[classKeyV499] : ""
    for _,rule in rules
        if (PickupOptRuleMatchV12(rule,q,flags,info.name,info.stats,baseNameV499,h,cls))
            return true
    return false
}

PickupExcludeGroupMatchV491(h,cls,q,data)
{
    global pickupExcludeGroupsV491,consumableClassRAMV7
    groups := pickupExcludeGroupsV491
    if (!IsObject(groups) || !groups.Count())
        return false
    if (groups.HasKey("CHARM") && PickupIsCharmV571(h,cls))
        return true
    if (q+0=5 && groups.HasKey("SET_XANH"))
        return true
    if (q+0=7 && groups.HasKey("UNIQUE"))
        return true
    if (q+0=7 && data && h)
    {
        tier := UniqueItemsTierFromLiveTableV1(h,D2ReadU32(h,data+0x28),wlvl)
        if (groups.HasKey(tier))
            return true
    }
    group := ConsumablePickupGroupV7(h,cls)
    if (groups.HasKey(group))
        return true
    for _,parent in PickupGroupParentChainV8(group)
        if (groups.HasKey(parent))
            return true
    pid := h ? DllCall("GetProcessId","Ptr",h,"UInt") : 0
    keyV499 := pid . "|" . cls
    if (!pid || !IsObject(consumableClassRAMV7) || !consumableClassRAMV7.HasKey(keyV499))
        return true
    nameV499 := consumableClassRAMV7[keyV499]
    for excludedGroupV499,_ in groups
        if (PickupAlertGroupMatchV14(excludedGroupV499,q,"",q+0=5,nameV499))
            return true
    return false
}

PickupExcludedByNameV490(h,unit,cls,q,data)
{
    global pickupExcludeRulesV490
    if (PickupExcludeGroupMatchV491(h,cls,q,data))
        return true
    hit := PickupRuleListMatchV490(pickupExcludeRulesV490,h,unit,cls,q,data,ready)
    return hit || !ready
}

PickupNoSigMatchV490(ctx,item,q)
{
    global pickupNoSigRulesV490,pickupNoSigClassesV490,consumableClassRAMV7
    classKeepV981 := IsObject(pickupNoSigClassesV490) && pickupNoSigClassesV490.HasKey(item.cls)
    specificPresentV981 := false
    if (IsObject(pickupNoSigRulesV490))
        for _,ruleV981 in pickupNoSigRulesV490
            if (!ruleV981.HasKey("exactClassV638")
                && (ruleV981.stats.Length() || ruleV981.qualities.Count()
                    || ruleV981.tiers.Count() || ruleV981.eth))
                specificPresentV981 := true

    ; V981: ten + OPT trong ds KHONG SIG phai duoc xet TRUOC whitelist CLASS.
    ; Vi du: Angel of Death [2] [30%] [15%] - sai 1 opt thi SIG ngay,
    ; khong duoc giu lai boi CLASS chung hay rule theo ten khong co OPT.
    if (specificPresentV981)
    {
        startedV981 := A_TickCount
        Loop
        {
            PickupOptPollV12()
            flagsV981 := D2ReadU32(ctx.h,item.data+0x18)
            infoV981 := PickupOptReadV12(ctx.h,item.unit,item.cls,q,item.data,flagsV981)
            if (IsObject(infoV981) && infoV981.ok)
            {
                classKeyV981 := infoV981.pid . "|" . item.cls
                baseNameV981 := IsObject(consumableClassRAMV7) && consumableClassRAMV7.HasKey(classKeyV981)
                    ? consumableClassRAMV7[classKeyV981] : ""
                namedSpecificV981 := false,matchingSpecificV981 := false
                for _,ruleV981 in pickupNoSigRulesV490
                {
                    if (ruleV981.HasKey("exactClassV638")
                        || (!ruleV981.stats.Length() && !ruleV981.qualities.Count()
                            && !ruleV981.tiers.Count() && !ruleV981.eth))
                        continue
                    if (!RegExMatch(infoV981.name . "`n" . baseNameV981,"im)" . ruleV981.name))
                        continue
                    namedSpecificV981 := true
                    if (PickupOptRuleMatchV12(ruleV981,q,flagsV981,infoV981.name
                        ,infoV981.stats,baseNameV981,ctx.h,item.cls))
                        matchingSpecificV981 := true
                }
                if (namedSpecificV981)
                {
                    SigLogV147("SIG_NO_SIG_OPTS uid=" . item.uid . " class=" . item.cls
                        . " name=" . StrReplace(infoV981.name,"`n"," | ")
                        . " match=" . matchingSpecificV981
                        . " action=" . (matchingSpecificV981 ? "KEEP" : "SIG"))
                    return matchingSpecificV981
                }
                break
            }
            ; Khong SIG neu chua doc duoc ten/OPT - khong suy doan sai.
            if (A_TickCount-startedV981>3000)
                return true
            Sleep, 50
        }
    }
    if (classKeepV981)
    {
        SigLogV147("SIG_KEEP_CLASS uid=" . item.uid . " class=" . item.cls . " reason=NO_SIG_CLASS_RULE")
        return true
    }
    started := A_TickCount
    Loop
    {
        hit := PickupRuleListMatchV490(pickupNoSigRulesV490,ctx.h,item.unit,item.cls,q,item.data,ready)
        if (ready)
            return hit
        if (A_TickCount-started > 3000)
            return true
        PickupOptPollV12()
        Sleep, 50
    }
}
PickupEditorReadV8()
{
    if (!UniquePickupCleanDuplicateV19() || !RareWarningReadTextV35(UniquePickupFileV3(),raw,false))
        return ""
    return raw
}

PickupCharmNamesV731()
{
    return "The Butcher's Tooth|Riftwalker's Eye|Laser Focus Crystal|Optical Detector|Scroll of Kings|Horazon's Focus|Visions of Akarat"
        . "|Sacred Worldstone Key|Moon of the Spider|Fool's Gold|Spirit Trance Herb|The Black Road|Legacy of Blood|Idol of Vanity"
        . "|Azmodan's Heart|Crystalline Flame Medallion|Weather Control|Silver Seal of Ureh|Eternal Bone Pile|Soul of Kabraxis|Lylia's Curse"
        . "|Spirit of Creation|The Book of Lies|Dragon Claw|The Ancient Repositories|Xazax's Illusion|Astrogha's Venom Stinger|The Sleep"
        . "|Books of Kalan|Neutrality Pact|The Glorious Book of Median|Vial of Elder Blood|Essence of Time|Dulra Fruit|Paragon's Hammer"
        . "|Six Angel Bag|Zakarum's Ear|Sunstone of the Gods|Umbaru Treasure|Corrupted Wormhole|Demonsbane|Cold Fusion Schematics"
        . "|Dimensional Key|Sunstone of the Twin Seas|Sacred Sunstone|Shadow Vortex|Worldstone Orb|Caoi Dulra Fruit|Soulstone Shard"
        . "|Eye of Divinity|Nexus Crystal|Dúlra Aegis"
}

PickupCatalogBuildV8()
{
    global pickupCatalogNamesV11,pickupDefaultCatalogV490
    Gui, TreeView, PickupCatalogV8
    TV_Delete()
    pickupCatalogNamesV11 := {}
    PickupCatalogNodeV11("Horadric Cube")
    charmRootV573 := PickupCatalogNodeV11("Charm")
    PickupCatalogNodeV11("Relic",charmRootV573,false)
    for _,name in StrSplit(PickupCharmNamesV731(),"|")
        PickupCatalogNodeV11(name,charmRootV573,false)
    root := PickupCatalogNodeV11("Unique")
    for _,tier in ["TU","SU","SSU","SSSU"]
        PickupCatalogNodeV11(tier,root)
    PickupCatalogNodeV11("Set xanh")
    PickupCatalogNodeV11("Mastercrafted")
    root := PickupCatalogNodeV11("Rune")
    runeSets := [{name:"Rune thường",names:"El|Eld|Tir|Nef|Eth|Ith|Tal|Ral|Ort|Thul|Amn|Sol|Shael|Dol|Hel|Io|Lum|Ko|Fal|Lem|Pul|Um|Mal|Ist|Gul|Vex|Ohm|Lo|Sur|Ber|Jah|Cham|Zod"}
        ,{name:"Rune Enchanted",names:"Ol|Elq|Tyr|Nif|Xeth|Xith|Thal|Rhal|Urt|Tuul|Ahmn|Zol|Shaen|Doj|Hem|Iu|Lux|Ka|Fel|Lew|Phul|Un|Mhal|Yst|Gur|Vez|Ohn|Loz|Zur|Bur|Iah|Yham|Xod"}
        ,{name:"Rune Great",names:"Taha|Ghal|Qor"},{name:"Rune Elemental",names:"Fire|Stone|Arcane|Poison|Light|Ice"}]
    for _,set in runeSets
    {
        branch := PickupCatalogNodeV11(set.name,root,false)
        Loop, Parse, % set.names, |
            PickupCatalogNodeV11(A_LoopField . " Rune",branch,false)
    }
    root := PickupCatalogNodeV11("Gem")
    gems := "Diamond|Amethyst|Ruby|Topaz|Bloodstone|Onyx|Amber|Turquoise|Sapphire|Emerald|Rainbow Stone|Skull"
    for _,set in [{name:"Gem thường",prefix:""},{name:"Gem Flawless",prefix:"Flawless "},{name:"Gem Perfect",prefix:"Perfect "}]
    {
        branch := PickupCatalogNodeV11(set.name,root,false)
        Loop, Parse, gems, |
            PickupCatalogNodeV11(set.prefix . A_LoopField,branch,false)
    }
    root := PickupCatalogNodeV11("Shrine")
    PickupCatalogNodeV11("Shrine (10)",root,false)
    shrines := "Abandoned|Creepy|Eerie|Enchanted|Fascinating|Hidden|Intimidating|Magical|Ornate|Quiet|Sacred|Shimmering|Spiritual|Tainted|Trinity|Weird"
    Loop, Parse, shrines, |
        PickupCatalogNodeV11(A_LoopField . " Shrine",root,false)
    root := PickupCatalogNodeV11("Oil")
    for _,name in ["Oil of Augmentation","Oil of Conjuration","Oil of Greater Luck","Oil of Intensity"]
        PickupCatalogNodeV11(name,root,false)
    for _,group in ["Arcane","Corrupted"]
    {
        root := PickupCatalogNodeV11(group)
        for _,suffix in ["Shard","Crystal","Cluster"]
            PickupCatalogNodeV11(group . " " . suffix,root,false)
    }
    root := PickupCatalogNodeV11("Material")
    for _,name in ["Sacred Essence","Heavenly Soul","Mark of Infusion","Crate O' Souls","Crate O' Sacred Essence"]
        PickupCatalogNodeV11(name,root,false)
    root := PickupCatalogNodeV11("Signet")
    for _,name in ["Signet of Learning","Greater Signet of Learning","Large Signet of Learning","Custom Signet"]
        PickupCatalogNodeV11(name,root,false)
    root := PickupCatalogNodeV11("Cycle")
    for _,name in ["Small Cycle","Medium Cycle","Large Cycle","Golden Cycle"]
        PickupCatalogNodeV11(name,root,false)
    for _,name in ["Mystic Orb","Container","Essence","Vessel","Enchant Scroll","Enchanting","Mystic Dye","Treasure","Item Design","Belladonna Extract","Riftstone","Scroll of Summoning","Trophy","Occult Effigy","Emblem","Quest Item","Cube Reagent"]
        PickupCatalogNodeV11(name)
    pickupDefaultCatalogV490 := ""
    for node,name in pickupCatalogNamesV11
        if (!TV_GetParent(node))
            pickupDefaultCatalogV490 .= name . "`r`n"
    pickupDefaultCatalogV490 .= "Relic`r`nRunestone`r`n"
    PickupCatalogCustomV490()
    for node,_ in pickupCatalogNamesV11
        TV_Modify(node,"Sort -Expand")
    PickupCatalogArrangeV638()
}

PickupCatalogNodeV11(name,parent:=0,expand:=false)
{
    global pickupCatalogNamesV11
    node := TV_Add(name,parent,expand ? "Expand" : "")
    pickupCatalogNamesV11[node] := name
    return node
}


PickupCatalogPatternsV9()
{
    static patterns := ""
    if (!IsObject(patterns))
        patterns := {"mastercrafted":"\(Mastercrafted\)","mystic orb":"Mystic Orb","container":"Container","runestone":"Runestone","essence":"Essence","vessel":"Vessel","enchant scroll":"Enchant Scroll","enchanting":"Enchanting","mystic dye":"Mystic Dye","treasure":"Treasure","item design":"Item Design","belladonna extract":"Belladonna Extract","riftstone":"Riftstone","scroll of summoning":"Scroll of Summoning","relic":"Relic","trophy":"Trophy","occult effigy":"Occult Effigy","emblem":"Emblem of","cycle":"Cycle","small cycle":"Small Cycle","medium cycle":"Medium Cycle","large cycle":"Large Cycle","golden cycle":"Golden Cycle","quest item":"Quest Item","cube reagent":"Cube Reagent","shrine (10)":"Shrine \(10(?:\)|$)","signet":"Signet"}
    shrines := "Abandoned|Creepy|Eerie|Enchanted|Fascinating|Hidden|Intimidating|Magical|Ornate|Quiet|Sacred|Shimmering|Spiritual|Tainted|Trinity|Weird"
    Loop, Parse, shrines, |
        patterns[PickupNameNormalizeV8(A_LoopField . " Shrine")] := "^" . A_LoopField . " Shrine(?: \(\d+\))?$"
    return patterns
}


PickupEditorKeyV10(line)
{
    line := LTrim(Trim(line," `t`r`n" . Chr(0xFEFF)),"# `t")
    if (line="")
        return ""
    if (PickupShortParseV638(line,shortName,shortClass,shortQuality))
        return "ITEM:" . RareWarningRuleKeyV29(shortClass,shortQuality,-1)
    if (IsObject(SetNoSigParseV227(line)) && RegExMatch(line,"[\[{]"))
        return "SET_KEEP:" . PickupNameNormalizeV8(line)
    if (PickupOptIsRuleV12(line))
        return "OPT:" . PickupNameNormalizeV8(line)
    group := PickupAutoGroupParseV7(line)
    if (group!="")
        return "GROUP:" . group
    if (UniqueRuleParseV18(line,cls,q,idx,tier))
        return "ITEM:" . RareWarningRuleKeyV29(cls,q,idx)
    return "TEXT:" . PickupNameNormalizeV8(line)
}

PickupEditorHasV10(raw,name)
{
    wanted := PickupEditorKeyV10(name)
    Loop, Parse, raw, `n, `r
        if (PickupEditorKeyV10(A_LoopField)=wanted)
            return true
    return false
}

PickupEditorDedupV10(raw,ByRef removed)
{
    seen := {},removed := 0,result := ""
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField," `t`r`n" . Chr(0xFEFF))
        if (SubStr(line,1,1)="#")
        {
            result .= line . "`r`n"
            continue
        }
        key := PickupEditorKeyV10(line)
        if (key="")
            continue
        if (seen.HasKey(key))
        {
            removed++
            continue
        }
        seen[key] := true
        result .= line . "`r`n"
    }
    return result
}

PickupOptIsRuleV12(line)
{
    line := PickupColorStripV14(Trim(line," `t`r`n" . Chr(0xFEFF)),ignoredColorV14)
    if (PickupShortParseV638(RegExReplace(line,"i)\[\s*cube\s*\]",""),shortName,shortClass,shortQuality))
        return true
    if (SubStr(line,1,1)!="#" && RegExMatch(line,"i)\[\s*cube\s*\]"))
        return true
    if (IsObject(SetNoSigParseV227(line)))
        return false
    return SubStr(line,1,1)=Chr(34) || (SubStr(line,1,1)!="#" && RegExMatch(line,"^.+[\[{]"))
}

PickupOptRegexValidV12(pattern,ByRef error)
{
    error := ""
    try
    {
        RegExMatch("","im)" . pattern)
        if (ErrorLevel)
            error := "Regex không hợp lệ: " . pattern
    }
    catch e
        error := "Regex không hợp lệ: " . pattern
    return error=""
}

PickupOptParseV12(line,ByRef error)
{
    rawLineV14 := line
    cubeRelicV567 := RegExMatch(line,"i)\[\s*cube\s*\]") ? true : false
    line := RegExReplace(line,"i)\[\s*cube\s*\]","")
    line := PickupColorStripV14(line,ruleColorV14)
    error := "",line := Trim(line," `t`r`n" . Chr(0xFEFF))
    if (PickupShortParseV638(line,shortName,shortClass,shortQuality))
        return {name:".*",stats:[],qualities:{},tiers:{},eth:false,raw:rawLineV14,color:ruleColorV14
            ,exactClassV638:shortClass,exactQualityV638:shortQuality
            ,cubeRelicV567:cubeRelicV567 && InStr(shortName,"Relic"),cubeCharmV571:cubeRelicV567 && !InStr(shortName,"Relic")}
    simpleMode := SubStr(line,1,1)!=Chr(34)
    if (simpleMode)
    {
        simple := Trim(RegExReplace(line,"\s+#.*$","")," `t:")
        splitAt := RegExMatch(simple,"[\[{]")
        m1 := splitAt ? Trim(SubStr(simple,1,splitAt-1)) : simple
        m2 := splitAt ? SubStr(simple,splitAt) : ""
        if (m1="" || InStr(m1,"=") || InStr(m1,Chr(34)))
        {
            error := "Nhập tên đồ trước [] hoặc {}."
            return false
        }
    }
    else if (!RegExMatch(line,"^" . Chr(34) . "([^" . Chr(34) . "]+)" . Chr(34) . "(.*)$",m))
    {
        error := "Tên phải nằm trong dấu nháy kép."
        return false
    }
    name := simpleMode ? "(?<![[:alnum:]_])\Q" . Trim(m1) . "\E(?![[:alnum:]_])" : RegExReplace(Trim(m1),"\s*\|\s*","|")
    if (!PickupOptRegexValidV12(name,error))
        return false
    rule := {name:name,stats:[],qualities:{},tiers:{},eth:false,raw:rawLineV14,color:ruleColorV14}
    category := Trim(m1)
    StringLower, category, category
    rule.cubeRelicV567 := cubeRelicV567 && category="relic"
    rule.namedCharmV740 := false
    if (simpleMode)
        for _,charmNameV740 in StrSplit(PickupCharmNamesV731(),"|")
            if (category=PickupNameNormalizeV8(charmNameV740))
                rule.namedCharmV740 := true
    rule.charmV571 := category="charm"
    rule.cubeCharmV571 := cubeRelicV567 && category!="relic"
    rule.setV574 := category="set" || category="set xanh" || category="set_xanh"
    if (rule.setV574)
        rule.qualities[5] := true,rule.name := ".*"
    if (simpleMode && (category="angelic" || category="sacred" || category="mastercrafted"))
    {
        rule.name := ".*"
        rule.tiers[category] := true
    }
    rest := m2,tokens := "",i := 1
    while (i<=StrLen(rest))
    {
        ch := SubStr(rest,i,1)
        if (ch="#")
            break
        if (ch!="{" && ch!="[")
        {
            tokens .= ch,i++
            continue
        }
        opener := ch,closer := ch="{" ? "}" : "]"
        depth := 1,pattern := "",escaped := false,i++
        while (i<=StrLen(rest) && depth>0)
        {
            ch := SubStr(rest,i,1),i++
            if (!escaped && ch=opener)
                depth++
            else if (!escaped && ch=closer)
                depth--
            if (depth>0)
                pattern .= ch
            escaped := (!escaped && ch="\")
        }
        if (depth)
        {
            error := "Thiếu dấu " . closer . " đóng option."
            return false
        }
        pattern := RegExReplace(Trim(pattern),"\s*\|\s*","|")
        pattern := RegExReplace(pattern,"i)(^|\|)(?:doc|độc)(?=\||$)","$1\bPoison\b")
        if (RegExMatch(pattern,"^(\d+)(?:-(\d+))?$",range))
        {
            minimum := range1+0,maximum := range2="" ? minimum : range2+0
            if (minimum>maximum || maximum>99)
            {
                error := "Khoảng All Skills phải tăng dần và trong 0–99."
                return false
            }
            values := ""
            Loop, % maximum-minimum+1
                values .= (A_Index=1 ? "" : "|") . (minimum+A_Index-1)
            pattern := "(?<![0-9])\+?(?:" . values . ")\s+to All Skills\b"
        }
        if (pattern="" || !PickupOptRegexValidV12(pattern,error))
        {
            if (error="")
                error := "Option trong [] hoặc {} không được để trống."
            return false
        }
        rule.stats.Push(pattern),tokens .= " "
    }
    qualities := {"low":1,"inferior":1,"normal":2,"superior":3,"magic":4,"set":5,"rare":6,"unique":7,"crafted":8,"honorific":9}
    tokens := RegExReplace(Trim(tokens),"\s+"," ")
    Loop, Parse, tokens, %A_Space%
    {
        token := A_LoopField
        StringLower, token, token
        if (token="")
            continue
        if (qualities.HasKey(token))
            rule.qualities[qualities[token]] := true
        else if (token="eth" || token="ethereal")
            rule.eth := true
        else if (RegExMatch(token,"^(sacred|angelic|mastercrafted|1|2|3|4)$"))
            rule.tiers[token] := true
        else if (RegExMatch(token,"^(red|green|blue|yellow|gold|white|black|orange|purple|grey|gray|tan|pink|darkgreen|sound\d+|notify|stat|map|show)$"))
            continue
        else
        {
            error := "Chưa hỗ trợ từ: " . token
            return false
        }
    }
    return rule
}

PickupOptValidateTextV12(raw,ByRef error)
{
    error := ""
    Loop, Parse, raw, `n, `r
    {
        if (!PickupOptIsRuleV12(A_LoopField))
            continue
        if (!IsObject(PickupOptParseV12(A_LoopField,why)))
        {
            error := "Dòng " . A_Index . ": " . why
            return false
        }
    }
    return true
}

PickupOptHelpV12()
{
    text := "NHẶT THEO TÊN VÀ OPTION`r`n`r`n"
    text .= "Set xanh [Zakarum]{Tên bộ khác}: nhặt mọi đồ Set; các bộ trong ngoặc không được SIG. [] và {} dùng như nhau; ngoặc trống bỏ qua. Tên bộ không phân biệt hoa/thường; có thể nhập phần tên (Zakarum).`r`n"
    text .= "Rune [red] hoặc Rune {red}: nhặt Rune và hiện chữ đỏ. Không ghi màu: xanh.`r`n"
    text .= "Angelic [2-5] {doc} [red]: điều kiện nhặt giữ nguyên, cảnh báo màu đỏ.`r`n"
    text .= "Màu: red, green, blue, yellow, gold, white, orange, purple, grey, pink, tan, darkgreen, black.`r`n"
    text .= "Light Plate [2-5] = nhặt Light Plate có +2 đến +5 All Skills.`r`n"
    text .= "Light Plated Boots = nhặt hết loại đó, không xét option.`r`n"
    text .= "Full Helm [3] = chỉ nhặt mũ có +3 All Skills.`r`n"
    text .= "Angelic [2-5] {doc} = mọi đồ Angelic có +2 đến +5 All Skills và option chứa Poison. doc/độc đều dùng được.`r`n"
    text .= "[] và {} dùng như nhau; có hoặc không có khoảng trắng trước ngoặc đều được.`r`n"
    text .= "Tên phải dùng đúng tên loại đồ trong game. Không phân biệt hoa/thường.`r`n`r`n"
    text .= "Option khác: " . Chr(34) . "Leather Gloves" . Chr(34) . " {Fire dance}`r`n"
    text .= "[] và {} dùng như nhau. Chỉ ghi số = All Skills; chữ = tên option. Hai nhóm cần cả hai; | trong một nhóm là chọn một.`r`n"
    text .= "Có thể thêm angelic, sacred, rare, eth... sau tên trong nháy kép để giới hạn loại đồ.`r`n"
    text .= "Mục Chuyển Charm Vào Cube: nhập tên đồ hoặc Tên|CLASS|ITEMDATA, ví dụ Relic hoặc Charm; không cần [cube].`r`n"
    text .= "Mục Chuyển Vào Kho (Cất Tiền): đồ trong Cube hoặc dưới đất → túi trung gian → kho khi Cất tiền; bỏ qua đồ có sẵn trong túi.`r`n"
    text .= "Charm: chỉ đổi tạm khi có đúng Charm cùng loại trong rương ngoài; chưa có đúng món đó thì chỉ nhặt, không chuyển Cube.`r`n"
    text .= "# tắt dòng. #Angelic: chỉ là tiêu đề ghi chú.`r`n`r`n"
    text .= "Món có luật tên/option riêng phải đạt điều kiện trước khi nhặt; luật nhặt mặc định và GET không bỏ qua điều kiện. Trong mục Chuyển Charm Vào Cube, Zakarum's Ear [rrr 15%] hoặc Zakarum's Ear {rrr 15%} chỉ nhận món có option khớp rrr 15%.`r`n"
    text .= "Tool đọc chữ trực tiếp từ game. Nếu chưa đọc được option thì chưa nhặt qua luật có option. XUẤT LOG ghi tên, option và lỗi đọc khi bạn bật log."
    return text
}

PickupOptExamplesV12()
{
    q := Chr(34)
    return "#Light Plate [2-5]`r`n#Light Plated Boots`r`n#Full Helm [3-4]`r`n#" . q . "Boots" . q . " angelic {All Skills} {All Attributes}`r`n"
}

PickupOptCleanTextV12(raw,reverseLines:=false)
{
    clean := RegExReplace(raw,Chr(255) . "c.","")
    clean := StrReplace(clean,"`r","")
    if (!reverseLines)
        return Trim(clean," `t`n")
    lines := StrSplit(clean,"`n"),result := ""
    Loop, % lines.Length()
    {
        line := Trim(lines[lines.Length()-A_Index+1])
        if (line!="")
            result .= (result="" ? "" : "`n") . line
    }
    return result
}

PickupOptRuleMatchV12(rule,q,flags,name,stats,baseName:="",h:=0,cls:=-1)
{
    if (rule.HasKey("exactClassV638"))
        return cls+0=rule.exactClassV638 && q+0=rule.exactQualityV638
    if (rule.qualities.Count() && !rule.qualities.HasKey(q+0))
        return false
    if (rule.eth && !(flags & 0x00400000))
        return false
    if (rule.tiers.Count())
    {
        hit := false
        for tier,_ in rule.tiers
            if (RegExMatch(name . "`n" . baseName,"im)\(" . tier . "\)"))
                hit := true
        if (!hit)
            return false
    }
    if (rule.charmV571 ? !PickupIsCharmV571(h,cls) : !RegExMatch(name . "`n" . baseName,"im)" . rule.name))
        return false
    for _,pattern in rule.stats
        if (stats="" || !RegExMatch(stats,"im)" . pattern))
            return false
    return true
}

PickupOptMatchV12(h,unit,cls,q,data)
{
    global pickupOptRulesV12,consumableClassRAMV7,pickupCubeTraceUntil
    PickupOptPollV12()
    if (!IsObject(pickupOptRulesV12))
        UniquePickupReloadRAMV1()
    if (!unit || !data || !h || !IsObject(pickupOptRulesV12) || !pickupOptRulesV12.Length())
        return false
    flags := D2ReadU32(h,data+0x18),possible := false
    for _,rule in pickupOptRulesV12
        if (!rule.actionOnlyV678 && (!rule.qualities.Count() || rule.qualities.HasKey(q+0)) && (!rule.eth || (flags & 0x00400000)))
            possible := true
    if (!possible)
        return false
    info := PickupOptReadV12(h,unit,cls,q,data,flags)
    if (!IsObject(info) || !info.ok)
        return false
    classKey := info.pid . "|" . cls
    baseName := IsObject(consumableClassRAMV7) && consumableClassRAMV7.HasKey(classKey) ? consumableClassRAMV7[classKey] : ""
    for _,rule in pickupOptRulesV12
    {
        if (rule.actionOnlyV678)
            continue
        if (PickupOptRuleMatchV12(rule,q,flags,info.name,info.stats,baseName,h,cls))
            return true
    }
    return false
}
PickupOptReadV12(h,unit,cls,q,data,flags,nameOnlyV740:=false,forceStatsV766:=false)
{
    global pickupOptCacheV12,pickupOptJobV12,pickupOptRulesV12,pickupOptRevisionV12,pickupExcludeRulesV490,pickupNoSigRulesV490,townStoreRulesV628
    static lastPrune := 0
    if (!IsObject(pickupOptCacheV12))
        pickupOptCacheV12 := {}
    pid := DllCall("GetProcessId","Ptr",h,"UInt")
    uid := D2ReadU32(h,unit+0x0C),seed := D2ReadU32(h,data+0x14)
    if (!pid || !uid || D2ReadU32(h,unit)!=4 || D2ReadU32(h,unit+0x04)!=cls || D2ReadU32(h,unit+0x14)!=data)
        return false
    key := pid . "|" . unit . "|" . uid . "|" . data . "|" . seed . "|" . q . "|" . flags . "|" . pickupOptRevisionV12
    if (nameOnlyV740 && pickupOptCacheV12.HasKey(key) && pickupOptCacheV12[key].ok && A_TickCount-pickupOptCacheV12[key].tick<60000)
        return pickupOptCacheV12[key]
    if (nameOnlyV740)
        key .= "|NAME"
    if (pickupOptCacheV12.HasKey(key))
    {
        info := pickupOptCacheV12[key]
        if (A_TickCount-info.tick < (info.ok ? 60000 : 10000))
            return info
        pickupOptCacheV12.Delete(key)
    }
    if (A_TickCount-lastPrune>5000)
    {
        expired := []
        for cacheKey,entry in pickupOptCacheV12
            if (A_TickCount-entry.tick>60000)
                expired.Push(cacheKey)
        for _,cacheKey in expired
            pickupOptCacheV12.Delete(cacheKey)
        lastPrune := A_TickCount
    }
    if (RemoteThreadBusyV740(pid) || PickupOptPidPendingV655(pid))
        return false
    if (IsObject(pickupOptJobV12))
        return false
    needsStats := false
    for _,ruleSet in [pickupOptRulesV12,pickupExcludeRulesV490,pickupNoSigRulesV490,townStoreRulesV628]
        for _,rule in ruleSet
            if (rule.stats.Length() && (!rule.qualities.Count() || rule.qualities.HasKey(q+0)) && (!rule.eth || (flags & 0x00400000)))
                needsStats := true
        if (forceStatsV766)
        needsStats := true
    else if (nameOnlyV740)
        needsStats := false
    job := PickupOptStartV12(pid,unit,cls,q,data,uid,seed,needsStats)
    if (!IsObject(job))
    {
        pickupOptCacheV12[key] := {ok:false,tick:A_TickCount,pid:pid,uid:uid}
        DebugTraceWrite("pickup","D2MX_READ_FAIL uid=" . uid . " class=" . cls . " reason=GAME_FUNCTION_OR_REMOTE_CALL_NOT_READY")
        return false
    }
    job.key := key,job.pid := pid,job.uid := uid,job.cls := cls,job.data := data,job.unit := unit,job.seed := seed
    job.tick := A_TickCount,job.timedOut := false
    pickupOptJobV12 := job
    return false
}

PickupOptPendingV12()
{
    global pickupOptJobV12
    PickupOptPollV12()
    return IsObject(pickupOptJobV12) && !pickupOptJobV12.timedOut
}

PickupOptRetiredPollV655()
{
    global pickupOptRetiredV655
    if (!IsObject(pickupOptRetiredV655))
        return
    for index,job in pickupOptRetiredV655.Clone()
    {
        if (DllCall("WaitForSingleObject","Ptr",job.th,"UInt",0)!=0)
            continue
        DllCall("VirtualFreeEx","Ptr",job.hp,"Ptr",job.remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",job.th),DllCall("CloseHandle","Ptr",job.hp)
        pickupOptRetiredV655.Delete(index)
    }
    if (!pickupOptRetiredV655.Count())
        SetTimer, PickupOptRetiredTimerV655, Off
}

PickupOptRetiredTimerV655:
PickupOptRetiredPollV655()
return

PickupOptPidPendingV655(pid)
{
    global pickupOptRetiredV655
    PickupOptRetiredPollV655()
    for _,job in pickupOptRetiredV655
        if (job.pid=pid)
            return true
    return false
}

PickupOptPollV12()
{
    global pickupOptJobV12,pickupOptCacheV12,pickupOptRetiredV655
    static busy := false
    if (busy || !IsObject(pickupOptJobV12))
        return
    busy := true
    try
    {
        job := pickupOptJobV12
        if (DllCall("WaitForSingleObject","Ptr",job.th,"UInt",0)!=0)
        {
            if (!job.timedOut && A_TickCount-job.tick>2500)
            {
                job.timedOut := true
                if (!IsObject(pickupOptRetiredV655))
                    pickupOptRetiredV655 := {}
                pickupOptRetiredV655[job.pid . "|" . job.th] := job
                pickupOptCacheV12[job.key] := {ok:false,pid:job.pid,uid:job.uid,tick:A_TickCount}
                pickupOptJobV12 := false
                SetTimer, PickupOptRetiredTimerV655, 500
                FonInfoPushV385("Đọc tên item quá hạn; vẫn theo dõi lệnh cũ, không chặn cửa sổ game khác.")
                DebugTraceWrite("pickup","D2MX_READ_TIMEOUT uid=" . job.uid . " next=PER_PID_QUARANTINE_UNTIL_THREAD_END")
            }
            return
        }
        exitCode := 0,name := "",stats := ""
        success := DllCall("GetExitCodeThread","Ptr",job.th,"UInt*",exitCode) && exitCode=1
        identityOK := D2ReadU32(job.hp,job.unit)=4 && D2ReadU32(job.hp,job.unit+0x0C)=job.uid
            && D2ReadU32(job.hp,job.unit+0x14)=job.data && D2ReadU32(job.hp,job.data+0x14)=job.seed
        if (success && identityOK)
        {
            name := PickupOptReadWideV12(job.hp,job.name,512)
            if (job.needsStats)
                stats := PickupOptReadWideV12(job.hp,job.stats,4096)
            name := PickupOptCleanTextV12(name),stats := PickupOptCleanTextV12(stats,true)
        }
        info := {ok:success && identityOK && name!="",name:name,stats:stats,pid:job.pid,uid:job.uid,tick:A_TickCount,cls:job.cls}
        if (!IsObject(pickupOptCacheV12))
            pickupOptCacheV12 := {}
        if (pickupOptCacheV12.Count()>=512)
        {
            oldestKey := "",oldestTick := A_TickCount
            for cacheKey,entry in pickupOptCacheV12
                if (entry.tick<=oldestTick)
                    oldestKey := cacheKey,oldestTick := entry.tick
            if (oldestKey!="")
                pickupOptCacheV12.Delete(oldestKey)
        }
        pickupOptCacheV12[job.key] := info
        DebugTraceWrite("pickup","D2MX_ITEM uid=" . job.uid . " class=" . job.cls . " ok=" . info.ok . " name=" . StrReplace(name,"`n"," | ") . " options=" . StrReplace(stats,"`n"," | "))
        DllCall("VirtualFreeEx","Ptr",job.hp,"Ptr",job.remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",job.th),DllCall("CloseHandle","Ptr",job.hp)
        pickupOptJobV12 := false
    }
    finally
        busy := false
}

PickupOptReadWideV12(h,addr,size)
{
    VarSetCapacity(buffer,size+2,0),got := 0
    if (!DllCall("ReadProcessMemory","Ptr",h,"Ptr",addr,"Ptr",&buffer,"UPtr",size,"UPtr*",got) || got!=size)
        return ""
    return StrGet(&buffer,"UTF-16")
}

PickupOptEmitV12(ByRef code,ByRef offset,hex)
{
    Loop, Parse, hex, %A_Space%
        if (A_LoopField!="")
            NumPut("0x" . A_LoopField,code,offset++,"UChar")
}

PickupOptStartV12(pid,unit,cls,q,data,uid,seed,needsStats)
{
    client := D2GetModuleBaseV35(pid,"D2Client.dll")
    hp := client ? D2OpenProcess(pid) : 0
    if (!hp)
        return false
    player := D2ReadU32(hp,client+0x11BBFC)
    valid := D2ReadU16(hp,client)=0x5A4D && player && D2ReadU32(hp,player)=0
        && D2ReadU32(hp,unit)=4 && D2ReadU32(hp,unit+0x04)=cls
        && D2ReadU32(hp,unit+0x14)=data && D2ReadU32(hp,data)=q
    if (!valid || !D2ReadU8V18(hp,client+0x914F0) || (needsStats && !D2ReadU8V18(hp,client+0x560B0)))
    {
        DllCall("CloseHandle","Ptr",hp)
        return false
    }
    remote := DllCall("VirtualAllocEx","Ptr",hp,"Ptr",0,"UPtr",0x2000,"UInt",0x3000,"UInt",0x40,"Ptr")
    if (!remote || remote>0xFFFFDFFF)
    {
        if (remote)
            DllCall("VirtualFreeEx","Ptr",hp,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hp)
        return false
    }
    nameAddr := remote+0x200,statsAddr := remote+0x400
    VarSetCapacity(code,256,0),o := 0,jumps := []
    PickupOptEmitV12(code,o,"53 57 8B 5C 24 0C 31 C0 83 3B 04 0F 85")
    jumps.Push(o),o+=4
    PickupOptEmitV12(code,o,"81 7B 0C"),NumPut(uid,code,o,"UInt"),o+=4
    PickupOptEmitV12(code,o,"0F 85"),jumps.Push(o),o+=4
    PickupOptEmitV12(code,o,"81 7B 14"),NumPut(data,code,o,"UInt"),o+=4
    PickupOptEmitV12(code,o,"0F 85"),jumps.Push(o),o+=4
    PickupOptEmitV12(code,o,"8B 53 14 81 7A 14"),NumPut(seed,code,o,"UInt"),o+=4
    PickupOptEmitV12(code,o,"0F 85"),jumps.Push(o),o+=4
    PickupOptEmitV12(code,o,"68 00 01 00 00 68"),NumPut(nameAddr,code,o,"UInt"),o+=4
    PickupOptEmitV12(code,o,"53 B8"),NumPut(client+0x914F0,code,o,"UInt"),o+=4
    PickupOptEmitV12(code,o,"FF D0")
    if (needsStats)
    {
        PickupOptEmitV12(code,o,"31 C0 81 7B 0C"),NumPut(uid,code,o,"UInt"),o+=4
        PickupOptEmitV12(code,o,"0F 85"),jumps.Push(o),o+=4
        PickupOptEmitV12(code,o,"81 7B 14"),NumPut(data,code,o,"UInt"),o+=4
        PickupOptEmitV12(code,o,"0F 85"),jumps.Push(o),o+=4
        PickupOptEmitV12(code,o,"BF"),NumPut(statsAddr,code,o,"UInt"),o+=4
        PickupOptEmitV12(code,o,"6A 00 6A 01 53 B8"),NumPut(client+0x560B0,code,o,"UInt"),o+=4
        PickupOptEmitV12(code,o,"FF D0")
    }
    PickupOptEmitV12(code,o,"B8 01 00 00 00")
    endOffset := o
    PickupOptEmitV12(code,o,"5F 5B C2 04 00")
    for _,jump in jumps
        NumPut(endOffset-(jump+4),code,jump,"Int")
    written := 0
    if (!DllCall("WriteProcessMemory","Ptr",hp,"Ptr",remote,"Ptr",&code,"UPtr",o,"UPtr*",written) || written!=o)
    {
        DllCall("VirtualFreeEx","Ptr",hp,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hp)
        return false
    }
    DllCall("FlushInstructionCache","Ptr",hp,"Ptr",remote,"UPtr",o)
    th := DllCall("CreateRemoteThread","Ptr",hp,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",unit,"UInt",0,"Ptr",0,"Ptr")
    if (!th)
    {
        DllCall("VirtualFreeEx","Ptr",hp,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hp)
        return false
    }
    return {hp:hp,remote:remote,th:th,name:nameAddr,stats:statsAddr,needsStats:needsStats}
}

PickupOptCloseV12()
{
    global pickupOptJobV12
    if (!IsObject(pickupOptJobV12))
        return
    job := pickupOptJobV12
    if (DllCall("WaitForSingleObject","Ptr",job.th,"UInt",0)=0)
        DllCall("VirtualFreeEx","Ptr",job.hp,"Ptr",job.remote,"UPtr",0,"UInt",0x8000)
    DllCall("CloseHandle","Ptr",job.th),DllCall("CloseHandle","Ptr",job.hp)
    pickupOptJobV12 := false
}

PickupColorHexV14(name)
{
    colors := {"red":"FF3030","green":"35D06F","blue":"5599FF","yellow":"FFFF00","gold":"FFD700","white":"FFFFFF","black":"000000","orange":"FFA500","purple":"BB77FF","grey":"AAAAAA","gray":"AAAAAA","tan":"D2B48C","pink":"FF88CC","darkgreen":"008000"}
    name := Trim(name)
    StringLower, name, name
    return colors.HasKey(name) ? colors[name] : ""
}

PickupColorStripV14(line,ByRef color)
{
    color := "",rest := line,out := ""
    while (pos := RegExMatch(rest,"i)(?:\[\s*(red|green|blue|yellow|gold|white|black|orange|purple|grey|gray|tan|pink|darkgreen)\s*\]|\{\s*(red|green|blue|yellow|gold|white|black|orange|purple|grey|gray|tan|pink|darkgreen)\s*\})",m))
    {
        out .= SubStr(rest,1,pos-1),color := PickupColorHexV14(m1!="" ? m1 : m2)
        rest := SubStr(rest,pos+StrLen(m))
    }
    return Trim(out . rest)
}


PickupAlertGroupMatchV14(group,q,tier,setOK,name)
{
    if (group="UNIQUE")
        return q=7 && UniqueKnownTierV4(tier)
    if (UniqueKnownTierV4(group))
        return q=7 && tier=group
    if (group="SET_XANH")
        return q=5 && setOK
    if (name="")
        return false
    
    if (SubStr(group,1,5)="NAME:")
    {
        Loop, Parse, name, `n, `r
            if (PickupNameNormalizeV8(A_LoopField)=SubStr(group,6))
                return true
        return false
    }
    if (SubStr(group,1,7)="FILTER:")
    {
        patterns := PickupCatalogPatternsV9(),filter := SubStr(group,8)
        return patterns.HasKey(filter) && RegExMatch(name,"im)" . patterns[filter])
    }
    baseGroup := ConsumableKnownNameV7(name)
    return group=baseGroup || group=PickupNamedSubtypeV8(name,baseGroup)
}

PickupAlertMatchV14(h,u,cls,q,data,tier,ByRef color,ByRef label)
{
    global pickupAllow,pickupListLoaded,pickupAutoGroupsV7,pickupColorsV14,pickupExactAlertsV14,pickupOptRulesV12,consumableClassRAMV7,pickupExcludeClassesV329
    if (IsObject(pickupExcludeClassesV329) && pickupExcludeClassesV329.HasKey(cls+0))
        return false
    color := "35D06F",label := "ITEM",matched := false,explicitColor := "",exactAlertV610 := false,customLabelV610 := ""
    rareTierV610 := q=7 && (tier="SSU" || tier="SSSU")
    if (!pickupListLoaded)
        PickupReloadRAMV97()
    if (!IsObject(pickupAutoGroupsV7))
        UniquePickupReloadRAMV1()
    key := (cls+0) . "|" . Format("{:02X}",q)
    if (pickupAllow.HasKey(key))
        matched := true
    idx := D2ReadU32(h,data+0x28)
    for _,exactKey in [RareWarningRuleKeyV29(cls,q,-1),RareWarningRuleKeyV29(cls,q,idx)]
    {
        if (!pickupExactAlertsV14.HasKey(exactKey))
            continue
        exact := pickupExactAlertsV14[exactKey],matched := true,exactAlertV610 := true
        if (exact.label!="")
            customLabelV610 := exact.label
        if (exact.color!="")
            explicitColor := exact.color
    }
    ConsumablePickupGroupV7(h,cls)
    pid := DllCall("GetProcessId","Ptr",h,"UInt"),classKey := pid . "|" . cls
    baseName := IsObject(consumableClassRAMV7) && consumableClassRAMV7.HasKey(classKey) ? consumableClassRAMV7[classKey] : ""
    flags := D2ReadU32(h,data+0x18),info := false
    PickupOptPollV12()
    if (pickupOptRulesV12.Length() || IsObject(pickupAutoGroupsV7) && pickupAutoGroupsV7.Count())
        info := PickupOptReadV12(h,u,cls,q,data,flags)
    name := IsObject(info) && info.ok ? info.name : baseName
    setOK := q=5 ? SetPickupVerifiedV4(h,cls,data) : false
    for group,_ in pickupAutoGroupsV7
    {
        if (!PickupAlertGroupMatchV14(group,q,tier,setOK,name . "`n" . baseName))
            continue
        matched := true
        if (pickupColorsV14.HasKey(group) && explicitColor="")
            color := pickupColorsV14[group]
    }
    if (IsObject(info) && info.ok)
    {
        for _,rule in pickupOptRulesV12
        {
            if (rule.actionOnlyV678)
                continue
            if (!PickupOptRuleMatchV12(rule,q,flags,info.name,info.stats,baseName,h,cls))
                continue
            matched := true
            if (rule.color!="")
                explicitColor := rule.color
        }
    }
    if (!matched)
        return false
    if (exactAlertV610)
        color := "FF3030"
    if (explicitColor!="")
        color := explicitColor
    if (rareTierV610)
        color := "FF3030"
    if (name!="")
    {
        displayLinesV14 := StrSplit(RegExReplace(name,Chr(255) . "c.",""),"`n")
        display := displayLinesV14[1]
        label := Trim(display," `t`r")
    }
    if (customLabelV610!="")
        label := customLabelV610
    if (q=7)
        label := "[" . (UniqueKnownTierV4(tier) ? tier : "UNIQUE ?") . "] " . (label="ITEM" ? "" : label)
    else if (exactAlertV610 && label="ITEM")
        label := "Vật phẩm hiếm"
    return true
}


BossPriorityTextV221()
{
    global bossPriorityClassesV221
    return StrReplace(bossPriorityClassesV221,",","`r`n")
}

MonsterLockEligibleV308(classId)
{
    return classId>=0 && BossPriorityHasV221(classId) && !MonsterClassExcludedV11(classId)
}

BossPriorityHasV221(classId)
{
    global bossPriorityIdsV221
    return IsObject(bossPriorityIdsV221) && bossPriorityIdsV221.HasKey(classId+0)
}

BossPriorityNormalizeV221(text,ByRef normalized,ByRef ids)
{
    normalized := "",ids := {}
    for _,token in StrSplit(RegExReplace(Trim(text),"[,;\s]+",","),",")
    {
        if (token="")
            continue
        if (!RegExMatch(token,"^\d+$") || StrLen(token)>10 || token+0>4294967295)
            return false
        id := token+0
        if (ids.HasKey(id))
            continue
        ids[id] := true,normalized .= (normalized="" ? "" : ",") . id
    }
    return true
}

BossPrioritySaveV221(profile:="")
{
    global ConfigFile,currentProfile,bossPriorityClassesV221
    profile := profile="" ? currentProfile : profile
    section := ProfileSection(profile)
    IniWrite, %bossPriorityClassesV221%, % ProfileConfigPathV364(section), %section%, BossPriorityClasses
    return !ErrorLevel
}

BossPriorityLoadV221(profile)
{
    global ConfigFile,bossPriorityClassesV221,bossPriorityIdsV221
    section := ProfileSection(profile)
    IniRead, text, % ProfileConfigPathV364(section), %section%, BossPriorityClasses, %A_Space%
    if (!BossPriorityNormalizeV221(text,normalized,ids))
        normalized := "",ids := {}
    bossPriorityClassesV221 := normalized,bossPriorityIdsV221 := ids
    GuiControl,, BossPriorityListV221, % BossPriorityTextV221() . "`r`n"
}

BossPriorityCommitV221(text)
{
    global bossPriorityClassesV221,bossPriorityIdsV221
    if (!BossPriorityNormalizeV221(text,normalized,ids))
    {
        MsgBox, 48, Lỗi, Class ID boss chỉ nhập số, mỗi ID một dòng.
        return false
    }
    oldList := bossPriorityClassesV221,oldIds := bossPriorityIdsV221
    bossPriorityClassesV221 := normalized,bossPriorityIdsV221 := ids
    if (!BossPrioritySaveV221())
    {
        bossPriorityClassesV221 := oldList,bossPriorityIdsV221 := oldIds
        MsgBox, 48, Lỗi, Không lưu được danh sách Boss ưu tiên.
        return false
    }
    GuiControl,, BossPriorityListV221, % BossPriorityTextV221() . "`r`n"
    return true
}


BossPriorityGetNearestV221(fromGuiV222 := true)
{
    pid := fromGuiV222 ? CoordDisplayGamePidV1() : D2GetActiveGamePidV95(),base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? DllCall("OpenProcess","UInt",0x0410,"Int",false,"UInt",pid,"Ptr") : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return false
        target := PetBossHoveredUnitV223(h,base,pid)
        if (!IsObject(target) || !MonsterBossProbeReadV1(h,target.unit,0x30,ub)
            || NumGet(ub,0,"UInt")!=1 || NumGet(ub,12,"UInt")!=target.uid
            || NumGet(ub,16,"UInt")=0 || NumGet(ub,16,"UInt")=12)
        {
            ToolTipInfoV386("GET BOSS: hãy đặt chuột lên boss sống rồi bấm phím GET.")
            SetTimer, RemoveToolTip, -2500
            return false
        }
        cls := NumGet(ub,4,"UInt")
        if (MonsterClassExcludedV11(cls))
        {
            ToolTipInfoV386("Class " . cls . " đang trong Pet loại trừ. Xóa khỏi loại trừ trước khi thêm Boss ưu tiên.")
            SetTimer, RemoveToolTip, -3000
            return false
        }
        GuiControlGet, edited, 1:, BossPriorityListV221
        if (!BossPriorityCommitV221(edited . "`r`n" . cls))
            return false
        ToolTipInfoV386("Đã thêm Boss ưu tiên: CLASS " . cls . " (con đang dưới chuột).")
        SetTimer, RemoveToolTip, -2500
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}


PetBossFocusV222(wParam,lParam,msg,hwnd)
{
    global PetExcludeHwndV16,BossPriorityHwndV222,petBossGetTargetV222,pickupGetTargetV638
    if (((wParam >> 16) & 0xFFFF)!=0x100 || !lParam)
        return
    GuiControlGet, rightEditV638, 1:Hwnd, PickupEditorInputV8
    GuiControlGet, keepEditV638, 1:Hwnd, PickupNoSigEditorV490
    pickupGetTargetV638 := lParam=rightEditV638 ? "PickupEditorInputV8" : (lParam=keepEditV638 ? "PickupNoSigEditorV490" : "")
    if (lParam=PetExcludeHwndV16)
        petBossGetTargetV222 := "PET"
    else if (lParam=BossPriorityHwndV222)
        petBossGetTargetV222 := "BOSS"
}


PetBossHoveredUnitV223(h,base,pid)
{
    MouseGetPos,,,hoverWin
    WinGet, hoverPid, PID, ahk_id %hoverWin%
    if (!pid || hoverPid!=pid || D2GetActiveGamePidV95()!=pid)
        return false
    u := D2ReadU32(h,base+0x11B834)
    if (!u || !MonsterBossProbeReadV1(h,u,0x30,ub))
        return false
    uid := NumGet(ub,12,"UInt"),mode := NumGet(ub,16,"UInt")
    if (NumGet(ub,0,"UInt")!=1 || !uid || mode=0 || mode=12)
        return false
    return {unit:u,uid:uid}
}

SigReusableItemV225(item)
{
    return IsObject(item) && item.q=2 && (item.cls=1204 || item.cls=1734 || item.cls=1735)
}


SetNoSigParseV227(line)
{
    line := PickupColorStripV14(Trim(line," `t`r`n" . Chr(0xFEFF)),ignoredColor)
    if (SubStr(line,1,1)="#")
        return false
    line := Trim(RegExReplace(line,"\s+#.*$",""))
    if (!RegExMatch(line,"i)^(?:SET(?:[ _]+XANH)?|ITEMDATA\s*=\s*05\s*\|\s*TIER\s*=\s*(?:SET_XANH|SET))(?=\s|[\[{]|$)(.*)$",m))
        return false
    rest := Trim(m1),names := [],seen := {}
    while (rest!="")
    {
        if (!RegExMatch(rest,"^(?:\[([^\[\]{}]*)\]|\{([^\[\]{}]*)\})\s*",part))
            return false
        value := Trim(part1!="" ? part1 : part2)
        Loop, Parse, value, |
        {
            name := Trim(RegExReplace(A_LoopField,"\s+"," "))
            StringLower, key, name
            if (name!="" && !seen.HasKey(key))
                names.Push(name),seen[key] := true
        }
        rest := SubStr(rest,StrLen(part)+1)
    }
    return {names:names}
}

SetNoSigLoadV227(ctx)
{
    if (!RareWarningReadTextV35(UniquePickupFileV3(),raw))
        return false
    raw := PickupCanonicalAllowTextV491(raw)
    if (RareWarningReadTextV35(PickupNoSigFileV490(),keepText,true))
        raw .= "`r`n" . keepText
    names := [],seen := {}
    Loop, Parse, raw, `n, `r
    {
        line := Trim(A_LoopField," `t`r`n" . Chr(0xFEFF))
        if (line="" || SubStr(line,1,1)="#")
            continue
        parsed := SetNoSigParseV227(line)
        if (!IsObject(parsed))
        {
            if (RegExMatch(line,"i)^(?:SET(?:[ _]+XANH)?|ITEMDATA\s*=\s*05\s*\|\s*TIER\s*=\s*(?:SET_XANH|SET))(?=\s|[\[{]|$)"))
            {
                SigLogV147("SET_KEEP_RULE_ERROR line=" . line)
                return false
            }
            continue
        }
        for _,name in parsed.names
        {
            StringLower, key, name
            if (!seen.HasKey(key))
                names.Push(name),seen[key] := true
        }
    }
    ctx.setNoSigNamesV227 := names,ctx.setNameCacheV227 := {},ctx.setKeepLoggedV227 := {}
    for _,name in names
        SigLogV147("SET_KEEP_RULE set=" . name)
    return true
}

SigSetProtectedV227(ctx,item)
{
    if (!IsObject(ctx.setNoSigNamesV227) || !ctx.setNoSigNamesV227.Length())
        return false
    name := SigSetNameV227(ctx,item),keep := name="",matched := ""
    if (name!="")
        for _,wanted in ctx.setNoSigNamesV227
            if (InStr(name,wanted,false))
            {
                keep := true,matched := wanted
                break
            }
    if (ctx.setKeepLoggedV227.HasKey(item.uid))
        return ctx.setKeepLoggedV227[item.uid]
    SigLogV147("SET_MEMBERSHIP uid=" . item.uid . " class=" . item.cls . " set=" . name
        . " no_sig=" . keep . " rule=" . matched . " reason=" . (name="" ? "UNKNOWN_SET_KEEP_SAFE" : keep ? "PROTECTED_SET" : "OTHER_SET"))
    ctx.setKeepLoggedV227[item.uid] := keep
    return keep
}

SigSetNameV227(ctx,item)
{
    global sigSetNameJobV227
    if (!item.unit || D2ReadU32(ctx.h,item.unit)!=4 || D2ReadU32(ctx.h,item.unit+0x0C)!=item.uid
        || D2ReadU32(ctx.h,item.unit+0x14)!=item.data || !SetPickupVerifiedV4(ctx.h,item.cls,item.data))
        return ""
    common := D2GetModuleBaseV35(ctx.pid,"D2Common.dll"),sgpt := D2ReadU32(ctx.h,common+0x99E1C)
    itemTable := D2ReadU32(ctx.h,sgpt+0xC18),idx := D2ReadU32(ctx.h,item.data+0x28)
    record := itemTable+idx*0x1B8,setId := D2ReadU16(ctx.h,record+0x2C)
    sets := D2ReadU32(ctx.h,sgpt+0xC0C),count := D2ReadU32(ctx.h,sgpt+0xC10)
    if (!sets || count<1 || count>32767 || setId>=count)
        return ""
    setRecord := sets+setId*0x128
    members := D2ReadU32(ctx.h,setRecord+0x0C),linked := false
    if (D2ReadU16(ctx.h,setRecord)!=setId || members<1 || members>6)
        return ""
    Loop, %members%
        if (D2ReadU32(ctx.h,setRecord+0x110+(A_Index-1)*4)=record)
            linked := true
    stringId := D2ReadU16(ctx.h,setRecord+2)
    if (!linked || !stringId || stringId=65535)
        return ""
    key := setRecord . "|" . stringId
    if (ctx.setNameCacheV227.HasKey(key))
        return ctx.setNameCacheV227[key]
    if (IsObject(sigSetNameJobV227))
    {
        if (DllCall("WaitForSingleObject","Ptr",sigSetNameJobV227.th,"UInt",0)!=0)
            SigFailV147("Đang đọc tên bộ Set; giữ đồ, chờ rồi SIG lại")
        DllCall("VirtualFreeEx","Ptr",sigSetNameJobV227.hp,"Ptr",sigSetNameJobV227.remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",sigSetNameJobV227.th),DllCall("CloseHandle","Ptr",sigSetNameJobV227.hp)
        sigSetNameJobV227 := false
    }
    lang := D2GetModuleBaseV35(ctx.pid,"D2Lang.dll")
    client := D2GetModuleBaseV35(ctx.pid,"D2Client.dll")
    if (!lang || !client || !NativeRightClickBuildV9(ctx.h,client))
        return ""
    job := ConsumableNameStartV7(ctx.pid,lang+0x9450,stringId)
    if (!IsObject(job))
        return ""
    sigSetNameJobV227 := job,start := A_TickCount
    while (DllCall("WaitForSingleObject","Ptr",job.th,"UInt",0)!=0)
    {
        SigCheckV147(ctx)
        if (A_TickCount-start>=4000)
            SigFailV147("Chưa đọc được tên bộ Set; giữ đồ, dừng SIG")
        Sleep, 25
    }
    name := "",ptr := 0
    if (DllCall("GetExitCodeThread","Ptr",job.th,"UInt*",ptr) && ptr)
        name := PickupOptCleanTextV12(PickupOptReadWideV12(job.hp,ptr,512))
    DllCall("VirtualFreeEx","Ptr",job.hp,"Ptr",job.remote,"UPtr",0,"UInt",0x8000)
    DllCall("CloseHandle","Ptr",job.th),DllCall("CloseHandle","Ptr",job.hp)
    sigSetNameJobV227 := false
    name := Trim(RegExReplace(name,"\s+"," "))
    ctx.setNameCacheV227[key] := name
    return name
}

ScosGoldReadV229(h,player)
{
    stats := D2ReadU32(h,player+0x5C)
    if (!stats || !MonsterBossProbeReadV1(h,stats,0x60,sb))
        return false
    for _,off in [0x24,0x48]
    {
        root := NumGet(sb,off,"UInt"),count := NumGet(sb,off+4,"UShort"),cap := NumGet(sb,off+6,"UShort")
        if (!root || count<1 || count>512 || cap<count || !MonsterBossProbeReadV1(h,root,count*8,ab))
            continue
        gold := 0,bank := 0,level := 0,seen := {},duplicate := false
        Loop, %count%
        {
            at := (A_Index-1)*8,layer := NumGet(ab,at,"UShort"),id := NumGet(ab,at+2,"UShort")
            if (layer || (id!=12 && id!=14 && id!=15))
                continue
            if (seen.HasKey(id))
                duplicate := true
            seen[id] := true,value := NumGet(ab,at+4,"UInt")
            if (id=12)
                level := value
            else if (id=14)
                gold := value
            else
                bank := value
        }
        if (!duplicate && level>=1 && level<=150 && gold<=2147483647 && bank<=2147483647)
            return {gold:gold,bank:bank,limit:2500000}
    }
    return false
}


ScosGoldBeforeWpV229(r,ctx,player,ByRef pb,px,py,independentStash := false)
{
    global xRunning,zRunning,gameItemActionOwner,packetWatchArmedV1,pickupTimerBusy
    if (r.goldDoneV229)
        return false
    if (!r.stashRouteDoneV230)
        return true
    if (r.phase!="WP")
        throw Exception("Chưa hoàn tất cất tiền trước WP")
    if (xRunning || zRunning || gameItemActionOwner!="" || pickupTimerBusy || packetWatchArmedV1
        || !AutoMonsterPacketCleanupV1())
        return true
    SigCheckV147(ctx)
    ctx.player := player,ctx.inv := D2ReadU32(ctx.h,player+0x60)
    TownStorePrepareV629(r,ctx,player)
    mode := D2ReadU32(ctx.h,player+0x10)
    if (mode=0 || mode=17)
        throw Exception("Nhân vật đã chết khi cất tiền")
    gold := ScosGoldReadV229(ctx.h,player)
    if (!IsObject(gold))
    {
        PortalLogWriteV66("SCOS_GOLD_ERROR reason=GOLD_STATS_UNREADABLE next=STOP_BEFORE_WP")
        throw Exception("Không đọc được tiền trong rương/người; chưa vào WP")
    }
    if (r.goldStepV229="CLOSE")
    {
        if (A_TickCount-r.goldAtV229<500)
            return true
        r.goldDoneV229 := true
        return false
    }
    if (r.goldStepV229="VERIFY")
    {
        received := gold.bank-r.goldBankV229,spent := r.goldWalletV229-gold.gold
        PortalLogWriteV66("SCOS_GOLD_VERIFY amount=" . r.goldAmountV229 . " wallet=" . gold.gold
            . " bank=" . gold.bank . " bank_delta=" . received . " wallet_delta=" . spent
            . " elapsed_ms=" . (A_TickCount-r.goldAtV229),"SCOS_GOLD_VERIFY",500)
        if (received=r.goldAmountV229 && spent=received)
        {
            PortalLogWriteV66("SCOS_GOLD_CONFIRMED amount=" . received . " wallet=" . gold.gold
                . " bank=" . gold.bank . " limit=" . gold.limit . " next=CLOSE_STASH_THEN_WP")
            ScosGoldCloseV229(r,ctx)
            return true
        }
        if (A_TickCount-r.goldAtV229>=4000)
        {
            PortalLogWriteV66("SCOS_GOLD_ERROR reason=DEPOSIT_UNCONFIRMED amount=" . r.goldAmountV229
                . " wallet=" . gold.gold . " bank=" . gold.bank . " bank_delta=" . received . " wallet_delta=" . spent)
            throw Exception("Chưa xác nhận cất tiền; dừng trước WP, không gửi lặp")
        }
        return true
    }
    if (!r.goldStepV229 && (gold.bank>=gold.limit || gold.gold=0) && TownStorePendingV628(ctx,player,r))
    {
        if (!TownStoreRunV628(r,ctx,player))
            return true
        r.goldDoneV229 := true
        return false
    }
    if ((gold.bank>=gold.limit || gold.gold=0)
        && (!TownStorePendingV628(ctx,player,r) || r.goldStepV229="OPEN_WAIT"))
    {
        PortalLogWriteV66("SCOS_GOLD_SKIP reason=" . (gold.bank>=gold.limit ? "STASH_FULL" : "NO_CARRIED_GOLD")
            . " wallet=" . gold.gold . " bank=" . gold.bank . " limit=" . gold.limit)
        if (r.goldStepV229="OPEN_WAIT")
        {
            ScosGoldCloseV229(r,ctx)
            return true
        }
        r.goldDoneV229 := true
        return false
    }
    stash := CycObjectV42(ctx.h,pb,267)
    if (!IsObject(stash))
        throw Exception("Không thấy rương cất tiền gần WP")
    if (!r.goldStartedV229)
    {
        r.goldStartedV229 := true
        PortalLogWriteV66("SCOS_GOLD_CHECK wallet=" . gold.gold . " bank=" . gold.bank . " limit=" . gold.limit
            . " stash_uid=" . stash.uid . " stash_xy=" . stash.x . "," . stash.y . " next=DEPOSIT_BEFORE_WP")
    }
    distance := Sqrt((px-stash.x)**2+(py-stash.y)**2)
    if (distance>20)
    {
        if (r.goldStepV229="OPEN_WAIT")
            throw Exception("Rời xa rương trong khi cất tiền; chưa vào WP")
        throw Exception("Chưa ở gần rương sau lộ trình; dừng để tránh đi tắt")
    }
    if (mode!=1 && mode!=5)
        return true
    inv := D2ReadU32(ctx.h,player+0x60),cursor := inv ? PickupCursorV4(ctx.h,inv) : false
    if (!IsObject(cursor) || cursor.unit)
        throw Exception("Có vật trên chuột; dừng bước cất tiền")
    if (r.goldStepV229="OPEN_WAIT")
    {
        if (stash.uid!=r.goldStashV229)
            throw Exception("Rương cất tiền đã thay đổi")
        if (A_TickCount-r.goldAtV229<750)
            return true
        amount := Min(gold.gold,gold.limit-gold.bank)
        bytes := ScosGoldPacketV231(amount)
        r.goldWalletV229 := gold.gold,r.goldBankV229 := gold.bank,r.goldAmountV229 := amount
        PortalLogWriteV66("SCOS_GOLD_SEND amount=" . amount . " wallet=" . gold.gold . " bank=" . gold.bank
            . " format=BUTTON_WORD_HIGH_WORD_LOW_WORD next=VERIFY_BALANCES")
        SigPacketV147(ctx,bytes)
        r.goldStepV229 := "VERIFY",r.goldAtV229 := A_TickCount
        return true
    }
    level := CoordLevelV14(ctx.h,NumGet(pb,0x1C,"UInt"))
    if (independentStash && (!BackgroundValidV63() || D2GetActiveGamePidV95()!=ctx.pid))
    {
        FarmGoldInfoV9(r,"Cất tiền: đang chờ nhận đúng cửa sổ game.")
        return true
    }
    opened := independentStash ? SigTownInteractStashV342(ctx.pid,level,stash)
        : SigTownPortalInteractV148(r.pid,level,stash,true)
    if (opened)
    {
        r.goldStashV229 := stash.uid,r.goldStepV229 := "OPEN_WAIT",r.goldAtV229 := A_TickCount
        PortalLogWriteV66("SCOS_GOLD_OPEN uid=" . stash.uid . " class=267 method=NATIVE_UNIT_INTERACT")
    }
    if (independentStash && !opened)
        FarmGoldInfoV9(r,"Cất tiền: chưa gửi được lệnh mở rương; giữ bước hiện tại.")
    return true
}

ScosGoldCloseV229(r,ctx)
{
    SigCheckV147(ctx)
    if (!TownStoreRunV628(r,ctx,ctx.player))
        return
    if (!r.storeUiClosedV633 && !GameTargetKeyV63("{Esc}"))
        throw Exception("Chưa đóng được rương sau cất tiền")
    r.goldStepV229 := "CLOSE",r.goldAtV229 := A_TickCount
    PortalLogWriteV66("SCOS_GOLD_CLOSE next=" . (r.map="NAO" ? "NAO_USE_ITEM_AT_5138_5060" : "EXISTING_WP_ROUTE"))
}


ScosGoldPacketV231(amount)
{
    if (amount<1 || amount>2147483647 || amount!=Floor(amount))
        throw Exception("Số tiền cất không hợp lệ")
    high := (amount >> 16) & 0xFFFF,low := amount & 0xFFFF
    return [0x4F,0x14,0x00,high & 0xFF,(high >> 8) & 0xFF,low & 0xFF,(low >> 8) & 0xFF]
}

GameRoomHistoryLoadV252()
{
    global gameRoomHistoryV252,ConfigFile
    gameRoomHistoryV252 := []
    IniRead, count, %ConfigFile%, GameRoomHistory, Count, 0
    count := Min(10,Max(0,count+0))
    Loop, %count%
    {
        key := "Name" . A_Index
        IniRead, name, %ConfigFile%, GameRoomHistory, %key%, %A_Space%
        key := "Time" . A_Index
        IniRead, stamp, %ConfigFile%, GameRoomHistory, %key%, %A_Space%
        if (name!="" && !InStr(name,"|") && !InStr(name,"`n"))
            gameRoomHistoryV252.Push({name:name,stamp:stamp})
    }
}

GameRoomHistoryLatestV252()
{
    global gameRoomHistoryV252
    return IsObject(gameRoomHistoryV252) && gameRoomHistoryV252.Length() ? gameRoomHistoryV252[1].name : ""
}


GameRoomHistoryPickV252:
GuiControlGet, selectedRoomV252, 1:, GameRoomHistoryV252
for _,historyRoomV252 in gameRoomHistoryV252
    if (selectedRoomV252=historyRoomV252.name . "  -  " . historyRoomV252.stamp)
    {
        GuiControl, 1:, GameRoomNameV252, % historyRoomV252.name
        break
    }
return

GameRoomLiveNameV252(pid)
{
    base := D2GetModuleBaseV35(pid,"D2Client.dll"),h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return ""
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!path || !CoordLevelV14(h,D2ReadU32(h,path+0x1C)))
            return ""
        info := D2ReadU32(h,base+0x11B980)
        if (!info || !MonsterBossProbeReadV1(h,info+0x1B,24,buf))
            return ""
        length := 0
        Loop, 24
        {
            value := NumGet(buf,A_Index-1,"UChar")
            if (!value)
                break
            if (value<32 || value>126 || value=124)
                return ""
            length++
        }
        if (!length || length>=24 || D2ReadU32(h,base+0x11B980)!=info)
            return ""
        name := StrGet(&buf,length,"CP0")
        if (!MonsterBossProbeReadV1(h,info+0x1B,24,verify)
            || StrGet(&verify,length,"CP0")!=name || NumGet(verify,length,"UChar")!=0)
            return ""
        return name
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

GameRoomHistoryCaptureV252(pid,verifiedNameV1181 := "",captureReasonV1181 := "LIVE_GAME")
{
    global gameRoomHistoryV252,ConfigFile
    name := (verifiedNameV1181!="" ? verifiedNameV1181 : GameRoomLiveNameV252(pid))
    if (name="")
    {
        PortalLogWriteV66("GAME_ROOM_HISTORY_READ_FAILED previous=KEPT")
        return false
    }
    if (!IsObject(gameRoomHistoryV252))
        GameRoomHistoryLoadV252()
    if (gameRoomHistoryV252.Length() && gameRoomHistoryV252[1].name=name)
        return true
    FormatTime, stamp,, yyyy-MM-dd HH:mm:ss
    next := [{name:name,stamp:stamp}]
    for _,item in gameRoomHistoryV252
        if (item.name!=name && next.Length()<10)
            next.Push(item)
    gameRoomHistoryV252 := next
    count := next.Length()
    IniWrite, %count%, %ConfigFile%, GameRoomHistory, Count
    for i,item in next
    {
        key := "Name" . i,value := item.name
        IniWrite, %value%, %ConfigFile%, GameRoomHistory, %key%
        key := "Time" . i,value := item.stamp
        IniWrite, %value%, %ConfigFile%, GameRoomHistory, %key%
    }
    GuiControl, 1:, GameRoomNameV252, %name%
    PortalLogWriteV66("GAME_ROOM_HISTORY_SAVED name=" . name . " trigger=" . captureReasonV1181 . " count=" . count)
    return true
}

GameRoomHistoryWatchTimerV1181:
GameRoomHistoryAutoCaptureV1181()
return

GameRoomHistoryAutoCaptureV1181()
{
    static observedPidV1181 := 0,observedNameV1181 := "",lastSavedAtV1181 := 0
    pid := D2GetActiveGamePidV95()
    if (!pid)
        pid := CoordDisplayGamePidV1()
    if (!pid)
    {
        observedPidV1181 := 0, observedNameV1181 := ""
        return false
    }
    ; The live name function validates the player and stable game name in memory.
    ; It fails harmlessly on loading screens: never erase previously saved history.
    name := GameRoomLiveNameV252(pid)
    if (name="")
        return false
    ; Save on first observed entry or immediately upon change; also retry failed INI writes.
    if (observedPidV1181!=pid || observedNameV1181!=name || !lastSavedAtV1181
        || A_TickCount-lastSavedAtV1181>=10000)
    {
        if (!GameRoomHistoryCaptureV252(pid,name,"GAME_ENTER"))
            return false
        observedPidV1181 := pid, observedNameV1181 := name
        lastSavedAtV1181 := A_TickCount
    }
    return true
}

PickupFixedPriorityV254(cls,q)
{
    if (cls=1204)
        return 1
    if (cls=1734 || cls=1735)
        return 2
    return 3
}

FarmPauseReleaseV256(reason)
{
    global farmMapPauseV52,farmLoadedMapV56,farmControlOwnerV186,mapWorkflowV185
    global mapRunResumeV210,coordRunSelectedV210,coordRouteV16,coordCastPendingV50
    global farmStopMoveV124,farmCubeSortOnceV253,scosEntryV162
    if (IsObject(scosEntryV162) && scosEntryV162.map="BO"
        && reason="LEFT_PAUSED_MAP")
    {
        farmMapPauseV52 := false,farmLoadedMapV56 := false
        PortalLogWriteV66("BO_PAUSE_CONTEXT_RELEASE reason=" . reason . " owner=KEPT entry=KEPT")
        return
    }
    farmMapPauseV52 := false,farmLoadedMapV56 := false,farmControlOwnerV186 := ""
    mapWorkflowV185 := false,mapRunResumeV210 := false,coordRunSelectedV210 := false
    coordRouteV16 := false,coordCastPendingV50 := false,farmStopMoveV124 := false
    farmCubeSortOnceV253 := false
    SetTimer, FarmStopMoveTimerV124, Off
    PortalLogWriteV66("FARM_PAUSE_RELEASE reason=" . reason . " buttons=UNLOCKED")
}


Farm130ButtonV257:
libRequestedTierV728 := 130
Gosub, LibSelectedButtonV290
return

Farm133ButtonV290:
libRequestedTierV728 := 133
Gosub, LibSelectedButtonV290
return

Farm136ButtonV290:
libRequestedTierV728 := 136
Gosub, LibSelectedButtonV290
return

Farm139ButtonV290:
libRequestedTierV728 := 139
Gosub, LibSelectedButtonV290
return

LibSelectedButtonV290:
; V2026 fix: tat ca 4 nut 130/133/136/139 dung DUY NHAT START chung.
; Khong kiem tra thanh/map 103/263-266 o day: MapControlActionV168 se
; tu doc map hien tai bang F-ON, nap INI va chay tu dong vang.
libRunningV728 := FarmControlRunningV186() || IsObject(farmMapPauseV52) || cainPausedV10 || farmUserPausedV2026
if (libRunningV728 && farmControlOwnerV186="LIB" && libRequestedTierV728=libScrollTierV290)
{
    FarmUserPauseToggleV2026("LIB")
    return
}
; Doi tier trong khi dang Farm LIB: dung phien cu truoc khi Start tier moi.
if (libRunningV728 && farmControlOwnerV186="LIB")
    FarmButtonStopV1()
libScrollTierV290 := libRequestedTierV728
; Khong tao mot cach chon diem Start thu hai theo selection cua ListBox.
; Duy nhat FarmStartRowV394() quyet dinh dong vang tai START chung.
libRunChoiceV281 := false
farm130ButtonDispatchV257 := true
try
    Gosub, MapControlButtonV168
finally
    farm130ButtonDispatchV257 := false
return

LibFarmLevelV292(level)
{
    return level>0 && level!=1 && level!=40 && level!=75 && level!=103 && level!=109
}

MapScrollFarmV269(mapName)
{
    return mapName="LIB"
}

Map130EntryArmV257(hwnd,mapName:="LIB")
{
    global scosEntryV162,pickupImageOn,packetWatchArmedV1,backgroundPidV63,libScrollTierV290,libAutoTicketV293,farmEntryGoldV315
    global mapRunResumeV210,coordRunSelectedV210,coordManualRowV59,coordPinnedYellowV136
    if (packetWatchArmedV1 || !BackgroundBindV63(hwnd))
        return false
    level := FarmCurrentLevelV143()
    if (level!=103 && !LibFarmLevelV292(level))
        return false
    ; Quay lai qua CONG CU sau hoi sinh: GIU map da khoa.
    ; Chi mo ve moi trong Map130EntryTick moi duoc xoa khoa map.
    mapRunResumeV210 := false,coordRunSelectedV210 := false
    coordManualRowV59 := 0,coordPinnedYellowV136 := 0
    scosEntryV162 := {map:mapName,pid:backgroundPidV63,until:A_TickCount+180000,phase:level=103 ? "WP" : "MAP",row:1,last:0,pickup:pickupImageOn,shiftX:5050,shiftY:5036}
    FarmSharedEntryOptionsV781(scosEntryV162)
    scosEntryV162.autoTicketV293 := true
    scosEntryV162.scrollTierV290 := libScrollTierV290
    scosEntryV162.scrollClassV290 := libScrollTierV290=133 ? 2389 : libScrollTierV290=136 ? 2390 : libScrollTierV290=139 ? 2391 : 2348
    PickupEnabledSetV71(false,true,false)
    SetTimer, ScosEntryTimerV162, 250
    FarmPickupSyncV57(0,0,-1,true)
    PortalLogWriteV66("MAP_STAGE1_START map=LIB destination=LIVE_MAP town=103 scroll_at=5050,5036")
    return true
}


Map130ScrollV257(ctx,inv,scrollClass)
{
    items := V9SnapshotAllItems({h:ctx.h,inv:inv,first:D2ReadU32(ctx.h,inv+0x10)})
    for uid,item in items
        if (item.cls=scrollClass
            && D2ReadU8V18(ctx.h,item.data)=2 && item.loc=0 && item.owner=inv
            && D2ReadU32(ctx.h,item.unit+0x10)!=3 && D2ReadU32(ctx.h,item.unit+0x10)!=5)
        {
            PortalLogWriteV66("MAP_SCROLL_FOUND map=LIB uid=" . uid . " class=" . item.cls . " itemdata=02 next=USE_ONCE")
            return uid
        }
    PortalLogWriteV66("MAP_SCROLL_WAIT map=LIB class=" . scrollClass . " reason=NO_SELECTED_SCROLL_IN_INVENTORY","scroll_wait_LIB",2000)
    return 0
}

Map130EntryTickV257(r,ctx,player,ByRef pb,level,px,py)
{
    global coordSavedV15,mapFarmStartPendingV170,scosEntryV162
    global libFarmPinnedMapV2026,lib263EntryV841
    if (LibFarmLevelV292(level))
    {
        MapEntryFirstBuffFinishV248(r,ctx,player,level,px,py)
        return
    }
    if (level!=103)
        return
    if (r.phase="WP")
    {
        if (!r.libTownRouteDoneV11)
        {
            if (FarmNoFightFlowV8(r,ctx,pb,103,"LIB_TOWN")!="DONE")
                return
            r.libTownRouteV11 := FarmRoutePointsV724().Clone()
            last := r.libTownRouteV11[r.libTownRouteV11.Length()]
            r.shiftX := last.x,r.shiftY := last.y
            FarmCommonRouteEndV3(r)
            r.libTownRouteDoneV11 := true
            return
        }
        if (r.ticketErrorHoldV769)
            return
        if (r.autoTicketV293 && !r.ticketDoneV293)
        {
            r.ticketDoneV293 := true
            PortalLogWriteV66("LIB_AUTO_TICKET_START tier=" . r.scrollTierV290 . " count=1")
            if (!Ticket130RunV265(1,(r.scrollTierV290-130)//3,r))
            {
                r.ticketErrorHoldV769 := true
                FarmErrorKeepV769("AUTO_TICKET_FAILED")
                ToolTipInfoV386("Tạo vé chưa hoàn tất; giữ phiên farm và vật phẩm, chờ xử lý lỗi.")
                SetTimer, RemoveToolTip, -6000
                return
            }
            if (!IsObject(scosEntryV162) || scosEntryV162!=r)
                return
            r.until := A_TickCount+180000
            return
        }
        r.phase := "SHIFT",r.last := 0
        PortalLogWriteV66("MAP130_TOWN_GOLD_DONE next=USE_ITEM_AT_LAST_SAVED_POINT waypoint=SKIPPED")
        return
    }
    if (r.phase="SHIFT")
    {
        if ((px-r.shiftX)**2+(py-r.shiftY)**2>4)
        {
            point := {x:r.shiftX,y:r.shiftY}
            FarmNoFightFlowV8(r,ctx,pb,103,"LIB_SCROLL_POINT",[point],point)
            return
        }
        FarmCommonRouteEndV3(r)
        inv := D2ReadU32(ctx.h,player+0x60)
        cursor := inv ? PickupCursorV4(ctx.h,inv) : false
        if (!IsObject(cursor) || cursor.unit)
            throw Exception("Đang có vật phẩm trên chuột")
        chosen := Map130ScrollV257(ctx,inv,r.scrollClassV290)
        if (!chosen)
            return
        ; Day moi la bat dau MO MAP MOI (scroll moi), khong phai hoi sinh ve cong cu.
        libFarmPinnedMapV2026 := false,lib263EntryV841 := false
        PortalLogWriteV66("LIB_FON_UNPIN reason=NEW_SCROLL_PORTAL tier=" . r.scrollTierV290)
        r.oldPortals := NaoPortalsV188(ctx,pb)
        bytes := [0x20],SigDwordV147(bytes,chosen),SigDwordV147(bytes,px),SigDwordV147(bytes,py)
        r.phase := "PORTAL_WAIT",r.openAt := A_TickCount
        SigPacketV147(ctx,bytes)
        PortalLogWriteV66("MAP_SCROLL_OPEN_PORTAL tier=" . r.scrollTierV290 . " uid=" . chosen . " xy=" . px . "," . py . " use_once=1")
        return
    }
    if (A_TickCount-r.openAt>15000)
        throw Exception("Không xác nhận được cổng vào map LIB")
    if (A_TickCount-r.openAt<500)
        return
    portals := NaoPortalsV188(ctx,pb),target := false,count := 0
    for uid,portal in portals
        if (!r.oldPortals.HasKey(uid) && (portal.x-r.shiftX)**2+(portal.y-r.shiftY)**2<=144)
            target := portal,count++
    if (count>1)
        throw Exception("Có nhiều cổng mới gần nhau - dừng để tránh vào nhầm")
    if (!IsObject(target))
    {
        if (!r.scanLogAt || A_TickCount-r.scanLogAt>=1000)
        {
            r.scanLogAt := A_TickCount
            PortalLogWriteV66("MAP130_PORTAL_SCAN room=" . V92Hex(NumGet(pb,0x1C,"UInt")) . " portals=" . portals.Count() . " new_near=" . count)
        }
        return
    }
    if (!r.portalLogged)
    {
        r.portalLogged := true
        PortalLogWriteV66("MAP130_PORTAL_FOUND uid=" . target.uid . " xy=" . target.x . "," . target.y . " distance2=" . ((px-target.x)**2+(py-target.y)**2))
    }
    if ((px-target.x)**2+(py-target.y)**2>9)
    {
        point := {x:target.x,y:target.y}
        FarmNoFightFlowV8(r,ctx,pb,103,"LIB_PORTAL_" . target.uid,[point],point)
        return
    }
    FarmCommonRouteEndV3(r)
    if (r.enterAt && A_TickCount-r.enterAt<1500)
        return
    sent := MapStage9V373(ctx,103,target)
    r.enterAt := A_TickCount
    PortalLogWriteV66("MAP130_ENTER_PORTAL uid=" . target.uid . " xy=" . target.x . "," . target.y . " expected=LIVE_MAP method=NATIVE queued=" . sent)
}

