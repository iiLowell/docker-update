# Docker Update Utility

A command-line tool for managing Docker container updates efficiently. This utility helps you update Docker containers while preserving their configurations, volumes, and network settings.

## Features

- Update single or multiple containers
- Preserve container configurations during updates
- Automatic backup of container settings
- Show available updates for containers
- Force updates regardless of version
- Dry-run capability
- Detailed or quiet output modes
- Color-coded status information

## Installation

### Prerequisites

- Linux/Unix-based system
- Docker installed and running
- Bash shell
- Root access or sudo privileges

### Quick Install

```bash
# Download the script
sudo curl -o /usr/local/bin/docker-update https://raw.githubusercontent.com/iiLowell/docker-update/refs/heads/main/docker-update.sh

# Make it executable
sudo chmod +x /usr/local/bin/docker-update
```

### Manual Installation

1. Save the script as `docker-update` in `/usr/local/bin/`:
   ```bash
   sudo nano /usr/local/bin/docker-update
   # Paste the script content
   ```

2. Make the script executable:
   ```bash
   sudo chmod +x /usr/local/bin/docker-update
   ```

## Usage

### Basic Commands

```bash
# Update a single container
docker-update container_name

# Update all running containers
docker-update --all

# Show help
docker-update --help

# List containers and their update status
docker-update --list
```

### Options

```
-h, --help              Show help message
-a, --all              Update all running containers
-f, --force            Force update even if image is up to date
-l, --list            List all containers and their current image versions
-d, --dry-run         Show what would be updated without making changes
-s, --skip-backup     Skip creating backup of container configuration
-q, --quiet           Reduce output verbosity
-v, --verbose         Increase output verbosity
```

### Examples

```bash
# Update nginx container
docker-update nginx

# Force update MySQL container
docker-update --force mysql

# List all containers and their versions
docker-update --list

# Dry run update of WordPress container
docker-update --dry-run wordpress

# Update all containers quietly
docker-update --all --quiet

# Update with detailed output
docker-update --verbose nginx

# Update without backup
docker-update --skip-backup nginx
```

## Backup and Recovery

By default, the script creates backups of container configurations before updates in `/tmp/docker-backups/`.

Backup files are named: `container_name_YYYYMMDD_HHMMSS.json`

### Backup Location
```
/tmp/docker-backups/
└── container_name_20240101_123456.json
```

## Output Examples

### List Command Output
```
Container Name      | Current Version                    | Latest Available                   | Status
=====================================================================================
nginx              | nginx:1.21.3 (1.21.3)             | nginx:1.21.4 (1.21.4)            | Update available
mysql              | mysql:8.0 (8.0.27)                | mysql:8.0 (8.0.27)               | Up to date
wordpress          | wordpress:5.8 (5.8.2)             | wordpress:5.8 (5.8.3)            | Update available
```

## Troubleshooting

### Common Issues

1. Permission Denied
   ```bash
   sudo chown root:root /usr/local/bin/docker-update
   sudo chmod 755 /usr/local/bin/docker-update
   ```

2. Docker Socket Access
   ```bash
   # Add your user to the docker group
   sudo usermod -aG docker $USER
   # Log out and back in
   ```

3. Script Not Found
   ```bash
   # Ensure the script is in PATH
   echo $PATH
   # Should include /usr/local/bin
   ```

### Error Messages

- `Error: Container 'name' not found`: Verify container name
- `Error: Failed to pull latest image`: Check internet connection and image name
- `Error: Failed to start new container`: Check container configuration

## Security Considerations

- The script requires Docker daemon access
- Backup files contain sensitive configuration data
- Consider removing old backups periodically
- Review pulled images before updating production containers

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

[iiLowell](https://github.com/iiLowell)
