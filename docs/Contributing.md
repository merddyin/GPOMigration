# Contributing to GPOMigration

Project Site: [https://github.com/merddyin/GPOMigration](https://github.com/merddyin/GPOMigration)

There are some important things to be aware of if you plan on contributing to this project.

## Documentation
All project documentation should be edited directly in the `docs` folder.

- Update `docs/index.md` for user-facing overview and installation information.
- Update `docs/ChangeLog.md` with release notes for each version.
- Keep per-command help in `docs/Functions/*.md` aligned with public function behavior.

Public function comment-based help is still the source of truth for in-shell help. Keep it current when changing command parameters or examples.

## Development Environment
While any text editor will work well there are included task and setting json files explicitly for Visual Studio Code included with this project. The following tasks have been defined to make things a bit easier. First access the 'Pallette' (Shift+Ctrl+P or Shift+Cmd+P)  and start typing in any of the following tasks to find and run them:

- Build Module -> Runs the Build task
- Insert Missing Comment Based Help -> Reserved for compatibility; update CBH manually in this project.
- Run Tests -> Run Pester tests
- Test, Build, Install and Load Module -> Run the Test, build tasks but also install and try to load the module.

