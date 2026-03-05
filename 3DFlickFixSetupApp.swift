import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Foundation

struct ContentView: View {
    @State private var configPath: String = ""
    @State private var mountBaseDir: String = NSHomeDirectory()
    @State private var mountpoint: String = "3DFF"
    @State private var remoteName: String = "3DFF"
    @State private var mode: SetupMode = .both
    @State private var status: String = "Select your rclone config and mount folder, then click Mount Now."
    @State private var mountServiceStatus: String = "Unknown"
    @State private var dlnaServiceStatus: String = "Unknown"
    @State private var macFUSEStatus: String = "Unknown"
    @State private var macFUSEInstalledVersion: String = "Unknown"
    @State private var macFUSELatestVersion: String = "Unknown"
    @State private var macFUSEVersionStatus: String = "Unknown"
    @State private var rcloneInstalledVersion: String = "Unknown"
    @State private var rcloneInstalledStatus: String = "Unknown"
    @State private var rcloneLatestVersion: String = "Unknown"
    @State private var rcloneVersionStatus: String = "Unknown"
    @State private var connectionStatus: String = "Not tested"
    @State private var lastErrorDetails: String = ""
    @State private var flashVersionBadge: Bool = false
    @State private var isFirstInstallRunning: Bool = false

    private let statusTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let flashTimer = Timer.publish(every: 0.7, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.95, blue: 0.99),
                    Color(red: 0.88, green: 0.92, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 420, height: 420)
                .blur(radius: 40)
                .offset(x: -240, y: -220)

            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 480, height: 480)
                .blur(radius: 60)
                .offset(x: 300, y: 260)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    glassSurface {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("3DFlickFix Setup")
                                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                                Text("Mount and DLNA control center for Apple Silicon")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(isFirstInstallRunning ? "Setting Up..." : "Set Up Everything") {
                                firstTimeInstallation()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(isFirstInstallRunning)
                        }
                    }

                    glassSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Configuration")
                                .font(.headline)

                            HStack(spacing: 10) {
                                Label("rclone config file", systemImage: "doc.text")
                                    .foregroundStyle(.secondary)
                                Text(configPath.isEmpty ? "No file selected" : configPath)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button("Select File") {
                                    pickConfigFile()
                                }
                                .buttonStyle(GlassActionButtonStyle())
                            }

                            HStack(spacing: 10) {
                                Label("Mount folder", systemImage: "folder")
                                    .foregroundStyle(.secondary)
                                Text(mountBaseDir)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button("Select Folder") {
                                    pickMountDirectory()
                                }
                                .buttonStyle(GlassActionButtonStyle())
                            }
                        }
                    }

                    glassSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Dependencies")
                                .font(.headline)

                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("macFUSE: \(macFUSEStatus)")
                                    Text("rclone: \(rcloneInstalledStatus)")
                                }

                                Spacer()

                                HStack(spacing: 8) {
                                    Button("Install / Update macFUSE") {
                                        downloadAndInstallMacFUSE()
                                    }
                                    Button("Install / Update rclone") {
                                        downloadAndInstallRclone()
                                    }
                                }
                                .buttonStyle(GlassActionButtonStyle())
                            }

                            HStack(spacing: 6) {
                                Text("macFUSE")
                                    .foregroundStyle(.secondary)
                                Text("installed \(macFUSEInstalledVersion)")
                                    .foregroundStyle(.secondary)
                                Text("latest \(macFUSELatestVersion)")
                                    .foregroundStyle(macFUSEVersionStatus == "Update available" ? .red : .secondary)
                                    .opacity(macFUSEVersionStatus == "Update available" ? (flashVersionBadge ? 0.35 : 1.0) : 1.0)
                                Text("(\(macFUSEVersionStatus))")
                                    .foregroundStyle(.secondary)
                                Text("|")
                                    .foregroundStyle(.secondary)
                                Text("rclone")
                                    .foregroundStyle(.secondary)
                                Text("installed \(rcloneInstalledVersion)")
                                    .foregroundStyle(.secondary)
                                Text("latest \(rcloneLatestVersion)")
                                    .foregroundStyle(rcloneVersionStatus == "Update available" ? .red : .secondary)
                                    .opacity(rcloneVersionStatus == "Update available" ? (flashVersionBadge ? 0.35 : 1.0) : 1.0)
                                Text("(\(rcloneVersionStatus))")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        }
                    }

                    glassSurface {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Service Mode")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("Mode", selection: $mode) {
                                    ForEach(SetupMode.allCases) { option in
                                        Text(option.displayName).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 280)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Remote")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("3DFF", text: $remoteName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 130)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Mount Name")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("3DFF", text: $mountpoint)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 150)
                            }

                            Spacer()
                        }
                    }

                    glassSurface {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Quick Actions")
                                .font(.headline)

                            HStack(spacing: 8) {
                                Button("Mount Now") {
                                    mountNow()
                                }
                                .keyboardShortcut(.defaultAction)

                                Button("Start DLNA") {
                                    startDLNANow()
                                }

                                Button("Stop DLNA") {
                                    stopDLNANow()
                                }

                                Button("Check DLNA Health") {
                                    runDLNAHealthCheck()
                                }
                            }

                            HStack(spacing: 8) {
                                Button("Remove Mount") {
                                    removeMount()
                                }

                                Button("Remove Services") {
                                    removeServices()
                                }

                                Button("Test Connection") {
                                    testConnection()
                                }

                                Button("Refresh Status") {
                                    refreshServiceStatus()
                                }

                                Button("Open Logs") {
                                    openLogsFolder()
                                }

                                Button("Copy Details") {
                                    copyErrorText()
                                }
                                .disabled(lastErrorDetails.isEmpty)
                            }
                        }
                        .buttonStyle(GlassActionButtonStyle())
                    }

                    HStack(alignment: .top, spacing: 12) {
                        glassSurface {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Live Status")
                                    .font(.headline)
                                Text("Mount Service: \(mountServiceStatus)")
                                Text("DLNA Service: \(dlnaServiceStatus)")
                                Text("macFUSE: \(macFUSEStatus)")
                                Text("Connection Test: \(connectionStatus)")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity)

                        glassSurface {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Details")
                                    .font(.headline)
                                ScrollView {
                                    Text(lastErrorDetails.isEmpty ? "No details yet." : lastErrorDetails)
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                                .frame(height: 120)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    glassSurface {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 760, minHeight: 420)
        .onAppear {
            if configPath.isEmpty, let detected = autoDetectRcloneConfigPath() {
                configPath = detected
                status = "Auto-selected config file: \((detected as NSString).lastPathComponent)"
            }
            refreshServiceStatus()
            refreshMacFUSEStatus()
            refreshVersionChecks()
        }
        .onReceive(statusTimer) { _ in
            refreshServiceStatus()
        }
        .onReceive(flashTimer) { _ in
            if macFUSEVersionStatus == "Update available" || rcloneVersionStatus == "Update available" {
                flashVersionBadge.toggle()
            } else {
                flashVersionBadge = false
            }
        }
    }

    @ViewBuilder
    private func glassSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    private func pickConfigFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "conf") ?? .plainText]
        panel.message = "Choose your rclone.conf file."

        if panel.runModal() == .OK, let url = panel.url {
            configPath = url.path
            status = "Selected config file: \(url.lastPathComponent)"
        }
    }

    private func pickMountDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose the folder where the mount will be created."

        if panel.runModal() == .OK, let url = panel.url {
            mountBaseDir = url.path
            status = "Selected mount folder: \(url.path)"
        }
    }

    private func installServices() {
        guard ensureConfigPathSelected() else { return }

        if (mode == .mount || mode == .both) && mountpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = "Enter a mount name to continue."
            return
        }

        guard let script = Bundle.main.path(forResource: "InstallServices", ofType: "sh") else {
            status = "InstallServices.sh is missing from the app bundle."
            lastErrorDetails = status
            return
        }

        guard let stagedConfigPath = stageConfigForPrivilegedAccess() else {
            status = "Could not prepare rclone.conf for installation."
            return
        }

        let requestedRemote = remoteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteResolution = resolveRemote(requested: requestedRemote, configPath: stagedConfigPath)
        guard let effectiveRemote = remoteResolution.remote else {
            status = "No remotes were found in the selected rclone.conf file."
            lastErrorDetails = remoteResolution.message ?? "No remotes returned by rclone listremotes."
            return
        }
        if let message = remoteResolution.message {
            status = message
            lastErrorDetails = message
            remoteName = effectiveRemote
        }

        let escapedScript = shellEscape(script)
        let escapedMode = shellEscape(mode.rawValue)
        let escapedRemote = shellEscape(effectiveRemote)
        let escapedConfig = shellEscape(stagedConfigPath)

        var cmd = "\(escapedScript) --yes --mode \(escapedMode) --remote \(escapedRemote) --config-file \(escapedConfig)"

        if mode == .mount || mode == .both {
            cmd += " --mountpoint \(shellEscape(mountpoint)) --mount-dir \(shellEscape(mountBaseDir))"
        }

        runPrivileged(command: cmd, actionName: "install")
        refreshServiceStatusDelayed()
    }

    private func firstTimeInstallation() {
        guard ensureConfigPathSelected() else { return }

        isFirstInstallRunning = true
        status = "Running first-time setup checks..."
        lastErrorDetails = ""

        refreshVersionChecks { macStatus, rcloneStatus in
            runFirstTimeDependencyInstall(macStatus: macStatus, rcloneStatus: rcloneStatus)
        }
    }

    private func runFirstTimeDependencyInstall(macStatus: String, rcloneStatus: String) {
        if macStatus == "Update available" || macStatus == "Not installed" {
            DispatchQueue.main.async {
                status = "macFUSE is missing or out of date. Installing the latest version..."
            }

            downloadAndInstallMacFUSE { success, message in
                DispatchQueue.main.async {
                    if !success {
                        status = "macFUSE installation failed before setup could continue."
                        lastErrorDetails = message
                        isFirstInstallRunning = false
                        return
                    }

                    status = "macFUSE is ready. Checking rclone..."
                    refreshVersionChecks { _, refreshedRcloneStatus in
                        runFirstTimeRcloneInstallIfNeeded(rcloneStatus: refreshedRcloneStatus)
                    }
                }
            }
            return
        }

        runFirstTimeRcloneInstallIfNeeded(rcloneStatus: rcloneStatus)
    }

    private func runFirstTimeRcloneInstallIfNeeded(rcloneStatus: String) {
        if rcloneStatus == "Update available" || rcloneStatus == "Not installed" {
            DispatchQueue.main.async {
                status = "rclone is missing or out of date. Installing the latest version..."
            }

            downloadAndInstallRclone { success, message in
                DispatchQueue.main.async {
                    if !success {
                        status = "rclone installation failed before setup could continue."
                        lastErrorDetails = message
                        isFirstInstallRunning = false
                        return
                    }

                    status = "rclone is ready. Finishing setup..."
                    installServices()
                    isFirstInstallRunning = false
                }
            }
            return
        }

        DispatchQueue.main.async {
            status = "Everything is up to date. Finishing setup..."
            installServices()
            isFirstInstallRunning = false
        }
    }

    private func mountNow() {
        guard ensureConfigPathSelected() else { return }

        let remote = remoteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let point = mountpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remote.isEmpty else {
            status = "Enter a remote name to continue."
            lastErrorDetails = status
            return
        }
        guard !point.isEmpty else {
            status = "Enter a mount name to continue."
            lastErrorDetails = status
            return
        }

        guard let rclone = resolveRcloneBinary() else {
            status = "rclone could not be found. Please install or update rclone first."
            lastErrorDetails = status
            return
        }

        guard let stagedConfigPath = stageConfigForPrivilegedAccess() else {
            status = "Could not prepare rclone.conf for mounting."
            return
        }

        let remoteResolution = resolveRemote(requested: remote, configPath: stagedConfigPath)
        guard let effectiveRemote = remoteResolution.remote else {
            status = "No remotes were found in the selected rclone.conf file."
            lastErrorDetails = remoteResolution.message ?? "No remotes returned by rclone listremotes."
            return
        }
        if let message = remoteResolution.message {
            status = message
            lastErrorDetails = message
            remoteName = effectiveRemote
        }

        let mountDir = URL(fileURLWithPath: mountBaseDir).appendingPathComponent(point).path
        if isMountActive(at: mountDir) {
            status = "Mount is already active at \(mountDir)."
            lastErrorDetails = ""
            refreshServiceStatusDelayed()
            return
        }

        let mountLog = userMountLogPath()
        let mountLogDir = (mountLog as NSString).deletingLastPathComponent
        do {
            try FileManager.default.createDirectory(atPath: mountLogDir, withIntermediateDirectories: true)
        } catch {
            status = "Could not create the mount log folder: \(mountLogDir)"
            lastErrorDetails = error.localizedDescription
            return
        }
        do {
            try FileManager.default.createDirectory(atPath: mountDir, withIntermediateDirectories: true)
        } catch {
            status = "Could not create the mount folder: \(mountDir)"
            lastErrorDetails = error.localizedDescription
            return
        }

        status = "Mounting \(effectiveRemote): to \(mountDir)..."

        DispatchQueue.global(qos: .userInitiated).async {
            let result = runCommand(rclone, arguments: [
                "mount",
                "\(effectiveRemote):",
                mountDir,
                "--daemon",
                "--allow-other",
                "--dir-cache-time", "72h",
                "--drive-chunk-size", "64M",
                "--log-level", "INFO",
                "--vfs-read-chunk-size", "32M",
                "--vfs-read-chunk-size-limit", "off",
                "--config", stagedConfigPath,
                "--log-file", mountLog,
                "--vfs-cache-mode", "full"
            ])

            let logTail = tailFile(path: mountLog, lines: 40)

            DispatchQueue.main.async {
                if result.exitCode != 0 {
                    status = "Mount failed."
                    let output = [result.output, logTail].filter { !$0.isEmpty }.joined(separator: "\n")
                    lastErrorDetails = output.isEmpty ? "The mount command returned an error." : output
                    return
                }

                if isMountActive(at: mountDir) {
                    status = "Mount is active at \(mountDir)."
                    lastErrorDetails = ""
                } else {
                    status = "The mount command finished, but no active mount was detected."
                    lastErrorDetails = logTail.isEmpty ? "Check \(mountLog) for details." : logTail
                }

                refreshServiceStatusDelayed()
            }
        }
    }

    private func startDLNANow() {
        guard ensureConfigPathSelected() else { return }

        let requestedRemote = remoteName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedRemote.isEmpty else {
            status = "Enter a remote name to continue."
            lastErrorDetails = status
            return
        }

        guard let rclone = resolveRcloneBinary() else {
            status = "rclone could not be found. Please install or update rclone first."
            lastErrorDetails = status
            return
        }

        let remoteResolution = resolveRemote(requested: requestedRemote, configPath: configPath)
        guard let effectiveRemote = remoteResolution.remote else {
            status = "No remotes were found in the selected rclone.conf file."
            lastErrorDetails = remoteResolution.message ?? "No remotes returned by rclone listremotes."
            return
        }

        if let message = remoteResolution.message {
            status = message
            lastErrorDetails = message
            remoteName = effectiveRemote
        }

        if isProcessRunning(matching: "rclone.*serve.*dlna") {
            status = "DLNA is already running."
            refreshServiceStatusDelayed()
            return
        }

        let dlnaLog = userDLNALogPath()
        let dlnaLogDir = (dlnaLog as NSString).deletingLastPathComponent
        do {
            try FileManager.default.createDirectory(atPath: dlnaLogDir, withIntermediateDirectories: true)
        } catch {
            status = "Could not create the DLNA log folder: \(dlnaLogDir)"
            lastErrorDetails = error.localizedDescription
            return
        }

        status = "Starting DLNA server for \(effectiveRemote)..."

        let shellCommand = [
            "nohup",
            shellEscape(rclone),
            "serve",
            "dlna",
            shellEscape("\(effectiveRemote):"),
            "--name",
            shellEscape("3DFlickFix"),
            "--dir-cache-time", "72h",
            "--drive-chunk-size", "64M",
            "--log-level", "INFO",
            "--vfs-read-chunk-size", "32M",
            "--vfs-read-chunk-size-limit", "off",
            "--config", shellEscape(configPath),
            "--log-file", shellEscape(dlnaLog),
            "--vfs-cache-mode", "full",
            ">/dev/null 2>&1 &"
        ].joined(separator: " ")

        DispatchQueue.global(qos: .userInitiated).async {
            _ = runCommand("/bin/sh", arguments: ["-lc", shellCommand])
            let logTail = tailFile(path: dlnaLog, lines: 40)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if isProcessRunning(matching: "rclone.*serve.*dlna") {
                    status = "DLNA started successfully."
                    lastErrorDetails = ""
                } else {
                    status = "DLNA failed to start."
                    lastErrorDetails = logTail.isEmpty ? "Check \(dlnaLog) for details." : logTail
                }
                refreshServiceStatusDelayed()
            }
        }
    }

    private func stopDLNANow() {
        let result = runCommand("/usr/bin/pkill", arguments: ["-f", "rclone.*serve.*dlna"])
        if result.exitCode == 0 {
            status = "DLNA has been stopped."
            lastErrorDetails = ""
        } else {
            status = "No running DLNA process was found."
            lastErrorDetails = ""
        }
        refreshServiceStatusDelayed()
    }

    private func runDLNAHealthCheck() {
        status = "Running DLNA health check..."
        lastErrorDetails = ""

        DispatchQueue.global(qos: .userInitiated).async {
            var checks: [String] = []
            var passed = true

            let processResult = runCommand("/usr/bin/pgrep", arguments: ["-f", "rclone.*serve.*dlna"])
            if processResult.exitCode == 0 {
                let procLine = processResult.output.split(separator: "\n").first.map(String.init) ?? "running"
                checks.append("Process: OK (\(procLine))")
            } else {
                checks.append("Process: FAIL (no running rclone DLNA process was found)")
                passed = false
            }

            let listenResult = runCommand("/usr/sbin/lsof", arguments: ["-nP", "-iTCP:7879", "-sTCP:LISTEN"])
            if listenResult.exitCode == 0, listenResult.output.contains("rclone") {
                checks.append("Port 7879: OK (rclone is listening)")
            } else {
                checks.append("Port 7879: FAIL (rclone is not listening)")
                passed = false
            }

            let endpoints = [
                "/static/ContentDirectory.xml",
                "/static/ConnectionManager.xml",
                "/static/X_MS_MediaReceiverRegistrar.xml"
            ]

            for endpoint in endpoints {
                let url = "http://127.0.0.1:7879\(endpoint)"
                let curl = runCommand("/usr/bin/curl", arguments: ["-s", "--max-time", "4", "-o", "/dev/null", "-w", "%{http_code}", url])
                if curl.exitCode == 0, curl.output == "200" {
                    checks.append("\(endpoint): OK (200)")
                } else {
                    let code = curl.output.isEmpty ? "no response" : curl.output
                    checks.append("\(endpoint): FAIL (\(code))")
                    passed = false
                }
            }

            if !passed {
                let dlnaLog = userDLNALogPath()
                let tail = tailFile(path: dlnaLog, lines: 40)
                if !tail.isEmpty {
                    checks.append("")
                    checks.append("Recent DLNA log:")
                    checks.append(tail)
                }
            }

            let details = checks.joined(separator: "\n")
            DispatchQueue.main.async {
                status = passed ? "DLNA health check passed." : "DLNA health check failed."
                lastErrorDetails = details
                refreshServiceStatusDelayed()
            }
        }
    }

    private func removeMount() {
        let point = mountpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseDir = mountBaseDir.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !baseDir.isEmpty else {
            status = "Enter a mount folder to continue."
            lastErrorDetails = status
            return
        }

        let targetDir = URL(fileURLWithPath: baseDir).appendingPathComponent(point).path

        let cmdParts = [
            "BASE_DIR=\(shellEscape(baseDir))",
            "TARGET_DIR=\(shellEscape(targetDir))",
            "if [ -n \"$TARGET_DIR\" ] && [ -d \"$TARGET_DIR\" ] && /sbin/mount | /usr/bin/grep -F \" on $TARGET_DIR (\" >/dev/null; then /sbin/umount \"$TARGET_DIR\" || /usr/sbin/diskutil unmount force \"$TARGET_DIR\" || true; fi",
            "if [ -n \"$TARGET_DIR\" ] && [ -d \"$TARGET_DIR\" ]; then /bin/rmdir \"$TARGET_DIR\" 2>/dev/null || true; fi",
            "if [ -d \"$BASE_DIR\" ]; then for d in \"$BASE_DIR\"/*; do [ -d \"$d\" ] || continue; if /sbin/mount | /usr/bin/grep -F \" on $d (\" >/dev/null; then /sbin/umount \"$d\" || /usr/sbin/diskutil unmount force \"$d\" || true; /bin/rmdir \"$d\" 2>/dev/null || true; echo \"Removed mount: $d\"; fi; done; fi"
        ]

        let cmd = cmdParts.joined(separator: "; ")
        runPrivileged(command: cmd, actionName: "remove mount")
        refreshServiceStatusDelayed()
    }

    private func downloadAndInstallMacFUSE(completion: ((Bool, String) -> Void)? = nil) {
        status = "Downloading and installing macFUSE..."
        lastErrorDetails = ""

        let command = [
            "set -e",
            "API_URL='https://api.github.com/repos/macfuse/macfuse/releases/latest'",
            "PKG_URL=$(/usr/bin/curl -fsSL \"$API_URL\" | /usr/bin/grep browser_download_url | /usr/bin/grep '\\.pkg' | /usr/bin/head -n 1 | /usr/bin/cut -d '\"' -f 4)",
            "if [ -z \"$PKG_URL\" ]; then echo 'Failed to find macFUSE pkg download URL'; exit 1; fi",
            "PKG_NAME=$(/usr/bin/basename \"$PKG_URL\")",
            "TMP_PKG=\"/tmp/$PKG_NAME\"",
            "/usr/bin/curl -L \"$PKG_URL\" -o \"$TMP_PKG\"",
            "/usr/sbin/installer -pkg \"$TMP_PKG\" -target /",
            "/bin/rm -f \"$TMP_PKG\"",
            "echo 'macFUSE installed successfully.'",
            "echo 'You may need to approve the system extension in System Settings -> Privacy & Security.'",
            "echo 'A reboot might be required.'"
        ].joined(separator: "; ")

        DispatchQueue.global(qos: .userInitiated).async {
            let result = runPrivilegedWithResult(command: command, actionName: "download and install macfuse")
            DispatchQueue.main.async {
                if result.success {
                    status = "macFUSE installation completed."
                    if !result.message.isEmpty {
                        lastErrorDetails = result.message
                    }
                    refreshMacFUSEStatus()
                    refreshVersionChecks()
                } else {
                    status = "macFUSE installation failed."
                    lastErrorDetails = result.message
                }

                completion?(result.success, result.message)
            }
        }
    }

    private func downloadAndInstallRclone(completion: ((Bool, String) -> Void)? = nil) {
        status = "Downloading and installing rclone..."
        lastErrorDetails = ""

        let command = [
            "set -e",
            "VERSION='v1.73.1'",
            "ARCH='osx-arm64'",
            "FILE=\"rclone-${VERSION}-${ARCH}.zip\"",
            "URL=\"https://downloads.rclone.org/${VERSION}/${FILE}\"",
            "WORKDIR='/tmp/3dflickfix-rclone-install'",
            "rm -rf \"$WORKDIR\"",
            "mkdir -p \"$WORKDIR\"",
            "cd \"$WORKDIR\"",
            "/usr/bin/curl -L -o \"$FILE\" \"$URL\"",
            "/usr/bin/unzip -q \"$FILE\"",
            "cd \"rclone-${VERSION}-${ARCH}\"",
            "/usr/bin/install -m 755 rclone /usr/local/bin/rclone",
            "cd /",
            "rm -rf \"$WORKDIR\"",
            "/usr/local/bin/rclone version | /usr/bin/head -n 1"
        ].joined(separator: "; ")

        DispatchQueue.global(qos: .userInitiated).async {
            let result = runPrivilegedWithResult(command: command, actionName: "download and install rclone")
            DispatchQueue.main.async {
                if result.success {
                    status = "rclone installation completed."
                    if !result.message.isEmpty {
                        lastErrorDetails = result.message
                    }
                    refreshVersionChecks()
                } else {
                    status = "rclone installation failed."
                    lastErrorDetails = result.message
                }

                completion?(result.success, result.message)
            }
        }
    }

    private func updateBundledRcloneToLatest(completion: @escaping (Bool, String) -> Void) {
        guard let apiURL = URL(string: "https://api.github.com/repos/rclone/rclone/releases/latest") else {
            completion(false, "Invalid GitHub API URL for rclone.")
            return
        }

        let archResult = runCommand("/usr/bin/uname", arguments: ["-m"])
        let arch = archResult.output.lowercased()
        let assetHint = arch == "arm64" ? "osx-arm64" : "osx-amd64"

        var request = URLRequest(url: apiURL)
        request.setValue("3DFlickFix-Setup", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(false, "Failed to fetch latest rclone release: \(error.localizedDescription)")
                return
            }

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(false, "GitHub API request failed with status code \(code).")
                return
            }

            guard let data else {
                completion(false, "GitHub API returned no data.")
                return
            }

            do {
                let release = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let assets = release?["assets"] as? [[String: Any]] ?? []

                guard let asset = assets.first(where: { asset in
                    let name = (asset["name"] as? String ?? "").lowercased()
                    return name.contains(assetHint) && name.hasSuffix(".zip")
                }) else {
                    completion(false, "Could not find an rclone macOS \(assetHint) zip in the latest release.")
                    return
                }

                guard let assetURLString = asset["browser_download_url"] as? String,
                      let assetURL = URL(string: assetURLString) else {
                    completion(false, "Latest rclone release metadata is missing download URL.")
                    return
                }

                URLSession.shared.downloadTask(with: assetURL) { tempURL, _, downloadError in
                    if let downloadError {
                        completion(false, "rclone download failed: \(downloadError.localizedDescription)")
                        return
                    }

                    guard let tempURL else {
                        completion(false, "rclone download failed: temporary file not available.")
                        return
                    }

                    guard let bundledRclonePath = Bundle.main.path(forResource: "rclone", ofType: nil) else {
                        completion(false, "Bundled rclone path not found in app resources.")
                        return
                    }

                    let zipPath = "/tmp/3dflickfix-rclone-latest.zip"
                    do {
                        let zipURL = URL(fileURLWithPath: zipPath)
                        if FileManager.default.fileExists(atPath: zipPath) {
                            try FileManager.default.removeItem(at: zipURL)
                        }
                        try FileManager.default.copyItem(at: tempURL, to: zipURL)
                    } catch {
                        completion(false, "Failed to stage rclone archive: \(error.localizedDescription)")
                        return
                    }

                    let command = [
                        "TMPDIR=/tmp/3dflickfix-rclone-update",
                        "rm -rf \"$TMPDIR\"",
                        "mkdir -p \"$TMPDIR\"",
                        "/usr/bin/unzip -oq \(shellEscape(zipPath)) -d \"$TMPDIR\"",
                        "RC_BIN=$(/usr/bin/find \"$TMPDIR\" -type f -name rclone | /usr/bin/head -n 1)",
                        "if [ -z \"$RC_BIN\" ]; then echo 'rclone binary not found in archive'; exit 1; fi",
                        "/usr/bin/install -m 755 \"$RC_BIN\" \(shellEscape(bundledRclonePath))",
                        "echo Updated rclone at \(shellEscape(bundledRclonePath))"
                    ].joined(separator: "; ")

                    DispatchQueue.main.async {
                        let result = runPrivilegedWithResult(command: command, actionName: "update rclone")
                        completion(result.success, result.message)
                    }
                }.resume()
            } catch {
                completion(false, "Failed to parse latest rclone metadata: \(error.localizedDescription)")
            }
        }.resume()
    }

    private func removeServices() {
        guard let script = Bundle.main.path(forResource: "RemoveServices", ofType: "sh") else {
            status = "RemoveServices.sh is missing from the app bundle."
            lastErrorDetails = status
            return
        }

        var cmd = "\(shellEscape(script)) --yes"
        if !mountpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cmd += " --mountpoint \(shellEscape(mountpoint))"
        }
        runPrivileged(command: cmd, actionName: "remove")
        refreshServiceStatusDelayed()
    }

    private func testConnection() {
        guard ensureConfigPathSelected() else {
            connectionStatus = "Config file not selected"
            return
        }

        let remote = remoteName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remote.isEmpty else {
            status = "Enter a remote name to continue."
            connectionStatus = "Remote name missing"
            return
        }

        guard let rclone = resolveRcloneBinary() else {
            status = "rclone could not be found. Please install or update rclone first."
            connectionStatus = "rclone is missing"
            return
        }

        connectionStatus = "Testing..."
        let remoteResolution = resolveRemote(requested: remote, configPath: configPath)
        guard let effectiveRemote = remoteResolution.remote else {
            status = "No remotes were found in the selected rclone.conf file."
            connectionStatus = "No remotes found"
            lastErrorDetails = remoteResolution.message ?? "No remotes returned by rclone listremotes."
            return
        }
        if let message = remoteResolution.message {
            status = message
            lastErrorDetails = message
            remoteName = effectiveRemote
        } else {
            status = "Testing remote \(effectiveRemote): with the selected config file..."
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = runCommand(rclone, arguments: ["lsd", "\(effectiveRemote):", "--config", configPath, "--max-depth", "1"])
            DispatchQueue.main.async {
                if result.exitCode == 0 {
                    connectionStatus = "OK"
                    status = "Connection test succeeded for remote \(effectiveRemote)."
                } else {
                    let details = result.output.isEmpty ? "Unknown error" : result.output
                    connectionStatus = "Failed"
                    status = "Connection test failed."
                    lastErrorDetails = details
                }
            }
        }
    }

    private func refreshServiceStatus() {
        DispatchQueue.global(qos: .utility).async {
            let mount = isProcessRunning(matching: "rclone.*mount")
            let dlna = isProcessRunning(matching: "rclone.*serve.*dlna")

            DispatchQueue.main.async {
                mountServiceStatus = mount ? "Running" : "Stopped"
                dlnaServiceStatus = dlna ? "Running" : "Stopped"
            }
        }
    }

    private func refreshMacFUSEStatus() {
        DispatchQueue.global(qos: .utility).async {
            let installed = isMacFUSEInstalled()
            DispatchQueue.main.async {
                macFUSEStatus = installed ? "Installed" : "Not installed"
                if installed {
                    status = "macFUSE is installed."
                } else {
                    status = "macFUSE was not detected. Use Install / Update macFUSE to install the latest release."
                }
            }
        }
    }

    private func refreshVersionChecks(completion: ((String, String) -> Void)? = nil) {
        status = "Checking installed and latest versions for macFUSE and rclone..."

        DispatchQueue.global(qos: .utility).async {
            let localMacFUSE = getInstalledMacFUSEVersion() ?? "Not installed"
            let localRclone = getInstalledRcloneVersion() ?? "Not installed"

            fetchLatestReleaseTag(repo: "macfuse/macfuse") { latestMacFUSE in
                let latestMac = latestMacFUSE ?? "Unknown"

                fetchLatestReleaseTag(repo: "rclone/rclone") { latestRclone in
                    let latestRc = latestRclone ?? "Unknown"

                    DispatchQueue.main.async {
                        macFUSEInstalledVersion = localMacFUSE
                        macFUSELatestVersion = latestMac
                        macFUSEVersionStatus = compareVersionStatus(installed: localMacFUSE, latest: latestMac)

                        rcloneInstalledVersion = localRclone
                        rcloneInstalledStatus = localRclone == "Not installed" ? "Not installed" : "Installed"
                        rcloneLatestVersion = latestRc
                        rcloneVersionStatus = compareVersionStatus(installed: localRclone, latest: latestRc)

                        status = "Version check complete."
                        completion?(macFUSEVersionStatus, rcloneVersionStatus)
                    }
                }
            }
        }
    }

    private func refreshServiceStatusDelayed() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            refreshServiceStatus()
        }
    }

    private func runPrivileged(command: String, actionName: String) {
        let appleScriptSource = "do shell script \"\(escapeForAppleScript(command))\" with administrator privileges"
        guard let scriptObject = NSAppleScript(source: appleScriptSource) else {
            status = "Could not request administrator access for \(actionName)."
            return
        }

        var errorInfo: NSDictionary?
        let result = scriptObject.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            status = "\(actionName.capitalized) failed."
            lastErrorDetails = message
            return
        }

        let output = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if output.isEmpty {
            status = "\(actionName.capitalized) completed successfully."
            lastErrorDetails = ""
        } else {
            status = "\(actionName.capitalized) completed with additional details."
            lastErrorDetails = output
        }
    }

    private func runPrivilegedWithResult(command: String, actionName: String) -> (success: Bool, message: String) {
        let appleScriptSource = "do shell script \"\(escapeForAppleScript(command))\" with administrator privileges"
        guard let scriptObject = NSAppleScript(source: appleScriptSource) else {
            return (false, "Failed to create AppleScript for \(actionName).")
        }

        var errorInfo: NSDictionary?
        let result = scriptObject.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            return (false, message)
        }

        let output = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (true, output)
    }

    private func stageConfigForPrivilegedAccess() -> String? {
        if configPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let detected = autoDetectRcloneConfigPath() {
            configPath = detected
            status = "Auto-selected config file: \((detected as NSString).lastPathComponent)"
        }

        let sourcePath = configPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourcePath.isEmpty else {
            status = "Please select an rclone.conf file first."
            lastErrorDetails = status
            return nil
        }

        let destinationPath = "/tmp/3dflickfix-rclone.conf"
        do {
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let destinationURL = URL(fileURLWithPath: destinationPath)
            if FileManager.default.fileExists(atPath: destinationPath) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationPath)
            return destinationPath
        } catch {
            let details = "Could not copy config to /tmp: \(error.localizedDescription)"
            status = details
            lastErrorDetails = details
            return nil
        }
    }

    private func copyErrorText() {
        guard !lastErrorDetails.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastErrorDetails, forType: .string)
        status = "Copied details to the clipboard."
    }

    private func openLogsFolder() {
        let logsDir = "\(NSHomeDirectory())/Library/Logs/3DFlickFix"
        do {
            try FileManager.default.createDirectory(atPath: logsDir, withIntermediateDirectories: true)
            NSWorkspace.shared.open(URL(fileURLWithPath: logsDir, isDirectory: true))
            status = "Opened logs folder."
        } catch {
            status = "Could not open the logs folder."
            lastErrorDetails = error.localizedDescription
        }
    }

    private func ensureConfigPathSelected() -> Bool {
        if !configPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        if let detected = autoDetectRcloneConfigPath() {
            configPath = detected
            status = "Auto-selected config file: \((detected as NSString).lastPathComponent)"
            return true
        }

        status = "Please select an rclone.conf file first."
        lastErrorDetails = status
        return false
    }

    private func autoDetectRcloneConfigPath() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "/tmp/3dflickfix-rclone.conf",
            "\(home)/Downloads/rclone-3.conf",
            "\(home)/Downloads/3DFlickFix-MacOS/rclone.conf",
            "\(home)/.config/rclone/rclone.conf"
        ]

        for candidate in candidates {
            if FileManager.default.isReadableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}

