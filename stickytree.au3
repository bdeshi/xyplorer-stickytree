#cs
  sticky-tree.au3
  The AutoIt component to the XYplorer Sticky Tree script.
  https://www.xyplorer.com/xyfc/viewtopic.php?f=7&t=20154
  Called from XYplorer as: stickytree.au3 <xyhwnd> [$ctbindex]
  Required AutoIt version: at least Beta 3.3.15.1
#ce
#cs icon terms or use
  The stickytree.ico file is generated from the bamboo.png icon of
  FatCow's "farm-fresh" iconset: http://www.fatcow.com/free-icons.
  Licensed under a Creative Commons Attribution 3.0 license.
#ce icon terms or use

#Region AutoIt3Wrapper directives section
  #AutoIt3Wrapper_Version=B
  #AutoIt3Wrapper_Icon=stickytree.ico
  #AutoIt3Wrapper_Res_Description=XYplorerStickyTree
  #AutoIt3Wrapper_Compression=4
  #AutoIt3Wrapper_Res_Fileversion=0.9.9.8
  #AutoIt3Wrapper_Res_FileVersion_AutoIncrement=P
  #AutoIt3Wrapper_Res_Fileversion_First_Increment=Y
  #AutoIt3Wrapper_Run_Tidy=Y
  #Tidy_Parameters=/tc 2 /ri /reel
  ; Au3Stripper Settings
  #AutoIt3Wrapper_Run_Au3Stripper=Y
  #Au3Stripper_Parameters=/pe /so /rm /Beta
  #AutoIt3Wrapper_Au3stripper_OnError=S
  #AutoIt3Wrapper_Au3Check_Parameters=-d -w 3 -w 4 -w 6
#EndRegion AutoIt3Wrapper directives section

#include <windowsconstants.au3>
#include <WinAPISysWin.au3>
#include <SendMessage.au3>
#include <StringConstants.au3>
#NoTrayIcon

If $CmdLine[0] < 1 Then Exit
; ==> config
Global $gHorizontalListPosition = 0 ; Default position of list in horizontal split
Global $gVerticalListCenter = 0 ; autocenter panes in vertical split
Global $gEqualizeNavWidth = 1 ; set equal left and right navpanel widths
; ==> config

Global $gReceivedData = ''
Global $gReceivedDataLast = ''
Global Const $gXyHandle = HWnd(Int($CmdLine[1]))
; Global Const $gXyPID = WinGetProcess($gXyHandle)
Global Const $gMyHandle = GUICreate('XYplorerStickyTree')
GUIRegisterMsg($WM_COPYDATA, 'XyReceiveData') ; Au3Stripper Point of Concern
GUISetState(@SW_HIDE, $gMyHandle)
Global Const $gGetLayoutScript = '::' & _
    'copydata ' & $gMyHandle & ', "' & _
    'Toggle=$P_STICKYTREE_TOGGLE,' & _
    'Pane=" . get(''Pane'') . ",' & _
    'P1Height=" . gettoken(controlposition(''L 1''),   4, ''|'') . ",' & _
    'P2Height=" . gettoken(controlposition(''L 2''),   4, ''|'') . ",' & _
    'SBHeight=" . gettoken(controlposition(''SB''),    4, ''|'') . ",' & _
    'BCHeight=" . gettoken(controlposition(''BC 1''),  4, ''|'') . ",' & _
    'TBHeight=" . gettoken(controlposition(''TAB 1''), 4, ''|'') . ","' & _
    '. setlayout(), 0;'

#cs disable update when tooltips/hovers are open.
  match by class + parent_xy_pid
  tooltip class:  tooltips_class32
  hoverbox class: ??
#ce disable update when tooltips/hovers are open.

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
While True
  Sleep(10)
  If WinExists($gXyHandle) = 0 Then
    ExitApp()
  EndIf
  XySendData($gGetLayoutScript)
  If ($gReceivedData <> $gReceivedDataLast) Then
    ProcessReceivedData()
  EndIf
WEnd

Func ProcessReceivedData()  ;==> update layout based on $gReceivedData
  Local $execScript = '::setlayout("'
  Local $layout = LayoutStrToArray()
  #cs syntax check fails to detect Assign()-generated vars
  For $key In MapKeys($layout)
    Assign($key, $layout[$key], 1)
  Next
  #ce syntax check fails to detect Assign()-generated vars
  If $layout['DP'] = 0 Or $layout['Toggle'] <> 1 Then
    ExitApp()
  Else
    $execScript &= 'ShowTree=1,ShowNav=1,'

    ; ==== horizontal tabs ====
    If $layout['DPHorizontal'] = 1 Then
      $execScript &= 'TreeCatalogStacked=1,ShowCatalog=1,'
      If $layout['ListPosition'] = 1 Then
        $execScript &= 'ListPosition=' & $gHorizontalListPosition & ','
      EndIf
      Local $catFirst, $catHeight
      If $layout['Pane'] = 1 Then
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
      ; allow unstacking
      If $layout['TreeCatalogStacked'] = 0 Then
        $execScript &= 'ListPosition=1,'
        $layout['ListPosition'] = 1
      EndIf
      If $layout['ListPosition'] = 1 Then
        $execScript &= 'CatalogFirst=' & (($layout['Pane'] = 1) ? 0 : 1) & ','
      Else
        $execScript &= 'TreeCatalogStacked=1,ListPosition=' & (($layout['Pane'] = 1) ? 0 : 2) & ','
      EndIf
    EndIf
  EndIf
  $execScript &= '");'
  XySendData($execScript)
  Return True
EndFunc   ;==>ProcessReceivedData

Func ExitApp()
  ; reset layout
  XySendData('::unset $P_STICKYTREE_TOGGLE;')
  Exit
EndFunc   ;==>ExitApp

Func LayoutStrToArray()  ;==> Converts layout info in $gReceivedData to a hashmap
  Local $mLayout[], $sKey, $sValue
  For $sProperty In StringSplit($gReceivedData, ",", $STR_NOCOUNT)
    $sKey = StringSplit($sProperty, "=", $STR_NOCOUNT)[0]
    $sValue = StringSplit($sProperty, "=", $STR_NOCOUNT)[1]
    $mLayout[$sKey] = Int($sValue)
  Next
  Return $mLayout
EndFunc   ;==>LayoutStrToArray

#cs
  typedef struct tagCOPYDATASTRUCT {
    ULONG_PTR dwData; // The data to be passed to the receiving application. See SC copydata ref.
    DWORD     cbData; // The size, in bytes, of the data pointed to by the lpData member.
    PVOID     lpData; // Pointer to The data to be passed to the receiving application.
  } COPYDATASTRUCT, *PCOPYDATASTRUCT;
#ce
Func XySendData($data) ;==> send data to XY via WM_COPYDATA
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
EndFunc   ;==>XySendData

Func XyReceiveData($_hWnd, $_msg, $wParam, $lParam) ;==> get data from XY via WM_COPYDATA
  $gReceivedDataLast = $gReceivedData
  If ($wParam = $gXyHandle) Then
    Local $copyDataStruct = DllStructCreate('dword dwData;dword cbData;ptr lpData', $lParam)
    Local $lpData = DllStructGetData($copyDataStruct, 'lpData')
    Local $dataSize = DllStructGetData($copyDataStruct, 'cbData') / 2
    Local $dataStruct = DllStructCreate('wchar data[' & $dataSize & ']', $lpData)
    $gReceivedData = DllStructGetData($dataStruct, 'data')
  EndIf
  Return True
EndFunc   ;==>XyReceiveData
