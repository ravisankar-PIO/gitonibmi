#!/QOpenSys/usr/bin/bash
# ------------------------------------------------------------------------- #
# Program       : profilesetup.sh
# Author        : Ravisankar Pandian
# Company       : Programmers.io
# Date Written  : 24/05/2024
# Copyright     : Programmers.io
# Description   : This script is used to setup the BASH, .profile and .gitprompt.sh 
#                 for the personal profiles. 
# ------------------------------------------------------------------------- #

#################################################################################
# Function to setup the user profiles
#################################################################################
createprofile(){
  # Create the user libraries first
  cl CRTLIB $1 
  
  # Setup the SSH Keys
  echo "Setup the .ssh folder for the users..."

  echo "mkdir -p /home/$1/.ssh"
  mkdir -p /home/$1/.ssh  

  echo "cd /home/$1/.ssh"
  cd /home/$1/.ssh

  /QOpenSys/pkgs/bin/wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/id_ed25519
  /QOpenSys/pkgs/bin/wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/id_ed25519.pub
  /QOpenSys/pkgs/bin/chmod 600 id_ed25519
  /QOpenSys/pkgs/bin/chmod 600 id_ed25519.pub

  
  # Setup the .profile file
  cd .. && echo "export PATH=/QOpenSys/QIBM/ProdData/JavaVM/jdk17/64bit/bin:/QOpenSys/pkgs/bin:$PATH" >> .profile
  
  # Setup gitprompt on bash
  /QOpenSys/pkgs/bin/wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/gitprompt.sh
  mv gitprompt.sh .gitprompt.sh
  echo "PROMPT_COMMAND='__posh_git_ps1 \"\${VIRTUAL_ENV:+(\`basename \$VIRTUAL_ENV\`)}\\[\\e[32m\\]\\u\\[\\e[0m\\]@\\h:\\[\\e[33m\\]\\w\\[\\e[0m\\] \" \"\\\\\\\$ \";'\$PROMPT_COMMAND" >> .profile
  echo "source /home/$1/.gitprompt.sh" >> .profile

  # Change the shell to Bash for this user
  echo "/QOpenSys/pkgs/bin/chsh -s /QOpenSys/pkgs/bin/bash $1"
  /QOpenSys/pkgs/bin/chsh -s /QOpenSys/pkgs/bin/bash $1
}

createprofile "RAVI"