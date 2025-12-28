# Claude Task

Read `BUILD_SPEC.md` in this repository. Treat it as the strict requirements.

Generate the full repository structure and file contents exactly as specified.

Rules:
- Do not ask clarifying questions.
- Do not redesign or simplify.
- Do not omit files.
- Output the repo tree first, then each file path followed by its full contents.
- For uncertain items explicitly marked as uncertain, parameterize them and document them.
- If output length is exceeded, stop at a clear boundary and indicate where to resume.
