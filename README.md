# Windows TTL Changer

A small PowerShell tool that shows and changes the default TTL (IPv4) and hop limit (IPv6) that Windows puts on outgoing packets. It runs as a simple text menu from a single script file.

```text
  ========================================
    Windows TTL Changer
    Developed by huseyinymk
    Version 1.0.2
  ========================================

    Current IPv4 TTL Value: 128
    Current IPv6 TTL Value: 128

    1- Change TTL 65
    2- Change TTL Default Value (128)
    3- Change TTL Custom Value
    0- Exit

    Select an option:
```

After choosing a value, the tool asks where to apply it:

```text
    Which protocol should this setting be applied to?

    1- IPv4
    2- IPv6
    3- IPv4 & IPv6
    0- Back
```

## Why 65?

Every IP packet carries a TTL value. Each router that forwards the packet lowers it by one, and a phone that shares its connection through a hotspot acts as such a router.

| Traffic | TTL sent | TTL the carrier sees |
|---|---|---|
| The phone's own traffic | 64 | 64 |
| A Windows PC on the phone's hotspot | 128 | 127 |
| A Windows PC with the TTL set to 65 | 65 | 64 |

Some carriers use this difference to recognize hotspot traffic and count it against a separate tethering quota. With a TTL of 65, packets from the PC reach the carrier with 64, the same value as the phone's own packets.

A TTL of 65 is also fine for everyday use. Android, iOS, macOS and Linux all use 64, so switching back to 128 is optional.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1, which is built in, or PowerShell 7
- Administrator rights. The script asks for them through a UAC prompt.

## Usage

Download both files into the same folder:

- `Windows-TTL-Changer.ps1` — the tool
- `Run-Windows-TTL-Changer.cmd` — the launcher

Then **double-click `Run-Windows-TTL-Changer.cmd`** and approve the UAC prompt. Choose a value, then choose where to apply it: IPv4, IPv6, or both.

For hotspot use, apply the value to **IPv4 & IPv6**. If only IPv4 is changed, IPv6 traffic still reaches the carrier with 127.

### Why a launcher?

Windows blocks `.ps1` scripts by default through the *Restricted* execution policy, and on many machines the right-click **Run with PowerShell** entry is missing or blocked, so the window just flashes an error such as *"running scripts is disabled on this system"* and closes. The launcher starts the script with `-ExecutionPolicy Bypass`, which applies to that single run only and changes no system setting.

You can do the same by hand from a terminal:

```powershell
powershell -ExecutionPolicy Bypass -File .\Windows-TTL-Changer.ps1
```

## How it works

Windows keeps two copies of this setting: the *active* value it uses right now, and the *persistent* value it loads after a restart. Writing only the persistent copy does not change the active one, so the script sets both with `netsh`. A change therefore works immediately and survives a restart:

```powershell
netsh interface ipv4 set global defaultcurhoplimit=65 store=active
netsh interface ipv4 set global defaultcurhoplimit=65 store=persistent
netsh interface ipv6 set global defaultcurhoplimit=65 store=active
netsh interface ipv6 set global defaultcurhoplimit=65 store=persistent
```

After every change, the script reads both copies back to confirm them. If the value saved for the next restart differs from the current one, the menu shows it under the current values. To undo a change, choose option 2 or run the same commands with 128.

## Limitations

TTL is only one of the ways carriers detect tethering. If your hotspot quota still goes down with a TTL of 65, your carrier probably uses another method, such as a separate APN for tethered traffic or deep packet inspection. Changing the TTL does not help against those.

## Disclaimer

Your carrier's terms of service may restrict sharing your phone's mobile data with other devices. You are responsible for how you use this tool. It is provided as is, without any warranty.

## License

Windows TTL Changer is free software, licensed under the [GNU General Public License v3.0 or later](LICENSE).

You are free to use, study, share and modify it. If you distribute it, modified or not, you must pass on the same freedoms: the source code has to be available under this same license, so every published version stays open source.
