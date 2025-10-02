#!/usr/bin/env python3
"""
Создание полного набора иконок для Retina дисплеев
Включая @2x версии для высокого разрешения
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_retina_tray_icons():
    """Создает полный набор иконок для обычного и Retina разрешения"""
    
    print("📱 Создание полного набора иконок для Retina дисплеев...")
    
    # Определяем размеры для обычных и Retina дисплеев
    # macOS автоматически выбирает правильную версию
    base_sizes = [16, 18, 20, 22]  # Базовые размеры
    retina_multiplier = 2  # Коэффициент для Retina (@2x)
    
    for base_size in base_sizes:
        print(f"\n🎯 Создание наборов для базового размера {base_size}px:")
        
        # Обычная версия
        print(f"   📱 Обычное разрешение {base_size}x{base_size}")
        create_text_icon(base_size, False)
        
        # Retina версия (@2x)
        retina_size = base_size * retina_multiplier
        print(f"   📱 Retina разрешение {retina_size}x{retina_size} (@2x)")
        create_text_icon(retina_size, True)
    
    print("\n📂 Создаем основной набор с правильными именами:")
    
    # Создаем основную иконку 18x18 для обычного дисплея
    main_icon = create_text_icon(18, False, save_file=False)
    
    # Создаем Retina версию 36x36 (@2x)
    retina_icon = create_text_icon(36, True, save_file=False)
    
    # Сохраняем основной набор с правильными именами
    main_icon.save("iconset-work/tray-icon.png", "PNG")
    main_icon.save("iconset-work/tray-icon-mono.png", "PNG")
    retina_icon.save("iconset-work/tray-icon@2x.png", "PNG")
    retina_icon.save("iconset-work/tray-icon-mono@2x.png", "PNG")
    print("   ✅ Основные файлы: tray-icon.png, tray-icon@2x.png")
    
    # Создаем темную версию
    dark_main = create_text_icon(18, False, save_file=False, white_text=True)
    dark_retina = create_text_icon(36, True, save_file=False, white_text=True)
    
    dark_main.save("iconset-work/tray-icon-dark.png", "PNG")
    dark_retina.save("iconset-work/tray-icon-dark@2x.png", "PNG")
    print("   ✅ Темные файлы: tray-icon-dark.png, tray-icon-dark@2x.png")
    
    # Создаем подробную информацию о файлах
    print("\n📊 Созданные файлы:")
    check_and_report_file("iconset-work/tray-icon.png")
    check_and_report_file("iconset-work/tray-icon@2x.png")
    check_and_report_file("iconset-work/tray-icon-mono.png") 
    check_and_report_file("iconset-work/tray-icon-mono@2x.png")
    check_and_report_file("iconset-work/tray-icon-dark.png")
    check_and_report_file("iconset-work/tray-icon-dark@2x.png")
    
    print("\n✨ Полный набор иконок создан!")
    print("   🖥️  Обычный дисплей: tray-icon.png")
    print("   📱 Retina дисплей: tray-icon@2x.png")
    print("   🔄 Автоматический выбор через macOS")
    
    return True

def create_text_icon(size, is_retina=False, save_file=True, white_text=False):
    """Создает текстовую иконку заданного размера"""
    
    # Создаем изображение
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))  # Прозрачный фон
    draw = ImageDraw.Draw(img)
    
    # Увеличиваем качество для Retina
    smoothing_factor = 4 if is_retina else 2
    quality_factor = 2 if is_retina else 1
    
    # Пытаемся использовать системный шрифт
    try:
        # Для Retina используем более крупный шрифт
        font_size = max(12, (size - 4) * quality_factor)
        
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
        # Fallback размеры
        text_width = len(text) * (size // 3)
        text_height = size // 2
    
    # Центрируем текст с учетом Retina качества
    x = (size - text_width) // 2
    y = (size - text_height) // 2 - (1 if not is_retina else 2)
    
    # Выбираем цвет текста
    text_color = (255, 255, 255, 255) if white_text else (0, 0, 0, 255)
    
    # Для Retina добавляем дополнительное сглаживание
    if is_retina:
        # Рисуем базовый текст
        draw.text((x, y), text, fill=text_color, font=font)
        # Добавляем легкую тень для четкости
        shadow_color = (128, 128, 128, 64) if white_text else (255, 255, 255, 64)
        draw.text((x + 1, y + 1), text, fill=shadow_color, font=font)
    else:
        draw.text((x, y), text, fill=text_color, font=font)
    
    # Сохраняем файл если требуется
    if save_file:
        suffix = "@2x" if is_retina else ""
        color_suffix = "-dark" if white_text else ""
        filename = f"iconset-work/tray-icon{suffix}{color_suffix}.png"
        img.save(filename, "PNG")
    
    return img

def check_and_report_file(filepath):
    """Проверяет существование файла и выводит информацию"""
    if os.path.exists(filepath):
        size = os.path.getsize(filepath)
        filename = os.path.basename(filepath)
        resolution = "Retina" if "@2x" in filename else "обычное"
        color = "белый текст" if "dark" in filename else "черный текст"
        print(f"   ✅ {filename}: {size} байт ({resolution}, {color})")
    else:
        print(f"   ❌ Ошибка: {filepath} не найден")

if __name__ == "__main__":
    try:
        success = create_retina_tray_icons()
        if success:
            print("\n✅ Полный набор Retina иконок создан успешно!")
            print("🚀 Пересоберите приложение для тестирования на Retina дисплеях!")
        else:
            print("\n❌ Не удалось создать Retina иконки")
            exit(1)
    except Exception as e:
        print(f"\n❌ Ошибка создания Retina иконок: {e}")
        exit(1)
