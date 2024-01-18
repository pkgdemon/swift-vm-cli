# Swift VM CLI

**Boot VM ISOs with serial using Apple Hypervisor Framework**

## Requirements

To use Swift VM CLI, ensure that your system meets the following requirements:

- **Apple Silicon based Mac:** Swift VM CLI relies on Apple's Hypervisor Framework, which is available on Macs with Apple Silicon architecture.

- **macOS 13.0 Ventura or later:** Make sure you are running macOS 13.0 Ventura or a later version. This is necessary for compatibility with the Apple Hypervisor Framework.

- **Xcode:** You need to have Xcode installed on your system. If not already installed, you can download and install Xcode from the App Store or [Apple's official website](https://developer.apple.com/xcode/).

Ensure that these prerequisites are met before proceeding with the build and usage of Swift VM CLI.

## Getting Started

1. Clone this repository to your local machine:

    ```bash
    git clone https://github.com/pkgdemon/swift-vm-cli.git
    ```

2. Build the project using Xcode:

    ```bash
    cd swift-vm-cli
    xcodebuild
    ```

3. Run the project to display the build path:

    ```bash
    Usage: <path-to-built-executable> <iso-path>
    ```

    Example:

    ```bash
    /path/to/built/executable/swift-vm-cli /path/to/your/iso-file.iso
    ```

4. Navigate to the directory containing the built executable:

    ```bash
    cd /path/to/built/executable/
    ```

5. Run the application using an ISO file as an argument:

    ```bash
    ./swift-vm-cli /path/to/your/iso-file.iso
    ```

Make sure to replace placeholders like `<path-to-built-executable>` and `<path/to/your/iso-file.iso>` with the actual paths.
