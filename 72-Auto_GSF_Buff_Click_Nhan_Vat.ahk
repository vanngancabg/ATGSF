#InstallKeybdHook
#InstallMouseHook
mapTestModeV656 := false
pickupContextModeV765 := "FARM"
pickupSigListOnlyV1321 := false
sigSessionActiveV1321 := false
sigFailedItemsV765 := {}
 
manualLogFilesV98 := {}
manualLogFilesV98["Auto-GSF-Buff-HP-Mana.txt"] := false
manualLogFilesV98["Auto-GSF-Click-Phai-Packet.txt"] := false
manualLogFilesV98["Auto-GSF-Cong-Len-Map.log"] := true
manualLogFilesV98["Auto-GSF-Cube.log"] := false
manualLogFilesV98["Auto-GSF-Debug.log"] := false
manualLogFilesV98["Auto-GSF-Nhan-Vat-DLL.txt"] := false
manualLogFilesV98["Auto-GSF-Nhat-Ruong.txt"] := true
manualLogFilesV98["UniqueItems-GET.txt"] := true
manualLogFilesV98["Auto-GSF-Quai-Boss.txt"] := true
manualLogFilesV98["Auto-GSF-Ruong-Belt.txt"] := false
manualLogFilesV98["Auto-GSF-Ruong-Cube.txt"] := true
manualLogFilesV98["Auto-GSF-Test-Phong.log"] := true
manualLogFilesV98["Auto-GSF-Map-Full.log"] := true
manualLogFilesV98["Auto-GSF-Tu-Danh.txt"] := true
roomMapLastButtonV22 := ""
autoMapTrackingV10 := true
coordTrackingEnabledV409 := true
cainPausedV10 := false
farmUserPausedV2026 := false
farmPauseTickV2026 := 0
coordPinnedYellowV136 := 0
coordYellowRowV350 := 0
fonInfoOnV385 := false
farmElapsedStartedAtV1350 := ""
farmElapsedSavedSecV1350 := 0
coordMapReadyV381 := false
coordMapStateV381 := false
coordMapAcceptedV381 := false
coordMapReloadV381 := false
coordMapKeepYellowV381 := false
coordMapSerialV381 := 0
fonFirstLoadV763 := false
stage2StartPendingV381 := false
autoLoadMapV340 := true
autoLoadMapPendingV340 := false
autoLoadMapAttemptsV340 := 0
fonStartupLoadDoneV763 := false
roomSavedReplayEnabledV116 := false
roomRecordV108 := false
roomExploreV89 := false
portalBuffV85 := false
#SingleInstance Force
if (!A_IsAdmin)
{
    Run, *RunAs "%A_AhkPath%" "%A_ScriptFullPath%"
    ExitApp
}
TxtRootInitV816() ; Chuyen .txt va config.ini vao thu muc txt, giu file cu.
debugPrivilegeOK := EnableGameDebugPrivilege()
farmLastCombatTickV72 := 0
farmPickupGuardV4 := false
farmResumeArmedV70 := false, farmResumeOutsideV70 := false, farmResumeInternalV70 := false
sigTownLogTestEnabledV148 := true, sigTownV148 := false, sigTownSendingV148 := false
sigCubeCaptureEnabledV151 := false, sigCubeCaptureV151 := false
portalBackPendingV74 := false
portalExitPendingV69 := false
gameItemActionOwner := ""
gameItemTimersPausedOwner := ""
backgroundHwndV63 := 0, backgroundPidV63 := 0, backgroundBirthV63 := ""
autoMonsterAttackOn := false
monsterExcludeClassesV11 := ""
petLearnOnV12 := false
petLearnDoneV12 := false
petLearnEnabledV12 := false
autoMonsterToggleKeyV13 := ""
farmNaoKeyV181 := "",sigSuKeyV181 := "",pickupBackgroundV181 := false
farmResetWatchEnabledV217 := false
farmResetWatchMinutesV217 := 5
farmExtraCAINButtonDispatchV297 := false
farmVizButtonDispatchV687 := false
farmWatchdogSecondsV578 := 60
resetWatchSinceV217 := 0
lastTriggerV217 := 0
petLearnKeyV13 := "'"
coordGetKeyV14 := ""
coordPointTextV14 := ""
coordSavedV15 := []
routeMapsV21 := []
routeMapIdV21 := 0
routeMapNextV21 := 1
routeMapUiBusyV21 := false
coordCurrentTextV15 := "--,--"
coordCurrentLevelV400 := 0
coordCursorCacheV410 := {pid:0,base:0,h:0,at:0}
routePreviewV401 := false
mapLoadFailureV402 := false
cainHuntRouteV403 := false
coordBoxLastV15 := ""
coordPointLevelV14 := 0
coordMoveDoneV14 := false
coordMoveTriesV14 := 0
coordNoTargetSinceV14 := 0
coordLastMoveV14 := 0
moveDelayMsV810 := 250
combatRecoverV48 := false
combatMildRecoverV299 := false
monsterRadiusV48 := 12
itemCenterRadiusV810 := 12
pickupScanRadiusV810 := 24  ; BK quet mac dinh = BK danh x2, doc theo profile sau
farmScanLimitV771 := 5
mapMoveDistanceV197 := 12
portalCastKeyV50 := "MButton"
portalCastEveryV52 := 2
teleportKeyV55 := ""
teleportIntervalSecV56 := 5
selectedTabV6 := 1
chaseMissV6 := false

