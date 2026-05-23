@echo off
:: Corrige os problemas de acentuação e caracteres bugados
CHCP 1252 >nul
title JMDC Clean and Optmizer
color 0A
cls

:menu
cls
echo ==============================================================================
echo               JMDC Consulting and Technology - Clean and Optmizer
echo ==============================================================================
echo.
echo           - Otimizador Avançado para Windows 11
echo           - www.jmdc.com.br
echo.
echo ==============================================================================
echo.
echo Escolha uma opção abaixo:
echo.
echo [1] - OTIMIZAÇÃO RÁPIDA (Limpeza de Temporários e Prefetch)
echo [2] - OTIMIZAÇÃO COMPLETA GAMER (Tweaks de Registro e Prioridade)
echo [3] - OTIMIZAR NAVEGADORES (Limpeza de Cache Geral)
echo [4] - FIX ERROS DO WINDOWS (SFC /Scannow e DISM)
echo [5] - OTIMIZAR REDE E PING (DNS Google e Otimização TCP)
echo [6] - PLANOS DE ENERGIA (Ativar Desempenho Máximo)
echo [7] - DEBLOAT COMPLETO (Desativa Telemetria e Coleta de Dados)
echo [8] - GPU TWEAKS (Ativar Agendamento de GPU por Hardware)
echo [9] - BACKUP E SEGURANÇA (Criar Ponto de Restauração)
echo [A] - COMPACTAR DISCO (Compact OS - Libera até 60%% de espaço)
echo [B] - FERRAMENTAS EXTRAS (Abrir Painel God Mode)
echo [C] - RESTAURAR CONFIGURAÇÕES PADRÃO (Reset de Rede)
echo [D] - INFORMAÇÕES DO SISTEMA
echo [S] - SAIR
echo.
echo ==============================================================================
set /p op=Digite a opção desejada: 

if /i "%op%"=="1" goto op1
if /i "%op%"=="2" goto op2
if /i "%op%"=="3" goto op3
if /i "%op%"=="4" goto op4
if /i "%op%"=="5" goto op5
if /i "%op%"=="6" goto op6
if /i "%op%"=="7" goto op7
if /i "%op%"=="8" goto op8
if /i "%op%"=="9" goto op9
if /i "%op%"=="A" goto opa
if /i "%op%"=="B" goto opb
if /i "%op%"=="C" goto opc
if /i "%op%"=="D" goto opd
if /i "%op%"=="S" goto sair
goto menu

:op1
cls
echo Aplicando Otimização Rápida...
del /s /f /q %temp%\*.*
del /s /f /q C:\Windows\Temp\*.*
del /s /f /q C:\Windows\Prefetch\*.*
echo Limpeza concluída com sucesso!
pause
goto menu

:op2
cls
echo Aplicando Otimização Completa Gamer...
reg add "HKLM\System\CurrentControlSet\Control\PriorityControl" /v "Win32PrioritySeparation" /t REG_DWORD /d 38 /f
echo Tweaks de performance aplicados!
pause
goto menu

:op3
cls
echo Otimizando Navegadores...
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
echo Cache limpo!
pause
goto menu

:op4
cls
echo Corrigindo erros do Windows...
sfc /scannow
dism /online /cleanup-image /restorehealth
echo Reparo concluído!
pause
goto menu

:op5
cls
echo Otimizando Rede e Ping...
netsh int tcp set global autotuninglevel=disabled
netsh interface ip set dns name="Ethernet" source=static address=8.8.8.8
echo DNS e TCP configurados!
pause
goto menu

:op6
cls
echo Ativando Plano de Desempenho Máximo...
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
echo Plano ativado! Verifique nas Opções de Energia.
pause
goto menu

:op7
cls
echo Executando Debloat e desativando Telemetria...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f
echo Privacidade aumentada!
pause
goto menu

:op8
cls
echo Aplicando GPU Tweaks...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v "HwSchMode" /t REG_DWORD /d 2 /f
echo Hardware Accelerated GPU Scheduling ativado!
pause
goto menu

:op9
cls
echo Criando Ponto de Restauração...
wmic /namespace:\\root\default path SystemRestore call CreateRestorePoint "SR Windows Tech Turbo", 100, 7
echo Ponto criado! Agora você está seguro.
pause
goto menu

:opa
cls
echo Compactando Sistema (Compact OS)...
compact.exe /CompactOS:always
echo Compactação concluída!
pause
goto menu

:opb
cls
echo Abrindo Ferramentas Extras (God Mode)...
mkdir "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}" 2>nul
explorer "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
pause
goto menu

:opc
cls
echo Restaurando Configurações de Rede...
netsh int ip reset
netsh winsock reset
echo Reinicie o PC para aplicar as mudanças de rede.
pause
goto menu

:opd
cls
echo Informações do Sistema:
systeminfo | findstr /B /C:"Nome do SO" /C:"Versão do SO" /C:"Tipo de sistema"
if errorlevel 1 systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"System Type"
pause
goto menu

:sair
echo Obrigado por usar nossa ferramenta de otimização!
start https://www.jmdc.com.br
exit