#!/usr/bin/env python3
"""
Создание сбалансированных иконок трея - золотая середина между маленькими и большими
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_balanced_tray_icons():
    """Создает сбалансированные иконки трея оптимального размера"""
    
    print("📱 Создание сбалансированных иконок трея...")
    print("⚖️ Поиск золотой середины между компактностью и читаемостью!")
    
    # Оптимальные размеры - баланс между компактностью и читаемостью
    icon_sizes = [17, 18]  # Компромиссный размер
    
    for icon_size in icon_sizes:
        print(f"\n📱 Создание сбалансированной иконки {icon_size}x{icon_size} пикселей...")
        
        # Создаем изображение
        img = Image.new('RGBA', (icon_size, icon_size), (0, 0, 0, 0))  # Прозрачный фон
        draw = ImageDraw.Draw(img)
        
        # Сбалансированный размер шрифта между маленьким и большим
        balanced_font_sizes = {
            17: 10,  # Компромиссный шрифт для 17px
            18: 11   # Оптимальный шрифт для 18px
        }
        
        font_size = balanced_font_sizes.get(icon_size, 11)
        
        # Используем качественный системный шрифт
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
        
        # Текст "I2P" - оптимального размера
        text = "I2P"
        
        # Получаем размеры текста
        try:
            bbox = draw.textbbox((0, 0), text, font=font)
            text_width = bbox[2] - bbox[0]
            text_height = bbox[3] - bbox[1]
        except:
            # Сбалансированные fallback размеры
            text_width = len(text) * (font_size * 0.7)
            text_height = font_size
        
        # Точное центрирование сбалансированного текста
        x = (icon_size - text_width) // 2
        y = (icon_size - text_height) // 2 - 1
        
        # Четкий черный текст для светлых тем (сбалансированная тень)
        draw.text((x, y), text, fill=(0, 0, 0, 255), font=font)
        
        # Умеренная тень для четкости без увеличения размера
        shadow_color = (255, 255, 255, 12)
        draw.text((x + 1, y + 1), text, fill=shadow_color, font=font)
        
        # Сохраняем основную сбалансированную иконку
        if icon_size == 18:  # Основной размер для трея
            img.save("iconset-work/tray-icon.png", "PNG")
            print(f"   ✅ Сбалансированная иконка {icon_size}x{icon_size}")
        
        # Создаем сбалансированную инвертированную версию для темной темы
        img_inv = Image.new('RGBA', (icon_size, icon_size), (0, 0, 0, 0))  # Прозрачный фон
        draw_inv = ImageDraw.Draw(img_inv)
        
        # Четкий белый текст для темных тем
        draw_inv.text((x, y), text, fill=(255, 255, 255, 255), font=font)
        # Сбалансированная тень для темных тем
        shadow_color_inv = (0, 0, 0, 12)
        draw_inv.text((x + 1, y + 1), text, fill=shadow_color_inv, font=font)
        
        if icon_size == 18:
            img_inv.save("iconset-work/tray-icon-dark.png", "PNG")
            print(f"   ✅ Сбалансированная темная иконка {icon_size}x{icon_size}")
        
        # Дополнительные сбалансированные размеры
        filename = f"iconset-work/tray-icon-{icon_size}x{icon_size}-balanced.png"
        img.save(filename, "PNG")
        filename_inv = f"iconset-work/tray-icon-{icon_size}x{icon_size}-dark-balanced.png"
        img_inv.save(filename_inv, "PNG")
    
    print("\n✨ Созданы сбалансированные иконки!")
    print("📁 Оптимальные файлы для системного трея:")
    print("   📱 tray-icon.png - сбалансированная иконка (читаемая и компактная)")
    print("   🌙 tray-icon-dark.png - сбалансированная темная иконка (читаемая и компактная)")
    
    # Проверяем размеры файлов
    balanced_files = ["tray-icon.png", "tray-icon-dark.png"]
    print("\n📊 Размеры сбалансированных файлов:")
    for filename in balanced_files:
        filepath = f"iconset-work/{filename}"
        if os.path.exists(filepath):
            size = os.path.getsize(filepath)
            print(f"   ✅ {filename}: {size} байт (сбалансированная версия)")
    
    print("\n⚖️ Особенности сбалансированных иконок:")
    print("   ✅ Компромиссный размер шрифта для оптимальной читаемости")
    print("   ✅ Размер между слишком маленьким и слишком большим")
    print("   ✅ Умеренные тени для четкости без засорения")
    print("   ✅ Оптимальное использование пространства трея")
    
    return True

if __name__ == "__main__":
    try:
        success = create_balanced_tray_icons()
        if success:
            print("\n✅ Сбалансированные иконки созданы успешно!")
            print("🚀 Пересоберите приложение для оптимального размера!")
        else:
            print("\n❌ Не удалось создать сбалансированные иконки")
            exit(1)
    except Exception as e:
        print(f"\n❌ Ошибка создания сбалансированных иконок: {e}")
        exit(1)
