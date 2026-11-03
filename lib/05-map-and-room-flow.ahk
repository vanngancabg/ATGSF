CoordGoTeleportV284(h,ByRef pb,goal)
{
    if (CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))=163)
        return false
    global coordGoV59,teleportKeyV55,backgroundAimV64,zRunning,xRunning,gameItemActionOwner,packetWatchArmedV1,petLearnOnV12
    global scosEntryV162,farmControlOwnerV186
    autoCallV504 := goal.autoCallV504 && farmControlOwnerV186="BO" && IsObject(scosEntryV162)
        && scosEntryV162.map="BO" && scosEntryV162.pid=goal.pid && scosEntryV162.boStageV413=2 && scosEntryV162.phase="FARM"
    if (coordGoV59!=goal || !goal.requiredArrival || teleportKeyV55="" || zRunning || xRunning
        || gameItemActionOwner!="" || packetWatchArmedV1 || petLearnOnV12 || !NativeDispatchReadyV10(autoCallV504) || !AutoMonsterPacketCleanupV1())
        return false
    pid := goal.pid,point := goal,direction := 1
    if (D2GetActiveGamePidV95()!=pid)
        return false
    hwnd := GameTargetHwndV63(), base := D2GetModuleBaseV35(pid,"D2Client.dll")
    path := NumGet(pb,0x1C,"UInt")
    view := AutoMonsterAttackViewV1(h,base,hwnd,D2ReadU32(h,D2ReadU32(h,base+0x11BBFC)+0x2C))
    if (!IsObject(view) || CoordLevelV14(h,path)!=point.level)
        return CoordTeleBlockedV96("VIEW_OR_MAP_INVALID")
    px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
    dx := (point.x-px)*direction, dy := (point.y-py)*direction
    sx := (dx-dy)*16, sy := (dx+dy)*8
    length := Sqrt(sx*sx+sy*sy)
    if (length<1)
        return CoordTeleBlockedV96("ALREADY_AT_DESTINATION")
    playerSX := NumGet(pb,8,"Int")-view.ox
    playerSY := NumGet(pb,12,"Int")-view.oy
    reach := MonsterRadiusGetV239() / Sqrt(dx*dx+dy*dy)
    aimX := Max(16,Min(view.gw-16,playerSX+sx*reach))
    aimY := Max(32,Min(view.gh-64,playerSY+sy*reach))
    clientX := Round(aimX*view.cw/view.gw), clientY := Round(aimY*view.ch/view.gh)
    if (!NativeDispatchReadyV10(autoCallV504) || GameTargetHwndV63()!=hwnd || D2GetActiveGamePidV95()!=pid)
        return CoordTeleBlockedV96("GAME_CONTEXT_BEFORE_AIM")
    if (!GameTargetAimV63(clientX,clientY))
        return CoordTeleBlockedV96("AIM_SEND_FAILED")
    Sleep, 30
    if (!NativeDispatchReadyV10(autoCallV504) || GameTargetHwndV63()!=hwnd || D2GetActiveGamePidV95()!=pid)
    {
        backgroundAimV64 := false
        return CoordTeleBlockedV96("GAME_CONTEXT_AFTER_AIM")
    }
    if (coordGoV59!=goal)
    {
        backgroundAimV64 := false
        return false
    }
    sentV284 := BuffCheckedSendV29(teleportKeyV55)
    backgroundAimV64 := false
    if (sentV284)
        AutoMonsterAttackLogV2("MANUAL_GO_DELAY_TELEPORT row=" . goal.row . " destination=" . goal.x . "," . goal.y . " effect=UNCONFIRMED")
    return sentV284
}

CoordMoveUpV144:
CoordMoveRowV144(-1)
return

CoordMoveDownV144:
CoordMoveRowV144(1)
return

CoordMoveRowV144(direction)
{
    routePointsV724 := FarmRoutePointsV724()
    global CoordListHwndV15,roomRecordV108,autoMonsterAttackOn,coordGoV59,currentProfile,ConfigFile
    global coordNearbyRowV18,coordManualRowV59,coordLiveYellowV128,coordPinnedYellowV136,autoMapTrackingV10
    global coordEditPointV127,coordInsertAnchorV57,coordPointTextV14,coordPointLevelV14
    static busy := false
    if (busy)
        return false
    if (IsObject(roomRecordV108))
    {
        ToolTipInfoV386("Dừng lưu phòng trước khi chuyển dòng lên/xuống.")
        SetTimer, RemoveToolTip, -2500
        return false
    }
    row := DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x188,"Ptr",0,"Ptr",0,"Int")
    next := row+direction
    if (row<1 || row>routePointsV724.Length() || next<1 || next>routePointsV724.Length())
        return false
    busy := true
    try
    {
        if (autoMonsterAttackOn || IsObject(coordGoV59))
            FarmStopV124("REORDER_COORDINATE_ROW")
        points := routePointsV724.Clone()
        moved := points[row],points[row] := points[next],points[next] := moved
        if (moved.HasKey("roomNumber") && !RoomMapPointsWriteV126(RoomProfileFileV108(),moved.level,points))
        {
            ToolTipInfoV386("Không lưu được thứ tự mới. Giữ nguyên danh sách cũ.")
            SetTimer, RemoveToolTip, -3000
            return false
        }
        routePointsV724 := points
        coordNearbyRowV18 := next,coordManualRowV59 := next,coordLiveYellowV128 := next,coordPinnedYellowV136 := next
        coordEditPointV127 := false,coordInsertAnchorV57 := false
        coordPointTextV14 := moved.x . "," . moved.y,coordPointLevelV14 := moved.level
        CoordRouteResetV16()
        CoordSavedStoreV15(currentProfile)
        CoordBoxRefreshV15(true)
        DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x186,"Ptr",next,"Ptr",0)
        return true
    }
    finally
        busy := false
}

CoordDeleteRowV15:
if (IsObject(roomRecordV108))
{
    ToolTipInfoV386("Dừng lưu lộ trình trước khi xóa tọa độ.")
    SetTimer, RemoveToolTip, -2500
    return
}
FonEditBeginV414()
try
{
coordGoV59 := false, coordManualRowV59 := 0
SetTimer, CoordGoTimerV59, Off
lineV15 := DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x188,"Ptr",0,"Ptr",0,"Int")
if (lineV15<1 || lineV15>coordSavedV15.Length())
{
    ToolTipInfoV386("Chọn dòng từ 2 trở đi để xóa. Dòng 1 là tọa độ nhân vật.")
    SetTimer, RemoveToolTip, -2500
    return
}
if (autoMonsterAttackOn)
    FarmStopV124("DELETE_ROUTE_ROW")
deletedPointV126 := coordSavedV15[lineV15]
roomDeleteFileV126 := RoomProfileFileV108()
coordSavedV15.RemoveAt(lineV15)
coordLiveYellowV128 := 0
if (deletedPointV126.HasKey("roomNumber") && !RoomMapPointsWriteV126(roomDeleteFileV126,deletedPointV126.level,coordSavedV15))
{
    coordSavedV15.InsertAt(lineV15,deletedPointV126)
    ToolTipInfoV386("Không lưu được dòng xóa vào file map. Giữ nguyên lộ trình.")
    SetTimer, RemoveToolTip, -3000
    return
}
CoordRouteResetV16()
coordNearbyRowV18 := coordSavedV15.Length() ? Min(lineV15,coordSavedV15.Length()) : 0
coordManualRowV59 := coordNearbyRowV18
coordPinnedYellowV136 := coordNearbyRowV18,coordLiveYellowV128 := coordNearbyRowV18
coordInsertAnchorV57 := coordNearbyRowV18 ? coordSavedV15[coordNearbyRowV18] : false
coordEditPointV127 := coordInsertAnchorV57
if (coordSavedV15.Length())
{
    pointV15 := coordSavedV15[coordNearbyRowV18]
    coordPointTextV14 := pointV15.x . "," . pointV15.y, coordPointLevelV14 := pointV15.level
}
else
    coordPointTextV14 := "", coordPointLevelV14 := 0
coordMoveDoneV14 := false, coordMoveTriesV14 := 0, coordNoTargetSinceV14 := 0
CoordSavedStoreV15(currentProfile)
CoordBoxRefreshV15(true)
if (coordNearbyRowV18)
    DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x186,"Ptr",coordNearbyRowV18,"Ptr",0)
return

}
finally
    FonEditEndV414()

CoordDeleteAllV58:
if (IsObject(roomRecordV108))
{
    ToolTipInfoV386("Dừng lưu lộ trình trước khi xóa tọa độ.")
    SetTimer, RemoveToolTip, -2500
    return
}
FonEditBeginV414()
try
{
coordGoV59 := false, coordManualRowV59 := 0
SetTimer, CoordGoTimerV59, Off
if (autoMonsterAttackOn)
    FarmStopV124("DELETE_ALL_ROUTE_ROWS")
if (coordSavedV15.Length() && coordSavedV15[1].HasKey("roomNumber")
    && !RoomMapPointsWriteV126(RoomProfileFileV108(),coordSavedV15[1].level,[]))
{
    ToolTipInfoV386("Không lưu được thao tác xóa vào file map. Giữ nguyên lộ trình.")
    SetTimer, RemoveToolTip, -3000
    return
}
coordSavedV15 := [],coordNearbyRowV18 := 0,coordLiveYellowV128 := 0
coordInsertAnchorV57 := false
CoordRouteResetV16()
coordPointTextV14 := "", coordPointLevelV14 := 0
coordMoveDoneV14 := false, coordMoveTriesV14 := 0, coordNoTargetSinceV14 := 0
CoordSavedStoreV15(currentProfile)
CoordBoxRefreshV15(true)
return

}
finally
    FonEditEndV414()

RoomMapPointsWriteV126(file,level,points)
{
    if (!FileExist(file) || !IsObject(points) || points.Length()>10000)
        return false
    temp := file . ".edit.tmp",section := "Route-" . level,sequence := ""
    FileCopy, %file%, %temp%, 1
    if (ErrorLevel)
        return false
    IniDelete, %temp%, %section%
    IniWrite, ROOM_CENTERS_V1, %temp%, %section%, Format
    if (ErrorLevel)
        return false
    if (!points.Length())
    {
        for _,prefix in ["Rooms-","Geometry-","Gates-"]
        {
            emptySectionV413 := prefix . level
            IniDelete, %temp%, %emptySectionV413%
        }
    }
    for i,point in points
    {
        if (!point.HasKey("roomNumber") || point.level!=level)
            return false
        key := "Room" . i,value := point.roomNumber . "|" . point.x . "," . point.y
        IniWrite, %value%, %temp%, %section%, %key%
        if (ErrorLevel)
            return false
        sequence .= (sequence="" ? "" : "-") . point.roomNumber
    }
    count := points.Length()
    IniWrite, %sequence%, %temp%, %section%, Sequence
    if (ErrorLevel)
        return false
    IniWrite, %count%, %temp%, %section%, Count
    if (ErrorLevel)
        return false
    if (count)
    {
        check := RoomMapReadV109(temp)
        if (!IsObject(check) || check.level!=level || check.points.Length()!=count)
            return false
        for i,point in points
            if (check.points[i].roomNumber!=point.roomNumber || check.points[i].x!=point.x || check.points[i].y!=point.y)
                return false
    }
    FileMove, %temp%, %file%, 1
    return !ErrorLevel
}

FarmCurrentLevelV143()
{
    pid := CoordDisplayGamePidV1(),base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? DllCall("OpenProcess","UInt",0x0410,"Int",0,"UInt",pid,"Ptr") : 0
    if (!h)
        return 0
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return 0
        return CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}
MapRouteHintV400(file)
{
    if (!FileExist(file))
        return 0
    IniRead, level, %file%, Map, RecordedLevel, 0
    if (RegExMatch(level,"^\d+$") && level+0)
        return level+0
    IniRead, level, %file%, Map, AutoLevel, 0
    if (RegExMatch(level,"^\d+$") && level+0)
        return level+0
    SplitPath, file,,,, stemV402
    if (RegExMatch(stemV402,"i)(?:^|-)Map(\d+)(?:-|$)",nameLevelV402))
        return nameLevelV4021+0
    IniRead, sections, %file%
    found := 0
    Loop, Parse, sections, `n, `r
        if (RegExMatch(A_LoopField,"^Route-(\d+)$",m))
        {
            if (found && found!=m1+0)
                return 0
            found := m1+0
        }
    return found
}

MapEmptyRouteSelectV400(level)
{
    global routeMapsV21,routeMapIdV21,currentProfile,coordMapReadyV381,coordMapAcceptedV381
    global roomRecordV108,roomRecordFinishingV21,roomMapSelectionResetV111,routePreviewV401
    if (!level || IsObject(roomRecordV108) || roomRecordFinishingV21)
        return false
    matches := []
    for _,map in routeMapsV21
    {
        file := RoomProfileFileV108(currentProfile,map.id)
        if (!MapRouteFileInScopeV408(file,level) || MapRouteHintV400(file)!=level)
            continue
        section := "Route-" . level
        IniRead, count, %file%, %section%, Count, 0
        if (RegExMatch(count,"^\d+$") && count+0=0)
            matches.Push(map)
    }
    selected := false
    for _,map in matches
        if (map.id=routeMapIdV21)
            selected := map
    if (!IsObject(selected) && matches.Length())
        selected := matches[1]
    if (!IsObject(selected))
        return false
    routeMapIdV21 := selected.id,roomMapSelectionResetV111 := false,routePreviewV401 := true
    RouteMapsStoreV21(currentProfile)
    RouteMapRefreshV21(false)
    coordMapReadyV381 := false,coordMapAcceptedV381 := false
    PortalLogWriteV66("MAP_EMPTY_SELECTED live_level=" . level . " route_id=" . selected.id . " purpose=RECORD_ONLY farm=OFF")
    FonLoadErrorShowV385("Map " . level . ": đã chọn file rỗng để ghi lộ trình. Farm đang OFF.")
    return true
}

RoomRecordSelectLiveV400()
{
    global coordCurrentLevelV400,currentProfile,routeMapIdV21,roomRecordV108,routePreviewV401
    if (IsObject(roomRecordV108))
        return false
    pid := CoordDisplayGamePidV1(),level := pid ? RoomRecordLevelV259(pid) : 0
    if (!level)
    {
        ToolTipInfoV386("Chưa đọc được map hiện tại để ghi lộ trình.")
        SetTimer, RemoveToolTip, -2500
        return false
    }
    coordCurrentLevelV400 := level
    selectedFileV401 := RoomProfileFileV108(currentProfile,routeMapIdV21)
    explicitDataV401 := routePreviewV401 ? RoomMapReadV109(selectedFileV401,false,level) : false
    if (IsObject(explicitDataV401) && explicitDataV401.points.Length())
    {
        CoordSavedLoadV15(currentProfile)
        CoordBoxRefreshV15(true)
        return true
    }
    RoomMapsSyncV110(true)
    if (FonLoadMapV382("RECORD_SELECT_LIVE"))
        return true
    if (MapEmptyRouteSelectV400(level))
        return true
    ToolTipInfoV386("Đang ở map " . level . " nhưng chưa có file tương ứng. Bấm THÊM MAP để tạo file đúng map.")
    SetTimer, RemoveToolTip, -3500
    return false
}

RoomRecordedPublishV399(r,data)
{
    global routeMapIdV21,currentProfile,coordSavedV15,coordPointLevelV14,coordPointTextV14
    global coordYellowRowV350,coordLiveYellowV128,coordPinnedYellowV136,coordNearbyRowV18,coordManualRowV59
    global coordMapSerialV381,coordMapStateV381,coordMapReadyV381,coordMapAcceptedV381,stage2MapFileV14,routePreviewV401,mapLoadFailureV402
    global mapTestModeV656
    if (MapFileIsTestV656(r.file)!=mapTestModeV656)
        return
    mapLoadFailureV402 := false
    routePreviewV401 := true
    routeMapIdV21 := r.mapChoice
    RouteMapsStoreV21(currentProfile)
    coordSavedV15 := data.points,coordPointLevelV14 := data.level
    row := data.points.Length(),point := data.points[row]
    coordPointTextV14 := point.x . "," . point.y
    coordYellowRowV350 := row,coordLiveYellowV128 := row,coordPinnedYellowV136 := row
    coordNearbyRowV18 := row,coordManualRowV59 := row
    CoordRouteResetV16()
    coordMapSerialV381 += 1,stage2MapFileV14 := false,coordMapAcceptedV381 := false
    context := MapLiveIdentityV399(r.pid,r.level)
    coordMapReadyV381 := IsObject(context) && MapFileStampReadV398(r.file,stamp)
    coordMapStateV381 := false
    if (coordMapReadyV381)
    {
        key := r.pid . "|" . currentProfile . "|" . r.level
        recordLayoutV841 := IsObject(r.snapshotV413) && IsObject(r.snapshotV413.geometry)
            && !r.snapshotV413.geometry.partial ? r.snapshotV413.geometry.layout : ""
        coordMapStateV381 := {key:key,pid:r.pid,level:r.level,profile:currentProfile,loaded:true
            ,mapId:r.mapChoice,retryAt:0,serial:coordMapSerialV381,levelPtrV395:context.levelPtr
            ,fileV10:r.file,fileStampV10:stamp
            ,layoutV841:recordLayoutV841,layoutCheckedAtV841:A_TickCount}
    }
    FonLoadErrorHideV385()
}

MapLiveIdentityV399(pid,expectedLevel)
{
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb))
            return false
        room1 := NumGet(pb,0x1C,"UInt"),room2 := room1 ? D2ReadU32(h,room1+0x10) : 0
        lp := room2 ? D2ReadU32(h,room2+0x58) : 0
        if (!lp || CoordLevelV14(h,room1)!=expectedLevel)
            return false
        return {levelPtr:lp,x:NumGet(pb,2,"UShort"),y:NumGet(pb,6,"UShort")}
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

MapFileStampReadV398(file,ByRef stamp)
{
    stamp := ""
    if (file="" || !FileExist(file) || InStr(FileExist(file),"D"))
        return false
    try
    {
        FileGetTime, modified, %file%, M
        if (ErrorLevel || modified="")
            return false
        FileGetSize, bytes, %file%
        if (ErrorLevel || bytes="")
            return false
        stamp := modified . "|" . bytes
        return true
    }
    catch stampErrorV398
    {
        PortalLogWriteV66("MAP_FILE_STAMP_FAILED file=" . file . " reason=READ_ERROR")
        return false
    }
}

MapLoadFailedStopV397(reason)
{
    global coordMapReadyV381,coordMapAcceptedV381,mapLoadFailureV402
    global coordCurrentLevelV400,backgroundPidV63,scosEntryV162
    failPidV402 := CoordDisplayGamePidV1()
    if (!failPidV402)
        failPidV402 := backgroundPidV63
    failLevelV402 := failPidV402 ? RoomRecordLevelV259(failPidV402) : coordCurrentLevelV400
    failIdentityV402 := failPidV402 && failLevelV402 ? MapLiveIdentityV399(failPidV402,failLevelV402) : false
    mapLoadFailureV402 := {pid:failPidV402,level:failLevelV402
        ,levelPtr:IsObject(failIdentityV402) ? failIdentityV402.levelPtr : 0,reason:reason}
    coordMapReadyV381 := false,coordMapAcceptedV381 := false
    PortalLogWriteV66("MAP_LOAD_FAILED reason=" . reason . " ready=FALSE actions=UNCHANGED", "MAP_LOAD_FAILED", 1000)
    if (IsObject(scosEntryV162) && scosEntryV162.map="BO")
        BOErrorReportV463(scosEntryV162,reason,"MAP_READ_OR_LOAD")
    return false
}

MapGatesReadV397(pid,level)
{
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        if (!MonsterBossProbeReadV1(h,path,0x20,pb)
            || CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))!=level)
            return false
        gates := [],seen := {},keys := {},started := A_TickCount
        for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
        {
            node := RoomExploreReadV89(h,D2ReadU32(h,room+0x10),level,true)
            if (!IsObject(node))
                continue
            u := D2ReadU32(h,room+0x74)
            Loop, 4096
            {
                if (!u || seen.HasKey(u))
                    break
                if (seen.Count()>=4096 || A_TickCount-started>250)
                    return false
                seen[u] := true
                if (!MonsterBossProbeReadV1(h,u,0xEC,ub))
                    return false
                typ := NumGet(ub,0,"UInt"),cls := NumGet(ub,4,"UInt")
                if (typ=5 || (typ=2 && (cls=60 || cls=156 || cls=266 || cls=194 || cls=288)))
                {
                    op := NumGet(ub,0x2C,"UInt")
                    if (!MonsterBossProbeReadV1(h,op,0x18,ob))
                        return false
                    x := NumGet(ob,0x0C,"UInt"),y := NumGet(ob,0x10,"UInt")
                    if (x>=node.x && x<node.x+node.w && y>=node.y && y<node.y+node.h)
                    {
                        rect := node.x . "_" . node.y . "_" . node.w . "_" . node.h
                        key := typ . "," . cls . "|" . x . "," . y . "|" . rect
                        if (!keys.HasKey(key))
                            gates.Push({typ:typ,cls:cls,x:x,y:y,rect:rect,key:key}),keys[key] := true
                    }
                }
                u := NumGet(ub,0xE8,"UInt")
            }
        }
        endPath := D2ReadU32(h,player+0x2C)
        if (!MonsterBossProbeReadV1(h,endPath,0x20,endPB)
            || CoordLevelV14(h,NumGet(endPB,0x1C,"UInt"))!=level)
            return false
        return gates
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

MapGatesFileReadV397(file,level)
{
    section := "Gates-" . level
    IniRead, format, %file%, %section%, Format, MISSING
    if (format="MISSING")
        return []
    IniRead, count, %file%, %section%, Count, INVALID
    if (format!="EXIT_XY_ROOM_V1" || !RegExMatch(count,"^\d+$") || count>4096)
        return false
    gates := []
    Loop, %count%
    {
        key := "Gate" . A_Index
        IniRead, value, %file%, %section%, %key%, INVALID
        if (!RegExMatch(value,"^([25]),(\d+)\|(\d+),(\d+)\|(\d+_\d+_\d+_\d+)$",m)
            || m3<1 || m3>65535 || m4<1 || m4>65535 || (m1=2 && m2=59))
            return false
        gates.Push({typ:m1+0,cls:m2+0,x:m3+0,y:m4+0,rect:m5,key:value})
    }
    return gates
}


MapGatesFilterV397(candidates,pid,level,ByRef liveGeometryV841)
{
    liveGeometryV841 := false
    if (!IsObject(candidates) || !candidates.Length())
        return []
    ; Thành chỉ được ưu tiên level ID khi duy nhất một lộ trình.
    if (FarmReviveTownLevelV295(level) && candidates.Length()=1)
    {
        PortalLogWriteV66("MAP_TOWN_SINGLE level=" . level . " route=" . candidates[1].id)
        return candidates
    }
    liveGeometryV841 := MapRoomLayoutReadV270(pid,level)
    if (!IsObject(liveGeometryV841) || liveGeometryV841.partial || liveGeometryV841.layout="")
    {
        PortalLogWriteV66("MAP_LAYOUT_NOT_READY level=" . level
            . " live_read=" . IsObject(liveGeometryV841)
            . " partial=" . (IsObject(liveGeometryV841) ? liveGeometryV841.partial : -1)
            . " policy=DO_NOT_GUESS_MAP", "MAP_LAYOUT_WAIT", 1500)
        return []
    }
    exact := [], legacy := [], geometry := liveGeometryV841
    for _,candidate in candidates
    {
        data := candidate.data,policy := "FULL_LAYOUT", matched := false
        if (data.roomLayout!="")
        {
            ; Layout là tập hình chữ nhật của TOÀN MAP, không phải ID và
            ; không phải số lượng phòng đang được render quanh nhân vật.
            ; File cũ đôi khi ghi RoomCount theo số node (có node trùng hình),
            ; nên dùng layout hình học đầy đủ làm định danh chính.
            if (data.roomLayout=geometry.layout)
                matched := true,exact.Push(candidate)
        }
        else
        {
            ; Tương thích file cũ: chỉ khi MỘT file trong level và >=2 phòng
            ; khác nhau chứa TẤT CẢ điểm route. Không load bừa theo map ID.
            policy := "LEGACY_POINTS_CHECK"
            check := MapRoutePointsFitRoomsV841(data.points,geometry)
            if (candidates.Length()=1 && check.ok && check.rooms>=2)
                matched := true,legacy.Push(candidate)
        }
        PortalLogWriteV66("MAP_LAYOUT_CHECK level=" . level . " route_id=" . candidate.id
            . " saved_rooms=" . data.roomCount . " live_rooms=" . geometry.count
            . " saved_partial=" . data.partial . " match=" . matched
            . " policy=" . policy . " gate_condition=REMOVED")
    }
    if (exact.Length())
        return exact
    if (legacy.Length()=1)
    {
        PortalLogWriteV66("MAP_LAYOUT_LEGACY_VERIFIED level=" . level
            . " route=" . legacy[1].id . " policy=UNIQUE_TWO_ROOMS")
        return legacy
    }
    return []
}

MapRoutePointsFitRoomsV841(points,geometry)
{
    if (!IsObject(points) || !points.Length() || !IsObject(geometry)
        || !IsObject(geometry.rects) || geometry.partial)
        return {ok:false,rooms:0}
    matchedRooms := {}
    for _,point in points
    {
        rect := RoomRecordRectV413(geometry,point.x,point.y)
        if (rect="")
            return {ok:false,rooms:matchedRooms.Count()}
        matchedRooms[rect] := true
    }
    return {ok:true,rooms:matchedRooms.Count()}
}

