#include <iostream>
#include <string>
#include <thread>
#include <cstring>
#include <unistd.h>
#include <sys/socket.h>
#include <mutex>
#include <ctime>
#include <iomanip>
#include <sys/ioctl.h>
#include <atomic>
#include <sstream>

extern "C" {
    #include "libsam3.h"
}

// --- COLORS & CONFIG ---
const std::string RESET     = "\033[0m";
const std::string COL_TIME  = "\033[38;5;244m";
const std::string COL_YOU   = "\033[1;32m";
//const std::string COL_PEER  = "\033[1;36m";
//const std::string COL_PEER  = "\033[38;5;208m"; // Rich Orange
const std::string COL_PEER  = "\033[1;35m"; // High contrast Magenta

const std::string COL_SYS   = "\033[1;33m";
const std::string COL_ERR   = "\033[1;31m";
const int HEARTBEAT_SEC     = 30; 

std::mutex console_mtx;
std::mutex target_mtx; 
std::string target_dest = ""; 
bool prompt_active = false;
std::atomic<bool> running{true};
std::atomic<bool> in_chat{false}; 

std::string get_timestamp() {
    std::time_t now = std::time(nullptr);
    std::tm* local = std::localtime(&now);
    std::ostringstream oss;
    oss << COL_TIME << "[" << std::put_time(local, "%H:%M:%S") << "] " << RESET;
    return oss.str();
}

void send_raw(Sam3Session* ses, const std::string& target, const std::string& msg) {
    if (target.empty()) return;
    Sam3Connection* conn = sam3StreamConnect(ses, target.c_str());
    if (conn) {
        send(conn->fd, msg.c_str(), msg.length(), 0);
        sam3CloseConnection(conn);
    }
}

void receiver_thread(Sam3Session* ses) {
    while (running) {
        Sam3Connection* conn = sam3StreamAccept(ses);
        if (conn) {
            char buffer[4096] = {0};
            ssize_t n = recv(conn->fd, buffer, sizeof(buffer) - 1, 0);
            
            if (n > 0 && buffer[0] != 0x00) {
                std::string msg(buffer);
                
                if (msg.find("HANDSHAKE:") == 0) {
                    std::string peer_key = msg.substr(10);
                    {
                        std::lock_guard<std::mutex> lock(target_mtx);
                        target_dest = peer_key;
                    }
                    send_raw(ses, peer_key, "ACK_HANDSHAKE:" + std::string(ses->pubkey));
                    std::lock_guard<std::mutex> c_lock(console_mtx);
                    std::cout << "\r\33[2K" << COL_SYS << "[SYSTEM]: Handshake received. ACK sent." << RESET << std::endl;
                    if (prompt_active) std::cout << COL_YOU << "YOU: " << RESET << std::flush;

                } else if (msg.find("ACK_HANDSHAKE:") == 0) {
                    {
                        std::lock_guard<std::mutex> lock(target_mtx);
                        target_dest = msg.substr(14);
                    }
                    std::lock_guard<std::mutex> c_lock(console_mtx);
                    std::cout << "\r\33[2K" << COL_SYS << "[SYSTEM]: ACK received. Connection verified." << RESET << std::endl;
                    if (prompt_active) std::cout << COL_YOU << "YOU: " << RESET << std::flush;

                } else if (msg == "NOTIFY_END:") {
                    std::lock_guard<std::mutex> c_lock(console_mtx);
                    std::cout << "\r\33[2K" << COL_SYS 
                              << "[SYSTEM]: Peer ended the chat. Returning to standby.\n"
                              << "[SYSTEM]: Waiting for handshake or enter Target: " << RESET << std::flush;
                    {
                        std::lock_guard<std::mutex> t_lock(target_mtx);
                        target_dest = "";
                    }
                    in_chat = false;
                    prompt_active = false;

                } else {
                    std::lock_guard<std::mutex> c_lock(console_mtx);
                    if (prompt_active) std::cout << "\r\33[2K" << std::flush;
                    std::cout << get_timestamp() << COL_PEER << "[PEER]: " << RESET << msg << std::endl;
                    if (prompt_active) std::cout << COL_YOU << "YOU: " << RESET << std::flush;
                }
            }
            sam3CloseConnection(conn);
        }
        usleep(100000);
    }
}

