'
'*******************************************************************************************
'
'           MUEVE EL PARCHE DISTRIBUIDO A SU DIRECTORIO CORRESPONDIENTE
'
'*******************************************************************************************
'
Option Explicit
On Error Resume Next
'
'**********************************************************************************
'                    CONSTANTES  GLOBALES  DE  APLICACION
'**********************************************************************************
'
	Const DIR_LOG		= "C:\LOGS"							' Directorio Raiz Ficheros LOG	
	Const DIR_LOG_PTO	= "C:\LOGS\PUESTO"					' Directorio Fichero LOG		
	Const DIR_SAN		= "C:\SAN"							' Directorio Raiz SAN
	Const DIR_SAN_PCH	= "C:\SAN\PAQUETES"					' Directorio PCH - SAN Version Anterior	
	Const DIR_SAN_EXE	= "C:\SAN\PAQUETES\EXE"				' Directorio PCH Ejecucion Parches
	Const DIR_SAN_TMP	= "C:\SAN\PAQUETES\TMP"				' Directorio PCH Temporal para Copias
	Const DIR_SAN_ERR	= "C:\SAN\PAQUETES\ERR"				' Directorio PCH Parches con Errores
	Const DIR_SAN_ALM	= "C:\SAN\PAQUETES\ALM"				' Directorio PCH Almacen
	Const DIR_SAN_MVD	= "C:\SAN\PAQUETES\MVD"				' Directorio PCH Move Delay
	Const W2K			= "5.0"								' Version S.O. Windows 2000
	Const WXP			= "5.1"								' Version S.O. Windows XP
	Const W7E			= "6.1"								' Version S.O. Windows 7
	Const W8E			= "6.3"								' Version S.O. Windows 8	
	Const W10			= "10.0"							' Version S.O. Windows 10		
	Const OS_32			= 32								' Sistema Operativo 32 Bits
	Const OS_64			= 64								' Sistema Operativo 64 Bits	
'
'**********************************************************************************
'                           VARIABLES  GLOBALES 
'**********************************************************************************
'
	Dim Rc						' Codigo de Retorno de las funciones
	Dim Rx						' Codigo de Finalizacion de Proceso
	Dim Bits_Arq				' Tipo de procesador 32 o 64 Bits
	Dim Bits_OS					' Version de S.O. Instalada (32 o 64 Bits)	
	Dim Comando					' Variable Para Ejecucion de Comandos	
	Dim Aplicacion				' Nombre de la Aplicación 
	Dim Version					' Versión de la Aplicación
	Dim Descrip					' Descripción de la Aplicación
	Dim WShell					' Objeto "WSCript.shell"
	Dim ShellAp					' Objeto "shell.application"
	Dim ObjNetwork				' Objeto "WScript.Network"			
	Dim FSO						' Objeto "Scripting.FileSystemObject"
	Dim objWMI					' Objeto WMI	
	Dim PT						' Objeto "PRBTools.Tools"
	Dim LogFile					' Fichero LOG = DirLog + Aplicacion
	Dim VerSO					' Version S.O.
	Dim DirDest					' Directorio Destino del Parche
	Dim Puesto					' Nombre de Puesto	
	Dim Usuario					' Usuario que ejecuta el módulo	
	Dim RutaOrigen				' Drectorio de Ejecicion
	Dim FileAppXml				' Fichero XML de Referencia
'
'**********************************************************************************
'                    CONSTANTES  GLOBALES  DE  SISTEMA
'**********************************************************************************
'	
	Const HKLM		   = &H80000002 		' Clave Reg HKEY_LOCAL_MACHINE
	Const ForReading   = 1					' Abrit Fichero para lectura
	Const ForWriting   = 2					' Abrir Fichero para escritura
	Const ForAppending = 8					' Abrit Fichero para anexar datos	
