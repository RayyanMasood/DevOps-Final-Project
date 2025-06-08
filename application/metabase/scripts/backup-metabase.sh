#!/bin/bash

# Metabase Backup Script
# Creates automated backups of Metabase configuration and PostgreSQL database

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METABASE_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${METABASE_DIR}/backups"
LOG_FILE="/tmp/metabase-backup.log"

# Default values
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
POSTGRES_HOST="${POSTGRES_HOST:-metabase-postgres}"
POSTGRES_DB="${POSTGRES_DB:-metabase}"
POSTGRES_USER="${POSTGRES_USER:-metabase_user}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"

# S3 Configuration (optional)
BACKUP_S3_BUCKET="${BACKUP_S3_BUCKET:-}"
BACKUP_S3_REGION="${BACKUP_S3_REGION:-us-west-2}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Initialize backup directory
init_backup_dir() {
    mkdir -p "$BACKUP_DIR"/{database,config,logs,docker-volumes}
    
    # Create backup info file
    cat > "$BACKUP_DIR/backup-info.txt" << EOF
Metabase Backup Directory
Created: $(date)
Backup Types:
- database/: PostgreSQL database dumps
- config/: Configuration files and Docker Compose
- logs/: Application and system logs
- docker-volumes/: Docker volume backups

Retention Policy: $BACKUP_RETENTION_DAYS days
EOF

    log_success "Backup directory initialized: $BACKUP_DIR"
}

# Load environment variables
load_environment() {
    local env_file="$METABASE_DIR/.env"
    
    if [[ -f "$env_file" ]]; then
        set -a
        source "$env_file"
        set +a
        
        # Override with environment values
        POSTGRES_PASSWORD="${METABASE_DB_PASSWORD:-$POSTGRES_PASSWORD}"
        
        log_info "Environment variables loaded"
    else
        log_warning "Environment file not found: $env_file"
    fi
}

# Backup PostgreSQL database
backup_database() {
    log_info "Starting PostgreSQL database backup..."
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/database/metabase_db_${timestamp}.sql"
    local compressed_file="${backup_file}.gz"
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR/database"
    
    # Set PostgreSQL password
    export PGPASSWORD="$POSTGRES_PASSWORD"
    
    # Create database backup
    if docker exec metabase-postgres pg_dump -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" > "$backup_file" 2>>"$LOG_FILE"; then
        local backup_size=$(du -h "$backup_file" | awk '{print $1}')
        log_success "Database backup created: $(basename "$backup_file") ($backup_size)"
        
        # Compress backup
        if gzip "$backup_file"; then
            local compressed_size=$(du -h "$compressed_file" | awk '{print $1}')
            log_success "Database backup compressed: $(basename "$compressed_file") ($compressed_size)"
        else
            log_warning "Failed to compress database backup"
        fi
        
        # Verify backup
        if verify_database_backup "$compressed_file"; then
            log_success "Database backup verification passed"
        else
            log_warning "Database backup verification failed"
        fi
        
    else
        log_error "Database backup failed"
        rm -f "$backup_file"
        unset PGPASSWORD
        return 1
    fi
    
    unset PGPASSWORD
    return 0
}

# Backup configuration files
backup_configuration() {
    log_info "Starting configuration backup..."
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local config_backup="$BACKUP_DIR/config/metabase_config_${timestamp}.tar.gz"
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR/config"
    
    # Create configuration backup
    if tar -czf "$config_backup" -C "$METABASE_DIR" \
        docker-compose.yml \
        .env \
        nginx/ \
        config/ \
        scripts/ \
        2>>"$LOG_FILE"; then
        
        local backup_size=$(du -h "$config_backup" | awk '{print $1}')
        log_success "Configuration backup created: $(basename "$config_backup") ($backup_size)"
        
        # Create checksum
        local checksum_file="${config_backup}.md5"
        if command -v md5sum >/dev/null 2>&1; then
            md5sum "$config_backup" > "$checksum_file"
        elif command -v md5 >/dev/null 2>&1; then
            md5 "$config_backup" > "$checksum_file"
        fi
        
        return 0
    else
        log_error "Configuration backup failed"
        rm -f "$config_backup"
        return 1
    fi
}

