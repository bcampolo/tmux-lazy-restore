# Tmux Lazy Restore 🦥⚡💾 #

A tmux session manager plugin that allows sessions to be lazily restored in order to save memory and processing power, when compared to other session managers which generally restore all of your sessions at once.

********************************************************************************

## Why? ##
**There are already a bunch of tmux session managers, like tmux-resurrect.  Why did you make another one?**  
I've used tmux-resurrect for years and it's an awesome plugin, but I kept running into one major issue.  I have a separate tmux session for every project that I work on, which is around 20 different projects.  These project-based tmux sessions usually involve running Neovim, LSPs, and other processes.  This can eat up a lot of resources and usually I'm only working on one or two of those projects in any given day so loading the rest is a waste.  

So I took the next logical step and started working on a PR for tmux-resurrect to add functionality to lazily restore sessions, but then I happened upon these issues on their GitHub page and started having serious doubts as to whether or not my PR would even be considered:
- [tmux-resurrect Issue #465 (Closed - Not planned)](https://github.com/tmux-plugins/tmux-resurrect/issues/465)
- [tmux-resurrect Issue #255 (Closed - User found work-around)](https://github.com/tmux-plugins/tmux-resurrect/issues/255)  

So here we are: yet another tmux session manager!

********************************************************************************

## Features ##
- **Lazily Restore Individual Sessions**: A custom session-chooser allows selecting any session from the previously saved tmux sessions and only that session will be restored.  This can be a huge savings for memory and processing power.
- **Save/Update Individual Sessions**: You can save new sessions and update individual sessions without impacting all of your other sessions.
- **Easy-to-Read JSON Format**: Session files are stored in human-readable JSON files and can be updated by hand if so desired.
- **Bulk Session Operations**: Optionally Save All and/or Restore All sessions at once, similar to other tmux session managers.

********************************************************************************

## Requirements ##
- [tmux](https://github.com/tmux/tmux/wiki) - You can't use tmux plugins without tmux, right?
- [fzf](https://github.com/junegunn/fzf) - Allows fuzzy finding sessions to restore

********************************************************************************

> **DISCLAIMER:** 
> I do all of my development on a Debian/Ubuntu based Linux distro, so while this SHOULD still work on other systems, it is geared towards my own dev environment and may not work elsewhere.
> If you are using a Mac, your mileage may vary (you Kool-Aid-drinking, hipster Apple fanboi).
> If you are using Windows, I'll see you in Hell!

********************************************************************************

## Installation Using [TPM](https://github.com/tmux-plugins/tpm)
- After installing all of the prerequisites, you can add the following to you .tmux.conf file:
    ```sh
    set -g @plugin 'bcampolo/tmux-lazy-restore'
    ```

- Start tmux as usual

    ```sh
    tmux
    ```
********************************************************************************

## Key Bindings ##
- `prefix + f` - Fuzzy \[F\]ind a session and if not already loaded, restore the chosen session from the session file
- `prefix + u` - Save/\[U\]pdate the current session only to the session file
- `prefix + r` - \[R\]evert the current session to its definition in the session file 
- `prefix + X` - Delete/E\[X\]terminate the current session and remove it from session file
- `prefix + Ctrl-r` - \[R\]estore all sessions (NOTE: Does not impact current sessions that don't already exist in the file)
- `prefix + Ctrl-s` - \[S\]ave all sessions (NOTE: Does not impact sessions in the file that are not currently loaded)

### Customizing Key Bindings ###
- Add the following to your ~/.tmux.conf file after the line that adds the plugin
    ```sh
    set -g @tmux-lazy-restore-choose-key 'f'
    set -g @tmux-lazy-restore-update-key 'u'
    set -g @tmux-lazy-restore-revert-key 'r'
    set -g @tmux-lazy-restore-delete-key 'X'
    set -g @tmux-lazy-restore-restore-all-key 'C-r'
    set -g @tmux-lazy-restore-save-all-key 'C-s'
    ```

### Other Options ###
Optionally add the following to your ~/.tmux.conf file after the tmux-lazy-restore plugin line:
- Change the session file path (defaults to ~/.config/tmux-lazy-restore/sessions.json):
    ```sh
    set -g @tmux-lazy-restore-session-file '/path/to/file'
    ```
- After restoring session(s), kill the tmux session that the restore command was launched from, under the following conditions (defaults to 'off'):
    - The launching session was the only session before restoring
    - The launching session is empty (1 window, 1 pane)
    - The launching session name is numeric (usually auto-named by tmux)
    - The launching session is not the active session being restored
    ```sh
    set -g @tmux-lazy-restore-kill-launch-session 'on'
    ```

********************************************************************************

## TODOs ##
- [X] Fuzzy Find and Restore Individual Session
- [X] Save/Update Individual Session
- [X] Restore All Sessions
- [X] Save All Sessions
- [X] Delete Individual Session
- [X] Revert Individual Session
- [X] Indicate which sessions are new and which are already loaded
- [ ] Interoperability with tmux-resurrect

## Contributing ##
If you run into any issues or have any suggestions, open a Pull Request that includes the updates and I'll review/comment/merge it as soon as I can.  If you don't have enough time or don't know how to fix the issue, submit an Issue and provide as much detail as you can.

********************************************************************************

## Acknowledgments

I would like to thank the following plugins for inspiration and as a reference during development:
- [tmux resurrect](https://github.com/tmux-plugins/tmux-resurrect)
- [tpm](https://github.com/tmux-plugins/tpm)

********************************************************************************

## Additional Resources ##
- [My YouTube Playlist](https://youtube.com/playlist?list=PLD3V7KEd2M-tUghtES9iyl_ERa7sc1-HF&si=sLuFUeU_IjGr0S2I) 🔥🔥🔥

********************************************************************************
