AutoPotTimer:
if (packetWatchArmedV1)
    return
if (xRunning)
{
    HealTrace("TIMER_SKIP reason=QUICK_BUFF_RUNNING", "timer")
    return
}
if (!autoPotOn && !manaOn && !invHealOn && !invManaOn && !cubeHealOn && !cubeManaOn)
{
    HealTrace("TIMER_SKIP reason=ALL_SOURCES_OFF", "timer")
    return
}
if (!IsGameActive())
{
    HealTrace("TIMER_SKIP reason=GAME_NOT_ACTIVE", "timer")
    return
}

pid := D2GetActiveGamePidV95()
if (pid)
{
    level := RoomRecordLevelV259(pid)
    if (level && FarmReviveTownLevelV295(level))
    {
        return
    }
}

if (!GameItemActionBeginV4("Heal", "heal", true))
    return
try
{
healVitals := D2ReadHealVitalsV3()
healHPEnabled := autoPotOn || invHealOn || cubeHealOn
healMPEnabled := manaOn || invManaOn || cubeManaOn
healHPWait := Max(0, potCooldown - (A_TickCount-potLastDrink), potNextDrinkAtV730-A_TickCount)
healMPWait := Max(0, manaCooldown - (A_TickCount-manaLastDrink))
healHPNeed := (healVitals.hp>=0 && healVitals.hp<=potHPThreshold)
healMPNeed := (healVitals.mana>=0 && healVitals.mana<=manaThreshold)
HealTrace("HP_GATE pid=" . healVitals.pid . " value=" . healVitals.hp
    . " threshold=" . potHPThreshold . " enabled=" . healHPEnabled
    . " need=" . healHPNeed . " cooldown_left_ms=" . healHPWait . " read=" . healVitals.reason, "hp_gate")
HealTrace("MANA_GATE pid=" . healVitals.pid . " value=" . healVitals.mana
    . " threshold=" . manaThreshold . " enabled=" . healMPEnabled
    . " need=" . healMPNeed . " cooldown_left_ms=" . healMPWait . " read=" . healVitals.reason, "mp_gate")
if (healHPEnabled && !healHPWait && healHPNeed)
{
    okHP := TryHealSources(1229, "HP")
    if (okHP)
    {
        potLastDrink := A_TickCount
        potNextDrinkAtV730 := potLastDrink+Max(1,potCooldown)
        HealTrace("HEAL_SENT kind=HP before=" . healVitals.hp . " next_try_ms=" . potCooldown)
    }
}
if (healMPEnabled && !healMPWait && healMPNeed)
{
    okMana := TryHealSources(1234, "Mana")
    if (okMana)
    {
        manaLastDrink := A_TickCount
        HealTrace("HEAL_SENT kind=Mana before=" . healVitals.mana . " next_try_ms=" . manaCooldown)
    }
}
}
finally
{
    GameItemActionEndV4("Heal")
}
return

TryHealSources(targetClass, kind)
{
    global healExhausted, cubeHealOn, cubeManaOn, invHealOn, invManaOn, autoPotOn, manaOn
    global potHPThreshold,potCooldown,potLastDrink,potNextDrinkAtV730
    static retryAt := {}, lastPid := 0
    pid := D2GetActiveGamePidV95()
    if (!pid)
        return false
    if (pid!=lastPid)
    {
        healExhausted := {HP:{Belt:false,Ruong:false,Cube:false}, Mana:{Belt:false,Ruong:false,Cube:false}}
        retryAt := {}, lastPid := pid
    }
    if (kind="HP")
    {
        if (!RegExMatch(potCooldown,"^\d+$") || potCooldown<1
            || A_TickCount-potLastDrink<potCooldown || A_TickCount<potNextDrinkAtV730)
            return false
        currentHPV730 := D2ReadHealVitalsV3()
        if (currentHPV730.pid!=pid || currentHPV730.hp<0 || currentHPV730.hp>potHPThreshold)
            return false
    }
    beltOn := (kind="HP") ? autoPotOn : manaOn
    ruongOn := (kind="HP") ? invHealOn : invManaOn
    cubeOn := (kind="HP") ? cubeHealOn : cubeManaOn
    for _, source in ["Belt", "Ruong", "Cube"]
    {
        enabled := (source="Belt") ? beltOn : ((source="Ruong") ? ruongOn : cubeOn)
        cacheKey := kind . "_" . source
        if (!enabled)
        {
            HealTrace("SOURCE_SKIP kind=" . kind . " source=" . source . " reason=OFF", cacheKey)
            continue
        }
        if (healExhausted[kind][source] && retryAt.HasKey(cacheKey) && A_TickCount<retryAt[cacheKey])
        {
            HealTrace("SOURCE_SKIP kind=" . kind . " source=" . source . " reason=EMPTY_BACKOFF"
                . " retry_in_ms=" . (retryAt[cacheKey]-A_TickCount), cacheKey)
            continue
        }
        healExhausted[kind][source] := false
        if (source="Belt")
            result := V25UseBeltClassKey(targetClass)
        else if (source="Ruong")
            result := D2TryInventoryPotionClassV17(targetClass)
        else
            result := D2TryCubePotionClassV17(targetClass)
        HealTrace("SOURCE_RESULT kind=" . kind . " source=" . source . " result=" . result
            . " meaning=" . (result=1 ? "SENT" : (result=0 ? "EMPTY" : "READ_OR_SEND_ERROR")), cacheKey . "_result")
        if (result=1)
            return true
        if (result=0)
        {
            healExhausted[kind][source] := true
            retryAt[cacheKey] := A_TickCount+2000
        }
    }
    HealTrace("HEAL_NOT_SENT kind=" . kind . " reason=NO_AVAILABLE_SOURCE", kind . "_none")
    return false
}

V34WriteCubeProbeOnce()
{
    if (!ManualLogActiveV81())
        return
    log := A_ScriptDir . "\Cube-HP-Mana-Test.log"
    tmp := A_Temp . "\d2_cube_hpmana_v34.txt"
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
    ManualLogAppendV81("================ CUBE HP-MANA PROBE V34 " . A_Now . " ================`r`n", log, "UTF-8")
    ManualLogAppendV81("READ ONLY - CUBE DISCOVERY - NO SEND / NO CLICK / NO PACKET`r`n", log, "UTF-8")
    ManualLogAppendV81("KNOWN HP_CLASS=1229 MANA_CLASS=1234`r`n", log, "UTF-8")
    ManualLogAppendV81("PID=" . pidFound . " PLAYER=" . V92Hex(player) . " PLAYER_INV=" . V92Hex(inv) . " FIRST=" . V92Hex(first) . "`r`n", log, "UTF-8")
    ManualLogAppendV81("MUC TIEU: tim owner/inventory khac PLAYER_INV va loc/path cua HP-Mana trong Cube.`r`n`r`n", log, "UTF-8")

    queue := [first]
    seen := {}
    qi := 1
    itemN := 0, hpManaN := 0, foreignOwnerN := 0

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
            po := (A_Index - 1) * 4
            pu := D2ReadU32(h, u + po)
            if (!pu || seen.HasKey(pu))
                continue
            pt := D2ReadU32(h, pu + 0x00)
            pc := D2ReadU32(h, pu + 0x04)
            if (pt = 4 && pc >= 1 && pc <= 10000)
                queue.Push(pu)
        }

        if (typ = 4 && itemData)
        {
            Loop, 64
            {
                po := (A_Index - 1) * 4
                pu := D2ReadU32(h, itemData + po)
                if (!pu || seen.HasKey(pu))
                    continue
                pt := D2ReadU32(h, pu + 0x00)
                pc := D2ReadU32(h, pu + 0x04)
                if (pt = 4 && pc >= 1 && pc <= 10000)
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

        isHPMP := (cls = 1229 || cls = 1234)
        foreign := (owner && owner != inv)
        if (foreign)
            foreignOwnerN++

        if (isHPMP || foreign)
        {
            tag := ""
            if (cls = 1229)
                tag .= " HP_CLASS1229"
            else if (cls = 1234)
                tag .= " MANA_CLASS1234"
            if (foreign)
                tag .= " FOREIGN_OWNER_CANDIDATE"
            if (loc45 = 255)
                tag .= " BELT"

            if (isHPMP)
                hpManaN++

            ManualLogAppendV81("ITEM#" . itemN . " unit=" . V92Hex(u) . " class=" . cls . " id=" . uid . " q00=" . q00 . " loc44=" . loc44 . " loc45=" . loc45 . " owner=" . V92Hex(owner) . " playerInv=" . V92Hex(inv) . " path=" . V92Hex(path) . " xy=" . x . "," . y . tag . "`r`n", log, "UTF-8")

            if (isHPMP)
            {
                ud := ""
                Loop, 64
                {
                    off := (A_Index - 1) * 4
                    vv := D2ReadU32(h, u + off)
                    ud .= (A_Index=1 ? "" : " ") . Format("{:02X}:{:08X}", off, vv)
                }
                ManualLogAppendV81("  UNIT_DWORDS_00_FC " . ud . "`r`n", log, "UTF-8")

                bd := ""
                Loop, 256
                {
                    off := A_Index - 1
                    vv := D2ReadU8V18(h, itemData + off)
                    bd .= (A_Index=1 ? "" : " ") . Format("{:02X}:{:02X}", off, vv)
                }
                ManualLogAppendV81("  ITEMDATA_BYTES_00_FF " . bd . "`r`n", log, "UTF-8")
            }
        }
    }

    ManualLogAppendV81("`r`nSUMMARY CUBE_PROBE GRAPH_NODES=" . seen.Count() . " ITEMS=" . itemN . " HP_MANA=" . hpManaN . " FOREIGN_OWNER=" . foreignOwnerN . "`r`n", log, "UTF-8")
    ManualLogAppendV81("END CUBE HP-MANA PROBE V34`r`n", log, "UTF-8")
    DllCall("CloseHandle", "Ptr", h)
    return true
}


D2GetCurrentManaV17()
{
    vitals := D2ReadHealVitalsV3()
    return vitals.mana
}

D2DumpPlayerStatRootV21()
{
    tmp := A_Temp . "\\d2_stat_v21.txt"
    FileDelete, %tmp%
    cmd := "tasklist /FI " . Chr(34) . "IMAGENAME eq Game.exe" . Chr(34) . " /FO CSV /NH > " . Chr(34) . tmp . Chr(34) . " 2>&1"
    RunWait, %ComSpec% /c %cmd%,, Hide
    FileRead, raw, %tmp%
    FileDelete, %tmp%
    Loop, Parse, raw, `n, `r
    {
        line := A_LoopField
        if !RegExMatch(line, "i)^""Game\.exe"",""([0-9]+)""", m)
            continue
        pid := m1 + 0
        base := D2GetModuleBaseV35(pid, "D2Client.dll")
        if (!base)
            continue
        h := D2OpenProcess(pid)
        if (!h)
            continue
        player := D2ReadU32(h, base + 0x11BBFC)
        stats := player ? D2ReadU32(h, player + 0x5C) : 0
        root := stats ? D2ReadU32(h, stats + 0x24) : 0
        if (!root)
        {
            DllCall("CloseHandle", "Ptr", h)
            continue
        }
        txt := "STAT_ROOT_V21=" . V92Hex(root) . "`r`n"
        off := 0
        Loop, 65
        {
            v := D2ReadU32(h, root + off)
            val256 := Floor(v / 256)
            txt .= "OFF=0x" . Format("{:02X}", off) . " RAW=" . v . " DIV256=" . val256
            if (val256 = 14956)
                txt .= "  <== HP_MATCH"
            if (val256 = 7664)
                txt .= "  <== MANA_7664_MATCH"
            txt .= "`r`n"
            off += 4
        }
        DllCall("CloseHandle", "Ptr", h)
        return txt
    }
    return "STAT_ROOT_V21=FAIL`r`n"
}

D2TryInventoryPotionClassV17(targetClass)
{
    return D2TryContainerPotionClassV17(targetClass, 0)
}

D2TryCubePotionClassV17(targetClass)
{
    return D2TryContainerPotionClassV17(targetClass, 3)
}

HealScanRootsV4(h, inv)
{
    roots := [], seen := {}, errors := 0
    for _, off in [0x0C,0x10]
    {
        if (!PickupReadU32V4(h,inv+off,u))
        {
            errors++
            continue
        }
        if (u && !seen.HasKey(u))
        {
            seen[u] := true
            roots.Push(u)
        }
    }
    return {roots:roots,errors:errors}
}

HealScanCandidateV4(h, u, cls, data, inv, targetClass, source)
{
    global pickupCubeTraceUntil
    if (!pickupCubeTraceUntil || A_TickCount>pickupCubeTraceUntil)
        return
    uid := D2ReadU32(h,u+0x0C)
    loc := D2ReadU8V18(h,data+0x45)
    owner := D2ReadU32(h,data+0x5C)
    HealTrace("SCAN_ITEM source=" . source . " target_class=" . targetClass
        . " uid=" . uid . " class=" . cls . " loc=" . loc
        . " owner=" . V92Hex(owner) . " inv=" . V92Hex(inv)
        . " class_match=" . (cls=targetClass) . " owner_match=" . (owner=inv)
        , "scan_" . targetClass . "_" . source . "_" . uid)
}

HealPotionMatchV304(h,cls,itemData,targetClass)
{
    if (!itemData)
        return false
    if (targetClass=1229)
        return (cls=1228 || cls=1229) && D2ReadU8V18(h,itemData)=2
    return cls=targetClass
}

D2TryContainerPotionClassV17(targetClass, wantedLoc45)
{
    ctx := D2OpenHealContextV3()
    if (ctx.reason!="OK")
    {
        HealTrace("CONTAINER_ERROR loc=" . wantedLoc45 . " reason=" . ctx.reason, "container_error")
        return -1
    }
    h := ctx.h, player := ctx.player, inv := ctx.inv, first := ctx.first
    if (!inv)
    {
        DllCall("CloseHandle", "Ptr", h)
        return -1
    }
    scan := HealScanRootsV4(h,inv)
    queue := scan.roots
    readErrors := scan.errors
    itemCount := 0, matchCount := 0
    source := wantedLoc45=0 ? "Ruong" : "Cube"
    HealTrace("SCAN_START source=" . source . " class=" . targetClass
        . " roots=" . queue.Length() . " root_errors=" . readErrors
        . " first=" . V92Hex(D2ReadU32(h,inv+0x0C))
        . " last=" . V92Hex(first), "scan_start_" . source . targetClass)
    seen := {}
    qi := 1
    Loop, 4096
    {
        if (qi > queue.Length())
            break
        u := queue[qi]
        qi++
        if (!u || seen.HasKey(u))
            continue
        seen[u] := 1
        if (!PickupReadU32V4(h,u,typ))
        {
            readErrors++
            continue
        }
        cls := D2ReadU32(h, u + 0x04)
        uid := D2ReadU32(h, u + 0x0C)
        itemData := D2ReadU32(h, u + 0x14)
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
        if (typ=4 && itemData)
        {
            itemCount++
            if (HealPotionMatchV304(h,cls,itemData,targetClass))
                matchCount++
            HealScanCandidateV4(h,u,cls,itemData,inv,targetClass,source)
        }
        if (typ != 4 || !uid || !HealPotionMatchV304(h,cls,itemData,targetClass))
            continue
        loc45 := D2ReadU8V18(h, itemData + 0x45)
        ownerInv := D2ReadU32(h, itemData + 0x5C)
        if (loc45 != wantedLoc45 || ownerInv != inv)
            continue
        playerPath := D2ReadU32(h, player + 0x2C)
        px := playerPath ? D2ReadU16(h, playerPath + 0x02) : 0
        py := playerPath ? D2ReadU16(h, playerPath + 0x06) : 0
        if (!PickupGameActiveV2(ctx.pid))
        {
            DllCall("CloseHandle", "Ptr", h)
            return -1
        }
        HealTrace("CONTAINER_USE uid=" . uid . " class=" . cls . " quality=" . D2ReadU8V18(h,itemData) . " loc=" . wantedLoc45)
        ok := D2RemoteUseInventoryV3(h, uid, px, py)
        HealTrace("CONTAINER_SEND uid=" . uid . " class=" . cls . " loc=" . wantedLoc45 . " sent=" . ok)
        DllCall("CloseHandle", "Ptr", h)
        return ok ? 1 : -1
    }
    DllCall("CloseHandle", "Ptr", h)
    complete := qi>queue.Length() && readErrors=0
    HealTrace("SCAN_END source=" . source . " class=" . targetClass
        . " items=" . itemCount . " class_matches=" . matchCount
        . " read_errors=" . readErrors . " complete=" . complete
        . " result=" . (complete ? "EMPTY" : "READ_ERROR"), "scan_end_" . source . targetClass)
    return complete ? 0 : -1
}

V25UseBeltClassKey(targetClass)
{
    ctx := D2OpenHealContextV3()
    if (ctx.reason!="OK")
    {
        HealTrace("BELT_ERROR class=" . targetClass . " reason=" . ctx.reason, "belt_error")
        return -1
    }
    h := ctx.h, inv := ctx.inv, first := ctx.first
    if (!inv)
    {
        DllCall("CloseHandle", "Ptr", h)
        return -1
    }
    found := false, foundKey := 0, foundX := -1, foundUID := 0
    scan := HealScanRootsV4(h,inv)
    queue := scan.roots
    seen := {}, readErrors := scan.errors, itemCount := 0, matchCount := 0
    HealTrace("SCAN_START source=Belt class=" . targetClass
        . " roots=" . queue.Length() . " root_errors=" . readErrors
        . " first=" . V92Hex(D2ReadU32(h,inv+0x0C))
        . " last=" . V92Hex(first), "scan_start_Belt" . targetClass)

    while (queue.Length() && seen.Count() < 4096)
    {
        u := queue.RemoveAt(1)
        if (!u || seen.HasKey(u))
            continue
        seen[u] := 1

        if (!PickupReadU32V4(h,u,typ))
        {
            readErrors++
            continue
        }
        cls := D2ReadU32(h, u + 0x04)
        itemData := D2ReadU32(h, u + 0x14)

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

        if (typ=4 && itemData)
        {
            itemCount++
            if (HealPotionMatchV304(h,cls,itemData,targetClass))
                matchCount++
            HealScanCandidateV4(h,u,cls,itemData,inv,targetClass,"Belt")
        }
        if (typ != 4 || !HealPotionMatchV304(h,cls,itemData,targetClass))
            continue

        path := D2ReadU32(h, u + 0x2C)
        if (!path)
            continue
        loc45 := D2ReadU8V18(h, itemData + 0x45)
        ownerInv := D2ReadU32(h, itemData + 0x5C)
        x := D2ReadU32(h, path + 0x0C)
        if (loc45 = 255 && ownerInv = inv && x >= 0 && x <= 15)
        {
            found := true
            foundX := x,foundClassV304 := cls
            foundKey := Mod(x, 4) + 1
            foundUID := D2ReadU32(h,u+0x0C)
            break
        }
    }
    incomplete := !found && (queue.Length()>0 || readErrors>0)
    DllCall("CloseHandle", "Ptr", h)
    if (!found)
    {
        HealTrace("BELT_NOT_FOUND class=" . targetClass . " graph_incomplete=" . incomplete
            . " items=" . itemCount . " class_matches=" . matchCount
            . " read_errors=" . readErrors, "belt_not_found_" . targetClass)
        return incomplete ? -1 : 0
    }
    if (!foundUID || !PickupGameActiveV2(ctx.pid))
        return -1
    if (!DeathlordKeyAllowedV29(foundKey) || !GameTargetKeyV63(foundKey))
        return -1
    HealTrace("BELT_PRESS class=" . foundClassV304 . " uid=" . foundUID
        . " slot=" . foundX . " key=" . foundKey . " result=SENT")
    return 1
}


D2OpenHealContextV3()
{
    static cachedPid := 0, cachedBase := 0
        global backgroundPidV63
    pid := backgroundPidV63 ? backgroundPidV63 : D2GetActiveGamePidV95()
    if (!pid)
        return {reason:"GAME_NOT_ACTIVE",pid:0}
    if (pid!=cachedPid || !cachedBase)
    {
        cachedPid := pid
        cachedBase := D2GetModuleBaseV35(pid, "D2Client.dll")
    }
    if (!cachedBase)
        return {reason:"D2CLIENT_NOT_FOUND",pid:pid}
    h := D2OpenProcess(pid)
    if (!h)
        return {reason:"OPEN_GAME_FAILED",pid:pid,error:A_LastError}
    player := D2ReadU32(h,cachedBase+0x11BBFC)
    if (!player)
    {
        DllCall("CloseHandle", "Ptr", h)
        return {reason:"PLAYER_NOT_READY",pid:pid}
    }
    inv := D2ReadU32(h,player+0x60)
    first := inv ? D2ReadU32(h,inv+0x10) : 0
    return {reason:"OK",pid:pid,h:h,player:player,inv:inv,first:first}
}

D2ReadHealVitalsV3()
{
    ctx := D2OpenHealContextV3()
    if (ctx.reason != "OK")
        return {hp:-1,mana:-1,pid:ctx.pid,reason:ctx.reason}
    
    stats := D2ReadU32(ctx.h, ctx.player + 0x5C)
    hp := -1, mana := -1, reason := "STAT_ROOT_NOT_READY"
    
    if (stats)
    {
        hpInfo := MonsterBossProbeHPV2(ctx.h, stats)
        if (hpInfo.ok)
        {
            hp := hpInfo.hp
            reason := "OK"
        }
        
        for _, off in [0x48, 0x24]
        {
            root := D2ReadU32(ctx.h, stats + off)
            count := D2ReadU16(ctx.h, stats + off + 4)
            if (root && count > 0 && count < 512)
            {
                VarSetCapacity(ab, count * 8, 0)
                if (DllCall("ReadProcessMemory", "Ptr", ctx.h, "Ptr", root, "Ptr", &ab, "UPtr", count * 8, "UPtr*", got) && got == count * 8)
                {
                    Loop, %count%
                    {
                        at := (A_Index - 1) * 8
                        layer := NumGet(ab, at, "UShort")
                        statId := NumGet(ab, at + 2, "UShort")
                        value := NumGet(ab, at + 4, "UInt")
                        if (layer = 0 && statId = 8)
                        {
                            mana := Floor(value / 256)
                            break
                        }
                    }
                }
            }
            if (mana >= 0)
                break
        }
    }
    
    DllCall("CloseHandle", "Ptr", ctx.h)
    return {hp:hp,mana:mana,pid:ctx.pid,reason:reason}
}

HealTrace(message, throttleKey:="")
{
    global pickupCubeTraceUntil
    static lastLog := {}, session := 0
    if (!pickupCubeTraceUntil || A_TickCount>=pickupCubeTraceUntil)
        return
    if (session!=pickupCubeTraceUntil)
        lastLog := {}, session := pickupCubeTraceUntil
    if (throttleKey!="")
    {
        if (lastLog.HasKey(throttleKey) && A_TickCount-lastLog[throttleKey]<500)
            return
        lastLog[throttleKey] := A_TickCount
    }
    DebugTraceWrite("heal", message)
}

D2GetCurrentHPV1()
{
    vitals := D2ReadHealVitalsV3()
    return vitals.hp
}

