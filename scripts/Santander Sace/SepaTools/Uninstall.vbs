Option Explicit
On Error Resume Next
'
'**********************************************************************************
'							Constantes Globales Aplicacion
'**********************************************************************************
'
	Const REGDPL32	= "Software\Microsoft\Deployment\"				' Datos Despliege
	Const REGDPL64	= "Software\Wow6432Node\Microsoft\Deployment\"	' Datos Despliege
	Const REGAPL32	= "Software\Paquetes"							' Clave Registro Aplicacion
	Const REGAPL64	= "Software\Wow6432Node\Paquetes"				' Clave Registro Aplicacion
	Const DIR_PROG 	= "Prog"								  		' Subdirectorio Software
	Const DIR_LOG 	= "C:\LOGS"										' Directorio Fichero LOG	
	Const W2K	 	= "5.0"											' Version S.O. Windows 2000
	Const WXP	 	= "5.1"											' Version S.O. Windows XP
	Const W7E	 	= "6.1"											' Version S.O. Windows 7
	Const W8E	 	= "6.3"											' Version S.O. Windows 8				
	Const W10		= "10.0"										' Version S.O. Windows 10			
	Const OS_32	 	= 32											' Sistema Operativo 32 Bits
	Const OS_64	 	= 64											' Sistema Operativo 64 Bits	
	Const APPL_32 	= "32"											' Aplicacion Solo 32 Bits
	Const APPL_64 	= "64"											' Aplicacion Solo 64 Bits
	Const APPL_XX 	= "32/64"										' Aplicacion 32 y 64 Bits	
	Const APPL_WOW 	= "WOW"											' Aplicacion 32/64 Bits		
	Const IPL_REQ 	= 3010											' IPL Requerido	
'
'**********************************************************************************
'							Constantes Globales Sistema
'**********************************************************************************
'
	Const HKCR			= &H80000000 		' Clave Reg HKEY_CLASSES_ROOT
	Const HKCU			= &H80000001 		' Clave Reg HKEY_CURRENT_USER
	Const HKLM			= &H80000002 		' Clave Reg HKEY_LOCAL_MACHINE
	Const HKUS			= &H80000003 		' Clave Reg HKEY_USERS
	Const HKCC			= &H80000005 		' Clave Reg HKEY_CURRENT_CONFIG
	Const ForReading	= 1					' Abrit Fichero para lectura
	Const ForWriting	= 2					' Abrir Fichero para escritura
	Const ForAppending	= 8					' Abrit Fichero para anexar datos
'
'**********************************************************************************
'							Variables Globales
'**********************************************************************************
'
	Dim Rc						' Codigo de Retorno de las funciones
	Dim Bits_Arq				' Tipo de procesador 32 o 64 Bits
	Dim Bits_OS					' Version de S.O. Instalada (32 o 64 Bits)
	Dim RegApl					' HKLM\Software/HKLM\Software\Wow6432Node (Paquetes)
	Dim RegDpl					' HKLM\Software/HKLM\Software\Wow6432Node (Deployment)
	Dim Bits_Appl				' Aplicacion 32, 64, 32/54 Bits
	Dim Aplicacion				' Nombre de la Aplicación
	Dim AppToUnInst				' Aplicacion a Desinstalar
	Dim Descrip					' Descripción de la Aplicación	
	Dim Version					' Versión de la Aplicación
	Dim VerDis					' Versión del Distribuidor
	Dim VerSO					' Version S.O.
	Dim OsLanguage				' Idioma S.O.
	Dim Puesto					' Nombre de Puesto
	Dim Dominio					' Dominio del Puesto
	Dim Usuario					' Usuario que ejecuta el módulo
	Dim WShell					' Objeto "WSCript.shell"
	Dim ShellAp					' Objeto "shell.application"
	Dim FSO						' Objeto "Scripting.FileSystemObject"
	Dim RutaOrigen				' Path donde se encuentar INSTALAR.VBS
	Dim RutaProg				' Path PROG = RutaOrigen + DirProg
	Dim LogFile					' (DirLog + Aplicacion) (XML-LOGFILE)
	Dim DirWindows				' Directorio Windows
	Dim ProgFiles				' Directorio de "ProgramFiles"
	Dim ProgData				' Directorio de "ProgramData"
	Dim CommonProgFiles			' Directorio de "CommonProgramFiles"
	Dim UsersDesktop			' Directorio de "All Users\desktop"
	Dim AllUsersMenu			' Directorio de "All Users\Menu"
	Dim AllUsersPrograms		' Directorio de "All Users\Menu\Programs"
	Dim AllUsersStartup			' Directorio de "All Users\Menu\Programs\Startup"
	Dim PathSys					' Directorio System32 / SysWOW64
	Dim Comando					' Variable para ejecutable del Comando de Ejecucion