private struct GlassActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.28))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

enum SetupMode: String, CaseIterable, Identifiable {
    case mount
    case dlna
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mount: return "Mount"
        case .dlna: return "DLNA"
        case .both: return "Both"
        }
    }
}

@main
struct SetupApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

private func shellEscape(_ input: String) -> String {
    return "'" + input.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

private func escapeForAppleScript(_ input: String) -> String {
    return input
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

private func resolveRcloneBinary() -> String? {
    let candidates = [
        "/usr/local/bin/rclone",
        "/opt/homebrew/bin/rclone",
        "/usr/bin/rclone"
    ]

    for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
        return path
    }

    if let bundled = Bundle.main.path(forResource: "rclone", ofType: nil),
       FileManager.default.isExecutableFile(atPath: bundled) {
        return bundled
    }

    return nil
}

private func runCommand(_ launchPath: String, arguments: [String]) -> (exitCode: Int32, output: String) {
    let process = Process()
    let outputPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return (1, "Failed to run command: \(error.localizedDescription)")
    }

    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return (process.terminationStatus, output)
}

private func tailFile(path: String, lines: Int) -> String {
    let result = runCommand("/usr/bin/tail", arguments: ["-n", String(lines), path])
    if result.exitCode == 0 {
        return result.output
    }
    return ""
}

