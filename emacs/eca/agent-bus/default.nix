{ python3Packages, makeWrapper, writeTextFile }:
let
  python = python3Packages.python.withPackages (ps: [ ps.mcp ]);
  serverSource = writeTextFile {
    name = "agent-bus-source";
    destination = "/server.py";
    text = ''
    #!/usr/bin/env python3
    import asyncio
    import json
    import re
    import time
    from collections import OrderedDict
    from typing import Any

    from mcp.server.lowlevel import Server
    from mcp.server.stdio import stdio_server
    from mcp.types import CallToolResult, TextContent, Tool

    CHANNEL = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")
    NAME = re.compile(r"^[A-Za-z0-9._-]{1,64}$")
    CONTROL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
    BROADCAST = "all"
    MAX_BODY = 16384
    MAX_MESSAGES = 1000
    MAX_CHANNELS = 256
    MAX_WAIT = 60

    SCHEMAS = {
        "post": {
            "description": "Post a message on a coordination channel to one participant or to all",
            "properties": {
                "channel": {"type": "string", "pattern": CHANNEL.pattern},
                "sender": {"type": "string", "pattern": NAME.pattern},
                "to": {"type": "string", "pattern": NAME.pattern, "description": "Participant name, or \"all\" to broadcast"},
                "body": {"type": "string", "minLength": 1, "maxLength": MAX_BODY},
            },
            "required": ["channel", "sender", "to", "body"],
        },
        "read": {
            "description": "Read messages addressed to a participant (directly or broadcast) with id greater than after, optionally waiting for new ones",
            "properties": {
                "channel": {"type": "string", "pattern": CHANNEL.pattern},
                "recipient": {"type": "string", "pattern": NAME.pattern},
                "after": {"type": "integer", "minimum": 0},
                "waitSeconds": {"type": "integer", "minimum": 0, "maximum": MAX_WAIT},
            },
            "required": ["channel", "recipient"],
        },
    }
    TOOLS = tuple(SCHEMAS)


    class Bus:
        def __init__(self):
            self.channels: OrderedDict[str, dict[str, Any]] = OrderedDict()
            self.changed = asyncio.Condition()

        def channel(self, name):
            if name not in self.channels:
                if len(self.channels) >= MAX_CHANNELS:
                    self.channels.popitem(last=False)
                self.channels[name] = {"next": 1, "messages": []}
            self.channels.move_to_end(name)
            return self.channels[name]

        @staticmethod
        def schema(tool):
            spec = SCHEMAS[tool]
            return {"type": "object", "properties": spec["properties"], "required": spec["required"], "additionalProperties": False}

        @staticmethod
        def validate(tool, args):
            if not isinstance(args, dict):
                return "invalid_arguments"
            spec = SCHEMAS[tool]
            if set(args) - set(spec["properties"]) or any(key not in args for key in spec["required"]):
                return "invalid_arguments"
            for key, value in args.items():
                if key == "channel":
                    ok = isinstance(value, str) and CHANNEL.fullmatch(value) is not None
                elif key in {"sender", "to", "recipient"}:
                    ok = isinstance(value, str) and NAME.fullmatch(value) is not None
                elif key == "body":
                    ok = isinstance(value, str) and 1 <= len(value) <= MAX_BODY and not CONTROL.search(value)
                else:
                    limit = MAX_WAIT if key == "waitSeconds" else None
                    ok = isinstance(value, int) and not isinstance(value, bool) and value >= 0 and (limit is None or value <= limit)
                if not ok:
                    return "invalid_arguments"
            if tool == "post" and args["sender"] == BROADCAST:
                return "invalid_arguments"
            if tool == "read" and args["recipient"] == BROADCAST:
                return "invalid_arguments"
            return None

        def pending(self, args):
            state = self.channel(args["channel"])
            after = args.get("after", 0)
            me = args["recipient"]
            found = [m for m in state["messages"] if m["id"] > after and m["sender"] != me and m["to"] in (me, BROADCAST)]
            return found, state["next"] - 1

        async def execute(self, tool, args):
            invalid = self.validate(tool, args)
            if invalid:
                return {"status": invalid}
            async with self.changed:
                if tool == "post":
                    state = self.channel(args["channel"])
                    message = {"id": state["next"], "sender": args["sender"], "to": args["to"], "body": args["body"], "time": time.time()}
                    state["next"] += 1
                    state["messages"].append(message)
                    del state["messages"][:-MAX_MESSAGES]
                    self.changed.notify_all()
                    return {"status": "ok", "id": message["id"]}
                deadline = time.monotonic() + args.get("waitSeconds", 0)
                found, cursor = self.pending(args)
                while not found:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        break
                    try:
                        await asyncio.wait_for(self.changed.wait(), remaining)
                    except asyncio.TimeoutError:
                        pass
                    found, cursor = self.pending(args)
                return {"status": "ok", "messages": found, "cursor": cursor}


    def make_server(bus):
        server = Server("agent-bus")

        @server.list_tools()
        async def list_tools():
            return [Tool(name=name, description=SCHEMAS[name]["description"], inputSchema=bus.schema(name)) for name in TOOLS]

        @server.call_tool(validate_input=False)
        async def call_tool(name: str, arguments: dict):
            result = {"status": "invalid_arguments"} if name not in TOOLS else await bus.execute(name, arguments or {})
            return CallToolResult(content=[TextContent(type="text", text=json.dumps(result, separators=(",", ":")))], isError=result["status"] != "ok")

        return server


    async def main():
        server = make_server(Bus())
        async with stdio_server() as streams:
            await server.run(streams[0], streams[1], server.create_initialization_options())


    def cli():
        asyncio.run(main())


    if __name__ == "__main__": cli()
    '';
  };
in
python3Packages.buildPythonApplication {
  pname = "agent-bus";
  version = "0.1.0";
  pyproject = false;
  src = serverSource;
  propagatedBuildInputs = [ python3Packages.mcp ];
  dontUnpack = false;
  installPhase = ''
    install -Dm755 server.py $out/libexec/agent-bus/server.py
    makeWrapper ${python.interpreter} $out/bin/agent-bus \
      --add-flags "$out/libexec/agent-bus/server.py"
  '';
  nativeBuildInputs = [ makeWrapper ];
  meta.mainProgram = "agent-bus";
}
