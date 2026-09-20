{ runCommand, writeText, writeTextFile, python3Packages, nix-mcp, nix, cacert }:
let
  python = python3Packages.python.withPackages (ps: [ ps.mcp ]);
  fakeNixText = ''
    import json
    import os
    import signal
    import subprocess
    import sys
    import time
    from pathlib import Path


    def load_config(root):
        path = Path(root) / ".nix-mcp-test.json"
        if not path.is_file():
            return {}
        return json.loads(path.read_text(encoding="utf-8"))


    def record(root, argv, stdin_eof):
        path = Path(root) / ".nix-mcp-invocations.jsonl"
        item = {"argv": argv, "cwd": os.getcwd(), "environment": dict(sorted(os.environ.items())),
                "stdin_eof": stdin_eof, "pid": os.getpid(), "pgid": os.getpgid(0)}
        with path.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(item, sort_keys=True) + "\n")


    def main():
        root = os.getcwd()
        config = load_config(root)
        mode = config.get("mode", "json")
        argv = sys.argv[1:]
        record(root, argv, True)
        if mode == "wait":
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            time.sleep(float(config.get("seconds", 120)))
        elif mode == "term-resistant":
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(120)"])
            (Path(root) / ".nix-mcp-descendant").write_text(str(child.pid))
            time.sleep(120)
        elif mode == "parent-exits":
            child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(120)"])
            (Path(root) / ".nix-mcp-descendant").write_text(str(child.pid))
            return 0
        elif mode == "invalid-utf8":
            sys.stdout.buffer.write(b"\xff\xfe")
            return 0
        elif mode == "invalid-json-utf8":
            sys.stdout.buffer.write(b'{"value":"\xff"}')
            return 0
        elif mode == "text":
            print("not json")
            return 0
        elif mode == "nonzero":
            print("failure", file=sys.stderr)
            return int(config.get("code", 17))
        elif mode in {"stdout-flood", "stderr-flood", "both-flood"}:
            if mode in {"stdout-flood", "both-flood"}:
                sys.stdout.write("x" * 100000)
            if mode in {"stderr-flood", "both-flood"}:
                sys.stderr.write("y" * 100000)
            return int(config.get("code", 0))
        elif mode == "partial":
            sys.stdout.write('{"partial":')
            return 0
        else:
            json.dump(config.get("result", {"ok": True}), sys.stdout, separators=(",", ":"))
            sys.stdout.write("\n")
        return 0


    if __name__ == "__main__":
        raise SystemExit(main())
  '';
  fakeNixSource = writeText "fake_nix.py" fakeNixText;
  fakeNix = writeTextFile {
    name = "nix-mcp-test-nix";
    destination = "/bin/nix";
    executable = true;
    text = "#!${python.interpreter}\n${fakeNixText}";
  };
  testServerSource = writeTextFile {
    name = "nix-mcp-testServerSource";
    text = ''
    import asyncio
    import json
    import os
    import signal
    import stat
    import sys
    import tempfile
    import unittest
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).parents[1]))
    from server import LIMIT, NixMcp


    class ServerTests(unittest.IsolatedAsyncioTestCase):
        async def asyncSetUp(self):
            self.d = tempfile.TemporaryDirectory()
            self.p = Path(self.d.name)
            (self.p / "flake.nix").write_text("{}")
            source = Path(__file__).with_name("fake_nix.py")
            self.fake = self.p / "fake-nix"
            self.fake.write_text(f"#!{sys.executable}\n" + source.read_text())
            self.fake.chmod(self.fake.stat().st_mode | stat.S_IXUSR)
            self.app = NixMcp({"roots": [str(self.p)]}, str(self.fake))

        async def asyncTearDown(self):
            self.d.cleanup()

        def config(self, value):
            (self.p / ".nix-mcp-test.json").write_text(json.dumps(value))

        def records(self):
            return [json.loads(line) for line in (self.p / ".nix-mcp-invocations.jsonl").read_text().splitlines()]

        async def test_all_commands_exact_invocations_and_environment(self):
            root = str(self.p)
            cases = {
                "flake_metadata": {},
                "flake_show": {},
                "flake_check": {},
                "eval": {"attribute": "packages.x86_64-linux.nix-mcp"},
                "build": {"attributes": ["packages.x86_64-linux.nix-mcp", "checks.x86_64-linux.nix-mcp"]},
                "develop": {"devShell": "ci"},
                "sbt": {"devShell": "ci", "tasks": ["scalafixAll", "core/test", "scalafmtAll"]},
            }
            expected = {
                "flake_metadata": ["--option", "pure-eval", "true", "--option", "accept-flake-config", "false", "--option", "use-registries", "false", "--option", "allow-import-from-derivation", "false", "--option", "sandbox", "true", "flake", "metadata", "--json", "--no-update-lock-file", "--no-write-lock-file", root],
                "flake_show": ["--option", "pure-eval", "true", "--option", "accept-flake-config", "false", "--option", "use-registries", "false", "--option", "allow-import-from-derivation", "false", "--option", "sandbox", "true", "flake", "show", "--json", "--no-update-lock-file", "--no-write-lock-file", root],
                "flake_check": ["--option", "pure-eval", "true", "--option", "accept-flake-config", "false", "--option", "use-registries", "false", "--option", "allow-import-from-derivation", "false", "--option", "sandbox", "true", "flake", "check", "--keep-going", "--no-update-lock-file", "--no-write-lock-file", root],
                "eval": ["--option", "pure-eval", "true", "--option", "accept-flake-config", "false", "--option", "use-registries", "false", "--option", "allow-import-from-derivation", "false", "--option", "sandbox", "true", "eval", "--json", "--no-update-lock-file", "--no-write-lock-file", root + "#packages.x86_64-linux.nix-mcp"],
                "build": ["--option", "pure-eval", "true", "--option", "accept-flake-config", "false", "--option", "use-registries", "false", "--option", "allow-import-from-derivation", "false", "--option", "sandbox", "true", "build", "--json", "--no-link", "--no-update-lock-file", "--no-write-lock-file", root + "#packages.x86_64-linux.nix-mcp", root + "#checks.x86_64-linux.nix-mcp"],
                "develop": ["--option", "pure-eval", "true", "--option", "accept-flake-config", "false", "--option", "use-registries", "false", "--option", "allow-import-from-derivation", "false", "--option", "sandbox", "true", "develop", "--no-update-lock-file", "--no-write-lock-file", root + "#ci", "--command", "true"],
                "sbt": ["--option", "pure-eval", "true", "--option", "accept-flake-config", "false", "--option", "use-registries", "false", "--option", "allow-import-from-derivation", "false", "--option", "sandbox", "true", "develop", "--no-update-lock-file", "--no-write-lock-file", root + "#ci", "--command", "sbtn", "scalafixAll", "core/test", "scalafmtAll"],
            }
            for tool, extra in cases.items():
                result = await self.app.execute(tool, {"root": root, **extra})
                self.assertEqual(result["status"], "ok", tool)
                record = self.records()[-1]
                self.assertEqual(record["argv"], expected[tool])
                self.assertEqual(record["cwd"], root)
                self.assertTrue(record["stdin_eof"])
                self.assertEqual(set(record["environment"]), {"GIT_TERMINAL_PROMPT", "HOME", "LANG", "LC_ALL", "NIX_SSL_CERT_FILE", "NIX_USER_CONF_FILES", "PATH", "PYTHONNOUSERSITE", "TMPDIR", "XDG_CACHE_HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME"})
                self.assertEqual(record["environment"]["NIX_SSL_CERT_FILE"], "__CACERT__")
                self.assertFalse(Path(record["environment"]["TMPDIR"]).exists())

        async def test_null_root_and_malformed_shapes_never_spawn(self):
            invalid = [({"root": None}, "invalid_arguments"), ({"root": [], "attribute": "a"}, "unauthorized_root"), ({"root": str(self.p), "attribute": []}, "invalid_arguments"), ({"root": str(self.p), "attributes": ["a", "a"]}, "invalid_arguments"), ({"root": str(self.p), "tasks": ["clean"]}, "invalid_arguments"), ({"root": str(self.p), "tasks": ["test;bad"]}, "invalid_arguments"), ({"root": str(self.p), "devShell": "bad#shell"}, "invalid_arguments"), ({"root": str(self.p), "timeoutSeconds": 0}, "invalid_arguments"), ({"root": str(self.p), "unknown": 1}, "invalid_arguments")]
            for args, expected in invalid:
                result = await self.app.execute("eval" if "attribute" in args else "build" if "attributes" in args else "sbt" if "tasks" in args else "develop" if "devShell" in args else "flake_metadata", args)
                self.assertEqual(result["status"], expected)
            self.assertFalse((self.p / ".nix-mcp-invocations.jsonl").exists())

        async def test_output_status_matrix(self):
            for mode, expected in (("json", "ok"), ("text", "invalid_output"), ("invalid-utf8", "invalid_output"), ("invalid-json-utf8", "invalid_output"), ("stdout-flood", "truncated"), ("stderr-flood", "truncated"), ("both-flood", "truncated"), ("nonzero", "execution_error"), ("partial", "invalid_output")):
                self.config({"mode": mode, "code": 9 if mode == "nonzero" else 0})
                result = await self.app.execute("flake_metadata", {"root": str(self.p), "timeoutSeconds": 1})
                self.assertEqual(result["status"], expected, mode)
                self.assertLessEqual(result["stdout"]["capturedBytes"], LIMIT)
                self.assertLessEqual(result["stderr"]["capturedBytes"], LIMIT)
                self.assertEqual(result["status"] == "ok", result["error"] is None)
            self.config({"mode": "invalid-json-utf8"})
            result = await self.app.execute("flake_metadata", {"root": str(self.p)})
            self.assertFalse(result["jsonParsed"])
            self.assertIsNone(result["data"])
            self.assertTrue(result["error"])
            self.assertTrue(result["status"] != "ok")
            self.assertFalse(result["stdout"]["encodingValid"])
            self.assertTrue(result["stdout"]["text"])
            self.config({"mode": "wait"})
            result = await self.app.execute("flake_metadata", {"root": str(self.p), "timeoutSeconds": 1})
            self.assertEqual(result["status"], "timeout")

        async def test_busy_cancellation_and_reuse(self):
            self.config({"mode": "wait"})
            first = asyncio.create_task(self.app.execute("flake_metadata", {"root": str(self.p), "timeoutSeconds": 10}))
            await asyncio.sleep(.1)
            busy = await self.app.execute("flake_show", {"root": str(self.p)})
            self.assertEqual(busy["status"], "busy")
            first.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await first
            self.config({"mode": "json"})
            self.assertEqual((await self.app.execute("flake_metadata", {"root": str(self.p) }))[
                "status"], "ok")

        async def test_parent_exits_first_and_term_resistant_descendants_are_cleaned(self):
            for mode in ("term-resistant", "parent-exits"):
                self.config({"mode": mode})
                result = await self.app.execute("flake_metadata", {"root": str(self.p), "timeoutSeconds": 1})
                self.assertEqual(result["status"], "timeout" if mode == "term-resistant" else "invalid_output")
                marker = self.p / ".nix-mcp-descendant"
                if marker.exists():
                    pid = int(marker.read_text())
                    with self.assertRaises(ProcessLookupError):
                        os.kill(pid, 0)
                    marker.unlink()
                self.assertFalse(marker.exists())
            self.config({"mode": "json"})
            self.assertEqual((await self.app.execute("flake_metadata", {"root": str(self.p)}))["status"], "ok")

        def test_validation_and_schema(self):
            schema = self.app.schema("build")
            self.assertFalse(schema["additionalProperties"])
            self.assertEqual(self.app.validate("eval", {"attribute": "a", "timeoutSeconds": True})[2], "invalid_arguments")
            self.assertEqual(self.app.validate("build", {"attributes": ["a", "a"]})[2], "invalid_arguments")
            self.assertEqual(self.app.validate("eval", {"attribute": "a;bad"})[2], "invalid_arguments")
            self.assertEqual(self.app.validate("sbt", {"root": str(self.p), "tasks": ["compile", "testQuick", "scalafixAll --check", "core/scalafmtCheckAll"]})[2], None)
            self.assertEqual(self.app.validate("sbt", {"root": str(self.p), "tasks": ["clean"]})[2], "invalid_arguments")


    if __name__ == "__main__":
        unittest.main()