MapRoomLayoutReadV270(pid,expectedLevel)
{
    if (CainCaveMapV502(expectedLevel))
    {
        cave := CainCaveMapSnapshotV511(pid,expectedLevel)
        return IsObject(cave) ? cave.geometry : false
    }
    base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC),path := player ? D2ReadU32(h,player+0x2C) : 0
        room1 := path ? D2ReadU32(h,path+0x1C) : 0
        current := room1 ? D2ReadU32(h,room1+0x10) : 0
        lp := current ? D2ReadU32(h,current+0x58) : 0
        if (!lp || D2ReadU32(h,lp+0x1D0)!=expectedLevel)
            return false
        expectedRoomsV841 := D2ReadU32(h,lp+0x08)
        address := D2ReadU32(h,lp+0x10)
        seen := {},rects := {},layout := ""
        failed := 0,limitHit := false,started := A_TickCount
        while (address)
        {
            if (seen.HasKey(address) || seen.Count()>=4096)
            {
                limitHit := true
                break
            }
            if (A_TickCount-started>3500)
            {
                limitHit := true
                break
            }
            seen[address] := true
            if (D2ReadU32(h,address+0x58)!=lp)
            {
                failed++
                address := D2ReadU32(h,address+0x24)
                continue
            }
            node := RoomExploreReadV89(h,address,expectedLevel,true)
            if (!IsObject(node))
            {
                failed++
                address := D2ReadU32(h,address+0x24)
                continue
            }
            key := node.x . "_" . node.y . "_" . node.w . "_" . node.h
            rects[key] := true
            address := D2ReadU32(h,address+0x24)
        }
        if (!rects.Count() || !seen.HasKey(current))
            return false
        for key,_ in rects
            layout .= key . "`n"
        Sort, layout
        layout := StrReplace(RTrim(layout,"`n"),"`n","|")
        ; Đếm số phòng từ header để nhận ra danh sách thiếu node dù next=0.
        countBadV841 := expectedRoomsV841>0 && expectedRoomsV841<=4096
            && seen.Count()!=expectedRoomsV841
        partialV841 := failed || limitHit || countBadV841
        if (partialV841)
            PortalLogWriteV66("MAP_LAYOUT_PARTIAL level=" . expectedLevel
                . " header_rooms=" . expectedRoomsV841
                . " chain_seen=" . seen.Count() . " rects=" . rects.Count()
                . " failed_reads=" . failed . " limit_hit=" . limitHit
                . " count_mismatch=" . countBadV841, "MAP_LAYOUT_PARTIAL", 1500)
        ; Đề phòng game chuyển map ngay khi đang đọc chuỗi Room2.
        endRoom1V841 := D2ReadU32(h,path+0x1C)
        endRoom2V841 := endRoom1V841 ? D2ReadU32(h,endRoom1V841+0x10) : 0
        if (!endRoom2V841 || D2ReadU32(h,endRoom2V841+0x58)!=lp)
            return false
        return {level:expectedLevel,levelPtr:lp,count:rects.Count(),layout:layout,rects:rects
            ,partial:partialV841 ? 1 : 0}
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}
MapRoomLayoutSaveV270(file,geometry)
{
    if (!IsObject(geometry) || !FileExist(file))
        return false
    section := "Geometry-" . geometry.level
    IniWrite, FULL_LEVEL_ROOM_LIST, %file%, %section%, Source
    if (ErrorLevel)
        return false
    IniWrite, % geometry.level, %file%, %section%, MapID
    if (ErrorLevel)
        return false
    IniWrite, % geometry.count, %file%, %section%, TotalRooms
    if (ErrorLevel)
        return false
    IniWrite, % geometry.count, %file%, %section%, RoomCount
    if (ErrorLevel)
        return false
    IniWrite, % geometry.layout, %file%, %section%, Layout
    if (ErrorLevel)
        return false
    IniWrite, % (geometry.HasKey("partial") ? geometry.partial : 0), %file%, %section%, Partial
    return !ErrorLevel
}


CoordSavedLoadV15(profile)
{
    global roomExploreV89,coordEditPointV127,coordLiveYellowV128,coordPinnedYellowV136
    coordEditPointV127 := false,coordLiveYellowV128 := 0,coordPinnedYellowV136 := 0
    if (IsObject(roomExploreV89))
        RoomExploreEndV89("PROFILE_LOAD")
    global coordManualRowV59, coordGoV59
    coordManualRowV59 := 0, coordGoV59 := false
    SetTimer, CoordGoTimerV59, Off
    global ConfigFile, coordSavedV15, coordPointTextV14, coordPointLevelV14, routeMapIdV21
    coordSavedV15 := [],coordPointTextV14 := "",coordPointLevelV14 := 0
    if (!routeMapIdV21)
        return
    selectedFileV401 := RoomProfileFileV108(profile)
    roomMapDataV109 := RoomMapReadV109(selectedFileV401)
    if (IsObject(roomMapDataV109))
    {
        coordSavedV15 := roomMapDataV109.points
        coordPointLevelV14 := roomMapDataV109.level
        coordPointTextV14 := coordSavedV15[1].x . "," . coordSavedV15[1].y
    }
}

CoordSavedStoreV15(profile)
{
    global roomExploreV89
    if (IsObject(roomExploreV89))
        return
    global ConfigFile, coordSavedV15, coordPointTextV14, coordPointLevelV14, routeMapIdV21
    if (!routeMapIdV21)
        return
    RouteMapsStoreV21(profile)
    section := RouteMapSectionV21(profile), count := coordSavedV15.Length()
    IniRead, savedKeysV413, % ProfileConfigPathV364(section), %section%
    Loop, Parse, savedKeysV413, `n, `r
        if (RegExMatch(A_LoopField,"^(CoordSaved\d+)=",oldCoordKeyV413))
            IniDelete, % ProfileConfigPathV364(section), %section%, %oldCoordKeyV4131%
    IniWrite, %count%, % ProfileConfigPathV364(section), %section%, CoordSavedCount
    for i,point in coordSavedV15
    {
        key := "CoordSaved" . i, value := point.x . "," . point.y . "," . point.level
        IniWrite, %value%, % ProfileConfigPathV364(section), %section%, %key%
    }
    IniWrite, %coordPointTextV14%, % ProfileConfigPathV364(section), %section%, CoordPoint
    IniWrite, %coordPointLevelV14%, % ProfileConfigPathV364(section), %section%, CoordLevel
}

CoordRouteResetV16()
{
    global coordRouteV16, coordNoTargetSinceV14, monsterRetryUntilV44, monsterChaseV44, monsterCombatUidV45, combatRecoverV48,combatMildRecoverV299, monsterRadiusV48, combatMoveLastV48, monsterRoadAreaV51
    global monsterProgressByUidV591
    monsterProgressByUidV591 := {}

    monsterCombatUidV45 := 0, monsterRoadAreaV51 := false
    combatRecoverV48 := false, combatMildRecoverV299 := false, combatMoveLastV48 := 0
    ChaseMissResetV6()
    monsterRetryUntilV44 := {}, monsterChaseV44 := false
    coordRouteV16 := {pid:0,anchor:0,next:0,yellow:0,phase:"START",tries:0,bestDist:-1,lastDispatch:0,moveProbe:false,fallbackUsed:false,battlePending:false,bypass:false,startX:0,startY:0,startLevel:0,legRow:0,closestGoalDistance:-1,firstMoveAttempted:false,stuckProbe:false,lastTeleport:0}
    coordNoTargetSinceV14 := 0
	FarmStuckInfoDisableV10(true)
}

CoordRouteBattleV16()
{
    global coordRouteV16
    if (!IsObject(coordRouteV16) || !coordRouteV16.anchor)
        return
    r := coordRouteV16
    r.lastBattleV118 := A_TickCount, r.stuckProbe := false
    if (!r.battlePending)
    {
        r.battlePending := true
        r.tries := 0, r.bestDist := -1, r.lastDispatch := 0, r.moveProbe := false
        AutoMonsterAttackLogV2("ROUTE_BATTLE destination_row=" . (r.next+1) . " phase=" . r.phase . " resume_same_destination=1")
    }
}

CoordNearestSavedV18(x,y,level)
{
    routePointsV724 := FarmRoutePointsV724()

    best := 0, bestDist := 0x7FFFFFFF
    for i,point in routePointsV724
    {
        if (point.level!=level)
            continue
        dist := (x-point.x)*(x-point.x)+(y-point.y)*(y-point.y)
        if (dist<bestDist)
            best := i, bestDist := dist
    }
    return best
}

CoordPortalArrivalObserveV307(h,ByRef pb,pid,level)
{
    global farmLoadedMapV56,currentProfile,routeMapIdV21,coordSavedV15
    static lastPid := 0,lastLevel := 0
    fromTown := lastPid=pid && FarmReviveTownLevelV295(lastLevel)
    lastPid := pid,lastLevel := level
    if (fromTown && !FarmReviveTownLevelV295(level) && IsObject(farmLoadedMapV56)
        && farmLoadedMapV56.pid=pid && farmLoadedMapV56.profile=currentProfile
        && farmLoadedMapV56.mapId=routeMapIdV21 && farmLoadedMapV56.level=level
        && coordSavedV15.Length())
        return CoordPortalResumeV306(h,pb,pid)
    return false
}

CoordPortalResumeV306(h,ByRef pb,pid)
{
    global farmMapPauseV52,coordRouteV16
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    if (IsObject(coordRouteV16) && coordRouteV16.startAtYellowV367
        && coordRouteV16.pid=pid && coordRouteV16.startLevel=level)
    {
        coordRouteV16.portalArrivalPendingV307 := false
        return true
    }
    if (!CoordResumeNearestV303(h,pb,pid,"PORTAL_ARRIVAL"))
        return false
    if (IsObject(farmMapPauseV52) && farmMapPauseV52.pid=pid
        && farmMapPauseV52.level=coordRouteV16.startLevel)
        farmMapPauseV52.route := coordRouteV16,farmMapPauseV52.yellow := coordRouteV16.yellow
    return true
}

CoordResumeNearestV303(h,ByRef pb,pid,reason)
{
    global coordRouteV16,coordSavedV15,coordManualRowV59,coordPinnedYellowV136,coordNearbyRowV18,coordLiveYellowV128
    global coordRunSelectedV210,mapRunResumeV210,coordNoTargetSinceV14,coordCastPendingV50,coordCastLastRowV50
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    if (reason="AFTER_HP2_RECOVERY" || reason="AFTER_SIG" || reason="PORTAL_ARRIVAL")
    {
        r := coordRouteV16
        if (!IsObject(r) || r.pid!=pid || r.startLevel!=level)
        {
            if (reason!="PORTAL_ARRIVAL")
                return false
        }
        else
        {
        r.resumeNearestV303 := false,r.stuckProbe := false,r.moveProbe := false,r.lastDispatch := 0
        r.escapeV84 := false,coordNoTargetSinceV14 := 0
        AutoMonsterAttackLogV2("ROUTE_RESUME_ORDERED reason=" . reason . " anchor=" . r.anchor
            . " next=" . r.next . " phase=" . r.phase . " preserve_progress=1")
        CoordBoxRefreshV15(true)
        return true
        }
    }
    row := CoordNearestSavedV18(NumGet(pb,2,"UShort"),NumGet(pb,6,"UShort"),level)
    if (!row)
        return false
    CoordRouteResetV16()
    r := coordRouteV16
    r.pid := pid,r.anchor := row-1,r.next := row,r.yellow := row,r.phase := "NEXT"
    r.startX := NumGet(pb,2,"UShort"),r.startY := NumGet(pb,6,"UShort"),r.startLevel := level
    r.forwardFloorV303 := row-1
    coordManualRowV59 := 0,coordPinnedYellowV136 := row,coordNearbyRowV18 := row,coordLiveYellowV128 := row
    coordRunSelectedV210 := false,mapRunResumeV210 := false,coordNoTargetSinceV14 := 0
    coordCastPendingV50 := false,coordCastLastRowV50 := 0
    AutoMonsterAttackLogV2("ROUTE_RESUME_NEAREST reason=" . reason . " row=" . row . " next=REACH_NEAREST_THEN_FORWARD_ONLY")
    CoordBoxRefreshV15(true)
    return true
}

CoordRouteObserveV18(h,ByRef pb,pid)
{
    routePointsV724 := FarmRoutePointsV724()
    if (BOCommonActiveV444(pid))
        return
    global coordRouteV16,coordNoTargetSinceV14,monsterCombatUidV45,combatRecoverV48,combatMildRecoverV299,monsterRoadAreaV51,monsterChaseV44,monsterRadiusV48,coordManualRowV59
    global farmLoadedMapV56,coordYellowRowV350,autoMonsterAttackOn,farmSkillPairV620,farmCenterCycleV741
    observedLevelV381 := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    if (autoMonsterAttackOn && !Stage2MapWaitV381(pid,observedLevelV381))
        return
    if (!IsObject(coordRouteV16) || (coordRouteV16.pid && coordRouteV16.pid!=pid))
        CoordRouteResetV16()
    r := coordRouteV16
    px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    if (!px || !py || !level)
        return
    if (r.portalArrivalPendingV307)
    {
        if (!CoordPortalResumeV306(h,pb,pid))
            return
        r := coordRouteV16
    }
    if (r.resumeNearestV303)
    {
        if (!CoordResumeNearestV303(h,pb,pid,"AFTER_SIG"))
            return
        r := coordRouteV16
    }
    if (r.phase="START")
    {
        if (!routePointsV724.Length())
        {
            AutoMonsterAttackLogV2("ROUTE_WAIT reason=NO_SAVED_COORDINATES use=GET_COORDINATE",true)
            return
        }
        origin := coordYellowRowV350>=1 && coordYellowRowV350<=routePointsV724.Length()
            && routePointsV724[coordYellowRowV350].level=level ? coordYellowRowV350 : 1

        continuingV242 := false
        if (r.resumeRowV210>=1 && r.resumeRowV210<=routePointsV724.Length()
            && routePointsV724[r.resumeRowV210].level=level)
        {
            origin := r.resumeRowV210
            continuingV242 := true
            r.resumeRowV210 := 0
            AutoMonsterAttackLogV2("RUN_RESUME row=" . (origin+1) . " next=" . (origin+2))
        }
        if (!origin)
            return
        r.pid := pid, r.startX := px, r.startY := py, r.startLevel := level
        if (r.startAtYellowV367)
            r.anchor := origin-1,r.next := origin,r.yellow := origin
        else
            r.anchor := origin,r.next := origin+1,r.yellow := origin
        r.phase := r.next>routePointsV724.Length() ? "DONE" : "NEXT", r.bypass := false
        if (Stage2FightEnabledV9() && !BossSearchActiveV430(pid,level))
            r.combatRowV627 := origin
        AutoMonsterAttackLogV2("ROUTE_START_YELLOW row=" . (origin+1) . " player=" . px . "," . py)
        AutoMonsterAttackLogV2("ROUTE_START current_origin=" . px . "," . py . " destination_row=" . (r.next+1))
        CoordBoxRefreshV15()
    }
    if (r.combatRowV627>=1)
    {
        r.anchor := Min(routePointsV724.Length(),r.combatRowV627-1)
        r.next := r.combatRowV627
        r.phase := r.combatRowV627>routePointsV724.Length() ? "DONE" : "NEXT"
        r.forwardFloorV303 := r.anchor
    }
    if (r.anchor<r.forwardFloorV303)
        r.anchor := r.forwardFloorV303
    r.forwardFloorV303 := Max(r.forwardFloorV303,r.anchor)
    if (r.phase="NEXT")
        r.next := r.anchor+1
    if (r.yellow<r.anchor)
        r.yellow := r.anchor

    if (!r.combatRowV627 && RoomCoordinateModeV116() && !ScosOrderedRouteV234())
        RoomGroupObserveV118(h,pb,level)
    probe := r.moveProbe
    if (IsObject(probe) && !probe.reported)
    {
        moved := px!=probe.x || py!=probe.y
        if (moved || A_TickCount-probe.at>=1800)
        {
            AutoMonsterAttackLogV2("ROUTE_MOVE_OBSERVED row=" . probe.row . " before=" . probe.x . "," . probe.y . " now=" . px . "," . py . " position_changed=" . moved)
            probe.reported := true
            if (moved)
                r.tries := 0
        }
    }
    if (r.phase="NEXT" && r.anchor>=1 && r.anchor<routePointsV724.Length())
        r.next := r.anchor+1
    if (r.phase="NEXT" && r.next>=1 && r.next<=routePointsV724.Length())
    {
        point := routePointsV724[r.next]
        dist := (px-point.x)*(px-point.x)+(py-point.y)*(py-point.y)
        isLastPoint := (r.next = routePointsV724.Length())
        entrySegmentV577 := FarmCommonRouteActiveV3(pid,level)
        finalFarmPointV577 := isLastPoint && !entrySegmentV577
        defaultArrival := isLastPoint && entrySegmentV577 ? 100 : 25
        arrivalSq := finalFarmPointV577 ? 25 : (point.HasKey("arrivalSqV3") ? Max(0,point.arrivalSqV3) : defaultArrival)
        stepOK := (!r.lastArrivalV343 || A_TickCount-r.lastArrivalV343>=300)
        ; Khi farm B->C dang MOVE, chi FarmCenterAdvanceV756 duoc phep chot C.
        ; Tranh timer route nhay dong vang/C->D truoc khi xu ly quai tai C.
        if (!r.combatRowV627 && !FarmCenterPendingV741(pid)
            && (!RoomCoordinateModeV116() || ScosOrderedRouteV234()) && point.level=level && dist<=arrivalSq && stepOK)
        {
            MovementCtrlSetV78(false,0,"CoordRouteObserveV18")
            r.lastArrivalV343 := A_TickCount
            r.anchor := r.next, r.yellow := r.next, r.moveProbe := false, r.bypass := false
            r.startAtYellowV367 := false
            r.phase := r.anchor>=routePointsV724.Length() ? "DONE" : "NEXT"
            if (r.phase="NEXT")
                r.next := r.anchor+1
            CoordCastMarkV50(r.anchor)
            r.lastDispatch := 0
            r.firstMoveAttempted := false
            coordNoTargetSinceV14 := A_TickCount-250
            r.escapeV84 := false
            if (IsObject(farmSkillPairV620) && farmSkillPairV620.buffDone)
                farmSkillPairV620.needsCheck := true
            FarmStuckInfoDisableV10()
            AutoMonsterAttackLogV2("ROUTE_ARRIVED row=" . (r.anchor+1) . " player=" . px . "," . py . " movement=CONTINUE_TO_NEXT_OR_FREE_AT_END combat=ROAD_SCAN")
            ToolTipInfoV386("ĐÃ ĐẾN DÒNG " . (r.anchor+1) . (r.phase="DONE" ? " — QUÉT ĐÁNH TỰ DO" : " — ĐI TIẾP VÀ QUÉT ĐÁNH"))
            SetTimer, RemoveToolTip, -3000
            CoordBoxRefreshV15()
        }
    }
    if (r.phase="NEXT" && r.next>=1 && r.next<=routePointsV724.Length())
    {
        goal := routePointsV724[r.next]
        goalDistance := Sqrt((px-goal.x)*(px-goal.x)+(py-goal.y)*(py-goal.y))
        if (r.legRow!=r.next)
        {
            r.legRow := r.next, r.closestGoalDistance := goalDistance
            r.firstMoveAttempted := false, r.lastDispatch := 0, r.stuckProbe := false
        }
        else if (r.closestGoalDistance<0 || goalDistance<r.closestGoalDistance)
            r.closestGoalDistance := goalDistance
    }

    FarmFinalArrivalV577(pid,level,px,py)
}

FarmNormalFinalMapV577(owner,level)
{
    if (owner="SCOS")
        return level=270
    if (owner="NAO")
        return level=NaoFarmLevelV312(level) && !FarmReviveTownLevelV295(level)
    if (owner="M3000")
        return level=141
    if (owner="LIB")
        return LibFarmLevelV292(level)
    plan := FarmMapPlanV10(owner,level)
    return IsObject(plan) && plan.final
}

FarmFinalArrivalV577(pid,level,px,py)
{
    routePointsV724 := FarmRoutePointsV724()
    global farmGD2TestV644,coordRouteV16
    if (IsObject(farmGD2TestV644))
    {
        if (IsObject(coordRouteV16) && coordRouteV16.phase="DONE")
            MapStage2RouteFinishV185()
        return false
    }
    global mapWorkflowV185,farmControlOwnerV186,coordRouteV16
    global autoMonsterAttackOn
    if (!autoMonsterAttackOn || FarmCommonRouteActiveV3(pid,level)
        || Stage2FlowModeV380()!="NORMAL" || !IsObject(mapWorkflowV185)
        || mapWorkflowV185.stage!=2 || mapWorkflowV185.map!=farmControlOwnerV186)
        return false
    if (!FarmNormalFinalMapV577(farmControlOwnerV186,level))
        return false
    r := coordRouteV16,count := routePointsV724.Length()
    if (!IsObject(r) || r.pid!=pid || r.startLevel!=level || !count
        || r.phase!="DONE" || r.anchor<count)
        return false
    last := routePointsV724[count]
    if (last.level!=level || (px-last.x)**2+(py-last.y)**2>25)
        return false
    if (!MapStage2RouteFinishV185())
        return false
    return true
}


CoordBoxTextV16()
{
    global coordCurrentTextV15, coordSavedV15, coordRouteV16, autoMonsterAttackOn, coordNearbyRowV18,roomExploreV89,coordCurrentLevelV400
    yellow := CoordYellowIndexV48()
    points := IsObject(roomExploreV89) && roomExploreV89.savedRouteOnly ? roomExploreV89.saved : coordSavedV15
    global coordCurrentRoomV130
    text := "1: NV " . (RegExMatch("" . coordCurrentRoomV130,"^\d+$") ? coordCurrentRoomV130 : "?") . "|" . coordCurrentTextV15
        . (coordCurrentLevelV400 ? " | Map " . coordCurrentLevelV400 : "")
    for i,point in points
    {
        number := point.HasKey("roomNumber") ? point.roomNumber : "-"
        text .= "`r`n" . (i+1) . ": " . number . "|" . point.x . "," . point.y
    }
    return text
}

PetExcludeTextV16()
{
    global monsterExcludeClassesV11
    text := "", seen := {}
    for _,token in StrSplit(RegExReplace(monsterExcludeClassesV11,"[;\s]+",","),",")
    {
        if (!RegExMatch(token,"^\d+$") || seen.HasKey(token+0))
            continue
        seen[token+0] := true
        text .= (text="" ? "" : "`r`n") . (token+0)
    }
    return text
}

PetExcludeRefreshV16()
{
    global PetExcludeHwndV16
    if (PetExcludeHwndV16 && DllCall("IsWindow","Ptr",PetExcludeHwndV16))
        DllCall("SendMessage","Ptr",PetExcludeHwndV16,"UInt",0xC,"Ptr",0,"Str",PetExcludeTextV16() . "`r`n")
}


CoordColorKeyV17()
{
    global autoMapTrackingV10
    return (autoMapTrackingV10 ? "AUTO:" : "PINNED:") . CoordYellowIndexV48()
}

