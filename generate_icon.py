import math
from PIL import Image, ImageDraw

def create_icon(size):
    # Create a transparent image
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw a background rounded rectangle (Squircle-ish for macOS)
    # macOS icons are usually rounded squares.
    rect_padding = size * 0.1
    rect_bbox = [rect_padding, rect_padding, size - rect_padding, size - rect_padding]
    
    # Draw Dark Grey/Black Background
    draw.rounded_rectangle(rect_bbox, radius=size*0.18, fill=(40, 40, 40, 255))
    
    # Draw Red Circle (Recording indicator style)
    circle_padding = size * 0.25
    circle_bbox = [circle_padding, circle_padding, size - circle_padding, size - circle_padding]
    draw.ellipse(circle_bbox, fill=(255, 59, 48, 255)) # System Red
    
    # Draw a simple "Mic" shape in White
    # Mic body
    mic_w = size * 0.12
    mic_h = size * 0.25
    cx = size / 2
    cy = size / 2
    
    mic_body = [cx - mic_w/2, cy - mic_h/1.5, cx + mic_w/2, cy + mic_h/2.5]
    draw.rounded_rectangle(mic_body, radius=mic_w/2, fill=(255, 255, 255, 255))
    
    # Mic stand/line
    line_w = size * 0.04
    line_h = size * 0.1
    draw.rectangle([cx - line_w/2, cy + mic_h/2.5 + size*0.05, cx + line_w/2, cy + mic_h/2.5 + size*0.05 + line_h], fill=(255, 255, 255, 255))
    
    # Mic base
    base_w = size * 0.15
    draw.rectangle([cx - base_w/2, cy + mic_h/2.5 + size*0.05 + line_h, cx + base_w/2, cy + mic_h/2.5 + size*0.05 + line_h + line_w], fill=(255, 255, 255, 255))
    
    return img

# Generate 1024x1024 icon
icon = create_icon(1024)
icon.save('AppIcon.png')
print("AppIcon.png created")
