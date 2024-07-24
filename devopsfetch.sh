#!/bin/bash

# Log file
LOG_FILE="/var/log/devopsfetch.log"

# Ensure the log file exists and is writable
touch $LOG_FILE
chmod 644 $LOG_FILE

# Function to display active ports and services
function display_ports() {
    echo "Listing all active ports and services..." | tee -a $LOG_FILE
    printf "%-10s %-25s %-25s\n" "Proto" "Local Address" "Foreign Address" | tee -a $LOG_FILE
    ss -tuln | awk 'NR==1 || /LISTEN/ {printf "%-10s %-25s %-25s\n", $1, $5, $6}' | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE

    echo "Detailed port usage with services:" | tee -a $LOG_FILE
    for port in $(ss -tuln | awk '/LISTEN/ {print $5}' | awk -F: '{print $2}' | sort -u); do
        echo "Port: $port" | tee -a $LOG_FILE
        lsof -i :$port | tee -a $LOG_FILE
        echo "" | tee -a $LOG_FILE
    done
}

# Function to display Docker images and containers
function display_docker() {
    echo "Listing all Docker images and containers..." | tee -a $LOG_FILE
    
    echo "Docker Images:" | tee -a $LOG_FILE
    printf "%-20s %-20s %-20s %-20s\n" "REPOSITORY" "TAG" "IMAGE ID" "CREATED" "SIZE" | tee -a $LOG_FILE
    sudo docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE

    echo "Docker Containers:" | tee -a $LOG_FILE
    printf "%-20s %-20s %-20s %-20s %-20s\n" "CONTAINER ID" "IMAGE" "COMMAND" "CREATED" "STATUS" "PORTS" "NAMES" | tee -a $LOG_FILE
    sudo docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Command}}\t{{.RunningFor}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}" | tee -a $LOG_FILE
}

# Function to display Nginx domains and their ports
function display_nginx() {
    echo "Listing all Nginx domains and their ports..." | tee -a $LOG_FILE
    sudo nginx -T | awk '
        /server_name/ {
            server_name = $2;
        }
        /listen/ {
            listen_port = $2;
            if (server_name && listen_port) {
                printf "%-20s %-20s\n", server_name, listen_port;
                server_name = "";
                listen_port = "";
            }
        }
    ' | tee -a $LOG_FILE
}

# Function to display Nginx domain configurations
function display_nginx_domain() {
    local domain=$1
    echo "Displaying detailed configuration for domain $domain..." | tee -a $LOG_FILE
    sudo nginx -T | awk '/server_name '"$domain"'/{flag=1;next}/}/{flag=0}flag' | tee -a $LOG_FILE
}

# Function to list all users and their last login times
function display_users() {
    echo "Listing all users and their last login times..." | tee -a $LOG_FILE
    printf "%-15s %-20s %-20s %-15s\n" "USER" "TTY" "FROM" "LOGIN@"
    who -u | awk '{printf "%-15s %-20s %-20s %-15s\n", $1, $2, $5, $3}' | tee -a $LOG_FILE
}

# Function to display activities within a specified time range
function display_time_range() {
    local start_time=$1
    local end_time=$2
    echo "Listing activities from $start_time to $end_time..." | tee -a $LOG_FILE
    sudo journalctl --since "$start_time" --until "$end_time" | tee -a $LOG_FILE
}

# Parse command-line arguments and execute corresponding functions
while true; do
    case "$1" in
        -p|--port)
            if [ -z "$2" ]; then
                display_ports
            else
                echo "Displaying detailed information for port $2..." | tee -a $LOG_FILE
                sudo lsof -i :$2 | tee -a $LOG_FILE
            fi
            ;;
        -d|--docker)
            if [ -z "$2" ]; then
                display_docker
            else
                echo "Displaying detailed information for container $2..." | tee -a $LOG_FILE
                sudo docker inspect $2 | tee -a $LOG_FILE
            fi
            ;;
        -n|--nginx)
            if [ -z "$2" ]; then
                display_nginx
            else
                display_nginx_domain "$2"
            fi
            ;;
        -u|--users)
            if [ -z "$2" ]; then
                display_users
            else
                echo "Displaying detailed information for user $2..." | tee -a $LOG_FILE
                last $2 | tee -a $LOG_FILE
            fi
            ;;
        -t|--time)
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo "Please provide both start and end times." | tee -a $LOG_FILE
            else
                display_time_range "$2" "$3"
            fi
            ;;
        *)
            echo "Usage: $0 [option] [argument]" | tee -a $LOG_FILE
            echo "Options:" | tee -a $LOG_FILE
            echo "  -p, --port           Display all active ports and services or specific port details" | tee -a $LOG_FILE
            echo "  -d, --docker         List all Docker images and containers or specific container details" | tee -a $LOG_FILE
            echo "  -n, --nginx          Display all Nginx domains and their ports or specific domain details" | tee -a $LOG_FILE
            echo "  -u, --users          List all users and their last login times or specific user details" | tee -a $LOG_FILE
            echo "  -t, --time           Display activities within a specified time range" | tee -a $LOG_FILE
            echo "  -h, --help           Show help" | tee -a $LOG_FILE
            ;;
    esac
    sleep 60  # Wait for 60 seconds before the next iteration
done

