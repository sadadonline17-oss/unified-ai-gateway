import 'package:flutter/services.dart';
import '../constants.dart';

/// Provides a fallback terminal via platform channels when flutter_pty
/// doesn't work on certain devices.
class TerminalService {
  static const _channel = MethodChannel(AppConstants.channelName);

  /// Get the proot command that flutter_pty should spawn.
  /// flutter_pty will use this to start a proot bash shell.
  static Future<Map<String, String>> getProotShellConfig() async {
    final filesDir = await _channel.invokeMethod<String>('getFilesDir') ?? '';
    final nativeLibDir = await _channel.invokeMethod<String>('getNativeLibDir') ?? '';

    final rootfsDir = '$filesDir/rootfs/ubuntu';
    final tmpDir = '$filesDir/tmp';
    final configDir = '$filesDir/config';
    final homeDir = '$filesDir/home';
    final prootPath = '$nativeLibDir/libproot.so';

    final libDir = '$filesDir/lib';

    return {
      'executable': prootPath,
      'rootfsDir': rootfsDir,
      'tmpDir': tmpDir,
      'configDir': configDir,
      'homeDir': homeDir,
      'libDir': libDir,
      'nativeLibDir': nativeLibDir,
      'PROOT_TMP_DIR': tmpDir,
      'PROOT_NO_SECCOMP': '1',
      'PROOT_LOADER': '$nativeLibDir/libprootloader.so',
      'PROOT_LOADER_32': '$nativeLibDir/libprootloader32.so',
      'LD_LIBRARY_PATH': '$libDir:$nativeLibDir',
    };
  }

  static List<String> buildProotArgs(Map<String, String> config) {
    final procFakes = '${config['configDir']}/proc_fakes';
    final sysFakes = '${config['configDir']}/sys_fakes';

    return [
      '-0',
      '--link2symlink',
      '--kernel-release=6.2.1-PRoot-Distro',
      '-r', config['rootfsDir']!,
      '-b', '/dev',
      '-b', '/proc',
      '-b', '/sys',
      // Fake proc entries (matching proot-distro)
      '-b', '$procFakes/loadavg:/proc/loadavg',
      '-b', '$procFakes/stat:/proc/stat',
      '-b', '$procFakes/uptime:/proc/uptime',
      '-b', '$procFakes/version:/proc/version',
      '-b', '$procFakes/vmstat:/proc/vmstat',
      '-b', '$procFakes/cap_last_cap:/proc/sys/kernel/cap_last_cap',
      '-b', '$procFakes/max_user_watches:/proc/sys/fs/inotify/max_user_watches',
      '-b', '$procFakes/fips_enabled:/proc/sys/crypto/fips_enabled',
      // Fake sys entries
      '-b', '$sysFakes/empty:/sys/fs/selinux',
      // App binds
      '-b', '${config['configDir']}/resolv.conf:/etc/resolv.conf',
      '-b', '${config['homeDir']}:/root/home',
      '-w', '/root',
      '/bin/bash',
      '-l',
    ];
  }
}
