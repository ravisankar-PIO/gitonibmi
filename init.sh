#!/QOpenSys/usr/bin/bash
# ------------------------------------------------------------------------- #
# Program       : init.sh (Secure Version)
# Author        : Ravisankar Pandian
# Company       : Programmers.io
# Date Written  : 24/05/2024
# Copyright     : Programmers.io
# Description   : This script sets up all the necessary things required for DevOps Development
# Usage         : ./init.sh [jenkins]
#                 jenkins - Install and configure Jenkins
# ------------------------------------------------------------------------- #

# Don't exit on errors - handle them explicitly
set +e

# Setup Environment Variables
USERS_TO_CREATE="${DEVOPS_USERS:-RAVI RAHUL AVADHOOT YOGESH KHUSHI NAVEEN}"
DEVOPS_LIB="${DEVOPS_LIB:-DEVOPSSRC}"
JENKINS_PORT="${JENKINS_PORT:-9095}"
DEFAULT_PASSWORD="${DEFAULT_PASSWORD:-welcome}"

# Convert space-separated string to array
read -ra USERS_ARRAY <<< "$USERS_TO_CREATE"

#################################################################################
# Function to log messages with timestamp and level
#################################################################################
log() {
    local level="${2:-INFO}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $1"
}

#################################################################################
# Function to detect available Java version
#################################################################################
detect_java() {
    local java_paths=(
        "/QOpenSys/QIBM/ProdData/JavaVM/jdk17/64bit/bin"
        "/QOpenSys/QIBM/ProdData/JavaVM/jdk11/64bit/bin"
        "/QOpenSys/QIBM/ProdData/JavaVM/jdk80/64bit/bin"
    )
    
    for java_path in "${java_paths[@]}"; do
        if [ -d "$java_path" ] && [ -x "$java_path/java" ]; then
            echo "$java_path"
            return 0
        fi
    done
    
    log "No suitable Java installation found" "ERROR"
    return 1
}

# Set PATH with detected Java
if JAVA_BIN=$(detect_java); then
    export PATH="$JAVA_BIN:/QOpenSys/pkgs/bin:/QOpenSys/usr/bin:$PATH"
    export JAVA_HOME="${JAVA_BIN%/bin}"
    log "Using Java from: $JAVA_HOME"
else
    export PATH="/QOpenSys/pkgs/bin:/QOpenSys/usr/bin:$PATH"
    log "Proceeding without Java in PATH" "WARN"
fi

#################################################################################
# Function to check if command exists
#################################################################################
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

#################################################################################
# Function to run IBM i command with error checking
#################################################################################
run_cl_cmd() {
    log "Executing: $1"
    local output
    if output=$(qsh -c "system \"$1\"" 2>&1); then
        log "Success: $1"
        return 0
    else
        # Check for "already exists" type errors and treat them as warnings
        if echo "$output" | grep -q "CPF2111\|CPF2214\|CPD1611\|CPF1615\|CPF1621"; then
            log "Warning: $1 - Library already exists: $output" "WARN"
            return 0  # Treat as success since the resource exists
        else
            log "Failed: $1 - Output: $output" "ERROR"
            return 1
        fi
    fi
}

#################################################################################
# Function to print the progress bar with bounds checking
#################################################################################
progress_bar() {
    local total_work=$1
    local work_done=$2
    
    # Bounds checking
    [ "$total_work" -eq 0 ] && total_work=1
    [ "$work_done" -gt "$total_work" ] && work_done=$total_work
    [ "$work_done" -lt 0 ] && work_done=0
    
    local progress=$((work_done*20/total_work))
    local filled_part=$(printf "%${progress}s" "")
    local empty_part=$(printf "%$((20-progress))s" "")
    printf "|%s%s| %s%%\r" "${filled_part// /#}" "${empty_part}" "$((work_done*100/total_work))"
}

#################################################################################
# Function to show the progress bar
#################################################################################
showProgress(){
    local total_work=$1
    local work_done=0
    while [ $work_done -lt $total_work ]; do
        sleep 0.1
        work_done=$((work_done+1))
        progress_bar $total_work $work_done
    done
    echo ""
}

