#!/usr/bin/env python3
"""
Создание только Retina иконок трея (без обычных версий)
Современные macOS дисплеи все Retina, обычные версии больше не нужны
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_retina_only_tray_icons():
    """Создает только Retina версии @2x иконок для системного трея"""
    
    print("📱 Создание только Retina иконок для современных macOS дисплеев...")
    print("💡 Обычные версии больше не нужны - все современные дисплеи Retina!")
    
    # Размеры только для Retina дисплеев  
    # macOS автоматически масштабирует их до нужного размера трея
    retina_sizes = [18, 20, 22]  # Размеры трея в пикселях для Retina
    
    for retina_size in retina_sizes:
        print(f"\n📱 Создание Retina иконки {retina_size}x{retina_size}...")
        
        # Создаем изображение
        img = Image.new('RGBA', (retina_size, retina_size), (0, 0, 0, 0))  # Прозрачный фон
        draw = ImageDraw.Draw(img)
        
        # Улучшенное качество для Retina дисплеев
        smoothing_factor = 4
        quality_factor = 2
        
        # Пытаемся использовать системный шрифт повышенного качества
        try:
            font_size = max(14, (retina_size - 2) * quality_factor)  # Больший шрифт для Retina
            
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
        
        # Текст "I2P"
        text = "I2P"
        
        # Получаем размеры текста
        try:
            bbox = draw.textbbox((0, 0), text, font=font)
            text_width = bbox[2] - bbox[0]
            text_height = bbox[3] - bbox[1]
        except:
            # Fallback размеры для Retina
            text_width = len(text) * (retina_size // 2)
            text_height = retina_size // 2
        
        # Центрируем текст для Retina дисплея
        x = (retina_size - text_width) // 2
        y = (retina_size - text_height) // 2 - 1
        
        # Для Retina добавляем превосходное качество текста
        # Черный текст для светлых тем
        draw.text((x, y), text, fill=(0, 0, 0, 255), font=font)
        # Добавляем легкую тень для четкости на Retina
        shadow_color = (255, 255, 255, 32)
        draw.text((x + 1, y + 1), text, fill=shadow_color, font=font)
        
        # Сохраняем с @2x суффиксом для Retina распознавания
        if retina_size == 18:  # Основной размер для трея
            img.save("iconset-work/tray-icon@2x.png", "PNG")
            print(f"   ✅ Retina иконка {retina_size}x{retina_size} (@2x)")
        
        # Создаем инвертированную версию для темной темы
        img_inv = Image.new('RGBA', (retina_size, retina_size), (0, 0, 0, 0))  # Прозрачный фон
        draw_inv = ImageDraw.Draw(img_inv)
        
        # Белый текст для темных тем Retina
        draw_inv.text((x, y), text, fill=(255, 255, 255, 255), font=font)
        # Добавляем легкую тень для темных тем
        shadow_color_inv = (0, 0, 0, 32)
        draw_inv.text((x + 1, y + 1), text, fill=shadow_color_inv, font=font)
        
        if retina_size == 18:
            img_inv.save("iconset-work/tray-icon-dark@2x.png", "PNG")
            print(f"   ✅ Темная Retina иконка {retina_size}x{retina_size} (@2x)")
        
        # Дополнительные размеры только для Retina
        filename = f"iconset-work/tray-icon-{retina_size}x{retina_size}@2x.png"
        img.save(filename, "PNG")
        filename_inv = f"iconset-work/tray-icon-{retina_size}x{retina_size}-dark@2x.png"
        img_inv.save(filename_inv, "PNG")
    
    print("\n✨ Созданы только Retina иконки!")
    print("📁 Файлы для современных macOS дисплеев:")
    print("   📱 tray-icon@2x.png - текст 'I2P' для Retina дисплеев")
    print("   🌙 tray-icon-dark@2x.png - темный текст 'I2P' для Retina дисплеев")
    
    # Проверяем размеры файлов
    retina_files = ["tray-icon@2x.png", "tray-icon-dark@2x.png"]
    print("\n📊 Размеры Retina файлов:")
    for filename in retina_files:
        filepath = f"iconset-work/{filename}"
        if os.path.exists(filepath):
            size = os.path.getsize(filepath)
            print(f"   ✅ {filename}: {size} байт (только Retina)")
    
    print("\n💡 Преимущества только Retina версий:")
    print("   ✅ Минимальный размер бандла приложения") 
    print("   ✅ Максимальное качество на всех современных дисплеях")
    print("   ✅ Автоматическое масштабирование macOS до нужного размера")
    print("   ✅ Поддержка всех современных MacBook и дисплеев Apple")
    
    return True

if __name__ == "__main__":
    try:
        success = create_retina_only_tray_icons()
        if success:
            print("\n✅ Только Retina иконки созданы успешно!")
            print("🚀 Обновите скрипт сборки и пересоберите приложение!")
        else:
            print("\n❌ Не удалось создать Retina иконки")
            exit(1)
    except Exception as e:
        print(f"\n❌ Не удалось создать Retina иконки: {e}")
        exit(1)
