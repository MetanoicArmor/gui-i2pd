import SwiftUI

struct ContentView: View {
    @StateObject private var i2pdManager = I2pdManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Заголовок
                Text("I2P Daemon GUI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Статус сервера
                StatusCard(
                    isRunning: i2pdManager.isRunning,
                    uptime: i2pdManager.uptime,
                    peers: i2pdManager.peerCount
                )
                
                // Кнопки управления
                ControlButtons(i2pdManager: i2pdManager)
                
                // Логи
                if !i2pdManager.logs.isEmpty {
                    LogView(logs: i2pdManager.logs)
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 500, minHeight: 600)
            .navigationTitle("I2P Control Panel")
        }
        .onAppear {
            i2pdManager.checkStatus()
        }
    }
}

struct StatusCard: View {
    let isRunning: Bool
    let uptime: String
    let peers: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Статус")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(isRunning ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(isRunning ? "Запущен" : "Остановлен")
                    .fontWeight(.medium)
            }
            
            if isRunning {
                HStack {
                    Image(systemName: "clock")
                    Text("Время работы: \(uptime)")
                }
                .font(.caption)
                
                HStack {
                    Image(systemName: "person.3")
                    Text("Соединений с пирами: \(peers)")
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ControlButtons: View {
    @ObservedObject var i2pdManager: I2pdManager
    
    var body: some View {
        HStack(spacing: 15) {
            Button(action: {
                if i2pdManager.isRunning {
                    i2pdManager.stopDaemon()
                } else {
                    i2pdManager.startDaemon()
                }
            }) {
                Label(
                    i2pdManager.isRunning ? "Остановить" : "Запустить",
                    systemImage: i2pdManager.isRunning ? "stop.circle.fill" : "play.circle.fill"
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(i2pdManager.isLoading)
            
            Button("Перезапустить") {
                i2pdManager.restartDaemon()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .disabled(i2pdManager.isLoading || !i2pdManager.isRunning)
            
            Button("Обновить статус") {
                i2pdManager.checkStatus()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .disabled(i2pdManager.isLoading)
            
            Button("Очистить логи") {
                i2pdManager.clearLogs()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        
        if i2pdManager.isLoading {
            ProgressView()
                .scaleEffect(0.8)
                .padding(.top, 5)
        }
    }
}

struct LogView: View {
    let logs: [LogEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Логи")
                .font(.headline)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(logs.prefix(50), id: \.id) { log in
                        HStack {
                            Text(log.timestamp, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(log.timestamp, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(log.message)
                                .font(.system(.caption, design: .monospaced))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(logLevelColor(for: log.level).opacity(0.1))
                        .cornerRadius(3)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 200)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private func logLevelColor(for level: LogLevel) -> Color {
        switch level {
        case .info:
            return .blue
        case .warn:
            return .orange
        case .error:
            return .red
        case .debug:
            return .gray
        }
    }
}

#Preview {
    ContentView()
}
