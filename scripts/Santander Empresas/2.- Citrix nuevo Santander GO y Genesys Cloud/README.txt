Por la migración a Santander Go que implica la migración de la voz a Genesys cloud,
Se implemento actualizar la versión de citrix a la 24.2.4001.1

Este se instala por CMD como admin, buscar la ruta del instalable y ejecutarlo agregando el comando ADDLOCAL=BCR_Client

Si se quiere una instalación silenciosa añadir /silent ADDLOCAL=BCR_Client

Ejemplo: CitrixWorkspaceapp.exe /silent ADDLOCAL=BCR_Client
         CitrixWorkspaceapp.exe ADDLOCAL=BCR_Client

