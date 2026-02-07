package com.openclawd.app

import java.io.BufferedReader
import java.io.InputStreamReader

class ProcessManager(
    private val filesDir: String,
    private val nativeLibDir: String
) {
    private val rootfsDir get() = "$filesDir/rootfs/ubuntu"
    private val tmpDir get() = "$filesDir/tmp"
    private val homeDir get() = "$filesDir/home"
    private val configDir get() = "$filesDir/config"

    fun getProotPath(): String {
        return "$nativeLibDir/libproot.so"
    }

    fun buildProotCommand(command: String): List<String> {
        val prootPath = getProotPath()
        val nodeOptions = "--require /root/.openclawd/bionic-bypass.js"

        val procFakes = "$configDir/proc_fakes"
        val sysFakes = "$configDir/sys_fakes"

        // Match proot-distro's run_proot_cmd() as closely as possible.
        // NOTE: --sysvipc is deliberately omitted here (matching proot-distro).
        // It causes assertion failures (SIGABRT) when dpkg forks child processes
        // during package installation. Only enable it for interactive/gateway use.
        return listOf(
            prootPath,
            "-0",                           // Fake root (UID 0)
            "--link2symlink",               // Convert hard links to symlinks
            "-L",                           // Fix lstat for symlinks
            "--kill-on-exit",               // Clean up child processes
            "--kernel-release=6.2.1-PRoot-Distro",
            "-r", rootfsDir,
            // Device binds
            "-b", "/dev",
            "-b", "/proc",
            "-b", "/sys",
            "-b", "/dev/urandom:/dev/random",
            // fd/stdin/stdout/stderr (package scripts need these)
            "-b", "/proc/self/fd:/dev/fd",
            "-b", "/proc/self/fd/0:/dev/stdin",
            "-b", "/proc/self/fd/1:/dev/stdout",
            "-b", "/proc/self/fd/2:/dev/stderr",
            // Fake proc entries (Android restricts these)
            "-b", "$procFakes/loadavg:/proc/loadavg",
            "-b", "$procFakes/stat:/proc/stat",
            "-b", "$procFakes/uptime:/proc/uptime",
            "-b", "$procFakes/version:/proc/version",
            "-b", "$procFakes/vmstat:/proc/vmstat",
            "-b", "$procFakes/cap_last_cap:/proc/sys/kernel/cap_last_cap",
            "-b", "$procFakes/max_user_watches:/proc/sys/fs/inotify/max_user_watches",
            "-b", "$procFakes/fips_enabled:/proc/sys/crypto/fips_enabled",
            // Shared memory (proot-distro binds this)
            "-b", "$rootfsDir/tmp:/dev/shm",
            // Fake sys entries
            "-b", "$sysFakes/empty:/sys/fs/selinux",
            // App binds
            "-b", "$configDir/resolv.conf:/etc/resolv.conf",
            "-b", "$homeDir:/root/home",
            "-w", "/root",
            "/bin/bash", "-c",
            "export NODE_OPTIONS=\"$nodeOptions\" && export HOME=/root && export DEBIAN_FRONTEND=noninteractive && export TMPDIR=/tmp && export LANG=C.UTF-8 && export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin && $command"
        )
    }

    private val libDir get() = "$filesDir/lib"

    private fun prootEnv(): Map<String, String> = mapOf(
        "PROOT_TMP_DIR" to tmpDir,
        "PROOT_NO_SECCOMP" to "1",
        // NOTE: Do NOT set PROOT_L2S_DIR here. proot-distro sets it because
        // it extracts via `proot --link2symlink tar`, creating L2S metadata
        // in that dir. We extract with Java, so no L2S metadata exists.
        // Setting it makes proot look for metadata that isn't there, breaking
        // file resolution (ENOSYS on open).
        "PROOT_LOADER" to "$nativeLibDir/libprootloader.so",
        "PROOT_LOADER_32" to "$nativeLibDir/libprootloader32.so",
        "LD_LIBRARY_PATH" to "$libDir:$nativeLibDir",
        "HOME" to "/root"
    )

    fun runInProotSync(command: String, timeoutSeconds: Long = 900): String {
        val cmd = buildProotCommand(command)
        val env = prootEnv()

        val pb = ProcessBuilder(cmd)
        pb.environment().putAll(env)
        pb.redirectErrorStream(true)

        val process = pb.start()
        val output = StringBuilder()
        val errorLines = StringBuilder() // Only error-relevant lines
        val reader = BufferedReader(InputStreamReader(process.inputStream))

        var line: String?
        while (reader.readLine().also { line = it } != null) {
            val l = line ?: continue
            // Filter proot warnings
            if (l.contains("proot warning") || l.contains("can't sanitize")) {
                continue
            }
            output.appendLine(l)
            // Collect error-relevant lines (skip apt progress and info noise)
            if (!l.startsWith("Get:") && !l.startsWith("Fetched ") &&
                !l.startsWith("Hit:") && !l.startsWith("Ign:") &&
                !l.contains(" kB]") && !l.contains(" MB]") &&
                !l.startsWith("Reading package") && !l.startsWith("Building dependency") &&
                !l.startsWith("Reading state") && !l.startsWith("The following") &&
                !l.startsWith("Need to get") && !l.startsWith("After this") &&
                l.trim().isNotEmpty()) {
                errorLines.appendLine(l)
            }
        }

        val exited = process.waitFor(timeoutSeconds, java.util.concurrent.TimeUnit.SECONDS)
        if (!exited) {
            process.destroyForcibly()
            throw RuntimeException("Command timed out after ${timeoutSeconds}s")
        }

        val exitCode = process.exitValue()
        if (exitCode != 0) {
            // Use error-relevant lines for the message (no download noise)
            val errorOutput = errorLines.toString().takeLast(3000).ifEmpty {
                output.toString().takeLast(3000)
            }
            throw RuntimeException(
                "Command failed (exit code $exitCode): $errorOutput"
            )
        }

        return output.toString()
    }

    fun startProotProcess(command: String): Process {
        val cmd = buildProotCommand(command)
        val env = prootEnv()

        val pb = ProcessBuilder(cmd)
        pb.environment().putAll(env)
        pb.redirectErrorStream(false)

        return pb.start()
    }
}