# Backup Docker volumes
backup_docker_volumes() {
    log_info "Starting Docker volumes backup..."
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local volumes_backup="$BACKUP_DIR/docker-volumes/metabase_volumes_${timestamp}.tar.gz"
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR/docker-volumes"
    
    # Get Docker volumes
    local volumes=$(docker volume ls --filter name=metabase --format "{{.Name}}")
    
    if [[ -z "$volumes" ]]; then
        log_warning "No Metabase Docker volumes found"
        return 0
    fi
    
    # Create temporary directory for volume backups
    local temp_dir=$(mktemp -d)
    
    # Backup each volume
    for volume in $volumes; do
        log_info "Backing up volume: $volume"
        local volume_dir="$temp_dir/$volume"
        mkdir -p "$volume_dir"
        
        # Use docker run to access volume data
        docker run --rm -v "$volume:/data" -v "$volume_dir:/backup" alpine \
            tar -czf "/backup/data.tar.gz" -C /data . 2>>"$LOG_FILE"
    done
    
    # Create combined volumes backup
    if tar -czf "$volumes_backup" -C "$temp_dir" . 2>>"$LOG_FILE"; then
        local backup_size=$(du -h "$volumes_backup" | awk '{print $1}')
        log_success "Docker volumes backup created: $(basename "$volumes_backup") ($backup_size)"
    else
        log_error "Docker volumes backup failed"
        rm -f "$volumes_backup"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    return 0
}

# Backup application logs
backup_logs() {
    log_info "Starting logs backup..."
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local logs_backup="$BACKUP_DIR/logs/metabase_logs_${timestamp}.tar.gz"
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR/logs"
    
    # Create logs backup
    if tar -czf "$logs_backup" -C "$METABASE_DIR" logs/ 2>>"$LOG_FILE"; then
        local backup_size=$(du -h "$logs_backup" | awk '{print $1}')
        log_success "Logs backup created: $(basename "$logs_backup") ($backup_size)"
        return 0
    else
        log_error "Logs backup failed"
        rm -f "$logs_backup"
        return 1
    fi
}

# Verify database backup
verify_database_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        return 1
    fi
    
    # Check if file is readable and contains expected content
    if [[ "$backup_file" == *.gz ]]; then
        local first_lines=$(zcat "$backup_file" 2>/dev/null | head -10)
    else
        local first_lines=$(head -10 "$backup_file" 2>/dev/null)
    fi
    
    if echo "$first_lines" | grep -q "PostgreSQL database dump"; then
        return 0
    else
        return 1
    fi
}

# Upload to S3 (optional)
upload_to_s3() {
    local backup_file="$1"
    
    if [[ -z "$BACKUP_S3_BUCKET" ]]; then
        log_info "S3 backup not configured, skipping upload"
        return 0
    fi
    
    if ! command -v aws >/dev/null 2>&1; then
        log_warning "AWS CLI not installed, skipping S3 upload"
        return 1
    fi
    
    log_info "Uploading backup to S3: $backup_file"
    
    local s3_key="metabase-backups/$(basename "$backup_file")"
    
    if aws s3 cp "$backup_file" "s3://$BACKUP_S3_BUCKET/$s3_key" --region "$BACKUP_S3_REGION" 2>>"$LOG_FILE"; then
        log_success "Backup uploaded to S3: s3://$BACKUP_S3_BUCKET/$s3_key"
        return 0
    else
        log_error "Failed to upload backup to S3"
        return 1
    fi
}

