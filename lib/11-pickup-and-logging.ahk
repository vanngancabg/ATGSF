TownStoreMoneyV636(ctx)
{
    global sigCancelV147
    before := ScosGoldReadV229(ctx.h,ctx.player)
    if (!IsObject(before))
        throw Exception("Chuyển Kho: chưa đọc được tiền, chưa gửi lệnh cất")
    amount := Min(before.gold,Max(0,before.limit-before.bank))
    if (amount<=0)
    {
        SigLogV147("TOWN_STORE_GOLD_SKIP wallet=" . before.gold . " bank=" . before.bank . " limit=" . before.limit)
        return true
    }
    bytes := ScosGoldPacketV231(amount)
    SigPacketV147(ctx,bytes)
    started := A_TickCount
    Loop
    {
        SigCheckV147(ctx)
        if (sigCancelV147)
            throw Exception("Đã dừng cất tiền")
        now := ScosGoldReadV229(ctx.h,ctx.player)
        if (IsObject(now) && before.gold-now.gold=amount && now.bank-before.bank=amount)
        {
            SigLogV147("TOWN_STORE_GOLD_CONFIRMED amount=" . amount . " wallet=" . now.gold . " bank=" . now.bank)
            return true
        }
        if (A_TickCount-started>4000)
            throw Exception("Chuyển Kho: chưa xác nhận tiền vào kho; không gửi lặp")
        Sleep, 100
    }
}


PickupCatalogArrangeV638()
{
    global pickupCatalogNamesV11
    groups := [],others := [],node := TV_GetChild(0)
    while (node)
    {
        row := PickupCatalogCopyV638(node)
        if (row.name="Angelic")
        {
        }
        else if (row.children.Length() || RegExMatch(row.name,"i)^(?:Rune|Gem|Shrine|Oil|Unique|Charm|Material|Signet|Cycle|Arcane|Corrupted)$"))
            groups.Push(row)
        else
            others.Push(row)
        node := TV_GetNext(node)
    }
    groups := PickupCatalogRowsSortV638(groups),others := PickupCatalogRowsSortV638(others)
    TV_Delete(),pickupCatalogNamesV11 := {}
    for _,row in groups
        PickupCatalogRestoreV638(row)
    if (others.Length())
    {
        otherRoot := PickupCatalogNodeV11("Khác",0,false)
        for _,row in others
            PickupCatalogRestoreV638(row,otherRoot)
    }
}

PickupCatalogCopyV638(node)
{
    global pickupCatalogNamesV11
    row := {name:pickupCatalogNamesV11[node],children:[]},child := TV_GetChild(node)
    while (child)
    {
        row.children.Push(PickupCatalogCopyV638(child))
        child := TV_GetNext(child)
    }
    return row
}

PickupCatalogRestoreV638(row,parent:=0)
{
    node := PickupCatalogNodeV11(row.name,parent,false)
    for _,child in row.children
        PickupCatalogRestoreV638(child,node)
    TV_Modify(node,"Sort -Expand")
    return node
}


PickupCatalogRowsSortV638(rows)
{
    order := "",result := []
    for index,row in rows
        order .= row.name . "`t" . index . "`n"
    Sort, order
    Loop, Parse, order, `n, `r
        if (RegExMatch(A_LoopField,"`t(\d+)$",m))
            result.Push(rows[m1+0])
    return result
}

TownStoreGroundStageV639(ctx,item)
{
    SigCheckV147(ctx)
    if (item.cls=1204)
        throw Exception("Chuyển Kho: giữ Cube để luồng nhặt thường lấy lại")
    ground := SigGroundV147(ctx),live := ground[item.uid]
    if (!IsObject(live) || live.cls!=item.cls || live.q!=item.q
        || D2ReadU32(ctx.h,live.data+0x14)!=item.storeSeedV629)
        throw Exception("Chuyển Kho: vật dưới đất đã đổi, chưa nhặt")
    TownStoreInventorySlotV629(ctx,item)
    cursor := PickupCursorV4(ctx.h,ctx.inv)
    if (!IsObject(cursor) || cursor.unit)
        throw Exception("Chuyển Kho: chuột chưa trống trước khi nhặt")
    bytes := [0x16],SigDwordV147(bytes,4),SigDwordV147(bytes,item.uid),SigDwordV147(bytes,0)
    SigLogV147("TOWN_STORE_GROUND_PICK uid=" . item.uid . " class=" . item.cls . " packet=16/4/uid/0")
    SigPacketV147(ctx,bytes)
    staged := SigWaitLocV147(ctx,item.uid,0,4000,item.unit)
    if (!IsObject(staged) || staged.cls!=item.cls || staged.q!=item.q
        || D2ReadU32(ctx.h,staged.data+0x14)!=item.storeSeedV629)
        throw Exception("Chuyển Kho: chưa xác nhận đúng vật dưới đất đã vào túi")
    return staged
}

TownStoreReadCloseV641(r,ctx)
{
    global sigCubeUiOpenV159
    ctx.storeOccupiedV641 := false
    TownStoreOpenV629(ctx,sigCubeUiOpenV159)
    previous := "",stable := 0,started := A_TickCount
    Loop
    {
        SigCheckV147(ctx)
        occupied := {},fingerprint := "",count := 0
        for uid,a in SigSnapshotV147(ctx)
            if (a.loc=4 && D2ReadU32(ctx.h,a.unit+0x10)=0)
            {
                size := TicketItemSizeV277(ctx,a.cls)
                if (a.x<0 || a.y<0 || a.x+size.w>14 || a.y+size.h>14)
                    throw Exception("Chuyển Kho: tọa độ đồ trong kho ngoài vùng ô 0–13; dừng đọc")
                count++,fingerprint .= uid . ":" . a.x . "," . a.y . ";"
                Loop, % size.h
                {
                    yy := a.y+A_Index-1
                    Loop, % size.w
                        occupied[(a.x+A_Index-1) . "," . yy] := true
                }
            }
        stable := fingerprint=previous ? stable+1 : 0,previous := fingerprint
        if (stable>=2)
            break
        if (A_TickCount-started>3000)
            throw Exception("Chuyển Kho: dữ liệu kho chưa ổn định; chưa chuyển đồ")
        Sleep, 150
    }
    ctx.storeOccupiedV641 := occupied
    SigLogV147("TOWN_STORE_GRID_READ ui=OPEN items=" . count . " occupied_cells=" . occupied.Count() . " next=CLOSE_THEN_PACKET")
    TownStoreMoneyV636(ctx)
    TownStoreCloseBatchV636(r,ctx)
    SigLogV147("TOWN_STORE_GRID_READY ui=CLOSED occupied_cells=" . occupied.Count())
}

TownStoreCommitV641(ctx,item,slot,size)
{
    all := SigSnapshotV147(ctx),a := all[item.uid]
    if (!IsObject(a))
        a := SigLiveItemV148(ctx,item.uid,item.unit)
    x := IsObject(a) && a.x>=0 && a.x+size.w<=14 ? a.x : slot.x
    y := IsObject(a) && a.y>=0 && a.y+size.h<=14 ? a.y : slot.y
    Loop, % size.h
    {
        yy := y+A_Index-1
        Loop, % size.w
            ctx.storeOccupiedV641[(x+A_Index-1) . "," . yy] := true
    }
    SigLogV147("TOWN_STORE_GRID_RESERVED uid=" . item.uid . " xy=" . x . "," . y . " size=" . size.w . "x" . size.h)
    return true
}

CoordEscapeVectorV661(dx,dy,direction:=1,px:=0,py:=0)
{
    if (IsObject(direction))
        return {x:direction.x-px,y:direction.y-py}
    if (direction="PLUS45" || direction="MINUS45")
    {
        sign := direction="PLUS45" ? 1 : -1,c := Sqrt(0.5)
        return {x:(dx-sign*dy)*c,y:(sign*dx+dy)*c}
    }
    if (direction="LEFT")
        return {x:dy,y:-dx}
    if (direction="RIGHT")
        return {x:-dy,y:dx}
    return {x:dx*direction,y:dy*direction}
}

CoordWalkEscapeSetV661(e,stage,px,py)
{
    global chaseCheckSecV9
    e.walkRecoveryV642 := true
    e.phase := "T1",e.phaseAt := A_TickCount
    e.probeX := px,e.probeY := py
    e.probeDist := Sqrt((px-e.point.x)**2+(py-e.point.y)**2)
    e.lastSend := 0,e.teleSent := false,e.teleAt := 0
    e.teleProbeX := px,e.teleProbeY := py
    if (e.HasKey("targetX"))
        e.Delete("targetX")
    AutoMonsterAttackLogV2("STUCK_PHASE name=T1 row=" . e.row . " from=" . px . "," . py)
}

CoordWalkEscapeAdvanceV661(e,px,py)
{
    switch e.phase
    {
        case "T1": next := "W1"
        case "W1": next := "B2"
        case "B2": next := "W2"
        case "W2": next := "T2"
        case "T2": next := "W2b"
        case "W2b": next := "B3"
        case "B3": next := "W3"
        case "W3": next := "T3"
        case "T3": next := "W3b"
        default: next := "BB"
    }
    e.phase := next,e.phaseAt := A_TickCount
    e.probeX := px,e.probeY := py
    e.probeDist := Sqrt((px-e.point.x)**2+(py-e.point.y)**2)
    e.lastSend := 0,e.teleSent := false,e.teleAt := 0
    if (e.HasKey("targetX"))
        e.Delete("targetX")
    AutoMonsterAttackLogV2("STUCK_PHASE name=" . next . " row=" . e.row)
}

CoordWalkEscapeTickV642(h,ByRef pb,pid,r,e,point,manualGoal:=false,arrivalRadiusV1251:=5)
{
    global chaseCheckSecV9,teleportIntervalSecV56,teleportKeyV55,boMoveMinimumV456,coordSavedV15
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort"),now := A_TickCount
    manual := CoordRecoveryGoalValidV655(manualGoal)
    waitMs := Max(1,chaseCheckSecV9)*1000
    goalDist := Sqrt((px-point.x)**2+(py-point.y)**2)
    if (!manual)
        FarmTeleWalkObserveV2026(r,px,py)
    initial := Sqrt((e.stuckX-point.x)**2+(e.stuckY-point.y)**2)
    if (initial-goalDist >= Max(5,boMoveMinimumV456))
    {
        CoordWalkEscapeResumeV642(r,e,"RECOVERY_PROGRESS")
        return false
    }
    if (e.phase="B2" || e.phase="B3")
    {
        if (!e.HasKey("targetX"))
        {
            dx := e.returnXV608-px,dy := e.returnYV608-py
            if (dx*dx+dy*dy<1)
                dx := 1,dy := 0
            side := e.phase="B2" ? "PLUS45" : "MINUS45"
            vector := CoordEscapeVectorV661(dx,dy,side)
            length := Sqrt(vector.x**2+vector.y**2)
            e.targetX := Round(px+vector.x*5/length)
            e.targetY := Round(py+vector.y*5/length)
            e.backProbeX := px,e.backProbeY := py
            AutoMonsterAttackLogV2("STUCK_BACK side=" . side . " row=" . e.row
                . " from=" . px . "," . py . " target=" . e.targetX . "," . e.targetY)
        }
        dist := Sqrt((px-e.targetX)**2+(py-e.targetY)**2)
        travelled := Sqrt((px-e.backProbeX)**2+(py-e.backProbeY)**2)
        if (dist<=1 || travelled>=5 || now-e.phaseAt>=waitMs)
        {
            CoordWalkEscapeAdvanceV661(e,px,py)
            return true
        }
        if (!e.lastSend || now-e.lastSend>=200)
        {
            moveSentV2026 := CoordStuckMoveV392(pid,e.targetX,e.targetY,point.level,r,e.row,manualGoal)
            if (moveSentV2026 && !manual)
                FarmTeleWalkDispatchedV2026(r,px,py)
            e.lastSend := now
        }
        return true
    }
    if (e.phase="BB")
    {
        dist := Sqrt((px-e.returnXV608)**2+(py-e.returnYV608)**2)
        if (dist<=5)
        {
            CoordWalkEscapeResumeV642(r,e,"RESTART_B_TO_C")
            return false
        }
        ; A blocked return-to-B gets one more complete escape sequence.
        if (now-e.phaseAt>=waitMs)
        {
            if (!e.extraEscapeV903)
            {
                e.extraEscapeV903 := true
                CoordWalkEscapeSetV661(e,"T1",px,py)
                AutoMonsterAttackLogV2("STUCK_MOVE_RETRY_EXTRA row=" . e.row . " attempt=2")
                return true
            }
            CoordWalkEscapeResumeV642(r,e,"RECOVERY_RETRY_EXHAUSTED")
            return false
        }
        if (!e.lastSend || now-e.lastSend>=200)
        {
            moveSentV2026 := CoordStuckMoveV392(pid,e.returnXV608,e.returnYV608,point.level,r,e.row,manualGoal)
            if (moveSentV2026 && !manual)
                FarmTeleWalkDispatchedV2026(r,px,py)
            e.lastSend := now
        }
        return true
    }
    if (SubStr(e.phase,1,1)="T")
    {
        if (teleportKeyV55="" || point.level=163)
        {
            CoordWalkEscapeAdvanceV661(e,px,py)
            return true
        }
        if (!e.teleSent)
        {
            ; Farm: if the previous Tele has not been followed by real walking,
            ; skip another Tele and try the recovery walking phase instead.
            if (!manual && r.teleRequiresWalkV2026)
            {
                PortalLogWriteV66("BC_STUCK_TELE_SKIPPED row=" . e.row
                    . " reason=NO_WALK_AFTER_PREVIOUS_TELE next=WALK", "BC_STUCK_TELE_SKIPPED", 1000)
                CoordWalkEscapeAdvanceV661(e,px,py)
                return true
            }
            beforeX := px,beforeY := py
            sent := manual ? CoordGoTeleportToV303(h,pb,manualGoal,1)
                : CoordTeleportStuckV55(h,pb,pid,point,1)
            if (sent)
            {
                r.lastTeleport := A_TickCount
                e.teleSent := true,e.teleAt := now
                e.teleProbeX := beforeX,e.teleProbeY := beforeY
                if (!manual)
                {
                    r.teleRequiresWalkV2026 := true
                    r.teleWalkCommandAtV2026 := 0
                }
                return true
            }
            if (now-e.phaseAt>=500)
                CoordWalkEscapeAdvanceV661(e,px,py)
            return true
        }
        if (now-e.teleAt<350)
            return true
        CoordWalkEscapeAdvanceV661(e,px,py)
        return true
    }
    if (goalDist<=Max(1,arrivalRadiusV1251))
    {
        CoordWalkEscapeResumeV642(r,e,"ARRIVED_C")
        return false
    }
    if (goalDist < e.probeDist-1)
    {
        e.probeDist := goalDist
        e.phaseAt := A_TickCount
    }
    if (now-e.phaseAt>=waitMs)
    {
        CoordWalkEscapeAdvanceV661(e,px,py)
        return true
    }
    if (!e.lastSend || now-e.lastSend>=200)
    {
        moveSentV2026 := CoordStuckMoveV392(pid,point.x,point.y,point.level,r,e.row,manualGoal)
        if (moveSentV2026 && !manual)
            FarmTeleWalkDispatchedV2026(r,px,py)
        e.lastSend := now
    }
    return true
}


