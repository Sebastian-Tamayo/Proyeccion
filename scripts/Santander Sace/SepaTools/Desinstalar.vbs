Option Explicit
On Error Resume Next
'
'**********************************************************************************
'                               Constantes Globales
'**********************************************************************************
'
	Const REGDPL32	 	= "Software\Microsoft\Deployment\"				' Datos Despliege					
	Const REGDPL64	 	= "Software\Wow6432Node\Microsoft\Deployment\"	' Datos Despliege						
	Const REGAPL32	 	= "Software\Paquetes"							' Clave Registro Aplicacion
	Const REGAPL64	 	= "Software\Wow6432Node\Paquetes"				' Clave Registro Aplicacion	
	Const DirProg	 	= "Prog"									  	' Subdirectorio Software
	Const DirLog	 	= "C:\LOGS"										' Directorio Fichero LOG	
	Const W2K		 	= "5.0"											' Version S.O. Windows 2000
	Const WXP		 	= "5.1"											' Version S.O. Windows XP
	Const W7E		 	= "6.1"											' Version S.O. Windows 7
	Const W8E		 	= "6.3"											' Version S.O. Windows 8				
	Const W10			= "10.0"										' Version S.O. Windows 10			
	Const OS_32		 	= 32											' Sistema Operativo 32 Bits
	Const OS_64		 	= 64											' Sistema Operativo 64 Bits	
	Const APPL_32	 	= "32"											' Aplicacion Solo 32 Bits
	Const APPL_64	 	= "64"											' Aplicacion Solo 64 Bits
	Const APPL_XX	 	= "32/64"										' Aplicacion 32 y 64 Bits	
	Const APPL_WOW	 	= "WOW"											' Aplicacion 32/64 Bits		
	Const IPL_REQ	 	= 3010											' IPL Requerido	
	Const DIR_PCH_SAN	= "C:\SAN\PAQUETES"								' Directorio PCH - SAN Version Anterior
	Const DIR_SAN_EXE	= "C:\SAN\PAQUETES\EXE"							' Directorio PCH Ejecucion Parches
	Const DIR_SAN_TMP	= "C:\SAN\PAQUETES\TMP"							' Directorio PCH Temporal para Copias
	Const DIR_SAN_ERR	= "C:\SAN\PAQUETES\ERR"							' Directorio PCH Parches con Errores
	Const DIR_SAN_ALM	= "C:\SAN\PAQUETES\ALM"							' Directorio PCH Almacen		
'
'**********************************************************************************
'                            Variables Glovbales
'**********************************************************************************
'
	Dim Rc						' Codigo de Retorno de las funciones
	Dim Rx						' Codigo de Retorno de las funciones	
	Dim FSO						' Objeto "Scripting.FileSystemObject"	
	Dim Bits_OS					' Version de S.O. Instalada (32 o 64 Bits)
	Dim Comando					' Variable para Comando de Ejecucion
	Dim WShell					' Objeto "WSCript.shell"
	Dim RutaOrigen				' Path donde se encuentar INSTALAR.VBS
	Dim CurDir					' Directorio Actual
	Dim Aplicacion				' Nombre de la Aplicación 
	Dim Version					' Versión de la Aplicación	
	Dim RegApl					' HKLM\Software/HKLM\Software\Wow6432Node (Paquetes)
	Dim RegDpl					' HKLM\Software/HKLM\Software\Wow6432Node (Deployment)	
'	
'**********************************************************************************
'                         Iniciar Proceso de Instalacion
'**********************************************************************************
'
	Dim PT, PF
	
	Rx = 0
	Rc = IniciarVariables()
	Rc = ObtenerDatosXML(RutaOrigen & "\Desinstalar.xml")	
	PF = FSO.GetParentFolderName(RutaOrigen)
	If PF <> DIR_SAN_ERR Then Rc = BorrarPchAnt(DIR_SAN_ERR, Aplicacion, Mid(Version, 1, 2) & Mid(Version, 4))
	If PF <> DIR_SAN_ALM Then Rc = BorrarPchAnt(DIR_SAN_ALM, Aplicacion, Mid(Version, 1, 2) & Mid(Version, 4))				
	If PF <> DIR_PCH_SAN Then Rc = BorrarPchAnt(DIR_PCH_SAN, Aplicacion, Mid(Version, 1, 2) & Mid(Version, 4))
	If PF <> DIR_SAN_TMP Then Rc = BorrarPchAnt(DIR_SAN_TMP, Aplicacion, Mid(Version, 1, 2) & Mid(Version, 4))		

	CurDir = WShell.CurrentDirectory
	WShell.CurrentDirectory = RutaOrigen
	If Bits_OS = OS_32 Then
		Rx = WShell.Run("cscript.exe  Uninstall.vbs", 0, True)			
	Else
		Rx = WShell.Run("Script64.exe Uninstall.vbs", 0, True)			
	End If
	Select Case Rx
		Case 0, IPL_REQ
		Case Else
			Rc = FSO.CreateFolder(DIR_SAN_ERR & "\" & Aplicacion & "_" & Left(Version, 2) & Mid(Version, 4)) 
	End Select
	WShell.CurrentDirectory = CurDir			
'
'**********************************************************************************
'                              Finalizar Proceso de Instalacion
'**********************************************************************************
'
	WScript.Quit(Rx)
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
			Else
				If Left(Version, 2) > Left(VerAx, 2) Then
        			Folder.Delete
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
		Bits_OS  = objProcessor.AddressWidth
	Next	
	
	Set FSO		= CreateObject("Scripting.FileSystemObject")	
	Set WShell	= CreateObject("WSCript.shell")
	RutaOrigen	= FSO.GetParentFolderName(WScript.ScriptFullName)
	
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
		WScript.Quit(1465)
	End If	

	Set nodelist = xmlObj.selectnodes("DATSOF/APLI/NOMBRE") 
	Set node     = nodelist.item(0)
	Aplicacion   = Trim(node.text)
			
	Set nodelist = xmlObj.selectnodes("DATSOF/APLI/VERAPLI") 
	Set node     = nodelist.item(0)
	Version      = Trim(node.text)
	
	ObtenerDatosXML = 0
	
End Function
