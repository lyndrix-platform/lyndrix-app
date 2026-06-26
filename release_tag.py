#!/usr/bin/env python3
"""Release tag helper (mirrors the Lyndrix release flow).

Bump version.py first, then cut the tag — CI builds + publishes the APK on the tag.

Usage:
  ./release_tag.py --version 0.1.0
Options:
  --both          also create a bare X.Y.Z tag (no leading v)
  --push-commit   push current branch before tagging
  --remote        remote name (default: origin)
  --force         overwrite existing tags
"""
import argparse
import os
import subprocess
import sys


def run(cmd, cwd=None, check=True):
    print(f"> {' '.join(cmd)} (cwd={cwd or os.getcwd()})")
    return subprocess.run(cmd, cwd=cwd, check=check)


def is_git_repo(path):
    return os.path.isdir(os.path.join(path, '.git'))


def git_has_uncommitted_changes(path):
    r = subprocess.run(['git', 'status', '--porcelain'], cwd=path, stdout=subprocess.PIPE, text=True)
    return bool(r.stdout.strip())


def tag_exists_local(path, tag):
    r = subprocess.run(['git', 'tag', '--list', tag], cwd=path, stdout=subprocess.PIPE, text=True)
    return bool(r.stdout.strip())


def tag_exists_remote(path, remote, tag):
    r = subprocess.run(['git', 'ls-remote', '--tags', remote, f'refs/tags/{tag}'], cwd=path, stdout=subprocess.PIPE, text=True)
    return bool(r.stdout.strip())


def delete_remote_tag(path, remote, tag):
    run(['git', 'push', remote, f':refs/tags/{tag}'], cwd=path)


def create_and_push_tags(path, version, opts):
    vtag = version if version.startswith('v') else f'v{version}'
    bare = version.lstrip('v')
    tags_to_create = [vtag]
    if opts.both:
        tags_to_create.append(bare)
    for tag in tags_to_create:
        if tag_exists_local(path, tag):
            if opts.force:
                run(['git', 'tag', '-d', tag], cwd=path)
            else:
                print(f"Tag {tag} already exists locally in {path}. Use --force to overwrite.")
                sys.exit(1)
        message = opts.message or f"Release {tag}"
        run(['git', 'tag', '-a', tag, '-m', message], cwd=path)
    for tag in tags_to_create:
        if opts.force and tag_exists_remote(path, opts.remote, tag):
            delete_remote_tag(path, opts.remote, tag)
        run(['git', 'push', opts.remote, tag], cwd=path)


def process_repo(path, version, opts):
    path = os.path.abspath(path)
    if not is_git_repo(path):
        print(f"Not a git repo: {path}")
        return
    if git_has_uncommitted_changes(path) and not opts.force:
        print(f"Repository {path} has uncommitted changes. Commit or use --force to continue.")
        return
    if opts.push_commit:
        run(['git', 'push', opts.remote, 'HEAD'], cwd=path)
    create_and_push_tags(path, version, opts)


def main():
    p = argparse.ArgumentParser(description='Create and push release tags')
    p.add_argument('--version', '-v', required=True, help='Version, e.g. 0.1.0 or v0.1.0')
    p.add_argument('--repos', '-r', nargs='*', default=['.'], help='Repository paths (default: cwd)')
    p.add_argument('--both', action='store_true', help='Also create a bare tag without leading v')
    p.add_argument('--push-commit', action='store_true', help='Push current branch before tagging')
    p.add_argument('--remote', default='origin', help='Remote name')
    p.add_argument('--message', '-m', help='Tag message')
    p.add_argument('--force', action='store_true', help='Overwrite tags if they exist')
    args = p.parse_args()
    for repo in args.repos:
        print(f"\n== Processing {repo} ==\n")
        process_repo(repo, args.version, args)


if __name__ == '__main__':
    main()