D2RemoteUseInventoryV3(hProcess, unitId, playerX := 0, playerY := 0)
{
    if (RemoteThreadBusyV740(D2GetActiveGamePidV95()))
        return false
    pid := D2GetProcessIdFromHandle(hProcess)
    netBase := pid ? D2GetModuleBaseV35(pid, "D2Net.dll") : 0
    if (!netBase)
        return false
    hUse := DllCall("OpenProcess", "UInt", 0x043A, "Int", 0, "UInt", pid, "Ptr")
    if (!hUse)
        return false
    sendFn := netBase + 0x7650
    remote := DllCall("VirtualAllocEx", "Ptr", hUse, "Ptr", 0, "UPtr", 128, "UInt", 0x3000, "UInt", 0x40, "Ptr")
    if (!remote)
    {
        DllCall("CloseHandle", "Ptr", hUse)
        return false
    }
    VarSetCapacity(pkt, 13, 0)
    NumPut(0x20, pkt, 0, "UChar")
    NumPut(unitId, pkt, 1, "UInt")
    NumPut(playerX, pkt, 5, "UInt")
    NumPut(playerY, pkt, 9, "UInt")
    wrote := 0
    ok1 := DllCall("WriteProcessMemory", "Ptr", hUse, "Ptr", remote+64, "Ptr", &pkt, "UPtr", 13, "UPtrP", wrote)
    VarSetCapacity(code, 32, 0)
    o := 0
    NumPut(0x68, code, o, "UChar"), o += 1
    NumPut(remote+64, code, o, "UInt"), o += 4
    NumPut(0x6A, code, o, "UChar"), o += 1
    NumPut(0x01, code, o, "UChar"), o += 1
    NumPut(0x6A, code, o, "UChar"), o += 1
    NumPut(0x0D, code, o, "UChar"), o += 1
    NumPut(0xB8, code, o, "UChar"), o += 1
    NumPut(sendFn, code, o, "UInt"), o += 4
    NumPut(0xFF, code, o, "UChar"), o += 1
    NumPut(0xD0, code, o, "UChar"), o += 1
    NumPut(0xC3, code, o, "UChar"), o += 1
    wrote2 := 0
    ok2 := DllCall("WriteProcessMemory", "Ptr", hUse, "Ptr", remote, "Ptr", &code, "UPtr", o, "UPtrP", wrote2)
    if (!ok1 || !ok2)
    {
        DllCall("VirtualFreeEx", "Ptr", hUse, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        DllCall("CloseHandle", "Ptr", hUse)
        return false
    }
    th := DllCall("CreateRemoteThread", "Ptr", hUse, "Ptr", 0, "UPtr", 0, "Ptr", remote, "Ptr", 0, "UInt", 0, "UIntP", tid, "Ptr")
    if (!th)
    {
        DllCall("VirtualFreeEx", "Ptr", hUse, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        DllCall("CloseHandle", "Ptr", hUse)
        return false
    }
    waitUse := DllCall("WaitForSingleObject", "Ptr", th, "UInt", 1000)
    waitLimit := 5
    while (waitUse == 258 && IsGameActive() && waitLimit > 0)
    {
        waitUse := DllCall("WaitForSingleObject", "Ptr", th, "UInt", 1000)
        waitLimit--
    }
    RemoteThreadFinishV740(hUse,th,remote,waitUse)
    return waitUse=0
}

D2GetActiveGamePidV95()
{
    hwnd := GameTargetHwndV63()
    if (!hwnd)
        return 0
    WinGet, pid, PID, ahk_id %hwnd%
    return pid+0
}


RareWarningGetHandlerV1:
if (!IsGameForegroundV63())
    return
if (sigBusyV147 || packetWatchArmedV1 || xRunning)
    return
GetNearestGroundItemV83(false)
KeyWait, %rareWarningKeyV1%
return

PickupUiToggleV79:
GuiControlGet, pickupUiStateV79,, PickupEnabledInputV79
pickupManualActiveV827 := false  ; 1 checkbox controls mode, not a manual Farm bypass
PickupEnabledSetV71(pickupUiStateV79)
return

PickupToggleHandlerV79:
if (!IsGameForegroundV63() || !PickupActivateGameV13())
    return
pickupManualActiveV827 := false  ; Do not bypass Farm Tele pickup
PickupEnabledSetV71(!pickupImageOn)
pickupWaitKeyV79 := RegExReplace(pickupToggleKeyV79,"^[~*$<>!^+#]+")
KeyWait, %pickupWaitKeyV79%
return

PickupToggleBindV79()
{
    global pickupToggleKeyV79
    static previous := ""
    if (previous!="")
        BackgroundHotkeyV63("~$" . previous,"PickupToggleHandlerV79","Off UseErrorLevel")
    previous := pickupToggleKeyV79
    if (previous!="")
        BackgroundHotkeyV63("~$" . previous,"PickupToggleHandlerV79","On UseErrorLevel")
}

PickupStopFullV119(reason)
{
    global pickupImageOn,pickupFarmWorkV75,pickupRoundResetV1,pickupLastClick,currentProfile,ConfigFile,pickupGroupActiveV26
    global farmPickupBlockedV57,pickupContextModeV765,sigFailedItemsV765,pending
    if (BossSearchActiveV430())
    {
        farmPickupBlockedV57 := false,pickupImageOn := true
        pickupFarmWorkV75 := false,pickupRoundResetV1 := true,pickupLastClick := 0
        V104CubeLog("ITEM_SEARCH_PICKUP_RETRY reason=" . reason . " next=CHECK_TARGET_INVENTORY_THEN_CUBE pickup=ON")
        return
    }
    if (pickupContextModeV765 = "SIG")
    {
        if (IsObject(pending) && pending.uid)
        {
            if (!IsObject(sigFailedItemsV765))
                sigFailedItemsV765 := {}
            if (!sigFailedItemsV765.HasKey(pending.uid))
            {
                sigFailedItemsV765[pending.uid] := {uid:pending.uid,cls:pending.cls,reason:reason,at:A_TickCount}
                V104CubeLog("SIG_PICKUP_FAIL uid=" . pending.uid . " reason=" . reason)
                FonInfoPushV385("[SIG] Cube đầy, UID " . pending.uid . " không nhặt được. Dọn Cube; tool chạy tiếp khi hết.")
            }
        }
        return
    }
    farmPickupBlockedV57 := true
    pickupFarmWorkV75 := false,pickupRoundResetV1 := true,pickupLastClick := 0
    PickupCtrlEndV26()
    SetTimer, PickupImageTimer, Off
    V104CubeLog("PICKUP_STOP reason=" . reason . " farm=UNCHANGED")
    ToolTipInfoV386("Nhặt lại vẫn dính chuột: rương đầy, dừng nhặt và tiếp tục farm. Dọn rương rồi bật nhặt lại.")
    SetTimer, RemoveToolTip, -3000
}

PickupEnabledSetV71(enabled,keepMode := false,showTip := true)
{
    global pickupBackgroundV181
    if (enabled)
        pickupBackgroundV181 := true
    global pickupOneShotV216 ,pickupImageOn, pickupGroupOnlyV26,pickupDestinationV119, pickupRoundResetV1, pickupLastClick, ConfigFile, currentProfile, pickupGroupActiveV26
    global farmPickupBlockedV57,farmPickupAllowedV57,farmMapPauseV52,pickupManualActiveV827
    pickupImageOn := enabled ? true : false
    if (!pickupImageOn)
        pickupManualActiveV827 := false
    farmPickupAllowedV57 := pickupImageOn && !IsObject(farmMapPauseV52)
    if (enabled)
        farmPickupBlockedV57 := false
	    if (!enabled)
        pickupOneShotV216 := false
        if (enabled && !keepMode)
        PickupCtrlEndV26()
    pickupRoundResetV1 := true, pickupLastClick := 0
    section := ProfileSection(currentProfile)
    state := 1
    IniWrite, %state%, %ConfigFile%, PickupImage, Enabled
    IniWrite, %state%, % ProfileConfigPathV364(section), %section%, PickupImageOn
    IniWrite, %pickupDestinationV119%, % ProfileConfigPathV364(section), %section%, PickupDestination
    IniWrite, %pickupGroupOnlyV26%, % ProfileConfigPathV364(section), %section%, PickupGroupOnly
    if (!GetKeyState("LButton","P") && !GetKeyState("RButton","P"))
        GuiControl, 1:, PickupEnabledInputV79, %pickupImageOn%
    else
        SetTimer, PickupUiRefreshV526, -50
if (pickupImageOn || pickupGroupActiveV26)
    SetTimer, PickupImageTimer, 20
else
{
    SetTimer, PickupImageTimer, Off
    pickupRoundResetV1 := true, pickupLastClick := 0
}
if (showTip)
    {
        ToolTipInfoV386(pickupImageOn ? "NHẶT ITEM: BẬT" : "NHẶT ITEM: TẮT")
        SetTimer, RemoveToolTip, -2000
    }
}

PickupUiRefreshV526:
if (GetKeyState("LButton","P") || GetKeyState("RButton","P"))
{
    SetTimer, PickupUiRefreshV526, -50
    return
}
GuiControl, 1:, PickupEnabledInputV79, %pickupImageOn%
return


V104CubeGroundTimer:
if (!ManualLogActiveV81())
{
    SetTimer, V104CubeGroundTimer, Off
    return
}
if (packetWatchArmedV1)
    return
if (xRunning)
    return
stage := 4 - Ceil((v104CubeExpire - A_TickCount) / 15000)
if (stage != v104Stage && stage >= 1 && stage <= 3)
{
    v104Stage := stage
    ManualLogAppendV81(A_Now . " | PHASE=" . stage . "`r`n", A_ScriptDir . "\Auto-GSF-Cube.log", "UTF-8")
}
if (A_TickCount >= v104CubeExpire)
{
    SetTimer, V104CubeGroundTimer, Off
    ManualLogAppendV81(A_Now . " | CAPTURE_END cube_ground_found=" . v104CubeFound . "`r`n", A_ScriptDir . "\Auto-GSF-Cube.log", "UTF-8")
    return
}
if (!v104CubeFound && V104FindGroundCube(v104CubePid))
    v104CubeFound := true
V104LogItemChanges()
return

V104LogItemChanges()
{
    if (!ManualLogActiveV81())
        return
    global v104Before, v104Stage
    after := V9SnapshotAllItems()
    log := A_ScriptDir . "\Auto-GSF-Cube.log"
    for uid,a in after
    {
        if (a.cls != 1229 && a.cls != 1204)
            continue
        if (!v104Before.HasKey(uid))
        {
            ManualLogAppendV81(A_Now . " | PHASE=" . v104Stage . " ITEM_APPEAR class=" . a.cls . " uid=" . uid . " loc45=" . a.loc . " xy=" . a.x . "," . a.y . " itemDataPtr=" . V92Hex(a.data) . "`r`n", log, "UTF-8")
            continue
        }
        b := v104Before[uid]
        if (b.loc != a.loc || b.x != a.x || b.y != a.y || b.owner != a.owner)
            ManualLogAppendV81(A_Now . " | PHASE=" . v104Stage . " ITEM_MOVE class=" . a.cls . " uid=" . uid . " loc45=" . b.loc . "->" . a.loc . " xy=" . b.x . "," . b.y . "->" . a.x . "," . a.y . " owner=" . V92Hex(b.owner) . "->" . V92Hex(a.owner) . " itemDataPtr=" . V92Hex(a.data) . "`r`n", log, "UTF-8")
    }
    v104Before := after
}

V104FindGroundCube(pid)
{
    if (!ManualLogActiveV81())
        return
    h := D2OpenProcess(pid)
    if (!h)
        return false
    base := D2GetModuleBaseV35(pid, "D2Client.dll")
    player := base ? D2ReadU32(h, base + 0x11BBFC) : 0
    path := player ? D2ReadU32(h, player + 0x2C) : 0
    room := path ? D2ReadU32(h, path + 0x1C) : 0
    rooms := [room], seen := {}
    nearby := room ? D2ReadU32(h, room + 0x08) : 0
    nearCount := room ? D2ReadU32(h, room + 0x0C) : 0
    if (nearby && nearCount > 0 && nearCount <= 32)
    {
        Loop, %nearCount%
        {
            nextRoom := D2ReadU32(h, nearby + (A_Index-1)*4)
            if (nextRoom)
                rooms.Push(nextRoom)
        }
    }
    found := false
    for _,r in rooms
    {
        u := r ? D2ReadU32(h, r + 0x74) : 0
        Loop, 4096
        {
            if (!u || seen.HasKey(u))
                break
            seen[u] := 1
            if (D2ReadU32(h, u + 0x00)=4 && D2ReadU32(h, u + 0x04)=1204)
            {
                uid := D2ReadU32(h, u + 0x0C)
                data := D2ReadU32(h, u + 0x14)
                quality := data ? D2ReadU8V18(h, data + 0x00) : -1
                loc := data ? D2ReadU8V18(h, data + 0x45) : -1
                itemPath := D2ReadU32(h, u + 0x2C)
                x := itemPath ? D2ReadU32(h, itemPath + 0x0C) : -1
                y := itemPath ? D2ReadU32(h, itemPath + 0x10) : -1
                if (uid && quality=2)
                {
                    log := A_ScriptDir . "\Auto-GSF-Cube.log"
                    ManualLogAppendV81(A_Now . " | CUBE_GROUND class=1204 uid=" . uid . " ITEMDATA=" . Format("{:02X}", quality) . " itemDataPtr=" . V92Hex(data) . " unit=" . V92Hex(u) . " loc45=" . loc . " xy=" . x . "," . y . "`r`n", log, "UTF-8")
                    found := true
                    break
                }
            }
            next := D2ReadU32(h, u + 0xE8)
            if (next=u)
                break
            u := next
        }
        if (found)
            break
    }
    DllCall("CloseHandle", "Ptr", h)
    return found
}


GetNearestGroundItemV83(removeMode := false, warningMode := false)
{
    global rareWarningHistoryV16,rareWarningSeenV19,pickupRoundResetV1,pickupLastClick
    if (!removeMode && PickupEditorGetV638())
        return
    PickupFileCleanDuplicateV97()
    outFile := TxtRootPathV816("Item-Nhat.txt")
    bestPid := D2GetActiveGamePidV95()
    bestPlayer := 0
    if (bestPid)
    {
        base := D2GetModuleBaseV35(bestPid, "D2Client.dll")
        h0 := D2OpenProcess(bestPid)
        if (h0)
        {
            bestPlayer := D2ReadU32(h0, base + 0x11BBFC)
            DllCall("CloseHandle", "Ptr", h0)
        }
    }
    if (!bestPid)
    {
        ToolTipInfoV386("GET ID: không tìm thấy nhân vật")
        SetTimer, RemoveToolTip, -2000
        return
    }

    h := D2OpenProcess(bestPid)
    pPath := D2ReadU32(h, bestPlayer + 0x2C)
    px := pPath ? D2ReadU16(h, pPath + 0x02) : 0
    py := pPath ? D2ReadU16(h, pPath + 0x06) : 0
    pRoom := pPath ? D2ReadU32(h, pPath + 0x1C) : 0
    if (!pRoom)
    {
        if (h)
            DllCall("CloseHandle", "Ptr", h)
        ToolTipInfoV386("GET ID: không đọc được Room")
        SetTimer, RemoveToolTip, -2000
        return
    }

    rooms := MonsterLoadedRoomsV20(h,pRoom)

    bestId := 0, bestClass := 0, bestItemData := 0, bestDist := 0x7FFFFFFF, bestX := 0, bestY := 0
    seen := {}
    for ri, room in rooms
    {
        u := D2ReadU32(h, room + 0x74)
        Loop, 4096
        {
            if (!u || seen.HasKey(u))
                break
            seen[u] := 1
            if (D2ReadU32(h, u + 0x00) = 4)
            {
                cls := D2ReadU32(h, u + 0x04)
                uid := D2ReadU32(h, u + 0x0C)
                ip := D2ReadU32(h, u + 0x2C)
                ix := ip ? D2ReadU32(h, ip + 0x0C) : 0
                iy := ip ? D2ReadU32(h, ip + 0x10) : 0
                dx := ix - px, dy := iy - py
                ax := dx < 0 ? -dx : dx
                ay := dy < 0 ? -dy : dy
                d := ax + ay
                mode := D2ReadU32(h,u+0x10)
                if (cls != 1214 && uid && (mode=3 || mode=5) && d < bestDist)
                {
                    itemData := D2ReadU32(h, u + 0x14)
                    bestDist := d, bestId := uid, bestClass := cls, bestItemData := itemData, bestX := ix, bestY := iy
                }
            }
            nx := D2ReadU32(h, u + 0xE8)
            if (nx = u)
                break
            u := nx
        }
    }
    bestQuality := bestItemData ? D2ReadU8V18(h, bestItemData + 0x00) : 0
    bestFileIndex := bestItemData ? D2ReadU32(h, bestItemData + 0x28) : -1
    bestConsumableV7 := bestId ? ConsumablePickupGroupV7(h,bestClass) : ""
    ; Set xanh: xac thuc bang quality 05 va bang Set trong game; khong bat buoc doc chu S.
    bestSetV4 := bestQuality=5 && SetPickupVerifiedV4(h,bestClass,bestItemData)
    bestTierWlvl := 0
    bestTier := (bestQuality=7 && bestFileIndex>=0) ? UniqueItemsTierFromLiveTableV1(h, bestFileIndex, bestTierWlvl) : ""

    if (bestId && bestItemData && ManualLogActiveV81())
        GetGroundItemRawDumpV220(h, bestClass, bestId, bestItemData, bestX, bestY, bestQuality)

    DllCall("CloseHandle", "Ptr", h)

    if (!bestId)
    {
        if (ManualLogActiveV81())
            ManualLogAppendV81(A_Now . " | GET_RESULT no_ground_item=1`r`n", TxtRootPathV816("Auto-GSF-Nhat-Ruong.txt"), "UTF-8")
        ToolTipInfoV386("GET ID: không thấy item dưới đất")
        SetTimer, RemoveToolTip, -2000
        return
    }
    if (!removeMode && ((bestConsumableV7!="" && PickupAutoGroupEnabledV7(bestConsumableV7))
        || (bestSetV4 && PickupAutoGroupEnabledV7("SET_XANH"))
        || (bestQuality=7 && UniqueKnownTierV4(bestTier) && PickupAutoGroupEnabledV7(bestTier))))
    {
        knownNameV4 := bestConsumableV7!="" ? bestConsumableV7 : (bestSetV4 ? "SET XANH" : bestTier)
        ToolTipInfoV386("TỰ NHẶT " . knownNameV4 . " — không cần lưu từng món. GET dùng cho vật phẩm chưa nhận diện.")
        SetTimer, RemoveToolTip, -2500
        return
    }
    if (removeMode && bestQuality>0)
    {
        warningDeletedV35 := true
        if (bestQuality=7)
        {
            UniquePickupRemoveV1(bestClass,bestFileIndex)
            warningDeletedV35 := !UniquePickupHasV1(bestClass,bestFileIndex)
        }
        PickupListRemoveV87(bestClass,bestQuality)
        PickupReloadRAMV97()
        rowsV35 := PickupReadRowsV65("",readOKV35), pickupStillV35 := false
        for _,ruleV35 in rowsV35
            if (ruleV35=(bestClass+0) . "|" . Format("{:02X}",bestQuality+0))
                pickupStillV35 := true
        if (warningDeletedV35 && readOKV35 && !pickupStillV35)
        {
            rareWarningHistoryV16 := [], rareWarningSeenV19 := {}
            pickupRoundResetV1 := true, pickupLastClick := 0
            ToolTipInfoV386("Đã xóa khỏi danh sách nhặt.")
        }
        else
            ToolTipInfoV386("Chưa xóa được khỏi danh sách nhặt. Kiểm tra quyền ghi file.")
        SetTimer, RemoveToolTip, -2500
        RareWarningRenderV16()
        RareWarningScanGroundV23()
        return
    }
    if (bestQuality = 0)
        ToolTipInfoV386("GET BỎ QUA - ITEMDATA=00")
    else if (bestQuality=7 && bestFileIndex>=0)
    {
        if (removeMode)
        {
            if (UniquePickupRemoveV1(bestClass, bestFileIndex))
                ToolTipInfoV386("XÓA UNIQUE - CLASS " . bestClass . " - FileIndex " . bestFileIndex . " - " . bestTier)
            else
                ToolTipInfoV386("UNIQUE CHƯA CÓ - CLASS " . bestClass . " - FileIndex " . bestFileIndex)
        }
        else
        {
            if (UniquePickupAddV1(bestClass, bestFileIndex, bestTier))
                ToolTipInfoV386("THÊM " . bestTier . " - CLASS " . bestClass . " - FileIndex " . bestFileIndex . " - wLvl " . bestTierWlvl)
            else
                ToolTipInfoV386("ĐÃ CÓ " . bestTier . " - CLASS " . bestClass . " - FileIndex " . bestFileIndex)
        }
    }
    else if (removeMode)
    {
        PickupReloadRAMV97()
        if (PickupListRemoveV87(bestClass, bestQuality))
            ToolTipInfoV386("GET KHÔNG NHẶT - CLASS " . bestClass . " - ITEMDATA " . bestQuality)
        else
            ToolTipInfoV386("KHÔNG CÓ DÒNG HOẶC KHÔNG LƯU ĐƯỢC - CLASS " . bestClass . " - ITEMDATA " . bestQuality)
    }
    else
    {
        if (PickupListAddV87(bestClass, bestQuality))
            ToolTipInfoV386("GET THÊM - CLASS " . bestClass . " - ITEMDATA " . bestQuality)
        else
            ToolTipInfoV386("ĐÃ CÓ - CLASS " . bestClass . " - ITEMDATA " . bestQuality)
    }
    SetTimer, RemoveToolTip, -2500
}

GetGroundItemRawDumpV220(h, cls, uid, itemData, ix, iy, quality)
{
    if (!ManualLogActiveV81() || !h || !itemData)
        return

    log := TxtRootPathV816("Auto-GSF-Nhat-Ruong.txt")
    uniqueLog := TxtRootPathV816("UniqueItems-GET.txt")
    fileIndex := D2ReadU32(h, itemData + 0x28)
    uniqueWlvl := 0
    uniqueTier := UniqueItemsTierFromLiveTableV1(h, fileIndex, uniqueWlvl)
    ManualLogAppendV81("`r`n================ GET GROUND ITEM RAW " . A_Now . " ================`r`n", log, "UTF-8")
    ManualLogAppendV81("[GROUND_ITEM] class=" . cls . " uid=" . uid . " ITEMDATA=" . Format("{:02X}", quality) . " itemData=" . V92Hex(itemData) . " xy=" . ix . "," . iy . "`r`n", log, "UTF-8")

    unit := 0
    dataRaw := ""
    Loop, 256
    {
        off := A_Index - 1
        bv := D2ReadU8V18(h, itemData + off)
        dataRaw .= (A_Index=1 ? "" : " ") . Format("{:02X}:{:02X}", off, bv)
    }
    ManualLogAppendV81("  ITEMDATA_BYTES_00_FF " . dataRaw . "`r`n", log, "UTF-8")
    keyLine := "  ITEMDATA_KEY_BYTES quality00=" . Format("{:02X}", D2ReadU8V18(h,itemData+0x00)) . " fileIndex28=" . fileIndex . " raw3F=" . Format("{:02X}",D2ReadU8V18(h,itemData+0x3F)) . " raw40=" . Format("{:02X}",D2ReadU8V18(h,itemData+0x40)) . " raw41=" . Format("{:02X}",D2ReadU8V18(h,itemData+0x41)) . " raw42=" . Format("{:02X}",D2ReadU8V18(h,itemData+0x42)) . " raw43=" . Format("{:02X}",D2ReadU8V18(h,itemData+0x43)) . " raw44=" . Format("{:02X}",D2ReadU8V18(h,itemData+0x44)) . " raw45=" . Format("{:02X}",D2ReadU8V18(h,itemData+0x45)) . " raw46=" . Format("{:02X}",D2ReadU8V18(h,itemData+0x46)) . " raw47=" . Format("{:02X}",D2ReadU8V18(h,itemData+0x47)) . "`r`n"
    ManualLogAppendV81(keyLine, log, "UTF-8")

    uniqueHeader := "`r`n================ UNIQUE ITEM GET " . A_Now . " ================`r`n"
    uniqueInfo := "CLASS=" . cls . " | ITEMDATA=" . Format("{:02X}", quality) . " | FileIndex=" . fileIndex . " | wLvl=" . uniqueWlvl . " | TIER=" . uniqueTier . " | UID=" . uid . " | ITEMDATA_PTR=" . V92Hex(itemData) . " | XY=" . ix . "," . iy . "`r`n"
    uniqueRaw := "ITEMDATA_BYTES_00_FF " . dataRaw . "`r`n"
    FileAppend, %uniqueHeader%, %uniqueLog%, UTF-8
    FileAppend, %uniqueInfo%, %uniqueLog%, UTF-8
    FileAppend, %uniqueRaw%, %uniqueLog%, UTF-8
}

UniquePickupFileV3()
{
    return TxtRootPathV816("Item-Nhat-Unique.txt")
}

RareWarningDecimalV30(value,ByRef result)
{
    value := Trim(value), result := 0
    negative := SubStr(value,1,1)="-"
    if (negative)
        value := SubStr(value,2)
    if (value="")
        return false
    Loop, Parse, value
    {
        digit := Asc(A_LoopField)-48
        if (digit<0 || digit>9)
            return false
        result := result*10+digit
    }
    if (negative)
        result := -result
    return true
}

UniqueRuleParseV18(line,ByRef cls,ByRef q,ByRef idx,ByRef tier)
{
    if (PickupShortParseV638(line,shortName,cls,q))
    {
        idx := -1,tier := shortName
        return true
    }
    cls := 0, q := 7, idx := -1, tier := "", haveClass := false, haveIndex := false, haveQuality := false
    line := PickupColorStripV14(line,ignoredColorV14)
    if (SubStr(Trim(line," `t`r`n" . Chr(0xFEFF)),1,1)="#")
        return false
    for _,part in StrSplit(Trim(line," `t`r`n" . Chr(0xFEFF)),"|")
    {
        equal := InStr(part,"=")
        if (!equal)
            continue
        name := Trim(SubStr(part,1,equal-1)), value := Trim(SubStr(part,equal+1))
        if (name="CLASS")
            haveClass := RareWarningDecimalV30(value,cls)
        else if (name="FILEINDEX")
            haveIndex := RareWarningDecimalV30(value,idx)
        else if (name="ITEMDATA")
        {
            if (SubStr(value,1,2)="0x")
                value := SubStr(value,3)
            q := 0, haveQuality := value!=""
            Loop, Parse, value
            {
                pos := InStr("0123456789ABCDEF",A_LoopField,false)
                if (!pos)
                {
                    haveQuality := false
                    break
                }
                q := q*16+pos-1
            }
        }
        else if (name="TIER")
            tier := value
    }
    if (idx=4294967295)
        idx := -1
    return haveClass && cls>0 && q>0 && (haveIndex || haveQuality)
}

RareWarningLoadV1()
{
    return 0
}

UniqueRememberPickedV18(h,item)
{
    return
}

RareWarningRuleKeyV29(cls,q,fileIndex)
{
    idx := fileIndex+0
    if (idx=4294967295)
        idx := -1
    return Format("{:d}|{:02X}|{:d}",cls+0,q+0,idx)
}

RareWarningShowV1(text,color:="35D06F",key:="")
{
    global rareWarningHistoryV16,rareWarningSeenV19
    if (!IsObject(rareWarningHistoryV16))
        rareWarningHistoryV16 := []
    if (!IsObject(rareWarningSeenV19))
        rareWarningSeenV19 := {}
    key := key="" ? text : key
    fingerprint := text . "|" . color
    if (rareWarningSeenV19.HasKey(key) && rareWarningSeenV19[key]=fingerprint)
        return
    rareWarningSeenV19[key] := fingerprint
    for i,row in rareWarningHistoryV16
    {
        if (row.key=key)
        {
            rareWarningHistoryV16[i] := {key:key,text:text,color:color}
            RareWarningRenderV16()
            return
        }
    }
    rareWarningHistoryV16.Push({key:key,text:text,color:color})
    while (rareWarningHistoryV16.Length()>10)
        rareWarningHistoryV16.RemoveAt(1)
    RareWarningRenderV16()
}

RareWarningRenderV16(refresh:=true)
{
    global RareWarningHeaderV20,RareWarningRowV191,RareWarningRowV192,RareWarningRowV193,RareWarningRowV194,RareWarningRowV195,RareWarningRowV196,RareWarningRowV197,RareWarningRowV198,RareWarningRowV199,RareWarningRowV1910
    static lastPlacement := ""
    global rareWarningHistoryV16,rareWarningHiddenV19
    global rareWarningCreatedV19,rareWarningVisibleV19,rareWarningRuleCountV30,rareWarningFileErrorV30
    previousCriticalV221 := A_IsCritical
    Critical, On
    try
    {
    if (!IsObject(rareWarningHistoryV16))
        rareWarningHistoryV16 := []
    if (rareWarningHiddenV19 || !rareWarningHistoryV16.Length() || !IsGameForegroundV63())
    {
        Gui, RareWarning:Hide
        rareWarningVisibleV19 := false
        return
    }
    hwnd := DllCall("GetForegroundWindow","Ptr")
    VarSetCapacity(rect,16,0), VarSetCapacity(origin,8,0)
    if (!DllCall("GetClientRect","Ptr",hwnd,"Ptr",&rect) || !DllCall("ClientToScreen","Ptr",hwnd,"Ptr",&origin))
        return
    width := Max(96,Floor(NumGet(rect,8,"Int")/8)), textWidth := width-16
    left := NumGet(origin,0,"Int")+8, top := NumGet(origin,4,"Int")+8
    placement := hwnd . "|" . left . "|" . top . "|" . width
    if (!refresh && rareWarningVisibleV19 && placement=lastPlacement)
        return
    lastPlacement := placement
    if (!rareWarningCreatedV19)
    {
        Gui, RareWarning:Destroy
        Gui, RareWarning:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
        Gui, RareWarning:Color, 151A22
        Gui, RareWarning:Font, s9 cD6DFEA, Segoe UI
        Gui, RareWarning:Add, Text, BackgroundTrans x8 y5 w%textWidth% h18 vRareWarningHeaderV20, VẬT PHẨM DƯỚI ĐẤT
        Loop, 10
        {
            y := 25+(A_Index-1)*18
            Gui, RareWarning:Add, Text, BackgroundTrans x8 y%y% w%textWidth% h18 vRareWarningRowV19%A_Index%,
        }
        rareWarningCreatedV19 := true
        Gui, 1:Default
    }
    Loop, 10
    {
        i := A_Index, row := rareWarningHistoryV16[i]
        text := IsObject(row) ? row.text : ""
        color := IsObject(row) ? row.color : "D6DFEA"
        Gui, RareWarning:Font, s9 c%color%, Segoe UI
        GuiControl, RareWarning:Move, RareWarningRowV19%i%, w%textWidth%
        GuiControl, RareWarning:Font, RareWarningRowV19%i%
        GuiControl, RareWarning:, RareWarningRowV19%i%, %text%
    }
    header := rareWarningFileErrorV30!="" ? rareWarningFileErrorV30 : "DS NHẶT | " . rareWarningHistoryV16.Length()
    GuiControl, RareWarning:, RareWarningHeaderV20, %header%
    GuiControl, RareWarning:Move, RareWarningHeaderV20, w%textWidth%
    Gui, RareWarning:Show, x%left% y%top% w%width% h210 NoActivate, Vật phẩm
    rareWarningVisibleV19 := true
    }
    finally
    {
        if (previousCriticalV221)
            Critical, %previousCriticalV221%
        else
            Critical, Off
    }
}

RareWarningScanTimerV23:
RareWarningScanGroundV23()
return

RareWarningScanGroundV23()
{
    global rareWarningHiddenV19,rareWarningSeenV19,rareWarningHistoryV16
    static busy := false, lastSession := "", lastContents := "", lastFileCheck := 0
    global sigBusyV147
    if (busy || sigBusyV147 || rareWarningHiddenV19 || !IsGameForegroundV63())
        return
    busy := true, h := 0
    try
    {
        if (A_TickCount-lastFileCheck>1000 || !lastFileCheck)
        {
            lastFileCheck := A_TickCount
            RareWarningReadTextV35(UniquePickupFileV3(),alertRawV14,false)
            RareWarningReadTextV35(TxtRootPathV816("Item-Nhat.txt"),alertExactV14,false)
            contents := alertRawV14 . Chr(1) . alertExactV14
            if (contents!=lastContents)
            {
                UniquePickupReloadRAMV1()
                PickupReloadRAMV97()
                lastContents := contents
            }
        }
        hwnd := DllCall("GetForegroundWindow","Ptr")
        WinGet, pid, PID, ahk_id %hwnd%
        base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
        h := base ? DllCall("OpenProcess","UInt",0x410,"Int",false,"UInt",pid,"Ptr") : 0
        if (!h)
            return
        player := D2ReadU32(h,base+0x11BBFC)
        path := player ? D2ReadU32(h,player+0x2C) : 0
        room := path ? D2ReadU32(h,path+0x1C) : 0
        if (!room)
            return
        session := pid . "|" . player
        if (session!=lastSession)
        {
            rareWarningSeenV19 := {}, rareWarningHistoryV16 := []
            lastSession := session
            RareWarningRenderV16()
        }
        seen := {}, normal := [], alerts := [], tiers := {}, present := {}
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
                    uid := D2ReadU32(h,u+0x0C), cls := D2ReadU32(h,u+4)
                    data := D2ReadU32(h,u+0x14)
                    q := data ? D2ReadU8V18(h,data) : 0
                    if (uid && cls!=1214 && q>0)
                    {
                        idx := D2ReadU32(h,data+0x28), tier := ""
                        if (q=7)
                        {
                            if (!tiers.HasKey(idx))
                                tiers[idx] := UniqueItemsTierFromLiveTableV1(h,idx,wlvl)
                            tier := tiers[idx]
                        }
                        if (!PickupAlertMatchV14(h,u,cls,q,data,tier,color,label))
                        {
                            u := D2ReadU32(h,u+0xE8)
                            continue
                        }
                        entry := {key:session . "|" . uid, text:label . " | CLASS " . cls . " | " . Format("{:02X}",q) . " | FI " . idx, color:color}
                        red := color="FF3030"
                        present[entry.key] := true
                        if (red)
                            alerts.Push(entry)
                        else
                            normal.Push(entry)
                    }
                }
                next := D2ReadU32(h,u+0xE8)
                if (next=u)
                    break
                u := next
            }
        }
        absent := []
        for key,_ in rareWarningSeenV19
            if (!present.HasKey(key))
                absent.Push(key)
        for _,key in absent
            rareWarningSeenV19.Delete(key)
        retainedV14 := []
        for _,rowV14 in rareWarningHistoryV16
            if (present.HasKey(rowV14.key))
                retainedV14.Push(rowV14)
        rareWarningHistoryV16 := retainedV14
        for _,entry in normal
            RareWarningShowV1(entry.text,entry.color,entry.key)
        for _,entry in alerts
            RareWarningShowV1(entry.text,entry.color,entry.key)
        RareWarningRenderV16()
    }
    finally
    {
        if (h)
            DllCall("CloseHandle","Ptr",h)
        busy := false
    }
}