FarmPreBuffCombatCheckV710(h,player,ByRef pb,pid,finished := false)
{
    routePointsV724 := FarmRoutePointsV724()
    global gameItemActionOwner,xRunning,zRunning,farmBuffExclusiveV621,monsterRadiusV48,moveDelayMsV810
    global farmRunEpochV535,form6KeyV716,scosEntryV162,farmControlOwnerV186
    static origin := false,lastAttackAt := 0,lastMoveAt := 0

    if (finished)
    {
        origin := false,lastAttackAt := 0,lastMoveAt := 0
        return false
    }
    room := NumGet(pb,0x1C,"UInt")
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    level := room ? CoordLevelV14(h,room) : 0
    if (!pid || !player || !level || !px || !py)
        return true
    if (!IsObject(origin) || origin.pid!=pid || origin.player!=player
        || origin.level!=level || origin.epoch!=farmRunEpochV535)
    {
        origin := {pid:pid,player:player,level:level,epoch:farmRunEpochV535
            ,x:px,y:py,radiusSq:(Max(1,monsterRadiusV48)/2)**2}
        lastAttackAt := 0,lastMoveAt := 0
        PortalLogWriteV66("PRE_BUFF_BEGIN center=" . px . "," . py
            . " radius=" . Sqrt(origin.radiusSq) . " return_before_buff=1")
    }
    returnX := origin.x,returnY := origin.y
    if (farmControlOwnerV186="SCOS" && level=270)
    {
        buffPoint := IsObject(scosEntryV162) && scosEntryV162.map="SCOS"
            && scosEntryV162.pid=pid ? scosEntryV162.scosInwardV696.point : false
        if (!IsObject(buffPoint))
            buffPoint := ScosMap3NextPointV696(routePointsV724)
        if (!IsObject(buffPoint) || buffPoint.row!=2)
            return true
        returnX := buffPoint.x,returnY := buffPoint.y
    }
    if (xRunning || zRunning || gameItemActionOwner!="" || farmBuffExclusiveV621)
        return true
    playerMode := D2ReadU32(h,player+0x10)
    if (playerMode=0 || playerMode=17)
        return true

    best := false,bestDist := 0x7FFFFFFF,seen := {},scanComplete := true
    rooms := MonsterLoadedRoomsV20(h,room)
    if (!IsObject(rooms) || !rooms.Length())
        return true
    for _,loadedRoom in rooms
    {
        if (!MonsterBossProbeReadV1(h,loadedRoom+0x74,4,head))
        {
            scanComplete := false
            continue
        }
        u := NumGet(head,0,"UInt")
        Loop, 1024
        {
            if (!u || seen.HasKey(u))
                break
            seen[u] := true
            if (!MonsterBossProbeReadV1(h,u,0xEC,ub))
            {
                scanComplete := false
                break
            }
            unit := u,u := NumGet(ub,0xE8,"UInt")
            uid := NumGet(ub,0x0C,"UInt"),mode := NumGet(ub,0x10,"UInt")
            if (NumGet(ub,0,"UInt")=1 && uid && mode!=0 && mode!=12
                && !MonsterClassExcludedV11(NumGet(ub,4,"UInt"),h,unit))
            {
                if (!MonsterBossProbeReadV1(h,NumGet(ub,0x2C,"UInt"),0x20,mb))
                    scanComplete := false
                else
                {
                    x := NumGet(mb,2,"UShort"),y := NumGet(mb,6,"UShort")
                    centerDist := (x-origin.x)**2+(y-origin.y)**2
                    dist := (x-px)**2+(y-py)**2
                    if (centerDist<=origin.radiusSq && dist<bestDist)
                        best := {unit:unit,uid:uid,x:x,y:y,dist:dist,cls:NumGet(ub,4,"UInt")}
                            ,bestDist := dist
                }
            }
            if (u=unit || (A_Index=1024 && u))
            {
                scanComplete := false
                break
            }
        }
    }
    if (IsObject(best))
    {
        if (!NativeDispatchReadyV10(true) || !AutoMonsterPacketCleanupV1())
            return true
        if (A_TickCount-lastAttackAt>=250)
        {
            if (QuickBuffHasKey(form6KeyV716))
            {
                if (!QuickBuffSend(form6KeyV716))
                    return true
            }
            else if (!LastAttackSkillV20())
                return true
            if (NativeMapTestV5(true,{pid:pid,unit:best.unit,uid:best.uid}))
            {
                lastAttackAt := A_TickCount
                AttackIdTipV12(best.cls,Round(Sqrt(best.dist),1))
                PortalLogWriteV66("PRE_BUFF_ATTACK uid=" . best.uid
                    . " center=" . origin.x . "," . origin.y . " radius=" . Sqrt(origin.radiusSq))
            }
        }
        return true
    }
    if (!scanComplete)
    {
        if (!origin.preBuffSkipAt) 
            origin.preBuffSkipAt := A_TickCount
        if (A_TickCount - origin.preBuffSkipAt > 1500) 
            return false
        return true
    }
    if (!FarmAttackHoldReleaseV15() || !AutoMonsterPacketCleanupV1())
        return true
    if ((px-returnX)**2+(py-returnY)**2>1)
    {
        if (NativeDispatchReadyV10(true) && A_TickCount-lastMoveAt>=Max(0,moveDelayMsV810))
        {
            if (NativeMovePointV14(pid,returnX,returnY,level,false,false,true,false,false))
            {
                lastMoveAt := A_TickCount
                PortalLogWriteV66("PRE_BUFF_RETURN to=" . returnX . "," . returnY . " buff=WAIT")
            }
        }
        return true
    }
    if (playerMode=2 || playerMode=3 || playerMode=6)
        return true
    return false
}

CheckAndRestoreBackgroundFarm(pid, currentLevel)
{
    global outsideLevelV22, backgroundHwndV63
    static lastFarmLevel := 0

    if (currentLevel != 0 && currentLevel == outsideLevelV22 && lastFarmLevel != outsideLevelV22)
    {
        PortalLogWriteV66("MAP_FARM_RESTORE_BACKGROUND level=" . currentLevel . " -> Kich hoat lai chay nen.")
        
        if (backgroundHwndV63 && DllCall("IsWindow", "Ptr", backgroundHwndV63))
        {
            DllCall("PostMessage", "Ptr", backgroundHwndV63, "UInt", 0x1C, "UPtr", 1, "Ptr", 0)
            DllCall("PostMessage", "Ptr", backgroundHwndV63, "UInt", 0x6, "UPtr", 1, "Ptr", 0)
            
            WinGet, minmax, MinMax, ahk_id %backgroundHwndV63%
            if (minmax == -1)
            {
                DllCall("ShowWindowAsync", "Ptr", backgroundHwndV63, "Int", 4)
            }
        }
    }
    lastFarmLevel := currentLevel
}
D2GetProcessIdFromHandle(hProcess)
{
    return DllCall("GetProcessId", "Ptr", hProcess, "UInt")
}
CoordWalkEscapeResumeV642(r,e,reason)
{
    r.retryV611 := false
    if (e.HasKey("targetX"))
        e.Delete("targetX")
    FarmStuckResumeV608(r)
    ; Chi voi duong di NHAT, khong xem het chuoi thoat ket la da thanh cong.
    ; Truyen BLOCKED cho FarmPickupMoveResultV905 de thoat dich tam va ve C.
    if (reason="RECOVERY_RETRY_EXHAUSTED" && r.HasKey("itemMoveV910") && r.itemMoveV910)
        r.phase := "BLOCKED"
    AutoMonsterAttackLogV2("STUCK_DONE row=" . e.row . " phase=" . e.phase
        . " reason=" . reason . " next=" . (r.phase="BLOCKED" ? "ITEM_STUCK" : "RESUME_SAME_COORDINATE"))
    return false
}

GD1IdentifyButtonV643:
if (SigBackgroundBindV179())
{
    gd1IdentifyPidV643 := D2GetActiveGamePidV95()
    RouteRecorderIdentityV658("Đưa chuột lên NPC, kho, WP hoặc cổng trong game; đọc sau 3 giây.")
    ToolTipInfoV386("Đưa chuột lên NPC, kho, WP hoặc cổng trong game; đọc sau 3 giây.")
    SetTimer, GD1IdentifyTimerV643, -3000
}
return

GD1IdentifyTimerV643:
GD1IdentifyReadV643(gd1IdentifyPidV643)
return

