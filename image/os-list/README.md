# image/os-list — Raspberry Pi Imager integration

This lets users install MPI-Station straight from the official
[Raspberry Pi Imager](https://www.raspberrypi.com/software/): **Choose OS → Use
custom → (paste this JSON's URL)**, or by hosting it as a custom repository.
Imager downloads, verifies (`extract_sha256`), and flashes the image, then can
apply its own first-boot customization.

## Files

| File | Purpose |
|---|---|
| `mpi-station.json` | The `os_list` template with `__PLACEHOLDER__` tokens |
| `generate-os-list.sh` | Fills the placeholders from a built `.img.xz`, emits release JSON + a `.sha256` |
| `icon.png` | (add at release) 40×40-ish PNG shown in the Imager OS list |

## Release flow

1. Build and compress the image (`image/build-image.sh --compress`).
2. Upload `mpi-station-YYYYMMDD.img.xz` to the download host (see the main
   README's hosting notes — GitHub Releases, Cloudflare R2, or archive.org).
3. Generate the release JSON:

   ```bash
   image/os-list/generate-os-list.sh \
     --image image/output/mpi-station-20260722.img.xz \
     --url   https://<host>/mpi-station-20260722.img.xz \
     --date  2026-07-22 \
     --output image/os-list/mpi-station.release.json
   ```

   This computes `image_download_size` (compressed bytes), `extract_size`
   (uncompressed bytes, read from the xz index), and `extract_sha256` (streamed
   from the decompressed image), and writes a `<image>.sha256` next to the image
   for out-of-band verification.

4. Host `mpi-station.release.json` at a **stable URL** (e.g. the GitHub Pages
   site or the same bucket) and give that URL to users, or add it to a custom
   repository list.

## Field notes

- `extract_sha256` is security-critical: Imager aborts the write and wipes the
  partition table if the decompressed image's hash doesn't match. Always
  regenerate it per build — never hand-edit.
- `devices: ["pi4-64bit"]` scopes the entry to Raspberry Pi 4 (64-bit). Add
  `"pi5-64bit"` once the image is validated on a Pi 5, or remove the field to
  show the image for all devices.
- `init_format` is intentionally omitted for the beta. The image runs its own
  first-boot provisioning (data-partition split, sample restore), so Imager's
  advanced OS-customization dialog is left disabled to avoid conflicts. Once the
  interaction is verified, set `"init_format": "systemd"` to let users preset
  hostname / user / Wi-Fi / SSH from Imager.
- `architecture: "armv8"` = arm64.

Schema reference:
[rpi-imager os-list schema](https://github.com/raspberrypi/rpi-imager/blob/qml/doc/json-schema/os-list-schema.json).
