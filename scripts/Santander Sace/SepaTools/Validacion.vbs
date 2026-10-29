'************************************************************************************
'
'	VALICACION.VBS
'	--------------
' 		- Comprueba que el Usuario Logado es el Propietario del Puesto
' 		- Ejecuta el Procedimiento Indicado en el Fichero DSH.XML
'
'************************************************************************************
Option Explicit
On Error Resume Next
'
'**********************************************************************************
'                            Definicion de Variables
'**********************************************************************************
'
	Dim Rc						' Codigo de Retorno de las funciones
	Dim Comando					' Variable para Comando de Ejecucion
	Dim ObjWmi					' Objeto WMI
	Dim FSO						' Objeto "Scripting.FileSystemObject"
	Dim WshNet					' Objeto "WScript.Network"
	Dim WShell					' Objeto "WSCript.shell"
	Dim RutaOrigen				' Path donde se encuentar INSTALAR.VBS
	Dim CurDir					' Directorio Actual
	Dim ExecFile				' Fichero Ejecucion en XML
	Dim ExtExec					' Extension Fichero Ejecutable
	Dim Puesto					' Nombre del Puesto
	Dim Usuario					' Usuario Logado
	Dim Ejecutar				' Indicador de Instalacion requerida
	Dim ObjItem					' Variable Auxiliar de Busqueda
	Dim ColItems				' Variable Auxiliar de Busqueda	
	Dim AuxArr					' Variable Auxiliar
'	
'**********************************************************************************
'   					     Iniciar Proceso                      
'**********************************************************************************
'
	Rc 			= 0
	Ejecutar 	= False
	Err.Clear
'
'******************************* Inicializar Variables *****************************
'
	Set WShell	= CreateObject("WSCript.shell")
	Set WshNet	= CreateObject("WScript.Network")	
	Set FSO		= CreateObject("Scripting.FileSystemObject")	
	Set ObjWmi	= GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2") 
	Puesto 		= UCase(Trim(WshNet.Computername))
	RutaOrigen	= FSO.GetParentFolderName(WScript.ScriptFullName)			
'
'****************************** Buscar Usuarios Validos ****************************
'
	Set ColItems = ObjWmi.ExecQuery("Select * from Win32_ComputerSystem",,48)
	For Each ObjItem In ColItems
		AuxArr	= Split(ObjItem.UserName,"\")	
		Usuario = UCase(Trim(AuxArr(1)))
		If InStr(Puesto, Usuario) 			Then Ejecutar = True
		If InStr(Puesto, Right(Usuario, 5))	Then Ejecutar = True		
	Next
	If Ejecutar = False Then WScript.Quit(80)
'
'************************* Determinar Comando de Ejecucion **************************
'
	Rc		= ObtenerDatosXML()
	ExtExec	= UCase(Trim(FSO.GetExtensionName(ExecFile)))
	Select Case ExtExec
		Case "VBS", "VBE"
			Comando = "cscript.exe " & ExecFile		
		Case "CMD", "BAT"
			Comando = "CMD /C " & ExecFile		
		Case "EXE"
			Comando = ExecFile
		Case "PS1"
			Comando = "PowerShell.exe " & ExecFile
		Case Else
			WScript.Quit(9999)		
	End Select
'
'******************************* Ejecutar Instalacion ********************************
' 
	CurDir = WShell.CurrentDirectory
	WShell.CurrentDirectory	= RutaOrigen
	Rc = WShell.Run(Comando, 0, True)
	WShell.CurrentDirectory	= CurDir
'
'**********************************************************************************
'                              Finalizar Proceso de Instalacion
'**********************************************************************************
'
	WScript.Quit(Rc)
'	
'**********************************************************************************
'           ObtenerDatosXML : Busca Fichero XML Y Carga Datos
'**********************************************************************************
'
Function ObtenerDatosXML()
	On Error Resume Next
'
'****************************** Buscar Fichero XML ********************************
'
	Dim Rc, oFolder, oFiles, oFile, FileXml
	
	FileXml = ""
	Set oFolder = FSO.GetFolder(RutaOrigen) 
	Set oFiles  = oFolder.Files
	For Each oFile In oFiles           
		If(instr(1, UCase(oFile.name), ".DSH.XML") > 0) then
			FileXml = UCase(oFile.Path)
			Exit For
		End If
	Next
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
	
	Set nodelist = xmlObj.selectnodes("DATSOF/APLI/PROCINS") 
	Set node     = nodelist.item(0)
	ExecFile     = Trim(node.text)
	
	ObtenerDatosXML = 0
	
End Function
