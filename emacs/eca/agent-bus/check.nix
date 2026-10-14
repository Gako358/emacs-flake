{ runCommand, writeText, python3Packages, agent-bus }:
let
  python = python3Packages.python.withPackages (ps: [ ps.mcp ]);
  testServerSource = writeText "test_server.py" ''
    import asyncio
    import sys
    import time
    import unittest
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).parents[1]))
    from server import MAX_MESSAGES, SCHEMAS, TOOLS, Bus


    class BusTests(unittest.IsolatedAsyncioTestCase):
        async def asyncSetUp(self):
            self.bus = Bus()

        async def post(self, sender, to, body, channel="plan:wave-1"):
            result = await self.bus.execute("post", {"channel": channel, "sender": sender, "to": to, "body": body})
            self.assertEqual(result["status"], "ok")
            return result["id"]

        async def read(self, recipient, after=0, wait=0, channel="plan:wave-1"):
            result = await self.bus.execute("read", {"channel": channel, "recipient": recipient, "after": after, "waitSeconds": wait})
            self.assertEqual(result["status"], "ok")
            return result

        async def test_direct_broadcast_and_own_messages(self):
            await self.post("T1", "T2", "need RecordingLogger")
            await self.post("T2", "all", "AppConfig field added")
            await self.post("T3", "T1", "logback done")
            t1 = await self.read("T1")
            self.assertEqual([(m["sender"], m["body"]) for m in t1["messages"]], [("T2", "AppConfig field added"), ("T3", "logback done")])
            t2 = await self.read("T2")
            self.assertEqual([m["body"] for m in t2["messages"]], ["need RecordingLogger"])
            self.assertEqual(t2["cursor"], 3)
            self.assertEqual((await self.read("T1", after=t1["cursor"]))["messages"], [])

        async def test_channels_are_isolated(self):
            await self.post("T1", "all", "hello", channel="a")
            self.assertEqual((await self.read("T2", channel="b"))["messages"], [])
            self.assertEqual(len((await self.read("T2", channel="a"))["messages"]), 1)

        async def test_wait_wakes_on_post_and_times_out(self):
            waiter = asyncio.create_task(self.read("T2", wait=5))
            await asyncio.sleep(0.1)
            await self.post("T1", "T2", "ready")
            result = await asyncio.wait_for(waiter, 2)
            self.assertEqual([m["body"] for m in result["messages"]], ["ready"])
            started = time.monotonic()
            empty = await self.read("T2", after=result["cursor"], wait=1)
            self.assertEqual(empty["messages"], [])
            self.assertGreaterEqual(time.monotonic() - started, 0.9)

        async def test_unrelated_post_does_not_end_wait(self):
            waiter = asyncio.create_task(self.read("T2", wait=3))
            await asyncio.sleep(0.1)
            await self.post("T1", "T3", "not for T2")
            await asyncio.sleep(0.2)
            self.assertFalse(waiter.done())
            await self.post("T1", "all", "for everyone")
            result = await asyncio.wait_for(waiter, 2)
            self.assertEqual([m["body"] for m in result["messages"]], ["for everyone"])

        async def test_history_is_bounded(self):
            for i in range(MAX_MESSAGES + 5):
                await self.post("T1", "T2", str(i))
            messages = (await self.read("T2"))["messages"]
            self.assertEqual(len(messages), MAX_MESSAGES)
            self.assertEqual(messages[0]["body"], "5")

        async def test_rejections(self):
            cases = [
                ("post", {"channel": "c", "sender": "T1", "to": "T2"}),
                ("post", {"channel": "c", "sender": "T1", "to": "T2", "body": ""}),
                ("post", {"channel": "c", "sender": "T1", "to": "T2", "body": "\x1b[31m"}),
                ("post", {"channel": "c", "sender": "all", "to": "T2", "body": "x"}),
                ("post", {"channel": "c d", "sender": "T1", "to": "T2", "body": "x"}),
                ("post", {"channel": "c", "sender": "T1", "to": "T2", "body": "x", "extra": 1}),
                ("post", {"channel": "c", "sender": "T1", "to": "T2", "body": "x" * 16385}),
                ("read", {"channel": "c", "recipient": "all"}),
                ("read", {"channel": "c", "recipient": "T1", "waitSeconds": 61}),
                ("read", {"channel": "c", "recipient": "T1", "after": True}),
                ("read", {"channel": "c", "recipient": "T1", "after": -1}),
            ]
            for tool, args in cases:
                self.assertEqual((await self.bus.execute(tool, args))["status"], "invalid_arguments", (tool, args))
            self.assertEqual((await self.read("T2", channel="c"))["messages"], [])

        def test_schemas(self):
            self.assertEqual(set(TOOLS), {"post", "read"})
            for tool in TOOLS:
                schema = self.bus.schema(tool)
                self.assertFalse(schema["additionalProperties"])
                self.assertTrue(set(schema["required"]) <= set(SCHEMAS[tool]["properties"]))


    if __name__ == "__main__":
        unittest.main()
  '';
  testProtocolSource = writeText "test_protocol.py" ''
    import asyncio
    import json
    import os
    import unittest


    class ProtocolTests(unittest.IsolatedAsyncioTestCase):
        async def asyncSetUp(self):
            self.process = await asyncio.create_subprocess_exec(os.environ["AGENT_BUS_SERVER"], stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, env={"HOME": os.environ["HOME"]})
            self.ident = 0
            self.replies = {}
            self.reader = asyncio.create_task(self.read_loop())
            await self.request("initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "test", "version": "1"}})
            self.process.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
            await self.process.stdin.drain()

        async def asyncTearDown(self):
            self.process.stdin.close()
            try:
                await asyncio.wait_for(self.process.wait(), 5)
            except asyncio.TimeoutError:
                self.process.kill()
                await self.process.wait()
                self.fail("server did not exit after stdin EOF")
            self.reader.cancel()

        async def read_loop(self):
            while line := await self.process.stdout.readline():
                reply = json.loads(line)
                if "id" in reply and reply["id"] in self.replies:
                    self.replies[reply["id"]].set_result(reply)

        async def request(self, method, params=None):
            self.ident += 1
            ident = self.ident
            self.replies[ident] = asyncio.get_running_loop().create_future()
            message = {"jsonrpc": "2.0", "id": ident, "method": method}
            if params is not None:
                message["params"] = params
            self.process.stdin.write((json.dumps(message) + "\n").encode())
            await self.process.stdin.drain()
            return await asyncio.wait_for(self.replies[ident], 15)

        async def call(self, name, arguments):
            reply = await self.request("tools/call", {"name": name, "arguments": arguments})
            return reply["result"]["isError"], json.loads(reply["result"]["content"][0]["text"])

        async def test_tools_and_concurrent_wait(self):
            tools = (await self.request("tools/list"))["result"]["tools"]
            self.assertEqual({tool["name"] for tool in tools}, {"post", "read"})
            waiter = asyncio.create_task(self.call("read", {"channel": "plan:w1", "recipient": "T2", "waitSeconds": 10}))
            await asyncio.sleep(0.3)
            self.assertFalse(waiter.done())
            error, posted = await self.call("post", {"channel": "plan:w1", "sender": "T1", "to": "T2", "body": "interface ready"})
            self.assertFalse(error)
            self.assertEqual(posted["id"], 1)
            error, result = await asyncio.wait_for(waiter, 5)
            self.assertFalse(error)
            self.assertEqual([m["body"] for m in result["messages"]], ["interface ready"])
            error, bad = await self.call("post", {"channel": "plan:w1", "sender": "T1", "to": "T2"})
            self.assertTrue(error)
            self.assertEqual(bad["status"], "invalid_arguments")
            error, unknown = await self.call("delete", {})
            self.assertTrue(error)


    if __name__ == "__main__":
        unittest.main()
  '';
  testSource = runCommand "agent-bus-test-source" { } ''
    mkdir -p $out/tests
    cp ${agent-bus.src}/server.py $out/server.py
    cp ${testServerSource} $out/tests/test_server.py
    cp ${testProtocolSource} $out/tests/test_protocol.py
  '';
in
runCommand "agent-bus-check" {
  src = testSource;
  nativeBuildInputs = [ python agent-bus ];
} ''
  export PYTHONDONTWRITEBYTECODE=1
  export HOME=$(mktemp -d)
  export AGENT_BUS_SERVER=${agent-bus}/bin/agent-bus
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