CoordDrawRowV17(lParam)
{
    global CoordListHwndV15, coordRowsV17, coordRouteV16, autoMonsterAttackOn, coordNearbyRowV18
    if (!lParam || !CoordListHwndV15 || NumGet(lParam+0,0,"UInt")!=2)
        return false
    hwndOffset := A_PtrSize=8 ? 24 : 20
    dcOffset := A_PtrSize=8 ? 32 : 24
    rectOffset := A_PtrSize=8 ? 40 : 28
    if (NumGet(lParam+0,hwndOffset,"Ptr")!=CoordListHwndV15)
        return false
    item := NumGet(lParam+0,8,"UInt")
    if (item=0xFFFFFFFF)
        return true
    dc := NumGet(lParam+0,dcOffset,"Ptr"), rect := lParam+rectOffset
    state := NumGet(lParam+0,16,"UInt"), selected := state & 1
    color := selected ? 0xFFE8D6 : 0xFFFFFF
    idx := CoordYellowIndexV48()
    if (item=idx && item>0)
        color := 0x99E8FF
    brush := DllCall("gdi32\CreateSolidBrush","UInt",color,"Ptr")
    saved := DllCall("gdi32\SaveDC","Ptr",dc,"Int")
    try
    {
        DllCall("user32\FillRect","Ptr",dc,"Ptr",rect,"Ptr",brush)
        font := DllCall("SendMessage","Ptr",CoordListHwndV15,"UInt",0x31,"Ptr",0,"Ptr",0,"Ptr")
        if (font)
            DllCall("gdi32\SelectObject","Ptr",dc,"Ptr",font,"Ptr")
        DllCall("gdi32\SetBkMode","Ptr",dc,"Int",1)
        DllCall("gdi32\SetTextColor","Ptr",dc,"UInt",0)
        VarSetCapacity(textRect,16,0)
        Loop, 4
            NumPut(NumGet(rect+0,(A_Index-1)*4,"Int"),textRect,(A_Index-1)*4,"Int")
        NumPut(NumGet(textRect,0,"Int")+4,textRect,0,"Int")
        caption := IsObject(coordRowsV17) ? coordRowsV17[item+1] : ""
        DllCall("user32\DrawTextW","Ptr",dc,"WStr",caption,"Int",-1,"Ptr",&textRect,"UInt",0x8824)
        if (selected || (state & 0x10))
            DllCall("user32\DrawFocusRect","Ptr",dc,"Ptr",rect)
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


ToolDoubleBindV18(key,label,state)
{
    static bound := {}
    old := bound.HasKey(label) ? bound[label] : ""
    if (old!="")
    {
        BackgroundHotkeyV63("~$" . old,label,"Off UseErrorLevel")
        bound[label] := ""
    }
    if (state="Off" || label="QCastDoubleKeyHandler" || label="ClickCastDoubleHandler")
        return
    key := NormalizeOptionalKey(key)
    if (key="")
        return
    BackgroundHotkeyV63("~$" . key,label,"On UseErrorLevel")
    if (!ErrorLevel)
        bound[label] := key
}


NativeMoveCodeV19(remote,base,player,moveCommand := 3,pathingV505 := false,commonV505 := 0)
{
    hex := "6068" . NativeLE32V9(remote+128) . "68" . NativeLE32V9(player)
    hex .= "B8" . NativeLE32V9(base+0x186A0) . "FFD0A3" . NativeLE32V9(remote+192)
    hex .= "85C0"
    branchAt := StrLen(hex)//2
    hex .= "0F8400000000"
    targetXV502 := pathingV505 ? remote+216 : remote+140
    targetYV502 := pathingV505 ? remote+220 : remote+144
    hex .= "8B0D" . NativeLE32V9(targetXV502) . "8B15" . NativeLE32V9(targetYV502)
    hex .= "890D" . NativeLE32V9(remote+200) . "8915" . NativeLE32V9(remote+204)
    if (pathingV505 && commonV505)
    {
        hex .= "BE" . NativeLE32V9(player) . "8B762C8B463CA3" . NativeLE32V9(remote+224)
        hex .= "6A0156B8" . NativeLE32V9(commonV505+0x34F80) . "FFD0"
        hex .= "8B0D" . NativeLE32V9(targetXV502) . "8B15" . NativeLE32V9(targetYV502)
    }
    hex .= "68" . NativeLE32V9(player) . "6A" . Format("{:02X}",moveCommand) . "8BC2"
    hex .= "BA" . NativeLE32V9(base+0x1A010) . "FFD2A3" . NativeLE32V9(remote+196)
    hex .= "B9" . NativeLE32V9(player) . "8B492C8B4128A3" . NativeLE32V9(remote+208)
    hex .= "8B413CA3" . NativeLE32V9(remote+212)
    if (pathingV505 && commonV505)
        hex .= "FF35" . NativeLE32V9(remote+224) . "51B8" . NativeLE32V9(commonV505+0x34F80) . "FFD0"
    finishAt := StrLen(hex)//2
    skip := finishAt-(branchAt+6)
    if (skip<0)
        return ""
    hex := SubStr(hex,1,branchAt*2+4) . NativeLE32V9(skip) . SubStr(hex,branchAt*2+13)
    return hex . "6131C0C20400"
}


RoomExportV19(h,base)
{
    player := D2ReadU32(h,base+0x11BBFC), path := player ? D2ReadU32(h,player+0x2C) : 0
    if (!MonsterBossProbeReadV1(h,path,0x20,pb))
    {
        PacketWatchLogV1("ROOM_EXPORT reason=PLAYER_PATH_READ_FAIL")
        return
    }
    current := NumGet(pb,0x1C,"UInt"), current2 := current ? D2ReadU32(h,current+0x10) : 0
    PacketWatchLogV1("ROOM_EXPORT_BEGIN current_room1=" . V92Hex(current) . " current_room2=" . V92Hex(current2)
        . " player=" . NumGet(pb,2,"UShort") . "," . NumGet(pb,6,"UShort") . " numbering=SNAPSHOT_ONLY")
    scanRooms := MonsterLoadedRoomsV20(h,current), seen := {}
    nearPtr := current2 ? D2ReadU32(h,current2+8) : 0, count := current2 ? D2ReadU32(h,current2+0x2C) : 0
    PacketWatchLogV1("ROOM_SCAN_LINKS pointer=" . V92Hex(nearPtr) . " count=" . count . " source=ROOM2 offsets=8,44 filter=LOADED_SAME_MAP")
    row := 0
    for _,r in scanRooms
    {
        if (!r || seen.HasKey(r))
            continue
        seen[r] := true, row++
        r2 := D2ReadU32(h,r+0x10)
        PacketWatchLogV1("ROOM_SCANNED snapshot_no=" . row . " current=" . (r=current)
            . " room1=" . V92Hex(r) . " room2=" . V92Hex(r2) . " " . RoomDescribeV19(h,r2)
            . " " . RoomUnitsV19(h,r))
    }
    if (MonsterBossProbeReadV1(h,current2,0x60,rb))
    {
        ptr := NumGet(rb,8,"UInt"), n := NumGet(rb,0x2C,"UInt"), seen2 := {}
        PacketWatchLogV1("ROOM_NEIGHBOR_LINKS pointer=" . V92Hex(ptr) . " count=" . n . " offsets=8,44")
        if (ptr && n>0 && n<=64)
        {
            Loop, %n%
            {
                r2 := D2ReadU32(h,ptr+(A_Index-1)*4)
                if (!r2 || seen2.HasKey(r2))
                    continue
                seen2[r2] := true
                loaded := D2ReadU32(h,r2+0x30)
                PacketWatchLogV1("ROOM_NEIGHBOR index=" . A_Index . " room2=" . V92Hex(r2)
                    . " room1=" . V92Hex(loaded) . " loaded=" . (loaded!=0) . " in_monster_scan=" . seen.HasKey(loaded)
                    . " " . RoomDescribeV19(h,r2))
            }
        }
    }
    PacketWatchLogV1("ROOM_EXPORT_END scanned_rooms=" . row . " read_only=1")
}

RoomDescribeV19(h,room2)
{
    if (!MonsterBossProbeReadV1(h,room2,0x60,rb))
        return "room_data=READ_FAIL"
    level := NumGet(rb,0x58,"UInt"), map := level ? D2ReadU32(h,level+0x1D0) : 0
    x := NumGet(rb,0x34,"UInt"), y := NumGet(rb,0x38,"UInt")
    w := NumGet(rb,0x3C,"UInt"), height := NumGet(rb,0x40,"UInt")
    preset := NumGet(rb,0x48,"UInt"), info := NumGet(rb,0x20,"UInt")
    number := "NA"
    if (preset=2 && info && MonsterBossProbeReadV1(h,info,4,numberBytes))
        number := NumGet(numberBytes,0,"UInt")
    return "map=" . map . " room_grid=" . x . "," . y . " grid_size=" . w . "," . height
        . " preset_type=" . preset . " preset_room_number=" . number
}

RoomUnitsV19(h,room)
{
    u := D2ReadU32(h,room+0x74), seen := {}, total := 0, live := 0, eligible := 0
    start := A_TickCount, truncated := false
    while (u)
    {
        if (seen.HasKey(u) || total>=2048 || A_TickCount-start>40)
        {
            truncated := true
            break
        }
        seen[u] := true
        if (!MonsterBossProbeReadV1(h,u,0xEC,ub))
        {
            truncated := true
            break
        }
        total++
        mode := NumGet(ub,16,"UInt")
        if (NumGet(ub,0,"UInt")=1 && mode!=0 && mode!=12)
        {
            live++
            if (!MonsterClassExcludedV11(NumGet(ub,4,"UInt"),h,u))
                eligible++
        }
        u := NumGet(ub,0xE8,"UInt")
    }
    return "units=" . total . " live_type1=" . live . " class_not_excluded=" . eligible . " count_truncated=" . truncated
}


MonsterLoadedRoomsV20(h,current)
{
    rooms := [], seen := {}
    if (!current)
        return rooms
    rooms.Push(current), seen[current] := true
    current2 := D2ReadU32(h,current+0x10)
    if (ScosOrderedRouteV234())
        return ScosLoadedUnitsRegionsV235(h,current,current2)
    if (!MonsterBossProbeReadV1(h,current2,0x60,rb))
        return rooms
    level := NumGet(rb,0x58,"UInt"), map := level ? D2ReadU32(h,level+0x1D0) : 0
    ptr := NumGet(rb,8,"UInt"), count := NumGet(rb,0x2C,"UInt")
    if (!map || !ptr || count<1 || count>64)
        return rooms
    Loop, %count%
    {
        room2 := D2ReadU32(h,ptr+(A_Index-1)*4)
        if (!room2 || !MonsterBossProbeReadV1(h,room2,0x60,nb))
            continue
        room1 := NumGet(nb,0x30,"UInt"), otherLevel := NumGet(nb,0x58,"UInt")
        if (!room1 || seen.HasKey(room1) || !otherLevel
            || D2ReadU32(h,otherLevel+0x1D0)!=map || D2ReadU32(h,room1+0x10)!=room2)
            continue
        rooms.Push(room1), seen[room1] := true
    }
    return rooms
}

ScosLoadedUnitsRegionsV235(h,current,current2)
{
    rooms := [current],seenRooms := {},seenNodes := {},queued := {},queue := [current2],index := 1
    seenRooms[current] := true,queued[current2] := true
    if (!MonsterBossProbeReadV1(h,current2,0x60,origin))
        return rooms
    level := NumGet(origin,0x58,"UInt"),map := level ? D2ReadU32(h,level+0x1D0) : 0
    if (!map)
        return rooms
    while (index<=queue.Length() && index<=4096)
    {
        node := queue[index],index++
        if (!node || seenNodes.HasKey(node))
            continue
        seenNodes[node] := true
        if (!MonsterBossProbeReadV1(h,node,0x60,nb))
            continue
        otherLevel := NumGet(nb,0x58,"UInt"),loaded := NumGet(nb,0x30,"UInt")
        if (!otherLevel || D2ReadU32(h,otherLevel+0x1D0)!=map
            || !loaded || D2ReadU32(h,loaded+0x10)!=node)
            continue
        if (!seenRooms.HasKey(loaded))
            rooms.Push(loaded),seenRooms[loaded] := true
        ptr := NumGet(nb,8,"UInt"),count := NumGet(nb,0x2C,"UInt")
        if (!ptr || count<1 || count>64)
            continue
        Loop, %count%
        {
            linked := D2ReadU32(h,ptr+(A_Index-1)*4)
            if (linked && !queued.HasKey(linked))
                queue.Push(linked),queued[linked] := true
        }
    }
    return rooms
}

MonsterRoadEligibleV52(px,py,x,y)
{
    routePointsV724 := FarmRoutePointsV724()
    global farmCombatAreaV590,backgroundPidV63,monsterRadiusV48
    bkSq := Max(1,monsterRadiusV48)**2
    if (FarmCenterPolicyV741(backgroundPidV63))
        return (x-px)**2+(y-py)**2<=bkSq
    if (IsObject(farmCombatAreaV590) && farmCombatAreaV590.pid=backgroundPidV63)
    {
        area := farmCombatAreaV590.area
        if (!MonsterInsideAreaV48(x,y,area))
            return false
        return (x-px)**2+(y-py)**2 <= bkSq
    }
    if (BOCommonActiveV444())
    {
        global stage2FlowV380,pickupRadius
        searchV503 := stage2FlowV380.searchV430
        centerV503 := IsObject(searchV503.itemCenterV447) ? searchV503.itemCenterV447 : searchV503.fightOriginV488
        cxV447 := IsObject(centerV503) ? centerV503.x : px
        cyV447 := IsObject(centerV503) ? centerV503.y : py
        if (Abs(x-cxV447)+Abs(y-cyV447) > Max(1,pickupRadius))
            return false
        return (x-px)**2+(y-py)**2 <= bkSq
    }
    global roomExploreV89,coordRouteV16
    scanRadiusV20 := MonsterScanRadiusV20(IsObject(coordRouteV16) ? coordRouteV16.startLevel : 0)
    if (ScosOrderedRouteV234())
        return (x-px)**2+(y-py)**2<=scanRadiusV20*scanRadiusV20
    if (RoomCoordinateModeV116())
        return (x-px)*(x-px)+(y-py)*(y-py)<=scanRadiusV20*scanRadiusV20
    if (IsObject(roomExploreV89))
    {
        if (roomExploreV89.skipCombatRoom=roomExploreV89.current && roomExploreV89.skipCombatRoom)
            return false
        node := roomExploreV89.nodes[roomExploreV89.current]
        return IsObject(node) && x>=node.x && x<node.x+node.w && y>=node.y && y<node.y+node.h
            && (x-px)*(x-px)+(y-py)*(y-py)<=scanRadiusV20*scanRadiusV20
    }
    global goalDetourV14
    r := coordRouteV16
    if ((x-px)**2+(y-py)**2 > bkSq)
        return false
    if (!IsObject(r) || r.phase!="NEXT" || r.next<1 || r.next>routePointsV724.Length())
        return true
    p := routePointsV724[r.next]
    gx := p.x-px, gy := p.y-py, length := Sqrt(gx*gx+gy*gy)
    if (!length)
        return false
    dx := x-px, dy := y-py, forward := (dx*gx+dy*gy)/length
    goalDist := Sqrt((x-p.x)*(x-p.x)+(y-p.y)*(y-p.y))
    side := Abs(dx*gy-dy*gx)/length
    if (r.bypass)
        return dx*dx+dy*dy<=scanRadiusV20*scanRadiusV20
    closest := r.closestGoalDistance>=0 ? r.closestGoalDistance : length
    return goalDist<=closest+goalDetourV14
}

MonsterRoadRankV52(px,py,x,y,dist)
{
    return dist
}

CoordTeleportStuckV55(h,ByRef pb,pid,point,direction := 1)
{
    routePointsV724 := FarmRoutePointsV724()
    if (CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))=163)
        return false
    global teleportKeyV55,teleportIntervalSecV56,coordRouteV16,teleLockSecV13,backgroundAimV64
    global roomExploreV89,autoMonsterAttackOn
        if (!autoMonsterAttackOn)
            return CoordTeleBlockedV96("FARM_CANCELLED")
        if (IsObject(roomExploreV89))
            return CoordTeleBlockedV96("ROOM_TEST_TELEPORT_DISABLED")
        routeSnapshotV80 := coordRouteV16
        if (!IsObject(routeSnapshotV80) || !IsObject(routeSnapshotV80.escapeV84)
            || (routeSnapshotV80.escapeV84.reason!="WALK_NO_PROGRESS"
                && routeSnapshotV80.escapeV84.reason!="COMBAT_NO_PROGRESS"))
            return CoordTeleBlockedV96("NO_CONFIRMED_STUCK_STATE")
        if (!IsObject(routeSnapshotV80) || routeSnapshotV80.phase!="NEXT"
            || routeSnapshotV80.next!=routeSnapshotV80.anchor+1
            || routePointsV724[routeSnapshotV80.next]!=point)
            return CoordTeleBlockedV96("ROUTE_CHANGED_OR_NOT_NEXT")
    if (teleportKeyV55="")
        return CoordTeleBlockedV96("TELEPORT_KEY_EMPTY")
    if (!FarmAttackReleaseWaitV15())
        return CoordTeleBlockedV96("ATTACK_RELEASE_PENDING")
    if (!NativeDispatchReadyV10(true))
        return CoordTeleBlockedV96("DISPATCH_BUSY")
    if (D2GetActiveGamePidV95()!=pid)
        return CoordTeleBlockedV96("GAME_PID_CHANGED")
    if (!AutoMonsterPacketCleanupV1())
        return CoordTeleBlockedV96("NATIVE_THREAD_BUSY")
    hwnd := GameTargetHwndV63(), base := D2GetModuleBaseV35(pid,"D2Client.dll")
    livePlayerV631 := D2ReadU32(h,base+0x11BBFC)
    livePathV631 := livePlayerV631 ? D2ReadU32(h,livePlayerV631+0x2C) : 0
    if (!MonsterBossProbeReadV1(h,livePathV631,0x20,pb))
        return CoordTeleBlockedV96("LIVE_PATH_AFTER_RELEASE_UNREADABLE")
    path := NumGet(pb,0x1C,"UInt")
    view := AutoMonsterAttackViewV1(h,base,hwnd,livePathV631)
    if (!IsObject(view) || CoordLevelV14(h,path)!=point.level)
        return CoordTeleBlockedV96("VIEW_OR_MAP_INVALID")
    px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
    dx := point.x-px,dy := point.y-py
    vectorV661 := CoordEscapeVectorV661(dx,dy,direction,px,py)
    dx := vectorV661.x,dy := vectorV661.y
    sx := (dx-dy)*16, sy := (dx+dy)*8
    length := Sqrt(sx*sx+sy*sy)
    if (length<1)
        return CoordTeleBlockedV96("ALREADY_AT_DESTINATION")
    playerSX := NumGet(pb,8,"Int")-view.ox
    playerSY := NumGet(pb,12,"Int")-view.oy
    ; B/C movement-stuck Tele only. Item-stuck Tele uses CoordGoTeleportToV303.
    reach := MonsterRadiusGetV239()/Sqrt(dx*dx+dy*dy)
    if (IsObject(direction))
        reach := Min(1,reach)
    aimX := Max(16,Min(view.gw-16,playerSX+sx*reach))
    aimY := Max(32,Min(view.gh-64,playerSY+sy*reach))
    clientX := Round(aimX*view.cw/view.gw), clientY := Round(aimY*view.ch/view.gh)
    if (!NativeDispatchReadyV10(true)
        || GameTargetHwndV63()!=hwnd || D2GetActiveGamePidV95()!=pid)
        return CoordTeleBlockedV96("GAME_CONTEXT_BEFORE_AIM")
    try
    {
    if (!GameTargetAimV63(clientX,clientY))
        return CoordTeleBlockedV96("AIM_SEND_FAILED")
    Sleep, 30
    if (!NativeDispatchReadyV10(true)
        || GameTargetHwndV63()!=hwnd || D2GetActiveGamePidV95()!=pid)
        return CoordTeleBlockedV96("GAME_CONTEXT_AFTER_AIM")
    if (!autoMonsterAttackOn || coordRouteV16!=routeSnapshotV80
        || routePointsV724[coordRouteV16.next]!=point
        || !IsObject(coordRouteV16.escapeV84)
        || (coordRouteV16.escapeV84.reason!="WALK_NO_PROGRESS"
            && coordRouteV16.escapeV84.reason!="COMBAT_NO_PROGRESS"))
    {
        backgroundAimV64 := false
        return CoordTeleBlockedV96("ROUTE_CHANGED_AFTER_AIM")
    }
    sentV84 := BuffCheckedSendV29(teleportKeyV55)
    backgroundAimV64 := false
    if (!sentV84)
        return CoordTeleBlockedV96("KEY_SEND_BLOCKED")
    if (IsObject(roomExploreV89))
        roomExploreV89.lastTeleAt := A_TickCount
    Sleep, 100
    AutoMonsterAttackLogV2("STUCK_TELEPORT"
        . " direction=" . (direction=1 ? "GOAL" : direction=-1 ? "REVERSE" : direction) . " key=" . teleportKeyV55 . " destination=" . point.x . "," . point.y
        . " aim_client=" . clientX . "," . clientY . " presses=1 cooldown_ms=" . (teleportIntervalSecV56*1000) . " effect=UNCONFIRMED")
    return true
    }
    finally
        backgroundAimV64 := false
}

CoordStuckStartV84(h,ByRef pb,pid,reason,manualGoalV392 := false)
{
    global coordRouteV16,monsterCombatUidV45,monsterRoadAreaV51,monsterChaseV44,roomExploreV89,autoMonsterAttackOn
    manual := CoordRecoveryGoalValidV655(manualGoalV392) && (!autoMonsterAttackOn || FarmItemGoalValidV655(manualGoalV392))
    if (reason!="WALK_NO_PROGRESS")
        return false
    if (!manual && IsObject(roomExploreV89))
    {
        RoomWalkBlockedV107(roomExploreV89,reason)
        return false
    }
    points := manual ? manualGoalV392.pointsV392 : FarmRoutePointsV724()
    r := manual ? manualGoalV392.routeV392 : coordRouteV16
    if (!IsObject(r) || r.pid!=pid || r.phase!="NEXT" || r.next!=r.anchor+1
        || r.next<2 || r.next>points.Length())
        return false
    if (!IsObject(r.escapeV84))
    {
        point := points[r.next]
        b := points[r.next-1]
        px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
        e := {row:r.next,point:point,reason:reason,phase:"T1",stuckX:px,stuckY:py
            ,returnXV608:b.x,returnYV608:b.y,walkRecoveryV642:true}
        r.escapeV84 := e
        CoordWalkEscapeSetV661(e,"T1",px,py)
        r.stuckProbe := false,r.bypass := true
        monsterCombatUidV45 := 0,monsterRoadAreaV51 := false,monsterChaseV44 := false
        FarmStuckInfoEnableV10()
        FarmWatchStuckBeginV679(e,pid,"DI_CHUYEN",A_TickCount)
    }
    return true
}

CoordStuckTickV84(h,ByRef pb,pid,manualGoalV392 := false,arrivalRadiusV1251 := 5)
{
    global coordRouteV16,chaseCheckSecV9,autoMonsterAttackOn,monsterCombatUidV45,boMoveMinimumV456
    if (BOCommonActiveV444(pid) && !IsObject(manualGoalV392))
        return false
    manual := CoordRecoveryGoalValidV655(manualGoalV392) && (!autoMonsterAttackOn || FarmItemGoalValidV655(manualGoalV392))
    points := manual ? manualGoalV392.pointsV392 : FarmRoutePointsV724()
    r := manual ? manualGoalV392.routeV392 : coordRouteV16
    if ((!manual && !autoMonsterAttackOn) || !IsObject(r) || r.pid!=pid || r.phase!="NEXT"
        || r.next<2 || r.next>points.Length() || r.next!=r.anchor+1)
        return false
    point := points[r.next]
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    if (level!=point.level)
        return false
    e := r.escapeV84
    if (!IsObject(e))
    {
        probe := r.stuckProbe
        if (!IsObject(probe) || monsterCombatUidV45)
            return false
        dist := Sqrt((px-point.x)**2+(py-point.y)**2)
        if (!probe.HasKey("dist") || probe.goalRow!=r.next || probe.dist-dist>=Max(5,boMoveMinimumV456))
        {
            r.stuckProbe := {x:px,y:py,since:A_TickCount,dist:dist,goalRow:r.next}
            return false
        }
        if (A_TickCount-probe.since<Max(1,chaseCheckSecV9)*1000
            || !CoordStuckStartV84(h,pb,pid,"WALK_NO_PROGRESS",manualGoalV392))
            return false
        e := r.escapeV84
    }
    if (e.row!=r.next || e.point!=point)
    {
        r.escapeV84 := false
        return false
    }
    if ((px-point.x)**2+(py-point.y)**2<=Max(1,arrivalRadiusV1251)**2)
    {
        CoordWalkEscapeResumeV642(r,e,"ARRIVED_C")
        return false
    }
    return CoordWalkEscapeTickV642(h,pb,pid,r,e,point,manualGoalV392,arrivalRadiusV1251)
}

FarmStuckResumeV608(r)
{
    global coordNoTargetSinceV14
    r.escapeV84 := false,r.stuckProbe := false,r.moveProbe := false,r.bypass := false,r.battlePending := false
    r.lastDispatch := 0,r.bestDist := -1,r.tries := 0
    coordNoTargetSinceV14 := A_TickCount-250
}

CoordDisplayGamePidV1()
{
    static lastPid := 0
    activePid := D2GetActiveGamePidV95()
    if (activePid)
    {
        lastPid := activePid
        return activePid
    }
    if (lastPid)
    {
        hwnd := WinExist("ahk_pid " . lastPid)
        WinGetTitle, title, ahk_id %hwnd%
        if (hwnd && InStr(title,"Diablo II") && D2GetModuleBaseV35(lastPid,"D2Client.dll"))
            return lastPid
        lastPid := 0
    }
    WinGet, windows, List, Diablo II
    foundPid := 0
    Loop, %windows%
    {
        hwnd := windows%A_Index%
        WinGet, candidatePid, PID, ahk_id %hwnd%
        WinGetTitle, candidateTitle, ahk_id %hwnd%
        if (!InStr(candidateTitle,"Diablo II") || !D2GetModuleBaseV35(candidatePid,"D2Client.dll"))
            continue
        if (foundPid && foundPid!=candidatePid)
            return 0
        foundPid := candidatePid
    }
    lastPid := foundPid
    return foundPid
}

CoordDisplayPositionV1(x,y)
{
    global coordCurrentTextV15
    if (!x || !y)
        return
    text := x . "," . y
    if (text!=coordCurrentTextV15)
    {
        coordCurrentTextV15 := text
        CoordBoxRefreshV15()
    }
}

RememberTabV6:
if (!guiBuilding)
{
    GuiControlGet, selectedTabV6,, AutoGSFMainTabs
    if (selectedTabV6>=1 && selectedTabV6<=4)
        IniWrite, %selectedTabV6%, %ConfigFile%, General, SelectedTab
}
return

ChaseMissResetV6()
{
    global chaseMissV6
    chaseMissV6 := false
}

