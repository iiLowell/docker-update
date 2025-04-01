#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display help
show_help() {
    echo -e "${BLUE}Docker Container Update Utility${NC}"
    echo
    echo "Usage:"
    echo "  docker-update [OPTIONS] [CONTAINER_NAME]"
    echo
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -a, --all              Update all running containers"
    echo "  -f, --force            Force update even if image is up to date"
    echo "  -l, --list            List all containers and their current image versions"
    echo "  -d, --dry-run         Show what would be updated without making changes"
    echo "  -s, --skip-backup     Skip creating backup of container configuration"
    echo "  -q, --quiet           Reduce output verbosity"
    echo "  -v, --verbose         Increase output verbosity"
    echo
    echo "Examples:"
    echo "  docker-update nginx                # Update single container"
    echo "  docker-update -a                   # Update all running containers"
    echo "  docker-update -f mysql            # Force update container"
    echo "  docker-update -d wordpress        # Dry run update"
    echo
    echo "The script will:"
    echo "  1. Backup container configuration (unless --skip-backup)"
    echo "  2. Stop the container"
    echo "  3. Pull the latest image"
    echo "  4. Recreate the container with the same configuration"
    echo "  5. Start the container"
}

# Function to backup container configuration
backup_container() {
    local container_name="$1"
    local backup_dir="/tmp/docker-backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/${container_name}_${timestamp}.json"

    mkdir -p "${backup_dir}"
    docker inspect "${container_name}" > "${backup_file}"
    echo "Configuration backed up to: ${backup_file}"
}