GD1IdentifyReadV643(pid)
{
    global GD1IdentityTextV643,backgroundPidV63
    if (!pid || D2GetActiveGamePidV95()!=pid)
        return
    base := D2GetModuleBaseV35(pid,"D2Client.dll"),h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        unit := D2ReadU32(h,base+0x11B834)
        if (!MonsterBossProbeReadV1(h,path,0x20,pb) || !unit || !MonsterBossProbeReadV1(h,unit,0x18,ub))
        {
            RouteRecorderIdentityV658("Chưa nhận diện được; bấm Nhận Diện và giữ chuột trên đối tượng trong game.")
            ToolTipInfoV386("Chưa nhận diện được đối tượng; bấm Nhận Diện và giữ chuột trên đối tượng trong game.")
            return
        }
        kind := NumGet(ub,0,"UInt"),cls := NumGet(ub,4,"UInt"),uid := NumGet(ub,12,"UInt")
        if (kind!=1 && kind!=2 && kind!=4 && kind!=5)
            return
        level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        targetPath := D2ReadU32(h,unit+0x2C)
        if (!MonsterBossProbeReadV1(h,targetPath,0x18,tp))
            return
        x := kind=1 ? NumGet(tp,2,"UShort") : NumGet(tp,0x0C,"UInt")
        y := kind=1 ? NumGet(tp,6,"UShort") : NumGet(tp,0x10,"UInt")
        label := kind=1 ? "NPC / Quái" : kind=4 ? "Vật phẩm" : cls=267 ? "Kho" : "Cổng / WP / Đối tượng"
        text := label . "`r`nlevel=" . level . " type=" . kind . " class=" . cls . " uid=" . uid
            . " x=" . x . " y=" . y
        if (kind=4)
        {
            data := NumGet(ub,0x14,"UInt")
            text .= " itemdata=" . Format("{:02X}",D2ReadU8V18(h,data))
        }
        text .= "`r`nplayer=" . NumGet(pb,2,"UShort") . "," . NumGet(pb,6,"UShort")
        Clipboard := text
        if (RouteRecorderIdentityV658(text . "`r`nĐã copy thông tin."))
            return
        Gui, GD1IdentityV643:New, +AlwaysOnTop +ToolWindow, Nhận diện GD1 - đã copy
        Gui, GD1IdentityV643:Font, s10, Segoe UI
        Gui, GD1IdentityV643:Add, Edit, x10 y10 w470 h125 Multi ReadOnly vGD1IdentityTextV643, %text%
        Gui, GD1IdentityV643:Show, w490 h145
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

GD1IdentityV643GuiClose:
GD1IdentityV643GuiEscape:
Gui, GD1IdentityV643:Destroy
return
RetiredThreadCleanupV690:
    RetiredThreadCleanupV690Tick()
return

RetiredThreadCleanupV690Tick()
{
    global retiredThreadsV690
    static busy := false
    if (busy)
        return
    if (!IsObject(retiredThreadsV690) || !retiredThreadsV690.Count())
    {
        SetTimer, RetiredThreadCleanupV690, Off
        return
    }
    busy := true
    try
    {
        for key,entry in retiredThreadsV690.Clone()
        {
            done := DllCall("WaitForSingleObject","Ptr",entry.th,"UInt",0)=0
            dead := RemoteProcessEndedV740(entry.h)
            if (!done && !dead)
                continue
            if (done && !dead)
                DllCall("VirtualFreeEx","Ptr",entry.h,"Ptr",entry.remote,"UPtr",0,"UInt",0x8000)
            DllCall("CloseHandle","Ptr",entry.th)
            DllCall("CloseHandle","Ptr",entry.h)
            retiredThreadsV690.Delete(key)
        }
        if (!IsObject(retiredThreadsV690) || !retiredThreadsV690.Count())
            SetTimer, RetiredThreadCleanupV690, Off
    }
    finally
        busy := false
}

RemoteThreadFinishV740(h,th,remote,wait)
{
    global retiredThreadsV690
    if (th && wait!=0)
    {
        previous := A_IsCritical
        Critical, On
        if (!IsObject(retiredThreadsV690))
            retiredThreadsV690 := {}
        pid := DllCall("GetProcessId","Ptr",h,"UInt")
        retiredThreadsV690[h . "|" . remote] := {h:h,th:th,remote:remote,pid:pid,at:A_TickCount}
        SetTimer, RetiredThreadCleanupV690, 100
        if (previous)
            Critical, %previous%
        else
            Critical, Off
        DebugTraceWrite("packet","REMOTE_TIMEOUT_TRACKED pid=" . pid . " next=WAIT_THREAD_OR_PROCESS_EXIT")
        return false
    }
    if (remote)
        DllCall("VirtualFreeEx","Ptr",h,"Ptr",remote,"UPtr",0,"UInt",0x8000)
    if (th)
        DllCall("CloseHandle","Ptr",th)
    if (h)
        DllCall("CloseHandle","Ptr",h)
    return wait=0
}

RemoteThreadBusyV740(pid)
{
    global retiredThreadsV690
    RetiredThreadCleanupV690Tick()
    for _,entry in retiredThreadsV690
        if (!pid || !entry.pid || entry.pid=pid)
            return true
    return false
}

FarmRuntimeErrorV740(e)
{
    global farmErrorRetryAtV740
    static lastNotice := 0
    farmErrorRetryAtV740 := A_TickCount+1000
    if (!lastNotice || A_TickCount-lastNotice>=3000)
    {
        lastNotice := A_TickCount
        try DebugTraceWrite("farm","FARM_RETRY_ERROR message=" . e.Message . " line=" . e.Line . " function=" . e.What)
        try FonInfoPushV385("Farm gặp lỗi tạm thời; giữ phiên và thử lại sau 1 giây.")
    }
}

RemoteProcessEndedV740(h)
{
    code := 259
    return DllCall("GetExitCodeProcess","Ptr",h,"UIntP",code) && code!=259
}


FarmCenterPolicyV741(pid,level:=0)
{
    global autoMonsterAttackOn,coordRouteV16,roomExploreV89,cainNoFightV361
    if (!autoMonsterAttackOn || !Stage2FightEnabledV9() || cainNoFightV361 || IsObject(roomExploreV89))
        return false
    r := coordRouteV16,points := FarmRoutePointsV724()
    if (!IsObject(r) || r.pid!=pid || !IsObject(points) || !points.Length()
        || (level && r.startLevel!=level) || (BossSearchActiveV430(pid) && !BOFinalRouteActiveV451(pid)))
        return false
    row := r.combatRowV627>=1 && r.combatRowV627<=points.Length() ? r.combatRowV627 : r.next
    return row>=1 && row<=points.Length() && points[row].level=r.startLevel && r.phase!="DONE"
}

FarmCenterCaptureV741(pid)
{
    global coordRouteV16,farmRunEpochV535
    if (!FarmCenterPolicyV741(pid))
        return false
    r := coordRouteV16,points := FarmRoutePointsV724()
    if (r.phase="NEXT" && r.next>=1 && r.next<=points.Length())
        row := r.next
    else
        row := r.combatRowV627>=1 && r.combatRowV627<=points.Length() ? r.combatRowV627 : r.next
    p := points[row]
    c := {pid:pid,epoch:farmRunEpochV535,route:r,row:row,level:p.level,x:p.x,y:p.y
        ,radius:Max(1,MonsterRadiusGetV239()),phase:"ATTACK",attacked:false,pickupPass:0}
    return c
}

FarmCenterPendingV741(pid)
{
    global farmCenterCycleV741,farmRunEpochV535,coordRouteV16,autoMonsterAttackOn
    c := farmCenterCycleV741
    if (!IsObject(c) || c.pid!=pid)
        return false
    points := FarmRoutePointsV724(),p := points[c.row]
    if (!autoMonsterAttackOn || c.epoch!=farmRunEpochV535 || c.route!=coordRouteV16
        || !IsObject(p) || p.level!=c.level || p.x!=c.x || p.y!=c.y)
    {
        farmCenterCycleV741 := false
        return false
    }
    return true
}

FarmCenterNextV756(c)
{
    points := FarmRoutePointsV724(),row := c.row+1,p := points[row]
    ; V1190: Dòng kế tiếp trùng tọa độ vẫn là một dòng lộ trình hợp lệ.
    ; Không trả false khi C trùng B: false trước đây bị hiểu nhầm là HẾT TUYẾN,
    ; làm Scos dòng 116=117 (5180,10660) chuyển GD3 quá sớm.
    if (!IsObject(p) || row>points.Length() || p.level!=c.level || p.x<1 || p.y<1)
        return false
    return {row:row,level:p.level,x:p.x,y:p.y}
}

FarmCenterGoalValidV756(c)
{
    if (!IsObject(c.forwardV756))
        return true
    live := FarmCenterNextV756(c),goal := c.forwardV756
    return IsObject(live) && live.row=goal.row && live.level=goal.level
        && live.x=goal.x && live.y=goal.y
}

; ROUTE 1->2->3: Khong nhay dong. Chi xac nhan den diem khi vao ban kinh diem do.
; B->C: Chi mot tieu chuan den C, dung BK danh tren giao dien Form 6.
; Dung chung cho CHECK, MOVE, TELE, va xu ly vuot C.
FarmCenterArrivedV756(px,py,gx,gy)
{
    radiusV756 := Max(1,MonsterRadiusGetV239())
    return (px-gx)**2+(py-gy)**2<=radiusV756*radiusV756
}

FarmCenterAdvanceV756(h,player,pid,c,px,py)
{
    global coordRouteV16,farmCenterCycleV741,farmFightLockV626
    global coordNoTargetSinceV14,coordCastPendingV50,portalBuffV85,roomExploreV89
    global monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44,farmScanListV682,farmScanSelectedV682
    if (FarmItemRoutePausedV903(pid))
        return false
    if (!FarmCenterPendingV741(pid) || farmCenterCycleV741!=c || !IsObject(c.forwardV756)
        || !FarmCenterGoalValidV756(c))
        return false
    goal := c.forwardV756
    ; B->C: vao ban kinh danh da cai thi coi nhu den, giao cho luong danh chinh.
    if (!FarmCenterArrivedV756(px,py,goal.x,goal.y))
        return false
    ; MOVE chi kiem tra da gan C, khong mo cong / danh / buff.
    ; Dieu kien mo cong duoc LUONG CHINH xet sau khi nhan DONE.
    if (!FarmCenterPendingV741(pid) || farmCenterCycleV741!=c || !FarmCenterGoalValidV756(c))
        return false
    ; V991: vi tri (px,py) da duoc doc/kiem tra level o luong goi.
    ; Khong doc lai path lan 2: doc loi tam thoi khong duoc lam mat MOVE DONE.
    r := coordRouteV16
    r.anchor := c.row,r.yellow := goal.row,r.combatRowV627 := goal.row,r.next := goal.row
    r.phase := "NEXT",r.forwardFloorV303 := c.row
    r.battlePending := false,r.lastDispatch := 0,r.legRow := 0,r.firstMoveAttempted := false
    r.escapeV84 := false,r.stuckProbe := false,r.bypass := false,r.moveProbe := false
    r.startAtYellowV367 := false,r.lastArrivalV343 := A_TickCount
    coordNoTargetSinceV14 := A_TickCount-250
    ; V970: handoff minh bach. MOVE bao DONE/ARRIVED va giu cycle cho
    ; FarmCenterCheckV741 (luong farm chinh) tu chon PRE_BUFF hay ATTACK_FIRST.
    c.row := goal.row,c.x := goal.x,c.y := goal.y,c.forwardV756 := false
    c.phase := "MOVE_DONE",c.moveStateV905 := "DONE",c.moveResultV905 := "ARRIVED"
    c.attackStateV905 := "RUNNING",c.attackResultV905 := ""
    c.attackEmptyCountV906 := 0,c.attackEmptyAtV906 := 0
    c.attacked := false,c.roadWatchV914 := false
    ; Sang diem moi: khong dung ket qua Tele va bo dem retry cua diem cu.
    c.teleProbeV2026 := false,c.teleAvoidUntilV2026 := 0
    c.teleWalkPendingV2026 := false,c.preferredTeleRowV2026 := 0
    r.teleRequiresWalkV2026 := false,r.teleWalkCommandAtV2026 := 0
    farmFightLockV626 := false
    monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
    farmScanListV682 := [],farmScanSelectedV682 := 0
    PortalLogWriteV66("BC_MOVE_DONE row=" . goal.row
        . " result=ARRIVED next=MAIN_CHECK_PORTAL_OR_NORMAL_ATTACK")
    FarmCombatViewV624(pid,false,"MOVE DONE tại C; giao cho luồng chính kiểm tra mở cổng")
    CoordBoxRefreshV15()
    return true
}

FarmFlowScanGroundItemsV902(h,player,pid,room,level,px,py,infoOnly)
{
    global farmCenterCycleV741,farmItemLockV625,farmFightLockV626
    global pickupImageOn,pickupGroupActiveV26,pickupRadius,pickupRoundResetV1
    global farmGroundItemCountV710,monsterCombatUidV45,monsterChaseV44,monsterRoadAreaV51
        itemLockSeenV625 := false,itemScanCompleteV625 := true
        itemOnRoad := false,itemCx := 0,itemCy := 0,itemBestV590 := 0x7FFFFFFF
        deferItemGuardV768 := !infoOnly && FarmCenterPendingV741(pid)
            && !farmCenterCycleV741.attacked
        ; Trong luong diem B->C, chi timer nhat rieng duoc tao tin do moi.
        ; Bo quet FARM chi kiem tra lai do da duoc khoa, khong chiem quyen tai tam khac.
        if (!infoOnly && pickupImageOn && !pickupGroupActiveV26 && Stage2PickupEnabledV9() && !BOCommonActiveV444(pid)
            && (!FarmCenterPolicyV741(pid,level) || IsObject(farmItemLockV625)))
        {
            itemScanSeen := {}
            itemScanRadiusSqV625 := Max(1,pickupRadius)**2
            for _,ir in MonsterLoadedRoomsV20(h,room)
            {
                if (!MonsterBossProbeReadV1(h,ir+0x74,4,itemHeadV625))
                {
                    itemScanCompleteV625 := false
                    continue
                }
                iu := NumGet(itemHeadV625,0,"UInt")
                Loop, 1024
                {
                    if (!iu || itemScanSeen.HasKey(iu))
                        break
                    itemScanSeen[iu] := true
                    if (!MonsterBossProbeReadV1(h,iu,0xEC,itemUnitV625))
                    {
                        itemScanCompleteV625 := false
                        break
                    }
                    if (D2ReadU32(h,iu)=4)
                    {
                        idata := D2ReadU32(h,iu+0x14),imode := D2ReadU32(h,iu+0x10),icls := D2ReadU32(h,iu+4)
                        if (idata && icls!=1214 && (imode=3 || imode=5))
                        {
                            iip := D2ReadU32(h,iu+0x2C)
                            if (iip && MonsterBossProbeReadV1(h,iip,0x14,itemPathV625))
                            {
                                iix := NumGet(itemPathV625,0x0C,"UInt"),iiy := NumGet(itemPathV625,0x10,"UInt")
                                idist := (iix-px)**2+(iiy-py)**2
                                lockDistV625 := IsObject(farmItemLockV625)
                                    ? (iix-farmItemLockV625.x)**2+(iiy-farmItemLockV625.y)**2 : idist
                                lockRadiusSqV625 := IsObject(farmItemLockV625) ? farmItemLockV625.pickupRadiusSqV648 : pickupRadius*pickupRadius
                                itemDetectRadiusSqV625 := IsObject(farmItemLockV625)
                                    ? lockRadiusSqV625 : itemScanRadiusSqV625
                                if (lockDistV625<=itemDetectRadiusSqV625
                                    && !FarmPickupTimedIgnoreV1602(pid,level,D2ReadU32(h,iu+0x0C))
                                    && PickupFileHasRuleV97(icls,D2ReadU8V18(h,idata),idata,h,iu))
                                {
                                    farmGroundItemCountV710++
                                    itemLockSeenV625 := true
                                    if (!deferItemGuardV768 && idist<itemBestV590)
                                    {
                                        itemOnRoad := true,itemCx := iix,itemCy := iiy,itemBestV590 := idist
                                        itemBestUidV1602 := D2ReadU32(h,iu+0x0C),itemBestClsV1602 := icls
                                    }
                                }
                            }
                            else
                                itemScanCompleteV625 := false
                        }
                    }
                    inx := D2ReadU32(h,iu+0xE8)
                    if (inx=iu)
                    {
                        itemScanCompleteV625 := false
                        break
                    }
                    iu := inx
                    if (A_Index=1024 && iu)
                        itemScanCompleteV625 := false
                }
            }
            if (IsObject(farmItemLockV625) && !itemLockSeenV625 && itemScanCompleteV625)
            {
                ; V918: ONE missed ground-item scan must not cancel Farm's temporary
                ; target while ITEM_MOVE/ITEM_ATTACK/PICKUP owns the move/attack.
                ; Only the shared pickup handoff may finish this workflow.
                farmItemOwnedV918 := FarmCenterPendingV741(pid)
                    && (farmCenterCycleV741.phase="ITEM_MOVE"
                        || farmCenterCycleV741.phase="ITEM_ATTACK"
                        || farmCenterCycleV741.phase="PICKUP"
                        || farmCenterCycleV741.phase="PICKUP_BUSY")
                if (farmItemOwnedV918)
                    PortalLogWriteV66("BC_ITEM_LOCK_KEEP phase=" . farmCenterCycleV741.phase
                        . " center=" . farmItemLockV625.x . "," . farmItemLockV625.y
                        . " reason=SCAN_MISS_WAIT_PICKUP_DONE", "BC_ITEM_LOCK_KEEP", 1000)
                else
                {
                    farmItemLockV625 := false
                    AutoMonsterAttackLogV2("ITEM_GUARD_UNLOCK reason=NO_WANTED_GROUND_ITEMS_IN_FIXED_CIRCLE")
                }
            }
            if (!IsObject(farmItemLockV625) && itemOnRoad)
            {
                pickupRoundResetV1 := true
                farmFightLockV626 := false
                itemGuardRadiusV648 := ItemCenterRadiusGetV810()
                farmItemLockV625 := {pid:pid,player:player,level:level,x:itemCx,y:itemCy
                    ,uid:itemBestUidV1602,cls:itemBestClsV1602,startedAtV1602:A_TickCount
                    ,radiusSq:itemGuardRadiusV648*itemGuardRadiusV648,pickupRadiusSqV648:Max(1,pickupRadius)**2
                    ,source:"ITEM_PICKUP_LOCK",row:0}
                monsterCombatUidV45 := 0,monsterChaseV44 := false,monsterRoadAreaV51 := false
                AutoMonsterPacketCleanupV1()
                AutoMonsterAttackLogV2("ITEM_GUARD_LOCK center=" . itemCx . "," . itemCy . " combat_radius=" . itemGuardRadiusV648 . " pickup_radius=" . Max(1,pickupRadius))
            }
        }
        if (IsObject(farmItemLockV625))
        {
            if (itemLockSeenV625 && itemCx>0 && itemCy>0)
                farmItemLockV625.pickupX := itemCx,farmItemLockV625.pickupY := itemCy
            itemOnRoad := true,itemCx := farmItemLockV625.x,itemCy := farmItemLockV625.y
        }
        return {found:itemOnRoad,x:itemCx,y:itemCy,complete:itemScanCompleteV625}
}

FarmParentNextV767(phase)
{
    global farmCenterCycleV741
    ; ITEM_ATTACK: giu tam vat pham trong suot cac lan gui lenh danh va kiem tra ket.
    if (phase="ITEM_ATTACK" && IsObject(farmCenterCycleV741))
        return "ITEM_ATTACK"
    if (phase="ROAD_ATTACK" && IsObject(farmCenterCycleV741))
        return "ROAD_ATTACK"
    return (phase="ATTACK_FIRST" || phase="ATTACK_MORE") && IsObject(farmCenterCycleV741) ? "ATTACK_MORE" : ""
}

FarmParentBeginV767(pid,level)
{
    global farmCenterCycleV741,farmTownBuffRearmV1002,portalBuffDeferredV998
    global farmRunEpochV535,currentProfile,routeMapIdV21,farmControlOwnerV186
    if (FarmCenterPendingV741(pid) || !FarmCenterPolicyV741(pid,level))
        return false
    c := FarmCenterCaptureV741(pid)
    if (!IsObject(c))
        return false
    rearmV1002 := farmTownBuffRearmV1002
    if (IsObject(rearmV1002) && rearmV1002.pid=pid && rearmV1002.level=c.level
        && rearmV1002.row=c.row && rearmV1002.profile=currentProfile
        && rearmV1002.mapId=routeMapIdV21 && rearmV1002.owner=farmControlOwnerV186)
    {
        portalBuffDeferredV998 := {pid:pid,route:c.route,epoch:farmRunEpochV535
            ,fromRow:rearmV1002.fromRow,row:c.row}
        farmTownBuffRearmV1002 := false
        PortalLogWriteV66("FARM_TOWN_BUFF_RESUME row=" . c.row . " from=" . rearmV1002.fromRow)
    }
    c.phase := "ATTACK_FIRST",c.attacked := false,c.pickupPass := 0
    c.attackStateV905 := "RUNNING", c.attackResultV905 := ""
    c.attackEmptyCountV906 := 0, c.attackEmptyAtV906 := 0
    farmCenterCycleV741 := c
    PortalLogWriteV66("BC_ENGINE_BUILD=20261029_ROAD_FON_PICKUP_TELE_WALK_FIRST"
        . " row=" . c.row . " level=" . c.level)
    return true
}

FarmParentAttackEmptyV767(pid)
{
    global farmCenterCycleV741,farmScanListV682,farmItemLockV625,coordRouteV16,portalBuffDeferredV998
    global coordCastPendingV50,coordCastLastRowV50,portalCastKeyV50
    global monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44,chaseCheckSecV9
    if (!FarmCenterPendingV741(pid))
        return false
    c := farmCenterCycleV741
    if (c.phase!="ATTACK_FIRST" && c.phase!="ATTACK_MORE"
        && c.phase!="ITEM_ATTACK" && c.phase!="ROAD_ATTACK")
        return false
    if (IsObject(farmScanListV682) && farmScanListV682.Length())
        return false
    ; Quet rong >=3 luot day du lien tiep thi chuyen sang buoc tiep theo ngay.
    ; Quai xuat hien / quet khong day du se reset bo dem o luong quet.
    if (!c.attackEmptyAtV906 || A_TickCount-c.attackEmptyAtV906>750)
    {
        c.attackEmptyAtV906 := A_TickCount
        c.attackEmptyCountV906 := 1
    }
    else if (A_TickCount-c.attackEmptyAtV906>=200)
        c.attackEmptyAtV906 := A_TickCount, c.attackEmptyCountV906++
    if (c.attackEmptyCountV906<3)
        return true
    PortalLogWriteV66("BC_ATTACK_AREA_EMPTY_CONFIRMED row=" . c.row
        . " phase=" . c.phase . " empty_scans=" . c.attackEmptyCountV906)
    ; Quet rong da xac nhan: bo UID tan cong cu de khong chan CoordCastTickV50.
    monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
    FarmAttackHoldReleaseV15()
    ; Dung tam quet nhan vat: danh sach quai can duong xong -> di tiep C.
    ; Khong tang dong vang, khong doi dich C, khong quay ve diem B.
    if (c.phase="ROAD_ATTACK")
    {
        c.phase := "MOVE",c.roadX_V2026 := 0,c.roadY_V2026 := 0
        c.attackEmptyCountV906 := 0,c.attackEmptyAtV906 := 0
        rRoadV2026 := coordRouteV16
        if (IsObject(rRoadV2026) && rRoadV2026.pid=pid)
            rRoadV2026.battlePending := false,rRoadV2026.stuckProbe := false
                ,rRoadV2026.lastDispatch := 0,rRoadV2026.firstMoveAttempted := false
        PortalLogWriteV66("BC_ROAD_CLEAR row=" . c.row . " next="
            . (IsObject(c.forwardV756) ? c.forwardV756.row : 0) . " resume=MOVE")
        return true
    }
    ; Quet sach tai diem moi xet cong/buff/di tiep. Tin hieu item duoc xu ly rieng.
    if (c.phase!="ITEM_ATTACK")
    {
        ; V1002: cong o diem N CHI duoc mo sau khi quet rong on dinh.
        if (coordCastPendingV50 && coordCastLastRowV50=c.row && portalCastKeyV50!="")
            c.portalCastReadyV1002 := true
        ; V998: chi mo khoa BUFF o N+1 khi quet danh tai diem nay da sach.
        pendingV998 := portalBuffDeferredV998
        if (IsObject(pendingV998) && pendingV998.pid=pid && pendingV998.route=c.route
            && pendingV998.epoch=c.epoch && pendingV998.row=c.row)
            c.portalBuffReadyV998 := true
        c.attackEmptyCountV906 := 0
        c.phase := "CHECK"
        return true
    }
    ; Chi ITEM_ATTACK (sau khi DEN VI TRI DO) moi duoc giao quyen nhat.
    ; If the lock vanishes during the combat scan, do not complete the Farm row.
    ; FarmCenterCheckV741 can restore the original center on the next tick.
    if (!IsObject(farmItemLockV625))
    {
        PortalLogWriteV66("BC_ITEM_LOCK_MISSING phase=ITEM_ATTACK next=RECOVER_NOT_C")
        return true
    }
    c.attackStateV905 := "DONE"
    c.attackResultV905 := "AREA_CLEAR_CONFIRMED"
    c.phase := Stage2PickupEnabledV9() ? "PICKUP" : "CHECK"
    PortalLogWriteV66("BC_ITEM_AREA_CLEAR center=" . farmItemLockV625.x . "," . farmItemLockV625.y . " next=PICKUP")
    return true
}

FarmCenterCheckV741(h,player,pid,mainTurnV768:=false)
{
    global farmCenterCycleV741,autoMonsterAttackOn,farmRunEpochV535,coordRouteV16,farmItemLockV625
    global monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44
    global portalBuffV85,coordCastPendingV50,coordCastLastRowV50,portalCastKeyV50,pickupImageOn,pickupRadius
    global portalBuffDeferredV998,pestiPointPendingV28,lastAttackPendingV20
    global farmTownResumeSaveV1002,currentProfile,routeMapIdV21,farmControlOwnerV186
    if (!FarmCenterPendingV741(pid))
        return false
    c := farmCenterCycleV741
    FarmPortalBuffDeadlineV1301(pid,"CENTER_TICK")
    ; V1002: luu diem dang di truoc khi co the bi cham cong ve thanh.
    ; Khong dong vao route, anchor, bo dem hoac luong MOVE.
    saveRowV1002 := c.phase="MOVE" && IsObject(c.forwardV756) ? c.forwardV756.row : c.row
    ; Neu da mo cong o N va danh xong, quay lai phai tiep N+1.
    if (c.phase="CHECK" && IsObject(portalBuffDeferredV998)
        && portalBuffDeferredV998.pid=pid && portalBuffDeferredV998.route=c.route
        && portalBuffDeferredV998.fromRow=c.row && !coordCastPendingV50)
        saveRowV1002 := portalBuffDeferredV998.row
    farmTownResumeSaveV1002 := {pid:pid,level:c.level,row:saveRowV1002
        ,profile:currentProfile,mapId:routeMapIdV21,owner:farmControlOwnerV186,at:A_TickCount}
    ; Item signals only own the Farm cycle while the item is already in pickup range.
    if (FarmItemRoutePausedV903(pid) && c.phase!="ITEM_MOVE" && c.phase!="ITEM_ATTACK"
        && c.phase!="PICKUP" && c.phase!="PICKUP_BUSY")
    {
        c.resumeAfterItemV2026 := c.phase
        monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
        c.phase := "PICKUP",c.attackStateV905 := "DONE",c.attackResultV905 := "ITEM_IN_PICKUP_RANGE"
        c.fencePickupV1185 := false
        c.attackEmptyCountV906 := 0,c.attackEmptyAtV906 := 0
        FarmAttackHoldReleaseV15()
        PortalLogWriteV66("BC_ITEM_SIGNAL center=" . farmItemLockV625.x . "," . farmItemLockV625.y
            . " first=PICKUP_IN_RANGE")
    }
    if (c.phase="ITEM_MOVE")
        return FarmCenterStepV766(h,player,pid)  ; toi do se goi nhat ngay, khong danh
    if (c.phase="ITEM_ATTACK")
    {
        ; Legacy phase tu phien cu: khong tao BK danh item. Phuc hoi ve
        ; ITEM_MOVE neu van co item lock, nguoc lai quay ve CHECK route.
        if (FarmItemRoutePausedV903(pid))
        {
            c.phase := "ITEM_MOVE"
            PortalLogWriteV66("BC_ITEM_LEGACY_RECOVER next=ITEM_MOVE")
        }
        else
        {
            c.phase := "CHECK"
            PortalLogWriteV66("BC_ITEM_LEGACY_RECOVER next=CHECK item=GONE")
        }
        return true
    }
    ; Item da nhat xong/het tin hieu: quay lai danh quai tai tam dang do,
    ; khong di thang C neu truoc luc nhat dang danh quai can duong/B.
    if (c.phase="CHECK" && c.resumeAfterItemV2026!="")
    {
        resumeV2026 := c.resumeAfterItemV2026,c.resumeAfterItemV2026 := ""
        if (resumeV2026="ROAD_ATTACK" || resumeV2026="ATTACK_FIRST"
            || resumeV2026="ATTACK_MORE")
        {
            c.phase := resumeV2026
            c.attackEmptyCountV906 := 0,c.attackEmptyAtV906 := 0
            PortalLogWriteV66("BC_ITEM_RESUME phase=" . c.phase . " row=" . c.row)
            return false
        }
        if (resumeV2026="MOVE")
        {
            c.phase := "MOVE"
            PortalLogWriteV66("BC_ITEM_RESUME phase=MOVE goal="
                . (IsObject(c.forwardV756) ? c.forwardV756.row : 0))
            return true
        }
    }
    ; MOVE DONE: luong chinh kiem tra input mo cong.
    ; Diem N: QUET DANH SACH ROI MO CONG, KHONG DANH LAI SAU CONG.
    ; Diem N+1: quet sach quai quanh diem roi moi buff.
    if (c.phase="MOVE_DONE")
    {
        ; V991: MOVE DONE chi duoc giao cho luong chinh, khong cho callback phu tieu thu.
        if (!mainTurnV768)
            return true
        if (c.moveStateV905!="DONE" || c.moveResultV905!="ARRIVED")
            return true
        ; Danh dau dung DONG DICH C (khong dung dong xuat phat B).
        CoordCastMarkV50(c.row)
        if (coordCastPendingV50 && portalCastKeyV50!="")
            PortalLogWriteV66("BC_MOVE_DONE_MAIN row=" . c.row
                . " portal=YES next=NORMAL_ATTACK_CLEAR_THEN_PORTAL")
        if (coordCastPendingV50 && portalCastKeyV50="")
            coordCastPendingV50 := false
        pendingV998 := portalBuffDeferredV998
        if (IsObject(pendingV998) && pendingV998.pid=pid && pendingV998.route=c.route
            && pendingV998.epoch=c.epoch && pendingV998.row=c.row)
        {
            ; Diem N+1: DANH TRUOC, BUFF SAU. Khong buff qua co pending thuong.
            pestiPointPendingV28 := false,lastAttackPendingV20 := false
            PortalLogWriteV66("BC_PORTAL_BUFF_NEXT_ARRIVED row=" . c.row . " next=SCAN_ATTACK_THEN_BUFF")
        }
        c.phase := "ATTACK_FIRST"
        PortalLogWriteV66("BC_MOVE_DONE_MAIN row=" . c.row
            . " portal=NO next=NORMAL_MONSTER_SCAN")
        return false
    }
    ; V1002: chi luong chinh sau khi danh rong xac nhan moi mo cong tai N.
    if (c.phase="CHECK" && c.portalCastReadyV1002)
    {
        c.portalCastReadyV1002 := false
        if (coordCastPendingV50 && coordCastLastRowV50=c.row && portalCastKeyV50!="")
        {
            c.phase := "PORTAL_CAST"
            PortalLogWriteV66("BC_PORTAL_AFTER_CLEAR row=" . c.row . " next=CAST_THEN_ROUTE")
            return true
        }
    }
    if (c.phase="PORTAL_CAST")
    {
        if (coordCastPendingV50)
        {
            ; Goi ham mo cong hien tai, KHONG goi tu luong MOVE.
            CoordCastTickV50(h,player,pid)
            return true
        }
        ; V1002: da danh sach TRUOC khi mo cong; khong click danh tai cho sau cong.
        ; Luong buff ngoai route neu co van giu xu ly cu.
        c.phase := IsObject(portalBuffV85) ? "PORTAL_BUFF" : "CHECK"
        PortalLogWriteV66("BC_PORTAL_CAST_FINISHED row=" . c.row . " next=" . c.phase)
        return true
    }
    if (c.phase="PORTAL_BUFF")
    {
        if (IsObject(portalBuffV85))
        {
            FarmPortalBuffTickV85(h,player,pid)
            return true
        }
        c.phase := "CHECK"
        PortalLogWriteV66("BC_PORTAL_BUFF_DONE row=" . c.row . " next=ROUTE_CHECK")
        return true
    }
    ; N+1: giu nguyen thoi diem buff, thay chuoi noi bo bang Form 1/3/5/6.
    if (c.phase="CHECK" && c.portalBuffReadyV998)
    {
        pendingV998 := portalBuffDeferredV998
        c.portalBuffReadyV998 := false
        if (IsObject(pendingV998) && pendingV998.pid=pid && pendingV998.route=c.route
            && pendingV998.epoch=c.epoch && pendingV998.row=c.row)
        {
            portalBuffDeferredV998 := false
            ; N+1 danh sach xong: bat day buff day du, co chuyen set phu/kill 1/kill 2.
            portalBuffV85 := {pid:pid,route:coordRouteV16,phase:"FORM1",buffSetPhuV1001:1,startTickV1301:A_TickCount}
            c.phase := "PORTAL_BUFF"
            PortalLogWriteV66("BC_PORTAL_BUFF_NEXT_START from=" . pendingV998.fromRow
                . " row=" . c.row . " order=ATTACK_CLEAR_THEN_BUFF_FORM1_FORM3_FORM5_FORM6")
            return true
        }
    }
    ; ITEM_ATTACK duoc quet/danh trong timer FARM voi ban kinh BK/2 quanh do.
    if (c.phase="ITEM_ATTACK" || c.phase="ATTACK" || c.phase="ATTACK_FIRST"
        || c.phase="ATTACK_MORE" || c.phase="ROAD_ATTACK")
        return false
    if (c.phase="MOVE")
    {
        ; FIX: neu B can mo cong, khong duoc vao worker MOVE va lap BLOCK mai.
        ; Quet quai da ket thuc o B; chi chuyen sang PORTAL_CAST de goi ham cast GOC.
        if (coordCastPendingV50 && coordCastLastRowV50<=c.row)
        {
            c.phase := "PORTAL_CAST",c.portalCastReadyV1002 := false
            PortalLogWriteV66("BC_PORTAL_FROM_MOVE row=" . c.row
                . " cast_mark_row=" . coordCastLastRowV50
                . " next=CoordCastTickV50 before_C", "BC_PORTAL_FROM_MOVE", 300)
            return true
        }
        ; Giu cycle B->C va dich C trong toan bo qua trinh di + xet ket.
        if (!mainTurnV768)
            return true
        ; Den C thi nhan C, giao cho luong danh BK tai C (khong bo qua diem).
        ; Neu packet/remote dispatch dang ban nhung da gan C, van bao DONE.
        if (IsObject(c.forwardV756)
            && MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,movePbV991)
            && CoordLevelV14(h,NumGet(movePbV991,0x1C,"UInt"))=c.level
            && FarmCenterArrivedV756(NumGet(movePbV991,2,"UShort"),NumGet(movePbV991,6,"UShort")
                ,c.forwardV756.x,c.forwardV756.y))
        {
            FarmCenterAdvanceV756(h,player,pid,c,NumGet(movePbV991,2,"UShort"),NumGet(movePbV991,6,"UShort"))
            return true
        }
        ; Trong khi di: quet BK quanh nhan vat truoc MOI lenh di chuyen.
        ; Gap quai -> khoa tam tai vi tri nhan vat, dung di va danh het.
        roadScanV2026 := FarmApproachScanV722(h,player,pid,true)
        if (!IsObject(roadScanV2026) || !roadScanV2026.complete)
        {
            PortalLogWriteV66("BC_MOVE_SCAN_WAIT row=" . c.row
                . " reason=MONSTER_SCAN_INCOMPLETE", "BC_MOVE_SCAN_WAIT", 1000)
            return true
        }
        if (IsObject(roadScanV2026.target))
        {
            c.roadX_V2026 := roadScanV2026.x,c.roadY_V2026 := roadScanV2026.y
            c.phase := "ROAD_ATTACK",c.attackEmptyCountV906 := 0,c.attackEmptyAtV906 := 0
            c.attacked := false
            if (IsObject(coordRouteV16) && coordRouteV16.pid=pid)
                coordRouteV16.stuckProbe := false,coordRouteV16.escapeV84 := false
            MovementCtrlSetV78(false,0,"FarmRoadEncounterV2026")
            PortalLogWriteV66("BC_ROAD_ATTACK center=" . c.roadX_V2026 . "," . c.roadY_V2026
                . " uid=" . roadScanV2026.target.uid . " goal="
                . (IsObject(c.forwardV756) ? c.forwardV756.row : 0)
                . " next=KILL_ALL_THEN_RESUME_MOVE")
            return false  ; Tra quyen cho CUNG bo quet/danh Form6 chinh o tick nay.
        }
        ; Khong co quai tren duong moi di tiep; khong tick buff/cong tai MOVE.
        if (!FarmCenterRoutePrepareV910(pid,c))
        {
            PortalLogWriteV66("BC_MOVE_PREPARE_FAIL row=" . c.row
                . " goal=" . (IsObject(c.forwardV756) ? c.forwardV756.row : 0)
                . " phase=MOVE next=CHECK", "BC_MOVE_PREPARE_FAIL", 1000)
            c.phase := "CHECK"
            return true
        }
        ; MOVE chi di chuyen; danh quai duoc xu ly tai tam Farm chinh.
        ; Move-stuck recovery is handled by CoordStuckTickV84 in the MOVE worker.
        ; Chi them log de xac dinh timer MOVE co chay va co gui lenh hay khong.
        PortalLogWriteV66("BC_MOVE_TICK B=" . c.row
            . " C=" . (IsObject(c.forwardV756) ? c.forwardV756.row : 0)
            . " phase=" . c.phase, "BC_MOVE_TICK", 1000)
        ; Tren duong da quet rong moi di; vao BK C se doi tam sang C de danh.
        moveSentV1113 := FarmCenterWalkResumeV765(pid,c)
        if (!moveSentV1113 && c.phase="MOVE")
            PortalLogWriteV66("BC_MOVE_WAIT_DISPATCH B=" . c.row
                . " C=" . (IsObject(c.forwardV756) ? c.forwardV756.row : 0)
                . " reason=MOVE_WORKER_RETURN_FALSE", "BC_MOVE_WAIT_DISPATCH", 1000)
        return true
    }
    if (c.phase!="CHECK" && c.phase!="RETURN")
        return FarmCenterStepV766(h,player,pid)
    ; CHECK chua xu ly xong (vi packet/buff dang ban) thi GIU CHECK.
    ; Chi FarmFlowRouteAdvanceV900 duoc quyen doi thanh MOVE sau khi da xac dinh C.
    return FarmCenterStepV766(h,player,pid)
}