RareWarningFollowGameV20:
RareWarningRenderV16(false)
return

RareWarningHideChangedV19:
GuiControlGet, rareWarningHiddenV19,, RareWarningHideInputV19
rareWarningHiddenV19 := rareWarningHiddenV19 ? true : false
rareHideSectionV19 := ProfileSection(currentProfile)
IniWrite, %rareWarningHiddenV19%, % ProfileConfigPathV364(rareHideSectionV19), %rareHideSectionV19%, RareWarningHidden
RareWarningRenderV16()
return

UniqueItemsTierFromLiveTableV1(h, fileIndex, ByRef wLvl)
{
    wLvl := 0
    if (!h || fileIndex < 0)
        return "UNKNOWN"
    pid := DllCall("GetProcessId", "Ptr", h, "UInt")
    commonBase := pid ? D2GetModuleBaseV35(pid, "D2Common.dll") : 0
    if (!commonBase)
        return "UNKNOWN"
    sgpt := D2ReadU32(h, commonBase + 0x99E1C)
    if (!sgpt)
        return "UNKNOWN"
    tablePtr := D2ReadU32(h, sgpt + 0xC24)
    tableCount := D2ReadU32(h, sgpt + 0xC28)
    if (!tablePtr || !tableCount || fileIndex >= tableCount)
        return "UNKNOWN"
    record := tablePtr + (fileIndex * 0x14C)
    VarSetCapacity(uniqueRecordV5,0x38,0),uniqueReadV5 := 0
    if (!DllCall("ReadProcessMemory","Ptr",h,"Ptr",record,"Ptr",&uniqueRecordV5,"UPtr",0x38,"UPtr*",uniqueReadV5) || uniqueReadV5!=0x38)
        return "UNKNOWN"
    if (NumGet(uniqueRecordV5,0,"UShort")!=fileIndex)
        return "UNKNOWN"
    wLvl := NumGet(uniqueRecordV5,0x34,"UShort")
    if (wLvl<=1)
    {
        baseCodeV5 := NumGet(uniqueRecordV5,0x28,"UInt")
        if (UniqueLowNormalCodeV6(baseCodeV5))
            return "TU"
        return "UNKNOWN"
    }
    if (wLvl >= 2 && wLvl <= 100)
        return "TU"
    if (wLvl >= 101 && wLvl <= 115)
        return "SU"
    if (wLvl >= 116 && wLvl <= 120)
        return "SSU"
    if (wLvl >= 121)
        return "SSSU"
    return "UNKNOWN"
}

PickupReloadRAMV97()
{
    global pickupAllow,pickupRows,pickupListLoaded,pickupFirstClass,pickupFirstQuality
    global pickupDenyV23,pickupProtectedV65,pickupRoundResetV1
    UniquePickupReloadRAMV1()
    pickupAllow := {},pickupRows := ["1204|02","1734|02","1735|02"],pickupDenyV23 := {},pickupProtectedV65 := {"1204|02":true,"1734|02":true,"1735|02":true}
    pickupFirstClass := 1204,pickupFirstQuality := "02"
    pickupListLoaded := true,pickupRoundResetV1 := true
    return 1
}

PickupParseExactV65(line)
{
    if (!RegExMatch(Trim(line),"i)^CLASS\s*=\s*(\d+)\s*\|\s*ITEMDATA\s*=\s*([0-9A-F]{1,2})\s*$",m))
        return ""
    q := PickupHexTextV25(m2)
    return q!="" && q!="00" ? (m1+0) . "|" . q : ""
}

PickupReadRowsV65(file := "",ByRef readOK := false)
{
    if (file="")
        file := TxtRootPathV816("Item-Nhat.txt")
    readOK := false
    rows := [], seen := {}
    ; Danh sach chua co / khong doc duoc: khong nhat ngoai DS, khong nem loi lam tat luong game.
    if (file="" || !FileExist(file))
        return rows
    try
    {
        FileRead, raw, %file%
    }
    catch readErrV1322
    {
        return rows
    }
    if (ErrorLevel)
        return rows
    readOK := true
    Loop, Parse, raw, `n, `r
    {
        key := PickupParseExactV65(A_LoopField)
        if (key!="" && !seen.HasKey(key))
            rows.Push(key), seen[key] := true
    }
    return rows
}

PickupWriteRowsV65(rows)
{
    file := TxtRootPathV816("Item-Nhat.txt"), temp := file . ".tmp", content := ""
    for _,key in rows
    {
        parts := StrSplit(key,"|")
        content .= "CLASS=" . parts[1] . " | ITEMDATA=" . parts[2] . "`r`n"
    }
    f := FileOpen(temp,"w","UTF-8")
    if (!IsObject(f))
        return false
    written := f.Write(content), f.Close()
    if (content!="" && !written)
        return false
    FileMove, %temp%, %file%, 1
    return !ErrorLevel
}


PickupFilesEnsureV23()
{
    return true
}
PickupOptNameBlockV12(h,unit,cls,q,data)
{
    global pickupOptRulesV12,consumableClassRAMV7
    if (!IsObject(pickupOptRulesV12) || !pickupOptRulesV12.Length() || !h || !unit || !data)
        return false
    cond := false
    for _,rule in pickupOptRulesV12
        if ((!rule.HasKey("exactClassV638") || rule.exactClassV638=cls)
            && (!rule.charmV571 || PickupIsCharmV571(h,cls))
            && (!rule.namedCharmV740 || PickupIsCharmV571(h,cls))
            && (rule.stats.Length() || rule.tiers.Count() || rule.qualities.Count() || rule.eth))
        {
            cond := true
            break
        }
    if (!cond)
        return false
    PickupOptPollV12()
    flags := D2ReadU32(h,data+0x18)
    info := PickupOptReadV12(h,unit,cls,q,data,flags,true)
    if (!IsObject(info) || !info.ok)
        return true
    classKey := info.pid . "|" . cls
    baseName := IsObject(consumableClassRAMV7) && consumableClassRAMV7.HasKey(classKey) ? consumableClassRAMV7[classKey] : ""
    nameHit := false
    fullHit := false
    for _,rule in pickupOptRulesV12
    {
        if (!rule.stats.Length() && !rule.tiers.Count() && !rule.qualities.Count() && !rule.eth)
            continue
        if ((rule.HasKey("exactClassV638") && rule.exactClassV638!=cls)
            || ((rule.charmV571 || rule.namedCharmV740) && !PickupIsCharmV571(h,cls)))
            continue
        if (rule.charmV571)
        {
            if (!PickupIsCharmV571(h,cls))
                continue
            nameHit := true
            full := rule.stats.Length() ? PickupOptReadV12(h,unit,cls,q,data,flags) : info
            if (IsObject(full) && full.ok && PickupOptRuleMatchV12(rule,q,flags,full.name,full.stats,baseName,h,cls))
                fullHit := true
            continue
        }
        if (!CubeNameMatchV12(rule, info.name, baseName))
            continue
        nameHit := true
        full := rule.stats.Length() ? PickupOptReadV12(h,unit,cls,q,data,flags) : info
        if (IsObject(full) && full.ok && PickupOptRuleMatchV12(rule,q,flags,full.name,full.stats,baseName,h,cls))
            fullHit := true
    }
    return nameHit && !fullHit
}

CubeNameMatchV12(rule, name, baseName)
{
    if (RegExMatch(name . "`n" . baseName, "im)" . rule.name))
        return true
    raw := rule.raw
    if (RegExMatch(raw, "^\s*""([^""]+)""", m))
        literal := m1
    else
    {
        pos := RegExMatch(raw, "[\[\{]")
        literal := pos ? SubStr(raw, 1, pos - 1) : raw
        literal := Trim(literal)
    }
    literal := CubeNameNormV12(literal)
    if (literal = "")
        return false
    return InStr(CubeNameNormV12(name), literal) || InStr(CubeNameNormV12(baseName), literal)
}

CubeNameNormV12(s)
{
    s := RegExReplace(s, "['''''`´]", "")
    StringLower, s, s
    return Trim(RegExReplace(s, "\s+", " "))
}

; Cache exact class+quality rows, re-read at most once per second when the user edits the list.
; Missing/invalid list must NOT mean 'pick everything'.
PickupSigListExactV1321(cls,q)
{
    static cacheV1321 := {},checkedAtV1321 := 0,loadedV1321 := false
    if (!loadedV1321 || A_TickCount-checkedAtV1321>=1000)
    {
        rowsV1321 := PickupReadRowsV65("",readOkV1321)
        cacheV1321 := {}
        if (readOkV1321)
            for _,keyV1321 in rowsV1321
                cacheV1321[keyV1321] := true
        checkedAtV1321 := A_TickCount,loadedV1321 := true
    }
    return cacheV1321.HasKey((cls+0) . "|" . Format("{:02X}",q+0))
}

PickupFileHasRuleV97(cls,q,itemData:=0,h:=0,unit:=0)
{
    global pickupAllow, pickupProtectedV65, pickupListLoaded, pickupGroupOnlyV26,pickupDestinationV119,pickupExcludeClassesV329,pickupExactAlertsV14
    
    if (unit && PickupFarmSkipUnitV762(h,unit))
        return false
    if (!pickupListLoaded)
        PickupReloadRAMV97()
    if (IsObject(pickupExcludeClassesV329) && pickupExcludeClassesV329.HasKey(cls+0))
        return false
    if (PickupExcludedByNameV490(h,unit,cls,q,itemData))
        return false
    if (q+0=5 && !SetPickupVerifiedV4(h,cls,itemData))
        return false

    if (unit && PickupOptNameBlockV12(h,unit,cls,q,itemData))
        return false

    ; Only after a successful SIG, ordinary pickup uses Item-Nhat.txt EXACTLY.
    ; Do not restrict Farm pickup or SIG-owned recovery with this switch.
    global pickupSigListOnlyV1321,sigSessionActiveV1321,sigBusyV147
    if (pickupSigListOnlyV1321 && !sigSessionActiveV1321 && !sigBusyV147
        && !SigPickupOwnedV764() && !FarmControlRunningV186())
        return PickupSigListExactV1321(cls,q)

    if (Stage2CommonPickupTargetV420(cls,q))
        return true
    if (q+0=2 && (cls=1204 || cls=1734 || cls=1735))
        return true


    if (!pickupListLoaded)
        PickupReloadRAMV97()

    if (IsObject(pickupExactAlertsV14) && pickupExactAlertsV14.HasKey(RareWarningRuleKeyV29(cls,q,-1)))
        return true
    if (unit && PickupOptMatchV12(h,unit,cls,q,itemData))
        return true
    
    ; Set xanh mac dinh: quality=05 + Set table, khong cho van de doc ten S chan nhat.
    if (q+0=5 && PickupAutoGroupEnabledV7("SET_XANH")
        && SetPickupVerifiedV4(h,cls,itemData))
        return true
    
    if (q+0=7 && itemData && h)
    {
        tierV4 := UniqueItemsTierFromLiveTableV1(h,D2ReadU32(h,itemData+0x28),wlvlV4)
        if (UniqueKnownTierV4(tierV4))
            return true
    }
    
    if (h && PickupIsCharmV571(h,cls))
        return true
        
    consumableGroupV7 := ConsumablePickupGroupV7(h,cls)
    if (consumableGroupV7!="")
        return true
    if (PickupCatalogMatchV645(h,unit,cls,q,itemData))
        return true

    return false
}


PickupCatalogMatchV645(h,unit,cls,q,data)
{
    global pickupAutoGroupsV7,consumableClassRAMV7
    if (!h || !IsObject(pickupAutoGroupsV7))
        return false
    pid := DllCall("GetProcessId","Ptr",h,"UInt"),key := pid . "|" . cls
    baseName := IsObject(consumableClassRAMV7) && consumableClassRAMV7.HasKey(key) ? consumableClassRAMV7[key] : ""
    needsName := false
    for group,_ in pickupAutoGroupsV7
    {
        if (SubStr(group,1,5)!="NAME:" && SubStr(group,1,7)!="FILTER:")
            continue
        if (PickupAlertGroupMatchV14(group,q,"",false,baseName))
            return true
        needsName := true
    }
    if (!needsName || !unit || !data)
        return false
    PickupOptPollV12()
forceStats := (q=5 || q=7 || q=8)
info := PickupOptReadV12(h,unit,cls,q,data,D2ReadU32(h,data+0x18),forceStats)
    if (!IsObject(info) || !info.ok)
        return false
    for group,_ in pickupAutoGroupsV7
        if ((SubStr(group,1,5)="NAME:" || SubStr(group,1,7)="FILTER:")
            && PickupAlertGroupMatchV14(group,q,"",false,info.name . "`n" . baseName))
            return true
    return false
}

PickupFileCountV97()
{
    global pickupRows,pickupListLoaded
    if (!pickupListLoaded)
        PickupReloadRAMV97()
    return pickupRows.Length()
}

PickupFileFirstRuleV97(ByRef firstCls,ByRef firstQ)
{
    global pickupFirstClass, pickupFirstQuality, pickupListLoaded
    if (!pickupListLoaded)
        PickupReloadRAMV97()
    firstCls := pickupFirstClass, firstQ := pickupFirstQuality
    return firstQ!=""
}

PickupFileStashOnlyV97(cls,q,h:=0)
{
    global pickupProtectedV65, pickupListLoaded,pickupDestinationV119,pickupToCubeV37,pickupGroupActiveV26
    if (h && PickupIsCharmV571(h,cls))
        return true
    if (Stage2CommonPickupTargetV420(cls,q))
        return false
    if (!pickupGroupActiveV26 && !pickupToCubeV37)
        return true
    if (pickupDestinationV119="STASH")
        return true
    if (!pickupListLoaded)
        PickupReloadRAMV97()
    return pickupProtectedV65.HasKey((cls+0) . "|" . Format("{:02X}",q+0))
}

PickupFileAddV97(cls,q)
{
    global pickupRoundResetV1, pickupLastClick
    if (q<=0)
        return false
    PickupFilesEnsureV23()
    rows := PickupReadRowsV65("",readOK)
    if (!readOK)
        return false
    key := (cls+0) . "|" . Format("{:02X}",q+0)
    for _,existing in rows
        if (existing=key)
        {
            PickupReloadRAMV97()
            return false
        }
    rows.Push(key)
    if (!PickupWriteRowsV65(rows))
        return false
    PickupReloadRAMV97()
    pickupRoundResetV1 := true, pickupLastClick := 0
    return true
}

PickupFileRemoveV97(cls,q)
{
    global pickupRoundResetV1, pickupLastClick
    if (q<=0)
        return false
    PickupFilesEnsureV23()
    rows := PickupReadRowsV65("",readOK)
    if (!readOK)
        return false
    key := (cls+0) . "|" . Format("{:02X}",q+0), found := 0
    for i,existing in rows
        if (existing=key)
        {
            found := i
            break
        }
    if (!found)
    {
        PickupReloadRAMV97()
        return false
    }
    last := rows.Length()
    if (found!=last)
        rows[found] := rows[last]
    rows.RemoveAt(last)
    if (!PickupWriteRowsV65(rows))
        return false
    PickupReloadRAMV97()
    pickupRoundResetV1 := true, pickupLastClick := 0
    return true
}

PickupFileCleanDuplicateV97()
{
    return PickupReloadRAMV97()
}

PickupListLoadV87()
{
    PickupFileCleanDuplicateV97()
    return PickupReloadRAMV97()
}

PickupListAddV87(cls, q)
{
    return PickupFileAddV97(cls, q)
}

PickupListRemoveV87(cls, q)
{
    return PickupFileRemoveV97(cls, q)
}

D2ReadU8V18(hProc, addr)
{
    VarSetCapacity(buf, 1, 0)
    if (!DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 1, "UPtr*", got))
        return 0
    return NumGet(buf, 0, "UChar")
}

FarmPickupSyncV57(livePid := 0,liveLevel := 0,liveMode := -1,force := false)
{
    global sigBusyV147
    if (sigBusyV147 || SigPickupOwnedV764())
        return false
    global pickupImageOn,pickupGroupActiveV26,pickupRoundResetV1,pickupFarmWorkV75
    global farmMapPauseV52,autoMonsterAttackOn,scosEntryV162,stageTwoV166,sigTownV148
    global mapFarmStartPendingV170,backgroundPidV63,townLevelV22,farmPickupBlockedV57,farmPickupAllowedV57
    static managed := false,lastWanted := false
    wasManaged := managed
    running := FarmControlRunningV186()
    if (!running && !managed)
        return true
    managed := running
    wanted := false
    global cainPausedV10
    if (running && !cainPausedV10 && !IsObject(farmMapPauseV52) && BackgroundValidV63())
    {
        level := liveLevel,mode := liveMode
        if (livePid!=backgroundPidV63 || !level || mode<0)
        {
            pid := backgroundPidV63,base := D2GetModuleBaseV35(pid,"D2Client.dll")
            h := base ? D2OpenProcess(pid) : 0
            if (!h)
                return farmPickupAllowedV57
            try
            {
                player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
                if (!MonsterBossProbeReadV1(h,path,0x20,pb))
                    return farmPickupAllowedV57
                level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt")),mode := D2ReadU32(h,player+0x10)
                if (!level)
                    return farmPickupAllowedV57
            }
            finally
                DllCall("CloseHandle","Ptr",h)
        }
        town := FarmReviveTownLevelV295(level)
        if (town)
        {
            lastWanted := pickupImageOn
            farmPickupAllowedV57 := pickupImageOn && !farmPickupBlockedV57
            return true
        }
        wanted := level && mode!=0 && mode!=17 && Stage2PickupEnabledV9()
    }
    transition := force || running!=wasManaged || wanted!=lastWanted
    if (transition && wanted)
        farmPickupBlockedV57 := false
    ; Farm must only calculate its pickup permission. Do NOT toggle Nhặt UI here:
    ; one checkbox controls both modes; Farm runs Tele, SIG handles its own loop.
    lastWanted := wanted
    farmPickupAllowedV57 := wanted && pickupImageOn && !farmPickupBlockedV57
    if (!wanted)
        pickupFarmWorkV75 := false
    return farmPickupAllowedV57
}

