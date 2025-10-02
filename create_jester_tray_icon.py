#!/usr/bin/env python3
"""
Создание оригинальной иконки маски шута для системного трея
"""

from PIL import Image, ImageDraw
import os

def create_jester_tray_icon():
    """Создает оригинальную иконку маски шута размером 16x16 для системного трея"""
    
    print("🃏 Создание оригинальной иконки маски шута для трея...")
    
    # Создаем набор размеров для разных разрешений экрана
    sizes = [16, 32, 64]
    
    for size in sizes:
        print(f"🎨 Создание иконки {size}x{size}...")
        
        # Создаем изображение с прозрачным фоном
        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        # Рассчитываем масштабирование
        scale = size / 16.0
        
        # Создаем маску шута
        center_x, center_y = size // 2, size // 2
        
        # Основная форма маски (овал)
        mask_width = int(12 * scale)
        mask_height = int(14 * scale)
        mask_left = center_x - mask_width // 2
        mask_top = center_y - mask_height // 2 + int(1 * scale)
        mask_right = mask_left + mask_width
        mask_bottom = mask_top + mask_height
        
        # Рисуем основную маску (кремовый цвет)
        mask_color = (255, 230, 200, 255)
        draw.ellipse([mask_left, mask_top, mask_right, mask_bottom], 
                    fill=mask_color, outline=(200, 180, 160, 255))
        
        # Глаза (овальные разрезы)
        eye_width = int(2 * scale)
        eye_height = int(3 * scale)
        eye_offset_y = int(2 * scale)
        eye_offset_x = int(3 * scale)
        
        left_eye_left = center_x - eye_offset_x - eye_width // 2
        left_eye_top = center_y - eye_offset_y
        left_eye_right = left_eye_left + eye_width
        left_eye_bottom = left_eye_top + eye_height
        
        right_eye_left = center_x + eye_offset_x - eye_width // 2
        right_eye_top = center_y - eye_offset_y
        right_eye_right = right_eye_left + eye_width
        right_eye_bottom = right_eye_top + eye_height
        
        # Черные глаза (пустоты маски)
        draw.ellipse([left_eye_left, left_eye_top, left_eye_right, left_eye_bottom], 
                    fill=(0, 0, 0, 255))
        draw.ellipse([right_eye_left, right_eye_top, right_eye_right, right_eye_bottom], 
                    fill=(0, 0, 0, 255))
        
        # Нос (треугольный)
        nose_size = int(1.5 * scale)
        nose_points = [
            (center_x, center_y - int(1 * scale)),
            (center_x - nose_size, center_y + int(1 * scale)),
            (center_x + nose_size, center_y + int(1 * scale))
        ]
        draw.polygon(nose_points, fill=(200, 180, 160, 255))
        
        # Улыбка (кривая)
        smile_width = int(6 * scale)
        smile_height = int(2 * scale)
        smile_top = center_y + int(3 * scale)
        
        draw.arc([
            center_x - smile_width // 2,
            smile_top - smile_height,
            center_x + smile_width // 2,
            smile_top + smile_height
        ], 0, 180, fill=(200, 180, 160, 255), width=max(1, int(1 * scale)))
        
        # Украшения маски - точки
        dot_color = (255, 100, 100, 255)  # Красные точки
        dot_size = max(1, int(1 * scale))
        
        # Точки вокруг глаз
        decoration_points = [
            (left_eye_left - int(3 * scale), left_eye_top - int(1 * scale)),
            (left_eye_right + int(3 * scale), left_eye_top - int(1 * scale)),
            (right_eye_left - int(3 * scale), right_eye_top - int(1 * scale)),
            (right_eye_right + int(3 * scale), right_eye_top - int(1 * scale)),
            (left_eye_left - int(2 * scale), left_eye_bottom + int(2 * scale)),
            (right_eye_right + int(2 * scale), right_eye_bottom + int(2 * scale))
        ]
        
        for point in decoration_points:
            if point[0] >= 0 and point[1] >= 0 and point[0] < size and point[1] < size:
                draw.ellipse([
                    point[0] - dot_size, point[1] - dot_size,
                    point[0] + dot_size, point[1] + dot_size
                ], fill=dot_color)
        
        # Колпак шута (треугольник)
        cap_height = int(6 * scale)
        cap_width = int(8 * scale)
        cap_top = mask_top - cap_height + int(2 * scale)
        
        cap_points = [
            (center_x, cap_top),
            (center_x - cap_width // 2, mask_top),
            (center_x + cap_width // 2, mask_top)
        ]
        draw.polygon(cap_points, fill=(150, 0, 150, 255))  # Фиолетовый
        
        # Колокольчики на колпаке
        bell_color = (255, 255, 100, 255)  # Желтые колокольчики
        bell_size = max(1, int(1 * scale))
        
        bells = [
            (center_x - cap_width // 4, mask_top - int(1 * scale)),
            (center_x + cap_width // 4, mask_top - int(1 * scale))
        ]
        
        for bell in bells:
            draw.ellipse([
                bell[0] - bell_size, bell[1] - bell_size,
                bell[0] + bell_size, bell[1] + bell_size
            ], fill=bell_color)
        
        # Сохраняем в разные варианты
        main_name = f"iconset-work/tray-icon-{size}x{size}.png"
        img.save(main_name, "PNG")
        print(f"   ✅ {main_name}")
        
        # Создаем монохромный вариант (инвертированный для темной темы)
        img_inverted = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw_inv = ImageDraw.Draw(img_inverted)
        
        # Рисуем инвертированную версию
        draw_inv.ellipse([mask_left, mask_top, mask_right, mask_bottom], 
                        fill=(80, 80, 80, 255), outline=(120, 120, 120, 255))
        
        draw_inv.ellipse([left_eye_left, left_eye_top, left_eye_right, left_eye_bottom], 
                        fill=(255, 255, 255, 255))
        draw_inv.ellipse([right_eye_left, right_eye_top, right_eye_right, right_eye_bottom], 
                        fill=(255, 255, 255, 255))
        
        draw_inv.polygon(nose_points, fill=(100, 100, 100, 255))
        
        draw_inv.arc([
            center_x - smile_width // 2,
            smile_top - smile_height,
            center_x + smile_width // 2,
            smile_top + smile_height
        ], 0, 180, fill=(100, 100, 100, 255), width=max(1, int(1 * scale)))
        
        for point in decoration_points:
            if point[0] >= 0 and point[1] >= 0 and point[0] < size and point[1] < size:
                draw_inv.ellipse([
                    point[0] - dot_size, point[1] - dot_size,
                    point[0] + dot_size, point[1] + dot_size
                ], fill=(200, 200, 200, 255))
        
        draw_inv.polygon(cap_points, fill=(100, 50, 100, 255))
        
        for bell in bells:
            draw_inv.ellipse([
                bell[0] - bell_size, bell[1] - bell_size,
                bell[0] + bell_size, bell[1] + bell_size
            ], fill=(150, 150, 150, 255))
        
        inv_name = f"iconset-work/tray-icon-{size}x{size}-inverted.png"
        img_inverted.save(inv_name, "PNG")
        print(f"   ✅ {inv_name}")
    
    # Создаем стандартные имена для совместимости
    main_16 = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    draw_16 = ImageDraw.Draw(main_16)
    
    # Копируем базовую маску 16x16
    main_16.paste(img)
    
    main_16.save("iconset-work/tray-icon.png", "PNG")
    main_16.save("iconset-work/tray-icon-mono.png", "PNG")
    
    # Инвертированная версия для темной темы
    inverted = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    inv_draw = ImageDraw.Draw(inverted)
    inverted.paste(img_inverted)
    
    inverted.save("iconset-work/tray-icon-dark.png", "PNG")
    
    print("\n🎉 Созданы оригинальные иконки маски шута для трея!")
    print("📁 Основные файлы:")
    print("   ✅ tray-icon.png - основная иконка маски шута")
    print("   ✅ tray-icon-mono.png - для светлых тем")
    print("   ✅ tray-icon-dark.png - инвертированная для темных тем")
    print("\n📐 Дополнительные размеры:")
    for size in sizes:
        print(f"   ✅ tray-icon-{size}x{size}.png - основной размер {size}x{size}")
        print(f"   ✅ tray-icon-{size}x{65}x{size}-inverted.png - инвертированный размер {size}x{size}")
    
    return True

if __name__ == "__main__":
    try:
        success = create_jester_tray_icon()
        if success:
            print("\n✅ Оригинальные иконки маски шута созданы успешно!")
            print("🚀 Теперь можно пересобрать приложение с новыми иконками!")
        else:
            print("\n❌ Не удалось создать иконки")
            exit(1)
    except Exception as e:
        print(f"\n❌ Ошибка создания иконок: {e}")
        exit(1)
