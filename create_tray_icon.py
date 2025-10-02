#!/usr/bin/env python3
"""
Создание специальной иконки для системного трея
на основе текущей иконки приложения I2P-GUI
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_tray_icon():
    """Создает иконку для трея размером 16x16 пикселей"""
    
    # Создаем изображение 16x16
    size = 16
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Создаем простой дизайн для I2P - луковица TOR/I2P стиля
    # Рисуем луковицу в виде концентрических кругов
    
    center_x, center_y = size // 2, size // 2
    
    # Внешний круг (граница луковицы)
    border_radius = 7
    draw.ellipse([center_x - border_radius, center_y - border_radius, 
                  center_x + border_radius, center_y + border_radius], 
                 fill=(45, 45, 45, 255), outline=None)
    
    # Средний круг (середина луковицы)  
    mid_radius = 4
    draw.ellipse([center_x - mid_radius, center_y - mid_radius,
                  center_x + mid_radius, center_y + mid_radius],
                 fill=(85, 85, 85, 255), outline=None)
    
    # Внутренний круг (ядро луковицы)
    inner_radius = 2
    draw.ellipse([center_x - inner_radius, center_y - inner_radius,
                  center_x + inner_radius, center_y + inner_radius],
                 fill=(125, 125, 125, 255), outline=None)
    
    # Добавляем небольшие точки вокруг для подписей сети
    dot_positions = [
        (4, 4), (12, 4), (4, 12), (12, 12)
    ]
    
    for dot_x, dot_y in dot_positions:
        draw.ellipse([dot_x - 0.5, dot_y - 0.5, dot_x + 0.5, dot_y + 0.5],
                     fill=(65, 65, 65, 255))
    
    # Сохраняем оригинальную версию
    img.save('iconset-work/tray-icon.png', 'PNG')
    
    # Создаем монохромную версию (для светлых тем)
    img_mono = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw_mono = ImageDraw.Draw(img_mono)
    
    # Белые круги на прозрачном фоне
    draw_mono.ellipse([center_x - border_radius, center_y - border_radius,
                       center_x + border_radius, center_y + border_radius],
                      fill=(255, 255, 255, 255))
    draw_mono.ellipse([center_x - mid_radius, center_y - mid_radius,
                       center_x + mid_radius, center_y + mid_radius],
                      fill=(200, 200, 200, 255))
    draw_mono.ellipse([center_x - inner_radius, center_y - inner_radius,
                       center_x + inner_radius, center_y + inner_radius],
                      fill=(150, 150, 150, 255))
    
    for dot_x, dot_y in dot_positions:
        draw_mono.ellipse([dot_x - 0.5, dot_y - 0.5, dot_x + 0.5, dot_y + 0.5],
                          fill=(180, 180, 180, 255))
    
    img_mono.save('iconset-work/tray-icon-mono.png', 'PNG')
    
    # Создаем инвертированную версию (для темных тем)
    img_inv = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw_inv = ImageDraw.Draw(img_inv)
    
    # Темные круги на прозрачном фоне
    draw_inv.ellipse([center_x - border_radius, center_y - border_radius,
                      center_x + border_radius, center_y + border_radius],
                      fill=(200, 200, 200, 255))
    draw_inv.ellipse([center_x - mid_radius, center_y - mid_radius,
                      center_x + mid_radius, center_y + mid_radius],
                      fill=(120, 120, 120, 255))
    draw_inv.ellipse([center_x - inner_radius, center_y - inner_radius,
                      center_x + inner_radius, center_y + inner_radius],
                      fill=(80, 80, 80, 255))
    
    for dot_x, dot_y in dot_positions:
        draw_inv.ellipse([dot_x - 0.5, dot_y - 0.5, dot_x + 0.5, dot_y + 0.5],
                         fill=(140, 140, 140, 255))
    
    img_inv.save('iconset-work/tray-icon-dark.png', 'PNG')
    
    print("✅ Создано 3 варианта иконки для трея:")
    print("   - tray-icon.png (основная)")
    print("   - tray-icon-mono.png (монохромная)")
    print("   - tray-icon-dark.png (темная)")
    
    return True

if __name__ == "__main__":
    try:
        create_tray_icon()
        print("🎉 Иконки для трея созданы успешно!")
    except Exception as e:
        print(f"❌ Ошибка создания иконок: {e}")