EnsureDefaultConfigV8(file)
{
    defaultConfig := "
(
[BuffList]
Key_1=F3
Delay_1=250
Key_2=F4
Delay_2=250
Key_3=F5
Delay_3=250
Key_4=F6
Delay_4=250
Key_5=M3
Delay_5=250
Key_6=M4
Delay_6=300
Key_7=NONE
Delay_7=150
Key_8=NONE
Delay_8=150
Key_9=NONE
Delay_9=150
Key_10=NONE
Delay_10=150
UseBuffMode=CÓ BUFF (Thực hiện Combo)
State_1=ON
State_2=ON
State_3=ON
State_4=ON
State_5=ON
State_6=ON
State_7=ON
State_8=ON
State_9=ON
State_10=ON
[CombatList]
Key_1=F1
Delay_1=25
Key_2=F2
Delay_2=25
Key_3=NONE
Delay_3=25
Key_4=NONE
Delay_4=25
Key_5=NONE
Delay_5=25
Mode=ENABLE (Skill + Click)
ClickType=3 Click (Triple)
[Weapon2Combo]
SkillKey=M5
Delay=400
Key_1=M3
Delay_1=300
Key_2=NONE
Delay_2=300
Key_3=NONE
Delay_3=200
SwapDelay=200
[AutoClick]
LeftState=NONE
LeftDelay=100
RightState=ENABLE
RightDelay=100
[QuickBuffX]
Key_1=M4
Delay_1=200
Key_2=M5
Delay_2=200
Key_3=NONE
Delay_3=200
[Default]
UseBuffMode=CÓ BUFF (Thực hiện Combo)
BuffKey_1=F3
BuffDelay_1=150
BuffKey_2=F4
BuffDelay_2=150
BuffKey_3=F5
BuffDelay_3=150
BuffKey_4=F6
BuffDelay_4=150
BuffKey_5=F7
BuffDelay_5=150
BuffKey_6=F8
BuffDelay_6=150
BuffKey_7=F10
BuffDelay_7=3000
BuffKey_8=NONE
BuffDelay_8=150
BuffKey_9=NONE
BuffDelay_9=150
BuffKey_10=NONE
BuffDelay_10=150
CombatKey_1=F1
CombatDelay_1=25
CombatKey_2=F2
CombatDelay_2=25
CombatKey_3=NONE
CombatDelay_3=200
CombatKey_4=NONE
CombatDelay_4=200
CombatKey_5=NONE
CombatDelay_5=200
CombatMode=ENABLE (Skill + Click)
ClickType=3 Click (Triple)
W2Key_1=M3
W2Delay_1=400
W2Key_2=NONE
W2Delay_2=200
W2Key_3=NONE
W2Delay_3=200
QXKey_1=M4
QXDelay_1=200
QXKey_2=M5
QXDelay_2=200
QXKey_3=NONE
QXDelay_3=200
AutoPotEnable=1
AutoPotKey=AUTO CYCLE (1-4)
AutoPotHpPercent=60%
AutoPotCd=6000
AutoPotClientX=62
AutoPotClientY=668
AutoPotColor=0x98928F
[Profiles]
List=Default|duongquapal|backupduongqua
Current=Default
Names=Default|NecNec
[duongquapal]
UseBuffMode=CÓ BUFF (Thực hiện Combo)
BuffKey_1=F3
BuffDelay_1=250
BuffKey_2=F4
BuffDelay_2=250
BuffKey_3=F5
BuffDelay_3=250
BuffKey_4=F6
BuffDelay_4=250
BuffKey_5=M5
BuffDelay_5=250
BuffKey_6=M4
BuffDelay_6=300
BuffKey_7=NONE
BuffDelay_7=150
BuffKey_8=NONE
BuffDelay_8=150
BuffKey_9=NONE
BuffDelay_9=150
BuffKey_10=NONE
BuffDelay_10=150
CombatKey_1=F1
CombatDelay_1=200
CombatKey_2=F2
CombatDelay_2=200
CombatKey_3=NONE
CombatDelay_3=200
CombatKey_4=NONE
CombatDelay_4=200
CombatKey_5=NONE
CombatDelay_5=200
CombatMode=ENABLE (Skill + Click)
ClickType=3 Click (Triple)
W2Key_1=M3
W2Delay_1=400
W2Key_2=NONE
W2Delay_2=200
W2Key_3=NONE
W2Delay_3=200
QXKey_1=M4
QXDelay_1=200
QXKey_2=M5
QXDelay_2=200
QXKey_3=NONE
QXDelay_3=200
AutoPotEnable=1
AutoPotKey=AUTO CYCLE (1-4)
AutoPotHpPercent=80%
AutoPotCd=3000
AutoPotRelX=-335
AutoPotRelY=595
AutoPotColor=0xEC0000
AutoPotClientX=89
AutoPotClientY=695
[backupduongqua]
UseBuffMode=CÓ BUFF (Thực hiện Combo)
BuffKey_1=F3
BuffDelay_1=250
BuffKey_2=F4
BuffDelay_2=250
BuffKey_3=F5
BuffDelay_3=250
BuffKey_4=F6
BuffDelay_4=250
BuffKey_5=M5
BuffDelay_5=250
BuffKey_6=M4
BuffDelay_6=300
BuffKey_7=NONE
BuffDelay_7=150
BuffKey_8=NONE
BuffDelay_8=150
BuffKey_9=NONE
BuffDelay_9=150
BuffKey_10=NONE
BuffDelay_10=150
CombatKey_1=F1
CombatDelay_1=200
CombatKey_2=F2
CombatDelay_2=200
CombatKey_3=NONE
CombatDelay_3=200
CombatKey_4=NONE
CombatDelay_4=200
CombatKey_5=NONE
CombatDelay_5=200
CombatMode=ENABLE (Skill + Click)
ClickType=3 Click (Triple)
AutoPotEnable=1
AutoPotKey=AUTO CYCLE (1-4)
AutoPotCd=3000
AutoPotClientX=89
AutoPotClientY=695
AutoPotColor=0xEC0000
W2Key_1=M3
W2Delay_1=400
W2Key_2=NONE
W2Delay_2=200
W2Key_3=NONE
W2Delay_3=200
QXKey_1=M4
QXDelay_1=200
QXKey_2=M5
QXDelay_2=200
QXKey_3=NONE
QXDelay_3=200
[Settings]
LastProfile=duongquapal
[General]
Version=1
SelectedTab=3
[Keys]
Z=B
X=V
[Double]
Key=Left
Interval=500
[FormDouble]
Key=None
Interval=500
[Z]
FKey=F1
Delay1=300
Delay2=0
Delay3=500
FKey2=None
SetKey=W
SetDelay=200
[Cycle]
FKey1=F10
FDelay1=5000
FKey2=
FDelay2=0
FKey3=
FDelay3=0
FKey4=
FDelay4=0
FKey5=
FDelay5=0
FKey6=
FDelay6=0
FKey7=
FDelay7=0
FKey8=
FDelay8=0
FKey9=
FDelay9=0
FKey10=
FDelay10=0
[Profile_Default]
ZKey=B
XKey=V
DoubleKey=Left
DoubleTapMs=500
FormDoubleKey=None
FormDoubleTapMs=500
QCastDoubleKey=Up
QCastDoubleTapMs=500
ZSetKey=W
ZSetDelay=200
XDelay=200
ZFKey=F1
ZFKey2=None
ZDelay1=300
ZDelay2=0
ZDelay3=500
AutoPotOn=1
InvHealOn=1
CubeHealOn=1
InvToCubeKey=/
Belt4HPKey=,
Belt2HP2ManaKey=.
PotMode=Auto(1-4)
PotCaptureKey1=N
PotHPThreshold=13000
PotCooldown=6000
ManaOn=1
ManaMode=Auto(1-4)
ManaThreshold=3000
ManaCooldown=6000
PickupImageOn=1
PickupToggleKey=^C
GetIdKey=
PickupRadius=15
QCastKey1=X
QCastDelay1=6000
QCastKey2=
QCastDelay2=0
QCastKey3=
QCastDelay3=0
FKey1=F10
FDelay1=5000
FKey2=
FDelay2=0
FKey3=
FDelay3=0
FKey4=
FDelay4=0
FKey5=
FDelay5=0
FKey6=
FDelay6=0
FKey7=
FDelay7=0
FKey8=
FDelay8=0
FKey9=
FDelay9=0
FKey10=
FDelay10=0
BossModeOn=0
DeleteIdKey=
CubePickupDelayMs=60
CubeTransferDelayMs=40
ClickCastDoubleKey=Down
ClickCastDoubleTapMs=500
ClickCastKey1=F4
ClickCastDelay1=50000
ClickCastKey2=F5
ClickCastDelay2=30000
ClickCastKey3=
ClickCastDelay3=0
ClickCastKey4=
ClickCastDelay4=0
InvManaOn=1
CubeManaOn=1
AutoMonsterAttackOn=0
MonsterExcludeClasses=1660
AutoMonsterToggleKey=L
PetLearnKey='
CoordGetKey='
CoordPoint=5507,10889
CoordLevel=270
CoordSavedCount=143
CoordSaved1=5957,11316,270
CoordSaved2=5927,11306,270
CoordSaved3=5916,11344,270
CoordSaved4=5874,11370,270
CoordSaved5=5885,11408,270
CoordSaved6=5911,11346,270
CoordSaved7=5909,11298,270
CoordSaved8=5842,11295,270
CoordSaved9=5797,11325,270
CoordSaved10=5768,11356,270
CoordSaved11=5727,11345,270
CoordSaved12=5683,11340,270
CoordSaved13=5654,11381,270
CoordSaved14=5635,11415,270
CoordSaved15=5618,11458,270
CoordSaved16=5590,11497,270
MonsterAttackRadius=40
RouteCastKey=MButton
CoordSaved17=5558,11531,270
CoordSaved18=5513,11536,270
CoordSaved19=5467,11517,270
CoordSaved20=5410,11516,270
CoordSaved21=5377,11534,270
CoordSaved22=5315,11512,270
CoordSaved23=5267,11496,270
CoordSaved24=5268,11457,270
CoordSaved25=5226,11455,270
CoordSaved26=5190,11419,270
CoordSaved27=5147,11418,270
CoordSaved28=5100,11396,270
CoordSaved29=5093,11350,270
CoordSaved30=5091,11296,270
CoordSaved31=5117,11254,270
CoordSaved32=5119,11207,270
CoordSaved33=5106,11150,270
CoordSaved34=5136,11138,270
RouteCastEvery=3
StuckTeleportKey=Space
StuckTeleportIntervalSeconds=3
ChaseCheckSeconds=3
TeleportAttackLockSeconds=3
CoordSaved35=5164,11113,270
CoordSaved36=5149,11079,270
CoordSaved37=5106,11040,270
CoordSaved38=5181,11062,270
CoordSaved39=5204,11145,270
CoordSaved40=5235,11176,270
CoordSaved41=5275,11167,270
CoordSaved42=5310,11170,270
CoordSaved43=5300,11123,270
CoordSaved44=5296,11081,270
CoordSaved45=5302,11040,270
CoordSaved46=5296,10988,270
CoordSaved47=5280,10978,270
CoordSaved48=5269,10925,270
CoordSaved49=5299,10900,270
CoordSaved50=5309,10871,270
CoordSaved51=5339,10861,270
CoordSaved52=5356,10825,270
CoordSaved53=5376,10776,270
CoordSaved54=5367,10739,270
CoordSaved55=5355,10683,270
CoordSaved56=5317,10678,270
CoordSaved57=5303,10662,270
CoordSaved58=5259,10661,270
CoordSaved59=5260,10709,270
CoordSaved60=5305,10703,270
CoordSaved61=5333,10690,270
CoordSaved62=5348,10750,270
CoordSaved63=5333,10790,270
CoordSaved64=5301,10775,270
CoordSaved65=5260,10794,270
CoordSaved66=5247,10811,270
CoordSaved67=5200,10796,270
CoordSaved68=5184,10743,270
CoordSaved69=5204,10721,270
CoordSaved70=5196,10663,270
CoordSaved71=5145,10666,270
CoordSaved72=5091,10661,270
CoordSaved73=5053,10675,270
CoordSaved74=5086,10704,270
CoordSaved75=5147,10701,270
CoordSaved76=5179,10707,270
CoordSaved77=5182,10755,270
CoordSaved78=5123,10750,270
CoordSaved79=5121,10770,270
CoordSaved80=5174,10776,270
CoordSaved81=5177,10812,270
CoordSaved82=5230,10802,270
CoordSaved83=5316,10817,270
CoordSaved84=5290,10861,270
CoordSaved85=5363,10881,270
CoordSaved86=5405,10895,270
CoordSaved87=5403,10956,270
CoordSaved88=5356,10992,270
CoordSaved89=5394,11041,270
CoordSaved90=5395,11093,270
CoordSaved91=5408,11111,270
CoordSaved92=5447,11160,270
CoordSaved93=5423,11207,270
CoordSaved94=5432,11252,270
CoordSaved95=5384,11261,270
CoordSaved96=5326,11242,270
CoordSaved97=5319,11176,270
CoordSaved98=5363,11142,270
CoordSaved99=5402,11153,270
CoordSaved100=5446,11161,270
CoordSaved101=5511,11163,270
CoordSaved102=5545,11141,270
CoordSaved103=5600,11139,270
CoordSaved104=5568,11109,270
CoordSaved105=5564,11053,270
CoordSaved106=5600,11005,270
CoordSaved107=5642,11048,270
CoordSaved108=5646,11096,270
CoordSaved109=5654,11147,270
CoordSaved110=5697,11160,270
CoordSaved111=5760,11166,270
CoordSaved112=5826,11164,270
CoordSaved113=5869,11168,270
CoordSaved114=5826,11144,270
CoordSaved115=5834,11090,270
CoordSaved116=5851,11050,270
CoordSaved117=5844,10982,270
CoordSaved118=5789,10935,270
CoordSaved119=5814,10895,270
CoordSaved120=5780,10821,270
CoordSaved121=5769,10776,270
CoordSaved122=5825,10802,270
CoordSaved123=5732,10752,270
CoordSaved124=5708,10707,270
CoordSaved125=5673,10688,270
CoordSaved126=5643,10702,270
CoordSaved127=5592,10694,270
CoordSaved128=5537,10698,270
CoordSaved129=5491,10704,270
CoordSaved130=5469,10734,270
CoordSaved131=5538,10714,270
CoordSaved132=5584,10701,270
CoordSaved133=5608,10746,270
CoordSaved134=5611,10805,270
CoordSaved135=5637,10824,270
CoordSaved136=5714,10864,270
CoordSaved137=5738,10894,270
CoordSaved138=5742,10922,270
CoordSaved139=5689,10936,270
CoordSaved140=5634,10930,270
CoordSaved141=5589,10926,270
CoordSaved142=5551,10891,270
CoordSaved143=5507,10889,270
CoordSaved144=5507,10889,270
CoordSaved145=5507,10889,270
[AutoPot]
Enabled=1
Mode=Auto(1-4)
CaptureKey=n
X=96
Y=696
Color=0X4A4444
Cooldown=6000
CaptureKey1=N
CaptureKey2=
Color1=0X474746
Color2=
PotHPThreshold=13000
InventoryHealEnabled=1
InventoryManaEnabled=1
CubeHealEnabled=1
CubeManaEnabled=1
[]
PotX=0
PotY=0
PotColor1=ERROR
[QCastDouble]
Key=Up
Interval=500
[Window]
X=554
Y=56
[X]
Delay=200
[QCast]
Key1=X
Delay1=6000
Key2=
Delay2=0
Key3=
Delay3=0
[PickupImage]
Enabled=1
Radius=15
GetIdKey=
ToggleKey=^C
DeleteIdKey=
[AutoMana]
Enabled=1
Mode=Auto(1-4)
Threshold=3000
Cooldown=6000
[V22]
CubeUID=242
[Profile_NecNec]
ZKey=B
XKey=V
DoubleKey=Left
DoubleTapMs=500
FormDoubleKey=None
FormDoubleTapMs=500
QCastDoubleKey=Up
QCastDoubleTapMs=500
ZSetKey=W
ZSetDelay=200
XDelay=200
ZFKey=F1
ZFKey2=None
ZDelay1=300
ZDelay2=0
ZDelay3=500
AutoPotOn=1
InvHealOn=1
CubeHealOn=1
InvToCubeKey=/
Belt4HPKey=,
Belt2HP2ManaKey=.
PotMode=Auto(1-4)
PotCaptureKey1=N
PotHPThreshold=13000
PotCooldown=6000
ManaOn=1
ManaMode=Auto(1-4)
ManaThreshold=3000
ManaCooldown=6000
PickupImageOn=1
PickupToggleKey=^C
GetIdKey=
PickupRadius=15
QCastKey1=X
QCastDelay1=6000
QCastKey2=
QCastDelay2=0
QCastKey3=
QCastDelay3=0
FKey1=F10
FDelay1=5000
FKey2=
FDelay2=0
FKey3=
FDelay3=0
FKey4=
FDelay4=0
FKey5=
FDelay5=0
FKey6=
FDelay6=0
FKey7=
FDelay7=0
FKey8=
FDelay8=0
FKey9=
FDelay9=0
FKey10=
FDelay10=0
BossModeOn=0
DeleteIdKey=
CubePickupDelayMs=60
CubeTransferDelayMs=40
ClickCastDoubleKey=Down
ClickCastDoubleTapMs=500
ClickCastKey1=F4
ClickCastDelay1=50000
ClickCastKey2=F5
ClickCastDelay2=30000
ClickCastKey3=
ClickCastDelay3=0
ClickCastKey4=
ClickCastDelay4=0
InvManaOn=1
CubeManaOn=1
AutoMonsterAttackOn=0
MonsterExcludeClasses=1660
AutoMonsterToggleKey=L
PetLearnKey='
CoordGetKey='
CoordPoint=5507,10889
CoordLevel=270
CoordSavedCount=143
CoordSaved1=5957,11316,270
CoordSaved2=5927,11306,270
CoordSaved3=5916,11344,270
CoordSaved4=5874,11370,270
CoordSaved5=5885,11408,270
CoordSaved6=5911,11346,270
CoordSaved7=5909,11298,270
CoordSaved8=5842,11295,270
CoordSaved9=5797,11325,270
CoordSaved10=5768,11356,270
CoordSaved11=5727,11345,270
CoordSaved12=5683,11340,270
CoordSaved13=5654,11381,270
CoordSaved14=5635,11415,270
CoordSaved15=5618,11458,270
CoordSaved16=5590,11497,270
MonsterAttackRadius=40
RouteCastKey=MButton
CoordSaved17=5558,11531,270
CoordSaved18=5513,11536,270
CoordSaved19=5467,11517,270
CoordSaved20=5410,11516,270
CoordSaved21=5377,11534,270
CoordSaved22=5315,11512,270
CoordSaved23=5267,11496,270
CoordSaved24=5268,11457,270
CoordSaved25=5226,11455,270
CoordSaved26=5190,11419,270
CoordSaved27=5147,11418,270
CoordSaved28=5100,11396,270
CoordSaved29=5093,11350,270
CoordSaved30=5091,11296,270
CoordSaved31=5117,11254,270
CoordSaved32=5119,11207,270
CoordSaved33=5106,11150,270
CoordSaved34=5136,11138,270
RouteCastEvery=3
StuckTeleportKey=Space
StuckTeleportIntervalSeconds=3
ChaseCheckSeconds=3
TeleportAttackLockSeconds=3
CoordSaved35=5164,11113,270
CoordSaved36=5149,11079,270
CoordSaved37=5106,11040,270
CoordSaved38=5181,11062,270
CoordSaved39=5204,11145,270
CoordSaved40=5235,11176,270
CoordSaved41=5275,11167,270
CoordSaved42=5310,11170,270
CoordSaved43=5300,11123,270
CoordSaved44=5296,11081,270
CoordSaved45=5302,11040,270
CoordSaved46=5296,10988,270
CoordSaved47=5280,10978,270
CoordSaved48=5269,10925,270
CoordSaved49=5299,10900,270
CoordSaved50=5309,10871,270
CoordSaved51=5339,10861,270
CoordSaved52=5356,10825,270
CoordSaved53=5376,10776,270
CoordSaved54=5367,10739,270
CoordSaved55=5355,10683,270
CoordSaved56=5317,10678,270
CoordSaved57=5303,10662,270
CoordSaved58=5259,10661,270
CoordSaved59=5260,10709,270
CoordSaved60=5305,10703,270
CoordSaved61=5333,10690,270
CoordSaved62=5348,10750,270
CoordSaved63=5333,10790,270
CoordSaved64=5301,10775,270
CoordSaved65=5260,10794,270
CoordSaved66=5247,10811,270
CoordSaved67=5200,10796,270
CoordSaved68=5184,10743,270
CoordSaved69=5204,10721,270
CoordSaved70=5196,10663,270
CoordSaved71=5145,10666,270
CoordSaved72=5091,10661,270
CoordSaved73=5053,10675,270
CoordSaved74=5086,10704,270
CoordSaved75=5147,10701,270
CoordSaved76=5179,10707,270
CoordSaved77=5182,10755,270
CoordSaved78=5123,10750,270
CoordSaved79=5121,10770,270
CoordSaved80=5174,10776,270
CoordSaved81=5177,10812,270
CoordSaved82=5230,10802,270
CoordSaved83=5316,10817,270
CoordSaved84=5290,10861,270
CoordSaved85=5363,10881,270
CoordSaved86=5405,10895,270
CoordSaved87=5403,10956,270
CoordSaved88=5356,10992,270
CoordSaved89=5394,11041,270
CoordSaved90=5395,11093,270
CoordSaved91=5408,11111,270
CoordSaved92=5447,11160,270
CoordSaved93=5423,11207,270
CoordSaved94=5432,11252,270
CoordSaved95=5384,11261,270
CoordSaved96=5326,11242,270
CoordSaved97=5319,11176,270
CoordSaved98=5363,11142,270
CoordSaved99=5402,11153,270
CoordSaved100=5446,11161,270
CoordSaved101=5511,11163,270
CoordSaved102=5545,11141,270
CoordSaved103=5600,11139,270
CoordSaved104=5568,11109,270
CoordSaved105=5564,11053,270
CoordSaved106=5600,11005,270
CoordSaved107=5642,11048,270
CoordSaved108=5646,11096,270
CoordSaved109=5654,11147,270
CoordSaved110=5697,11160,270
CoordSaved111=5760,11166,270
CoordSaved112=5826,11164,270
CoordSaved113=5869,11168,270
CoordSaved114=5826,11144,270
CoordSaved115=5834,11090,270
CoordSaved116=5851,11050,270
CoordSaved117=5844,10982,270
CoordSaved118=5789,10935,270
CoordSaved119=5814,10895,270
CoordSaved120=5780,10821,270
CoordSaved121=5769,10776,270
CoordSaved122=5825,10802,270
CoordSaved123=5732,10752,270
CoordSaved124=5708,10707,270
CoordSaved125=5673,10688,270
CoordSaved126=5643,10702,270
CoordSaved127=5592,10694,270
CoordSaved128=5537,10698,270
CoordSaved129=5491,10704,270
CoordSaved130=5469,10734,270
CoordSaved131=5538,10714,270
CoordSaved132=5584,10701,270
CoordSaved133=5608,10746,270
CoordSaved134=5611,10805,270
CoordSaved135=5637,10824,270
CoordSaved136=5714,10864,270
CoordSaved137=5738,10894,270
CoordSaved138=5742,10922,270
CoordSaved139=5689,10936,270
CoordSaved140=5634,10930,270
CoordSaved141=5589,10926,270
CoordSaved142=5551,10891,270
CoordSaved143=5507,10889,270
CoordSaved144=5507,10889,270
CoordSaved145=5507,10889,270
[ClickCast]
ClickCastDoubleKey=Down
ClickCastDoubleTapMs=500
ClickCastKey1=F4
ClickCastDelay1=50000
ClickCastKey2=F5
ClickCastDelay2=30000
ClickCastKey3=
ClickCastDelay3=0
ClickCastKey4=
ClickCastDelay4=0
[Master456]
Key=Del
)"
    if (!FileExist(file))
    {
        configHandle := FileOpen(file, "w", "UTF-16")
        if (!IsObject(configHandle))
            return false
        defaultConfig := StrReplace(defaultConfig, "`r`n", "`n")
        configHandle.Write(StrReplace(defaultConfig, "`n", "`r`n") . "`r`n")
        configHandle.Close()
        return true
    }
    section := ""
    Loop, Parse, defaultConfig, `n, `r
    {
        line := A_LoopField
        if (RegExMatch(line, "^\[(.*)\]$", sectionMatch))
        {
            section := sectionMatch1
            continue
        }
        separator := InStr(line, "=")
        if (section = "" || !separator)
            continue
        key := SubStr(line, 1, separator - 1)
        value := SubStr(line, separator + 1)
        IniRead, savedValue, %file%, %section%, %key%, __AUTO_GSF_MISSING_V8__
        if (savedValue = "__AUTO_GSF_MISSING_V8__")
            IniWrite, %value%, %file%, %section%, %key%
    }
    return true
}

PetExcludeReleaseCombatV514()
{
    global monsterRetryUntilV44,monsterChaseV44,monsterCombatUidV45,monsterRoadAreaV51
    global coordRouteV16,roomExploreV89
    MonsterStuckZonesResetV243()
    monsterRetryUntilV44 := {},monsterChaseV44 := false
    monsterCombatUidV45 := 0,monsterRoadAreaV51 := false
    ChaseMissResetV6()
    if (IsObject(coordRouteV16))
        coordRouteV16.bypass := false
    if (IsObject(roomExploreV89))
        roomExploreV89.skipCombatRoom := 0
    PortalLogWriteV66("PET_EXCLUDE_REMOVED retry_uids=CLEARED stuck_zones=CLEARED room_skip=CLEARED next=RESCAN_MONSTERS")
}

PetExcludeCommitV10(text)
{
    global monsterExcludeClassesV11
    normalized := "", seen := {}
    for _, token in StrSplit(RegExReplace(Trim(text), "[,;\s]+", ","), ",")
    {
        if (token = "")
            continue
        if (!RegExMatch(token, "^\d+$"))
        {
            MsgBox, 48, Lỗi, Class ID pet chỉ nhập số, mỗi ID một dòng.
            return false
        }
        id := token + 0
        if (seen.HasKey(id))
            continue
        seen[id] := true
        normalized .= (normalized = "" ? "" : ",") . id
    }
    oldList := monsterExcludeClassesV11
    monsterExcludeClassesV11 := normalized
    if (!PetExcludeSaveV12())
    {
        monsterExcludeClassesV11 := oldList
        MsgBox, 48, Lỗi, Không lưu được file loại trừ pet.
        return false
    }
    for _,token in StrSplit(RegExReplace(oldList,"[;\s]+",","),",")
    {
        if (RegExMatch(token,"^\d+$") && !seen.HasKey(token+0))
        {
            PetExcludeReleaseCombatV514()
            break
        }
    }
    return true
}

PetExcludeDeleteV10:
if (!PetExcludeHwndV16 || !DllCall("IsWindow", "Ptr", PetExcludeHwndV16))
    return
VarSetCapacity(petSelectionStartV10, 4, 0)
VarSetCapacity(petSelectionEndV10, 4, 0)
DllCall("SendMessage", "Ptr", PetExcludeHwndV16, "UInt", 0xB0, "Ptr", &petSelectionStartV10, "Ptr", &petSelectionEndV10)
petCaretV10 := NumGet(petSelectionStartV10, 0, "UInt")
petLineV10 := DllCall("SendMessage", "Ptr", PetExcludeHwndV16, "UInt", 0xC9, "Ptr", petCaretV10, "Ptr", 0)
GuiControlGet, petDeleteTextV10,, PetExcludeListV16
petDeleteTextV10 := StrReplace(petDeleteTextV10, "`r`n", "`n")
petKeptTextV10 := ""
Loop, Parse, petDeleteTextV10, `n, `r
{
    if (A_Index - 1 = petLineV10)
        continue
    petKeptTextV10 .= A_LoopField . "`r`n"
}
if (PetExcludeCommitV10(petKeptTextV10))
    PetExcludeRefreshV16()
return

TeleportTipHideV11:
ToolTip,,,, 2
return


AttackIdTipV12(classId,distance := "")
{
    global viewIdV54,viewPosV291
    SetTimer, TeleportTipHideV11, Off
    if (!viewIdV54)
    {
        ToolTip,,,, 2
        SetTimer, AttackIdTipWatchV12, Off
        return
    }
    text := "Mục tiêu ID: " . classId
    if (viewPosV291 && distance!="")
        text .= " | Khoảng cách: " . distance
    ToolTipInfoV386(text, "", "", 2)
    SetTimer, AttackIdTipWatchV12, 200
}

AttackIdTipWatchV12:
if (!viewIdV54 || !autoMonsterAttackOn || !IsGameActive())
{
    ToolTip,,,, 2
    SetTimer, AttackIdTipWatchV12, Off
}
return

