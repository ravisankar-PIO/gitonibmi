# Set bash as the default shell.
/QOpenSys/pkgs/bin/chsh -s /QOpenSys/pkgs/bin/bash $USER

# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
# create a .profile file in your home folder to store the environment variables.
# ==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
cd ~
echo "export PATH=/QOpenSys/pkgs/bin:$PATH" >> .profile
echo "export JAVA_HOME=/QOpenSys/pkgs/lib/jvm/openjdk-11" >> .profile
echo "export JENKINS_HOME=/home/$USER/jenkins_home" >> .profile
echo "export GITBUCKET_HOME=/home/$USER/gitbucket_home" >> .profile
source ~/.profile


wget --show-progress https://raw.githubusercontent.com/ravisankar-PIO/gitonibmi/main/gitprompt.sh
mv gitprompt.sh .gitprompt.sh
echo "PROMPT_COMMAND='__posh_git_ps1 \"\${VIRTUAL_ENV:+(\`basename \$VIRTUAL_ENV\`)}\\[\\e[32m\\]\\u\\[\\e[0m\\]@\\h:\\[\\e[33m\\]\\w\\[\\e[0m\\] \" \"\\\\\\\$ \";'\$PROMPT_COMMAND" >> .profile
echo "source ~/.gitprompt.sh" >> .profile
source ~/.profile


git config --global user.name 'Ravisankar Pandian' 
git config --global user.email ravisankar.pandian@programmers.io

ssh-keygen -t ed25519 -C "ravisankar.pandian@programmers.io" -f ~/.ssh/id_ed25519 -N ""