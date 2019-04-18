#cs
  sticky-tree.au3
  The AutoIt component to the XYplorer Sticky Tree script.
  https://www.xyplorer.com/xyfc/viewtopic.php?f=7&t=20154
  Called from XYplorer as: stickytree.au3 <hwnd> [$ctbindex]
  Required AutoIt version: >= 3.3.15.1
#ce
#cs icon terms of use
  The stickytree.ico file is generated from the bamboo.png icon of
  FatCow's "farm-fresh" iconset: http://www.fatcow.com/free-icons.
  Licensed under a Creative Commons Attribution 3.0 license.
#ce icon terms of use

#Region ; AutoIt3Wrapper directives section
  #AutoIt3Wrapper_Version=Beta
  #AutoIt3Wrapper_Icon=stickytree.ico
  #AutoIt3Wrapper_Compression=4
  #AutoIt3Wrapper_UseX64=n
  #AutoIt3Wrapper_Res_Description=XYplorerStickyTree
  #AutoIt3Wrapper_Res_Fileversion=1.0.0.0
  #AutoIt3Wrapper_Res_Fileversion_AutoIncrement=P
  #AutoIt3Wrapper_Res_Fileversion_First_Increment=Y
  #AutoIt3Wrapper_AU3Check_Parameters=-d -w 4 -w 5 -w 6
  #AutoIt3Wrapper_Run_Tidy=Y
  #Tidy_Parameters=/tc 2 /ri /reel
  #AutoIt3Wrapper_Run_Au3Stripper=Y
  #Au3Stripper_Parameters=/pe /so /rm /Beta
  #AutoIt3Wrapper_Au3stripper_OnError=S
#EndRegion ; AutoIt3Wrapper directives section

#include <WindowsConstants.au3>
#include <SendMessage.au3>
#include <WinAPISysWin.au3>
#include <WinAPIProc.au3>
#include <StringConstants.au3>

#NoTrayIcon
Opt("WinWaitDelay", 10)

If $CmdLine[0] < 1 Then Exit

; ==> config TODO: make GUI control panel
Global $gHorizontalListPosition = 0 ; Default position of list in horizontal split
Global $gVerticalListCenter = 0 ; autocenter panes in vertical split
Global $gEqualizeNavWidth = 1 ; set equal left and right navpanel widths
Global $gRestoreLayout = 1 ; on quit, restore layout to as it was before starting
; ==> config TODO: make GUI control panel

Global Const $gXyHandle = HWnd(Int($CmdLine[1]))
Global Const $gCTBIndex = $CmdLine[0] > 1 ? Int($CmdLine[2]) : -1
Global Const $gMyHandle = GUICreate('XYplorerStickyTree')
GUIRegisterMsg($WM_COPYDATA, 'ReceiveData')  ; au3stripper point of concern
GUISetState(@SW_HIDE, $gMyHandle)
#cs
  // setlayout() doesn't return up-to-date sizes, controlposition does.
  copydata 0x001C068C,
    "Toggle=$P_STICKYTREE_TOGGLE,Pane=" . get('Pane')
    . ",P1Height=" . gettoken(controlposition('L 1'),   4, '|')
    . ",P2Height=" . gettoken(controlposition('L 2'),   4, '|')
    . ",SBHeight=" . gettoken(controlposition('SB'),    4, '|')
    . ",BCHeight=" . gettoken(controlposition('BC 1'),  4, '|')
    . ",TBHeight=" . gettoken(controlposition('TAB 1'), 4, '|')
    . "," . setlayout(), 0;
#ce
Global Const $gGetLayoutScript = "::copydata " & $gMyHandle & ', "' & _
    "Toggle=$P_STICKYTREE_TOGGLE,Pane="" . get('Pane') . ""," & _
    "P1Height="" . gettoken(controlposition('L 1'),   4, '|') . ""," & _
    "P2Height="" . gettoken(controlposition('L 2'),   4, '|') . ""," & _
    "SBHeight="" . gettoken(controlposition('SB'),    4, '|') . ""," & _
    "BCHeight="" . gettoken(controlposition('BC 1'),  4, '|') . ""," & _
    "TBHeight="" . gettoken(controlposition('TAB 1'), 4, '|') . "","" . " & _
    "setlayout(), 0;"
Global $gReceivedData = Null
Global $_ = Null

#cs
ControlGetFocus() can interfere with [mouse] input
because it calls AttachThreadInput which resets key state
So set up AttachThreadInput beforehand
#ce
Global Const $gXyThread = _WinAPI_GetWindowThreadProcessId($gXyHandle, $_)
Global Const $gMyThread = _WinAPI_GetCurrentThreadId()
Global Const $gThreadAttached = _WinAPI_AttachThreadInput($gMyThread, $gXyThread, True)
If Not $gThreadAttached Then Exit

; make sure only one copy is running
SendReceive("::copydata " & $gMyHandle & ", isset($P_STICKYTREE_HWND), 0;")
If Int($gReceivedData) Then Exit

