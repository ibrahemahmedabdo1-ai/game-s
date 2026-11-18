@echo off
chcp 65001 >nul
where git >nul 2>nul || (echo Git is not installed. Install it from https://git-scm.com then run this again. & pause & exit /b 1)
echo Paste your EMPTY GitHub repository URL (https://github.com/USER/REPO.git)
set /p REPO=URL: 
if not exist .git git init
git add -A
git commit -m "Initial import"
git branch -M main
git remote remove origin >nul 2>nul
git remote add origin %REPO%
git push -u origin main
echo.
echo Done. Open your repository on GitHub, then the Actions tab.
pause