'
'**********************************************************************************
'								Inicializar Variables
'**********************************************************************************
'
	Rc = IniciarVariables()									' Crear Objetos / Iniciar Variables
	Rc = ObtenerDatosXML(RutaOrigen & "\Desinstalar.xml")	' Buscar / Obtener Datos Fichero .....DSH.XML
	Rc = PersonalizarVariables()							' Compone Variables segun OS y Aplicacion (32/64)
	Rc = CrearFicheroLog()									' Buscar / Crear Fichero C:\LOGS\......LOG
	Rc = CabeceraLog()										' Componer Cabecera Fichero LOG
	Rc = ComprobarApplOS()									' Comprobar Compatibilidad Appl / OS
'
'**********************************************************************************
'					PONER :	Campo Descripcion Fichero XML
'**********************************************************************************
'
	Dim RetEnd
	Dim Arra_7Zt
	Dim Z7t
	Dim Run7z
	Dim Para1
	Dim Ruta
	Dim Des
	Dim Code_Array
	Dim Desis
	Dim Lite
	Dim Regi
	Dim Regsr_Array
	Dim Regsr
	Dim Ori
	Dim Exis
	Dim Path
	Dim colProcessList
	Dim Encontrado
	Dim objProcess
	Dim Todos
	Dim Pro_App
	Dim Pro_App_Array

	RetEnd = 0
	If Bits_OS = 32 then
		Rc = EscribeLog (RetEnd,"-- ENTORNO 32")
		Regi = "\SOFTWARE"
		Path = "C:\PROGRA~1"
	End IF
	If Bits_OS = 64 then
		Rc = EscribeLog (RetEnd,"-- ENTORNO 64")
		Regi = "\SOFTWARE\Wow6432Node"
		Path = "C:\PROGRA~2"
	End If
	
'-----------------------------Modulo Localizacion Proceso app abierta------------------------------------- 	
	Todos = 1
	Pro_App_Array = Array (	"SEPAtools.exe")
	For Each Pro_App in Pro_App_Array
		Set colProcessList = GetObject("Winmgmts:").ExecQuery ("Select * from Win32_Process")
		For Each objProcess in colProcessList
			If objProcess.name = Pro_App then
				Encontrado = "SI"
			End if
		Next
			If Encontrado = "SI" Then
				If Todos = 0 Then	
					RetEnd = WShell.Run ("cmd /c msg * /time:120 /w ACTUALIZACION APP DISPONIBLE POR FAVOR CIERRE LA APLICACION Y PULSE ACEPTAR PARA CONTINUAR LA ACTUALIZACION. EN 2 MINUTOS LA APLICACION SE CERRARA AUTOMATICAMENTE",0,True)
				End If
				RetEnd = MatarProceso (Pro_App)
				If RetEnd = 0 Then
					RetEnd = 0
					Todos = 1
					Rc = EscribeLog (RetEnd,"-- PROCESO " & Pro_App & " TERMINADO OK")
				Else
					RetEnd = 9997
					Rc = EscribeLog (RetEnd,"-- PROCESO " & Pro_App & " TERMINADO KO")
					Rc = FinalizarProceso(RetEnd)
				End If
			End If
		colProcessList= Empty
	Next	

'------------------DESINSTALACION---------------------------------------
	Code_Array = Array ("{B45F0F8F-715D-4949-A708-8931C5BBBE58}",_
						"{B45F0F8F-715D-4949-A708-8931C5BBBE58}")
