# Open Chat

A native iOS chat app built with SwiftUI, supporting OpenRouter and Requesty as AI backends with streaming responses, markdown rendering, and multi-conversation support.

## Features

- **OpenRouter & Requesty**: OpenAI-compatible API proxies giving access to hundreds of models
- **Streaming responses**: Real-time token-by-token text streaming
- **Markdown rendering**: Code blocks, inline formatting, and rich text display
- **Multiple conversations**: Thread/session management with search
- **SwiftData persistence**: Chat history saved locally
- **Dark mode**: Full light/dark appearance support
- **Settings screen**: Per-provider API key and model configuration
- **iOS 18+**: Built for modern SwiftUI and Swift concurrency

## Requirements

- macOS with Xcode 16+ (command-line tools)
- iOS 18.0+ device or simulator
- Apple ID signed into Xcode (for device signing)

## Quick Start — All CLI, No Xcode GUI

```bash
# 0. One-time setup (skip if already signed into Xcode)
make signin        # Opens Xcode Accounts → sign in with your Apple ID

# 1. Check everything is ready
make doctor

# 2. Build, install, and launch on your device — one command
make run
```

> **Important**: The first time, you must sign into Xcode with your Apple ID (`make signin`). This creates your signing certificate. After that one-time step, you never need to open Xcode again — everything works from the terminal.

## Commands

### Setup

| Command | Description |
|---------|-------------|
| `make signin` | **One-time**: open Xcode to sign in with Apple ID |
| `make setup` | Show detected config (team, device, bundle ID) |
| `make doctor` | Check all prerequisites (certificates, accounts, device) |
| `make device` | List connected iOS devices |
| `make team` | Show signing identity details + expiry |

### Build

| Command | Description |
|---------|-------------|
| `make build` | Build for device (Release) |
| `make build-debug` | Build for device (Debug) |
| `make sim-build` | Build for simulator |
| `make sim-run` | Build + launch in simulator |
| `make clean` | Remove all build artifacts |

### Sideload & Run

| Command | Description |
|---------|-------------|
| `make sideload` | Build + install on device |
| `make install` | Install existing .app on device |
| `make launch` | Launch installed app on device |
| `make run` | **Build + install + launch** (all-in-one) |
| `make uninstall` | Remove app from device |
| `make ipa` | Export .ipa for distribution |

### Utilities

| Command | Description |
|---------|-------------|
| `make open` | Open project in Xcode (GUI fallback) |
| `make logs` | Show device logs for open-chat |

## Configuration

### Override auto-detection

The Makefile auto-detects your team and device. Override with environment variables:

```bash
# Set your Team ID (find under Xcode > Settings > Accounts)
export TEAM_ID=XXXXXXXXXX

# Set a specific device
export DEVICE_ID=00000000-0000-0000-0000-000000000000

# Custom bundle identifier
export BUNDLE_ID=com.yourname.openchat
```

### First-time setup

The signing certificate in your keychain may be expired or missing.
Run `make doctor` to check, then:

```bash
make signin    # Opens Xcode → sign in with your Apple ID once
```

After signing in, Xcode creates a fresh certificate. Close Xcode — you won't need it again.

### Trust the developer certificate (on device)

After first install, trust the developer profile on your iPhone:

1. **Settings > General > VPN & Device Management**
2. Tap your developer profile
3. Tap **Trust**

### Free Apple ID limitations

Apps signed with a free account **expire after 7 days**. Just run `make run` again to re-install.

### Wireless debugging

Once you've connected via USB once, you can enable wireless:

1. Plug in via USB, then: **Xcode > Window > Devices and Simulators**
2. Select your device, check **Connect via network**
3. Now `make run` works over Wi-Fi (device must be on same network)

## AI Provider Configuration

Configure your providers in the app's **Settings** screen:

| Provider | Endpoint | Default Model |
|----------|----------|---------------|
| Requesty | `router.requesty.ai` | `meta-llama/llama-3.3-70b-instruct:free` |
| OpenRouter | `openrouter.ai` | `meta-llama/llama-3.3-70b-instruct:free` |

Both are OpenAI-compatible. Model lists are fetched without authentication. Get your API key from [openrouter.ai](https://openrouter.ai) or [requesty.ai](https://requesty.ai) to start chatting.

## Project Structure

```
open-chat/
├── Sources/
│   ├── App/                     # @main entry point
│   ├── Models/                  # SwiftData: Conversation, Message, AIProvider
│   ├── Services/                # OpenAI-compatible streaming provider
│   ├── ViewModels/              # MVVM: Chat, Conversations, Settings
│   ├── Views/                   # SwiftUI: Chat bubbles, sidebar, settings
│   └── Persistence/            # SwiftData container
├── Resources/
│   └── Info.plist
├── Makefile                     # CLI build/sideload/run
├── Package.swift                # SPM manifest
└── README.md
```

## Architecture

- **UI**: SwiftUI with `@Observable` (iOS 18+)
- **State**: MVVM pattern
- **Data**: SwiftData with `ModelContainer`
- **Streaming**: `URLSession.bytes` + `AsyncThrowingStream`
- **Persistence**: SwiftData (chat history), `UserDefaults` (settings)
- **Markdown**: `AttributedString` with inline + code block parsing

## License

[MIT](LICENSE)