StateBuffRead124V17(h,player,wantedState := 124)
{
    if (!player || !RegExMatch(wantedState,"^\d+$") || wantedState>4095)
        return -1
    if (!MonsterBossProbeReadV1(h,player+0x5C,4,unitStats))
        return -1
    root := NumGet(unitStats,0,"UInt")
    if (root<0x10000 || !MonsterBossProbeReadV1(h,root,0x64,b))
        return -1
    if (!(NumGet(b,0x10,"UInt") & 0x80000000) || NumGet(b,0x44,"UInt")!=player)
        return -1
    flags := NumGet(b,0x58,"UInt")
    if (flags<0x10000 || !MonsterBossProbeReadV1(h,flags+4*(wantedState>>5),4,word))
        return -1
    if (!MonsterBossProbeReadV1(h,player+0x5C,4,checkRoot)
        || NumGet(checkRoot,0,"UInt")!=root
        || !MonsterBossProbeReadV1(h,root+0x58,4,checkFlags)
        || NumGet(checkFlags,0,"UInt")!=flags)
        return -1
    return (NumGet(word,0,"UInt") & (1 << (wantedState & 31))) ? 1 : 0
}

StateBuffTickV17(h,player,ByRef pb,pid)
{
    global coordRouteV16, entryBuffPendingV20, lastAttackPendingV20, buffGetV20, townLevelV22, outsideLevelV22, pestiPointPendingV28, pestilenceKeyV18, xRunning, zRunning, gameItemActionOwner, reviveBuffPendingV34
    global portalBuffV85, coordCastPendingV50
    static session := false, lastPid := 0, wasTown := false, initialized := false
    if (reviveBuffPendingV34)
        FarmStartClearReviveBuffV757(CoordLevelV14(h,NumGet(pb,0x1C,"UInt")),D2ReadU32(h,player+0x10),pid)
    if (FarmTravelNoBuffV670(pid) || !Stage2FightEnabledV9())
        return false
    if (IsObject(portalBuffV85) && !IsObject(buffGetV20))
        return FarmPortalBuffTickV85(h,player,pid)
        if (reviveBuffPendingV34 && !IsObject(buffGetV20))
    {
        if (RouteBuffSequenceV20(h,player,pid))
        {
            reviveBuffPendingV34 := false, entryBuffPendingV20 := false
            AutoMonsterAttackLogV2("REVIVE_BUFF_DONE attack_skill=LAST_F farm=RESUME")
        }
        return true
    }
    if (IsObject(buffGetV20))
        return false
    if (!coordCastPendingV50 && AutoBuffEnsureV513(h,player,pid))
        return true
    if (!IsObject(coordRouteV16))
        return false
    if (session!=coordRouteV16 || lastPid!=pid)
        session := coordRouteV16, lastPid := pid, initialized := false, entryBuffPendingV20 := false, pestiPointPendingV28 := false
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    if (!level)
        return false
    if (townLevelV22="" || outsideLevelV22="")
        return false
    town := level=townLevelV22
    if (!initialized)
    {
        wasTown := town, initialized := true
        return false
    }
    if (town)
    {
        wasTown := true, entryBuffPendingV20 := false
        return false
    }
    if (wasTown && level=outsideLevelV22)
        wasTown := false, entryBuffPendingV20 := true
        if (entryBuffPendingV20)
    {
        if (RouteBuffSequenceV20(h,player,pid))
            entryBuffPendingV20 := false
        return true
    }
    if (pestiPointPendingV28 && coordCastPendingV50)
        return false
    if (pestiPointPendingV28)
    {
        if (xRunning || zRunning || gameItemActionOwner!="" || !NativeDispatchReadyV10(true)
            || D2GetActiveGamePidV95()!=pid || !AutoMonsterPacketCleanupV1())
            return false
        if (PestilenceEnsureV513(h,player,pid))
            return true
        pestiPointPendingV28 := false
        return true
    }
    if (lastAttackPendingV20)
    {
        if (LastAttackSkillV20())
            lastAttackPendingV20 := false
        return true
    }
    return false
}

; V1301: mot luot PORTAL buff toi da 5 giay; qua han tiep tuc Farm.
; Goi tu main center tick va worker MOVE, ke ca khi ham buff khong duoc tick.
FarmPortalBuffDeadlineV1301(pid,sourceV1301 := "")
{
    global portalBuffV85,coordRouteV16,lastAttackPendingV20
    rV1301 := portalBuffV85
    if (!IsObject(rV1301))
        return false
    if (rV1301.pid!=pid || rV1301.route!=coordRouteV16)
    {
        portalBuffV85 := false
        PortalLogWriteV66("PORTAL_BUFF_STALE_CLEAR source=" . sourceV1301
            . " old_pid=" . rV1301.pid . " new_pid=" . pid)
        return true
    }
    if (!rV1301.HasKey("startTickV1301") || rV1301.startTickV1301<=0)
        rV1301.startTickV1301 := A_TickCount
    elapsedV1301 := A_TickCount-rV1301.startTickV1301
    if (elapsedV1301>=0 && elapsedV1301<5000)
        return false
    ; Neu qua 5s: nha pending buff, giu route main Farm tiep tuc.
    ; Luong farm hien co se tu xu ly CHECK/MOVE tai dong dang dung.
    phaseV1301 := rV1301.phase
    portalBuffV85 := false
    lastAttackPendingV20 := false
    PortalLogWriteV66("PORTAL_BUFF_TIMEOUT_5S pid=" . pid . " phase=" . phaseV1301
        . " elapsed_ms=" . elapsedV1301 . " source=" . sourceV1301
        . " result=UNLOCK_CONTINUE_FARM")
    return true
}

; Buff farm theo thu tu FORM THUC: 1 (set phu/ve set chinh),
; 3 (kiem tra thieu), 5 (chon va click phai), 6 (chi chon skill danh).
; Giữ nguyên thoi diem buff mo cong o diem N+1 cua B->C.
FarmPortalBuffTickV85(h,player,pid)
{
    global portalBuffV85,coordRouteV16,autoMonsterAttackOn,pestiPointPendingV28
    global xRunning,zRunning,gameItemActionOwner,lastAttackPendingV20,farmPortalBuffActiveDeadlineV1301
    r := portalBuffV85
    if (!IsObject(r))
        return false
    if (!autoMonsterAttackOn || r.pid!=pid || r.route!=coordRouteV16)
    {
        portalBuffV85 := false
        return false
    }
    if (FarmPortalBuffDeadlineV1301(pid,"BUFF_TICK"))
        return false
    if (xRunning || zRunning || gameItemActionOwner!="" || !NativeDispatchReadyV10(true)
        || D2GetActiveGamePidV95()!=pid || !AutoMonsterPacketCleanupV1())
        return true
    ; Limit actual key/cast waits to the same deadline as the Farm route watchdog.
    farmPortalBuffActiveDeadlineV1301 := r.startTickV1301 + 5000
    try
    {
    if (r.phase="FORM1")
    {
        if (!FarmBuffForm1V906(pid))
            return true
        pestiPointPendingV28 := false
        r.phase := "FORM3"
        return true
    }
    if (r.phase="FORM3")
    {
        if (!FarmBuffThreeRowsV519(h,player,pid))
            return true
        r.phase := "FORM5"
        return true
    }
    if (r.phase="FORM5")
    {
        if (!FarmBuffForm5V906())
            return true
        r.phase := "FORM6"
        return true
    }
    if (r.phase="FORM6")
    {
        if (!FarmBuffForm6SelectV906())
            return true
        if (portalBuffV85=r)
            portalBuffV85 := false
        lastAttackPendingV20 := false
        ResetAfterQuickBuff()
        AutoMonsterAttackLogV2("PORTAL_BUFF_DONE sequence=FORM1_FORM3_FORM5_FORM6")
        return true
    }
    PortalLogWriteV66("PORTAL_BUFF_INVALID_PHASE phase=" . r.phase)
    r.phase := "FORM1"
    return true
    }
    finally
        farmPortalBuffActiveDeadlineV1301 := 0
}

FarmBuffForm1V906(pid)
{
    global zSetKey,zSetDelay,zFKey,zFKey2,zDelay1,zDelay2,xRunning,buffSetBaselineV500
    if (xRunning || !IsGameActive() || D2GetActiveGamePidV95()!=pid)
        return false
    FarmSkillBaselineEnsureV621(pid)
    original := buffSetBaselineV500
    switched := false,done := true,returned := true
    xRunning := true
    try
    {
        if (QuickBuffHasKey(zSetKey))
        {
            if (!QuickBuffSend(zSetKey))
                done := false
            else
            {
                switched := true
                done := QuickBuffWait(zSetDelay)
            }
        }
        try
        {
            if (done && QuickBuffHasKey(zFKey))
                done := QuickBuffCast(zFKey,zDelay1)
            if (done && QuickBuffHasKey(zFKey2))
                done := QuickBuffCast(zFKey2,zDelay2)
        }
        finally
        {
            if (switched)
            {
                returned := IsGameActive() && D2GetActiveGamePidV95()=pid
                    && BuffSetReturnV500(zSetKey,zSetDelay)
                ; BuffSetReturnV500 co nhanh timeout tra true: phai doc lai set chinh.
                if (returned && IsObject(original) && original.pid=pid && original.left>=0)
                {
                    current := FarmSkillPairCaptureV620(pid)
                    returned := IsObject(current) && current.left=original.left
                }
                else
                    returned := false
                AutoMonsterAttackLogV2("BUFF_FORM1_RETURN_MAIN_SET verified=" . returned)
            }
        }
    }
    finally
        xRunning := false
    return done && returned
}

FarmBuffForm5V906()
{
    global clickCastRows,xRunning
    if (xRunning || !IsGameActive())
        return false
    xRunning := true
    try
    {
        rows := []
        for _,row in clickCastRows
            rows.Push({key:row.key,delay:row.delay,source:row})
        for _,row in rows
        {
            if (!QuickBuffHasKey(row.key))
                continue
            if (!QuickBuffCast(row.key,row.delay))
                return false
            row.source.last := A_TickCount
        }
        return true
    }
    finally
        xRunning := false
}

FarmBuffForm6SelectV906()
{
    global form6KeyV716,xRunning
    if (xRunning || !IsGameActive())
        return false
    if (!QuickBuffHasKey(form6KeyV716))
        return true
    xRunning := true
    try
        return QuickBuffSend(form6KeyV716) ; CHI chon, khong click phai.
    finally
        xRunning := false
}

LastAttackSkillV20()
{
    global FKey1,FKey2,FKey3,FKey4,FKey5
    key := ""
    Loop, 4
    {
        i := A_Index
        if (!QuickBuffHasKey(FKey%i%))
            break
        key := FKey%i%
    }
    return key="" ? true : QuickBuffSend(key)
}


MapEntryFirstBuffFinishV248(r,ctx,player,level,px,py,requireDestination := true)
{
    global scosEntryV162,mapStage1BuffDoneV248,mapFarmStartPendingV170
    if (scosEntryV162!=r)
        return false
    if (requireDestination && (r.map="SCOS" || r.map="") && (px-5958)**2+(py-11317)**2>4)
        return false
    mapStage1BuffDoneV248 := {pid:r.pid,map:r.map,level:level,x:px,y:py,buffDone:false,beforeFinalBuffV718:r.beforeFinalBuffV718}
    PortalLogWriteV66("MAP_STAGE1_COMPLETE map=" . r.map . " level=" . level . " reason=ENTRY_DESTINATION_REACHED next=STAGE2 no_route_load=1")
    PortalLogWriteV66("MAP_STAGE1_COMPLETE map=" . r.map . " level=" . level . " reason=ENTRY_DESTINATION_REACHED next=STAGE2 no_route_load=1")
    ScosEntryStopV162("STAGE1_DESTINATION_REACHED")
    PickupEnabledSetV71(false,true,false)
    MapStageSetV185(2)
    mapFarmStartPendingV170 := true
    SetTimer, MapFarmStartV170, -1
    return true
}

ScosEntryBuffReadyV233(pid)
{
    global scosEntryV162,mapStage1BuffDoneV248
    r := scosEntryV162
    if (IsObject(r) && r.pid=pid
        && (r.beforeFinalBuffActiveV718 || r.phase="ENTRY_BUFF" || (r.map="BO" && r.phase="LOAD" && !r.buffDoneV413))
        && BackgroundValidV63() && D2GetActiveGamePidV95()=pid)
        return true
    t := mapStage1BuffDoneV248
    return IsObject(t) && !t.buffDone && t.pid=pid
        && BackgroundValidV63() && D2GetActiveGamePidV95()=pid
}

FarmFinalEntryPreparedV718(state,pid,level)
{
    global farmRunEpochV535
    if (!IsObject(state))
        return false
    prepared := state.beforeFinalBuffV718
    if (!IsObject(prepared) || !prepared.ready || prepared.pid!=pid
        || prepared.epoch!=farmRunEpochV535 || !level || level=prepared.source)
        return false
    if (prepared.destination)
        return level=prepared.destination
    return prepared.owner="BO" || FarmNormalFinalMapV577(prepared.owner,level)
}

FarmBeforeFinalEntryV718(r,h,player,level,destination := 0)
{
    global scosEntryV162,farmRunEpochV535
    if (!IsObject(r) || scosEntryV162!=r)
        return true
    owner := r.map,needed := false
    if (owner="SCOS")
        needed := level=241 && destination=270
    else if (owner="NAO")
        needed := level=109 && r.phase="PORTAL_WAIT"
    else if (MapScrollFarmV269(owner))
        needed := level=103 && r.phase="PORTAL_WAIT"
    else if (owner="BO")
        needed := r.boStageV413=3 && r.phase="PORTAL"
    else if (owner="CAIN")
    {
        needed := level=184
        if (needed)
            destination := 185
    }
    else
    {
        plan := FarmMapPlanV10(owner,level)
        if (!destination && IsObject(plan))
            destination := plan.next
        finalPlan := destination ? FarmMapPlanV10(owner,destination) : false
        needed := IsObject(finalPlan) && finalPlan.final
    }
    if (!needed)
        return true
    prepared := r.beforeFinalBuffV718
    if (IsObject(prepared) && prepared.ready && prepared.pid=r.pid
        && prepared.epoch=farmRunEpochV535 && prepared.source=level
        && prepared.destination=destination)
        return true
    epoch := farmRunEpochV535
    r.beforeFinalBuffActiveV718 := true
    try
    {
        if (!RouteBuffSequenceV20(h,player,r.pid,false,true) || scosEntryV162!=r
            || epoch!=farmRunEpochV535 || RoomRecordLevelV259(r.pid)!=level)
            return false
        r.beforeFinalBuffV718 := {pid:r.pid,owner:owner,epoch:epoch,source:level
            ,destination:destination,ready:true}
        PortalLogWriteV66("FINAL_ENTRY_BUFF_DONE owner=" . owner . " source=" . level
            . " destination=" . destination . " next=ENTER_NO_ARRIVAL_BUFF")
        return true
    }
    finally
        r.beforeFinalBuffActiveV718 := false
}

RouteBuffSequenceV20(h,player,pid,arrival := false,beforeFinal := false)
{
    global stateBuffKeyV17, deathlordStateV19, xRunning, zRunning, autoMonsterAttackOn, gameItemActionOwner, lastAttackPendingV20
    global farmRunEpochV535,buffSequenceOnV555,farmSkillPairV620,scosEntryV162,mapStage1BuffDoneV248

    liveLevelV718 := RoomRecordLevelV259(pid)
    if (arrival && (FarmFinalEntryPreparedV718(scosEntryV162,pid,liveLevelV718)
        || FarmFinalEntryPreparedV718(mapStage1BuffDoneV248,pid,liveLevelV718)))
        return true
    if (!beforeFinal && FarmTravelNoBuffV670(pid))
        return true

    ; Buff must not start a separate monster scan/attack or return-to-point movement.
    ; The main Farm route handles clearing monsters before the N+1 buff.
    buffEpochV535 := farmRunEpochV535
    dispatchReadyV236 := NativeDispatchReadyV10(true)
    if ((!autoMonsterAttackOn && !buffSequenceOnV555 && !CycCombatReadyV42(pid) && !ScosEntryBuffReadyV233(pid)) || xRunning || zRunning || gameItemActionOwner!="" || !dispatchReadyV236
        || D2GetActiveGamePidV95()!=pid || !AutoMonsterPacketCleanupV1())
    {
        if (ScosEntryBuffReadyV233(pid))
            PortalLogWriteV66("SCOS_ENTRY_BUFF_WAIT reason=" . (!dispatchReadyV236 ? "DISPATCH_GATE" : "ACTION_PID_OR_PACKET_BUSY") . " farm=" . autoMonsterAttackOn . " x=" . xRunning . " z=" . zRunning . " owner=" . gameItemActionOwner . " dispatch_ready=" . dispatchReadyV236,"SCOS_ENTRY_BUFF_WAIT",1000)
        return false
    }
    ; Buff vao map/hoi sinh cung su dung thu tu Form 1 -> 3 -> 5 -> 6.
    if (!FarmBuffForm1V906(pid) || buffEpochV535!=farmRunEpochV535)
        return false
    if (!FarmBuffThreeRowsV519(h,player,pid) || buffEpochV535!=farmRunEpochV535)
        return false
    if (!FarmBuffForm5V906() || buffEpochV535!=farmRunEpochV535)
        return false
    ok := FarmBuffForm6SelectV906() && buffEpochV535=farmRunEpochV535
    if (ok)
        ResetAfterQuickBuff()
    if (ok)
    {
        lastAttackPendingV20 := false
        FarmSetVerifyTrigger()
    }
    return ok
}

FarmBuffThreeRowsV519(h,player,pid)
{
    global stateBuffKeyV17,deathlordStateV19,pestilenceKeyV18,pestilenceStateV19
    global anathemaKeyV518,anathemaStateV518,xRunning,zRunning,gameItemActionOwner
    rows := [{name:"Deathlord",key:stateBuffKeyV17,id:deathlordStateV19}
        ,{name:"Pinnacle",key:pestilenceKeyV18,id:pestilenceStateV19}
        ,{name:"Anathema",key:anathemaKeyV518,id:anathemaStateV518}]
    for _,row in rows
    {
        if (!IsGameActive() || D2GetActiveGamePidV95()!=pid || xRunning || zRunning || gameItemActionOwner!="")
            return false
        if (!QuickBuffHasKey(row.key) || row.id="")
            continue
        state := StateBuffRead124V17(h,player,row.id)
        sent := state=0 ? AutoBuffCastV517(h,player,pid,row.key,row.id) : false
        if (state=0 && !sent)
            return false ; Chua buff duoc thi khong chuyen qua Form 5.
        PortalLogWriteV66("FARM_BUFF_ROW name=" . row.name . " id=" . row.id . " key=" . row.key
            . " state=" . state . " cast=" . sent . " action=" . (state=1 ? "KEEP_ACTIVE" : state<0 ? "SKIP_UNKNOWN" : "KEY_RIGHT_CLICK"))
    }
    return true
}

AutoBuffCastV517(h,player,pid,key,stateId)
{
    global xRunning,zRunning,gameItemActionOwner,sigBusyV147,packetWatchArmedV1,xDelay
    if (!QuickBuffHasKey(key) || !RegExMatch(stateId,"^\d+$") || stateId>4095
        || zRunning || xRunning || sigBusyV147 || packetWatchArmedV1 || gameItemActionOwner!=""
        || D2GetActiveGamePidV95()!=pid || !IsGameActive() || !NativeDispatchReadyV10(true)
        || StateBuffRead124V17(h,player,stateId)!=0 || !AutoMonsterPacketCleanupV1())
        return false
    xRunning := true
    sent := false
    try
    {
        if (!BuffCheckedSendV29(key) || !QuickBuffWait(30) || D2GetActiveGamePidV95()!=pid)
            return false
        state := StateBuffRead124V17(h,player,stateId)
        if (state=0)
        {
            sent := GameTargetBuffSelfClickV454()
            if (sent)
                QuickBuffWait(Max(150,xDelay))
        }
        else if (state=1)
            sent := true
        PortalLogWriteV66("BUFF_ONCE_ROW id=" . stateId . " key=" . key . " state_after_key=" . state
            . " cast=" . sent . " mode=KEY_THEN_RIGHT_CLICK")
        return sent
    }
    finally
    {
        if (IsGameActive() && D2GetActiveGamePidV95()=pid)
            LastAttackSkillV20()
        xRunning := false
    }
}

BuffGetLayoutV19:
buffGetV20 := {until:A_TickCount+60000,baseline:false,pid:0}
GuiControl,, BuffGetResultV19,
SetTimer, BuffGetTimerV20, 250
ToolTipInfoV386("Trở lại game khi chưa có buff rồi bấm một skill buff để lấy ID.")
SetTimer, RemoveToolTip, -3000
return

BuffGetTimerV20:
if (!IsObject(buffGetV20) || A_TickCount>=buffGetV20.until)
{
    buffGetV20 := false
    SetTimer, BuffGetTimerV20, Off
    return
}
if (!IsGameActive() || zRunning || xRunning)
    return
pidV20 := D2GetActiveGamePidV95()
hV20 := pidV20 ? D2OpenProcess(pidV20) : 0
if (!hV20)
    return
try
{
    baseV20 := D2GetModuleBaseV35(pidV20,"D2Client.dll")
    playerV20 := baseV20 ? D2ReadU32(hV20,baseV20+0x11BBFC) : 0
    statesV20 := BuffStatesReadV20(hV20,playerV20)
    if (!IsObject(statesV20))
        return
    if (!IsObject(buffGetV20.baseline) || buffGetV20.pid!=pidV20)
    {
        buffGetV20.baseline := statesV20, buffGetV20.pid := pidV20
        return
    }
        foundV20 := ""
    for idV20,_ in statesV20
        if (!buffGetV20.baseline.HasKey(idV20))
            foundV20 .= (foundV20="" ? "" : ",") . idV20
    if (foundV20!="")
    {
        buffGetTextV22 := foundV20
        GuiControl,, BuffGetResultV19, %foundV20%
        buffGetV20 := false
        SetTimer, BuffGetTimerV20, Off
    }
}
finally
    DllCall("CloseHandle","Ptr",hV20)
return

BuffStatesReadV20(h,player)
{
    if (!player || !MonsterBossProbeReadV1(h,player+0x5C,4,unitStats))
        return false
    root := NumGet(unitStats,0,"UInt")
    if (root<0x10000 || !MonsterBossProbeReadV1(h,root,0x64,b))
        return false
    if (!(NumGet(b,0x10,"UInt") & 0x80000000) || NumGet(b,0x44,"UInt")!=player)
        return false
    flags := NumGet(b,0x58,"UInt")
    if (flags<0x10000)
        return false
    if (!MonsterBossProbeReadV1(h,flags,512,bits))
        return false
    if (!MonsterBossProbeReadV1(h,player+0x5C,4,checkRoot)
        || NumGet(checkRoot,0,"UInt")!=root
        || !MonsterBossProbeReadV1(h,root+0x58,4,checkFlags)
        || NumGet(checkFlags,0,"UInt")!=flags)
        return false
    states := {}
    Loop, 128
    {
        word := NumGet(bits,(A_Index-1)*4,"UInt")
        if (!word)
            continue
        wordIndex := A_Index-1
        Loop, 32
            if (word & (1 << (A_Index-1)))
                states[wordIndex*32 + (A_Index-1)] := true
    }
    return states
}

RouteMapSectionForV656(profile,id,testMode:=-1)
{
    global mapTestModeV656
    if (testMode=-1)
        testMode := mapTestModeV656
    return ProfileSection(profile) . "_RouteMap_" . (testMode ? "Test_" : "") . id
}

RouteMapRegistrySectionV656(profile)
{
    global mapTestModeV656
    return ProfileSection(profile) . (mapTestModeV656 ? "_RouteMap_TestRegistry" : "")
}