PickupImageTimer:
if (farmUserPausedV2026 && FarmControlRunningV186())
    return
; Normal pickup must not run while the SIG session is active.
; SIG recovery uses its separate direct pickup flow.
if (sigSessionActiveV1321 || SigPickupOwnedV764() || sigBusyV147)
    return
; Farm owns every item pickup while running. The timer signals the item
; position only; Farm's center/approach movement and Tele must happen first.
if (FarmControlRunningV186())
{
    if (pickupImageOn && autoMonsterAttackOn && Stage2PickupEnabledV9())
    {
        activePickupPidV806 := D2GetActiveGamePidV95()
        farmPickupPhaseV806 := activePickupPidV806 && FarmCenterPendingV741(activePickupPidV806)
            && farmCenterCycleV741.phase="PICKUP_BUSY"
        if (!farmPickupPhaseV806)
            FarmPickupDetectOnlyV903(activePickupPidV806)
    }
    return
}
if (buffSequenceRunningV555)
    return
if (IsObject(scosEntryV162) && scosEntryV162.map="BO"
    && (scosEntryV162.phase="FARM" || scosEntryV162.phase="PORTAL" || scosEntryV162.phase="LOAD" || scosEntryV162.phase="RETURN_MATERIAL"))
    return
if (sigBusyV147)
    return
if (FarmControlRunningV186() && (IsObject(farmMapPauseV52) || (!farmPickupAllowedV57 && !pickupManualActiveV827)))
    return
if (packetWatchArmedV1)
    return
if (xRunning)
    return
if (!pickupImageOn && !pickupGroupActiveV26)
{
    SetTimer, PickupImageTimer, Off
    pickupRoundResetV1 := true
    return
}
if (pickupTimerBusy)
    return
if (!IsGameActive())
    return
if (!GameItemActionBeginV4("Pickup", "cube"))
    return
pickupTimerBusy := true
try
{
    PickupV61Tick()
}
finally
{
    pickupTimerBusy := false
    GameItemActionEndV4("Pickup")
}
return


; Timer nhat phat hien do trong tam nhat; Farm tu quyet dinh luc ban giao nhat.
FarmPickupDetectOnlyV903(pid)
{
    global farmItemLockV625,pickupRadius,pickupImageOn,autoMonsterAttackOn
    global pickupGroupActiveV26, farmCenterCycleV741
    if (!pid || !autoMonsterAttackOn || !pickupImageOn || pickupGroupActiveV26
        || !Stage2PickupEnabledV9() || BOCommonActiveV444(pid))
        return false
    if (IsObject(farmItemLockV625))
        return true
    h := D2OpenProcess(pid)
    if (!h)
        return false
    found := false
    try
    {
        base := D2GetModuleBaseV35(pid,"D2Client.dll")
        player := base ? D2ReadU32(h,base+0x11BBFC) : 0
        path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!player || !path || !MonsterBossProbeReadV1(h,path,0x20,pp))
            return false
        level := CoordLevelV14(h,NumGet(pp,0x1C,"UInt"))
        room := NumGet(pp,0x1C,"UInt")
        px := NumGet(pp,2,"UShort"), py := NumGet(pp,6,"UShort")
        if (!level || !room || FarmReviveTownLevelV295(level))
            return false
        best := 0x7FFFFFFF
        itemScanRadiusV903 := Max(1,pickupRadius)
        seen := {}
        for _,ir in MonsterLoadedRoomsV20(h,room)
        {
            if (!MonsterBossProbeReadV1(h,ir+0x74,4,head))
                continue
            iu := NumGet(head,0,"UInt")
            Loop, 1024
            {
                if (!iu || seen.HasKey(iu))
                    break
                seen[iu] := true
                if (!MonsterBossProbeReadV1(h,iu,0xEC,itemBuf))
                    break
                if (D2ReadU32(h,iu)=4)
                {
                    idata := D2ReadU32(h,iu+0x14)
                    imode := D2ReadU32(h,iu+0x10)
                    icls := D2ReadU32(h,iu+4)
                    if (idata && icls!=1214 && (imode=3 || imode=5))
                    {
                        ip := D2ReadU32(h,iu+0x2C)
                        if (ip && MonsterBossProbeReadV1(h,ip,0x14,ib))
                        {
                            ix := NumGet(ib,0x0C,"UInt"), iy := NumGet(ib,0x10,"UInt")
                            dist := (ix-px)**2+(iy-py)**2
                            if (dist<=itemScanRadiusV903**2 && dist<best
                                && !FarmPickupTimedIgnoreV1602(pid,level,D2ReadU32(h,iu+0x0C))
                                && PickupFileHasRuleV97(icls,D2ReadU8V18(h,idata),idata,h,iu))
                            {
                                best := dist, fx := ix, fy := iy
                                foundUidV1602 := D2ReadU32(h,iu+0x0C),foundClsV1602 := icls
                                found := true
                            }
                        }
                    }
                }
                next := D2ReadU32(h,iu+0xE8)
                if (next=iu)
                    break
                iu := next
            }
        }
        if (found && !IsObject(farmItemLockV625))
        {
            ; ITEM_PICKUP_10S: Track this UID from the first approach.
            r := Max(1,pickupRadius)
            farmItemLockV625 := {pid:pid,player:player,level:level,x:fx,y:fy
                ,uid:foundUidV1602,cls:foundClsV1602,startedAtV1602:A_TickCount
                ,radiusSq:r*r,pickupRadiusSqV648:Max(1,pickupRadius)**2
                ,source:"PICKUP_TIMER_SIGNAL",row:0}
            ; Timer chi khoa item da nam trong tam nhat; Farm se nhat tai cho.
            AutoMonsterAttackLogV2("PICKUP_TIMER_SIGNAL item=" . fx . "," . fy . " next=PICKUP_IN_RANGE")
        }
    }
    finally
        DllCall("CloseHandle","Ptr",h)
    return found
}

; PICKUP_FIX_2026: A failed UID may cool down briefly, never be ignored
; for the whole farm/map. Old Boolean skip values from older code also expire.
FarmPickupTimedIgnoreV1602(pid,level,uid)
{
    global farmPickupTimedSkippedV1602,farmRunEpochV535
    if (!pid || !level || !uid || !IsObject(farmPickupTimedSkippedV1602))
        return false
    key := pid . "|" . farmRunEpochV535 . "|" . level . "|" . uid
    if (!farmPickupTimedSkippedV1602.HasKey(key))
        return false
    expires := farmPickupTimedSkippedV1602[key]
    if (expires=1 || !expires || A_TickCount>=expires)
    {
        farmPickupTimedSkippedV1602.Delete(key)
        return false
    }
    return true
}

FarmPickupTimedSkipV1602(pid,level,uid,reason)
{
    global farmPickupTimedSkippedV1602,farmRunEpochV535
    if (!pid || !level || !uid)
        return false
    if (!IsObject(farmPickupTimedSkippedV1602))
        farmPickupTimedSkippedV1602 := {}
    ; Short cooldown only. Never remove a loot UID for the rest of the run.
    farmPickupTimedSkippedV1602[pid . "|" . farmRunEpochV535 . "|" . level . "|" . uid] := A_TickCount+2000
    PortalLogWriteV66("FARM_PICKUP_RETRY_COOLDOWN uid=" . uid . " level=" . level
        . " reason=" . reason . " retry_after_ms=2000")
    return true
}

FarmItemGoalValidV655(goal)
{
    global farmItemLockV625,autoMonsterAttackOn,backgroundPidV63
    return IsObject(goal) && goal.itemReturnV655 && autoMonsterAttackOn
        && IsObject(farmItemLockV625) && farmItemLockV625.returnGoalV655=goal
        && farmItemLockV625.pid=goal.pid && goal.pid=backgroundPidV63
        && farmItemLockV625.level=goal.level
}

CoordRecoveryGoalValidV655(goal)
{
    global coordGoV59
    return IsObject(goal) && (FarmItemGoalValidV655(goal) || coordGoV59=goal)
}

; ITEM_ESCAPE_20261029: one live owner for stuck recovery. Do not use the
; standard item approach/retreat while the recovery sequence is running.
FarmItemEscapeActiveV20261029(pid := 0)
{
    global farmItemLockV625
    if (!IsObject(farmItemLockV625))
        return false
    goal := farmItemLockV625.returnGoalV655
    return FarmItemGoalValidV655(goal) && (!pid || goal.pid=pid)
        && IsObject(goal.routeV392) && IsObject(goal.routeV392.escapeV84)
}

FarmItemReturnV648(h,ByRef pb,pid,level,px,py)
{
    global farmItemLockV625,pickupRadius,farmCenterCycleV741
    area := farmItemLockV625
    if (!IsObject(area) || area.pid!=pid || area.level!=level)
        return false
    x := area.pickupX>0 ? area.pickupX : area.x
    y := area.pickupY>0 ? area.pickupY : area.y
    arrivalRadiusV1801 := Max(1,pickupRadius)
    distSqV1801 := (px-x)**2+(py-y)**2
    if (distSqV1801<=arrivalRadiusV1801**2)
    {
        area.returnGoalV655 := false
        return false
    }
    PortalLogWriteV66("FARM_PICKUP_SKIP_OUT_OF_RANGE uid=" . area.uid
        . " item=" . x . "," . y . " player=" . px . "," . py
        . " radius=" . arrivalRadiusV1801 . " next=RESUME_ROUTE")
    farmItemLockV625 := false
    if (FarmCenterPendingV741(pid) && farmCenterCycleV741.phase="ITEM_MOVE")
    {
        farmCenterCycleV741.phase := "CHECK"
        farmCenterCycleV741.pickupStateV905 := "DONE"
        farmCenterCycleV741.pickupResultV905 := "OUT_OF_RANGE"
    }
    return false
}

FarmApproachScanV722(h,player,pid,centerMoveProbeV2026:=false)
{
    global autoMonsterAttackOn,cainNoFightV361,roomExploreV89,monsterRadiusV48
    global farmApproachV722,farmScanListV682,farmReviveV32,farmBuffExclusiveV621,buffSequenceRunningV555
    global farmCenterCycleV741,farmItemLockV625
    farmApproachV722 := false
    ; BC_LOG_FIX: route B->C is already owned by FarmCenterCheckV741(mainTurn=true).
    ; This scan is called AGAIN from NativeMovePointV14. Previously its nested
    ; FarmCenterCheckV741(mainTurn=false) returned true for MOVE, which made
    ; the approach scan report complete=false and blocked the same route move.
    ; Keep item guard authoritative: never bypass a pending item pickup signal.
    if (!centerMoveProbeV2026 && FarmCenterPendingV741(pid)
        && farmCenterCycleV741.phase="MOVE" && !FarmItemRoutePausedV903(pid))
        return false
    pickupPassV750 := FarmCenterPendingV741(pid) && farmCenterCycleV741.phase="PICKUP_BUSY"
    if (!centerMoveProbeV2026 && !pickupPassV750 && FarmCenterCheckV741(h,player,pid))
        return {pid:pid,player:player,complete:false,rows:[],closeRows:[],target:false,at:A_TickCount}
    if (!autoMonsterAttackOn || !Stage2FightEnabledV9() || cainNoFightV361 || IsObject(roomExploreV89)
        || IsObject(farmReviveV32) || farmBuffExclusiveV621 || buffSequenceRunningV555
        || BOCommonActiveV444(pid) || BOFinalRouteActiveV451(pid) || BossSearchActiveV430(pid) || CainHuntActiveV403())
        return false
    radiusV722 := Max(1,MonsterRadiusGetV239())
    scan := {pid:pid,player:player,level:0,at:A_TickCount,complete:false,rows:[],closeRows:[],target:false
        ,radiusSq:radiusV722*radiusV722}
    farmApproachV722 := scan
    if (!MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,pp))
        return scan
    level := CoordLevelV14(h,NumGet(pp,0x1C,"UInt")),mode := D2ReadU32(h,player+0x10)
    if (!level || mode=0 || mode=17)
        return scan
    if (FarmReviveTownLevelV295(level))
        return false
    scan.level := level,scan.x := NumGet(pp,2,"UShort"),scan.y := NumGet(pp,6,"UShort")
    if (IsObject(farmItemLockV625) && farmItemLockV625.pid=pid
        && farmItemLockV625.player=player && farmItemLockV625.level=level)
        scan.x := farmItemLockV625.x,scan.y := farmItemLockV625.y,scan.radiusSq := farmItemLockV625.radiusSq
    farmScanListV682 := scan.rows
    rooms := MonsterLoadedRoomsV20(h,NumGet(pp,0x1C,"UInt"))
    if (!IsObject(rooms) || !rooms.Length())
        return scan
    seen := {},complete := true,total := 0,start := A_TickCount,bkSq := scan.radiusSq
    for _,r in rooms
    {
        if (!MonsterBossProbeReadV1(h,r+0x74,4,head))
        {
            complete := false
            continue
        }
        u := NumGet(head,0,"UInt")
        Loop, 1024
        {
            if (!u || seen.HasKey(u))
                break
            if (total>=2048 || A_TickCount-start>80)
                return scan
            seen[u] := true,total++
            if (!MonsterBossProbeReadV1(h,u,0xEC,ub))
            {
                complete := false
                break
            }
            unit := u,u := NumGet(ub,0xE8,"UInt")
            uid := NumGet(ub,12,"UInt"),mode := NumGet(ub,16,"UInt"),cls := NumGet(ub,4,"UInt")
            if (NumGet(ub,0,"UInt")=1 && uid && mode!=0 && mode!=12 && !MonsterClassExcludedV11(cls,h,unit))
            {
                if (!MonsterBossProbeReadV1(h,NumGet(ub,0x2C,"UInt"),0x20,mp))
                    complete := false
                else if (CoordLevelV14(h,NumGet(mp,0x1C,"UInt"))=level)
                {
                    x := NumGet(mp,2,"UShort"),y := NumGet(mp,6,"UShort"),dist := (x-scan.x)**2+(y-scan.y)**2
                    if (dist<=bkSq && !MonsterRetryExcludedV44(uid,x,y,level,pid))
                    {
                        a := {unit:unit,uid:uid,path:NumGet(ub,0x2C,"UInt"),dist:dist,x:x,y:y,level:level
                            ,priority:BossPriorityHasV221(cls),cls:cls}
                        scan.rows.Push(a)
                        if (dist<=scan.radiusSq)
                        {
                            scan.closeRows.Push(a)
                            if (!IsObject(scan.target) || dist<scan.target.dist)
                                scan.target := a
                        }
                    }
                }
            }
            if (A_Index=1024 && u)
                complete := false
        }
    }
    identity := MapLiveIdentityV399(pid,level)
    if (!IsObject(identity) || !MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,endPP)
        || CoordLevelV14(h,NumGet(endPP,0x1C,"UInt"))!=level)
        return scan
    scan.complete := complete,scan.at := A_TickCount
    farmScanListV682 := scan.rows
    global farmScanSelectedV682
    farmScanSelectedV682 := IsObject(scan.target) ? scan.target.uid : 0
    FarmCombatViewV624(pid,scan.target,IsObject(scan.target) ? "có quái quanh nhân vật; chờ lượt đánh" : complete ? "chưa thấy quái quanh nhân vật" : "đang đọc lại quái quanh nhân vật")
    return scan
}

FarmPickupFirstV75()
{
    global sigBusyV147
    if (sigBusyV147)
        return false
    global farmPickupAllowedV57,farmMapPauseV52,farmPickupBlockedV57,farmCenterCycleV741,pickupManualActiveV827
    global pickupImageOn, pickupTimerBusy, pickupFarmWorkV75, portalExitPendingV69, reviveBuffPendingV34
    pidV806 := D2GetActiveGamePidV95()
    centerPickupV806 := pidV806 && FarmCenterPendingV741(pidV806)
        && farmCenterCycleV741.phase="PICKUP_BUSY"
    if (FarmControlRunningV186() && (IsObject(farmMapPauseV52)
        || (!farmPickupAllowedV57 && !pickupManualActiveV827 && !(centerPickupV806 && pickupImageOn
            && Stage2PickupEnabledV9() && !farmPickupBlockedV57))))
        return false
    if (!pickupImageOn)
    {
        pickupFarmWorkV75 := false
        return false
    }
    global pickupGroupActiveV26,farmCenterCycleV741
    pidV741 := D2GetActiveGamePidV95()
    if (pidV741 && FarmControlRunningV186() && FarmCenterPolicyV741(pidV741)
        && !pickupGroupActiveV26 && !pickupManualActiveV827
        && (!FarmCenterPendingV741(pidV741) || farmCenterCycleV741.phase!="PICKUP_BUSY"))
        return false
    if (IsObject(portalExitPendingV69) || reviveBuffPendingV34)
        return false
    if (pickupTimerBusy || !AutoMonsterPacketCleanupV1())
        return pickupFarmWorkV75 ? true : false
    if (!GameItemActionBeginV4("Pickup", "cube"))
        return true
    pickupTimerBusy := true
    try
        PickupV61Tick()
    finally
    {
        pickupTimerBusy := false
        GameItemActionEndV4("Pickup")
    }
    if (pickupImageOn && pickupFarmWorkV75)
    {
        AutoMonsterAttackLogV2("FARM_PICKUP_PRIORITY route=PAUSED until=QUEUE_AND_CURSOR_DONE",true)
        return true
    }
    return false
}

PickupV61Tick()
{
    global rareWarningKeyV1,ticketPickupWaitV279
    global pickupRoundResetV1,pickupFarmWorkV75,pickupGroupActiveV26,pickupManualActiveV827
    static idleScanAtV590 := 0,idleScanPidV590 := 0
    static privilegeChecked := false, cachedPid := 0, cachedBase := 0, lastPlayer := 0
    static throttleAtV690 := 0
    if (A_PtrSize != 4)
        return
    if (FarmControlRunningV186() && !pickupGroupActiveV26 && !pickupFarmWorkV75
        && !pickupRoundResetV1 && !IsObject(ticketPickupWaitV279)
        && A_TickCount - throttleAtV690 < 60)
        return
    throttleAtV690 := A_TickCount
    if (!privilegeChecked)
    {
        D2EnableDebugPrivilege()
        privilegeChecked := true
    }
    activePid := D2GetActiveGamePidV95()
    if (!activePid)
        return
    if (FarmControlRunningV186() && !pickupFarmWorkV75 && !pickupGroupActiveV26 && !pickupRoundResetV1)
    {
        if (idleScanPidV590=activePid && A_TickCount-idleScanAtV590<150)
            return
        idleScanPidV590 := activePid,idleScanAtV590 := A_TickCount
    }
    sigPickupV670 := IsObject(ticketPickupWaitV279) && ticketPickupWaitV279.sigScopeV654
        && ticketPickupWaitV279.pid=activePid
    if (!sigPickupV670 && FarmControlRunningV186() && !FarmReviveTownLevelV295(RoomRecordLevelV259(activePid)))
        if (!FonEnsureLiveV410(activePid))
            return
    global farmCenterCycleV741
    if (!sigPickupV670 && FarmControlRunningV186() && FarmCenterPolicyV741(activePid)
        && !pickupGroupActiveV26 && !pickupManualActiveV827
        && (!FarmCenterPendingV741(activePid) || farmCenterCycleV741.phase!="PICKUP_BUSY"))
        return
    if (activePid != cachedPid || !cachedBase)
    {
        cachedPid := activePid
        cachedBase := D2GetModuleBaseV35(activePid, "D2Client.dll")
        lastPlayer := 0
    }
    if (!cachedBase)
        return
    h := D2OpenProcess(activePid)
    if (!h)
        return
    player := D2ReadU32(h, cachedBase + 0x11BBFC)
    if (player)
    {
        if (lastPlayer && player != lastPlayer)
            pickupRoundResetV1 := true
        lastPlayer := player
        if (BOPickupAllowedV441(h,player,activePid))
            D2ScanRoomItemsV61(h, player, 0, activePid)
    }
    DllCall("CloseHandle", "Ptr", h)
}

PickupGameActiveV2(pid)
{
    return IsGameActive() && D2GetActiveGamePidV95()=pid
}

PickupRebindStashUidV2(h, pPlayer, pid, ByRef pending)
{
    inv := D2ReadU32(h,pPlayer+0x60)
    first := inv ? D2ReadU32(h,inv+0x10) : 0
    if (!first)
        return false
    snapshot := V9SnapshotAllItems({pid:pid,h:h,inv:inv,first:first})
    if (!snapshot.HasKey(pending.uid))
        return false
    found := snapshot[pending.uid]
    if (found.cls != pending.cls || found.loc != 0 || found.owner != inv
        || D2ReadU32(h,found.unit) != 4
        || D2ReadU32(h,found.unit+0x0C) != pending.uid
        || D2ReadU32(h,found.unit+0x14) != found.data)
        return false
    V104CubeLog("PICKUP_REBIND_STASH uid=" . pending.uid
        . " old_unit=" . V92Hex(pending.unit) . " new_unit=" . V92Hex(found.unit)
        . " old_data=" . V92Hex(pending.data) . " new_data=" . V92Hex(found.data))
    pending.unit := found.unit, pending.data := found.data
    return true
}
PickupFlushStashListV217(h, pid, inv, ByRef list)
{
    if (!IsObject(list) || list.Count()=0)
        return "CLEARED"
    if (!inv)
        return "STOP"
    first := D2ReadU32(h,inv+0x10)
    snapshot := first ? V9SnapshotAllItems({pid:pid,h:h,inv:inv,first:first}) : {}
    for uid, info in list.Clone()
    {
        if (!PickupGameActiveV2(pid))
            return "STOP"
        if (!snapshot.HasKey(uid))
        {
            list.Delete(uid)
            V104CubeLog("PICKUP_FLUSH_SKIP uid=" . uid . " reason=NOT_IN_STASH")
            continue
        }
        item := snapshot[uid]
        if (item.cls=1204)
        {
            list.Delete(uid)
            V104CubeLog("PICKUP_FLUSH_SKIP uid=" . uid . " reason=CUBE_KEEP_INVENTORY")
            continue
        }
        if (item.loc != 0 || item.owner != inv)
        {
            list.Delete(uid)
            V104CubeLog("PICKUP_FLUSH_SKIP uid=" . uid . " reason=NOT_STASH loc=" . item.loc)
            continue
        }
        if (PickupIsCharmV571(h,item.cls) || FinalQuestItemV511(h,item))
        {
            list.Delete(uid)
            continue
        }
        cursor := PickupCursorV4(h,inv)
        if (!IsObject(cursor))
            return "STOP"
        if (cursor.unit)
        {
            V104CubeLog("PICKUP_FLUSH_STOP reason=CURSOR_HELD cursor_uid=" . cursor.uid)
            return "STOP"
        }
        work := {uid:uid, unit:item.unit, cls:item.cls, data:item.data, loc:0}
        cubeResult := PickupMoveToCubeV2(h,pid,inv,work)
        V104CubeLog("PICKUP_FLUSH_MOVE uid=" . uid . " class=" . item.cls
            . " result=" . cubeResult . " stash_list=" . list.Count())
        if (cubeResult = "MOVED")
        {
            list.Delete(uid)
            continue
        }
        if (cubeResult = "CURSOR_HELD" || cubeResult = "STASH_ONLY")
            return "CUBE_FULL"
        return "STOP"
    }
    return "CLEARED"
}