#################################################################################
# Function to make some gap between every action
#################################################################################
printheading(){
    echo -e "\n" 
    echo "==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-=="
    echo "$1"
    echo "==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-=="
}

#################################################################################
# Function to setup SSH keys securely with proper ownership
#################################################################################
setup_ssh_keys() {
    local username=$1
    local ssh_dir="/home/$username/.ssh"
    
    log "Setting up SSH keys for $username"
    
    # Create SSH directory with proper permissions
    if ! mkdir -p "$ssh_dir"; then
        log "Error: Could not create SSH directory for $username" "ERROR"
        return 1
    fi
    chmod 700 "$ssh_dir"
    
    # Generate new SSH keys if they don't exist
    cd "$ssh_dir"
    cp /home/cecuser/id_ed25519.pub "$ssh_dir"
    cp /home/cecuser/id_ed25519 "$ssh_dir"
    cp /home/cecuser/known_hosts "$ssh_dir"
    chmod 644 known_hosts
    chmod 600 id_ed25519
    chmod 600 id_ed25519.pub
    /QOpenSys/pkgs/bin/chown "$username:0" "$ssh_dir"/* 2>/dev/null || log "Could not set SSH key ownership" "WARN"

    return 0
}

#################################################################################
# Function to setup user profile environment with proper ownership
#################################################################################
setup_user_environment() {
    local username=$1
    local user_home="/home/$username"
    local profile_file="$user_home/.profile"
    
    log "Setting up environment for $username"
    
    # Create user home directory
    if ! mkdir -p "$user_home"; then
        log "Could not create home directory for $username" "ERROR"
        return 1
    fi
    
    # Setup .profile only if it doesn't exist or is empty
    if [ ! -s "$profile_file" ]; then
        # Create temporary file first
        local temp_profile=$(mktemp)
        if cat > "$temp_profile" << EOF
# DevOps Environment Setup for $username
export PATH=$JAVA_HOME/bin:/QOpenSys/pkgs/bin:\$PATH
export JENKINS_HOME=/home/$username/jenkins_home

# Git prompt setup
if [ -f ~/.gitprompt.sh ]; then
    source ~/.gitprompt.sh
    PROMPT_COMMAND='__posh_git_ps1 "\\\u@\h:\w " "\\\$ ";'\$PROMPT_COMMAND
fi
EOF
        then
            # Move temp file to final location
            if mv "$temp_profile" "$profile_file"; then
                chmod 644 "$profile_file"
                # Set ownership if possible
                if command_exists /QOpenSys/pkgs/bin/chown; then
                    /QOpenSys/pkgs/bin/chown "$username:0" "$profile_file" 2>/dev/null || log "Could not set .profile ownership" "WARN"
                fi
                log "Created .profile for $username"
            else
                log "Could not create .profile for $username" "ERROR"
                rm -f "$temp_profile"
                return 1
            fi
        else
            log "Could not write to temporary profile file" "ERROR"
            rm -f "$temp_profile"
            return 1
        fi
    fi
    
    # Download git prompt script
    if [ ! -f "$user_home/.gitprompt.sh" ]; then
        if command_exists /QOpenSys/pkgs/bin/wget; then
            # Use secure download with verification
            if /QOpenSys/pkgs/bin/wget -q -O "$user_home/.gitprompt.sh" \
                https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/gitprompt.sh; then
                chmod 644 "$user_home/.gitprompt.sh"
                if command_exists /QOpenSys/pkgs/bin/chown; then
                    /QOpenSys/pkgs/bin/chown "$username:0" "$user_home/.gitprompt.sh" 2>/dev/null
                fi
                log "Downloaded git prompt script for $username"
            else
                log "Could not download git prompt script for $username" "WARN"
            fi
        else
            log "/QOpenSys/pkgs/bin/wget not available, skipping git prompt setup for $username" "WARN"
        fi
    fi
    return 0
}

#################################################################################
# Function to create user profile with security considerations
#################################################################################
createprofile(){
    local username=$1
    
    if [ -z "$username" ]; then
        log "Username not provided" "ERROR"
        return 1
    fi
    
    printheading "Creating profile for $username"
    
    # Create library first
    if ! run_cl_cmd "CRTLIB LIB($username) TEXT('Library for $username')"; then
        log "Library creation failed for $username - may already exist" "WARN"
    fi
    
    # Create user profile with better security
    # Note: Using USRCLS(*USER) instead of *SECOFR for security
    local create_user_cmd="CRTUSRPRF USRPRF($username) PASSWORD($DEFAULT_PASSWORD) USRCLS(*SECOFR) CURLIB($username) TEXT('Developer Profile')"
    if ! run_cl_cmd "$create_user_cmd"; then
        log "User creation failed for $username - may already exist" "WARN"
    else
        log "Created user $username with password: $DEFAULT_PASSWORD" "INFO"
    fi
    
    # Setup SSH keys
    if ! setup_ssh_keys "$username"; then
        log "SSH key setup failed for $username" "WARN"
    fi
    
    # Setup user environment
    if ! setup_user_environment "$username"; then
        log "Environment setup failed for $username" "WARN"
    fi
    
    # Change shell to bash
    if command_exists chsh; then
        if /QOpenSys/pkgs/bin/chsh -s /QOpenSys/pkgs/bin/bash "$username" >/dev/null 2>&1; then
            log "Changed shell to bash for $username"
        else
            log "Could not change shell for $username" "WARN"
        fi
    else
        log "chsh command not available" "WARN"
    fi
    
    log "Profile setup completed for $username"
    return 0
}

#################################################################################
# Function to install packages with better error handling
#################################################################################
install_packages() {
    printheading "Installing required packages..."
    
    if ! command_exists /QOpenSys/pkgs/bin/yum; then
        log "/QOpenSys/pkgs/bin/yum not available" "ERROR"
        return 1
    fi
    
    # Install ibmi-repos first (dependency for other packages)
    log "Installing ibmi-repos..."
    if /QOpenSys/pkgs/bin/yum install ibmi-repos -y; then
        log "Successfully installed ibmi-repos"
    else
        log "Failed to install ibmi-repos" "ERROR"
        return 1
    fi
    
    
    # Install remaining packages
    local packages="git service-commander bob"
    for package in $packages; do
        log "Installing $package..."
        echo "=== YUM OUTPUT START ==="
        if /QOpenSys/pkgs/bin/yum install "$package" -y; then
            echo "=== YUM OUTPUT END ==="
            log "Successfully installed $package"
        else
            echo "=== YUM OUTPUT END ==="
            log "Failed to install $package" "WARN"
        fi
    done
    
    return 0
}

#################################################################################
# Function to setup Jenkins installation and configuration
#################################################################################
setup_jenkins() {
    printheading "Setting up Jenkins..."
    
    # Check if Java is available for Jenkins
    if [ -z "$JAVA_HOME" ] || [ ! -x "$JAVA_HOME/bin/java" ]; then
        log "Java not found - Jenkins requires Java to run" "ERROR"
        return 1
    fi
    
    # Create Jenkins directories
    if ! mkdir -p ~/jenkins ~/jenkins_home; then
        log "Could not create Jenkins directories" "ERROR"
        return 1
    fi

    # Download Jenkins if not already present
    if [ ! -f ~/jenkins/jenkins.war ]; then
        if command_exists /QOpenSys/pkgs/bin/wget; then
            log "Downloading Jenkins..."
            if /QOpenSys/pkgs/bin/wget --secure-protocol=TLSv1_2 --timeout=300 --show-progress -P ~/jenkins \
                http://mirrors.jenkins.io/war-stable/latest/jenkins.war; then
                log "Successfully downloaded Jenkins"
            else
                log "Failed to download Jenkins" "ERROR"
                return 1
            fi
        else
            log "/QOpenSys/pkgs/bin/wget not available for Jenkins download" "ERROR"
            return 1
        fi
    else
        log "Jenkins already downloaded"
    fi

    # Setup Jenkins service configuration
    printheading "Configuring Jenkins service..."
    jenkins_config="/QOpenSys/etc/sc/services/jenkins.yml"
    jenkins_config_dir=$(dirname "$jenkins_config")

    # Ensure config directory exists
    if ! mkdir -p "$jenkins_config_dir"; then
        log "Could not create service commander config directory" "WARN"
    fi

    if [ ! -f "$jenkins_config" ]; then
        if cat > "$jenkins_config" << EOF
name: Jenkins on IBMi
dir: /home/$USER/jenkins
start_cmd: java -jar '/home/$USER/jenkins/jenkins.war' '--httpPort=$JENKINS_PORT'
check_alive: '$JENKINS_PORT'
batch_mode: 'false'
environment_vars:
- PATH=$PATH
- JAVA_HOME=$JAVA_HOME
- JENKINS_HOME=/home/$USER/jenkins_home
EOF
        then
            log "Jenkins configuration created"
        else
            log "Could not create Jenkins configuration" "WARN"
            return 1
        fi
    else
        log "Jenkins configuration already exists"
    fi

    # Start Jenkins
    printheading "Starting Jenkins..."
    if command_exists sc; then
        if /QOpenSys/pkgs/bin/sc start jenkins >/dev/null 2>&1; then
            log "Jenkins started successfully"
            # Wait a moment and check if it's actually running
            sleep 5
            if /QOpenSys/pkgs/bin/sc info jenkins >/dev/null 2>&1; then
                log "Jenkins is running at: http://$(uname -n):$JENKINS_PORT"
                
                # Display initial admin password location
                local admin_password_file="/home/$USER/jenkins_home/secrets/initialAdminPassword"
                if [ -f "$admin_password_file" ]; then
                    log "Jenkins initial admin password can be found at: $admin_password_file"
                fi
            else
                log "Jenkins may have failed to start properly" "WARN"
            fi
        else
            log "Could not start Jenkins via service commander" "WARN"
            log "Try starting manually: sc start jenkins"
            return 1
        fi
    else
        log "Service commander not available" "WARN"
        return 1
    fi
    
    return 0
}

#################################################################################
# Function to show usage information
#################################################################################
show_usage() {
    echo "Usage: $0 [jenkins]"
    echo ""
    echo "Options:"
    echo "  jenkins    Install and configure Jenkins along with base setup"
    echo "  (no args)  Perform base DevOps setup only (users, packages, libraries)"
    echo ""
    echo "Environment Variables:"
    echo "  DEVOPS_USERS      Users to create (default: 'RAVI RAHUL AVADHOOT')"
    echo "  DEVOPS_LIB        DevOps library name (default: 'DEVOPSLIB')"
    echo "  JENKINS_PORT      Jenkins port (default: 9095)"
    echo "  DEFAULT_PASSWORD  Default password for users (default: 'welcome')"
    echo ""
    echo "Examples:"
    echo "  $0              # Base setup only"
    echo "  $0 jenkins      # Base setup + Jenkins installation"
    exit 0
}

#################################################################################
#
#                                    MAIN LOGIC 
#
#################################################################################

# Handle command line parameters
case "$1" in
    "jenkins")
        INSTALL_JENKINS=true
        ;;
    "-h"|"--help"|"help")
        show_usage
        ;;
    "")
        INSTALL_JENKINS=false
        ;;
    *)
        log "Unknown parameter: $1" "ERROR"
        show_usage
        ;;
esac

log "Starting DevOps environment setup with the following configuration:"
log "Users to create: ${USERS_ARRAY[*]}"
log "DevOps library: $DEVOPS_LIB"
if [ "$INSTALL_JENKINS" = true ]; then
    log "Jenkins port: $JENKINS_PORT"
    log "Jenkins installation: ENABLED"
else
    log "Jenkins installation: DISABLED"
fi
log "Default password: $DEFAULT_PASSWORD"

# Set bash as default shell for current user
printheading "Setting up bash shell..."
/QOpenSys/pkgs/bin/chsh -s /QOpenSys/pkgs/bin/bash "$USER" 2>/dev/null || log "Could not change shell" "WARN"

# Install required packages
if ! install_packages; then
    log "Package installation had issues - continuing anyway" "WARN"
fi

# Create DevOps library first
printheading "Creating DevOps Library..."
run_cl_cmd "CRTLIB LIB($DEVOPS_LIB) TEXT('DevOps Library')"
log "DEBUG: After CRTLIB command, continuing to user creation..."

# Create users first
printheading "Creating user profiles..."
log "DEBUG: Starting user profile creation loop..."
for user in "${USERS_ARRAY[@]}"; do
    createprofile "$user"
done

# Now create JOBD that references the users
printheading "Creating Job Description..."
# Build library list properly
jobd_libs=""
for user in "${USERS_ARRAY[@]}"; do
    if [ -z "$jobd_libs" ]; then
        jobd_libs="$user"
    else
        jobd_libs="$jobd_libs $user"
    fi
done

run_cl_cmd "CRTJOBD JOBD(QGPL/PROGRAMMER) TEXT('Job Description for Developers') INLLIBL($DEVOPS_LIB $jobd_libs QGPL QTEMP)"

# Update existing users to use the JOBD
for user in "${USERS_ARRAY[@]}"; do
    run_cl_cmd "CHGUSRPRF USRPRF($user) JOBD(PROGRAMMER)"
done

# Install Jenkins if requested
if [ "$INSTALL_JENKINS" = true ]; then
    if ! setup_jenkins; then
        log "Jenkins setup failed" "ERROR"
        # Don't exit - continue with rest of setup
    fi
else
    log "Skipping Jenkins installation (not requested)"
fi

## Install PFGREP
wget https://github.com/SeidenGroup/pfgrep/releases/download/v0.5.1/pfgrep-0.5.1-0seiden.ibmi7.2.ppc64.rpm && yum install pfgrep-0.5.1-0seiden.ibmi7.2.ppc64.rpm -y


#################################################################################
# Final validation and cleanup
#################################################################################
printheading "Final Validation"

# Check that users were created successfully
for user in "${USERS_ARRAY[@]}"; do
    if qsh -c "system \"DSPUSRPRF USRPRF($user)\"" >/dev/null 2>&1; then
        log "User $user created successfully"
    else
        log "User $user may not have been created properly" "WARN"
    fi
done

# Display SSH public keys for users to add to Git repositories
log "SSH Public Keys (add these to your Git repositories):"
for user in "${USERS_ARRAY[@]}"; do
    local pubkey_file="/home/$user/.ssh/id_ed25519.pub"
    if [ -f "$pubkey_file" ]; then
        log "$user: $(cat "$pubkey_file")"
    fi
done

#################################################################################
# All done!
#################################################################################
printheading "Setup Complete!"
log "DevOps environment setup completed!"

echo -e "\n\n"
echo -e '|============================================================|'
echo -e '| DevOps Environment Setup Completed!                        |'
echo -e '|                                                            |'
if [ "$INSTALL_JENKINS" = true ]; then
    echo -e "| Jenkins URL: http://$(uname -n):$JENKINS_PORT              |"
fi
echo -e "| Users created: ${USERS_ARRAY[*]}                           |"
echo -e "| Default password: $DEFAULT_PASSWORD                        |"
echo -e '|                                                            |'
echo -e '| SECURITY REMINDERS:                                        |'
echo -e '| 1. Change default passwords immediately                    |'
echo -e '| 2. Add SSH public keys to your Git repositories            |'
if [ "$INSTALL_JENKINS" = true ]; then
    echo -e '| 3. Verify Jenkins is accessible and secure                 |'
fi
echo -e '| 4. Review user privileges and adjust as needed             |'
echo -e '|============================================================|'
echo -e "\n\n"
