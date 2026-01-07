# Istruzioni Debug Mobile - SignStamp

## Dispositivo di Test
- **Modello**: Moto G42
- **ID Dispositivo USB**: `ZY32G6P69H`
- **IP WiFi**: `192.168.1.12` (può cambiare)

---

## Debug USB

### Prerequisiti
1. Abilitare **Opzioni sviluppatore** sul telefono:
   - Impostazioni → Info telefono → Tocca 7 volte su "Numero build"
2. Abilitare **Debug USB**:
   - Impostazioni → Opzioni sviluppatore → Debug USB → ON
3. Collegare il cavo USB

### Comandi
```powershell
# Verificare dispositivi connessi
C:\SDK\flutterSDK\flutter\bin\flutter.bat devices

# Lanciare l'app
C:\SDK\flutterSDK\flutter\bin\flutter.bat run -d ZY32G6P69H
```

---

## Debug WiFi (Wireless)

### Setup Iniziale (richiede USB una tantum)

1. **Collegare il telefono via USB**

2. **Abilitare modalità TCP su ADB**:
```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" tcpip 5555
```

3. **Trovare l'IP del telefono** (se non lo conosci):
```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" shell ip addr show wlan0 | Select-String "inet "
```
Oppure: Impostazioni → WiFi → Tocca la rete connessa → Vedi dettagli

4. **Scollegare il cavo USB**

5. **Connettere via WiFi**:
```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" connect 192.168.1.12:5555
```

### Lanciare l'App via WiFi
```powershell
# Verificare connessione
C:\SDK\flutterSDK\flutter\bin\flutter.bat devices

# Lanciare l'app
C:\SDK\flutterSDK\flutter\bin\flutter.bat run -d 192.168.1.12:5555
```

### Disconnettere
```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" disconnect 192.168.1.12:5555
```

---

## Risoluzione Problemi

### Dispositivo non rilevato
```powershell
# Riavviare ADB server
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" kill-server
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" start-server
```

### Connessione WiFi persa
Il debug WiFi si resetta quando:
- Il telefono si riavvia
- Cambia rete WiFi
- Dopo lungo periodo di inattività

**Soluzione**: Ricollegare USB e ripetere setup iniziale

### L'IP è cambiato
```powershell
# Ricollegare USB e trovare nuovo IP
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" shell ip addr show wlan0 | Select-String "inet "
```

### Porta 5555 occupata
```powershell
# Usare porta diversa
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" tcpip 5556
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" connect 192.168.1.12:5556
```

---

## Comandi Utili

```powershell
# Lista tutti i dispositivi ADB
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" devices

# Screenshot
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" exec-out screencap -p > screenshot.png

# Log in tempo reale
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" logcat -s flutter

# Installare APK manualmente
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" install build\app\outputs\flutter-apk\app-debug.apk

# Hot reload (durante flutter run)
# Premi 'r' nel terminale

# Hot restart
# Premi 'R' nel terminale
```

---

## Percorsi Importanti

| Risorsa | Percorso |
|---------|----------|
| Flutter SDK | `C:\SDK\flutterSDK\flutter\bin` |
| Android SDK | `C:\Users\User\AppData\Local\Android\sdk` |
| ADB | `C:\Users\User\AppData\Local\Android\sdk\platform-tools\adb.exe` |
| Progetto | `C:\projects\addSignature` |