FarmCenterStepV766(h,player,pid)
{
    global farmCenterCycleV741,farmScanListV682,farmScanSelectedV682
    global xRunning,zRunning,gameItemActionOwner,farmBuffExclusiveV621,buffSequenceRunningV555
    global monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44,teleportIntervalSecV56
    global farmItemLockV625,pickupRoundResetV1,pickupImageOn,pickupRadius
    if (!FarmCenterPendingV741(pid))
        return false
    c := farmCenterCycleV741
    if (c.phase="PICKUP_BUSY")
        return FarmFlowPickupBusyV900(pid,c)
    if (c.phase="ITEM_MOVE" && (xRunning || zRunning || gameItemActionOwner!=""
        || farmBuffExclusiveV621 || buffSequenceRunningV555))
        PortalLogWriteV66("BC_ITEM_MOVE_WAIT owner=" . gameItemActionOwner
            . " buff=" . (xRunning || zRunning || farmBuffExclusiveV621 || buffSequenceRunningV555)
            . " reason=CONTROL_BUSY","BC_ITEM_MOVE_WAIT",1000)
    if (c.phase="ATTACK" || xRunning || zRunning || gameItemActionOwner!=""
        || farmBuffExclusiveV621 || buffSequenceRunningV555)
        return true
    if (!MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,pp))
        return true
    level := CoordLevelV14(h,NumGet(pp,0x1C,"UInt")),mode := D2ReadU32(h,player+0x10)
    if (level!=c.level || mode=0 || mode=17 || FarmReviveTownLevelV295(level))
    {
        farmCenterCycleV741 := false
        return false
    }
    if (!FarmAttackReleaseWaitV15() || !AutoMonsterPacketCleanupV1() || RemoteThreadBusyV740(pid))
    {
        if (c.phase="RETURN" && farmCenterCycleV741=c)
            farmCenterCycleV741 := false
        return true
    }
    if (!FarmCenterPendingV741(pid) || farmCenterCycleV741!=c)
        return true
    if (c.phase="ITEM_MOVE")
        return FarmFlowApproachItemV910(h,player,pid,c)
    if (c.phase="PICKUP")
        return FarmFlowApproachPickupV900(h,player,pid,c)
    return FarmFlowRouteAdvanceV900(h,player,pid,c)
}

; Luong nhat rieng chi chay trong PICKUP_BUSY; het nhat thi tra lai timer farm.
FarmPickupHandoffTimerV901:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    SetTimer, FarmPickupHandoffTimerV901, Off
    return
}
if (!autoMonsterAttackOn)
{
    SetTimer, FarmPickupHandoffTimerV901, Off
    return
}
handPidV901 := D2GetActiveGamePidV95()
if (!handPidV901 || !FarmCenterPendingV741(handPidV901)
    || farmCenterCycleV741.phase!="PICKUP_BUSY")
{
    SetTimer, FarmPickupHandoffTimerV901, Off
    if (autoMonsterAttackOn)
        SetTimer, AutoMonsterAttackTimer, 250
    return
}
handoffCycleV905 := farmCenterCycleV741
FarmFlowPickupBusyV900(handPidV901,handoffCycleV905)
if (IsObject(handoffCycleV905) && handoffCycleV905.phase!="PICKUP_BUSY")
{
    if (handoffCycleV905.pickupStateV905!="DONE")
        handoffCycleV905.pickupResultV905 := "INTERRUPTED"
    PortalLogWriteV66("FARM_PICKUP_DONE result=" . handoffCycleV905.pickupResultV905, "FARM_PICKUP_DONE", 500)
}
if (!FarmCenterPendingV741(handPidV901)
    || farmCenterCycleV741.phase!="PICKUP_BUSY")
{
    SetTimer, FarmPickupHandoffTimerV901, Off
    if (autoMonsterAttackOn)
        SetTimer, AutoMonsterAttackTimer, 250
}
return

FarmFlowPickupBusyV900(pid,c)
{
    global farmManualStoppedV2026
    if (farmManualStoppedV2026)
        return false
    global farmItemLockV625,pickupImageOn,pickupFarmWorkV75,pickupTimerBusy,gameItemActionOwner
    global sigBusyV147,farmMapPauseV52,portalExitPendingV69,reviveBuffPendingV34,pickupRoundResetV1
    if (!pickupImageOn || !Stage2PickupEnabledV9())
    {
        farmItemLockV625 := false
        c.pickupStateV905 := "DONE",c.pickupResultV905 := "DISABLED"
        c.phase := "CHECK"
        return true
    }
    ; Da ban giao: dung ham nhat chung, khong lap lai dieu kien combat / buff / remote.
    ; Ham FarmPickupFirstV75 tu quan ly tranh trung thao tac vat pham.
    workingV905 := FarmPickupFirstV75()
    if (workingV905 || pickupFarmWorkV75 || pickupTimerBusy || gameItemActionOwner!="")
    {
        c.pickupIdleAtV905 := 0
        c.pickupActiveSeenV905 := true
        return true
    }
    if (sigBusyV147 || IsObject(farmMapPauseV52) || IsObject(portalExitPendingV69)
        || reviveBuffPendingV34 || RemoteThreadBusyV740(pid))
    {
        c.pickupIdleAtV905 := 0
        return true
    }
    if (!c.pickupIdleAtV905)
        c.pickupIdleAtV905 := A_TickCount
    else if (A_TickCount-c.pickupIdleAtV905>=10000)
    {
        farmItemLockV625 := false
        c.pickupStateV905 := "DONE",c.pickupResultV905 := "IDLE_TIMEOUT"
        c.phase := "CHECK"
        pickupRoundResetV1 := true
        PortalLogWriteV66("FARM_PICKUP_DONE result=IDLE_TIMEOUT idle_ms="
            . (A_TickCount-c.pickupIdleAtV905) . " next=RESUME_ROUTE")
    }
    ; Normally D2ScanRoomItemsV61 confirms completion after processing the queue.
    ; If scans never complete and no pickup work starts, release the route after
    ; a bounded idle wait instead of holding PICKUP_BUSY indefinitely.
    return true
}

; Giao tiep luong di chuyen -> farm: DONE chi khi da den dich hoac thoat loi.
; Khong suy dien DONE tu ket qua true/false cua lenh phat di chuyen.
FarmPickupMoveResultV905(h,ByRef pp,pid,level,px,py)
{
    global farmItemLockV625,pickupRadius
    area := farmItemLockV625
    if (!IsObject(area) || area.pid!=pid || area.level!=level)
        return {state:"DONE",result:"TARGET_LOST"}
    x := area.pickupX>0 ? area.pickupX : area.x
    y := area.pickupY>0 ? area.pickupY : area.y
    distanceSqV1185 := (px-x)**2+(py-y)**2
    if (!area.startedAtV1602)
        area.startedAtV1602 := A_TickCount
    ; Farm never dispatches movement toward a ground item.
    pickupArrivalRadiusV1302 := Max(1,pickupRadius)
    if (distanceSqV1185<=pickupArrivalRadiusV1302**2)
    {
        area.returnGoalV655 := false
        return {state:"DONE",result:"ARRIVED"}
    }
    area.returnGoalV655 := false
    return {state:"DONE",result:"OUT_OF_RANGE"}
}

