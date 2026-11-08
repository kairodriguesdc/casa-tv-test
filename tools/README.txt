CASA TV Tools
=============

Double-click scripts for testing CASA on the TV. No AI and no Android tools needed,
so running them costs nothing.

Mac:      open the "mac" folder.
Windows:  open the "windows" folder.

  1 Install CASA Test        downloads the latest build and installs it on the TV
  2 Get CASA Test results    copies the results so you can paste them into the chat with Claude
  3 Remove CASA Test         puts the TV's settings back and uninstalls the test app

The first time, a script asks for the TV's IP address and remembers it.
It also downloads Google's small "adb" tool once, if the computer doesn't have it.

If the TV asks "Allow debugging?", tick Always allow and choose OK.
(Network debugging must be on in the TV's Developer options.)

First run on a Mac: macOS may block the script because it came from the internet.
Right-click the script › Open › Open. After that, double-click works.

First run on Windows: if SmartScreen warns you, choose More info › Run anyway.

repo.txt must hold the GitHub repository that builds the app, for example:
    yourname/casa-tv-test