; stop if dual pane disabled
SendReceive("::copydata " & $gMyHandle & ", get('#800'), 0;")
If Not Int($gReceivedData) Then Exit

; toggle ctb state
If $gCTBIndex > -1 Then
  SendData("::ctbstate(1," & $gCTBIndex & ");")
EndIf

; get classname of AB, for avoiding AB dropdown interruption
SendReceive("::copydata " & $gMyHandle & ', setlayout(), 0;')
If StringInStr($gReceivedData, 'ShowAddressbar=1') Then
  SendData("::focus 'A';")
  $_ = ControlGetFocus($gXyHandle)
Else
  SendData("::setlayout(ShowAddressbar=1);focus 'A';")
  $_ = ControlGetFocus($gXyHandle)
  SendData("::setlayout(ShowAddressbar=0);")
EndIf
Global Const $gClassAB = $_

; store pre-exec pane focus
SendData("::focus 'L';")
Global $gClassLastPane = ControlGetFocus($gXyHandle)

; get classname of pane 1 & pane 2
SendData("::focus 'P1';")
Global Const $gClassP1 = ControlGetFocus($gXyHandle)
SendData("::focus 'P2';")
Global Const $gClassP2 = ControlGetFocus($gXyHandle)

; restore pre-exec pane focus
If $gClassLastPane = $gClassP1 Then
  SendData("::focus 'P1';")
EndIf

;==> main loop vars
Global $gTriggerUpdate = False
Global $gActivePane = 0
Global $gLastPane = -1
Global $gLastPaneDim = 0
Global $gPaneDim = -1

;==> main loop
While True
  If Not WinExists($gXyHandle) Then Exit
  If Not WinActive($gXyHandle) Then ContinueLoop
  ; polling for focus when AB active interrupts AB dropdown
  If ControlGetFocus($gXyHandle) = $gClassAB Then ContinueLoop
  $gTriggerUpdate = False
  $gActivePane = 0
  ; activepane is used in layoutupdater so must be always up-do-date
  Switch ControlGetFocus($gXyHandle)
    Case $gClassP1
      $gActivePane = 1
    Case $gClassP2
      $gActivePane = 2
  EndSwitch
  ; update layout on active pane change
  If $gActivePane > 0 And $gActivePane <> $gLastPane Then
    $gLastPane = $gActivePane
    $gTriggerUpdate = True
  EndIf
  ; update layout on pane size change
  If Not $gTriggerUpdate Then
    $gPaneDim = GetPaneDim($gClassP1) & "," & GetPaneDim($gClassP2)
    If $gPaneDim <> $gLastPaneDim Then
      $gLastPaneDim = $gPaneDim
      $gTriggerUpdate = True
    EndIf
  EndIf
  If $gTriggerUpdate Then
    SendReceive($gGetLayoutScript)
    ProcessReceivedData()
  EndIf
WEnd
Exit

Func ExitApp()
  Local $execScript = '::unset $P_STICKYTREE_TOGGLE;'
  ; detach thread input
  If $gThreadAttached Then
    _WinAPI_AttachThreadInput($gMyThread, $gXyThread, False)
  EndIf
  ; unset relevant ctbstate (if any)
  If $gCTBIndex > -1 Then
    $execScript &= 'ctbstate(0,' & $gCTBIndex & ');'
  EndIf
  SendData($execScript)
  Exit
EndFunc   ;==>ExitApp

Func ProcessReceivedData()  ;==> update layout based on $gReceivedData
  #cs received data
    Toggle=0,Pane=1,P1Height=251,P2Height=308,SBHeight=24,BCHeight=23,TBHeight=23,
    DP=1,DPHorizontal=1,ShowMainMenu=1,ShowAddressbar=1,ShowToolbar=1,ShowTabs=1,
    ShowCrumb=1,ShowFilter=0,ShowStatusbar=1,ShowStatusbarButtons=1,ShowNav=1,
    ShowTree=1,ShowCatalog=1,ShowPreviewPane=0,ShowInfoPanel=0,ABTBStacked=1,
    ToolbarFirst=1,TreeCatalogStacked=0,CatalogFirst=0,ListPosition=0,TabsWide=0,
    InfoPanelWide=1,NavWidthLeft=154,NavWidthRight=154,CatalogWidth=154,CatalogHeight=297,
    Pane1Width=456,Pane2Width=560,Pane1Height=246,Pane2Height=207,PreviewPaneWidth=280,
    InfoPanelHeight=196,InfoPanelHeightJump=0,LiveFilterInStatusBar=0
  #ce received data
  Local $layout = LayoutStrToArray($gReceivedData)
  $gReceivedData = Null
  ; note: $gActivePane seems more reliable than $layout['Pane']

  If $layout['DP'] = 0 Or $layout['Toggle'] <> 1 Then ExitApp()
  Local $execScript = "::setlayout('"
  $execScript &= 'ShowTree=1,ShowNav=1,'

  ; ==== horizontal tabs ====
  If $layout['DPHorizontal'] = 1 Then
    $execScript &= 'TreeCatalogStacked=1,ShowCatalog=1,'
    If $layout['ListPosition'] = 1 Then
      $execScript &= 'ListPosition=' & $gHorizontalListAlign & ','
    EndIf
    Local $catFirst, $catHeight
    If $gActivePane = 1 Then
      $catFirst = 0
      $catHeight = $layout['P2Height'] + (($layout['InfoPanelWide'] = 1) ? 0 : $layout['SBHeight'])
    Else
      $catFirst = 1
      $catHeight = $layout['P1Height']
    EndIf
    $catHeight += (($layout['ShowCrumb'] = 1) ? $layout['BCHeight'] : 0) + _
        (($layout['ShowTabs'] = 1) ? $layout['TBHeight'] : 0)
    $execScript &= 'CatalogFirst=' & $catFirst & ',CatalogHeight=' & $catHeight & ','

    ; ===== vertical tabs =====
  Else
    If $layout['TreeCatalogStacked'] = 0 Then
      $execScript &= 'ListPosition=1,'
      $layout['ListPosition'] = 1
    EndIf
    If $layout['ListPosition'] = 1 Then
      $execScript &= 'CatalogFirst=' & (($gActivePane = 1) ? 0 : 1) & ','
    Else
      $execScript &= 'TreeCatalogStacked=1,ListPosition=' & (($gActivePane = 1) ? 0 : 2) & ','
    EndIf
  EndIf
  $execScript &= "');"
  SendData($execScript)
  Return True
