## Termchat-i2p ( Simple Terminal-based P2P Chat for I2P )

A high-performance, serverless, and metadata-resistant instant messenger built in C++ using the **Invisible Internet Project (I2P)** network. This application facilitates direct peer-to-peer communication without relying on central servers or revealing IP addresses.

## Key Features

*   **100% Serverless:** No central authority or database. Connections are established directly between I2P destinations using [SAM v3.1+](https://geti2p.net).
*   **True P2P Tunnels:** Uses I2P's "Streaming Library" to create virtual TCP-like streams over a decentralized mesh of volunteer nodes.
*   **Metadata Resistance:** Unlike Tor, which uses bidirectional circuits, this app utilizes **unidirectional tunnels**. Outgoing data travels a different path than incoming data, significantly complicating traffic analysis.
*   **Persistent Identity:** Support for long-term sessions via private key persistence, allowing you to maintain the same `.i2p` destination across restarts.
*   **Heartbeat Mechanism:** Built-in keep-alive pings to ensure I2P tunnels remain active and responsive during idle periods.

## Why it is Secure

### **1. Garlic Routing**
The application leverages I2P’s **Garlic Routing**, which bundles multiple messages (called "cloves") into a single encrypted packet. This makes it nearly impossible for an intermediary node to distinguish between a single chat message and other background network traffic.

### **2. End-to-End Encryption**
All traffic is wrapped in four layers of encryption before leaving your machine. Only the intended destination can decrypt the final payload. 

### **3. No Exit Nodes**
Unlike Tor, where an "Exit Node" can monitor unencrypted traffic leaving the network, all communications in this app stay **strictly within the I2P network**. There is no "edge" where your data is exposed to the clearnet.

### **4. Cryptographic Destinations**
Users are identified by a **512-bit public key** (Destination) rather than an IP address. There is no mapping between your physical location and your I2P identity.

## How to Build

*   **I2P Router:** You must have a running I2P router with the **SAM bridge** enabled (usually on port 7656).
*   **Dev Environment:** You will need a C++ compiler that supports at least C++11 (since the code uses std::thread, std::mutex, and std::atomic).
*   **libsam3:** This is the C library used to communicate with the I2P SAM bridge (provided as libsam3.zip).

### macOS

On macOS you need Xcode Command Line Tools (or Xcode). The pre-built library in the zip is for Linux, so libsam3 must be built from source.

```bash
# Установка компилятора (если ещё нет)
xcode-select --install

# Распаковка и сборка libsam3 (только библиотека; тесты в архиве под Linux)
unzip -o libsam3.zip
cd libsam3
make clean && make build
cd ..

# Сборка termchat-i2p
make
```

Run from the project directory: `./termchat-i2p`, or use the full path to the binary.

### Linux (Ubuntu/Debian)

```bash
sudo apt update && sudo apt install build-essential
unzip libsam3.zip

# Сборка libsam3
cd libsam3
make
cd ..
```

```bash
# Сборка termchat-i2p с линковкой libsam3
make
```


## Usage Guide

### 1. Identity & Persistence
When you launch the program, you are prompted for a **Local Private Key**.
*   **New Session:** Leave it empty and press `Enter`. The app will generate a new identity. **Save the Local Private Key** displayed at startup if you want to use this "account" again.
*   **Returning User:** Paste your saved **Local Private Key** (the long string of ~884+ characters). This ensures your **Public Destination** remains the same so friends can always reach you at the same address.

### 2. Establishing a Connection
To start a chat, you need your peer's **Local Destination** (Public Key).
1.  Copy your **Local Destination** and send it to your peer via a secure channel.
2.  Paste your peer's **Local Destination** into the "Target" prompt.
3.  The app performs an automatic **Handshake**. Once you see `[SYSTEM]: Connection verified`, you are in encrypted chat mode.

### 3. In-Chat Commands
While in a chat session, use the following commands:

| Command | Action | When to use |
| :--- | :--- | :--- |
| `\end` | **Terminate Chat** | Ends the current session and returns you to "Standby" mode to wait for new peers. |
| `\quit` | **Exit Program** | Safely closes I2P tunnels and shuts down the application. |

### 4. Chatting Logic
*   **Standby Mode:** The program waits for either you to enter a target or for a peer to send you a handshake.
*   **Chat Mode:** Once connected, simply type your message and press `Enter`.
*   **Heartbeats:** The program automatically sends invisible "keep-alive" pings every 30 seconds to prevent your I2P tunnel from timing out.

## Pro-Tips
*   **Metadata Safety:** Because I2P is a mesh network, the first few minutes of a session might be slow while your router finds "exploratory tunnels."
*   **Persistence:** Always keep your **Private Key** secret. Anyone with that key can impersonate your I2P destination.

