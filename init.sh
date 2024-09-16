#!/QOpenSys/usr/bin/bash
# ------------------------------------------------------------------------- #
# Program       : setup.sh
# Author        : Ravisankar Pandian
# Company       : Programmers.io
# Date Written  : 24/05/2024
# Copyright     : Programmers.io
# ------------------------------------------------------------------------- #

# Function to print the progress bar characters.
progress_bar() {
    local total_work=$1
    local work_done=$2
    local progress=$((work_done*20/total_work))  # 20 because 100/5=20
    local filled_part=$(printf "%${progress}s" "")
    local empty_part=$(printf "%$((20-progress))s" "")  # 20 because 100/5=20
    printf "|%s%s| %s%%\r" "${filled_part// /#}" "${empty_part}" "$((work_done*100/total_work))"
}

# Function to show the progress bar
showProgress(){
total_work=$1
work_done=0
while [ $work_done -lt $total_work ]; do
    # Simulate some work with sleep
    /QOpenSys/pkgs/bin/sleep 0.1
    work_done=$((work_done+1))
    progress_bar $total_work $work_done
done
echo ""  # Newline after progress bar
}


# Function to make some gap between every action
printheading(){
    echo -e "\n" 
    echo "==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-=="
    echo "$1"
    echo "==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-=="
}



# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
#                  MAIN LOGIC # ==-==-==-==-==-==-==-==-==-==-==-==-==-==
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# Set bash as the default shell.
/QOpenSys/pkgs/bin/chsh -s /QOpenSys/pkgs/bin/bash $USER
printheading "Changed the default shell to bash..."



# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# create a .profile file in your home folder to store the environment variables.
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
printheading "Setup the environment variables..."
showProgress 10
cd ~

## set Open source packages' path
echo "export PATH=/QOpenSys/QIBM/ProdData/JavaVM/jdk17/64bit/bin:/QOpenSys/pkgs/bin:$PATH" >> .profile
# echo "export JAVA_HOME=/QOpenSys/pkgs/lib/jvm/openjdk-11" >> .profile
echo "export JENKINS_HOME=/home/$USER/jenkins_home" >> .profile
# echo "export GITBUCKET_HOME=/home/$USER/gitbucket_home" >> .profile
source ~/.profile



# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# Change the Prompt String to reflect Git Status.
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
printheading "Setup the Prompt String to show Git Status..."
wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/gitprompt.sh
mv gitprompt.sh .gitprompt.sh
echo "PROMPT_COMMAND='__posh_git_ps1 \"\${VIRTUAL_ENV:+(\`basename \$VIRTUAL_ENV\`)}\\[\\e[32m\\]\\u\\[\\e[0m\\]@\\h:\\[\\e[33m\\]\\w\\[\\e[0m\\] \" \"\\\\\\\$ \";'\$PROMPT_COMMAND" >> .profile
echo "source ~/.gitprompt.sh" >> .profile
source ~/.profile



# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# Install GIT
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
printheading "Setup GIT..."
yum install git -y




# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# Retrieve SSH Keys from GitOnIBMi Repo
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
cd ~
mkdir .ssh
cd .ssh
printheading "Retrieve SSH Keypairs..."
wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/id_ed25519
wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/id_ed25519.pub



# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# Download Jenkins
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
mkdir -p ~/jenkins
mkdir -p ~/jenkins_home
cd ~/jenkins
printheading "Download Jenkins..."
wget --show-progress http://mirrors.jenkins.io/war-stable/latest/jenkins.war



# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# Install Service Commander
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
printheading "Install Service Commander..."
yum install service-commander -y



# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# Copy the Jenkins yml config file
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
printheading "Configure the jenkins yml file..."
showProgress 10
cd ~
wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/jenkins.yml

current_user="$USER"
# Use sed to replace CECUSER with Current_User and save to a temporary file
sed "s/CECUSER/$current_user/g" jenkins.yml > jenkins1.yml
# Move the temporary file to the original file
mv jenkins1.yml /QOpenSys/etc/sc/services/jenkins.yml
rm jenkins.yml


# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# Start Jenkins via SC
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
printheading "Start the Jenkins...."
sc start jenkins



# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# Install BOB
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
printheading "Install Better Object Builder..."
cd ~
yum install bob -y



# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# Create User Profiles and libraries
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# Create the user libraries first
cl CRTLIB RAHUL 
cl CRTLIB AVADHOOT
cl CRTLIB DEVOPSLIB

# Create a job description to put these libraries into library list
cl "CRTJOBD JOBD(QGPL/PROGRAMMER) TEXT('Job Description for Developers') INLLIBL(DEVOPSLIB RAHUL AVADHOOT RAVI QGPL QTEMP)"

# Then create the user profiles and attach the JOBD to them
cl "CRTUSRPRF USRPRF(RAVI) PASSWORD(WELCOME) USRCLS(*SECOFR) CURLIB(RAVI) TEXT('Developers Profile') JOBD(PROGRAMMER)"
cl "CRTUSRPRF USRPRF(RAHUL) PASSWORD(WELCOME) USRCLS(*SECOFR) CURLIB(RAHUL) TEXT('Developers Profile') JOBD(PROGRAMMER)"
cl "CRTUSRPRF USRPRF(AVADHOOT) PASSWORD(WELCOME) USRCLS(*SECOFR) CURLIB(AVADHOOT) TEXT('Developers Profile') JOBD(PROGRAMMER)"

mkdir /home/ravi/.ssh/ -p 
cd /home/ravi/.ssh
wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/id_ed25519
wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/id_ed25519.pub
echo "export PATH=/QOpenSys/QIBM/ProdData/JavaVM/jdk17/64bit/bin:/QOpenSys/pkgs/bin:$PATH" >> .profile
echo "source /home/$current_user/.gitprompt.sh" >> .profile


mkdir /home/rahul/.ssh/ -p 
cd /home/rahul/.ssh
wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/id_ed25519
wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/id_ed25519.pub
echo "export PATH=/QOpenSys/QIBM/ProdData/JavaVM/jdk17/64bit/bin:/QOpenSys/pkgs/bin:$PATH" >> .profile
echo "source /home/$current_user/.gitprompt.sh" >> .profile

mkdir /home/avadhoot/.ssh/ -p 
cd /home/avadhoot/.ssh
wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/id_ed25519
wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/id_ed25519.pub
echo "export PATH=/QOpenSys/QIBM/ProdData/JavaVM/jdk17/64bit/bin:/QOpenSys/pkgs/bin:$PATH" >> .profile
echo "source /home/$current_user/.gitprompt.sh" >> .profile

# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# All done!
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
echo -e "\n\n"
echo -e '|============================================================|'
echo -e '| Initial setup for Bash Prompt, Git, Service-commander,     |'
echo -e "|             BOB & Jenkins are completed!                   |"
echo -e '|============================================================|'
echo -e "\n\n"
