# Publicar el ecosistema en CasaTorinoApp

Desde este entorno cloud el push a `Sebastian-Tamayo/CasaTorinoApp` falla con **403**.
En tu PC (con tu cuenta GitHub) ejecuta:

```bash
# 1) Clona el destino
git clone https://github.com/Sebastian-Tamayo/CasaTorinoApp.git
cd CasaTorinoApp

# 2) Sustituye el contenido por el monorepo unificado de Proyeccion
git clone --depth 1 https://github.com/Sebastian-Tamayo/Proyeccion.git /tmp/proyeccion
rm -rf erp web reservas docs README.md package.json .gitignore
cp -a /tmp/proyeccion/casa-torino/. .

# 3) Commit y push
git add -A
git commit -m "Unify web, ERP and reservas into one Casa Torino ecosystem monorepo"
git push origin main
```

Alternativa rápida (bundle ya preparado en Proyeccion):

```bash
git clone https://github.com/Sebastian-Tamayo/Proyeccion.git
cd Proyeccion
git subtree push --prefix=casa-torino git@github.com:Sebastian-Tamayo/CasaTorinoApp.git main
```

*(Si `subtree push` pide autenticación, usa tu SSH o `gh auth login`.)*
