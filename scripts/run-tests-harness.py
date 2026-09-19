#!/usr/bin/env python3
"""Runs the swift-testing files in Tests/ without Xcode.

`swift test` needs the Testing module, which Command Line Tools lack. This rewrites
@Suite/@Test/#expect into a plain executable, compiles it with the Kit + TUI sources
(so internals are reachable), and runs it. Usage: python3 scripts/run-tests-harness.py
Optional extra Swift files to compile in can be passed as arguments."""
import re, subprocess, sys, os, glob
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
import tempfile
S = tempfile.mkdtemp(prefix="kh-harness-")
srcs = sorted(glob.glob(f"{ROOT}/Sources/KeyholdrKit/*.swift") + glob.glob(f"{ROOT}/Sources/KeyholdrTUI/*.swift"))
extra = sys.argv[1:]  # extra source files (e.g. CLI helpers under test)
tests = sorted(glob.glob(f"{ROOT}/Tests/keyholdrTests/*.swift"))
out, calls = [], []
for t in tests:
    text = open(t).read()
    text = re.sub(r"^import Testing\n|^@testable import .*\n", "", text, flags=re.M)
    suite = None
    lines = []
    for line in text.split("\n"):
        m = re.match(r"@Suite struct (\w+)", line)
        if m:
            suite = m.group(1); lines.append(line.replace("@Suite ", "")); continue
        m = re.match(r"\s*@Test func (\w+)\(", line)
        if m and suite:
            calls.append(f"{suite}().{m.group(1)}"); lines.append(line.replace("@Test ", "")); continue
        if re.match(r"^@Test func (\w+)", line):  # free function tests
            m = re.match(r"^@Test func (\w+)", line); calls.append(m.group(1)); lines.append(line.replace("@Test ", "")); continue
        lines.append(line)
    out.append("\n".join(lines))
body = "\n".join(out).replace("#expect(", "expect(")
main = f'''import Foundation
nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var checks = 0
func expect(_ c: @autoclosure () -> Bool, line: Int = #line) {{ checks += 1; if !c() {{ failures += 1; print("FAIL at test line \\(line)") }} }}
{body}
'''
main_swift = "\n".join(["import Foundation", "// ---- run"] )
runner = "\n".join(f"do {{ try await_{i}() }}" for i in range(0))
open(f"{S}/harness_tests.swift", "w").write(main)
run = ["import Foundation"]
for c in calls:
    run.append(f'print("• {c}"); do {{ try await {c}() }} catch {{ failures += 1; print("THROWN in {c}: \(error)") }}')
run.append('print(failures == 0 ? "ALL OK (\\(checks) checks)" : "\\(failures) FAILED of \\(checks)")')
run.append("exit(failures == 0 ? 0 : 1)")
open(f"{S}/main.swift", "w").write("\n".join(run))
cmd = ["swiftc", "-swift-version", "6", "-o", f"{S}/testharness", *srcs, *extra, f"{S}/harness_tests.swift", f"{S}/main.swift"]
r = subprocess.run(cmd, capture_output=True, text=True)
errs = [l for l in r.stderr.split("\n") if "error" in l]
if r.returncode != 0:
    print("\n".join(errs[:20]) or r.stderr[:2000]); sys.exit(2)
sys.exit(subprocess.run([f"{S}/testharness"]).returncode)
