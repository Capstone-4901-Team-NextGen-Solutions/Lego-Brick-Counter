-------------------------------------
Lego Brick Counter/Sorter
-------------------------------------

Description: A system that identifies, classifies, and counts Lego bricks from images or camera
input. It generates an inventory and matches against Lego set databases to suggest buildable sets
or highlight missing pieces. Functions as an intelligent Lego inventory and recommendation
assistant.

-------------------------------------
Motivation:

● Combines computer vision, machine learning, and database management.

● Challenges include recognizing bricks from images and mapping them to sets.

● A fun and engaging technical problem with real-world use for Lego enthusiasts.

---------------------------------------------
Platform:

● Mobile app that is supported on IOS and Android platforms.

● Python for CV/ML (OpenCV, CNNs).

● Flask/Django or Node.js for UI.

● Optional mobile integration for capturing images.

------------------------------------
Features:

● Brick classification via CV/ML.

● Automated counting.

● Database comparison to suggest sets.

● Intuitive UI for uploads, visualization, and recommendations.

● Stretch goal: Real-time sorting with hardware integration.
-----------------------------------------------------
How to Run:

1) Download repository by cloning it.
2) use 'cd backend' to get into the /backend folder.
3) run 'py -3.11 -m pip install -r requirements.txt' //Note: any version of python 3.11 will do, and it I had to install it to be able to download the pakages needed to run the app in the requirements.txt.
4) After that run "py -3.11 app.py". This will run the backend part of the app.
5) In another terminal, either on VS code or the CMD, navigate to the /frontend folder by 'cd .../frontend' or just 'cd frontend' if you are already on the project file path. //Note: go to the file path where the project is on.
6) Once you are in the frontend folder, run 'flutter clean'.
7) Run 'flutter pub get'.
8) Finally run 'flutter run'.
9) You will be prompted to either choose chrome, windows/mac, or edge.
10) I usually choose chrome, but it will pop up around 30 seconds to a minute and depends on each computer.
11) Optionally, you can run 'flutter run -d emulator-5564' to run in a virtual phone emulator // Note: Replace emulator-5564 with your emulator name.
    - Use 'flutter devices' to see all the devices you can run, or SEE BELOW on how to create either an ios or android emulator.

How to create your emulator:
1) Navigate to either android studio or Xcode(IoS emulator)
2) go to device manager and add a device.
3) This will create your own virtual mobile emulator.
4) Start the emulator, and it is ready to go. This will appear in your terminal when typing 'flutter devices'.