# Clean old backups
cleanup_old_backups() {
    log_info "Cleaning up old backups..."
    
    local cleaned_count=0
    
    # Clean local backups
    for backup_type in database config logs docker-volumes; do
        if [[ -d "$BACKUP_DIR/$backup_type" ]]; then
            local files_cleaned=$(find "$BACKUP_DIR/$backup_type" -type f -mtime +$BACKUP_RETENTION_DAYS -exec rm -f {} \; -print | wc -l)
            cleaned_count=$((cleaned_count + files_cleaned))
            
            if [[ $files_cleaned -gt 0 ]]; then
                log_info "Cleaned $files_cleaned old $backup_type backup(s)"
            fi
        fi
    done
    
    # Clean S3 backups if configured
    if [[ -n "$BACKUP_S3_BUCKET" ]] && command -v aws >/dev/null 2>&1; then
        local cutoff_date=$(date -d "$BACKUP_RETENTION_DAYS days ago" '+%Y-%m-%d')
        
        aws s3api list-objects-v2 --bucket "$BACKUP_S3_BUCKET" --prefix "metabase-backups/" \
            --query "Contents[?LastModified<'$cutoff_date'].Key" --output text 2>/dev/null | \
        while read -r key; do
            if [[ -n "$key" ]]; then
                aws s3 rm "s3://$BACKUP_S3_BUCKET/$key" 2>>"$LOG_FILE"
                ((cleaned_count++))
            fi
        done
    fi
    
    if [[ $cleaned_count -eq 0 ]]; then
        log_info "No old backups to clean"
    else
        log_success "Cleaned $cleaned_count old backup file(s)"
    fi
}

