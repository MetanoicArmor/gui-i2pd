#!/usr/bin/env python3
"""
Создание компактных иконок трея с минимальным размером
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_compact_tray_icons():
    """Создает самый компактный вариант иконок трея"""
    
    print("📱 Создание компактных иконок трея...")
    print("🎯 Минимальный размер для системного трея macOS!")
    
    # Используем меньшие размеры для контейнера иконки
    icon_sizes = [16, 18]  # Минимальные размеры для трея
    
    for icon_size in icon_sizes:
        print(f"\n📱 Создание компактной иконки {icon_size}x{icon_size} пикселей...")
        
        # Создаем изображение
        img = Image.new('RGBA', (icon_size, icon_size), (0, 0, 0, 0))  # Прозрачный фон
        draw = ImageDraw.Draw(img)
        
        # Очень компактный шрифт для минимального размера
        compact_font_sizes = {
            16: 9,   # Очень маленький шрифт для 16px
            18: 11   # Маленький шрифт для 18px
        }
        
        font_size = compact_font_sizes.get(icon_size, 10)
        
        # Пытаемся использовать компактный системный шрифт
        try:
            try:
                font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", font_size)
            except:
                try:
                    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
                except:
                    # Используем системный шрифт по умолчанию
                    font = ImageFont.load_default()
        except:
            font = ImageFont.load_default()
        
        # Текст "I2P" - компактный вариант
        text = "I2P"
        
        # Получаем размеры текста
        try:
            bbox = draw.textbbox((0, 0), text, font=font)
            text_width = bbox[2] - bbox[0]
            text_height = bbox[3] - bbox[1]
        except:
            # Минимальные fallback размеры
            text_width = len(text) * (font_size * 0.6)
            text_height = font_size
        
        # Точно центрируем компактный текст
        x = (icon_size - text_width) // 2
        y = (icon_size - text_height) // 2 - 1
        
        # Четкий черный текст для светлых тем (минимальная тень)
        draw.text((x, y), text, fill=(0, 0, 0, 255), font=font)
        
        # Очень легкая тень для четкости (минимальная)
        shadow_color = (255, 255, 255, 8)
        draw.text((x + 1, y + 1), text, fill=shadow_color, font=font)
        
        # Сохраняем основную компактную иконку
        if icon_size == 18:  # Основной размер для трея
            img.save("iconset-work/tray-icon.png", "PNG")
            print(f"   ✅ Компактная иконка {icon_size}x{icon_size}")
        
        # Создаем компактную инвертированную версию для темной темы
        img_inv = Image.new('RGBA', (icon_size, icon_size), (0, 0, 0, 0))  # Прозрачный фон
        draw_inv = ImageDraw.Draw(img_inv)
        
        # Четкий белый текст для темных тем
        draw_inv.text((x, y), text, fill=(255, 255, 255, 255), font=font)
        # Минимальная тень для темных тем
        shadow_color_inv = (0, 0, 0, 8)
        draw_inv.text((x + 1, y + 1), text, fill=shadow_color_inv, font=font)
        
        if icon_size == 18:
            img_inv.save("iconset-work/tray-icon-dark.png", "PNG")
            print(f"   ✅ Компактная темная иконка {icon_size}x{icon_size}")
        
        # Дополнительные компактные размеры
        filename = f"iconset-work/tray-icon-{icon_size}x{icon_size}-compact.png"
        img.save(filename, "PNG")
        filename_inv = f"iconset-work/tray-icon-{icon_size}x{icon_size}-dark-compact.png"
        img_inv.save(filename_inv, "PNG")
    
    print("\n✨ Созданы компактные иконки!")
    print("📁 Минимальные файлы для системного трея:")
    print("   📱 tray-icon.png - компактная иконка (минимальный размер)")
    print("   🌙 tray-icon-dark.png - компактная темная иконка (минимальный размер)")
    
    # Проверяем размеры файлов
    compact_files = ["tray-icon.png", "tray-icon-dark.png"]
    print("\n📊 Размеры компактных файлов:")
    for filename in compact_files:
        filepath = f"iconset-work/{filename}"
        if os.path.exists(filepath):
            size = os.path.getsize(filepath)
            print(f"   ✅ {filename}: {size} байт (компактная версия)")
    
    print("\n💡 Особенности компактных иконок:")
    print("   ✅ Минимальный размер шрифта для экономии места")
    print("   ✅ Компактный текст 'I2P' с минимальными отступами")
    print("   ✅ Легкие тени для четкости без увеличения размера")
    print("   ✅ Оптимизированное использование пространства")
    
    return True

if __name__ == "__main__":
    try:
        success = create_compact_tray_icons()
        if success:
            print("\n✅ Компактные иконки созданы успешно!")
            print("🚀 Пересоберите приложение для минимального размера!")
        else:
            print("\n❌ Не удалось создать компактные иконки")
            exit(1)
    except Exception as e:
        print(f"\n❌ Ошибка создания компактных иконок: {e}")
        exit(1)
