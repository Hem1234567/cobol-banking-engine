#!/usr/bin/env python3
"""Validate every YAML file with a real parser and basic workflow sanity checks."""

from __future__ import annotations

from pathlib import Path
import sys

import yaml

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = {".git", ".tools", "build", ".work", "output", "node_modules", "__pycache__"}


class UniqueKeyLoader(yaml.BaseLoader):
    """BaseLoader keeps YAML 1.1 words such as 'on' as strings."""

    def construct_mapping(self, node, deep=False):  # type: ignore[override]
        mapping = {}
        for key_node, value_node in node.value:
            key = self.construct_object(key_node, deep=deep)
            if key in mapping:
                raise yaml.constructor.ConstructorError(
                    "while constructing a mapping",
                    node.start_mark,
                    f"found duplicate key {key!r}",
                    key_node.start_mark,
                )
            mapping[key] = self.construct_object(value_node, deep=deep)
        return mapping


def iter_yaml_files() -> list[Path]:
    files = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".yml", ".yaml"}:
            continue
        if any(part in EXCLUDED for part in path.parts):
            continue
        files.append(path)
    return sorted(files)


def validate_workflow(path: Path, data: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return [f"{path}: workflow root must be a mapping"]
    for key in ("name", "on", "permissions", "jobs"):
        if key not in data:
            errors.append(f"{path}: missing required workflow key {key!r}")
    jobs = data.get("jobs")
    if not isinstance(jobs, dict):
        errors.append(f"{path}: jobs must be a mapping")
        return errors
    for job_id, job in jobs.items():
        if not isinstance(job, dict):
            errors.append(f"{path}: job {job_id} must be a mapping")
            continue
        if "runs-on" not in job:
            errors.append(f"{path}: job {job_id} has no runs-on")
        if "timeout-minutes" not in job:
            errors.append(f"{path}: job {job_id} has no timeout-minutes")
        needs = job.get("needs", [])
        if isinstance(needs, str):
            needs = [needs]
        if not isinstance(needs, list):
            errors.append(f"{path}: job {job_id} needs must be a string or list")
            needs = []
        for dependency in needs:
            if dependency not in jobs:
                errors.append(f"{path}: job {job_id} needs unknown job {dependency!r}")
        steps = job.get("steps")
        if not isinstance(steps, list) or not steps:
            errors.append(f"{path}: job {job_id} has no steps")
            continue
        for index, step in enumerate(steps, start=1):
            if not isinstance(step, dict):
                errors.append(f"{path}: job {job_id} step {index} must be a mapping")
                continue
            if str(step.get("continue-on-error", "")).lower() == "true":
                errors.append(
                    f"{path}: job {job_id} step {index} uses continue-on-error"
                )
            if "uses" not in step and "run" not in step:
                errors.append(f"{path}: job {job_id} step {index} has neither uses nor run")
    return errors


def main(argv: list[str]) -> int:
    if len(argv) > 1:
        files = [Path(item).resolve() for item in argv[1:]]
    else:
        files = iter_yaml_files()
    errors: list[str] = []
    if not files:
        print("YAML|FAIL|no YAML files found", file=sys.stderr)
        return 1
    for path in files:
        try:
            text = path.read_text(encoding="utf-8")
            data = yaml.load(text, Loader=UniqueKeyLoader)
        except yaml.YAMLError as exc:
            errors.append(f"{path}: YAML parse error: {exc}")
            continue
        except OSError as exc:
            errors.append(f"{path}: cannot read: {exc}")
            continue
        relative = path.relative_to(ROOT) if path.is_relative_to(ROOT) else path
        if "workflows" in path.parts:
            errors.extend(validate_workflow(relative, data))
        print(f"YAML|PARSED|{relative}")
    if errors:
        for error in errors:
            print(f"YAML|FAIL|{error}", file=sys.stderr)
        return 1
    print(f"YAML|PASS|files={len(files)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