# List existing backups
list_backups() {
    echo "=== Metabase Backup Inventory ==="
    echo "Backup Directory: $BACKUP_DIR"
    echo
    
    for backup_type in database config logs docker-volumes; do
        if [[ -d "$BACKUP_DIR/$backup_type" ]]; then
            echo "$backup_type Backups:"
            find "$BACKUP_DIR/$backup_type" -type f -printf "%TY-%Tm-%Td %TH:%TM  %10s  %f\n" 2>/dev/null | sort -r || \
            ls -lh "$BACKUP_DIR/$backup_type"/* 2>/dev/null | awk '{print $6" "$7" "$8"  "$5"  "$9}' || \
            echo "  No $backup_type backups found"
            echo
        fi
    done
    
    # Show total backup size
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
    echo "Total Backup Size: ${total_size:-Unknown}"
    
    # Show S3 backups if configured
    if [[ -n "$BACKUP_S3_BUCKET" ]] && command -v aws >/dev/null 2>&1; then
        echo
        echo "S3 Backups:"
        aws s3 ls "s3://$BACKUP_S3_BUCKET/metabase-backups/" --human-readable --summarize 2>/dev/null || \
        echo "  Unable to list S3 backups"
    fi
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    local backup_type="$2"
    
    if [[ -z "$backup_file" || -z "$backup_type" ]]; then
        log_error "Usage: restore_backup [backup_file] [database|config|volumes]"
        return 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_warning "This will restore from backup and may overwrite existing data!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Restore cancelled"
        return 0
    fi
    
    case "$backup_type" in
        database)
            restore_database "$backup_file"
            ;;
        config)
            restore_configuration "$backup_file"
            ;;
        volumes)
            restore_docker_volumes "$backup_file"
            ;;
        *)
            log_error "Unknown backup type: $backup_type"
            return 1
            ;;
    esac
}

# Restore database from backup
restore_database() {
    local backup_file="$1"
    
    log_info "Restoring database from: $(basename "$backup_file")"
    
    export PGPASSWORD="$POSTGRES_PASSWORD"
    
    # Stop Metabase service
    cd "$METABASE_DIR"
    docker-compose stop metabase
    
    # Drop and recreate database
    docker exec metabase-postgres psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS $POSTGRES_DB;"
    docker exec metabase-postgres psql -U "$POSTGRES_USER" -c "CREATE DATABASE $POSTGRES_DB;"
    
    # Restore database
    if [[ "$backup_file" == *.gz ]]; then
        zcat "$backup_file" | docker exec -i metabase-postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
    else
        docker exec -i metabase-postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$backup_file"
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "Database restore completed"
        
        # Restart Metabase
        docker-compose start metabase
        log_info "Metabase service restarted"
    else
        log_error "Database restore failed"
        unset PGPASSWORD
        return 1
    fi
    
    unset PGPASSWORD
}

# Create backup manifest
create_backup_manifest() {
    local manifest_file="$BACKUP_DIR/backup-manifest-$(date '+%Y%m%d_%H%M%S').json"
    
    local database_backups=$(find "$BACKUP_DIR/database" -name "*.sql.gz" 2>/dev/null | wc -l)
    local config_backups=$(find "$BACKUP_DIR/config" -name "*.tar.gz" 2>/dev/null | wc -l)
    local log_backups=$(find "$BACKUP_DIR/logs" -name "*.tar.gz" 2>/dev/null | wc -l)
    local volume_backups=$(find "$BACKUP_DIR/docker-volumes" -name "*.tar.gz" 2>/dev/null | wc -l)
    
    cat > "$manifest_file" << EOF
{
    "backup_manifest": {
        "created_at": "$(date -Iseconds)",
        "backup_directory": "$BACKUP_DIR",
        "retention_days": $BACKUP_RETENTION_DAYS,
        "s3_bucket": "${BACKUP_S3_BUCKET:-null}",
        "backup_counts": {
            "database_backups": $database_backups,
            "config_backups": $config_backups,
            "log_backups": $log_backups,
            "volume_backups": $volume_backups
        },
        "total_backups": $((database_backups + config_backups + log_backups + volume_backups))
    }
}
EOF

    log_success "Backup manifest created: $(basename "$manifest_file")"
}

# Run full backup
run_full_backup() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_info "Starting full Metabase backup at $timestamp"
    
    local database_result=0
    local config_result=0
    local logs_result=0
    local volumes_result=0
    
    # Initialize backup directory
    init_backup_dir
    
    # Run backups
    backup_database || database_result=$?
    backup_configuration || config_result=$?
    backup_logs || logs_result=$?
    backup_docker_volumes || volumes_result=$?
    
    # Upload to S3 if configured
    if [[ -n "$BACKUP_S3_BUCKET" ]]; then
        for backup_file in "$BACKUP_DIR"/*/*$(date '+%Y%m%d')*; do
            if [[ -f "$backup_file" ]]; then
                upload_to_s3 "$backup_file"
            fi
        done
    fi
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Create manifest
    create_backup_manifest
    
    # Report results
    echo
    echo "=== Backup Summary ==="
    echo "Database backup: $([[ $database_result -eq 0 ]] && echo "SUCCESS" || echo "FAILED")"
    echo "Configuration backup: $([[ $config_result -eq 0 ]] && echo "SUCCESS" || echo "FAILED")"
    echo "Logs backup: $([[ $logs_result -eq 0 ]] && echo "SUCCESS" || echo "FAILED")"
    echo "Volumes backup: $([[ $volumes_result -eq 0 ]] && echo "SUCCESS" || echo "FAILED")"
    echo "Completed at: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Return overall result
    if [[ $database_result -eq 0 && $config_result -eq 0 && $logs_result -eq 0 && $volumes_result -eq 0 ]]; then
        log_success "Full backup completed successfully"
        return 0
    else
        log_warning "Backup completed with some failures"
        return 1
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  full                Run full backup (default)"
    echo "  database            Backup database only"
    echo "  config              Backup configuration only"
    echo "  logs                Backup logs only"
    echo "  volumes             Backup Docker volumes only"
    echo "  list                List existing backups"
    echo "  cleanup             Clean old backups"
    echo "  restore FILE TYPE   Restore from backup"
    echo "  help                Show this help message"
    echo
    echo "Examples:"
    echo "  $0                              # Run full backup"
    echo "  $0 database                     # Backup database only"
    echo "  $0 list                         # List all backups"
    echo "  $0 restore backup.sql.gz database  # Restore database"
    echo "  $0 cleanup                      # Clean old backups"
}

# Main function
main() {
    local command="${1:-full}"
    
    # Load environment variables
    load_environment
    
    case "$command" in
        full)
            run_full_backup
            ;;
        database)
            init_backup_dir
            backup_database
            ;;
        config)
            init_backup_dir
            backup_configuration
            ;;
        logs)
            init_backup_dir
            backup_logs
            ;;
        volumes)
            init_backup_dir
            backup_docker_volumes
            ;;
        list)
            list_backups
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        restore)
            restore_backup "$2" "$3"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'log_info "Backup interrupted"; exit 1' INT TERM

# Run main function
main "$@"
