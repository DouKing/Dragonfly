import Foundation
import Combine

@main
public struct Dragonfly {
    public static func main() {
        debugPrint(CommandLine.argc, CommandLine.arguments)
        _ = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { time in
                print("\u{1B}[1A\u{1B}[K\(time)")
            }
        
        let rootDir = FileManager.default.currentDirectoryPath
        let projName = CommandLine.arguments[1]
        
        let repo = "git@github.com:DouKing/iOSTemplate.git"
        
        let templateName = ".Template"
        _ = shell("git clone \(repo) ./\(templateName)")
//        _ = shell("git", "clone", repo, "./\(templateName)")
        
        let srcPath = "\(rootDir)/\(templateName)/codebase"
        let dstPath = "\(rootDir)/\(projName)"
        
        try? FileManager.default.removeItem(atPath: "\(rootDir)/\(templateName)/codebase/Application/Runner.xcodeproj/")
        try? FileManager.default.removeItem(atPath: "\(rootDir)/\(templateName)/codebase/Runner.xcworkspace/")
        try? FileManager.default.removeItem(atPath: "\(rootDir)/\(templateName)/codebase/Podfile.lock")
        
        var isDir: ObjCBool = false
        let isExists = FileManager.default.fileExists(atPath: dstPath, isDirectory: &isDir)
        if !isExists || !isDir.boolValue {
            try! FileManager.default.copyItem(atPath: srcPath, toPath: dstPath)
        }
        
        // 修改配置
        
        func modifyConfig(path: String) {
            let content = try! NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
            let newContent = content.replacingOccurrences(of: "Runner", with: projName)
                .replacingOccurrences(of: "com.sample.debug", with: "com.sample.\(projName).debug")
                .replacingOccurrences(of: "com.sample.develop", with: "com.sample.\(projName).develop")
                .replacingOccurrences(of: "com.sample.release", with: "com.sample.\(projName).release")
            do {
                try newContent.write(toFile: path, atomically: true, encoding: .utf8)
            } catch {
                print(error)
            }
        }
        
        modifyConfig(path: "\(dstPath)/Application/project.yml")
        modifyConfig(path: "\(dstPath)/Application/Sources/Config/DebugConfig.xcconfig")
        modifyConfig(path: "\(dstPath)/Application/Sources/Config/DevelopConfig.xcconfig")
        modifyConfig(path: "\(dstPath)/Application/Sources/Config/ReleaseConfig.xcconfig")
        modifyConfig(path: "\(dstPath)/Podfile")
        
        // 清理缓存
        try? FileManager.default.removeItem(atPath: "\(rootDir)/\(templateName)")
        
        // 初始化工程
        _ = shell("xcodegen generate --spec ./\(projName)/Application/project.yml")
    }
}

@discardableResult
func shell(_ args: String...) -> (status: Int32, result: String?) {
    let task = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    
    task.standardOutput = outputPipe
    task.standardError = errorPipe
    task.arguments = ["-c"] + args
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    
    outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
        let data = fileHandle.availableData
        if data.count > 0,
           let result = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            print(result)
        }
    }
    
    errorPipe.fileHandleForReading.readabilityHandler = { fileHandle in
        let data = fileHandle.availableData
        if data.count > 0,
           let result = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            print(result)
        }
    }
    
    do {
        try task.run()
        task.waitUntilExit()
    } catch {
        print("There was an error running the command: \(args)")
        print(error.localizedDescription)
        exit(1)
    }
    
    guard let outputData = try? outputPipe.fileHandleForReading.readToEnd(),
          let outputString = String(data: outputData, encoding: .utf8) else {
        // Print error if needed
        if let errorData = try? errorPipe.fileHandleForReading.readToEnd(),
           let errorString = String(data: errorData, encoding: .utf8) {
            print("Encountered the following error running the command:")
            print(errorString)
            //exit(1)
        }

        return (task.terminationStatus, nil)
    }
    
    return (task.terminationStatus, outputString)
}
