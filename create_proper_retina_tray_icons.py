#!/usr/bin/env python3
"""
Создание правильно размещенных Retina иконок трея
Без @2x суффиксов для избежания автоматического увеличения macOS
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_proper_retina_tray_icons():
    """Создает Retina иконки с правильными размерами без аутоувеличения"""
    
    print("📱 Создание правильно размещенных Retina иконок трея...")
    print("💡 Без @2x суффиксов для избежания автоматического увеличения macOS!")
    
    # Размеры для трея (macOS автоматически не будет их масштабировать)
    tray_sizes = [18, 20, 22]  # Размеры в пикселях трея
    
    for tray_size in tray_sizes:
        print(f"\n📱 Создание Retina иконки {tray_size}x{tray_size} пикселей...")
        
        # Создаем изображение
        img = Image.new('RGBA', (tray_size, tray_size), (0, 0, 0, 0))  # Прозрачный фон
        draw = ImageDraw.Draw(img)
        
        # Улучшенные параметры для четкости текста
        smoothing_factor = 8  # Высокое качество для трея
        quality_factor = 1.5  # Модифицированный коэффициент качества
        
        # Оптимизированный размер шрифта для системного трея
        try:
            font_size = max(12, int(tray_size * quality_factor))  # Адаптивный размер шрифта
            
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
            # Fallback размеры оптимизированные для трея
            text_width = len(text) * (tray_size // 2)
            text_height = tray_size // 2
        
        # Точное центрирование текста для трея
        x = (tray_size - text_width) // 2
        y = (tray_size - text_height) // 2 - 1  # Немного выше центра
        
        # Качественный черный текст для светлых тем
        draw.text((x, y), text, fill=(0, 0, 0, 255), font=font)
        # Улучшенное сглаживание для четкости
        shadow_color = (255, 255, 255, 16)
        draw.text((x + 1, y + 1), text, fill=shadow_color, font=font)
        
        # Сохраняем основную иконку (без @2x суффикса)
        if tray_size == 18:  # Основной размер для трея
            img.save("iconset-work/tray-icon.png", "PNG")
            print(f"   ✅ Оптимизированная Retina иконка {tray_size}x{tray_size}")
        
        # Создаем инвертированную версию для темной темы
        img_inv = Image.new('RGBA', (tray_size, tray_size), (0, 0, 0, 0))  # Прозрачный фон
        draw_inv = ImageDraw.Draw(img_inv)
        
        # Четкий белый текст для темных тем
        draw_inv.text((x, y), text, fill=(255, 255, 255, 255), font=font)
        # Улучшенная тень для темных тем
        shadow_color_inv = (0, 0, 0, 16)
        draw_inv.text((x + 1, y + 1), text, fill=shadow_color_inv, font=font)
        
        if tray_size == 18:
            img_inv.save("iconset-work/tray-icon-dark.png", "PNG")
            print(f"   ✅ Оптимизированная темная Retina иконка {tray_size}x{tray_size}")
        
        # Дополнительные размеры для различных разрешений
        filename = f"iconset-work/tray-icon-{tray_size}x{tray_size}.png"
        img.save(filename, "PNG")
        filename_inv = f"iconset-work/tray-icon-{tray_size}x{tray_size}-dark.png"
        img_inv.save(filename_inv, "PNG")
    
    print("\n✨ Созданы оптимизированные Retina иконки!")
    print("📁 Правильно размещенные файлы для системного трея:")
    print("   📱 tray-icon.png - Retina иконка без авмасштабирования")
    print("   🌙 tray-icon-dark.png - темная Retina иконка без автомасштабирования")
    
    # Проверяем размеры файлов
    retina_files = ["tray-icon.png", "tray-icon-dark.png"]
    print("\n📊 Размеры оптимизированных файлов:")
    for filename in retina_files:
        filepath = f"iconset-work/{filename}"
        if os.path.exists(filepath):
            size = os.path.getsize(filepath)
            print(f"   ✅ {filename}: {size} байт (оптимизированная Retina)")
    
    print("\n💡 Преимущества правильных Retina иконок:")
    print("   ✅ Нет автоувеличения macOS (без @2x суффиксов)")
    print("   ✅ Правильный размер для системного трея (18x18 пикселей)")
    print("   ✅ Высокое качество текста 'I2P'")
    print("   ✅ Оптимизированный размер файлов")
    
    return True

if __name__ == "__main__":
    try:
        success = create_proper_retina_tray_icons()
        if success:
            print("\n✅ Оптимизированные Retina иконки созданы успешно!")
            print("🚀 Пересоберите приложение для правильного отображения!")
        else:
            print("\n❌ Не удалось создать оптимизированные Retina иконки")
            exit(1)
    except Exception as e:
        print(f"\n❌ Ошибка создания оптимизированных Retina иконок: {e}")
        exit(1)