EndFunc   ;==>ProcessReceivedData

Func LayoutStrToArray($layoutStr)  ;==> Converts layout info in $gReceivedData to a hashmap
  Local $mLayout[], $sKey, $sValue
  For $sProperty In StringSplit($layoutStr, ",", $STR_NOCOUNT)
    $sKey = StringSplit($sProperty, "=", $STR_NOCOUNT)[0]
    $sValue = StringSplit($sProperty, "=", $STR_NOCOUNT)[1]
    $mLayout[$sKey] = Int($sValue)
  Next
  Return $mLayout
EndFunc   ;==>LayoutStrToArray

Func GetPaneDim($class)  ;==> Return a hash of pane positions
  If Not WinExists($gXyHandle) Then Exit ; MAGIC to stop orphan process bug. why here? I don't know
  Local $sPos = ""
  Local $aPos = ControlGetPos($gXyHandle, '', "[CLASSNN:" & $class & "]")
  For $iData In $aPos
    $sPos &= "," & String($iData)
  Next
  $sPos = StringTrimLeft($sPos, 1)
  Return $sPos
EndFunc   ;==>GetPaneDim

Func SendReceive($str)  ;==> Send Data and wait until some data received
  $gReceivedData = Null
  SendData($str)
  While $gReceivedData = Null And WinExists($gXyHandle)
    ContinueLoop
  WEnd
  Return
EndFunc   ;==>SendReceive

#cs
  typedef struct tagCOPYDATASTRUCT {
    ULONG_PTR dwData; // The data to be passed to the receiving application. See SC copydata ref.
    DWORD     cbData; // The size, in bytes, of the data pointed to by the lpData member.
    PVOID     lpData; // Pointer to The data to be passed to the receiving application.
  } COPYDATASTRUCT, *PCOPYDATASTRUCT;
#ce
Func SendData($data) ;==> send WM_COPYDATA to Xy
  Local $dwData = 0x00400001   ; copydata mode 1: execute data as script
  Local $dataSize = StringLen($data)
  Local $dataStruct = DllStructCreate('wchar data[' & $dataSize & ']')
  Local $copyDataStruct = DllStructCreate('dword dwData;dword cbData;ptr lpData')
  DllStructSetData($dataStruct, 'data', $data)
  DllStructSetData($copyDataStruct, 'dwData', $dwData)
  DllStructSetData($copyDataStruct, 'cbData', $dataSize * 2)   ; $dataSize is 2bytes per wchar
  DllStructSetData($copyDataStruct, 'lpData', DllStructGetPtr($dataStruct))
  _SendMessage($gXyHandle, $WM_COPYDATA, $gMyHandle, DllStructGetPtr($copyDataStruct))
  Return True
EndFunc   ;==>SendData

Func ReceiveData($_hWnd, $_msg, $wParam, $lParam) ;==> get WM_COPYDATA from Xy
  If ($wParam = $gXyHandle) Then
    Local $copyDataStruct = DllStructCreate('dword dwData;dword cbData;ptr lpData', $lParam)
    Local $lpData = DllStructGetData($copyDataStruct, 'lpData')
    Local $dataSize = DllStructGetData($copyDataStruct, 'cbData') / 2
    Local $dataStruct = DllStructCreate('wchar data[' & $dataSize & ']', $lpData)
    $gReceivedData = DllStructGetData($dataStruct, 'data')
    If ($dataSize = 0) Then $gReceivedData = ''
  EndIf
  Return True
EndFunc   ;==>ReceiveData