MapFileIsTestV656(file)
{
    SplitPath, file,,directory
    return RTrim(directory,"\")=A_ScriptDir . "\Map\Test"
}

MapTestModeChangedV656:
Critical
GuiControlGet, requestedTestModeV656, 1:, MapTestModeCheckV656
if (requestedTestModeV656=mapTestModeV656)
    return
RouteMapsStoreV21(currentProfile)
mapTestModeV656 := requestedTestModeV656=1
if (mapTestModeV656)
    FileCreateDir, % A_ScriptDir . "\Map\Test"
testSectionV656 := ProfileSection(currentProfile)
IniWrite, %mapTestModeV656%, % ProfileConfigPathV364(testSectionV656), %testSectionV656%, MapTestMode
coordMapStateV381 := false, coordMapReadyV381 := false, coordMapAcceptedV381 := false
coordMapReloadV381 := false, coordMapKeepYellowV381 := false
stage2MapFileV14 := "", farmLoadedMapV56 := false
routePreviewV401 := true
coordPinnedYellowV136 := 0, coordYellowRowV350 := 0
RouteMapsLoadV21(currentProfile)
RoomMapsSyncV110(true)
RouteMapRefreshV21(false)
CoordSavedLoadV15(currentProfile)
CoordRouteResetV16()
CoordBoxRefreshV15(true)
FonInfoPushV385(mapTestModeV656 ? "Test mode: dùng Map\Test." : "Đã trở lại danh sách map thường.")
return

RouteMapSectionV21(profile)
{
    global routeMapIdV21
    return RouteMapSectionForV656(profile,routeMapIdV21)
}

RouteMapsLoadV21(profile)
{
    global ConfigFile, routeMapsV21, routeMapIdV21, routeMapNextV21
    MapTownDirectoryPrepareV411()
    section := RouteMapRegistrySectionV656(profile)
    routeMapsV21 := []
    IniRead, count, % ProfileConfigPathV364(section), %section%, RouteMapCount, -1
    if (count=-1 && section!=ProfileSection(profile))
    {
        routeMapIdV21 := 0, routeMapNextV21 := 1
        RouteMapsStoreV21(profile)
        return
    }
    if (count=-1)
    {
        routeMapsV21 := [{id:1,name:"Map Scos"}], routeMapIdV21 := 1, routeMapNextV21 := 2
        dest := RouteMapSectionV21(profile)
        IniRead, oldCount, % ProfileConfigPathV364(section), %section%, CoordSavedCount, 0
        if (!RegExMatch(oldCount,"^\d+$") || oldCount>10000)
            oldCount := 0
        IniWrite, %oldCount%, % ProfileConfigPathV364(dest), %dest%, CoordSavedCount
        Loop, %oldCount%
        {
            key := "CoordSaved" . A_Index
            IniRead, value, % ProfileConfigPathV364(section), %section%, %key%, %A_Space%
            IniWrite, %value%, % ProfileConfigPathV364(dest), %dest%, %key%
        }
        for _,key in ["CoordPoint","CoordLevel"]
        {
            IniRead, value, % ProfileConfigPathV364(section), %section%, %key%, %A_Space%
            IniWrite, %value%, % ProfileConfigPathV364(dest), %dest%, %key%
        }
        RouteMapsStoreV21(profile)
        return
    }
    if (!RegExMatch(count,"^\d+$") || count>1000)
        count := 0
    maxId := 0
    Loop, %count%
    {
        key := "RouteMap" . A_Index . "Id"
        IniRead, id, % ProfileConfigPathV364(section), %section%, %key%, 0
        key := "RouteMap" . A_Index . "Name"
        IniRead, name, % ProfileConfigPathV364(section), %section%, %key%, %A_Space%
        if (RegExMatch(id,"^\d+$") && id>0 && Trim(name)!="")
        {
            routeMapsV21.Push({id:id+0,name:name})
            maxId := Max(maxId,id)
        }
    }
    IniRead, routeMapIdV21, % ProfileConfigPathV364(section), %section%, RouteMapSelected, 0
    valid := false
    for _,map in routeMapsV21
        if (map.id=routeMapIdV21)
            valid := true
    if (!valid)
        routeMapIdV21 := routeMapsV21.Length() ? routeMapsV21[1].id : 0
    IniRead, routeMapNextV21, % ProfileConfigPathV364(section), %section%, RouteMapNextId, 1
    if (!RegExMatch(routeMapNextV21,"^\d+$") || routeMapNextV21<=maxId)
        routeMapNextV21 := maxId+1
}

RouteMapsStoreV21(profile)
{
    global ConfigFile, routeMapsV21, routeMapIdV21, routeMapNextV21
    section := RouteMapRegistrySectionV656(profile), count := routeMapsV21.Length()
    IniRead, oldMapCountV413, % ProfileConfigPathV364(section), %section%, RouteMapCount, 0
    if (RegExMatch(oldMapCountV413,"^\d+$") && oldMapCountV413>count && oldMapCountV413<=1000)
    {
        Loop, % oldMapCountV413-count
        {
            oldMapIndexV413 := count+A_Index
            for _,suffixV413 in ["Id","Name"]
            {
                oldMapKeyV413 := "RouteMap" . oldMapIndexV413 . suffixV413
                IniDelete, % ProfileConfigPathV364(section), %section%, %oldMapKeyV413%
            }
        }
    }
    IniWrite, %count%, % ProfileConfigPathV364(section), %section%, RouteMapCount
    IniWrite, %routeMapIdV21%, % ProfileConfigPathV364(section), %section%, RouteMapSelected
    IniWrite, %routeMapNextV21%, % ProfileConfigPathV364(section), %section%, RouteMapNextId
    for i,map in routeMapsV21
    {
        key := "RouteMap" . i . "Id", value := map.id
        IniWrite, %value%, % ProfileConfigPathV364(section), %section%, %key%
        key := "RouteMap" . i . "Name", value := map.name
        IniWrite, %value%, % ProfileConfigPathV364(section), %section%, %key%
    }
}

RouteMapRefreshV21(scanFiles := true)
{
    global routeMapsV21, routeMapIdV21, routeMapUiBusyV21,currentProfile
    if (scanFiles)
        RoomMapsSyncV110()
    routeMapUiBusyV21 := true
    text := "|", selected := 0
    for i,map in routeMapsV21
    {
        previewFileV401 := RoomProfileFileV108(currentProfile,map.id)
        if (!MapRouteFileInScopeV408(previewFileV401))
        {
            text .= (i=1 ? "" : "|") . map.name
            if (map.id=routeMapIdV21)
                selected := i
            continue
        }
        ; V851: The map picker is for recognizing layouts, not counting route steps.
        ; Only HASH levels need a count: stable HASH / original HASH maximum.
        previewLevelV851 := MapRouteHintV400(previewFileV401)
        suffixV401 := ""
        if (previewLevelV851=39 || previewLevelV851=183 || previewLevelV851=184)
        {
            previewHashV851 := BoHashReadV830(previewFileV401,previewLevelV851)
            if (IsObject(previewHashV851))
                suffixV401 := " [H" . previewHashV851.hashes.Length() . "/" . previewHashV851.max . "]"
            else
                suffixV401 := " [chưa HASH]"
        }
        text .= (i=1 ? "" : "|") . map.name . suffixV401
        if (map.id=routeMapIdV21)
            selected := i
    }
    GuiControl, 1:, RouteMapSelectV21, %text%
    if (selected)
        GuiControl, 1:Choose, RouteMapSelectV21, %selected%
    routeMapUiBusyV21 := false
}

RouteMapActivateV21(id)
{
    global routeMapIdV21, currentProfile, coordPointTextV14, coordPointLevelV14, coordNearbyRowV18, coordInsertAnchorV57
    global farmMapPauseV52,routePreviewV401
    routePreviewV401 := true
    if (IsObject(farmMapPauseV52) && farmMapPauseV52.mapId!=id)
        FarmPauseReleaseV256("USER_SELECTED_ROUTE_FILE")
    routeMapIdV21 := id
    coordPointTextV14 := "", coordPointLevelV14 := 0
    coordNearbyRowV18 := 0, coordInsertAnchorV57 := false
    CoordSavedLoadV15(currentProfile)
    CoordRouteResetV16()
    RouteMapsStoreV21(currentProfile)
    RouteMapRefreshV21()
    CoordBoxRefreshV15(true)
    return true
}

RouteMapSelectV21:
if (routeMapUiBusyV21)
    return
GuiControlGet, startGd4V726, 1:, RecoveryStartTestV537
if (IsObject(roomRecordV108))
{
    RouteMapRefreshV21()
    ToolTipInfoV386("Dừng lưu phòng hoặc ghi chèn trước khi đổi map.")
    SetTimer, RemoveToolTip, -2500
    return
}
if (autoMonsterAttackOn && !startGd4V726)
{
    RouteMapRefreshV21()
    ToolTipInfoV386("Tắt Auto đánh trước khi đổi map.")
    SetTimer, RemoveToolTip, -2000
    return
}
GuiControlGet, mapChoiceV21,, RouteMapSelectV21
if (mapChoiceV21>=1 && mapChoiceV21<=routeMapsV21.Length())
{
    CoordSavedStoreV15(currentProfile)
    RouteMapActivateV21(routeMapsV21[mapChoiceV21].id)
    if (startGd4V726)
        FarmStartForcedV702("SCOS")
}
return

RouteMapAddV21:
FonEditBeginV414()
try
{
if (IsObject(roomRecordV108))
{
    ToolTipInfoV386("Dừng lưu phòng trước khi thêm map.")
    SetTimer, RemoveToolTip, -2000
    return
}
if (autoMonsterAttackOn)
{
    ToolTipInfoV386("Tắt Auto đánh trước khi thêm map.")
    SetTimer, RemoveToolTip, -2000
    return
}
autoMapPidV22 := CoordDisplayGamePidV1()
autoMapLevelV22 := autoMapPidV22 ? RoomRecordLevelV259(autoMapPidV22) : 0
if (!autoMapLevelV22)
    autoMapLevelV22 := coordPointLevelV14+0
RoomMapsSyncV110(true,autoMapLevelV22)
autoMapButtonV22 := RoomMapButtonNameV22(autoMapLevelV22)
mapBaseNameV294 := autoMapButtonV22 . "-Map" . autoMapLevelV22
mapNameV21 := RoomMapNamedNumberV293(mapBaseNameV294)
CoordSavedStoreV15(currentProfile)
newMapIdV21 := routeMapNextV21++
routeMapsV21.Push({id:newMapIdV21,name:mapNameV21})
newMapSectionV21 := RouteMapSectionForV656(currentProfile,newMapIdV21)
IniWrite, 0, % ProfileConfigPathV364(newMapSectionV21), %newMapSectionV21%, CoordSavedCount
newRoomMapDirectoryV408 := MapRouteDirectoryV408(autoMapButtonV22,autoMapLevelV22)
newRoomMapFileV110 := newRoomMapDirectoryV408 . "\" . mapNameV21 . ".ini"
if (FileExist(newRoomMapFileV110))
{
    routeMapsV21.Pop(), routeMapNextV21 := newMapIdV21
    MsgBox, 48, Thêm map, File map cùng tên đã có. Chọn map đó để lưu tiếp.
    return
}
FileCreateDir, %newRoomMapDirectoryV408%
IniWrite, %mapNameV21%, %newRoomMapFileV110%, Map, Name
if (ErrorLevel)
{
    routeMapsV21.Pop(), routeMapNextV21 := newMapIdV21
    MsgBox, 48, Thêm map, Không tạo được file trong thư mục Map.
    return
}
IniWrite, %mapBaseNameV294%, %newRoomMapFileV110%, Map, RecordBaseName
IniWrite, 1, %newRoomMapFileV110%, Map, AutoName
IniWrite, %autoMapButtonV22%, %newRoomMapFileV110%, Map, AutoButton
IniWrite, %autoMapLevelV22%, %newRoomMapFileV110%, Map, AutoLevel
if (RegExMatch(mapNameV21,"-(\d+)$",recordNumberV294))
    IniWrite, %recordNumberV2941%, %newRoomMapFileV110%, Map, RecordNumber
IniWrite, %newRoomMapFileV110%, % ProfileConfigPathV364(newMapSectionV21), %newMapSectionV21%, RoomMapFile
RouteMapActivateV21(newMapIdV21)
return

}
finally
    FonEditEndV414()

RouteMapDeleteV21:
; V843: never delete a saved map through GUI.
ToolTipInfoV386("XÓA MAP đã bị vô hiệu hóa; INI được giữ nguyên.")
SetTimer, RemoveToolTip, -2500
return

RouteMapReloadV843:
; Keep V68 synchronization, only perform a fresh read from disk.
RoomMapsSyncV110(true,coordCurrentLevelV400,true)
RouteMapRefreshV21(false)
if (routeMapIdV21)
    CoordSavedLoadV15(currentProfile)
CoordBoxRefreshV15(true)
ToolTipInfoV386("Đã đọc lại INI từ đĩa; không xóa file.")
SetTimer, RemoveToolTip, -2500
return

TownGetV22:
zoneGetV22 := {control:"TownLevelInputV22",until:A_TickCount+30000,profile:currentProfile,pid:CoordDisplayGamePidV1()}
ToolTipInfoV386("Đang đọc ID khu vực TRONG thành từ game.")
SetTimer, RemoveToolTip, -3000
SetTimer, ZoneGetTimerV22, 250
Gosub, ZoneGetTimerV22
return

OutsideGetV22:
zoneGetV22 := {control:"OutsideLevelInputV22",until:A_TickCount+30000,profile:currentProfile,pid:CoordDisplayGamePidV1()}
ToolTipInfoV386("Đang đọc ID khu vực NGOÀI thành từ game.")
SetTimer, RemoveToolTip, -3000
SetTimer, ZoneGetTimerV22, 250
Gosub, ZoneGetTimerV22
return

ZoneGetTimerV22:
if (!IsObject(zoneGetV22) || A_TickCount>=zoneGetV22.until || zoneGetV22.profile!=currentProfile)
{
    zoneGetV22 := false
    SetTimer, ZoneGetTimerV22, Off
    return
}
if (!zoneGetV22.pid)
    zoneGetV22.pid := CoordDisplayGamePidV1()
zonePidV22 := zoneGetV22.pid
zoneHV22 := zonePidV22 ? D2OpenProcess(zonePidV22) : 0
if (!zoneHV22)
    return
try
{
    zoneBaseV22 := D2GetModuleBaseV35(zonePidV22,"D2Client.dll")
    zonePlayerV22 := zoneBaseV22 ? D2ReadU32(zoneHV22,zoneBaseV22+0x11BBFC) : 0
    zonePathV22 := zonePlayerV22 ? D2ReadU32(zoneHV22,zonePlayerV22+0x2C) : 0
    zoneIdV22 := zonePathV22 ? CoordLevelV14(zoneHV22,D2ReadU32(zoneHV22,zonePathV22+0x1C)) : 0
    if (!zoneIdV22)
        return
    zoneControlV22 := zoneGetV22.control
    if (zoneControlV22="TownLevelInputV22" && KnownFarmLevelV522(zoneIdV22))
    {
        ToolTipInfoV386("Đang ở map farm " . zoneIdV22 . "; về thành rồi GET mục Trong thành.")
        SetTimer, RemoveToolTip, -3500
        zoneGetV22 := false
        SetTimer, ZoneGetTimerV22, Off
        return
    }
    GuiControl,, %zoneControlV22%, %zoneIdV22%
    zoneSectionV22 := ProfileSection(currentProfile)
    if (zoneControlV22="TownLevelInputV22")
    {
        townLevelV22 := zoneIdV22
        IniWrite, %townLevelV22%, % ProfileConfigPathV364(zoneSectionV22), %zoneSectionV22%, TownLevelID
    }
    else
    {
        outsideLevelV22 := zoneIdV22
        IniWrite, %outsideLevelV22%, % ProfileConfigPathV364(zoneSectionV22), %zoneSectionV22%, OutsideLevelID
    }
    ToolTipInfoV386("Đã lấy ID khu vực: " . zoneIdV22 . " - đã lưu vào profile.")
    SetTimer, RemoveToolTip, -3000
    zoneGetV22 := false
    SetTimer, ZoneGetTimerV22, Off
}
finally
    DllCall("CloseHandle","Ptr",zoneHV22)
return


PickupHexTextV25(value)
{
    value := Trim(value)
    StringUpper, value, value
    if (!RegExMatch(value,"^[0-9A-F]{1,2}$"))
        return ""
    return StrLen(value)=1 ? "0" . value : value
}

PickupStashHotkeyV14:
PickupChooseGroupV26("0")
return
PickupSetHotkeyV14:
PickupChooseGroupV26("5")
return
PickupSUHotkeyV14:
PickupChooseGroupV26("7")
return

PickupGroupKeysChangedV14:
GuiControlGet, stashKeyV14,, PickupStashKeyInputV14
GuiControlGet, setKeyV14,, PickupSetKeyInputV14
GuiControlGet, suKeyV14,, PickupSUKeyInputV14
stashKeyV14 := NormalizeMapHotkeyV178(stashKeyV14)
setKeyV14 := NormalizeMapHotkeyV178(setKeyV14)
suKeyV14 := NormalizeMapHotkeyV178(suKeyV14)
if ((stashKeyV14!="" && (stashKeyV14=setKeyV14 || stashKeyV14=suKeyV14)) || (setKeyV14!="" && setKeyV14=suKeyV14))
    return
pickupStashKeyV14 := stashKeyV14, pickupSetKeyV14 := setKeyV14, pickupSUKeyV14 := suKeyV14
PickupGroupBindV14()
sectionV14 := ProfileSection(currentProfile)
IniWrite, %pickupStashKeyV14%, % ProfileConfigPathV364(sectionV14), %sectionV14%, PickupStashKey
IniWrite, %pickupSetKeyV14%, % ProfileConfigPathV364(sectionV14), %sectionV14%, PickupSetKey
IniWrite, %pickupSUKeyV14%, % ProfileConfigPathV364(sectionV14), %sectionV14%, PickupSUKey
return

PickupGroupBindV14()
{
    global pickupStashKeyV14,pickupSetKeyV14,pickupSUKeyV14
    static previous := []
    labels := ["PickupStashHotkeyV14","PickupSetHotkeyV14","PickupSUHotkeyV14"]
    for i,key in previous
        if (key!="")
            BackgroundHotkeyV63("$" . key,labels[i],"Off UseErrorLevel")
    previous := [pickupStashKeyV14,pickupSetKeyV14,pickupSUKeyV14]
    for i,key in previous
        if (key!="")
            BackgroundHotkeyV63("$" . key,labels[i],"On UseErrorLevel")
}

RareWarningGetButtonV14:
if (!sigBusyV147 && !packetWatchArmedV1 && !xRunning && PickupActivateGameV13())
    GetNearestGroundItemV83(false)
return

PickupButton0V146:
PickupChooseGroupV26("0",true)
return

PickupButton5V146:
PickupChooseGroupV26("5",true)
return

PickupButton7V146:
PickupChooseGroupV26("7",true)
return
PickupCtrlEndV26()
{
    global pickupOneShotV216, pickupGroupActiveV26, pickupDestinationV119, pickupGroupOnlyV26
    pickupOneShotV216 := false
    pickupGroupActiveV26 := false
    pickupDestinationV119 := ""
    pickupGroupOnlyV26 := ""
}

PickupChooseGroupV26(number,fromGuiV146 := false)
{
    global pickupGroupOnlyV26,pickupDestinationV119,pickupAllow,pickupImageOn,pickupRoundResetV1,pickupLastClick,xRunning,zRunning
    global currentProfile,ConfigFile,pickupBackgroundV181,sigBusyV147
    global currentProfile,ConfigFile,pickupBackgroundV181,sigBusyV147
    global packetWatchArmedV1,pickupOneShotV216,pickupGroupActiveV26
    if (sigBusyV147 || packetWatchArmedV1 || xRunning || zRunning || !PickupActivateGameV13())
        return
    pickupBackgroundV181 := true
    if (packetWatchArmedV1 || xRunning || zRunning || (number!="0" && number!="5" && number!="7"))
        return
    quality := number="5" ? "05" : (number="7" ? "07" : "")
    PickupReloadRAMV97()
    pickupGroupOnlyV26 := quality, pickupDestinationV119 := number="0" ? "STASH" : "CUBE"
    pickupGroupActiveV26 := true, pickupRoundResetV1 := true, pickupLastClick := 0
    pickupOneShotV216 := true
    SetTimer, PickupImageTimer, 20
    ToolTipInfoV386(number="0" ? "NHẶT ĐỒ VÀO RƯƠNG (1 LẦN)" : (number="5" ? "NHẶT SET VÀO CUBE (1 LẦN)" : "NHẶT SU VÀO CUBE (1 LẦN)"))
    SetTimer, RemoveToolTip, -2500
}

QuickBuffAllowedV27(key,skipToggleKey)
{
    return QuickBuffHasKey(key) && (skipToggleKey="" || !CastKeysMatch(key,skipToggleKey))
}

DeathlordKeyAllowedV29(key)
{
    global stateBuffKeyV17, deathlordStateV19
    if (stateBuffKeyV17="" || !CastKeysMatch(key,stateBuffKeyV17))
        return true
    if (deathlordStateV19="" || !IsGameActive())
        return false
    pid := D2GetActiveGamePidV95()
    h := pid ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        base := D2GetModuleBaseV35(pid,"D2Client.dll")
        player := base ? D2ReadU32(h,base+0x11BBFC) : 0
        state := player ? StateBuffRead124V17(h,player,deathlordStateV19) : -1
        DebugTraceWrite("character","DEATHLORD_CHECK id=" . deathlordStateV19 . " state=" . state . " send=" . (state=0 ? 1 : 0))
        return state=0
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

DeathlordPressGateV87(key)
{
    global stateBuffKeyV17
    static lastPid := 0, lastBirth := "", lastPress := 0
    if (stateBuffKeyV17="" || !CastKeysMatch(key,stateBuffKeyV17))
        return true
    previousCritical := A_IsCritical
    Critical, On
    try
    {
        pid := D2GetActiveGamePidV95(), birth := pid ? BackgroundBirthV63(pid) : ""
        if (!pid || (pid=lastPid && birth=lastBirth && lastPress && A_TickCount-lastPress<2000))
            return false
        if (!DeathlordKeyAllowedV29(key))
            return false
        lastPid := pid, lastBirth := birth, lastPress := A_TickCount
        DebugTraceWrite("character","DEATHLORD_PRESS_GATE pid=" . pid . " state=MISSING presses=1 min_gap_ms=2000")
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

BuffCheckedSendV29(key)
{
    if (!FarmAttackReleaseWaitV15())
        return false
    if (!DeathlordKeyAllowedV29(key))
        return false
    global portalCastKeyV50
    if (key!=portalCastKeyV50)
        return GameTargetKeyV63("{" . key . "}")
    pid := D2GetActiveGamePidV95(),base := pid ? D2GetModuleBaseV35(pid,"D2Client.dll") : 0
    h := base ? D2OpenProcess(pid) : 0
    if (!h)
        return false
    try
    {
        player := D2ReadU32(h,base+0x11BBFC)
        if (!player || !FarmPortalRecordV725(pid,h,player,"CAST"))
            return false
        sent := GameTargetKeyV63("{" . key . "}")
        if (!sent)
            FarmPortalRecordV725(pid,h,player,"CANCEL_CAST")
        return sent
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}


FarmSkillPairCaptureV620(pid)
{
    if (!pid)
        return false
    h := D2OpenProcess(pid)
    if (!h)
        return false
    try
    {
        base := D2GetModuleBaseV35(pid,"D2Client.dll")
        player := base ? D2ReadU32(h,base+0x11BBFC) : 0
        if (!player)
            return false
        info := D2ReadU32(h,player+0xA8)
        if (!info)
            return false
        leftId := -1,rightId := -1
        leftPtr := D2ReadU32(h,info+8)
        if (leftPtr && MonsterBossProbeReadV1(h,leftPtr,4,b))
        {
            row := NumGet(b,0,"UInt")
            if (row && MonsterBossProbeReadV1(h,row,2,b))
                leftId := NumGet(b,0,"UShort")
        }
        rightPtr := D2ReadU32(h,info+12)
        if (rightPtr && MonsterBossProbeReadV1(h,rightPtr,4,b))
        {
            row := NumGet(b,0,"UInt")
            if (row && MonsterBossProbeReadV1(h,row,2,b))
                rightId := NumGet(b,0,"UShort")
        }
        return {pid:pid,left:leftId,right:rightId,needsCheck:false,phase:"",phaseStartAt:0,lastActionAt:0}
    }
    finally
        DllCall("CloseHandle","Ptr",h)
}

FarmSetVerifyTrigger()
{
    return
}


BuffSetReturnV500(key,delay)
{
    global buffSetBaselineV500,buffSetLeftOKV621,farmRunEpochV535
    pid := D2GetActiveGamePidV95(),epoch := farmRunEpochV535
    FarmSkillBaselineEnsureV621(pid)
    c := buffSetBaselineV500,buffSetLeftOKV621 := false
    if (!IsGameActive() || !BuffCheckedSendV29(key))
        return false
    started := A_TickCount,waitMs := Max(10,delay)
    while (A_TickCount-started<10000)
    {
        remaining := 10000-(A_TickCount-started)
        if (epoch!=farmRunEpochV535 || !QuickBuffWait(Min(waitMs,remaining)) || D2GetActiveGamePidV95()!=pid)
            return false
        current := FarmSkillPairCaptureV620(pid)
        if (!IsObject(c) || c.pid!=pid || c.left<0)
            return true
        if (IsObject(current) && current.left>=0)
        {
            if (current.left=c.left)
            {
                buffSetLeftOKV621 := true
                AutoMonsterAttackLogV2("BUFF_LEFT_VERIFIED expected=" . c.left . " elapsed_ms=" . (A_TickCount-started))
                return true
            }
            if (A_TickCount-started<10000)
                BuffCheckedSendV29(key)
        }
    }
    AutoMonsterAttackLogV2("BUFF_LEFT_TIMEOUT limit_ms=10000 next=BUFF_456_CONTINUE")
    return true
}

BuffSetFixRightV500(fixKey2:="",fixKey1:="")
{
    global buffSetBaselineV500,xDelay,farmRunEpochV535
    global FKey1,FKey2,FKey3,FKey4,FKey5
    pid := D2GetActiveGamePidV95(),epoch := farmRunEpochV535,c := buffSetBaselineV500
    if (!IsObject(c) || c.pid!=pid || c.right<0)
        return true
    lastF := ""
    Loop, 4
    {
        i := A_Index
        if (!QuickBuffHasKey(FKey%i%))
            break
        lastF := FKey%i%
    }
    if (lastF="")
        return true
    started := A_TickCount,waitMs := Max(10,xDelay)
    while (A_TickCount-started<10000)
    {
        if (epoch!=farmRunEpochV535 || !IsGameActive() || D2GetActiveGamePidV95()!=pid || !BuffSequenceContinueV555())
            return false
        current := FarmSkillPairCaptureV620(pid)
        if (IsObject(current) && current.left=c.left && current.right>=0)
        {
            if (current.right=c.right)
            {
                AutoMonsterAttackLogV2("BUFF_RIGHT_VERIFIED expected=" . c.right . " elapsed_ms=" . (A_TickCount-started))
                return true
            }
            BuffCheckedSendV29(lastF)
        }
        remaining := 10000-(A_TickCount-started)
        if (remaining<=0)
            break
        if (!QuickBuffWait(Min(waitMs,remaining)))
            return false
    }
    AutoMonsterAttackLogV2("BUFF_RIGHT_TIMEOUT limit_ms=10000 next=FARM_CONTINUE")
    return true
}

FarmBuffResumeVerifiedV621()
{
    global autoMonsterAttackOn,farmBuffModeV509,master456Paused,farmStopMoveV124,stage2StartPendingV381
    global stageTwoV166,sigTownV148,sigBusyV147
    if (IsObject(stageTwoV166) || IsObject(sigTownV148) || sigBusyV147)
        return
    autoMonsterAttackOn := true,farmBuffModeV509 := 1,master456Paused := false
    farmStopMoveV124 := false
    SetTimer, FarmStopMoveTimerV124, Off
    SetTimer, AutoMonsterAttackTimer, 250
    FarmCastSyncV88(Stage2FightEnabledV9())
    AutoMonsterAttackLogV2("BUFF_COMPLETE combat=ON cast4=ON verification_gate=RELEASED")
}

FarmSkillBaselineEnsureV621(pid,force:=false)
{
    global buffSetBaselineV500,currentProfile
    if (!pid)
        return false
    birth := BackgroundBirthV63(pid)
    c := buffSetBaselineV500
    if (!force && IsObject(c) && c.pid=pid && c.birth=birth && c.profile=currentProfile && c.left>=0 && c.right>=0)
        return true
    c := FarmSkillPairCaptureV620(pid)
    if (!IsObject(c) || c.left<0 || c.right<0)
        return false
    c.birth := birth,c.profile := currentProfile
    buffSetBaselineV500 := c
    AutoMonsterAttackLogV2("SKILL_PAIR_BASELINE source=" . (force ? "STOP" : "FIRST_START") . " left=" . c.left . " right=" . c.right)
    return true
}

AutoBuffEnsureV513(h,player,pid)
{
    firstPending := DeathlordEnsureV31(h,player,pid)
    secondPending := PestilenceEnsureV513(h,player,pid)
    thirdPending := AnathemaEnsureV518(h,player,pid)
    return firstPending || secondPending || thirdPending
}

PestilenceEnsureV513(h,player,pid)
{
    global pestilenceKeyV18,pestilenceStateV19, anathemaStateV518, anathemaKeyV518
    global autoMonsterAttackOn,xRunning,zRunning,gameItemActionOwner
    static lastPid := 0,lastPlayer := 0,lastId := "",lastKey := "",missingAt := 0,retryAt := 0
    if (lastPid!=pid || lastPlayer!=player || lastId!=pestilenceStateV19 || lastKey!=pestilenceKeyV18)
    {
        lastPid := pid,lastPlayer := player,lastId := pestilenceStateV19,lastKey := pestilenceKeyV18
        missingAt := 0,retryAt := 0
    }
    if ((!autoMonsterAttackOn && !CycCombatReadyV42(pid) && !ScosEntryBuffReadyV233(pid))
        || !QuickBuffHasKey(pestilenceKeyV18) || pestilenceStateV19="")
        return false
    state := StateBuffRead124V17(h,player,pestilenceStateV19)
    if (state=1)
    {
        missingAt := 0,retryAt := 0
        return false
    }
    if (state<0)
    {
        missingAt := 0
        return false
    }
    if (!missingAt)
    {
        missingAt := A_TickCount
        return false
    }
    if (A_TickCount-missingAt<250 || (retryAt && A_TickCount-retryAt<2000))
        return false
    if (xRunning || zRunning || gameItemActionOwner!="" || !IsGameActive()
        || D2GetActiveGamePidV95()!=pid || !NativeDispatchReadyV10(true) || !AutoMonsterPacketCleanupV1())
        return false
    if (StateBuffRead124V17(h,player,pestilenceStateV19)!=0)
        return false
    retryAt := A_TickCount
    sent := AutoBuffCastV517(h,player,pid,pestilenceKeyV18,pestilenceStateV19)
    DebugTraceWrite("character","PINNACLE_RETRY id=" . pestilenceStateV19 . " state=MISSING sent=" . sent
        . " retry_ms=2000 source=LIVE_STATE_BITS wait_blocks_farm=0 until=STATE_PRESENT")
    return sent ? true : false
}

AnathemaEnsureV518(h,player,pid)
{
    global anathemaKeyV518,anathemaStateV518
    global autoMonsterAttackOn,xRunning,zRunning,gameItemActionOwner
    static lastPid := 0,lastPlayer := 0,lastId := "",lastKey := "",missingAt := 0,retryAt := 0
    if (lastPid!=pid || lastPlayer!=player || lastId!=anathemaStateV518 || lastKey!=anathemaKeyV518)
    {
        lastPid := pid,lastPlayer := player,lastId := anathemaStateV518,lastKey := anathemaKeyV518
        missingAt := 0,retryAt := 0
    }
    if ((!autoMonsterAttackOn && !CycCombatReadyV42(pid) && !ScosEntryBuffReadyV233(pid))
        || !QuickBuffHasKey(anathemaKeyV518) || anathemaStateV518="")
        return false
    state := StateBuffRead124V17(h,player,anathemaStateV518)
    if (state=1)
    {
        missingAt := 0,retryAt := 0
        return false
    }
    if (state<0)
    {
        missingAt := 0
        return false
    }
    if (!missingAt)
    {
        missingAt := A_TickCount
        return false
    }
    if (A_TickCount-missingAt<250 || (retryAt && A_TickCount-retryAt<2000))
        return false
    if (xRunning || zRunning || gameItemActionOwner!="" || !IsGameActive()
        || D2GetActiveGamePidV95()!=pid || !NativeDispatchReadyV10(true) || !AutoMonsterPacketCleanupV1())
        return false
    if (StateBuffRead124V17(h,player,anathemaStateV518)!=0)
        return false
    retryAt := A_TickCount
    sent := AutoBuffCastV517(h,player,pid,anathemaKeyV518,anathemaStateV518)
    DebugTraceWrite("character","ANATHEMA_RETRY id=" . anathemaStateV518 . " state=MISSING sent=" . sent
        . " retry_ms=2000 source=LIVE_STATE_BITS wait_blocks_farm=0 until=STATE_PRESENT")
    return sent ? true : false
}

DeathlordEnsureV31(h,player,pid)
{
    global stateBuffKeyV17, deathlordStateV19, deathlordRetryAtV31
    global autoMonsterAttackOn, xRunning, zRunning, gameItemActionOwner, roomExploreV89
    static missingPid := 0, missingPlayer := 0, missingId := "", missingAt := 0
    if (missingPid!=pid || missingPlayer!=player || missingId!=deathlordStateV19)
        missingPid := pid, missingPlayer := player, missingId := deathlordStateV19, missingAt := 0
    if ((!autoMonsterAttackOn && !CycCombatReadyV42(pid) && !ScosEntryBuffReadyV233(pid)) || stateBuffKeyV17="" || deathlordStateV19="")
        return false
    state := StateBuffRead124V17(h,player,deathlordStateV19)
    if (IsObject(roomExploreV89))
        AutoMonsterAttackLogV2("ROOM_Z_STATE key=" . stateBuffKeyV17 . " id=" . deathlordStateV19 . " state=" . state . " meaning=1_PRESENT_0_MISSING_-1_READ_FAILED",true)
    if (state=1)
    {
        deathlordRetryAtV31 := 0, missingAt := 0
        return false
    }
    if (state<0)
    {
        missingAt := 0
        return false
    }
    if (!missingAt)
    {
        missingAt := A_TickCount
        return false
    }
    if (A_TickCount-missingAt<250)
        return false
    if (deathlordRetryAtV31 && A_TickCount-deathlordRetryAtV31<2000)
        return false
    if (xRunning || zRunning || gameItemActionOwner!="" || !IsGameActive()
        || D2GetActiveGamePidV95()!=pid || !NativeDispatchReadyV10(true) || !AutoMonsterPacketCleanupV1())
        return false
    deathlordRetryAtV31 := A_TickCount
    sent := AutoBuffCastV517(h,player,pid,stateBuffKeyV17,deathlordStateV19)
    if (IsObject(roomExploreV89))
        AutoMonsterAttackLogV2("ROOM_Z_SEND key=" . stateBuffKeyV17 . " state=" . state . " sent=" . sent . " retry_ms=2000 effect=WAIT_LIVE_STATE")
    PortalLogWriteV66("AUTO_BUFF_ROW1_ATTEMPT id=" . deathlordStateV19 . " key=" . stateBuffKeyV17
        . " state=" . state . " sent=" . sent . " wait_blocks_farm=0","AUTO_BUFF_ROW1_ATTEMPT",1000)
    DebugTraceWrite("character","DEATHLORD_RETRY id=" . deathlordStateV19 . " state=" . state . " sent=" . sent . " retry_ms=2000 source=LIVE_STATE_BITS until=STATE_PRESENT")
    return sent ? true : false
}

KnownFarmLevelV522(level)
{
    return level=155 || level=270 || level=168 || level=183 || level=184 || level=185
        || level=150 || level=148 || level=147 || level=146 || level=141 || (level>=263 && level<=266)
}

FarmReviveTownLevelV295(level)
{
    global townLevelV22,farmControlOwnerV186
    if (level=241 && farmControlOwnerV186="SCOS")
        return false
    planV743 := FarmMapPlanV10(farmControlOwnerV186,level)
    if (IsObject(planV743) && !planV743.town)
        return false
    return level>0 && (level=1 || level=40 || level=75 || level=103 || level=109
        || (level=townLevelV22 && !KnownFarmLevelV522(level)))
}

; V62: Chuyen Esc thang den cua so game da bind khi chet (mode 17).
; Chi su dung trong luong hoi sinh, khong doi cach gui phim chung.
FarmReviveSendEscV62(pid)
{
    if (!pid || !BackgroundValidV63() || D2GetActiveGamePidV95()!=pid)
        return false
    hwnd := GameTargetHwndV63()
    if (!hwnd)
        return false
    WinGet, targetPidV62, PID, ahk_id %hwnd%
    if (targetPidV62!=pid)
        return false
    vkV62 := GetKeyVK("Esc"),scV62 := GetKeySC("Esc")
    if (!vkV62)
        return false
    lpV62 := 1 | ((scV62 & 255)<<16) | ((scV62 & 256) ? 0x1000000 : 0)
    if (!GameTargetMessageV63(hwnd,0x100,vkV62,lpV62))
        return false
    Sleep, 30
    return GameTargetMessageV63(hwnd,0x101,vkV62,lpV62|0xC0000000)
}

; V62: Uu tien hoi sinh truoc buff, cleanup, remote thread va pickup;
; neu co revive dang cho thi tiep tuc no truoc ca nhanh PICKUP_BUSY.
FarmReviveDeadPriorityV62()
{
    global autoMonsterAttackOn,farmReviveV32
    if (!autoMonsterAttackOn || !IsGameActive())
        return false
    pidV62 := D2GetActiveGamePidV95()
    if (!pidV62)
        return false
    baseV62 := D2GetModuleBaseV35(pidV62,"D2Client.dll")
    hV62 := baseV62 ? D2OpenProcess(pidV62) : 0
    if (!hV62)
        return false
    try
    {
        playerV62 := D2ReadU32(hV62,baseV62+0x11BBFC)
        if (!playerV62)
            return false
        modeV62 := D2ReadU32(hV62,playerV62+0x10)
        reviveActiveV62 := IsObject(farmReviveV32) && farmReviveV32.pid=pidV62
        if (modeV62!=0 && modeV62!=17 && !reviveActiveV62)
            return false
        pathV62 := D2ReadU32(hV62,playerV62+0x2C)
        if (!pathV62 || !MonsterBossProbeReadV1(hV62,pathV62,0x20,pbV62))
            VarSetCapacity(pbV62,0x20,0)
        FarmRevivePickupInterruptV62(pidV62)
        FarmReviveTickV32(hV62,playerV62,pbV62,pidV62,GameTargetHwndV63(),baseV62,pathV62,modeV62)
        return true
    }
    finally
        DllCall("CloseHandle","Ptr",hV62)
}

FarmRevivePickupInterruptV62(pid)
{
    global farmCenterCycleV741,farmItemLockV625,pickupFarmWorkV75,pickupRoundResetV1
    global pickupTimerBusy,gameItemActionOwner
    cycle := farmCenterCycleV741
    if (IsObject(cycle) && cycle.pid=pid && cycle.phase="PICKUP_BUSY")
    {
        SetTimer, FarmPickupHandoffTimerV901, Off
        farmCenterCycleV741 := false
        if (IsObject(farmItemLockV625) && farmItemLockV625.pid=pid)
            farmItemLockV625 := false
        PortalLogWriteV66("FARM_PICKUP_INTERRUPTED reason=PLAYER_DEAD next=REVIVE")
    }
    pickupFarmWorkV75 := false
    pickupRoundResetV1 := true
    if (gameItemActionOwner="Pickup" && !pickupTimerBusy)
        GameItemActionEndV4("Pickup")
}

FarmReviveTickV32(h,player,ByRef pb,pid,hwnd,base,path,mode)
{
    static busyV743 := false
    if (busyV743)
        return true
    busyV743 := true
    try
    {

    global reviveBuffPendingV34, farmReviveV32, autoMonsterAttackOn, townLevelV22, outsideLevelV22, entryBuffPendingV20
    global xRunning, zRunning, gameItemActionOwner, portalCastKeyV50, coordCastPendingV50, coordCastCountV50, portalBuffV85
    global farmControlOwnerV186,scosEntryV162,coordRouteV16,coordYellowRowV350
    global coordManualRowV59,coordPinnedYellowV136,coordLiveYellowV128,coordNearbyRowV18,coordCastLastRowV50
    global farmTownResumeSaveV1002,currentProfile,routeMapIdV21,portalBuffDeferredV998
    global farmTownBuffRearmV1002
    if (!autoMonsterAttackOn || !IsGameActive())
        return false
    ; V941: ghi 1 dong/1 lan chet vao Farm_LichSuMap.txt, khong ghi lap theo tick.
    FarmMapJournalDeathObserveV940(pid,mode)
    if (mode=0 || mode=17)
    {
        portalBuffV85 := false
        if (!IsObject(farmReviveV32) || farmReviveV32.HasKey("portalBefore")
            || farmReviveV32.townBuffDone || IsObject(farmReviveV32.origin))
        {
            deathRouteV725 := IsObject(coordRouteV16) && coordRouteV16.pid=pid ? coordRouteV16 : false
            deathLevelV725 := IsObject(deathRouteV725) ? deathRouteV725.startLevel : CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
            farmReviveV32 := {pid:pid,esc:false,step:0,last:0,origin:false,seen:{},townBuffDone:false
                ,resumeRouteV725:deathRouteV725,resumeLevelV725:deathLevelV725
                ,resumeRowV725:IsObject(deathRouteV725) && deathRouteV725.yellow>=1 ? deathRouteV725.yellow : coordYellowRowV350}
        }
        farmReviveV32.deathSeenV296 := true
        ; V67: Uu tien Esc cho CA HAI trang thai chet (mode 0 va 17).
        ; Gui truoc buff, nhat, packet cleanup; thu lai neu van chua hoi sinh.
        if ((mode=0 || mode=17) && (!farmReviveV32.escTryAtV62 || A_TickCount-farmReviveV32.escTryAtV62>=1200))
        {
            farmReviveV32.escTryAtV62 := A_TickCount
            sentEscV62 := FarmReviveSendEscV62(pid)
            if (sentEscV62)
                farmReviveV32.esc := true
            AutoMonsterAttackLogV2("REVIVE_ESC mode=" . mode . " queued=" . sentEscV62 . " retry_if_still_dead=1200ms")
        }
        return true
    }
    if (!IsObject(farmReviveV32) && autoMonsterAttackOn && reviveBuffPendingV34
        && (mode=1 || mode=5)
        && FarmRevivePortalSourceV746(CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))))
    {
        farmReviveV32 := {pid:pid,esc:false,step:0,last:0,origin:false,seen:{},townBuffDone:false}
        reviveBuffPendingV34 := false
        PortalLogWriteV66("FARM_START_TOWN next=FIND_PORTAL buff=BEFORE_PORTAL")
    }
    ; V1002: dang FARM, lo bam cong quay ve THANH: neu thay cong xanh
    ; thi goi luong tim/cong quay lai giong hoi sinh, khong can co chet.
    ; Khong kich hoat neu khong co cong, hoac co nhieu cong khong ro dich.
    if (!IsObject(farmReviveV32) && autoMonsterAttackOn && (mode=1 || mode=5))
    {
        townNowV1002 := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
        if (FarmReviveTownLevelV295(townNowV1002))
        {
            townPortalsV1002 := FarmPortalsReadV725(h,pb,townCompleteV1002)
            if (townCompleteV1002)
            {
                sessionV1002 := FarmPortalSessionV725(pid)
                recordedV1002 := IsObject(sessionV1002.farm) && sessionV1002.farm.townLevel=townNowV1002
                    ? sessionV1002.farm.townUid : 0
                townTargetV1002 := false,townCountV1002 := 0
                for _,townPortalV1002 in townPortalsV1002
                {
                    if (townPortalV1002.cls!=59)
                        continue
                    townCountV1002++
                    if (recordedV1002 && townPortalV1002.uid=recordedV1002)
                        townTargetV1002 := townPortalV1002
                    else if (!recordedV1002)
                        townTargetV1002 := townPortalV1002
                }
                if ((recordedV1002 && IsObject(townTargetV1002))
                    || (!recordedV1002 && townCountV1002=1))
                {
                    saveV1002 := farmTownResumeSaveV1002
                    savedRowV1002 := IsObject(saveV1002) && saveV1002.pid=pid
                        && saveV1002.profile=currentProfile && saveV1002.mapId=routeMapIdV21
                        && saveV1002.owner=farmControlOwnerV186 ? saveV1002.row : 0
                    savedLevelV1002 := savedRowV1002 ? saveV1002.level : 0
                    farmReviveV32 := {pid:pid,esc:false,step:0,last:0,origin:false
                        ,seen:{},townBuffDone:true,accidentalPortalV1002:true
                        ,portalUidV1002:townTargetV1002.uid
                        ,resumeRowV725:savedRowV1002,resumeLevelV725:savedLevelV1002}
                    reviveBuffPendingV34 := false
                    deferV1002 := portalBuffDeferredV998
                    if (IsObject(deferV1002) && deferV1002.pid=pid
                        && savedLevelV1002=saveV1002.level
                        && savedRowV1002=deferV1002.row)
                        farmTownBuffRearmV1002 := {pid:pid,level:savedLevelV1002
                            ,row:deferV1002.row,fromRow:deferV1002.fromRow
                            ,profile:currentProfile,mapId:routeMapIdV21,owner:farmControlOwnerV186}
                    PortalLogWriteV66("FARM_TOWN_PORTAL_RETURN reason=ACCIDENTAL_PORTAL town=" . townNowV1002
                        . " portal_uid=" . townTargetV1002.uid . " resume_row=" . savedRowV1002
                        . " next=ENTER_PORTAL_KEEP_ROUTE")
                }
            }
        }
    }
    if (!IsObject(farmReviveV32))
        return false
    r := farmReviveV32
    if (r.pid!=pid)
    {
        farmReviveV32 := false
        return false
    }
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    FarmPortalObserveV725(h,player,pb,pid)
    PortalLogWriteV66("REVIVE_STATE level=" . level . " mode=" . mode . " step=" . r.step . " last_try=" . r.last . " seen_count=" . r.seen.Count() . " x_running=" . xRunning . " z_running=" . zRunning . " item_owner=" . gameItemActionOwner,"revive",1000)
    if (!r.respawnLevelV296 && level && mode!=0 && mode!=17)
    {
        r.respawnLevelV296 := level
        PortalLogWriteV66("REVIVE_ALIVE next=FIND_PORTAL town_id_check=OFF")
    }

    if (r.entrySent && level && r.respawnLevelV296 && level!=r.respawnLevelV296)
    {
        PortalLogWriteV66("RETURN_MAP_CONFIRMED level=" . level . " farm=" . autoMonsterAttackOn,"returned",1000)
        if (r.expectedReturnV725 && level!=r.expectedReturnV725)
        {
            PortalLogWriteV66("REVIVE_RETURN_MAP_MISMATCH expected=" . r.expectedReturnV725 . " actual=" . level,"REVIVE_RETURN_MAP_MISMATCH",1000)
            return true
        }
        if (r.returnKindV725!="FARM" && r.returnKindV725!="RED")
            return true
        ; V67: Moi lan chui cong xanh TU THANH LEN FARM deu mo cong moi,
        ; ke ca luot vao lai khong phai do chet, de lan chet sau co cong ve.
        if (r.returnKindV725="FARM" && !r.reopenSentV723)
        {
            if ((mode!=1 && mode!=5)
                || xRunning || zRunning || gameItemActionOwner!="" || !AutoMonsterPacketCleanupV1())
                return true
            if (!QuickBuffHasKey(portalCastKeyV50))
            {
                if (!r.reopenKeyWarningV723)
                {
                    r.reopenKeyWarningV723 := true
                    FonInfoPushV385("Hồi sinh: chưa có phím mở cổng. Cài phím mở cổng để tiếp tục Farm.")
                }
                return true
            }
            reopenRequestV725 := A_TickCount
            if (!BuffCheckedSendV29(portalCastKeyV50) || farmReviveV32!=r)
                return true
            r.reopenSentV723 := reopenRequestV725
            PortalLogWriteV66("REVIVE_REOPEN_PORTAL key=" . portalCastKeyV50 . " level=" . level
                . " sent=1 next=WAIT_CONFIRM_NEW_PORTAL")
            return true
        }
        if (r.returnKindV725="FARM" && r.reopenSentV723)
        {
            portalSessionV725 := FarmPortalSessionV725(pid)
            createdV725 := portalSessionV725.farm
            if (!IsObject(createdV725) || createdV725.level!=level || createdV725.confirmedAt<r.reopenSentV723)
            {
                if (A_TickCount-r.reopenSentV723>=3000)
                    r.reopenSentV723 := 0
                return true
            }
        }
        FarmReviveResumeV743(h,player,pb,pid,r)
        return true
    }
    if (level && !FarmRevivePortalSourceV746(level))
    {
        r.returnPortalV720 := false,r.portalWaitV725 := false
        FarmReviveResumeV743(h,player,pb,pid,r)
        return true
    }
    if (mode!=1 && mode!=5 && mode!=2 && mode!=3 && mode!=6)
        return true
    if (xRunning || zRunning || gameItemActionOwner!="" || !IsGameActive() || !AutoMonsterPacketCleanupV1())
        return true
    px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
    if (!IsObject(r.origin))
        r.origin := {x:px,y:py}
    preferredPortalV720 := IsObject(r.returnPortalV720) ? r.returnPortalV720.uid : r.targetUid
    target := FarmPortalTargetV67(h,pb,px,py,preferredPortalV720,true)
    if (!IsObject(target))
    {
        r.atOriginSince := 0
        ; Do not chase a vanished portal forever: scan green, red, then reload map.
        if (mode=2 || mode=3 || mode=6)
        {
            NativeMovePointV14(pid,px,py,level,false,true,true,false,{revive:r,stop:true})
            return true
        }
        if (r.portalWaitV725)
        {
            r.missingSinceV720 := 0,r.missingReadsV720 := 0
            return true
        }
        if (!r.missingSinceV720)
            r.missingSinceV720 := A_TickCount,r.missingReadsV720 := 0,r.missingReadAtV720 := 0
        if (!r.missingReadAtV720 || A_TickCount-r.missingReadAtV720>=500)
            r.missingReadsV720++,r.missingReadAtV720 := A_TickCount
        if (r.missingReadsV720<3 || A_TickCount-r.missingSinceV720<1500)
            return true
        ; V61: Chi sau khi da hoi sinh ve thanh va khong co cong quay lai:
        ; huy tien do lo trinh cu, nạp map moi khi vao duoc khu Farm,
        ; bat dau tu dong vang cua map moi. Khong sua nhanh HOI SINH hay CO CONG.
        if (r.deathSeenV296 && FarmReviveTownLevelV295(level))
            FarmReviveNoPortalNewRouteV61(r,pid,level)
        PortalLogWriteV66("REVIVE_NO_FARM_PORTAL owner=" . farmControlOwnerV186
            . " level=" . level . " next=REENTER_FARM_RELOAD_MAP_YELLOW")
        FarmReviveResumeV743(h,player,pb,pid,r)
        return true
    }
    r.missingSinceV720 := 0,r.missingReadsV720 := 0
    r.returnPortalV720 := {uid:target.uid,level:level,x:target.x,y:target.y}
    r.returnKindV725 := target.returnKindV725,r.expectedReturnV725 := target.destinationV725
    if (r.entrySent && A_TickCount-r.entrySent<1500)
        return true
    if ((px-target.x)**2+(py-target.y)**2>9)
    {
        r.atOriginSince := 0
        if (!r.moveAtV720 || A_TickCount-r.moveAtV720>=250)
        {
            sent := NativeMovePointV14(pid,target.x,target.y,level,false,true,true,false,{revive:r})
            if (sent)
                r.moveAtV720 := A_TickCount
            PortalLogWriteV66("REVIVE_PORTAL_APPROACH uid=" . target.uid . " town=" . level
                . " target=" . target.x . "," . target.y . " queued=" . sent,"REVIVE_PORTAL_APPROACH",1000)
        }
        return true
    }
    if (mode=2 || mode=3 || mode=6)
    {
        NativeMovePointV14(pid,px,py,level,false,true,true,false,{revive:r,stop:true})
        return true
    }
    PortalLogWriteV66("PORTAL_DLL_TARGET uid=" . target.uid . " class=" . target.cls . " portal_xy=" . target.x . "," . target.y
        . " player_xy=" . px . "," . py . " selection=NEAREST_CURRENT_PLAYER","portal_target",1000)
    if (r.targetUid!=target.uid || r.targetX!=target.x || r.targetY!=target.y)
    {
        r.targetUid := target.uid, r.targetX := target.x, r.targetY := target.y
        r.atOriginSince := 0
    }
    if (!r.atOriginSince)
    {
        r.atOriginSince := A_TickCount
        return true
    }
    if (A_TickCount-r.atOriginSince<250)
        return true
    if (!r.townBuffDone)
    {
        if (!RouteBuffSequenceV20(h,player,pid,false,true) || farmReviveV32!=r)
            return true
        r.townBuffDone := true,r.arrivalBuffDoneV294 := true
        r.atOriginSince := 0,r.moveAtV720 := 0,r.last := 0
        reviveBuffPendingV34 := false,entryBuffPendingV20 := false
        PortalLogWriteV66("REVIVE_TOWN_BUFF_DONE next=ENTER_RETURN_PORTAL")
        return true
    }
    sent := FarmPortalInteractV67(pid,level,target)
    PortalLogWriteV66("PORTAL_DLL_TRY attempt=" . (r.step+1) . " uid=" . target.uid . " type=2 rva=0x2AC10"
        . " portal_xy=" . target.x . "," . target.y . " player_xy=" . px . "," . py
        . " stable_ms=" . (A_TickCount-r.atOriginSince) . " queued=" . sent . " result=WAIT_MAP_CHANGE")
    if (sent)
    {
        r.step++
        r.entrySent := A_TickCount, r.entryX := px, r.entryY := py, r.entryUid := target.uid
    }
    r.atOriginSince := 0
    r.last := A_TickCount
    return true
    }
    finally
        busyV743 := false
}

FarmPortalSessionV725(pid)
{
    global farmPortalSessionsV725,farmControlOwnerV186,libScrollTierV290,currentProfile
    if (!IsObject(farmPortalSessionsV725))
        farmPortalSessionsV725 := {}
    birth := BackgroundBirthV63(pid)
    owner := farmControlOwnerV186
    key := pid . "|" . birth . "|" . currentProfile . "|" . owner . (owner="LIB" ? "|" . libScrollTierV290 : "")
    if (!farmPortalSessionsV725.HasKey(key))
        farmPortalSessionsV725[key] := {pid:pid,birth:birth,owner:owner,initial:{},townSeen:{},farm:false,cast:false,pendingEntry:false}
    return farmPortalSessionsV725[key]
}

FarmPortalsReadV725(h,ByRef pb,ByRef complete)
{
    result := {},complete := false,seen := {},total := 0,start := A_TickCount
    room := NumGet(pb,0x1C,"UInt"),level := room ? CoordLevelV14(h,room) : 0
    rooms := room ? MonsterLoadedRoomsV20(h,room) : false
    if (!level || !IsObject(rooms) || !rooms.Length())
        return result
    complete := true
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
            if (total>=4096 || A_TickCount-start>100)
            {
                complete := false
                return result
            }
            seen[u] := true,total++
            if (!MonsterBossProbeReadV1(h,u,0xEC,ub))
            {
                complete := false
                break
            }
            unit := u,u := NumGet(ub,0xE8,"UInt"),cls := NumGet(ub,4,"UInt"),uid := NumGet(ub,12,"UInt")
            if (NumGet(ub,0,"UInt")=2 && uid && (cls=59 || cls=60))
            {
                if (!MonsterBossProbeReadV1(h,NumGet(ub,0x2C,"UInt"),0x18,op))
                    complete := false
                else
                    result[uid] := {unit:unit,uid:uid,cls:cls,typ:2,level:level,mode:NumGet(ub,16,"UInt")
                        ,x:NumGet(op,12,"UInt"),y:NumGet(op,16,"UInt")}
            }
            if (A_Index=1024 && u)
                complete := false
        }
    }
    return result
}

FarmPortalRecordV725(pid,h,player,kind,target := false)
{
    session := FarmPortalSessionV725(pid)
    if (kind="CANCEL_CAST")
    {
        session.cast := false
        return true
    }
    if (!MonsterBossProbeReadV1(h,D2ReadU32(h,player+0x2C),0x20,pb))
        return false
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    portals := FarmPortalsReadV725(h,pb,complete)
    if (!complete || !level)
        return false
    if (kind="CAST")
    {
        if (FarmReviveTownLevelV295(level))
            return false
        if (IsObject(session.cast) && session.cast.level=level && A_TickCount-session.cast.at<1500)
            return false
        session.cast := {pid:pid,level:level,x:NumGet(pb,2,"UShort"),y:NumGet(pb,6,"UShort")
            ,before:portals,at:A_TickCount}
        PortalLogWriteV66("PORTAL_RECORD_CAST level=" . level . " before=" . portals.Count())
        return true
    }
    if (kind!="ENTRY" || !IsObject(target) || !portals.HasKey(target.uid))
        return false
    live := portals[target.uid]
    if (live.unit!=target.unit)
        return false
    record := {uid:live.uid,cls:live.cls,unit:live.unit,level:level,x:live.x,y:live.y,destination:0,at:A_TickCount}
    session.initial[level . "|" . live.uid] := record
    session.pendingEntry := record
    if (FarmStartPortalOriginV699(level))
    {
        if (!IsObject(session.townSeen[level]))
            session.townSeen[level] := {}
        for uid,portal in portals
            session.townSeen[level][uid] := true
    }
    PortalLogWriteV66("PORTAL_RECORD_INITIAL source=" . level . " uid=" . live.uid . " class=" . live.cls
        . " xy=" . live.x . "," . live.y)
    return true
}

FarmPortalObserveV725(h,player,ByRef pb,pid)
{
    session := FarmPortalSessionV725(pid)
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    if (!level || D2ReadU32(h,player+0x10)=0 || D2ReadU32(h,player+0x10)=17)
        return false
    entry := session.pendingEntry
    if (IsObject(entry) && entry.sentAt && level!=entry.level)
    {
        entry.destination := level,entry.arrivedAt := A_TickCount
        session.pendingEntry := false
        PortalLogWriteV66("PORTAL_RECORD_INITIAL_DEST uid=" . entry.uid . " source=" . entry.level . " destination=" . level)
    }
    cast := session.cast
    farm := session.farm
    needTownPair := FarmReviveTownLevelV295(level) && IsObject(farm) && !farm.townUid
    if (!IsObject(cast) && !needTownPair)
        return true
    portals := FarmPortalsReadV725(h,pb,complete)
    if (!complete)
        return false
    if (IsObject(cast) && cast.level=level)
    {
        found := false,count := 0
        for uid,p in portals
        {
            old := cast.before[uid]
            changed := !IsObject(old) || old.x!=p.x || old.y!=p.y
            if (p.cls=59 && changed && (p.x-cast.x)**2+(p.y-cast.y)**2<=400)
                found := p,count++
        }
        if (count=1)
        {
            session.farm := {uid:found.uid,cls:found.cls,level:level,x:found.x,y:found.y,castAt:cast.at
                ,confirmedAt:A_TickCount,townUid:0,townLevel:0,townX:0,townY:0}
            session.cast := false,farm := session.farm
            PortalLogWriteV66("PORTAL_RECORD_FARM_CONFIRMED uid=" . found.uid . " level=" . level
                . " class=" . found.cls . " xy=" . found.x . "," . found.y)
        }
    }
    if (IsObject(cast) && cast.level!=level && FarmReviveTownLevelV295(level))
    {
        found := false,count := 0,seen := session.townSeen[level]
        for uid,p in portals
            if (p.cls=59 && !session.initial.HasKey(level . "|" . uid) && (!IsObject(seen) || !seen.HasKey(uid)))
                found := p,count++
        if (count=1)
        {
            session.farm := {uid:0,cls:found.cls,level:cast.level,x:cast.x,y:cast.y,castAt:cast.at
                ,confirmedAt:A_TickCount,townUid:found.uid,townLevel:level,townX:found.x,townY:found.y}
            session.cast := false
            PortalLogWriteV66("PORTAL_RECORD_FARM_TOWN_CONFIRMED town_uid=" . found.uid . " destination=" . cast.level)
        }
    }
    if (FarmReviveTownLevelV295(level) && IsObject(session.farm) && !session.farm.townUid)
    {
        farm := session.farm,found := false,count := 0,seen := session.townSeen[level]
        for uid,p in portals
        {
            initial := session.initial.HasKey(level . "|" . uid)
            if (p.cls=farm.cls && !initial && (!IsObject(seen) || !seen.HasKey(uid)))
                found := p,count++
        }
        if (count=1)
        {
            farm.townUid := found.uid,farm.townLevel := level,farm.townX := found.x,farm.townY := found.y
            PortalLogWriteV66("PORTAL_RECORD_FARM_TOWN_PAIR farm_uid=" . farm.uid . " town_uid=" . found.uid
                . " town=" . level . " destination=" . farm.level)
        }
        else if (count>1)
            PortalLogWriteV66("PORTAL_PAIR_WAIT reason=MULTIPLE_UNRECORDED_PORTALS count=" . count,"PORTAL_PAIR_WAIT",1000)
    }
    return true
}

FarmPortalSelectV725(h,ByRef pb,pid,r)
{
    global farmControlOwnerV186
    session := FarmPortalSessionV725(pid)
    level := CoordLevelV14(h,NumGet(pb,0x1C,"UInt"))
    if (!FarmRevivePortalSourceV746(level))
    {
        r.returnPortalV720 := false,r.portalWaitV725 := false
        return false
    }
    FarmPortalObserveV725(h,D2ReadU32(h,D2GetModuleBaseV35(pid,"D2Client.dll")+0x11BBFC),pb,pid)
    portals := FarmPortalsReadV725(h,pb,complete)
    r.portalWaitV725 := !complete
    if (!complete)
        return false
    blue := false,bestDist := 1.0e20
    px := NumGet(pb,2,"UShort"),py := NumGet(pb,6,"UShort")
    for uid,p in portals
    {
        if (p.cls!=59)
            continue
        dist := (p.x-px)**2+(p.y-py)**2
        if (!IsObject(blue) || dist<bestDist || (dist=bestDist && p.uid<blue.uid))
            blue := p,bestDist := dist
    }
    ; V1002: neu truoc do da xac dinh cong quay lai, khong chon nham cong khac.
    if (r.accidentalPortalV1002 && r.portalUidV1002)
    {
        confirmedV1002 := portals[r.portalUidV1002]
        if (!IsObject(confirmedV1002) || confirmedV1002.cls!=59)
        {
            r.portalWaitV725 := true
            return false
        }
        blue := confirmedV1002
    }
    if (IsObject(blue))
    {
        r.farmMissingAtV725 := 0,r.farmMissingReadsV725 := 0,r.farmMissingReadAtV725 := 0
        blue.returnKindV725 := "FARM",blue.destinationV725 := 0
        return blue
    }
    r.returnPortalV720 := false
    if (!r.farmMissingAtV725)
        r.farmMissingAtV725 := A_TickCount,r.farmMissingReadsV725 := 0,r.farmMissingReadAtV725 := 0
    if (!r.farmMissingReadAtV725 || A_TickCount-r.farmMissingReadAtV725>=500)
        r.farmMissingReadsV725++,r.farmMissingReadAtV725 := A_TickCount
    if (r.farmMissingReadsV725<3 || A_TickCount-r.farmMissingAtV725<1500)
    {
        r.portalWaitV725 := true
        return false
    }
    entrance := false
    for _,a in session.initial
        if (a.level=level && a.cls=60 && a.destination
            && FarmStartMapStageV737(farmControlOwnerV186,a.destination)>0
            && !FarmReviveTownLevelV295(a.destination)
            && (!IsObject(entrance) || a.at>entrance.at))
            entrance := a
    p := IsObject(entrance) ? portals[entrance.uid] : false
    if (IsObject(p) && p.cls=60)
    {
        p.returnKindV725 := "RED",p.destinationV725 := entrance.destination
        return p
    }
    ; A previous red portal that is no longer loaded must not block fallback.
    ; Red is always fallback #2 regardless of map owner or number of red portals.
    ; When more than one exists, take the nearest (stable tie-break by UID).
    red := false,redCount := 0,bestRedDist := 1.0e20
    for _,candidate in portals
    {
        if (candidate.cls!=60)
            continue
        redCount++
        dist := (candidate.x-px)**2+(candidate.y-py)**2
        if (!IsObject(red) || dist<bestRedDist || (dist=bestRedDist && candidate.uid<red.uid))
            red := candidate,bestRedDist := dist
    }
    if (IsObject(red))
    {
        red.returnKindV725 := "RED",red.destinationV725 := 0
        r.portalWaitV725 := false
        return red
    }
    ; Only after a complete scan and no green or red: load map and yellow line.
    r.portalWaitV725 := false
    PortalLogWriteV66("REVIVE_NO_GREEN_RED owner=" . farmControlOwnerV186
        . " level=" . level . " next=LOAD_MAP_YELLOW","REVIVE_NO_GREEN_RED",2000)
    return false
}

FarmPortalTargetV67(h,ByRef pb,ox,oy,preferredUid := 0,recordedOnlyV725 := false)
{
    global farmReviveV32
    if (recordedOnlyV725 && IsObject(farmReviveV32))
        return FarmPortalSelectV725(h,pb,farmReviveV32.pid,farmReviveV32)
    seen := {}, count := 0, best := false, bestDist := 1.0e20
    for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
    {
        u := D2ReadU32(h,room+0x74)
        Loop, 256
        {
            if (!u || seen.HasKey(u) || count>=1024)
                break
            seen[u] := true, count++
            if (!MonsterBossProbeReadV1(h,u,0xEC,b))
                break
            next := NumGet(b,0xE8,"UInt"), cls := NumGet(b,4,"UInt")
            if (NumGet(b,0,"UInt")=2 && (cls=59 || cls=60))
            {
                path := NumGet(b,0x2C,"UInt"), uid := NumGet(b,0x0C,"UInt")
                if (uid && MonsterBossProbeReadV1(h,path,0x18,ob))
                {
                    x := NumGet(ob,0x0C,"UInt"), y := NumGet(ob,0x10,"UInt")
                    if (uid=preferredUid)
                        return {unit:u,uid:uid,cls:cls,x:x,y:y}
                    dist := (x-ox)*(x-ox)+(y-oy)*(y-oy)
                    if (dist<bestDist)
                        best := {unit:u,uid:uid,cls:cls,x:x,y:y}, bestDist := dist
                }
            }
            u := next
        }
    }
    return best
}

FarmPortalInteractV67(pid,level,target)
{
    global autoMonsterPacketPendingV1,farmReviveV32
    if (!IsObject(target) || !CoordMoveReadyV60(pid,false,true) || !AutoMonsterPacketCleanupV1())
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
            || (NumGet(pb,2,"UShort")-target.x)**2+(NumGet(pb,6,"UShort")-target.y)**2>400)
            return false
        inv := D2ReadU32(h,player+0x60), cursor := inv ? PickupCursorV4(h,inv) : false
        if (!IsObject(cursor) || cursor.unit)
            return false
        live := FarmPortalTargetV67(h,pb,target.x,target.y,target.uid,IsObject(farmReviveV32))
        if (!IsObject(live) || live.uid!=target.uid || live.unit!=target.unit
            || live.x!=target.x || live.y!=target.y)
            return false
        remote := DllCall("VirtualAllocEx","Ptr",h,"Ptr",0,"UPtr",128,"UInt",0x3000,"UInt",0x40,"Ptr")
        if (!remote || remote>0xFFFFFFFF)
            return false
        hex := FarmPortalCodeTownOnlyV68(base,target.uid,level)
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
            || (IsObject(farmReviveV32) && !FarmRevivePortalSourceV746(level))
            || (NumGet(currentPb,2,"UShort")-target.x)**2+(NumGet(currentPb,6,"UShort")-target.y)**2>400
            || !CoordMoveReadyV60(pid,false,true)
            || D2ReadU32(h,target.unit)!=2 || D2ReadU32(h,target.unit+0x0C)!=target.uid
            || D2ReadU32(h,target.unit+4)!=target.cls)
            return false
        thread := DllCall("CreateRemoteThread","Ptr",h,"Ptr",0,"UPtr",0,"Ptr",remote,"Ptr",0,"UInt",0,"UIntP",tid,"Ptr")
        if (!thread)
            return false
        autoMonsterPacketPendingV1 := {process:h,remote:remote,thread:thread,uid:target.uid,kind:"PORTAL_DLL",portalCall:true,setAt:A_TickCount}
        owned := true
        SetTimer, AutoMonsterPacketCleanupTimerV1, 50
        PortalLogWriteV66("PORTAL_INTERACT_SENT uid=" . target.uid . " class=" . target.cls
            . " xy=" . target.x . "," . target.y . " player=" . NumGet(pb,2,"UShort") . "," . NumGet(pb,6,"UShort")
            . " level=" . level . " method=FarmPortalInteractV67")
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