; B->C item priority only hands off items already inside the pickup radius.
FarmFlowApproachItemV910(h,player,pid,c)
{
    global farmManualStoppedV2026
    if (farmManualStoppedV2026)
        return false
    global farmItemLockV625,monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44
    if (!IsObject(farmItemLockV625) || farmItemLockV625.pid!=pid
        || farmItemLockV625.level!=c.level)
    {
        c.phase := "CHECK"
        PortalLogWriteV66("BC_ITEM_MOVE_CANCEL reason=TARGET_LOST next=C")
        return true
    }
    if (!MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,pp)
        || CoordLevelV14(h,NumGet(pp,0x1C,"UInt"))!=c.level)
        return true
    px := NumGet(pp,2,"UShort"),py := NumGet(pp,6,"UShort")
    result := FarmPickupMoveResultV905(h,pp,pid,c.level,px,py)
    c.moveStateV905 := result.state,c.moveResultV905 := result.result
    if (result.state!="DONE")
        return true
    if (result.result!="ARRIVED")
    {
        ; Loi khac: khong treo tuyen C.
        farmItemLockV625 := false
        c.phase := "CHECK"
        PortalLogWriteV66("BC_ITEM_MOVE_DONE result=" . result.result . " next=C")
        return true
    }
    ; Farm chi nhat vat pham trong ban kinh hien tai, khong di lech tuyen.
    c.fencePickupV1185 := false
    ; Den do la nhat NGAY: khong quet/danh quai BK/2 quanh vat pham nua.
    ; Giu lock do va goal C cho den khi ham nhat chung bao DONE.
    c.itemTargetV918 := {pid:pid,player:farmItemLockV625.player,level:c.level
        ,x:farmItemLockV625.x,y:farmItemLockV625.y}
    monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
    c.phase := "PICKUP",c.attackStateV905 := "DONE",c.attackResultV905 := "ITEM_COMBAT_SKIPPED"
    c.attackEmptyCountV906 := 0,c.attackEmptyAtV906 := 0
    PortalLogWriteV66("BC_ITEM_ARRIVED center=" . farmItemLockV625.x . "," . farmItemLockV625.y
        . " next=PICKUP_DIRECT no_item_combat=1")
    ; Ban giao ngay cho nhat chung, khong de timer route/tele chen giua.
    return FarmFlowApproachPickupV900(h,player,pid,c)
}

FarmFlowApproachPickupV900(h,player,pid,c)
{
    global farmManualStoppedV2026
    if (farmManualStoppedV2026)
        return false
    global farmItemLockV625,monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44,pickupRoundResetV1,pickupImageOn
    if (c.attackStateV905!="DONE" || !Stage2PickupEnabledV9() || !pickupImageOn || !IsObject(farmItemLockV625))
    {
        farmItemLockV625 := false
        c.phase := "CHECK"
        return true
    }
    if (!MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,pp)
        || CoordLevelV14(h,NumGet(pp,0x1C,"UInt"))!=c.level)
        return true
    px := NumGet(pp,2,"UShort"),py := NumGet(pp,6,"UShort")
    if (IsObject(farmItemLockV625) && farmItemLockV625.pid=pid
        && farmItemLockV625.level=c.level && !c.fencePickupV1185)
    {
        moveResultV905 := FarmPickupMoveResultV905(h,pp,pid,c.level,px,py)
        c.moveStateV905 := moveResultV905.state
        c.moveResultV905 := moveResultV905.result
        if (moveResultV905.state!="DONE")
            return true
        if (moveResultV905.result!="ARRIVED")
        {
            ; Ket/loi cung DONE, nhung khong ban giao nhat sai vi tri.
            PortalLogWriteV66("FARM_ITEM_MOVE_DONE result=" . moveResultV905.result, "FARM_ITEM_MOVE_DONE", 500)
            farmItemLockV625 := false
            c.phase := "CHECK"
            return true
        }
    }
    if (!IsObject(farmItemLockV625))
    {
        c.moveStateV905 := "DONE", c.moveResultV905 := "TARGET_LOST"
        c.phase := "CHECK"
        return true
    }
    ; Chi giao quyen nhat neu vat pham van trong tam nhat hien tai.
    monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
    c.phase := "PICKUP_BUSY",c.pickupPass := 0
    c.pickupStateV905 := "RUNNING",c.pickupResultV905 := ""
    pickupRoundResetV1 := true
    SetTimer, AutoMonsterAttackTimer, Off
    FarmAttackHoldReleaseV15()
    SetTimer, FarmPickupHandoffTimerV901, 20
    PortalLogWriteV66("FARM_PICKUP_HANDOFF phase=PICKUP_BUSY attack_timer=OFF pickup_timer=ON"
        . " fence=" . (c.fencePickupV1185 ? 1 : 0)
        . " next=" . (c.fencePickupV1185 ? "TRY_PICK_THEN_TELE_IF_GROUND" : "NORMAL_PICKUP")
        ,"FARM_PICKUP_HANDOFF",500)
    return FarmFlowPickupBusyV900(pid,c)
}

FarmFlowRouteAdvanceV900(h,player,pid,c)
{
    global farmCenterCycleV741,coordCastPendingV50,coordCastLastRowV50,portalCastKeyV50
    ; Sau scan B, portal tai B la thao tac BAT BUOC truoc khi tien ve C.
    if (c.phase="CHECK" && coordCastPendingV50 && coordCastLastRowV50<=c.row)
    {
        c.phase := "PORTAL_CAST",c.portalCastReadyV1002 := false
        PortalLogWriteV66("BC_PORTAL_CHECK_TO_CAST row=" . c.row
            . " cast_mark_row=" . coordCastLastRowV50
            . " next=CoordCastTickV50", "BC_PORTAL_CHECK_TO_CAST", 300)
        return true
    }
    if (!MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,pp)
        || CoordLevelV14(h,NumGet(pp,0x1C,"UInt"))!=c.level)
        return true
    px := NumGet(pp,2,"UShort"),py := NumGet(pp,6,"UShort")
    c.radius := Max(1,MonsterRadiusGetV239())
    if (!FarmCenterGoalValidV756(c))
    {
        c.forwardV756 := false,c.phase := "CHECK",c.teleAt := 0
        return true
    }
    if (!IsObject(c.forwardV756))
        c.forwardV756 := FarmCenterNextV756(c)
    if (IsObject(c.forwardV756))
    {
        goal := c.forwardV756
        ; Khong bo qua C: bat buoc vao ban kinh C va quet danh tai C.
        if (FarmCenterArrivedV756(px,py,goal.x,goal.y))
        {
            ; V1190: hai dòng cùng tọa độ -> nhận đến C, tăng dòng vàng,
            ; KHÔNG coi C trùng B là hết map.
            if (goal.x=c.x && goal.y=c.y)
                PortalLogWriteV66("BC_ROUTE_SAME_COORD from_row=" . c.row
                    . " to_row=" . goal.row
                    . " next=ADVANCE_TO_FOLLOWING_ROW", "BC_ROUTE_SAME_COORD", 300)
            FarmCenterAdvanceV756(h,player,pid,c,px,py)
            return true
        }
        c.phase := "MOVE"
        return true
    }
    ; V1190: Không có điểm tiếp theo chưa có nghĩa là hết tuyến.
    ; Chỉ cho DONE khi đúng dòng cuối. Lỗi map / trùng tọa độ / thiếu dữ liệu
    ; phải giữ farm chờ xử lý, tuyệt đối không Save&Exit ở giữa tuyến.
    pointsV1190 := FarmRoutePointsV724()
    countV1190 := IsObject(pointsV1190) ? pointsV1190.Length() : 0
    if (!countV1190 || c.row!=countV1190)
    {
        PortalLogWriteV66("BC_ROUTE_NEXT_BLOCKED row=" . c.row
            . " total=" . countV1190 . " next_row=" . (c.row+1)
            . " reason=NOT_REAL_ROUTE_END action=KEEP_FARM_NO_GD3"
            , "BC_ROUTE_NEXT_BLOCKED", 2000)
        return true
    }
    ; Điểm cuối thực sự: đã đánh sạch và nhặt xong tại dòng cuối.
    global coordRouteV16
    r := coordRouteV16
    if (IsObject(r) && r.pid=pid && c.route=r && !FarmItemRoutePausedV903(pid))
    {
        r.anchor := c.row,r.yellow := c.row,r.next := c.row
        r.combatRowV627 := 0,r.phase := "DONE",r.forwardFloorV303 := c.row
        r.escapeV84 := false,r.stuckProbe := false,r.battlePending := false
        PortalLogWriteV66("BC_ROUTE_DONE last_row=" . c.row . " total=" . countV1190 . " next=GD3")
        CoordBoxRefreshV15()
    }
    farmCenterCycleV741 := false
    if (IsObject(r) && r.pid=pid && r.phase="DONE")
        MapStage2RouteFinishV185()
    return false
}


FarmPlayerTargetValidV741(h,player,unit,uid,pid)
{
    if (!MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,pp)
        || !MonsterBossProbeReadV1(h,unit,0x30,ub) || NumGet(ub,0,"UInt")!=1 || NumGet(ub,12,"UInt")!=uid
        || NumGet(ub,16,"UInt")=0 || NumGet(ub,16,"UInt")=12
        || !MonsterBossProbeReadV1(h,NumGet(ub,0x2C,"UInt"),0x20,mp))
        return false
    level := CoordLevelV14(h,NumGet(pp,0x1C,"UInt"))
    radius := Max(1,MonsterRadiusGetV239())
    return level && CoordLevelV14(h,NumGet(mp,0x1C,"UInt"))=level
        && (NumGet(mp,2,"UShort")-NumGet(pp,2,"UShort"))**2+(NumGet(mp,6,"UShort")-NumGet(pp,6,"UShort"))**2<=radius**2
}


FarmCenterRoutePrepareV910(pid,c)
{
    global coordRouteV16,coordNoTargetSinceV14
    global monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44
    if (!IsObject(c) || !FarmCenterGoalValidV756(c) || !IsObject(c.forwardV756)
        || !IsObject(coordRouteV16) || coordRouteV16!=c.route
        || coordRouteV16.pid!=pid)
        return false
    r := coordRouteV16,goal := c.forwardV756
    if (r.combatRowV627=c.row || r.anchor!=c.row || r.next!=goal.row)
    {
        r.combatRowV627 := 0,r.anchor := c.row,r.next := goal.row
        r.phase := "NEXT",r.forwardFloorV303 := c.row
        r.lastDispatch := 0,r.bestDist := -1,r.tries := 0
        r.legRow := 0,r.moveProbe := false,r.stuckProbe := false,r.escapeV84 := false
        r.battlePending := false,r.firstMoveAttempted := false
        coordNoTargetSinceV14 := A_TickCount-250
        monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
        PortalLogWriteV66("BC_MOVE_START B=" . c.row . " C=" . goal.row . " target=" . goal.x . "," . goal.y)
    }
    return true
}


; V940 - Uu tien teleport den dich C / vat pham neu cooldown san sang,
; neu khong gui duoc thi de NativeMovePointV14 di bo va CoordStuckTickV84 xu ly ket.
FarmBCPreferredTeleportV940(h,ByRef pb,pid,c,goal)
{
    global teleportKeyV55,teleportIntervalSecV56,coordManualTeleLastV296
    global coordRouteV16,backgroundAimV64,coordCastPendingV50,coordCastLastRowV50,portalBuffV85
    global coordNoTargetSinceV14
    castBlocksV1172 := coordCastPendingV50 && IsObject(c) && coordCastLastRowV50<=c.row
    if (!IsObject(c) || !IsObject(goal) || (c.phase!="MOVE" && c.phase!="ITEM_MOVE")
        || teleportKeyV55="" || IsObject(portalBuffV85) || castBlocksV1172)
        return false
    if (!IsGameActive() || D2GetActiveGamePidV95()!=pid || !NativeDispatchReadyV10(true)
        || !AutoMonsterPacketCleanupV1())
        return false
    if (CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=goal.level || goal.level=163)
        return false
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    dx := goal.x-px,dy := goal.y-py
    distV940 := Sqrt(dx*dx+dy*dy)
    if (distV940<1 || FarmCenterArrivedV756(px,py,goal.x,goal.y))
        return false
    lastV940 := Max(c.lastTeleV940+0,coordManualTeleLastV296+0
        ,IsObject(coordRouteV16) ? coordRouteV16.lastTeleport+0 : 0)
    cdV940 := Max(1,teleportIntervalSecV56)*1000
    ; Tele chi co tac dung neu sau lan truoc nhan vat tien gan den C.
    ; Khong tin vao KEYDOWN_QUEUED nhu mot xac nhan da dich chuyen.
    if (IsObject(c.teleProbeV2026) && A_TickCount-c.teleProbeV2026.at>=350)
    {
        prevV2026 := c.teleProbeV2026
        c.teleProbeV2026 := false
        if (prevV2026.goalRow=goal.row && A_TickCount-prevV2026.at<=5000
            && distV940>=prevV2026.dist-2)
        {
            c.teleAvoidUntilV2026 := A_TickCount+6500
            PortalLogWriteV66("BC_TELE_NO_PROGRESS row=" . goal.row
                . " before=" . Round(prevV2026.dist,1) . " after=" . Round(distV940,1)
                . " fallback=NATIVE_MOVE_AND_STUCK retry_after_ms=6500")
        }
        else if (prevV2026.goalRow=goal.row && distV940<prevV2026.dist-2)
            c.teleAvoidUntilV2026 := 0
    }
    ; One preferred Tele per leg. Never use a cooldown expiry as a reason to Tele again.
    if (c.preferredTeleRowV2026=goal.row || IsObject(c.teleWalkPendingV2026))
        return false
    if (c.teleAvoidUntilV2026 && A_TickCount<c.teleAvoidUntilV2026)
        return false
    if (lastV940 && A_TickCount-lastV940<cdV940)
        return false
    if (!FarmAttackHoldReleaseWaitV940())
        return false
    baseV940 := D2GetModuleBaseV35(pid,"D2Client.dll")
    livePlayerV940 := baseV940 ? D2ReadU32(h,baseV940+0x11BBFC) : 0
    pathV940 := livePlayerV940 ? D2ReadU32(h,livePlayerV940+0x2C) : 0
    if (!pathV940 || !MonsterBossProbeReadV1(h,pathV940,0x20,pb)
        || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=goal.level)
        return false
    ; Doc lai vi tri sau thao tac release de tranh nham Tele tu vi tri cu.
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    dx := goal.x-px,dy := goal.y-py
    distV940 := Sqrt(dx*dx+dy*dy)
    if (distV940<1 || FarmCenterArrivedV756(px,py,goal.x,goal.y))
        return false
    viewV940 := AutoMonsterAttackViewV1(h,baseV940,GameTargetHwndV63(),pathV940)
    if (!IsObject(viewV940))
        return false
    sxV940 := (dx-dy)*16,syV940 := (dx+dy)*8
    ; FIX: dist trong ma cu chua duoc gan -> huong/diem nham Tele khong hop le.
    reachV940 := Min(1,Max(1,MonsterRadiusGetV239())/distV940)
    axV940 := Max(16,Min(viewV940.gw-16,NumGet(pb,8,"Int")-viewV940.ox+sxV940*reachV940))
    ayV940 := Max(32,Min(viewV940.gh-64,NumGet(pb,12,"Int")-viewV940.oy+syV940*reachV940))
    try
    {
        if (!GameTargetAimV63(Round(axV940*viewV940.cw/viewV940.gw),Round(ayV940*viewV940.ch/viewV940.gh)))
            return false
        Sleep, 30
        if (!NativeDispatchReadyV10(true) || D2GetActiveGamePidV95()!=pid)
            return false
        sentV940 := BuffCheckedSendV29(teleportKeyV55)
        if (sentV940)
        {
            c.lastTeleV940 := A_TickCount,coordManualTeleLastV296 := A_TickCount
            c.teleProbeV2026 := {at:A_TickCount,dist:distV940,goalRow:goal.row}
            c.teleWalkPendingV2026 := {row:goal.row,at:A_TickCount,attempts:0}
            c.preferredTeleRowV2026 := goal.row
            if (IsObject(coordRouteV16) && coordRouteV16.pid=pid)
            {
                coordRouteV16.lastTeleport := A_TickCount
                coordRouteV16.stuckProbe := false,coordRouteV16.escapeV84 := false
                coordRouteV16.lastDispatch := 0,coordRouteV16.firstMoveAttempted := false
                coordRouteV16.teleRequiresWalkV2026 := true
                coordRouteV16.teleWalkCommandAtV2026 := 0
            }
            ; Do not start the stuck clock before a movement command is issued.
            coordNoTargetSinceV14 := A_TickCount-250
            PortalLogWriteV66("BC_TELE_SEND phase=" . c.phase . " destination=" . goal.x . "," . goal.y
                . " from=" . px . "," . py . " distance=" . Round(distV940,1)
                . " reach=" . Round(reachV940,3)
                . " aim=" . Round(axV940*viewV940.cw/viewV940.gw) . "," . Round(ayV940*viewV940.ch/viewV940.gh)
                . " cd_ms=" . cdV940 . " next=TELE_SETTLE_THEN_WALK")
        }
        return sentV940
    }
    finally
        backgroundAimV64 := false
}

FarmAttackHoldReleaseWaitV940()
{
    return FarmAttackHoldReleaseV15() && FarmAttackReleaseWaitV15()
}

; Route Tele gate: a queued Tele is NOT successful walking.
; Only a dispatched move, followed by >=2 tiles of real displacement, can release the Tele gate.
FarmTeleWalkDispatchedV2026(r,px,py)
{
    if (!IsObject(r) || !r.teleRequiresWalkV2026)
        return false
    if (!r.teleWalkCommandAtV2026)
    {
        r.teleWalkCommandAtV2026 := A_TickCount
        r.teleWalkStartXV2026 := px,r.teleWalkStartYV2026 := py
        PortalLogWriteV66("BC_TELE_WALK_DISPATCH row=" . r.next
            . " from=" . px . "," . py . " next=OBSERVE_WALK")
    }
    return true
}

