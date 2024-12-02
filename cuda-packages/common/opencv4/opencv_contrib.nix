{
  fetchFromGitHub,
  opencv4,
}:
fetchFromGitHub {
  owner = "opencv";
  repo = "opencv_contrib";
  rev = "refs/tags/${opencv4.version}";
  hash = "sha256-JFSQQRvcZ+aiLUxXqfODaWQW635Xkkvh4xmkNcGySh8=";
}
