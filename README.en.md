# Music Player

## Overview

This sample demonstrates how to develop a music player UI once and deploy it on multiple devices, including bar-type phones, foldable devices, tablets, PCs, Vision devices, and wearables. In addition, a three-layer architecture is used to organize the code project. Adaptive and responsive layouts are combined to build a complete music experience, covering home page recommendations, playlist browsing, full-screen playback, and mini playback control.

## Preview

|                  **Bar-Type Phone**                   |                  **Bi-fold phone**                   |                       **Tablet**                       |
|:-----------------------------------------------------:|:----------------------------------------------------:|:------------------------------------------------------:|
| <img src='screenshots/device/phone_en.png' width=180> | <img src='screenshots/device/fold_en.png' width=330> | <img src='screenshots/device/tablet_en.png' width=580> | 

|                       **PC**                       |                     **Vision**                     |                     **Wearable**                      |
|:--------------------------------------------------:|:--------------------------------------------------:|:-----------------------------------------------------:|
| <img src='screenshots/device/pc_en.png' width=620> | <img src='screenshots/device/tv_en.png' width=620> | <img src='screenshots/device/watch_en.png' width=120> |

## How to Use

- **Home page (recommendation)**  
  After you tap the application, the home page with the bottom navigation bar is displayed by default, showing recommended feeds (implemented by the **recommendation** module).

- **Playlist**  
  You can access the playlist page from the home page or the navigation bar, where you can browse the playlist and select songs. The playlist is implemented by the **MusicAppState** and **playlist** modules; the playback status is implemented by the **MusicAppState** and **player** modules.

- **Playback control**  
  - Use the play/pause, previous, and next buttons on the UI to control the playback of the playlist.  
  - Tap the blank area in the control area or a song in the list to enter the full-screen playback page and view the cover, progress, and lyrics.

## Project Directory

```
├── common                                                  // Common capability layer directory
│   └── musicbasic                                          // Basic HAR: song data, global status, breakpoints, and window tools
│       └── src/main                                        // Standard module source code and resource root directory
│           ├── ets                                         // Root directory of the ArkTS service source code
│           │   ├── api                                     // API DTO and mapping
│           │   ├── constants                               // Common constants
│           │   ├── data                                    // Data model of songs, playlists, and recommendation feeds
│           │   ├── db                                      // Access data such as that in the memory song library
│           │   ├── model                                   // Global playback control status, menus, and songs
│           │   └── util                                    // Tools such as logs, breakpoints, windows, and persistent facades
│           └── resources                                   // Strings, colors, media, and rawfile resources
├── features                                                // Feature HAR: split by service capability
│   ├── player                                              // Player: full-screen page, lyric, and audio playback encapsulation
│   │   └── src/main                                        // Standard module source code and resource root directory
│   │       ├── ets                                         // Root directory of the ArkTS service source code
│   │       │   ├── constant                                // Player and lyric constants
│   │       │   ├── model                                   // Playback UI model, media services, and lyric items
│   │       │   ├── util                                    // LRC, background playback, and playback intent shell
│   │       │   ├── view                                    // Playback page UI components (including adaptation for wearables)
│   │       │   └── viewmodel                               // ViewModel of the playback page
│   │       └── resources                                   // Module string, icon, and theme resources
│   ├── playlist                                            // Playlist: details page, column, and mini playback control bar
│   │   └── src/main                                        // Standard module source code and resource root directory
│   │       ├── ets                                         // Root directory of the ArkTS service source code
│   │       │   ├── model                                   // Playlist, list UI model and data source
│   │       │   ├── util                                    // Tools such as playlist demo data
│   │       │   ├── view                                    // Playlist page and mini bar UIs (including wearable route UIs)
│   │       │   └── viewmodel                               // ViewModel for the association between the playlist and playback control
│   │       └── resources                                   // Module string and icon resources
│   └── recommendation                                      // Recommendation home page, wide-screen panel, and home page mini bar
│       └── src/main                                        // Standard module source code and resource root directory
│           ├── ets                                         // Root directory of the ArkTS service source code
│           │   ├── model                                   // Recommendation block UI model and data source
│           │   ├── util                                    // Tools for recommendation demo data
│           │   ├── view                                    // UIs such as the recommendation home page, mini bar, wide-screen panel, and wearable home page
│           │   └── viewmodel                               // ViewModel of the recommendation home page
│           └── resources                                   // Module string, banner, and theme resources
└── products                                                // Entry for HAPs of different device forms
    ├── default                                             // Entry for mobile phone/tablet applications
    │   └── src/main                                        // Standard module source code and resource root directory
    │       ├── ets                                         // Root directory of the ArkTS entry and pages
    │       │   ├── entryability                            // Entry ability
    │       │   ├── pages                                   // Page routes (main navigation and shell)
    │       │   └── phonebackupextability                   // Extended backup ability on the phone
    │       └── resources                                   // Permission declaration, page profile, icon, and multi-language support
    ├── pc                                                  // Application entry for PCs/2-in-1 devices
    │   └── src/main                                        // Standard module source code and resource root directory
    │       ├── ets                                         // Root directory of the ArkTS entry and pages
    │       │   ├── pages                                   // PC home page and route page
    │       │   ├── pcability                               // PC entry ability
    │       │   └── pcbackupability                         // PC backup extension ability
    │       └── resources                                   // Layered icons, page profile, and multi-language support
    ├── tv                                                  // Application entry for smart large screens
    │   └── src/main                                        // Standard module source code and resource root directory
    │       ├── ets                                         // Root directory of the ArkTS entry and pages
    │       │   ├── pages                                   // TV home page and route page
    │       │   ├── tvability                               // TV entry ability
    │       │   └── tvbackupability                         // TV backup extension ability
    │       └── resources                                   // Layered icons, page profile, and multi-language support
    └── watch                                               // Application entry for smart wearables
        └── src/main                                        // Standard module source code and resource root directory
            ├── ets                                         // Root directory of the ArkTS entry and pages
            │   ├── pages                                   // Wearable home page and route page
            │   ├── watchability                            // Wearable entry ability
            │   └── watchbackupability                      // Wearable backup extension ability
            └── resources                                   // Watch face icons, route profile, and multi-language support
```

