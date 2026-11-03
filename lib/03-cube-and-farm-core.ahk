Belt2HP2ManaHandler:
if (!IsGameForegroundV63())
    return
if (sigBusyV147)
    return
if (packetWatchArmedV1)
    return
TransferHotkeyTrace("8HP_8MP_TO_BELT")
if (xRunning)
{
    DebugTraceWrite("belt", "TRANSFER_BLOCKED reason=BUFF_RUNNING")
    return
}
if (!IsGameActive())
{
    DebugTraceWrite("belt", "TRANSFER_BLOCKED reason=GAME_NOT_ACTIVE")
    return
}
if (!GameItemActionBeginV4("Belt", "belt", true))
    return
try
{
beltOneShotLogActive := beltOneShotLogArmed
if (beltOneShotLogActive)
    BeltSendLogV101("=== ONE-SHOT 2HP2MANA START " . A_Now . " ===")
beltTraceSendOK := V50ConfigureBelt([1229,1229,1234,1234])
DebugTraceWrite("belt", "BELT_HANDLER_END packets_sent_ok=" . beltTraceSendOK)
if (beltOneShotLogActive)
    BeltSendLogV101("=== ONE-SHOT END - LOG AUTO OFF ===")
beltOneShotLogActive := false
beltOneShotLogArmed := false
}
finally
{
    GameItemActionEndV4("Belt")
}
return

BeltSendLogV101(msg)
{
    DebugTraceWrite("belt", msg)
}

GameItemActionBeginV4(owner, channel, requireEmpty:=false)
{
    global buffSequenceRunningV555
    if (RemoteThreadBusyV740(D2GetActiveGamePidV95()))
        return false
    if (buffSequenceRunningV555)
        return false
    if (!FarmAttackReleaseWaitV15())
        return false
    global gameItemActionOwner, gameItemTimersPausedOwner, portalExitPendingV69, autoMonsterAttackOn, reviveBuffPendingV34
    if (autoMonsterAttackOn && (IsObject(portalExitPendingV69) || reviveBuffPendingV34))
        return false
    static lastSkip := {}, lastSkipTick := {}
    previousCritical := A_IsCritical
    Critical, On
    if (gameItemActionOwner!="")
    {
        busyOwner := gameItemActionOwner
        if (previousCritical)
            Critical, %previousCritical%
        else
            Critical, Off
        reason := "BUSY_" . busyOwner
        if (!lastSkip.HasKey(owner) || lastSkip[owner]!=reason || A_TickCount-lastSkipTick[owner]>=500)
        {
            DebugTraceWrite(channel,"ITEM_ACTION_SKIP requested=" . owner . " busy=" . busyOwner)
            lastSkip[owner] := reason, lastSkipTick[owner] := A_TickCount
        }
        return false
    }
    gameItemActionOwner := owner
    if (owner="Belt" || owner="Cube")
    {
        SetTimer, PickupImageTimer, Off
        SetTimer, AutoPotTimer, Off
        gameItemTimersPausedOwner := owner
        DebugTraceWrite(channel,"BACKGROUND_PAUSE owner=" . owner . " pickup_timer=OFF heal_timer=OFF")
    }
    if (previousCritical)
        Critical, %previousCritical%
    else
        Critical, Off
    if (requireEmpty)
    {
        ctx := D2OpenHealContextV3()
        cursor := ctx.reason="OK" ? PickupCursorV4(ctx.h,ctx.inv) : -1
        if (ctx.reason="OK")
            DllCall("CloseHandle","Ptr",ctx.h)
        if (!IsObject(cursor) || cursor.unit)
        {
            reason := "CURSOR_NOT_EMPTY_OR_UNREADABLE"
            if (!lastSkip.HasKey(owner) || lastSkip[owner]!=reason || A_TickCount-lastSkipTick[owner]>=500)
            {
                DebugTraceWrite(channel,"ITEM_ACTION_SKIP requested=" . owner . " reason=" . reason)
                lastSkip[owner] := reason, lastSkipTick[owner] := A_TickCount
            }
            GameItemActionEndV4(owner)
            return false
        }
    }
    if (lastSkip.HasKey(owner))
    {
        DebugTraceWrite(channel,"ITEM_ACTION_RESUME owner=" . owner)
        lastSkip.Delete(owner), lastSkipTick.Delete(owner)
    }
    if (owner="Belt" || owner="Cube")
        DebugTraceWrite(channel,"ITEM_ACTION_BEGIN owner=" . owner)
    return true
}

GameItemActionEndV4(owner)
{
    global gameItemActionOwner, gameItemTimersPausedOwner
    if (gameItemActionOwner!=owner)
        return
    if (gameItemTimersPausedOwner=owner)
    {
        gameItemTimersPausedOwner := ""
        gameItemActionOwner := ""
        SetTimer, AutoPotTimer, 50
        SetTimer, PickupImageTimer, 20
        DebugTraceWrite(owner="Belt" ? "belt" : "cube"
            ,"BACKGROUND_RESTORE owner=" . owner . " pickup_timer=20ms heal_timer=50ms")
        return
    }
    gameItemActionOwner := ""
}

V50MoveConfirmedV4(pid, uid, cls, slot)
{
    global cubeTransferDelayMs
    Loop, 3
    {
        attempt := A_Index
        ctx := D2OpenHealContextV3()
        if (ctx.reason!="OK" || ctx.pid!=pid)
        {
            if (ctx.reason="OK")
                DllCall("CloseHandle","Ptr",ctx.h)
            return false
        }
        cursor := PickupCursorV4(ctx.h,ctx.inv)
        snapshot := V9SnapshotAllItems(ctx)
        sent := false
        if (IsObject(cursor))
        {
            if (cursor.unit && cursor.uid=uid && cursor.cls=cls)
                sent := V50SendCursorToBeltV4({pid:pid},uid,slot)
            else if (!cursor.unit && snapshot.HasKey(uid))
            {
                item := snapshot[uid]
                if (item.cls=cls && item.loc=0 && item.owner=ctx.inv
                    && D2ReadU32(ctx.h,item.unit+0x0C)=uid)
                {
                    sent := V50RemotePacket26({pid:pid},uid,slot)
                }
            }
        }
        BeltSendLogV101("FILL_ATTEMPT uid=" . uid . " slot=" . slot
            . " attempt=" . attempt . " sent=" . sent)
        confirmStart := A_TickCount
        while (A_TickCount-confirmStart<600 && PickupGameActiveV2(pid))
        {
            Sleep, %cubeTransferDelayMs%
            cursor := PickupCursorV4(ctx.h,ctx.inv)
            snapshot := V9SnapshotAllItems(ctx)
            if (!IsObject(cursor) || (cursor.unit && cursor.uid=uid) || !snapshot.HasKey(uid))
                continue
            item := snapshot[uid]
            if (item.cls=cls && item.x=slot
                && D2ReadU32(ctx.h,item.unit+0x0C)=uid
                && D2ReadU32(ctx.h,item.unit+0x10)=2)
            {
                DllCall("CloseHandle","Ptr",ctx.h)
                BeltSendLogV101("FILL_CONFIRMED uid=" . uid . " class=" . cls . " slot=" . slot)
                return true
            }
        }
        cursor := PickupCursorV4(ctx.h,ctx.inv)
        live := snapshot.HasKey(uid) ? snapshot[uid] : 0
        BeltSendLogV101("FILL_STATE uid=" . uid . " target_slot=" . slot
            . " attempt=" . attempt . " cursor_read=" . IsObject(cursor)
            . " cursor_uid=" . (IsObject(cursor) ? cursor.uid : -1)
            . " found=" . IsObject(live) . " loc=" . (IsObject(live) ? live.loc : -1)
            . " xy=" . (IsObject(live) ? live.x . "," . live.y : "UNKNOWN"))
        for beltUid, beltItem in snapshot
        {
            if (D2ReadU32(ctx.h,beltItem.unit+0x10)=2
                && (!IsObject(cursor) || beltItem.unit!=cursor.unit))
                BeltSendLogV101("BELT_ACTUAL uid=" . beltUid . " class=" . beltItem.cls
                    . " xy=" . beltItem.x . "," . beltItem.y
                    . " mode=" . D2ReadU32(ctx.h,beltItem.unit+0x10))
        }
        if (attempt=3 && PickupGameActiveV2(pid) && IsObject(cursor)
            && cursor.unit && cursor.uid=uid && cursor.cls=cls)
        {
            dropped := false
            Loop, 3
            {
                cursor := PickupCursorV4(ctx.h,ctx.inv)
                if (!IsObject(cursor))
                    break
                if (!cursor.unit)
                {
                    dropped := true
                    break
                }
                if (cursor.uid!=uid || cursor.cls!=cls)
                    break
                sentDrop := PickupDropCursorV4(ctx.h,pid,ctx.inv,{uid:uid,cls:cls},"belt")
                BeltSendLogV101("BELT_DROP uid=" . uid . " try=" . A_Index . " sent=" . sentDrop)
                startDrop := A_TickCount
                while (A_TickCount-startDrop<600 && PickupGameActiveV2(pid))
                {
                    Sleep, %cubeTransferDelayMs%
                    cursor := PickupCursorV4(ctx.h,ctx.inv)
                    if (IsObject(cursor) && !cursor.unit)
                    {
                        dropped := true
                        break
                    }
                }
                if (dropped)
                    break
            }
            BeltSendLogV101("BELT_DROP_RESULT uid=" . uid . " confirmed=" . dropped
                . " cursor_empty=" . (IsObject(cursor) && !cursor.unit))
        }
        DllCall("CloseHandle","Ptr",ctx.h)
        BeltSendLogV101("FILL_NOT_CONFIRMED uid=" . uid . " slot=" . slot
            . " attempt=" . attempt . " retry=" . (attempt<3))
    }
    return false
}