FarmTeleWalkObserveV2026(r,px,py)
{
    if (!IsObject(r) || !r.teleRequiresWalkV2026 || !r.teleWalkCommandAtV2026)
        return false
    movedV2026 := Sqrt((px-r.teleWalkStartXV2026)**2+(py-r.teleWalkStartYV2026)**2)
    if (movedV2026<2)
        return false
    r.teleRequiresWalkV2026 := false,r.teleWalkCommandAtV2026 := 0
    PortalLogWriteV66("BC_TELE_WALK_CONFIRMED row=" . r.next
        . " moved=" . Round(movedV2026,1) . " now=" . px . "," . py)
    return true
}

FarmCenterWalkResumeV765(pid,c)
{
    global coordRouteV16,autoMonsterAttackOn,farmRunEpochV535
    global coordNoTargetSinceV14,monsterCombatUidV45,portalBackPendingV74,chaseCheckSecV9
    if (FarmItemRoutePausedV903(pid))
    {
        PortalLogWriteV66("BC_MOVE_BLOCK reason=ITEM_PRIORITY", "BC_MOVE_BLOCK", 1000)
        return false
    }
    global coordCastPendingV50,coordCastLastRowV50,portalBuffV85,portalExitPendingV69,farmBuffExclusiveV621,buffSequenceRunningV555
    FarmPortalBuffDeadlineV1301(pid,"MOVE_WORKER")
    castBlocksV1172 := coordCastPendingV50 && IsObject(c) && coordCastLastRowV50<=c.row
    if (!autoMonsterAttackOn || !IsObject(c) || c.pid!=pid || c.epoch!=farmRunEpochV535
        || c.route!=coordRouteV16 || !FarmCenterGoalValidV756(c)
        || D2GetActiveGamePidV95()!=pid || !NativeDispatchReadyV10(true)
        || RemoteThreadBusyV740(pid) || castBlocksV1172 || IsObject(portalBuffV85)
        || IsObject(portalExitPendingV69) || farmBuffExclusiveV621 || buffSequenceRunningV555)
    {
        whyV1113 := "SEND_OR_REMOTE_GUARD"
        if (!autoMonsterAttackOn)
            whyV1113 := "FARM_OFF"
        else if (!IsObject(c))
            whyV1113 := "CYCLE_MISSING"
        else if (c.pid!=pid || c.epoch!=farmRunEpochV535 || c.route!=coordRouteV16)
            whyV1113 := "CYCLE_ID_MISMATCH"
        else if (!FarmCenterGoalValidV756(c))
            whyV1113 := "GOAL_INVALID"
        else if (D2GetActiveGamePidV95()!=pid)
            whyV1113 := "GAME_PID_CHANGED"
        else if (castBlocksV1172)
            whyV1113 := "PORTAL_CAST_PENDING"
        else if (IsObject(portalBuffV85))
            whyV1113 := "PORTAL_BUFF_BUSY"
        else if (IsObject(portalExitPendingV69))
            whyV1113 := "PORTAL_EXIT_BUSY"
        else if (farmBuffExclusiveV621 || buffSequenceRunningV555)
            whyV1113 := "BUFF_EXCLUSIVE"
        else if (!NativeDispatchReadyV10(true))
            whyV1113 := "NATIVE_DISPATCH_NOT_READY"
        PortalLogWriteV66("BC_MOVE_BLOCK reason=" . whyV1113
            . " cast=" . coordCastPendingV50 . " buff=" . IsObject(portalBuffV85)
            . " exclusive=" . farmBuffExclusiveV621 . " sequence=" . buffSequenceRunningV555
            . " cast_row=" . coordCastLastRowV50 . " B=" . (IsObject(c) ? c.row : 0)
            . " pid=" . pid, "BC_MOVE_BLOCK", 1000)
        return false
    }
    base := D2GetModuleBaseV35(pid,"D2Client.dll"),h := base ? D2OpenProcess(pid) : 0
    if (!h)
    {
        PortalLogWriteV66("BC_MOVE_BLOCK reason=OPEN_PROCESS_FAIL", "BC_MOVE_BLOCK", 1000)
        return false
    }
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        if (!player || !MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,pb)
            || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=c.level
            || !FarmAttackReleaseWaitV15() || !AutoMonsterPacketCleanupV1())
        {
            PortalLogWriteV66("BC_MOVE_BLOCK reason=PLAYER_PATH_LEVEL_OR_PACKET_BUSY", "BC_MOVE_BLOCK", 1000)
            return false
        }
        px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
        ; Giu dich C trong suot qua trinh di; khong tu nhay qua D.
        if (IsObject(c.forwardV756)
            && FarmCenterArrivedV756(px,py,c.forwardV756.x,c.forwardV756.y))
        {
            ; V948: da o gan tam C thi khong phat them tele/di bo.
            ; Chi cho quy trinh cast/buff va ban giao quet quai tai C.
            if (FarmCenterAdvanceV756(h,player,pid,c,px,py))
                return true
            PortalLogWriteV66("BC_ARRIVAL_WAIT row=" . c.forwardV756.row
                . " xy=" . px . "," . py . " goal=" . c.forwardV756.x . "," . c.forwardV756.y
                . " cast_pending=" . coordCastPendingV50 . " portal_buff=" . IsObject(portalBuffV85)
                . " reason=WAIT_FINISH_HANDOFF", "BC_ARRIVAL_WAIT", 1000)
            return true
        }
        CoordRouteObserveV18(h,pb,pid)
        rWalkV2026 := coordRouteV16
        if (IsObject(rWalkV2026) && rWalkV2026.pid=pid)
            FarmTeleWalkObserveV2026(rWalkV2026,px,py)
        postTeleV2026 := c.teleWalkPendingV2026
        if (IsObject(postTeleV2026) && IsObject(c.forwardV756))
        {
            if (postTeleV2026.row!=c.forwardV756.row)
                c.teleWalkPendingV2026 := false
            else
            {
                ; Give the Tele animation a short settle period, never a stuck timeout.
                ; On every following tick, attempt the actual route move before stuck.
                if (A_TickCount-postTeleV2026.at<350)
                    return true
                walkSentV2026 := CoordMoveWhenClearV14(h,pb,pid)
                postTeleV2026.attempts++
                if (walkSentV2026)
                {
                    c.teleWalkPendingV2026 := false
                    if (IsObject(rWalkV2026) && rWalkV2026.pid=pid)
                    {
                        FarmTeleWalkDispatchedV2026(rWalkV2026,px,py)
                        rWalkV2026.stuckProbe := {x:px,y:py,since:A_TickCount
                            ,dist:Sqrt((px-c.forwardV756.x)**2+(py-c.forwardV756.y)**2)
                            ,goalRow:c.forwardV756.row}
                        rWalkV2026.firstMoveAttempted := true
                    }
                    PortalLogWriteV66("BC_TELE_WALK_RESUME row=" . c.forwardV756.row
                        . " result=MOVE_DISPATCHED next=CHECK_REAL_PROGRESS")
                }
                else
                    PortalLogWriteV66("BC_TELE_WALK_RETRY row=" . c.forwardV756.row
                        . " attempts=" . postTeleV2026.attempts
                        . " reason=MOVE_NOT_READY no_retele=1", "BC_TELE_WALK_RETRY", 1000)
                return true
            }
        }
        ; Arm the EXISTING coordinate-stuck timer from MOVE state itself.
        ; Previously it was armed only when CoordStuckMoveV392 sent a command,
        ; so repeated send failures could prevent stuck handling indefinitely.
        routeStuckV1202 := coordRouteV16
        if (IsObject(c.forwardV756) && IsObject(routeStuckV1202)
            && routeStuckV1202.phase="NEXT" && routeStuckV1202.pid=pid
            && routeStuckV1202.next=c.forwardV756.row
            && routeStuckV1202.firstMoveAttempted
            && !IsObject(routeStuckV1202.escapeV84) && !IsObject(routeStuckV1202.stuckProbe))
        {
            distStuckV1202 := Sqrt((px-c.forwardV756.x)**2+(py-c.forwardV756.y)**2)
            routeStuckV1202.stuckProbe := {x:px,y:py,since:A_TickCount
                ,dist:distStuckV1202,goalRow:routeStuckV1202.next}
            PortalLogWriteV66("BC_MOVE_STUCK_CLOCK_BEGIN row=" . c.forwardV756.row
                . " xy=" . px . "," . py . " goal=" . c.forwardV756.x . "," . c.forwardV756.y
                . " timeout_sec=" . chaseCheckSecV9,"BC_MOVE_STUCK_CLOCK_BEGIN",1000)
        }
        ; Existing teleport and move-stuck handlers stay unchanged.
        ; V948: het cooldown uu tien TELE, neu khong gui duoc moi di bo/xet ket.
        if (IsObject(c.forwardV756) && FarmBCPreferredTeleportV940(h,pb,pid,c,c.forwardV756))
            return true
        if (CoordStuckTickV84(h,pb,pid))
        {
            PortalLogWriteV66("BC_MOVE_STUCK_HANDLING row=" . (IsObject(c.forwardV756) ? c.forwardV756.row : 0), "BC_MOVE_STUCK_HANDLING", 1000)
            return true
        }
        moveOkV1113 := CoordMoveWhenClearV14(h,pb,pid)
        if (moveOkV1113 && IsObject(routeStuckV1202) && routeStuckV1202.pid=pid)
        {
            routeStuckV1202.firstMoveAttempted := true
            FarmTeleWalkDispatchedV2026(routeStuckV1202,px,py)
            if (!IsObject(routeStuckV1202.stuckProbe))
                routeStuckV1202.stuckProbe := {x:px,y:py,since:A_TickCount
                    ,dist:Sqrt((px-c.forwardV756.x)**2+(py-c.forwardV756.y)**2)
                    ,goalRow:c.forwardV756.row}
        }
        if (!moveOkV1113)
        {
            PortalLogWriteV66("BC_MOVE_NO_DISPATCH reason=ROUTE_MOVE_RETURN_FALSE"
                . " phase=" . coordRouteV16.phase . " anchor=" . coordRouteV16.anchor
                . " next=" . coordRouteV16.next . " combatRow=" . coordRouteV16.combatRowV627
                . " sinceIdleMs=" . (coordNoTargetSinceV14 ? A_TickCount-coordNoTargetSinceV14 : -1)
                . " combatUid=" . monsterCombatUidV45 . " portalBack=" . IsObject(portalBackPendingV74)
                . " px=" . px . " py=" . py, "BC_MOVE_NO_DISPATCH", 1000)
        }
        return moveOkV1113
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

FarmScanCompleteV742(readsOK,total,elapsed)
{
    return readsOK && total<2048 && elapsed<=150
}

FarmCombatResumeV742(pid)
{
    global monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44
    global coordRouteV16,coordNoTargetSinceV14,farmCenterCycleV741
    if (FarmCenterPendingV741(pid))
        return false
    if (!FarmAttackReleaseWaitV15() || !AutoMonsterPacketCleanupV1() || RemoteThreadBusyV740(pid))
        return false
    monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
    r := coordRouteV16
    if (IsObject(r) && r.pid=pid && r.battlePending)
    {
        r.battlePending := false,r.lastDispatch := 0,r.firstMoveAttempted := false
        coordNoTargetSinceV14 := A_TickCount-250
        PortalLogWriteV66("COMBAT_CLEAR_RESUME row=" . r.next . " next=PICKUP_THEN_ROUTE","COMBAT_CLEAR_RESUME",500)
    }
    return true
}


FarmReviveYellowV743(row,count)
{
    if (row>=1 && row<=count)
        return row
    return 0
}

; V61: Xoa tien do ROUTE cu (KHONG xoa file map tren dia),
; lam mat hieu luc cache F-ON de sau khi vao khu Farm, F-ON doc lai
; map dung level boi canh hien tai va GD2 chay tu dong vang moi.
; Chi goi khi da hoi sinh xong, o thanh, va khong con cong.
FarmReviveNoPortalNewRouteV61(r,pid,level)
{
    global farmReviveV32,stage2MapFileV14,stage2FlowV380,farmStage2DoneV372
    global libFarmPinnedMapV2026,farmControlOwnerV186
    global farmLoadedMapV56,mapRunResumeV210,coordRunSelectedV210
    global coordMapReadyV381,coordMapAcceptedV381,coordMapStateV381
    global coordMapSerialV381,fonCursorV724,coordMoveDoneV14
    global farmStartChoiceV2,mapLoadFailureV402
    if (farmReviveV32!=r || !r.deathSeenV296 || !FarmReviveTownLevelV295(level))
        return false
    if (r.noPortalRouteResetV61)
        return true
    if (farmControlOwnerV186="LIB")
        libFarmPinnedMapV2026 := false  ; Khong co cong cu -> map moi phai pick tai spawn moi.
    CoordRouteResetV16()
    stage2MapFileV14 := false,stage2FlowV380 := false,farmStage2DoneV372 := false
    farmLoadedMapV56 := false,mapRunResumeV210 := false,coordRunSelectedV210 := false
    farmStartChoiceV2 := false,coordMoveDoneV14 := false
    coordMapReadyV381 := false,coordMapAcceptedV381 := false,coordMapStateV381 := false
    fonCursorV724 := false,coordMapSerialV381 += 1,mapLoadFailureV402 := false
    r.noPortalRouteResetV61 := true
    PortalLogWriteV66("REVIVE_NO_PORTAL_ROUTE_RESET pid=" . pid . " town=" . level
        . " old_route=DISCARDED map_file=KEPT next=STAGE1_THEN_FON_RELOAD_FROM_YELLOW")
    return true
}

FarmReviveResumeV743(h,player,ByRef pb,pid,r)
{
    global farmReviveV32,autoMonsterAttackOn,scosEntryV162,farmControlOwnerV186
    global farmRunEpochV535,farmCenterCycleV741,monsterCombatUidV45,monsterChaseV44,monsterRoadAreaV51
    global coordSavedV15,coordRouteV16,coordYellowRowV350,coordPinnedYellowV136,coordManualRowV59
    global coordLiveYellowV128,coordNearbyRowV18,stage2MapFileV14,stage2FlowV380,farmStartChoiceV2
    global farmDeadStartV695,reviveBuffPendingV34,entryBuffPendingV20,cainPauseFarmV361,cainNoFightV361
    global coordCastPendingV50,coordCastCountV50,coordCastLastRowV50
    global currentProfile,routeMapIdV21
    if (farmReviveV32!=r || !BackgroundValidV63() || D2GetActiveGamePidV95()!=pid)
        return false
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt")),mode := D2ReadU32(h,player+0x10)
    if (!level || mode=0 || mode=17 || !FarmAttackReleaseWaitV15() || !AutoMonsterPacketCleanupV1())
        return false
    owner := farmControlOwnerV186!="" ? farmControlOwnerV186 : "SCOS",epoch := farmRunEpochV535
    town := FarmReviveTownLevelV295(level)
    known := FarmStartMapStageV737(owner,level)>0 || (owner="CAIN" && (level=168 || CainCaveMapV502(level)))
    if (!town && !known)
    {
        PortalLogWriteV66("REVIVE_LIVE_MAP_WAIT owner=" . owner . " level=" . level . " reason=NOT_OWNER_ROUTE","REVIVE_LIVE_MAP_WAIT",2000)
        return false
    }
    if (!r.reloadPreparedV743)
    {
        if (IsObject(scosEntryV162.commonRouteV3))
            FarmCommonRouteEndV3(scosEntryV162)
        scosEntryV162 := false
        SetTimer, ScosEntryTimerV162, Off
        stage2MapFileV14 := false,stage2FlowV380 := false,farmStartChoiceV2 := false
        farmCenterCycleV741 := false,monsterCombatUidV45 := 0,monsterChaseV44 := false,monsterRoadAreaV51 := false
        cainPauseFarmV361 := false,cainNoFightV361 := false
        autoMonsterAttackOn := true
        SetTimer, AutoMonsterAttackTimer, 250
        r.reloadPreparedV743 := true
    }
    routeFree := town || (owner="BO" && !FarmReviveBOFinalV743(level))
        || (owner="CAIN" && CainCaveMapV502(level))
    if (!routeFree)
    {
        identity := MapLiveIdentityV399(pid,level)
        if (!IsObject(identity))
            return false
        if (!r.mapLoadedV743 || r.loadedLevelV743!=level || r.loadedPtrV743!=identity.levelPtr)
        {
            FonTrackingEnableV410()
            ; LIB sau hoi sinh: doc lai LO TRINH DA KHOA TRONG RAM, khong nap lai INI.
            if (!FonLoadMapV382("REVIVE_LIVE_MAP",pid,level,NumGet(pb,2,"UShort"),NumGet(pb,6,"UShort")))
                return false
            if (farmReviveV32!=r || epoch!=farmRunEpochV535 || RoomRecordLevelV259(pid)!=level)
                return false
            r.mapLoadedV743 := true,r.loadedLevelV743 := level,r.loadedPtrV743 := identity.levelPtr
        }
        ; V1002: tra ve dung diem truoc khi bam nham cong, thay vi bat dau lai tu 1.
        if (r.accidentalPortalV1002 && r.resumeLevelV725=level
            && r.resumeRowV725>=1 && r.resumeRowV725<=coordSavedV15.Length()
            && IsObject(coordSavedV15[r.resumeRowV725])
            && coordSavedV15[r.resumeRowV725].level=level)
        {
            coordYellowRowV350 := r.resumeRowV725
            PortalLogWriteV66("FARM_TOWN_PORTAL_RESTORE level=" . level . " row=" . coordYellowRowV350)
        }
        yellow := FarmReviveYellowV743(coordYellowRowV350,coordSavedV15.Length())
        if (!yellow || coordSavedV15[yellow].level!=level
            || !Stage2MapWaitV381(pid,level,!LibFarmPinMatchesV2026(pid,level)))
            return false
    }
    else
        yellow := 0
    if (farmReviveV32!=r || epoch!=farmRunEpochV535 || RoomRecordLevelV259(pid)!=level)
        return false
    attached := owner="CAIN" && !town && level!=168 ? CainStage2AttachV379()
        : MapStage1ArmV185(owner,GameTargetHwndV63())
    if (!attached)
    {
        autoMonsterAttackOn := true
        return false
    }
    if (farmReviveV32!=r || epoch!=farmRunEpochV535 || RoomRecordLevelV259(pid)!=level)
        return false
    if (yellow)
    {
        coordYellowRowV350 := yellow,coordPinnedYellowV136 := yellow,coordManualRowV59 := yellow
        coordLiveYellowV128 := yellow,coordNearbyRowV18 := yellow
        pointV745 := coordSavedV15[yellow]
        farmStartChoiceV2 := {pid:pid,epoch:epoch,profile:currentProfile,mapId:routeMapIdV21
            ,level:level,row:yellow,x:pointV745.x,y:pointV745.y,reloadPending:false}
        if (IsObject(coordRouteV16) && coordRouteV16.pid=pid && coordRouteV16.startLevel=level)
            coordRouteV16.resumeRowV210 := yellow,coordRouteV16.yellow := yellow,coordRouteV16.startAtYellowV367 := true
    }
    if (IsObject(scosEntryV162) && scosEntryV162.pid=pid)
    {
        scosEntryV162.reviveFarmWasOnV725 := false,scosEntryV162.reviveOwnerV725 := false
        if (r.townBuffDone && !town)
        {
            scosEntryV162.stage1BuffDoneV368 := true,scosEntryV162.stage1SigDoneV374 := true,scosEntryV162.preSigDoneV310 := true
            scosEntryV162.beforeFinalBuffV718 := {pid:pid,owner:owner,epoch:epoch,source:r.respawnLevelV296,destination:level,ready:true}
            if (owner="BO")
                scosEntryV162.buffDoneV413 := true
        }
    }
    farmReviveV32 := false,farmDeadStartV695 := false
    reviveBuffPendingV34 := false,entryBuffPendingV20 := false
    coordCastPendingV50 := false,coordCastCountV50 := 0,coordCastLastRowV50 := 0
    if (owner!="CAIN" || town || level=168)
    {
        autoMonsterAttackOn := false
        SetTimer, AutoMonsterAttackTimer, Off
    }
    SetTimer, ScosEntryTimerV162, 250
    PortalLogWriteV66("REVIVE_RESUME_LIVE_MAP owner=" . owner . " level=" . level . " yellow=" . yellow
        . " source=FON_LIVE forced_first_row=0 portal=" . r.returnKindV725)
    FonInfoPushV385("Hồi sinh: map " . level . (yellow ? ", chạy từ dòng vàng " . yellow : ", tiếp tục luồng map hiện tại") . ".")
    return true
}


