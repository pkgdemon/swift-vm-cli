# swift-vm-cli
Boot VM ISOs with serial using Apple Hypervisor Framework

Requirements
* Apple Silicon based Mac
* macOS 13.0 Ventura or later
* Xcode

After cloning this repo and building with xcode run the project to show the build path:

```
Usage: /Users/jmaloney/Library/Developer/Xcode/DerivedData/swift-vm-cli-hhgddqysbvcjwzgcfoizuqjjkrea/Build/Products/Debug/swift-vm-cli <iso-path>
Program ended with exit code: 64
```
Navigate to this directory and run the application using ISO file as arugment:

```
cd /Users/jmaloney/Library/Developer/Xcode/DerivedData/swift-vm-cli-hhgddqysbvcjwzgcfoizuqjjkrea/Build/Products/Debug/
```

```
./swift-vm-cli /Users/jmaloney/Downloads/ubuntu-22.04.2-live-server-arm64.iso
```
