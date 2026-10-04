{ python3Packages, gh, cacert, makeWrapper, writeTextFile }:
let
  python = python3Packages.python.withPackages (ps: [ ps.mcp ]);
  serverSource = writeTextFile {
    name = "gh-mcp-source";
    destination = "/server.py";
    text = ''
    #!/usr/bin/env python3
    import argparse
    import asyncio
    import json
    import math
    import os
    import re
    import shutil
    import signal
    import tempfile
    import time
    from pathlib import Path
    from typing import Any

    from mcp.server.lowlevel import Server
    from mcp.server.stdio import stdio_server
    from mcp.types import CallToolResult, TextContent, Tool

    LOGIN = r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})"
    OWNER = re.compile(rf"^{LOGIN}$")
    REPO = re.compile(rf"^({LOGIN})/((?!\.+$)[A-Za-z0-9._-]{{1,100}})$")
    ISSUE_URL = re.compile(rf"^https://github\.com/({LOGIN})/(?!\.+/)[A-Za-z0-9._-]{{1,100}}/(?:issues|pull)/[1-9][0-9]{{0,9}}$")
    NODE_ID = re.compile(r"^[A-Za-z0-9_=-]{1,128}$")
    DATE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
    TEXT_CONTROL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
    LINE_CONTROL = re.compile(r"[\x00-\x1f\x7f]")
    LIMIT = 262144
    CLEANUP = 2.0
    MAX_TIMEOUT = 300
    DEFAULT_TIMEOUT = 60
    MAX_INT = 2**31 - 1
    INHERITED_ENV = ("HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR", "DBUS_SESSION_BUS_ADDRESS", "GH_CONFIG_DIR", "GH_TOKEN", "GITHUB_TOKEN")
    ISSUE_LIST_FIELDS = "number,title,state,labels,assignees,milestone,url,updatedAt"
    ISSUE_VIEW_FIELDS = "number,title,body,state,stateReason,labels,assignees,milestone,issueType,parent,subIssues,subIssuesSummary,projectItems,url"
    ISSUE_TYPES_QUERY = "query($owner:String!){organization(login:$owner){issueTypes(first:50){nodes{id name description isEnabled}}}}"

    REPO_ARG = {"repo": "repo"}
    ISSUE_ARG = {"repo": "repo", "number": "int"}
    PROJECT_ARG = {"owner": "owner", "number": "int"}
    EDIT_KEYS = ("title", "body", "addLabels", "removeLabels", "addAssignees", "removeAssignees", "addProjects", "addSubIssues", "parent", "milestone", "type")
    VALUE_KEYS = ("value", "text", "numberValue", "date", "iterationId", "clear")

    SPECS: dict[str, tuple[str, dict[str, str], list[str]]] = {
        "issue_list": ("List issues in a repository", {**REPO_ARG, "state": "state", "labels": "names", "milestone": "line", "search": "line", "limit": "limit"}, ["repo"]),
        "issue_view": ("View an issue with its parent, sub-issues, type and project items", ISSUE_ARG, ["repo", "number"]),
        "label_list": ("List repository labels", {**REPO_ARG, "limit": "limit"}, ["repo"]),
        "milestone_list": ("List repository milestones", {**REPO_ARG, "state": "state"}, ["repo"]),
        "issue_type_list": ("List an organization's issue types", {"owner": "owner"}, ["owner"]),
        "project_list": ("List an owner's GitHub Projects", {"owner": "owner", "closed": "bool", "limit": "limit"}, ["owner"]),
        "project_view": ("View a GitHub Project", PROJECT_ARG, ["owner", "number"]),
        "project_field_list": ("List a project's fields, options and iterations", {**PROJECT_ARG, "limit": "limit"}, ["owner", "number"]),
        "project_item_list": ("List a project's items, optionally filtered", {**PROJECT_ARG, "query": "line", "limit": "limit"}, ["owner", "number"]),
        "issue_create": ("Create an issue, optionally as a sub-issue and on projects", {**REPO_ARG, "title": "line", "body": "text", "labels": "names", "assignees": "names", "milestone": "line", "type": "line", "parent": "int", "projects": "names"}, ["repo", "title", "body"]),
        "issue_edit": ("Edit an issue's fields, labels, assignees, projects, parent or sub-issues", {**ISSUE_ARG, "title": "line", "body": "text", "addLabels": "names", "removeLabels": "names", "addAssignees": "names", "removeAssignees": "names", "addProjects": "names", "addSubIssues": "ints", "parent": "int", "milestone": "line", "type": "line"}, ["repo", "number"]),
        "issue_close": ("Close an issue", {**ISSUE_ARG, "reason": "reason", "comment": "text"}, ["repo", "number"]),
        "issue_reopen": ("Reopen an issue", ISSUE_ARG, ["repo", "number"]),
        "issue_comment": ("Comment on an issue", {**ISSUE_ARG, "body": "text"}, ["repo", "number", "body"]),
        "project_item_add": ("Add an issue or pull request to a project", {**PROJECT_ARG, "url": "url"}, ["owner", "number", "url"]),
        "project_item_edit": ("Set one field value on a project item by field name", {**PROJECT_ARG, "url": "url", "field": "line", "value": "line", "text": "line", "numberValue": "float", "date": "date", "iterationId": "nodeid", "clear": "bool"}, ["owner", "number", "url", "field"]),
    }
    TOOLS = tuple(SPECS)
    URL_OUTPUT = {"issue_create", "issue_edit", "issue_comment"}
    NO_DATA = {"issue_close", "issue_reopen"}


    class GhMcp:
        def __init__(self, config: dict[str, Any], gh: str):
            self.gh = str(Path(gh).resolve())
            owners = config["owners"]
            if any(not isinstance(o, str) or not OWNER.fullmatch(o) for o in owners):
                raise ValueError("invalid owner")
            self.owners = {o.lower() for o in owners}
            self.lock = asyncio.Lock()

        @staticmethod
        def property_schema(kind):
            line = {"type": "string", "minLength": 1, "maxLength": 256}
            name = {"type": "string", "minLength": 1, "maxLength": 100, "pattern": "^[^,\\x00-\\x1f\\x7f]+$"}
            return {
                "repo": {"type": "string", "pattern": REPO.pattern, "maxLength": 140},
                "owner": {"type": "string", "pattern": OWNER.pattern},
                "int": {"type": "integer", "minimum": 1, "maximum": MAX_INT},
                "ints": {"type": "array", "items": {"type": "integer", "minimum": 1, "maximum": MAX_INT}, "minItems": 1, "maxItems": 50, "uniqueItems": True},
                "limit": {"type": "integer", "minimum": 1, "maximum": 500},
                "line": line,
                "names": {"type": "array", "items": name, "minItems": 1, "maxItems": 20, "uniqueItems": True},
                "text": {"type": "string", "maxLength": 65536},
                "state": {"type": "string", "enum": ["open", "closed", "all"]},
                "reason": {"type": "string", "enum": ["completed", "not planned"]},
                "bool": {"type": "boolean"},
                "url": {"type": "string", "pattern": ISSUE_URL.pattern},
                "nodeid": {"type": "string", "pattern": NODE_ID.pattern},
                "date": {"type": "string", "pattern": DATE.pattern},
                "float": {"type": "number"},
            }[kind]

        def schema(self, tool):
            _, props, required = SPECS[tool]
            properties = {key: self.property_schema(kind) for key, kind in props.items()}
            properties["timeoutSeconds"] = {"type": "integer", "minimum": 1, "maximum": MAX_TIMEOUT}
            return {"type": "object", "properties": properties, "required": required, "additionalProperties": False}

        @staticmethod
        def valid_value(kind, value):
            if kind in {"int", "limit"}:
                return isinstance(value, int) and not isinstance(value, bool) and 1 <= value <= (500 if kind == "limit" else MAX_INT)
            if kind == "ints":
                return isinstance(value, list) and 1 <= len(value) <= 50 and len(set(value)) == len(value) and all(isinstance(v, int) and not isinstance(v, bool) and 1 <= v <= MAX_INT for v in value)
            if kind == "bool":
                return isinstance(value, bool)
            if kind == "float":
                return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)
            if not isinstance(value, (str, list)):
                return False
            if kind == "names":
                return isinstance(value, list) and 1 <= len(value) <= 20 and len(set(value)) == len(value) and all(isinstance(v, str) and 1 <= len(v) <= 100 and "," not in v and not LINE_CONTROL.search(v) for v in value)
            if not isinstance(value, str):
                return False
            if kind == "line":
                return 1 <= len(value) <= 256 and not LINE_CONTROL.search(value)
            if kind == "text":
                return len(value) <= 65536 and not TEXT_CONTROL.search(value)
            if kind == "repo":
                return len(value) <= 140 and REPO.fullmatch(value) is not None
            if kind == "owner":
                return OWNER.fullmatch(value) is not None
            if kind == "url":
                return ISSUE_URL.fullmatch(value) is not None
            if kind == "nodeid":
                return NODE_ID.fullmatch(value) is not None
            if kind == "date":
                return DATE.fullmatch(value) is not None
            if kind == "state":
                return value in {"open", "closed", "all"}
            if kind == "reason":
                return value in {"completed", "not planned"}
            return False

        def validate(self, tool, args):
            if not isinstance(args, dict):
                return "invalid_arguments"
            _, props, required = SPECS[tool]
            if set(args) - set(props) - {"timeoutSeconds"} or any(key not in args for key in required):
                return "invalid_arguments"
            timeout = args.get("timeoutSeconds")
            if timeout is not None and (isinstance(timeout, bool) or not isinstance(timeout, int) or not 1 <= timeout <= MAX_TIMEOUT):
                return "invalid_arguments"
            if any(not self.valid_value(props[key], value) for key, value in args.items() if key != "timeoutSeconds"):
                return "invalid_arguments"
            if tool == "issue_edit" and not any(key in args for key in EDIT_KEYS):
                return "invalid_arguments"
            if tool == "project_item_edit":
                chosen = [key for key in VALUE_KEYS if key in args]
                if len(chosen) != 1 or args.get("clear") is False:
                    return "invalid_arguments"
            owners = []
            if "repo" in args:
                owners.append(REPO.fullmatch(args["repo"]).group(1))
            if "owner" in args:
                owners.append(args["owner"])
            if "url" in args:
                owners.append(ISSUE_URL.fullmatch(args["url"]).group(1))
            if any(owner.lower() not in self.owners for owner in owners):
                return "unauthorized_owner"
            return None

        @staticmethod
        def command(tool, args):
            stdin = None
            if tool == "issue_list":
                argv = ["issue", "list", f"--repo={args['repo']}", f"--state={args.get('state', 'open')}", f"--limit={args.get('limit', 100)}", f"--json={ISSUE_LIST_FIELDS}"]
                argv += [f"--label={label}" for label in args.get("labels", [])]
                if "milestone" in args: argv.append(f"--milestone={args['milestone']}")
                if "search" in args: argv.append(f"--search={args['search']}")
            elif tool == "issue_view":
                argv = ["issue", "view", str(args["number"]), f"--repo={args['repo']}", f"--json={ISSUE_VIEW_FIELDS}"]
            elif tool == "label_list":
                argv = ["label", "list", f"--repo={args['repo']}", f"--limit={args.get('limit', 100)}", "--json=name,description,color"]
            elif tool == "milestone_list":
                argv = ["api", f"repos/{args['repo']}/milestones?state={args.get('state', 'open')}&per_page=100"]
            elif tool == "issue_type_list":
                argv = ["api", "graphql", f"--raw-field=query={ISSUE_TYPES_QUERY}", f"--raw-field=owner={args['owner']}"]
            elif tool == "project_list":
                argv = ["project", "list", f"--owner={args['owner']}", f"--limit={args.get('limit', 100)}", "--format=json"]
                if args.get("closed"): argv.append("--closed")
            elif tool == "project_view":
                argv = ["project", "view", str(args["number"]), f"--owner={args['owner']}", "--format=json"]
            elif tool == "project_field_list":
                argv = ["project", "field-list", str(args["number"]), f"--owner={args['owner']}", f"--limit={args.get('limit', 100)}", "--format=json"]
            elif tool == "project_item_list":
                argv = ["project", "item-list", str(args["number"]), f"--owner={args['owner']}", f"--limit={args.get('limit', 100)}", "--format=json"]
                if "query" in args: argv.append(f"--query={args['query']}")
            elif tool == "issue_create":
                argv = ["issue", "create", f"--repo={args['repo']}", f"--title={args['title']}", "--body-file=-"]
                stdin = args["body"]
                for key, flag in (("labels", "label"), ("assignees", "assignee"), ("projects", "project")):
                    if key in args: argv.append(f"--{flag}={','.join(args[key])}")
                for key in ("milestone", "type", "parent"):
                    if key in args: argv.append(f"--{key}={args[key]}")
            elif tool == "issue_edit":
                argv = ["issue", "edit", str(args["number"]), f"--repo={args['repo']}"]
                if "title" in args: argv.append(f"--title={args['title']}")
                if "body" in args:
                    argv.append("--body-file=-")
                    stdin = args["body"]
                for key, flag in (("addLabels", "add-label"), ("removeLabels", "remove-label"), ("addAssignees", "add-assignee"), ("removeAssignees", "remove-assignee"), ("addProjects", "add-project"), ("addSubIssues", "add-sub-issue")):
                    if key in args: argv.append(f"--{flag}={','.join(str(v) for v in args[key])}")
                for key in ("parent", "milestone", "type"):
                    if key in args: argv.append(f"--{key}={args[key]}")
            elif tool == "issue_close":
                argv = ["issue", "close", str(args["number"]), f"--repo={args['repo']}"]
                if "reason" in args: argv.append(f"--reason={args['reason']}")
                if "comment" in args: argv.append(f"--comment={args['comment']}")
            elif tool == "issue_reopen":
                argv = ["issue", "reopen", str(args["number"]), f"--repo={args['repo']}"]
            elif tool == "issue_comment":
                argv = ["issue", "comment", str(args["number"]), f"--repo={args['repo']}", "--body-file=-"]
                stdin = args["body"]
            elif tool == "project_item_add":
                argv = ["project", "item-add", str(args["number"]), f"--owner={args['owner']}", f"--url={args['url']}", "--format=json"]
            else:
                argv = ["project", "item-edit", str(args["number"]), f"--owner={args['owner']}", f"--url={args['url']}", f"--field={args['field']}"]
                if "value" in args: argv.append(f"--value={args['value']}")
                elif "text" in args: argv.append(f"--text={args['text']}")
                elif "numberValue" in args: argv.append(f"--number={args['numberValue']!r}")
                elif "date" in args: argv.append(f"--date={args['date']}")
                elif "iterationId" in args: argv.append(f"--iteration-id={args['iterationId']}")
                else: argv.append("--clear")
                argv.append("--format=json")
            return argv, stdin

        @staticmethod
        def envelope(tool, status="ok", argv=(), exit_code=None, duration=0, out=None, err=None, parsed=False, data=None, error=None):
            blank = {"text": "", "capturedBytes": 0, "discardedBytes": 0, "truncated": False, "encodingValid": True}
            return {"schemaVersion": 1, "tool": tool, "status": status, "argv": list(argv), "exitCode": exit_code, "durationMs": duration, "stdout": out or blank, "stderr": err or blank, "jsonParsed": parsed, "data": data, "error": error}

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
                valid = True
            except UnicodeDecodeError:
                text = raw.decode("utf-8", "replace")
                valid = False
            return {"text": text, "capturedBytes": len(data), "discardedBytes": discarded, "truncated": discarded > 0, "encodingValid": valid}

        @staticmethod
        async def _feed(stream, payload):
            try:
                if payload:
                    stream.write(payload)
                    await stream.drain()
            except (BrokenPipeError, ConnectionResetError):
                pass
            finally:
                stream.close()

        @staticmethod
        async def _stop(process, tasks):
            for sig in (signal.SIGTERM, signal.SIGKILL):
                try:
                    os.killpg(process.pid, sig)
                except ProcessLookupError:
                    pass
                try:
                    await asyncio.wait_for(asyncio.shield(process.wait()), CLEANUP)
                    break
                except asyncio.TimeoutError:
                    continue
            done = asyncio.gather(*tasks, return_exceptions=True)
            try:
                await asyncio.wait_for(asyncio.shield(done), CLEANUP)
            except asyncio.TimeoutError:
                for task in tasks:
                    task.cancel()
                await asyncio.gather(*tasks, return_exceptions=True)

        def environment(self, temp):
            env = {key: os.environ[key] for key in INHERITED_ENV if key in os.environ}
            env.update({"PATH": os.path.dirname(self.gh), "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8", "TMPDIR": temp, "GH_HOST": "github.com", "GH_PROMPT_DISABLED": "1", "GH_NO_UPDATE_NOTIFIER": "1", "GH_NO_EXTENSION_UPDATE_NOTIFIER": "1", "GH_SPINNER_DISABLED": "1", "NO_COLOR": "1", "GIT_TERMINAL_PROMPT": "0", "SSL_CERT_FILE": "__CACERT__"})
            return env

        async def execute(self, tool, args):
            started = time.monotonic()
            elapsed = lambda: int((time.monotonic() - started) * 1000)
            invalid = self.validate(tool, args)
            if invalid:
                return self.envelope(tool, invalid, duration=elapsed(), error={"message": invalid})
            argv, stdin = self.command(tool, args)
            timeout = args.get("timeoutSeconds", DEFAULT_TIMEOUT)
            async with self.lock:
                process = None
                tasks = []
                temp = tempfile.mkdtemp(prefix="gh-mcp-")
                try:
                    process = await asyncio.create_subprocess_exec(self.gh, *argv, cwd=temp, env=self.environment(temp), stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, start_new_session=True)
                    tasks = [asyncio.create_task(self._drain(process.stdout)), asyncio.create_task(self._drain(process.stderr)), asyncio.create_task(self._feed(process.stdin, (stdin or "").encode("utf-8")))]
                    status = "ok"
                    try:
                        await asyncio.wait_for(asyncio.shield(process.wait()), timeout)
                    except asyncio.TimeoutError:
                        status = "timeout"
                    except asyncio.CancelledError:
                        await asyncio.shield(self._stop(process, tasks))
                        raise
                    await self._stop(process, tasks)
                    blank = {"text": "", "capturedBytes": 0, "discardedBytes": 0, "truncated": False, "encodingValid": True}
                    out, err = [task.result() if task.done() and not task.cancelled() and task.exception() is None else blank for task in tasks[:2]]
                    code = process.returncode
                    if status == "ok" and code != 0: status = "execution_error"
                    elif status == "ok" and (out["truncated"] or err["truncated"]): status = "truncated"
                    elif status == "ok" and (not out["encodingValid"] or not err["encodingValid"]): status = "invalid_output"
                    data = None
                    parsed = False
                    if status == "ok" and tool in URL_OUTPUT:
                        urls = [line for line in out["text"].splitlines() if line.startswith("https://github.com/")]
                        data = {"url": urls[-1]} if urls else None
                    elif status == "ok" and tool not in NO_DATA:
                        try:
                            data = json.loads(out["text"])
                            parsed = True
                        except json.JSONDecodeError:
                            status = "invalid_output"
                    return self.envelope(tool, status, [self.gh, *argv], code, elapsed(), out, err, parsed, data, None if status == "ok" else {"message": status})
                except asyncio.CancelledError:
                    raise
                except Exception as exc:
                    if process is not None:
                        await self._stop(process, tasks)
                    return self.envelope(tool, "execution_error", duration=elapsed(), error={"message": str(exc)})
                finally:
                    shutil.rmtree(temp, ignore_errors=True)


    def make_server(app):
        server = Server("gh-mcp")

        @server.list_tools()
        async def list_tools():
            return [Tool(name=name, description=SPECS[name][0], inputSchema=app.schema(name)) for name in TOOLS]

        @server.call_tool(validate_input=False)
        async def call_tool(name: str, arguments: dict):
            result = app.envelope(name, status="invalid_arguments", error={"message": "unknown tool"}) if name not in TOOLS else await app.execute(name, arguments or {})
            return CallToolResult(content=[TextContent(type="text", text=json.dumps(result, separators=(",", ":")))], isError=result["status"] != "ok")

        return server


    async def main(config, gh):
        app = GhMcp(config, gh)
        server = make_server(app)
        async with stdio_server() as streams:
            await server.run(streams[0], streams[1], server.create_initialization_options())


    def cli():
        parser = argparse.ArgumentParser()
        parser.add_argument("--config", required=True)
        ns = parser.parse_args()
        with open(ns.config, encoding="utf-8") as f: config = json.load(f)
        if set(config) != {"owners"} or not isinstance(config["owners"], list) or not config["owners"] or any(not isinstance(x, str) or not OWNER.fullmatch(x) for x in config["owners"]) or len({x.lower() for x in config["owners"]}) != len(config["owners"]):
            raise SystemExit("invalid config")
        asyncio.run(main(config, "__PACKAGED_GH__"))


    if __name__ == "__main__": cli()
    '';
  };
in
python3Packages.buildPythonApplication {
  pname = "gh-mcp";
  version = "0.1.0";
  pyproject = false;
  src = serverSource;
  propagatedBuildInputs = [ python3Packages.mcp ];
  dontUnpack = false;
  installPhase = ''
    install -Dm755 server.py $out/libexec/gh-mcp/server.py
    substituteInPlace $out/libexec/gh-mcp/server.py \
      --replace-fail '"__PACKAGED_GH__"' '"${gh}/bin/gh"' \
      --replace-fail '"__CACERT__"' '"${cacert}/etc/ssl/certs/ca-bundle.crt"'
    makeWrapper ${python.interpreter} $out/bin/gh-mcp \
      --add-flags "$out/libexec/gh-mcp/server.py"
  '';
  nativeBuildInputs = [ makeWrapper ];
  meta.mainProgram = "gh-mcp";
}