'-----------DESISTALACION---------------------------------------------------------------------
	For Each Desis In Code_Array 
			Lite = wShell.RegRead ("HKEY_LOCAL_MACHINE" & Regi & "\Microsoft\Windows\CurrentVersion\Uninstall\" & Desis & "\DisplayName")
			Lite = Lite & " " & wShell.RegRead ("HKEY_LOCAL_MACHINE" & Regi & "\Microsoft\Windows\CurrentVersion\Uninstall\" & Desis & "\DisplayVersion")
			RetEnd = WShell.run ("MsiExec.exe /x " & Desis & " /qn /norestart",0,True)
			Select Case RetEnd
				Case 0
					Rc = EscribeLog (RetEnd,"-- " & Aplicacion & " VERSION: " &  Lite & " DESISTALADO OK")
					FSO.DeleteFolder Path &"\SEPAtools"
					RetEnd = 0
				Case 1605
					RetEnd = 0
				Case 1618
						Rc = EscribeLog (RetEnd,"-- " & Aplicacion & " DESINSTALACION KO OTRA INSTALACION EN CURSO")
				Case 3010
					Rc = EscribeLog (RetEnd,"-- " & Aplicacion & " VERSION: " &  Lite & " DESISTALADO OK REINICIO REQUERIDO")					
					FSO.DeleteFolder Path &"\SEPAtools"
				Case Else
					Rc = EscribeLog (RetEnd,"-- " & Aplicacion & " VERSION: " &  Lite & " DESISTALADO KO")
			End Select
	Next	
	WScript.Sleep (1000)
	If RetEnd = 0 Or RetEnd = 3010 Then
		RetEnd = WShell.Run ("cmd /c rd " & Path & "\SEPAtools /S /Q",0,True)
		RetEnd = 0
	End If
'
'**********************************************************************************
'						 FINALIZAR PROCESO DE USUARIO
'**********************************************************************************
'
	Rc = EscribeLog (RetEnd,"-- VERSION FABRICANTE:" & VerDis)
    Rc = EscribeLog (RetEnd,"-- VERSION INTERNA:" & Version)	
	Rc = FinalizarProceso(RetEnd)
'
'**********************************************************************************
'			 IniciarVariables : Carga de las Variables Globales
'**********************************************************************************
'

Function IniciarVariables()
	On Error Resume Next

	Dim objWMIService, colSettings, objProcessor
	
	Set objWMIService = GetObject("winmgmts:\\.\root\CIMV2")
	Set colSettings	= objWMIService.ExecQuery("SELECT * FROM Win32_Processor")
	For Each objProcessor In colSettings
		Bits_Arq = objProcessor.DataWidth
		Bits_OS  = objProcessor.AddressWidth
	Next
	
	Set FSO				= CreateObject("Scripting.FileSystemObject")
	Set WShell			= CreateObject("WSCript.shell")
	Set ShellAp  		= CreateObject("shell.application")
	UsersDesktop 		= WShell.SpecialFolders("AllUsersDesktop")
	AllUsersMenu 		= WShell.SpecialFolders("AllUsersStartmenu")
	AllUsersPrograms	= WShell.SpecialFolders("AllUsersPrograms")
	AllUsersStartup 	= WShell.SpecialFolders("AllUsersStartup")
	ProgData 			= WShell.ExpandEnvironmentStrings("%ProgramData%")	
	DirWindows			= UCase(WShell.ExpandEnvironmentStrings("%SystemRoot%"))
	RutaOrigen			= FSO.GetParentFolderName(WScript.ScriptFullName)
	RutaProg	 		= RutaOrigen & "\" & DIR_PROG
	
	If Bits_OS = OS_64 Then
		RegApl = REGAPL64
		RegDpl = "HKLM\" & REGDPL64
	Else		
		RegApl = REGAPL32
		RegDpl = "HKLM\" & REGDPL32	
	End If	

	IniciarVariables = 0	

End Function
'
'**********************************************************************************
'			 PersonalizarVariables : Carga de las Variables Globales
'**********************************************************************************
'
Function PersonalizarVariables()
	On Error Resume Next

	Select Case Bits_OS
		Case OS_32
			PathSys         = DirWindows & "\System32"
			ProgFiles       = WShell.ExpandEnvironmentStrings("%ProgramFiles%")
			CommonProgFiles = WShell.ExpandEnvironmentStrings("%CommonProgramFiles%")
		Case OS_64
			Select Case Bits_Appl
				Case APPL_64
					PathSys         = DirWindows & "\System32"
					ProgFiles       = WShell.ExpandEnvironmentStrings("%ProgramFiles%")
					CommonProgFiles = WShell.ExpandEnvironmentStrings("%CommonProgramFiles%")
				Case APPL_XX
					PathSys         = DirWindows & "\System32"
					ProgFiles       = WShell.ExpandEnvironmentStrings("%ProgramFiles%")
					CommonProgFiles = WShell.ExpandEnvironmentStrings("%CommonProgramFiles%")					
				Case APPL_WOW			
					PathSys         = DirWindows & "\SysWOW64"					
					ProgFiles       = WShell.ExpandEnvironmentStrings("%ProgramFiles(x86)%")
					CommonProgFiles = WShell.ExpandEnvironmentStrings("%CommonProgramFiles(x86)%")
			End Select
	End Select

	PersonalizarVariables = 0
	
End Function
'
'**********************************************************************************
'			 ObtenerDatosXML : Busca Fichero XML Y Carga Datos
'**********************************************************************************
'
Function ObtenerDatosXML(AppFile)
	On Error Resume Next
'
'****************************** Buscar Fichero XML ********************************
'
	Dim Rc, oFolder, oFiles, oFile, FileXml

	If FSO.FileExists(AppFile) Then
		FileXml = AppFile
	Else		
		FileXml = ""
		Set oFolder = FSO.GetFolder(RutaOrigen) 
		Set oFiles  = oFolder.Files
		For Each oFile In oFiles           
			If(instr(1, UCase(oFile.name), ".DSH.XML") > 0) then
				FileXml = UCase(oFile.Path)
				Exit For
			End If
		Next
	End If
'
'*********** Lectura del Nombre de Aplicacíon / Version / Descripcion *******************
'
	Dim xmlObj, nodelist, node

	Set xmlObj	= CreateObject("Microsoft.XMLDOM")
	xmlObj.Async = False
	Rc = xmlObj.Load(FileXml)
	If Rc = False Then
		Set xmlObj = Nothing
		WScript.Quit(1465)
	End If

	Set nodelist	= xmlObj.selectnodes("DATSOF/APLI/NOMBRE")
	Set node		= nodelist.item(0)
	Aplicacion		= Trim(node.text)

	Set nodelist	= xmlObj.selectnodes("DATSOF/APLI/VERAPLI")
	Set node		= nodelist.item(0)
	Version			= Trim(node.text)

	Set nodelist	= xmlObj.selectnodes("DATSOF/APLI/VERDIS")
	Set node		= nodelist.item(0)
	VerDis			= Trim(node.text)

	Set nodelist	= xmlObj.selectnodes("DATSOF/APLI/DESC")
	Set node		= nodelist.item(0)
	Descrip			= Trim(node.text)

	Set nodelist	= xmlObj.selectnodes("DATSOF/APLI/APP_UNINST")
	Set node		= nodelist.item(0)
	AppToUnInst		= Trim(node.text)
	
	Set nodelist	= xmlObj.selectnodes("DATSOF/APLI/BITS_APPL")
	Set node		= nodelist.item(0)
	Bits_Appl		= Trim(node.text)	

	Set nodelist	= xmlObj.selectnodes("DATSOF/APLI/LOGFILE")
	Set node		= nodelist.item(0)
	LogFile			= Trim(node.text)

	ObtenerDatosXML = 0

End Function
'
'**********************************************************************************
'			 ComprobarBitsSO : Comprobar Bits Sistema Operativo Aplicacion
'**********************************************************************************
'
Function ComprobarApplOS()
	On Error Resume Next
	
	Dim Rc
	
	ComprobarApplOS = 1633
	Select Case Bits_OS
		Case OS_32
			Select Case Bits_Appl
				Case APPL_32 	ComprobarApplOS = 0				
				Case APPL_64 	ComprobarApplOS = 1633								
				Case APPL_XX 	ComprobarApplOS = 0										
				Case APPL_WOW	ComprobarApplOS = 0														
			End Select
		Case OS_64
			Select Case Bits_Appl
				Case APPL_32	ComprobarApplOS = 1633								
				Case APPL_64	ComprobarApplOS = 0								
				Case APPL_XX	ComprobarApplOS = 0
				Case APPL_WOW	ComprobarApplOS = 0																										
			End Select
	End Select
	
	If ComprobarApplOS <> 0 Then
		Rc = EscribeLog(1633, "ERR_DESCR = Bits_OS - " & Bits_OS & " Bits_Apl - " & Bits_Appl)
		Rc = FinalizarProceso(1633)
	End If	

End Function
'
'**********************************************************************************
'			 CrearFicheroLog : Crea el fichero de Log
'**********************************************************************************
'
Function CrearFicheroLog()
	On Error Resume Next

	Dim Rc, oFiles, i, ProgVisor
'
'****************************** Fichero de Log *************************************
'
	If IsEmpty(LogFile) Or LogFile = "" Then
		LogFile = DIR_LOG & "\" & AppToUnInst & ".LOG"
	End If
	If Not FSO.FileExists(LogFile) Then
		Set oFiles = FSO.CreateTextFile(LogFile, True)
		oFiles.Close
		Rc = EscribeLog("", "-----------------------------------------------------------------")
	End If
	Rc = EscribeLog("", "	 " & Descrip)
	Rc = EscribeLog("", "-----------------------------------------------------------------")
	Rc = EscribeLog("", "Inicio " & Aplicacion & " " & Version & " - " & Now)
	Rc = EscribeLog("", " ")

	CrearFicheroLog = 0

End Function
'
'**********************************************************************************
'           CabeceraLog : Graba Cabecera del Fichero Log
'**********************************************************************************
'
Function CabeceraLog()
	On Error Resume Next

	Dim Rc
'	
'************************ Verifica Sistema Operativo / Idioma *********************
'
	Dim objWMIService, colItems, objItem, LangDesc, SpVer, AxVer

	Const wbemFlagReturnImmediately = &h10
	Const wbemFlagForwardOnly       = &h20

   	Set objWMIService = GetObject("winmgmts:\\.\root\CIMV2")
   	Set colItems      = objWMIService.ExecQuery("SELECT * FROM Win32_OperatingSystem", "WQL", _
                                          wbemFlagReturnImmediately + wbemFlagForwardOnly)

   	For Each objItem In colItems
   		Select Case objItem.OSLanguage
   			Case 1033	LangDesc = "1033 English - United States"   			
   			Case 1040	LangDesc = "1040 Italian - Italy"
   			Case 2070	LangDesc = "2070 Portuguese - Portugal"
   			Case 3082	LangDesc = "3082 Spanish - International Sort"
   			Case Else	LangDesc = objItem.OSLanguage & " No Soportado"
   		End Select
   		AxVer 		= Split(objItem.Version, ".")
   		VerSO 		= AxVer(0) & "." & AxVer(1)
   		OsLanguage	= objItem.OSLanguage   		   		
   		SpVer 		= objItem.ServicePackMajorVersion & "." & objItem.ServicePackMinorVersion   		
   		Rc = EscribeLog("", "S.O.    : " & objItem.Caption & " - " & Bits_OS & " Bits")   		
   		Rc = EscribeLog("", "Idiona  : " & LangDesc)
   		Rc = EscribeLog("", "Version : " & objItem.Version & " (SP " & SpVer & ")")   		
   	Next
'
'************************* Obtener Usuario / Dominio ***********************************	
'
	Dim ObjNetwork, WmiSys, WmiQuery, Result, CompSys, InfoPuesto, WsName
	
	Set ObjNetwork 	= WScript.CreateObject("WScript.Network")
	WsName         	= UCase(ObjNetwork.ComputerName)
	InfoPuesto     	= "Usuario : " & ObjNetwork.ComputerName & "\" & ObjNetwork.UserName	
	Puesto			= ObjNetwork.ComputerName
	Usuario 		= ObjNetwork.UserName		
	Rc = EscribeLog("", InfoPuesto)

	Set WmiSys = GetObject("winmgmts:") 
	WmiQuery   = "select * from win32_computersystem" 
	Set Result = WmiSys.execquery(WmiQuery) 
	For each CompSys in Result 
		InfoPuesto	= "Dominio : " & CompSys.domain 	
		Dominio 	= CompSys.domain		
		Rc = EscribeLog("", InfoPuesto)
	Next
	Rc = EscribeLog("", " ")
		
	CabeceraLog = 0
	
End Function	
'
'**********************************************************************************
'			FinalizarProceso : Finalizar Proceso
'**********************************************************************************
'
Function FinalizarProceso(Ret)
	On Error Resume Next

	Dim Rc

	Select Case Ret
		Case 0, IPL_REQ
			Rc = BorrarAplEnRegistro(HKLM, RegApl & "\" & Aplicacion)
			Rc = BorrarAplEnRegistro(HKLM, RegApl & "\" & AppToUnInst)		
			Rc = GrabarAplEnRegistro(Ret)
		Case Else
			Rc = EscribeLog(Ret, "ERR_DESCR = Codigo de Finalizacion Erroneo")			
	End Select

	Rc = EscribeLog("", " ")
	Rc = EscribeLog("", "Finishing " & Aplicacion & " " & Version & " - " & Now)
	Rc = EscribeLog("", "-----------------------------------------------------------------")

	Set FSO		= Nothing
	Set WShell	= Nothing

	FinalizarProceso = 0
	WScript.Quit(Ret)

End Function
'
'**********************************************************************************
'			 EscribeLog : Escritura Fichero de Log
'**********************************************************************************
'
Function EscribeLog(Ret, Texto)
	On Error Resume Next

	Dim Rc, FSO, Fich, Linea, Hora, RcEdit

	Const ForAppending = 8

	Hora		= Right("00000000" & Mid(Now, 12), 8)
	Set FSO		= WScript.CreateObject ("Scripting.FileSystemObject")
	Set Linea	= fso.OpenTextFile(LogFile, ForAppending, True)
	If Ret = "" Then
		Rc = Linea.WriteLine(Hora & " " & Texto)
	Else
		RcEdit = "[Rc=" & Right("0000" & Ret, 4) & "] "
		Rc = Linea.WriteLine(Hora & " " & RcEdit & Texto)
	End If
	Linea.Close

	Err.Clear
	EscribeLog = 0

End Function
'
'**********************************************************************************
'	 GrabarAplEnRegistro : Graba Aplicacion en Registro como Ejecutada
'**********************************************************************************
'
Function GrabarAplEnRegistro(Ret)
	On Error Resume Next

	Dim  Rc, oReg, Fecha, Hora

	Fecha = Right("00000" & Date, 10)
	Hora  = Right("00000" & Time, 8)

	Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
	Rc = oReg.CreateKey(HKLM, RegApl)
	Rc = oReg.CreateKey(HKLM, RegApl & "\" & Aplicacion)	
	Rc = oReg.SetStringValue(HKLM, RegApl & "\" & Aplicacion, "Description", 			Descrip)
	Rc = oReg.SetStringValue(HKLM, RegApl & "\" & Aplicacion, "Version", 				Version)
	Rc = oReg.SetStringValue(HKLM, RegApl & "\" & Aplicacion, "Manufacturer Version",	VerDis)
	Rc = oReg.SetStringValue(HKLM, RegApl & "\" & Aplicacion, "Date", 					Fecha & " " & Hora)

	GrabarAplEnRegistro = 0

End Function
'
'**********************************************************************************
'	 BorrarAplEnRegistro : Borra Clave de Registro de Aplicacion
'**********************************************************************************
'
Function BorrarAplEnRegistro(HKLM, ClaveReg)
	On Error Resume Next

	Dim Rc, oReg, ArraySubClave, SubClave

	Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
	Rc = oReg.EnumKey(HKLM, ClaveReg, ArraySubClave)
	If IsArray(ArraySubClave) Then
		For Each SubClave In ArraySubClave
			Rc = BorrarAplEnRegistro(HKLM, ClaveReg & "\" & SubClave)
		Next
	End If
	Rc = oReg.DeleteKey(HKLM, ClaveReg)
	BorrarAplEnRegistro = 0

End Function
'
'**********************************************************************************
'	 UnidadLibre : Obtiene la Letra de la Primera Unidad Libre
'**********************************************************************************
'
Function UnidadLibre()
	On Error Resume Next

	Dim i, objDictionary, objWMIService, colDisks, objDisk, strDrive

	Set objDictionary	= CreateObject("Scripting.Dictionary")
	Set objWMIService	= GetObject("winmgmts:\\.\root\cimv2")
	Set colDisks		= objWMIService.ExecQuery("Select * from Win32_LogicalDisk")
	For Each objDisk in colDisks
		objDictionary.Add objDisk.DeviceID, objDisk.DeviceID
	Next
	For i = 67 to 90
		strDrive = Chr(i) & ":"
		If Not objDictionary.Exists(strDrive) Then
		 	UnidadLibre = strDrive
		 	Exit Function
		End If
	Next

End Function
Function MatarProceso(Proceso)
	On Error Resume Next
	Dim Rc, objWMI, objProcess, colProcess 	
	TerminarProceso = 0
	Set objWMI      = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2") 
	Set colProcess  = objWMI.ExecQuery("Select * from Win32_Process Where Name = '" & Proceso & "'")
	For Each objProcess in colProcess
		TerminarProceso = objProcess.Terminate()
		Rc = WScript.Sleep(2000)    	        				
	Next 
	Set colProcess = Nothing
	Set objWMI     = Nothing			
End Function