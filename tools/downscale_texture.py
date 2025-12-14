#!/usr/bin/env python3
"""
Minecraft Texture Downscaler
Downscales images using nearest-neighbor interpolation to preserve pixel art crisp edges.
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow is required. Install with: pip install Pillow")
    sys.exit(1)


def downscale_texture(
    input_path: str,
    output_path: str | None = None,
    target_size: int = 16,
    maintain_aspect: bool = False
) -> str:
    """
    Downscale an image using nearest-neighbor interpolation.

    Args:
        input_path: Path to the input image
        output_path: Path for output (default: adds _16x16 suffix)
        target_size: Target size in pixels (default: 16)
        maintain_aspect: If True, maintains aspect ratio; if False, forces square

    Returns:
        Path to the output file
    """
    input_file = Path(input_path)

    if not input_file.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    # Open image
    img = Image.open(input_path)
    original_size = img.size

    # Calculate target dimensions
    if maintain_aspect:
        # Scale based on the larger dimension
        ratio = target_size / max(original_size)
        new_size = (
            max(1, int(original_size[0] * ratio)),
            max(1, int(original_size[1] * ratio))
        )
    else:
        new_size = (target_size, target_size)

    # Downscale using nearest-neighbor (NEAREST) to preserve hard pixel edges
    downscaled = img.resize(new_size, Image.Resampling.NEAREST)

    # Determine output path
    if output_path is None:
        output_file = input_file.parent / f"{input_file.stem}_{target_size}x{target_size}{input_file.suffix}"
    else:
        output_file = Path(output_path)

    # Save with PNG for transparency support
    if output_file.suffix.lower() in ['.png', '.gif']:
        downscaled.save(output_file)
    else:
        # Convert to RGB if saving as JPEG (no alpha channel)
        if downscaled.mode == 'RGBA':
            downscaled = downscaled.convert('RGB')
        downscaled.save(output_file)

    print(f"✓ Downscaled: {original_size[0]}x{original_size[1]} → {new_size[0]}x{new_size[1]}")
    print(f"  Output: {output_file}")

    return str(output_file)


def batch_downscale(
    input_dir: str,
    output_dir: str | None = None,
    target_size: int = 16,
    extensions: tuple = ('.png', '.jpg', '.jpeg', '.gif', '.bmp')
) -> list[str]:
    """
    Batch downscale all images in a directory.

    Args:
        input_dir: Directory containing images
        output_dir: Output directory (default: creates 'downscaled' subdirectory)
        target_size: Target size in pixels
        extensions: File extensions to process

    Returns:
        List of output file paths
    """
    input_path = Path(input_dir)

    if not input_path.is_dir():
        raise NotADirectoryError(f"Not a directory: {input_dir}")

    # Setup output directory
    if output_dir is None:
        out_path = input_path / f"downscaled_{target_size}x{target_size}"
    else:
        out_path = Path(output_dir)

    out_path.mkdir(parents=True, exist_ok=True)

    # Find all image files
    image_files = [f for f in input_path.iterdir()
                   if f.is_file() and f.suffix.lower() in extensions]

    if not image_files:
        print(f"No image files found in {input_dir}")
        return []

    print(f"Processing {len(image_files)} images...")

    outputs = []
    for img_file in image_files:
        output_file = out_path / f"{img_file.stem}{img_file.suffix}"
        try:
            result = downscale_texture(
                str(img_file),
                str(output_file),
                target_size
            )
            outputs.append(result)
        except Exception as e:
            print(f"✗ Error processing {img_file.name}: {e}")

    print(f"\n✓ Processed {len(outputs)}/{len(image_files)} images")
    print(f"  Output directory: {out_path}")

    return outputs


def main():
    parser = argparse.ArgumentParser(
        description="Downscale images using nearest-neighbor interpolation for pixel art",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Downscale single image to 16x16
  python downscale_texture.py image.png

  # Downscale to 32x32
  python downscale_texture.py image.png -s 32

  # Downscale with custom output path
  python downscale_texture.py image.png -o output.png

  # Batch downscale entire directory
  python downscale_texture.py textures/ --batch

  # Batch downscale to 64x64
  python downscale_texture.py textures/ --batch -s 64
        """
    )

    parser.add_argument(
        "input",
        help="Input image file or directory (with --batch)"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output file path (single file) or directory (batch mode)"
    )
    parser.add_argument(
        "-s", "--size",
        type=int,
        default=16,
        help="Target size in pixels (default: 16)"
    )
    parser.add_argument(
        "--batch",
        action="store_true",
        help="Process all images in a directory"
    )
    parser.add_argument(
        "--keep-aspect",
        action="store_true",
        help="Maintain aspect ratio instead of forcing square"
    )

    args = parser.parse_args()

    try:
        if args.batch:
            batch_downscale(
                args.input,
                args.output,
                args.size
            )
        else:
            downscale_texture(
                args.input,
                args.output,
                args.size,
                args.keep_aspect
            )
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