boMoveMinimumV456 := 5
teleLockSecV13 := 3
goalDetourV14 := 6
monsterLockUntilDeadV145 := false
fautLab1V309 := false
labNumberV314 := 1
farmEntrySigV315 := true,farmEntryGoldV315 := true
labInventoryOnlyV311 := false
cainNoFightV361 := false
cainPauseFarmV361 := false
stage2FlowV380 := false
currentAttackUidV520 := 0
currentAttackClassV520 := 0
currentAttackX_V520 := 0
currentAttackY_V520 := 0
currentAttackAtV520 := 0
currentAttackDistV523 := 0
; Latest monster skipped because of a combat-stuck decision (one display slot).
farmStuckSkipInfoV1234 := false
farmSkillPairV620 := false
cainAttachRetryAtV379 := 0
farmCloseRadiusV391 := 5
farmCloseAutoV391 := false
farmGroundItemCountV710 := 0
viewIdV54 := false
viewPosV291 := false
viewTipV640 := true
routeRecordDistanceV649 := 12
monsterLockNoDamageSecV621 := 5
monsterLockRoomSecV622 := 30
monsterSkipDistanceV752 := 4
stateBuffKeyV17 := ""
pestilenceKeyV18 := ""
deathlordStateV19 := 124
townLevelV22 := 241
outsideLevelV22 := 270
buffGetTextV22 := ""
zoneGetV22 := false
pestilenceStateV19 := 111
anathemaStateV518 := ""
anathemaKeyV518 := ""
entryBuffPendingV20 := false
pestiPointPendingV28 := false
farmLeftSkillV30 := -1, farmLeftPidV30 := 0, farmSetAttemptV30 := false
deathlordRetryAtV31 := 0
farmReviveV32 := false
reviveBuffPendingV34 := false
lastAttackPendingV20 := false
buffGetV20 := false
stateBuffCheckSecV17 := 3
coordInsertAnchorV57 := false
coordCastCountV50 := 0
coordCastPendingV50 := false
coordCastLastRowV50 := 0
combatMoveLastV48 := 0
monsterRoadAreaV51 := false
coordManualRowV59 := 0
coordGoV59 := false
coordRouteV16 := false
coordNearbyRowV18 := 0
bossPriorityClassesV221 := "", bossPriorityIdsV221 := {}
petBossGetTargetV222 := "PET"
petExcludeFileV12 := TxtRootPathV816("Pet-Loai-Tru.txt")
if (!FileExist(petExcludeFileV12) && FileExist(TxtRootPathV816("Auto-GSF-Pet-Loai-Tru.txt")))
    FileCopy, % TxtRootPathV816("Auto-GSF-Pet-Loai-Tru.txt"), %petExcludeFileV12%
manualLogOnV81 := false
manualLogClosingV81 := false
manualLogFolderV81 := ""
manualLogSessionV95 := ""
manualLogStartV81 := 0
autoMonsterExportV2 := false
autoMonsterAttackBusy := false
farmRunEpochV535 := 0
farmMapJournalRunV940 := false
farmMapJournalHoldEpochV940 := -1
farmMapJournalDeathStateV940 := {pid:0,dead:false,aliveAt:0,lastObserved:0}
autoMonsterPacketPendingV1 := false
packetWatchV1 := false
packetWatchArmedV1 := false
nativeAttackProbeV5 := false
nativeMapTemplateV5 := false
buffSetBaselineV500 := false
farmBuffExclusiveV621 := false
buffSetLeftOKV621 := false
nativeUnitTemplateV7 := {pid:0,player:0,flags:134,aux1:1,aux2:2,source:"OBSERVED_LOG9_RIGHT_UNIT"}
#InstallKeybdHook
#UseHook On
SendMode, Event
SetKeyDelay, 30, 30
SetWorkingDir, %A_ScriptDir%

cubeCtrlLogArmed := false
cubeCtrlLogExpire := 0

beltOneShotLogArmed := false
beltOneShotLogActive := false
beltBuffLogArmed := false
beltBuffLogActive := false
beltBuffLogHPDone := false
beltBuffLogMPDone := false
routeRecordV358 := false
OnExit, SavePositionOnExit
OnMessage(0x112, "WM_SYSCOMMAND_SavePos")
OnMessage(0x2B, "AutoGSFDrawTabV3")
OnMessage(0x111, "PetBossFocusV222")

