# Offline Training Studio
Users should be able to download videos they've opened in the training studio in order to view them when their device is offline or lacks service.

**Platform scope: Android and iOS only.** The web build is unaffected.

---

## UX

When the user visits a training studio page with an internet connection they are served a video from our CDN.

There will be a save icon that moves the video from their application cache into permanent storage. Before proceeding, available free storage is checked — if less than 1 GB is free, a warning dialog is shown with the option to proceed or cancel. No other dialog is shown.

The video is pre-downloaded to the app cache directory before the player opens it. The save icon becomes tappable once that pre-download completes and the player has started — no additional download is needed when the user taps save. If the pre-download fails, the player falls back to streaming directly from the CDN and the save icon remains grayed out for the session with no error shown.

The same 1 GB storage check applies when the reversed video is downloaded on demand.

Once the video has been saved to device the training studio will change the save icon into a delete icon. This action will open a dialog to ask them if they'd like to remove the video from their device. Confirming deletes the file from permanent storage.

Reversed videos are not saved as part of the initial save action. They are downloaded on demand when the user taps the reverse button in the training studio.

---

## File Storage

Videos are stored using the same path structure as the CDN, rooted at the platform application documents directory (`getApplicationDocumentsDirectory()` via `path_provider`):

```
{documents_directory}/tricks/{trick_id}/forward.mp4
{documents_directory}/tricks/{trick_id}/reversed.mp4
{documents_directory}/tricks/{trick_id}/forward_mobile.mp4
{documents_directory}/tricks/{trick_id}/reversed_mobile.mp4
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

The same rules apply to reversed videos when they are downloaded on demand.

### Cache quality upgrade

The same quality logic applies to media_kit's application cache. If a lower quality file is present in the cache when the app is on WiFi, the lower quality entry is evicted and the higher quality version is downloaded in its place.

When a background quality upgrade is running, the video is already considered saved and the delete icon is shown instead of the save icon — save is not accessible during this window.

---

## Video Player

When offline the video player should hide the reverse button if no reversed video is present on the device.

---

## Error Handling

**Download failure or interruption**: If a download fails or is interrupted mid-transfer, the partial file is deleted before the error is shown. The save icon returns to its unsaved state. No partial or corrupt files are left on disk.

**Reversed video download failure**: If an on-demand reversed video download fails or is interrupted, the partial file is deleted. The reverse button returns to its downloadable state (visible but not playing). No partial file is left on disk.

**Insufficient storage**: If free storage is below 1 GB when the user taps save or taps the reverse button to trigger an on-demand download, a warning dialog is shown with the option to proceed or cancel. The file size is not displayed.

---

## Test Cases

### Save and delete

| # | Scenario | Pass condition |
|---|---|---|
| V1.1 | Open training studio on WiFi, tap save icon | `forward.mp4` appears in the correct path; icon changes to delete |
| V1.2 | Tap delete icon, confirm dialog | File is deleted from permanent storage; icon returns to save state |
| V1.3 | Tap save with less than 1 GB free storage | Warning dialog is shown; user can choose to proceed or cancel |
| V1.4 | Download is interrupted mid-transfer | Partial file is deleted; save icon returns to unsaved state |

### Reversed video

| # | Scenario | Pass condition |
|---|---|---|
| V2.1 | Tap reverse button online with no reversed file on device | Reversed video downloads and plays |
| V2.2 | Tap reverse button offline with no reversed file on device | Reverse button is hidden; cannot be tapped |
| V2.3 | Tap reverse button offline with reversed file on device | Reversed video plays from device |
| V2.4 | Tap reverse button online, download starts, then fails mid-transfer | Partial reversed file is deleted; reverse button returns to downloadable state; no corrupt file remains on disk |
| V2.5 | Tap reverse button with less than 1 GB free storage | Warning dialog is shown; user can choose to proceed or cancel |

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
| V4.3 | Go offline with forward saved but no reversed | Video plays; reverse button is hidden |
| V4.4 | Go offline with both forward and reversed saved | Both directions play correctly |
