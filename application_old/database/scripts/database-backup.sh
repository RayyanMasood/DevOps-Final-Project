#!/bin/bash

# Database Backup Script
# Creates automated backups of MySQL and PostgreSQL databases with rotation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/tunnel-config.env"
BACKUP_DIR="${SCRIPT_DIR}/../backups"
LOG_FILE="/tmp/database-backup.log"

# Backup retention (days)
MYSQL_RETENTION_DAYS=30
POSTGRESQL_RETENTION_DAYS=30
COMPRESSED_RETENTION_DAYS=90

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

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
}

# Initialize backup directory
init_backup_dir() {
    log_info "Initializing backup directory..."
    
    mkdir -p "$BACKUP_DIR"/{mysql,postgresql,compressed}
    
    # Create backup info file
    cat > "$BACKUP_DIR/backup-info.txt" << EOF
DevOps Database Backup Directory
Created: $(date)
Backup Types:
- mysql/: MySQL database dumps
- postgresql/: PostgreSQL database dumps
- compressed/: Compressed archive backups

Retention Policy:
- MySQL dumps: $MYSQL_RETENTION_DAYS days
- PostgreSQL dumps: $POSTGRESQL_RETENTION_DAYS days
- Compressed archives: $COMPRESSED_RETENTION_DAYS days
EOF
    
    log_success "Backup directory initialized: $BACKUP_DIR"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking backup prerequisites..."
    
    # Check if backup directory exists
    if [[ ! -d "$BACKUP_DIR" ]]; then
        init_backup_dir
    fi
    
    # Check database clients
    local mysql_available=false
    local postgresql_available=false
    
    if command -v mysqldump >/dev/null 2>&1; then
        mysql_available=true
        log_success "MySQL client available"
    else
        log_warning "MySQL client (mysqldump) not available"
    fi
    
    if command -v pg_dump >/dev/null 2>&1; then
        postgresql_available=true
        log_success "PostgreSQL client available"
    else
        log_warning "PostgreSQL client (pg_dump) not available"
    fi
    
    # Check compression tools
    if command -v gzip >/dev/null 2>&1; then
        log_success "Compression tool (gzip) available"
    else
        log_warning "Compression tool not available - backups will not be compressed"
    fi
    
    # Check disk space
    local available_space=$(df "$BACKUP_DIR" | tail -1 | awk '{print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    if [[ $available_gb -lt 1 ]]; then
        log_warning "Low disk space available: ${available_gb}GB"
    else
        log_success "Disk space available: ${available_gb}GB"
    fi
    
    if [[ "$mysql_available" == false && "$postgresql_available" == false ]]; then
        log_error "No database clients available for backup"
        exit 1
    fi
}

# Backup MySQL database
backup_mysql() {
    if ! command -v mysqldump >/dev/null 2>&1; then
        log_warning "MySQL backup skipped - mysqldump not available"
        return 1
    fi
    
    if [[ -z "${MYSQL_USER:-}" || -z "${MYSQL_PASSWORD:-}" ]]; then
        log_warning "MySQL backup skipped - credentials not configured"
        return 1
    fi
    
    log_info "Starting MySQL backup..."
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/mysql/mysql_backup_${timestamp}.sql"
    local compressed_file="${backup_file}.gz"
    
    # Create backup
    local mysql_args=(
        -h localhost
        -P "${LOCAL_MYSQL_PORT:-3307}"
        -u "$MYSQL_USER"
        -p"$MYSQL_PASSWORD"
        --single-transaction
        --routines
        --triggers
        --events
        --all-databases
        --add-drop-database
        --comments
        --dump-date
    )
    
    if mysqldump "${mysql_args[@]}" > "$backup_file" 2>>"$LOG_FILE"; then
        local backup_size=$(du -h "$backup_file" | awk '{print $1}')
        log_success "MySQL backup created: $(basename "$backup_file") ($backup_size)"
        
        # Compress backup
        if command -v gzip >/dev/null 2>&1; then
            if gzip "$backup_file"; then
                local compressed_size=$(du -h "$compressed_file" | awk '{print $1}')
                log_success "MySQL backup compressed: $(basename "$compressed_file") ($compressed_size)"
            else
                log_warning "Failed to compress MySQL backup"
            fi
        fi
        
        # Verify backup
        if verify_mysql_backup "$compressed_file"; then
            log_success "MySQL backup verification passed"
        else
            log_warning "MySQL backup verification failed"
        fi
        
        return 0
    else
        log_error "MySQL backup failed"
        rm -f "$backup_file"
        return 1
    fi
}

# Backup PostgreSQL database
backup_postgresql() {
    if ! command -v pg_dump >/dev/null 2>&1; then
        log_warning "PostgreSQL backup skipped - pg_dump not available"
        return 1
    fi
    
    if [[ -z "${POSTGRESQL_USER:-}" || -z "${POSTGRESQL_PASSWORD:-}" ]]; then
        log_warning "PostgreSQL backup skipped - credentials not configured"
        return 1
    fi
    
    log_info "Starting PostgreSQL backup..."
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/postgresql/postgresql_backup_${timestamp}.sql"
    local compressed_file="${backup_file}.gz"
    
    # Set PostgreSQL password
    export PGPASSWORD="$POSTGRESQL_PASSWORD"
    
    # Create backup
    local pg_dump_args=(
        -h localhost
        -p "${LOCAL_POSTGRESQL_PORT:-5433}"
        -U "$POSTGRESQL_USER"
        -d "${POSTGRESQL_DATABASE:-devops_analytics}"
        --verbose
        --clean
        --create
        --if-exists
        --no-owner
        --no-privileges
    )
    
    if pg_dump "${pg_dump_args[@]}" > "$backup_file" 2>>"$LOG_FILE"; then
        local backup_size=$(du -h "$backup_file" | awk '{print $1}')
        log_success "PostgreSQL backup created: $(basename "$backup_file") ($backup_size)"
        
        # Compress backup
        if command -v gzip >/dev/null 2>&1; then
            if gzip "$backup_file"; then
                local compressed_size=$(du -h "$compressed_file" | awk '{print $1}')
                log_success "PostgreSQL backup compressed: $(basename "$compressed_file") ($compressed_size)"
            else
                log_warning "Failed to compress PostgreSQL backup"
            fi
        fi
        
        # Verify backup
        if verify_postgresql_backup "$compressed_file"; then
            log_success "PostgreSQL backup verification passed"
        else
            log_warning "PostgreSQL backup verification failed"
        fi
        
        unset PGPASSWORD
        return 0
    else
        log_error "PostgreSQL backup failed"
        rm -f "$backup_file"
        unset PGPASSWORD
        return 1
    fi
}

# Verify MySQL backup
verify_mysql_backup() {
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
    
    if echo "$first_lines" | grep -q "MySQL dump"; then
        return 0
    else
        return 1
    fi
}

# Verify PostgreSQL backup
verify_postgresql_backup() {
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

# Create compressed archive of all backups
create_archive() {
    log_info "Creating compressed archive..."
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local archive_file="$BACKUP_DIR/compressed/full_backup_${timestamp}.tar.gz"
    
    # Create tar archive of all backup directories
    if tar -czf "$archive_file" -C "$BACKUP_DIR" mysql postgresql 2>>"$LOG_FILE"; then
        local archive_size=$(du -h "$archive_file" | awk '{print $1}')
        log_success "Archive created: $(basename "$archive_file") ($archive_size)"
        
        # Create checksum
        local checksum_file="${archive_file}.md5"
        if command -v md5sum >/dev/null 2>&1; then
            md5sum "$archive_file" > "$checksum_file"
            log_success "Archive checksum created: $(basename "$checksum_file")"
        elif command -v md5 >/dev/null 2>&1; then
            md5 "$archive_file" > "$checksum_file"
            log_success "Archive checksum created: $(basename "$checksum_file")"
        fi
        
        return 0
    else
        log_error "Archive creation failed"
        rm -f "$archive_file"
        return 1
    fi
}

# Clean old backups
cleanup_old_backups() {
    log_info "Cleaning up old backups..."
    
    local cleaned_count=0
    
    # Clean MySQL backups
    if [[ -d "$BACKUP_DIR/mysql" ]]; then
        local mysql_cleaned=$(find "$BACKUP_DIR/mysql" -name "*.sql*" -mtime +$MYSQL_RETENTION_DAYS -exec rm -f {} \; -print | wc -l)
        cleaned_count=$((cleaned_count + mysql_cleaned))
        if [[ $mysql_cleaned -gt 0 ]]; then
            log_info "Cleaned $mysql_cleaned old MySQL backup(s)"
        fi
    fi
    
    # Clean PostgreSQL backups
    if [[ -d "$BACKUP_DIR/postgresql" ]]; then
        local postgresql_cleaned=$(find "$BACKUP_DIR/postgresql" -name "*.sql*" -mtime +$POSTGRESQL_RETENTION_DAYS -exec rm -f {} \; -print | wc -l)
        cleaned_count=$((cleaned_count + postgresql_cleaned))
        if [[ $postgresql_cleaned -gt 0 ]]; then
            log_info "Cleaned $postgresql_cleaned old PostgreSQL backup(s)"
        fi
    fi
    
    # Clean compressed archives
    if [[ -d "$BACKUP_DIR/compressed" ]]; then
        local archive_cleaned=$(find "$BACKUP_DIR/compressed" -name "*.tar.gz*" -mtime +$COMPRESSED_RETENTION_DAYS -exec rm -f {} \; -print | wc -l)
        cleaned_count=$((cleaned_count + archive_cleaned))
        if [[ $archive_cleaned -gt 0 ]]; then
            log_info "Cleaned $archive_cleaned old archive(s)"
        fi
    fi
    
    if [[ $cleaned_count -eq 0 ]]; then
        log_info "No old backups to clean"
    else
        log_success "Cleaned $cleaned_count old backup file(s)"
    fi
}

# List existing backups
list_backups() {
    echo "=== Database Backup Inventory ==="
    echo "Backup Directory: $BACKUP_DIR"
    echo
    
    if [[ -d "$BACKUP_DIR/mysql" ]]; then
        echo "MySQL Backups:"
        find "$BACKUP_DIR/mysql" -name "*.sql*" -printf "%TY-%Tm-%Td %TH:%TM  %10s  %f\n" 2>/dev/null | sort -r || \
        ls -lh "$BACKUP_DIR/mysql"/*.sql* 2>/dev/null | awk '{print $6" "$7" "$8"  "$5"  "$9}' || \
        echo "  No MySQL backups found"
        echo
    fi
    
    if [[ -d "$BACKUP_DIR/postgresql" ]]; then
        echo "PostgreSQL Backups:"
        find "$BACKUP_DIR/postgresql" -name "*.sql*" -printf "%TY-%Tm-%Td %TH:%TM  %10s  %f\n" 2>/dev/null | sort -r || \
        ls -lh "$BACKUP_DIR/postgresql"/*.sql* 2>/dev/null | awk '{print $6" "$7" "$8"  "$5"  "$9}' || \
        echo "  No PostgreSQL backups found"
        echo
    fi
    
    if [[ -d "$BACKUP_DIR/compressed" ]]; then
        echo "Compressed Archives:"
        find "$BACKUP_DIR/compressed" -name "*.tar.gz" -printf "%TY-%Tm-%Td %TH:%TM  %10s  %f\n" 2>/dev/null | sort -r || \
        ls -lh "$BACKUP_DIR/compressed"/*.tar.gz 2>/dev/null | awk '{print $6" "$7" "$8"  "$5"  "$9}' || \
        echo "  No compressed archives found"
        echo
    fi
    
    # Show disk usage
    echo "Disk Usage:"
    du -sh "$BACKUP_DIR"/* 2>/dev/null || echo "  Unable to calculate disk usage"
    echo
    
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
    echo "Total Backup Size: ${total_size:-Unknown}"
}

# Restore database from backup
restore_database() {
    local database_type="$1"
    local backup_file="$2"
    
    if [[ -z "$database_type" || -z "$backup_file" ]]; then
        log_error "Usage: restore_database [mysql|postgresql] [backup_file]"
        return 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_warning "This will restore the database from backup. Existing data will be replaced!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Restore cancelled"
        return 0
    fi
    
    case "$database_type" in
        mysql)
            restore_mysql "$backup_file"
            ;;
        postgresql)
            restore_postgresql "$backup_file"
            ;;
        *)
            log_error "Unknown database type: $database_type"
            return 1
            ;;
    esac
}

# Restore MySQL from backup
restore_mysql() {
    local backup_file="$1"
    
    log_info "Restoring MySQL from: $(basename "$backup_file")"
    
    if [[ "$backup_file" == *.gz ]]; then
        zcat "$backup_file" | mysql -h localhost -P "${LOCAL_MYSQL_PORT:-3307}" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD"
    else
        mysql -h localhost -P "${LOCAL_MYSQL_PORT:-3307}" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" < "$backup_file"
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "MySQL restore completed"
    else
        log_error "MySQL restore failed"
        return 1
    fi
}

# Restore PostgreSQL from backup
restore_postgresql() {
    local backup_file="$1"
    
    log_info "Restoring PostgreSQL from: $(basename "$backup_file")"
    
    export PGPASSWORD="$POSTGRESQL_PASSWORD"
    
    if [[ "$backup_file" == *.gz ]]; then
        zcat "$backup_file" | psql -h localhost -p "${LOCAL_POSTGRESQL_PORT:-5433}" -U "$POSTGRESQL_USER" -d "${POSTGRESQL_DATABASE:-devops_analytics}"
    else
        psql -h localhost -p "${LOCAL_POSTGRESQL_PORT:-5433}" -U "$POSTGRESQL_USER" -d "${POSTGRESQL_DATABASE:-devops_analytics}" < "$backup_file"
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "PostgreSQL restore completed"
    else
        log_error "PostgreSQL restore failed"
        unset PGPASSWORD
        return 1
    fi
    
    unset PGPASSWORD
}

# Run full backup
run_full_backup() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_info "Starting full database backup at $timestamp"
    
    local mysql_result=0
    local postgresql_result=0
    local archive_result=0
    
    # Backup MySQL
    backup_mysql || mysql_result=$?
    
    # Backup PostgreSQL
    backup_postgresql || postgresql_result=$?
    
    # Create archive if any backup succeeded
    if [[ $mysql_result -eq 0 || $postgresql_result -eq 0 ]]; then
        create_archive || archive_result=$?
    fi
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Report results
    echo
    echo "=== Backup Summary ==="
    echo "MySQL backup: $([[ $mysql_result -eq 0 ]] && echo "SUCCESS" || echo "FAILED")"
    echo "PostgreSQL backup: $([[ $postgresql_result -eq 0 ]] && echo "SUCCESS" || echo "FAILED")"
    echo "Archive creation: $([[ $archive_result -eq 0 ]] && echo "SUCCESS" || echo "FAILED")"
    echo "Completed at: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Return overall result
    if [[ $mysql_result -eq 0 && $postgresql_result -eq 0 && $archive_result -eq 0 ]]; then
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
    echo "  mysql               Backup MySQL only"
    echo "  postgresql          Backup PostgreSQL only"
    echo "  archive             Create compressed archive"
    echo "  list                List existing backups"
    echo "  cleanup             Clean old backups"
    echo "  restore TYPE FILE   Restore database from backup"
    echo "  help                Show this help message"
    echo
    echo "Examples:"
    echo "  $0                              # Run full backup"
    echo "  $0 mysql                        # Backup MySQL only"
    echo "  $0 list                         # List all backups"
    echo "  $0 restore mysql backup.sql.gz  # Restore MySQL"
    echo "  $0 cleanup                      # Clean old backups"
}

# Main function
main() {
    local command="${1:-full}"
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    # Load configuration
    load_config
    
    # Check prerequisites
    check_prerequisites
    
    case "$command" in
        full)
            run_full_backup
            ;;
        mysql)
            backup_mysql
            ;;
        postgresql)
            backup_postgresql
            ;;
        archive)
            create_archive
            ;;
        list)
            list_backups
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        restore)
            restore_database "$2" "$3"
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
