# Optional: Dedicated VHDX Storage

This appendix is for users who want to keep their repos on a **separate virtual disk** instead of the default WSL2 distro filesystem.

For this repository, a dedicated VHDX is **optional**, not required. The normal setup is simpler:

- Keep your repos inside your Ubuntu distro, for example at `~/repos`
- Avoid `/mnt/c` for source code because Linux and container I/O is usually slower there
- Let this repo bind-mount `~/repos` into the container at `/home/vscode/repos`

Use a dedicated VHDX only if you have a specific storage reason, such as:

- You want repo data separated from the main distro disk
- You want a larger or independently managed virtual disk
- You want to move repo storage without moving the whole distro

## What Changes

With the default layout:

- Repos live at `~/repos` inside the Ubuntu distro filesystem
- JetBrains opens them via `\\wsl$\Ubuntu\home\<user>\repos\<project>`
- Docker bind-mounts `${HOME}/repos` into the dev container

With a dedicated VHDX layout:

- You mount a separate ext4-formatted VHDX into WSL
- You store repos on that mounted path instead of the distro's default filesystem
- You update your workflow so JetBrains and Docker point to that mounted location

## Important Caveats

- This is an advanced Windows + WSL setup, not the baseline path for this repo
- `wsl --mount --vhd` behavior and requirements can vary by Windows and WSL version
- Creating, attaching, partitioning, and formatting the disk is outside this repo's normal setup flow
- If you use a custom mount path, you may need to adjust bind mounts or symlinks to preserve the expected `~/repos` location

## Recommended Approach

If you choose this layout, keep the rest of the repo unchanged by exposing the mounted disk through the same Linux path the repo already expects.

For example:

1. Mount the dedicated disk into WSL.
2. Create a repo directory on that disk.
3. Bind-mount or symlink that location to `~/repos`.
4. Keep using the existing devcontainer and JetBrains instructions.

That way, the repo continues to work with the existing `${HOME}/repos:/home/vscode/repos` bind mount declared in `.devcontainer/base/docker-compose.base.yml`.

## Not Included Here

This appendix intentionally does **not** prescribe a single PowerShell automation script or Task Scheduler setup as the default solution. Those details are highly environment-specific and add Windows admin and storage-management complexity that most users of this repo do not need.

If you decide to adopt a dedicated VHDX layout, treat it as a host-level customization layered on top of the standard repo workflow, not as a prerequisite for using this repository.
