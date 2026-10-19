{ python3Packages, nix, cacert, makeWrapper, writeTextFile }:
let
  python = python3Packages.python.withPackages (ps: [ ps.mcp ]);
  serverSource = writeTextFile {
    name = "nix-mcp-source";
    destination = "/server.py";
    text = ''
    #!/usr/bin/env python3
    import argparse
    import asyncio
    import json
    import os
    import re
    import shutil
    import signal
    import sys
    import tempfile
    import time
    from pathlib import Path
    from typing import Any

    from mcp.server.lowlevel import Server
    from mcp.server.stdio import stdio_server
    from mcp.types import CallToolResult, TextContent, Tool

    ATTR = re.compile(r"^[A-Za-z_][A-Za-z0-9_-]*(\.[A-Za-z_][A-Za-z0-9_-]*)*$")
    SBT_TASK = re.compile(r"^([A-Za-z0-9_.-]+/)?([A-Z][A-Za-z0-9]*/)?(compile|test|testQuick|scalafixAll( --check)?|scalafmt|scalafmtAll|scalafmtCheckAll)$")
    CABAL_TARGET = re.compile(r"^(all|[A-Za-z0-9_][A-Za-z0-9_-]*(:[A-Za-z0-9_][A-Za-z0-9_-]*){0,2})$")
    RELATIVE_DIR = re.compile(r"^[A-Za-z0-9_-][A-Za-z0-9_.-]*(/[A-Za-z0-9_-][A-Za-z0-9_.-]*)*$")
    CONTROL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
    TOOLS = ("flake_metadata", "flake_show", "flake_check", "eval", "build", "develop", "run", "sbt", "cabal")
    LIMIT = 65536
    CLEANUP = 2.0
    MAX_TIMEOUT = 1800
    EMACS_INIT = "(progn (require (quote package)) (package-initialize) (require (quote merrinx-config)))"
    ELISP_PATHS = {"/tmp/org-planning-validation.el", "/tmp/org-roam-first-use.el"}


    class NixMcp:
        def __init__(self, config: dict[str, Any], nix: str):
            self.nix = str(Path(nix).resolve())
            self.roots: dict[str, str] = {}
            for raw in config["roots"]:
                if not isinstance(raw, str) or not Path(raw).is_absolute() or CONTROL.search(raw) or any(c in raw for c in "#?"):
                    raise ValueError("invalid root")
                path = Path(raw)
                canonical = str(path.resolve(strict=True))
                if canonical != raw or not path.is_dir() or not (path / "flake.nix").is_file():
                    raise ValueError("roots must be canonical flake directories")
                if canonical in self.roots.values():
                    raise ValueError("duplicate root")
                self.roots[raw] = canonical
            self.canonical = set(self.roots.values())
            parents = []
            for raw in config.get("rootParents", []):
                if not isinstance(raw, str) or not Path(raw).is_absolute() or CONTROL.search(raw) or any(c in raw for c in "#?"):
                    raise ValueError("invalid root parent")
                if str(Path(raw).resolve(strict=True)) != raw or not Path(raw).is_dir() or raw in parents:
                    raise ValueError("root parents must be unique canonical directories")
                parents.append(raw)
            self.parents = tuple(parents)
            cwd = str(Path.cwd().resolve())
            candidates = [root for root in self.canonical if cwd == root or cwd.startswith(root + os.sep)]
            self.active = max(candidates, key=len) if candidates else None
            self.locks: dict[str, asyncio.Lock] = {}

        def schema(self, tool: str) -> dict[str, Any]:
            if self.parents:
                root = {"type": "string", "maxLength": 4096, "description": "One of " + ", ".join(sorted(self.canonical)) + " or a canonical flake directory below " + ", ".join(self.parents)}
            else:
                root = {"type": "string", "enum": sorted(self.canonical)}
            props: dict[str, Any] = {"root": root, "timeoutSeconds": {"type": "integer", "minimum": 1, "maximum": MAX_TIMEOUT}}
            required: list[str] = []
            if tool == "eval":
                props["attribute"] = {"type": "string", "pattern": ATTR.pattern, "maxLength": 512}
                required = ["attribute"]
            if tool == "build":
                props["attributes"] = {"type": "array", "items": {"type": "string", "pattern": ATTR.pattern, "maxLength": 512}, "minItems": 1, "maxItems": 16, "uniqueItems": True}
                required = ["attributes"]
            if tool in {"build", "develop", "sbt", "cabal"}:
                props["devShell"] = {"type": "string", "pattern": ATTR.pattern, "maxLength": 512}
            if tool == "run":
                props["app"] = {"type": "string", "enum": ["test"]}
                props["emacsArguments"] = {"type": "array", "items": {"type": "string", "maxLength": 4096}, "minItems": 1, "maxItems": 64}
                required = ["app", "emacsArguments"]
            if tool == "sbt":
                props["tasks"] = {"type": "array", "items": {"type": "string", "pattern": SBT_TASK.pattern, "maxLength": 512}, "minItems": 1, "maxItems": 16}
                required = ["tasks"]
            if tool == "cabal":
                props["projectDir"] = {"type": "string", "pattern": RELATIVE_DIR.pattern, "maxLength": 512}
                props["command"] = {"type": "string", "enum": ["build", "test"]}
                props["targets"] = {"type": "array", "items": {"type": "string", "pattern": CABAL_TARGET.pattern, "maxLength": 512}, "minItems": 1, "maxItems": 16, "uniqueItems": True}
                required = ["command", "targets"]
            return {"type": "object", "properties": props, "required": required, "additionalProperties": False}

        def envelope(self, tool, root=None, attrs=(), status="ok", argv=(), exit_code=None, duration=0, out=None, err=None, parsed=False, data=None, error=None):
            blank = {"text": "", "capturedBytes": 0, "discardedBytes": 0, "truncated": False, "encodingValid": True}
            return {"schemaVersion": 1, "tool": tool, "root": root, "attributes": list(attrs), "status": status, "argv": list(argv), "exitCode": exit_code, "durationMs": duration, "stdout": out or blank, "stderr": err or blank, "jsonParsed": parsed, "data": data, "error": error}

        def root(self, args):
            if "root" not in args:
                if self.active is None:
                    return None, "root_required"
                canonical = self.active
            else:
                raw = args["root"]
                if not isinstance(raw, str) or not (raw in self.canonical or self.below_parent(raw)):
                    return None, "unauthorized_root"
                canonical = raw
            try:
                current = str(Path(canonical).resolve(strict=True))
            except OSError:
                return None, "root_changed"
            if current != canonical or CONTROL.search(current) or any(c in current for c in "#?") or not Path(current, "flake.nix").is_file():
                return None, "root_changed"
            return canonical, None

        def below_parent(self, raw):
            if len(raw) > 4096 or not Path(raw).is_absolute() or CONTROL.search(raw) or any(c in raw for c in "#?"):
                return False
            if not any(raw.startswith(parent + os.sep) for parent in self.parents):
                return False
            try:
                return str(Path(raw).resolve(strict=True)) == raw and Path(raw, "flake.nix").is_file()
            except OSError:
                return False

        @staticmethod
        def valid_emacs_arguments(args):
            if not isinstance(args, list) or not 1 <= len(args) <= 64 or any(not isinstance(arg, str) or len(arg) > 4096 or CONTROL.search(arg) for arg in args):
                return False
            index = 0
            if args[index] != "--batch":
                return False
            index += 1
            if index + 1 >= len(args) or args[index:index + 2] != ["--eval", EMACS_INIT]:
                return False
            index += 2
            if index + 1 >= len(args) or args[index] != "--load" or args[index + 1] not in ELISP_PATHS:
                return False
            index += 2
            if index < len(args):
                if args[index:] != ["--funcall", "ert-run-tests-batch-and-exit"]:
                    return False
                index += 2
            return index == len(args)

        def validate(self, tool, args):
            if not isinstance(args, dict):
                return None, (), "invalid_arguments"
            allowed = {"root", "timeoutSeconds"} | ({"attribute"} if tool == "eval" else set()) | ({"attributes"} if tool == "build" else set()) | ({"devShell"} if tool in {"build", "develop", "sbt", "cabal"} else set()) | ({"app", "emacsArguments"} if tool == "run" else set()) | ({"tasks"} if tool == "sbt" else set()) | ({"projectDir", "command", "targets"} if tool == "cabal" else set())
            if set(args) - allowed:
                return None, (), "invalid_arguments"
            if "root" in args and args["root"] is None:
                return None, (), "invalid_arguments"
            timeout = args.get("timeoutSeconds")
            if isinstance(timeout, bool) or (timeout is not None and (not isinstance(timeout, int) or not 1 <= timeout <= MAX_TIMEOUT)):
                return None, (), "invalid_arguments"
            if tool == "run":
                app = args.get("app")
                emacs_args = args.get("emacsArguments")
                if app != "test" or not self.valid_emacs_arguments(emacs_args):
                    return None, (), "invalid_arguments"
            shell = args.get("devShell")
            if shell is not None and (not isinstance(shell, str) or not ATTR.fullmatch(shell) or len(shell) > 512):
                return None, (), "invalid_arguments"
            attrs = [args.get("attribute")] if tool == "eval" else args.get("attributes", [])
            if tool == "eval" and (not isinstance(attrs[0], str) or not ATTR.fullmatch(attrs[0]) or len(attrs[0]) > 512):
                return None, (), "invalid_arguments"
            if tool == "build":
                if not isinstance(attrs, list) or not 1 <= len(attrs) <= 16:
                    return None, (), "invalid_arguments"
                if any(not isinstance(a, str) or not ATTR.fullmatch(a) or len(a) > 512 for a in attrs):
                    return None, (), "invalid_arguments"
                if len(set(attrs)) != len(attrs):
                    return None, (), "invalid_arguments"
            if tool == "sbt":
                attrs = args.get("tasks", [])
                if not isinstance(attrs, list) or not 1 <= len(attrs) <= 16:
                    return None, (), "invalid_arguments"
                if any(not isinstance(task, str) or not SBT_TASK.fullmatch(task) or len(task) > 512 for task in attrs):
                    return None, (), "invalid_arguments"
            if tool == "cabal":
                attrs = args.get("targets", [])
                if args.get("command") not in ("build", "test"):
                    return None, (), "invalid_arguments"
                if not isinstance(attrs, list) or not 1 <= len(attrs) <= 16 or any(not isinstance(t, str) or not CABAL_TARGET.fullmatch(t) or len(t) > 512 for t in attrs) or len(set(attrs)) != len(attrs):
                    return None, (), "invalid_arguments"
                project = args.get("projectDir")
                if project is not None and (not isinstance(project, str) or not RELATIVE_DIR.fullmatch(project) or len(project) > 512):
                    return None, (), "invalid_arguments"
            root, error = self.root(args)
            if error is None and tool == "cabal" and args.get("projectDir") is not None:
                try:
                    project = Path(root, args["projectDir"]).resolve(strict=True)
                except OSError:
                    return root, tuple(attrs), "invalid_arguments"
                if not str(project).startswith(root + os.sep) or not project.is_dir():
                    return root, tuple(attrs), "invalid_arguments"
            return root, tuple(attrs), error

        @staticmethod
        async def _drain(stream):
            data = bytearray()
            discarded = 0
            while True:
                chunk = await stream.read(8192)
                if not chunk:
                    break
                room = max(0, LIMIT - len(data))
                data.extend(chunk[:room])
                discarded += max(0, len(chunk) - room)
            raw = bytes(data)
            try:
                text = raw.decode("utf-8")
                encoding_valid = True
            except UnicodeDecodeError:
                text = raw.decode("utf-8", "replace")
                encoding_valid = False
            return {"text": text, "capturedBytes": len(data), "discardedBytes": discarded, "truncated": discarded > 0, "encodingValid": encoding_valid}

        async def _stop(self, process, tasks):
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                await asyncio.wait_for(asyncio.shield(process.wait()), CLEANUP)
            except asyncio.TimeoutError:
                pass
            drains = asyncio.gather(*tasks, return_exceptions=True)
            try:
                await asyncio.wait_for(asyncio.shield(drains), CLEANUP)
            except asyncio.TimeoutError:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            try:
                await asyncio.wait_for(asyncio.shield(process.wait()), CLEANUP)
            except asyncio.TimeoutError:
                pass
            try:
                await asyncio.wait_for(asyncio.shield(drains), CLEANUP)
            except asyncio.TimeoutError:
                for task in tasks:
                    if not task.done():
                        task.cancel()
                await asyncio.gather(*tasks, return_exceptions=True)

        async def _cleanup(self, process, tasks):
            cleanup = asyncio.create_task(self._stop(process, tasks))
            try:
                await asyncio.shield(cleanup)
            except asyncio.CancelledError:
                await asyncio.shield(cleanup)
                raise

        async def execute(self, tool, args):
            started = time.monotonic()
            root, attrs, invalid = self.validate(tool, args)
            if invalid:
                return self.envelope(tool, root, attrs, invalid, duration=int((time.monotonic() - started) * 1000), error={"message": invalid})
            timeout = args.get("timeoutSeconds", {"flake_metadata": 30, "flake_show": 60, "flake_check": 600, "eval": 60, "build": 600, "develop": 60, "run": 600, "sbt": 600, "cabal": 600}[tool])
            lock = self.locks.setdefault(root, asyncio.Lock())
            await lock.acquire()
            process = None
            tasks = []
            temp = None
            try:
                prefix = [self.nix, "--option", "pure-eval", "true", "--option", "accept-flake-config", "false", "--option", "use-registries", "false", "--option", "allow-import-from-derivation", "true", "--option", "sandbox", "true"]
                locks = ["--no-update-lock-file", "--no-write-lock-file"]
                target = root + ("#" + args["devShell"] if args.get("devShell") else "")
                if tool == "flake_metadata": argv = prefix + ["flake", "metadata", "--json"] + locks + [root]
                elif tool == "flake_show": argv = prefix + ["flake", "show", "--json"] + locks + [root]
                elif tool == "flake_check": argv = prefix + ["flake", "check", "--keep-going"] + locks + [root]
                elif tool == "eval": argv = prefix + ["eval", "--json"] + locks + [root + "#" + attrs[0]]
                elif tool == "build": argv = prefix + ["develop"] + locks + [target, "--command"] + prefix + ["build", "--json", "--no-link"] + locks + [root + "#" + a for a in attrs]
                elif tool == "develop": argv = prefix + ["develop"] + locks + [target, "--command", "true"]
                elif tool == "run": argv = prefix + ["run"] + locks + [root + "#" + args["app"], "--", *args["emacsArguments"]]
                elif tool == "cabal":
                    project = ["--project-dir=" + args["projectDir"]] if args.get("projectDir") is not None else []
                    details = ["--test-show-details=streaming"] if args["command"] == "test" else []
                    argv = prefix + ["develop"] + locks + [target, "--command", "cabal", *project, args["command"], *attrs, *details]
                else: argv = prefix + ["develop"] + locks + [target, "--command", "sbtn", *attrs]
                temp = tempfile.mkdtemp(prefix="nix-mcp-")
                env = {"PATH": os.path.dirname(self.nix), "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8", "GIT_TERMINAL_PROMPT": "0"}
                for key in ("HOME", "TMPDIR", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME", "NIX_USER_CONF_FILES"):
                    env[key] = temp
                env["NIX_SSL_CERT_FILE"] = "__CACERT__"
                process = await asyncio.create_subprocess_exec(*argv, cwd=root, env=env, stdin=asyncio.subprocess.DEVNULL, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, start_new_session=True)
                tasks = [asyncio.create_task(self._drain(process.stdout)), asyncio.create_task(self._drain(process.stderr))]
                status = "ok"
                try:
                    await asyncio.wait_for(asyncio.shield(process.wait()), timeout)
                except asyncio.TimeoutError:
                    status = "timeout"
                except asyncio.CancelledError:
                    await self._cleanup(process, tasks)
                    raise
                finally:
                    try:
                        await self._cleanup(process, tasks)
                    except Exception:
                        if status != "timeout":
                            raise
                results = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), CLEANUP)
                blank = {"text": "", "capturedBytes": 0, "discardedBytes": 0, "truncated": False, "encodingValid": True}
                out, err = [value if isinstance(value, dict) else blank for value in results]
                code = process.returncode
                if status == "ok" and code != 0: status = "execution_error"
                elif status == "ok" and (out["truncated"] or err["truncated"]): status = "truncated"
                elif status == "ok" and (not out["encodingValid"] or not err["encodingValid"]): status = "invalid_output"
                if status == "ok" and tool in {"flake_check", "develop", "run", "sbt", "cabal"}:
                    data = None; parsed = False
                else:
                    data = None; parsed = False
                    if status == "ok":
                        # Dev shell hooks may print to stdout before nix build emits its single JSON line.
                        text = (out["text"].strip().splitlines() or [""])[-1] if tool == "build" else out["text"]
                        try: data = json.loads(text); parsed = True
                        except json.JSONDecodeError: status = "invalid_output"
                return self.envelope(tool, root, attrs, status, argv, code, int((time.monotonic() - started) * 1000), out, err, parsed, data, None if status == "ok" else {"message": status})
            except asyncio.CancelledError:
                if process is not None:
                    await self._cleanup(process, tasks)
                raise
            except Exception as exc:
                if process is not None:
                    await self._cleanup(process, tasks)
                return self.envelope(tool, root, attrs, "execution_error", duration=int((time.monotonic() - started) * 1000), error={"message": str(exc)})
            finally:
                if temp: shutil.rmtree(temp, ignore_errors=True)
                lock.release()


    def make_server(app):
        server = Server("nix-mcp")
        @server.list_tools()
        async def list_tools():
            return [Tool(name=t, description="Safe Nix operation", inputSchema=app.schema(t)) for t in TOOLS]
        @server.call_tool(validate_input=False)
        async def call_tool(name: str, arguments: dict):
            result = app.envelope(name, status="invalid_arguments", error={"message": "unknown tool"}) if name not in TOOLS else await app.execute(name, arguments or {})
            return CallToolResult(content=[TextContent(type="text", text=json.dumps(result, separators=(",", ":")))], isError=result["status"] != "ok")
        return server


    async def main(config, nix):
        app = NixMcp(config, nix)
        server = make_server(app)
        async with stdio_server() as streams:
            await server.run(streams[0], streams[1], server.create_initialization_options())


    def cli():
        parser = argparse.ArgumentParser()
        parser.add_argument("--config", required=True)
        ns = parser.parse_args()
        with open(ns.config, encoding="utf-8") as f: config = json.load(f)
        if not {"roots"} <= set(config) <= {"roots", "rootParents"} or not config["roots"]:
            raise SystemExit("invalid config")
        for key in ("roots", "rootParents"):
            values = config.get(key, [])
            if not isinstance(values, list) or any(not isinstance(x, str) or not x for x in values) or len(set(values)) != len(values):
                raise SystemExit("invalid config")
        asyncio.run(main(config, "__PACKAGED_NIX__"))


    if __name__ == "__main__": cli()
    '';
  };
in
python3Packages.buildPythonApplication {
  pname = "nix-mcp";
  version = "0.1.0";
  pyproject = false;
  src = serverSource;
  propagatedBuildInputs = [ python3Packages.mcp ];
  dontUnpack = false;
  installPhase = ''
    install -Dm755 server.py $out/libexec/nix-mcp/server.py
    substituteInPlace $out/libexec/nix-mcp/server.py \
      --replace-fail '"__PACKAGED_NIX__"' '"${nix}/bin/nix"' \
      --replace-fail '"__CACERT__"' '"${cacert}/etc/ssl/certs/ca-bundle.crt"'
    makeWrapper ${python.interpreter} $out/bin/nix-mcp \
      --add-flags "$out/libexec/nix-mcp/server.py"
  '';
  nativeBuildInputs = [ makeWrapper ];
  passthru.python = python3Packages.python;
  meta.mainProgram = "nix-mcp";
}