PickupMoveToCubeV2(h, pid, inv, item)
{
    global cubeTransferDelayMs, cubePickupDelayMs, pickupCubeTracePacket
    ; Farm Cube confirmation only: poll at most every 20 ms; keep other Cube/Belt delays unchanged.
    pickupCubePollMs := Max(10, Min(20, cubeTransferDelayMs))
    if (item.cls=1204)
    {
        V104CubeLog("PICKUP_CUBE_SKIP uid=" . item.uid . " reason=CUBE_KEEP_INVENTORY")
        return "STASH_ONLY"
    }
    static cachedCube := 0, cachedPid := 0, cachedInv := 0
    cube := cachedCube
    if (!IsObject(cube) || cachedPid != pid || cachedInv != inv
        || D2ReadU32(h,cube.unit) != 4
        || D2ReadU32(h,cube.unit+0x0C) != cube.uid
        || D2ReadU32(h,cube.unit+0x04) != 1204
        || D2ReadU32(h,cube.unit+0x14) != cube.data
        || D2ReadU8V18(h,cube.data) != 2
        || D2ReadU8V18(h,cube.data+0x45) != 0
        || D2ReadU32(h,cube.data+0x5C) != inv)
    {
        cube := 0
        first := D2ReadU32(h,inv+0x10)
        snapshot := first ? V9SnapshotAllItems({pid:pid,h:h,inv:inv,first:first}) : {}
        for uid,c in snapshot
        {
            if (c.cls=1204 && c.loc=0 && c.owner=inv && c.data
                && D2ReadU8V18(h,c.data)=2
                && D2ReadU32(h,c.unit+0x0C)=uid)
            {
                cube := {uid:uid,unit:c.unit,data:c.data}
                break
            }
        }
        cachedCube := cube, cachedPid := pid, cachedInv := inv
    }
    if (!IsObject(cube))
    {
        V104CubeLog("PICKUP_CUBE_NOT_FOUND uid=" . item.uid . " round=RESET")
        return "STOP"
    }
    loc := -1
    Loop, 2
    {
        attempt := A_Index
        if (!PickupGameActiveV2(pid))
        {
            V104CubeLog("PICKUP_CUBE_STOP uid=" . item.uid . " reason=GAME_NOT_ACTIVE")
            return "STOP"
        }
        loc := PickupCubeItemStateV3(h,pid,inv,item)
        if (loc=3)
        {
            V104CubeLog("PICKUP_CUBE_CONFIRMED uid=" . item.uid . " attempt=" . attempt . " already_moved=1")
            return "MOVED"
        }
        if (loc!=0 && loc!=4)
        {
            V104CubeLog("PICKUP_CUBE_STOP uid=" . item.uid . " loc=" . loc . " reason=ITEM_NOT_IN_STASH_OR_CURSOR")
            return "STOP"
        }
        if (D2ReadU32(h,cube.unit)!=4 || D2ReadU32(h,cube.unit+0x0C)!=cube.uid
            || D2ReadU32(h,cube.unit+0x04)!=1204 || D2ReadU32(h,cube.unit+0x14)!=cube.data
            || D2ReadU8V18(h,cube.data)!=2 || D2ReadU8V18(h,cube.data+0x45)!=0
            || D2ReadU32(h,cube.data+0x5C)!=inv)
        {
            V104CubeLog("PICKUP_CUBE_STOP uid=" . item.uid . " reason=CUBE_IDENTITY_CHANGED")
            return "STOP"
        }
        V104CubeLog("PICKUP_CUBE_ATTEMPT uid=" . item.uid . " class=" . item.cls
            . " attempt=" . attempt . " loc=" . loc . " cube_uid=" . cube.uid)
        pickupCubeTracePacket := true
        if (loc=0)
            sent := V104RemotePacket19_2A({pid:pid,allowAny:true},item.uid,cube.uid
                ,item.unit,item.data,cube.unit,cube.data,inv,item.cls)
        else
        {
            V104CubeLog("PICKUP_CUBE_CURSOR_RETRY uid=" . item.uid . " packet=2A attempt=" . attempt)
            sent := V6SendPacket2A({pid:pid},item.uid,cube.uid)
        }
        pickupCubeTracePacket := false
        V104CubeLog("PICKUP_CUBE_SEND_RESULT uid=" . item.uid . " attempt=" . attempt . " sent=" . sent)
        confirmStart := A_TickCount
        unknownLogged := false
        while (A_TickCount-confirmStart < 300)
        {
            Sleep, %pickupCubePollMs%
            if (!PickupGameActiveV2(pid))
            {
                V104CubeLog("PICKUP_CUBE_STOP uid=" . item.uid . " reason=GAME_NOT_ACTIVE")
                return "STOP"
            }
            loc := PickupCubeItemStateV3(h,pid,inv,item)
            if (loc=3)
            {
                V104CubeLog("PICKUP_CUBE_CONFIRMED uid=" . item.uid . " attempt=" . attempt)
                return "MOVED"
            }
            if (loc!=0 && loc!=4 && !unknownLogged)
            {
                V104CubeLog("PICKUP_CUBE_WAIT_UID uid=" . item.uid . " loc=" . loc
                    . " attempt=" . attempt . " action=WAIT_AND_REBIND")
                unknownLogged := true
            }
        }
        V104CubeLog("PICKUP_CUBE_NOT_CONFIRMED uid=" . item.uid . " attempt=" . attempt
            . " loc=" . loc . " retry=" . (attempt<2))
    }
    loc := PickupCubeItemStateV3(h,pid,inv,item)
    if (loc=3)
        return "MOVED"
    if (loc=4 && PickupGameActiveV2(pid))
    {
        sent := PickupDropCursorV4(h,pid,inv,item)
        V104CubeLog("PICKUP_CUBE_RETRY_EXHAUSTED uid=" . item.uid
            . " loc=" . loc . " drop_sent=" . sent . " cube=BLOCKED")
        return "CURSOR_HELD"
    }
    if (loc=0)
    {
        V104CubeLog("PICKUP_CUBE_RETRY_EXHAUSTED uid=" . item.uid
            . " loc=0 action=KEEP_IN_STASH cube=BLOCKED")
        return "STASH_ONLY"
    }
    V104CubeLog("PICKUP_CUBE_RETRY_EXHAUSTED uid=" . item.uid . " loc=" . loc . " cube=NOT_BLOCKED")
    return "STOP"
}

PickupReadU32V4(h, addr, ByRef value)
{
    VarSetCapacity(buf,4,0)
    got := 0
    if (!addr || !DllCall("ReadProcessMemory","Ptr",h,"Ptr",addr,"Ptr",&buf
        ,"UPtr",4,"UPtrP",got) || got!=4)
        return false
    value := NumGet(buf,0,"UInt")
    return true
}

PickupCursorV4(h, inv)
{
    if (!inv || !PickupReadU32V4(h,inv+0x08,owner) || !owner
        || !PickupReadU32V4(h,owner,ownerType) || ownerType!=0
        || !PickupReadU32V4(h,owner+0x60,ownerInv) || ownerInv!=inv
        || !PickupReadU32V4(h,inv+0x20,u))
        return -1
    if (!u)
        return {unit:0,uid:0}
    if (!PickupReadU32V4(h,u,typ) || typ!=4
        || !PickupReadU32V4(h,u+0x0C,uid)
        || !PickupReadU32V4(h,u+0x04,cls)
        || !PickupReadU32V4(h,u+0x14,data) || !data
        || !PickupReadU32V4(h,inv+0x20,check) || check!=u)
        return -1
    return {unit:u,uid:uid,cls:cls,data:data,loc:D2ReadU8V18(h,data+0x45)}
}

PickupDropCursorV4(h, pid, inv, item, traceChannel:="cube")
{
    if (RemoteThreadBusyV740(D2GetActiveGamePidV95()))
        return false
    if (!PickupGameActiveV2(pid))
        return false
    cursor := PickupCursorV4(h,inv)
    if (!IsObject(cursor) || !cursor.unit || cursor.uid!=item.uid || cursor.cls!=item.cls)
    {
        DebugTraceWrite(traceChannel,"PICKUP_DROP_SKIP uid=" . item.uid . " reason=CURSOR_NOT_MATCHED")
        return false
    }
    itemUid := item.uid
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
    VarSetCapacity(pkt,5,0)
    NumPut(0x17,pkt,0,"UChar")
    NumPut(itemUid,pkt,1,"UInt")
    wrotePkt := 0
    okPkt := DllCall("WriteProcessMemory","Ptr",hSend,"Ptr",remote+64,"Ptr",&pkt,"UPtr",5,"UPtrP",wrotePkt)
    VarSetCapacity(code,32,0)
    o:=0
    NumPut(0x68,code,o,"UChar"),o+=1
    NumPut(remote+64,code,o,"UInt"),o+=4
    NumPut(0x6A,code,o,"UChar"),o+=1
    NumPut(0x01,code,o,"UChar"),o+=1
    NumPut(0x6A,code,o,"UChar"),o+=1
    NumPut(0x05,code,o,"UChar"),o+=1
    NumPut(0xB8,code,o,"UChar"),o+=1
    NumPut(sendFn,code,o,"UInt"),o+=4
    NumPut(0xFF,code,o,"UChar"),o+=1
    NumPut(0xD0,code,o,"UChar"),o+=1
    NumPut(0xC3,code,o,"UChar"),o+=1
    wroteCode:=0
    okCode := DllCall("WriteProcessMemory","Ptr",hSend,"Ptr",remote,"Ptr",&code,"UPtr",o,"UPtrP",wroteCode)
    if (!okPkt || wrotePkt!=5 || !okCode || wroteCode!=o)
    {
        DllCall("VirtualFreeEx","Ptr",hSend,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hSend)
        return false
    }
    cursor := PickupCursorV4(hSend,inv)
    if (!PickupGameActiveV2(pid) || !IsObject(cursor) || !cursor.unit
        || cursor.uid!=item.uid || cursor.cls!=item.cls)
    {
        DllCall("VirtualFreeEx","Ptr",hSend,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hSend)
        DebugTraceWrite(traceChannel,"PICKUP_DROP_SKIP uid=" . itemUid . " reason=CURSOR_OR_GAME_CHANGED")
        return false
    }
    if (item.cls=1204)
    {
        cubeBaseV754 := D2GetModuleBaseV35(pid,"D2Client.dll")
        cubePlayerV754 := cubeBaseV754 ? D2ReadU32(h,cubeBaseV754+0x11BBFC) : 0
        CubeResetHoldV754(pid,h,cubePlayerV754,item.uid)
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
        wait := DllCall("WaitForSingleObject","Ptr",th,"UInt",1000)
        waitLimit--
    }
    exitCode:=0
    DllCall("GetExitCodeThread","Ptr",th,"UIntP",exitCode)
    RemoteThreadFinishV740(hSend,th,remote,wait)
    DebugTraceWrite(traceChannel,"PICKUP_DROP_PACKET17 uid=" . itemUid . " wait=" . wait
        . " exit=" . V92Hex(exitCode) . " bytes=" . wrotePkt)
    return (wait=0)
}

PickupCubeItemStateV3(h, pid, inv, item)
{
    cursor := PickupCursorV4(h,inv)
    if (!IsObject(cursor))
        return -1
    if (cursor.unit)
    {
        if (cursor.uid!=item.uid || cursor.cls!=item.cls)
            return -2
        if (item.unit!=cursor.unit || item.data!=cursor.data)
            V104CubeLog("PICKUP_CURSOR_REBIND uid=" . item.uid
                . " unit=" . V92Hex(cursor.unit) . " raw_loc=" . cursor.loc)
        item.unit := cursor.unit, item.data := cursor.data
        return 4
    }
    loc := -1
    if (D2ReadU32(h,item.unit)=4 && D2ReadU32(h,item.unit+0x0C)=item.uid
        && D2ReadU32(h,item.unit+0x04)=item.cls && D2ReadU32(h,item.unit+0x14)=item.data)
    {
        loc := D2ReadU8V18(h,item.data+0x45)
        if (loc=3 || (loc=0 && D2ReadU32(h,item.data+0x5C)=inv))
            return loc
    }
    roots := HealScanRootsV4(h,inv)
    if (roots.errors || !roots.roots.Length())
        return -1
    queue := roots.roots, seen := {}, qi := 1, found := 0
    while (qi<=queue.Length() && qi<=8192)
    {
        u := queue[qi], qi++
        if (!u || seen.HasKey(u))
            continue
        seen[u] := true
        typ := D2ReadU32(h,u)
        data := (typ=4) ? D2ReadU32(h,u+0x14) : 0
        if (data && D2ReadU32(h,u+0x0C)=item.uid && D2ReadU32(h,u+0x04)=item.cls)
        {
            liveLoc := D2ReadU8V18(h,data+0x45)
            owner := D2ReadU32(h,data+0x5C)
            if (liveLoc=3 || (liveLoc=0 && owner=inv))
            {
                found := {unit:u,data:data,loc:liveLoc}
                if (liveLoc=3)
                    break
            }
        }
        for _, off in [0xE4,0xE8]
        {
            link := D2ReadU32(h,u+off)
            if (link && !seen.HasKey(link))
                queue.Push(link)
        }
        if (data)
        {
            for _, off in [0x60,0x64,0x6C,0x70,0x84,0xAC,0xB0,0xB4,0xC8,0xD8]
            {
                link := D2ReadU32(h,data+off)
                if (link && !seen.HasKey(link) && D2ReadU32(h,link)=4)
                    queue.Push(link)
            }
        }
    }
    if (!IsObject(found))
        return loc
    if (D2ReadU32(h,found.unit)!=4 || D2ReadU32(h,found.unit+0x0C)!=item.uid
        || D2ReadU32(h,found.unit+0x04)!=item.cls || D2ReadU32(h,found.unit+0x14)!=found.data)
        return -1
    liveLoc := D2ReadU8V18(h,found.data+0x45)
    if (liveLoc=0 && D2ReadU32(h,found.data+0x5C)!=inv)
        return -1
    V104CubeLog("PICKUP_CUBE_REBIND uid=" . item.uid . " old_unit=" . V92Hex(item.unit)
        . " new_unit=" . V92Hex(found.unit) . " old_loc=" . loc . " new_loc=" . liveLoc)
    item.unit := found.unit, item.data := found.data
    return liveLoc
}

PickupGroundRebindV123(h,player,item)
{
    path := D2ReadU32(h,player+0x2C),room := path ? D2ReadU32(h,path+0x1C) : 0
    if (!room || !IsObject(item))
        return false
    seen := {}
    for _,r in MonsterLoadedRoomsV20(h,room)
    {
        unit := D2ReadU32(h,r+0x74)
        Loop, 4096
        {
            if (!unit || seen.HasKey(unit))
                break
            seen[unit] := true
            if (D2ReadU32(h,unit)=4 && D2ReadU32(h,unit+0x0C)=item.uid
                && D2ReadU32(h,unit+0x04)=item.cls)
            {
                data := D2ReadU32(h,unit+0x14),mode := D2ReadU32(h,unit+0x10)
                if (data && (mode=3 || mode=5))
                {
                    item.unit := unit,item.data := data
                    return true
                }
            }
            next := D2ReadU32(h,unit+0xE8)
            if (next=unit)
                break
            unit := next
        }
    }
    return false
}