FarmPortalCodeTownOnlyV68(base,uid,town,unitType:=2)
{
    hex := "60A1" . NativeLE32V9(base+0x11BBFC), jumps := []
    for _,load in ["","8B402C","8B401C","8B4010","8B4058"]
    {
        hex .= load . "85C0"
        jumps.Push(StrLen(hex)//2)
        hex .= "7400"
    }
    if (town>0)
    {
        hex .= "81B8D0010000" . NativeLE32V9(town)
        jumps.Push(StrLen(hex)//2), hex .= "7500"
    }
    hex .= "B9" . NativeLE32V9(unitType) . "BA" . NativeLE32V9(uid) . "B8" . NativeLE32V9(base+0x2AC10) . "FFD0"
    finish := StrLen(hex)//2
    for _,at in jumps
        hex := SubStr(hex,1,at*2+2) . Format("{:02X}",finish-at-2) . SubStr(hex,at*2+5)
    return hex . "6131C0C20400"
}

FarmNearbyPortalsV61(h,ByRef pb)
{
    portals := {}, seen := {}, count := 0
    px := NumGet(pb,2,"UShort"), py := NumGet(pb,6,"UShort")
    for _,room in MonsterLoadedRoomsV20(h,NumGet(pb,0x1C,"UInt"))
    {
        u := D2ReadU32(h,room+0x74)
        Loop, 256
        {
            if (!u || seen.HasKey(u) || count>=1024)
                break
            seen[u] := true, count++
            if (!MonsterBossProbeReadV1(h,u,0xEC,b))
                break
            next := NumGet(b,0xE8,"UInt"), cls := NumGet(b,4,"UInt")
            if (NumGet(b,0,"UInt")=2 && (cls=59 || cls=60))
            {
                path := NumGet(b,0x2C,"UInt"), uid := NumGet(b,0x0C,"UInt")
                if (uid && MonsterBossProbeReadV1(h,path,0x18,ob))
                {
                    x := NumGet(ob,0x0C,"UInt"), y := NumGet(ob,0x10,"UInt")
                    if ((x-px)*(x-px)+(y-py)*(y-py)<=400)
                        portals[uid] := true
                }
            }
            u := next
        }
    }
    return portals
}


PortalLogStartV66()
{
    if (!ManualLogActiveV81())
        return false
    global portalLogUntilV66, portalLogFileV66, portalLogSessionV66, portalLogLastLevelV66, portalLogAutoV73
    portalLogAutoV73 := false
    portalLogFileV66 := A_ScriptDir . "\Auto-GSF-Cong-Len-Map.log"
    portalLogSessionV66 := A_TickCount, portalLogLastLevelV66 := 0
    portalLogUntilV66 := A_TickCount+2147480000
    PortalLogWriteV66("START duration=UNTIL_STOP segment_ms=10000 fix=SCOS_BLOCK_REENTRY_AFTER_PORTAL_POSITION_TRANSFER note=QUEUE_SUCCESS_IS_NOT_PORTAL_SUCCESS")
    SetTimer, PortalLogTimerV66, 500
}

PortalLogWriteV66(message,key := "",interval := 0)
{
    if (!ManualLogActiveV81())
        return
    FarmInfoEventV4(message)
    global portalLogUntilV66, portalLogFileV66, portalLogSessionV66
    static seen := {}, session := 0
    if (!portalLogUntilV66 || A_TickCount>=portalLogUntilV66)
        return
    if (session!=portalLogSessionV66)
        seen := {}, session := portalLogSessionV66
    if (key!="" && interval && seen.HasKey(key) && A_TickCount-seen[key]<interval)
        return
    if (key!="")
        seen[key] := A_TickCount
    ManualLogAppendV81(A_Now . " tick=" . A_TickCount . " | " . message . "`r`n", portalLogFileV66, "UTF-8")
}

NaoFarmLevelV312(level)
{
    return Lab1SingleRunV310() && level>0 && !FarmReviveTownLevelV295(level) ? level : 155
}

Lab1SingleRunV310()
{
    global fautLab1V309,farmControlOwnerV186
    return fautLab1V309 && farmControlOwnerV186="NAO"
}

MapStage2RouteFinishV185()
{
    global farmGD2TestV644
    if (IsObject(farmGD2TestV644))
        return FarmGD2TestStopV644("TEST GD2: DONE - đã chạy hết tuyến, giữ map để sửa tiếp.")
    global farmStage2DoneV372,coordRouteV16,backgroundPidV63,farmControlOwnerV186
    if (IsObject(farmStage2DoneV372) && farmStage2DoneV372.route=coordRouteV16)
        return true
    if (Stage2FlowModeV380()="ITEM" && !Stage2ItemDoneV380())
    {
        CainHuntRouteLoopV407()
        return false
    }
    farmStage2DoneV372 := {pid:backgroundPidV63,owner:farmControlOwnerV186,route:coordRouteV16,handled:false}
    if (IsObject(coordRouteV16))
        coordRouteV16.phase := "DONE"
    PortalLogWriteV66("MAP_STAGE2_DONE result=DONE town=CALLER_DECIDES")
    ToolTipInfoV386("GĐ2: DONE - đã đi hết map.")
    SetTimer, RemoveToolTip, -3000
    return true
}

ScosEntryStopV162(reason)
{
    global scosEntryV162
    if (reason="HOTKEY" || InStr(reason,"USER_STOP"))
        FarmBuffStopV509()
    if (!IsObject(scosEntryV162))
        return
    r := scosEntryV162
    scosEntryV162 := false
    SetTimer, ScosEntryTimerV162, Off
    PickupEnabledSetV71((reason="HOTKEY" || InStr(reason,"USER_STOP")) ? false : r.pickup,true,false)
    PortalLogWriteV66("MAP_ENTRY_STOP map=" . (r.map!="" ? r.map : "SCOS") . " reason=" . reason)
}

FarmCommonRouteActiveV3(pid := 0,level := 0)
{
    global scosEntryV162,farmControlOwnerV186
    r := scosEntryV162,c := r.commonRouteV3
    return IsObject(r) && IsObject(c) && c.owner=farmControlOwnerV186
        && (!pid || c.pid=pid) && (!level || c.level=level)
}

FarmCommonRouteReadyV3(pid,level)
{
    global scosEntryV162
    if (!FarmCommonRouteActiveV3(pid,level))
        return false
    c := scosEntryV162.commonRouteV3,live := MapLiveIdentityV399(pid,level),points := c.pointsV724
    return !c.initializingV724 && IsObject(live) && live.levelPtr=c.levelPtr && IsObject(points)
        && points.Length() && points[1].level=level
}

FarmCommonRouteEndV3(r)
{
    global autoMonsterAttackOn,coordRouteV16,stage2FlowV380,stage2MapFileV14,farmStage2DoneV372
    global farmPickupBlockedV57,farmPickupAllowedV57
    if (!IsObject(r.commonRouteV3))
        return
    FarmAttackHoldReleaseV15()
    autoMonsterAttackOn := false
    SetTimer, AutoMonsterAttackTimer, Off
    r.commonRouteV3 := false
    coordRouteV16 := false,stage2FlowV380 := false,stage2MapFileV14 := false,farmStage2DoneV372 := false
    farmPickupBlockedV57 := false,farmPickupAllowedV57 := false
}

FarmCommonRouteTickV3(r,ctx,ByRef pb,level,key,points := false,handoff := false,fightOn := false)
{
    global scosEntryV162,coordSavedV15,coordRouteV16,coordYellowRowV350
    global autoMonsterAttackOn,farmControlOwnerV186,stage2FlowV380,farmStage2DoneV372
    global farmPickupBlockedV57,farmPickupAllowedV57,farmResumeArmedV70,reviveBuffPendingV34
    global coordCastPendingV50,pestiPointPendingV28,lastAttackPendingV20,monsterCombatUidV45,monsterRoadAreaV51
    if (scosEntryV162!=r)
        return "WAIT"
    c := r.commonRouteV3
    if (!IsObject(c) || c.key!=key || c.level!=level || c.initializingV724)
    {
        FarmCommonRouteEndV3(r)
        if (IsObject(points) && points.Length())
        {
            route := []
            for _,point in points
                route.Push({x:point.x,y:point.y,level:level})
            row := 1
        }
        else
        {
            if (!Stage2MapWaitV381(r.pid,level,true))
                return "WAIT"
            FarmStartApplyYellowV2()
            route := []
            for _,point in coordSavedV15
                route.Push(point.Clone())
            row := FarmStartRowV394()
        }
        live := MapLiveIdentityV399(r.pid,level)
        if (!IsObject(live) || !IsObject(route) || !route.Length() || route[1].level!=level)
            return "WAIT"
        if (IsObject(handoff))
        {
            last := route[route.Length()]
            if (last.x!=handoff.x || last.y!=handoff.y)
                route.Push({x:handoff.x,y:handoff.y,level:level,arrivalSqV3:1})
            else
                last.arrivalSqV3 := 1
        }
        r.commonRouteV3 := {key:key,pid:r.pid,owner:farmControlOwnerV186,level:level,levelPtr:live.levelPtr
            ,fightOn:fightOn ? true : false,pointsV724:route,startRowV724:row,initializingV724:true}
        if (fightOn && r.commonBuffLevelV10!=level)
        {
            autoMonsterAttackOn := true
            if (!RouteBuffSequenceV20(ctx.h,ctx.playerV10,r.pid,true) || scosEntryV162!=r)
                return "WAIT"
            r.commonBuffLevelV10 := level
        }
        r.commonRouteV3.initializingV724 := false
        Stage2FlowConfigureV380("NORMAL",0,-1,fightOn)
        MapStageSetV185(1)
        FarmCastSyncV88(fightOn)
        PickupEnabledSetV71(fightOn,true,false)
        farmPickupBlockedV57 := !fightOn,farmPickupAllowedV57 := fightOn
        farmResumeArmedV70 := false,reviveBuffPendingV34 := false,farmStage2DoneV372 := false
        coordCastPendingV50 := false,pestiPointPendingV28 := false,lastAttackPendingV20 := false
        CoordRouteResetV16()
        coordRouteV16.pid := r.pid,coordRouteV16.startLevel := level
        coordRouteV16.resumeRowV210 := row,coordRouteV16.startAtYellowV367 := true,coordRouteV16.yellow := row
        autoMonsterAttackOn := true
        if (fightOn)
            SetTimer, AutoMonsterAttackTimer, 250
        else
            SetTimer, AutoMonsterAttackTimer, Off
        CoordBoxRefreshV15(true)
        FonInfoPushV385("Map " . level . ": gọi farm chuẩn" . (fightOn ? "" : " không đánh") . ", bắt đầu từ dòng " . row . ".")
        PortalLogWriteV66("COMMON_ROUTE_BEGIN caller=" . farmControlOwnerV186 . " map=" . level
            . " key=" . key . " yellow=" . row . " combat=" . fightOn . " engine=STANDARD_GD2")
        return "RUN"
    }
    if (!FarmCommonRouteReadyV3(r.pid,level))
        return "WAIT"
    if (!AutoMonsterPacketCleanupV1())
        return "WAIT"
    if (c.fightOn)
        return IsObject(coordRouteV16) && coordRouteV16.phase="DONE" ? "DONE" : "RUN"
    monsterCombatUidV45 := 0,monsterRoadAreaV51 := false
    if (r.goldAlongBusyV12 && FarmGoldAlongRouteV12(r,ctx,pb,level))
        return "RUN"
    CoordRouteObserveV18(ctx.h,pb,r.pid)
    if (FarmGoldAlongRouteV12(r,ctx,pb,level))
        return "RUN"
    if (IsObject(coordRouteV16) && coordRouteV16.phase="DONE")
    {
        if (!FarmSharedGoldExitReadyV781(r,ctx,pb,level))
            return "RUN"
        if (IsObject(handoff))
        {
            MapStage1MoveV374(ctx,handoff.x,handoff.y)
            return "RUN"
        }
        return "DONE"
    }
    if (!CoordStuckTickV84(ctx.h,pb,r.pid))
        CoordMoveWhenClearV14(ctx.h,pb,r.pid)
    return "RUN"
}
