# Build script for Python Server EXE
# Bundles the server, assets, and flutter web build

echo "Installing PyInstaller if missing..."
pip install pyinstaller google-auth google-auth-httplib2 google-api-python-client

echo "Building EXEs..."
pyinstaller --noconfirm --onefile --console `
--add-data "assets;assets" `
--add-data "build/web;build/web" `
--name "ServidorPOS" `
servidor.py

echo "Build complete! Check the 'dist' folder."
