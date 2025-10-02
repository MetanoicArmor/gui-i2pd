#!/bin/bash

echo "🚀 Quick Build Script for I2P Daemon GUI"
echo "========================================="

# Очистка предыдущих сборок
echo "🧹 Очистка..."
swift clean 2>/dev/null || true

# Сборка проекта
echo "📦 Swift Package Manager - building..."
swift build -c release

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
    echo "📍 Executable: .build/release/i2pd-gui"
    echo "📦 Size: $(du -sh .build/release/i2pd-gui | cut -f1)"
    echo ""
    echo "🔨 Create .app bundle: ./create-fresh-app.sh"
else
    echo "❌ Build failed!"
    exit 1
fi