## How to Implement

- **Entry and playback shell**  
  - For the entry page [products/default/src/main/ets/pages/Index.ets](https://gitcode.com/HarmonyOS_Samples/MusicHome/blob/master/products/default/src/main/ets/pages/Index.ets) of phones and tablets, **HdsNavigation**, **RecommendPage**, and **dispatchShellPlaybackIntent** and **PlaybackPageCoverContent** provided by **player** are used to display the full-screen playback coverage layer when **MusicAppState.isShowPlay** is true.  
  - The playback intent is distributed by **PlaybackIntentState** (**musicbasic**) and **dispatchShellPlaybackIntent**.

- **Status and data**  
  - The global playback and UI status are mainly implemented by **MusicAppState** (**common** or **musicbasic**). The playlist queue can be synchronized with the local **MusicDbApi**.  
  - The breakpoint and window information is involved in layout calculation by using tools such as **BreakpointSystem** and **WindowInfo**.

- **Recommendation and playlist UIs**  
  - The recommendation page is implemented using **RecommendViewModel** and the **Section** components. The floating mini bar on the home page is stored in **features/recommendation**.  
  - The playlist details, column list, and playback control are implemented using files stored in the **view** and **viewmodel** folders under **features/playlist** by collaborating with **MusicListPlaybackViewModel**.

- **Player and lyrics**  
  - The full-screen playback, control area, and lyric display are implemented by **PlaybackPage**, **LrcView**, **PlayerViewModel**, and **MediaService** stored in **features/player**. The lyric resources and parsing logic are stored in **util/model**.  
  - **audioPlayback** and **KEEP_BACKGROUND_RUNNING** are declared in the mobile phone configuration file **module.json5**, which collaborate with the in-app background player such as **BackgroundUtil**.

- **Wearables and other forms**  
  - Independent pages and circular screens are implemented for wearables using files in the **products** and **watch** folders.

## Required Permissions

| Permission                                | Purpose                                                        |
|-------------------------------------------|----------------------------------------------------------------|
| `ohos.permission.KEEP_BACKGROUND_RUNNING` | Retains the background capabilities related to audio playback. |

## Constraints

1. This sample is only supported on devices running standard systems, including bar-type phones, bi-fold devices (Mate X series), tri-fold devices, widescreen foldable devices, tablets, PCs, Vision devices, and wearables.

2. The HarmonyOS version must be HarmonyOS 6.0.2 Release or later.

3. The DevEcoStudio version must be DevEcoStudio 6.1.0 Release or later.

4. The HarmonyOSSDK version must be HarmonyOS 6.1.0 Release SDK or later.