D2ScanRoomItemsV61(h, pPlayer, radius, selectedPid)
{
    global teleportKeyV55,teleportIntervalSecV56
    global pickupImageOn, pickupRadius, pickupLastClick, v61LastPickupTick, v58PrevGoldId, v58PrevGoldUnit, v58PrevGoldX, v58PrevGoldY, v58LastGoldEvent
    global v60LastTraceTick
        global pickupRoundResetV1, pickupFarmWorkV75
    global pickupOneShotV216,ticketPickupWaitV279,pickupOptJobV12,farmItemLockV625
    global pickupGroupActiveV26,pickupManualActiveV827
    global pickupStashListV217,labInventoryOnlyV311,monsterLockRoomSecV622
    static roundItems := [], roundIndex := 1, roundPid := 0, roundOn := false
    static pending := 0, cubeBlocked := false
    static lastPickupOn := false
    static lastIdleLog := 0
    static emptySinceV16 := 0, emptyChecksV16 := 0
    static farmEmptyChecksV940 := 0, farmLastEmptyAtV940 := 0
    try
    {
    global farmCenterCycleV741,pickupRoundResetV1
    farmBatch := FarmCenterPendingV741(selectedPid) && farmCenterCycleV741.phase="PICKUP_BUSY"
    ; PICKUP_FIX_2026: Do NOT finish a pickup merely because the first
    ; approach took 10 seconds. Keep the UID until verified or truly gone.
    closeScanV722 := (farmBatch || pickupManualActiveV827) ? false : FarmApproachScanV722(h,pPlayer,selectedPid)
    if (IsObject(closeScanV722) && (!closeScanV722.complete || IsObject(closeScanV722.target)))
    {
        cursorV722 := PickupCursorV4(h,D2ReadU32(h,pPlayer+0x60))
        if (!IsObject(cursorV722) || !cursorV722.unit || !IsObject(pending))
            return ""
    }
    PickupAutoGroupsRefreshV7()
    if (!pickupImageOn && !pickupGroupActiveV26)
	{
    roundItems := [], roundIndex := 1, roundPid := 0, roundOn := false
    pending := 0, cubeBlocked := false
    lastPickupOn := false
    return ""
	}
    if (pickupRoundResetV1 || !lastPickupOn || roundPid != selectedPid)
    {
        emptySinceV16 := 0, emptyChecksV16 := 0
        farmEmptyChecksV940 := 0,farmLastEmptyAtV940 := 0
        roundItems := [], roundIndex := 1, roundPid := selectedPid, roundOn := false
        pending := 0, cubeBlocked := false
    }
    pickupRoundResetV1 := false
    lastPickupOn := true

    if (IsObject(pending))
    {
        if (pending.release)
        {
            inv := D2ReadU32(h,pPlayer+0x60)
            cursor := PickupCursorV4(h,inv)
            if (IsObject(cursor) && !cursor.unit)
            {
                V104CubeLog("PICKUP_DROP_CONFIRMED uid=" . pending.uid
                    . " cursor=EMPTY cube=BLOCKED next=STASH_ONLY")
                if (pending.stopAfterDropV119)
                    PickupStopFullV119("INVENTORY_CURSOR_REJECTED_TWICE")
                else if (pending.retryAfterDropV123)
                {
                    if (A_TickCount-pending.tick<200)
                        return ""
                    if (PickupGroundRebindV123(h,pPlayer,pending))
                    {
                        if (!PickupFileHasRuleV97(pending.cls,D2ReadU8V18(h,pending.data),pending.data,h,pending.unit))
                        {
                            pending := 0,roundOn := farmBatch ? roundOn : false
                            return ""
                        }
                        retryInfoV123 := ""
                        if (!PickupFailedInventoryReadyV551(h,pPlayer,selectedPid,pending.uid,pending.unit))
                            return ""
                        if (D2RemotePickupPacket(h,pending.uid,retryInfoV123,pending.cls))
                        {
                            pending.release := false,pending.retryAfterDropV123 := false
                            pending.stopAfterDropV119 := false,pending.retry := false
                            pending.skipCube := true,pending.tick := A_TickCount
                            V104CubeLog("PICKUP_INVENTORY_RETRY_AFTER_DROP uid=" . pending.uid . " cursor_rejections=" . pending.cursorRejectsV123 . " cube=SKIP")
                        }
                        else if (A_TickCount-pending.tick>=1500)
                        {
                            pending := 0
                            roundItems := farmBatch ? roundItems : [],roundIndex := farmBatch ? roundIndex : 1,roundOn := farmBatch ? roundOn : false
                        }
                        return ""
                    }
                    if (A_TickCount-pending.tick<1500)
                        return ""
                    V104CubeLog("PICKUP_RETRY_DROPPED_ITEM_NOT_FOUND uid=" . pending.uid . " pickup=ON full=UNKNOWN")
                }
                pending := 0
                roundItems := farmBatch ? roundItems : [], roundIndex := farmBatch ? roundIndex : 1, roundOn := farmBatch ? roundOn : false
                return ""
            }
            if (IsObject(cursor) && (cursor.uid!=pending.uid || cursor.cls!=pending.cls))
            {
                V104CubeLog("PICKUP_DROP_STOP expected_uid=" . pending.uid
                    . " cursor_uid=" . cursor.uid . " reason=OTHER_ITEM pickup=PAUSED")
                global farmPickupBlockedV57
                farmPickupBlockedV57 := true
                pickupImageOn := false
                return ""
            }
            if (A_TickCount-pending.tick >= 500 && PickupGameActiveV2(selectedPid))
            {
                if (pending.releaseTries >= 3)
                {
                    V104CubeLog("PICKUP_CURSOR_STILL_HELD uid=" . pending.uid
                        . " cursor_read=" . IsObject(cursor) . " pickup=PAUSED")
                    farmPickupBlockedV57 := true
                    pickupImageOn := false
                    return ""
                }
                sent := PickupDropCursorV4(h,selectedPid,inv,pending)
                pending.releaseTries++
                pending.tick := A_TickCount
                V104CubeLog("PICKUP_CURSOR_DROP_RETRY uid=" . pending.uid
                    . " try=" . pending.releaseTries . " sent=" . sent)
            }
            return ""
        }
        if (A_TickCount - pending.tick < 50)
            return ""
        inv := D2ReadU32(h,pPlayer+0x60)
        confirmedLoc := PickupCubeItemStateV3(h,selectedPid,inv,pending)
        ; PICKUP_FIX_2026: Ground state 3 or a transient read failure is
        ; NOT proof of pickup. Let the retry/rebind/Tele path below run.
        if (confirmedLoc=4)
        {
            pending.cursorRejectsV123 := pending.cursorRejectsV123+1
            pending.release := true,pending.stopAfterDropV119 := pending.cursorRejectsV123>=2
            if (BOFinalItemActiveV442(selectedPid) && pending.cls=1825)
                pending.stopAfterDropV119 := false
            pending.retryAfterDropV123 := !pending.stopAfterDropV119,pending.releaseTries := 1
            PickupDropCursorV4(h,selectedPid,inv,pending)
            pending.tick := A_TickCount
            V104CubeLog("PICKUP_INVENTORY_CURSOR uid=" . pending.uid . " rejects=" . pending.cursorRejectsV123
                . " next=" . (pending.stopAfterDropV119 ? "DROP_THEN_STOP_PICKUP" : "DROP_THEN_RETRY_SAME_ITEM"))
            return ""
        }
        if (confirmedLoc=0 || confirmedLoc=3)
        {
            PickupFarmForgetV762(selectedPid,pending.uid)
            loc := confirmedLoc
            owner := D2ReadU32(h,pending.data+0x5C)
                        if (loc = 0 && inv && owner = inv)
            {
                if (farmBatch && IsObject(farmItemLockV625))
                    farmItemLockV625.itemPickedV1602 := true
                UniqueRememberPickedV18(h,pending)

                pickupStashListV217[pending.uid] := {unit:pending.unit, data:pending.data, cls:pending.cls}
                V104CubeLog("PICKUP_STASH_CONFIRMED uid=" . pending.uid
                    . " class=" . pending.cls . " loc=" . loc . " owner=" . V92Hex(owner)
                    . " inv=" . V92Hex(inv) . " skip_cube=" . pending.skipCube
                    . " cube_blocked=" . cubeBlocked . " stash_list=" . pickupStashListV217.Count())
                if (!FinalQuestItemV511(h,pending) && !cubeBlocked && !pending.skipCube && !(Lab1SingleRunV310() && labInventoryOnlyV311))
                {
                    cubeResult := PickupMoveToCubeV2(h,selectedPid,inv,pending)
                    if (cubeResult = "MOVED")
                    {
                        pickupStashListV217.Delete(pending.uid)
                        V104CubeLog("PICKUP_STASH_CLEARED uid=" . pending.uid
                            . " stash_list=" . pickupStashListV217.Count())
                    }
                    else if (cubeResult = "CURSOR_HELD")
                    {
                        cubeBlocked := true
                        V104CubeLog("PICKUP_CUBE_REJECT uid=" . pending.uid
                            . " action=DROP_ALREADY_DONE stash_list=" . pickupStashListV217.Count())
                        SigCubeFullQueueV153()
                        pending := 0
                        roundItems := farmBatch ? roundItems : [], roundIndex := farmBatch ? roundIndex : 1, roundOn := farmBatch ? roundOn : false
                        return ""
                    }
                    else if (cubeResult = "STASH_ONLY")
                    {
                        cubeBlocked := true
                        V104CubeLog("PICKUP_STASH_ONLY uid=" . pending.uid
                            . " reason=CUBE_REJECTED stash_list=" . pickupStashListV217.Count())
                        SigCubeFullQueueV153()
                    }
                    else if (cubeResult = "STOP")
                    {
                        V104CubeLog("PICKUP_CUBE_TRANSIENT_STOP uid=" . pending.uid
                            . " cube=NOT_BLOCKED round=RESET stash_list=" . pickupStashListV217.Count())
                        pending := 0
                        roundItems := farmBatch ? roundItems : [], roundIndex := farmBatch ? roundIndex : 1, roundOn := farmBatch ? roundOn : false
                        return ""
                    }
                }
                else
                    V104CubeLog("PICKUP_STASH_ONLY uid=" . pending.uid
                        . " reason=" . (pending.skipCube ? "FIRST_THREE_RULES" : "CURSOR_HELD_BEFORE")
                        . " stash_list=" . pickupStashListV217.Count())
                if (pending.firstRule && !farmBatch)
                    roundItems := farmBatch ? roundItems : [], roundIndex := farmBatch ? roundIndex : 1, roundOn := farmBatch ? roundOn : false
                pending := 0
                return ""
            }
        }
        ; Farm khong duoi theo UID neu vat pham khong con trong tam nhat.
        if (confirmedLoc=3 && farmBatch && pickupImageOn
            && IsObject(farmItemLockV625) && farmItemLockV625.pid=selectedPid
            && farmItemLockV625.uid=pending.uid
            && A_TickCount-pending.tick>=450)
        {
            playerPathV1703 := D2ReadU32(h,pPlayer+0x2C)
            itemPathV1703 := D2ReadU32(h,pending.unit+0x2C)
            if (playerPathV1703 && itemPathV1703
                && D2ReadU32(h,pending.unit)=4
                && D2ReadU32(h,pending.unit+0x0C)=pending.uid)
            {
                pxV1703 := D2ReadU16(h,playerPathV1703+2)
                pyV1703 := D2ReadU16(h,playerPathV1703+6)
                ixV1703 := D2ReadU32(h,itemPathV1703+0x0C)
                iyV1703 := D2ReadU32(h,itemPathV1703+0x10)
                arrivalV1703 := Max(1,pickupRadius)
                if (pxV1703 && pyV1703 && ixV1703 && iyV1703
                    && (ixV1703-pxV1703)**2+(iyV1703-pyV1703)**2>arrivalV1703**2)
                {
                    PortalLogWriteV66("FARM_PICKUP_SKIP_OUT_OF_RANGE uid=" . pending.uid
                        . " item=" . ixV1703 . "," . iyV1703
                        . " player=" . pxV1703 . "," . pyV1703
                        . " radius=" . arrivalV1703 . " next=RESUME_ROUTE")
                    farmItemLockV625 := false
                    farmCenterCycleV741.pickupStateV905 := "DONE"
                    farmCenterCycleV741.pickupResultV905 := "OUT_OF_RANGE"
                    farmCenterCycleV741.phase := "CHECK"
                    pending := 0
                    roundItems := [],roundIndex := 1,roundOn := false
                    pickupRoundResetV1 := true
                    return ""
                }
            }
        }
        ; Farm retries a failed pickup in place; it never walks back to the item.
        if (confirmedLoc=3 && pickupImageOn && farmBatch)
        {
            if (A_TickCount-pending.tick<1200)
                return ""
            playerPathV1704 := D2ReadU32(h,pPlayer+0x2C)
            itemPathV1704 := pending.unit ? D2ReadU32(h,pending.unit+0x2C) : 0
            if (playerPathV1704 && itemPathV1704
                && D2ReadU32(h,pending.unit)=4 && D2ReadU32(h,pending.unit+0x0C)=pending.uid)
            {
                pxV1704 := D2ReadU16(h,playerPathV1704+2)
                pyV1704 := D2ReadU16(h,playerPathV1704+6)
                ixV1704 := D2ReadU32(h,itemPathV1704+0x0C)
                iyV1704 := D2ReadU32(h,itemPathV1704+0x10)
                nearSqV1704 := Max(1,pickupRadius)**2
                if (pxV1704 && pyV1704 && ixV1704 && iyV1704
                    && (ixV1704-pxV1704)**2+(iyV1704-pyV1704)**2>nearSqV1704)
                {
                    PortalLogWriteV66("FARM_PICKUP_SKIP_OUT_OF_RANGE uid=" . pending.uid
                        . " item=" . ixV1704 . "," . iyV1704
                        . " player=" . pxV1704 . "," . pyV1704
                        . " radius=" . Max(1,pickupRadius) . " next=RESUME_ROUTE")
                    farmItemLockV625 := false
                    farmCenterCycleV741.pickupStateV905 := "DONE"
                    farmCenterCycleV741.pickupResultV905 := "OUT_OF_RANGE"
                    farmCenterCycleV741.phase := "CHECK"
                    pending := 0
                    roundItems := [],roundIndex := 1,roundOn := false
                    pickupRoundResetV1 := true
                    return ""
                }
            }
            if (!IsGameActive() || D2GetActiveGamePidV95()!=selectedPid
                || RemoteThreadBusyV740(selectedPid) || !AutoMonsterPacketCleanupV1())
                return ""
            unitOkV1704 := pending.unit && D2ReadU32(h,pending.unit)=4
                && D2ReadU32(h,pending.unit+0x0C)=pending.uid
                && (D2ReadU32(h,pending.unit+0x10)=3 || D2ReadU32(h,pending.unit+0x10)=5)
            if (!unitOkV1704)
                unitOkV1704 := PickupGroundRebindV123(h,pPlayer,pending)
            if (unitOkV1704 && PickupFailedInventoryReadyV551(h,pPlayer,selectedPid,pending.uid,pending.unit))
            {
                retryInfoV1704 := ""
                sentV1704 := D2RemotePickupPacket(h,pending.uid,retryInfoV1704,pending.cls)
                pending.tick := A_TickCount
                PortalLogWriteV66("FARM_PICKUP_RETRY_NO_OLD_TELE uid=" . pending.uid
                    . " sent=" . sentV1704 . " info=" . retryInfoV1704
                    . " next=CHECK_GROUND_STATE", "FARM_PICKUP_RETRY_NO_OLD_TELE",1000)
            }
            return ""
        }
        if (A_TickCount-pending.tick>=100 && PickupFarmBudgetActiveV762(selectedPid))
        {
            if (PickupRebindStashUidV2(h,pPlayer,selectedPid,pending))
            {
                PickupFarmForgetV762(selectedPid,pending.uid)
                return ""
            }
            if (PickupFarmIgnoredV762(selectedPid,pending.uid))
            {
                pending := 0,roundItems := farmBatch ? roundItems : [],roundIndex := farmBatch ? roundIndex : 1,roundOn := farmBatch ? roundOn : false
                return ""
            }
            if (!pending.farmStartedV762)
                pending.farmStartedV762 := pending.tick
            if (A_TickCount-pending.farmStartedV762>=(farmBatch ? 3000 : 15000))
            {
                PickupFarmSkipV762(selectedPid,pending.uid,pending.cls
                    ,"TOTAL_TIMEOUT",(farmBatch ? 30000 : monsterLockRoomSecV622*1000))
                pending := 0,roundItems := farmBatch ? roundItems : [],roundIndex := farmBatch ? roundIndex : 1,roundOn := farmBatch ? roundOn : false
                return ""
            }
            if (!pending.moveDoneV764)
            {
                pending.moveDoneV764 := true
                pending.moveAtV764 := A_TickCount
                pending.tick := A_TickCount
                if (!FarmControlRunningV186() && pending.unit && MonsterBossProbeReadV1(h,pending.unit,0x30,mub)
                    && MonsterBossProbeReadV1(h,NumGet(mub,0x2C,"UInt"),0x20,mip))
                {
                    moveX := NumGet(mip,2,"UShort"), moveY := NumGet(mip,6,"UShort")
                    if (moveX>0 && moveY>0)
                    {
                        moveInfo := ""
                        sentMove := V5SendMove03(h, moveX, moveY, moveInfo)
                        DebugTraceWrite("pickup","PICKUP_MOVE_BACK uid=" . pending.uid
                            . " to=" . moveX . "," . moveY
                            . " sent=" . sentMove . " info=" . moveInfo)
                    }
                }
                else if (FarmControlRunningV186())
                    DebugTraceWrite("pickup","PICKUP_MOVE_SKIP uid=" . pending.uid . " reason=FARM_NO_APPROACH")
                return ""
            }
            if (!pending.retryV764)
            {
                if (A_TickCount-pending.moveAtV764<600)
                    return ""
                if (!PickupFailedInventoryReadyV551(h,pPlayer,selectedPid,pending.uid,pending.unit))
                {
                    if (A_TickCount-pending.farmStartedV762>=(farmBatch ? 3000 : 5000))
                    {
                        PickupFarmSkipV762(selectedPid,pending.uid,pending.cls
                            ,"INVENTORY_PREP_TIMEOUT",(farmBatch ? 30000 : monsterLockRoomSecV622*1000))
                        pending := 0,roundItems := farmBatch ? roundItems : [],roundIndex := farmBatch ? roundIndex : 1,roundOn := farmBatch ? roundOn : false
                    }
                    return ""
                }
                retryInfoV762 := ""
                if (!D2RemotePickupPacket(h,pending.uid,retryInfoV762,pending.cls))
                {
                    pending.tick := A_TickCount
                    return ""
                }
                pending.retryV764 := true
                pending.tick := A_TickCount
                return ""
            }
            attemptsV762 := PickupFarmStateV762(selectedPid,pending.uid,pending.cls)
            if (attemptsV762.tries<3)
            {
                thirdInfoV762 := ""
                if (D2RemotePickupPacket(h,pending.uid,thirdInfoV762,pending.cls))
                {
                    pending.tick := A_TickCount
                    return ""
                }
                if (A_TickCount-attemptsV762.lastAt<100)
                    return ""
            }
            PickupFarmSkipV762(selectedPid,pending.uid,pending.cls
                ,"PICKUP_FAILED_THREE_ATTEMPTS",(farmBatch ? 30000 : monsterLockRoomSecV622*1000))
            pending := 0,roundItems := farmBatch ? roundItems : [],roundIndex := farmBatch ? roundIndex : 1,roundOn := farmBatch ? roundOn : false
            return ""
        }
        if (A_TickCount - pending.tick >= 100 && !pending.retry)
        {
            if (PickupRebindStashUidV2(h,pPlayer,selectedPid,pending))
                return ""

            if (!PickupFileHasRuleV97(pending.cls,D2ReadU8V18(h,pending.data),pending.data,h,pending.unit))
            {
                pending := 0,roundOn := farmBatch ? roundOn : false
                return ""
            }
            retryInfo := ""
            if (!PickupFailedInventoryReadyV551(h,pPlayer,selectedPid,pending.uid,pending.unit))
                return ""
            retrySent := D2RemotePickupPacket(h,pending.uid,retryInfo,pending.cls)
            pending.retry := true
            pending.tick := A_TickCount
            V104CubeLog("PICKUP_RETRY uid=" . pending.uid . " sent=" . retrySent
                . " loc=" . D2ReadU8V18(h,pending.data+0x45))
            return ""
        }
        if (A_TickCount - pending.tick >= 100)
        {
            if (PickupRebindStashUidV2(h,pPlayer,selectedPid,pending))
                return ""
            if (!PickupFailedInventoryReadyV551(h,pPlayer,selectedPid,pending.uid,pending.unit))
                return ""
            if (Lab1SingleRunV310() && labInventoryOnlyV311)
            {
                V104CubeLog("LAB_INVENTORY_FULL pickup=OFF farm=CONTINUE town_sig=OFF")
                PickupEnabledSetV71(false,true,false)
                pending := 0,roundItems := farmBatch ? roundItems : [],roundIndex := farmBatch ? roundIndex : 1,roundOn := farmBatch ? roundOn : false
                return ""
            }
            V104CubeLog("PICKUP_STASH_FULL uid=" . pending.uid
                . " class=" . pending.cls
                . " dist_manhattan=" . (pending.HasKey("dist") ? pending.dist : -1)
                . " waited_ms=" . (A_TickCount - pending.tick)
                . " action=FLUSH_STASH_LIST"
                . " stash_list=" . pickupStashListV217.Count())
            flushInv := D2ReadU32(h,pPlayer+0x60)
            flushResult := PickupFlushStashListV217(h,selectedPid,flushInv,pickupStashListV217)
            V104CubeLog("PICKUP_FLUSH_RESULT result=" . flushResult
                . " stash_list=" . pickupStashListV217.Count())
            if (flushResult = "CUBE_FULL")
            {
                cursorNow := PickupCursorV4(h,flushInv)
                if (IsObject(cursorNow) && cursorNow.unit)
                    PickupDropCursorV4(h,selectedPid,flushInv,cursorNow)
                SigCubeFullQueueV153()
            }
            pending := 0
            roundItems := farmBatch ? roundItems : [], roundIndex := farmBatch ? roundIndex : 1, roundOn := farmBatch ? roundOn : false
        }
        return ""
    }
    if (roundOn)
    {
        if (roundIndex > roundItems.Length())
        {
            roundOn := false
            ; Khong reset khoa UID 30 giay trong cung mot luot Farm.
        }
        else
        {
        if (v61LastPickupTick && A_TickCount - v61LastPickupTick < 20)
            return ""
        item := roundItems[roundIndex]
        if (farmBatch)
        {
            itemBudgetV940 := PickupFarmStateV762(selectedPid,item.uid,item.cls)
            if (!itemBudgetV940.startedAtV940)
                itemBudgetV940.startedAtV940 := A_TickCount
            ; Khong bo UID hop le theo dong ho 3 giay: luong nhat xu ly cho den khi xong.
            ; Van reset budget khi item xac nhan da vao cont/cube bang PickupFarmForgetV762().
        }
        if (PickupFarmIgnoredV762(selectedPid,item.uid))
        {
            roundIndex++
            return ""
        }
        if (D2ReadU32(h,item.unit) != 4
            || D2ReadU32(h,item.unit+0x0C) != item.uid
            || D2ReadU32(h,item.unit+0x04) != item.cls
            || D2ReadU32(h,item.unit+0x14) != item.data)
        {
            roundIndex++
            return ""
        }
        if (!IsGameActive() || D2GetActiveGamePidV95()!=selectedPid)
            return ""
        if (!PickupFileHasRuleV97(item.cls,D2ReadU8V18(h,item.data),item.data,h,item.unit))
        {
            roundIndex++
            DebugTraceWrite("pickup","PICKUP_QUEUE_SKIP uid=" . item.uid . " reason=EXCLUDED_OR_RULE_PENDING")
            return ""
        }
        relicResultV567 := PickupRelicRoundV567(h,pPlayer,selectedPid,item)
        if (farmBatch && IsObject(farmItemLockV625) && relicResultV567="WAIT")
            farmItemLockV625.startedAtV1602 := A_TickCount  ; Do not time out Relic reading/Swap.
        if (relicResultV567!="PASS")
        {
            if (relicResultV567!="WAIT")
                roundIndex++,v61LastPickupTick := A_TickCount
            return ""
        }
        if (farmBatch && IsObject(farmItemLockV625) && farmItemLockV625.uid!=item.uid)
        {
            farmItemLockV625.uid := item.uid,farmItemLockV625.cls := item.cls
            farmItemLockV625.startedAtV1602 := A_TickCount
            farmItemLockV625.itemPickedV1602 := false
        }
        roundInfo := ""
        sentRound := D2RemotePickupPacket(h,item.uid,roundInfo,item.cls)
        DebugTraceWrite("pickup", "PICKUP_SEND uid=" . item.uid . " class=" . item.cls
            . " pid=" . selectedPid . " sent=" . sentRound
            . " dist_manhattan=" . (item.HasKey("dist") ? item.dist : -1)
            . " detail=" . roundInfo)
        v61LastPickupTick := A_TickCount
        roundIndex++
        if (sentRound || (pickupImageOn && D2ReadU32(h,item.unit+0x10)=3
            && PickupGameActiveV2(selectedPid)))
            pending := {uid:item.uid,unit:item.unit,cls:item.cls,data:item.data
                ,skipCube:item.skipCube,firstRule:item.firstRule,tick:A_TickCount,retry:false
                ,dist:(item.HasKey("dist") ? item.dist : -1),firstSendOkV1172:sentRound}
        return ""
        }
    }
    ; Farm luon quet lai sau tung mon. Khong bao DONE chi vi queue da het.
    out := "PlayerPtr=0x" . Format("{:08X}", pPlayer) . "`r`n"
    diag := A_Now . " tick=" . A_TickCount . " | SCAN_BEGIN player=0x" . Format("{:08X}", pPlayer) . "`r`n"
    pPath := D2ReadU32(h, pPlayer + 0x2C)
    out .= "PlayerPath[+2C]=0x" . Format("{:08X}", pPath) . "`r`n"
    if (!pPath)
        return out . "FAIL: PlayerPath=0`r`n"

    px := D2ReadU16(h, pPath + 0x02)
    py := D2ReadU16(h, pPath + 0x06)
    pRoom := D2ReadU32(h, pPath + 0x1C)
    out .= "PlayerSubXY=(" . px . "," . py . ")`r`n"
    diag .= A_Now . " tick=" . A_TickCount . " | PLAYER xy=(" . px . "," . py . ") pickupOn=" . pickupImageOn . " radius=" . pickupRadius . "`r`n"
    out .= "Room1[Path+1C]=0x" . Format("{:08X}", pRoom) . "`r`n"
    if (!pRoom)
        return out . "FAIL: Room1=0`r`n"

    rooms := MonsterLoadedRoomsV20(h,pRoom)

    pickupAllowCount := PickupFileCountV97()
    out .= "PICKUP_LIST_RAM fixed_rule+itemdata_groups=" . pickupAllowCount . "`r`n"
    hasPriority := PickupFileFirstRuleV97(priorityClass, priorityQ)


    bestUnit := 0, bestUnitId := 0, bestClass := 0, bestX := 0, bestY := 0, bestDist := 0x7FFFFFFF
    priorityUnit := 0, priorityUnitId := 0, priorityX := 0, priorityY := 0, priorityDist := 0x7FFFFFFF
    totalUnits := 0, totalItems := 0, nearItems := 0
    goldFound := false, goldIdNow := 0, goldUnitNow := 0, goldXNow := 0, goldYNow := 0, goldDistNow := 0
    seenUnits := {}
    PickupAutoGroupsRefreshV7()
    roundCandidates := []
    sigScopeV654 := IsObject(ticketPickupWaitV279) && ticketPickupWaitV279.pid=selectedPid && ticketPickupWaitV279.sigScopeV654
    global cubeResetSerialV754
    scanSerialV754 := cubeResetSerialV754
    verifyScanV754 := farmBatch || sigScopeV654 || CubeResetPendingV754(selectedPid)
        || (IsObject(ticketPickupWaitV279) && ticketPickupWaitV279.pid=selectedPid)
    scanCompleteV654 := true
    for ri, room in rooms
    {
        if (verifyScanV754 && !MonsterBossProbeReadV1(h,room+0x74,4,headV654))
        {
            scanCompleteV654 := false
            continue
        }
        pUnit := D2ReadU32(h, room + 0x74)
        out .= "ROOM#" . ri . " ptr=0x" . Format("{:08X}", room) . " UnitFirst=0x" . Format("{:08X}", pUnit) . "`r`n"
        Loop, 4096
        {
            if (!pUnit || seenUnits.HasKey(pUnit))
                break
            seenUnits[pUnit] := 1
            if (verifyScanV754 && !MonsterBossProbeReadV1(h,pUnit,0xEC,unitV654))
            {
                scanCompleteV654 := false
                break
            }
            totalUnits++
            typ := D2ReadU32(h, pUnit + 0x00)
            if (typ = 4 && (!sigScopeV654 || D2ReadU32(h,pUnit+0x10)=3 || D2ReadU32(h,pUnit+0x10)=5))
            {
                totalItems++
                unitId := D2ReadU32(h, pUnit + 0x0C)
                cls := D2ReadU32(h, pUnit + 0x04)
                itemData := D2ReadU32(h, pUnit + 0x14)
                itemQuality := itemData ? D2ReadU8V18(h, itemData + 0x00) : 0
                ipath := D2ReadU32(h, pUnit + 0x2C)
                sx := ipath ? D2ReadU32(h, ipath + 0x0C) : 0
                sy := ipath ? D2ReadU32(h, ipath + 0x10) : 0
                dx := sx - px, dy := sy - py
                adx := dx < 0 ? -dx : dx
                ady := dy < 0 ? -dy : dy
                dist := adx + ady
                if (cls = 1214)
                {
                    goldFound := true
                    goldIdNow := unitId
                    goldUnitNow := pUnit
                    goldXNow := sx
                    goldYNow := sy
                    goldDistNow := dist
                }
                inside := (radius <= 0 || dist <= radius)
                if (sigScopeV654)
                {
                    dist := Sqrt((sx-ticketPickupWaitV279.xV654)**2+(sy-ticketPickupWaitV279.yV654)**2)
                    inside := dist<=ticketPickupWaitV279.radiusV654
                }
                if (!sigScopeV654 && IsObject(farmItemLockV625) && farmItemLockV625.pid=selectedPid && farmItemLockV625.player=pPlayer)
                {
                    inside := inside && (sx-farmItemLockV625.x)**2+(sy-farmItemLockV625.y)**2<=farmItemLockV625.pickupRadiusSqV648
                    dist := Sqrt(dx*dx+dy*dy)
                }
                inRangeV654 := sigScopeV654 ? inside : (dist<=pickupRadius)
                optUnitV12 := inside && inRangeV654 ? pUnit : 0
                inPickupFile := (itemQuality > 0) && !PickupFarmIgnoredV762(selectedPid,unitId)
                    ? PickupFileHasRuleV97(cls, itemQuality, itemData, h, optUnitV12) : false
                if (inside)
                {
                    nearItems++
                    if (cls != 1214 && unitId && itemData && inPickupFile
                        && inRangeV654)
                    {
                        firstRule := hasPriority && cls = priorityClass
                            && Format("{:02X}", itemQuality) = priorityQ
                        roundCandidates.Push({uid:unitId,unit:pUnit,cls:cls,data:itemData
                            ,dist:dist,firstRule:firstRule,priorityV254:PickupFixedPriorityV254(cls,itemQuality)
                            ,skipCube:PickupFileStashOnlyV97(cls,itemQuality,h)})
                    }
                    if (cls != 1214 && inPickupFile && dist < bestDist)
                        bestDist := dist, bestUnit := pUnit, bestUnitId := unitId, bestClass := cls, bestX := sx, bestY := sy
                    if (cls != 1214 && inPickupFile && hasPriority && inRangeV654
                        && cls = priorityClass && Format("{:02X}", itemQuality) = priorityQ
                        && dist < priorityDist)
                        priorityDist := dist, priorityUnit := pUnit, priorityUnitId := unitId, priorityX := sx, priorityY := sy
                }
                out .= "ITEM#" . totalItems . " room=" . ri . " unit=0x" . Format("{:08X}", pUnit)
                    . " id=" . unitId . " class=" . cls . " xy=(" . sx . "," . sy . ") dist=" . dist
                    . " itemdata=" . Format("{:02X}", itemQuality)
                    . (inPickupFile ? " [FILE_OK]" : " [NOT_IN_FILE]")
                    . (inside ? " [IN_RADIUS]" : "") . "`r`n"
                if (cls != 1214)
                    diag .= A_Now . " tick=" . A_TickCount . " | ITEM id=" . unitId . " unit=0x" . Format("{:08X}", pUnit)
                        . " class=" . cls . " itemdata=" . Format("{:02X}", itemQuality)
                        . " itemDataPtr=0x" . Format("{:08X}", itemData)
                        . " path=0x" . Format("{:08X}", ipath)
                        . " xy=(" . sx . "," . sy . ") player=(" . px . "," . py . ") dist=" . dist
                        . " rule=" . (inPickupFile ? "FILE_OK" : "NOT_IN_FILE")
                        . " radius=" . (inside ? "IN" : "OUT") . "`r`n"
            }
            nxt := D2ReadU32(h, pUnit + 0xE8)
            if (nxt = pUnit)
            {
                if (verifyScanV754)
                    scanCompleteV654 := false
                break
            }
            pUnit := nxt
            if (verifyScanV754 && A_Index=4096 && pUnit)
                scanCompleteV654 := false
        }
    }
    out .= "ALL ROOMS SUMMARY: rooms=" . rooms.Length() . " units=" . totalUnits . " items=" . totalItems . " inRadius=" . nearItems . "`r`n"
    
    if (CubeResetPendingV754(selectedPid))
        CubeResetNormalScanV754(selectedPid,RoomRecordLevelV259(selectedPid),h,pPlayer,scanSerialV754
        ,scanCompleteV654 && rooms.Length() && totalUnits && !roundCandidates.Length()
        && !roundOn && !IsObject(pending) && !ConsumableNamesPendingV7()
        && !PickupOptPidPendingV655(selectedPid),px,py)
    if (IsObject(ticketPickupWaitV279) && ticketPickupWaitV279.pid=selectedPid)
    {
        waitV279 := ticketPickupWaitV279
        waitV279.remaining := roundCandidates.Length(),waitV279.scanAt := A_TickCount
        waitV279.scanSerialV764 := scanSerialV754
        cursorV279 := PickupCursorV4(h,D2ReadU32(h,pPlayer+0x60))
        namesPendingV468 := ConsumableNamesPendingV7()
        waitV279.blockReasonV468 := roundCandidates.Length() ? "GROUND_ITEMS"
            : roundOn ? "PICKUP_ROUND" : IsObject(pending) ? "ITEM_CONFIRM"
            : namesPendingV468 || (verifyScanV754 && PickupOptPidPendingV655(selectedPid)) ? "ITEM_NAME_JOB"
            : !scanCompleteV654 || !rooms.Length() || !totalUnits ? "ROOM_READ"
            : RoomRecordLevelV259(selectedPid)!=waitV279.level ? "MAP_CHANGED"
            : !IsObject(cursorV279) || cursorV279.unit ? "CURSOR_BUSY" : ""
        if (waitV279.blockReasonV468!="")
            waitV279.emptyAt := 0,waitV279.checks := 0,waitV279.done := false
        else
        {
            if (!waitV279.emptyAt)
                waitV279.emptyAt := A_TickCount
            waitV279.checks++
            if (waitV279.checks>=3 && A_TickCount-waitV279.emptyAt>=1200)
                waitV279.done := true

        }
    }
    if (roundCandidates.Length())
        emptySinceV16 := 0, emptyChecksV16 := 0
    if (pickupOneShotV216 && !roundOn && !IsObject(pending) && !roundCandidates.Length() && !ConsumableNamesPendingV7())
    {
        if (!emptySinceV16)
            emptySinceV16 := A_TickCount
        emptyChecksV16++
        cursorV16 := PickupCursorV4(h,D2ReadU32(h,pPlayer+0x60))
        if (emptyChecksV16<3 || A_TickCount-emptySinceV16<1200 || !IsObject(cursorV16) || cursorV16.unit)
            return out
        PickupCtrlEndV26()
        if (!pickupImageOn)
            SetTimer, PickupImageTimer, Off
        ToolTipInfoV386("ĐÃ KIỂM TRA HẾT ĐỒ TRONG BÁN KÍNH - NHẶT XONG")
        SetTimer, RemoveToolTip, -2000
        return out
    }
    ; PICKUP_FIX_2026: A partial/empty room read is not evidence of empty ground.
    if (farmBatch && (!scanCompleteV654 || !rooms.Length() || !totalUnits))
        return out
    if (farmBatch)
    {
        farmCenterCycleV741.pickupPass++
        if (!roundCandidates.Length())
        {
            ; PICKUP_FIX_2026: A zero-candidate scan does not mean the
            ; locked item has been collected. Re-read its ground UID before DONE.
            if (IsObject(farmItemLockV625) && !farmItemLockV625.itemPickedV1602
                && farmItemLockV625.pid=selectedPid)
            {
                lockedV2026 := farmItemLockV625
                groundV2026 := {uid:lockedV2026.uid,cls:lockedV2026.cls}
                if (PickupGroundRebindV123(h,pPlayer,groundV2026))
                {
                    lockedV2026.groundLostAtV2026 := 0
                    groundPathV2026 := D2ReadU32(h,groundV2026.unit+0x2C)
                    gxV2026 := groundPathV2026 ? D2ReadU32(h,groundPathV2026+0x0C) : 0
                    gyV2026 := groundPathV2026 ? D2ReadU32(h,groundPathV2026+0x10) : 0
                    if (gxV2026 && gyV2026 && PickupFarmIgnoredV762(selectedPid,groundV2026.uid))
                    {
                        PortalLogWriteV66("FARM_PICKUP_LOCK_RELEASE uid=" . groundV2026.uid
                            . " reason=FAILED_PICKUP_COOLDOWN next=RESUME_FARM")
                        farmItemLockV625 := false
                        farmCenterCycleV741.pickupStateV905 := "DONE"
                        farmCenterCycleV741.pickupResultV905 := "SKIPPED_COOLDOWN"
                        farmCenterCycleV741.phase := "CHECK"
                        farmEmptyChecksV940 := 0,farmLastEmptyAtV940 := 0
                        pickupRoundResetV1 := true
                        return out
                    }
                    groundRuleV2026 := PickupFileHasRuleV97(lockedV2026.cls
                        ,D2ReadU8V18(h,groundV2026.data),groundV2026.data,h,groundV2026.unit)
                    if (groundRuleV2026 && gxV2026 && gyV2026)
                    {
                        groundDistV2026 := Sqrt((gxV2026-px)**2+(gyV2026-py)**2)
                        if (groundDistV2026<=Max(1,pickupRadius))
                        {
                            ; A scanned ground item remains eligible: do not
                            ; let an incomplete round force route continuation.
                            roundCandidates.Push({uid:groundV2026.uid,unit:groundV2026.unit
                                ,cls:groundV2026.cls,data:groundV2026.data,dist:groundDistV2026
                                ,firstRule:false,priorityV254:PickupFixedPriorityV254(groundV2026.cls
                                    ,D2ReadU8V18(h,groundV2026.data))
                                ,skipCube:PickupFileStashOnlyV97(groundV2026.cls
                                    ,D2ReadU8V18(h,groundV2026.data),h)})
                            PortalLogWriteV66("FARM_PICKUP_LOCK_RESCAN uid=" . groundV2026.uid
                                . " dist=" . Round(groundDistV2026,1) . " action=RETRY_PICKUP"
                                ,"FARM_PICKUP_LOCK_RESCAN",1000)
                        }
                        else
                        {
                            ; Still on the ground but out of range: release the
                            ; temporary target and resume the farm route.
                            PortalLogWriteV66("FARM_PICKUP_SKIP_OUT_OF_RANGE uid=" . groundV2026.uid
                                . " dist=" . Round(groundDistV2026,1)
                                . " radius=" . Max(1,pickupRadius) . " next=RESUME_ROUTE")
                            farmItemLockV625 := false
                            farmCenterCycleV741.phase := "CHECK"
                            farmCenterCycleV741.pickupStateV905 := "DONE"
                            farmCenterCycleV741.pickupResultV905 := "OUT_OF_RANGE"
                            pickupRoundResetV1 := true
                            return out
                        }
                    }
                    else if (!groundRuleV2026)
                    {
                        ; The current item filter is authoritative. A rule
                        ; change is not a successful pickup.
                        PortalLogWriteV66("FARM_PICKUP_RULE_CHANGED uid=" . groundV2026.uid
                            . " next=RESUME_ROUTE")
                        farmItemLockV625 := false
                    }
                    else
                    {
                        PortalLogWriteV66("FARM_PICKUP_GROUND_COORD_WAIT uid=" . groundV2026.uid
                            . " next=RESCAN", "FARM_PICKUP_GROUND_COORD_WAIT",1000)
                        return out
                    }
                }
                else
                {
                    ; Item may have entered inventory/cube or disappeared.
                    ; Wait for a stable observation and explicitly label it.
                    if (!lockedV2026.groundLostAtV2026)
                        lockedV2026.groundLostAtV2026 := A_TickCount
                    if (A_TickCount-lockedV2026.groundLostAtV2026<800)
                        return out
                    invV2026 := D2ReadU32(h,pPlayer+0x60)
                    firstV2026 := invV2026 ? D2ReadU32(h,invV2026+0x10) : 0
                    if (firstV2026)
                    {
                        snapV2026 := V9SnapshotAllItems({pid:selectedPid,h:h,inv:invV2026,first:firstV2026})
                        if (snapV2026.HasKey(lockedV2026.uid))
                        {
                            gotV2026 := snapV2026[lockedV2026.uid]
                            if (gotV2026.cls=lockedV2026.cls
                                && ((gotV2026.loc=0 && gotV2026.owner=invV2026) || gotV2026.loc=3))
                            {
                                lockedV2026.itemPickedV1602 := true
                                PortalLogWriteV66("FARM_PICKUP_LOCK_CONFIRMED uid=" . lockedV2026.uid
                                    . " location=" . gotV2026.loc . " next=CHECK_REMAINING")
                            }
                        }
                    }
                }
            }
            if (!roundCandidates.Length())
            {
                if (!farmLastEmptyAtV940 || A_TickCount-farmLastEmptyAtV940>=150)
                    farmLastEmptyAtV940 := A_TickCount,farmEmptyChecksV940++
                if (farmEmptyChecksV940>=3 && !ConsumableNamesPendingV7())
                {
                    resultV2026 := !IsObject(farmItemLockV625) ? "GROUND_EMPTY_3_CHECKS"
                        : farmItemLockV625.itemPickedV1602 ? "PICKUP_CONFIRMED" : "GROUND_GONE_UNVERIFIED"
                    farmCenterCycleV741.pickupStateV905 := "DONE"
                    farmCenterCycleV741.pickupResultV905 := resultV2026
                    farmCenterCycleV741.phase := "CHECK"
                    farmItemLockV625 := false
                    pickupRoundResetV1 := true
                    PortalLogWriteV66("FARM_PICKUP_ALL_DONE empty_checks=" . farmEmptyChecksV940
                        . " scan_complete=1 result=" . resultV2026)
                }
                return out
            }
        }
        farmEmptyChecksV940 := 0,farmLastEmptyAtV940 := 0
    }
    if (roundCandidates.Length())
    {
        Loop, % roundCandidates.Length()
        {
            i := A_Index, nearest := i
            Loop, % roundCandidates.Length()-i
            {
                j := i+A_Index
                if (roundCandidates[j].priorityV254<roundCandidates[nearest].priorityV254
                    || (roundCandidates[j].priorityV254=roundCandidates[nearest].priorityV254
                        && roundCandidates[j].dist<roundCandidates[nearest].dist))
                    nearest := j
            }
            if (nearest != i)
                swap := roundCandidates[i], roundCandidates[i] := roundCandidates[nearest], roundCandidates[nearest] := swap
        }
        if (farmBatch && roundCandidates.Length()>1)
            roundCandidates := [roundCandidates[1]]  ; nhat 1 mon, quet lai sau moi mon
        roundItems := roundCandidates, roundIndex := 1, roundOn := true
    }
    else if (!lastIdleLog || A_TickCount - lastIdleLog >= 2000)
    {
        lastIdleLog := A_TickCount
        V104CubeLog("PICKUP_SCAN_EMPTY ground=" . totalItems . " near=" . nearItems
            . " rules=" . pickupAllowCount . " bestDist=" . bestDist
            . " radius=" . pickupRadius . " pickup=ON")
    }
    return out
    }
    finally
    {
        PickupOptPollV12()
        pickupFarmWorkV75 := pickupImageOn && (IsObject(pending) || (roundOn && roundIndex<=roundItems.Length()))
    }
}