V50SendCursorToBeltV4(ctx, itemUid, beltSlot)
{
    if (RemoteThreadBusyV740(D2GetActiveGamePidV95()))
        return false
    pid := ctx.pid
    if (!PickupGameActiveV2(pid) || beltSlot<0 || beltSlot>15)
        return false
    netBase := D2GetModuleBaseV35(pid,"D2Net.dll")
    if (!netBase)
        return false
    sendFn := netBase + 0x7650
    hSend := DllCall("OpenProcess","UInt",0x043A,"Int",0,"UInt",pid,"Ptr")
    if (!hSend)
        return false
    remote := DllCall("VirtualAllocEx","Ptr",hSend,"Ptr",0,"UPtr",128,"UInt",0x3000,"UInt",0x40,"Ptr")
    if (!remote)
    {
        DllCall("CloseHandle","Ptr",hSend)
        return false
    }
    VarSetCapacity(pkt,9,0)
    NumPut(0x23,pkt,0,"UChar")
    NumPut(itemUid,pkt,1,"UInt")
    NumPut(beltSlot,pkt,5,"UInt")
    wrotePkt := 0
    okPkt := DllCall("WriteProcessMemory","Ptr",hSend,"Ptr",remote+64,"Ptr",&pkt,"UPtr",9,"UPtrP",wrotePkt)
    VarSetCapacity(code,32,0)
    o:=0
    NumPut(0x68,code,o,"UChar"),o+=1
    NumPut(remote+64,code,o,"UInt"),o+=4
    NumPut(0x6A,code,o,"UChar"),o+=1
    NumPut(0x01,code,o,"UChar"),o+=1
    NumPut(0x6A,code,o,"UChar"),o+=1
    NumPut(0x09,code,o,"UChar"),o+=1
    NumPut(0xB8,code,o,"UChar"),o+=1
    NumPut(sendFn,code,o,"UInt"),o+=4
    NumPut(0xFF,code,o,"UChar"),o+=1
    NumPut(0xD0,code,o,"UChar"),o+=1
    NumPut(0xC3,code,o,"UChar"),o+=1
    wroteCode:=0
    okCode := DllCall("WriteProcessMemory","Ptr",hSend,"Ptr",remote,"Ptr",&code,"UPtr",o,"UPtrP",wroteCode)
    if (!okPkt || !okCode)
    {
        DllCall("VirtualFreeEx","Ptr",hSend,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hSend)
        return false
    }
    th := DllCall("CreateRemoteThread","Ptr",hSend,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
    if (!th)
    {
        DllCall("VirtualFreeEx","Ptr",hSend,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hSend)
        return false
    }
    wait := DllCall("WaitForSingleObject","Ptr",th,"UInt",1000)
    waitLimit := 5
    while (wait == 258 && IsGameActive() && waitLimit > 0)
    {
        wait := DllCall("WaitForSingleObject", "Ptr", th, "UInt", 1000)
        waitLimit--
    }
    exitCode:=0
    DllCall("GetExitCodeThread","Ptr",th,"UIntP",exitCode)
    RemoteThreadFinishV740(hSend,th,remote,wait)
    return (wait=0)
}

V50ConfigureBelt(want)
{
    global cubePickupDelayMs, cubeTransferDelayMs
    BeltSendLogV101("=== START V3 BELT + PICKUP STACK DIAG ===")
    BeltSendLogV101("MODE=" . want[1] . "," . want[2] . "," . want[3] . "," . want[4])
    BeltSendLogV101("TIMING pickup_ms=" . cubePickupDelayMs . " confirm_ms=" . cubeTransferDelayMs)

    retry := 0

V85_Restart:
    retry++
    BeltSendLogV101("PASS=" . retry)

    if (retry > 20)
    {
        BeltSendLogV101("RETRY_LIMIT -> STOP")
        return false
    }

    if (!IsGameActive())
        return false

    belt := V76ScanBeltSlots()
    if (!IsObject(belt))
    {
        Sleep, 80
        Goto, V85_Restart
    }

    wrongColumns := []
    Loop, 4
    {
        col := A_Index - 1
        target := want[A_Index]
        wrongColumn := false
        Loop, 4
        {
            row := A_Index - 1
            slot := col + row*4
            if (belt.HasKey(slot))
            {
                info := belt[slot]
                if (IsObject(info) && info.cls != target)
                {
                    wrongColumn := true
                    break
                }
            }
        }
        if (wrongColumn)
            wrongColumns.Push(col)
    }
    for _, col in wrongColumns
    {
        beltKey := col + 1
        previousCount := 5, noProgress := 0, emptyColumn := false
        Loop, 8
        {
            batch := A_Index
            BeltSendLogV101("CLEAR_WRONG_COLUMN col=" . col . " key=" . beltKey . " batch=" . batch)
            if (!IsGameActive())
                return false
            SetKeyDelay, %cubeTransferDelayMs%, %cubeTransferDelayMs%
            Loop, 4
            {
                BuffCheckedSendV29(beltKey)
            }
            SetKeyDelay, 30, 30
            belt := V76ScanBeltSlots()
            if (!IsObject(belt))
                return false
            remaining := 0
            Loop, 4
                if (belt.HasKey(col + (A_Index - 1)*4))
                    remaining++
            BeltSendLogV101("CLEAR_CHECK col=" . col . " remaining=" . remaining)
            if (!remaining)
            {
                emptyColumn := true
                break
            }
            if (remaining >= previousCount)
                noProgress++
            else
                noProgress := 0
            if (noProgress >= 3)
                break
            previousCount := remaining
        }
        if (!emptyColumn)
        {
            BeltSendLogV101("CLEAR_NOT_EMPTY col=" . col . " -> STOP")
            return false
        }
    }

    needHP := 0, needMP := 0
    Loop, 4
    {
        target := want[A_Index]
        if (target = 1229)
            needHP += 4
        else if (target = 1234)
            needMP += 4
    }
    pool := V78ScanInventoryPotions(needHP, needMP)

    if (!IsObject(belt) || !IsObject(pool))
    {
        Sleep, 80
        Goto, V85_Restart
    }

    BeltSendLogV101("POOL HP=" . pool[1229].Length() . " MP=" . pool[1234].Length())

    Loop, 4
    {
        col := A_Index - 1
        target := want[A_Index]

        Loop, 4
        {
            row := A_Index - 1
            slot := col + row*4

            if (belt.HasKey(slot))
            {
                info := belt[slot]
                if (IsObject(info) && info.cls = target)
                {
                    BeltSendLogV101("OK slot=" . slot . " cls=" . info.cls . " uid=" . info.uid)
                    continue
                }

                BeltSendLogV101("UNEXPECTED_SLOT slot=" . slot . " -> RESET")
                Sleep, 80
                Goto, V85_Restart
            }

            if (!pool.HasKey(target) || pool[target].Length() < 1)
            {
                BeltSendLogV101("POOL_EMPTY class=" . target . " -> STOP")
                return false
            }

            it := pool[target].RemoveAt(1)
            BeltSendLogV101("FAST_FILL slot=" . slot . " class=" . target . " uid=" . it.uid)

            if (!V50MoveConfirmedV4(pool.pid, it.uid, target, slot))
            {
                BeltSendLogV101("FAST_FILL_FAIL slot=" . slot . " uid=" . it.uid . " -> STOP")
                return false
            }

            belt[slot] := {cls:target, uid:it.uid, slot:slot}
            BeltSendLogV101("FILL_DONE slot=" . slot . " uid=" . it.uid . " confirmed=1")

            Sleep, %cubeTransferDelayMs%
        }
    }

    BeltSendLogV101("=== END BELT FILLS CONFIRMED ===")
    return true
}

V78ScanInventoryPotions(needHP := 16, needMP := 16)
{
    ctx := V44OpenGameContext()
    if (!IsObject(ctx))
        return ""

    h := ctx.h, inv := ctx.inv
    pool := {}
    pool[1229] := []
    pool[1234] := []

    scan := HealScanRootsV4(h,ctx.inv)
    if (scan.errors)
    {
        DllCall("CloseHandle","Ptr",h)
        BeltSendLogV101("BELT_SCAN_ROOT_ERROR function=V78ScanInventoryPotions")
        return ""
    }
    queue := scan.roots, seen := {}, qi := 1
    while (qi <= queue.Length() && qi <= 8192)
    {
        if (pool[1229].Length() >= needHP && pool[1234].Length() >= needMP)
            break
        u := queue[qi], qi++
        if (!u || seen.HasKey(u))
            continue
        seen[u] := 1

        typ := D2ReadU32(h,u+0x00)
        cls := D2ReadU32(h,u+0x04)
        itemData := (typ=4) ? D2ReadU32(h,u+0x14) : 0

        if (typ=4 && itemData && (cls=1229 || cls=1234)
            && D2ReadU8V18(h,itemData+0x45)=0
            && D2ReadU32(h,itemData+0x5C)=inv)
        {
            uid := D2ReadU32(h,u+0x0C)
            if (uid && ((cls=1229 && pool[1229].Length() < needHP)
                || (cls=1234 && pool[1234].Length() < needMP)))
                pool[cls].Push({uid:uid, cls:cls, itemData:itemData})
        }

        e4:=D2ReadU32(h,u+0xE4), e8:=D2ReadU32(h,u+0xE8)
        if (e4 && !seen.HasKey(e4))
            queue.Push(e4)
        if (e8 && !seen.HasKey(e8))
            queue.Push(e8)

        if (typ=4 && itemData)
        {
            ptrOffsets := [0x60,0x64,0x6C,0x70,0x84,0xAC,0xB0,0xB4,0xC8,0xD8]
            for _,po in ptrOffsets
            {
                pu:=D2ReadU32(h,itemData+po)
                if (pu && !seen.HasKey(pu) && D2ReadU32(h,pu)=4)
                    queue.Push(pu)
            }
        }
    }

    pool.pid := ctx.pid
    DllCall("CloseHandle","Ptr",h)
    return pool
}


V76ScanBeltSlots()
{
    if (!IsGameActive())
        return ""

    ctx := V44OpenGameContext()
    if (!IsObject(ctx))
        return ""

    h := ctx.h
    cursor := PickupCursorV4(h,ctx.inv)
    if (!IsObject(cursor))
    {
        DllCall("CloseHandle","Ptr",h)
        return ""
    }
    scan := HealScanRootsV4(h,ctx.inv)
    if (scan.errors)
    {
        DllCall("CloseHandle","Ptr",h)
        BeltSendLogV101("BELT_SCAN_ROOT_ERROR function=V76ScanBeltSlots")
        return ""
    }
    queue := scan.roots, seen := {}, qi := 1
    slots := {}

    while (qi <= queue.Length() && qi <= 8192)
    {
        u := queue[qi], qi++
        if (!u || seen.HasKey(u))
            continue
        seen[u] := 1

        typ := D2ReadU32(h,u+0x00)
        cls := D2ReadU32(h,u+0x04)
        uid := D2ReadU32(h,u+0x0C)
        itemData := (typ=4) ? D2ReadU32(h,u+0x14) : 0

        if (typ=4 && itemData && uid)
        {
            loc45 := D2ReadU8V18(h,itemData+0x45)
            mode := D2ReadU32(h,u+0x10)
            if (mode=2 && u!=cursor.unit)
            {
                path := D2ReadU32(h,u+0x2C)
                if (path)
                {
                    slot := D2ReadU32(h,path+0x0C)
                    if (slot >= 0 && slot <= 15 && uid!=0xFFFFFFFF
                        && D2ReadU32(h,u+0x0C)=uid && D2ReadU32(h,u+0x10)=2)
                    {
                        slots[slot] := {cls:cls,uid:uid,slot:slot,unit:u}
                        BeltSendLogV101("BELT_SLOT_READ slot=" . slot . " uid=" . uid
                            . " class=" . cls . " mode=" . mode . " loc=" . loc45)
                    }
                }
            }
        }

        e4:=D2ReadU32(h,u+0xE4), e8:=D2ReadU32(h,u+0xE8)
        if (e4 && !seen.HasKey(e4))
            queue.Push(e4)
        if (e8 && !seen.HasKey(e8))
            queue.Push(e8)

        if (typ=4 && itemData)
        {
            ptrOffsets := [0x60,0x64,0x6C,0x70,0x84,0xAC,0xB0,0xB4,0xC8,0xD8]
            for _,po in ptrOffsets
            {
                pu:=D2ReadU32(h,itemData+po)
                if (pu && !seen.HasKey(pu) && D2ReadU32(h,pu)=4)
                    queue.Push(pu)
            }
        }
    }

    DllCall("CloseHandle","Ptr",h)
    return slots
}

V50RemotePacket26(ctx, unitId, beltSlot)
{
    if (RemoteThreadBusyV740(D2GetActiveGamePidV95()))
        return false
    global cubePickupDelayMs
    pid := ctx.pid
    if (!pid)
        return false

    if (beltSlot < 0 || beltSlot > 15)
    {
        BeltSendLogV101("DIRECT19_23_BLOCK invalid_slot=" . beltSlot)
        return false
    }

    netBase := D2GetModuleBaseV35(pid, "D2Net.dll")
    if (!netBase)
    {
        BeltSendLogV101("DIRECT19_23_BLOCK D2Net=0")
        return false
    }

    sendFn := netBase + 0x7650
    BeltSendLogV101("DIRECT19_23 D2Net=" . V92Hex(netBase) . " Send=" . V92Hex(sendFn)
        . " uid=" . unitId . " slot=" . beltSlot)

    hSend := DllCall("OpenProcess", "UInt", 0x043A, "Int", 0, "UInt", pid, "Ptr")
    if (!hSend)
    {
        BeltSendLogV101("DIRECT19_23 OpenProcess_FAIL err=" . A_LastError)
        return false
    }

    remote := DllCall("VirtualAllocEx", "Ptr", hSend, "Ptr", 0, "UPtr", 256
        , "UInt", 0x3000, "UInt", 0x40, "Ptr")
    if (!remote)
    {
        err := A_LastError
        DllCall("CloseHandle", "Ptr", hSend)
        BeltSendLogV101("DIRECT19_23 Alloc_FAIL err=" . err)
        return false
    }

    VarSetCapacity(pkt19, 5, 0)
    NumPut(0x19, pkt19, 0, "UChar")
    NumPut(unitId, pkt19, 1, "UInt")

    VarSetCapacity(pkt23, 9, 0)
    NumPut(0x23, pkt23, 0, "UChar")
    NumPut(unitId, pkt23, 1, "UInt")
    NumPut(beltSlot, pkt23, 5, "UInt")

    wrote19 := 0, wrote23 := 0
    ok19 := DllCall("WriteProcessMemory", "Ptr", hSend, "Ptr", remote+128
        , "Ptr", &pkt19, "UPtr", 5, "UPtrP", wrote19)
    ok23 := DllCall("WriteProcessMemory", "Ptr", hSend, "Ptr", remote+160
        , "Ptr", &pkt23, "UPtr", 9, "UPtrP", wrote23)

    VarSetCapacity(code19, 32, 0)
    o := 0
    NumPut(0x68, code19, o, "UChar"), o += 1
    NumPut(remote+128, code19, o, "UInt"), o += 4
    NumPut(0x6A, code19, o, "UChar"), o += 1
    NumPut(0x01, code19, o, "UChar"), o += 1
    NumPut(0x6A, code19, o, "UChar"), o += 1
    NumPut(0x05, code19, o, "UChar"), o += 1
    NumPut(0xB8, code19, o, "UChar"), o += 1
    NumPut(sendFn, code19, o, "UInt"), o += 4
    NumPut(0xFF, code19, o, "UChar"), o += 1
    NumPut(0xD0, code19, o, "UChar"), o += 1
    NumPut(0xC3, code19, o, "UChar"), o += 1
    wroteCode19 := 0
    okCode19 := DllCall("WriteProcessMemory", "Ptr", hSend, "Ptr", remote
        , "Ptr", &code19, "UPtr", o, "UPtrP", wroteCode19)

    VarSetCapacity(code23, 32, 0)
    p := 0
    NumPut(0x68, code23, p, "UChar"), p += 1
    NumPut(remote+160, code23, p, "UInt"), p += 4
    NumPut(0x6A, code23, p, "UChar"), p += 1
    NumPut(0x01, code23, p, "UChar"), p += 1
    NumPut(0x6A, code23, p, "UChar"), p += 1
    NumPut(0x09, code23, p, "UChar"), p += 1
    NumPut(0xB8, code23, p, "UChar"), p += 1
    NumPut(sendFn, code23, p, "UInt"), p += 4
    NumPut(0xFF, code23, p, "UChar"), p += 1
    NumPut(0xD0, code23, p, "UChar"), p += 1
    NumPut(0xC3, code23, p, "UChar"), p += 1
    wroteCode23 := 0
    okCode23 := DllCall("WriteProcessMemory", "Ptr", hSend, "Ptr", remote+64
        , "Ptr", &code23, "UPtr", p, "UPtrP", wroteCode23)

    if (!ok19 || !ok23 || !okCode19 || !okCode23)
    {
        err := A_LastError
        DllCall("VirtualFreeEx", "Ptr", hSend, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        DllCall("CloseHandle", "Ptr", hSend)
        BeltSendLogV101("DIRECT19_23 Write_FAIL err=" . err)
        return false
    }

    BeltSendLogV101("PACKET19 uid=" . unitId)
    th1 := DllCall("CreateRemoteThread", "Ptr", hSend, "Ptr", 0, "UPtr", 0
        , "Ptr", remote, "Ptr", 0, "UInt", 0, "UIntP", tid1, "Ptr")
    if (!th1)
    {
        err := A_LastError
        DllCall("VirtualFreeEx", "Ptr", hSend, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        DllCall("CloseHandle", "Ptr", hSend)
        BeltSendLogV101("DIRECT19_23 Thread19_FAIL err=" . err)
        return false
    }
    wait1 := DllCall("WaitForSingleObject", "Ptr", th1, "UInt", 1000)
    exit1 := 0
    DllCall("GetExitCodeThread", "Ptr", th1, "UIntP", exit1)
    BeltSendLogV101("PACKET19_RESULT wait=" . wait1 . " exit=" . V92Hex(exit1)
        . " pkt=" . wrote19 . " code=" . wroteCode19)
    if (wait1 != 0)
    {
        RemoteThreadFinishV740(hSend,th1,remote,wait1)
        return false
    }
    DllCall("CloseHandle", "Ptr", th1)

    Sleep, %cubePickupDelayMs%

    BeltSendLogV101("PACKET23 uid=" . unitId . " slot=" . beltSlot)
    th2 := DllCall("CreateRemoteThread", "Ptr", hSend, "Ptr", 0, "UPtr", 0
        , "Ptr", remote+64, "Ptr", 0, "UInt", 0, "UIntP", tid2, "Ptr")
    if (!th2)
    {
        err := A_LastError
        DllCall("VirtualFreeEx", "Ptr", hSend, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        DllCall("CloseHandle", "Ptr", hSend)
        BeltSendLogV101("DIRECT19_23 Thread23_FAIL err=" . err)
        return false
    }
    wait2 := DllCall("WaitForSingleObject", "Ptr", th2, "UInt", 1000)
    exit2 := 0
    DllCall("GetExitCodeThread", "Ptr", th2, "UIntP", exit2)

    RemoteThreadFinishV740(hSend,th2,remote,wait2)

    ok := (wait1 = 0 && wait2 = 0)
    BeltSendLogV101("PACKET23_RESULT wait=" . wait2 . " exit=" . V92Hex(exit2)
        . " pkt=" . wrote23 . " code=" . wroteCode23 . " ok=" . ok)
    return ok
}

TransferHotkeyTrace(action)
{
    global pickupCubeTraceUntil, xRunning, v103CubeMoveRunning, debugPrivilegeOK, debugPrivilegeError
    if (!pickupCubeTraceUntil || A_TickCount >= pickupCubeTraceUntil)
        return
    traceChannel := (action="RUONG_TO_CUBE") ? "cube" : "belt"
    pid := D2GetActiveGamePidV95()
    WinGet, processName, ProcessName, A
    WinGetTitle, title, A
    active := IsGameActive()
    DebugTraceWrite(traceChannel, "TRANSFER_KEY action=" . action . " hotkey=" . A_ThisHotkey
        . " pid=" . pid . " process=" . processName . " title=" . title
        . " active=" . active . " ahk_bits=" . (A_PtrSize*8) . " admin=" . A_IsAdmin
        . " debug_privilege=" . debugPrivilegeOK . " debug_error=" . debugPrivilegeError
        . " xRunning=" . xRunning . " cubeRunning=" . v103CubeMoveRunning)
    if (!active || !pid)
        return
    snap := DllCall("CreateToolhelp32Snapshot", "UInt", 0x8|0x10, "UInt", pid, "Ptr")
    snapError := (snap && snap!=-1) ? 0 : A_LastError
    base := 0, firstError := 0, nextError := 0, moduleCount := 0
    if (snap && snap != -1)
    {
        sz := (A_PtrSize=8) ? 1080 : 1064
        nameOffset := (A_PtrSize=8) ? 48 : 32
        baseOffset := (A_PtrSize=8) ? 24 : 20
        VarSetCapacity(me, sz, 0)
        NumPut(sz, me, 0, "UInt")
        ok := DllCall("Module32FirstW", "Ptr", snap, "Ptr", &me)
        firstError := ok ? 0 : A_LastError
        while (ok)
        {
            moduleCount++
            moduleName := StrGet(&me+nameOffset, 256, "UTF-16")
            if (moduleName="D2Client.dll")
                base := NumGet(me, baseOffset, "Ptr")
            ok := DllCall("Module32NextW", "Ptr", snap, "Ptr", &me)
            nextError := A_LastError
        }
        DllCall("CloseHandle", "Ptr", snap)
    }
    h := D2OpenProcess(pid)
    openError := h ? 0 : A_LastError
    player := (h && base) ? D2ReadU32(h, base+0x11BBFC) : 0
    inv := player ? D2ReadU32(h, player+0x60) : 0
    first := inv ? D2ReadU32(h, inv+0x10) : 0
    DebugTraceWrite(traceChannel, "TRANSFER_OPEN snapshot=" . snap . " snapshot_error=" . snapError
        . " module_first_error=" . firstError . " module_next_error=" . nextError
        . " module_count=" . moduleCount . " D2Client=" . base
        . " process_handle=" . h . " open_error=" . openError
        . " player=" . player . " inventory=" . inv . " first_item=" . first)
    if (h)
        DllCall("CloseHandle", "Ptr", h)
}

DebugTraceFile(channel)
{
    if (channel="pickup")
        return TxtRootPathV816("Auto-GSF-Nhat-Ruong.txt")
    if (channel="belt")
        return TxtRootPathV816("Auto-GSF-Ruong-Belt.txt")
    if (channel="cube")
        return TxtRootPathV816("Auto-GSF-Ruong-Cube.txt")
    if (channel="heal")
        return TxtRootPathV816("Auto-GSF-Buff-HP-Mana.txt")
    if (channel="monster")
        return TxtRootPathV816("Auto-GSF-Quai-Boss.txt")
    if (channel="character")
        return TxtRootPathV816("Auto-GSF-Nhan-Vat-DLL.txt")
    if (channel="packet")
        return TxtRootPathV816("Auto-GSF-Click-Phai-Packet.txt")
    return ""
}

DebugTraceWrite(channel, message)
{
    if (!ManualLogActiveV81())
        return
    global pickupCubeTraceUntil
    if (!pickupCubeTraceUntil || A_TickCount >= pickupCubeTraceUntil)
        return
    log := DebugTraceFile(channel)
    if (log="")
        return
    ManualLogAppendV81(A_Now . " tick=" . A_TickCount . " | " . message . "`r`n", log, "UTF-8")
}

V104CubeLog(message)
{
    isCube := InStr(message, "PICKUP_CUBE_")=1
        || InStr(message, "PICKUP_CURSOR_")=1
        || InStr(message, "PICKUP_RELEASE_")=1
        || InStr(message, "PICKUP_")!=1
    DebugTraceWrite(isCube ? "cube" : "pickup", message)
}

V104RemotePacket19_2A(ctx, unitId, cubeUid, itemUnit, itemData, cubeUnit, cubeData, inv, potionClass)
{
    if (RemoteThreadBusyV740(D2GetActiveGamePidV95()))
        return false
    global cubePickupDelayMs
    if (unitId=cubeUid || potionClass=1204)
    {
        V104CubeLog("DIRECT19_2A_BLOCK reason=CUBE_SELF_INSERT uid=" . unitId . " cube_uid=" . cubeUid)
        return false
    }
    pid := ctx.pid
    if (!pid)
        return false
    if (!ctx.allowAny && potionClass != 1229 && potionClass != 1234)
    {
        V104CubeLog("DIRECT19_2A_BLOCK invalid_potion_class=" . potionClass)
        return false
    }
    if (cubeUid <= 0)
    {
        V104CubeLog("DIRECT19_2A_BLOCK invalid_cube_uid=" . cubeUid)
        return false
    }
    netBase := D2GetModuleBaseV35(pid, "D2Net.dll")
    if (!netBase)
    {
        V104CubeLog("DIRECT19_2A_BLOCK D2Net=0")
        return false
    }
    sendFn := netBase + 0x7650
    V104CubeLog("DIRECT19_2A D2Net=" . V92Hex(netBase) . " Send=" . V92Hex(sendFn)
        . " uid=" . unitId . " cube_uid=" . cubeUid)
    hSend := DllCall("OpenProcess", "UInt", 0x043A, "Int", 0, "UInt", pid, "Ptr")
    if (!hSend)
    {
        V104CubeLog("DIRECT19_2A OpenProcess_FAIL err=" . A_LastError)
        return false
    }
    remote := DllCall("VirtualAllocEx", "Ptr", hSend, "Ptr", 0, "UPtr", 256
        , "UInt", 0x3000, "UInt", 0x40, "Ptr")
    if (!remote)
    {
        err := A_LastError
        DllCall("CloseHandle", "Ptr", hSend)
        V104CubeLog("DIRECT19_2A Alloc_FAIL err=" . err)
        return false
    }
    VarSetCapacity(pkt19, 5, 0)
    NumPut(0x19, pkt19, 0, "UChar")
    NumPut(unitId, pkt19, 1, "UInt")
    VarSetCapacity(pkt2A, 9, 0)
    NumPut(0x2A, pkt2A, 0, "UChar")
    NumPut(unitId, pkt2A, 1, "UInt")
    NumPut(cubeUid, pkt2A, 5, "UInt")
    wrote19 := 0, wrote2A := 0
    ok19 := DllCall("WriteProcessMemory", "Ptr", hSend, "Ptr", remote+128
        , "Ptr", &pkt19, "UPtr", 5, "UPtrP", wrote19)
    ok2A := DllCall("WriteProcessMemory", "Ptr", hSend, "Ptr", remote+160
        , "Ptr", &pkt2A, "UPtr", 9, "UPtrP", wrote2A)
    VarSetCapacity(code19, 32, 0)
    o := 0
    NumPut(0x68, code19, o, "UChar"), o += 1
    NumPut(remote+128, code19, o, "UInt"), o += 4
    NumPut(0x6A, code19, o, "UChar"), o += 1
    NumPut(0x01, code19, o, "UChar"), o += 1
    NumPut(0x6A, code19, o, "UChar"), o += 1
    NumPut(0x05, code19, o, "UChar"), o += 1
    NumPut(0xB8, code19, o, "UChar"), o += 1
    NumPut(sendFn, code19, o, "UInt"), o += 4
    NumPut(0xFF, code19, o, "UChar"), o += 1
    NumPut(0xD0, code19, o, "UChar"), o += 1
    NumPut(0xC3, code19, o, "UChar"), o += 1
    wroteCode19 := 0
    okCode19 := DllCall("WriteProcessMemory", "Ptr", hSend, "Ptr", remote
        , "Ptr", &code19, "UPtr", o, "UPtrP", wroteCode19)
    VarSetCapacity(code2A, 32, 0)
    p := 0
    NumPut(0x68, code2A, p, "UChar"), p += 1
    NumPut(remote+160, code2A, p, "UInt"), p += 4
    NumPut(0x6A, code2A, p, "UChar"), p += 1
    NumPut(0x01, code2A, p, "UChar"), p += 1
    NumPut(0x6A, code2A, p, "UChar"), p += 1
    NumPut(0x09, code2A, p, "UChar"), p += 1
    NumPut(0xB8, code2A, p, "UChar"), p += 1
    NumPut(sendFn, code2A, p, "UInt"), p += 4
    NumPut(0xFF, code2A, p, "UChar"), p += 1
    NumPut(0xD0, code2A, p, "UChar"), p += 1
    NumPut(0xC3, code2A, p, "UChar"), p += 1
    wroteCode2A := 0
    okCode2A := DllCall("WriteProcessMemory", "Ptr", hSend, "Ptr", remote+64
        , "Ptr", &code2A, "UPtr", p, "UPtrP", wroteCode2A)
    if (!ok19 || !ok2A || !okCode19 || !okCode2A)
    {
        err := A_LastError
        DllCall("VirtualFreeEx", "Ptr", hSend, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        DllCall("CloseHandle", "Ptr", hSend)
        V104CubeLog("DIRECT19_2A Write_FAIL err=" . err)
        return false
    }
    if (D2ReadU32(hSend,itemUnit+0x00) != 4
        || D2ReadU32(hSend,itemUnit+0x0C) != unitId
        || D2ReadU32(hSend,itemUnit+0x04) != potionClass
        || D2ReadU32(hSend,itemUnit+0x14) != itemData
        || D2ReadU8V18(hSend,itemData+0x45) != 0
        || D2ReadU32(hSend,itemData+0x5C) != inv
        || D2ReadU32(hSend,cubeUnit+0x00) != 4
        || D2ReadU32(hSend,cubeUnit+0x0C) != cubeUid
        || D2ReadU32(hSend,cubeUnit+0x04) != 1204
        || D2ReadU32(hSend,cubeUnit+0x14) != cubeData
        || D2ReadU8V18(hSend,cubeData+0x45) != 0
        || D2ReadU32(hSend,cubeData+0x5C) != inv)
    {
        V104CubeLog("SKIP_WRONG_POTION_OR_CUBE_CHANGED uid=" . unitId . " class=" . potionClass . " cube_uid=" . cubeUid)
        DllCall("VirtualFreeEx", "Ptr", hSend, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        DllCall("CloseHandle", "Ptr", hSend)
        return false
    }
    V104CubeLog("PACKET19 uid=" . unitId)
    th1 := DllCall("CreateRemoteThread", "Ptr", hSend, "Ptr", 0, "UPtr", 0
        , "Ptr", remote, "Ptr", 0, "UInt", 0, "UIntP", tid1, "Ptr")
    if (!th1)
    {
        err := A_LastError
        DllCall("VirtualFreeEx", "Ptr", hSend, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        DllCall("CloseHandle", "Ptr", hSend)
        V104CubeLog("DIRECT19_2A Thread19_FAIL err=" . err)
        return false
    }
    wait1 := DllCall("WaitForSingleObject", "Ptr", th1, "UInt", 1000)
    exit1 := 0
    DllCall("GetExitCodeThread", "Ptr", th1, "UIntP", exit1)
    V104CubeLog("PACKET19_RESULT wait=" . wait1 . " exit=" . V92Hex(exit1)
        . " pkt=" . wrote19 . " code=" . wroteCode19)
    if (wait1 != 0)
    {
        RemoteThreadFinishV740(hSend,th1,remote,wait1)
        return false
    }
    DllCall("CloseHandle", "Ptr", th1)
    Sleep, %cubePickupDelayMs%
    V104CubeLog("PACKET2A uid=" . unitId . " cube_uid=" . cubeUid)
    th2 := DllCall("CreateRemoteThread", "Ptr", hSend, "Ptr", 0, "UPtr", 0
        , "Ptr", remote+64, "Ptr", 0, "UInt", 0, "UIntP", tid2, "Ptr")
    if (!th2)
    {
        err := A_LastError
        DllCall("VirtualFreeEx", "Ptr", hSend, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        DllCall("CloseHandle", "Ptr", hSend)
        V104CubeLog("DIRECT19_2A Thread2A_FAIL err=" . err)
        return false
    }
    wait2 := DllCall("WaitForSingleObject", "Ptr", th2, "UInt", 1000)
    exit2 := 0
    DllCall("GetExitCodeThread", "Ptr", th2, "UIntP", exit2)
    RemoteThreadFinishV740(hSend,th2,remote,wait2)
    ok := (wait1 = 0 && wait2 = 0)
    V104CubeLog("PACKET2A_RESULT wait=" . wait2 . " exit=" . V92Hex(exit2)
        . " pkt=" . wrote2A . " code=" . wroteCode2A . " ok=" . ok)
    return ok
}

V44OpenGameContext()
{
    ctx := D2OpenHealContextV3()
    if (ctx.reason!="OK")
        return false
    if (!ctx.inv || !ctx.first)
    {
        DllCall("CloseHandle","Ptr",ctx.h)
        return false
    }
    ctx.d2base := D2GetModuleBaseV35(ctx.pid,"D2Client.dll")
    return ctx
}

V2CubeWatchTimer:
if (!ManualLogActiveV81())
{
    SetTimer, V2CubeWatchTimer, Off
    return
}
if (xRunning)
    return
if (!cubeCtrlLogArmed)
{
    SetTimer, V2CubeWatchTimer, Off
    return
}
if (A_TickCount > cubeCtrlLogExpire)
{
    cubeCtrlLogArmed := false
    SetTimer, V2CubeWatchTimer, Off
    log := A_ScriptDir . "\Auto-GSF-Debug.log"
    ManualLogAppendV81("V2_WATCH_TIMEOUT - khong thay HP/MP loc45 0->3`r`n", log, "UTF-8")
    ToolTipInfoV386("CUBE LOG V2: hết 15 giây - chưa thấy chuyển")
    SetTimer, RemoveToolTip, -2200
    return
}
V2CheckCubeMove()
return

V2CheckCubeMove()
{
    if (!ManualLogActiveV81())
        return
    global cubeCtrlLogArmed, cubeWatchBefore
    after := V1SnapshotHPManaLoc()
    for uid, b in cubeWatchBefore
    {
        if (b.loc != 0 || !after.HasKey(uid))
            continue
        a := after[uid]
        if (a.loc = 3)
        {
            cubeCtrlLogArmed := false
            SetTimer, V2CubeWatchTimer, Off
            log := A_ScriptDir . "\Auto-GSF-Debug.log"
            ManualLogAppendV81("`r`n================ V2 MOVE CONFIRMED ================`r`n", log, "UTF-8")
            ManualLogAppendV81("DETECTED tick=" . A_TickCount . "`r`n", log, "UTF-8")
            ManualLogAppendV81("CHANGE id=" . uid . " class=" . b.cls . " loc45 " . b.loc . "->" . a.loc . " xy " . b.x . "," . b.y . "->" . a.x . "," . a.y . " unit=" . V92Hex(b.unit) . " data=" . V92Hex(b.data) . "`r`n", log, "UTF-8")
            ManualLogAppendV81("BEFORE loc45=" . b.loc . " x=" . b.x . " y=" . b.y . "`r`n", log, "UTF-8")
            ManualLogAppendV81("AFTER  loc45=" . a.loc . " x=" . a.x . " y=" . a.y . "`r`n", log, "UTF-8")
            ManualLogAppendV81("BELT_COMPARE=0x19 lifts item; 0x23 places to Belt; BYTE27 offsets were captured above for comparison.`r`n", log, "UTF-8")
            ManualLogAppendV81("RESULT=RUONG_TO_CUBE_CONFIRMED`r`n", log, "UTF-8")
            ToolTipInfoV386("CUBE LOG V2 OK - đã bắt Rương -> Cube")
            SetTimer, RemoveToolTip, -2200
            return
        }
    }
}

V1SnapshotHPManaLoc()
{
    r := {}
    tmp := A_Temp . "\d2_v2_cube_pid.txt"
    FileDelete, %tmp%
    cmd := "tasklist /FI " . Chr(34) . "IMAGENAME eq Game.exe" . Chr(34) . " /FO CSV /NH > " . Chr(34) . tmp . Chr(34) . " 2>&1"
    RunWait, %ComSpec% /c %cmd%,, Hide
    FileRead, raw, %tmp%
    FileDelete, %tmp%

    h := 0, first := 0
    Loop, Parse, raw, `n, `r
    {
        if !RegExMatch(A_LoopField, "i)^""Game\.exe"",""([0-9]+)""", m)
            continue
        pid := m1 + 0
        base := D2GetModuleBaseV35(pid, "D2Client.dll")
        if (!base)
            continue
        h0 := D2OpenProcess(pid)
        if (!h0)
            continue
        p := D2ReadU32(h0, base + 0x11BBFC)
        inv := p ? D2ReadU32(h0, p + 0x60) : 0
        f := inv ? D2ReadU32(h0, inv + 0x10) : 0
        if (p && inv && f)
        {
            h := h0, first := f
            break
        }
        DllCall("CloseHandle", "Ptr", h0)
    }
    if (!h || !first)
        return r

    q := [first], seen := {}, qi := 1
    Loop, 8192
    {
        if (qi > q.Length())
            break
        u := q[qi], qi++
        if (!u || seen.HasKey(u))
            continue
        seen[u] := 1
        typ := D2ReadU32(h,u+0x00), cls := D2ReadU32(h,u+0x04)
        uid := D2ReadU32(h,u+0x0C), data := D2ReadU32(h,u+0x14)
        path := D2ReadU32(h,u+0x2C)
        Loop, 64
        {
            off := (A_Index-1)*4
            pu := D2ReadU32(h,u+off)
            if (!pu || seen.HasKey(pu))
                continue
            pt := D2ReadU32(h,pu+0x00), pc := D2ReadU32(h,pu+0x04)
            if (pt=4 && pc>=1 && pc<=10000)
                q.Push(pu)
        }
        if (typ=4 && data)
        {
            Loop, 64
            {
                off := (A_Index-1)*4
                pu := D2ReadU32(h,data+off)
                if (!pu || seen.HasKey(pu))
                    continue
                pt := D2ReadU32(h,pu+0x00), pc := D2ReadU32(h,pu+0x04)
                if (pt=4 && pc>=1 && pc<=10000)
                    q.Push(pu)
            }
        }
        if (typ=4 && (cls=1229 || cls=1234) && data && uid)
        {
            loc := D2ReadU8V18(h,data+0x45)
            x := path ? D2ReadU32(h,path+0x0C) : 0
            y := path ? D2ReadU32(h,path+0x10) : 0
            r[uid] := {cls:cls, loc:loc, x:x, y:y, unit:u, data:data}
        }
    }
    DllCall("CloseHandle","Ptr",h)
    return r
}

InvToCubeHandler:
if (!IsGameForegroundV63())
    return
if (sigBusyV147)
    return
if (packetWatchArmedV1)
    return
TransferHotkeyTrace("RUONG_TO_CUBE")
if (xRunning)
{
    DebugTraceWrite("cube", "TRANSFER_BLOCKED reason=BUFF_RUNNING")
    return
}
if (!IsGameActive() || v103CubeMoveRunning)
{
    DebugTraceWrite("cube", "TRANSFER_BLOCKED active=" . IsGameActive() . " busy=" . v103CubeMoveRunning)
    return
}
if (!GameItemActionBeginV4("Cube", "cube", true))
    return
v103CubeMoveRunning := true
try
{
    V105SendAllPotionsToCube()
}
finally
{
    v103CubeMoveRunning := false
    GameItemActionEndV4("Cube")
}
return

V105SendAllPotionsToCube()
{
    global cubePickupDelayMs, cubeTransferDelayMs
    moved := 0, hpMoved := 0, mpMoved := 0, reason := ""
    batch := V105ScanStashPotions()
    DebugTraceWrite("cube", "CUBE_SCAN reason=" . batch.reason
        . " pid=" . batch.pid . " potions=" . (IsObject(batch.potions) ? batch.potions.Length() : 0))
    if (batch.reason != "")
        reason := batch.reason
    else
    {
        for _, p in batch.potions
        {
            if (!IsGameActive() || D2GetActiveGamePidV95() != batch.pid)
            {
                reason := "GAME_NOT_ACTIVE"
                break
            }
            DebugTraceWrite("cube", "CUBE_ITEM_BEGIN uid=" . p.uid . " class=" . p.cls
                . " cube_uid=" . batch.cube.uid)
            result := V103SendOnePotionToCube(batch, p)
            DebugTraceWrite("cube", "CUBE_ITEM_RESULT uid=" . p.uid . " class=" . p.cls
                . " confirmed=" . result.moved . " reason=" . result.reason)
            if (!result.moved)
            {
                reason := result.reason
                break
            }
            moved++
            if (result.cls = 1229)
                hpMoved++
            else if (result.cls = 1234)
                mpMoved++
        }
    }
    if (reason = "")
        reason := "STASH_EMPTY"
    movedText := "HP " . hpMoved . ", MP " . mpMoved
    if (reason = "STASH_EMPTY")
        message := "ĐÃ CHUYỂN " . movedText . " - RƯƠNG HẾT BÌNH"
    else if (reason = "CUBE_FULL" || reason = "CUBE_FULL_OR_REJECTED")
        message := "ĐÃ CHUYỂN " . movedText . " - CUBE KHÔNG NHẬN THÊM"
    else
        message := "ĐÃ CHUYỂN " . movedText . " - DỪNG: " . reason
    DebugTraceWrite("cube", "CUBE_TRANSFER_RESULT " . message)
    ToolTipInfoV386(message)
    SetTimer, RemoveToolTip, -3000
    return moved
}

V105ScanStashPotions()
{
    pid := D2GetActiveGamePidV95()
    if (!pid)
        return {reason:"GAME_NOT_ACTIVE"}
    base := D2GetModuleBaseV35(pid, "D2Client.dll")
    h := D2OpenProcess(pid)
    if (!h || !base)
    {
        if (h)
            DllCall("CloseHandle", "Ptr", h)
        return {reason:"OPEN_GAME_FAILED"}
    }
    player := D2ReadU32(h, base + 0x11BBFC)
    inv := player ? D2ReadU32(h, player + 0x60) : 0
    first := inv ? D2ReadU32(h, inv + 0x10) : 0
    if (!first)
    {
        DllCall("CloseHandle", "Ptr", h)
        return {reason:"INVENTORY_UNAVAILABLE"}
    }
    snapshot := V9SnapshotAllItems({pid:pid,h:h,inv:inv,first:first})
    potions := [], cube := 0, hpSeen := 0, mpSeen := 0, cubeSeen := 0
    for itemUid, item in snapshot
    {
        if ((item.cls=1229 || item.cls=1234) && item.loc=0 && item.owner=inv)
        {
            if (D2ReadU32(h,item.unit)=4 && D2ReadU32(h,item.unit+0x0C)=itemUid
                && D2ReadU32(h,item.unit+0x04)=item.cls && D2ReadU32(h,item.unit+0x14)=item.data
                && D2ReadU8V18(h,item.data+0x45)=0 && D2ReadU32(h,item.data+0x5C)=inv)
            {
                potions.Push({uid:itemUid,unit:item.unit,data:item.data,cls:item.cls,loc:0,x:item.x,y:item.y})
                if (item.cls=1229)
                    hpSeen++
                else
                    mpSeen++
            }
        }
        if (item.cls=1204)
        {
            cubeSeen++
            if (!IsObject(cube) && item.loc=0 && item.owner=inv
                && D2ReadU8V18(h,item.data)=2 && D2ReadU32(h,item.unit)=4
                && D2ReadU32(h,item.unit+0x0C)=itemUid && D2ReadU32(h,item.unit+0x14)=item.data)
                cube := {uid:itemUid,unit:item.unit,data:item.data,cls:item.cls,loc:0,owner:item.owner}
        }
    }
    DllCall("CloseHandle", "Ptr", h)
    if (!potions.Length() || !IsObject(cube))
        return {reason:(!potions.Length() ? "STASH_EMPTY" : "CUBE_NOT_FOUND")}
    return {reason:"",pid:pid,base:base,inv:inv,cube:cube,potions:potions}
}

V103SendOnePotionToCube(batch, p)
{
    global cubeTransferDelayMs
    pid := batch.pid, base := batch.base, inv := batch.inv, c := batch.cube
    h := D2OpenProcess(pid)
    if (!h)
        return {moved:false,reason:"OPEN_GAME_FAILED"}
    ctx := {pid:pid,inv:inv}
    if (D2ReadU32(h,p.unit+0x0C) != p.uid || D2ReadU32(h,p.unit+0x04) != p.cls
        || D2ReadU32(h,p.unit+0x14) != p.data || D2ReadU8V18(h,p.data+0x45) != 0
        || D2ReadU32(h,p.data+0x5C) != inv
        || D2ReadU32(h,c.unit+0x0C) != c.uid || D2ReadU32(h,c.unit+0x04) != 1204
        || D2ReadU32(h,c.unit+0x14) != c.data || D2ReadU8V18(h,c.data+0x45) != 0
        || D2ReadU32(h,c.data+0x5C) != inv)
    {
        DllCall("CloseHandle", "Ptr", h)
        return {moved:false,reason:"ITEM_IDENTITY_CHANGED"}
    }
    DllCall("CloseHandle", "Ptr", h)
    if (!IsGameActive() || D2GetActiveGamePidV95() != pid)
    {
        return {moved:false,reason:"GAME_NOT_ACTIVE"}
    }
    sent := V104RemotePacket19_2A(ctx, p.uid, c.uid, p.unit, p.data, c.unit, c.data, inv, p.cls)
    if (!sent)
    {
        return {moved:false,reason:"SEND_FAILED"}
    }
    hCheck := D2OpenProcess(pid)
    confirmed := false, locAfter := -1, foundAfter := false
    if (hCheck)
    {
        Loop, 12
        {
            Sleep, %cubeTransferDelayMs%
            if (D2ReadU32(hCheck,p.unit) != 4 || D2ReadU32(hCheck,p.unit+0x0C) != p.uid
                || D2ReadU32(hCheck,p.unit+0x04) != p.cls
                || D2ReadU32(hCheck,p.unit+0x14) != p.data)
                break
            foundAfter := true
            locAfter := D2ReadU8V18(hCheck,p.data+0x45)
            if (locAfter = 3)
            {
                confirmed := true
                break
            }
        }
        DllCall("CloseHandle", "Ptr", hCheck)
    }
    if (!confirmed && IsGameActive() && D2GetActiveGamePidV95() = pid)
    {
        GameTargetClickV63("Left")
    }
    return {moved:confirmed,cls:p.cls,reason:(confirmed ? "MOVED" : "CUBE_FULL_OR_REJECTED")}
}


V6SendPacket2A(ctx, itemUid, cubeUid)
{
    if (RemoteThreadBusyV740(D2GetActiveGamePidV95()))
        return false
    if (itemUid=cubeUid)
    {
        V104CubeLog("PACKET2A_BLOCK reason=CUBE_SELF_INSERT uid=" . itemUid)
        return false
    }
    pid := ctx.pid
    netBase := D2GetModuleBaseV35(pid,"D2Net.dll")
    if (!netBase)
        return false
    sendFn := netBase + 0x7650
    hSend := DllCall("OpenProcess","UInt",0x043A,"Int",0,"UInt",pid,"Ptr")
    if (!hSend)
        return false
    remote := DllCall("VirtualAllocEx","Ptr",hSend,"Ptr",0,"UPtr",128,"UInt",0x3000,"UInt",0x40,"Ptr")
    if (!remote)
    {
        DllCall("CloseHandle","Ptr",hSend)
        return false
    }
    VarSetCapacity(pkt,9,0)
    NumPut(0x2A,pkt,0,"UChar")
    NumPut(itemUid,pkt,1,"UInt")
    NumPut(cubeUid,pkt,5,"UInt")
    wrotePkt := 0
    okPkt := DllCall("WriteProcessMemory","Ptr",hSend,"Ptr",remote+64,"Ptr",&pkt,"UPtr",9,"UPtrP",wrotePkt)
    VarSetCapacity(code,32,0)
    o:=0
    NumPut(0x68,code,o,"UChar"),o+=1
    NumPut(remote+64,code,o,"UInt"),o+=4
    NumPut(0x6A,code,o,"UChar"),o+=1
    NumPut(0x01,code,o,"UChar"),o+=1
    NumPut(0x6A,code,o,"UChar"),o+=1
    NumPut(0x09,code,o,"UChar"),o+=1
    NumPut(0xB8,code,o,"UChar"),o+=1
    NumPut(sendFn,code,o,"UInt"),o+=4
    NumPut(0xFF,code,o,"UChar"),o+=1
    NumPut(0xD0,code,o,"UChar"),o+=1
    NumPut(0xC3,code,o,"UChar"),o+=1
    wroteCode:=0
    okCode := DllCall("WriteProcessMemory","Ptr",hSend,"Ptr",remote,"Ptr",&code,"UPtr",o,"UPtrP",wroteCode)
    if (!okPkt || !okCode)
    {
        DllCall("VirtualFreeEx","Ptr",hSend,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hSend)
        return false
    }
    th := DllCall("CreateRemoteThread","Ptr",hSend,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
    if (!th)
    {
        DllCall("VirtualFreeEx","Ptr",hSend,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hSend)
        return false
    }
    wait := DllCall("WaitForSingleObject","Ptr",th,"UInt",1000)
    exitCode:=0
    DllCall("GetExitCodeThread","Ptr",th,"UIntP",exitCode)
    RemoteThreadFinishV740(hSend,th,remote,wait)
    return (wait=0)
}

V9SnapshotAllItems(ctx := 0)
{
    r := {}
    ownsHandle := !IsObject(ctx)
    if (ownsHandle)
        ctx := V44OpenGameContext()
    if (!IsObject(ctx))
        return r
    h:=ctx.h, first:=ctx.first, inv:=ctx.inv
    q := [first], seen := {}, qi := 1
    while (qi <= q.Length() && qi <= 8192)
    {
        u := q[qi], qi++
        if (!u || seen.HasKey(u))
            continue
        seen[u] := 1
        typ := D2ReadU32(h,u+0x00)
        cls := D2ReadU32(h,u+0x04)
        uid := D2ReadU32(h,u+0x0C)
        data := (typ=4) ? D2ReadU32(h,u+0x14) : 0
        if (typ=4 && data && uid)
        {
            loc := D2ReadU8V18(h,data+0x45)
            owner := D2ReadU32(h,data+0x5C)
            path := D2ReadU32(h,u+0x2C)
            x := path ? D2ReadU32(h,path+0x0C) : -1
            y := path ? D2ReadU32(h,path+0x10) : -1
            r[uid] := {cls:cls,loc:loc,owner:owner,x:x,y:y,unit:u,data:data,inv:inv}
        }
        e4 := D2ReadU32(h,u+0xE4), e8 := D2ReadU32(h,u+0xE8)
        if (e4 && !seen.HasKey(e4))
            q.Push(e4)
        if (e8 && !seen.HasKey(e8))
            q.Push(e8)
        if (typ=4 && data)
        {
            ptrOffsets := [0x60,0x64,0x6C,0x70,0x84,0xAC,0xB0,0xB4,0xC8,0xD8]
            for _,po in ptrOffsets
            {
                pu := D2ReadU32(h,data+po)
                if (pu && !seen.HasKey(pu) && D2ReadU32(h,pu)=4)
                    q.Push(pu)
            }
        }
    }
    if (ownsHandle)
        DllCall("CloseHandle","Ptr",h)
    return r
}


V9CubeIdentityTimer:
if (!ManualLogActiveV81())
{
    SetTimer, V9CubeIdentityTimer, Off
    return
}
if (xRunning)
    return
if (!v9CubeWatchArmed)
{
    SetTimer, V9CubeIdentityTimer, Off
    return
}
if (A_TickCount > v9CubeWatchExpire)
{
    v9CubeWatchArmed := false
    SetTimer, V9CubeIdentityTimer, Off
    log := A_ScriptDir . "\Auto-GSF-Cube.log"
    ManualLogAppendV81("V9_WATCH_TIMEOUT - khong thay item nao doi loc/xy/owner`r`n", log, "UTF-8")
    ToolTipInfoV386("V9: hết 15 giây - chưa bắt được Cube")
    SetTimer, RemoveToolTip, -2200
    return
}
V9CheckCubeIdentity()
return

V9CheckCubeIdentity()
{
    if (!ManualLogActiveV81())
        return
    global v9CubeWatchArmed, v9CubeBefore
    after := V9SnapshotAllItems()
    log := A_ScriptDir . "\Auto-GSF-Cube.log"
    for uid,b in v9CubeBefore
    {
        if (!after.HasKey(uid))
            continue
        a := after[uid]
        if (b.loc!=a.loc || b.x!=a.x || b.y!=a.y || b.owner!=a.owner)
        {
            v9CubeWatchArmed := false
            SetTimer, V9CubeIdentityTimer, Off
            ManualLogAppendV81("`r`n================ V9 ITEM CHANGE DETECTED ================`r`n", log, "UTF-8")
            ManualLogAppendV81("V9_CANDIDATE class=" . b.cls . " uid=" . uid . " loc45 " . b.loc . "->" . a.loc . " xy " . b.x . "," . b.y . "->" . a.x . "," . a.y . " owner " . V92Hex(b.owner) . "->" . V92Hex(a.owner) . " unit=" . V92Hex(b.unit) . " data=" . V92Hex(b.data) . "`r`n", log, "UTF-8")
            ManualLogAppendV81("V9_RESULT=CUBE_IDENTITY_CANDIDATE_CAPTURED | NO_SEND`r`n", log, "UTF-8")
            ToolTipInfoV386("V9 OK: đã bắt item thay đổi - gửi log")
            SetTimer, RemoveToolTip, -2500
            return true
        }
    }
    return false
}


V23StopCapture()
{
    global v23Armed, v23h
    v23Armed:=false
    SetTimer, V23CtrlLeftTimer, Off
    if (v23h)
        DllCall("CloseHandle","Ptr",v23h)
    v23h:=0
}

V23CtrlLeftTimer:
if (!ManualLogActiveV81())
{
    SetTimer, V23CtrlLeftTimer, Off
    return
}
if (xRunning)
    return
if (!v23Armed)
{
    SetTimer, V23CtrlLeftTimer, Off
    return
}
if (A_TickCount>v23Expire)
{
    log:=A_ScriptDir . "\\Auto-GSF-Debug.log"
    ManualLogAppendV81("V23_TIMEOUT | khong thay HP/MP loc45 0->3 | NO_SEND`r`n", log, "UTF-8")
    V23StopCapture()
    ToolTipInfoV386("V23: hết 15 giây - chưa bắt được")
    SetTimer, RemoveToolTip, -2200
    return
}
V23CheckCtrlLeft()
return

V23CheckCtrlLeft()
{
    if (!ManualLogActiveV81())
        return
    global v23Armed, v23Before, v23h, v23base, v23LastSel, v23SelChanges
    if (!v23Armed || !v23h)
        return false
    sel:=D2ReadU32(v23h,v23base+0x11B834)
    if (sel!=v23LastSel)
    {
        uid:=sel ? D2ReadU32(v23h,sel+0x0C) : 0
        cls:=sel ? D2ReadU32(v23h,sel+0x04) : 0
        v23SelChanges .= " sel=" . V92Hex(sel) . "/uid=" . uid . "/class=" . cls
        v23LastSel:=sel
    }
    after:=V1SnapshotHPManaLoc()
    for uid,b in v23Before
    {
        if (!after.HasKey(uid))
            continue
        a:=after[uid]
        if (b.loc=0 && a.loc=3)
        {
            s54:=D2ReadU32(v23h,v23base+0x11B854)
            s58:=D2ReadU32(v23h,v23base+0x11B858)
            s64:=D2ReadU32(v23h,v23base+0x11B864)
            log:=A_ScriptDir . "\\Auto-GSF-Debug.log"
            ManualLogAppendV81("V23_MOVE_CONFIRMED uid=" . uid . " class=" . b.cls . " loc45=0->3 xy=" . b.x . "," . b.y . "->" . a.x . "," . a.y . "`r`n", log, "UTF-8")
            ManualLogAppendV81("V23_SELECTED_CHANGES=" . v23SelChanges . "`r`n", log, "UTF-8")
            ManualLogAppendV81("V23_STATE_AT_CONFIRM selected=" . V92Hex(sel) . " s54=" . s54 . " s58=" . V92Hex(s58) . " s64=" . s64 . "`r`n", log, "UTF-8")
            ManualLogAppendV81("V23_RESULT=CTRL_LEFT_RUONG_TO_CUBE_CONFIRMED | NO_SEND`r`n", log, "UTF-8")
            V23StopCapture()
            ToolTipInfoV386("V23 OK: đã bắt Ctrl+LEFT - gửi log")
            SetTimer, RemoveToolTip, -2500
            return true
        }
    }
    return false
}

V102StopOneHPWatch()
{
    global v102OneHPArmed, v102OneHPHandle
    v102OneHPArmed := false
    SetTimer, V102OneHPWatchTimer, Off
    if (v102OneHPHandle)
        DllCall("CloseHandle", "Ptr", v102OneHPHandle)
    v102OneHPHandle := 0
}


V102OneHPWatchTimer:
if (!ManualLogActiveV81())
{
    SetTimer, V102OneHPWatchTimer, Off
    return
}
if (xRunning)
    return
if (!v102OneHPArmed)
{
    SetTimer, V102OneHPWatchTimer, Off
    return
}
if (A_TickCount >= v102OneHPExpire)
{
    log := A_ScriptDir . "\Auto-GSF-Cube.log"
    ManualLogAppendV81(A_Now . " | TIMEOUT: khong thay HP chuyen loc45=0->3.`r`n", log, "UTF-8")
    V102StopOneHPWatch()
    ToolTipInfoV386("HẾT 15 GIÂY - chưa thấy HP vào Cube")
    SetTimer, RemoveToolTip, -2500
    return
}
for uid, item in v102OneHPBefore
{
    if (D2ReadU32(v102OneHPHandle, item.unit + 0x0C) != uid)
        continue
    dataNow := D2ReadU32(v102OneHPHandle, item.unit + 0x14)
    if (!dataNow)
        continue
    locNow := D2ReadU8V18(v102OneHPHandle, dataNow + 0x45)
    if (locNow != 3)
        continue
    ownerNow := D2ReadU32(v102OneHPHandle, dataNow + 0x5C)
    pathNow := D2ReadU32(v102OneHPHandle, item.unit + 0x2C)
    xNow := pathNow ? D2ReadU32(v102OneHPHandle, pathNow + 0x0C) : 0
    yNow := pathNow ? D2ReadU32(v102OneHPHandle, pathNow + 0x10) : 0
    log := A_ScriptDir . "\Auto-GSF-Cube.log"
    ManualLogAppendV81(A_Now . " | CHUYEN_THANH_CONG uid=" . uid . " class=1229 loc45=" . item.loc . "->" . locNow . " owner=" . V92Hex(item.owner) . "->" . V92Hex(ownerNow) . " xy=" . item.x . "," . item.y . "->" . xNow . "," . yNow . " unit=" . V92Hex(item.unit) . " itemData=" . V92Hex(item.data) . "->" . V92Hex(dataNow) . "`r`n", log, "UTF-8")
    V102StopOneHPWatch()
    ToolTipInfoV386("ĐÃ BẮT 1 HP RƯƠNG -> CUBE - xem file log")
    SetTimer, RemoveToolTip, -2500
    return
}
return

ManualLogActiveV81()
{
    global manualLogOnV81, manualLogClosingV81
    return manualLogOnV81 || manualLogClosingV81
}

ManualLogAppendV81(message, originalPath, encoding := "UTF-8")
{
    global manualLogFolderV81, manualLogStartV81, manualLogSessionV95, manualLogFilesV98
    global manualLogWriteFailedV749
    if (!ManualLogActiveV81() || manualLogFolderV81="" || originalPath="")
        return false
    if (manualLogWriteFailedV749)
        return false
    SplitPath, originalPath, channelFile
    if (!manualLogFilesV98.HasKey(channelFile) || !manualLogFilesV98[channelFile])
        return false
    part := Floor((A_TickCount-manualLogStartV81)/10000)+1
    partPath := manualLogFolderV81 . "\" . manualLogSessionV95 . "-" . Format("{:04}",part) . "-" . channelFile
    try
        FileAppend, %message%, %partPath%, UTF-8
    catch errorV749
    {
        ManualLogWriteFailedV749(partPath,errorV749.Message)
        return false
    }
    wroteV749 := !ErrorLevel
    if (!wroteV749)
    {
        ManualLogWriteFailedV749(partPath,"FileAppend returned ErrorLevel")
        return false
    }
    if (wroteV749)
    {
        try
            ManualLogVNAppendV749(message,channelFile)
        catch errorV749
            ManualLogVNFailedV749()
    }
    return wroteV749
}

ManualLogWriteFailedV749(path,reason)
{
    global manualLogWriteFailedV749
    if (manualLogWriteFailedV749)
        return
    manualLogWriteFailedV749 := true
    OutputDebug, % "Auto-GSF log write failed: " . path . " | " . reason
    ToolTipInfoV386("LỖI GHI LOG; đã ngừng ghi log, tool vẫn hoạt động.")
    SetTimer, RemoveToolTip, -4000
}

MapFullExportTimerV134:
MapFullExportV134()
return

MapFullExportV134()
{
    global manualLogOnV81,manualLogFolderV81,manualLogSessionV95,manualLogFilesV98,mapFullCapturedV134
    static busy := false
    if (busy || !manualLogOnV81 || !manualLogFilesV98["Auto-GSF-Map-Full.log"])
        return
    busy := true,h := 0,session := manualLogSessionV95
    try
    {
        pid := CoordDisplayGamePidV1(),base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
        h := base ? DllCall("OpenProcess","UInt",0x0410,"Int",0,"UInt",pid,"Ptr") : 0
        if (!h)
            return
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return
        room1 := NumGet(pb,0x1C,"UInt"),current := room1 ? D2ReadU32(h,room1+0x10) : 0
        if (!MonsterBossProbeReadV1(h,current,0x60,rb))
            return
        lp := NumGet(rb,0x58,"UInt"),level := lp ? D2ReadU32(h,lp+0x1D0) : 0
        if (!level || !MonsterBossProbeReadV1(h,lp,0x20,lb))
            return
        captureKey := pid . "|" . lp . "|" . level
        if (mapFullCapturedV134=captureKey)
            return
        first := NumGet(lb,0x10,"UInt"),nodes := {},queue := [current],chainSeen := {},chainStatus := "NO_VALID_HEAD",failed := 0
        chain := first
        if (chain>=0x10000)
        {
            chainStatus := "END_NULL"
            while (chain)
            {
                if (!manualLogOnV81 || manualLogSessionV95!=session)
                    return
                if (chainSeen.HasKey(chain) || chainSeen.Count()>=4096)
                {
                    chainStatus := "CYCLE_OR_LIMIT"
                    break
                }
                if (!MonsterBossProbeReadV1(h,chain,0x60,cb) || NumGet(cb,0x58,"UInt")!=lp)
                {
                    chainStatus := "READ_FAILED_OR_OTHER_LEVEL"
                    break
                }
                chainSeen[chain] := true,queue.Push(chain)
                chain := NumGet(cb,0x24,"UInt")
                if (Mod(chainSeen.Count(),32)=0)
                    Sleep, -1
            }
        }
        queued := {},qi := 1,limited := false
        while (qi<=queue.Length())
        {
            if (!manualLogOnV81 || manualLogSessionV95!=session)
                return
            address := queue[qi++]
            if (queued.HasKey(address))
                continue
            if (queued.Count()>=4096)
            {
                limited := true
                break
            }
            queued[address] := true
            node := RoomExploreReadV89(h,address,level)
            if (!IsObject(node) || D2ReadU32(h,address+0x58)!=lp)
            {
                failed++
                continue
            }
            nodes[address] := node
            for _,neighbor in node.links
                if (!queued.HasKey(neighbor))
                    queue.Push(neighbor)
            if (Mod(queued.Count(),32)=0)
                Sleep, -1
        }
        file := RoomProfileFileV108(),section := "Rooms-" . level,saved := {},savedCount := 0,maxSaved := -1
        IniRead, savedRaw, %file%, %section%
        Loop, Parse, savedRaw, `n, `r
        {
            if (RegExMatch(A_LoopField,"^(\d+_\d+_\d+_\d+)=(\d+)$",m))
                saved[m1] := m2+0,savedCount++,maxSaved := Max(maxSaved,m2+0)
        }
        IniRead, nextSaved, %file%, %section%, NextNumber, MISSING
        chainComplete := chainStatus="END_NULL" && chainSeen.HasKey(current) && !failed && !limited
        log := "FULL_MAP_BEGIN time=" . A_Now . " pid=" . pid . " map=" . level . " player=" . NumGet(pb,2,"UShort") . "," . NumGet(pb,6,"UShort")
            . " current_room2=" . V92Hex(current) . " level_pointer=" . V92Hex(lp) . " head=" . V92Hex(first)
            . " source=GAME_MEMORY read_only=1 file=" . file . "`r`n"
        log .= "FULL_MAP_METHOD level_head_offset=0x10 room2_next_offset=0x24 level_owner_offset=0x58"
            . " chain_status=" . chainStatus . " chain_rooms=" . chainSeen.Count() . " current_in_chain=" . chainSeen.HasKey(current)
            . " chain_complete=" . chainComplete . " failed_reads=" . failed . " limit_reached=" . limited
            . " links_kind=GEOGRAPHIC_NEIGHBORS_NOT_CONFIRMED_WALKABLE level_header_raw=" . MonsterBossProbeHexV1(lb,0x20) . "`r`n"
        geometry := {},foundSaved := {},loaded := 0,index := 0,missing := 0
        for address,node in nodes
        {
            key := node.x . "_" . node.y . "_" . node.w . "_" . node.h
            geometry[key] := true
            number := saved.HasKey(key) ? saved[key] : "UNSAVED"
            if (saved.HasKey(key))
                foundSaved[key] := true
            else
                missing++
            links := ""
            for _,neighbor in node.links
            {
                other := nodes[neighbor]
                otherKey := IsObject(other) ? other.x . "_" . other.y . "_" . other.w . "_" . other.h : ""
                otherNumber := otherKey!="" && saved.HasKey(otherKey) ? saved[otherKey] : "UNSAVED"
                links .= (links="" ? "" : ",") . V92Hex(neighbor) . ":" . otherNumber
            }
            loaded += node.r1 ? 1 : 0,index++
            log .= "ROOM index=" . index . " saved_number=" . number . " current=" . (address=current)
                . " room2=" . V92Hex(address) . " room1=" . V92Hex(node.r1) . " loaded=" . (node.r1!=0)
                . " rect=" . node.x . "," . node.y . "," . node.w . "," . node.h . " center=" . node.cx . "," . node.cy
                . " neighbors=" . links . " raw=" . node.raw . "`r`n"
        }
        absent := 0
        for key,number in saved
            if (!foundSaved.HasKey(key))
            {
                absent++
                log .= "SAVED_NOT_FOUND_IN_MEMORY saved_number=" . number . " rect=" . key . "`r`n"
            }
        log .= "FULL_MAP_END memory_room_addresses=" . nodes.Count() . " unique_room_rectangles=" . geometry.Count()
            . " loaded_room1=" . loaded . " saved_room_count=" . savedCount . " highest_saved_number=" . maxSaved
            . " next_saved_number=" . nextSaved . " memory_rooms_without_saved_number=" . missing . " saved_rooms_absent=" . absent
            . " complete_level_list=" . chainComplete . " numbering=FILE_ASSIGNED_NOT_GAME_ROOM_COUNT`r`n`r`n"
        if (!manualLogOnV81 || manualLogSessionV95!=session)
            return
        output := manualLogFolderV81 . "\" . session . "-Auto-GSF-Map-Full.log"
        FileAppend, %log%, %output%, UTF-8
        if (!ErrorLevel)
        {
            mapFullCapturedV134 := captureKey
            ToolTipInfoV386("Đã xuất map " . level . ": " . nodes.Count() . " phòng. Xem Auto-GSF-Map-Full.log trong Logs.")
            SetTimer, RemoveToolTip, -3000
        }
        else
        {
            ToolTipInfoV386("Không ghi được Auto-GSF-Map-Full.log trong thư mục Logs.")
            SetTimer, RemoveToolTip, -3000
        }
    }
    finally
    {
        if (h)
            DllCall("CloseHandle","Ptr",h)
        busy := false
    }
}

ManualLogStopV81:
showLogV749 := manualLogOnV81 && A_ExitReason=""
SetTimer, MapInputWatchV176, Off
SetTimer, StageTwoTestArmTimerV167, Off
stageTwoTestWaitV167 := 0
if (!IsObject(stageTwoV166) || (!stageTwoV166.continuous && !stageTwoV166.restartRunV17))
    StageTwoStopV166("LOG_STOP_BUTTON")
SetTimer, WpCaptureTimerV161, Off
PacketWatchStopV1()
wpCaptureV161 := false
SigCubeCaptureStopV151()
if (!IsObject(sigTownV148) || !sigTownV148.auto)
    SigTownCancelV148("LOG_STOP_BUTTON")
SetTimer, MapFullExportTimerV134, Off
SetTimer, EntryMouseLogTimerV160, Off
SetTimer, StageTwoKeyLogTimerV164, Off
if (IsObject(roomExploreV89) && !roomExploreV89.manualReplay)
    RoomExploreStopV89("LOG_STOP")
manualLogClosingV81 := true
FarmInfoLogStopV4()
ManualLogAppendV81(A_Now . " | SESSION_END reason=USER_STOP`r`n",A_ScriptDir . "\Auto-GSF-Cong-Len-Map.log")
V102StopOneHPWatch()
PacketWatchStopV1()
for _,stopLogTimerV81 in ["PortalLogTimerV66","NativeExportTimerV12","CharacterDLLProbeTimerV3","MonsterBossProbeTimerV1","StopPickupCubeTrace","V104CubeGroundTimer","V2CubeWatchTimer","V9CubeIdentityTimer","V23CtrlLeftTimer","V102OneHPWatchTimer"]
    SetTimer, %stopLogTimerV81%, Off
portalLogUntilV66 := 0
pickupCubeTraceUntil := 0
pickupCubeTracePacket := false
autoMonsterExportV2 := false
cubeCtrlLogArmed := false
v104CubeExpire := 0
manualLogOnV81 := false
manualLogClosingV81 := false
GuiControl,, ExportLogButtonV81, XUẤT LOG
try
    ManualLogVNStopV749(showLogV749)
catch errorV749
    ToolTipInfoV386("Đã dừng log. Không mở được bảng diễn giải; log gốc vẫn còn.")
return

ManualLogClearOldV157(folder)
{
    global manualLogFilesV98
    failed := 0
    Loop, Files, % folder . "\*", F
    {
        if (!RegExMatch(A_LoopFileName,"i)\.(txt|log)$") && !RegExMatch(A_LoopFileName,"i)-Stage2-.*\.bmp$"))
            continue
        FileDelete, %A_LoopFileFullPath%
        if (ErrorLevel)
            failed++
    }
    for name,_ in manualLogFilesV98
    {
        oldPath := A_ScriptDir . "\" . name
        if (!FileExist(oldPath))
            continue
        FileDelete, %oldPath%
        if (ErrorLevel)
            failed++
    }
    return failed=0
}
RouteRecordToggleV358:
RouteRecorderShowV657()
return

RouteRecorderShowV657()
{
    global routeRecorderHwndV657,routeRecordV358
    global RouteRecorderNameV657,RouteRecorderStatusV657,RouteRecorderFileV657,RouteRecorderPointsV657,RouteRecorderIdentityTextV658
    if (!routeRecorderHwndV657 || !DllCall("IsWindow","Ptr",routeRecorderHwndV657))
    {
        Gui, RouteRecorderV657:New, +AlwaysOnTop +HwndrouteRecorderHwndV657, Ghi Tọa Độ GD1
        Gui, RouteRecorderV657:Font, s9, Segoe UI
        Gui, RouteRecorderV657:Add, Text, x12 y15 w70 h22, Tên tuyến:
        Gui, RouteRecorderV657:Add, Edit, x84 y10 w300 h26 vRouteRecorderNameV657, GD1
        Gui, RouteRecorderV657:Add, Button, x396 y9 w112 h28 gRouteRecorderStartV657, Bắt đầu ghi
        Gui, RouteRecorderV657:Add, Button, x518 y9 w112 h28 gRouteRecorderStopV657, Dừng và lưu
        Gui, RouteRecorderV657:Add, Button, x518 y46 w112 h28 gGD1IdentifyButtonV643, Nhận Diện
        Gui, RouteRecorderV657:Add, Text, x12 y48 w494 h34 vRouteRecorderStatusV657, Chưa ghi. Nhập tên tuyến rồi bấm Bắt đầu ghi.
        Gui, RouteRecorderV657:Add, Edit, x12 y88 w618 h42 ReadOnly vRouteRecorderFileV657, File sẽ lưu trong LoTrinh\GD1 khi bấm Dừng và lưu.
        Gui, RouteRecorderV657:Add, ListView, x12 y140 w618 h292 Grid vRouteRecorderPointsV657, STT|Map|Nhân vật X`,Y|Điểm click X`,Y|Đối tượng / NPC
        LV_ModifyCol(1,42), LV_ModifyCol(2,48), LV_ModifyCol(3,100), LV_ModifyCol(4,100), LV_ModifyCol(5,300)
        Gui, RouteRecorderV657:Add, Edit, x12 y442 w618 h70 Multi ReadOnly vRouteRecorderIdentityTextV658, Nhận diện NPC / kho / cổng: bấm Nhận Diện rồi đưa chuột lên đối tượng trong game.
        Gui, RouteRecorderV657:Add, Text, x12 y522 w618 h34, Chỉ ghi click trái trong cửa sổ game đã chọn. Mỗi dòng hiện ngay sau khi ghi thành công.
        Gui, 1:Default
    }
    Gui, RouteRecorderV657:Show, w642 h564
    Gui, 1:Default
}

RouteRecorderBeginV657(r)
{
    global routeRecorderHwndV657
    if (!routeRecorderHwndV657)
        return
    Gui, RouteRecorderV657:Default
    Gui, ListView, RouteRecorderPointsV657
    LV_Delete()
    GuiControl,, RouteRecorderFileV657, Đang ghi; chưa xuất file.
    Gui, 1:Default
    Gui, RouteRecorderV657:Show, NA
}

RouteRecorderAppendV657(index,c)
{
    global routeRecorderHwndV657
    if (!routeRecorderHwndV657)
        return
    Gui, RouteRecorderV657:Default
    Gui, ListView, RouteRecorderPointsV657
    LV_Add("",index,c.level,c.px . "," . c.py,c.mx . "," . c.my,c.targetDesc)
    LV_Modify(index,"Vis")
    Gui, 1:Default
    RouteRecorderStatusV657("ĐANG GHI: " . index . " điểm. Map " . c.level . " | Nhân vật: " . c.px . "," . c.py . " | Click: " . c.mx . "," . c.my)
}

RouteRecorderStatusV657(message)
{
    global routeRecorderHwndV657
    if (routeRecorderHwndV657)
        GuiControl, RouteRecorderV657:, RouteRecorderStatusV657, %message%
}

RouteRecorderIdentityV658(message)
{
    global routeRecorderHwndV657
    if (routeRecorderHwndV657 && DllCall("IsWindow","Ptr",routeRecorderHwndV657))
    {
        GuiControl, RouteRecorderV657:, RouteRecorderIdentityTextV658, %message%
        return true
    }
    return false
}

RouteRecorderSavedV657(file)
{
    global routeRecorderHwndV657
    if (routeRecorderHwndV657)
        GuiControl, RouteRecorderV657:, RouteRecorderFileV657, %file%
    RouteRecorderStatusV657("Đã dừng và lưu xong. Danh sách điểm được giữ để xem lại.")
}

RouteRecorderStartV657:
if (IsObject(routeRecordV358))
{
    RouteRecorderStatusV657("Đang có phiên ghi. Dừng và lưu trước khi ghi tuyến mới.")
    return
}
RouteRecordStartV358()
return

RouteRecorderStopV657:
if (IsObject(routeRecordV358) && !routeRecordV358.planV375)
    RouteRecordStopV358("RECORDER_FORM_STOP")
return

RouteRecorderV657GuiClose:
RouteRecorderV657GuiEscape:
if (IsObject(routeRecordV358) && !routeRecordV358.planV375)
{
    if (!RouteRecordStopV358("RECORDER_FORM_CLOSE"))
        return
}
Gui, RouteRecorderV657:Hide
return

RouteRecordStartV358()
{
    global routeRecordV358, backgroundPidV63, backgroundHwndV63, roomRecordV108
    if (IsObject(roomRecordV108))
    {
        ToolTipInfoV386("Đang Tạo/Sửa Map — dừng lại trước khi Ghi Map.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    GuiControlGet, gd1NameV643, RouteRecorderV657:, RouteRecorderNameV657
    if (Trim(gd1NameV643)="")
    {
        RouteRecorderStatusV657("Nhập tên tuyến trước khi bắt đầu ghi.")
        return false
    }
    gd1NameV643 := RegExReplace(Trim(gd1NameV643),"[\\/:*?""<>|]","_")
    if (!SigBackgroundBindV179() || !PickupActivateGameV13())
    {
        RouteRecorderStatusV657("Không tìm thấy cửa sổ game; chọn game rồi bấm Bắt đầu ghi lại.")
        ToolTipInfoV386("Không tìm thấy cửa sổ game để ghi lộ trình.")
        SetTimer, RemoveToolTip, -3000
        return false
    }
    routeRecordV358 := {pid:backgroundPidV63, hwnd:backgroundHwndV63
        , startAt:A_TickCount, clicks:[],gd1NameV643:gd1NameV643}
    RouteRecorderBeginV657(routeRecordV358)
    GuiControl, 1:, RouteRecordButtonV358, Đang ghi (0)
    Hotkey, ~*LButton, RouteRecordMouseDownV358, On
    RouteRecorderStatusV657("ĐANG GHI: click chuột trái trong game. Bấm Dừng và lưu trên form khi xong.")
    SetTimer, RemoveToolTip, -6000
    return true
}

RouteRecordStopV358(reason)
{
    global routeRecordV358
    r := routeRecordV358
    if (!IsObject(r))
        return false
    Hotkey, ~*LButton, RouteRecordMouseDownV358, Off
    routeRecordV358 := false
    if (r.planV375)
    {
        RoutePlanRecordingUiV375(false)
        GuiControl, 1:, RouteRecordButtonV358, Ghi Tọa Độ
        return true
    }
    GuiControl, 1:, RouteRecordButtonV358, Ghi Tọa Độ
    logDir := A_ScriptDir . (r.gd1NameV643!="" ? "\LoTrinh\GD1" : "\Logs")
    FileCreateDir, %logDir%
    outFile := logDir . "\" . (r.gd1NameV643!="" ? r.gd1NameV643 . "-" : "Route-Record-") . A_Now . "-" . A_TickCount . ".txt"
    content := "=== GHI LO TRINH " . A_Now . " ===`r`n"
    content .= "pid=" . r.pid . " hwnd=" . r.hwnd . " clicks=" . r.clicks.Length() . " reason=" . reason . "`r`n"
    content .= "Cot: CLICK#N | t_ms | client=cx,cy | screen=sx,sy | level | player=px,py | map=mx,my`r`n"
    content .= "player = toa do nhan vat trong map khi click`r`n"
    content .= "map    = toa do map ma con tro dang chi (quy doi tu client + camera)`r`n`r`n"
    for i, c in r.clicks
    {
        content .= "CLICK#" . i
            . " | t=" . (c.at - r.startAt)
            . " | client=" . c.cx . "," . c.cy
            . " | screen=" . c.sx . "," . c.sy
            . " | level=" . c.level
            . " | player=" . c.px . "," . c.py
            . " | map=" . c.mx . "," . c.my
            . "`r`n"
        if (c.targetDesc != "")
            content .= "  TARGET " . c.targetDesc . "`r`n"
    }
    content .= "`r`n; GD1: đúng tọa độ click theo thứ tự, không phụ thuộc file Map.`r`n"
    content .= "GD1Route := []`r`n"
    for i,c in r.clicks
        content .= "GD1Route.Push({level:" . c.level . ",x:" . c.mx . ",y:" . c.my . "})"
            . (c.targetDesc!="" ? " `; " . c.targetDesc : "") . "`r`n"
    content .= "`r`n=== END ===`r`n"
    f := FileOpen(outFile, "w", "UTF-8")
    if (IsObject(f))
    {
        writtenV657 := f.Write(content)
        f.Close()
        if (!writtenV657)
        {
            routeRecordV358 := r
            RouteRecorderStatusV657("Lỗi ghi file. Bấm Dừng và lưu để thử lại; dữ liệu vẫn được giữ.")
            return false
        }
        RouteRecorderSavedV657(outFile)
        ToolTipInfoV386("Đã ghi lộ trình: " . outFile)
    }
    else
    {
        routeRecordV358 := r
        RouteRecorderStatusV657("Không ghi được file. Kiểm tra quyền ghi rồi bấm Dừng và lưu lại.")
        ToolTipInfoV386("Không ghi được file lộ trình.")
        return false
    }
    SetTimer, RemoveToolTip, -5000
    return true
}

RouteRecordMouseDownV358:
if (!IsObject(routeRecordV358))
    return
if (!IsGameForegroundV63() || D2GetActiveGamePidV95() != routeRecordV358.pid)
    return
RouteRecordCaptureV358(routeRecordV358)
return

RouteRecordCaptureV358(r)
{
    if (!IsObject(r))
        return
    VarSetCapacity(pt, 8, 0)
    if (!DllCall("GetCursorPos", "Ptr", &pt))
        return
    sx := NumGet(pt, 0, "Int"), sy := NumGet(pt, 4, "Int")
    hwnd := r.hwnd
    if (!DllCall("IsWindow", "Ptr", hwnd))
        return
    NumPut(sx, pt, 0, "Int"), NumPut(sy, pt, 4, "Int")
    if (!DllCall("ScreenToClient", "Ptr", hwnd, "Ptr", &pt))
        return
    cx := NumGet(pt, 0, "Int"), cy := NumGet(pt, 4, "Int")
    px := 0, py := 0, level := 0, mx := 0, my := 0, targetDesc := ""
    base := D2GetModuleBaseV35(r.pid, "D2Client.dll")
    h := base ? D2OpenProcess(r.pid) : 0
    if (h)
    {
        try
        {
            player := D2ReadU32(h, base + 0x11BBFC)
            path := player ? D2ReadU32(h, player + 0x2C) : 0
            if (player && MonsterBossProbeReadV1(h, path, 0x20, pb))
            {
                px := NumGet(pb, 2, "UShort"), py := NumGet(pb, 6, "UShort")
                level := CoordLevelV14(h, NumGet(pb, 0x1C, "UInt"))
                view := AutoMonsterAttackViewV1(h, base, hwnd, path)
                if (IsObject(view) && view.cw > 0 && view.ch > 0)
                {
                    gx := cx * view.gw / view.cw
                    gy := cy * view.gh / view.ch
                    pSX := NumGet(pb, 8, "Int") - view.ox
                    pSY := NumGet(pb, 12, "Int") - view.oy
                    a := (gx - pSX) / 16.0
                    b := (gy - pSY) / 8.0
                    mx := Round(px + (a + b) / 2.0)
                    my := Round(py + (b - a) / 2.0)
                }
                unit := D2ReadU32(h, base + 0x11B834)
                if (unit && MonsterBossProbeReadV1(h, unit, 0x18, ub))
                {
                    kind := NumGet(ub, 0, "UInt")
                    cls  := NumGet(ub, 4, "UInt")
                    uid  := NumGet(ub, 12, "UInt")
                    if (kind = 1)
                        targetDesc := "NPC/MONSTER type=1 class=" . cls . " uid=" . uid
                    else if (kind = 2)
                        targetDesc := "OBJECT class=" . cls . " uid=" . uid
                    else if (kind = 4)
                    {
                        itemData := NumGet(ub, 0x14, "UInt")
                        q := itemData ? D2ReadU8V18(h, itemData) : 0
                        targetDesc := "ITEM class=" . cls . " itemdata=" . Format("{:02X}", q) . " uid=" . uid
                    }
                    else if (kind != 0)
                        targetDesc := "UNIT type=" . kind . " class=" . cls . " uid=" . uid
                    targetPathV643 := D2ReadU32(h,unit+0x2C)
                    if (targetDesc!="" && MonsterBossProbeReadV1(h,targetPathV643,0x18,targetPbV643))
                    {
                        txV643 := kind=1 ? NumGet(targetPbV643,2,"UShort") : NumGet(targetPbV643,0x0C,"UInt")
                        tyV643 := kind=1 ? NumGet(targetPbV643,6,"UShort") : NumGet(targetPbV643,0x10,"UInt")
                        targetDesc .= " x=" . txV643 . " y=" . tyV643
                    }
                }
            }
        }
        finally
            DllCall("CloseHandle", "Ptr", h)
    }
    if (!level || !IsObject(view) || mx<=0 || my<=0)
    {
        if (!r.planV375)
            RouteRecorderStatusV657("Chưa đọc được tọa độ click; chưa thêm điểm. Kiểm tra nhân vật trong game.")
        return
    }
    if (r.planV375)
    {
        line := "MOVE level=" . level . " x=" . mx . " y=" . my
        if (targetDesc!="")
            line .= " `; " . targetDesc
        if (!RoutePlanAppendV375(line))
        {
            RouteRecordStopV358("WRITE_FAILED")
            return
        }
    }
    r.clicks.Push({at:A_TickCount, sx:sx, sy:sy, cx:cx, cy:cy
        , px:px, py:py, level:level, mx:mx, my:my, targetDesc:targetDesc})
    GuiControl, 1:, RouteRecordButtonV358, % "Đang ghi (" . r.clicks.Length() . ")"
    if (!r.planV375)
        RouteRecorderAppendV657(r.clicks.Length(),r.clicks[r.clicks.Length()])
}
ExportHPManaLog:
if (manualLogOnV81)
{
    Gosub, ManualLogStopV81
    ToolTipInfoV386("ĐÃ DỪNG LOG — FARM VẪN CHẠY.")
    SetTimer, RemoveToolTip, -2500
    return
}
manualLogFolderV81 := A_ScriptDir . "\Logs"
manualLogSessionV95 := A_Now . "-" . A_TickCount
manualLogWriteFailedV749 := false
FileCreateDir, %manualLogFolderV81%
if (ErrorLevel)
{
    ToolTipInfoV386("KHÔNG TẠO ĐƯỢC THƯ MỤC LOG.")
    SetTimer, RemoveToolTip, -2500
    return
}
if (!ManualLogClearOldV157(manualLogFolderV81))
{
    ToolTipInfoV386("KHÔNG XÓA ĐƯỢC LOG CŨ — ĐÓNG FILE LOG ĐANG MỞ RỒI THỬ LẠI.")
    SetTimer, RemoveToolTip, -3000
    return
}
manualLogStartV81 := A_TickCount
manualLogOnV81 := true
ManualLogVNStartV749()
FarmInfoLogStartV4()
mapFullCapturedV134 := ""
SetTimer, MapFullExportTimerV134, 1000
GuiControl,, ExportLogButtonV81, DỪNG LOG
PortalLogStartV66()
mapInputLastV176 := ""
SetTimer, MapInputWatchV176, 50
MapKeyTraceV174("INPUT_WATCH","START before_manual_L")
entryMouseStateV160 := {LButton:GetKeyState("LButton","P"),RButton:GetKeyState("RButton","P"),MButton:GetKeyState("MButton","P")}
SetTimer, EntryMouseLogTimerV160, 50
stageTwoKeysV164 := {Esc:GetKeyState("Esc","P"),Enter:GetKeyState("Enter","P"),Tab:GetKeyState("Tab","P")}
SetTimer, StageTwoKeyLogTimerV164, 50
PacketWatchStopV1()
autoMonsterExportV2 := autoMonsterAttackOn
SetTimer, CharacterDLLProbeTimerV3, Off
characterDLLProbeV3 := {moduleIndex:1,lastSnapshot:"",busy:false}
SetTimer, MonsterBossProbeTimerV1, Off
monsterProbeSeenV1 := {}
monsterProbeBusyV1 := false
pickupCubeTraceUntil := 0
pickupCubeTracePacket := false
SetTimer, StopPickupCubeTrace, Off
wpCaptureV161 := false
traceCreateFailed := false
for traceNameV98, traceEnabledV98 in manualLogFilesV98
{
    if (!traceEnabledV98 || traceNameV98="Auto-GSF-Map-Full.log" || traceNameV98="Auto-GSF-Tinh-Trang.txt")
        continue
    traceFile := A_ScriptDir . "\" . traceNameV98
    traceWrittenV98 := ManualLogAppendV81(A_Now . " tick=" . A_TickCount . " | TRACE_START channel=" . traceNameV98
        . " duration=UNTIL_STOP segment_ms=10000 profile=" . currentProfile . "`r`n", traceFile, "UTF-8")
    if (!traceWrittenV98)
        traceCreateFailed := true
}

if (traceCreateFailed)
{
    Gosub, ManualLogStopV81
    ToolTipInfoV386("KHÔNG TẠO ĐƯỢC FILE LOG TXT TRONG THƯ MỤC TOOL")
    SetTimer, RemoveToolTip, -3000
    return
}
stageTwoTestWaitV167 := 0
SetTimer, StageTwoTestArmTimerV167, Off
pickupCubeTraceUntil := A_TickCount + 2147480000
SetTimer, NativeExportTimerV12, 250
SetTimer, CharacterDLLProbeTimerV3, 500
DebugTraceWrite("character", "TEST town_to_field_buff_return duration=UNTIL_STOP segment_ms=10000 poll_ms=500 state_interpretation=PROBE")
DebugTraceWrite("pickup", "CONFIG pickup_on=" . pickupImageOn . " radius=" . pickupRadius
    . " rules=" . pickupAllowCount . " get_key=" . getIdKey)
DebugTraceWrite("belt", "CONFIG key_16HP=" . belt4HPKey . " key_8HP8MP=" . belt2HP2ManaKey
    . " pickup_delay_ms=" . cubePickupDelayMs . " transfer_delay_ms=" . cubeTransferDelayMs)
DebugTraceWrite("cube", "CONFIG key=" . invToCubeKey . " pickup_delay_ms=" . cubePickupDelayMs
    . " transfer_delay_ms=" . cubeTransferDelayMs)
SigGroundDiagnosticV63()
HealTrace("CONFIG priority=Belt>Ruong>Cube HP_belt=" . autoPotOn . " mana_belt=" . manaOn
    . " HP_ruong=" . invHealOn . " MP_ruong=" . invManaOn
    . " HP_cube=" . cubeHealOn . " MP_cube=" . cubeManaOn
    . " hp_threshold=" . potHPThreshold . " mana_threshold=" . manaThreshold
    . " hp_cooldown_ms=" . potCooldown . " mana_cooldown_ms=" . manaCooldown)
DebugTraceWrite("monster", "READ_ONLY_SCAN duration=UNTIL_STOP segment_ms=10000 poll_ms=500 classification=UNCONFIRMED auto_attack=" . autoMonsterAttackOn)
SetTimer, MonsterBossProbeTimerV1, 500
if (autoMonsterExportV2)
{
    log := TxtRootPathV816("Auto-GSF-Tu-Danh.txt")
    AutoMonsterAttackLogV2("TRACE_START duration=UNTIL_STOP segment_ms=10000 auto_attack=ON checkbox_preserved=1")
    DebugTraceWrite("packet", "AUTO_DIAGNOSTIC auto_attack=ON checkbox_preserved=1 capture=TOOL_CLIENT_CALL_STATUS actual_packet_capture=0 tool_actions=RUNNING duration=UNTIL_STOP segment_ms=10000")
    ToolTipInfoV386("ĐANG GHI LOG 10 GIÂY/ĐOẠN — BẤM XUẤT LOG ĐỂ DỪNG")
}
else
{
    DebugTraceWrite("packet", "CHARACTER_TEST capture=OFF tool_actions=RUNNING duration=UNTIL_STOP segment_ms=10000")
    ToolTipInfoV386("ĐANG GHI LOG 10 GIÂY/ĐOẠN — BẤM XUẤT LOG ĐỂ DỪNG")
}
SetTimer, StopPickupCubeTrace, Off
SetTimer, RemoveToolTip, -2500
return

StopPickupCubeTrace:
SetTimer, NativeExportTimerV12, Off
SetTimer, CharacterDLLProbeTimerV3, Off
PacketWatchStopV1()
if (autoMonsterExportV2)
{
    AutoMonsterAttackLogV2("TRACE_END auto_attack=" . autoMonsterAttackOn . " checkbox_preserved=1")
    autoMonsterExportV2 := false
}
SetTimer, MonsterBossProbeTimerV1, Off
if (pickupCubeTraceUntil && A_TickCount >= pickupCubeTraceUntil)
{
    pickupCubeTraceUntil := 0
    pickupCubeTracePacket := false
    for _, traceChannel in ["pickup", "belt", "cube", "heal", "monster", "packet", "character"]
    {
        traceFile := DebugTraceFile(traceChannel)
        ManualLogAppendV81(A_Now . " tick=" . A_TickCount . " | TRACE_END channel=" . traceChannel . "`r`n", traceFile, "UTF-8")
    }
}
return

V105CaptureOpenedCube:
V105LogCubeState()
ToolTipInfoV386("Đã chụp Cube lần 2 - xem Auto-GSF-Cube.log")
SetTimer, RemoveToolTip, -2500
return

V105LogCubeState()
{
    if (!ManualLogActiveV81())
        return
    static captureNo := 0
    log := A_ScriptDir . "\Auto-GSF-Cube.log"
    pid := D2GetActiveGamePidV95()
    base := pid ? D2GetModuleBaseV35(pid, "D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    player := h ? D2ReadU32(h, base + 0x11BBFC) : 0
    inv := player ? D2ReadU32(h, player + 0x60) : 0
    first := inv ? D2ReadU32(h, inv + 0x10) : 0
    if (!first)
    {
        if (h)
            DllCall("CloseHandle", "Ptr", h)
        ManualLogAppendV81(A_Now . " | CUBE_STATE_ERROR active_pid=" . pid . "`r`n", log, "UTF-8")
        return false
    }
    captureNo++
    ctx := {pid:pid,h:h,inv:inv,first:first}
    snapshot := V9SnapshotAllItems(ctx)
    selected := D2ReadU32(h, base + 0x11B834)
    ManualLogAppendV81("`r`n" . A_Now . " | CUBE_STATE #" . captureNo . " pid=" . pid . " player=" . V92Hex(player) . " inv=" . V92Hex(inv) . " selected=" . V92Hex(selected) . "`r`n", log, "UTF-8")
    uiRaw := ""
    Loop, 256
        uiRaw .= Format("{:02X}",D2ReadU8V18(h,base+0x11B800+A_Index-1))
    ManualLogAppendV81("D2CLIENT_UI_11B800_11B8FF=" . uiRaw . "`r`n", log, "UTF-8")
    cubeCount := 0, insideCount := 0
    for uid,item in snapshot
    {
        if (item.cls=1204)
        {
            quality := D2ReadU8V18(h,item.data+0x00)
            cubeCount++
            ManualLogAppendV81("CUBE uid=" . uid . " quality=" . Format("{:02X}",quality) . " loc45=" . item.loc . " owner=" . V92Hex(item.owner) . " xy=" . item.x . "," . item.y . " unit=" . V92Hex(item.unit) . " itemData=" . V92Hex(item.data) . "`r`n", log, "UTF-8")
            raw := ""
            Loop, 128
                raw .= Format("{:02X}",D2ReadU8V18(h,item.data+A_Index-1))
            ManualLogAppendV81("CUBE_DATA_00_7F=" . raw . "`r`n", log, "UTF-8")
        }
        if (item.loc=3)
        {
            insideCount++
            ManualLogAppendV81("INSIDE uid=" . uid . " class=" . item.cls . " xy=" . item.x . "," . item.y . " itemData=" . V92Hex(item.data) . "`r`n", log, "UTF-8")
        }
    }
    ManualLogAppendV81("CUBE_STATE_END cube_count=" . cubeCount . " inside_count=" . insideCount . "`r`n", log, "UTF-8")
    DllCall("CloseHandle", "Ptr", h)
    return (cubeCount>0)
}
beltLogOK := V23WriteBelt16Log()
invLogOK := V2WriteManaProbeOnce()
cubeLogOK := V34WriteCubeProbeOnce()

trackLog := A_ScriptDir . "\TheoDoi-HP-Mana-Belt.log"
beltLog := A_ScriptDir . "\Belt-Wide-V24.log"
invLog := A_ScriptDir . "\HP-Mana-Test.log"
cubeLog := A_ScriptDir . "\Cube-HP-Mana-Test.log"

beltText := ""
invText := ""
cubeText := ""
if FileExist(beltLog)
    FileRead, beltText, %beltLog%
if FileExist(invLog)
    FileRead, invText, %invLog%
if FileExist(cubeLog)
    FileRead, cubeText, %cubeLog%

FileDelete, %trackLog%
ManualLogAppendV81("================ THEO DOI HP-MANA-BELT V33 " . A_Now . " ================`r`n", trackLog, "UTF-8")
ManualLogAppendV81("READ ONLY - NO SEND / NO CLICK / NO PACKET`r`n", trackLog, "UTF-8")
ManualLogAppendV81("MUC DICH: SO SANH BELT + RUONG TRUOC/SAU SHIFT+CHUOT TRAI`r`n", trackLog, "UTF-8")
ManualLogAppendV81("PROFILE=" . currentProfile . " | BUFF_RUONG=" . InvHealOn . " | PHIM_4HP=" . Belt4HPKey . " | PHIM_2HP2MANA=" . Belt2HP2ManaKey . "`r`n", trackLog, "UTF-8")
ManualLogAppendV81("BAT_HP=" . AutoPotOn . " | BAT_MANA=" . ManaOn . " | HP_NGUONG=" . PotHPThreshold . " | MANA_NGUONG=" . ManaThreshold . "`r`n", trackLog, "UTF-8")
ManualLogAppendV81("BELT_SCAN_OK=" . beltLogOK . " | INVENTORY_SCAN_OK=" . invLogOK . " | CUBE_SCAN_OK=" . cubeLogOK . "`r`n", trackLog, "UTF-8")

ManualLogAppendV81("`r`n================ BELT ================`r`n", trackLog, "UTF-8")
if (beltText != "")
    ManualLogAppendV81(beltText, trackLog, "UTF-8")
else
    ManualLogAppendV81("KHONG CO DU LIEU BELT`r`n", trackLog, "UTF-8")

ManualLogAppendV81("`r`n================ RUONG / INVENTORY ================`r`n", trackLog, "UTF-8")
if (invText != "")
    ManualLogAppendV81(invText, trackLog, "UTF-8")
else
    ManualLogAppendV81("KHONG CO DU LIEU RUONG / INVENTORY`r`n", trackLog, "UTF-8")

ManualLogAppendV81("`r`n================ RUONG CUBE / CUBE INVENTORY PROBE ================`r`n", trackLog, "UTF-8")
if (cubeText != "")
    ManualLogAppendV81(cubeText, trackLog, "UTF-8")
else
    ManualLogAppendV81("KHONG CO DU LIEU CUBE`r`n", trackLog, "UTF-8")

ManualLogAppendV81("`r`n================ END V34 ================`r`n", trackLog, "UTF-8")

if (beltLogOK && invLogOK && cubeLogOK)
    ToolTipInfoV386("XUẤT LOG OK - TheoDoi-HP-Mana-Belt.log")
else
    ToolTipInfoV386("XUẤT LOG CHƯA ĐỦ - vào game rồi thử lại")
SetTimer, RemoveToolTip, -2500
return

ManaTestLogOnce:
return


V23WriteBelt16Log()
{
    if (!ManualLogActiveV81())
        return
    log := A_ScriptDir . "\\Belt-Wide-V24.log"
    tmp := A_Temp . "\\d2_belt_v24.txt"
    FileDelete, %tmp%
    cmd := "tasklist /FI " . Chr(34) . "IMAGENAME eq Game.exe" . Chr(34) . " /FO CSV /NH > " . Chr(34) . tmp . Chr(34) . " 2>&1"
    RunWait, %ComSpec% /c %cmd%,, Hide
    FileRead, raw, %tmp%
    FileDelete, %tmp%

    pidFound := 0, player := 0, h := 0
    Loop, Parse, raw, `n, `r
    {
        ln := A_LoopField
        if !RegExMatch(ln, "i)^""Game\.exe"",""([0-9]+)""", m)
            continue
        pid := m1 + 0
        base := D2GetModuleBaseV35(pid, "D2Client.dll")
        if (!base)
            continue
        h0 := D2OpenProcess(pid)
        if (!h0)
            continue
        pp := D2ReadU32(h0, base + 0x11BBFC)
        if (!pp)
        {
            DllCall("CloseHandle", "Ptr", h0)
            continue
        }
        pidFound := pid, player := pp, h := h0
        break
    }
    if (!pidFound || !player || !h)
        return false

    inv := D2ReadU32(h, player + 0x60)
    first := inv ? D2ReadU32(h, inv + 0x10) : 0
    if (!inv || !first)
    {
        DllCall("CloseHandle", "Ptr", h)
        return false
    }
    ManualLogAppendV81("================ BELT WIDE GRAPH V24 " . A_Now . " ================`r`n", log, "UTF-8")
    ManualLogAppendV81("READ ONLY - BELT DISCOVERY ONLY - RUONG V22 UNTOUCHED - NO SEND/CLICK/PACKET`r`n", log, "UTF-8")
    ManualLogAppendV81("EXPECTED PHYSICAL BELT: 12 HP + 4 MANA`r`n", log, "UTF-8")
    ManualLogAppendV81("KNOWN: HP_CLASS=1229 MANA_CLASS=1234`r`n", log, "UTF-8")
    ManualLogAppendV81("PID=" . pidFound . " PLAYER=" . V92Hex(player) . " INV=" . V92Hex(inv) . " FIRST=" . V92Hex(first) . "`r`n`r`n", log, "UTF-8")

    queue := [first]
    seen := {}
    qi := 1
    itemN := 0, beltN := 0, hpN := 0, manaN := 0
    Loop, 8192
    {
        if (qi > queue.Length())
            break
        u := queue[qi]
        qi++
        if (!u || seen.HasKey(u))
            continue
        seen[u] := 1

        typ := D2ReadU32(h, u + 0x00)
        cls := D2ReadU32(h, u + 0x04)
        uid := D2ReadU32(h, u + 0x0C)
        itemData := D2ReadU32(h, u + 0x14)
        path := D2ReadU32(h, u + 0x2C)

        Loop, 64
        {
            po := (A_Index-1)*4
            pu := D2ReadU32(h, u + po)
            if (!pu || seen.HasKey(pu))
                continue
            ptyp := D2ReadU32(h, pu + 0x00)
            pcls := D2ReadU32(h, pu + 0x04)
            if (ptyp = 4 && pcls >= 1 && pcls <= 10000)
                queue.Push(pu)
        }

        if (typ = 4 && itemData)
        {
            Loop, 64
            {
                po := (A_Index-1)*4
                pu := D2ReadU32(h, itemData + po)
                if (!pu || seen.HasKey(pu))
                    continue
                ptyp := D2ReadU32(h, pu + 0x00)
                pcls := D2ReadU32(h, pu + 0x04)
                if (ptyp = 4 && pcls >= 1 && pcls <= 10000)
                    queue.Push(pu)
            }
        }

        if (typ != 4 || cls < 1 || cls > 10000 || !itemData)
            continue

        itemN++
        q00 := D2ReadU8V18(h, itemData + 0x00)
        loc44 := D2ReadU8V18(h, itemData + 0x44)
        loc45 := D2ReadU8V18(h, itemData + 0x45)
        owner := D2ReadU32(h, itemData + 0x5C)
        x := path ? D2ReadU32(h, path + 0x0C) : 0
        y := path ? D2ReadU32(h, path + 0x10) : 0
        mark := ""
        if (loc45 = 255)
        {
            beltN++
            mark .= " BELT_CANDIDATE#" . beltN
        }
        if (cls = 1229)
        {
            hpN++
            mark .= " HP_CLASS1229"
        }
        if (cls = 1234)
        {
            manaN++
            mark .= " MANA_CLASS1234"
        }

        ManualLogAppendV81("ITEM#" . itemN . " unit=" . V92Hex(u) . " class=" . cls . " id=" . uid . " q00=" . q00 . " loc44=" . loc44 . " loc45=" . loc45 . " owner=" . V92Hex(owner) . " path=" . V92Hex(path) . " xy=" . x . "," . y . mark . "`r`n", log, "UTF-8")

        if (loc45 = 255 || cls = 1229 || cls = 1234)
        {
            d := ""
            Loop, 64
            {
                off := (A_Index-1)*4
                vv := D2ReadU32(h, u + off)
                d .= (A_Index=1 ? "" : " ") . Format("{:02X}:{:08X}", off, vv)
            }
            ManualLogAppendV81("  UNIT_DWORDS_00_FC " . d . "`r`n", log, "UTF-8")

            b := ""
            Loop, 256
            {
                off := A_Index-1
                vv := D2ReadU8V18(h, itemData + off)
                b .= (A_Index=1 ? "" : " ") . Format("{:02X}:{:02X}", off, vv)
            }
            ManualLogAppendV81("  ITEMDATA_BYTES_00_FF " . b . "`r`n", log, "UTF-8")
        }
    }

    ManualLogAppendV81("`r`nGRAPH_SEEN=" . seen.Count() . " ITEM_FOUND=" . itemN . " BELT_LOC255=" . beltN . " HP_CLASS1229=" . hpN . " MANA_CLASS1234=" . manaN . "`r`n", log, "UTF-8")
    ManualLogAppendV81("END BELT WIDE GRAPH V24`r`n", log, "UTF-8")
    DllCall("CloseHandle", "Ptr", h)
    return true
}


V2WriteManaProbeOnce()
{
    if (!ManualLogActiveV81())
        return
    log := A_ScriptDir . "\\HP-Mana-Test.log"
    tmp := A_Temp . "\\d2_inventory_hpmana_v16.txt"
    FileDelete, %tmp%
    cmd := "tasklist /FI " . Chr(34) . "IMAGENAME eq Game.exe" . Chr(34) . " /FO CSV /NH > " . Chr(34) . tmp . Chr(34) . " 2>&1"
    RunWait, %ComSpec% /c %cmd%,, Hide
    FileRead, raw, %tmp%
    FileDelete, %tmp%

    pidFound := 0, player := 0, h := 0
    Loop, Parse, raw, `n, `r
    {
        ln := A_LoopField
        if !RegExMatch(ln, "i)^""Game\.exe"",""([0-9]+)""", m)
            continue
        pid := m1 + 0
        base := D2GetModuleBaseV35(pid, "D2Client.dll")
        if (!base)
            continue
        h0 := D2OpenProcess(pid)
        if (!h0)
            continue
        pp := D2ReadU32(h0, base + 0x11BBFC)
        if (!pp)
        {
            DllCall("CloseHandle", "Ptr", h0)
            continue
        }
        pidFound := pid, player := pp, h := h0
        break
    }
    if (!pidFound || !player || !h)
        return false

    inv := D2ReadU32(h, player + 0x60)
    first := inv ? D2ReadU32(h, inv + 0x10) : 0
    if (!inv || !first)
    {
        DllCall("CloseHandle", "Ptr", h)
        return false
    }
    ManualLogAppendV81("================ INVENTORY HP-MANA WIDE GRAPH V16 " . A_Now . " ================`r`n", log, "UTF-8")
    ManualLogAppendV81("READ ONLY - INVENTORY/RUONG ONLY - NO BELT ACTION - NO GET - NO SEND/CLICK/PACKET`r`n", log, "UTF-8")
    ManualLogAppendV81("PID=" . pidFound . " PLAYER=" . V92Hex(player) . " INVENTORY=" . V92Hex(inv) . " FIRST=" . V92Hex(first) . "`r`n", log, "UTF-8")
    hpNow := D2GetCurrentHPV1()
    manaNow := D2GetCurrentManaV17()
    ManualLogAppendV81("CURRENT_HP=" . hpNow . " HP_KNOWN_CLASS=1229`r`n", log, "UTF-8")
    ManualLogAppendV81("CURRENT_MANA=" . manaNow . " MANA_KNOWN_CLASS=1234`r`n", log, "UTF-8")
    statDumpV21 := D2DumpPlayerStatRootV21()
    ManualLogAppendV81("---------------- STAT ROOT V21 0x00..0x100 ----------------`r`n" . statDumpV21, log, "UTF-8")

    queue := [first]
    seen := {}
    qi := 1
    foundCount := 0
    Loop, 4096
    {
        if (qi > queue.Length())
            break
        u := queue[qi]
        qi++
        if (!u || seen.HasKey(u))
            continue
        seen[u] := 1

        typ := D2ReadU32(h, u + 0x00)
        cls := D2ReadU32(h, u + 0x04)
        uid := D2ReadU32(h, u + 0x0C)
        itemData := D2ReadU32(h, u + 0x14)
        path := D2ReadU32(h, u + 0x2C)
        e4 := D2ReadU32(h, u + 0xE4)
        e8 := D2ReadU32(h, u + 0xE8)

        if (e4 && !seen.HasKey(e4))
            queue.Push(e4)
        if (e8 && !seen.HasKey(e8))
            queue.Push(e8)

        if (typ = 4 && itemData)
        {
            ptrOffsets := [0x60, 0x64, 0x6C, 0x70, 0x84, 0xAC, 0xB0, 0xB4, 0xC8, 0xD8]
            for _, po in ptrOffsets
            {
                pu := D2ReadU32(h, itemData + po)
                if (!pu || seen.HasKey(pu))
                    continue
                ptyp := D2ReadU32(h, pu + 0x00)
                pcls := D2ReadU32(h, pu + 0x04)
                if (ptyp = 4 && pcls >= 1 && pcls <= 10000)
                    queue.Push(pu)
            }
        }

        if (typ != 4 || cls < 1 || cls > 10000 || !itemData)
            continue

        foundCount++
        q00 := D2ReadU8V18(h, itemData + 0x00)
        loc44 := D2ReadU8V18(h, itemData + 0x44)
        loc45 := D2ReadU8V18(h, itemData + 0x45)
        x := path ? D2ReadU32(h, path + 0x0C) : 0
        y := path ? D2ReadU32(h, path + 0x10) : 0
        mark := (cls = 1229 ? " HP_KNOWN" : " MANA_CANDIDATE")

        ManualLogAppendV81("`r`nITEM n=" . foundCount . " unit=" . V92Hex(u) . " type=" . typ . " class=" . cls . " id=" . uid . " itemData=" . V92Hex(itemData) . " q00=" . q00 . " loc44=" . loc44 . " loc45=" . loc45 . " path=" . V92Hex(path) . " xy=" . x . "," . y . " E4=" . V92Hex(e4) . " E8=" . V92Hex(e8) . mark . "`r`n", log, "UTF-8")

        ManualLogAppendV81("UNIT_DWORDS_00_FC`r`n", log, "UTF-8")
        line := ""
        Loop, 64
        {
            ro := (A_Index - 1) * 4
            rv := D2ReadU32(h, u + ro)
            line .= Format("{:02X}", ro) . ":" . V92Hex(rv) . " "
            if (Mod(A_Index, 8) = 0)
            {
                ManualLogAppendV81(line . "`r`n", log, "UTF-8")
                line := ""
            }
        }

        ManualLogAppendV81("ITEMDATA_DWORDS_00_FC PTR=" . V92Hex(itemData) . "`r`n", log, "UTF-8")
        line := ""
        Loop, 64
        {
            ro := (A_Index - 1) * 4
            rv := D2ReadU32(h, itemData + ro)
            line .= Format("{:02X}", ro) . ":" . V92Hex(rv) . " "
            if (Mod(A_Index, 8) = 0)
            {
                ManualLogAppendV81(line . "`r`n", log, "UTF-8")
                line := ""
            }
        }

        ManualLogAppendV81("ITEMDATA_BYTES_00_7F`r`n", log, "UTF-8")
        line := ""
        Loop, 128
        {
            bo := A_Index - 1
            bv := D2ReadU8V18(h, itemData + bo)
            line .= Format("{:02X}", bo) . ":" . Format("{:02X}", bv) . " "
            if (Mod(A_Index, 16) = 0)
            {
                ManualLogAppendV81(line . "`r`n", log, "UTF-8")
                line := ""
            }
        }
    }

    ManualLogAppendV81("`r`nSUMMARY V16 INVENTORY_ITEMS=" . foundCount . " GRAPH_NODES=" . seen.Count() . "`r`n", log, "UTF-8")
    ManualLogAppendV81("END INVENTORY HP-MANA WIDE GRAPH V16`r`n", log, "UTF-8")
    DllCall("CloseHandle", "Ptr", h)
    return true
}

ClickCastTimer:
ClickCastDoubleHandler:
return

ClickCastReleaseWatch:
if (!GetKeyState(clickCastDoubleKey, "P"))
{
    clickCastHeld := false
    SetTimer, ClickCastReleaseWatch, Off
}
return

ClearExtraFRows()
{
    global FKey5, FKey6, FKey7, FKey8, FKey9, FKey10
    global FDelay5, FDelay6, FDelay7, FDelay8, FDelay9, FDelay10
    Loop, 5
    {
        i := A_Index + 5
        FKey%i% := ""
        FDelay%i% := 0
    }
}

SaveClickCastConfig(section)
{
    Form6SaveV716(section)
    global ConfigFile, clickCastRows, clickCastDoubleKey, clickCastDoubleTapMs
    IniWrite, %clickCastDoubleKey%, % ProfileConfigPathV364(section), %section%, ClickCastDoubleKey
    IniWrite, %clickCastDoubleTapMs%, % ProfileConfigPathV364(section), %section%, ClickCastDoubleTapMs
    for i, row in clickCastRows
    {
        key := row.key
        delay := row.delay
        IniWrite, %key%, % ProfileConfigPathV364(section), %section%, ClickCastKey%i%
        IniWrite, %delay%, % ProfileConfigPathV364(section), %section%, ClickCastDelay%i%
    }
}

LoadClickCastConfig(section)
{
    Form6LoadV716(section)
    global ConfigFile, clickCastRows, clickCastDoubleKey, clickCastDoubleTapMs
    global lastClickCastTap, clickCastHeld, doubleKey, formDoubleKey, qCastDoubleKey
    if (clickCastDoubleKey != "")
        ToolDoubleBindV18(clickCastDoubleKey,"ClickCastDoubleHandler","Off")
    IniRead, key, % ProfileConfigPathV364(section), %section%, ClickCastDoubleKey, Down
    if (!InStr("|None|Left|Right|Up|Down|Home|End|PgUp|PgDn|", "|" . key . "|"))
        key := "Down"
    IniRead, interval, % ProfileConfigPathV364(section), %section%, ClickCastDoubleTapMs, 1000
    if interval is not integer
        interval := 1000
    if (interval < 50)
        interval := 1000
    if (key!="None" && (key = doubleKey || key = formDoubleKey || key = qCastDoubleKey))
    {
        for _, candidate in ["Down", "Home", "End", "PgUp", "PgDn", "Left", "Right", "Up"]
        {
            if (candidate != doubleKey && candidate != formDoubleKey && candidate != qCastDoubleKey)
            {
                key := candidate
                break
            }
        }
    }
    clickCastDoubleKey := "None"
    clickCastDoubleTapMs := interval + 0
    lastClickCastTap := 0
    clickCastHeld := false
    SetTimer, ClickCastReleaseWatch, Off
    clickCastRows := []
    Loop, 6
    {
        i := A_Index
        IniRead, key, % ProfileConfigPathV364(section), %section%, ClickCastKey%i%, None
        IniRead, delay, % ProfileConfigPathV364(section), %section%, ClickCastDelay%i%, 0
        key := NormalizeOptionalKey(key)
        if (key != "" && !GetKeyVK(key) && !GetKeySC(key))
            key := ""
        if delay is not integer
            delay := 0
        if (delay < 0)
            delay := 0
        clickCastRows.Push({key: key, delay: delay + 0, last: A_TickCount})
    }
    ToolDoubleBindV18(clickCastDoubleKey,"ClickCastDoubleHandler","On")
}

RefreshClickCastControls()
{
    Form6RefreshV716()
    global clickCastRows, clickCastDoubleKey, clickCastDoubleTapMs, qCastDoubleKey, qCastDoubleTapMs
    for i, row in clickCastRows
    {
        key := (row.key = "" ? "None" : row.key)
        delay := row.delay
        GuiControl,, RClickKey%i%, % MouseKeyDisplayV616(key)
        GuiControl,, RClickDelay%i%, %delay%
    }
    GuiControl, ChooseString, QCastDoubleKey, %qCastDoubleKey%
    GuiControl,, QCastDoubleTapMs, %qCastDoubleTapMs%
    GuiControl, ChooseString, ClickCastKeyInput, %clickCastDoubleKey%
    GuiControl,, ClickCastMsInput, %clickCastDoubleTapMs%
}


QuickBuffRun(skipToggleKeyV27 := "",selectLastFOnlyV377 := false)
{
    global zSetKey, zSetDelay, zFKey, zFKey2, zDelay1, zDelay2, xDelay
    global QCastKey1, QCastKey2, QCastKey3, QCastDelay1, QCastDelay2, QCastDelay3
    global qCastLast1, qCastLast2, qCastLast3, clickCastRows
    global FKey1, FKey2, FKey3, FKey4, FKey5
    global FDelay1, FDelay2, FDelay3, FDelay4, FDelay5
    global cycleStep, nextStepTime
    global farmBuffExclusiveV621,xRunning,farmRunEpochV535,autoMonsterAttackOn
    if (farmBuffExclusiveV621)
        return false
    savedXRunningV621 := xRunning,epochV621 := farmRunEpochV535,attackWasOnV621 := autoMonsterAttackOn
    farmBuffExclusiveV621 := true,xRunning := true,completedV621 := false
    FarmAttackHoldReleaseV15()
    try
    {
    FarmSkillBaselineEnsureV621(D2GetActiveGamePidV95())
    castRows := []
    fRows := []
    clickRows := []
    Loop, 3
    {
        i := A_Index
        castRows.Push({key:QCastKey%i%, delay:QCastDelay%i%, index:i})
    }
    for _, row in clickCastRows
        clickRows.Push({key:row.key, delay:row.delay, source:row})
    Loop, 4
    {
        i := A_Index
        if (FKey%i% = "" || FKey%i% = "None")
            break
        fRows.Push({key:FKey%i%, delay:FDelay%i%, index:i})
    }
    if (QuickBuffAllowedV27(zSetKey,skipToggleKeyV27))
        if (!QuickBuffSend(zSetKey) || !QuickBuffWait(zSetDelay))
            return false
    if (QuickBuffAllowedV27(zFKey,skipToggleKeyV27))
        if (!QuickBuffCast(zFKey, zDelay1))
            return false
    if (QuickBuffAllowedV27(zFKey2,skipToggleKeyV27))
        if (!QuickBuffCast(zFKey2, zDelay2))
            return false
    if (QuickBuffAllowedV27(zSetKey,skipToggleKeyV27))
        if (!BuffSetReturnV500(zSetKey,zSetDelay))
            return false
    for _, row in castRows
    {
        if (!QuickBuffAllowedV27(row.key,skipToggleKeyV27))
            continue
        if (!QuickBuffSend(row.key))
            return false
        i := row.index
        qCastLast%i% := A_TickCount
        if (!QuickBuffWait(xDelay))
            return false
    }
    for _, row in clickRows
    {
        if (!QuickBuffAllowedV27(row.key,skipToggleKeyV27))
            continue
        if (!QuickBuffCast(row.key, xDelay))
            return false
        row.source.last := A_TickCount
    }
    lastFIndex := 0
    for _, row in fRows
    {
        if (!QuickBuffAllowedV27(row.key,skipToggleKeyV27))
            continue
        if (row.index=5 || (row.index=fRows.Length() && (selectLastFOnlyV377 || CastKeysMatch(row.key,"F10"))))
        {
            if (!QuickBuffSend(row.key) || !QuickBuffWait(xDelay))
                return false
        }
        else if (!QuickBuffCast(row.key, xDelay))
            return false
        lastFIndex := row.index
    }
    cycleStep := lastFIndex + 1
    if (cycleStep > fRows.Length())
        cycleStep := 1
    nextStepTime := 0
    if (!BuffSetFixRightV500())
        return false
    completedV621 := true
    return true
    }
    finally
    {
        farmBuffExclusiveV621 := false
        xRunning := epochV621=farmRunEpochV535 ? savedXRunningV621 : false
        if (completedV621 && attackWasOnV621 && epochV621=farmRunEpochV535)
            FarmBuffResumeVerifiedV621()
    }
}

QuickBuffHasKey(key)
{
    key := Trim(key)
    return key != "" && !RegExMatch(key,"i)^(?:None|Error)$")
}

QuickBuffSend(key)
{
    global farmPortalBuffActiveDeadlineV1301
    if (farmPortalBuffActiveDeadlineV1301 && A_TickCount>=farmPortalBuffActiveDeadlineV1301)
        return false
    if (!BuffSequenceContinueV555() || !IsGameActive())
        return false
    if (!DeathlordKeyAllowedV29(key))
        return false
    return GameTargetKeyV63("{" . key . "}")
}

QuickBuffCast(key, delay)
{
    global scosEntryV162
    if (!DeathlordKeyAllowedV29(key))
        return true
    if (!QuickBuffSend(key) || !QuickBuffWait(30))
        return false
    if (!IsGameActive())
        return false
    if (!GameTargetBuffSelfClickV454())
        return false
    return QuickBuffWait(delay)
}

QuickBuffWait(ms)
{
    global farmPortalBuffActiveDeadlineV1301
    if ((farmPortalBuffActiveDeadlineV1301 && A_TickCount>=farmPortalBuffActiveDeadlineV1301)
        || !BuffSequenceContinueV555())
        return false
    started := A_TickCount
    while (A_TickCount - started < ms)
    {
        if (!BuffSequenceContinueV555() || !IsGameActive()
            || (farmPortalBuffActiveDeadlineV1301 && A_TickCount>=farmPortalBuffActiveDeadlineV1301))
            return false
        Sleep, 10
    }
    return BuffSequenceContinueV555() && IsGameActive()
        && (!farmPortalBuffActiveDeadlineV1301 || A_TickCount<farmPortalBuffActiveDeadlineV1301)
}

ResetAfterQuickBuff()
{
    global qCastLast1, qCastLast2, qCastLast3, clickCastRows
    global cycleStep, nextStepTime, FDelay1
    global pickupLastClick, v61LastPickupTick
    global lastDoubleKeyTime, lastQCastDoubleKeyTime, lastClickCastTap
    now := A_TickCount
    qCastLast1 := now
    qCastLast2 := now
    qCastLast3 := now
    for _, row in clickCastRows
        row.last := now
    cycleStep := 1
    nextStepTime := now + FDelay1
    pickupLastClick := now
    v61LastPickupTick := now
    lastDoubleKeyTime := 0
    lastQCastDoubleKeyTime := 0
    lastClickCastTap := 0
}

Master456Handler:
return

Master456StateSaveV121(profile)
{
    global ConfigFile,master456Paused,master456Saved,QCastOn,clickCastOn,cycleOn
    section := ProfileSection(profile)
    paused := master456Paused ? 1 : 0
    cast := paused && IsObject(master456Saved) ? master456Saved.cast : QCastOn
    click := paused && IsObject(master456Saved) ? master456Saved.click : clickCastOn
    cycle := paused && IsObject(master456Saved) ? master456Saved.cycle : cycleOn
    IniWrite, %paused%, % ProfileConfigPathV364(section), %section%, Master456Paused
    IniWrite, %cast%, % ProfileConfigPathV364(section), %section%, Master456ResumeCast
    IniWrite, %click%, % ProfileConfigPathV364(section), %section%, Master456ResumeClick
    IniWrite, %cycle%, % ProfileConfigPathV364(section), %section%, Master456ResumeCycle
}

Master456StateLoadV121(profile)
{
    global master456Paused,master456Saved
    master456Paused := false,master456Saved := false
    Cycle6GuiSyncV525()
}

SaveMaster456Key()
{
    global ConfigFile, master456Key
    key := (master456Key = "" ? "None" : master456Key)
    IniWrite, %key%, %ConfigFile%, Master456, Key
}

MonsterBossProbeTimerV1:
if (!ManualLogActiveV81())
{
    SetTimer, MonsterBossProbeTimerV1, Off
    return
}
if (!pickupCubeTraceUntil || A_TickCount >= pickupCubeTraceUntil)
{
    SetTimer, MonsterBossProbeTimerV1, Off
    return
}
if (monsterProbeBusyV1 || !IsGameActive())
    return
monsterProbeBusyV1 := true
try
    MonsterBossProbeScanV1()
finally
    monsterProbeBusyV1 := false
return

MonsterBossProbeReadV1(h, addr, size, ByRef buf)
{
    if (!h || addr < 0x10000 || size <= 0)
        return false
    VarSetCapacity(buf, size, 0)
    return DllCall("ReadProcessMemory", "Ptr", h, "Ptr", addr, "Ptr", &buf
        , "UPtr", size, "UPtrP", got) && got = size
}

MonsterBossProbeHexV1(ByRef buf, size)
{
    out := ""
    Loop, %size%
        out .= Format("{:02X}", NumGet(buf, A_Index-1, "UChar"))
    return out
}

MonsterBossProbeScanV1()
{
    global monsterProbeSeenV1, pickupCubeTraceUntil
    static cachePid := 0, cacheBase := 0
    pid := D2GetActiveGamePidV95()
    if (!pid)
        return
    if (pid != cachePid || !cacheBase)
    {
        cachePid := pid
        cacheBase := D2GetModuleBaseV35(pid, "D2Client.dll")
    }
    h := cacheBase ? DllCall("OpenProcess", "UInt", 0x0410, "Int", 0, "UInt", pid, "Ptr") : 0
    if (!h)
    {
        DebugTraceWrite("monster", "ERROR=OPEN_READ_CONTEXT pid=" . pid)
        return
    }
    try
    {
        player := D2ReadU32(h, cacheBase+0x11BBFC)
        path := player ? D2ReadU32(h, player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h, path, 0x80, pb))
        {
            DebugTraceWrite("monster", "ERROR=PLAYER_PATH_READ pid=" . pid . " player=" . V92Hex(player))
            return
        }
        px := NumGet(pb, 0x02, "UShort"), py := NumGet(pb, 0x06, "UShort")
        room := NumGet(pb, 0x1C, "UInt")
        selectedRaw := D2ReadU32(h, cacheBase+0x11B834)
        DebugTraceWrite("monster", "SCAN pid=" . pid . " player=" . V92Hex(player)
            . " xy=" . px . "," . py . " room=" . V92Hex(room)
            . " selected_raw_11B834=" . V92Hex(selectedRaw))
        if (!room)
        {
            DebugTraceWrite("monster", "ERROR=ROOM_NOT_READY")
            return
        }
        rooms := MonsterLoadedRoomsV20(h,room), seenRooms := {}, seenUnits := {}

        DebugTraceWrite("monster", "BOSS_IDENTIFY_CONTEXT level=" . CoordLevelV14(h,room)
            . " selected_pointer_raw=" . V92Hex(selectedRaw)
            . " classification=UNCONFIRMED purpose=COMPARE_CLASS_UID_AND_MONSTER_DATA")
        count := 0, total := 0, errors := 0, truncated := false
        hpReads := 0, highestHP := -1, highestUID := 0, highestClass := 0, highestDist := -1, highestMaxHP := -1
        bestId := 0, bestDist := 0x7FFFFFFF, start := A_TickCount
        for ri, r in rooms
        {
            if (seenRooms.HasKey(r))
                continue
            seenRooms[r] := true
            u := D2ReadU32(h, r+0x74)
            Loop, 1024
            {
                if (!u || seenUnits.HasKey(u))
                    break
                if (total >= 2048 || A_TickCount-start >= 120
                    || A_TickCount >= pickupCubeTraceUntil || D2GetActiveGamePidV95() != pid)
                {
                    truncated := true
                    break
                }
                seenUnits[u] := true
                if (!MonsterBossProbeReadV1(h, u, 0xEC, ub))
                {
                    errors++
                    break
                }
                total++
                typ := NumGet(ub, 0x00, "UInt"), cls := NumGet(ub, 0x04, "UInt")
                uid := NumGet(ub, 0x0C, "UInt"), mode := NumGet(ub, 0x10, "UInt")
                data := NumGet(ub, 0x14, "UInt"), upath := NumGet(ub, 0x2C, "UInt")
                next := NumGet(ub, 0xE8, "UInt")
                if (typ = 1)
                {
                    count++
                    pathOK := MonsterBossProbeReadV1(h, upath, 0x80, mb)
                    x := pathOK ? NumGet(mb, 0x02, "UShort") : -1
                    y := pathOK ? NumGet(mb, 0x06, "UShort") : -1
                    dist := pathOK ? Abs(x-px)+Abs(y-py) : -1
                    hpInfo := MonsterBossProbeHPV2(h, NumGet(ub, 0x5C, "UInt"))
                    if (hpInfo.ok)
                        hpReads++
                    if (pathOK && hpInfo.ok && hpInfo.hp > 0
                        && (hpInfo.hp > highestHP || (hpInfo.hp = highestHP && dist < highestDist)))
                    {
                        highestHP := hpInfo.hp, highestMaxHP := hpInfo.maxhp
                        highestUID := uid, highestClass := cls, highestDist := dist
                    }
                    DebugTraceWrite("monster", "CANDIDATE room=" . ri . " unit=" . V92Hex(u)
                        . " type=" . typ . " class=" . cls . " uid=" . uid . " mode_raw=" . mode
                        . " data=" . V92Hex(data) . " path=" . V92Hex(upath)
                        . " path_ok=" . pathOK . " xy=" . x . "," . y . " dist_L1=" . dist
                        . " hp=" . hpInfo.hp . " max_hp=" . hpInfo.maxhp . " hp_ok=" . hpInfo.ok
                        . " hp_raw=" . hpInfo.raw . " max_hp_raw=" . hpInfo.maxraw
                        . " hp_source=" . hpInfo.source . " hp_reason=" . hpInfo.reason
                        . " selected_raw_match=" . (selectedRaw=u)
                        . " alive=" . (mode!=0 && mode!=12) . " excluded_pet_class=" . MonsterClassExcludedV11(cls,h,u)
                        . " level=" . (pathOK ? CoordLevelV14(h,NumGet(mb,0x1C,"UInt")) : -1)
                        . " dist_L2=" . (pathOK ? Round(Sqrt((x-px)**2+(y-py)**2),2) : -1)
                        . " boss=UNCONFIRMED enemy=UNCONFIRMED")
                    if (pathOK && dist < bestDist)
                        bestDist := dist, bestId := uid
                    key := pid . ":" . u . ":" . uid . ":" . cls . ":" . data
                    if (!monsterProbeSeenV1.HasKey(key))
                    {
                        monsterProbeSeenV1[key] := true
                        DebugTraceWrite("monster", "HP_STATS_RAW uid=" . uid . " " . hpInfo.dump)
                        DebugTraceWrite("monster", "UNIT_RAW uid=" . uid . " bytes_00_EB=" . MonsterBossProbeHexV1(ub, 0xEC))
                        if (pathOK)
                            DebugTraceWrite("monster", "PATH_RAW uid=" . uid . " bytes_00_7F=" . MonsterBossProbeHexV1(mb, 0x80))
                        if (MonsterBossProbeReadV1(h, data, 0x80, db))
                        {
                            DebugTraceWrite("monster", "DATA_RAW uid=" . uid . " class=" . cls . " bytes_00_7F=" . MonsterBossProbeHexV1(db, 0x80))
                            DebugTraceWrite("monster", "BOSS_DATA_COMPARE uid=" . uid . " class=" . cls
                                . " raw_u8_16=" . NumGet(db,0x16,"UChar") . " raw_u16_18=" . NumGet(db,0x18,"UShort")
                                . " raw_u32_1C=" . V92Hex(NumGet(db,0x1C,"UInt"))
                                . " interpretation=UNCONFIRMED no_boss_priority_applied=1")
                        }
                        else
                            DebugTraceWrite("monster", "DATA_READ_FAIL uid=" . uid)
                    }
                }
                u := next
            }
            if (truncated)
                break
        }
        DebugTraceWrite("monster", "SUMMARY rooms=" . seenRooms.Count() . " units=" . total
            . " type1_candidates=" . count . " read_errors=" . errors . " truncated=" . truncated
            . " nearest_candidate_uid=" . bestId . " dist_L1=" . (bestId ? bestDist : -1)
            . " hp_read_ok=" . hpReads . " priority_requested=HIGHEST_CURRENT_HP"
            . " highest_hp_candidate_uid=" . highestUID . " class=" . highestClass
            . " hp=" . highestHP . " max_hp=" . highestMaxHP . " dist_L1=" . highestDist
            . " hostile=UNCONFIRMED target_selected=0 attack_sent=0")
    }
    finally
        DllCall("CloseHandle", "Ptr", h)
}

MonsterBossProbeHPV2(h, stats)
{
    result := {ok:false,hp:-1,maxhp:-1,raw:-1,maxraw:-1
        ,source:"NONE",reason:"STATS_READ_FAIL",dump:"stats=" . V92Hex(stats)}
    if (!MonsterBossProbeReadV1(h, stats, 0x80, sb))
        return result
    result.dump .= " bytes_00_7F=" . MonsterBossProbeHexV1(sb, 0x80)
    result.reason := "HP_STAT_NOT_FOUND"
    for _, off in [0x48, 0x24]
    {
        root := NumGet(sb, off, "UInt")
        count := NumGet(sb, off+4, "UShort")
        capacity := NumGet(sb, off+6, "UShort")
        label := "STATS+" . Format("{:02X}", off)
        result.dump .= " " . label . " ptr=" . V92Hex(root)
            . " count=" . count . " capacity=" . capacity
        if (!root || count < 1 || count > 512 || capacity < count)
            continue
        if (!MonsterBossProbeReadV1(h, root, count*8, ab))
        {
            result.dump .= " READ_FAIL"
            continue
        }
        result.dump .= " array_first_" . Min(count,32) . "=" . MonsterBossProbeHexV1(ab, Min(count,32)*8)
        hpRaw := -1, maxRaw := -1, duplicates := false
        Loop, %count%
        {
            entry := (A_Index-1)*8
            layer := NumGet(ab, entry, "UShort")
            statId := NumGet(ab, entry+2, "UShort")
            value := NumGet(ab, entry+4, "UInt")
            if (layer != 0)
                continue
            if (statId = 6)
            {
                if (hpRaw != -1)
                    duplicates := true
                hpRaw := value
            }
            if (statId = 7)
            {
                if (maxRaw != -1)
                    duplicates := true
                maxRaw := value
            }
        }
        result.dump .= " hp_raw=" . hpRaw . " max_raw=" . maxRaw . " duplicate=" . duplicates
        if (duplicates || hpRaw < 0 || maxRaw <= 0 || hpRaw > maxRaw)
            continue
        result.ok := true
        result.hp := Floor(hpRaw/256), result.maxhp := Floor(maxRaw/256)
        result.raw := hpRaw, result.maxraw := maxRaw
        result.source := label, result.reason := "STRUCTURE_MATCH_PROBE"
        return result
    }
    return result
}

FarmGD2TestButtonV644:
FarmGD2TestStartV644()
return

FarmGD2TestStopV644(message := "Đã dừng TEST GD2.")
{
    global farmGD2TestV644,farmControlOwnerV186
    previousOwner := IsObject(farmGD2TestV644) ? farmGD2TestV644.previousOwner : ""
    FarmButtonStopV1()
    farmControlOwnerV186 := previousOwner
    FonInfoPushV385(message)
    return false
}

FarmGD2TestReadyV644(pid,level)
{
    global farmGD2TestV644,coordSavedV15
    if (!IsObject(farmGD2TestV644))
        return false
    if (pid!=farmGD2TestV644.pid || level!=farmGD2TestV644.level)
        return FarmGD2TestStopV644("TEST GD2 dừng: cửa sổ hoặc map đã đổi.")
    return IsObject(coordSavedV15) && coordSavedV15.Length()>0
}

FarmGD2TestStartV644()
{
    global
    local row,previousOwner,pid,level,point,oldResume
    if (IsObject(farmGD2TestV644))
        return FarmGD2TestStopV644()
    if (sigBusyV147 || gameItemActionOwner!="")
    {
        FonInfoPushV385("TEST GD2: chờ thao tác vật phẩm xong rồi bấm lại.")
        return false
    }
    row := FarmStartRowV394(),previousOwner := farmControlOwnerV186
    if (!SigBackgroundBindV179())
    {
        FonInfoPushV385("TEST GD2: chọn cửa sổ game trước.")
        return false
    }
    pid := backgroundPidV63,level := RoomRecordLevelV259(pid)
    if (!pid || !level)
    {
        FonInfoPushV385("TEST GD2: cần vào map trước.")
        return false
    }
    FarmButtonStopV1()
    CoordSavedLoadV15(currentProfile)
    if (!IsObject(coordSavedV15) || !coordSavedV15.Length())
    {
        FonInfoPushV385("TEST GD2: map đang chọn chưa có tọa độ đã lưu.")
        return false
    }
    row := Max(1,Min(row,coordSavedV15.Length()))
    for _,point in coordSavedV15
    {
        if (point.level!=level)
        {
            FonInfoPushV385("TEST GD2: tuyến đang chọn khác map hiện tại.")
            return false
        }
    }
    FarmRuntimeResetV535("GD2_TEST_START")
    farmGD2TestV644 := {pid:pid,level:level,row:row,starting:true,previousOwner:previousOwner}
    farmControlOwnerV186 := "TEST",mapWorkflowV185 := false
    coordYellowRowV350 := row
    GuiControl, 1:, FarmGD2TestButtonV644, Dừng
    autoMonsterAttackOn := true
    oldResume := farmResumeInternalV70,farmResumeInternalV70 := true
    Gosub, AutoMonsterAttackToggle
    farmResumeInternalV70 := oldResume
    if (!IsObject(farmGD2TestV644))
        return false
    farmGD2TestV644.starting := false
    if (!autoMonsterAttackOn || stage2StartPendingV381)
        return FarmGD2TestStopV644("TEST GD2: chưa khởi động được, kiểm tra game và tuyến đã lưu.")
    FarmWatchStartV5()
    FonInfoPushV385("TEST GD2: chạy từ dòng vàng " . row . " đến cuối tuyến.")
    return true
}

AutoMonsterAttackToggle:
if (farmUserPausedV2026 && autoMonsterAttackOn)
    return
if (autoMonsterAttackOn)
    farmManualStoppedV2026 := false
if (autoMonsterAttackOn)
    FarmElapsedStartV1350()
else if (!FarmControlRunningV186() && !IsObject(scosEntryV162) && !IsObject(stageTwoV166)
    && !IsObject(mapWorkflowV185) && !IsObject(farmMapPauseV52))
    FarmElapsedStopV1350()
if (autoMonsterAttackOn)
{
    if (!farmResumeInternalV70)
        mapLoadFailureV402 := false
    if (farmControlOwnerV186!="BO")
        FonTrackingEnableV410()
    if (!BOCoordinateBlockedV471())
    {
        SetTimer, CoordCurrentTimerV15, 500
        CoordCurrentReadV15()
    }
}
startYellowV367 := FarmStartRowV394(),startYellowMapV367 := routeMapIdV21
if (autoMonsterAttackOn && FarmStartApplyYellowV2())
    startYellowV367 := FarmStartRowV394(),startYellowMapV367 := routeMapIdV21
if (!autoMonsterAttackOn)
{
    farmStartRetryV237 := false
}
if (autoMonsterAttackOn && !farmResumeInternalV70)
    farmCubeSortOnceV253 := false
if (autoMonsterAttackOn)
    pickupStashListV217 := {}
if (autoMonsterAttackOn && IsObject(sigTownV148))
    SigTownCancelV148("USER_RESTARTED_FARM")
if (autoMonsterAttackOn && IsObject(roomRecordV108) && roomRecordV108.insertMode)
{
    if (!RoomInsertStopV125())
    {
        FarmStartWaitV237("RECORD_INSERT_BUSY")
        return
    }
}
if (!autoMonsterAttackOn && IsObject(roomExploreV89))
    RoomExploreEndV89("FARM_OFF")
portalBuffV85 := false
MovementCtrlSetV78(false,0,"AutoMonsterAttackToggle")
if (autoMonsterAttackOn && !BackgroundBindV63(backgroundHwndV63))
{
    FarmStartWaitV237("GAME_BIND_NOT_READY")
    return
}
if (autoMonsterAttackOn)
    FarmSkillBaselineEnsureV621(backgroundPidV63)
if (autoMonsterAttackOn && !BossSearchActiveV430() && !Stage2MapRequestV381())
{
    if (!autoMonsterAttackOn)
        return
    stage2StartPendingV381 := true
    SetTimer, Stage2StartWaitTimerV381, 250
    PortalLogWriteV66("STAGE2_START_WAIT reason=NO_SELECTED_ROUTE", "STAGE2_ROUTE_WAIT",2000)
    return
}
stage2StartPendingV381 := false
SetTimer, Stage2StartWaitTimerV381, Off
if (autoMonsterAttackOn && coordSavedV15.Length())
    farmLoadedMapV56 := {pid:backgroundPidV63,profile:currentProfile,mapId:routeMapIdV21
        ,level:coordSavedV15[1].level}

if (autoMonsterAttackOn && !pickupImageOn && Stage2FightEnabledV9())
    PickupEnabledSetV71(true,false,false)

if (autoMonsterAttackOn)
{
    if (IsObject(mapWorkflowV185) && mapWorkflowV185.map="SCOS" && mapWorkflowV185.testRows>0)
    {
        while (coordSavedV15.Length()>mapWorkflowV185.testRows)
            coordSavedV15.Pop()
        AutoMonsterAttackLogV2("TEST_ROUTE_LIMIT map=SCOS rows=" . coordSavedV15.Length() . " saved_file=UNCHANGED")
    }
    CoordBoxRefreshV15(true)
}
if (autoMonsterAttackOn)
    Stage2FlowSelectCainV380()
else
    Stage2FlowConfigureV380()
if (autoMonsterAttackOn && farmBuffModeV509!=1)
    FarmBuffStartV509()
FarmCastSyncV88(autoMonsterAttackOn)
if (autoMonsterAttackOn)
{
    PickupEnabledSetV71(true,true,false)
    farmResumeArmedV70 := true
    SetTimer, FarmResumeTimerV70, 500
}
coordGoV59 := false
SetTimer, CoordGoTimerV59, Off
entryBuffAlreadyDoneV233 := scosStartFarmV162 && IsObject(mapStage1BuffDoneV248)
    && mapStage1BuffDoneV248.pid=backgroundPidV63
startAlreadyFarmV757 := autoMonsterAttackOn && FarmStartInFarmV757(backgroundPidV63)
reviveBuffPendingV34 := autoMonsterAttackOn && !IsObject(roomExploreV89) && !entryBuffAlreadyDoneV233 && !startAlreadyFarmV757
if (startAlreadyFarmV757)
{
    entryBuffPendingV20 := false
    PortalLogWriteV66("START_IN_FARM_READY next=KEEP_YELLOW_ROUTE revive_buff=SKIP")
}
portalExitPendingV69 := false
portalBackPendingV74 := false
farmLastCombatTickV72 := A_TickCount
farmReviveV32 := false
deathlordRetryAtV31 := 0
farmLeftSkillV30 := -1, farmLeftPidV30 := 0, farmSetAttemptV30 := false
if (autoMonsterAttackOn)
coordCastCountV50 := 0, coordCastPendingV50 := false, coordCastLastRowV50 := 0
coordManualRowV59 := 0
userSelectedRowV351 := FarmStartRowV394()
mapRunResumeV210 := false,coordRunSelectedV210 := false
CoordRouteResetV16()
if (autoMonsterAttackOn && ScosOrderedRouteV234())
    coordRouteV16.yellow := 1
if (userSelectedRowV351>0)
{
    coordRouteV16.resumeRowV210 := userSelectedRowV351
    coordRouteV16.startAtYellowV367 := true
    farmStartChoiceV2 := false
    coordRouteV16.pid := backgroundPidV63
    coordRouteV16.startLevel := coordSavedV15[userSelectedRowV351].level
    coordRouteV16.portalArrivalPendingV307 := false
    coordRouteV16.yellow := userSelectedRowV351
    coordRunSelectedV210 := false
    mapRunResumeV210 := false
    PortalLogWriteV66("FARM_START_FROM_YELLOW row=" . userSelectedRowV351
        . " level=" . coordSavedV15[userSelectedRowV351].level)
}
coordMoveDoneV14 := false, coordMoveTriesV14 := 0, coordNoTargetSinceV14 := 0
if (autoMonsterAttackOn)
{
    PacketWatchStopV1()
    AutoMonsterAttackLogV2("START route=ACTIVE_SAVED_ROWS from=CURRENT_POSITION travel_attack_radius=CONFIGURED arrival=NEXT_LEG last_point=TOWN_SIG_STOP auto_log=MANUAL_ONLY")
}
else
    AutoMonsterAttackLogV2("STOP checkbox=OFF")
if (autoMonsterAttackOn)
{
    farmStartRetryV237 := false
    farmPickupBlockedV57 := false
    SetTimer, AutoMonsterAttackTimer, 250
    FarmPickupSyncV57(0,0,-1,true)
}
else
{
    SetTimer, AutoMonsterAttackTimer, Off
    FarmPickupSyncV57()
}
return

FarmStartWaitV237(reason)
{
    FarmRestartOnErrorV238(reason)
}

FarmStage3RequestV313(cause)
{
    global farmManualStoppedV2026
    if (farmManualStoppedV2026)
        return false
    global mapWorkflowV185,farmResetWatchEnabledV217,farmStage3PendingV237,farmRestartReasonV238
    if (!IsObject(mapWorkflowV185) || mapWorkflowV185.stage!=2)
        return false
    if ((cause="STUCK" && !farmResetWatchEnabledV217) || (cause!="COMPLETE" && cause!="STUCK"))
        return false
    FarmCombatYieldV237()
    PickupEnabledSetV71(false,true,false)
    farmRestartReasonV238 := cause
    FarmMapJournalFinishV940("GD2_" . cause)
    if (StageTwoArmV166(cause="STUCK" || ContinuousMapEnabledV168()))
    {
        farmStage3PendingV237 := false
        SetTimer, FarmStage3RetryTimerV237, Off
        MapStageSetV185(3)
        FonInfoPushV385("GĐ2 xong — chuyển GĐ3: Save & Exit và tạo phòng bằng DLL.")
    }
    else
    {
        farmStage3PendingV237 := true
        SetTimer, FarmStage3RetryTimerV237, 2000
        FonInfoPushV385("GĐ2 xong — đang chờ nhận cửa sổ game để bắt đầu GĐ3.")
    }
    return true
}

FarmRestartOnErrorV238(reason)
{
    global farmManualStoppedV2026
    if (farmManualStoppedV2026)
        return false
    global scosEntryV162,stageTwoV166,autoMonsterAttackOn,farmStartRetryV237
    if (IsObject(stageTwoV166))
    {
        stageTwoV166.phase := "RECOVER",stageTwoV166.until := A_TickCount+120000
        stageTwoV166.at := A_TickCount,stageTwoV166.retryAtV237 := A_TickCount+1000
        PortalLogWriteV66("STAGE3_RETRY_CURRENT_STEP reason=" . reason)
        return
    }
    if (IsObject(scosEntryV162))
    {
        scosEntryV162.until := A_TickCount+180000,scosEntryV162.retryAtV237 := A_TickCount+1000
        PortalLogWriteV66("STAGE1_RETRY_CURRENT_STEP phase=" . scosEntryV162.phase . " reason=" . reason . " stage3=OFF","STAGE1_RETRY",2000)
        ToolTipInfoV386("GĐ1: " . reason . " — giữ bước hiện tại.")
        SetTimer, RemoveToolTip, -4000
        return
    }
    FarmStartKeepV697(reason)
}

FarmErrorKeepV769(reason)
{
    global farmStartRetryV237,mapWorkflowV185
    if (!FarmControlRunningV186() && !IsObject(mapWorkflowV185))
        return false
    farmStartRetryV237 := true
    FarmRestartOnErrorV238(reason)
    FarmWatchStateV688()
    PortalLogWriteV66("FARM_ERROR_KEPT reason=" . reason . " run=ON context=PRESERVED next=EXISTING_RECOVERY","FARM_ERROR_KEPT",1000)
    return false
}

FarmStartKeepV697(reason)
{
    global
    farmStartRetryV237 := true
    FarmWatchStateV688()
    Gosub, MapControlButtonStatusV171
    FonInfoPushV385("[START] Vẫn bật; chờ phục hồi khi đứng yên: " . reason)
    PortalLogWriteV66("START_REQUEST_KEPT owner=" . farmControlOwnerV186 . " reason=" . reason)
    return true
}


FarmResumeTimerV70:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    SetTimer, FarmResumeTimerV70, Off
    return
}
if (!farmResumeArmedV70)
{
    SetTimer, FarmResumeTimerV70, Off
    return
}
if (!BackgroundValidV63() || autoMonsterAttackBusy || xRunning || zRunning || gameItemActionOwner!="")
    return
resumePidV70 := backgroundPidV63
resumeBaseV70 := D2GetModuleBaseV35(resumePidV70,"D2Client.dll")
resumeHV70 := resumeBaseV70 ? D2OpenProcess(resumePidV70) : 0
if (!resumeHV70)
    return
try
{
    resumePlayerV70 := D2ReadU32(resumeHV70,resumeBaseV70+0x11BBFC)
    resumePathV70 := resumePlayerV70 ? D2ReadU32(resumeHV70,resumePlayerV70+0x2C) : 0
    if (!MonsterBossProbeReadV1(resumeHV70,resumePathV70,0x20,resumePbV70))
        return
    resumeLevelV70 := CoordLevelV14(resumeHV70,NumGet(resumePbV70,0x1C,"UInt"))
    resumeModeV70 := D2ReadU32(resumeHV70,resumePlayerV70+0x10)
    if (autoMonsterAttackOn && outsideLevelV22!="" && resumeLevelV70=outsideLevelV22)
        farmResumeOutsideV70 := true
    if (!farmResumeOutsideV70 || townLevelV22="" || resumeLevelV70!=townLevelV22
        || (resumeModeV70!=1 && resumeModeV70!=5))
        return
    farmResumeOutsideV70 := false
    if (!autoMonsterAttackOn)
    {
        farmResumeInternalV70 := true
        autoMonsterAttackOn := true
        try
            Gosub, AutoMonsterAttackToggle
        finally
            farmResumeInternalV70 := false
    }
    if (autoMonsterAttackOn && !IsObject(farmReviveV32))
        reviveBuffPendingV34 := true
    PortalLogWriteV66("FARM_TOWN_RECOVER auto=" . autoMonsterAttackOn . " next=TOWN_BUFF_THEN_PORTAL_THEN_FARM")
}
finally
    DllCall("CloseHandle","Ptr",resumeHV70)
return

AutoMonsterAttackTimer:
if (farmUserPausedV2026)
    return
if (farmManualStoppedV2026)
{
    SetTimer, AutoMonsterAttackTimer, Off
    return
}
; Revive is dispatched by the one Farm timer. START-while-dead uses this timer too.
if (IsObject(farmDeadStartV695))
{
    FarmDeadStartTickV695()
    return
}
; On death, Esc is always handled before buff, pickup, movement or fighting.
if (FarmReviveDeadPriorityV62())
    return
; Timer danh khong xen vao qua trinh da ban giao nhat.
if (FarmControlRunningV186() && IsObject(farmCenterCycleV741)
    && farmCenterCycleV741.phase="PICKUP_BUSY")
    return
if (A_TickCount<farmErrorRetryAtV740 || RemoteThreadBusyV740(D2GetActiveGamePidV95()))
    return
try
{
if (buffSequenceRunningV555 || farmBuffExclusiveV621)
    return
pidCheck := D2GetActiveGamePidV95()
if (pidCheck)
{
    currentMapLevel := RoomRecordLevelV259(pidCheck)
    CheckAndRestoreBackgroundFarm(pidCheck, currentMapLevel)
}
	
if (!autoMonsterAttackOn || autoMonsterAttackBusy)
{
    if (!autoMonsterAttackOn)
        FarmAttackHoldReleaseV15()
    return
}
if (farmControlOwnerV186="CAIN" && !IsObject(scosEntryV162)
    && !IsObject(stageTwoV166) && !IsObject(sigTownV148) && !IsObject(farmReviveV32))
{
    global cainAttachRetryAtV379
    if (!cainAttachRetryAtV379 || A_TickCount-cainAttachRetryAtV379>=1000)
    {
        cainAttachRetryAtV379 := A_TickCount
        CainStage2AttachV379()
    }
    return
}
if (petLearnOnV12 || packetWatchArmedV1 || zRunning || xRunning || gameItemActionOwner!="" || !IsGameActive())
{
    FarmAttackHoldReleaseV15()
    if (petLearnOnV12 || packetWatchArmedV1 || zRunning || xRunning || !IsGameActive())
    {
        monsterChaseV44 := false
        if (IsObject(coordRouteV16))
            coordRouteV16.stuckProbe := false
    }
    AutoMonsterAttackLogV2("WAIT active=" . IsGameActive() . " capture=" . packetWatchArmedV1
        . " buff=" . (zRunning || xRunning) . " owner=" . gameItemActionOwner, true)
    return
}
autoMonsterAttackBusy := true
farmAttackUsedV15 := false
try
    AutoMonsterAttackScanV1()
catch e
{
    if (IsObject(scosEntryV162) && scosEntryV162.map="BO")
        BOErrorReportV463(scosEntryV162,e.Message,"FARM line=" . e.Line . " function=" . e.What)
    else
        FarmRuntimeErrorV740(e)
}
finally
{
    autoMonsterAttackBusy := false
    if (!farmAttackUsedV15 && !FarmAttackKeepV15())
        FarmAttackHoldReleaseV15()
}
}
catch e
    FarmRuntimeErrorV740(e)
return

AutoMonsterAttackViewV1(h, base, hwnd, playerPath)
{
    if (!MonsterBossProbeReadV1(h, base+0xDBC48, 8, sizeBuf)
        || !MonsterBossProbeReadV1(h, base+0x11995C, 8, offsetBuf)
        || !MonsterBossProbeReadV1(h, playerPath, 0x20, playerBuf))
        return false
    gw := NumGet(sizeBuf,0,"UInt"), gh := NumGet(sizeBuf,4,"UInt")
    ox := NumGet(offsetBuf,4,"Int"), oy := NumGet(offsetBuf,0,"Int")
    if (gw<320 || gh<240 || gw>8192 || gh>8192)
        return false
    playerSX := NumGet(playerBuf,8,"Int")-ox
    playerSY := NumGet(playerBuf,12,"Int")-oy
    if (Abs(playerSX-gw/2)>80 || playerSY<gh/4 || playerSY>gh*3/4)
        return false
    VarSetCapacity(rect,16,0)
    if (!DllCall("GetClientRect","Ptr",hwnd,"Ptr",&rect))
        return false
    cw := NumGet(rect,8,"Int"), ch := NumGet(rect,12,"Int")
    if (cw<320 || ch<240)
        return false
    return {gw:gw,gh:gh,cw:cw,ch:ch,ox:ox,oy:oy}
}

AutoMonsterAttackPointV1(ByRef pb, view)
{
    sx := NumGet(pb,8,"Int")-view.ox
    sy := NumGet(pb,12,"Int")-view.oy-8
    if (sx<16 || sx>view.gw-16 || sy<32 || sy>view.gh-64)
        return false
    return {x:Round(sx*view.cw/view.gw),y:Round(sy*view.ch/view.gh)}
}

AutoMonsterAttackScanV1(infoOnly := false)
{
    global farmManualStoppedV2026
    if (farmManualStoppedV2026 && !infoOnly)
        return false
    routePointsV724 := FarmRoutePointsV724()
    if (!infoOnly && VizBossActiveV687())
        return false
    if (!infoOnly && FarmCommonRouteActiveV3() && !Stage2FightEnabledV9())
        return false

    global roomExploreV89,portalBuffV85,coordCastPendingV50
    global autoMonsterAttackOn,zRunning,xRunning,gameItemActionOwner,packetWatchArmedV1,farmLastCombatTickV72
    global monsterLockUntilDeadV145,viewIdV54,viewPosV291,farmResetWatchEnabledV217,monsterLockRoomSecV622
    global farmControlOwnerV186,stage2FlowV380,QCastOn,cycleOn,farmCombatAreaV590,farmItemLockV625,farmFightLockV626
    global pickupImageOn,pickupGroupActiveV26,pickupRadius,pickupRoundResetV1
    global cainNoFightV361,cainPauseFarmV361,cainBossUidV361,cainBossKilledV361,cainBossClassV361
    global scosEntryV162,farmReviveV32
    global currentAttackUidV520,currentAttackClassV520,currentAttackX_V520,currentAttackY_V520,currentAttackAtV520,currentAttackDistV523
    global monsterExcludeClassesV11,coordNoTargetSinceV14,coordRouteV16,monsterCombatUidV45,monsterRadiusV48,monsterChaseV44,combatMoveLastV48,monsterRoadAreaV51,chaseCheckSecV9
    global farmScanListV682,farmScanSelectedV682,farmGroundItemCountV710
    global farmCenterCycleV741,farmScanLimitV771
    static cachePid := 0, cacheBase := 0
    static nonBossBurstCountsV1 := {}
    if (cainPauseFarmV361 && !infoOnly)
        return
    pid := D2GetActiveGamePidV95()
    if (!pid)
    {
        AutoMonsterAttackLogV2("SKIP reason=NO_ACTIVE_GAME_PID", true)
        return
    }
    hwnd := GameTargetHwndV63()
    if (pid!=cachePid || !cacheBase)
    {
        cachePid := pid
        cacheBase := D2GetModuleBaseV35(pid,"D2Client.dll")
    }
    h := cacheBase ? DllCall("OpenProcess","UInt",0x0410,"Int",0,"UInt",pid,"Ptr") : 0
    if (!h)
    {
        AutoMonsterAttackLogV2("SKIP reason=OPEN_READ_PROCESS base=" . cacheBase . " error=" . A_LastError, true)
        return
    }
    previousAreaV590 := farmCombatAreaV590
    try
    {
        player := D2ReadU32(h,cacheBase+0x11BBFC)
        playerPath := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,playerPath,0x20,pb))
        {
            AutoMonsterAttackLogV2("SKIP reason=PLAYER_PATH_READ", true)
            return
        }
        playerMode := D2ReadU32(h,player+0x10)
        liveStage2LevelV381 := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        if (!infoOnly)
            PortalLogWriteV66("COMBAT_SCAN_CONTEXT level=" . liveStage2LevelV381 . " owner=" . farmControlOwnerV186
                . " fight=" . Stage2FightEnabledV9() . " no_fight=" . cainNoFightV361 . " pause=" . cainPauseFarmV361
                . " recovery=" . IsObject(coordRouteV16.escapeV84) . " cast4=" . QCastOn . " cycle6=" . cycleOn,"COMBAT_SCAN_CONTEXT",1000)
        if (!infoOnly && BOCommonActiveV444(pid))
        {
            observedRoomV462 := D2ReadU32(h,NumGet(pb,0x1C,"UInt")+0x10)
            if (observedRoomV462)
                BossSearchRoomsObserveV432(stage2FlowV380.searchV430,observedRoomV462)
        }

        ; Single revive dispatcher inside the normal Farm scan.
        if (!infoOnly && FarmReviveTickV32(h,player,pb,pid,hwnd,cacheBase,playerPath,playerMode))
            return
        ; ITEM_ESCAPE_20261029: continue recovery every farm tick, before
        ; route-center / combat can dispatch the old item destination.
        if (!infoOnly && FarmItemEscapeActiveV20261029(pid))
        {
            escapePhaseV20261029 := farmItemLockV625.returnGoalV655.routeV392.escapeV84.phase
            FarmItemReturnV648(h,pb,pid,liveStage2LevelV381
                ,NumGet(pb,2,"UShort"),NumGet(pb,6,"UShort"))
            PortalLogWriteV66("FARM_ITEM_ESCAPE_EXCLUSIVE_TICK pid=" . pid
                . " phase_before=" . escapePhaseV20261029
                . " still_active=" . (FarmItemEscapeActiveV20261029(pid) ? 1 : 0)
                ,"FARM_ITEM_ESCAPE_EXCLUSIVE_TICK",1000)
            return
        }
        if (!infoOnly)
            FarmParentBeginV767(pid,liveStage2LevelV381)
        if (!infoOnly && FarmCenterCheckV741(h,player,pid,true))
            return

        if (!infoOnly && playerMode!=0 && playerMode!=17
            && !FarmReviveTownLevelV295(liveStage2LevelV381)
            && !Stage2MapWaitV381(pid,liveStage2LevelV381))
        {
            if (!stage2WaitReportedV385)
            {
                stage2WaitReportedV385 := 1
                FonInfoPushV385("[GĐ2] Chưa có lộ trình đang nạp cho level=" . liveStage2LevelV381)
            }
            return
        }
        stage2WaitReportedV385 := 0

        itemDoneV380 := !infoOnly && Stage2ItemCheckV380(h,player,pid)
        if (!infoOnly && CainQuestReturnV369(h,player,pid))
            return
        if (itemDoneV380)
            return
        cainGd4ActiveV376 := FarmItemFlowRunningV427(pid,liveStage2LevelV381)
        if (!infoOnly && FarmStage2DoneCurrentV372(pid) && !cainGd4ActiveV376)
            return

        if (!infoOnly && FarmMapAltTickV199(h,player,pb,pid))
            return
        if (!infoOnly)
            RoomStandLogV114(h,player,pb,pid,playerMode)
        if (!infoOnly && IsObject(roomExploreV89) && playerMode!=0 && playerMode!=17)
        {
            if (PortalExitTickV69(h,player,pb,pid))
                return
            if (IsObject(portalBuffV85) && FarmPortalBuffTickV85(h,player,pid))
                return
            if (!coordCastPendingV50 && AutoBuffEnsureV513(h,player,pid))
                return
        }
        if (!infoOnly && Stage2FightEnabledV9() && !ScosOrderedRouteV234() && RoomExploreTickV89(h,player,pb,pid,playerMode))
            return
        if (playerMode=0 || playerMode=17)
            return
        if (!infoOnly && BossSearchActiveV430(pid,liveStage2LevelV381) && farmControlOwnerV186!="BO")
        {
            invV430 := D2ReadU32(h,player+0x60)
            cursorV430 := invV430 ? PickupCursorV4(h,invV430) : false
            if (!IsObject(cursorV430) || cursorV430.unit)
                return
            if (StateBuffTickV17(h,player,pb,pid) || CombatRecoverTickV48(h,pb,pid,false))
                return
            if (Stage2FightEnabledV9())
                BossSearchTickV430(h,player,pb,pid)
            else if (Stage2PickupEnabledV9())
                FarmPickupFirstV75()
            return
        }
        px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
        CoordDisplayPositionV1(px,py)
        room := NumGet(pb,0x1C,"UInt")
        if (!room)
        {
            AutoMonsterAttackLogV2("SKIP reason=ROOM_NOT_READY", true)
            return
        }
        if (!infoOnly && FarmStandResetTickV246(px,py,CoordLevelV14(h,room),pid))
            return
        inv := D2ReadU32(h,player+0x60)
        cursor := inv ? PickupCursorV4(h,inv) : -1
        if (!IsObject(cursor) || cursor.unit)
        {
            AutoMonsterAttackLogV2("SKIP reason=CURSOR_CHECK valid=" . IsObject(cursor) . " held=" . (IsObject(cursor) ? cursor.unit : -1), true)
            return
        }
        if (!infoOnly && BOFinalRouteActiveV451(pid))
        {
            BOFinalHuntTickV454(h,player,pb,pid)
            return
        }
        if (!infoOnly && RoomCoordinateModeV116() && !CainHuntLockedV404(pid,liveStage2LevelV381))
        {
            CoordRouteObserveV18(h,pb,pid)
            if (playerMode=4 || playerMode=7 || playerMode=8 || playerMode=9 || playerMode=10 || playerMode=11 || playerMode=12 || playerMode=13 || playerMode=14 || playerMode=15 || playerMode=18)
                coordRouteV16.lastBattleV118 := A_TickCount, coordRouteV16.stuckProbe := false
        }

        if (!infoOnly && !Stage2FightEnabledV9())
        {
            monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
            CoordRouteObserveV18(h,pb,pid)
            if (Stage2PickupEnabledV9() && FarmPickupFirstV75())
                return
            if (!CoordStuckTickV84(h,pb,pid))
                CoordMoveWhenClearV14(h,pb,pid)
            return
        }

        if (!infoOnly && CainHuntLockedV404(pid,liveStage2LevelV381))
        {
            if (StateBuffTickV17(h,player,pb,pid))
                return
            if (CombatRecoverTickV48(h,pb,pid,false))
                return
            if (CainHuntBossTickV403(h,player,pb,pid))
                return
        }
        if (!infoOnly && farmControlOwnerV186="LIB" && LibFarmLevelV292(CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))))
        {
            CoordRouteObserveV18(h,pb,pid)
            if (IsObject(coordRouteV16) && routePointsV724.Length()>0
                && coordRouteV16.phase="DONE" && coordRouteV16.anchor>=routePointsV724.Length())
            {
                PortalLogWriteV66("LIB_ROUTE_END last_row=" . coordRouteV16.anchor . " next=TOWN_SIG_THEN_STAGE3")
                MapStage2RouteFinishV185()
                return
            }
        }

        if (!infoOnly && cainNoFightV361)
        {
            if (StateBuffTickV17(h,player,pb,pid))
                return
            monsterCombatUidV45 := 0,monsterRoadAreaV51 := false
            CoordRouteObserveV18(h,pb,pid)
            if (!CoordStuckTickV84(h,pb,pid))
                CoordMoveWhenClearV14(h,pb,pid)
            return
        }
        if (!infoOnly && StateBuffTickV17(h,player,pb,pid))
            return
        if (!infoOnly && playerMode!=0 && playerMode!=17 && !IsObject(farmReviveV32)
            && !FarmReviveTownLevelV295(CoordLevelV14(h,NumGet(pb,0x1C,"UInt")))
            && CombatRecoverTickV48(h,pb,pid,false))
            return
        if (!infoOnly && CainHuntBossTickV403(h,player,pb,pid))
            return
        if (!infoOnly)
        {
            CoordRouteObserveV18(h,pb,pid)
        }


        if (!infoOnly && !IsObject(roomExploreV89) && PortalExitTickV69(h,player,pb,pid))
            return

        if (!infoOnly && BOCommonActiveV444(pid))
        {
            BOCombatRouteRebaseV488(pb,stage2FlowV380.searchV430)
            BOItemCenterUpdateV447(h,player,pb,pid)
        }
        scosScanV240 := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))=270
        scanRadiusV20 := MonsterScanRadiusV20(liveStage2LevelV381)
        if (IsObject(farmFightLockV626) && (farmFightLockV626.pid!=pid
            || farmFightLockV626.player!=player || farmFightLockV626.level!=liveStage2LevelV381))
            farmFightLockV626 := false
        if (IsObject(farmItemLockV625) && (farmItemLockV625.pid!=pid
            || farmItemLockV625.player!=player || farmItemLockV625.level!=liveStage2LevelV381))
            farmItemLockV625 := false
        if (!pickupImageOn || !Stage2PickupEnabledV9())
            farmItemLockV625 := false
        if (!infoOnly)
            farmGroundItemCountV710 := 0
        itemScanV902 := FarmFlowScanGroundItemsV902(h,player,pid,room,liveStage2LevelV381,px,py,infoOnly)
        itemOnRoad := itemScanV902.found,itemCx := itemScanV902.x,itemCy := itemScanV902.y
        attackArea := MonsterAttackAreaV48(h,pb)
        if (!infoOnly && !BOCommonActiveV444(pid) && !itemOnRoad
            && !FarmCenterPolicyV741(pid,liveStage2LevelV381))
        {
            savedAreaV627 := FarmRouteCombatAreaV627(pid,player,liveStage2LevelV381)
            if (IsObject(savedAreaV627))
                attackArea := savedAreaV627
        }
        playerCycleV741 := !infoOnly && FarmCenterPolicyV741(pid,liveStage2LevelV381)
        ; Farm B->C chi danh tai B: tin hieu item KHONG tao tam danh moi.
        ; ITEM_MOVE/PICKUP duoc FarmCenterCheck xu ly truoc bo quet quai.
        if (playerCycleV741)
        {
            ; Tai diem: tam quet = toa do diem. Gap quai tren duong:
            ; tam quet = vi tri nhan vat LUC PHAT HIEN, giu den khi danh sach.
            scanRadiusV20 := Max(1,MonsterRadiusGetV239())
            centerBCV910 := FarmCenterPendingV741(pid) ? farmCenterCycleV741 : FarmCenterCaptureV741(pid)
            roadCenterV2026 := IsObject(centerBCV910) && (centerBCV910.phase="ROAD_ATTACK"
                || (centerBCV910.phase="ATTACK" && centerBCV910.dispatchOriginV1190="ROAD_ATTACK"))
            centerXV910 := roadCenterV2026 ? centerBCV910.roadX_V2026
                : IsObject(centerBCV910) ? centerBCV910.x : px
            centerYV910 := roadCenterV2026 ? centerBCV910.roadY_V2026
                : IsObject(centerBCV910) ? centerBCV910.y : py
            attackArea := {x:centerXV910,y:centerYV910,radiusSq:scanRadiusV20**2
                ,source:(roadCenterV2026 ? "ROAD_PLAYER_CENTER" : "ROUTE_POINT_CENTER")
                ,row:(IsObject(centerBCV910) ? centerBCV910.row : 0)}
        }
        farmCombatAreaV590 := {pid:pid,level:liveStage2LevelV381,area:attackArea}

        rooms := (playerCycleV741 || itemOnRoad || IsObject(farmFightLockV626)) ? MonsterLoadedRoomsV20(h,room)
            : RoomFarmBoundaryV235() ? [room] : MonsterLoadedRoomsV20(h,room)
        seenRooms := {}, seenUnits := {}
        target := false, lockedTarget := false, bestPriorityV221 := false
        bestDist := 0x7FFFFFFF, total := 0, start := A_TickCount
        scanListV682 := []
        combatScanCompleteV626 := true
        ; V947: thong ke quai nam sat/duoi chan (khoang cach <= 2 o),
        ; KHONG bo qua quai trung toa do. Bao ly do neu loc khoi danh sach.
        nearFootSeenV947 := 0,nearFootEligibleV947 := 0
        nearFootClassV947 := 0,nearFootRetryV947 := 0
        nearFootAreaV947 := 0,nearFootRoadV947 := 0
        monsterPathErrorV947 := 0
        boRawNearV446 := 0,boExcludedNearV446 := 0,boRetryNearV446 := 0
        for _, r in rooms
        {
            if (seenRooms.HasKey(r))
                continue
            seenRooms[r] := true
            if (!MonsterBossProbeReadV1(h,r+0x74,4,combatHeadV626))
            {
                combatScanCompleteV626 := false
                continue
            }
            u := NumGet(combatHeadV626,0,"UInt")
            Loop, 1024
            {
                if (!u || seenUnits.HasKey(u) || total>=2048 || A_TickCount-start>150)
                    break
                seenUnits[u] := true
                total++
                if (!MonsterBossProbeReadV1(h,u,0xEC,ub))
                {
                    combatScanCompleteV626 := false
                    break
                }
                next := NumGet(ub,0xE8,"UInt")
                typ := NumGet(ub,0,"UInt"), mode := NumGet(ub,0x10,"UInt")
                uid := NumGet(ub,0x0C,"UInt"), path := NumGet(ub,0x2C,"UInt")
                if (typ=1 && uid && mode!=0 && mode!=12 && !MonsterBossProbeReadV1(h,path,0x20,mb))
                {
                    monsterPathErrorV947++
                    combatScanCompleteV626 := false
                    u := next
                    continue
                }
                if (typ=1 && uid && mode!=0 && mode!=12)
                {
                    x := NumGet(mb,2,"UShort"), y := NumGet(mb,6,"UShort")
                    dist := (x-px)*(x-px)+(y-py)*(y-py)
                    classV11 := NumGet(ub,4,"UInt")
                    excludedV11 := MonsterClassExcludedV11(classV11,h,u)
                    if (dist<=4)
                    {
                        nearFootSeenV947++
                        if (excludedV11)
                            nearFootClassV947++
                        else if (MonsterRetryExcludedV44(uid,x,y,CoordLevelV14(h,NumGet(mb,0x1C,"UInt")),pid))
                            nearFootRetryV947++
                        else if (!MonsterInsideAreaV48(x,y,attackArea))
                            nearFootAreaV947++
                        else if (!MonsterRoadEligibleV52(px,py,x,y))
                            nearFootRoadV947++
                        else
                            nearFootEligibleV947++
                    }
                    if (!infoOnly && BOCommonActiveV444(pid) && MonsterInsideAreaV48(x,y,attackArea))
                    {
                        boRawNearV446++
                        if (excludedV11)
                            boExcludedNearV446++
                        retryNearV446 := MonsterRetryExcludedV44(uid,x,y,CoordLevelV14(h,NumGet(mb,0x1C,"UInt")),pid)
                        if (retryNearV446)
                            boRetryNearV446++
                        PortalLogWriteV66("BO_NEAR_MONSTER uid=" . uid . " class=" . classV11
                            . " distance=" . Round(Sqrt(dist),2) . " excluded_class=" . excludedV11
                            . " retry_excluded=" . retryNearV446 . " mode=" . mode,"BO_NEAR_MONSTER_" . uid,1000)
                    }
                    if ((playerCycleV741 || itemOnRoad || !RoomFarmBoundaryV235() || RoomMonsterSameRoomV113(h,mb,pb))
                        && !excludedV11 && !MonsterRetryExcludedV44(uid,x,y,CoordLevelV14(h,NumGet(mb,0x1C,"UInt")),pid)
                        && MonsterInsideAreaV48(x,y,attackArea)
                        && (MonsterRoadEligibleV52(px,py,x,y)
                            || (uid=monsterCombatUidV45 && BossPriorityHasV221(classV11))))
                    {
                        candidate := {unit:u,uid:uid,path:path,dist:dist,x:x,y:y,level:CoordLevelV14(h,NumGet(mb,0x1C,"UInt")),priority:BossPriorityHasV221(classV11),cls:classV11}
                        if (!infoOnly)
                            scanListV682.Push(candidate)
                        if (monsterCombatUidV45 && uid=monsterCombatUidV45)
                            lockedTarget := candidate
                        rank := MonsterRoadRankV52(px,py,x,y,dist)
                        if ((candidate.priority && !bestPriorityV221) || (candidate.priority=bestPriorityV221 && rank<bestDist))
                            bestDist := rank, target := candidate,bestPriorityV221 := candidate.priority
                    }
                }
                u := next
                if (A_Index=1024 && u)
                    combatScanCompleteV626 := false
            }
            if (total>=2048 || A_TickCount-start>80)
            {
                combatScanCompleteV626 := false
                break
            }
        }
        combatScanCompleteV626 := FarmScanCompleteV742(combatScanCompleteV626,total,A_TickCount-start)
        if (infoOnly)
            return
        farmScanListV682 := scanListV682
        farmScanSelectedV682 := IsObject(target) ? target.uid : 0
        if (FarmCenterPendingV741(pid) && (IsObject(target) || !combatScanCompleteV626))
        {
            ; Co quai hoac luot quet khong day du: khong dem tiep chuoi quet rong.
            farmCenterCycleV741.attackEmptyCountV906 := 0
            farmCenterCycleV741.attackEmptyAtV906 := 0
        }
        parentInfoV771 := FarmCenterPendingV741(pid) ? farmCenterCycleV741 : false
                if (IsObject(parentInfoV771))
        {
            rowB := parentInfoV771.row
            rowC := IsObject(parentInfoV771.forwardV756) ? parentInfoV771.forwardV756.row : rowB + 1
            parentInfoTextV771 := (parentInfoV771.phase="ATTACK_FIRST" || parentInfoV771.phase="ATTACK_MORE" || parentInfoV771.phase="ATTACK")
                ? (IsObject(target) ? "ĐANG ĐÁNH | quét quái không giới hạn" : "ĐANG TÌM QUÁI | quét tiếp đến khi hết mục tiêu")
                : parentInfoV771.phase="ROAD_ATTACK" ? "QUÁI CẢN ĐƯỜNG | DỪNG ĐI, ĐÁNH QUANH NHÂN VẬT"
                : parentInfoV771.phase="ITEM_MOVE" ? "ĐANG ĐI VỀ VẬT PHẨM / XÉT KẸT"
                : parentInfoV771.phase="ITEM_ATTACK" ? "ĐANG ĐÁNH QUÁI QUANH VẬT PHẨM BK/2"
                : parentInfoV771.phase="PICKUP" ? "ĐÃ SẠCH QUÁI QUANH ĐỒ / CHỜ NHẶT"
                : parentInfoV771.phase="PICKUP_BUSY" ? "ĐANG NHẶT / CẤT VẬT PHẨM"
                : parentInfoV771.phase="CHECK" ? "ĐANG KIỂM TRA VỊ TRÍ DÒNG " . rowB
                : parentInfoV771.phase="RETURN" ? "ĐANG ĐIỀU CHỈNH VỊ TRÍ DÒNG " . rowB . " / " . rowC
                : parentInfoV771.phase="MOVE" ? "ĐANG CHUYỂN SANG DÒNG TIẾP THEO " . rowC
                : "QUY TRÌNH DÒNG " . rowB . " → " . rowC . ": " . parentInfoV771.phase
        }
        else
            parentInfoTextV771 := IsObject(target) ? "ĐÃ CHỌN MỤC TIÊU ĐÁNH" : "CHƯA CÓ QUÁI HỢP LỆ TRONG BK"
        FarmCombatViewV624(pid,target,parentInfoTextV771)
        ; V947: ghi DUNG MOI LAN QUET THUC TE, KHONG gioi han 1 lan/giay.
        ; Nhip timer la 250ms nhung khi busy thi khong co quet: log chi ghi cac lan THUC SU quet.
        scanPhaseV947 := IsObject(parentInfoV771) ? parentInfoV771.phase : "OTHER"
        scanRowV947 := IsObject(parentInfoV771) ? parentInfoV771.row : 0
        scanEmptyV947 := IsObject(parentInfoV771) ? parentInfoV771.attackEmptyCountV906 : 0
        scanDurationV947 := A_TickCount-start
        PortalLogWriteV66("COMBAT_SCAN_RESULT level=" . liveStage2LevelV381 . " row=" . scanRowV947
            . " phase=" . scanPhaseV947 . " rooms=" . seenRooms.Count()
            . " units=" . total . " candidates=" . scanListV682.Length()
            . " complete=" . combatScanCompleteV626 . " scan_ms=" . scanDurationV947
            . " area=" . attackArea.source . " center=" . attackArea.x . "," . attackArea.y
            . " player=" . px . "," . py . " empty_count=" . scanEmptyV947
            . " near_foot=" . nearFootSeenV947 . " foot_eligible=" . nearFootEligibleV947
            . " foot_skip_class=" . nearFootClassV947 . " foot_skip_retry=" . nearFootRetryV947
            . " foot_skip_area=" . nearFootAreaV947 . " foot_skip_road=" . nearFootRoadV947
            . " path_read_fail=" . monsterPathErrorV947
            . " target_uid=" . (IsObject(target) ? target.uid : 0)
            . " target_class=" . (IsObject(target) ? target.cls : 0), "COMBAT_SCAN_RESULT",0)
        ; Check the player-centered radius before treating an empty waypoint area as clear.
        if (playerCycleV741 && combatScanCompleteV626 && !IsObject(target)
            && IsObject(centerBCV910)
            && (centerBCV910.phase="ATTACK_FIRST" || centerBCV910.phase="ATTACK_MORE"))
        {
            nearFootScanV2026 := FarmApproachScanV722(h,player,pid,true)
            if (IsObject(nearFootScanV2026) && nearFootScanV2026.complete
                && IsObject(nearFootScanV2026.target))
            {
                centerBCV910.roadX_V2026 := nearFootScanV2026.x
                centerBCV910.roadY_V2026 := nearFootScanV2026.y
                centerBCV910.phase := "ROAD_ATTACK"
                centerBCV910.attackEmptyCountV906 := 0
                centerBCV910.attackEmptyAtV906 := 0
                centerBCV910.attacked := false
                MovementCtrlSetV78(false,0,"FarmRoadPlayerScanV2026")
                PortalLogWriteV66("BC_ROAD_ATTACK_PLAYER_SCAN row=" . centerBCV910.row
                    . " center=" . nearFootScanV2026.x . "," . nearFootScanV2026.y
                    . " uid=" . nearFootScanV2026.target.uid
                    . " next=PLAYER_CENTERED_COMBAT")
                return
            }
        }
        if (combatScanCompleteV626 && !IsObject(target) && FarmParentAttackEmptyV767(pid))
            return
        incomingV711 := MonsterStuckIncomingV711(h,pid,liveStage2LevelV381,scanListV682,px,py)
        if (IsObject(incomingV711))
        {
            target := incomingV711,lockedTarget := incomingV711
            farmScanSelectedV682 := target.uid
        }
        if (BOCommonActiveV444(pid))
        {
            if (monsterCombatUidV45 && IsObject(lockedTarget))
                target := lockedTarget
            boScanCompleteV446 := combatScanCompleteV626
            BOCommonPublishV446(pid,target,boScanCompleteV446,px,py)
            PortalLogWriteV66("BO_SHARED_SCAN radius=" . scanRadiusV20 . " raw_near=" . boRawNearV446
                . " excluded_near=" . boExcludedNearV446 . " retry_near=" . boRetryNearV446
                . " target_uid=" . (IsObject(target) ? target.uid : 0) . " complete=" . boScanCompleteV446
                . " engine=COMMON_SCOS_CAIN","BO_SHARED_SCAN",1000)
            if (IsObject(target))
            {
                boCombatV479 := stage2FlowV380.searchV430
                monsterCombatUidV45 := target.uid
                if (BOCombatStopWalkV482(h,player,pb,boCombatV479))
                    return
                BossSearchHoldAttackV436(h,player,pb,boCombatV479,target)
                PortalLogWriteV66("BO_COMBAT_FIRST uid=" . target.uid . " class=" . target.cls
                    . " distance=" . Round(Sqrt(target.dist),2) . " movement=PAUSED pickup=WAIT", "BO_COMBAT_FIRST",1000)
                return
            }
            if (!boScanCompleteV446)
                return
            if (!IsObject(target))
            {
                if (BOPickupPriorityV421(h,player,pb,pid))
                    return
                boCombatV479 := stage2FlowV380.searchV430
                if (boCombatV479.afterCombatPickupV486)
                {
                    if (BOPickupPriorityV421(h,player,pb,pid))
                        return
                    if (BOCommonPickupGateV444(h,player,pb,pid)="WAIT")
                        return
                    boCombatV479.itemCenterV447 := false
                    BOCombatRouteRebaseV488(pb,boCombatV479,true)
                    boCombatV479.afterCombatPickupV486 := false,boCombatV479.fightOriginV488 := false
                    PortalLogWriteV66("BO_AFTER_COMBAT_PICKUP_DONE next=NEW_ZIGZAG_FROM_LIVE_POSITION")
                }
                BOCommonMoveV444(h,pb,pid)
                return
            }
        }

        if (playerCycleV741 && !IsObject(target) && combatScanCompleteV626)
        {
            if (!FarmCombatResumeV742(pid))
                return
        }
        if (!itemOnRoad && !IsObject(target) && IsObject(farmFightLockV626))
        {
            if (FarmRouteCombatClearV627(h,player,pid,pb))
                return
        }
        combatLocked := false
        if (monsterCombatUidV45 && !playerCycleV741)
        {
            if (IsObject(lockedTarget))
            {
                if (MonsterLockEligibleV308(lockedTarget.cls))
                    target := lockedTarget, combatLocked := true
                else
                    monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
            }
            else
            {
                if (!combatScanCompleteV626)
                    return
                AutoMonsterAttackLogV2("COMBAT_UNLOCK uid=" . monsterCombatUidV45 . " reason=TARGET_GONE_EXCLUDED_OR_OUTSIDE_RADIUS")
                monsterCombatUidV45 := 0, monsterRoadAreaV51 := false
            }
        }
        if (farmControlOwnerV186="CAIN" && cainBossUidV361 && !cainBossKilledV361
            && combatScanCompleteV626)
        {
            bossSeen := false
            for _,r in rooms
            {
                uu := D2ReadU32(h,r+0x74)
                Loop, 4096
                {
                    if (!uu)
                        break
                    if (D2ReadU32(h,uu)=1 && D2ReadU32(h,uu+0x0C)=cainBossUidV361)
                    {
                        mm := D2ReadU32(h,uu+0x10)
                        if (mm!=0 && mm!=12)
                            bossSeen := true
                        break
                    }
                    nn := D2ReadU32(h,uu+0xE8)
                    if (nn=uu)
                        break
                    uu := nn
                }
                if (bossSeen)
                    break
            }
            if (!bossSeen)
            {
                cainBossKilledV361 := true
                AutoMonsterAttackLogV2("CAIN_BOSS_KILLED uid=" . cainBossUidV361 . " class=" . cainBossClassV361 . " next=OPEN_TOWN_PORTAL")
            }
        }
        if (IsObject(target) || !combatScanCompleteV626)
            farmLastCombatTickV72 := A_TickCount
        if (CombatLowHPAlternateV299(h,pb,pid,target))
        {
            PortalLogWriteV66("COMBAT_SKIP reason=HP_ALTERNATE target_uid=" . target.uid,"COMBAT_POST_SCAN_SKIP",1000)
            return
        }
        if (combatScanCompleteV626 && !IsObject(target))
        {
            if (CoordCastTickV50(h,player,pid))
                return
        }
        if (!ScosOrderedRouteV234() && IsObject(roomExploreV89) && IsObject(target) && target.dist>25)
        {
            monsterCombatUidV45 := 0, monsterRoadAreaV51 := false, monsterChaseV44 := false
            coordRouteV16.bypass := false
            coordNoTargetSinceV14 := A_TickCount-250
            AutoMonsterAttackLogV2("ROOM_APPROACH_MONSTER uid=" . target.uid . " distance=" . Round(Sqrt(target.dist),2)
                . " attack_distance=5 action=WALK_TO_NEAREST_MONSTER",true)
            CoordMoveWhenClearV14(h,pb,pid)
            return
        }
        travelling := IsObject(coordRouteV16) && coordRouteV16.phase="NEXT"
        engageLimitSq := travelling ? scanRadiusV20*scanRadiusV20 : 0
        if (itemOnRoad || IsObject(farmFightLockV626))
            engageLimitSq := 8589672450
                if (!IsObject(target) || (travelling && !scosScanV240 && !combatLocked && target.dist>engageLimitSq))
        {
            if (!IsObject(target) && Stage2PickupEnabledV9())
            {
                if (!infoOnly && itemOnRoad && FarmItemReturnV648(h,pb,pid,liveStage2LevelV381,px,py))
                    return
                if (FarmPickupFirstV75())
                    return
            }
            if (itemOnRoad)
                return
            if (IsObject(target))
                AutoMonsterAttackLogV2("TEST_CONTINUE_MOVE reason=NEAREST_MONSTER_TOO_FAR uid=" . target.uid
                    . " distance=" . Round(Sqrt(target.dist),2) . " engage_radius=CONFIGURED phase=TRAVEL priority=MOVE",true)
            else
                AutoMonsterAttackLogV2("SCAN reason=NO_LIVE_TARGET rooms=" . seenRooms.Count() . " units=" . total, true)
            if (CoordStuckTickV84(h,pb,pid))
                return
            if (IsObject(coordRouteV16) && coordRouteV16.phase="NEXT" && !coordRouteV16.firstMoveAttempted)
            {
                coordRouteV16.firstMoveAttempted := true
                coordNoTargetSinceV14 := A_TickCount-250
            }
            CoordMoveWhenClearV14(h,pb,pid)
            return
        }
        ; Combat scan khong duoc xoa timer xet ket dang di nhat vat pham.
        itemMovingV1801 := FarmCenterPendingV741(pid) && IsObject(farmCenterCycleV741)
            && farmCenterCycleV741.phase="ITEM_MOVE"
        if (IsObject(farmItemLockV625) && !itemMovingV1801)
            farmItemLockV625.returnGoalV655 := false
        if (IsObject(coordRouteV16) && !itemMovingV1801)
            coordRouteV16.escapeV84 := false,coordRouteV16.stuckProbe := false
        if (cainNoFightV361)
        {
            AutoMonsterAttackLogV2("CAIN_SKIP_TRASH uid=" . target.uid . " class=" . target.cls . " continue_route=1",true)
            CoordMoveWhenClearV14(h,pb,pid)
            return
        }
        if (farmControlOwnerV186="CAIN" && !cainNoFightV361 && BossPriorityHasV221(target.cls))
        {
            if (cainBossUidV361 != target.uid)
            {
                cainBossUidV361 := target.uid
                cainBossClassV361 := target.cls
                cainBossKilledV361 := false
                AutoMonsterAttackLogV2("CAIN_BOSS_ENGAGE uid=" . target.uid . " class=" . target.cls)
            }
        }
        AutoMonsterAttackLogV2("TARGET_SELECTED uid=" . target.uid . " boss_priority=" . target.priority . " class=" . target.cls . " distance=" . Round(Sqrt(target.dist),2)
            . " radius=" . scanRadiusV20 . " bypass=" . (IsObject(coordRouteV16) ? coordRouteV16.bypass : 0)
            . " closest_goal=" . (IsObject(coordRouteV16) ? coordRouteV16.closestGoalDistance : -1) . " route_movement=PAUSED",true)
        targetHP := MonsterBossProbeHPV2(h,D2ReadU32(h,target.unit+0x5C))
        hpRaw := targetHP.ok ? targetHP.raw : -1

        ; Active farm target: start the configured stuck clock even if a key or
        ; packet is temporarily blocked by game focus or packet dispatch.
        if (!MonsterChaseProgressV44(target.uid,px,py,target.dist,hpRaw,target.x,target.y,target.level,pid,h,target.unit,true))
        {
            currentAttackDistV523 := Round(Sqrt(target.dist),1)
            AttackIdTipV12(D2ReadU32(h,target.unit+4),currentAttackDistV523)
            monsterCombatUidV45 := 0, monsterRoadAreaV51 := false
            if (IsObject(roomExploreV89))
            {
                RoomWalkBlockedV107(roomExploreV89,"MONSTER_NO_PROGRESS")
                AutoMonsterAttackLogV2("ROOM_TARGET_BLOCKED uid=" . target.uid . " teleport=OFF next=RETURN_PREVIOUS_ROOM")
                return
            }
            if (IsObject(coordRouteV16))
            {
                coordRouteV16.bypass := true
                if (coordRouteV16.phase="CLEAR" && coordRouteV16.next<routePointsV724.Length())
                    coordRouteV16.next++, coordRouteV16.phase := "NEXT"
                coordRouteV16.lastDispatch := 0
            }
            coordNoTargetSinceV14 := A_TickCount-250
            if (IsObject(coordRouteV16))
                coordRouteV16.escapeV84 := false,coordRouteV16.stuckProbe := false
            ; At B: skip the stuck monster and rescan other B targets next tick.
            ; Only the normal empty-area confirmation is allowed to start MOVE to C.
            if (!playerCycleV741 && !itemOnRoad && !IsObject(farmFightLockV626))
                CoordMoveWhenClearV14(h,pb,pid)
            return
        }
        coordNoTargetSinceV14 := 0
        if (IsObject(coordRouteV16))
            coordRouteV16.stuckProbe := false
        CoordRouteBattleV16()
        if (!autoMonsterAttackOn || zRunning || xRunning
            || gameItemActionOwner!="" || GameTargetHwndV63()!=hwnd)
            return
        if (!MonsterBossProbeReadV1(h,target.unit,0x30,finalUnit))
            return
        finalMode := NumGet(finalUnit,0x10,"UInt")
        if (NumGet(finalUnit,0,"UInt")!=1 || NumGet(finalUnit,0x0C,"UInt")!=target.uid
            || finalMode=0 || finalMode=12)
            return
        path := NumGet(finalUnit,0x2C,"UInt")
        if (!MonsterBossProbeReadV1(h,path,0x20,mb))
            return
        lockEligibleV308 := MonsterLockEligibleV308(NumGet(finalUnit,4,"UInt"))
        if (!lockEligibleV308 && monsterCombatUidV45=target.uid)
            monsterCombatUidV45 := 0,monsterRoadAreaV51 := false
        finalX := NumGet(mb,2,"UShort"), finalY := NumGet(mb,6,"UShort")
        finalDistance := (finalX-px)*(finalX-px)+(finalY-py)*(finalY-py)
                bossLockActiveV1 := combatLocked && BossPriorityHasV221(target.cls)
        if ((!playerCycleV741 && !itemOnRoad && RoomFarmBoundaryV235() && !RoomMonsterSameRoomV113(h,mb,pb))
            || (travelling && !scosScanV240 && !combatLocked && finalDistance>engageLimitSq)
            || (!MonsterInsideAreaV48(finalX,finalY,attackArea) || !MonsterRoadEligibleV52(px,py,finalX,finalY)))
            return
        Critical, On
        if (autoMonsterAttackOn && !packetWatchArmedV1 && !zRunning && !xRunning
            && gameItemActionOwner="" && GameTargetHwndV63()=hwnd && D2GetActiveGamePidV95()=pid)
        {
            queued := AutoMonsterPacketSendV1(pid,target.unit,target.uid)
            ; Queued=0 is NOT combat progress. MonsterChaseProgressV44 above
            ; owns the single configured combat-stuck timeout and UID/room lock.
            ; Do not run a second watchdog that could change B combat prematurely.
            if (queued)
            {
                currentAttackDistV523 := Round(Sqrt(target.dist),1)
                AttackIdTipV12(NumGet(finalUnit,4,"UInt"),currentAttackDistV523)
                currentAttackUidV520 := target.uid
                currentAttackClassV520 := NumGet(finalUnit,4,"UInt")
                currentAttackX_V520 := finalX
                currentAttackY_V520 := finalY
                currentAttackAtV520 := A_TickCount
            }
            if (queued && FarmCenterPendingV741(pid))
                farmCenterCycleV741.attacked := true
            if (queued && IsObject(monsterChaseV44) && monsterChaseV44.uid=target.uid)
            {
                if (!monsterChaseV44.since)
                    monsterChaseV44.since := A_TickCount
                monsterChaseV44.queued++
            }
            if (queued && lockEligibleV308 && monsterCombatUidV45!=target.uid)
            {
                monsterCombatUidV45 := target.uid
                if (travelling)
                    monsterRoadAreaV51 := {x:px,y:py,radiusSq:scanRadiusV20*scanRadiusV20,source:"ROAD_ENCOUNTER",row:0,level:CoordLevelV14(h,room)}
                AutoMonsterAttackLogV2("COMBAT_LOCK uid=" . target.uid . " class=" . target.cls . " reason=KEEP_CURRENT_TARGET coordinate_movement=PAUSED until=TARGET_GONE_OUTSIDE_RADIUS_OR_ROOM_LOCK")
            }
            if (queued && !lockEligibleV308)
            {
                monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
                burstKeyV1 := pid . "|" . CoordLevelV14(h,room) . "|" . target.uid
                burstCountV1 := nonBossBurstCountsV1.HasKey(burstKeyV1) ? nonBossBurstCountsV1[burstKeyV1]+1 : 1
                if (burstCountV1>=2)
                {
                    nonBossBurstCountsV1.Delete(burstKeyV1)
                    MonsterStuckUidSkipV711(target.uid,CoordLevelV14(h,room),pid)
                    AutoMonsterAttackLogV2("NON_BOSS_BURST_DONE uid=" . target.uid . " attacks=2 tracking=OFF skip_seconds=" . Max(1,monsterLockRoomSecV622) . " next=ROUTE_OR_NEXT_TARGET",true)
                }
                else
                    nonBossBurstCountsV1[burstKeyV1] := burstCountV1
            }
            if (queued && !lockEligibleV308 && RoomFarmBoundaryV235())
            {
                coordRouteV16.stuckProbe := false
                AutoMonsterAttackLogV2("ROOM_FREE_ATTACK uid=" . target.uid . " target_lock=OFF next=FRESH_NEAREST_SCAN",true)
            }
            AutoMonsterAttackLogV2("AUTO_NATIVE_RIGHT_CLICK uid=" . target.uid . " class=" . NumGet(finalUnit,4,"UInt")
                . " method=D2CLIENT_RIGHT_DOWN_UP queued=" . queued
                . " priority=" . (target.priority ? "LISTED_BOSS_ID" : "NEAREST_TO_PLAYER") . " phase=" . (travelling ? "TRAVEL_CLOSE_COMBAT" : "FOCUS_COMBAT")
                . " scan=ALL_LOADED_ROOMS radius_map=" . scanRadiusV20 . " area=" . (IsObject(attackArea) ? attackArea.source : "TRAVEL_NEAR_PLAYER")
                . " distance=" . Round(Sqrt(target.dist),2) . " mouse_moved=0")
        }
        Critical, Off
    }
    finally
    {
        farmCombatAreaV590 := previousAreaV590
        Critical, Off
        DllCall("CloseHandle","Ptr",h)
    }
}

PacketWatchTimerV1:
if (!ManualLogActiveV81())
{
    SetTimer, PacketWatchTimerV1, Off
    return
}
Critical, On
if (!packetWatchArmedV1 || !pickupCubeTraceUntil || A_TickCount>=pickupCubeTraceUntil)
{
    PacketWatchStopV1()
    Critical, Off
    return
}
if (!IsObject(packetWatchV1))
{
    pidPacket := D2GetActiveGamePidV95()
    if (pidPacket)
        PacketWatchStartV1(pidPacket)
}
if (IsObject(packetWatchV1))
    PacketWatchPollV1()
Critical, Off
return

PacketWatchLogV1(message)
{
    if (!ManualLogActiveV81())
        return
    global pickupCubeTraceUntil,sigCubeCaptureV151,wpCaptureV161
    if (!pickupCubeTraceUntil || A_TickCount>=pickupCubeTraceUntil)
        return
    log := IsObject(wpCaptureV161) ? A_ScriptDir . "\Auto-GSF-Cong-Len-Map.log" : DebugTraceFile(IsObject(sigCubeCaptureV151) ? "cube" : "packet")
    ManualLogAppendV81(A_Now . " tick=" . A_TickCount . " | " . message . "`r`n", log, "UTF-8")
}

PacketWatchGetContextV1(hThread, ByRef context)
{
    VarSetCapacity(context,716,0)
    NumPut(0x10017,context,0,"UInt")
    fn := A_PtrSize=8 ? "Wow64GetThreadContext" : "GetThreadContext"
    return DllCall(fn,"Ptr",hThread,"Ptr",&context)
}

PacketWatchSetContextV1(hThread, ByRef context)
{
    fn := A_PtrSize=8 ? "Wow64SetThreadContext" : "SetThreadContext"
    return DllCall(fn,"Ptr",hThread,"Ptr",&context)
}

PacketWatchStartV1(pid)
{
    if (!ManualLogActiveV81())
        return false
    global packetWatchV1, packetWatchArmedV1, nativeAttackProbeV5
    base := D2GetModuleBaseV35(pid,nativeAttackProbeV5 ? "D2Client.dll" : "D2Net.dll")
    h := base ? DllCall("OpenProcess","UInt",0x0410,"Int",0,"UInt",pid,"Ptr") : 0
    if (!h)
    {
        PacketWatchLogV1("CAPTURE_ERROR stage=OPEN_PROCESS err=" . A_LastError)
        packetWatchArmedV1 := false
        return false
    }
    if (nativeAttackProbeV5 && !NativeAttackBuildV5(h,base))
    {
        PacketWatchLogV1("ATTACK_PROBE_SKIP reason=DLL_BUILD_MISMATCH")
        DllCall("CloseHandle","Ptr",h)
        packetWatchArmedV1 := false
        return false
    }
    if (!DllCall("DebugActiveProcess","UInt",pid))
    {
        PacketWatchLogV1("CAPTURE_ERROR stage=DEBUG_ATTACH err=" . A_LastError . " packet_capture=NOT_STARTED")
        DllCall("CloseHandle","Ptr",h)
        packetWatchArmedV1 := false
        return false
    }
    packetWatchV1 := {pid:pid,h:h,send:base+(nativeAttackProbeV5 ? 0x1A060 : 0x7650),attackProbe:nativeAttackProbeV5,threads:{},count:0
        ,initialBreak:false,initialWowBreak:false,lastRight:false,failed:false,mainTid:0}
    if (!DllCall("DebugSetProcessKillOnExit","Int",false))
    {
        PacketWatchLogV1("CAPTURE_ERROR stage=KEEP_GAME_ALIVE err=" . A_LastError)
        PacketWatchStopV1()
        return false
    }
    PacketWatchLogV1("ATTACHED pid=" . pid . " send_entry=" . V92Hex(packetWatchV1.send)
        . " attack_probe=" . nativeAttackProbeV5 . " capture=ACTUAL_FUNCTION_ARGUMENTS no_packet_sent_by_probe=1")
    return true
}

PacketWatchThreadV1(tid)
{
    global packetWatchV1
    w := packetWatchV1
    if (w.threads.HasKey(tid))
        return w.threads[tid]
    ht := DllCall("OpenThread","UInt",0x1A,"Int",false,"UInt",tid,"Ptr")
    if (!ht || !PacketWatchGetContextV1(ht,context))
    {
        if (ht)
            DllCall("CloseHandle","Ptr",ht)
        PacketWatchLogV1("THREAD_SKIP tid=" . tid . " reason=CONTEXT_READ err=" . A_LastError)
        return false
    }
    dr7 := NumGet(context,24,"UInt")
    if (dr7 & 3)
    {
        PacketWatchLogV1("THREAD_SKIP tid=" . tid . " reason=DR0_ALREADY_USED")
        DllCall("CloseHandle","Ptr",ht)
        return false
    }
    t := {h:ht,dr0:NumGet(context,4,"UInt"),dr6:NumGet(context,20,"UInt"),dr7:dr7}
    NumPut(w.send,context,4,"UInt")
    NumPut(0,context,20,"UInt")
    NumPut((dr7 & 0xFFF0FFFC) | 1,context,24,"UInt")
    if (!PacketWatchSetContextV1(ht,context))
    {
        PacketWatchLogV1("THREAD_SKIP tid=" . tid . " reason=CONTEXT_SET err=" . A_LastError)
        DllCall("CloseHandle","Ptr",ht)
        return false
    }
    w.threads[tid] := t
    PacketWatchLogV1("THREAD_ARMED tid=" . tid)
    return t
}

PacketWatchPollV1()
{
    global packetWatchV1
    if (!IsObject(packetWatchV1))
        return
    w := packetWatchV1
    Loop, 64
    {
        VarSetCapacity(event,192,0)
        if (!DllCall("WaitForDebugEvent","Ptr",&event,"UInt",0))
            break
        code := NumGet(event,0,"UInt"), pid := NumGet(event,4,"UInt"), tid := NumGet(event,8,"UInt")
        uoff := A_PtrSize=8 ? 16 : 12
        status := 0x10002
        try
        {
            if (code=3 || code=2)
            {
                if (code=3)
                {
                    fileHandle := NumGet(event,uoff,"Ptr")
                    if (fileHandle)
                        DllCall("CloseHandle","Ptr",fileHandle)
                }
                if (code=3)
                {
                    w.mainTid := tid
                    PacketWatchThreadV1(tid)
                    PacketWatchLogV1("MAIN_THREAD tid=" . tid . " tool_actions=PAUSED")
                }
            }
            else if (code=6)
            {
                fileHandle := NumGet(event,uoff,"Ptr")
                if (fileHandle)
                    DllCall("CloseHandle","Ptr",fileHandle)
            }
            else if (code=4)
            {
                if (w.threads.HasKey(tid))
                {
                    DllCall("CloseHandle","Ptr",w.threads[tid].h)
                    w.threads.Delete(tid)
                }
            }
            else if (code=1)
            {
                exception := NumGet(event,uoff,"UInt")
                status := 0x80010001
                if ((exception=0x80000004 || exception=0x4000001E) && w.threads.HasKey(tid))
                {
                    t := w.threads[tid]
                    exceptionAddress := NumGet(event,uoff+(A_PtrSize=8 ? 16 : 12),"Ptr")
                    if (exceptionAddress=w.send)
                    {
                        status := 0x10002
                        w.failed := true
                        PacketWatchLogV1("BREAKPOINT_HIT tid=" . tid)
                    }
                    if (PacketWatchGetContextV1(t.h,context)
                        && NumGet(context,184,"UInt")=w.send && (NumGet(context,20,"UInt") & 1))
                    {
                        status := 0x10002
                        w.failed := false
                        esp := NumGet(context,196,"UInt")
                        if (w.attackProbe)
                            NativeAttackCaptureV5(w,esp)
                        else if (MonsterBossProbeReadV1(w.h,esp,16,args))
                        {
                            len := NumGet(args,4,"UInt"), arg1 := NumGet(args,8,"UInt")
                            ptr := NumGet(args,12,"UInt")
                            right := GetKeyState("RButton","P")
                            MouseGetPos, mouseXPacket, mouseYPacket
                            if (len>0 && len<=4096 && MonsterBossProbeReadV1(w.h,ptr,Min(len,128),packet))
                            {
                                w.count++
                                PacketWatchLogV1("SEND n=" . w.count . " tid=" . tid . " len=" . len
                                    . " arg1=" . arg1 . " opcode=" . Format("{:02X}",NumGet(packet,0,"UChar"))
                                    . " hex=" . MonsterBossProbeHexV1(packet,Min(len,128))
                                    . " truncated=" . (len>128) . " physical_RButton=" . right
                                    . " active_game=" . (D2GetActiveGamePidV95()=w.pid)
                                    . " mouse=" . mouseXPacket . "," . mouseYPacket)
                            }
                            else
                                PacketWatchLogV1("SEND_READ_FAIL len=" . len . " ptr=" . V92Hex(ptr))
                        }
                        NumPut(NumGet(context,192,"UInt") | 0x10000,context,192,"UInt")
                        NumPut(NumGet(context,20,"UInt") & 0xFFFFFFFE,context,20,"UInt")
                        if (!PacketWatchSetContextV1(t.h,context))
                        {
                            w.failed := true
                            PacketWatchLogV1("CAPTURE_ERROR stage=RESUME_CONTEXT tid=" . tid . " err=" . A_LastError)
                        }
                    }
                }
                else if (exception=0x80000003 && !w.initialBreak)
                {
                    w.initialBreak := true
                    status := 0x10002
                }
                else if (exception=0x4000001F && !w.initialWowBreak)
                {
                    w.initialWowBreak := true
                    status := 0x10002
                }
            }
            else if (code=5)
            {
                w.failed := true
                PacketWatchLogV1("PROCESS_EXIT code=" . NumGet(event,uoff,"UInt"))
            }
        }
        catch packetProbeError
        {
            w.failed := true
            PacketWatchLogV1("CAPTURE_ERROR stage=EVENT_PROCESSING message=" . packetProbeError.Message)
        }
        finally
        {
            if (!DllCall("ContinueDebugEvent","UInt",pid,"UInt",tid,"UInt",status))
            {
                w.failed := true
                PacketWatchLogV1("CAPTURE_ERROR stage=CONTINUE_DEBUG_EVENT err=" . A_LastError)
            }
        }
        if (w.failed)
        {
            PacketWatchStopV1()
            return
        }
    }
    right := GetKeyState("RButton","P")
    if (right && !w.lastRight && D2GetActiveGamePidV95()=w.pid)
    {
        MouseGetPos, mxPacket, myPacket
        PacketWatchLogV1("MANUAL_RBUTTON_DOWN mouse=" . mxPacket . "," . myPacket)
    }
    w.lastRight := right
}

PacketWatchStopV1()
{
    global packetWatchV1, packetWatchArmedV1, nativeAttackProbeV5
    nativeAttackProbeV5 := false
    packetWatchArmedV1 := false
    BackgroundHotkeyV63("~*RButton","","Off UseErrorLevel")
    SetTimer, PacketWatchTimerV1, Off
    if (!IsObject(packetWatchV1))
        return
    w := packetWatchV1
    for tid,t in w.threads
    {
        suspended := DllCall("SuspendThread","Ptr",t.h,"UInt")
        if (suspended!=0xFFFFFFFF)
        {
            try
            {
                if (PacketWatchGetContextV1(t.h,context))
                {
                    NumPut(t.dr0,context,4,"UInt")
                    NumPut(t.dr6,context,20,"UInt")
                    NumPut(t.dr7,context,24,"UInt")
                    if (!PacketWatchSetContextV1(t.h,context))
                        PacketWatchLogV1("RESTORE_ERROR tid=" . tid . " err=" . A_LastError)
                }
                else
                    PacketWatchLogV1("RESTORE_ERROR tid=" . tid . " reason=CONTEXT_READ")
            }
            finally
                DllCall("ResumeThread","Ptr",t.h)
        }
        DllCall("CloseHandle","Ptr",t.h)
    }
    detached := DllCall("DebugActiveProcessStop","UInt",w.pid)
    PacketWatchLogV1("CAPTURE_END packets=" . w.count . " failed=" . w.failed . " detach_ok=" . detached . " tool_actions=RESUMED")
    DllCall("CloseHandle","Ptr",w.h)
    packetWatchV1 := false
}

PacketWatchRightButtonV2:
if (!packetWatchArmedV1 || !IsGameActive())
    return
MouseGetPos, clickPacketX, clickPacketY
PacketWatchLogV1("MANUAL_RBUTTON_DOWN source=PASS_THROUGH_HOTKEY mouse=" . clickPacketX . "," . clickPacketY)
return

AutoMonsterPacketCleanupTimerV1:
AutoMonsterPacketCleanupV1()
return

AutoMonsterPacketCleanupV1(onExit := false)
{
    global autoMonsterPacketPendingV1,farmAttackHoldV15,autoMonsterAttackOn,backgroundPidV63
    pending := autoMonsterPacketPendingV1
    if (onExit)
    {
        if (IsObject(farmAttackHoldV15))
            farmAttackHoldV15.releaseV15 := true
        if (IsObject(pending) && pending.holdDownV15)
            pending.releaseV15 := true
    }
    if (!IsObject(pending))
    {
        if (IsObject(farmAttackHoldV15) && farmAttackHoldV15.releaseV15)
            return FarmAttackHoldReleaseV15()
        SetTimer, AutoMonsterPacketCleanupTimerV1, Off
        return !RemoteThreadBusyV740(backgroundPidV63)
    }
    wait := DllCall("WaitForSingleObject","Ptr",pending.thread,"UInt",0)
    if (wait!=0 && RemoteProcessEndedV740(pending.process))
    {
        DllCall("CloseHandle","Ptr",pending.thread)
        DllCall("CloseHandle","Ptr",pending.process)
        autoMonsterPacketPendingV1 := false,farmAttackHoldV15 := false
        SetTimer, AutoMonsterPacketCleanupTimerV1, Off
        return false
    }
    if (wait!=0 && !onExit && pending.HasKey("setAt") && A_TickCount-pending.setAt>1500)
    {
        if (!pending.timeoutReportedV655)
        {
            pending.timeoutReportedV655 := true
            DebugTraceWrite("packet","PENDING_TIMEOUT_TRACKED kind=" . pending.kind . " uid=" . pending.uid)
            FonInfoPushV385("Lệnh game chưa kết thúc; giữ thứ tự lệnh, Đứng lâu xử lý nếu không phục hồi.")
        }
        return false
    }
    if (wait!=0 && !onExit)
        return false
    if (wait=0 && pending.holdDownV15)
    {
        DllCall("CloseHandle","Ptr",pending.thread)
        farmAttackHoldV15 := pending
        autoMonsterPacketPendingV1 := false
        SetTimer, AutoMonsterPacketCleanupTimerV1, Off
        if (onExit || pending.releaseV15 || !autoMonsterAttackOn)
            return FarmAttackHoldReleaseV15()
        return true
    }
    if (wait=0)
    {
        if (pending.moveCall && MonsterBossProbeReadV1(pending.process,pending.remote+(pending.resultOffsetV503 ? pending.resultOffsetV503 : 192),24,moveResult))
        {
            prepResult := NumGet(moveResult,0,"UInt"), helperResult := NumGet(moveResult,4,"UInt")
            AutoMonsterAttackLogV2("MAP_MOVE_THREAD_END prepare_return=" . prepResult
                . " helper_return=" . (helperResult=0xFFFFFFFF ? "NOT_CALLED" : helperResult)
                . " prepared_point=" . NumGet(moveResult,8,"UInt") . "," . NumGet(moveResult,12,"UInt")
                . " path_points=" . NumGet(moveResult,16,"UInt") . " path_type=" . NumGet(moveResult,20,"UInt")
                . " effect=UNCONFIRMED")
        }
        if (pending.dispatchV9 && MonsterBossProbeReadV1(pending.process,pending.remote+192,24,resultV9))
            NativeDispatchLogV10(pending.autoCall,"NATIVE_RIGHT_DISPATCH_RESULT uid=" . pending.uid
                . " down_return=" . NumGet(resultV9,0,"UInt") . " up_return=" . NumGet(resultV9,4,"UInt")
                . " prepared_flags=" . NumGet(resultV9,8,"UInt") . " resolved_target=" . V92Hex(NumGet(resultV9,12,"UInt"))
                . " prepared_skill=" . V92Hex(NumGet(resultV9,16,"UInt")) . " attack_gate_before=" . NumGet(resultV9,20,"UInt")
                . " return_is_not_cast_confirmation=1")
        if (!pending.autoCall && (pending.kind="UNIT_TEST" || pending.kind="MAP_TEST"))
        {
            testPidV8 := DllCall("GetProcessId","Ptr",pending.process,"UInt")
            testBaseV8 := D2GetModuleBaseV35(testPidV8,"D2Client.dll")
            if (testBaseV8)
                NativeAttackStateV8(pending.process,testBaseV8,"AFTER_CALL")
        }
        DllCall("VirtualFreeEx","Ptr",pending.process,"Ptr",pending.remote,"UPtr",0,"UInt",0x8000)
        DllCall("GetExitCodeThread","Ptr",pending.thread,"UIntP",exitCode)
        if (pending.dispatchV9)
            NativeDispatchLogV10(pending.autoCall,"NATIVE_" . (pending.autoCall ? "AUTO_UNIT" : pending.kind="UNIT_TEST" ? "UNIT" : "MAP") . "_THREAD_END uid=" . pending.uid
                . " exit_code=" . exitCode . " completed=1 effect=UNCONFIRMED")
        else if (pending.portalCall)
            PortalLogWriteV66("PORTAL_DLL_THREAD_END uid=" . pending.uid . " exit_code=" . exitCode . " completed=1 effect=WAIT_MAP_CHANGE")
        else if (pending.moveCall)
            AutoMonsterAttackLogV2("MAP_MOVE_THREAD_EXIT exit_code=" . exitCode . " completed=1 effect=UNCONFIRMED")
        else
            AutoMonsterAttackLogV2("AUTO_CLIENT_CLICK_THREAD_END uid=" . pending.uid . " exit_code=" . exitCode . " completed=1 hit=UNCONFIRMED")
    }
    DllCall("CloseHandle","Ptr",pending.thread)
    DllCall("CloseHandle","Ptr",pending.process)
    autoMonsterPacketPendingV1 := false
    SetTimer, AutoMonsterPacketCleanupTimerV1, Off
    return (wait=0)
}

RoomStandLogV114(h,player,ByRef pb,pid,mode)
{
    global coordSavedV15
    global roomExploreV89,coordRouteV16,coordCastPendingV50,portalBuffV85,portalExitPendingV69,portalBackPendingV74
    global xRunning,zRunning,gameItemActionOwner,monsterRetryUntilV44,monsterRadiusV48,autoMonsterAttackOn
    static last := 0
    if (!ManualLogActiveV81() || A_TickCount-last<1000)
        return
    last := A_TickCount
    px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort"), room1 := NumGet(pb,0x1C,"UInt")
    room2 := room1 ? D2ReadU32(h,room1+0x10) : 0, level := CoordLevelV14(h,room1)
    r := roomExploreV89, route := coordRouteV16, file := RoomProfileFileV108()
    RoomExploreLogV89("ROOM_STAND_STATE pid=" . pid . " farm=" . autoMonsterAttackOn . " room_farm=" . IsObject(r) . " coordinate_map=" . RoomCoordinateModeV116()
        . " map=" . level . " room2=" . V92Hex(room2) . " player=" . px . "," . py . " mode=" . mode . " file=" . file
        . " yellow_row=" . CoordYellowIndexV48() . " replay_index=" . r.routeReplayIndex . " phase=" . route.phase
        . " goal_room=" . V92Hex(r.target) . " goal_uid=" . r.goalUid . " goal_kind=" . r.goalKind
        . " walking_ms=" . r.travelMs . " returning=" . r.backtracking . " fallback=" . r.routeFallback
        . " portal_pending=" . coordCastPendingV50 . " clear_pending=" . r.pendingClearRoom
        . " portal_buff=" . IsObject(portalBuffV85) . " portal_exit=" . IsObject(portalExitPendingV69)
        . " portal_back=" . IsObject(portalBackPendingV74) . " x_running=" . xRunning . " z_running=" . zRunning . " item_owner=" . gameItemActionOwner)
    if (RoomCoordinateModeV116() && IsObject(route) && route.next>=1 && route.next<=coordSavedV15.Length())
    {
        goalV124 := coordSavedV15[route.next]
        RoomExploreLogV89("ROOM_STAND_COORD_NEXT row=" . route.next . " room_number=" . goalV124.roomNumber
            . " center=" . goalV124.x . "," . goalV124.y . " anchor=" . route.anchor)
    }
    if (!IsObject(r) && !RoomCoordinateModeV116())
    {
        section := "Route-" . level
        IniRead, format, %file%, %section%, Format, MISSING
        IniRead, count, %file%, %section%, Count, 0
        RoomExploreLogV89("ROOM_STAND_ROUTE_NOT_ACTIVE file_exists=" . (FileExist(file)!="") . " format=" . format . " count=" . count
            . " reason=CHECK_MAP_LEVEL_OR_START_ROOM_IN_SAVED_ROUTE")
    }
    if (IsObject(r.routeReplay) && r.routeReplayIndex<=r.routeReplay.Length())
    {
        step := r.routeReplay[r.routeReplayIndex], known := 0, loaded := 0
        for address,node in r.nodes
            if (node.routeNumber=step.number)
                known := address, loaded := node.r1!=0
        RoomExploreLogV89("ROOM_STAND_NEXT row=" . r.routeReplayIndex . " room_number=" . step.number
            . " center=" . step.x . "," . step.y . " known_room=" . V92Hex(known) . " loaded=" . loaded
            . " blocked=" . r.closedBranches.HasKey(known) . " total=" . r.routeReplay.Length())
    }
    node := RoomExploreReadV89(h,room2,level)
    if (!IsObject(node))
    {
        RoomExploreLogV89("ROOM_STAND_SCAN reason=CURRENT_ROOM_READ_FAILED")
        return
    }
    scan := RoomLiveGoalV90(h,node,px,py)
    reason := scan.incomplete ? "SCAN_INCOMPLETE" : scan.count ? (IsObject(scan.best) ? "LIVE_CURRENT_ROOM_MONSTER" : "LIVE_BUT_NO_ELIGIBLE_TARGET") : "CURRENT_ROOM_CLEAR"
    RoomExploreLogV89("ROOM_STAND_SCAN live=" . scan.count . " incomplete=" . scan.incomplete . " reason=" . reason
        . " nearest_uid=" . scan.best.uid . " nearest_xy=" . scan.best.x . "," . scan.best.y
        . " rect=" . node.x . "," . node.y . "," . node.w . "," . node.h)
    u := node.r1 ? D2ReadU32(h,node.r1+0x74) : 0, seen := {}, n := 0, shown := 0
    while (u && n<256 && shown<12 && !seen.HasKey(u))
    {
        seen[u] := true, n++
        if (!MonsterBossProbeReadV1(h,u,0xEC,ub))
            break
        next := NumGet(ub,0xE8,"UInt"), typ := NumGet(ub,0,"UInt"), cls := NumGet(ub,4,"UInt"), uid := NumGet(ub,12,"UInt"), unitMode := NumGet(ub,16,"UInt")
        if (typ=1 && unitMode!=0 && unitMode!=12)
        {
            shown++, valid := MonsterBossProbeReadV1(h,NumGet(ub,0x2C,"UInt"),0x20,mp)
            mx := valid ? NumGet(mp,2,"UShort") : -1, my := valid ? NumGet(mp,6,"UShort") : -1
            same := valid && RoomMonsterSameRoomV113(h,mp,pb)
            retry := IsObject(monsterRetryUntilV44) && monsterRetryUntilV44.HasKey(uid) ? Max(0,monsterRetryUntilV44[uid]-A_TickCount) : 0
            RoomExploreLogV89("ROOM_STAND_MONSTER uid=" . uid . " class=" . cls . " mode=" . unitMode . " xy=" . mx . "," . my
                . " path_valid=" . valid . " same_room=" . same . " pet=" . MonsterClassExcludedV11(cls,h,u)
                . " distance=" . (valid ? Round(Sqrt((mx-px)**2+(my-py)**2),1) : -1) . " radius=" . monsterRadiusV48 . " retry_ms=" . retry)
        }
        u := next
    }
}
