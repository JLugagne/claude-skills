# Checklist: Path Traversal, Filesystem Access & File Uploads (OWASP A01, A03)

## 1. Directory & Path Traversal (CWE-22, CWE-23)
- [ ] **Dot-Dot-Slash (`../`, `..\`) Filtering**: Identify all endpoints accepting file names, paths, or document keys. Verify user-supplied input is not directly concatenated into filesystem paths without boundary checking.
- [ ] **Encoding & Normalization Bypasses**: Test for URL encoded (`%2e%2e%2f`), double-encoded (`%252e%252e%252f`), unicode normalized, overlong UTF-8, and null-byte (`%00`) sequence bypasses.
- [ ] **Absolute Path Overwrite in Path Joining**: Check functions like `filepath.Join(baseDir, userInput)` in Go or `os.path.join(base_dir, user_input)` in Python — if `userInput` begins with a slash (`/`), it replaces the base directory entirely in many languages.
- [ ] **Root Prefix Validation (`HasPrefix` / `Rel`)**: Ensure path sanitization resolves symlinks and canonicalizes the path (e.g. `filepath.EvalSymlinks` + `filepath.Clean`) and validates that the resulting target strictly starts with the designated safe root directory (with trailing slash).

## 2. Zip Slip & Archive Extraction (CWE-29)
- [ ] **Archive Member Path Validation**: Inspect code extracting `.zip`, `.tar`, `.tar.gz`, or `.jar` files. Verify that each entry's path (`header.Name` or `zipFile.Name`) is validated to ensure it does not contain directory traversal sequences before writing to disk.
- [ ] **Symlink Attacks in Archives**: Check if extracted archives can contain malicious symlinks that point outside the destination directory, leading to subsequent arbitrary file writes or reads.

## 3. Arbitrary File Read, Write & Deletion (CWE-73, CWE-434)
- [ ] **Arbitrary File Read**: Check endpoints serving files (e.g., invoices, profile pictures, export downloads). Can an attacker supply paths to read system files (`/etc/passwd`, `/etc/shadow`), application source code, or configuration secrets (`.env`, private keys)?
- [ ] **Arbitrary File Write / Overwrite**: Identify where files are saved to disk. Can an attacker overwrite critical configuration files, cron jobs, templates, or executable scripts?
- [ ] **Arbitrary File Deletion**: Check file deletion endpoints (e.g., deleting attachments). Can an attacker delete arbitrary system or application files by manipulating paths?

## 4. Unrestricted File Uploads (CWE-434)
- [ ] **File Extension Blacklisting vs Whitelisting**: Verify that file extensions are validated against a strict, minimal whitelist (never a blacklist). Check for double extensions (`file.php.png`), trailing dots/spaces, or case sensitivity bypasses (`.PhP`).
- [ ] **MIME-Type & Magic Byte Spoofing**: Verify that file validation does not rely solely on the client-supplied `Content-Type` header; check that server-side magic byte inspection is enforced.
- [ ] **Storage Location & Execution Permissions**: Ensure uploaded files are stored outside the public web server document root, on an isolated object store (S3/GCS/MinIO), or served with headers that prevent execution (`Content-Disposition: attachment`, `X-Content-Type-Options: nosniff`, strict CSP).
- [ ] **Filename Sanitization**: Verify that the original user-supplied filename is never used directly on the filesystem; replace it with a server-generated UUID or hash.
