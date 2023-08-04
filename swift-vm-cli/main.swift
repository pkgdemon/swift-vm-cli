/*
See LICENSE folder for this programs licensing information.

Abstract:
A command-line utility that runs Linux or FreeBSD in a virtual machine with serial output.
*/

import Foundation
import Virtualization

// MARK: Parse the Command Line

guard CommandLine.argc == 2 else {
    printUsageAndExit()
}

let installerISOPath = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: false)
/*
Example below is to hardcode ISO path instead of requiring arguments
 */
//let installerISOPath = URL(fileURLWithPath: "/Users/jmaloney/Downloads/FreeBSD-13.2-RELEASE-arm64-aarch64-disc1.iso", isDirectory: false)
let vmBundlePath = NSHomeDirectory() + "/Swift VM CLI.bundle/"
let mainDiskImagePath = vmBundlePath + "Disk.img"
let efiVariableStorePath = vmBundlePath + "NVRAM"
let machineIdentifierPath = vmBundlePath + "MachineIdentifier"

private var virtualMachine: VZVirtualMachine!

private var needsInstall = true

/// Set to read handle before starting VM. Not saved.
var fileHandleForReading: FileHandle?

/// Set to write handle before starting VM. Not saved.
var fileHandleForWriting: FileHandle?

func createVMBundle() {
    do {
        try FileManager.default.createDirectory(atPath: vmBundlePath, withIntermediateDirectories: false)
    } catch {
        fatalError("Failed to create “Swift VM VM.bundle.”")
    }
}

// Create an empty disk image for the virtual machine.
func createMainDiskImage() {
    let diskCreated = FileManager.default.createFile(atPath: mainDiskImagePath, contents: nil, attributes: nil)
    if !diskCreated {
        fatalError("Failed to create the main disk image.")
    }

    guard let mainDiskFileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: mainDiskImagePath)) else {
        fatalError("Failed to get the file handle for the main disk image.")
    }

    do {
        // 64 GB disk space.
        try mainDiskFileHandle.truncate(atOffset: 64 * 1024 * 1024 * 1024)
    } catch {
        fatalError("Failed to truncate the main disk image.")
    }
}

// MARK: Create device configuration objects for the virtual machine.

private func createBlockDeviceConfiguration() -> VZVirtioBlockDeviceConfiguration {
    guard let mainDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: mainDiskImagePath), readOnly: false) else {
        fatalError("Failed to create main disk attachment.")
    }

    let mainDisk = VZVirtioBlockDeviceConfiguration(attachment: mainDiskAttachment)
    return mainDisk
}

private func computeCPUCount() -> Int {
    let totalAvailableCPUs = ProcessInfo.processInfo.processorCount

    var virtualCPUCount = totalAvailableCPUs <= 1 ? 1 : totalAvailableCPUs - 1
    virtualCPUCount = max(virtualCPUCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
    virtualCPUCount = min(virtualCPUCount, VZVirtualMachineConfiguration.maximumAllowedCPUCount)

    return virtualCPUCount
}

private func computeMemorySize() -> UInt64 {
    var memorySize = (4 * 1024 * 1024 * 1024) as UInt64 // 4 GiB
    memorySize = max(memorySize, VZVirtualMachineConfiguration.minimumAllowedMemorySize)
    memorySize = min(memorySize, VZVirtualMachineConfiguration.maximumAllowedMemorySize)

    return memorySize
}

private func createAndSaveMachineIdentifier() -> VZGenericMachineIdentifier {
    let machineIdentifier = VZGenericMachineIdentifier()

    // Store the machine identifier to disk so you can retrieve it for subsequent boots.
    try! machineIdentifier.dataRepresentation.write(to: URL(fileURLWithPath: machineIdentifierPath))
    return machineIdentifier
}

private func retrieveMachineIdentifier() -> VZGenericMachineIdentifier {
    // Retrieve the machine identifier.
    guard let machineIdentifierData = try? Data(contentsOf: URL(fileURLWithPath: machineIdentifierPath)) else {
        fatalError("Failed to retrieve the machine identifier data.")
    }

    guard let machineIdentifier = VZGenericMachineIdentifier(dataRepresentation: machineIdentifierData) else {
        fatalError("Failed to create the machine identifier.")
    }

    return machineIdentifier
}

private func createEFIVariableStore() -> VZEFIVariableStore {
    guard let efiVariableStore = try? VZEFIVariableStore(creatingVariableStoreAt: URL(fileURLWithPath: efiVariableStorePath)) else {
        fatalError("Failed to create the EFI variable store.")
    }

    return efiVariableStore
}

private func retrieveEFIVariableStore() -> VZEFIVariableStore {
    if !FileManager.default.fileExists(atPath: efiVariableStorePath) {
        fatalError("EFI variable store does not exist.")
    }

    return VZEFIVariableStore(url: URL(fileURLWithPath: efiVariableStorePath))
}

private func createUSBMassStorageDeviceConfiguration() -> VZUSBMassStorageDeviceConfiguration {
    guard let intallerDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: installerISOPath, readOnly: true) else {
        fatalError("Failed to create installer's disk attachment.")
    }

    return VZUSBMassStorageDeviceConfiguration(attachment: intallerDiskAttachment)
}