void heartbeat_thread(Sam3Session* ses) {
    while (running) {
        sleep(HEARTBEAT_SEC);
        std::string current_target;
        {
            std::lock_guard<std::mutex> lock(target_mtx);
            current_target = target_dest;
        }
        if (!current_target.empty()) send_raw(ses, current_target, std::string(1, 0x00));
    }
}

bool is_valid_b64(const std::string& str, size_t min_len) {
    if (str.length() < min_len) return false;
    for (char c : str) {
        if (!isalnum(c) && c != '-' && c != '~' && c != '=') {
            return false;
        }
    }
    return true;
}


bool is_valid_format(const std::string& str, size_t min_len, size_t max_len = 0) {
    if (str.length() < min_len) return false;
    if (max_len > 0 && str.length() > max_len) return false;
    for (char c : str) {
        if (!isalnum(c) && c != '-' && c != '~' && c != '=') return false;
    }
    return true;
}


int main() {
    Sam3Session ses;
    memset(&ses, 0, sizeof(Sam3Session));

    
    std::string provided_key;
    
    while (true) {
        std::cout << COL_SYS << "[SYSTEM]: Enter Local Private Key (leave empty to generate new): " << RESET << std::flush;
        std::getline(std::cin, provided_key);
    
        if (provided_key.empty()) break;
    
        // Ensure it's not a short Public Key
        if (provided_key.length() < 884) {
            std::cout << COL_ERR << "[ERROR]: This looks like a Public Key. Persistence requires a full Private Key (min 884 chars)." << RESET << std::endl;
            continue;
        }
    
        if (is_valid_format(provided_key, 884)) break;
        std::cout << COL_ERR << "[ERROR]: Invalid character format in Private Key." << RESET << std::endl;
    }
    
    const char* key_ptr = provided_key.empty() ? SAM3_DESTINATION_TRANSIENT : provided_key.c_str();

    if (sam3CreateSession(&ses, SAM3_HOST_DEFAULT, SAM3_PORT_DEFAULT, 
                          key_ptr, SAM3_SESSION_STREAM, 
                          EdDSA_SHA512_Ed25519, NULL) < 0) {
        std::cerr << COL_ERR << "[ERROR]: Cannot connect to I2P SAM bridge (default 127.0.0.1:7656).\n"
                  << "         Is the I2P router running with SAM bridge enabled?" << RESET << std::endl;
        return 1;
    }

    std::cout << COL_SYS << "[SYSTEM]: Local Destination: " << RESET << ses.pubkey << std::endl;
    std::cout << COL_SYS << "[SYSTEM]: Local Private Key: " << RESET << ses.privkey << std::endl;
    
    std::thread(receiver_thread, &ses).detach();
    std::thread(heartbeat_thread, &ses).detach();

    // Startup Prompt
    std::cout << COL_SYS << "[SYSTEM]: Waiting for handshake or enter Target: " << RESET << std::flush;

    while (running) {
        // --- Standby Phase ---
        while (running && !in_chat) {
            {
                std::lock_guard<std::mutex> lock(target_mtx);
                if (!target_dest.empty()) { in_chat = true; break; } 
            }
            
            struct timeval tv = {0, 500000};
            fd_set fds; FD_ZERO(&fds); FD_SET(STDIN_FILENO, &fds);
            if (select(STDIN_FILENO + 1, &fds, NULL, NULL, &tv) > 0) {
                std::string input;
                if (std::getline(std::cin, input) && !input.empty()) {
                    if (input == "\\quit") {
                        std::cout << COL_SYS << "Are you sure you want to quit? (y/n): " << RESET << std::flush;
                        std::string confirm;
                        std::getline(std::cin, confirm);
                        if (confirm == "y" || confirm == "Y") {
                            running = false;
                            break;
                        }
                        std::cout << COL_SYS << "[SYSTEM]: Waiting for handshake or enter Target: " << RESET << std::flush;
                        continue;
                    }
                    
                    // Check if it is a Private Key (>= 884 chars)
                    if (input.length() >= 800) {
                        std::cout << COL_ERR << "[ERROR]: You entered a Private Key. For safety, enter only a Peer Destination." << RESET << std::endl;
                        std::cout << COL_SYS << "[SYSTEM]: Waiting for handshake or enter Target: " << RESET << std::flush;
                        continue;
                    }

                    // Validate a Standard Destination (516-616 chars)
                    if (!is_valid_format(input, 516, 700)) {
                        std::cout << COL_ERR << "[ERROR]: Invalid Destination format (must be 516-616 chars)." << RESET << std::endl;
                        std::cout << COL_SYS << "[SYSTEM]: Waiting for handshake or enter Target: " << RESET << std::flush;
                        continue;
                    }
                    
                    send_raw(&ses, input, "HANDSHAKE:" + std::string(ses.pubkey));
                    std::cout << COL_SYS << "[SYSTEM]: Handshake sent. Waiting for ACK..." << RESET << std::endl;
                }
            }
        }

        // --- Chat Phase ---
        while (running && in_chat) {
            {
                std::lock_guard<std::mutex> lock(console_mtx);
                if (!prompt_active) {
                    std::cout << COL_YOU << "YOU: " << RESET << std::flush;
                    prompt_active = true;
                }
            }

            struct timeval tv = {0, 100000};
            fd_set fds; FD_ZERO(&fds); FD_SET(STDIN_FILENO, &fds);
            
            if (select(STDIN_FILENO + 1, &fds, NULL, NULL, &tv) > 0) {
                std::string message;
                if (std::getline(std::cin, message)) {
                    if (!in_chat) break;

                    if (message == "\\end") {
                        std::string current_target;
                        { std::lock_guard<std::mutex> lock(target_mtx); current_target = target_dest; }
                        
                        send_raw(&ses, current_target, "NOTIFY_END:");
                        { std::lock_guard<std::mutex> lock(target_mtx); target_dest = ""; }
                        in_chat = false;
                        prompt_active = false;
                        std::cout << COL_SYS << "[SYSTEM]: Chat closed. Returning to standby.\n" 
                                  << "[SYSTEM]: Waiting for handshake or enter Target: " << RESET << std::flush;
                        break; 
                    }

                    if (message == "\\quit") {
                        std::cout << COL_SYS << "[SYSTEM]: \\quit is only available outside of chat. Use \\end first." << RESET << std::endl;
                        prompt_active = false;
                        continue;
                    }

                    if (!message.empty()) {
                        std::string current_target;
                        { std::lock_guard<std::mutex> lock(target_mtx); current_target = target_dest; }
                        
                        send_raw(&ses, current_target, message);
                        
                        {
                            std::lock_guard<std::mutex> lock(console_mtx);
                            
                            // Get terminal width
                            struct winsize w;
                            ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
        
        

                            // Calculate how many lines the raw input (including "YOU: ") occupied
                            // Apply integer ceiling division.
                            int total_chars = 5 + message.length();
                            int lines_to_clear = (total_chars + w.ws_col - 1) / w.ws_col;

                            // Move UP and Clear every line of the multiline echo
                            for (int i = 0; i < lines_to_clear; ++i) {
                                std::cout << "\r\33[2K\033[A"; 
                            }
                            
                            std::cout << "\r\33[2K"; // clear of the target line
                            
                            std::cout << get_timestamp() << COL_YOU << "[YOU]: " << RESET << message << std::endl;
                        }
                        prompt_active = false;
                    }
                }
            }
        }
    }

    sam3CloseSession(&ses);
    std::cout << COL_SYS << "[SYSTEM]: Graceful shutdown complete." << RESET << std::endl;
    return 0;
}
