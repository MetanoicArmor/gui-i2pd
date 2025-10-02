#!/usr/bin/env python3
"""
Создание текстовых иконок "I2P" для системного трея
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_text_tray_icons():
    """Создает текстовые иконки 'I2P' для системного трея"""
    
    print("📝 Создание текстовых иконок 'I2P' для трея...")
    
    # Размеры для трея
    sizes = [18, 20, 16]  # Основной размер для macOS трея
    
    for size in sizes:
        print(f"✏️ Создание текстовой иконки {size}x{size}...")
        
        # Создаем изображение
        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))  # Прозрачный фон
        draw = ImageDraw.Draw(img)
        
        # Пытаемся использовать системный шрифт
        try:
            # Используем системный шрифт macOS
            font_size = max(12, size - 4)  # Размер шрифта в зависимости от размера иконки
            try:
                font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", font_size)
            except:
                try:
                    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
                except:
                    font = ImageFont.load_default()
        except:
            font = ImageFont.load_default()
        
        # Текст "I2P"
        text = "I2P"
        
        # Получаем размеры текста
        try:
            bbox = draw.textbbox((0, 0), text, font=font)
            text_width = bbox[2] - bbox[0]
            text_height = bbox[3] - bbox[1]
        except:
            # Fallback если bbox не работает
            text_width = len(text) * (size // 3)
            text_height = size // 2
        
        # Центрируем текст
        x = (size - text_width) // 2
        y = (size - text_height) // 2 - 1  # Немного выше центра
        
        # Черный текст для контрастности
        draw.text((x, y), text, fill=(0, 0, 0, 255), font=font)
        
        # Сохраняем основную иконку
        if size == 18:  # Основной размер
            img.save("iconset-work/tray-icon.png", "PNG")
            img.save("iconset-work/tray-icon-mono.png", "PNG")
            print(f"   ✅ Основная текстовая иконка {size}x{size}")
        
        # Создаем инвертированную версию для темной темы
        img_inv = Image.new('RGBA', (size, size), (0, 0, 0, 0))  # Прозрачный фон
        draw_inv = ImageDraw.Draw(img_inv)
        
        # Белый текст для темных тем
        draw_inv.text((x, y), text, fill=(255, 255, 255, 255), font=font)
        
        if size == 18:
            img_inv.save("iconset-work/tray-icon-dark.png", "PNG")
            print(f"   ✅ Инвертированная текстовая иконка {size}x{size}")
        
        # Дополнительные размеры
        filename = f"iconset-work/tray-icon-{size}x{size}.png"
        img.save(filename, "PNG")
        filename_inv = f"iconset-work/tray-icon-{size}x{size}-inverted.png" 
        img_inv.save(filename_inv, "PNG")
    
    print("\n📝 Созданы текстовые иконки 'I2P'!")
    print("📁 Основные файлы:")
    print("   ✅ tray-icon.png - черный текст на прозрачном фоне")
    print("   ✅ tray-icon-mono.png - черный текст для светлых тем")
    print("   ✅ tray-icon-dark.png - белый текст для темных тем")
    
    # Проверяем размеры файлов
    files_to_check = ["tray-icon.png", "tray-icon-dark.png", "tray-icon-mono.png"]
    print("\n📊 Размеры файлов:")
    for filename in files_to_check:
        filepath = f"iconset-work/{filename}"
        if os.path.exists(filepath):
            size = os.path.getsize(filepath)
            print(f"   ✅ {filename}: {size} байт")
    
    print("\n✨ Особенности текстовых иконок:")
    print("   ✅ Простые и читаемые")
    print("   ✅ Высокий контраст")
    print("   ✅ Компактные размеры")
    print("   ✅ Автоматическое центрирование текста")
    
    return True

if __name__ == "__main__":
    try:
        success = create_text_tray_icons()
        if success:
            print("\n✅ Текстовые иконки 'I2P' созданы успешно!")
            print("🚀 Пересоберите приложение для тестирования!")
        else:
            print("\n❌ Не удалось создать текстовые иконки")
            exit(1)
    except Exception as e:
        print(f"\n❌ Ошибка создания текстовых иконок: {e}")
        exit(1)