private func userMountLogPath() -> String {
    let home = NSHomeDirectory()
    return "\(home)/Library/Logs/3DFlickFix/mount.log"
}

private func userDLNALogPath() -> String {
    let home = NSHomeDirectory()
    return "\(home)/Library/Logs/3DFlickFix/dlna.log"
}

private func isProcessRunning(matching pattern: String) -> Bool {
    let result = runCommand("/usr/bin/pgrep", arguments: ["-f", pattern])
    return result.exitCode == 0
}

private func isMountActive(at path: String) -> Bool {
    let result = runCommand("/sbin/mount", arguments: [])
    guard result.exitCode == 0 else { return false }
    return result.output.contains(" on \(path) (")
}

private func isMacFUSEInstalled() -> Bool {
    let fsPaths = [
        "/Library/Filesystems/macfuse.fs",
        "/Library/Filesystems/osxfuse.fs"
    ]

    for path in fsPaths where FileManager.default.fileExists(atPath: path) {
        return true
    }

    let pkgIds = [
        "com.github.osxfuse.pkg.Core",
        "io.macfuse.installer.pkg",
        "io.macfuse.installer",
        "io.macfuse.installer.components.core",
        "io.macfuse.installer.components.preferencepane",
        "com.github.macfuse"
    ]

    for pkg in pkgIds {
        let result = runCommand("/usr/sbin/pkgutil", arguments: ["--pkg-info", pkg])
        if result.exitCode == 0 {
            return true
        }
    }

    return false
}

