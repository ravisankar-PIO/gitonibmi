# gitonibmi
A repository to connect the GitHub with IBMi

# Initial Lab Server Setup
1. Connect to the VS Code with the new lab server using the **CECUSER** profile. 
2. Change shell to BASH
3. Open the BASH Terminal `Ctrl+Shift+J`, run the below command and come back after having a coffee. :coffee:

```
/QOpenSys/pkgs/bin/wget -qO- raw.githubusercontent.com/ravisankar-PIO/gitonibmi/refs/heads/main/init.sh | bash
```

## What this script will do?
1. Creates 3 user profiles  `Rahul, Ravi and Avadhoot` and 4 libraries `DEVOPSLIB, RAHULP, AVADHOOT, RAVI`
3. Creates a JOBD `PROGRAMMER` for setting up the library list and attaches it to the user profiles
4. Installs GIT, Jenkins, BOB, Service Commander & GitPrompt