V5SendMove03(hProcess, x, y, ByRef info)
{
    if (RemoteThreadBusyV740(D2GetActiveGamePidV95()))
        return false
    pid := D2GetProcessIdFromHandle(hProcess)
    if (!pid) {
        info := "pid=0"
        return false
    }
    netBase := D2GetModuleBaseV35(pid, "D2Net.dll")
    if (!netBase) {
        info := "D2Net=0"
        return false
    }
    hp := DllCall("OpenProcess", "UInt", 0x043A, "Int", 0, "UInt", pid, "Ptr")
    if (!hp) {
        info := "OpenProcess fail=" . A_LastError
        return false
    }
    sendFn := netBase + 0x7650
    remote := DllCall("VirtualAllocEx", "Ptr", hp, "Ptr", 0, "UPtr", 96, "UInt", 0x3000, "UInt", 0x40, "Ptr")
    if (!remote) {
        DllCall("CloseHandle","Ptr",hp)
        info := "alloc fail"
        return false
    }
    VarSetCapacity(pkt,5,0)
    NumPut(0x03,pkt,0,"UChar")
    NumPut(x & 0xFFFF,pkt,1,"UShort")
    NumPut(y & 0xFFFF,pkt,3,"UShort")
    w1:=0
    a:=DllCall("WriteProcessMemory","Ptr",hp,"Ptr",remote+64,"Ptr",&pkt,"UPtr",5,"UPtrP",w1)
    VarSetCapacity(code,32,0), o:=0
    NumPut(0x68,code,o,"UChar"),o+=1, NumPut(remote+64,code,o,"UInt"),o+=4
    NumPut(0x6A,code,o,"UChar"),o+=1, NumPut(1,code,o,"UChar"),o+=1
    NumPut(0x6A,code,o,"UChar"),o+=1, NumPut(5,code,o,"UChar"),o+=1
    NumPut(0xB8,code,o,"UChar"),o+=1, NumPut(sendFn,code,o,"UInt"),o+=4
    NumPut(0xFF,code,o,"UChar"),o+=1, NumPut(0xD0,code,o,"UChar"),o+=1, NumPut(0xC3,code,o,"UChar"),o+=1
    w2:=0
    b:=DllCall("WriteProcessMemory","Ptr",hp,"Ptr",remote,"Ptr",&code,"UPtr",o,"UPtrP",w2)
    if (!a || !b) {
        DllCall("VirtualFreeEx","Ptr",hp,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hp)
        info := "write fail"
        return false
    }
    th:=DllCall("CreateRemoteThread","Ptr",hp,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
    if (!th) {
        DllCall("VirtualFreeEx","Ptr",hp,"Ptr",remote,"UPtr",0,"UInt",0x8000)
        DllCall("CloseHandle","Ptr",hp)
        info := "thread fail"
        return false
    }
    wait:=DllCall("WaitForSingleObject","Ptr",th,"UInt",1000), ex:=0
    waitLimit := 5
    while (wait == 258 && IsGameActive() && waitLimit > 0)
    {
        wait:=DllCall("WaitForSingleObject","Ptr",th,"UInt",1000)
        waitLimit--
    }
    DllCall("GetExitCodeThread","Ptr",th,"UIntP",ex)
    RemoteThreadFinishV740(hp,th,remote,wait)
    info := "03 x=" . x . " y=" . y . " wait=" . wait . " exit=" . ex
    return wait=0
}
D2RemotePickupPacket(hProcess, unitId, ByRef info, itemClass:=0)
{
    if (RemoteThreadBusyV740(D2GetActiveGamePidV95()))
        return false
    MovementCtrlSetV78(false,0,"D2RemotePickupPacket")
    pid := D2GetProcessIdFromHandle(hProcess)
    if (!pid)
    {
        info := "pid=0"
        return false
    }
    if (!PickupFarmTryV762(pid,unitId,itemClass))
    {
        info := "FARM_PICKUP_RETRY_LIMIT_OR_COOLDOWN"
        return false
    }

    netBase := D2GetModuleBaseV35(pid, "D2Net.dll")
    if (!netBase)
    {
        info := "D2Net=0"
        return false
    }
    hPickup := DllCall("OpenProcess", "UInt", 0x043A, "Int", 0, "UInt", pid, "Ptr")
    if (!hPickup)
    {
        info := "OpenProcess pickup fail err=" . A_LastError
        return false
    }
    hProcess := hPickup
    sendFn := netBase + 0x7650
    remote := DllCall("VirtualAllocEx", "Ptr", hProcess, "Ptr", 0, "UPtr", 128, "UInt", 0x3000, "UInt", 0x40, "Ptr")
    if (!remote)
    {
        err73 := A_LastError
        DllCall("CloseHandle", "Ptr", hPickup)
        info := "VirtualAllocEx fail err=" . err73
        return false
    }
    VarSetCapacity(pkt, 13, 0)
    NumPut(0x16, pkt, 0, "UChar")
    NumPut(4, pkt, 1, "UInt")
    NumPut(unitId, pkt, 5, "UInt")
    NumPut(0, pkt, 9, "UInt")
    wrote := 0
    ok1 := DllCall("WriteProcessMemory", "Ptr", hProcess, "Ptr", remote+64, "Ptr", &pkt, "UPtr", 13, "UPtrP", wrote)
    VarSetCapacity(code, 32, 0)
    o := 0
    NumPut(0x68, code, o, "UChar"), o += 1
    NumPut(remote+64, code, o, "UInt"), o += 4
    NumPut(0x6A, code, o, "UChar"), o += 1
    NumPut(0x01, code, o, "UChar"), o += 1
    NumPut(0x6A, code, o, "UChar"), o += 1
    NumPut(0x0D, code, o, "UChar"), o += 1
    NumPut(0xB8, code, o, "UChar"), o += 1
    NumPut(sendFn, code, o, "UInt"), o += 4
    NumPut(0xFF, code, o, "UChar"), o += 1
    NumPut(0xD0, code, o, "UChar"), o += 1
    NumPut(0xC3, code, o, "UChar"), o += 1
    wrote2 := 0
    ok2 := DllCall("WriteProcessMemory", "Ptr", hProcess, "Ptr", remote, "Ptr", &code, "UPtr", o, "UPtrP", wrote2)
    if (!ok1 || !ok2)
    {
        DllCall("VirtualFreeEx", "Ptr", hProcess, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        err73 := A_LastError
        DllCall("CloseHandle", "Ptr", hPickup)
        info := "WriteProcessMemory fail err=" . err73
        return false
    }
    th := DllCall("CreateRemoteThread", "Ptr", hProcess, "Ptr", 0, "UPtr", 0, "Ptr", remote, "Ptr", 0, "UInt", 0, "UIntP", tid, "Ptr")
    if (!th)
    {
        DllCall("VirtualFreeEx", "Ptr", hProcess, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        err73 := A_LastError
        DllCall("CloseHandle", "Ptr", hPickup)
        info := "CreateRemoteThread fail err=" . err73
        return false
    }
    wait62 := DllCall("WaitForSingleObject", "Ptr", th, "UInt", 1000)
    waitLimit := 5
    while (wait62 == 258 && IsGameActive() && waitLimit > 0)
    {
        wait62 := DllCall("WaitForSingleObject", "Ptr", th, "UInt", 1000)
        waitLimit--
    }
    exitCode62 := 0
    DllCall("GetExitCodeThread", "Ptr", th, "UIntP", exitCode62)
    RemoteThreadFinishV740(hPickup,th,remote,wait62)
    info := "packet=16/04/id/0 len=13 wrotePkt=" . wrote . " wroteCode=" . wrote2 . " threadExit=0x" . Format("{:08X}", exitCode62) . " D2Net=0x" . Format("{:08X}", netBase) . " Send=0x" . Format("{:08X}", sendFn)
    return wait62=0
}

D2GetModuleBaseV35(pid, wanted)
{
    static cacheV690 := {}
    key := pid . "|" . wanted
    if (cacheV690.HasKey(key) && A_TickCount - cacheV690[key].at < 500 && cacheV690[key].base)
        return cacheV690[key].base
    snap := DllCall("CreateToolhelp32Snapshot", "UInt", 0x8|0x10, "UInt", pid, "Ptr")
    if (snap = -1 || !snap)
        return 0
    sz := (A_PtrSize = 8) ? 1080 : 1064
    nameOffset := (A_PtrSize = 8) ? 48 : 32
    baseOffset := (A_PtrSize = 8) ? 24 : 20
    VarSetCapacity(me, sz, 0)
    NumPut(sz, me, 0, "UInt")
    ok := DllCall("Module32FirstW", "Ptr", snap, "Ptr", &me)
    base := 0
    while (ok)
    {
        name := StrGet(&me + nameOffset, 256, "UTF-16")
        if (name = wanted)
        {
            base := NumGet(me, baseOffset, "Ptr")
            break
        }
        ok := DllCall("Module32NextW", "Ptr", snap, "Ptr", &me)
    }
    DllCall("CloseHandle", "Ptr", snap)
    if (base)
        cacheV690[key] := {base:base, at:A_TickCount}
    return base
}


D2ReadUnicodeV33(hProc, addr, byteLen)
{
    if (!addr || byteLen <= 0 || byteLen > 2048)
        return ""
    VarSetCapacity(buf, byteLen + 2, 0)
    got := 0
    if (!DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", addr, "Ptr", &buf, "UPtr", byteLen, "UPtr*", got))
        return ""
    if (got <= 0)
        return ""
    return StrGet(&buf, Floor(got/2), "UTF-16")
}

D2EnableDebugPrivilege()
{
    if (!DllCall("advapi32\OpenProcessToken", "Ptr", DllCall("GetCurrentProcess", "Ptr"), "UInt", 0x20|0x8, "Ptr*", hToken))
        return false

    VarSetCapacity(luid, 8, 0)
    if (!DllCall("advapi32\LookupPrivilegeValueW", "Ptr", 0, "WStr", "SeDebugPrivilege", "Ptr", &luid))
    {
        DllCall("CloseHandle", "Ptr", hToken)
        return false
    }

    VarSetCapacity(tp, 16, 0)
    NumPut(1, tp, 0, "UInt")
    NumPut(NumGet(luid,0,"UInt"), tp, 4, "UInt")
    NumPut(NumGet(luid,4,"Int"), tp, 8, "Int")
    NumPut(2, tp, 12, "UInt")
    ok := DllCall("advapi32\AdjustTokenPrivileges", "Ptr", hToken, "Int", 0, "Ptr", &tp, "UInt", 0, "Ptr", 0, "Ptr", 0)
    err := A_LastError
    DllCall("CloseHandle", "Ptr", hToken)
    return (ok && err = 0)
}


EnableGameDebugPrivilege()
{
    global debugPrivilegeError
    debugPrivilegeError := 0
    token := 0
    process := DllCall("GetCurrentProcess", "Ptr")
    if (!DllCall("advapi32\OpenProcessToken", "Ptr", process, "UInt", 0x28, "Ptr*", token))
    {
        debugPrivilegeError := A_LastError
        return false
    }
    VarSetCapacity(luid, 8, 0)
    if (!DllCall("advapi32\LookupPrivilegeValueW", "Ptr", 0, "WStr", "SeDebugPrivilege", "Ptr", &luid))
    {
        debugPrivilegeError := A_LastError
        DllCall("CloseHandle", "Ptr", token)
        return false
    }
    VarSetCapacity(tp, 16, 0)
    NumPut(1, tp, 0, "UInt")
    NumPut(NumGet(luid, 0, "UInt"), tp, 4, "UInt")
    NumPut(NumGet(luid, 4, "UInt"), tp, 8, "UInt")
    NumPut(2, tp, 12, "UInt")
    DllCall("SetLastError", "UInt", 0)
    ok := DllCall("advapi32\AdjustTokenPrivileges", "Ptr", token, "Int", false
        , "Ptr", &tp, "UInt", 0, "Ptr", 0, "Ptr", 0)
    debugPrivilegeError := A_LastError
    DllCall("CloseHandle", "Ptr", token)
    return ok && debugPrivilegeError=0
}

D2OpenProcess(pid)
{
    return DllCall("OpenProcess", "UInt", 0x043A, "Int", 0, "UInt", pid, "Ptr")
}

D2ReadU32(hProc, addr)
{
    VarSetCapacity(buf, 4, 0)
    if (!DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 4, "UPtr*", got))
        return 0
    return NumGet(buf, 0, "UInt")
}

D2ReadU16(hProc, addr)
{
    VarSetCapacity(buf, 2, 0)
    if (!DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", addr, "Ptr", &buf, "UPtr", 2, "UPtr*", got))
        return 0
    return NumGet(buf, 0, "UShort")
}

D2GetModuleBase(pid, moduleName)
{
    snap := DllCall("CreateToolhelp32Snapshot", "UInt", 0x00000008|0x00000010, "UInt", pid, "Ptr")
    if (snap = -1 || !snap)
        return 0

    sz := (A_PtrSize = 8) ? 1080 : 1064
    VarSetCapacity(me, sz, 0)
    NumPut(sz, me, 0, "UInt")

    target := moduleName
    StringLower, target, target
    base := 0

    ok := DllCall("Module32FirstW", "Ptr", snap, "Ptr", &me)
    while (ok)
    {
        nameOff := (A_PtrSize = 8) ? 48 : 32
        name := StrGet(&me + nameOff, 256, "UTF-16")
        StringLower, name, name
        if (name = target)
        {
            baseOff := (A_PtrSize = 8) ? 24 : 20
            base := NumGet(me, baseOff, "Ptr")
            break
        }
        ok := DllCall("Module32NextW", "Ptr", snap, "Ptr", &me)
    }
    DllCall("CloseHandle", "Ptr", snap)
    return base
}

Cycle6GuiSyncV525()
{
    BuffSequenceGuiSyncV555()
}

BuffSequenceToggleV555:
BuffSequenceSetV555(!buffSequenceOnV555)
return

BuffSequenceDelayChangedV555:
buffSequenceDelayV555 := BuffSequenceDelayGetV555()
buffSequenceNextV555 := A_TickCount+buffSequenceDelayV555
sectionV555 := ProfileSection(currentProfile)
IniWrite, %buffSequenceDelayV555%, % ProfileConfigPathV364(sectionV555), %sectionV555%, BuffSequenceDelayMs
return

BuffSequenceTimerV555:
BuffSequenceTickV555()
return

BuffSequenceDelayGetV555()
{
    global buffSequenceDelayV555
    if (ProfileControlExistsV365("BuffSequenceDelayInputV555"))
        GuiControlGet, value, 1:, BuffSequenceDelayInputV555
    else
        value := buffSequenceDelayV555
    if (!RegExMatch(value,"^\d+$") || value<1)
        return 30000
    return Min(86400000,value+0)
}

BuffSequenceGuiSyncV555()
{
    global buffSequenceOnV555
    if (ProfileControlExistsV365("BuffSequenceButtonV555"))
        GuiControl, 1:, BuffSequenceButtonV555, % buffSequenceOnV555 ? "Auto Buff Delay *" : "Auto Buff Delay"
}

BuffSequenceSetV555(on)
{
    global buffSequenceOnV555,buffSequenceEpochV555,buffSequenceNextV555,buffSequenceDelayV555
    global QCastOn,cycleOn,master456Paused,master456Saved
    if (on && (!SigBackgroundBindV179() || !BackgroundValidV63()))
    {
        ToolTipInfoV386("Chưa nhận được cửa sổ game để chạy Auto Buff Delay.")
        SetTimer, RemoveToolTip, -2500
        return false
    }
    buffSequenceEpochV555++,buffSequenceOnV555 := on ? true : false
    buffSequenceNextV555 := 0
    if (on)
    {
        buffSequenceDelayV555 := BuffSequenceDelayGetV555()
        SetTimer, BuffSequenceTimerV555, 100
    }
    else
    {
        SetTimer, BuffSequenceTimerV555, Off
        FarmAttackHoldReleaseV15()
    }
    BuffSequenceGuiSyncV555()
    return true
}

BuffSequenceContinueV555()
{
    global buffSequenceOnV555,buffSequenceRunningV555,buffSequenceEpochV555,buffSequenceRunEpochV555
    return !buffSequenceRunningV555 || (buffSequenceOnV555 && buffSequenceEpochV555=buffSequenceRunEpochV555)
}

BuffSequenceTickV555()
{
    global buffSequenceOnV555,buffSequenceRunningV555,buffSequenceEpochV555,buffSequenceRunEpochV555,buffSequenceNextV555
    global xRunning,zRunning,gameItemActionOwner,sigBusyV147,sigTownV148,packetWatchArmedV1,stageTwoV166,QCastOn
    if (!buffSequenceOnV555 || buffSequenceRunningV555 || A_TickCount<buffSequenceNextV555
        || xRunning || zRunning || gameItemActionOwner!="" || sigBusyV147 || IsObject(sigTownV148)
        || packetWatchArmedV1 || IsObject(stageTwoV166) || !IsGameActive())
        return
    FarmAttackHoldReleaseV15()
    if (!AutoMonsterPacketCleanupV1())
        return
    pid := D2GetActiveGamePidV95(),base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return
    buffSequenceRunningV555 := true,buffSequenceRunEpochV555 := buffSequenceEpochV555
    runEpoch := buffSequenceEpochV555,ok := false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),mode := player ? D2ReadU32(h,player+0x10) : 0
        if (!player || mode=0 || mode=17)
            return
        ok := AutoBuffOnlySequenceV555(h,player,pid)
    }
    finally
    {
        DllCall("CloseHandle","Ptr",h)
        buffSequenceRunningV555 := false
        if (buffSequenceOnV555 && runEpoch=buffSequenceEpochV555)
            buffSequenceNextV555 := A_TickCount+(ok ? BuffSequenceDelayGetV555() : 1000)
    }
}


; AUTO BUFF DELAY ONLY: shared buff form actions but NO farm pre-buff
; combat scan, attack, returning to original XY, or SCOS point 2 movement.
; Do not call RouteBuffSequenceV20 here: that routine deliberately invokes
; FarmPreBuffCombatCheckV710 and can dispatch NativeMovePointV14.
AutoBuffOnlySequenceV555(h,player,pid)
{
    global buffSequenceOnV555,buffSequenceRunEpochV555,buffSequenceEpochV555
    global xRunning,zRunning,gameItemActionOwner
    if (!buffSequenceOnV555 || buffSequenceRunEpochV555!=buffSequenceEpochV555
        || xRunning || zRunning || gameItemActionOwner!=""
        || !IsGameActive() || D2GetActiveGamePidV95()!=pid)
        return false
    if (!FarmBuffForm1V906(pid) || !BuffSequenceContinueV555())
        return false
    if (!FarmBuffThreeRowsV519(h,player,pid) || !BuffSequenceContinueV555())
        return false
    if (!FarmBuffForm5V906() || !BuffSequenceContinueV555())
        return false
    if (!FarmBuffForm6SelectV906() || !BuffSequenceContinueV555())
        return false
    return true
}

ToggleCycle:
if (master456Paused)
    return

cycleOn := !cycleOn
Cycle6GuiSyncV525()

if (cycleOn)
{
    cycleStep := 1
    nextStepTime := 0
    ToolTipInfoV386("Auto Bấm Dãy F: ON")
}
else
{
    ToolTipInfoV386("Auto Bấm Dãy F: OFF")
}

SetTimer, RemoveToolTip, -3000

return

SaveAllConfig()
{
    global selectedTabV6, ConfigFile
    GuiControlGet, selectedTabV6,, AutoGSFMainTabs
    if (selectedTabV6>=1 && selectedTabV6<=4)
        IniWrite, %selectedTabV6%, %ConfigFile%, General, SelectedTab
    SaveMaster456Key()
    SaveClickCastConfig("ClickCast")
    global ConfigFile

    global zKey
    global xKey

    global doubleKey
    global doubleTapMs

    global formDoubleKey
    global formDoubleTapMs
    global qCastDoubleKey
    global qCastDoubleTapMs

    global zSetKey, zSetDelay, xDelay
    global zSetKey, zSetDelay, xDelay
    global zFKey
    global zFKey2
    global zDelay1
    global zDelay2
    global zDelay3
    global QCastKey1, QCastKey2, QCastKey3, QCastDelay1, QCastDelay2, QCastDelay3
    global QCastKey1, QCastKey2, QCastKey3, QCastDelay1, QCastDelay2, QCastDelay3

    global FKey1, FKey2, FKey3, FKey4
    global FKey5, FKey6, FKey7, FKey8
    global FKey9, FKey10

    global FDelay1, FDelay2, FDelay3, FDelay4
    global FDelay5, FDelay6, FDelay7, FDelay8
    global FDelay9, FDelay10
    global autoPotOn, invHealOn, invManaOn, cubeHealOn, cubeManaOn, potMode, potCaptureKey1, potHPThreshold, potHPThreshold2V299, potCooldown
    global manaOn, manaMode, manaThreshold, manaCooldown
    global sigKeyV147,sigSuKeyV181,farmNaoKeyV181,pickupBackgroundV181
    global pickupToggleKeyV79, pickupImageOn, getIdKey, deleteIdKey, pickupRadius, pickupFailTeleRadiusV1253
	global petLearnEnabledV12
    IniWrite, 1, %ConfigFile%, General, Version

    global profileList, currentProfile
    IniWrite, %profileList%, %ConfigFile%, Profiles, Names
    IniWrite, %currentProfile%, %ConfigFile%, Profiles, Current
    IniWrite, %currentProfile%, %ConfigFile%, Settings, LastProfile

    IniWrite, %zKey%, %ConfigFile%, Keys, Z
    IniWrite, %xKey%, %ConfigFile%, Keys, X

    IniWrite, %doubleKey%, %ConfigFile%, Double, Key
    IniWrite, %doubleTapMs%, %ConfigFile%, Double, Interval

    IniWrite, %formDoubleKey%, %ConfigFile%, FormDouble, Key
    IniWrite, %formDoubleTapMs%, %ConfigFile%, FormDouble, Interval

    IniWrite, %qCastDoubleKey%, %ConfigFile%, QCastDouble, Key
    IniWrite, %qCastDoubleTapMs%, %ConfigFile%, QCastDouble, Interval

    IniWrite, %zFKey%, %ConfigFile%, Z, FKey
    kill2GeneralSave := (zFKey2 = "" ? "None" : zFKey2)
IniWrite, %kill2GeneralSave%, %ConfigFile%, Z, FKey2
    IniWrite, %zDelay1%, %ConfigFile%, Z, Delay1
    IniWrite, %zDelay2%, %ConfigFile%, Z, Delay2
    IniWrite, %zDelay3%, %ConfigFile%, Z, Delay3

    IniWrite, %zSetKey%, %ConfigFile%, Z, SetKey
    IniWrite, %zSetDelay%, %ConfigFile%, Z, SetDelay
    IniWrite, %xDelay%, %ConfigFile%, X, Delay
    Loop, 3
    {
        qIndex := A_Index
        qKey := QCastKey%qIndex%
        qDelay := QCastDelay%qIndex%
        IniWrite, %qKey%, %ConfigFile%, QCast, Key%qIndex%
        IniWrite, %qDelay%, %ConfigFile%, QCast, Delay%qIndex%
    }

    IniRead, zSetKey, %ConfigFile%, Z, SetKey, %zSetKey%
    IniRead, zSetDelay, %ConfigFile%, Z, SetDelay, %zSetDelay%
    IniRead, xDelay, %ConfigFile%, X, Delay, %xDelay%
    Loop, 3
    {
        qIndex := A_Index
        defaultQKey := QCastKey%qIndex%
        defaultQDelay := QCastDelay%qIndex%
        IniRead, tempQKey, %ConfigFile%, QCast, Key%qIndex%, %defaultQKey%
        IniRead, tempQDelay, %ConfigFile%, QCast, Delay%qIndex%, %defaultQDelay%
        QCastKey%qIndex% := tempQKey
        QCastDelay%qIndex% := tempQDelay
    }

    IniWrite, %autoPotOn%, %ConfigFile%, AutoPot, Enabled
    IniWrite, %invHealOn%, %ConfigFile%, AutoPot, InventoryHealEnabled
    IniWrite, %invManaOn%, %ConfigFile%, AutoPot, InventoryManaEnabled
    IniWrite, %cubeHealOn%, %ConfigFile%, AutoPot, CubeHealEnabled
    IniWrite, %cubeManaOn%, %ConfigFile%, AutoPot, CubeManaEnabled
    IniWrite, %potMode%, %ConfigFile%, AutoPot, Mode
    IniWrite, %potCaptureKey1%, %ConfigFile%, AutoPot, CaptureKey1
    IniWrite, %potHPThreshold%, %ConfigFile%, AutoPot, PotHPThreshold
    IniWrite, %potHPThreshold2V299%, %ConfigFile%, AutoPot, PotHPThreshold2
    IniWrite, %potCaptureKey2%, %ConfigFile%, AutoPot, CaptureKey2
    IniWrite, %potCooldown%, %ConfigFile%, AutoPot, Cooldown
    IniWrite, %manaOn%, %ConfigFile%, AutoMana, Enabled
    IniWrite, %manaMode%, %ConfigFile%, AutoMana, Mode
    IniWrite, %manaThreshold%, %ConfigFile%, AutoMana, Threshold
    IniWrite, %manaCooldown%, %ConfigFile%, AutoMana, Cooldown
    IniWrite, 1, %ConfigFile%, PickupImage, Enabled
    IniWrite, %getIdKey%, %ConfigFile%, PickupImage, GetIdKey
    IniWrite, %deleteIdKey%, %ConfigFile%, PickupImage, DeleteIdKey
    IniWrite, %pickupRadius%, %ConfigFile%, PickupImage, Radius
    pickupFailTeleRadiusV1253 := PickupFailTeleRadiusGetV1253()
    IniWrite, %pickupFailTeleRadiusV1253%, %ConfigFile%, PickupImage, PickupFailTeleRadius
	    IniWrite, % petLearnEnabledV12 ? 1 : 0, %ConfigFile%, PickupImage, PetLearnEnabled

    Loop, 10
    {
        index := A_Index

        key := FKey%index%
        delay := FDelay%index%

        IniWrite, %key%, %ConfigFile%, Cycle, FKey%index%
        IniWrite, %delay%, %ConfigFile%, Cycle, FDelay%index%
    }
}

LoadConfig()
{
    global selectedTabV6, ConfigFile, continuousMapV168, autoLoadMapV340
    global zSetKey, zSetDelay, xDelay
    IniRead, selectedTabV6, %ConfigFile%, General, SelectedTab, 1
    if (selectedTabV6<1 || selectedTabV6>4)
        selectedTabV6 := 1
    LoadClickCastConfig("ClickCast")
    global ConfigFile

    global zKey
    global xKey

    global doubleKey
    global doubleTapMs

    global formDoubleKey
    global formDoubleTapMs
    global qCastDoubleKey
    global qCastDoubleTapMs

    global zFKey
    global zFKey2
    global zDelay1
    global zDelay2
    global zDelay3

    global FKey1, FKey2, FKey3, FKey4
    global FKey5, FKey6, FKey7, FKey8
    global FKey9, FKey10

    global FDelay1, FDelay2, FDelay3, FDelay4
    global FDelay5, FDelay6, FDelay7, FDelay8
    global FDelay9, FDelay10
    global autoPotOn, invHealOn, invManaOn, cubeHealOn, cubeManaOn, potMode, potCaptureKey1, potHPThreshold, potHPThreshold2V299, potCooldown
    global manaOn, manaMode, manaThreshold, manaCooldown
    global sigKeyV147,sigSuKeyV181,farmNaoKeyV181,pickupBackgroundV181
    
	    global petLearnEnabledV12
	global pickupToggleKeyV79, pickupImageOn, getIdKey, deleteIdKey, pickupRadius, pickupLastClick, pickupFailTeleRadiusV1253
	global farmResetWatchEnabledV217, farmResetWatchMinutesV217

    IniRead, temp, %ConfigFile%, Keys, Z,

    if (temp != "ERROR" && StrLen(temp) = 1)
        zKey := temp

    IniRead, temp, %ConfigFile%, Keys, X, x

    if (temp != "ERROR" && StrLen(temp) = 1)
        xKey := temp

    IniRead, temp, %ConfigFile%, Double, Key, Left

    if (temp != "ERROR")
    {
        if (temp = "None"
         || temp = "Left"
         || temp = "Right"
         || temp = "Up"
         || temp = "Down"
         || temp = "Home"
         || temp = "End"
         || temp = "PgUp"
         || temp = "PgDn")
        {
            doubleKey := temp
        }
        else
        {
            doubleKey := "Left"
        }
    }

    IniRead, temp, %ConfigFile%, Double, Interval, 1000

    if (temp != "ERROR")
        doubleTapMs := temp

    IniRead, temp, %ConfigFile%, FormDouble, Key, Right

    if (temp != "ERROR")
    {
        if (temp = "None"
         || temp = "Left"
         || temp = "Right"
         || temp = "Up"
         || temp = "Down"
         || temp = "Home"
         || temp = "End"
         || temp = "PgUp"
         || temp = "PgDn")
        {
            formDoubleKey := temp
        }
        else
        {
            formDoubleKey := "Right"
        }
    }

    IniRead, temp, %ConfigFile%, FormDouble, Interval, 1000

    if (temp != "ERROR")
        formDoubleTapMs := temp

    IniRead, temp, %ConfigFile%, QCastDouble, Key, Up

    if (temp = "None"
         || temp = "Left"
     || temp = "Right"
     || temp = "Up"
     || temp = "Down"
     || temp = "Home"
     || temp = "End"
     || temp = "PgUp"
     || temp = "PgDn")
        qCastDoubleKey := "None"
    else
        qCastDoubleKey := "None"

    IniRead, temp, %ConfigFile%, QCastDouble, Interval, 1000
    if (temp != "ERROR")
        qCastDoubleTapMs := temp

    IniRead, temp, %ConfigFile%, Z, FKey,

    if (temp != "ERROR")
        zFKey := temp

    IniRead, temp, %ConfigFile%, Z, FKey2,

    if (temp != "ERROR")
        zFKey2 := temp

    IniRead, temp, %ConfigFile%, Z, Delay1, 150

    if (temp != "ERROR")
        zDelay1 := temp

    IniRead, temp, %ConfigFile%, Z, Delay2, 150

    if (temp != "ERROR")
        zDelay2 := temp

    IniRead, temp, %ConfigFile%, Z, Delay3, 500

    if (temp != "ERROR")
        zDelay3 := temp

    IniRead, autoPotOn, %ConfigFile%, AutoPot, Enabled, 0
    IniRead, invHealOn, %ConfigFile%, AutoPot, InventoryHealEnabled, 0
    IniRead, invManaOn, %ConfigFile%, AutoPot, InventoryManaEnabled, %invHealOn%
    IniRead, cubeHealOn, %ConfigFile%, AutoPot, CubeHealEnabled, 0
    IniRead, cubeManaOn, %ConfigFile%, AutoPot, CubeManaEnabled, %cubeHealOn%
    IniRead, potMode, %ConfigFile%, AutoPot, Mode, Auto(1-4)
    IniRead, potCaptureKey1, %ConfigFile%, AutoPot, CaptureKey1, n
    IniRead, potHPThreshold, %ConfigFile%, AutoPot, PotHPThreshold, 7000
    hp2DefaultV299 := Max(1,Floor(potHPThreshold/2))
    IniRead, potHPThreshold2V299, %ConfigFile%, AutoPot, PotHPThreshold2, %hp2DefaultV299%
    IniRead, potCooldown, %ConfigFile%, AutoPot, Cooldown, 3000
    if (!RegExMatch(potCooldown,"^\d+$") || potCooldown<1)
        potCooldown := 3000
    IniRead, manaOn, %ConfigFile%, AutoMana, Enabled, 0
    IniRead, manaMode, %ConfigFile%, AutoMana, Mode, Auto(1-4)
    IniRead, manaThreshold, %ConfigFile%, AutoMana, Threshold, 1000
    IniRead, manaCooldown, %ConfigFile%, AutoMana, Cooldown, 3000
    pickupImageOn := true
    getIdKey := ""
    deleteIdKey := ""
    IniRead, pickupRadius, %ConfigFile%, PickupImage, Radius, 4
    IniRead, pickupFailTeleRadiusV1253, %ConfigFile%, PickupImage, PickupFailTeleRadius, 4
    if (!RegExMatch(pickupFailTeleRadiusV1253,"^\d+$") || pickupFailTeleRadiusV1253<1 || pickupFailTeleRadiusV1253>100)
        pickupFailTeleRadiusV1253 := 4
    pickupFailTeleRadiusV1253 += 0
	    IniRead, petLearnEnabledV12, %ConfigFile%, PickupImage, PetLearnEnabled, 0
    petLearnEnabledV12 := petLearnEnabledV12=1
    pickupRadius += 0
    if (pickupRadius < 1)
        pickupRadius := 4
    pickupLastClick := 0

    Loop, 10
    {
        index := A_Index

        defaultKey := FKey%index%
        defaultDelay := FDelay%index%

        IniRead, tempKey, %ConfigFile%, Cycle, FKey%index%, %defaultKey%
        IniRead, tempDelay, %ConfigFile%, Cycle, FDelay%index%, %defaultDelay%

        FKey%index% := NormalizeOptionalKey(tempKey)
        FDelay%index% := tempDelay
    }

    global profileList, currentProfile
    IniRead, tempProfiles, %ConfigFile%, Profiles, Names, Default
    if (tempProfiles = "ERROR" || tempProfiles = "")
        tempProfiles := "Default"
    if (!InStr("|" . tempProfiles . "|", "|Default|"))
        tempProfiles := "Default|" . tempProfiles
    profileList := tempProfiles
    ProfileMigrateV364()
    ProfileDiscoverFilesV366()

    IniRead, tempCurrent, %ConfigFile%, Profiles, Current, __MISSING_V366__
    if (tempCurrent="__MISSING_V366__" || tempCurrent="ERROR" || tempCurrent="" || !ProfileExists(tempCurrent))
        IniRead, tempCurrent, %ConfigFile%, Settings, LastProfile, Default
    if (!ProfileExists(tempCurrent))
        tempCurrent := "Default"
    currentProfile := tempCurrent

    if (!FileExist(ProfileFile("Default")))
        SaveProfile("Default")

    LoadProfile(currentProfile)
    global profileReadyV364
    profileReadyV364 := true

    GuiControl,, ZRunKey, % MouseKeyDisplayV616((zKey    = "" ? "None" : zKey))
    GuiControl,, ZSetKey, % MouseKeyDisplayV616((zSetKey = "" ? "None" : zSetKey))
    GuiControl,, ZSetDelay, %zSetDelay%
    GuiControl,, ZKeyF1, % MouseKeyDisplayV616((zFKey   = "" ? "None" : zFKey))
    GuiControl,, ZKeyF2, % MouseKeyDisplayV616((zFKey2  = "" ? "None" : zFKey2))
    GuiControl,, ZDelay1,   %zDelay1%
    GuiControl,, ZDelay2,   %zDelay2%

    GuiControl,, ProfileSelect, |%profileList%
    GuiControl, ChooseString, ProfileSelect, %currentProfile%
    GuiControl,, NewProfileName, %currentProfile%

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
    GuiControl,, ZRunKey, % MouseKeyDisplayV616((zKey = "" ? "None" : zKey))
    GuiControl,, ZSetKey, % MouseKeyDisplayV616(zSetKey)
    GuiControl,, ZSetDelay, %zSetDelay%
    GuiControl,, ZKeyF1, % MouseKeyDisplayV616(zFKey)
    GuiControl,, ZKeyF2, % MouseKeyDisplayV616((zFKey2 = "" ? "None" : zFKey2))
    GuiControl,, ZDelay1, %zDelay1%
    GuiControl,, ZDelay2, %zDelay2%
    GuiControl, ChooseString, DoubleKey, %doubleKey%
    GuiControl,, DoubleTapMs, %doubleTapMs%
    GuiControl, ChooseString, FormDoubleKey, %formDoubleKey%
    GuiControl,, FormDoubleTapMs, %formDoubleTapMs%
    GuiControl, Choose, AutoGSFMainTabs, %selectedTabV6%
}


OpenGuide:
Gosub, PickupGuideShowV8
return


SaveFormPosition:
Gui, +LastFound
formHwnd := WinExist()
if (formHwnd)
{
    WinGet, formMinMax, MinMax, ahk_id %formHwnd%
    if (formMinMax != -1)
    {
        WinGetPos, tempFormX, tempFormY,,, ahk_id %formHwnd%
        if (tempFormX != "" && tempFormY != "" && tempFormX > -2000 && tempFormY > -2000)
        {
            formX := tempFormX
            formY := tempFormY
            IniWrite, %formX%, %ConfigFile%, Window, X
            IniWrite, %formY%, %ConfigFile%, Window, Y
        }
    }
}
return
GuiClose:
Gosub, SaveFormPosition
ExitApp
return

GuiEscape:
return

WM_SYSCOMMAND_SavePos(wParam, lParam, msg, hwnd)
{
    global formX, formY, ConfigFile
    if ((wParam & 0xFFF0) = 0xF020)
    {
        Gui, +LastFound
        guiHwnd := WinExist()
        if (hwnd = guiHwnd)
        {
            WinGetPos, formX, formY,,, ahk_id %hwnd%
            if (formX != "" && formY != "")
            {
                IniWrite, %formX%, %ConfigFile%, Window, X
                IniWrite, %formY%, %ConfigFile%, Window, Y
            }
        }
    }
}

SavePositionOnExit:
if (profileReadyV364)
{
    SaveProfile(currentProfile)
    IniWrite, %currentProfile%, %ConfigFile%, Profiles, Current
    IniWrite, %currentProfile%, %ConfigFile%, Settings, LastProfile
}
FonInfoCloseV385()
PickupOptCloseV12()
if (manualLogOnV81)
    Gosub, ManualLogStopV81
	if (IsObject(routeRecordV358))
    RouteRecordStopV358("EXIT")
if (IsObject(routePlanV375))
    RoutePlanSaveV375()
ConsumableNameCleanupV7()
MovementCtrlSetV78(false,0,"SavePositionOnExit")
AutoMonsterPacketCleanupV1(true)
PacketWatchStopV1()
IfWinExist, Auto-GSF
{
    WinGet, exitMinMax, MinMax, Auto-GSF
    if (exitMinMax != -1)
    {
        WinGetPos, exitFormX, exitFormY,,, Auto-GSF
        if (exitFormX != "" && exitFormY != "" && exitFormX > -2000 && exitFormY > -2000)
        {
            IniWrite, %exitFormX%, %ConfigFile%, Window, X
            IniWrite, %exitFormY%, %ConfigFile%, Window, Y
        }
    }
}
ExitApp
return


V92HPProbeTimer_DISABLED:
V92WriteHPProbe()
return

V92WriteHPProbe()
{
    if (!ManualLogActiveV81())
        return
    global V92Sample
    if (V92Sample = "")
        V92Sample := 0
    V92Sample++

    log := TxtRootPathV816("HPProbe-v92.txt")
    tmp := A_Temp . "\d2_hp_v92.txt"
    FileDelete, %tmp%
    cmd := "tasklist /FI " . Chr(34) . "IMAGENAME eq Game.exe" . Chr(34) . " /FO CSV /NH > " . Chr(34) . tmp . Chr(34) . " 2>&1"
    RunWait, %ComSpec% /c %cmd%,, Hide
    FileRead, raw, %tmp%
    FileDelete, %tmp%

    pidBest := 0, player := 0, baseBest := 0
    Loop, Parse, raw, `n, `r
    {
        line := A_LoopField
        if RegExMatch(line, "i)^""Game\.exe"",""([0-9]+)""", m)
        {
            pid := m1 + 0
            base := D2GetModuleBaseV35(pid, "D2Client.dll")
            if (!base)
                continue
            h0 := D2OpenProcess(pid)
            if (!h0)
                continue
            pp := D2ReadU32(h0, base + 0x11BBFC)
            DllCall("CloseHandle", "Ptr", h0)
            if (pp)
            {
                pidBest := pid, player := pp, baseBest := base
                break
            }
        }
    }
    if (!pidBest || !player)
        return

    h := D2OpenProcess(pidBest)
    if (!h)
        return

    pStats := D2ReadU32(h, player + 0x5C)
    pInv := D2ReadU32(h, player + 0x60)
    FormatTime, ts,, yyyyMMdd-HHmmss

    out := "=== V92 SAMPLE " . V92Sample . " " . ts . " tick=" . A_TickCount . " ===`r`n"
    out .= "PID=" . pidBest . " Player=" . V92Hex(player) . " Stats=" . V92Hex(pStats) . " Inventory=" . V92Hex(pInv) . "`r`n"

    if (pStats)
    {
        out .= "STAT_A0_E0"
        Loop, 17
        {
            off := 0xA0 + (A_Index-1)*4
            v := D2ReadU32(h, pStats + off)
            out .= " +" . V92HexOff(off) . "=" . v
        }
        out .= "`r`n"

        Loop, 2
        {
            rootOff := (A_Index=1) ? 0x24 : 0x48
            root := D2ReadU32(h, pStats + rootOff)
            out .= "ROOT stats+" . V92HexOff(rootOff) . "=" . V92Hex(root)
            if (root > 0x10000)
            {
                Loop, 20
                {
                    qoff := (A_Index-1)*4
                    qv := D2ReadU32(h, root + qoff)
                    out .= " +" . V92HexOff(qoff) . "=" . qv
                }
            }
            out .= "`r`n"
        }

        a4 := D2ReadU32(h, pStats + 0xA4)
        out .= "A4_VALUE=" . V92Hex(a4) . "`r`n"
        if (a4 > 0x10000)
        {
            out .= "A4_PTR_BLOCK"
            Loop, 32
            {
                qoff := (A_Index-1)*4
                qv := D2ReadU32(h, a4 + qoff)
                out .= " +" . V92HexOff(qoff) . "=" . qv
            }
            out .= "`r`n"
        }
    }

    if (pInv)
    {
        cnt := D2ReadU32(h, pInv + 0x28)
        u := D2ReadU32(h, pInv + 0x10)
        typ := u ? D2ReadU32(h, u+0x00) : 0
        cls := u ? D2ReadU32(h, u+0x04) : 0
        uid := u ? D2ReadU32(h, u+0x0C) : 0
        out .= "INV countField=" . cnt . " firstUnit=" . V92Hex(u) . " type=" . typ . " class=" . cls . " id=" . uid . "`r`n"
    }

    out .= "`r`n"
    DllCall("CloseHandle", "Ptr", h)
    ManualLogAppendV81(out, log)
}

V92Hex(v)
{
    return Format("0x{:08X}", v & 0xFFFFFFFF)
}

V92HexOff(v)
{
    return Format("{:02X}", v)
}

Belt4HPHandler:
if (!IsGameForegroundV63())
    return
if (sigBusyV147)
    return
if (packetWatchArmedV1)
    return
TransferHotkeyTrace("16HP_TO_BELT")
if (xRunning)
{
    DebugTraceWrite("belt", "TRANSFER_BLOCKED reason=BUFF_RUNNING")
    return
}
if (!IsGameActive())
{
    HealTrace("TIMER_SKIP reason=GAME_NOT_ACTIVE", "timer")
    return
}
pid := D2GetActiveGamePidV95()
if (pid && FarmReviveTownLevelV295(RoomRecordLevelV259(pid)))
    return
if (!GameItemActionBeginV4("Heal", "heal", true))
    return
if (!GameItemActionBeginV4("Belt", "belt", true))
    return
try
{
beltOneShotLogActive := beltOneShotLogArmed
if (beltOneShotLogActive)
    BeltSendLogV101("=== ONE-SHOT 4HP START " . A_Now . " ===")
beltTraceSendOK := V50ConfigureBelt([1229,1229,1229,1229])
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