private func getInstalledMacFUSEVersion() -> String? {
    let plistPath = "/Library/Filesystems/macfuse.fs/Contents/Info.plist"
    if FileManager.default.fileExists(atPath: plistPath) {
        let result = runCommand("/usr/bin/defaults", arguments: ["read", plistPath, "CFBundleShortVersionString"])
        if result.exitCode == 0, !result.output.isEmpty {
            return result.output
        }
    }

    let pkgIds = [
        "io.macfuse.installer.components.core",
        "io.macfuse.installer.components.preferencepane",
        "io.macfuse.installer.pkg",
        "io.macfuse.installer",
        "com.github.macfuse",
        "com.github.osxfuse.pkg.Core"
    ]

    for pkg in pkgIds {
        let result = runCommand("/usr/sbin/pkgutil", arguments: ["--pkg-info", pkg])
        if result.exitCode == 0, let version = parseField(named: "version", fromPkgInfo: result.output) {
            return version
        }
    }

    return nil
}

private func getInstalledRcloneVersion() -> String? {
    let candidates = [
        "/usr/local/bin/rclone",
        "/opt/homebrew/bin/rclone",
        resolveRcloneBinary()
    ].compactMap { $0 }

    for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
        let result = runCommand(candidate, arguments: ["version"])
        if result.exitCode == 0, let token = firstVersionToken(in: result.output) {
            return token
        }
    }

    return nil
}

