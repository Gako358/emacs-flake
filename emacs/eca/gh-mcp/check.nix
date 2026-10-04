{ runCommand, writeText, writeTextFile, python3Packages, gh-mcp, gh, cacert }:
let
  python = python3Packages.python.withPackages (ps: [ ps.mcp ]);
  fakeGhText = ''
    import json
    import os
    import signal
    import sys
    import time
    from pathlib import Path


    def main():
        home = Path(os.environ["HOME"])
        config_path = home / ".gh-mcp-test.json"
        config = json.loads(config_path.read_text()) if config_path.is_file() else {}
        stdin = sys.stdin.read()
        item = {"argv": sys.argv[1:], "cwd": os.getcwd(), "environment": dict(sorted(os.environ.items())), "stdin": stdin}
        with (home / ".gh-mcp-invocations.jsonl").open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(item, sort_keys=True) + "\n")
        mode = config.get("mode", "json")
        if mode == "wait":
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            time.sleep(120)
        elif mode == "nonzero":
            print("failure", file=sys.stderr)
            return 4
        elif mode == "text":
            print(config.get("text", "not json"))
        elif mode == "flood":
            sys.stdout.write("x" * 300000)
        else:
            json.dump(config.get("result", {"ok": True}), sys.stdout)
        return 0


    if __name__ == "__main__":
        raise SystemExit(main())
  '';
  fakeGhSource = writeText "fake_gh.py" fakeGhText;
  fakeGh = writeTextFile {
    name = "gh-mcp-test-gh";
    destination = "/bin/gh";
    executable = true;
    text = "#!${python.interpreter}\n${fakeGhText}";
  };
  testServerSource = writeText "test_server.py" ''
    import asyncio
    import json
    import os
    import stat
    import sys
    import tempfile
    import unittest
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).parents[1]))
    from server import SPECS, TOOLS, GhMcp

    EXPECTED_ENV = {"HOME", "GH_TOKEN", "PATH", "LANG", "LC_ALL", "TMPDIR", "GH_HOST", "GH_PROMPT_DISABLED", "GH_NO_UPDATE_NOTIFIER", "GH_NO_EXTENSION_UPDATE_NOTIFIER", "GH_SPINNER_DISABLED", "NO_COLOR", "GIT_TERMINAL_PROMPT", "SSL_CERT_FILE"}
    URL = "https://github.com/acme/app/issues/7"


    class ServerTests(unittest.IsolatedAsyncioTestCase):
        async def asyncSetUp(self):
            self.d = tempfile.TemporaryDirectory()
            self.home = Path(self.d.name)
            self.saved = dict(os.environ)
            os.environ.clear()
            os.environ.update({"HOME": str(self.home), "GH_TOKEN": "test-token", "UNRELATED_SECRET": "leak", "GH_HOST": "evil.example"})
            self.fake = self.home / "bin" / "gh"
            self.fake.parent.mkdir()
            self.fake.write_text(f"#!{sys.executable}\n" + Path(__file__).with_name("fake_gh.py").read_text())
            self.fake.chmod(self.fake.stat().st_mode | stat.S_IXUSR)
            self.app = GhMcp({"owners": ["acme", "Team-X"]}, str(self.fake))

        async def asyncTearDown(self):
            os.environ.clear()
            os.environ.update(self.saved)
            self.d.cleanup()

        def config(self, value):
            (self.home / ".gh-mcp-test.json").write_text(json.dumps(value))

        def records(self):
            path = self.home / ".gh-mcp-invocations.jsonl"
            return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

        async def test_exact_invocations_stdin_and_environment(self):
            cases = [
                ("issue_list", {"repo": "acme/app", "labels": ["bug", "help wanted"], "milestone": "Sprint 3", "search": "no:assignee", "state": "all", "limit": 5},
                 ["issue", "list", "--repo=acme/app", "--state=all", "--limit=5", "--json=number,title,state,labels,assignees,milestone,url,updatedAt", "--label=bug", "--label=help wanted", "--milestone=Sprint 3", "--search=no:assignee"], ""),
                ("issue_view", {"repo": "acme/app", "number": 7},
                 ["issue", "view", "7", "--repo=acme/app", "--json=number,title,body,state,stateReason,labels,assignees,milestone,issueType,parent,subIssues,subIssuesSummary,projectItems,url"], ""),
                ("label_list", {"repo": "acme/app"}, ["label", "list", "--repo=acme/app", "--limit=100", "--json=name,description,color"], ""),
                ("milestone_list", {"repo": "acme/app", "state": "closed"}, ["api", "repos/acme/app/milestones?state=closed&per_page=100"], ""),
                ("project_list", {"owner": "team-x", "closed": True}, ["project", "list", "--owner=team-x", "--limit=100", "--format=json", "--closed"], ""),
                ("project_view", {"owner": "acme", "number": 3}, ["project", "view", "3", "--owner=acme", "--format=json"], ""),
                ("project_field_list", {"owner": "acme", "number": 3}, ["project", "field-list", "3", "--owner=acme", "--limit=100", "--format=json"], ""),
                ("project_item_list", {"owner": "acme", "number": 3, "query": "-status:Done", "limit": 50}, ["project", "item-list", "3", "--owner=acme", "--limit=50", "--format=json", "--query=-status:Done"], ""),
                ("project_item_add", {"owner": "acme", "number": 3, "url": URL}, ["project", "item-add", "3", "--owner=acme", "--url=" + URL, "--format=json"], ""),
                ("project_item_edit", {"owner": "acme", "number": 3, "url": URL, "field": "Status", "value": "In Progress"}, ["project", "item-edit", "3", "--owner=acme", "--url=" + URL, "--field=Status", "--value=In Progress", "--format=json"], ""),
                ("project_item_edit", {"owner": "acme", "number": 3, "url": URL, "field": "Estimate", "numberValue": 2.5}, ["project", "item-edit", "3", "--owner=acme", "--url=" + URL, "--field=Estimate", "--number=2.5", "--format=json"], ""),
                ("project_item_edit", {"owner": "acme", "number": 3, "url": URL, "field": "Sprint", "iterationId": "cfc16e4d"}, ["project", "item-edit", "3", "--owner=acme", "--url=" + URL, "--field=Sprint", "--iteration-id=cfc16e4d", "--format=json"], ""),
                ("project_item_edit", {"owner": "acme", "number": 3, "url": URL, "field": "Due", "clear": True}, ["project", "item-edit", "3", "--owner=acme", "--url=" + URL, "--field=Due", "--clear", "--format=json"], ""),
            ]
            for tool, args, argv, stdin in cases:
                result = await self.app.execute(tool, args)
                self.assertEqual(result["status"], "ok", tool)
                self.assertTrue(result["jsonParsed"], tool)
                record = self.records()[-1]
                self.assertEqual(record["argv"], argv, tool)
                self.assertEqual(record["stdin"], stdin, tool)
                self.assertEqual(set(record["environment"]) - {"PYTHONNOUSERSITE"}, EXPECTED_ENV)
                self.assertEqual(record["environment"]["GH_HOST"], "github.com")
                self.assertEqual(record["environment"]["SSL_CERT_FILE"], "__CACERT__")
                self.assertFalse(Path(record["cwd"]).exists())

        async def test_issue_types_query_is_fixed(self):
            self.assertEqual((await self.app.execute("issue_type_list", {"owner": "acme"}))["status"], "ok")
            argv = self.records()[-1]["argv"]
            self.assertEqual(argv[:2], ["api", "graphql"])
            self.assertTrue(argv[2].startswith("--raw-field=query=query($owner:String!){organization(login:$owner){issueTypes"))
            self.assertEqual(argv[3], "--raw-field=owner=acme")

        async def test_writes_bind_values_and_send_bodies_on_stdin(self):
            self.config({"mode": "text", "text": "Creating issue\nhttps://github.com/acme/app/issues/8"})
            result = await self.app.execute("issue_create", {"repo": "acme/app", "title": "--help", "body": "Line one\n- [ ] item", "labels": ["epic"], "assignees": ["@me", "bob"], "milestone": "Sprint 3", "type": "Epic", "parent": 5, "projects": ["Roadmap"]})
            self.assertEqual(result["status"], "ok")
            self.assertEqual(result["data"], {"url": "https://github.com/acme/app/issues/8"})
            record = self.records()[-1]
            self.assertEqual(record["argv"], ["issue", "create", "--repo=acme/app", "--title=--help", "--body-file=-", "--label=epic", "--assignee=@me,bob", "--project=Roadmap", "--milestone=Sprint 3", "--type=Epic", "--parent=5"])
            self.assertEqual(record["stdin"], "Line one\n- [ ] item")
            self.config({"mode": "text", "text": "https://github.com/acme/app/issues/7"})
            await self.app.execute("issue_edit", {"repo": "acme/app", "number": 7, "body": "new", "addLabels": ["a", "b"], "removeLabels": ["c"], "addAssignees": ["x"], "removeAssignees": ["y"], "addProjects": ["Roadmap"], "addSubIssues": [8, 9], "parent": 2, "milestone": "M", "type": "Task", "title": "T"})
            record = self.records()[-1]
            self.assertEqual(record["argv"], ["issue", "edit", "7", "--repo=acme/app", "--title=T", "--body-file=-", "--add-label=a,b", "--remove-label=c", "--add-assignee=x", "--remove-assignee=y", "--add-project=Roadmap", "--add-sub-issue=8,9", "--parent=2", "--milestone=M", "--type=Task"])
            self.assertEqual(record["stdin"], "new")
            await self.app.execute("issue_comment", {"repo": "acme/app", "number": 7, "body": "Moved to sprint 4"})
            self.assertEqual(self.records()[-1]["argv"], ["issue", "comment", "7", "--repo=acme/app", "--body-file=-"])
            self.assertEqual(self.records()[-1]["stdin"], "Moved to sprint 4")
            self.config({"mode": "text", "text": ""})
            close = await self.app.execute("issue_close", {"repo": "acme/app", "number": 7, "reason": "not planned", "comment": "Dropped"})
            self.assertEqual(close["status"], "ok")
            self.assertEqual(self.records()[-1]["argv"], ["issue", "close", "7", "--repo=acme/app", "--reason=not planned", "--comment=Dropped"])
            await self.app.execute("issue_reopen", {"repo": "acme/app", "number": 7})
            self.assertEqual(self.records()[-1]["argv"], ["issue", "reopen", "7", "--repo=acme/app"])

        async def test_rejections_never_spawn(self):
            cases = [
                ("issue_view", {"repo": "other/app", "number": 1}, "unauthorized_owner"),
                ("project_list", {"owner": "other"}, "unauthorized_owner"),
                ("project_item_add", {"owner": "acme", "number": 1, "url": "https://github.com/other/app/issues/1"}, "unauthorized_owner"),
                ("issue_view", {"repo": "acme/..", "number": 1}, "invalid_arguments"),
                ("issue_view", {"repo": "acme/app", "number": True}, "invalid_arguments"),
                ("issue_view", {"repo": "acme/app", "number": 0}, "invalid_arguments"),
                ("issue_view", {"repo": "acme/app", "number": 1, "extra": 1}, "invalid_arguments"),
                ("issue_view", {"repo": "acme/app", "number": 1, "timeoutSeconds": 301}, "invalid_arguments"),
                ("issue_view", {"repo": "acme/app"}, "invalid_arguments"),
                ("issue_create", {"repo": "acme/app", "title": "a\nb", "body": ""}, "invalid_arguments"),
                ("issue_create", {"repo": "acme/app", "title": "t", "body": "\x1b[31m"}, "invalid_arguments"),
                ("issue_create", {"repo": "acme/app", "title": "t", "body": "", "labels": ["a,b"]}, "invalid_arguments"),
                ("issue_create", {"repo": "acme/app", "title": "t", "body": "", "labels": ["a", "a"]}, "invalid_arguments"),
                ("issue_edit", {"repo": "acme/app", "number": 1}, "invalid_arguments"),
                ("project_item_edit", {"owner": "acme", "number": 1, "url": URL, "field": "Status"}, "invalid_arguments"),
                ("project_item_edit", {"owner": "acme", "number": 1, "url": URL, "field": "Status", "value": "A", "text": "B"}, "invalid_arguments"),
                ("project_item_edit", {"owner": "acme", "number": 1, "url": URL, "field": "Status", "clear": False}, "invalid_arguments"),
                ("project_item_edit", {"owner": "acme", "number": 1, "url": URL, "field": "Due", "date": "tomorrow"}, "invalid_arguments"),
                ("project_item_edit", {"owner": "acme", "number": 1, "url": URL, "field": "N", "numberValue": float("nan")}, "invalid_arguments"),
                ("project_item_edit", {"owner": "acme", "number": 1, "url": "https://evil.example/acme/app/issues/1", "field": "S", "value": "x"}, "invalid_arguments"),
                ("issue_close", {"repo": "acme/app", "number": 1, "reason": "duplicate"}, "invalid_arguments"),
            ]
            for tool, args, expected in cases:
                self.assertEqual((await self.app.execute(tool, args))["status"], expected, (tool, args))
            self.assertEqual(self.records(), [])

        async def test_status_matrix(self):
            for mode, expected in (("nonzero", "execution_error"), ("text", "invalid_output"), ("flood", "truncated")):
                self.config({"mode": mode})
                self.assertEqual((await self.app.execute("issue_view", {"repo": "acme/app", "number": 1}))["status"], expected, mode)
            self.config({"mode": "wait"})
            result = await self.app.execute("issue_view", {"repo": "acme/app", "number": 1, "timeoutSeconds": 1})
            self.assertEqual(result["status"], "timeout")
            self.config({"mode": "json"})
            self.assertEqual((await self.app.execute("issue_view", {"repo": "acme/app", "number": 1}))["status"], "ok")

        def test_schemas(self):
            self.assertEqual(set(TOOLS), set(SPECS))
            for tool in TOOLS:
                schema = self.app.schema(tool)
                self.assertFalse(schema["additionalProperties"])
                self.assertIn("timeoutSeconds", schema["properties"])
                self.assertTrue(set(schema["required"]) <= set(schema["properties"]))
            self.assertNotIn("delete", " ".join(TOOLS))


    if __name__ == "__main__":
        unittest.main()
  '';
  testProtocolSource = writeText "test_protocol.py" ''
    import asyncio
    import json
    import os
    import shutil
    import tempfile
    import unittest
    from pathlib import Path

    TOOLS = {"issue_list", "issue_view", "label_list", "milestone_list", "issue_type_list", "project_list", "project_view", "project_field_list", "project_item_list", "issue_create", "issue_edit", "issue_close", "issue_reopen", "issue_comment", "project_item_add", "project_item_edit"}


    class ProtocolTests(unittest.IsolatedAsyncioTestCase):
        async def launch(self, executable):
            home = Path(tempfile.mkdtemp(prefix="gh-mcp-protocol-"))
            config = home / "config.json"
            config.write_text(json.dumps({"owners": ["acme"]}))
            process = await asyncio.create_subprocess_exec(executable, "--config", str(config), stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, env={"HOME": str(home)})
            self.ident = 0
            return home, process

        async def request(self, process, method, params=None):
            self.ident += 1
            message = {"jsonrpc": "2.0", "id": self.ident, "method": method}
            if params is not None:
                message["params"] = params
            process.stdin.write((json.dumps(message) + "\n").encode())
            await process.stdin.drain()
            while True:
                line = await asyncio.wait_for(process.stdout.readline(), 10)
                self.assertTrue(line, "server closed stdout")
                reply = json.loads(line)
                if reply.get("id") == self.ident:
                    return reply

        async def initialize(self, process):
            await self.request(process, "initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "test", "version": "1"}})
            process.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
            await process.stdin.drain()

        async def finish(self, home, process):
            process.stdin.close()
            try:
                await asyncio.wait_for(process.wait(), 5)
            except asyncio.TimeoutError:
                process.kill()
                await process.wait()
                self.fail("server did not exit after stdin EOF")
            shutil.rmtree(home)

        async def test_fake_server_round_trip(self):
            home, process = await self.launch(os.environ["GH_MCP_TEST_SERVER"])
            try:
                await self.initialize(process)
                tools = (await self.request(process, "tools/list"))["result"]["tools"]
                self.assertEqual({tool["name"] for tool in tools}, TOOLS)
                good = await self.request(process, "tools/call", {"name": "issue_view", "arguments": {"repo": "acme/app", "number": 1}})
                self.assertFalse(good["result"]["isError"])
                self.assertEqual(json.loads(good["result"]["content"][0]["text"])["data"], {"ok": True})
                bad = await self.request(process, "tools/call", {"name": "issue_view", "arguments": {"repo": "other/app", "number": 1}})
                self.assertTrue(bad["result"]["isError"])
                self.assertEqual(json.loads(bad["result"]["content"][0]["text"])["status"], "unauthorized_owner")
            finally:
                await self.finish(home, process)

        async def test_production_server_lists_and_rejects(self):
            home, process = await self.launch(os.environ["GH_MCP_PRODUCTION_SERVER"])
            try:
                await self.initialize(process)
                tools = (await self.request(process, "tools/list"))["result"]["tools"]
                self.assertEqual({tool["name"] for tool in tools}, TOOLS)
                bad = await self.request(process, "tools/call", {"name": "issue_create", "arguments": {"repo": "acme/app", "title": "t"}})
                self.assertTrue(bad["result"]["isError"])
            finally:
                await self.finish(home, process)


    if __name__ == "__main__":
        unittest.main()
  '';
  testServer = gh-mcp.override { gh = fakeGh; };
  testSource = runCommand "gh-mcp-test-source" { } ''
    mkdir -p $out/tests
    cp ${gh-mcp.src}/server.py $out/server.py
    cp ${fakeGhSource} $out/tests/fake_gh.py
    cp ${testServerSource} $out/tests/test_server.py
    cp ${testProtocolSource} $out/tests/test_protocol.py
  '';
in
runCommand "gh-mcp-check" {
  src = testSource;
  nativeBuildInputs = [ python gh-mcp testServer ];
} ''
  export PYTHONDONTWRITEBYTECODE=1
  export GH_MCP_TEST_SERVER=${testServer}/bin/gh-mcp
  export GH_MCP_PRODUCTION_SERVER=${gh-mcp}/bin/gh-mcp
  grep -F '"${gh}/bin/gh"' ${gh-mcp}/libexec/gh-mcp/server.py
  grep -F '"${cacert}/etc/ssl/certs/ca-bundle.crt"' ${gh-mcp}/libexec/gh-mcp/server.py
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
