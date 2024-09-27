{ config, lib, ... }:
let
  inherit (config) cuda-lib;
  inherit (lib.attrsets) mapAttrs;
  inherit (lib.options) mkOption;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.trivial) const;
  inherit (lib.types)
    addCheck
    enum
    functionTo
    lazyAttrsOf
    nonEmptyListOf
    nonEmptyStr
    nullOr
    oneOf
    optionType
    raw
    strMatching
    submodule
    ;

  # NOTE: Cannot use at the top-level of `options` as it causes an infinite-recursion error.
  mkOptions = mapAttrs (const mkOption);
in
{
  options.cuda-lib.types = mkOptions {
    # TODO: Look into how `pkgs` makes an option type by overriding another option type:
    # https://github.com/NixOS/nixpkgs/blob/a6cc776496975eaef2de3218505c85bb5059fccb/lib/types.nix#L524-L530
    # We should do that for `attrs` and `function` to make docs more readable.
    # TODO: Not able to look at the keys in aggregate -- each typing decision is made per-key.
    attrs = {
      description = "The option type of an attribute set with typed keys and values.";
      type = functionTo (functionTo optionType);
      default =
        keyType: valueType:
        addCheck (lib.types.attrsOf valueType) (
          attrs: builtins.all keyType.check (builtins.attrNames attrs)
        );
    };
    cudaVariant = {
      description = "The option type of a CUDA variant";
      type = optionType;
      default = strMatching "^(None|cuda[[:digit:]]+)$";
    };
    indexOf = {
      description = ''
        The option type of an index attribute set, mapping redistributable names to versionedManifestsOf leafType.
      '';
      type = functionTo optionType;
      default =
        leafType:
        cuda-lib.types.attrs cuda-lib.types.redistName (cuda-lib.types.versionedManifestsOf leafType);
    };
    features = {
      description = "The option type of a features attribute set";
      type = optionType;
      default = submodule {
        options = mkOptions {
          cudaVersionsInLib = {
            description = "Subdirectories of the `lib` directory which are named after CUDA versions";
            type = nullOr (nonEmptyListOf (strMatching "^[[:digit:]]+(\.[[:digit:]]+)?$"));
            default = null;
          };
          outputs = {
            description = ''
              The outputs provided by a package.

              A `bin` output requires that we have a non-empty `bin` directory containing at least one file with the
              executable bit set.

              A `dev` output requires that we have at least one of the following non-empty directories:

              - `lib/pkgconfig`
              - `share/pkgconfig`
              - `lib/cmake`
              - `share/aclocal`

              NOTE: Absent from this list is `include`, which is handled by the `include` output. This is because the `dev`
              output in Nixpkgs is used for development files and is selected as the default output to install if present.
              Since we want to be able to access only the header files, they are present in a separate output.

              A `doc` output requires that we have at least one of the following non-empty directories:

              - `share/info`
              - `share/doc`
              - `share/gtk-doc`
              - `share/devhelp`
              - `share/man`

              An `include` output requires that we have a non-empty `include` directory.

              A `lib` output requires that we have a non-empty lib directory containing at least one shared library.

              A `python` output requires that we have a non-empty `python` directory.

              A `sample` output requires that we have a non-empty `samples` directory.

              A `static` output requires that we have a non-empty lib directory containing at least one static library.

              A `stubs` output requires that we have a non-empty `lib/stubs` or `stubs` directory containing at least one
              shared or static library.
            '';
            type = nonEmptyListOf (enum [
              "out" # Always present
              "bin"
              "dev"
              "doc"
              "include"
              "lib"
              "python"
              "sample"
              "static"
              "stubs"
            ]);
          };
        };
      };
    };
    # TODO: Look into how `pkgs` makes an option type by overriding another option type:
    # https://github.com/NixOS/nixpkgs/blob/a6cc776496975eaef2de3218505c85bb5059fccb/lib/types.nix#L524-L530
    # We should do that for `attrs` and `function` to make docs more readable.
    function = {
      description = "The option type of an function with typed argument and return values.";
      type = functionTo (functionTo optionType);
      default = argType: returnType: addCheck (lib.types.functionTo returnType) argType.check;
    };
    manifestsOf = {
      description = ''
        The option type of a manifest attribute set, mapping package names to releasesOf leafType.
      '';
      type = functionTo optionType;
      default =
        leafType: cuda-lib.types.attrs cuda-lib.types.packageName (cuda-lib.types.releasesOf leafType);
    };
    packageInfo = {
      description = "The option type of a package info attribute set.";
      type = optionType;
      default = submodule {
        options = mkOptions {
          features = {
            description = "Features the package provides";
            type = cuda-lib.types.features;
          };
          recursiveHash = {
            description = "Recursive NAR hash of the unpacked tarball";
            type = cuda-lib.types.sriHash;
          };
          relativePath = {
            description = "The path to the package in the redistributable tree or null if it can be reconstructed.";
            type = nullOr nonEmptyStr;
            default = null;
          };
        };
      };
    };
    packagesOf = {
      description = "The option type of a package info attribute set, mapping platform to packageVariantsOf leafType.";
      type = functionTo optionType;
      default =
        leafType: cuda-lib.types.attrs cuda-lib.types.platform (cuda-lib.types.packageVariantsOf leafType);
    };
    packageName = {
      description = "The option type of a package name";
      type = optionType;
      default = strMatching "^[[:alnum:]_-]+$";
    };
    packageVariantsOf = {
      description = "The option type of a package variant attribute set, mapping CUDA variant to leafType.";
      type = functionTo optionType;
      default = leafType: cuda-lib.types.attrs cuda-lib.types.cudaVariant leafType;
    };
    platform = {
      description = "The option type of a platform";
      type = optionType;
      default = enum config.data.platforms;
    };
    redistConfig = {
      description = "The option type of a redist config attribute set.";
      type = optionType;
      default = submodule {
        options = mkOptions {
          data = {
            description = ''
              Data required to produce packages for (potentially multiple) versions of CUDA.
            '';
            type = cuda-lib.types.versionedManifestsOf cuda-lib.types.packageInfo;
          };
          overrides = {
            description = ''
              Overrides for packages provided by the redistributable.

              NOTE: Trying to use a more expressive type than `raw` causes the automatic-argument detection we do to
              fail, as the `check` function for the type interferes with the functions in the `overrides` attribute
              set.
            '';
            type = cuda-lib.types.attrs cuda-lib.types.packageName raw;
          };
          versionPolicy = {
            description = ''
              Only the latest version matching the selected policy will be used. If a version has fewer parts than the
              selected policy, it will be treated as if it has the missing parts set to 0. For example, if the policy
              is "minor" and the latest version is "1.2", it will be treated as "1.2.0".
            '';
            type = enum [
              "major"
              "minor"
              "patch"
              "build"
            ];
            default = "minor";
          };
        };
      };
    };
    redistName = {
      description = "The option type of allowable redistributables";
      type = optionType;
      default = enum config.data.redistNames;
    };
    redistUrl = {
      description = "The option type of a URL of for something in a redistributable's tree";
      type = optionType;
      default =
        let
          redistNamePattern = "(${concatStringsSep "|" config.data.redistNames})";
          redistUrlPrefixPattern = "(${config.data.redistUrlPrefix})";
          redistUrlPattern = "${redistUrlPrefixPattern}/${redistNamePattern}/redist/(.+)";
        in
        strMatching redistUrlPattern;
    };
    releasesOf = {
      description = "The option type of a release attribute set of leafType.";
      type = functionTo optionType;
      default =
        leafType:
        submodule {
          options = mkOptions {
            releaseInfo.type = cuda-lib.types.releaseInfo;
            packages.type = cuda-lib.types.packagesOf leafType;
          };
        };
    };
    releaseInfo = {
      description = "The option type of a releaseInfo attribute set.";
      type = optionType;
      default = submodule {
        options = mkOptions {
          licensePath = {
            description = "The path to the license file in the redistributable tree";
            type = nullOr nonEmptyStr;
            default = null;
          };
          license = {
            description = "The license of the redistributable";
            type = nullOr nonEmptyStr;
          };
          name = {
            description = "The full name of the redistributable";
            type = nullOr nonEmptyStr;
          };
          version = {
            description = "The version of the redistributable";
            type = cuda-lib.types.version;
          };
        };
      };
    };
    sha256 = {
      description = "The option type of a SHA-256, base64-encoded hash";
      type = optionType;
      default = strMatching "^[[:alnum:]+/]{64}$";
    };
    sriHash = {
      description = "The option type of a Subresource Integrity hash";
      type = optionType;
      # NOTE: This does not check the length of the hash!
      default = strMatching "^(md5|sha(1|256|512))-([[:alnum:]+/]+={0,2})$";
    };
    version = {
      description = "The option type of a version with at least one component";
      type = optionType;
      default = strMatching "^[[:digit:]]+(\.[[:digit:]]+)*$";
    };
    versionedManifestsOf = {
      description = ''
        The option type of a versioned manifest attribute set, mapping version strings to manifestsOf leafType.
      '';
      type = functionTo optionType;
      default =
        leafType: cuda-lib.types.attrs cuda-lib.types.version (cuda-lib.types.manifestsOf leafType);
    };

    # TODO: Better organize/alphabetize.
    callPackageOverrider = {
      description = ''
        The option type of a callPackage overrider.

        These are functions which are passed to callPackage, and then provided to overrideAttrs.

        NOTE: The argument provided to overrideAttrs MUST be a function -- if it is not, callPackage will set
        the override attribute on the resulting attribute set, which when provided to overrideAttrs will break
        the package evaluation.
      '';
      type = optionType;
      default =
        let
          overrideAttrsPrevFn = functionTo (lazyAttrsOf raw);
          overrideAttrsFinalPrevFn = functionTo overrideAttrsPrevFn;
        in
        functionTo (oneOf [
          overrideAttrsPrevFn
          overrideAttrsFinalPrevFn
        ]);
    };
    # TODO: Possible improvement for error messages?
    # error: attribute 'deprecationMessage' missing
    #    at /nix/store/djw90qs3g3awfpcd7rhx80017620nm07-source/lib/modules.nix:805:17:
    #       804|       warnDeprecation =
    #       805|         warnIf (opt.type.deprecationMessage != null)
    #          |                 ^
    #       806|           "The type `types.${opt.type.name}' of option `${showOption loc}' defined in ${showFiles opt.declarations} is deprecated. ${opt.type.deprecationMessage}";
    #
    # When we leave off mkOption on cudaCapability, we get that error. However, as `options.types` is defined as a submodule
    # of freeformType = optionType, it should instead provide an error message about how cudaCapability is not a valid option type.
    # NOTE: I can't think of a way to actually improve this error message, because we would need to do type-checking on the options attribute set,
    # not the config attribute set (which is where checks are performed).
    cudaCapability = {
      description = "The option type of a CUDA capability.";
      type = optionType;
      default = strMatching "^[[:digit:]]+\\.[[:digit:]]+[a-z]?$";
    };
    flattenedIndexElem = {
      description = "The option type of an element of a flattened index";
      type = optionType;
      default = submodule {
        options = mkOptions {
          cudaVariant.type = cuda-lib.types.cudaVariant;
          packageInfo.type = cuda-lib.types.packageInfo;
          packageName.type = cuda-lib.types.packageName;
          platform.type = cuda-lib.types.platform;
          redistName.type = cuda-lib.types.redistName;
          releaseInfo.type = cuda-lib.types.releaseInfo;
          # NOTE: This is the version of the manifest, not the version of an individual redist package (that is
          # provided by releaseInfo.version).
          version.type = cuda-lib.types.version;
        };
      };
    };
    majorVersion = {
      description = "The option type of a version with a single component";
      type = optionType;
      default = cuda-lib.types.versionWithNumComponents 1;
    };
    majorMinorVersion = {
      description = "The option type of a version with two components";
      type = optionType;
      default = cuda-lib.types.versionWithNumComponents 2;
    };
    majorMinorPatchVersion = {
      description = "The option type of a version with three components";
      type = optionType;
      default = cuda-lib.types.versionWithNumComponents 3;
    };
    majorMinorPatchBuildVersion = {
      description = "The option type of a version with four components";
      type = optionType;
      default = cuda-lib.types.versionWithNumComponents 4;
    };
    versionWithNumComponents = {
      description = "The option type of a version with a specific number of components";
      type = functionTo optionType;
      default =
        numComponents:
        if numComponents < 1 then
          throw "numComponents must be positive"
        else
          strMatching "^[[:digit:]]+(\.[[:digit:]]+){${toString (numComponents - 1)}}$";
    };
  };
}
