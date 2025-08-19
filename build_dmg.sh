#!/bin/bash

# MacPie DMG Builder Script
# This script builds the app and creates a distributable DMG

set -e  # Exit on any error

echo "🚀 Starting MacPie DMG build process..."

# Configuration
APP_NAME="MacPie"
VERSION="1.0.0"
BUILD_CONFIG="Release"
PROJECT_FILE="MacPie.xcodeproj"
SCHEME="MacPie"
OUTPUT_DIR="dist"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode command line tools not found. Please install Xcode first."
    exit 1
fi

# Check if hdiutil is available (for DMG creation)
if ! command -v hdiutil &> /dev/null; then
    print_error "hdiutil not found. This script requires macOS."
    exit 1
fi

# Clean previous builds
print_status "Cleaning previous builds..."
xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME" clean 2>/dev/null || true

# Build the app in Release configuration
print_status "Building $APP_NAME in $BUILD_CONFIG configuration..."
xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME" -configuration "$BUILD_CONFIG" -sdk macosx build

if [ $? -ne 0 ]; then
    print_error "Build failed!"
    exit 1
fi

print_success "Build completed successfully!"

# Use the known build path from Xcode
BUILD_DIR="/Users/apple/Library/Developer/Xcode/DerivedData/MacPie-cdmyfkoybkofpednonatcldhmejv/Build/Products/Release"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    print_error "App not found at expected path: $APP_PATH"
    exit 1
fi

print_success "App built at: $APP_PATH"

# Create output directory
print_status "Creating output directory..."
mkdir -p "$OUTPUT_DIR"

# Create a temporary directory for DMG contents
TEMP_DIR=$(mktemp -d)
print_status "Created temporary directory: $TEMP_DIR"

# Copy app to temp directory
print_status "Copying app to temporary directory..."
cp -R "$APP_PATH" "$TEMP_DIR/"

# Create Applications symlink (standard practice)
print_status "Creating Applications symlink..."
ln -s /Applications "$TEMP_DIR/Applications"

# Create background image (optional - you can customize this)
print_status "Creating DMG background..."
mkdir -p "$TEMP_DIR/.background"

# Create a simple background image using ImageMagick if available, or use a placeholder
if command -v convert &> /dev/null; then
    convert -size 800x600 xc:lightblue -pointsize 24 -gravity center -annotate +0+0 "Drag MacPie to Applications" "$TEMP_DIR/.background/background.png"
else
    print_warning "ImageMagick not found. Using placeholder background."
    # Create a simple text file as placeholder
    echo "MacPie Background" > "$TEMP_DIR/.background/background.txt"
fi

# Create DMG
print_status "Creating DMG file..."
hdiutil create -volname "$APP_NAME" -srcfolder "$TEMP_DIR" -ov -format UDZO "$OUTPUT_DIR/$DMG_NAME"

if [ $? -eq 0 ]; then
    print_success "DMG created successfully: $OUTPUT_DIR/$DMG_NAME"
    
    # Get file size
    FILE_SIZE=$(du -h "$OUTPUT_DIR/$DMG_NAME" | cut -f1)
    print_success "DMG size: $FILE_SIZE"
    
    # Show DMG info
    print_status "DMG information:"
    hdiutil info "$OUTPUT_DIR/$DMG_NAME" 2>/dev/null | grep -E "(image-path|format|size|capacity)" || print_warning "Could not display DMG info"
    
else
    print_error "Failed to create DMG!"
    exit 1
fi

# Clean up temporary directory
print_status "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

print_success "🎉 DMG build process completed!"
print_status "Your DMG is ready at: $OUTPUT_DIR/$DMG_NAME"
print_status "You can now distribute this DMG file to users."

# Optional: Open the output directory
read -p "Would you like to open the output directory? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$OUTPUT_DIR"
fi
