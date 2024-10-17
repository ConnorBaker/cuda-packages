# autoAddCudaCompatRunpath hook must be added AFTER `setupCudaHook`. Both
# hooks prepend a path with `libcuda.so` to the `DT_RUNPATH` section of
# patched elf files, but `cuda_compat` path must take precedence (otherwise,
# it doesn't have any effect) and thus appear first. Meaning this hook must be
# executed last.
{
  autoFixElfFiles,
  cuda_compat ? null,
  cudaMajorMinorVersion,
  flags,
  makeSetupHook,
}:
makeSetupHook {
  name = "cuda${cudaMajorMinorVersion}-auto-add-cuda-compat-runpath-hook";
  propagatedBuildInputs = [ autoFixElfFiles ];

  substitutions = {
    # Hotfix Ofborg evaluation
    libcudaPath = if flags.isJetsonBuild then "${cuda_compat}/compat" else null;
  };

  meta = {
    broken = !flags.isJetsonBuild;
    platforms = [ "aarch64-linux" ];
  };
} ./auto-add-cuda-compat-runpath.sh