CoordMode, Mouse, Client

ConfigFile := A_ScriptDir . "\txt\config.ini"
if (!FileExist(ConfigFile))
    EnsureDefaultConfigV8(ConfigFile)

cycleOn := false
farmBuffModeV509 := 0
cycle1On := true
buffSequenceOnV555 := false,buffSequenceRunningV555 := false,buffSequenceDelayV555 := 30000
buffSequenceNextV555 := 0,buffSequenceEpochV555 := 0,buffSequenceRunEpochV555 := 0

zRunning := false
xRunning := false
cycleStep := 1
nextStepTime := 0

zKey := ""
xKey := ""
xDelay := 200

zSetKey   := ""
zSetDelay := 200
zFKey     := ""
zFKey2    := ""
zDelay1   := 200
zDelay2   := 200
zDelay3   := 500

doubleKey := "Left"
doubleTapMs := 1000
lastDoubleKeyTime := 0
doubleKeyHeld := false

formDoubleKey := "Right"
formDoubleTapMs := 1000
lastFormDoubleKeyTime := 0
formDoubleKeyHeld := false

zSetKey := ""
zSetDelay := 200
zFKey := ""
zFKey2 := ""
zDelay1 := 200
zDelay2 := 200
zDelay3 := 500

configGuiVisible := true
configApplyOK := false
currentProfile := "Default"
profileList := "Default"

autoPotOn := false
invHealOn := false
invManaOn := false
cubeHealOn := false
cubeManaOn := false
invToCubeKey := "None"
cubePickupDelayMs := 50
cubeTransferDelayMs := 20
belt4HPKey := "None"
belt2HP2ManaKey := "None"
manaOn := false
manaMode := "Auto(1-4)"
manaThreshold := 1000
manaCooldown := 3000
potMode := "Auto(1-4)"
potCaptureKey1 := "n"
potHPThreshold := 10000
potHPThreshold2V299 := 5000
potFarCount := 0
potCooldown := 6000
potLastDrink := 0
potNextDrinkAtV730 := 0
manaLastDrink := 0
potCycle := 1
healExhausted := {HP: {Cube: false, Ruong: false, Belt: false}
    , Mana: {Cube: false, Ruong: false, Belt: false}}

pickupFarmWorkV75 := false
pickupImageOn := false
pickupOneShotV216 := false
pickupGroupActiveV26 := false
pickupStashListV217 := {}
pickupToggleKeyV79 := ""
sigActiveModeV182 := ""
sigKeyV147 := "", sigBusyV147 := false, sigCancelV147 := false, sigArmedV147 := 0, sigSendingKeyV147 := false
getIdKey := "g"
deleteIdKey := ""
rareWarningKeyV1 := ""
pickupStashKeyV14 := "^0", pickupSetKeyV14 := "^5", pickupSUKeyV14 := "^7"
sigTUV586 := false, sigSUV510 := false, sigSSUV13 := false, sigSSSUV13 := false
itemInspectKeyV287 := ""
excludeModeV329 := false
excludeDeleteModeV332 := false
pickupExcludeClassesV329 := {}
pickupAngelicSetIdsV13 := {}
libScrollTierV290 := 130
libFarmPinnedMapV2026 := false  ; Cache cho 130/133/136/139, khong phai cache map toan cuc
rareWarningHiddenV19 := false
rareWarningRulesV1 := {}
rareWarningLastKeyV1 := ""
pickupRadius := 4
pickupFailTeleRadiusV1253 := 4  ; BK teleport khi nhat loi, thay duoc tren GUI.
pickupLastClick := 0
pickupColorVariation := 60
pickupColors := []
pickupTargetLocked := false
pickupLockedX := 0
pickupLockedY := 0

pickupAllow := {}
pickupGroupOnlyV26 := ""
pickupDestinationV119 := ""
pickupToCubeV37 := true  ; Nhặt thường mặc định chuyển vào Cube, không cần checkbox.
pickupRows := []
pickupListLoaded := false
pickupFirstClass := 0
pickupFirstQuality := ""
pickupCubeTraceUntil := 0
pickupCubeTracePacket := false

form6ModeV716 := 1,form6KeyV716 := "",form6CountV716 := 4
FKey1 := "F3"
FKey2 := "F4"
FKey3 := "F5"
FKey4 := "F10"

FKey5 := ""
FKey6 := ""
FKey7 := ""
FKey8 := ""
FKey9 := ""
FKey10 := ""

FDelay1 := 200
FDelay2 := 200
FDelay3 := 200
FDelay4 := 3000