FarmReviveBOFinalV743(level)
{
    global currentProfile
    section := ProfileSection(currentProfile)
    IniRead, finalLevelV743, % ProfileConfigPathV364(section), %section%, BOFarmLevel4, 0
    return finalLevelV743>0 && level=finalLevelV743
}


FarmRevivePortalSourceV746(level)
{
    return level>0 && !FarmReviveOnFarmV747(level)
}

FarmReviveOnFarmV747(level)
{
    global farmControlOwnerV186,outsideLevelV22
    if (level<=0)
        return false
    owner := farmControlOwnerV186
    if (owner="SCOS")
        return level=270
    if (owner="LIB")
        return level>=263 && level<=266
    if (owner="NAO")
        return level=155 || (Lab1SingleRunV310() && outsideLevelV22>0 && level=outsideLevelV22)
    if (owner="BO")
        return FarmReviveBOFinalV743(level)
    if (owner="CAIN")
        return level=185
    plan := FarmMapPlanV10(owner,level)
    if (IsObject(plan))
        return plan.final ? true : false
    if (owner="VIZ" || owner="TRAN" || owner="CYC" || owner="M3000" || owner="UBU")
        return false
    return outsideLevelV22>0 && level=outsideLevelV22
}

ManualLogVNStartV749()
{
    global manualLogVNStateV749,manualLogSessionV95,currentProfile,chaseCheckSecV9,monsterLockRoomSecV622
    manualLogVNStateV749 := {session:manualLogSessionV95,parts:[],size:0,trimmed:false,failed:false,lines:0
        ,started:A_Now,profile:currentProfile,checkSec:chaseCheckSecV9,lockSec:monsterLockRoomSecV622}
}

ManualLogVNFailedV749()
{
    global manualLogVNStateV749
    if (IsObject(manualLogVNStateV749))
        manualLogVNStateV749.failed := true
}

ManualLogVNAppendV749(message,channel)
{
    global manualLogVNStateV749,manualLogSessionV95
    r := manualLogVNStateV749
    if (!IsObject(r) || r.session!=manualLogSessionV95)
        return false
    block := ""
    Loop, Parse, message, `n, `r
    {
        line := A_LoopField
        if (Trim(line)="")
            continue
        if (StrLen(line)>8192)
            line := SubStr(line,1,8192) . " [Dòng dài: phần còn lại xem log gốc]"
        block .= "[" . channel . "] " . ManualLogVNLineV749(line) . "`r`n"
        r.lines++
        if (StrLen(block)>=32768)
        {
            ManualLogVNBufferV749(r,block)
            block := ""
        }
    }
    if (block!="")
        ManualLogVNBufferV749(r,block)
    return true
}

ManualLogVNBufferV749(r,block)
{
    last := r.parts.Length()
    if (last && StrLen(r.parts[last])+StrLen(block)<=32768)
        r.parts[last] .= block
    else
        r.parts.Push(block)
    r.size += StrLen(block)
    while (r.size>2000000 && r.parts.Length()>1)
    {
        old := r.parts.RemoveAt(1)
        r.size -= StrLen(old),r.trimmed := true
    }
    return true
}

ManualLogVNLineV749(line)
{
    prefix := "",body := line
    if (RegExMatch(line,"^(\d{14})(?:\s+tick=\d+)?\s*\|\s*(.*)$",m))
    {
        prefix := SubStr(m1,7,2) . "/" . SubStr(m1,5,2) . "/" . SubStr(m1,1,4)
            . " " . SubStr(m1,9,2) . ":" . SubStr(m1,11,2) . ":" . SubStr(m1,13,2) . " | "
        body := m2
    }
    if (RegExMatch(body,"^([A-Z][A-Z0-9_]+)(?=\s|$)",event))
    {
        label := ManualLogVNLookupV749("EVENT",event1)
        body := (label=event1 ? "Sự kiện chưa có diễn giải: " . event1 : label)
            . SubStr(body,StrLen(event1)+1)
    }
    out := "",pos := 1
    while (at := RegExMatch(body,"([A-Za-z_][A-Za-z_0-9]*)=(""[^""]*""|[^\s|]+)",field,pos))
    {
        out .= SubStr(body,pos,at-pos) . ManualLogVNLookupV749("FIELD",field1) . ": "
            . ManualLogVNLookupV749("VALUE",field2)
        pos := at+StrLen(field)
    }
    return prefix . out . SubStr(body,pos)
}

ManualLogVNLookupV749(kind,key)
{
    static initializedV751 := false,events := {},fields := {},values := {}
    if (!initializedV751)
    {
        events["COMBAT_PICKUP_CLEAR"] := "Đã hết lượt nhặt và quái bảo vệ đồ; tiếp theo kiểm tra tâm B"
        events["COMBAT_AFTER_ATTACK_PICKUP"] := "Sau đánh: chuyển sang xét nhặt và đánh quái theo tâm nhặt"
        events["START"] := "Bắt đầu ghi log"
        events["TRACE_START"] := "Bắt đầu ghi kênh"
        events["SESSION_END"] := "Kết thúc ghi log"
        events["CONFIG"] := "Cấu hình đang dùng"
        events["TARGET_SELECTED"] := "Chọn mục tiêu để đánh"
        events["TARGET_STUCK_NO_DAMAGE"] := "Mục tiêu không tiến triển: đã yêu cầu bỏ qua"
        events["TARGET_STUCK_ROOM_LOCK"] := "Tạm khóa phòng chứa mục tiêu bị kẹt"
        events["TARGET_ROOM_UNREADABLE"] := "Không đọc được phòng chứa mục tiêu; đang chờ đọc lại"
        events["COMBAT_LOCK"] := "Giữ mục tiêu đang đánh"
        events["COMBAT_UNLOCK"] := "Bỏ giữ mục tiêu"
        events["COMBAT_STUCK_SWITCH"] := "Bỏ qua mục tiêu kẹt và đổi sang mục tiêu gần"
        events["COMBAT_SCAN_CONTEXT"] := "Điều kiện lượt quét quái"
        events["COMBAT_SCAN_RESULT"] := "Kết quả quét quái"
        events["FON_MANUAL_REFRESH"] := "Load: bật lại F-ON và đọc map thực tế hiện tại"
        events["START_IN_FARM_READY"] := "Start: nhân vật đã ở map farm; giữ dòng vàng và bỏ chờ buff hồi sinh"
        events["START_IN_FARM_BUFF_CLEAR"] := "Đã bỏ cờ buff hồi sinh cũ vì nhân vật đang sống trong map farm"
        events["COMBAT_FORWARD_TO_C"] := "Vượt bán kính theo hướng B tới C; teleport tới C và chờ xác nhận"
        events["COMBAT_FORWARD_ARRIVED"] := "Đã vào bán kính quanh C; dừng tele, chuyển tâm đánh và dòng vàng sang C"
        events["COMBAT_CENTER_CHECK"] := "Kiểm tra vị trí so với tâm B"
        events["COMBAT_CENTER_INSIDE"] := "Nhân vật đang trong bán kính tâm B"
        events["COMBAT_CENTER_RETURN"] := "Đã gửi một lệnh tele chỉnh lệch B/C; tiếp tục đi và đánh, không lặp tele chờ tới đích"
        events["COMBAT_CLEAR_RESUME"] := "Đã hết mục tiêu hợp lệ; tiếp tục nhặt đồ rồi đi lộ trình"
        events["COMBAT_CENTER_TELE"] := "Gửi lệnh teleport về tâm B"
        events["COMBAT_CENTER_TELE_SENT"] := "Đã gửi lệnh teleport về tâm B; chờ kiểm tra vị trí"
        events["NATIVE_DISPATCH"] := "Gửi thao tác tới game"
        events["PORTAL_DLL_TARGET"] := "Chọn cổng đang tồn tại"
        events["PORTAL_DLL_TRY"] := "Thử gửi lệnh chui cổng"
        events["PORTAL_INTERACT_SENT"] := "Đã gửi lệnh tương tác cổng; chưa xác nhận chuyển map"
        events["RETURN_MAP_CONFIRMED"] := "Đã xác nhận đổi map sau khi vào cổng"
        events["REVIVE_ESC"] := "Gửi Esc sau khi chết"
        events["REVIVE_STATE"] := "Tình trạng hồi sinh"
        events["REVIVE_ALIVE"] := "Đã đọc được nhân vật sống sau hồi sinh"
        events["REVIVE_REOPEN_PORTAL"] := "Gửi phím mở lại cổng sau hồi sinh"
        events["REVIVE_NO_FARM_PORTAL"] := "Không thấy cổng farm sau các lượt kiểm tra"
        events["REVIVE_RESUME_LIVE_MAP"] := "Tiếp tục map hiện tại từ dòng vàng"
        events["REVIVE_RETURN_MAP_MISMATCH"] := "Map vừa vào khác map đang chờ"
        events["REVIVE_LIVE_MAP_WAIT"] := "Chờ dữ liệu map phù hợp để chạy tiếp"
        events["REVIVE_PORTAL_APPROACH"] := "Đi tới gần cổng hồi sinh"
        events["REVIVE_PORTAL_RESCAN_RETURN"] := "Quay về vị trí cổng đã thấy để quét lại"
        events["FARM_START_TOWN"] := "Bắt đầu kiểm tra cổng quay lại farm"
        events["REVIVE_TOWN_BUFF_DONE"] := "Đã xong buff trước khi chui cổng"
        events["REVIVE_RED_WAIT"] := "Chưa chọn được một cổng đỏ phù hợp"
        events["PORTAL_RECORD_FARM_CONFIRMED"] := "Đã quan sát thấy cổng farm mới"
        events["PORTAL_RECORD_FARM_TOWN_PAIR"] := "Đã ghép đầu cổng ở điểm hồi sinh"
        events["PORTAL_RECORD_FARM_TOWN_CONFIRMED"] := "Đã xác nhận đầu cổng farm tại điểm hồi sinh"
        events["PORTAL_RECORD_INITIAL_DEST"] := "Đã ghi nhận map đích của cổng vào"
        events["MAP_CHANGE"] := "Nhân vật đổi map"
        events["FON_LOAD_SCAN"] := "Tìm file lộ trình khớp map hiện tại"
        events["FON_LOAD_OK"] := "Đã nạp file lộ trình và dòng vàng"
        events["FON_LOAD_FAIL"] := "Chưa nạp được lộ trình cho map"
        events["FON_LOAD_BLOCKED"] := "Đang có lượt nạp map khác; chờ lượt sau"
        events["STAGE2_ROUTE_NEW"] := "Tạo lộ trình mới từ dòng vàng"
        events["STAGE2_ROUTE_BEGIN"] := "Bắt đầu chạy lộ trình đang nạp"
        events["FARM_START_FROM_YELLOW"] := "Bắt đầu farm từ dòng vàng"
        events["RUN_RESET_FROM_YELLOW"] := "Nạp lại lộ trình và bắt đầu từ dòng vàng"
        events["ROUTE_START_YELLOW"] := "Khởi động lộ trình tại dòng vàng"
        events["ROUTE_START"] := "Bắt đầu đi lộ trình"
        events["RUN_RESUME"] := "Tiếp tục lộ trình"
        events["ROUTE_MOVE"] := "Gửi lệnh di chuyển theo lộ trình"
        events["MAP_MOVE_DISPATCH"] := "Gửi lệnh đi tới tọa độ"
        events["MAP_MOVE_WAIT"] := "Lệnh di chuyển đang chờ"
        events["ROUTE_NO_PROGRESS"] := "Nhân vật chưa tiến tới đích"
        events["ROUTE_MOVE_OBSERVED"] := "Đối chiếu vị trí sau lệnh di chuyển"
        events["ROUTE_WAIT"] := "Chờ dữ liệu lộ trình"
        events["ROUTE_BATTLE"] := "Tạm ngừng đi lộ trình để đánh quái"
        events["ROUTE_RESUME_ORDERED"] := "Tiếp tục theo thứ tự lộ trình"
        events["MAP_STAGE1_START"] := "Bắt đầu giai đoạn đi vào khu farm"
        events["MAP_STAGE1_COMPLETE"] := "Hoàn thành giai đoạn đi vào khu farm"
        events["MAP_STAGE2_START"] := "Bắt đầu farm chính"
        events["MAP_STAGE2_DONE"] := "Đã hết lộ trình farm chính"
        events["MAP_STAGE3_START"] := "Bắt đầu xử lý sau farm"
        events["COMMON_ROUTE_BEGIN"] := "Bắt đầu đoạn lộ trình dùng chung"
        events["COMMON_ROUTE_DONE"] := "Đã hoàn thành đoạn lộ trình dùng chung"
        events["BO_COMBAT_FIRST"] := "BO: ưu tiên đánh quái, tạm ngừng di chuyển"
        events["BO_SHARED_SCAN"] := "BO: kết quả quét quái dùng chung"
        events["ITEM_GUARD_LOCK"] := "Tạm giữ vùng có đồ cần nhặt"
        events["ITEM_GUARD_UNLOCK"] := "Bỏ giữ vùng nhặt đồ"
        events["LOW_HP_ATTACK_ONCE"] := "Máu thấp: gửi một lượt đánh rồi né"
        events["SIG_SESSION_RELEASE"] := "Phiên game cũ đã kết thúc; xóa khóa SIG/nhặt cũ và cho phép phục hồi game"
        events["SIG_CATALYST_TO_CUBE"] := "Đã đưa đúng tem SIG vào Cube; tem được giữ lại sau khi ghép"
        events["FARM_PICKUP_TRY"] := "Thử nhặt vật phẩm trong lúc farm"
        events["FARM_PICKUP_SKIP"] := "Bỏ qua vật phẩm nhặt không được trong lượt farm này"
        events["SIG_ERROR_PICKUP_BEGIN"] := "SIG lỗi: nhặt lại đồ trước khi dừng"
        events["SIG_ERROR_PICKUP_DONE"] := "Đã thu hồi đồ sau lỗi SIG"
        events["SIG_ERROR_PICKUP_FAILED"] := "Chưa thu hồi xong đồ sau lỗi SIG"
        events["SIG_ENTRY_ABORT"] := "SIG đã dừng vì lỗi; giữ đồ, không chờ vô hạn"
        events["CUBE_RESET_HOLD"] := "Đã khóa reset trước khi quăng Cube; chờ nhặt lại Cube và đồ"
        events["CUBE_RESET_PICKUP_DONE"] := "Đã xác nhận nhặt xong sau khi quăng Cube; chờ thao tác đồ kết thúc"
        events["FARM_SIG_PAUSE"] := "Tạm dừng bộ đếm reset; chờ SIG và nhặt đồ xong"
        events["FARM_SIG_RESUME"] := "SIG và nhặt đồ đã xong; bộ đếm reset bắt đầu lại từ 0"
        events["STAGE4_SIG_DEFER"] := "Hoãn phục hồi game vì đang SIG hoặc nhặt đồ sau SIG"
        events["REMOTE_TIMEOUT_TRACKED"] := "Lệnh game chưa hoàn tất; giữ vùng nhớ và chờ xử lý xong"
        events["FARM_RETRY_ERROR"] := "Gặp lỗi tạm thời; chờ thử lại"
        events["SKIP"] := "Bỏ qua thao tác trong lượt này"
        events["WAIT"] := "Đang chờ"
        events["STOP"] := "Dừng thao tác"
        events["STATE"] := "Tình trạng hiện tại"
        fields["uid"] := "ID mục tiêu"
        fields["target_uid"] := "ID mục tiêu được chọn"
        fields["new_uid"] := "ID mục tiêu mới"
        fields["old_uid"] := "ID mục tiêu cũ"
        fields["trigger_uid"] := "ID quái gây kẹt"
        fields["class"] := "Loại đối tượng"
        fields["target_class"] := "Loại mục tiêu"
        fields["cls"] := "Loại đối tượng"
        fields["pid"] := "ID tiến trình game"
        fields["unit"] := "Địa chỉ đối tượng"
        fields["level"] := "ID map hiện tại"
        fields["source"] := "Nguồn"
        fields["destination"] := "Map đích"
        fields["expected"] := "Đang chờ"
        fields["actual"] := "Thực tế"
        fields["before"] := "Trước"
        fields["after"] := "Sau"
        fields["row"] := "Dòng lộ trình"
        fields["yellow"] := "Dòng vàng"
        fields["next"] := "Bước tiếp theo"
        fields["phase"] := "Giai đoạn"
        fields["step"] := "Bước"
        fields["attempt"] := "Lần thử"
        fields["reason"] := "Lý do"
        fields["queued"] := "Đã gửi lệnh (1=có, 0=chưa)"
        fields["sent"] := "Đã gửi (1=có, 0=chưa)"
        fields["result"] := "Kết quả"
        fields["confirmed"] := "Đã xác nhận"
        fields["known"] := "Đọc được dữ liệu"
        fields["complete"] := "Quét đủ dữ liệu"
        fields["radius"] := "Bán kính"
        fields["distance"] := "Khoảng cách"
        fields["dist_sq"] := "Khoảng cách bình phương"
        fields["half_bk_sq"] := "Nửa bán kính, bình phương"
        fields["hp_readable"] := "Đọc được máu"
        fields["hp"] := "Máu"
        fields["hp_raw"] := "Máu gốc"
        fields["time"] := "Thời gian xét"
        fields["since"] := "Mốc bắt đầu đếm"
        fields["elapsed"] := "Thời gian đã qua"
        fields["elapsed_ms"] := "Thời gian đã qua (ms)"
        fields["wait_ms"] := "Chờ (ms)"
        fields["duration"] := "Thời lượng"
        fields["retry_ms"] := "Chờ thử lại (ms)"
        fields["timeout"] := "Thời hạn"
        fields["locked"] := "Đang khóa"
        fields["uid_locked"] := "Khóa riêng quái"
        fields["room_locked"] := "Khóa phòng"
        fields["scope"] := "Phạm vi"
        fields["room"] := "Phòng"
        fields["rooms"] := "Số phòng"
        fields["units"] := "Số đối tượng"
        fields["owner"] := "Farm đang chạy"
        fields["map"] := "Map/lộ trình"
        fields["map_id"] := "ID map"
        fields["profile"] := "Hồ sơ"
        fields["key"] := "Phím"
        fields["mode"] := "Trạng thái"
        fields["state"] := "Tình trạng"
        fields["channel"] := "Kênh"
        fields["tick"] := "Mốc thời gian hệ thống"
        fields["x"] := "Tọa độ X"
        fields["y"] := "Tọa độ Y"
        fields["xy"] := "Tọa độ"
        fields["player"] := "Nhân vật"
        fields["player_xy"] := "Tọa độ nhân vật"
        fields["portal_xy"] := "Tọa độ cổng"
        fields["target"] := "Đích"
        fields["to"] := "Tới"
        fields["method"] := "Cách thực hiện"
        fields["movement"] := "Di chuyển"
        fields["pickup"] := "Nhặt đồ"
        fields["farm"] := "Farm"
        fields["fight"] := "Đánh quái"
        fields["no_fight"] := "Không đánh"
        fields["pause"] := "Tạm dừng"
        fields["item_owner"] := "Thao tác đang giữ quyền dùng đồ"
        fields["x_running"] := "Buff X đang chạy"
        fields["z_running"] := "Buff Z đang chạy"
        fields["last_try"] := "Lần thử gần nhất"
        fields["boss_priority"] := "Ưu tiên boss"
        fields["position_changed"] := "Vị trí đã đổi"
        fields["buff"] := "Buff"
        fields["forced_first_row"] := "Ép về dòng đầu"
        fields["next_left_ms"] := "Còn lại (ms)"
        fields["map_file"] := "File lộ trình"
        fields["file"] := "File"
        fields["ready"] := "Đã sẵn sàng"
        fields["selection"] := "Cách chọn"
        fields["action"] := "Thao tác"
        fields["until"] := "Đến khi"
        fields["segment_ms"] := "Khoảng chia file (ms)"
        fields["note"] := "Ghi chú"
        fields["combat"] := "Đánh quái"
        fields["center"] := "Tâm"
        fields["area"] := "Vùng quét"
        fields["lock_ms"] := "Thời gian khóa (ms)"
        values["USER_STOP"] := "Người dùng dừng log"
        values["UNTIL_STOP"] := "Tới khi dừng"
        values["FARM"] := "Farm"
        values["RED"] := "Cổng đỏ"
        values["MAP"] := "Map"
        values["UID"] := "Riêng một quái"
        values["ROOM"] := "Cả phòng"
        values["CHECK"] := "Kiểm tra"
        values["ATTACK"] := "Đánh"
        values["RETURN"] := "Quay về tâm"
        values["INSIDE"] := "Trong bán kính"
        values["OUTSIDE"] := "Ngoài bán kính"
        values["WAIT_MAP_CHANGE"] := "Chờ xác nhận đổi map"
        values["LIVE_MAP_YELLOW"] := "Nạp map hiện tại và lấy dòng vàng"
        values["PICKUP"] := "Nhặt sau khi đánh hết quái"
        values["CHECK_B"] := "Kiểm tra bán kính tâm B"
        values["PLAYER_SCAN"] := "Quét quanh nhân vật"
        values["PLAYER_SCAN_THEN_CHECK_B"] := "Quét quanh nhân vật rồi kiểm tra tâm B"
        values["PICKUP_THEN_ROUTE"] := "Nhặt đồ rồi đi lộ trình"
        values["FON_LIVE"] := "Dữ liệu map đang nạp"
        values["RESUME_COMBAT"] := "Tiếp tục đánh"
        values["NONE"] := "Không có"
        values["ON"] := "Bật"
        values["OFF"] := "Tắt"
        values["MISSING"] := "Chưa thấy"
        values["PRESENT"] := "Đang có"
        values["NORMAL"] := "Bình thường"
        values["NO_ROUTE_FILE"] := "Không có file lộ trình"
        values["NOT_OWNER_ROUTE"] := "Map chưa thuộc lộ trình của farm đang chạy"
        values["TARGET_GONE_EXCLUDED_OR_OUTSIDE_RADIUS"] := "Quái mất, bị loại hoặc ra ngoài bán kính"
        values["NO_WANTED_GROUND_ITEMS_IN_FIXED_CIRCLE"] := "Không còn đồ cần nhặt trong vùng"
        values["WAIT_THREAD_OR_PROCESS_EXIT"] := "Chờ lệnh game xong hoặc game đóng"
        values["NO_UNIQUE_RED_PORTAL"] := "Chưa có đúng một cổng đỏ phù hợp"
        values["BUILD_OR_INTERACT_SIGNATURE_MISMATCH"] := "Phiên bản game hoặc hàm tương tác không khớp"
        values["NO_SELECTED_ROUTE"] := "Chưa chọn lộ trình"
        values["READ_FAILED"] := "Không đọc được dữ liệu"
        values["TARGET_GONE"] := "Mục tiêu không còn"
        values["KEEP_CURRENT_TARGET"] := "Tiếp tục giữ mục tiêu hiện tại"
        values["PAUSED"] := "Tạm ngừng"
        values["WAIT"] := "Chờ"
        values["DONE"] := "Hoàn tất"
        values["NEXT"] := "Điểm tiếp theo"
        values["CLEAR"] := "Quét/đánh quanh điểm"
        values["START"] := "Bắt đầu"
        values["SIG"] := "Xử lý SIG"
        values["WP"] := "Waypoint"
        values["PORTAL"] := "Cổng"
        values["PORTAL_WAIT"] := "Chờ cổng"
        values["FON"] := "Bộ nạp map"
        values["NEAREST_CURRENT_PLAYER"] := "Gần nhân vật nhất"
        values["RETRY_ROOM_READ"] := "Thử đọc lại phòng"
        values["STANDARD_GD2"] := "Luồng farm chuẩn"
        values["NO_LIVE_TARGET"] := "Không có quái sống hợp lệ"
        initializedV751 := true
    }
    table := kind="EVENT" ? events : kind="FIELD" ? fields : values
    return table.HasKey(key) ? table[key] : key
}