# Function to list containers and their images
list_containers() {
    # Print header
    printf "${BLUE}%-20s | %-50s | %-50s | %-15s${NC}\n" "Container Name" "Current Version" "Latest Available" "Status"
    printf "%.120s\n" "==============================================================================================================================================="

    docker ps --format '{{.Names}}' | while read container; do
        # Get current image and tag
        current_image=$(docker inspect --format='{{.Config.Image}}' "${container}")

        # Split image name and tag
        if [[ $current_image == *":"* ]]; then
            image_name=${current_image%:*}
            current_tag=${current_image#*:}
        else
            image_name=$current_image
            current_tag="latest"
        fi

        # Pull latest image silently
        docker pull -q "${image_name}:${current_tag}" >/dev/null 2>&1

        # Get image IDs and details
        current_id=$(docker inspect --format='{{.Id}}' "${container}")
        current_digest=$(docker inspect --format='{{.RepoDigests}}' "${current_image}" 2>/dev/null)
        latest_digest=$(docker inspect --format='{{.RepoDigests}}' "${image_name}:${current_tag}" 2>/dev/null)

        # Get detailed version information
        current_version=$(docker inspect "${container}" --format='{{.Config.Image}} ({{.Id}})')
        latest_version=$(docker inspect "${image_name}:${current_tag}" --format='{{.RepoTags}} ({{.Id}})')

        # Compare and set status
        if [ "$current_digest" == "$latest_digest" ]; then
            status="${GREEN}Up to date${NC}"
        else
            status="${YELLOW}Update available${NC}"
        fi

        # Try to get more detailed version information from labels
        current_detail=$(docker inspect "${container}" --format='{{index .Config.Labels "org.opencontainers.image.version"}}' 2>/dev/null)
        latest_detail=$(docker inspect "${image_name}:${current_tag}" --format='{{index .Config.Labels "org.opencontainers.image.version"}}' 2>/dev/null)

        # If version labels exist, add them to the output
        if [ ! -z "$current_detail" ]; then
            current_version="$current_version ($current_detail)"
        fi
        if [ ! -z "$latest_detail" ]; then
            latest_version="$latest_version ($latest_detail)"
        fi

        # Format and print the row
        printf "%-20s | %-50s | %-50s | %b\n" \
            "${container}" \
            "${current_version:0:50}" \
            "${latest_version:0:50}" \
            "${status}"
    done

    # Print footer with additional information
    echo
    echo -e "${BLUE}Notes:${NC}"
    echo "- Current Version shows the image and tag currently in use by the container"
    echo "- Latest Available shows the most recent version available in the repository"
    echo -e "- Status: ${GREEN}Up to date${NC} or ${YELLOW}Update available${NC}"
    echo "- Version numbers in parentheses are from image metadata (when available)"
}

# Function to update a single container
update_container() {
    local container_name="$1"
    local force="$2"
    local dry_run="$3"
    local skip_backup="$4"
    local quiet="$5"
    local verbose="$6"

    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo -e "${RED}Error: Container '${container_name}' not found${NC}"
        return 1
    fi

    # Get image name
    local image_name=$(docker inspect --format='{{.Config.Image}}' "${container_name}")

    if [ "$quiet" != "true" ]; then
        echo -e "${BLUE}Updating container '${container_name}' using image '${image_name}'${NC}"
    fi

    # Check if update is needed
    if [ "$force" != "true" ]; then
        docker pull -q "${image_name}" >/dev/null 2>&1
        local latest_id=$(docker image inspect "${image_name}" --format '{{.Id}}')
        local running_id=$(docker inspect --format='{{.Image}}' "${container_name}")
        if [ "$latest_id" == "$running_id" ]; then
            echo -e "${GREEN}Container '${container_name}' is already running the latest version${NC}"
            return 0
        fi
    fi

    if [ "$dry_run" == "true" ]; then
        echo "Dry run: Would update ${container_name} using image ${image_name}"
        return 0
    fi

    # Backup configuration
    if [ "$skip_backup" != "true" ]; then
        backup_container "${container_name}"
    fi

    # Stop container
    if [ "$verbose" == "true" ]; then
        echo "Stopping container..."
    fi
    docker stop "${container_name}" >/dev/null 2>&1

    # Pull latest image
    if [ "$verbose" == "true" ]; then
        echo "Pulling latest image..."
        docker pull "${image_name}"
    else
        docker pull -q "${image_name}" >/dev/null 2>&1
    fi

    # Get container configuration
    local container_config=$(docker inspect "${container_name}")
    local ports=$(docker inspect "${container_name}" --format='{{range $p, $conf := .HostConfig.PortBindings}} -p {{(index $conf 0).HostPort}}:{{$p}} {{end}}')
    local volumes=$(docker inspect "${container_name}" --format='{{range .Mounts}}{{if eq .Type "bind"}}-v {{.Source}}:{{.Destination}}{{if .RW}}{{else}}:ro{{end}} {{end}}{{end}}')
    local env_vars=$(docker inspect "${container_name}" --format='{{range .Config.Env}}-e {{.}} {{end}}')
    local network=$(docker inspect "${container_name}" --format='{{range $net, $v := .NetworkSettings.Networks}}--network {{$net}} {{end}}')
    local restart_policy=$(docker inspect "${container_name}" --format='{{.HostConfig.RestartPolicy.Name}}')
    local labels=$(docker inspect "${container_name}" --format='{{range $k, $v := .Config.Labels}}--label {{$k}}={{$v}} {{end}}')

    # Remove old container
    if [ "$verbose" == "true" ]; then
        echo "Removing old container..."
    fi
    docker rm "${container_name}" >/dev/null 2>&1

    # Create and start new container
    if [ "$verbose" == "true" ]; then
        echo "Creating new container..."
    fi

    local create_command="docker create --name ${container_name} \
        ${ports} \
        ${volumes} \
        ${env_vars} \
        ${network} \
        ${labels} \
        --restart=${restart_policy} \
        ${image_name}"

    if [ "$verbose" == "true" ]; then
        echo "Running: ${create_command}"
    fi

    eval "${create_command}" >/dev/null 2>&1
    docker start "${container_name}" >/dev/null 2>&1

    if [ "$quiet" != "true" ]; then
        echo -e "${GREEN}Successfully updated ${container_name}${NC}"
    fi
}

# Main script
FORCE=false
ALL=false
DRY_RUN=false
SKIP_BACKUP=false
QUIET=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--all)
            ALL=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -l|--list)
            list_containers
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            CONTAINER_NAME="$1"
            shift
            ;;
    esac
done

if [ "$ALL" == "true" ]; then
    if [ "$QUIET" != "true" ]; then
        echo -e "${BLUE}Updating all running containers...${NC}"
    fi
    docker ps --format '{{.Names}}' | while read container; do
        update_container "$container" "$FORCE" "$DRY_RUN" "$SKIP_BACKUP" "$QUIET" "$VERBOSE"
    done
elif [ -n "$CONTAINER_NAME" ]; then
    update_container "$CONTAINER_NAME" "$FORCE" "$DRY_RUN" "$SKIP_BACKUP" "$QUIET" "$VERBOSE"
else
    echo -e "${RED}Error: No container specified. Use -h for help.${NC}"
    exit 1
fi
