#!/usr/bin/env python3
"""
PandaPlay App Icon Generator

This script generates app icons in multiple sizes from the SVG source file.
Requires: cairosvg (pip install cairosvg) or ImageMagick

Usage:
    python generate_icons.py
"""

import os
import subprocess
import sys

# Icon sizes for iOS and tvOS
IOS_SIZES = [1024, 180, 167, 152, 120, 87, 80, 76, 60, 58, 40, 29, 20]
TVOS_SIZES = [1280, 768, 464, 400, 232]

def check_dependencies():
    """Check if required dependencies are installed."""
    # Try cairosvg first
    try:
        import cairosvg
        return 'cairosvg'
    except ImportError:
        pass

    # Try ImageMagick
    try:
        result = subprocess.run(['convert', '-version'],
                              capture_output=True,
                              text=True)
        if result.returncode == 0:
            return 'imagemagick'
    except FileNotFoundError:
        pass

    return None

def generate_with_cairosvg(svg_file, output_dir):
    """Generate icons using cairosvg."""
    try:
        import cairosvg
    except ImportError:
        print("Error: cairosvg not found. Install with: pip install cairosvg")
        return False

    all_sizes = IOS_SIZES + TVOS_SIZES

    for size in all_sizes:
        output_file = os.path.join(output_dir, f'AppIcon-{size}x{size}.png')
        print(f"Generating {output_file}...")

        try:
            cairosvg.svg2png(
                url=svg_file,
                write_to=output_file,
                output_width=size,
                output_height=size
            )
        except Exception as e:
            print(f"  Error generating {size}x{size}: {e}")
            return False

    return True

def generate_with_imagemagick(svg_file, output_dir):
    """Generate icons using ImageMagick."""
    all_sizes = IOS_SIZES + TVOS_SIZES

    for size in all_sizes:
        output_file = os.path.join(output_dir, f'AppIcon-{size}x{size}.png')
        print(f"Generating {output_file}...")

        try:
            subprocess.run([
                'convert',
                '-background', 'none',
                '-resize', f'{size}x{size}',
                svg_file,
                output_file
            ], check=True, capture_output=True)
        except subprocess.CalledProcessError as e:
            print(f"  Error generating {size}x{size}: {e}")
            return False
        except FileNotFoundError:
            print("Error: ImageMagick not found. Install with: brew install imagemagick")
            return False

    return True

def main():
    """Main function."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    svg_file = os.path.join(script_dir, 'AppIcon.svg')
    output_dir = os.path.join(script_dir, 'GeneratedIcons')

    # Check if SVG file exists
    if not os.path.exists(svg_file):
        print(f"Error: {svg_file} not found!")
        sys.exit(1)

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Check dependencies
    print("Checking dependencies...")
    backend = check_dependencies()

    if not backend:
        print("\nError: No suitable image conversion tool found.")
        print("Please install one of the following:")
        print("  - cairosvg: pip install cairosvg")
        print("  - ImageMagick: brew install imagemagick")
        sys.exit(1)

    print(f"Using {backend} for image conversion...\n")

    # Generate icons
    if backend == 'cairosvg':
        success = generate_with_cairosvg(svg_file, output_dir)
    else:
        success = generate_with_imagemagick(svg_file, output_dir)

    if success:
        print(f"\n✓ Icons generated successfully in {output_dir}")
        print("\nNext steps:")
        print("1. Open Xcode")
        print("2. Navigate to Assets.xcassets > AppIcon")
        print("3. Drag the generated icons to the corresponding slots")
    else:
        print("\n✗ Failed to generate icons")
        sys.exit(1)

if __name__ == '__main__':
    main()
