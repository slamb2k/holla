# Yubikey PAM Configuration Installer

## Overview

I want to create a terminal based linux tool that configures PAM and allow yubikey for all logins (account, sudo, su, etc).

## Requirements

### General

- I want to use u2f
- For the initial version, you can assume the yubikey will always be in the machine.

### Interface Specific

Based on the different types of interfaces, the tool should behave differently.

#### Terminal (CLI) within Desktop Environment

Whenever a login is required:
    - Write to terminal that the user should touch the yubikey to authenticate after they see the authentication window.
    - Pop the GUI authentication window and focus it.
    - Allow Yubikey to to be used to authenticate in this dialog.
    - If the yubikey auth fails 3 times or the user submits no password, the terminal should display a message to the user that password authentication is required and reopen the window for the password to be entered.
    - Return to the terminal that requested the authentication once completed and display the result of the authentication.
    - Write to the terminal the result of the authentication.

#### Terminal (CLI) within Terminal Emulator

    - Write to terminal that the user should touch the yubikey to authenticate or hit enter to use password authentication.
    - If the yubikey auth fails 3 timesor the user submits no password, they should fallback to password authentication.
    - Once complete, write to the terminal the result of the authentication.

#### GUI

- Pop the GUI authentication window and focus it.
- Allow Yubikey to to be used to authenticate in this dialog.
- If the yubikey auth fails 3 times or the user submits no password, the terminal should display a message to the user that password authentication is required and reopen the window for the password to be entered.
- Once complete, return to the app that requested the authentication and display the result of the authentication.
