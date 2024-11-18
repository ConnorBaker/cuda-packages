# autoAddCudaCompatRunpath hook must be added AFTER `setupCudaHook`. Both
# hooks prepend a path with `libcuda.so` to the `DT_RUNPATH` section of
# patched elf files, but `cuda_compat` path must take precedence (otherwise,
# it doesn't have any effect) and thus appear first. Meaning this hook must be
# executed last.
{
  autoFixElfFiles,
  backendStdenv,
  cuda_compat ? null,
  flags,
  lib,
  makeSetupHook,
}:
makeSetupHook {
  name = "${backendStdenv.cudaNamePrefix}-auto-add-cuda-compat-runpath-hook";
  propagatedBuildInputs = [ autoFixElfFiles ];

  substitutions = {
    # Hotfix Ofborg evaluation
    libcudaPath = if flags.isJetsonBuild then "${cuda_compat}/compat" else null;
  };

  meta = {
    description = "Setup hook which propagates cuda-compat on Jetson devices";
    broken = !flags.isJetsonBuild;
    platforms = [ "aarch64-linux" ];
    maintainers = lib.teams.cuda.members;
  };
} ./auto-add-cuda-compat-runpath.sh