private func createNetworkDeviceConfiguration() -> VZVirtioNetworkDeviceConfiguration {
    let networkDevice = VZVirtioNetworkDeviceConfiguration()
    networkDevice.attachment = VZNATNetworkDeviceAttachment()

    return networkDevice
}

private func createInputAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
    let inputAudioDevice = VZVirtioSoundDeviceConfiguration()

    let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
    inputStream.source = VZHostAudioInputStreamSource()

    inputAudioDevice.streams = [inputStream]
    return inputAudioDevice
}

private func createOutputAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
    let outputAudioDevice = VZVirtioSoundDeviceConfiguration()

    let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
    outputStream.sink = VZHostAudioOutputStreamSink()

    outputAudioDevice.streams = [outputStream]
    return outputAudioDevice
}

private func createSerialPortDeviceConfiguration() -> VZSerialPortConfiguration {
    let consoleConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()

    let inputFileHandle = FileHandle.standardInput
    let outputFileHandle = FileHandle.standardOutput

    // Put stdin into raw mode, disabling local echo, input canonicalization,
    // and CR-NL mapping.
    var attributes = termios()
    tcgetattr(inputFileHandle.fileDescriptor, &attributes)
    attributes.c_iflag &= ~tcflag_t(ICRNL)
    attributes.c_lflag &= ~tcflag_t(ICANON | ECHO)
    tcsetattr(inputFileHandle.fileDescriptor, TCSANOW, &attributes)

    let stdioAttachment = VZFileHandleSerialPortAttachment(fileHandleForReading: inputFileHandle,
                                                           fileHandleForWriting: outputFileHandle)

    consoleConfiguration.attachment = stdioAttachment

    return consoleConfiguration
}

func createVirtualMachine() {
    let virtualMachineConfiguration = VZVirtualMachineConfiguration()

    virtualMachineConfiguration.cpuCount = computeCPUCount()
    virtualMachineConfiguration.memorySize = computeMemorySize()
    virtualMachineConfiguration.serialPorts = [createSerialPortDeviceConfiguration()]

    let platform = VZGenericPlatformConfiguration()
    let bootloader = VZEFIBootLoader()
    let disksArray = NSMutableArray()

    if needsInstall {
        // This is a fresh install: Create a new machine identifier and EFI variable store,
        // and configure a USB mass storage device to boot the ISO image.
        platform.machineIdentifier = createAndSaveMachineIdentifier()
        bootloader.variableStore = createEFIVariableStore()
        disksArray.add(createUSBMassStorageDeviceConfiguration())
    } else {
        // The VM is booting from a disk image that already has the OS installed.
        // Retrieve the machine identifier and EFI variable store that were saved to
        // disk during installation.
        platform.machineIdentifier = retrieveMachineIdentifier()
        bootloader.variableStore = retrieveEFIVariableStore()
    }

    virtualMachineConfiguration.platform = platform
    virtualMachineConfiguration.bootLoader = bootloader

    disksArray.add(createBlockDeviceConfiguration())
    guard let disks = disksArray as? [VZStorageDeviceConfiguration] else {
        fatalError("Invalid disksArray.")
    }
    virtualMachineConfiguration.storageDevices = disks

    virtualMachineConfiguration.networkDevices = [createNetworkDeviceConfiguration()]
    virtualMachineConfiguration.audioDevices = [createInputAudioDeviceConfiguration(), createOutputAudioDeviceConfiguration()]

    virtualMachineConfiguration.keyboards = [VZUSBKeyboardConfiguration()]
    virtualMachineConfiguration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]

    try! virtualMachineConfiguration.validate()
    virtualMachine = VZVirtualMachine(configuration: virtualMachineConfiguration)
}

if !FileManager.default.fileExists(atPath: vmBundlePath) {
    needsInstall = true
    createVMBundle()
    createMainDiskImage()

} else {
    needsInstall = false
}

createVirtualMachine()

func printUsageAndExit() -> Never {
    print("Usage: \(CommandLine.arguments[0]) <iso-path>")
    exit(EX_USAGE)
}

virtualMachine.start { (result) in
    if case let .failure(error) = result {
        print("Failed to start the virtual machine. \(error)")
        exit(EXIT_FAILURE)
    }
}

RunLoop.main.run(until: Date.distantFuture)
