#!/QOpenSys/usr/bin/bash
# ------------------------------------------------------------------------- #
# Program       : init.sh (Secure Version)
# Author        : Ravisankar Pandian
# Company       : Programmers.io
# Date Written  : 24/05/2024
# Copyright     : Programmers.io
# Description   : This script sets up all the necessary things required for DevOps Development
# Usage         : ./init.sh [jenkins] [bob] [sc]
#                 jenkins - Install and configure Jenkins
#                 bob     - Install Better Object Builder
#                 sc      - Install Service Commander
# ------------------------------------------------------------------------- #

# Don't exit on errors - handle them explicitly
set +e

# Setup Environment Variables
USERS_TO_CREATE="${DEVOPS_USERS:-RAVI RAHUL AVADHOOT YOGESH KHUSHI NAVEEN GAURAV}"
DEVOPS_LIB="${DEVOPS_LIB:-PIODEVOPS}"
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
        # Create temporary file using timestamp for uniqueness
        local temp_profile="$user_home/.profile.tmp.$"
        
        # Build PATH based on what's being installed
        local path_config="export PATH=/QOpenSys/pkgs/bin:\$PATH"
        if [ "$INSTALL_JENKINS" = true ] || [ "$INSTALL_BOB" = true ]; then
            # Only add Java to PATH if Jenkins or BOB is being installed
            if [ -n "$JAVA_HOME" ]; then
                path_config="export PATH=$JAVA_HOME/bin:/QOpenSys/pkgs/bin:\$PATH"
            fi
        fi
        
        if cat > "$temp_profile" << EOF
# DevOps Environment Setup for $username
$path_config
$([ "$INSTALL_JENKINS" = true ] && echo "export JENKINS_HOME=/home/$username/jenkins_home")

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
    local create_user_cmd="CRTUSRPRF USRPRF($username) PASSWORD($DEFAULT_PASSWORD) USRCLS(*SECOFR) CURLIB($username) TEXT($username)"
    if ! run_cl_cmd "$create_user_cmd"; then
        log "User creation failed for $username - may already exist" "WARN"
    else
        log "Created user $username with password: $DEFAULT_PASSWORD" "INFO"
    fi
    
    # Setup SSH keys only for RAVI
    if [ "$username" = "RAVI" ]; then
        if ! setup_ssh_keys "$username"; then
            log "SSH key setup failed for $username" "WARN"
        fi
    else
        log "Skipping SSH key setup for $username (only RAVI gets SSH keys)" "INFO"
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
# Function to install base packages (git and ibmi-repos only)
#################################################################################
install_base_packages() {
    printheading "Installing base packages..."
    
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
    
    # Install git
    log "Installing git..."
    echo "=== YUM OUTPUT START ==="
    if /QOpenSys/pkgs/bin/yum install git -y; then
        echo "=== YUM OUTPUT END ==="
        log "Successfully installed git"
    else
        echo "=== YUM OUTPUT END ==="
        log "Failed to install git" "WARN"
    fi
    
    return 0
}

#################################################################################
# Function to install Service Commander
#################################################################################
install_service_commander() {
    printheading "Installing Service Commander..."
    
    if ! command_exists /QOpenSys/pkgs/bin/yum; then
        log "/QOpenSys/pkgs/bin/yum not available" "ERROR"
        return 1
    fi
    
    log "Installing service-commander..."
    echo "=== YUM OUTPUT START ==="
    if /QOpenSys/pkgs/bin/yum install service-commander -y; then
        echo "=== YUM OUTPUT END ==="
        log "Successfully installed Service Commander"
    else
        echo "=== YUM OUTPUT END ==="
        log "Failed to install Service Commander" "ERROR"
        return 1
    fi
    
    return 0
}

#################################################################################
# Function to install BOB (Better Object Builder)
#################################################################################
install_bob() {
    printheading "Installing Better Object Builder (BOB)..."
    
    if ! command_exists /QOpenSys/pkgs/bin/yum; then
        log "/QOpenSys/pkgs/bin/yum not available" "ERROR"
        return 1
    fi
    
    log "Installing bob (this will also install Java as a dependency)..."
    echo "=== YUM OUTPUT START ==="
    if /QOpenSys/pkgs/bin/yum install bob -y; then
        echo "=== YUM OUTPUT END ==="
        log "Successfully installed BOB"
        
        # Detect Java that was installed as dependency
        if JAVA_BIN=$(detect_java); then
            export PATH="$JAVA_BIN:/QOpenSys/pkgs/bin:/QOpenSys/usr/bin:$PATH"
            export JAVA_HOME="${JAVA_BIN%/bin}"
            log "Java installed as BOB dependency: $JAVA_HOME"
        fi
    else
        echo "=== YUM OUTPUT END ==="
        log "Failed to install BOB" "ERROR"
        return 1
    fi
    
    return 0
}

#################################################################################
# Function to setup Jenkins installation and configuration
#################################################################################
setup_jenkins() {
    printheading "Setting up Jenkins..."
    
    # Detect Java for Jenkins
    if JAVA_BIN=$(detect_java); then
        export PATH="$JAVA_BIN:/QOpenSys/pkgs/bin:/QOpenSys/usr/bin:$PATH"
        export JAVA_HOME="${JAVA_BIN%/bin}"
        log "Using Java from: $JAVA_HOME"
    else
        log "Java not found - Jenkins requires Java to run" "ERROR"
        log "Please install Java first or run with 'bob' parameter to install BOB (which includes Java)"
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
        log "Service Commander not available - Jenkins installed but not started" "WARN"
        log "Install Service Commander with './init.sh sc' or start Jenkins manually"
        return 0  # Not a failure, just a warning
    fi
    
    return 0
}

