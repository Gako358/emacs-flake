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
    CONTROL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
    TOOLS = ("flake_metadata", "flake_show", "flake_check", "eval", "build")
    LIMIT = 65536
    CLEANUP = 2.0


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
            cwd = str(Path.cwd().resolve())
            candidates = [root for root in self.canonical if cwd == root or cwd.startswith(root + os.sep)]
            self.active = max(candidates, key=len) if candidates else None
            self.lock = asyncio.Lock()

        def schema(self, tool: str) -> dict[str, Any]:
            root = {"type": "string", "enum": sorted(self.canonical)}
            props: dict[str, Any] = {"root": root, "timeoutSeconds": {"type": "integer", "minimum": 1, "maximum": 110}}
            required: list[str] = []
            if tool == "eval":
                props["attribute"] = {"type": "string", "pattern": ATTR.pattern, "maxLength": 512}
                required = ["attribute"]
            if tool == "build":
                props["attributes"] = {"type": "array", "items": {"type": "string", "pattern": ATTR.pattern, "maxLength": 512}, "minItems": 1, "maxItems": 16, "uniqueItems": True}
                required = ["attributes"]
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
                if not isinstance(raw, str) or raw not in self.canonical:
                    return None, "unauthorized_root"
                canonical = raw
            try:
                current = str(Path(canonical).resolve(strict=True))
            except OSError:
                return None, "root_changed"
            if current != canonical or CONTROL.search(current) or any(c in current for c in "#?") or not Path(current, "flake.nix").is_file():
                return None, "root_changed"
            return canonical, None

        def validate(self, tool, args):
            if not isinstance(args, dict):
                return None, (), "invalid_arguments"
            allowed = {"root", "timeoutSeconds"} | ({"attribute"} if tool == "eval" else set()) | ({"attributes"} if tool == "build" else set())
            if set(args) - allowed:
                return None, (), "invalid_arguments"
            if "root" in args and args["root"] is None:
                return None, (), "invalid_arguments"
            timeout = args.get("timeoutSeconds")
            if isinstance(timeout, bool) or (timeout is not None and (not isinstance(timeout, int) or not 1 <= timeout <= 110)):
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
            root, error = self.root(args)
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
            timeout = args.get("timeoutSeconds", {"flake_metadata": 30, "flake_show": 60, "flake_check": 110, "eval": 60, "build": 110}[tool])
            if self.lock.locked():
                return self.envelope(tool, root, attrs, "busy", error={"message": "busy"})
            await self.lock.acquire()
            process = None
            tasks = []
            temp = None
            try:
                prefix = [self.nix, "--option", "pure-eval", "true", "--option", "accept-flake-config", "false", "--option", "use-registries", "false", "--option", "allow-import-from-derivation", "false", "--option", "sandbox", "true"]
                locks = ["--no-update-lock-file", "--no-write-lock-file"]
                if tool == "flake_metadata": argv = prefix + ["flake", "metadata", "--json"] + locks + [root]
                elif tool == "flake_show": argv = prefix + ["flake", "show", "--json"] + locks + [root]
                elif tool == "flake_check": argv = prefix + ["flake", "check", "--keep-going"] + locks + [root]
                elif tool == "eval": argv = prefix + ["eval", "--json"] + locks + [root + "#" + attrs[0]]
                else: argv = prefix + ["build", "--json", "--no-link"] + locks + [root + "#" + a for a in attrs]
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
                if status == "ok" and tool == "flake_check":
                    data = None; parsed = False
                else:
                    data = None; parsed = False
                    if status == "ok":
                        try: data = json.loads(out["text"]); parsed = True
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
                self.lock.release()


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
        if set(config) != {"roots"} or not isinstance(config["roots"], list) or not config["roots"] or any(not isinstance(x, str) or not x for x in config["roots"]) or len(set(config["roots"])) != len(config["roots"]):
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
