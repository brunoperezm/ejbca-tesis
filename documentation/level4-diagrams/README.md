# PlantUML Dynamic Viewer

This directory contains a dynamic PlantUML viewer that automatically loads `.plantuml` files from the filesystem.

## How to use:

### Option A: Docker (Recommended)
```bash
# From the documentation/ directory
docker-compose up plantuml-viewer
```
Then open: http://localhost:8081/viewer.html

### Option B: Local Development
1. **Start the Python API server:**
```bash
python3 list_diagrams.py
```
This will start a server on port 8001 that serves the diagram content.

2. **Serve the HTML viewer:**
```bash
# In another terminal, serve the HTML file
python3 -m http.server 8000
```

3. **Open in browser:**
Navigate to: http://localhost:8000/viewer.html

## Features:

- ✅ **Automatic file discovery**: Automatically finds all `.plantuml` files in the directory
- ✅ **Dynamic content loading**: Always shows current file content (no hardcoded diagrams)
- ✅ **Modern themes**: Uses Material Design and Cerulean themes with rounded corners
- ✅ **UTF-8 support**: Properly handles accented characters (é, ñ, etc.)
- ✅ **HEX encoding**: Uses simple hex encoding for PlantUML compatibility
- ✅ **Refresh functionality**: Button to reload diagrams without page refresh
- ✅ **Export to PNG**: Download diagrams as PNG files

## Adding new diagrams:

1. Create a new `.plantuml` file in this directory
2. Click "🔄 Refresh Diagrams" in the viewer
3. Your new diagram will appear automatically!

## API Endpoint:

The `list_diagrams.py` server provides:
- `GET /list_diagrams` - Returns JSON with all diagram files and their content

## Docker Configuration:

The `docker-compose.yml` is configured to:
- **Port 8081**: Static file server (viewer.html)  
- **Port 8082**: API server (list_diagrams.py)
- **Auto-start**: Both servers run automatically in the container

The viewer automatically detects whether it's running in Docker or local development and uses the appropriate ports.