'';
  };
  testProtocolSource = writeTextFile {
    name = "nix-mcp-testProtocolSource";
    text = ''
    import asyncio
    import json
    import os
    import shutil
    import tempfile
    import unittest
    from pathlib import Path


    class JsonRpcClient:
        def __init__(self, process):
            self.process = process
            self.ident = 0

        async def request(self, method, params=None):
            self.ident += 1
            ident = self.ident
            line = {"jsonrpc": "2.0", "id": ident, "method": method}
            if params is not None:
                line["params"] = params
            self.process.stdin.write((json.dumps(line, separators=(",", ":")) + "\n").encode())
            await self.process.stdin.drain()
            while True:
                raw = await asyncio.wait_for(self.process.stdout.readline(), 5)
                self.assert_line(raw)
                message = json.loads(raw)
                if message.get("id") == ident:
                    return message

        async def notification(self, method, params=None):
            line = {"jsonrpc": "2.0", "method": method}
            if params is not None:
                line["params"] = params
            self.process.stdin.write((json.dumps(line, separators=(",", ":")) + "\n").encode())
            await self.process.stdin.drain()

        @staticmethod
        def assert_line(raw):
            if not raw:
                raise AssertionError("server closed stdout")
            if len(raw) > 2 * 1024 * 1024:
                raise AssertionError("oversized protocol line")


    class ProtocolTests(unittest.IsolatedAsyncioTestCase):
        async def launch(self, production=False):
            root = Path(tempfile.mkdtemp(prefix="nix-mcp-protocol-"))
            (root / "flake.nix").write_text("{}")
            config = root / "config.json"
            config.write_text(json.dumps({"roots": [str(root)]}, separators=(",", ":")))
            executable = os.environ["NIX_MCP_PRODUCTION_SERVER" if production else "NIX_MCP_TEST_SERVER"]
            process = await asyncio.create_subprocess_exec(
                executable, "--config", str(config), stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
                limit=2 * 1024 * 1024)
            return root, process, JsonRpcClient(process)

        async def finish(self, root, process):
            if process.stdin and not process.stdin.is_closing():
                process.stdin.close()
            natural_error = None
            try:
                await asyncio.wait_for(process.wait(), 2)
            except asyncio.TimeoutError as error:
                natural_error = error
            finally:
                if natural_error is not None:
                    process.terminate()
                    try:
                        await asyncio.wait_for(process.wait(), 2)
                    except asyncio.TimeoutError:
                        process.kill()
                        await asyncio.wait_for(process.wait(), 2)
            stderr = await asyncio.wait_for(process.stderr.read(4097), 1)
            self.assertLessEqual(len(stderr), 4096)
            if natural_error is not None:
                self.fail("server did not exit naturally after stdin EOF")
            self.assertIsNotNone(process.returncode)
            marker = root / ".nix-mcp-descendant"
            if marker.exists():
                pid = int(marker.read_text())
                with self.assertRaises(ProcessLookupError):
                    os.kill(pid, 0)
            shutil.rmtree(root)

        async def test_installed_server_protocol_and_cancellation(self):
            root, process, client = await self.launch()
            try:
                initialized = await client.request("initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "test", "version": "1"}})
                self.assertEqual(initialized["result"]["protocolVersion"], "2025-11-25")
                await client.notification("notifications/initialized")
                self.assertIn("result", await client.request("ping"))
                listed = (await client.request("tools/list"))["result"]["tools"]
                self.assertEqual({tool["name"] for tool in listed}, {"flake_metadata", "flake_show", "flake_check", "eval", "build", "develop", "sbt"})
                for tool in listed:
                    self.assertEqual(tool["inputSchema"]["type"], "object")
                    self.assertIn("root", tool["inputSchema"]["properties"])
                    self.assertFalse(tool["inputSchema"]["additionalProperties"])
                good = await client.request("tools/call", {"name": "flake_metadata", "arguments": {"root": str(root)}})
                content = json.loads(good["result"]["content"][0]["text"])
                self.assertEqual(content["schemaVersion"], 1)
                self.assertFalse(good["result"]["isError"])
                (root / ".nix-mcp-test.json").write_text(json.dumps({"mode": "invalid-json-utf8"}))
                malformed = await client.request("tools/call", {"name": "flake_metadata", "arguments": {"root": str(root)}})
                malformed_content = json.loads(malformed["result"]["content"][0]["text"])
                self.assertEqual(malformed_content["status"], "invalid_output")
                self.assertFalse(malformed_content["jsonParsed"])
                self.assertIsNone(malformed_content["data"])
                self.assertTrue(malformed["result"]["isError"])
                bad = await client.request("tools/call", {"name": "eval", "arguments": {"root": str(root), "attribute": "bad;input"}})
                self.assertTrue(bad["result"]["isError"])
                self.assertEqual(json.loads(bad["result"]["content"][0]["text"])["status"], "invalid_arguments")
                (root / ".nix-mcp-test.json").write_text(json.dumps({"mode": "wait"}))
                request_id = client.ident + 1
                request = asyncio.create_task(client.request("tools/call", {"name": "flake_metadata", "arguments": {"root": str(root)}}))
                await asyncio.sleep(.2)
                await client.notification("notifications/cancelled", {"requestId": request_id})
                cancelled = await asyncio.wait_for(request, 2)
                self.assertEqual(cancelled, {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {"code": 0, "message": "Request cancelled"},
                })
                self.assertIn("result", await client.request("ping"))
            finally:
                await self.finish(root, process)

        async def test_active_eof_exits(self):
            root, process, client = await self.launch()
            try:
                await client.request("initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "test", "version": "1"}})
                await client.notification("notifications/initialized")
            finally:
                await self.finish(root, process)

        async def test_production_initialize_list_ping_invalid_and_eof(self):
            root, process, client = await self.launch(production=True)
            try:
                await client.request("initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "test", "version": "1"}})
                await client.notification("notifications/initialized")
                self.assertIn("tools", (await client.request("tools/list"))["result"])
                self.assertIn("result", await client.request("ping"))
                bad = await client.request("tools/call", {"name": "eval", "arguments": {"root": str(root), "attribute": "bad;input"}})
                self.assertTrue(bad["result"]["isError"])
            finally:
                await self.finish(root, process)


    if __name__ == "__main__":
        unittest.main()
'';
  };
  testServer = nix-mcp.override { nix = fakeNix; };
  testSource = runCommand "nix-mcp-test-source" {} ''
    mkdir -p $out/tests
    cp ${nix-mcp.src}/server.py $out/server.py
    cp ${fakeNixSource} $out/tests/fake_nix.py
    cp ${testServerSource} $out/tests/test_server.py
    cp ${testProtocolSource} $out/tests/test_protocol.py
  '';
in
runCommand "nix-mcp-check" {
  src = testSource;
  nativeBuildInputs = [ python nix-mcp testServer ];
} ''
  export PYTHONDONTWRITEBYTECODE=1
  export PYTHONPATH=$src
  export NIX_MCP_TEST_PYTHON=${python.interpreter}
  export NIX_MCP_TEST_NIX=${fakeNix}/bin/nix
  export NIX_MCP_TEST_SERVER=${testServer}/bin/nix-mcp
  export NIX_MCP_PRODUCTION_SERVER=${nix-mcp}/bin/nix-mcp
  export NIX_MCP_EXPECTED_NIX=${nix}/bin/nix
  export NIX_MCP_EXPECTED_CACERT=${cacert}/etc/ssl/certs/ca-bundle.crt
  help="$(${nix-mcp}/bin/nix-mcp --help)"
  printf '%s\n' "$help" | grep -F -- '--config CONFIG'
  if printf '%s\n' "$help" | grep -E -- '--(nix|fake|override|root)'; then
    echo 'unexpected public option' >&2
    exit 1
  fi
  ${python.interpreter} -B -c 'import importlib.metadata, mcp; assert importlib.metadata.version("mcp") == "1.29.0"'
  test_log=$(mktemp)
  if ! ${python.interpreter} -B -m unittest discover -s $src/tests -v 2>&1 | tee "$test_log"; then
    exit 1
  fi
  if grep -E '(^| )[0-9]+ skipped|skipped ' "$test_log"; then
    echo 'skipped tests are not allowed' >&2
    exit 1
  fi
  touch $out
''
