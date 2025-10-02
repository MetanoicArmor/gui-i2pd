#!/bin/bash

echo "🔧 Настройка для работы с Xcode"
echo "================================"

# Проверяем наличие бинарника в исходном месте
if [ -f "i2pd" ]; then
    echo "✅ Найден исходный бинарник i2pd"
    echo "📊 Размер: $(ls -lh i2pd | awk '{print $5}')"
    
    # Проверяем конфигурацию Xcode проекта
    if [ -d "i2pd-gui.xcodeproj" ]; then
        echo "📁 Найден проект Xcode"
        echo "🔧 Настройка для работы с Xcode..."
        
        # Показываем доступные варианты копирования
        echo ""
        echo "Выберите вариант интеграции:"
        echo "1 - Копировать бинарник в папку приложения (рекомендуется)"
        echo "2 - Оставить как есть (создавать симлинки)"
        echo "3 - Показать текущее состояние"
        
        read -p "Введите номер (1-3): " choice
        
        case $choice in
            1)
                echo "📦 Копируем бинанк в папку проекта..."
                cp i2pd i2pd-gui/
                echo "✅ Бинарник скопирован в i2pd-gui/i2pd"
                echo "💡 Теперь можно запускать в Xcode"
                ;;
            2)
                echo "🔗 Создаем симлинки..."
                ln -sf "$(pwd)/i2pd" i2pd-gui/i2pd 2>/dev/null || cp i2pd i2pd-gui/
                echo "✅ Симлинк создан"
                ;;
            3)
                echo "📋 Текущее состояние:"
                echo "   Основной бинарник: $(ls -la i2pd 2>/dev/null || echo "не найден")"
                echo "   Бинарник в проекте: $(ls -la i2pd-gui/i2pd 2>/dev/null || echo "не найден")"
                ;;
            *)
                echo "❌ Неверный выбор"
                ;;
        esac
    else
        echo "❌ Проект Xcode не найден"
        echo "💡 Убедитесь что файл i2pd-gui.xcodeproj существует"
    fi
else
    echo "❌ Бинарник i2pd не найден в текущей директории"
    echo "💡 Поместите бинарник i2pd в корень проекта"
fi

echo ""
echo "🚀 Готово! Теперь можно:"
echo "   open i2pd-gui.xcodeproj"
echo "   swift run"