private func listRemotes(configPath: String) -> [String] {
    guard let rclone = resolveRcloneBinary() else {
        return []
    }

    let result = runCommand(rclone, arguments: ["listremotes", "--config", configPath])
    guard result.exitCode == 0 else {
        return []
    }

    return result.output
        .split(separator: "\n")
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .map { $0.hasSuffix(":") ? String($0.dropLast()) : $0 }
}

private func resolveRemote(requested: String, configPath: String) -> (remote: String?, message: String?) {
    let remotes = listRemotes(configPath: configPath)
    guard !remotes.isEmpty else {
        return (nil, "No remotes found in selected config.")
    }

    if remotes.contains(requested) {
        return (requested, nil)
    }

    let fallback = remotes[0]
    let message = "Remote '\(requested)' not found. Using '\(fallback)' from selected config."
    return (fallback, message)
}

private func fetchLatestReleaseTag(repo: String, completion: @escaping (String?) -> Void) {
    guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
        completion(nil)
        return
    }

    var request = URLRequest(url: url)
    request.setValue("3DFlickFix-Setup", forHTTPHeaderField: "User-Agent")

    URLSession.shared.dataTask(with: request) { data, response, error in
        guard error == nil,
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let data else {
            completion(nil)
            return
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            completion(json?["tag_name"] as? String)
        } catch {
            completion(nil)
        }
    }.resume()
}