ManualLogVNStopV749(show := true)
{
    global manualLogVNStateV749,manualLogVNDisplayV749,ManualLogVNTextV749,ManualLogVNHwndV749
    global ManualLogVNHintV749,ManualLogVNCopyButtonV749,ManualLogVNCloseButtonV749
    r := manualLogVNStateV749
    manualLogVNStateV749 := false
    if (!show || !IsObject(r))
        return false
    text := "DIỄN GIẢI LOG TIẾNG VIỆT`r`nPhiên: " . r.session . " | Hồ sơ: " . r.profile
        . "`r`nXét kẹt: " . r.checkSec . " giây | Thời gian khóa bỏ qua: " . r.lockSec . " giây."
        . "`r`nCó thể bôi đen để copy, hoặc bấm Copy tất cả. Đóng bảng sẽ bỏ bản diễn giải này."
        . "`r`nGửi lệnh thành công chưa có nghĩa là game đã di chuyển/đổi map. Các ID và số liệu được giữ nguyên."
        . "`r`nSự kiện chưa có bản diễn giải sẽ giữ tên gốc để đối chiếu; bảng không tự kết luận nguyên nhân lỗi."
    if (r.trimmed)
        text .= "`r`nPhiên dài: chỉ hiển thị phần log gần nhất để giới hạn bộ nhớ; log gốc vẫn đầy đủ."
    if (r.failed)
        text .= "`r`nMột số dòng không diễn giải được; hãy đối chiếu log gốc."
    text .= "`r`n`r`n"
    for _,part in r.parts
        text .= part
    if (!r.lines)
        text .= "Phiên này không có dòng log được ghi."
    manualLogVNDisplayV749 := text
    Gui, ManualLogVN:Destroy
    Gui, ManualLogVN:New, +Resize +MinSize640x360 +HwndManualLogVNHwndV749, Diễn giải log tiếng Việt
    Gui, ManualLogVN:Font, s10, Segoe UI
    Gui, ManualLogVN:Add, Text, x12 y10 w860 h22 vManualLogVNHintV749, Đọc bản diễn giải bên dưới. Ctrl+A / Ctrl+C để copy phần bạn muốn gửi.
    Gui, ManualLogVN:Add, Edit, x12 y36 w876 h470 vManualLogVNTextV749 ReadOnly +HScroll -Wrap, %text%
    Gui, ManualLogVN:Add, Button, x630 y516 w140 h30 vManualLogVNCopyButtonV749 gManualLogVNCopyV749, Copy tất cả
    Gui, ManualLogVN:Add, Button, x782 y516 w106 h30 vManualLogVNCloseButtonV749 gManualLogVNCloseV749, Đóng
    Gui, ManualLogVN:Show, w900 h558
    return true
}

ManualLogVNCopyV749:
Clipboard := manualLogVNDisplayV749
GuiControl, ManualLogVN:, ManualLogVNHintV749, Đã copy toàn bộ bản diễn giải. Bạn có thể dán để gửi.
return

ManualLogVNCloseV749:
ManualLogVNGuiClose:
ManualLogVNGuiEscape:
Gui, ManualLogVN:Destroy
manualLogVNDisplayV749 := "",ManualLogVNHwndV749 := 0
return

ManualLogVNGuiSize:
if (A_EventInfo=1)
    return
vnWidthV749 := A_GuiWidth-24,vnHeightV749 := A_GuiHeight-88,vnButtonsYV749 := A_GuiHeight-42
vnCopyXV749 := A_GuiWidth-270,vnCloseXV749 := A_GuiWidth-118
GuiControl, ManualLogVN:Move, ManualLogVNHintV749, % "w" . vnWidthV749
GuiControl, ManualLogVN:Move, ManualLogVNTextV749, % "w" . vnWidthV749 . " h" . vnHeightV749
GuiControl, ManualLogVN:Move, ManualLogVNCopyButtonV749, % "x" . vnCopyXV749 . " y" . vnButtonsYV749
GuiControl, ManualLogVN:Move, ManualLogVNCloseButtonV749, % "x" . vnCloseXV749 . " y" . vnButtonsYV749
return


MonsterSkipDistanceChangedV752:
GuiControlGet, skipInputV752, 1:, MonsterSkipDistanceInputV752
if (RegExMatch(skipInputV752,"^\d+$") && skipInputV752<=200)
    monsterSkipDistanceV752 := skipInputV752+0
return

MonsterSkipDistanceGetV752(radius)
{
    global monsterSkipDistanceV752
    return monsterSkipDistanceV752>0 ? monsterSkipDistanceV752 : Max(1,radius)/2
}

; V1801: independent shortcut for Form 4 Cast, configured beneath Form 3.
CastToggleKeyChangedV1801:
GuiControlGet, castKeyEditV1801, 1:, CastToggleKeyInputV1801
newCastKeyV1801 := NormalizeOptionalKey(castKeyEditV1801)
if (newCastKeyV1801!="" && !GetKeyVK(newCastKeyV1801) && !GetKeySC(newCastKeyV1801))
    return
if (castToggleKeyV1801!="")
    BackgroundHotkeyV63("~$" . castToggleKeyV1801,"CastToggleHandlerV1801","Off UseErrorLevel")
castToggleKeyV1801 := newCastKeyV1801
IniWrite, % castToggleKeyV1801="" ? "None" : castToggleKeyV1801, %ConfigFile%, CastShortcut, Key
if (castToggleKeyV1801!="")
    BackgroundHotkeyV63("~$" . castToggleKeyV1801,"CastToggleHandlerV1801","On UseErrorLevel")
return

CastToggleHandlerV1801:
if (!IsGameForegroundV63())
    return
castManualToggleV1801 := !castManualToggleV1801
QCastOn := castManualToggleV1801
if (QCastOn)
    qCastLast1 := A_TickCount, qCastLast2 := A_TickCount, qCastLast3 := A_TickCount
; Always show shortcut state, even if optional View Tooltip / F-ON INFO is disabled.
GuiControl, 1:, CastToggleStatusV1801, % (castManualToggleV1801 ? "ON" : "OFF")
ToolTip, % "CAST: " . (castManualToggleV1801 ? "ON" : "OFF")
SetTimer, RemoveToolTip, -3000
return

; V816 - Gom .txt nam canh file AHK vao thu muc txt ngay khi mo tool.
; Khong thay doi file .log, tep .txt trong Logs/LoTrinh, hay tep tam A_Temp.
TxtRootInitV816()
{
    folder := A_ScriptDir . "\txt"
    FileCreateDir, %folder%
    if (!InStr(FileExist(folder), "D"))
        return false
    ; Chuyen config.ini vao txt, khong ghi de du lieu neu da co ban trong txt.
    legacyIniV816 := A_ScriptDir . "\config.ini"
    targetIniV816 := folder . "\config.ini"
    if (FileExist(legacyIniV816))
    {
        if (FileExist(targetIniV816))
        {
            backupIndexV816 := 1
            Loop
            {
                targetIniV816 := folder . "\config-ban-cu-" . backupIndexV816 . ".ini"
                if (!FileExist(targetIniV816))
                    break
                backupIndexV816++
            }
        }
        FileMove, %legacyIniV816%, %targetIniV816%
    }
    Loop, Files, % A_ScriptDir . "\*.txt", F
    {
        src := A_LoopFileFullPath
        dst := folder . "\" . A_LoopFileName
        if (FileExist(dst))
        {
            SplitPath, src,,, extension, baseName
            index := 1
            Loop
            {
                dst := folder . "\" . baseName . "-ban-cu-" . index . "." . extension
                if (!FileExist(dst))
                    break
                index++
            }
        }
        FileMove, %src%, %dst%
    }
    return true
}

; Duong dan thong nhat cho file TXT trong thu muc goc.
; Neu khong tao duoc thu muc hay khong di chuyen duoc file cu, van doc file cu.
TxtRootPathV816(fileName)
{
    folder := A_ScriptDir . "\txt"
    if (!InStr(FileExist(folder), "D"))
    {
        FileCreateDir, %folder%
        if (!InStr(FileExist(folder), "D"))
            return A_ScriptDir . "\" . fileName
    }
    path := folder . "\" . fileName
    legacy := A_ScriptDir . "\" . fileName
    if (!FileExist(path) && FileExist(legacy))
    {
        FileMove, %legacy%, %path%
        if (ErrorLevel)
            return legacy
    }
    return path
}
