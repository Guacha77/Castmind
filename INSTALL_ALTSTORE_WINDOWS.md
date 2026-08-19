# Build and install Castmind from Windows with GitHub Actions and AltStore

## 1. Push this repository to GitHub

From PowerShell:

```powershell
cd C:\Users\chagu\Documents\Castmind
git add .
git commit -m "Prepare Castmind unsigned iOS build"
git branch -M main
git remote add origin https://github.com/YOUR_USER/YOUR_REPO.git
git push -u origin main
```

## 2. Run the GitHub Actions build

1. Open your repository on GitHub.
2. Go to `Actions`.
3. Select `Build unsigned IPA`.
4. Click `Run workflow`.
5. Wait until the run finishes successfully.

## 3. Download the artifact

1. Open the completed workflow run.
2. Scroll to `Artifacts`.
3. Download `Castmind-unsigned-ipa`.
4. GitHub downloads a ZIP file.
5. Extract the ZIP. Inside you should see:
   - `Castmind-unsigned.ipa`
   - `Castmind-unsigned.ipa.sha256`

Optional SHA-256 check from PowerShell:

```powershell
Get-FileHash .\Castmind-unsigned.ipa -Algorithm SHA256
Get-Content .\Castmind-unsigned.ipa.sha256
```

## 4. Install with AltStore

1. Make sure AltServer is running on Windows.
2. Connect the iPhone by USB or use Wi-Fi sync if already configured.
3. Transfer `Castmind-unsigned.ipa` to the iPhone through Files, iCloud Drive, AirDrop alternative, or any local transfer method you use.
4. On the iPhone, open AltStore.
5. Go to `My Apps`.
6. Tap `+`.
7. Select `Castmind-unsigned.ipa`.
8. Wait for AltStore to sign and install it.

AltStore free Apple IDs normally need refresh every 7 days.
