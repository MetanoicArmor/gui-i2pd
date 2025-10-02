#!/usr/bin/env python3
"""
Создание красивой иконки трея на основе основной иконки приложения I2P-GUI.icns
"""

from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import os

def create_tray_icon_from_app_icon():
    """Создает красивые иконки трея на основе основной иконки приложения"""
    
    print("🎨 Создание красивой andконки трея на основе иконки приложения I2P-GUI.icns...")
    
    # Загружаем основную иконку
    app_icon_path = "I2P-GUI.icns"
    
    if not os.path.exists(app_icon_path):
        print(f"❌ Иконка приложения не найдена: {app_icon_path}")
        return False
    
    # Извлекаем изображение из .icns файла через sips (macOS utility)
    import subprocess
    temp_path = "temp_icon.png"
    
    try:
        # Используем sips для извлечения PNG из icns
        cmd = ["sips", "-s", "format", "png", app_icon_path, "--out", temp_path]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0 or not os.path.exists(temp_path):
            print("❌ Не удалось извлечь изображение из .icns файла")
            return False
        
        # Загружаем извлеченное изображение
        source_image = Image.open(temp_path)
        print(f"✅ Загружена основная иконка: {source_image.size}")
        
        # Очищаем временный файл
        os.remove(temp_path)
        
    except Exception as e:
        print(f"❌ Ошибка извлечения из .icns: {e}")
        return False
    
    # Конвертируем в RGBA если нужно
    if source_image.mode != 'RGBA':
        source_image = source_image.convert('RGBA')
    
    # Создаем набор иконок трея разных размеров
    tray_sizes = [16, 32, 64]  # Стандартные размеры для трея
    
    created_files = []
    
    for size in tray_sizes:
        print(f"🔧 Создание иконки трея {size}x{size}...")
        
        # Создаем круглую иконку трея
        circular_icon = create_circular_tray_icon(source_image, size)
        
        # Сохраняем в разных стилях для разных ситуаций
        
        # 1. Основная версия (стандартная)
        icon_name = f"tray-icon-{size}x{size}.png"
        circular_icon.save(f"iconset-work/{icon_name}", "PNG")
        created_files.append(icon_name)
        print(f"   ✅ {icon_name}")
        
        # 2. Улучшенная контрастность для лучшей видимости в трее
        enhanced_icon = enhance_for_tray_visibility(circular_icon)
        enhanced_name = f"tray-icon-{size}x{size}-enhanced.png"
        enhanced_icon.save(f"iconset-work/{enhanced_name}", "PNG")
        created_files.append(enhanced_name)
        print(f"   ✅ {enhanced_name}")
        
        # Только для основного размера (16x16) создаем дополнительные вариантыテーマ
        if size == 16:
            # Версия с легким размытием для smoother look
            blurred_icon = circular_icon.filter(ImageFilter.GaussianBlur(radius=0.3))
            blur_name = f"tray-icon-{size}x{size}-smooth.png"
            blurred_icon.save(f"iconset-work/{blur_name}", "PNG")
            created_files.append(blur_name)
            print(f"   ✅ {blur_name}")
    
    # Создаем стандартные имена для совместимости с кодом приложения
    main_icon_16 = create_circular_tray_icon(source_image, 16)
    enhanced_16 = enhance_for_tray_visibility(main_icon_16)
    
    # Стандартные имена для автоматического выбора по темам
    main_icon_16.save("iconset-work/tray-icon.png", "PNG")
    enhanced_16.save("iconset-work/tray-icon-dark.png", "PNG")  # Улучшенная для темной темы
    main_icon_16.save("iconset-work/tray-icon-mono.png", "PNG")   # Обычная для светлой темы
    
    print("\n🎉 Созданы иконки трея на основе основной иконки приложения:")
    print("📁 Основные файлы:")
    print("   ✅ tray-icon.png - основная иконка трея")
    print("   ✅ tray-icon-dark.png - улучшенная для темной темы macOS")  
    print("   ✅ tray-icon-mono.png - обычная для светлой темы macOS")
    
    print("\n📁 Дополнительные варианты:")
    for filename in created_files:
        filepath = f"iconset-work/{filename}"
        if os.path.exists(filepath):
            file_size = os.path.getsize(filepath)
            print(f"   ✅ {filename} ({file_size} байт)")
    
    return True

def create_circular_tray_icon(image, size):
    """Создает круглую иконку для трея из исходного изображения"""
    
    # Создаем изображение нужного размера
    icon = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    
    # Рассчитываем область круга с небольшим отступом для лучшей видимости
    margin = max(1, size // 20)  # Отступ от края
    radius = (size - margin * 2) // 2
    center_x, center_y = size // 2, size // 2
    
    # Изменяем размер исходного изображения под наши нужды
    source_size = min(image.size)
    scale_factor = (size * 0.9) / source_size  # Используем 90% размера для круглого кадрирования
    
    resize_width = int(image.width * scale_factor)
    resize_height = int(image.height * scale_factor)
    
    # Изменяем размер с сохранением пропорций
    resized_image = image.resize((resize_width, resize_height), Image.LANCZOS)
    
    # Создаем маску круглой формы
    mask_size = radius * 2
    mask = Image.new('L', (mask_size, mask_size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse([0, 0, mask_size, mask_size], fill=255)
    
    # Применяем маску к изображению с центрированием
    masked_image = Image.new('RGBA', (mask_size, mask_size), (0, 0, 0, 0))
    offset_x = (mask_size - resize_width) // 2
    offset_y = (mask_size - resize_height) // 2
    masked_image.paste(resized_image, (offset_x, offset_y))
    masked_image.putalpha(mask)
    
    # Размещаем изображение в центре иконки
    x_offset = center_x - radius
    y_offset = center_y - radius
    icon.paste(masked_image, (x_offset, y_offset), masked_image)
    
    # Добавляем тонкую границу для лучшей видимости в системном трее
    border_thickness = max(1, size // 32)
    border_color = (255, 255, 255, 100)  # Полупрозрачная белая граница
    
    # Обводим круг границей
    outer_radius = radius + border_thickness // 2
    draw.arc([center_x - outer_radius, center_y - outer_radius, 
              center_x + outer_radius, center_y + outer_radius], 
             0, 360, fill=border_color, width=border_thickness)
    
    return icon

def enhance_for_tray_visibility(img):
    """Применяет улучшения для лучшей видимости в системном трее"""
    
    # Создаем копию изображения
    enhanced = img.copy()
    
    # Применяем легкое увеличение контрастности
    enhancer = ImageEnhance.Contrast(enhanced)
    enhanced = enhancer.enhance(1.15)  # +15% контрастности
    
    # Легкое увеличение яркости для лучшей видимости
    brightness_enhancer = ImageEnhance.Brightness(enhanced)
    enhanced = brightness_enhancer.enhance(1.05)  # +5% яркости
    
    # Легкое увеличение резкости
    sharpness_enhancer = ImageEnhance.Sharpness(enhanced)
    enhanced = sharpness_enhancer.enhance(1.1)  # +10% резкости
    
    return enhanced

if __name__ == "__main__":
    try:
        success = create_tray_icon_from_app_icon()
        if success:
            print("\n✅ Красивые иконки трея созданы успешно!")
            print("🚀 Теперь можно пересобрать приложение с улучшенными иконками!")
        else:
            print("\n❌ Не удалось создать иконки трея")
            exit(1)
    except Exception as e:
        print(f"\n❌ Ошибка создания иконок: {e}")
        exit(1)
