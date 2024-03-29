import Foundation

@main
public struct Dragonfly {
    public static func main() {
        debugPrint(CommandLine.argc, CommandLine.arguments)
        
        let rootDir = FileManager.default.currentDirectoryPath
        let projName = CommandLine.arguments[1]
        
        let repo = "git@github.com:DouKing/iOSTemplate.git"
        
        let templateName = ".Template"
        //_ = shell("git clone git@github.com:DouKing/iOSTemplate.git ./\(templateName)")
        let result = execute(["git", "clone", repo, "./\(templateName)"])
        
        let srcPath = "\(rootDir)/\(templateName)/codebase"
        let dstPath = "\(rootDir)/\(projName)"
        
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

func shell(_ command: String) -> String {
    let task = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    
    task.standardOutput = outputPipe
    task.standardError = errorPipe
    task.arguments = ["-c", command]
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    
    do {
        try task.run()
        task.waitUntilExit()
    } catch {
        print("There was an error running the command: \(command)")
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
        }
        exit(1)
    }
    
    return outputString
}

func execute(_ args: [String]) -> (status: Int32, result: String) {
    let process = Process()
    process.launchPath = "/usr/bin/env"
    process.arguments = args
    
    let pipe = Pipe()
    process.standardOutput = pipe
    
    process.launch()
    process.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output: String = String(data: data, encoding: .utf8)!
    
    return (status: process.terminationStatus, result: output)
}