#################################################################################
# Function to show usage information
#################################################################################
show_usage() {
    echo "Usage: $0 [jenkins] [bob] [sc]"
    echo ""
    echo "Options:"
    echo "  jenkins    Install and configure Jenkins along with base setup"
    echo "  bob        Install Better Object Builder (BOB) - includes Java"
    echo "  sc         Install Service Commander (required for Jenkins auto-start)"
    echo "  (no args)  Perform base DevOps setup only (users, git)"
    echo ""
    echo "You can combine options:"
    echo "  $0 sc jenkins bob    # Install Service Commander, Jenkins, and BOB"
    echo "  $0 jenkins sc        # Install Jenkins with Service Commander"
    echo ""
    echo "Environment Variables:"
    echo "  DEVOPS_USERS      Users to create (default: 'RAVI RAHUL AVADHOOT YOGESH KHUSHI NAVEEN GAURAV')"
    echo "  DEVOPS_LIB        DevOps library name (default: 'PIODEVOPS')"
    echo "  JENKINS_PORT      Jenkins port (default: 9095)"
    echo "  DEFAULT_PASSWORD  Default password for users (default: 'welcome')"
    echo ""
    echo "Examples:"
    echo "  $0                  # Base setup only (git, users)"
    echo "  $0 sc               # Base setup + Service Commander"
    echo "  $0 bob              # Base setup + BOB installation"
    echo "  $0 sc jenkins       # Base setup + Service Commander + Jenkins"
    echo "  $0 sc jenkins bob   # Complete setup (all components)"
    echo ""
    echo "Note: Jenkins requires Service Commander to auto-start"
    exit 0
}

#################################################################################
#
#                                    MAIN LOGIC 
#
#################################################################################

# Initialize flags
INSTALL_JENKINS=false
INSTALL_BOB=false
INSTALL_SC=false

# Parse command line parameters
for arg in "$@"; do
    case "$arg" in
        "jenkins")
            INSTALL_JENKINS=true
            ;;
        "bob")
            INSTALL_BOB=true
            ;;
        "sc")
            INSTALL_SC=true
            ;;
        "-h"|"--help"|"help")
            show_usage
            ;;
        *)
            log "Unknown parameter: $arg" "ERROR"
            show_usage
            ;;
    esac
done

log "Starting DevOps environment setup with the following configuration:"
log "Users to create: ${USERS_ARRAY[*]}"
log "DevOps library: $DEVOPS_LIB"
log "Default password: $DEFAULT_PASSWORD"
if [ "$INSTALL_JENKINS" = true ]; then
    log "Jenkins port: $JENKINS_PORT"
    log "Jenkins installation: ENABLED"
else
    log "Jenkins installation: DISABLED"
fi
if [ "$INSTALL_BOB" = true ]; then
    log "BOB installation: ENABLED"
else
    log "BOB installation: DISABLED"
fi
if [ "$INSTALL_SC" = true ]; then
    log "Service Commander installation: ENABLED"
else
    log "Service Commander installation: DISABLED"
fi

# Set bash as default shell for current user
printheading "Setting up bash shell..."
/QOpenSys/pkgs/bin/chsh -s /QOpenSys/pkgs/bin/bash "$USER" 2>/dev/null || log "Could not change shell" "WARN"

# Install base packages (git, ibmi-repos)
if ! install_base_packages; then
    log "Base package installation had issues - continuing anyway" "WARN"
fi

# Install Service Commander if requested
if [ "$INSTALL_SC" = true ]; then
    if ! install_service_commander; then
        log "Service Commander installation failed" "ERROR"
        # Don't exit - continue with rest of setup
    fi
fi

# Install BOB if requested
if [ "$INSTALL_BOB" = true ]; then
    if ! install_bob; then
        log "BOB installation failed" "ERROR"
        # Don't exit - continue with rest of setup
    fi
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

# Now create JOBD to setup INLLIBL
printheading "Creating Job Description..."
run_cl_cmd "CRTJOBD JOBD(QGPL/PROGRAMMER) TEXT('Job Description for Developers') INLLIBL(QGPL QTEMP $DEVOPS_LIB)"

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
printheading "Installing PFGREP..."
if /QOpenSys/pkgs/bin/wget https://github.com/SeidenGroup/pfgrep/releases/download/v0.5.1/pfgrep-0.5.1-0seiden.ibmi7.2.ppc64.rpm && /QOpenSys/pkgs/bin/yum install pfgrep-0.5.1-0seiden.ibmi7.2.ppc64.rpm -y; then
    log "PFGREP installed successfully"
else
    log "PFGREP installation failed" "WARN"
fi

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

# Display SSH public key for RAVI
log "SSH Public Key for RAVI (add this to your Git repositories):"
pubkey_file="/home/RAVI/.ssh/id_ed25519.pub"
if [ -f "$pubkey_file" ]; then
    log "RAVI: $(cat "$pubkey_file")"
fi

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
if [ "$INSTALL_BOB" = true ]; then
    echo -e '| BOB (Better Object Builder) installed                      |'
fi
if [ "$INSTALL_SC" = true ]; then
    echo -e '| Service Commander installed                                |'
fi
echo -e "| Users created: ${USERS_ARRAY[*]}                           |"
echo -e "| Default password: $DEFAULT_PASSWORD                        |"
echo -e '|                                                            |'
echo -e '| SECURITY REMINDERS:                                        |'
echo -e '| 1. Change default passwords immediately                    |'
echo -e '| 2. Add SSH public key (RAVI only) to Git repositories      |'
if [ "$INSTALL_JENKINS" = true ]; then
    echo -e '| 3. Verify Jenkins is accessible and secure                 |'
fi
echo -e '| 4. Review user privileges and adjust as needed             |'
echo -e '|============================================================|'
echo -e "\n\n"
