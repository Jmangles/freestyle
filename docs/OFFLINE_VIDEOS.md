# Offline Training Studio
Users should be able to download videos they've opened in the training studio in order to view them when their device is offline or lacks service.

**Platform scope: Android and iOS only.** The web build is unaffected.

---

## UX

When the user visits a training studio page with an internet connection they are served a video from our CDN.

There will be a save icon that moves the video from their application cache into permanent storage. Before proceeding, available free storage is checked — if less than 1 GB is free, a warning dialog is shown with the option to proceed or cancel. No other dialog is shown.

The video is pre-downloaded to the app cache directory before the player opens it. The save icon becomes tappable once that pre-download completes and the player has started — no additional download is needed when the user taps save. If the pre-download fails, the player falls back to streaming directly from the CDN and the save icon remains grayed out for the session with no error shown.

Once the video has been saved to device the training studio will change the save icon into a delete icon. This action will open a dialog to ask them if they'd like to remove the video from their device. Confirming deletes the file from permanent storage.

---

## File Storage

Videos are stored using the same path structure as the CDN, rooted at the platform application documents directory (`getApplicationDocumentsDirectory()` via `path_provider`):

```
{documents_directory}/tricks/{trick_id}/forward.mp4
{documents_directory}/tricks/{trick_id}/forward_mobile.mp4
```

Video availability is determined entirely by file existence — no database table is needed.

---

## Quality

Videos come in two quality levels detected by filename: files with `_mobile` are mobile quality; files without are full quality.

### Quality selection rules

| Connection | Files present on device | Behavior |
|---|---|---|
| WiFi | `forward.mp4` | Serve from device |
| WiFi | `forward_mobile.mp4` | Silently download `forward.mp4`, delete `forward_mobile.mp4` |
| WiFi | Neither | Download `forward.mp4` from CDN |
| Mobile | `forward.mp4` | Serve full quality from device — no downgrade |
| Mobile | `forward_mobile.mp4` | Serve from device |
| Mobile | Neither | Download `forward_mobile.mp4` from CDN |

The quality swap (WiFi with only mobile quality on device) runs silently in the background when the training studio is opened. No indicator is shown to the user.

### Cache quality upgrade

The same quality logic applies to media_kit's application cache. If a lower quality file is present in the cache when the app is on WiFi, the lower quality entry is evicted and the higher quality version is downloaded in its place.

When a background quality upgrade is running, the video is already considered saved and the delete icon is shown instead of the save icon — save is not accessible during this window.

---

## Error Handling

**Download failure or interruption**: If a download fails or is interrupted mid-transfer, the partial file is deleted before the error is shown. The save icon returns to its unsaved state. No partial or corrupt files are left on disk.

**Insufficient storage**: If free storage is below 1 GB when the user taps save, a warning dialog is shown with the option to proceed or cancel. The file size is not displayed.

---

## Test Cases

### Save and delete

| # | Scenario | Pass condition |
|---|---|---|
| V1.1 | Open training studio on WiFi, tap save icon | `forward.mp4` appears in the correct path; icon changes to delete |
| V1.2 | Tap delete icon, confirm dialog | File is deleted from permanent storage; icon returns to save state |
| V1.3 | Tap save with less than 1 GB free storage | Warning dialog is shown; user can choose to proceed or cancel |
| V1.4 | Download is interrupted mid-transfer | Partial file is deleted; save icon returns to unsaved state |

### Quality

| # | Scenario | Pass condition |
|---|---|---|
| V3.1 | Save video on mobile connection | `forward_mobile.mp4` is saved to permanent storage |
| V3.2 | Re-open training studio on WiFi with only `forward_mobile.mp4` present | `forward.mp4` downloads silently; `forward_mobile.mp4` is deleted |
| V3.3 | Open training studio on mobile with `forward.mp4` present | Full quality served from device; no download |
| V3.4 | Quality swap download fails mid-transfer | Partial file deleted; existing mobile file retained; no crash |

### Offline playback

| # | Scenario | Pass condition |
|---|---|---|
| V4.1 | Go offline with forward video saved | Training studio opens and plays correctly |
| V4.2 | Go offline without any video saved | Training studio button hidden (per OFFLINE.md 6.4) |