FDelay5 := 0
FDelay6 := 0
FDelay7 := 0
FDelay8 := 0
FDelay9 := 0
FDelay10 := 0

QCastKey1 := ""
QCastKey2 := ""
QCastKey3 := ""

QCastDelay1 := 0
QCastDelay2 := 0
QCastDelay3 := 0
QCastOn := false
castManualToggleV1801 := false
castToggleKeyV1801 := ""
IniRead, castToggleKeyV1801, %ConfigFile%, CastShortcut, Key, None
castToggleKeyV1801 := NormalizeOptionalKey(castToggleKeyV1801)

qCastDoubleKey := "None"
qCastDoubleTapMs := 1000
lastQCastDoubleKeyTime := 0
qCastDoubleKeyHeld := false

clickCastRows := []
Loop, 6
    clickCastRows.Push({key: "", delay: 0, last: A_TickCount})
clickCastOn := false
clickCastDoubleKey := "None"
clickCastDoubleTapMs := 1000
lastClickCastTap := 0
clickCastHeld := false

master456Paused := false
master456Saved := {}
master456Key := "None"
Gosub, ShowConfig
LoadConfig()
PickupListLoadV87()
UniquePickupCleanDuplicateV19()
RareWarningLoadV1()
PickupGroupBindV14()
PickupExcludeLoadV329()

if (rareWarningKeyV1 != "")
    BackgroundHotkeyV63("~$" . rareWarningKeyV1,"RareWarningGetHandlerV1","On")

if (zKey != "")
    BackgroundHotkeyV63("~$" . zKey,"ZKeyHandler","On")

if (xKey != "")
        BackgroundHotkeyV63("~$" . xKey,"XKeyHandler","On")

if (belt4HPKey != "" && belt4HPKey != "None")
    BackgroundHotkeyV63("~$" . belt4HPKey,"Belt4HPHandler","On")
if (belt2HP2ManaKey != "" && belt2HP2ManaKey != "None")
    BackgroundHotkeyV63("~$" . belt2HP2ManaKey,"Belt2HP2ManaHandler","On")
if (invToCubeKey != "" && invToCubeKey != "None")
    BackgroundHotkeyV63("~$" . invToCubeKey,"InvToCubeHandler","On")

ToolDoubleBindV18(doubleKey,"DoubleKeyHandler","On")

ToolDoubleBindV18(formDoubleKey,"FormDoubleKeyHandler","On")

ToolDoubleBindV18(qCastDoubleKey,"QCastDoubleKeyHandler","On")
ToolDoubleBindV18(clickCastDoubleKey,"ClickCastDoubleHandler","On")
if (master456Key != "")
    BackgroundHotkeyV63("~$" . master456Key,"Master456Handler","On")


SetTimer, Cycle1Timer, 20
SetTimer, AutoPotTimer, 150
SetTimer, QCastTimer, 20
if (castToggleKeyV1801!="")
    BackgroundHotkeyV63("~$" . castToggleKeyV1801,"CastToggleHandlerV1801","On UseErrorLevel")
SetTimer, PickupImageTimer, 50
FarmWatchStartV5()
SetTimer, FarmResetWatchTimerV217, 1000

SetTimer, V2CubeWatchTimer, Off
SetTimer, V9CubeIdentityTimer, Off
SetTimer, V23CtrlLeftTimer, Off

qCastLast1 := A_TickCount
qCastLast2 := A_TickCount
qCastLast3 := A_TickCount
if (FonTrackingEnableV410())
{
    ; V845: F-ON follows the live position. Do NOT discard a loaded map at startup.
    ; The timer will load a map only if no valid route is loaded or its identity changes.
    CoordCurrentReadV15()
}
manualCastInput := InputHook("V L0")
manualCastInput.MinSendLevel := 0
manualCastInput.KeyOpt("{All}", "N")
manualCastInput.OnKeyDown := Func("ManualCastKeyDown")
manualCastInput.Start()
return

; Ordered parts preserve the original label and function order.
#Include %A_ScriptDir%\lib\01-runtime-and-buff.ahk
#Include %A_ScriptDir%\lib\02-potions-and-pickup.ahk
#Include %A_ScriptDir%\lib\03-cube-and-farm-core.ahk
#Include %A_ScriptDir%\lib\04-farm-and-coordinates.ahk
#Include %A_ScriptDir%\lib\05-map-and-room-flow.ahk
#Include %A_ScriptDir%\lib\06-room-and-sig-flow.ahk
#Include %A_ScriptDir%\lib\07-sig-and-farm-controls.ahk
#Include %A_ScriptDir%\lib\08-map-workflows.ahk
#Include %A_ScriptDir%\lib\09-library-and-route-plans.ahk
#Include %A_ScriptDir%\lib\10-farm-recovery.ahk
#Include %A_ScriptDir%\lib\11-pickup-and-logging.ahk