private func compareVersionStatus(installed: String, latest: String) -> String {
    let installedNorm = normalizedVersion(installed)
    let latestNorm = normalizedVersion(latest)

    guard let installedNorm, let latestNorm else {
        if installed.lowercased().contains("not installed") {
            return "Not installed"
        }
        return "Unknown"
    }

    switch compareSemanticVersion(installedNorm, latestNorm) {
    case .orderedAscending:
        return "Update available"
    case .orderedSame:
        return "Up to date"
    case .orderedDescending:
        return "Ahead of latest"
    }
}

private func normalizedVersion(_ raw: String) -> String? {
    let token = firstVersionToken(in: raw)
    guard let token else { return nil }

    let trimmed = token
        .replacingOccurrences(of: "macfuse-", with: "", options: .caseInsensitive)
        .replacingOccurrences(of: "rclone-", with: "", options: .caseInsensitive)
        .replacingOccurrences(of: "v", with: "", options: .caseInsensitive)
    return trimmed
}

private func firstVersionToken(in text: String) -> String? {
    let pattern = "[A-Za-z-]*v?[0-9]+(?:\\.[0-9]+)+"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return nil
    }
    let nsText = text as NSString
    let range = NSRange(location: 0, length: nsText.length)
    guard let match = regex.firstMatch(in: text, options: [], range: range) else {
        return nil
    }
    return nsText.substring(with: match.range)
}

private func compareSemanticVersion(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let lhsParts = lhs.split(separator: ".").compactMap { Int($0) }
    let rhsParts = rhs.split(separator: ".").compactMap { Int($0) }

    let maxCount = max(lhsParts.count, rhsParts.count)
    for idx in 0..<maxCount {
        let l = idx < lhsParts.count ? lhsParts[idx] : 0
        let r = idx < rhsParts.count ? rhsParts[idx] : 0
        if l < r { return .orderedAscending }
        if l > r { return .orderedDescending }
    }
    return .orderedSame
}

private func parseField(named field: String, fromPkgInfo output: String) -> String? {
    for line in output.split(separator: "\n") {
        let prefix = "\(field): "
        if line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return nil
}
