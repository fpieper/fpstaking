# Sideloading the Radix Ledger Nano App onto Ledger Nano S on Windows

Thanks to @Mleekko for the original instructions, I just simplified them a bit.

The sideloading was tested on Windows 10, but should theoretically also work on other versions.

First checkout the main guide: https://docs.radixdlt.com/main/user-applications/ledger-app-sideload.html.
Mostly the steps in the section `Install the Radix Ledger App` will differ slightly (described below):


1. Get the latest `Ledger Live` version and update the Ledger Nano S firmware to `2.0` and close `Ledger Live` afterwards.
   The installation of the app will not work when `Ledger Live` is opened.


2. Install Python 3.9 (during installation check "Add to PATH"):
   https://www.python.org/ftp/python/3.9.6/python-3.9.6-amd64.exe


3. Download the ledger app https://assets.radixdlt.com/ledger-app/radix-ledger-app-1.0.0.zip and extract its contents e.g. into your download folder.
   You should now have a directory `Downloads\radix-ledger-app-1.0.0\app-radix`.
   

4. Open "Command Prompt" (`cmd.exe`)


5. Install ledgerblue with (type in the command and press enter):
   ```
   pip3 install ledgerblue
   ```


6. Move (`cd` stands for change directory) into the extracted `app-radix` folder (assuming it is in your Download folder):
   ```
   cd Downloads\radix-ledger-app-1.0.0\app-radix
   ```


7. Reconnect the Nano S and enter the PIN (do not do anything on Nano S after that and stay in the main menu)


8. Sideload the ledger app to your Nano S with (ensure `Ledger Live` is not running):
   ```
   python -m ledgerblue.loadApp --path "44'/1022'" --curve secp256k1 --tlv --targetId 0x31100004 --delete --fileName bin/app.hex --appName Radix --dataSize 0 --icon 0100000000ffffff00ffffffffffffffffffe1fffdfffce7fe4ffe1fffbfffffffffffffffffffffff --rootPrivateKey b5b2eacb2debcf4903060e0fa2a139354fe29be9e4ac7c433f694a3d93297eaa
   ```


9. Do the confirmations on the Nano S (like described in the main guide after the previous sideloading command).