'	
'**********************************************************************************
'                             Inicializar Variables
'**********************************************************************************
'
	If WScript.Arguments.Count > 0 Then
		FileAppXml = WScript.Arguments(0)		
	End If
	
	Rc = IniciarVariables()
	Rc = CrearFicheroLog()
	Rc = ObtenerDatosXML(RutaOrigen & "\" & FileAppXml)	
'
'**********************************************************************************
'                               Iniciar Proceso de Copia
'***********************************************************************************
'
	Dim i, DirAlm, DirTmp, DirErr, Msg
	
	Const ROBOCOPY_PRG	= "RoboCopy.exe"
	Const ROBOCOPY_PAR	= "/MIR /R:2 /W:2"
	
	Err.Clear
'
'**************************** Comprobar Directorios de Trabajo **********************
'	
	If Not FSO.FolderExists(DIR_SAN)		Then Rc = FSO.CreateFolder(DIR_SAN)
	If Not FSO.FolderExists(DIR_LOG)		Then Rc = FSO.CreateFolder(DIR_LOG)	
	If Not FSO.FolderExists(DIR_LOG_PTO)	Then Rc = FSO.CreateFolder(DIR_LOG_PTO)	
	If Not FSO.FolderExists(DIR_SAN_PCH) 	Then Rc = FSO.CreateFolder(DIR_SAN_PCH)
	If Not FSO.FolderExists(DIR_SAN_EXE) 	Then Rc = FSO.CreateFolder(DIR_SAN_EXE)	
	If Not FSO.FolderExists(DIR_SAN_TMP) 	Then Rc = FSO.CreateFolder(DIR_SAN_TMP)
	If Not FSO.FolderExists(DIR_SAN_ERR) 	Then Rc = FSO.CreateFolder(DIR_SAN_ERR)	
	If Not FSO.FolderExists(DIR_SAN_ALM) 	Then Rc = FSO.CreateFolder(DIR_SAN_ALM)	
	If Not FSO.FolderExists(DIR_SAN_MVD) 	Then Rc = FSO.CreateFolder(DIR_SAN_MVD)		
'
'****************************** Borrar Carpetas Destino *****************************
'
	Rc = EscribeLog("", " ")
	Rc = EscribeLog(0, "COPY_STAR = " & UCase(Usuario) & " - " & Date & " - " & Puesto)
	Rc = EscribeLog(0, "APPL_DESC = " & Aplicacion & " - " & Version & " - " & Descrip)			
	DirAlm = DIR_SAN_ALM & "\" & Aplicacion & "_" & Mid(Version, 1, 2) & Mid(Version, 4)	
	DirTmp = DIR_SAN_TMP & "\" & Aplicacion & "_" & Mid(Version, 1, 2) & Mid(Version, 4)	
	DirErr = DIR_SAN_ERR & "\" & Aplicacion & "_" & Mid(Version, 1, 2) & Mid(Version, 4)
			
	For i = 1 To 5
		Rc = BorrarPchAnt(DIR_SAN_ERR, Aplicacion, Mid(Version, 1, 2) & Mid(Version, 4))
		Rc = BorrarPchAnt(DIR_SAN_ALM, Aplicacion, Mid(Version, 1, 2) & Mid(Version, 4))				
		Rc = BorrarPchAnt(DIR_SAN_PCH, Aplicacion, Mid(Version, 1, 2) & Mid(Version, 4))
		Rc = BorrarPchAnt(DIR_SAN_EXE, Aplicacion, Mid(Version, 1, 2) & Mid(Version, 4))	
		Rc = BorrarPchAnt(DIR_SAN_TMP, Aplicacion, Mid(Version, 1, 2) & Mid(Version, 4))
		If FSO.FolderExists(DirTmp) Or FSO.FolderExists(DirAlm) Or FSO.FolderExists(DirErr) Then
			WScript.Sleep(i * 1000)
			Rx = 9999			
		Else
			Rx = 0
			Rc = FSO.CreateFolder(DirTmp)				
			Exit For			
		End If
	Next
	If Rx = 9999 Then Rc = FinalizarProceso(Rx)
'
'********************************** Copia Ficheros Almacen ************************************
'
	Err.Clear
	Comando = ROBOCOPY_PRG & " " 
	Comando = Comando & Chr(34) & RutaOrigen & Chr(34) & " "
	Comando = Comando & Chr(34) & DirTmp     & Chr(34) & " " & ROBOCOPY_PAR
	Rc = WShell.Run(Comando, 0 ,True)
	Rc = EscribeLog(Rc, "EXEC_PRGM = " & ROBOCOPY_PRG & " *.* " & DIRTMP & " " & ROBOCOPY_PAR)
	Rc = FSO.MoveFolder(DirTmp, DirAlm)
	Rc = EscribeLog(Err.Number, "MOVE_FLDR = " & DirTmp & " " & DirAlm)	
	For i = 1 To 5
		WScript.Sleep(i * 1000)
		If Not FSO.FolderExists(DirAlm) Then
			Err.Clear
			Rc = FSO.MoveFolder(DIRTMP, DirAlm)		
			Rc = EscribeLog(Err.Number, "MOVE_FLDR = " & DirTmp & " " & DirAlm)	
		Else
			Exit For
		End If	
	Next
	If FSO.FileExists(DirAlm & "\" & FileAppXml) Then
		Rc = FSO.CopyFile(DirAlm & "\" & FileAppXml, DirAlm & "\Instalar.dsh.xml", True)
	End If			
'
'**********************************************************************************
'                          FINALIZAR  PROCESO  DE  COPIA
'***********************************************************************************
'
	Rc = FinalizarProceso(0)
'
'**********************************************************************************
'        BorrarPchAnt : Borra los Paquetes de Versiones Anteriores
'**********************************************************************************
'	
Function BorrarPchAnt(Directorio, Modulo, Version)
	On Error Resume Next
	
	Dim Rc, objFldr, Folders, Folder, Longitud
	Dim UcModulo, UcFolder, UlFolder, FolderAux, VerAx
	
	BorrarPchAnt = 0	
	If Not FSO.FolderExists(Directorio) Then Exit Function	
	
	UcModulo    = UCase(Trim(Modulo))
	Longitud    = Len(UcModulo)
    Set objFldr = FSO.GetFolder(Directorio)
    Set Folders = objFldr.SubFolders
    For Each Folder in Folders
    	UlFolder  = Folder.Name
        UcFolder  = UCase(Trim(Folder.Name))
        FolderAux = Left(UcFolder, Longitud)
        If UcModulo = FolderAux Then
        	VerAx = Mid(UcFolder, Longitud + 2, Len(Version))
       		Err.Clear        	
        	If Version = VerAx Then
        		Folder.Delete
        		Rc = EscribeLog(Err.Number, "RMVE_FLDR = " & Directorio & "\" & UlFolder)
			Else
				If Left(Version, 2) > Left(VerAx, 2) Then
        			Folder.Delete
        			Rc = EscribeLog(Err.Number, "RMVE_FLDR = " & Directorio & "\" & UlFolder)				
				End If        		
        	End If
        End If
    Next
		
End Function
'
'**********************************************************************************
'           IniciarVariables : Carga de las Variables Globales
'**********************************************************************************
'
Function IniciarVariables()
	On Error Resume Next

	Dim objWMIService, colSettings, objProcessor
	
   	Set objWMIService = GetObject("winmgmts:\\.\root\CIMV2")	
	Set colSettings   = objWMIService.ExecQuery("SELECT * FROM Win32_Processor")
	For Each objProcessor In colSettings
		Bits_Arq = objProcessor.DataWidth
		Bits_OS  = objProcessor.AddressWidth
	Next	

	Set FSO        	= CreateObject("Scripting.FileSystemObject")
	Set WShell     	= CreateObject("WSCript.shell")
	Set ShellAp    	= CreateObject("shell.application")
	Set ObjNetwork 	= CreateObject("WScript.Network")			
	Set PT			= CreateObject("PRBTools.Tools")
	Set objWMI     	= GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")				
	RutaOrigen     	= FSO.GetParentFolderName(WScript.ScriptFullName)			
	LogFile        	= DIR_LOG_PTO & "\COPIARALM.LOG"
	Usuario        	= ObjNetwork.UserName	
	Puesto         	= ObjNetwork.ComputerName			
		
	IniciarVariables = 0
	
End Function
'	
'**********************************************************************************
'           ObtenerDatosXML : Busca Fichero XML Y Carga Datos
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
	
	Set xmlObj   = CreateObject("Microsoft.XMLDOM") 
	xmlObj.Async = False 
	Rc = xmlObj.Load(FileXml) 
	If Rc = False Then
		Set xmlObj = Nothing 
		Rc = EscribeLog("", " ")				
		Rc = EscribeLog(9999, "ERR_DESCR = FICHERO XML DE APLICACION NO ENCONTRADO")
		Rc = FinalizarProceso(9999)
	End If	

	Set nodelist = xmlObj.selectnodes("DATSOF/APLI/NOMBRE") 
	Set node     = nodelist.item(0)
	Aplicacion   = Trim(node.text)
			
	Set nodelist = xmlObj.selectnodes("DATSOF/APLI/VERAPLI") 
	Set node     = nodelist.item(0)
	Version      = Trim(node.text)
	
	Set nodelist = xmlObj.selectnodes("DATSOF/APLI/DESC") 
	Set node     = nodelist.item(0)
	Descrip      = Trim(node.text)
	
	ObtenerDatosXML = 0
	
End Function
'
'**********************************************************************************
'           CrearFicheroLog : Crea el fichero de Log
'**********************************************************************************
'
Function CrearFicheroLog()
	On Error Resume Next

	Dim Rc, oFiles, oFile, DatePto, DateArray, DateFile
	Dim i, j, ExtOrig, ExtDest, FileOrig, FileDest
'
'****************************** Fichero de Log *************************************
'
	If FSO.FileExists(LogFile) Then
		Set oFile = FSO.GetFile(LogFile)
		DateArray = Split(oFile.DateCreated, " ", -1)
		DateFile = DateArray(0)
		DateArray = Split(Mid(Now, 1), " ", -1)
		DatePto = DateArray(0)
		If DatePto <> DateFile Then
			Rc = EscribeLog("", "-----------------------------------------------------------------")		
			For i = 30 To 2 Step -1
				j = i - 1
				ExtOrig = Right("000" & j, 3)
				ExtDest = Right("000" & i, 3)
				FileOrig = DIR_LOG_PTO & "\COPIARALM." & ExtOrig
				FileDest = DIR_LOG_PTO & "\COPIARALM." & ExtDest
				If FSO.FileExists(FileDest) Then
					Rc = FSO.DeleteFile(FileDest, True)
				End If				
				If FSO.FileExists(FileOrig) Then
					Rc = FSO.MoveFile(FileOrig, FileDest)
				End If
			Next
			FileOrig = DIR_LOG_PTO & "\COPIARALM.LOG"
			FileDest = DIR_LOG_PTO & "\COPIARALM.001"
			Rc = FSO.MoveFile(FileOrig, FileDest)
		End If														
	End If

	If Not FSO.FileExists(LogFile) Then
		Set oFiles = FSO.CreateTextFile(LogFile, True)
		oFiles.Close
		Rc = PT.FileSetDateNow(LogFile)		
		Rc = EscribeLog("", "-----------------------------------------------------------------")
		Rc = EscribeLog("", "     COPIARALM : Mueve Parches a Ejecutar")
		Rc = EscribeLog("", "-----------------------------------------------------------------")
		Rc = EscribeLog("", " ")
		Rc = CabeceraLog()	
	End If 

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
   		AxVer = Split(objItem.Version, ".")
   		VerSO = AxVer(0) & "." & AxVer(1)
   		SpVer = objItem.ServicePackMajorVersion & "." & objItem.ServicePackMinorVersion   		
   		Rc = EscribeLog("", "S.O.    : " & objItem.Caption & " - " & Bits_OS & " Bits")   		
   		Rc = EscribeLog("", "Idiona  : " & LangDesc)
   		Rc = EscribeLog("", "Version : " & objItem.Version & " (SP " & SpVer & ")")   		
   	Next
'
'************************* Obtener Usuario / Dominio ***********************************	
'
	Dim ObjNetwork, WmiSys, WmiQuery, Result, CompSys, InfoPuesto, WsName, DomGrp
	
	Set ObjNetwork = WScript.CreateObject("WScript.Network")
	WsName         = UCase(ObjNetwork.ComputerName)
	InfoPuesto     = "Usuario : " & ObjNetwork.ComputerName & "\" & ObjNetwork.UserName	
	Rc = EscribeLog("", InfoPuesto)

	Set WmiSys = getobject("winmgmts:") 
	WmiQuery   = "select * from win32_computersystem" 
	Set Result = WmiSys.execquery(WmiQuery) 
	For each CompSys in Result 
		InfoPuesto = "Dominio : " & CompSys.domain 	
		Rc = EscribeLog("", InfoPuesto)
	Next

	CabeceraLog = 0
	
End Function	
'
'**********************************************************************************
'          FinalizarProceso : Finalizar Proceso
'**********************************************************************************
'
Function FinalizarProceso(Ret)
	On Error Resume Next

	Dim Rc
	
	Set FSO     = Nothing
	Set WShell  = Nothing
	Set ShellAp = Nothing
	Set objWMI  = Nothing	

	FinalizarProceso = 0
	WScript.Quit(Ret)
	
End Function	
'
'**********************************************************************************
'           EscribeLog : Escritura Fichero de Log
'**********************************************************************************
'
Function EscribeLog(Ret, Texto)
	On Error Resume Next

	Dim Rc, FSO, Fich, Linea, Hora, RcEdit

	Const ForAppending = 8	

	Hora      = Right("00000000" & Mid(Now, 12), 8)
	Set FSO   = WScript.CreateObject ("Scripting.FileSystemObject")
	Set Linea = fso.OpenTextFile(LogFile, ForAppending, True)
	If Ret = "" Then
		Rc = Linea.WriteLine(Hora & " " & Texto)
	Else
		RcEdit = "[Rc=" & Right("0000" & Ret, 4) & "] "
		Rc     = Linea.WriteLine(Hora & " " & RcEdit & Texto)		
	End If
	Linea.Close
	
	EscribeLog = 0

End Function
