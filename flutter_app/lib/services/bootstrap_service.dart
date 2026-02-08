import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import 'native_bridge.dart';

class BootstrapService {
  final Dio _dio = Dio();

  Future<SetupState> checkStatus() async {
    try {
      final complete = await NativeBridge.isBootstrapComplete();
      if (complete) {
        return const SetupState(
          step: SetupStep.complete,
          progress: 1.0,
          message: 'Setup complete',
        );
      }
      return const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: 'Setup required',
      );
    } catch (e) {
      return SetupState(
        step: SetupStep.error,
        error: 'Failed to check status: $e',
      );
    }
  }

  Future<void> runFullSetup({
    required void Function(SetupState) onProgress,
  }) async {
    try {
      // Step 0: Setup directories
      onProgress(const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: 'Setting up directories...',
      ));
      await NativeBridge.setupDirs();
      await NativeBridge.writeResolv();

      // Step 1: Download rootfs
      final arch = await NativeBridge.getArch();
      final rootfsUrl = AppConstants.getRootfsUrl(arch);
      final filesDir = await NativeBridge.getFilesDir();
      final tarPath = '$filesDir/tmp/ubuntu-rootfs.tar.gz';

      onProgress(const SetupState(
        step: SetupStep.downloadingRootfs,
        progress: 0.0,
        message: 'Downloading Ubuntu rootfs...',
      ));

      await _dio.download(
        rootfsUrl,
        tarPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            final mb = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            onProgress(SetupState(
              step: SetupStep.downloadingRootfs,
              progress: progress,
              message: 'Downloading: $mb MB / $totalMb MB',
            ));
          }
        },
      );

      // Step 2: Extract rootfs
      onProgress(const SetupState(
        step: SetupStep.extractingRootfs,
        progress: 0.0,
        message: 'Extracting rootfs (this takes a while)...',
      ));
      await NativeBridge.extractRootfs(tarPath);
      onProgress(const SetupState(
        step: SetupStep.extractingRootfs,
        progress: 1.0,
        message: 'Rootfs extracted',
      ));

      // Install bionic bypass + cwd-fix + node-wrapper BEFORE using node.
      // The wrapper patches process.cwd() which returns ENOSYS in proot.
      await NativeBridge.installBionicBypass();

      // Step 3: Install Node.js
      // Fix permissions inside proot (Java extraction may miss execute bits)
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.0,
        message: 'Fixing rootfs permissions...',
      ));
      // Blanket recursive chmod on all bin/lib directories.
      // Java tar extraction loses execute bits; dpkg needs tar, xz,
      // gzip, rm, mv, etc. — easier to fix everything than enumerate.
      await NativeBridge.runInProot(
        'chmod -R 755 /usr/bin /usr/sbin /bin /sbin '
        '/usr/local/bin /usr/local/sbin 2>/dev/null; '
        'chmod -R +x /usr/lib/apt/ /usr/lib/dpkg/ /usr/libexec/ '
        '/var/lib/dpkg/info/ /usr/share/debconf/ 2>/dev/null; '
        'chmod 755 /lib/*/ld-linux-*.so* /usr/lib/*/ld-linux-*.so* 2>/dev/null; '
        'mkdir -p /var/lib/dpkg/updates /var/lib/dpkg/triggers; '
        'echo permissions_fixed',
      );

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.1,
        message: 'Updating package lists...',
      ));
      await NativeBridge.runInProot('apt-get update -y');

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.2,
        message: 'Downloading base packages...',
      ));
      // APT's internal fork→exec→dpkg fails with exit 100 on Android 10+
      // (W^X policy + PTY setup in the forked child). Workaround: download
      // packages via apt (no dpkg needed), then run dpkg directly from the
      // shell where proot's ptrace interception works correctly.
      await NativeBridge.runInProot(
        'apt-get -q -d install -y --no-install-recommends '
        'ca-certificates curl gnupg',
      );

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.25,
        message: 'Extracting base packages...',
      ));
      // Extract .deb files using Java (Apache Commons Compress) to avoid
      // fork+exec issues in proot on Android 10+. dpkg, dpkg-deb, ar all
      // fail because subprocess forking is broken in proot.
      await NativeBridge.extractDebPackages();

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.3,
        message: 'Configuring certificates...',
      ));
      // Java extraction doesn't run postinst scripts. ca-certificates
      // needs update-ca-certificates to generate the cert bundle.
      // Try it first; if it fails (fork issues), manually concatenate certs.
      try {
        await NativeBridge.runInProot('update-ca-certificates 2>/dev/null');
      } catch (_) {
        // Manual fallback: concatenate all Mozilla CA certs into the bundle
        await NativeBridge.runInProot(
          'mkdir -p /etc/ssl/certs 2>/dev/null; '
          'cat /usr/share/ca-certificates/mozilla/*.crt '
          '> /etc/ssl/certs/ca-certificates.crt 2>/dev/null; '
          'echo certs_done',
        );
      }

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.4,
        message: 'Adding NodeSource repository...',
      ));
      // The NodeSource setup script internally runs apt-get which fails
      // (fork+exec issue). Add the repo manually instead.
      // Use curl -k as fallback if certs are still broken.
      await NativeBridge.runInProot(
        'curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key '
        '-o /tmp/nodesource.gpg.key 2>/dev/null || '
        'curl -fsSLk https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key '
        '-o /tmp/nodesource.gpg.key',
      );
      await NativeBridge.runInProot(
        'gpg --dearmor -o /usr/share/keyrings/nodesource.gpg '
        '< /tmp/nodesource.gpg.key 2>/dev/null; '
        'echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] '
        'https://deb.nodesource.com/node_22.x nodistro main" '
        '> /etc/apt/sources.list.d/nodesource.list; '
        'echo repo_added',
      );

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.5,
        message: 'Updating package lists...',
      ));
      await NativeBridge.runInProot('apt-get update -y');

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.6,
        message: 'Downloading Node.js...',
      ));
      await NativeBridge.runInProot(
        'apt-get -q -d install -y --no-install-recommends nodejs',
      );

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.75,
        message: 'Extracting Node.js packages...',
      ));
      await NativeBridge.extractDebPackages();

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.9,
        message: 'Verifying Node.js...',
      ));
      // proot's getcwd() syscall returns ENOSYS on Android 10+.
      // node --version works (exits before module system init), but any
      // require() call triggers process.cwd() which crashes.
      // Fix: use node-wrapper.js which patches process.cwd before
      // loading the target script. Installed by installBionicBypass().
      // Also unset NODE_OPTIONS (bionic-bypass only needed at gateway runtime).
      const wrapper = '/root/.openclawd/node-wrapper.js';
      // npm needs a writable cache dir; /root/.npm doesn't exist yet
      // and mkdir inside proot can fail. Use /tmp/npm-cache instead.
      const nodeRun =
          'unset NODE_OPTIONS; npm_config_cache=/tmp/npm-cache node $wrapper';
      final npmCli = '/usr/lib/node_modules/npm/bin/npm-cli.js';
      await NativeBridge.runInProot(
        'node --version && $nodeRun $npmCli --version',
      );
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 1.0,
        message: 'Node.js installed',
      ));

      // Step 4: Install OpenClaw
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.0,
        message: 'Installing OpenClaw (this may take a few minutes)...',
      ));
      // --ignore-scripts: npm runs postinstall scripts by forking child
      // processes, which fails in proot (level 2+ fork). Native modules
      // (sharp, node-pty) download prebuilts in postinstall — we handle
      // sharp manually below; node-pty is optional for gateway mode.
      await NativeBridge.runInProot(
        '$nodeRun $npmCli install -g openclaw --ignore-scripts --no-optional',
        timeout: 1800,
      );

      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.7,
        message: 'Setting up native modules...',
      ));
      // Native modules need their prebuilt binaries for linux-arm64.
      // postinstall scripts can't run (spawn fails in proot), so we
      // rebuild them individually. Each is optional — gateway works without them.
      for (final mod in ['sharp', 'better-sqlite3']) {
        try {
          await NativeBridge.runInProot(
            '$nodeRun $npmCli rebuild $mod --ignore-scripts 2>/dev/null; '
            'echo ${mod}_done',
            timeout: 300,
          );
        } catch (_) {
          // Native modules are optional for core gateway
        }
      }

      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.9,
        message: 'Verifying OpenClaw...',
      ));
      await NativeBridge.runInProot(
        '$nodeRun $npmCli list -g openclaw',
      );
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 1.0,
        message: 'OpenClaw installed',
      ));

      // Step 5: Bionic Bypass already installed (before node verification)
      onProgress(const SetupState(
        step: SetupStep.configuringBypass,
        progress: 1.0,
        message: 'Bionic Bypass configured',
      ));

      // Done
      onProgress(const SetupState(
        step: SetupStep.complete,
        progress: 1.0,
        message: 'Setup complete! Ready to start the gateway.',
      ));
    } on DioException catch (e) {
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Download failed: ${e.message}. Check your internet connection.',
      ));
    } catch (e) {
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Setup failed: $e',
      ));
    }
  }
}
