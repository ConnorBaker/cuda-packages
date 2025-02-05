{
  fetchFromGitHub,
  opencv4,
}:
fetchFromGitHub {
  owner = "opencv";
  repo = "opencv_extra";
  tag = opencv4.version;
  hash = "sha256-sgQstFlhUmjJOCtyfu/C1dzc3ytC6tRxRBgxRtSb/pk=";
}
