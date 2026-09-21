# Checklist: Remote Code Execution (RCE) & Arbitrary Execution (OWASP A03, A08)

## 1. OS Command & Shell Injection (CWE-78, CWE-88)
- [ ] **Direct Shell Execution Sinks**: Search for all invocations of shell execution APIs (`os/exec.Command` in Go, `subprocess.Popen(shell=True)` or `os.system` in Python, `child_process.exec` in Node.js, `Runtime.getRuntime().exec` in Java).
- [ ] **Unsanitized Command Arguments & String Interpolation**: Ensure commands do not concatenate user-controlled input into shell strings. Verify that commands are invoked directly with argument slices (`exec.Command("git", "clone", url)`) without spawning an intermediate shell (`sh -c`).
- [ ] **Argument Injection / Flag Injection**: Even when invoking binaries directly without a shell, verify that user input cannot begin with dashes (`-` or `--`) to inject malicious flags into tools like `git` (`--upload-pack`), `tar` (`--checkpoint-action`), `curl` (`-o`), `ssh` (`-oProxyCommand`), or `find` (`-exec`).

## 2. Insecure Deserialization (CWE-502, OWASP A08)
- [ ] **Dangerous Deserialization Libraries**: Check for usage of native/unsafe deserializers on untrusted data: Python `pickle`, `marshal`, `shelve`; PyYAML `yaml.load` (instead of `safe_load`); Java `ObjectInputStream.readObject`; PHP `unserialize`; Ruby `Marshal.load`.
- [ ] **Polymorphic / Dynamic Type Deserialization**: In Go (`encoding/gob`, `json.Unmarshal` into `interface{}`), C# (`BinaryFormatter`, `TypeNameHandling.All`), or Java (Jackson default typing, Fastjson), verify that untrusted input cannot specify arbitrary types to instantiate gadget chains.
- [ ] **RPC & Message Broker Deserialization**: Ensure messages consumed from queues (RabbitMQ, Kafka, SQS, Redis pub/sub) or internal RPCs validate payload schemas strictly before deserializing.

## 3. Server-Side Template Injection (SSTI) (CWE-1336, OWASP A03)
- [ ] **Template String Interpolation vs Context Binding**: Verify that template engines (Jinja2, Django templates, Twig, Blade, Pebble, Go `html/template` or `text/template`, Handlebars, Mustache) compile static template files and pass user data as variables, rather than rendering strings constructed by concatenating user input (`template.New().Parse("Hello " + userInput)`).
- [ ] **Sandbox Escape & Method Invocation**: For template engines with expression support (Jinja2, Pebble, Twig, SpEL, OGNL), check if user input can invoke built-in functions, reflection methods, or access underlying system objects (`__builtins__`, `__class__`, `Runtime`).

## 4. Dynamic Code Evaluation & Script Engines (CWE-94, CWE-95)
- [ ] **Code Evaluation Functions**: Search for `eval()`, `exec()`, `Function()`, `vm.runInContext()` in JavaScript, `eval` in Python/Ruby/PHP. Ensure no user input can influence evaluated code strings.
- [ ] **Embedded Scripting Languages**: If the application embeds an interpreter (e.g. Lua, Otto/Goja JavaScript engine in Go, Python embedded in C++), verify that the interpreter environment is completely sandboxed: no filesystem, network, or OS process execution bindings exposed to user scripts.
- [ ] **Dynamic Plugin / Library Loading**: Check functions that load external libraries (`plugin.Open` in Go, `dlopen` in C/C++, `ctypes.CDLL` in Python). Verify that library names and paths are strictly hardcoded or loaded only from trusted, tamper-proof directories.
